---
title: "docs.nats.io — System reference: advisories and metrics (6 pages)"
type: summary
area: [monitoring, core]
source-url: https://docs.nats.io/reference/system/advisory.md
source-path: raw/nats-docs/reference/system/advisory.md
author: NATS documentation (Synadia Communications, Inc.) — generated from the event JSON schemas
article: "reference/system/advisory.md and advisory/{client-connect,client-disconnect,account-connections}.md; reference/system/metric.md and metric/service-latency.md"
date: 2026-08-31          # the pages are undated; this is the fetch date
version: "2.14"
tags: [system-account, "$SYS", events, service-latency, generated]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# docs.nats.io — System reference: advisories and metrics

The six pages of the system tree that describe what the server *publishes* rather than what it
answers, read for phase E step 1 and checked against `events.go` and `accounts.go` at v2.14.6
([[s-nats-server-system-subjects]]) and on the wire ([[s-nats-server-system-subjects-observed]]).

## Key claims

- `advisory.md` names three events: **client connect** on `$SYS.ACCOUNT.{account}.CONNECT`, **client
  disconnect** on `$SYS.ACCOUNT.{account}.DISCONNECT` ("Includes disconnect reason and statistics"),
  and **account connections** on **`$SYS.ACCOUNT.{account}.CONNECTIONS`** — "Published when account
  connection limits are reached … Alerts when approaching or exceeding limits". It gives a common
  envelope (`type`, `id`, `timestamp`, `server {name, host, id, cluster}`, `data`) and says a client
  "must have permissions to subscribe to `$SYS.>`".
- `client-connect.md`: type `io.nats.server.advisory.v1.client_connect`, fields `id`, `timestamp`,
  `server`, `client`. `client-disconnect.md`: `…client_disconnect`, plus `sent` ("Data sent by the
  client"), `received` ("Data sent to the client"), `reason`. `account-connections.md`: type
  `…account_connections`, described on its own page as "**Regular advisory published with account
  states**", fields `acc`, `conns`, `leafnodes`, `total_conns`, `sent`, `received`,
  `slow_consumers` (`name` and `num_subscriptions`, which the server sends, are absent).
- `metric.md`: metrics "are published as events" on `$SYS.SERVER.METRIC.>`, service latency on
  **`$SYS.SERVER.METRIC.SERVICE.LATENCY`**. `service-latency.md`: type
  `io.nats.server.metric.v1.service_latency`; `status` `200` / `400` ("no reply subject") / `408`
  ("requester lost interest before request completed") / `503` / `504`; **`error`** ("A description
  of the status code when not 200"); `requestor`, `responder`, `header` ("When header based latency
  is enabled, the headers that triggered the event"), `start`, `service`, `system`, `total` — all
  nanoseconds.

## What the server does instead

- The account-connections event is on `$SYS.ACCOUNT.<acc>.SERVER.CONNS` (and the compatibility
  `$SYS.SERVER.ACCOUNT.<acc>.CONNS`), never `CONNECTIONS`; it is sent on every change **and as a 30 s
  heartbeat** while the account has connections — the schema page's "Regular advisory" is right,
  the overview's "when limits are reached" is not (docs issue #66).
- Service latency is published on the subject the export's `latency { subject }` names, in the
  exporting account (`accounts.go:1496–1500`); `$SYS.SERVER.METRIC.>` occurs nowhere in the server.
  The `error` field is tagged `description` (docs issue #67).
- The events' `data` is not nested: `client`, `sent`, `received`, `reason` and the `AccountStat`
  fields sit at the top level beside `server`, as the subpages (not the overview's envelope) show.

## Practical takeaways

- Subscribe to `$SYS.ACCOUNT.*.SERVER.CONNS` for a per-account, per-server heartbeat with connection
  counts; the old `$SYS.SERVER.ACCOUNT.*.CONNS` still works on 2.14.6.
- Latency events go where the *exporter* pointed them; a `$SYS.>` subscription never sees them.

## Notable quotes

- "Regular advisory published with account states" — `account-connections.md`.
- "Published when account connection limits are reached" — `advisory.md`, the same event.

## Relevance to the wiki

Docs issues #66 and #67; the corrected *System events* section of [[advisories]]; the events table
of [[system-subjects]]. Completes the docs coverage of `reference/system/` with
[[s-docs-system-monitor-reference]].

## Questions it answers

Row 82 (the connect/disconnect bodies), row 162.

## Pages touched

[[system-subjects]] · [[advisories]]
