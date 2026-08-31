---
title: "gh#4342 — Backup data in nats-server with jetstream enabled where storage is memory"
type: summary
area: [jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/discussions/4342
source-path: raw/gh-discussions/gh-4342.md
author: "@anil1996 (asking), @derekcollison and @jnmoyne (maintainers, answering)"
article: "Backup data in nats-server with jetstream enabled where storage is memory"
date: 2023-07-27
version: "2.9"
tags: [memory-streams, backup, mirror, healthz, rolling-restart, replicas]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#4342 — Backing up a memory stream

The thread behind question-bank **Q32**, with an **accepted answer** from a maintainer. Two
questions, two answers, and both are about the thing the docs' backup chapter cannot do.

## Key claims

**Can a memory stream be backed up? No** (@derekcollison, marked as the answer):

> "Not currently.
>
> If you run the stream as an R3 and do rolling restarts and `/healthz` checks it will survive.
>
> **If you really need to, create a file backed mirror and back that up.**"

Three separate points in three lines:

1. **There is no backup path for a memory stream** — the same conclusion the server source reaches
   with `no impl` ([[s-nats-server-snapshot-restore]]).
2. **R3 plus a *proper* rolling restart is the availability answer.** The stream survives a restart
   because the other replicas hold it — the drain-and-gate procedure in [[upgrade-a-cluster]], with
   `/healthz` as the gate ([[monitoring-endpoints]]).
3. **A file-backed mirror is the supported workaround**: mirror the memory stream into a file stream
   and snapshot *that* ([[mirrors-and-sources]]).

**And for a controlled restart of an R1 memory stream** (@jnmoyne, the following day) — a procedure,
not a warning:

> "before the restart update the stream's configuration to set `replicas=3`, check using
> `nats stream info` that all the new replicators have caught up, restart your server and then update
> the stream's configuration back to `replicas=1`."

with the boundary stated plainly:

> "If it's fault-tolerance you need (unscheduled server restart) then you must use `replicas=3`."

## Practical takeaways

- **"Temporarily R3" is a real technique**, and it is the same catch-up gate as everywhere else in
  this wiki: raise `--replicas`, wait for `current` with zero lag, act, lower it again
  ([[rebalance-streams]]). It converts a memory stream's restart from data loss into a no-op — but
  only for a *planned* restart.
- **A memory stream's durability story is entirely other people's copies.** Nothing on disk, nothing
  to snapshot; the copies are replicas or a mirror.
- **The maintainer's mirror suggestion is the only documented-by-anyone way to get a memory stream
  into an archive**, and no docs page says it.
- **The answer is from 2023 and still matches v2.14.6**, where `memStore.Snapshot` returns `no impl`
  — three years, no change.

## Notable quotes

> "If you really need to, create a file backed mirror and back that up." — @derekcollison

> "If it's fault-tolerance you need (unscheduled server restart) then you must use replicas=3." —
> @jnmoyne

## Relevance to the wiki

The *Memory streams* section of [[backup-and-restore-jetstream]] — which had inferred the mirror
workaround before this thread was read, and now states it with a maintainer behind it.

## Questions it answers

**Q32**, the memory-stream half, from the thread the row was mined from.

## Pages touched

[[backup-and-restore-jetstream]] · [[mirrors-and-sources]] · [[replicas]] · [[upgrade-a-cluster]] ·
[[rebalance-streams]]
