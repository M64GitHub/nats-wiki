---
title: "docs.nats.io — Rolling upgrades"
type: summary
area: [deploy, jetstream, topology]
source-url: https://docs.nats.io/learn/deployment/rolling-upgrades.md
source-path: raw/nats-docs/learn/deployment/rolling-upgrades.md
author: NATS documentation (Synadia Communications, Inc.)
article: Rolling upgrades
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [rolling-upgrade, lame-duck, SIGUSR2, meta-leader, PodDisruptionBudget, preStop, ldm]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Rolling upgrades

The procedure for changing the binary under a live cluster: lame-duck mode for one node, and an
upgrade **order** across the three. The most procedurally complete page in the deployment chapter,
and the only source that states the order rule.

## Key claims

**Lame-duck mode is one signal and a five-step sequence.**

```
kill -SIGUSR2 $(cat /var/run/nats/nats.pid)
```

1. "It closes its client listener, so no *new* connection lands on a node that's on its way out."
2. "It transfers any Raft leadership it holds to another replica, so no stream is left leaderless."
3. "It shuts down its JetStream assets cleanly, flushing to disk."
4. "It broadcasts `INFO ldm:true` to its routes and its connected clients. The update drops this node
   from each client's server pool, so the next reconnect lands elsewhere; **the client takes no other
   action on the INFO itself**."
5. "After a short grace period it closes the remaining client connections, **spread over the
   lame-duck duration rather than all at once**."

"Only after that does the process exit."

**Two settings control the timing**, with defaults stated:

```
lame_duck_grace_period: "10s"      # default 10s — how long before it starts kicking clients
lame_duck_duration: "2m"           # default 2m, minimum 30s — the window the kicks are spread over
```

> "The grace period must be shorter than the duration."

and the sizing rule: "Set the duration to comfortably cover how long your clients take to reconnect
*and* how long JetStream needs to move leadership off this node."

**On Kubernetes the chart wires the signal into `preStop`:**

```yaml
lifecycle:
  preStop:
    exec:
      command:
        - "nats-server"
        - "-sl=ldm=/var/run/nats/nats.pid"
```

> "Kubernetes then sends SIGTERM, **which the server ignores while it's draining**, so the drain is
> protected only by `terminationGracePeriodSeconds`: when that expires the kubelet sends SIGKILL. The
> chart defaults `lame_duck_duration` to `30s` and `terminationGracePeriodSeconds` to `60s`."

(Both chart values confirmed at chart release **nats-2.14.6** —
[[s-nats-helm-chart-values-2.14.6]]. The SIGTERM claim is confirmed in the server source —
[[s-nats-server-signals]].)

**The upgrade order rule — the page's core claim:**

> "**Upgrade the non-leaders first, and the meta-leader last.**"

Because "one node in the cluster is the **meta-leader**: the Raft leader for the cluster's own
metadata … Stepping the meta-leader down forces a metadata election, and while that election runs,
stream and consumer *operations* (create, update, leadership moves) pause until a new leader wins —
typically about **5 to 10 seconds** with default timeouts if the node was killed outright, or
**roughly a second** if it handed leadership off first."

**Find the meta-leader:**

```
nats server report jetstream
```

**The per-node procedure is three steps**, and the third is a gate:

```
kill -SIGUSR2 $(cat /var/run/nats/nats.pid)   # 1. drain
systemctl restart nats-server                  # 2. new binary
nats stream info ORDERS                        # 3. wait for this node to read "current"
```

> "A restarted node isn't done until its `ORDERS` replica has caught up, because taking the next node
> down while this one is still syncing leaves the stream one healthy replica short."

The `Cluster` block is what you read:

```
Replicas: 3
Leader:   nats-1
Replica:  nats-0, current, ...
Replica:  nats-2, current, ...
```

> "Every replica must read `current` before you take the next node down."

**A PodDisruptionBudget makes the rule enforceable on Kubernetes:**

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

**Clients need no changes.** "A node leaving in lame-duck mode requires no action from a correctly
configured client" — the INFO fires an optional lame-duck callback, the node stops accepting new
connections, and when the staggered close comes the client's normal reconnect logic dials another
node.

**Four pitfalls:**

1. **"A `lame_duck_duration` shorter than the rebalance drops clients early."** 30s set, 45s needed →
   "the node kicks its clients and exits while the stream is still catching up. Measure how long a
   real drain takes on your cluster first."
2. **Upgrading the meta-leader without draining it stalls stream ops** for the 5–10s election.
3. **"Evicting pods without a PDB can drain all three at once"** — an autoscaler or a careless
   `kubectl delete`, and "two nodes down costs the R3 stream its quorum".
4. **"A reconnect storm comes from abrupt kills, not from lame-duck."** The staggered close is what
   spreads the reconnects; "the storm risk is what you get *without* that".

## Practical takeaways

- **The gate, not the drain, is what makes a roll safe.** Lame-duck mode protects the node you are
  taking down; re-reading `nats stream info` until the replica is `current` protects the *next* one.
- **The meta group and a stream's group are different Raft groups with different leaders**, so
  `nats server report jetstream` and `nats stream info` answer different questions and you need both
  ([[raft-in-nats]]).
- **The chart's `lame_duck_duration: 30s` is the documented minimum**, and this page's own advice is
  not to default to the minimum. On a cluster with real streams, raise both it and
  `terminationGracePeriodSeconds` together.
- **`INFO ldm:true` is advisory to clients.** They do not reconnect on it; they reconnect when the
  connection is closed. That is why the *duration* controls the reconnect spread.

## Notable quotes

> "Kubernetes then sends SIGTERM, which the server ignores while it's draining, so the drain is
> protected only by `terminationGracePeriodSeconds`."

> "A reconnect storm comes from abrupt kills, not from lame-duck."

## Relevance to the wiki

The whole of [[upgrade-a-cluster]], and the drain step [[install-nats-server]]'s `ExecStop` line
exists to trigger.

## Questions it answers

**Q63** (the procedure) and **Q93** in part; **Q64** needs the per-version upgrade guides
([[s-docs-upgrade-to-2.12]], [[s-docs-upgrade-to-2.14]]) alongside it.

## Pages touched

[[upgrade-a-cluster]] · [[install-nats-server]] · [[build-a-3-node-cluster]] · [[raft-in-nats]] ·
[[replicas]] · [[nats-helm-charts]] · [[config-keys]]
