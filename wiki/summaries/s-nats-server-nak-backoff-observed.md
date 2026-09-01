---
title: "Observed on nats-server v2.14.6 — what a nak actually waits"
type: summary
area: [jetstream]
source-path: raw/nats-server-src/nak-backoff-observed-v2.14.6.md
source-url: https://github.com/nats-io/nats-server/blob/v2.14.6/server/consumer.go
author: "run locally; server source by the nats-io authors"
article: "thirteen experiments on nats-server v2.14.6 with nats CLI 0.4.0, plus server/consumer.go at the tag"
date: 2026-09-01
version: "2.14.6"
tags: [nak, nakWithDelay, backoff, ack_wait, redelivery, max_ack_pending, observed]
aliases: [nak backoff, delayed nak timing]
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# Observed on v2.14.6 — what a nak actually waits

Run rather than read, because the claim is behavioural and three public sources disagree about it:
the docs say a consumer `backoff` does not slow a nak ([[s-docs-acknowledgment]]), a Synadia post
says it does ([[s-synadia-reliable-delivery-dlq]]), and an unanswered thread reports a nak that did
not redeliver at once ([[s-gh-5631-nak-not-immediate]]). **Both published answers are wrong**, and
the real rule is arithmetic neither of them states.

Thirteen experiments on the **v2.14.6** binary with **nats CLI 0.4.0**, 2026-09-01, plus the three
ranges of `server/consumer.go` at the tag that explain every number.

## Key claims

**1 · A bare `-NAK` redelivers immediately, backoff or no backoff.** Three bare naks on a consumer
with `backoff` `[5s, 10s, 15s]`: **0.00 s** every time. The docs are right about this case.

**2 · A nak carrying a delay is *not* redelivered after that delay** when the consumer has a backoff.
Asking for 2 s on successive attempts gave **2.000 · 7.000 · 12.000 · 12.001** seconds, measured from
the server's own `-DV` trace. Asking for **zero** delay gave **0.00 · 4.94 · 9.94**.

**3 · The rule.** With `dc` the redelivery count, capped at the last entry:

```
effective wait  =  requested delay  +  ( BackOff[dc] − BackOff[0] )
```

Predicted `2 · 7 · 12 · 12` for a 2 s delay against `[5s, 10s, 15s]`; observed `2.000 · 7.000 ·
12.000 · 12.001`. With **no** backoff the extra term is zero and the delay is exact — three 2 s naks
gave `1.95 · 1.95 · 1.95`.

**4 · Why**, from `server/consumer.go` at v2.14.6:

- `:658` — `config.AckWait = config.BackOff[0]`, under the comment *"If BackOff was specified that
  will override the AckWait and the MaxDeliver"*. In **pedantic** mode it is an error instead:
  `first backoff value has to equal batch AckWait`.
- `:3231` — `p.Timestamp = time.Now().Add(-o.cfg.AckWait).Add(d).UnixNano()`, under the comment
  *"now - ackWait is expired now, so offset from there"*.
- `:6066` — `deadline = int64(o.cfg.BackOff[dc])` in `checkPending`.

The comment at `:3231` is exact only when the deadline at `:6066` is also `AckWait` — that is, only
when there is no backoff.

**5 · `-NAK {}` is not a bare nak.** `processNak` branches on `len(nak) > len(AckNak)` — anything at
all after the four bytes `-NAK` — and an empty options object unmarshals to a zero delay. So a client
that always serialises its nak options takes the delayed path and picks up the backoff term; one that
omits them does not. Same API call, different timing.

**6 · The positive control matters.** With no answer at all, the same consumer redelivered after
**5.00 · 10.00 · 15.00** — the documented schedule, exactly. The backoff is not inert; claim 1 is a
real negative.

**7 · `AckWait` beside a `BackOff` is silently discarded** — and by the **server**, not the CLI. The
config was sent straight to `$JS.API.CONSUMER.CREATE`: requested `ack_wait: 30s` with
`backoff: [1s, 5s, 30s, 2m]`, stored **`ack_wait: 1s`**.

**8 · A delayed nak still holds its `max_ack_pending` slot at 2.14.6.** A consumer capped at **2**,
both messages nak'd with a 30-second delay: the next pull returned **`408 Request Timeout`** and no
message. This re-runs [[s-gh-4972-nak-with-delay-blocks]]'s 2024 finding on the current release,
where the thread's own maintainers had discussed changing it and named no version.

## Practical takeaways

- **Do not combine a consumer `backoff` with `nakWithDelay` and expect the delay you asked for.**
  Pick one mechanism per consumer: a backoff for `ack_wait` timeouts, or delayed naks with no backoff
  configured.
- **Never write `AckWait` and `BackOff` on the same consumer and believe the `AckWait`.** The first
  backoff entry *is* the ack deadline. A `--backoff-min` of 1 second means a one-second deadline for
  every handler.
- **`--backoff-steps=3 --backoff-min=5s --backoff-max=20s` produces `5s, 10s, 15s`** at nats CLI
  0.4.0 — the maximum is not one of the steps. Recorded as an observation; no source states what the
  generator should produce.
- **The CLI cannot send a delayed nak at all.** `nats consumer next` has `--ack`, `--nak` and
  `--term` and no delay flag, which is why these runs needed a purpose-written client
  (`raw/nats-server-src/nats-probe-client.py`).

## Notable quotes

> "// now - ackWait is expired now, so offset from there." — `server/consumer.go:3230`, v2.14.6

> "// If BackOff was specified that will override the AckWait and the MaxDeliver."
> — `server/consumer.go:653`, v2.14.6

## Relevance to the wiki

It settles the contradiction `inbox/plan-delivery-timing-2026-09-01.md` step 2 exists for, and it
produced three records: `inbox/docs-issues.md` **#38** (the docs' claim), **#39** (the blog's), and
`inbox/server-issues.md` **SI-2** (the behaviour, which has no authority above it). It also re-dates
question-bank row 19's answer from a 2024 thread to the current release.

**A harness bug is recorded in the transcript on purpose**: the first run gave every consumer no
filter subject on a `test.>` stream, so consumers shared each other's messages and the delivery
counts read `1, 1, 2`. Every table since carries the stream sequence beside the delivery count so a
contaminated row is visible.

## Questions it answers

Rows 17, 18 and 19.

## Pages touched

[[ack-and-redelivery]] · [[consumer]] · [[worker-pool]]
