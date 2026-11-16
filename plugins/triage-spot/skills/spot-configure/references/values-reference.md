# tria-spot values reference

Every key of the chart's `values.yaml` at v0.9.0, grouped. "Flag" is the binary flag the chart passes. Defaults are the
chart's. A key marked "roll" changes the Deployment's args or volumes, so `helm upgrade` rolls the pod. The chart
installs the Deployment runtime only: a substrate actor takes the same flags as the `args` of its ActorTemplate, and the
flags that only an actor takes are in the last section. The `engine` block of v0.6.x is gone.

## Identity

| Key | Default | Flag | Meaning |
|---|---|---|---|
| `spot.enabled` | `false` | | `false` renders nothing. `true` starts a model-driven agent that sends what it reads to the model API. Required for every render. |
| `spot.tenant` | `""` | `--tenant` | The workspace id. Required. No spaces or slashes. |
| `spot.name` | `<tenant>-spot` | `--name` | Technical name: Deployment, volume, ServiceAccount, note tags, ego thread, certificate identity. Chart truncates to 63 characters; a certificate allows lowercase letters, digits and dashes, at most 40. |
| `spot.chatName` | `""` | `--chat-name` | Messenger name until the core says. The workspace owner sets the real one (`spotName`); the spot reads it with `get_spot_identity`. People do not write to a spot at v0.9.0 (Tria does), so the sources name nothing that this decides for a person. |
| `spot.replicas` | `1` | | `1` runs, `0` parks (Deployment, PVC, ServiceAccount and Secrets stay; an upgrade keeps it parked). More than 1 is not supported. |
| `image.repository` | `ghcr.io/triageagent-dev/spot` | | Image. |
| `image.tag` | chart `appVersion` | | A string; a digits-only tag must be quoted or the chart fails. |
| `image.pullPolicy`, `imagePullSecrets` | `IfNotPresent`, `[]` | | Standard. |

## Core connection

| Key | Default | Flag | Meaning |
|---|---|---|---|
| `core.mcpUrl` | `""` | `--core-mcp-url` | The core's `/mcp` (streamable HTTP). Required. |
| `core.apiUrl` | `""` | `--core-api-url` | The core's HTTP API. Enables the trigger websocket (the wake frames of the core's scheduler); empty = poll only, and the spot wakes itself at the planned time. Required for `certificate`. Add its port to `networkPolicy.core.ports`. |
| `core.identity` | `serviceAccount` | | `serviceAccount`, `secret` or `certificate`. |
| `core.enrollKeySecret.name`, `.key` | `""`, `key` | `--enroll-key-file` | `certificate`: the Secret with the one-time key, mounted at `/secrets/enroll`. Sent only while the spot has no certificate. A spent key left here is harmless. |
| `core.caFingerprint` | `""` | `--core-ca-fingerprint` | `certificate`: `SHA256:<64 lowercase hex>` of the core's CA. Required then. |
| `core.audience` | `triage-core` | | `serviceAccount`: the projected token's audience. |
| `core.tokenExpirationSeconds` | `3600` | | `serviceAccount`: minimum 600; the kubelet rotates at 80%. |
| `core.rbac.create` | `true` | | `serviceAccount`: renders Role and RoleBinding `<name>-core` (label `triageagent.dev/managed: "true"`). Ignored for other identities. |
| `core.verbs` | `[get, list, create, update]` | | `serviceAccount`: verbs on the one workspace, from get, list, create, update, execute, ingest, voice, observe. The default is read and write, no exec, ingest or voice. |
| `core.tokenSecret.name`, `.key` | `""`, `token` | `--core-token-file` | `secret`: a static bearer token, mounted as a file. Required then. |

## Model

| Key | Default | Flag | Meaning |
|---|---|---|---|
| `llm.provider` | `anthropic` | `--llm-provider` | `anthropic` or `gemini`. |
| `llm.auth` | `key` | `--llm-auth` | `key`, `federation` (Anthropic only), `vertex`. The binary also has `injected` (Anthropic only, a substrate actor); the chart refuses it. |
| `llm.model` | `""` | `--model` | Empty = `claude-opus-5-5` or `gemini-3-flash-preview`; the flag is not passed. No prefix on Vertex AI. The shipped substrate template sets `claude-sonnet-5-5`. |
| `llm.effort` | `medium` | `--effort` | `low`, `medium`, `high`, `xhigh`, `max`. |
| `llm.maxSteps` | `40` | `--max-steps` | Model requests per wake. |
| `llm.maxToolCalls` | `20` | `--max-tool-calls` | Tool calls per wake. `0` omits the flag (the binary's 20). |
| `llm.maxTurnTokens` | `150000` | `--max-turn-tokens` | Billable tokens per wake (input without cache reads, output, cache writes). `0` = none. |
| `llm.keySecret` | | `--anthropic-key-file` | `anthropic` + `key`. |
| `llm.geminiKeySecret` | | `--gemini-key-file` | `gemini` + `key`. |
| `llm.federation.*` | | `--anthropic-*` | `ruleId`, `orgId`, `serviceAccountId` required; `workspaceId` optional; `audience` `https://api.anthropic.com`; `tokenExpirationSeconds` 600 (minimum). |
| `llm.vertex.project`, `.region` | `""`, `global` | `--vertex-project`, `--vertex-region` | `vertex`. Project is required. |

## Schedule and wake

| Key | Default | Flag | Meaning |
|---|---|---|---|
| `agent.minWake`, `agent.maxWake` | `2m`, `2h` | `--min-wake`, `--max-wake` | Clamp for the model's `schedule_next`. A turn that does not schedule gets `minWake`. A failed turn backs off from `minWake`, doubling to `maxWake`. The spot reports the plan to the core (ADR-106), which sends the wake when it is due. `maxWake` is also the net: with the stream up and no wake from the core the spot wakes itself that long after its last wake, and it is the `maxWakeMs` the core clamps to 1 minute to 24 hours. |
| `agent.pollInterval` | `30s` | `--poll-interval` | Polling while the trigger stream is down or absent. |
| `agent.edgeCooldown` | `1m` | `--edge-cooldown` | Gap between a turn and an issue-change wake. Forced to `0` on a substrate actor. |
| `agent.chatBatch` | `10m` | `--chat-batch` | Wait of a person's message in a room that does not name the spot. At v0.9.0 the spot reads only its bus, where every message is Tria's request and wakes it at once whatever this says. Forced to `0` on a substrate actor. |
| `agent.issueWakes` | `true` | `--issue-wakes` | `false`: issue changes wait for the scheduled wake; only a person's message wakes early. |
| `agent.maxEdgeWakesPerHour` | `12` | `--max-edge-wakes-per-hour` | Early wakes per hour; `0` = no cap. |
| `agent.skipQuietWakes` | `true` | `--skip-quiet-wakes` | A startup or timer wake with no facts, no held edge and no open issue ends with no model call. |
| `agent.fastLane` | `true` | `--fast-lane` | A person's message (at v0.9.0, a request from Tria) and a promised wake run in a short second turn beside a long one. |
| `agent.fastMaxToolCalls` | `8` | `--fast-max-tool-calls` | Short turn cap (flag passed only when not 8). |
| `agent.fastMaxTurnTokens` | `120000` | `--fast-max-turn-tokens` | Short turn cap (flag passed only when not 120000). |
| `agent.turnTimeout` | `20m` | `--turn-timeout` | Wall-clock cap per wake; past it the wake fails. |
| `agent.toolTimeout` | `60s` | `--tool-timeout` | One tool call; past it the model gets an error result. |
| `agent.toolResultMaxBytes` | `12288` | `--tool-result-max-bytes` | A longer result is cut and says how much was dropped. |
| `agent.heartbeatId` | `""` | `--heartbeat-id` | Memory cell id of the heartbeat. Default `system2-heartbeat-<tenant>`. |

## Budgets and spend

| Key | Default | Flag | Meaning |
|---|---|---|---|
| `agent.dailyTokenCeiling` | `2000000` | `--daily-token-ceiling` | Tokens per UTC day (input, output, cache creation). `0` = none. At the ceiling no wake starts and edges are held until UTC midnight. A turn in flight can overshoot by one turn. |
| `agent.hourlyTokenCeiling` | `600000` | `--hourly-token-ceiling` | Any rolling hour. `0` = none. In memory: a restart starts empty. |

The core's cap is not a chart value: policy `budgets.spotTenantDailyTokens` (per workspace) over
`budgets.spotDailyDefaultTokens` (1,000,000). The spot reports each turn to the core on its stream (an actor, in its
reports); the core books it as usage kind `spot`.

The schedule itself is not a chart value. The core's floor (no wake within 30 seconds of the last one it sent, at most 60
an hour per spot) and its limit of one outstanding wake per spot are the core's constants. The planned wake and the
promises (up to 20, each at most seven days out) are the spot's to report.

## Tools and prompt

| Key | Default | Flag | Meaning |
|---|---|---|---|
| `agent.coreTools` | `curated` | `--core-tools` | `curated` or `all`. Denied by name even if allowed: `resolve_issue`, `forget_issue`, `update_issue_severity`, `link_issues`, `set_tenant_goals`, `run_rsi`, `emit_event`, `classify_event`, `decide_event`, `guardrail_event`, `test_notify`, `test_push`, `approve_pattern`, `expire_memory_item`, `consolidate_memory`, `build_memory`, `build_knowledge`, `build_rca`. |
| `agent.notesOnly` | `false` | `--notes-only` | The model gets only `search_memory` over its own notes. |
| `agent.instructionCell` | `spot-instruction` | `--instruction-cell` | Memory cell with the system prompt (kind `spot_system_identity`). Read at start, retried for two minutes, then the spot exits. |
| `connectors` | `[]` | `--connectors-file` | See below. An actor takes the same list inline in `--connectors-json`. |
| `agent.maxTasks` | image default `3` | `--max-tasks` | Concurrent `start_task` tasks, each a turn of its own beside the lanes; `0` takes the tool away; 10 at most (up to 10 more wait). Was `engine.temporal.maxTasks`. The flag is passed only when the key is set. On a substrate spot `start_task` asks the core to make a task actor instead (see spot-configure, Tasks). |

Allowed core tools in the default mode: `get_triage_instructions`, `get_tenant_situation`, `get_tenant_health`,
`get_tenant_goals`, `list_open_issues`, `list_issues`, `get_issue_detail`, `get_issue_graph`, `get_recent_events`,
`search_memory`, `search_corpus`, `get_memory`, `get_memory_context`, `get_memory_items`, `get_memory_cell`,
`fetch_memory`, `get_world_context`, `get_service_analytics`, `get_service_prediction`, `inspect_service`,
`list_services`, `list_applications`, `list_pattern_proposals`, `analyze_issue`, `verify_hypothesis`,
`comment_on_issue`, `upsert_memory_item`, `supersede_memory_item`, `refute_memory_item`, `note_observation`,
`recognize_pattern`, `link_pattern`, `say_in_workspace`, `read_workspace_room`, `read_workspace_file`,
`set_workspace_status`, `set_spot_status`. The built-ins are `schedule_next`, `finish` and, with `agent.maxTasks`
above 0, `start_task`. The workspace tools (`say_in_workspace`, `read_workspace_room`, `read_workspace_file`,
`set_workspace_typing`) take the room `bus` and no other at v0.9.0.

### Connector example

```yaml
connectors:
  - name: example-kube                      # lowercase letters, digits, dashes; not core or ego
    url: http://tools.example.svc:8084/mcp  # streamable HTTP
    tools: [k8s_get_resources, k8s_describe_resource, k8s_get_pod_logs]   # required, exact names
    hint: The workspace's cluster, read-only.
    egress:
      namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: example}}
      podSelector: {matchLabels: {app.kubernetes.io/name: tools}}
      ports: [8084]
```

The model sees `example-kube__k8s_get_resources` and so on. The ConfigMap holds names, URLs, tool names and hints,
no credential. A tool the connector offers and `tools` does not name is not offered, and a call to it is refused.
The connector's identity and RBAC or IAM (read-only get, list, describe and logs for a Kubernetes tool server) are
configured on the connector, not in this chart.

## Engine (removed)

There is no `engine` block. The Temporal engine was removed in spot v0.7.0 (the core's ADR-106): `--engine` and every
`--temporal-*` flag make the binary refuse to start, and a values file with `engine.type: temporal` fails to render with
a message that names ADR-106. The last release with the engine is v0.6.1.

## Telemetry

| Key | Default | Flag | Meaning |
|---|---|---|---|
| `telemetry.enabled` | `false` | | Send OpenTelemetry spans (one per wake, model request and tool call). |
| `telemetry.endpoint` | `""` | `--otel-endpoint` | OTLP/HTTP endpoint. Required when enabled. Add `networkPolicy.telemetry`. |
| `telemetry.tenant`, `.tenantName`, `.tenantAttr` | `""`, `""`, `triage.tenant` | `--otel-tenant`, `--otel-tenant-name`, `--otel-tenant-attr` | The label ego files the spans under; empty = the spot's name. Name at most 80 characters, no control characters, commas or equals signs. |
| `telemetry.mcpUrl` | `""` | `--ego-mcp-url` | ego's MCP endpoint; adds ego's read-only tools. Needs `tokenSecret`. |
| `telemetry.tokenSecret` | | `--otel-token-file` | Sender token, read at each export. |
| `telemetry.content` | `true` | `--otel-content` | `true`: spans carry prompts, answers, tool arguments and results. `false`: names, timings and token counts only. |

## Logs and state

| Key | Default | Flag | Meaning |
|---|---|---|---|
| `agent.logLevel` | `info` | `--log-level` | `debug`, `info`, `warn`, `error`. |
| `agent.logContent` | `false` | `--log-content` | `true` lets debug logs carry messages, tool input and model text. Off by default: logs hold counts, kinds, ids, tool names and timings only. |
| `persistence.size` | `256Mi` | | `/state` PVC. |
| `persistence.storageClassName`, `.accessModes`, `.existingClaim` | `""`, `[ReadWriteOnce]`, `""` | | Standard. A PVC the chart creates is deleted with the release. |

`/state` holds the usage ledger (`supervisor/usage.json`), room cursors, wake digest, the promises
(`promises.json`; an earlier `promise.json` is read as a list of one), status file (`supervisor/status.json`), and for the
certificate identity `identity/` (`key.pem`, `cert.der`, `ca.der`, `token`, mode 0600). A substrate actor adds
`supervisor/window.json` (the tokens of the last hour, the early wakes of the last hour and the issue baseline). The
model's memory is the core's.

## Network policy

Egress only; nothing may connect in.

| Key | Default | Meaning |
|---|---|---|
| `networkPolicy.enabled` | `true` | Render the policy. |
| `networkPolicy.dns.namespaceLabel` | `kube-system` | Namespace of cluster DNS. |
| `networkPolicy.anthropic.cidrs`, `.ports` | `160.79.104.0/23`, `2607:6bc0::/48`; `[443]` | Used for provider `anthropic` with `key` or `federation`. |
| `networkPolicy.google.cidrs`, `.ports` | `[]`, `[443]` | Required for provider `gemini` or auth `vertex`; you name the ranges. |
| `networkPolicy.google.metadata.cidrs`, `.ports` | GKE metadata addresses, `[988, 80]` | Auth `vertex`. |
| `networkPolicy.core.namespaceSelector`, `.podSelector`, `.cidrs`, `.ports` | empty, `[443]` | Required whatever the identity. A selector left empty is not rendered; a pod selector alone selects pods in the spot's own namespace. |
| `networkPolicy.telemetry.*` | ports `[4318]` | Required with `telemetry.enabled`. |

## Pod

| Key | Default |
|---|---|
| `resources` | requests 100m/128Mi, limits 500m/512Mi |
| `nodeSelector`, `tolerations`, `affinity`, `podAnnotations` | empty |
| `serviceAccount.create`, `.name`, `.annotations` | `true`, `""` (the spot's name), `{}`. Annotations carry the Vertex AI Workload Identity binding. |

The pod runs as uid 10001, non-root, read-only root filesystem, all capabilities dropped, runtime seccomp profile,
and does not mount a ServiceAccount token (`automountServiceAccountToken: false`). Strategy is `Recreate`.

## Flags only a substrate actor takes

These are `args` of the ActorTemplate, not chart values. Source: the spot's specification and flag definitions at v0.9.0.

| Flag | Meaning |
|---|---|
| `--runtime` | `deployment` (default) or `substrate`. |
| `--listen` | Address of `GET /readyz` (the wake-up probe) and `POST /frame` (the core's requests); default `:80`. |
| `--llm-auth=injected` | Anthropic only: a placeholder `x-api-key`; the egress policy puts the real key on. Required with `--runtime=substrate`. |
| `--llm-base-url` | The API's URL when it is not `https://api.anthropic.com`; only with `injected`. |
| `--enroll-key-injected` | The first join carries `X-Triage-Enroll-Key` with a placeholder, replaced from a Secret by the egress; not with `--enroll-key-file`. |
| `--otel-token-injected` | A placeholder bearer to `--otel-endpoint` and `--ego-mcp-url`, replaced by the egress; not with `--otel-token-file`. |
| `--connectors-json` | The connectors as inline JSON (the actor mounts no file); not with `--connectors-file`. |
| `--core-ca-fingerprint`, `--core-api-url` | Required: the actor joins by certificate and talks to the core over HTTP. |
| `--task-verifier-file` | Makes the process a task actor: the file holds the SHA-256 (hex) of the access token of its one task. It never joins. The core side that creates task actors is not in the core at main 1123dda59. |

An actor's link to the core is `POST /v2/messenger/spot/link` (challenge, join, renew, hello) and `/link/report`; it has no
websocket. The core's requests to it are authorised by `Authorization: Bearer <the access token of the last hello>`.
