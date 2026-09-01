---
title: "gh#4994 — AckWait does not publish to dead letter queue with zero clients"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/4994
source-path: raw/gh-discussions/gh-4994.md
author: "@gongy (asked); @derekcollison (answer, marked)"
article: "GitHub Discussion 4994 (Q&A)"
date: 2024-01-24
version: ""
tags: [dead-letter, max_deliver, ack_wait, scale-to-zero, advisories, pull-consumer]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# gh#4994 — there is no automated DLQ, and with nobody fetching there is no redelivery either

Two findings in one short thread, both from a maintainer, and the second is the more surprising:
**JetStream has no automated dead-letter queue by design**, and **`ack_wait` expiring does not by
itself advance a pull consumer's delivery count when no client is fetching**.

## Key claims

**The design answer** (@derekcollison, marked): "We do not have automated DLQs, as you noted **by
design since we truly separate consumers from stream semantics**. … For DLQ, you could **term** a
message and have something that captures that advisory and moves the message to whichever stream you
want."

That is the pattern, stated by a maintainer two and a half years before a Synadia post spelled it out
in code ([[s-synadia-reliable-delivery-dlq]]): capture the advisory, fetch the message, move it.

**The scale-to-zero trap**, which is the asker's actual problem and is confirmed as intended:

> "if `AckWait` expires with no clients fetching from the pull consumer, the message does not move to
> the dead letter queue (`MaxDeliver=1`). We have also reproduced this effect, and understand it is by
> design."

> "There appears to be **no way to configure JetStream to eagerly move messages from pending to the
> dead letter queue upon `AckWait` timeout, without clients issuing fetches.** The behavior of a push
> consumer + queue group setup appears to exhibit the same effect — if there are no subscribers in the
> queue group, messages remain in `AckPending` after the `AckWait`."

They tried to work around it with "dummy fetch requests to the pull consumer, to activate the message
redirection" and "did not find a way to trigger this manually."

The asker cites `nats-io/nats-server` issue #1716 as where the behaviour was established.

**A second, unrelated suggestion** in the same answer, worth keeping: "you can run one large mux'd
stream and have consumer pull only the subject they need, most likely bound to the type of event" —
the same advice against stream-per-thing that [[jetstream-slows-as-consumers-grow]] gives.

## Practical takeaways

- **A dead-letter design that depends on `max_deliver` firing depends on someone fetching.** Scale a
  worker pool to zero and messages sit in `AckPending`; nothing is dead-lettered, nothing is
  advised, and the queue looks healthy. This is the failure mode to design around, not a bug.
- **Term is the deliberate path to a dead letter.** A handler that knows the message can never
  succeed should term it rather than burn deliveries — the term advisory is immediate and does not
  wait for a timer or a fetch ([[ack-and-redelivery]]).
- **"No automated DLQ" is a consequence of the architecture**, not an omission: consumers are
  separate from stream semantics, so nothing at the consumer layer is allowed to move a message
  between streams on its own.

## Relevance to the wiki

The maintainer statement licensing [[dead-letter-queue]], and the source of its hardest constraint.
It also answers the question-bank row about dead-lettering with the design reason attached rather than
just a recipe.

## Questions it answers

Rows 106 and 107.

## Pages touched

[[dead-letter-queue]] · [[ack-and-redelivery]] · [[consumer]] · [[advisories]]
