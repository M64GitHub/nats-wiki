---
title: nats-server 2.12
type: entity
kind: release
area: [deploy, jetstream, topology]
since: [2.12]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [release, 2.12, strict-mode, elastic-pointers, offline-assets, GOMEMLIMIT]
aliases: ["2.12", v2.12, v2.12.0, v2.12.15]
sources: [s-docs-upgrade-to-2.12, s-docs-advanced-publishing, s-gh-7463-jetstream-corruption, s-adr-51-message-scheduler, s-gh-7672-cron-schedules]
created: 2026-08-31
updated: 2026-09-01
---

# nats-server 2.12

The predecessor of [[nats-server-2.14]] — **2.13 was skipped**, so 2.12 is the version you upgrade
*from* when moving to current stable.

## Facts

| | |
|---|---|
| first release | **v2.12.0**, 2025-09-22 |
| latest release | **v2.12.15**, 2026-08-12 |
| releases in this line | 47 tags, from `v2.12.0-preview.1` (2025-08-08) |
| upgrades from | 2.11.x |
| downgrade floor | **v2.11.9 or higher** — see below |
| license | Apache-2.0 |

Dates and tags from `raw/release-notes/_tags-and-dates.md` (GitHub releases API, fetched
2026-08-31). Note that 2.12 is **still receiving patches** as of 2026-08-12, after 2.14 shipped.

## What it adds

**Streams**

- **`AllowAtomicPublish`** — atomically publish N messages into a stream, replicated or not, with
  per-message consistency checks before committing (ADR-50). What a publisher actually sends —
  `Nats-Batch-Id`, `Nats-Batch-Sequence`, `Nats-Batch-Commit`, and the `batch`/`count` fields on the
  committing `PubAck` — plus the three ways a batch ends without committing, is on [[publishing]]
  (source: [[s-docs-advanced-publishing]]). Two constraints arrived with it: the flag is refused
  alongside `persist_mode: async`, and a **mirror** cannot be a batch target
  (`10209`, [[error-codes]]).
- **`AllowMsgCounter`** — distributed counter CRDT semantics on a stream; counter streams can be
  mirrored or aggregated (ADR-49).
- **`AllowMsgSchedules`** — delayed message scheduling (ADR-51); 2.14 extends it with cron.

**Consumers**

- **The `prioritized` priority policy** — added here, not in 2.11 with the rest of
  [[priority-groups]]. It lets a consumer receive messages sooner instead of delaying failover, at
  the cost of flip-flopping work between clients.

**Operations**

- **`server_metadata`** — a map of string keys and values describing the server, alongside
  `server_tags`. See [[stream-placement]].
- **Promoting mirrors** — a mirroring stream can be promoted to primary, "enabling new disaster
  recovery methodology". **Delete the current primary or remove its configured subjects first**,
  then configure the promoted mirror to listen on them.
- **`connect_backoff`** on routes and gateways — exponential backoff on reconnection, **starting at
  1 second up to 30 seconds** when `true`. Slower reconnection, but "significantly reduces the
  amount of DNS queries and general connection attempts during server restarts or outages".
- **Offline assets** — on a downgrade the server recognises that newer features were used and puts
  the stream or consumer into an **unsupported/offline mode** rather than misreading it (ADR-44).
- **Scale-up and reset disk/state protection** — better protection against leader elections based
  on empty state, and more reliable replicated in-memory streams. The caveat is important: all but
  one server can be restarted and an in-memory stream's data caught back up, **but every server
  involved in that stream's replication must be available, not just a quorum**.
- **Insecure TLS cipher suites are disabled by default**, re-enabled with
  `allow_insecure_cipher_suites`; new suites from `crypto/tls` are added automatically.
- **The global account `$G` now produces system events** (connect and disconnect).
- **`GOMAXPROCS` and `GOMEMLIMIT` appear in server stats.**
- **New subject transforms `partition(n)` and `random(n)`** — whole-subject convenience forms
  alongside `partition(n, …)` on token indices.
- **Log lines carry the account name and user** for connection-related events (max connections,
  auth errors); connection-closed logging includes the remote server name.
- **`isolate_leafnode_interest`** — stops east-west interest propagating between leaf nodes that do
  not need to reach each other, replacing the same-cluster-name workaround.
- **A leafnode remote can be disabled by config reload** with `disabled: true`; false→true
  disconnects a solicited leafnode and stops it reconnecting.

**Performance**

- **Async stream flushing** for replicated streams — "a significant improvement in performance",
  with **no consistency downside**, because writes are still persisted synchronously in the Raft log
  before being committed. See [[raft-in-nats]].
- **Elastic pointers in the filestore** — write-through caches that can be evicted early under
  memory pressure.

## What an operator must plan for

### Memory usage changes shape

With elastic pointers, 2.12 "may show a different memory usage pattern to before" — RSS may be
**lower on some systems and higher on others**, depending on asset count and access patterns. For
the first time the server can free filestore caches on demand and return memory to the OS, which
reduces OOM-kill risk — but it also means the server **retains caches more optimistically when
resources allow**.

The behaviour is largely governed by **`GOMEMLIMIT`**, which the upgrade guide suggests tuning
against available system memory, or against the memory reservation on Kubernetes. See
[[jetstream-sizing]].

### Strict JetStream API is on by default

From **2.11** the server logged an invalid JetStream request:

```
[WRN] Invalid JetStream request '$G > $JS.API.STREAM.CREATE.test-stream': json: unknown field "unknown"
```

From **2.12 it also returns an error to the client** — invalid requests are now **rejected**. If
that log line was being ignored on 2.11, upgrading turns it into client-visible failures. The
escape hatch, for buying time to fix clients:

```
jetstream {
  strict: false
}
```

See [[js-api]].

### It is also the floor maintainers will help you from

2.12 is where the project's own support answer lands. Asked about a JetStream store that had gone
inconsistent on **2.9.8**, a maintainer's whole reply was: "2.9.x is now very old, unsupported and
100s of bug fixes behind, we have invested a lot of time on the storage layer since… You need to
upgrade to **2.12.x**, we can't help with such old versions." The asker upgraded and reported the
problem gone (source: [[s-gh-7463-jetstream-corruption]]). No public source read states a formal
support or end-of-life policy — this is the closest thing to one, and it is a maintainer's sentence in
a thread, not a document. See [[disaster-recovery]] and [[upgrade-a-cluster]].

### The downgrade floor is v2.11.9

Downgrading 2.12 → 2.11 **rebuilds the on-disk stream state files**, because the format changed.
That means **re-scanning every stream message block**: higher CPU than usual and a longer wait
before the restarted node reports healthy. It happens **only on the first restart** and **does not
lose data**.

> "When downgrading, only downgrade to **v2.11.9 or higher**."

From v2.11.9 the older server recognises 2.12 features in use and safely puts the affected stream
or consumer into unsupported/offline mode, protecting both the data and the server. Downgrading to
anything older gives up that protection.

## What 2.12's message scheduling actually shipped, and what it did not

`AllowMsgSchedules` arrived here, but only **one** of ADR-51's three use cases came with it, and the
gap caught operators out. A maintainer, answering someone whose cron expression was rejected
(source: [[s-gh-7672-cron-schedules]]):

> "Only single scheduled messages from that ADR were released as part of 2.12… The remaining items,
> like cron-like schedules, will be part of version 2.14 to be released March of next year."
> — @MauriceVanVeen, 2025-12-21

So on 2.12: `Nats-Schedule: @at <RFC3339>` with a `Nats-Schedule-Target`, a `Nats-Schedule-TTL`, and
nothing else. **Cron, `@every`, `@hourly`, `Nats-Schedule-Source` and `Nats-Schedule-Time-Zone` are
2.14** ([[nats-server-2.14]]).

**The failure is a syntax error, not a version error.** A 2.14 expression on a 2.12 server comes back
as `message schedules pattern is invalid` (**10189**) — the same message a genuinely malformed cron
gets. Read ADR-51's revision table, which maps each addition to a server version, before debugging the
expression ([[message-scheduling]], [[error-codes]]).


## Related

[[nats-server-2.11]] · [[nats-server-2.14]] · [[priority-groups]] · [[js-api]] ·
[[jetstream-sizing]] · [[raft-in-nats]] · [[upgrade-a-cluster]] · [[nats-server]]

## Sources

[[s-docs-upgrade-to-2.12]] · [[s-docs-advanced-publishing]] · [[s-gh-7463-jetstream-corruption]] · [[s-adr-51-message-scheduler]] · [[s-gh-7672-cron-schedules]]
