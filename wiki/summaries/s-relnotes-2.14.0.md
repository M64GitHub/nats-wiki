---
title: "nats-server v2.14.0 release notes"
type: summary
area: [deploy, jetstream, topology]
source-url: https://github.com/nats-io/nats-server/releases/tag/v2.14.0
source-path: raw/release-notes/v2.14.0.md
author: nats-io/nats-server maintainers
article: "Release v2.14.0"
date: 2026-04-30          # GitHub published_at
version: "2.14"
tags: [release, 2.14, changelog, feature_flags, consumer-reset]
aliases: [v2.14.0]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.0 release notes

Published **2026-04-30**, built with **Go 1.26.2**. The changelog behind
[[s-docs-upgrade-to-2.14]]; this summary keeps the items the upgrade guide does not carry, with
their PR numbers.

## Added

**General** — feature flags in the server configuration (#7866, ADR-53).

**JetStream**

| item | detail |
|---|---|
| Fast-ingest batch publishing | #7778, #7892, #7894, #7945 — ADR-50 |
| Repeating & cron-based message schedules | #7504, #7687, #7688 — the **`Nats-Schedule`** header takes `@every 5m`, `@hourly` or crontab syntax (ADR-51) |
| Scheduled subject sampling | #7506 — the **`Nats-Schedule-Source`** header samples the last message in the stream for a subject, "allowing sampling of values at a different rate to the original publisher" |
| Scheduled subject rollups | #7559 — the **`Nats-Schedule-Rollup`** header rolls up the `Nats-Schedule-Target` subject on a schedule |
| **Consumer reset API** | #7489 — **`$JS.API.CONSUMER.RESET.<stream>.<consumer>`** resets a consumer to an earlier sequence **without deleting and recreating it** (ADR-60) |
| Domain-aware ack and flow-control subjects | #7860 — **disabled by default**, enabled with the **`js_ack_fc_v2`** feature flag, **default in v2.15**. ACLs must match `$JS.ACK.domain.acchash.stream.consumer.>` and `$JS.FC.domain.acchash.stream.consumer.>` |
| Asynchronous stream state snapshots | #7876 |
| Disable message deduplication when sourcing | #7651 |

**Leafnodes** — remote configurations can be added and removed at runtime by config reload
(#7937); new **`ignore_discovered_servers`** option for leafnode remotes, to ignore leafnode URLs
sent by the hub (#8067).

## Changed

- **`traceparent` is no longer modified by message tracing** (#7755). The sentinel header value
  **`Nats-Trace-Dest: trace disabled`** disables all server tracing-related functionality.
- **Consumers now generate a `404 No Messages` response when using `no_wait` without setting an
  expiry and there are no pending messages** (#7466).
- **Invalid or divergent consumer state is reset to match the stream state on startup**, i.e. after
  unclean shutdowns (#7692).
- **Info APIs are deprioritised.** Account info, stream info, stream list, consumer info and
  consumer list requests are now **queued separately, below create-update-delete operations**
  (#7898).
- **MQTT**: retained messages can no longer contain the ASCII DEL character (`0x7F`) in the subject
  (#8071).

## Improved

- **Sourcing and mirroring from interest and workqueue streams is now supported** (#7613). The
  server "automatically upgrades to a durable consumer with `AckFlowControl` policy and uses
  consumer reset where necessary" (ADR-60).
- **End-of-batch commit** for atomic batch publishing (#7403) — `Nats-Batch-Commit: eob` commits
  the batch, and **that last message is not persisted** (ADR-50).
- **Rollups are now allowed if the stream has reached the `discard_new_per_subject` limit** (#7974).
- **Raft nodes will step down if overrun** (#7853).

## Fixed

- **Raft nodes will no longer start if the snapshot is missing or corrupt, or if the snapshot does
  not align with the remaining log on disk, avoiding potential data loss** (#7566, #7580, #7620).
- Filestore operations handle read and write errors from the filesystem more thoroughly (#7788).
- Filestore recovers from a partial purge after a hard kill (#7676).
- Consistent Raft group rename when moving to or off R1 (#7802).

## Relevance to the wiki

The precise version attribution the concept pages need, plus four facts the docs' upgrade guide
omits: the consumer-reset **subject**, the info-API deprioritisation (which changes what a
monitoring poller costs on a busy server), the `no_wait`-without-expiry `404` change, and that a
Raft node with a corrupt or misaligned snapshot now **refuses to start** rather than risking data
loss.

## Questions it answers

Q64 in part (data-integrity risks across a minor upgrade — the refuse-to-start-on-bad-snapshot
change is the concrete one).

## Pages touched

[[nats-server-2.14]] · [[raft-in-nats]] · [[consumer]] · [[js-api]] · [[retention-policies]] ·
[[monitoring-endpoints]]
