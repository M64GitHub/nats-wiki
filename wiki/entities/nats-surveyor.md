---
title: nats-surveyor
type: entity
kind: tool
area: [monitoring, topology, jetstream]
verified-against: nats-surveyor v0.9.11
verified-on: 2026-09-03
tags: [tool, surveyor, monitoring, system-account, statz, raftz, prometheus]
aliases: [nats-surveyor, surveyor, "nats-io/nats-surveyor"]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-prometheus-and-dashboards, s-nats-server-system-subjects, s-nats-surveyor-metrics-observed, s-prometheus-nats-exporter-collector, s-gh-3857-consumer-pending-series, s-exporter-issue-218-num-pending-differs-per-node]
created: 2026-08-31
updated: 2026-09-03
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
- **`--jsz-leaders-only` keeps one sample per asset instead of one per replica** — three to one for
  an R3 consumer, and the R1 assets unchanged (439 → 411 samples on the lab shape) — which is where the
  authoritative numbers are anyway: `num_pending` is 0 on every replica but the leader (source:
  [[s-nats-surveyor-metrics-observed]]).

## Cheat sheet

```
nats-surveyor -s nats://n1-east:4222 --creds ./sys.creds -c 3
nats-surveyor -s nats://n1-east:4222 --creds ./sys.creds -c -1 --server-discovery-timeout 2s
nats-surveyor … --jsz all --jsz-leaders-only --jsz-limit 1024
nats-surveyor … --jsz-filter stream_total_messages,consumer_num_pending
nats-surveyor … --raftz                 # metalayer Raft group metrics
nats-surveyor … --accounts              # per-account metrics (watch cardinality)
nats-surveyor … --gatewayz              # gateway metrics
nats-surveyor … --port 7777             # --prefix is accepted and ignored at v0.9.11 (see below)
nats-surveyor … --log-level debug
```

Every flag has an environment variable: `NATS_SURVEYOR_SERVERS`, `NATS_SURVEYOR_CREDS`,
`NATS_SURVEYOR_JSZ`, and so on — which is how it is configured in Kubernetes.

## The surface it reads

Surveyor's system-account credentials buy it the request family on [[system-subjects]] —
`$SYS.REQ.SERVER.PING.<Z>`, one reply per server, including the three names an HTTP scraper can never
reach (`STATSZ`, `IDZ`, `PROFILEZ`) and the account-scoped `$SYS.REQ.ACCOUNT.<acc>.<Z>` forms — which
is the structural reason it can survey a whole topology from one connection while
[[prometheus-nats-exporter]] needs one process per server's HTTP port (source:
[[s-nats-server-system-subjects]]).


## What bites you

Run at v0.9.11 against a 2.14.6 lab cluster on 2026-09-03, with the source lines from the module cache
(source: [[s-nats-surveyor-metrics-observed]]):

- **`--prefix` does nothing.** The flag is parsed and stored (`cmd/root.go:238`, `:333`) into a field
  declared `Prefix string // TODO` (`surveyor/surveyor.go:82`) that nothing reads; every name is built
  with the literal `nats` namespace. `--prefix x` produced 102 `nats_*` series and no `x_*`. Its help
  text is `inbox/docs-issues.md` #77. Dashboards use `nats_core_*`, `nats_stream_*`,
  `nats_consumer_*` as they are — the same JetStream names the exporter produces under `-prefix nats`,
  which is the one place the two tools agree ([[s-prometheus-nats-exporter-collector]]).
- **One sample per replica, and `num_pending` is 0 off the leader.** `nats_consumer_num_pending` read
  20 on the consumer's leader and 0 on both followers; `num_ack_pending` and `num_redelivered` agreed on
  all three. There is **no `is_consumer_leader` label** — compare `server_name` with `consumer_leader`,
  or pass `--jsz-leaders-only`, which keeps one sample per asset (three → one for R3, R1 unchanged).
  The exporter's form of the same finding is issue #218
  ([[s-exporter-issue-218-num-pending-differs-per-node]]); the thread that asked whether surveyor has
  the series was never answered ([[s-gh-3857-consumer-pending-series]]).
- **The labels are not the exporter's.** Streams are `stream`, not `stream_name`; the cluster is
  `cluster_name` on JetStream series and `server_cluster` on core ones; `server_id` is always the NKey
  id. A dashboard written for one tool does not query the other.
- **The three `--raftz` series carry shifted labels** at v0.9.11: `nats_core_raftz_meta_committed` /
  `_applied` / `_pindex` print `cluster_name="<server id>"` and `server_id="<cluster>"` — the
  descriptors are declared with `server_id, server_name, cluster_name` (`collector_statz.go:953`) and
  filled with values in the order cluster, name, id (`:356–358`, `:2163–2169`). Read them by
  `server_name`.
- **`nats_up` and the survey counters are the health of the survey**: `nats_survey_surveyed_count`
  below `nats_survey_expected_count` means a server did not answer `PING.STATSZ` in `--timeout` (3 s),
  and `nats_up 0` means no connection at all — with, the README says, no other series.
- **What it has that the exporter lacks** — the reason to run both: per-route traffic and
  `pending_bytes`, per-account JetStream reservations and tiers, `ha_assets`, stream and consumer
  **leader counts** per server, the meta group's Raft indices, API pending, CPU and RTT per server.
  What it lacks: `/healthz`, per-connection series, the `/varz` config echoes. The full list is on
  [[metrics]].


## Related

[[prometheus-nats-exporter]] · [[monitoring-endpoints]] · [[raft-in-nats]] · [[nats-helm-charts]] ·
[[synadia-products]] · [[nats-cli]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-prometheus-and-dashboards]] · [[s-nats-server-system-subjects]] · [[s-nats-surveyor-metrics-observed]] · [[s-prometheus-nats-exporter-collector]] · [[s-gh-3857-consumer-pending-series]] · [[s-exporter-issue-218-num-pending-differs-per-node]]
