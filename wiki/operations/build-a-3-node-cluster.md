---
title: Build a 3-node cluster
type: operation
kind: runbook
area: [topology, deploy, jetstream]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [cluster, routes, gossip, seed, cluster-name, no_advertise, failover, tls, 6222]
aliases: [cluster, clustering, "form a cluster", "first cluster", routes, "cluster setup"]
sources: [s-docs-your-first-cluster, s-gh-7190-asymmetric-cluster, s-gh-3569-connect-to-route-port, s-docs-forming-a-cluster, s-nats-server-route-cluster-formation, s-docs-hardening, s-docs-kubernetes, s-nats-server-topology, s-docs-super-clusters]
created: 2026-08-31
updated: 2026-08-31
---

# Build a 3-node cluster

Three `nats-server` processes joined by **routes**, so the loss of one server is a reconnect rather
than an outage and a stream can keep copies on more than one machine (source:
[[s-docs-your-first-cluster]]). This runbook builds the cluster; [[replicas]] is where you decide
what to replicate onto it.

## Goal

Three servers that:

- all report the **same cluster name** and a non-zero, equal route count;
- carry a message published on any one of them to a subscriber on any other;
- hand a client the other two servers' addresses so it fails over on its own;
- can hold an **R3** stream.

## Preconditions

- Three hosts, each with `nats-server` installed and running from a config file
  ([[install-nats-server]]).
- **An odd number of servers.** Two loses its majority the moment one is down; four tolerates one
  loss, the same as three, so the fourth server buys cost rather than availability. This is a
  JetStream constraint — a pure routing cluster works at any count (source:
  [[s-docs-your-first-cluster]], [[replicas]]).
- Route port **6222** reachable **between the nodes and nowhere else** — a route is a trusted link.
- **Empty JetStream stores, or a backup.** If any node already holds streams as a standalone server,
  stop and read [[streams-deleted-when-clustering-a-standalone-server]] — the first clustered restart
  deletes them.
- A system account if you want `nats server list` to work; the cluster forms without one, but you
  cannot inspect it ([[account]]).

## Steps

### Server config

Every server gets the same `cluster { name }` and its own ports. One server is the **seed** and
carries no `routes`; the others point at it (source: [[s-docs-forming-a-cluster]]).

```
# n1-east.conf — the seed
server_name: n1-east
listen: 0.0.0.0:4222
http_port: 8222

jetstream {
  store_dir: "/var/lib/nats/js"
}

cluster {
  name: east
  listen: 0.0.0.0:6222
}
```

```
# n2-east.conf — a joiner
server_name: n2-east
listen: 0.0.0.0:4222
http_port: 8222

jetstream {
  store_dir: "/var/lib/nats/js"
}

cluster {
  name: east
  listen: 0.0.0.0:6222
  routes: [
    nats://n1-east:6222
    nats://n3-east:6222
  ]
}
```

`n3-east` is the same file with its own `server_name` and routes to `n1-east` and `n2-east`.

Three fields do the work:

| field | rule |
|---|---|
| `cluster.name` | **identical on every server.** Two servers with different configured names cannot join |
| `cluster.listen` | the **route** port, never the client port. `cluster.port` defaults to **6222** |
| `cluster.routes` | seed addresses to dial at startup. **List two or three**, not one |

**You do not need to write the full mesh.** A server that dials one peer learns about every server
that peer knows and dials those too — an *implicit* route, opened by gossip (INFO redistribution).
Writing the mesh by hand also works; the servers drop the redundant connections with a
`Duplicate Route` close, and the cost is editing every config each time you add a node (source:
[[s-docs-forming-a-cluster]]). Listing two or three seeds is the middle ground: it is not about the
shape of the mesh, only about surviving a cold start where the one seed you named is down.

Start all three. The joiners dial their seeds, exchange INFO, and open the remaining routes
themselves.

### TLS on the routes

Client TLS and cluster TLS are **separate blocks**, and turning on the first leaves the second
plaintext — including replicated JetStream data (source: [[s-docs-hardening]]):

```
cluster {
  name: "east"
  listen: "0.0.0.0:6222"
  routes: [ "nats://n1-east:6222", "nats://n3-east:6222" ]

  tls {
    cert_file: "/var/lib/nats/certs/server-cert.pem"
    key_file:  "/var/lib/nats/certs/server-key.pem"
    ca_file:   "/var/lib/nats/certs/ca.pem"
    verify:    true
  }
}
```

On a route the server **forces mutual verification whether or not you set `verify`**, because each
end acts as both client and server. That is what turns the route port from "anyone who knows the
cluster name" into "anyone holding a certificate from your CA". Certificate rotation is a config
reload, not a restart — the wanted [[rotate-tls-certificates]] covers it.

### Firewall

```
ufw allow 4222/tcp
ufw allow from 10.0.0.0/24 to any port 6222 proto tcp
ufw deny 8222/tcp
```

Allow 6222 **from the cluster subnet before** denying it elsewhere. A blanket deny leaves three
servers that each come up alone and never form quorum (source: [[s-docs-hardening]]).

### Kubernetes

The chart does the routes, the headless service and the pod naming for you (source:
[[s-docs-kubernetes]]):

```yaml
# values.yaml — a three-node JetStream cluster
config:
  cluster:
    enabled: true
    replicas: 3
  jetstream:
    enabled: true
    fileStore:
      pvc:
        size: 10Gi
```

Do not "fix" the chart's `podManagementPolicy: Parallel`: the ordered default waits for each pod to
be ready before starting the next, and **that deadlocks cluster formation**, because no node is ready
until it can see its peers. See [[nats-helm-charts]].

## Verify

**1. Each server agrees on the name.** This one needs no credentials — it is in every server's own
log at route-listener startup (source: [[s-nats-server-route-cluster-formation]]):

```
Cluster name is east
```

If instead you see `Cluster name was dynamically generated, consider setting one`, that server has no
`cluster { name }` and will take on whichever name it meets first.

**2. The mesh formed** (needs the system account):

```
nats server list
```

```
│ Name    │ Cluster │ Host │ Version │ JS  │ Conns │ Subs │ Routes │ Uptime │
│ n1-east │ east    │ ...  │ 2.x.x   │ yes │     0 │    9 │      8 │  1m2s  │
│ n2-east │ east    │ ...  │ 2.x.x   │ yes │     0 │    9 │      8 │  58s   │
│ n3-east │ east    │ ...  │ 2.x.x   │ yes │     0 │    9 │      8 │  55s   │
```

**Read it as: every row shows the same `Cluster`, and the same non-zero `Routes`.** Unequal counts
with every node present is a real failure shape, not a rounding artefact — see the DNS pitfall
below. `Routes` counts
*connections, not peers* — each peer link is a pool of `cluster.pool_size` connections (default
**3**) plus a dedicated system-account route, so 8 is what two peers look like. A server missing from
the list, or a different `Cluster` value, means it formed a cluster of its own (source:
[[s-docs-forming-a-cluster]]). For one server's own view:

```
nats server info n1-east
```

**3. A message crosses the cluster.** Subscribe on one server, publish on another:

```
nats sub "orders.>" --server nats://n3-east:4222
nats pub orders.created '{"order_id":"ord_8w2k"}' --server nats://n1-east:4222
```

If the two never joined, nothing arrives — and nothing errors.

**4. A client fails over on its own.** Point a publisher at one server and kill that server:

```
nats pub orders.created "order {{Count}}" --count 100 --sleep 1s --trace --server nats://n1-east:4222
```

```
12:00:22 >>> Connected to nats://localhost:4222 (127.0.0.1:4222)
12:00:25 >>> Disconnected due to: EOF, will attempt reconnect
12:00:25 >>> Reconnected to nats://localhost:4223 (127.0.0.1:4223)
12:00:26 Published 7 bytes to "orders.created"
```

It reconnects to a server you never named, because the first server's INFO handed it the rest of the
cluster. If it does not, check `no_advertise` — left off (the default), failover spans the whole
cluster (source: [[s-docs-your-first-cluster]]).

**5. The cluster can hold a replicated stream:**

```
nats stream add ORDERS --subjects 'orders.*' --storage file --replicas 3 --defaults
nats stream info ORDERS
```

`Replicas: 3` with a leader and two peers is the end state. What R3 does and does not promise is
[[replicas]]; if placement is refused, [[no-suitable-peers-for-placement]].

## Rollback

**Routes reload; the listener does not.** `cluster.routes` and `cluster.name` are reloadable, so
adding or removing a peer address is `systemctl reload nats-server`. `cluster.listen`, `cluster.host`
and `cluster.port` are **restart-only** — only a `listen` whose host is unchanged and whose port is
`-1` survives a reload (`inbox/config-keys-table.md`, [[config-keys]]).

**Removing the `cluster` block from a server that holds replicated streams is not a rollback.** Take
it out of the cluster the JetStream way — move the stream's replicas off it first
([[rebalance-streams]]) — and never treat "delete the block and restart" as safe on a node with data
([[streams-deleted-when-clustering-a-standalone-server]]).

## Pitfalls

**A `routes` entry pointed at the client port never forms anything.** `nats://host:4222` reaches the
client listener, which speaks a different protocol; the route never establishes and the server runs
alone. The docs call this "half of cluster-formation bugs" (source: [[s-docs-forming-a-cluster]]).

**The same confusion in the other direction is loud.** A *client* pointed at `6222` gets an error in
the **server's** log —

```
[ERR] 192.168.0.3:57824 - rid:10 - attempted to connect to route port
```

— and, confusingly, the subscription may still receive messages. "`cluster` routes are meant to be
used only for other nodes (servers) to connect and form a cluster. Clients should connect to the
listen URL of one of the nodes" (source: [[s-gh-3569-connect-to-route-port]]). Note which direction
is which: the client mistake logs, the route mistake is silent.

**A misspelled `cluster.name` gives you two clusters that look like one.** The odd server's route is
rejected with

```
Rejecting connection, cluster name "east" does not match "eest"
```

and it forms a one-server cluster that never merges. Nothing else fails; you find out when a message
does not cross.

**An *unset* `cluster.name` fails the other way — it joins something it should not.** A server whose
name was generated rather than configured **adopts the peer's name** and drops its other routes,
rather than being rejected. So "every server must set the same name" is advice; the invariant is that
two *configured* names must match. Set the name explicitly on every server, and treat
`Cluster name was dynamically generated` as an error (source:
[[s-nats-server-route-cluster-formation]]).

**One seed is a boot-order gamble.** Gossip only needs one, but if that one is down when the others
start, none of them find the cluster. List two or three.

**Do not make that seed a single DNS name that resolves to several servers.** It is the shape every
service-discovery integration reaches for, and a maintainer's answer on gh#7190 is blunt about it:

> "This won't work well at the moment, the cluster needs to be aware of the other servers otherwise
> they could discover different ones via the dns resolution and result in a partitioned cluster."

The reported symptom is not a missing node — every node joins and every node has routes to the
others — but **unequal route counts** (8 + 6 + 6 on a three-node 2.11.7 cluster instead of 8 + 8 + 8)
and clients that cannot reach each other across the gap. Enumerate the peers, or use per-pod DNS
names as [[nats-helm-charts]] does. The thread has **no accepted answer**; the workaround offered is
to check `/routez` for the expected count and restart the node until DNS hands it a resolution that
clusters (source: [[s-gh-7190-asymmetric-cluster]]).

**The route port is a privilege boundary.** A route carries every account's traffic plus the system
account. Exposed with no authorization, anyone who connects with the cluster name can join as a
server and read or inject messages across your accounts (source: [[s-docs-your-first-cluster]]).
Bind it to a private interface, firewall it, and put TLS or route credentials on it.

**An even server count is a trap for JetStream, not for routing.** Two servers lose quorum on one
failure; four tolerate exactly what three do ([[raft-in-nats]]).

## If this cluster will also carry a gateway or leafnodes

Three checks that belong in the same change, because two of them stop the server from starting and
`nats-server -c … -t` reports the file valid first (source: [[s-nats-server-topology]], reproduced on
v2.14.5).

**1 · `gateway.name` must equal `cluster.name`.** A *conflicting* pair fails with
`cluster name conflicts between cluster and gateway definitions` (`errors.go:192`). An **unset**
`cluster.name` is different: the gateway name is silently **adopted** as the cluster name
(`server.go:1118–1124`) — the same adoption trap as the route-side one this page already covers.

**2 · Write `gateway.port`.** There is no default despite the reference stating `7222`:

```
nats-server: gateway "east" has no port specified (select -1 for random port)
```

**3 · Set `system_account` if the server both accepts leafnodes and speaks to a gateway**, or it
refuses to start:

```
nats-server: leaf nodes and gateways (both being defined) require a system account to also be configured
```

You want the system account anyway — `nats server list` and the three `nats server report` commands
need it.

And one thing to verify from the **log**, not from a successful publish: a typo'd remote gateway name
never connects, but gossip forms the super-cluster through the other cluster's correct outbound
connection, so the cross-region test passes while the typo retries forever
(source: [[s-docs-super-clusters]]):

```
Failing connection to gateway "wset", remote gateway name is "west"
```

The remote logs the more useful half, naming all three values:
`Connection from "west" rejected, wanted to connect to "wset", this is "west"`.

See [[gateway]], [[leafnode]] and [[choosing-a-topology]] before adding either layer.


## Related

[[install-nats-server]] · [[replicas]] · [[raft-in-nats]] · [[stream-placement]] ·
[[no-suitable-peers-for-placement]] · [[streams-deleted-when-clustering-a-standalone-server]] ·
[[config-keys]] · [[account]] · [[nats-helm-charts]] · [[nats-cli]] · [[monitoring-endpoints]] ·
[[jetstream-sizing]] · [[rotate-tls-certificates]] · [[upgrade-a-cluster]] ·
[[rebalance-streams]] · [[reload-server-config]] · [[raft-in-nats]] · [[tls-in-nats]]

## Sources

[[s-docs-your-first-cluster]] · [[s-docs-forming-a-cluster]] ·
[[s-nats-server-route-cluster-formation]] · [[s-gh-7190-asymmetric-cluster]] ·
[[s-gh-3569-connect-to-route-port]] · [[s-docs-hardening]] · [[s-docs-kubernetes]] · [[s-nats-server-topology]] · [[s-docs-super-clusters]]
