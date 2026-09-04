---
title: Gateway
type: concept
area: [topology, deploy, core]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [gateway, supercluster, geo-affinity, queue-group, gossip, reject_unknown_cluster, 7222, stalled_clients]
aliases: [gateways, super-cluster, supercluster, super cluster, cluster of clusters, geo-affinity, geo affinity]
sources: [s-docs-super-clusters, s-nats-server-topology, s-gh-7494-supercluster-degradation, s-docs-putting-it-together, s-docs-jetstream-in-a-cluster, s-gh-7438-multi-region-availability, s-gh-4823-leafnode-supercluster-duplicates, s-gh-6328-jetstream-behind-gateways, s-nats-server-jetstream-cluster, s-relnotes-2.14, s-relnotes-2.10, s-nats-server-request-reply, s-nats-server-request-reply-observed, s-docs-core-nats-queue-groups, s-docs-protocols-internal, s-nats-server-wire-protocol]
created: 2026-08-31
updated: 2026-09-04
---

# Gateway

**The connection that joins one cluster to another cluster.** Clusters joined this way are a
**super-cluster**. A route ties two *servers* together and assumes they are close; a gateway ties two
*clusters* together and assumes they are far apart (source: [[s-docs-super-clusters]]).

The distinction is not cosmetic. Stretch one `cluster {}` across two regions and every server holds a
route to every server in the other region — a full mesh over the WAN. With gateways, each server
opens **one connection per remote cluster**, never one per remote server.

## How it behaves

**A gateway forwards only what has interest on the far side.** A publisher flooding
`orders.created` in `east` puts nothing on the link if nobody in `west` subscribes to it. This is why
a gateway is cheap over a slow link.

**Gateways gossip.** Point a server at a few remote gateways "and it discovers the rest, including
clusters it was never told about directly". The `gateways` array is a seed and a fallback, not an
inventory you must keep complete. `reject_unknown_cluster: true` turns discovery off — it "effectively
disables gossiping of new cluster" while still letting a configured cluster grow
(source: `reference/config/gateway/reject_unknown_cluster.md`).

**`name` identifies the cluster, not the server.** Every server in `east` carries the identical
gateway name, and it must equal that server's `cluster.name`. A *conflicting* pair is a startup error:

```
cluster name conflicts between cluster and gateway definitions
```

(`ErrClusterNameConfigConflict`, `errors.go:192`). An **unset** `cluster.name` is a different case —
the gateway name is **adopted** as the cluster name (`server.go:1118–1124`), which the docs do not
mention (source: [[s-nats-server-topology]]). Same shape as the route-side adoption in
`inbox/docs-issues.md` #11.

**A stream's replicas never cross a gateway.** Replication is scoped to one cluster: "Replication
stays inside one cluster; it's the unit a stream is replicated across"
(source: [[s-docs-jetstream-in-a-cluster]]). Moving stream data between clusters is
[[mirrors-and-sources]], not a replica count — see [[multi-region-jetstream]].

**So a gateway is the wrong tool for the thing it is most often reached for.** Asked for regional read
replicas of a KV bucket across four continents, a maintainer's answer was to skip the super-cluster
entirely: "you could simply have your 3 node cluster in the US and have each of your 1 nodes in other
parts of the world connect to the cluster as Leaf Nodes. Then you can enable JS on those leaf nodes
and create read replica streams that source from streams located in the cluster"
(source: [[s-gh-6328-jetstream-behind-gateways]]). Because the data has to be mirrored or sourced
whichever link it crosses, the gateway buys nothing here — the connection type is chosen on network
and isolation grounds instead. See [[choosing-a-topology]] and [[leafnode]].

## Geo-affinity, precisely

The docs describe it as a preference: "NATS prefers a local queue subscriber first… The message never
crosses the gateway, because it doesn't need to."

The implementation is an **exclusion list**, and the difference matters. When a message is delivered
to local queue subscribers, the server collects the queue-group **names** it served
(`client.go:4482–4487`):

> "we need to keep track of the queue names the messages are delivered to. When sending to the GWs,
> the RMSG will include those names so that the remote clusters do not deliver messages to their queue
> subs of the same names."

`sendMsgToGateways` then drops those names from the remote's queue list, and skips the gateway
entirely only if nothing is left **and** there is no plain-subscriber interest
(`gateway.go:2638–2654`):

```go
2653:			if !psi && len(queues) == 0 {
2654:				continue
```

So:

- **Queue-group interest only on the far side** → nothing crosses. The docs' claim holds.
- **Any plain (non-queue) subscriber on the far side** → every message crosses, and geo-affinity
  suppresses nothing but the duplicate queue delivery.

That second case is the one people measure and do not expect —
[[supercluster-slows-when-a-remote-subscriber-joins]] (source:
[[s-gh-7494-supercluster-degradation]], [[s-nats-server-topology]]).

## Inside one cluster there is no affinity at all

The exclusion list above is the only locality preference the server has — the docs' "prefers a member in
the publisher's own cluster before reaching across to another region" (source:
[[s-docs-core-nats-queue-groups]]) is this list, and nothing narrower. Within a cluster a queue
group's members are equally likely wherever they sit: a peer's members arrive as one `RS+ … <weight>`
entry and the sublist expands it to the weight before the random pick (`sublist.go:741–747`), so one
member on the publisher's server and three on a peer received 90 / 97 / 106 / 107 of 400 publishes on
the lab (run E2; source: [[s-nats-server-request-reply]], [[s-nats-server-request-reply-observed]]). A
leafnode is different again — a leaf's members are only a fallback, and their entries skew the hub's
own split — [[queue-groups]] and [[leafnode]] have the runs. The queue names the local delivery
served are collected under `pmrCollectQueueNames` (`client.go:4481–4489`) and handed to
`sendMsgToGateways` (`gateway.go:2638–2654`); the block above is quoted from that range.


## What configures it

```
gateway {
  name: "east"          # must equal cluster.name
  port: 7222            # no default — see below
  gateways: [
    { name: "west", urls: ["nats://w1:7222", "nats://w2:7222", "nats://w3:7222"] }
  ]
}
```

| key | what it does | default | reload |
|---|---|---|---|
| `gateway.name` | the **cluster's** name; identical on every server of the cluster | – | restart |
| `gateway.port` / `listen` | where inbound gateway connections land | **none** | restart |
| `gateway.host` | interface to listen on | `0.0.0.0` (only once a port is set) | restart |
| `gateway.gateways[].name` | the remote cluster's name; a typo never connects | – | restart |
| `gateway.gateways[].urls` | where to reach that cluster's gateway listeners | – | restart |
| `gateway.reject_unknown_cluster` | refuse clusters not in `gateways`; disables gossip of new clusters | `false` | restart |
| `gateway.advertise` | `<host>:<port>` to advertise, for NAT | – | restart |
| `gateway.connect_retries` | attempts before giving up on a **discovered** gateway; does not apply to configured ones | `0` | restart |
| `gateway.connect_backoff` | back off between reconnects instead of a fixed interval | `false` | restart |
| `gateway.write_deadline` | how long a gateway write may block before the connection is stalled | `10s` | restart |
| `gateway.tls` | **`verify` is always enabled** on gateway TLS | – | material only |

**`gateway.port` has no default.** The generated reference states `7222`; the server refuses to
start without one:

```
nats-server: gateway "east" has no port specified (select -1 for random port)
```

(`gateway.go:316–318`; reproduced on v2.14.6). `nats-server -t` passes the same file
(source: [[s-nats-server-topology]]; `inbox/docs-issues.md` #23).

**Only TLS material reloads.** Everything else in the block — `host`, `port`, `name`,
`authorization`, the remote list, and the TLS `timeout`, `verify_and_map`,
`verify_cert_and_check_known_urls` and `pinned_certs` — fails the reload
(source: `reference/config/gateway.md`). See [[reload-server-config]].

**Gateway `authorization` is restricted.** A single username/password only: `users` and `token`
"will prevent the server from starting", callouts are rejected, and the `permissions` block is
ignored. With `verify_and_map`, different certificates are fine as long as they map to the same
username (source: `reference/config/gateway.md`).

**A server with both a gateway and a leafnode listener must set `system_account`** or it will not
start — see [[leafnode]].

## Limits and failure modes

- **A working super-cluster is not a correct one.** A typo'd remote name never connects and logs
  `Failing connection to gateway "wset", remote gateway name is "west"` on every retry — while the
  *other* cluster's correct outbound connection lands and gossip forms the super-cluster anyway. The
  remote gets a second, more informative line naming all three values:
  `Connection from %q rejected, wanted to connect to %q, this is %q` (`gateway.go:1099–1103`). Alert
  on the log, not on a successful publish.
- **Centralising workers defeats geo-affinity.** Run all `order-workers` in one region and every
  other region's orders cross the WAN as steady-state load.
- **A plain cross-region subscriber couples every local publisher to the WAN link** — see the
  geo-affinity section and [[supercluster-slows-when-a-remote-subscriber-joins]].
- **A super-cluster is one JetStream meta group over the WAN.** Stream and consumer creation needs a
  global quorum, so a region's availability depends on the others, and an imbalanced server count
  lets one region dominate. This is the reason a maintainer recommends leafnodes with separate
  domains for uneven multi-region deployments (source: [[s-gh-7438-multi-region-availability]]) —
  [[multi-region-jetstream]].

## What you can observe

```
nats server report gateways
nats server list                 # the GWs column counts gateway connections per server
```

Both need the system account. `/gatewayz` is the HTTP equivalent — see [[monitoring-endpoints]].
When a cross-region publisher slows down, `/varz` → `stalled_clients` and `/connz` → `stalls` are the
counters that say so.

## Version notes: the 2.14 line

**Since.** `since: [2.10]` in the frontmatter means *present at 2.10, the oldest line this wiki covers*:
the 2.10 release bodies patch gateways from v2.10.12 on and none records the arrival, which is
older than the archive (source: [[s-relnotes-2.10]]).

**2.14.2**: "quorum needed is now calculated correctly when bootstrapping the metalayer when gateway
URLs resolve to multiple IP addresses" (#8238) — a gateway name behind a round-robin DNS record
could be counted more than once (source: [[s-relnotes-2.14]]). **2.14.3**: a race in gateway
`CONNECT` handling (#8306). **2.14.6**: routes missing after a reconnect when gossiped URLs were
rejected (#8527).


## Interest-only is the default, and has been since 2.9.0

The gateway protocol has two interest modes, and every account-level description of them written
before 2.9 is now the wrong one.

- **Optimistic** — send everything for an account until the far side says "no interest" with an
  `RS-` per subject, and keep a no-interest list. After
  `defaultGatewayMaxRUnsubBeforeSwitch = 1000` such replies the account switches
  (`gateway.go:41`).
- **Interest-only** — send nothing unless the far side has sent an explicit `RS+`.

Since **2.9.0** a server advertises `"gateway_iom":true` in its gateway `INFO` unconditionally, and
the comment says what it means: "this server will switch all accounts to InterestOnly mode when
accepting an inbound or when a new account is fetched" (`gateway.go:552–558`). Between two 2.9+
servers the optimistic path is therefore never entered, and the 1000-`RS-` threshold never reached.
Observed on a 2.14.6 gateway listener (source: [[s-nats-server-wire-protocol]]):

```
INFO {"server_id":"…","version":"2.14.6","proto":3,"go":"","host":"…","port":17222,"headers":true,"max_payload":1048576,"gateway":"WPC","gateway_urls":["…:17222"],"gateway_url":"…:17222","gateway_nrp":true,"gateway_iom":true}
```

`reference/protocols/gateway.md:251–270` still presents optimistic mode as the initial state and the
`RS-` count as the trigger; that is the pre-2.9 behaviour (`inbox/docs-issues.md` #106).

**A reply that crosses a gateway is rewritten.** The origin cluster puts
`_GR_.<6-char cluster hash>.<6-char server hash>.` in front of the client's own reply subject and
strips it again on the way back — so a capture on the far side shows an inbox nobody subscribed to:

```
CA  RMSG $G x.svc + _GR_.DdEU99.DSpI1m._INBOX.IyBx… NATS-RPLY-22 3
CB  RMSG $G _GR_.DdEU99.DSpI1m._INBOX.IyBx… 8
```

`$GR.` is the **old** prefix (`oldGWReplyPrefix`, `gateway.go:43`) and `$GNR.` a name that survives
only in comments. The frames, the `A+` / `A-` account verbs and the `gateway_cmd` codes are in
[[wire-protocol]] (source: [[s-docs-protocols-internal]]).

**Gateways ping regardless of traffic.** `gwMaxPingInterval = 15s` (`gateway.go:58`) caps whatever
`ping_interval` is configured, because `s2_auto` compression picks its level from measured RTT.


## Related

[[leafnode]] · [[choosing-a-topology]] · [[multi-region-jetstream]] · [[build-a-3-node-cluster]] ·
[[mirrors-and-sources]] · [[raft-in-nats]] · [[supercluster-slows-when-a-remote-subscriber-joins]] ·
[[duplicate-messages-across-a-leafnode]] · [[monitoring-endpoints]] · [[reload-server-config]]

## Sources

[[s-docs-super-clusters]] · [[s-docs-putting-it-together]] · [[s-docs-jetstream-in-a-cluster]] ·
[[s-nats-server-topology]] · [[s-gh-7494-supercluster-degradation]] ·
[[s-gh-7438-multi-region-availability]] · [[s-gh-4823-leafnode-supercluster-duplicates]] ·
[[s-gh-6328-jetstream-behind-gateways]] · [[s-nats-server-jetstream-cluster]] · [[s-relnotes-2.14]] · [[s-relnotes-2.10]] · [[s-nats-server-request-reply]] · [[s-nats-server-request-reply-observed]]
- [[s-docs-core-nats-queue-groups]] — the docs' one sentence on geo-affinity for queue groups. · [[s-docs-protocols-internal]] · [[s-nats-server-wire-protocol]]

## To verify

- ~~The meta-group behaviour across gateways has not been read from the server source~~ **Settled
  2026-09-01**: at bootstrap the meta group's expected peer size is `len(routes)` plus every
  configured gateway URL, and creates are proposals the meta leader commits to a majority of that
  group — one meta group per super-cluster, so a gateway does cost a global quorum. See
  [[meta-layer]] (source: [[s-nats-server-jetstream-cluster]]).
- `gateway.connect_retries` is documented as applying only to *discovered* gateways. Not verified
  against the source.
