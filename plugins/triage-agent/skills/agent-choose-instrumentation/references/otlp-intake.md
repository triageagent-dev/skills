# OTLP receiver: what it reads, drops and refuses

Agent v3.3.3 unless a row says otherwise. Sources: `otlpreceiver/` (`wanted.go`, `normalize.go`, `spanmetrics.go`, `traces.go`, `logs.go`,
`cadvisor.go`, `receiver.go`, `admission.go`, `intake.go`), `docs/spec.md` section 03, ADR-0017, ADR-0022, CHANGELOG.

## Services and temporality

The receiver registers the OTLP metrics, traces and logs services on one gRPC listener (port 4317). Compression: gzip, zstd and snappy.

| Input | Handling |
|---|---|
| Cumulative sum or explicit-bucket histogram | kept as the series' latest point; a point older than the last one forwarded is dropped |
| Delta sum or histogram | added into a running total per series and forwarded as cumulative; an interval ending no later than the last one added is dropped as a retry; changed bucket bounds are refused (`histogram bucket bounds changed`) |
| Exponential histogram | refused per point: `exponential histograms are not supported; use explicit buckets` |
| A series that changes kind | refused: `a series changed its kind` |
| Exemplars | dropped at intake |

Traces and logs: the spec describes raw traces and logs as a feature of the OTLP sensor role (`otlp.sensor.enabled`); the code registers the traces and
logs services in the controller's listener too. The spec says the controller's listener needs the `spanmetrics` and `count` connectors. Use the role for raw telemetry, which is
the documented and cluster-tested path (ADR-0022).

## Metric names read

| Family | Names (as the sender names them) | Notes |
|---|---|---|
| RED, SIG, L7 topology (server side) | `http.server.request.duration`, `rpc.server.call.duration` | histograms in seconds; status from `http.response.status_code` and `rpc.response.status_code` |
| L7 topology (client side) | `http.client.request.duration`, `rpc.client.call.duration`, `db.client.operation.duration` | callee from `server.address` |
| Older names, renamed | `http.server.duration`, `http.client.duration`, `rpc.server.duration`, `rpc.client.duration` (milliseconds become seconds); attributes `http.status_code`, `http.method`, `net.peer.name`; numeric `rpc.grpc.status_code` | |
| Span metrics from a Collector's `spanmetrics` connector | `traces.span.metrics.duration` (calls counter dropped; needs `add_resource_attributes: true`) | dimensions read: `http.response.status_code`, `http.status_code`, `http.request.method`, `http.method`, `http.route`, `rpc.system`, `rpc.system.name`, `rpc.method`, `rpc.service`, `rpc.grpc.status_code`, `rpc.response.status_code`, `server.address`, `net.peer.name` |
| L4 topology | `obi.network.flow.bytes` | only if something emits it |
| USE | `use.*` points (for example `use.mem.pct`, `use.cpu.usage.usec`, `use.oom.kill`; the full list is in `usemetrics/`) | |
| USE from the kubelet | cAdvisor series `container_cpu_usage_seconds`, `container_cpu_cfs_periods`, `container_cpu_cfs_throttled_periods`, `container_oom_events`, `container_spec_cpu_quota`, `container_spec_cpu_period`, `container_memory_working_set_bytes`, `container_memory_usage_bytes`, `container_spec_memory_limit_bytes`, `container_pressure_{cpu,memory,io}_waiting_seconds`, `machine_cpu_cores`, `machine_memory_bytes` | pod-level cgroup series only (empty `container` and `image` labels); PSI needs Kubernetes 1.34 or later; the Collector's identity needs `get` on `nodes/metrics` |
| LOG | `log.errors`, `log.warns`, `log.lines` counters, or raw log records (severity number: error and above, warn up to error, every record) | counts only, no sample line |
| Application readiness (OTLP-only) | `k8s.deployment.desired/available`, `k8s.statefulset.desired_pods/ready_pods`, `k8s.daemonset.desired_scheduled_nodes/ready_nodes` | from the `k8s_cluster` receiver |

Required attributes: `service.name` and `k8s.namespace.name` (resource or point). The workload comes from `k8s.owner.name`, or from the
`k8s.deployment.name` family that `k8sattributes` adds. Raw spans: server and consumer spans become the server histograms, client and producer
spans the client histograms, internal spans are ignored; gRPC is recognised from `rpc.system`, `rpc.system.name` or `rpc.grpc.status_code`.
Client spans resolve the callee from `server.address`; without a Service index (`kubernetes.watch=false`) only `name`, `name:port`, `name.<namespace>` and `name.<namespace>.svc` resolve.

## What happens to a point

| Outcome | Reason | Where it shows |
|---|---|---|
| Read | a collector reads the name | forwarded to the sensor stream |
| `unread` | no collector reads the metric name (dropped before it takes a quota slot) | `unread` in the once-a-minute `otlp received` summary line, the ledger, and the intake status with the top names |
| `refused` | `resource has no k8s.namespace.name: the sender did not enrich it`; `namespace <ns> is not the sender's namespace` (token sender); `namespace contains the tenant separator`; `resource names more than one k8s.namespace.name`; `namespace outside the workspace scope`; the tenant reasons below; `series limit reached`; the temporality reasons above | returned to the sender as partial success (`RejectedDataPoints`/`RejectedSpans`), counted per sender; the per-sender line is verbosity 1 |
| `refusedExports` | backpressure, before the request is read: `backpressure: too many exports in flight`, `backpressure: memory near the limit` | `RESOURCE_EXHAUSTED` with a retry delay (1 s in flight, 5 s memory); outside `exports` and `points` |
| `held` (entries) | the numbers the receiver keeps across exports: last timestamps, delta totals, span-route counts, log counts, previous PSI readings; each expires after `otlp.expire` (3m) | `held` and `sources` in the intake status |
| held back from the core | an entry the core would refuse a whole frame over (no namespace or name, topology end missing); the push queue drops just that entry | TUI "Held back from the core"; `triage_agent_frames_malformed_dropped_total` |

Tenant reasons: `the certificate names several tenants and the resource has no triage.tenant`; `tenant <t> is not in the sender's certificate`; `tenant <t> is not served by this agent`.

## Process-and-drop and backpressure

The receiver translates each export as it arrives, forwards it and keeps no copy. The controller's hub merges a source's exports per series, newest value per attribute set.
Admission control refuses an export before reading it when more than `otlp.limits.maxInFlight` are in flight (0 means twice the CPUs, at least 4), or when the live heap passes 75% of the Go
memory limit (taken again under 60%). Every mode sets the Go memory limit to 90% of the container's cgroup limit; `GOMEMLIMIT` in the environment wins. A Collector's exporter queue honours the retry delay.
Limits (`otlp.limits.*`): `maxResources` 2000, `maxPointsPerResource` 5000, `maxResourcesPerSender` 500, `maxRequestBytes` 4194304, `maxSeries` 2000000, `maxInFlight` 0; `otlp.expire` 3m.

## Intake statistics to the core

Per sender and one-minute window: `exports`, `points` (also spans and log records), `unread`, `refused`, `refusedExports`, plus `held` and `sources` now, and the top 20 unread metric names
(`unreadByName`; names past 1024 per sender fold into `other`). They travel in the `sensor_state` frame every 60 s, summed over the receiver replicas, so the core can show what share of a Collector's export is read and
what to filter out at the Collector. This is on the agent branch after v3.3.3 (commits `feat(otlp): report the intake per sender to the core` and the ranking fix); v3.3.3 does not carry it.
The same counters per source are in the local TUI's sources panel and `GET /api/v1/sources` (`ledger`, `roleLedger`).
