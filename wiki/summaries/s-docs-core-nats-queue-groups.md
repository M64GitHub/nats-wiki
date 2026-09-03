---
title: "docs — Core NATS: queue groups"
type: summary
area: [core, clients, topology]
source-url: https://docs.nats.io/learn/core-nats/queue-groups.md
source-path: raw/nats-docs/learn/core-nats/queue-groups.md
author: nats-io docs
article: "learn/core-nats/queue-groups.md; concepts/queue-groups.md read and folded (its L24, L1528 / L2131 and L2064–2093 carried as pointer lines)"
date: 2026-08-31
version: ""
tags: [queue-group, --queue, load-balancing, random-selection, geo-affinity, at-most-once, typo, wildcard-group, coexistence]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# docs — Core NATS: queue groups

The deep dive's queue-group page read as one article, with the `concepts/queue-groups.md` primer
(2,159 lines, restating it) folded. **Unversioned by design**; the server's selection is pinned at
v2.14.6 by [[s-nats-server-request-reply]] and measured — on one server, across the lab's three
nodes and across a leafnode — in [[s-nats-server-request-reply-observed]] runs C, E and H.

## Key claims

- A queue group is "a set of subscribers on the same subject that share a name. The server treats the
  whole group as one logical subscriber: for each message, it picks exactly one member of the group
  and delivers to that member alone" (L12). Membership is the subscription plus a name; "There's
  nothing to configure on the server … The server learns a group exists the moment its first member
  subscribes" (L16). The CLI form is `nats sub orders.created --queue packers` (L51).
- **How the pick works**: "The server keeps the live members of a group in a list. For each message,
  it picks a random index into that list and delivers to that member. On a single server the selection
  is uniform-random across the available members; a cluster adds a locality preference, covered
  below" (L218). "The server doesn't rotate fairly through the members the way round-robin would. The
  same packer can be chosen twice in a row, and over a handful of messages the split can look
  lopsided" (L220). The primer adds the sentence the deep dive lacks: selection "does not account for
  how busy a member is. A member stops receiving messages only when its subscription or connection
  goes away, **including when the server disconnects it as a slow consumer**"
  (`concepts/queue-groups.md:24`).
- **Membership is dynamic**: join by subscribing, leave by unsubscribing or disconnecting; a fourth
  packer "starts receiving its share immediately"; the shape suits an autoscaler (L224–228).
- **At-most-once**: "if the server picks a packer and it dies *after* delivery, that message is gone —
  the server won't retry it with another member. Work that must survive a worker crash belongs in a
  durable work queue in JetStream" (L230). The primer: "Core queue groups never redeliver … Duplicates
  come only from publisher retries, so make processing idempotent" (`concepts/queue-groups.md:2131`) —
  and, 600 lines earlier on the same page, "Use queue groups for operational work that needs to happen
  **exactly once**" (`:1528`), which contradicts it — docs issue #87.
- **Coexistence**: a plain subscriber and a queue group share a subject; "The server runs the two
  distributions independently" — the plain subscriber gets every message, the group one copy (L232–239).
- **One subject per group**: "Membership is evaluated *after* subject matching"; two members with the
  same name on different subjects "don't share load" (L253–255). A group may subscribe with a wildcard
  and then "load-balances across everything that wildcard matches" (L257).
- **Across regions**: "When the same queue group has members in several clusters, the server prefers a
  member in the publisher's own cluster before reaching across to another region … See Topologies →
  Super-clusters" (L261–263); the primer's version, "Messages are delivered to workers in the same
  cluster/region as the publisher … Only if all US-East workers are unavailable will messages route to
  US-West or EU-West workers" (`concepts/queue-groups.md:2064–2093`), restates
  [[s-docs-super-clusters]]. What neither says, and run E measured: **within one cluster there is no
  locality preference at all** — one member on the publisher's server and three on a peer got a
  quarter each — so "a cluster adds a locality preference" (L218) reads as something the server does
  not do; docs issue #88.
- **Pitfalls**: "A typo in the queue group name makes a second group … each published order goes to
  one member of *each* group: the work is double-handled" (L267); "Don't expect ordering or an even
  split" (L359); "Make a packer's work safe to repeat" (L361).
- "The same mechanics apply to request-reply: a queue group of responders on one subject answers each
  request exactly once" (L371).

## Practical takeaways

- Size a pool on the random pick, not on readiness: a busy member keeps receiving its share (run C).
- Byte-identical names, one subject per group; a wildcard group balances everything it matches.
- Nothing here survives a member's crash — [[worker-pool]] is the durable shape.
- The only server view of a group is `/subsz?subs=1` with its `qgroup` column, per server.

## Notable quotes

- "The server learns a group exists the moment its first member subscribes" (L16).
- "the same packer can be chosen twice in a row" (L220).

## Relevance to the wiki

The docs' half of [[queue-groups]]; the readiness question that [[s-nats-server-request-reply-observed]]
run C settles against the services chapter (docs issue #86), the in-cluster split of run E (docs issue
#88), the primer's slow-consumer sentence for [[slow-consumer-detected]]. `concepts/queue-groups.md` is
**read and folded** here.

## Questions it answers

134 (the queue-group half of the design question), 173, 174.

## Pages touched

[[queue-groups]] · [[request-reply]] · [[worker-pool]] · [[gateway]] · [[leafnode]] ·
[[slow-consumer-detected]] · [[core-nats-delivery]] · [[nats-cli]]
