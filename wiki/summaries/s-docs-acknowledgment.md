---
title: "docs.nats.io — Ack responses and redelivery"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/learn/jetstream/acknowledgment.md
source-path: raw/nats-docs/learn/jetstream/acknowledgment.md
author: NATS documentation (Synadia Communications, Inc.)
article: Ack responses and redelivery
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [ack, nak, term, backoff, max_deliver, advisories]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Ack responses and redelivery

The four answers a client can give to a delivered message, and the two server-side controls that
decide when a message comes back and when it stops.

## Key claims

- A client answers a delivered message in exactly **one of four ways**:
  - **ack** — the work succeeded; the server clears the pending entry and never delivers it again.
  - **nak** — negative acknowledgment; redeliver. A plain nak asks for redelivery *immediately*,
    or after a delay the client attaches.
  - **term** — give up; this message can never be handled, so never deliver it again. Clears the
    pending entry and moves the acknowledgment floor exactly as an ack does, but records that the
    work never happened.
  - **in-progress** — not a final answer; it **resets the AckWait timer** so a long job does not
    trip redelivery.
- **AckWait** is the redelivery timer. **Default 30 seconds.**
- **MaxDeliver** caps delivery attempts. **Default `-1`, meaning no limit** — a message can be
  redelivered forever.
- A **delayed nak is a client-library call**. The CLI's `--nak` only asks for immediate
  redelivery. To space out redeliveries from the CLI, set a consumer backoff instead.
- **A nak returns the message to the consumer, not to the worker that nak'd it.** With a worker
  pool sharing one consumer, the redelivery can land on a different worker.
- **Backoff** is a list of delays, one per attempt, that grows the wait between redeliveries.
  It only shapes redeliveries that fire when the **AckWait timer runs out** — it does **not**
  slow a nak. If the list has fewer entries than MaxDeliver allows, the server reuses the last
  entry for the remaining attempts.
- **Setting a backoff replaces AckWait**: the first entry in the list becomes the wait before the
  first redelivery, and therefore the ack deadline for the first delivery too. A
  `--backoff-min=1s` drops the effective AckWait to 1 second, overriding any `--wait` set earlier.
- **After a term**, the message is gone from *this consumer* but stays in the stream under the
  default `limits` retention — other consumers still see it and it ages out with the stream's
  limits. On a `workqueue` or `interest` stream, a term removes it just as an ack would.
- **JetStream has no built-in dead-letter queue.** When a message hits MaxDeliver the server drops
  it from the consumer's pending list and says nothing in the consumer's normal output.
- The server raises an advisory for each of these:
  - nak: `$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED.<stream>.<consumer>`
  - term: `$JS.EVENT.ADVISORY.CONSUMER.MSG_TERMINATED.<stream>.<consumer>` — carries the stream
    and consumer sequence, the delivery count, and an optional reason attached to the term
  - delivery-limit drop: `$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.<stream>.<consumer>`
- **Ack policies** are four: `explicit` (each message answered on its own), `none` (the server
  treats a message as done the moment it is delivered — no pending list, no Ack Wait, no
  redelivery), `all` (one ack retires every earlier message too) and `flow_control` (used by the
  push consumers the server creates for durable mirrors and sources; acks ride the flow-control
  responses and behave like `all`).
- **`all` on a consumer with MaxAckPending > 1 is silent data loss**: acking message 10 also
  retires a message 7 that failed and was waiting to come back.

## Practical takeaways

- A bare nak on a transient failure retries in the same instant, fails again, and pins one worker
  on one message. Nak *with a delay*; a consumer backoff will not help, because backoff only
  spaces out AckWait timeouts.
- A poison message with no term path burns every one of its MaxDeliver attempts and holds up the
  messages behind it.
- Subscribe to the max-deliveries advisory to catch drops; there is no other signal.
- If AckWait is shorter than real processing time and the worker does not send in-progress, two
  workers end up running the same job.

## Commands the page uses

```
nats consumer edit ORDERS shipping --ack=explicit --wait=10s --max-deliver=5
nats consumer edit ORDERS shipping --backoff=linear --backoff-steps=5 --backoff-min=1s --backoff-max=30s
nats consumer next ORDERS shipping --term
nats consumer info ORDERS shipping
nats sub '$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping'
nats events --js-advisory --no-srv-advisory
```

`nats consumer info` prints the controls as:

```
Configuration:
           Ack Policy: Explicit
             Ack Wait: 10.00s
        Replay Policy: Instant
   Maximum Deliveries: 5
      Max Ack Pending: 1,000
```

## Relevance to the wiki

Together with [[s-docs-delivery-and-acknowledgment]] this is the source for
[[ack-and-redelivery]]. It supplies the four responses, the AckWait and MaxDeliver defaults, the
backoff-does-not-affect-nak rule, and the three advisory subjects an operator needs to see
redeliveries and drops at all.

## Questions it answers

Q17 (exponential backoff). Partially, and not enough to fill the bank's `answered by` cell:
Q18 (this page states the opposite of the question's premise — a plain nak *does* redeliver
immediately — so the thread behind Q18 needs reading before the wiki claims an answer), Q19
(it says a nak returns the message to the consumer, but not whether the delayed nak holds a
`max_ack_pending` slot), Q59 (it names three consumer advisories but no metrics).

## Pages touched

[[ack-and-redelivery]] · [[consumer]] · [[retention-policies]]
