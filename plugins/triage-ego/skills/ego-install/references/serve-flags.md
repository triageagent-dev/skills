# `ego serve` flags and environment

Every flag below was read from `cmd/ego/main.go`. A flag with an environment name takes the value from `EGO_<NAME>` when the flag is absent. The four listen-address flags have no environment name. Run `ego serve -h` for the text of the installed version.

## Listening

| Flag | Default | Chart passes | Purpose |
|---|---|---|---|
| `--addr` | `127.0.0.1:8001` | `:8001` | REST API, UI, live feed, `/mcp` |
| `--otlp-addr` | `127.0.0.1:4318` | `:4318` | OTLP/HTTP receiver, `POST /v1/traces` |
| `--otlp-grpc-addr` | `127.0.0.1:4317` | `:4317` | OTLP/gRPC receiver |
| `--health-addr` | `127.0.0.1:9090` | `:9090` | `GET /api/health`, never gated |

The container image runs `serve --addr :8001 --otlp-addr :4318 --otlp-grpc-addr :4317 --health-addr :9090` and exposes 8001, 4317, 4318 and 9090.

## Storage

| Flag | Environment | Default | Chart value |
|---|---|---|---|
| `--session-db` | `EGO_SESSION_DB_PATH` | none (memory only) | `persistence.dbFile` under `/data` |
| `--session-memory` | `EGO_SESSION_MEMORY` | 200 | `persistence.memorySessions` |
| `--session-retention` | `EGO_SESSION_RETENTION` | 720h (30 days) | `persistence.retention` |
| `--segment-idle` | `EGO_SEGMENT_IDLE` | 30m | none (use `extraEnv`) |
| `--segment-max-spans` | `EGO_SEGMENT_MAX_SPANS` | 2000 | none (use `extraEnv`) |
| `--segment-max-age` | `EGO_SEGMENT_MAX_AGE` | 6h | none (use `extraEnv`) |
| `--usage-tenant-attr` | `EGO_USAGE_TENANT_ATTR` | empty, which the code reads as `ego.tenant` | `usageTenantAttr` |

## Authentication and roles

| Flag | Environment | Default | Chart value |
|---|---|---|---|
| `--no-auth` | `EGO_NO_AUTH=true` | off | passed when `auth.enabled=false` |
| `--session-secret` | `EGO_SESSION_SECRET` | none; at least 32 bytes | Secret `auth.sessionSecret`, key `SESSION_SECRET` |
| `--github-client-id` | `EGO_GITHUB_CLIENT_ID` | none | `auth.githubClientId` |
| `--github-client-secret` | `EGO_GITHUB_CLIENT_SECRET` | none | Secret `auth.githubClientSecret`, key `GITHUB_CLIENT_SECRET` |
| `--github-org` | `EGO_GITHUB_ORG` | none | `auth.githubOrg` |
| `--public-url` | `EGO_PUBLIC_URL` | none | `auth.publicUrl` |
| `--admin-github-users` | `EGO_ADMIN_GITHUB_USERS` | none | `adminGithubUsers` |
| `--default-role` | `EGO_DEFAULT_ROLE` | `member` | `auth.defaultRole` |
| `--audit-log` | `EGO_AUDIT_LOG=true` | off | `auth.auditLog` |
| `--otlp-token` | `EGO_OTLP_TOKEN` | none; at least 32 bytes | Secret `otlpAuth.secret`, key `otlpAuth.key` (default `OTLP_TOKEN`) |

Start-up rules from `checkExposure` and `checkSecret`:

- A listen address that is not loopback, with no `--session-secret` and no `--no-auth`, makes `serve` exit with "refusing to listen ... without a login".
- `--no-auth` together with `--session-secret` exits with "contradicts".
- A session secret or OTLP token shorter than 32 bytes exits with an error that suggests `openssl rand -hex 32`.
- A GitHub client id and secret together need `--github-org`, `--session-secret` and `--public-url`, or `serve` exits. With a session secret and no client id and secret there is no browser sign-in route; only tokens from `ego auth mint-token` and sender tokens work.

## Evaluation and logging

| Flag | Environment | Default | Chart value |
|---|---|---|---|
| `--online-config` | `EGO_ONLINE_CONFIG` | none (online evaluation off) | `online.enabled` mounts `/etc/ego/online.json` |
| `--eval-daily-tokens` | `EGO_EVAL_DAILY_TOKENS` | 5000000; 0 is unlimited | none (use `extraEnv`) |
| `--log-level` | `EGO_LOG_LEVEL` | `info` | `logLevel` |

`--online-config` without `--session-db` makes `serve` exit with "--online-config needs --session-db".

## Judge and decision-model environment

These are read by the process, not by flags of `serve`.

| Variable | Used for |
|---|---|
| `GEMINI_API_KEY`, `GOOGLE_API_KEY` | Gemini Developer API judge |
| `GOOGLE_GENAI_USE_VERTEXAI=true`, `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION` | Vertex AI judge and Vertex managed metrics, with Application Default Credentials |
| `EGO_JUDGE_LOCATION` | Location of the Gemini judge alone, honoured only with `GOOGLE_GENAI_USE_VERTEXAI=true`. The chart sets it from `vertex.judgeLocation` |
| `EGO_DECISION_API_KEY` (or `JEV_API_KEY`) | Key for the default decision-model endpoint |
| `EGO_DECISION_URL` (or `JEV_API_URL`) | Endpoint of your own decision model |
| `EGO_DECISION_MODEL` (or `JEV_MODEL`) | Decision model name; default `jev-1.13` |
| `EGO_DECISION_MAX_STATE_BYTES` | Shorten a state larger than this before it is sent |

## `ego mcp` (stdio)

`--server-url` / `EGO_SERVER_URL` (default `http://localhost:8001`), `--session-token` / `EGO_SESSION_TOKEN` (else `gh auth token` unless `--no-gh-auth`), `--trace-dir` / `EGO_MCP_TRACE_DIR`, `--admin-tools`.

## `ego auth mint-token`

`--name` (required), `--role` (`admin`, `member`, `viewer`; default `member`), `--tenants`, `--delegate`, `--ttl-days` (default 90), `--secret` (default `EGO_SESSION_SECRET`).
