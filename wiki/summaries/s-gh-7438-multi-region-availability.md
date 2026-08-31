---
title: "gh#7438 — Multi-region without sacrificing availability"
type: summary
area: [topology, jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/discussions/7438
source-path: raw/gh-discussions/gh-7438.md
author: "@ryansun96 (asker), @jnmoyne (maintainer reply)"
article: "GitHub Discussion 7438, nats-io/nats-server, Q&A"
date: 2025-10-17
version: ""
tags: [multi-region, gateway, leafnode, jetstream-domain, quorum, unanswered]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#7438 — three regions, unequal sizes, and the cost of a global quorum

Opened 2025-10-17. A maintainer replies with the architecture; the asker's **two follow-up questions
about the downsides are never answered**. That silence is itself the finding — it is the gap
[[choosing-a-topology]] exists to fill.

## Key claims

### The problem, as the asker frames it

> "From the doc if three clusters are connected via gateways, the availability of any region depends
> on that of (or connectivity to) other regions, because stream and consumer creation relies on a
> global quorum (which also introduces significant latency). This dependency is more pronounced when
> one region has significantly more server than the sum of the other two, such that the loss of one
> region will render two other regions partially unavailable."

What he wants: "an architecture that keeps each region independent from each other, but still offers
the convenience of 'one virtual cluster'" — ease of mirroring between regions, ease of consuming and
publishing across them.

### The maintainer's answer

> "In the case of imbalance in the cluster sizes or when connectivity between regions can be bad, you
> are better off using one cluster (using your largest one) and the others connecting as Leaf Nodes,
> each one with their own JS domain name.
>
> Sourcing and consuming from streams in other regions remains the same but (for JS operations) you
> have to specify the JS API domain name (by default the domain name of the specific server the
> client is connected to is used). Connecting through a leaf node is functionally transparent from
> the client application's point of view (according to the permissions the LN is using to connect to
> the hub): Core NATS messages (and requests) can be published to or subscribed to from anywhere, so
> as long as you can publish to the subject that a stream in another region is capturing on, then the
> messages will be stored in the stream."
> — @jnmoyne, 2025-10-20

Two facts in that paragraph are load-bearing and stated nowhere in the docs:

1. **Each leaf region gets its own `jetstream { domain }`** — that is what makes the regions
   independent, because a domain is a separate JetStream system with its own meta group.
2. **The default domain for a JS operation is the domain of the server the client is connected to.**
   Reaching another region means naming its domain (`nats --js-domain <name> …`).

**Core NATS is unaffected by the domain split.** Publishing to a subject a remote region's stream
captures is enough; the message is stored there. That is the practical shape of "one virtual
cluster".

### What was asked and never answered

> "Does making an entire region a leaf node cluster impose any child-parent / edge-central related
> limitations? … is there a way to 'convert' a leaf cluster into a non-leaf cluster in the future, if
> necessary? What happens if the now-largest cluster is overtaken in size by a leaf cluster in the
> future?
>
> In other words, does the leaf node architecture have any down side compared to, say, a super
> cluster? **This is the information I find missing from the docs / videos, i.e. the cons of each
> architecture.**"

> "Similarly, if we already have a regular cluster, is there a way to convert it into a leaf cluster
> without losing data?"

Both unanswered as of 2026-08-31.

## Practical takeaways

- **Gateways make availability regional-coupled for JetStream; leafnodes with separate domains do
  not.** A super-cluster is one meta group over the WAN; a hub-and-leaf arrangement is one meta group
  per domain. That is the whole trade.
- The asymmetry the asker worries about is real: in a super-cluster, quorum is decided by the total
  server count, so a dominant region can hold the meta group hostage.
- The **hub is a hub in topology, not in authority** — but nobody public has confirmed what happens
  when the leaf outgrows it. Treat the choice of which region is the hub as hard to reverse until
  someone documents otherwise.
- The docs' claim that each layer "is reversible: the layer below never changed" (source:
  [[s-docs-putting-it-together]]) does not survive contact with this question, which is exactly what
  the asker is asking and nobody answers.

## Relevance to the wiki

The direct source for [[multi-region-jetstream]] and the trade-off table on [[choosing-a-topology]].
The unanswered half is recorded on both pages rather than filled in.

## Questions it answers

- **Q45** — multi-region availability without cross-region latency: one hub cluster, leaf regions,
  one JetStream domain each.

## Pages touched

[[multi-region-jetstream]] · [[choosing-a-topology]] · [[jetstream-domain]] · [[leafnode]] ·
[[gateway]] · [[mirrors-and-sources]] · [[raft-in-nats]]
