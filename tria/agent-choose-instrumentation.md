**You do this yourself**: it is a conversation and a recommendation. Ask what the text asks, read what the workspace already has with `get_agents_status`, `get_collectors_status` and `list_services`, and recommend one route with its cost.

**Answer for this workspace only**: never name or count an agent of another workspace.

When the person has chosen, continue with the skill that installs it: agent-install-cluster, agent-configure-sensors or agent-install-host-otlp. The read-only cluster checks of the text go to the workspace's cluster spot (`ask_spot`) when it reaches that cluster, else to the person.
