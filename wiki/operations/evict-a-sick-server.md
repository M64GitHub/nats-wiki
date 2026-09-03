---
title: Evict a sick-but-not-dead server
type: operation
kind: runbook
area: [topology, deploy, core, jetstream]
verified-against: nats-server 2.14.6
verified-on: 2026-09-01
tags: [evict, sick-node, hardware-failure, kick, lame-duck, peer-remove, slow-consumer, system-requests, kubernetes]
aliases: [remove a server from a cluster, kick clients off a server, evict a node, sick node, hardware failure]
sources: [s-gh-6892-evict-a-sick-node, s-nats-server-kick-ldm-mqtt-session, s-nats-server-jetstream-cluster, s-nats-server-lame-duck, s-docs-kubernetes, s-adr-61-meta-quorum-rescue, s-docs-scaling-and-peers, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12]
created: 2026-09-01
updated: 2026-09-03
---

# Evict a sick-but-not-dead server

A server that is up but unhealthy — CPU pinned, disk stalled, nobody able to log in — is worse than
a dead one: its peers may already have dropped it, but its clients have not, and every leadership it
holds is a leadership that flaps. This runbook takes such a server out of a cluster from the
outside, in the order that helps most, and says plainly which part **cannot** be done from outside.
The question it answers was asked in gh#6892 and never answered there (source:
[[s-gh-6892-evict-a-sick-node]]).

## Goal

Move JetStream leadership and assets off the server, remove it from the meta group, get its clients
onto healthy servers, and stop it — using only system-account requests and the platform.

## Preconditions

- **System-account credentials** for `nats` (`--server nats://<user>:<pw>@<healthy-server>`).
- The server's **name and id**: `nats server list` shows both name and, in `Slow`, whether the
  healthy servers have counted it as a slow consumer; `/varz` on any server gives its own `server_id`.
- An idea of **whether it still processes system requests**. Everything in the *nats CLI* section
  that touches a client is executed **by the sick server itself** — a saturated server may take
  seconds or never (source: [[s-nats-server-kick-ldm-mqtt-session]]).
- A **meta leader with quorum** on the healthy side, or the peer-remove step will not answer
  ([[meta-layer]]).

## Steps

### nats CLI

**1. See what it holds.**

```
nats server list                              # Conns, Routes, Slow, RTT per server
nats server report jetstream                  # meta leader (*), and the RAFT Meta Group table
nats stream report                            # which streams it leads
nats server request connections --subscriptions   # every server answers; read server.name per reply
```

**2. Move leadership off it, if it still answers.** A stepdown is a transfer to a peer heard from
within 3 s and takes about half a second (source: [[s-nats-server-jetstream-cluster]]):

```
nats server cluster step-down --host <healthy-server>     # only if it is the meta leader
nats stream cluster step-down ORDERS                       # for each stream it leads
```

If it does *not* answer, skip this: its groups will elect around it within 4–9 s of its last
heartbeat, and it steps down from anything it leads about 10 s after it last heard a majority
([[raft-in-nats]]).

**3. Remove it from the JetStream meta group.** Executed by the healthy meta leader, one server at a
time, answered only after a quorum has the removal in its log (sources:
[[s-nats-server-jetstream-cluster]], [[s-docs-scaling-and-peers]]):

```
nats server cluster peer-remove <server-name> --force
```

The removed server — if it can still hear the group — logs `JetStream being DISABLED, our server was
removed from the cluster`, publishes `$JS.EVENT.ADVISORY.SERVER.REMOVED`, disables its own JetStream,
and the meta leader re-places every stream that had it. **This is undone by itself after five
minutes** if the server keeps running with its `cluster {}` block: step 5 must happen inside that
window (observed; source: [[s-nats-server-jetstream-cluster]]).

**4. Kick its clients — one at a time, and only through the sick server.** The only per-client
request that disconnects is `KICK`; it is served by the server named in the subject, so the request
reaches the sick server and nothing else can do it for it (source:
[[s-nats-server-kick-ldm-mqtt-session]]):

```
nats server request kick <cid> <server-id>
```

Observed on 2.14.6: the client sees `>>> Disconnected due to: EOF, will attempt reconnect` and is on
another server within a few seconds; an unknown cid answers
`{"error":{"code":500,"description":"no such client or leafnode id"}}`. The cids come from
`nats server request connections` (each reply names its server) or from `/connz` on the sick
server's monitor port if it still serves HTTP.

**Do not count on the lame-duck request.** `$SYS.REQ.SERVER.<server-id>.LDM` with `{"cid": <n>}`
(no CLI subcommand; send it with `nats req`) only sends the client an INFO with `ldm: true`; whether
it moves is the client library's decision, and nats CLI 0.4.0 (nats.go) stayed put (observed).

**There is no request that removes clients by IP, kicks every client of a server, or tells the
other servers to drop a route.** The per-server system requests at 2.14.6 are `KICK`, `LDM`,
`RELOAD` and the monitoring endpoints, nothing more (source:
[[s-nats-server-kick-ldm-mqtt-session]]). The route layer needs no help: the healthy servers close a
route that stops draining as a slow consumer on `write_deadline` ([[slow-consumer-detected]]), which
is what gh#6892's other servers had already done.

**5. Stop it.** With host access: `nats-server --signal ldm=<pid>` drains it properly — every Raft
group it leads is stepped down first, then clients are disconnected over `lame_duck_duration`
(source: [[s-nats-server-lame-duck]]; [[upgrade-a-cluster]]) — or a plain stop. Without host access,
the platform is the only lever (next section).

### server config

Nothing here evicts a server, but two keys decide how long the situation lasts. `write_deadline`
(default `10s`, [[config-keys]]) is how long a healthy server tolerates a route or client that does not
drain before closing it as a slow consumer. `ping_interval` / `ping_max` (`2m` / `2`) are the
**server's** pings to *its* clients — they do not make a client abandon a stalled server; that is the
client library's own ping (see *To verify*).

### Kubernetes / Helm

The liveness probe is the eviction: the Helm chart's `livenessProbe` asks
`/healthz?js-enabled-only=true`, deliberately the loosest question so a recovering stream never
triggers a restart loop — and a server whose JetStream is unhealthy fails it and is restarted by the
kubelet, which drops every client connection at once (source: [[s-docs-kubernetes]];
[[monitoring-endpoints]]). If the process is alive but the probe cannot run, deleting the pod has the
same effect, and the StatefulSet brings it back on its own volume. Step 3 above is still worth doing
first if the meta group has quorum without it, so the restarted pod comes back as a follower rather
than as a stale leader.

## Verify

```
nats server report jetstream          # the server is gone from the RAFT Meta Group table
curl -s http://<healthy>:8222/jsz | jq .meta_cluster.cluster_size     # one less
nats server list                       # its Conns column, or its row, gone
```

## Rollback

A server removed in step 3 and left running rejoins the meta group by itself after five minutes; a
stopped one, restarted with the same config, bootstraps a fresh meta state, follows the group, and
is re-added on the same timer (observed; source: [[s-nats-server-jetstream-cluster]]). Nothing has
to be undone by hand.

## Pitfalls

- **Peer-remove with no meta leader** answers `did not receive a response from the meta leader,
  ensure the account used has system privileges and appropriate permissions` — the credentials are
  fine; there is no leader. That is the [[disaster-recovery]] situation (source:
  [[s-adr-61-meta-quorum-rescue]]).
- **The five-minute rejoin.** A peer-remove is permanent only if the server is stopped or its
  `cluster {}` block removed within five minutes.
- **`KICK` is per connection and per server**, and the server must execute it. Against a truly
  saturated server, expect it to be slow or ignored — which is exactly gh#6892's case, and why the
  platform restart is the reliable half.
- **Clients leave on their own clock.** Until the socket closes or their own ping times out, clients
  keep using a stalled server; the "10+ minutes of slowness" in gh#6892 is that clock.

## Version notes

- **The five-minute rejoin is a 2.10.28 change**: "Servers that have been `peer-remove`'d can now be
  re-admitted automatically after 5 minutes without a server restart" (#6815, "Server peer re-add
  after peer-remove"). Before 2.10.28 a removed server stayed out until restarted (source:
  [[s-relnotes-2.10]]).
- **`$SYS.REQ.SERVER.<id>.KICK` and `.LDM` arrived in 2.10.0** (#4298); from 2.10.17 `KICK` also
  reaches leafnode connections (#5587). Neither is in the docs — `inbox/docs-issues.md` #54.
- **2.10.28 proposes the new peer set through the Raft layer** on a stream or consumer peer-remove,
  "potentially avoiding a drift in peers" (#6720, #6727).


### The 2.11 line

- **2.11.15**: "The stream peer-remove command now accepts a peer ID as well as a server name"
  (#7952) (source: [[s-relnotes-2.11]]).
- **2.11.12** hardened the removal itself: the meta layer answers a peer-remove only after quorum
  (#7581); the removed peer's state is written immediately so it "cannot unexpectedly reappear after
  a restart" (#7602); a heartbeat between removal and leadership transfer no longer re-admits it
  (#7649); removed peers are not counted towards quorum (#7589); **the last remaining peer cannot be
  removed** (#7610).


### The 2.12 line

**2.12.10**: "a drift that could occur in the peer sets after a peer remove of an online node"
fixed (#8258). **2.12.14**: "Raft elections now correctly ignore votes from removed peers" (#8353).
**2.12.6**: `peer-remove` by peer ID (#7952) (source: [[s-relnotes-2.12]]).


## To verify

- The client libraries' own ping interval and maximum outstanding pings — what decides how fast a
  client abandons a server that stops answering — were not read from any client source here. The
  server-side `ping_interval` / `ping_max` are the other direction.

## Related

[[meta-layer]] · [[raft-in-nats]] · [[stream-leader-keeps-moving]] · [[slow-consumer-detected]] ·
[[upgrade-a-cluster]] · [[disaster-recovery]] · [[rebalance-streams]] · [[monitoring-endpoints]] ·
[[config-keys]] · [[how-clients-reach-a-cluster]]

## Sources

[[s-gh-6892-evict-a-sick-node]] · [[s-nats-server-kick-ldm-mqtt-session]] ·
[[s-nats-server-jetstream-cluster]] · [[s-nats-server-lame-duck]] · [[s-docs-kubernetes]] ·
[[s-adr-61-meta-quorum-rescue]] · [[s-docs-scaling-and-peers]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]]
