---
title: JetStream sizing
type: operation
kind: sizing
area: [deploy, jetstream]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [sizing, disk, memory, max_file_store, account-limits, file-descriptors]
aliases: [sizing, capacity planning, how much disk, how much RAM]
sources: [s-docs-sizing-and-resources, s-synadia-jetstream-memory-patterns, s-docs-connection-limits-config, s-docs-surviving-node-loss, s-docs-replication-and-r3, s-docs-upgrade-to-2.12, s-synadia-jetstream-anti-patterns, s-nats-server-constants-2.14.6, s-docs-monitoring-endpoints]
created: 2026-08-31
updated: 2026-08-31
---

# JetStream sizing

**The question this answers:** how much disk, RAM, CPU and file-descriptor headroom a JetStream
node needs, and how a replicated stream's bytes count twice — once against the node's disk, once
against the account's quota.

**What it does not answer:** IOPS. No public source read so far gives IOPS guidance for JetStream,
and the per-message *storage overhead* (block, index and per-subject-state bytes on top of the
payload) is likewise unstated — see [[filestore-layout]] and *What is still unknown*, below. Sizing
disk from payload bytes alone will under-count by an amount this wiki cannot yet quantify.

## Inputs you need

Before any of the arithmetic below means anything, collect:

| input | why | how to get it |
|---|---|---|
| peak message rate (msg/s) | drives CPU and replication traffic | your publisher's own metrics |
| message size (bytes, p50 and peak) | drives disk, and bounds `max_payload` / `max_pending` | your publisher |
| retention target (`max_age`, `max_msgs`, `max_bytes`) | the only thing that bounds a `limits` stream | a decision, not a measurement |
| replica count | multiplies both disk and write traffic | see [[replicas]] |
| consumer count and lifetime | drives memory more than message count does | your application design |
| the **account's** live limits | the server enforces these regardless of node disk | `nats account info` |
| the volume's real size | the default reads the filesystem, not your intent | `df -h` |

**Read the live limits before you size.** The numbers the server enforces are not necessarily the
numbers in the config you are looking at — in operator mode they come from the account JWT
(source: [[s-docs-sizing-and-resources]]).

```
nats account info --server tls://nats.example.internal:4222 --creds /etc/nats/creds/app.creds
nats server info n1-east --server tls://nats.example.internal:4222 --creds /etc/nats/creds/sys.creds
```

`nats server info` is a **system-account** request — use the system account's creds, not an
application user's.

## The four resources a node spends

Once each of these is sized, the node is sized (source: [[s-docs-sizing-and-resources]]).

**CPU.** Core NATS routing is cheap; **TLS handshakes and JetStream replication** are where the
cycles go. There is no hard CPU limit to set, so the rule is headroom: **overprovision by 20–30%
above steady state**, so a node has cycles spare for a rebalance when a peer leaves.

**Memory.** Connections, subscriptions, and — for memory-storage streams only — message data. A
file-storage stream's messages live on disk, not in RAM. A few hundred light client connections fit
comfortably in a few hundred megabytes. What actually drives JetStream memory is covered under
*Sizing RAM* below.

**Disk.** File-storage streams. **This is the resource most likely to run out.**

**File descriptors.** Connections, routes and streams each consume them, and **JetStream spends
roughly two FDs per stream**. The default per-process limit is fine on a small cluster and not on a
large one; the docs' hardened service unit sets `LimitNOFILE=800000`.

## The calculation

### Step 1 — the stream's stored bytes

Start from retention, not from rate:

```
stream_bytes ≈ (messages retained) × (average message size) × (1 + per-message overhead)
```

where *messages retained* is whichever of `max_msgs`, `max_bytes` or `max_age × rate` binds first.
**The overhead term is unknown** — see *What is still unknown*. Until a source gives it, size with
`max_bytes` set to a number you have measured on a test stream, not one you derived.

### Step 2 — multiply by replicas, per node

Each replica stores the **full** stream. On a three-node cluster holding one R3 stream, **each node
stores the whole stream once** — the multiplier lands on the cluster, not on any one node:

```
per_node_disk ≈ Σ (stream_bytes of every stream whose replicas include this node)
cluster_disk  ≈ Σ (stream_bytes × num_replicas)
```

R3 is **roughly three times the storage and write traffic of R1**
(source: [[s-docs-surviving-node-loss]]).

### Step 3 — multiply *again* for the account quota

This is the step people miss (source: [[s-docs-sizing-and-resources]]):

- **On an un-tiered account, an R3 stream counts as `replicas × bytes` against `MaxStore`.** A
  10 GiB stream at R3 spends **30 GiB** of the account's storage limit.
- **On a tiered account, replication is baked into the tier.** The bytes reported are *usable*
  bytes: a 10 GiB tier holds a 10 GiB R3 stream.

Get this wrong on an un-tiered account and **the third replica fails to place** when the account
hits its ceiling — the node has disk, the account does not.

### Step 4 — pin `max_file_store` to the volume

Left unset, JetStream sizes itself from the machine
(source: [[s-docs-sizing-and-resources]]):

| key | default | fallback, and when |
|---|---|---|
| `max_memory_store` | **75% of system RAM**, capped by `GOMEMLIMIT` if set | **256MB**, only when the server cannot read system memory |
| `max_file_store` | **75% of the disk actually available under `store_dir`** | **1TB**, only when the platform cannot report disk size (Windows and a few others, or a failed `statfs`) |

The `256MB` and `1TB` figures are **fallbacks, not defaults** — a widely mis-quoted distinction. On
a Linux container with a 10 GiB volume the file-storage default is about **7.5 GiB**, not 1 TB.

```
jetstream {
  store_dir:        "/var/lib/nats/jetstream"
  max_memory_store: 256MB
  max_file_store:   10GB
}
```

The hazard is not the default; it is **setting `max_file_store` larger than the volume**, or
running on a **shared or thin-provisioned** volume whose "available" space overstates what this
node may safely use. Either way the node accepts writes it cannot store, and the failure arrives as
a **publish error mid-stream, not a startup warning**.

On Kubernetes the Helm chart already defaults `max_file_store` to the PVC size, so this pin is
usually set for you.

### Step 5 — bound the message size

`max_payload` caps a single message. **Default 1 MB**; the reference is explicit that values over
**8MB are not recommended** and that the hard ceiling is **64MB**
(source: [[s-docs-connection-limits-config]]).

Two hard constraints:

- **`max_payload` must be `≤ max_pending`**, and if it is not, **the server refuses to start**.
- Keep **`max_pending ≥ 10× peak message size**` so a burst of large messages cannot stall a
  connection.

`max_payload` is **hot reloadable**; `max_pending` **requires a restart**. So raising the payload
ceiling is a two-stage change: restart to raise `max_pending` first, then reload `max_payload`.

With the defaults there is room — **1 MB against 64 MB** ([[defaults-and-limits]]). Above **8 MB**
the server logs a startup warning and keeps running: it is a warning threshold, not a limit, and the
constant's comment flags that a future version may start rejecting.

## Sizing RAM

The docs' sizing page covers storage; it does not say what JetStream holds in memory. Four things
do (source: [[s-synadia-jetstream-memory-patterns]]):

1. **Message deduplication tables** — recently seen message IDs, sized by the stream's
   deduplication window.
2. **File store caching** — recently accessed messages and stream data, cached to speed reads.
3. **Metadata and subject tracking** — stream, consumer and subject state held for quick lookups.
4. **Meta leadership** — the node holding meta leadership coordinates and holds state for **all**
   streams. That overhead lands on one node.

**Message count and size do not directly drive memory.** Synadia's answer to a user running 300M+
messages across a few streams with one consumer each was that such a workload *should not*
inherently use much memory — memory follows **architectural patterns** (meta leadership,
deduplication window, consumer lifecycle), not volume. The exceptions named are consumers doing
**full stream scans** and **many short-lived consumers**.

The levers, in the order Synadia gives them:

- **Tune the deduplication window per stream** — or disable dedup if you deduplicate externally.
- **Fewer subjects per stream** where the design allows.
- **Prefer long-lived consumers**; short-lived ones cost more memory.
- **Keep meta leadership off nodes carrying high-volume streams.**
- If none of that explains it, **profile with Go's `pprof`**.

### Consumers are a cluster-wide budget

Consumers cost continuously, not per message: each one's state is managed and replicated across the
cluster. Synadia's guidance (source: [[s-synadia-jetstream-anti-patterns]]):

> "There's no hard cap, but **beyond 100,000 consumers, the potential for issues increases
> significantly.** The background Raft traffic and the load on the meta-leader increase as they work
> to maintain state consistency across nodes and manage consumer subscriptions."

and, for a single consumer's filter list:

> "adding **more than a few hundred disjoint subject filters** will likely lead to slowness and
> instability"

with the post's recap giving the working number as **~300 per consumer**. Both are **guidance, not
server limits** — the source says "there's no hard cap" and "there is no hard limit here", and does
not state the version or method behind either number.

Two consequences for sizing:

- **Count consumers cluster-wide, the way you count disk.** The load lands on the meta leader, so it
  does not show up as any one stream's problem.
- **Consumers can often be designed away** — a `republish` policy or Direct Get serves clients that
  do not need a durable position, at no per-client cost. See
  [[jetstream-slows-as-consumers-grow]].

### Memory behaves differently from 2.12 onward

**Elastic pointers in the filestore (2.12)** changed the shape of NATS memory use: the server can
now free filestore caches on demand and return memory to the OS under pressure, which lowers
OOM-kill risk — but it also **retains caches more optimistically when resources allow**. The
upgrade guide is explicit that RSS "may result in lower resident set size (RSS) reported, in others
it may result in higher, depending on the number of assets and publish/access patterns"
(source: [[s-docs-upgrade-to-2.12]]).

**The lever is `GOMEMLIMIT`.** The behaviour is "largely controlled by the GC thresholds as set by
the `GOMEMLIMIT` environment variable", which the guide suggests tuning against available system
memory or, on Kubernetes, against the pod's memory reservation. Since 2.12 the effective
`GOMAXPROCS` and `GOMEMLIMIT` also appear in the server stats, so you can confirm what the process
actually got rather than what you set.

Two practical consequences: **RSS is no longer a straightforward capacity signal** on 2.12+, and a
memory comparison across a version boundary is not like-for-like.

An asymmetric memory profile across a cluster — one node at 13 GB while its peers sit at 2–3 GB —
is the expected shape when that node holds meta leadership plus stream and consumer leadership. Look
at leadership before looking for a leak. See [[raft-in-nats]].

## A worked example

A three-node cluster, one R3 file stream, on an **un-tiered** account.

| input | value |
|---|---|
| rate | 500 msg/s peak |
| message size | 800 B average |
| retention | `max_age: 72h` |
| replicas | 3 |
| account | un-tiered |

**Payload bytes retained:** `500 msg/s × 800 B × 72 h × 3600 s/h` = 103,680,000,000 B ≈ **96.6 GiB**
of raw payload.

**Per node:** each of the three nodes stores the full stream once → **≈ 96.6 GiB of payload per
node**, *plus* the unquantified filestore overhead. A 10 GiB volume is off by an order of
magnitude; this stream needs a volume of at least ~120 GiB per node to leave headroom, and the real
figure must be measured, not derived.

**Against the account quota:** un-tiered, so `replicas × bytes` = `3 × 96.6 GiB` ≈ **290 GiB** of
`MaxStore`. An account provisioned at 100 GiB will accept the stream at R1 and **fail to place the
third replica**.

**`max_payload`:** 800 B average is far under the 1 MB default; no change needed.

**File descriptors:** one stream ≈ two FDs. Not a constraint here; it becomes one in the hundreds
of streams.

**The lesson of the example** is step 3. The disk arithmetic said 96.6 GiB per node and everything
looked fine; the account arithmetic said 290 GiB and the stream cannot be created at R3.

## Rules of thumb

Each with its source. Nothing here is inferred.

| rule | source |
|---|---|
| Overprovision CPU by **20–30%** above steady state | [[s-docs-sizing-and-resources]] |
| JetStream spends **~2 file descriptors per stream** | [[s-docs-sizing-and-resources]] |
| `max_memory_store` defaults to **75% of RAM**, `max_file_store` to **75% of available disk** | [[s-docs-sizing-and-resources]] |
| An un-tiered account charges **`replicas × bytes`** against `MaxStore` | [[s-docs-sizing-and-resources]] |
| Keep `max_pending` at **≥ 10× peak message size** | [[s-docs-sizing-and-resources]] |
| `max_payload`: **1 MB** default, **8MB** not recommended above, **64MB** hard ceiling | [[s-docs-connection-limits-config]] |
| R3 is **~3× the storage and write traffic** of R1 | [[s-docs-surviving-node-loss]] |
| Replicas **do not scale writes** — a higher count lowers peak write throughput | [[s-docs-surviving-node-loss]] |
| Memory follows **leadership and dedup window**, not message count | [[s-synadia-jetstream-memory-patterns]] |
| Keep total consumers **below ~100,000** | [[s-synadia-jetstream-anti-patterns]] |
| Keep disjoint subject filters **below ~300 per consumer** | [[s-synadia-jetstream-anti-patterns]] |

## What runs out first

Roughly in the order it bites:

1. **The account's `MaxStore`** — because of the `replicas × bytes` rule, this is hit at a third of
   the stream size you were planning for, and the symptom is a **placement failure**, not a disk
   alert.
2. **Disk under `store_dir`** — the resource the docs single out as most likely to run out. The
   symptom of over-committing `max_file_store` is a **publish error mid-stream**.
3. **The meta leader** — memory, and Raft/API load that scales with **consumer count** rather than
   message count. Not on every node, and not in proportion to traffic.
4. **File descriptors**, in the hundreds of streams, with a symptom that misleads: **connection
   refusals that look like a network fault**.
5. **CPU**, mostly during TLS handshakes and replication, and mostly visible as a node that cannot
   catch up after a rebalance.

## How to measure it on a running system

```
nats account info                 # the live account ceilings: Memory, Storage, Streams, Consumers
nats server info <server>         # this node's Maximum Payload, Maximum Connections, JetStream limits
nats stream info <stream>         # the stream's real size and its replica states
df -h /var/lib/nats/jetstream     # what the device says, which outranks what the config says
ulimit -n                         # the FD ceiling the process will actually get

curl -s 'http://localhost:8222/jsz?acc=<account>&streams=true' | jq   # per-account, per-stream state
curl -s http://localhost:8222/varz | jq '{connections, slow_consumers}'
```

**Scope `/jsz`.** An unscoped `?accounts=true&streams=true&consumers=true` walks every account,
stream and consumer and serialises the lot — on a node with thousands of consumers the scrape times
out and returns *nothing* (source: [[s-docs-monitoring-endpoints]]). See [[monitoring-endpoints]].

Watch the device, not the config: *"Don't trust the config number over what the device reports."*
Deeper per-stream and per-account accounting lives on the `/jsz` endpoint — see
[[monitoring-endpoints]].

## Pitfalls

- **Sizing the node and forgetting the tenant.** An account limit is enforced regardless of how
  much disk the node has.
- **Treating 256MB / 1TB as the JetStream defaults.** They are fallbacks for when the server cannot
  read the system's memory or disk.
- **Raising `max_payload` in isolation.** It must stay `≤ max_pending`, and above 8MB you are
  outside what the reference recommends even though the server will accept up to 64MB.
- **Expecting a JWT account limit to change on reload.** In operator mode, `MaxStore` and
  `MaxStreams` live in the account JWT the resolver holds — editing and pushing the JWT is the only
  way to move them, and a server reload or restart will not
  (source: [[s-docs-sizing-and-resources]]). Keep server versions aligned across a rolling upgrade
  so every node reads the same JWT limit fields; tiered R1/R3 limits need servers new enough to
  understand them.
- **Adding replicas to get throughput.** They cost write throughput rather than adding it — see
  [[replicas]].

## What is still unknown

Recorded here rather than guessed, because a wrong sizing number is the most damaging thing this
wiki could contain.

- **Per-message storage overhead** — how many bytes a stream spends on blocks, index and
  per-subject state beyond the payload (question-bank Q2). No source ingested so far states it.
  Until one does, measure it on a test stream.
- **IOPS** — no public source read so far gives JetStream IOPS guidance (part of Q1).
- **A practical cap on messages in one stream, or a known-good `MaxMsgs`** (Q4, Q5) — unstated.
- ~~How many consumers one stream or server supports (Q6)~~ — **answered**, as guidance rather
  than a limit: see *Consumers are a cluster-wide budget* above.
- **Why memory grows with the number of unacknowledged messages** (Q10) — the Synadia post covers
  memory generally but does not address pending-message state.
- **Filestore compression's cost** (Q31) — [[stream]] records that `s2` trades CPU for disk, but no
  source quantifies either side.
- ~~Why `max_payload` above 8MB is "not recommended"~~ — **answered**: above 8 MB the server logs a
  startup warning and does nothing else (`server/server.go:2342`), and the constant's comment says a
  future version *may* reject it. See [[defaults-and-limits]]. What actually degrades between 8 MB
  and 64 MB is still unsourced — the warning text says only "could lead to poor performance".

## Related

[[replicas]] · [[stream]] · [[consumer]] · [[raft-in-nats]] · [[filestore-layout]] ·
[[monitoring-endpoints]] · [[jetstream-out-of-disk]] · [[config-keys]] · [[defaults-and-limits]] ·
[[jetstream-slows-as-consumers-grow]]

## Sources

[[s-docs-sizing-and-resources]] · [[s-synadia-jetstream-memory-patterns]] ·
[[s-docs-connection-limits-config]] · [[s-docs-surviving-node-loss]] ·
[[s-docs-replication-and-r3]] · [[s-docs-upgrade-to-2.12]] · [[s-synadia-jetstream-anti-patterns]] ·
[[s-nats-server-constants-2.14.6]] · [[s-docs-monitoring-endpoints]]
