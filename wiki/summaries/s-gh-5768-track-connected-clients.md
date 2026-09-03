---
title: "gh#5768 — How can I track connected clients if my system account misses a connection event?"
type: summary
area: [monitoring, core]
source-url: https://github.com/nats-io/nats-server/discussions/5768
source-path: raw/gh-discussions/gh-5768.md
author: "@brettinternet (asker, who also gave the chosen answer)"
date: 2024-08-08
version: ""               # the thread names no server version
tags: [system-account, connz, connect-events, iot]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# gh#5768 — tracking connected clients when a `CONNECT` event was missed

An IoT prototype watches `$SYS.ACCOUNT.*.CONNECT` and `.DISCONNECT` to show which devices are
online, and wants a way to re-read the current set after its own restart "if my server misses an
event during redeployments". Q&A, answered by the asker the same day; one reply; the two follow-up
questions were never answered in the thread.

## Key claims

- The asker's answer: request **`$SYS.REQ.SERVER.<server ID>.CONNZ`** from the system account, with
  `client.ConnectedServerId()` as the id, and page it with a body of `{"offset": 0, "limit": 1}` —
  "the request data matching the monitoring query params for pagination".
- Two questions left open: how to paginate (answered by the asker's own reply), and whether the
  per-server subject "represents metrics for the entire cluster" — it does not; `<id>.CONNZ` is one
  server, `$SYS.REQ.SERVER.PING.CONNZ` fans out to every server and returns one reply each
  ([[s-nats-server-system-subjects]], `events.go:1343–1352`).

## What the server adds

- Every account with a connection also publishes `$SYS.ACCOUNT.<acc>.SERVER.CONNS` **every 30 s**
  with `conns`, `leafnodes` and `total_conns` per server — a heartbeat that covers a missed event
  without a request at all ([[s-nats-server-system-subjects-observed]] §3).

## Practical takeaways

- On startup: `PING.CONNZ` with `--replies` equal to the server count (or `nats server request
  connections`), paged with `offset` / `limit`; then trust the events and the 30 s `CONNS` heartbeat.

## Notable quotes

- "if my server misses an event during redeployments, I'd like to be able to query the NATS server
  for currently connected clients on startup"

## Relevance to the wiki

The public form of the reconcile-after-a-miss question; answered by the request table and the
events table of [[system-subjects]].

## Questions it answers

Row 163.

## Pages touched

[[system-subjects]]
