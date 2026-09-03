---
title: "gh#3857 — Consumer pending metrics in nats-surveyor or prometheus-nats-exporter?"
type: summary
area: [monitoring, jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/3857
source-path: raw/gh-discussions/gh-3857.md
author: "@Doslin (asker), @derekcollison"
date: 2023-02-08
version: ""               # no server version named; surveyor's JetStream metrics arrived in v0.9.1 per its README
tags: [num_pending, surveyor, exporter, consumer, unprocessed]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# gh#3857 — is the consumer's pending count a series anywhere?

The asker posts a screenshot of `nats consumer info` and asks what the pending figure means and whether
surveyor or the exporter export it. Q&A, **not answered** (no chosen answer), one upvote.

## Key claims

- The maintainer on the figure: **"That is the number of messages still to be delivered to the
  consumer, with consideration for any filter subject provided."** — the definition of `num_pending`
  (the CLI's *Unprocessed Messages*).
- On the tools, 2023-02-09: "We have updates to surveyor that add JetStream but not sure that metric is
  there" — and the thread ends there.

## Practical takeaways

The answer the thread never got, from the wiki's runs on 2026-09-03 ([[s-prometheus-nats-exporter-metrics-observed]],
[[s-nats-surveyor-metrics-observed]]): **both tools export it** — `jetstream_consumer_num_pending`
(exporter v0.20.2, `-jsz=all` or `-jsz=consumers`; `nats_consumer_num_pending` with `-prefix nats`) and
`nats_consumer_num_pending` (surveyor v0.9.11, `--jsz all` or `consumers`) — **and both read 0 on every
node but the consumer's leader**, because the server computes it on the leader only
([[s-nats-server-traffic-counters-and-ha-assets]]). Filter on `is_consumer_leader="true"` (exporter) or
scrape with `--jsz-leaders-only` (surveyor).

## Relevance to the wiki

Row 83. The series, its labels and the leader rule are on [[metrics]].

## Questions it answers

Q83 — with the wiki's runs supplying what the thread lacks.

## Pages touched

[[metrics]] · [[prometheus-nats-exporter]] · [[nats-surveyor]] · [[consumer]]
