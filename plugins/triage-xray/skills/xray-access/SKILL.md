---
name: xray-access
description: Set who may sign in to X-Ray and who gets the admin interface: GitHub, Entra and Google sign-in, --access-users and --access-admins, admitting a whole Google Workspace domain, MCP member access, writeAllowedUsers, "nobody can sign in", "I can sign in but MCP says 403". Use for "add a user to xray", "make me admin in xray", "let the whole domain in", "who can use xray". To install the server use xray-install, to connect a client use xray-connect.
---

# Who may use X-Ray

Three layers decide it. Read the current state first: `helm get values xray -n xray` and the server's
`args` in `kubectl -n xray get deploy xray -o jsonpath='{.spec.template.spec.containers[0].args}'`.

## 1. The provider's own gate

| Provider | Gate |
|---|---|
| GitHub | `--github-org`, narrowed by `--github-team` |
| Microsoft Entra | `--azure-tenant-id` |
| Google | `--google-domain`, matched on the ID token's `hd` claim |

Without the gate the server refuses to start; `--allow-any-user` admits every account and is rarely right.

## 2. Principal lists (any provider)

`--access-users` and `--access-admins`, or the environment variables `ACCESS_USERS` and `ACCESS_ADMINS`,
take comma-separated principals:

| Principal | Means |
|---|---|
| `google:<address>` | that address, in `--google-domain` (needs the flag) |
| `google:*@<domain>` | every address of `--google-domain`; in `--access-users` only |
| `github:<numeric user id>` | that GitHub user; the id, not the login, which can be renamed and re-registered |
| `azure:<object id>` | that Entra object id (a GUID), not the UPN |

- `--access-users` says who may sign in. `--access-admins` says who gets the admin interface (an MCP
  token, voice writes); an admin may also sign in.
- **With either list set, only listed principals sign in.** Set only `--access-admins` and only the
  admins can sign in. To admit a domain and name its admins, set
  `--access-users=google:*@example.com` and `--access-admins=google:alice@example.com`.
- `google:*@<domain>` grants sign-in and never admin. In `--access-admins`, with a `*` anywhere else in
  an address, or for another domain, the server refuses to start and says why.
- A malformed principal, a principal for a provider that is not configured, or a list that parses to
  nothing stops the server at start. Read `kubectl -n xray logs deploy/xray` if the pod restarts after an edit.
- The lists are checked at every sign-in, on every session use, at `/authorize` and for voice writes.

Find a GitHub id with `gh api users/<login> --jq .id`. Apply a change by editing `args` (or the
`ACCESS_*` variables) in the values file, dry-run, say what changes, then upgrade: it recreates the pod.

## 3. MCP and writes

- MCP is admin-only. `--mcp-member-access` (default off, needs `--mcp-oauth`) lets a signed-in person who
  is not an admin read shared memory and keep up to 1000 private notes of their own; they cannot read or
  change anyone else's private cells or write shared ones. Turning it off refuses member tokens already issued.
- `writeAllowedUsers` in the configuration cell (chart `voice.systemConfig.writeAllowedUsers`) is the older
  list of user hashes that may write by voice and MCP; `--access-admins` is the better way to name admins.
- The static `--mcp-token-secret` bearer is full scope and is outside these lists.

## Troubleshooting

| Symptom | Cause |
|---|---|
| nobody can sign in after setting a list | the list names only some people; add `google:*@<domain>` or the missing principals |
| the pod restarts after an edit | a principal is malformed; the log names it |
| signed in, MCP says 401 or 403 | not an admin and `--mcp-member-access` is off, or the token expired (`/mcp`, Authenticate) |
| a renamed GitHub user lost access | the list holds the numeric id, so the rename changes nothing; check the id |

## Done when

- A person named in the lists signs in and a person outside them is refused.
- An admin gets an MCP token with write scope; a member (with `--mcp-member-access`) gets read and `xray:memory.write.own`.

Written against X-Ray v2.10.1.
