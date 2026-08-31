<!-- Runs made 2026-08-31 on nats-server v2.14.6 (Homebrew) and nats CLI 0.4.0, macOS 25.6.0 (arm64, APFS).
     Nothing is edited except the store path, which is written as <store>. -->
# nats-server v2.14.6 — what the filestore actually puts on disk

Evidence for `wiki/internals/filestore-layout.md` and for the disk arithmetic on
`wiki/operations/jetstream-sizing.md` (question-bank **Q1**, **Q2**). The source ranges these runs
confirm are in `filestore-v2.14.6.md`.

Everything below was run against a **single standalone server**, R1, file storage, no encryption and
no compression, so the numbers are the bare filestore with nothing on top.

```
nats-server: v2.14.6
nats CLI:    0.4.0
```

Server config (`s.conf`):

```
port: 4232
server_name: fslab
jetstream {
  store_dir: "<store>"
}
http: 8232
```

Every stream below was created with the same explicit shape, so no CLI default is doing hidden work:

```
nats stream add <NAME> --subjects='<subj>.>' --storage=file --replicas=1 --retention=limits \
  --discard=old --max-age=-1 --max-bytes=<B> --max-msgs=<M> --max-msgs-per-subject=<P> \
  --max-msg-size=-1 --dupe-window=2m --no-allow-rollup --no-deny-delete --no-deny-purge
```

---

## 1 · The per-message record length, three ways

Payload is exactly 100 bytes of `x`. `nats pub -J` sends **no headers** unless `-H` is given.

| what was published | subject | subject len | headers | `state.bytes` delta | `22 + slen + [4+hlen] + mlen + 8` |
|---|---|---|---|---|---|
| 1 msg, no headers | `sz.a` | 4 | — | **134** | 22+4+100+8 = 134 ✓ |
| 1 msg, `-H k:v` | `sz.a` | 4 | 18 B wire block | **156** | 22+4+4+18+100+8 = 156 ✓ |
| 1 msg, no headers | `sz.averylongsubjecttokenhere` | 28 | — | **158** | 22+28+100+8 = 158 ✓ |

The 18-byte header block is the wire form `NATS/1.0\r\nk: v\r\n\r\n`, stored verbatim.

**A memory stream counts differently.** The same 100-byte payload on `mem.a` (5 chars):

| storage | headers | `state.bytes` |
|---|---|---|
| memory | none | **121** = 5 + 0 + 100 + 16 |
| memory | `-H k:v` | **139** = 5 + 18 + 100 + 16 |
| file | none | 135 for `big.a` = 22 + 5 + 100 + 8 |

So `nats stream info` bytes are **not comparable across storage types**: the same message is 135 B
in a file stream and 121 B in a memory stream.

## 2 · The block file is a bare concatenation of records

10,000 × 100 B on `sz.a` (`rl` = 134):

```
$ nats stream info SZ --json | jq '.state | {messages, bytes}'
{ "messages": 10000, "bytes": 1340000 }

$ find <store> -type f -exec stat -f "%z %N" {} \;
       506 <store>/jetstream/$G/streams/SZ/meta.inf
        16 <store>/jetstream/$G/streams/SZ/meta.sum
   1340000 <store>/jetstream/$G/streams/SZ/msgs/1.blk
```

`1.blk` is **exactly** the reported bytes: 10,000 × 134. There is no block file header, no padding
and no index file. `index.db` had not been written yet — it is written on a timer, on purge and on a
clean stop.

### The first record, decoded from the file

From `BIG/msgs/1.blk` (subject `big.a`, 100 B payload, `rl` = 135):

```
00000000: 8700 0000 0100 0000 0000 0000 f0a4 951f  ................
00000010: 59d2 d018 0500 6269 672e 6178 7878 7878  Y.....big.axxxxx
00000020: 7878 7878 7878 7878                      xxxxxxxx
```

| bytes | field | value |
|---|---|---|
| 0–3 | `total_len` (LE uint32, high bit = has headers) | `0x87` = **135**, headers bit clear |
| 4–11 | `seq` (LE uint64) | 1 |
| 12–19 | `ts` (LE int64, unix nanos) | 1788160332289910000 → 2026-08-31T07:12:12.289910Z |
| 20–21 | `subj_len` (LE uint16) | 5 |
| 22–26 | subject | `big.a` |
| 27–126 | payload | 100 × `x` |
| 127–134 | highwayhash64 | `9a9873f5deaf5f84` |

## 3 · Deleting a message makes the file **bigger**

Five `nats stream rmm SZ <seq>` on the 10,000-message stream:

| | before | after |
|---|---|---|
| `state.messages` | 10,000 | 9,995 |
| `state.bytes` | 1,340,000 | **1,339,330** (−5 × 134) |
| `1.blk` on disk | 1,340,000 | **1,340,150** (+5 × 30) |

The deleted records stay in the block, and each delete appends a **30-byte tombstone**
(`emptyRecordLen`). Disk and reported bytes now differ by 820 bytes for five deletions.

## 4 · A full purge frees the disk immediately

```
$ nats stream purge SZ -f
```

| | before | after |
|---|---|---|
| `msgs/` contents | `1.blk` 1,340,150 | `2.blk` **30**, `index.db` **56** |
| `state` | 9,995 msgs / 1,339,330 B | 0 msgs / 0 B, `first_seq` 10001, `last_seq` 10000 |

The old block is removed outright and a fresh block is started holding a single 30-byte tombstone
that carries the sequence floor. A purge also forces `index.db` to be written.

## 5 · The block size the server picks, and how to see it

Blocks roll *before* the record that would overflow them, so a full block is always
`BlockSize − (less than one record)`.

| stream | `max_bytes` | `max_msgs` | `max_msgs_per_subject` | full block observed | implied `BlockSize` |
|---|---|---|---|---|---|
| `B100K` | 100KB | — | — | 31,920 (240 × 133) | **32,000** (`FileStoreMinBlkSize`) |
| `B1M` | 1MB | — | — | 4,194,288 (31,536 × 133) | **4MB** (`defaultMediumBlockSize`) |
| `B100M` | 100MB | — | — | 8,388,576 (63,072 × 133) | **8MB** (`FileStoreMaxBlkSize`) |
| `BIG` | — | — | — | 8,388,495 (62,137 × 135) | **8MB** (`limits` default) |
| `NMSG` | — | 100,000 | — | 8,388,576 | **8MB** |
| `NPER` | — | — | 1,000 | 4,194,288 | **4MB** (`defaultKVBlockSize`) |
| `KV_CFG` (a KV bucket) | — | — | 1 (history) | 4,194,270 | **4MB** (`defaultKVBlockSize`) |

`B1M` is the branch worth staring at: a stream limited to **1MB** is given a **4MB** block, because
`dynBlkSize`/`autoTuneFileStorageBlockSize` collapse everything between 32,000 and 8MB to exactly
4MB. There is no configuration surface for this in the stream API — `nats stream info --json`
reports no block size at all.

## 6 · Reported bytes bound the records, not the disk

With `--discard=old`, `max_bytes` is enforced against `state.bytes` to within one record:

| stream | `max_bytes` | `state.bytes` | `*.blk` on disk | disk ÷ reported |
|---|---|---|---|---|
| `B100K` | 102,400 | 102,277 | 111,720 | **1.09** |
| `B1M` | 1,048,576 | 1,048,572 | 4,655,000 *(immediately after filling)* | **4.44** |
| `B1M` | 1,048,576 | 1,048,572 | 1,048,572 *(after one sync interval)* | **1.00** |

`B1M`'s 4.4× was **transient**: the periodic sync pass (every `sync_interval`, default `2m`)
compacted the half-dead first block from 4,194,288 down to 587,860 and disk converged on the
reported figure. `B100K`'s 1.09 is **stable** — its oldest block is only 30% dead, and compaction
needs more than half of a block to be dead before it will rewrite it.

### The block that is never compacted

`NPER` (`max_msgs_per_subject: 1000`, 40,000 messages published to one subject, 1,000 retained) then
left idle:

```
$ nats stream info NPER --json | jq '.state | {messages, bytes}'
{ "messages": 1000, "bytes": 133000 }

$ ls -l <store>/jetstream/$G/streams/NPER/msgs/
-rw-------  1 ...  1125712  2.blk
```

**8.5× the reported size, and it does not go down.** `1.blk` was removed when every record in it
died, but `2.blk` is the *last* block, and both compaction paths skip the last block by design
(`filestore.go:6151` and `filestore.go:8039`). It will only shrink once enough new messages arrive
to roll a new block behind it.

Checked again after a **full `sync_interval`** and after a **server restart** — `2.blk` is still
1,125,712 bytes, unchanged, timestamp unchanged. `B100K` likewise stayed at 111,720 across the same
window: its oldest block is 30% dead, and compaction wants more than 50%.

## 7 · `index.db` — the full-state snapshot

Written by `flushStreamStateLoop` every **2 minutes plus up to 30 s of jitter**, forced on purge and
on a clean shutdown (all ten streams had one after `kill -INT`).

Its size is dominated by the per-subject map. Measured:

| stream | subjects | Σ subject bytes | `index.db` | bytes per subject beyond the subject itself |
|---|---|---|---|---|
| `BIG` | 1 | 5 | 102 | — |
| `B100K` | 1 | 3 | 128 | — |
| `CARD` | 20,000 (`card.1`…`card.20000`) | 188,894 | **268,964** | (268,964 − 188,894 − ~100) / 20,000 ≈ **4.0** |
| `KV_CFG` | 40,000 (`$KV.CFG.k1`…) | 548,894 | **708,987** | (708,987 − 548,894 − ~100) / 40,000 ≈ **4.0** |

Four bytes per subject is exactly the encoder: one varint for the subject length and one each for
`total`, `fblk`, `lblk`, all single-byte at these magnitudes. **Budget `index.db` at
`Σ(len(subject) + 4)`** — a million distinct 40-character subjects is roughly 44 MB of `index.db`
per replica, rewritten every two minutes.

## 8 · Recovery, with and without `index.db`

Same store, 10 streams, 279,653 messages, 39 MB, on this machine's SSD:

| | `Took … to start JetStream` |
|---|---|
| with `index.db` present for all 10 streams | **22.1 ms** |
| after `find <store> -name index.db -delete` | **24.6 ms** |

**No measurable difference at this size.** This lab is far too small to show what `index.db` is for;
it does not support any claim that removing it makes recovery slow, and it is recorded here so that
nobody derives one from it.

## 9 · What the monitoring endpoints report

`/jsz` and `/varz` report the **logical** figure — the sum of `state.bytes` — not disk:

```
$ curl -s http://127.0.0.1:8232/jsz | jq '{storage, reserved_storage, messages, bytes, streams}'
{
  "storage": 37891637,
  "reserved_storage": 106110976,
  "messages": 279653,
  "bytes": 37891637,
  "streams": 10
}

$ find <store> -type f -exec stat -f "%z" {} \; | paste -sd+ - | bc
39881215
```

`storage` (37,891,637) is the exact sum of the ten streams' `state.bytes`; the tree on disk is
**39,881,215** — 5.25% more. `reserved_storage` 106,110,976 is the sum of the four streams that set
`max_bytes` (100KB + 1MB + 100MB + a leftover 100KB stream), reserved whether or not anything is
stored.

`/jsz` also prints the effective sync interval, which is the compaction cadence in §6:

```
"config": { "sync_interval": 120000000000, ... }
```

## 10 · Consumer state on disk

A pull consumer's directory holds `meta.inf` (its config), `meta.sum` and `o.dat` (its position).
`o.dat` tracks the ack-pending set, not the stream:

| consumer | `num_ack_pending` | `o.dat` |
|---|---|---|
| `SZ > WORK`, freshly created | 0 | **8 B** |
| `SZ > WORK`, 50 delivered unacked | 50 | **213 B** |
| `BIG > P500`, 500 delivered unacked | 500 | **2,762 B** |

Roughly 5–6 bytes per outstanding message here; the encoding is varint deltas, so the real figure
depends on how the pending sequences are spread. The point for sizing is the shape: **consumer state
is bounded by `max_ack_pending`, not by stream size** — a consumer on a 70,000-message stream with
500 pending costs under 3 KB.

## 11 · `max_file_store` bounds the logical figure, so the disk can pass it

A **second server** (`port: 4233`, `http: 8233`, its own store), configured with the ceiling set
deliberately small:

```
jetstream {
  store_dir: "<store>"
  max_file_store: 4MB
  max_memory_store: 1MB
}
```

```
[INF]   Max Storage:     4.00 MB
```

One stream, `max_msgs_per_subject: 1000` (so 4MB blocks), 60,000 × 100 B published to the single
subject `c.a`, then left alone:

```
$ nats stream info CAP --json | jq '.state | {messages, bytes}'
{ "messages": 1000, "bytes": 133000 }

$ curl -s http://127.0.0.1:8233/jsz | jq '{storage, config: .config.max_storage}'
{ "storage": 133000, "config": 4194304 }

$ find <store> -type f -exec stat -f "%z %N" {} \;
       508 <store>/jetstream/$G/streams/CAP/meta.inf
        16 <store>/jetstream/$G/streams/CAP/meta.sum
   3785712 <store>/jetstream/$G/streams/CAP/msgs/2.blk
```

**JetStream believes it has used 133,000 of 4,194,304 bytes — 3%. The store directory holds
3,786,236 bytes — 90% of the same ceiling.** Nothing is wrong with the stream and nothing is logged;
the 3.79 MB is the never-compacted last block from §6, and the accounting `max_file_store` enforces
counts only the 1,000 live records inside it.

`du -sk` on this APFS volume reports 4,724 KB for the same tree, above `max_file_store` outright;
the apparent-size figure 3,786,236 is the conservative one and is what is quoted above.

The consequence for sizing is direct: **`max_file_store` set equal to the volume size does not stop
the volume filling.** It is a ceiling on a number that is smaller than the thing it is protecting.
