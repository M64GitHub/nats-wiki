<!-- observed run · nats-server v2.14.6 (`nats-server --version` → `nats-server: v2.14.6`), nats CLI 0.4.0 (which pins nats.go v1.51.0, visible in its own CONNECT below) · macOS 15 (darwin/arm64) · 2026-09-04 -->
# nats-server v2.14.6 observed — the wire protocol: what each listener offers, what a CONNECT must carry, every `-ERR` provoked, and the verbs a route, gateway and leafnode actually exchange

Runs for step 5 of `inbox/plan-the-client-side-2026-09-03.md`. The source side is
`raw/nats-server-src/wire-protocol-v2.14.6.md`; the `-ERR` string list is
`raw/nats-server-src/client-errors-v2.14.6.md`.

Seven passes, all on one machine, all against the same binary:

| pass | script | what it does |
|---|---|---|
| A | `wire-protocol-runA.sh` | the `INFO` line every listener offers — client, leafnode, route, gateway — standalone and clustered |
| B | `wire-protocol-runB.sh`, `-runB2.sh` | what a `CONNECT` must carry, and what an omitted field means |
| C | `wire-protocol-runC.sh`, `-runC2.sh` | every `-ERR` a client can be sent, provoked, with the exact bytes and whether the socket survives |
| D | `wire-protocol-runD.sh` | the wrong-port rejections, and whether an "unrecoverable" `-ERR` really closes the socket |
| E | `wire-protocol-runE.sh` | `RS+` / `RS-` / `RMSG` and `LS+` / `LS-` / `LMSG` from the server's own `-DV` trace |
| F | `wire-protocol-runF.sh` | the header, queue and reply forms on a leafnode |
| G | `wire-protocol-runG.sh` | the gateway verbs and the mapped reply prefix, across two clusters |

The raw client is `wire-protocol-raw.py` — it sends nothing it is not told to, prints every line with
a millisecond stamp relative to connect, and answers `PING` only with `--pong`. The configs are quoted
inline at each scene. Transcripts and per-scene server logs are the unedited originals in the
maintainer's scratch (`local/scratch/runs/wire-protocol/`, not public); everything quoted below is
copied verbatim from them.

---

## A · The `INFO` line, per listener

### A1 · a standalone server, client port

```
port: 14222
http: 18222
server_name: WP1
```

```
[     1.6 ms] << INFO {"server_id":"NA4HSTPPVQJSOEE2542QFCQX6Y5T5UV2FZA3B43AEN5XBX7VHF5ZLQZ4","server_name":"WP1","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":5,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XDHXU3CTJ3XQE5ZVFTB4LAVNMHKYBJ7VWLL7DJF7SH2O2HCP37YV3HXE"} 
```

Thirteen fields. `client_ip`, `api_lvl` and `xkey` are on the **default** INFO and appear in no row of
`reference/protocols/client.md`'s table. `auth_required`, `tls_required`, `tls_verify` and
`tls_available` are absent — they are `omitempty` and this server has no auth and no TLS.

**The line ends with a space before its CRLF.** The tool prints the line after stripping `\r\n`, and
the trailing space survives; it is `generateInfoJSON`'s third join separator (`util.go:360–364`).

### A2 · the same server clustered, with JetStream, a leafnode port and a gateway

```
port: 14222
http: 18222
server_name: WP1
accounts { SYS: { users: [ { user: sys, password: sys } ] }, APP: { users: [ { user: app, password: app } ] } }
system_account: SYS
cluster { name: WPC, port: 16222, no_advertise: false, routes: [ "nats://127.0.0.1:16223" ] }
leafnodes { port: 17422 }
gateway { name: WPC, port: 17222 }
jetstream { store_dir: "/tmp/wp-store", domain: WPD }
```

```
[     1.3 ms] << INFO {"server_id":"NDTHUEUQXCT5AUKD5GO3IYZP46VB6WMUK3MLV7DVSIHVAD423W6Q7FGX","server_name":"WP1","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"auth_required":true,"max_payload":1048576,"jetstream":true,"client_id":15,"client_ip":"127.0.0.1","cluster":"WPC","domain":"WPD","connect_urls":["192.168.178.61:14222","192.168.178.61:14223"],"api_lvl":4,"xkey":"XAP4KDPNQYYRJNOKCS7JL4OYYJLCLCA6NIY2IY6SL47QLM2T65AQLVIQ"} 
```

`connect_urls` carries the **advertised** address of both nodes, not `host` (`0.0.0.0`).

### A3 · the leafnode listener (17422), same server

```
[     1.4 ms] << INFO {"server_id":"NDTHUEUQXCT5AUKD5GO3IYZP46VB6WMUK3MLV7DVSIHVAD423W6Q7FGX","server_name":"WP1","version":"2.14.6","proto":3,"go":"go1.27.0","host":"192.168.178.61","port":17422,"headers":true,"auth_required":true,"max_payload":1048576,"jetstream":true,"ip":"192.168.178.61:17422","client_id":16,"nonce":"6YvRYf1Bq0leWNs","cluster":"WPC","domain":"WPD","compression":"s2_auto","api_lvl":4,"info_on_connect":true,"leafnode_urls":["192.168.178.61:17422"]} 
```

`proto` is **3**, not the `1` the leafnode page states. `compression` is `s2_auto` — the leafnode
default. `client_id` is present and is simply the connection id (16, one after the client connection
above); `reference/protocols/leafnode.md:50` describes it as "Client ID for compression negotiation".
`info_on_connect` and `leafnode_urls` are documented nowhere.

### A4 · the route listener (16222), same server

```
[     1.4 ms] << INFO {"server_id":"NDTHUEUQXCT5AUKD5GO3IYZP46VB6WMUK3MLV7DVSIHVAD423W6Q7FGX","server_name":"WP1","version":"2.14.6","proto":3,"go":"go1.27.0","host":"0.0.0.0","port":16222,"headers":true,"max_payload":1048576,"jetstream":true,"nonce":"rNk-zhgehGZa1UU","cluster":"WPC","domain":"WPD","connect_urls":["192.168.178.61:14222"],"compression":"accept","lnoc":true,"lnocu":true,"route_pool_size":3,"gateway_url":"192.168.178.61:17222","leafnode_urls":["192.168.178.61:17422"]} 
```

**No `ip` field.** `reference/protocols/route.md:25` says the accepting server "will add an `ip` field
containing the address and port of the connecting server" — that is the *forwarded* INFO of a peer,
not the listener's own greeting. `compression` is `accept`, the cluster default. `lnoc` / `lnocu` /
`route_pool_size` are documented nowhere; `route_pool_size: 3` is the default route pool.

### A5 · the gateway listener (17222), same server

```
[     1.4 ms] << INFO {"server_id":"NDTHUEUQXCT5AUKD5GO3IYZP46VB6WMUK3MLV7DVSIHVAD423W6Q7FGX","server_name":"WP1","version":"2.14.6","proto":3,"go":"","host":"192.168.178.61","port":17222,"headers":true,"max_payload":1048576,"gateway":"WPC","gateway_urls":["192.168.178.61:17222"],"gateway_url":"192.168.178.61:17222","gateway_nrp":true,"gateway_iom":true}
```

Three things at once: `go` is the **empty string** on a gateway INFO; `gateway_url` is a bare
`host:port`, not the `nats-gw://<hostname>:<port>` form `reference/protocols/gateway.md:50` gives;
and this is the **only** INFO of the five with **no trailing space** before its CRLF, because the
gateway path formats `InfoProto` (`route.go:129`) instead of calling `generateInfoJSON`.

`gateway_iom:true` is the flag that says all accounts go to interest-only mode at once.

---

## B · What a `CONNECT` must carry

All on the A1 config.

### B1 · no CONNECT at all

```
[     1.6 ms] >> PING
[     2.4 ms] << PONG
[   603.6 ms] -- socket still open after 0.6s
```

With no auth configured, a connection that never sends `CONNECT` is served.

### B2 · `CONNECT {}` — every "Required: true" field omitted

```
[     1.4 ms] >> CONNECT {}
[     1.4 ms] >> PING
[     1.6 ms] << +OK
[     1.6 ms] << PONG
```

Accepted — **and acknowledged**. The `+OK` is the answer: an omitted `verbose` is `true`
(`defaultOpts`, `client.go:706`), so `CONNECT {}` is a verbose connection. `verbose`, `pedantic` and
`echo` all default to `true`; every other field to its zero value.

### B13 · the same, with traffic

```
[     1.6 ms] >> CONNECT {}
[     1.6 ms] >> SUB foo 1
[     1.6 ms] >> PUB foo 5  +  'hello'
[     1.6 ms] >> UNSUB 1
[     1.6 ms] >> PING
[     1.8 ms] << +OK
[     1.8 ms] << +OK
[     1.8 ms] << +OK
[     1.8 ms] << MSG foo 1 5 | payload: hello\r\n
[     1.8 ms] << +OK
[     1.8 ms] << PONG
```

One `+OK` per well-formed op — `CONNECT`, `SUB`, `PUB`, `UNSUB` — and none for `PING`, which is
answered with `PONG`.

### B14–B16 · `verbose:false`, and what `echo` does

```
B14  >> CONNECT {"verbose":false} / SUB foo 1 / PUB foo 5 'hello' / PING
     << MSG foo 1 5 | payload: hello\r\n
     << PONG
B15  >> CONNECT {"verbose":false} … the publisher is also the subscriber
     << MSG foo 1 2 | payload: hi\r\n
B16  >> CONNECT {"verbose":false,"echo":false} … same subscription, same publish
     << PONG                                    (no MSG)
```

### B17 · lowercase ops

`connect`, `sub`, `ping` all work; the delivery and the `PONG` are identical to B14.

### B18 · `pedantic` defaults to true — a malformed `SUB` subject

```
[     1.4 ms] >> CONNECT {"verbose":false}
[     1.4 ms] >> SUB foo. 1
[     1.4 ms] >> PING
[     1.5 ms] << -ERR 'Invalid Subject'
[     1.5 ms] << PONG
[   602.6 ms] -- socket still open after 0.6s
```

The `PONG` after the `-ERR` is the `Recoverable: Yes` column, observed.

### B20 · `UNSUB <sid> <max>`

```
>> SUB foo 1 / UNSUB 1 2 / PUB foo a / PUB foo b / PUB foo c / PING
<< MSG foo 1 1 | payload: a\r\n
<< MSG foo 1 1 | payload: b\r\n
<< PONG
```

Two delivered, the third dropped: the auto-unsubscribe counts *deliveries*, and it is armed before
any message arrives.

### B5–B9 · the CONNECT rejections

| sent | received |
|---|---|
| `CONNECT {"protocol":2}` | `-ERR 'invalid client protocol'`, socket closed |
| `CONNECT {"protocol":-1}` | `-ERR 'invalid client protocol'`, socket closed |
| `CONNECT {"account":"APP"}` | `-ERR 'Authorization Violation'`, socket closed |
| `CONNECT {"no_responders":true,"headers":false}` | `-ERR 'no responders requires headers support'`, socket closed |
| `CONNECT {oops}` | **nothing at all** — the socket is closed with no `-ERR` |

The last is `json.Unmarshal` failing inside `processConnect`, which returns the error rather than
sending one.

### B12 · a second `CONNECT` on a live connection

```
>> CONNECT {} / SUB foo 1 / CONNECT {"verbose":true} / PING
<< +OK  +OK  +OK  PONG
```

Accepted; the connection stays up.

---

## C · Every `-ERR` a client can be sent

One config per scene, quoted at the row. "open?" is whether the socket was still readable at the end
of the scene.

| # | config | provocation | on the wire | open? |
|---|---|---|---|---|
| C1 | — | `FOO bar` | `-ERR 'Unknown Protocol Operation'` | no |
| C2 | — | `SUB foo. 1` | `-ERR 'Invalid Subject'` | **yes** |
| C3 | — | `PUB foo..bar 1` | `-ERR 'Invalid Publish Subject'` | **yes** |
| C4 | — | `PUB foo.* 1` | `-ERR 'Invalid Publish Subject'` | **yes** |
| C5 | — | `UNSUB 99` (no such sid) | nothing; `PONG` follows | **yes** |
| C6 | `max_connections: 1` | a second connection | `-ERR 'maximum connections exceeded'` | no |
| C15 | `authorization { user: u, password: p, timeout: 1 }` | send nothing at all | `-ERR 'Authentication Timeout'` at **1003.0 ms** | no |
| C7b | the same | `CONNECT {"user":"u","pass":"WRONG"}` | `-ERR 'Authorization Violation'` | no |
| C18 | `max_control_line: 1024` | a 2000-byte `SUB` argument | `-ERR 'maximum control line exceeded'` | no (D6) |
| C9 | `max_payload: 128` | `PUB foo 200` | `-ERR 'Maximum Payload Violation'` | no |
| C19 | `max_subscriptions: 2` | a third `SUB` | `-ERR 'maximum subscriptions exceeded'` | **yes** |
| C11 | `permissions { subscribe: { allow: ["can.sub"] } }` | `SUB nope 1` | `-ERR 'Permissions Violation for Subscription to "nope"'` | **yes** |
| C13 | the same | `SUB nope Q 1` | `-ERR 'Permissions Violation for Subscription to "nope" using queue "Q"'` | **yes** |
| C12 | `permissions { publish: { allow: ["can.pub"] } }` | `PUB nope 1` | `-ERR 'Permissions Violation for Publish to "nope"'` | **yes** |
| C16 | `tls { cert_file: …, key_file: …, timeout: 2 }` | never start a handshake | **nothing at all**; socket closed at **2002.8 ms** | no |
| C17 | `ping_interval: "2s", ping_max: 2` | never answer `PING` | `-ERR 'Stale Connection'` at **6139.9 ms** | no |

Six of these are worth their exact transcripts.

**C15 — the authorization timeout.** The string is `Authentication Timeout`, not the
`Authorization Timeout` of `reference/protocols/client.md:424`, and it fires at the configured second:

```
[  1003.0 ms] << -ERR 'Authentication Timeout'
[  1003.1 ms] -- socket closed by the server
```

**C16 — TLS.** With `tls {}` configured and a client that sends bytes but no handshake, nothing is
sent back at all; the connection is dropped when `tls.timeout` expires:

```
[  2002.8 ms] -- socket closed by the server
```

and the server logs only `TLS required for client connections` at startup. `Secure Connection - TLS
Required` never reaches the wire, because `closeConnection(TLSHandshakeError)` sets `skipFlushOnClose`
(`client.go:2023`) and the enqueued `-ERR` is discarded.

**C17 — the stale rule, from the server's side.** With `ping_interval: 2s` and `ping_max: 2`, the
client is cut on the **third** interval, not the second:

```
[     1.6 ms] >> CONNECT {"verbose":false}
[  2137.9 ms] << PING
[  4138.6 ms] << PING
[  6139.9 ms] << -ERR 'Stale Connection'
[  6140.0 ms] -- socket closed by the server
```

Two PINGs go unanswered and the connection survives; the third timer fires, finds `ping.out+1 >
maxPingsOut`, and closes. `(ping_max + 1) × ping_interval` is the rule. The server's log at default
level says nothing about it.

**C19 — `maximum subscriptions exceeded` is recoverable.** The rejected `SUB` is dropped and the
connection keeps working:

```
>> SUB a 1 / SUB b 2 / SUB c 3 / PUB a 'hello' / PING
<< -ERR 'maximum subscriptions exceeded'
<< MSG a 1 5 | payload: hello\r\n
<< PONG
[  2002.9 ms] -- socket still open after 2.0s
```

**C11 / C13 — the permission strings have no `sid`.** The live `SUB` path formats
`Permissions Violation for Subscription to %q` (and `… using queue %q`), `client.go:5792–5803`. The
two forms with `(sid %q)` (`client.go:6146`, `:6149`) are the **config-reload** path, when a reload
revokes permissions on subscriptions that already exist.

**C18 / D6 — `maximum control line exceeded` does close the connection.** In runC the reader gave up
before the FIN arrived; D6 re-ran it with a write 1.5 s later:

```
[     2.0 ms] >> SUB <2000 bytes>
[     2.0 ms] << -ERR 'maximum control line exceeded'
[  1507.8 ms] -- send failed: BrokenPipeError
[  1508.1 ms] -- read: ConnectionResetError
```

The `-ERR` is the plain `ErrMaxControlLine` text; the `State %d, max_control_line %d, Buffer len %d
(snip: …)` context of `NewErrorCtx` does not appear on the wire.

---

## D · The wrong-port rejections

Two clustered servers with the A2 config; a **client-shaped** `CONNECT` (one that carries `lang`) on
each listener.

| port | listener | on the wire |
|---|---|---|
| 16222 | route | `-ERR 'attempted to connect to route port'` |
| 17222 | gateway | `-ERR 'attempted to connect to gateway port'` |
| 17422 | leafnode | `-ERR 'Authorization Violation'` |

The leafnode row is not a different rule; it is **ordering**. `processConnect` runs
`checkAuthentication` before dispatching to `processLeafNodeConnect`, and this deployment's leafnode
port requires auth. On a server with no accounts (E1) the same `CONNECT` gets the expected string:

```
[     1.7 ms] << -ERR 'attempted to connect to leaf node port'
```

Two more rejections on the route port, neither of them in any doc page:

```
CONNECT {"name":"fake","cluster":"WRONGNAME"}
<< -ERR 'Rejecting connection, cluster name "WRONGNAME" does not match "WPC"'

CONNECT {"name":"fake","cluster":"WPC","gateway":"OTHER"}
<< -ERR 'Rejecting connection from gateway "OTHER" on the Route port'
```

### E1b · a leaf-shaped CONNECT on a leafnode port, no auth

```
[     1.2 ms] >> CONNECT {"name":"fake","cluster":"NA1"}
[     1.2 ms] >> PING
[     1.4 ms] << LS+ $SYS.REQ.ACCOUNT.PING.CONNZ
[     1.4 ms] << LS+ $SYS.REQ.ACCOUNT.PING.STATZ
[     1.4 ms] << LS+ $SYS.REQ.SERVER.PING.CONNZ
[     1.4 ms] << LS+ $SYS.REQ.USER.INFO
[     1.4 ms] << LS+ $LDS.7DmzskwZH3rqXncz35KEqQ
[     1.4 ms] << PONG
[  1001.7 ms] -- socket still open after 1.0s
```

The hub accepts it and immediately pushes its interest. **`$LDS.` arrives as an ordinary `LS+`
subject** — there is no `LDS` verb; `reference/protocols/leafnode.md` lists one in its overview table.

---

## E · The route and leafnode verbs, from the server's own `-DV` trace

Two servers in cluster `HUBC` (14222/16222 and 14223/16223), `-DV` on the first; a leaf
(`nats-leaf://127.0.0.1:17422`) added for the second half. Subscriptions made with
`nats sub … --count 1`, publishes with `nats pub` from the *other* server.

### The route's CONNECT — no `lang`, no `version`

```
[TRC] 127.0.0.1:52444 - rid:9 - <<- [CONNECT {"echo":true,"verbose":false,"pedantic":false,"tls_required":false,"headers":true,"name":"NDDCZEMZEOSTEIJM7OJQQMKGKKRQTCIYWA73WL44QS76IFQXSZU6P742","cluster":"HUBC","lnoc":true}]
```

`name` is the remote's **server ID**, not a "generated server name"; `cluster` and `lnoc` are the
route-specific fields; `lang` and `version` — both listed by `reference/protocols/route.md:73–74` —
are absent, and their absence is exactly what tells the server this is not a client
(`route.go:3022–3028`).

For contrast, the CLI's own client CONNECT on the same server:

```
[TRC] 127.0.0.1:52445 - cid:11 - <<- [CONNECT {"verbose":false,"pedantic":false,"tls_required":false,"name":"NATS CLI Version 0.4.0","lang":"go","version":"1.51.0","protocol":1,"echo":true,"headers":true,"no_responders":true}]
```

### `RS+` / `RS-` / `RMSG`

```
cid:11 <<- [SUB orders.new  1]
rid:8  ->> [RS+ $G orders.new]
rid:8  <<- [RMSG $G orders.new 11]
cid:11 ->> [MSG orders.new 1 11]
rid:8  ->> [RS- $G orders.new]

cid:12 <<- [SUB work.> WORKERS 1]
rid:8  ->> [RS+ $G work.> WORKERS 1]
rid:8  <<- [RMSG $G work.a | WORKERS 6]
cid:12 ->> [MSG work.a 1 6]
rid:8  ->> [RS- $G work.> WORKERS]
```

`$G` is the global account. **`RMSG` carries a `|` and the queue names** when the message is for a
queue group — a form `reference/protocols/route.md:133` does not have
(`RMSG <account> <subject> [reply-to] <bytes>`).

### `LS+` / `LS-` / `LMSG` on the leafnode connection, and the same subs on the route

```
lid:11 <<- [LS+ edge.svc NATS-RPLY-22 1]
lid:11 <<- [LS+ edge.ping]
lid:11 <<- [LS+ edge.work W 1]
rid:8  ->> [LS+ LEAF1 $G edge.svc NATS-RPLY-22 1]
rid:8  ->> [LS+ LEAF1 $G edge.ping]
rid:8  ->> [LS+ LEAF1 $G edge.work W 1]
```

The route form is `LS+ <origin cluster> <account> <subject> [queue weight]` — **origin first**.
`reference/protocols/leafnode.md:142` puts it last, and on the leafnode protocol rather than the
route one:  `LS+ <subject> <queue_group> <weight> <origin_cluster>`. The leaf's own `LS+` never
carries a cluster at all.

`LS-` mirrors it:

```
lid:11 <<- [LS- edge.work W]
rid:8  ->> [LS- LEAF1 $G edge.work W]
lid:11 <<- [LS- edge.ping]
rid:8  ->> [LS- LEAF1 $G edge.ping]
```

### The four `LMSG` shapes, and `HMSG` for headers

```
lid:11 ->> [LMSG edge.ping 5]                                                       plain
lid:11 ->> [LMSG edge.ping answers.here 10]                                         reply, no '+'
lid:11 ->> [LMSG edge.work | W 6]                                                   queue
lid:11 ->> [LMSG edge.svc + _INBOX.NdE7GE7EcMTNHiJegg8lA0.DrsNzzjW NATS-RPLY-22 3]  reply + queue
lid:11 ->> [HMSG edge.ping 22 33]                                                   headers
lid:11 ->> [HMSG edge.work | W 18 31]                                               headers + queue
```

Two things the leafnode page does not have: the **three-token reply form without `+`**
(`LMSG <subject> <reply> <size>`, accepted at `leafnode.go:3241–3245`), and **`HMSG`** — the page's
`LMSG <subject> … <header_size> <total_size>` form does not exist, and a three-token `LMSG` would be
parsed as *subject, reply, size*.

### A request across the leafnode, end to end

```
cid:16 <<- [SUB _INBOX.NdE7GE7EcMTNHiJegg8lA0.DrsNzzjW  1]
rid:8  ->> [RS+ $G _INBOX.NdE7GE7EcMTNHiJegg8lA0.DrsNzzjW]
lid:11 ->> [LS+ _INBOX.NdE7GE7EcMTNHiJegg8lA0.DrsNzzjW]
cid:16 <<- [PUB edge.svc _INBOX.NdE7GE7EcMTNHiJegg8lA0.DrsNzzjW 3]
lid:11 ->> [LMSG edge.svc + _INBOX.NdE7GE7EcMTNHiJegg8lA0.DrsNzzjW NATS-RPLY-22 3]
lid:11 <<- [LMSG _INBOX.NdE7GE7EcMTNHiJegg8lA0.DrsNzzjW 4]
cid:16 ->> [MSG _INBOX.NdE7GE7EcMTNHiJegg8lA0.DrsNzzjW 1 4]
rid:8  ->> [RS- $G _INBOX.NdE7GE7EcMTNHiJegg8lA0.DrsNzzjW]
lid:11 ->> [LS- _INBOX.NdE7GE7EcMTNHiJegg8lA0.DrsNzzjW]
```

The inbox subscription is propagated to the route **and** the leaf before the request is published,
and withdrawn on both as soon as the reply is delivered. `NATS-RPLY-22` is the queue group
`nats reply` uses.

One more trace op appears here that is on no wire: `lid:11 <-> [DELSUB edge.ping]` — a `<->` internal
event, not a protocol message.

---

## G · The gateway verbs

Two single-server clusters, `CA` (14222/17222) and `CB` (14223/17223), each seeded with both gateway
URLs, `-DV` on both.

### The gateway's CONNECT

```
gid:6 <<- [CONNECT {"echo":false,"verbose":false,"pedantic":false,"tls_required":false,"headers":false,"name":"NBSYA2VQ3LBA76JKDRTL3ZRZRBVLV53VIRF3FQND2RIW7IV74QMRLGVV","cluster":"","gateway":"CB"}]
```

`gateway` is the field that identifies it; `lang` and `version`, both listed by
`reference/protocols/gateway.md:83–84`, are absent. `echo` is **false** and `headers` **false** on
the gateway CONNECT.

### `RS+` / `RS-` / `RMSG` across the link

```
CB  cid:8  <<- [SUB x.svc NATS-RPLY-22 1]
CB  gid:6  ->> [RS+ $G x.svc NATS-RPLY-22 1]
CA  gid:5  <<- [RS+ $G x.svc NATS-RPLY-22 1]

CA  cid:8  <<- [PUB x.svc _INBOX.IyBx5VO0xuwOgGNU5OhIh3.ZK2utkMz 3]
CA  gid:5  ->> [RMSG $G x.svc + _GR_.DdEU99.DSpI1m._INBOX.IyBx5VO0xuwOgGNU5OhIh3.ZK2utkMz NATS-RPLY-22 3]
CB  gid:6  <<- [RMSG $G x.svc + _GR_.DdEU99.DSpI1m._INBOX.IyBx5VO0xuwOgGNU5OhIh3.ZK2utkMz NATS-RPLY-22 3]
CB  cid:8  ->> [MSG x.svc 1 _INBOX.IyBx5VO0xuwOgGNU5OhIh3.ZK2utkMz 3]

CB  cid:8  <<- [PUB _INBOX.IyBx5VO0xuwOgGNU5OhIh3.ZK2utkMz 8]
CB  gid:5  ->> [RMSG $G _GR_.DdEU99.DSpI1m._INBOX.IyBx5VO0xuwOgGNU5OhIh3.ZK2utkMz 8]
CA  gid:6  <<- [RMSG $G _GR_.DdEU99.DSpI1m._INBOX.IyBx5VO0xuwOgGNU5OhIh3.ZK2utkMz 8]
CA  cid:8  ->> [MSG _INBOX.IyBx5VO0xuwOgGNU5OhIh3.ZK2utkMz 1 8]
```

The reply subject the origin cluster puts on the wire is
`_GR_.<6-char cluster hash>.<6-char server hash>.<original reply>` — here `_GR_.DdEU99.DSpI1m.` in
front of the client's own `_INBOX.…`. The responder answers the mapped subject, and the origin
cluster strips the prefix before delivering. `$GR.` (the old prefix) and `$GNR.` (a name that survives
only in comments) did not appear.

`nats request` reported `Received with rtt 909.334µs`.

**`A+` / `A-` were not observed.** With `gateway_iom:true` (A5) both sides are in interest-only mode
from the start, so the optimistic-mode path that sends `A-` after
`defaultGatewayMaxRUnsubBeforeSwitch = 1000` no-interest replies was never entered. What that path
looks like on the wire is **not tested here**.

---

## What was not tested

- WebSocket transport (`ws_connect_urls`, the `/leafnode` WebSocket path, per-message deflate).
- Compression actually negotiated and engaged — only the advertised `compression` field was read.
- The `A+` / `A-` account verbs, and the `gateway_cmd` 1/2/3 sequence.
- MQTT, and the `$MQTT` subject space.
- A route with `pinned_accounts`, where the account is dropped from the `RS+` / `RMSG` line.
- Any TLS-terminated connection: every capture above is plaintext.
