---
title: "docs.nats.io — Forming a cluster"
type: summary
area: [topology, deploy]
source-url: https://docs.nats.io/learn/clustering/forming-a-cluster.md
source-path: raw/nats-docs/learn/clustering/forming-a-cluster.md
author: NATS documentation (Synadia Communications, Inc.)
article: Forming a cluster
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [routes, gossip, INFO, explicit-route, implicit-route, seed, pool_size, cluster-name]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Forming a cluster

How a server pointed at one peer ends up holding a route to every peer: explicit routes, implicit
routes, and gossip. The mechanism behind [[s-docs-your-first-cluster]], and the only doc page that
explains what the `Routes` column of `nats server list` actually counts.

## Key claims

**A route is a server-to-server connection on its own port.** "A client connects on the client port
(4222); a route connects on a separate route port (6222). The two never share a port, and that
distinction has practical consequences: **half of cluster-formation bugs are a route pointed at the
client port**."

"A route is bidirectional once open. Whichever server dialed, both ends afterward send and receive
over the same link: subscription interest in one direction, the messages that match it in the other."

**Two kinds of route:**

- **Explicit** — "one you configured. You wrote its address into the `routes` list in `nats.conf`,
  and the server dials it on startup. This is the seed."
- **Implicit** — "one the server opened on its own, to a peer it was *not* configured to know."

**Gossip is INFO redistribution.** "When two servers form a route, each sends the other an **INFO**
message, a small protocol frame carrying its own address. The receiver learns that peer exists and
dials it. A server then forwards that INFO to the other peers it already holds routes to, so each of
them learns the new peer and dials it too."

Traced on `east`: `n2-east` and `n3-east` each dial their one explicit route to `n1-east`; "on the
next INFO exchange, `n1-east` tells `n2-east` about `n3-east`. `n2-east` has no route to `n3-east`,
so it opens one — an implicit route that completes the mesh."

**The pure seed config** — `n1-east` with no `routes` of its own:

```
server_name: n1-east
listen: 127.0.0.1:4222

jetstream {
  store_dir: "./js/n1-east"
}

cluster {
  name: east
  listen: 127.0.0.1:6222
}
```

`n2-east` and `n3-east` each carry `routes: [ nats://127.0.0.1:6222 ]` and nothing else. "`n3-east`
… does **not** list `n2-east`, and it doesn't need to: gossip will supply that route."

**Verification, and the caveat on it.** The `nats server` commands "query the system account
(`$SYS`), which these configs don't set up; add one … and connect with its credentials before you run
them" — see [[account]].

```
nats server list
```

```
│ Name    │ Cluster │ Host │ Version │ JS  │ Conns │ Subs │ Routes │ Uptime │
│ n1-east │ east    │ ...  │ 2.x.x   │ yes │     0 │    9 │      8 │  1m2s  │
│ n2-east │ east    │ ...  │ 2.x.x   │ yes │     0 │    9 │      8 │  58s   │
│ n3-east │ east    │ ...  │ 2.x.x   │ yes │     0 │    9 │      8 │  55s   │
```

**The `Routes` column counts connections, not peers**: "each link to a peer is a small pool of
connections (three by default) plus a dedicated system-account route, so a three-server cluster shows
several per server. What confirms the mesh is that the count is the same on every row and non-zero."
(Two peers × (3 pooled + 1 system) = the 8 shown. `cluster.pool_size` defaults to **3** —
`inbox/config-keys-table.md`.)

```
nats server info n1-east
```

"prints `n1-east`'s perspective: its client port, the routes it holds, and the cluster name it
belongs to."

**Three pitfalls:**

1. **A mismatched `cluster.name` forms two clusters.** "Set `name: east` on two servers and
   `name: eest` on the third, and the third's route is rejected: its log reads
   `Rejecting connection, cluster name "east" does not match "eest"` and it forms its own one-server
   cluster that never merges."
2. **`routes` pointed at the client port never forms the mesh.** "A `routes` entry of
   `nats://127.0.0.1:4222` aims at the client listener, which speaks the client protocol, not the
   route protocol. The route never establishes and the server runs alone."
3. **One seed is enough, but list two or three anyway.** "If every joiner seeds off `n1-east` alone
   and `n1-east` happens to be down when they start, none of them can find the cluster. … Don't rely
   on a single seed in production."

**The rest of the `cluster {}` block** — `pool_size`, `compression`, `authorization`, the per-link
`tls {}` — is delegated to the generated config reference; this page uses only `name`, `listen` and
`routes`.

## Practical takeaways

- **`Routes` is not a peer count, and reading it as one produces false alarms.** The usable check is
  *same non-zero number on every row*, plus every row showing the same `Cluster`.
- **The two failure modes are silent in opposite ways**: a name mismatch leaves you with two working
  clusters that look like one; a route aimed at 4222 leaves you with servers that work alone. Neither
  fails loudly at startup.
- **Seed lists are a boot-ordering control, not a topology control.** More seeds do not change the
  mesh, only the odds that a cold start finds it.

## Notable quotes

> "Half of cluster-formation bugs are a route pointed at the client port."

## Relevance to the wiki

The mechanism section and both verification commands of [[build-a-3-node-cluster]]. Cross-checked
against the server in [[s-nats-server-route-cluster-formation]], which confirms the rejection log
line and adds the dynamic-cluster-name case this page does not cover.

## Questions it answers

Q47 (asymmetric / failed cluster formation), together with
[[s-nats-server-route-cluster-formation]].

## Pages touched

[[build-a-3-node-cluster]] · [[install-nats-server]] · [[raft-in-nats]] · [[account]] ·
[[config-keys]] · [[nats-cli]]
