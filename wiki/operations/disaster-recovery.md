---
title: Disaster recovery
type: operation
kind: runbook
area: [jetstream, topology, deploy]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [disaster-recovery, promotion, failover, mirror, lag, rpo, 10065, meta-quorum, dr]
aliases: [DR, failover, "promote a mirror", "site loss", "recover a stream", RPO]
sources: [s-docs-disaster-recovery, s-docs-mirrors-as-dr, s-docs-stream-backup-restore, s-natscli-backup-restore, s-docs-surviving-node-loss]
created: 2026-08-31
updated: 2026-08-31
---

# Disaster recovery

Which copy to reach for when something has already gone wrong, and how to use it. The decision is
worth making **before** the outage, because the wrong choice costs either data or hours (source:
[[s-docs-disaster-recovery]]).

## Match the failure to the tool

| what happened | reach for | why |
|---|---|---|
| **the whole cluster or site is gone** | **promote the mirror** | it already holds the data — promotion is minutes, a restore is hours |
| **someone deleted or purged the stream** | the **mirror**, else the snapshot | a mirror survives an upstream delete: it keeps every message it had copied and stops updating, so it is usually the freshest intact copy |
| **the messages are corrupt** (a bad publisher) | **restore a snapshot** that predates it, or purge the bad range | the corrupt writes replicated into the mirror too |
| **a consumer lost its position** | restore a **`--consumers`** snapshot | only the snapshot captured the consumer's saved delivery position |

Two rules hold the table together:

- **A snapshot is the only copy that predates a mistake.** A mirror follows live writes, so a corrupt
  write reaches it; it freezes at an upstream delete but never at an earlier point *you* chose.
- **R3 is on none of these rows.** "R3 is availability, not a backup" — an accidental delete or a bad
  publish replicates to all three copies at once ([[replicas]]).

## Failover: promote a mirror

A mirror is read-only by design. Promotion turns it into a writable primary. Five steps, in this
order.

### Preconditions that were decided long ago

Both of these are **placement** decisions made when the DR mirror was built, not things you can fix
during the outage:

- **Every step below goes through the JetStream metadata group**, so that group must still hold
  quorum after the site is lost. If the failed site held the meta majority, no `stream edit` or
  `stream rm` succeeds until the cluster recovers ([[raft-in-nats]]).
- **The promoted stream must live where that quorum survives** — which is why a DR mirror normally
  sits in **its own JetStream domain (a leafnode) or an independent cluster**, rather than sharing one
  meta group spanning both sites ([[leafnode]], [[mirrors-and-sources]]).

### 1. Read the lag — this is your RPO

```
nats stream info ORDERS_DR
```

```
Mirror Information:
         Stream Name: ORDERS
                 Lag: 0
           Last Seen: 1.2s
```

`Lag` is the count of messages the mirror has not copied. **Promote at `Lag: 0`**, or with a stalled
lag you have consciously accepted.

When the upstream site is already gone, `Last Seen` climbs and `Lag` freezes at whatever it was when
contact dropped. **That frozen number is the data loss** — write it down; it is the incident's RPO.
Waiting for a lag that will never reach zero only extends the outage.

### 2. Drop the mirror configuration

```
nats stream edit ORDERS_DR --no-mirror
```

The stream stops following its upstream and keeps every message it had. Promotion changes the
relationship, not the data.

### 3. Free the lost stream's subjects

```
nats stream rm ORDERS --force
```

**Do not skip this.** Losing the site does not remove the dead stream's assignment from the
metadata, and the server checks new subjects against every stream in the account — so step 4 comes
back with `subjects overlap with an existing stream`, error **10065**
`JSStreamSubjectOverlapErr` ([[error-codes]]).

### 4. Bind the subjects

```
nats stream edit ORDERS_DR --subjects "orders.>"
```

A mirror has no subjects of its own — it receives through the mirror mechanism, not by listening. A
writable primary must bind them.

### 5. Redirect publishers and consumers

```
nats pub orders.created '{"order_id":"ord_8w2k"}' --server nats://site2:4222
```

Only the server address changes. Failover is complete, and the data loss is exactly the lag from
step 1.

## Recovery from a mistake: restore

For corruption, or when the mirror holds less than the last snapshot:

```
nats stream restore ./backups/orders/2026-06-04
```

- **Do not recreate an empty stream first** — restore creates it, and an existing stream of the same
  name fails with **10130** (`stream name already in use, cannot restore`).
- **For logical corruption, stop the publishers first**, then purge the bad sequence range or restore
  a snapshot that predates it. Purging while writes continue means purging against a growing tail.
- **A restore can land somewhere else**: `--cluster`, `--tag` and `--replicas` place the restored
  stream, so a production R3 snapshot can come back as R1 in a DR site
  ([[backup-and-restore-jetstream]]).

The mechanics — chunking, `backup.json`, the name rule, memory streams — are in
[[backup-and-restore-jetstream]].

## Verify

After a **promotion**:

```
nats stream info ORDERS_DR      # no Mirror block; Subjects lists orders.>; a named Leader
nats pub orders.created '{"order_id":"…"}'   # a write is accepted
nats consumer ls ORDERS_DR                   # the consumers that survived
```

After a **restore**: `nats stream info ORDERS` — `Messages` and `Last Sequence` against what the
snapshot claimed, and `Active Consumers` if it carried them.

Either way, record the RPO: the frozen lag, or the snapshot's timestamp.

## Rollback

**Promotion is not reversible into the old topology.** Once `ORDERS_DR` accepts writes it has
diverged from anything the old site may still hold; if the original site comes back, it is a *new*
source of truth question, not a merge — the returning stream must be rebuilt as a mirror of the
promoted one, or reconciled by hand.

Decide before the outage which site wins in a split, and make step 3 (`stream rm`) the point of no
return you commit to deliberately.

## Pitfalls

**Promoting before the lag is read.** The tail is lost and new writes land on top of the gap. Read
the lag first — always.

**Skipping step 3.** `10065` mid-outage, on a step you did not expect to fail.

**Assuming the meta group survived.** If the lost site held the meta majority, every command in this
runbook fails until quorum returns. This is the failure mode that turns a 5-minute promotion into an
outage, and it is prevented only at design time.

**Treating R3 as DR.** It is not on any row of the table.

**An untested snapshot.** A healthy `nats stream info` on the *live* stream says nothing about the
archive. Rehearse restores on a schedule; quarterly is the docs' minimum.

**Forgetting the identity plane.** A restored stream nobody can authenticate against is not a
recovery — [[backup-and-restore-identity]].

## Related

[[backup-and-restore-jetstream]] · [[backup-and-restore-identity]] · [[mirrors-and-sources]] ·
[[replicas]] · [[raft-in-nats]] · [[error-codes]] · [[stream-placement]] · [[leafnode]] ·
[[rebalance-streams]] · [[upgrade-a-cluster]] · [[nats-cli]] · [[malformed-or-corrupt-message]] ·
[[jetstream-out-of-disk]]

## Sources

[[s-docs-disaster-recovery]] · [[s-docs-mirrors-as-dr]] · [[s-docs-stream-backup-restore]] ·
[[s-natscli-backup-restore]] · [[s-docs-surviving-node-loss]]
