---
title: "gh#8001 — JetStream startup seems slow for ~50M messages"
type: summary
area: [jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/discussions/8001
source-path: raw/gh-discussions/gh-8001.md
author: "@zig (asked); @wallyqs and @derekcollison (maintainers, no answer chosen)"
article: "GitHub Discussion 8001 (General, opened 2026-04-02, last message 2026-04-13, unanswered)"
date: 2026-04-02
version: "2.12.5"
tags: [recovery, startup, restore, sources, filestore, index.db, healthcheck, kubernetes, helm, goroutine-dump, stacksz, unanswered]
aliases: []
sources: []
created: 2026-09-02
updated: 2026-09-02
---

# gh#8001 — a 50 M-message stream took 6 min 38 s to "restore" after a clean shutdown

The thread behind question-bank row 13. It is **unanswered upstream**: two maintainers asked
diagnostic questions, the reporter answered every one of them and posted a goroutine dump, and nobody
read the dump back. This wiki did (see *What the dump says*), and the mechanism it shows is not the
one the maintainers were looking for.

## The report

`nats-server 2.12.5`, standalone (not clustered), under the standard Helm chart on Kubernetes with
Ceph storage the reporter rates at "> 200MB/s". One stream, `project-event`: **R1, file storage, S2
compression, `max_age: 7d`, six subjects, about twenty `sources`**, 50,319,725 messages, 39 GiB
reported, about 7 GB on disk. A `GOMEMLIMIT` of 1800 MiB; more than ten cores available.

The reporter killed the pod to pick up a config change (the reload had failed: `config reload not
supported for jetstream max memory and store`). The shutdown log is the **clean** path — `Initiating
JetStream Shutdown...`, `JetStream Shutdown`, `Server Exiting..` — and the next start logged:

```
15:56:24.874369 [INF]   Starting restore for stream 'project > project-event'
15:56:26.795870 [INF]   Restored 274,003 messages for stream 'project > project-controller' in 1.921s
15:56:34.458356 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: leafnode, websocket, server"
[previous message repeated regularly]
16:03:03.158149 [INF]   Restored 50,005,377 messages for stream 'project > project-event' in 6m38.284s
```

During those six minutes: CPU "near but lower than 2 cores", memory under 1.4 GB, and **about
20 MB/s of constant disk reads, no writes** — "it fits with the duration and total disk usage",
i.e. the whole store was read once. A second restart with the correct `max_file_store` was just as slow.

## What the maintainers said

- @wallyqs: *"is it a version past v2.11.11? newer versions do this in parallel"* — the parallel
  stream loading of v2.11.11 / v2.12.2 (#7482, #7526). The reporter was on 2.12.5, so already had it,
  and had one large stream, which parallelism across streams cannot help.
- @derekcollison: *"On a clean shutdown startup should be very fast. If the shutdown is not clean the
  server will need to rebuild the metadata and indexes for the stream on restart."* Then, shown the
  clean shutdown and the six subjects: *"Ok that does not seem normal given not that many subjects."*
  He asked for a CPU profile and a `stacksz`.
- The reporter posted the `stacksz`. No reply followed. The last message, 2026-04-13: *"is it true also
  in standalone mode that it should be fast after a clean shutdown?"* — still open on 2026-09-02.

## What the dump says

Goroutine 111 — the one running the restore of `project-event` — is not rebuilding anything. It is
in a `read` syscall inside:

```
(*msgBlock).loadBlock                 filestore.go:7729
(*msgBlock).loadMsgsWithLock          filestore.go:7784
(*msgBlock).prevMatchingMulti         filestore.go:2967
(*fileStore).LoadPrevMsgMulti         filestore.go:8597
(*stream).startingSequenceForSources  stream.go:4311
(*stream).setupSourceConsumers        stream.go:4358
(*stream).subscribeToStream           stream.go:4408
(*stream).setLeader                   stream.go:1166
(*Account).addStreamWithAssignment    stream.go:966
(*Account).recoverStream              stream.go:628
(*Account).EnableJetStream.func2      jetstream.go:1566
```

(line numbers are 2.12.5's; the same path at v2.14.6 is quoted in
[[s-nats-server-filestore-recovery]]). Thirty-five other `parallelTaskQueue` workers sit idle on a
channel: there was nothing else to recover in parallel. `startingSequenceForSources` is the
**backward scan a stream with `sources` makes at every start** to find the last message it received
from each source: it walks from the last sequence towards the first, loading each block in full,
and stops early only when it has seen a message from *every* configured source. With about twenty
sources, any one of them that had gone quiet — or had never delivered anything — sends the scan to
sequence 1. Seven gigabytes at 20 MB/s is six minutes. That is why the store read completely, why
the CPU stayed under two cores (one goroutine, one block at a time, S2 decompression), and why a clean
shutdown made no difference: `index.db` was fine, and the time is spent *after* the store is recovered
but *inside* the `Restored … in` timer, because on an R1 stream the source setup runs inline in
`recoverStream` → `setLeader` → `subscribeToStream`.

The maintainers fixed exactly this for 2.15 without reference to this thread: PR #8282 (merged
2026-08-20) indexes sources in `sources.db`, and v2.15.0-preview.1's notes say *"Restarts and leader
changes previously required expensive backward scans through the stream to find the last sourced
indices"* (see [[s-nats-server-filestore-recovery]]). At v2.14.6 the scan is still there.

## Practical takeaways

- The `Restored N messages for stream … in <duration>` line measures more than the store recovery.
  On an R1 stream with `sources` it includes the source scan; nothing in the log names the scan.
- `Healthcheck failed: "failed to be ready for connections …"` repeating through a restart is the
  readiness probe failing for as long as the restore takes — under the Helm chart that is the pod
  staying not-ready, and on a cluster it would be the node not rejoining.
- "Clean shutdown ⇒ fast start" holds for the store (`index.db`), not for a sourcing stream on
  2.10–2.14. The reporter's question about standalone mode has a yes-and-no answer: yes for the
  store, no for a stream with an idle source.
- Diagnose from a `stacksz` (`/stacksz` on the monitoring port, or `nats server request profile`
  once the server answers): if the restoring goroutine is in `startingSequenceForSources`, it is the
  scan; if it is in `rebuildStateFromBufLocked`, it is an unclean stop or a refused `index.db`.

## Notable quotes

> "I see about 20MB/s of constant disk read access (no writes) during the startup. From this it seems
> all the data on disk are being scanned (it fits with the duration and total disk usage). […] what
> I'm worried is that all data are reread on startup even after a clean shutdown." — the reporter

> "On a clean shutdown startup should be very fast. If the shutdown is not clean the server will need
> to rebuild the metadata and indexes for the stream on restart." — @derekcollison

## Relevance to the wiki

The only public report of a multi-minute restore with its own goroutine dump, and the one that
shows the `Restored … in` line charging a source scan to "restore". The gotcha
[[jetstream-recovery-is-slow]] is built on it; the run that reproduces the shape on 2.14.6 is
[[s-nats-server-stream-scale-observed]].

## Questions it answers

Row **13** (the mechanism the thread never received, the run, and the 2.15 fix).

## Pages touched

[[jetstream-recovery-is-slow]] · [[filestore-layout]] · [[mirrors-and-sources]] ·
[[jetstream-sizing]] · [[kubernetes-storage]] · [[nats-server-2.12]] · [[nats-server-2.15-preview]]
