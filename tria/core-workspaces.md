**You do these yourself**, with the tools of the admin group (load it with `load_tools`): `list_workspaces`, `create_workspace`, `update_workspace` (name, licences, spots, trial end), `delete_workspace` and `restore_workspace`; members with `get_workspace_members`, `set_workspace_member` and `remove_workspace_member`; spots with `create_spot` and `remove_spot` (see the skill spot-install); agents with `list_workspace_agents`, `bind_agent` and `unbind_agent`. Every changing call waits for the person's yes in the chat.

**The person does these**: minting an agent key (`mint_agent_key` is not offered to you, because the key is a secret that must be shown to a person). Tell them to mint it in the console's workspaces panel, and never ask for the key in the chat.

**Not yours to do**: nothing in this skill needs kubectl. Where the text shows a `curl` call to `/v2/tenants`, the tool of the same purpose replaces it.

Say what you will change in one line before a changing call, and read the result back with the matching list tool afterwards.
