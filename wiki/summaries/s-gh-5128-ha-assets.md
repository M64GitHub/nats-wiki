---
title: "gh#5128 — How many streams and consumers can a cluster hold; what is an HA asset?"
type: summary
area: [jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/discussions/5128
source-path: raw/gh-discussions/gh-5128.md
author: "@suchen-sci (asker), @derekcollison (chosen answer), @nickchomey"
date: 2024-02-26
version: ""               # no version named; the limit and the counter are checked at v2.14.6
tags: [ha_assets, max_ha_assets, sizing, consumers, streams, limits]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# gh#5128 — "we generally focus on HA Assets"

Asked for a general estimate — 10, 100, 1,000, 10,000 — of the streams a 3- or 5-node cluster can hold
and the consumers per stream. Q&A, answered the same day by the maintainer, three upvotes.

## Key claims

- **The unit is the HA asset, "or replicated JetStream assets"**: "In our global clusters we limit
  servers, at the moment, to **2k HA Assets**. We have customers that have higher and are ok."
- Streams: "use muxed streams and have consumers filter out what they need, or R1 mirrors that do the
  same."
- Consumers "are varied. There are heavy, R3/R5 variants, but can also be pretty light. In general if
  the consumer is simply inheriting the R3 from the parent stream, we expect these to be limited." Above
  100k: "feel free to reach out … even higher numbers are supported today with custom solutions."
- "When they are all active its mostly a hardware problem, however if the mix has idle, or low volume
  streams we can improve there."
- A follow-up (100k browser clients): use **R1, possibly memory-based consumers the client recreates on
  demand**, with "a single muxed KV that stores the sequences for the 100k consumers that is an R3", the
  stored sequence becoming `OptStartingSeq` when the consumer is recreated.

## Practical takeaways

- The number to watch is per server, not per cluster: on 2.14.6 `ha_assets` in `/varz` → `jetstream.stats`,
  in `/jsz` and in `STATSZ` is the count of Raft nodes the server runs — every R>1 stream and consumer it
  holds a replica of, **plus the meta group** — and `jetstream { limits { max_ha_assets } }` refuses new
  groups above it and excludes the server from placement ([[s-nats-server-traffic-counters-and-ha-assets]]).
  The exporter carries it as `gnatsd_varz_jetstream_stats_ha_assets`, surveyor as
  `nats_core_jetstream_ha_assets` ([[metrics]]).
- "2k per server" is the maintainer's operating figure for Synadia's clusters, not a server limit; the
  server ships with no default `max_ha_assets`.

## Relevance to the wiki

Row 153, and the *what runs out first* question of [[jetstream-sizing]].

## Questions it answers

Q153. Reinforces Q6.

## Pages touched

[[metrics]] · [[jetstream-sizing]] · [[jetstream-slows-as-consumers-grow]] · [[stream-placement]] · [[config-keys]]
