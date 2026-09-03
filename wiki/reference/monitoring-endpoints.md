---
title: Monitoring endpoints
type: reference
area: [monitoring, deploy]
verified-against: nats-server 2.14.6
verified-on: 2026-09-01
tags: [monitoring, varz, jsz, healthz, connz, routez, raftz, http_port]
aliases: [/varz, /jsz, /healthz, /connz, /routez, /raftz, monitoring port, http_port]
sources: [s-nats-server-jetstream-resources, s-issue-4281-insufficient-storage, s-docs-monitoring-endpoints, s-docs-hardening, s-nats-server-constants-2.14.6, s-relnotes-2.14.0, s-nats-server-auth-and-tls, s-gh-7684-certificate-expiry, s-natscli-account-tls, s-nats-server-topology, s-gh-7494-supercluster-degradation, s-docs-putting-it-together, s-adr-59-sourcing-and-mirroring, s-nats-server-filestore-layout, s-docs-accounts-and-multitenancy, s-docs-encryption-and-tls, s-docs-kubernetes, s-docs-mirrors-as-dr, s-docs-prometheus-and-dashboards, s-docs-single-server, s-gh-5243-kv-watchers-at-scale, s-gh-6605-which-consumer-is-slow, s-gh-7190-asymmetric-cluster, s-nats-server-tls-reload, s-docs-mqtt-auth-and-clustering, s-nats-server-mqtt-websocket-observed, s-nats-server-monitoring-observed, s-gh-7362-routez-connz-rtt, s-gh-7483-varz-cpu-in-containers, s-docs-monitoring-profiling, s-docs-monitoring-advisories-and-events, s-docs-monitoring-jetstream-health, s-nats-server-jetstream-cluster, s-nats-server-raftz, s-docs-monitor-raftz, s-nats-server-meta-layer-rerun-observed, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12]
created: 2026-08-31
updated: 2026-09-03
---

# Monitoring endpoints

The read-only HTTP endpoints a `nats-server` serves on its monitoring port. This page lists the
**15 documented endpoints and their query parameters**; it does not list response fields — those are
per-endpoint schema dumps in the docs, and the ones worth explaining live on the concept pages.

## The port

The monitoring port is **separate from the client port and off until you enable it**: set
`http_port: 8222` in the config, or pass `-m 8222`. `8222` is the conventional choice and the
server's compiled-in `DEFAULT_HTTP_PORT` (`const.go:135`, source:
[[s-nats-server-constants-2.14.6]]), but the port is whatever you set.

**Bind it to localhost on a host, but never on Kubernetes.** `http: "127.0.0.1:8222"` keeps `/varz`
off the network on a VM; under the Helm chart it fails every probe, because the kubelet's startup,
readiness and liveness probes connect to the **pod IP**, not to loopback — so no pod ever goes ready.
There, keep the chart's bind and restrict the port with a NetworkPolicy (source: [[s-docs-hardening]];
see [[install-nats-server]] and [[nats-helm-charts]]).

It is **plain HTTP, request-response, nothing pushed**: a `GET` returns a JSON snapshot of state at
that instant and the connection closes.

> **The monitoring port is unauthenticated by default.** Anyone who can reach it can read `/connz`
> and see your users, subjects and traffic. Do not expose it to the internet
> (source: [[s-docs-monitoring-endpoints]]).

## The 15 endpoints

Query parameters are the request-schema fields from the 2.14 reference tree.

| endpoint | what it reports | query parameters |
|---|---|---|
| **`/varz`** | the server process: version, uptime, memory, connection counters, `slow_consumers` | — |
| **`/connz`** | client connections | `acc`, `auth`, `cid`, `filter_subject`, `limit`, `mqtt_client`, `offset`, `sort`, `state`, `subscriptions`, `subscriptions_detail`, `user` |
| **`/routez`** | cluster routes to peer servers | `subscriptions`, `subscriptions_detail` |
| **`/jsz`** | JetStream state: streams, consumers, meta leader | `acc`, `accounts`, `config`, `consumers`, `direct-consumers`, `leader-only`, `limit`, `offset`, `raft`, `stream-leader-only`, `streams` — **the docs print `account`, `consumer`, `direct_consumer`, `leader_only`, `stream_leader_only`, which the endpoint ignores** (docs issue #48) |
| **`/healthz`** | a yes/no health check — `200` healthy, `503` not | `account`, `consumer`, `details`, `js-enabled` *(deprecated — use `js-enabled-only`)*, `js-enabled-only`, `js-meta-only`, `js-server-only`, `stream` |
| **`/raftz`** | live RAFT group state: term, leader, overrun, per-peer status | `acc`, `group` — **the docs print `account`, which the endpoint ignores**; with no `acc` only the system account's groups are listed |
| `/accountz` | account configuration | `acc` — the docs print `account`, which the endpoint ignores |
| `/accstatz` | per-account statistics | `accounts`, `include_unused` |
| `/gatewayz` | gateway connections | `account_name`, `accounts`, `name`, `subscriptions`, `subscriptions_detail` |
| `/leafz` | leafnode connections | `account`, `subscriptions` |
| `/subsz` | the subscription list | `account`, `limit`, `offset`, `subscriptions`, `test` |
| `/statsz` | server statistics | `cluster`, `domain`, `exact_match`, `host`, `server_name`, `tags` |
| `/ipqueuesz` | internal queue depths | `all`, `filter` |
| `/profilez` | Go profiles (`pprof`) | `debug`, `duration`, `name` |
| `/idz` | the server's identity | — |

The four used most are **`/varz`, `/connz`, `/routez` and `/jsz`**
(source: [[s-docs-monitoring-endpoints]]).

## The fields worth naming

### `/varz` — three connection counters that get confused

| field | meaning |
|---|---|
| `connections` | clients connected **right now** |
| `total_connections` | every connection **since the server started** — only ever climbs |
| **`slow_consumers`** | clients the server has **disconnected for not keeping up**; `0` on a healthy node |

**Alert on `connections`, not `total_connections`.** A client reconnecting in a loop barely moves
the live count but inflates the lifetime count fast; alerting on the lifetime counter pages someone
for a number that was always going to grow. A large gap between the two, **with `slow_consumers`
above zero, is connection flapping rather than load**:

```
curl -s http://localhost:8222/varz \
  | jq '{live: .connections, lifetime: .total_connections, dropped: .slow_consumers}'
```

`slow_consumers` is the counter behind [[slow-consumer-detected]] — it says *how many*, never
*which*.

### `/connz` — finding the connection that is behind

Each entry carries `cid`, `account`, `authorized_user`, `rtt`, `pending_bytes` and, with
`?subs=true`, `subscriptions_list`. **`?auth=true` is what fills in the account and user.**

```
curl -s 'http://localhost:8222/connz?sort=pending&limit=10' | jq
```

returns "the ten connections with the most data queued: the clients most likely to fall behind".

The two counts at the top describe the *response*: `num_connections` is how many this response
returned, `total` how many matched in all. With `?limit` and `?offset`, `total` stays put while
`num_connections` shrinks to the page size.

### `/routez` — routes are pooled since 2.10

Each entry is one route: `rid`, `remote_name`, `remote_id`, `rtt`, `pending_size`. **Since 2.10
each peer contributes several route entries** — a connection pool of three plus a dedicated
system-account route — so a default three-node cluster shows **eight entries on one node, four per
peer**. Health is therefore **presence, not count**: group by `remote_name` and confirm every peer
is still there. A vanished peer, or a climbing `rtt`, is the first sign a node has dropped off the
mesh.

**The check only means anything cluster-wide, and only after every node is up.** A lone healthy node
legitimately has no routes, so `/routez` on one server proves nothing; what a partial split-brain
looks like is the *same non-zero number on every row* failing to hold — every node still agreeing on
the cluster name and appearing in the list, with only the connection counts differing. Confirmed on a
2.11.7 cluster (source: [[s-gh-7190-asymmetric-cluster]]); see
[[build-a-3-node-cluster]].

### `/jsz` — scope it or it will time out

`/jsz` reports streams, consumers, `meta_cluster.leader`, and the per-stream and per-consumer
numbers beneath.

`meta_cluster` is **always present** — `name`, `leader`, `peer` (the leader's id), `cluster_size`,
`pending`, `pending_requests`, `pending_infos`, `snapshot{pending_entries, pending_size, last_time,
last_duration}` — and **only the leader's copy** carries `replicas[]`, one entry per other peer with
`current` and `active` (nanoseconds since last contact). There is no `meta` query parameter: `/jsz?meta=1`
returns the same body as `/jsz`. `?raft=1&streams=1` adds each stream's `raft_group`, `leader_since` and
replicas. Confirmed on 2.14.6 ([[meta-layer]]; source: [[s-nats-server-jetstream-cluster]]).

> **An unscoped `/jsz` is slow at scale.** `?accounts=true&streams=true&consumers=true` walks every
> account, stream and consumer on the node and serialises the lot — "on a node with thousands of
> consumers it can take long enough that a scrape times out and you get *no* data."

Scope with `?acc=`, page with `?offset` and `?limit`:

```
curl -s 'http://localhost:8222/jsz?acc=ORDERS&streams=true' | jq
```

Since **2.14** the JetStream *API* equivalents of these calls — account info, stream info, stream
list, consumer info, consumer list — are **queued below create-update-delete operations**
(source: [[s-relnotes-2.14.0]]), which protects stream operations from an info-heavy poller without
making the poll cheap.

### `/healthz` — ask the right question

`/healthz` answers `200` or `503` and is built for an orchestrator that wants a yes/no rather than
JSON to parse:

```
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8222/healthz
```

Its parameters narrow what "healthy" means — JetStream only, this server only, the meta layer only,
or one named stream or consumer. **`js-enabled` is deprecated in favour of `js-enabled-only`.**

`?js-meta-only=true` stops after the meta-layer checks, and a `503` names one of five states:
`JetStream has not established contact with a meta leader` (no leader known), `JetStream is not current
with the meta leader` (a leader is known but not heard from within 2 s — **what a dead leader looks
like** until its term ends), `JetStream is still recovering meta layer`, `JetStream meta layer is not
running`, `JetStream meta layer write error: …`. Whatever the state, the server logs each failing request as
`Healthcheck failed: "…"` — the line is written by the HTTP handler (`monitor.go:3584–3589`), **once
per request**, so a probe polling every second produces one line a second and an unpolled server
produces none ([[meta-layer]]; sources: [[s-nats-server-jetstream-cluster]], [[s-nats-server-meta-layer-rerun-observed]]).

Since **2.14** a filestore I/O error **freezes the affected stream and reports unhealthy here**,
with the error text containing `write error`; the server keeps serving core traffic and needs a
restart to recover (source: [[nats-server-2.14]]).

**Which variant belongs on which Kubernetes probe** — the mapping the Helm chart renders, all three
on the monitor port `8222` (source: [[s-docs-kubernetes]]; see [[nats-helm-charts]]):

| probe | path | note |
|---|---|---|
| `startupProbe` | `/healthz` | the unqualified form, `failureThreshold: 90` — a JetStream server may take a long time to come up |
| `readinessProbe` | `/healthz?js-server-only=true` | ready when *this* server is up, without waiting on the meta layer |
| `livenessProbe` | `/healthz?js-enabled-only=true` | the loosest question, so a lagging stream never triggers a restart loop |

The gradient is deliberate: the liveness probe must ask the *least*, or a slow-recovering stream
restarts the pod that is recovering it.

**An unhealthy answer is not always about the server.** A consumer that has fallen behind fails the
check by name, which is how a KV watcher's ephemeral consumer can turn a node unhealthy — observed on
2.10.12 (source: [[s-gh-5243-kv-watchers-at-scale]]):

```
[WRN] Healthcheck failed: "JetStream consumer '$G > KV_wincloud-sdc-delta > h0mGFs2q' is not current"
```

### `/varz` — certificate expiry, per listener

`tls_cert_not_after` carries the certificate's expiry date, at the top level and on the `cluster`,
`gateway`, `leafnode`, `mqtt` and `websocket` objects (`monitor.go:1838–1845` at **v2.14.6**,
source: [[s-nats-server-auth-and-tls]]):

```
curl -s http://127.0.0.1:8222/varz | jq '{client: .tls_cert_not_after, cluster: .cluster.tls_cert_not_after, leaf: .leafnode.tls_cert_not_after}'
```

Three things to know before alerting on it:

- **The field is omitted when that listener has no TLS** (`omitzero`). An absent key means "no
  certificate configured here", not "no expiry".
- **It is the leaf certificate only** — specifically the `NotAfter` of the leaf of the *first*
  configured certificate (`tlsCertNotAfter`, `monitor.go:1485–1498`). An expiring intermediate or CA
  breaks the handshake identically and does not appear. `nats account tls` walks the whole verified
  chain and is the companion check (source: [[s-natscli-account-tls]]).
- **No docs page names this field**, which is why the public answer to "how do I see the expiry?"
  is still an `openssl` pipeline (source: [[s-gh-7684-certificate-expiry]]; `inbox/docs-issues.md`
  #20). It shipped in [PR #7709](https://github.com/nats-io/nats-server/pull/7709).
- **It is also the only way to confirm a certificate rotation landed.** A reload prints
  `Reloaded: tls = enabled` whether or not the certificate changed, `config_digest` digests the
  configuration *text* and so does not move when only the file behind `cert_file` is new, and
  `nats-server --signal reload` exits 0 even for a reload the server refused. Observed on the
  v2.14.6 binary (source: [[s-nats-server-tls-reload]]); the procedure is in
  [[rotate-tls-certificates]].

Do not reach for `openssl s_client` against the client port: the first bytes there are the plaintext
`INFO` line, so it fails with `wrong version number` unless `handshake_first` is on. See
[[rotate-tls-certificates]].

### `/varz` — `reserved_storage` is the number that decides `10047`

`jetstream.stats` carries **four** storage numbers, and the pair people read is the wrong pair:

```
curl -s http://127.0.0.1:8222/varz | jq '.jetstream.stats | {storage, reserved_storage, memory, reserved_memory}'
```

`storage` and `memory` are what is actually held. `reserved_storage` and `reserved_memory` are the sum
of every stream's `max_bytes`, counted as used from the moment the stream exists — and it is the
*reserved* pair that `insufficient storage resources available (10047)` compares against the limit
(`jetstream.go:2523–2553`, source: [[s-nats-server-jetstream-resources]]). A real dump in
[[s-issue-4281-insufficient-storage]] reads `"storage": 4022205` beside
`"reserved_storage": 37580963840` — 4 MB held, 35 GiB reserved. Alert on the **gap**, not on
`storage`. See [[jetstream-out-of-disk]].

`gomaxprocs` and `cores` are worth reading at the same time: a container with a fractional CPU limit
can leave the server at `GOMAXPROCS=1` on an 8-core host, which is one of the hypotheses on
[[nats-timeout]].

### `cpu` is a percentage of **one** core

The single most misread number on the endpoint, and no public source says what it is relative to. Read
from the source at v2.14.6 (source: [[s-nats-server-monitoring-observed]]):

> **`cpu: 100.0` means one core fully consumed. `cpu: 250.0` means two and a half cores.** It is
> relative to **neither** the host's core count nor any container CPU allocation — it is an absolute
> "cores consumed × 100".

On Linux the value is not computed when you call `/varz`: a background timer samples
`utime + stime` from `/proc/<pid>/stat` **once a second**, takes the delta, and divides by elapsed
seconds (`server/pse/pse_linux.go:49–86`); `ProcUsage` returns that figure `/10.0` (`:104`).

**So a CPU alert threshold must be scaled by the container's CPU *allocation*, not by `cores`.** On a
0.25 vCPU task, `cpu: 25` is the container saturated, and `cpu: 10` — the figure in
[[s-gh-7483-varz-cpu-in-containers]] — is **40 % of allocation**, not 10 % of anything. `cores` is
`runtime.NumCPU()` (`monitor.go:1727`) and nothing in the monitoring or process-stats code reads a
cgroup CPU quota, so on a container `cores` reports the **host's** logical CPUs. That question was
asked in public and **closed with no reply at all**.

Two caveats from the same function, both Linux-only: `ticks` is **hardcoded to 100** rather than read
from `sysconf(_SC_CLK_TCK)` — commented "Avoiding to generate docker image without CGO" — so a kernel
with a different `CLK_TCK` is scaled wrong; and the elapsed-seconds term comes from
`syscall.Sysinfo().Uptime`, the **host's** uptime.

### `rtt` is a PING/PONG — and on a client it can be an hour old

`rtt` appears in `/connz` and `/routez` and looks like a live latency measurement. It is not. `c.rtt`
is written in exactly two places (`client.go`, v2.14.6; source:
[[s-nats-server-monitoring-observed]]):

| when | value |
|---|---|
| **at connect**, for a client | `computeRTT(c.start)` — the **connection setup time**, not a ping (`:2289`) |
| **on every PONG** | `computeRTT(c.rttStart)`, stamped when the server sent the PING (`:2690`, `:2801`) |

and it is floored at **1 nanosecond**, so it is never reported as zero once set (`:2262–2267`).

**How often it refreshes is the part that decides whether the number is usable:**

| connection kind | refresh |
|---|---|
| route, gateway, spoke leafnode | pinged on **every ping-timer tick** — default `2m` |
| **client** | only when `rtt == 0` or **more than an hour** has passed (`DEFAULT_RTT_MEASUREMENT_INTERVAL = time.Hour`, `const.go:224`, used at `client.go:5844`) |
| **MQTT** | **never** — `sendRTTPingLocked` returns false for MQTT connections (`client.go:2671–2673`), see [[mqtt]] |

So a busy client's `/connz` `rtt` is the **connect-time estimate, then refreshed roughly hourly**. A
maintainer's public answer — "periodic PING/PONG response times", "on initial setup of a connection and
periodically as the connection ages" — is correct and omits the period; the reporter who then said "I
don't see these values getting updated, even if we wait minutes" was right, and never got a reply
([[s-gh-7362-routez-connz-rtt]]).

**Practical consequences.** Do not read a client's `rtt` as current network latency, and do not chase a
high one on a long-lived connection — force a fresh measurement with a new connection instead.
`/routez` `rtt` *is* fresh to within the ping interval, which is why a climbing route `rtt` is a
meaningful signal and a client one may not be.

### The events the endpoints cannot give you

Everything above is a **level you poll**. Two kinds of thing never appear in a scrape, because they are
moments rather than levels (source: [[s-docs-monitoring-advisories-and-events]]):

| pushed on | carries |
|---|---|
| `$JS.EVENT.ADVISORY.>` | JetStream advisories — max-deliveries, nak, leader-elected, quorum-lost ([[advisories]]) |
| `$SYS.ACCOUNT.<account>.CONNECT` / `.DISCONNECT` | one message per client connect and disconnect, the account baked into the subject |
| `$SYS.SERVER.<id>.STATSZ` | a periodic heartbeat carrying "the same kind of summary numbers as `/varz`, pushed instead of pulled" |

`$SYS.ACCOUNT.*.CONNECT` is the push equivalent of polling `/connz` on a timer, and `STATSZ` of polling
`/varz`. Both are published into the **system account**, so subscribing needs a system user, not the
application account. Advisories are published **once** and stored nowhere — capture them in a stream if
you need them after the fact.

### The `/jsz` numbers that actually say "behind"

`/jsz` counts streams and consumers; whether a consumer is *keeping up* comes from its state, and lag
is arithmetic over two fields (source: [[s-docs-monitoring-jetstream-health]]):

```
lag = stream.last_seq − consumer.delivered.stream_seq
```

reported directly as **`num_pending`**. Read it beside `num_ack_pending` (in-flight) and `num_waiting`
(outstanding pulls) — the three move for different reasons, and the combination
`num_pending` climbing · `num_waiting` at 0 · `delivered.stream_seq` flat is the signature of a
**crashed consumer pool** rather than a busy one. [[stream-has-high-message-lag]] has the full
diagnostic; [[consumer]] has the field table.

### `$SYS.REQ.SERVER.PING.PROFILEZ` — profiling without a restart

The `$SYS` request behind `nats server request profile <heap|allocs|goroutine|cpu>`, which needs a
system-account connection and no configuration change. Each answering server writes
`<profile>-<timestamp>-<server>`; `--name`, `--host`, `--cluster` and `--tags` narrow who answers.
**CPU sampling is capped at 15 seconds** on this route — the CLI reuses `--timeout` as the window,
default `5s` — and a longer capture needs `prof_port`, which is **not reloadable** and has **no
authentication** (source: [[s-docs-monitoring-profiling]]). Prefer the `$SYS` route; it is
authenticated like any other `$SYS` request. See [[jetstream-sizing]].


## The two stall counters

Neither `stalled_clients` nor the per-connection `stalls` appears anywhere in the 861-page docs tree
(`inbox/docs-issues.md` #25). They are the counters that explain a publisher slowing down because one
of its *destinations* is slow — a cross-region gateway, most often.

| endpoint | field | what it counts |
|---|---|---|
| `/varz` | **`stalled_clients`** | server-wide: "the total number of times that clients have been stalled" (`monitor.go:1279`) |
| `/connz` | **`stalls`** | the same count, per connection (`monitor.go:133`, `:597`) |

```
curl -s localhost:8222/varz | jq .stalled_clients
curl -s 'localhost:8222/connz?sort=pending' \
  | jq '.connections[] | {cid, name, stalls, pending_bytes}'
```

The matching log line is `Producer was stalled for a total of %v` (`client.go:1451`), rate-limited
and printed only once the total for a read loop reaches `stallClientMaxDuration` (5ms). The stall
itself is bounded at `stallTotalAllowed` (10ms) per read-loop invocation
(source: [[s-nats-server-topology]]).

**Read them next to `slow_consumers`, not instead of it.** `slow_consumers` counts clients the server
gave up on; `stalled_clients` counts the times it slowed a *producer* down to avoid that. A rising
`stalled_clients` with a flat `slow_consumers` is back-pressure working —
[[supercluster-slows-when-a-remote-subscriber-joins]] is what it looks like across a gateway, and
`no_fast_producer_stall: true` is the switch that converts one counter into the other.

## Surveying a topology

Three CLI reports read `/routez`, `/gatewayz` and `/leafz` through the system account, one per layer
(source: [[s-docs-putting-it-together]]):

```
nats server list                 # every server, its cluster, and its Routes and GWs counts
nats server report routes        # the mesh inside each cluster
nats server report gateways      # the gateways between clusters
nats server report leafnodes     # the leaves dialed into the hub
```

The Leafnode Report's two columns worth reading carefully:

- **`Account`** — `$G` means the leaf landed in the global account and there is **no boundary**. This
  is the isolation audit, not a label — [[leafnode]].
- **`Spoke`** — a property of *where you ran the command*, not of the link: `false` on the hub that
  accepted the connection, `true` on the leaf that dialed it.


## How this was derived

- The endpoint list and every query parameter come from `raw/nats-docs/reference/system/monitor/`
  in the 2.14 docs tree — 15 pages, each a generated schema with a `## Request Schema` section. To
  regenerate: parse the request-schema field names out of each file (note the docs escape
  underscores as `\_`).
- The prose — the port, the counter meanings, the pooled-routes count, the `/jsz` scaling warning
  and the unauthenticated-by-default caveat — comes from
  `raw/nats-docs/learn/monitoring/monitoring-endpoints.md`. The reference pages carry **no prose at
  all**, only field lists.
- `DEFAULT_HTTP_PORT` is read from the server source at v2.14.6.

## From an endpoint to a time series

`prometheus-nats-exporter` runs **outside** NATS, scrapes this port and serves its own `/metrics`;
it "holds no history of its own; it answers each scrape from a fresh read of the monitoring port".
The rule worth knowing here is that **the metric names follow the wire fields** — `num_pending`
becomes `nats_consumer_num_pending` — with `-jsz` turning on the JetStream collector and the default
`jetstream_` prefix renamed to `nats_` by `-prefix nats`, "the same rename the NATS Helm chart
applies". So any field named on this page can be found as a series, and the exporter's invocation,
its labels and the metric list are on [[prometheus-nats-exporter]]
(source: [[s-docs-prometheus-and-dashboards]]).

### `/raftz` — scope it to an account, or you only see the meta group

`/raftz` returns one object per Raft group this server holds, keyed `account → group name`. Two
things the docs do not say: the account filter is **`acc`**, not `account` (which is silently
ignored), and **it defaults to the system account**, so a bare `/raftz` shows only `$SYS` → `_meta_`.
A stream's or consumer's group needs both filters, because `group=` alone is looked up inside `$SYS`
and returns `{}`. Confirmed on 2.14.6 (source: [[s-nats-server-raftz]]):

```
curl -s http://localhost:8222/raftz | jq '."$SYS"._meta_'                       # the meta group
curl -s 'http://localhost:8222/raftz?acc=ORDERS_ACCOUNT&group=S-R3F-RCvvHwre' | jq   # one stream's group
nats server request raft --account ORDERS_ACCOUNT --group S-R3F-RCvvHwre          # the same over $SYS
```

Per group: `id` (this server's peer id), `state` (`LEADER` / `FOLLOWER` / `CANDIDATE` / `OBSERVER` /
`CLOSED`), `size` and `quorum_needed` (`size/2 + 1`), `committed` / `applied`, `term`, `voted_for`,
`pterm` / `pindex`, `leader` and — on the leader only — `leader_since`, `ever_had_leader` (the
cold-boot signal), `system_account` / `traffic_account`, the four queue lengths `ipq_proposal_len`,
`ipq_entry_len`, `ipq_resp_len`, `ipq_apply_len`, a `wal` object (`messages`, `bytes`, `first_seq`,
`last_seq`, timestamps — `messages: 0` with `first_seq = last_seq + 1` is a freshly compacted log) and
`wal_error`. The flags that matter on a bad day are omitted when false: **`overrun`** and
`overrun_count` (the 2.14 overrun protection, [[raft-in-nats]]), `catching_up`, `observer`, `paused`.
`peers` maps peer id to `name`, `known`, `last_seen` and `last_replicated_index`; a follower reports
`last_seen` for the leader only, the leader reports both for every peer. The docs' page for this
endpoint prints none of it (docs issue #47; source: [[s-docs-monitor-raftz]]).

**A docs error worth knowing.** Six of the generated reference pages — `accountz`, `jsz`, `leafz`,
`subsz`, `gatewayz`, `raftz` — print the field names of the `$SYS.REQ.SERVER.PING.<Z>` request
payload (`account`, `consumer`, `subscriptions`, …) as the endpoint's request options. The HTTP
handlers read different names (`acc`, `consumers`, `subs`, …) and ignore the documented ones: on
2.14.6 `/accountz?account=NOPE` returns the normal page while `/accountz?acc=NOPE` answers
`400 Account NOPE does not exist`. `connz` and `healthz` print the right names. Use the underscore
names in `nats server request …` and its flags, never in a URL (source: [[s-nats-server-raftz]]).

## What is deliberately not here

**Response fields.** Each endpoint's response schema runs to dozens of fields and is generated; the
docs' own pages are the place for them. The fields above are the ones this wiki has a reason to
explain. `/raftz` is the exception, below: the docs' page for it has **no** response fields, so its
field set is on this page instead.

**Account visibility over `$SYS`.** What an account can see of itself does not travel over this port:
`nats account info` asks `$SYS.REQ.USER.INFO`, and a narrow publish allow-list silently blanks the
answer while `/accountz` keeps working. That surface is on [[account]] and [[js-api-subjects]]
(source: [[s-docs-accounts-and-multitenancy]]).

## Seeing the internal replication consumers

The consumers a mirror or source runs on its upstream are hidden from the consumer API by a `Direct`
flag, so `nats consumer ls` will not show them (for a Limits upstream; 2.14 makes them visible for
WorkQueue and Interest — [[mirrors-and-sources]]). `/jsz` will, on request:

```
curl -s 'http://127.0.0.1:8222/jsz?streams=true&consumers=true&direct-consumers=true&config=true&acc=APP'
```

`direct-consumers` requires `consumers=true`; the result adds `direct_consumer_detail` to each
`StreamDetail`, a full `ConsumerInfo` per replication consumer whose delivered and ack-floor
sequences can be compared against the upstream's state. The same `StreamDetail` carries `mirror` and
`sources` (each a `StreamSourceInfo` with `lag`, `active` and `error`) whenever `streams=true`, and
the identical data is available over NATS at `$SYS.REQ.SERVER.PING.JSZ`
(source: [[s-adr-59-sourcing-and-mirroring]]). **`active` is the JSON name for what the `nats` CLI
prints as `Last Seen`** — a growing value means the `lag` you just read is already stale
(source: [[s-docs-mirrors-as-dr]]; the RPO reading is on [[mirrors-and-sources]]).

Other `/jsz` selectors from the same spec: `acc`, `leader-only`, `stream-leader-only`, `raft`,
`offset` and `limit`.


## `storage` is a logical figure, not disk

`/jsz` `storage`, `/varz` `jetstream.stats.storage` and every per-stream `state.bytes` under
`/jsz?streams=1` report the same thing: the sum of the **live message record lengths**
(`30 + len(subject) + len(payload)`, plus `4 + len(headers)`). None of them is the size of the files
under `store_dir` (source: [[s-nats-server-filestore-layout]], `nats-server 2.14.6`).

Measured on one node holding ten streams: `storage` **37,891,637**, exactly the sum of the ten
`state.bytes`; the store tree on disk **39,881,215** — 5.25% more. On a single idle stream the gap
reached **8.5×**. See [[filestore-layout]] for why, and [[jetstream-out-of-disk]] for what it costs.

`reserved_storage` is a third figure again: the sum of every stream's `max_bytes`, counted whether
or not anything is stored.

**Monitor all three, and `df` as well.** No endpoint reports physical size, so a disk alert has to
come from the node, not from NATS:

```
curl -s localhost:8222/jsz | jq '{storage, reserved_storage, max: .config.max_storage}'
```

`/jsz` also prints the effective **`config.sync_interval`** (nanoseconds; `120000000000` = the `2m`
default), which is the cadence on which block compaction and the `index.db` snapshot run.


## MQTT-aware fields

The monitoring port knows about MQTT connections, which is the tool for a client-ID collision
(source: [[s-docs-mqtt-auth-and-clustering]]).

| where | field |
|---|---|
| `/connz?mqtt_client=truck-17` | filter connections by MQTT client id |
| `/connz` connection record | `mqtt_client`, the client id holding that session |
| `/varz` | an `mqtt` section with the listener's resolved settings, including the JetStream domain in use |

Two log lines are worth grepping for alongside them, both confirmed on 2.14.6 (source:
[[s-nats-server-mqtt-websocket-observed]]): `Listening for MQTT clients on mqtt://…`, whose **absence**
means the `mqtt {}` block set no port; and
`Creating MQTT streams/consumers with replicas N for account "…"`, which is the only place the server
states the replica count it derived for MQTT state — see [[mqtt]].

## What arrived in 2.10

Each with its release and PR (source: [[s-relnotes-2.10]]):

| what | since |
|---|---|
| `unique_tag` in `/jsz` and `/varz`; `slow_consumer_stats` in `/varz`; subscription count in `/statz`; `/jsz?raft=1` | 2.10.0 (#3617, #4330, #3875, #3914) |
| `$SYS.REQ.SERVER.PING.IDZ`, `$SYS.REQ.SERVER.<id>.PROFILEZ`, `.KICK`, `.LDM`, `.RELOAD` | 2.10.0 (#3663, #3774, #4298, #4307) — `IDZ`, `KICK`, `LDM` and `RELOAD` are undocumented, `inbox/docs-issues.md` #54 |
| `ocsp_peer_cache` dropped from `/varz` when not in use | 2.10.6 (#4829) |
| `/jsz` account filtering with stream details fixed | 2.10.14 (#5229) |
| **`/expvarz`** | 2.10.16 (#5374) |
| **`/raftz`**, "experimental … for diagnostic purposes" | 2.10.17 (#5530) |
| `StreamLeaderOnly` filter on `/jsz`; CPU profiles from `PROFILEZ`; an HTTP read timeout on the monitoring, profiling and OCSP servers | 2.10.19 (#5704, #5743, #5790) |
| **`statsz` every 10 s instead of 30 s**; pending JetStream API request count in `statsz` and `/jsz` | 2.10.21 (#5925, #5923, #5926) |
| `/gatewayz` subscription info; `raftz` and `ipqueuesz` over the system account; `/routez` `pending_bytes` | 2.10.26 (#6525, #6439, #6476) |
| `GOMAXPROCS` and `GOMEMLIMIT` in `statsz` and `/varz`; `/jsz` `offset` pagination fixed | 2.10.28 (#6791, #6794, #6816) |
| `/connz?state=all` returns open connections | 2.10.29 (#6849) |

`/healthz` changed underneath too: 2.10.17 stops false positives after a failed snapshot restore
(#5549), 2.10.24 carries "minor fixes to `healthz` and healthchecks" (#6247, #6248, #6232), and
**2.10.25 stops the health check from re-evaluating assignments**, which had recreated streams and
consumers "shortly after a deletion" (#6362); 2.10.26 made its error messages say why (#6416).


## What arrived in 2.11

Each with its release and PR (source: [[s-relnotes-2.11]]):

| what | since |
|---|---|
| `config_digest` in `/varz` (the hash `nats-server -t` prints); `/healthz?js-meta-only=true` | 2.11.0 (#4325, #6649) — `config_digest` undocumented, `inbox/docs-issues.md` #57 |
| `/connz` includes leafnode connections; `accstatsz` carries leafnode, route and gateway stats | 2.11.5 (#6949, #6967) |
| `/subsz` returns the correct `total` for pagination | 2.11.6 (#7009) |
| `/leafz` reports the connection ID; the index page names endpoints on hover | 2.11.7 (#7063, #7066, #7087) |
| `leader_since`, `system_account`, `traffic_account` on stream and consumer info and in `/jsz`; `/raftz` reports the cluster-traffic account | 2.11.9 (#7189, #7193, #7186) — undocumented, #56 and #57 |
| `accstatsz` omits empty gateway, route and leaf stats | 2.11.10 (#7300) |
| meta snapshot statistics and leader counts in `/jsz`; `/jsz?direct-consumers=true` | 2.11.11 (#7524, #7429, #7543) |
| **`tls_cert_not_after`** in `/varz` and its per-listener blocks | 2.11.12 (#7709) — undocumented, #57 |
| `/expvarz` redacts command-line secrets; MQTT passwords no longer in the JWT field | 2.11.15 |
| **`/connz` no longer discloses bearer JWTs**; route and cluster URL secrets redacted | 2.11.17 |

`/healthz` in 2.11: it stops "fixing up cluster node skews, as this could interfere with processing
assignments" (2.11.5, #7001); no unexpected monitor-goroutine warnings after a snapshot restore
(2.11.6, #7019); no transient errors for newly created or recently deleted consumers (2.11.8, #7154);
a stream that is catching up is reported as catching up, not unhealthy (2.11.11, #7535); consumers
deleted on recovery do not fail it (2.11.11, #7523).


## What arrived in 2.12

| what | since |
|---|---|
| `exact_match` on the server-name, host and cluster filters of "various monitoring endpoints" | 2.12.0 (#7260) |
| `server_metadata` reported with the server | 2.12.0 (#6935) |
| expvar `/debug/vars` on the monitoring port | 2.12.2 (#7469) |
| meta snapshot statistics, leader counts, `direct-consumers` in `/jsz` | 2.12.1–2.12.2 (#7429, #7524, #7543) |
| `tls_cert_not_after` in `/varz` | 2.12.4 (#7709) — undocumented, `inbox/docs-issues.md` #57 |
| replica `lag` and `current` consistent on followers | 2.12.5 (#7885) |
| `$SYS.REQ.USER.INFO` returns the account and user nametag | 2.12.6 (#7973) |
| **`in_client_msgs`, `in_client_bytes`, `out_client_msgs`, `out_client_bytes`** in `/varz` — "data to/from normal clients only" | 2.12.9 / 2.14.1 (#7851) — undocumented, noted on #57 |
| `/accstatz` no longer omits accounts with only leaf connections | 2.12.10 (#8252) |
| **JSONP callback support removed** | 2.12.12 |
| `healthz` skips expired JWT accounts; `/varz` reports JetStream limits after a reload | 2.12.14 (#8379, #8394) |

(source: [[s-relnotes-2.12]]). The docs' 2.12 upgrade guide lists `GOMAXPROCS` and `GOMEMLIMIT` in
server stats as new in 2.12; they are 2.10.28 / 2.11.2 (#6791) — `inbox/docs-issues.md` #58.


## Related

[[slow-consumer-detected]] · [[raft-in-nats]] · [[jetstream-sizing]] · [[js-api]] ·
[[jetstream-slows-as-consumers-grow]] · [[advisories]] · [[config-keys]] · [[nats-server-2.14]] ·
[[jetstream-out-of-disk]] · [[nats-timeout]] · [[kv-watchers-stall-the-cluster]]

## Sources

[[s-docs-monitoring-endpoints]] · [[s-nats-server-constants-2.14.6]] · [[s-relnotes-2.14.0]] · [[s-nats-server-auth-and-tls]] · [[s-gh-7684-certificate-expiry]] · [[s-natscli-account-tls]] · [[s-nats-server-jetstream-resources]] · [[s-issue-4281-insufficient-storage]] · [[s-nats-server-topology]] · [[s-gh-7494-supercluster-degradation]] · [[s-docs-putting-it-together]] · [[s-adr-59-sourcing-and-mirroring]] · [[s-nats-server-filestore-layout]] ·
[[s-docs-hardening]] ·
[[s-docs-accounts-and-multitenancy]] · [[s-docs-encryption-and-tls]] · [[s-docs-kubernetes]] · [[s-docs-mirrors-as-dr]] · [[s-docs-prometheus-and-dashboards]] · [[s-docs-single-server]] · [[s-gh-5243-kv-watchers-at-scale]] · [[s-gh-6605-which-consumer-is-slow]] · [[s-gh-7190-asymmetric-cluster]] · [[s-nats-server-tls-reload]] ·
[[s-docs-mqtt-auth-and-clustering]] · [[s-nats-server-mqtt-websocket-observed]] ·
[[s-nats-server-monitoring-observed]] · [[s-gh-7362-routez-connz-rtt]] ·
[[s-gh-7483-varz-cpu-in-containers]] · [[s-docs-monitoring-profiling]] ·
[[s-docs-monitoring-advisories-and-events]] · [[s-docs-monitoring-jetstream-health]] · [[s-nats-server-jetstream-cluster]] · [[s-nats-server-raftz]] · [[s-docs-monitor-raftz]] · [[s-nats-server-meta-layer-rerun-observed]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]]
