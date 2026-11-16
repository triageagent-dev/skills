# MCP tools and REST twins

Source: `internal/mcptools/registry.go` (tool names, arguments, descriptions), `internal/api/server.go` (routes), `docs/STATUS.md`, `docs/rsi.md`. Every tool is limited to the tenants and agents the caller's role allows. A tool that needs online evaluation answers an error when it is not configured. `POST /mcp` is stateless streamable HTTP; `GET` answers 405; a body over 1 MiB is refused with 413; a delegate token takes one request per POST.

## Reading quality

| MCP tool | Arguments | REST | Notes |
|---|---|---|---|
| `get_quality` | `kind?`, `hours?` (1 to 720, default 24) | `GET /api/online/quality?kind=&hours=` | open alerts, hourly means per metric, sessions scored, today's judge budget (not given to a tenant-limited caller) |
| `explain_regression` | `alert_id` | `GET /api/online/alerts/{id}/explain` | the alert, its suspect, worst sessions with the judge's evidence |
| `explain_session` | `session_id` | `GET /api/online/sessions/{id}/explain` | every metric: score, rationale, per-sentence or per-rubric verdicts, `human_verdict`, `human_score` |
| none | | `GET /api/online/status` | config summary, queue, budget, `counts` by reason, `sessionsScored24h`, `openAlerts`, `findings`, `labels` |
| none | | `GET /api/online/series?hours=N` | hourly (tenant, kind, metric) mean and n; default 168, at most 2160 |
| none | | `GET /api/online/alerts?state=open\|all` | alert lifecycle: open, updated, resolved |
| none | | `GET /api/online/failed` | feeds the alerts flag: the latest session scored below its threshold |

## Findings and corrections

| MCP tool | Arguments | REST | Role |
|---|---|---|---|
| `get_findings` | `kind?`, `state?` (`open` default, `corrected`, `resolved`, `stale`, `all`), `since?` (RFC 3339 or `24h`) | `GET /api/online/findings?state=&kind=&tenant=&since=`, `GET /api/online/findings/{id}` | any reader |
| `register_correction` | `finding_id?`, `kind`, `what` (at most 2000 characters), `version?`, `by?`, `tenant?` | `POST /api/online/corrections` body `{findingId?, tenant, kind, what, version?, by?}` | member or admin; viewer and agent-scoped roles get 403; a tenant-limited member posts for its own tenants only |
| `list_corrections` | `kind?`, `state?` | `GET /api/online/corrections?state=&kind=&tenant=` | any reader |
| `run_findings` | none | `POST /api/online/findings/sweep` | admin; 5-minute limit; 409 `a sweep is already running` |
| `label_session` | `session_id`, `metric`, `verdict` (`agree`, `disagree`), `score?`, `note?` | `POST /api/online/labels` body `{sessionId, metric, verdict, score?, note?}`; `GET /api/online/labels?metric=&session=&tenant=&since=` | members and admins, as a person; a sender token gets 403; 404 when the session has no online score for the metric or belongs to a tenant the caller may not see |

Limits: `kind`, `tenant`, `version` and `by` at most 200 characters (`by` 400); a (tenant, kind) holds at most 20 pending corrections (429); a finding that is `resolved` or `stale` takes no more corrections (409); one (session, metric) takes at most 50 label versions (409). The findings, corrections and labels JSON is snake_case on REST, MCP and in storage; sink payloads are camelCase.

Finding states: `open`, `corrected` (a correction names it), `resolved` (its correction verified, or its alert resolved), `stale` (no correction and the series stayed above `findings.minScore` for `findings.window`). Correction states: `pending`, `verified`, `failed`.

## Usage and sessions

| MCP tool | Arguments | REST |
|---|---|---|
| `get_usage` | `hours?` (1 to 2160, default 24), `tenant?` (key or `<sender>/*`), `group?` (`kind`, `tenant`, `model`, `service`), `top?` (1 to 100) | `GET /api/usage?hours=&tenant=&bucket=hour\|day`, `GET /api/usage/calls?group=session&limit=`, `GET /api/usage/failed` |
| none | | `GET /api/usage/limits`: caps in force and what is used: online judge tokens and Jev calls, sessions in memory, retention in days, database on disk and volume in use |
| `list_sessions` | `limit?`, `agent?`, `tenant?`, `since?`, `query?`, `complete?`, `scored?`, `thread?` | `GET /api/streaming/sessions` |
| `summarize_session`, `get_session_spans` (`errors_only?`, `limit?`) | `session_id` | `GET /api/streaming/session-spans` |
| `list_threads` | `limit?`, `agent?`, `tenant?`, `since?`, `query?` | `GET /api/threads` |
| `get_ego_score`, `get_ego_tools`, `get_ego_errors` | `agent?`, `tenant?`, `hours?` (up to 720), `session_id?`; `by?` and `limit?` for the score | `GET /api/activity/score`, `/tools`, `/errors` |

`get_usage` and `/api/usage` need `--session-db` and are refused to a role limited to agents. They count tokens only; no cost is estimated by the tool (the UI shows an approximate cost for Claude models and marks it as approximate).

## Role bindings and tokens (admin)

| MCP tool | Arguments | REST |
|---|---|---|
| `list_role_bindings` | none | `GET /api/admin/roles` |
| `set_role_binding` | `subject_type` (`user`, `team`), `subject` (login, or `org/team-slug`), `role` (`admin`, `member`, `viewer`), `agents?`, `tenants?`, `id?` | `POST /api/admin/roles` body `{id?, subjectType, subject, role, agents?, tenants?}` |
| `delete_role_binding` | `id` | `DELETE /api/admin/roles/{id}` |
| none | | `GET`, `POST /api/admin/senders`; `DELETE /api/admin/senders/{id}`; `GET`, `POST /api/admin/senders/{id}/tokens`; `DELETE /api/admin/senders/{id}/tokens/{tokenId}` |
| none | | `POST /api/admin/revocations` body `{"tokenId":"tok-..."}` or `{"subject":"<name>"}` |
| none | | `POST /api/admin/tenant-names` body `{"key":"<sender>/<label>","name":"..."}` (empty name clears) |
| none | | `POST /api/admin/purge-tenants` body `{"keys":[...], "dryRun":true}`; keys only, never patterns |

Role management exists only when ego runs with a session secret. Without one the REST routes answer 503 ("role management requires --session-secret ...") and the MCP tools return the same error. Over stdio the three role tools are registered only with `ego mcp --admin-tools`.

Tokens from the command line: `ego auth mint-token --name <label> --role admin|member|viewer --tenants <keys> --ttl-days 90 --secret "$EGO_SESSION_SECRET"`; `--delegate --tenants '<sender>/*'` mints a token that opens `/mcp` only, where every `tools/call` must pass `tenant`. The token's id is printed on stderr.
