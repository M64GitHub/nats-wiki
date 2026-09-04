<!-- source: nats-server v2.14.6 binary, nats CLI 0.4.0 (its go.mod pins nats.go v1.51.0; the client values this wiki quotes are read at v1.53.1 in raw/nats-go-src/connection-v1.53.1.md), Python 3.14.7, macOS, 2026-09-04 · runs A, B, C and E on the three-node lab of tools/lab/cluster.sh (n1 4291 / n2 4292 / n3 4293, plain clients in $G), run D on one standalone server per scene on port 14222 (monitoring 18222) · four passes, scripts beside this file: client-lifecycle-run.sh (A1–A2, B1–B2, C1, E1–E7), client-lifecycle-run2.sh (A3, B3 first attempt, C4, E8–E9), client-lifecycle-run3.sh (B3–B5 after raw-watch.py was fixed), client-lifecycle-stale-run.sh (D1–D3); the raw protocol clients are client-lifecycle-raw-watch.py and client-lifecycle-stale-client.py · the transcripts are the scripts' output verbatim except that the `nats pub` progress-bar redraw lines and bash's job-control lines are dropped -->
# nats-server v2.14.6 — the client's side of a fault: a node stopped, a node in lame duck, a drain under load, a stale link, and a pull consumer whose leader moves

The behavioural half of `raw/nats-go-src/connection-v1.53.1.md` and `raw/nats-cli/reconnect-0.4.0.md`,
for `wiki/concepts/client-connection-lifecycle.md` and `wiki/reference/client-defaults.md`
(phase F step 3). Five runs, each in two shapes where the two ends of a connection lose different
things: **A** a node stopped with SIGTERM under a live subscriber and under a live publisher, then
the same at full publish rate so the at-most-once gap is countable; **B** the same node asked to
enter lame duck instead, plus the asynchronous `INFO` a client actually receives; **C** `nats reply`
drained with Ctrl-C while requests are in flight; **D** the stale link from both ends — the server's
`-ERR 'Stale Connection'` on a shortened ping interval, and nats.go's own detection at its defaults,
timed over six minutes; **E** a JetStream pull consumer while its consumer leader's node stops.

## What each run shows

- **A1** a subscriber pinned to n1, publisher on n2 at 89 msg/s: n1 stopped, the client printed
  `>>> Disconnected due to: EOF, will attempt reconnect` and `>>> Reconnected to
  nats://127.0.0.1:4293` **in the same second**, and received **all 1000** messages — first 1, last
  1000, none missing. It had never been told about n3: the pool grew from the one configured URL
  through the `connect_urls` gossip. **A2** the mirror image, publisher pinned to n1: the publisher
  moved to n2 mid-run (`>>> Disconnected … EOF` → `>>> Reconnected to nats://127.0.0.1:4292`),
  finished all 1000 and exited 0, and the subscriber on n2 received all 1000. A one-URL client has
  failover only because of discovery.
- **A3** the same shape as A1 with the publisher running flat out — **25,800 msg/s** — makes the gap
  visible: **199,990 of 200,000 received, exactly ten missing, 43891–43900, one contiguous run**.
  That is the at-most-once gap, about **0.39 ms** wide, and it is that small because nats.go sleeps
  only after a whole sweep of the pool (`doReconnect`, `:3395`), so with three servers known the
  first retry is immediate.
- **B1** n1 signalled `ldm` under the same load: the subscriber stayed on n1 and was disconnected
  **10.0 s later** (`Closing existing clients` at 01:54:11.210 against `JetStream Shutdown` at
  01:54:01.209), then reconnected to n3 having lost nothing. **B2** the publisher's side, same
  result. The 10 s is `DEFAULT_LAME_DUCK_GRACE_PERIOD` (`const.go:200`), measured from the end of
  the JetStream shutdown, not from the notice: in **B3** the notice was 02:00:26.394 and the clients
  were closed 02:00:37.405, **11.01 s**, because `transferRaftLeaders` waits a second first.
- **B3** the asynchronous `INFO` a client on the departing server receives, **about a second after
  the notice**: `"connect_urls":["127.0.0.1:4292","127.0.0.1:4293"]` — n1's own address removed — and
  **`"ldm":true`**. The delay is in the code, not the network: `lameDuckMode` transfers Raft
  leadership and waits a second, shuts JetStream down, and only then calls `sendLDMToClients`
  (`server.go:4463–4529`) — notice 02:00:26.394, `JetStream Shutdown` 02:00:27.404, the client's INFO
  at its own t=3.015. The grace-period timer starts **after** that INFO, which is why
  `Closing existing clients` at 02:00:37.405 is 10.001 s after it and 11.011 s after the notice. **B4** a client on n2 receives an `INFO` at the same instant with the same
  shortened `connect_urls` and **no `ldm` key**: a peer learns the pool changed, not that a server
  is leaving. **B5** a client that completed `CONNECT` but never sent a `PING` received **no
  lame-duck `INFO` at all** and was simply closed 13 s later — `sendAsyncInfoToClients` skips every
  client without `firstPongSent` (`route.go:1026–1028`). Every real client pings at connect; a raw
  one has to.
- **C1** `nats reply --sleep 1s` under 50 requests, Ctrl-C after 2 s: `Draining...` and `Exiting` in
  the **same second**, exit code **1**. **C4** the same with eight separate single requests so each
  outcome is unambiguous: **four answered** (rtt 0.83 s, 0.99 s, 1.21 s, 1.84 s) and **four printed
  nothing at all** and timed out. `Drain()` returns as soon as the background drain starts, and
  `log.Fatalf("Exiting")` kills the process on that return, so the requests already delivered to the
  responder's buffer are lost. This is the pitfall `drain-and-shutdown.md:45` describes, counted.
- **D1** the server's side with `ping_interval: "5s"` and `ping_max: 2`, and a client that never
  answers: `PING` at t=2.186 and t=7.187, then at **t=12.189** — where the third `PING` would have
  gone — `-ERR 'Stale Connection'` and the socket closed. Two pings unanswered, the third interval
  closes it. **The server logged nothing** at default level; only `/varz`'s `total_connections`
  moved. **D2** the control answered every `PONG` and was still connected at t=22.4.
- **D3** the client's side at nats.go's own defaults (2 m interval, 2 outstanding), with the server
  `SIGSTOP`ped: `>>> Disconnected due to: nats: stale connection, will attempt reconnect` at
  **+360.0 s from the connect** — six minutes exactly, the third ping interval. ADR-40's "two
  consecutive PONGs are missed" would be four. The CLI's own backoff is visible in the same
  transcript: **640 ms, 800 ms, 2.15 s, 1.979 s, 3.424 s, 1.873 s** — and 2.15 s can only come from
  the table's `Duration(3)` = 1500 ms jittered into [750, 2250], which fixes the indexing: nats.go
  increments the sweep counter *before* calling the custom delay (`:3424–3426`), so natscli's
  callback is first called with **1**, and the table's first entry, **500 ms, is never used**.
- **E1–E7** an R3 stream and a durable pull consumer, 500 messages: a `consumer next --count 100`
  finished in well under the half-second before the leader's node was stopped, so it proved only
  that the leadership moved (n1 → n3) with `ack_floor` intact and nothing redelivered.
  **E8** repeats it one message at a time, 120 fetches across the stop: **exactly one failed**, with
  `error: no message received: nats: no responders available for request` in **17 ms**, and the very
  next iteration succeeded. The `$JS.API` request that lands in the leadership window gets *no
  responders*, not a timeout, and the window is one request wide.
- **E9** ten messages fetched with `--no-ack`, then the consumer leader's node stopped: 35 s later
  (past the 30 s `ack_wait`) the new leader still reported `ack_pending 10`, `ack_floor 119`,
  `num_redelivered 0` — and the next fetch returned those ten stream sequences **with `tries: 2`**,
  under new consumer sequences 130–139, before continuing at `tries: 1`. Nothing was lost; the
  un-acked work came back as a redelivery, and `num_redelivered` had not yet counted it.

## Transcript — first pass (`client-lifecycle-run.sh`): A1–A2, B1–B2, C1, E1–E7

```

### versions
nats-server: v2.14.6
nats CLI: 0.4.0
date: 2026-09-03T23:53:16Z

### reset the lab (3 nodes, purged)
healthy: 3 nodes, /healthz?js-meta-only=true ok on every node; meta leader n1, cluster_size 3
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
node pid     alive client http  healthz  js-meta  meta_leader cluster_size
n1   39349   yes   4291   8291  200      200      n1          3
n2   39369   yes   4292   8292  200      200      n1          3
n3   39389   yes   4293   8293  200      200      n1          3
lab dir: /var/folders/3t/s08lg8x96lz5mbccdwl_rfj80000gn/T/nats-lab   version gate: v2.14.6

### A — n1 stopped with SIGTERM

--- A1: the SUBSCRIBER is pinned to n1; the publisher runs on n2. n1 stops 3 s into 1000 messages
stopping n1 at 23:53:21
n1: stopped (SIGTERM, pid 39349)
publisher exit: 0
what the subscriber received:
first 1, last 1000, received 1000, missing inside the range 0

--- A1: every line the subscriber printed that was not a message
01:53:17 Subscribing on orders.new 
01:53:17 >>> Connected to nats://127.0.0.1:4291 (127.0.0.1:4291)
01:53:21 >>> Disconnected due to: EOF, will attempt reconnect
01:53:21 >>> Reconnected to nats://127.0.0.1:4293 (127.0.0.1:4293)

--- A1: the publisher's last two lines
 done! [1.00K in 11.167s; 89/s]

--- A1: restart n1
n1: pid 39719  client 127.0.0.1:4291  http 127.0.0.1:8291  log /var/folders/3t/s08lg8x96lz5mbccdwl_rfj80000gn/T/nats-lab/n1/n1.log

--- A2: the PUBLISHER is pinned to n1; the subscriber runs on n2. n1 stops 3 s in
stopping n1 at 23:53:41
n1: stopped (SIGTERM, pid 39719)
publisher exit: 0
what the subscriber received:
first 1, last 1000, received 1000, missing inside the range 0

--- A2: the publisher's non-progress lines — did a one-URL client fail over
01:53:38 >>> Connected to nats://127.0.0.1:4291 (127.0.0.1:4291)
01:53:41 >>> Disconnected due to: EOF, will attempt reconnect
01:53:41 >>> Reconnected to nats://127.0.0.1:4292 (127.0.0.1:4292)

--- A2: restart n1
n1: pid 39960  client 127.0.0.1:4291  http 127.0.0.1:8291  log /var/folders/3t/s08lg8x96lz5mbccdwl_rfj80000gn/T/nats-lab/n1/n1.log
node pid     alive client http  healthz  js-meta  meta_leader cluster_size
n1   39960   yes   4291   8291  200      200      n2          3
n2   39369   yes   4292   8292  200      200      n2          3
n3   39389   yes   4293   8293  200      200      n2          3
lab dir: /var/folders/3t/s08lg8x96lz5mbccdwl_rfj80000gn/T/nats-lab   version gate: v2.14.6

### B — n1 asked to enter lame duck instead of being stopped

--- B1: the SUBSCRIBER is pinned to n1; publisher on n2; ldm 3 s in
n1 pid 39960 — signalling ldm at 23:54:01
publisher exit: 0
what the subscriber received:
first 1, last 1000, received 1000, missing inside the range 0

--- B1: the subscriber's non-message lines
01:53:57 Subscribing on orders.new 
01:53:57 >>> Connected to nats://127.0.0.1:4291 (127.0.0.1:4291)
01:54:11 >>> Disconnected due to: EOF, will attempt reconnect
01:54:11 >>> Reconnected to nats://127.0.0.1:4293 (127.0.0.1:4293)

--- B1: n1's log around the lame-duck notice
[39960] 2026/09/04 01:54:01.209327 [INF] JetStream Shutdown
[39960] 2026/09/04 01:54:11.210484 [INF] Closing existing clients
[39960] 2026/09/04 01:54:11.211887 [INF] Initiating Shutdown...
[39960] 2026/09/04 01:54:11.212077 [INF] 127.0.0.1:6293 - rid:9 - Router connection closed: Server Shutdown - Remote: n3
[39960] 2026/09/04 01:54:11.212123 [INF] 127.0.0.1:6292 - rid:8 - Router connection closed: Server Shutdown - Remote: n2
[39960] 2026/09/04 01:54:11.212154 [INF] 127.0.0.1:6292 - rid:13 - Router connection closed: Server Shutdown - Remote: n2
[39960] 2026/09/04 01:54:11.212181 [INF] 127.0.0.1:6292 - rid:14 - Router connection closed: Server Shutdown - Remote: n2
[39960] 2026/09/04 01:54:11.212210 [INF] 127.0.0.1:6293 - rid:11 - Router connection closed: Server Shutdown - Remote: n3
[39960] 2026/09/04 01:54:11.212231 [INF] 127.0.0.1:6293 - rid:12 - Router connection closed: Server Shutdown - Remote: n3
[39960] 2026/09/04 01:54:11.212251 [INF] 127.0.0.1:6293 - rid:15 - Router connection closed: Server Shutdown - Remote: n3
[39960] 2026/09/04 01:54:11.212275 [INF] 127.0.0.1:6292 - rid:10 - Router connection closed: Server Shutdown - Remote: n2
[39960] 2026/09/04 01:54:11.212330 [INF] Server Exiting..

--- B1: is n1 still up?
node pid     alive client http  healthz  js-meta  meta_leader cluster_size
n1   -       no    4291   8291  000      000      -           -
n2   39369   yes   4292   8292  200      200      n2          3
n3   39389   yes   4293   8293  200      200      n2          3
lab dir: /var/folders/3t/s08lg8x96lz5mbccdwl_rfj80000gn/T/nats-lab   version gate: v2.14.6

--- B2: restart the lab, then the PUBLISHER pinned to n1 and ldm 3 s in
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
n1 pid 40466 — signalling ldm at 23:54:25
publisher exit: 0
what the subscriber received:
first 1, last 1000, received 1000, missing inside the range 0

--- B2: the publisher's non-progress lines
01:54:22 >>> Connected to nats://127.0.0.1:4291 (127.0.0.1:4291)

--- B2: rebuild the lab for the next runs
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
node pid     alive client http  healthz  js-meta  meta_leader cluster_size
n1   41085   yes   4291   8291  200      200      n2          3
n2   41105   yes   4292   8292  200      200      n2          3
n3   41125   yes   4293   8293  200      200      n2          3
lab dir: /var/folders/3t/s08lg8x96lz5mbccdwl_rfj80000gn/T/nats-lab   version gate: v2.14.6

### C — nats reply drained with Ctrl-C while requests are in flight

--- C1: one responder sleeping up to 1 s per reply, 50 sequential requests, SIGINT 2 s in
SIGINT to nats reply at 23:54:48.882
nats reply exit: 1
nats request exit: 0

--- C2: everything nats reply printed
01:54:45 Listening on "orders.check" in group "NATS-RPLY-22"
01:54:46 [#0] Received on subject "orders.check":

q
01:54:47 [#1] Received on subject "orders.check":

q
01:54:47 [#2] Received on subject "orders.check":

q
01:54:48 [#3] Received on subject "orders.check":

q
01:54:48 [#4] Received on subject "orders.check":

q
01:54:48 [#5] Received on subject "orders.check":

q
01:54:48 [#6] Received on subject "orders.check":

q
01:54:48 
Draining...
01:54:48 Exiting

--- C3: how the 50 requests ended
replies received: 0
no-responders lines: 1
01:54:51 No responders are available

### E — a JetStream pull consumer while its leader's node stops

--- E1: R3 stream and a durable pull consumer, 500 messages in
stream leader n2 replicas ['n1', 'n3'] msgs 500
consumer leader: n1

--- E2: a quiet fetch of 100 first — the baseline
first fetch: exit 0, messages 100

--- E3: fetch 100 more, and stop the consumer leader's node half a second in
stopping n1 (node 1) at 23:54:53.435
n1: stopped (SIGTERM, pid 41085)
second fetch exit: 0
messages received: 100
acknowledged: 100

--- E4: the last 12 lines of that fetch
[01:54:52] subj: life.a / tries: 1 / cons seq: 199 / str seq: 199 / pending: 301

m 199

Acknowledged message

[01:54:52] subj: life.a / tries: 1 / cons seq: 200 / str seq: 200 / pending: 300

m 200

Acknowledged message

--- E5: consumer state after the move
leader n3 delivered 200 / 200 ack_floor 200 / 200 pending 300 ack_pending 0 redelivered 0

--- E6: a third fetch — which sequences come back, and with what tries count
third fetch exit: 0
[01:54:56] subj: life.a / tries: 1 / cons seq: 201 / str seq: 201 / pending: 299
[01:54:56] subj: life.a / tries: 1 / cons seq: 202 / str seq: 202 / pending: 298
[01:54:56] subj: life.a / tries: 1 / cons seq: 203 / str seq: 203 / pending: 297
[01:54:56] subj: life.a / tries: 1 / cons seq: 204 / str seq: 204 / pending: 296
[01:54:56] subj: life.a / tries: 1 / cons seq: 205 / str seq: 205 / pending: 295

--- E7: restart the stopped node
n1: pid 41556  client 127.0.0.1:4291  http 127.0.0.1:8291  log /var/folders/3t/s08lg8x96lz5mbccdwl_rfj80000gn/T/nats-lab/n1/n1.log
node pid     alive client http  healthz  js-meta  meta_leader cluster_size
n1   41556   yes   4291   8291  200      200      n2          3
n2   41105   yes   4292   8292  200      200      n2          3
n3   41125   yes   4293   8293  200      200      n2          3
lab dir: /var/folders/3t/s08lg8x96lz5mbccdwl_rfj80000gn/T/nats-lab   version gate: v2.14.6

### done
```

## Transcript — second pass (`client-lifecycle-run2.sh`): A3, B3 (first attempt), C4, E8–E9

The B3 attempt in this pass is kept because it is the evidence for **B5**: `raw-watch.py` was
reading through `socket.makefile()` on a socket with a timeout, which Python refuses, so the client
died at `t=0.000` and n1 — left with no clients at all — went straight to `Initiating Shutdown` with
no grace period.

```

### versions
nats-server: v2.14.6
nats CLI: 0.4.0
date: 2026-09-03T23:56:44Z
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …

### A3 — the gap, at full publish rate

--- A3: subscriber pinned to n1, publisher on n2 with no sleep; n1 stopped 2 s in
stopping n1 at 23:56:49.272
n1: stopped (SIGTERM, pid 42697)
publisher exit: 0
publisher's own rate line: done! [200.00K in 7.752s; 25.80K/s]
what the subscriber received:
first 1, last 200000, received 199990, missing inside the range 10
  gaps: 43891-43900 (10)

--- A3: the subscriber's non-message lines
01:56:46 Subscribing on orders.new 
01:56:46 >>> Connected to nats://127.0.0.1:4291 (127.0.0.1:4291)
01:56:49 >>> Disconnected due to: EOF, will attempt reconnect
01:56:49 >>> Reconnected to nats://127.0.0.1:4292 (127.0.0.1:4292)
n1: pid 43045  client 127.0.0.1:4291  http 127.0.0.1:8291  log /var/folders/3t/s08lg8x96lz5mbccdwl_rfj80000gn/T/nats-lab/n1/n1.log

### B3 — the lame-duck INFO a client receives, and n1's whole lame-duck log

--- B3: a raw client on n1, then ldm; the async INFO is the interesting line
n1 pid 43045 — signalling ldm at 23:57:03.851

--- B3: everything the raw client saw
t=0.000 << INFO {"server_id":"NDXPP64HHU4LAKQZE2AVIZYCCDEMTNRGBERXBMMFP6CKBHJ7C4OP6YNL","server_name":"n1","version":"2.14.6","proto":1,"go":"go1.27.0","host":"127.0.0.1","port":4291,"headers":true,"auth_required":true,"max_payload":1048576,"jetstream":true,"client_id":24,"client_ip":"127.0.0.1","cluster":"east","connect_urls":["127.0.0.1:4291","127.0.0.1:4293","127.0.0.1:4292"],"api_lvl":4,"xkey":"XAEHBSSPCVWAT74ZPA7VTMLQHA77SJ5KGNMZW3ZUB5FNKZXYEVIAXZVF"}
t=0.000 >> SUB orders.> 1
Traceback (most recent call last):
  File "/Users/m64/space/64/nats-wiki/local/scratch/runs/client-lifecycle/raw-watch.py", line 28, in <module>
    line = f.readline()
  File "/opt/homebrew/Cellar/python@3.14/3.14.7/Frameworks/Python.framework/Versions/3.14/lib/python3.14/socket.py", line 727, in readinto
    raise OSError("cannot read from timed out object")
OSError: cannot read from timed out object

--- B3: n1's lame-duck log, from the notice down
[43045] 2026/09/04 01:57:03.864751 [INF] Entering lame duck mode, stop accepting new clients
[43045] 2026/09/04 01:57:03.864847 [INF] Initiating JetStream Shutdown...
[43045] 2026/09/04 01:57:03.864989 [INF] JetStream Shutdown
[43045] 2026/09/04 01:57:03.865459 [INF] Initiating Shutdown...
[43045] 2026/09/04 01:57:03.865521 [INF] 127.0.0.1:6293 - rid:12 - Router connection closed: Server Shutdown - Remote: n3
[43045] 2026/09/04 01:57:03.865544 [INF] 127.0.0.1:6293 - rid:14 - Router connection closed: Server Shutdown - Remote: n3
[43045] 2026/09/04 01:57:03.865553 [INF] 127.0.0.1:6292 - rid:9 - Router connection closed: Server Shutdown - Remote: n2
[43045] 2026/09/04 01:57:03.865559 [INF] 127.0.0.1:6292 - rid:13 - Router connection closed: Server Shutdown - Remote: n2
[43045] 2026/09/04 01:57:03.865565 [INF] 127.0.0.1:6292 - rid:15 - Router connection closed: Server Shutdown - Remote: n2
[43045] 2026/09/04 01:57:03.865576 [INF] 127.0.0.1:6292 - rid:10 - Router connection closed: Server Shutdown - Remote: n2
[43045] 2026/09/04 01:57:03.865582 [INF] 127.0.0.1:6293 - rid:11 - Router connection closed: Server Shutdown - Remote: n3
[43045] 2026/09/04 01:57:03.865589 [INF] 127.0.0.1:6293 - rid:8 - Router connection closed: Server Shutdown - Remote: n3

--- B3: what the INFO's connect_urls held, parsed
t=0.000  server_name=n1 ldm=None connect_urls=['127.0.0.1:4291', '127.0.0.1:4293', '127.0.0.1:4292']
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …

### C4 — nats reply drained with one request per process

--- C4: responder sleeping 1 s per reply; 8 concurrent single requests; SIGINT 2 s in
SIGINT to nats reply at 23:57:13.298
nats reply exit: 1

--- C4: what nats reply printed
01:57:10 Listening on "orders.check" in group "NATS-RPLY-22"
01:57:11 [#0] Received on subject "orders.check":

q5
01:57:12 [#1] Received on subject "orders.check":

q3
01:57:12 [#2] Received on subject "orders.check":

q1
01:57:12 [#3] Received on subject "orders.check":

q2
01:57:13 [#4] Received on subject "orders.check":

q4
01:57:13 
Draining...
01:57:13 Exiting

--- C4: how each of the eight requests ended
req 1: answered — rtt 1.211021625s
req 2: answered — rtt 1.83852075s
req 3: answered — rtt 995.878375ms
req 4: nothing printed (timed out): 01:57:11 Sending request on "orders.check"
req 5: answered — rtt 830.842541ms
req 6: nothing printed (timed out): 01:57:11 Sending request on "orders.check"
req 7: nothing printed (timed out): 01:57:11 Sending request on "orders.check"
req 8: nothing printed (timed out): 01:57:11 Sending request on "orders.check"
answered: 4 of 8

### E8 — a pull consumer fetching one at a time while its leader's node stops
stream leader n3, consumer leader n1
stopping n1 (node 1) at 23:57:24.079
n1: stopped (SIGTERM, pid 43236)

--- E8: the iterations around the stop
44:iter 44 rc=1 dt=0.017 error: no message received: nats: no responders available for request
iterations with rc != 0: 1 of 120

--- E8: the five slowest iterations
  iter 94 rc=0 dt=0.026 cons seq: 93
  iter 40 rc=0 dt=0.021 cons seq: 40
  iter 6 rc=0 dt=0.021 cons seq: 6
  iter 68 rc=0 dt=0.020 cons seq: 67
  iter 5 rc=0 dt=0.020 cons seq: 5
  total fetched: 119

--- E8: consumer state now
leader n2 delivered 119 ack_floor 119 ack_pending 0 redelivered 0
n1: pid 45566  client 127.0.0.1:4291  http 127.0.0.1:8291  log /var/folders/3t/s08lg8x96lz5mbccdwl_rfj80000gn/T/nats-lab/n1/n1.log

### E9 — messages held un-acked when the consumer leader's node stops

--- E9: fetch 10 with --no-ack, stop the consumer leader, wait past ack_wait (30 s), fetch again
consumer leader n2
fetched un-acked: 10
before the stop: ack_pending 10 delivered 129 ack_floor 119
stopping n2 at 23:57:34
n2: stopped (SIGTERM, pid 43256)
35 s after the stop: leader n3 ack_pending 10 delivered 129 ack_floor 119 redelivered 0

--- E9: what came back — the tries counter says whether these are redeliveries
tries: 2 / cons seq: 130 / str seq: 120
tries: 2 / cons seq: 131 / str seq: 121
tries: 2 / cons seq: 132 / str seq: 122
tries: 2 / cons seq: 133 / str seq: 123
tries: 2 / cons seq: 134 / str seq: 124
tries: 2 / cons seq: 135 / str seq: 125
tries: 2 / cons seq: 136 / str seq: 126
tries: 2 / cons seq: 137 / str seq: 127
tries: 2 / cons seq: 138 / str seq: 128
tries: 2 / cons seq: 139 / str seq: 129
tries: 1 / cons seq: 140 / str seq: 130
tries: 1 / cons seq: 141 / str seq: 131
n2: pid 45943  client 127.0.0.1:4292  http 127.0.0.1:8292  log /var/folders/3t/s08lg8x96lz5mbccdwl_rfj80000gn/T/nats-lab/n2/n2.log
node pid     alive client http  healthz  js-meta  meta_leader cluster_size
n1   45566   yes   4291   8291  200      200      n3          3
n2   45943   yes   4292   8292  200      200      n3          3
n3   43279   yes   4293   8293  200      200      n3          3
lab dir: /var/folders/3t/s08lg8x96lz5mbccdwl_rfj80000gn/T/nats-lab   version gate: v2.14.6

### done
```

## Transcript — third pass (`client-lifecycle-run3.sh`): B3–B5

```

### versions
nats-server: v2.14.6
date: 2026-09-04T00:00:22Z
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …

### B3 — the lame-duck INFO, and the grace period before anything is closed
n1 pid 47640 — signalling ldm at 00:00:26.379

--- B3: the client on n1 — every line, with seconds since its own CONNECT
t=0.000 << INFO {"server_id":"NCQOWA7DDAGT3BS2PCH4BT2UNQX26DKBEX6Y4SR3XLCJT23TRAFRHY6V","server_name":"n1","version":"2.14.6","proto":1,"go":"go1.27.0","host":"127.0.0.1","port":4291,"headers":true,"auth_required":true,"max_payload":1048576,"jetstream":true,"client_id":20,"client_ip":"127.0.0.1","cluster":"east","connect_urls":["127.0.0.1:4291","127.0.0.1:4292","127.0.0.1:4293"],"api_lvl":4,"xkey":"XCWKFWGUXTUY2FUNVDP2S3S6JUFRZK7WDXCVMSIQ2O7PM23L4K3W5PZI"} 
t=0.000 >> CONNECT + PING
t=0.000 >> SUB orders.> 1
t=0.000 << PONG
t=0.000 << INFO {"server_id":"NCQOWA7DDAGT3BS2PCH4BT2UNQX26DKBEX6Y4SR3XLCJT23TRAFRHY6V","server_name":"n1","version":"2.14.6","proto":1,"go":"go1.27.0","host":"127.0.0.1","port":4291,"headers":true,"auth_required":true,"max_payload":1048576,"jetstream":true,"client_id":20,"client_ip":"127.0.0.1","cluster":"east","connect_urls":["127.0.0.1:4291","127.0.0.1:4292","127.0.0.1:4293"],"connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XCWKFWGUXTUY2FUNVDP2S3S6JUFRZK7WDXCVMSIQ2O7PM23L4K3W5PZI"} 
t=2.117 << PING
t=2.117 >> PONG
t=3.015 << INFO {"server_id":"NCQOWA7DDAGT3BS2PCH4BT2UNQX26DKBEX6Y4SR3XLCJT23TRAFRHY6V","server_name":"n1","version":"2.14.6","proto":1,"go":"go1.27.0","host":"127.0.0.1","port":4291,"headers":true,"auth_required":true,"max_payload":1048576,"jetstream":true,"client_id":20,"client_ip":"127.0.0.1","cluster":"east","connect_urls":["127.0.0.1:4292","127.0.0.1:4293"],"ldm":true,"api_lvl":4,"xkey":"XCWKFWGUXTUY2FUNVDP2S3S6JUFRZK7WDXCVMSIQ2O7PM23L4K3W5PZI"} 
t=13.517 -- server closed the socket

--- B3: its INFO lines parsed
t=0.000 server_name=n1 ldm=None client_id=20 connect_urls=['127.0.0.1:4291', '127.0.0.1:4292', '127.0.0.1:4293']
t=0.000 server_name=n1 ldm=None client_id=20 connect_urls=['127.0.0.1:4291', '127.0.0.1:4292', '127.0.0.1:4293']
t=3.015 server_name=n1 ldm=True client_id=20 connect_urls=['127.0.0.1:4292', '127.0.0.1:4293']

--- B4: the client on n2 (a peer, not the departing server) — its INFO lines
t=0.000 server_name=n2 ldm=None client_id=20 connect_urls=['127.0.0.1:4292', '127.0.0.1:4291', '127.0.0.1:4293']
t=0.000 server_name=n2 ldm=None client_id=20 connect_urls=['127.0.0.1:4292', '127.0.0.1:4291', '127.0.0.1:4293']
t=3.011 server_name=n2 ldm=None client_id=20 connect_urls=['127.0.0.1:4292', '127.0.0.1:4293']

--- B5: the client on n1 that never sent a PING — what it saw
t=0.000 << INFO {"server_id":"NCQOWA7DDAGT3BS2PCH4BT2UNQX26DKBEX6Y4SR3XLCJT23TRAFRHY6V","server_name":"n1","version":"2.14.6","proto":1,"go":"go1.27.0","host":"127.0.0.1","port":4291,"headers":true,"auth_required":true,"max_payload":1048576,"jetstream":true,"client_id":21,"client_ip":"127.0.0.1","cluster":"east","connect_urls":["127.0.0.1:4291","127.0.0.1:4292","127.0.0.1:4293"],"api_lvl":4,"xkey":"XCWKFWGUXTUY2FUNVDP2S3S6JUFRZK7WDXCVMSIQ2O7PM23L4K3W5PZI"} 
t=0.000 >> CONNECT
t=0.000 >> SUB orders.> 1
t=2.125 << PING
t=2.125 >> PONG
t=13.016 -- server closed the socket

--- B3: n1's log from the lame-duck notice down
[47640] 2026/09/04 02:00:26.393991 [INF] Entering lame duck mode, stop accepting new clients
[47640] 2026/09/04 02:00:26.394149 [INF] JetStream cluster no metadata leader
[47640] 2026/09/04 02:00:26.435495 [INF] JetStream cluster new metadata leader: n2/east
[47640] 2026/09/04 02:00:27.394970 [INF] Initiating JetStream Shutdown...
[47640] 2026/09/04 02:00:27.395336 [WRN] Metalayer blocking snapshot starting
[47640] 2026/09/04 02:00:27.404186 [WRN] Metalayer blocking snapshot took 0.009s (streams: 0, consumers: 0, compacted: 198 B)
[47640] 2026/09/04 02:00:27.404275 [INF] JetStream Shutdown
[47640] 2026/09/04 02:00:37.405495 [INF] Closing existing clients

--- B3: the two timestamps that matter
[47640] 2026/09/04 02:00:26.393991 [INF] Entering lame duck mode, stop accepting new clients
[47640] 2026/09/04 02:00:37.405495 [INF] Closing existing clients

### done
```

## Transcript — fourth pass (`client-lifecycle-stale-run.sh`): D1–D3

```

### versions
nats-server: v2.14.6
nats CLI: 0.4.0
date: 2026-09-04T00:01:48Z

--- the config for D1 and D2
listen: 127.0.0.1:14222
http: 127.0.0.1:18222
ping_interval: "5s"
ping_max: 2

### D1 — a client that never answers PING (server ping_interval 5s, ping_max 2)
t=0.000 << INFO {"server_id":"NA7LTVXW2MB47YMSCPO2UDJEAFL2OYVGPG7HRQF5RS65URSRS2JJPCQU","server_name":"NA7LTVXW2MB47YMSCPO2UDJEAFL2OYVGPG7HRQF5RS65URSRS2JJPCQU","version":"2.14.6","proto":1,"go":"go1.27.0","host
t=0.000 >> CONNECT + PING
t=0.001 << PONG
t=0.001 << INFO {"server_id":"NA7LTVXW2MB47YMSCPO2UDJEAFL2OYVGPG7HRQF5RS65URSRS2JJPCQU","server_name":"NA7LTVXW2MB47YMSCPO2UDJEAFL2OYVGPG7HRQF5RS65URSRS2JJPCQU","version":"2.14.6","proto":1,"go":"go1.27.0","host":"127.0.0.1","port":14222,"headers":true,"max_payload":1048576,"client_id":5,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XDHIMSFMEQ32DSWS3G56AOFWEYD2PI4TYQPX5Q35BDT26CTOKHBWJAHI"} 
t=2.186 << PING
t=7.187 << PING
t=12.189 << -ERR 'Stale Connection'
t=12.190 -- server closed the socket

--- D1: what the server logged

--- D1: /varz
connections 0 total_connections 1 ping_interval(ns) 5000000000 ping_max 2 slow_consumers 0

### D2 — the control: the same client answering PONG
t=0.000 << INFO {"server_id":"NA7LTVXW2MB47YMSCPO2UDJEAFL2OYVGPG7HRQF5RS65URSRS2JJPCQU","server_name":"NA7LTVXW2MB47YMSCPO2UDJEAFL2OYVGPG7HRQF5RS65URSRS2JJPCQU","version":"2.14.6","proto":1,"go":"go1.27.0","host
t=0.000 >> CONNECT + PING
t=0.000 << PONG
t=0.000 << INFO {"server_id":"NA7LTVXW2MB47YMSCPO2UDJEAFL2OYVGPG7HRQF5RS65URSRS2JJPCQU","server_name":"NA7LTVXW2MB47YMSCPO2UDJEAFL2OYVGPG7HRQF5RS65URSRS2JJPCQU","version":"2.14.6","proto":1,"go":"go1.27.0","host":"127.0.0.1","port":14222,"headers":true,"max_payload":1048576,"client_id":6,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XDHIMSFMEQ32DSWS3G56AOFWEYD2PI4TYQPX5Q35BDT26CTOKHBWJAHI"} 
t=2.395 << PING
t=2.395 >> PONG
t=7.395 << PING
t=7.395 >> PONG
t=12.397 << PING
t=12.397 >> PONG
t=17.400 << PING
t=17.400 >> PONG
t=22.399 << PING
t=22.399 >> PONG

--- D2: the server's log since D1
[48470] 2026/09/04 02:01:48.684786 [INF] Starting http monitor on 127.0.0.1:18222
[48470] 2026/09/04 02:01:48.685406 [INF] Listening for client connections on 127.0.0.1:14222
[48470] 2026/09/04 02:01:48.685413 [INF] Server is ready

### D3 — the client's side at nats.go's defaults: the server SIGSTOPped for 7.5 minutes
SIGSTOP to the server (pid 48886) at 00:02:28
  +   0.0 s  02:02:25 Subscribing on stale.>
  +   0.0 s  02:02:25 >>> Connected to nats://127.0.0.1:14222 (127.0.0.1:14222)
  + 357.5 s  02:08:25 >>> Disconnected due to: nats: stale connection, will attempt reconnect
  + 357.5 s  02:08:25 >>> Setting reconnect delay to 640ms
  + 360.6 s  02:08:28 >>> Setting reconnect delay to 800ms
  + 362.6 s  02:08:30 >>> Setting reconnect delay to 2.15s
  + 366.6 s  02:08:35 >>> Setting reconnect delay to 1.979s
  + 370.6 s  02:08:39 >>> Setting reconnect delay to 3.424s
  + 376.6 s  02:08:44 >>> Setting reconnect delay to 1.873s
  watcher done after 377.6 s
SIGCONT at 00:08:46

--- D3: everything the subscriber printed
02:02:25 Subscribing on stale.> 
02:02:25 >>> Connected to nats://127.0.0.1:14222 (127.0.0.1:14222)
02:08:25 >>> Disconnected due to: nats: stale connection, will attempt reconnect
02:08:25 >>> Setting reconnect delay to 640ms
02:08:28 >>> Setting reconnect delay to 800ms
02:08:30 >>> Setting reconnect delay to 2.15s
02:08:35 >>> Setting reconnect delay to 1.979s
02:08:39 >>> Setting reconnect delay to 3.424s
02:08:44 >>> Setting reconnect delay to 1.873s
02:08:46 >>> Reconnected to nats://127.0.0.1:14222 (127.0.0.1:14222)

--- D3: the server's log after it was resumed
[48886] 2026/09/04 02:02:24.497718 [INF]   Name:     NDNJC5BYXJYZDTH6TH4ELHVC2VR7PA2KATJFHCKXBDDQFINTQV2SSC5Z
[48886] 2026/09/04 02:02:24.497723 [INF]   ID:       NDNJC5BYXJYZDTH6TH4ELHVC2VR7PA2KATJFHCKXBDDQFINTQV2SSC5Z
[48886] 2026/09/04 02:02:24.497736 [INF] Using configuration file: local/scratch/runs/client-lifecycle/plain.conf (sha256:b50201e34f73e3a070ca74074e4981150f5b80bdc61309d76a9b675dd4c43385)
[48886] 2026/09/04 02:02:24.498110 [INF] Starting http monitor on 127.0.0.1:18222
[48886] 2026/09/04 02:02:24.498215 [INF] Listening for client connections on 127.0.0.1:14222
[48886] 2026/09/04 02:02:24.498225 [INF] Server is ready

### done
```

## One correction made to this file

The **B3** bullet above first said the `ldm` INFO reached the client "0.6 s after the signal". That was
read off the client's own clock without anchoring it to the server's log. Re-checked against
`server.go:4463–4529` in the same session, before the step closed: `lameDuckMode` transfers Raft
leadership, waits a second, shuts JetStream down, and only then calls `sendLDMToClients`, and the
grace-period timer starts after that call — so the INFO is **about a second after the notice** and the
close is 10 s after the **INFO**, which is exactly the 11.011 s the transcript shows from notice to
`Closing existing clients`. The transcripts below are untouched.

Also from the same source, and the explanation of why this file's second pass has a B3 that shut down
instantly: if the server finds **no clients** at that point it calls `Shutdown()` immediately
(`server.go:4487–4494`) — which is what happened when the first `raw-watch.py` died at `t=0.000`.

## What was not tested

- **A client-side slow consumer**, and the `-ERR` strings behind an expired or revoked credential:
  both need a program that sets pending limits or a short-lived JWT, and both belong to step 4 of
  `inbox/plan-the-client-side-2026-09-03.md`.
- **Any client other than nats.go and the `nats` CLI.** Every per-client value in
  `wiki/reference/client-defaults.md` outside the Go and CLI columns is the documentation's word,
  marked as such.
- **A wedged link that is not a frozen process.** D3 freezes the server with `SIGSTOP`, which stops
  it answering but leaves the socket open — the same shape as a server too busy to read, not the
  same as a network path that black-holes packets (`pfctl` rules are not portable enough for this
  lab).
- **`no_advertise`**, and therefore the failure mode where a one-URL client never learns the pool.
  A1 and A2 show the discovery that `no_advertise` removes; the removal itself is not run here.
