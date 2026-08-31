---
title: "docs.nats.io — Monitoring endpoints"
type: summary
area: [monitoring, deploy]
source-url: https://docs.nats.io/learn/monitoring/monitoring-endpoints.md
source-path: raw/nats-docs/learn/monitoring/monitoring-endpoints.md
author: NATS documentation (Synadia Communications, Inc.)
article: Monitoring endpoints
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [monitoring, varz, connz, routez, jsz, healthz, slow_consumers]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Monitoring endpoints

The learn chapter's page on the HTTP monitoring port. It is the **only prose source** for these
endpoints — the 15 reference pages under `reference/system/monitor/` are generated schema dumps with
no explanation at all.

## Key claims

- The **monitoring port is separate from the client port and off until enabled**: `http_port: 8222`
  in the config, or `-m 8222`. "`8222` is the conventional choice, but the port is whatever you
  set."
- It is **plain HTTP, pull-only**: "You send a `GET`, the server returns a JSON snapshot of its
  state at that instant, and the connection closes. The model is a synchronous request answered by
  an on-demand response."
- **The four used most: `/varz` (the server), `/connz` (its clients), `/routez` (its cluster
  routes), `/jsz` (its JetStream).**
- **Every endpoint takes query parameters** to filter, page and sort — "A bare endpoint returns
  everything, which on a busy server is a lot."

### `/varz` — the three counters

| field | meaning |
|---|---|
| `connections` | connected **right now** |
| `total_connections` | since the server started — **only ever goes up** |
| **`slow_consumers`** | "the number of clients the server has **disconnected for not keeping up**; on a healthy node it stays at `0`" |

### `/connz`

Per connection: `cid`, `account`, `authorized_user`, `rtt`, `pending_bytes`, and with `?subs=true`
a `subscriptions_list`. **`?auth=true` is what fills in the account and user.**

`?sort=pending&limit=10` returns "the ten connections with the most data queued: **the clients most
likely to fall behind**".

The two counts at the top describe the response, not the server: `num_connections` is how many this
response returned; `total` is how many matched the query in all. Under `?limit`/`?offset`, `total`
stays put while `num_connections` shrinks to the page size.

### `/routez` — pooled since 2.10

Each entry is one route: `rid`, `remote_name`, `remote_id`, `rtt`, `pending_size`.

> "Since 2.10, routes are pooled: each peer contributes several route entries (a connection pool of
> three plus a dedicated system-account route), so **a default three-node cluster shows eight
> entries on `n1-east`, four per peer**."

So "health isn't a raw count, then, but presence: group by `remote_name` and confirm both peers are
still there. A peer that vanishes entirely, or a climbing `rtt`, is your first sign a node has
dropped off the mesh."

### `/jsz`

Reports "how many streams and consumers it holds, which node is the JetStream meta leader, and the
per-stream and per-consumer numbers underneath" — `streams`, `consumers`,
`meta_cluster.leader`, `account_details[].stream_detail[].state`.

### `/healthz`

"A `/healthz` query whose answer is just ok or error: a `200` when the node is healthy, a `503` when
it isn't. It's built for an orchestrator (a Kubernetes liveness probe, a load balancer) that wants a
yes/no, not JSON to parse." Its parameters "narrow what 'healthy' means (JetStream-only,
this-server-only, a specific stream or consumer), and those distinctions matter for cluster checks."

## Pitfalls the page names

- **Alert on `connections`, not `total_connections`.** "A client that reconnects in a loop (a crash
  loop, a flaky network) barely moves `connections` but inflates `total_connections` fast. Alert on
  the lifetime counter and you page someone at 3am for a number that was always going to grow."
  A large gap between the two, **with `slow_consumers` above zero, is connection flapping, not
  load**.
- **An unscoped `/jsz` is slow at scale.** `?accounts=true&streams=true&consumers=true` "walks every
  account, stream, and consumer on the node and serializes the lot… on a node with thousands of
  consumers it can take long enough that a scrape times out and you get *no* data. **Do not fetch
  the whole tree on a schedule.**" Scope with `?acc=`, page with `?offset` and `?limit`.
- **The monitoring port is unauthenticated by default.** "Anyone who can reach `:8222` can read
  `/connz` and see your users, subjects, and traffic." Locking it down is a security task, named
  here so the port is not exposed by accident.

## Relevance to the wiki

The source for [[monitoring-endpoints]], and the one that gives [[slow-consumer-detected]] its two
real leads: **`slow_consumers` in `/varz`** counts the disconnections, and
**`/connz?sort=pending`** ranks the connections most likely to be responsible — neither of which the
unanswered GitHub thread mentions.

## Questions it answers

Q57 in part (which endpoints to alert on — it names the counters and the two alerting traps, but not
a full alerting runbook), Q58 in part (the `/connz?sort=pending` lead for finding a slow consumer).

## Pages touched

[[monitoring-endpoints]] · [[slow-consumer-detected]] · [[jetstream-sizing]] · [[raft-in-nats]]
