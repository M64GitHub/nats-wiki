---
title: "ADR-35 — JetStream filestore compression"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-35.md
source-path: raw/adr/ADR-35.md
author: "@neilalexander"
article: ADR-35 JetStream Filestore Compression
date: 2023-05-01
version: "2.10"
tags: [compression, s2, filestore, encryption, block, sizing, docs-issue-30]
aliases: [ADR-35, filestore compression, s2 compression]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-35 — why a stream compresses whole blocks, and what that costs

The design behind the stream's `compression` field. Written 2023-05-01 for the 2.10 cycle, status
**Implemented**. Everything in it holds in nats-server 2.14.6 **except one sentence about changing
the setting on a live stream**, which is wrong — see *What the ADR gets wrong* below and docs issue
#30.

## Key claims

### The problem it solves is encryption, not disk price

"Use of filestore encryption can almost completely prevent host filesystem compression or
deduplication from working effectively. This may present a particular problem in environments where
encryption is mandated for compliance reasons but local storage is either limited or expensive."

So compression exists because **an encrypted stream is incompressible to everything underneath it** —
the filesystem, the volume, the backup target. The server compresses *before* it encrypts, which is
the only place in the stack where that ordering is available.

### The field

The stream config gains `compression`, valid values `"none"` and `"s2"`. Settable on
`$JS.API.STREAM.CREATE`, changeable on `$JS.API.STREAM.UPDATE`, returned by
`$JS.API.STREAM.INFO`. "Compression and decompression of messages is performed transparently by the
NATS Server if configured to do so, therefore clients do not need to be modified in order to publish
to or consume messages from a stream."

Confirmed in 2.14.6: `StoreCompression` has exactly two values, `NoCompression` and `S2Compression`,
marshalled as `"none"` and `"s2"` (`server/filestore.go:109-153`), and an unknown string is rejected
at parse time.

### Whole blocks, asynchronously, once they stop being the tail

"When enabled, message blocks will be compressed asynchronously when they cease to be the tail
block — that is, at the point that the message block reaches the maximum configured block size and a
new block is created. This is to prevent unnecessary decompression and recompression of the tail
block while it is still being written to, which would reduce publish throughput."

"Compaction and truncation operations will also compress/decompress any relevant blocks
synchronously as required."

In 2.14.6 that is `recompressOnDiskIfNeeded` (`filestore.go:7763`), called in a goroutine from the
new-block path (`filestore.go:4978`) and synchronously from the truncate path
(`filestore.go:11172`).

### Block, not message — and the reason is stated

"Both block and individual message compression were initially explored. In order to benefit from
repetition across individual messages (particularly where the data is structured, i.e. in JSON
format), compression at the block level provides significantly better compression ratios over
compressing individual messages separately."

This is why compression ratio depends on how similar *neighbouring* messages are, not on how
compressible one message is.

### The on-disk shape

"Compressed blocks gain a new prepended header describing not only the compression algorithm in use
but also the original block content size. This header is encrypted along with the rest of the block
when filestore encryption is enabled. Absence of this header implies that the block is not
compressed."

"The checksum at the end of the block is specifically excluded from compression and remains on disk
as-is, so that checking the block integrity does not require decompressing the entire block."

Both confirmed in 2.14.6: `CompressionInfo.MarshalMetadata` writes `'c','m','p'`, the algorithm byte
and a uvarint original size (`filestore.go:13982`), and `Compress` / `Decompress` explicitly carry
the trailing checksum through uncompressed (`filestore.go:14008`, `:14048`).

The original size is stored so "it [is] possible to determine the effective compression ratio later
without having to decompress the block, **although the NATS Server does not currently do this**" —
still true in 2.14.6: nothing reads `OriginalSize` to report a ratio, so there is no server-side
compression-ratio metric to monitor.

### The cost, in the ADR's own words

"Compression requires extra system resources, therefore it is anticipated that a compressed stream
may suffer some performance penalties compared to an uncompressed stream." No numbers are given —
the ADR quantifies nothing, and neither does any other public source read for this wiki.

## What the ADR gets wrong

> "The compression algorithm can be updated after the stream has been created. **Newly minted blocks
> will use the newly selected compression algorithm**, but this will not result in existing blocks
> being proactively compressed or decompressed."

The second half is right. The first half is not, on 2.14.6. The algorithm the running store writes
with is `fs.fcfg.Compression`, set once when the store is created (`server/stream.go:994`, reached
only from `setupStore` at `stream.go:1004`); `fileStore.UpdateConfig` (`filestore.go:686`) updates
the stream config and never touches it. A live change is accepted, persisted and reported by
`STREAM.INFO`, and **changes nothing on disk until the store is re-created**.

Run on the v2.14.6 binary
(`raw/nats-server-src/compression-purge-discovery-observed-v2.14.6.md`): a block sealed *after*
`nats stream edit --compression=s2` was 31020 bytes and uncompressed; after a server restart the
next block sealed at 790 bytes with the `cmp` header. Recorded as docs issue #30.

`learn/jetstream/policies.md` in the docs states the real behaviour ("the new setting waits until
the stream's store restarts"), so here the docs are right and the ADR is wrong — the reverse of the
usual direction.

## Practical takeaways

- **`compression: s2` is a create-time decision in practice.** Setting it later is legal but inert
  until the stream's store is re-created, and it never touches what is already on disk.
- **It only pays on structured, repetitive payloads.** Block-level S2 exploits repetition *between*
  messages; already-compressed payloads (images, archives, encrypted blobs) gain nothing and still
  cost CPU.
- **The strongest case is an encrypted stream**, where nothing below the server can compress.
- **There is no compression-ratio metric.** The only honest measurement is the size of the stream's
  `msgs/*.blk` files against the byte count `nats stream info` reports.

## Relevance to the wiki

The whole of [[stream-compression]], the disk half of [[jetstream-sizing]], and the `compression`
row in [[stream]]'s configuration table.

## Questions it answers

Q31 (how filestore compression works and what it costs), answered by [[stream-compression]].

## Pages touched

[[stream-compression]] · [[stream]] · [[jetstream-sizing]] · [[tls-in-nats]]
