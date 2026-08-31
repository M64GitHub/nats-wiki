---
title: "docs.nats.io — Prometheus & dashboards"
type: summary
area: [monitoring, jetstream, deploy]
source-url: https://docs.nats.io/learn/monitoring/prometheus-and-dashboards.md
source-path: raw/nats-docs/learn/monitoring/prometheus-and-dashboards.md
author: NATS documentation (Synadia Communications, Inc.)
article: Prometheus & dashboards
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [prometheus, grafana, exporter, surveyor, healthz, nats-server-check, metrics]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Prometheus & dashboards

How the monitoring port becomes a time series, and the three traps in wiring it up. The only docs
page that states the exporter's real invocation and the difference between the exporter and
surveyor.

## Key claims

**The exporter converts JSON to time series and stores nothing.**

```
prometheus-nats-exporter -jsz=all -prefix nats -port 7777 http://localhost:8222
```

- It "runs *outside* NATS", scrapes a node's monitoring port (`:8222`) and serves its own
  `/metrics` on **`:7777`**.
- "The exporter holds no history of its own; it answers each scrape from a fresh read of the
  monitoring port."
- `-jsz` turns on the JetStream collector (streams and consumers).
- **Default JetStream metric prefix is `jetstream_`**; `-prefix nats` renames it to `nats_`, "the
  same rename the NATS Helm chart applies".

**The metric names follow the wire fields.** `num_pending` → `nats_consumer_num_pending`;
redeliveries → `nats_consumer_num_redelivered`; stream message count →
`nats_stream_total_messages`; in-flight → `nats_consumer_num_ack_pending`. Every series is labelled
`account`, `stream_name`, `consumer_name`:

```
nats_consumer_num_pending{account="ORDERS",stream_name="ORDERS",consumer_name="shipping"} 20
```

**Prometheus scrape target**, verbatim:

```yaml
scrape_configs:
  - job_name: nats
    scrape_interval: 15s
    static_configs:
      - targets: ["localhost:7777"]
```

**`nats server check` is the alerting side**, returning OK / WARNING / CRITICAL "in a format
Prometheus, Nagios, or a plain script can read":

```
nats server check consumer --stream ORDERS --consumer shipping --unprocessed-critical 100
nats server check consumer --stream ORDERS --consumer shipping \
  --unprocessed-critical 100 --redelivery-critical 10
```

**`nats-surveyor` is the cluster-wide alternative.** It "connects to the system account, polls every
server for its `Statz` (the same summary data `nats server report` reads), and exposes the combined
metrics on one `/metrics` endpoint". It **needs a system-account credential**, and is "an
alternative to running the exporter against one node at a time".

**Three pitfalls, stated as such:**

1. **"A node-local health check passes even with no quorum."**
   `/healthz?js-enabled-only=true` "asks only whether *this* node's JetStream subsystem is running.
   It returns `200` even when the cluster has lost the quorum that keeps the `ORDERS` stream
   writable". Pair it with `/healthz?js-meta-only=true`, "the one that turns 503 when the cluster
   loses quorum".
2. **"A check with no threshold never fires."** `nats server check consumer` has defaults, but
   "the defaults don't know your SLA … A silent check looks like coverage while providing none,
   which makes it worse than having no check."
3. **"The exporter keeps no time series."** Without Prometheus behind it you "gain a metrics format,
   not a record".

## Practical takeaways

- **Two `/healthz` queries, two questions.** Node-local liveness and cluster-meta health are
  different alerts; wiring only the first is the documented way to sleep through an outage.
- **`-prefix nats` is not cosmetic** — dashboards imported from the community (and anything built
  against a Helm-deployed cluster) expect `nats_`, so an exporter run without it produces panels
  that silently find no data.
- **Exporter per node, surveyor per deployment.** The exporter needs an HTTP monitoring port
  reachable per node; surveyor needs one system-account credential and discovers the rest.

## Notable quotes

> "A silent check looks like coverage while providing none, which makes it worse than having no
> check."

## Relevance to the wiki

The behaviour and flags behind [[prometheus-nats-exporter]] and [[nats-surveyor]], and the alerting
half of [[monitoring-endpoints]].

## Questions it answers

Q57 (what to alert on) — reinforces the answer already on [[monitoring-endpoints]] with the exporter
and check-command mechanics.

## Pages touched

[[prometheus-nats-exporter]] · [[nats-surveyor]] · [[nats-cli]] · [[monitoring-endpoints]] ·
[[nats-helm-charts]]
