---
title: "gh#7190 — Asymmetric Cluster Formation Problem"
type: summary
area: [topology, deploy]
source-url: https://github.com/nats-io/nats-server/discussions/7190
source-path: raw/gh-discussions/gh-7190.md
author: "@ccampanale (asking), @wallyqs (maintainer, replying)"
article: "Asymmetric Cluster Formation Problem"
date: 2025-08-20
version: "2.11.7"
tags: [routes, dns, service-discovery, partitioned-cluster, routez, pool_size, fargate]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#7190 — Asymmetric Cluster Formation Problem

A three-node cluster on AWS Fargate whose nodes end up with **different route counts** — 8 + 6 + 6
instead of 8 + 8 + 8 — and clients partitioned as a result. **No answer was accepted**, but a NATS
maintainer names the cause in the first reply: the route address is one DNS name that resolves to
several IPs.

## Key claims

**The setup.** NATS **2.11.7**, three nodes registered in one AWS Service Discovery (Route 53) DNS
namespace with `routing_policy = MULTIVALUE`, each node's config carrying a **single** route entry
pointing at that shared name:

```
cluster {
    name: …
    port: …
    connect_retries: 5
    authorization { user: … password: … timeout: … }
    routes = [
        nats://<user>:<pass>@<service-discovery-fqdn>:<port>
    ]
}
```

**The symptom, in the reporter's numbers:**

> "our three node cluster typically has a total of 24 routes; each node has 4 routes to the other two
> nodes for a total of 8. When the total number of routes is less than 24 (typically this surfaces as
> 8 + 6 + 6) this causes some services to be unreachable by others; a sort of split-brain."

**The maintainer's answer** (@wallyqs, the first reply):

> "This won't work well at the moment, the cluster needs to be aware of the other servers otherwise
> they could discover different ones via the dns resolution and result in a partitioned cluster."

quoting the single-FQDN `routes` entry as the thing that will not work.

**The suggested workaround**, same author:

> "One way to try to workaround this is to have a way in Fargate to detect that the number of routes
> is expected (via `/routez`), in case it is not then restart the container until it has a dns
> resolution that makes it cluster with the rest of the nodes."

**The reporter's counter-argument is the interesting part**, because it is the reading the docs
invite: gossip is supposed to make one seed enough, so why should a name that always resolves to *a*
cluster member not be equivalent to a seed?

> "in all instances where we've seen this asymmetric cluster formation occur, one node **not having
> routes to another node** is never the problem. Our cluster seems to always form with routes to each
> other node … But for some reason, some nodes have less routes than others."

**The thread ends there.** The reporter's last message weighs a `/routez`-based cluster health check
and its failure modes ("the first node could be healthy for all intents and purposes and not yet have
any routes"). No maintainer follow-up, no chosen answer, and no root cause beyond the DNS
observation.

## Practical takeaways

- **A single multi-value DNS name is not a seed address.** A seed is "an address of a specific
  server"; a name that resolves to a rotating subset of the cluster gives each node a *different*
  first peer, and the maintainer's position is that the servers must be "aware of the other servers"
  rather than discovering them through a resolver. Enumerate the peers — or the pod DNS names, as the
  Helm chart does ([[nats-helm-charts]]).
- **Route counts are per-connection and must match across nodes.** 4 per peer link is
  `cluster.pool_size` (default **3**) plus the dedicated system-account route — exactly the arithmetic
  [[s-docs-forming-a-cluster]] gives, here confirmed on a real 2.11.7 cluster. **Unequal counts are
  the symptom**, which is why "same non-zero number on every row" is the check worth automating.
- **`/routez` is the programmatic version of that check** ([[monitoring-endpoints]]), and the thread
  is candid about its limits: a lone healthy node legitimately has no routes, so the check is only
  meaningful cluster-wide, after every node is up.
- **This is a partial split-brain that leaves every node in the cluster.** All three agree on the
  cluster name and all appear in the list; only the connection counts differ. Nothing in the docs'
  cluster-formation pitfalls covers this shape.

## Notable quotes

> "The cluster needs to be aware of the other servers otherwise they could discover different ones
> via the dns resolution and result in a partitioned cluster." — @wallyqs

## Relevance to the wiki

The DNS pitfall in [[build-a-3-node-cluster]], and independent confirmation of the route-count
arithmetic that runbook tells you to verify.

## Questions it answers

**Q47** — with the caveat that the thread is unanswered: the maintainer names the cause (a
multi-value DNS route address) and a workaround, not a fix.

## Pages touched

[[build-a-3-node-cluster]] · [[monitoring-endpoints]] · [[nats-helm-charts]]
