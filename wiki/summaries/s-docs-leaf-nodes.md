---
title: "docs.nats.io — Leaf nodes"
type: summary
area: [topology, security, jetstream]
source-url: https://docs.nats.io/learn/topologies/leaf-nodes.md
source-path: raw/nats-docs/learn/topologies/leaf-nodes.md
author: NATS documentation (Synadia Communications, Inc.)
article: Leaf nodes
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [leafnode, hub, spoke, remotes, 7422, jetstream-domain, address-space-isolation]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Leaf nodes

The shape for a site that has **egress only**. The page's whole argument is one constraint: a
gateway joins two clusters that can both accept connections from each other, and a factory floor
behind a firewall can accept nothing. A leaf dials out; the hub never dials in.

## Key claims

### The definition, and the direction that makes it work

> "A **leaf node** is a NATS server that opens an *outbound* connection to a remote NATS system and
> bridges subject interest across it."

The server the leaf dials is the **hub**. "As long as the factory can make one connection out to the
hub, the bridge works: no inbound firewall rule, no public address on the factory side."

Once up, the leaf is an ordinary NATS server to its own clients — "the machine needs no leaf-specific
configuration".

### The two config blocks, and which end gets which

The hub **listens**; the leaf declares a **remote**.

```
# hub — accept inbound leaf node connections
leafnodes {
  listen: 127.0.0.1:7422
}
```

```
# leaf — dial out
leafnodes {
  remotes: [
    { urls: [ "nats://127.0.0.1:7422", "nats://127.0.0.1:7423", "nats://127.0.0.1:7424" ] }
  ]
}
```

- **"The default leaf node port is `7422`."** It is "a fourth kind of listener, separate from the
  client port (4222), the route port (6222), and the gateway port (7222) — one port per kind of
  connection." *(This wiki reads `port` as **having no default at all** — see
  [[s-nats-server-topology]] and `inbox/docs-issues.md` #23. The number 7422 is real as a convention
  and as the port appended to a remote URL that omits one; it is not what an omitted `leafnodes.port`
  becomes.)*
- The leaf `urls` list is for **reconnect**, not for load: "listing all three gives the leaf somewhere
  to reconnect if one hub server is down."
- **`remotes` is a list**: "a leaf can hold several, each dialing a different NATS system." A leaf can
  itself run `leafnodes { listen }` and become a hub for leaves further out — "leaf links compose
  into trees, not just a single hub and spoke."
- The leaf in the example "has no `cluster {}` block and no `gateway {}` block".

### Two more fields, in production

- **`account`** — "selects which local account on the leaf the bridged interest joins."
- **`credentials`** — "a `.creds` file that proves the leaf's identity to the hub, which attaches it
  to the matching account there."

"Point both ends at the same account and the factory floor and the cloud share one isolated subject
space across the link."

### Local clients stay hidden

"A factory machine connects to `factory-1` as a plain client. It never appears on the hub as a
connection. The hub sees one thing: the leaf link." Add a thousand machines and "the hub still sees
one leaf link."

The page is careful to split two things people merge:

> "That covers connections. Subjects are separate… Bound to its own account, only the subjects that
> account imports and exports cross the link — that's **address-space isolation**, an account
> decision, not something the leaf link gives you for free."

In the default account "there's no subject boundary; interest flows across the leaf the way it flows
across a cluster's routes."

### JetStream over a leaf needs a domain

"If `factory-1` runs its own JetStream … it needs a JetStream **domain**." A domain "is a name that
isolates one JetStream system from another across a leaf link… Without distinct domains, a leaf's
JetStream and its hub's JetStream collide."

### The two pitfalls the page names

1. **Treating the leaf like an inbound connection.** "People reverse this (a `listen` on the factory,
   expecting the hub to dial in) and nothing connects."
2. **Expecting JetStream to span the leaf without a domain.** "If `factory-1` enables JetStream while
   sharing the hub's system account, it extends the *hub's* JetStream rather than running its own, so
   a stream you create on the factory floor may land on the hub, not locally."

## Practical takeaways

- The block you write tells you which end you are on. `listen` = hub, `remotes` = leaf. There is no
  symmetric form.
- A leaf link is **one connection** regardless of how many clients sit behind it. That is the
  scaling property, and it is also why the hub cannot see or authenticate those clients.
- Isolation is an **account** decision, not a leaf one. A leaf in the default account is as open as a
  route.
- JetStream across the link is the part with a trap: sharing the system account with matching
  domains extends the hub's JetStream, which is usually not what someone building an edge store
  wants.

## Relevance to the wiki

The source for [[leafnode]], and half the material for [[choosing-a-topology]]. The domain pitfall
is the docs' side of what [[streams-not-visible-across-a-leafnode]] and [[jetstream-domain]] explain
from the server source.

## Questions it answers

- **Q41** in part — what a leafnode is for, versus a gateway.
- **Q48** in part — it names `account` as the boundary; it never mentions `deny_imports` /
  `deny_exports`, which is the question people actually ask (see [[s-gh-5941-restrict-leafnode-subjects]]).

## Pages touched

[[leafnode]] · [[choosing-a-topology]] · [[jetstream-domain]] · [[multi-region-jetstream]] ·
[[account]] · [[streams-not-visible-across-a-leafnode]] · [[config-keys]]
