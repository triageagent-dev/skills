# Strings to search for

Verbatim from the spot's chart and code (v0.9.0) and the core's code (main 1123dda59). Search the log with `grep -F`. A
substrate actor's process prints the same lines, but the spot repository does not say where to read them: use the
platform's tooling.

## Helm render errors (`helm template`, `helm install`)

| Message | Fix |
|---|---|
| `spot.tenant is required when spot.enabled is true` | Set `spot.tenant`. |
| `core.mcpUrl is required when spot.enabled is true` | Set `core.mcpUrl`. |
| `core.apiUrl is required when core.identity is certificate: the spot joins over the core's websocket` | Set `core.apiUrl`. |
| `core.caFingerprint (SHA256:<64 lowercase hex>) is required when core.identity is certificate` | Lowercase hex only, with the `SHA256:` prefix. |
| `core.identity must be serviceAccount, secret or certificate` | Fix the value. |
| `core.tokenExpirationSeconds must be at least 600` | Raise it. |
| `core.tokenSecret.name is required when core.identity is secret` | Name the Secret. |
| `llm.provider must be anthropic or gemini`, `llm.auth must be key, federation or vertex` | Fix the value. |
| `llm.auth federation is an Anthropic auth mode: use key or vertex with llm.provider gemini` | Change provider or auth. |
| `llm.keySecret.name is required when llm.auth is key` | Name the Secret (provider `anthropic`). |
| `llm.geminiKeySecret.name is required when llm.provider is gemini and llm.auth is key` | Name the Secret. |
| `llm.federation.ruleId is required when llm.auth is federation` (also `orgId`, `serviceAccountId`) | Set the ids. |
| `llm.vertex.project is required when llm.auth is vertex` | Set the project. |
| `networkPolicy.google.cidrs must list the addresses of the Google APIs the pod may reach when llm.provider is gemini or llm.auth is vertex` | Name the Google ranges your network uses. |
| `networkPolicy.core needs a namespaceSelector/podSelector or cidrs so egress to it is explicit` | Select where the core lives. The same message exists for `telemetry`. |
| `connectors[<name>].tools must name the tools the spot may call` | A connector needs an exact tool list. |
| `connectors[<name>].egress.ports is required` | Name the ports. |
| `engine.type: temporal is no longer supported: the Temporal engine was removed and the core is the spot's scheduler (the core's ADR-106). Remove the engine block from the values.` | Remove the `engine` block and `networkPolicy.temporal`. A customer who needs Temporal stays on v0.6.1. |
| `telemetry.endpoint is required when telemetry.enabled is true` | Set it. |
| `image.tag must be a string: quote it in the values file or use --set-string image.tag=...` | Quote a digits-only tag. |
| `serviceAccount.name is required when serviceAccount.create is false` | Name it. |

## Startup validation (`tria-spot: <message>`, exit 2)

| Message | Meaning |
|---|---|
| `--core-ca-fingerprint must look like SHA256:<64 lowercase hex characters>` | Certificate identity needs a well-formed fingerprint. |
| `--core-token-file cannot be set with --core-ca-fingerprint: the token file is the identity's own` | Do not mix identities. |
| `--core-api-url is required with --core-ca-fingerprint: the spot joins over the core's websocket` | Set `core.apiUrl`. |
| `the spot name "<n>" cannot be in a certificate: lowercase letters, digits and dashes, at most 40` | Rename. |
| `--enroll-key-file needs --core-ca-fingerprint` | Enrollment key only with the certificate identity. |
| `--llm-auth=federation is an Anthropic auth mode: use key or vertex with --llm-provider=gemini` | Provider and auth mismatch. |
| `--anthropic-key-file must not be given with --llm-auth=federation: the key would shadow federation` | One mode only. |
| `--<flag> only applies with --llm-auth=<mode>` / `--llm-provider=<provider>` | A value of another mode is set. |
| `--instruction-cell is required: the id of the core's memory cell that holds the system prompt` | `agent.instructionCell` empty. |
| `--ego-mcp-url needs --otel-token-file, the sender token ego checks` | `telemetry.mcpUrl` needs `telemetry.tokenSecret`. |
| `--engine: the Temporal engine was removed; the core is the spot's scheduler (the core's ADR-106). Drop --engine and every --temporal-* flag` (also for each `--temporal-*`) | Drop the flag; the engine is gone since v0.7.0. |
| `--runtime=substrate needs --llm-auth=injected: an actor holds no model credential` | Substrate template args. |
| `--runtime=substrate needs --core-ca-fingerprint: an actor joins the core by certificate` | Substrate template args. |
| `--runtime=substrate needs --core-api-url: the actor's link to the core is HTTP requests to it` | Substrate template args. |
| `--runtime=substrate needs --listen` | Substrate template args. |
| `--runtime "<x>" is not one of deployment, substrate` | Fix the value. |
| `--llm-auth=injected outside --runtime=substrate needs --llm-base-url: the proxy that puts the key on the request` | `injected` on a Deployment needs a proxy in front of the API. |
| `--llm-base-url only applies with --llm-auth=injected`, `--anthropic-key-file must not be given with --llm-auth=injected: the spot holds no key` | One mode only. |
| `--enroll-key-injected needs --runtime=substrate and not --enroll-key-file` | Injected key header is for an actor. |
| `--otel-token-injected needs --runtime=substrate and not --otel-token-file` | Injected bearer is for an actor. |
| `--ego-mcp-url needs --otel-token-injected in --runtime=substrate: the egress replaces a bearer the spot sends, it adds none` | Add the flag or drop ego. |
| `--task-verifier-file needs --runtime=substrate`, `--task-verifier-file needs --core-api-url: the task's report goes there` | Task actor args. |
| `--max-tasks is between 0 and 10` | Fix. |
| `--min-wake must be positive`, `--max-wake must be at least --min-wake` | Wake timing. |

## Spot log lines

| Line | Level | Meaning |
|---|---|---|
| `starting version=... commit=...` | info | Process start. |
| `model provider=... id=... effort=...` and `model auth: ...` | info | Provider, model and auth mode in use. |
| `identity: certificate; waiting for the core to accept the spot` | info | Waiting for a certificate and the first access token. |
| `certificate issued spot=... fingerprint=...` | info | Join succeeded. |
| `identity: the core accepted the spot` | info | First access token received. |
| `system prompt read from the core cell=... bytes=... sha256=...` | info | Prompt loaded. |
| `system prompt not read yet` | warn | Retried every 10 seconds for two minutes. |
| `watching the core by=stream|poll` | info | How the core is watched. |
| `the link to the core is up` (`actor`) | info | A substrate actor's hello was taken. |
| `the link to the core is not up; retrying` | warn | An actor's link failed; `err` says why, backoff shown. |
| `the access token could not be renewed; trying again` | warn | An actor's 30-minute token. |
| `the core asks for a wake` (`reason` tick or promise) | info | A wake sent by the core's scheduler. |
| `a person asked for a wake from the console` | info | A manual wake. |
| `a wake of a reason the spot does not know is dropped`, `a promised wake the spot does not hold is dropped` | debug | Stale or unknown order from the core. |
| `a request names a later time: kept as a promise` (`at`, `held`) | info | A request in the bus with a due time. |
| `a request for a later time could not be kept as a promise` | warn | The list holds 20, or the time is past seven days. |
| `standing notes not read; the wake goes on without them` | warn | `search_memory` of the standing notes failed. |
| `the saved issue baseline is unreadable; the next look starts a new one` | warn | An actor's `window.json`. |
| `the core did not start the task (status N)`, `the link to the core is not up` | tool error | `start_task` on a substrate spot; the core side is not shipped at main 1123dda59. |
| `trigger stream closed; reconnecting` | warn | Stream ended; backoff 1s to 30s. |
| `the core refused the join: <status> <message>` | in `err` of `trigger stream closed; reconnecting` | Core's refusal; message below. |
| `the core refused the stream: <status> <body>` | in `err` of the same line | HTTP refusal of the websocket upgrade. |
| `the core does not accept the certificate; the spot will join afresh` | warn | Close 1008. |
| `the core is not the one this spot trusts: ...` | in `err` | CA or signature mismatch. |
| `the core's MCP endpoint cannot be used` | warn | MCP failures, with `failures`, `suppressed`, `nextTry`; said once a minute. |
| `core unreachable` / `core reachable again` | warn / info | Supervisor's own client. |
| `turn start`, `turn done`, `turn failed` | info / error | `turn done` carries billable, read, out, steps, toolCalls, seconds. |
| `short turn start`, `short turn done`, `short turn failed` | info / error | The second lane. |
| `edges count=... kinds=... human=... mentioned=...` | info | Changes noticed, never their text. |
| `nothing to act on: no facts, no open issue; no model call` | info | Quiet wake skipped. |
| `a hold rule is active: no model call` | info | Standing rule. |
| `hourly token ceiling reached...`, `daily token ceiling reached...`, `daily core ceiling reached...` | warn | Paused. |
| `the core counts more than this spot did: taking the core's number` | info | Budget frame raised the local counter. |
| `the core's cap on the spot changed blocked=... spent=... cap=...` | info | Workspace cap crossed. |
| `tool server left out of this turn` | warn | Connector or ego unreachable. |
| `tool skipped: its name is not one the model API takes` | warn | A tool name the model API rejects. |
| `schedule not taken as written source=... note=...` | warn | The model's `schedule_next` was clamped or garbled. |
| `heartbeat not refreshed: the turn failed, so reflection stays the floor` | warn | After a failed turn. |

## Core refusal messages (inside `refused ...`)

| Message | Cause |
|---|---|
| `an enrollment key is required` | No key sent and no approval for this spot. |
| `agent key is invalid, used, expired or revoked` | Unknown, spent, expired or revoked key (the secret did not match counts as invalid). |
| `join request does not match the agent key: key is for cluster "spot:<ws>/<name>" and tenants [<ws>]` | Name or workspace differs from the key's. |
| `no such workspace "<ws>"` | Workspace unknown or inactive. |
| `too many join requests` | Rate limit per key or fingerprint. |
| `join proof does not verify` | The request was altered or signed by another key. |
| `agent join state unavailable` | The core cannot read its join state; retry. |
| `certificate is revoked`, `agent is not approved`, `certificate predates the agent's approval` | On `hello`, close 1008: rejoin needed. |

## Core log lines (operator of the core)

| Line | Level |
|---|---|
| `messenger: spot certificate issued` (`spot`, `workspace`, `fingerprint`) | info |
| `messenger: spot join request` (`kind`, `status`, `source`, `reason`) | debug |
| `messenger: spot wake sent` (`spot`, `reason`) | info |
| `messenger: spot wakes due but not sent` (`spots`) | info (debug when nothing is unsent) |
| `messenger: spot control` (`spot`, `op`, `ok`, `tasks`) | info |
| `messenger: spot silent, forgotten` (`spot`, `silent`) | info |
| `messenger: spot forgotten` (`spot`) | info |
| `messenger: spot link record`, `messenger: spot report`, `messenger: spot token` | warn |
| `messenger bus room created` (`tenant`, `spot`) | info |
| `messenger: spot hello refused` | debug |
| `messenger: spot join refused, the join state failed`, `messenger: spot hello refused, the join state failed` | warn |
| `spot removed` (`cluster`, `by`, `revoked`, `forgotten`) | info |
| `agent key minted` (`key`, `cluster`, `tenants`, `by`) | info |
