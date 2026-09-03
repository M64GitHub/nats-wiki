---
title: "gh#6005 — a sourcing stream stalls after its memory-backed source restarts (2.10.19's start-sequence clipping change, reverted in 2.10.22)"
type: summary
area: [jetstream, topology]
source-url: https://github.com/nats-io/nats-server/discussions/6005
source-path: raw/gh-discussions/gh-6005.md
author: "@AlexeiSosnov (asker); @neilalexander and @jnmoyne (maintainers); @pricelessrabbit, @astmix"
date: 2024-10-15
version: "2.10.19 – 2.10.22; recurrence reported on 2.14 (2026-08-07)"
article: "Q&A thread, 3 comments and 1 reply; answered 2024-10-17; updated 2026-08-08"
tags: [sourcing, mirror, memory-stream, leafnode, opt_start_seq, clipping, restart, AckFlowControl]
aliases: [gh#6005, "sequence clipping sourcing", "sourcing from memory stream stops after restart"]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# gh#6005 — a sourcing stream stalls after its memory-backed source restarts

The public form of question-bank row 154. A hub stream sources from a **memory-backed** stream on a
busy leaf node (memory storage chosen "to avoid additional i/o load"). Every leaf restart recreates
the source stream empty, `FirstSeq = LastSeq = 0`, and the sourcing stream re-creates its source
consumer from "the last remembered offset in the sourced stream". Up to 2.10.12 that worked; from
2.10.19 it stalled and lost messages.

## Key claims

- **What changed.** The asker traced it to nats-server PR #5785, in 2.10.19: "when a consumer start
  sequence was out of the stream, it was clipped to be inside the stream … starting from NATS
  v2.10.19 this behavior is changed, and consumer `OptStartSequence` is now **not** being clipped."
  The source consumer therefore waits "until the sourced stream `LastSeq` catches up to the consumer
  sequence" — a stall, and, once the recreated stream passes the old sequence, a gap.
- **Not only memory streams.** The same applies "when a sourced server unexpectedly shuts down [and]
  the last block of the sourced stream SST can be lost due to not being flushed on the disk".
- **The answer, two days later, from a maintainer:** "We've reverted the behaviour in #6014, which
  will go into 2.10.22, and will rethink how to satisfy both use cases in 2.11." The 2.10.22 release
  body carries it: "Revert earlier PR #5785 to restore consumer start sequence clipping, fixing an
  issue where sourcing/mirroring consumers could skip messages (#6014)" (source: [[s-relnotes-2.10]]).
- **A second user** notes the revert also fixes issue #5847, "a sourced stream is manually deleted and
  recreated … when you source stream for other accounts that you are not controlling directly".
- **It came back on 2.14.** On 2026-08-07 a user reported the same stall with WorkQueue source and
  sourcing streams across two leaf domains (`external.api: $JS.leaf-1.API`): "it seems that
  `opt_start_seq` is now taken from the durable consumer after switching to the **AckFlowControl**
  policy. The observed behavior is that the replication stream only receives new messages after we
  reach the sequence number at which the stop occurred last time." A maintainer replied on
  2026-08-08 that "sourcing recovering from the sourced stream being deleted and re-created should
  be addressed by" PR #8384 — "(2.15) [IMPROVED] Source stream recreation detection", merged
  2026-08-13, listed in the v2.15.0-preview.1 body.

## Practical takeaways

- On **2.10.19, 2.10.20 or 2.10.21**, a source or mirror whose upstream can restart empty (memory
  storage, or an unflushed last block) stalls until the upstream's sequence overtakes the remembered
  one, and then skips. Upgrade to **2.10.22 or later**.
- On **2.14**, the reliable-sourcing consumer (durable, `AckFlowControl` — ADR-60) reintroduces the
  shape for an upstream that is *deleted and recreated*; the fix is in the 2.15 preview (#8384). Until
  then, a recreated upstream means recreating the source entry too.
- A memory stream on a leaf is a legitimate way to keep I/O off the edge, but its every restart is a
  "deleted and recreated" upstream to whoever sources it.

## Relevance to the wiki

The version-layer entry for [[mirrors-and-sources]] (*What a sourcing stream does at every start*),
and a cause for [[stream-has-high-message-lag]] when the upstream is memory-backed.

## Questions it answers

Row 154.

## Pages touched

[[mirrors-and-sources]] · [[nats-server-2.10]] · [[nats-server-2.15-preview]] ·
[[stream-has-high-message-lag]]
