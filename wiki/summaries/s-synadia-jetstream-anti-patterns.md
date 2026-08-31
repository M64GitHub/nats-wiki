---
title: "Synadia — JetStream Anti-Patterns: pitfalls to avoid when scaling"
type: summary
area: [jetstream, deploy, monitoring]
source-url: https://www.synadia.com/blog/jetstream-design-patterns-for-scale
source-path: raw/synadia-blog/jetstream-design-patterns-for-scale.txt
author: Andrew Connolly (Synadia) — series *Design Patterns for Scaling NATS*
article: "JetStream Anti-Patterns: Avoid these pitfalls to scale more efficiently"
date: 2026-06-06
version: "2.10, 2.11 referenced"
tags: [consumer-info, consumer-count, subject-filters, republish, direct-get, scaling]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# Synadia — JetStream Anti-Patterns

The first post of Synadia's scaling series, focused on **JetStream consumers**. It is the only
public source found so far that puts **numbers** on consumer-count and subject-filter limits.

## Key claims — the three anti-patterns

### 1. Overusing `consumer info`

`consumer info` "was intended to provide insights for monitoring or debugging", and at scale it is
**expensive**:

> "Consumer info has to go to the **meta-leader** before it returns a 'does not exist' error and, if
> the consumer does exist, **requires calculating state**."

The named anti-pattern is the exists-check loop:

```
consumer info call
  consumer doesn't exist  > consumer create
  consumer does exist     > consumer update
```

which "seems innocuous in a prototype or proof of concept, becomes very expensive across ten of
thousands of clients".

**The fix is to skip the check and just call consumer create.** The post spells out why that is
safe:

> "if the consumer already exists with the same name on the specified stream, JetStream verifies the
> request against the existing consumer's config. If they match, **the call is idempotent** and
> JetStream responds with a success message without making any changes. If the config differs,
> JetStream will **update** the existing consumer (unless the operation tries to update a
> non-editable configuration, e.g. start sequence, in which case an error is returned)."

**Second misuse: checking pending messages.** Get it from the **last fetched message's metadata**
instead — `MsgMetadata` carries `Sequence`, `NumDelivered`, **`NumPending`** ("the number of
messages that match the consumer's filter, but have not been delivered yet"), `Timestamp`,
`Stream`, `Consumer` and `Domain`. No API call needed.

### 2. Too many consumers

> "How many consumers is too many? There's no hard cap, but **beyond 100,000 consumers, the
> potential for issues increases significantly.** The background **Raft traffic** and the load on
> the **meta-leader** increase as they work to maintain state consistency across nodes and manage
> consumer subscriptions."

Consumers cost "managing state, replicating it across the cluster", and "beyond a certain threshold
instability or failures are likely".

**Two alternatives that remove consumers entirely:**

- **Republish** — a `republish` policy on the stream re-emits messages onto core NATS subjects that
  plain subscribers listen to:

  ```json
  { "republish": { "source": "orders", "destination": "filtered.orders.>" } }
  ```

  "Republish is ideal for use cases where subscribers can handle messages in real time and **do not
  require strict delivery guarantees**." The post's diagnosis is worth quoting:

  > "Often, having too many consumers is downstream of **overstated persistence and delivery
  > guarantee requirements**."

- **Direct Get** — "even faster and more lightweight than consumers, making it ideal for getting
  specific messages from streams", via `$JS.API.DIRECT.GET.<stream>.<last_by_subj>`. Called out as
  especially useful for mobile and IoT clients that want only the latest value on a subject. **Batch
  Get, in 2.11, returns multiple messages from multiple subject filters.**

### 3. Too many subject filters on one consumer

Multiple subjects in a single server-side consumer filter arrived in **2.10**, and they may be
completely disjoint.

> "Again, there is no hard limit here. But adding **more than a few hundred disjoint subject
> filters** will likely lead to slowness and instability."

The mechanism:

> "As more disjoint subjects are specified, more subject indexing and matching operations increase
> server-side workload. **Each additional disjoint subject filter potentially requires the loading
> and scanning of more message blocks** to identify matches."

The fix: split into separate consumers each with fewer filters, or "re-evaluate your subject name
hierarchy so you can better leverage wildcard filters".

## The post's own recap, verbatim in substance

- Avoid overusing `consumer info`; use `consumer create` or the last fetched message's metadata.
- **Reduce the total number of consumers below ~100k.**
- Use republish and the Direct Get API to avoid unnecessary consumers.
- **Keep disjoint subject filters below ~300 on each consumer.**

Note the recap's "~300" is more specific than the body's "more than a few hundred"; both are the
same claim and neither is a server-enforced limit.

## Caveats on citing it

- **These are guidance thresholds, not server limits.** The post says so twice: "there's no hard
  cap" and "there is no hard limit here".
- The post is dated **2026-06-06** and names **2.10** and **2.11** for specific features, but does
  **not state which server version the thresholds were measured against**, or how they were
  measured.

## Relevance to the wiki

Fills two of the open items on [[jetstream-sizing]]'s *What is still unknown* — the consumer-count
question (Q6) and, partially, why throughput degrades as consumers multiply (Q7). It is also the
source for [[jetstream-slows-as-consumers-grow]] and a correction to a habit [[consumer]] currently
describes neutrally: `consumer info` is a debugging tool, not a control-loop primitive.

## Questions it answers

Q6 (how many consumers before it hurts — ~100k), Q7 in part (why throughput degrades with many
consumers — background Raft traffic and meta-leader load), Q9 in part (high-cardinality subject
filters on **one consumer**, which is not the same as a high-cardinality subject space).

## Pages touched

[[jetstream-slows-as-consumers-grow]] · [[jetstream-sizing]] · [[consumer]] · [[direct-get]] ·
[[stream]]
