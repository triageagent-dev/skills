---
name: xray-install
description: Install X-Ray, the agentic memory and code-graph server, on Kubernetes with the published Helm chart: namespace, MCP token Secret, sign-in, public address, ingress, a trial through port-forward, upgrade. Use for "install xray", "deploy x-ray", "helm install xray", "set up X-Ray memory", "upgrade xray", "xray does not start", "xray refuses to start". For who may sign in use xray-access, to connect Claude Code use xray-connect, for more than one replica use xray-replicas.
---

# Install X-Ray

X-Ray keeps memory as `MemoryCell` custom resources in the cluster and serves it by keyword and by
meaning over a web UI, REST, MCP and Gemini Live voice. It is one binary, `xray`. The image is
`ghcr.io/triageagent-dev/xray:<version>` and the chart is `oci://ghcr.io/triageagent-dev/charts/xray`.

## 1. Read the state

Run these and say what you found before changing anything. Ask which kube context to use if it is not
obvious, and run every command against it.

```sh
kubectl config current-context
helm list -A | grep -i xray
kubectl get ns xray
kubectl get crd memorycells.xray.triageagent.dev
helm show chart oci://ghcr.io/triageagent-dev/charts/xray      # the newest published version
```

Use a namespace of its own. The server may list and watch every Secret in its namespace (it finds
the token Secrets of MCP servers at session time), so a shared namespace exposes the other workloads'
Secrets to it.

## 2. A trial

Sign-in is off and the server is reached through `kubectl port-forward`. Use it to look, not to run.
The token Secret is generated on your machine and never printed.

```sh
kubectl create namespace xray
openssl rand -hex 24 | kubectl -n xray create secret generic xray-mcp-token --from-file=token=/dev/stdin
helm upgrade --install xray oci://ghcr.io/triageagent-dev/charts/xray --version <version> -n xray --set dev=true
kubectl -n xray rollout status deploy/xray
kubectl -n xray port-forward svc/xray 8080:80 8083:8083
```

`dev=true` adds `--dev`: sign-in off, any origin accepted. The web UI is at http://localhost:8080, MCP
at port 8083 with `Authorization: Bearer <token>`. For a private registry, create a pull secret in
the namespace and add `--set 'imagePullSecrets[0].name=<secret>'`.

## 3. Real use

Without `--dev` the server stops at start unless it has a sign-in method and the address users reach,
and the log says which is missing.

1. Create the MCP token Secret as above. The chart's `mcp.tokenSecret` default is `xray-mcp-token`.
2. Create the sign-in Secret from a file you control, one provider at least:

   | Provider | Chart value | Secret keys | Server flags |
   |---|---|---|---|
   | GitHub | `github.secretName` | `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` | `--github-org=<org>` (or `--github-team`) |
   | Microsoft Entra | `azure.secretName` | `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID` | |
   | Google | `google.secretName` | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_DOMAIN` | |

   ```sh
   kubectl -n xray create secret generic github-oauth --from-env-file=<file-with-the-keys>
   ```

   GitHub without `--github-org` or Google without `GOOGLE_DOMAIN` would admit any account of that
   provider, so the server refuses to start; `--allow-any-user` overrides that and is almost never
   what you want. The provider's OAuth app uses the callback under your public address.
3. Write the values file from the chart's own, so the new keys show:

   ```sh
   helm show values oci://ghcr.io/triageagent-dev/charts/xray --version <version> > values.yaml
   ```

   Set `github.secretName` (or `azure.secretName`, `google.secretName`), and in `args` add
   `--public-url=https://xray.example.com` and `--github-org=<org>`. Expose it with `ingress.enabled`
   and `ingress.hostname`, or with `httpRoute` for a Gateway API route. A path in `--public-url`
   (`https://gw.example.com/path`) mounts the server there, and the UI must be built with
   `BASE_PATH=/path`.
4. For a token per MCP user instead of the shared secret, set `mcp.oauth.enabled: true`, add
   `--mcp-oauth`, `--mcp-resource-url=https://xray.example.com/mcp` and `--mcp-token-ttl=3h`, and
   remove `--mcp-address=:8083`. `xray-connect` covers the client side.
5. Dry-run and print only what matters:

   ```sh
   helm template xray oci://ghcr.io/triageagent-dev/charts/xray --version <version> -n xray -f values.yaml | grep -E '^\s+- --|image:'
   ```

   Never print the whole render. Say what will be created, wait for a yes, then:

   ```sh
   helm upgrade --install xray oci://ghcr.io/triageagent-dev/charts/xray --version <version> -n xray -f values.yaml
   ```

Embeddings run in a sidecar in the pod on `localhost:8090` with the model baked into its image
(`embedding.sidecar.enabled`). Voice needs a Google Cloud project or a Gemini key (`voice.*`,
`--gcp-project`, `--gemini-api-key`); search and MCP work without it. Check the chart's `values.yaml`
for the rest.

## 4. Verify

```sh
kubectl -n xray rollout status deploy/xray
kubectl -n xray logs deploy/xray | grep -E "xray server ready|MemoryCell seed complete"
curl -s https://<xray-host>/v1/version
```

## 5. Upgrade

1. `helm get values xray -n xray > current.yaml` (it holds Secret names, not values) and compare it with
   `helm show values oci://ghcr.io/triageagent-dev/charts/xray --version <new>`.
2. Helm never upgrades a CRD. Read the diff, then apply the new one by hand:
   `helm show crds oci://ghcr.io/triageagent-dev/charts/xray --version <new> | kubectl apply -f -`.
3. Dry-run as above, say what changes, upgrade with `-f current.yaml`. The pod is recreated and
   sessions and MCP tokens stay valid.

## When it does not start

| Log or symptom | Cause |
|---|---|
| names a missing sign-in method or `--public-url` | add one of the providers and the address, or `--dev` for a trial |
| `github sign-in needs --github-org` | set it, or `--github-team` |
| `ImagePullBackOff` | the registry is private: add `imagePullSecrets` |
| the pod stays in `CreateContainerConfigError` | the sign-in Secret named in `values.yaml` does not exist in the namespace; it must exist before the pod starts |
| `no k8s config` warning | the server runs on process memory: items vanish at a restart. It is expected only outside a cluster |

## Done when

- `kubectl -n xray rollout status deploy/xray` succeeds and the log shows `xray server ready`.
- `GET /v1/version` answers with the version you installed.
- A person you intend to admit signs in at the public address and sees the web UI.

Next: `xray-access` for who may sign in, `xray-connect` for Claude Code.

Written against X-Ray v2.10.1 and chart `xray` 2.10.1.
