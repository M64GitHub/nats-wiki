---
title: Index
type: index
created: 2026-08-31
updated: 2026-08-31
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
  bucket, no read-after-write, and what watch and key listing really are.
- [[object-store]] — a bucket is the stream `OBJ_<bucket>` holding chunks and info in two subject
  spaces; 128k chunks, SHA-256 digests, and the features that do not exist.
- [[ordered-consumer]] — the ephemeral, memory-backed, R1 client construct that rebuilds itself on a
  gap, and the consumer churn it produces.
- [[priority-groups]] — `overflow`, `pinned_client` and `prioritized`; the `Nats-Pin-Id` protocol,
  the `423`, and the `failover` option that does nothing on 2.14.
- [[message-ttl]] — `Nats-TTL`, subject delete markers, the silent TTL clamp, and the marker kinds
  that are documented but unimplemented.
- [[account]] — the absolute boundary: `$G` and `$SYS`, per-account JetStream, why a cross-account
  request fails as `No responders`, and the three `no_auth_user` traps.
- [[direct-get]] — the point read answered by any replica: `allow_direct`, the two subjects, batch
  and `EOB`, and why it can never confirm a write.
- [[mirrors-and-sources]] — exact read-only copy vs merged aggregate; `Lag` as your RPO, the four
  `mirror_direct` rules, and the two failures that are completely silent.

## Internals

*How the server does it, included only where it explains something you can observe.*

- [[raft-in-nats]] — meta group vs per-asset groups, the 4–9 second election window, append →
  commit → apply, and the stepdown commands.
- [[stream-placement]] — `server_tags`, tag intersection, and the two causes of
  `no suitable peers for placement` (10005).
- [[js-api]] — `$JS.API` request-reply, paged listings, the `code` / `err_code` / `description`
  envelope, and why you must never match on error text.

## Operations

**Runbooks**

**Sizing**

- [[jetstream-sizing]] — disk, RAM, CPU and FDs for a JetStream node; the JetStream storage
  defaults, the `replicas × bytes` account rule, a worked example, and what is still unmeasurable.

**Patterns**

- [[worker-pool]] — many processes on one consumer: demand-based distribution, `max_ack_pending` as a
  *shared* ceiling, and why this is not a queue group.

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

**nats-server source**

- [[s-nats-server-constants-2.14.6]] — the defaults the docs do not state, read from the tagged
  source with file and line.

**Synadia blog**

- [[s-synadia-jetstream-memory-patterns]] — what JetStream actually holds in RAM, and the
  2-minute deduplication window default.

**ADRs — `nats-architecture-and-design`** (one row per ADR in `inbox/adr-toc.md`)

- [[s-adr-1-jetstream-json-api]] — the `$JS.API` shape: subjects, paging, schemas, the error
  envelope, wire units.
- [[s-adr-7-server-error-codes]] — the `err_code` numbering, `server/errors.json`, and why
  `description` is not part of the API.
- [[s-adr-8-key-value-store]] — the stream a KV bucket is, and its delete/purge/watch mechanics.
- [[s-adr-17-ordered-consumer]] — the ordered consumer's forced configuration and restrictions.
- [[s-adr-20-object-store]] — the stream an object-store bucket is, chunking and digests.
- [[s-adr-31-direct-get]] — the Direct Get spec: subjects, the `_sys_` queue group, headers, status
  codes, and the four `mirror_direct` alignment rules.
- [[s-adr-42-priority-groups]] — the three priority policies and the pinned-client protocol.
- [[s-adr-43-per-message-ttl]] — `Nats-TTL`, markers, the clamp, and seven error codes.

**Release notes and upgrade guides**

- [[s-docs-upgrade-to-2.12]] — 2.11 → 2.12: strict mode, elastic pointers, the v2.11.9 downgrade
  floor.
- [[s-docs-upgrade-to-2.14]] — 2.12 → 2.14: the `$JS.ACK` v2 deadline, frozen streams on filestore
  I/O errors, Raft overrun protection.
- [[s-relnotes-2.14.0]] — the v2.14.0 changelog with PR numbers, including the items the upgrade
  guide omits.

**GitHub discussions**

- [[s-gh-7982-no-suitable-peers]] — a placement failure diagnosed with debug logs.
- [[s-gh-7831-standalone-to-cluster]] — maintainers on why standalone cannot become a cluster
  in place.
- [[s-gh-6605-which-consumer-is-slow]] — an unanswered thread, recorded as unanswered.

**Synadia blog (continued)**

- [[s-synadia-jetstream-anti-patterns]] — the ~100k consumer and ~300 subject-filter thresholds,
  why `consumer info` is expensive, and republish / Direct Get as alternatives to consumers.

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
- [[s-docs-worker-pool]] — one consumer many workers, the shared `MaxAckPending` cap, and the queue
  group comparison.
- [[s-docs-mirrors-and-sources]] — mirror vs source, the comparison table, and the export type that
  fails silently.
- [[s-docs-mirrors-as-dr]] — `Lag` as RPO, what an upstream delete really does to a mirror, and why a
  mirror is not a backup.

**docs.nats.io — Security (learn)**

- [[s-docs-accounts-and-multitenancy]] — accounts as isolated subject spaces, `$G` and `$SYS`,
  per-account JetStream, and the `no_auth_user` traps.

**GitHub, CNCF and the repositories**

- [[s-github-repo-facts]] — 32 repos and 24 READMEs: versions, licences, archived flags, and the
  feature coverage the docs delegate to them.
- [[s-nats-server-readme]] — CNCF, Apache-2.0, and the Trail of Bits / OSTIF security audit.
- [[s-cncf-nats-project]] — accepted 2018-03-15 at the Incubating maturity level.

## Wanted pages (topics with no source yet)

These are deliberately unresolved links; ingest a source to fill them.

Concepts: [[leafnode]] · [[gateway]]

Internals: [[filestore-layout]] · [[meta-layer]]

Operations: [[install-nats-server]] · [[build-a-3-node-cluster]] ·
[[rotate-tls-certificates]] · [[backup-and-restore-jetstream]] · [[upgrade-a-cluster]]

Gotchas: [[consumer-keeps-redelivering]] · [[jetstream-out-of-disk]] ·
[[stream-leader-keeps-moving]] · [[kv-watcher-misses-updates]]

Reference: *(all six reference tables are written — see the Reference section above)*

Entities: *(all the repos, clients, tools, releases, products and organisations the ecosystem page
names now have pages — see the Entities section above. People: none yet.)*

## Inbox

- `inbox/question-bank.md` — the questions this wiki must answer, with the page that answers each
- `inbox/adr-toc.md` — one row per ADR of `nats-architecture-and-design`
- `inbox/docs-issues.md` — errors and gaps found in the public NATS docs, verified against the
  server source, kept so they can be sent to the maintainers
- `inbox/config-keys-table.md` — 621 config keys with type, default and reload behaviour
- `inbox/plan-first-ingests-2026-08-31.md` — **finished** 2026-08-31, all 7 steps; kept as the record
- `inbox/plan-runbooks-and-security-2026-08-31.md` — the current plan; say `start the plan`
- `inbox/` also holds scout files and plans; nothing there is a wiki page.
