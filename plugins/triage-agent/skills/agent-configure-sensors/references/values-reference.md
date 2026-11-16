# Sensor and collector values

Every key below is in the chart's `values.yaml` (triage-agent chart 3.3.3). "unset" means the key renders no argument and the
binary's own default applies; the number in parentheses is that default. Applying any of them rolls the pods that use it.

## Collectors in the controller

A collector runs when `core.host` is set, its `enabled` is true (the default) and it has a source: `otlp.enabled`, or the DaemonSet role
named in the second column.

| Collector | Source on the DaemonSet | Enabled by |
|---|---|---|
| RED (`red_metrics`, `red_summary`) | `ebpf` role | `redMetrics.enabled` |
| Topology (`topology_snapshot`) | `ebpf` role | `topology.enabled` |
| USE (`use_metrics`, `use_summary`) | `node-exporter` role | `useMetrics.enabled` |
| LOG (`log_metrics`) | `log-exporter` role | `logMetrics.enabled` |

Gated frames (`red_metrics`, `use_metrics`, `log_metrics`) carry only services that crossed a gate in the window. The summary
frames carry every service.

## RED gates (`redMetrics.*`)

| Value | Default | Meaning |
|---|---|---|
| `intervalSeconds` | unset (60) | Gate window. Also the topology collector's read tick. |
| `errorThreshold` | unset (10) | Minimum errors in a window. |
| `minErrorRatePct` | unset (5) | Minimum error rate. Both this and `errorThreshold` must hold. `0` means no rate floor. |
| `operationErrorRatePct` | unset (50) | A single operation with `errorThreshold` errors and this error rate qualifies the service. `0` turns the arm off. |
| `latencyMultiplier` | unset (5) | p99 at least this many times the median p99 of recent normal windows. `0` turns the arm off. |
| `latencyFloorMs` | unset (1000) | Absolute p99 the latency arm also needs. |
| `latencyMinRequests` | unset (10) | Requests a window needs for its p99 to count. |
| `latencyMinBaselineWindows` | unset (10) | Prior windows needed before the latency arm fires. Baselines are in memory; they restart with the controller. |
| `baseline.enabled` | unset (true) | Baseline arms for error rate and p99 per service and per operation. |
| `baseline.multiplier` | unset (3) | Breach factor against the service's own normal. |
| `baseline.evidenceWindows` | unset (5) | Windows summed for one verdict. |
| `baseline.errFloorPct` / `latFloorMs` | unset (5 / 300) | Floors the baseline arms also need. |
| `baseline.minBaselineWindows` | unset (5) | Readings before judging against the own baseline. |
| `baseline.errMinRequests` / `errMinErrors` / `latMinRequests` | unset (20 / 3 / 10) | Evidence a verdict needs. |
| `baseline.errColdFloorPct` / `latColdFloorMs` | unset (15 / 5000) | With no baseline yet (after a restart) a reading at or above these is reported and not learned. Negative disables. |
| `baseline.errSparseMinErrors` / `errSparseRatePct` | unset (5 / 50) | Low-volume rule. Negative `errSparseMinErrors` disables it. |
| `baseline.latChronicMinRequests` | unset (100) | Requests a breaching p99 needs before the key is muted as chronically spiky. |
| `baseline.maxOperations` | unset (100) | Operations tracked one by one per service; the rest are judged together. |

## USE gates (`useMetrics.*`)

| Value | Default | Meaning |
|---|---|---|
| `enabled` | `true` | Collector on. |
| `nodeExporter` | `false` | Run the `node-exporter` role on the DaemonSet. |
| `intervalSeconds` | unset (60) | Gate window. |
| `memPsiThreshold` / `cpuPsiThreshold` / `ioPsiThreshold` | unset (20 / 40 / 40) | "some avg60" PSI percent, maximum over a service's pods. Any one qualifies. `0` always reports that dimension. OOM kills in the window also qualify. |
| `baseline.enabled` / `multiplier` | unset (true / 3) | CPU cores used against the service's own baseline. |
| `baseline.cpuFloorCores` | unset (0.25) | Cores floor. |
| `baseline.cpuColdFloorCores` | unset (0, off) | Cores at or above which a service with no baseline is reported. |
| `resources` | requests 10m / 32Mi, limits 50m / 64Mi | In `values.yaml`, read by no template: it has no effect. The DaemonSet runs all roles in one container sized by `ebpf.resources`. |

## LOG gates (`logMetrics.*`) and the exporter (`logExporter.*`)

| Value | Default | Meaning |
|---|---|---|
| `logMetrics.enabled` | `true` | Collector on. |
| `logMetrics.intervalSeconds` | unset (60) | Gate window. |
| `logMetrics.errorThreshold` | unset (10) | Error-line or warn-line delta in a window that qualifies a service. |
| `logMetrics.baseline.enabled` / `multiplier` | unset (true / 3) | Once a service has a baseline it is reported on a step of this factor and at least `errorThreshold`. |
| `logMetrics.baseline.coldFloorLines` | unset (0, off) | Lines per window at or above which a service with no baseline is reported. |
| `logExporter.enabled` | `false` | Run the `log-exporter` role on the DaemonSet. |
| `logExporter.includeNamespaces` | `[]` | Exact namespace names to tail. Empty falls back to `target.namespaces`, then to every namespace. |
| `logExporter.errorRegex` / `warnRegex` | unset | In `values.yaml`, read by no template at 3.3.3: no effect. The binary has the flags `--log-exporter-error-regex` and `--log-exporter-warn-regex` (RE2) with built-in defaults. |
| `logExporter.sampleMaxLen` | unset | Same: no effect through the chart. Flag `--log-exporter-sample-max-len` (160). |
| `logExporter.maxSamplesPerService` | unset | Same. Flag `--log-exporter-max-samples-per-service` (8): distinct error fingerprints per service, more fall into one catch-all series. |
| `logExporter.sampleJsonFields` | `[]` | Same. Flag `--log-exporter-sample-json-fields` (message, msg, error, err). |
| `logExporter.resources` | requests 50m / 64Mi, limits 100m / 128Mi | Read by no template: no effect. The DaemonSet container is sized by `ebpf.resources`. |

The sample sent to the core is redacted for secrets and email addresses and cut to 256 bytes on the wire (spec section 05).

## Topology (`topology.*`)

| Value | Default | Meaning |
|---|---|---|
| `enabled` | `true` | Collector on. |
| `intervalSeconds` | unset (600) | Flush cadence of the full snapshot. Use 60 for a first check, then restore it. |

The snapshot keeps the top 500 edges and the first 200 nodes.

## eBPF DaemonSet (`ebpf.*`)

| Value | Default | Meaning |
|---|---|---|
| `enabled` | `false` | Deploy the DaemonSet `<fullname>-ebpf` with the `ebpf` role. |
| `privileged` | `false` | `true` runs a fully privileged container. Last resort. |
| `extraCapabilities` | `[]` | Added to the six default capabilities: `SYS_RESOURCE` (kernels before 5.11), `SYS_ADMIN` (Go uprobes on some kernels). |
| `includeNamespaces` | `[]` | Allowlist; `excludeNamespaces` is then ignored. Wins over the next two. |
| `instrumentNamespaces` | `[]` | Plain names (exact match), used when `includeNamespaces` is empty. |
| `excludeNamespaces` | kube-system, kube-node-lease, kube-public | Applied only when `includeNamespaces`, `instrumentNamespaces` and `target.namespaces` are all empty. |
| `excludeWorkloads` | `[]` | Owner-name globs (Deployment, StatefulSet, DaemonSet), e.g. `["*synthetic*"]`. |
| `excludePaths` | `[]` | Executable-path globs, e.g. `["*ms-playwright*"]`. |
| `excludeOtelInstrumentedServices` | `false` | `true` leaves processes that ship their own OTel SDK without RED. |
| `metaRestrictLocalNode` | unset | OBI's Kubernetes metadata scope. Unset: node-local, or cluster-wide when `networkFlows` is on. |
| `disableInformers` | `[node]` | OBI informers to disable. |
| `networkFlows.enabled` | `false` | L4 flow edges. Sets `hostNetwork: true` and `dnsPolicy: ClusterFirstWithHostNet`. Needs `ebpf.enabled`. |
| `tolerations` | `[]` | Empty keeps the DaemonSet off tainted nodes. |
| `nodeSelector` | `{}` | Limits the nodes. Pods on other nodes are invisible. |
| `resources` | requests 50m / 128Mi, limits 300m / 700Mi | Whole DaemonSet container. |

Measured memory of the container by instrumented processes: 0 about 47Mi, 1 about 285Mi, 5 about 348Mi, 18 about 409Mi. The first attach costs
about 240Mi and each further process about 7Mi; CPU peaks near 130m while attaching after a restart. A cluster-wide metadata informer
(flows on) grows with the cluster's pod count: raise `ebpf.resources.limits.memory` on a large cluster.

## Other values

| Value | Default | Meaning |
|---|---|---|
| `image.ebpf.repository` / `tag` | `""` / `""` | DaemonSet image. Empty means `<image.repository>-obi` and `image.tag`. |
| `sensorStream.port` / `meshPort` / `tick` | 9470 / 9471 / unset (15s) | Controller gRPC port for the sensors, replica gossip port, how often each sensor sends. |
| `workloadResources` | `[]` | Workload kinds as `group/version/resource`; a non-empty list replaces the built-ins (deployments, statefulsets, daemonsets, argoproj.io rollouts). |
| `rbac.extraWorkloadRules` | `[]` | Read rules for a kind added in `workloadResources`. |
| `virtualApps` | `""` | `on` or `off`; empty leaves the binary default, `on`. Needs `core.host`. |
| `syncPeriod` | unset (120) | Informer resync seconds. |
| `metrics.enabled` / `bindAddress` | `false` / `127.0.0.1:8080` | Controller self-metrics endpoint. |
| `resources` | requests 50m / 64Mi, limits 200m / 512Mi | Controller container. |
