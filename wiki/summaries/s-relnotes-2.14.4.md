---
title: "nats-server v2.14.4 release notes (2026-07-30), with the mirror and filestore lines of v2.14.1 and v2.14.2"
type: summary
area: [jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/releases/tag/v2.14.4
source-path: raw/release-notes/v2.14.4.md
author: "nats-io/nats-server maintainers"
article: "Release v2.14.4 body (GitHub release), plus three lines from raw/release-notes/v2.14.1.md and v2.14.2.md"
date: 2026-07-30
version: "2.14.4"
tags: [release, 2.14.4, 2.14.2, 2.14.1, interior-deletes, dmap, avl, filestore, mirror, max_concurrent_io, security]
aliases: [v2.14.4]
sources: []
created: 2026-09-02
updated: 2026-09-02
---

# nats-server v2.14.4 (2026-07-30) — the interior-delete release

Read for one reason: gh#8417 ran on v2.14.2, its maintainer said he was "working on an improvement
in the filestore for a situation like this where the number of deletes are greater than the number
of unique subjects", and this is where that work shipped — three days after the thread closed. The
lab runs on v2.14.6, so every measurement in [[s-nats-server-mirrors-observed]] is on the fixed side.
Phase D will fold this into the per-minor `s-relnotes-2.14`; the whole body and the other five patch
bodies are in `raw/release-notes/`.

## Key claims — v2.14.4

Go 1.26.5. **Improved**, JetStream:

- "Calculating and looking up sequences in delete maps for file-backed streams with large numbers of
  interior deletes is now faster and holds locks for less time (#8403)"
- "Inserts, iterations and deletes in AVL sequence sets are now faster in many cases, which speeds
  up the tracking of interior deletes (#8406)"
- "Stream snapshots now attempt to determine the correct encode buffer size up front, avoiding many
  unnecessary allocations on streams with large numbers of interior deletes (#8405)"
- "Reduced memory usage of the structure that is used to track subjects within a stream (#8412)"
- "The disk concurrency semaphore has been increased to 4096 slots, up from the previous CPU-scaled
  count (#8336)" and "can now be configured with the **`max_concurrent_io`** option in the
  `jetstream` config block (#8336)"
- "Filestore underlying block cache buffers are now recycled to the pool when the weak reference is
  collected by the GC (#8395)"

**Fixed**, the ones an operator of mirrors or sparse streams would notice:

- "Stale error responses on source or mirror creation are now dropped by recreating the subscription
  (#8356)"
- "The filestore no longer skips sparse delete blocks when processing deletes from a snapshot (#8404)"
- "Fixed a race condition between concurrent message removals via limits that could unexpectedly
  disable writes into a filestore (#8378)"
- "Fixed a race condition between storing messages in the filestore and block compactions (#8400)"
- "Raft proposals now require the term to be passed down from JetStream, preventing situations where
  stale proposals from a previous term could make changes in a new term after a fast election (#8370)"
- "Filestore blocks with unsynced or truncated key files are now removed and counted as lost data
  instead of failing to recover altogether (#8365)"

And a block of **security fixes** without PR numbers: "Combining `no_auth_user` with auth callouts
will no longer skip authentication checks when no `CONNECT` message is sent", "JWT validation no
longer crashes the server with whitespace-only permissions", "Several paths that enforce the
permissions of queue subscriptions no longer treat the whole permission as a subject literal",
"Fixed an authentication bypass with TLS `verify_and_map` authenticating users with blank passwords",
and MQTT: "MQTT clients can no longer subscribe to `$MQTT.>` subjects, closing a potential permission
bypass".

## The lines from v2.14.1 (2026-05-20) and v2.14.2 (2026-06-02)

- v2.14.1: "Mirror consumers are now retried immediately on a last sequence mismatch, avoiding
  stalling for longer than necessary (#8152)" and "Skip message errors are now surfaced correctly,
  propagating failures (#8152)"; "Source consumer creation will no longer schedule a recreation if a
  setup is already in progress, avoiding potential setup storms (#8111)".
- v2.14.2: "The filestore no longer performs a block skip check on streams with extremely high
  subject counts, as it could result in runaway CPU usage (#8227)"; "Fixed an issue where the
  per-subject state last block was not stored correctly with a max messages per subject limit of 1
  (#8254)" — the KV shape exactly.

## What did not change

The linear-scan heuristic in `firstMatching` — `mb.fss.Size()*4 > int(lseq-fseq)` — is the same at
v2.14.6 as the maintainer described it in July ([[s-nats-server-mirror]]). 2.14.4 made each
delete-map lookup cheaper; it did not make a mirror recognise an everything-matching filter.

## Practical takeaways

- A cluster with sparse file streams (KV buckets with hot keys, Interest or WorkQueue streams with
  large gaps) wants **2.14.4 or later**; the per-subject-state fix for `max_msgs_per_subject: 1` is
  in **2.14.2**.
- `max_concurrent_io` exists from 2.14.4 (default 4096 slots); nothing older exposes it.
- The four security fixes in 2.14.4 are reason enough to be past it, independent of JetStream.

## Questions it answers

- Version layer for **Q76** and **Q91**; material for **Q9** (#8227 is the first public statement of
  a subject-count threshold) and **Q13**.

## Pages touched

[[nats-server-2.14]] · [[filestore-layout]] · [[mirrors-and-sources]] ·
[[consumer-slow-on-a-sparse-stream]]
