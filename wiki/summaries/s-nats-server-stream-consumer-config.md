---
title: "nats-server v2.14.6 — StreamConfig and ConsumerConfig, from the source"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/stream-consumer-config-v2.14.6.md
author: nats-io/nats-server maintainers
article: "server/stream.go, consumer.go, jetstream.go, jetstream_api.go, jetstream_cluster.go, opts.go at tag v2.14.6 — the two config structs, the defaults the server fills in, the validation, the update rules"
date: 2026-08-27          # v2.14.6 publish date
version: "2.14.6"
tags: [stream-config, consumer-config, defaults, mutability, source]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.14.6 — `StreamConfig` and `ConsumerConfig`, from the source

Read for [[stream-and-consumer-config]]: the 38 stream fields and 35 consumer fields with their JSON
tags, what the server fills in when a field is left at zero, what it refuses at creation, and — the
part no docs page states — what an update may change. The behavioural half is
[[s-nats-server-config-mutability-observed]].

## Key claims

**The stream defaults** (`checkStreamCfg`, `stream.go:1660–1760`): `storage` → `file`; `num_replicas`
→ 1 (max `StreamMaxReplicas` = 5, `:716`); `max_msgs`, `max_msgs_per_subject`, `max_bytes`,
`max_msg_size`, `max_consumers` → -1 when 0 or below -1; `max_age` must be 0 or ≥ 100 ms;
`duplicate_window` → 2 m (`StreamDefaultDuplicatesWindow`, `:1658`) **only when the stream is neither a
mirror nor sourcing**, clamped to the server's `max_duplicate_window` limit and to `max_age`; in
**pedantic mode every silent correction is an error** (`JSPedanticErrF`, 10157). Name ≤ 255
(`JSMaxNameLen`), description ≤ 4096, metadata ≤ 128 KB (`jetstream_api.go:355–363`). The exclusions
(`:1783–1852`): roll-ups need purge (`roll-ups require the purge permission`), a counter stream cannot
use `discard: new`, message TTLs, schedules or any retention but `limits`; `discard_new_per_subject`
needs `discard: new` and `max_msgs_per_subject > 0`; `subject_delete_marker_ttl` ≥ 1 s and needs
`allow_msg_ttl` and roll-ups; schedules need roll-ups and not `discard: new`; `persist_mode: async`
needs file storage, R1 and no atomic batches; markers are forbidden on mirrors (`:1928`); a subject
that captures `>` or overlaps `$JS.API` / `$SYS` needs `no_ack` (`:2173–2192`), and `>` also R1.

**What a stream update may change** (`configUpdateCheck`, `stream.go:2300–2437`): refused —
`name`, `storage`, `retention` to or from `workqueue`, unsealing, cancelling `deny_delete` or
`deny_purge`, a changed `mirror` (**removing it is allowed** — promotion), disabling `allow_msg_ttl`,
changing `allow_msg_counter`, disabling `allow_msg_schedules`, changing `persist_mode`, `num_replicas > 1`
on a standalone server (10074). Allowed — everything else, including `retention` between `limits` and
`interest`, `num_replicas`, `max_consumers`, `compression`, `subjects`, `sources`, limits, `discard`,
the `allow_*` flags one way. Sealing forces `max_age: 0`, `discard: new`, `deny_delete`, `deny_purge`
and drops `allow_rollup_hdrs` (`:2371–2377`); a `max_bytes` change is checked against the account
reservation as a difference (`:2380–2436`). After the check, `updateWithAdvisory` re-validates every
consumer against a changed `consumer_limits` (`:2448–2475`).

**The consumer defaults** (`setConsumerConfigDefaults`, `consumer.go:587–704`; constants `:570–586`):
`max_deliver` → -1; `max_waiting` → 512 (`JSWaitQueueDefaultMax`, `jetstream_api.go:705`) for pull
consumers; `ack_wait` → 30 s for `explicit` and `all` (**not for `none`**); a `backoff` overwrites
`ack_wait` with its first entry (pedantic: refused unless equal); `max_ack_pending` → the stream's
`consumer_limits.max_ack_pending`, else 1000 (`JsDefaultMaxAckPending`) clamped down by the server and
account `max_ack_pending`; `inactive_threshold` → the stream's limit, else **5 s for ephemerals**
(`JsDeleteWaitTimeDefault`, applied at `:1473–1483` with up to a second of jitter); `max_batch` → the
server's `max_request_batch`; `priority_timeout` → 2 m for `pinned_client`; flow-control pending → 32 MB.
The zero `ack_policy` is `none` (`AckNone … = iota`, `:335`), `deliver_policy` `all`, `replay_policy`
`instant`, `priority_policy` `none`.

**The consumer validation** (`checkConsumerCfg`, `:705–1000`): replicas ≤ the stream's and equal to
it for memory or workqueue; `backoff` entries positive and `max_deliver > len(backoff)` (10116);
`AckFlowControl` needs push, flow control, `max_ack_pending`, no `ack_wait`, no `max_deliver`
(10218–10222); push: no wildcards or cycles in `deliver_subject`, no `max_waiting` (10080),
`max_ack_pending` needs an ack policy (10082), heartbeat ≥ 100 ms (10083); pull: explicit ack on a
workqueue stream (10084), no `rate_limit_bps` (10086), no heartbeat or flow control (10088, 10089),
`max_batch` ≤ the server limit (10114); `max_ack_pending` ≤ server, account and stream limits (10121);
`inactive_threshold` ≤ the stream limit; `direct` needs push and ephemeral (10090, 10091); filters
neither duplicated nor overlapping nor both forms at once (ADR-34's 10134 / 10136); the start
sequence/time must match the deliver policy (10094); `sample_freq` parses; flow control needs
heartbeats; `durable_name` and `name`, if both given, equal; metadata ≤ 128 KB (10135); priority
groups not on push (10178), a policy needs groups and vice versa, group names 1–16 chars of
`A-Z a-z 0-9 -_/=` (10162).

**What a consumer update may change** (`checkNewConsumerConfig`, `:2481–2549`): refused —
`deliver_policy`, `mem_storage`, `direct`, `sourcing`, `opt_start_seq`, `opt_start_time`, `ack_policy`,
`replay_policy`, `idle_heartbeat`, `flow_control`, pull ↔ push, `max_waiting`, and a `backoff` longer
than `max_deliver`. `updateConfig` (`:2551–2705`) then applies `description`, `ack_wait` (re-arming the
pending timer), `max_deliver`, `backoff`, `filter_subject` / `filter_subjects`, `rate_limit_bps`,
`sample_freq`, `max_ack_pending` (shrinking it stalls delivery until acks catch up), `headers_only`,
`max_batch`, `max_expires`, `max_bytes`, `deliver_subject` (push only), `inactive_threshold`,
`num_replicas`, `metadata`, `pause_until`, `priority_groups`, `priority_policy`, `priority_timeout`.

**The limits that clamp a consumer**: server `jetstream { limits { max_request_batch,
max_ack_pending, max_ha_assets, max_duplicate_window, max_batch_inflight_per_stream,
max_batch_inflight_total, max_batch_size, max_batch_timeout } }` (`JSLimitOpts`, `opts.go:375–384`);
account `max_ack_pending` beside `max_memory`, `max_storage`, `max_streams`, `max_consumers`,
`memory_max_stream_bytes`, `storage_max_stream_bytes`, `max_bytes_required`
(`JetStreamAccountLimits`, `jetstream.go:71–80`); stream `consumer_limits { inactive_threshold,
max_ack_pending }` (`stream.go:168–171`). **The batch defaults** (`stream.go:446–455`): timeout 10 s;
atomic batches 50 in flight per stream, 1000 in total, 1000 messages each; fast batches 1000 per
stream, 50,000 in total — the numbers `learn/jetstream/advanced-publishing.md` states.

**Where a message's timestamp comes from** (row 140): `processJetStreamMsg` stamps
`time.Now().UnixNano()` **on the leader** when the incoming `ts` is zero (`stream.go:6929–6931`;
`:7486` for an atomic batch) and the value travels in the Raft proposal, so every replica stores the
leader's clock and a follower's clock never enters a message.

**Request bodies**: `JSApiStreamInfoRequest` has `deleted_details` and `subjects_filter`
(`jetstream_api.go:437–447`); `JSApiConsumerGetNextRequest` has `expires`, `batch`, `max_bytes`,
`no_wait`, `idle_heartbeat` — **no ceiling on `batch`** in the struct; the only checks are the
consumer's `max_batch` and the server's `max_request_batch` (`consumer.go:834–835`).

## Practical takeaways

- Decide `storage`, `retention: workqueue`, `persist_mode`, `allow_msg_counter` and a `mirror` at
  creation; everything else can follow.
- A consumer's `ack_policy`, `deliver_policy`, `replay_policy`, pull/push and `max_waiting` are
  forever; delete and recreate to change them.
- `ack_wait` applies only to `explicit` and `all`; an ephemeral with `ack_policy: none` has none.

## Notable quotes

- "Can only change retention from limits to interest or back, not to/from work queue for now." —
  `stream.go:2318`.
- "We will allow removing the mirror config to 'promote' the mirror to a normal stream." — `:2337`.

## Relevance to the wiki

The authority behind [[stream-and-consumer-config]]; completes *What you cannot change later* on
[[stream]] and *What configures it* on [[consumer]]; settles row 140.

## Questions it answers

Rows 140, 164; 15–17, 21, 28, 71, 88, 116, 151, 160 in part.

## Pages touched

[[stream-and-consumer-config]] · [[stream]] · [[consumer]] · [[defaults-and-limits]] · [[config-keys]] · [[publishing]]
