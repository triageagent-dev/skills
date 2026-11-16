# Application Passport — triageagent-dev/skills

## 1. Identity

| Field | Value |
|---|---|
| Component | skills (Claude Code plugin marketplace `triageagent-dev`) |
| Description | Installation, configuration and operation procedures for Triage (core, cluster agent, spot, ego) and a query skill for the Triage MCP server |
| Repo | https://github.com/triageagent-dev/skills |
| Registry | none; distributed by `/plugin marketplace add triageagent-dev/skills` |
| Version | commit a9254a4 on `main` (all counts in this document are taken from that commit), no git tags; plugin versions: triage-core 0.2.0, triage-agent 0.1.0, triage-spot 0.2.0, triage-ego 0.1.0, triage-insights 2.15.41 |
| Owner | Triage Agent (`owner.name` in `.claude-plugin/marketplace.json`) |
| License | Apache-2.0 (`LICENSE`, copyright line "2026 triageagent-dev"; `license` set in all five `plugin.json`) |
| Date | 2026-11-15 |
| Audit status | No HIGH or CRITICAL findings open; MEDIUM and LOW open (audit 2026-11-16, commit 665563c) |
| Code review | Findings open (2026-11-16, commit 665563c) |

## 2. Classification

| Field | Value |
|---|---|
| Class | Plugin marketplace (documents, one shell script) |
| Type | Skills (instruction sets read by an AI assistant); one install script |
| Plugins | 5: triage-core, triage-agent, triage-spot, triage-ego, triage-insights |
| Skills | 25 `SKILL.md` files: core 11, agent 5, spot 4, ego 4, insights 1 |
| Supporting files | 16 reference files, 1 asset (`values-certificate.yaml`), 1 shell script (`plugins/triage-insights/install.sh`) |
| Capabilities | Instruct an assistant to run kubectl, helm, curl, jq, openssl, make, git, docker, cosign, sudo/systemctl and MCP client registration commands against the user's clusters, hosts and Triage core |
| Model role | Prompt content for the user's assistant; no model is called by this repository |
| Runtime | The user's assistant session (Claude Code; the insights skill also lists Codex and GitHub Copilot CLI) |
| Public accessibility | Repository visibility is a GitHub setting; content is written with public names only (`CONTRIBUTING.md`) |
| Production data access | Through the user's kubeconfig, Triage API credentials and MCP session; read and write |
| PII | none stored; commands handle GitHub logins, workspace and agent names |
| Sensitivity | Procedures create and read Kubernetes Secrets, Triage agent and spot enrollment keys, ServiceAccount tokens, OAuth client secrets, notification webhook URLs and a certificate authority key |

## 3. Artifact

| Field | Value |
|---|---|
| Form | Git repository of Markdown, YAML, JSON and one POSIX shell script |
| Language | Markdown (skills), YAML (values files), JSON (manifests), POSIX sh |
| Build tool | none |
| Base image | none |
| Runtime user | the invoking user |
| Manifests | `.claude-plugin/marketplace.json` and five `plugins/*/.claude-plugin/plugin.json`; `claude plugin validate .` passes |
| SKILL.md frontmatter | `name` and `description` in all 25 skills |
| SKILL.md length | 58 to 371 lines |
| Install script | `plugins/triage-insights/install.sh`: copies `skills/triage-insights` into `~/.claude/skills`, `~/.codex/skills`, `~/.copilot/skills`, or with `--project <dir>` into `<dir>/.claude/skills`, `<dir>/.agents/skills`, `<dir>/.github/skills`; removes the existing `triage-insights` directory at the target first; no network access, no sudo |

## 4. AI / LLM Supply Chain

| Item | Value |
|---|---|
| Models called by this repository | none |
| LLM auth | none held in the repository |
| Consumers | assistants that load Agent Skills (Claude Code, Codex, GitHub Copilot CLI) |
| Frontmatter tool scopes (`allowed-tools`) | none declared |
| Skills that state logs, API or tool output is data, not instructions | 25 of 25 |
| Skills that name Triage MCP tools | agent-install-cluster, core-access, core-events-notifications, core-policy, core-rsi, core-users, core-workspaces, triage-bootstrap, triage-insights, spot-configure, spot-install, spot-operate, spot-troubleshoot |
| Mutating MCP tools named in triage-insights | resolve_issue, comment_on_issue, update_issue_severity, link_issues, forget_issue, upsert_memory_item, supersede_memory_item, expire_memory_item, set_tenant_goals, build_rca, run_rsi, test_push, test_notify, build_memory, build_knowledge |

## 5. Privileges

| Scope | What the skills instruct | Where |
|---|---|---|
| Kubernetes RBAC creation | ServiceAccount `triage-admin` with RoleBinding to Role `triage-admin` (all capability bits on every workspace); RoleBindings for GitHub users and teams | core-access |
| Kubernetes Secrets | creates Secrets for CA key, OAuth client secret, model key, Teams token, notification URLs, enrollment keys, OTLP tokens, UI admin key, API tokens; secret values are typed by the person in their own terminal and read from standard input or a 0600 file | core-install, core-events-notifications, core-ego-link, spot-install, ego-install, ego-connect-agent, agent-configure-sensors, agent-troubleshoot |
| Cluster-wide agent workload | eBPF DaemonSet with `hostPID: true`; optional `hostNetwork: true`, `privileged: true`, extra capability `SYS_ADMIN` | agent-configure-sensors |
| Namespace mutation | `kubectl annotate namespace`; `kubectl create namespace`; Helm `--create-namespace` | agent-install-cluster, agent-troubleshoot, core-service-graph, core-install, spot-install, agent-install-host-otlp |
| Helm | `helm upgrade --install`, `helm install`, `helm upgrade`, `helm template`; `helm uninstall` named for agent, ego and spot removal | all install and operate skills |
| Cluster objects applied with kubectl | MemoryCells (policy, service graph, notification routing, spot prompt) via `kubectl apply` or `make apply-*` targets that run `kubectl apply --server-side --force-conflicts` | core-policy, core-service-graph, core-events-notifications, core-users |
| Triage REST API | tenant create, patch, delete and restore; member and key management; agent approve and revoke; notification channels; spot removal | core-workspaces, core-users, agent-install-cluster, spot-operate |
| Host | `sudo sh install.sh`, `sudo systemctl restart triage-agent`, `sudo systemctl enable --now triage-agent`, `sudo install` into `/var/lib/triage-agent` | agent-install-host-otlp |
| Fault injection | otel-demo suite scales, crashes, throttles, network-denies and kills pods of namespace `otel-demo`; creates ServiceAccount `triage-eval` | core-evals |
| Assistant configuration | `claude mcp add`, `codex mcp add`, `copilot mcp add`; copying `skills/ego-rsi` into `~/.claude/skills` | core-access, triage-insights, ego-connect-agent |
| Local files | writes `mint.json`, `agent.key`, `ui-admin.key`, `api-tokens`, `policy.yaml`, `current.yaml`, `collector-otlp-secret.yaml`, `spot-instruction-cell.yaml`, `ca.key` in the working directory or a temp directory | agent-install-cluster, agent-install-host-otlp, agent-configure-sensors, core-access, core-policy, core-install, core-workspaces, spot-install, spot-configure, ego-install |
| Confirmation language | states a context or asks before a change in 24 of 25 skills: agent-choose-instrumentation, agent-configure-sensors, agent-install-cluster, agent-install-host-otlp, agent-troubleshoot, core-access, core-ego-link, core-evals, core-events-notifications, core-install, core-policy, core-rsi, core-service-graph, core-users, core-workspaces, triage-bootstrap, ego-configure-evaluation, ego-connect-agent, ego-install, ego-rsi-operate, spot-configure, spot-install, spot-operate, spot-troubleshoot | skills named |

## 6. Network Surface

| Item | Value |
|---|---|
| Listening ports | none |
| Deployed auth state | not applicable |
| Outbound from install.sh | none |
| External hosts the skills tell the user to fetch from | ghcr.io/triageagent-dev (charts `triage-core`, `triage-agent`, `tria-spot`, `ego`; images `core`, `agent`, `spot`, `ego`), github.com/triageagent-dev/{agent,spot,ego} (releases, clone), raw.githubusercontent.com/triageagent-dev/ego (install script), token.actions.githubusercontent.com (cosign issuer) |
| Other hosts named | `<core-host>`, `<ego-host>`, `<triage-host>` placeholders; Anthropic API CIDRs 160.79.104.0/23 and 2607:6bc0::/48 in the spot values reference |

## 7. Dependency Vulnerabilities

| Ecosystem | Manifest | Components (syft CycloneDX 1.6) | CRITICAL | HIGH | MEDIUM | LOW |
|---|---|---|---|---|---|---|
| none | no go.mod, package-lock.json, requirements.txt, Cargo.lock, pyproject.toml, Dockerfile | 0 | 0 | 0 | 0 | 0 |
