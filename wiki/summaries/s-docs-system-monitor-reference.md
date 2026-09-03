---
title: "docs.nats.io — System reference: the monitor tree (15 endpoint pages)"
type: summary
area: [monitoring]
source-url: https://docs.nats.io/reference/system/monitor.md
source-path: raw/nats-docs/reference/system/monitor.md
author: NATS documentation (Synadia Communications, Inc.) — generated from the monitoring JSON schemas
article: "reference/system.md, reference/system/monitor.md and the 14 pages under reference/system/monitor/ other than raftz (varz, connz, subsz, routez, gatewayz, leafz, accountz, accstatz, jsz, healthz, statsz, ipqueuesz, idz, profilez)"
date: 2026-08-31          # the pages are undated; this is the fetch date
version: "2.14"
tags: [monitoring, varz, jsz, statsz, idz, profilez, generated]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# docs.nats.io — System reference: the monitor tree

The whole `reference/system/` monitor tree read in one sitting for phase E
(`inbox/plan-the-reference-layer-2026-09-03.md`, step 1); `raftz.md` has its own summary
([[s-docs-monitor-raftz]]). The unit is the tree, not the page: fifteen generated schema listings
of a few hundred bytes each, with no prose about behaviour.

## Key claims

- `reference/system.md` lists four categories — advisories, metrics, monitoring, errors — and
  `monitor.md` presents **fifteen "HTTP monitoring endpoints"** (`Varz`, `Connz`, `Subsz`, `Routez`,
  `Gatewayz`, `Leafz`, `Accountz`, `Accstatz`, `JSz`, `Healthz`, `Statsz`, `IPQueuesz`, `Idz`,
  `Profilez`, `Raftz`), configured with `http_port: 8222` and "then accessible at
  `http://localhost:8222/varz`".
- Each subpage is `## Request Schema` (the JSON-tag names of the request options struct) and
  `## Response Schema` (field, type, one line). `varz.md` is the only one with substance: ~70
  response fields including `slow_consumers`, `stale_connections`, `stalled_clients`,
  `slow_consumer_stats`, `stale_connection_stats`, `config_digest`, `config_load_time`,
  `tls_cert_not_after`, `pinned_account_fails`, `http_req_stats`, `gomaxprocs`, `gomemlimit`; it
  annotates **`max_connections`** — an integer count (`Varz.MaxConn int`, `monitor.go:1235`) —
  with "nanoseconds depicting a duration in time".
- `statsz.md` documents request options `cluster`, `domain`, `exact_match`, `host`, `server_name`,
  `tags` — which are the `EventFilterOptions` of a system request, not URL parameters — and a
  response of `active_accounts`, `active_servers`, `connections`, `cores`, `cpu`, `gateways`,
  `jetstream`, `mem`, `received`, `routes`, `sent`, `slow_consumer_stats`, `slow_consumers`,
  `stale_connection_stats`, `stale_connections`, `stalled_clients`, `start`, `subscriptions`,
  `total_connections`, `gomaxprocs`, `gomemlimit`. `idz.md` has no request schema and a response of
  `id`, `name`, `host`, `ver`, `cluster`, `domain`, `jetstream` ("deprecated in favor of the
  `ServerCapability`"), `flags`, `feature_flags`, `tags`, `metadata`, `seq`, `time` — the
  `ServerInfo` envelope, not the bare `ServerID` the request actually answers with.
  `profilez.md`: `debug`, `duration` (nanoseconds), `name`; response `error`, `profile` (integer
  array).
- `jsz.md` request options: `account`, `accounts`, `config`, `consumer`, `direct_consumer`,
  `leader_only`, `limit`, `offset`, `raft`, `stream_leader_only`, `streams` (docs issue #48 for the
  URL names); response: `account_details`, `accounts`, `api`, `bytes`, `config`, `consumers`,
  `consumers_leader`, `disabled`, **`ha_assets`**, `limits`, `memory`, `messages`, `meta_cluster`,
  `now`, `reserved_memory`, `reserved_storage`, `server_id`, `storage`, `streams`, `streams_leader`,
  `total`.
- `connz.md`: `sort` allowed values `cid`, `start`, `subs`, `pending`, `msgs_to`, `msgs_from`,
  `bytes_to`, `bytes_from`, `last`, `idle`, `uptime`, `stop`, `reason`, `rtt` — "Only the sort by
  connection ID (ByCid) is ascending, all others are descending"; `state` `open` / `closed` / `all`;
  `mqtt_client`; `filter_subject`. `healthz.md`: `js-enabled` "Deprecated: Use JSEnabledOnly
  instead", `js-enabled-only`, `js-meta-only`, `js-server-only`, `account`, `stream`, `consumer`,
  `details`; response `status`, `status_code`, `error`, `errors[]`. `subsz.md`: `test` — "Needs to be
  literal since it signifies a publish subject"; response `cache_hit_rate`, `num_cache`,
  `num_inserts`, `num_matches`, `num_removes`, `avg_fanout`, `max_fanout`. `accstatz.md`:
  `accounts[]`, `include_unused`. `ipqueuesz.md`: `all`, `filter`, and an empty response schema.
- `monitor.md`'s *Security Considerations* says "Use authentication to protect monitoring endpoints"
  and "Consider TLS" — the port has no authentication of its own; TLS is `https_port`
  ([[monitoring-endpoints]]).

## Practical takeaways

- Three of the fifteen — `statsz`, `idz`, `profilez` — return **404** over HTTP on 2.14.6; they are
  `$SYS.REQ.SERVER.PING.<Z>` requests only. Two HTTP paths the tree never mentions exist:
  `/stacksz` and `/debug/vars` ([[s-nats-server-system-subjects-observed]]). Docs issue #65.
- The request options on `statsz.md` are the filter every system request accepts; the page is the
  only place in the docs that names them.

## Notable quotes

- "Endpoints are then accessible at `http://localhost:8222/varz`" — `monitor.md`.
- "Whether JetStream is enabled (deprecated in favor of the `ServerCapability`)." — `idz.md`.

## Relevance to the wiki

Completes the docs coverage of `reference/system/` (23 of 23 read); the field lists feed
[[monitoring-endpoints]]'s query-parameter column and [[system-subjects]]'s request table; docs
issue #65 (the three non-endpoints) and the `max_connections` annotation (#68).

## Questions it answers

Row 161 in part (which names are request-only).

## Pages touched

[[system-subjects]] · [[monitoring-endpoints]]
