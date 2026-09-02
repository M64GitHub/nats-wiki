---
title: "gh#8444 — Mirror Stream sync is ~2.9× slower when a Consumer cold-scans the mirror during catch-up"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/8444
source-path: raw/gh-discussions/gh-8444.md
author: "@cyqsign (asked); @gitsult4n (one comment); no maintainer reply"
article: "GitHub Discussion 8444 (Q&A, unanswered as of 2026-09-02)"
date: 2026-08-10
version: "2.14.2"
tags: [mirror, catch-up, lag, filestore, lock, SkipMsgs, LoadNextMsg, sparse-stream, unanswered]
aliases: []
sources: []
created: 2026-09-02
updated: 2026-09-02
---

# gh#8444 — a consumer scanning a mirror slows the mirror's own catch-up

The same reporter as [[s-gh-8417-kv-mirror-file-vs-memory]], two weeks later, with a buildable
reproduction attached. **No maintainer has replied** as of 2026-09-02; the one comment is from a
community member arguing from the source. The wiki's own measurement is in
[[s-nats-server-mirrors-observed]].

## The report

Hub and leaf as two `nats-server` processes on one node (domains `hub` and `leaf`, **v2.14.2**,
CentOS 7, file storage, R1). Source stream A: `MaxMsgsPerSubject: 1`, `AllowAtomicPublish`,
`AllowRollup`, `AllowDirect`. Mirror B on the leaf via `$JS.hub.API`.

The data shape, built to be sparse: 1,000,000 keys written once, a hot 300,000 of them overwritten
3,000,000 times as fast as possible — "span ≈ 4 000 000, holes ≈ 3 000 000, hole ratio ≈ 75 %. Every
message retrieval must skip through ~3 dead seqs on average."

The measurement: delete and recreate B, time the catch-up to `lag` 0, once alone and once while a
`DeliverAll`, `AckNone`, ephemeral, unfiltered consumer "re-scans head→tail in a loop":

| | mirror sync time | min ingest rate |
|---|---:|---:|
| no consumer | **14.201 s** | 64,217 seq/s |
| with the cold-scan consumer | **41.003 s** | 23,080 seq/s |
| delta | +26.802 s (**2.89×**) | down 64 % |

Message counts matched afterwards, so both runs synced the same data. The questions: is that
magnitude expected contention, and is there a server-side setting that reduces it?

## The one comment

A code-grounded hypothesis, flagged as such ("rather than something I've isolated with a profiler"):

- One `sync.RWMutex` guards the whole file store (`fileStore.mu`).
- The reader's `LoadNextMsg` holds `fs.mu.RLock()` for the **whole call**, "including the loop that
  walks `fs.blks` — so a single `LoadNextMsg` invocation that has to step over several holes-only
  blocks holds `fs.mu.RLock()` for the entire multi-block walk".
- The mirror's write side takes the exclusive lock **twice per live message** on a sparse backlog:
  once in `SkipMsgs` to record the gap the upstream's deletes left (`stream.go`'s "the upstream
  stream has expired or deleted messages" branch), once in `StoreMsg`. At a 75 % hole ratio "that's
  close to a 2x increase in exclusive-lock *acquisitions* on the write side alone".
- Go's `RWMutex` is writer-preferring, so queued writers also stall subsequent readers.
- Its own push-back: `firstMatching` can populate a block's cache from disk **while holding the
  block lock**, and a harness that restarts a full head-to-tail scan every round evicts the blocks
  near the mirror's write tail — so lock count and cache pressure "are probably not independent,
  competing explanations here, but two views of the same mechanism".

The answers it offers: no `FileStoreConfig`, stream or consumer setting narrows the lock; the
`SkipMsgs` half exists only during the *historical* backfill, so **start the scanning consumer once
the mirror's `lag` reaches 0** (poll `STREAM.INFO`); and reuse one long-lived consumer instead of
creating an ephemeral one per round, because each creation "does its own I/O and locking".

The line numbers in the comment are from `main` in 2026-08; at v2.14.6 the same code is at
`filestore.go:9427–9433` (`LoadNextMsg`), `5465–5467` (`SkipMsgs`), `5336` (`StoreMsg`) and
`stream.go:3275–3286` (the gap branch) — [[s-nats-server-mirror]].

## What the wiki's run adds

Three Go readers (`nats bench js ordered`, no filter, head to tail in a loop) against the same
1 M / 4 M shape on one server, nats-server 2.14.6: the file mirror's catch-up went from ~2.6 s to
**8.9–10.1 s (3.4–3.9×)**, and a **memory** mirror's from ~1.1 s to **3.3–3.7 s (3.1–3.4×)**
([[s-nats-server-mirrors-observed]]). The effect reproduces; on that host it is not specific to the
file store's lock.

## Practical takeaways

- Do not let readers cold-scan a mirror while it is doing its initial catch-up. Gate them on `lag`
  reaching 0 — the same field [[mirrors-and-sources]] tells you to alert on.
- A sparse upstream (a KV bucket with a hot key space, an Interest or WorkQueue stream) makes the
  catch-up itself more expensive: every gap is a `skipMsgs` call before the message that follows it.
- Nothing in the config changes this. The mitigations are scheduling and consumer hygiene.

## Questions it answers

- **Q91** — with the mechanism argued from source and the effect reproduced, but marked as
  unanswered upstream.

## Pages touched

[[mirrors-and-sources]] · [[consumer-slow-on-a-sparse-stream]] · [[filestore-layout]] ·
[[jetstream-slows-as-consumers-grow]]
