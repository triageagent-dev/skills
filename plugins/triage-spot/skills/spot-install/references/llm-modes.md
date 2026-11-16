# Model provider and auth modes

Pick one row. The values go in the `llm:` block and `networkPolicy:` block of the values file. The chart fails to
render when a required value of the chosen mode is missing, and refuses `federation` with provider `gemini`. The chart
offers `key`, `federation` and `vertex`. The fourth mode, `injected`, is for a substrate actor and is a flag of the
actor's template, not a chart value (see the last section).

| Provider | Auth | Secret or identity | Required values | Egress |
|---|---|---|---|---|
| `anthropic` | `key` | Secret `llm.keySecret` (key name `key` by default), mounted as a file at `/secrets/anthropic/<key>` | `llm.keySecret.name` | `networkPolicy.anthropic` (defaults: the CIDRs Anthropic publishes, port 443) |
| `anthropic` | `federation` | A projected ServiceAccount token at `/var/run/secrets/anthropic.com/token`; no Secret | `llm.federation.ruleId`, `orgId`, `serviceAccountId`; optional `workspaceId` | `networkPolicy.anthropic` |
| `anthropic` | `vertex` | The pod's Workload Identity (Application Default Credentials); nothing mounted | `llm.vertex.project`; `region` defaults to `global`; ServiceAccount annotation | `networkPolicy.google.cidrs` (you name them) and `networkPolicy.google.metadata` |
| `gemini` | `key` | Secret `llm.geminiKeySecret`, mounted at `/secrets/gemini/<key>` | `llm.geminiKeySecret.name` | `networkPolicy.google.cidrs` (you name them) |
| `gemini` | `vertex` | Workload Identity, as above | `llm.vertex.project` | `networkPolicy.google.cidrs` and `.metadata` |

## Anthropic with a key

```yaml
llm:
  provider: anthropic
  auth: key
  keySecret: {name: spot-a-model-key, key: key}
```

The key is read from the file on every request, so rotating the Secret needs no restart.

## Anthropic with federation

No Anthropic secret exists. The ids are not secrets.

```yaml
llm:
  provider: anthropic
  auth: federation
  federation:
    ruleId: fdrl_<id>
    orgId: <organization id>
    serviceAccountId: svac_<id>
    workspaceId: wrkspc_<id>        # optional when the rule spans one workspace
```

The federation rule in the Claude Console has to match the pod's ServiceAccount. The token's subject is the
standard Kubernetes form `system:serviceaccount:<namespace>:<serviceaccount name>`; check Anthropic's federation
documentation for the rule fields. The chart does not verify the rule.

A rule that does not match shows as a 401 on the first model call. The spot's log says: `Anthropic
authentication failed in federation mode; check the authentication history in the Claude Console (jti_reused /
match_*)`. The repository states that whether the token is reused across exchanges (`jti_reused`) was not tested
against the real API.

## Vertex AI (either provider)

```yaml
llm:
  provider: anthropic              # or gemini
  auth: vertex
  vertex: {project: <gcp project>, region: global}
serviceAccount:
  annotations:
    iam.gke.io/gcp-service-account: <google-sa>@<gcp project>.iam.gserviceaccount.com
networkPolicy:
  google:
    cidrs: [<ranges of the Google APIs your network uses>]
```

The Google service account must be allowed on Vertex AI in that project, and bound to the pod's Kubernetes
ServiceAccount for Workload Identity. `networkPolicy.google.metadata` defaults to GKE's metadata server
addresses and ports (`169.254.169.252/32`, `169.254.169.254/32`; 988, 80). The model id has no prefix on Vertex AI.
The repository lists the egress ranges and model id for Claude on a real Vertex AI project as not verified.

## Gemini with a key

```yaml
llm:
  provider: gemini
  auth: key
  geminiKeySecret: {name: spot-a-gemini-key, key: key}
networkPolicy:
  google:
    cidrs: [<ranges of the Google APIs your network uses>]
```

An empty or missing key file stops the start. `GOOGLE_API_KEY` and `GEMINI_API_KEY` are never read.

## Anthropic injected (a substrate actor)

An actor holds no model credential. The template sets `--llm-provider=anthropic --llm-auth=injected`; the spot sends a
fixed placeholder `x-api-key` to `https://api.anthropic.com` (or `--llm-base-url` when the API is behind another URL, and
the environment is not read). The actor's EgressPolicy has a rule for that host that replaces the header with the value
of a Kubernetes Secret, `credentialUri: ate-secret://k8s.io/default/<namespace>/<secret>/<key>`, and only a request that
carries the header is changed. The key never reaches the sandbox, the image or the template.

```yaml
# in the egress policy
- https:
    hostnames: [api.anthropic.com]
    effects:
      replaceHeaders:
      - header: x-api-key
        credentialUri: ate-secret://k8s.io/default/<namespace>/<model key Secret>/<key>
```

Rules from the specification: Anthropic only (Gemini refuses `injected`); the rule is `https`, so the egress gateway
ends TLS and the template must mount the trust bundle and set `SSL_CERT_FILE`; the atespace must be allowed to read the
Secret's namespace. Rotating the key is a Secret update with no actor change. `--llm-auth=injected` outside the
substrate runtime needs `--llm-base-url`, a proxy that puts the key on the request. The core's ADR-107 names Vertex AI
through the platform's gateway as an option behind the same placeholder; the spot repository documents only the
Anthropic `injected` mode.

## Model choice

`llm.model` empty selects the provider's default: `claude-opus-5-5` for Anthropic, `gemini-3-flash-preview` for
Gemini. `llm.effort` is `low`, `medium` (default), `high`, `xhigh` or `max`. The substrate template in the spot
repository passes `--model=claude-sonnet-5-5`. The v0.9.0 release notes name no other default.
