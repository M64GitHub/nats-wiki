---
title: "Reliable Message Delivery in NATS JetStream: Acks, Retries, Dead Letters, and Replay"
type: summary
area: [jetstream, monitoring]
source-url: https://www.synadia.com/blog/jetstream-reliable-delivery-dlq-replay
source-path: raw/synadia-blog/jetstream-reliable-delivery-dlq-replay.txt
author: "Andrew Connolly (Synadia)"
article: "Synadia engineering blog post"
date: 2026-07-24
version: ""              # no nats-server version stated anywhere in the post
tags: [ack, nak, backoff, max_deliver, dead-letter, dlq, advisories, replay, retention]
aliases: [dead letter queue, DLQ]
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# Synadia — reliable delivery, dead letters and replay

The applied layer over [[ack-and-redelivery]]: the six failure scenarios and the primitive that
answers each, the three consumer verbs, and a **dead-letter queue assembled from advisories** in
about thirty lines of Go. It states no `nats-server` version anywhere.

**Two of its claims are wrong at v2.14.6 and are recorded as `inbox/docs-issues.md` #39** — see
*Where it is wrong*, below. It is cited on the wiki for the parts that hold.

## Key claims

- **NATS has no dead-letter queue, deliberately.** "There is no `dead_letter: true` field on a
  consumer. What NATS has instead is the set of primitives you assemble one from, and the DLQ you
  build is an ordinary JetStream stream with all the retention, filtering, and replay that implies,
  which beats a special-case holding pen."
- **The DLQ pattern is three parts**: capture `$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.>` into a
  stream of its own ("the index of everything that exhausted its redelivery budget"); read the source
  stream and sequence out of each advisory and **direct-get the original message** by sequence;
  republish it to `dlq.<stream>.<consumer>`, captured by a second stream. "Failed messages land on
  `dlq.<stream>.<consumer>`, subject-partitioned so you can inspect or replay a single failing
  consumer's backlog without touching the rest."
- **The handler is itself an ordinary consumer**: "if it cannot reach the source stream, it Naks and
  tries the advisory again later; if the advisory is malformed, it Terms."
- **Advisories are transient.** "If nobody is subscribed when one fires, it is gone" — which is why
  the pattern starts with a stream over the advisory subject rather than a subscriber.
- **Retention decides whether the original is still there to fetch**, and this is the post's sharpest
  operational point. On `limits` retention the payload survives independently of acks — "the
  friendliest case". On `workqueue` and `interest`, "the window in which the original payload is
  available for a direct get is bounded by consumer behavior": exhausting `max_deliver` is what fires
  the advisory, so the handler is racing the removal. **The general rule the post gives**: "on any
  retention policy that removes messages once they are terminally handled, capture the payload while
  it still exists" — copying it into the DLQ stream at capture time is what makes it durable.
- **Size `max_deliver` against the length of the backoff schedule.** "A MaxDeliver of 5 with a
  four-entry backoff gives four spaced retries after the initial delivery; the fifth attempt is the
  last before the message is bounded out."
- **The last backoff interval repeats**: "once the schedule is exhausted, the last interval repeats
  until the delivery bound is reached." Confirmed at `consumer.go:6060–6063`, v2.14.6.
- **Replay is the same read primitive aimed backwards**: `DeliverPolicy` (all / last / new / by start
  sequence / by start time) chooses where, `ReplayPolicy` chooses the pacing — `instant`, or
  `original`, which "reproduces the timing of the original stream… useful for realistic load
  reproduction."
- Three advisories are named for the failure path: `MAX_DELIVERIES`, `MSG_TERMINATED` and
  `MSG_NAKED` — the last in the **correct** `MSG_NAKED` spelling, which the docs' own reference page
  gets wrong ([[advisories]], docs issue #1).

## Where it is wrong

Both were run on the v2.14.6 binary ([[s-nats-server-nak-backoff-observed]]) and are docs issue #39.

- **"How do I retry a failed message with a backoff? Negatively acknowledge it."** A **bare** nak is
  precisely the case a consumer `backoff` does *not* shape: three bare naks on a consumer with
  `backoff` `[5s, 10s, 15s]` were redelivered after **0.00 s** each. The schedule applies to
  redeliveries that fire when `ack_wait` expires — and, through a server-side accident
  (`inbox/server-issues.md` SI-2), to a nak that *carries* a delay.
- **The consumer snippet sets `AckWait: 30 * time.Second` beside `BackOff: [1s, 5s, 30s, 2m]`.** The
  server overwrites `ack_wait` with the first backoff entry, so that config stores **`ack_wait: 1s`**
  — verified by sending it straight to `$JS.API.CONSUMER.CREATE`. A reader who copies it gets a
  one-second ack deadline and duplicate processing of every handler slower than that.

## Practical takeaways

- **Build the DLQ over a `limits` source stream if you can.** On `workqueue` or `interest` the
  direct-get is a race the post tells you to expect but cannot remove.
- **Capture the payload, not the reference.** The advisory is an index entry; the message it points
  at may be gone by the time anyone looks.
- **The pattern needs no server feature that does not exist** — an advisory subject, a stream, direct
  get, and a republish.

## Notable quotes

> "NATS traded a one-line config field for a dead-letter mechanism that is first-class
> infrastructure."

> "advisories are transient messages. If nobody is subscribed when one fires, it is gone."

## Relevance to the wiki

The source of the nak/backoff contradiction this wiki settled on the binary, and the only public
description of a NATS dead-letter pattern read so far. Whether the wiki gets a
`dead-letter-queue` page depends on `inbox/question-bank.md` having a real public question for it —
`CLAUDE.md`'s scope test, applied in step 4 of `inbox/plan-delivery-timing-2026-09-01.md`.

## Questions it answers

Row 17 partially (and wrongly, for the bare-nak case). Its DLQ material answers no bank row yet.

## Pages touched

[[ack-and-redelivery]] · [[advisories]] · [[retention-policies]] · [[direct-get]] · [[consumer]]
