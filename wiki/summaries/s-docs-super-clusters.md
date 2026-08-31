---
title: "docs.nats.io — Super-clusters"
type: summary
area: [topology, deploy]
source-url: https://docs.nats.io/learn/topologies/super-clusters.md
source-path: raw/nats-docs/learn/topologies/super-clusters.md
author: NATS documentation (Synadia Communications, Inc.)
article: Super-clusters
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [gateway, supercluster, geo-affinity, queue-group, gossip, 7222, interest]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Super-clusters

Two clusters joined by **gateways**, and the reason not to just stretch one cluster across the WAN.
The page carries the only prose statement of **geo-affinity** in the docs.

## Key claims

### A route and a gateway make opposite assumptions

> "A route ties two *servers* together and assumes they're close; a gateway ties two *clusters*
> together and assumes they're far apart."

The cost argument is explicit: stretch one cluster across regions and "every server holds a route to
every server in the other region — a full mesh running over the slow link." With gateways, "each
server opens just one gateway connection to each *other cluster*, never one to every remote server."

### Gateways carry only what has interest

"A gateway forwards a message to another cluster only when that cluster has a subscriber for it."
The worked case: a publisher in `east` floods `orders.created` thousands of times a second and "if
nobody in `west` subscribes to `orders.created`, not one of those messages crosses the gateway."

### The config block

```
gateway {
  name: "east"
  port: 7222
  gateways: [
    { name: "west", urls: ["nats://127.0.0.1:7322", "nats://127.0.0.1:7323", "nats://127.0.0.1:7324"] }
  ]
}
```

- **`name` identifies the cluster, not the server.** "Every server in `east` uses the identical
  gateway name `east`."
- It **must match `cluster.name`**: "set them differently and the server refuses to start
  (`cluster name conflicts between cluster and gateway definitions`)". *(Verified — the string is
  `ErrClusterNameConfigConflict`. The **unset** case is different and the page does not cover it; see
  [[s-nats-server-topology]].)*
- "A server's own entry in the `gateways` array is ignored automatically", so the block is identical
  across the cluster.
- **Gateways gossip.** "Point a server at a few remote gateways and it discovers the rest, including
  clusters it was never told about directly… The URLs are a starting point for discovery and a
  fallback if one is down, not a list you must keep complete."
- The page says `port` defaults to `7222`. *(It does not — a `gateway {}` block with no port is a
  startup error. See `inbox/docs-issues.md` #23.)*

### Geo-affinity

> "NATS prefers a local queue subscriber first. An order published in `east` goes to an `east`
> worker, even though a `west` worker is also subscribed and willing. The message never crosses the
> gateway, because it doesn't need to."

And the fall-through: "If every `east` worker is down, an order published in `east` has no local
subscriber, so geo-affinity falls through and the message crosses the gateway… When more than one
remote cluster has a worker for the queue group, NATS picks one of them and sends the message across
that single gateway."

The page frames this as **queue-group and request traffic only**, in its own summary line: "geo-affinity
keeps queue-group and request traffic in its home region". It never says what happens to a **plain**
subscriber on the far side — which is the gap behind [[s-gh-7494-supercluster-degradation]].

### The three pitfalls

1. **Reaching for routes to span regions.** "Don't grow a cluster across regions."
2. **Mismatched gateway names.** "Typo it — `wset` for `west` — and that entry never connects; the
   server logs `Failing connection to gateway "wset", remote gateway name is "west"` on every retry."
   The sharp part: "Because the other cluster's config is correct, its outbound connection still
   lands, and the super-cluster forms through that reverse connection and gossip. So a working
   cross-region publish doesn't prove your config is right — the typo keeps failing in the
   background."
3. **Chatty cross-region traffic without local workers.** "Geo-affinity only keeps traffic home when
   a *local* queue subscriber exists to serve it… Place a queue subscriber for each workload in every
   region that produces that work."

## Practical takeaways

- Gateway count scales with **clusters**, not servers: one connection per server per remote cluster.
- Geo-affinity is a property of **queue groups**. A design that relies on locality must put the
  workload behind a queue group in every producing region; a plain subscriber gets no locality at all.
- A super-cluster that works is not a super-cluster that is configured correctly. Grep the logs for
  `Failing connection to gateway`, because gossip hides the typo.
- The `gateways` list is a seed, not an inventory. `reject_unknown_cluster: true` is the switch that
  turns gossip off, and the page does not mention it.

## Relevance to the wiki

The source for [[gateway]] and the geo-affinity half of [[multi-region-jetstream]]. Its silence on
plain subscribers is what [[s-gh-7494-supercluster-degradation]] runs into.

## Questions it answers

- **Q41** in part — what a gateway is for.
- **Q45** in part — the locality mechanism, but not the JetStream half, which is the hard half.
- **Q46** not at all: geo-affinity is described in a way that reads as a promise it does not make.

## Pages touched

[[gateway]] · [[choosing-a-topology]] · [[multi-region-jetstream]] · [[build-a-3-node-cluster]] ·
[[config-keys]] · [[supercluster-slows-when-a-remote-subscriber-joins]]
