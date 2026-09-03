---
title: "ADR-9 — JetStream Consumer Idle Heartbeats"
type: summary
area: [jetstream, clients]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-9.md
source-path: raw/adr/ADR-9.md
author: "@aricart"
article: ADR-9
date: 2021-05-12
version: ""               # predates 2.10; present at the wiki's floor
tags: [adr, idle_heartbeat, push-consumers, consumer-config]
aliases: [ADR-9]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# ADR-9 — JetStream Consumer Idle Heartbeats

Approved, 2021-05-12. The `idle_heartbeat` field of `ConsumerConfig`, in nanoseconds: "the server will
only notify after the specified interval has elapsed and no new messages have been delivered to the
consumer. Delivering a message to the consumer resets the interval."

## Key claims

- A heartbeat is an ordinary message on the consumer's delivery subject with status `100` and
  description `Idle Heartbeat`, carrying **`Nats-Last-Consumer`** (the last consumer sequence
  delivered; `0` if none) and **`Nats-Last-Stream`** (the newest stream sequence) — headers a client
  uses "to re-affirm that it has not lost any messages".
- Purpose: to let a client "detect when they have been disconnected", since "the consumer's
  subscription may sit idly waiting for messages, without knowing that the server might have simply
  gone away and recovered elsewhere".
- On 2.14.6 the field is **push-only** (a pull consumer's `idle_heartbeat` is refused with 10088)
  and cannot be updated (`heart beats can not be updated`); the pull equivalent is the
  `idle_heartbeat` of each `MSG.NEXT` request ([[s-nats-server-stream-consumer-config]],
  [[consumer]]).

## Practical takeaways

- Set it on push consumers and alarm on missed beats; on pull consumers put the interval in the
  request instead.

## Relevance to the wiki

The `idle_heartbeat` row of [[stream-and-consumer-config]].

## Questions it answers

Row 164 in part.

## Pages touched

[[stream-and-consumer-config]]
