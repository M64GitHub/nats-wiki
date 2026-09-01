---
title: "JetStream slows down as the consumer count grows"
type: gotcha
area: [jetstream, deploy, monitoring]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [consumer-count, consumer-info, meta-leader, raft-traffic, subject-filters, republish]
aliases: ["too many consumers", "100k consumers", "consumer info is slow", "throughput collapses with many consumers"]
sources: [s-synadia-jetstream-anti-patterns, s-adr-17-ordered-consumer, s-relnotes-2.14.0, s-docs-raft-and-leaders, s-gh-5243-kv-watchers-at-scale, s-gh-6746-watch-many-keys, s-gh-5044-restrict-durable-consumers, s-docs-get-direct, s-nats-server-jetstream-log-warnings]
created: 2026-08-31
updated: 2026-09-01
---

# JetStream slows down as the consumer count grows

A cluster that was fine at a few thousand consumers gets slow, then unstable, as the fleet grows —
with the meta leader carrying the load and no single stream obviously at fault.

## Symptom

- Latency rises on JetStream API calls generally, not on one stream.
- The **meta leader** is the busy node; its peers look comparatively idle
  (see [[raft-in-nats]] for how to tell which node that is).
- Background Raft traffic grows with consumer count rather than with message rate.
- Publisher throughput degrades as consumers are added, with no change to the publishers.

## Quick triage

```
nats server report jetstream    # which server is meta leader, and its load
nats consumer ls <stream>       # how many consumers, and whether they are short-lived
nats stream info <stream>       # replicas, and where the leader sits
```

Then ask two questions the numbers below turn into answers: **how many consumers in total**, and
**how many disjoint subject filters on any one of them**.

## Causes, ranked

### 1. More than ~100,000 consumers

Synadia's guidance (source: [[s-synadia-jetstream-anti-patterns]]):

> "There's no hard cap, but **beyond 100,000 consumers, the potential for issues increases
> significantly.** The background Raft traffic and the load on the meta-leader increase as they work
> to maintain state consistency across nodes and manage consumer subscriptions."

Every consumer costs state management and replication of that state across the cluster. The cost is
paid continuously, not per message.

*Confirm:* count consumers across all streams and compare against ~100k.

*Fix:* remove consumers rather than add servers — see *Designing consumers away*, below.

### 2. A `consumer info` call in a control loop

`consumer info` "was intended to provide insights for monitoring or debugging", and it is
**expensive by construction**:

> "Consumer info has to go to the **meta-leader** before it returns a 'does not exist' error and, if
> the consumer does exist, **requires calculating state**."

The named anti-pattern is the exists-check:

```
consumer info call
  consumer doesn't exist  > consumer create
  consumer does exist     > consumer update
```

— "innocuous in a prototype or proof of concept, becomes very expensive across ten of thousands of
clients". Note it routes to the **meta leader**, which is why this cause and cause 1 produce the
same shape of symptom.

*Confirm:* `nats --trace` on a representative client shows the call pattern
(see [[js-api]]).

*Fix:* **just call consumer create.** It is safe because it is idempotent:

> "if the consumer already exists with the same name on the specified stream, JetStream verifies the
> request against the existing consumer's config. If they match, the call is idempotent and
> JetStream responds with a success message without making any changes. If the config differs,
> JetStream will update the existing consumer (unless the operation tries to update a non-editable
> configuration, e.g. start sequence, in which case an error is returned)."

**And to check pending messages, read the last fetched message's metadata** — `NumPending` is
already on every message the consumer delivers, alongside `Sequence`, `NumDelivered`, `Timestamp`,
`Stream`, `Consumer` and `Domain`. No API call at all.

### 3. Too many disjoint subject filters on one consumer

Multiple subjects in one server-side consumer filter arrived in **2.10**, and they need not share a
hierarchy.

> "there is no hard limit here. But adding **more than a few hundred disjoint subject filters** will
> likely lead to slowness and instability."

The recap gives the working number as **~300 per consumer**. The mechanism:

> "Each additional disjoint subject filter potentially requires the **loading and scanning of more
> message blocks** to identify matches."

*Confirm:* read the filter list on the slowest consumers.

*Fix:* split into separate consumers with fewer filters each, **or re-work the subject hierarchy so
wildcards do the job** — the second is the better answer and the harder one.

**Watch out for the client feature that turns this into cause 1.** "Watch multiple keys on one
watcher" is a *client-side* name (`KvWatchOptions` in nats.js) for this same server-side capability,
and it needs **2.10 or later**. A client on an older server, or one that has not implemented it,
falls back to **one consumer per key** — so the same application code is a filter problem on 2.10+
and a consumer-count problem below it (source: [[s-gh-6746-watch-many-keys]]). One watcher over
thousands of keys is not the answer either; a wildcard that covers them is. The asker never posted a
measurement, so treat it as a documented client capability rather than a confirmed number.

### 4. Churn from short-lived consumers

An [[ordered-consumer]] deletes and recreates itself on every detected gap or missed heartbeat, and
KV watches, KV history and KV key listing are all ordered consumers
(source: [[s-adr-17-ordered-consumer]], [[key-value]]). A fleet of KV watchers therefore generates
consumer create/delete traffic against the meta leader **by construction**, not by misuse.

*Confirm:* consumer names appearing and vanishing in `nats consumer ls` between runs — and, in the
server log, the line that tells churn apart from count:

```
Consumer assignment for '<account> > <stream> > <name>' not cleaned up, retrying
```

That is the meta layer failing to land the *deletion* of an assignment. Its companion tell is a
stream report showing **`Consumers: 0`** while the log floods with per-consumer lines: nothing is
running, everything is being created and destroyed. On the client side of the same event the server
logs how long it spent inside one connection's read loop —
`Readloop processing time: 2m11s` — which is the slow-consumer starvation shape seen from the other
end (source: [[s-gh-5243-kv-watchers-at-scale]]; the format string is verified at v2.14.6 in
[[s-nats-server-jetstream-log-warnings]]). The reported case was **1,000 KV watchers on one key**,
one per client. See [[kv-watchers-stall-the-cluster]] and [[slow-consumer-detected]].

*Fix:* prefer long-lived consumers where the design allows; Synadia names consumer lifecycle as one
of the three things memory follows ([[jetstream-sizing]]).

## Designing consumers away

Two alternatives that remove the consumer entirely
(source: [[s-synadia-jetstream-anti-patterns]]):

**Republish** — a `republish` policy on the stream re-emits messages onto core NATS subjects that
plain subscribers listen to, with no consumer state anywhere:

```json
{ "republish": { "source": "orders", "destination": "filtered.orders.>" } }
```

"Ideal for use cases where subscribers can handle messages in real time and **do not require strict
delivery guarantees**." The post's diagnosis of *why* people end up here is worth keeping:

> "Often, having too many consumers is downstream of **overstated persistence and delivery guarantee
> requirements**."

**Direct Get** — `$JS.API.DIRECT.GET.<stream>.<last_by_subj>` is "even faster and more lightweight
than consumers", and is the right tool for a client that wants the latest value on a subject rather
than a stream position. Called out for mobile and IoT clients. **Batch Get, in 2.11, returns
multiple messages from multiple subject filters.** See [[direct-get]].

Two things to know before designing on it. **`allow_direct` is off by default and its absence is
silent**: with the setting unset no server answers the Direct Get subject and "the request times out
with nothing returned" — no error, no code, nothing to grep for, which is the worst shape for a first
deployment. And **`--last-per-subject` / `multi_last` is a point-in-time snapshot across a whole
subject space**, which is precisely "the cheap alternative to standing up a consumer just to read
current state" (source: [[s-docs-get-direct]]).

## Prevention

- **Budget consumers as a cluster-wide resource with a ~100k ceiling**, and count them the way you
  count disk.
- **Treat `consumer info` as a debugging tool.** Nothing in a hot path should call it.
- **Keep disjoint filters under ~300 per consumer.**
- Before adding consumers, ask whether the delivery guarantee is actually required — republish and
  Direct Get cost nothing per client.
- **Put a hard backstop under the guidance: the account's `max_consumers`.** Subject permissions
  cannot stop a client creating consumers — a durable and an ephemeral both use
  `$JS.API.CONSUMER.CREATE.<stream>.<name>` and the difference is in the request body — so per-account
  JetStream limits are the only enforceable control, and they bound the resource regardless of who
  creates what (source: [[s-gh-5044-restrict-durable-consumers]]; see [[account]] and
  [[subject-permissions]]). The same thread reaches this page's conclusion from the security side:
  **not exposing the JetStream API at all** — Direct Get plus a republish subject give untrusted
  clients history with no consumer to create.

## A note on the numbers

**~100,000 consumers and ~300 subject filters are guidance, not server limits.** The source says so
twice — "there's no hard cap" and "there is no hard limit here" — and it **does not state which
server version they were measured against, or how**. Treat them as the order of magnitude at which
to start designing differently, not as thresholds to run up to.

There is one adjacent server change worth knowing: since **2.14**, account info, stream info, stream
list, consumer info and consumer list requests are **queued below create-update-delete operations**
(source: [[s-relnotes-2.14.0]]). That protects stream operations from an info-heavy client — it does
not make the info call cheap.

## Explained by

[[raft-in-nats]] (the meta group, and why meta-leader load is a cluster-wide symptom) ·
[[consumer]] · [[ordered-consumer]]

## Related

[[jetstream-sizing]] · [[consumer]] · [[direct-get]] · [[key-value]] · [[js-api]] ·
[[ordered-consumer]] · [[stream]] · [[kv-watchers-stall-the-cluster]] · [[nats-timeout]] ·
[[stream-has-high-message-lag]]

## Sources

[[s-synadia-jetstream-anti-patterns]] · [[s-adr-17-ordered-consumer]] · [[s-relnotes-2.14.0]] ·
[[s-docs-raft-and-leaders]] · [[s-gh-5243-kv-watchers-at-scale]] · [[s-gh-6746-watch-many-keys]] ·
[[s-gh-5044-restrict-durable-consumers]] · [[s-docs-get-direct]] ·
[[s-nats-server-jetstream-log-warnings]]
