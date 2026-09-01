---
title: Advisories and system events
type: reference
area: [monitoring, jetstream, core]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [advisories, events, "$JS.EVENT.ADVISORY", "$SYS", monitoring]
aliases: [advisories, "$JS.EVENT.ADVISORY", system events, jetstream advisories]
sources: [s-nats-server-jetstream-resources, s-nats-server-jetstream-log-warnings, s-nats-server-constants-2.14.6, s-adr-42-priority-groups, s-docs-acknowledgment, s-docs-monitoring-endpoints, s-adr-61-meta-quorum-rescue, s-docs-accounts-and-multitenancy, s-nats-server-snapshot-restore, s-docs-advanced-publishing, s-nats-server-monitoring-observed, s-docs-monitoring-advisories-and-events, s-synadia-reliable-delivery-dlq, s-gh-4994-scale-to-zero-dlq, s-gh-7590-dlq-payload-loss]
created: 2026-08-31
updated: 2026-09-01
---

# Advisories and system events

Advisories are the things the server tells you **once, on a subject**, that no poll will ever show
you. A message that exhausted its delivery limit, a stream that lost quorum, a server that ran out
of space — if nothing is subscribed when it happens, you never learn it happened.

**The subjects below are read from the server source at v2.14.6**, not from the docs, because the
docs' own advisory reference disagrees with the server on one of them — see *A docs error*, below.

## JetStream advisories

Every prefix takes a suffix: `.<stream>` for stream events, `.<stream>.<consumer>` for consumer
events. Source: `server/jetstream_api.go` at v2.14.6
([[s-nats-server-constants-2.14.6]]).

### Consumer

| event | subject prefix | line |
|---|---|---|
| **delivery limit exceeded** | `$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES` | 241 |
| **message nak'd** | `$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED` | 244 |
| **message terminated** | `$JS.EVENT.ADVISORY.CONSUMER.MSG_TERMINATED` | 247 |
| consumer created | `$JS.EVENT.ADVISORY.CONSUMER.CREATED` | 259 |
| consumer deleted | `$JS.EVENT.ADVISORY.CONSUMER.DELETED` | 262 |
| consumer paused / resumed | `$JS.EVENT.ADVISORY.CONSUMER.PAUSE` | 265 |
| **priority group pinned** | `$JS.EVENT.ADVISORY.CONSUMER.PINNED` | 268 |
| **priority group unpinned** | `$JS.EVENT.ADVISORY.CONSUMER.UNPINNED` | 271 |
| consumer leader elected | `$JS.EVENT.ADVISORY.CONSUMER.LEADER_ELECTED` | 298 |
| **consumer quorum lost** | `$JS.EVENT.ADVISORY.CONSUMER.QUORUM_LOST` | 301 |

### Stream

| event | subject prefix | line |
|---|---|---|
| stream created | `$JS.EVENT.ADVISORY.STREAM.CREATED` | 250 |
| stream deleted | `$JS.EVENT.ADVISORY.STREAM.DELETED` | 253 |
| stream updated | `$JS.EVENT.ADVISORY.STREAM.UPDATED` | 256 |
| snapshot started | `$JS.EVENT.ADVISORY.STREAM.SNAPSHOT_CREATE` | 274 |
| snapshot complete | `$JS.EVENT.ADVISORY.STREAM.SNAPSHOT_COMPLETE` | 277 |
| restore started | `$JS.EVENT.ADVISORY.STREAM.RESTORE_CREATE` | 280 |
| restore complete | `$JS.EVENT.ADVISORY.STREAM.RESTORE_COMPLETE` | 283 |

(The four snapshot and restore rows are read from the server at v2.14.6, source:
[[s-nats-server-snapshot-restore]]; the operation they trace is [[backup-and-restore-jetstream]].)
| stream leader elected | `$JS.EVENT.ADVISORY.STREAM.LEADER_ELECTED` | 289 |
| **stream quorum lost** | `$JS.EVENT.ADVISORY.STREAM.QUORUM_LOST` | 292 |
| batch abandoned | `$JS.EVENT.ADVISORY.STREAM.BATCH_ABANDONED` | 295 |

**`BATCH_ABANDONED` is the only notice you get for one of the three ways an atomic batch ends.** A
sequence gap or an over-limit batch comes back to the publisher as an error `PubAck`; a batch that
goes **ten seconds without a message** is dropped with **no error reply at all**, and this advisory
is raised instead. So a publisher that only reads `PubAck`s cannot tell a stalled batch from a slow
one — subscribe to the advisory, or treat the committing `PubAck` as the sole proof
(source: [[s-docs-advanced-publishing]]; [[publishing]]).

### Server and API

| event | subject | line |
|---|---|---|
| **server out of storage** | `$JS.EVENT.ADVISORY.SERVER.OUT_OF_STORAGE` | 304 |
| server removed | `$JS.EVENT.ADVISORY.SERVER.REMOVED` | 307 |
| **API limit reached** | `$JS.EVENT.ADVISORY.API.LIMIT_REACHED` | 310 |
| domain leader elected | `$JS.EVENT.ADVISORY.DOMAIN.LEADER_ELECTED` | 286 |
| **API audit** | `$JS.EVENT.ADVISORY.API` | 314 |

The whole space is under **`JSAdvisoryPrefix = "$JS.EVENT.ADVISORY"`** (line 232), so
`$JS.EVENT.ADVISORY.>` subscribes to everything.

## System events

From `raw/nats-docs/reference/system/advisory/` — three documented events, on the **system account**:

| event | schema type |
|---|---|
| client connect | `io.nats.server.advisory.v1.client_connect` |
| client disconnect | `io.nats.server.advisory.v1.client_disconnect` |
| account connections | `io.nats.server.advisory.v1.account_connections` |

Connect and disconnect are published per account on `$SYS.ACCOUNT.<account>.CONNECT` and
`$SYS.ACCOUNT.<account>.DISCONNECT`. Since **2.12** the global account `$G` produces these too
(source: [[nats-server-2.12]]).

Separately, each server publishes a **`STATSZ` heartbeat on `$SYS.SERVER.<id>.STATSZ`** on a fixed
interval, carrying the same kind of summary numbers as `/varz` — **pushed instead of polled**, so a
listener has a steady pulse from every node (source: [[s-docs-monitoring-endpoints]]).

A server also publishes per-account connection counts on
**`$SYS.SERVER.ACCOUNT.<ACCOUNT>.CONNS`**, visible to a system-account user.

**None of this is reachable without a system-account user, and that is easy to lose.** The moment a
config declares its own `accounts` block without naming a `SYS` account, the system account has no
user, "server events are unreachable" and the event tooling stops working — `nats server account
info` included. Declare a `SYS` account, set `system_account`, and give it a user
(source: [[s-docs-accounts-and-multitenancy]]); see [[account]] and [[config-keys]]. To watch them:

```
nats subscribe '$SYS.SERVER.>' --user sys-admin --password syspass
```

### Coming in 2.15: the meta-rescue advisory

Not in 2.14.6. When a server applies an unsafe meta-quorum rescue it logs a `WARN` **and** publishes
`$JS.EVENT.ADVISORY.SERVER.META_RESCUE` (`io.nats.jetstream.advisory.v1.meta_rescue`) carrying
`server`, `server_id`, `prev_quorum`, `new_quorum`, `cluster` and `domain` (the last only when a
domain is configured). It is worth wiring in advance: an advisory is an ordinary published message
and "does not depend on the meta leader", so it arrives while the meta layer has no quorum — the one
moment nothing else about the cluster answers. See [[disaster-recovery]]
(source: [[s-adr-61-meta-quorum-rescue]]).

## A docs error worth knowing

**The docs' own advisory reference gives the nak subject as `$JS.EVENT.ADVISORY.CONSUMER.MSG_NAK`**
(`raw/nats-docs/reference/jetstream/advisory/nak.md`), **and that is wrong.** The server defines:

```go
JSAdvisoryConsumerMsgNakPre = "$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED"
```

— `jetstream_api.go:244` at v2.14.6. The docs' *learn* page
(`learn/jetstream/acknowledgment.md`) says `MSG_NAKED` and agrees with the server; only the
generated reference page disagrees. A subscription written from that reference page **receives
nothing**, silently.

This wiki uses **`MSG_NAKED`**.

**Since 2026-09-01 this is confirmed on the wire, not only from the constant.** A consumer was given a
message, the message was NAK'd, and `nats sub '$JS.EVENT.ADVISORY.>'` received
(source: [[s-nats-server-monitoring-observed]]):

```
$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED.ORDERS.naktest
```

The same run confirmed the max-deliveries subject **does** carry `.CONSUMER.`:

```
$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping
{"type":"io.nats.jetstream.advisory.v1.max_deliver","id":"9lWb25w5SokA1gpeK2wgeB",
 "timestamp":"2026-08-31T22:39:02.825838Z","stream":"ORDERS","consumer":"shipping",
 "stream_seq":1,"deliveries":2}
```

Two things follow. The **hand-written chapter's prose agrees with the server** and its own animation
caption does not — it writes `$JS.EVENT.ADVISORY.MAX_DELIVERIES.ORDERS.shipping`, dropping
`.CONSUMER.`, three times (`inbox/docs-issues.md` **#36**, source:
[[s-docs-monitoring-advisories-and-events]]). And the **advisory body carries `id` and `timestamp`**
beyond the fields the chapter's example shows.

**The chapter does not settle the pinned/unpinned subjects.** It names `nak`, `consumer_action` and
`terminated` as *types* and never writes their subjects, and does not mention pinned or unpinned at
all — so docs issues #2 and #3 still rest on the server alone.

### An advisory subscription is noisier than the examples suggest

`$JS.EVENT.ADVISORY.API` fires for ordinary JetStream API calls. Creating one stream and two consumers
produced **three** `API` advisories before the first interesting one arrived
(source: [[s-nats-server-monitoring-observed]]). A `nats sub '$JS.EVENT.ADVISORY.>'` left running on a
busy cluster is mostly API audit traffic; filter to the subtree you care about, or capture into a
stream and filter on read — the chapter's own remedy:

```
nats stream add ADVISORIES --subjects '$JS.EVENT.ADVISORY.>' \
  --storage file --retention limits --max-age 168h --defaults
```

**Advisories are published once and stored nowhere.** "If no one is subscribed when it fires, you
never learn that order `987` stopped being delivered" — and there is **no dead-letter queue**: the
`max_deliver` advisory "is the only built-in signal that this happened" (source:
[[s-docs-monitoring-advisories-and-events]]). The message itself stays in the stream under its
retention policy; what stops is delivery to that consumer.

## The schema types

Each JetStream advisory carries a `type` of the form
`io.nats.jetstream.advisory.v1.<name>` — the 22 documented ones are `api_audit`,
`api_limit_reached`, `consumer_action`, `consumer_group_pinned`, `consumer_group_unpinned`,
`consumer_leader_elected`, `consumer_pause`, `consumer_quorum_lost`, `domain_leader_elected`,
`max_deliver`, `nak`, `restore_complete`, `restore_create`, `server_out_of_space`, `server_removed`,
`snapshot_complete`, `snapshot_create`, `stream_action`, `stream_batch_abandoned`,
`stream_leader_elected`, `stream_quorum_lost` and `terminated`.

Note that `consumer_action` and `stream_action` are the schema types behind the CREATED / DELETED /
UPDATED subjects — the docs model them as one "action" advisory each, while the server has a
separate subject per action.

## Watching them

```
nats sub '$JS.EVENT.ADVISORY.>'                                       # everything
nats sub '$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping' # one consumer's drops
nats events --js-advisory --no-srv-advisory                           # the CLI's own view
```

## The four to alert on first

Not a ranking from a source — a reading of what the rest of this wiki shows costs real outages:

1. **`MAX_DELIVERIES`** — JetStream has **no dead-letter queue**, so this advisory is the *only*
   notice that a message was dropped after exhausting its attempts. See [[ack-and-redelivery]].
2. **`STREAM.QUORUM_LOST` / `CONSUMER.QUORUM_LOST`** — the group has no majority and cannot elect a
   leader; writes are blocked. See [[raft-in-nats]] and [[replicas]].
3. **`SERVER.OUT_OF_STORAGE`** — the condition [[jetstream-sizing]] says arrives as a publish error
   mid-stream rather than a startup warning. It fires **once**, guarded, and JetStream on that server
   is already shutting down by the time it is published (`jetstream.go:652–678`, source:
   [[s-nats-server-jetstream-resources]]) — so the alert must be on the event, not on a threshold.
   Note that the same handler is reached from the Raft critical-write-error path, so the advisory can
   fire with the disk nearly empty: [[jetstream-out-of-disk]] and [[malformed-or-corrupt-message]].
4. **`API.LIMIT_REACHED`** — the API queue is saturated, which is what
   [[jetstream-slows-as-consumers-grow]] describes from the client side. Its `Dropped` field is the
   count of requests the server **discarded without any reply at all**, which is the sharpest
   server-side cause of [[nats-timeout]] (`jetstream_api.go:876–890`, source:
   [[s-nats-server-jetstream-log-warnings]]).

`LEADER_ELECTED` is worth **logging** rather than alerting: elections are normal
([[raft-in-nats]]), but a stream whose leader keeps moving is a symptom
([[stream-leader-keeps-moving]]).

## Capturing advisories into a stream

Advisories are **published once and stored nowhere**: "if nobody is subscribed when one fires, it is
gone" (source: [[s-synadia-reliable-delivery-dlq]]). Any design that depends on noticing one needs a
stream over the advisory subject, not a subscriber somebody remembers to run.

```
nats stream add DLQ_ADVISORIES \
  --subjects='$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.>' \
  --storage=file --replicas=3
```

That stream is "the index of everything that exhausted its redelivery budget". Because each
max-deliveries advisory carries the source stream and the **stream sequence** of the message that ran
out of attempts, the index is enough to fetch the original with [[direct-get]] and republish it — the
dead-letter pattern, which NATS has no config field for and assembles out of these parts. See
[[ack-and-redelivery]] for what the advisory means and [[retention-policies]] for the race the fetch
runs against.

Two notes for anyone building this:

- **The advisory is a pointer, not a copy.** On `workqueue` or `interest` retention the message it
  names may already be gone; capture the payload at capture time.
- **`$JS.EVENT.ADVISORY.API` fires for ordinary API calls**, so a stream over the whole
  `$JS.EVENT.ADVISORY.>` space is much noisier than one scoped to the subject you care about.


### The max-deliveries advisory carries no payload, and will not

The body is metadata only — the stream, the consumer, the stream sequence and the delivery count:

```json
{"type":"io.nats.jetstream.advisory.v1.max_deliver","id":"TMbth7XzlJOkyzkRhNWQTR",
 "timestamp":"2026-09-01T02:36:13.790078Z","stream":"WQ","consumer":"w",
 "stream_seq":1,"deliveries":2}
```

A request to include the failed message's payload was **considered and resisted**, for a reason worth
recording because it will not change soon (source: [[s-gh-7590-dlq-payload-loss]]):

> "We have considered this before but has quite a lot of user feedback that this is a bad idea due to
> the payloads potentially being sensitive and DLQ advisories going to different locations outside of
> nats. It might be something that would make sense as a per consumer opt in though."
> — @ripienaar, 2025-11-28

**Treat every advisory as an index entry, not a record.** The `stream_seq` is how you reach the
message ([[direct-get]]), and on retention policies that remove acked messages you have to fetch it
promptly — see [[dead-letter-queue]] and [[retention-policies]].

**And the advisory only fires if someone is fetching.** A pull consumer with no client asking for
messages never advances its delivery count, so `max_deliver` is never reached and this advisory is
never published, however long `ack_wait` has elapsed (source: [[s-gh-4994-scale-to-zero-dlq]]). An
alert built on this subject is silent in exactly the situation where a worker pool has died.


## How this was derived

- **The subject prefixes come from `server/jetstream_api.go` at tag v2.14.6**, lines 232–314, quoted
  verbatim in `raw/nats-server-src/constants-v2.14.6.md`. The server is used as the authority in
  preference to the docs because the two disagree (above). To regenerate: re-read the
  `JSAdvisory*Pre` constants at the new tag.
- **The schema type names** come from the 22 files in
  `raw/nats-docs/reference/jetstream/advisory/` and the 3 in `raw/nats-docs/reference/system/advisory/`.
- The `$SYS.ACCOUNT.*` subjects and the `STATSZ` heartbeat come from
  `raw/nats-docs/learn/monitoring/advisories-and-events.md`.

## To verify

- **The per-advisory payload fields are not on this page.** Each of the 25 reference pages carries a
  response schema; none has been ingested field-by-field.
- ~~`learn/monitoring/advisories-and-events.md` not ingested~~ — **done 2026-09-01**
  ([[s-docs-monitoring-advisories-and-events]]). It confirmed the max-deliveries subject and produced
  docs issue #36, and it does **not** state the nak, pinned or unpinned subjects, so it could not
  cross-check #1–#3 by itself.
- **The `$SYS` connect/disconnect and `STATSZ` events have not been captured on the wire.** They need
  a system-account connection; the advisory captures above were made in the application account.

## Related

[[ack-and-redelivery]] · [[monitoring-endpoints]] · [[raft-in-nats]] · [[priority-groups]] ·
[[jetstream-sizing]] · [[jetstream-out-of-disk]] · [[js-api-subjects]] · [[error-codes]] ·
[[malformed-or-corrupt-message]] · [[nats-timeout]] · [[stream-has-high-message-lag]]

## Sources

[[s-nats-server-constants-2.14.6]] · [[s-adr-42-priority-groups]] · [[s-docs-acknowledgment]] ·
[[s-docs-monitoring-endpoints]] · [[s-nats-server-jetstream-resources]] ·
[[s-nats-server-jetstream-log-warnings]] ·
[[s-adr-61-meta-quorum-rescue]] ·
[[s-docs-accounts-and-multitenancy]] · [[s-nats-server-snapshot-restore]] ·
[[s-docs-advanced-publishing]] ·
[[s-nats-server-monitoring-observed]] · [[s-docs-monitoring-advisories-and-events]] · [[s-synadia-reliable-delivery-dlq]] · [[s-gh-4994-scale-to-zero-dlq]] · [[s-gh-7590-dlq-payload-loss]]
