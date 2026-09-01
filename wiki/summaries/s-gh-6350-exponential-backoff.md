---
title: "gh#6350 — Does NATS support exponential backoff consumption retry?"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/6350
source-path: raw/gh-discussions/gh-6350.md
author: "@penghuazhou (asked); @jnmoyne (answer, marked)"
article: "GitHub Discussion 6350 (Q&A)"
date: 2025-01-10          # answer chosen 2025-01-10; opened 2025-01-09
version: ""               # no server version stated
tags: [backoff, nak, nakWithDelay, ack_wait, redelivery]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# gh#6350 — exponential backoff: two mechanisms, chosen by *who* decided the message failed

Four lines long, with a **marked answer from a maintainer**, and the whole value is the distinction
it draws. Asked 2025-01-09: *"If the consumption fails, I hope to exponentially retreat and retry the
consumption."* Answered and marked 2025-01-10.

## Key claims

@jnmoyne's answer splits retry by **who noticed the failure**:

- **Implicit failure — the client never answered.** "If you do not ack the message (before the
  consumer's AckWait timeout happens) then you can specify a series of backoff times in the
  consumer's configuration (see 'Backoff' in
  https://docs.nats.io/nats-concepts/jetstream/consumers#general)."
- **Explicit failure — the client said no.** "If you explicitly give up on processing the message
  using the 'nack' (negative ack) then you can specify the backoff period using `nakWithDelay`."

So the answer to "does JetStream support exponential backoff" is **yes, twice, and they are different
mechanisms**: consumer `backoff` is server-side configuration that shapes `ack_wait` timeouts; a
delayed nak is a per-message client call that carries its own delay.

## Practical takeaways

- **The two are not interchangeable, and neither covers the other's case.** A consumer `backoff` does
  nothing for a handler that catches an exception and naks; a `nakWithDelay` does nothing for a
  handler that hangs or a worker that dies. A retry policy that wants both needs both.
- **Only one of them is reachable from the CLI.** `backoff` is consumer configuration
  (`--backoff=linear --backoff-steps=N --backoff-min=… --backoff-max=…`); the delayed nak is a
  client-library call with no `nats` CLI equivalent ([[ack-and-redelivery]]).
- **"Exponential" is a shape you supply, not a mode you switch on.** `backoff` is a list of durations,
  one per attempt; the delay on a nak is whatever number the handler passes. Neither is an
  exponential-backoff *algorithm* with a multiplier — the CLI's own generator is `linear`.

## Notable quotes

> "If you do not ack the message (before the consumer's AckWait timeout happens) then you can specify
> a series of backoff times in the consumer's configuration… If you explicitly give up on processing
> the message using the 'nack' (negative ack) then you can specify the backoff period using
> `nakWithDelay`." — @jnmoyne, 2025-01-10 (marked as the answer)

## Relevance to the wiki

Question-bank row 17. It is the maintainer statement behind the sentence [[ack-and-redelivery]]
already carries — that a consumer backoff "only shapes redeliveries that fire when the `ack_wait`
timer runs out" — and it upgrades that from a docs claim to a docs claim a maintainer restates
independently. It is also the frame the wiki needs before the contradiction in
[[s-synadia-reliable-delivery-dlq]] can be argued about at all: two mechanisms, and the question is
whether the first one also applies to the second one's trigger.

## Questions it answers

Row 17 — yes, by two separate mechanisms.

## Pages touched

[[ack-and-redelivery]] · [[consumer]]
