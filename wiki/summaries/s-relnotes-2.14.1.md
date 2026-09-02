---
title: "nats-server v2.14.1 release notes (2026-05-20) — drifted redelivered state, and the pending leak at max deliveries"
type: summary
area: [jetstream, deploy, monitoring]
source-url: https://github.com/nats-io/nats-server/releases/tag/v2.14.1
source-path: raw/release-notes/v2.14.1.md
author: "nats-io/nats-server maintainers"
article: "Release v2.14.1 body (GitHub release)"
date: 2026-05-20
version: "2.14.1"
tags: [release, 2.14.1, redelivery, max_deliver, workqueue, interest, consumer-store, varz, metrics, raft, mirrors]
aliases: [v2.14.1]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.14.1 (2026-05-20) — the first 2.14 patch, read for its consumer lines

The mirror and filestore lines of this release are already on [[s-relnotes-2.14.4]]; this summary is
the rest of it, read because two of its fixes are the *redelivery* shape and one is the `max_deliver`
shape. Phase D will fold it into the per-minor `s-relnotes-2.14`; the whole body is in
`raw/release-notes/`.

## Key claims

**Fixed, JetStream — the consumer lines:**

- "A number of paths that could leave consumer redelivered in a drifted state have been fixed, e.g.
  with workqueue or interest-based streams with `max_deliver`, on single message removal or after
  purges/compactions (#8102)"
- "Consumer file stores will now correctly flush when deleting a single redelivery, avoiding
  unexpected further redeliveries (#8168)"
- "Pending state no longer leaks when reaching max deliveries (#8156)"
- "The delivery policy for consumers on clustered workqueue streams is now enforced correctly (#8126)"
- "Consumers with `inactive_threshold` should no longer have their local state deleted unexpectedly
  when the proposal to the metalayer to clean up the consumer fails (#8198)"

**Fixed, elsewhere:** "Raft nodes will now ignore temporary snapshots on recovery after a crash
(#8101)"; "Raft node append entry caches are now invalidated correctly on WAL truncation and snapshot
installs (#8149)"; "Metalayer state is now preserved in a number of cases where it was incorrectly
being removed on shutdown (#8199)"; "Caches are now cleared correctly when converting filestore
encryption mode, avoiding block-level corruption (#8105, #8166)"; "Storage reservations for un-tiered
streams have been made consistent between creates/updates and clustered/non-clustered modes (#8170)";
"TLS listeners now work correctly with the PROXY protocol where enabled (#8130)"; "Client TLS
certificates without subject DNs but with DNS subject alternate names are now permitted (#8100)".

**Added:** "New metrics `in_client_msgs`, `in_client_bytes`, `out_client_msgs` and `out_client_bytes`
are now available via the `/varz` monitoring endpoint for tracking data to/from normal clients only
(#7851)".

**Improved:** "Num pending is now only calculated on consumer leaders, avoiding unnecessary CPU usage
on followers (#8172)"; "Stream and consumer assignment errors are now surfaced (#8208)";
"Intersection of sublists and subject trees can now be cancelled early, avoiding high CPU usage in
some pathological cases (#8209)"; "The log level of TLS handshake timeout or non-TLS record errors
have been demoted to debug level to reduce noise (#8096)". Go 1.26.3.

## Practical takeaways

- **2.14.0 is the only 2.14 without these consumer fixes.** A workqueue or interest stream with
  `max_deliver` on 2.14.0, or a consumer whose file store dropped a single redelivery, could report
  redelivered state that had drifted from reality — and, per #8168, redeliver again. On 2.14.1 and
  later, "redelivered" in `nats consumer info` is trustworthy again.
- `#8156` matters to a dead-letter design: before it, a message reaching `max_deliver` could leave
  its pending entry behind; the advisory and the drop are the same, the consumer's accounting was not.
- The four `/varz` client counters are the first per-server *client-only* traffic numbers; the older
  `in_msgs`/`out_msgs` include routes and internal traffic.

## Questions it answers

- Version layer for **row 14** (the known-defect cause on [[consumer-keeps-redelivering]]); a
  monitoring note for the [[nats-server-2.14]] entity.

## Pages touched

[[consumer-keeps-redelivering]] · [[nats-server-2.14]] · [[ack-and-redelivery]] ·
[[dead-letter-queue]]
