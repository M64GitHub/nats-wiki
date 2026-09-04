---
title: "nats-server v2.14.6 — the wire protocol: INFO, CONNECT, every verb and every -ERR, read and run"
type: summary
area: [core, topology, clients, interop]
source-path: raw/nats-server-src/wire-protocol-v2.14.6.md
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
author: nats-io/nats-server
article: "30 extracted ranges from server.go, client.go, parser.go, route.go, gateway.go, leafnode.go, const.go and util.go at tag v2.14.6, plus runs A–G in raw/nats-server-src/wire-protocol-observed-v2.14.6.md"
date: 2026-09-04
version: "2.14.6"
tags: [wire-protocol, INFO, CONNECT, -ERR, RS+, LS+, LMSG, HMSG, RMSG, gateway_iom, lnocu, ping, max_control_line]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# nats-server v2.14.6 — the wire protocol, read and run

The authority for [[wire-protocol]]: what the server actually puts on a socket, read from the source
at the tag and then provoked on the binary. Written for step 5 of
`inbox/plan-the-client-side-2026-09-03.md`. Extends [[s-nats-server-client-errors]] (step 4), which
listed the `-ERR` strings; this summary adds the `INFO` and `CONNECT` fields, the verbs of all four
connection kinds, and the settings behind each error.

## Key claims

### One `Info` struct, four connection kinds

`type Info struct` (`server.go:108–165`) has **49 JSON fields** in four blocks the struct comments
themselves label: the common block, `// Route Specific` (`import`, `export`, `lnoc`, `lnocu`,
`info_on_connect`, `route_pool_size`, `route_pool_idx`, `route_account`, `route_acc_add_reqid`,
`gossip_mode`), `// Gateways Specific` (`gateway`, `gateway_urls`, `gateway_url`, `gateway_cmd`,
`gateway_cmd_payload`, `gateway_nrp`, `gateway_iom`) and `// LeafNode Specific` (`leafnode_urls`),
plus `xkey`. Everything but `server_id`, `server_name`, `version`, `proto`, `go`, `host`, `port`,
`headers` and `max_payload` is `omitempty`, so what a client sees is a function of the deployment.

**Observed, a standalone default server's greeting to a client:**

```
INFO {"server_id":"NA4H…","server_name":"WP1","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":5,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XDHX…"} 
```

`api_lvl` (the JetStream API level, 4 at 2.14.6) and `xkey` (the server's x25519 public key) are on
the **default** INFO.

**An INFO line ends with a space before its CRLF.** `generateInfoJSON` joins
`[]byte("INFO")`, the JSON and `CR_LF` with `" "` as separator (`util.go:360–364`), so the third join
inserts a space. The gateway path uses `InfoProto = "INFO %s" + _CRLF_` (`route.go:129`) and has
none. Both observed.

### `CONNECT`: nothing is required, and three fields default to true

`ClientOpts` (`client.go:675–704`) has 22 fields. `json.Unmarshal` merges into a struct pre-seeded
with `var defaultOpts = ClientOpts{Verbose: true, Pedantic: true, Echo: true}` (`client.go:706`), so
**`CONNECT {}` is verbose, pedantic and echoing**. Observed: `CONNECT {}` followed by `PING` returns
`+OK` then `PONG`.

Three rejections, all observed:

| sent | `-ERR` |
|---|---|
| `protocol` outside `[0, 1]` | `invalid client protocol` |
| `account` or `new_account` set | `Authorization Violation` — "we used to have this as an optional feature for dynamic sandbox environments. Now its considered an error" (`client.go:2387–2392`) |
| `no_responders: true` without `headers` | `no responders requires headers support` |

A `CONNECT` whose JSON does not parse gets **nothing** — `processConnect` returns the unmarshal error
and the socket is closed silently.

### The `-ERR` inventory is 60 sites, not 58

`errProto = "-ERR '%s'" + _CRLF_` (`client.go:94`). Fifty-eight sites go through `sendErr` /
`sendErrAndDebug` / `sendErrAndErr` — the table in [[s-nats-server-client-errors]] — and **two do
not**: `Stale Connection` is written with `c.enqueueProto` directly, at `client.go:5867`
(`processPingTimer`) and `client.go:5908` (`watchForStaleConnection`). This corrects the completeness
claim of that step's extract.

**Five close reasons throw the pending `-ERR` away.** `markConnAsClosed` sets `skipFlushOnClose` for
`ReadError`, `WriteError`, `SlowConsumerPendingBytes`, `SlowConsumerWriteDeadline` and
`TLSHandshakeError` (`client.go:2022–2025`). Step 4 found the two slow-consumer cases; the fifth means
**`Secure Connection - TLS Required` cannot reach a client at v2.14.6**: `server.go:3684` composes it
and `server.go:3685` discards it. Observed (C16): a client that opens a socket to a TLS-required
server and never handshakes gets **no bytes at all**, and is dropped when `tls.timeout` expires — at
2002.8 ms with `timeout: 2`.

### The settings behind the errors, and whether the socket survives

Sixteen errors were provoked (run C). The recoverable ones are the surprise:

| `-ERR` | setting | default | socket survives |
|---|---|---|---|
| `Invalid Subject` | — | — | **yes** |
| `Invalid Publish Subject` | — | — | **yes** |
| `Permissions Violation for Subscription to %q [using queue %q]` | `permissions` | — | **yes** |
| `Permissions Violation for Publish to %q` | `permissions` | — | **yes** |
| `maximum subscriptions exceeded` | `max_subscriptions` | 0 (unlimited) | **yes** |
| `Unknown Protocol Operation` | — | — | no |
| `maximum connections exceeded` | `max_connections` | `DEFAULT_MAX_CONNECTIONS = 64 * 1024` | no |
| `Authentication Timeout` | `authorization { timeout }` | `AUTH_TIMEOUT = 2s` | no |
| `Authorization Violation` | any auth failure | — | no |
| `maximum control line exceeded` | `max_control_line` | `MAX_CONTROL_LINE_SIZE = 4096` | no |
| `Maximum Payload Violation` | `max_payload` | `MAX_PAYLOAD_SIZE = 1MB` | no |
| `Stale Connection` | `ping_interval` / `ping_max` | `2m` / `2` | no |

`max_control_line` is **multiplied by 16 for every non-client kind** (`parser.go:1276–1284`) — a 64 KB
allowance on a route, gateway or leaf, "which matches maxBufSize so a single oversized read is caught
on the very next parse call". The `-ERR` carries the plain `maximum control line exceeded` text; the
`State %d, max_control_line %d, Buffer len %d (snip: …)` context built by `NewErrorCtx` goes to the
log, not the wire.

The live permission strings carry **no sid**: `Permissions Violation for Subscription to "nope"`
(`client.go:5792–5803`). The two `(sid %q)` forms (`client.go:6146`, `:6149`) belong to the
config-reload path, when a reload revokes permissions on subscriptions that already exist.

### Ping: the kind decides everything

`processPingTimer` (`client.go:5821–5879`): **`ROUTER`, `GATEWAY` and a spoke `LEAF` ping
unconditionally**; only a client's inbound traffic counts as a PONG. The ceilings differ —
`routeMaxPingInterval = 30s` (`route.go:140`, `:147`) and `gwMaxPingInterval = 15s`
(`gateway.go:58`) cap whatever `ping_interval` is configured, and `opts.go:2156–2157` warns when a
`cluster { ping_interval }` above 30 s is reset.

The stale rule is `ping.out + 1 > maxPingsOut` — **the interval after the last allowed unanswered
ping**. Observed with `ping_interval: 2s, ping_max: 2`: PING at 2137.9 ms, PING at 4138.6 ms,
`-ERR 'Stale Connection'` at **6139.9 ms**. That is `(ping_max + 1) × ping_interval`, and it is the
server-side counterpart of nats.go's own six minutes (step 3, D3).

The **first** ping is shortened and randomised: `firstClientPingInterval = 2s` for a client,
`firstPingInterval = 1s` for everything else, plus "up to 20%" of random offset
(`client.go:6994–7029`, `server.go:57–60`).

### The verbs, observed

Route (`-DV`, one subscribe and one publish across a two-node cluster):

```
RS+ $G orders.new                 RS- $G orders.new
RS+ $G work.> WORKERS 1           RS- $G work.> WORKERS
RMSG $G orders.new 11
RMSG $G work.a | WORKERS 6
```

Leafnode:

```
LS+ edge.ping                     LS- edge.ping
LS+ edge.work W 1                 LS- edge.work W
LMSG edge.ping 5
LMSG edge.ping answers.here 10
LMSG edge.work | W 6
LMSG edge.svc + _INBOX.… NATS-RPLY-22 3
HMSG edge.ping 22 33
HMSG edge.work | W 18 31
```

`LS+` takes **one or three** arguments, never two (`leafnode.go:2926–2941`). `LMSG` has four shapes,
`+` marking a reply and `|` marking the queue list (`leafnode.go:3233–3269`); a leaf's **header**
messages are `HMSG` (`parser.go:381–385`).

The same leaf subscriptions carried on the route show the origin cluster **first**:

```
LS+ LEAF1 $G edge.ping            LS- LEAF1 $G edge.work W
```

`LS+`/`LS-` with an origin are a **route** feature (`c.route.lnoc` / `c.route.lnocu`,
`route.go:1729–1740`), advertised as `lnoc` / `lnocu` in the route INFO.

Gateway, with a request crossing it:

```
RS+ $G x.svc NATS-RPLY-22 1
RMSG $G x.svc + _GR_.DdEU99.DSpI1m._INBOX.IyBx…ZK2utkMz NATS-RPLY-22 3
RMSG $G _GR_.DdEU99.DSpI1m._INBOX.IyBx…ZK2utkMz 8
```

The mapped reply is `_GR_.<6-char cluster hash>.<6-char server hash>.<original reply>`
(`gateway.go:47–52`). `$GR.` is `oldGWReplyPrefix` (`gateway.go:43`); `$GNR.` appears only in comments
(`gateway.go:148`, `server.go:158`).

### Interest-only is the default since 2.9.0

`info.GatewayIOM = true` is set unconditionally outside tests, and the comment dates it: "we are now
(since v2.9.0) indicate that this server will switch all accounts to InterestOnly mode when accepting
an inbound or when a new account is fetched" (`gateway.go:552–558`). Observed as
`"gateway_iom":true` on the gateway listener's INFO. `defaultGatewayMaxRUnsubBeforeSwitch = 1000`
(`gateway.go:41`) is the older, optimistic path's threshold, and `A+` / `A-` were **not** observed —
that path is not entered when both sides advertise the flag.

### Wrong port, and the order of the checks

| dialled | with | `-ERR` |
|---|---|---|
| route port | a CONNECT carrying `lang` | `attempted to connect to route port` (`route.go:3022–3028`) |
| gateway port | the same | `attempted to connect to gateway port` |
| leafnode port, no auth | the same | `attempted to connect to leaf node port` |
| leafnode port, auth required | the same | **`Authorization Violation`** — `checkAuthentication` runs first |
| route port | `{"cluster":"WRONGNAME"}` | `Rejecting connection, cluster name "WRONGNAME" does not match "WPC"` |
| route port | `{"gateway":"OTHER"}` | `Rejecting connection from gateway "OTHER" on the Route port` |

The mechanism is `lang`: "Client provide Lang in the CONNECT protocol while ROUTEs don't".

## Practical takeaways

- **`nc <host> <port>` is a complete port smoke test.** The INFO line names the server, its version,
  its cluster and its kind, and costs nothing.
- **`-ERR` is not `err_code`.** Nothing on this wire carries a numeric code; the `10xxx` codes are
  JetStream API JSON (see [[error-codes]]).
- Four `-ERR`s leave the connection usable. A client that closes on every `-ERR` is throwing away a
  working connection on a permissions or `max_subscriptions` rejection.
- A capture that shows a client-side timeout with **no** `-ERR` is one of five cases: a slow consumer
  (two branches), a read or write error, or a TLS handshake that never completed.

## Relevance to the wiki

The whole of [[wire-protocol]]; the interest-only correction on [[gateway]]; the `$LDS.` and delay
corrections on [[leafnode]]; the `-ERR` column on [[defaults-and-limits]]; the ping arithmetic on
[[client-connection-lifecycle]] and [[client-defaults]].

## Questions it answers

Bank rows 183, 184, 185, 186, 187.

## Pages touched

[[wire-protocol]], [[gateway]], [[leafnode]], [[client-connection-lifecycle]], [[client-defaults]],
[[defaults-and-limits]], [[error-codes]], [[subject-permissions]], [[tls-in-nats]],
[[how-clients-reach-a-cluster]], [[build-a-3-node-cluster]], [[monitoring-endpoints]],
[[system-subjects]], [[duplicate-messages-across-a-leafnode]],
[[supercluster-slows-when-a-remote-subscriber-joins]], [[core-nats-delivery]], [[nats-server]],
[[nats-server-2.10]].

## Sources

- `raw/nats-server-src/wire-protocol-v2.14.6.md` — 30 verbatim ranges at tag v2.14.6
- `raw/nats-server-src/wire-protocol-observed-v2.14.6.md` — runs A–G on nats-server v2.14.6, 2026-09-04
- Extends [[s-nats-server-client-errors]]; the docs it sweeps are [[s-docs-protocol-client]] and
  [[s-docs-protocols-internal]].
