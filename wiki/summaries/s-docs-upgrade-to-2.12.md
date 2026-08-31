---
title: "docs.nats.io — Upgrade to NATS 2.12"
type: summary
area: [deploy, jetstream, topology]
source-url: https://docs.nats.io/release-notes/upgrade-to-2.12.md
source-path: raw/nats-docs/release-notes/upgrade-to-2.12.md
author: NATS documentation (Synadia Communications, Inc.)
article: Upgrade to NATS 2.12
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.12"
tags: [upgrade, 2.12, strict-mode, elastic-pointers, offline-assets]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Upgrade to NATS 2.12

The upgrade guide from 2.11.x.

## Key claims — features

**Streams**

- **Atomic batch publish** — `AllowAtomicPublish` atomically publishes N messages into a stream,
  replicated or not, with per-message consistency checks before committing (ADR-50).
- **Distributed Counter CRDT** — `AllowMsgCounter` gives increment/decrement counter semantics on a
  stream; counter streams can be mirrored or aggregated (ADR-49).
- **Delayed Message Scheduling** — `AllowMsgSchedules` schedules messages for delayed publishing
  (ADR-51).

**Consumers**

- **`prioritized` pull consumer policy** — *"In addition to the consumer policies like overflow or
  client pinning, a new `prioritized` policy has been added."* It lets a consumer receive messages
  sooner instead of delaying failover, at the cost of potentially flip-flopping work between
  clients (ADR-42).

**Operations**

- **`server_metadata`** — like `server_tags` but a map of string keys and values describing the
  server.
- **Promoting mirrors** — a mirroring stream can be **promoted to primary**, "enabling new disaster
  recovery methodology". The current primary should be **deleted or have its configured subjects
  removed before promoting**, then the promoted mirror is configured to listen on those subjects.
- **Exponential backoff on route and gateway connections** — `connect_backoff`; if `true`, starts
  at **1 second up to 30 seconds**. Slower reconnection, but "significantly reduces the amount of
  DNS queries and general connection attempts during server restarts or outages".
- **Offline assets** — when downgrading, the server recognises that new features were used and puts
  the stream and/or consumer into an **unsupported/offline mode** (ADR-44).
- **Stream/consumer scale-up and reset disk/state protection** — better protection against leader
  elections based on empty state, and more reliable replicated in-memory streams. "Now all but one
  server can be restarted and the in-memory stream's data can reliably be caught back up. However,
  during such a scenario **all servers involved with replication of that stream will need to be
  available, not just what's needed for quorum**."

## Key claims — improvements

- **Async stream flushing** — replicated streams flush to the underlying store asynchronously, "a
  significant improvement in performance". Writes are **still persisted synchronously in the Raft
  log before committing**, so there is no consistency downside.
- **Elastic pointers in the filestore** — file-based streams use elastic pointers for write-through
  caches, so caches can be **evicted early to avoid out-of-memory conditions**.
- **Cipher suites from `crypto/tls`** — new suites added automatically; **insecure suites disabled
  by default**, re-enabled with `allow_insecure_cipher_suites`.
- **System events for `$G`** — the global account now produces connect and disconnect events too.
- **`GOMAXPROCS` and `GOMEMLIMIT` in server stats** — the effective Go limits are now reported
  alongside CPU and memory usage.
- **New subject transforms `partition(n)` and `random(n)`** — convenience forms that work on the
  whole subject, alongside the existing `partition(n, …)` on token indices.
- **Account name and user in logging** — connection-related log lines (max connections,
  authentication errors) now include the account name and user; connection-closed logging includes
  the remote server name.
- **`isolate_leafnode_interest`** — avoids propagating east-west interest between leaf nodes that
  do not need to reach each other, replacing the workaround of giving them the same cluster name.
- **`disabled: true` on a leafnode remote via config reload** — false→true disconnects a solicited
  leafnode and stops it reconnecting; true→false solicits it again.

## Upgrade considerations

### Memory usage changes shape

With elastic pointers, 2.12 "may show a different memory usage pattern to before" — RSS may be
**lower on some systems and higher on others**, depending on asset count and access patterns.

> "For the first time, the server will be able to respond to memory pressure by freeing filestore
> caches on demand and returning the memory to the operating system. This reduces the chance that
> sudden spikes in utilisation will result in an out-of-memory (OOM) kill. However, this means that
> the server can more optimistically retain caches in memory when available resources allow."

The behaviour is **largely controlled by `GOMEMLIMIT`**, which the guide suggests tuning against
available system memory or, on Kubernetes, against the memory reservation.

### Strict JetStream API is on by default

From **2.11** the server *logged* invalid JetStream requests:

```
[WRN] Invalid JetStream request '$G > $JS.API.STREAM.CREATE.test-stream': json: unknown field "unknown"
```

From **2.12 it also returns an error to the client** — strict mode is enabled by default and
invalid requests are rejected. Temporarily disable while fixing clients:

```
jetstream {
  strict: false
}
```

## Downgrade considerations

**Stream state files are rebuilt** when downgrading 2.12 → 2.11, because the on-disk format changed.
That requires **re-scanning all stream message blocks**: higher CPU than usual and a longer wait
before the restarted node reports healthy. It happens **only on the first restart after
downgrading** and **does not lose data**.

> "When downgrading, only downgrade to **v2.11.9 or higher**. Starting from this version, the server
> will recognize the use of new v2.12 features and will safely put the stream and/or consumer that
> uses these new features into an unsupported/offline mode."

## Relevance to the wiki

The change layer for 2.12, and the source of two facts that change how you read a 2.12+ server:
memory usage is now elastic and `GOMEMLIMIT`-driven, and an invalid JetStream request is an error
rather than a log line. It also corrects the version attribution for the `prioritized` priority
policy, which ADR-42 does not date.

## Questions it answers

Q63 in part and Q64 in part (the 2.11↔2.12 hop, including the **v2.11.9 downgrade floor** — the
single most concrete data-integrity constraint found so far).

## Pages touched

[[nats-server-2.12]] · [[nats-server-2.11]] · [[priority-groups]] · [[js-api]] ·
[[jetstream-sizing]] · [[replicas]] · [[stream]]
