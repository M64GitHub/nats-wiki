<!-- source: nats-server v2.14.6 (homebrew binary) with nats CLI 0.4.0, run locally 2026-09-01 ·
     plus server/stream.go and server/errors.json at tag v2.14.6 · verbatim transcript -->

# The JetStream message scheduler, run on nats-server v2.14.6 — 2026-09-01

ADR-51 is the only real description of this feature that exists: no `learn/` chapter in the docs
mentions message scheduling, and the reference tree carries only a header table and the error codes.
So every rule in the ADR that could be checked was **run**, and the header table was checked against
what the server actually produces — which it does not match.

```
$ nats-server --version
nats-server: v2.14.6
$ nats --version
0.4.0
```

## The stream

```
nats stream add SCHED --subjects='schedules.>,orders,sensors.>' --storage=file --replicas=1 \
  --retention=limits --discard=old --allow-schedules --allow-msg-ttl --defaults
```

`nats stream info SCHED` reports, and the stored config confirms:

```
                 Allows Purge: true
             Allows Schedules: true
               Allows Rollups: true
           Required API Level: 2 hosted at level 4
```

```json
"deny_purge": false, "allow_rollup_hdrs": true, "allow_msg_ttl": true, "allow_msg_schedules": true
```

**ADR-51's side effects are real and stored**: enabling schedules stores `allow_rollup_hdrs: true` and
`deny_purge: false`. Note the JSON field is **`allow_rollup_hdrs`**, not `allow_rollup` as the ADR's Go
snippet naming would suggest. The stream is also raised to **API level 2**, as the ADR says it should
be.

## A single delayed message, end to end

```
$ nats pub 'schedules.orders.single' 'delayed-body' \
    -H "Nats-Schedule:@at 2026-09-01T02:17:55Z" \
    -H 'Nats-Schedule-TTL:5m' -H 'Nats-Schedule-Target:orders' -H 'X-Custom:kept'
```

Five seconds later the schedule subject is **gone** and one message has appeared on `orders`:

```
$ nats stream get SCHED --last-for orders
Item: SCHED#4 received 2026-09-01 02:17:55.002189 +0000 UTC on Subject orders

Headers:
  X-Custom: kept
  Nats-Scheduler: schedules.orders.single
  Nats-Schedule-Next: purge
  Nats-TTL: 5m

delayed-body
```

Three things this settles, all against the docs' header reference:

1. **`Nats-Scheduler` is the subject that held the schedule** — `schedules.orders.single` — not a
   "Scheduler ID" as `reference/jetstream/api/headers.md` calls it.
2. **`Nats-Schedule-TTL` sets `Nats-TTL` on the *generated* message**, not a "Time-to-live for the
   schedule" as the same table says. The schedule's own lifetime is controlled by a `Nats-TTL` header
   on the schedule message, which is a different header.
3. **Extra headers ride through verbatim** (`X-Custom: kept`), as ADR-51 says.

An `@every`/cron schedule produces the other form of `Nats-Schedule-Next` — an RFC3339 timestamp
rather than `purge`:

```
Item: SCHED#56 on Subject orders
Headers:
  Nats-Scheduler: schedules.p.1s
  Nats-Schedule-Next: 2026-09-01T02:20:44Z
```

## Schedules roll up their own subject

Publishing a second schedule to the same subject leaves **one** message, not two:

```
$ nats pub 'schedules.orders.hourly' 'body-v1' -H 'Nats-Schedule:@hourly' -H 'Nats-Schedule-Target:orders'
$ nats pub 'schedules.orders.hourly' 'body-v2' -H 'Nats-Schedule:@hourly' -H 'Nats-Schedule-Target:orders'
$ nats stream subjects SCHED
│ schedules.orders.hourly │ 1 │
```

— the auto-applied `Nats-Rollup: sub` ADR-51 describes. "Publishing a new schedule to an existing
schedule subject replaces the prior one" is observed, not just specified.

## A past-dated schedule fires immediately

```
Z · @at with a timestamp in 2009 (16 years in the past)
    OK — stored at seq 68
```

Two seconds later the schedule subject is gone and the body is on the target:

```
Item: SCHED#69 received 2026-09-01 02:20:54.541722 +0000 UTC on Subject orders
Headers:
  Nats-Schedule-Next: purge
  Nats-Scheduler: schedules.past.only
past-body
```

## A trap in the instrument, worth recording

The first attempt at the error tests below reported that **every** invalid publish was accepted.
That was wrong, and the cause is operationally important: **`nats pub` without `-J` is a core NATS
publish.** It sets no reply subject, so the JetStream `PubAck` — including the rejection — goes
nowhere and the CLI prints `Published N bytes` for a message the server refused.

```
$ nats pub 'schedules.cli.bad' 'x' -H 'Nats-Schedule:*/5 * * * *' -H 'Nats-Schedule-Target:orders'
04:21:30 Published 1 bytes to "schedules.cli.bad"          # no error, and nothing was stored

$ nats pub -J 'schedules.cli.bad' 'x' --schedule-cron='*/5 * * * *' --schedule-dest=orders
nats: error: message schedules pattern is invalid (10189)
```

Every result below was re-run through a client that reads the `PubAck`
(`raw/nats-server-src/nats-probe-client.py`, publishing with `HPUB` and a reply subject).

## Every rule ADR-51 states, run

`OK` means the server stored the message; otherwise the error code and description are the server's
own, read off the `PubAck`.

| # | what was published | result |
|---|---|---|
| A | a valid `@hourly` schedule with a target | **OK** |
| B | a cancel from a **different** subject (`Nats-Schedule-Next: purge` + `Nats-Scheduler`) | **OK** — and the schedule is removed |
| C | `Nats-Scheduler` **equal to the publish subject** | **10212** `message schedules invalid scheduler` |
| D | `Nats-Scheduler` **empty** | **10212** |
| E | `Nats-Scheduler` a wildcard (`schedules.orders.>`) | **10212** |
| F | `Nats-Scheduler` **without** `Nats-Schedule-Next` | **10212** |
| G | `Nats-Schedule-Next` with a value other than `purge` | **10212** |
| H | a **6-field** cron, `0 */5 * * * *` | **OK** |
| I | a **5-field** cron, `*/5 * * * *` — the classic crontab shape | **10189** `message schedules pattern is invalid` |
| J | `@every 500ms` — below the stated minimum | **10189** |
| K | `@every 1s` — the stated minimum | **OK** |
| L | `Nats-Schedule-Time-Zone: Europe/Amsterdam` on a **cron** schedule | **OK** |
| M | the same time zone on an **`@every`** schedule | **10189** — *the pattern error, not the time-zone one* |
| N | `Nats-Schedule-Time-Zone: +02:00` (a fixed offset) | **10223** `message schedules time zone is invalid` |
| O | `Nats-Schedule-Time-Zone:` (empty) | **10223** |
| P | a schedule with **no** `Nats-Schedule-Target` | **10190** `message schedules target is invalid` |
| Q | a target subject **not in the stream** | **10190** |
| R | `Nats-Schedule-Rollup: all` | **10192** `message schedules invalid rollup` |
| S | a **wildcard** `Nats-Schedule-Source` | **10203** `message schedules source is invalid` |
| T | any schedule on a stream with `allow_msg_schedules` **false** | **10188** `message schedules is disabled` |
| U | `Nats-Schedule-TTL` on a stream **without** `allow_msg_ttl` | **10166** `per-message TTL is disabled` (`JSMessageTTLDisabledErr`) — *not* 10191 |
| V | the same schedule with no TTL header (control) | **OK** |
| W | a **cancel** on a stream with schedules disabled | **10188** |
| X | `Nats-Schedule-TTL: banana` on a TTL-enabled stream | **10191** `message schedules invalid per-message TTL` |
| Y | `Nats-Schedule-TTL: 500ms` — below the per-message-TTL floor | **10191** |

Stream-level rules, through `nats stream add` / `edit` (these are request-reply, so the CLI does show
the error):

```
$ nats stream add MIR --mirror SCHED --allow-schedules …
nats: error: could not create Stream: stream mirrors can not also schedule messages (10186)

$ nats stream add SRC --source SCHED --allow-schedules …
nats: error: could not create Stream: stream source can not also schedule messages (10187)

$ nats stream add SCHEDNEW --subjects='sn.>' --discard=new --allow-schedules …
nats: error: could not create Stream: message scheduling cannot use discard new (10052)

$ nats stream edit SCHED --no-allow-schedules -f
nats: error: could not edit Stream SCHED: message schedules can not be disabled (10052)
```

**ADR-51 revision 8 lists "Document Discard New is not supported" with server version `TBD`. It is
enforced at 2.14.6.**

**Both stream-level refusals arrive as 10052**, which is the generic `JSStreamInvalidConfigF`
(`{err}`, HTTP 500) — the specific reason is only in the message text, so code-matching cannot tell
these apart from any other invalid stream config.

## The scheduler error codes at v2.14.6

From `server/errors.json` at the tag — **ten**, not the nine the docs' error page was read as having
(`10223` is there too, and it is in the docs mirror):

| code | constant | description |
|---|---|---|
| 10186 | `JSMirrorWithMsgSchedulesErr` | stream mirrors can not also schedule messages |
| 10187 | `JSSourceWithMsgSchedulesErr` | stream source can not also schedule messages |
| 10188 | `JSMessageSchedulesDisabledErr` | message schedules is disabled |
| 10189 | `JSMessageSchedulesPatternInvalidErr` | message schedules pattern is invalid |
| 10190 | `JSMessageSchedulesTargetInvalidErr` | message schedules target is invalid |
| 10191 | `JSMessageSchedulesTTLInvalidErr` | message schedules invalid per-message TTL |
| 10192 | `JSMessageSchedulesRollupInvalidErr` | message schedules invalid rollup |
| 10203 | `JSMessageSchedulesSourceInvalidErr` | message schedules source is invalid |
| 10212 | `JSMessageSchedulesSchedulerInvalidErr` | message schedules invalid scheduler |
| 10223 | `JSMessageSchedulesTimeZoneInvalidErr` | message schedules time zone is invalid |

The five `10212` conditions are all in one block of `server/stream.go` at v2.14.6 (`:6619–6678`):

```go
			if scheduleNext := sliceHeader(JSScheduleNext, hdr); len(scheduleNext) > 0 && !sourced {
				// Clients may only use Nats-Schedule-Next to purge a schedule.
				if bytesToString(scheduleNext) != JSScheduleNextPurge {
					apiErr := NewJSMessageSchedulesSchedulerInvalidError()
				…
				// Nats-Scheduler must accompany the purge and:
				// - it must NOT be empty.
				// - it must NOT match the publish subject.
				if scheduler := sliceHeader(JSScheduler, hdr); len(scheduler) == 0 ||
					bytesToString(scheduler) == subject || !IsValidPublishSubject(bytesToString(scheduler)) {
				…
			} else if !sourced && len(sliceHeader(JSScheduler, hdr)) > 0 {
				// Clients may only use Nats-Scheduler alongside Nats-Schedule-Next.
```

with one more, from the same block, that is **deliberately lenient**:

```go
					// Check that the to-be-purged subject is a schedule message.
					// We still allow this message through if there exists no message for this subject,
					// to remain backward-compatible. An "expected at sequence" check can still be
					// performed to make this stricter.
```

`JSScheduler = "Nats-Scheduler"` is defined at `stream.go:675`.

## nats CLI 0.4.0 has scheduling flags, and one of them cannot work

The CLI has first-class flags no public source read so far mentions:

```
--schedule-after=DURATION   --schedule-at=TIME     --schedule-cron=CRON
--schedule-every=DURATION   --schedule-dest=SUBJECT --schedule-source=SUBJECT
--schedule-ttl=DURATION
```

all of which imply `--jetstream`. There is **no** flag for `Nats-Schedule-Time-Zone` or
`Nats-Schedule-Rollup`; those need `-H`.

**`--schedule-after` produces a schedule the server always rejects.** From the server's trace log,
the four flags side by side:

```
--schedule-after=3s   ->  Nats-Schedule: 2026-09-01T02:21:28Z        ->  10189 pattern is invalid
--schedule-at=<ts>    ->  Nats-Schedule: @at 2026-09-01T02:21:50Z    ->  OK
--schedule-every=1m   ->  Nats-Schedule: @every 1m0s                 ->  OK
--schedule-cron='0 */5 * * * *' -> Nats-Schedule: 0 */5 * * * *      ->  OK
```

`--schedule-after` emits the timestamp **without the `@at ` prefix**. The error blames the pattern,
so nothing points at the flag.

## What was NOT tested

- **Clustered streams.** Everything here is R1 on one server; schedule firing under a leader change
  was not tested, nor was the ADR's claim about scale (gh#7628's "100K+ pending schedules").
- **The two-stream `WorkQueue` + `Interest` composition** ADR-51 recommends, and the pinning-consumer
  workaround. Only `limits` retention was exercised.
- **`Nats-Schedule-Source` sampling end to end** — only the wildcard rejection was run.
- **DST behaviour**, which ADR-51 warns about; it needs a clock, not a config.
- **Whether tzdata is present** on this host for every IANA zone, beyond `Europe/Amsterdam`.
- **2.12**, where cron is expected to fail with the same 10189 for a different reason (gh#7672).

## Addendum — two claims from the Synadia post, checked (same session, 2026-09-01)

*Delayed Message Scheduling in NATS JetStream* (Peter Humulock, 2026-04-09) states a rule ADR-51 does
not: "Target and schedule subjects must differ — The `Nats-Schedule-Target` must point to a different
subject than the one the schedule message is published to." **The server enforces it**, with the
target error rather than the scheduler one:

| # | what was published | result |
|---|---|---|
| AA | `Nats-Schedule-Target` equal to the schedule's own subject | **10190** `message schedules target is invalid` |
| AB | the same schedule with a different target in the same stream (control) | **OK** |

The post's other three caveats were already covered above: a past-dated schedule fires immediately
(observed), one schedule per subject with the latest replacing the prior (observed), and
mirrors/sources refused (10186 / 10187). Its DST caveat was **not** tested — it needs a clock, not a
config.
