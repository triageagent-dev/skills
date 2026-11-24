**Answer for this workspace only.** `get_agents_status` says which agents the workspace has. Never name an agent, a cluster or a namespace of another workspace, and never use one as an example.

**You write the command, the person runs it.** You have no kubectl or helm. Never answer that you cannot give a command.

1. Load the admin group (`load_tools`) and call `list_agent_keys` for the workspace. Its `install` holds, for each unused key, the complete `helm upgrade --install` command: the chart, the core's host, the CA fingerprint, the minted cluster name and the workspace, with `<KEY>` where the key goes.
2. No unused cluster key: ask the person to mint one in the console's workspaces panel (`mint_agent_key` is not offered to you, because the key is a secret shown to a person once), then call `list_agent_keys` again.
3. Give that command with the values the person asked for added as further `--set` lines: for eBPF `--set ebpf.enabled=true` (the skill agent-configure-sensors has the other sensor values and says what eBPF needs from the cluster). Keep `<KEY>` in it and say the person puts there the key the console showed when it was minted. Add the `kubectl annotate` line from `install`.

Never ask for the key and never repeat one that appears in the chat.

**You do these yourself**, with the admin group (`load_tools`): `list_agent_keys` and `revoke_agent_key`; for an install without a key `list_pending_agents`, then `approve_agent` or `deny_agent` after the person compared the fingerprint with the agent's own log; `bind_agent` and `unbind_agent`. After the install, `get_agents_status` proves the join: the agent is listed and connected.

**The workspace's cluster spot** can do the read-only steps when it reaches that same cluster (`ask_spot`): the existing release, the namespace annotations, the agent's pods and log. It changes nothing.

The `curl` calls to the core in the text are replaced by the tools above.
