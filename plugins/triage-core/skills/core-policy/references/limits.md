# Compiled defaults that matter

These are `policy.Default()` in the core. A policy cell overrides them field by field.

## Budgets (tokens per UTC day unless noted)

| Key | Default | Notes |
|---|---|---|
| `budgets.llmDailyTokens` | 1,000,000 | instance total; covers routing, guardrail, RCA, reflection, knowledge, RSI. 0 = unlimited |
| `budgets.llmGuardrailReserveTokens` | 20,000 | extra headroom for the guardrail alone, so exhausting the pool does not drop every human event |
| `budgets.llmTenantDailyDefaultTokens` | 100,000 | per workspace; the guardrail is exempt. 0 = uncapped |
| `budgets.llmKindDailyTokens` | agent 400k, reflection 250k, knowledge 250k, rca 100k, guardrail 100k, rsi 50k, chat 100k, voice 100k | per workspace and kind; known kinds: agent, guardrail, rca, reflection, knowledge, rsi, chat, voice |
| `budgets.llmKindDailyDefaultTokens` | 100,000 | kinds not in the table |
| `budgets.llmKindMaxOutputTokens` | agent 8192 | per response, thinking included; 0 or at least 4096 |
| `budgets.chatUserDailyTokens` | 1,000,000 | per person |
| `budgets.voiceUserDailyTokens` | 100,000 | per person |
| `budgets.voiceTenantDailyDefaultTokens` | 0 (uncapped) | per workspace |
| `budgets.spotDailyDefaultTokens` | 1,000,000 | per workspace's spot; 0 = no cap |
| `decisions.dailyTokens` | 200,000 | decision model, per workspace, separate from the above |
| `budgets.agentEventsDailyDefault` | 0 (uncapped) | events per agent per 24 hours |
| `budgets.agentEventsDailyRegistry`, `agentFramesPerSecond` | compiled constants | caps for agents of self-registered workspaces and frames per second per connection |

A model call passes the gates in this order: the instance cap (widened by the guardrail reserve for a guardrail call), the call kind's cap for that workspace, then the
workspace cap (a guardrail call is exempt). Failed calls count: the ledger records what the provider billed. Circuit breaker: 5 failures, 60 s, fixed.

## Loops and classification

| Key | Default |
|---|---|
| `loops.reflection.interval` | 180m |
| `loops.knowledge.interval` | 480m |
| `loops.reflection.cooldown`, `loops.knowledge.cooldown` | 60m (the compiled `PassCooldown`) |
| `classification.reopenWindow` | 6h |
| `classification.flapSuppression.minReopens` | 5 |
| `classification.noiseThreshold` / `issueThreshold` | 0.2 / 0.5 (a tenant's own graph cell can carry its thresholds) |
| `concerns.recoveryHysteresis` | 5m |
| `predictions.minConfidence` | 0.5 |
| `alerts.repeatInterval` | 1h |

## Retention (days)

events 7, resolvedConcerns 90, analytics 30, knowledge 90, episodic 180.

## Auth

`auth.mcpTokenTTL` 15m, `failureBurst` 10, `failureRefill` 1s, `failureCutoff` 5m, `reviewPerSource` 50.

## Workspaces

`workspaces.trial`: `days` 14, `maxPerOrg` 1, `licences` 3. A trial's limits come from policy and never from the request.

## RSI

Off by default (`rsi.enabled: false`, mode `shadow`). See core-rsi.
