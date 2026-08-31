---
title: Ordered consumer
type: concept
area: [jetstream, clients]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [ordered-consumer, ephemeral, heartbeats, gap-detection]
aliases: [ordered consumer, OrderedConsumer]
sources: [s-gh-5243-kv-watchers-at-scale, s-adr-17-ordered-consumer, s-adr-8-key-value-store, s-docs-reading-back, s-docs-kv-watching]
created: 2026-08-31
updated: 2026-08-31
---

# Ordered consumer

An ordered consumer is a **client-side** construct, not a server feature: a push subscription that
watches the consumer sequence, and when it sees a gap, **throws its consumer away and builds a new
one** starting at the last good stream sequence (source: [[s-adr-17-ordered-consumer]]). It is what
KV watches, KV history and KV key listing are built on ([[key-value]]).

## How it behaves

- It **tracks the last good stream and consumer sequence**.
- **On a gap** it closes the subscription, releases the consumer, and creates a new one at the
  proper stream sequence.
- **On missed heartbeats** it assumes the consumer is gone — deleted, lost after a reconnect, lost
  to a node restart — and recreates it from the last known stream sequence.
- The state may optionally be exposed to the user.

## What it cannot be

An ordered consumer **cannot** be a **pull** consumer, a **durable**, bound or "direct", and it
**cannot be used with queues or deliver groups**.

## The configuration it forces

If a user supplies a consumer configuration it is validated and **rejected on mismatch**:

| field | rule |
|---|---|
| `durable_name` | must not be provided |
| `deliver_subject` | must not be provided |
| `ack_policy` | must be absent or `none`; set to `none` if absent |
| `max_deliver` | must be absent or `1`; set to `1` if absent |
| `flow_control` | must be absent or `true`; set to `true` if absent |
| `mem_storage` | must be absent or `true`; set to `true` if absent |
| `num_replicas` | must not be provided; **set to `1`** |

Set silently, without erroring:

| field | value |
|---|---|
| `idle_heartbeat` | **5 seconds** if not provided |
| `ack_wait` | "something large like **22 hours**", matching the Go implementation |

## Why an operator cares

**It is ephemeral, memory-backed, R1 and unacknowledged.** `mem_storage: true`, `num_replicas: 1`
and `ack_policy: none` together mean an ordered consumer keeps no durable state and survives
nothing — by design, because it rebuilds itself.

**It shows up as consumer churn.** Every gap and every heartbeat miss deletes one consumer and
creates another under a new name. In `nats consumer ls` and in consumer-count metrics that reads as
short-lived consumers appearing and vanishing. It is also exactly the "many short-lived consumers"
pattern named as a memory cost on [[jetstream-sizing]] — so a workload built on many KV watchers is
paying that cost by construction.

**The churn, not the count, is what breaks a cluster.** Each create and each delete is an assignment
the meta layer has to land, and the deletions are what fall behind: 1000 clients each watching one KV
key produced a flood of `Consumer assignment for '<acc> > <stream> > <name>' not cleaned up, retrying`
on a bucket holding a **single 118-byte message**, with all three nodes pinned at their CPU limit
(source: [[s-gh-5243-kv-watchers-at-scale]]). See [[kv-watchers-stall-the-cluster]].

**A stuck ordered consumer will not look like a redelivery problem.** With `ack_policy: none` there
are no acks to be outstanding, and the ~22-hour `ack_wait` means nothing times out. It will look
idle instead. Watch the `idle_heartbeat` instead of the ack counters.

**`num_replicas: 1` on a replicated stream is deliberate.** The consumer's state is not worth
replicating because it is rebuilt on failure — see the consumer-replica rules on [[replicas]].

## To verify

- The ADR names **no server version**, and it is dated 2021-09-29 with status *Implemented*. The
  `idle_heartbeat` of 5s and `ack_wait` of ~22h are **client defaults described in the ADR**, not
  server defaults, and individual clients may differ.

## The plain ephemeral it is built on

An ordered consumer is a client construct over an **ephemeral** consumer, and the ephemeral's own
rule is the one that makes the construct necessary: "an ephemeral consumer keeps no position you can
return to… it's removed once it goes idle, and a reconnect then starts over from the beginning"
(source: [[s-docs-reading-back]]). The `nats` CLI builds one whenever `nats sub` is given a JetStream
flag such as `--all`, which is why a one-off replay costs nothing to clean up — and why it is the
wrong tool for a reader that must resume ([[consumer]]).

**A KV watch is one of these, and its lifecycle is the watch's.** "Opening the watch creates it, and
closing the watch removes it" — which is why a watch is live state and never a point read, and why
using one to fetch a single value "pays for a consumer and a snapshot" that [[direct-get]] would have
answered outright (source: [[s-docs-kv-watching]]; [[key-value]]).

**Two readers do not share the work.** "Each reader gets its own ordered consumer with its own
position, so two processes reading this way both read the whole stream — they don't split it." That
is a fan-out, not a pool; to share work use a named consumer and a [[worker-pool]]
(`learn/jetstream/ordered-consumer.md`, spot-checked 2026-08-31; that page has not been ingested).

## Related

[[consumer]] · [[key-value]] · [[ack-and-redelivery]] · [[replicas]] · [[jetstream-sizing]] ·
[[kv-watchers-stall-the-cluster]] · [[jetstream-slows-as-consumers-grow]]

## Sources

[[s-adr-17-ordered-consumer]] · [[s-adr-8-key-value-store]] · [[s-gh-5243-kv-watchers-at-scale]] ·
[[s-docs-reading-back]] · [[s-docs-kv-watching]]
