---
title: "JetStream startup or recovery is slow"
type: gotcha
area: [jetstream, deploy]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-09-02
tags: [recovery, restore, startup, index.db, sources, backward-scan, clean-shutdown, SIGKILL, healthcheck, cardinality, kubernetes, measured, unanswered-upstream]
aliases: ["Restored messages for stream in minutes", "JetStream restart takes minutes", "stream restore slow", "server slow to start with large stream", "Healthcheck failed during startup", "jetstream startup slow", "recovery slow after restart", "jetstream-recovery-is-slow"]
sources: [s-gh-8001-jetstream-startup-slow-50m, s-nats-server-filestore-recovery, s-nats-server-stream-scale-observed, s-gh-8333-high-cardinality-subjects, s-synadia-how-many-subjects, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12, s-relnotes-2.14, s-relnotes-2.15-preview, s-nats-server-stream-topology-observed]
created: 2026-09-02
updated: 2026-09-04
---

# JetStream startup or recovery is slow

A server with a large file-backed stream takes minutes to come back after a restart. The log sits
between `Starting restore for stream …` and `Restored N messages for stream … in <minutes>` while
`Healthcheck failed` repeats; the disk reads steadily, one or two cores are busy, and — the part
that surprises — it happens **after a clean shutdown too**.

## Symptom

From the public report, nats-server 2.12.5, one R1 file stream of 50 M messages / 7 GB with about
twenty `sources`, restarted under the Helm chart after a clean `JetStream Shutdown` (source:
[[s-gh-8001-jetstream-startup-slow-50m]]):

```
15:56:24.874369 [INF]   Starting restore for stream 'project > project-event'
15:56:26.795870 [INF]   Restored 274,003 messages for stream 'project > project-controller' in 1.921s
15:56:34.458356 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: leafnode, websocket, server"
[previous message repeated regularly]
16:03:03.158149 [INF]   Restored 50,005,377 messages for stream 'project > project-event' in 6m38.284s
```

About 20 MB/s of reads and no writes for the whole six minutes; under two cores; memory flat. The
`Healthcheck failed` line is the readiness probe polling `/healthz` — one line per poll for as long
as the restore takes (measured on 2.14.6: one per poll, source:
[[s-nats-server-stream-scale-observed]]) — so on Kubernetes the pod stays not-ready and on a cluster
the node stays out for the duration.

## Quick triage

```
# 1 · was the stop clean? what did the store say when it came back?
grep -E 'JetStream Shutdown|Server Exiting|Filestore \[|Stream state|Restored' nats-server.log | tail -20

# 2 · does the slow stream have sources (or is it a mirror)?
nats stream info <stream> --json | jq '{sources: [.config.sources[]?.name], mirror: .config.mirror.name,
                                       msgs: .state.messages, bytes: .state.bytes, subjects: .state.num_subjects}'

# 3 · while it is still restoring: what is the restoring goroutine doing?
curl -s http://127.0.0.1:8222/stacksz | grep -A 30 'recoverStream' | grep -E 'server\.\(' | head
```

Read the answers against the causes below: a `Filestore [<stream>] Stream state …` warning means
cause 2; `sources` present and no such warning means cause 1; `num_subjects` above a million means
cause 3 whatever the stop was; a stack in `startingSequenceForSources` is cause 1, in
`rebuildStateFromBufLocked` cause 2 or 3.

## Causes, ranked

### 1 · The stream has `sources`, and one of them is idle or empty (2.10–2.14)

**The trap.** At every start — and on a replicated stream at every leader change — a stream with
`sources` scans **itself backwards from its last message** to find the last sequence it received from
each source (`startingSequenceForSources`, `stream.go:4787–4894` at 2.14.6). It stops early only when
it has seen a message from *every* configured source. A source that has never delivered, or has been
quiet since before the stream's oldest message, sends the scan to sequence 1: every block loaded in
full, decompressed, one goroutine. On an R1 stream this runs inline inside the `Restored … in` timer;
nothing in the log names it (source: [[s-nats-server-filestore-recovery]]). The public report's own
goroutine dump shows exactly this frame, and nobody upstream read it — the thread is **unanswered as
of 2026-09-02** (source: [[s-gh-8001-jetstream-startup-slow-50m]]).

**How to confirm.** `stacksz` during the restore shows `startingSequenceForSources` →
`LoadPrevMsgMulti` → `prevMatchingMulti` / `prevMatching` → `loadMsgsWithLock`. Or the arithmetic: the
restore time is the stream's bytes on disk divided by what the volume reads at — 7 GB at 20 MB/s is
six minutes. Measured on 2.14.6: a 1.6 GB sourcing stream restored in **2.57 s** with one empty
source and **23 ms** without it, the 50 M-message stream it sourced from in 3 ms alongside (source:
[[s-nats-server-stream-scale-observed]]).

**The fix.**

- **Remove sources that have nothing in the stream** — a source added "for later", a source whose
  origin was emptied or renamed. `nats stream edit` takes the change live; the next start is fast.
- **Keep every source producing**, or accept the scan and size the restart window for it
  (bytes on disk ÷ read throughput, per sourcing stream, serially per stream).
- **Put the sourcing stream on the fastest volume**, not the biggest: the scan is a sequential read
  and the report's Ceph volume gave it 20 MB/s.
- **2.15** removes it: the sourced sequences are indexed as they arrive and kept in `sources.db` at the
  stream's root (PR #8282, 2026-08-20; empty sources too since #8516; v2.15.0-preview.1: *"Restarts
  and leader changes previously required expensive backward scans through the stream to find the
  last sourced indices"*). Replicated streams need `feature_flags { js_snapshot_sources }` for the
  index to be replicated. Not in any 2.14.x (source: [[s-nats-server-filestore-recovery]]).

### 2 · The stop was not clean, or `index.db` was refused, so every block is read

**The trap.** A clean stop writes `index.db` — the full stream state, the per-subject index, one
record per block — and the next start trusts it after four checks: its hash, that the last block it
names exists, that the block's **last record checksum** still matches, and that no newer block
exists (`recoverFullState`, `filestore.go:1927–2216`). A SIGKILL, an OOM kill, a node loss, or a
crash after the last periodic write fails the third check; anything that fails is logged as
`[WRN] Filestore [<stream>] Stream state …` and the store falls back to reading **every block end
to end**, verifying every record's hash and rebuilding the subject index (source:
[[s-nats-server-filestore-recovery]]).

**How to confirm.** The warning names the reason: `Stream state outdated, last block has additional
entries, will rebuild` (the common one), `… found extra blocks, will rebuild`, `… checksum did not
match`, `… could not locate msg block N`. A **missing** file logs nothing — a store restored from a
snapshot or copied by hand takes the same slow path silently. Measured on 2.14.6, 50 M messages /
6.8 GB: **3–27 ms** after a clean stop, **6.4 s** after SIGKILL, **9.5 s** with the file deleted, the
disk at 1.0–1.6 GB/s throughout — so on a 20 MB/s volume the same rebuild is minutes (source:
[[s-nats-server-stream-scale-observed]]).

**The fix.**

- **Stop cleanly**: SIGTERM (or lame duck first), and a `terminationGracePeriodSeconds` long enough
  for `JetStream Shutdown` to be logged before the kill — the report's pod was killed *after* that
  line and still paid, because of cause 1.
- **Do not delete or restore stores by hand** without expecting one full read on the next start.
- Nothing else shortens it on 2.14: the rebuild reads and hashes every record. Parallelism is
  across streams (`max_concurrent_io`, up to 64 workers, since 2.11.11 / 2.12.2), not within one.

### 3 · More than a million subjects, or a million interior deletes

**The trap.** Above `highCardinalityThreshold` (1,000,000, a code constant) the **periodic** `index.db`
write is skipped; only a clean stop writes one. So for a stream that large in subjects — or with
that many interior deletes, which a busy KV bucket accumulates — every unclean stop is cause 2, and
a clean one still rebuilds a million-entry in-memory tree from the file (source:
[[s-nats-server-filestore-recovery]]).

**How to confirm.** `nats stream info` → `Number of Subjects` above a million, and no `index.db` in
`msgs/` on a running server. Measured on 2.14.6, 3.2 M messages over 1.2 M subjects: **153 ms** after
a clean stop, **1.02 s** after SIGKILL, against 2 ms / 303 ms for the same messages over six subjects
(source: [[s-nats-server-stream-scale-observed]]). Synadia's check pages call this out as the third
cost of cardinality (source: [[s-synadia-how-many-subjects]]); the maintainer's "no problem with a
lot of subjects" is about reads and writes, not restarts (source:
[[s-gh-8333-high-cardinality-subjects]]).

**The fix.** Budget the restart, keep the stop clean, and design the subject space
([[jetstream-sizing]]): a per-subject index costs RAM and restart time whether or not the messages
are large.

### 4 · The volume reads slowly

**The trap.** Every path above is a sequential read of the stream; the restore time is bytes ÷
throughput. The public report's storage was rated "> 200MB/s" and delivered 20 MB/s to one
goroutine reading 8 MB blocks. Network block storage, thin-provisioned volumes and the storage class
matter here more than anywhere else in a JetStream deployment ([[kubernetes-storage]]).

**How to confirm.** `iostat` or the node's disk metrics during the restore: a flat read rate far
below the volume's rating.

### 5 · A server older than 2.11.11 / 2.12.2 recovers streams one at a time

Streams are loaded in parallel since v2.11.11 and v2.12.2 (#7482, #7526; "JetStream recovery
parallelism now matches the I/O gated semaphore"). On older servers a hundred streams recover
serially; on newer ones a single huge stream still does (source:
[[s-nats-server-filestore-recovery]]).

## The other axis: stream *count*, not stream size

Every cause above is about one large stream. The runs behind [[stream-topology-design]] measured the
other shape — many small ones — and it is the more expensive axis by a wide margin (source:
[[s-nats-server-stream-topology-observed]], runs A, A2 and R3; one laptop, so an ordering):

| what is being restarted | `Took … to start JetStream` |
|---|---|
| 1,001 streams, 280,000 messages, clean stop | **125 ms** |
| 10,000 empty streams, clean stop | **5.405 s** |
| 10,000 streams with one message each, clean stop | **5.762 s** |
| 10,000 streams, one write each since the last clean stop, after SIGKILL | **5.655 s**, with **10,000** `Filestore [E…] Stream state outdated, last block has additional entries, will rebuild` warnings — one per stream |
| one stream, 1.1 M messages, 1,005 consumers | **300.80 ms** |
| one stream, 1,000,000 distinct subjects, clean stop | **421 ms** (604.9 ms after SIGKILL) |
| **a node holding 1,000 `R3` streams** | **`/healthz` 200 in 17.985 s** — `Took 329.47ms to start JetStream` and 1,000 `Restored` lines; the remaining 17 s is Raft groups. Its SIGTERM shutdown did not finish within 10 s |

Read together with cause 3: a million subjects in one stream costs **421 ms**, and a thousand
replicated streams costs **eighteen seconds**. If recovery time is the constraint, the number of
**assets** is the term to design down, not the number of subjects.

*Confirm:* count the `Restored` lines against the wall-clock gap to `/healthz` 200; if the
`Took … to start JetStream` line is a small fraction of it, the time is in the Raft groups
([[meta-layer]]), not in the filestore.


## Prevention

- Do not leave a source configured that has nothing in the stream; review `sources` when a
  producer is retired.
- Size the restart window from the stream's bytes and the volume's *measured* read rate, per stream
  with `sources` and per stream above a million subjects — and tell the readiness probe: the report's
  pod was unready for six minutes because the probe was right.
- Stop cleanly, always; treat any `Filestore [<stream>] Stream state …` warning as a signal that the
  last stop was not.
- Plan the 2.15 upgrade for sourcing-heavy deployments; that release is where cause 1 ends.

## Explained by

[[filestore-layout]] — `index.db`, the block files, and what recovery reads.
[[mirrors-and-sources]] — what a sourcing stream does at every start.

## Version notes: the 2.10 line

- 2.10.0 rewrote filestore meta indexing, "significantly reducing time to recover streams at
  startup" (#4450, #4481), and 2.10.10 replaced the per-subject map with the subject tree (#4960,
  #4983 — since 2.10.10, not 2.10.9; see [[filestore-layout]]) (source: [[s-relnotes-2.10]]).
- `index.db` recovery fixes: 2.10.7 (per-subject tracking corrupted on a bad or missing `index.db`,
  #4851), 2.10.8 (corrupt subjects detected, #4890; no snapshots before recovery completes, #4927),
  2.10.21 ("improvements to recovering from old or corrupted `index.db`", #5893, #5901, #5907),
  2.10.26 (the delete map cleaned on compaction so `index.db` recovers, #6515).
- 2.10.23: metalayer recovery "will now more reliably group assets for creation/update/deletion …
  reducing the chance of ghost consumers and misconfigured streams happening after restarts"
  (#6066, #6069, #6088, #6092); "Sourcing consumers for R1 streams will now be set up inline when the
  stream is recovered" (#6219).
- 2.10.28: temporary files from stream compression are ignored on recovery "so that the same blocks
  do not get loaded more than once" (#6684).


### The 2.11 line

- **2.11.11: streams are loaded in parallel** when JetStream is enabled, "often reducing the time it
  takes to start up the server" (#7482), and recovery parallelism matches the I/O semaphore (#7526)
  (source: [[s-relnotes-2.11]]).
- **2.11.12**: "The scan for the last sourced message sequence when setting up a subject-filtered
  source is now considerably faster" (#7553) — the backward scan measured on this page.
- **2.11.7**: a stale `index.db` after a block delete and an unclean shutdown is now recognised as
  lost data and the index rebuilt (#7123). **2.11.10**: blocks with out-of-order sequences from disk
  corruption recovered (#7303, #7304), with more useful error messages (#7305). **2.11.9 → 2.11.10**:
  meta snapshot performance with very many assets regressed and was fixed (#7350).


### The 2.12 line

**2.12.3**: the meta layer stages and deduplicates recovery operations at startup (#7540).
**2.12.8**: "scanning for the starting sequence for consumers is now an asynchronous operation
which no longer pauses the metalayer" (#8051). **2.12.14**: the disk I/O semaphore that bounds the
parallel recovery task queue rose to 4096 slots (`max_concurrent_io`, #8336). **2.12.5**: tombstones
always used for trailing deletes (#7782) and a race rebuilding block state (#7783) (source:
[[s-relnotes-2.12]]).


### The 2.14 line, and the preview

- **2.14.0**: recovery from a partial purge after a hard kill (#7676); a Raft node **refuses to start**
  on a missing, corrupt or misaligned snapshot (#7566, #7580, #7620) — not slow, stopped, and on
  purpose (source: [[s-relnotes-2.14]]). **2.14.1**: temporary snapshots ignored on recovery after a
  crash (#8101). **2.14.2**: the block-skip check disabled above a million subjects (#8227).
  **2.14.4**: `max_concurrent_io` bounds the recovery task queue (#8336); **blocks with unsynced or
  truncated key files are removed and counted as lost data "instead of failing to recover
  altogether"** (#8365). **2.14.6**: snapshots no longer prevented on a clean shutdown (#8465) — a
  clean stop that recovered block by block was this; the stream's created time survives recovery on
  a standalone server (#8471).
- **2.15 preview**: `sources.db` (#8282) ends cause 1; the `js_snapshot_sources` flag ("Introduced:
  2.15.0", off) carries the index in stream snapshots (source: [[s-relnotes-2.15-preview]]).


## Related

[[jetstream-sizing]] · [[kubernetes-storage]] · [[upgrade-a-cluster]] · [[stream]] ·
[[nats-server-2.15-preview]] · [[nats-server-2.12]] · [[consumer-slow-on-a-sparse-stream]]

## Sources

[[s-gh-8001-jetstream-startup-slow-50m]] · [[s-nats-server-filestore-recovery]] ·
[[s-nats-server-stream-scale-observed]] · [[s-gh-8333-high-cardinality-subjects]] ·
[[s-synadia-how-many-subjects]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]] · [[s-relnotes-2.15-preview]] · [[s-nats-server-stream-topology-observed]]
