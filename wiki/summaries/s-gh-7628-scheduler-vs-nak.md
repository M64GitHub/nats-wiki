---
title: "gh#7628 — Message Scheduler vs NAK-with-delay for scheduled notifications at scale"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/7628
source-path: raw/gh-discussions/gh-7628.md
author: "@jan-krueger (asked); @MauriceVanVeen (answer, marked)"
article: "GitHub Discussion 7628 (Q&A)"
date: 2025-12-09
version: "2.12"
tags: [message-scheduling, nak, nakWithDelay, scale, message-ttl]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# gh#7628 — use the scheduler, not `NakWithDelay`, and here is why it scales

A push-notification service asks the design question this wiki's whole delivery-timing topic reduces
to: **a message must arrive later — delay the redelivery, or schedule the publish?** Asked with real
numbers (100K+ pending schedules) and answered the same day by a maintainer, marked.

## Key claims

The asker lays out both options explicitly — Option A: `schedules.<notification-id>` with
`Nats-Schedule: @at <time>` and `Nats-Schedule-Target: notifications.live`; Option B: publish to the
target with an `X-Scheduled-At` header and have the consumer "call `NakWithDelay(remaining_time)`
until due" — and asks three questions: is the scheduler designed for this scale, any concerns with
100K+ pending schedules per stream, and would `NakWithDelay` be better.

@MauriceVanVeen's marked answer:

> "Would definitely recommend using the new 2.12 scheduling feature over NakWithDelay, since **Nak is
> not meant for that purpose** and only really works as a workaround because the 2.12 scheduling
> feature wasn't there before. It should support a very large amount of schedules since it's **built
> on top of the per-message TTL work** which similarly also supports a very large amount. But, it's
> always good to test for your use case 🙂"

Three things in one paragraph:

- **A recommendation**: the scheduler, not `NakWithDelay`.
- **A reason**: nak was never meant for scheduling; it was the only tool before 2.12.
- **A mechanism**: the scheduler is built on the **per-message TTL** implementation
  ([[message-ttl]]), which is why the scale answer is optimistic. **No number is given** — "a very
  large amount", plus "always good to test for your use case".

## Practical takeaways

- **This is the answer to "delay the redelivery or schedule the publish?"** — schedule the publish,
  whenever the delay is a property of the *work* rather than of a *failure*. A delayed nak is for
  retrying something that went wrong; it is not a timer.
- **The wiki's other half of this answer is measured, not quoted.** A delayed nak holds its
  `max_ack_pending` slot for the whole delay ([[s-gh-4972-nak-with-delay-blocks]], re-run on 2.14.6),
  so Option B's 100K pending notifications would need a cap of 100K — which is the concrete reason
  behind "nak is not meant for that purpose".
- **The scale claim is unverified here and everywhere.** No public source states a tested schedule
  count; the maintainer's own advice is to test. This wiki did not test it either
  ([[s-nats-server-message-schedules-observed]] names it under what was not tested).

## Relevance to the wiki

Question-bank row 30, answered directly by a maintainer, and the load-bearing link between
[[message-scheduling]] and [[message-ttl]] — the scheduler is not a new subsystem, it is the TTL
machinery pointed at a different job.

## Questions it answers

Row 30, and part of row 19.

## Pages touched

[[message-scheduling]] · [[ack-and-redelivery]] · [[message-ttl]] · [[worker-pool]]
