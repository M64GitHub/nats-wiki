<!-- source: https://docs.nats.io/learn/backup-recovery/disaster-recovery.md · fetched 2026-08-31 · section: disaster-recovery -->
# Disaster recovery

You now have two tools. A **snapshot** of `ORDERS` sits off-site under `./backups/orders/`, and a live **mirror**, `ORDERS_DR`, runs at `site2`. Each protects against a different failure, and reaching for the wrong one during an outage costs you either data or hours.

This page is the **runbook**: an ordered procedure that names the failure, picks the right tool, and carries out the recovery against the real `ORDERS` deployment. It also covers the one operation the earlier pages set up but never performed: **promotion**, turning the read-only `ORDERS_DR` into a writable primary.

## Match the failure to the tool

A runbook starts before the outage. The decision you don't want to make under pressure during an outage is *which tool*. Decide it ahead of time, per failure class.

| What happened                                                    | Reach for                                             | Why                                                                                                                                                                                 |
| ---------------------------------------------------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The whole `east` cluster is gone                                 | promote `ORDERS_DR`                                   | The mirror already holds the data; promotion is minutes, a restore is hours.                                                                                                        |
| Someone deleted or purged `ORDERS` by mistake                    | recover from `ORDERS_DR`, or restore the snapshot     | The mirror survives an upstream delete: it keeps every message it had copied and just stops updating, so it's usually the freshest intact copy. The snapshot is the older fallback. |
| Messages on `ORDERS` are corrupt or wrong (a bad publisher)      | restore a known-good snapshot, or purge the bad range | The bad data replicated to the mirror as well. The snapshot predates the corruption.                                                                                                |
| A consumer lost its position (`shipping` redelivering from zero) | restore a `--consumers` snapshot                      | Only the snapshot captured the consumer's saved delivery position.                                                                                                                  |

One principle runs through the whole table: a snapshot is the only copy that predates a mistake. A mirror follows the upstream's live writes, so a corrupt write replicates into it; it survives an upstream delete but only as a copy frozen at the break, never an earlier point you chose. That's why the chapter built both, and why [R3 replication](/learn/clustering/.md) is on neither row: replicating a bad write three times doesn't undo it.

## Failover: promote the mirror

When the `east` cluster is gone, the goal is to make `ORDERS_DR` start accepting writes so `order-svc` and the consumers can carry on at `site2`. That's promotion, and it's a short, ordered sequence. The animation below shows it end to end.

**Message flow — Promote a mirror on site loss (animated):** Disaster-recovery failover in five stages. site1 owns the writable ORDERS stream while ORDERS\_DR on site2 mirrors every message across the WAN. site1 goes dark, taking the primary and its clients with it; only the ORDERS\_DR mirror survives. Before failing over, an operator checks the mirror's lag and waits until ORDERS\_DR reports zero messages behind. The mirror is then promoted — reconfigured into a standalone, writable ORDERS stream on site2 — and order-svc and the consumers reconnect to site2 and resume from where the mirror left off.

* orderSvc → order-svc (subject: publish)
* order-svc → consumers (subject: deliver)
* order-svc → site2 (subject: mirror)
* orderSvc → site2 (subject: publish)
* site2 → consumers (subject: deliver)

### Step 1 — verify the lag is zero

A mirror trails its upstream by some **lag**: the count of messages it hasn't copied yet. Promote it while lag is non-zero and you start publishing on top of a stream that's still missing its tail. So the first runbook step is always the same: read the lag.

#### CLI

```
#!/bin/bash



# Before you promote ORDERS_DR, read how far it trails the upstream.

# A mirror is eventually consistent: it follows its upstream over the

# network, so at any instant it can be a few messages behind. The Lag

# field is that gap, in messages. Promote a mirror with non-zero lag

# and you publish on top of a stream that is still missing tail

# messages.



# Point at site2, where the ORDERS_DR mirror lives.

nats --server nats://127.0.0.1:5222 stream info ORDERS_DR



# Look at the Mirror block in the output:

#

#   Mirror Information:

#

#            Stream Name: ORDERS

#                    Lag: 0

#              Last Seen: 1.2s

#

# Lag: 0 means the mirror has caught up to every message the upstream

# had at last contact — it is safe to promote. A non-zero Lag means

# messages are still in flight; wait and re-run until it reaches 0.

#

# Last Seen is how long ago the mirror last heard from the upstream. If

# the upstream site is already gone, Last Seen climbs and Lag freezes at

# whatever it was when contact dropped — that frozen Lag is your data

# loss, your actual RPO for this failover.
```

#### C

```
// Before you promote ORDERS_DR, read how far it trails the

// upstream. Lag is that gap, in messages: promote a mirror with

// non-zero lag and you publish on top of a stream that is still

// missing tail messages.

s = js_GetStreamInfo(&si, js, "ORDERS_DR", NULL, &jerr);

if ((s == NATS_OK) && (si->Mirror != NULL))

{

    printf("Mirror of : %s\n", si->Mirror->Name);

    printf("Lag       : %" PRIu64 " messages\n", si->Mirror->Lag);

    // Active is how long ago the mirror last heard from the

    // upstream. If the upstream site is already gone, this

    // climbs and Lag freezes at whatever it was when contact

    // dropped — that frozen Lag is your data loss.

    printf("Last seen : %.1fs ago\n",

           (double) si->Mirror->Active / 1E9);



    // Lag 0 means the mirror has caught up to every message the

    // upstream had at last contact: it is safe to promote.

    if (si->Mirror->Lag == 0)

        printf("Safe to promote\n");

    else

        printf("Messages still in flight — wait and re-check\n");

}
```

If the `east` site is fully unreachable, the mirror can't reach its upstream and the lag stops at whatever it was when contact dropped. That stalled number is your real recovery point: the messages written to `ORDERS` after the last successful copy are lost. Note it, then proceed. Waiting for a lag that will never move to zero only extends the outage.

### Step 2 — drop the mirror config

A mirror is **read-only** by design: it rejects direct publishes because its only job is to follow its upstream. To make `ORDERS_DR` writable, you remove the mirror relationship from its configuration.

```
# At site2: edit ORDERS_DR so it is no longer a mirror.

# Removing the mirror source makes the stream a standalone primary.

nats --server nats://site2:4222 stream edit ORDERS_DR --no-mirror
```

Once the mirror config is gone, the stream stops following `east`. It still holds every message it had copied. Promotion doesn't touch the data, only the relationship.

### Step 3 — clear the lost stream's assignment

The subject bind in the next step fails if the old `ORDERS` assignment is still in the JetStream metadata. The server checks the subjects you're adding against every stream in the account, and losing the site doesn't remove the dead `ORDERS` on its own, so the edit comes back with `subjects overlap with an existing stream (10065)`. Clear the stale entry first:

```
# Remove the assignment for the lost ORDERS so its subjects are free.

nats --server nats://site2:4222 stream rm ORDERS --force
```

This is the official promotion order: free the mirrored stream's subjects, drop the mirror config (step 2), then bind those subjects to the promoted stream (step 4).

### Step 4 — add the subjects so it accepts writes

A mirror has no subjects of its own; it receives messages through the mirror mechanism, not by listening on `orders.>`. A writable primary needs to *bind* those subjects so publishers can reach it. Add them:

```
# Give the promoted stream the subjects ORDERS used to own.

nats --server nats://site2:4222 stream edit ORDERS_DR --subjects "orders.>"
```

`ORDERS_DR` now captures `orders.created`, `orders.shipped`, `orders.canceled` — the same subjects the lost primary held. It now functions as a full primary.

### Step 5 — redirect publishers and consumers

The last step redirects traffic. Point `order-svc` and the consumers at `site2` and they resume against the promoted stream:

```
# Publishers and consumers now connect to site2.

nats --server nats://site2:4222 pub orders.created \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'
```

The order JSON is byte-for-byte what `order-svc` always sent; only the server address changed. Failover is complete: the platform writes and reads at `site2`, and the data loss is exactly the stalled lag you noted in step 1.

Two deployment preconditions sit under this whole sequence. First, every `stream rm` and `stream edit` here goes through the JetStream metadata group, so that group has to keep quorum after the site is lost — if the failed site held the meta majority, no edit succeeds until the cluster recovers. Second, the promoted stream must live where that quorum survives. That's why a DR mirror is normally placed in its own JetStream domain (a leaf node) or an independent cluster, rather than sharing one meta group that spans both sites.

How the mirror replicated those messages in the first place (the config, the filters, the start position) is the JetStream chapter's job, covered in [Mirrors and sources](/learn/jetstream/mirrors-and-sources.md). The runbook only reads the lag and changes the relationship.

## Recovery from a mistake: restore the snapshot

The other rows of the table roll back rather than fail over. When corrupt messages were written to `ORDERS`, the mirror is no help, because it copied the bad writes; the snapshot is the intact copy, taken before the bad event. An accidental delete or purge is the exception: the mirror keeps everything it had already replicated, so it's often the freshest surviving copy — recover from it when it holds more than the last snapshot, and fall back to the snapshot otherwise.

#### CLI

```
#!/bin/bash



# Recovery for a hard site loss or an accidental delete: rebuild ORDERS

# from the last off-site snapshot. Restore recreates the stream byte

# for byte — same messages, same sequence numbers, same config, and

# (because this snapshot was taken with --consumers) the same shipping

# and analytics consumers at their saved delivery position.

#

# Do NOT recreate an empty ORDERS first. Restore creates the stream

# itself; an existing stream of the same name makes the restore fail.

# After an accidental delete, restore straight from the snapshot.



nats --server nats://127.0.0.1:4222 stream restore ./backups/orders/2026-06-04



# Expected tail of the output:

#

#   Starting restore of Stream "ORDERS" from ./backups/orders/2026-06-04

#   ...

#   Restored stream "ORDERS" in 0.38s

#

#   Information for Stream ORDERS

#   ...

#            Messages: 1,000

#       First Sequence: 1

#        Last Sequence: 1,000

#     Active Consumers: 2

#

# Then verify: the message count and last sequence must match what the

# snapshot held. Everything published after the snapshot was taken is

# gone — that gap is your recovery point. A snapshot you never test is

# a guess, so rehearse this restore on a schedule, not during the

# outage.
```

For an accidental delete, restore straight from the snapshot. Don't recreate an empty `ORDERS` first, because restore creates the stream itself and an existing stream of the same name makes it fail. For logical corruption, stop the publishers first so no new bad data races in, then either purge the corrupt sequence range or restore a known-good snapshot that predates it. For a lost consumer position, a snapshot taken with `--consumers` brings the durable consumer config and its delivery position back together.

The mechanics of the snapshot itself (chunking, the `backup.json`, the restore name rule) live one page back on [Stream backup and restore](/learn/backup-recovery/stream-backup-restore.md). Here it's one step in a larger procedure.

## Pitfalls

The runbook fails most often on the order of the steps and the assumptions around them rather than on the commands themselves. Four common mistakes happen mid-outage.

**Never promote a mirror before lag reaches zero.** Promotion makes the mirror writable. If you do it while messages are still in flight from the upstream, those tail messages are lost and new writes land on top of the gap. Always run the lag check first, and only proceed at `Lag: 0` or with a stalled lag you've consciously accepted as your recovery point. Read the lag and don't skip step 1.

You can make that check a gate. Run the lag check from [step 1 above](#step-1--verify-the-lag-is-zero), decide on the number, then promote, never the reverse.

**R3 replication will not save you from a mistake.** A three-replica stream survives a node loss, but an accidental delete or a bad publish replicates to all three copies at once. R3 is availability, not a backup. Don't put it on the mistake rows of the table; that's what snapshots are for.

**Stop publishers before purging corrupted messages.** Purging a bad sequence range while `order-svc` is still writing lets new corrupt data arrive behind you, so you keep purging against a tail that keeps growing. Stop the publishers, purge or restore, then resume.

**An untested snapshot is unverified.** A healthy `nats stream info` on the live stream tells you the live stream is healthy; it proves nothing about the archive in `./backups/orders/`. Rehearse the restore on a schedule (quarterly is a reasonable minimum) into a throwaway stream or server, so the first time you run it isn't during the outage.

## Where you are

You can now name a NATS failure and reach for the right tool quickly. A lost site means promote `ORDERS_DR`: verify lag, drop the mirror config, add the subjects, redirect traffic. A mistake (delete, corruption, or a lost consumer position) means restore the snapshot, the copy that predates the mistake — a mirror copies a corrupt write and only freezes at an upstream delete. R3 is on neither path; it's availability, not recovery.

The data plane is now fully covered: a snapshot you can restore to, and a site where you can promote the mirror.

## What's next

One layer is still unprotected. If a laptop full of keys is lost, or the servers are rebuilt clean, the data is recoverable but no one can prove who they are: the operator JWT, the account JWTs, the nkeys, and the creds are gone. The next page backs up the **identity** plane.

Continue to [Config and JWT backup](/learn/backup-recovery/config-and-jwt-backup.md).

## See also

* [Mirrors and sources](/learn/jetstream/mirrors-and-sources.md) — how a mirror replicates, the mechanism the runbook only reads the lag of.
* [Stream backup and restore](/learn/backup-recovery/stream-backup-restore.md) — the snapshot internals the restore step depends on.
* [Clustering](/learn/clustering/.md) — R3 leader election, the availability story that is not a recovery story.
