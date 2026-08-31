---
title: How clients reach a cluster
type: operation
kind: pattern
area: [deploy, core, clients, topology]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [connect_urls, no_advertise, client_advertise, seed-urls, loadbalancer, kubernetes, discovery, reconnect]
aliases: ["seed URLs", "server discovery", "connect_urls", "no_advertise", "client_advertise", "LoadBalancer vs seed URLs", "client connection URLs"]
sources: [s-adr-40-nats-connection, s-nats-helm-chart-values-2.14.6, s-docs-kubernetes, s-docs-encryption-and-tls, s-docs-websocket-tls-and-proxies, s-docs-websocket-your-first-websocket-connection]
created: 2026-08-31
updated: 2026-08-31
---

# How clients reach a cluster

A client is given a **seed list** of URLs to dial, and once connected it is *told* about the other
nodes by the server. Those are two different mechanisms, and every deployment question — LoadBalancer
or per-node addresses, NAT, Kubernetes — is really the question of **which of the two you want to be
in charge of failover**.

## The problem

The default arrangement works perfectly on a flat network and fails in a specific, confusing way
anywhere else: the server hands its clients a list of addresses **it** can see, which may be
addresses **they** cannot reach. Clients then appear healthy until a node goes away, at which point
they reconnect to an unroutable address and fail — long after whoever configured it moved on.

## What the server actually advertises

Observed on nats-server 2.14.6
(`raw/nats-server-src/compression-purge-discovery-observed-v2.14.6.md`; the `INFO` line was read
straight off the client port):

- **A standalone server advertises nothing** — no `connect_urls` field at all.
- **A clustered server advertises its own client URL and every peer URL it learned over the
  routes**, resolved to the host's **routable address** — not `0.0.0.0`, not `127.0.0.1`, and not
  what `listen` says.
- A client that set `protocol: 1` in `CONNECT` receives an updated `INFO` whenever that list changes,
  mid-connection (source: [[s-adr-40-nats-connection]]).
- Clients use the advertised list **by default**; "ignore advertised servers" is a client option
  defaulting to `false` (source: [[s-adr-40-nats-connection]]).

Two server keys change it, both **hot-reloadable**:

| key | block | effect |
|---|---|---|
| `no_advertise: true` | `cluster { }` | this server sends no client URLs to its peers **and** tells its own clients about no other server |
| `client_advertise: "<host>:<port>"` | top level | replaces this server's advertised URL **everywhere in the cluster**, verbatim and unresolved |

`no_advertise` is per node and its effect is cluster-wide: with it set on one node of three, that
node advertised nothing *and disappeared from the other two nodes' lists*, because the suppression
happens on the route as well as on the client connection. On a two-node cluster the survivor was
left with `connect_urls: null` entirely — a node that has learned no peer URL omits the field rather
than advertising only itself.

## The three designs

### 1 · Seed every node, discovery on — the flat-network default

```
nats://nats-1.internal:4222,nats://nats-2.internal:4222,nats://nats-3.internal:4222
```

Clients shuffle the list (randomization is on by default), connect to one, and learn the rest.
Failover is the client's job and needs nothing from the network.

**Use it when** every client can route to every node: one VPC or VLAN, stable DNS per node, no
address translation. This is the arrangement the whole client protocol is designed around.

### 2 · One address, discovery off — the load-balancer design

```
cluster {
  # clients arrive through the LB; pod/node addresses would be useless to them
  no_advertise: true
}
```

Clients are given the **one** LB address and are never told about anything else. Failover becomes the
load balancer's job: it must health-check the backends and stop sending new connections to a dead
one.

**Use it when** clients reach NATS through a single VIP, Service or ingress they cannot see behind —
which is exactly the Kubernetes default. The official Helm chart ships
`config.cluster.noAdvertise: true` with the comment "If clients are behind a load balancer it is
best to leave this as is" (source: [[s-nats-helm-chart-values-2.14.6]]).

**The cost is real:** a client that loses its connection reconnects to the same VIP and gets
whatever the LB gives it. It cannot prefer a healthy node it already knows about, and it cannot
spread itself across the cluster — a load balancer that favours the least-loaded backend will pile
reconnects onto the node that just restarted and is therefore emptiest.

### 3 · Advertise reachable per-node addresses — discovery from outside

```
# on each node, its own externally reachable address
client_advertise: "nats-1.example.com:4222"
```

Each node advertises an address that works from where the clients are — a per-node DNS name, a
NodePort, a per-pod LoadBalancer, an ingress hostname. Discovery and client-side failover work
exactly as in design 1, from outside the network boundary.

**Use it when** you want client-side failover but the internal addresses are not usable externally:
NAT, a bastion network, or clients outside the Kubernetes cluster. The docs note this case for TLS
too: "If, and only if, a NATS client sees an IP address in the advertised server lists, then that is
treated as equivalent to an updated DNS entry, and when reconnecting the NATS client should use the
original DNS hostname as the server identity to verify" (source: [[s-docs-encryption-and-tls]]) — so
advertise **names**, not IPs, when TLS is on.

**The cost is operational:** one externally routable address per node, forever, and every one of them
must stay in the certificate's SANs.

## On Kubernetes, concretely

The chart creates two services: a **headless** service giving each pod a stable DNS name
(`nats-0.nats-headless.<ns>.svc.cluster.local`) used for routing between nodes, and a regular
**ClusterIP** service named `nats` that clients dial (source: [[s-docs-kubernetes]]). The client
Service has no `type` field in the chart's values at all, so it is a plain ClusterIP — there is no
`LoadBalancer` option to set, and the only ingress in the chart is for WebSocket
(source: [[s-nats-helm-chart-values-2.14.6]]).

That produces design 2 by default, and it is the right default:

- **In-cluster clients** dial `nats://nats.<ns>.svc.cluster.local:4222` and let the Service
  distribute them. Discovery is off, so nobody is handed a pod IP.
- **In-cluster clients that want client-side failover** can seed the headless names directly —
  `nats://nats-0.nats-headless...:4222,nats://nats-1...` — and set
  `config.cluster.noAdvertise: false`. Pod IPs are routable inside the cluster, so discovery works.
- **External clients** need design 3: an address per pod (per-pod LoadBalancer, NodePort, or an
  ingress that speaks TCP), each pod's `client_advertise` set to its own external address. The
  chart's own comment says as much — "in case clients have external connectivity make sure to define
  the `advertise` section as well".

**The failure to avoid** is the middle of these: one LoadBalancer in front of all pods *with*
advertising on. Clients connect through the VIP, are told the pod IPs, and reconnect to addresses
that do not exist outside the cluster. It works until the first failover.

## Trade-offs at a glance

| | seed all nodes, discovery on | one VIP, `no_advertise` | per-node `client_advertise` |
|---|---|---|---|
| who fails over | the client | the load balancer | the client |
| client config | full seed list | one URL | one or more URLs |
| survives adding a node | yes, automatically | yes | only after configuring the new node |
| needs per-node external addresses | no | no | yes |
| TLS SANs | node names | the VIP name | every advertised name |
| spreads clients across the cluster | yes (shuffled) | only as well as the LB does | yes |

## When *not* to use discovery at all

- When clients are outside a boundary the advertised addresses do not cross, and you are not willing
  to maintain per-node external addresses. Turn it off (`no_advertise`) rather than leave clients
  holding addresses that fail only during an incident.
- When a fixed, auditable set of endpoints is a requirement — discovery means a client may end up
  connected to a node nobody put in its configuration.

## Verify

Read what a server actually sends, without a client:

```
(printf ''; sleep 0.4) | nc <host> 4222
```

The first line is `INFO {…}`; the `connect_urls` array is what your clients will use for reconnects.
Do this **from where the clients live** — the whole class of failure here is an address that is
routable from the server and not from the client. Every URL in the list must be reachable from that
vantage point; if one is not, the design is wrong, not the client.

## WebSocket clients, and `advertise` behind a proxy

A [[websocket]] listener is a separate door with its own address, and two things about reaching it
differ from the client port (sources: [[s-docs-websocket-tls-and-proxies]],
[[s-docs-websocket-your-first-websocket-connection]]).

**`advertise` in the `websocket {}` block** is what a server behind NAT or a terminating proxy tells
clients about itself. Without it the server hands out the address it can see locally, which clients
cannot reach — and because discovery is used on **reconnect**, the failure appears later than the
change that caused it, not at first connect:

```
websocket { listen: 0.0.0.0:8080, no_tls: true, advertise: "nats.example.com:443" }
```

**The client's URL scheme is not the server's configuration.** A client connects with `wss://` because
the *proxy* presents the certificate; whether the listener itself runs TLS is decided by its own
`tls {}` block or `no_tls`. The two are set independently and a mismatch fails at the handshake.

**Always write the scheme and the port in a WebSocket client URL.** nats.js fills a missing port in
and never picks 4222 — a bare host becomes `wss://host:443`, `ws://host` becomes port 80, and
`nats://host:4222` keeps the port while losing the scheme, sending a WebSocket handshake to the plain
client port. The failure looks like the server being down.

## Related

[[build-a-3-node-cluster]] · [[upgrade-a-cluster]] · [[tls-in-nats]] · [[nats-helm-charts]] ·
[[install-nats-server]] · [[reload-server-config]] · [[leafnode]]

## Sources

- [[s-adr-40-nats-connection]] — the connection and reconnect specification, the client defaults,
  and the discovery section that is still a TODO
- [[s-nats-helm-chart-values-2.14.6]] — `config.cluster.noAdvertise: true`, its comment, and the
  ClusterIP Service
- [[s-docs-kubernetes]] — the headless and ClusterIP services the chart creates
- [[s-docs-encryption-and-tls]] — advertised IPs versus the hostname a client verifies
- `raw/nats-server-src/compression-purge-discovery-observed-v2.14.6.md` — the `INFO` lines quoted
  above, observed on the v2.14.6 binary
- [[s-docs-websocket-tls-and-proxies]]
- [[s-docs-websocket-your-first-websocket-connection]]
