---
title: "docs.nats.io — Your first cluster"
type: summary
area: [topology, deploy, core]
source-url: https://docs.nats.io/learn/topologies/your-first-cluster.md
source-path: raw/nats-docs/learn/topologies/your-first-cluster.md
author: NATS documentation (Synadia Communications, Inc.)
article: Your first cluster
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [cluster, routes, gossip, failover, no_advertise, cluster-port, quorum]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Your first cluster

Three servers, the `cluster {}` block, and a publisher that survives having its server killed. The
deployment-shaped half of cluster formation; [[s-docs-forming-a-cluster]] is the mechanism-shaped
half of the same `east` cluster.

## Key claims

**What a cluster is.** "A set of `nats-server` processes that know about each other and act as one
logical NATS system. A client connected to any server in the cluster can reach a subscriber
connected to any one of the servers in the cluster."

**Routes are not client connections.** "Clients connect on the client port (`4222`, the NATS
default); servers connect to each other on a separate cluster port (`6222` in the configs below)."

**One hop is always enough.** "Every server holds a route to every other server, so each is one hop
from all the rest. With three servers that's three routes. There's no central coordinator … A
message a server receives over a route is delivered to that server's own clients and **forwarded no
further**, because one hop is always enough to reach anyone."

**The three configs** (client ports 4222/4223/4224, route ports 6222/6223/6224). `n1-east`:

```
server_name: n1-east
listen: 127.0.0.1:4222

jetstream {
  store_dir: "./js/n1-east"
}

cluster {
  name: east
  listen: 127.0.0.1:6222
  routes: [
    nats://127.0.0.1:6223
  ]
}
```

`n2-east` and `n3-east` repeat it on 4223/6223 and 4224/6224, both with
`routes: [ nats://127.0.0.1:6222 ]`. Note this page has `n1-east` point *back* at `n2-east`;
[[s-docs-forming-a-cluster]] gives the same cluster with `n1-east` carrying **no** routes, and says
so explicitly.

The three fields that do the work: **`name`** ("must be `east` on all three servers, or they won't
join"), **`listen`** (the cluster port, "separate from the client port"), **`routes`** ("the list of
peers to actively connect to — one per server … None lists every peer").

**Gossip finishes the mesh.** "When a server connects to a route you wrote, it learns about every
other server that peer already knows, and dials those too." Writing the full mesh by hand also works —
"the servers simply notice the redundant connections and drop the extras (the log notes a
`Duplicate Route` close)" — and the trade-off is stated: the by-hand mesh means "no server depends on
a single seed being up first, but every new server then means editing every config".

**Start and confirm:**

```
nats-server -c n1-east.conf &
nats-server -c n2-east.conf &
nats-server -c n3-east.conf &
```

Stop with `kill %1 %2 %3` or `pkill nats-server`. Confirm a message crosses by subscribing on
`n3-east` (`--server nats://localhost:4224`) and publishing on `n1-east`
(`--server nats://localhost:4222`).

**Client failover is server-driven.** "On connect, a server sends an INFO message that includes the
other servers' client URLs. The client now knows about all three even if you only configured one."
The demonstration:

```
nats pub orders.created "order {{Count}}" --count 100 --sleep 1s --trace --server nats://localhost:4222
```

```
12:00:22 >>> Connected to nats://localhost:4222 (127.0.0.1:4222)
12:00:24 Published 7 bytes to "orders.created"
12:00:25 >>> Disconnected due to: EOF, will attempt reconnect
12:00:25 >>> Reconnected to nats://localhost:4223 (127.0.0.1:4223)
12:00:26 Published 7 bytes to "orders.created"
```

"`4223` is `n2-east` — a server you never named." **One control governs this:** `no_advertise: true`
"stops advertising its peers, and a client only knows the URLs you gave it by hand. Leave it off
(the default) and failover spans the whole cluster."

**Three pitfalls:**

1. **A misspelled cluster name does not raise an error.** "The server with the odd name forms its own
   cluster and never joins `east`, leaving you with two clusters that look like one until a message
   fails to cross." The log line quoted here is
   `cluster name "eats" does not match "east"`.
2. **Do not expose the cluster port.** "A route is a *trusted* link: it carries every account's
   traffic plus the system account, far more than any one client connection sees. Leave it reachable
   with no authorization … and anyone who connects with the cluster name `east` can join as a server
   and read or inject messages across your accounts."
3. **Plan for an odd server count.** "A two-server set loses its majority as soon as one server is
   down, and a four-server set tolerates only one loss — the same as three — so the extra server adds
   cost without buying more failure tolerance. … For a pure routing cluster, any count is fine."

## Practical takeaways

- **The cluster port is a privilege boundary, not a networking detail.** The docs' own configs bind
  it to `127.0.0.1`; anything else needs route authorization or TLS ([[s-docs-hardening]]).
- **Client failover needs no client config** — it needs `no_advertise` left off, and reachable
  advertised addresses. That is the whole mechanism behind "point clients at one seed URL".
- **The odd-count rule is a JetStream rule**, and the page is careful to say so: a routing-only
  cluster does not care.

## Notable quotes

> "A route is a *trusted* link: it carries every account's traffic plus the system account, far more
> than any one client connection sees."

> "The loss of one server is a reconnect, not an outage."

## Relevance to the wiki

The deployment half of [[build-a-3-node-cluster]], and the source for the failover demonstration in
its Verify section.

## Questions it answers

Q47 in part (a name mismatch is one documented cause of a cluster that will not form —
[[s-nats-server-route-cluster-formation]] carries the exception the page omits).

## Pages touched

[[build-a-3-node-cluster]] · [[install-nats-server]] · [[replicas]] · [[raft-in-nats]] · [[nats-cli]]
