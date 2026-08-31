---
title: "nats-server v2.14.6 — the filestore on disk"
type: summary
area: [jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/filestore-v2.14.6.md
author: nats-io/nats-server contributors
article: "server/filestore.go, stream.go, memstore.go at v2.14.6, plus eleven runs on the v2.14.6 binary (raw/nats-server-src/filestore-observed-v2.14.6.md)"
date: 2026-08-31
version: "2.14.6"
tags: [filestore, block-size, emptyRecordLen, index.db, tombstone, compaction, disk, sizing, psim]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — the filestore on disk

Read to answer the two oldest open sizing questions in `inbox/question-bank.md`: **Q2**, what a
stream costs on disk beyond the raw message bytes, and the disk half of **Q1**, sizing a cluster.
Every structural claim is a line of `nats-server` at tag **v2.14.6** (ranges in
`raw/nats-server-src/filestore-v2.14.6.md`); every number was then **measured on the v2.14.6 binary**
with **nats CLI 0.4.0** (runs in `raw/nats-server-src/filestore-observed-v2.14.6.md`).

## Key claims

### A message costs exactly 30 bytes plus its subject, on top of payload and headers

`fileStoreMsgSizeRaw` (`filestore.go:9821–9828`):

```
no headers:    rl = 22 + len(subject) + len(payload) + 8
with headers:  rl = 22 + len(subject) + 4 + len(headers) + len(payload) + 8
```

The 22 is `msgHdrSize` — `total_len(4) seq(8) ts(8) subj_len(2)` — and the 8 is `checksumSize`, a
highwayhash64 over the record. Together they are `emptyRecordLen = 30` (`filestore.go:1118–1122`),
which is also the exact size of a delete tombstone.

Measured: a 100-byte payload on the 4-character subject `sz.a` moved `state.bytes` by **134**; the
same message with one header `k:v` by **156** (the stored header is the 18-byte wire block
`NATS/1.0\r\nk: v\r\n\r\n`, plus the 4-byte length field); on a 28-character subject by **158**.

**`nats stream info` already reports these bytes**, not payload bytes: `updateAccounting`
(`filestore.go:7696–7700`) adds the whole record length `rl` to `mb.bytes`. So `max_bytes`,
`/jsz storage` and an account's `MaxStore` are all counted in record bytes, and *payload* bytes are
never reported anywhere.

### A memory stream counts different bytes for the same message

`memStoreMsgSizeRaw` (`memstore.go:2334–2336`) is `slen + hlen + mlen + 16` — sixteen bytes, and no
4-byte header-length field. Measured: the same 100-byte payload reports **121 B** in a memory stream
against **135 B** in a file stream. The two `bytes` figures are not comparable.

### The block file is a bare concatenation of records — nothing else

10,000 × 134-byte records produced a `1.blk` of **exactly 1,340,000 bytes**. No file header, no
padding, no index file. Decoding the first record straight out of the file reproduces the format in
the comment above `writeMsgRecordLocked` (`filestore.go:7502–7506`) byte for byte, including the
high bit of `total_len` used as the has-headers flag.

The directory is `<store_dir>/jetstream/<account>/streams/<stream>/`, holding `meta.inf` (~500 B),
`meta.sum` (16 B), `msgs/<n>.blk`, `msgs/index.db`, and `obs/<consumer>/{meta.inf,meta.sum,o.dat}`
(names at `filestore.go:302–327`).

### Deleting a message makes the file bigger; only a purge frees it

A delete leaves the record in place and appends a 30-byte tombstone. Measured over five
`nats stream rmm`: `state.bytes` fell by 670 (5 × 134) while `1.blk` **grew** by 150 (5 × 30).

`nats stream purge` is different: the block was removed outright and replaced by a fresh block
holding one 30-byte tombstone, 1,340,150 bytes → 30. A purge also forces `index.db` to be written.

### A block is only rewritten when more than half of it is dead — and never if it is the last one

`shouldCompactInline` (`filestore.go:6254–6256`) needs `rbytes > compactMinimum` (2MB) **and**
`bytes*2 < rbytes`. `shouldCompactSync` (`filestore.go:6262–6264`) drops the 2MB floor and runs on
the periodic sync, every `sync_interval` (**default 2m**, `filestore.go:331–332`).

Both call sites exclude the last block: `!isLastBlock && …` (`filestore.go:6151`) and
`mb != lmb && …` under the comment `// Do not compact last mb.` (`filestore.go:8037–8039`).

Measured, three outcomes on the same server:

| stream | reported | on disk | ratio | why |
|---|---|---|---|---|
| `B1M` right after filling | 1,048,572 | 4,655,000 | 4.44 | first block half dead, not yet swept |
| `B1M` one `sync_interval` later | 1,048,572 | 1,048,572 | **1.00** | swept: 4,194,288 → 587,860 |
| `B100K` | 102,277 | 111,720 | **1.09**, stable | oldest block only 30% dead |
| `NPER`, then idle | 133,000 | 1,125,712 | **8.47**, stable | it is the last block |

`NPER` was re-checked after a full sync interval **and** a server restart: unchanged.

### The block size is chosen for you, and there is no way to read it back

`autoTuneFileStorageBlockSize` (`stream.go:1412–1443`) runs first and falls through to `dynBlkSize`
(`filestore.go:816–851`) only when the stream sets none of `max_bytes`, `max_msgs`,
`max_msgs_per_subject`. Both use `(size / 4) + 1` rounded up to 100, then clamp to one of exactly
three values: **32,000** (`FileStoreMinBlkSize`), **4MB** (`defaultMediumBlockSize`) or **8MB**
(`FileStoreMaxBlkSize`, also `maxBlockSize`). Everything between the floor and the cap collapses to
4MB.

Measured, by watching where blocks roll:

| stream shape | block size |
|---|---|
| `max_bytes: 100KB` | 32,000 |
| `max_bytes: 1MB` | **4MB** |
| `max_bytes: 100MB` | 8MB |
| nothing set, `limits` retention | 8MB |
| `max_msgs: 100000`, nothing else | 8MB |
| `max_msgs_per_subject` set (any stream, and **every KV bucket**) | 4MB (`defaultKVBlockSize`) |

A record never straddles a block: `checkLastBlock` (`filestore.go:7705–7712`) rolls first, so a full
block is always `BlockSize` minus less than one record. `nats stream info --json` reports no block
size at all.

### `index.db` costs about `len(subject) + 4` per subject

`_writeFullState` (`filestore.go:12038–12057`) writes the stream summary, then one record per
subject (the loop at `filestore.go:12050–12056`) — `uvarint(len) + subject + uvarint(total) + uvarint(fblk) + uvarint(lblk)` — then one per
block. Written by `flushStreamStateLoop` every **2 minutes plus up to 30 s of jitter**
(`filestore.go:11904–11906`), forced on purge and on a clean shutdown.

Measured on two streams: 20,000 subjects → 268,964 B and 40,000 subjects → 708,987 B, both landing
on **4.0 bytes per subject beyond the subject text itself**. A million 40-character subjects is
therefore ~44 MB of `index.db` per replica, rewritten every two minutes.

Above **1,000,000** subjects or 1,000,000 interior deletes the unforced write returns `errStateTooBig`
and is skipped (`highCardinalityThreshold`, `filestore.go:388–390`, checked at
`filestore.go:12006–12009`).

### Consumer state is bounded by `max_ack_pending`, not by stream size

Measured `o.dat`: **8 B** fresh, **213 B** at 50 pending, **2,762 B** at 500 pending — roughly 5–6
bytes per outstanding message, on a 70,000-message stream.

### `/jsz` and `/varz` report the logical figure, not disk

Ten streams: `/jsz` `storage` **37,891,637**, exactly the sum of the ten `state.bytes`. The tree on
disk was **39,881,215** — 5.25% more. `reserved_storage` was the sum of the `max_bytes` of the four
streams that set one, stored or not.

`/jsz` also prints `config.sync_interval` (`120000000000`), which is the compaction cadence above.

### Recovery, honestly

Same 279,653-message, 39 MB store: **22.1 ms** with `index.db` present, **24.6 ms** after deleting
every `index.db`. **No measurable difference at this size.** This says nothing about the
tens-of-millions case; it is recorded so that no one derives a claim from it.

## Practical takeaways

- **Size disk from `(payload + headers + subject + 30) × messages`**, then add the physical slack
  below. Payload alone under-counts by 30 bytes plus the subject on every message — which is 35% on
  a 100-byte message with a five-character subject and 0.05% on a 100 KB one.
- **The reported bytes are a floor on disk, never a ceiling.** Budget **one whole block size** of
  slack per stream on top of the logical figure — 8MB for a default `limits` stream, 4MB for a KV
  bucket — because the last block is never compacted.
- **`max_file_store` does not protect the volume.** It bounds the same logical figure. A server
  configured `max_file_store: 4MB` was measured holding 3.79 MB on disk while reporting 133,000
  bytes used (3%).
- **Compression, encryption and per-message TTLs all sit on top of this** and were deliberately off
  in every run, so these are the floor numbers.

## Notable quotes

From the source, verbatim:

> `// Do not compact last mb.` — `filestore.go:8037`

> `rbytes      uint64 // Total bytes (raw) including deleted. Used for rolling to new blk.` —
> `filestore.go:239`

## Relevance to the wiki

The last unquantified term in [[jetstream-sizing]]. It also supplies the mechanism behind the
disk-versus-reported gap that [[jetstream-out-of-disk]] describes symptomatically, and it is the
first source in this wiki that lets [[stream-compression]]'s "measure it with `du`" advice be
interpreted, because it says what `du` is being compared against.

## Questions it answers

**Q1** (the disk term, which was the blocker; IOPS remains unsourced) and **Q2** (in full). It
also strengthens **Q72** — why deleting keys does not reclaim disk in a KV bucket — with the block
mechanism behind it.

It does **not** answer **Q9** ("does a high-cardinality subject space hurt *performance*?"): it gives
the storage cost of cardinality and the 1,000,000-subject `index.db` cut-off, not a latency or
throughput figure. That row stays open.

## Pages touched

[[filestore-layout]] (created) · [[jetstream-sizing]] · [[stream]] · [[key-value]] ·
[[stream-compression]] · [[jetstream-out-of-disk]] · [[defaults-and-limits]] ·
[[monitoring-endpoints]] · [[consumer]]
