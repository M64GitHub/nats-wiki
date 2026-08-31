---
title: "docs.nats.io — Sizing & resources"
type: summary
area: [deploy, jetstream]
source-url: https://docs.nats.io/learn/deployment/sizing-and-resources.md
source-path: raw/nats-docs/learn/deployment/sizing-and-resources.md
author: NATS documentation (Synadia Communications, Inc.)
article: Sizing & resources
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [sizing, max_file_store, max_memory_store, account-limits, file-descriptors]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Sizing & resources

The deployment chapter's baseline: the four resources a node spends, the JetStream storage
defaults, and how R3 replication counts against an account's storage ceiling.

## Key claims

**The four resources a node spends**

- **CPU** — core NATS routing is cheap; **TLS handshakes and JetStream replication** are where
  cycles go. There is no hard CPU limit to set, so the rule is headroom: **overprovision CPU by
  20–30% above steady state** so a node has cycles spare for a rebalance when a peer leaves.
- **Memory** — connections, subscriptions, and (for memory-storage streams) message data. A
  file-storage stream's messages live on disk, not in RAM. The docs budget a light client service
  at roughly **128 MiB**, and say a few hundred connections fit comfortably in a few hundred
  megabytes.
- **Disk** — holds file-storage streams. **The resource most likely to run out.**
- **File descriptors** — connections, routes and streams each consume FDs. **JetStream spends
  roughly two FDs per stream.** The default per-process limit is plenty on a small cluster and not
  on a large one; the docs' hardened service unit raises it to `LimitNOFILE=800000`.

**The JetStream storage defaults**

- **`max_memory_store` defaults to 75% of system RAM** (capped by `GOMEMLIMIT` if set), falling
  back to **256 MB** only when the server cannot read system memory.
- **`max_file_store` defaults to 75% of the disk space actually available under `store_dir`**,
  falling back to **1 TB** only when the platform cannot report disk size (Windows and a few
  others, or a failed `statfs`). On a Linux container with a 10 GiB volume the file-storage default
  is therefore **about 7.5 GiB, not 1 TB**.
- The container hazard is therefore **not** the default — it is setting `max_file_store` *larger*
  than the volume, or running on a **shared or thin-provisioned** volume where "available" disk
  overstates what the stream may safely use. Either way the node accepts writes it cannot
  ultimately store and the publish that crosses the real boundary fails.
- **The Helm chart already defaults `max_file_store` to the PVC size**, so on Kubernetes the pin is
  usually set for you.

```
jetstream {
  store_dir:      "/var/lib/nats/jetstream"
  max_memory_store: 256MB
  max_file_store:   10GB
}
```

**Account limits and how replication counts**

- Server config sizes the *node*; **account limits** size the *tenant*: `MaxMemory`, `MaxStore`,
  `MaxStreams`, `MaxConsumers`. The server enforces them **no matter how much disk the node has**.
- **On an un-tiered account an R3 stream counts as `replicas × bytes` against `MaxStore`.** A
  10 GiB stream at R3 spends **30 GiB** of the account's storage limit. Forget the multiplier and
  the third replica fails to place when the account hits its ceiling.
- **On a tiered account replication is baked into the tier**: the bytes reported are the *usable*
  bytes, so a 10 GiB tier holds a 10 GiB R3 stream.
- `nats account info` reports the live ceilings as `Memory`, `Storage`, `Streams`, `Consumers`.

**Connection, subscription and payload limits**

- **`max_connections` default 64K (65,536)**, reloadable; overflow disconnects immediately.
- **`max_subscriptions`** caps subscriptions per connection; **default unlimited**.
- **`max_payload` caps a single message at 1 MB by default**, and **must stay `≤ max_pending`**.
- **Keep `max_pending` at `≥ 10× peak message size`** so a burst of large messages cannot stall a
  connection.

## Pitfalls the page names

- **`max_file_store` beyond the real disk** — the failure is a publish error mid-stream, not a
  startup warning. Set it to the volume size and watch the device with `df -h`; do not trust the
  config number over what the device reports.
- **`max_payload` larger than `max_pending`** — **the server refuses to start.** Do not raise
  `max_payload` in isolation.
- **File-descriptor exhaustion on a big cluster** — about two FDs per stream, plus routes and
  gossip. The symptom is **connection refusals that look like a network fault**. Raise the limit
  (`ulimit -n 800000`) before the process starts.
- **JWT account limits change only when the account JWT does.** Operator-mode accounts enforce
  limits through the account JWT the resolver holds, **not** through server config: raising
  `MaxStore` or `MaxStreams` means editing and pushing the JWT, and **a server reload or restart
  will not move them**. Keep server versions aligned across a rolling upgrade so every node reads
  the same JWT limit fields — tiered R1/R3 limits need servers new enough to understand them.

## Commands the page uses

```
nats account info --server tls://nats.acme.internal:4222 --creds /etc/nats/creds/order-svc.creds
nats server info n1-east --server tls://nats.acme.internal:4222 --creds /etc/nats/creds/sys.creds
df -h
```

`nats server info` is a **system-account** request — authenticate with the system account's creds,
not an application user's.

## Relevance to the wiki

The backbone of [[jetstream-sizing]]: the only public source read so far that states the JetStream
storage defaults precisely (75% of RAM / 75% of available disk, with 256 MB / 1 TB as *fallbacks*,
which is widely misquoted) and the `replicas × bytes` account rule that makes R3 cost three times
the account quota.

## Questions it answers

Q3 (what a stream costs in resources and how to run JetStream resource-effectively), Q65 in part
(the Helm chart defaults `max_file_store` to the PVC size). Q1 only partially — it gives disk and
RAM but **no IOPS guidance and no per-message overhead figure**.

## Pages touched

[[jetstream-sizing]] · [[replicas]] · [[stream]]
