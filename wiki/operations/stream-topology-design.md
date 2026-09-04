---
title: Stream topology design
type: operation
kind: pattern
area: [jetstream, security, topology]
since: [2.10]   # `filter_subjects`, stream subject transforms and `mirror.subject_transforms` are 2.10/2.11; the shape is older
verified-against: nats-server 2.14.6
verified-on: 2026-09-04
tags: [stream-count, stream-per-subject, stream-per-tenant, filtered-consumers, fan-out, max_streams, max_consumers, "10026", "10027", "10002", ha_assets, mirror, source, blast-radius, "SI-9"]
aliases: [how many streams, stream per subject, stream per tenant, one stream or many, fan-out design, stream count, consumer fan-out, read replica, replication shape, mirror or source, stream topology]
sources: [s-gh-6100-stream-per-subject-or-one, s-gh-3405-consumer-filtering-performance, s-gh-6571-source-mirror-or-one-stream, s-nats-server-stream-topology-observed, s-gh-5128-ha-assets, s-nats-server-traffic-counters-and-ha-assets, s-gh-3772-jetstream-as-an-event-store, s-synadia-jetstream-anti-patterns, s-synadia-how-many-subjects, s-synadia-subject-hierarchies, s-gh-4499-workqueue-fanout-retention, s-gh-4170-subject-indexing-internals]
created: 2026-09-04
updated: 2026-09-04
---

# Stream topology design

**How many streams, how many consumers on each, and how a second copy is made** — three questions that
are really one, because all three ask what a JetStream *asset* is and what one costs. This page answers
them together; [[subject-design]] is the layer underneath, and the retention choice each stream carries
is [[retention-policies]].

## The problem

You have a subject tree ([[subject-design]]) and a set of readers, and you have to decide the shape:
one stream or many, one consumer per reader or a filter per reader, one copy or two. Every public
answer to these questions gives a *shape* and no number — "it's rarely a good idea to have stream per
subject", "the server doesn't do like a table scan", "it's not because a stream is larger that delivery
takes longer" — so the arguments are unfalsifiable in exactly the place a design review needs them to
be checkable. The numbers on this page come from runs on the 2.14.6 binary (source:
[[s-nats-server-stream-topology-observed]]); **every one of them is one laptop**, so they are ratios
and mechanisms, never capacity figures for a cluster.

## The design

### The default, and the one reason to leave it

**One stream per namespace, many filtered consumers.** The maintainers state it plainly:

> "Many Consumers per single Stream is usually the simple and good pattern as a starting point.
> **It's rarely a good idea to have stream per subject.**" — @Jarema, 2024-11-11 (source:
> [[s-gh-6100-stream-per-subject-or-one]])

What makes it work is that a filter is a **seek, not a scan** — "no the sever doesn't do like a table
scan over all of the messages in the stream and things indexing are used to make operations to find the
first and last message(s) in a stream very efficient indeed" (source:
[[s-gh-3405-consumer-filtering-performance]], @jnmoyne, 2022-09-01, dated to 2.9 and never measured in
public). Re-run on 2.14.6: one matching message in the middle of 1,000,001 is a **0.9 ms**
`CONSUMER.CREATE` with `num_pending` **1** and the message in **2.3 ms**.

**The one reason to split that the maintainers accept is policy, not performance**: "I would stick to
one stream, **unless you need different retention policies for some subjects** for example" (source:
[[s-gh-6100-stream-per-subject-or-one]]). Retention, replication factor, storage backend, placement,
limits and the account are all **per stream**, so a subject needing a different one of those needs its
own stream. A subject that only needs a different *reader* does not — that is a consumer. Putting
`orders.>` and `payments.>` in one stream "couples their retention, replication, and storage budget"
(source: [[s-synadia-subject-hierarchies]]), which is the same rule stated from the other side.

The three defensible reasons to run more streams than that rule produces:

1. **A different policy** — the rule above.
2. **Blast radius.** A stream is the unit of corruption, of a botched `nats stream edit`, of a purge and
   of a restore. Splitting by tenant or by domain bounds what one mistake reaches.
3. **A different placement or account** — a different cluster, region, domain or tenant
   ([[stream-placement]], [[account]]).

Performance is not on the list, and the sources say so explicitly for the case people actually reach
for it (below, *How a second copy is made*).

### How many streams: what the second one costs

| | at `R1` | at `R3` |
|---|---|---|
| create | P50 **0.6 ms**, 1,592/s for the first thousand (675/s for ten thousand) | P50 **107–112 ms** — 100 in 10.18 s, 300 in 23.01 s, 1,000 in **80.85 s** |
| empty, on disk | **8 KiB** — 3 files, `meta.inf` 516 B + `meta.sum` 16 B + `msgs/1.blk` 0 B; linear to 10,000 | the same, per replica |
| empty, in RAM | **~53–58 KiB of RSS**; 1,000 → 75.1 MiB, 10,000 → 534.2 MiB | plus a Raft group per stream |
| `ha_assets` | **0**, even with 10,000 streams | **streams + 1** (the meta group): 11, 101, 301, 1001 |
| the meta layer's store | — | `$SYS/_js_/_meta_` 36 KiB → **628 KiB** from 10 to 1,000 streams |
| restart | 1,001 streams **125 ms**; 10,000 empty **5.405 s**; 10,000 after SIGKILL **5.655 s** with 10,000 `Stream state outdated … will rebuild` warnings | 1,000 streams: `/healthz` 200 in **17.985 s**, and SIGTERM shutdown **did not finish in 10 s** |
| deleting 10,000 | **3.02 s**, store to 0 KiB at once — but **RSS does not fall** (the Go heap returns on its own schedule) | not run |

Three more facts that settle the argument in the shape it is usually had (source:
[[s-nats-server-stream-topology-observed]], runs A, A2, R3):

- **Having many streams does not slow the publish path into one of them.** 20,000 × 128 B into the
  same stream with 1 / 10 / 100 / 1,000 streams present: 194,031 / 204,803 / 209,442 / 192,309 msg/s.
- **The first message into a fresh stream costs ~4.4 ms** — 10,000 messages into 10,000 empty streams
  took 43.97 s; the same 10,000 again took 0.36 s. A design that creates a stream per short-lived
  *thing* pays this every time.
- **Spreading a volume over streams costs disk**: the same 100,000 × 128 B messages were 21,004 KiB
  over 1,000 streams against 16,708 KiB in one stream with a tenant token — **1.26×**, per-stream block
  slack ([[filestore-layout]]).

**So where does "many streams" start to cost you?** It depends entirely on `R1` against `R3`, and the
answer is different by two orders of magnitude:

- **At `R1`** the cost is disk slack, RSS and **recovery time**. Ten thousand streams create in 15 s and
  restart in 5.4 s; nothing else moved. The practical ceiling is how long a restart may take.
- **At `R3`** the unit is the **HA asset** — every replicated stream *and every replicated consumer*
  is one Raft group, plus the meta group ([[meta-layer]], [[metrics]]). Synadia's operating figure is
  **2,000 HA assets per server** — "In our global clusters we limit servers, at the moment, to 2k HA
  Assets. We have customers that have higher and are ok" (source: [[s-gh-5128-ha-assets]]) — and the
  theoretical ceiling a second maintainer names is "on the order of **100s of thousands of assets**
  could likely saturate the network and CPU of the servers within a given cluster" (source:
  [[s-gh-3772-jetstream-as-an-event-store]]). `jetstream { limits { max_ha_assets } }` enforces a
  number: new groups above it are refused and the server is excluded from placement (source:
  [[s-nats-server-traffic-counters-and-ha-assets]]). The run puts a time next to the guidance —
  1,000 `R3` streams took **81 s to create and 18 s to come back**.

The rule of thumb this supports: **at `R3`, count assets and treat a few thousand per server as the
design ceiling; at `R1`, count restart seconds.** And note that "many small streams, one consumer each"
spends the asset budget **twice**, because a replicated consumer is an HA asset too.

### One stream per tenant: where the two public answers meet

The public record points both ways, and it is worth knowing why before choosing.

- gh#6100's chosen answer says **one stream**, because each replicated stream carries its own Raft
  group — asked about one stream per *subject* (source: [[s-gh-6100-stream-per-subject-or-one]]).
- Synadia's [per-tenant FIFO post](https://www.synadia.com/blog/nats-jetstream-per-tenant-fifo-processing)
  (2026-05-20) recommends **one stream per tenant** at "roughly hundreds to low thousands of tenants",
  because it separates ordering from parallelism — one blocked tenant does not stall another. It is
  named, not ingested, in [[s-gh-6100-stream-per-subject-or-one]]; **neither answer was measured**.

They answer different questions. A stream per *subject* buys nothing, because a filter already gives
per-subject reading. A stream per *tenant* buys an **isolation** property a filter cannot: an
independent retention and limit budget, an independent restore, and — the actual reason — an
independent head of line, because a stuck tenant is a stuck consumer and a consumer belongs to one
stream.

The measurement says where the line is. "Hundreds to low thousands" is exactly the range where the
`R3` numbers turn: 100 streams create in 10 s, 300 in 23 s, 1,000 in 81 s and take 18 s to recover.
So **at `R1`, one stream per tenant into the low thousands is cheap; at `R3`, low thousands is the
point where cluster restart time becomes the binding constraint**, and the design should either drop
to `R1` copies for the per-tenant layer or use one stream with a tenant token and per-tenant consumers.

The alternative that gets skipped: if what is wanted from "per tenant" is **isolation**, an
[[account]] gives more of it than a stream does — a separate subject space, separate limits and a
boundary a permission mistake cannot cross. Choosing between an account and a token is
[[subject-design]]'s section and phase G4's page.

## Tenancy: what an account's limits actually cap

If tenants are accounts, these are the four limits they meet, with the exact codes (source:
[[s-nats-server-stream-topology-observed]], run D, on a two-account 2.14.6 server):

| limit | what the tenant sees |
|---|---|
| account `max_streams` | `10027 maximum number of streams reached` on `$JS.API.STREAM.CREATE` |
| account `max_consumers` | `10026 maximum consumers limit reached` |
| per-**stream** `max_consumers` | **the same `10026`** — the error does not say which of the two was hit |
| account `max_file` | `10002 resource limits exceeded for account`, returned as the **`PubAck`** of the publish that would cross the line |

**And the one that changes a design: an account's `max_consumers` is enforced per *stream*, not per
account.** With `TENANT { jetstream: { max_streams: 3, max_consumers: 2 } }`, `S1` took two consumers
and refused a third with `10026`; `S2` then took two more. Four consumers in a `max_consumers: 2`
account. The server compares the limit against `mset.numLimitableConsumers()` for **the one stream**
(`consumer.go:1130–1137`; clustered, `jetstream_cluster.go:9587–9605`), and `nats account info` renders
it correctly — *"Consumers: Maximum 2 per stream"* — while the documentation says only "the maximum
number of consumers allowed", in the same shape as `max_streams`, which **is** per account. Recorded as
docs issue **#124**.

So a tenant's real consumer ceiling is **`max_streams × max_consumers`**, and `max_consumers` alone
caps nothing at the account level. If the intent is a per-account budget, `max_streams` is the lever
that has one.

Three behaviours worth knowing before a tenant reports being stuck:

- **The storage check reserves the record** rather than filling to the byte: the account stopped at
  67,108,842 of 67,108,864 bytes — 22 bytes of headroom — and refused every further publish.
- **The budget comes back immediately.** A `purge` freed storage and the next publish was accepted;
  deleting a stream freed a `max_streams` slot and the fourth stream was created at once.
- **A mirror's and a source's internal consumers do not count** against `max_consumers`, and
  `CONSUMER.NAMES` does not list them: `len(mset.consumers) - mset.sourcingConsumers`
  (`stream.go:8587`). A copy does not spend a tenant's consumer budget ([[mirrors-and-sources]]).

## How many consumers, and on what

**Consumers on one stream are not the expensive axis.** 1 / 10 / 100 / 300 / 1,000 filtered consumers
on one stream: publish rate 197,506 / 216,850 / 218,176 / 211,130 / 199,888 msg/s — flat.
`CONSUMER.INFO` on one of the thousand takes 0.2 ms; a restart with 1,005 consumers on a 1.1 M-message
stream takes 300.80 ms; `CONSUMER.LIST` is 4.7–4.9 ms at both 305 and 1,005 consumers, because the
response is paged (`limit` 256).

**The 300-way fan-out, built both ways, is the row's answer** — the same 300,000 × 128 B messages, the
same 300 subjects:

| | 300 streams, one consumer each | one stream, 300 filtered consumers |
|---|---|---|
| RSS, filled | 203.5 MiB | **73.9 MiB** (2.75× less) |
| disk | 64,800 KiB | **53,708 KiB** |
| ingest | 127,068 msg/s | **194,513 msg/s** (1.5× more) |
| empty, before any message | 55.4 MiB / 6,000 KiB | 37.1 MiB / 3,608 KiB |
| server subscriptions | 1,864 | 1,567 |

One stream with filtered consumers wins on every axis measured. **The two thresholds to design
against are elsewhere**:

- **~100,000 consumers**, the published guidance: "there's no hard cap, but beyond 100,000 consumers,
  the potential for issues increases significantly", because of background Raft traffic and load on
  the meta leader (source: [[s-synadia-jetstream-anti-patterns]]). At `R3` each one is an HA asset
  ([[jetstream-slows-as-consumers-grow]]).
- **~300 disjoint filters on *one* consumer** — and the runs sharpen what that number is. It is a
  **create-time** cost: `CONSUMER.CREATE` at 1 / 300 / 1,000 / 5,000 filters took 1.0 / **4.6** /
  **33.7** / **784.0 ms**, while the **first fetch stayed 0.2–0.4 ms at every count** and the single
  wildcard covering all 1,000 subjects created in 0.8 ms. So the published fix — rework the subject
  hierarchy so a wildcard does the job — is right, for a sharper reason than "scanning blocks": at
  rest the many-filter consumer read as fast as the wildcard one, and *creating* it cost three orders
  of magnitude more.

**Which readers need a consumer at all** is the question before the count. Two rules:

- **Instances of one app share a consumer; different apps each get their own.** One consumer
  *distributes*, it does not duplicate — the mistake that costs the asker of gh#4499 two weeks
  (source: [[s-gh-4499-workqueue-fanout-retention]]). [[worker-pool]] is the first case,
  [[retention-policies]] decides whether the second is allowed at all.
- **Live readers with no replay requirement do not need one.** `republish` re-emits every stored
  message onto a core subject that plain subscribers hear, and [[direct-get]] answers point reads
  without any consumer state. "Often, having too many consumers is downstream of overstated
  persistence and delivery guarantee requirements" (source: [[s-synadia-jetstream-anti-patterns]]).
  The published sizing advice agrees from the other direction: at scale the real cost is usually
  **consumers, not subjects** (source: [[s-synadia-how-many-subjects]]).

One property that argues *for* many consumers on one stream: **consumer leaders spread across the
replica set** — "each consumer leader (if replicated) can live on different Stream replica, balancing
the load" (source: [[s-gh-6100-stream-per-subject-or-one]]).

## How a second copy is made

**First, the answer to the reason people usually want one.** Asked to choose between a WorkQueue
stream plus a Limits mirror for analytics, and one Limits stream with both consumers on it, the
maintainer rejected the premise:

> "**It's not because a stream is larger that delivery of messages to consumers takes longer**,
> therefore approach 2 is simpler, more efficient and doesn't have the Cons you list." — @jnmoyne,
> 2025-03-02 (source: [[s-gh-6571-source-mirror-or-one-stream]])

Asked what a large stream *does* cost, the same answer names exactly one thing: "Mostly increased
memory usage if you have a lot of different subject being used in the stream (the servers maintain per
subject indexing)" — a **subject-cardinality** cost ([[subject-design]]), which a copy does not reduce
because it carries the same subjects. Consumers are independent cursors: a slow analytics reader does
not hold a fast one back ([[consumer]]). **So do not make a copy to keep the first stream small.**

The reasons that remain are location, policy and recovery — and there are exactly **two** shapes for
them, plus one that people expect and that does not exist.

| | **mirror** | **sourcing stream** |
|---|---|---|
| what it copies | one upstream, whole or filtered | one **or several** upstreams, each filtered and transformed |
| may it have its own `subjects` | **no** — `10034 stream mirrors can not contain subjects`, on create *and* on update | **yes**, and it can be published to directly |
| may it also have `sources` | **no** — `10031 stream mirrors can not also contain other sources` | yes, including **two of the same stream with different filters** |
| filter / transform | `mirror.filter_subject`, `mirror.subject_transforms` | `sources[].filter_subject`, `sources[].subject_transforms` |
| catch-up, 200,000 × 128 B | **0.521 s** | 0.652 s |
| disk for the same messages | **33,408 KiB** — exactly the origin's | **46,192 KiB — 1.38×** (with a transform, 263.9 B/msg against the mirror's 164.0 — **1.57×**) |
| can it serve reads for the upstream | **yes** — `mirror_direct` ([[mirrors-and-sources]]) | not as the upstream's identity |

**The 1.38× is one header on every message.** A sourcing stream stores
`Nats-Stream-Source: ORIG 1 orig.*.evt from-orig.{{wildcard(1)}} orig.1.evt` — origin stream, origin
sequence, the transform's source and destination, and the original subject. A mirror stores none, which
is why it costs exactly what the origin costs. **Choose a mirror unless you need something only a
source gives**: several upstreams, its own subjects, or a direct publish path.

Two things neither shape does: **neither follows a delete on the origin** (`STREAM.MSG.DELETE` on
sequence 5 left the message readable in both), and **both survive the origin being deleted**, complete
and readable. A copy is not a replica — [[replicas]] is what makes a stream survive a node.

**And the third shape does not exist server-side.** "A consumer on the origin that writes into a second
stream" is the option row 114 asks about, and it cannot be built with a consumer alone: a push consumer
delivering to `copy2.evt`, with the second stream subscribed on `copy2.>`, delivered **0 of 1,000**
messages, `num_pending` stuck at 1,000, **nothing logged at any level**. `Sublist.registerNotification`
counts interest only for a subscription whose subject is *literally equal* to the deliver subject
(`sublist.go:169–190`) — and a stream's capture subject is a wildcard in every realistic case.
Attaching one plain `nats sub copy2.evt` released all 1,000 at once (server issue **SI-9**).

The working form is a **client**: pull from the origin, publish into the copy — 1,000 messages in
0.01 s in the run. It costs a process to run and to supervise, and **the copy carries no origin header
and gets its own sequence numbers**, so nothing of the origin's position survives and neither side can
tell how far behind it is. If you need the copy to know where it is, that is a mirror or a source, not
a client.

## The configuration that implements it

```
# the default shape: one stream, many filtered consumers
nats stream add ORDERS --subjects 'orders.>' --storage=file --replicas=3 --retention=limits
nats consumer add ORDERS billing   --filter 'orders.*.paid'    --pull --ack=explicit
nats consumer add ORDERS analytics --filter 'orders.>'         --pull --ack=explicit

# a second stream, because the policy differs — not because the first one is big
nats stream add AUDIT --subjects 'orders.audit.>' --storage=file --replicas=5 --max-age=8760h

# a read replica in another region: a mirror, and it may answer the origin's direct reads
nats stream add ORDERS_EU --mirror ORDERS --replicas=3
#   … with `allow_direct` on ORDERS and `mirror_direct` on the mirror — mirrors-and-sources

# fan-in from several streams, or a copy you can also publish into: a source
nats stream add ROLLUP --source ORDERS --source PAYMENTS --subjects 'rollup.>'
```

| what you are setting | where | note |
|---|---|---|
| stream count | one `nats stream add` each | the floor is 8 KiB + ~55 KiB of RSS at `R1`, a Raft group at `R3` |
| `--replicas` | per stream | the single biggest term: `R1` → `R3` is 0.6 ms → ~110 ms per create ([[replicas]]) |
| consumer count and filters | `--filter` / `filter_subjects` (2.10+) | many consumers are cheap; many **filters on one** consumer are not |
| account `max_streams`, `max_consumers`, `max_file` | `accounts { … jetstream { … } }` | `max_consumers` is **per stream** — above |
| `max_ha_assets` | `jetstream { limits { } }` | refuses new Raft groups and excludes the server from placement |
| the copy | `--mirror` or `--source` | never a consumer — SI-9 |

## Trade-offs and costs

| decision | what it buys | what it costs | when it stops working |
|---|---|---|---|
| **one stream, many filtered consumers** (default) | one retention budget, one restore, indexed reads, consumer leaders spread across replicas | every subject shares retention, replication, storage and placement; one blast radius | when a subject needs a different **policy**, or when one tenant's backlog must not be another's |
| **many streams** | policy per stream, blast radius, per-tenant restore and limits | 1.26× disk; ~55 KiB of RSS each; **restart**: 5.4 s at 10,000 `R1`, 18 s at 1,000 `R3`; an HA asset each at `R3` | a few thousand HA assets per server (Synadia's operating figure is **2k**); at `R1`, when the restart budget runs out |
| **many consumers on one stream** | independent cursors, independent replay, no data duplication | per-consumer state, one HA asset each at `R3`, meta-leader load | ~100,000 consumers, published guidance |
| **many filters on one consumer** | one asset instead of many | **create time**: 4.6 ms at 300 filters, 784 ms at 5,000 | ~300 disjoint filters — rework the subjects so a wildcard covers them |
| **a mirror** | a second copy at the origin's price, `mirror_direct` read spreading, a recovery point | a full second copy of the data and its replication | it may never have its own subjects or sources |
| **a sourcing stream** | several upstreams, its own subjects, a direct publish path | **1.38–1.57×** the mirror's disk, for the origin header on every message | when you only needed one upstream — take the mirror |
| **a client-made copy** | arbitrary transformation, cross-anything | a process to supervise; **no origin sequence, no lag figure** | it is the only shape when neither of the other two fits |

## When *not* to use it

- **Do not create a stream per subject.** A filter already gives per-subject reading, and the stream
  adds a floor, a restart cost and (at `R3`) an HA asset for nothing.
- **Do not create a stream per short-lived thing.** The first message into a fresh stream costs
  ~4.4 ms, and 10,000 streams are 5.4 s of every restart.
- **Do not split a stream for performance.** The publish path did not move between 1 and 1,000 streams,
  and delivery does not slow because a stream is large; the one thing that does grow is the
  per-subject index, which a split does not shrink.
- **Do not use `max_consumers` as an account budget.** It caps per stream; use `max_streams`.
- **Do not build the copy with a consumer.** It silently delivers nothing (SI-9).
- **Do not reach for a stream when an account is what you meant.** A prefix and a stream are not
  isolation boundaries; an account is ([[account]]).

## Related

[[subject-design]] · [[stream]] · [[consumer]] · [[retention-policies]] · [[mirrors-and-sources]] ·
[[replicas]] · [[account]] · [[meta-layer]] · [[jetstream-sizing]] ·
[[jetstream-slows-as-consumers-grow]] · [[jetstream-recovery-is-slow]] · [[stream-placement]] ·
[[multi-region-jetstream]] · [[worker-pool]] · [[direct-get]] · [[filestore-layout]] · [[metrics]] ·
[[core-or-jetstream]] · [[event-sourcing-on-jetstream]]

## Sources

- [[s-gh-6100-stream-per-subject-or-one]] — the default and its reason (the per-stream Raft group), the
  one exception (different retention), consumer leaders across replicas, and the per-tenant post that
  answers the other way.
- [[s-gh-3405-consumer-filtering-performance]] — "the server doesn't do like a table scan": filtering is
  indexed, which the one-stream default rests on.
- [[s-gh-6571-source-mirror-or-one-stream]] — a copy is not a performance tool, and the one cost of a
  large stream is the per-subject index.
- [[s-nats-server-stream-topology-observed]] — every measured number on this page: runs A, A2, R3 (stream
  count), C (consumers and filters), D (the account limits and #124), F (the two copy shapes and SI-9).
- [[s-gh-5128-ha-assets]] — 2,000 HA assets per server as Synadia's operating figure, and muxed streams
  with filtering as the recommendation.
- [[s-nats-server-traffic-counters-and-ha-assets]] — `ha_assets` is the count of Raft nodes, and
  `max_ha_assets` refuses groups and excludes a server from placement.
- [[s-gh-3772-jetstream-as-an-event-store]] — "on the order of 100s of thousands of assets" as the
  theoretical ceiling.
- [[s-synadia-jetstream-anti-patterns]] — ~100k consumers, ~300 disjoint filters, and republish and
  Direct Get as the two ways to need fewer consumers.
- [[s-synadia-how-many-subjects]] — the real cost at scale is consumers rather than subjects, and the
  reasons to partition.
- [[s-synadia-subject-hierarchies]] — one stream per top-level namespace, because a shared stream
  couples retention, replication and storage budget.
- [[s-gh-4499-workqueue-fanout-retention]] — instances of one app share a consumer; different apps each
  get their own.
- [[s-gh-4170-subject-indexing-internals]] — the subject space as the set definition a filter reads,
  and per-subject state as a memory cost.
