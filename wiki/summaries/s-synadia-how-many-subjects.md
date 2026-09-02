---
title: "Synadia — How Many Subjects Should a NATS JetStream Stream Have? (and two Insights check pages)"
type: summary
area: [jetstream, monitoring]
source-url: https://www.synadia.com/blog/how-many-subjects-jetstream-stream
source-path: raw/synadia-blog/how-many-subjects-jetstream-stream.txt
author: "Andrew Connolly (Synadia)"
article: "Blog post, 2026-05-20; plus the undated Synadia Insights check pages JETSTREAM_025 (raw/synadia-insights/nats-subject-count-threshold.txt) and JETSTREAM_003 (raw/synadia-insights/nats-stream-message-limit.txt)"
date: 2026-05-20
version: "2.11"
tags: [subjects, cardinality, memory, sizing, republish, direct-get, deliver_last_per_subject, kv, consumers, insights, max_msgs, alerting]
aliases: []
sources: []
created: 2026-09-02
updated: 2026-09-02
---

# Synadia on subject count — a memory-sizing question, and two check definitions

The only published per-subject byte figure for the JetStream subject index, and the only public
statement that subject count lengthens recovery. Question-bank rows 9 and 5.

## The blog post (2026-05-20)

**The figure.** *"Each indexed subject has overhead, roughly a few hundred bytes."* *"Around 10
million subjects may add roughly 3-4 GB of memory overhead."* *"100 million subjects has been done,
but should not be treated as a casual default."* *"Millions of subjects can be practical if the
server has sufficient memory."* Subjects "are indexed in memory".

**The advice.** Subject count "by itself is not the only question" — size on message volume per
subject, retention, replication factor, storage, stream and consumer counts, delivery mode, and
"failover and restart time expectations". The real cost is usually **consumers, not subjects**: a
stateful JetStream consumer per filtered subscriber is expensive, and moving many subjects into one
stream does not remove that. Since 2.10 one consumer can carry several filter subjects, but the set
is fixed at creation.

**The design options** the post weighs: many durable consumers (independent replay, offline
subscribers); **stream republish** to plain NATS subjects for live fan-out, with JetStream as the
recovery path (the republished message carries the stream, sequence and original subject so gaps
can be detected; recovery by an ephemeral consumer or Direct Get); **last-value-on-connect** by a
`deliver_last_per_subject` consumer, a KV `Watch` (each watcher is a consumer), or republish plus
Direct Get (available since 2.9 with `allow_direct`; batched and multi-subject Direct Get since
2.11; "no single operation that performs a Direct Get and then atomically continues a live
subscription", so design for duplicates and gaps); and **partitioning** by subject or stream for
isolation, differing retention, write scaling and blast radius — "not only about subject count".

**Practical recommendations**, verbatim in spirit: estimate the index's memory; measure with real
cardinality and volume; decide whether subscribers need durable replay or mostly live delivery; avoid
one JetStream consumer per live subscriber where plain subscriptions plus recovery suffice; plan for
duplicates and races around the fetch-then-subscribe handoff.

## The two check pages (Synadia Insights, undated, unsigned)

Cited as what a commercial monitor watches, not as dated claims.

- **JETSTREAM_025 — Subject count threshold.** Fires when a stream's subject count exceeds the
  metadata keys `io.nats.monitor.subjects-warn` / `io.nats.monitor.subjects-critical` set on the
  stream (the page's examples: 100,000 / 500,000, and 50,000 / 200,000 on `nats stream add
  --metadata`). Those keys are a **product convention**, not a server feature — the server stores
  metadata and does nothing with it. The four costs it names: memory ("a stream with 10 million
  unique subjects can consume gigabytes of RAM just for the index"), consumer filter matching,
  **recovery time** ("when a server restarts, it rebuilds the subject index from the stream's
  storage. A stream with millions of unique subjects takes significantly longer to recover"), and
  operational visibility. It is explicit that publishing is *not* affected directly.
- **JETSTREAM_003 — Stream message limit.** Fires at **90 % of `max_msgs`**; the sizing formula
  `max_msgs = publish_rate_per_second × retention_window_seconds × safety_factor`, e.g. 1,000 msg/s ×
  86,400 s × 1.5 = 129,600,000; the fixes are `max_age`, `max_msgs_per_subject`, more consumers on a
  work queue, and a rule that every stream carries limits.

## What this wiki checked against it

The "few hundred bytes" figure agrees with the run in [[s-nats-server-stream-scale-observed]]
(~380 B per subject of process RSS at 1.2 M seven-digit subjects, block cache included) and with the
maintainer's "100 megs" per million ([[s-gh-8333-high-cardinality-subjects]]) within the spread one
expects between an index estimate and a whole-process measurement. The recovery claim is correct in
direction and incomplete in mechanism: at v2.14.6 the index is rebuilt from `index.db` after a clean
stop, from every block otherwise, and **above 1,000,000 subjects the periodic `index.db` is not
written at all** ([[s-nats-server-filestore-recovery]]).

## Questions it answers

Row **9** (the byte figure and the design advice); the message-limit formula is context for row **5**.

## Pages touched

[[jetstream-sizing]] · [[filestore-layout]] · [[synadia]] · [[stream]]
