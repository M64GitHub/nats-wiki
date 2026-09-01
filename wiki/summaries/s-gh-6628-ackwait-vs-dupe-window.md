---
title: "gh#6628 — ack-wait and dupe-window behavior when used together"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/6628
source-path: raw/gh-discussions/gh-6628.md
author: "@s4iko (asked); @MauriceVanVeen (answered); @zakk616 (later comment)"
article: "GitHub Discussion 6628 (Q&A)"
date: 2025-03-10          # opened and answered the same day; no answer formally chosen
version: ""               # no server version stated; the asker runs the Helm chart on Kubernetes
tags: [ack_wait, duplicate_window, redelivery, pull-batch, max_ack_pending, quarkus]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# gh#6628 — `ack_wait` and the duplicate window are unrelated

An operator with `ack_wait: 8m` and `duplicate_window: 10m` kept seeing redeliveries and expected the
longer window to suppress them: *"if a message is redelivered every 8m and the duplication window is
10m the message should never be processed twice."* A maintainer separates the two settings, and the
thread then turns up the asker's real cause — a **pull batch of 100**. Opened and answered
2025-03-10; no answer was formally marked, and a third party added a different theory eleven months
later.

## Key claims

- **The two settings are not related to each other** (@MauriceVanVeen): "AckWait and DupeWindow are
  two different settings that are not related to each other."
  - `duplicate_window` is a **stream** setting: it "ensures a message with the same identifier can't
    be published into the stream again within the dupe window". It bounds re-**publication** of the
    same `Nats-Msg-Id`.
  - `ack_wait` is a **consumer** setting: it "manages redeliveries of a message if it's sent to your
    client but it was not acknowledged within the configured wait time". It bounds re-**delivery** of
    a message already stored.
- **The defaults, stated in the same breath**: "the DupeWindow and AckWait to their defaults, 2
  minutes and 30 seconds respectively" — matching `StreamDefaultDuplicatesWindow` and the consumer
  `ack_wait` default this wiki reads at v2.14.6 ([[s-nats-server-constants-2.14.6]]).
- **To be delivered only once, bound the deliveries, not the window**: "you could set the MaxDeliver
  value to 1, or always Ack or Term the message once you get it."
- **The cause was a pull batch of 100.** The asker fetched batches of 100 and acked each message only
  after a downstream publish was acked. Switching to one message at a time — "explicitly fetch 1
  message, process it, send an outgoing message, wait for its ack, then ack the original message" —
  stopped the redeliveries: *"I removed this parameter and there were no more message were
  redelivered."*
- **The consumer state at the time showed nothing wrong**: `Ack Wait: 8m0s`, `Max Ack Pending:
  10,000`, `Outstanding Acks: 0`, `Redelivered Messages: 0`, `Waiting Pulls: 4 of maximum 512`. The
  evidence of the problem was in the application, not in `nats consumer info` — which is why the
  thread ran on for a day.

## Practical takeaways

- **A redelivery is not a duplicate publish, and no stream setting suppresses it.** The dedup window
  only ever compares `Nats-Msg-Id` on *publish*; the consumer's redelivery loop never consults it.
  Raising `duplicate_window` to cover `ack_wait` does nothing at all.
- **A batch fetch starts the `ack_wait` clock on every message in the batch**, not on the one being
  worked. Fetch 100 with `ack_wait: 8m` and a per-message cost of 6 seconds and the tail of the batch
  is already past its deadline when the worker reaches it. This is the same arithmetic
  [[consumer]] states as "`max_ack_pending` below the batch size caps throughput", seen from the
  other end: **the batch size must fit inside `ack_wait × workers`**, or the batch redelivers itself.
- **Two plausible-sounding causes were both wrong**: the window (the asker's) and slow processing
  (@zakk616's, added 2026-02-19 — "to me it looks the service took more than this duration"). The
  actual answer was batch size, and the diagnosis came from describing the fetch loop, not from
  server output.

## Notable quotes

> "AckWait and DupeWindow are two different settings that are not related to each other."
> — @MauriceVanVeen, 2025-03-10

> "The problem was due to the use of a batch-size of 100. I removed this parameter and there were no
> more message were redelivered." — @s4iko, 2025-03-11

## Relevance to the wiki

Question-bank row 16 is this thread. It is also the cleanest public statement of a confusion this
wiki should refuse to let stand: [[publishing]] owns the duplicate window and [[ack-and-redelivery]]
owns redelivery, and neither previously said the other one is not involved.

## Questions it answers

Row 16 — how `ack_wait` and the duplicate window interact: they do not.

## Pages touched

[[ack-and-redelivery]] · [[publishing]] · [[consumer]]
