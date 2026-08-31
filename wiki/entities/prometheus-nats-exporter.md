---
title: prometheus-nats-exporter
type: entity
kind: tool
area: [monitoring, jetstream]
verified-against: prometheus-nats-exporter v0.20.2
verified-on: 2026-08-31
tags: [tool, prometheus, exporter, metrics, jsz, varz, healthz]
aliases: [prometheus-nats-exporter, nats exporter, "nats-io/prometheus-nats-exporter"]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-prometheus-and-dashboards]
created: 2026-08-31
updated: 2026-08-31
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
| JetStream metric prefix | **`jetstream_`** by default; `-prefix nats` renames to `nats_` |
| retry interval | `-ri`, 30 seconds by default |

## What an operator needs to know

- **`-prefix nats` is effectively mandatory.** The default JetStream prefix is `jetstream_`, but the
  NATS Helm chart renames metrics to `nats_`, and community Grafana dashboards are written against
  `nats_`. An exporter run without it produces dashboards that silently show nothing.
- **It holds no history.** "The exporter holds no history of its own; it answers each scrape from a
  fresh read of the monitoring port." Without Prometheus behind it you have a metrics *format*, not
  monitoring.
- **Nothing is collected unless you ask for it.** Every collector is a flag. A blank invocation
  exports almost nothing; `-jsz=all` is what makes stream and consumer state visible.
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

**Series it produces, with their labels** (`account`, `stream_name`, `consumer_name`):

```
nats_consumer_num_pending{account="ORDERS",stream_name="ORDERS",consumer_name="shipping"} 20
nats_consumer_num_ack_pending{…} 5
nats_consumer_num_redelivered{…} 3
nats_stream_total_messages{account="ORDERS",stream_name="ORDERS"} 1000
```

The names follow the wire fields of `/jsz` — `num_pending` becomes `nats_consumer_num_pending`.

## Related

[[nats-surveyor]] · [[monitoring-endpoints]] · [[nats-cli]] · [[nats-helm-charts]] ·
[[jetstream-slows-as-consumers-grow]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-prometheus-and-dashboards]]
