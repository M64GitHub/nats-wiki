---
title: "Synadia — Understanding JetStream Memory Usage Patterns"
type: summary
area: [jetstream, deploy]
source-url: https://www.synadia.com/blog/nats-jetstream-high-ram-usage
source-path: raw/synadia-blog/nats-jetstream-high-ram-usage.txt
author: Andrew Connolly (Synadia) — series *NATS Community FAQs*
article: Understanding JetStream Memory Usage Patterns
date: 2025-08-08
version: ""               # the post names no nats-server version
tags: [memory, duplicate_window, meta-leader, pprof, sizing]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# Synadia — Understanding JetStream Memory Usage Patterns

A Community-FAQ post answering a user who saw **13 GB of a 16 GB `GOMEMLIMIT`** used on one node of
a JetStream cluster — on stream/consumer leaders and the meta leader — while other nodes sat at
2–3 GB, and where memory stayed elevated **after all clients were stopped**. Their workload was
**300M+ messages across a few streams with a single consumer each**.

## Key claims

**What JetStream actually spends memory on** — four contributors, none of them "message count":

- **Message deduplication** — in-memory tables of recently seen message IDs, sized by the
  configured deduplication window. **The post states the default deduplication window is
  2 minutes**, and its Go snippet comments `Duplicates: time.Second * 30, // Reduced from default
  2 minutes`.
- **File store caching** — recently accessed messages and stream data are cached in memory to
  improve read performance.
- **Metadata and subject tracking** — stream, consumer and subject state held in memory for quick
  lookups.
- **Cluster meta leadership** — a node acting as **meta leader** coordinates and holds state for
  **all** streams, which adds overhead on that node specifically.

**The misconception it corrects**

> "While message count and size affect disk usage, they don't directly correlate with memory usage
> unless consumers are performing full stream scans or creating many short-lived consumers."

300M messages across a few streams with single consumers **should not** inherently cause high
memory usage. Memory is driven by **architectural patterns** — meta leadership, deduplication
settings, consumer lifecycle — far more than by raw message volume.

**The levers it recommends**

- **Tune deduplication.** If you deduplicate externally, disable the feature or reduce the window
  **per stream**.
- **Fewer subjects per stream** where possible.
- **Long-lived consumers are more memory-efficient than short-lived ones.**
- **Separate meta leadership from nodes handling high-volume streams.**
- For memory that none of the above explains, **profile with Go's `pprof`** — the post's own
  conclusion for this questioner.

## Practical takeaways

- An asymmetric memory profile across a cluster (one node far higher than its peers) is expected
  when that node holds meta leadership and stream/consumer leadership — it is a **leadership**
  question before it is a leak.
- Memory that stays high after clients disconnect points at the caches and tables above, not at
  connection state.
- The deduplication window is a **memory** setting as much as a correctness one; a long window on a
  high-cardinality publisher is paid for in RAM.

## Relevance to the wiki

The RAM half of [[jetstream-sizing]] — the docs' sizing page gives storage numbers but says nothing
about what JetStream holds in memory. It also supplies the only value read so far for the
**deduplication window default (2 minutes)**, which the generated `StreamConfig` schema records
only as "0 for default".

## Caveats on citing it

- **The post names no `nats-server` version** and is dated 2025-08-08, before the 2.14 tree this
  wiki is otherwise verified against. Treat the 2-minute dedup default as *stated by Synadia in
  August 2025*, not as verified against 2.14 — see the `## To verify` note on [[stream]].
- It is a blog answer to one user's thread, not a reference: the four contributors are named, but
  no formula, coefficient or per-object byte cost is given.

## Questions it answers

Q3 in part (running JetStream resource-effectively — the memory levers). **Not** Q10, which asks
specifically why memory grows with the number of *unacknowledged* messages; this post does not
address pending-message state at all.

## Pages touched

[[jetstream-sizing]] · [[stream]] · [[raft-in-nats]]
