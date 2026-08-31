---
title: "docs.nats.io — Disaster recovery"
type: summary
area: [jetstream, topology, deploy]
source-url: https://docs.nats.io/learn/backup-recovery/disaster-recovery.md
source-path: raw/nats-docs/learn/backup-recovery/disaster-recovery.md
author: NATS documentation (Synadia Communications, Inc.)
article: Disaster recovery
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [disaster-recovery, promotion, mirror, lag, rpo, failover, 10065, meta-quorum]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Disaster recovery

The runbook that chooses between a snapshot and a mirror, and the five-step **promotion** that turns
a read-only mirror into a writable primary — the operation the mirror pages set up but never perform.

## Key claims

**The decision table, which is the page's core contribution:**

| what happened | reach for | why |
|---|---|---|
| the whole cluster is gone | **promote the mirror** | "The mirror already holds the data; promotion is minutes, a restore is hours." |
| someone deleted or purged the stream | **the mirror, or the snapshot** | "The mirror survives an upstream delete: it keeps every message it had copied and just stops updating, so it's usually the freshest intact copy." |
| messages are corrupt (a bad publisher) | **restore a known-good snapshot**, or purge the bad range | "The bad data replicated to the mirror as well. The snapshot predates the corruption." |
| a consumer lost its position | **restore a `--consumers` snapshot** | "Only the snapshot captured the consumer's saved delivery position." |

> "A snapshot is the only copy that predates a mistake."

and, explicitly on the row that is not there:

> "**R3 replication will not save you from a mistake.** … an accidental delete or a bad publish
> replicates to all three copies at once. R3 is availability, not a backup."

**Promotion is five ordered steps**, and the order matters:

1. **Read the lag** — `nats stream info ORDERS_DR`, the `Mirror Information` block:

   ```
   Mirror Information:
            Stream Name: ORDERS
                    Lag: 0
              Last Seen: 1.2s
   ```

   > "If the upstream site is already gone … the lag stops at whatever it was when contact dropped.
   > **That stalled number is your real recovery point** … Waiting for a lag that will never move to
   > zero only extends the outage."

2. **Drop the mirror config** — `nats stream edit ORDERS_DR --no-mirror`. "Promotion doesn't touch
   the data, only the relationship."

3. **Remove the lost stream's assignment** — `nats stream rm ORDERS --force`. Without it the next
   step fails: "the server checks the subjects you're adding against every stream in the account, and
   losing the site doesn't remove the dead `ORDERS` on its own, so the edit comes back with
   `subjects overlap with an existing stream (10065)`."

4. **Bind the subjects** — `nats stream edit ORDERS_DR --subjects "orders.>"`. "A mirror has no
   subjects of its own; it receives messages through the mirror mechanism."

5. **Redirect publishers and consumers** to the surviving site.

**Two preconditions under the whole sequence**, stated once and easy to miss:

> "every `stream rm` and `stream edit` here goes through the JetStream metadata group, so **that
> group has to keep quorum after the site is lost** — if the failed site held the meta majority, no
> edit succeeds until the cluster recovers. Second, **the promoted stream must live where that quorum
> survives**. That's why a DR mirror is normally placed in its own JetStream domain (a leaf node) or
> an independent cluster, rather than sharing one meta group that spans both sites."

**Restoring instead of failing over:** "Do **not** recreate an empty `ORDERS` first. Restore creates
the stream itself; an existing stream of the same name makes the restore fail." For logical
corruption: "stop the publishers first so no new bad data races in, then either purge the corrupt
sequence range or restore a known-good snapshot that predates it."

**Four pitfalls:** never promote before lag is zero (or a stalled lag you have consciously accepted);
R3 is not a backup; stop publishers before purging; and —

> "**An untested snapshot is unverified.** … Rehearse the restore on a schedule (**quarterly is a
> reasonable minimum**) into a throwaway stream or server."

## Practical takeaways

- **The table is the artefact worth stealing.** Deciding tool-per-failure *before* an outage is the
  page's whole argument, and the reasoning ("a mirror copies a corrupt write; a snapshot predates
  it") is what makes it memorable.
- **`Lag` is the RPO, and a frozen `Lag` is the number you write in the incident report.**
- **Step 3 exists only because the dead stream's subjects still occupy the account.** It is the step
  people skip, and `10065` is what they get.
- **The meta-quorum precondition decides whether a DR mirror works at all**, and it is a *placement*
  decision made long before the outage: separate domain or separate cluster, never one meta group
  spanning both sites ([[raft-in-nats]]).

## Notable quotes

> "A snapshot is the only copy that predates a mistake."

> "R3 is availability, not a backup."

## Relevance to the wiki

The whole of [[disaster-recovery]], and the promotion procedure [[mirrors-and-sources]] describes
the mechanism for.

## Questions it answers

Contributes to **Q39** (the recovery half; the thread's question about *what corrupted* a cluster is
not answered here) and **Q45**.

## Pages touched

[[disaster-recovery]] · [[backup-and-restore-jetstream]] · [[mirrors-and-sources]] · [[replicas]] ·
[[raft-in-nats]] · [[error-codes]] · [[stream]]
