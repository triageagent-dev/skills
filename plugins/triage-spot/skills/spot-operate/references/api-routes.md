# Core routes and tools for spots

All routes take the caller's own credential: an SSO session, or a Kubernetes ServiceAccount token with audience
`triage-core`. "Manage" means write and exec on the workspace (roles owner and admin). Names: `<id>` is the workspace id,
`<name>` the spot's name. Checked against the core at main 1123dda59 (unreleased 3.6.0).

## REST

| Route | Grant | Answer and notes |
|---|---|---|
| `POST /v2/tenants/<id>/keys` body `{"label":"<name>","kind":"spot"}` | manage | 201 `{key, keyInfo, caFingerprint, install}`. `key` is `tak_<id>_<secret>`, shown once. `keyInfo` is `{id, label, cluster, kind, bindings, createdAt, createdBy, expiresAt}`; `cluster` is `spot:<id>/<name>`. Valid 7 days, one use. Name rules: lowercase letters, digits, dots, dashes, at most 40. 400 on a bad name, or when an unused key for that name exists; 403 without the grant; 404 inactive workspace. `install.spot` is a hint line naming `core.identity=certificate` and `core.caFingerprint`. When the core has the substrate router (deployment file `messenger.substrate`) the answer also has `actor: {name, atespace}`, the name the core addresses the actor by; the core derives it and notes that the actor is owed its first frame. |
| `GET /v2/tenants/<id>/keys` | manage | Unused, unexpired keys without their secret. |
| `DELETE /v2/tenants/<id>/keys/<keyId>` | manage | Revokes an unused key. |
| `GET /v2/tenants/<id>/spots` | read | `{"spots":[...]}`, the rows of `list_spots` plus `spot` and `workspace`: `name`, `runtime` (`deployment` or `substrate`), `state` (`connected`, `asleep`, `suspended`, `down`), `lastSeen`, `user`, `ownUser`, `inRooms`, `holder`, `oldest`, `firstSeen`, `joinedAt`, `certExpires`, `fingerprint`, `nextWake`, `nextWhy`. Every spot with a record seen in the last 7 days, and every spot that joined by certificate even if it has not called yet (`down`). A core without the messenger answers the older rows `{spot, workspace, fingerprint, approvedAt, notAfter}`. |
| `DELETE /v2/tenants/<id>/spots/<name>` | manage (403 before lookup) | Revokes the certificate if there is one, drops the row and wakes, clears the workspace's status mark when no other spot has fresh stats, ends the open stream. `{"status":"removed","revoked":bool,"forgotten":bool}`; 404 when nothing existed; 502 failed drop; 500 unreadable join state. A name that is no key's (the workspace's `spotName`) revokes nothing and still clears the row. |
| `GET /v2/agents` | admin | `{caFingerprint, agents}`. Each row has `type` (`agent` or `spot`), and for a spot `spot`, `workspace`, `cluster`=`spot:<id>/<name>`. The `caFingerprint` is the value for `core.caFingerprint`. Present only when the agent CA is configured. |
| `POST /v2/agents/revoke` body `{"cluster":"spot:<id>/<name>"}` | admin | Revokes, and drops a revoked spot's row and wakes. |
| `DELETE /v2/agents/<cluster>` | manage on every tenant it serves | Cannot take a spot's key (it holds a slash). Use the spots route. |
| `GET /v2/messenger/rooms` | read | The workspace room has `spot`: `state` (`up`/`down`), `name`, `stats`, `spots[]` (`id`, `stats`, `spent`), `budget` (the workspace's spot cap and spend), and `tria` (`promises`, `count`: the caller's own, all of them for an admin of the workspace). Admins also get rows of `kind: bus` (one per spot, with `spot.id`), readable through the messages route and never writable. |
| `GET /v2/messenger/spot/wakes?workspace=&spot=` | read | Newest 50 wakes, 24 hours: reason (`startup`, `tick`, `edge`, `human`, `manual`, `task`), lane, outcome, duration, steps, tool calls, tokens, plan (`next`, `nextWhy`, `nextSource`, `promises`). The newest 10 carry `trace`. |
| `GET /v2/messenger/spot/tasks?workspace=&spot=` | read | `{workspace, spot, ok, msg, tasks}`; 409 spot not connected, 504 no answer. |
| `POST /v2/messenger/spot/tasks/control` body `{workspace, spot, task, op}` | manage | `op` is `stop`, `kill`, `restart`, `drop` (these need `task`) or `wake` (no task: a wake with the reason `manual`). There is no pause. 403 without the grant, 400 missing workspace, spot or op. |
| `GET /v2/usage` | read | Hourly usage rows; kind `spot` carries a `spot` field. |
| `GET /v2/messenger/spot/ws?tenant=` | SA token with write | The ServiceAccount identity's trigger stream. |
| `GET /v2/messenger/spot/join` | none (proof by key) | The certificate identity's join and stream websocket (a Deployment spot). Needs `X-Triage-Agent-Nonce` (32 bytes, base64): 400 without. 404 when the core has no join (`spot join is not enabled`). 429 past 60 upgrades a minute from one source. |
| `POST /v2/messenger/spot/link` | none (proof by key) | A substrate actor's join, outside the session gate. Body `{"kind":"challenge"|"join"|"renew"|"hello", ...}`. A one-time key comes in `join.enrollKey` or, when that is empty, in the header `X-Triage-Enroll-Key` (the body wins). `hello` needs `runtime: "substrate"` and returns the 30-minute access token and the actor's name. A nonce that is expired, repeated or not the core's is 401, a certificate that does not verify 403, an unreadable join state 503. Hello is limited to 6 a minute per spot, join and renew to 600 a minute per source. |
| `POST /v2/messenger/spot/link/report` | `Authorization: Bearer <actor access token>` | An actor's `turn`, `stats`, `wake` and `schedule`, stored at once. An empty object only reads the budget. 200 `{"budget"}`; 401 for a token the core refuses (the actor says hello again); 429 past one report a second (burst 10), stats one every 5 seconds. |

The join frames: the core sends `challenge`; the spot answers `join` (CSR, proof, `enrollKey`), `renew` or
`hello`; the core answers a join or renewal with `join_result` (`issued` or `refused` with a message) and closes.
After a good `hello` the socket is the trigger stream, and the core sends `{"token":{"value","exp"}}`. Over the link
the same frames are plain requests and answers.

The core to an actor goes through the substrate ingress router (`routerURL` of `messenger.substrate`) to `POST /frame` on
the actor's port 80, with the header `ate-target-actor`. The frames are the stream's: `wake`, `rooms`, `control`. The
core adds the actor's last access token as a bearer; 401, 403 and 429 from the actor count as "busy", any other
transport error as `crashed`. A spot's `POST /v2/messenger/spot/link/tasks` (start a task actor) is in the spot at v0.9.0
and is not registered in the core at main 1123dda59.

## MCP tools

| Tool | Who | Notes |
|---|---|---|
| `get_spot_identity` | read | Workspace id and name, the name its owner gave the spot, and the ids of the workspace's spots. |
| `list_spots` | read | Every spot of the workspace with runtime, state, certificate dates and next wake (the rows of `GET /v2/tenants/<id>/spots`). |
| `say_in_workspace`, `read_workspace_room`, `read_workspace_file`, `set_workspace_typing` | write / read | A spot's voice: `room` is `team`, `agents` or `bus`. At v0.9.0 a spot uses `bus` only; `reply_to` (the request's id) and `memory` (the id of the item that holds the result) are for the bus. `say_in_workspace` caps: team 12 an hour, agents 60, bus 60, and it refuses a repeat of the last five. `read_workspace_room` with `room: bus` and `spot` is for an admin reading the audit trail; each message carries `due` or `memory` where it has one, and `mentions` and `forYou`. |
| `set_spot_status` | a spot only | One line, 140 characters, shown about six hours. Refused to non-spot callers and when the workspace's cap is used up (`your daily token cap is used up (<spent> of <cap>); the core takes no more from you until 00:00 UTC`). |
| `list_spot_tasks` | read | Key, title, lane, state, start, age. A Deployment spot must be connected; a suspended actor is answered from the core's record (empty list) without waking it. |
| `control_spot_task` | manage, confirm in chat | `op` `stop`, `kill`, `restart`, `drop` (by task key) or `wake` (no task, reason `manual`). Refused to spots and service accounts. Core sends a `control` frame and waits 10 seconds. |

Tria has these as her own tools: `ask_spot` (needs write access of the person she answers), `promise`, `list_promises`
and `drop_promise` exist only for her, and she also has `list_spots`, `get_spot_identity`, `list_spot_tasks`,
`control_spot_task` and `read_workspace_room`. People see only what Tria says about them.

## Policy keys

| Key | Default | Meaning |
|---|---|---|
| `budgets.spotDailyDefaultTokens` | 1,000,000 | Daily token cap per workspace for its spots, new input plus output. `0` = no cap. |
| `budgets.spotTenantDailyTokens` | empty | Per-workspace override. A present entry may be `0` (that workspace uncapped). |

The cap is read from the live policy; an edit applies at once. It is not counted in the instance, tenant or kind
caps.
