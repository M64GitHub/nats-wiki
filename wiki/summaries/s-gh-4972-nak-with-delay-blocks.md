---
title: "gh#4972 — Doesn't NakWithDelay reduce the MaxAckPending counter and block the execution of other messages?"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/4972
source-path: raw/gh-discussions/gh-4972.md
author: "@AlexandrTQ (asked); @ripienaar and @derekcollison (maintainers)"
article: "GitHub Discussion 4972 (Q&A)"
date: 2024-01-18          # opened and discussed the same day; no answer chosen
version: ""               # no server version stated; nats.go jetstream API, WorkQueue stream
tags: [nak, nakWithDelay, max_ack_pending, worker-pool, ordering, working-as-designed]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# gh#4972 — a delayed nak keeps its `max_ack_pending` slot for the whole delay

The sharpest public statement of a constraint that decides whether a retry design works: **a message
that has been delivered once and is waiting to come back is still *pending*, delay or no delay.** The
reporter set `MaxAckPending: 10`, nak'd ten messages with `NakWithDelay(time.Minute)`, and the
consumer stopped dead — 10 messages processed out of 100 published. Two maintainers answer the same
day; **no answer was marked**, and the thread ends with the two of them agreeing to reconsider the
design.

## Key claims

- **Working as designed, and the reason is ordering** (@ripienaar): "Any messages that was once
  delivered and had to be retried is pending, its an important constraint as max pending is used to
  manage ordering to name but one case. So this is working as designed, there's no alternative
  today."
- **The only lever is the cap itself** (@ripienaar): "The only real option today is to increase the
  maxackpending."
- **A maintainer thinks the behaviour is arguably wrong** (@derekcollison, same day): "It's
  reasonable to think that a message nak'd but with a delay should not count towards max ack pending.
  This would need to be a change in the server though. We should convert this to an issue as a
  feature request." The thread's last word is @derekcollison asking @ripienaar to reopen the design
  question: "I agree about ordering but with NAK that has already been violated to some degree based
  on the observer." **No issue number is given in the thread, and no fix version is named anywhere in
  it.**
- **Running more consume callbacks does not buy more slots.** The reporter's second idea was to drop
  `MaxAckPending` from the config and start ten `Consume` loops instead, expecting ten independent
  workers. @ripienaar's correction is the point: "With this case you would get a default value for
  MaxAckPending, in your initial code you set it to 10." The concurrency did not come from the ten
  loops; it came from the cap going back to its default of 1000. `max_ack_pending` is **one number per
  consumer**, whatever is pulling against it.
- **Spreading the loops across processes does not change that either.** @derekcollison: "This would
  only work if you ran only one copy of your app" — and when the reporter observes messages splitting
  84/16 across two app instances, the reply names what the reporter had actually given up: "I thought
  the intent was to still have essentially max ack pending, or inflight, be 10."

## Practical takeaways

- **A delayed nak is a *sleeping slot*, not a released one.** Retry capacity and concurrency come out
  of the same budget, so `max_ack_pending` must cover both the work in flight *and* everything
  sleeping in retry. At a nak rate of *R* per second and a delay of *D* seconds, roughly *R × D* slots
  are asleep at steady state before a single new message can be delivered (arithmetic from the
  constraint above, not a number any source states).
- **The failure mode is a silent, total stall**, not a slowdown: once every slot is held by a sleeping
  message, the consumer delivers nothing until the first delay expires — with `Outstanding Acks` at
  its maximum and every worker idle. That is the signature to look for in `nats consumer info`.
- **Long delays and small caps are incompatible.** A one-minute retry delay on a cap of 10 gives at
  most 10 retries per minute across the whole consumer. Either the cap grows to cover the sleeping
  set, or the delay does not belong on the nak — which is the argument for scheduling the retry as a
  new message instead ([[s-gh-7628-scheduler-vs-nak]]).
- **`WorkQueue` retention does not change any of this.** The reporter's stream was `WorkQueuePolicy`;
  the cap is a consumer property and behaves identically.

## Notable quotes

> "Any messages that was once delivered and had to be retried is pending, its an important constraint
> as max pending is used to manage ordering to name but one case. So this is working as designed,
> there's no alternative today." — @ripienaar, 2024-01-18

> "It's reasonable to think that a message nak'd but with a delay should not count towards max ack
> pending. This would need to be a change in the server though." — @derekcollison, 2024-01-18

## Relevance to the wiki

Question-bank row 19, answered by two maintainers with the reason attached. It also supplies the
*why* behind a rule [[worker-pool]] and [[ack-and-redelivery]] already state from the docs — that
`max_ack_pending` is shared across the whole consumer — and it is half of row 30's answer: the reason
a maintainer later recommends the message scheduler over `NakWithDelay` for scheduled work at scale.

**Age matters here.** The thread is from 2024-01-18 and both maintainers describe the behaviour as
current *"today"*, with a change discussed but not made. The wiki states it against **v2.14.6**
because it was re-run on that binary, not because this thread is recent
([[s-nats-server-nak-backoff-observed]]).

## Questions it answers

Row 19 — yes, for the whole delay; and part of row 30.

## Pages touched

[[ack-and-redelivery]] · [[worker-pool]] · [[jetstream-sizing]] · [[consumer]]
