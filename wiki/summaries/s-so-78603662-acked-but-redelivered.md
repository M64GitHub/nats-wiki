---
title: "Stack Overflow #78603662 — JetStream messages processed multiple times by my consumer even when acknowledged"
type: summary
area: [jetstream, clients]
source-url: https://stackoverflow.com/questions/78603662/nats-jetstream-messages-being-processed-multiple-times-by-my-consumer-even-when
source-path: raw/stackoverflow/so-78603662.md
author: "Kunal (asked); Ben Basil (the one answer, not accepted)"
article: "Stack Overflow question 78603662, tags c#, .net, nats.io, nats-jetstream"
date: 2024-06-10          # asked; the answer is from 2024-07-11
version: ""               # no server version stated; NATS.Net on .NET 8
tags: [redelivery, ack, backoff, ack_wait, max_deliver, nanoseconds, dotnet, unanswered]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# Stack Overflow #78603662 — "processed twice despite `AckAsync`": a ten-microsecond deadline

Question-bank row 14's own thread — mined by its title on 2026-08-31, read in full on 2026-09-03.
Score 4, 1,217 views, one answer that was never accepted, and **nobody named the cause**. The cause
is one number in the wrong unit, and it reproduces on 2.14.6 to the letter.

## What the question shows

A .NET 8 program with NATS.Net publishes ten messages to `test.new.first` on stream `sample-new`
(subjects `test.new.*`), then creates consumer `first-new-consumer` with:

```
DeliverPolicy = All
MaxDeliver    = 2
Backoff       = new List<long> { 10000 }
```

and consumes with `ConsumeAsync`, calling `msg.AckAsync()` on every message. "My consumer processes
each message twice, despite calling `msg.AckAsync()`." Raising `MaxDeliver` raises the number of
times; leaving it unset gives once. The poster's expectation: "If a record is not acknowledged only
then that record should get processed again."

**The one answer** (2024-07-11, score 1, not accepted): "Try creating a durable consumer by adding a
field called durable and a name for it." It does not touch the ack deadline; the poster never replied.

## What the wiki adds — the diagnosis

- **`backoff` is a list of durations, and on the JetStream API a duration is a signed 64-bit integer
  of nanoseconds.** Sent as the number `10000`, the entry is **ten microseconds**. Created through the
  raw API with the poster's numbers on 2.14.6, the server stores `ack_wait: 10000` and the CLI prints
  **`Ack Wait: 10µs`** (source: [[s-nats-server-redelivery-observed]], run H.1).
- **The first backoff entry *is* the ack deadline.** `config.AckWait = config.BackOff[0]`,
  `consumer.go:658` at v2.14.6, under *"If BackOff was specified that will override the AckWait and
  the MaxDeliver"* (source: [[s-nats-server-nak-backoff-observed]]). The poster set no `AckWait`; the
  backoff set one anyway.
- **What a 10 µs deadline does to an acking client** (source: [[s-nats-server-redelivery-observed]],
  run H.3, a pull of 100 kept open the way a consume loop keeps one, the handler taking 5 ms before
  acking): with `max_deliver: 2` **every message is delivered exactly twice**, every delivery acked;
  with `max_deliver` unlimited the same ten messages come back **ten times each** until the pull's
  batch is used up; with a real `ack_wait` of 30 s, once. Acked the instant they arrive on localhost,
  the ack usually beats the timer (six pulls of seven delivered once; the seventh redelivered ninety
  times in six milliseconds) — so the symptom depends on how long the handler takes and how far the
  server is, which is why it looks intermittent.
- **"Processed twice" and "more times with a higher `MaxDeliver`" are the deadline plus the cap.**
  The message's second delivery goes out before the first delivery's ack has landed; the ack then
  clears it (`processAckMsgLocked` clears the pending entry whichever delivery the ack names,
  `consumer.go:3717–3731`), and the delivery count is already 2. "Without `MaxDeliver`, once" is
  **not** what 2.14.6 does — unlimited deliveries redeliver *more* — so that part is either the ack
  winning the race on the poster's machine or something the client did differently; the wiki does
  not know.
- **Whether NATS.Net passed `10000` through unchanged** is inferred from the symptom matching run
  H.3, not observed: the raw run sends the number straight to the API, and the .NET model's unit at
  the poster's version is not in a source this wiki holds.

## Practical takeaways

- **A `backoff` in the wrong unit is an ack deadline of nothing.** When the client's `Backoff` field
  takes plain integers, the number goes to the server as nanoseconds; when it takes `TimeSpan`,
  `time.Duration` or a `Duration` type this cannot happen. Check the type before typing a number.
- **The tell is one line**: `nats consumer info` → `Ack Wait: 10µs`. Anything shorter than the
  handler's work is a redelivery generator, and `max_deliver` is then the number of times each
  message will be processed.
- **The advice given — a durable name — is unrelated.** A consumer's durability decides when the
  server forgets it, not when it redelivers.

## Relevance to the wiki

Row 14's title is the wiki's gotcha title, and its body is the commonest *mechanism* behind it: a
deadline the operator did not know they had set. It also gives [[nats-net]] its first *what bites
you* item from a public report.

## Questions it answers

Row 14 — the thread's own cause, plus the general rule for every client.

## Pages touched

[[consumer-keeps-redelivering]] · [[ack-and-redelivery]] · [[nats-net]] · [[consumer]]
