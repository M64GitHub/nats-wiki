---
title: Advisories and system events
type: reference
area: [monitoring, jetstream, core]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [advisories, events, "$JS.EVENT.ADVISORY", "$SYS", monitoring]
aliases: [advisories, "$JS.EVENT.ADVISORY", system events, jetstream advisories]
sources: [s-nats-server-jetstream-resources, s-nats-server-jetstream-log-warnings, s-nats-server-constants-2.14.6, s-adr-42-priority-groups, s-docs-acknowledgment, s-docs-monitoring-endpoints, s-adr-61-meta-quorum-rescue, s-docs-accounts-and-multitenancy, s-nats-server-snapshot-restore]
created: 2026-08-31
updated: 2026-08-31
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
- `learn/monitoring/advisories-and-events.md` has been read only for the `$SYS` subjects and the
  `STATSZ` heartbeat, **not ingested as a summary** — it is the obvious next monitoring source.

## Related

[[ack-and-redelivery]] · [[monitoring-endpoints]] · [[raft-in-nats]] · [[priority-groups]] ·
[[jetstream-sizing]] · [[jetstream-out-of-disk]] · [[js-api-subjects]] · [[error-codes]] ·
[[malformed-or-corrupt-message]] · [[nats-timeout]] · [[stream-has-high-message-lag]]

## Sources

[[s-nats-server-constants-2.14.6]] · [[s-adr-42-priority-groups]] · [[s-docs-acknowledgment]] ·
[[s-docs-monitoring-endpoints]] · [[s-nats-server-jetstream-resources]] ·
[[s-nats-server-jetstream-log-warnings]] ·
[[s-adr-61-meta-quorum-rescue]] ·
[[s-docs-accounts-and-multitenancy]] · [[s-nats-server-snapshot-restore]]
