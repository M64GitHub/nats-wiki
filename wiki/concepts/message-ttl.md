---
title: Per-message TTL
type: concept
area: [jetstream, kv]
since: [2.11]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [ttl, Nats-TTL, subject_delete_marker_ttl, tombstone, markers]
aliases: [Nats-TTL, per-message TTL, message TTL, subject delete marker, limit marker]
sources: [s-adr-43-per-message-ttl, s-docs-stream-config, s-adr-8-key-value-store, s-adr-48-kv-ttl, s-docs-kv-ttl-and-limits, s-docs-mirrors-and-sources, s-adr-51-message-scheduler, s-gh-7628-scheduler-vs-nak, s-nats-server-message-schedules-observed, s-docs-jetstream-headers, s-synadia-delayed-scheduling, s-relnotes-2.11]
created: 2026-08-31
updated: 2026-09-03
---

# Per-message TTL

Per-message TTL gives an individual message its own expiry, instead of every message in a
[[stream]] sharing the stream-wide `max_age`. Introduced for **nats-server 2.11**
(source: [[s-adr-43-per-message-ttl]]). It is the mechanism behind KV per-key TTL and KV tombstone
cleanup — the ADR's own motivating case is that *"KV tombstones are a problem in that they forever
clog up the buckets with noise"*.

## How it behaves

The publisher sets a **`Nats-TTL`** header carrying a duration as **seconds or a Go duration
string** (`1h`). The server computes the deadline from the message's **stream timestamp** plus that
duration.

| value | effect |
|---|---|
| a duration ≥ 1 second | the message is removed that long after its stream timestamp |
| **`never`** | the message is **never expired** — and **not removed by the stream's `MaxAge` either** |
| header absent | no per-message TTL applies |
| unparsable, sub-second, or a literal `0` | **an error in the PubAck; the message is discarded** |

Publishing a `Nats-TTL` header to a stream with the feature **disabled rejects the message**.

### The silent clamp

**Unless `MaxMsgsPer` equals 1, the server treats `SubjectDeleteMarkerTTL` as the minimum effective
`Nats-TTL`.** A publish below that floor is **not rejected** — the server **raises the effective TTL
to the floor and rewrites the stored `Nats-TTL` header** to the clamped value, formatted as integer
seconds.

A message you asked to live 5 seconds can therefore live as long as the marker TTL, with nothing in
the PubAck to say so. This is the subtlest behaviour on this page.

## What configures it

```
allow_msg_ttl: true
subject_delete_marker_ttl: 60s
```

| restriction | detail |
|---|---|
| `allow_msg_ttl` | **can be enabled on an existing stream but never disabled** |
| minimum values | both `Nats-TTL` and `subject_delete_marker_ttl` have a **1-second minimum** |
| mirrors | **`subject_delete_marker_ttl` may not be set on a mirror stream** |
| API level | setting either **requires stream API level `1`** |
| `allow_rollup_hdrs` | **must be `true`** — set automatically on create/update unless pedantic mode is on |
| `deny_purge` | **must be `false`** — likewise set automatically outside pedantic mode |

Because `pedantic: true` makes the server apply no defaults and rewrite nothing
(source: [[s-docs-stream-config]]), a pedantic create that sets `subject_delete_marker_ttl` without
also setting `allow_rollup_hdrs` fails where a normal one would have been fixed up.

## Limit markers (tombstones)

When the server removes a message **and it was the last one in its subject**, it can place a marker
message carrying **`Nats-Marker-Reason`** and a **`Nats-TTL` set to the stream's
`subject_delete_marker_ttl`**, formatted as a Go duration string — `1m0s` for a 60-second setting:

```
Nats-Marker-Reason: MaxAge
Nats-TTL: 1m0s
```

**`MaxAge` is the reason for any age-based removal of a subject's last value** — whether the trigger
was the stream-wide `MaxAge` or a per-message `Nats-TTL`. The two are not distinguishable from the
marker.

**Markers are off by default**; `subject_delete_marker_ttl` is the opt-in.

KV enables both fields through a single "Limit Markers" setting whose duration must be **at least
1 second**, accepts a TTL on `Create` and `Purge` **only** — never on `Put`, because expiring a
current value could resurrect an older revision — and can turn markers on for an existing bucket but
not off again (source: [[s-adr-48-kv-ttl]]). KV maps the marker reasons onto its own operations —
`MaxAge` and `Purge` become `PURGE`, `Remove`
becomes `DEL`. See [[key-value]].

### Two marker kinds do not exist yet

The ADR documents markers for the **delete-message API** (`Nats-Marker-Reason: Remove`) and the
**purge-subject API** (`Nats-Marker-Reason: Purge`), each with an explicit admonition:

> **"As of Server version 2.14 this feature is not currently implemented."**

So on 2.14 the only marker the server actually places is the `MaxAge` one. Do not build a
delete-notification path on `Remove` or `Purge` markers.

## Sources and mirrors

Sources and mirrors **always accept and store** messages carrying `Nats-TTL`, even when
`allow_msg_ttl` is disabled — with the setting off they are simply stored and never expire. That is
deliberate: it lets a replication topology keep an audit trail of messages that would have been
TTLed upstream.

**Sources may set `subject_delete_marker_ttl`; mirrors may not** — inserting new messages into a
mirror would make it impossible to match sequences against the mirrored stream. That reason rests on
the mirror contract itself: a mirrored message "keeps the **same sequence number, the same timestamp,
and the same subject** it had upstream", while a sourced stream gives its messages "**fresh sequence
numbers** as they arrive" (source: [[s-docs-mirrors-and-sources]]). The same contract explains the
audit-trail behaviour above — **a mirror keeps its own retention**, so the upstream may keep seven
days while the mirror keeps forever, and a message the upstream would have expired simply does not
expire in the copy.

## Error codes

| rejection path | `err_code` | description |
|---|---:|---|
| `Nats-TTL` published to a stream with `allow_msg_ttl: false` | **10166** | `per-message TTL is disabled` |
| `Nats-TTL` unparsable, sub-second, or literal `0` | **10165** | `invalid per-message TTL` |
| `subject_delete_marker_ttl` below `1s` | **10052** | `subject delete marker TTL must be at least 1 second` |
| `subject_delete_marker_ttl` on a mirror | **10052** | `subject delete markers forbidden on mirrors` |
| `subject_delete_marker_ttl` with `allow_rollup_hdrs: false`, pedantic mode | **10052** | `subject delete marker cannot be set if roll-ups are disabled` |
| `subject_delete_marker_ttl` with `allow_rollup_hdrs: true` and `deny_purge: true` | **10052** | `roll-ups require the purge permission` |
| update setting `allow_msg_ttl: false` after it was `true` | **10052** | `message TTL status can not be disabled` |

All the `10052` responses are `JSStreamInvalidConfigF` and share one shape, with the reason in the
description field — which is exactly the case ADR-7 warns not to match on as text. See
[[error-codes]] and [[js-api]].

## The message scheduler is built on this

**[[message-scheduling]] is not a separate subsystem — it is this machinery pointed at a different
job.** A maintainer says so when asked whether the scheduler will hold 100K+ pending schedules: "It
should support a very large amount of schedules since it's **built on top of the per-message TTL
work** which similarly also supports a very large amount" (source: [[s-gh-7628-scheduler-vs-nak]]).

Two consequences an operator meets directly:

- **`Nats-Schedule-TTL` needs `allow_msg_ttl` on the stream**, and without it the publish fails with
  `10166 per-message TTL is disabled` — a *TTL* error on what looks like a *scheduling* feature
  (observed at v2.14.6, source: [[s-nats-server-message-schedules-observed]]). It sets `Nats-TTL` on
  the **generated** message, not on the schedule; the docs' header table says the opposite
  (source: [[s-docs-jetstream-headers]], `inbox/docs-issues.md` #41).
- **A `Nats-TTL` on the schedule message itself is the recommended way to stop a stale schedule from
  firing after downtime.** A past-dated schedule fires the moment the server recovers it — "even if it
  was schedule for a month ago, it will be sent immediately" — and a TTL is what removes it first
  (source: [[s-adr-51-message-scheduler]]).

A `Nats-Schedule-TTL` below this page's own TTL floor, or one that does not parse, is rejected with
`10191` rather than clamped.


### `allow_msg_ttl` is not implied by `allow_msg_schedules`

They are two flags and enabling the scheduler does not enable this one: a schedule carrying
`Nats-Schedule-TTL` on a stream with only `allow_msg_schedules` fails with **`10166 per-message TTL is
disabled`** — a TTL error raised by what looks like a scheduling feature (source:
[[s-synadia-delayed-scheduling]], confirmed at v2.14.6). Set both, or drop the header.


## Version notes: the 2.11 patches

Per-message TTL shipped in **2.11.0** — "`Nats-TTL` header, provided either as a string duration
(`1m`, `30s`) or an integer in seconds" (#6272, #6354, #6363, #6370, #6376, #6385, #6400) — with
**subject delete markers on `MaxAge`** (`SubjectDeleteMarkerTTL`, the `Nats-Marker-Reason` header;
#6378 … #6432) (source: [[s-relnotes-2.11]]). Then, release by release:

- **2.11.2**: markers "are now placed for messages that have aged out due to their TTL and not just
  because of the `MaxAge` policy" (#6741); a per-message TTL may be **lower than the marker TTL**
  when `max_msgs_per_subject` is 1 (#6818); TTL state recovered from disk after loss or corruption
  (#6758); tombstones written for TTL expiry so the deletion survives a rebuild (#6781); a message
  rejected for an invalid TTL is not put in the deduplication map (#6725); markers have the right
  headers through direct get (#6826).
- **2.11.5**: "Updating the `AllowMsgTTL` setting on a stream will now take effect correctly"
  (#6922).
- **2.11.7**: **enabling TTLs on a stream scans existing messages** with a `Nats-TTL` header
  (#7117); TTLs **over an hour** "could take double the expected time" before #7070; a KV purge with
  markers no longer leaves a redundant extra marker (#7026).
- **2.11.9**: the `Nats-TTL` header is correct when the marker TTL overwrites it (#7177).
- **2.11.10**: removed messages leave the TTL state immediately; expiry starts as expected after a
  restart with markers enabled; no leaked timers (#7344).
- **2.11.11**: `sync_always` honoured for the TTL and scheduling state files (#7385).


## To verify

- The server-side **default** for `subject_delete_marker_ttl` (as opposed to its 1-second minimum)
  is not stated; the `StreamConfig` schema lists the field with no default
  (source: [[s-docs-stream-config]]).

## The KV spelling, and the default that is still missing

On a [[key-value]] bucket the same two stream fields are set by one CLI flag:

```
nats kv add   CACHE     --marker-ttl 1h
nats kv edit  INVENTORY --marker-ttl 1h
```

`--marker-ttl` is `subject_delete_marker_ttl`, and the docs describe the duration as "how long the
bucket keeps the expiry marker" (source: [[s-docs-kv-ttl-and-limits]]). **That page always passes the
value explicitly and never states a server-side default** — so the open item below survives a second
source. A per-key TTL then rides on it, and requires **2.11 or newer**: on an older server "enabling
markers on the bucket is rejected, and the timed create fails with it."

A KV watcher sees an expiry as a **`PURGE` operation**, indistinguishable from a hand purge except by
the marker's `MaxAge` reason ([[key-value]]).

## Related

[[stream]] · [[key-value]] · [[retention-policies]] · [[error-codes]] · [[js-api]] ·
[[mirrors-and-sources]]

## Sources

[[s-adr-43-per-message-ttl]] · [[s-docs-stream-config]] · [[s-adr-8-key-value-store]] ·
[[s-adr-48-kv-ttl]] · [[s-docs-kv-ttl-and-limits]] ·
[[s-docs-mirrors-and-sources]] · [[s-adr-51-message-scheduler]] · [[s-gh-7628-scheduler-vs-nak]] · [[s-nats-server-message-schedules-observed]] · [[s-docs-jetstream-headers]] · [[s-synadia-delayed-scheduling]] · [[s-relnotes-2.11]]
