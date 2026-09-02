---
title: Publishing to a stream
type: concept
area: [jetstream]
since: []
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [PubAck, Nats-Msg-Id, duplicate, duplicate_window, async-publish, atomic-batch, fast-ingest, AllowAtomicPublish, AllowBatchPublish, Nats-Batch-Id, Nats-Expected-Last-Subject-Sequence, exactly-once, persist_mode]
aliases: [publish, PubAck, pub ack, exactly once, exactly-once, deduplication, dedup, Nats-Msg-Id, msg id, async publish, atomic batch, batch publish, fast ingest, publish acknowledgement]
sources: [s-docs-publishing, s-docs-advanced-publishing, s-nats-server-constants-2.14.6, s-adr-1-jetstream-json-api, s-docs-stream-config, s-relnotes-2.14.0, s-docs-upgrade-to-2.12, s-docs-upgrade-to-2.14, s-gh-6628-ackwait-vs-dupe-window, s-adr-51-message-scheduler, s-docs-jetstream-headers, s-nats-server-message-schedules-observed, s-nats-server-mirror, s-nats-server-mirrors-observed]
created: 2026-08-31
updated: 2026-09-02
---

# Publishing to a stream

A JetStream publish is a core publish that gets an answer. That answer — the **`PubAck`** — is the
only proof the message was stored, and everything difficult about publishing follows from what
happens when it does not arrive.

## What it behaves like

**You publish to a subject, never to a stream.** The server finds the stream capturing the subject
and stores the message there; the publisher does not name the stream and does not need to know which
one bound the subject (source: [[s-docs-publishing]]).

**The `PubAck` carries three fields you use** — `stream`, `sequence`, and `duplicate` — plus
situational ones such as `domain` on a multi-tenant or leafnode setup ([[jetstream-domain]]). On the
CLI it is the line `Stored in Stream: ORDERS Sequence: 1`.

**Sequence numbers start at 1, only increase, and are never reused** — not after a delete, not after
a purge (see *Sequences are addresses* on [[stream]]).

**Stored is not delivered.** A `PubAck` says the stream holds the message. Whether any consumer has
seen it is a separate question with a separate answer ([[ack-and-redelivery]]). "Code that marks an
order shipped as soon as the `PubAck` returns is acting on a write that no shipping logic has seen."

### The two failure modes are not the same

| what happened | what you know | what to do |
|---|---|---|
| **`no responders`** | Nothing was stored. No stream captures that subject. | Fix the subject or the stream. Retrying will not help. |
| **timeout** | **Nothing.** "The server may have stored the message and the ack got lost on the way back." | Retry — but only with a `Nats-Msg-Id`. |

`nats: no responders available for request` is a **core** status, not a JetStream error code, which
is why it carries no `err_code` ([[error-codes]]). It reaches you immediately; a timeout does not.

**`nats pub` without `--jetstream` hides the first case.** A plain publish prints
`Published 4 bytes to "invoices.created"` whether or not a stream stored it. Only `--jetstream` reads
the ack (source: [[s-docs-publishing]]):

```
nats pub invoices.created "test"
# 17:31:21 Published 4 bytes to "invoices.created"

nats pub --jetstream invoices.created "test"
# 17:31:21 Published 4 bytes to "invoices.created"
# nats: error: nats: no responders available for request
```

## Exactly-once, honestly

**JetStream does not give exactly-once delivery. It gives at-least-once storage with duplicate
suppression over a bounded window**, and at-least-once delivery on the read side. That is the answer
to the question people actually ask, and the mechanism is two pieces that must both be right.

**1 · The publisher supplies an identity.** Set `Nats-Msg-Id` on every publish you might retry:

```
nats pub --jetstream orders.created \
  --header "Nats-Msg-Id:ord_8w2k-created" '{"order_id":"ord_8w2k", …}'
```

Run it twice and the second call "prints the same sequence number with `Duplicate: true`, and nothing
new is stored" (source: [[s-docs-publishing]]). Use an ID the producer can **recompute** — an order
ID, a request ID, a hash of the payload — because a retry after a process restart must produce the
same one.

**2 · The stream supplies a window.** `duplicate_window` bounds how long the server remembers those
IDs. The default is **2 minutes** (`StreamDefaultDuplicatesWindow`, `stream.go:1658` at v2.14.6,
source: [[s-nats-server-constants-2.14.6]]) — and it is stated in prose in the docs' own publishing
chapter as well: "the duplicate-tracking window is two minutes by default"
(source: [[s-docs-publishing]]).

**The window is the whole guarantee.** A retry that arrives later than the window stores a second
copy, header or no header. So the promise is precisely: *a publish repeated within `duplicate_window`
with the same `Nats-Msg-Id` is stored once.* Three things narrow it further, all on [[stream]]: the
default applies only when the stream sets no window and is neither a mirror nor a source; the value
is clamped down by the account's `Duplicates` limit and by `max_age`; and the tracked IDs live in
**RAM**, so a long window on a high-cardinality publisher is a memory cost ([[jetstream-sizing]]).

**On the delivery side there is no equivalent.** A consumer can be delivered a message more than once
— that is what `ack_wait` and `max_deliver` are for — so an end-to-end exactly-once system needs an
idempotent consumer as well ([[ack-and-redelivery]]). Deduplication protects the *stream* from double
writes; nothing protects a side effect from running twice except your own code.

## Ordering, and what breaks it

**A stream is ordered by its own sequence**, which the server assigns as messages arrive and store.
There is no per-key ordering primitive: if you need messages about one entity to stay in order, put
them on one subject and read them through one consumer, or shard deterministically with
`{{partition(n,1)}}` ([[subject-transforms]]) so one entity always lands in one bucket.

**Synchronous publishing preserves your send order.** Each publish is confirmed before the next is
sent, so send order and stream order agree.

**Async publishing does not**, and the failure is subtle. Publishes 1–6 are fired without waiting; 3
fails while 4, 5 and 6 succeed. Nothing is resent on its own — "order 3 is simply missing" — and by
the time your retry runs, 4, 5 and 6 are stored, "so the re-published order 3 lands last, at
sequence 7" (source: [[s-docs-advanced-publishing]]). Two different fixes for two different problems:

- the **ack** was lost but the message landed → `Nats-Msg-Id`, and the repeat is dropped;
- the **order** matters → `Nats-Expected-Last-Subject-Sequence`, which stores the message only when
  the subject's last sequence is the one you expect and rejects it otherwise, so an out-of-order
  retry "fails fast… instead of silently landing in the wrong place".

> "An async publish you never check is a lost write."

**A gap in the sequence is not a lost message.** Deletes and purges leave permanent holes, and
consumers step over them without blocking ([[stream]]).

## The four publish modes

| mode | reach for it when | all-or-nothing | opt-in | since |
|---|---|---|---|---|
| **one at a time** | the default — simple, ordered, safe to retry | n/a | none | — |
| **async** | you publish at volume and one-at-a-time is too slow | no | none (a client feature) | — |
| **atomic batch** | a group of messages must land together or not at all | **yes** | `allow_atomic` (`AllowAtomicPublish`) | **2.12** |
| **fast-ingest batch** | maximum sustained throughput, gaps tolerable or fatal | no | `allow_batched` (`AllowBatchPublish`) | **2.14** |

(source: [[s-docs-advanced-publishing]]; the flags and their arrival are confirmed by
[[s-docs-upgrade-to-2.12]], [[s-docs-upgrade-to-2.14]] and [[s-docs-stream-config]].)

### Async

A client-library feature with **no stream setting**. Support is uneven and worth knowing before you
design around it: Go, Java, .NET and Rust have a dedicated call returning a future; nats.js works by
not awaiting each `publish()`; **nats.py has no first-class async publish**, and the docs' own example
approximates it with `asyncio.gather` while noting the client "does not bound how many are in flight"
([[nats-py]]). On the CLI the everyday `nats pub` is synchronous; the async path exists only in the
benchmark, `nats bench js pub async orders.created --batch 1000`.

### Atomic batch — 2.12

The stream opts in with `allow_atomic` (`nats stream add --allow-batch`). The publisher opens a batch
with **`Nats-Batch-Id`**, numbers each message with an increasing **`Nats-Batch-Sequence`**, and marks
the last with **`Nats-Batch-Commit`**. The server stages the messages and writes them as a unit only
on commit; the committing `PubAck` carries **`batch`** and **`count`**.

```
printf '%s\n' '{"order_id":"ord_8w2k","line":"sku-1"}' '{"order_id":"ord_8w2k","line":"sku-2"}' \
  | nats pub --atomic --send-on=newline --force-stdin orders.created
# Wrote batch ID: heTjQHWT0emRc98Os9nUtx Messages: 3 Sequence: 3
```

**Three ways a batch ends without committing**, and only two of them tell you:

- a **sequence gap** or an **over-limit batch** → an error `PubAck`, so the publisher hears about it;
- **ten seconds without a message** → the batch is dropped **with no error reply**, and the server
  raises a `stream_batch_abandoned` advisory instead
  (`$JS.EVENT.ADVISORY.STREAM.BATCH_ABANDONED.<stream>`, [[advisories]]).

So **the committing `PubAck` is the only proof a batch landed.** Do not infer it from the individual
publishes.

**Client support is the practical constraint**: the `nats` CLI and nats.js carry it in the core
client; Go, Java, Rust and .NET reach it through [[orbit]]; nats.py has to drive the `Nats-Batch-*`
headers directly.

### Fast-ingest batch — 2.14

Built to replace async publish: "the client opens one channel and the server runs flow control over
it… the server acks in batches and tells each publisher how fast it may go — ramping up while it
keeps up, slowing down under load", which is what keeps many concurrent fast publishers balanced.
The stream opts in with `allow_batched`.

It gives up atomicity, and the trade is chosen per batch:

- **`gap: fail`** — abandon the batch at the first gap, so what is stored has no holes. For ordered
  data such as the chunks of an [[object-store]] object.
- **`gap: ok`** — report the gap and keep going. **This loses data by design**; use it only where a
  hole is acceptable, such as metrics.

There is no stable public publisher in most clients yet: the CLI has it only in `nats bench js pub
fast`; Go, Rust and JavaScript reach it through [[orbit]]; Python, Java and .NET have the stream flag
with the publishers still landing.

### One combination the server refuses

**`allow_atomic` and `persist_mode: async` do not mix.** "A stream set to persist asynchronously
rejects atomic publishing, because the atomicity depends on the synchronous write path. Fast-ingest
batches are fine on such a stream" (source: [[s-docs-advanced-publishing]]). Both are `persist_mode`
and `allow_atomic` on [[stream]]; neither can be changed after creation.

### The window bounds re-*publication*, not re-*delivery*

The duplicate window is consulted **on publish and never on delivery**, so it does nothing about a
consumer redelivering a message the stream already holds. Operators conflate the two often enough
that a maintainer has had to say it outright (source: [[s-gh-6628-ackwait-vs-dupe-window]]):

> "AckWait and DupeWindow are two different settings that are not related to each other."
> — @MauriceVanVeen, 2025-03-10

`duplicate_window` is a **stream** setting bounding how long the server remembers a `Nats-Msg-Id`;
`ack_wait` is a **consumer** setting bounding how long it waits for an answer before delivering the
same stored message again ([[ack-and-redelivery]]). The asker of that thread had a `10m` window
against an `8m` `ack_wait` and expected the longer window to suppress the redeliveries; it cannot,
and no stream setting can. To be handled once, bound the deliveries — `max_deliver: 1`, or an ack or
term on every path.


## Limits and failure modes

- **Batch size and in-flight limits.** The docs state **1,000 messages per atomic batch** and **at
  most 50 batches in flight per stream**, "both operator-configurable server limits, not fixed
  protocol caps" — the doc page's own words. This wiki has **not** confirmed either against the
  server or found the config keys that change them; ADR-50 is named as the authority and has not been
  read (source: [[s-docs-advanced-publishing]]).
- **The batch error codes** are in [[error-codes]] — `10176`, `10179`, `10199`, `10201`, `10210` for
  atomic publishing and `10205`–`10209`, `10211` for batch publishing, including
  `10209 stream mirrors can not also use batch publishing`.
- **A duplicate is not an error.** `duplicate: true` comes back with the original sequence and a
  success status; code that treats a non-zero `duplicate` as a failure will retry forever.
- **`max_payload` bounds a single message** (`1MB` by default), and a batch does not get around it —
  each message is still a message ([[defaults-and-limits]]).

### A publisher that never waits for an ack can be dropped at the stream

A core-NATS publish into a stream's subject has no back-pressure. The stream queues inbound
messages in an internal queue capped at **100,000 messages or 128 MB**
(`streamDefaultMaxQueueMsgs`, `streamDefaultMaxQueueBytes`, `stream.go:441–442` at 2.14.6, source:
[[s-nats-server-mirror]]); past that the server drops and logs once:

```
[WRN] Dropping messages due to excessive stream ingest rate on '$G' > 'KV_DNS': IPQ len limit reached
```

Observed on 2.14.6: 2,400,000 publishes fired at a file-backed KV stream over loopback without
waiting for any `PubAck` left 337,733 messages stored; the same publisher keeping 4,000 in flight
lost none at ~200,000 msg/s (source: [[s-nats-server-mirrors-observed]]). Fire-and-forget into
JetStream is not a publish mode; use async publish with a bounded pending window and read every
ack.


## A fifth mode: publish now, store for later

**Since 2.12** a publish can carry a *schedule* instead of being stored as an ordinary message: the
stream keeps it and produces messages on a target subject at the times the headers ask for
([[message-scheduling]]). It is a publish-time feature — the whole configuration is headers on one
`nats pub` — so two things belong on this page.

**The headers**, in the same namespace as everything above (source: [[s-docs-jetstream-headers]]):
`Nats-Schedule`, `Nats-Schedule-Target`, `Nats-Schedule-Source`, `Nats-Schedule-TTL`,
`Nats-Schedule-Time-Zone`, `Nats-Schedule-Rollup` — and, on the messages the server generates,
`Nats-Scheduler` and `Nats-Schedule-Next`. Extra headers on the schedule ride through to the target
verbatim.

**`nats pub` without `-J` cannot report a rejected publish.** This is not specific to schedules and it
matters for every header on this page: a plain `nats pub` is a **core NATS publish**, so it sets no
reply subject, the `PubAck` has nowhere to go, and the CLI prints `Published N bytes` for a message
the server refused. Observed at v2.14.6: the same invalid schedule prints an error with `-J` and
nothing without it (source: [[s-nats-server-message-schedules-observed]]).

```
nats pub    schedules.x 'body' -H 'Nats-Schedule:*/5 * * * *' …   # "Published 1 bytes" — and refused
nats pub -J schedules.x 'body' --schedule-cron='*/5 * * * *' …    # "message schedules pattern is invalid (10189)"
```

**Cancelling a schedule uses this page's expected-state headers.** `Nats-Schedule-Next: purge` plus
`Nats-Scheduler: <schedule subject>`, optionally with `Nats-Expected-Last-Subject-Sequence`, stops a
schedule and publishes a message as one atomic operation (source: [[s-adr-51-message-scheduler]]).


## To verify

- **The 1,000-message and 50-in-flight batch limits, and the config keys that change them.** Stated
  by the docs, unconfirmed against `nats-server` and unlocated in `inbox/config-keys-table.md`.
  **(unverified)**
- **The ten-second atomic-batch stall timeout** — same status: stated by the docs only.
- Whether `Nats-Expected-Last-Subject-Sequence` and its siblings (`Nats-Expected-Stream`,
  `Nats-Expected-Last-Sequence`) have their own error codes on rejection.
  `reference/jetstream/api/headers.md` is in `raw/` and has not been read.

## Related

[[stream]] · [[ack-and-redelivery]] · [[consumer]] · [[subject-transforms]] · [[error-codes]] ·
[[advisories]] · [[defaults-and-limits]] · [[jetstream-sizing]] · [[nats-server-2.12]] ·
[[nats-server-2.14]] · [[orbit]] · [[direct-get]] · [[mirrors-and-sources]]

## Sources

- [[s-docs-publishing]] — the `PubAck`, the two failure modes, `Nats-Msg-Id`, and the two-minute
  window in prose.
- [[s-docs-advanced-publishing]] — async, atomic batch and fast ingest, with their headers, limits
  and the `persist_mode` incompatibility.
- [[s-nats-server-constants-2.14.6]] — `StreamDefaultDuplicatesWindow` at the tag.
- [[s-docs-stream-config]] — `allow_atomic`, `allow_batched` and `persist_mode` in the config schema.
- [[s-docs-upgrade-to-2.12]] · [[s-docs-upgrade-to-2.14]] — the releases the two batch modes shipped
  in.
- [[s-relnotes-2.14.0]] — the `Nats-Batch-Commit: eob` end-of-batch commit.
- [[s-adr-1-jetstream-json-api]] — the `PubAck` as an API response. · [[s-gh-6628-ackwait-vs-dupe-window]] · [[s-adr-51-message-scheduler]] · [[s-docs-jetstream-headers]] · [[s-nats-server-message-schedules-observed]] · [[s-nats-server-mirror]] · [[s-nats-server-mirrors-observed]]
