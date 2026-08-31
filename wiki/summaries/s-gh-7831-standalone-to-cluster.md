---
title: "gh#7831 — Streams marked orphan and deleted when converting standalone to cluster"
type: summary
area: [topology, jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/discussions/7831
source-path: raw/gh-discussions/gh-7831.md
author: "@sourabhaggrawal (asked); @MauriceVanVeen and @wallyqs (NATS maintainers, answered)"
article: "GitHub Discussion 7831 (General)"
date: 2026-02-14
version: ""              # no server version stated by the reporter
tags: [standalone, cluster, migration, orphan, data-loss, mirrors]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#7831 — streams orphaned and deleted when clustering a standalone server

Opened 2026-02-14, **no answer marked** but answered clearly by two NATS maintainers. This is the
thread behind one of the most destructive mistakes an operator can make with JetStream.

## The report

Running JetStream **standalone** across multiple datacentres and wanting HA. The expectation was:
add the cluster block, restart, raise the streams from R1 to R3, let the data replicate.

> "However, when I restart NATS with the cluster configuration, the existing streams are immediately
> marked as orphaned and automatically deleted before I have any opportunity to update their replica
> counts. **This results in complete data loss.**"

## The answer — from the maintainers

**@MauriceVanVeen:**

> "Standalone single-server is different from clustered deployments and can't be migrated in place
> like that. You'll likely need to take a backup of your streams and then restore them in the
> clustered setup."

And on *why*, when asked whether in-place migration is planned:

> "This is not planned at the moment. A clustered setup uses consensus and **stores on which servers
> those streams/consumers are hosted separately**. A single-server setup doesn't have/need that.
> Migrating is perhaps technically possible, but would be tricky to get right."

**@wallyqs** offered the lower-downtime alternative:

> "a bit involved but either taking backups or think you can try to **leafnode connect the standalone
> server to a cluster and create mirrors of the streams first, then unplug the leafnode standalone
> server and make the streams stop being mirrors**"

@MauriceVanVeen called that mirroring approach "the most 'native' way to do this migration with
minimal to no downtime".

## The mechanism

The cluster's **meta layer holds the assignments** — which servers host which streams and
consumers. A standalone server has no meta layer and no such record. When the same data directory
comes up as part of a cluster, its streams have **no assignment in the meta layer**, so they are
orphans by definition, and orphan cleanup removes them.

## Status of a fix

**There is no configuration option or flag to prevent the cleanup** — the thread asks directly and
none is offered. A community contributor (@tilakraj94) proposed **adopting orphaned R1 streams**
during the cluster-mode orphan check and opened
[PR #7988](https://github.com/nats-io/nats-server/pull/7988) on 2026-03-27. @wallyqs responded that
the team is happy to look but flagged "many edge cases to consider specially when there are already
present streams with the same name", and confirmed:

> "no we don't have an item in the roadmap about this"

**As of the thread's last activity (2026-03-27) the PR was unreviewed.** Nothing ingested says it
merged.

## Practical takeaways

- **There is no in-place standalone → cluster migration.** The two are different deployments, not a
  configuration difference.
- **The deletion is immediate on restart**, before there is any chance to raise the replica count.
  There is no window to react in.
- Two supported paths: **backup and restore into the cluster**, or **leafnode + mirror + promote**.
- Neither is a flag. Both need planning before the restart, not after.

## Relevance to the wiki

The source for [[streams-deleted-when-clustering-a-standalone-server]], and the concrete reason the
[[meta-layer]] matters to an operator: it is the record whose absence makes a stream an orphan.

## Questions it answers

Q38 (why streams were marked orphan and deleted when converting standalone to a cluster) — this is
the thread the bank's row links to.

## Pages touched

[[streams-deleted-when-clustering-a-standalone-server]] · [[meta-layer]] · [[replicas]] ·
[[backup-and-restore-jetstream]] · [[mirrors-and-sources]]
