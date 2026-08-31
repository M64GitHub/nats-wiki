---
title: Mirrors and sources
type: concept
area: [jetstream, topology, deploy]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [mirror, sources, lag, mirror_direct, subject_transforms, filter_subject, external, dr, 10060]
aliases: [mirror, mirrors, sources, source stream, stream sourcing, mirror_direct]
sources: [s-docs-mirrors-and-sources, s-docs-mirrors-as-dr, s-adr-31-direct-get]
created: 2026-08-31
updated: 2026-08-31
---

# Mirrors and sources

The two ways to build one [[stream]] from another. A **mirror** is an exact read-only copy of a
single stream; **sources** merge many streams into one. Both replicate continuously and both are
eventually consistent (source: [[s-docs-mirrors-and-sources]]).

For an operator they are three different tools wearing one mechanism: a read replica, an aggregate,
and a disaster-recovery copy at a second site.

## How they behave

| | **Mirror** | **Source** |
|---|---|---|
| upstreams | exactly **one** | one or **many** |
| sequence numbers | **kept from the upstream** | **fresh**, interleaved across sources |
| timestamps and subjects | kept from the upstream | as delivered |
| own subjects, direct publishes | **no — read-only** | yes, optional |
| change the config later | **no — delete and recreate** | yes — add, drop or edit sources |
| ordering | the upstream's order | per-upstream order kept; **no order across upstreams** |

**A mirror's copy is exact.** "A message in the mirror keeps the same sequence number, the same
timestamp, and the same subject it had upstream." If `orders.created` was sequence 1 upstream, it is
sequence 1 in the mirror.

**A mirror is read-only because it listens on no subjects of its own.** A publish routes to whatever
stream owns the subject — the origin, never the mirror.

**Both keep their own retention.** The upstream may keep seven days while the mirror keeps forever;
the mirror's own limits decide what it stores.

**Replication is asynchronous.** "The upstream stores a message and acknowledges the publisher
*before* the mirror has it." The gap is `Lag`.

## What configures it

```
nats stream add ORDERS-ARCHIVE --mirror ORDERS
nats stream add ALL-ORDERS --source ORDERS-US --source ORDERS-EU --source ORDERS-APAC
nats stream add ORDERS_DR --mirror ORDERS --defaults      # run against the second site
nats stream info ORDERS-ARCHIVE
```

Per-entry fields on a mirror or source: `filter_subject`, `subject_transforms`, `opt_start_seq`,
`external`. A mirror also interacts with [[direct-get]] through **`mirror_direct`** — see below.

`nats stream info` grows a block that a plain stream does not have:

```
Mirror Information:
  Stream Name: ORDERS
          Lag: 0
    Last Seen: 1.20s
```

A **sourced** stream carries a `Source Information` block **per upstream**, each with its own `Lag`
and `Last Seen`, "because each source replicates on its own".

Reading these three fields (source: [[s-docs-mirrors-as-dr]]):

- **`Stream Name`** — the upstream. "If it says anything else, the mirror points at the wrong source."
- **`Lag`** — messages the upstream has that the mirror does not. **This is your RPO**: "any number
  above zero is the data you'd lose if the primary vanished this instant."
- **`Last Seen`** — how long since the mirror heard from the upstream. A growing value means "the
  `Lag` you read is already stale". In the monitoring JSON this field is named **`active`**, not
  `last_seen`.

## Mirrors and Direct Get

A mirror can answer reads addressed to its **upstream**, which is how read load reaches servers in
another cluster or region. The switch is **`mirror_direct`** on the *mirror's* config, and it has
four rules that surprise people (source: [[s-adr-31-direct-get]]):

1. At create time, if the upstream is visible, `mirror_direct` is **forced to match the upstream's
   `allow_direct`** — a disagreeing value is rejected in pedantic mode and silently aligned
   otherwise.
2. If the upstream is not visible (an External mirror across domains), your value is preserved.
3. A mirror **only joins the read pool once it has caught up** to within a small lag window, so a
   fresh mirror contributes nothing to read availability yet.
4. **`mirror_direct` is captured at create time and never refreshed.** Toggling the upstream's
   `allow_direct` later desynchronises every mirror until each one is itself updated. Enabling or
   disabling mirror participation is therefore **two operations**: the upstream *and* an update on
   each mirror.

ADR-31's own advice: "always set `mirror_direct` to their desired value."

## Limits and failure modes

- **A mirror is not a backup.** "A mirror follows the upstream's live writes, so a corrupt write
  lands in the mirror too — and a mirror keeps no earlier state to rewind to." It gives you
  availability (short RTO), not a recovery point. Pair it with snapshots; see
  [[backup-and-restore-jetstream]].
- **Delete the upstream and the mirror does not die — it freezes.** It "keeps every message it had
  already copied, stops receiving new ones, and records the fault in the **`Error` field** of its
  Mirror Information". Purge a range upstream and the mirror keeps what it already stored, detects
  the sequence gap and skips the missing messages. Either way you are left with a stale copy frozen
  at the break, not a chosen point in time.
- **Publishing to a mirror fails in a confusing way.** The message lands in the origin stream that
  owns the subject. Force it with `Nats-Expected-Stream: ORDERS-ARCHIVE` and the server rejects it —
  **`expected stream does not match`, error `10060`** — because the subject routed to the origin.
- **`filter_subject` and `subject_transforms` are mutually exclusive on one entry.** The server
  rejects a config setting both. A transform filters *and* renames in one step; use it when you need
  the rename, `filter_subject` when you only need the subset.
- **Cross-account and cross-domain config fails silently.** The `external` block needs matching
  exports and imports, and **each of the three subjects has a required type**: the consumer API and
  flow-control subjects are **service** exports (request/reply), the delivery subject is a **stream**
  export (one-way). "Get a type wrong and replication doesn't fail with an error; the mirror never
  catches up."
- **A mirror's config is fixed at creation.** Changing the upstream, the filter or the transform is a
  delete-and-recreate. That is cheap — the upstream still holds the data — but it is not an edit.
  Sources, by contrast, can be added, dropped and edited in place.

## Why an operator cares

- **`Lag` is the number to alert on, and `Last Seen` is what validates it.** An alert on `Lag` alone
  reads healthy while replication is dead. On a sourced stream you need one alert per upstream.
- **Two of the failure modes are silent** — the wrong export type, and a desynchronised
  `mirror_direct`. Neither produces a log line; both produce a copy that quietly never catches up.
- **R3 is not a second site.** Replication protects against losing one node in a cluster; a mirror is
  what survives losing the cluster. See [[replicas]].

## Related

The promotion procedure that turns a mirror into a writable primary is [[disaster-recovery]];
what a snapshot protects that a mirror cannot is [[backup-and-restore-jetstream]].


[[stream]] · [[replicas]] · [[direct-get]] · [[error-codes]] · [[key-value]] · [[message-ttl]] ·
[[backup-and-restore-jetstream]] · [[monitoring-endpoints]] · [[account]]

## To verify

- **ADR-59** is named by the docs as the authoritative spec for sourcing and mirroring
  (`filter_subject`, `subject_transforms`, External streams, replication semantics) and **has not
  been ingested**; ADR-60 refines it for WorkQueue and Interest streams and is cited by
  [[nats-server-2.14]] but not read either. Both are local in `raw/adr/`.
- Whether a **KV mirror on file storage** is materially slower than on memory storage
  (question-bank Q76) is not addressed by any source read here.

## Sources

[[s-docs-mirrors-and-sources]] · [[s-docs-mirrors-as-dr]] · [[s-adr-31-direct-get]]
