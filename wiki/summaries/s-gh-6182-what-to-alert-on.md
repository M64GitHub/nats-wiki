---
title: "gh#6182 — Which exporter metrics for cluster-down, memory, store, drops, latency, throughput?"
type: summary
area: [monitoring, jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/discussions/6182
source-path: raw/gh-discussions/gh-6182.md
author: "@mohamedsaleem18 (asker)"
date: 2024-11-26
version: "2.10.19"       # the asker's cluster; no answer names a version
tags: [alerting, exporter, prometheus, openshift, monitoring]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# gh#6182 — the alert list nobody answered

A three-server 2.10.19 JetStream cluster on OpenShift; the asker wants "the corresponding Prometheus
metrics from the NATS exporter" for seven alerts. Q&A, **zero replies**, two upvotes — the shape of the
question is exactly the one an operator holds, and it is the public form of question-bank rows 57
and 129.

## Key claims

The seven alert targets, verbatim: "NATS cluster down · Memory usage · JetStream store usage · High
message drop rates · Increased latency · Decreased throughput · Number of connections to a stream and
latency". Nothing else is in the thread.

## Practical takeaways

The mapping the thread lacks, from the exporter and surveyor runs on 2.14.6
([[s-prometheus-nats-exporter-metrics-observed]], [[s-nats-surveyor-metrics-observed]]) — full table on
[[metrics]]:

| asked for | series (exporter v0.20.2 default names / surveyor v0.9.11) |
|---|---|
| cluster down | `gnatsd_healthz_status` (0 = ok) and `_status_value{value="unreachable"}` per node; surveyor's `nats_up` and `nats_survey_surveyed_count` vs `_expected_count` for the whole cluster |
| memory | `gnatsd_varz_mem`; `jetstream_account_memory_used` vs `jetstream_server_max_memory` |
| JetStream store | `jetstream_account_storage_used` vs `jetstream_server_max_storage`; `gnatsd_varz_jetstream_stats_storage` and `_reserved_storage` |
| drops | there is no drop counter for JetStream; `gnatsd_varz_slow_consumers`, `gnatsd_varz_stalled_clients`, `jetstream_consumer_num_redelivered`; the max-deliveries advisory has **no series** |
| latency | **no per-message series**; `gnatsd_connz_rtt` per connection (`-connz_detailed`), service-latency events over `$SYS` |
| throughput | `rate()` over `gnatsd_varz_in_msgs` / `out_msgs` (exact counters, exported as gauges) |
| connections to a stream | no such series; the nearest are `jetstream_stream_consumer_count` and `jetstream_consumer_num_waiting` |

## Relevance to the wiki

Rows 57 and 129.

## Questions it answers

Q57, Q129 — answered on [[metrics]], not in the thread.

## Pages touched

[[metrics]] · [[advisories]] · [[monitoring-endpoints]]
