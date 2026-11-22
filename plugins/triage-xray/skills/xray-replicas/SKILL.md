---
name: xray-replicas
description: Run X-Ray with more than one replica: leader election, the replica mesh, what is shared across pods and what stays per pod, the mesh certificate, a NetworkPolicy for the mesh port, checking the leader and the peers, failover time, "sign-in fails on one pod", "mesh peer disconnected". Use for "run xray with 3 replicas", "scale xray", "xray high availability", "who is the xray leader", "xray mesh". To install X-Ray first use xray-install; for who may sign in use xray-access.
---

# More than one replica

With one replica nothing here is on and nothing changes. Above one, the chart turns on two things
(ADR-068 in the repository):

- **Leader election** (`--leader-elect`): one replica, elected with a Kubernetes Lease, runs the work that
  must run once: the retention sweep, the episodic reaper, deleting a cell at its deadline, writing
  stored embeddings and status back to cells, and writing the stats to the configuration cell. Every
  replica serves requests and mirrors every cell into its own index either way.
- **The mesh** (`--mesh-tls-dir`): the replicas find each other through a headless Service and talk over
  mutual TLS. They share their counters, each person's daily token spend (a cap holds across replicas),
  logins, OAuth client registrations, MCP authorization codes (`/authorize` and `/token` may land on
  different pods) and sign-in state (a sign-in may finish on another pod).

## 1. Read the state

```sh
kubectl -n xray get deploy xray -o jsonpath='{.spec.replicas}{"\n"}'
kubectl -n xray get lease xray-leader -o jsonpath='{.spec.holderIdentity}{"\n"}' 2>&1
kubectl -n xray get svc,secret | grep -i mesh
```

## 2. Turn it on

Set `replicaCount` in the values file; the chart adds both features by itself above 1. To try them with
one replica, set `leaderElect: true` and `mesh.enabled: true`. `mesh.port` (default 8085) is the peer port.

The chart then creates:

| Object | Purpose |
|---|---|
| Secret `<release>-mesh-tls` | a self-signed CA and one certificate named `xray-mesh`, mounted by every pod and kept across upgrades |
| Service `<release>-mesh` | headless, publishes not-ready addresses; its DNS name resolves to the pods |
| Role rule on `leases` | lets the pods take the Lease `xray-leader` (`--leader-lease-name` renames it) |
| env `POD_NAME` | the pod's name, its identity on the Lease and the mesh |

Two requirements:

- **Set an OAuth client secret** (any of the sign-in providers). The state cookie, the session key and the
  MCP signing key are derived from it, so without it each pod has its own and a sign-in or an MCP token
  from one pod fails on another.
- **Run X-Ray in a namespace of its own.** The mesh certificate is a Secret in the release namespace.

Dry-run (`helm template ... | grep -E 'replicas:|--leader-elect|--mesh-'`), say what changes, then
`helm upgrade --install xray ... -f values.yaml`.

## 3. Limit the mesh port

Any pod that holds the certificate and is behind the Service can join, so allow the port from the
release's pods only. This needs a CNI that enforces NetworkPolicy. The chart labels the pods `app: <release>`; replace `xray` in the selectors with the release name if it differs.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: xray-mesh, namespace: xray }
spec:
  podSelector: { matchLabels: { app: xray } }
  policyTypes: [Ingress]
  ingress:
    - from: [{ podSelector: { matchLabels: { app: xray } } }]
      ports: [{ protocol: TCP, port: 8085 }]
```

A policy that selects the pods also blocks their other ingress, so add the rules for the port the
ingress or gateway uses (80) and the metrics port before applying it. Write the policy to a file, dry-run
it with `kubectl apply --dry-run=server -f`, and apply it only on a yes.

## 4. Verify

```sh
kubectl -n xray logs deploy/xray -c xray | grep -E "replica mesh on|leader election on|mesh: peer connected|acquired lease"
kubectl -n xray get lease xray-leader -o jsonpath='{.spec.holderIdentity}{"\n"}'
```

Each pod logs `replica mesh on` and `mesh: peer connected` once per peer; exactly one logs
`leaderlease: acquired lease`, and its name is the Lease's `holderIdentity`. A lost peer logs
`mesh: peer disconnected`.

## 5. Behaviour to know

| Case | Behaviour |
|---|---|
| leader pod stops or dies | another replica leads after the lease expires: about 15 to 20 seconds. Serving is unaffected; only leader work waits |
| a rolling update | each side counts its own work until it finishes; frames of another protocol version are dropped |
| mesh certificate rotation | delete `<release>-mesh-tls` and upgrade, which creates a new one; the pods hold the old one until they restart, so say that a restart follows and wait for a yes |
| voice session cap, rate limits | per pod: the effective limit is the setting times the replicas |
| search-hit pulses on the UI map | per pod: a browser sees the pulses of the replica it is connected to |
| two replicas restate the same fact at once | each may create a cell until the cluster watch catches up |

## Done when

- every pod is Ready, and the Lease `xray-leader` has a holder that is one of the pods;
- each pod logs `mesh: peer connected` for every other pod;
- a person signs in and the next requests succeed whichever pod answers, and an MCP login completes;
- with voice on, the audio tokens a person spends through one pod show in `quota.used` of `GET /v1/memory/metrics` on the others (the limit is `--user-daily-audio-token-limit`, 500000 by default).

Written against X-Ray v2.10.1 and chart `xray` 2.10.1.
