---
title: "prometheus-nats-exporter v0.20.2 — the collector source: how every series is named and what it reads"
type: summary
area: [monitoring, jetstream, core]
source-url: https://github.com/nats-io/prometheus-nats-exporter/tree/v0.20.2/collector
source-path: raw/prometheus-nats-exporter-src/collector-v0.20.2.md
author: The NATS Authors (Apache-2.0); extract by this wiki, 2026-09-03
date: 2026-08-19          # the v0.20.2 release date
version: "v0.20.2"        # the exporter's tag; it embeds nats-server v2.14.3 for its /jsz types
tags: [exporter, prometheus, gnatsd, jetstream_, prefix, collector, jsz, varz, connz, healthz]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# prometheus-nats-exporter v0.20.2 — the collector source

The `collector/` package, `exporter/exporter.go` and `main.go` at tag v0.20.2, read for the rule that
turns an endpoint field into a series name and for the explicit series of each hand-written collector.
The scrapes that confirm it are [[s-prometheus-nats-exporter-metrics-observed]].

## Key claims

1. **Two namespaces, both replaced by one flag.** `CoreSystem = "gnatsd"` and
   `JetStreamSystem = "jetstream"` (`collector.go:34–35`; the comment: "use gnatsd for backward
   compatibility. Changing would require users to change their dashboards"). `-prefix` overrides *both*
   (`getSystem`, `collector.go:456–461`), so `-prefix nats` yields `nats_varz_*` **and**
   `nats_consumer_*`. Without it the core series are `gnatsd_*`, which the docs never mention.
2. **The generic rule** (`varz`, `routez`, `subsz`): `<namespace>_<endpoint>_<field>` with nested objects
   flattened by `_` (`fqName`, `objectToMetrics`, `collector.go:322–405`). Every number becomes a
   **gauge** labelled `server_id`; strings are exported only for eight keys — `server_id`,
   `server_name`, `version`, `domain`, `leader`, `name`, `start`, `config_load_time` — as a "label gauge"
   (`…{value="2.14.6"} 1`) or, when they parse as RFC 3339, as epoch **milliseconds**; **booleans and
   arrays are never exported** (the `default` case), nor are the nine `skipFQN` names (`leaf`,
   `trusted_operators_claim`, `cluster_*`, `gateway_*`). The metric list is rebuilt when a response
   grows a new key (`makeRequests`, `:204–227`).
3. **The default `server_id` label is the monitoring URL** (`main.go:36–58` — `parseServerIDAndURL`
   builds `scheme://host`); `-use_internal_server_id` / `-use_internal_server_name` read `/varz`'s
   `server_id` / `server_name` instead (`:177–191`).
4. **The JetStream collector** (`jsz.go`) declares 33 series: 7 `server_*`, 4 `account_*`, 8 `stream_*`,
   10 `consumer_*`, `stream_source_lag` / `_active_duration_ns`, `stream_mirror_lag` /
   `_active_duration_ns` (`:130–367`). Labels (`:92–128`): six server labels on everything (`server_id`,
   `server_name`, `cluster`, `domain`, `meta_leader`, `is_meta_leader`), then `account`, `account_name`,
   `account_id`; streams add `stream_name`, `stream_leader`, `is_stream_leader`, `stream_raft_group`;
   consumers add `consumer_name`, `consumer_leader`, `is_consumer_leader`, `consumer_desc`;
   `-jsz_stream_meta_keys` / `-jsz_consumer_meta_keys` add `stream_meta_<k>` / `consumer_meta_<k>`.
   `Describe` omits the four `account_*` and the two `ack_floor_*` series (`:381–419`); they are still
   emitted, because the registry is not pedantic (`exporter.go:380–381`).
5. **What `-jsz` sends** (`jsz.go:427–436`): `all` and `consumer(s)` →
   `/jsz?consumers=true&config=true&raft=true`; `stream(s)` → `/jsz?streams=true` — no config, so no
   `limit_bytes` / `limit_messages`, and no raft, so `stream_raft_group=""`; `account(s)` →
   `/jsz?accounts=true`. A second request to `/varz` fetches the server name. Any other value is
   refused: `invalid jsz filter` (`exporter.go:231–236`).
6. **`num_pending` and the other consumer series are copied straight from the consumer info fields**
   (`jsz.go:625–640`); `last_delivery_seconds` / `last_ack_seconds` are `ts − delivered.last_active` /
   `ts − ack_floor.last_active`, present only when those timestamps exist.
7. **`connz`** (`connz.go`): ten summary series labelled `server_id` — the sums over the `connections`
   array of a `/connz` request **without `limit`** (`:224`), so over the server's default page of 1024;
   `-connz_detailed` adds `?auth=true` and one sample per connection with fourteen labels (`cid`,
   `kind`, `type`, `ip`, `port`, `name`, `name_tag`, `account`, `account_id` = the same value, `lang`,
   `version`, `tls_version`, `tls_cipher_suite`). **The only counters in the whole exporter are the four
   `in_msgs` / `in_bytes` / `out_msgs` / `out_bytes` here** (`:261–264`, `:280–283`); `rtt` is
   microseconds, `uptime` and `idle` milliseconds parsed from the server's `y/d/h/m/s` strings
   (`:351–365`, `:424–453`).
8. **`healthz`** (`healthz.go`): three flags, three endpoints — `healthz`, `healthz?js-enabled-only=true`,
   `healthz?js-server-only=true` — and **no `js-meta-only`**. `<ns>_healthz_status` is **0 for `ok`, 1
   otherwise** ("keep the existing metric behaving the same", `:95–100`); `<ns>_healthz_status_value{value=…}`
   is 1 when ok, 0 otherwise, `value="unreachable"` when the request failed (`:103–122`).
9. **`accstatz`** reads `/accstatz?unused=1` and emits nine series per account, including
   `slow_consumers`, `sent_*` and `received_*` (`accstatz.go:46`, `:93–136`); **`accountz`** makes one
   `/accountz?acc=<id>` request **per account per scrape** and emits fifteen (seven states, eight JWT
   limits) (`accountz.go:81–101`, `:133–210`); **`leafz`** emits `conn_nodes_total` always and eight
   per leaf; **`gatewayz`** twelve each for outbound and inbound gateways and nothing when there are
   none.
10. **The flag test is inverted** (`main.go:79–88`): `metricsSpecified` ends in `|| opts.GetJszFilter == ""`,
    so a bare invocation is "specified" and fails with `no Collectors specified`, while `-jsz=…` alone
    is "not specified" and gets `varz` added with the message `No metrics specified.  Defaulting to
    varz.` The README promises neither.
11. The Go runtime and process collectors are registered on the same registry (`exporter.go:290–303`),
    which is where the `go_*` and `process_*` series come from; the retry interval for an unreachable
    monitor URL is 30 s (`-ri`); more than one URL is accepted with a warning that it "violates
    Prometheus guidelines" (`main.go:162–169`).

## Practical takeaways

- Read the exporter's names as `<prefix>_<endpoint>_<field>` for the core and `<prefix>_<server|account|stream|consumer>_<field>`
  for JetStream; the field is the wire field of the endpoint, unchanged.
- Anything in `/varz` that is a boolean, an array or a string outside the eight keys — `auth_required`,
  `tls_required`, `connect_urls`, `git_commit`, `store_dir`, the per-route list of `/routez` — **has no
  series**. Per-route RTT and pending bytes are a surveyor feature, not an exporter one.
- `gnatsd_healthz_status == 1` is the unhealthy condition; do not alert on `== 0`.

## Relevance to the wiki

The naming half of [[metrics]]; the *What bites you* section of [[prometheus-nats-exporter]].

## Questions it answers

Q83, Q84, Q85 (the exporter side). Q129 in part.

## Pages touched

[[metrics]] · [[prometheus-nats-exporter]] · [[monitoring-endpoints]] · [[nats-surveyor]]
