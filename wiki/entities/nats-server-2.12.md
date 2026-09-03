---
title: nats-server 2.12
type: entity
kind: release
area: [deploy, jetstream, topology]
since: [2.12]
verified-against: nats-server 2.14.6
verified-on: 2026-09-03
tags: [release, 2.12, strict-mode, elastic-pointers, offline-assets, GOMEMLIMIT, api-level-2, atomic-batch, counters, async-flush, changelog]
aliases: ["2.12", v2.12, v2.12.0, v2.12.5, v2.12.15]
sources: [s-docs-upgrade-to-2.12, s-docs-advanced-publishing, s-gh-7463-jetstream-corruption, s-adr-51-message-scheduler, s-gh-7672-cron-schedules, s-nats-server-filestore-recovery, s-gh-8001-jetstream-startup-slow-50m, s-relnotes-2.11, s-relnotes-2.12, s-relnotes-2.2.0]
created: 2026-08-31
updated: 2026-09-03
---

# nats-server 2.12

The predecessor of [[nats-server-2.14]] — **2.13 was skipped**, so 2.12 is the version you upgrade
*from* when moving to current stable, and the line that is **still patched in step with 2.14**:
from 2.12.9 on every release is the same-day twin of a 2.14 patch. API level 2; strict API and async
flush by default; atomic batch publish, counters, single-message scheduling, the `prioritized`
policy, trusted proxies, the PROXY protocol.

## Facts

| | |
|---|---|
| first release | **v2.12.0**, 2025-09-22 |
| latest release | **v2.12.15**, 2026-08-12 |
| releases in this line | **15** (no 2.12.13); 47 tags from `v2.12.0-preview.1` (2025-08-08) |
| upgrades from | 2.11.x |
| downgrade floor | **v2.11.9 or higher** — see below |
| warned | **v2.12.5** — a stream update could lose a cluster's consumers; mitigation `meta_compact_sync: true`; fixed in 2.12.6 |
| regression | **v2.12.7 → v2.12.11** — stale subject state, `Message Not Found` with `max_msgs_per_subject` (2.14 unaffected) |
| CVEs | the same twelve as 2.11: v2.12.5 (two), v2.12.6 (ten), v2.12.7 (`TBD`); security batches without ids in 2.12.12 and 2.12.14 |
| license | Apache-2.0 |

Dates and tags from `raw/release-notes/_tags-and-dates.md`; the 15 bodies are in
`raw/release-notes/` and read as one changelog in [[s-relnotes-2.12]] (which also checks the docs'
upgrade guide against them); every release is a row of `inbox/relnotes-toc.md`.

## What it adds

**Streams**

- **`AllowAtomicPublish`** — atomically publish N messages into a stream, replicated or not, with
  per-message consistency checks before committing (ADR-50). What a publisher actually sends —
  `Nats-Batch-Id`, `Nats-Batch-Sequence`, `Nats-Batch-Commit`, and the `batch`/`count` fields on the
  committing `PubAck` — plus the three ways a batch ends without committing, is on [[publishing]]
  (source: [[s-docs-advanced-publishing]]). Two constraints arrived with it: the flag is refused
  alongside `persist_mode: async`, and a **mirror** cannot be a batch target
  (`10209`, [[error-codes]]). Batches deduplicate on `Nats-Msg-Id` from 2.12.1 (#7391) (source:
  [[s-relnotes-2.12]]).
- **`AllowMsgCounter`** — distributed counter CRDT semantics on a stream (`Nats-Incr`); counter
  streams can be mirrored or aggregated (ADR-49). **2.12.12 fixed counter staging corrupting the
  committed running total** (#8311) — do not run counters on 2.12.0–2.12.11.
- **`AllowMsgSchedules`** — delayed message scheduling (ADR-51); 2.14 extends it with cron.
- **Mirror promotion** — remove the `mirror` configuration and the mirror becomes a normal stream:
  "cannot be undone and also requires configuring the stream subjects to continue operation"
  (#7171).
- **API level 2** (#6969), the **`Nats-Required-Api-Level`** request header (#7157), **strict API
  decoding by default** (#7049), **async flush by default** on replicated streams "as long as
  `sync: always` is not configured" (#7018, #7163) and an opt-in async persist mode for R1 (#7315).

**Consumers**

- **The `prioritized` priority policy** — added here, not in 2.11 with the rest of
  [[priority-groups]]. It lets a consumer receive messages sooner instead of delaying failover, at
  the cost of flip-flopping work between clients.

**Operations**

- **`server_metadata`** — a map of string keys and values describing the server, alongside
  `server_tags`. See [[stream-placement]].
- **Trusted proxies** (ADR-55, #7153) — `proxies { trusted [ … ] }` plus `authorization {
  proxy_required }`; "enforcing that connections arrive via a NATS protocol-aware proxy". The list
  is documented nowhere (`inbox/docs-issues.md` #60). **The PROXY protocol** (v1 and v2,
  `proxy_protocol: true`) followed in 2.12.2 (#7456). See [[run-nats-behind-a-proxy]].
- **`connect_backoff`** on routes and gateways — exponential backoff on reconnection, **starting at
  1 second up to 30 seconds** when `true`. Slower reconnection, but "significantly reduces the
  amount of DNS queries and general connection attempts during server restarts or outages".
- **Offline assets** — on a downgrade the server recognises that newer features were used and puts
  the stream or consumer into an **unsupported/offline mode** rather than misreading it (ADR-44).
- **Scale-up and reset disk/state protection** — "empty log protection" in Raft (#7038) and
  replicated streams creatable with replica nodes offline (#7075). The caveat is important: all but
  one server can be restarted and an in-memory stream's data caught back up, **but every server
  involved in that stream's replication must be available, not just a quorum**.
- **Insecure TLS cipher suites are disabled by default**, re-enabled with
  `allow_insecure_cipher_suites`; new suites from `crypto/tls` are added automatically;
  `X25519MLKEM768` joins the curve preferences.
- **WebSocket and MQTT clients no longer use TCP keepalives** (#7329) — the line's only
  `### Changed` outside JetStream.
- **New subject transforms `partition(n)` and `random(n)`** — whole-subject convenience forms
  alongside `partition(n, …)` on token indices.
- **Log lines carry the account name and user** for connection-related events (max connections,
  auth errors); connection-closed logging includes the remote server name.
- **`isolate_leafnode_interest`** — stops east-west interest propagating between leaf nodes that do
  not need to reach each other, replacing the same-cluster-name workaround.
- **A leafnode remote can be disabled by config reload** with `disabled: true`; false→true
  disconnects a solicited leafnode and stops it reconnecting.
- **A no-responders error carries the original subject** in a `Nats-Subject` header (#5250). The bytes as the 2.14.6 server sends them — and the 2.2.0 form without the header — are on [[request-reply]] (source: [[s-relnotes-2.2.0]]).

**Performance**

- **Async stream flushing** for replicated streams — "a significant improvement in performance",
  with **no consistency downside**, because writes are still persisted synchronously in the Raft log
  before being committed. See [[raft-in-nats]].
- **Elastic pointers in the filestore** — write-through caches held by weak pointers that "can
  respond to garbage collector (GC) pressure" (#7180).

## What the patch releases changed

The keys, defaults and behaviours an operator on 2.12 lives with, by release (all from
[[s-relnotes-2.12]], which has the full tables and PR numbers):

| release | change |
|---|---|
| 2.12.1 | `write_deadline` per `cluster`, `leafnode` and `gateway` block; WebSocket leafnodes through an HTTP proxy; batches deduplicate on `Nats-Msg-Id`; meta files staged through temp files |
| 2.12.2 | **PROXY protocol**; `meta_compact`, `write_timeout`; expvar `/debug/vars`; parallel stream loading at startup |
| 2.12.3 | `DiscardNewPerSubject` enforced by the leader; the meta layer stages and deduplicates recovery; the `AsyncFlush` write loss fixed |
| 2.12.4 | `tls_cert_not_after`; switching to interest retention removes no-interest head messages; a corrupt R1 file consumer is deleted automatically |
| 2.12.5 | **warned** (consumer loss on stream update; `meta_compact_sync: true`); two CVEs; **async metalayer snapshots**; **`max_consumers` updatable**; `max_conns: 0`; snapshot `window_size`; the "long-standing" `store_max_stream_bytes` accounting bug fixed |
| 2.12.6 | **the 2.12.5 regression fixed**; ten CVEs; 1 MB JWT limit; HTTP CONNECT proxy for leafnodes; restores processed from the wire; the orphan check no longer deletes direct (sourcing) consumers |
| 2.12.7 | `max_mem_store` / `max_file_store` may be **raised by reload**; the ACL fixes; **introduces the stale-subject-state regression** |
| 2.12.8 | consumer start-sequence scans asynchronous; `Nats-Msg-Id` not deduplicated in mirrors; sourcing no longer duplicates after a leaf reconnect |
| 2.12.9 | `in_client_*` counters in `/varz`; pending calculated only on consumer leaders; the drifted-redelivered-state fixes of 2.14.1 |
| 2.12.10 | the filestore block-skip check disabled at extreme subject counts (runaway CPU); counter and schedule configuration constraints |
| 2.12.11 | **the 2.12.7 regression fixed** (#8285) |
| 2.12.12 | **JSONP removed** from monitoring; service-import replies across routes; counter running-total corruption and compaction corrupting compressed or encrypted blocks fixed; a security batch |
| 2.12.14 | **`max_concurrent_io`**, disk semaphore 4096; a `verify_and_map` blank-password authentication bypass and a `no_auth_user` + callout bypass fixed; malformed replicated entries rejected |
| 2.12.15 | idempotent stream creates could lose data when an offline node caught up from a meta snapshot (#8449) |

## Which patch to be on, and why

- **Never 2.12.5 without `meta_compact_sync: true`** — "a stream update may result in the loss of
  consumers in clustered deployments"; **2.12.6** fixes it (#7939).
- **Not 2.12.7 – 2.12.10 with `max_msgs_per_subject`** (every KV bucket has one): stale subject-state
  tracking and `Message Not Found`; **2.12.11** fixes it (#8285), and 2.14 never had it.
- **2.12.12 or later with counters, compression or encryption** — counter staging corrupted the
  running total (#8311) and compaction corrupted compressed or encrypted blocks (#8312) before it.
- **2.12.14 or later on any server with `verify_and_map` or `no_auth_user` plus auth callout** — the
  two authentication bypasses fixed there.
- **2.12.15 or later on a cluster that creates streams idempotently** while nodes may be down
  (#8449).
- **2.12.6 or later, full stop**, for the twelve 2026 CVEs.

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

## The docs' upgrade guide against the bodies

Read line by line ([[s-relnotes-2.12]]): every feature the guide lists is in the v2.12.0 body except
two. "System events for the `$G` account" appears in no 2.12 body (the bodies neither confirm nor deny it), and
"`GOMAXPROCS` and `GOMEMLIMIT` in server stats" is presented as new in 2.12 though it shipped in
**2.10.28 and 2.11.2** (2025-04-25, #6791) — `inbox/docs-issues.md` #58. The guide omits the API
level 2, the `max_buffered_msgs` ×10 (the docs still print the 2.11 default — #22), the
TCP-keepalive change, trusted proxies, `Nats-Required-Api-Level`, the `Nats-Subject` header, and
everything after 2.12.0.

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

## Recovery in the 2.12 line

**v2.12.2** (2025-11-13, with v2.11.11): "Streams are now loaded in parallel when enabling JetStream,
often reducing the time it takes to start up the server (#7482, #7526)" — one task queue of
`min(64, disk-I/O semaphore)` workers across an account's streams; within one stream recovery is
still serial. **v2.12.3**: the meta layer "will now stage and deduplicate recovery operations at
startup, instead of rapidly applying and then undoing conflicting assignments" (#7540). **v2.12.5**
(2026-03-09): tombstones always used for trailing deletes (#7782) and a race fixed while rebuilding
block state (#7783). **v2.12.8**: the consumer start-sequence scan "is now an asynchronous operation
which no longer pauses the metalayer" (#8051). **v2.12.14**: the disk I/O semaphore is 4096 slots
(`max_concurrent_io`), and the parallel task queue above scales with it. The row-13 report — 50 M
messages restored in 6 min 38 s after a clean shutdown — ran on **v2.12.5**, so it had the parallel
loading a maintainer pointed to; the time was the source scan a sourcing stream makes at every
start, which no 2.12.x changes ([[jetstream-recovery-is-slow]]; sources:
[[s-nats-server-filestore-recovery]], [[s-gh-8001-jetstream-startup-slow-50m]], [[s-relnotes-2.12]]).

## The 2.11 releases that ship beside 2.12

The 2.12 line was patched in step with 2.11 from 2025-11-13 on: 2.11.11 with 2.12.2, 2.11.12 with
2.12.4 (2026-01-27), 2.11.14 with 2.12.5 (2026-03-09), 2.11.15 with 2.12.6 (2026-03-24), 2.11.16 with
2.12.7 (2026-04-14), 2.11.17 with 2.12.8 (2026-04-27) — the same fixes and the same twelve CVEs on the
same days (source: [[s-relnotes-2.11]]). And the downgrade floor's other half: PR #7158, "(2.12)
[ADDED] Offline assets support", shipped in **2.11.9** so that a 2.11 server could recognise 2.12
assets as offline rather than misread them. From 2.12.9 (2026-05-20) the twin is 2.14: 2.12.9 =
2.14.1, 2.12.10 = 2.14.2, 2.12.12 = 2.14.3, 2.12.14 = 2.14.4, 2.12.15 = 2.14.5 (source:
[[s-relnotes-2.12]]).

## The default diff at v2.12.15

`python3 tools/check-defaults.py --tag v2.12.15` (2026-09-03; `inbox/check-defaults-v2.12.15.md`):
**14 disagree, 27 unresolved, 175 agree**. Diffed against v2.11.17, **one resolved default moves**
and it is the one the bodies announce: `jetstream { max_buffered_msgs }` **10,000 → 100,000**
(2.12.0, #6633; the docs print the 2.11 value — #22). Three keys become resolvable — the atomic
batch limits `jetstream.limits.batch.max_inflight_per_stream` = 50, `max_inflight_total` = 1,000,
`max_msgs` = 1,000 (2.12.0, ADR-50), all agreeing with the docs — and `strict` becomes *unresolved*
because 2.12 inverted the option (`NoJetStreamStrict = !v`), which is how "on by default" was
implemented (source: [[s-relnotes-2.12]]; the diff in `wiki/log.md` under 2026-09-03).


## Related

[[nats-server-2.11]] · [[nats-server-2.14]] · [[priority-groups]] · [[js-api]] ·
[[jetstream-sizing]] · [[raft-in-nats]] · [[upgrade-a-cluster]] · [[publishing]] ·
[[run-nats-behind-a-proxy]] · [[nats-server]]

## Sources

[[s-docs-upgrade-to-2.12]] · [[s-docs-advanced-publishing]] · [[s-gh-7463-jetstream-corruption]] · [[s-adr-51-message-scheduler]] · [[s-gh-7672-cron-schedules]] · [[s-nats-server-filestore-recovery]] · [[s-gh-8001-jetstream-startup-slow-50m]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]]
- [[s-relnotes-2.2.0]] — where the 503 itself arrived, for the `Nats-Subject` line above.
