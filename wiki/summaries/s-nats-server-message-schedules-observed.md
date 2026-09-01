---
title: "Observed on nats-server v2.14.6 — the message scheduler"
type: summary
area: [jetstream]
source-path: raw/nats-server-src/message-schedules-observed-v2.14.6.md
source-url: https://github.com/nats-io/nats-server/blob/v2.14.6/server/stream.go
author: "run locally; server source by the nats-io authors"
article: "26 publishes and 4 stream operations on nats-server v2.14.6 with nats CLI 0.4.0, plus server/stream.go and errors.json at the tag"
date: 2026-09-01
version: "2.14.6"
tags: [message-scheduling, allow_msg_schedules, error-codes, Nats-Scheduler, cron, observed]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# Observed on v2.14.6 — the message scheduler

ADR-51 is the only description of this feature in public, so every rule in it that could be checked
was run: **26 publishes and 4 stream operations**, plus the error registry and the validation block of
`server/stream.go` at the tag. **Everything the ADR states held.** The docs' header table did not.

## Key claims

**The stream field does what the ADR says.** `--allow-schedules` stores `allow_msg_schedules: true`
**and** `allow_rollup_hdrs: true` **and** `deny_purge: false`, and raises the stream to **API level 2**.
The JSON field is `allow_rollup_hdrs`, not `allow_rollup`.

**Four stream-level refusals**, with their exact messages:

```
stream mirrors can not also schedule messages (10186)
stream source can not also schedule messages (10187)
message scheduling cannot use discard new (10052)
message schedules can not be disabled (10052)
```

**The Discard New rule is enforced at 2.14.6**, though ADR-51 revision 8 still lists its server
version as `TBD`. **Both stream-level refusals arrive as `10052`** — the generic
`JSStreamInvalidConfigF` (`{err}`, HTTP 500) — so the reason is only in the message text and cannot be
matched on the code.

**The generated message, read off the stream**:

```
Headers:
  X-Custom: kept
  Nats-Scheduler: schedules.orders.single
  Nats-Schedule-Next: purge
  Nats-TTL: 5m
```

so `Nats-Scheduler` is **the schedule's subject**, `Nats-Schedule-TTL` becomes **`Nats-TTL` on the
generated message**, extra headers ride through verbatim, and `Nats-Schedule-Next` is `purge` for an
`@at` schedule and an RFC3339 timestamp for a repeating one. **The docs' header reference is wrong
about the first two** — it calls `Nats-Scheduler` a "Scheduler ID" and `Nats-Schedule-TTL` a
"Time-to-live for the schedule" (`inbox/docs-issues.md` **#41**).

**Schedules roll up their own subject**: publishing a second schedule to the same subject leaves one
message, not two. **A past-dated `@at` fires immediately** — a 2009 timestamp landed on the target
within two seconds and purged its schedule.

**Twenty-six publishes pin ten error codes to their conditions**, all read off the `PubAck`:

| condition | code |
|---|---|
| `Nats-Scheduler` equal to the publish subject; empty; a wildcard; without `Nats-Schedule-Next`; or `Nats-Schedule-Next` ≠ `purge` | **10212** |
| a **5-field** cron (the classic crontab shape); `@every` below `1s`; a time zone on a non-cron schedule | **10189** |
| a fixed UTC offset (`+02:00`) or an empty time-zone header | **10223** |
| no target, or a target not in the stream | **10190** |
| `Nats-Schedule-Rollup` other than `sub` | **10192** |
| a wildcard `Nats-Schedule-Source` | **10203** |
| any schedule (or cancel) on a stream with schedules off | **10188** |
| a malformed `Nats-Schedule-TTL`, or one below the per-message-TTL floor | **10191** |
| `Nats-Schedule-TTL` on a stream without `allow_msg_ttl` | **10166**, *not* 10191 |

**There are ten scheduler error codes at v2.14.6, not nine** — `10223`
`JSMessageSchedulesTimeZoneInvalidErr` joins the eight the ADR discusses plus `10203`.

**A time zone on an `@every` schedule is rejected as a bad *pattern* (10189)**, not as a bad time
zone — worth knowing when reading the error.

## Practical takeaways

- **`nats pub` without `-J` cannot tell you a publish was refused.** It is a core NATS publish with no
  reply subject, so the `PubAck` — including the rejection — goes nowhere and the CLI prints
  `Published N bytes` for a message the server threw away. Always use `-J` when publishing a schedule.
- **nats CLI 0.4.0 has scheduling flags** no public source read so far mentions: `--schedule-at`,
  `--schedule-after`, `--schedule-every`, `--schedule-cron`, `--schedule-dest`, `--schedule-source`,
  `--schedule-ttl`, all implying `--jetstream`. There is **no** flag for the time zone or the rollup.
- **`--schedule-after` is broken at v0.4.0.** It emits `Nats-Schedule: <RFC3339>` with **no `@at `
  prefix**, which the server always rejects with `10189 message schedules pattern is invalid` — an
  error that blames the pattern and points at nothing. `--schedule-at` emits `@at <RFC3339>` and
  works. `inbox/docs-issues.md` **#40**.
- **A five-field cron is the trap to expect.** `*/5 * * * *` is what everyone types and the server
  wants six fields, seconds first. It fails with the same `10189` that a 2.14 expression gets on a
  2.12 server ([[s-gh-7672-cron-schedules]]) — one error code, two completely different causes.

## Notable quotes

> "// We still allow this message through if there exists no message for this subject, to remain
> backward-compatible." — `server/stream.go`, in the `Nats-Scheduler` validation block, v2.14.6

## Relevance to the wiki

Everything on [[message-scheduling]] that states a value, an error code or a behaviour is from here
rather than from a doc page, because there is no doc page. It produced `inbox/docs-issues.md` **#40**
(the CLI flag), **#41** (the header table) and **#42** (no prose chapter at all).

## Questions it answers

Rows 29 and 30, with the values.

## Pages touched

[[message-scheduling]] · [[stream]] · [[error-codes]] · [[message-ttl]] · [[publishing]]
