---
title: Multi-region JetStream
type: operation
kind: pattern
area: [topology, jetstream, deploy]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [multi-region, leafnode, jetstream-domain, gateway, quorum, sourcing, mirror, geo-affinity]
aliases: [multi region, multi-region availability, global deployment, regional read replica, geo distribution]
sources: [s-gh-7438-multi-region-availability, s-gh-6328-jetstream-behind-gateways, s-docs-super-clusters, s-docs-jetstream-in-a-cluster, s-docs-leaf-nodes, s-nats-server-leafnode-js-domains, s-docs-mirrors-and-sources, s-docs-mirrors-as-dr, s-nats-server-topology]
created: 2026-08-31
updated: 2026-08-31
---

# Multi-region JetStream

**The problem.** Several regions must behave as one system — publish anywhere, consume anywhere,
copy streams between them — without each region's availability depending on the others, and without
paying cross-region latency for local work.

The instinct is a super-cluster. For **core NATS** that is right. For **JetStream** it is usually
wrong, and the reason is one sentence: a super-cluster is a *single* JetStream meta group spanning
the WAN, so stream and consumer creation needs a global quorum and one region's loss degrades the
rest. Asked exactly this, a maintainer answers:

> "In the case of imbalance in the cluster sizes or when connectivity between regions can be bad, you
> are better off using one cluster (using your largest one) and the others connecting as Leaf Nodes,
> each one with their own JS domain name."
> — @jnmoyne (source: [[s-gh-7438-multi-region-availability]])

## The design

**One hub cluster. Every other region a leafnode with its own [[jetstream-domain]].**

```
                    ┌──────────────────────────────┐
   region: US       │  hub cluster  (domain: hub)  │   3 or 5 servers, R3 streams
   (the largest)    │  n1  n2  n3                  │   one meta group
                    └───────▲──────────▲───────────┘
                            │          │              leafnode links, outbound from the leaf
              ┌─────────────┘          └─────────────┐
   ┌──────────┴──────────┐              ┌────────────┴────────┐
   │ EU   domain: eu     │              │ APAC domain: apac   │  1 server or its own cluster
   │ own meta group      │              │ own meta group      │  own streams, own quorum
   └─────────────────────┘              └─────────────────────┘
```

Three properties follow, and they are the whole argument:

1. **Each region has its own meta group.** A region keeps creating and serving streams when the hub
   or the WAN is gone. Nothing about its availability is decided elsewhere.
2. **Core NATS still behaves as one system.** "Core NATS messages (and requests) can be published to
   or subscribed to from anywhere, so as long as you can publish to the subject that a stream in
   another region is capturing on, then the messages will be stored in the stream"
   (source: [[s-gh-7438-multi-region-availability]]). Applications do not change.
3. **JetStream operations must name the domain.** "By default the domain name of the specific server
   the client is connected to is used" — anything else is `--js-domain <name>`, or the
   `$JS.<domain>.API.>` prefix in a client.

Data moves between regions with [[mirrors-and-sources]], not with replicas: a stream's replicas never
leave their cluster (source: [[s-docs-jetstream-in-a-cluster]]).

## The configuration that implements it

### The hub — accept leaves, name the domain

```
server_name: n1-hub
listen: 0.0.0.0:4222

system_account: SYS

jetstream {
  domain: "hub"
  store_dir: "/var/lib/nats/js"
}

cluster {
  name: us
  listen: 0.0.0.0:6222
  routes: [ nats://n2-hub:6222, nats://n3-hub:6222 ]
}

leafnodes {
  listen: 0.0.0.0:7422
}
```

`system_account` is not optional decoration here: any server that both accepts leafnodes **and**
carries a gateway refuses to start without it (source: [[s-nats-server-topology]]). Setting it from
the start also means `nats server report leafnodes` works when you need it.

### A leaf region — its own domain, dialing out

```
server_name: eu-1
listen: 0.0.0.0:4222

jetstream {
  domain: "eu"
  store_dir: "/var/lib/nats/js"
}

leafnodes {
  remotes: [
    {
      urls: [ "nats-leaf://n1-hub:7422", "nats-leaf://n2-hub:7422", "nats-leaf://n3-hub:7422" ]
      account: "APP"
      credentials: "/etc/nats/eu.creds"
    }
  ]
}
```

Three URLs, one system. **Do not list servers from two different clusters** — that is two bridges
into one system and the traffic loops ([[duplicate-messages-across-a-leafnode]]).

The domains must **differ** between hub and leaf. Identical domains without a shared system account
are actively denied, and identical domains *with* one extend the hub's JetStream onto the leaf
instead of giving the leaf its own (source: [[s-nats-server-leafnode-js-domains]]) —
[[streams-not-visible-across-a-leafnode]].

### Copying a stream between regions

A regional read replica is a stream on the leaf that **sources** from the hub's:

```
nats --js-domain eu stream add ORDERS-EU --source ORDERS
```

Cross-**domain** (and cross-account) sourcing needs an `external` block and matching exports and
imports — the part the docs do not cover. See [[cross-domain-sourcing]].

## Trade-offs and costs

| | super-cluster (gateways) | hub + leaf regions (this pattern) |
|---|---|---|
| JetStream meta group | **one**, spanning the WAN | **one per domain** |
| a region survives a WAN partition | partially — creation needs global quorum | yes, fully |
| unequal region sizes | the largest can dominate quorum | irrelevant |
| addressing another region's JetStream | same API, one namespace | must name the domain |
| core NATS reach | full | full |
| queue-group locality | geo-affinity, automatic | place workers per region yourself |
| symmetry | peer regions | hub-and-spoke, and **reversibility undocumented** |

**Core traffic through the hub is a real hop.** A leaf region reaching another leaf region goes
through the hub. The asker in [[s-gh-6328-jetstream-behind-gateways]] raised exactly this — "I wanted
to avoid a situation where a node in Asia needs to first communicate with the US before the EU can get
the message/update" — and nobody in either thread addressed it. If EU↔APAC core latency matters more
than regional JetStream independence, that is the case for a super-cluster.

**Geo-affinity is a gateway property, and it only covers queue groups.** It does not exist between a
hub and its leaves; put a queue-group member in each region that produces that work either way. And
in a super-cluster, a single **plain** cross-region subscriber puts every message on the WAN link and
slows the local leg too — [[supercluster-slows-when-a-remote-subscriber-joins]].

## When *not* to use it

- **Symmetric regions with good connectivity and one operator.** A super-cluster is simpler, has one
  JetStream namespace, and gives queue-group locality for free.
- **When no region may be subordinate, even in name.** The shape is hub-and-spoke, and no public
  source describes a way to reverse it — see *Choosing the hub is a one-way decision* on
  [[choosing-a-topology]], which owns that finding. Choosing the hub is a decision to make once.
- **When you need one stream replicated across regions.** Nothing does that. Replicas stay in a
  cluster; cross-region copies are mirrors and sources, which are asynchronous and whose `Lag` is
  your RPO (source: [[s-docs-mirrors-as-dr]]).

## Verify

```
nats server report leafnodes                 # the link is up, and on which account
nats --js-domain eu stream ls                # the leaf's own JetStream answers
nats --js-domain hub stream ls               # the hub's, from the same client
nats --js-domain eu stream info ORDERS-EU    # Source Information: Lag and Last Seen
```

If `nats --js-domain eu stream ls` returns the hub's streams, the two ends are extending rather than
separate — check the log for `JetStream using domains: local "…", remote "…"`, whose absence means
the connection **is** extending.

## Related

[[choosing-a-topology]] · [[leafnode]] · [[gateway]] · [[jetstream-domain]] ·
[[cross-domain-sourcing]] · [[mirrors-and-sources]] · [[disaster-recovery]] · [[replicas]] ·
[[raft-in-nats]] · [[jetstream-sizing]] · [[supercluster-slows-when-a-remote-subscriber-joins]]

## Sources

[[s-gh-7438-multi-region-availability]] · [[s-gh-6328-jetstream-behind-gateways]] ·
[[s-docs-super-clusters]] · [[s-docs-jetstream-in-a-cluster]] · [[s-docs-leaf-nodes]] ·
[[s-nats-server-leafnode-js-domains]] · [[s-nats-server-topology]] · [[s-docs-mirrors-and-sources]] ·
[[s-docs-mirrors-as-dr]]

## To verify

- The configs above are assembled from the documented key set and the server source; **no public
  source publishes a complete working hub-and-leaf multi-region configuration**, which is the same
  gap [[cross-domain-sourcing]] runs into. Each key used is individually sourced; the combination is
  not.
- Hub-mediated latency between two leaf regions is a consequence of the shape, not a measured number.
  No source in `raw/` benchmarks it.
