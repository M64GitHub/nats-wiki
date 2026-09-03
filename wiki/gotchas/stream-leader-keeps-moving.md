---
title: "stream leader keeps moving"
type: gotcha
area: [jetstream, topology, monitoring]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-09-01
tags: [leader-election, leader-elected, quorum-lost, flapping, stepdown, overrun, heartbeat, lost-quorum, advisories, mqtt, 10008, 10071]
aliases: ["leader flapping", "leader elections keep happening", "stream leader changes", "leader_elected advisories", "NO quorum, stalled", "quorum loss after days"]
sources: [s-gh-7533-quorum-loss-mqtt, s-nats-server-jetstream-cluster, s-nats-server-kick-ldm-mqtt-session, s-docs-monitoring-advisories-and-events, s-docs-upgrade-to-2.14, s-relnotes-2.14.0, s-gh-6490-high-message-lag, s-nats-server-jetstream-log-warnings, s-nats-server-lame-duck, s-docs-scaling-and-peers, s-docs-rolling-upgrades, s-adr-61-meta-quorum-rescue, s-synadia-jetstream-memory-patterns, s-docs-replication-and-r3, s-k8s-760-jetstream-pvc-per-replica, s-docs-upgrade-to-2.12, s-docs-kubernetes, s-nats-server-raftz, s-relnotes-2.14]
created: 2026-09-01
updated: 2026-09-03
---

# "stream leader keeps moving"

A stream's leader changes when nobody asked it to — once, or every few minutes — and each change
costs a pause in writes, sometimes a `NO quorum, stalled` warning, and on the worst days a cluster
that stops processing until something restarts. This page ranks the reasons a leader moves and gives
the line or command that tells them apart. The consensus mechanics are on [[raft-in-nats]]; the
cluster-wide group whose loss makes everything else stall is [[meta-layer]].

## Symptom

**The advisory.** JetStream publishes
`$JS.EVENT.ADVISORY.STREAM.LEADER_ELECTED.<stream>` on every leader change of a replicated stream,
`…CONSUMER.LEADER_ELECTED.<stream>.<consumer>` for consumers, and `…STREAM.QUORUM_LOST.<stream>` /
`…CONSUMER.QUORUM_LOST.…` when a group loses its majority ([[advisories]]). Repeated
`LEADER_ELECTED` advisories for one stream are the cheapest sign of a flap — but the docs are careful:
the advisory "reports a flap, not its cause" (source: [[s-docs-monitoring-advisories-and-events]]).
**Advisories are published once and stored nowhere.** Catching a flap that happened overnight needs
a stream that was already capturing `$JS.EVENT.ADVISORY.>`; if you have none, create one now, before
the next occurrence.

**The log lines**, on the servers (source: [[s-nats-server-kick-ldm-mqtt-session]],
[[s-nats-server-jetstream-cluster]]):

```
[INF] JetStream cluster new stream leader for '$G > ORDERS'            # on the new leader
[INF] Transfer of stream leader for '$G > ORDERS' to 'n2'              # a deliberate move
[WRN] JetStream cluster stream '$G > ORDERS' has NO quorum, stalled     # the group lost its majority
[INF] JetStream cluster no metadata leader                             # the meta group did too
[WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
```

**The CLI.** `nats stream info ORDERS` shows a different `Leader:` from one call to the next, or an
empty one during an election, with `Replica: n2, outdated, not seen …` lines.

**From an application**, a flap looks like a publish that times out and then works, or — from the
MQTT bridge — the sequence gh#7533 reported on 2.12.1 after days of stable operation: session
persists failing with `wrong last sequence: 0 (10071)`, then connects failing with
`JetStream system temporarily unavailable (10008)`, then 5-second `MS` request timeouts on
`$MQTT.msgs.…`, then `consumer 'default > $MQTT_msgs > …' has NO quorum, stalled`, with a CPU and
memory spike at the same time (source: [[s-gh-7533-quorum-loss-mqtt]]). Read in order that is the
meta group, then the stream's group, then a consumer's group each losing quorum.

## Quick triage

```
nats stream info ORDERS                    # Leader, and whether replicas are current
nats server report jetstream               # meta leader; Online / Current / Lag per server
curl -s 'http://n1:8222/raftz?acc=<account>&group=<Cluster Group>'   # term, overrun, catching_up, peers
curl -s http://n1:8222/healthz?js-meta-only=true          # on every node
curl -s http://n1:8222/routez | jq '.routes[] | {remote_name, rtt, pending_size}'
grep -E 'new stream leader|Transfer of stream leader|NO quorum|high message lag|Resetting stream cluster state|Healthcheck failed|no metadata leader|Slow Consumer' nats-server.log
```

`/raftz` is the per-group counter: `term` climbing is the flap count, `overrun: true` is cause 2 about
to happen, `catching_up` and `last_seen` say who fell behind — note the filter is `acc`, not `account`,
and the group name is the `Cluster Group` from `nats stream info` (source: [[s-nats-server-raftz]]).

Two readings decide most cases. **Did a deliberate `Transfer of stream leader` line precede the
change?** Then somebody or something asked (cause 4). **Did `has high message lag` precede it?** Then
the leader was overrun (cause 2). Neither, and a `NO quorum` or `Healthcheck failed` line nearby,
means a peer went quiet (cause 1).

## Causes, ranked

### 1. A peer stopped answering for about ten seconds

The timing is fixed. A leader sends a heartbeat every **1 s**; a follower whose timer runs **4–9 s**
without one starts an election; a leader that has not heard from a majority within **10 s**, checked
on a **10 s** ticker, steps down and logs `NO quorum, stalled`. None of the four has a config key
(source: [[s-nats-server-jetstream-cluster]]). So anything that stops a server answering for ~10 s
moves every leadership it holds: a CPU or memory spike (the shape gh#7533 reported), a paused or
throttled container, a route that is saturated or was closed as a slow consumer, a disk stall long
enough to block the Raft write path.

**How to confirm.** `Healthcheck failed` lines on the survivors; `/routez` `rtt` climbing on the route
to the suspect peer — a route's `rtt` is measured on the route's own pings, unlike a client's, which
can be an hour old ([[monitoring-endpoints]]); a `Slow Consumer Detected` for a *route* in the healthy
servers' logs ([[slow-consumer-detected]]); CPU and memory graphs for the node that lost leadership.
On Kubernetes, a pod that was restarted by its liveness probe shows the same pattern from the
outside ([[monitoring-endpoints]]; source: [[s-docs-kubernetes]]).

**The fix** is capacity and isolation, not tuning. Leadership concentrates memory — a node holding
stream, consumer and meta leadership sat far above its peers in one measured cluster — so keep the
meta leader off nodes carrying high-volume streams and size for the leader's footprint, not the
average (source: [[s-synadia-jetstream-memory-patterns]]; [[jetstream-sizing]]). Give each replica
its own block storage; three replicas on one shared or network disk fail together and stall together
(source: [[s-k8s-760-jetstream-pvc-per-replica]]; [[kubernetes-storage]]). A **persistent**
`outdated … operations behind` on one replica points at that peer's disk or its route, not at the
stream (source: [[s-docs-replication-and-r3]]).

### 2. The leader was overrun, and stepped down on purpose (2.14+)

Since 2.14 a leader that detects it is falling behind — accepting entries faster than the group
commits and applies them — **steps down so a healthier peer can take over**. The docs call it "a
safety net for transient overload, not a substitute for adequate capacity", and add that if a
majority of peers are equally overloaded the cluster stays degraded (sources: [[s-docs-upgrade-to-2.14]],
[[s-relnotes-2.14.0]]).

**How to confirm.** `JetStream stream '<acc> > <stream>' has high message lag` **before** the leader
change — the threshold is 10,000 accepted-but-unapplied proposals on the leader, and the line is
rate-limited, so its frequency says nothing about severity. Then step the leader down yourself and
watch whether the lag follows the leader (a node problem) or stays with the stream (a workload
problem) (source: [[s-gh-6490-high-message-lag]]; [[stream-has-high-message-lag]]).

**The fix** is the sizing page: fewer async publishers without back-pressure, no core-NATS publishes
into a stream's subjects, or more capacity ([[jetstream-sizing]]).

### 3. The group is repairing itself

When an entry cannot be applied, the server calls `resetClusteredState`: it steps the node down,
stops or deletes the Raft state, and logs `Resetting stream cluster state for '<acc> > <stream>'`.
Messages are preserved except in the one `errFirstSequenceMismatch` case. The reset is *refused* in
four cases, two of them "server or account resources exceeded" — a capacity problem blocking the
repair (source: [[s-nats-server-jetstream-log-warnings]]; [[raft-in-nats]]).

**How to confirm.** The `Resetting stream cluster state` line; a `Critical write error` with **no**
reset following is [[malformed-or-corrupt-message]] instead.

**The fix.** If the reset was refused for resources, free them and it proceeds. Repeated resets on
one stream are a disk or corruption question, not a leadership one.

### 4. Someone asked for it

A deliberate move logs `Transfer of stream leader for '<acc> > <stream>' to '<server>'` and is a
*transfer*, not an election: the leader picks a peer heard from within 3 s and hands over in about
half a second (source: [[s-nats-server-jetstream-cluster]]). Things that ask:

- `nats stream cluster step-down` and `nats server cluster step-down` — and any automation that
  calls them.
- **Lame duck** on a node: it steps down **every** Raft group it leads before the client-drain timer
  starts (source: [[s-nats-server-lame-duck]]), so a rolling restart moves every leadership on each
  node in turn — which is why [[upgrade-a-cluster]] orders nodes and takes the meta leader last
  (source: [[s-docs-rolling-upgrades]]).
- **Scaling or moving replicas**: a new peer "changes the quorum right away" and the meta leader
  re-places evicted replicas, one change at a time (source: [[s-docs-scaling-and-peers]];
  [[rebalance-streams]]).

**How to confirm.** The `Transfer` line, or the timing against a deploy log.

**The fix.** None; this is expected. Alert on `QUORUM_LOST`, not on `LEADER_ELECTED`
([[advisories]]).

### 5. Membership is not what you think it is

Quorum counts **configured** peers, not live ones (source: [[s-adr-61-meta-quorum-rescue]]), and the
peer set changes in two ways nobody watches: a server you `peer-remove`d and left running **rejoins
after five minutes**, and a server you switched off without removing keeps counting against the
majority (source: [[s-nats-server-jetstream-cluster]]; [[meta-layer]]). A group whose size keeps
changing keeps electing.

**How to confirm.** `/jsz` `meta_cluster.cluster_size` and the rows of `nats server report
jetstream` over time; `Online: false` rows that never go away.

**The fix.** Peer-remove servers when you retire them, and stop or reconfigure a removed server
inside the five-minute window ([[disaster-recovery]]).

### 6. Before 2.12: a fresh replica could win

2.12 added "better protection against leader elections based on empty state" during scale-up and
reset — before it, a peer with an empty log could take leadership and the group would reset around
it (source: [[s-docs-upgrade-to-2.12]]; [[nats-server-2.12]]).

**How to confirm.** `nats-server --version` below 2.12. **The fix.** Upgrade.

## What this page cannot tell you

**gh#7533 — a quorum loss after days of stable operation — was never answered.** The thread had no
reply when it was read on 2026-09-01. The wiki can map each line of its sequence to a mechanism:
`10008` is a server that believes the meta group leaderless; the 5-second `MS` timeouts are a
stream group that cannot commit; `NO quorum, stalled` is a consumer group that lost its majority
(source: [[s-nats-server-jetstream-cluster]]). The first line is the one it cannot explain:
`wrong last sequence: 0 (10071)` means the session record the server had written at sequence 40344
was no longer in `$MQTT_sess` — the stream's stored state had gone backwards *before* the quorum
loss — and what caused that on 2.12.1 is not established anywhere public (source:
[[s-gh-7533-quorum-loss-mqtt]], [[s-nats-server-kick-ldm-mqtt-session]]; [[mqtt]]).

## Prevention

- **Capture advisories.** A stream on `$JS.EVENT.ADVISORY.>` is the only way to know *when* the first
  election happened and which group went first.
- **Alert on `QUORUM_LOST`**, log `LEADER_ELECTED`.
- **Keep meta leadership off busy nodes**, and read the leader's memory, not the average.
- **One block volume per replica**, never a shared or network filesystem.
- **On Kubernetes**, a StatefulSet with per-pod volumes, resource requests that survive the spike,
  and the three-probe gradient — the liveness probe must ask the *least* or a recovering pod is
  restarted mid-catch-up (source: [[s-docs-kubernetes]]; [[monitoring-endpoints]]).
- **Run 2.14 or newer**: overrun protection turns a runaway leader into a stepdown you can see, and
  a node that refuses to start on a corrupt snapshot is a safety, not a fault ([[nats-server-2.14]]).

## Explained by

[[raft-in-nats]] (elections, the write path, overrun protection) · [[meta-layer]] (the group whose
loss stalls creates cluster-wide, the timing constants, the five-minute rejoin)

## Version notes: the 2.14 line

- **2.14.0**: "Raft nodes will step down if overrun" (#7853) — a new, *deliberate* cause of a
  leader moving: a leader whose proposals outrun commit and apply steps down so a healthier peer
  takes over, and the guide adds that if a majority are equally overloaded the group stays degraded
  (source: [[s-relnotes-2.14]]). On 2.14 a leader that moves under sustained publish load with
  `high message lag` beside it is this before it is anything in the ranked list above.
- **2.14.2**: peers tracked after an inactivity stall during catch-up (#8226); peer-set drift after
  peer-removing an online node (#8258) — the five-minute rejoin's neighbour. **2.14.3**: nodes stop
  voting and campaigning after write errors (#8290). **2.14.4**: elections ignore votes from removed
  peers (#8353); proposals carry the term, "preventing situations where stale proposals from a
  previous term could make changes in a new term after a fast election" (#8370). **2.14.6**: a
  signalling issue that could stall catch-ups, and a stale snapshot from a previous Raft group with
  the same name (#8501).


## Related

[[stream-has-high-message-lag]] · [[malformed-or-corrupt-message]] · [[slow-consumer-detected]] ·
[[advisories]] · [[monitoring-endpoints]] · [[jetstream-sizing]] · [[kubernetes-storage]] ·
[[upgrade-a-cluster]] · [[rebalance-streams]] · [[disaster-recovery]] · [[replicas]] · [[mqtt]] ·
[[evict-a-sick-server]]

## Sources

[[s-gh-7533-quorum-loss-mqtt]] · [[s-nats-server-jetstream-cluster]] ·
[[s-nats-server-kick-ldm-mqtt-session]] · [[s-docs-monitoring-advisories-and-events]] ·
[[s-docs-upgrade-to-2.14]] · [[s-relnotes-2.14.0]] · [[s-gh-6490-high-message-lag]] ·
[[s-nats-server-jetstream-log-warnings]] · [[s-nats-server-lame-duck]] ·
[[s-docs-scaling-and-peers]] · [[s-docs-rolling-upgrades]] · [[s-adr-61-meta-quorum-rescue]] ·
[[s-synadia-jetstream-memory-patterns]] · [[s-docs-replication-and-r3]] ·
[[s-k8s-760-jetstream-pvc-per-replica]] · [[s-docs-upgrade-to-2.12]] · [[s-docs-kubernetes]] · [[s-nats-server-raftz]] · [[s-relnotes-2.14]]
