---
title: "nats-surveyor v0.9.11 against nats-server v2.14.6 — every series it emitted, observed, and the source behind the names"
type: summary
area: [monitoring, jetstream, topology]
source-url: https://github.com/nats-io/nats-surveyor/releases/tag/v0.9.11
source-path: raw/nats-surveyor-src/metrics-observed-v0.9.11.md
author: this wiki (runs on the v2.14.6 binary, surveyor v0.9.11, 2026-09-03; the appendix quotes the v0.9.11 source from the Go module cache)
article: "three scrapes over the system account: --jsz all --accounts --raftz; the same with --jsz-leaders-only; --prefix x"
date: 2026-09-03
version: "2.14.6"         # the server; surveyor is v0.9.11 (2026-07-23)
tags: [surveyor, prometheus, nats_core, nats_up, raftz, jsz-leaders-only, prefix, system-account, observed]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-surveyor v0.9.11 against nats-server v2.14.6, observed

Three scrapes over the lab cluster's system account, on the same shape as the exporter runs
([[s-prometheus-nats-exporter-metrics-observed]]): one R3 stream with 30 messages, a pull consumer
holding 10 twice-delivered unacked messages, an R1 mirror and an R1 sourcing stream on n2. The
appendix of the raw file quotes the v0.9.11 source lines that build the names.

## Key claims

1. **105 series with every optional collector on** (`--jsz all --accounts --raftz`, run S1) — all under
   the literal namespace `nats`: 23 `nats_core_*` server series (`connection_count`,
   `total_connection_count`, `subs_count`, `slow_consumer_count`, `recv_msgs_count`, `recv_bytes`,
   `sent_msgs_count`, `sent_bytes`, `recv_from_client_msgs_total` / `_bytes_total`,
   `sent_to_client_msgs_total` / `_bytes_total`, `mem_bytes`, `cpu_percentage`, `core_count`,
   `gomaxprocs`, `go_memlimit_bytes`, `rtt_nanoseconds`, `start_time`, `uptime`, `route_count`,
   `gateway_count`, `active_account_count`, `info`), 6 `nats_core_route_*` (per route: `sent_msg_count`,
   `sent_bytes`, `recv_msg_count`, `recv_bytes`, `pending_bytes`, plus `route_count`), 20
   `nats_core_account_*` (`--accounts`), 26 `nats_core_jetstream_*` (including `ha_assets`,
   `api_requests` / `api_errors` / `api_pending`, `filestore_*` / `memstore_*` size/used/reserved,
   `server_total_streams` / `_stream_leaders` / `_consumers` / `_consumer_leaders`, the four
   `meta_snapshot_*`), 7 `nats_core_jetstream_cluster_raft_group_*` (from `STATSZ`'s meta block:
   `info`, `leader`, `size`, `replicas`, `replica_peer_active` / `_current` / `_offline`), 3
   `nats_core_raftz_meta_*` (`--raftz`: `committed`, `applied`, `pindex`), 6 `nats_stream_*` and 8
   `nats_consumer_*` (`--jsz`), `nats_survey_surveyed_count` / `_expected_count` /
   `_duration_seconds`, `nats_up`, `nats_jetstream_advisory_count`, `nats_latency_observations_count`.
   **19 are counters** (the traffic and API totals), 85 gauges, one summary.
2. **Labels differ from the exporter's.** Server series carry `server_cluster`, `server_id`
   (the server's NKey id, not a URL), `server_name`; `nats_core_info` adds `server_version`; the
   JetStream series carry `cluster_name`, `server_id`, `server_name`, and the stream/consumer ones
   `account`, `account_name`, **`stream`** (the exporter says `stream_name`), `stream_leader`,
   `raft_group`, `consumer_name`, `consumer_leader` — **no `is_*_leader` booleans**; the leader is
   compared by name.
3. **One sample per replica, and `num_pending` is 0 off the leader**: `nats_consumer_num_pending`
   read 20 on n2 (the consumer leader) and 0 on n1 and n3; `num_ack_pending` and `num_redelivered` 10
   on all three (S1). The server side is [[s-nats-server-traffic-counters-and-ha-assets]].
4. **`--jsz-leaders-only` keeps one sample per asset** (run S2): the consumer series went from 3 to 1
   sample each and the stream series from 5 to 3 (the R3 stream's three replicas became one; the two
   R1 streams stayed) — 439 → 411 samples on this shape. It removes the replicas' copies, not "half".
5. **`--prefix` does nothing** (run S3: 102 `nats_*` series, 0 `x_*`): `cmd/root.go:238` defines the
   flag with the help "Replace the default prefix for all the metrics", `:333` stores it, and
   `surveyor/surveyor.go:82` declares the field as `Prefix string // TODO` — nothing reads it; every
   name is built with `prometheus.BuildFQName("nats", …)` (`collector_statz.go:391`, `574–652`).
6. **The three `raftz` series carry shifted labels**: `nats_core_raftz_meta_applied{cluster_name="NDSQ…",server_id="east",server_name="n1"}`
   — `cluster_name` holds the server id and `server_id` the cluster name. The descriptors are declared
   with `jsServerLabels` = `server_id`, `server_name`, `cluster_name` (`collector_statz.go:953`) but
   filled with the ordinary server-label values (`:2163–2169`; `serverLabelValues`, `:356–358`), whose order is cluster, name, id.
   The `raft_group_info` series' `cluster_name` is `_meta_` on the two followers and `east` on the
   leader.
7. **`nats_up 1`, `nats_survey_expected_count 3`, `nats_survey_surveyed_count 3`** — the health of the
   survey itself; the README says `nats_up` goes to 0 "and no additional NATS metrics" when the system
   is unreachable.
8. **Coverage the exporter lacks**: per-route traffic and pending bytes, per-account JetStream
   reservations and tiers, `ha_assets`, stream and consumer **leader counts** per server, the meta
   group's Raft indices (`--raftz`), API pending, `cpu_percentage` and RTT — all from one connection over
   `$SYS.REQ.SERVER.PING.STATSZ` / `JSZ` / `RAFTZ` ([[system-subjects]]).

## Practical takeaways

- Do not pass `--prefix` expecting a rename; dashboards must use `nats_core_*` / `nats_stream_*` /
  `nats_consumer_*` as they are.
- For consumer lag alerts use `--jsz-leaders-only` (one true sample per consumer) or filter
  `server_name == consumer_leader` in PromQL; there is no `is_consumer_leader` label here.
- `--jsz all` on a large deployment multiplies samples by replica count; `--jsz-limit` (1024) caps the
  accounts' JetStream metrics, `--jsz-filter` the consumer series.

## Relevance to the wiki

The surveyor half of [[metrics]]; the *What bites you* section of [[nats-surveyor]]; docs issue #77
(the `--prefix` help text).

## Questions it answers

Q83, Q84, Q85 (the surveyor side), Q153 (`nats_core_jetstream_ha_assets`).

## Pages touched

[[metrics]] · [[nats-surveyor]] · [[raft-in-nats]] · [[monitoring-endpoints]] · [[system-subjects]]
