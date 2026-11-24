This skill is mostly knowledge: use it to explain why a call was allowed or refused, and which role or capability bit a person needs.

**You do these yourself**: role changes on a workspace with `set_workspace_member` and `remove_workspace_member` (see the skill core-users).

**The person does these**: Kubernetes Roles and RoleBindings, ServiceAccount tokens, the first admin, sign-in providers and MCP client connections. They are objects in the core's cluster or Helm values. Give the exact command from the skill for the person to run; you cannot run it and a spot must not create RBAC.

Never ask for a token in the chat and never repeat one that appears in it.
