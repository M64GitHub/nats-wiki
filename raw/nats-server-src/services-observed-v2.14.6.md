<!-- observed run · nats-server v2.14.6 (`nats-server --version` → `nats-server: v2.14.6`), nats CLI 0.4.0, nats.go v1.53.1 (the service program's own pin) · macOS 15 (darwin/arm64) · 2026-09-04 -->
# nats-server v2.14.6 observed — the services framework: what a service puts on the server, what `$SRV` answers, what a service error looks like on the wire, and what a blocked instance does to a queue group

Runs for step 6 of `inbox/plan-the-client-side-2026-09-03.md`. The spec side is `raw/adr/ADR-32.md`
and the three response schemas in `raw/jsm-go/micro-*-v0.4.1.json`; the docs side is
`raw/nats-docs/learn/services/` and `raw/nats-docs/reference/services*`.

**The services framework is entirely a client-library convention.** `$SRV` appears nowhere in
`nats-server`'s source: the server has no service registry, no discovery verb and no reservation of
the prefix. Everything below is what the *client* does, seen from the server.

Six passes, all on one machine, all against the same binary:

| pass | script | what it does |
|---|---|---|
| A | `services-runA.sh` | the `nats service serve` demo service ×2 — what it creates, and every `$SRV` body |
| B | `services-runB.sh` | is `$SRV` reserved by the server, and what subject permissions do to discovery |
| C | `services-runC.sh`, `-runC2.sh` | a real six-endpoint service (nats.go v1.53.1): groups, per-endpoint queue groups, the service error as bytes, and whether one blocked endpoint blocks its siblings |
| D | `services-runD.sh`, `-runD2.sh` | `Stop()` drains and an abrupt exit does not |
| E | `services-runE.sh`, `-runE2.sh` | `$SRV` and service endpoints across a leafnode |

The service program is `services-svc.go` — a nats.go v1.53.1 `micro` service with a group, five grouped
endpoints (`check`, `slow`, `bad`, `vip` with its own queue group, `bcast` with the queue group
disabled) and one service-level endpoint on an explicit subject (`health` → `inv.health`). The raw
client is `services-raw.py` (the step-5 `wire-protocol-raw.py`, unchanged but for a larger payload
print). The subscription dump is `services-subsz.py`. Configs are quoted inline at each scene.
Transcripts and per-scene logs are the unedited originals in the maintainer's scratch
(`local/scratch/runs/services/`, not public); everything quoted below is copied verbatim from them.

---

## A · What `nats service serve` creates

Config (`base.conf`) throughout A, B1, C and D:

```
port: 14222
http: 18222
server_name: SVC1
```

### A1 · two instances of the same service

`nats service serve DEMO`, twice. Each prints:

```
NATS CLI Service DEMO handler 81600 waiting for requests on nats://127.0.0.1:14222

Listening Subjects:

  DEMO.echo: Echo Service
```

The demo service is `Name: DEMO`, `Version: 1.0.0`, `Description: NATS CLI Demo Service (DEMO)`, one
group named after the service and one endpoint `echo` — so the subject is `<name>.echo`
(`natscli@v0.4.0/cli/service_command.go:147–182`, `grp := srv.AddGroup(c.name)` then
`grp.AddEndpoint("echo", …)`). `learn/services/your-first-service.md:39–41` states the `<name>.echo`
subject; confirmed.

### A2 · `nats service list --json` is the raw `info_response`

```json
[
  {
    "name": "DEMO",
    "id": "DQpyBxNsnfQF8IA1mVo0dm",
    "version": "1.0.0",
    "metadata": {
      "_nats.client.created.library": "natscli",
      "_nats.client.created.version": "0.4.0"
    },
    "type": "io.nats.micro.v1.info_response",
    "description": "NATS CLI Demo Service (DEMO)",
    "endpoints": [
      {
        "name": "echo",
        "subject": "DEMO.echo",
        "queue_group": "q",
        "metadata": null
      }
    ]
  },
  { … the second instance, same name and version, different id … }
]
```

Two instances of one service differ only in `id`. natscli stamps two metadata keys of its own.
`metadata: null` on an endpoint that set none — the schema's `oneOf` includes `null`
(`raw/jsm-go/micro-info_response-v0.4.1.json`).

### A3 · `nats service info` shows **one** instance, with two running

```
Service Information

          Service: DEMO (doj3sxHIfpYX6X3lEV5aSi)
      Description: NATS CLI Demo Service (DEMO)
          Version: 1.0.0
         Metadata: _nats.client.created.library: natscli
                   _nats.client.created.version: 0.4.0
```

`nats service list` (which gathers by deadline) showed both ids in the same run; `info` takes the
first reply and stops. This is the pitfall `learn/services/discovery.md:325` warns callers about,
living in the CLI itself. `nats service info DEMO <id>` addresses one instance deliberately.

### A4 · the `$SRV.INFO` body, one reply per instance

`nats request '$SRV.INFO' '' --replies=0` (0 = collect until the timeout):

```
05:08:10 Received with rtt 436.542µs
{"name":"DEMO","id":"doj3sxHIfpYX6X3lEV5aSi","version":"1.0.0","metadata":{"_nats.client.created.library":"natscli","_nats.client.created.version":"0.4.0"},"type":"io.nats.micro.v1.info_response","description":"NATS CLI Demo Service (DEMO)","endpoints":[{"name":"echo","subject":"DEMO.echo","queue_group":"q","metadata":null}]}

05:08:10 Received with rtt 468.917µs
{"name":"DEMO","id":"nUv3ey9KwkBMUgYJNUqxSn", … }
```

### A5 · the `$SRV.PING` body — five fields, nothing else

```
{"name":"DEMO","id":"nUv3ey9KwkBMUgYJNUqxSn","version":"1.0.0","metadata":{"_nats.client.created.library":"natscli","_nats.client.created.version":"0.4.0"},"type":"io.nats.micro.v1.ping_response"}
```

No `started`, no `description`, no `endpoints`. The round-trip time a `PING` is "for" is measured by
the caller; nothing in the reply carries it.

### A6 · six requests to `DEMO.echo`, then `nats service stats`

```
│ ID                     │ Endpoint │ Requests │ Queue Group │ Errors │ Processing Time │ Average Time │
│ DQpyBxNsnfQF8IA1mVo0dm │ echo     │ 4        │ q           │ 0      │ 286µs           │ 71µs         │
│ cISlwMwTbFJu2nGnbOppdG │ echo     │ 2        │ q           │ 0      │ 192µs           │ 96µs         │
│                        │          │ 6        │             │ 0      │ 477µs           │ 80µs         │
```

Six requests split **4 / 2**. Two earlier passes of the same scene split **1 / 5** and **5 / 1**. The
CLI sums the per-instance counters into the last row; the server keeps no aggregate.

### A7 · the `$SRV.STATS.DEMO` body

```
{"name":"DEMO","id":"doj3sxHIfpYX6X3lEV5aSi","version":"1.0.0","metadata":{…},"type":"io.nats.micro.v1.stats_response","started":"2026-09-04T03:08:09.53948Z","endpoints":[{"name":"echo","subject":"DEMO.echo","queue_group":"q","num_requests":1,"num_errors":0,"last_error":"","processing_time":85959,"average_processing_time":85959,"data":{"total_payload":5}}]}
```

`started` is RFC3339 **UTC** (the CLI prints local time). `processing_time` and
`average_processing_time` are **nanoseconds** as integers. `last_error` is present as an empty string
when there has been none — the schema's `endpoints[]` item marks it required. `data` is whatever the
service's `StatsHandler` returned; natscli's returns `{"total_payload": <bytes>}`.

### A8 · `nats service ping DEMO`

```
DEMO nUv3ey9KwkBMUgYJNUqxSn                        rtt=2ms
DEMO doj3sxHIfpYX6X3lEV5aSi                        rtt=2ms
```

One line per instance — the health check that counts running copies.

### A9 · the subscriptions one instance makes: **ten**, of which nine are `$SRV`

`/subsz?subs=1&acc=$G`, two instances running (cid 5 and cid 6):

```
  num_subscriptions 24; non-$SYS entries 20:
  cid   5  sid   1  msgs    0  qgroup -              $SRV.STATS
  cid   5  sid   2  msgs    2  qgroup -              $SRV.STATS.DEMO
  cid   5  sid   3  msgs    1  qgroup -              $SRV.STATS.DEMO.cISlwMwTbFJu2nGnbOppdG
  cid   5  sid   4  msgs    2  qgroup -              $SRV.INFO
  cid   5  sid   5  msgs    1  qgroup -              $SRV.INFO.DEMO
  cid   5  sid   6  msgs    0  qgroup -              $SRV.INFO.DEMO.cISlwMwTbFJu2nGnbOppdG
  cid   5  sid   7  msgs    1  qgroup -              $SRV.PING
  cid   5  sid   8  msgs    1  qgroup -              $SRV.PING.DEMO
  cid   5  sid   9  msgs    0  qgroup -              $SRV.PING.DEMO.cISlwMwTbFJu2nGnbOppdG
  cid   5  sid  10  msgs    2  qgroup q              DEMO.echo
  cid   6  sid   1  msgs    1  qgroup -              $SRV.PING
  … the same nine for the second instance, its own id in the third level …
  cid   6  sid  10  msgs    4  qgroup q              DEMO.echo
```

**Three verbs × three levels = nine plain subscriptions, plus one queue subscription per endpoint.**
None of the nine carries a queue group — that is *why* discovery is a broadcast: every instance
answers every `$SRV` request it matches. The verb order differs between the two instances (map
iteration), which is not meaningful.

### A10 · addressing one instance

`nats request '$SRV.INFO.DEMO.DQpyBxNsnfQF8IA1mVo0dm' '' --replies=0` → exactly one reply, that
instance's.

### A11 · SIGINT on one instance

`nats service serve` never calls `Stop()`: `serveAction` blocks on `<-ctx.Done()` and returns
(`natscli@v0.4.0/cli/service_command.go:190–194`), so a Ctrl-C closes the connection with no drain.
Observed: the interrupted process printed no drain line, and `nats service list` 1.2 s later showed
only the survivor. (A backgrounded process in a shell script inherits `SIGINT` ignored unless job
control is on; the script sets `set -m`.)

---

## B · Is `$SRV` reserved, and what do permissions do?

### B1 · the server does not reserve `$SRV`

An ordinary client, no auth on the server:

```
05:10:10 Published 5 bytes to "$SRV.PING"
pub exit=0
```

The publish is **accepted**. `$SRV` appears nowhere in `nats-server`'s source; the reservation is a
client-side convention (ADR-32: "This prefix is reserved for internal handlers"). A second client
subscribed to `$SRV.>` and saw another caller's discovery request in full, reply subject included:

```
[#1] Received on "$SRV.PING.DEMO" with reply "_INBOX.eUWs5RxzZwA8NY0n7Q9nJy.pnZiDtWq"
```

An endpoint subject is an ordinary subscription too: `nats pub 'DEMO.echo' 'not a request'` (no reply
subject) was accepted and the handler ran —

```
05:10:13 Published 13 bytes to "DEMO.echo"
05:10:13 Handling request on subject DEMO.echo
```

— and the reply went nowhere. A service endpoint cannot tell a request from a publish.

### B2 · subject permissions are the only isolation there is

Config (`perms.conf`): three users, `svc` unrestricted, `caller` allowed to publish only
`orders.>` and `_INBOX.>`, `ops` allowed to publish only `$SRV.>` and `_INBOX.>`; both restricted
users may subscribe only to `_INBOX.>`.

| client | action | result |
|---|---|---|
| `caller` | `nats request orders.echo 'hi'` | answered, `rtt 405.334µs` |
| `caller` | `nats request '$SRV.PING' ''` | nothing; the CLI printed only "Sending request" and timed out |
| `ops` | `nats request '$SRV.PING' '' --replies=0` | the `ping_response` body |
| `ops` | `nats request orders.echo 'hi'` | nothing; timed out |

The server logged both refusals:

```
[83907] … "$G/user:caller" - Publish Violation - Subject "$SRV.PING"
[83907] … "$G/user:ops" - Publish Violation - Subject "orders.echo"
```

So discovery and invocation separate cleanly by publish permission, and neither client was told why —
the violation reaches the connection as an async error the CLI does not print.

---

## C · A real six-endpoint service (nats.go v1.53.1)

### C1 · the subject layout the framework builds

The program's own line, and `nats service info Inventory`:

```
[05:11:10.702 A] endpoints: check=orders.inventory.check(q="q") slow=orders.inventory.slow(q="q") bad=orders.inventory.bad(q="q") vip=orders.inventory.vip(q="q-vip") bcast=orders.inventory.bcast(q="") health=inv.health(q="q")
```

```
          Service: Inventory (Yw9iT921Z8BOfT5NbFJrbC)
      Description: order inventory, observed
          Version: 1.2.3
         Metadata: label: A
                    zone: eu-1
…
               Name: vip
            Subject: orders.inventory.vip
        Queue Group: q-vip

               Name: bcast
            Subject: orders.inventory.bcast

               Name: health
            Subject: inv.health
        Queue Group: q
```

`{group}.{endpoint}` for the five grouped endpoints; `health` was added on the *service* with
`WithEndpointSubject("inv.health")` and gets no group prefix. For `bcast`, whose queue group is
disabled, `nats service info` **omits the Queue Group line entirely** and `stats` prints
`Requests: 0 in group ""`.

### C2 · the subscriptions: nine `$SRV` plus one per endpoint

```
  cid   5  sid  10  msgs    0  qgroup q              orders.inventory.check
  cid   5  sid  11  msgs    0  qgroup q              orders.inventory.slow
  cid   5  sid  12  msgs    0  qgroup q              orders.inventory.bad
  cid   5  sid  13  msgs    0  qgroup q-vip          orders.inventory.vip
  cid   5  sid  14  msgs    0  qgroup -              orders.inventory.bcast
  cid   5  sid  15  msgs    0  qgroup q              inv.health
```

Six endpoints → six subscriptions, one per endpoint, each with the queue group it resolved to.
`bcast` has none: `WithEndpointQueueGroupDisabled()` makes it a plain `SUB`
(`nats.go@v1.53.1/micro/service.go:448–464`).

### C3 · a service error is a normal reply with two headers

`nats request orders.inventory.bad '{"total":-1}'`:

```
05:11:11 Received with rtt 313.709µs
05:11:11 Nats-Service-Error: order total must be positive
05:11:11 Nats-Service-Error-Code: 400
05:11:11
{"field":"total"}
```

The same request from a raw client, byte for byte:

```
[     1.6 ms] >> PUB orders.inventory.bad _INBOX.RAW.1 12
[     1.6 ms] >> {"total":-1}
[     2.0 ms] << HMSG _INBOX.RAW.1 1 92 109 | payload: NATS/1.0\r\nNats-Service-Error: order total must be positive\r\nNats-Service-Error-Code: 400\r\n\r\n{"field":"total"}\r\n
```

A 109-byte message with a 92-byte header block and a 17-byte body. Compare a request to an endpoint
nobody serves, on the same connection:

```
[     2.4 ms] << HMSG _INBOX.RAW.2 1 55 55 | payload: NATS/1.0 503\r\nNats-Subject: orders.inventory.nosuch\r\n\r\n\r\n
```

**The 503 comes from the server and carries a status line and an empty body; a service error comes
from the service and carries `NATS/1.0` with two headers and whatever body the handler sent.** A
caller that only checks for a transport error sees both as success.

### C4 · `num_errors` and `last_error` after one service error

```
  check    q=q      reqs=0   errs=0   last_error=''
  slow     q=q      reqs=0   errs=0   last_error=''
  bad      q=q      reqs=1   errs=1   last_error='400:order total must be positive'
  vip      q=q-vip  reqs=0   errs=0   last_error=''
  bcast    q=       reqs=0   errs=0   last_error=''
  health   q=q      reqs=0   errs=0   last_error=''
```

`last_error` is formatted `"<code>:<description>"`. The counters are per endpoint, not per service.

### C5 · **a blocked endpoint does not block its siblings**

One instance. `slow` blocks 3 s; `check` fired 0.3 s into the block, `vip` 0.6 s in:

```
[05:12:03.901 A] slow    <- "blocking" (blocking 3s)
[05:12:04.206 A] check   <- "fast" on orders.inventory.check
[05:12:04.532 A] vip     <- "vip"
[05:12:06.902 A] slow    -> replying
```

Both siblings answered while `slow` was blocked, in 327 µs and 508 µs. Each endpoint is its own
`QueueSubscribe` with its own async callback (`nats.go@v1.53.1/micro/service.go:448–464`), and nats.go
runs one dispatch goroutine per subscription — so in Go the blocking is **per endpoint**, not per
service or per connection.

### C6 · broadcast vs queue group, two instances

```
--- one request to bcast, --replies=0 ---
05:12:07 Received with rtt 713µs      bcast from A
05:12:07 Received with rtt 728.25µs   bcast from B
--- one request to check (queue group q) ---
05:12:09 Received with rtt 541.667µs  ok from B
--- one request to vip (queue group q-vip) ---
05:12:10 Received with rtt 486.542µs  vip from A
```

The endpoint with no queue group answers **once per instance**; the caller's `Request` would take the
first and drop the rest.

### C7 · **a blocked instance keeps its share; the queue group does not route around it**

Two instances, both handlers blocking 3 s, eight requests fired at once, callers timing out at 8 s.
Every request was delivered immediately, at t = 11.086–11.087; each instance then processed its share
strictly one at a time:

```
=== A ===                                   === B ===
[05:12:11.087 A] slow <- "s5"               [05:12:11.086 B] slow <- "s3"
[05:12:14.088 A] slow -> replying           [05:12:14.087 B] slow -> replying
[05:12:14.088 A] slow <- "s6"               [05:12:14.087 B] slow <- "s1"
[05:12:17.089 A] slow -> replying           [05:12:17.088 B] slow -> replying
[05:12:17.089 A] slow <- "s7"               [05:12:17.088 B] slow <- "s4"
[05:12:20.091 A] slow -> replying           [05:12:20.089 B] slow -> replying
                                            [05:12:20.090 B] slow <- "s2"
                                            [05:12:23.091 B] slow -> replying
                                            [05:12:23.091 B] slow <- "s8"
                                            [05:12:26.092 B] slow -> replying
```

Split **3 / 5**, random. Of the eight callers, four got a reply (s5 and s3 at 3.00 s, s6 and s1 at
6.00 s) and **four timed out** — s7, s2, s4 and s8 were answered at 20.09 s, 23.09 s and 26.09 s, long
after their callers had gone, into inboxes nobody was listening on.

The server delivers to a member chosen at random per message and never looks at whether that member
is busy (`server/client.go:5514–5520`, quoted in `raw/nats-server-src/request-reply-v2.14.6.md`).
A blocked member's share queues in its own subscription buffer and waits behind the block.

---

## D · `Stop()` drains; an abrupt exit does not

### D1 · what `Stop()` removes, and when

`Stop()` called 2.0 s into a 5 s handler:

```
[05:17:34.297 A] slow    <- "mid-flight" (blocking 5s)
[05:17:36.266 A] calling Stop()
[05:17:36.267 A] Stop() returned after 1.3 ms err=<nil>
[05:17:39.297 A] slow    -> replying
```

Immediately after `Stop()` returned, with the process still running:

```
t≈3.6s (just after Stop) — a check request, and $SRV.PING
05:17:36 No responders are available
05:17:36 No responders are available
```

and `/subsz?subs=1&acc=$G` reported **no non-`$SYS` entries** — all fifteen subscriptions, the nine
`$SRV` ones included, were gone. The mid-flight request still got its reply, at 5.001 s:

```
05:17:34 Sending request on "orders.inventory.slow"
05:17:39 Received with rtt 5.001267583s
slow from A
```

So `Stop()` removes every subscription at once, returns in about a millisecond, and leaves in-flight
handlers running in the background — they finish and reply **only if the process stays alive**.
An instance disappears from `$SRV` discovery the moment it stops, not when its work finishes.

### D2 · SIGKILL mid-handler

The same shape with `kill -9` 1.0 s into the handler: the caller printed
`Sending request on "orders.inventory.slow"` and never received anything, waiting out its 10 s
timeout. In-flight work is lost, and the caller learns nothing but a timeout — there is no
no-responders answer for a request already accepted.

---

## E · Across a leafnode

Configs: a hub (`port 14222`, `leafnodes { port: 17422 }`) and a leaf (`port 14223`,
`leafnodes { remotes: [ { url: "nats-leaf://127.0.0.1:17422" } ] }`), both in account `$G`.

### E1 · discovery and invocation both cross

With the service running **only on the leaf**, from the hub:

```
--- from the hub, across the leafnode ---
│ Inventory │ 1.2.3   │ kXbKPouqnC76nyHwwQmxyV │ order inventory, observed │
--- $SRV.PING from the hub ---
{"name":"Inventory","id":"kXbKPouqnC76nyHwwQmxyV","version":"1.2.3","metadata":{"label":"LEAF","zone":"eu-1"},"type":"io.nats.micro.v1.ping_response"}
--- calling the endpoint from the hub ---
05:18:04 Received with rtt 811.25µs
ok from LEAF
```

`$SRV.PING`, `$SRV.INFO`, `$SRV.STATS` and the endpoint subjects are ordinary subjects, so they follow
ordinary leafnode interest propagation. Nothing special is needed and nothing is filtered.

### E2 · but the queue group prefers the local member

One instance on the hub, one on the leaf, one queue group `q`, eight requests from each side:

```
--- 8 requests to check, from the hub ---
   8 ok from HUB
--- 8 requests to check, from the leaf ---
   8 ok from LEAF
--- service list from the hub: how many instances? ---
│ Inventory │ 1.2.3   │ gYDkEVFKFTDYeSmU3giF4j │ order inventory, observed │
│           │         │ kXbKPouqnC76nyHwwQmxyV │                           │
```

**16 of 16 requests stayed on the server the caller was connected to**, while discovery saw both
instances from either side. Placing an instance next to the callers keeps their traffic local; it
does not add capacity to the other side.

### E3 · what the hub's `/subsz` shows

With a service only on the leaf, the hub's `/subsz?subs=1&acc=$G` reported `num_subscriptions 24`
but returned **no `subscriptions_list` entries** for them; the leaf's own endpoint reported the same
count with the service's 15 entries listed. Leaf-origin interest is counted on the hub but not
itemised by that endpoint, so `/subsz` will not show you a remote service's subjects.

---

## What was not tested

- Any client other than nats.go and natscli. Every per-language default in
  `learn/resilient-clients/` and every module name in `learn/services.md` stays the docs' word.
- `$SRV` across a **gateway** or a **supercluster** (E covers a leafnode only), and across an
  **account import** — the prefix override ADR-32 asks for is not implemented in nats.go
  (`APIPrefix` is a `const`, `micro/service.go:264–265`), so a cross-account tool has no way to
  address a differently-prefixed tree.
- `Reset()`, the `DoneHandler`, and endpoints added after the service started (ADR-32 revision 6).
- Service **latency** advisories — a server feature of a cross-account service export with
  `latency {}` configured, unrelated to the framework's counters; see
  `raw/nats-server-src/system-subjects-observed-v2.14.6.md`.
- Whether a slow-consumer condition is ever reached on an endpoint subscription: C7's blocked
  instance queued 5 messages, far below any pending limit.
