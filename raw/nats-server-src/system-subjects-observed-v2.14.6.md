<!-- source: nats-server v2.14.6 binary, nats CLI 0.4.0, macOS, 2026-09-03 · the lab cluster of tools/lab/cluster.sh (n1–n3, cluster east) plus a standalone server x1 and a leaf x2 whose configs are in system-subjects-run.sh beside this file -->
# nats-server v2.14.6 — the `$SYS` subjects, observed

The behavioural half of `system-subjects-v2.14.6.md`, for `wiki/reference/system-subjects.md` and the
correction of `wiki/reference/monitoring-endpoints.md` (phase E step 1,
`inbox/plan-the-reference-layer-2026-09-03.md`). Two scenes: the lab cluster started by
`bash tools/lab/cluster.sh up 3` (the `$SYS` user `sys`), and **x1**, a standalone server with two
ordinary accounts (`APP` imports the service `svc.echo` that `SVC` exports with
`latency { sampling: 100%, subject: "svc.latency" }`) and a leafnode listener that a leaf **x2** dials
as the `APP` user — because the lab has no ordinary account and, as `events.go:2543` says, the
account-connections event is never published for `$G`. Every command is in `system-subjects-run.sh`.
Server ids are shortened to `<n1 id>` etc.; nothing else is edited.

## 1 · Which paths the HTTP monitoring port serves

`server.go:3134–3162` registers fifteen `HandleFunc`s. `curl -o /dev/null -w '%{http_code}'` on n1:

```
/varz            200
/statsz          404
/idz             404
/profilez        404
/stacksz         200
/debug/vars      200
/subscriptionsz  200
/expvarz         404
```

`/stacksz` returns a goroutine dump (`goroutine 265 [running]: …server.(*Server).HandleStacksz`);
`/debug/vars` the Go `expvar` page (`{"cmdline": [...], "memstats": {...}}`); `/subscriptionsz` is an
alias of `/subsz` (`server.go:3148`). **`statsz`, `idz` and `profilez` are not HTTP endpoints** — the
docs' `reference/system/monitor.md` lists them among "HTTP monitoring endpoints" reachable at
`http://localhost:8222/<z>`; `wiki/reference/monitoring-endpoints.md` had copied that list.

## 2 · The same three names answer over the system account

`nats --server nats://sys:sys@127.0.0.1:4291 req '$SYS.REQ.SERVER.PING.<Z>' '{}' --replies 3`:

```
### $SYS.REQ.SERVER.PING.IDZ  (body: {})
{"name":"n1","host":"127.0.0.1","id":"<n1 id>"}
{"name":"n2","host":"127.0.0.1","id":"<n2 id>"}
{"name":"n3","host":"127.0.0.1","id":"<n3 id>"}

### $SYS.REQ.SERVER.PING.STATSZ  (body: {})
{"server":{"name":"n1","host":"127.0.0.1","id":"<n1 id>","cluster":"east","ver":"2.14.6",
 "feature_flags":{"js_ack_fc_v2":false,"js_raft_delete_range":false},"jetstream":true,"flags":7,
 "seq":71,"time":"2026-09-03T01:46:41.582054Z"},
 "statsz":{"start":"2026-09-03T03:45:20.781242+02:00","mem":27951104,"cores":10,"cpu":0.4,"connections":1,…}}

### $SYS.REQ.SERVER.PING.VARZ  (body: {})
{"server":{…"seq":78,…},"data":{"server_id":"<n1 id>","server_name":"n1","version":"2.14.6",…}}

### $SYS.REQ.SERVER.PING.PROFILEZ (body: {"name":"goroutine"})
{"server":{"name":"n3",…},"data":{"profile":"H4sIAAAAAAAE/6xXfWwcx3Xv3u2Sj3sU+…   (gzip, base64)

### $SYS.REQ.SERVER.<n1 id>.IDZ  (the per-server form)
{"name":"n1","host":"127.0.0.1","id":"<n1 id>"}

### $SYS.REQ.SERVER.PING.EXPVARZ
{"server":{…},"data":{"memstats":{"Al…      (the request form of /debug/vars)

### $SYS.REQ.SERVER.PING.STACKSZ (2 s)
03:50:50 Sending request on "$SYS.REQ.SERVER.PING.STACKSZ"        (no reply — there is no STACKSZ request)

### $SYS.REQ.SERVER.PING  (the legacy statsz ping, events.go:69)
three replies, the same {"server":…,"statsz":…} body as PING.STATSZ
```

Three envelope shapes, all from `events.go`: **`IDZ` answers with the bare `ServerID`** (`idzReq`,
`:2252`), **`STATSZ` with `{"server", "statsz"}`** (`ServerStatsMsg`, `:150`), every other `<Z>` with
`{"server", "data"}` (`ServerAPIResponse`, `:2125`) — or `{"server", "data": null, "error": {"code",
"description"}}`: `$SYS.REQ.ACCOUNT.APP.JSZ` on x1, which has no JetStream, answered
`"error":{"code":500,"description":"jetstream not enabled…"}`.

## 3 · The account events, on x1

`nats --server nats://sys:sys@127.0.0.1:4299 sub '$SYS.>'` from 03:47:08. Then: the `APP` client
`holder` subscribes (03:47:27) and stays; the `APP` client `requester` sends one `svc.echo` request
(03:47:29) and leaves; a client with a wrong password (03:47:30); the leaf x2 dials (03:47:31); nothing
for the next two minutes; x2 stops (03:49:27). Subjects received, with counts:

```
   1 $SYS.ACCOUNT.$G.DISCONNECT
   5 $SYS.ACCOUNT.$SYS.SERVER.CONNS
   3 $SYS.ACCOUNT.APP.CONNECT
   3 $SYS.ACCOUNT.APP.DISCONNECT
   9 $SYS.ACCOUNT.APP.SERVER.CONNS
   5 $SYS.ACCOUNT.SVC.SERVER.CONNS
   5 $SYS.SERVER.ACCOUNT.$SYS.CONNS
   9 $SYS.SERVER.ACCOUNT.APP.CONNS
   5 $SYS.SERVER.ACCOUNT.SVC.CONNS
   1 $SYS.SERVER.<x1 id>.CLIENT.AUTH.ERR
  15 $SYS.SERVER.<x1 id>.STATSZ
```

**`$SYS.ACCOUNT.{account}.CONNECTIONS`, the subject the docs give for the account-connections
advisory, never appeared.** The event goes out on **both** `$SYS.ACCOUNT.<acc>.SERVER.CONNS` and
`$SYS.SERVER.ACCOUNT.<acc>.CONNS` (`events.go:58–59`, `:2545`), with the same `id` on both, **on every
connect and disconnect and every 30 s while the account has a connection** (`eventsHBInterval`,
`:100`, `:2466`). The `APP` timeline, from the new subject:

```
"timestamp":"2026-09-03T01:47:27.113191Z"   "conns":1,"leafnodes":0,"total_conns":1     holder connects
"timestamp":"2026-09-03T01:47:29.140717Z"   "conns":2,"leafnodes":0,"total_conns":2     requester connects
"timestamp":"2026-09-03T01:47:29.141604Z"   "conns":1,"leafnodes":0,"total_conns":1     requester leaves
"timestamp":"2026-09-03T01:47:31.230874Z"   "conns":1,"leafnodes":1,"total_conns":2     the leaf x2
"timestamp":"2026-09-03T01:48:01.231712Z"   "conns":1,"leafnodes":1,"total_conns":2     heartbeat, +30 s
"timestamp":"2026-09-03T01:48:31.232799Z"   "conns":1,"leafnodes":1,"total_conns":2     heartbeat, +30 s
"timestamp":"2026-09-03T01:49:01.234612Z"   "conns":1,"leafnodes":1,"total_conns":2     heartbeat, +30 s
"timestamp":"2026-09-03T01:49:27.144144Z"   "conns":1,"leafnodes":0,"total_conns":1     x2 stops
"timestamp":"2026-09-03T01:49:27.14469Z"    "conns":0,"leafnodes":0,"total_conns":0     (holder killed with it)
```

`$SYS` and `SVC` heartbeat likewise (01:47:38.844, 01:48:08.844, …). It is a heartbeat, not a
limit alarm: the docs' overview ("Published when account connection limits are reached … Alerts
when approaching or exceeding limits") describes something the event does not do; its own schema
line, "Regular advisory published with account states", is the accurate one. One body in full:

```
{"type":"io.nats.server.advisory.v1.account_connections","id":"UZwJ1dfXtZ6DgrGbA8vcEE",
 "timestamp":"2026-09-03T01:47:27.113191Z",
 "server":{"name":"x1","host":"127.0.0.1","id":"<x1 id>","ver":"2.14.6",
   "feature_flags":{"js_ack_fc_v2":false,"js_raft_delete_range":false},"jetstream":false,"flags":0,
   "seq":26,"time":"2026-09-03T01:47:27.11323Z"},
 "acc":"APP","name":"APP","conns":1,"leafnodes":0,"total_conns":1,"num_subscriptions":5,
 "sent":{"msgs":0,"bytes":0,"gateways":{"msgs":0,"bytes":0},"routes":{"msgs":0,"bytes":0},"leafs":{"msgs":0,"bytes":0}},
 "received":{"msgs":0,"bytes":0,"gateways":{"msgs":0,"bytes":0},"routes":{"msgs":0,"bytes":0},"leafs":{"msgs":0,"bytes":0}},
 "slow_consumers":0}
```

`name` and `num_subscriptions` are in the body and not on the docs page. The **connect** and
**disconnect** bodies (server object trimmed to `name`, `id`, `seq`, `time`):

```
$SYS.ACCOUNT.APP.CONNECT
{"type":"io.nats.server.advisory.v1.client_connect","id":"UZwJ1dfXtZ6DgrGbA8vcJO","timestamp":"2026-09-03T01:47:27.113195Z",
 "server":{"name":"x1","id":"<x1 id>","seq":27,"time":"2026-09-03T01:47:27.113237Z"},
 "client":{"start":"2026-09-03T03:47:27.112979+02:00","host":"127.0.0.1","id":10,"acc":"APP","user":"app","name":"holder",
   "lang":"go","ver":"1.51.0","name_tag":"APP","kind":"Client","client_type":"nats"}}

$SYS.ACCOUNT.APP.DISCONNECT
{"type":"io.nats.server.advisory.v1.client_disconnect","id":"UZwJ1dfXtZ6DgrGbA8vce2","timestamp":"2026-09-03T03:47:29.141611+02:00",
 "server":{"name":"x1","id":"<x1 id>","seq":33,"time":"2026-09-03T01:47:29.141632Z"},
 "client":{"start":"2026-09-03T03:47:29.140326+02:00","host":"127.0.0.1","id":11,"acc":"APP","user":"app","name":"requester",
   "lang":"go","ver":"1.51.0","rtt":356000,"stop":"2026-09-03T03:47:29.141611+02:00","name_tag":"APP","kind":"Client","client_type":"nats"},
 "sent":{"msgs":1,"bytes":4},"received":{"msgs":1,"bytes":4},"reason":"Client Closed"}

$SYS.ACCOUNT.APP.CONNECT   (the leaf)
{"type":"io.nats.server.advisory.v1.client_connect","id":"UZwJ1dfXtZ6DgrGbA8vd3q","timestamp":"2026-09-03T01:47:31.230882Z",
 "server":{"name":"x1","seq":39,"time":"2026-09-03T01:47:31.230944Z"},
 "client":{"start":"2026-09-03T01:47:31.229251Z","host":"127.0.0.1","id":13,"acc":"APP","user":"app","name":"x2","ver":"2.14.6",
   "name_tag":"APP","kind":"Leafnode"}}
```

So a leaf node connecting *is* a `CONNECT` event on the account it binds to, with `"kind":"Leafnode"`
and the remote's `server_name` as `name` — gh#5902's asker was subscribed to the right thing when they
read `$SYS.ACCOUNT.*.CONNECT`. **`$SYS.ACCOUNT.<acc>.LEAFNODE.CONNECT` was not published**: zero
matches for `LEAFNODE` in the whole log, twice (x2 restarted at 03:50). `events.go:2416–2421` is the
reason — `sendLeafNodeConnect` returns before sending unless `s.gateway.enabled`; the constant's own
comment says "for internal use only". That thread ends with the maintainer wondering whether a single
hub versus "a cluster or more advanced system" is the difference; the relevant difference is gateways,
which Synadia Cloud has and the asker's docker-compose hub had not.

Note the `timestamp` zones: the connect event's is UTC (`Z`), the disconnect event's carries the local
offset (`+02:00`) — `accountConnectEvent` stamps `time.Now().UTC()`, `accountDisconnectEvent` uses the
`now` its caller passes (`events.go:2551–2662`).

## 4 · A failed authentication

`nats --server nats://app:WRONG@127.0.0.1:4299 pub x y` → `nats: error: nats: Authorization
Violation`. Two events, one on the server subject and one on the account the client fell into:

```
$SYS.SERVER.<x1 id>.CLIENT.AUTH.ERR
{"type":"io.nats.server.advisory.v1.client_disconnect","id":"UZwJ1dfXtZ6DgrGbA8vcoM","timestamp":"2026-09-03T01:47:30.189954Z",
 "server":{"name":"x1","id":"<x1 id>","seq":35,"time":"2026-09-03T01:47:30.189958Z"},
 "client":{"start":"2026-09-03T03:47:30.18958+02:00","host":"127.0.0.1","id":12,"acc":"$G","user":"app","name":"NATS CLI Version 0.4.0",
   "lang":"go","ver":"1.51.0","rtt":266000,"stop":"2026-09-03T01:47:30.189954Z","name_tag":"$G","kind":"Client","client_type":"nats"},
 "sent":{"msgs":0,"bytes":0},"received":{"msgs":0,"bytes":0},"reason":"Authentication Failure"}

$SYS.ACCOUNT.$G.DISCONNECT
(the same body, id UZwJ1dfXtZ6DgrGbA8vctW)
```

The auth-error event **is a `client_disconnect`** with `reason: "Authentication Failure"`; the client
is attributed to `$G` because it never got into `APP`. No `CONNECT` preceded it.

## 5 · Service latency: on the export's subject, in the exporting account

`SVC` exports `svc.echo` with `latency { sampling: 100%, subject: "svc.latency" }`; a `SVC` client
subscribed to `svc.latency`; `APP` sent one request. The metric arrived **on `svc.latency` in `SVC`**,
not on any `$SYS` subject (the `$SYS.>` subscriber saw nothing for it):

```
[#1] Received on "svc.latency"
{"type":"io.nats.server.metric.v1.service_latency","id":"S7WoumEAVUfuJjuEiShLB7","timestamp":"2026-09-03T01:47:29.141443Z",
 "status":200,"requestor":{"acc":"APP","rtt":356292},
 "responder":{"start":"2026-09-03T03:47:08.843631+02:00","host":"127.0.0.1","id":9,"acc":"SVC","user":"svc","name":"NATS CLI Version 0.4.0",
   "lang":"go","ver":"1.51.0","rtt":293000,"server":"x1","kind":"Client","client_type":"nats"},
 "start":"2026-09-03T01:47:29.140776708Z","service":15000,"system":1792,"total":666084}
```

`accounts.go:1496–1500`: `lsubj := si.latency.subject; a.srv.sendInternalAccountMsg(a, lsubj, sl)`.
The docs' `reference/system/metric.md` says metrics are published on `$SYS.SERVER.METRIC.>` and
`$SYS.SERVER.METRIC.SERVICE.LATENCY`; no such subject exists in `events.go` or `accounts.go`, and the
one documented field name that differs is `error` (docs) against `description` (`accounts.go:1432`).
The responder side also saw the request header `Nats-Request-Info: {"acc":"APP","rtt":356292}`.

## 6 · `STATSZ`: every 10 s, from every server

x1's heartbeat, `server.time` of successive `$SYS.SERVER.<x1 id>.STATSZ` messages:

```
01:47:12.778  01:47:22.779  01:47:32.779  01:47:42.780  01:47:52.781  01:48:02.782  01:48:12.783  01:48:22.784 …
```

10 s apart (`statsHBInterval`, `events.go:101`), after a start at 250 ms doubling up to it
(`startStatszTimer`, `:1140`). On the lab, five distinct server ids sent `STATSZ` during the run —
n1, n3 and the three incarnations of n2 (restarted twice) — 43 + 43 + 22 + 12 + 12 messages.

## 7 · Reload by message, lame duck, shutdown — on the lab

```
### $SYS.REQ.SERVER.<n1 id>.RELOAD   (empty body)
{"server":{"name":"n1",…,"seq":184,"time":"2026-09-03T01:50:53.062618Z"}}
n1.log:
[37582] 2026/09/03 03:50:53.061950 [INF] Reloaded: accounts
[37582] 2026/09/03 03:50:53.062609 [INF] Reloaded server configuration (sha256:23f0c061b4b83357e74d987cc52fe1b9257a81e686732b6dc04f93dd21d7994a)
```

A reload requested over the system account, answered with the bare server envelope (`reloadConfig`,
`events.go:3201`). Then `nats-server --signal ldm=<n2 pid>` at 03:50:54.077:

```
[#127] Received on "$SYS.SERVER.<n2 id>.LAMEDUCK"
{"name":"n2","host":"127.0.0.1","id":"<n2 id>","cluster":"east","ver":"2.14.6",
 "feature_flags":{"js_ack_fc_v2":false,"js_raft_delete_range":false},"jetstream":true,"flags":7,"seq":56,"time":"2026-09-03T01:50:54.084721Z"}
n2.log:
[37602] 2026/09/03 03:50:54.084705 [INF] Entering lame duck mode, stop accepting new clients
[37602] 2026/09/03 03:50:54.085188 [INF] Server Exiting..
```

The `LAMEDUCK` body is the server's `ServerInfo` and nothing else. n2 had no clients, so the drain
ended in half a millisecond — and **no `SHUTDOWN` event reached the subscriber on n1** on that exit.
A plain SIGTERM on the restarted n2 (`cluster.sh stop 2`, 03:52:27) did produce it:

```
[#187] Received on "$SYS.SERVER.<n2 id>.SHUTDOWN"
{"name":"n2","host":"127.0.0.1","id":"<n2 id>","cluster":"east",…,"seq":27,"time":"2026-09-03T01:52:27.933483Z"}
n2.log:
[43315] 2026/09/03 03:52:27.933973 [INF] 127.0.0.1:6293 - rid:13 - Router connection closed: Server Shutdown - Remote: n3
[43315] 2026/09/03 03:52:27.934346 [INF] Server Exiting..
```

## 8 · The account-scoped request forms

As `sys` on x1, `$SYS.REQ.ACCOUNT.APP.<Z>` with an empty JSON body:

| request | answer |
|---|---|
| `STATZ` | `{"server":…,"data":{"server_id":…,"now":…,"account_statz":[…]}}` |
| `INFO` | `{"server":…,"data":{"account_name":"APP","update_time":…,…}}` |
| `SUBSZ` | `{"server":…,"data":{…subscriptions of APP…}}` |
| `LEAFZ` | `{"server":…,"data":{…}}` |
| `CONNZ` | `{"server":…,"data":{…APP's connections…}}` |
| `JSZ` | `{"server":…,"data":null,"error":{"code":500,"description":"jetstream not enabled…"}}` (x1 has no JetStream) |
| `CONNS` | **no reply** in 4 s, with `{}` and with `{"acc":"APP"}` — a server-to-server request (`accNumConnsReq`, `events.go:233`) |
| `$SYS.REQ.ACCOUNT.NSUBS` `{"subject":"hold.me"}` | **no reply** in 3 s (internal) |
| `$SYS.DEBUG.SUBSCRIBERS` `{"subject":">"}` | `0` (a bare number) |

On the lab, `$SYS.REQ.ACCOUNT.PING.STATZ` answered from all three servers, and
`$SYS.REQ.ACCOUNT.$G.CONNZ` likewise (`$G` is a valid account token there).

As the ordinary user `app` on x1 (no system credentials):

| request | answer |
|---|---|
| `$SYS.REQ.USER.INFO` | `{"server":…,"data":{"user":"app","account":"APP","account_name":"APP"}}` |
| `$SYS.REQ.ACCOUNT.PING.CONNZ` | answered — the built-in import (`events.go:2385–2387`), scoped to `APP` |
| `$SYS.REQ.ACCOUNT.PING.STATZ` | answered — likewise |
| `$SYS.REQ.SERVER.PING.VARZ` | `No responders are available` |
| `$SYS.REQ.ACCOUNT.APP.CONNZ` | `No responders are available` |

## Not tested

Gateways (so `LEAFNODE.CONNECT` was shown absent, not present); the OCSP events; `KICK` and `LDM`
by id (in `kick-ldm-observed-v2.14.6.md`); `$SYS.LATENCY.M2.*` (needs a request crossing servers);
operator mode (`$SYS.REQ.CLAIMS.*`, `$SYS.REQ.ACCOUNT.<id>.CLAIMS.LOOKUP`); whether a `SHUTDOWN` is
delivered after a lame-duck drain that *had* clients; the docs' `$SYS.SERVER.METRIC.>` — searched for
in the two source files, not subscribed to on the wire beyond the `$SYS.>` subscription that saw no
such subject.
