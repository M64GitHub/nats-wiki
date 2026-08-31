---
title: "gh#7494 — Performance degradation in a global NATS super-cluster"
type: summary
area: [topology, core, monitoring]
source-url: https://github.com/nats-io/nats-server/discussions/7494
source-path: raw/gh-discussions/gh-7494.md
author: "@Choi-Sung-Hoon (asker)"
article: "GitHub Discussion 7494, nats-io/nats-server, Q&A"
date: 2025-10-30
version: ""
tags: [gateway, supercluster, geo-affinity, bench, stalled_clients, slow-consumer, unanswered]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#7494 — 80,000 msg/s becomes 2,000 when a distant subscriber joins

Opened 2025-10-30. **Unanswered as of 2026-08-31.** Recorded because the measurement is clean, the
question is the right one, and the server source answers it even though nobody in the thread did.

## Key claims

### The topology

Six clusters, three servers each, joined as a super-cluster: "South Korea (IDC 1 + IDC 2) ·
Singapore · US West · US East · Germany".

### The three measurements

All with `nats bench`, 4KB messages.

| case | publisher | subscribers | result |
|---|---|---|---|
| A | korea-idc1 | korea-idc2 | "about 70,000 ~ 80,000 msgs / sec" |
| B | korea-idc1 | us-east | "2,000 msgs / sec" |
| C | korea-idc1 | korea-idc2 **and** us-east | **"around 2,000 / sec"** for the Korea subscriber too |

The asker's own reading of B is right — "I assume that this is because of physical distance between
South Korea and US." His question is about C:

> "The message delivery rate in the same region is expected to be 70,000 ~ 80,000 msgs / sec as case
> A, but it's actually around 2,000 / sec. **It seems like a cluster is affected by other clusters
> when they are subscribing same subject.** Is this an expected behavior? or is there something that
> I'm missing?"

### What the server says (not in the thread)

Two facts from [[s-nats-server-topology]] together explain case C exactly:

1. **Geo-affinity does not apply.** `nats bench sub` creates a **plain** subscriber, not a queue
   subscriber. Geo-affinity is an exclusion list over *queue group names*
   (`client.go:4482–4487`, `gateway.go:2637–2654`); with plain-subscriber interest on the far side,
   `psi` is true and every message crosses the gateway. The docs' "the message never crosses the
   gateway" is a statement about queue groups only
   (source: [[s-docs-super-clusters]]).
2. **A fast producer is stalled by its slowest destination.** `deliverMsg` stalls a `CLIENT` producer
   whenever a destination connection is in a stalled state (`client.go:3937–3944`), and the gateway
   to US East is such a destination. The stall is bounded — `stallClientMinDuration` 2ms,
   `stallClientMaxDuration` 5ms, `stallTotalAllowed` 10ms per read-loop invocation — but it is per
   loop, and it applies to the publisher, which is why the *Korea* leg degrades too.

The observables nobody named: the log line `Producer was stalled for a total of %v`
(`client.go:1451`), `/varz` → `stalled_clients`, and `/connz` → `stalls` per connection. **None of
these three appears anywhere in the 861-page docs tree** (`inbox/docs-issues.md` #25).

## Practical takeaways

- **Yes, this is expected behaviour**, and the mechanism has a name and a counter. It is not a
  super-cluster defect.
- A cross-region **plain** subscription puts your full publish rate on the WAN link and couples every
  local subscriber to it. If you want regional locality, the remote consumer must be a **queue group**
  member of a group that also has a local member.
- `no_fast_producer_stall: true` removes the coupling by dropping to the slow consumer instead of
  slowing the producer. It is a real trade, not a tuning win: the distant subscriber loses messages.
- `nats bench` measures the shape of your subscriptions as much as the network. A bench that uses
  plain subscribers cannot demonstrate geo-affinity.

## Relevance to the wiki

The symptom behind [[supercluster-slows-when-a-remote-subscriber-joins]], and the reason
[[gateway]] states the plain-subscriber caveat next to geo-affinity rather than after it.

## Questions it answers

- **Q46** — what causes performance degradation in a global super-cluster.

## Pages touched

[[supercluster-slows-when-a-remote-subscriber-joins]] · [[gateway]] · [[monitoring-endpoints]] ·
[[slow-consumer-detected]] · [[choosing-a-topology]] · [[config-keys]]
