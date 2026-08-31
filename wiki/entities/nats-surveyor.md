---
title: nats-surveyor
type: entity
kind: tool
area: [monitoring, topology, jetstream]
verified-against: nats-surveyor v0.9.11
verified-on: 2026-08-31
tags: [tool, surveyor, monitoring, system-account, statz, raftz, prometheus]
aliases: [nats-surveyor, surveyor, "nats-io/nats-surveyor"]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-prometheus-and-dashboards]
created: 2026-08-31
updated: 2026-08-31
---

# nats-surveyor

**Cluster-wide monitoring from one process.** Instead of scraping each server's HTTP port, surveyor
connects to the **system account** and polls every server for its `Statz`, then exposes the whole
deployment as one Prometheus endpoint (source: [[s-docs-prometheus-and-dashboards]]).

## Where it fits

The other half of the monitoring choice: [[prometheus-nats-exporter]] per node over HTTP, or
surveyor once over NATS itself. The exporter's README names surveyor as "an alternative approach that
uses a System account instead of HTTP monitoring endpoints".

## Facts

| | |
|---|---|
| repo | `nats-io/nats-surveyor` |
| latest release | **v0.9.11**, 2026-07-23 |
| licence | Apache-2.0 |
| requires | **system account credentials** — "System accounts must be enabled to use surveyor" |
| listens on | `:7777` by default (`-p`), same as the exporter |
| polls | `$SYS.REQ` (prefix overridable with `--sys-req-prefix`) |
| config | flags, `NATS_SURVEYOR_*` environment variables, or `./nats-surveyor.yaml` |
| deployed by | the `surveyor` chart in [[nats-helm-charts]] |

## What an operator needs to know

- **It needs a system-account credential, and that is the whole security story.** Four ways to supply
  it: `--creds` (chained JWT + nkey seed), `--nkey`, `--jwt` + `--seed`, or `--user` / `--password`.
  Whoever runs surveyor can read every account's activity, so it belongs with your other privileged
  workloads.
- **It sees servers, not ports.** `--count` sets how many servers to expect; `-1` plus
  `--server-discovery-timeout` discovers them. A count that never resolves is the usual first symptom
  of a credential or connectivity problem.
- **It can export `/raftz`.** `--raftz` exports "metalayer Raft group metrics", which is the one
  monitoring surface [[raft-in-nats]] and [[monitoring-endpoints]] both name as a gap. It is the
  easiest public path to Raft-level metrics today.
- **Per-account metrics are opt-in and cardinality-sensitive.** `--accounts` and, worse,
  `--accounts-detailed` multiply series by account count; `--jsz-limit` (default 1024) and
  `--jsz-filter` exist because unbounded JetStream metrics are how you flatten Prometheus.
- **`--jsz-leaders-only` halves the noise** on an R3 cluster by fetching stream and consumer metrics
  only from leaders, which is where the authoritative numbers are anyway.

## Cheat sheet

```
nats-surveyor -s nats://n1-east:4222 --creds ./sys.creds -c 3
nats-surveyor -s nats://n1-east:4222 --creds ./sys.creds -c -1 --server-discovery-timeout 2s
nats-surveyor … --jsz all --jsz-leaders-only --jsz-limit 1024
nats-surveyor … --jsz-filter stream_total_messages,consumer_num_pending
nats-surveyor … --raftz                 # metalayer Raft group metrics
nats-surveyor … --accounts              # per-account metrics (watch cardinality)
nats-surveyor … --gatewayz              # gateway metrics
nats-surveyor … --prefix nats --port 7777
nats-surveyor … --log-level debug
```

Every flag has an environment variable: `NATS_SURVEYOR_SERVERS`, `NATS_SURVEYOR_CREDS`,
`NATS_SURVEYOR_JSZ`, and so on — which is how it is configured in Kubernetes.

## Related

[[prometheus-nats-exporter]] · [[monitoring-endpoints]] · [[raft-in-nats]] · [[nats-helm-charts]] ·
[[synadia-products]] · [[nats-cli]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-prometheus-and-dashboards]]
