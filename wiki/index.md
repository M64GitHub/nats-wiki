---
title: Index
type: index
created: 2026-08-31
updated: 2026-09-03
---

# NATS Wiki — Index

Catalog of every page. Read this first on any query. Pages link by slug (filename without
`.md`); folders are only layers. Operations are logged in [[log]]. The questions this wiki
exists to answer live in `inbox/question-bank.md`.

## Concepts

*What a thing is and how it behaves — streams, consumers, accounts, topology primitives.*

- [[stream]] — the durable ordered message store: subjects, limits, discard, storage, and the
  fields you cannot change after creation.
- [[consumer]] — the stateful cursor over a stream: pull fetch vs consume, `batch`/`expires`,
  deliver and replay policies, what `nats consumer info` shows.
- [[ack-and-redelivery]] — at-least-once in practice: the four answers (ack, nak, term,
  in-progress), `ack_wait`, `max_deliver`, `max_ack_pending`, backoff, and the advisories.
- [[retention-policies]] — `limits` / `interest` / `workqueue`: who decides a message is finished,
  and why the choice is effectively permanent.
- [[replicas]] — R=1/R=3/R=5, what a `PubAck` promises, `sync_interval`, and why replicas are a
  durability knob rather than a throughput one.
- [[key-value]] — a KV bucket is the stream `KV_<bucket>`: fixed properties, why a delete grows the
  bucket, no read-after-write, and what watch and key listing really are. Plus compare-and-swap, the
  lock-and-lease it composes into, and when a bucket is the wrong tool.
- [[mqtt]] — `nats-server` **is** the MQTT broker: topics become subjects, the five `$MQTT_*` streams
  it creates for itself, what each QoS level actually costs, and the replica count derived from your
  `routes` list.
- [[websocket]] — a WebSocket connection *is* a NATS connection; origin checking is not access
  control, the four cookie settings, and the listener a leaf node can dial.
- [[object-store]] — a bucket is the stream `OBJ_<bucket>` holding chunks and info in two subject
  spaces; 128 KiB chunks, SHA-256 digests, and the features that do not exist. Plus the write
  ordering that makes a failed put safe, links and the silent `UpdateMeta` discard, what a soft delete
  really costs on disk, and the leafnode boundary an object bucket **crosses** when a KV bucket
  does not.
- [[ordered-consumer]] — the ephemeral, memory-backed, R1 client construct that rebuilds itself on a
  gap, and the consumer churn it produces.
- [[priority-groups]] — `overflow`, `pinned_client` and `prioritized`; the `Nats-Pin-Id` protocol,
  the `423`, and the `failover` option that does nothing on 2.14.
- [[message-ttl]] — `Nats-TTL`, subject delete markers, the silent TTL clamp, and the marker kinds
  that are documented but unimplemented.
- [[message-scheduling]] — the stream publishes for you: `allow_msg_schedules` and the two fields it
  silently changes, `@at` in 2.12 and cron in 2.14, six-field cron and the `10189` with four causes,
  the atomic cancel and its `10212`, and why retention decides whether a schedule ever fires.
- [[account]] — the absolute boundary: `$G` and `$SYS`, per-account JetStream, why a cross-account
  request fails as `No responders`, and the three `no_auth_user` traps.
- [[publishing]] — what a `PubAck` proves and what it does not; `Nats-Msg-Id` and the two-minute
  duplicate window as the honest limit of "exactly once"; the async order trap; and the four publish
  modes, including atomic batch (2.12) and fast ingest (2.14).
- [[subject-transforms]] — rewriting the subject a message is stored under, deterministic sharding
  with `{{partition(n,1)}}`, and republish with its five headers and its `10052` cycle check.
- [[direct-get]] — the point read answered by any replica: `allow_direct`, the two subjects, batch
  and `EOB`, and why it can never confirm a write.
- [[mirrors-and-sources]] — exact read-only copy vs merged aggregate; `Lag` as your RPO, the four
  `mirror_direct` rules, and the two failures that are completely silent.
- [[subject-permissions]] — the two rules that govern every grant: an `allow` list closes everything
  else, and deny beats allow. Plus the three denials that are completely silent.
- [[operator-mode]] — the operator → account → user trust chain: three signature checks per
  connection, scoped signing keys, revocation windows, and why nothing takes effect until you push.
- [[auth-callout]] — authentication delegated to a service you run. What the server signs, what it
  pins, and the fact that it verifies **nothing** the client presented.
- [[tls-in-nats]] — one `tls {}` block per connection type and none of them inherit; `verify_and_map`
  as an identity, TLS-first, and the at-rest key.
- [[cross-account-sharing]] — exports and imports, the two halves that fail differently, and the two
  undocumented routes to a stream or KV bucket in another account.
- [[leafnode]] — the server that dials *out* and bridges interest over one connection; the only layer
  that can draw a boundary, and only with an account behind it.
- [[gateway]] — cluster to cluster. Interest-based forwarding, the gossip that hides your typo, and
  geo-affinity as it is actually implemented: an exclusion list over queue-group names.
- [[jetstream-domain]] — the `$JS.<domain>.API.>` mapping that makes one JetStream separately
  addressable from another, and the three outcomes across a leafnode.
- [[choosing-a-topology]] — route, gateway or leafnode: the four properties that decide it, the
  ladder, and the three cases where the ladder is the wrong answer.
- [[stream-compression]] — `compression: s2` on a file stream: whole blocks, never the tail, no
  ratio metric — and why changing it on a live stream does nothing until the store restarts.

## Internals

*How the server does it, included only where it explains something you can observe.*

- [[raft-in-nats]] — meta group vs per-asset groups, the 4–9 second election window, append →
  commit → apply, and the stepdown commands.
- [[meta-layer]] — the one Raft group a cluster runs about itself: what it stores, why a stream
  with no record in it is deleted 30 s after a join, the constants nobody can tune, a survivor that
  claims leadership for 10 s, the request that timed out and landed anyway, and the peer that
  rejoins five minutes after you removed it. Read from the source and run on 2.14.6.
- [[stream-placement]] — `server_tags`, tag intersection, and the two causes of
  `no suitable peers for placement` (10005).
- [[js-api]] — `$JS.API` request-reply, paged listings, the `code` / `err_code` / `description`
  envelope, and why you must never match on error text.
- [[filestore-layout]] — what a file stream writes under `store_dir`: the 30-byte record overhead,
  the three block sizes the server picks for you, why a delete makes the file *bigger*, the last
  block that is never compacted, and `index.db` at `len(subject) + 4` per subject.

## Operations

**Runbooks**

- [[install-nats-server]] — one server as a service you can reload, drain and monitor: the config
  that earns its lines, the unit the repo actually ships, Docker and Helm, and what to verify.
- [[build-a-3-node-cluster]] — routes, gossip and one seed; the two ways a cluster silently fails to
  form, TLS on the route port, and the five checks that prove it worked.
- [[upgrade-a-cluster]] — the rolling upgrade: lame-duck drain, non-leaders first and the meta-leader
  last, the gate on every replica reading `current`, and the per-version hazards and downgrade floors.
- [[reload-server-config]] — change policy without a reconnect: validate, SIGHUP, verify. What a
  reload can and cannot change, and the Kubernetes sidecar that does the signalling.
- [[rebalance-streams]] — adding a node moves nothing. Grow a peer set, move a replica off a server,
  retire one — **one change at a time**, gated on a named leader and zero lag.
- [[backup-and-restore-jetstream]] — the snapshot: what it holds, how to restore it somewhere else at
  a different size, and why a **memory stream fails with `snapshot failed: no impl`**.
- [[disaster-recovery]] — which copy to reach for, and the five-step promotion of a mirror into a
  writable primary. `Lag` is the RPO; the meta-quorum precondition is decided at design time.
- [[backup-and-restore-identity]] — the operator, accounts, seeds and `server.conf`. Sealed with a
  curve key, and the re-push into the server's resolver that a naive restore forgets.
- [[set-up-operator-mode]] — operator, accounts, scoped keys, creds and a resolver, in the order that
  works; gated at every step, because the failures here produce no error anywhere.
- [[run-nats-behind-a-proxy]] — the nginx block, the two timeouts that decide whether idle
  subscriptions survive, `advertise`, and the `/leafnode` path a proxy has to route.
- [[rotate-tls-certificates]] — replace a certificate before it expires, and find out how long you
  have: `tls_cert_not_after` per listener, and `nats account tls` across the whole chain.
- [[cross-domain-sourcing]] — copy a stream between JetStream domains: the `external` block, the
  prefix the CLI builds for you, and the export types that fail silently.
- [[evict-a-sick-server]] — a server that is up but unhealthy: move leadership, peer-remove it
  (and why that undoes itself in five minutes), kick its clients one cid at a time through the sick
  server itself, and let the platform do the rest. The thread that asked was never answered.

**Sizing**

- [[jetstream-sizing]] — disk, RAM, CPU and FDs for a JetStream node; the `30 + len(subject)`
  per-message record cost and the block-size slack, the JetStream storage defaults, the
  `replicas × bytes` account rule, a worked example, and IOPS as the one term still unsourced.

**Patterns**

- [[worker-pool]] — many processes on one consumer: demand-based distribution, `max_ack_pending` as a
  *shared* ceiling, and why this is not a queue group.
- [[dead-letter-queue]] — there is no DLQ, deliberately: capture the max-deliveries advisory,
  direct-get the original by sequence, republish. The advisory carries no payload and never will, and
  with nobody fetching nothing is ever dead-lettered.
- [[multi-region-jetstream]] — one hub cluster, leaf regions with their own domains. Why a
  super-cluster couples every region's availability, and what the shape costs you.
- [[how-clients-reach-a-cluster]] — seed URLs versus what the server advertises: the three designs
  (discovery on, one VIP with `no_advertise`, per-node `client_advertise`), and why Kubernetes ships
  with discovery off.
- [[kubernetes-storage]] — one PVC per replica on block storage, never `hostPath` and never NFS; the
  chart values that implement it, and the `max_file_store` ceiling the chart sets equal to the volume.

## Gotchas

*Symptom-first: what you see → why → the fix.*

- [[no-suitable-peers-for-placement]] — `10005` on a create or a replica increase: five causes, and
  the debug-log line that is the only way to see the server's reasoning.
- [[streams-deleted-when-clustering-a-standalone-server]] — the restart that destroys your data.
  Read it before the restart; there is no flag and no window to react in.
- [[jetstream-slows-as-consumers-grow]] — the ~100k consumer and ~300 filter thresholds, the
  `consumer info` control loop, and how to design consumers away.
- [[slow-consumer-detected]] — what the log line does *not* tell you. **No confirmed fix**; the
  public thread is unanswered.
- [[maximum-messages-exceeded]] — `10077` on publish: a `discard: new` stream at its limit refuses
  every write and **logs nothing**. The four ways out, and which one keeps the data.
- [[unauthenticated-clients-still-connect]] — you added a system account and the door is still open.
  The server fabricates a `$G` user and advertises `auth_required: true` anyway.
- [[jetstream-out-of-disk]] — `10047` / `10028` compare **reservations**, not usage. Three failures
  wear the same words, and two of them happen with the volume nearly empty.
- [[stream-directories-disappear]] — every stream still listed, most directories gone. `store_dir` on
  tmpfs, and a distribution reaper doing its job.
- [[malformed-or-corrupt-message]] — a corrupt Raft WAL, a fresh volume that re-corrupts, and why
  `JetStream out of resources` appears with 94% of the disk free.
- [[streams-not-visible-across-a-leafnode]] — extending JetStream needs the system account **and**
  matching domains. Different domains is the other supported answer, and the server guards the
  middle case.
- [[stream-has-high-message-lag]] — 10,000 accepted-but-unapplied proposals on the leader, plus the
  table of neighbouring JetStream warnings and what each one measures.
- [[kv-watchers-stall-the-cluster]] — 1000 watchers on a 118-byte bucket. Churn, not count. **No
  confirmed fix**; the thread is unanswered.
- [[nats-timeout]] — the client's own error, which the server never sends and never logs. Including
  the API queue that drops every pending request without a reply.
- [[duplicate-messages-across-a-leafnode]] — a window of sequences replayed, not one message. A leaf
  bridging into a supercluster twice, and why `deny_imports` "fixing" it is the diagnosis.
- [[supercluster-slows-when-a-remote-subscriber-joins]] — 80,000 msg/s becomes 2,000 in the *local*
  region. Geo-affinity covers queue groups only, and the producer is stalled by its slowest link.
- [[object-store-list-is-slow]] — `nats object ls` blows out while uploads run. **No public source
  answers this**; measured instead — object count is nearly free, concurrent writes are not, and a
  list is an ephemeral consumer created per call.
- [[consumer-slow-on-a-sparse-stream]] — a consumer on a **mirror** crawls on file storage while the
  memory mirror and the origin fly; the mirror's catch-up takes 3–4× longer while consumers read it.
  Cause 1: a filter that matches everything on a stream with no subjects and a sequence space that
  is mostly interior deletes (the KV hot-key shape) — measured 6.5–9.4× on 2.14.6, 65× in the
  public report. Cause 2: readers during catch-up — gate them on `Lag` 0; unanswered upstream.
- [[jetstream-recovery-is-slow]] — `Restored N messages for stream … in 6m38s` after a *clean* shutdown,
  with `Healthcheck failed` repeating under it. Five causes ranked: a stream with `sources` scanning
  itself backwards for an idle or empty source at every start (2.10–2.14, gone with `sources.db` in 2.15;
  the public thread is unanswered and its own goroutine dump says so), an unclean stop or a refused
  `index.db` (the five warnings that say which), more than a million subjects, a slow volume, and
  pre-2.11.11 serial recovery — measured on 2.14.6: 3–27 ms clean, 6.4 s after SIGKILL, 2.57 s for a
  1.6 GB sourcing stream with one empty source and 23 ms without it.
- [[consumer-keeps-redelivering]] — `tries: 2` on messages the handler acked, the floor not moving, and
  **nothing in the server log**. Five causes ranked: an ack deadline shorter than the work — including a
  `backoff` whose first entry replaced `ack_wait`, in nanoseconds on the API, so `[10000]` is `Ack Wait:
  10µs` and every acked message is processed `max_deliver` times (measured on 2.14.6: exactly twice);
  a pull batch the workers cannot drain in time; no ack on the success path; a nak loop with
  `max_deliver: -1`; and a table of server versions that redelivered acked messages (2.11.0–2.11.4
  `last_per_subject`, fixed 2.11.5; before 2.11.3 after a leader change; before 2.10.17 on rollouts;
  2.14.0 drifted state). The wiki's last wanted page, closed 2026-09-03.
- [[stream-leader-keeps-moving]] — six causes ranked, from a peer that went quiet for ten seconds to a
  peer-removed server rejoining; the advisory that reports a flap but not its cause; and the one
  public quorum-loss report (gh#7533) mapped line by line, with the part nobody has explained.

## Reference

*Lookup tables: defaults and limits, config keys, `$JS.API` subjects, monitoring endpoints.*

- [[defaults-and-limits]] — every default the server uses when you set nothing, each read from the
  v2.14.6 source with file and line, or from a cited docs page.
- [[config-keys]] — the keys that matter for running a server, by block, with **reload vs restart**;
  the full 621-key table is `inbox/config-keys-table.md`.
- [[js-api-subjects]] — the 32 documented `$JS.API` subjects, which need the system account, and
  three that the API index omits.
- [[error-codes]] — the `err_code` model, why `description` is not the API, and the codes this wiki
  cites.
- [[monitoring-endpoints]] — the 15 HTTP endpoints and their query parameters, plus the fields
  worth naming in `/varz`, `/connz`, `/routez`, `/jsz` and `/healthz`.
- [[advisories]] — every `$JS.EVENT.ADVISORY` subject **read from the server source**, the `$SYS`
  connect/disconnect events, and the four worth alerting on.

## Entities

**Repos**

- [[nats-server]] — the one binary the whole wiki is about: CNCF, Apache-2.0, the Trail of Bits audit,
  and the source this wiki quotes defaults from.
- [[nats-architecture-and-design]] — the 54 ADRs: the specification layer between the docs and the
  source, and where client-side behaviour is defined at all.
- [[jsm-go]] — the JetStream management library under the `nats` CLI, NACK and Terraform, and the
  canonical home of the JetStream API JSON schemas the docs are generated from.
- [[orbit]] — `synadia-io/orbit.*`: the seven extension repos, and the versioning contract that
  keeps opinionated helpers out of the core clients.
- [[nats-streaming]] — STAN, archived and replaced by JetStream. Kept so a search for it lands here.

**Clients**

*Tier 1 — "track new server features at release".*

- [[nats-go]] — the reference implementation, and the parity target the other clients name.
- [[nats-js]] — the v3 mono-repo: Node/Bun, Deno and the browser, with the base client split into
  modules.
- [[nats-py]] — `nats-py` today, a modular `nats-core` (Python 3.13+) in progress; the docs name
  neither.
- [[nats-java]] — the artifact is `io.nats:jnats`, not the repo name.
- [[nats-rs]] — `async-nats`: stable API on 0.x versions, and the `chrono` feature that poisons a
  whole build.
- [[nats-net]] — v3 added OpenTelemetry and **dropped .NET 6**.
- [[nats-c]] — the FFI and embedded client; a port of the Go client's semantics, with no support
  matrix.

*Tier 2 — "may lag behind on new server features".*

- [[nats-zig]] — pre-1.0; no Object Store, no mTLS.
- [[nats-swift]] — **Core NATS only**; JetStream, KV, Object Store and Services are roadmap.
- [[nats-pure-rb]] — the preferred Ruby client, thread-safe, no EventMachine.
- [[nats-rb]] — legacy Ruby, no release since 2019. Use [[nats-pure-rb]].
- [[nats-ex]] — Elixir, published to hex as **`gnat`**, MIT-licensed.

**Tools**

- [[nats-cli]] — `nats`: the tool an operator lives in. Contexts, streams, consumers, `server check`,
  `server report`, `bench`, and `nats auth`.
- [[nsc]] — the standalone identity CLI; same on-disk store as `nats auth`, and the two things
  `nats auth` cannot do yet.
- [[nk]] — nkeys: Ed25519, the prefix letters, and why the server never holds a private key.
- [[nats-top]] — one server, live: who is the noisy connection, and the slow-consumer counter.
- [[nats-box]] — the container with `nats`, `nsc`, `nats-top` and `nk` in it; the CLI's deployment
  vehicle on Kubernetes.
- [[prometheus-nats-exporter]] — the monitoring port as Prometheus metrics; why `-prefix nats`
  is not optional.
- [[nats-surveyor]] — cluster-wide monitoring through the system account, including `/raftz`.
- [[nats-helm-charts]] — `nats-io/k8s`: the StatefulSet, the three probes, the config reloader, and
  the `Parallel` policy you must not "fix".
- [[nack]] — streams and consumers as CRDs; the ~30-second resync, `--control-loop`, and the KV
  trap.

**Releases**

- [[nats-server-2.14]] — current stable (v2.14.6, 2026-08-27). Batch publish, cron schedules,
  consumer reset, WorkQueue/Interest sourcing, Raft overrun protection, and the `$JS.ACK` v2
  deadline.
- [[nats-server-2.12]] — atomic batch publish, counters, schedules, `prioritized` policy, strict
  JetStream API on by default, elastic filestore pointers. Downgrade floor **v2.11.9**.
- [[nats-server-2.11]] — stream API level 1, per-message TTL, priority groups, KV limit markers.
- [[nats-server-2.10]] — the floor for KV/Object Store compression, sources and mirrors.
- [[nats-server-2.15-preview]] — unreleased; the one thing to act on now is the `$JS.ACK` v2
  default.

**Products**

- [[synadia-products]] — the five commercial offerings, and which operational problem each removes.
  Deliberately thin.

**Organisations**

- [[synadia]] — the maintainer: who defines the client tiers, why `synadia-io` is a separate org.
- [[cncf]] — NATS is a CNCF project, **Incubating since 2018-03-15**; what that does and does not
  claim.

**People**

## Summaries (one per ingested source)

**docs.nats.io — JetStream (learn)**

- [[s-docs-delivery-and-acknowledgment]] — the ack/redeliver loop, ack floor, double ack,
  out-of-order redelivery.
- [[s-docs-acknowledgment]] — ack / nak / term / in-progress, `ack_wait`, `max_deliver`, backoff,
  the three consumer advisories.
- [[s-docs-pull-consumers]] — fetch vs consume, `batch` and `expires`, `408`/`404`,
  `max_ack_pending` vs batch size.
- [[s-docs-retention-policies]] — the three retention values, the WorkQueue consumer rules
  (10099 / 10100), Interest filling the disk.
- [[s-docs-publishing]] — the `PubAck`'s three fields, why a timeout means "unknown" and
  `no responders` means "nothing stored", and the two-minute duplicate window stated in prose.
- [[s-docs-advanced-publishing]] — async, atomic batch and fast ingest: the `Nats-Batch-*` headers,
  the ten-second stall that abandons a batch silently, the `gap: ok` mode that loses data by design,
  and the `persist_mode: async` incompatibility.
- [[s-docs-shaping-the-stream]] — the three limits as independent ceilings, `max_age` as the one that
  never rejects a publish, and the third rejection string.
- [[s-docs-altering-stream-state]] — `rmm` securely erases where `DeleteMsg` does not, purge does not
  rewind the counter, and a sequence is a stable address.
- [[s-docs-subject-mapping]] — the transform language, deterministic partitioning, republish's five
  headers, and the loops the server cannot always catch.
- [[s-docs-reading-back]] — stream sequence vs consumer sequence, the metadata that rides on every
  message, and `replay: original`.
- [[s-docs-filtering]] — a filter that matches nothing fails silently, and the two meanings of
  "overlap".
- [[s-docs-kv-under-the-hood]] — the `KV_<bucket>` stream config as the server prints it, the literal
  direct-get subject, and the hole `deny_delete` does not close: a raw publish.
- [[s-docs-kv-watching]] — snapshot-then-live, the end-of-initial-data signal in five client shapes
  (Rust has none), and why `widget-*` matches nothing.
- [[s-docs-kv-history-and-revisions]] — the revision counter is **bucket-wide**, and CAS is two
  operations: `create` against revision 0, `update` against a named one.
- [[s-docs-kv-ttl-and-limits]] — per-key TTL is create-only and a later `put` silently makes the key
  permanent; the three bucket limits reject rather than evict.
- [[s-docs-kv-your-first-bucket]] — `--history 1` is the default, and bucket names have a narrower
  charset than keys.
- [[s-docs-object-store-your-first-object]] — put writes chunks then metadata, and that ordering is
  the durability contract: an interrupted put leaves no gettable object, never a truncated one.
- [[s-docs-object-store-chunking]] — the 128 KB default with both its bounds, the guidance ADR-20
  never gave, and orphan chunks: the store's one silent disk leak.
- [[s-docs-object-store-metadata-and-links]] — `ObjectInfo`'s three caller-set fields, links as
  snapshots that dangle, and the two fields `UpdateMeta` discards without telling you.
- [[s-docs-object-store-watching-and-listing]] — watch carries metadata and never the bytes; and,
  read for Q75, a **negative result**: the page says a list is cheap and never mentions concurrency.
- [[s-docs-object-store-under-the-hood]] — `OBJ_<bucket>`, the two `$O.` subject spaces,
  `Nats-Rollup: sub` as the whole latest-wins mechanism, and soft delete as a rollup.
- [[s-docs-mqtt-your-first-mqtt-client]] — `nats-server` is the MQTT broker; JetStream is a startup
  requirement and a per-account one, and an `mqtt {}` block with no port is a silent no-op.
- [[s-docs-mqtt-topics-and-subjects]] — the full topic→subject escaping, the six refused characters,
  and why a permission written `sensors/#` matches nothing.
- [[s-docs-mqtt-qos-sessions-and-retained]] — the QoS contract, sessions keyed by client id, wills,
  retained messages — and the 63/31 subscription ceiling `max_ack_pending` implies.
- [[s-docs-mqtt-auth-and-clustering]] — `allowed_connection_types`, the bearer JWT an MQTT device
  sends as its password, `$MQTT.sub.>` (allow nothing, deny nothing), and replicas derived from
  `routes`.
- [[s-docs-websocket-your-first-websocket-connection]] — the listener that requires TLS, the port
  that has no default, and nats.js filling in a port that is never 4222.
- [[s-docs-websocket-browsers-and-origins]] — `allowed_origins` is an exact string match **and is
  skipped when no `Origin` header is sent**; the four cookie settings and what each is for.
- [[s-docs-websocket-tls-and-proxies]] — the nginx block, the idle timeout against the ping interval,
  `advertise`, and the reload rule that loses your whole edit.
- [[s-docs-websocket-leaf-nodes-over-websocket]] — a leaf through the HTTPS ingress: the `/leafnode`
  path, `LEAFNODE_WS`, and why the scheme does not tell you whether a link is encrypted.
- [[s-docs-monitoring-advisories-and-events]] — advisories are published once and stored nowhere,
  there is **no dead-letter queue**, and the `$SYS` connect/disconnect and `STATSZ` events.
- [[s-docs-monitoring-jetstream-health]] — lag as arithmetic, the three numbers that get confused, and
  the three-field signature of a crashed consumer pool.
- [[s-docs-monitoring-profiling]] — `nats server request profile` over `$SYS` with its 15-second CPU
  cap, against `prof_port` which needs a restart and has no authentication.
- [[s-docs-policies]] — the nine stream and consumer policies and which five are fixed at creation.
- [[s-docs-surviving-node-loss]] — R=1/R=3/R=5, odd counts, storage durability, consumer replica
  rules, replicas ≠ throughput.
- [[s-docs-sizing-and-resources]] — the four resources a node spends, the real JetStream storage
  defaults (75%, not 256MB/1TB), and how R3 counts against an account's `MaxStore`.

**docs.nats.io — Clustering (learn)**

- [[s-docs-raft-and-leaders]] — RAFT groups, the meta group, election timings, stepdown.
- [[s-docs-replication-and-r3]] — quorum commit, what a `PubAck` proves, `sync_interval` and the
  divergence scenario.
- [[s-docs-placement]] — placement levers, tag intersection, `no suitable peers for placement`.

**docs.nats.io — Reference (generated schemas)**

- [[s-docs-stream-config]] — every `StreamConfig` field with its range and default.
- [[s-docs-consumer-config]] — the `$JS.API.CONSUMER.CREATE` subject and the observable
  `ConsumerInfo` fields.
- [[s-docs-connection-limits-config]] — `max_payload`, `max_pending`, `max_connections`,
  `max_subscriptions`: the 8MB/64MB rule and their reload behaviour.
- [[s-docs-monitoring-endpoints]] — the only prose source for the monitoring port; `slow_consumers`,
  `/connz?sort=pending`, and why an unscoped `/jsz` times out.
- [[s-docs-monitor-raftz]] — the 173-byte reference page three learn chapters call "the full field
  set": two request options, no response fields.

**nats-server source**

- [[s-nats-server-constants-2.14.6]] — the defaults the docs do not state, read from the tagged
  source with file and line.
- [[s-nats-server-systemd-units]] — the two units in `util/`: `ExecStop` is a **SIGUSR2 lame-duck
  drain**, `TimeoutStopSec=150` is `lame_duck_duration` plus buffer, `LimitNOFILE=800000`.
- [[s-nats-server-route-cluster-formation]] — the cluster-name check on both sides of a route, and
  the dynamic-name case the docs omit: an unset name is **adopted**, not rejected.
- [[s-nats-server-signals]] — what each signal does, including `SIGTERM` during a drain, and the
  `--signal` name that sends **SIGKILL**.
- [[s-nats-server-lame-duck]] — the drain as implemented: the JetStream work happens **before** the
  timer, the spread is `duration − grace`, and the per-client interval is capped at one second.
- [[s-nats-server-snapshot-restore]] — the snapshot clamps, the two restore checks, and the `no impl`
  a **memory** stream returns instead of the documented message.
- [[s-nats-server-auth-and-tls]] — the real auth and TLS timeout defaults, `tls_cert_not_after`, the
  certificate-to-user mapping order, the credentials auth callout does **not** check, and the `$G`
  user the server invents.
- [[s-nats-server-jetstream-resources]] — what "out of storage" actually means: the 75%-of-**free**
  disk default, `finalizeDynamicMaxStore` (new in 2.14.6), what `10047` compares, and the
  out-of-space handler's two callers.
- [[s-nats-server-raftz]] — `/raftz` read from `monitor.go` and run: every field, the `acc` filter
  that defaults to the system account, and the sweep that found six monitor reference pages printing
  request names the HTTP endpoints ignore.
- [[s-nats-server-kick-ldm-mqtt-session]] — the two per-client system requests (`KICK` disconnects,
  `LDM` only informs) run against a live client, and the conditional publish behind an MQTT
  session's `wrong last sequence: 0`.
- [[s-nats-server-jetstream-cluster]] — the meta layer read at v2.14.6 and then run: no replica
  count, quorum `size/2+1` over every JetStream server (gateways included), the 30-second orphan
  check, the 10-second lie of a leader that lost its followers, the fate of a timed-out proposal,
  the five-minute rejoin after a peer-remove, and the docs' wrong peer-remove subject.
- [[s-nats-server-filestore-layout]] — the filestore read at v2.14.6 and then measured on the
  binary: `30 + len(subject)` per message, the block-size clamps, the never-compacted last block
  (8.5× on an idle stream), `index.db` per subject, and `max_file_store` bounding a logical figure.
- [[s-nats-server-leafnode-js-domains]] — the three outcomes of a leafnode carrying JetStream, the
  `$JS.<domain>.API.>` mapping table, and the server's explicit guard against two identical domains.
- [[s-nats-server-jetstream-log-warnings]] — every JetStream warning this wiki quotes, with its
  threshold and what the server does next; including the API queue that drains without replying.
- [[s-nats-server-topology]] — the topology layer: no default port on any of the three listener
  blocks, the system account a composed server must have, geo-affinity as an exclusion list, the
  fast-producer stall and its two counters, and what a leafnode user may carry.
- [[s-nats-server-tls-reload]] — eight runs on the v2.14.6 binary settling whether a reload picks up
  a renewed certificate: it does, on a client listener and on a leafnode remote, in both shapes of
  the change — but the log lines, `config_digest` and the signal's exit status say nothing either
  way, and a refused reload looks identical to a successful one.
- [[s-nats-server-object-store-observed]] — nine runs on the v2.14.6 binary: the 128 KiB default
  derived from an exact chunk count, the raw metadata message with its rollup header and zero
  `mtime`, a 200 MiB delete giving back **98.4 % of the disk at the call**, the four `$JS.API` calls
  a list makes, and the Q75 measurement — object count is nearly free, concurrent writes are not.
- [[s-nats-server-object-store-leafnode]] — the leafnode JetStream deny list names `$OBJ.>` and the
  object store uses `$O.`, so object data crosses a domain boundary that KV data does not; a
  same-named bucket on both sides of a leafnode silently converges. Docs issue #35.
- [[s-nats-server-monitoring-observed]] — what `/varz` `cpu` and `/connz` `rtt` really measure, read
  at v2.14.6 and run: `cpu` is a percentage of **one core**, a client's `rtt` is the connect-time
  estimate refreshed at most **hourly**, and the nak advisory subject captured **on the wire**.
- [[s-nats-server-mqtt-websocket-observed]] — fifteen runs on the v2.14.6 binary with a hand-written
  MQTT 3.1.1 probe: the **five `$MQTT_*` streams** no source names, what QoS 0/1/2 each cost, the
  dedup record an abandoned QoS 2 handshake leaks, stale sessions pinning QoS 1 messages forever, all
  ten conversion rules, the 63/31 ceiling, the origin table including the no-`Origin` row, and MQTT
  replicas derived from `routes`.
- [[s-nats-server-defaults-sweep]] — all 216 documented defaults compared with the source at
  v2.14.6: leafnode compression is `s2_auto` and not `accept`, `mqtt.max_ack_pending` is 1024 and
  not 100, `mqtt.port` has no default at all, and why a use-site default is invisible in `/varz`.
- [[s-nats-server-nak-backoff-observed]] — thirteen runs on the v2.14.6 binary settling what a nak
  actually waits: a **bare** nak is immediate with or without a `backoff`, but a nak carrying a delay
  waits `delay + (backoff[dc] − backoff[0])`, `-NAK {}` is not a bare nak, and `ack_wait` beside a
  `backoff` is silently overwritten. Docs issues #38 and #39, server issue SI-2.
- [[s-nats-server-message-schedules-observed]] — the message scheduler run rather than read: every
  ADR-51 rule held, ten error codes pinned to their conditions, the two header rows the docs get
  wrong, `nats pub` without `-J` hiding a rejection, and `--schedule-after` broken at CLI 0.4.0.
- [[s-nats-server-meta-layer-rerun-observed]] — the meta-layer run repeated through `tools/lab/`: the same
  bootstrap, restart and stepdown numbers by a different route, the same peer ids on a purged store, and the
  correction that `Healthcheck failed` is one log line per `/healthz` request, not one a second.

**The `nats.go` client source**

- [[s-nats-server-jetstream-log-warnings|(see above)]] for the server side; the client error strings
  `nats: timeout` and `nats: no responders available for request` are quoted from
  `raw/nats-go-src/errors-v1.53.1.md` on [[nats-timeout]].

**Synadia blog**

- [[s-synadia-jetstream-memory-patterns]] — what JetStream actually holds in RAM, and the
  2-minute deduplication window default.

**ADRs — `nats-architecture-and-design`** (one row per ADR in `inbox/adr-toc.md`)

- [[s-adr-1-jetstream-json-api]] — the `$JS.API` shape: subjects, paging, schemas, the error
  envelope, wire units.
- [[s-adr-7-server-error-codes]] — the `err_code` numbering, `server/errors.json`, and why
  `description` is not part of the API.
- [[s-adr-8-key-value-store]] — the stream a KV bucket is, and its delete/purge/watch mechanics.
- [[s-adr-10-extended-purge]] — purge is three operations behind one subject: `filter`, `seq`,
  `keep`, what the server rejects, and what a purge does *not* reset.
- [[s-adr-17-ordered-consumer]] — the ordered consumer's forced configuration and restrictions.
- [[s-adr-20-object-store]] — the stream an object-store bucket is, chunking and digests.
- [[s-adr-31-direct-get]] — the Direct Get spec: subjects, the `_sys_` queue group, headers, status
  codes, and the four `mirror_direct` alignment rules.
- [[s-adr-35-filestore-compression]] — block-level S2: why blocks and not messages, the on-disk
  header, and the one sentence about live changes that the server contradicts (docs issue #30).
- [[s-adr-40-nats-connection]] — the connection spec: `INFO`/`CONNECT`, TLS-first since 2.10.4, the
  reconnect algorithm and client defaults, and the discovery section that is still a TODO.
- [[s-adr-42-priority-groups]] — the three priority policies and the pinned-client protocol.
- [[s-adr-43-per-message-ttl]] — `Nats-TTL`, markers, the clamp, and seven error codes.
- [[s-adr-48-kv-ttl]] — KV limit markers: one setting, two stream fields, a 1-second floor, and why
- [[s-adr-51-message-scheduler]] — the message scheduler's only real specification: the header family,
  six-field cron, time zones as a tzdata dependency, the retention table and the two-stream shape for
  interest retention.
  there is no TTL on `Put`.
- [[s-adr-54-kv-codecs]] — *Proposed*: keys are subjects, nothing escapes them for you, and what a
  client-side codec costs you in `nats kv ls` and in a watcher.
- [[s-adr-57-kv-subject-transforms]] — *Proposed*: why a KV mirror always has `mirror_direct`, the
  generated `$KV.<src>.>` transform, and how a plain stream becomes a KV source.
- [[s-adr-59-sourcing-and-mirroring]] — the authoritative sourcing/mirroring spec: the config
  surface, `10029`/`10045`, `Nats-Stream-Source`, `/jsz?direct-consumers=true`, and why WorkQueue and
  Interest upstreams were "not recommended".
- [[s-adr-60-reliable-sourcing]] — 2.14's answer to that: durable `JS_MIRROR_*` / `JS_SRC_*`
  consumers, `AckFlowControl`, the consumer reset API, and the API level 4 requirement.
- [[s-adr-61-meta-quorum-rescue]] — 2.15's `$JS.API.META.RESCUE`: quorum is computed from the
  configured peer set, and what to do when that wedges the meta layer.

**Release notes and upgrade guides**

- [[s-docs-upgrade-to-2.12]] — 2.11 → 2.12: strict mode, elastic pointers, the v2.11.9 downgrade
  floor.
- [[s-docs-upgrade-to-2.14]] — 2.12 → 2.14: the `$JS.ACK` v2 deadline, frozen streams on filestore
  I/O errors, Raft overrun protection.
- [[s-relnotes-2.14.0]] — the v2.14.0 changelog with PR numbers, including the items the upgrade
  guide omits.
- [[s-relnotes-2.10]] — the 29 release bodies of the 2.10 line (2023-09-19 → 2025-05-01) read as one changelog:
  defaults and keys that arrived, behaviours that changed, withdrawn releases, the data-integrity
  fixes by release, three CVEs; corrects the subject tree to 2.10.10.
- [[s-relnotes-2.11]] — the 18 release bodies of the 2.11 line (2025-03-19 → 2026-04-27) as one changelog: what
  2.11.0 added, the withdrawn 2.11.2, the 2.11.9 downgrade floor, twelve 2026 CVEs, the keys and
  monitoring fields the docs never name (docs issues #55–#57).
- [[s-relnotes-2.12]] — the 15 release bodies of the 2.12 line (2025-09-22 → 2026-08-12) as one changelog,
  checked against the docs' upgrade guide: API level 2, strict and async flush by default, the 2.12.5
  warning, the 2.12.7 → 2.12.11 regression, `max_concurrent_io`, the same-day 2.14 twins; docs issues #58–#60.

**GitHub discussions**

- [[s-gh-7982-no-suitable-peers]] — a placement failure diagnosed with debug logs.
- [[s-gh-7831-standalone-to-cluster]] — maintainers on why standalone cannot become a cluster
  in place.
- [[s-gh-7533-quorum-loss-mqtt]] — quorum loss after days of stable operation, seen from the MQTT
  bridge on 2.12.1: `10071`, `10008`, publish timeouts, `NO quorum`. Unanswered upstream.
- [[s-gh-6892-evict-a-sick-node]] — a host at 100 % CPU dropped by its peers as a slow consumer and
  still holding its clients for ten minutes. Unanswered upstream.
- [[s-gh-6605-which-consumer-is-slow]] — an unanswered thread, recorded as unanswered.
- [[s-gh-7190-asymmetric-cluster]] — one DNS name as the route address: nodes with **unequal route
  counts** and clients partitioned. Unanswered; the maintainer names the cause.
- [[s-gh-3569-connect-to-route-port]] — `attempted to connect to route port`: the client-port /
  route-port confusion, answered by a maintainer.
- [[s-gh-6070-lame-duck-under-systemd]] — a unit with `ExecStop=… SIGINT` that never drains, and the
  rule that follows: with systemd, stop through `systemctl`.
- [[s-gh-4342-memory-stream-backup]] — "Not currently": the accepted answer on backing up a memory
  stream, plus the file-backed-mirror workaround and the temporarily-R3 restart trick.
- [[s-gh-4535-unauthenticated-connections]] — a system account that reopened the server, the
  maintainer's rule, and the bug fix it turned into (**2.10.2**).
- [[s-gh-7854-jwt-push-timeout]] — an account push that times out with nothing in the log, and a
  maintainer's working `nats auth` sequence.
- [[s-gh-7749-hostpath-jetstream]] — `hostPath` or a PVC for JetStream on Kubernetes, answered five
  months later by a community member and never by a maintainer; the provenance is on the page.
- [[s-k8s-760-jetstream-pvc-per-replica]] — from `nats-io/k8s`: why the chart gives each replica its
  own PVC, and the one public maintainer statement ruling out NFS for JetStream.
- [[s-gh-7684-certificate-expiry]] — why `openssl s_client` returns nothing against port 4222, and
  the `/varz` field that was added because of this thread.
- [[s-gh-7505-auth-callout-nkey]] — no, the server does not verify `connect_opts.nkey`. Treat every
  field of it as a claim.
- [[s-gh-5606-cross-account-jetstream]] — four maintainers, four answers: no cross-account user, no
  JetStream on the system account, and the API-prefix route nothing documents.
- [[s-gh-7017-kv-across-accounts]] — sharing a KV bucket across accounts. **Unanswered since
  2025-06-29**; recorded as evidence about the docs.
- [[s-gh-5044-restrict-durable-consumers]] — why subject permissions cannot forbid durable consumers:
  the durable name is in the payload. **Unresolved.**
- [[s-gh-5924-filestore-dirs-vanished]] — 45 of 50 stream directories gone. `store_dir` on a RAM
  disk, and `tmpwatch` doing exactly what it is for.
- [[s-gh-7463-jetstream-corruption]] — a corrupt Raft WAL on 2.9.8 that "spread back" from healthy
  replicas. One-sentence answer, confirmed fix: upgrade.
- [[s-gh-7834-leafnode-same-js-domain]] — the same JetStream domain on both ends of a leafnode.
  **Unanswered**; the source explains all four observations.
- [[s-gh-6490-high-message-lag]] — `has high message lag`: publishing faster than the system can
  store, with the two named causes.
- [[s-gh-6746-watch-many-keys]] — several KV keys on one watcher; self-answered in an hour.
- [[s-gh-5243-kv-watchers-at-scale]] — 1000 watchers, a 118-byte bucket and a cluster that does not
  recover. **Unanswered.**
- [[s-gh-6836-object-store-list-slow]] — object-store `ls` slow, sometimes timing out, while uploads
  run. One comment, by the asker. **Unanswered since 2025-04-25**, which is why Q75 was measured.
- [[s-gh-7362-routez-connz-rtt]] — the chosen answer ("periodic PING/PONG") omits the period; the
  reporter's "it never updates, even after minutes" is right and gets no reply.
- [[s-gh-7483-varz-cpu-in-containers]] — is `/varz` `cpu` relative to the container's vCPU or the
  host's cores? **Closed with zero comments.** The answer is neither.
- [[s-gh-5859-unexpected-nats-timeout]] — two reports of `nats: timeout`, a ping line that is not a
  symptom, one real routes defect and a `GOMAXPROCS` hypothesis. **Unresolved.**
- [[s-gh-6328-jetstream-behind-gateways]] — "you don't even need a super-cluster": a maintainer
  routes a regional read replica to leafnodes and sourcing.
- [[s-gh-7438-multi-region-availability]] — one hub cluster, leaf regions, one JS domain each. The
  architecture is answered; **both questions about the downsides are not**.
- [[s-gh-7881-cross-domain-sourcing]] — the exact question the docs cannot answer, **with no
  maintainer reply**, and the `service import not authorized` error that names the missing export.
- [[s-gh-8417-kv-mirror-file-vs-memory]] — the answered thread behind row 76: a KV mirror on file
  storage read 65× slower than on memory because the consumer's `FilterSubject` matched everything
  and a mirror has no subjects, so the file store took the per-subject path across 83 % holes;
  without the filter, 150k+ msg/s. The initial sync's slowness was never explained.
- [[s-gh-8001-jetstream-startup-slow-50m]] — the unanswered thread behind row 13: 50 M messages, 7 GB,
  about twenty sources, 6 min 38 s to restore after a clean shutdown at 20 MB/s of reads; the reporter's
  goroutine dump, which nobody upstream read, shows `startingSequenceForSources` — the source scan.
- [[s-gh-8333-high-cardinality-subjects]] — row 9's maintainer comment: no performance problem with
  a million-plus subjects except RAM for the radix-tree index, "in the order of 100 megs" per million.
- [[s-gh-5202-max-unique-subjects]] — the chosen answer that the per-subject index is an in-memory
  adaptive radix tree since 2.10.9, holding a count and two block indexes per subject; no maximum.
- [[s-gh-7147-one-billion-cap]] — "capped at one billion?": no; a maintainer's stream at 1,174,510,552
  messages, and a reporter's unexplained discards that the thread never reaches.
- [[s-gh-7032-max-msgs-known-good]] — the largest known-good `MaxMsgs`: there is no hard limit; disk
  and the per-subject index are what run out; shard by time when they do (chosen answer).
- [[s-gh-8444-mirror-catchup-under-a-reader]] — the unanswered thread behind row 91: mirror
  catch-up 2.89× slower under one cold-scanning consumer, with a reproduction; one community comment
  argues the file store's lock structure (`SkipMsgs` + `StoreMsg` per live message against readers'
  `RLock`s) and says to start readers at `Lag` 0.
- [[s-issue-5106-object-store-mirror-list]] — the closed issue behind row 105: `nats object ls` on
  a mirrored bucket failed because the client looked the stream up by subject (fixed in nats.go
  2024-02) and because a mirror needs `$O.<origin>.>` → `$O.<mirror>.>`; plus the three client
  issues that say a mirrored object store is still hand-built and "not general-purpose yet".
- [[s-issue-6921-last-per-subject-acks]] — the closed defect behind the wiki's last wanted page: a
  `last_per_subject` consumer with explicit acks on a stream with `max_msgs_per_subject: 5` stops
  registering acks on 2.11.0–2.11.4 (floor frozen, `Outstanding Acks` at the cap), reproduced in .NET
  and Rust, "worked" in Go only while `MaxAckPending: 1` was missing; bisected to fixed in 2.11.5.
- [[s-nats-server-mirror]] — `stream.go` and `filestore.go` at v2.14.6: the `JS_MIRROR_<id>`
  consumer and its config, the 10 s stall check and 2 s retry gate, the gap → `skipMsgs` branch
  (one Raft entry per hole on a replicated mirror), `SkipMsgs` under the write lock, and the
  linear-scan heuristic `mb.fss.Size()*4 > lseq-fseq` — with the `mirror-<id>` names at v2.10.0
  and v2.12.0 for docs issue #49, and the stream's 100,000-message inbound queue cap.
- [[s-nats-server-mirrors-observed]] — the three runs on 2.14.6: a mirror's sync in 1.24 s (file)
  and 0.74 s (memory) for 400k live over 2.4 M sequences; 267,866 vs 1,740,462 msg/s with and
  without the everything-matching filter on the file mirror, no gap on memory or on the origin;
  three readers making catch-up 3.4–3.9× (file) and 3.1–3.4× (memory) slower; an object bucket
  mirrored across two domains, empty without the transform and whole with it; a same-domain KV
  mirror unreadable by its own name; an un-acked flood dropped at the stream's inbound queue.
- [[s-nats-server-filestore-recovery]] — the recovery path at v2.14.6 with line numbers: the two
  timers, `recoverFullState`'s four checks and five `Stream state …` warnings, the block-by-block
  fallback, when `index.db` is written and when the write is skipped, the three uses of the 1,000,000
  threshold, and `startingSequenceForSources`, the backward scan a sourcing stream makes at every
  start — inline on R1, deferred on R3 — with PRs #8282 / #8516 and the release lines that fix it in 2.15.
- [[s-nats-server-stream-scale-observed]] — a 50 M-message stream restarted six ways (3–27 ms clean,
  6.4 s after SIGKILL, 9.5 s with `index.db` deleted), a 1.6 GB sourcing stream at 2.57 s with an
  empty source and 23 ms without, 1.2 M subjects at ~380 B of RSS each and no periodic `index.db`,
  `--max-msgs 10000000000` accepted, and a `*` inside a token that pending counts and delivery disagree on.
- [[s-nats-server-redelivery-observed]] — runs G, H and I on 2.14.6: issue #6921's recipe delivering
  once each with the floor following; a redelivery loop as `tries:`, `consumer info`, the JSON counters
  and the `-DV` trace show it, with **nothing** at the default log level; `backoff: [10000]` stored as
  `Ack Wait: 10µs`, a race the ack wins six pulls of seven on localhost and loses every time with 5 ms
  of work — exactly `max_deliver` deliveries per acked message; and a redelivery needing a waiting pull.
- [[s-relnotes-2.14.4]] — the interior-delete release (2026-07-30: #8403, #8405, #8406,
  `max_concurrent_io`, four security fixes), with the mirror and filestore lines of v2.14.1 and
  v2.14.2; the six patch bodies are in `raw/release-notes/`.
- [[s-relnotes-2.11.5]] — where issue #6921 was fixed: `DeliverLastPerSubject` "now correctly deliver
  messages and handles acks when there are interior deletes" (#7005, 2025-06-26), plus Raft on
  monotonic time (#6999) and `healthz` no longer fixing up node skews (#7001).
- [[s-relnotes-2.11.2]] — withdrawn for a regression ("upgrade to 2.11.3 instead"), and the release
  that stopped replicated consumers redelivering acknowledged messages after a leader change, at a
  stated throughput cost; with the 2.10.16 / 2.10.17 lines that fixed the same complaint around
  restarts (#5419, #5482, #5533).
- [[s-relnotes-2.14.1]] — the first 2.14 patch, read for its consumer lines: drifted redelivered state
  on workqueue and interest streams with `max_deliver` (#8102), a consumer store not flushing a deleted
  redelivery (#8168), the pending leak at max deliveries (#8156), and the `/varz` client-only counters.
- [[s-nats-go-kv-object-mirror]] — nats.go v1.53.1: a KV mirror's read prefix is rewritten to the
  origin's only for an `external` mirror (`kv.go:1610–1618`), so a same-domain mirror is unreadable
  by its own name; the object store binds by stream name and derives its subjects from the bucket
  name, so a mirror needs the transform.
- [[s-gh-5941-restrict-leafnode-subjects]] — deny lists, and an accepted answer that has no
  implementation in config mode. The follow-up proving it is unanswered.
- [[s-gh-4823-leafnode-supercluster-duplicates]] — a leaf bridging into a supercluster twice.
  "A Supercluster is a single system", and reach it by DNS.
- [[s-gh-7494-supercluster-degradation]] — 80,000 msg/s to 2,000 when a distant subscriber joins.
  **Unanswered**; the source explains it exactly.
- [[s-gh-6628-ackwait-vs-dupe-window]] — `ack_wait` and the duplicate window "are not related to
  each other"; the asker's real cause was a **pull batch of 100**.
- [[s-gh-6350-exponential-backoff]] — the marked answer that splits retry in two: consumer `backoff`
  for an implicit failure, `nakWithDelay` for an explicit one.
- [[s-gh-4972-nak-with-delay-blocks]] — a delayed nak keeps its `max_ack_pending` slot for the whole
  delay. **Working as designed**, with a maintainer arguing in the same thread that it should not be.
- [[s-gh-5631-nak-not-immediate]] — a nak that redelivered only after the ack timeout, on 2.10.14.
- [[s-so-78603662-acked-but-redelivered]] — row 14's own thread, unanswered: "processed twice despite
  `AckAsync`" was `Backoff = [10000]` — ten microseconds on the wire — becoming the ack deadline, so
  every message is processed `MaxDeliver` times; reproduced on 2.14.6 to the letter.
  **Zero comments in two years**; the wiki answers it from the binary instead.
- [[s-gh-7672-cron-schedules]] — cron schedules are 2.14, and on 2.12 they come back as
  `message schedules pattern is invalid` — a version problem wearing a syntax problem's clothes.
- [[s-gh-7628-scheduler-vs-nak]] — "Nak is not meant for that purpose": use the scheduler, and it
  scales because it is built on the per-message TTL work.
- [[s-gh-4994-scale-to-zero-dlq]] — "We do not have automated DLQs… by design", and the
  scale-to-zero trap: with nobody fetching, `ack_wait` never advances the delivery count.
- [[s-gh-7590-dlq-payload-loss]] — the max-deliveries advisory has no payload, why the maintainers
  resist adding one, and the 2.12.3/2.12.4 R3 defect that made the documented recipe fail.
- [[s-gh-6005-sourcing-memory-stream-restart]] — a sourcing stream stalls after its memory-backed upstream
  restarts: 2.10.19 stopped clipping the start sequence, 2.10.22 reverted it, 2.14 saw it again (#8384 in 2.15).
- [[s-gh-6748-cve-binary-release-docker-images]] — CVE-2025-30215 shipped as binaries a week before the tag;
  the official Docker image is built by Docker's library from a PR and lags.

**Synadia blog (continued)**

- [[s-synadia-jetstream-anti-patterns]] — the ~100k consumer and ~300 subject-filter thresholds,
  why `consumer info` is expensive, and republish / Direct Get as alternatives to consumers.
- [[s-synadia-reliable-delivery-dlq]] — the dead-letter pattern assembled from the max-deliveries
  advisory, a direct get by sequence and a republish; how retention bounds the recovery window. **Two
  of its claims are wrong at 2.14.6** (docs issue #39).
- [[s-synadia-how-many-subjects]] — "roughly a few hundred bytes" per indexed subject, ~10 M ≈ 3–4 GB,
  and the advice to size on consumption pattern (consumers, republish, KV, Direct Get) rather than
  subject count; plus two Insights check definitions, `JETSTREAM_025` (subject count via stream
  metadata) and `JETSTREAM_003` (90 % of `max_msgs`, the sizing formula), undated.
- [[s-synadia-delayed-scheduling]] — the readable account of the message scheduler: the four
  `Nats-Schedule` formats with the version each arrived in, six gotchas, and the target-vs-schedule
  rule the specification omits.

**docs.nats.io — Ecosystem, install and deployment**

- [[s-docs-ecosystem]] — the docs' own map: three client tiers, Orbit, the tooling, the identity
  libraries. The naming authority for every entity page.
- [[s-docs-getting-started]] — install commands and package coordinates, and the two pinned example
  versions that have aged.
- [[s-docs-kubernetes]] — the Helm chart, the three probes, the config-reloader sidecar, and NACK's
  two reconcile modes.
- [[s-docs-prometheus-and-dashboards]] — the exporter's real invocation, the metric names, and the
  health check that passes with no quorum.

**docs.nats.io — JetStream (continued)**

- [[s-docs-get-direct]] — the point read, `allow_direct`, batch with `Nats-Num-Pending`, and the
  three ways it is misused.
- [[s-docs-jetstream-headers]] — the docs' one table of the whole JetStream header space; its
  scheduling rows are the docs' *entire* coverage of the scheduler, and two of them are wrong.
- [[s-docs-worker-pool]] — one consumer many workers, the shared `MaxAckPending` cap, and the queue
  group comparison.
- [[s-docs-mirrors-and-sources]] — mirror vs source, the comparison table, and the export type that
  fails silently.
- [[s-docs-mirrors-as-dr]] — `Lag` as RPO, what an upstream delete really does to a mirror, and why a
  mirror is not a backup.

**docs.nats.io — Topologies, clustering and hardening (learn)**

- [[s-docs-single-server]] — the smallest config worth deploying, the three jobs one server is right
  for, and `replicas > 1 not supported in non-clustered mode`.
- [[s-docs-your-first-cluster]] — the `cluster {}` block as a deployment shape: routes, INFO-driven
  client failover, and the three pitfalls.
- [[s-docs-forming-a-cluster]] — explicit vs implicit routes, gossip as INFO redistribution, and what
  the `Routes` column of `nats server list` actually counts.
- [[s-docs-hardening]] — three independent TLS blocks, the sandboxed systemd unit, and why
  `http: "127.0.0.1:8222"` is right on a VM and an outage on Kubernetes.
- [[s-docs-rolling-upgrades]] — lame-duck mode step by step, the upgrade **order** rule, the
  `current` gate, and the PodDisruptionBudget that enforces it.
- [[s-docs-config-management]] — includes, the `-t` dry-run, SIGHUP, and the policy-versus-identity
  rule behind the reload/restart split.
- [[s-docs-scaling-and-peers]] — grow a Raft group and watch catchup; `peer-remove` vs `--replicas`;
  why one membership change at a time is the whole discipline.
- [[s-docs-stream-backup-restore]] — `backup.json` + `stream.tar.s2`, the chunked/windowed transfer,
  and the two rules on restore.
- [[s-docs-disaster-recovery]] — the failure-to-tool decision table, the five-step mirror promotion,
  and the meta-quorum precondition under all of it.
- [[s-docs-config-and-jwt-backup]] — the identity plane: which files carry it, sealing the archive,
  and why a restored store still leaves the server rejecting everyone.
- [[s-docs-leaf-nodes]] — the outbound bridge: hub vs remote, the account as the only real boundary,
  and the JetStream-domain pitfall.
- [[s-docs-super-clusters]] — gateways, gossip, and the only prose statement of geo-affinity — which
  is narrower than it reads.
- [[s-docs-jetstream-in-a-cluster]] — the meta group named, odd counts argued, and the two runnable
  commands that audit replica counts.
- [[s-docs-putting-it-together]] — the three `nats server report` commands, "composition adds reach,
  not boundaries", and a composed config that **does not start**.

**docs.nats.io — Security (learn)**

- [[s-docs-accounts-and-multitenancy]] — accounts as isolated subject spaces, `$G` and `$SYS`,
  per-account JetStream, and the `no_auth_user` traps.
- [[s-docs-authentication-basics]] — the config user list, the three credential styles, bcrypt, and
  the one error string every authentication failure produces.
- [[s-docs-authorization]] — permissions as subjects; the allow/deny rules and the four ways they
  fail silently.
- [[s-docs-cross-account]] — export and import, stream vs service, and the asymmetric failure: an
  unmatched import stops the server, an unmatched export moves nothing.
- [[s-docs-operator-mode]] — the build: `nats auth`, the store, the creds file, the resolver, and the
  push.
- [[s-docs-decentralized-auth]] — what the server verifies, scoped signing keys, the revocation
  window, expiry and bearer tokens.
- [[s-docs-auth-callout]] — `$SYS.REQ.USER.AUTH`, the signing and replay rules, and the credentials
  that cross it in the clear.
- [[s-docs-encryption-and-tls]] — TLS per connection type, `verify_and_map`, TLS-first, and the
  at-rest key.
- [[s-docs-security-checklist]] — the chapter's four questions and the only consolidated security
  checklist the docs publish.

**The `nats` CLI**

- [[s-natscli-backup-restore]] — every flag `nats stream backup` / `restore` takes at v0.4.0,
  including the three (`--config`, `--cluster`, `--replicas`) that make a cross-site restore possible.
- [[s-natscli-account-tls]] — `nats account tls`, the certificate check nobody names: the whole
  verified chain, `--expire-warn 1w`, and a non-zero exit. Plus `nats account backup` / `restore`.
- [[s-natscli-stream-external]] — the CLI has walked people through cross-domain sourcing for years:
  two branches, `$JS.<domain>.API` composed for you, and what the account branch assumes.

**The Helm chart**

- [[s-nats-helm-chart-values-2.14.6]] — the chart's own `values.yaml` at its release tag: lame-duck
  timing with zero slack, the reloader's `/etc/`-only watch, `configChecksumAnnotation`, the
  JetStream storage block with no `hostPath` value anywhere in it, and `max_file_store` rendered
  equal to the PVC size.

**GitHub issues — `nats-io/nats-server`**

- [[s-issue-4281-insufficient-storage]] — `10047` with an almost empty disk. `max_bytes` is a
  reservation; **open since 2023-06-29** with an unanswered counter-example.
- [[s-issue-8322-dynamic-maxstore-shrinks]] — the auto-sized `max_file_store` ratcheting downwards at
  every restart, reported twice two years apart, fixed by PR #8503 in **2.14.6**.

**GitHub, CNCF and the repositories**

- [[s-github-repo-facts]] — 32 repos and 24 READMEs: versions, licences, archived flags, and the
  feature coverage the docs delegate to them.
- [[s-nats-server-readme]] — CNCF, Apache-2.0, and the Trail of Bits / OSTIF security audit.
- [[s-cncf-nats-project]] — accepted 2018-03-15 at the Incubating maturity level.

## Wanted pages (topics with no source yet)

These are deliberately unresolved links; ingest a source to fill them.

Concepts: *(none — `leafnode` and `gateway` were written 2026-08-31, together with
`jetstream-domain` and `choosing-a-topology`; see the Concepts section above)*

Internals: *(none — `meta-layer` was written 2026-09-01 from `jetstream_cluster.go` and a three-node run;
see the Internals section above)*

`filestore-layout` was written 2026-08-31 and is in the Internals section above.

Operations: *(none — `rotate-tls-certificates` was written 2026-08-31; see the Operations section above)*

Gotchas: *(none — `consumer-keeps-redelivering` was written 2026-09-03 from issue #6921, Stack Overflow
#78603662, three runs on 2.14.6 and the five redelivery summaries; `stream-leader-keeps-moving` was
written 2026-09-01. See the Gotchas section above.)*

`jetstream-out-of-disk` was written 2026-08-31 and is in the Gotchas section above.
`kv-watcher-misses-updates` has been **retired rather than written**: the thread it was wanted for
(gh#6746) asks how to watch many keys on one watcher, and a search of `nats-io/nats-server`
discussions on 2026-08-31 found nobody publicly reporting a KV watcher missing an update. The KV
watcher failure people do report is `kv-watchers-stall-the-cluster`, in the Gotchas section above;
the gap is recorded under `## To verify` on the `key-value` page.

Reference: *(all six reference tables are written — see the Reference section above)*

Entities: *(all the repos, clients, tools, releases, products and organisations the ecosystem page
names now have pages — see the Entities section above. People: none yet.)*

## Inbox

- `inbox/question-bank.md` — the questions this wiki must answer, with the page that answers each
- `inbox/adr-toc.md` — one row per ADR of `nats-architecture-and-design`
- `inbox/docs-issues.md` — **48** errors and gaps found in **public NATS documentation**, each verified
  against the server at a release tag with file and line, kept so they can be sent to the maintainers.
  **None has been filed yet** — every row's `upstream` column reads `not filed`. Routed by a
  `destination` column: 42 to `nats-docs`, 4 (#7, #30, #31, #37) to the ADR repo, 1 (#40) to `natscli`,
  1 (#39) to a published blog post.
- `inbox/server-issues.md` — **1** finding about **`nats-server` itself**, kept separate because a
  server finding cannot be settled the way a docs finding can: there is no higher authority to check it
  against, so entries are observations and questions rather than verdicts. `SI-1` is the
  `$OBJ.>` / `$O.` mismatch that lets object-store data cross a JetStream domain boundary.
- `inbox/config-keys-table.md` — 621 config keys with type, default and reload behaviour
- `inbox/plan-first-ingests-2026-08-31.md` — **finished** 2026-08-31, all 7 steps; kept as the record
- `inbox/plan-runbooks-and-security-2026-08-31.md` — **finished** 2026-08-31, all 7 steps; kept as
  the record
- `inbox/plan-consolidation-2026-08-31.md` — **finished** 2026-09-01, all 8 steps; kept as the
  record. Took unlanded ripples **252 → 0** across 202 claims, per *Operation: consolidate*
- `inbox/plan-drift-and-adrs-2026-08-31.md` — **finished** 2026-08-31, all 5 steps; kept as the record
- `inbox/plan-the-unread-chapters-2026-08-31.md` — **finished** 2026-09-01, all 6 steps; kept as the
  record
- `inbox/scout-backlog.md` — **standing list**, not a scout: the 14 bank rows that still want one,
  grouped into three scouts with the reason each group holds together, plus the two rows that are
  *not* scouts because another plan or an ingested thread already owns them. Update it when a scout is
  run
- `inbox/scout-delivery-timing-2026-09-01.md` — **scout**, 2026-09-01. Eleven candidates on
  redelivery timing and the message scheduler, for bank rows 16–19 and 29–30. Carries two findings the
  plan below exists to settle: the docs and a Synadia post **disagree on whether a consumer backoff
  applies to a nak**, and the message scheduler has **no prose anywhere in docs.nats.io** (checked
  against the live index, not the mirror)
- `inbox/plan-delivery-timing-2026-09-01.md` — **proposed**, not started, and the newest file — so a
  bare `start the plan` takes this one. Four steps from the scout above; step 2 is a **server run** on
  v2.14.6 rather than a read, because the contradiction is behavioural
- `inbox/plan-the-meta-layer-2026-09-01.md` — **finished** 2026-09-01, all 3 steps; kept as the record.
  Wrote `meta-layer`, `stream-leader-keeps-moving` and `evict-a-sick-server`, settled every open
  `## To verify` item on `raft-in-nats`, and produced docs issues #43–#48 The last structural hole in
  the JetStream coverage: `meta-layer` and `stream-leader-keeps-moving`, the two remaining wanted
  pages, plus Q37 and Q40. **Name the file explicitly** when starting it — a bare `start the plan`
  takes the newest file
- `inbox/` also holds scout files and plans; nothing there is a wiki page.
