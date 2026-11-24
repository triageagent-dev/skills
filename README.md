# Triage skills

Skills for Claude Code (and any client that reads Agent Skills) that install and configure Triage: the core, the cluster agent, spots and ego.

```
/plugin marketplace add triageagent-dev/skills
/plugin install triage-core@triageagent-dev
/plugin install triage-agent@triageagent-dev
/plugin install triage-spot@triageagent-dev
/plugin install triage-ego@triageagent-dev
/plugin install triage-insights@triageagent-dev
/plugin install triage-xray@triageagent-dev
```

Then ask in your own words: "set up Triage from scratch", "install the core", "set a daily token limit", "join a cluster", "install a spot", "install ego", "install xray".

| Plugin | Skills |
|---|---|
| `triage-core` | `triage-bootstrap`, `core-install`, `core-access`, `core-users`, `core-policy`, `core-workspaces`, `core-service-graph`, `core-events-notifications`, `core-rsi`, `core-ego-link`, `core-evals` |
| `triage-agent` | `agent-choose-instrumentation`, `agent-configure-sensors`, `agent-install-cluster`, `agent-install-host-otlp`, `agent-troubleshoot` |
| `triage-spot` | `spot-configure`, `spot-install`, `spot-operate`, `spot-troubleshoot` |
| `triage-ego` | `ego-configure-evaluation`, `ego-connect-agent`, `ego-install`, `ego-rsi-operate` |
| `triage-insights` | `triage-insights`: ask Triage about issues, service health and memory over MCP |
| `triage-xray` | `xray-install`, `xray-connect`, `xray-access`, `xray-replicas`: install X-Ray, connect Claude Code to its memory over MCP, set who may use it, run more than one replica |

The skills change a cluster only for what you ask, say which context they run against, dry-run first, and never take a secret value in the conversation: they give you the `kubectl create secret` command to run yourself.
## Skills for Tria

Tria, the agent of a Triage core, can follow some of these skills in a person's private chat. `tria/map.yaml` lists which, for whom (`workspace` or `instance`) and when; `tria/<skill>.md` says for each who carries out its steps: Tria with her own tools, the workspace's cluster spot, or the person. A skill is not rewritten for her, and one the map does not name is not offered.

`make tria-check` checks the map against the tree. `make tria-bundle SKILLS_ARTIFACT=<registry/repo/skills-bundle>` pushes the tree as one OCI artifact and prints its digest-pinned reference, which goes into the core chart's `skills.ref`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for how a skill is written and checked.

Licensed under the [Apache License 2.0](LICENSE).
