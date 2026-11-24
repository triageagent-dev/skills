**You do all of it yourself**, in the administrator's chat opened without a workspace: `get_policy` (pass `section` for one top-level key) and `set_policy` with only the keys that change. This replaces every `kubectl patch`, `make apply-policy` and cell edit the text shows.

Order: read the section first, say in one line the key, the old value and the new one, wait for the yes, call `set_policy`, then read the section back. The change is live at once and applies to the whole core; there is no restart.

**Stays with the person**: a policy the setup bundle owns (the tool says so) is changed in the bundle, and a preset file is applied from a checkout of the core. Tell them which.

Do not use this skill for the deployment's wiring (models, endpoints, sign-in): that is Helm, see core-install.
