---
title: "nats-server v2.14.6 — the traffic counters, the leader-only consumer fields, and ha_assets"
type: summary
area: [monitoring, jetstream, core]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/traffic-counters-and-ha-assets-v2.14.6.md
author: The NATS Authors (Apache-2.0); extract by this wiki, 2026-09-03
date: 2026-08-27          # the v2.14.6 release date
version: "2.14.6"
tags: [in_msgs, out_msgs, in_bytes, counters, num_pending, ha_assets, max_ha_assets, varz, connz, consumer]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.14.6 — traffic counters, leader-only consumer fields, `ha_assets`

Three questions the metrics pages needed the server to answer: are the counters exact, why does a
follower report `num_pending: 0`, and what is an HA asset. Line numbers are at tag v2.14.6.

## Key claims

1. **The counters are exact, atomic, per server, and count payload bytes.** `processInboundClientMsg`
   adds one to `c.in.msgs` and `len(msg) − CR_LF` to `c.in.bytes` for every inbound message
   (`client.go:4345–4346`); after each parsed read buffer the totals are added with `atomic.AddInt64`
   to the connection, the account and the server (`:1607–1633`; `in_client_*` only for `CLIENT`
   connections, `:1625–1628`); deliveries do the same on the out side (`:5314–5319`). `/varz` reads them
   with `atomic.LoadInt64` (`monitor.go:1900–1907`), as does `/connz` per connection (`:595–596`).
   Nothing is sampled. The `Varz` comments (`:1269–1279`): `in_msgs` "includes messages from the
   clients, routers, gateways and leaf nodes"; `slow_consumers` is "the total count of clients that were
   disconnected since start"; `stalled_clients` "the total number of times that clients have been
   stalled".
2. **`/connz` and `/subsz` page at 1024 by default** (`DefaultConnListSize`, `DefaultSubListSize`,
   `monitor.go:170–173`).
3. **`/connz?auth=true` omits `account` for the global account**: `if name := client.acc.GetName();
   name != globalAccountName { ci.Account = name }` (`:457–459`); `name_tag` falls back to the account
   name (`:463`).
4. **A follower's consumer info**: `infoWithSnapAndReply` takes `delivered` and `ack_floor` from the
   replicated store state and, when not leader, `num_ack_pending = len(state.Pending)` and
   `num_redelivered = len(state.Redelivered)` (`consumer.go:3558–3565`) — **replicated, so correct on
   every node** — while **`streamNumPending` returns 0 without consulting the store unless this server
   is the leader** (`:5628–5632`). `num_pending` is therefore a leader-only figure by construction, on
   every surface that calls this function: `CONSUMER.INFO`, `/jsz`, `STATSZ`, the exporter, surveyor.
5. **`ha_assets` is the number of Raft nodes this server runs** — `stats.HAAssets = s.numRaftNodes()`
   (`jetstream.go:2623`; `raft.go:798–802`, `len(s.raftNodes)`) — which **includes the meta group**
   (`jetstream_cluster.go:8031`: "HAAssets contain _meta_ which we want to ignore, hence > and not
   >="). Every R>1 stream and consumer the server holds a replica of is one asset; R1 assets are not.
6. **`max_ha_assets`** (`jetstream { limits { max_ha_assets } }`, `opts.go:378`: "the maximum of Streams
   and Consumers that may have more than 1 replica") is enforced twice: when a Raft group would be
   created — `Maximum HA Assets limit reached: %d` in the log and `system limit reached` to the caller
   (`jetstream_cluster.go:2953–2959`) — and at placement, where a peer whose `ha_assets` exceeds it is
   discarded with `Peer selection: discard %s@%s (HA Asset Count: %d) exceeds max ha asset limit of %d`
   (`:8031–8035`); replicated streams are placed preferring the peer with fewer HA assets (`:8087–8088`).
   No default: 0 means unlimited.

## Practical takeaways

- `rate(in_msgs)` on a per-server basis is a true throughput figure; a cluster figure is a sum.
- `num_pending` on a follower is not "wrong data", it is 0 by design — filter by leader.
- Size on `ha_assets` per server, not on stream count: an R3 stream with ten R3 consumers is eleven
  assets on each of three servers.

## Relevance to the wiki

Rows 139, 153, 165; the leader rule and the `ha_assets` series on [[metrics]].

## Questions it answers

Q139, Q153 (with [[s-gh-5128-ha-assets]]), Q165.

## Pages touched

[[metrics]] · [[monitoring-endpoints]] · [[nats-top]] · [[consumer]] · [[jetstream-sizing]] · [[stream-placement]] · [[config-keys]]
