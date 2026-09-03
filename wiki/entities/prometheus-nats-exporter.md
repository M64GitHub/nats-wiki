---
title: prometheus-nats-exporter
type: entity
kind: tool
area: [monitoring, jetstream]
verified-against: prometheus-nats-exporter v0.20.2
verified-on: 2026-09-03
tags: [tool, prometheus, exporter, metrics, jsz, varz, healthz]
aliases: [prometheus-nats-exporter, nats exporter, "nats-io/prometheus-nats-exporter"]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-prometheus-and-dashboards, s-nats-server-system-subjects, s-prometheus-nats-exporter-collector, s-prometheus-nats-exporter-metrics-observed, s-exporter-issue-218-num-pending-differs-per-node, s-gh-3857-consumer-pending-series]
created: 2026-08-31
updated: 2026-09-03
---

# prometheus-nats-exporter

**The thing that turns the monitoring port into Prometheus metrics.** It scrapes the endpoints you
enable on one server and re-exposes them, in Prometheus format, on its own port. It stores nothing
(source: [[s-docs-prometheus-and-dashboards]]).

## Where it fits

One exporter per server, in front of [[monitoring-endpoints]]. The cluster-wide alternative that
polls through the system account instead is [[nats-surveyor]] — the exporter's own README points at
it by name.

## Facts

| | |
|---|---|
| repo | `nats-io/prometheus-nats-exporter` |
| latest release | **v0.20.2**, 2026-08-19 |
| licence | Apache-2.0 |
| image | `natsio/prometheus-nats-exporter` |
| listens on | **`:7777`** by default, path **`/metrics`** |
| scrapes | the endpoints you switch on: `varz`, `connz`, `subz`, `routez`, `gatewayz`, `leafz`, `healthz`, `accountz`, `accstatz`, `jsz` |
| metric prefixes | **`gnatsd_`** for every core collector and **`jetstream_`** for `/jsz` by default; `-prefix nats` renames **both** to `nats_` |
| retry interval | `-ri`, 30 seconds by default |

## What an operator needs to know

- **`-prefix nats` is effectively mandatory.** The defaults are `gnatsd_` for the core series and
  `jetstream_` for JetStream (`collector.go:34–35` at v0.20.2, kept "for backward compatibility"); the
  NATS Helm chart renames both to `nats_`, and community Grafana dashboards are written against
  `nats_`. An exporter run without it produces dashboards that silently show nothing — and the docs
  never mention the `gnatsd_` half (`inbox/docs-issues.md` #76; source: [[s-prometheus-nats-exporter-collector]]).
- **It holds no history.** "The exporter holds no history of its own; it answers each scrape from a
  fresh read of the monitoring port." Without Prometheus behind it you have a metrics *format*, not
  monitoring.
- **Nothing is collected unless you ask for it.** Every collector is a flag. A blank invocation does
  not start at all (`no Collectors specified`, see *What bites you*); `-jsz=all` is what makes stream
  and consumer state visible.
- **`-jsz=all` is expensive on a large account.** The unscoped `/jsz` read is the same one that times
  out when asked for everything (see [[monitoring-endpoints]]); `-jsz streams` or `-jsz consumers`
  narrows it.
- **The scrape can be authenticated and encrypted**: `-http_user` / `-http_pass` (bcrypt supported)
  for basic auth, `-tlscert` / `-tlskey` / `-tlscacert` to serve HTTPS.

## Cheat sheet

```
# the documented invocation: JetStream collector on, nats_ prefix, :7777 -> :8222
prometheus-nats-exporter -jsz=all -prefix nats -port 7777 http://localhost:8222

prometheus-nats-exporter -varz -connz -routez -healthz http://localhost:8222
prometheus-nats-exporter -jsz streams -prefix nats http://localhost:8222
prometheus-nats-exporter -connz_detailed http://localhost:8222     # per-client metrics
prometheus-nats-exporter -healthz_js_server_only http://localhost:8222
prometheus-nats-exporter -http_user scrape -http_pass '…' -port 7777 http://localhost:8222
docker run natsio/prometheus-nats-exporter:latest
```

```yaml
# prometheus.yml
scrape_configs:
  - job_name: nats
    scrape_interval: 15s
    static_configs:
      - targets: ["localhost:7777"]
```

**The series it produces** — 167 with every collector on, 28 of them JetStream — are tabled by
collector on [[metrics]], each with the endpoint field it is read from, its labels and its type. The
rule: `<namespace>_<endpoint>_<field>` for the core collectors and `<namespace>_<server|account|stream|consumer>_<field>`
for `/jsz`, the field being the wire field unchanged — `num_pending` becomes `jetstream_consumer_num_pending`,
or `nats_consumer_num_pending` under `-prefix nats`. A consumer series carries seventeen labels, not
the three the docs' sample shows (source: [[s-prometheus-nats-exporter-collector]],
[[s-prometheus-nats-exporter-metrics-observed]]):

```
jetstream_consumer_num_pending{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="true",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 20
```

## The surface it reads

The exporter scrapes the HTTP monitoring port only — the fifteen paths `server.go` registers, tabled
on [[monitoring-endpoints]]. It therefore never sees the request-only names (`STATSZ`, `IDZ`,
`PROFILEZ`) nor any `$SYS` event (`CONNS`, `STATSZ` heartbeats, `CLIENT.AUTH.ERR`), which need a
system-account connection; that side is [[system-subjects]] and, as a tool, [[nats-surveyor]]
(source: [[s-nats-server-system-subjects]]).


## What bites you

Read from the v0.20.2 source and reproduced on a 2.14.6 lab cluster on 2026-09-03 (source:
[[s-prometheus-nats-exporter-collector]], [[s-prometheus-nats-exporter-metrics-observed]]):

- **It sees one node, and an R1 asset lives on one node.** `/jsz` lists the streams and consumers the
  scraped server holds a replica of: node n1 reported `total_streams 1` and no mirror or source
  series while n2 reported 3 with `stream_mirror_lag` and `stream_source_lag`. One exporter per node
  is the minimum, and a dashboard has to sum or `max` across them.
- **`num_pending` is 0 on every replica but the consumer's leader** — the server computes it on the
  leader only (`consumer.go:5628–5632`); `num_ack_pending`, `num_redelivered` and the sequences are
  replicated and agree everywhere. Alert on `jetstream_consumer_num_pending{is_consumer_leader="true"}`.
  This is exporter issue #218, open and unanswered since 2023, where the reporter found the same
  label ([[s-exporter-issue-218-num-pending-differs-per-node]]); the docs' `nats_consumer_num_pending`
  sample never mentions it (`inbox/docs-issues.md` #78). The thread that asked whether the series exists
  at all was never answered either ([[s-gh-3857-consumer-pending-series]]).
- **`gnatsd_healthz_status` is 0 when healthy** and 1 otherwise, kept inverted "the same" for
  compatibility; `gnatsd_healthz_status_value{value="ok"} 1` is the readable form, and
  `{value="unreachable"}` the only series left when the port is down.
- **There is no `js-meta-only` collector.** `-healthz`, `-healthz_js_enabled_only` and
  `-healthz_js_server_only` are the three; the one `/healthz` form that turns 503 on quorum loss cannot
  be scraped by this exporter — quorum comes from [[nats-surveyor]]'s Raft series or the advisories.
- **No collector flag is fatal, and `-jsz` alone is not what it looks like.** A bare invocation exits
  with `[FTL] error starting the exporter: no Collectors specified`; `-jsz=all` (or any `-jsz`) with no
  other flag prints `No metrics specified.  Defaulting to varz.` and adds the 83 `varz` series unasked.
  The test in `main.go:79–88` is inverted (`opts.GetJszFilter == ""`). Always name every collector.
- **The `server_id` label is the monitoring URL** — `server_id="http://127.0.0.1:8222"` — unless
  `-use_internal_server_id` or `-use_internal_server_name` is given; the JetStream series carry
  `server_name` beside it regardless.
- **`-jsz=streams` drops more than consumers**: its `/jsz?streams=true` request carries no config and
  no raft block, so `stream_limit_bytes` / `stream_limit_messages` vanish and `stream_raft_group=""`.
- **`connz` sums one page.** The summary series add up the `connections` array of a `/connz` request
  sent without `limit` — 1024 entries — so on a busier server `gnatsd_connz_total` exceeds
  `gnatsd_connz_num_connections` and the sums are partial. In `-connz_detailed`, `account` is empty for
  clients in `$G` (the server omits it for the global account; `name_tag` carries the name).
- **`-accountz` is one HTTP request per account per scrape**, after the account list.
- **Almost everything is a gauge** — 135 of 139 core series, `gnatsd_varz_in_msgs` included; the four
  `gnatsd_connz_in_*` / `out_*` are the only counters. `rate()` still works on a monotonic gauge.
- **Booleans, arrays and most strings have no series**: no `auth_required`, no `connect_urls`, no
  per-route `rtt` or `pending_bytes` (the `routes[]` array is dropped; surveyor exports them).


## Related

[[nats-surveyor]] · [[monitoring-endpoints]] · [[nats-cli]] · [[nats-helm-charts]] ·
[[jetstream-slows-as-consumers-grow]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-prometheus-and-dashboards]] · [[s-nats-server-system-subjects]] · [[s-prometheus-nats-exporter-collector]] · [[s-prometheus-nats-exporter-metrics-observed]] · [[s-exporter-issue-218-num-pending-differs-per-node]] · [[s-gh-3857-consumer-pending-series]]
