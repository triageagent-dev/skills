# Metrics, what each needs, where each runs

Source: `README.md` (Metrics), `docs/STATUS.md`, `cmd/ego/main.go` (`judgeMetrics`, `vertexEvalMetrics`), `internal/online/config.go` (`judgeEvaluators`, `unmeteredMetrics`, `referenceMetrics`). `GET /api/metrics` lists the same metrics with `requiresEvalSet`, `requiresLLM`, `requiresGCP` and `requiresRubrics` for the installed version; `ego run` and `POST /api/evaluate` accept all of them.

| Metric | Family | Needs | `ego run` / `/api/evaluate` | Online profile |
|---|---|---|---|---|
| `tool_trajectory_avg_score` | algorithm | eval set | yes | refused (eval set) |
| `response_match_score` (ROUGE-1) | algorithm | eval set | yes | refused (eval set) |
| `final_response_match_v2` | Gemini judge | eval set and judge model | yes | refused (eval set) |
| `rubric_based_final_response_quality_v1` | Gemini judge | judge model, rubrics (`--rubric`, repeatable) | yes | yes, `rubrics` required |
| `rubric_based_tool_use_quality_v1` | Gemini judge | judge model, rubrics | yes | yes, `rubrics` required |
| `hallucinations_v1` | Gemini judge | judge model | yes | yes |
| `safety_v1` | Vertex managed eval | Application Default Credentials, `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION` | yes | refused (budget cannot meter it) |
| `multi_turn_task_success_v1`, `multi_turn_trajectory_quality_v1`, `multi_turn_tool_use_quality_v1` | Vertex managed eval | same as `safety_v1` | yes | refused |
| `jev_task_resolved`, `jev_grounded`, `jev_tool_use_appropriate`, `jev_response_kind` | decision model | decision model access | yes | yes, counted in `jevCallsPerDay` |
| `jev_matches_reference` | decision model | decision model, eval set | yes | refused (eval set) |
| custom `jev:<key>` | decision model | `--jev-questions` file | yes (`ego run`) | as evaluator `jev_custom` with `questions` |

Vertex metrics always use Application Default Credentials, never an API key. They report no token counts, so interactive runs are limited by concurrency and request caps only.

## What the judges see

- `hallucinations_v1` checks the response against the user's message and that turn's tool calls and results (each result capped at 6000 characters, 24000 per turn). Earlier turns and the agent's own instructions are not in the context, so a claim that rests on them reads as unsupported.
- The default judge model is `gemini-3-flash-preview`; an evaluator names another with `judgeModel`. A judge call is capped at 8192 output tokens.
- Quoted trace text in a judge prompt is fenced and defanged and every call opens with a notice that quoted text is data. This lowers prompt-injection risk and does not remove it; Jev prompts are defanged only for the state they carry.
- For a thread's segment n >= 2 the Gemini judges get the last user prompt and final answer of segment n-1 as fenced context. Jev and Vertex evaluators do not.

## Judge access

| Judge | How the process finds it | Chart | Local or container |
|---|---|---|---|
| Gemini Developer API | `GEMINI_API_KEY` or `GOOGLE_API_KEY`; `ego run --judge-api-key` overrides | no dedicated value: add the variable to `extraEnv` from a Secret with `valueFrom.secretKeyRef` | environment variable |
| Gemini on Vertex AI | `GOOGLE_GENAI_USE_VERTEXAI=true`, `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION`, Application Default Credentials; `EGO_JUDGE_LOCATION` sets the judge's own location (newest Gemini models are served from `global`) | `vertex.enabled`, `vertex.project`, `vertex.location`, `vertex.judgeLocation` (default `global`), `serviceAccount.annotations` for Workload Identity | the same variables, `gcloud auth application-default login` or a service account |
| Vertex managed eval | `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION`, ADC | same as above | same |
| Jev, default endpoint | `EGO_DECISION_API_KEY` (or `JEV_API_KEY`); model `EGO_DECISION_MODEL` (or `JEV_MODEL`), default `jev-1.13` | Secret named by `jevSecret` (default `ego-jev`, optional) with key `JEV_API_KEY`; `decision.model` | environment variable |
| Decision model of your own (Ollama 0.35 or later, `/v1/systemone`, or any server speaking the decisions API) | `EGO_DECISION_URL` (or `JEV_API_URL`); needs no key unless the server asks; `EGO_DECISION_MAX_STATE_BYTES` shortens long states for a small context | `decision.url`, `decision.model`, `decision.maxStateBytes` | environment variables |

`GET /api/config` answers `data.apiKeys.google` (true when a Gemini key is set, or Vertex AI is configured with a project) and `data.apiKeys.jev` (true when a decision key or URL is set). It reports that the variables exist, not that the credentials work; a credential that does not work makes the metric report an error (the `jev_*` case is logged at start as "they will report errors").

`score` questions are not sent to a decision model yet. A decision model that runs on a small context needs `EGO_DECISION_MAX_STATE_BYTES`, and its scores should be checked against labelled sessions before anyone relies on them.

## Limits of interactive evaluation

At most 4 evaluations at once, 50 trace files, 20 evaluators, 8 judge samples and 50 rubrics per evaluator per request. One daily judge-token cap shared by all callers (`--eval-daily-tokens`, default 5,000,000 per UTC day, 0 unlimited; 429 when used up; one user can take a quarter of it; admins are exempt). `ego run` offline has no ego-side cap; it spends the caller's own judge credentials, with `--judge-samples` defaulting to 5.
