**You do these yourself**: `get_workspace_members` to see who has which role, `set_workspace_member` to give or change a role (owner, admin, member, viewer), `remove_workspace_member` to take it away. The subject is `<provider>:<id>`, for example `github:alice`; ask for it when the person gives only a name.

**The person does these**: anything about how people sign in (the GitHub organisation or team, OIDC, token lifetimes). That is the core's deployment configuration, set with Helm values by whoever installed the core. Give them the section of the skill that names the value; do not offer to change it.

When someone "can sign in but sees nothing", read the workspace's members first: the usual cause is no role on that workspace.
