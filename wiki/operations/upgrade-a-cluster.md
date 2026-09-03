---
title: Upgrade a cluster
type: operation
kind: runbook
area: [deploy, jetstream, topology]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-09-01
tags: [rolling-upgrade, lame-duck, SIGUSR2, meta-leader, downgrade, PodDisruptionBudget, ldm]
aliases: [rolling upgrade, "upgrade NATS", "roll a cluster", lame duck, ldm, "upgrade nats-server"]
sources: [s-docs-rolling-upgrades, s-nats-server-lame-duck, s-nats-server-signals, s-nats-helm-chart-values-2.14.6, s-docs-upgrade-to-2.12, s-docs-upgrade-to-2.14, s-nats-server-systemd-units, s-docs-scaling-and-peers, s-gh-4342-memory-stream-backup, s-issue-8322-dynamic-maxstore-shrinks, s-adr-40-nats-connection, s-gh-7463-jetstream-corruption, s-nats-server-jetstream-cluster, s-relnotes-2.10, s-gh-6748-cve-binary-release-docker-images, s-relnotes-2.11, s-relnotes-2.12]
created: 2026-08-31
updated: 2026-09-03
---

# Upgrade a cluster

Roll a new `nats-server` version through a cluster **one node at a time**, with clients reconnecting
on their own and no stream losing quorum. Two things make it safe: **lame-duck mode**, which is how a
node leaves, and the **order**, which is non-leaders first and the meta-leader last (source:
[[s-docs-rolling-upgrades]]).

## Goal

Every node on the new version, with:

- no client disconnected without somewhere to go;
- no stream below quorum at any point;
- exactly **one** metadata election, at the end, lasting about a second rather than 5–10.

## Preconditions

- **Read the upgrade guide for the hop you are making.** The version-specific hazards are not in this
  runbook because they are not general — see *Version hazards* below.
- **Know your downgrade floor before you start.** For 2.11 → 2.12 it is **v2.11.9**: "only downgrade
  to v2.11.9 or higher", because from that version a server recognises 2.12 features and puts the
  affected asset into an unsupported/offline mode instead of misreading it (source:
  [[s-docs-upgrade-to-2.12]]).
- **A backup**, or a deliberate decision not to have one ([[backup-and-restore-jetstream]]).
- **Find your R1 memory streams first — a roll destroys them.** There is no backup path for a memory
  stream at all (`nats stream backup` cannot snapshot one), so a maintainer's answer to "can a memory
  stream be backed up?" is the procedure instead: "If you run the stream as an R3 and do rolling
  restarts and `/healthz` checks it will survive." For one that is R1 today, the controlled sequence
  is: "before the restart update the stream's configuration to set `replicas=3`, check using
  `nats stream info` that all the new replicators have caught up, restart your server and then update
  the stream's configuration back to `replicas=1`" — with the boundary stated plainly, "if it's
  fault-tolerance you need (unscheduled server restart) then you must use `replicas=3`"
  (source: [[s-gh-4342-memory-stream-backup]]). `nats stream find --replicas=1` lists the candidates.
  This is the same catch-up gate as step 3, and it makes the restart a no-op only for a *planned* one.
  If the stream must also survive into an archive, mirror it into a file-backed stream and snapshot
  that ([[mirrors-and-sources]]).
- **Every stream at full replica count and every replica `current`.** A roll that starts one replica
  short spends the whole procedure one failure from quorum loss.
- **A service unit whose `ExecStop` sends SIGUSR2**, or you are signalling by hand
  ([[install-nats-server]]).
- On Kubernetes: a **PodDisruptionBudget**, and `terminationGracePeriodSeconds` large enough for the
  drain (both below).

## Steps

### 1. Read the cluster before you touch it

```
nats server list                    # every node, its version, and that all are up
nats server report jetstream        # which node leads the META group
nats stream info ORDERS             # per stream: Replicas, Leader, and each peer current/outdated
```

The `Cluster` block of `nats stream info` is the gate you will re-read after every node:

```
Replicas: 3
Leader:   nats-1
Replica:  nats-0, current, ...
Replica:  nats-2, current, ...
```

> "Every replica must read `current` before you take the next node down."

**The meta group and each stream's group are different Raft groups with different leaders**
([[raft-in-nats]]), so both commands are needed: `nats server report jetstream` finds the
meta-leader, `nats stream info` finds each stream's.

### 2. Order the nodes: non-leaders first, meta-leader last

Stepping the meta-leader down forces a metadata election, and **while it runs, stream and consumer
operations — create, update, leadership moves — pause**: about **5 to 10 seconds** if the node was
killed outright, or **roughly a second** if it handed leadership off first (source:
[[s-docs-rolling-upgrades]]; the 4–9 second election timer behind those numbers is on
[[raft-in-nats]]).

Doing the non-leaders first means that by the time you reach the meta-leader, the nodes ready to take
over are already on the new version, and the one unavoidable election happens **once**, briefly, at
the end.

### 3. Per node: drain, restart, wait

```
# 1. drain — enter lame-duck mode
systemctl stop nats-server                     # the shipped unit's ExecStop sends SIGUSR2
# or, signalling directly:
nats-server --signal ldm
kill -SIGUSR2 $(cat /var/run/nats/nats.pid)

# 2. new binary
systemctl start nats-server

# 3. gate — do not continue until this node reads "current"
nats stream info ORDERS
```

**What the drain does**, in order: logs `Entering lame duck mode, stop accepting new clients` and
closes the client listener so no new connection lands on a node that is leaving; **steps down every
Raft group it leads** and marks them observers; shuts JetStream and the Raft nodes down cleanly;
broadcasts `INFO ldm:true`; waits `lame_duck_grace_period`, logs `Closing existing clients`, and
closes the remaining connections at randomised intervals. Only then does the process exit.

**Clients need no changes and take no action on the broadcast.** They keep using the connection they
have; the node stops accepting new ones; when their connection is finally closed, ordinary reconnect
logic dials another node. That is why the *duration*, not the INFO, controls how spread out the
reconnects are.

**The two timing keys** (defaults from [[defaults-and-limits]], both restart-only —
[[config-keys]]):

```
lame_duck_grace_period: "10s"     # default 10s — the wait before clients start being closed
lame_duck_duration: "2m"          # default 2m, minimum 30s — the window they are spread over
```

The grace period must be **strictly** shorter than the duration — the server refuses to start
otherwise, with `lame duck grace period (…) should be strictly lower than lame duck duration (…)`;
and a duration under `30s` is rejected at parse time (source: [[s-nats-server-lame-duck]]).

**What the duration actually governs — and what it does not.** Read from the implementation
(`server.go:4439–4565`), the drain does the JetStream work **first**, before the timer exists:

- Raft leadership is stepped down on **every** group this node holds and each becomes an observer,
  with a **fixed one-second wait** — not a wait bounded by `lame_duck_duration`;
- JetStream and the Raft nodes are then shut down;
- **only then** is the close schedule computed, the INFO sent, the grace period waited out, and the
  clients closed.

So the duration is **the window over which client connections are closed, and nothing else**. Two
consequences the docs do not state:

- the spread window is **`lame_duck_duration` − `lame_duck_grace_period`**, not the full duration;
- **the interval between closes is capped at one second**, so ten clients drain in about ten seconds
  whatever the duration says. A node with **no** clients exits immediately — which is why a drain can
  look like it did nothing (source: [[s-nats-server-lame-duck]], and the maintainer's answer in
  [[s-gh-6070-lame-duck-under-systemd]]).

Size the duration against **your client count and how fast they reconnect**. Sizing it against
JetStream catch-up does not work, because that is not what it waits for — the gate in step 3 is what
protects the stream.

### 4. Pick the right signal

`nats-server --signal <name>` does not map to names the way a service manager does (source:
[[s-nats-server-signals]], read from `server/signal.go` at v2.14.6):

| you want | signal | `--signal` name |
|---|---|---|
| **drain, then exit** | `SIGUSR2` | `ldm` |
| stop now, no drain | `SIGINT` | `quit` |
| reload config | `SIGHUP` | `reload` |
| re-open the log file (rotation) | `SIGUSR1` | `reopen` |
| **`stop`** | **`SIGKILL`** | `stop` — **not a graceful stop** |

`SIGTERM` shuts the server down **unless a drain is already running**, in which case it is ignored —
which is what lets the Kubernetes lifecycle work.

Every one of them is logged before it acts: `Trapped "user defined signal 2" signal`.

### 5. Kubernetes

The chart wires the drain into the pod's `preStop` hook, so `kubectl rollout restart` triggers it:

```yaml
lifecycle:
  preStop:
    exec:
      command: ["nats-server", "-sl=ldm=/var/run/nats/nats.pid"]
```

Kubernetes then sends SIGTERM, **which the draining server ignores** — so the drain is bounded only
by `terminationGracePeriodSeconds`, after which the kubelet sends SIGKILL, which nothing can catch.

The chart's defaults sit **exactly** on its own rule (source:
[[s-nats-helm-chart-values-2.14.6]]):

```yaml
config:
  lameDuckGracePeriod: 10s
  lameDuckDuration: 30s          # the server's documented minimum
podTemplate:
  terminationGracePeriodSeconds: 60   # = 10 + 30 + 20s shutdown overhead
```

**There is no slack.** Raise `lameDuckDuration` and you must raise
`terminationGracePeriodSeconds` with it, or SIGKILL lands inside the drain.

And cap concurrent disruption so an autoscaler or a node drain cannot take two pods at once:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nats
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: nats
```

## Verify

After **each** node:

```
nats stream info ORDERS        # this node back as a replica, reading "current", lag 0
nats server list               # the node is back, with its new Version
```

After the **last** node:

```
nats server list               # every row on the new version
nats server report jetstream   # a meta-leader exists, on an upgraded node
nats stream info ORDERS        # Replicas at full count, a named Leader, every peer current
```

Proving it end to end, as the docs do: leave a subscriber and a publisher running through the whole
roll —

```
nats sub "orders.created"
nats pub orders.created '{"order_id":"ord_8w2k"}'
```

The subscriber logs a reconnect when its node drains and keeps printing; the publish still lands,
because the two nodes still up hold a quorum.

## Rollback

**Downgrading is a version-specific question, not a general one.** Two rules from the guides read so
far:

- **2.12 → 2.11: only to v2.11.9 or higher.** Below that floor a server does not recognise 2.12
  features and will not safely offline the assets that use them (source: [[s-docs-upgrade-to-2.12]]).
- **Stream state files are rebuilt on the first restart after a 2.12 → 2.11 downgrade**, which
  re-scans every message block: higher CPU and a longer wait before the node reports healthy. It
  **does not lose data** and happens only once.
- **2.14 → 2.12: remove `feature_flags` from the config first** — older servers do not recognise the
  field. Sourcing or mirroring may not function until every server is downgraded, and durable
  consumers created with `AckFlowControl` are **marked offline and unusable** until upgraded back
  (source: [[s-docs-upgrade-to-2.14]]).

Roll a downgrade the same way as an upgrade — drain, restart, gate on `current`.

## Version hazards

The per-hop hazards live on the release pages; these are the ones an upgrade can trip over:

| hop | what to know | source |
|---|---|---|
| any | `Invalid JetStream request … unknown field "sourcing"` is **expected** mid-roll and resolves once every server is on one version | [[s-docs-upgrade-to-2.14]] |
| → 2.12 | **strict JetStream API on by default** — an invalid request now returns an error to the client instead of only logging. `jetstream { strict: false }` is the temporary escape | [[nats-server-2.12]] |
| → 2.12 | memory behaviour changes: elastic filestore pointers, RSS driven by `GOMEMLIMIT` | [[s-docs-upgrade-to-2.12]] |
| → 2.14 | **filestore I/O errors now freeze the affected stream** and surface in health checks; recovery needs a restart. Other streams keep running, and a replica takes over | [[nats-server-2.14]] |
| → 2.14 | **Raft overrun protection**: an overloaded leader steps down. If a majority are equally overloaded the cluster stays degraded — it is a safety net, not capacity | [[raft-in-nats]] |
| → 2.15 | `$JS.ACK` / `$JS.FC` **v2 subject format becomes the default**. Imports, exports or permissions naming `$JS.ACK.<stream>.>` must be updated first; opt in early with `feature_flags { js_ack_fc_v2: true }` | [[nats-server-2.15-preview]] |

**There is no 2.13** — 2.14 is the direct successor of 2.12 ([[nats-server-2.14]]).

**Upgrading is also the project's own answer to an old cluster misbehaving.** Asked about R3
WorkQueue streams on **2.9.8** whose Raft WAL had gone corrupt — with no resource pressure behind it
(20 days up, 6–7% of 200 GB used, 1.3 GB of a 2 GB memory limit) and where deleting the PVC and
resyncing from the healthy replicas **reproduced** the corruption — a maintainer's whole reply was:
"2.9.x is now very old, unsupported and 100s of bug fixes behind, we have invested a lot of time on
the storage layer since… You need to upgrade to 2.12.x." The asker upgraded and reported the problem
gone (source: [[s-gh-7463-jetstream-corruption]]). If you are rolling a cluster several minors behind,
treat the upgrade itself as the remedy rather than something to schedule after the investigation. See
[[nats-server-2.12]] and [[disaster-recovery]].

### The 2.10 line

From the 29 release bodies (source: [[s-relnotes-2.10]]):

- **Downgrade floor 2.9.22.** 2.10 changed the on-disk format: "if a downgrade from 2.10.x occurs,
  the old version will not understand the format on disk with the exception 2.9.22 and any
  subsequent patch releases for 2.9" (v2.10.0, v2.10.1 and v2.10.2 bodies). 2.10.5 then removed meta
  files left by the 2.9 → 2.10 conversion (#4733).
- **2.10.16 can panic at startup** on zero-byte `tav.idx` files left by a crash before a sync;
  delete them before starting, or run 2.10.17, which "avoid[s] panic on corrupted TAV file" (#5464).
- **2.10.19 → 2.10.20 → 2.10.22**: 2.10.19 broke KV compare-and-swap on R1 (fixed in 2.10.20) and
  stopped clipping source-consumer start sequences (reverted in 2.10.22) — skip those three releases
  if anything sources or mirrors.
- **2.10.28 is withdrawn** — "contains a regression that has since been fixed in 2.10.29. Please
  upgrade to that version instead." With 2.11.2 that makes two withdrawn patches in two lines: read
  the body before picking a patch.
- **A CVE can ship as binaries first** — `v2.10.27-binary` a week before `v2.10.27`, the Docker
  image on its own queue (source: [[s-gh-6748-cve-binary-release-docker-images]]); see
  [[install-nats-server]].
- **From 2.10.28 a peer-removed server rejoins by itself after five minutes** (#6815).


### The 2.11 line

From the 18 release bodies (source: [[s-relnotes-2.11]]):

- **2.11.2 is withdrawn** ("contains a regression that has since been fixed in 2.11.3"); its
  consumer-consistency change — replicated consumers wait for quorum before delivering — is the one
  with the throughput caveat, and it stays in every later 2.11.
- **2.11.0 and 2.11.1 on an upgraded standalone server**: idempotent stream and consumer creates
  "fail due to metadata changes" until #6716 (2.11.2, so effectively 2.11.3).
- **2.11.0 – 2.11.5 run filtered consumers slowly** — "a performance regression introduced in v2.11.0
  which could result in abnormally low throughput from filtered consumers and higher GC pressure",
  fixed in 2.11.6 (#7015). Do not benchmark a 2.11 cluster below 2.11.6.
- **2.11.4 refuses stream and consumer updates when all peers are offline** (#6856); earlier 2.11
  accepted them, "a potential avenue for data loss".
- **2.11.9 is the floor for any 2.12 rollback** (offline assets, #7158) — see the table above.
- **Names with spaces are rejected from 2.11.0** for servers, clusters and gateways (#5676); a config
  that started on 2.10 can fail to start on 2.11.
- **A graceful `SIGTERM` exits 0 from 2.11.0** (#6336; 2.11.10 fixes it at startup, #7367) — a unit
  or supervisor that treated the old exit 1 as a failure sees a change.
- **2.11.14 – 2.11.16 close twelve CVEs**; 2.11.16's `no_auth_user` is client-only and `deny`
  wildcards are enforced strictly — a config relying on either loophole breaks on upgrade.


### The 2.12 line

From the 15 release bodies (source: [[s-relnotes-2.12]]):

- **2.12.5 carries a warning, not a withdrawal**: "a stream update may result in the loss of
  consumers in clustered deployments in specific cases. Single-server deployments are not affected.
  To temporarily mitigate, set `meta_compact_sync: true` in the `jetstream` config block and perform
  a configuration reload." Fixed in 2.12.6 (#7939). A cluster on 2.12.5 must carry the mitigation
  until it moves.
- **2.12.7 – 2.12.10 have a stale-subject-state regression** — `Message Not Found` on streams with
  `max_msgs_per_subject` (every KV bucket) — fixed in 2.12.11 (#8285); "v2.14.x versions are not
  affected".
- **2.12.15 fixes a data-loss path** in idempotent stream creates "when an offline node catches up
  from a metalayer snapshot" (#8449); 2.14.5 is its twin.
- **The 2.11 → 2.12 hop changes defaults**, not only features: strict API on, async flush on for
  replicated streams, `max_buffered_msgs` ×10, WebSocket and MQTT keepalives off, insecure cipher
  suites off (`allow_insecure_cipher_suites` restores them), API level 2 (clients asserting a level
  with `Nats-Required-Api-Level` now can).
- **Counters, compression or encryption: 2.12.12 or later** (#8311, #8312); **`verify_and_map` or
  `no_auth_user` with auth callout: 2.12.14 or later** (the two authentication bypasses).
- **`max_mem_store` and `max_file_store` may be raised by config reload from 2.12.7** (#8014) — a
  storage grow no longer needs a restart, but a shrink still does.


## Pitfalls

**Do not size `lame_duck_duration` against JetStream.** The docs advise setting it to cover "how long
JetStream needs to move leadership off this node", and warn that a short duration means the node
"kicks its clients and exits while the stream is still catching up". The implementation orders the
work the other way round: stepdown and JetStream shutdown complete **before** the client-close timer
starts, with a fixed one-second wait of their own. A longer duration buys client reconnects more
room and buys JetStream nothing (source: [[s-nats-server-lame-duck]]; recorded as
`inbox/docs-issues.md` #13). **What protects the stream is the gate in step 3** — not continuing
until every replica reads `current`.

**Restarting the meta-leader without draining it stalls every stream and consumer operation** for the
election window. Always drain; always do the meta-leader last.

**Two nodes down costs an R3 stream its quorum**, and nothing stops a cluster autoscaler, a node
drain or a careless `kubectl delete` from doing it. A `PodDisruptionBudget` makes the rule
enforceable instead of procedural.

**A reconnect storm comes from abrupt kills, not from lame-duck.** The staggered close is what
spreads the reconnects; killing a node outright, or setting the duration so short the spread
collapses, is what produces the burst.

**Do not reload config mid-roll.** A SIGHUP while JetStream is moving replicas or handing off
leadership competes with that work — wait for the cluster to settle
([[reload-server-config]], source: [[s-docs-config-management]]).

**Do not stack membership changes onto an upgrade.** A roll is already a sequence of one-node
changes; adding a `peer-remove` or a `--replicas` edit while a node is catching up is how a group
loses quorum ([[rebalance-streams]]).

**`--signal stop` is `SIGKILL`.** The name is the trap; `ldm` is the drain.

**A restart can come back with a smaller JetStream ceiling than the data it already holds.** With no
explicit `max_file_store`, the file-storage limit is computed as **75% of what is *free* under
`store_dir` at startup** — not 75% of the volume — so every byte JetStream itself has written lowers
the next start's ceiling. It is invisible in testing and appears the first time a loaded server is
restarted, which is usually an upgrade (source: [[s-issue-8322-dynamic-maxstore-shrinks]]). **Pin
`max_file_store` to the volume** before the roll, and never write `max_file_store: 0` to mean "no
limit" — it disables file storage. See [[jetstream-sizing]] and [[jetstream-out-of-disk]].

**Clients can stay silent for about four minutes after a node dies.** A default client notices a
server that stopped answering only after two missed pongs on a two-minute ping interval — roughly
**four minutes** — unless the socket errors first (source: [[s-adr-40-nats-connection]]). That is why
the drain matters: lame-duck closes connections in a staggered way and the clients move immediately,
where an abrupt kill leaves some of them waiting out that window before they even start reconnecting.
Reconnect behaviour after that is bounded by client defaults you do not control, so a node that goes
down hard still delivers all of its clients to the survivors at once
([[how-clients-reach-a-cluster]]).

## What the meta leader does on shutdown, from the source

Two facts from `jetstream.go` and `raft.go` at v2.14.6 that explain the ordering above (source:
[[s-nats-server-jetstream-cluster]]; [[meta-layer]]): on a clean shutdown a **meta leader transfers
leadership itself** — it calls the group's stepdown, which hands over to a peer heard from within 3 s
without an election, and waits up to 2 s for that to complete — which is why a drained meta leader costs
about a second and a killed one 4–9 s (measured: 0.5 s for a stepdown, 3.5 s after a `kill -9`). And a
follower that restarts **learns the leader from the next heartbeat** rather than voting (measured:
0.55 s from `recovering state` to `new metadata leader`), so the only election in a well-ordered
rolling restart is the last node's.


## Related

[[install-nats-server]] · [[build-a-3-node-cluster]] · [[reload-server-config]] ·
[[rebalance-streams]] · [[raft-in-nats]] · [[replicas]] · [[nats-helm-charts]] · [[config-keys]] ·
[[defaults-and-limits]] · [[monitoring-endpoints]] · [[nats-server-2.14]] · [[nats-server-2.12]] ·
[[nats-server-2.15-preview]] · [[backup-and-restore-jetstream]] · [[malformed-or-corrupt-message]] ·
[[jetstream-out-of-disk]]

## Sources

[[s-docs-rolling-upgrades]] · [[s-nats-server-lame-duck]] · [[s-nats-server-signals]] ·
[[s-nats-helm-chart-values-2.14.6]] ·
[[s-docs-upgrade-to-2.12]] · [[s-docs-upgrade-to-2.14]] · [[s-nats-server-systemd-units]] ·
[[s-docs-scaling-and-peers]] · [[s-gh-4342-memory-stream-backup]] ·
[[s-issue-8322-dynamic-maxstore-shrinks]] · [[s-adr-40-nats-connection]] ·
[[s-gh-7463-jetstream-corruption]] · [[s-nats-server-jetstream-cluster]] · [[s-relnotes-2.10]] · [[s-gh-6748-cve-binary-release-docker-images]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]]
