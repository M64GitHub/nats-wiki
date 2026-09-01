---
title: JetStream sizing
type: operation
kind: sizing
area: [deploy, jetstream]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [sizing, disk, memory, max_file_store, account-limits, file-descriptors]
aliases: [sizing, capacity planning, how much disk, how much RAM]
sources: [s-issue-8322-dynamic-maxstore-shrinks, s-issue-4281-insufficient-storage, s-nats-server-jetstream-resources, s-nats-server-systemd-units, s-docs-sizing-and-resources, s-synadia-jetstream-memory-patterns, s-docs-connection-limits-config, s-docs-surviving-node-loss, s-docs-replication-and-r3, s-docs-upgrade-to-2.12, s-synadia-jetstream-anti-patterns, s-nats-server-constants-2.14.6, s-docs-monitoring-endpoints, s-adr-35-filestore-compression, s-nats-server-filestore-layout, s-nats-helm-chart-values-2.14.6, s-gh-7749-hostpath-jetstream, s-k8s-760-jetstream-pvc-per-replica, s-docs-shaping-the-stream, s-nats-server-object-store-observed, s-docs-object-store-chunking, s-docs-monitoring-profiling, s-gh-7483-varz-cpu-in-containers, s-nats-server-monitoring-observed, s-docs-hardening, s-gh-5924-filestore-dirs-vanished, s-gh-6490-high-message-lag, s-gh-4972-nak-with-delay-blocks]
created: 2026-08-31
updated: 2026-09-01
---

# JetStream sizing

**The question this answers:** how much disk, RAM, CPU and file-descriptor headroom a JetStream
node needs, and how a replicated stream's bytes count twice — once against the node's disk, once
against the account's quota.

**What it does not answer:** IOPS. No public source read so far gives IOPS guidance for JetStream.
The per-message storage overhead **is** now quantified — read at the tag and measured on the binary;
it is Step 1 below and the mechanism is on [[filestore-layout]].

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
large one; the unit the server repo ships sets **`LimitNOFILE=800000`**, with the reason in a comment —
"JetStream requires 2 FDs open per stream" (source: [[s-nats-server-systemd-units]] · [[s-nats-server-filestore-layout]] ·
[[s-nats-helm-chart-values-2.14.6]] · [[s-gh-7749-hostpath-jetstream]] ·
[[s-k8s-760-jetstream-pvc-per-replica]] ·
[[s-docs-shaping-the-stream]]). Setting it is
part of [[install-nats-server]].

## The calculation

### Step 1 — the stream's stored bytes

Start from retention, not from rate:

```
messages_retained = whichever of max_msgs, max_bytes or (max_age × rate) binds first

record_bytes  = 30 + len(subject) + len(payload) + (headers ? 4 + len(headers) : 0)
stream_bytes  = messages_retained × record_bytes
```

**The 30 bytes are exact**: a 22-byte record header (`total_len`, `seq`, `ts`, `subj_len`) plus an
8-byte checksum, and the subject is stored verbatim on **every** message. This is also the figure the
server reports, so `nats stream info` bytes, `max_bytes`, `/jsz storage` and an account's `MaxStore`
are all counted in `record_bytes` — payload bytes are never reported anywhere
(source: [[s-nats-server-filestore-layout]], `nats-server 2.14.6`). See [[filestore-layout]].

What that costs, by message shape:

| payload | subject | record bytes | overhead |
|---|---|---|---|
| 100 B | `orders.new` (10) | 140 | **+40%** |
| 1 KB | `orders.new` (10) | 1,064 | +3.9% |
| 100 KB | `orders.new` (10) | 102,440 | +0.04% |

**Small messages are where this bites.** A stream of 100-byte events costs 40% more disk than the
payload arithmetic says; a stream of 100 KB documents costs 0.04% more. A **memory** stream uses a
different formula — `len(subject) + len(headers) + len(payload) + 16` — so its `bytes` figure is not
comparable to a file stream's.

### Step 1b — add the physical slack

`stream_bytes` is what the server *accounts*. What the volume gives up is larger, and by a bounded
amount:

```
disk_bytes ≈ stream_bytes + one block size + index.db + ~520 B of metadata
index.db   ≈ Σ over distinct subjects (len(subject) + 4)
```

**Budget one whole block size per stream**, because the newest message block is never rewritten to
drop the messages that have aged out of it — that is by design, not a bug
(`filestore.go:6151`, `filestore.go:8039`). The block size is chosen for you:

| the stream sets | block size |
|---|---|
| nothing, `limits` retention | **8MB** |
| nothing, any other retention | 4MB |
| `max_msgs_per_subject` (so **every KV bucket**) | 4MB |
| `max_bytes` under ~128 KB | 32,000 B |
| `max_bytes` between that and 32MB | **4MB** |
| `max_bytes` at or over 32MB | 8MB |

Measured worst case: a stream reporting **133,000 bytes** held **1,125,712 bytes** on disk — 8.5× —
and stayed there across a sync interval and a restart, because it was idle and its whole content sat
in the last block. Steady-state streams sit within a few percent; ten streams totalling 37,891,637
reported bytes occupied 39,881,215 on disk, **+5.25%**
(source: [[s-nats-server-filestore-layout]]).

**Rule of thumb: size the volume at `stream_bytes × 1.1 + 8MB per stream`,** and never at
`stream_bytes` exactly.

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
a Linux container with a 10 GiB volume the file-storage default is about **7.5 GiB**, not 1 TB. Both
values are now read from the server rather than from the docs: `diskAvailable` is
`Bavail * Bsize / 4 * 3` (`disk_avail.go:31`) and the memory branch is `sysMem / 4 * 3` over **total**
system memory (`jetstream.go:2777`), source: [[s-nats-server-jetstream-resources]]. The generated
config reference contradicts this and is recorded as **docs issue #22**.

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

**Pinning it is not optional advice — the maintainers say so twice, and leaving it unset breaks
restarts.** The dynamic value is 75% of what is **free** at startup, so every byte JetStream itself
has written lowers the next boot's ceiling:

> "We do not recommend auto-sizing for real world production uses. You should always configure
> JetStream to use as much disk as you want / need explicitly in the configuration. Auto detection is
> for development and testing." — @derekcollison, 2024-09-10
> (source: [[s-issue-8322-dynamic-maxstore-shrinks]])

512 MB volume → limit 338 MB → create a 300 MB stream → fill 250 MB → **restart** → limit 196 MB, and
the server refuses to restore the stream with `insufficient storage resources available (10047)`.
**nats-server 2.14.6** adds `finalizeDynamicMaxStore`, which adds recovered bytes back after startup
recovery (PR #8503, merged 2026-08-24); it is absent from 2.14.5 and every earlier release. Even with
the fix the limit is computed once, at startup, so a shared volume still invalidates it. See
[[jetstream-out-of-disk]].

`max_file_store: 0` does **not** mean unlimited. An explicitly configured `0` is honoured as zero and
no stream can be created (`jetstream.go:2760`, source: [[s-nats-server-jetstream-resources]]).

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

### Step 6 — if it is an object bucket, size it in messages first

An [[object-store]] bucket is a stream and every step above applies to it, but the input changes: you
do not know the message count from the message rate, you derive it from the **chunk size**.

```
messages = ceil(object_bytes / chunk_size) + 1        # +1 for the metadata message, per object
```

At the **128 KiB** default (source: [[s-docs-object-store-chunking]]) a 1 GiB object is **8,192 chunk
messages**; a 200 MiB object is 1,600. Two things follow that catch people out:

- **`max_msgs` on the backing stream counts chunks, not objects.** A `max_msgs` chosen for "how many
  files should this bucket hold" is off by three or four orders of magnitude.
- **The per-message overhead is a function of the chunk size you picked**, not of the data. Measured
  at the default on 2.14.6, a 200 MiB object occupied 204,912 KB on disk — about **2.4 %**. Halve the
  chunk size and that share doubles (source: [[s-nats-server-object-store-observed]];
  [[filestore-layout]] has the record arithmetic).

Two more figures for the disk budget. `discard: new` on an object bucket means a full bucket
**rejects puts** rather than making room, so the volume headroom in Step 4 is not optional here. And
after deleting a large object, expect **one trailing block** of residue rather than a slow drain: a
200 MiB delete returned 98.4 % of the bytes at the call and left a single 3.2 MB block.

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
- If none of that explains it, **profile with Go's `pprof`** — the method is below.

**Neither memory control reserves anything at startup**, which is why a cap set from the wrong number
gets the process OOM-killed rather than throttled: "`max_memory_store` is an accounting limit checked
as messages arrive, and `GOMEMLIMIT` is a soft target the Go garbage collector aims for". The docs'
hardened unit sizes the two against each other with the store as the floor — `MemoryMax` above
expected use, `GOMEMLIMIT` "somewhat below `MemoryMax` so GC reins memory in before the cgroup kills
the process", and both above `max_memory_store` plus buffers
(source: [[s-docs-hardening]]):

```
# With jetstream { max_memory_store: 4Gi }, size for the store plus buffers.
MemoryMax=6G
Environment=GOMEMLIMIT=5500MiB
```

One systemd interaction is easy to miss when hardening the same unit: `ProtectSystem` makes paths
read-only, and the JetStream `store_dir` — plus the pid and ports-file directories — must be listed as
writable or the server cannot start. See [[install-nats-server]].

#### Profiling, when none of the above explains it

That pointer had no instructions attached for five plans. It does now (source:
[[s-docs-monitoring-profiling]]).

**Start with the system-account route**: it needs no config change and no restart, which matters
mid-incident when a restart destroys the state you are chasing.

```
nats server request profile heap --name=n1-east      # writes heap-<timestamp>-n1-east
nats server request profile goroutine --cluster=east
```

The request travels on `$SYS.REQ.SERVER.PING.PROFILEZ`, so the context must be connected to the
**system account** — a normal account has no permission on `$SYS` and the request simply gets no
replies ([[monitoring-endpoints]]). `--name`, `--host`, `--cluster` and `--tags` narrow who answers,
which matters on a large cluster.

| profile | ask for it when |
|---|---|
| `heap` | memory is growing and you want to know what still **holds** it |
| `allocs` | memory **churn** — what allocates most, freed or not |
| `goroutine` | the server looks stuck, or its goroutine count climbs |
| `cpu` | a node is pinning a core |

**CPU sampling is capped at 15 seconds on this route.** The CLI reuses the global `--timeout` as the
window (default `5s`); ask for longer and the server returns an error instead of a profile.

**A longer window needs `prof_port`, and it has two real costs.** It is **not reloadable**, so turning
it on is a rolling restart; and it has **no authentication** and binds to the same `host` as the client
port — default `0.0.0.0`, with no separate profiling host to narrow. A goroutine dump exposes subjects
and internal state, so leave `prof_port` unset in production or firewall it
([[install-nats-server]] covers the systemd hardening; the firewall rules are yours). Block profiling additionally needs `prof_block_rate` above zero — that one
*is* reloadable, so raise it, take the profile, and drop it back.

Read the result with `go tool pprof -top <file>`, or `go tool pprof -http=:8080 <file>` for the flame
graph. If you are collecting it for someone else, send the file as it is.

#### Reading `/varz` `cpu` while you size

One number to get right before setting any CPU threshold: **`cpu` in `/varz` is a percentage of one
core**, not of the host and not of a container's allocation, so `cpu: 250` is two and a half cores
(source: [[s-nats-server-monitoring-observed]]). The 20–30 % headroom rule above is therefore a
fraction of the **allocation**, and on a container `cores` reports the host's logical CPUs rather than
the quota. [[monitoring-endpoints]] has the derivation.

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

### A retry policy is a capacity input

`max_ack_pending` is usually sized against worker count ([[worker-pool]]), but a consumer that
retries with **delayed naks** spends the same budget twice: a message nak'd with a delay stays
*pending* for the whole delay, so it holds its slot while it sleeps
(source: [[s-gh-4972-nak-with-delay-blocks]], [[ack-and-redelivery]]).

The sleeping set is a steady-state number you can compute from the retry policy:

```
sleeping slots ≈ nak rate (per second) × nak delay (seconds)
cap ≥ workers in flight + sleeping slots + headroom
```

(Arithmetic from the constraint; **no source states this number** — the only published guidance is a
maintainer's "the only real option today is to increase the maxackpending.")

A worked case from the reporting thread: `max_ack_pending: 10`, every message nak'd with a
one-minute delay — 10 sleeping slots consume the entire cap and the consumer delivers **nothing** for
a minute. At 50 naks per second and a 60-second delay the sleeping set alone is ~3000 slots, which is
three times the default cap of 1000.

**What this costs elsewhere:** pending state is per consumer and is replicated, so a large
`max_ack_pending` is not free — it grows the consumer's `o.dat` and its Raft traffic, which is the
budget *Consumers are a cluster-wide budget* above is about. A retry design with long delays and high
rates is therefore a **sizing decision**, not a client-side detail; if the numbers come out absurd,
schedule the retry as a new message instead ([[message-scheduling]]).


## A worked example

A three-node cluster, one R3 file stream, on an **un-tiered** account.

| input | value |
|---|---|
| rate | 500 msg/s peak |
| message size | 800 B average |
| retention | `max_age: 72h` |
| replicas | 3 |
| account | un-tiered |

**Messages retained:** `500 msg/s × 72 h × 3600 s/h` = **129,600,000** messages.

**Payload bytes:** `129,600,000 × 800 B` = 103,680,000,000 B ≈ **96.6 GiB**. This is the number that
looks like the answer and is not.

**Record bytes:** the subject is `orders.created`, 14 characters, and there are no headers, so each
message costs `30 + 14 + 800` = **844 B**. `129,600,000 × 844` = 109,382,400,000 B ≈ **101.9 GiB** —
**5.5% more than the payload arithmetic**, and this is the figure `nats stream info`, `max_bytes` and
the account quota all use.

**Per node:** each of the three nodes stores the full stream once → **≈ 101.9 GiB per node**, plus
8 MB of never-compacted last block and a negligible `index.db` (one subject). Size the volume at
~112 GiB per node (`× 1.1 + 8MB`). A 10 GiB volume is off by an order of magnitude.

**Against the account quota:** un-tiered, so `replicas × bytes` = `3 × 101.9 GiB` ≈ **305 GiB** of
`MaxStore` — not the 290 GiB the payload arithmetic gives. An account provisioned at 300 GiB looks
like it fits and does not.

**`max_payload`:** 800 B average is far under the 1 MB default; no change needed.

**File descriptors:** one stream ≈ two FDs. Not a constraint here; it becomes one in the hundreds
of streams.

**The lesson of the example** is step 3. The disk arithmetic said 96.6 GiB per node and everything
looked fine; the account arithmetic said 290 GiB and the stream cannot be created at R3.

## Rules of thumb

Each with its source. Nothing here is inferred.

| rule | source |
|---|---|
| A message costs **`30 + len(subject)` bytes** on disk beyond payload and headers | [[s-nats-server-filestore-layout]] |
| The reported `bytes` **already include** that overhead; payload bytes are reported nowhere | [[s-nats-server-filestore-layout]] |
| Budget **one block size (usually 8MB) of slack per stream** — the newest block is never compacted | [[s-nats-server-filestore-layout]] |
| `index.db` costs **`len(subject) + 4` per distinct subject**, rewritten every 2 minutes | [[s-nats-server-filestore-layout]] |
| Size the volume at **`stream_bytes × 1.1 + 8MB per stream`**, never at `stream_bytes` | [[s-nats-server-filestore-layout]] |
| Overprovision CPU by **20–30%** above steady state | [[s-docs-sizing-and-resources]] |
| JetStream spends **~2 file descriptors per stream** | [[s-docs-sizing-and-resources]] |
| `max_memory_store` defaults to **75% of RAM**, `max_file_store` to **75% of available disk** | [[s-docs-sizing-and-resources]], verified [[s-nats-server-jetstream-resources]] |
| A stream's `max_bytes` is **reserved**, not measured — empty streams consume the ceiling | [[s-issue-4281-insufficient-storage]] |
| Never leave `max_file_store` unset in production; the dynamic value **shrinks at every restart** before 2.14.6 | [[s-issue-8322-dynamic-maxstore-shrinks]] |
| An un-tiered account charges **`replicas × bytes`** against `MaxStore` | [[s-docs-sizing-and-resources]] |
| Keep `max_pending` at **≥ 10× peak message size** | [[s-docs-sizing-and-resources]] |
| `max_payload`: **1 MB** default, **8MB** not recommended above, **64MB** hard ceiling | [[s-docs-connection-limits-config]] |
| R3 is **~3× the storage and write traffic** of R1 | [[s-docs-surviving-node-loss]] |
| Replicas **do not scale writes** — a higher count lowers peak write throughput | [[s-docs-surviving-node-loss]] |
| Memory follows **leadership and dedup window**, not message count | [[s-synadia-jetstream-memory-patterns]] |
| Keep total consumers **below ~100,000** | [[s-synadia-jetstream-anti-patterns]] |
| Keep disjoint subject filters **below ~300 per consumer** | [[s-synadia-jetstream-anti-patterns]] |

### Compression changes the disk term, and nothing else

`compression: s2` on a file-storage stream compresses whole message blocks on disk. It shrinks
**stored bytes only** — the account quota, the `max_bytes` reservation and the replica multiplier
are all computed from *logical* bytes, so compression does not buy you room against the ceilings in
*What runs out first*, only against the physical volume (source:
[[s-adr-35-filestore-compression]]).

Three things to know before you count on it:

- **The ratio depends on repetition between neighbouring messages**, not within one, because S2 is
  applied to a whole block. Structured payloads (JSON, protobuf text) compress well; images,
  archives and anything encrypted client-side do not.
- **The server publishes no compression ratio.** Measure it as `nats stream info` bytes against
  `du -sh …/streams/<name>/msgs` on a node holding the stream; there is no metric or endpoint field.
- **The CPU cost is unquantified in every public source.** ADR-35 says only that "a compressed
  stream may suffer some performance penalties". Budget for it, then measure.

See [[stream-compression]], including why changing the setting on a live stream does nothing until
its store restarts.


## What runs out first

Roughly in the order it bites:

1. **The account's `MaxStore`** — because of the `replicas × bytes` rule, this is hit at a third of
   the stream size you were planning for, and the symptom is a **placement failure**, not a disk
   alert.
2. **The server's `max_file_store` reservation** — `max_bytes` on a stream is counted as *used* the
   moment the stream exists, so the ceiling is reached by empty streams. A `/varz` dump in
   [[s-issue-4281-insufficient-storage]] shows **4 MB stored against 35 GiB reserved**. The symptom is
   `insufficient storage resources available (10047)` on the *next* create — see
   [[jetstream-out-of-disk]].
3. **Disk under `store_dir`** — the resource the docs single out as most likely to run out. The
   symptom of over-committing `max_file_store` is a **publish error mid-stream**, and of genuinely
   filling the device, `JetStream out of File resources, will be DISABLED` plus the
   `$JS.EVENT.ADVISORY.SERVER.OUT_OF_STORAGE` advisory.
   **`max_file_store` does not protect the volume**: it bounds the same logical figure everything
   else does. A server configured `max_file_store: 4MB` was measured holding **3.79 MB on disk while
   reporting 133,000 bytes used** — 3% of its own ceiling (source:
   [[s-nats-server-filestore-layout]]; recorded as docs issue #33). Setting it equal to the volume
   size, as the docs' own example does, leaves the volume unprotected. **The Helm chart does exactly
   that by default**: with `fileStore.maxSize` unset it renders `max_file_store` equal to
   `fileStore.pvc.size`, so a stock install has a 10Gi ceiling on a 10Gi volume
   (source: [[s-nats-helm-chart-values-2.14.6]]; the storage layout is on [[kubernetes-storage]]).
4. **The meta leader** — memory, and Raft/API load that scales with **consumer count** rather than
   message count. Not on every node, and not in proportion to traffic.
5. **File descriptors**, in the hundreds of streams, with a symptom that misleads: **connection
   refusals that look like a network fault**.
6. **CPU**, mostly during TLS handshakes and replication, and mostly visible as a node that cannot
   catch up after a rebalance.

**A note on where the disk comes from.** This page sizes the number; it does not choose the storage.
On Kubernetes the choice is settled — one PVC per replica on SSD-backed block storage, never NFS or
other shared file storage, because "most fast block based storage in the cloud only works with a
single host as a writer" (source: [[s-k8s-760-jetstream-pvc-per-replica]]), and never `hostPath`,
which turns a rescheduled pod into an empty replica
(source: [[s-gh-7749-hostpath-jetstream]]). Three replicas therefore cost three disks, which belongs
in the budget this page produces. The argument and the chart values are on [[kubernetes-storage]].

## How to measure it on a running system

```
nats account info                 # the live account ceilings: Memory, Storage, Streams, Consumers
nats server info <server>         # this node's Maximum Payload, Maximum Connections, JetStream limits
nats stream info <stream>         # the stream's LOGICAL size (record bytes) and its replica states
du -sb /var/lib/nats/jetstream/<account>/streams/<stream>/   # what the volume actually gave up
df -h /var/lib/nats/jetstream     # what the device says, which outranks what the config says
curl -s localhost:8222/varz | jq '.jetstream.stats | {storage, reserved_storage, memory, reserved_memory}'
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

**A `max_age` window is not a retention promise.** The three stream limits are independent and all
active, and the first one reached triggers the discard — so "a seven-day `MaxAge` does not guarantee
seven days of history. If traffic spikes, `MaxBytes` can be reached first and discard messages that
are only hours old" (source: [[s-docs-shaping-the-stream]]). If the age window is something you
promised someone, size `max_bytes` against **peak** traffic, not the average this page's worked
example uses. The same paragraph is the reason the sizing input on this page is a rate, not a total.

- **Sizing the volume from payload bytes.** Every stored message also carries 30 bytes and its
  subject. On 100-byte events that is 40% you did not budget; on 100 KB documents it is nothing.
- **Sizing the volume from the *reported* bytes.** That figure is a floor, not a ceiling — see
  Step 1b. `du` and `/jsz` will always disagree, and the gap is not a leak.
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
- **Sizing a problem that is not a sizing problem.** `has high message lag` looks like undersized
  disk or network and usually is not: a maintainer's answer to two independent reports is "you are
  sending faster then the system can process and store messages into the stream. This can happen if
  you use a core publish into a stream or if you use async Jetstream publishes with many publishers"
  (source: [[s-gh-6490-high-message-lag]]). Both causes **remove the backpressure a synchronous
  `PubAck` provides**, so no amount of hardware fixes them. Ask "did a publisher switch to core NATS
  or to async?" before you re-size anything — see [[stream-has-high-message-lag]].
- **Reaching for tmpfs to make the disk term go away.** A `store_dir` on a RAM disk is **not** a
  memory stream: a maintainer's response to streams whose directories had silently vanished under a
  tmpfs `store_dir` was "we don't support running the JetStream file store on RAM disks and cannot
  rely on RAM disks being anything other than temporary", naming a **memory** stream as the supported
  alternative and noting the server already does "in-memory caching of filestore blocks to help speed
  up accesses" (source: [[s-gh-5924-filestore-dirs-vanished]]). The related trap costs nothing to
  avoid: **with no `jetstream { store_dir }` set the default is under `os.TempDir()`**, exactly where
  `tmpwatch`, `tmpreaper`, `systemd-tmpfiles` and container image cleaners look. Set `store_dir`
  explicitly — see [[jetstream-out-of-disk]] and [[filestore-layout]].

## What is still unknown

Recorded here rather than guessed, because a wrong sizing number is the most damaging thing this
wiki could contain.

- ~~Per-message storage overhead~~ — **answered** (Q2): `30 + len(subject)` bytes per message in the
  record, `len(subject) + 4` per distinct subject in `index.db`, and up to one block size of
  never-compacted slack. Read at v2.14.6 and measured on the binary — Step 1 and Step 1b above, and
  [[filestore-layout]].
- **IOPS** — no public source read so far gives JetStream IOPS guidance (part of Q1). This is now
  the only unanswered term in Q1: disk, RAM, CPU and file descriptors all have numbers above.
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
[[jetstream-slows-as-consumers-grow]] · [[object-store]]

## Sources

[[s-docs-sizing-and-resources]] · [[s-synadia-jetstream-memory-patterns]] ·
[[s-docs-connection-limits-config]] · [[s-docs-surviving-node-loss]] ·
[[s-docs-replication-and-r3]] · [[s-docs-upgrade-to-2.12]] · [[s-synadia-jetstream-anti-patterns]] ·
[[s-nats-server-constants-2.14.6]] · [[s-docs-monitoring-endpoints]] ·
[[s-nats-server-jetstream-resources]] · [[s-issue-4281-insufficient-storage]] ·
[[s-issue-8322-dynamic-maxstore-shrinks]] · [[s-adr-35-filestore-compression]] ·
[[s-nats-server-systemd-units]] · [[s-nats-server-filestore-layout]] ·
[[s-nats-helm-chart-values-2.14.6]] · [[s-gh-7749-hostpath-jetstream]] ·
[[s-k8s-760-jetstream-pvc-per-replica]] · [[s-docs-shaping-the-stream]] ·
[[s-nats-server-object-store-observed]] · [[s-docs-object-store-chunking]] ·
[[s-docs-monitoring-profiling]] · [[s-gh-7483-varz-cpu-in-containers]] ·
[[s-nats-server-monitoring-observed]] · [[s-docs-hardening]] ·
[[s-gh-5924-filestore-dirs-vanished]] · [[s-gh-6490-high-message-lag]] · [[s-gh-4972-nak-with-delay-blocks]]
