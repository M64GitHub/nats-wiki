---
title: Publishing to a stream
type: concept
area: [jetstream]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-09-04
tags: [PubAck, Nats-Msg-Id, duplicate, duplicate_window, async-publish, atomic-batch, fast-ingest, AllowAtomicPublish, AllowBatchPublish, Nats-Batch-Id, Nats-Expected-Last-Subject-Sequence, exactly-once, persist_mode]
aliases: [publish, PubAck, pub ack, exactly once, exactly-once, deduplication, dedup, Nats-Msg-Id, msg id, async publish, atomic batch, batch publish, fast ingest, publish acknowledgement]
sources: [s-docs-publishing, s-docs-advanced-publishing, s-nats-server-constants-2.14.6, s-adr-1-jetstream-json-api, s-docs-stream-config, s-relnotes-2.14.0, s-docs-upgrade-to-2.12, s-docs-upgrade-to-2.14, s-gh-6628-ackwait-vs-dupe-window, s-adr-51-message-scheduler, s-docs-jetstream-headers, s-nats-server-message-schedules-observed, s-nats-server-mirror, s-nats-server-mirrors-observed, s-relnotes-2.12, s-relnotes-2.14, s-relnotes-2.10, s-nats-server-stream-consumer-config, s-issue-8271-request-info-max-payload, s-nats-server-share-import-observed, s-gh-7577-core-nats-ordering, s-docs-core-nats-publish-subscribe, s-nats-server-core-delivery, s-docs-resilient-clients-drain-and-shutdown, s-adr-22-publish-retries, s-docs-jetstream-where-next, s-nats-server-core-or-jetstream-observed, s-synadia-expected-sequence-headers, s-gh-3772-jetstream-as-an-event-store]
created: 2026-08-31
updated: 2026-09-04
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


### The header the server adds on a service import is not counted

`max_payload` is checked on the inbound `PUB`; a request that then crosses a service import gets a
`Nats-Request-Info` header added afterwards with no second check, so a request within a header's size
of the limit is **delivered oversized**. Observed on 2.14.6 with `max_payload: 256`: a 250-byte
request arrived at the responder as `HMSG … 257 507` (source:
[[s-nats-server-share-import-observed]]). Issue #8271 is open and its fix PR unmerged — the
maintainers' stated position is that `max_payload` "is generally about what the client sends not what
the server needs to add to it for tracking purposes" — so budget the header (about 250 bytes, plus the
user JWT when the import shares) below the limit rather than waiting for a fix (source:
[[s-issue-8271-request-info-max-payload]]; [[service-import-request-info]]).


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


## Version notes: the 2.12 line

**Since.** `since: [2.10]` in the frontmatter means *present at 2.10, the oldest line this wiki covers*:
the 2.10 release bodies patch publishing and the `PubAck` from v2.10.0 on and none records the arrival, which is
older than the archive (source: [[s-relnotes-2.10]]).

- **Atomic batch publish is 2.12.0** (#6966 … #7330, ADR-50). Its patches: **2.12.1** — a batch
  deduplicates on `Nats-Msg-Id` (#7391), rejects unsupported commits (#7368), checks the batch subject
  rather than the committing message's (#7342); **2.12.2** — the unsupported-header check looked at
  the wrong field (#7436); a deadlock between a direct get and a batch write (#7458); **2.12.9** — an
  *unsupported* advisory on an API-level mismatch (#8082); **2.12.12** — end-of-batch max-size checks
  and R1 message rewrites (#8305) (source: [[s-relnotes-2.12]]).
- **`Nats-Required-Api-Level`** (2.12.0, #7157) lets a publish or API request demand a server API
  level; from 2.12.4 the level error is returned only after the other checks, "preventing unexpected
  replies from other servers" (#7711).
- **A no-responders error names the original subject** in a `Nats-Subject` header from 2.12.0
  (#5250).
- **A publish exceeding the maximum store size is rejected before proposal** from 2.12.14 (#8389);
  the **32 MB** cap is 2.10.28 / 2.11.2 ([[s-relnotes-2.10]]); the ingest queue and its `429` are
  2.11.0 ([[s-relnotes-2.11]]).
- **Counters** (`Nats-Incr`, 2.12.0, ADR-49): staging corrupted the committed running total until
  2.12.12 (#8311); configuration constraints since 2.12.10 (#8240).


## To verify

- **The 1,000-message and 50-in-flight batch limits, and the config keys that change them.** Stated
  by the docs, unconfirmed against `nats-server` and unlocated in `inbox/config-keys-table.md`.
  **(unverified)**
- **The ten-second atomic-batch stall timeout** — same status: stated by the docs only.
- ~~Whether `Nats-Expected-Last-Subject-Sequence` and its siblings have their own error codes on
  rejection.~~ **Settled 2026-09-04** from `server/jetstream_errors_generated.go:849–896` at v2.14.6:
  six codes for five headers — see *The five expectation headers* above and [[error-codes]].

## The five expectation headers, and the one counter behind them

A conditional publish is the server checking one claim about the stream before it stores anything. All
five headers are in `server/stream.go:640–644` at v2.14.6:

| header | the claim | since |
|---|---|---|
| `Nats-Expected-Stream` | this subject is captured by *that* stream | ≤ 2.10 |
| `Nats-Expected-Last-Sequence` | the stream's last sequence is *n* | ≤ 2.10 |
| `Nats-Expected-Last-Subject-Sequence` | the last sequence **for this subject** is *n* | ≤ 2.10 |
| `Nats-Expected-Last-Subject-Sequence-Subject` | …but check that against this **wildcard** instead of the published subject | **2.11.0** (#5281) |
| `Nats-Expected-Last-Msg-Id` | the last stored `Nats-Msg-Id` is *this* | ≤ 2.10 |

`≤ 2.10` means present at **v2.10.29**, the oldest source tree this wiki holds; the release archive
starts at 2.10.0 and does not introduce them, so they are older than it. No source here dates them
further back, so no earlier version is claimed.

**There is one sequence counter, filtered three ways.** The per-subject and per-pattern forms do not
keep counters of their own: "The three header types don't create separate counters — they filter what
they check against: the whole stream, a single subject, or a wildcard pattern… **the expected value is
still a stream sequence number**, not an independent counter starting from zero" (source:
[[s-synadia-expected-sequence-headers]]). Publishing to `events.order.1`, `events.order.2`,
`events.order.1`, `events.order.2` in turn expects **0, 0, 1, 2** — the numbers jump because they are
stream sequences seen through a per-subject filter.

**The trap the per-subject form sets** is that subjects are exact: `events.order.1.created` and
`events.order.1.shipped` have completely independent tracking. When one entity's events span several
subjects — the event-sourcing case — the third header is what makes them share a sequence: send
`Nats-Expected-Last-Subject-Sequence: 1` together with
`Nats-Expected-Last-Subject-Sequence-Subject: events.order.1.*`. In nats.go's `jetstream` package the
three are `WithExpectLastSequence`, `WithExpectLastSequencePerSubject` and
`WithExpectLastSequenceForSubject(seq, pattern)`.

**What this buys, and its limit.** "concurrent appends across subjects without contention,
linearizability on a per-subject basis (entity event stream), while still gaining a total order of
events across all subjects within a stream for consumption" — and the check itself is claimed to be
free, because "subjects are indexed within a stream, so the OCC check does not add overhead" (source:
[[s-gh-3772-jetstream-as-an-event-store]]). It is **detection, not prevention**: the loser of a race
is rejected and must retry. Note the cost is not literally zero — the per-subject branch does a
`store.LoadLastMsg` for the subject on every such publish (`server/stream.go:6455–6470`) — only that it
is an indexed point read rather than a scan.

### What a rejection tells you

The codes are on [[error-codes]] — *The publish-expectation family*. The part that matters at the
publisher: **`10071 wrong last sequence: {seq}` carries a different number depending on which header
you sent.** The per-subject check answers with that subject's last sequence (`fseq`); the stream-wide
check answers with `mset.lseq`. Retrying with the number from the error is correct either way, which
is why clients can loop on it — but reading the number as "where the stream is" is only right for the
global form.

Two more worth knowing before designing a retry loop:

- **`10193 missing sequence for expected last sequence per subject`** — the pattern header sent without
  its companion. Surfaced as an error only since **2.12.0** (#7196); before that the combination failed
  quietly.
- **`10163 expected last sequence per subject temporarily unavailable`** is a **503**, not a 400. It is
  not your sequence being wrong; it is the check being unavailable, so the correct response is to retry
  unchanged rather than to re-read and correct.


## Version notes: the 2.14 line

- **Fast-ingest batch publishing is 2.14.0** (#7778, #7892, #7894, #7945, ADR-50), and so is the
  **end-of-batch commit** — `Nats-Batch-Commit: eob` on a final message that is not persisted
  (#7403). Its patches: **2.14.1** parses the batch sequence as a `uint64` (#8094) and no longer
  double-pools committed atomic-batch entries (#8098); **2.14.3** fixes failed fast-batch commits with
  `gapOk` (#8308) and the end-of-batch max-size checks and R1 rewrites (#8305); **2.14.4** fixes
  string ownership for the expected last sequence per subject in a batch (#8377); **2.14.6** a data
  race on the batch ID (#8369) (source: [[s-relnotes-2.14]]).
- **2.14.4**: a publish exceeding the maximum store size is rejected before proposal (#8389) — the
  same fix as 2.12.14.


## The batch limits, from the source

The three numbers the docs give for atomic batches — 1,000 messages per batch, 50 batches in flight
per stream, a ten-second stall before a batch is abandoned — are the compiled-in defaults
`streamDefaultMaxAtomicBatchSize`, `…InflightPerStream` and `streamDefaultMaxBatchTimeout`
(`stream.go:446–455` at v2.14.6), with a fourth the docs omit, 1,000 in flight in total; fast
batches allow 1,000 per stream and 50,000 in total. All are overridable in
`jetstream { limits { max_batch_size, max_batch_inflight_per_stream, max_batch_inflight_total,
max_batch_timeout } }` ([[config-keys]]). `allow_atomic` (2.12.0), `allow_batched` (2.14.0) and
`persist_mode` (2.12.0, fixed after creation, `async` incompatible with atomic batches) are on
[[stream-and-consumer-config]] with their update rules (source:
[[s-nats-server-stream-consumer-config]]).


## Flush is a receipt from the server, not a `PubAck`

A core publish gives you nothing back, so clients offer a **flush**: a `PING`, and the `PONG` that
answers it. Because a server processes one connection's bytes in order, a returned `PONG` proves the
server has **received** everything written before the `PING` (source:
[[s-docs-resilient-clients-drain-and-shutdown]]).

It is worth being exact about what that is and is not:

| | flush | `PubAck` |
|---|---|---|
| proves the bytes reached the server | yes | yes |
| proves a subscriber saw the message | **no** | no |
| proves the message was **stored** | **no** | yes — that is the whole point |
| costs | one round trip per flush | one per publish, or one per batch when async |

So a flush is the confirmation for a **core** publish burst — "after a flush returns, the orders are
on the server" — and it is *not* a substitute for a `PubAck` when the stream matters. Go's `Flush()`
has a fixed ten-second timeout; **Rust's `flush()` resolves when the bytes reach the socket, without
waiting for the PONG**, and **C# has no flush at all** (`PingAsync()` is the same round trip).
[[client-defaults]] has the per-client column; [[client-connection-lifecycle]] has the drain that
ends with this same flush.


## Core NATS order, for comparison

Before a stream is involved, order is **per publisher connection, across every subject**: "for a single
publish connection order will always be preserved globally", with several publishers interleaving
(source: [[s-gh-7577-core-nats-ordering]]). A stream then assigns its own sequence in the order the
leader receives messages — which for one synchronous publisher is that publisher's order, and for several,
or for an async publisher with a failed publish, is not (above). The core rule and its consequences are
on [[core-nats-delivery]].


Two more things the core layer decides for a JetStream publish. A publish is fire-and-forget on the wire
— only the `PubAck` above turns it into a confirmed write (source: [[s-docs-core-nats-publish-subscribe]]).
And a JetStream publish with headers is an `HPUB`, so the server's `max_payload` check counts the header
block — `Nats-Msg-Id`, the `Nats-Expected-*` headers, a batch's headers — together with the body, and a
violation closes the connection rather than returning an error (`processHeaderPub`, `client.go:2916–2930`;
source: [[s-nats-server-core-delivery]]).


## Why a publish can 503, and what to do about each cause

A JetStream publish is a core request, so "nobody is listening" is one of its outcomes. It has two
causes that look identical on the client and want opposite responses.

**A leadership blip — retry.** [[s-adr-22-publish-retries]] was written for exactly this: "when the
NATS Server is running with JetStream on cluster mode, there can be occasional blips in leadership
which can result in a number of `no responders available` errors during the election", answered with
a 503 status "right away". The Go client's remedy, still the default at nats.go v1.53.1, is
`DefaultPubRetryWait = 250ms` and `DefaultPubRetryAttempts = 2` — three sends in all — with
`RetryAttempts(-1)` meaning "until the context deadline". When the retries run out the error changes
from `no responders available for request` to **`nats: no response from stream`**, and that difference
is how you tell a client that retried from one that did not.

Measured on an R3 stream at 2.14.6: a stream-leader step-down cost a publisher **exactly one publish
out of 312**, 32 ms after the step-down command, while a core publisher on the same server through the
same seconds saw nothing. A **meta**-leader step-down in the same run cost nothing at all — publishes
are served by the stream's leader, not the meta leader (source:
[[s-nats-server-core-or-jetstream-observed]]).

**No stream captures this subject — a design error.** Same error string, 24 ms, and retrying will
never help. Check with `nats stream ls` and `nats stream subjects <name>` before reaching for a retry
policy.

**`nats pub -J` does neither.** natscli v0.4.0 issues a plain `nc.RequestMsg(msg, opts().Timeout)`
(`cli/pub_command.go:279`) and never retries, and it prints `Published N bytes …` *before* the request
is sent — so a failing JetStream publish from the CLI prints a success line followed by an error. Use
it as a diagnostic, not as a model of what a client does.

And whatever the mode, the `PubAck` means one thing only: "a stored message has not yet been
processed" — wait for delivery and the consumer's ack before acting on a business outcome (source:
[[s-docs-jetstream-where-next]]). [[core-or-jetstream]] is where to decide whether this flow needs any
of it.


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
- [[s-adr-1-jetstream-json-api]] — the `PubAck` as an API response. · [[s-gh-6628-ackwait-vs-dupe-window]] · [[s-adr-51-message-scheduler]] · [[s-docs-jetstream-headers]] · [[s-nats-server-message-schedules-observed]] · [[s-nats-server-mirror]] · [[s-nats-server-mirrors-observed]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]] · [[s-relnotes-2.10]] · [[s-nats-server-stream-consumer-config]] · [[s-issue-8271-request-info-max-payload]] · [[s-nats-server-share-import-observed]] · [[s-gh-7577-core-nats-ordering]] · [[s-docs-core-nats-publish-subscribe]] · [[s-nats-server-core-delivery]] · [[s-docs-resilient-clients-drain-and-shutdown]] · [[s-adr-22-publish-retries]] · [[s-docs-jetstream-where-next]] · [[s-nats-server-core-or-jetstream-observed]] · [[s-synadia-expected-sequence-headers]] · [[s-gh-3772-jetstream-as-an-event-store]]
