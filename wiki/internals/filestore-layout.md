---
title: Filestore layout on disk
type: internals
area: [jetstream, deploy]
verified-against: nats-server 2.14.6
verified-on: 2026-09-02
tags: [filestore, block-size, index.db, tombstone, compaction, disk, sizing, psim, o.dat]
aliases: [filestore, file store, blocks, blk, msg blocks, index.db, on-disk layout, storage overhead, bytes per message]
sources: [s-nats-server-filestore-layout, s-adr-35-filestore-compression, s-nats-server-jetstream-resources, s-nats-server-object-store-observed, s-docs-object-store-chunking, s-docs-object-store-under-the-hood, s-nats-server-mirror, s-gh-8417-kv-mirror-file-vs-memory, s-relnotes-2.14.4, s-nats-server-mirrors-observed, s-gh-8444-mirror-catchup-under-a-reader, s-nats-server-filestore-recovery, s-nats-server-stream-scale-observed, s-gh-5202-max-unique-subjects, s-gh-8001-jetstream-startup-slow-50m, s-gh-8333-high-cardinality-subjects, s-synadia-how-many-subjects, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12]
created: 2026-08-31
updated: 2026-09-03
---

# Filestore layout on disk

What a file-storage stream actually writes under `store_dir`, and why the number `nats stream info`
prints is **never** the number `du` prints. This is the page behind the disk term in
[[jetstream-sizing]].

Everything here is `nats-server` **2.14.6**, read at the tag and then **measured on the binary**
(source: [[s-nats-server-filestore-layout]]). Compression, encryption and TTLs were off in every
run, so these are floor numbers — see [[stream-compression]].

## What the server does

### The directory

```
<store_dir>/jetstream/<account>/streams/<stream>/
    meta.inf              the stream config, JSON            ~500 B
    meta.sum              its checksum                        16 B
    msgs/1.blk            message block 1
    msgs/2.blk            message block 2 …
    msgs/index.db         the full-state snapshot
    obs/<consumer>/meta.inf, meta.sum, o.dat
```

Names are `filestore.go:302–327`. There is no per-message file and no separate index per block; a
`.blk` file is a **bare concatenation of records** with no file header and no padding.

### One record

```
no headers:   total_len(4) seq(8) ts(8) subj_len(2) subj           msg hash(8)
with headers: total_len(4) seq(8) ts(8) subj_len(2) subj hdr_len(4) hdr msg hash(8)
```

The high bit of `total_len` is the has-headers flag; `hash` is a highwayhash64 over
`seq‖ts‖subj‖hdr‖msg`. So:

```
record bytes = 30 + len(subject) + len(payload) + (headers ? 4 + len(headers) : 0)
```

**30 = 22 + 8** (`msgHdrSize` + `checksumSize` = `emptyRecordLen`, `filestore.go:1118–1122`). The
same constant is the size of a **delete tombstone**.

The first record of a real block file, decoded:

| bytes | field | value |
|---|---|---|
| 0–3 | `total_len`, LE uint32 | `0x87` = 135 |
| 4–11 | `seq`, LE uint64 | 1 |
| 12–19 | `ts`, LE int64, unix nanos | 2026-08-31T07:12:12.289910Z |
| 20–21 | `subj_len`, LE uint16 | 5 |
| 22–26 | subject | `big.a` |
| 27–126 | payload | 100 bytes |
| 127–134 | highwayhash64 | `9a9873f5deaf5f84` |

### The reported bytes are record bytes, not payload bytes

`updateAccounting` adds the whole record length to the block's `bytes`, and that is what surfaces as
`state.bytes`. Everything that meters a stream — `max_bytes`, `/jsz` `storage`, an account's
`MaxStore` — meters this figure. **Payload bytes are never reported anywhere.**

A memory stream uses a different formula, `len(subject) + len(headers) + len(payload) + 16`
(`memstore.go:2334–2336`), so the same message is **135 B** in a file stream and **121 B** in a
memory stream. Do not compare the two.

### Blocks roll; records never straddle one

`checkLastBlock` opens a new block *before* writing a record that would overflow the current one, so
a full block is always `BlockSize` minus less than one record. A single record larger than the whole
block gets a block to itself.

**The block size is chosen for you and cannot be read back through the API.**
`autoTuneFileStorageBlockSize` (`stream.go:1412–1443`) runs first; `dynBlkSize`
(`filestore.go:816–851`) handles the rest. Both compute `(size / 4) + 1`, round up to 100, then clamp
to exactly one of three values:

| stream sets | block size | constant |
|---|---|---|
| `max_bytes` resolving to ≤ 32,000 | **32,000** | `FileStoreMinBlkSize` |
| `max_bytes` resolving between the two | **4MB** | `defaultMediumBlockSize` |
| `max_bytes` resolving to ≥ 8MB | **8MB** | `FileStoreMaxBlkSize` |
| `max_msgs` only | `max_msg_size` (or `max_payload`, or 1MB) × `max_msgs`, then the same clamp | |
| `max_msgs_per_subject` only — **every KV bucket** | **4MB** | `defaultKVBlockSize` |
| nothing, `limits` retention | **8MB** | `defaultLargeBlockSize` |
| nothing, any other retention | **4MB** | `defaultMediumBlockSize` |
| encryption on, and the filestore picks the size | capped at **2MB** | `maximumEncryptedBlockSize` |

The middle branch surprises people: **a stream with `max_bytes: 1MB` is given a 4MB block**, four
times its own limit. Measured across seven stream shapes; the observed roll points are in
[[s-nats-server-filestore-layout]].

The encryption cap lives in `dynBlkSize`, which only runs when `autoTuneFileStorageBlockSize` left
the size at zero. Whether an encrypted stream that sets `max_bytes` therefore gets a block over 2MB
was not tested **(unverified)**.

### Deleting a message makes the file bigger

A delete does not remove the record. It appends a **30-byte tombstone** and marks the sequence
deleted. `bytes` (reported) goes down; `rbytes` (what the file holds) goes **up**
(`filestore.go:238–240`).

Space comes back only when a block is **compacted** — rewritten without its dead records — or
removed entirely:

- **inline**, on the delete path, when the block is over **2MB** *and* more than half of it is dead
  (`shouldCompactInline`, `filestore.go:6254–6256`);
- **on the periodic sync**, every `sync_interval` (**default `2m`**), with the 2MB floor dropped but
  the half-dead test kept (`shouldCompactSync`, `filestore.go:6262–6264`);
- **whole-block removal**, when every record in a block is dead.

**Neither compaction path touches the last block.** `filestore.go:6151` guards with `!isLastBlock`;
`filestore.go:8039` guards with `mb != lmb` under the comment `// Do not compact last mb.` A stream
that discards most of its newest block and then goes quiet keeps that block, in full, until enough
new messages arrive to roll a block behind it.

`nats stream purge` is the exception that does free disk at once: the blocks are removed and a fresh
block is started holding a single tombstone carrying the sequence floor. Measured: 1,340,150 bytes →
30.

**Whole-block removal is why a bulk delete feels instant, and the last-block guard is why it is not
quite.** Deleting a 200 MiB object from an object-store bucket on 2.14.6 — 1,600 chunk messages
purged in one operation — took the stream directory from **204,912 KB to 3,212 KB at the call**, and
left it there through samples at 2, 10, 30 and 60 seconds. The residue was a single 3,279,785-byte
`.blk`: the last block, which neither compaction path will touch. This is the mechanism behind a
warning the docs give qualitatively — that after a delete "the on-disk space is reclaimed as the
stream cleans up, not synchronously at the call" (source: [[s-docs-object-store-under-the-hood]]) —
and the measurement narrows it: the part that is *not* synchronous is one block, not the object. So **98.4 % of the bytes returned
synchronously**, and what lingered was bounded by one block rather than by the size of what was
deleted (source: [[s-nats-server-object-store-observed]]). On a second bucket the residue was two
blocks (13,460 KB), still present at +5 s and down to 4,760 KB when sampled roughly four minutes later
with no other activity — the trailing blocks do go, on the sync path, once a block rolls behind them.

The operator-facing version of this is on [[object-store]]: size an object bucket for one block of
residue after a delete, not for the object.

### Per-message overhead at object-store chunk sizes

The record overhead here is what makes a chunk size choice a storage decision. At the object store's
**128 KiB** default a 200 MiB object occupied **204,912 KB on disk for 209,819,520 bytes of payload —
about 2.4 %**, because only 1,601 messages carry it. Halving the chunk size doubles the message count
and doubles that share; the docs page that raises per-message overhead as a reason not to shrink the
chunk size never states a figure, which is why this one is measured here (source:
[[s-nats-server-object-store-observed]], and [[s-docs-object-store-chunking]] for the claim it
quantifies). The arithmetic is the record format above: every chunk pays the same fixed record cost
whatever its payload.

### `index.db`, the full-state snapshot

Written by `flushStreamStateLoop` every **2 minutes plus up to 30 seconds of jitter**, and forced on
purge and on a clean shutdown. It holds the stream summary, then **one record per subject** —
`uvarint(len) + subject + total + fblk + lblk` — then one per block with its deleted map.

```
index.db ≈ Σ over subjects (len(subject) + 4) + ~8 per block + a small header
```

Above **1,000,000** subjects or 1,000,000 interior deletes the unforced write is skipped with
`errStateTooBig` (`highCardinalityThreshold`, `filestore.go:388–390`), so a very high-cardinality
stream stops getting one.

### Consumer state

`obs/<consumer>/o.dat` holds the delivered/ack-floor/pending position, not messages. It is bounded
by the ack-pending set, so by `max_ack_pending` — see [[ack-and-redelivery]].

### Interior deletes, and what they cost a reader

A KV overwrite, a per-subject limit, a purge by subject: each removes a message from the *middle*
of the sequence space. The record stays in its block (the tombstone above), the sequence goes into
the block's **delete map** (`mb.dmap`, an AVL sequence set), and it stays there for as long as the
block lives — compaction prunes deletes at a block's head and tail, never interior ones. **A block
never starts with a deleted sequence**: "`1.blk` would start at sequence 1, and have deleted entries
stored in its `mb.dmap` from 1000-1999 … `2.blk` would start at sequence 2000" (source:
[[s-gh-8417-kv-mirror-file-vs-memory]]). A KV bucket with a hot key space therefore spends most of
its sequence range on holes — 83 % in the public report, 75 % in another — while its message count
stays flat.

**What that costs on the read path** (`firstMatching`, `filestore.go:3031–3150` at 2.14.6, source:
[[s-nats-server-mirror]]). A consumer with a wildcard filter is served either by a *linear scan* of
the block, skipping `dmap` entries, or by a walk of the block's per-subject state (`fss`) to find
the next matching subject. The choice:

```go
  3095		doLinearScan := isAll || (wc && len(subjs) == 1 && subjs[0] == filter)
  3100		if !doLinearScan && wc && mb.cacheAlreadyLoaded() {
  3101			doLinearScan = mb.fss.Size()*4 > int(lseq-fseq)
  3102		}
```

`isAll` is an empty filter or `>`; the second clause is true when the filter *is* the stream's only
subject (a KV bucket's own `$KV.<bucket>.>`). Otherwise the block is scanned linearly only if it
holds fewer than four sequences per subject — measured on the **sequence range, holes included**. A
sparse block fails that test, and every message lookup becomes an `fss.Match` over the block's
subjects. On a **mirror** — a stream with `subjects: null` — even the bucket's own filter takes that
path. Measured on 2.14.6: a filter that matches everything read a file mirror at 267,866 msg/s where
no filter read it at 1,740,462; on the origin the same filter cost nothing; at 1 M subjects over 4 M
sequences the gap was 9.4× (source: [[s-nats-server-mirrors-observed]]). The symptom page is
[[consumer-slow-on-a-sparse-stream]].

**What it costs a writer that is a mirror.** A mirror records each upstream hole itself with
`SkipMsgs` (`filestore.go:5465–5530`): under the store's exclusive lock it inserts every skipped
sequence into the last block's `dmap`, starts a new block when that map would pass **64 K** entries,
and writes one 30-byte placeholder record. So a mirror of a sparse stream takes the write lock twice
per live message — once for the gap, once for the message — against readers whose `LoadNextMsg`
holds the read lock for a whole block walk (`9427–9433`). Three readers scanning a mirror during its
catch-up made the catch-up 3.4–3.9× slower on file storage (and 3.1–3.4× on memory, so on that host
the lock is not the whole story; source: [[s-nats-server-mirrors-observed]],
[[s-gh-8444-mirror-catchup-under-a-reader]]).

**What 2.14.4 changed.** "Calculating and looking up sequences in delete maps for file-backed
streams with large numbers of interior deletes is now faster and holds locks for less time (#8403)",
faster AVL sequence sets (#8406), and snapshot buffers sized up front for streams "with large
numbers of interior deletes" (#8405); v2.14.2 fixed the per-subject state's last block for
`max_msgs_per_subject: 1` (#8254) (source: [[s-relnotes-2.14.4]]). The linear-scan heuristic is
unchanged at 2.14.6.

**What a mirror does to the layout.** Because it replays live messages in order, a file mirror
re-packs: the same 400,000 messages that occupied 51 block files and 128,220 KB on the origin (2.2×
the reported bytes) occupied 29 files and 58,536 KB on the mirror (1.0×); the public report saw
81 % against 98 % live bytes (sources: [[s-nats-server-mirrors-observed]],
[[s-gh-8417-kv-mirror-file-vs-memory]]). It reads no faster for it.


### Recovery at startup: what `index.db` buys, and the five lines that say it was refused

When the server starts, each file store tries `index.db` first and reads the blocks only if that
fails (`newFileStoreWithCreated`, `filestore.go:509–549` at 2.14.6). The index path reads one file:
the stream summary, then the per-subject index rebuilt entry by entry into the in-memory tree, then
one record per block **without opening any block**. It is trusted after four checks — the file's
HighwayHash, that the last block it names exists, that the block's **last record checksum** still
equals the one saved, and that no higher-numbered block exists (`recoverFullState`, `:1927–2216`).
Any failure is a `[WRN] Filestore [<stream>] …` line and the fallback reads **every `<n>.blk` end to
end**, verifying each record's hash and rebuilding the per-block and per-stream subject state
(`recoverMsgs` → `recoverMsgBlock` → `rebuildState`, `:2454–2563`, `:1232–1322`, `:1558–1620`)
(source: [[s-nats-server-filestore-recovery]]).

| the warning | what it means |
|---|---|
| `Stream state outdated, last block has additional entries, will rebuild` | writes landed after the last `index.db` — a SIGKILL, an OOM kill, a crash; the common one |
| `Stream state outdated, found extra blocks, will rebuild` | a block was created after the file |
| `Stream state checksum did not match` | the file itself is damaged; it is deleted |
| `Stream state detected prior state, could not locate msg block N` | a block the file names is gone; its messages are counted as lost |
| `Stream state encountered internal inconsistency on recover` | the summary and the blocks disagree; the file is deleted |
| *(nothing)* | either the index was taken, or **there was no file** — a missing `index.db` is silent |

Each of them is followed by `Recovering stream state from index errored: …`. Measured on 2.14.6 with
50 M messages / 6.8 GB in 800 blocks (source: [[s-nats-server-stream-scale-observed]]):

| the stop | `Restored … in` | reads |
|---|---:|---|
| clean, disk idle (six restarts) | **3–27 ms** | none — one 23 KB file |
| clean, within seconds of a 6 GB bulk write | 1.8–7.0 s | the same path; the disk busy with write-back. Not isolated further |
| SIGKILL after new writes | **6.4 s** | every block, 1.0–1.6 GB/s; the goroutine in `rebuildState` (read, hash, tree insert) |
| clean, then `index.db` deleted | **9.5 s** | every block, no warning |

Two things shape those numbers. **Subjects**: rebuilding the tree from the file is not free at high
cardinality — 3.2 M messages over 1.2 M subjects took 153 ms on the index path against 1.02 s on the
full read, where six subjects took 2 ms against 303 ms — and above 1,000,000 subjects the periodic
write is skipped, so an unclean stop always means the full read. **Sources**: the `Restored … in`
timer also wraps the source scan a stream with `sources` makes on an R1 server, which can dwarf the
store's own recovery — the row-13 thread's 6 min 38 s was that, not this ([[mirrors-and-sources]],
[[jetstream-recovery-is-slow]]; source: [[s-gh-8001-jetstream-startup-slow-50m]]). The in-memory
tree is an adaptive radix tree since 2.10.10 (the maintainer who described it said 2.10.9; the source tree says 2.10.10 — see *The 2.10 line* below), with a message count and a first and last block per
subject (source: [[s-gh-5202-max-unique-subjects]]).

Streams are recovered in parallel across streams — one task queue of `min(64, max_concurrent_io)`
workers since 2.11.11 / 2.12.2 — and serially within one stream.


## What you can observe

```
# the logical figure — record bytes, what every limit is enforced against
nats stream info ORDERS --json | jq '.state | {messages, bytes, num_subjects, num_deleted}'

# the physical figure — what the volume actually gave up
du -sb /var/lib/nats/jetstream/ORDERS_ACCOUNT/streams/ORDERS/
ls -l  /var/lib/nats/jetstream/ORDERS_ACCOUNT/streams/ORDERS/msgs/

# the same logical figure, server-wide, plus the compaction cadence
curl -s localhost:8222/jsz | jq '{storage, reserved_storage, config: .config.sync_interval}'
```

| you see | it means |
|---|---|
| `du` ≈ `state.bytes` | steady state; nothing is owed |
| `du` up to one block size above | the normal resting state — the last block is partly dead |
| `du` several times `state.bytes` on an **idle** stream | the last block is mostly dead and will not be swept until traffic resumes |
| `du` several times `state.bytes` on a **busy** stream | a block is over half dead and under the 2MB floor, or the sync pass has not run yet; give it one `sync_interval` |
| `1.blk` missing, numbering starting high | older blocks were removed whole by retention — normal |
| `.blk` file bigger than `block_size` | one record was larger than the block |
| no `index.db` | it has not been written yet, or the stream is over the cardinality threshold |

The first and last rows below were **measured**; the two middle rows are the same verified
formula applied to other message shapes (all `nats-server 2.14.6`, R1, no compression):

| shape | reported ÷ payload | disk ÷ reported |
|---|---|---|
| 100 B payload, 5-char subject | **1.35** | 1.00 → up to 1 block of slack |
| 1 KB payload, 20-char subject | 1.049 | as above |
| 100 KB payload, 20-char subject | 1.0005 | as above |
| 20,000 subjects, `index.db` (measured) | — | +268,964 B for the file |
| idle stream, last block 99% dead | — | **8.47** (measured, stable) |

## Why an operator cares

1. **Disk sizing.** Payload bytes under-count by `30 + len(subject)` per message — 35% on a
   100-byte message with a five-character subject, 0.04% on a 100 KB one. [[jetstream-sizing]] uses this.
2. **`max_file_store` does not protect the volume.** It bounds the logical figure. A server
   configured `max_file_store: 4MB` was measured holding 3.79 MB on disk while reporting **133,000
   bytes used** — 3% of its own ceiling. Recorded as docs issue #33. See [[jetstream-out-of-disk]].
3. **"I deleted messages and nothing was freed."** Expected: deletes make the file bigger, and only
   a half-dead block gets rewritten. The last block never does.
4. **High-cardinality subjects cost per subject, twice** — once in `index.db` on disk, once in the
   in-memory `psim` tree — independent of message count. The in-memory side is "in the order of 100
   megs of RAM" per million small subjects by a maintainer's estimate and "roughly a few hundred
   bytes" each by Synadia's (sources: [[s-gh-8333-high-cardinality-subjects]],
   [[s-synadia-how-many-subjects]]); ~380 B of RSS each was measured. And a third time at restart,
   above a million. See [[stream]] and [[jetstream-sizing]].
5. **`du` and `/jsz` will always disagree**, and the gap is not a leak.
6. **Compression's ratio can only be measured** by comparing these two numbers, which is what
   [[stream-compression]] tells you to do.

## Version notes

- Read and measured at **2.14.6**. `index.db` is at `fullStateVersion = 4`; the server parses
  versions 1–4, so a store written by an older server is readable.
- **2.12** changed the filestore's cache to elastic pointers, which alters RSS but not any figure on
  this page — see [[jetstream-sizing]].
- Block-size selection, `emptyRecordLen` and the record format have been stable across 2.10–2.14 as
  far as the sources read here go; nothing older than 2.14.6 was measured **(unverified)**.

- **Recovery** read at **2.14.6**: `recoverFullState`, its four checks and five warnings, the fallback
  `recoverMsgs`, and `highCardinalityThreshold`'s three uses (the periodic `index.db`, the block skip on
  filtered reads since v2.14.2 / v2.12.10, interior deletes) — all measured on the binary the same day
  (sources: [[s-nats-server-filestore-recovery]], [[s-nats-server-stream-scale-observed]]). **2.15**
  adds `sources.db` at the stream's root for sourcing streams; nothing in the store format changes
  for streams without sources.


### The 2.10 line

- **The subject tree is since 2.10.10** — `fileStore.psim` is `map[string]*psi` at v2.10.9 and
  `*stree.SubjectTree[psi]` at v2.10.10, `server/stree/` absent at v2.10.9; the 2.10.10 body lists it
  as "NumPending calculations and subject index memory in filestore and memstore" (#4960, #4983).
  Message-block subject indexing moved onto stree in 2.10.17 (#5559), with `node48` (#5585); `node10`
  for numeric subject spaces came in 2.10.23 (#6106) (source: [[s-relnotes-2.10]]; evidence in
  `raw/nats-server-src/stree-arrival-v2.10.10.md`).
- `index.db`: full-state writes throttled to a separate goroutine (2.10.5, #4731) and their minimum
  interval raised (2.10.7, #4858); recovery of a bad or missing `index.db` fixed for per-subject
  tracking (2.10.7, #4851) and corrupt subjects (2.10.8, #4890); the full state written before
  snapshotting (2.10.4, #4699); recovery "from old or corrupted `index.db`" (2.10.21, #5893, #5901,
  #5907).
- Blocks and tombstones: tombstones held for previous blocks on compact (2.10.16, #5426); a "large
  number of message delete tombstones will no longer result in unusually large message blocks on
  disk" (2.10.22, #5973); tombstones written on purge and compact so deleted messages do not return
  after an index rebuild (2.10.28, #6685); a new last block generated before the final one is
  removed, so sequence numbers survive an interruption (2.10.28, #6778).
- Sync: `sync_interval` and `sync: always` controllable since 2.10.0 (#4483); metadata `O_SYNC` under
  `always` since 2.10.19 (#5729); filestore sync timers spread (2.10.23, #6128); JetStream shuts down
  on a read-only store since 2.10.25 (#6292).


### The 2.11 line

- **Encryption**: 2.11.6 fixed a block corrupted "if a write took place before a read after
  restarting the server" (#7008); 2.11.7 made cipher conversion work with compression (#7099);
  2.11.12 recovers keys independently of the index, "fixing some cases where the key could be reset
  unexpectedly if the index is rebuilt" (#7678) (source: [[s-relnotes-2.11]]).
- **`index.db` and blocks**: truncate and erase consistent after a hard kill (2.11.7, #7100); a stale
  `index.db` after a block delete marked as lost data and rebuilt (2.11.7, #7123) and cleaned up on
  truncate (2.11.8, #7162); out-of-order sequences from corruption recovered (2.11.10, #7303,
  #7304); a use-after-free in the flusher (2.11.10, #7295); tombstones no longer lost with secure
  erase and the last sequence kept for tombstone-only blocks (2.11.11, #7384); off-by-one hole
  detection at a block's end (2.11.11, #7508, #7525).
- **Flush and compaction**: **`AsyncFlush` could lose pending writes after a process pause**
  (2.11.12, #7594); compactions reclaiming over half the space use an atomic write "to avoid losing
  messages if killed" (#7627); compaction adjusts a block's high and low sequences and the delete map
  (#7634); a single truncated block no longer blocks storing (#7704); `sync_always` honoured for the
  TTL and scheduling state files (2.11.11, #7385).


### The 2.12 line

- **2.12.0**: async flush by default on replicated streams (#7018, #7163) and the async persist
  mode for R1 (#7315, #7323); weak-pointer caches (#7180); write-correctness fixes "particularly when
  combined with async mode" (#7318, #7331) (source: [[s-relnotes-2.12]]).
- **2.12.1**: meta files "written using temporary staging, avoiding accidental truncation on
  crashes" (#7388); pooled write-cache allocations reused (#7346). **2.12.5**: tombstones always used
  for trailing deletes (#7782); the #7816 batch — checksums after truncation on compressed or
  encrypted stores, locks not leaked, pending calculations bounded, subject and header corruption
  avoided. **2.12.7**: purging subjects loads only the blocks in range (#8004); caches no longer
  evicted too eagerly after a write (#8009). **2.12.9**: encryption-mode conversion clears caches,
  "avoiding block-level corruption" (#8105, #8166); block-cache aliasing fixed (#8187).
- **2.12.11**: the stale-subject-state regression of 2.12.7 (#8285). **2.12.12**: **"filestore
  compaction no longer corrupts compressed or encrypted blocks"** (#8312). **2.12.14**: the disk I/O
  semaphore is 4096 slots (`max_concurrent_io`, #8336); block-cache buffers recycled when the weak
  reference is collected (#8395); AVL sequence sets faster (#8406); encryption key files "synced to
  disk more aggressively" (#8366); a cache-weakening bug that raised memory and GC pressure (#8380).


## To verify

- The **`sdm`/`SDMMeta`** (subject-delete-markers) and **`thw.db`** (TTL hash wheel) and `sched.db`
  files appear in the constants but no stream in the lab produced one; what they cost is unknown.
  See [[message-ttl]].
- **Encrypted stores** add `<n>.key` files and cap blocks at 2MB. Not measured.
- Whether the 2MB `compactMinimum` or the block-size clamps changed before 2.14 — no release note
  read so far mentions either.

## Related

[[jetstream-sizing]] · [[stream]] · [[stream-compression]] · [[jetstream-out-of-disk]] ·
[[key-value]] · [[object-store]] · [[consumer]] · [[ack-and-redelivery]] ·
[[monitoring-endpoints]] · [[defaults-and-limits]] · [[retention-policies]]

## Sources

- [[s-nats-server-filestore-layout]] — `server/filestore.go`, `stream.go` and `memstore.go` at
  v2.14.6, plus eleven runs on the v2.14.6 binary.
- [[s-adr-35-filestore-compression]] — what compression does to the blocks described here.
- [[s-nats-server-jetstream-resources]] — what `max_file_store` and the account quota compare.
- [[s-nats-server-object-store-observed]] — the bulk-delete and per-chunk overhead measurements,
  taken on an object-store bucket because it is the easiest way to make 1,600 uniform messages.
- [[s-docs-object-store-chunking]] — the docs' unquantified per-message-overhead claim these
  numbers answer.
- [[s-docs-object-store-under-the-hood]] — the qualitative disk-reclamation warning the bulk-delete
  measurement narrows. · [[s-nats-server-mirror]] · [[s-gh-8417-kv-mirror-file-vs-memory]] · [[s-relnotes-2.14.4]] · [[s-nats-server-mirrors-observed]] · [[s-gh-8444-mirror-catchup-under-a-reader]] · [[s-nats-server-filestore-recovery]] · [[s-nats-server-stream-scale-observed]] · [[s-gh-5202-max-unique-subjects]] · [[s-gh-8001-jetstream-startup-slow-50m]] · [[s-gh-8333-high-cardinality-subjects]] · [[s-synadia-how-many-subjects]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]]
