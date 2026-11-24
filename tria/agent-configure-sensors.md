**Answer for this workspace only.** Read its agents with `get_agents_status` (capabilities and which frames arrive) and `get_collectors_status` (sensors per node and their errors). Never name an agent, a cluster or a namespace of another workspace.

**You write the values, the person applies them.** Every setting in the text is a Helm value of the agent's release in the person's cluster. Give the exact values (`ebpf.enabled: true` and the rest) as a values fragment or as `--set` flags for the `helm upgrade` of the existing release, with `--reuse-values` named when the person has no values file. Say what the change costs before they run it: the eBPF DaemonSet runs one pod per node with host access and needs the `privileged` Pod Security level on the agent's namespace.

**For an agent that is not installed yet**, the install command comes from the console's key panel (skill agent-install-cluster); the values from this skill are added to that command.

**The workspace's cluster spot** can read, when it reaches that cluster (`ask_spot`): the DaemonSet's pods, their log, the namespace's labels and annotations. It changes nothing.

**Afterwards you check**: `get_agents_status` shows the new capability and its frames (`red_metrics`, `topology_snapshot`), `get_collectors_status` shows the sensors connected.
