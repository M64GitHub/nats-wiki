---
title: nats-server 2.14
type: entity
kind: release
area: [deploy, jetstream, topology]
since: [2.14]
verified-against: nats-server 2.14.6
verified-on: 2026-09-03
tags: [release, 2.14, feature_flags, js_ack_fc_v2]
aliases: ["2.14", v2.14, v2.14.0, v2.14.6]
sources: [s-issue-8322-dynamic-maxstore-shrinks, s-nats-server-jetstream-resources, s-relnotes-2.14.0, s-docs-upgrade-to-2.14, s-adr-60-reliable-sourcing, s-docs-advanced-publishing, s-adr-51-message-scheduler, s-gh-7672-cron-schedules, s-relnotes-2.14.4, s-gh-8417-kv-mirror-file-vs-memory, s-nats-server-filestore-recovery, s-relnotes-2.14.1, s-relnotes-2.12, s-relnotes-2.14, s-relnotes-2.15-preview]
created: 2026-08-31
updated: 2026-09-03
---

# nats-server 2.14

The current stable minor. **2.14 is the direct successor of 2.12 — there is no 2.13.**

## Facts

| | |
|---|---|
| first release | **v2.14.0**, 2026-04-30 |
| latest release | **v2.14.6**, 2026-08-27 |
| releases in this line | 15 tags, from `v2.14.0-RC.1` (2026-04-16) |
| built with | Go 1.26.2 (v2.14.0) → Go 1.26.7 (v2.14.6) |
| upgrades from | **2.12.x** — 2.13 was skipped |
| license | Apache-2.0 |

Dates and tags are from the GitHub releases API, mirrored at
`raw/release-notes/_tags-and-dates.md` (291 tags, fetched 2026-08-31).

## What it adds

**Streams**

- **`AllowBatchPublish`** — fast, flow-controlled batch ingest, replicated or not, with per-message
  consistency checks and no intermediate staging (ADR-50).

  The operator-facing half is the **gap policy**, chosen per batch: `gap: fail` abandons the batch at
  the first missing message so what is stored has no holes, and `gap: ok` reports the gap and keeps
  going — **losing data by design**, which is fine for metrics and not for the chunks of an object
  ([[object-store]]). The mode also has no stable publisher in most clients yet: the CLI reaches it
  only through `nats bench js pub fast`, and Go, Rust and JavaScript through [[orbit]]
  (source: [[s-docs-advanced-publishing]]; [[publishing]]).
- **`AllowMsgSchedules` grows recurring schedules** — the `Nats-Schedule` header takes
  `@every 5m`, `@hourly` or crontab syntax — plus **subject sampling** (`Nats-Schedule-Source`) and
  **scheduled rollups** (`Nats-Schedule-Rollup`) (ADR-51).
- **Sourcing and mirroring from WorkQueue and Interest streams** — see [[retention-policies]].
- Sourcing streams can **disable deduplication** (#7651). The guide adds that a sourcing stream "can
  deduplicate when fanning in multiple sources"; **no release body says so** — kept as the guide's
  claim (source: [[s-relnotes-2.14]]).
- **End-of-batch commit** — `Nats-Batch-Commit: eob` commits an atomic batch, and that final
  message is **not persisted**.
- **Rollups are allowed at the `discard_new_per_subject` limit.**

**Consumers**

- **Consumer reset API** — **`$JS.API.CONSUMER.RESET.<stream>.<consumer>`** resets delivery state to
  the acknowledgement floor or an arbitrary sequence, **without deleting and recreating** the
  consumer. The resulting state equals a delete-and-recreate at that sequence (ADR-60).
- New ack policy **`AckFlowControl`**, used by the durable consumers that back WorkQueue/Interest
  sourcing — visible as `JS_MIRROR_<suffix>` / `JS_SRC_<suffix>` on the upstream, and requiring
  **API level 4** there, so a half-upgraded cluster does not get the reliable path (ADR-60, source:
  [[s-adr-60-reliable-sourcing]] · [[s-docs-advanced-publishing]]).
- **`404 No Messages` is now returned for a `no_wait` pull with no expiry** when nothing is pending.
- **Invalid or divergent consumer state is reset to match the stream** on startup after an unclean
  shutdown.

**Operations**

- **`feature_flags`** in the server config, to opt in or out of specific changes before they become
  default (ADR-53).
- **Leafnode remotes can be added and removed by config reload**, no restart; new
  **`ignore_discovered_servers`** option for leafnode remotes.
- **Filestore I/O errors are surfaced** — see below.
- **Raft overrun protection** — see [[raft-in-nats]].
- **Asynchronous stream state snapshots for replicated streams**, "particularly impactful in cases
  where the stream has a large number of interior deletes".
- **Info APIs are deprioritised**: account info, stream info, stream list, consumer info and
  consumer list are queued separately, below create-update-delete operations.
- `traceparent` is no longer modified by message tracing; **`Nats-Trace-Dest: trace disabled`**
  disables all server tracing.

## What an operator must plan for

### The `$JS.ACK` v2 deadline is 2.15

2.14 supports **both** ack / flow-control subject formats, and **v1 remains the default**:

```
v1: $JS.ACK.<stream>.<consumer>.<num delivered>.<stream seq>.<consumer seq>.<timestamp>.<num pending>
v2: $JS.ACK.<domain>.<account hash>.<stream>.<consumer>.<num delivered>.<stream seq>.<consumer seq>.<timestamp>.<num pending>
```

**In 2.15 the default becomes v2** — the maintainers' stated intent; at the `v2.15.0-preview.1` tag
the flag still defaults to `false` ([[s-relnotes-2.15-preview]]). Anyone with account imports/exports or subject permissions
naming `$JS.ACK.<stream>.>` or `$JS.FC.<stream>.>` — or anything more granular — **must update those
ACLs before 2.15**. Catch-all `$JS.ACK.>` / `$JS.FC.>`, and single-account JetStream deployments
with no such rules, need no change.

Test it early:

```
feature_flags {
  js_ack_fc_v2: true
}
```

Omitting the flag means "server default" (v1 on 2.14); `false` uses v1 while still supporting v2.
See [[nats-server-2.15-preview]].

### A filestore I/O error now freezes a stream

Previously not all filestore I/O errors were handled and the stream kept running. In 2.14 an
affected stream **freezes, logs the error, and reports unhealthy in the health check**. Other
streams on the server are unaffected and NATS core traffic keeps flowing, but **the server requires
a restart to recover**. The health check error message contains **`write error`** plus the
underlying error. On a replicated stream another replica picks up the work transparently.

This is a new alerting condition: a healthy server with one dead stream.

### Raft nodes refuse to start on a bad snapshot

A Raft node **will no longer start if its snapshot is missing or corrupt, or if the snapshot does
not align with the remaining log on disk** — deliberately, "avoiding potential data loss". A node
that fails to come back after an unclean shutdown may be doing this on purpose.

### v2.14.6 stops the dynamic `max_file_store` shrinking at every restart

Read from the source rather than from a release note. Before 2.14.6, an unset `max_file_store` was
recomputed at every startup as 75% of what was *free* under `store_dir`, so the ceiling fell as
JetStream filled the volume until a stream that had been legal could no longer be restored —
`insufficient storage resources available (10047)` on a restart with no configuration change.

**PR [#8503](https://github.com/nats-io/nats-server/pull/8503)** (merged 2026-08-24, closing issue
#8322) adds `finalizeDynamicMaxStore`, which waits for file-based streams to recover and then adds
the recovered bytes back into the limit, scaled the same way; the limit is marked provisional until
then. The function is **absent from v2.14.5 and every earlier release and present in v2.14.6**
(sources: [[s-issue-8322-dynamic-maxstore-shrinks]], [[s-nats-server-jetstream-resources]]).

It does not change the advice: the maintainers say to pin `max_file_store` explicitly in production,
and the value is still computed only at startup. See [[jetstream-out-of-disk]].

### Rolling upgrade and downgrade

This warning is **expected** while a cluster is mixed-version, and clears once every server is on
the same version:

```
[WRN] Invalid JetStream request '$G > $JS.API.CONSUMER.CREATE.O': json: unknown field "sourcing"
```

An upgraded server tried the new-style sourcing consumer against an older peer; it retries
automatically with the old style.

**Downgrading:** remove `feature_flags` from the config first — older servers do not recognise the
field. WorkQueue/Interest sourcing started on 2.14 will appear to work but fall back to the less
reliable ephemeral consumer mode, and **durable consumers created with `AckFlowControl` are marked
"offline" and unusable until upgraded back to 2.14**.

## What the scheduler gained here, in detail

2.12 shipped only single delayed messages; **2.14 is where the rest of ADR-51 landed** — and it is the
release a cron schedule requires (source: [[s-gh-7672-cron-schedules]], [[nats-server-2.12]]).
Verified on **v2.14.6** (source: [[s-nats-server-message-schedules-observed]]):

- **Six-field cron**, seconds first — `0 */5 * * * *`. A five-field expression is rejected.
- **`@every <duration>`**, minimum `1s`, plus `@yearly` / `@monthly` / `@weekly` / `@daily` /
  `@hourly`.
- **`Nats-Schedule-Time-Zone`** (revision 3), cron-only, taking IANA names, `UTC` or `Local` — and
  requiring **tzdata on the host**, or the schedule is refused as an invalid pattern. Fixed offsets
  are rejected with `10223`.
- **`Nats-Schedule-Source`** — subject sampling: publish the last message on another subject rather
  than the schedule's own body.
- **`Nats-Schedule-Rollup`** (revision 4) and the atomic **stop-a-schedule** protocol
  (`Nats-Schedule-Next: purge` with `Nats-Scheduler`), whose `10212` guard exists so a cancellation is
  not rolled up together with the schedule it cancels.
- **Discard New is refused** with schedules (ADR-51 revision 8) — enforced at 2.14.6 although the ADR
  still records that revision's server version as `TBD`.

See [[message-scheduling]] for the whole feature and the ten error codes it can return.


## The patch releases, for mirrors and sparse streams

The six patch bodies are in `raw/release-notes/v2.14.1.md` … `v2.14.6.md` (fetched 2026-09-02;
read whole in [[s-relnotes-2.14]]). The lines that decide which patch an operator of mirrors or KV buckets
with a hot key space wants (source: [[s-relnotes-2.14.4]]):

| release | date | what changed |
|---|---|---|
| v2.14.1 | 2026-05-20 | mirror consumers retried immediately on a last-sequence mismatch (#8152); skip-message errors surfaced (#8152); no source-consumer "setup storms" (#8111) |
| v2.14.2 | 2026-06-02 | per-subject state's last block stored correctly with `max_msgs_per_subject: 1` (#8254); no block-skip check on streams with extremely high subject counts (#8227) |
| v2.14.4 | 2026-07-30 | delete-map lookups on file streams with many interior deletes faster and holding locks for less time (#8403); faster AVL sequence sets (#8406); snapshot buffers sized up front (#8405); `max_concurrent_io` in `jetstream {}` (default 4096 slots, #8336); four security fixes (`no_auth_user` with auth callout, whitespace-only JWT permissions, queue-subscription permission checks, `verify_and_map` with blank passwords) |
| v2.14.6 | 2026-08-27 | the dynamic `max_file_store` fix above |

The public report of a KV mirror reading 65× slower on file storage ran on v2.14.2
([[s-gh-8417-kv-mirror-file-vs-memory]]); the maintainer's answer was the consumer's filter, not the
release, and the 6.5× re-measured on v2.14.6 shows the heuristic survived 2.14.4 —
[[consumer-slow-on-a-sparse-stream]].


## The patch releases, for very large subject spaces

**v2.14.2** (2026-06-02, also v2.12.10): "The filestore no longer performs a block skip check on
streams with extremely high subject counts, as it could result in runaway CPU usage (#8227)". The
block skip intersects the whole per-subject index on every filtered read to jump past blocks that
cannot match; the PR's benchmark had it at 173 µs with 1,000 subjects and 184 ms with 2,000,000. Since
this release the server does not attempt it above `highCardinalityThreshold` — 1,000,000 subjects,
the same constant that already switched off the periodic `index.db` — and walks forward block by
block instead ([[filestore-layout]], [[consumer-slow-on-a-sparse-stream]]). **v2.14.4** (2026-07-30):
blocks with an unsynced or truncated key file are removed and counted as lost data instead of
failing the whole recovery (#8365), and `max_concurrent_io` bounds the recovery task queue. **v2.14.0**
recovers from a partial purge after a hard kill (#7676). Nothing in 2.14 touches the source scan a
sourcing stream makes at every start; that is 2.15 ([[nats-server-2.15-preview]],
[[jetstream-recovery-is-slow]]; source: [[s-nats-server-filestore-recovery]]).


## The patch releases, for consumers

**2.14.1 (2026-05-20)** is where the consumer accounting of 2.14.0 was corrected: "A number of paths
that could leave consumer redelivered in a drifted state have been fixed, e.g. with workqueue or
interest-based streams with `max_deliver`, on single message removal or after purges/compactions
(#8102)"; "Consumer file stores will now correctly flush when deleting a single redelivery, avoiding
unexpected further redeliveries (#8168)"; "Pending state no longer leaks when reaching max deliveries
(#8156)"; the delivery policy on clustered workqueue streams enforced (#8126); consumers with
`inactive_threshold` no longer losing local state when the metalayer clean-up proposal fails (#8198).
The same release adds the `/varz` client-only counters `in_client_msgs`, `in_client_bytes`,
`out_client_msgs`, `out_client_bytes` (#7851) and computes num pending only on consumer leaders
(#8172) (source: [[s-relnotes-2.14.1]]). Symptom page: [[consumer-keeps-redelivering]].


## The 2.12 twins of the 2.14 patches

From 2.12.9 (2026-05-20) the 2.12 line ships the 2.14 patches under its own numbers on the same
days: 2.12.9 = 2.14.1, 2.12.10 = 2.14.2, 2.12.12 = 2.14.3, 2.12.14 = 2.14.4, 2.12.15 = 2.14.5. One
2.12 hazard has no 2.14 twin — the 2.12.7 → 2.12.11 stale-subject-state regression, whose body says
"v2.14.x versions are not affected" — and one 2.14 item has no 2.12 twin: 2.14.6 (source:
[[s-relnotes-2.12]]).


## The seven releases, from the bodies

Read end to end as one changelog in [[s-relnotes-2.14]]; the per-topic patch tables above stay as the
short form. Five patches are same-day twins of a 2.12 patch; 2.14.6 has none.

| release | date | Go | 2.12 twin | what an operator needs from it |
|---|---|---|---|---|
| v2.14.0 | 2026-04-30 | 1.26.2 | — | the feature release above; also `404 No Messages` on a `no_wait` pull with no expiry (#7466), divergent consumer state reset on startup (#7692), info APIs deprioritised (#7898), MQTT retained subjects may not contain `0x7F` (#8071), rollups allowed at `discard_new_per_subject` (#7974), `ignore_discovered_servers` (#8067) |
| v2.14.1 | 2026-05-20 | 1.26.3 | 2.12.9 | the consumer-accounting fixes (#8102, #8156, #8168, #8126, #8198); `in_client_*` in `/varz` (#7851); pending only on consumer leaders (#8172); Raft ignores temporary snapshots after a crash (#8101); encryption-mode conversion no longer corrupts blocks (#8105, #8166); TLS with the PROXY protocol (#8130); DNS-SAN-only client certificates accepted (#8100) |
| v2.14.2 | 2026-06-02 | 1.26.3 | 2.12.10 | `$JS.ACK` rewrite and compressed-WebSocket corruptions (#8242, #8244); the block-skip check off above a million subjects (#8227); quorum with multi-IP gateway URLs (#8238); `max_msgs_per_subject: 1` last block (#8254); peer-set drift after removing an online node (#8258) |
| v2.14.3 | 2026-06-29 | 1.26.4 | 2.12.12 | **JSONP removed** from monitoring; the security batch without CVE ids (MQTT pre-auth memory, `PUBLISH` underflow, `$MQTT.deliver.pubrel`, deny rules on replay, `CONNZ`/`SUBSZ` overflow, `NoAuthUser` restrictions, leaf `Nats-Trace-Dest`); **counter running total (#8311) and compressed/encrypted compaction (#8312) corruptions**; Raft stops voting after write errors (#8290); service-import replies across routes (#8317) |
| v2.14.4 | 2026-07-30 | 1.26.5 | 2.12.14 | `max_concurrent_io` and the 4096-slot semaphore (#8336); the interior-delete work (#8403, #8405, #8406, #8412); **the `verify_and_map` blank-password bypass** and the `no_auth_user` + auth-callout bypass; malformed replicated entries rejected; term on Raft proposals (#8370); votes from removed peers ignored (#8353); unsynced key files counted as lost data (#8365); MQTT packet ids from a monotonic counter (#8358) |
| v2.14.5 | 2026-08-12 | 1.26.5 | 2.12.15 | **`leafnodes { dial_timeout }`** and per remote (#8427); **the idempotent-create data-loss fix** (#8449); a logger deadlock (#8430) |
| v2.14.6 | 2026-08-27 | 1.26.7 | — | the reservation ratchet (#8503); **replicated consumers stuck after a leader change (#8488)**; **a consumer create destroying an existing consumer's state (#8491)**; stale snapshot / stalled catch-up / bounded append-entry cache (#8501); stream reads under their own lock, faster direct gets (#8486); inline compaction honours `sync_interval: always` (#8475); R > 1 updates rejected non-clustered (#8464); routes missing after a reconnect (#8527); `AckFlowControl` acking outside the filter (#8431, #8528); consumer tiers distinguished for limits (#8484) |

## Which patch to be on

- **Below 2.14.1, nothing**: 2.14.0's consumer accounting could drift and redeliver acked messages
  ([[consumer-keeps-redelivering]]).
- **2.14.3 or later** if any stream uses counters, `compression` or encryption (#8311, #8312), and
  for the security batch.
- **2.14.4 or later** if `tls { verify_and_map }` is on (the blank-password bypass) or
  `no_auth_user` is combined with auth callout.
- **2.14.5 or later** for the idempotent-create data-loss fix (#8449) — a cluster that creates
  streams idempotently from application code while a node is down.
- **2.14.6** for the `max_file_store` ratchet if the value is unset ([[jetstream-out-of-disk]]), for
  replicated consumers that stick after a leader change (#8488), and for the consumer-create state
  destruction (#8491). 2.14.6 is the release the wiki is verified against.

## The docs' upgrade guide against the bodies

Every feature in the guide is in the v2.14.0 body except one sentence — "sourcing streams can now
perform deduplication when fanning in multiple sources", which no body confirms — and the guide's
account of #7788 (a frozen stream, `write error` in the health check) is the guide's own wording for
a body line that says only "handle read and write errors … more thoroughly". The guide omits
`ignore_discovered_servers`, the `404` change, the info-API deprioritisation and every patch. Three
gaps verified in the source: `dial_timeout` documented nowhere (**#61**), the `feature_flags`
reference page naming no flag (**#62** — the source at v2.14.6 has `js_ack_fc_v2` and
`js_raft_delete_range`, the second with a warning that older peers panic on it), and
`$JS.API.CONSUMER.RESET` absent from the consumer API index (**#63**) (source: [[s-relnotes-2.14]]).
And the v2.14.0 body's "enabled by default in v2.15" for `js_ack_fc_v2` had not happened at the
preview tag ([[s-relnotes-2.15-preview]]).


## The default diff at v2.14.6

Diffing `inbox/check-defaults-v2.12.15.md` against `inbox/check-defaults-v2.14.6.md` (2026-09-03):
**no resolved default moves** between the last 2.12 patch and 2.14.6, and one key becomes
resolvable — `jetstream { info_queue_limit }`, the separate queue for info and list requests that
2.14.0's #7898 introduced without naming the key: unset it takes `request_queue_limit`, so 10,000,
while the docs print 100,000 (#22). The line's other changes — the 4096-slot semaphore, the
`dial_timeout` fallback, the `feature_flags` defaults — are keys whose defaults are not stated in
the docs, so the report does not see them; they are in the tables above (source:
[[s-relnotes-2.14]]).


## Related

[[nats-server-2.12]] · [[nats-server-2.15-preview]] · [[raft-in-nats]] · [[retention-policies]] ·
[[js-api]] · [[consumer]] · [[upgrade-a-cluster]] · [[nats-server]] · [[jetstream-out-of-disk]] ·
[[malformed-or-corrupt-message]] · [[jetstream-sizing]]

## Sources

[[s-relnotes-2.14.0]] · [[s-docs-upgrade-to-2.14]] · [[s-issue-8322-dynamic-maxstore-shrinks]] ·
[[s-nats-server-jetstream-resources]] ·
[[s-adr-60-reliable-sourcing]] · [[s-docs-advanced-publishing]] · [[s-adr-51-message-scheduler]] · [[s-gh-7672-cron-schedules]] · [[s-relnotes-2.14.4]] · [[s-gh-8417-kv-mirror-file-vs-memory]] · [[s-nats-server-filestore-recovery]] · [[s-relnotes-2.14.1]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]] · [[s-relnotes-2.15-preview]]
