---
title: "docs.nats.io — Stream backup and restore"
type: summary
area: [jetstream, deploy]
source-url: https://docs.nats.io/learn/backup-recovery/stream-backup-restore.md
source-path: raw/nats-docs/learn/backup-recovery/stream-backup-restore.md
author: NATS documentation (Synadia Communications, Inc.)
article: Stream backup and restore
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [backup, restore, snapshot, backup.json, stream.tar.s2, chunk-size, window-size, memory-streams]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Stream backup and restore

The snapshot: what it contains, how it streams off the server, and the four rules that shape a
restore. The only prose source for `nats stream backup` — and the page whose memory-stream error
message does not match the server ([[s-nats-server-snapshot-restore]]).

## Key claims

**A snapshot is two files in a directory:**

- **`backup.json`** — "the stream's configuration and state: its subjects, retention, limits, and
  sequence range";
- **`stream.tar.s2`** — "the messages themselves, packed into a tarball and compressed with S2".

```
nats stream backup ORDERS ./backups/orders/2026-06-04 --consumers
```

```
Starting backup of Stream "ORDERS" with 1 data file
...
Received 4 MiB compressed data in 128 chunks for stream "ORDERS" in 0.41s, 4.0 MiB uncompressed
Backup of "ORDERS" took 0.41s
```

**Consumer state is included by default.** "Restore that snapshot and the `shipping` and `analytics`
consumers come back exactly where they left off, not at the start of the stream." `--no-consumers`
drops it, and "nothing warns you until `shipping` is missing in production".

**The snapshot is chunked, windowed and acked:**

> "The server cuts the tarball into chunks and pushes them to an inbox subject, keeping up to a
> window's worth of unacknowledged chunks in flight at once — **8 MiB by default, which is 64 of the
> default 128 KiB chunks**. Each client ack frees a slot for the next chunk, and **if no ack arrives
> for about five seconds the backup aborts**."

(All three numbers confirmed in the server source — [[s-nats-server-snapshot-restore]].)

**Restore rebuilds the stream from the directory:**

```
nats stream restore ./backups/orders/2026-06-04
```

> "same messages, same sequence numbers, same configuration."

**Two rules on restore:**

1. **The name cannot change.** "The name lives in `backup.json`, and the server rejects a restore
   that would land under a different name … `stream name may not be changed during restore`." (The
   real message is the **CLI's**, and it reads `stream names may not be changed during restore` —
   [[s-natscli-backup-restore]].) "If you do need a second copy under a new name, restore to `ORDERS`
   first and then mirror or source it."
2. **The stream must not already exist.** "It recreates the stream; it doesn't merge a snapshot into
   a live one. So a real recovery is: confirm the broken stream is gone (or remove it), then
   restore."

**Verification is the last step, always:**

```
nats stream info ORDERS
```

> "`Messages` and `Last Sequence` must match the stream you snapshotted … Matching counts are what
> prove the archive is real; **the backup command exiting zero does not prove it on its own**."

and, on a short count: "the snapshot was taken under live writes that did not finish — snapshot a
quiesced stream, or accept the snapshot's point in time as your RPO."

**Four pitfalls:**

1. **"Memory streams cannot be snapshotted."** "A snapshot reads a stream's on-disk files, so a
   stream with `Storage: Memory` has nothing to read. The backup fails with
   `memory streams do not support snapshots`." **The server does not produce that message** — see
   below.
2. The name rule, as above.
3. **Flow control times out on slow disks or distant links**, aborting the backup
   (`408 No Flow Response`). The fix: `--chunk-size 64k --window-size 1m`.
4. `--no-consumers` silently drops consumer state.

## Practical takeaways

- **A snapshot is the only copy that predates a mistake** — the framing the DR page builds on
  ([[s-docs-disaster-recovery]]).
- **Storage type decides whether a stream is backupable at all**, and it is fixed at creation
  ([[stream]]). A memory stream has no backup path through this API.
- **Chunk and window size are the two knobs for a slow link**, and both are request fields on
  `$JS.API.STREAM.SNAPSHOT.<stream>`, not config keys.
- **The verification step is the deliverable.** Exit zero means the transfer finished, not that the
  archive restores.

## The claim that does not hold

> "The backup fails with `memory streams do not support snapshots`."

The server's memory store returns `no impl` (`server/memstore.go:2425`, v2.14.6), which surfaces as
error **10064** `snapshot failed: no impl`. Recorded as `inbox/docs-issues.md` **#15**, and stated on
[[backup-and-restore-jetstream]] with the real text.

## Relevance to the wiki

The whole of [[backup-and-restore-jetstream]], and the snapshot half of [[disaster-recovery]].

## Questions it answers

**Q32** — including the memory-stream half, once the real error is substituted.

## Pages touched

[[backup-and-restore-jetstream]] · [[disaster-recovery]] · [[stream]] · [[error-codes]] ·
[[js-api-subjects]] · [[nats-cli]]
