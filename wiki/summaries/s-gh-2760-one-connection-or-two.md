---
title: "gh#2760 — one connection for subscribing and publishing, or two"
type: summary
area: [clients, core]
source-url: https://github.com/nats-io/nats-server/discussions/2760
source-path: raw/gh-discussions/gh-2760.md
author: "@dsidirop (question), @derekcollison (chosen answer)"
date: 2021-12-26
version: ""
article: "Q&A, one comment, chosen answer the same day"
tags: [connections, head-of-line-blocking, websocket, subscriptions, design]
aliases: [gh#2760]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# gh#2760 — one connection for subscribing and publishing, or two

A WebSocket client asks whether to keep two connections, one to subscribe and one to publish, "to
make the most out of them"; the maintainer answers in three sentences. Row 138's thread.

## Key claims

- The asker already holds the two costs: letting remote clients publish directly "mandates tremendous
  caution", and "having 2 connections instead of 1 per client will strain resources in the server so
  there needs to be good justification".
- The chosen answer (@derekcollison, 2021-12-26): "Similar to TCP, websockets can handle
  bi-directional activity and we recommend folks to start with one connection. Since it is a single
  connection there could be head of line blocking, mostly from the system to your app
  (subscriptions). So if you have multiple subscriptions and might encounter latency sensitive
  processing that could be affected by head of line blocking, then move subscriptions across multiple
  connections."

## Practical takeaways

- Start with one connection. The cost of one connection is head-of-line blocking on the *inbound*
  side — one socket, one read loop, every subscription's messages in one order — not on publishing.
- Split by **subscription**, and only when one subscription's processing is latency-sensitive and
  another's is heavy: the second connection carries the sensitive subscriptions.

## Notable quotes

- "we recommend folks to start with one connection" (the chosen answer).

## Relevance to the wiki

Row 138's answer, on [[core-nats-delivery]] (the *single connection is one FIFO* sentence) and
[[request-reply]] (the requester's inbox shares the connection's read loop).

## Questions it answers

138.

## Pages touched

[[core-nats-delivery]] · [[request-reply]]
