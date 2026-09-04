---
title: Wire protocol
type: reference
area: [core, topology, clients, interop]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; per-field arrivals are noted in the tables
verified-against: nats-server 2.14.6
verified-on: 2026-09-04
tags: [wire-protocol, INFO, CONNECT, PUB, SUB, MSG, HPUB, HMSG, PING, PONG, -ERR, +OK, RS+, RS-, RMSG, LS+, LS-, LMSG, A+, A-, LDS, telnet, nc]
aliases: [protocol, nats protocol, client protocol, route protocol, gateway protocol, leafnode protocol, "-ERR", "+OK", INFO, CONNECT, RMSG, LMSG, "protocol errors", "wire format"]
sources: [s-nats-server-wire-protocol, s-docs-protocol-client, s-docs-protocols-internal, s-nats-server-client-errors, s-docs-system-errors, s-nats-server-tcp-nodelay]
created: 2026-09-04
updated: 2026-09-04
---

# Wire protocol

Every byte a NATS connection can carry, at **nats-server 2.14.6**: the `INFO` and `CONNECT` fields,
the verbs of all four connection kinds, and the exact `-ERR` strings with the setting behind each one
and whether the connection survives. It is a lookup table, not an explanation — the mechanisms are on
[[core-nats-delivery]], [[client-connection-lifecycle]], [[gateway]] and [[leafnode]].

**Where this page and the docs disagree, this page states the server** and says so in the row. The
documentation of this protocol is unusually far out of date: `reference/protocols/client.md` carries
three wrong defaults and six wrong strings on one table, and the three server-to-server pages contain
verb forms the parser rejects. Every disagreement is recorded in `inbox/docs-issues.md` #102–#107.

---

## The verbs, by connection kind

Operation names are **case-insensitive** (`sub foo 1` = `SUB foo 1`); every frame ends `␍␊`.

| verb | client | route | gateway | leafnode | form |
|---|---|---|---|---|---|
| `INFO` | ✓ | ✓ | ✓ | ✓ | `INFO <json> ␍␊` |
| `CONNECT` | ✓ | ✓ | ✓ | ✓ | `CONNECT <json>␍␊` |
| `PING` / `PONG` | ✓ | ✓ | ✓ | ✓ | `PING␍␊` |
| `+OK` | ✓ | | | | `+OK␍␊`, only when `verbose` |
| `-ERR` | ✓ | ✓ | ✓ | ✓ | `-ERR '<message>'␍␊` |
| `PUB` / `HPUB` | ✓ | | | | `PUB <subject> [reply] <#bytes>␍␊<payload>␍␊` |
| `SUB` / `UNSUB` | ✓ | | | | `SUB <subject> [queue] <sid>␍␊` · `UNSUB <sid> [max]␍␊` |
| `MSG` / `HMSG` | ✓ | | | | `MSG <subject> <sid> [reply] <#bytes>␍␊<payload>␍␊` |
| `RS+` / `RS-` | | ✓ | ✓ | | `RS+ <account> <subject> [<queue> <weight>]␍␊` |
| `RMSG` | | ✓ | ✓ | | see below |
| `LS+` / `LS-` | | ✓ ¹ | | ✓ | `LS+ <subject> [<queue> <weight>]␍␊` |
| `LMSG` | | ✓ ² | | ✓ | see below |
| `HMSG` | | ✓ | ✓ | ✓ | the header form of `RMSG` / `LMSG` |
| `A+` / `A-` | | | ✓ | | `A+ <account>␍␊` — account-level interest |

¹ On a **route**, `LS+` / `LS-` carry a leaf-origin subscription and take an extra leading token; see
*Origin clusters* below. ² On a route, `LMSG` is a message carrying an origin cluster
(`processRoutedOriginClusterMsgArgs`, `parser.go:1034–1039`) — not the leafnode `LMSG`.

**There is no `LDS` verb.** `$LDS.<nuid>` is a loop-detection *subject*, carried by an ordinary `LS+`
(`leafnode.go:59`; observed). `reference/protocols/leafnode.md:17` lists it as a message type.

### The message forms, exactly

```
MSG   <subject> <sid> [reply] <#bytes>␍␊<payload>␍␊
HMSG  <subject> <sid> [reply] <#hdr> <#total>␍␊<headers>␍␊␍␊<payload>␍␊

RMSG  <account> <subject> [+ <reply>] [| <queue>…] <#bytes>␍␊<payload>␍␊
LMSG  <subject> <#bytes>␍␊<payload>␍␊
LMSG  <subject> <reply> <#bytes>␍␊<payload>␍␊
LMSG  <subject> | <queue>… <#bytes>␍␊<payload>␍␊
LMSG  <subject> + <reply> [<queue>…] <#bytes>␍␊<payload>␍␊
HMSG  <subject> [+ <reply>] [| <queue>…] <#hdr> <#total>␍␊<headers>␍␊␍␊<payload>␍␊
```

`+` marks a reply, `|` marks the queue list (`leafnode.go:3233–3269`). The three-token form
`LMSG <subject> <reply> <#bytes>` has **no indicator** and is undocumented. A leafnode's header
messages are **`HMSG`**, never `LMSG` with two sizes — the `LMSG … <header_size> <total_size>` form of
`reference/protocols/leafnode.md:217` does not exist, and would be parsed as *subject, reply, size*.

Observed on the wire (`-DV` trace, run E/F):

```
RS+ $G orders.new                              LS+ edge.ping
RS+ $G work.> WORKERS 1                        LS+ edge.work W 1
RMSG $G orders.new 11                          LMSG edge.ping 5
RMSG $G work.a | WORKERS 6                     LMSG edge.ping answers.here 10
RS- $G work.> WORKERS                          LMSG edge.work | W 6
                                               LMSG edge.svc + _INBOX.… NATS-RPLY-22 3
                                               HMSG edge.ping 22 33
                                               HMSG edge.work | W 18 31
                                               LS- edge.work W
```

`$G` is the global account. `LS+` accepts **one or three** arguments, never two — a queue
subscription must carry its weight (`leafnode.go:2926–2941`), so
`LS+ <subject> <queue_group>` (`leafnode.md:112`) is a parse error.

### Origin clusters

A **route** forwards a leaf-origin subscription as `LS+` / `LS-` with the origin cluster as the
**first** token (`route.go:1729–1740`), advertised as `lnoc` / `lnocu` in the route `INFO`:

```
LS+ <origin cluster> <account> <subject> [<queue> <weight>]
LS- <origin cluster> <account> <subject> [<queue>]
```

Observed: `LS+ LEAF1 $G edge.ping`, `LS- LEAF1 $G edge.work W`. A leafnode connection's own `LS+`
never carries a cluster. `reference/protocols/leafnode.md:142` puts the token last, on the wrong
protocol.

### Argument-count ceilings

`MAX_PUB_ARGS = 3`, `MAX_HPUB_ARGS = 4`, `MAX_MSG_ARGS = 4`, `MAX_RSUB_ARGS = 6` (`const.go:173–189`).

---

## `INFO` — the fields the server sends

`type Info struct`, `server.go:108–165` — 49 JSON fields, one struct for all four kinds. Everything
but the first nine is `omitempty`, so what arrives depends on the deployment. "kind" is which
listeners send it.

### Common

| field | type | kind | notes |
|---|---|---|---|
| `server_id` | string | all | the server's nkey public key |
| `server_name` | string | all | |
| `version` | string | all | e.g. `2.14.6` |
| `proto` | int | all | **1** to a client, **3** on route / gateway / leafnode listeners |
| `git_commit` | string | all | omitted when not built with one |
| `go` | string | all | the Go version — **empty string** on a gateway INFO |
| `host`, `port` | string, int | all | the listener's own host and port |
| `headers` | bool | all | |
| `max_payload` | int32 | all | |
| `auth_required` | bool | all | |
| `tls_required`, `tls_verify`, `tls_available` | bool | all | |
| `jetstream` | bool | all | |
| `ip` | string | route, leaf | `nats-route://host:port` on a *forwarded* peer INFO; **absent** from a route listener's own greeting |
| `client_id` | uint64 | all | the connection id — one field, `CID` |
| `client_ip` | string | client | on the default INFO |
| `nonce` | string | all | present whenever a signature may be needed |
| `cluster` | string | all | |
| `cluster_dynamic` | bool | route | **undocumented** |
| `domain` | string | all | the JetStream domain |
| `connect_urls` | []string | client, route | the advertised `host:port` of every known node |
| `ws_connect_urls` | []string | client | |
| `ldm` | bool | client | `true` once the server enters lame duck |
| `compression` | string | route, leaf | the advertised mode; **undocumented on the client page** |
| `connect_info` | bool | — | "this is the server INFO response to CONNECT"; **undocumented** |
| `remote_account` | string | client, leaf | the account the remote binds to |
| `acc_is_sys` | bool | — | the account is the system account; **undocumented** |
| `api_lvl` | int | all | the JetStream API level — **4** at 2.14.6; **undocumented**, and on the default INFO |
| `xkey` | string | client, leaf | the server's x25519 public key; **undocumented**, and on the default INFO |

### Route-specific

`import`, `export`, `lnoc`, `lnocu`, `info_on_connect`, `route_pool_size`, `route_pool_idx`,
`route_account`, `route_acc_add_reqid`, `gossip_mode`. Only `import` and `export` appear in any doc
page. `route_pool_size` is 3 by default (observed) — see [[nats-server-2.10]] for route pooling.

### Gateway-specific

`gateway`, `gateway_urls`, `gateway_url`, `gateway_cmd`, `gateway_cmd_payload`, `gateway_nrp`,
`gateway_iom`. `gateway_url` is a bare `host:port`, **not** the `nats-gw://…` form
`reference/protocols/gateway.md:50` gives. `gateway_cmd` is `1` gossip, `2` all-subs-start,
`3` all-subs-complete (`gateway.go:88–90`). `gateway_iom: true` says every account goes to
interest-only mode at once — see *Gateway interest* below.

### Leafnode-specific

`leafnode_urls`, plus `xkey`. Undocumented.

### The trailing space

`generateInfoJSON` joins `["INFO", <json>, "␍␊"]` with `" "` (`util.go:360–364`), so **an `INFO` line
carries a space between the JSON and its CRLF**. The gateway path formats
`InfoProto = "INFO %s" + _CRLF_` (`route.go:129`) and does not. A parser that trims whitespace is
fine; one that assumes the byte after `}` is `\r` is not.

### What one actually looks like

```
INFO {"server_id":"NA4H…","server_name":"WP1","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":5,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XDHX…"} 
```

That is a **default** standalone server, no config beyond a port.

---

## `CONNECT` — the fields a client sends

`ClientOpts`, `client.go:675–704` — 22 fields. **None is required.** `CONNECT {}` is accepted; a
`CONNECT` whose JSON does not parse gets no `-ERR` at all, only a closed socket.

| field | type | omitted means | notes |
|---|---|---|---|
| `verbose` | bool | **`true`** | `defaultOpts`, `client.go:706` — an omitted `verbose` gives you `+OK` per op |
| `pedantic` | bool | **`true`** | |
| `echo` | bool | **`true`** | `false` suppresses delivery of your own publishes to your own subs |
| `tls_required` | bool | `false` | |
| `nkey`, `jwt`, `sig` | string | absent | `sig` answers the `nonce` from `INFO` |
| `auth_token`, `user`, `pass` | string | absent | |
| `name`, `lang`, `version` | string | `""` | `lang` is how the server tells a client from a route |
| `protocol` | int | `0` | must be `0` or `1`; anything else is `invalid client protocol` |
| `headers` | bool | `false` | |
| `no_responders` | bool | `false` | requires `headers` |
| `account`, `new_account` | string, bool | absent | **an error if set** — see below |
| `import`, `export` | perm | absent | routes and leafnodes only |
| `remote_account` | string | absent | leafnodes only |
| `proxy_sig` | string | absent | undocumented |

The `Required` column of `reference/protocols/client.md:107–124` has no counterpart in the server.

**`account` / `new_account` are now rejected.** "we used to have this as an optional feature for
dynamic sandbox environments. Now its considered an error" (`client.go:2387–2392`) — the client gets
`-ERR 'Authorization Violation'`.

### What each kind sends

```
client (nats CLI 0.4.0)
  CONNECT {"verbose":false,"pedantic":false,"tls_required":false,"name":"NATS CLI Version 0.4.0","lang":"go","version":"1.51.0","protocol":1,"echo":true,"headers":true,"no_responders":true}
route
  CONNECT {"echo":true,"verbose":false,"pedantic":false,"tls_required":false,"headers":true,"name":"<server id>","cluster":"HUBC","lnoc":true}
gateway
  CONNECT {"echo":false,"verbose":false,"pedantic":false,"tls_required":false,"headers":false,"name":"<server id>","cluster":"","gateway":"CB"}
```

A route and a gateway send **no `lang` and no `version`** — and that absence is the mechanism:
"Client provide Lang in the CONNECT protocol while ROUTEs don't" (`route.go:3022–3028`).
`reference/protocols/route.md:73–74` and `gateway.md:83–84` list both.

The **leafnode** CONNECT is a different struct (`leafConnectInfo`, `leafnode.go:2171–2208`) and three
of its documented names are wrong: the compression field is **`compress_mode`** (the old
`compression` tag "has never been used"), `hub` is **`is_hub`**, `proto` is **`protocol`**. `deny_pub`
and `isolate` are real and undocumented.

---

## `-ERR` — every string, its setting, and whether the connection survives

An `-ERR` is `-ERR '<message>'␍␊` (`errProto`, `client.go:94`). At v2.14.6 there are **60** places one
is written: 58 through `sendErr` / `sendErrAndDebug` / `sendErrAndErr`, and two direct
`enqueueProto` calls for `Stale Connection` (`client.go:5867`, `:5908`).

**Strings are case-sensitive and inconsistently cased on purpose.** A message that comes from an
`errors.New(…)` in `server/errors.go` is lowercase; one written as a literal at the call site is
Title Case. Match on the exact bytes below, not on the documentation's Title-Case rendering.

### What a client can be sent

"open" = the connection was still usable afterwards, observed.

| `-ERR '…'` | provoked by | setting · default | open |
|---|---|---|---|
| `Unknown Protocol Operation` | an unknown verb | — | no |
| `Invalid Subject` | `SUB foo. 1` | — | **yes** |
| `Invalid Publish Subject` | `PUB foo..bar 1`, `PUB foo.* 1` | — | **yes** |
| `Permissions Violation for Subscription to "x"` | a `SUB` outside `allow` | `permissions` | **yes** |
| `Permissions Violation for Subscription to "x" using queue "Q"` | a queue `SUB` outside `allow` | `permissions` | **yes** |
| `Permissions Violation for Publish to "x"` | a `PUB` outside `allow` | `permissions` | **yes** |
| `Permissions Violation for Publish with Reply of "x"` | a reply subject outside `allow` | `permissions` | **yes** |
| `Permissions Violation for Subscription to "x", too many tokens` | too many subject tokens | `permissions` | **yes** |
| `maximum subscriptions exceeded` | one `SUB` too many | `max_subscriptions` · `0` (unlimited) | **yes** |
| `maximum connections exceeded` | one connection too many | `max_connections` · `65536` | no |
| `maximum account active connections exceeded` | one connection too many, in one account | account limits | no |
| `maximum control line exceeded` | an over-long argument line | `max_control_line` · `4096` | no |
| `Maximum Payload Violation` | an over-long payload | `max_payload` · `1MB` | no |
| `Authentication Timeout` | no `CONNECT` in time | `authorization { timeout }` · `2s` | no |
| `Authorization Violation` | **any** auth failure, and `account` in `CONNECT` | — | no |
| `User Authentication Expired` | the user JWT expired | — | no |
| `Account Authentication Expired` | the account JWT expired | — | no |
| `User Authentication Revoked` | the user was revoked | — | no |
| `invalid client protocol` | `protocol` outside `[0,1]` | — | no |
| `no responders requires headers support` | `no_responders` without `headers` | — | no |
| `Stale Connection` | `ping_max` + 1 unanswered pings | `ping_interval` · `2m`, `ping_max` · `2` | no |
| `Failed Account Registration` | — | — | no |
| `Connection throttling is active. Please try again later.` | connection rate limiting | — | no |
| `attempted to connect to route port` | a client `CONNECT` on 6222 | — | no |
| `attempted to connect to leaf node port` | a client `CONNECT` on 7422 | — | no |
| `attempted to connect to gateway port` | a client `CONNECT` on 7222 | — | no |

Four of these leave the connection **usable**. A client that tears down on every `-ERR` throws away a
working connection on a permissions or `max_subscriptions` rejection.

**`max_control_line` is multiplied by 16 for every non-client kind** (`parser.go:1276–1284`) — the
4 KB default is a 64 KB allowance on a route, gateway or leaf.

**The `sid` is not in the live permission strings.** `client.go:5792–5803` formats them without one;
the two `(sid "…")` variants (`client.go:6146`, `:6149`) come from a **config reload** that revokes
permissions on subscriptions that already exist.

### Errors sent only to a server-to-server connection

`Invalid Subscription` · `Stale Leaf Node Connection - Closing` · `cluster name cannot contain spaces`
· `remote leafnode has same cluster name` · `connection rejected since minimum version required is
"x"` · `Duplicate Remote LeafNode Connection` · `Rejecting connection, cluster name "x" does not match
"y"` · `Rejecting connection from gateway "x" on the Route port` · `Rejecting connection from gateway
"x" on the leafnode port` · `Connection to gateway "x" rejected` · `Attempt to connect to gateway "x"
using wrong port` · `Connection from "x" rejected, wanted to connect to "y", this is "z"` ·
`No route for account "x"` · `Unable to lookup account "x": <err>` · `Account absent from
receive-all-subscriptions-<cmd> command`.

### Strings the documentation lists that the server never sends

| documented | where | what the server does |
|---|---|---|
| `Authorization Timeout` | `client.md:424` | sends `Authentication Timeout` |
| `Maximum Connections Exceeded` | `client.md:430` | sends `maximum connections exceeded` |
| `Attempted To Connect To Route Port` | `client.md:422` | sends `attempted to connect to route port` |
| `Invalid Client Protocol` | `client.md:425` | sends `invalid client protocol` |
| `Maximum Control Line Exceeded` | `client.md:426` | a `ClosedState` name (`monitor.go:2650`); the wire gives `maximum control line exceeded` |
| `Parser Error` | `client.md:427` | a `ClosedState` name (`monitor.go:2639`); the wire gives `Unknown Protocol Operation` |
| `Slow Consumer` | `client.md:431` | **nothing** — see [[slow-consumer-in-the-client]] |
| `Secure Connection - TLS Required` | `client.md:428` | composed (`server.go:3684`) and then **discarded**: `TLSHandshakeError` is in `markConnAsClosed`'s skip-flush set |
| `Maximum Payload Exceeded` | `gateway.md:301`, `leafnode.md:395` | the literal is `Maximum Payload Violation` |
| `Invalid Account`, `Gateway Protocol Error` | `gateway.md:298–299` | absent from `gateway.go` |
| `Loop Detected`, `Leafnode Not Allowed` | `leafnode.md:393,397` | absent from `leafnode.go` |
| `Permissions Violation` (bare) | `leafnode.md:392` | the leaf forms name the subject |

### Five ways a connection dies with no `-ERR` at all

`markConnAsClosed` sets `skipFlushOnClose` for `ReadError`, `WriteError`,
`SlowConsumerPendingBytes`, `SlowConsumerWriteDeadline` and `TLSHandshakeError`
(`client.go:2022–2025`). A capture that shows a silent drop is one of these. Observed: a plain client
against a TLS-required server gets **zero bytes** and is dropped at `tls.timeout`.

`-ERR` messages carry **no numeric code**. The `10xxx` codes are JetStream API JSON — see
[[error-codes]].

---

## `PING` / `PONG`

| kind | pings on a timer | traffic counts as a PONG | interval ceiling |
|---|---|---|---|
| client | yes | **yes** | — |
| route | yes | no | `routeMaxPingInterval` = **30s** |
| gateway | yes | no | `gwMaxPingInterval` = **15s** |
| leafnode (spoke) | yes | no | — |
| leafnode (hub side) | yes | yes | — |

`processPingTimer`, `client.go:5846–5857`. A configured `cluster { ping_interval }` above 30 s is reset
with a warning (`opts.go:2156–2157`).

**The stale rule is `(ping_max + 1) × ping_interval`.** The connection is cut on the timer *after* the
last allowed unanswered ping, not on it. Observed with `ping_interval: 2s, ping_max: 2` — PING at
2.14 s, PING at 4.14 s, `-ERR 'Stale Connection'` at **6.14 s**. With the defaults that is
**6 minutes**, which is what nats.go's own detection measures from the other side
(see [[client-connection-lifecycle]]).

The **first** ping is shortened and randomised: `firstClientPingInterval = 2s` for a client,
`firstPingInterval = 1s` otherwise, plus up to 20 % jitter (`client.go:6994–7029`).

---

## Prefixes seen on the wire

| prefix | meaning | where |
|---|---|---|
| `_INBOX.` | a client's reply subject | [[request-reply]] |
| `$SYS.` | system account requests and events | [[system-subjects]] |
| `$JS.` | the JetStream API and ack subjects | [[js-api-subjects]] |
| `$SRV.` | the services framework's discovery, stats and info requests | [[services-on-core-nats]] |
| `$LDS.<nuid>` | leafnode loop detection, one per account | [[leafnode]] |
| `_GR_.<cluster hash>.<server hash>.` | a reply mapped across a gateway | [[gateway]] |
| `$GR.` | the **old** mapped-reply prefix (`oldGWReplyPrefix`) | — |
| `$GNR.` | a name that survives only in source comments | — |

`$LDS.`, `$GR.` and `_GR_.` are exempt from permission checks on a leafnode `LS+`
(`leafnode.go:2969`).

---

## Gateway interest

`A+ <account>` and `A- <account>` are the account-level interest verbs: `A-` says "no interest in this
account at all, stop sending"; `A+` cancels it (`gateway.go:2795–2809`, `:2302–2318`).

**Optimistic mode is history.** Since **2.9.0** the server sets `gateway_iom: true` unconditionally —
"this server will switch all accounts to InterestOnly mode when accepting an inbound or when a new
account is fetched" (`gateway.go:552–558`) — and the flag was observed on a 2.14.6 gateway listener.
The `RS-` threshold `reference/protocols/gateway.md:257` describes without naming,
`defaultGatewayMaxRUnsubBeforeSwitch = 1000` (`gateway.go:41`), belongs to the path that is no longer
entered between two 2.9+ servers. The `gateway_cmd` 2 / 3 handshake still carries the transition.

A reply crossing a gateway is rewritten to
`_GR_.<6-char cluster hash>.<6-char server hash>.<original reply>` and rewritten back on the way home:

```
CA  RMSG $G x.svc + _GR_.DdEU99.DSpI1m._INBOX.IyBx… NATS-RPLY-22 3
CB  RMSG $G _GR_.DdEU99.DSpI1m._INBOX.IyBx… 8
```

---

## Compression

Eight names (`server.go:444–452`): `not supported`, `off`, `accept`, `s2_auto`, `s2_uncompressed`,
`s2_fast`, `s2_better`, `s2_best`. Aliases accepted: `on` / `enabled` / `true` (→ the context's
default), `disabled` / `false` (→ `off`), `not_supported`. Defaults: **`accept`** on a cluster,
**`s2_auto`** on a leafnode and on each leafnode remote (`opts.go:6062–6108`).

`s2_auto` picks a level from measured RTT: ≤10 ms → uncompressed, ≤50 ms → fast, ≤100 ms → better,
above → best (`server.go:457–464`). This is why a route's ping interval is capped at 30 s: `s2_auto`
needs the RTT measurement.

`reference/protocols/leafnode.md:291–296` lists six of the eight, omitting `s2_best` and
`not supported`, and no aliases.

---

## Leafnode reconnect delays

Four constants, all in `leafnode.go:48–67`; the docs call three of them "a 30-second reconnection
delay" and omit the fourth.

| after | delay |
|---|---|
| a loop detected via `$LDS.` | `30s` |
| a permissions violation | `30s` |
| the hub having the same cluster name | `30s` |
| a `min_version` rejection | `5s` |

---

## The one socket option, which the server does not set

`TCP_NODELAY` is **on** — Nagle disabled — on every connection of every kind, and no configuration
key changes it. The server never calls `SetNoDelay`: a grep of the whole v2.14.6 tree for
`SetNoDelay`, `NoDelay` and `TCP_NODELAY` returns nothing. Go does it instead, in
`net.newTCPConn` — `setNoDelay(fd, true)` on every accepted and every dialled `*TCPConn`
(`$GOROOT/src/net/tcpsock.go:289–290`, go1.27.0) — so client, route, leafnode, gateway, WebSocket
and MQTT sockets all inherit it (source: [[s-nats-server-tcp-nodelay]]). The values on
[[defaults-and-limits]] carry the same row.

That is the whole socket-option surface this reference covers: everything else on the wire is the
verbs above.


## Smoke-testing a port

The `INFO` line is free and identifies the listener:

```
nc 127.0.0.1 4222
```

`proto: 1` and a `client_ip` → a client port. `proto: 3` with `lnoc` / `route_pool_size` → a route
port. `proto: 3` with `nonce`, `compression` and `leafnode_urls` → a leafnode port. `gateway` and
`gateway_urls`, and no trailing space → a gateway port.

To go further without a client library, `raw/nats-server-src/wire-protocol-raw.py` sends exactly what
it is told to and timestamps every reply.

---

## How this was derived

- **The source**: `raw/nats-server-src/wire-protocol-v2.14.6.md` — 30 verbatim ranges from
  `server.go`, `client.go`, `parser.go`, `route.go`, `gateway.go`, `leafnode.go`, `const.go` and
  `util.go` at tag `v2.14.6`, taken from the release tarball `tools/check-defaults.py` keeps in
  `.cache/nats-server-2.14.6/`. Every line reference above is that tag. Regenerate for a new release
  by re-reading the same symbols: `type Info struct`, `type ClientOpts struct`, `defaultOpts`,
  `processConnect`, `markConnAsClosed`, `processPingTimer`, `setFirstPingTimer`,
  `overMaxControlLineLimit`, `type connectInfo struct`, `addRouteSubOrUnsubProtoToBuf`,
  `type leafConnectInfo struct`, `processLeafSub`, `processLeafMsgArgs`, and the const blocks of
  `const.go`, `gateway.go` and `leafnode.go`.
- **The `-ERR` inventory**: `raw/nats-server-src/client-errors-v2.14.6.md`, generated by matching
  `sendErr(`, `sendErrAndDebug(` and `sendErrAndErr(` across `server/*.go` (tests excluded), **plus**
  the two direct `enqueueProto(… errProto …)` sites this page adds.
- **The runs**: `raw/nats-server-src/wire-protocol-observed-v2.14.6.md`, seven passes on
  nats-server v2.14.6 on 2026-09-04, with `wire-protocol-runA.sh` … `-runG.sh` and
  `wire-protocol-raw.py` beside it. The verb traces are the server's own `-DV` output.
- **The docs it is checked against**: `raw/nats-docs/reference/protocols/client.md`, `/route.md`,
  `/gateway.md`, `/leafnode.md`, fetched 2026-08-31.

## Related

[[core-nats-delivery]] · [[client-connection-lifecycle]] · [[client-defaults]] ·
[[defaults-and-limits]] · [[error-codes]] · [[system-subjects]] · [[subject-permissions]] ·
[[gateway]] · [[leafnode]] · [[how-clients-reach-a-cluster]] · [[tls-in-nats]] ·
[[monitoring-endpoints]] · [[request-reply]] · [[queue-groups]]

## Sources

[[s-nats-server-wire-protocol]] · [[s-docs-protocol-client]] · [[s-docs-protocols-internal]] · [[s-nats-server-client-errors]] · [[s-docs-system-errors]] · [[s-nats-server-tcp-nodelay]]
