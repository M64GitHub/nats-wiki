---
title: Back up and restore JetStream
type: operation
kind: runbook
area: [jetstream, deploy]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [backup, restore, snapshot, memory-streams, chunk-size, window-size, 10064, 10130, consumers]
aliases: [backup, restore, snapshot, "nats stream backup", "nats stream restore", "back up a stream"]
sources: [s-docs-stream-backup-restore, s-nats-server-snapshot-restore, s-gh-4342-memory-stream-backup, s-natscli-backup-restore, s-docs-disaster-recovery, s-docs-mirrors-as-dr]
created: 2026-08-31
updated: 2026-08-31
---

# Back up and restore JetStream

Take a point-in-time copy of a stream the cluster cannot touch, and put it back. **Replication is not
a backup** — an accidental purge or a bad publisher replicates to all three copies at once
(source: [[s-docs-disaster-recovery]]). A snapshot is the only copy that predates a mistake.

## Goal

A dated, off-site snapshot directory you have **restored at least once**, and a restore procedure
whose result you verify by counting messages rather than by reading an exit code.

## Preconditions

- **The stream must be file-backed.** A memory stream cannot be snapshotted at all — see *Memory
  streams* below. Storage type is fixed at creation ([[stream]]).
- Credentials that may call `$JS.API.STREAM.SNAPSHOT.<stream>` and `…RESTORE.<stream>`
  ([[js-api-subjects]]).
- Somewhere to put it that is **not next to the cluster** — "a snapshot left next to the live cluster
  does not survive the event that takes the cluster down".

## Steps

### Take the snapshot

```
nats stream backup ORDERS ./backups/orders/2026-06-04 --consumers
```

```
Starting backup of Stream "ORDERS" with 1 data file
...
Received 4 MiB compressed data in 128 chunks for stream "ORDERS" in 0.41s, 4.0 MiB uncompressed
Backup of "ORDERS" took 0.41s
```

The directory holds exactly two things:

| file | contents |
|---|---|
| `backup.json` | the stream's **configuration and state** — subjects, retention, limits, sequence range |
| `stream.tar.s2` | the **messages**, tarred and S2-compressed |

**`--consumers` is the default** (`nats stream backup` sets it `true`), and it is what brings durable
consumers back *at their saved delivery position* rather than at the start of the stream. Passing
`--no-consumers` drops that silently — nothing warns you until a consumer is missing in production
(source: [[s-natscli-backup-restore]]).

**Date the directory.** A snapshot is a point in time; `2026-06-04` says which one.

### Verify the messages while you copy them

```
nats stream backup ORDERS ./backups/orders/2026-06-04 --check
```

`--check` ("Checks the stream for health prior to backup") is the CLI form of the API's `jsck` field,
"Check all message's checksums prior to snapshot". It costs a full read of the stream and is the only
built-in defence against archiving corruption you have not noticed.

### Restore it

```
nats stream restore ./backups/orders/2026-06-04
```

**Two rules**, both enforced:

- **The stream must not already exist.** Restore recreates the stream; it does not merge into a live
  one. If it exists you get **10130** `JSStreamNameExistRestoreFailedErr`,
  `stream name already in use, cannot restore` ([[error-codes]]). After an accidental delete, restore
  **straight from the snapshot** — do not create an empty stream first.
- **The name cannot change.** The `nats` CLI refuses with
  `stream names may not be changed during restore` when `--config` names a different stream, and the
  server rejects a mismatch with **10060** `JSStreamNotMatchErr`. For a copy under a new name, restore
  under the original and then mirror or source it ([[mirrors-and-sources]]).

### Restore somewhere else, at a different size

Everything about the config *except the name* can change on restore, which is what makes a snapshot
usable for more than in-place recovery (source: [[s-natscli-backup-restore]]):

```
nats stream restore ./backups/orders/2026-06-04 \
  --cluster west --tag ssd --replicas 1
```

| flag | what it does |
|---|---|
| `--cluster <name>` | place the restored stream in a specific cluster |
| `--tag <tag>` | place it on servers carrying a tag (repeatable) — [[stream-placement]] |
| `--replicas <n>` | override the replica count, e.g. restore an R3 production stream as R1 in a DR site |
| `--config <file>` | restore under a different stream configuration entirely |

## Verify

**A restore you did not check is not a restore.**

```
nats stream info ORDERS
```

```
State:
         Messages: 1,000
            Bytes: 4.0 MiB
   First Sequence: 1
    Last Sequence: 1,000
 Active Consumers: 2
```

- `Messages` and `Last Sequence` must match the stream you snapshotted.
- `Active Consumers` shows the consumers back, if the snapshot carried them.
- A **short** count means the snapshot was taken under live writes that did not finish — snapshot a
  quiesced stream, or accept the snapshot's instant as your RPO.

**The backup command exiting zero proves the transfer finished, not that the archive restores.**
Rehearse a real restore on a schedule — the docs' minimum is **quarterly** — into a throwaway stream
or server ([[disaster-recovery]]).

A restore also raises advisories, which is how you find out about one nobody authorised:
`$JS.EVENT.ADVISORY.STREAM.RESTORE_CREATE.<stream>` and `…RESTORE_COMPLETE.<stream>`
([[advisories]]), and the server logs `Starting restore for stream '<account> > <stream>'`.

## Memory streams

**A memory stream cannot be snapshotted, and the error does not say so.** A snapshot copies the
stream's on-disk files; a memory stream has none. What the server returns is
`no impl` (`server/memstore.go:2425` at v2.14.6), wrapped as error **10064**
`JSStreamSnapshotErrF`:

```
snapshot failed: no impl (10064)
```

and logged server-side as `Snapshot of stream '<account> > <stream>' failed: no impl`.

The docs state the message as `memory streams do not support snapshots`; **the server does not
produce that string**, and the `nats` CLI does not pre-check the storage type either (source:
[[s-nats-server-snapshot-restore]], [[s-natscli-backup-restore]]; recorded as
`inbox/docs-issues.md` #15).

**There is no snapshot path for a memory stream**, and a maintainer says so directly — the accepted
answer on the thread this runbook's question comes from is "Not currently"
(source: [[s-gh-4342-memory-stream-backup]]). The options, from that same answer:

- **use file storage** for anything you need to survive — the decision is made at creation and cannot
  be changed afterwards ([[stream]]);
- **"create a file backed mirror and back that up"** — mirror the memory stream into a file-backed
  stream and snapshot *that* ([[mirrors-and-sources]]);
- **run it R3 and restart properly**: "If you run the stream as an R3 and do rolling restarts and
  `/healthz` checks it will survive" — the drain-and-gate procedure in [[upgrade-a-cluster]];
- accept that the stream is not recoverable.

**For a *planned* restart of an R1 memory stream there is a trick**, from a second maintainer on the
same thread: raise the stream to `--replicas 3`, wait until `nats stream info` shows every replica
`current`, restart the server, then set it back to `--replicas 1`. It moves the data onto peers for
the duration of the restart. It does **not** help with an unplanned one — "if it's fault-tolerance
you need … then you must use `replicas=3`" ([[rebalance-streams]]).

## Tuning a slow or distant link

The server chunks the tarball and keeps a window of unacknowledged chunks in flight. Defaults, read
from the source (`jetstream_api.go:4262–4264`, v2.14.6):

| setting | default | limits |
|---|---|---|
| chunk size | **128 KiB** | clamped to **1 KiB – 1 MiB** |
| window size | **8 MiB** (= 64 chunks) | clamped to **1 KiB – 32 MiB** |
| ack timeout | **5s** | — |

If an ack does not arrive within five seconds the backup aborts (`408 No Flow Response`). Make each
round trip cheaper:

```
nats stream backup ORDERS ./backups/orders/2026-06-04 --consumers --chunk-size 64k --window-size 1m
```

**Asking for a chunk larger than 1 MiB does nothing** — the server clamps it silently, even though
the generated reference documents the field's maximum as an int64
(`inbox/docs-issues.md` #17).

## Rollback

A restore that fails leaves nothing behind to undo — the stream is created by the restore, so a
failure means the stream does not exist. What needs care is the opposite direction: **removing a
damaged stream before restoring over it is irreversible**. Confirm the snapshot you are about to
restore is the one you want (`backup.json` carries the config and the sequence range) before deleting
anything.

## Pitfalls

**Replication is not a backup.** R3 protects against a node dying, not against a `purge`, a bad
migration or a logic bug. Those replicate three times, instantly ([[replicas]]).

**A mirror is not a backup either.** It copies the corrupt write too. It *does* survive an upstream
delete — it keeps everything it had and stops updating — which makes it often the freshest intact
copy after a mistake, but never an earlier point you chose ([[mirrors-and-sources]],
[[disaster-recovery]]).

**A snapshot beside the cluster is not off-site.** It must survive the event that takes the cluster
down.

**Snapshotting a live stream gives you the live stream's tail, not a consistent later point.** The
count you verify is the count the snapshot took, and everything after it is your RPO.

**`--no-consumers` is silent.** The restore succeeds, the stream is right, and the consumers are
gone.

**Restoring into a cluster whose meta group has no quorum will not work.** Restore goes through
`$JS.API`, which needs the meta leader ([[raft-in-nats]]).

## Related

[[disaster-recovery]] · [[backup-and-restore-identity]] · [[mirrors-and-sources]] · [[stream]] ·
[[replicas]] · [[error-codes]] · [[js-api-subjects]] · [[advisories]] · [[stream-placement]] ·
[[nats-cli]] · [[rebalance-streams]] · [[upgrade-a-cluster]] · [[stream-directories-disappear]] ·
[[malformed-or-corrupt-message]]

## Sources

[[s-docs-stream-backup-restore]] · [[s-nats-server-snapshot-restore]] · [[s-natscli-backup-restore]] ·
[[s-gh-4342-memory-stream-backup]] · [[s-docs-disaster-recovery]] · [[s-docs-mirrors-as-dr]]
