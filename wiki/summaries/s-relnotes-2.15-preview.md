---
title: "nats-server v2.15.0-preview.1 release notes (2026-08-24) — the 2.15 preview as it stands"
type: summary
area: [deploy, jetstream, topology]
source-url: https://github.com/nats-io/nats-server/releases/tag/v2.15.0-preview.1
source-path: raw/release-notes/v2.15.0-preview.1.md, raw/nats-server-src/feature-flags-dial-timeout-and-2.15-subjects.md
author: nats-io/nats-server maintainers
date: 2026-08-24
version: "2.15"
article: "Release v2.15.0-preview.1 body (GitHub prerelease), read whole on 2026-09-03; the new API subjects verified in server/jetstream_api.go and the feature flags in server/feature_flags.go at that tag"
tags: [release, 2.15, preview, prerelease, desired-state, evacuate, cancel-move, meta-rescue, backup-v2, sources.db, js_snapshot_sources, sync_interval]
aliases: [v2.15.0-preview.1, "2.15 preview", "2.15 release notes"]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.15.0-preview.1 (2026-08-24) — the 2.15 preview as it stands

**A preview, not a release.** The body opens with `> [!IMPORTANT] This is a preview release for the
upcoming 2.15 series. This is not a formal release candidate and is still undergoing testing`, is
flagged prerelease on GitHub, is built with **Go 1.27.0**, and "contains all changes up to and
including v2.14.5" — so it predates the 2.14.6 fixes ([[s-relnotes-2.14]]). It is the only 2.15
tag as of 2026-09-03 (`raw/release-notes/_tags-and-dates.md`); no release date is announced. Read
here whole, after [[s-nats-server-filestore-recovery]] and [[jetstream-recovery-is-slow]] had used
its source-indexing line; the subjects it names were checked in `server/jetstream_api.go` and the
flags in `server/feature_flags.go` **at the preview tag**
(`raw/nats-server-src/feature-flags-dial-timeout-and-2.15-subjects.md`).

## Key claims — `### Added`, JetStream

| item | PRs | what the body says | verified at the tag |
|---|---|---|---|
| **Desired state metalayer** | #8432, #8437, #8439, #8443, #8452, #8460, #8476 | "a new desired state reconciliation engine for streams and consumers considerably improves the safety and reliability of asset moves and scales"; changing placement or replicas mid-move, cancelling an in-flight scale/move, and peer-removing are "now much safer" | — (design, not a subject) |
| **Cancel stream move** | #8476 | "an in-flight scale/move operation on a stream can be cancelled and the asset returned to its original placement using the new `$JS.API.STREAM.CANCEL_MOVE` endpoint" | `jetstream_api.go:189` — **`$JS.API.STREAM.CANCEL_MOVE.<stream>`**, an account-level request; the source comment: "not limited to moves, any in-flight desired state is rolled back, which includes a scale up/down or a retention change". Distinct from the system-account `$JS.API.ACCOUNT.STREAM.CANCEL_MOVE.<account>.<stream>` that 2.14.6 already serves ([[js-api-subjects]]) |
| **Evacuate endpoints** | #8443 | `$JS.API.SERVER.EVACUATE` "can safely evacuate streams, and any consumers on those streams, from a node"; `$JS.API.STREAM.PEER.EVACUATE.*` evacuates one peer from one stream; together they "allow for maintenance operations with full transfer of data and state without having to peer-remove first" | `jetstream_api.go:215` — **`$JS.API.SERVER.EVACUATE`**, "Only works from system account"; `:181` — **`$JS.API.STREAM.PEER.EVACUATE.<stream>`** |
| **Metalayer rescue** | #8408 | `$JS.API.META.RESCUE` "can temporarily lower the quorum-needed for the metalayer, in order to facilitate the recovery of a system where nodes have been permanently lost" — ADR-61 ([[s-adr-61-meta-quorum-rescue]]) | `jetstream_api.go:223` — a broadcast subject, "every online server evaluates and responds … independently", system account only |
| **Stream backup and restore v2** | #7882 | "a new backup format for stream snapshots which reads out per-message rather than per-block"; it "now correctly includes non-replicated consumers on follower nodes" | not read |
| **Detect source stream recreation** | #8384 | "the server now detects a source stream being recreated, restarting the sourcing back from the beginning, ensuring new messages are sourced" — the fix for [[s-gh-6005-sourcing-memory-stream-restart]] | not read |
| **Stream source indexing** | #8282 | "Restarts and leader changes previously required expensive backward scans through the stream to find the last sourced indices. These are now persisted in an index for instant lookup." — `sources.db` ([[s-nats-server-filestore-recovery]]) | the flag: `feature_flags.go:25, 54–59` — **`js_snapshot_sources`**, "Introduced: 2.15.0, both encoding versions are accepted, only emitting v1", default `false` |
| **Domain-prefixed JS API in the system account** | #8429 | "when a system account is bridged between the hub and a leaf node, the domain-prefixed JS API can now be used to operate on the leaf node while directly connected to the hub" | not read |

## `### Changed` — sync on replicated streams

"When the `sync_interval` is set to `always`, replicated streams now sync their WAL entries but no
longer sync upper stream layer writes" (#8447); "the synced log allows the stream to recover safely,
but removing unnecessary syncs from the upper stream layer dramatically improves performance";
**"non-replicated R1 streams are not affected by this change and will continue to sync at the stream
layer as normal."** A default did not change; what `sync_interval: always` *does* on an R3 stream
did ([[replicas]], [[filestore-layout]]).

## `### Improved`

"Shorter wait for durable source/mirror consumer resets (#8323) — when using durable consumers for
sourcing or mirroring, the heartbeats now short-circuit the recreation backoff" — the `AckFlowControl`
consumers of [[s-adr-60-reliable-sourcing]].

## What the preview does *not* say

- **Nothing about the `$JS.ACK` v2 default.** The v2.14.0 body promised `js_ack_fc_v2` "will be
  enabled by default in v2.15"; at this tag `feature_flags.go:36` still reads
  `FeatureFlagJsAckFormatV2: false` with "Enabled: TBD" — three flags exist (`js_ack_fc_v2`,
  `js_raft_delete_range`, `js_snapshot_sources`), all `false`. The ACL deadline on
  [[nats-server-2.15-preview]] stands as stated intent.
- No downgrade note, no API level, no `### Fixed` section of its own (the fixes are 2.14.5's).
- No date for 2.15.0.

## Relevance to the wiki

The operational surface of 2.15 as far as it is public: two evacuation subjects and a cancel that
change how [[rebalance-streams]] and [[evict-a-sick-server]] will be done, the rescue that
[[disaster-recovery]] already describes from ADR-61, the source index that ends cause 1 of
[[jetstream-recovery-is-slow]], and a `sync_interval: always` that means less on a replicated stream.
Everything here is preview-only and says so on every page it touches.

## Questions it answers

Rows 13 and 154 in part (the source index and the recreation detection are the fixes those rows
wait for); 34 and 40 in part (evacuate and cancel-move are the 2.15 shape of those runbooks). No
open row is closed.

## Pages touched

[[nats-server-2.15-preview]] · [[nats-server-2.14]] · [[js-api-subjects]] · [[meta-layer]] ·
[[raft-in-nats]] · [[disaster-recovery]] · [[rebalance-streams]] · [[evict-a-sick-server]] ·
[[mirrors-and-sources]] · [[jetstream-recovery-is-slow]] · [[replicas]] · [[filestore-layout]] ·
[[backup-and-restore-jetstream]] · [[upgrade-a-cluster]]
