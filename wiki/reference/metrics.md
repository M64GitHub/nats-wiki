---
title: Metrics
type: reference
area: [monitoring, jetstream, core]
since: [2.10]   # the endpoints the series are read from exist at 2.10; per-field arrivals are dated in the tables
verified-against: nats-server 2.14.6
verified-on: 2026-09-03
tags: [metrics, prometheus, exporter, surveyor, gnatsd, jetstream_, nats_, num_pending, ha_assets, alerting, time-series]
aliases: [prometheus metrics, metric names, exporter metrics, surveyor metrics, nats_consumer_num_pending, gnatsd_varz, jetstream_consumer_num_pending, series names]
sources: [s-prometheus-nats-exporter-collector, s-prometheus-nats-exporter-metrics-observed, s-nats-surveyor-metrics-observed, s-nats-server-traffic-counters-and-ha-assets, s-gh-2818-counters-exact-or-sampled, s-gh-3857-consumer-pending-series, s-gh-6182-what-to-alert-on, s-gh-5128-ha-assets, s-exporter-issue-218-num-pending-differs-per-node, s-docs-prometheus-and-dashboards, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12, s-relnotes-2.14, s-docs-services-discovery-and-stats]
created: 2026-09-03
updated: 2026-09-04
---

# Metrics

The time series `prometheus-nats-exporter` **v0.20.2** emits from a nats-server **2.14.6** monitoring
port, each mapped to the endpoint field it is read from, and the names `nats-surveyor` **v0.9.11**
uses where they differ. Not here: dashboards, and the events that are not series — the JetStream
advisories are on [[advisories]], the `$SYS` events and requests on [[system-subjects]], the endpoints
and their query parameters on [[monitoring-endpoints]]. Every name below was read from the two tools'
source at those tags and produced on a scrape of the lab cluster on 2026-09-03 (source:
[[s-prometheus-nats-exporter-collector]], [[s-prometheus-nats-exporter-metrics-observed]],
[[s-nats-surveyor-metrics-observed]]).

## The naming rule, and the prefix nobody documents

The exporter's name is **`<namespace>_<endpoint>_<field>`** for the core collectors and
**`<namespace>_<server|account|stream|consumer>_<field>`** for JetStream, where `<field>` is the wire
field of the endpoint, nested objects flattened with `_`. The two default namespaces are **`gnatsd`**
for everything read from `/varz`, `/connz`, `/routez`, `/subsz`, `/healthz`, `/accountz`, `/accstatz`,
`/leafz` and `/gatewayz`, and **`jetstream`** for `/jsz` (`collector.go:34–35` at v0.20.2, kept "for
backward compatibility"). **`-prefix nats` replaces both**, which is what the Helm chart and every
community dashboard assume (source: [[s-docs-prometheus-and-dashboards]]) — so the same series is:

| invocation | core example | JetStream example |
|---|---|---|
| default | `gnatsd_varz_connections` | `jetstream_consumer_num_pending` |
| `-prefix nats` | `nats_varz_connections` | `nats_consumer_num_pending` |
| nats-surveyor (fixed) | `nats_core_connection_count` | `nats_consumer_num_pending` |

The docs describe only the JetStream half of that rename; the `gnatsd_` default appears in the
exporter's README and nowhere in docs.nats.io (`inbox/docs-issues.md` #76). Surveyor's names are
hard-coded with the `nats` namespace and **its `--prefix` flag is a no-op** at v0.9.11 (the field is
marked `// TODO`; run S3 produced 0 renamed series — #77).

Three more rules that decide what a query returns:

- **Almost everything is a gauge.** Of the exporter's 139 core series in the run, 135 are typed
  `gauge`; the only counters are the four `<ns>_connz_in_msgs` / `in_bytes` / `out_msgs` / `out_bytes`.
  `gnatsd_varz_in_msgs` climbs monotonically but is declared a gauge — `rate()` still works on it.
  Surveyor types its 19 traffic and API totals as counters.
- **The `server_id` label is the monitoring URL by default** — `server_id="http://127.0.0.1:8291"` —
  unless `-use_internal_server_id` (the NKey id) or `-use_internal_server_name` (`server_id="n1"`) is
  given. Surveyor's `server_id` is always the NKey id, with `server_name` and `server_cluster` beside it.
- **Strings, booleans and arrays are not exported** by the generic collector: only eight string keys
  (`server_id`, `server_name`, `version`, `domain`, `leader`, `name`, `start`, `config_load_time`)
  become a "label gauge" — `gnatsd_varz_version{value="2.14.6"} 1` — or, for times, epoch
  **milliseconds**. `auth_required`, `tls_required`, `connect_urls`, `git_commit`, `store_dir` and the
  per-route list of `/routez` have **no series**.

Every scrape also carries about 38 `go_*`, `process_*` and `promhttp_*` series from the Prometheus
client library; they describe the exporter process, not the server.

## Which node's exporter to read

An exporter reads **one server's** port, and `/jsz` describes only the assets that server holds
a replica of. In the run, n1's exporter reported `jetstream_server_total_streams 1` and no mirror or
source series, while n2 — leader of the R3 stream and consumer and the only holder of the two R1
streams — reported `3` and the `mirror_lag` / `source_lag` series. **An R1 stream exists on one node's
exporter only**, so one exporter per node is the minimum for JetStream.

Then the rule that has confused operators since 2023 (exporter issue #218, open and unanswered,
source: [[s-exporter-issue-218-num-pending-differs-per-node]]): **`num_pending` is computed by the
consumer's leader and is 0 on every replica.** `streamNumPending` returns 0 without consulting the
store unless this server is the leader (`consumer.go:5628–5632`, source:
[[s-nats-server-traffic-counters-and-ha-assets]]); `num_ack_pending`, `num_redelivered`, `delivered_*`
and `ack_floor_*` come from the replicated state and agree on every node. Observed: `nats consumer
info` said *Unprocessed Messages: 20*, n2's exporter printed 20, n1's and n3's printed 0, and all three
printed `num_ack_pending 10`.

```
# the consumer's real lag, per exporter
jetstream_consumer_num_pending{is_consumer_leader="true"}
# surveyor: one sample per asset instead of one per replica
nats-surveyor … --jsz all --jsz-leaders-only
```

Surveyor has no `is_consumer_leader` label; compare `server_name` with `consumer_leader`, or use
`--jsz-leaders-only`, which in the run reduced the consumer series from three samples to one and the
stream series from five to three (the R3 stream's replicas collapsed, the two R1 streams stayed).

## The exporter's series, by collector

Names are given with the default namespace; replace `gnatsd_` and `jetstream_` by `nats_` under
`-prefix nats`. "Field" is the endpoint field the value is copied from. Arrival dates come from the
release notes where they record one; **every other field is present at 2.14.6 and the notes from
2.10.0 onward do not record its arrival**, so it may predate 2.10.

### `-varz` → `/varz` (83 series, all gauges, labelled `server_id`)

| series | field(s) | note |
|---|---|---|
| `gnatsd_varz_connections`, `_total_connections`, `_routes`, `_remotes`, `_leafnodes`, `_subscriptions` | the same names | `connections` is now, `total_connections` since start — see [[monitoring-endpoints]] |
| `gnatsd_varz_in_msgs`, `_in_bytes`, `_out_msgs`, `_out_bytes` | the same | exact since-start counters, all connection kinds (routes, gateways, leafs included) — see *Counters are exact* below |
| `gnatsd_varz_in_client_msgs`, `_in_client_bytes`, `_out_client_msgs`, `_out_client_bytes` | the same | clients only; **2.12.9 / 2.14.1** (#7851, source: [[s-relnotes-2.12]], [[s-relnotes-2.14]]) |
| `gnatsd_varz_slow_consumers` | `slow_consumers` | clients disconnected as slow consumers since start — [[slow-consumer-detected]] |
| `gnatsd_varz_slow_consumer_stats_clients`, `_routes`, `_gateways`, `_leafs` | `slow_consumer_stats{}` | **2.10.0** (#4330, source: [[s-relnotes-2.10]]) |
| `gnatsd_varz_stale_connections`; `_stale_connection_stats_clients`, `_routes`, `_gateways`, `_leafs` | `stale_connections`, `stale_connection_stats{}` | |
| `gnatsd_varz_stalled_clients` | `stalled_clients` | stall events since start — the fast-producer counter of [[slow-consumer-detected]] and [[gateway]] |
| `gnatsd_varz_disk_io_wait_stats_waits`, `_waiters`, `_wait_time`, `_max_wait_time` | `disk_io_wait_stats{}` | the filestore's disk I/O semaphore |
| `gnatsd_varz_cpu`, `_cores`, `_gomaxprocs`, `_mem` | the same | `cpu` is a percentage of one core ([[monitoring-endpoints]]); `mem` bytes RSS; `gomaxprocs` **2.10.28** (#6791) |
| `gnatsd_varz_start`, `_config_load_time` | the same | epoch **milliseconds** |
| `gnatsd_varz_version`, `_server_id`, `_server_name`, `_cluster_name` | the same | label gauges: `…{value="2.14.6"} 1` |
| `gnatsd_varz_port`, `_http_port`, `_https_port`, `_proto` | the same | |
| `gnatsd_varz_auth_timeout`, `_tls_timeout`, `_ping_interval`, `_ping_max`, `_write_deadline`, `_max_connections`, `_max_control_line`, `_max_payload`, `_max_pending`, `_cluster_pool_size` | the same | the effective config; durations in **nanoseconds** (`write_deadline 1e+10` = 10 s) — the values are on [[defaults-and-limits]] |
| `gnatsd_varz_http_req_stats_varz`, `_connz`, `_routez`, `_subsz`, `_jsz`, `_healthz`, `_accountz`, `_accstatz`, `_gatewayz`, `_leafz` | `http_req_stats{}` | requests per endpoint since start — one key per endpoint ever hit, so the set grows |
| `gnatsd_varz_jetstream_config_max_memory`, `_max_storage`, `_sync_interval` | `jetstream.config{}` | `sync_interval` in ns (`1.2e+11` = 2 m) |
| `gnatsd_varz_jetstream_stats_memory`, `_storage`, `_reserved_memory`, `_reserved_storage`, `_accounts`, `_ha_assets`, `_api_total`, `_api_errors`, `_api_level` | `jetstream.stats{}` | `storage` is logical, `reserved_storage` is what `10047` compares ([[jetstream-out-of-disk]]); `ha_assets` below |
| `gnatsd_varz_jetstream_meta_name`, `_leader` (label gauges), `_cluster_size`, `_pending`, `_pending_requests`, `_pending_infos`, `_snapshot_pending_entries`, `_snapshot_pending_size` | `jetstream.meta{}` | the meta group ([[meta-layer]]); the snapshot statistics are **2.11.11 / 2.12.2** in `/jsz` (#7524, source: [[s-relnotes-2.11]]); `replicas[]` is an array and has no series |

### `-connz` and `-connz_detailed` → `/connz`

| series | field | type | labels |
|---|---|---|---|
| `gnatsd_connz_num_connections`, `_total`, `_offset`, `_limit` | the response header | gauge | `server_id` |
| `gnatsd_connz_pending_bytes`, `_subscriptions` | summed over the page | gauge | `server_id` |
| `gnatsd_connz_in_msgs`, `_in_bytes`, `_out_msgs`, `_out_bytes` | summed over the page | **counter** | `server_id` |
| with `-connz_detailed`, the six above per connection, plus `gnatsd_connz_rtt` (µs), `_uptime` (ms), `_idle` (ms), `_start`, `_last_activity` (epoch ms) | per connection | gauge / untyped | `server_id`, `cid`, `kind`, `type`, `ip`, `port`, `name`, `name_tag`, `account`, `account_id`, `lang`, `version`, `tls_version`, `tls_cipher_suite` |

The sums cover the **page** `/connz` returns without `limit` — 1024 connections
(`DefaultConnListSize`, `monitor.go:170`); with more clients than that, `_total` exceeds
`_num_connections` and the sums are partial. **`account` is empty for clients in `$G`**: the server
omits it for the global account, and `name_tag` carries the name instead (`monitor.go:457–463`).

### `-healthz`, `-healthz_js_enabled_only`, `-healthz_js_server_only` → `/healthz`

| series | value |
|---|---|
| `gnatsd_healthz_status` | **0 when the status is `ok`, 1 otherwise** — inverted, kept "the same" for compatibility |
| `gnatsd_healthz_status_value{value="ok"|"<status>"|"unreachable"}` | 1 when ok, 0 otherwise; the only series emitted when the port cannot be reached |
| `gnatsd_healthz_js_enabled_only_status`, `_status_value` | the same for `?js-enabled-only=true` |
| `gnatsd_healthz_js_server_only_status`, `_status_value` | the same for `?js-server-only=true` |

**There is no `js-meta-only` collector.** The one `/healthz` form that turns 503 when the cluster
loses quorum (`?js-meta-only=true`, **2.11.0**, source: [[s-relnotes-2.11]]; [[monitoring-endpoints]])
cannot be scraped by the exporter at v0.20.2; quorum has to come from surveyor's Raft series or from
the advisories.

### `-routez` → `/routez` and `-subz` → `/subsz` (generic)

| series | note |
|---|---|
| `gnatsd_routez_num_routes`; `_server_id`, `_server_name` (label gauges) | the `routes[]` array is dropped — **no per-route RTT or pending bytes** from the exporter (surveyor has `nats_core_route_*`) |
| `gnatsd_subsz_num_subscriptions`, `_num_cache`, `_num_inserts`, `_num_removes`, `_num_matches`, `_cache_hit_rate`, `_max_fanout`, `_avg_fanout`, `_total`, `_offset`, `_limit`; `_server_id` | the sublist statistics |

### `-accstatz` → `/accstatz?unused=1` and `-accountz` → `/accountz`, `/accountz?acc=<id>`

| series | labels | note |
|---|---|---|
| `gnatsd_accstatz_current_connections`, `_total_connections`, `_subscriptions`, `_leaf_nodes`, `_sent_messages`, `_sent_bytes`, `_received_messages`, `_received_bytes`, **`_slow_consumers`** | `server_id`, `account`, `account_id`, `account_name` | per account, including `$SYS`; the per-account slow-consumer count [[slow-consumer-detected]] asked for |
| `gnatsd_accountz_client_connections`, `_leafnode_connections`, `_subscriptions`, `_is_system`, `_expired`, `_complete`, `_jetstream_enabled`, `_limit_subs`, `_limit_data`, `_limit_payload`, `_limit_imports`, `_limit_exports`, `_limit_wildcards`, `_limit_conn`, `_limit_leaf` | `server_id`, `account_id`, `account_name` | one `/accountz?acc=` request **per account per scrape**; the limits are the JWT's (0 on a config-file account) |

### `-leafz` → `/leafz` and `-gatewayz` → `/gatewayz`

| series | labels |
|---|---|
| `gnatsd_leafz_conn_nodes_total` (always emitted; 0 with no leaf) | `server_id` |
| `gnatsd_leafz_info`, `_conn_rtt`, `_conn_in_msgs`, `_conn_out_msgs`, `_conn_in_bytes`, `_conn_out_bytes`, `_conn_subscriptions_total`, `_conn_subscriptions` (one per subject) | `server_id`, `account`, `account_id`, `ip`, `port`, `name` (+ `subscription`) |
| `gnatsd_gatewayz_outbound_gateway_configured`, `_conn_start_time_seconds`, `_conn_last_activity_seconds`, `_conn_uptime_seconds`, `_conn_idle_seconds`, `_conn_rtt`, `_conn_pending_bytes`, `_conn_in_msgs`, `_conn_out_msgs`, `_conn_in_bytes`, `_conn_out_bytes`, `_conn_subscriptions`; the same twelve as `_inbound_gateway_*` | per gateway; **nothing** is emitted on a server with no gateways |

### `-jsz=all|consumers|streams|accounts` → `/jsz` (33 series, all gauges)

`-jsz=all` and `consumers` request `/jsz?consumers=true&config=true&raft=true`; `streams` requests
`/jsz?streams=true` — **no consumer series, no `limit_*` series, and an empty `stream_raft_group`
label**; `accounts` requests `/jsz?accounts=true`. Any other value is refused (`invalid jsz filter`).

| series | field | scope · labels |
|---|---|---|
| `jetstream_server_jetstream_disabled`, `_max_memory`, `_max_storage`, `_total_streams`, `_total_consumers`, `_total_messages`, `_total_message_bytes` | `disabled`, `config.max_memory`, `config.max_storage`, `streams`, `consumers`, `messages`, `bytes` | per server · `server_id`, `server_name`, `cluster`, `domain`, `meta_leader`, `is_meta_leader` |
| `jetstream_account_max_memory`, `_max_storage`, `_memory_used`, `_storage_used` | `reserved_memory`, `reserved_store`, `memory`, `store` of the account detail | per account · + `account`, `account_name`, `account_id` — **`max_*` is the account's reservation**, `1.8446744073709552e+19` when unlimited |
| `jetstream_stream_total_messages`, `_total_bytes`, `_first_seq`, `_last_seq`, `_consumer_count`, `_subject_count` | `state.messages`, `.bytes`, `.first_seq`, `.last_seq`, `.consumer_count`, `.num_subjects` | per stream · + `stream_name`, `stream_leader`, `is_stream_leader`, `stream_raft_group` (+ `stream_meta_<k>` with `-jsz_stream_meta_keys`) |
| `jetstream_stream_limit_messages`, `_limit_bytes` | `config.max_msgs`, `config.max_bytes` | `-1` = unlimited; only with `config=true` (`all` / `consumers`) |
| `jetstream_stream_mirror_lag`, `_mirror_active_duration_ns` | `mirror.lag`, `mirror.active` | + `mirror_name`, `mirror_api`, `mirror_deliver`; `active` is ns since last activity, `-1` inactive — the RPO of [[mirrors-and-sources]] |
| `jetstream_stream_source_lag`, `_source_active_duration_ns` | `sources[].lag`, `.active` | + `source_name`, `source_api`, `source_deliver`, one sample per source |
| `jetstream_consumer_num_pending` | `num_pending` | **leader only** — 0 on replicas · + `consumer_name`, `consumer_leader`, `is_consumer_leader`, `consumer_desc` (+ `consumer_meta_<k>`) |
| `jetstream_consumer_num_ack_pending`, `_num_redelivered`, `_num_waiting` | `num_ack_pending`, `num_redelivered`, `num_waiting` | replicated; `num_redelivered` is the count of messages **currently** outstanding that have been delivered more than once, not a redelivery rate |
| `jetstream_consumer_delivered_consumer_seq`, `_delivered_stream_seq`, `_ack_floor_consumer_seq`, `_ack_floor_stream_seq` | `delivered.*`, `ack_floor.*` | replicated |
| `jetstream_consumer_last_delivery_seconds`, `_last_ack_seconds` | `ts − delivered.last_active`, `ts − ack_floor.last_active` | only when the timestamp exists — absent until the first delivery / the first ack |

A consumer series carries **seventeen labels** by default (six server, three account, four stream,
four consumer); on a large account that is the cardinality `-jsz=all` costs, and the reason
[[prometheus-nats-exporter]] recommends scoping it.

## Surveyor's series

Surveyor polls every server over the system account (`$SYS.REQ.SERVER.PING.STATSZ`, `JSZ`, `RAFTZ` —
[[system-subjects]]) and emits **105 series** with `--jsz all --accounts --raftz` at v0.9.11. The
families, with what the exporter lacks in bold (source: [[s-nats-surveyor-metrics-observed]]):

| family | series | labels |
|---|---|---|
| `nats_core_*` (23, per server) | `connection_count`, `total_connection_count`, `subs_count`, `slow_consumer_count`, `recv_msgs_count`, `recv_bytes`, `sent_msgs_count`, `sent_bytes`, `recv_from_client_msgs_total`, `recv_from_client_bytes_total`, `sent_to_client_msgs_total`, `sent_to_client_bytes_total`, `mem_bytes`, `cpu_percentage`, `core_count`, `gomaxprocs`, `go_memlimit_bytes`, **`rtt_nanoseconds`**, `start_time`, `uptime`, `route_count`, `gateway_count`, `active_account_count`; `info{server_version}` | `server_cluster`, `server_name`, `server_id` |
| `nats_core_route_*` (6) | **`sent_msg_count`, `sent_bytes`, `recv_msg_count`, `recv_bytes`, `pending_bytes`** per route | + `server_route_name`, `server_route_name_id` |
| `nats_core_account_*` (20, `--accounts`) | `conn_count`, `total_conn_count`, `leaf_count`, `sub_count`, `slow_consumer_count`, `msgs_recv`, `msgs_sent`, `bytes_recv`, `bytes_sent`, `count`, `jetstream_enabled`, **`jetstream_stream_count`, `jetstream_consumer_count`, `jetstream_replica_count`**, `jetstream_memory_used`, `_reserved`, `jetstream_storage_used`, `_reserved`, `jetstream_tiered_storage_used`, `_reserved` | + `account`, `account_name` |
| `nats_core_jetstream_*` (26, per server) | `enabled`, `info`, `accounts`, **`ha_assets`**, `api_requests`, `api_errors`, **`api_pending`**, `filestore_size_bytes`, `_used_bytes`, `_reserved_bytes`, `memstore_size_bytes`, `_used_bytes`, `_reserved_bytes`, `server_jetstream_disabled`, `server_max_memory`, `server_max_storage`, `server_total_streams`, **`server_total_stream_leaders`**, `server_total_consumers`, **`server_total_consumer_leaders`**, `server_total_messages`, `server_total_message_bytes`, `meta_snapshot_pending_entries`, `_pending_bytes`, `_last_duration_seconds`, `_last_timestamp_seconds` | `cluster_name`, `server_id`, `server_name` |
| `nats_core_jetstream_cluster_raft_group_*` (7, from the meta block of `STATSZ`) | `info`, `leader`, `size`, `replicas`, **`replica_peer_active`, `replica_peer_current`, `replica_peer_offline`** (from the leader only, one sample per peer) | + `peer`, `raft_group`, `jetstream_domain` |
| `nats_core_raftz_meta_*` (3, `--raftz`) | **`committed`, `applied`, `pindex`** of the meta group | `cluster_name`, `server_id`, `server_name` — **values shifted**: `cluster_name` holds the server id and `server_id` the cluster name at v0.9.11 |
| `nats_stream_*` (6) · `nats_consumer_*` (8) | `total_messages`, `total_bytes`, `first_seq`, `last_seq`, `consumer_count`, `subject_count` · `delivered_consumer_seq`, `delivered_stream_seq`, `ack_floor_consumer_seq`, `ack_floor_stream_seq`, `num_ack_pending`, `num_pending`, `num_redelivered`, `num_waiting` | `account`, `account_name`, `cluster_name`, `server_id`, `server_name`, **`stream`** (not `stream_name`), `stream_leader`, `raft_group`, `consumer_name`, `consumer_leader` — one sample per replica unless `--jsz-leaders-only` |
| the survey itself | `nats_up`, `nats_survey_surveyed_count`, `_expected_count`, `_duration_seconds`, `nats_jetstream_advisory_count`, `nats_latency_observations_count` | — |

Surveyor has no `/healthz`, no per-connection series and no `varz` config echoes; the exporter has
no per-route, no leader-count and no Raft-index series. Running both is not redundant.

## The series behind the alerts

[[advisories]] names four events to alert on first; gh#6182 asked for seven metrics and got no reply
(source: [[s-gh-6182-what-to-alert-on]]). The series that exist at 2.14.6 / v0.20.2 / v0.9.11, and
what has none:

| condition | exporter (default names) | surveyor | what has no series |
|---|---|---|---|
| **cluster or node down** | `gnatsd_healthz_status == 1`, `gnatsd_healthz_status_value{value="unreachable"}` | `nats_up == 0`; `nats_survey_surveyed_count < nats_survey_expected_count` | — |
| **quorum** | nothing — no `js-meta-only` collector | `nats_core_jetstream_cluster_raft_group_replica_peer_offline == 1`, `_replica_peer_current == 0`, `nats_core_jetstream_cluster_raft_group_leader` summing to 0 across the cluster | `STREAM.QUORUM_LOST` / `CONSUMER.QUORUM_LOST` are advisories only |
| **lag** | `jetstream_stream_mirror_lag`, `jetstream_stream_source_lag`; `gnatsd_varz_jetstream_meta_pending` (the 10,000-proposal warning of [[stream-has-high-message-lag]]) | `nats_core_jetstream_api_pending` | per-stream Raft lag (`/jsz?raft=1`'s `replicas[].lag`) — an array, not exported by either |
| **disk** | `jetstream_account_storage_used` against `jetstream_account_max_storage`; `gnatsd_varz_jetstream_stats_reserved_storage` against `gnatsd_varz_jetstream_config_max_storage` (the comparison `10047` makes, [[jetstream-out-of-disk]]) | `nats_core_jetstream_filestore_used_bytes` / `_reserved_bytes` / `_size_bytes` | `SERVER.OUT_OF_STORAGE` fires once as an advisory; the volume's free space is the node exporter's job |
| **consumer pending** | `jetstream_consumer_num_pending{is_consumer_leader="true"}`, `jetstream_consumer_num_ack_pending`, `jetstream_consumer_num_waiting == 0` (nobody pulling) | `nats_consumer_num_pending` with `--jsz-leaders-only` | — |
| **redeliveries** | `jetstream_consumer_num_redelivered` (outstanding, not a rate); `gnatsd_varz_slow_consumers`, `gnatsd_accstatz_slow_consumers`, `gnatsd_varz_stalled_clients` for core drops | `nats_core_slow_consumer_count`, `nats_core_account_slow_consumer_count` | **`MAX_DELIVERIES`** — the only notice of a dropped message ([[dead-letter-queue]]) — is an advisory with no series; ack/nak/term counts are the `$JS.EVENT.METRIC` events, not series |
| latency, throughput | `rate(gnatsd_varz_in_msgs[1m])`, `gnatsd_connz_rtt` per connection with `-connz_detailed` | `rate(nats_core_recv_msgs_count[1m])`, `nats_core_rtt_nanoseconds` | **no per-message latency**; service latency is a `$SYS` event ([[system-subjects]]) |

A threshold check that needs no Prometheus at all is `nats server check consumer --unprocessed-critical`
([[nats-cli]], source: [[s-docs-prometheus-and-dashboards]]).

## Counters are exact

`in_msgs`, `out_msgs`, `in_bytes` and `out_bytes` in `/varz`, `/connz` and `nats-top` are **counts,
not samples**: every inbound message adds one and its payload length to the parser's tally
(`client.go:4345–4346`), the tallies are added atomically to the connection, the account and the
server after each read buffer (`:1607–1633`), and `/varz` reads them with an atomic load
(`monitor.go:1900–1907`). Two refinements the public answer ("Yes that is correct", gh#2818, source:
[[s-gh-2818-counters-exact-or-sampled]]) does not give: the byte counters count **payload bytes**
(headers included, the protocol line and CR LF excluded), and they are **per server since start** —
"nats top is not cluster aware"; a cluster figure is a sum over every node's exporter (source:
[[s-nats-server-traffic-counters-and-ha-assets]]).

## `ha_assets` and `max_ha_assets`

`ha_assets` — in `/varz` → `jetstream.stats`, in `/jsz`, in `STATSZ`, as `gnatsd_varz_jetstream_stats_ha_assets`
and `nats_core_jetstream_ha_assets` — is **the number of Raft groups this server runs**
(`jetstream.go:2623`, `raft.go:798–802`): every R>1 stream and consumer it holds a replica of, **plus the
meta group** (in the run: 3 on n1 = meta + one R3 stream + one R3 consumer; the two R1 streams count
nowhere). `jetstream { limits { max_ha_assets } }` — "the maximum of Streams and Consumers that may have
more than 1 replica", no default — is enforced when a group would be created (`Maximum HA Assets limit
reached: N`, the caller gets `system limit reached`) and at placement, where a peer above it is
discarded and replicated streams prefer the peer with fewer assets (`jetstream_cluster.go:2953–2959`,
`8031–8035`, `8087–8088`; source: [[s-nats-server-traffic-counters-and-ha-assets]]). The maintainer's
operating figure: "In our global clusters we limit servers, at the moment, to 2k HA Assets. We have
customers that have higher and are ok" (gh#5128, source: [[s-gh-5128-ha-assets]]) — the sizing use of it
is on [[jetstream-sizing]] and [[jetstream-slows-as-consumers-grow]].

## What the docs say, and what they do not

- `learn/monitoring/prometheus-and-dashboards.md` says "the full set of metric names … is documented
  in Reference"; no page of the reference tree lists a series name, and `gnatsd_` — the exporter's
  default for every core series — appears nowhere in docs.nats.io (`inbox/docs-issues.md` #76).
- The same page's sample `nats_consumer_num_pending{account,stream_name,consumer_name} 20` shows three
  of the seventeen labels and never says the value is 0 off the consumer leader (#78).
- Surveyor's `--prefix` help, "Replace the default prefix for all the metrics", describes a flag that
  does nothing at v0.9.11 (#77).
- Two behaviours of the exporter itself, recorded on [[prometheus-nats-exporter]] rather than in the
  docs report: a start with no collector flag fails (`no Collectors specified`), and `-jsz=…` alone
  silently adds `varz` ("Defaulting to varz") — the test in `main.go:79–88` is inverted.

## How this was derived

- **Names, labels, types**: `collector/*.go`, `exporter/exporter.go` and `main.go` of
  `nats-io/prometheus-nats-exporter` at tag **v0.20.2**, quoted with line numbers in
  `raw/prometheus-nats-exporter-src/collector-v0.20.2.md`; surveyor's `cmd/root.go`,
  `surveyor/surveyor.go` and `surveyor/collector_statz.go` at **v0.9.11** from the Go module cache,
  quoted in the appendix of `raw/nats-surveyor-src/metrics-observed-v0.9.11.md`.
- **The series as produced**: `go install` of both tools at those tags (module versions confirmed with
  `go version -m`; the binaries print `0.0.0` because `go install` sets no version), run against
  `tools/lab/cluster.sh up 3` on nats-server v2.14.6 with the shape described on the summaries, one
  `curl` per configuration: ten exporter scrapes (`raw/prometheus-nats-exporter-src/metrics-observed-v0.20.2.md`,
  scripts `metrics-run.sh` / `metrics-run2.sh`) and three surveyor scrapes. Regenerate with:

  ```
  bash tools/lab/cluster.sh down --purge && bash tools/lab/cluster.sh up 3
  OUT=/tmp/m bash raw/prometheus-nats-exporter-src/metrics-run.sh
  OUT=/tmp/m bash raw/prometheus-nats-exporter-src/metrics-run2.sh
  ```

- **The server side** (counters, the leader-only `num_pending`, `ha_assets`): `server/client.go`,
  `monitor.go`, `consumer.go`, `jetstream.go`, `jetstream_cluster.go`, `raft.go`, `opts.go` at
  **v2.14.6**, `raw/nats-server-src/traffic-counters-and-ha-assets-v2.14.6.md`.
- **Arrival dates**: the release notes in `raw/release-notes/` through the four `s-relnotes-*`
  summaries; a field with no date is present at 2.14.6 and undated by the notes.

## Version notes

- **nats-server**: `slow_consumer_stats` in `/varz` 2.10.0 (#4330); `/raftz` 2.10.17 (#5530) — the
  endpoint surveyor's `--raftz` reads; `gomaxprocs` / `gomemlimit` in `/varz` and `STATSZ` 2.10.28
  (#6791); `/healthz?js-meta-only=true` 2.11.0 (#6649); meta snapshot statistics and leader counts
  2.11.11 / 2.12.2 (#7524) — surveyor's `server_total_stream_leaders` / `_consumer_leaders` and
  `meta_snapshot_*` need at least that; `in_client_*` / `out_client_*` 2.12.9 / 2.14.1 (#7851)
  (source: [[s-relnotes-2.10]], [[s-relnotes-2.11]], [[s-relnotes-2.12]], [[s-relnotes-2.14]]).
- **prometheus-nats-exporter v0.20.2** (2026-08-19) embeds nats-server v2.14.3 for its `/jsz` types;
  its `jsz` collector's `limit_*` series, `stream_raft_group` and the `is_*_leader` labels exist at
  this tag (their arrival is not dated by any source read here).
- **nats-surveyor v0.9.11** (2026-07-23): stream and consumer metrics "since v0.9.1" (its README);
  `--prefix` unimplemented; the `raftz` label shift.

## The services framework's counters are not here

Nothing in this table comes from a [[services-framework]] service. Its five per-endpoint counters —
`num_requests`, `num_errors`, `last_error`, `processing_time`, `average_processing_time` — live in
each instance and are readable only by asking `$SRV.STATS`, per instance, gathered by deadline. There
is no exporter collector for them and no Prometheus bridge in the NATS tree; `nats service stats
<name> --json` is the scrape surface, and summing across instance ids is the reader's job because the
server keeps no aggregate (source: [[s-docs-services-discovery-and-stats]]).

The `service_latency` series is the separate, server-side mechanism — see [[advisories]].


## Related

[[monitoring-endpoints]] · [[advisories]] · [[system-subjects]] · [[prometheus-nats-exporter]] ·
[[nats-surveyor]] · [[nats-top]] · [[nats-cli]] · [[slow-consumer-detected]] · [[consumer]] ·
[[worker-pool]] · [[jetstream-out-of-disk]] · [[stream-has-high-message-lag]] · [[jetstream-sizing]] ·
[[raft-in-nats]] · [[meta-layer]] · [[defaults-and-limits]]

## Sources

[[s-prometheus-nats-exporter-collector]] · [[s-prometheus-nats-exporter-metrics-observed]] ·
[[s-nats-surveyor-metrics-observed]] · [[s-nats-server-traffic-counters-and-ha-assets]] ·
[[s-gh-2818-counters-exact-or-sampled]] · [[s-gh-3857-consumer-pending-series]] ·
[[s-gh-6182-what-to-alert-on]] · [[s-gh-5128-ha-assets]] ·
[[s-exporter-issue-218-num-pending-differs-per-node]] · [[s-docs-prometheus-and-dashboards]] ·
[[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]] · [[s-docs-services-discovery-and-stats]]
