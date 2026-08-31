---
title: "nats-server v2.14.6 — gateways, leafnodes and the checks that run before startup"
type: summary
area: [topology, core, monitoring, security]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/topology-v2.14.6.md
author: nats-io/nats-server contributors
article: "server/server.go, gateway.go, leafnode.go, client.go, opts.go, monitor.go at v2.14.6"
date: 2026-08-31
version: "2.14.6"
tags: [validateOptions, gateway, leafnode, geo-affinity, deny_imports, deny_exports, stalled_clients, system_account]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — the topology layer, read from source

Read to settle four things the docs state loosely: what an omitted topology port does, what a
composed server requires before it will start, what geo-affinity actually suppresses, and what
`deny_imports` / `deny_exports` are. Quoted ranges are in `raw/nats-server-src/topology-v2.14.6.md`;
behaviour marked *observed* was reproduced on the **v2.14.5** binary with the configs recorded there.

## Key claims

### `validateOptions` runs inside `NewServer`, before any account exists

`server.go:729` calls `validateOptions(opts)` from `NewServer`, with the comment that it is there
"because we cannot assume that server will always be started with configuration parsing". Everything
below is therefore a **startup** failure, not a runtime one — and none of it is reachable by
`nats-server -t`, which parses and stops.

### A leafnode listener plus a gateway requires `system_account`

`validateLeafNodeOptions` (`leafnode.go`) returns early if `o.LeafNode.Port == 0` and again if no
gateway is configured. Past both:

```go
346:	// If we are here we have both leaf nodes and gateways defined, make sure there
347:	// is a system account defined.
348:	if o.SystemAccount == _EMPTY_ {
349:		return fmt.Errorf("leaf nodes and gateways (both being defined) require a system account to also be configured")
```

`o.SystemAccount` is only non-empty when the config sets `system_account:` (`opts.go:1038`) or a
trusted operator supplies one (`opts.go:1535`). The runtime fallback that creates `$SYS`
(`server.go:2371–2373`) happens **later**, so it cannot satisfy this check.

*Observed:* the composed `n1-east.conf` from `learn/topologies/putting-it-together.md` passes
`nats-server -t` and then refuses to start with exactly that message.

### The three topology ports have no defaults

The generated config reference gives `cluster.port` `6222`, `gateway.port` `7222` and
`leafnodes.port` `7422` as **defaults**. The server applies none of them, and the three failure
shapes differ:

| key | documented default | what an omitted value does |
|---|---|---|
| `gateway.port` | `7222` | **startup error**: `gateway %q has no port specified (select -1 for random port)` (`gateway.go:316–318`) |
| `leafnodes.port` | `7422` | **no listener, silently** — `validateLeafNodeOptions` returns at `leafnode.go:328` and no accept loop starts |
| `cluster.port` | `6222` | **no listener, silently** |

`DEFAULT_LEAFNODE_PORT = 7422` exists (`const.go:206`) and is used in exactly **one** place — to fill
in a missing port on a *remote's* URL (`opts.go:6096`), never to open a listener. The `host` defaults
(`0.0.0.0`) *are* applied, but only once a port is set (`opts.go:6072–6074`, `6140–6142`).

*Observed:* `leafnodes { }` on a server with `listen: 127.0.0.1:4222` holds exactly one listening
socket, 4222.

### An unset `cluster.name` is adopted from `gateway.name`

`validateCluster` (`server.go:1118–1124`):

```go
1118:	if o.Gateway.Name != _EMPTY_ && o.Gateway.Name != o.Cluster.Name {
1119:		if o.Cluster.Name != _EMPTY_ {
1120:			return ErrClusterNameConfigConflict
1121:		}
1122:		// Set this here so we do not consider it dynamic.
1123:		o.Cluster.Name = o.Gateway.Name
```

The docs' `cluster name conflicts between cluster and gateway definitions` is correct
(`errors.go:192`) — but only for the *conflicting* branch. Unset is adopted. This is the same shape
as the route-side adoption in `inbox/docs-issues.md` #11.

### The gateway name mismatch produces **two** log lines, on two servers

```go
1099:			c.Errorf("Failing connection to gateway %q, remote gateway name is %q",
1100:				gwName, info.Gateway)
1102:			c.sendErr(fmt.Sprintf("Connection from %q rejected, wanted to connect to %q, this is %q",
1103:				s.getGatewayName(), gwName, info.Gateway))
```

The docs quote the first. The second is sent to the **remote** so the error "makes more sense in the
remote server's log", and it names all three values — this server, what it wanted, what it found.

### Geo-affinity is an exclusion list, not a routing preference

`client.go:4482–4487` says what is collected and why:

> "If there are matching queue subs and we are in gateway mode, we need to keep track of the queue
> names the messages are delivered to. When sending to the GWs, the RMSG will include those names so
> that the remote clusters do not deliver messages to their queue subs of the same names."

`sendMsgToGateways` then applies it per gateway (`gateway.go:2637–2654`): a remote queue group whose
name is already in `qgroups` is **not added**, and

```go
2652:			if !psi && len(queues) == 0 {
2653:				continue
```

— with no plain-subscriber interest (`psi`) and nothing left in the queue list, the gateway is
skipped. So the docs' "the message never crosses the gateway" holds **only when the far side's
interest is queue-group interest**. A single plain subscriber on the same subject in the remote
cluster puts every message on the WAN link, and geo-affinity suppresses nothing but the duplicate
queue delivery.

### A fast producer is stalled by its slowest destination — including a gateway

```go
125:	stallClientMinDuration = 2 * time.Millisecond
126:	stallClientMaxDuration = 5 * time.Millisecond
127:	stallTotalAllowed      = 10 * time.Millisecond
```

`deliverMsg` (`client.go:3937–3944`) stalls when the producer is a `CLIENT` and the destination
connection is in a stalled state, unless `no_fast_producer_stall: true` — in which case the server
"drops messages to the slow consumer instead". The stall is capped per read-loop invocation at
`stallTotalAllowed` (`client.go:3713`, `3736–3737`).

The observable, which the docs tree never names:

- log: `Producer was stalled for a total of %v` (`client.go:1451`), rate-limited
- `/varz` → **`stalled_clients`** (`monitor.go:1279`, `1909`) — server-wide count of stalls
- `/connz` → **`stalls`** per connection (`monitor.go:133`, `597`)

### `deny_imports` and `deny_exports` are deny-only, and they compose with the hub's permissions

`newLeafNodeCfg` (`leafnode.go:473–481`):

```go
475:		if len(remote.DenyExports) > 0 {
476:			perms.Publish = &SubjectPermission{Deny: remote.DenyExports}
478:		if len(remote.DenyImports) > 0 {
479:			perms.Subscribe = &SubjectPermission{Deny: remote.DenyImports}
```

So `deny_exports` is a **publish** deny (what this leaf sends up) and `deny_imports` is a
**subscribe** deny (what it asks for). There is no `allow` counterpart, which is why "deny everything,
then allow one subject" is not expressible with these keys.

The hub's side arrives in the INFO and the leaf's local denies are **merged on top**
(`leafnode.go:1715–1735`); on the hub the leaf's permissions are **reversed**, "since data is flowing
in the opposite direction" (`leafnode.go:2307–2318`), and pushed back by `sendPermsAndAccountInfo`
(`leafnode.go:2423–2424`) "for local enforcement".

### A leafnode user cannot carry permissions

`parseLeafUsers` is "a trimmed down version of parseUsers … for the users possibly defined in the
`authorization{}` section of `leafnodes {}`" (`opts.go:3005–3007`). It accepts exactly four keys:
`user`/`username`, `pass`/`password`, `account`, `proxy_required`.

*Observed:* `permissions` inside a `leafnodes.authorization` user is a parse error —
`unknown field "permissions"`. And a `leafuser` entry in the **global** `authorization.users` block
does not govern the leafnode connection at all: the deny is simply not applied. Both reproduce
gh#5941's unanswered follow-up exactly.

## Practical takeaways

- **`nats-server -t` is a syntax check.** It passes every `validateOptions` failure. A config gate
  that only runs `-t` will hand you a server that dies on restart. The real dry run is starting the
  binary.
- Write the port. Every time. On all three blocks. The reference's "Default" column is describing a
  convention, not the server.
- If a server both accepts leafnodes and speaks to a gateway, `system_account` is mandatory.
- Geo-affinity buys you nothing for plain subscribers. Design the cross-region workload as a queue
  group or expect the WAN traffic.
- `stalled_clients` and per-connection `stalls` are the two counters that explain "my publisher got
  slow when a distant subscriber joined".
- In **config** mode the leaf boundary is the **account**, not a user permission set. Permissions on
  the leaf user only exist in operator mode, where they travel in the JWT.

## Relevance to the wiki

The authority behind [[gateway]], [[leafnode]], [[choosing-a-topology]] and
[[supercluster-slows-when-a-remote-subscriber-joins]]; the source of `inbox/docs-issues.md` #23–#25;
and a correction to the pre-flight advice on [[reload-server-config]].

## Questions it answers

- **Q46** — why a same-region rate collapses when a remote subscriber joins.
- **Q48** — what `deny_imports` / `deny_exports` can and cannot express.

## Pages touched

[[gateway]] · [[leafnode]] · [[choosing-a-topology]] · [[multi-region-jetstream]] ·
[[supercluster-slows-when-a-remote-subscriber-joins]] · [[reload-server-config]] ·
[[monitoring-endpoints]] · [[config-keys]] · [[defaults-and-limits]] · [[build-a-3-node-cluster]] ·
[[slow-consumer-detected]]
