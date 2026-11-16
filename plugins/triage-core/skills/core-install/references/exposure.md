# Exposing the core

Three listeners matter outside the cluster.

| Listener | Port (chart value) | Who uses it | Path |
|---|---|---|---|
| API and UI bundle | 8080 (`httpApi.port`) | people, the TUI, the mobile app, spots (REST) | `/v2/...`, `/` |
| MCP | 8083 (`mcpServer.port`), or the API port with `httpRoute.mcpViaAPIPort` | Claude Code, Codex, Copilot, other agents | `/mcp` |
| Events | 8086 (`events.port`) | cluster agents (WebSocket), webhooks | `/events/ws`, `/events/<provider>/<service>` |

An agent only dials out, so a cluster in another network needs the events listener reachable over HTTPS, and nothing else.

## Gateway API

```yaml
httpRoute:
  enabled: true
  hostname: <core-host>
  gatewayName: <gateway>
  gatewayNamespace: <gateway-namespace>
  sectionName: https            # the listener on the Gateway
events:
  httpRoute:
    enabled: true               # adds the /events rule; httpRoute.enabled must be on too
```

- `httpRoute.mcpViaAPIPort: true` serves `/mcp` from the API Service when only one port is allowed through.
- `httpRoute.apiPathPrefix` narrows the catch-all rule (for example `/v2`) when another release shares the hostname.
- `externalGateway.enabled` makes the chart create the Gateway itself (`gatewayClassName`, `address`, `tlsSecret`).

## Ingress

```yaml
externalIngress:
  enabled: true
  eventsHostname: <events-host>
  clusterAgentHostname: <events-host>      # host of the /events/ws Ingress; may reuse another host
  clusterAgentProxyTimeout: "3600"        # seconds; the agent WebSocket is long-lived
  tlsSecret: <tls-secret>
  annotations: {}
```

## Load balancers that cap connection time

A WebSocket lives as long as the backend timeout allows. On a Google Cloud load balancer set
`gcpBackendPolicy.enabled`, `timeoutSec` and `eventsTimeoutSec` (for example 3600), and `sessionAffinity`
(`CLIENT_IP`) when `replicaCount` is above 1, because login and OAuth state is per pod.

## Client addresses

`trustedProxyHops` is the number of `X-Forwarded-For` entries the proxies in front append, counted from the right.
A global external Application Load Balancer appends two. The address it selects is the one the join, MCP OAuth and
rejected-credential throttles key on; with 0 the peer address is used and every client looks like the proxy.
