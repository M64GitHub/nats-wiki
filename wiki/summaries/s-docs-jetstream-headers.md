---
title: "Reference — JetStream API headers"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/reference/jetstream/api/headers.md
source-path: raw/nats-docs/reference/jetstream/api/headers.md
author: "docs.nats.io (Synadia)"
article: "reference/jetstream/api/headers"
date: 2026-08-31          # fetch date; the page carries no date of its own
version: "2.14"           # the docs tree this was fetched from
tags: [headers, Nats-Msg-Id, Nats-Rollup, Nats-Schedule, Nats-Batch, Nats-TTL]
aliases: [JetStream headers]
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# Reference — the JetStream header space

The docs' one table of every JetStream header, grouped by what it is for: deduplication, expected
state, rollup, size, batching, **scheduling**, and the headers the server adds on delivery. It is the
only place in the docs tree that mentions message scheduling at all — as a table with no prose.

## Key claims

- **Deduplication and expected state**: `Nats-Msg-Id`, `Nats-Expected-Last-Msg-Id`,
  `Nats-Expected-Stream`, `Nats-Expected-Last-Sequence`, `Nats-Expected-Last-Subject-Sequence` and
  `Nats-Expected-Last-Subject-Sequence-Subject` — the last of which "specifies the subject for the
  expected last subject sequence check", so the check can be made against a subject other than the
  one being published to.
- **Rollup**: `Nats-Rollup` takes `sub` or `all` — "`sub` replaces all previous messages on the same
  subject, `all` replaces all messages in the stream".
- **Atomic batching**: `Nats-Batch-Id`, `Nats-Batch-Sequence`, `Nats-Batch-Commit` (`1` "marks the
  final message in a batch, triggering atomic commit").
- **Scheduling**: `Nats-Schedule`, `Nats-Schedule-Time-Zone`, `Nats-Schedule-TTL`,
  `Nats-Schedule-Target`, `Nats-Schedule-Source`, `Nats-Scheduler`, `Nats-Schedule-Next` — with a
  worked example:

  ```
  Nats-Schedule: 0 */5 * * * *
  Nats-Schedule-TTL: 24h
  Nats-Schedule-Target: notifications.email
  ```

  The example is **six fields, seconds first**, which is correct and is the only place in the docs
  that shows it.
- **The page's own rules**: "Headers are case-sensitive"; "Some headers are set automatically by the
  server and should not be manually set by clients" — without saying which.

## Where it is wrong or thin, checked against the server

All four were run on v2.14.6 ([[s-nats-server-message-schedules-observed]]) and are
`inbox/docs-issues.md` **#41**.

- **`Nats-Scheduler` — "Scheduler ID / Identifier for the scheduler".** It is **the subject that holds
  the schedule**, and it must be a valid publish subject different from the one being published to,
  or the server returns `10212`. A reader who treats it as an opaque id cannot use it.
- **`Nats-Schedule-TTL` — "Time-to-live for the schedule".** It sets the TTL on the **generated
  message** (observed as `Nats-TTL: 5m` on the target message). The schedule's own lifetime is set by
  a `Nats-TTL` header on the schedule message — a different header with the opposite meaning.
- **`Nats-Schedule` — value "Cron expression".** It also accepts `@at <RFC3339>`, `@every <duration>`
  and the `@hourly` family; `@at` is the *only* form 2.12 supported.
- **`Nats-Schedule-Time-Zone` and `Nats-Schedule-Rollup` have empty descriptions**, and
  `Nats-Schedule-Rollup` is filed under *Message Rollup* rather than *Scheduled Messages*, typed
  "String" where the only valid value is `sub`.

The section also never mentions that **the stream must set `allow_msg_schedules`** for any of these
headers to do anything — the server answers `10188 message schedules is disabled` otherwise.

## Relevance to the wiki

The header table behind [[message-scheduling]] and part of [[publishing]]. Its scheduling rows are the
docs' *entire* coverage of the feature, which is why the wiki writes the page from ADR-51 and the
binary instead.

## Questions it answers

Row 29, partially — it lists the headers but not what they mean.

## Pages touched

[[message-scheduling]] · [[publishing]] · [[message-ttl]] · [[js-api-subjects]] · [[stream]]
