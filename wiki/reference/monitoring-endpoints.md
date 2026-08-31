---
title: Monitoring endpoints
type: reference
area: [monitoring, deploy]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [monitoring, varz, jsz, healthz, connz, routez, raftz, http_port]
aliases: [/varz, /jsz, /healthz, /connz, /routez, /raftz, monitoring port, http_port]
sources: [s-docs-monitoring-endpoints, s-nats-server-constants-2.14.6, s-relnotes-2.14.0]
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

## Related

[[slow-consumer-detected]] · [[raft-in-nats]] · [[jetstream-sizing]] · [[js-api]] ·
[[jetstream-slows-as-consumers-grow]] · [[advisories]] · [[config-keys]] · [[nats-server-2.14]]

## Sources

[[s-docs-monitoring-endpoints]] · [[s-nats-server-constants-2.14.6]] · [[s-relnotes-2.14.0]]
