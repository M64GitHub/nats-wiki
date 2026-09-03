---
title: "nats-server 2.14 release notes, v2.14.0 → v2.14.6 (2026-04-30 → 2026-08-27): the change layer"
type: summary
area: [deploy, jetstream, topology, monitoring, security, core, kv, interop]
source-url: https://github.com/nats-io/nats-server/releases
source-path: raw/release-notes/v2.14.0.md, raw/release-notes/v2.14.1.md, raw/release-notes/v2.14.2.md, raw/release-notes/v2.14.3.md, raw/release-notes/v2.14.4.md, raw/release-notes/v2.14.5.md, raw/release-notes/v2.14.6.md, raw/nats-server-src/feature-flags-dial-timeout-and-2.15-subjects.md
author: nats-io/nats-server maintainers
date: 2026-08-27          # v2.14.6, the current stable release; v2.14.0 shipped 2026-04-30
version: "2.14"
article: "The 7 GitHub release bodies of the 2.14 line read end to end as one changelog, checked line by line against the docs' 2.14 upgrade guide; the keys and subjects they introduce verified in the server source at v2.14.6"
tags: [release, 2.14, changelog, change-layer, defaults, feature_flags, js_ack_fc_v2, consumer-reset, AckFlowControl, fast-batch, cron, dial_timeout, max_concurrent_io, jsonp]
aliases: [v2.14.0, v2.14.1, v2.14.2, v2.14.3, v2.14.4, v2.14.5, v2.14.6, "2.14 release notes", "2.14 changelog"]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server 2.14 release notes, v2.14.0 → v2.14.6: the change layer

The 2.14 line is the **current stable** line: seven releases from **2026-04-30** (v2.14.0) to
**2026-08-27** (v2.14.6), 15 tags counting the release candidates. It is the direct successor of
2.12 — every body opens with "Please note that the 2.13.x version was skipped". No release was
withdrawn and no body carries an admonition; the one `### Removed` is JSONP on the monitoring
endpoints (2.14.3), and the one `### Changed` is in 2.14.0. Five of the six patches are same-day
twins of a 2.12 patch (2.14.1 = 2.12.9, 2.14.2 = 2.12.10, 2.14.3 = 2.12.12, 2.14.4 = 2.12.14,
2.14.5 = 2.12.15 — [[s-relnotes-2.12]]); **2.14.6 has no 2.12 twin**. This summary reads the seven
bodies as one document, by kind of change, each item with its release and PR number; folds in the
three per-patch summaries that already exist ([[s-relnotes-2.14.0]], [[s-relnotes-2.14.1]],
[[s-relnotes-2.14.4]]) by reference; checks the docs' 2.14 upgrade guide ([[s-docs-upgrade-to-2.14]])
against the bodies; and verifies the keys and subjects the bodies introduce in the server source
at v2.14.6 (`raw/nats-server-src/feature-flags-dial-timeout-and-2.15-subjects.md`). The 2.15
preview is [[s-relnotes-2.15-preview]]; the earlier lines are [[s-relnotes-2.10]],
[[s-relnotes-2.11]] and [[s-relnotes-2.12]].

## The releases at a glance

| release | date | Go | ★ | 2.12 twin | what an operator needs from it |
|---|---|---|---|---|---|
| 2.14.0 | 2026-04-30 | 1.26.2 | ★ | — | the feature release: `feature_flags`, fast-ingest batch publishing, cron and `@every` schedules with sampling and rollups, the **consumer reset API**, `$JS.ACK` / `$JS.FC` **v2 behind `js_ack_fc_v2`**, async stream snapshots, WorkQueue/Interest sourcing with **`AckFlowControl`**, reloadable leafnode remotes, `ignore_discovered_servers`; `404 No Messages` on `no_wait` without an expiry; divergent consumer state reset on startup; **info API requests deprioritised**; `traceparent` untouched; **Raft steps down when overrun**; **Raft refuses to start on a bad snapshot** |
| 2.14.1 | 2026-05-20 | 1.26.3 | | 2.12.9 | **`in_client_msgs` / `in_client_bytes` / `out_client_*`** in `/varz` (#7851); pending calculated only on consumer leaders (#8172); **the drifted-redelivered-state fixes** (#8102, #8156, #8168); mirror retry on last-sequence mismatch (#8152); route compression obeys `max_pings_out` (#8093); TLS with the PROXY protocol (#8130); 27 JetStream fixes |
| 2.14.2 | 2026-06-02 | 1.26.3 | | 2.12.10 | **the block-skip check disabled on extremely high subject counts — runaway CPU** (#8227); quorum with gateway URLs resolving to several IPs (#8238); `$JS.ACK` rewrite corruption (#8242); compressed-WebSocket buffer corruption (#8244); per-subject last block with `max_msgs_per_subject: 1` (#8254); peer-set drift after removing an online node (#8258) |
| 2.14.3 | 2026-06-29 | 1.26.4 | ★ | 2.12.12 | **`### Removed` — JSONP callback support** on the monitoring endpoints; a **security batch without CVE ids** (MQTT pre-auth memory, `PUBLISH` underflow, `$MQTT.deliver.pubrel`, subscribe deny on replay paths, `CONNZ`/`SUBSZ` overflow, `NoAuthUser` restrictions, leaf `Nats-Trace-Dest` bypass); **counter staging corrupted the running total** (#8311); **compaction corrupted compressed or encrypted blocks** (#8312); Raft stops voting after write errors (#8290); service-import replies across routes (#8317); a `### Credits` section |
| 2.14.4 | 2026-07-30 | 1.26.5 | | 2.12.14 | **`jetstream { max_concurrent_io }`, the disk semaphore at 4096 slots** (#8336); the interior-delete speed-ups (#8403, #8405, #8406, #8412); **an authentication bypass with `verify_and_map` and blank passwords**; `no_auth_user` with auth callout skipping checks; malformed replicated entries rejected (five reports by one contributor); Raft term on proposals (#8370); MQTT packet ids from a monotonic counter (#8358); `$MQTT.>` subscriptions refused |
| 2.14.5 | 2026-08-12 | 1.26.5 | | 2.12.15 | **`leafnodes { dial_timeout }`**, also per remote, "above the default 1 second for high-latency links" (#8427); **"potential data loss when handling idempotent stream creates when an offline node catches up from a metalayer snapshot"** (#8449); a logger deadlock (#8430) |
| 2.14.6 | 2026-08-27 | 1.26.7 | | — | **dynamic filestore reservations no longer shrink after restarts** (#8503 — [[jetstream-out-of-disk]]); stream reads under their own lock, faster direct gets (#8486); **replicated consumers stuck after a leader change** (#8488); **a consumer create that could destroy an existing consumer's state** (#8491); a stale snapshot from a previous Raft group replayed, a stalled catch-up, the append-entry cache bounded by size (#8501); inline compaction ignoring `sync_interval: always` (#8475); `AckFlowControl` acking outside the filter (#8431, #8528); R > 1 updates rejected on a non-clustered server (#8464); missing routes after a reconnect (#8527) |

★ is the table's rule (`inbox/relnotes-toc.md`): changed, removed, downgrade, withdrawn, warning,
CVE, or the first of a minor. 2.14.3 is starred for its `### Removed`, not for a CVE: **no 2.14
body names a CVE identifier**; the security fixes of 2.14.3 and 2.14.4 are listed without ids, as
their 2.12 twins are.

## Defaults, limits and behaviours that changed

| what | before | after | release, PR |
|---|---|---|---|
| **`feature_flags { }`** in the server config | — | **exists**; a map of name → bool, parsed at `opts.go:1842–1862` (v2.14.6); at v2.14.6 exactly two flags, `js_ack_fc_v2` and `js_raft_delete_range`, **both `false`** (`feature_flags.go:22–47`) | 2.14.0, #7866 (ADR-53) |
| `$JS.ACK` / `$JS.FC` subject format | v1 | **v1 remains the default; v2** (`$JS.ACK.<domain>.<account hash>.<stream>.<consumer>.…`) **behind `js_ack_fc_v2`** — the body: "this will be enabled by default in v2.15"; ACLs on `$JS.ACK.<stream>.>` / `$JS.FC.<stream>.>` must be updated first | 2.14.0, #7860 |
| a `no_wait` pull with no `expires` and nothing pending | (no status) | **`404 No Messages`** — the same #7466 that 2.11.11 lists, so not new to an operator on 2.11.11+ or 2.12.2+ | 2.14.0, #7466 |
| consumer state that is invalid or diverges from the stream | kept | **reset to match the stream state on startup**, "i.e. after unclean shutdowns" | 2.14.0, #7692 |
| account info, stream info, stream list, consumer info, consumer list | one API queue | **queued separately and deprioritised** "relative to create-update-delete API operations" | 2.14.0, #7898 |
| the `traceparent` header under message tracing | modified | **no longer modified**; `Nats-Trace-Dest: trace disabled` disables all server tracing | 2.14.0, #7755 |
| MQTT retained-message subjects | any | **may not contain ASCII DEL (`0x7F`)** | 2.14.0, #8071 |
| a Raft leader whose proposals outrun commit and apply | grows | **steps down** ("Raft nodes will step down if overrun") | 2.14.0, #7853 |
| a Raft node whose snapshot is missing, corrupt or misaligned with the log | starts | **will no longer start**, "avoiding potential data loss" | 2.14.0, #7566, #7580, #7620 |
| rollups on a stream at its `discard_new_per_subject` limit | refused | **allowed** | 2.14.0, #7974 |
| stream state snapshots on replicated streams | pause processing | **asynchronous** — "particularly impactful … with a large number of interior deletes" | 2.14.0, #7876 |
| sourcing from a WorkQueue or Interest stream | not supported | **supported**: the server "automatically upgrades to a durable consumer with `AckFlowControl` policy and uses consumer reset where necessary" | 2.14.0, #7613 (ADR-60) |
| leafnode `remotes` | restart | **added and removed by config reload** | 2.14.0, #7937 |
| num pending | every replica | **only on consumer leaders**, "avoiding unnecessary CPU usage on followers" | 2.14.1, #8172 |
| cluster route compression | own ping budget | **obeys the cluster `max_pings_out`** if configured | 2.14.1, #8093 |
| the filestore block-skip check on filtered reads | always | **skipped on streams with extremely high subject counts** — "it could result in runaway CPU usage" | 2.14.2, #8227 |
| JSONP on the monitoring endpoints | supported | **removed** | 2.14.3 |
| per-connection and TLS-handshake log lines | info | **debug** (#8096 in 2.14.1, #8289 in 2.14.3) | 2.14.1, 2.14.3 |
| **concurrent disk I/O** | CPU-scaled | **4096 slots**; `jetstream { max_concurrent_io }`, bounds 4 – 8192 | 2.14.4, #8336 — undocumented, `inbox/docs-issues.md` #59 |
| `healthz` on an account whose JWT expired | reported | **skipped** | 2.14.4, #8379 |
| `/varz` JetStream limits after a config reload | stale | **updated** | 2.14.4, #8394 |
| a stream config update with `replicas > 1` on a non-clustered server | accepted | **rejected** | 2.14.6, #8464 |
| inline filestore compaction with `sync_interval: always` | skipped the sync | **honours it** | 2.14.6, #8475 |
| an unset `max_file_store` at restart | recomputed from *free* disk, shrinking | **no longer shrinks based on used storage** (`finalizeDynamicMaxStore`) | 2.14.6, #8503 |

## Config keys, subjects, headers and fields that arrived

| key, subject or field | release, PR | verified |
|---|---|---|
| **`feature_flags { <name>: <bool> }`** — `js_ack_fc_v2` (the ack-subject v2 format), `js_raft_delete_range` (one `deleteRangeOp` Raft entry per gap instead of one per sequence, with the source's own **WARNING**: "Older peers panic on apply of an unknown stream entry operation") | 2.14.0, #7866 | `feature_flags.go:22–47`, `opts.go:570`, `server.go:2284` (v2.14.6). The docs' `feature_flags.md` names no flag — `inbox/docs-issues.md` **#62** |
| **fast-ingest batch publishing** (ADR-50) — flow-controlled, no staging; 2.14.1 parses the batch sequence as `uint64` (#8094); 2.14.3 fixes failed commits with `gapOk` (#8308); 2.14.6 a batch-id race (#8369) | 2.14.0, #7778, #7892, #7894, #7945 | [[publishing]] |
| **`Nats-Batch-Commit: eob`** — commit an atomic batch with a final message that is *not* persisted | 2.14.0, #7403 | 2.14.3: end-of-batch max-size checks and R1 rewrites (#8305) |
| **`Nats-Schedule`** repeating: `@every 5m`, `@hourly`, crontab syntax (ADR-51); **`Nats-Schedule-Source`** (sample the last message on a subject); **`Nats-Schedule-Rollup`** | 2.14.0, #7504, #7687, #7688; #7506; #7559 | [[message-scheduling]]; 2.14.1: `Nats-Schedule-Next: purge` checks the target is a schedule (#8135); 2.14.2: config constraints (#8240); 2.14.3: schedule drift fixed, malformed state rejected (#8308, #8269) |
| **`$JS.API.CONSUMER.RESET.<stream>.<consumer>`** — reset "back to an earlier sequence number … without deleting and recreating" (ADR-60) | 2.14.0, #7489 | `jetstream_api.go:159` (v2.14.6). Absent from the docs' consumer API index — **#63**. 2.14.4: reset responses dropped through a service import (#8407) |
| **`$JS.ACK.<domain>.<acchash>.<stream>.<consumer>.>`** and **`$JS.FC.<domain>.<acchash>.<stream>.<consumer>.>`** | 2.14.0, #7860 | behind `js_ack_fc_v2`; see [[js-api]] |
| **`AckFlowControl`** ack policy (JSON `flow_control`) and the durable **`JS_MIRROR_*` / `JS_SRC_*`** consumers | 2.14.0, #7613 | `consumer.go:351, 758–780` (v2.14.6): push-based, `flow_control` on, heartbeat exactly `1s`, positive `max_ack_pending`, no `ack_wait`, `backoff` or `max_deliver`; 2.14.6: no longer acks outside the filter on a WorkQueue upstream (#8431, #8528) |
| sourcing without deduplication | 2.14.0, #7651 | [[mirrors-and-sources]] |
| **`leafnodes { remotes [ { ignore_discovered_servers } ] }`** — ignore the leafnode URLs the hub sends | 2.14.0, #8067 | `opts.go:334, 3247–3248` (v2.14.6); documented (`reference/config/leafnodes/remotes/ignore_discovered_servers.md`) |
| **`in_client_msgs`, `in_client_bytes`, `out_client_msgs`, `out_client_bytes`** in `/varz` — "data to/from normal clients only" | 2.14.1, #7851 | undocumented, noted on #57 |
| the client ID through the embedded `ClientAuthentication` API | 2.14.2, #8217 | embedded servers only |
| **`jetstream { max_concurrent_io }`** | 2.14.4, #8336 | `dios.go` (v2.14.6): default 4096, bounds 4–8192 — #59 |
| **`jetstream { info_queue_limit }`** — the separate queue for account, stream and consumer info and list requests; the docs page says "Available since NATS Server 2.14" and prints a default of 100,000 | 2.14.0, #7898 — the body names the queue, not the key | `opts.go:2766–2771, 6183–6185` (v2.14.6): unset or `<= 0` → **`request_queue_limit`**, so 10,000 unless that is raised; the docs' 100,000 is wrong — `inbox/docs-issues.md` #22. Found by diffing `tools/check-defaults.py` reports at v2.12.15 and v2.14.6 (step 8) |
| **`leafnodes { dial_timeout }`** and **`leafnodes { remotes [ { dial_timeout } ] }`** — "allowing it to be increased above the default 1 second for high-latency links" | 2.14.5, #8427 | `opts.go:232–238, 275–280, 2872–2873, 3211–3212`; `const.go:156` (`DEFAULT_ROUTE_DIAL = 1 * time.Second`); `leafnode.go:604–608, 763–764` (v2.14.6). **Documented nowhere — #61** |

## Behaviours that changed — the "now" and "no longer" lines, by patch

- **2.14.1** (source also [[s-relnotes-2.14.1]]): **"A number of paths that could leave consumer
  redelivered in a drifted state have been fixed, e.g. with workqueue or interest-based streams with
  `max_deliver`, on single message removal or after purges/compactions" (#8102)**; a consumer file
  store flushes when deleting a single redelivery, "avoiding unexpected further redeliveries"
  (#8168); "pending state no longer leaks when reaching max deliveries" (#8156); the delivery policy
  on clustered WorkQueue streams enforced (#8126); a consumer with an `inactive_threshold` no longer
  loses local state when the meta clean-up proposal fails (#8198); source-consumer set-up no longer
  storms (#8111); mirror consumers retried immediately on a last-sequence mismatch (#8152); skip
  errors propagated (#8152); Raft ignores temporary snapshots after a crash (#8101), invalidates its
  append-entry caches on truncation and snapshot install (#8149), refuses proposals to remove
  unknown peers (#8154), cancels an in-flight checkpoint on reset (#8180, #8202); meta state
  preserved on shutdown (#8199); local meta log reset when extending the group to a parent domain
  (#8142); storage reservations consistent between creates/updates and clustered/non-clustered
  (#8170); `JetStreamMaxMemory` / `JetStreamMaxStore` honoured in embedded mode (#8184); republish
  subjects validated (#8127); stream and consumer assignment errors surfaced (#8208); sublist
  intersections cancel early in pathological cases (#8209). Elsewhere: TLS listeners with the PROXY
  protocol (#8130); client certificates with DNS SANs but no subject DN permitted (#8100); server
  shutdown idempotent for embedded use (#8163); a JWT directory-resolver panic (#8173); in-process
  connections no longer revert to TLS-required on an async `INFO` (#8205); leafnode connections
  over already-compressed WebSockets no longer negotiate compression (#7969); lock contention
  between leafnodes and clients (#8139, #8159); MQTT rejects invalid subject characters, "avoiding
  protocol issues when forwarded to other connection types" (#8104, #8112).
- **2.14.2**: **"Potential protocol-level corruption from rewriting `$JS.ACK` subjects" (#8242)**
  and **from buffer misuse in compressed WebSocket clients (#8244)** fixed; a route-interest race
  (#8235); `/accstatz` no longer omits accounts with only leaf connections (#8252); Raft peers
  tracked after an inactivity stall during catch-up (#8226); quorum computed correctly when
  bootstrapping the meta layer with gateway URLs resolving to several IPs (#8238); the filestore
  releases its lock after a write error (#8232); purges consistent between file and memory stores
  (#8241); a consumer lock released after a start-sequence error (#8230); counter streams and
  schedules get configuration constraints (#8240); scale-down consistent (#8253); the per-subject
  last block stored correctly with `max_msgs_per_subject: 1` (#8254 — the KV shape); peer-set drift
  after peer-removing an online node (#8258).
- **2.14.3**: **JSONP removed**; long-running reconnect and OCSP loops release unused timers (#8204);
  inherited JWT default permissions refresh on a claims update (#8276); external auth config cleared
  on a claims update (#8275); PROXY-protocol detection, TLS sniffing with `allow_non_tls` and v1
  address-family parsing fixed (#8302); a gateway `CONNECT` race (#8306); trusted-proxy tracking no
  longer leaks closed clients (#8307); **service-import replies delivered across cluster routes
  (#8317)**; message tracing works with imports and exports; `NoAuthUser` checks connection
  restrictions; leaf connections no longer bypass `Nats-Trace-Dest` publish permissions; `CONNZ` /
  `SUBSZ` pagination guards `Offset` / `Limit` overflow; a nil-pointer panic when the resolver's
  parent directory is missing (#8329); `s2_fast` writer options applied consistently (#8047). MQTT:
  partial `CONNECT` packets can no longer exhaust pre-authentication memory; a `PUBLISH`
  remaining-length underflow no longer panics; subscriptions to `$MQTT.deliver.pubrel` rejected;
  subscribe deny rules enforced on retained-message and QoS replay paths; a WebSocket `/mqtt`
  upgrade no longer panics with MQTT disabled. JetStream: a meta-node data race at shutdown (#8260);
  meta proposal in-flight tracking during stream moves (#8261); assignment handling refactored
  (#8262); **stream catch-up no longer skipped when limits are exceeded, "preventing possible stream
  desync" (#8265)**; malformed TTL and schedule state rejected on decode (#8269); zero consumer
  limits mean unlimited on a stream update (#8286); **Raft nodes stop voting and campaigning after
  write errors (#8290)**; checkpoints abort on a closed node (#8296); write errors registered for
  health and recovery (#8293); `ApplyCommit` handles the post-snapshot index (#8321); ack
  subscriptions match consumer names containing `%` (#8301); observer state cleared under
  `js_cluster_migrate` when a leaf remote is removed (#8304); atomic-batch end-of-batch checks and R1
  rewrites (#8305); schedule drift, failed fast-batch commits with `gapOk`, stale `/varz` leaf-remote
  state (#8308); peer-state decoding bounded (#8310); **counter staging no longer corrupts the
  committed running total (#8311)**; **filestore compaction no longer corrupts compressed or encrypted
  blocks (#8312)**; memory-store `NumPending` no longer overcounts for `DeliverLastPerSubject`
  (#8313); the inactive-delete grace period and pull `MaxBytes` budgeting (#8314); `MultiLastSeqs`
  no longer reorders the configured subjects (#8315); meta recovery snapshots leave no phantom
  streams or consumers (#8324); skipped-messages last time no longer breaks start-by-time (#8237);
  uncommitted membership changes reverted on truncation or snapshot (#8332).
- **2.14.4** (source also [[s-relnotes-2.14.4]]): the disk semaphore and `max_concurrent_io`
  (#8336); the Raft transport decoupled, "does not change server behaviour" (#8181); block-cache
  buffers recycled when the GC collects the weak reference (#8395); faster delete-map lookups and
  AVL sequence sets on streams with many interior deletes (#8403, #8406); snapshot encode buffers
  sized up front (#8405); the subject-tracking structure uses less memory (#8412). **The security
  batch, without CVE ids**: `no_auth_user` with auth callout no longer skips authentication when no
  `CONNECT` is sent; whitespace-only JWT permissions no longer crash the server; queue-subscription
  permission paths no longer treat the whole permission as a subject literal; JetStream and MQTT
  endpoints guard against JSON nulls; **"an authentication bypass with TLS `verify_and_map`
  authenticating users with blank passwords"**; MQTT clients can no longer subscribe to `$MQTT.>`.
  Also: `allow_non_tls` no longer logs that TLS is required (#8420); `healthz` skips expired JWT
  accounts (#8379); `/varz` reports JetStream limits after a reload (#8394); malformed replicated
  acks, delivered updates, skips and resets rejected, empty entries ignored, oversized entries and
  AVL node counts validated on 32-bit (#8284, #8345, #8347, #8355, #8357); stale error responses on
  source or mirror creation dropped by recreating the subscription (#8356); **elections ignore votes
  from removed peers (#8353)**; **filestore blocks with unsynced or truncated key files are removed
  and counted as lost data "instead of failing to recover altogether" (#8365)**, and key files are
  synced "more aggressively" (#8366); the append-entry iterator's end handled (#8372); string
  ownership for the expected last sequence per subject in a batch (#8377); a race between concurrent
  limit removals that could disable writes into a filestore (#8378); a cache-weakening bug raising
  memory and GC pressure (#8380); changing a consumer's storage type returns an error (#8382); a
  publish over the maximum store size rejected before proposal (#8389); a race between storing and
  compaction (#8400); sparse delete blocks no longer skipped when applying a snapshot's deletes
  (#8404); consumer-reset responses no longer dropped through a service import (#8407); a consumer
  created right after its clustered stream no longer gets `stream not found` (#8410); **Raft
  proposals carry the term from JetStream, "preventing situations where stale proposals from a
  previous term could make changes in a new term after a fast election" (#8370)**; a stream recreated
  while a node was down is not taken for an update by the returning node, "avoiding stale Raft
  groups from continuing to run" (#8413); snapshot endpoints check the reply subject more strictly.
  MQTT: packet identifiers for QoS 1 and 2 from a monotonic counter, "avoiding accidental ID reuse"
  (#8358); pending QoS 1/2 deliveries no longer leak on a downgrade to QoS 0 (#8359); QoS 2 messages
  released on a resumed session keep their QoS and packet ID (#8414).
- **2.14.5**: `dial_timeout` (#8427); a logger deadlock on a close error (#8430); **the
  idempotent-create data-loss fix (#8449)**.
- **2.14.6**: constant-time removal from service-import response maps (#8463); fewer deadline resets
  when flushing client buffers (#8513); client write buffers freed when the working buffer grows
  past "a rational size" (#8515); WebSocket buffers recycled on reallocation (#8518); **missing
  routes after a reconnect when gossiped URLs were rejected (#8527)**; **stream reads under a separate
  lock, "which improves the performance of direct gets" (#8486)**, and faster multi-subject
  sequence lookups (#8486); fewer heap escapes in subject-tree matching (#8526); the block sync no
  longer skips blocks compacted in the same pass (#8456), performs one directory sync per pass
  (#8461), and runs under the I/O semaphore (#8462); R > 1 updates rejected non-clustered (#8464);
  stream snapshots no longer prevented on a clean shutdown (#8465); inline compaction honours
  `sync_interval: always` (#8475); the stream created time preserved after recovery on a standalone
  server (#8471); a batch-ID data race (#8369); a data race reading the consumer direct or sourcing
  status, and that status can no longer be changed by a consumer update (#8478); **consumer tiers
  distinguished when enforcing limits (#8484)**; **replicated consumers no longer stuck after a leader
  change — a flow-control problem (#8488)**; **"various consumer create issues that could destroy
  the state of an existing consumer with the same name" (#8491)**; internal delete proposals no
  longer counted in the JS API statistics (#8502); **dynamic filestore reservations no longer shrink
  after restarts (#8503)**; a signalling issue stalling Raft catch-ups, the pending append-entry
  cache bounded by size as well as count, and a stale snapshot from a previous Raft group no longer
  replayed when the group name was unchanged (#8501); consumer delivery counts no longer underflow
  below zero (#8512); `AckFlowControl` consumers on a WorkQueue upstream no longer ack outside the
  filter (#8431, #8528).

## Data-integrity and data-loss fixes

| release | fix |
|---|---|
| 2.14.0 | Raft nodes refuse to start on a missing, corrupt or misaligned snapshot (#7566, #7580, #7620); filestore read and write errors handled "more thoroughly" (#7788); recovery from a partial purge after a hard kill (#7676); consistent Raft group rename moving to or off R1 (#7802) |
| 2.14.1 | temporary snapshots ignored after a crash (#8101); encryption-mode conversion clears caches, "avoiding block-level corruption" (#8105, #8166); append-entry caches invalidated on WAL truncation and snapshot install (#8149); no proposals to remove unknown peers (#8154); metalayer state preserved on shutdown (#8199); a consumer's local state survives a failed clean-up proposal (#8198); reservations consistent (#8170) |
| 2.14.2 | the `$JS.ACK` rewrite and compressed-WebSocket corruptions (#8242, #8244); peers tracked after an inactivity stall (#8226); quorum with multi-IP gateway URLs (#8238); peer-set drift after removing an online node (#8258); the per-subject last block with a limit of 1 (#8254) |
| 2.14.3 | **counter staging corrupting the running total (#8311)**; **compaction corrupting compressed or encrypted blocks (#8312)**; catch-up not skipped over limits (#8265); no voting after write errors (#8290); `ApplyCommit` after a snapshot (#8321); uncommitted membership changes reverted (#8332); phantom assets after meta recovery (#8324); malformed TTL and schedule state rejected (#8269); peer-state decoding bounded (#8310) |
| 2.14.4 | malformed replicated entries rejected (#8284, #8345, #8347, #8355, #8357); elections ignore removed peers (#8353); unsynced key files → lost data counted, not a failed recovery (#8365, #8366); the term on proposals (#8370); concurrent removals disabling writes (#8378); store/compaction race (#8400); sparse delete blocks from a snapshot (#8404); recreated streams not taken for updates (#8413) |
| 2.14.5 | **"potential data loss when handling idempotent stream creates when an offline node catches up from a metalayer snapshot, caused by an incorrect update to the create time in the stream assignment" (#8449)** |
| 2.14.6 | the block-sync skips and the directory sync (#8456, #8461); snapshots on clean shutdown (#8465); `sync_interval: always` honoured by inline compaction (#8475); **a consumer create destroying an existing consumer's state (#8491)**; a stale snapshot from a previous Raft group (#8501); replicated consumers stuck after a leader change (#8488); dynamic reservations shrinking (#8503); `AckFlowControl` acking outside the filter (#8431, #8528) |

## The docs' upgrade guide against the bodies

[[s-docs-upgrade-to-2.14]] (`raw/nats-docs/release-notes/upgrade-to-2.14.md`) read line by line
against the v2.14.0 body:

- **Confirmed by the body**: fast batch publish (#7778 …), recurring schedules (#7504 …), scheduled
  subject sampling (#7506), WorkQueue/Interest sourcing with `AckFlowControl` (#7613), the consumer
  reset API (#7489), leafnode remote reload (#7937), Raft overrun protection (#7853), deduplication
  disabled when sourcing (#7651), EOB commit (#7403), scheduled rollups (#7559), feature flags
  (#7866), the v1/v2 ack subjects (#7860), `traceparent` (#7755), asynchronous stream snapshots
  (#7876), the `unknown field "sourcing"` warning during a mixed-version roll, the downgrade rules.
- **Not in the bodies**: "sourcing streams can now perform deduplication when fanning in multiple
  sources" (guide line 34) — the 2.14.0 body says only that deduplication "can be disabled"
  (#7651); no 2.14 body mentions fan-in deduplication. Neither confirmed nor denied here.
- **The guide's words, not the body's**: "freeze the stream", "reports an unhealthy state in health
  checks" and the `write error` message (guide lines 28, 86–88) describe #7788, whose body line is
  "Filestore operations now handle read and write errors from the filesystem more thoroughly". The
  guide is the only source for the freeze; the wiki keeps it as the guide's claim.
- **The guide omits**: the `404 No Messages` change (#7466), the reset of divergent consumer state
  (#7692), the deprioritised info APIs (#7898), the MQTT DEL rule (#8071), rollups at
  `discard_new_per_subject` (#7974), Raft refusing to start on a bad snapshot (#7566 …),
  `ignore_discovered_servers` (#8067), and everything after 2.14.0 — `in_client_*`, the JSONP
  removal, `max_concurrent_io`, `dial_timeout`, the 2.14.5 data-loss fix, the 2.14.6 reservation fix.
- **Docs gaps verified in the source** (`raw/nats-server-src/feature-flags-dial-timeout-and-2.15-subjects.md`):
  **#61** `dial_timeout` documented nowhere; **#62** the `feature_flags` reference page names no flag,
  while the guide tells operators to set `js_ack_fc_v2` and the source warns that `js_raft_delete_range`
  panics older peers; **#63** `$JS.API.CONSUMER.RESET` absent from the consumer API index. The
  guide's ADR pointer for the ack subjects is ADR-15, which `inbox/adr-toc.md` records as
  *Deprecated*; its `#jsack` section is nonetheless what the server source cites (`feature_flags.go:34`).

## Corrections and notes

1. **"Enabled by default in v2.15"** (the v2.14.0 body, #7860) had not happened at the preview tag:
   `feature_flags.go` at v2.15.0-preview.1 still has `FeatureFlagJsAckFormatV2: false` with
   "Enabled: TBD" ([[s-relnotes-2.15-preview]]). The wiki keeps the 2.15 deadline as the maintainers'
   stated intent, not as a shipped default.
2. **#7466 is listed twice in the archive**: in the 2.11.11 body (2025-11-13, where it prints "400
   No Messages") and in the 2.14.0 body under `### Changed`. The server sends `404`; an operator
   coming from 2.11.11+ or 2.12.2+ already has it.
3. **The 2.14.0 body's Raft-overrun line is one sentence** ("Raft nodes will step down if overrun",
   #7853); the mechanism's description — leaders falling behind step down, a majority equally
   overloaded stays degraded — is the guide's ([[raft-in-nats]]).
4. **`js_raft_delete_range`** is introduced in 2.14.0 per the source comment but named in no release
   body; the 2.14.0 body's "feature flags" line names no flag at all. [[mirrors-and-sources]] already
   carries the flag from the source read.
5. The 2.14.3 body has a `### Credits` section naming five non-CVE reporters — the only such section
   in the 70 bodies — and its MQTT and monitoring fixes carry no PR numbers.
6. Go versions: 1.26.2 → 1.26.3 → 1.26.3 → 1.26.4 → 1.26.5 → 1.26.5 → 1.26.7. Dependencies are
   bumped in 2.14.1, 2.14.2, 2.14.3, 2.14.4 and 2.14.5 (`klauspost/compress`, `x/crypto`, `x/sys`,
   `jwt/v2` 2.8.2, `nkeys` 0.4.16, and in 2.14.4 the Antithesis SDK as a no-op default).

## Relevance to the wiki

This is the line the wiki is verified against, so the change layer here is mostly *which patch*:
**2.14.1** for trustworthy consumer accounting ([[consumer-keeps-redelivering]]), **2.14.2** for
very large subject spaces and `max_msgs_per_subject: 1` buckets ([[key-value]], [[filestore-layout]]),
**2.14.3** for counters, compression or encryption and for the security batch, **2.14.4** for sparse
streams, `max_concurrent_io` and the `verify_and_map` bypass, **2.14.5** for the idempotent-create
data loss and high-latency leafnode links, **2.14.6** for the reservation ratchet
([[jetstream-out-of-disk]]), stuck replicated consumers and the consumer-create state destruction.
The keys and subjects that arrived — `feature_flags`, `js_ack_fc_v2`, `ignore_discovered_servers`,
`dial_timeout`, `max_concurrent_io`, `CONSUMER.RESET`, `AckFlowControl`, the `in_client_*` counters —
land on [[config-keys]], [[defaults-and-limits]], [[js-api-subjects]], [[leafnode]],
[[monitoring-endpoints]]; the three docs gaps on `inbox/docs-issues.md`.

## Questions it answers

Rows 63, 64 and 130 in part (the 2.14 hazards and the data-integrity table); 14 in part (2.14.1's
consumer fixes, 2.14.6's #8488 and #8491); 9 and 13 in part (2.14.2's cardinality threshold,
2.14.4's semaphore and interior-delete work); 76 and 91 in part (2.14.4); 29 (cron is 2.14.0); 139 in
part (the client-only counters exist from 2.14.1; the bodies do not say whether any counter is
exact). No open row is closed by this summary alone.

## Pages touched

[[nats-server-2.14]] · [[nats-server-2.15-preview]] · [[upgrade-a-cluster]] · [[consumer]] ·
[[ack-and-redelivery]] · [[stream]] · [[retention-policies]] · [[mirrors-and-sources]] ·
[[publishing]] · [[message-scheduling]] · [[key-value]] · [[direct-get]] · [[replicas]] ·
[[raft-in-nats]] · [[meta-layer]] · [[filestore-layout]] · [[js-api]] · [[js-api-subjects]] ·
[[leafnode]] · [[gateway]] · [[tls-in-nats]] · [[auth-callout]] · [[account]] ·
[[subject-permissions]] · [[cross-account-sharing]] · [[mqtt]] · [[websocket]] ·
[[monitoring-endpoints]] · [[defaults-and-limits]] · [[config-keys]] · [[error-codes]] ·
[[jetstream-sizing]] · [[jetstream-out-of-disk]] · [[jetstream-recovery-is-slow]] ·
[[consumer-keeps-redelivering]] · [[stream-leader-keeps-moving]] · [[stream-placement]] ·
[[backup-and-restore-jetstream]] · [[reload-server-config]] · [[install-nats-server]] ·
[[run-nats-behind-a-proxy]] · [[rebalance-streams]]
