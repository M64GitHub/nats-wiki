---
title: "gh#5243 — 1000 nats cli watchers leads to unrecoverable state of servers"
type: summary
area: [kv, jetstream, topology]
source-url: https://github.com/nats-io/nats-server/discussions/5243
source-path: raw/gh-discussions/gh-5243.md
author: "@vineethm13 (asking), @derekcollison (maintainer, responding)"
article: "1000 nats cli watchers leads to unrecoverable state of servers."
date: 2024-03-25
version: "2.10.12"
tags: [kv, watch, ephemeral-consumers, consumer-churn, readloop, healthz, unresolved]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#5243 — A thousand watchers on one key, and the cluster stops recovering

**Unresolved.** Asked 2024-03-25 against **2.10.12**, three maintainer replies, a request to retry on
a release candidate, and a final "Can you explain what is exactly causing this issue?" from the
reporter that nobody answered. Recorded as unanswered, which is the honest state of it.

## Key claims

**The setup.** 1000 clients watching **one key in one bucket** with the `nats` CLI, against a 3-node
Kubernetes cluster. `nats stream report` shows the bucket is trivial:

```
│ KV_wincloud-sdc-delta   │ File    │           │ 0         │ 1        │ 118 B │ 0    │ 0       │ nats-1*  │
```

One message, 118 bytes, and **`Consumers: 0`** at the moment the report was taken.

**The symptom.** All three pods pinned at their 4-core CPU limit, and the log dominated by three
lines:

```
[WRN] Healthcheck failed: "JetStream consumer '$G > KV_wincloud-sdc-delta > h0mGFs2q' is not current"
[WRN] 40.0.156.123:50022 - cid:30807 - Readloop processing time: 2m11.969109716s
[WRN] Consumer assignment for '$G > KV_wincloud-sdc-delta > Vfwfb1rz' not cleaned up, retrying
[ERR] Error trying to connect to route (attempt 2): dial tcp 40.0.22.98:6222: i/o timeout
```

The reporter's own framing — "**unrecoverable state**" — is that the cluster does not come back on its
own, and that the same thing happens "after a spike in connection requests to the server".

**The maintainer exchange.** @derekcollison asked for the version and `stream info` (both given),
looped in @wallyqs and @caleblloyd for the Kubernetes deployment detail (never supplied), and 3 months
later suggested `v2.10.17-RC.5`. The reporter's reply is the last word in the thread:

> "Sure, Can you explain what is exactly causing this issue? I have tried with the python sdk watch as
> well, issue is seen there too."

**The two clients rule out a client bug.** The same behaviour with the `nats` CLI and with the Python
SDK points at the server-side cost of the watchers, not at one client's implementation.

## Practical takeaways

- 1000 watchers is 1000 **ephemeral consumers** created and torn down on the `KV_<bucket>` stream, each
  with its own assignment to propose through the meta layer. `Consumers: 0` in the stream report
  alongside a flood of per-consumer log lines is churn, not steady state.
- `Consumer assignment for '<account> > <stream> > <name>' not cleaned up, retrying` is the meta
  layer failing to land the *deletion* of an assignment — the tell that consumer churn, not consumer
  count, is the load (format string verified at v2.14.6 in
  [[s-nats-server-jetstream-log-warnings]]).
- `Readloop processing time: 2m11s` on a client connection is the server spending minutes inside one
  connection's read loop — the same starvation shape as a slow consumer, seen from the other side.
- The reporter's design — one watcher per client on the same key — is the one to change: a KV watch is
  not a cheap subscription, and [[jetstream-slows-as-consumers-grow]] gives the thresholds.

## Relevance to the wiki

The symptom page is [[kv-watchers-stall-the-cluster]]. It is the page the wanted link
`kv-watcher-misses-updates` becomes: searching `nats-io/nats-server` discussions found nobody
publicly reporting a KV watcher *missing* an update, and this — watchers overwhelming the meta
layer — is the KV-watcher failure people do report.

## Questions it answers

- The new bank row for KV watchers at scale. It does **not** answer why, and the page says so.

## Pages touched

[[kv-watchers-stall-the-cluster]] · [[key-value]] · [[ordered-consumer]] ·
[[jetstream-slows-as-consumers-grow]] · [[monitoring-endpoints]]
