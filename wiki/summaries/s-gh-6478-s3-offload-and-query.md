---
title: "gh#6478 — S3 next level: offload, backup, data-sharing, querying"
type: summary
area: [jetstream, deploy, interop]
source-url: https://github.com/nats-io/nats-server/discussions/6478
source-path: raw/gh-discussions/gh-6478.md
author: "@hpvd (asker); @ohanf, @Material-Scientist, @ABFocke"
date: 2025-02-09
version: ""
article: "GitHub discussion 6478, Ideas, no chosen answer, 3 comments and 4 replies, 42 upvotes, still open"
tags: [s3, object-storage, tiered-storage, offload, parquet, duckdb, rclone, vfs-write-back, seaweedfs, block, "8MB"]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# gh#6478 — S3 next level: offload, backup plus also data-sharing, querying?

**42 upvotes, the most-supported idea in the discussions index**, and the thread gh#3772's last comment
points at as the general approach to storage tiering. Opened 2025-02-09; **no maintainer has commented
in it**, which is the first thing to say when citing it. Read for question-bank row **198**.

## Key claims

**The proposal** (@hpvd): take S3 support beyond offload and backup to *data-sharing and querying*, by
writing messages to S3 **in Parquet** so third parties can read them with DuckDB directly, with Parquet
Modular Encryption for the security half. A later comment sketches the config surface: per subject, a
connected external store, a `mode` of `duplicate` or `offload`, and an offload threshold on message age,
message count or subject size — including a threshold of `0`, "purely relying on S3 (for this subject)".

**The strongest technical content in the thread is the reply that says why the naive version does not
work** (@ohanf, 2025-03-28), and it is the paragraph to quote in any design discussion:

> "I would not start with `0`, especially if you are assuming it will be cheaper. Object storage (ie S3)
> is not a file system, notably you can not 'append' to files once they have been uploaded. Providers
> also charge per operation, listing in particular can become quite expensive if you are not careful.
> The overhead of writing a new file for every message would be non-viable: tons of tiny files,
> amplification of API operations (direct impact to cost) and writing parquet headers. Some amount of
> buffering would need to be done before writing, and you may want to consider 'compaction' jobs even
> after files have been uploaded…"

with Grafana's Mimir and Loki, InfluxDB 3.0 and Kafka's connectors named as the prior art. A second
commenter agrees from operational experience: "Object stores are designed for infrequent writes, given
how each write creates a new object. Also, most object stores (especially minio-based) perform poorly
when dealing with many small files (SeaweedFS being the exception)."

**And the thread contains the one *tested* workaround in the public record** (@Material-Scientist,
2025-10-22) — an rclone mount with an S3 backend under `store_dir`, using `--vfs-write-back`:

- "If you mount an rclone volume with an S3-compatible backend onto your host, and have NATS use that as
  primary directory to write data to, you can set e.g. `--vfs-write-back=10m`, such that any data will
  get transferred to the S3 backend after 10min of not having been accessed."
- Why it fits: "no change necessary on NATS side, since NATS still sees the stub-files and fetches
  remote data on-demand"; "messages are buffered on the local disk until the **8MB block** is full, and
  hasn't been accessed/updated in 10min"; and a restarted mount still has the data locally.
- **It was observed working**: a 12 MB stream where only the first 8 MB block had been transferred while
  NATS was still writing the second, and "The remote backend even respects NATS retention limits" —
  blocks deleted locally were deleted remotely.
- **And then it broke.** "However, after a while I kept getting these errors… 69 & 72 are missing, which
  have errors in the logs: **corrupted on transfer**. That's where I stopped with this experiment."

## Practical takeaways

- **No maintainer participation and no chosen answer**, on the highest-upvoted idea in the repository.
  Cite it as demand and as community engineering, never as a plan or a supported design.
- The rclone approach is the closest thing to tiered storage that exists today for JetStream, it is
  attractive precisely because the filestore is a directory of sealed ~8 MB blocks
  ([[filestore-layout]]), and **its author abandoned it on data corruption**. That last sentence is the
  one an operator needs; the screenshots of it working are the ones they will find first.
- The reason a native implementation is not a weekend job is in @ohanf's reply, not in the roadmap:
  object stores cannot append, charge per operation, and punish small files — so any real design needs
  buffering, compaction and a cache-back path, which is a storage engine rather than a config key.
- The Parquet/DuckDB half is a different feature wearing the same name: *offload* is about cost,
  *querying* is about a second consumer of the data, and conflating them is why the thread has 42
  upvotes and no design.

## Notable quotes

> "Object storage (ie S3) is not a file system, notably you can not 'append' to files once they have
> been uploaded." — @ohanf, 2025-03-28

> "That's where I stopped with this experiment." — @Material-Scientist, 2025-10-22, on the rclone mount
> after `corrupted on transfer`

## Relevance to the wiki

The second half of row 198: gh#3871 says the server does not do it, this thread says what people build
instead and how far that gets. The evidence behind the *no tiered storage* section of
[[event-sourcing-on-jetstream]], and a caution for anyone reading
[[kubernetes-storage]]'s "block storage, never NFS" rule as being only about NFS.

## Questions it answers

Row **198** (the workaround half); row 144 in part.

## Pages touched

[[event-sourcing-on-jetstream]] · [[filestore-layout]] · [[kubernetes-storage]]
