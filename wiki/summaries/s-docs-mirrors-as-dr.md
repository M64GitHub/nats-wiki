---
title: "docs.nats.io — Mirrors as a DR tool"
type: summary
area: [jetstream, topology, deploy]
source-url: https://docs.nats.io/learn/backup-recovery/mirrors-and-sources.md
source-path: raw/nats-docs/learn/backup-recovery/mirrors-and-sources.md
author: NATS documentation (Synadia Communications, Inc.)
article: Mirrors as a DR tool
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [mirror, disaster-recovery, rpo, rto, lag, snapshot, failover]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Mirrors as a DR tool

The same mechanism as [[s-docs-mirrors-and-sources]], read as an availability tool: what `Lag`
means in RPO terms, and the one sentence that stops a mirror being mistaken for a backup.

## Key claims

**A mirror answers a different question from a snapshot.** "A snapshot answers 'what point can I
return to', and a mirror answers 'what site can I promote to take over'."

**R3 does not cover site loss.** "The R3 replication that protects you from losing *one node* does
nothing when you lose the *whole cluster*."

```
nats --server nats://site2:4222 stream add ORDERS_DR --mirror ORDERS --defaults
nats --server nats://site2:4222 stream info ORDERS_DR
```

**The Mirror Information block is the DR dashboard:**

```
Mirror Information:
  Stream Name: ORDERS
          Lag: 0
    Last Seen: 1.20s
```

- **`Stream Name`** — "If it says anything else, the mirror points at the wrong source."
- **`Lag`** — "the count of messages the upstream has that the mirror doesn't have yet … **Any number
  above zero is the data you'd lose if the primary vanished this instant.**"
- **`Last Seen`** — "how long ago the mirror last heard from its upstream … A growing `Last Seen`
  means the mirror is no longer keeping up, and the `Lag` you read is already stale."
- **In the monitoring JSON the last-seen field is named `active`** — the name differs from the CLI
  label.

**Lag is RPO; a mirror's short recovery is RTO.** "A mirror at `Lag: 0` gives you an RPO of zero
messages; a mirror that trails by thousands gives you an RPO of thousands." And: "A mirror's RTO is
short, because the data is already there."

**A mirror is not a backup** — the page's thesis, quoted:

> "A mirror follows the upstream's live writes, so a corrupt write lands in the mirror too — and a
> mirror keeps no earlier state to rewind to."

**What an upstream delete or purge actually does to a mirror**, which the page flags as
counter-intuitive:

- **Delete the upstream** and the mirror "is *not* deleted with it: it keeps every message it had
  already copied, stops receiving new ones, and **records the fault in the `Error` field of its
  Mirror Information**".
- **Purge a range upstream** and "the messages the mirror already stored stay put; the purge only
  caps what the mirror will still receive, because it **detects the sequence gap and skips the
  missing messages**".
- Either way the mirror survives "only as a stale copy frozen at the break, never as a point in time
  you chose".

**The two tools cover two different failures:**

| tool | failure it covers | cost |
|---|---|---|
| **Mirror** | the site failed — promote the copy | short RTO, no data loss if lag was zero |
| **Snapshot** | the data is wrong (deleted, purged, corrupted) | bounded RPO, restore-length RTO |

"Don't let a healthy mirror be your reason to stop taking snapshots."

**Configuration is fixed once the stream exists** — "you can't re-point a running mirror at a
different upstream or change what it copies in place … Plan the upstream, the site, and the subjects
you want once, upfront."

**Two pitfalls:** "A mirror is not a backup", and "**Read `Lag` before you trust the copy** … If
you've never checked a mirror, you don't know how far it trails." Watch it continuously, not once:
"A mirror that quietly stops keeping up is worth catching long before the day you need it."

## Practical takeaways

- **`Lag` is a number with a business meaning.** It is not a health metric to eyeball; it is the
  message count you have agreed to lose. That reframing is the page's most useful contribution.
- **`Last Seen` invalidates `Lag`.** A stale link means the lag figure is stale too — so an alert on
  `Lag` alone can read healthy while replication is dead.
- **The upstream-delete behaviour is a real operational surprise**: the mirror does not vanish, it
  freezes and records an `Error`. Worth knowing before an incident, because it looks like the mirror
  is fine.

## Notable quotes

> "Any number above zero is the data you'd lose if the primary vanished this instant."

## Relevance to the wiki

The DR half of [[mirrors-and-sources]], and the groundwork for the wanted runbook
[[backup-and-restore-jetstream]] in the current plan.

## Questions it answers

Q45 partially (multi-region availability via a mirror at a second site); Q32 and Q39 need the
snapshot and disaster-recovery pages, which are step 3 of the current plan.

## Pages touched

[[mirrors-and-sources]] · [[replicas]] · [[stream]] · [[monitoring-endpoints]] ·
[[backup-and-restore-jetstream]]
