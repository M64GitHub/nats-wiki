---
title: Stream compression
type: concept
area: [jetstream]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [compression, s2, filestore, block, encryption, sizing, docs-issue-30]
aliases: [compression, s2, "compression: s2", filestore compression, stream compression]
sources: [s-adr-35-filestore-compression, s-docs-stream-config, s-docs-policies]
created: 2026-08-31
updated: 2026-08-31
---

# Stream compression

A file-storage stream can compress its **message blocks** on disk with **S2** (an extension of
Snappy), transparently to publishers and consumers. One stream config field, `compression`, two
values, `none` and `s2` (source: [[s-adr-35-filestore-compression]], verified against nats-server
2.14.6).

It exists mainly because **an encrypted stream is incompressible to everything below the server** —
the filesystem, the volume, the backup target. Compressing before encrypting is a thing only the
server can do (source: [[s-adr-35-filestore-compression]]).

## How it behaves

**Whole blocks, not messages.** A stream's messages live in fixed-size blocks under
`<store_dir>/jetstream/<account>/streams/<stream>/msgs/*.blk`. S2 is applied to a whole block, so
the ratio depends on repetition **between** neighbouring messages, not within one. The ADR is
explicit that this was measured: block-level compression "provides significantly better compression
ratios over compressing individual messages separately", particularly for structured payloads such
as JSON.

**The tail block is never compressed.** A block is compressed when it stops being the one being
written to — "asynchronously when they cease to be the tail block", so publish throughput is not
paid twice. Truncation and compaction compress or decompress synchronously as needed
(source: [[s-adr-35-filestore-compression]]).

**A compressed block is identifiable on disk.** It starts with `cmp`, an algorithm byte and the
original size as a uvarint; an uncompressed block has no such header. The block's trailing checksum
is deliberately left uncompressed "so that checking the block integrity does not require
decompressing the entire block".

**Compress, then encrypt.** When the stream is encrypted, the compression header is inside the
ciphertext, and the server compresses the plaintext first "because then the compression can be as
efficient as possible on the raw data".

**Nothing reports the ratio.** The original size is on disk precisely so a ratio could be computed
without decompressing, and the server still does not do it. There is no `/varz`, `/jsz` or exporter
field for compression ratio in 2.14.6.

## Changing it on a live stream does nothing until the store restarts

This is the part that surprises people, and the two public sources disagree about it.

`nats stream edit <stream> --compression=s2` is **accepted**, persisted, and reported by
`nats stream info` — and the blocks the stream seals from that moment on are still **uncompressed**.
The algorithm the running store writes with is fixed when the store is created
(`server/stream.go:994`, reached only from `setupStore`); `fileStore.UpdateConfig` never updates it.
The new value takes effect the next time the stream's store is opened — on a server restart, or
whenever the stream is re-created on that node.

Observed on nats-server 2.14.6, in
`raw/nats-server-src/compression-purge-discovery-observed-v2.14.6.md`:

| block | sealed | on disk |
|---|---|---|
| `1.blk` | before the edit | 31020 bytes, uncompressed |
| `2.blk` | **after** `--compression=s2`, same server run | **31020 bytes, uncompressed** |
| `3.blk` | was the tail at restart | 20680 → **801 bytes**, `cmp` header |
| `4.blk` | after the restart | **790 bytes**, `cmp` header |
| `5.blk` | current tail | 5170 bytes, uncompressed |

So, precisely: **blocks sealed before the store re-opened stay as they are** (1 and 2 are never
revisited), the block that was the **tail** at restart is compressed as soon as it is superseded
(3), and everything sealed afterwards is compressed (4).

**The sources disagree, and the docs are right.** ADR-35 says "Newly minted blocks will use the newly
selected compression algorithm"; `learn/jetstream/policies.md` says the setting "waits until the
stream's store restarts". The server sides with the docs. Recorded as docs issue #30.

## What configures it

| where | how | notes |
|---|---|---|
| stream config | `"compression": "s2"` (or `"none"`) | `$JS.API.STREAM.CREATE`, `.UPDATE`, returned by `.INFO` |
| `nats` CLI | `nats stream add ORDERS --compression=s2` | flag help: "Compression algorithm to use (file storage only)" |
| changing later | `nats stream edit ORDERS --compression=s2 -f` | accepted; inert until the store is re-created |

Default: `none` (source: [[s-docs-stream-config]], `reference/jetstream/api/stream/create.md`).
Only `none` and `s2` are accepted; anything else is rejected when the config is parsed
(`server/filestore.go:139-152`, verified at v2.14.6). Memory streams ignore it — the flag is file
storage only.

Since **2.10** (source: [[s-adr-35-filestore-compression]], dated 2023-05-01 for that cycle).

## Limits and failure modes

- **Already-compressed payloads gain nothing** and still cost CPU on every block seal: images,
  archives, protobuf-with-compression, anything encrypted client-side.
- **The cost is unquantified in every public source.** ADR-35 says only that "a compressed stream
  may suffer some performance penalties compared to an uncompressed stream". No source read for this
  wiki gives a throughput or CPU number. Measure it on your own payload before assuming.
- **Reads of old blocks pay decompression**, so a consumer replaying from the start of a large
  compressed stream is doing work a live consumer never does.
- **`nats stream info` byte counts are logical, not physical.** They count message bytes, so a
  compressed stream reports the same size as an uncompressed one holding the same messages. The
  physical size is what the volume sees — see below.

## How to measure the ratio yourself

There is no metric, so compare the two numbers directly on a node holding the stream:

```
nats stream info ORDERS | grep Bytes
du -sh <store_dir>/jetstream/<account>/streams/ORDERS/msgs
```

The first is the logical size, the second what the disk actually holds — including the uncompressed
tail block and the index files. On a stream that has never restarted since the setting changed, they
will be the same, which is the symptom described above.

## Related

[[stream]] · [[jetstream-sizing]] · [[retention-policies]] · [[tls-in-nats]] (encryption at rest) ·
[[key-value]]

## Sources

- [[s-adr-35-filestore-compression]] — the design, the block-level decision, the on-disk header
- [[s-docs-stream-config]] — the `compression` field and its default
- [[s-docs-policies]] — the docs' statement that a change waits for the store to restart
- `raw/nats-server-src/compression-purge-discovery-observed-v2.14.6.md` — the block sizes above,
  observed on the v2.14.6 binary
