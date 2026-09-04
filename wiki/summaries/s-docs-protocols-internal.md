---
title: "docs — reference/protocols/route, /gateway, /leafnode: the three server-to-server protocols"
type: summary
area: [topology, core, interop]
source-url: https://docs.nats.io/reference/protocols/route.md
source-path: raw/nats-docs/reference/protocols/route.md
author: NATS documentation
article: "reference/protocols/route.md, /gateway.md and /leafnode.md, fetched 2026-08-31, read as one and swept against nats-server v2.14.6"
date: 2026-08-31
version: "2.0.0 in route.md's example, 2.10.0 in gateway.md's and leafnode.md's; no claim carries a version"
tags: [wire-protocol, route, gateway, leafnode, RS+, RS-, RMSG, LS+, LS-, LMSG, A+, A-, LDS, lnocu, compression]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# docs — `reference/protocols/route`, `/gateway`, `/leafnode`: the three server-to-server protocols

The three pages a client never needs and an operator reads with a packet capture open. Read together
for step 5 of `inbox/plan-the-client-side-2026-09-03.md`, because they share a shape — each extends
the client protocol with an account token and a subscription verb — and share their defects. Swept
against `nats-server` v2.14.6 ([[s-nats-server-wire-protocol]]), whose `-DV` trace was the authority
for every verb below.

## The three at a glance

| | route | gateway | leafnode |
|---|---|---|---|
| port in the examples | 6222 | 7222 | 7422 (`DEFAULT_LEAFNODE_PORT`, `const.go:206` — the only one of the three that is a server constant) |
| joins | server ↔ server, one cluster | cluster ↔ cluster | edge server → hub |
| subscription verb | `RS+` / `RS-` | `RS+` / `RS-`, plus `A+` / `A-` | `LS+` / `LS-` |
| message verb | `RMSG`, `HMSG` | `RMSG`, `HMSG` | `LMSG`, `HMSG` |
| account in the frame | yes | yes | **no** — the connection is bound to one account |
| documented `INFO` fields | 10 | 15 | 18 |
| ping | traffic-proxied per the page | "configurable interval" | "configurable intervals" |

The account column is the real difference. A route or gateway frame names its account
(`RS+ $G orders.new`); a leafnode connection is bound to one account at CONNECT time
(`remote_account`), so its frames carry only the subject.

## Key claims that hold

**Routes are a full mesh and gossip themselves.** "The accepting server will add an `ip` field
containing the address and port of the connecting server, and forward the new server's `INFO` message
to all servers it is routed to. Any servers in a cluster receiving an `INFO` message with an `ip`
field will attempt to connect to the server at that address, unless already connected"
(`route.md:25–27`).

**A gateway is one connection per remote cluster, interest-filtered.** "gateways act as intelligent
bridges that route messages between clusters based on account and subject interest"
(`gateway.md:4`).

**A leafnode is asymmetric.** "leafnodes create asymmetric connections where the edge initiates and
maintains the connection to the hub" (`leafnode.md:4`).

**Queue weight travels with the subscription.** `RS+ <account> <subject> <queue> <weight>`
(`route.md:99`, `gateway.md:147`) — confirmed on the wire as `RS+ $G work.> WORKERS 1`.

**Loop detection is a subject.** `$LDS.<unique_id>`, "When a server receives its own LDS subject
through a leafnode connection, it detects a routing loop" (`leafnode.md:262–277`) — confirmed:
`leafNodeLoopDetectionSubjectPrefix = "$LDS."` (`leafnode.go:59`) and the subject arrives as an
ordinary `LS+` (run E1b).

**Compression is negotiated in INFO/CONNECT and `s2_auto` keys off RTT** (`leafnode.md:298–313`) —
confirmed, with the thresholds `10ms / 50ms / 100ms` selecting uncompressed / fast / better / best
(`server.go:457–464`).

## What the sweep found

Recorded as `inbox/docs-issues.md` #102–#107. The three pages fail in the same three ways.

### 1 · Verb forms that the parser does not accept

| the page | the server at v2.14.6 |
|---|---|
| `LS+ <subject> <queue_group>` (`leafnode.md:112`) | **`processLeafSub` accepts 1 or 3 arguments only** (`leafnode.go:2926–2941`); a two-token `LS+` is `processLeafSub Parse Error` |
| `LS+ … <origin_cluster>` last (`leafnode.md:142`) | the origin cluster is the **first** token, and it is a **route** protocol form: `LS+ LEAF1 $G edge.ping` (`route.go:1729–1740`, run E) |
| `LS- … <origin_cluster>` last (`leafnode.md:181`) | likewise first: `LS- LEAF1 $G edge.work W` |
| `LMSG <subject> … <header_size> <total_size>` (`leafnode.md:217`) | **does not exist**; a leaf sends **`HMSG`** for headers (`parser.go:381–385`), and a three-token `LMSG` is parsed as *subject, reply, size* |
| `RMSG <account> <subject> [reply-to] <bytes>` (`route.md:133`, `gateway.md:204`) | omits the `+` reply indicator and the queue list: `RMSG $G work.a | WORKERS 6`, `RMSG $G x.svc + _GR_.… NATS-RPLY-22 3` |
| `LDS` as a verb, "Sent By: Hub Server" (`leafnode.md:17`) | **there is no `LDS` verb**; `$LDS.<nuid>` is a subject carried by `LS+` |

`LMSG` also has an undocumented three-token reply form without the `+`
(`LMSG edge.ping answers.here 10`, `leafnode.go:3241–3245`), and `LMSG` on a *route* means something
else entirely — a routed message carrying an origin cluster (`parser.go:1034–1039`).

### 2 · CONNECT and INFO fields that are not what the server sends

**The route and gateway CONNECT do not carry `lang` or `version`** — and their absence is the
mechanism by which the server tells a route from a client: "Client provide Lang in the CONNECT
protocol while ROUTEs don't" (`route.go:3022–3028`). `route.md:73–74` and `gateway.md:83–84` list
both. Observed:

```
CONNECT {"echo":true,"verbose":false,"pedantic":false,"tls_required":false,"headers":true,"name":"<server id>","cluster":"HUBC","lnoc":true}
CONNECT {"echo":false,"verbose":false,"pedantic":false,"tls_required":false,"headers":false,"name":"<server id>","cluster":"","gateway":"CB"}
```

`name` is the remote's **server ID**, not the "Generated Server Name" of `route.md:72`.

**Three of the leaf CONNECT's documented names are wrong** (`leafnode.md:75–89`): the compression
field is `compress_mode`, not `compression` — the old `compression` tag "has never been used"
(`leafnode.go:2189–2193`); `hub` is `is_hub`; `proto` is `protocol`. Two real fields, `deny_pub` and
`isolate`, are undocumented.

**`gateway_url` is a bare `host:port`.** `gateway.md:50` gives `nats-gw://<hostname>:<port>`;
observed `"gateway_url":"192.168.178.61:17222"` (run A5).

**The leafnode `INFO`'s `proto` is 3, not 1.** `leafnode.md:36` says "Protocol version (1 for current
leafnode protocol)"; observed `"proto":3` on both the leafnode and the route listener.
`leafnode.md:50` describes `client_id` as "Client ID for compression negotiation"; it is the
connection id, and it is on every INFO.

**The route listener's own INFO has no `ip`.** `route.md:25` is describing a *forwarded* INFO;
observed, a fresh connection to 6222 gets `cluster`, `connect_urls`, `compression`, `lnoc`, `lnocu`,
`route_pool_size`, `gateway_url` and `leafnode_urls` — five of which appear on no page.

**The compression list is missing `s2_best`** (`leafnode.md:291–296`) — the server has eight names,
`not supported`, `off`, `accept`, `s2_auto`, `s2_uncompressed`, `s2_fast`, `s2_better`, `s2_best`
(`server.go:444–452`) — and does not mention that `on` / `enabled` / `true`, `disabled` / `false` and
`not_supported` are accepted aliases.

### 3 · Errors that are not sent, and a mode that no longer applies

**Six of the ten "common errors" listed by the gateway and leafnode pages do not exist.** Sweeping
`sendErr` across `gateway.go` and `leafnode.go` at v2.14.6
([[s-nats-server-client-errors]]) gives no `Invalid Account`, no `Gateway Protocol Error`, no
`Loop Detected`, no `Leafnode Not Allowed`, no `Maximum Payload Exceeded` (the literal is
`Maximum Payload Violation`, `client.go:2554`) and no bare `Permissions Violation` (the leaf forms are
`Permissions Violation for Publish to %q` and `… for Subscription to %q`, `leafnode.go:3488`, `:3491`).
What the two files do send and neither page lists: `Rejecting connection from gateway %q on the
leafnode port`, `Attempt to connect to gateway %q using wrong port`, `Connection from %q rejected,
wanted to connect to %q, this is %q`, `remote leafnode has same cluster name`, `cluster name cannot
contain spaces`, `connection rejected since minimum version required is %q`, `Invalid Subscription`,
`Stale Leaf Node Connection - Closing`.

**The gateway's optimistic mode is the pre-2.9 behaviour.** `gateway.md:251–270` describes optimistic
mode as the initial state and the `RS-` count as the trigger for interest-only. Since **v2.9.0** the
server advertises `gateway_iom: true` unconditionally — "this server will switch all accounts to
InterestOnly mode when accepting an inbound or when a new account is fetched"
(`gateway.go:552–558`) — and the flag was observed on the gateway listener's INFO (run A5). The
threshold the page describes without naming is `defaultGatewayMaxRUnsubBeforeSwitch = 1000`
(`gateway.go:41`).

**The leafnode page's "30-second reconnection delay" is three different constants**, and there is a
fourth: `leafNodeReconnectDelayAfterLoopDetected`, `leafNodeReconnectAfterPermViolation`,
`leafNodeReconnectDelayAfterClusterNameSame` = 30 s each, and
`leafNodeMinVersionReconnectDelay = 5 s` (`leafnode.go:48–67`).

## Practical takeaways

- To recognise a connection kind from a capture, look at the CONNECT: `lang` present → client;
  `gateway` present → gateway; `cluster` and no `lang` → route; anything else on 7422 → leaf.
- The account token tells a route/gateway frame from a leaf frame at a glance. `$G` is the global
  account.
- `_GR_.<cluster hash>.<server hash>.` in front of an inbox is a reply crossing a gateway, not a
  subject anyone published.

## Relevance to the wiki

The source for the route, gateway and leafnode halves of [[wire-protocol]], and the correction layer
for [[gateway]], [[leafnode]] and [[duplicate-messages-across-a-leafnode]].

## Questions it answers

Bank rows 185, 187.

## Pages touched

[[wire-protocol]], [[gateway]], [[leafnode]], [[duplicate-messages-across-a-leafnode]],
[[supercluster-slows-when-a-remote-subscriber-joins]], [[how-clients-reach-a-cluster]],
[[build-a-3-node-cluster]], [[system-subjects]], [[nats-server]], [[nats-server-2.10]].

## Sources

- `raw/nats-docs/reference/protocols/route.md`, `/gateway.md`, `/leafnode.md` (fetched 2026-08-31)
- Swept against [[s-nats-server-wire-protocol]] and [[s-nats-server-client-errors]].
