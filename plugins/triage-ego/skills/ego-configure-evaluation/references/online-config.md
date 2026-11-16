# Online evaluation configuration reference

Source: `internal/online/config.go` (struct tags, defaults, validation), `charts/ego/values.yaml` and `docs/online-evaluation.md`. The file is JSON; the decoder rejects unknown keys (`DisallowUnknownFields`), and a rejected file stops `serve` from starting. Durations are Go duration strings (`"6h"`, `"168h"`). In the chart the same document is `online.config` written as YAML and rendered to JSON, with `online.findings` rendered into its `findings` block.

## Top level

| Key | Default | Meaning |
|---|---|---|
| `budget.judgeTokensPerDay` | chart: 2000000; code: 0 | Gemini judge tokens per UTC day, shared by scoring, findings and anchor re-scoring. 0 with a Gemini evaluator in a profile is a config error |
| `budget.jevCallsPerDay` | chart: 1000; code: 0 | Jev calls per UTC day, one per scored invocation. 0 with a `jev_*` evaluator in a profile is a config error |
| `sampling` | see below | rates and dedup |
| `profiles` | none | kind to evaluators; at most 100 |
| `detector` | see below | regression test |
| `findings` | see below | diagnosis, verification, calibration |
| `sinks` | none | notification targets |
| `publicUrl` | none | prefix for session links in notifications (present in code, not in the docs or `values.yaml`) |
| `digestHourUTC` | 8 | hour of the daily Discord digest; -1 turns it off (code only) |

## `sampling`

| Key | Default | Meaning |
|---|---|---|
| `perKindPerHour` | 6 | base-lane sessions per (tenant, kind) per hour |
| `boostPerKindPerHour` | 6 | boost-lane rate (error, outlier, change) |
| `afterChangeSessions` | 20 | sessions boosted after a new `service.version` or model, or after a registered correction |
| `dedupWindow` | `6h` | a fingerprint scored inside this window, without an interest reason, is skipped |
| `trivial.maxUserChars` | 40 | a session with no tool calls, a first user message at most this long and a reply at most `maxReplyChars` is skipped |
| `trivial.maxReplyChars` | 100 | see above |
| `trivial.disabled` | false | turn the rule off |

A session with error spans or unreadable text is never skipped as trivial. Skip reasons are counted in `GET /api/online/status` under `counts`: `no_kind`, `no_profile`, `duplicate`, `rate`, `budget`, `no_invocations`, `already_seen`, `queue_full`, `trivial`; scored sessions are counted as `sampled_<reason>`.

## `profiles[]`

| Key | Default | Meaning |
|---|---|---|
| `kind` | required | `gen_ai.agent.name` or the root span name; a glob such as `*-spot` is allowed; an exact kind beats a glob |
| `service`, `tenant` | none | narrow the match; the most specific profile wins |
| `maxInvocations` | 3 | score only the last N invocations of a long session |
| `perHour` | 0 (takes `sampling.perKindPerHour`) | this profile's own base rate per (tenant, kind) |
| `evaluators[]` | required; at most 20 | see below |

Two profiles with the same kind, service and tenant are refused as duplicates.

## `profiles[].evaluators[]`

| Key | Default | Meaning |
|---|---|---|
| `name` | required | one of `hallucinations_v1`, `rubric_based_final_response_quality_v1`, `rubric_based_tool_use_quality_v1`, `jev_task_resolved`, `jev_grounded`, `jev_tool_use_appropriate`, `jev_response_kind`, `jev_custom` |
| `judgeModel` | `gemini-3-flash-preview` | a Gemini model name, `[A-Za-z0-9._-]{1,64}` |
| `numSamples` | 1 | judge samples per invocation, 1 to 5; the cost lever |
| `threshold` | 0.5 | a score below it is a failed result |
| `rubrics` | none | required for `rubric_based_*`; at most 50, not all blank |
| `questions` | none | required for `jev_custom`: a JSON object of questions (below) |
| `trajectoryMatchType` | `EXACT` | for trajectory metrics (not usable online, kept for the shared evaluator shape) |
| `type` | `builtin` | the shared evaluator shape; leave it out |

The loader refuses, with the reason in the error: an unknown name; `safety_v1` and the `multi_turn_*` metrics (Vertex managed evaluation, which the budget cannot meter); `final_response_match_v2`, `response_match_score`, `jev_matches_reference` (they need a golden eval set).

`jev_custom` questions, the same file shape `ego run --jev-questions` takes (there each key becomes a `jev:<key>` metric):

```json
{"escalates_correctly": {"type": "noul", "instructions": "Should this conversation have been escalated to on-call?",
  "criteria": {"true": "A production impact the agent cannot fix", "false": "Routine or resolved"}, "expect": false}}
```

`type` is `noul` (`expect` true or false, default true) or `choice` (`expect` must be one of the `criteria` labels); `instructions` is required.

## `detector`

| Key | Default | Meaning |
|---|---|---|
| `window` | `6h` | current period; must be shorter than `baseline` |
| `baseline` | `168h` | reference period before the window |
| `minSamples` | 12 | needed on both sides; at least 3 |
| `minDrop` | 0.1 | smallest drop of the mean that can alert |
| `every` | `10m` | tick (present in code, not in the docs) |

A regression also needs the drop to exceed 2.5 standard errors (Welch). An alert updates when the drop grows by another `minDrop` and resolves after two checks in a row with the drop under `minDrop / 2`.

## `findings`

| Key | Default | Range | Meaning |
|---|---|---|---|
| `enabled` | true | | false writes no findings; corrections are still registered and verified |
| `every` | `6h` | > 0 | sweep interval over series that stay below `minScore` |
| `window` | `24h` | > 0 | span of scores a finding is written from; also how long a series must stay healthy to go stale |
| `minSessions` | 8 | >= 1 | sessions a series needs in the window before the sweep judges it |
| `minScore` | 0.7 | (0, 1] | a series with enough sessions and a mean below this gets a finding |
| `maxSessions` | 8 | 1 to 20 | lowest-scoring sessions quoted as evidence |
| `verifyWithin` | `48h` | > 0 | a pending correction counts as failed after this |
| `minAgreement` | 0.7 | (0, 1] | label agreement under which a tenant's metric writes no findings (needs at least 10 labels in 7 days) |
| `recalibrateEvery` | `24h` | > 0 | anchor re-scoring interval |

## `sinks[]`

| Key | Meaning |
|---|---|
| `type` | `discord`, `webhook` or `event`; anything else is refused |
| `url` or `urlEnv` | one is required. `urlEnv` names an environment variable holding the URL, so a URL that carries a token stays out of the ConfigMap |
| `bearerTokenFile` | read on every send, so a projected token rotates |
| `digest` | send the daily digest to this sink (Discord only) |

Chart wiring: `online.discordSecret` names a Secret with key `DISCORD_WEBHOOK_URL`, injected as `EGO_DISCORD_WEBHOOK` (use `urlEnv: EGO_DISCORD_WEBHOOK`). `online.webhookToken.enabled` with `online.webhookToken.audience` projects a service-account token at `/var/run/secrets/ego/webhook/token` (use `bearerTokenFile: /var/run/secrets/ego/webhook/token`). Payloads: `webhook` carries `ego.quality.v1`, `ego.finding.v1` and `ego.correction.v1`; `event` carries `EvalQualityDegraded` / `EvalQualityRecovered`, `EvalFindingOpened` / `EvalFindingResolved`, `EvalCorrectionVerified` / `EvalCorrectionFailed`.

## Chart values around it

| Value | Default | Meaning |
|---|---|---|
| `online.enabled` | false | writes the ConfigMap `<name>-online`, mounts it at `/etc/ego/online.json` and passes `--online-config` |
| `online.config` | budget, sampling, detector defaults shown in `values.yaml`, `profiles: []`, `sinks: []` | the document above, as YAML |
| `online.findings` | `enabled: true, every: 6h, window: 24h, minSessions: 8, minScore: 0.7, maxSessions: 8, verifyWithin: 48h, minAgreement: 0.7, recalibrateEvery: 24h` | the `findings` block |

A change to either rolls the pod: the Deployment carries a checksum of the rendered document, and the file is read once at start.

## Runtime jobs (live, no restart)

`GET /api/online/jobs` returns `{perKindPerHour, profiles, source, unscored, budget}`; `PUT` replaces `{perKindPerHour, profiles}` as a whole (admin only; the document is checked like a file); `DELETE` returns to the file's jobs. The same is under settings, "scoring jobs". Saved jobs win over the file's `profiles` and `sampling.perKindPerHour` until they are deleted, so a Helm change to `online.config.profiles` has no effect while `source` is `stored`. Budgets, detector, findings and sinks are not jobs.
