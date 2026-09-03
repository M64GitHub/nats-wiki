---
title: "prometheus-nats-exporter v0.20.2 against nats-server v2.14.6 — every series it emitted, observed"
type: summary
area: [monitoring, jetstream, core]
source-url: https://github.com/nats-io/prometheus-nats-exporter/releases/tag/v0.20.2
source-path: raw/prometheus-nats-exporter-src/metrics-observed-v0.20.2.md
author: this wiki (runs on the v2.14.6 binary, nats CLI 0.4.0, exporter v0.20.2, 2026-09-03; scripts metrics-run.sh and metrics-run2.sh beside the file)
article: "ten scrapes: every collector, -prefix nats, connz_detailed, jsz=streams, no flags, jsz alone, the internal server name, the leader's node, a live client"
date: 2026-09-03
version: "2.14.6"         # the server; the exporter is v0.20.2
tags: [exporter, prometheus, gnatsd, jetstream_, num_pending, is_consumer_leader, healthz, observed]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# prometheus-nats-exporter v0.20.2 against nats-server v2.14.6, observed

Ten scrapes on the lab cluster (`tools/lab/cluster.sh up 3`): one R3 file stream with 30 messages, a
pull consumer holding 10 unacked messages each delivered twice, an R1 mirror and an R1 sourcing stream
on node n2. The source half is [[s-prometheus-nats-exporter-collector]].

## Key claims

1. **With every collector on and no `-prefix` (run A, node n1): 167 NATS series** — 139 `gnatsd_*`
   (`varz` 83, `accountz` 15, `subsz` 12, `connz` 10, `accstatz` 9, `healthz` 2 × 3 variants, `routez`
   3, `leafz` 1) and 28 `jetstream_*` (`server` 7, `account` 4, `stream` 8, `consumer` 9) — plus 38
   `go_*` / `process_*` / `promhttp_*` from the client library. **135 of the 139 core series are typed
   `gauge`; the four counters are `gnatsd_connz_in_bytes` / `in_msgs` / `out_bytes` / `out_msgs`.**
   `gnatsd_varz_in_msgs` and friends are gauges although they only climb.
2. **`-prefix nats` renames every one of the 167** (run B): the name lists differ only in the
   namespace — `nats_varz_connections`, `nats_healthz_status`, `nats_consumer_num_pending`,
   `nats_server_jetstream_disabled`.
3. **The exporter sees only what the scraped node holds.** n1 (run A) reports `total_streams 1` and no
   mirror or source series; n2 (run H1-n2), which holds the two R1 streams and leads the R3 ones,
   reports `total_streams 3` and adds `jetstream_stream_mirror_lag` / `_mirror_active_duration_ns`
   (mirror `ORDERS`), `jetstream_stream_source_lag` / `_source_active_duration_ns` (source `ORDERS`) and,
   after one acknowledgement, `jetstream_consumer_last_ack_seconds`. An R1 asset appears on exactly one
   node's exporter.
4. **`num_pending` is 0 on the followers.** `nats consumer info` said *Unprocessed Messages: 20*;
   n1's exporter (a follower, `is_consumer_leader="false"`) printed `jetstream_consumer_num_pending … 0`
   while n2's (`is_consumer_leader="true"`) printed 20 (runs H1-n1 / H1-n2). `num_ack_pending` (10, then
   9), `num_redelivered` (10, then 9), `delivered_*` and `ack_floor_*` agreed on every node. The server
   side is [[s-nats-server-traffic-counters-and-ha-assets]]; the public report is
   [[s-exporter-issue-218-num-pending-differs-per-node]].
5. **The consumer series carry seventeen labels**, verbatim from run A:

   ```
   jetstream_consumer_num_ack_pending{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 10
   ```

   `server_id` is the monitoring URL by default; `-use_internal_server_name` makes it `n1` (run G).
6. **`-jsz=streams` (run D)** emits no consumer series, no `limit_bytes` / `limit_messages`, and
   `stream_raft_group=""` — the narrower `/jsz` query carries no config and no raft block. **Any `-jsz`
   value alone silently adds `varz`** with `No metrics specified.  Defaulting to varz.` (runs D and F:
   84 `gnatsd_varz_*` series appeared unasked); **no collector flag at all is fatal**:
   `[FTL] error starting the exporter: no Collectors specified` (run E).
7. **`gnatsd_healthz_status` is 0 when healthy** — all three variants printed `_status 0` and
   `_status_value{value="ok"} 1` on a healthy node.
8. **`connz`**: with no client the ten summary series are 0 (run C); with one `nats sub` connected
   (run H2) each per-connection series carries `cid="41"`, `kind="Client"`, `type="nats"`, `lang="go"`,
   `version="1.51.0"`, `name="NATS CLI Version 0.4.0"`, `name_tag="$G"` — and **`account=""`**, because
   `/connz?auth=true` omits `account` for the global account `$G` (server side,
   [[s-nats-server-traffic-counters-and-ha-assets]]); `rtt` 146 (µs), `uptime` and `idle` 1000 (ms).
   `gnatsd_connz_limit 1024` is the page the sums cover.
9. **The `/varz` flattening in practice**: `gnatsd_varz_jetstream_stats_ha_assets 3` (the meta group
   plus one R3 stream plus one R3 consumer on n1), `_jetstream_stats_storage 1431`,
   `_jetstream_stats_api_errors 1`, `_jetstream_meta_pending 0`, `_jetstream_meta_snapshot_pending_entries 4`,
   `_slow_consumer_stats_clients` / `_routes` / `_gateways` / `_leafs`, `_stale_connection_stats_*`,
   `_disk_io_wait_stats_*`, `_http_req_stats_<endpoint>` (a request count per endpoint — the scrapes
   themselves), `_cluster_pool_size 3`, `_routes 8`; label gauges `cluster_name`, `server_id`,
   `server_name`, `version`, `jetstream_meta_leader`, `jetstream_meta_name`; `start` and
   `config_load_time` as epoch ms (`1.788403202188e+12`); durations in nanoseconds
   (`write_deadline 1e+10`, `jetstream_config_sync_interval 1.2e+11`). No `auth_required`, no
   `connect_urls`, no per-route entries.
10. **`accountz` and `accstatz`** emit per-account samples for `$G` and `$SYS` — `gnatsd_accountz_is_system{account_name="$SYS"} 1`,
    `gnatsd_accountz_jetstream_enabled{account_name="$G"} 1`, `gnatsd_accstatz_slow_consumers … 0`,
    `gnatsd_accstatz_subscriptions{account_name="$SYS"} 228`; every JWT limit is 0 on a config-file
    account.

## Practical takeaways

- Alert on the leader's copy: `jetstream_consumer_num_pending{is_consumer_leader="true"}`. A cluster
  sum over all nodes is the leader's value anyway, but a per-node panel shows two zeroes.
- One exporter per node is not optional for JetStream: an R1 stream's series exist on one node only.
- Never start the exporter without a collector flag; never assume `-jsz` implies nothing else.

## Relevance to the wiki

The observed half of [[metrics]]; every *What bites you* item on [[prometheus-nats-exporter]].

## Questions it answers

Q83, Q84, Q85, Q129 (the series), Q165.

## Pages touched

[[metrics]] · [[prometheus-nats-exporter]] · [[consumer]] · [[monitoring-endpoints]] · [[slow-consumer-detected]] · [[worker-pool]] · [[jetstream-out-of-disk]] · [[stream-has-high-message-lag]] · [[advisories]]
