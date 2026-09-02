---
title: "nats-server v2.14.6 source — how a mirror catches up, and the filtered-read heuristic"
type: summary
area: [jetstream, kv]
source-path: raw/nats-server-src/mirror-v2.14.6.md
source-url: https://github.com/nats-io/nats-server/blob/v2.14.6/server/stream.go
author: "nats-io/nats-server (Apache-2.0)"
article: "server/stream.go and server/filestore.go at v2.14.6, selected ranges; server/stream.go at v2.10.0 and v2.12.0 for one comparison"
date: 2026-08-27
version: "2.14.6"
tags: [mirror, JS_MIRROR, processMirrorMsgs, skipMsgs, SkipMsgs, firstMatching, LoadNextMsg, linear-scan, sourceHealthCheckInterval, inbound-queue, source]
aliases: []
sources: []
created: 2026-09-02
updated: 2026-09-02
---

# nats-server v2.14.6 — the mirror's consumer, its catch-up loop, and the read path a filter takes

The ranges of `server/stream.go` and `server/filestore.go` that explain what
[[s-gh-8417-kv-mirror-file-vs-memory]] and [[s-gh-8444-mirror-catchup-under-a-reader]] observed,
with the real line numbers at tag v2.14.6. The runs that exercise them are
[[s-nats-server-mirrors-observed]].

## Key claims

**The consumer a mirror creates on its upstream** (`stream.go:3550–3575`) is asked for by name,
always: `Name: fmt.Sprintf("JS_MIRROR_%s", id)` with `id` from `createStableConsumerHash()`. Its
config: `DeliverByStartSequence` from the mirror's `LastSeq + 1` (or `DeliverAll` on an empty
mirror, `opt_start_seq` / `opt_start_time` honoured only on the first creation), `AckNone`, `AckWait`
**22 h**, `MaxDeliver` **1**, `Heartbeat` **1 s** (`sourceHealthHB`), `FlowControl: true`,
`Direct: true`, `Sourcing: true`, `InactiveThreshold` **10 s** (`sourceHealthCheckInterval`,
`3117–3122`), metadata `_nats.mirror.stream`, `_nats.mirror.acc` and, when the server has one,
`_nats.mirror.domain`. A `filter_subject` or a single `subject_transforms` entry becomes the
consumer's `FilterSubject`; several transforms become `FilterSubjects` (`3592–3618`). If the upstream
answers the create with `JSRequiredApiLevelErr` or `JSInvalidJSONErr` — an older server that does
not know `sourcing` — the request is retried without it under a fresh name
`JS_MIRROR_<id>_<random>` (`3733–3745`). A source stream's consumer is `JS_SRC_<id>` by the same
construction (`4019`).

**The names changed in 2.14.** At v2.10.0 (`stream.go:2558`) and v2.12.0 (`3258`) the name was
`fmt.Sprintf("mirror-%s", createConsumerName())` — random, and only when a filter was set; without a
filter the server let the upstream pick a name. ADR-59 revision 2 (2026-04-29) still describes that
older form; ADR-60 and the 2.14 server use `JS_MIRROR_<suffix>` / `JS_SRC_<suffix>` (docs issue
#49 in `inbox/docs-issues.md`).

**Deleting the mirror deletes the consumer, best-effort** (`2793–2808`): `tryDeleteMirrorConsumer`
recomputes the same stable name and makes "a best-effort single try".

**The catch-up loop** (`processMirrorMsgs`, `3125–3205`) drains the consumer's deliveries and, on a
**10 s** ticker, declares the mirror *stalled* if nothing has arrived for longer than
`sourceHealthCheckInterval`, then re-creates the consumer (`retryMirrorConsumer`, `3394–3401`, a
`Debugf` line `Retrying mirror consumer for '%s > %s'`). A re-create is gated by
`sourceConsumerRetryThreshold` = **2 s** (`3924`) and, after repeated failures, backs off by
`fails × 2 × 5 s` up to **2 min** (`3443–3456`).

**Heartbeats and flow control** (`processInboundMirrorMsg`, `3206–3262`): a control message with a
reply subject is flow control and is answered; an idle heartbeat carries `Nats-Last-Consumer`, and a
value that does not match the mirror's own delivered count means a retry; a heartbeat carrying
`Nats-Consumer-Stalled` gets a flow-control reply so the upstream resumes.

**The gap branch — how a mirror keeps the upstream's sequence numbers** (`3275–3290`): when the
consumer's delivery sequence is contiguous but the stream sequence jumped, "the upstream stream has
expired or deleted messages", and the mirror calls `skipMsgs(mirror.sseq+1, sseq-1)` before storing
the message. `skipMsgs` (`3403–3441`) is one `store.SkipMsgs(start, n)` call on an R1 mirror; on a
replicated mirror it is **one Raft entry per skipped sequence**, proposed in batches of 10,000 — or a
single `DeleteRange` entry when `feature_flags { js_raft_delete_range }` is on, "once every peer in
the cluster supports receiving deleteRangeOp".

**`SkipMsgs` in the file store** (`filestore.go:5465–5530`) runs under the store's exclusive lock
(`fs.mu.Lock()`), inserts every skipped sequence into the last block's delete map — starting a new
block if that map would pass **64 K** entries — and writes one 30-byte placeholder record. `StoreMsg`
/ `StoreRawMsg` (`5311`, `5336`) take the same lock. So on a sparse upstream every live message
costs the mirror two exclusive acquisitions, which is the structure gh#8444's comment argues from.

**The read path's heuristic** (`firstMatching`, `filestore.go:3031–3150`):

```go
  3093		subjs := mb.fs.cfg.Subjects
  3094		// If isAll or our single filter matches the filter arg do linear scan.
  3095		doLinearScan := isAll || (wc && len(subjs) == 1 && subjs[0] == filter)
  3096		// If we do not think we should do a linear scan check how many fss we
  3097		// would need to scan vs the full range of the linear walk. Optimize for
  3098		// 25th quantile of a match in a linear walk. Filter should be a wildcard.
  3099		// We should consult fss if our cache is not loaded and we only have fss loaded.
  3100		if !doLinearScan && wc && mb.cacheAlreadyLoaded() {
  3101			doLinearScan = mb.fss.Size()*4 > int(lseq-fseq)
  3102		}
```

`isAll` is true for an empty filter or `>`. On a KV bucket's own stream `subjs[0] == filter` is true
for `$KV.<bucket>.>`; on a **mirror**, `Subjects` is nil and the test fails. The fallback compares
four times the block's subject count against its **sequence range** — holes included — so a block
with 2,000 live messages over 12,000 sequences fails it and takes the per-subject path: an
`fss.Match` over every tracked subject to find the next candidate, per message. The same heuristic
appears in the multi-filter path (`9556–9558`). `LoadNextMsg` (`9427–9433`) holds `fs.mu.RLock()`
for the whole call.

**The stream's inbound queue** (`stream.go:439–443`, `920–927`): `streamDefaultMaxQueueMsgs =
100_000`, `streamDefaultMaxQueueBytes = 128 * 1024 * 1024`. A publisher that never waits for a
`PubAck` can fill it; the server then drops with `Dropping messages due to excessive stream ingest
rate on '<acc>' > '<stream>': IPQ len limit reached` — observed in the run.

**`highCardinalityThreshold = 1_000_000`** (`filestore.go:388–390`), the subject count above which
the per-subject index is no longer written unforced ([[filestore-layout]]).

## Practical takeaways

- A mirror's internal consumer is visible only through `/jsz?…&direct-consumers=true`; it is named
  `JS_MIRROR_<id>`, filterless unless the mirror filters, with a 1 s heartbeat and a 10 s stall
  check. Nothing about it is tunable from the mirror's config.
- `Lag` staying put for 10 s is the stall condition, after which the consumer is re-created every
  2 s at most, backing off to 2 min.
- A replicated mirror of a sparse upstream pays one Raft entry per hole unless
  `js_raft_delete_range` is enabled cluster-wide.
- On a mirror, an everything-matching consumer filter is the slow path on file storage.

## Questions it answers

- **Q76** (the mechanism behind the file-mirror read cost), **Q91** (the lock structure a competing
  reader contends with).

## Pages touched

[[mirrors-and-sources]] · [[filestore-layout]] · [[consumer-slow-on-a-sparse-stream]] ·
[[publishing]] · [[consumer]]
