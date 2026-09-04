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
- [[service-import-request-info]] — the header the server stamps on every request that crosses a service
  import: account only by default, the user too with `share: true` on the tenant's import; the first hop
  decides on a chain, a leafnode rewrites it, a stream strips it, and it can push a request over `max_payload`.
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
- [[core-nats-delivery]] — what a core publish promises: at-most-once to whoever is subscribed at that
  instant, order per publisher connection across every subject (the maintainers' answer in gh#7577), echo
  on by default, `max_payload` counted over header plus body and a violation that **closes the connection**,
  and the four surfaces that show why a message never arrived — a wire tap, `/subsz?test=`, `/connz`,
  `nats trace` — each run on 2.14.6.
- [[services-framework]] — a "service" is a client-library convention, not a server feature: the
  `{group}.{endpoint}` subject rule, the nine `$SRV` subscriptions every instance makes, the three
  response types and the five per-endpoint counters in nanoseconds, the two error headers against the
  503, what `Stop()` drains, and why `$SRV` is not reserved by the server at all.
- [[subjects-and-wildcards]] — the three rules the server enforces on a subject (no empty token, no
  whitespace, `>` last) and everything it does not: no length or token limit (`max_control_line` and the
  restart-only `max_subscription_tokens` are the real bounds), `$` prefixes nobody checks, a publish to a
  wildcard routed as a literal, pedantic mode that errors and delivers anyway, and a space that silently
  misroutes.
- [[request-reply]] — a publish with a private reply subject: the `_INBOX.<nuid>.*` mux, the three outcomes
  with each client's name for them and the CLI's one exit code for all three, the `503` exactly as the
  2.14.6 server sends it (`Nats-Subject` since 2.12.0, the four preconditions, since 2.2.0), scatter-gather
  with ADR-47's four stop conditions timed, the 503 across an import, and one connection or two.
- [[queue-groups]] — one member per message, picked at random: not round-robin and **not readiness-aware**
  (a busy member kept its share, measured), uniform per member across a cluster, the publisher's own side
  across a leafnode — with the hub's split skewed 3 : 1 by a leaf's members (SI-8) — and an exclusion list
  across a gateway; `/subsz` shows one server's members only.
- [[client-connection-lifecycle]] — what your application experiences while the cluster does something:
  the state machine and its edges, discovery as the thing that actually gives a one-URL client failover,
  the reconnect gap measured at two publish rates, `MaxReconnect` as a per-server budget that can end a
  connection for good, the six-minute keepalive (the third ping, not the second — the ADR says
  otherwise), drain's two phases and the three ways it bites, flush as a receipt, and the `ldm` INFO with
  the departing server's own address removed.

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

- [[core-or-jetstream]] — the durability decision, per subject rather than per system: the rule the
  docs state ("does the next message supersede this one?"), what the two publishes look like on the
  wire and what each costs, the mixed design under an unchanged publisher, and the two ways it goes
  wrong — a stream over a request/reply subject answering the requests itself, and a stream on `>`.
- [[worker-pool]] — many processes on one consumer: demand-based distribution, `max_ack_pending` as a
  *shared* ceiling, and why this is not a queue group.
- [[services-on-core-nats]] — designing a request/reply service layer with no broker state: sizing the
  caller's timeout from the queue rather than the handler, no-responders as the deploy check, scatter-
  gather only outside a queue group, permissions per role, drain on stop, and where the design stops
  and needs a stream.
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
- [[slow-consumer-in-the-client]] — `nats: slow consumer, messages dropped`: the client's own
  pending buffer overflowing, connection intact, server counter at zero. The Go default is two
  numbers, and the callback fires per transition rather than per drop.
- [[connection-closed-after-auth-error]] — CLOSED within seconds of a JWT lapsing, while the `nats`
  CLI on the same credentials appears fine. The abort rule, and how wide the retry window really is.
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

*Lookup tables: defaults and limits, config keys, `$JS.API` subjects, monitoring endpoints, metrics.*

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
- [[system-subjects]] — every `$SYS` subject the server answers on or publishes to, read from `events.go`
  at v2.14.6 and run: the fifteen `$SYS.REQ.SERVER.PING.<Z>` requests and which three have no HTTP twin,
  the account requests an ordinary user may make, the events with their bodies and heartbeats (`STATSZ`
  10 s, `CONNS` 30 s), and the two subjects the docs name that do not exist.
- [[stream-and-consumer-config]] — every field of `StreamConfig` and `ConsumerConfig` at v2.14.6: type,
  the default the server applies, the minor it arrived in, whether it can change after creation (with
  the refusal string), the CLI flag, and the rule that bites; the limits that clamp a consumer; which
  clock stamps a message; the pull `batch` that has no ceiling.
- [[metrics]] — every series `prometheus-nats-exporter` v0.20.2 emits from a 2.14.6 server, by collector,
  with the endpoint field, labels and type of each; the two default prefixes (`gnatsd_`, `jetstream_`)
  and the one flag that renames both; surveyor's 105 names and its `--prefix` that does nothing; which
  node's exporter to read (`num_pending` is 0 off the consumer leader); the series behind the alerts and
  what has none; the exact counters; `ha_assets`.
- [[client-defaults]] — what each NATS client does when you configure nothing: connect timeout,
  reconnect policy, buffers, keepalive, drain and flush. nats.go at v1.53.1 and the `nats` CLI at 0.4.0
  read from source with file and line; every other client is the documentation's word, marked as such —
  plus a table of what was measured on 2.14.6.
- [[wire-protocol]] — every byte a NATS connection can carry at 2.14.6: the 49 `INFO` fields and which
  listener sends each, the 22 `CONNECT` fields and the three that default to `true` when omitted, the
  verbs of all four connection kinds with the forms observed on the wire, and every `-ERR` string with
  the setting behind it and whether the connection survives — including the four that are recoverable,
  the five ways a connection dies silently, and the twelve strings the docs list that the server never
  sends.

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

Every client page carries a **`## What bites you`** section: the operator-visible behaviours, each
dated to the release that introduced it.

- [[nats-go]] — the reference implementation, and the parity target the other clients name. A write
  error does not force a reconnect unless you ask.
- [[nats-js]] — the v3 mono-repo: Node/Bun, Deno and the browser, with the base client split into
  modules. A 20 s connect timeout, 10 reconnects, and a buffer that never drops.
- [[nats-py]] — `nats-py` today, a modular `nats-core` (Python 3.13+) in progress; the docs name
  neither. The maintainers' own benchmark: "nats-py dropped 47-87% of messages under load".
- [[nats-java]] — the artifact is `io.nats:jnats`, not the repo name. `drain()`'s future says `true`
  even when it timed out.
- [[nats-rs]] — `async-nats`: stable API on 0.x versions, and the `chrono` feature that poisons a
  whole build. `flush()` waits for the socket, not for the server.
- [[nats-net]] — v3 added OpenTelemetry and **dropped .NET 6** — and moved two of the defaults the
  docs still state.
- [[nats-c]] — the FFI and embedded client; a port of the Go client's semantics, with no support
  matrix. Two auth errors ended the connection, with no opt-out before v3.13.0.

*Tier 2 — "may lag behind on new server features".*

- [[nats-zig]] — pre-1.0; no Object Store, no mTLS; one release, and Zig moves under it.
- [[nats-swift]] — Core NATS **and JetStream since v0.4.0**, whatever its README says; no KV, no
  Object Store, no Services.
- [[nats-pure-rb]] — the preferred Ruby client, thread-safe, no EventMachine. Read from its source,
  because no `learn/` page names Ruby at all: a budget of 10, a publisher that blocks, a four-minute
  keepalive.
- [[nats-rb]] — legacy Ruby, no release since 2019. Use [[nats-pure-rb]].
- [[nats-ex]] — Elixir, published to hex as **`gnat`**, MIT-licensed. KV watchers were dropped as slow
  consumers before v1.14.0.

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
- [[s-docs-concepts-jetstream]] — the primer's statement of the boundary: at-most-once against
  at-least-once, "JetStream extends that decoupling to time", stream · consumer · client, and
  independent cursors over one stored copy.
- [[s-docs-jetstream-where-next]] — the chapter's recap and its whole production checklist: stream ·
  consumer · ack, "a stored message has not yet been processed", and the one line that says when to
  reach for a stream — filed under a Pitfalls section that does not contain it (docs issue #118).
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

**docs.nats.io — Core NATS (learn)**

- [[s-docs-core-nats-subjects-and-mapping]] — tokens, `*` and `>`, the reserved prefixes, the whitespace
  misroute, and account-level `mappings` with weights, the remainder rule, partition and `cluster`; the
  `concepts/subjects.md` primer folded, with its unsourced 16-token limit.
- [[s-docs-core-nats-publish-subscribe]] — the chapter's spine: at-most-once, the interest graph, echo,
  `max_payload` with headers, the reconnect buffer and lame duck as a client sees them, and the three
  debugging tools; the `concepts/` primers folded.
- [[s-docs-core-nats-request-reply]] — the inbox mux, the three outcomes with each client's name, the CLI's
  gather flags and the `nats reply` queue-group trap; `concepts/request-reply.md` folded.
- [[s-docs-services-framework]] — the Services chapter's four narrative pages: what the framework adds to
  a plain responder, the `{group}.{endpoint}` rule, the three-level queue group, and the immutability of
  endpoints and metadata. Unversioned by design, so every date comes from ADR-32.
- [[s-docs-services-discovery-and-stats]] — the wire surface: the three `$SRV` verbs at three levels,
  broadcast semantics, the five per-endpoint counters in nanoseconds, the two error headers, and the
  `io.nats.micro.v1.*` schemas read from `raw/jsm-go/` because the docs' renderer collapsed them.
- [[s-docs-services-scaling]] — the operator page of the chapter, and this ingest's richest source of docs
  issues: two behavioural claims about a busy queue-group member that the runs contradict, plus what
  `Stop()` really drains.
- [[s-docs-core-nats-queue-groups]] — the random pick, coexistence, one subject per group, the typo, and the
  "a cluster adds a locality preference" sentence the lab contradicts; `concepts/queue-groups.md` folded.
- [[s-docs-core-nats-chapter]] — the chapter index: "core NATS is ephemeral", and the docs' clearest
  statement of the rule — at-most-once is right "when each message is superseded by the next one",
  a stream is for "wait for a subscriber, survive a restart, or be replayed later".

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
- [[s-docs-config-accounts-exports-imports]] — the `exports` / `imports` reference tables: four keys each, the
  reload notes, and the six keys the server accepts that they omit (docs issue #79).
- [[s-docs-monitoring-endpoints]] — the only prose source for the monitoring port; `slow_consumers`,
  `/connz?sort=pending`, and why an unscoped `/jsz` times out.
- [[s-docs-monitor-raftz]] — the 173-byte reference page three learn chapters call "the full field
  set": two request options, no response fields.
- [[s-docs-system-monitor-reference]] — the system monitor tree read whole: 15 generated endpoint pages,
  three of which (`statsz`, `idz`, `profilez`) are not HTTP endpoints at all, and `max_connections`
  annotated as a duration.
- [[s-docs-system-errors]] — the docs' second `-ERR` list, swept row by row against the server: 70
  identifier rows and 37 close reasons accurate, 11 of 22 claimed wire errors not sent at all.
- [[s-docs-protocol-client]] — `reference/protocols` and `reference/protocols/client`: the twelve verbs,
  the `INFO` and `CONNECT` tables and the fifteen-row `-ERR` table, swept against 2.14.6 — three wrong
  defaults, six wrong strings, `client_id` listed twice with two types, six INFO fields a client is sent
  that no row has, and a `Required` column the server has no counterpart for.
- [[s-docs-protocols-internal]] — `route`, `gateway` and `leafnode` read as one: the three at a glance,
  the verb forms the parser rejects (`LS+` with two tokens, `LMSG` with header sizes, the origin cluster
  last), the leaf CONNECT's three wrong field names, six "common errors" that do not exist, and the
  optimistic gateway mode that 2.9.0 retired.
- [[s-docs-system-advisories-and-metrics]] — the three system events and the latency metric as the docs
  give them: a `CONNECTIONS` subject that does not exist, a "limits reached" trigger that is a 30 s
  heartbeat, and a latency subject the server never uses.
- [[s-docs-jetstream-api-index]] — the four `$JS.API` index tables and 25 operation pages: `subjects_filter`,
  `missing` and `offline`, the purge and snapshot options, `min_pending` / `min_ack_pending`, and
  `stream/names` documenting its array as `consumers`.
- [[s-docs-jetstream-advisories-reference]] — the 24 advisory and metric pages swept field by field against
  `jetstream_events.go`: four wrong bodies, one missing enum value, twelve pages without `domain`.

**nats-server source**

- [[s-nats-server-constants-2.14.6]] — the defaults the docs do not state, read from the tagged
  source with file and line.
- [[s-nats-server-service-imports]] — `Nats-Request-Info`, the import's `share`, `getClientInfo(detailed)`, the
  first-hop rule, the leaf rewrite, the three export guards and `checkActivation`, and the config parsers'
  import/export keys, with lines at v2.14.6 and v2.10.0.
- [[s-nats-server-share-import-observed]] — four scenes on 2.14.6: the header's two shapes, a two-hop chain
  (the first hop decides), `max_payload: 256` delivering `HMSG … 257 507`, and `share` on a stream import
  accepted silently.
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
- [[s-nats-server-system-subjects]] — every `$SYS` subject from `events.go` at v2.14.6: the fifteen `PING.<Z>`
  names and their double subscription, the per-account table, the two built-in imports, the event
  bodies, the HTTP mux, service latency on the export's own subject, and `jetstream_events.go` whole.
- [[s-nats-server-system-subjects-observed]] — the runs: `/statsz` `/idz` `/profilez` 404 while the requests
  answer; `CONNS` on both subjects every 30 s; a leaf as a `CONNECT` with `kind: Leafnode` and no
  `LEAFNODE.CONNECT` without gateways; the auth-error pair; reload by message; lame duck and shutdown.
- [[s-nats-server-stream-consumer-config]] — `StreamConfig` and `ConsumerConfig` from the source: the defaults
  `checkStreamCfg` and `setConsumerConfigDefaults` fill in, the validation, `configUpdateCheck` and
  `checkNewConsumerConfig`, the batch constants, and the leader's clock on every message.
- [[s-nats-server-config-mutability-observed]] — three passes of raw API updates on 2.14.6: every refusal
  string, what sealing forces, an ephemeral's defaults, `subjects_filter`, and a pull of `batch: 300`
  served in full.
- [[s-nats-server-traffic-counters-and-ha-assets]] — the counters `/varz` and `/connz` report are atomic
  and count payload bytes; a follower's consumer info takes `num_ack_pending` from the replicated state but
  `num_pending` from a function that returns 0 unless leader; `ha_assets` is the Raft-node count (meta group
  included) and `max_ha_assets` is checked at group creation and at placement.
- [[s-nats-server-core-delivery]] — `isValidSubject`'s three rules, the two `PUB` parsers (a space is the
  reply boundary; `HPUB`'s size is header plus body), the advisory pedantic check, echo, the 503 with
  `Nats-Subject`, `max_subscription_tokens` with no reload case, `AddWeightedMappings` and the
  remainder-drop rule, `/subsz`, at v2.14.6 with lines.
- [[s-nats-server-core-delivery-observed]] — eight runs on 2.14.6: the whitespace misroute on the wire,
  `max_payload` refusing 600,000 + 500,000 bytes, pedantic mode delivering after its `-ERR`,
  `max_subscription_tokens` refusing a reload, `/subsz?test=`, `nats trace` without a system user, weighted
  and partitioned mappings counted over 200 publishes (the loss trick on a wildcard source too), a restart
  and a lame duck as `nats sub --trace` prints them.
- [[s-nats-server-request-reply]] — the four conditions of the 503 and its bytes, `processMsgResults`' random
  start index and the leaf fallback, the sublist's weight expansion, `RS+ … <weight>`, the gateway
  exclusion, at v2.14.6 with lines.
- [[s-nats-server-services-observed]] — six passes on 2.14.6: ten subscriptions per instance, the `$SRV`
  bodies, a service error and a 503 side by side on the wire, a blocked endpoint that does not block its
  siblings, a blocked instance that times out four of eight callers, what `Stop()` removes, and a
  leafnode that carries discovery but keeps the queue group local.
- [[s-nats-server-core-or-jetstream-observed]] — seven passes on 2.14.6: a JetStream publish is a core
  publish with a reply subject, the four `nats bench` ratios (93× for the round trip, nothing for a
  core publish into a captured subject), **a stream over a request/reply subject answering the requests
  with its own `PubAck`**, the `no_ack` rules at `stream.go:2170–2196`, a `>` stream that grows when you
  look at it, and a leader step-down costing an R3 publisher exactly one 503.
- [[s-nats-server-request-reply-observed]] — eight runs in four passes: the 503 with `Nats-Subject`, the
  CLI's silent timeout at exit 0, a busy member keeping 8 of 20, a quarter each across the lab's nodes, the
  503 across an import, and a leaf's members skewing the hub's split 3 : 1.
- [[s-nats-server-client-errors]] — every `-ERR` a client can be sent (58 call sites), the 37
  `ClosedState` reasons `/connz` reports, both server-side slow-consumer branches and why neither
  sends anything, the zero-length expiry timer, and `handshake_first`'s five accepted values.
- [[s-nats-server-wire-protocol]] — the wire protocol read at the tag and then provoked on the binary:
  the one `Info` struct behind four connection kinds, the `INFO` line's trailing space, `CONNECT {}` as a
  verbose connection, the `-ERR` count corrected to 60, the five close reasons that discard the error they
  just wrote, `(ping_max + 1) × ping_interval` timed at 6.14 s, every verb traced with `-DV`, and
  `gateway_iom` — interest-only by default since 2.9.0.

**The `nats.go` client source**

- [[s-nats-server-jetstream-log-warnings|(see above)]] for the server side; the client error strings
  `nats: timeout` and `nats: no responders available for request` are quoted from
  `raw/nats-go-src/errors-v1.53.1.md` on [[nats-timeout]].
- [[s-nats-go-relnotes-1.48.0]] — the release (2025-12-17) that added publish-subject validation to the Go
  client, dating the docs' "nats.go before v1.48.0" claim.

**docs.nats.io — Resilient clients (learn)**

- [[s-docs-resilient-clients-connecting]] — the chapter's state machine, the three connect-time options,
  the randomised pool, discovery and its per-client opt-outs, the four-step handshake.
- [[s-docs-resilient-clients-reconnection-and-events]] — backoff after a whole sweep, jitter, the
  per-server `MaxReconnect`, the reconnect buffer, the third-ping keepalive, the six events and the
  readiness rule.
- [[s-docs-resilient-clients-drain-and-shutdown]] — close vs drain, the two phases and their timeouts,
  per-subscription drain, flush as a server receipt, lame duck from the client's side.
- [[s-docs-resilient-clients-slow-consumers-and-request-reply]] — the pending buffer and its
  per-client divergence, the slow-consumer signal, the two things that share the name, and
  retry-per-outcome with idempotency.
- [[s-docs-resilient-clients-tls-and-auth]] — consuming a `.creds` file, the CA and the two handshake
  orders, and the only place the docs put the per-client auth-error abort rules side by side.

**The `nats.go` client and the `nats` CLI, at their pinned versions**

- [[s-nats-go-connection]] — nats.go v1.53.1: every connection default in one const block, the drop rule
  in `selectNextServer`, the sleep-per-sweep, the buffer check, `processPingTimer`, `processAuthError`,
  `drainConnection` and the stderr handler an unset callback still gets.
- [[s-nats-cli-reconnect]] — natscli 0.4.0: `MaxReconnects(-1)`, `IgnoreAuthErrorAbort()`, the 44-step
  backoff table, which `>>>` lines need `--trace`, the twice-registered error handler, and `nats reply`'s
  `Drain()` + `log.Fatalf`.
- [[s-nats-go-subscription]] — nats.go v1.53.1: the pending defaults that differ by subscription type,
  `SetPendingLimits`' two rules, the one-shot overflow transition, `processErr`'s three fates, the
  abort rule, and that `UserCredentials` re-reads the file every attempt.

**Runs on the server**

- [[s-nats-server-client-lifecycle-observed]] — a node stopped, a node in lame duck with its `ldm` INFO,
  `nats reply` drained under load, the stale link timed from both ends, and a pull consumer whose leader
  moves. Every measured number on [[client-connection-lifecycle]] and [[client-defaults]].
- [[s-nats-server-client-faults-observed]] — the three client faults on 2.14.6: a client-side slow
  consumer under `SetPendingLimits` against both of the server's own branches, a user and an account
  JWT expiring under a live connection on the wire and through three clients, and the four settings of
  `handshake_first` timed.

**The `jwt` library and `nsc`**

- [[s-jwt-imports-exports-activation]] — jwt v2.8.2: `Import.Share` / `Token`, `Export.TokenReq` /
  `Revocations` / `AccountTokenPosition` (and no account list), the validators, the activation claim.
- [[s-nsc-imports-exports-activation]] — nsc v2.15.0: `add import --share` / `--token`, `add export --private` /
  `--account-token-position`, `generate activation --target-account`.

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
- [[s-adr-9-idle-heartbeats]] — `idle_heartbeat`: status `100 Idle Heartbeat` with `Nats-Last-Consumer` and
  `Nats-Last-Stream`; push-only and fixed after creation on 2.14.6.
- [[s-adr-33-metadata]] — `metadata` on streams and consumers: 128 KB, `_nats` reserved.
- [[s-adr-34-multiple-filters]] — `filter_subjects`: no overlaps (10136), not both forms (10134), a buffer
  per subject on the server.
- [[s-adr-32-service-api]] — the Service API spec, revisions 1–6 (2022-11-23 → 2025-02-17): the name and
  SemVer rules, the `$SRV` verb tree, the three response types, the three-level queue group with default
  `q`, immutable metadata, drain on stop — and the overridable prefix nats.go never implemented.
- [[s-adr-22-publish-retries]] — the ADR that says a JetStream publish *is* a core request: the 503 on a
  leadership blip, `250ms` × 2 by default, `RetryAttempts(-1)`, and `nats: no response from stream` as
  the exhausted error — all still true at nats.go v1.53.1, and none of it done by `nats pub -J`.
- [[s-adr-4-message-headers]] — the header wire format: `NATS/1.0`, `HDR_LEN` through the blank line, case
  preserving, one value per line; no version — that comes from the source at v2.2.0.
- [[s-adr-47-request-many]] — *Partially Implemented*: the four stop conditions of a many-reply request and
  the terminal 503; the CLI's flags are these.

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
- [[s-relnotes-2.14]] — the 7 release bodies of the 2.14 line (2026-04-30 → 2026-08-27) as one changelog, checked
  against the docs' 2.14 upgrade guide and the server source: `feature_flags` and its two flags, the v2 ack
  subjects still off, `dial_timeout`, the consumer reset subject, which patch to be on; docs issues #61–#63.
- [[s-relnotes-2.15-preview]] — the v2.15.0-preview.1 body (2026-08-24) read whole: the desired-state metalayer,
  the evacuate and cancel-move subjects verified at the preview tag, backup v2, `sources.db`, the
  `sync_interval: always` change on replicated streams — and the `$JS.ACK` v2 default **not yet flipped**.
- [[s-relnotes-2.2.0]] — the oldest body kept, out of the archive's range: it never names headers or
  `no_responders`, so the source at v2.1.9 and v2.2.0 dates them — and the 2.2.0 `503` had no `Nats-Subject`.

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
- [[s-gh-5768-track-connected-clients]] — reconciling who is connected after a missed `CONNECT`:
  `$SYS.REQ.SERVER.<id>.CONNZ` paged with `offset`/`limit`, one server per id, and the 30 s `CONNS`
  heartbeat the thread never mentions.
- [[s-gh-5902-leafnode-connect-events]] — `LEAFNODE.CONNECT` seen on Synadia Cloud, never on a
  docker-compose hub, unresolved upstream; settled from the source — the sender is a no-op without
  gateways, and there is no `LEAFNODE.DISCONNECT`.
- [[s-gh-3944-subjects-in-a-stream]] — which subjects a stream holds: `subjects_filter` on `STREAM.INFO`,
  and "everything except X" as a `filter_subjects` list.
- [[s-gh-2818-counters-exact-or-sampled]] — "Yes that is correct": the traffic counters are exact — and per
  server; "nats top is not cluster aware".
- [[s-gh-3857-consumer-pending-series]] — the maintainer's definition of `num_pending`, and a 2023 "not sure
  that metric is there" the wiki's runs answer: both tools export it, leader only.
- [[s-gh-6182-what-to-alert-on]] — seven alert targets asked for a 2.10.19 cluster, zero replies; mapped to
  series on `metrics`.
- [[s-gh-5128-ha-assets]] — "we generally focus on HA Assets": 2k per server in Synadia's global clusters,
  muxed streams and R1 mirrors, R1 consumers recreated from a stored sequence.
- [[s-gh-7577-core-nats-ordering]] — row 25's thread: "for a single publish connection order will always be
  preserved globally", across subjects, with several publishers interleaving.
- [[s-gh-5097-subject-token-limit]] — the docs' 16-token guidance asked about, and a maintainer's "probably
  not strictly enforced".
- [[s-gh-2855-publish-with-wildcards]] — "Wildcards are only applicable for subscriptions."
- [[s-gh-5172-mapping-in-config-or-stream]] — the maintainer's placement rule: partition for a stream in the
  stream config, not the server config; and the server's example config using a wildcard source as its own
  destination for loss testing.
- [[s-gh-4984-micro-with-jetstream]] — can a services handler ack and nak? "Roughly planned … no
  immediate plans" in 2024, "Still not on the immediate roadmap" in 2025 — the public statement of where
  core NATS request/reply stops.
- [[s-gh-2961-js-and-core-one-cluster]] — "You can use both at the same time with the same cluster",
  and what it costs: memory up, "core nats performance will remain the same essentially". The only
  public maintainer statement on the mixed deployment.
- [[s-gh-3507-no-external-store]] — "No, we will support memory and file based for the store level" —
  no external database, ever; replication is replicas, mirrors and sources. Row 143's thread.
- [[s-gh-2760-one-connection-or-two]] — "start with one connection"; head-of-line blocking is on the
  subscription side, so split subscriptions, not publishing. Row 138's thread.

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
- [[s-natscli-auth-exports-imports]] — `nats auth account exports add` / `imports add --help` on 0.4.0: `--share`,
  `--token-position`, and no `--private`.
- [[s-natscli-account-tls]] — `nats account tls`, the certificate check nobody names: the whole
  verified chain, `--expire-warn 1w`, and a non-zero exit. Plus `nats account backup` / `restore`.
- [[s-natscli-stream-external]] — the CLI has walked people through cross-domain sourcing for years:
  two branches, `$JS.<domain>.API` composed for you, and what the account branch assumes.
- [[s-nats-cli-help-0.4.0]] — `stream add` / `edit` and `consumer add` / `edit` help at 0.4.0, verbatim: the
  flag for every field, the CLI's own defaults, and the fields `consumer edit` has no flag for.
- [[s-nats-cli-core-commands]] — `request`, `reply`, `trace`, `server mappings`, `subscribe` and `publish`
  help at 0.4.0: `nats reply` joins `NATS-RPLY-22` by default, `--replies` / `--reply-timeout` /
  `--wait-for-empty`, `--headers-only`, `--deliver`.
- [[s-nats-cli-request-reply-source]] — `req_command.go` and `reply_command.go` at v0.4.0: a timeout `break`s
  silently to exit 0, any empty reply ends a counted gather, `--wait-for-empty` is `--replies 32767`, and
  `nats reply` is one callback.

**The Helm chart**

- [[s-nats-helm-chart-values-2.14.6]] — the chart's own `values.yaml` at its release tag: lame-duck
  timing with zero slack, the reloader's `/etc/`-only watch, `configChecksumAnnotation`, the
  JetStream storage block with no `hostPath` value anywhere in it, and `max_file_store` rendered
  equal to the PVC size.
**prometheus-nats-exporter and nats-surveyor**

- [[s-prometheus-nats-exporter-collector]] — the v0.20.2 source: `gnatsd` and `jetstream` namespaces, the
  flattening rule and what it drops, 33 JetStream series with seventeen labels, the `/jsz` query each `-jsz`
  value sends, `healthz_status` inverted, no `js-meta-only`, the inverted "defaulting to varz" test.
- [[s-prometheus-nats-exporter-metrics-observed]] — ten scrapes on 2.14.6: 167 series, 135 of 139 core ones
  gauges, `-prefix nats` renaming all, an R1 stream visible on one node, `num_pending` 20 / 0 / 0 across the
  replicas, no-flags fatal, `-jsz` alone adding `varz`, `account=""` for `$G` clients.
- [[s-nats-surveyor-metrics-observed]] — three scrapes at v0.9.11: 105 series under a hard-coded `nats`
  namespace, `--prefix` a `// TODO`, one sample per replica unless `--jsz-leaders-only`, the `raftz` series
  with shifted labels, and the coverage the exporter lacks.


**GitHub issues — `nats-io/nats-server`**

- [[s-issue-4281-insufficient-storage]] — `10047` with an almost empty disk. `max_bytes` is a
  reservation; **open since 2023-06-29** with an unanswered counter-example.
- [[s-issue-8322-dynamic-maxstore-shrinks]] — the auto-sized `max_file_store` ratcheting downwards at
  every restart, reported twice two years apart, fixed by PR #8503 in **2.14.6**.
- [[s-issue-8271-request-info-max-payload]] — the server-added `Nats-Request-Info` header pushing a request
  over `max_payload`; **open**, its fix PR unmerged and the maintainers inclined to leave it; reproduced on 2.14.6.
- [[s-ghsa-2026-08-request-info-spoofing]] — CVE-2026-33246: a leafnode could forward a spoofed
  `Nats-Request-Info`; fixed 2.11.15 / 2.12.6, no workaround; the maintainers' statement of what the header is for.
- [[s-exporter-issue-218-num-pending-differs-per-node]] — `nats-io/prometheus-nats-exporter` #218, open and
  unanswered since 2023: `nats_consumer_num_pending` 3 / 0 / 3 across the pods, the reporter settling on
  `is_consumer_leader="true"`; reproduced on 2.14.6 and explained from the server source.

**GitHub, CNCF and the repositories**

- [[s-github-repo-facts]] — 32 repos and 24 READMEs: versions, licences, archived flags, and the
  feature coverage the docs delegate to them.
- [[s-nats-server-readme]] — CNCF, Apache-2.0, and the Trail of Bits / OSTIF security audit.
- [[s-cncf-nats-project]] — accepted 2018-03-15 at the Incubating maturity level.
- [[s-jsm-go-config-schemas]] — the two configuration JSON schemas at jsm.go v0.4.1: 38 stream and 34
  consumer properties, the consumer descriptions the docs never render, and one wrong deliver policy.
- [[s-client-releases-and-issues]] — the last ten release bodies and every open issue of all twelve
  clients: what dates each of the chapter's unversioned per-client claims, when subject validation
  arrived in each, and the two .NET defaults v3.0.0 moved out from under the docs.
- [[s-nats-pure-rb-client-source]] — the Ruby client read from `lib/nats/io/client.rb` at v2.5.0,
  because no `learn/` page names Ruby: the constants, the four-minute keepalive, the publisher that
  blocks and the drain that returns immediately.
- [[s-nats-server-tcp-nodelay]] — the two greps that settle Nagle: the server never sets
  `TCP_NODELAY`, and Go sets it on every TCP connection anyway.
- [[s-nats-server-connect-urls-gossip]] — `connect_urls` is fed by routes and by nothing else, so a
  client never learns the other clusters of a supercluster.

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

Reference: *(every reference table is written — see the Reference section above)*

Patterns: *(none — `core-or-jetstream` was written 2026-09-04 for bank row 133, closing megaplan
group G7, and is in the Operations section above with `services-on-core-nats`.)*

Entities: *(all the repos, clients, tools, releases, products and organisations the ecosystem page
names now have pages — see the Entities section above. People: none yet.)*

## Inbox

- `inbox/question-bank.md` — the questions this wiki must answer, with the page that answers each
- `inbox/adr-toc.md` — one row per ADR of `nats-architecture-and-design`
- `inbox/docs-issues.md` — **107** errors and gaps found in **public NATS documentation**, each verified
  against the server at a release tag with file and line, kept so they can be sent to the maintainers.
  **None has been filed yet** — every row's `upstream` column reads `not filed`. Routed by a
  `destination` column: 94 to `nats-docs`, 7 (#7, #30, #31, #37, #49, #51, #90) to the ADR repo, 3 (#40, #89, #91)
  to `natscli`, and one each to `jsm.go`, `nats-surveyor` and a published blog post (#39).
- `inbox/server-issues.md` — **8** findings about **`nats-server` itself**, kept separate because a
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
- `inbox/relnotes-toc.md` — one row per nats-server release body from v2.10.0 (70, 26 ★), generated by
  `tools/triage-releases.py`; the *Releases* table in the viewer
- `inbox/check-defaults-v2.10.29.md`, `-v2.11.17.md`, `-v2.12.15.md`, `-v2.14.6.md` — every documented config
  default against the server at each line's last patch; only the v2.14.6 one is in the viewer, the others are
  the diff base recorded in the log (2026-09-03, phase D step 8)
- `inbox/plan-change-layer-2026-09-03.md` — **finished** 2026-09-03, all 9 steps; kept as the record. The
  release archive, the five per-minor change-layer summaries, `since:` on every reader page, the default diff
  per minor, docs issues #54–#64
- `inbox/` also holds scout files and plans; nothing there is a wiki page.
