---
title: "gh#4823 — Duplicate messages on a leafnode cluster connected to a supercluster"
type: summary
area: [topology, core]
source-url: https://github.com/nats-io/nats-server/discussions/4823
source-path: raw/gh-discussions/gh-4823.md
author: "@smolp (asker), @derekcollison (answer)"
article: "GitHub Discussion 4823, nats-io/nats-server, Q&A"
date: 2023-11-28
version: "2.9.24"
tags: [leafnode, supercluster, gateway, duplicates, loop, dns, deny_imports]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#4823 — one leaf, two clusters of one supercluster, and a message loop

Opened 2023-11-28 on **nats-server 2.9.24**, answered 2023-11-29 by **@derekcollison**. A
one-sentence answer that reframes the whole problem, and the only public statement of the rule.

## Key claims

### The symptom

Sequence numbers observed by a subscriber in the leaf cluster:

```
9867,9866,9867,9867,9867,9867,9868,…,9879,9868,9869,9870,9871,9880,9872,9873,9881,9882,9874,…
```

against an expected `13702,13703,13704,…`. Not just duplicates — **reordering and repetition of a
whole window**, which is the shape of a routing loop rather than a redelivery.

### The topology

> "Cluster 1 & 2 in EU, connected via gateways, it's a super cluster, 3 nodes each. Cluster 3 in
> Asia, it's a leafnode cluster connected to 1 & 2 with 3 nodes."

The leaf remote lists **both** clusters:

```
leafnodes:
  remotes:
    - urls:
        - "nats-leaf://nats-cluster-1.nats.svc.clusterset.local:7422"
        - "nats-leaf://nats-cluster-2.nats.svc.clusterset.local:7422"
```

### The three "weird things", all consistent with a loop

1. "it only happens on 2 out of 3 nodes on Cluster 3… When I scale nats back to 1 replica, it doesn't
   happen."
2. "The issue only persists in internal cluster communication" — a Cluster-3 app asking a Cluster-3
   app duplicates; the same request from Cluster 1 or 2 does not.
3. "I can mitigate this issue by expanding `denyImports` list on the topic… The funny thing about
   this one is that there is no application on Cluster 1 and Cluster 2 that is publishing messages on
   those topics. **Looks like the leafnode replicas are somehow duplicating the data and making it
   circle around(?)**."

### The answer

> "A Leafnode bridges NATS systems. A Supercluster is a single system, so the LN connections from
> cluster 3 in Asia should only connect once to the supercluster, not to each cluster 1 & 2."
> — @derekcollison, 2023-11-29 (marked as the answer)

And earlier in the thread, the general form: "Its possible to create a loop using account imports and
exports. Normal mis-configuration loops are usually caught by the system when the LN's are
established."

### How you are supposed to address a supercluster

The asker asks whether a supercluster has a single address. The answer:

> "For superclusters we recommend cname DNS for clusters and a geo-aware global DNS for the whole
> thing which is what we do with Synadia Cloud."
> — @derekcollison, 2023-11-29

## Practical takeaways

- **A leaf remote's `urls` list must name servers of one NATS system, not one entry per cluster of a
  supercluster.** The list is a reconnect pool; every URL in it is an alternative route to the *same*
  system. Listing two clusters of a supercluster makes two bridges into one system, and the two
  bridges feed each other.
- The mitigation the reporter found — piling subjects into `deny_imports` — treats the symptom. It
  works because it cuts one direction of the loop, and it needs extending every time a new subject
  appears.
- Reach a supercluster through **DNS**, not through a longer `urls` list: a CNAME per cluster and a
  geo-aware record over the whole thing.
- The server catches *some* leafnode loops at connection time ("normal mis-configuration loops"), and
  this was not one of them — the same limited-guard shape as the JetStream-domain guard in
  [[s-nats-server-leafnode-js-domains]].

## Relevance to the wiki

The source for [[duplicate-messages-across-a-leafnode]], and the "how many URLs, and which" rule on
[[leafnode]].

## Questions it answers

- **Q44** — why duplicate messages appear on a leafnode cluster attached to a supercluster.

## Pages touched

[[duplicate-messages-across-a-leafnode]] · [[leafnode]] · [[gateway]] · [[choosing-a-topology]]
