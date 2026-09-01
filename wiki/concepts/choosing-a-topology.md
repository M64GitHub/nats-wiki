---
title: Choosing a topology
type: concept
area: [topology, deploy, jetstream]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [topology, route, gateway, leafnode, supercluster, multi-region, decision, quorum]
aliases: [which topology, cluster vs gateway vs leafnode, leafnode or gateway, topology decision, super-cluster or leafnode]
sources: [s-docs-putting-it-together, s-docs-super-clusters, s-docs-leaf-nodes, s-docs-jetstream-in-a-cluster, s-gh-6328-jetstream-behind-gateways, s-gh-7438-multi-region-availability, s-nats-server-topology, s-gh-7494-supercluster-degradation, s-gh-4823-leafnode-supercluster-duplicates]
created: 2026-08-31
updated: 2026-09-01
---

# Choosing a topology

**Route, gateway or leafnode — the three ways two NATS servers can be joined, and they are not
alternatives to each other.** They are layers: you add one when the layer below runs out of room, and
the layer below keeps working (source: [[s-docs-putting-it-together]]).

The question people actually ask is narrower than "which topology": it is *which connection type
joins these two things*, and the answer follows from four properties, not from scale.

## The four properties that decide it

| | **route** (one cluster) | **gateway** (super-cluster) | **leafnode** |
|---|---|---|---|
| joins | server ↔ server | cluster ↔ cluster | system ↔ system |
| who dials | both, full mesh | both | **the leaf only, outbound** |
| connections | n−1 per server | one per remote **cluster** | one, however many clients behind it |
| assumes peers are | close | far apart | anywhere with egress |
| carries | all interest in the account | only interest the far side has | only interest the far side has |
| JetStream | **replicas live here** — R1…R5 within the cluster | **one meta group across all clusters** | **a separate meta group per [[jetstream-domain]]** |
| can draw a boundary | no | no | **yes**, bound to its own [[account]] |

Two rows do most of the work.

**Only a leaf can partition.** "Stacking these shapes gives you one address space by default. Routes
carry an account's full interest across a cluster; a gateway forwards any subject the far side wants.
Neither partitions anything — they widen where a message can go" (source:
[[s-docs-putting-it-together]]). If the requirement is isolation, the answer is a leaf plus an
account, or accounts alone — never a gateway.

**JetStream availability is decided here.** A stream's replicas never leave their cluster
(source: [[s-docs-jetstream-in-a-cluster]]). A super-cluster is **one meta group** spanning the WAN,
so stream and consumer creation needs a global quorum and each region's availability depends on the
others. Leaf regions with their own domains are **one meta group each**, so a region survives on its
own. That single difference is why the maintainer answer for uneven multi-region deployments is
leafnodes, not gateways (source: [[s-gh-7438-multi-region-availability]]).

## The ladder

The docs' own progression, and it is a good default (source: [[s-docs-putting-it-together]]):

- **One server** until a single point of failure is unacceptable, or one server cannot carry the
  load. Then a cluster.
- **One cluster** until you need a second region, or a failure domain a single mesh cannot give you.
  Then a second cluster and a gateway.
- **A super-cluster** reaches every region, but not every site. When a factory, a ship or a laptop
  needs NATS locally with only outbound network access, attach a leaf.

Its pitfall is the one worth repeating in a design review: **"Building the whole stack before a limit
forces it."** The application code is identical at every stage, so growing later costs nothing in the
app; adding a layer early costs you a region to keep healthy.

## Where the ladder is the wrong answer

Three cases where the next rung is not the right move.

**A regional read replica of a stream or KV bucket.** The instinct is a super-cluster. The
maintainer answer is a leafnode:

> "You don't even need a super-cluster, you could simply have your 3 node cluster in the US and have
> each of your 1 nodes in other parts of the world connect to the cluster as Leaf Nodes. Then you can
> enable JS on those leaf nodes and create read replica streams that source from streams located in
> the cluster."
> — @jnmoyne (source: [[s-gh-6328-jetstream-behind-gateways]])

A gateway would not have helped: crossing a JetStream boundary is a [[mirrors-and-sources]] operation
either way, so the connection type is chosen on network and isolation grounds, not on whether data
can cross.

**Regions of unequal size.** In a super-cluster, quorum is decided by the total server count, so a
dominant region can hold the meta group hostage and losing it makes the others partially unavailable.
The recommendation is one cluster (the largest) with the others as leaf nodes, each with its own JS
domain (source: [[s-gh-7438-multi-region-availability]]) — [[multi-region-jetstream]].

**Isolation between tenants.** No connection type gives it. Accounts do —
[[account]], [[cross-account-sharing]].

## What each choice costs you

- **A route mesh across regions** costs a full mesh of WAN connections and unfiltered inter-server
  traffic. The docs are blunt: "Don't grow a cluster across regions."
- **A gateway** costs a shared JetStream meta group and its global quorum, plus the fact that a
  *working* super-cluster is not a *correctly configured* one — gossip forms it around a typo, and
  only the log says so (source: [[s-docs-super-clusters]]). It also gives locality only for
  **queue-group** traffic; a plain cross-region subscriber puts your whole publish rate on the WAN
  and slows the local leg too — [[supercluster-slows-when-a-remote-subscriber-joins]].
- **A leafnode** costs a hub-and-spoke shape that nobody has published a way out of — see
  *Choosing the hub is a one-way decision* below. It also requires naming a domain on every JetStream
  operation that leaves the local one. And it constrains how a leaf may **address** a super-cluster:
  a remote's `urls` list is a **reconnect pool for one NATS system**, not one entry per cluster.
  Listing two clusters of a super-cluster builds two bridges into the same system and the two bridges
  feed each other, duplicating messages; the server catches "normal mis-configuration loops" at
  connection time and does not catch this one. Reach a super-cluster through **DNS** — a CNAME per
  cluster and a geo-aware record over the whole thing — rather than through a longer list
  (source: [[s-gh-4823-leafnode-supercluster-duplicates]]; the symptom is
  [[duplicate-messages-across-a-leafnode]]).
- **Composing them on one server** costs a `system_account` you must remember to set, or the server
  will not start — and `nats-server -t` will tell you the config is valid first
  (source: [[s-nats-server-topology]]).

## Choosing the hub is a one-way decision, as far as anyone has said in public

**This wiki cannot answer it, and that is the answer.** Two questions were asked in the same thread
on 2025-10-20 and **neither was ever replied to**, by a maintainer or anyone else
(source: [[s-gh-7438-multi-region-availability]]):

> "Is there a way to 'convert' a leaf cluster into a non-leaf cluster in the future, if necessary?
> What happens if the now-largest cluster is overtaken in size by a leaf cluster in the future?"

> "Similarly, if we already have a regular cluster, is there a way to convert it into a leaf cluster
> without losing data?"

Searched again on **2026-08-31** across the docs tree, the ADRs, GitHub discussions and issues, and
the public blogs: **no public source states a procedure, states that one exists, or states that one
does not.** The neighbouring facts that *are* published only sharpen the question rather than
answering it — a JetStream domain is a per-server config value and every server in a cluster must
carry the same one ([[jetstream-domain]]), stream data does not move between domains except as a
mirror or source with its own lag ([[mirrors-and-sources]]), and a live cluster's `server_name`
cannot safely be changed in place. Assembling those into a migration would be this wiki inventing a
runbook, which it will not do.

**What follows for a design decision today:** treat the hub as fixed for the life of the deployment.
If a region might have to become the hub later, that is an argument for a super-cluster — where no
region is subordinate — and for accepting its costs instead. Recorded as the open state of
question-bank row **Q103**.

## Rules of thumb

1. **Egress-only on one side → leafnode.** There is no other option; a gateway needs both sides to
   accept connections.
2. **Same failure domain, low latency, want replicas → route.** Replicas live in a cluster and
   nowhere else.
3. **Symmetric regions, one operator, JetStream can tolerate a global quorum → gateway.**
4. **Asymmetric regions, or a region that must survive alone → leafnode with its own domain.**
5. **Need a boundary → account.** Then decide the connection type separately.
6. **Odd server counts, always** — an even count tolerates the same single failure at the cost of an
   extra server (source: [[s-docs-jetstream-in-a-cluster]]).

## Related

[[leafnode]] · [[gateway]] · [[jetstream-domain]] · [[multi-region-jetstream]] ·
[[build-a-3-node-cluster]] · [[replicas]] · [[raft-in-nats]] · [[account]] ·
[[mirrors-and-sources]] · [[cross-domain-sourcing]] · [[install-nats-server]]

## Sources

[[s-docs-putting-it-together]] · [[s-docs-super-clusters]] · [[s-docs-leaf-nodes]] ·
[[s-docs-jetstream-in-a-cluster]] · [[s-gh-6328-jetstream-behind-gateways]] ·
[[s-gh-7438-multi-region-availability]] · [[s-nats-server-topology]] ·
[[s-gh-7494-supercluster-degradation]] ·
[[s-gh-4823-leafnode-supercluster-duplicates]]

## To verify

- **The reversibility of a leaf topology is unknown.** The docs claim every layer is reversible
  ("the layer below never changed"); the two public questions asking exactly that are unanswered.
  This page records the claim and the silence rather than choosing between them.
- The statement that a super-cluster's stream and consumer creation "relies on a global quorum" comes
  from the asker in [[s-gh-7438-multi-region-availability]], not contradicted by the maintainer reply
  and consistent with the meta group being cluster-spanning. It has **not** been read from the server
  source.
