---
title: "gh#6328 — Is non-clustered JetStream possible with gateways?"
type: summary
area: [topology, jetstream, kv]
source-url: https://github.com/nats-io/nats-server/discussions/6328
source-path: raw/gh-discussions/gh-6328.md
author: "@Nintron27 (asker), @jnmoyne (answer)"
article: "GitHub Discussion 6328, nats-io/nats-server, Q&A"
date: 2025-01-06
version: ""
tags: [gateway, leafnode, read-replica, sourcing, kv, multi-region]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#6328 — "You don't even need a super-cluster"

Opened 2025-01-06, answered the same day by **@jnmoyne** (a NATS maintainer). Short, and the closest
thing in public to a direct maintainer answer to "leafnode, gateway or cluster — when do I use
which?"

## Key claims

The asker wants regional **read replicas of a KV bucket** for auth sessions, on Fly, with NATS
embedded in a Go binary:

> "3 node cluster in the US · 1 node in the EU · 1 node in Southeast Asia · 1 node in South America
> … The goal would be to have these form a super cluster, and each of the 1 nodes in every region
> have a read replica of a KV bucket that stores auth sessions."

He names his own alternative and his worry about it: "My one idea was to make all of these nodes
actually leaf nodes, but I wanted to avoid a situation where a node in Asia needs to first
communicate with the US before the EU can get the message/update."

The chosen answer, in full:

> "You don't even need a super-cluster, you could simply have your 3 node cluster in the US and have
> each of your 1 nodes in other parts of the world connect to the cluster as Leaf Nodes. Then you can
> enable JS on those leaf nodes and create read replica streams that source from streams located in
> the cluster."
> — @jnmoyne, 2025-01-06

The asker confirms: "After reading further about how leaf nodes work this does seem to be exactly
what I am going for here."

## Practical takeaways

- **A single-node JetStream site attached by a leafnode is the maintainer-recommended shape for a
  regional read replica** — not a gateway, and not a member of a stretched cluster.
- The reason a gateway does not help here is not stated in the thread but follows from the docs: a
  gateway carries *interest*, and a stream's replicas never leave their cluster
  (source: [[s-docs-jetstream-in-a-cluster]]). Crossing a JetStream boundary is a
  **mirror-or-source** operation either way, so the connection type is chosen on network and
  isolation grounds, not on whether JetStream data can cross.
- The asker's stated worry — that a leaf topology forces Asia→US→EU hops — is not addressed in the
  thread. It is real for **core** traffic through a hub, and it is what
  [[s-gh-7438-multi-region-availability]] pushes on.

## Relevance to the wiki

The maintainer answer that makes [[choosing-a-topology]] more than a restatement of the docs' ladder,
and the concrete shape behind [[multi-region-jetstream]].

## Questions it answers

- **Q41** — leafnode, gateway or cluster: for a regional JetStream read replica, the answer is a
  leafnode.

## Pages touched

[[choosing-a-topology]] · [[multi-region-jetstream]] · [[leafnode]] · [[gateway]] ·
[[mirrors-and-sources]] · [[key-value]]
