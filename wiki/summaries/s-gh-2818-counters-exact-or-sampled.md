---
title: "gh#2818 — Are the in/out byte and message counters exact, or approximations?"
type: summary
area: [monitoring, core]
source-url: https://github.com/nats-io/nats-server/discussions/2818
source-path: raw/gh-discussions/gh-2818.md
author: "@dsidirop (asker), @derekcollison (chosen answer), @ripienaar"
date: 2022-01-25
version: ""               # the thread names no server version (2.7 era); the wiki checks the claim at v2.14.6
tags: [in_msgs, out_msgs, in_bytes, out_bytes, nats-top, varz, counters]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# gh#2818 — are the traffic counters exact?

A one-question thread: does the data usage `nats-server` reports, and `nats-top` displays, account
for every message and byte, or is it sampled? Q&A, answered the same day, one upvote.

## Key claims

- The asker, from "a quick look in the source-code", believes the counters "account for every single
  byte and message that goes through NATS" and wants to be "100% certain".
- **The maintainer: "Yes that is correct."** (chosen answer, 2022-01-25).
- @ripienaar adds the qualification that matters for alerting: **"it's per server though — nats top is
  not cluster aware."** For an aggregate view of a cluster: "Use something like the prometheus exporter
  and gather data from all your servers."

## Practical takeaways

- The `in_msgs` / `out_msgs` / `in_bytes` / `out_bytes` values in `/varz`, `/connz` and `nats-top` are
  counts, not estimates. On 2.14.6 the wiki confirms this from the source: every inbound message adds
  one to the message counter and its payload length to the byte counter, and `/varz` reads them with an
  atomic load ([[s-nats-server-traffic-counters-and-ha-assets]]) — with one refinement the thread does
  not give: the byte counters count **payload bytes**, not wire bytes.
- They are **per server, since start**. A cluster total is a sum across every node's exporter.

## Relevance to the wiki

Row 139 of the question bank. The counters' series names and types are on [[metrics]].

## Questions it answers

Q139 — yes, exact, per server.

## Pages touched

[[metrics]] · [[nats-top]] · [[monitoring-endpoints]]
