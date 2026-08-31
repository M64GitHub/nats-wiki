---
title: "a supercluster slows down when a remote subscriber joins"
type: gotcha
area: [topology, core, monitoring]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [gateway, supercluster, geo-affinity, queue-group, stalled_clients, stalls, no_fast_producer_stall, bench]
aliases: ["supercluster performance degradation", "slow gateway", "cross-region slowdown", "producer stalled", "geo-affinity not working"]
sources: [s-gh-7494-supercluster-degradation, s-nats-server-topology, s-docs-super-clusters, s-docs-monitoring-endpoints]
created: 2026-08-31
updated: 2026-08-31
---

# A supercluster slows down when a remote subscriber joins

Two clusters in the same region push 80,000 msg/s. Add a subscriber in a distant cluster and the
**local** rate collapses to the distant one's. This is expected behaviour with a name and a counter,
not a super-cluster defect — but nothing in the docs says so, and the thread reporting it is
unanswered.

## Symptom

Measured with `nats bench`, 4KB messages, across a six-cluster global super-cluster
(source: [[s-gh-7494-supercluster-degradation]]):

| case | publisher | subscribers | result |
|---|---|---|---|
| A | Korea IDC1 | Korea IDC2 | **70,000–80,000 msg/s** |
| B | Korea IDC1 | US East | **2,000 msg/s** |
| C | Korea IDC1 | Korea IDC2 **and** US East | **~2,000 msg/s — for both** |

> "The message delivery rate in the same region is expected to be 70,000 ~ 80,000 msgs / sec as case
> A, but it's actually around 2,000 / sec. It seems like a cluster is affected by other clusters when
> they are subscribing same subject."

Case B is just distance. Case C is the surprise: the **local** leg drops to the remote leg's rate.

## Quick triage

```
curl -s localhost:8222/varz  | jq .stalled_clients
curl -s 'localhost:8222/connz?sort=pending' | jq '.connections[] | {cid, stalls, pending_bytes, name}'
```

and in the server log:

```
Producer was stalled for a total of 8ms
```

A non-zero and climbing `stalled_clients`, with `stalls` concentrated on the publishing connection,
confirms it. Then one question decides everything: **is the remote subscriber a queue-group member,
or a plain subscriber?**

```
nats server report gateways
```

## Causes, ranked

### 1 · The remote subscriber is plain, so geo-affinity does not apply

Geo-affinity is described as a preference — "NATS prefers a local queue subscriber first… The message
never crosses the gateway" (source: [[s-docs-super-clusters]]). The implementation is narrower: it is
an **exclusion list over queue-group names**. When local queue subscribers are served, the server
collects the names it served (`client.go:4482–4487`) and the gateway drops those names from the
remote's queue list. It skips the gateway entirely **only** if nothing is left *and* there is no
plain-subscriber interest (`gateway.go:2652–2653`):

```go
2652:			if !psi && len(queues) == 0 {
2653:				continue
```

`nats bench sub` creates a **plain** subscriber. So `psi` is true, every message crosses the WAN, and
geo-affinity suppresses nothing (source: [[s-nats-server-topology]]).

**How to confirm.** Re-run the same test with `--queue`:

```
nats bench sub orders.created --queue workers --server nats://korea-idc2:4222
nats bench sub orders.created --queue workers --server nats://us-east:4222
nats bench pub orders.created --size=4KB       --server nats://korea-idc1:4222
```

If the local rate recovers, this is your cause.

**The fix.** Make cross-region consumers **queue-group members of a group that also has a local
member**. A plain cross-region subscription is a decision to put your full publish rate on the WAN.

### 2 · The publisher is stalled by its slowest destination

The second half, and the reason the *local* leg degrades rather than just the remote one.
`deliverMsg` stalls a `CLIENT` producer whenever a destination connection is in a stalled state
(`client.go:3937–3944`) — and the gateway to the distant cluster is such a destination. The stall is
bounded, but per read-loop invocation:

| constant | value | `server/client.go` |
|---|---|---|
| `stallClientMinDuration` | `2ms` | `:125` |
| `stallClientMaxDuration` | `5ms` | `:126` |
| `stallTotalAllowed` | `10ms` | `:127` |

**How to confirm.** `/varz` → `stalled_clients` climbing while the test runs, and `stalls` on the
publisher's connection in `/connz`.

**The fix, with a real cost.** `no_fast_producer_stall: true` — "do not stall a fast producer when a
consumer cannot keep up. **The server drops messages to the slow consumer instead**"
(`reference/config/no_fast_producer_stall.md`). It is hot-reloadable. You are choosing which side
suffers: without it the producer slows for everyone, with it the distant subscriber loses messages.

### 3 · Genuinely undersized inter-region link

If the far cluster's consumer is a queue-group member with a local peer and the rate still collapses,
the messages are crossing for another reason — a plain subscriber you forgot, a monitoring
subscription on `>`, or a service reply flowing back. `nats server report gateways` and a
`nats sub '>' ` audit on the remote cluster find it.

## Prevention

- **Never benchmark geo-affinity with plain subscribers.** `nats bench sub` without `--queue` cannot
  demonstrate it, and its numbers say nothing about what a queue-group workload would do.
- **Audit for wildcard subscriptions in remote clusters.** One `>` subscriber anywhere in the
  super-cluster puts everything on every gateway.
- **Alert on `stalled_clients`.** It is the earliest sign that one slow destination is holding back
  producers, and it costs one `/varz` field — see [[monitoring-endpoints]].
- **If regional independence matters more than one namespace**, this is an argument for leaf regions
  with their own JetStream domains rather than a super-cluster —
  [[multi-region-jetstream]], [[choosing-a-topology]].

## Explained by

[[gateway]] — geo-affinity as implemented, and what `psi` means for it.

## Related

[[gateway]] · [[choosing-a-topology]] · [[multi-region-jetstream]] · [[slow-consumer-detected]] ·
[[monitoring-endpoints]] · [[config-keys]] · [[leafnode]]

## Sources

[[s-gh-7494-supercluster-degradation]] · [[s-nats-server-topology]] · [[s-docs-super-clusters]] ·
[[s-docs-monitoring-endpoints]]

## To verify

- **The mechanism is read from the source, not reproduced.** Building a six-region super-cluster to
  re-measure was out of reach; the two code paths and the constants are quoted at v2.14.6, and the
  thread supplies the measurements. The `--queue` confirmation step above is therefore a **proposed**
  test, not one this wiki has run.
- **The thread is unanswered** as of 2026-08-31. No maintainer has confirmed this reading.
