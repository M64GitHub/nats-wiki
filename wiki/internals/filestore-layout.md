---
title: Filestore layout on disk
type: internals
area: [jetstream, deploy]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [filestore, block-size, index.db, tombstone, compaction, disk, sizing, psim, o.dat]
aliases: [filestore, file store, blocks, blk, msg blocks, index.db, on-disk layout, storage overhead, bytes per message]
sources: [s-nats-server-filestore-layout, s-adr-35-filestore-compression, s-nats-server-jetstream-resources, s-nats-server-object-store-observed, s-docs-object-store-chunking, s-docs-object-store-under-the-hood]
created: 2026-08-31
updated: 2026-08-31
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
   in-memory `psim` tree — independent of message count. See [[stream]].
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
  measurement narrows.
