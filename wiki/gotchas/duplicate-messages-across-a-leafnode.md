---
title: "duplicate messages across a leafnode"
type: gotcha
area: [topology, core]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [leafnode, supercluster, gateway, duplicates, loop, deny_imports, dns, urls]
aliases: ["duplicate messages leafnode", "messages repeated leafnode", "leafnode loop", "message loop", "duplicates supercluster"]
sources: [s-gh-4823-leafnode-supercluster-duplicates, s-docs-leaf-nodes, s-docs-super-clusters, s-nats-server-topology]
created: 2026-08-31
updated: 2026-08-31
---

# Duplicate messages across a leafnode

A subscriber behind a leafnode receives the same message several times, out of order, in bursts. It
is not redelivery and it is not a client bug — it is a routing loop, and it has one common cause.

## Symptom

Sequence numbers as observed by a subscriber in the leaf cluster (source:
[[s-gh-4823-leafnode-supercluster-duplicates]]):

```
9867,9866,9867,9867,9867,9867,9868,9869,…,9879,9868,9869,9870,9871,9880,9872,9873,9881,9882,9874,…
```

against an expected `13702,13703,13704,…`. The tell is not the duplication alone but the
**re-run of a whole window** — a range of sequences repeating after later ones have already arrived.
Redelivery repeats *one* message; a loop repeats a *stretch*.

Three more observations that go with it, all from the same report:

- "it only happens on 2 out of 3 nodes on Cluster 3… When I scale nats back to 1 replica, it doesn't
  happen."
- Only **intra-leaf** traffic duplicates: a leaf app asking a leaf app duplicates, the same request
  from the hub side does not.
- Adding subjects to `deny_imports` makes it stop — "the funny thing about this one is that there is
  no application on Cluster 1 and Cluster 2 that is publishing messages on those topics."

## Quick triage

```
nats server report leafnodes          # how many links, from where, on which account
```

Then read the leaf's own `leafnodes.remotes[].urls` list and ask one question: **do these URLs name
servers of one NATS system?**

```
nats server report gateways           # are the hub-side clusters one supercluster?
```

If `urls` names servers from two clusters that are joined by a gateway, stop here — that is the
cause.

## Causes, ranked

### 1 · The leaf's `urls` list spans two clusters of one supercluster

The most common cause, and the one a maintainer named:

> "A Leafnode bridges NATS systems. A Supercluster is a single system, so the LN connections from
> cluster 3 in Asia should only connect once to the supercluster, not to each cluster 1 & 2."
> — @derekcollison (source: [[s-gh-4823-leafnode-supercluster-duplicates]])

**How to confirm.** The remote's `urls` contains addresses that resolve into two different clusters:

```
leafnodes {
  remotes: [
    { urls: [ "nats-leaf://cluster-1:7422", "nats-leaf://cluster-2:7422" ] }   # ← two systems' worth
  ]
}
```

A `urls` list is a **reconnect pool for one system**, not a list of systems to bridge
(source: [[s-docs-leaf-nodes]]). Two entries into one supercluster means the leaf has two ways into
the same address space, and traffic that goes up one comes back down the other.

**The fix.** One bridge per NATS system. Point the leaf at one cluster, and reach the supercluster
through DNS rather than a longer list:

> "For superclusters we recommend cname DNS for clusters and a geo-aware global DNS for the whole
> thing which is what we do with Synadia Cloud."
> — @derekcollison, same thread

So: a CNAME per cluster, a geo-aware record over the whole super-cluster, and one URL — or several
URLs that all resolve within **one** cluster, which is the normal reconnect pool.

### 2 · A loop built from account imports and exports

> "Its possible to create a loop using account imports and exports. Normal mis-configuration loops
> are usually caught by the system when the LN's are established."
> — @derekcollison, same thread

**How to confirm.** Look for an export in account A that is imported by account B on a subject
pattern that A also imports back, directly or through a leaf. The server catches *some* of these at
connection time; the guard is explicitly partial in the JetStream-domain case too, with a source
comment saying it "will only cover some forms of this issue"
(source: [[s-nats-server-leafnode-js-domains]]).

**The fix.** Break the cycle in [[cross-account-sharing]]. Prefer narrow subject patterns on both
halves of an export/import pair; `>` on either side is what makes a cycle easy to build by accident.

### 3 · Not this page: at-least-once redelivery

If the repeats are of a **single** message and the consumer is a JetStream consumer, this is ordinary
redelivery — see [[ack-and-redelivery]] and [[consumer-keeps-redelivering]]. The shape is different:
one message repeated on an `ack_wait` cadence, not a window replayed.

## Prevention

- **One leafnode bridge per NATS system.** Write it into the review checklist for any leaf that
  attaches to a supercluster.
- **Reach a supercluster by DNS**, not by enumerating clusters in `urls`.
- **`deny_imports` is not the fix.** It works by cutting one direction of the loop, needs extending
  every time a new subject appears, and leaves the loop in place. If the mitigation that helped was
  adding subjects to `deny_imports`, you have this bug (source:
  [[s-gh-4823-leafnode-supercluster-duplicates]]).
- Scale-to-one "fixing" it is a symptom, not a diagnosis: fewer leaf servers means fewer paths around
  the loop.

## Explained by

[[leafnode]] — what a `urls` list is, and why a leaf bridges *systems*.
[[gateway]] — why a supercluster is one system.

## Related

[[leafnode]] · [[gateway]] · [[choosing-a-topology]] · [[cross-account-sharing]] ·
[[account]] · [[multi-region-jetstream]] · [[streams-not-visible-across-a-leafnode]]

## Sources

[[s-gh-4823-leafnode-supercluster-duplicates]] · [[s-docs-leaf-nodes]] · [[s-docs-super-clusters]] ·
[[s-nats-server-topology]]

## To verify

- The thread ran on **nats-server 2.9.24**. The answer is architectural rather than version-specific,
  and nothing in the 2.10–2.14 release notes in `raw/release-notes/` describes a change here — but
  the behaviour has **not** been re-tested on 2.14.
- "Normal mis-configuration loops are usually caught by the system when the LN's are established" —
  which loops the server catches, and what it logs when it does, has not been read from the source.
