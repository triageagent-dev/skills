# Signals by instrumentation source

Agent v3.3.3 and chart 3.3.3, from `README.md`, `docs/spec.md` (sections 01, 02, 03, 10, 13), ADR-0009/0011/0013/0014/0015/0017/0018/0021/0022
and the code in `otlpreceiver/`, `redsource/`, `usemetrics/`, `logmetrics/`. "Cluster agent" is the Deployment; "eBPF" is its DaemonSet; "OTLP" is the
receiver, either in the controller (`otlp.enabled`) or in its own pods (`otlp.sensor.enabled`); "OTLP-only" is the same receiver with `kubernetes.watch=false`.

## Frames and who produces them

| Frame to the core | eBPF (cluster agent + DaemonSet) | OTLP (cluster agent) | OTLP-only agent | Host agent |
|---|---|---|---|---|
| `snapshot`, `app_delta` (application inventory) | virtual apps from workloads, labels, annotations | same | from the `k8s_cluster` workload counts a Collector sends, else one app per reporting (namespace, service); no label grouping | one app per selected systemd unit, namespace `host` |
| `k8s_event` (Warning events only) | yes | yes | no | no |
| `red_metrics`, `red_summary` | yes (HTTP, gRPC servers) | yes | yes | yes, with a `-tags obi` binary (the release binaries) |
| `use_metrics`, `use_summary` | yes, `node-exporter` role (cgroup v2, PSI) | yes, from `use.*` or the kubelet's cAdvisor | same | yes, from the unit's cgroup |
| `log_metrics` | yes, `log-exporter` role, with a redacted sample line | counts only, no sample line | counts only | yes, journald and plain log files, with a sample line |
| `topology_snapshot` L7 edges | yes: HTTP, gRPC, SQL, Redis client calls | yes, from client histograms or client spans | yes, resolved by host name only | edges go to external hosts, even to another unit |
| `topology_snapshot` L4 edges | opt-in `ebpf.networkFlows.enabled` | only if something sends `obi.network.flow.bytes` | same | flow series carry no unit names, so no extra edge |
| `sensor_state` | yes | yes, lists each OTLP source | yes | yes |

## Environment, rights, code changes

| | eBPF | OTLP in a cluster agent | OTLP-only agent | Host agent |
|---|---|---|---|---|
| Environment | Kubernetes nodes you may run a DaemonSet on | Kubernetes, with Collectors or SDKs | any place that can run the Deployment and reach a Kubernetes API with namespace-scoped rights; senders anywhere that can reach port 4317 | Linux VM or bare metal with systemd |
| Install rights | cluster-scoped: the chart adds a ClusterRole and ClusterRoleBinding for the DaemonSet (read pods, services, nodes, namespaces, replicasets, deployments, statefulsets, daemonsets), plus the controller's own ClusterRole | the controller's ClusterRole; a TokenReview ClusterRole only when `otlp.allowedServiceAccounts` is set | namespace-scoped only (Roles for leases, the join, sensor-TLS and client-CA Secrets); no ClusterRole | root on the host |
| Runtime privilege | `hostPID`, root, capabilities `BPF`, `PERFMON`, `NET_RAW`, `SYS_PTRACE`, `DAC_READ_SEARCH`, `CHECKPOINT_RESTORE`; Pod Security `privileged` level; `hostNetwork` with L4 flows; kernel 5.8+ (4.18 on RHEL) with BTF; cgroup v2 for USE; user 0 | none beyond the controller | none; the controller keeps the image's non-root user, and the role pods (`otlp.sensor.enabled`) run non-root with a read-only root filesystem and all capabilities dropped | root with the same six capabilities, `NoNewPrivileges`, `ProtectSystem=strict`; kernel 5.8+ with BTF, cgroup v2, systemd 240+ |
| Code changes | none, any language | an SDK or a Collector that sends the right names | same | none |
| Where the numbers come from | OBI uprobes and kprobes, cgroup files, container log files | what the sender exports | what the sender exports | OBI, unit cgroups, journald |

## Cost and size, as the repo states them

| Item | Figure |
|---|---|
| Image `agent` (no OBI) | 54 MB for linux/amd64; runs the controller and the OTLP role |
| Image `agent-obi` | 93 MB for linux/amd64; runs the eBPF role |
| DaemonSet container | requests 50m / 128Mi, limits 300m / 700Mi; memory about 47Mi with nothing instrumented, about 285Mi after the first attach, about 7Mi per further process; CPU near 130m while attaching after a restart |
| L4 flows | cluster-wide metadata informer: memory grows with the cluster's pod count |
| Controller | requests 50m / 64Mi, limits 200m / 512Mi |
| OTLP sensor role pods | 2 replicas, requests 100m / 256Mi, limits 2Gi memory; Go heap kept under 90% of the limit |
| Host unit | `MemoryMax=1G` |
| OTLP intake bounds | 2000 resources, 5000 series per resource, 500 resources per sender, 4 MiB per request, 2,000,000 series |
| Measured | on one cluster, OTLP alone matched eBPF for USE and for RED on traced services, and kept about a tenth of the graph's edges once L4 flows were gone (spec section 13) |

## What is lost without each source

| Without | Lost |
|---|---|
| eBPF | RED and L7 edges for services nobody traces or instruments; L4 flows; the log sample line (the OTLP count connector and raw logs give counts only); coverage of every process regardless of language |
| OTLP | services in sandboxed runtimes (gVisor, Kata, user-namespaced pods: eBPF cannot see their traffic), managed nodes that refuse a privileged DaemonSet, and anything that only exports telemetry (serverless, SaaS) |
| Kubernetes watch (`kubernetes.watch=false`) | Warning events, label-derived virtual apps, Service and Ingress name resolution of topology callees |
| Host agent | Kubernetes-less machines are not seen at all; host containers (Docker, Podman) are not covered yet |
