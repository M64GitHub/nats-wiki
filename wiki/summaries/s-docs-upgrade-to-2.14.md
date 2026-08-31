---
title: "docs.nats.io — Upgrade to NATS 2.14"
type: summary
area: [deploy, jetstream, topology]
source-url: https://docs.nats.io/release-notes/upgrade-to-2.14.md
source-path: raw/nats-docs/release-notes/upgrade-to-2.14.md
author: NATS documentation (Synadia Communications, Inc.)
article: Upgrade to NATS 2.14
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [upgrade, 2.14, feature_flags, js_ack_fc_v2, raft-overrun, filestore]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Upgrade to NATS 2.14

The upgrade guide from 2.12.x. **"Note that version 2.13 was skipped: 2.14 is the direct successor
of 2.12."**

## Key claims — features

**Streams**

- **Fast batch publish** — the `AllowBatchPublish` stream option, high-throughput flow-controlled
  publishing into a stream, replicated or not, with per-message consistency checks and no
  intermediate staging (ADR-50).
- **Recurring schedules** — `AllowMsgSchedules` now also takes a simple interval or **Cron**
  (ADR-51).
- **Scheduled subject sampling** — `AllowMsgSchedules` can source the last message matching a
  subject into the scheduled message; useful for downsampling on an interval.
- **Reliable WorkQueue and Interest mirroring/sourcing** — **sourcing or mirroring from a WorkQueue
  or Interest retention stream is now supported.** A **durable** consumer is used automatically
  instead of an ephemeral one, with a new ack policy **`AckFlowControl`** that acknowledges messages
  after they are persisted, based on flow control (ADR-60).

**Consumers**

- **Consumer reset API** — delivery state can be reset to the acknowledgement floor or to an
  arbitrary sequence, still respecting start sequences. "The consumer state after reset equals what
  would otherwise be a consumer delete and recreate at a specific starting sequence" (ADR-60).

**Operations**

- **Leafnode remote config reload** — the leafnode remotes section can be added and removed by
  configuration reload, **without a server restart**.
- **Filestore I/O error handling** — previously not all filestore I/O errors were handled properly.
  Now they are surfaced in logs and health checks and **freeze the affected stream**.
- **Raft overrun protection** — the server recognises its Raft layer being overrun by proposals and
  bounds the memory and disk it may use during such an event.

## Key claims — improvements

- Streams with sources can now **disable deduplication**, and a sourcing stream can deduplicate when
  fanning in multiple sources.
- **Atomic batch EOB commit** — a batch can be committed through an End-of-Batch message **without
  persisting that final message**; also supported with fast batch publish.
- **Scheduled subject rollups** — the `Nats-Schedule-Rollup` header.
- **Feature flags** — a `feature_flags` config field to opt in or out of specific fixes and
  improvements before they become the default.
- **Domain-aware ack and flow-control subjects** — both v1 and v2 supported (ADR-15).
- **`traceparent` is no longer modified** by message tracing.
- **Asynchronous stream state snapshots for replicated streams** — snapshots taken and written
  without pausing stream processing, improving tail latencies; "particularly impactful in cases
  where the stream has a large number of interior deletes".

## Upgrade considerations — the operator's half

### `$JS.ACK` / `$JS.FC` subject format changes in 2.15

```
v1: $JS.ACK.<stream name>.<consumer name>.<num delivered>.<stream sequence>.<consumer sequence>.<timestamp>.<num pending>
v2: $JS.ACK.<domain>.<account hash>.<stream name>.<consumer name>.<num delivered>.<stream sequence>.<consumer sequence>.<timestamp>.<num pending>
```

**Both formats are supported from 2.14; v1 remains the default. In 2.15 the default becomes v2.**

> Users that have defined account imports/exports or subject permissions containing the
> `$JS.ACK.<stream>.>` or `$JS.FC.<stream>.>` (or more granular) subjects **will be required to
> update their ACLs and/or account imports/exports before the 2.15 release**.

**Who is unaffected:** anyone with no such imports/exports or permissions (JetStream in a single
account), or anyone who used the catch-all wildcards `$JS.ACK.>` / `$JS.FC.>`.

Opt in early with a feature flag:

```
feature_flags {
  js_ack_fc_v2: true
}
```

Not specifying the flag means "use the server default", which for 2.14 is v1. `true` uses v2 (v1
still supported); `false` uses v1 but still supports v2.

### Filestore I/O errors now freeze a stream

> "if I/O errors are encountered, each stream affected by it will stop making progress. NATS core
> traffic is not affected by I/O errors, so the server keeps functioning, but will require a
> **restart** to recover from these I/O issues."

Observable as **a failing health check reporting an I/O error whose message contains `write
error`** plus which error was encountered. Other streams on the same server are unaffected, and for
replicated streams **another replica picks up the work transparently**.

### Raft overrun protection

In prior versions entries could be written to the Raft write-ahead log faster than they could be
committed and applied, growing memory and disk without bound. In 2.14 **leaders that detect they
are falling behind step down so a healthier peer can take over.** If a majority of peers are equally
overloaded, **the system remains in this degraded state** — the protection is "a safety net for
transient overload, not a substitute for adequate capacity".

### WorkQueue/Interest sourcing during a rolling upgrade

This log line is **expected** during an upgrade or downgrade and resolves once every server is on
the same version:

```
[WRN] Invalid JetStream request '$G > $JS.API.CONSUMER.CREATE.O': json: unknown field "sourcing"
```

An upgraded server tried the new-style sourcing consumer, an older target did not recognise it —
the upgraded server retries automatically with the old style.

## Downgrade considerations

- The same `Invalid JetStream request` line may appear, and **stream sourcing or mirroring may
  temporarily be unable to function until all servers are downgraded**.
- If WorkQueue/Interest sourcing or mirroring was started after the upgrade, it will **appear to
  work but run in the less reliable ephemeral consumer mode**, and any durable consumers created
  with `AckFlowControl` are **marked "offline" and unusable until upgraded back to 2.14**.
- **`feature_flags` must be removed from the config before downgrading** — older servers do not
  recognise the field.

## Relevance to the wiki

The change layer for 2.14: it settles the no-2.13 question, gives the `$JS.ACK` v2 migration
deadline (an ACL change with a hard release boundary), and supplies two new operational conditions
to watch for — a frozen stream on filestore I/O error, and leaders stepping down under Raft overrun.

## Questions it answers

Q63 in part and Q64 in part (rolling a cluster onto a new version and the data-integrity risks — for
the 2.12→2.14 hop specifically; a general runbook is still open).

## Pages touched

[[nats-server-2.14]] · [[nats-server-2.15-preview]] · [[retention-policies]] · [[raft-in-nats]] ·
[[js-api]] · [[consumer]] · [[stream]]
