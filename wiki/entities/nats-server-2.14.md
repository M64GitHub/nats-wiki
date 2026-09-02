---
title: nats-server 2.14
type: entity
kind: release
area: [deploy, jetstream, topology]
since: [2.14]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [release, 2.14, feature_flags, js_ack_fc_v2]
aliases: ["2.14", v2.14, v2.14.0, v2.14.6]
sources: [s-issue-8322-dynamic-maxstore-shrinks, s-nats-server-jetstream-resources, s-relnotes-2.14.0, s-docs-upgrade-to-2.14, s-adr-60-reliable-sourcing, s-docs-advanced-publishing, s-adr-51-message-scheduler, s-gh-7672-cron-schedules, s-relnotes-2.14.4, s-gh-8417-kv-mirror-file-vs-memory]
created: 2026-08-31
updated: 2026-09-02
---

# nats-server 2.14

The current stable minor. **2.14 is the direct successor of 2.12 — there is no 2.13.**

## Facts

| | |
|---|---|
| first release | **v2.14.0**, 2026-04-30 |
| latest release | **v2.14.6**, 2026-08-27 |
| releases in this line | 15 tags, from `v2.14.0-RC.1` (2026-04-16) |
| built with | Go 1.26.2 (v2.14.0) |
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
- Sourcing streams can **disable deduplication**, and can deduplicate when fanning in multiple
  sources.
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

**In 2.15 the default becomes v2.** Anyone with account imports/exports or subject permissions
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
phase D ingests them whole). The lines that decide which patch an operator of mirrors or KV buckets
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


## Related

[[nats-server-2.12]] · [[nats-server-2.15-preview]] · [[raft-in-nats]] · [[retention-policies]] ·
[[js-api]] · [[consumer]] · [[upgrade-a-cluster]] · [[nats-server]] · [[jetstream-out-of-disk]] ·
[[malformed-or-corrupt-message]] · [[jetstream-sizing]]

## Sources

[[s-relnotes-2.14.0]] · [[s-docs-upgrade-to-2.14]] · [[s-issue-8322-dynamic-maxstore-shrinks]] ·
[[s-nats-server-jetstream-resources]] ·
[[s-adr-60-reliable-sourcing]] · [[s-docs-advanced-publishing]] · [[s-adr-51-message-scheduler]] · [[s-gh-7672-cron-schedules]] · [[s-relnotes-2.14.4]] · [[s-gh-8417-kv-mirror-file-vs-memory]]
