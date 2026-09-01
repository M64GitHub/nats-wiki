---
title: "Delayed Message Scheduling in NATS JetStream"
type: summary
area: [jetstream]
source-url: https://www.synadia.com/blog/delayed-message-scheduling-nats-jetstream
source-path: raw/synadia-blog/delayed-message-scheduling-nats-jetstream.txt
author: "Peter Humulock (Synadia)"
article: "Synadia engineering blog post"
date: 2026-04-09
version: "2.12, 2.14"
tags: [message-scheduling, Nats-Schedule, cron, dst, gotchas]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# Synadia — delayed message scheduling

The applied reading of [[s-adr-51-message-scheduler]], and until this wiki's own page existed, the
only readable account of the feature outside the ADR. Its value is a **gotcha list**: four things the
spec states less plainly, and one rule the spec does not state at all.

## Key claims

**The framing.** "Before NATS 2.12, there was no native mechanism for delayed delivery. The common
workaround was `NakWithDelay` on a consumer… But `NakWithDelay` was designed for retry logic, not
scheduling. **It ties up consumer state, and it does not scale well** when you have thousands of
pending scheduled messages." The same judgement a maintainer gives in
[[s-gh-7628-scheduler-vs-nak]], and this wiki has measured the mechanism behind "ties up consumer
state" ([[ack-and-redelivery]]).

**Where NATS sits**: "Amazon SQS offers delay queues natively. RabbitMQ supports delayed delivery
through a plugin. **Kafka has no built-in per-message delay at all.**"

**The four `Nats-Schedule` formats, with the version each arrived in** — the clearest statement of the
2.12/2.14 boundary in any source:

| format | example | since |
|---|---|---|
| one-time timestamp | `@at 2026-04-08T14:00:00Z` | **2.12** |
| cron expression (6 fields) | `0 30 9 * * mon-fri` | **2.14** |
| fixed interval | `@every 5m` | **2.14** |
| predefined alias | `@hourly`, `@daily`, `@weekly` | **2.14** |

**Why six fields**: the format "extend[s] the standard five-field Unix cron (which dates back to 1975
at AT&T Bell Labs) with a seconds field for finer precision."

**Four use cases**, the last of which is the one that matters for this wiki's topic: deferred order
processing; periodic report generation with no external cron daemon; **sensor downsampling** with
`Nats-Schedule-Source` and `@every 5m`, with "no changes to the sensor application required"; and
**retry with backoff** — "instead of using `NakWithDelay` on a consumer, publish a retry message with
`@at <future_timestamp>` to a schedule subject."

## The gotchas, and how each stands up

Checked against ADR-51 and against the **v2.14.6** binary
([[s-nats-server-message-schedules-observed]]).

| the post's caveat | verdict |
|---|---|
| **past-dated schedules fire immediately**, "after a server restart, all past-due schedules also execute immediately" | **confirmed** — a 2009 timestamp landed on the target within two seconds. The post's advice differs from the ADR's, though: it says use `Nats-Schedule-TTL` "so consumers can detect and discard stale deliveries"; ADR-51 says put a **`Nats-TTL` on the schedule message** so it is removed before it can fire. The ADR's is the better advice — it prevents the delivery rather than labelling it |
| **cannot be disabled once enabled** | **confirmed** — `message schedules can not be disabled (10052)` |
| **no source or mirror streams** | **confirmed** — `10186` / `10187` |
| **version split**: `@at` in 2.12, cron/`@every`/sampling/time zones in 2.14 | **confirmed** ([[s-gh-7672-cron-schedules]]) |
| **DST can skip or duplicate a cron execution**; "sticking with UTC — the default — avoids this entirely" | **matches ADR-51**, and was **not tested here** — it needs a clock, not a config |
| **`AllowMsgTTL` is a separate flag**, not enabled by `AllowMsgSchedules` | **confirmed** — without it, `Nats-Schedule-TTL` fails with `10166 per-message TTL is disabled` |
| **target and schedule subjects must differ** — *a rule ADR-51 does not state* | **confirmed on the binary**: the server answers `10190 message schedules target is invalid` |

**One imprecision.** The post says `Nats-Schedule-Time-Zone` "only applies to cron expressions, not
`@at` timestamps". It is not ignored on a non-cron schedule — the publish is **rejected**, and with
`10189` (pattern invalid) rather than the time-zone code.

**What it leaves out**, and where this wiki gets it instead: the **tzdata requirement** on every server
evaluating named time zones (ADR-51 — a missing zone looks like a bad pattern); the way
`allow_msg_schedules` silently **enables rollups and clears `deny_purge`**; the whole **retention**
interaction, including that an `interest` stream will not store a schedule at all; and the atomic
**stop-a-schedule** protocol with its `10212`.

## Relevance to the wiki

The applied layer of [[message-scheduling]], and the source for the target-vs-schedule-subject rule
that the specification omits. It is also the only public source that puts the scheduler next to SQS,
RabbitMQ and Kafka, which is the comparison an architect arrives with.

## Questions it answers

Rows 29 and 30, as the readable version.

## Pages touched

[[message-scheduling]] · [[mirrors-and-sources]] · [[message-ttl]]
