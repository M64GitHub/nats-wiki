---
title: "Synadia — JetStream expected sequence headers"
type: summary
area: [jetstream]
source-url: https://www.synadia.com/blog/understanding-jetstream-expected-sequence-headers
source-path: raw/synadia-blog/understanding-jetstream-expected-sequence-headers.txt
author: "Peter Humulock (Synadia)"
date: 2026-01-20
version: "names NATS 2.12 for atomic batch publishing; no minimum version for the headers"
article: "Synadia blog post, ~1,330 words"
tags: [optimistic-concurrency, Nats-Expected-Last-Sequence, Nats-Expected-Last-Subject-Sequence, Nats-Expected-Last-Subject-Sequence-Subject, wrong-last-sequence, 10071, 10164, 10193, event-sourcing, atomic-batch]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# JetStream Expected Sequence Headers: Optimistic Concurrency Without Locks

The post that names the **third** expectation header, which no page of this wiki mentioned. Read for
question-bank rows 144 and 112.

## Key claims

**One counter, three filters.** "There is only one sequence counter per stream… The three header types
don't create separate counters — **they filter what they check against**: the whole stream, a single
subject, or a wildcard pattern." And: "Expected values are stream sequences: you're always checking
against actual stream sequence numbers, not independent per-subject counters."

| approach | header(s) | tracks | when |
|---|---|---|---|
| global | `NATS-Expected-Last-Sequence` | the stream's last sequence, whatever the subject | one writer, strict order across everything |
| per subject | `NATS-Expected-Last-Subject-Sequence` | the last sequence **for that exact subject** | one subject per entity, concurrent entities |
| per pattern | `NATS-Expected-Last-Subject-Sequence` **plus** `NATS-Expected-Last-Subject-Sequence-Subject` | the last sequence matching a wildcard | one entity across several subjects — "perfect for event sourcing" |

**The mistake it names**: "Assuming `events.order.1.created` and `events.order.1.shipped` share
sequence tracking. They don't — they're completely separate subjects with independent tracking." The
per-pattern form exists to make them share one, with `events.order.1.*` as the pattern.

**The worked sequences matter more than the prose.** Per subject: publishes to `events.order.1`,
`events.order.2`, `events.order.1`, `events.order.2` expect **0, 0, 1, 2** — "the expected values jump
… because we're tracking different subjects. The expected value is still a stream sequence number."

**Failure**: "Writer B also tries to publish with expected sequence 0 → fails with **'wrong last
sequence: 1'**. The error message tells you the current sequence so you can retry with the correct
value."

**Client API** (nats.go `jetstream`): `WithExpectLastSequence(0)`, `WithExpectLastSequencePerSubject(0)`,
`WithExpectLastSequenceForSubject(1, "events.order.1.*")`.

**Framing**: "Optimistic concurrency is about **detection**… These headers don't prevent conflicts —
they detect them. Your application handles retries." And they pair with 2.12's atomic batch publishing:
`NATS-Expected-Last-Sequence` on the first message of a batch.

## Verified against nats-server v2.14.6

- **All five publish-expectation headers exist**, `server/stream.go:640–644`: `Nats-Expected-Stream`,
  `Nats-Expected-Last-Sequence`, `Nats-Expected-Last-Subject-Sequence`,
  `Nats-Expected-Last-Subject-Sequence-Subject`, `Nats-Expected-Last-Msg-Id`. The post covers three of
  the five and does not mention `Nats-Expected-Stream` or `Nats-Expected-Last-Msg-Id`.
- **The third header arrived in 2.11.0** — "Support for `Nats-Expected-Last-Subject-Sequence-Subject`
  header, customising the subject used when paired with `Nats-Expected-Last-Subject-Sequence` (#5281)"
  (`raw/release-notes/v2.11.0.md:58`); absent from the v2.10.29 source, present in v2.11.17. The post
  states no version, which matters: sending it to a 2.10 server is silently ignored rather than
  refused.
- **The per-subject check runs before the global one**, and the two report different numbers.
  `server/stream.go:6455–6500`: the per-subject branch does `store.LoadLastMsg(seqSubj)` — where
  `seqSubj` is the override subject when the third header is present — and on a mismatch answers
  `NewJSStreamWrongLastSequenceError(fseq)` with **that subject's** last sequence; the global branch
  answers `NewJSStreamWrongLastSequenceError(mlseq)` with **the stream's** `mset.lseq`. So "wrong last
  sequence: 1" means two different things depending on which header you sent, and the post's "the
  error message tells you the current sequence" is true only in the sense that it tells you the current
  sequence *of the thing you asked about*.
- **The error codes**, `server/jetstream_errors_generated.go:849–896` — this settles the open
  `## To verify` item on [[publishing]]:

  | code | HTTP | message | raised by |
  |---|---|---|---|
  | 10071 | 400 | `wrong last sequence: {seq}` | `Nats-Expected-Last-Sequence` or `Nats-Expected-Last-Subject-Sequence` mismatch |
  | 10164 | 400 | `wrong last sequence` | the constant form, no sequence in the message |
  | 10070 | 400 | `wrong last msg ID: {id}` | `Nats-Expected-Last-Msg-Id` mismatch |
  | 10060 | 400 | `expected stream does not match` | `Nats-Expected-Stream` mismatch |
  | 10193 | 400 | `missing sequence for expected last sequence per subject` | the third header sent **without** its companion |
  | 10163 | 503 | `expected last sequence per subject temporarily unavailable` | the per-subject check cannot be made right now |

- **10193 is a 2.12.0 change**: "An error will now be correctly surfaced when the
  `Nats-Expected-Last-Subject-Sequence-Subject` header is supplied but the accompanying
  `Nats-Expected-Last-Subject-Sequence` header is not (#7196)" (`raw/release-notes/v2.12.0.md:98`).
  Before 2.12.0 that combination failed quietly.

## Practical takeaways

- Use the per-pattern form when an aggregate's events span several subjects — that is the event-sourcing
  case, and without it `order.1.created` and `order.1.shipped` are independently ordered.
- Retry on `10071` by reading the sequence out of the error, but know which sequence you are being
  told; a per-subject failure does not tell you where the stream is.
- Sending the pattern header alone is a real failure mode with a version boundary: refused with `10193`
  since 2.12.0, ignored before it.

## Notable quotes

> "It's all one stream sequence, just filtered three different ways."

> "Optimistic concurrency is about detection… These headers don't prevent conflicts — they detect
> them."

## Relevance to the wiki

The OCC half of bank rows 144 and 112. It supplies the third header, and checking it against the source
supplies the six error codes and the version boundaries — closing an open `## To verify` item on
[[publishing]].

## Questions it answers

Row 112 in part; row 144 in part.

## Pages touched

[[publishing]] · [[error-codes]] · [[stream-and-consumer-config]]
