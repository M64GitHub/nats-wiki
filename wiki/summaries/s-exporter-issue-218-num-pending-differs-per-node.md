---
title: "prometheus-nats-exporter issue #218 — NATS cluster has different values of the same metric"
type: summary
area: [monitoring, jetstream]
source-url: https://github.com/nats-io/prometheus-nats-exporter/issues/218
source-path: raw/gh-issues/exporter-issue-218.md
author: "@andreyreshetnikov-zh (reporter), @jlange-koch, @niklasmtj"
date: 2023-04-11
version: ""               # exporter 0.9.1–0.11.0, server unstated (2023); the wiki reproduces it with v0.20.2 on 2.14.6
tags: [num_pending, is_consumer_leader, exporter, consumer, replicas, alerting]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# exporter issue #218 — `nats_consumer_num_pending` is 3 / 0 / 3 across the pods

An exporter per pod on a three-node Helm cluster, R3 stream, and one consumer's
`nats_consumer_num_pending` reads `3`, `0`, `3` on the three pods (later `0 / 8 / 0`), as does
`nats_consumer_delivered_consumer_seq`. **Open since 2023-04-11, six comments, no maintainer reply.**

## Key claims

- Two other users report the same with `jetstream_consumer_num_pending` (exporter 0.9.1 and 0.11.0).
- The reporter's own investigation: restarting the exporter or the pod changes nothing — "apparently,
  the error is not with the exporter, as if the nats server displays another metric value … it looks
  like consumer replicas don't replicate these metrics from the consumer_leader"; the difference "is
  always on consumer_leader side"; `nats consumer info` "is always given by the consumer leader".
- **The workaround that closes it for them (2023-07-12)**: "the nats pod, which is consumer_leader at
  the moment, always shows the correct value for pending messages and for ack pending messages. I added
  the label `is_consumer_leader="true"` to Grafana dashboard and it solved the problem" — and for alerts:

  ```
  nats_consumer_num_pending{env="stage", is_consumer_leader="true"} > 0
  ```

- A `!= 0` filter is rejected as a workaround: replicas can also show non-zero while the leader
  correctly shows 0.

## Practical takeaways

- Reproduced on 2.14.6 with exporter v0.20.2 and surveyor v0.9.11
  ([[s-prometheus-nats-exporter-metrics-observed]], [[s-nats-surveyor-metrics-observed]]): `num_pending`
  20 on the leader, 0 on both followers. The cause is in the server, not the exporter:
  `streamNumPending` returns 0 unless this server is the consumer's leader
  ([[s-nats-server-traffic-counters-and-ha-assets]]).
- One refinement to the reporter's 2023 statement: on 2.14.6 **`num_ack_pending` and `num_redelivered`
  are replicated** (the followers report them from the replicated state — 10 / 10 / 10 in the run);
  only `num_pending` and the delivery timestamps are leader-only.

## Relevance to the wiki

The public form of the leader rule on [[metrics]]; row 165 of the question bank.

## Questions it answers

Q165; the practical half of Q83.

## Pages touched

[[metrics]] · [[prometheus-nats-exporter]] · [[consumer]] · [[nats-surveyor]]
