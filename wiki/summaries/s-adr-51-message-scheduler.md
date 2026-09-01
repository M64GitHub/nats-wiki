---
title: "ADR-51 — JetStream Message Scheduler"
type: summary
area: [jetstream]
source-path: raw/adr/ADR-51.md
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-51.md
author: "@ripienaar, with revisions by @MauriceVanVeen"
article: "ADR-51 (Approved; 8 revisions, 2025-03-21 → 2026-05-27)"
date: 2026-05-27          # latest revision
version: "2.12, 2.14"     # tagged 2.12 and 2.14; revision 8's server version is still TBD
tags: [message-scheduling, allow_msg_schedules, Nats-Schedule, cron, message-ttl, rollup]
aliases: [ADR-51, message scheduler, delayed publish]
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# ADR-51 — the JetStream message scheduler

**Approved**, eight revisions tracking the feature across two releases: single delayed messages in
**2.12**, and cron, time zones, `Nats-Schedule-Rollup` and the stop-a-schedule protocol in **2.14**.
Revision 8 (2026-05-27, "Document Discard New is not supported") still carries server version **TBD**
— though the restriction *is* enforced at 2.14.6 ([[s-nats-server-message-schedules-observed]]).

It is the **only real description of this feature anywhere in public**: no `learn/` chapter of the
docs mentions message scheduling at all.

## Key claims

**The model.** "1 message contains a Cron-like schedule and new messages are produced, into the same
stream, on the schedule. In all cases the last message on a subject holds the current schedule. In
other words **every schedule must have its own unique subject**." Three use cases are targeted:
publish a message later, publish repeatedly on a schedule, and publish the latest message for a
subject on a schedule (data sampling).

**The stream field.** `AllowMsgSchedules` / `allow_msg_schedules`, and its rules:

- `AllowMsgTTL` must also be true to use `Nats-Schedule-TTL`;
- **setting it on a source or mirror is denied**;
- **Discard New is not supported**;
- **it can be enabled on an existing stream but never disabled**;
- the stream requires **API level 2**;
- **enabling it implicitly enables `AllowRollup` and clears `DenyPurge`**, because "schedules are
  stored as rollup-subject messages: the server auto-applies `Nats-Rollup: sub` if the publisher did
  not set it". Publishing a new schedule to an existing schedule subject **replaces** the prior one.

**The headers you set.**

| header | what it does |
|---|---|
| `Nats-Schedule` | the schedule — `@at <RFC3339>`, a 6-field cron, `@every <duration>`, or `@yearly`/`@monthly`/`@weekly`/`@daily`/`@hourly` |
| `Nats-Schedule-Target` | the subject the generated message is published to. Must be a subject **in the same stream** |
| `Nats-Schedule-Source` | read the **last message** on this subject and publish that instead. "If no message exists on the source subject, the schedule's own body and headers is published as a fallback. Wildcards are not supported" |
| `Nats-Schedule-TTL` | sets a TTL **on the generated message**, if the stream supports per-message TTLs |
| `Nats-Schedule-Time-Zone` | the zone for a **cron** schedule. "Not allowed to be used if the schedule is not a Cron schedule" |
| `Nats-Schedule-Rollup` | sets a rollup on the generated message; **only `sub` is valid** |

**The headers the server adds** to each generated message: `Nats-Scheduler` (**the subject holding
the schedule**), `Nats-Schedule-Next` (the next invocation as a timestamp, or **`purge`** for a
single delayed message), plus `Nats-TTL` and `Nats-Rollup` when the corresponding `Nats-Schedule-*`
header was given. "Additional headers added to the message will be sent to the target subject
verbatim."

**Cron is six fields, seconds first**: Seconds `0-59`, Minutes `0-59`, Hours `0-23`, Day of Month
`1-31`, Month `1-12` or names, Day of Week `0-6` or names with `0` = Sunday. Ranges, lists, step
values and names all work, "largely copied from `crontab(5)`". When both day-of-month and day-of-week
are restricted, **either** matching fires the schedule.

**`@every` takes a Go `time.ParseDuration` string, and the minimum supported interval is `1s`;
shorter intervals are rejected.** (`@every 1m` is the ADR's example, not the floor.)

**Time zones**, added in revision 3 and detailed in revision 7. Accepted values are what Go's
`time.LoadLocation()` understands: an IANA name (`America/New_York`), the literal `UTC`, the literal
`Local` (the server's own zone), or an abbreviation like `EST` "when the server's host tzdata provides
it" — abbreviations "are ambiguous… and are not DST-aware on their own", so IANA names are "strongly
recommended". **Fixed offsets such as `+02:00` are not accepted**, and an empty header value is
rejected — omit it to default to UTC.

**The operational consequence of time zones** is a real deployment requirement: "The server resolves
IANA names against its host's tzdata at runtime — if the server has no tzdata available for the
requested zone, the schedule is rejected as an invalid pattern. **Operators must therefore install and
keep tzdata up to date on every server** that is expected to evaluate Cron schedules in named time
zones; otherwise schedules might not run, or might not run at the expected time."

**DST is a warning, not a feature**: "If time moves forward due to DST, a schedule could be skipped if
its time was not reached. If time moves backward due to DST, a schedule could be executed twice."

**A past-dated schedule fires at once, including after downtime**: "If a server was down for a month
and a scheduled message is recovered, even if it was schedule for a month ago, it will be sent
immediately. **To avoid this, add a `Nats-TTL` header** to the message so it will be removed after the
TTL."

**Stopping a schedule** — two ways. Basic: delete the schedule message (by sequence, by purging its
subject, or by a wildcard purge). Advanced and **atomic**: publish a message carrying
`Nats-Schedule-Next: purge` and `Nats-Scheduler: <the schedule's subject>`, to the target subject (to
fire early) or to any other subject (to cancel and signal the cancellation). Combine with
`Nats-Expected-Last-Subject-Sequence` to stop a schedule only if it still exists.

**Error 10212 and why it exists.** "The selected subject in `Nats-Scheduler` can NOT equal the publish
subject itself; the server rejects such publishes with error code `10212`. The same error is returned
when `Nats-Scheduler` is empty or is not a valid publish subject. **The constraint exists because,
without it, the cancel message would be purged together with the schedule via the auto-applied
`Nats-Rollup: sub`, leaving no record of the cancellation.**"

**Retention.** A schedule "occupies a sequence on the schedule subject and must remain stored for as
long as the schedule should keep producing messages. Once a schedule message is removed from storage,
by any mechanism, its schedule stops firing." Consequences per policy:

- **`Limits`** — "the simplest configuration for most scheduling use cases and is recommended". But
  `MaxAge` shorter than the firing interval deletes the schedule before it fires ("prefer `Nats-TTL`
  on the schedule itself"), and `DiscardOld` / `MaxMsgs` / `MaxBytes` removal disables it the same way.
- **`WorkQueue`** — works "provided no consumer acknowledges the message before the schedule fires".
  A consumer filtered on the schedule subject **removes the schedule on ack, permanently stopping it**.
- **`Interest`** — "if no consumer has interest in the schedule subject, the schedule will not be
  stored, nor will it trigger scheduled messages."

**Two ways to combine schedules with Interest retention**, and the ADR prefers the second:

1. A **pinning consumer** on the same Interest stream whose filter covers the schedule subjects —
   `AckPolicy=none` or an unconsumed durable is enough. "The pinning consumer becomes load-bearing
   configuration: if it is deleted or its filter drifts, schedules silently stop", and it "adds
   overhead, especially when replicated". Not recommended.
2. A **separate WorkQueue source stream** holding the schedules (with `AllowMsgSchedules=true` and
   subjects covering both schedule and target patterns), with the Interest stream **sourcing** the
   target subjects from it. "Note that `AllowMsgSchedules` must be set on the `WorkQueue` source
   stream only, the `Interest` stream cannot set it because it has sources configured."

## Practical takeaways

- **Give every schedule its own subject**, and design the stream's subject space for it —
  `schedules.>` plus the target patterns, since the target "must be a subject in the same stream".
  For many delayed messages to one target, use `orders.schedule.<UUID>` and point
  `Nats-Schedule-Target` at `orders`.
- **`allow_msg_schedules` is a one-way door**, and it silently changes two other stream properties.
  Treat it as a security-relevant change: it enables rollups and re-permits purge
  ([[subject-permissions]]).
- **Named time zones are a host dependency.** A cron schedule in `Europe/Amsterdam` fails as an
  invalid *pattern* on a server with no tzdata — an error that names nothing about time zones.
- **`Limits` retention unless you have a reason.** The other two policies make the schedule's
  survival depend on consumer behaviour.

## Relevance to the wiki

The spine of [[message-scheduling]], and the answer to question-bank rows 29 and 30. Everything in it
that could be checked was **run** on v2.14.6 ([[s-nats-server-message-schedules-observed]]) — all of
it held, including revision 8's Discard New rule, whose server version the ADR still lists as `TBD`.

## Questions it answers

Rows 29 and 30.

## Pages touched

[[message-scheduling]] · [[stream]] · [[message-ttl]] · [[retention-policies]] ·
[[mirrors-and-sources]] · [[error-codes]] · [[publishing]] · [[subject-permissions]] ·
[[nats-server-2.12]] · [[nats-server-2.14]]
