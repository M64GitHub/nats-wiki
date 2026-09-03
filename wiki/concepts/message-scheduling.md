---
title: Message scheduling
type: concept
area: [jetstream]
since: [2.12]
verified-against: nats-server 2.14.6
verified-on: 2026-09-01
tags: [message-scheduling, allow_msg_schedules, Nats-Schedule, cron, delayed-publish, message-ttl]
aliases: [message scheduler, scheduled messages, delayed publishing, delayed message, cron schedule, Nats-Schedule, allow_msg_schedules]
sources: [s-adr-51-message-scheduler, s-nats-server-message-schedules-observed, s-docs-jetstream-headers, s-gh-7672-cron-schedules, s-gh-7628-scheduler-vs-nak, s-synadia-delayed-scheduling, s-relnotes-2.12, s-relnotes-2.14]
created: 2026-09-01
updated: 2026-09-03
---

# Message scheduling

**A stream can hold a message and publish it later, once or on a schedule.** You publish a message
carrying `Nats-Schedule` headers to a subject in the stream; the server keeps it and produces new
messages on a target subject at the times you asked for. It is how you get a delayed publish or a
recurring one without a timer service, a cron host or a consumer that sits on messages
(source: [[s-adr-51-message-scheduler]]).

**Since 2.12 for single delayed messages; cron, `@every`, subject sampling and time zones arrived in
2.14** (source: [[s-gh-7672-cron-schedules]]). Everything on this page was run on **v2.14.6**
(source: [[s-nats-server-message-schedules-observed]]), because there is **no chapter about this
feature anywhere in the documentation** — see *Where the documentation is*, below.

## How it behaves

The unit is a **message that holds a schedule**, stored on its own subject:

```
nats pub -J 'schedules.orders.single' 'the body' \
  --schedule-at='2026-09-01T02:17:55Z' --schedule-dest=orders --schedule-ttl=5m
```

Three rules follow from that, and they are the whole model:

1. **Every schedule needs its own unique subject.** "In all cases the last message on a subject holds
   the current schedule" — publishing a second schedule to the same subject **replaces** the first
   (observed: two publishes, one message). For many delayed messages aimed at one target, use
   `orders.schedule.<UUID>` and set the target to `orders`.
2. **The target must be a subject in the same [[stream]].** A target the stream does not cover is
   rejected with `10190`.
3. **The schedule lives only as long as its message does.** "Once a schedule message is removed from
   storage, by any mechanism, its schedule stops firing" — including removal by `max_age`, by
   `max_msgs`, by a purge, or by a consumer acking it on a `workqueue` stream. See *Retention decides
   whether a schedule survives*.

When the schedule fires, the server publishes to the target and adds its own headers. Read off the
stream at v2.14.6:

```
Item: SCHED#4 on Subject orders

Headers:
  X-Custom: kept
  Nats-Scheduler: schedules.orders.single
  Nats-Schedule-Next: purge
  Nats-TTL: 5m

delayed-body
```

**`Nats-Scheduler` is the subject that held the schedule.** `Nats-Schedule-Next` is `purge` for a
single delayed message and the next invocation's RFC3339 timestamp for a repeating one. Any other
headers on the schedule ride through to the target verbatim.

**A past-dated schedule fires immediately** — a 2009 timestamp landed on the target within two
seconds. That includes recovery after downtime: "if a server was down for a month and a scheduled
message is recovered, even if it was schedule for a month ago, it will be sent immediately". To avoid
that, put a **`Nats-TTL` on the schedule message itself** so it expires instead of firing late.

## What configures it

### The stream field

```
nats stream add SCHED --subjects='schedules.>,orders' --allow-schedules --allow-msg-ttl
```

`allow_msg_schedules` (`AllowMsgSchedules`), **since 2.12**. Its rules, all confirmed on v2.14.6:

| rule | what happens if you break it |
|---|---|
| **cannot be disabled once enabled** | `message schedules can not be disabled (10052)` |
| **not allowed on a mirror** | `stream mirrors can not also schedule messages (10186)` |
| **not allowed on a stream with sources** | `stream source can not also schedule messages (10187)` |
| **not supported with Discard New** | `message scheduling cannot use discard new (10052)` |
| `allow_msg_ttl` must be on to use `Nats-Schedule-TTL` | `per-message TTL is disabled (10166)` |
| the stream is raised to **API level 2** | older clients cannot manage it |

**Enabling it silently changes two other stream properties**: it stores `allow_rollup_hdrs: true` and
clears `deny_purge`. That is not cosmetic — schedules are stored as rollup-subject messages and the
server auto-applies `Nats-Rollup: sub`, so the feature needs both. A stream whose permissions model
assumed rollups were off, or that purge was denied, has quietly changed; see [[subject-permissions]].

**The Discard New restriction is enforced at 2.14.6** even though ADR-51's revision 8 still records
its server version as `TBD` (source: [[s-nats-server-message-schedules-observed]]).

### The headers you set

| header | value | since |
|---|---|---|
| `Nats-Schedule` | `@at <RFC3339>` (2.12); a **6-field** cron, `@every <duration>`, or `@yearly`/`@monthly`/`@weekly`/`@daily`/`@hourly` (2.14) | 2.12 / 2.14 |
| `Nats-Schedule-Target` | the subject the generated message is published to. Required, and must be in the same stream | 2.12 |
| `Nats-Schedule-Source` | publish the **last message on this subject** instead of the schedule's own body. No wildcards. Falls back to the schedule's body if the source has no message | 2.14 |
| `Nats-Schedule-TTL` | a TTL applied to the **generated message** (needs `allow_msg_ttl`) | 2.12 |
| `Nats-Schedule-Time-Zone` | the zone for a **cron** schedule only | 2.14 |
| `Nats-Schedule-Rollup` | `sub`, and only `sub` — sets a rollup on the generated message | 2.14 |

and the two the **server** adds to each generated message: `Nats-Scheduler` (the schedule's subject)
and `Nats-Schedule-Next` (`purge`, or the next timestamp), plus `Nats-TTL` and `Nats-Rollup` when the
corresponding `Nats-Schedule-*` header was given (source: [[s-docs-jetstream-headers]]).

### Cron is six fields, seconds first

| field | values |
|---|---|
| Seconds | `0-59` |
| Minutes | `0-59` |
| Hours | `0-23` |
| Day of month | `1-31` |
| Month | `1-12`, or names |
| Day of week | `0-6`, or names; `0` is Sunday |

Ranges (`8-11`), lists (`1,2,5,9`), steps (`*/2`, `0-23/2`) and three-letter names (`mon,wed,fri`,
`jan-mar`) all work — "largely copied from the `crontab(5)` man page". When **both** day-of-month and
day-of-week are restricted, the schedule fires when **either** matches.

**`@every` takes a Go duration and its minimum is `1s`**; `@every 500ms` is rejected and `@every 1s`
is accepted (observed). Times are UTC unless a cron schedule names a zone.

### Time zones are a host dependency

`Nats-Schedule-Time-Zone` accepts what Go's `time.LoadLocation()` accepts: an IANA name
(`Europe/Amsterdam`), the literal `UTC`, the literal `Local` (the server's own zone), or an
abbreviation such as `EST` **if the host's tzdata provides it**. Abbreviations "are ambiguous… and are
not DST-aware on their own", so IANA names are the recommendation. **Fixed offsets like `+02:00` are
rejected**, and so is an empty header value — omit it for UTC.

**Install and maintain tzdata on every server that evaluates cron schedules.** ADR-51 is explicit:
without it the schedule "is rejected as an invalid pattern", so a missing time zone database looks
like a syntax error and nothing mentions time zones at all.

**DST is a warning, not a feature.** A schedule whose time is skipped by a spring-forward may not run;
one whose time occurs twice in an autumn fall-back may run twice. Avoid scheduling into the transition
hour.

## Stopping a schedule

Two ways (source: [[s-adr-51-message-scheduler]]).

**Basic — remove the schedule message.** Delete it by stream sequence, purge its subject, or purge a
wildcard covering several schedule subjects.

**Atomic — cancel and publish in one operation.** Publish a message carrying
`Nats-Schedule-Next: purge` and `Nats-Scheduler: <the schedule's subject>`:

- to the **target** subject, to fire the delayed message early; or
- to **any other** subject, to cancel and record the cancellation for a different set of consumers.

Combine it with `Nats-Expected-Last-Subject-Sequence` (and
`Nats-Expected-Last-Subject-Sequence-Subject`) to cancel only if the schedule still exists
([[publishing]]).

**`Nats-Scheduler` may not equal the subject you publish to.** The server refuses with `10212`, and
the reason is worth understanding rather than working around: the cancel would be rolled up together
with the schedule by the auto-applied `Nats-Rollup: sub`, "leaving no record of the cancellation".

All five ways to get `10212`, observed at v2.14.6:

| what you did | |
|---|---|
| `Nats-Scheduler` equals the publish subject | 10212 |
| `Nats-Scheduler` empty | 10212 |
| `Nats-Scheduler` is not a valid publish subject (e.g. a wildcard) | 10212 |
| `Nats-Scheduler` without `Nats-Schedule-Next` | 10212 |
| `Nats-Schedule-Next` set to anything but `purge` | 10212 |

One check is deliberately lenient: cancelling a schedule subject that holds **no** message is allowed,
"to remain backward-compatible" — use the expected-sequence headers if you need it strict.

## Retention decides whether a schedule survives

A schedule occupies a sequence and must stay stored to keep firing, so retention is not a detail here
(source: [[s-adr-51-message-scheduler]]; see [[retention-policies]]).

| policy | what it means for a schedule |
|---|---|
| **`limits`** | **the recommended choice.** But `max_age` shorter than the firing interval deletes the schedule before it fires — prefer a `Nats-TTL` on the schedule itself — and `discard: old` with `max_msgs`/`max_bytes` can evict it the same way |
| **`workqueue`** | works only while no consumer acks the schedule message. A consumer filtered on the schedule subject **permanently stops the schedule on ack** |
| **`interest`** | if no consumer has interest in the schedule subject, "the schedule will not be stored, nor will it trigger scheduled messages" |

**To combine schedules with `interest` retention, use two streams.** ADR-51 gives both options and
prefers the second:

1. A **pinning consumer** on the interest stream whose filter covers the schedule subjects
   (`ack_policy: none` is enough). It works, but "the pinning consumer becomes load-bearing
   configuration: if it is deleted or its filter drifts, schedules silently stop", and it costs
   overhead when replicated.
2. A **separate `workqueue` stream** holding the schedules, with `allow_msg_schedules` and subjects
   covering both the schedule and target patterns, and the interest stream **sourcing** the target
   subjects from it. The schedules never leave the workqueue stream. Note the asymmetry that makes
   this work: `allow_msg_schedules` goes on the source stream only — **the interest stream cannot set
   it, because it has sources configured** ([[mirrors-and-sources]]).

## Limits and failure modes

Ranked by how often they are the answer.

1. **A five-field cron.** `*/5 * * * *` is what everyone types; the server wants **six** fields with
   seconds first, and answers `10189 message schedules pattern is invalid` (observed). The error names
   nothing about field counts.
2. **The same `10189` on a 2.12 server means something else entirely** — cron did not ship until 2.14.
   "Only single scheduled messages from that ADR were released as part of 2.12… The remaining items,
   like cron-like schedules, will be part of version 2.14" (source: [[s-gh-7672-cron-schedules]]).
   Check the server version before debugging the expression.
3. **`nats pub` without `-J` hides the rejection.** It is a core NATS publish with no reply subject,
   so the `PubAck` — including a `10189` or `10212` — goes nowhere and the CLI prints
   `Published N bytes` for a message that was thrown away. Always publish schedules with `-J`.
4. **`--schedule-after` does not work at nats CLI 0.4.0.** It emits `Nats-Schedule: <RFC3339>` with no
   `@at ` prefix and is always rejected with `10189`. Use `--schedule-at` with an absolute time
   (`inbox/docs-issues.md` #40).
5. **A missing tzdata package looks like a bad cron expression**, not like a time-zone problem
   (above). And a time zone on a non-cron schedule is `10189` too — not the time-zone error.
6. **A schedule that quietly stopped is usually retention**, not the scheduler: something removed the
   schedule message. Check that the subject still holds it before debugging anything else.
7. **`allow_msg_schedules` cannot be undone.** Enabling it to try the feature permanently enables
   rollups and re-permits purge on that stream.

## What you can observe

```
nats stream info SCHED --json | jq '.config | {allow_msg_schedules, allow_rollup_hdrs, deny_purge}'
nats stream subjects SCHED                      # is the schedule message still there?
nats stream get SCHED --last-for orders         # the generated message, with its headers
```

`nats stream info` prints `Allows Schedules: true` and `Required API Level: 2` on an enabled stream.
There is **no** `nats schedule` command and no listing of active schedules at CLI v0.4.0: the
schedules *are* the messages on the schedule subjects, so `nats stream subjects` is the listing.

The error codes, all observed at v2.14.6 — see [[error-codes]]:

| code | condition |
|---|---|
| `10186` / `10187` | `allow_msg_schedules` on a mirror / on a stream with sources |
| `10188` | any schedule or cancel on a stream with schedules off |
| `10189` | bad pattern: a 5-field cron, `@every` under `1s`, a time zone on a non-cron schedule, an unknown zone — or a 2.14 expression on 2.12 |
| `10190` | no target, or a target outside the stream |
| `10191` | a malformed `Nats-Schedule-TTL`, or one below the per-message-TTL floor |
| `10192` | `Nats-Schedule-Rollup` other than `sub` |
| `10203` | a wildcard `Nats-Schedule-Source` |
| `10212` | the five `Nats-Scheduler` conditions above |
| `10223` | a fixed offset or an empty `Nats-Schedule-Time-Zone` |
| `10052` | the two stream-level refusals — a generic config error whose reason is only in the text |

## Scheduling vs a delayed nak

The decision this feature exists to settle, and a maintainer answers it directly for a service with
100K+ pending schedules (source: [[s-gh-7628-scheduler-vs-nak]]):

> "Would definitely recommend using the new 2.12 scheduling feature over NakWithDelay, since **Nak is
> not meant for that purpose** and only really works as a workaround because the 2.12 scheduling
> feature wasn't there before. It should support a very large amount of schedules since it's **built
> on top of the per-message TTL work** which similarly also supports a very large amount. But, it's
> always good to test for your use case."

The measured reason to agree is on [[ack-and-redelivery]]: **a nak'd message holds its
`max_ack_pending` slot for the whole delay**, so a design with 100K messages sleeping needs a cap of
100K, and a small cap stalls the consumer completely. A delayed nak is for retrying a *failure*; a
schedule is for work that is simply due later.

**The scale claim is unverified.** No public source states a tested schedule count, the maintainer's
own advice is to test, and this wiki did not test it either. What is verified is the mechanism: the
scheduler is built on the per-message TTL machinery ([[message-ttl]]), not on a separate timer
subsystem.

## Two rules that are only in one source each

**The target may not be the schedule's own subject.** ADR-51 never says this; a Synadia post does, and
the server enforces it with `10190 message schedules target is invalid` (source:
[[s-synadia-delayed-scheduling]], confirmed at v2.14.6). It follows from the model — the schedule
subject holds the schedule and the target receives the output — but nothing in the specification
states it, so it is easy to write and be surprised by.

**`allow_msg_ttl` is not implied by `allow_msg_schedules`.** They are separate flags, and a
`Nats-Schedule-TTL` on a stream that has only the second fails with `10166 per-message TTL is
disabled` — a TTL error on what looks like a scheduling problem.

**Where two sources give different advice about stale schedules, prefer the ADR.** Both agree a
past-dated schedule fires immediately, including after a restart. The blog suggests
`Nats-Schedule-TTL` "so consumers can detect and discard stale deliveries"; ADR-51 says to put a
**`Nats-TTL` on the schedule message itself** so it is removed before it can fire. The ADR's advice
prevents the delivery; the blog's only labels it after the fact.


## Where the documentation is

**There is no `learn/` chapter about message scheduling.** The feature exists in the docs as a header
table in `reference/jetstream/api/headers.md` (source: [[s-docs-jetstream-headers]]), ten error codes
in the error reference, and a few lines of release notes — for a feature that shipped in 2.12 and grew
in 2.14. The asker of gh#7672 says it plainly: *"Can't find much more info in the docs or code."*

Recorded as `inbox/docs-issues.md` **#42**. Two of the header table's own rows are also wrong — it
calls `Nats-Scheduler` a "Scheduler ID" and `Nats-Schedule-TTL` a "Time-to-live for the schedule",
where the server makes the first a subject and the second a TTL on the *generated message*
(**#41**). **This page therefore states ADR-51 and the binary, not the docs.**

## Cheat sheet

```
nats stream add SCHED --subjects='schedules.>,orders' --allow-schedules --allow-msg-ttl
nats pub -J schedules.orders.single 'body' --schedule-at=2026-09-01T02:17:55Z --schedule-dest=orders
nats pub -J schedules.orders.hourly 'body' --schedule-cron='0 0 * * * *' --schedule-dest=orders
nats pub -J schedules.orders.every  'body' --schedule-every=5m --schedule-dest=orders
nats pub -J schedules.sensors.sample '' --schedule-every=5m \
    --schedule-source=sensors.cnc.temperature --schedule-dest=sensors.sampled.cnc.temperature
nats pub -J schedules.orders.hourly 'x' --schedule-cron='0 0 * * * *' --schedule-dest=orders \
    -H 'Nats-Schedule-Time-Zone:Europe/Amsterdam'
nats pub -J schedules.orders.canceled 'cancelled' \
    -H 'Nats-Schedule-Next:purge' -H 'Nats-Scheduler:schedules.orders.hourly'
nats stream subjects SCHED
```

There is no CLI flag for the time zone or the rollup — use `-H`. **Do not use `--schedule-after`**
(failure mode 4).

## Version notes: the 2.12 patches

Single-message scheduling shipped in 2.12.0 (#7170, #7245, #7319, "using the `Nats-Schedule-TTL`
message header") (source: [[s-relnotes-2.12]]). Then: **2.12.1** — a scheduled message is
deactivated "when followed up with another message on the same subject without a schedule" (#7366)
and triggers correctly after a recovery (#7347); **2.12.8** — `Nats-Schedule-Next: purge` errors
when scheduling is not enabled on the stream (#8035); **2.12.9** — schedule subjects corrupted on
recovery (#8085); **2.12.10** — "configuration constraints applied to prevent incorrect usage
patterns" for counters and schedules (#8240); **2.12.12** — malformed schedule state rejected on
decode (#8269). Cron and `@every` are 2.14 ([[nats-server-2.14]]).


## Version notes: the 2.14 patches

Repeating and cron schedules, `Nats-Schedule-Source` and `Nats-Schedule-Rollup` are 2.14.0 (#7504,
#7687, #7688; #7506; #7559) (source: [[s-relnotes-2.14]]). Then: **2.14.1** — `Nats-Schedule-Next:
purge` "now correctly checks if the target is a schedule" (#8135); **2.14.2** — configuration
constraints on counter streams and schedules "to prevent incorrect usage patterns" (#8240);
**2.14.3** — schedule drift fixed (#8308) and malformed schedule state rejected on decode (#8269).
The 2.12 twins carry the same fixes ([[nats-server-2.12]]).


## Related

[[stream]] · [[message-ttl]] · [[retention-policies]] · [[mirrors-and-sources]] · [[publishing]] ·
[[ack-and-redelivery]] · [[error-codes]] · [[subject-permissions]] · [[js-api-subjects]] ·
[[nats-server-2.12]] · [[nats-server-2.14]]

## Sources

[[s-adr-51-message-scheduler]] · [[s-nats-server-message-schedules-observed]] ·
[[s-docs-jetstream-headers]] · [[s-gh-7672-cron-schedules]] · [[s-gh-7628-scheduler-vs-nak]]

Run directly, not read: `raw/nats-server-src/message-schedules-observed-v2.14.6.md` — nats-server
v2.14.6 with nats CLI 0.4.0, 2026-09-01. · [[s-synadia-delayed-scheduling]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]]
