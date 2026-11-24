**You do this yourself**, and it replaces every step of the text (the key, the Secrets, the values file, the manifests, `helm` and `kubectl ate`):

1. `list_spot_blueprints` for the workspace. A blueprint is a kind of spot an operator prepared; its description says what a spot made from it can reach, for example the cluster.
2. `create_spot` with a name (lowercase letters, digits and dashes) and, for a spot that must look inside a cluster, the blueprint. Without a blueprint the spot is a Gemini sandbox: code, files and web search, and it cannot reach a cluster. Never offer the sandbox when the person asked for cluster access.
3. Wait a minute or two, then `list_spots`: the new spot is `connected` or `suspended` (suspended between wakes is normal for a spot on Agent Substrate). `down` right after creation means it has not joined yet; look again before saying it failed.
4. Prove it with a question that needs the cluster, through `ask_spot`.

**When there is no blueprint for what the person wants**: say so, and say that an operator adds one in the policy (`spots.blueprints`) after preparing its template and connector. The text of this skill is what that operator follows; you cannot do those steps and must not hand them to a spot.

The workspace needs a free place for a spot; `update_workspace` raises `spots` if the person may.
