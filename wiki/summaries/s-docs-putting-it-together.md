---
title: "docs.nats.io — Putting it together (composed topology)"
type: summary
area: [topology, deploy, monitoring]
source-url: https://docs.nats.io/learn/topologies/putting-it-together.md
source-path: raw/nats-docs/learn/topologies/putting-it-together.md
author: NATS documentation (Synadia Communications, Inc.)
article: Putting it together
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [composition, layers, server-report, leafnode-report, spoke, address-space-isolation]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Putting it together

The page that stacks the shapes into one server config, gives the three `nats server report`
commands that survey them, and — the reason it matters here — **prints a composed config that does
not start**.

## Key claims

### Composition

"Each shape is a layer. You add the next layer when the current one runs out of room, and the layer
below keeps working exactly as it did."

"The wiring stays local to each layer. Routes wire servers inside one cluster. Gateways wire clusters
inside a super-cluster. Leaf remotes wire a leaf to a hub. No single config block has to know about
the whole picture."

### One server, three roles

The page prints `n1-east.conf` with `cluster {}`, `gateway {}`, `leafnodes { listen }` and
`jetstream {}` in one file, and calls it "all 'composition' means".

**That config does not start.** `nats-server` refuses with:

```
nats-server: leaf nodes and gateways (both being defined) require a system account to also be configured
```

and `nats-server -c n1-east.conf -t` reports the file **valid** first. Both reproduced on
nats-server v2.14.6; the check is `validateLeafNodeOptions` at `leafnode.go:346–349`. The
page then says, two sections later, that the chapter "doesn't set up" a system account — so the
omission is deliberate and the config is unrunnable as printed. Recorded as `inbox/docs-issues.md`
#24. See [[s-nats-server-topology]].

### Composition adds reach, not boundaries

> "Stacking these shapes gives you one address space by default. Routes carry an account's full
> interest across a cluster; a gateway forwards any subject the far side wants. Neither partitions
> anything — they widen where a message can go."

> "The one layer that *can* draw a boundary is the leaf, and only when you bind it to its own
> account."

This is the sharpest statement in the chapter and the one to carry into a design review.

### Picking the next layer

- "**One server** is enough until a single point of failure is unacceptable, or one server can't carry
  the load. Then add a cluster."
- "**One cluster** is enough until you need a second region, or a failure domain that a single mesh
  can't give you. Then join a second cluster with a gateway."
- "**A super-cluster** reaches every region, but not every site. When a factory, a ship, or a laptop
  needs NATS locally with only outbound network access, attach a leaf."

"Each step is reversible: the layer below never changed, so removing the layer above leaves a working
deployment behind." *(An unverified claim as stated — reversing a **JetStream** layer is not free;
see [[s-gh-7438-multi-region-availability]], where exactly this question is asked and left unanswered.)*

### Surveying the layers

Requires the **system account**. Then:

```
nats server list
nats server report routes      # the mesh inside each cluster
nats server report gateways    # the gateways between clusters
nats server report leafnodes   # the leaves dialed into the hub
```

`nats server list` has a `Routes` and a `GWs` column. The Leafnode Report has columns
`Server │ Name │ Account │ Address │ RTT │ Spoke`.

- The `Account` column "reads `$G`: nothing set up a dedicated account for the leaf, so it lands in
  the default global account, and there's no boundary here".
- **`Spoke`** "reads `false` because this report comes from `n1-east`, the hub end that accepted the
  connection. The column is `true` only on the leaf's own report."

### The pitfall

"**Building the whole stack before a limit forces it.** … A super-cluster you stood up 'to be safe'
is two regions to keep healthy before you have a second region's traffic."

## Practical takeaways

- `nats server report leafnodes` is the command that answers "is the leaf actually attached, and to
  which account" — and the `Account` column is the isolation audit, not just a label.
- The `Spoke` column tells you which end you are looking from. Reading it as a property of the link
  rather than of the vantage point is an easy mistake.
- A composed server needs `system_account` set. The docs' own composed example is the counter-example.
- "Composition adds reach, not boundaries" is the line to quote in a review when someone proposes a
  gateway as an isolation mechanism.

## Relevance to the wiki

The survey commands belong on [[gateway]], [[leafnode]] and [[monitoring-endpoints]]; the "picking
the next layer" ladder is the spine of [[choosing-a-topology]]; and the broken composed config is
`inbox/docs-issues.md` #24 plus a pitfall on [[build-a-3-node-cluster]] and [[reload-server-config]].

## Questions it answers

- **Q41** — the ladder is the closest thing the docs have to a direct answer.

## Pages touched

[[choosing-a-topology]] · [[leafnode]] · [[gateway]] · [[monitoring-endpoints]] ·
[[build-a-3-node-cluster]] · [[reload-server-config]] · [[nats-cli]] · [[account]]
