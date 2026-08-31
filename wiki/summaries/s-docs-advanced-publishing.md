---
title: "docs — JetStream: Advanced publishing"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/learn/jetstream/advanced-publishing.md
source-path: raw/nats-docs/learn/jetstream/advanced-publishing.md
author: nats-io docs
article: "learn/jetstream/advanced-publishing.md"
date: 2026-08-31          # fetched
version: "2.12, 2.14"     # names the releases the two batch modes arrived in
tags: [async-publish, atomic-batch, fast-ingest, AllowAtomicPublish, AllowBatchPublish, Nats-Batch-Id, Nats-Batch-Sequence, Nats-Batch-Commit, Nats-Expected-Last-Subject-Sequence, persist_mode, ADR-50]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — JetStream: Advanced publishing

The three publish modes beyond one-at-a-time, and the only place in the `learn` tree that describes
atomic batch and fast-ingest publishing as behaviour rather than as a config flag. Prose and CLI
only; the page repeats one example in seven client languages.

## Key claims

### Async publish

"An async publish doesn't wait: you fire each publish and keep going, then collect the acks
afterward." The contract is unchanged — one `PubAck` per message — only *when* you check it changes.

**The order trap, which is the reason to read the page.** A failed async publish "doesn't land, so
order 3 is simply missing — and you send it again… By then 4, 5, and 6 are already stored, so the
re-sent order takes a higher sequence and ends up *after* the orders you sent next." Two fixes for
two different problems:

- a lost **ack** with the message stored → a stable `Nats-Msg-Id`, and the server drops the repeat;
- **order** itself matters → `Nats-Expected-Last-Subject-Sequence` on each publish, so "an
  out-of-order retry then fails fast… instead of silently landing in the wrong place."

> "An async publish you never check is a lost write."

**There is no stream setting for async publish** — it is a client-library feature, and support
differs: Go, Java, .NET and Rust have a dedicated call; nats.js does it by not awaiting each
`publish()`; **nats.py has no first-class async publish** and the docs' example approximates it with
`asyncio.gather`, with the caveat that "the client does not bound how many are in flight". On the
CLI "the everyday `nats pub` is synchronous; the async path lives in the benchmark,
`nats bench js pub async orders.created --batch 1000`."

### Atomic batch publish — **server 2.12**

All-or-nothing for a group of messages. The stream opts in with **`AllowAtomicPublish`**
(`allow_atomic`; CLI `--allow-batch`). The protocol:

- the client opens a batch with **`Nats-Batch-Id`**, tags each message with an increasing
  **`Nats-Batch-Sequence`**, and marks the last with **`Nats-Batch-Commit`**;
- "the server holds the messages in a staging buffer and writes them as a unit only on commit";
- the committing `PubAck` carries two extra fields, **`batch`** and **`count`**.

**The limits, as the page states them:** "By default it's capped at 1,000 messages and a stream
allows at most 50 batches in flight — both are operator-configurable server limits, not fixed
protocol caps." A sequence gap or an over-limit batch "is rejected with an error `PubAck`", and **a
batch that goes ten seconds without a message is dropped with no error reply** — the server raises a
`stream_batch_abandoned` advisory instead ([[advisories]]).

CLI:

```
printf '%s\n' '{"order_id":"ord_8w2k","line":"sku-1"}' … \
  | nats pub --atomic --send-on=newline --force-stdin orders.created
# Wrote batch ID: heTjQHWT0emRc98Os9nUtx Messages: 3 Sequence: 3
```

**Client support is uneven:** the CLI and nats.js have it in the core client; **Go, Java, Rust and
.NET reach it through the Synadia Orbit companion libraries**; nats.py drives it with the raw
`Nats-Batch-*` headers.

### Fast-ingest batch publish — **server 2.14**

"Built to replace async publish: instead of the client guessing how fast to push and paying to track
every ack, the client opens one channel and the server runs flow control over it. The server acks in
batches and tells each publisher how fast it may go." The stream opts in with **`AllowBatchPublish`**
(`allow_batched`).

It **trades away atomicity**, and the trade is per batch:

- **`gap: fail`** — "abandons the batch on the first gap, so what's stored is in order with no
  holes." For ordered data, "like the chunks of an object."
- **`gap: ok`** — "reports the gap and keeps going." For metrics-shaped data where a hole is
  acceptable.

Client support, as tabulated: CLI `nats bench js pub fast` (**benchmark only**); Go
`jetstreamext.NewFastPublisher` and Rust `fast_publish` via Orbit; nats.js
`@synadiaorbit/fastingest` (`startFastIngest`); Python, Java and .NET have the stream flag with
"Orbit publishers catching up". "Because there's no stable public publisher in most clients, this
page doesn't show per-language code for it."

### The incompatibility

> "**`AllowAtomicPublish` and async persistence don't mix.** A stream set to persist asynchronously
> (`PersistMode: async`) rejects atomic publishing, because the atomicity depends on the synchronous
> write path. Fast-ingest batches are fine on such a stream."

## Practical takeaways

- The default is one publish at a time with the ack checked. Everything on this page is an opt-in
  with a cost.
- **A ten-second stall silently abandons an atomic batch** — no error `PubAck`, only an advisory. The
  committing `PubAck` is the only proof.
- `persist_mode: async` and `allow_atomic` are mutually exclusive: a stream tuned for write latency
  cannot also publish atomically.
- Fast ingest in `gap: ok` mode loses data by design.

## Relevance to the wiki

The wiki knew `allow_atomic` (2.12) and `allow_batched` (2.14) as stream flags from the release notes
and the config table; nothing described what they do, what they cost, or how a publisher drives them.
This is the source for the batch half of [[publishing]].

## Questions it answers

Contributes to **Q23** (the atomicity a batch does and does not give) and **Q24** (the async order
trap, and `Nats-Expected-Last-Subject-Sequence` as the ordering guard).

## Pages touched

[[publishing]] · [[stream]] · [[defaults-and-limits]] · [[error-codes]] · [[advisories]] ·
[[nats-server-2.12]] · [[nats-server-2.14]] · [[orbit]]

## Sources

The doc page, which points at
[ADR-50](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-50.md) for the
full header set and limits. ADR-50 has **not** been read; every limit above is the doc page's own
statement and is marked as such on [[publishing]].
