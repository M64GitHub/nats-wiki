---
title: "streams deleted when clustering a standalone server"
type: gotcha
area: [topology, jetstream, deploy]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-09-01
tags: [orphan, standalone, cluster, migration, data-loss, meta-layer]
aliases: ["orphaned streams", "streams marked orphan", "standalone to cluster", "R1 to R3 migration"]
sources: [s-gh-7831-standalone-to-cluster, s-docs-raft-and-leaders, s-docs-surviving-node-loss, s-nats-server-jetstream-cluster]
created: 2026-08-31
updated: 2026-09-03
---

# "streams deleted when clustering a standalone server"

You add a `cluster` block to a working standalone JetStream server, restart, and **the existing
streams are marked orphaned and deleted immediately** — before there is any chance to raise their
replica count. The data is gone.

> **Read this before the restart, not after.** There is no flag that undoes it and no window to
> react in. If you have already done it, the data is only recoverable from a backup taken
> beforehand.

## Symptom

Streams that existed on the standalone server are gone after the first restart in cluster mode.
The reporter in gh#7831 put it plainly:

> "when I restart NATS with the cluster configuration, the existing streams are immediately marked
> as orphaned and automatically deleted before I have any opportunity to update their replica
> counts. **This results in complete data loss.**"

## Quick triage

There is no triage. By the time the symptom is visible the streams are deleted. The only useful
check is the one done **before** the restart:

```
nats stream ls           # what exists on the standalone server
nats stream backup <stream> <dir>   # take it before you touch the config
```

## The cause

There is exactly one, and it is structural rather than a misconfiguration.

**A clustered deployment keeps the assignments in the meta layer; a standalone server has no such
record.** From the maintainer answer (source: [[s-gh-7831-standalone-to-cluster]]):

> "A clustered setup uses consensus and **stores on which servers those streams/consumers are hosted
> separately**. A single-server setup doesn't have/need that."

So when the same data directory comes up as part of a cluster, its streams have **no assignment in
the meta group** — see [[raft-in-nats]]. By the cluster's definition they are orphans, and orphan
cleanup removes them. The server is not losing data by accident; it is deleting data it has no
record of owning.

*How to confirm the diagnosis rather than something else:* the streams were R1 on a server with no
`cluster` block before the change, and they disappear on the **first** start after the block is
added.

### Confirmed on 2.14.6: the orphan check, and the 30 seconds before it

The mechanism is `checkForOrphans` in `server/jetstream_cluster.go`, whose own comment says what it is
for: recovered streams and consumers that "the meta layer's mappings should clean up, but under crash
scenarios there could be orphans". It runs **30 s after the server finishes replaying the meta log**,
only if a meta leader exists and this server is current with it, and deletes every stream recovered
from disk that has no assignment — logging exactly one line per stream. Reproduced: a standalone
server holding `ORPHAN` (R1, three messages) was restarted with a `cluster {}` block joining a live
cluster (source: [[s-nats-server-jetstream-cluster]]):

```
21:43:25.470 [INF]   Restored 3 messages for stream '$G > ORPHAN' in 1ms
21:43:25.471 [INF] JetStream cluster bootstrapping
21:43:26.018 [INF] JetStream cluster new metadata leader: n2/east
21:43:55.584 [WRN] Detected orphaned stream '$G > ORPHAN', will cleanup
```

Three things follow. **The stream is restored first** — the `Restored N messages` line is not a sign
it survived. **The window is 30 seconds**: the deletion happens only inside that check, so a server
stopped before the warning still has its stream directories on disk (unverified: the timing was
observed, the rescue was not tested). And **no INFO-level line announces it in advance**; the warning
is the deletion. Full mechanism: [[meta-layer]].


## The fix — pick one, before the restart

### Backup and restore

The maintainer's recommendation:

> "You'll likely need to take a backup of your streams and then restore them in the clustered
> setup."

Simple, well-supported, and requires downtime for the cutover. See
[[backup-and-restore-jetstream]].

### Leafnode plus mirrors

The lower-downtime path, from @wallyqs:

> "you can try to **leafnode connect the standalone server to a cluster and create mirrors of the
> streams first, then unplug the leafnode standalone server and make the streams stop being
> mirrors**"

@MauriceVanVeen called this "the most 'native' way to do this migration with minimal to no
downtime". It is also, in the thread's own words, "a bit involved" — the original reporter judged
that it "would require developing production-grade automation specifically for this use case" and
chose backup/restore instead. See [[leafnode]] and [[mirrors-and-sources]].

### What does not work

- **There is no configuration option or flag to prevent orphan cleanup.** The thread asks directly
  and none is offered.
- **You cannot raise R1 → R3 first and let it replicate.** The deletion happens on the restart that
  introduces the cluster block, before any edit is possible.
- **A single-node "cluster" as a seed** was raised by the reporter and not endorsed by either
  maintainer.

## Is a fix coming?

Asked whether in-place migration is planned, @MauriceVanVeen answered:

> "This is not planned at the moment. … Migrating is perhaps technically possible, but would be
> tricky to get right."

A community contributor proposed **adopting orphaned R1 streams** during the cluster-mode orphan
check and opened [PR #7988](https://github.com/nats-io/nats-server/pull/7988) on 2026-03-27.
@wallyqs was open to reviewing it but flagged "many edge cases to consider specially when there are
already present streams with the same name", and confirmed there is no roadmap item.

**As of the thread's last activity (2026-03-27) the PR was unreviewed, and nothing ingested says it
merged.** Do not plan around it.

## Prevention

- **Treat standalone and clustered as different deployments, not a configuration difference.** They
  differ in whether a meta layer exists at all.
- **Back up before any topology change**, not just this one.
- If HA is a possibility for a deployment, **stand it up as a cluster from the start** — even a
  three-node cluster on one host for a proof of concept — so the migration never has to happen.
  [[build-a-3-node-cluster]] is that procedure; [[install-nats-server]] says the same thing in its
  preconditions, because the cheapest moment to decide is before any data exists.

## Explained by

[[raft-in-nats]] (the meta group and what it holds) · [[replicas]] (why R1 has no peer to replicate
from) · [[meta-layer]]

## Related

[[backup-and-restore-jetstream]] · [[mirrors-and-sources]] · [[leafnode]] ·
[[no-suitable-peers-for-placement]] · [[build-a-3-node-cluster]] · [[replicas]]

## Sources

[[s-gh-7831-standalone-to-cluster]] · [[s-docs-raft-and-leaders]] · [[s-docs-surviving-node-loss]] · [[s-nats-server-jetstream-cluster]]
