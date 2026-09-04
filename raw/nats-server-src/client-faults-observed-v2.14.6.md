<!-- source: nats-server v2.14.6 binary, nats CLI 0.4.0, nats.go v1.53.1, nats-io/jwt v2.8.2, nats-io/nkeys v0.4.16, Go 1.27.0, OpenSSL 3.x, macOS, 2026-09-04 · five passes on standalone servers (client port 4222, monitoring 8222), scripts beside this file: client-faults-runA.sh (A1–A5), client-faults-runA2.sh (A4 re-run, A6), client-faults-runB.sh (B1–B5), client-faults-runB2.sh (B6–B7), client-faults-runC.sh (C1–C6); the programs are client-faults-slowsub.go, client-faults-deadsub.py, client-faults-mintjwt.go, client-faults-rawcreds.go and client-faults-authclient.go · configs inlined below · the transcripts are the scripts' output verbatim except that the `nats pub` progress-bar redraw lines are dropped -->
# nats-server v2.14.6 — the three client faults: a slow consumer, a credential expiring, a TLS handshake that does not match

The behavioural half of `raw/nats-go-src/subscription-v1.53.1.md` and
`raw/nats-server-src/client-errors-v2.14.6.md`, for `wiki/gotchas/slow-consumer-in-the-client.md`
and `wiki/gotchas/connection-closed-after-auth-error.md` (phase F step 4). Three runs:
**A** the two things called a slow consumer — the client's own pending buffer overflowing, and the
server giving up on a connection — measured side by side; **B** a user JWT and an account JWT
expiring *under a live connection*, on the wire, through the `nats` CLI, and through nats.go with
and without `IgnoreAuthErrorAbort`; **C** the three settings of `handshake_first` against a plain
client and a `--tlsfirst` one, timed.

The `nats` CLI cannot set pending limits and cannot mint a JWT with a chosen expiry, so A and B use
short Go programs (kept beside this file). No `nsc` was installed: `client-faults-mintjwt.go` builds
the operator/account/user chain directly with `nats-io/jwt` v2.8.2 and `nkeys` v0.4.16 — the same
libraries `nsc` uses and the same ones the server verifies against (`nats-server` v2.14.6's `go.mod`
pins `jwt/v2 v2.8.2`).

## What each run shows

- **A1** an async subscription with a **20 ms** handler and `SetPendingLimits(100, -1)` under 5,000
  messages published in 234 ms: **4,889 dropped, 111 delivered**, `MaxPending` 101 msgs / 9,191 B,
  the subscription still `IsValid()`, the connection still **CONNECTED**, `LastError` =
  `nats: slow consumer, messages dropped`. With **no async error callback set at all**, nats.go
  wrote **12 lines** to **stderr**: `nats: slow consumer, messages dropped on connection [5] for
  subscription on "orders.>"`. The limits the subscription started with, printed before any message
  arrived, were **500,000 msgs / 67,108,864 B**.
- **A2** the same run with an explicit `ErrorHandler`: it fired **13 times for 4,888 drops**, every
  time with `status CONNECTED` and the subscription named, and **stderr stayed empty** — setting a
  callback *replaces* `defaultErrHandler`, it does not add to it. Thirteen fires rather than one:
  the flag is cleared by the next message that *fits* (`sub.sc = false` on the success path,
  `nats.go:3974–3978`), so a sustained overflow re-arms and re-fires — far fewer than once per drop,
  far more than once per incident.
- **A3** `SetPendingLimits(0, -1)` and `SetPendingLimits(-1, 0)` both return **`nats: invalid
  argument`**; `SetPendingLimits(100, -1)` succeeds and `PendingLimits()` then reads **100 / -1** —
  a negative limit is *unlimited*, zero is an error.
- **A4** a **sync** subscription starts with **65,536 msgs / 67,108,864 B**, not 500,000 — the
  message limit comes from the channel's capacity (`sub.pMsgsLimit = cap(ch)`, `nats.go:5049–5053`).
  After the overflow `NextMsg` returned **`ErrSlowConsumer` 15 times** across 3,938 drops while
  delivering 62 messages, **and** the connection's default handler wrote the same 15 lines to
  stderr: a sync subscriber is told twice.
- **A5** the server's `write_deadline` branch. `write_deadline: "100ms"`, a raw subscriber that
  never reads its socket, 20,000 × 4 kB messages:
  `Slow Consumer Detected: WriteDeadline of 100ms exceeded with 2 chunks of 4029 total bytes.` then
  `Client connection closed: Slow Consumer (Write Deadline)`. `/varz` `slow_consumers` went 0 → 1
  and `slow_consumer_stats.clients` to 1.
- **A6** the server's *other* branch. `write_deadline: "30s"`, `max_pending: 1MB`, same subscriber:
  `Slow Consumer Detected: MaxPending of 1048576 Exceeded` then
  `Client connection closed: Slow Consumer (Pending Bytes)`, and `/connz?state=closed` shows
  `reason: "Slow Consumer (Pending Bytes)"`. **The client received no `-ERR` of any kind**: it drained
  **556,002 bytes and then read EOF**. Both server branches close in silence, which is why the
  client sees a read error and reconnects rather than an error string it can branch on.
- **A-varz** on the unmodified config, before either scene: `max_pending: 67108864`,
  `write_deadline: 10000000000` — 64 MB and 10 s, the documented defaults, read from the running
  server. During A1–A4 `slow_consumers` stayed **0**: a client-side slow consumer is invisible to
  the server.
- **B1** a user JWT valid for 20 s, on a raw client that signs the nonce itself: at **t+20.01 s**
  the server sent `-ERR 'User Authentication Expired'` and closed —
  `Client connection closed: Authentication Expired`.
- **B2** the same expiry under `nats sub --creds`. In 45 s the CLI printed **two lines**:
  `Subscribing on orders.>` and `>>> Disconnected due to: EOF, will attempt reconnect`. The server
  rejected it **11 times** in that window (`-ERR User Authentication Expired` once, then
  `-ERR Authorization Violation` ten times). The CLI never names the reason and never gives up.
- **B3** nats.go v1.53.1 at `ReconnectWait 500ms`: `ErrorHandler: nats: authentication expired`
  while **still CONNECTED**, then one reconnect attempt 0.51 s later that got the *same*
  `User Authentication Expired` — the same error from the same server — so `processAuthError` set
  `nc.ar` and the connection went **CLOSED after 1 reconnect**, `LastError` =
  `nats: User Authentication Expired`.
- **B6** the same at nats.go's own default `ReconnectWait` of **2 s**: the first reconnect (t+22.09)
  got `Authorization Violation` — a *different* error, so it retried — and the second (t+24.12) got
  it again, which aborted. **CLOSED 4.12 s after the expiry, after 2 reconnects**, `LastError` =
  `nats: Authorization Violation`. **The count of attempts before the abort depends on the
  reconnect delay**, because the server's answer changes: `jwt/v2`'s check is `now > c.Expires`
  (`claims.go:287`) at one-second resolution, so a reconnect landing inside the expiry second is
  *accepted* and then expired at once by `setExpiration`'s `expiresAt = 0` →
  `time.AfterFunc(0, c.authExpired)` (`client.go:1344–1353`, `:5980–5985`); from the next second on
  the JWT fails validation at CONNECT and the answer becomes `Authorization Violation`.
- **B4** the same creds with `IgnoreAuthErrorAbort()`: still **RECONNECTING after 45 s**, 46
  reconnect attempts, one rejection every ~0.55 s, `LastError = nats: Authorization Violation`. This
  is the `nats` CLI's configuration.
- **B5** an **account** JWT valid for 25 s, user JWT unexpiring: at t+25.00 the wire carried
  `-ERR 'Account Authentication Expired'` and closed with the same reason,
  `Client connection closed: Authentication Expired`.
- **B7** the creds file replaced 1 s after expiry (with an identical, still-expired file, so this
  shows only that the rotation window exists, not that a fresh credential is picked up): CLOSED at
  t+19.14 after 2 reconnects, unchanged. That nats.go re-reads the file per attempt is settled by
  source, not by this run — `UserCredentials` stores a callback that calls `userFromFile`, which
  does `os.ReadFile` (`nats.go:1499–1515`, `:6743–6755`).
- **C1** `nats --tlsfirst` against a server with plain TLS: `nats: error: nats: tls error: tls:
  first record does not look like a TLS handshake`, in **25 ms** — it fails fast, it does not hang.
- **C2** a plain client against `handshake_first: true`: `nats: error: read tcp
  127.0.0.1:51988->127.0.0.1:4222: i/o timeout` after **2.055 s**, the client's own connect timeout.
  The server had logged `[WRN] Clients that are not using "TLS Handshake First" option will fail to
  connect` at startup.
- **C3** `handshake_first: "auto"`: the plain client **succeeded** (0.093 s against 0.028 s on a
  plain-TLS server — the ~50 ms is the fallback delay) and `--tlsfirst` succeeded in 0.037 s. **No
  startup warning is logged**, because the warning is gated on there being no fallback
  (`server.go:2805–2812`).
- **C4** `handshake_first: "300ms"`: the plain client succeeded in **0.359 s** — the named delay,
  measured — and `--tlsfirst` in 0.027 s.
- **C6** `openssl s_client` against the same three: `wrong version number` on plain TLS, and a clean
  handshake with `Verify return code: 0 (ok)` against both `true` and `"auto"`.

## The configs

```
# base.conf — A1–A4 (defaults, so /varz reports the documented values)
port: 4222
http: 8222
server_name: cf1
```

```
# wd.conf — A5, the write_deadline branch
port: 4222
http: 8222
server_name: cfwd
write_deadline: "100ms"
max_pending: 1MB
```

```
# mp.conf — A6, the max_pending branch
port: 4222
http: 8222
server_name: cfmp
write_deadline: "30s"
max_pending: 1MB
```

```
# opmode/server.conf — B, written by client-faults-mintjwt.go (keys elided)
port: 4222
http: 8222
server_name: cfauth
operator: "…/opmode/operator.jwt"
system_account: ABEQLRS6T3LVZYHTORQYEBYJI2AFO3LBRP5MGK34D34VYCRXROERZS5M
resolver: MEMORY
resolver_preload: {
  ABEQ…ZS5M: "…SYS account JWT…"
  ADR2…OG7N: "…APP account JWT…"
}
```

```
# tls-{plain,first,auto,d300}.conf — C. Only the last line differs:
#   plain: (absent)   first: handshake_first: true
#   auto:  handshake_first: "auto"   d300: handshake_first: "300ms"
port: 4222
http: 8222
server_name: cftls-first
tls {
  cert_file: "tls/server.pem"
  key_file:  "tls/server-key.pem"
  ca_file:   "tls/ca.pem"
  timeout: 2
  handshake_first: true
}
```

The CA and server certificate were made with OpenSSL, `CN=localhost`,
`subjectAltName=DNS:localhost,IP:127.0.0.1`, 30 days.

---

## Run A — the two slow consumers

### A1 · client-side, no async error callback set

```
===== versions =====
nats-server: v2.14.6
0.4.0
require github.com/nats-io/nats.go v1.53.1

===== A1 -- client-side slow consumer, mode=default =====
--- flooding: nats pub orders.created --count 5000
 done! [5.00K in 234ms; 21.36K/s]
--- stdout:
connected: nats.go 1.53.1, server 2.14.6, cid 5, status CONNECTED
pending limits at subscribe time (the defaults): msgs=500000 bytes=67108864
pending limits set: msgs=100 bytes=-1
--- subscribed; flood it now ---
t+ 0.5s pending=0/0B dropped=0 delivered=0 valid=true status=0 conn=CONNECTED
t+ 1.0s pending=100/9100B dropped=585 delivered=3 valid=true status=0 conn=CONNECTED
t+ 1.5s pending=85/7735B dropped=4889 delivered=27 valid=true status=0 conn=CONNECTED
t+ 2.0s pending=61/5551B dropped=4889 delivered=51 valid=true status=0 conn=CONNECTED
t+ 2.5s pending=37/3367B dropped=4889 delivered=75 valid=true status=0 conn=CONNECTED
t+ 3.0s pending=13/1183B dropped=4889 delivered=99 valid=true status=0 conn=CONNECTED
t+ 3.5s pending=0/0B dropped=4889 delivered=111 valid=true status=0 conn=CONNECTED
t+ 4.0s pending=0/0B dropped=4889 delivered=111 valid=true status=0 conn=CONNECTED
t+ 4.5s pending=0/0B dropped=4889 delivered=111 valid=true status=0 conn=CONNECTED
t+ 5.0s pending=0/0B dropped=4889 delivered=111 valid=true status=0 conn=CONNECTED
--- final: handler ran 111, Delivered()=111, Dropped()=4889, MaxPending=101/9191B, sub valid=true, conn=CONNECTED, LastError=nats: slow consumer, messages dropped
--- stderr (this is where defaultErrHandler writes):
nats: slow consumer, messages dropped on connection [5] for subscription on "orders.>"
nats: slow consumer, messages dropped on connection [5] for subscription on "orders.>"
nats: slow consumer, messages dropped on connection [5] for subscription on "orders.>"
nats: slow consumer, messages dropped on connection [5] for subscription on "orders.>"
nats: slow consumer, messages dropped on connection [5] for subscription on "orders.>"
nats: slow consumer, messages dropped on connection [5] for subscription on "orders.>"
nats: slow consumer, messages dropped on connection [5] for subscription on "orders.>"
nats: slow consumer, messages dropped on connection [5] for subscription on "orders.>"
nats: slow consumer, messages dropped on connection [5] for subscription on "orders.>"
nats: slow consumer, messages dropped on connection [5] for subscription on "orders.>"
nats: slow consumer, messages dropped on connection [5] for subscription on "orders.>"
nats: slow consumer, messages dropped on connection [5] for subscription on "orders.>"
```

(Twelve stderr lines for 4,889 dropped messages.)

### A2 · client-side, with an explicit async error callback

```
===== A2 -- client-side slow consumer, mode=callback =====
--- flooding: nats pub orders.created --count 5000
 done! [5.00K in 260ms; 19.22K/s]
--- stdout:
connected: nats.go 1.53.1, server 2.14.6, cid 7, status CONNECTED
pending limits at subscribe time (the defaults): msgs=500000 bytes=67108864
pending limits set: msgs=100 bytes=-1
--- subscribed; flood it now ---
t+ 0.5s pending=0/0B dropped=0 delivered=0 valid=true status=0 conn=CONNECTED
t+ 1.0s pending=0/0B dropped=0 delivered=0 valid=true status=0 conn=CONNECTED
[cb 1] err="nats: slow consumer, messages dropped" sub=orders.> status=CONNECTED
[cb 2] err="nats: slow consumer, messages dropped" sub=orders.> status=CONNECTED
[cb 3] err="nats: slow consumer, messages dropped" sub=orders.> status=CONNECTED
[cb 4] err="nats: slow consumer, messages dropped" sub=orders.> status=CONNECTED
[cb 5] err="nats: slow consumer, messages dropped" sub=orders.> status=CONNECTED
[cb 6] err="nats: slow consumer, messages dropped" sub=orders.> status=CONNECTED
[cb 7] err="nats: slow consumer, messages dropped" sub=orders.> status=CONNECTED
[cb 8] err="nats: slow consumer, messages dropped" sub=orders.> status=CONNECTED
[cb 9] err="nats: slow consumer, messages dropped" sub=orders.> status=CONNECTED
[cb 10] err="nats: slow consumer, messages dropped" sub=orders.> status=CONNECTED
[cb 11] err="nats: slow consumer, messages dropped" sub=orders.> status=CONNECTED
[cb 12] err="nats: slow consumer, messages dropped" sub=orders.> status=CONNECTED
[cb 13] err="nats: slow consumer, messages dropped" sub=orders.> status=CONNECTED
t+ 1.5s pending=99/9009B dropped=4888 delivered=14 valid=true status=0 conn=CONNECTED
t+ 2.0s pending=75/6825B dropped=4888 delivered=38 valid=true status=0 conn=CONNECTED
t+ 2.5s pending=51/4641B dropped=4888 delivered=62 valid=true status=0 conn=CONNECTED
t+ 3.0s pending=27/2457B dropped=4888 delivered=86 valid=true status=0 conn=CONNECTED
t+ 3.5s pending=3/273B dropped=4888 delivered=110 valid=true status=0 conn=CONNECTED
t+ 4.0s pending=0/0B dropped=4888 delivered=112 valid=true status=0 conn=CONNECTED
t+ 4.5s pending=0/0B dropped=4888 delivered=112 valid=true status=0 conn=CONNECTED
t+ 5.0s pending=0/0B dropped=4888 delivered=112 valid=true status=0 conn=CONNECTED
--- final: handler ran 112, Delivered()=112, Dropped()=4888, MaxPending=101/9191B, sub valid=true, conn=CONNECTED, LastError=nats: slow consumer, messages dropped
--- async error callback fired 13 time(s) for 4888 dropped message(s)
--- stderr (this is where defaultErrHandler writes):
```

(stderr empty — the caller's handler replaced the default one.)

### A3 · what `SetPendingLimits` accepts

```
===== A3 -- SetPendingLimits(0, -1) and what a negative limit means =====
connected: nats.go 1.53.1, server 2.14.6, cid 9, status CONNECTED
pending limits at subscribe time (the defaults): msgs=500000 bytes=67108864
SetPendingLimits(0, -1) -> nats: invalid argument
SetPendingLimits(-1, 0) -> nats: invalid argument
SetPendingLimits(100, -1) -> <nil>
PendingLimits() now: msgs=100 bytes=-1  (negative = unlimited)
```

### A4 · a sync subscription: a different default, and `NextMsg`

```
===== A4 -- a sync subscription: the default limit, and NextMsg after the overflow =====
 done! [4.00K in 222ms; 18.02K/s]
connected: nats.go 1.53.1, server 2.14.6, cid 5, status CONNECTED
pending limits at subscribe time (the defaults): msgs=65536 bytes=67108864
pending limits set: msgs=50 bytes=-1
--- subscribed; flood it now ---
NextMsg -> ErrSlowConsumer (#1), dropped so far 139
NextMsg -> ErrSlowConsumer (#2), dropped so far 366
NextMsg -> ErrSlowConsumer (#3), dropped so far 723
NextMsg -> ErrSlowConsumer (#4), dropped so far 724
NextMsg -> ErrSlowConsumer (#5), dropped so far 1097
NextMsg -> ErrSlowConsumer (#6), dropped so far 1500
NextMsg -> ErrSlowConsumer (#7), dropped so far 1901
NextMsg -> ErrSlowConsumer (#8), dropped so far 2281
NextMsg -> ErrSlowConsumer (#9), dropped so far 2673
NextMsg -> ErrSlowConsumer (#10), dropped so far 2674
NextMsg -> ErrSlowConsumer (#11), dropped so far 3080
NextMsg -> ErrSlowConsumer (#12), dropped so far 3492
NextMsg -> ErrSlowConsumer (#13), dropped so far 3921
NextMsg -> ErrSlowConsumer (#14), dropped so far 3922
NextMsg -> ErrSlowConsumer (#15), dropped so far 3938
sync: delivered 62, ErrSlowConsumer returned 15 times
--- final: handler ran 0, Delivered()=62, Dropped()=3938, MaxPending=51/3213B, sub valid=true, conn=CONNECTED, LastError=nats: slow consumer, messages dropped
--- stderr:
(15 × "nats: slow consumer, messages dropped on connection [5] for subscription on \"orders.>\"")
```

### A5 · server-side, the `write_deadline` branch

```
===== A5/A6 -- the server-side slow consumer (write_deadline 100ms, max_pending 1MB) =====
{'slow_consumers': 0, 'max_pending': 1048576, 'write_deadline': 100000000}
--- flooding a subscriber that never reads its socket
 done! [20.00K in 1.29s; 15.50K/s]
--- the raw subscriber's view:
INFO: INFO {"server_id":"NCRISDPLOK7XKWPQD7UNVVLZ6QOIPMUTJABHEC6XMH7J6TQI3NEO6HA2","server_name":"cfwd","version":"2.14.6",…,"max_payload":1048576,…}
PONG: PONG
subscribed; now sleeping without reading for 20 s
--- /varz after:
{'slow_consumers': 1, 'slow_consumer_stats': {'clients': 1, 'routes': 0, 'gateways': 0, 'leafs': 0}}
--- the server log lines:
[83599] 2026/09/04 03:10:16.998280 [INF] 127.0.0.1:51814 - cid:5 - "deadsub" - Slow Consumer Detected: WriteDeadline of 100ms exceeded with 2 chunks of 4029 total bytes.
[83599] 2026/09/04 03:10:16.998291 [DBG] 127.0.0.1:51814 - cid:5 - "deadsub" - Client connection closed: Slow Consumer (Write Deadline)
```

The `/varz` reading on the *unmodified* server, before this scene and after A1–A4:

```
{'slow_consumers': 0, 'slow_consumer_stats': {'clients': 0, 'routes': 0, 'gateways': 0, 'leafs': 0}, 'max_pending': 67108864, 'write_deadline': 10000000000}
```

### A6 · server-side, the `max_pending` branch, and what the client receives

```
===== A6 -- the server's max_pending branch (write_deadline 30s, max_pending 1MB) =====
 done! [20.00K in 6.287s; 3.18K/s]
--- waiting for the raw subscriber to wake and drain
INFO: INFO {"server_id":"NCX5SPXWVIEJXVVJRHQ52QGZPREPYPAUJQ5US5CZ66XUK4EBQ4VI5J3D","server_name":"cfmp","version":"2.14.6",…}
PONG: PONG
subscribed; now sleeping without reading for 20 s
woke after 20.0 s; draining what the kernel buffered
socket EOF after 556002 bytes
last bytes: xxxxxxxxxx…xxxxx
--- /varz:
{'slow_consumers': 1, 'slow_consumer_stats': {'clients': 1, 'routes': 0, 'gateways': 0, 'leafs': 0}, 'max_pending': 1048576, 'write_deadline': 30000000000}
--- server log:
[84250] 2026/09/04 03:11:23.510467 [INF] 127.0.0.1:51829 - cid:5 - "deadsub" - Slow Consumer Detected: MaxPending of 1048576 Exceeded
[84250] 2026/09/04 03:11:23.510475 [DBG] 127.0.0.1:51829 - cid:5 - "deadsub" - Client connection closed: Slow Consumer (Pending Bytes)
[84250] 2026/09/04 03:11:29.898714 [DBG] 127.0.0.1:51830 - cid:6 - "v1.51.0:go:NATS CLI Version 0.4.0" - Client connection closed: Client Closed
--- /connz closed connections:
[('deadsub', 'Slow Consumer (Pending Bytes)'), ('NATS CLI Version 0.4.0', 'Client Closed')]
```

Note in passing: the CLI identifies itself as `v1.51.0:go:NATS CLI Version 0.4.0` — natscli 0.4.0
is built against nats.go **v1.51.0**, while every client value quoted in this wiki is read at
**v1.53.1**.

---

## Run B — a credential expiring under a live connection

### B1 · the bytes on the wire (user JWT valid 20 s)

```
===== B1 -- the wire, at expiry (user JWT valid 20 s) =====
operator ODXEU4YG27TMWPDKQZXE6ICNDAHHEXHQVAJDE45YSCB34E4CMZWHBJ34
SYS ABEQLRS6T3LVZYHTORQYEBYJI2AFO3LBRP5MGK34D34VYCRXROERZS5M
APP ADR2HJBED2TUNGAN5H7F3Z5ITSKHJTKBF5B5QJ2LSUQZ6FEE3JCGOG7N
user creds …/opmode/app-user.creds (expires in 20s)
t+  0.00s  << INFO {"server_id":"NCEEY2LM…","server_name":"cfauth","version":"2.14.6","proto":1,…,"auth_required":true,"max_payload":1048576,"client_id":5,"client_ip":"127.0.0.1","nonce":"BZXmb4KwjNY12OY","api_lvl":4,…}
t+  0.00s  >> CONNECT (jwt+sig, 808 bytes)
t+  0.01s  << PONG
t+  0.01s  << INFO {…,"connect_info":true,"remote_account":"ADR2HJBED2TUNGAN5H7F3Z5ITSKHJTKBF5B5QJ2LSUQZ6FEE3JCGOG7N",…}
t+  2.12s  << PING
t+  5.01s  << PONG
t+ 10.01s  << PONG
t+ 15.01s  << PONG
t+ 20.01s  << PONG
t+ 20.01s  << -ERR 'User Authentication Expired'
t+ 20.01s  socket ended: EOF
--- server log:
[85204] … [DBG] … - Authenticated JWT: Client "UCBLK4W3…" (claim-name: "order-svc", claim-tags: []) signed with "ADR2HJBE…" by Account "ADR2HJBE…" (claim-name: "APP", …)
[85204] 2026/09/04 03:13:37.732454 [TRC] … - ->> [-ERR User Authentication Expired]
[85204] 2026/09/04 03:13:37.732510 [DBG] … - User Authentication Expired - Account:ADR2HJBE…/APP - jwt:UCBLK4W3…
[85204] 2026/09/04 03:13:37.732548 [DBG] … - Client connection closed: Authentication Expired
```

### B2 · the `nats` CLI over the same expiry

```
===== B2 -- the nats CLI (IgnoreAuthErrorAbort, unlimited reconnects) =====
--- what the CLI printed (first 25 lines):
03:13:37 Subscribing on orders.> 
03:13:57 >>> Disconnected due to: EOF, will attempt reconnect
--- how many times it was rejected:
0
--- server log:
13
```

The CLI's whole output in 45 seconds is those two lines; the second number is a `grep -c` over the
CLI's log for `authoriz|expired`, and the third over the server's. The `-ERR` strings the server
actually sent in that window:

```
  10 -ERR Authorization Violation
   1 -ERR User Authentication Expired
```

### B3 · nats.go at `ReconnectWait 500ms` — one attempt, then CLOSED

```
===== B3 -- nats.go v1.53.1, default rules =====
t+  0.01s  connected: status=CONNECTED cid=5 server=NDRZPH4EUSCXB5JDY5CPPYZCRKX7XTGMII2IRLC3WL35EGZEOWZGFY63
t+ 19.01s  ErrorHandler: nats: authentication expired   (status CONNECTED)
t+ 19.01s  Disconnected: err=EOF  (status RECONNECTING)
t+ 19.52s  ErrorHandler: nats: authentication expired   (status CLOSED)
t+ 19.52s  CLOSED. LastError=nats: User Authentication Expired
t+ 20.02s  status CLOSED after 1 reconnect(s); stopping. LastError=nats: User Authentication Expired
--- server log (auth):
[85646] 2026/09/04 03:14:42.277342 [TRC] … cid:5 - "v1.53.1:go:order-svc" … ->> [-ERR User Authentication Expired]
[85646] 2026/09/04 03:14:42.277621 [DBG] … cid:5 … Client connection closed: Authentication Expired
[85646] 2026/09/04 03:14:42.788375 [TRC] … cid:7 - ->> [-ERR User Authentication Expired]
[85646] 2026/09/04 03:14:42.788475 [DBG] … cid:7 - Client connection closed: Authentication Expired
--- /connz closed:
[('order-svc', 'Authentication Expired'), ('order-svc', 'Authentication Expired')]
```

### B6 · nats.go at its own default `ReconnectWait` of 2 s — two attempts

```
===== B6 -- nats.go at its own defaults (ReconnectWait 2 s, MaxReconnects 60) =====
t+  0.00s  connected: status=CONNECTED cid=5 server=NDFNXRXNJ5DQUCLLQ57DPHASPGD2MBVPHOVUPFXGCJVM75PLYSKHQ3ZZ
t+ 20.00s  ErrorHandler: nats: authentication expired   (status RECONNECTING)
t+ 20.00s  Disconnected: err=EOF  (status RECONNECTING)
t+ 22.09s  ErrorHandler: nats: authorization violation   (status RECONNECTING)
t+ 24.12s  ErrorHandler: nats: authorization violation   (status CLOSED)
t+ 24.12s  CLOSED. LastError=nats: Authorization Violation
t+ 26.01s  status CLOSED after 2 reconnect(s); stopping. LastError=nats: Authorization Violation
--- the -ERR strings the server sent:
   2 -ERR Authorization Violation
   1 -ERR User Authentication Expired
```

### B4 · the same creds with `IgnoreAuthErrorAbort()` — the CLI's configuration

```
===== B4 -- nats.go with IgnoreAuthErrorAbort, same creds =====
t+  0.00s  connected: status=CONNECTED cid=5 server=NAA5YWJ7FELR3YTQV7HIDIRECULLO5USX54YZHXYFSR5Q6V6C23WXRC6
t+ 20.00s  ErrorHandler: nats: authentication expired   (status RECONNECTING)
t+ 20.00s  Disconnected: err=EOF  (status RECONNECTING)
t+ 20.59s  ErrorHandler: nats: authentication expired   (status RECONNECTING)
t+ 21.16s  ErrorHandler: nats: authorization violation   (status RECONNECTING)
t+ 21.67s  ErrorHandler: nats: authorization violation   (status RECONNECTING)
   … one every ~0.55 s …
t+ 45.55s  ErrorHandler: nats: authorization violation   (status RECONNECTING)
t+ 46.02s  still RECONNECTING after 45s; reconnects=46 LastError=nats: Authorization Violation
```

### B5 · an account JWT expiring instead

```
===== B5 -- an ACCOUNT JWT expiring under a live connection =====
user creds …/opmode5/app-user.creds (expires in 0s)
account APP expires in 25s
t+  0.00s  << INFO {"server_id":"NBJTC2FS…","server_name":"cfauth","version":"2.14.6",…,"auth_required":true,…,"nonce":"m7x4K1LTEut4Oa4",…}
t+  0.00s  >> CONNECT (jwt+sig, 785 bytes)
t+  0.00s  << PONG
t+  0.00s  << INFO {…,"remote_account":"ADL4CBCX…",…}
t+  2.38s  << PING
t+  5.00s  << PONG
t+ 10.00s  << PONG
t+ 15.00s  << PONG
t+ 20.00s  << PONG
t+ 25.00s  << -ERR 'Account Authentication Expired'
t+ 25.00s  socket ended: EOF
--- server log:
[86075] 2026/09/04 03:15:54.431274 [TRC] … ->> [-ERR Account Authentication Expired]
[86075] 2026/09/04 03:15:54.431487 [DBG] … Account Authentication Expired - Account:ADL4CBCX…/APP - jwt:UA7XYXOF…
[86075] 2026/09/04 03:15:54.431544 [DBG] … Client connection closed: Authentication Expired
```

### B7 · replacing the creds file inside the retry window

```
===== B7 -- rotate the creds inside the window: does the retry recover the connection? =====
user creds …/opmode7/app-user.creds (expires in 15s)
t+  0.00s  connected: status=CONNECTED cid=5 server=NAATGPRUPAKILFIZYTIWCELH4XSZ3CQ4NS7MI3XRRJW7QWETHXKZHDOZ
t+ 15.00s  ErrorHandler: nats: authentication expired   (status RECONNECTING)
t+ 15.00s  Disconnected: err=EOF  (status RECONNECTING)
creds file replaced at 03:18:48
t+ 17.07s  ErrorHandler: nats: authorization violation   (status RECONNECTING)
t+ 19.14s  ErrorHandler: nats: authorization violation   (status CLOSED)
t+ 19.14s  CLOSED. LastError=nats: Authorization Violation
t+ 20.01s  status CLOSED after 2 reconnect(s); stopping. LastError=nats: Authorization Violation
```

The replacement file carried the **same, already-expired** JWT (a fresh user would need a new key
pair and a new account signature, which the run did not mint), so this scene shows only the timing
of the window, not a successful rotation.

---

## Run C — `handshake_first`, from the client's side

```
===== server: tls-plain.conf =====
[86958] … [DBG] [::1]:51937 - cid:5 - Starting TLS client connection handshake
[86958] … [DBG] [::1]:51937 - cid:5 - TLS handshake complete
--- plain client (default handshake: expects the INFO first)
03:17:28 Published 91 bytes to "orders.created"
    elapsed 0.028 s
--- --tlsfirst client
nats: error: nats: tls error: tls: first record does not look like a TLS handshake
    elapsed 0.025 s

===== server: tls-first.conf =====
[87407] 2026/09/04 03:17:28.811110 [WRN] Clients that are not using "TLS Handshake First" option will fail to connect
--- plain client (default handshake: expects the INFO first)
nats: error: read tcp 127.0.0.1:51988->127.0.0.1:4222: i/o timeout
    elapsed 2.055 s
--- --tlsfirst client
03:17:30 Published 91 bytes to "orders.created"
    elapsed 0.035 s

===== server: tls-auto.conf =====
--- plain client (default handshake: expects the INFO first)
03:17:31 Published 91 bytes to "orders.created"
    elapsed 0.093 s
--- --tlsfirst client
03:17:31 Published 91 bytes to "orders.created"
    elapsed 0.037 s

===== server: tls-d300.conf =====
--- plain client (default handshake: expects the INFO first)
03:17:32 Published 91 bytes to "orders.created"
    elapsed 0.359 s
--- --tlsfirst client
03:17:32 Published 91 bytes to "orders.created"
    elapsed 0.027 s

===== C6 -- openssl s_client, the diagnostic side effect =====
--- s_client against handshake_first=plain
80E11DED01000000:error:0A00010B:SSL routines:tls_validate_record_header:wrong version number:ssl/record/methods/tlsany_meth.c:78:
CONNECTED(00000003)
Verification: OK
Verify return code: 0 (ok)
--- s_client against handshake_first=first
CONNECTED(00000003)
Verification: OK
Verify return code: 0 (ok)
    Verify return code: 0 (ok)
--- s_client against handshake_first=auto
CONNECTED(00000003)
Verification: OK
Verify return code: 0 (ok)
```

The `[WRN]` line appears only for `handshake_first: true`; neither `"auto"` nor `"300ms"` logs it.
Only the `first` scene prints it because the warning is gated on
`opts.TLSHandshakeFirst && opts.TLSHandshakeFirstFallback == 0` (`server.go:2805–2812`).

The matrix, as run:

| server `tls { … }` | plain client | `--tlsfirst` client | startup `[WRN]` | `openssl s_client` |
|---|---|---|---|---|
| (no `handshake_first`) | works, 0.028 s | **fails**, 0.025 s, `first record does not look like a TLS handshake` | no | `wrong version number` |
| `handshake_first: true` | **fails**, 2.055 s, `i/o timeout` | works, 0.035 s | **yes** | clean, `Verify return code: 0 (ok)` |
| `handshake_first: "auto"` | works, 0.093 s (~50 ms fallback) | works, 0.037 s | no | clean |
| `handshake_first: "300ms"` | works, 0.359 s (~300 ms fallback) | works, 0.027 s | no | (not run) |
