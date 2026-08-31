---
title: Monitoring endpoints
type: reference
area: [monitoring, deploy]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [monitoring, varz, jsz, healthz, connz, routez, raftz, http_port]
aliases: [/varz, /jsz, /healthz, /connz, /routez, /raftz, monitoring port, http_port]
sources: [s-nats-server-jetstream-resources, s-issue-4281-insufficient-storage, s-docs-monitoring-endpoints, s-docs-hardening, s-nats-server-constants-2.14.6, s-relnotes-2.14.0, s-nats-server-auth-and-tls, s-gh-7684-certificate-expiry, s-natscli-account-tls, s-nats-server-topology, s-gh-7494-supercluster-degradation, s-docs-putting-it-together, s-adr-59-sourcing-and-mirroring]
created: 2026-08-31
updated: 2026-08-31
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
| **`/jsz`** | JetStream state: streams, consumers, meta leader | `account`, `accounts`, `config`, `consumer`, `direct_consumer`, `leader_only`, `limit`, `offset`, `raft`, `stream_leader_only`, `streams` |
| **`/healthz`** | a yes/no health check — `200` healthy, `503` not | `account`, `consumer`, `details`, `js-enabled` *(deprecated — use `js-enabled-only`)*, `js-enabled-only`, `js-meta-only`, `js-server-only`, `stream` |
| **`/raftz`** | live RAFT group state: term, leader, per-peer status | `account`, `group` |
| `/accountz` | account configuration | `account` |
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

### `/jsz` — scope it or it will time out

`/jsz` reports streams, consumers, `meta_cluster.leader`, and the per-stream and per-consumer
numbers beneath.

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

Since **2.14** a filestore I/O error **freezes the affected stream and reports unhealthy here**,
with the error text containing `write error`; the server keeps serving core traffic and needs a
restart to recover (source: [[nats-server-2.14]]).

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

## What is deliberately not here

**Response fields.** Each endpoint's response schema runs to dozens of fields and is generated; the
docs' own pages are the place for them. The fields above are the ones this wiki has a reason to
explain. `/raftz`'s field set, in particular, is referenced by [[raft-in-nats]] but **has not been
ingested** — it is the next monitoring source worth taking.

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
(source: [[s-adr-59-sourcing-and-mirroring]]).

Other `/jsz` selectors from the same spec: `acc`, `leader-only`, `stream-leader-only`, `raft`,
`offset` and `limit`.


## Related

[[slow-consumer-detected]] · [[raft-in-nats]] · [[jetstream-sizing]] · [[js-api]] ·
[[jetstream-slows-as-consumers-grow]] · [[advisories]] · [[config-keys]] · [[nats-server-2.14]] ·
[[jetstream-out-of-disk]] · [[nats-timeout]] · [[kv-watchers-stall-the-cluster]]

## Sources

[[s-docs-monitoring-endpoints]] · [[s-nats-server-constants-2.14.6]] · [[s-relnotes-2.14.0]] · [[s-nats-server-auth-and-tls]] · [[s-gh-7684-certificate-expiry]] · [[s-natscli-account-tls]] · [[s-nats-server-jetstream-resources]] · [[s-issue-4281-insufficient-storage]] · [[s-nats-server-topology]] · [[s-gh-7494-supercluster-degradation]] · [[s-docs-putting-it-together]] · [[s-adr-59-sourcing-and-mirroring]]
