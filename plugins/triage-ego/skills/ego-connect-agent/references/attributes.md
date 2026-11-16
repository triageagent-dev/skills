# Attributes ego reads

Read from `internal/adk/attrs.go`, `internal/api/sessions.go`, `internal/api/segments.go`, `internal/api/senders.go`, `internal/api/usagestore.go`, `internal/online/features.go` and `internal/otlp/convert.go`. Resource attributes are merged onto every span of the export (they win on a key collision), so any attribute below can be set on the resource or on the span.

## Grouping

| Attribute | Effect |
|---|---|
| `ego.session_name` | Session name; wins over the next two |
| `gen_ai.conversation.id` | Session name when `ego.session_name` is absent |
| none of these | A synthetic session name; spans of one trace still group |
| `ego.thread` (resource attribute) | Declares an always-on agent. Opt-in. The thread is the value; ego cuts it into segments (`<thread>`, `<thread>~2`, ...) that are stored, listed and scored as sessions. Wins over `ego.session_name` |
| `ego.eval_set_id` (resource) | Ties a session to a saved eval set |

Session ids are namespaced `<sender>:<tenant>:<name>`. A plain session completes 30 s after its last span (3 s after a root span) and is queued for online scoring then; a late span reopens it and a scored session is not scored twice. A plain session holds at most 10000 spans. A thread's segment closes by `--segment-idle` (30m), `--segment-max-spans` (2000) or `--segment-max-age` (6h); one runaway trace is capped at 50000 spans.

## Tenant, agent, version

| Attribute | Effect |
|---|---|
| `ego.tenant` | Tenant label. This is the default; `--usage-tenant-attr` (`usageTenantAttr`) names another attribute, for example `triage.tenant` for a Triage core. The tenant key is `<sender>/<label>`. A named sender's span with no label belongs to the tenant `default` |
| `ego.tenant.name` | Display name of the tenant. The first name seen is kept while the tenant has none; only a named sender (one with its own token) can set it; at most 80 characters. An admin's name always wins |
| `gen_ai.agent.name` | The call kind of an LLM span, also the agent name in the UI and in role scopes. Without it the kind is the name of the trace's root span |
| `service.name` | Service of the session; the Usage view groups by it; the agent for Claude Code spans |
| `service.version` | Read from the span of the kind that used the most tokens. A version not seen for the kind in 24 hours starts a sampling burst and is named as the suspect of a regression |
| `gen_ai.request.model` | Model. A new model not seen for the kind in 24 hours also starts a burst |

## What makes a span an LLM or tool span

| Span type | A span is one when it has | 
|---|---|
| LLM call | `gen_ai.request.model`, or `openinference.span.kind` = `LLM`, or `llm.model_name`. Only LLM spans decide a session's kind and enter the usage ledger |
| Tool call | `gen_ai.tool.name`, or `tool.name` |
| Agent invocation | `gen_ai.operation.name` = `invoke_agent`, or a span name containing agent, chain, executor or workflow |
| Error | OTLP status `ERROR`, stored as `otel.status_code` = `ERROR` |

## Tokens and usage

The ledger gets one row per LLM span with at least one non-zero token count. Order of lookup:

1. ADK: `gcp.vertex.agent.llm_response` JSON with `usage_metadata.prompt_token_count` and `candidates_token_count`.
2. GenAI: `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`.
3. OpenInference: `llm.token_count.prompt`, `llm.token_count.completion`.

Cache parts, counted inside the input tokens: `gen_ai.usage.cache_read.input_tokens` and `gen_ai.usage.cache_creation.input_tokens` (or `gen_ai.usage.cache_write.input_tokens`). A failed request that reports no tokens has no ledger row.

## Content ego reads

| Attribute | Used for |
|---|---|
| `gen_ai.input.messages`, `gen_ai.output.messages` | Prompts and answers |
| `input.value`, `output.value` (OpenInference) | Prompts and answers |
| `gen_ai.tool.name`, `gen_ai.tool.call.id`, `gen_ai.tool.call.arguments`, `gen_ai.tool.call.result` | Tool calls and results. A model's tool call and the tool span that ran it count once |
| `gcp.vertex.agent.llm_request`, `gcp.vertex.agent.tool_call_args`, `gcp.vertex.agent.tool_response`, `gcp.vertex.agent.invocation_id`, `gcp.vertex.agent.event_id` | ADK |
| `temporal.*` and `tria.wake.key` on a turn's root span | Shown in the session header (Temporal workflow and run ids) |

An invocation's answer is the last call of the agent that opened it; a later call by another agent in the same conversation is not scored as the answer. Hallucination scoring sees the user message and that turn's tool calls and results only.

## Frameworks translated at ingest

| Sender | What ego adds | Notes |
|---|---|---|
| Claude Code (`claude_code.*` spans) | `gen_ai.*` attributes, token usage with cache reads and writes counted in the input, `gen_ai.conversation.id` = `session.id` | Label the tenant with `OTEL_RESOURCE_ATTRIBUTES=ego.tenant=<label>`; the agent is `service.name` (`claude-code` unless `OTEL_SERVICE_NAME` says otherwise). Redacted prompts are never stored |
| LangChain and LangGraph through LangSmith (`langsmith[otel]`, spans with `langsmith.span.kind`) | messages, tool arguments and results, `gen_ai.conversation.id` from metadata `thread_id`, else `conversation_id`, else `session_id` | The `LANGSMITH_*` variables are in the ego README under "LangChain and LangGraph". The exporter does not read `OTEL_RESOURCE_ATTRIBUTES`: label the tenant with a tenant-bound sender token, or with run metadata `tenant` plus `--usage-tenant-attr langsmith.metadata.tenant` |
| ADK, OpenTelemetry GenAI, OpenInference | read as they are | No SDK to add |

Not covered: OpenInference and Traceloop LangChain instrumentors (their message JSON in `input.value` is not unwrapped), and `/v1/logs`: frameworks that keep message content in log records instead of span attributes are not read.
