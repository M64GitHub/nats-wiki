---
title: Upgrade a cluster
type: operation
kind: runbook
area: [deploy, jetstream, topology]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [rolling-upgrade, lame-duck, SIGUSR2, meta-leader, downgrade, PodDisruptionBudget, ldm]
aliases: [rolling upgrade, "upgrade NATS", "roll a cluster", lame duck, ldm, "upgrade nats-server"]
sources: [s-docs-rolling-upgrades, s-nats-server-lame-duck, s-nats-server-signals, s-nats-helm-chart-values-2.14.6, s-docs-upgrade-to-2.12, s-docs-upgrade-to-2.14, s-nats-server-systemd-units, s-docs-scaling-and-peers]
created: 2026-08-31
updated: 2026-08-31
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
[[s-docs-scaling-and-peers]]
