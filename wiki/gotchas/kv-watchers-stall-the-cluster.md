---
title: "KV watchers pile up and the cluster stops recovering"
type: gotcha
area: [kv, jetstream, topology]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [kv, watch, ephemeral-consumers, consumer-churn, readloop, healthz, meta-layer, unresolved]
aliases: ["Consumer assignment not cleaned up retrying", "Readloop processing time", "too many KV watchers", "kv watcher misses updates", "1000 watchers"]
sources: [s-gh-5243-kv-watchers-at-scale, s-gh-6746-watch-many-keys, s-nats-server-jetstream-log-warnings, s-adr-8-key-value-store, s-synadia-jetstream-anti-patterns, s-docs-kv-watching]
created: 2026-08-31
updated: 2026-09-03
---

# KV watchers pile up and the cluster stops recovering

A thousand clients watching one key in a bucket that holds one 118-byte message, and a three-node
cluster pinned at its CPU limit that does not come back on its own.

> **Unresolved.** The public thread was never answered: a maintainer asked for the version and the
> stream report, got both, suggested a release candidate three months later, and the reporter's
> closing question — "Can you explain what is exactly causing this issue?" — has no reply. What
> follows is the symptom, what the log lines mean read from the server source, and the design change
> that removes the load. It is not a confirmed fix.

## Symptom

```
[WRN] Healthcheck failed: "JetStream consumer '$G > KV_wincloud-sdc-delta > h0mGFs2q' is not current"
[WRN] 40.0.156.123:50022 - cid:30807 - Readloop processing time: 2m11.969109716s
[WRN] Consumer assignment for '$G > KV_wincloud-sdc-delta > Vfwfb1rz' not cleaned up, retrying
[WRN] Consumer assignment for '$G > KV_wincloud-sdc-delta > ez6ULYpd' not cleaned up, retrying
[ERR] Error trying to connect to route (attempt 2): dial tcp 40.0.22.98:6222: i/o timeout
```

with all three pods at their 4-core limit, and a stream report showing the bucket is trivial:

```
│ KV_wincloud-sdc-delta   │ File │ │ 0 │ 1 │ 118 B │ 0 │ 0 │ nats-1* │
```

**One message. Zero consumers at the instant of the report.** Reproduced with the `nats` CLI and with
the Python SDK, on `2.10.12` (source: [[s-gh-5243-kv-watchers-at-scale]]).

## Why a small bucket produces this

A KV watch is not a subscription. It is an ephemeral [[ordered-consumer]] on the `KV_<bucket>` stream
— created, assigned through the meta layer, and torn down again (source: [[s-adr-8-key-value-store]]).
1000 watchers is 1000 consumer **assignments** proposed and 1000 deletions to land, on a bucket whose
data volume is irrelevant to the cost.

The `Consumer assignment for … not cleaned up, retrying` line
(`consumer.go:2322`, source: [[s-nats-server-jetstream-log-warnings]]) is the tell, and it points at
**deletion**, not creation: the meta layer cannot land the removal and keeps retrying. Consumer
**churn**, not consumer count, is the load — which is why `Consumers: 0` and a flood of per-consumer
warnings appear in the same minute.

`Readloop processing time: 2m11s` on a client connection is the server spending over two minutes
inside one connection's read loop — the same starvation shape as [[slow-consumer-detected]], seen from
the server side rather than the write side.

## Quick triage

```
nats stream report                       # is Consumers wildly unstable between runs?
nats consumer ls KV_<bucket>
curl -s localhost:8222/jsz?acc=<ACCOUNT>&consumers=1 | jq '.account_details[].stream_detail[].consumer_detail | length'
curl -s localhost:8222/healthz
```

Run `nats consumer ls` on the bucket's stream a few seconds apart. A list whose *membership* changes
every time — not its length — is churn.

## Causes, ranked

### 1. One watcher per client, or one watcher per key

The reported design: 1000 clients each watching the same key. Also common: one watcher per key inside
a single process, which [[s-gh-6746-watch-many-keys]] is someone asking how to avoid.

**The fix.** Collapse watchers:

- **Many keys, one watcher.** A watcher takes multiple **filter subjects**, so `foo`, `bar` and `baz`
  become one consumer rather than three. This needs nats-server **2.10+** and a client that exposes
  it (source: [[s-gh-6746-watch-many-keys]], [[key-value]]).
- **A wildcard instead of a list.** Filter-subject count is not free either: ~300 filters per consumer
  is where it starts to hurt (source: [[s-synadia-jetstream-anti-patterns]], see
  [[jetstream-slows-as-consumers-grow]]).
- **Fan out in your own process.** One watcher, one process, and distribute to the 1000 consumers over
  core NATS. A KV watch is an expensive per-client primitive and a cheap per-service one.

### 2. A connection spike, which produces the same thing

The reporter notes the same state "after a spike in connection requests to the server". Each
reconnecting client re-creates its watcher, so a mass reconnect is a mass consumer-create — a
thundering herd on the meta layer, from an event that has nothing to do with KV.

**Prevention.** Client-side reconnect jitter, and not opening a watcher per connection.

### 3. The meta layer is the bottleneck, and a route is failing

`Error trying to connect to route (attempt 2): … i/o timeout` in the same log means the cluster is also
struggling to keep routes up while saturated. Once the meta group cannot make progress, consumer
assignments neither land nor clear, and the state is self-sustaining — which is what "unrecoverable"
means here. See [[raft-in-nats]].

**How to confirm.** `nats server report jetstream` for the meta leader, and whether it is stable.

### 4. The version

@derekcollison suggested `v2.10.17-RC.5` and the reporter never posted a result. There have been many
releases since 2.10.12; an upgrade is a reasonable first move and is untested for this symptom.

## What this page cannot tell you

- **Why** the cluster does not recover once it enters this state. Nobody answered.
- Whether any current release fixes it.
- Whether a KV watcher can **miss** an update. This page was written where the wiki previously
  wanted `kv-watcher-misses-updates`; a search of `nats-io/nats-server` discussions found nobody
  publicly reporting a missed KV update, so that page has no source and was not written. The
  mechanism [[ordered-consumer]] describes — a consumer that detects a gap and rebuilds itself — is a
  candidate cause and remains unverified.

## The cheaper thing the watcher was probably standing in for

Two shapes on this page's causes are really the same design mistake: **a watch used where a read
would do.** The docs are explicit that a watch "is live state, not a point read… Don't open a watch,
read the first entry, and close it to fake a point read; you pay for a consumer and a snapshot to get
one value get would have handed you directly" (source: [[s-docs-kv-watching]]). A KV get is a
[[direct-get]] — one request, one reply, no consumer.

The second cheap substitution is the **filter**. A watch's key filter narrows both the snapshot and
the live stream, so a filtered watch is genuinely a smaller consumer, not a client-side filter over
everything. But it only works if the keys were named for it: `*` matches a **whole token**, so
`widget-*` over flat hyphenated keys matches nothing at all, while `widget.*` over dotted keys
matches. That naming decision is made once, before the first put ([[key-value]]).

## Prevention

- Treat a KV watch as a **consumer**, and count them the way you would count consumers.
  [[jetstream-slows-as-consumers-grow]] has the thresholds.
- One watcher per service, not per client. Redistribute over core NATS.
- Alert on consumer churn: `nats consumer ls` membership over time, or the consumer count in
  `/jsz?consumers=1`.
- Watch `/healthz` for `JetStream consumer … is not current` — the Kubernetes probe fails on it, and
  that is the first outward sign.

## Explained by

[[key-value]] for what a watch is built from, [[ordered-consumer]] for what one costs.

## To verify

- **`since:` is deliberately absent.** No release body from v2.10.0 to v2.14.6 dates KV watchers; the one body that names watchers is v2.11.5 (#7003, a log-noise fix). The symptom's version range is unknown beyond the thread's own 2.10.12.

## Related

[[key-value]] · [[ordered-consumer]] · [[jetstream-slows-as-consumers-grow]] · [[consumer]] ·
[[raft-in-nats]] · [[slow-consumer-detected]] · [[monitoring-endpoints]] · [[nats-helm-charts]] ·
[[stream-has-high-message-lag]]

## Sources

- [[s-gh-5243-kv-watchers-at-scale]] — the thread, its logs and its stream report. Unanswered.
- [[s-gh-6746-watch-many-keys]] — watching several keys on one watcher.
- [[s-nats-server-jetstream-log-warnings]] — the `not cleaned up, retrying` format string at v2.14.6.
- [[s-adr-8-key-value-store]]
- [[s-docs-kv-watching]] — what a watch delivers, and the two cheaper
  substitutions (a get, and a filter the keys were named for). — a watch is an ordered consumer.
- [[s-synadia-jetstream-anti-patterns]] — the consumer and filter-subject thresholds.
