<!-- source: https://github.com/nats-io/nats.js through the GitHub REST API (`gh api repos/nats-io/nats.js/releases?per_page=10` and `gh api repos/nats-io/nats.js/issues?state=open --paginate`) · fetched 2026-09-04 · release bodies verbatim (CRLF normalised to LF); open issues as number, open date and title only, pull requests excluded -->
# nats-io/nats.js — the last 10 release bodies, and the open issues at 2026-09-04

Fetched for step 8 of `inbox/plan-the-client-side-2026-09-03.md` (*What bites you* on the client entities). The `learn/resilient-clients` chapter states each client's behaviour without a version; a client's own release notes are the only public record that dates it.

## Releases

### `v3.4.0` — v3.4.0 — published 2026-05-08

https://github.com/nats-io/nats.js/releases/tag/v3.4.0

## What's Changed

In addition to fixes and general enhancements this release adds support for exciting nats-server 2.14 JetStream features.

[CORE]

- FIX: protocol integer parsing rejects non-sensical values (#373) by @aricart
- FEAT: `Symbol.asyncDispose` on connections/subscriptions — `using` auto-closes on scope exit (#396) by @aricart
- FIX: inboxes match go client `_INBOX.<nuid>.<token>` (was `_INBOX.<nuid>.<nuid>`); nuids now base62 see [nuid.js](https://github.com/nats-io/nuid.js) (#398) by @aricart
- FEAT: `getServers()`/`setServers()` — clients can list known servers and switch clusters (#400) by @aricart
- FEAT: `reconnectToServer` connection option — pick next server and dial delay during reconnect (#403) by @aricart

[JETSTREAM]

- FEAT: message schedules — messages fire on cron — **requires nats-server 2.14+** (#381) by @aricart
- FEAT: `resetConsumer()`/`reset()` on `JetStreamManager` — reset durable consumer ack sequence; enables order consumers backed by durables — **requires nats-server 2.14+** (#391) by @aricart
- FIX: push consumers stuck on heartbeat (#375) by @aricart
- FEAT: `JetStreamAccountStats`/`JetStreamApiStats` — add `reserved_memory`, `reserved_storage`, `inflight`; `max_bytes_required` is boolean; tiers use dynamic record (#376) by @aricart
- FEAT: fast ingest — exposed via [orbit fastingest](https://github.com/synadia-io/orbit.js/tree/main/fastingest) — **requires nats-server 2.14+** (#379) by @aricart
- FEAT: configure stream mirror/source consumers — `StreamSource.consumer`, `StreamConsumerSource`, `AckPolicy.FlowControl` — **requires [nats-server 2.14+](https://github.com/nats-io/nats-server/releases/tag/v2.14.0)** (#399) by @aricart

[KV]

- FIX: KV `create` passes `markerTTL` via `_put` (#367) by @Bre77

[OBJ]

- FEAT: faster entry add via fast ingest (**requires nats-server 2.14+**); native SHA-256 when available. Note that the fast ingest integration requires a hidden `allowBatched: true` to be specified as it is still experimental (#394, #397) by @aricart

[DOCS]

- FIX: esbuild build instructions (#378) by @AntoninPOLY
- Examples: websocket usage in modern frameworks (#392) by @aricart

## New Contributors

- @Bre77 — first contribution in #367
- @Jarema — first contribution in #369
- @AntoninPOLY — first contribution in #378

**Full Changelog**: https://github.com/nats-io/nats.js/compare/v3.3.1...v3.4.0

---

### `v3.4.0-4` — v3.4.0-4 — published 2026-05-08

https://github.com/nats-io/nats.js/releases/tag/v3.4.0-4

canary

---

### `v3.4.0-3` — v3.4.0-4 — published 2026-05-08

https://github.com/nats-io/nats.js/releases/tag/v3.4.0-3

canary

---

### `v3.4.0-2` — v3.4.0-2 — published 2026-05-07

https://github.com/nats-io/nats.js/releases/tag/v3.4.0-2

canary

---

### `v3.4.0-1` — v3.4.0-1 — published 2026-05-07

https://github.com/nats-io/nats.js/releases/tag/v3.4.0-1

canary

---

### `v3.4.0-0` — v3.4.0-0 — published 2026-04-29

https://github.com/nats-io/nats.js/releases/tag/v3.4.0-0

ci release cannary

---

### `v3.3.1` — v3.3.1 — published 2026-02-11

https://github.com/nats-io/nats.js/releases/tag/v3.3.1

## What's Changed

### ObjectStore

- Fixes a check on the validation of the digest. This is an important integrity fix.


### All Changes
* chore(workflows): remove unused `NODE_AUTH_TOKEN` environment variable from NPM publish steps by @aricart in https://github.com/nats-io/nats.js/pull/356
* chore(workflows): add `workflow_dispatch` trigger to test workflow by @aricart in https://github.com/nats-io/nats.js/pull/361
* fix shadowed digest which was creating self-equals. by @aricart in https://github.com/nats-io/nats.js/pull/364
* prepare for release by @aricart in https://github.com/nats-io/nats.js/pull/365


**Full Changelog**: https://github.com/nats-io/nats.js/compare/v3.3.0...v3.3.1

---

### `v3.3.0` — v3.3.0 — published 2025-12-16

https://github.com/nats-io/nats.js/releases/tag/v3.3.0

## What's Changed

  ### Core

  - Subject validation: Validate subjects for illegal whitespace characters (#348)

  ### JetStream

  - Direct API "no results": Handle "no results" status in direct APIs (#336)
  - Stream sequence errors: Handle additional JetStream API error for stream sequence (#353)
  - deleteMessage() change: Stream#deleteMessage() API to default to erase (#334)

  ### WebSocket

  - Custom WsSocketFactory: Expose ability to create WS connections by specifying a WsSocketFactory in WsConnectionOptions (#332)

  ### TypeScript

  - Export fix: Fixed exports so QueuedIterator exports correctly to JetStream (#351)

  ### Documentation

  - TypeScript compiler configuration guide for Node (#341)
  - General documentation updates (#333)

### All changes

* feat: expose in public api ability to create a ws connection by specifying a WsSocketFactory, and referencing it in WsConnectionOptions. by @aricart in https://github.com/nats-io/nats.js/pull/332
* fix(jestream): fixed the Stream#deleteMessage() api to default erase by @aricart in https://github.com/nats-io/nats.js/pull/334
* chore(workflows): add parallel support and Coveralls completion step by @aricart in https://github.com/nats-io/nats.js/pull/337
* feat(jetstream): handle "no results" status in direct APIs by @aricart in https://github.com/nats-io/nats.js/pull/336
* feat(tests): increase coverage by @aricart in https://github.com/nats-io/nats.js/pull/338
* feat(core): add reconnect logic for specifying servers by @aricart in https://github.com/nats-io/nats.js/pull/339
* feat(core): revert reconnect logic for specifying servers by @aricart in https://github.com/nats-io/nats.js/pull/340
* docs: add TypeScript compiler configuration guide for Node by @aricart in https://github.com/nats-io/nats.js/pull/341
* feat(tests): added jetstream/jetstreamManager context property  by @aricart in https://github.com/nats-io/nats.js/pull/342
* feat(core): validate subject for illegal whitespace characters by @aricart in https://github.com/nats-io/nats.js/pull/348
* fix(typescript): fixes to the exports so QueuedIterator exports correctly to JetStream by @aricart in https://github.com/nats-io/nats.js/pull/351
* feat(jetstream,kv): handle additional JetStream API error for stream seq by @aricart in https://github.com/nats-io/nats.js/pull/353
* fix(core): improve validation for `headers` arguments and update test by @aricart in https://github.com/nats-io/nats.js/pull/350
* update docs by @aricart in https://github.com/nats-io/nats.js/pull/333
* feat(core): normalize non-array values in `MsgHdrs.fromRecord` by @aricart in https://github.com/nats-io/nats.js/pull/352
* test(flapper): ignore sanitizers on cluster test by @aricart in https://github.com/nats-io/nats.js/pull/354
* refactor: bump dependencies by @aricart in https://github.com/nats-io/nats.js/pull/355


**Full Changelog**: https://github.com/nats-io/nats.js/compare/v3.2.0...v3.3.0

---

### `v3.2.0` — v3.2.0 — published 2025-09-22

https://github.com/nats-io/nats.js/releases/tag/v3.2.0

## What's Changed

This release increases stability and adds support for a number of exciting nats-server 2.12 features


 
### JetStream

  - feat: Batch publishing support. JetStream now allows you to publish a number of messages atomically in a batch. https://github.com/nats-io/nats.js/pull/322
  - feat: add `allow_msg_counter` to stream configurations. This features enables the use of streams as a counter. For an incubating API see [orbit counters](https://github.com/synadia-io/orbit.js/blob/main/counters/README.md) https://github.com/nats-io/nats.js/pull/317
  - feat: add Raft group and traffic account metadata to cluster types https://github.com/nats-io/nats.js/pull/319
  - feat: Support for message scheduling by setting the streams `allow_msg_schedules` and using `ScheduleOptions` in the `JetStreamPublishOptions`.  https://github.com/nats-io/nats.js/pull/321
  - feat: Added support for `Prioritized` policy for pull consumers https://github.com/nats-io/nats.js/pull/323
  - feat(jetstream): Add support to configure `PersistMode` stream configurations https://github.com/nats-io/nats.js/pull/327
  - feat: It is now possible to remove stream `mirrors` via update API https://github.com/nats-io/nats.js/pull/320
  - fix: NATS server 2.12 changed how pending messages were reported when accessed via the Direct API. https://github.com/nats-io/nats.js/pull/314

### Key-Value Store

  - feat(kv): introduce key and payload codecs for customizable key-value encoding and decoding https://github.com/nats-io/nats.js/pull/305
  - feat(kv): TTL support entries https://github.com/nats-io/nats.js/pull/306

### Object Store

  - fix:replicas api option was leaking into object store configuration where the only supported value, which was set correctly, is num_replicas. Servers 2.12+ which validate configurations would reject the operation if this value was set. https://github.com/nats-io/nats.js/pull/315
  

### Node Transport

  - fix: changed DNS resolution to use dns.lookup() instead of dns.resolveX() as this allows overrides such as /etc/hosts to work properly https://github.com/nats-io/nats.js/pull/310
  - fix: ensure proper cleanup of socket in discard() method. In some container setups under Windows. https://github.com/nats-io/nats.js/pull/309
 



**Full Changelog**: https://github.com/nats-io/nats.js/compare/v3.1.0...v3.2.0

---

### `v3.1.0` — v3.1.0 — published 2025-07-09

https://github.com/nats-io/nats.js/releases/tag/v3.1.0

## What's Changed

This release introduces features to Core (tracing), JetStream (per-message ttls, pinned consumers, subject-based sequence constraints) and KV (per-message ttls, timeout support for put/update operations) and improve the reliability of the client.

## Core
* feat(core): tracing - Introduced `TraceOptions` in `PublishOptions`, `RequestOptions`, and `RequestManyOptions` to enable message tracing with NATS. Trace messages are sent to a `traceDestination` subject and optionally flagged as `traceOnly` to avoid delivery and generate trace data only by @aricart in https://github.com/nats-io/nats.js/pull/265
* fix(core): use InstanceType for TE and TD type annotations by @Roseidon in https://github.com/nats-io/nats.js/pull/298
* fix(core): status iterator can now yield a `close` event signaling that the client closed by @aricart in https://github.com/nats-io/nats.js/pull/277
* refactor(core): remove redundant type assertions in Subscription by @aricart in https://github.com/nats-io/nats.js/pull/293

## JetStream
* feat(kv,jetstream)Add support for per-message TTLs in KV and JetStream by @aricart in https://github.com/nats-io/nats.js/pull/281
* feat(jetstream): pinned consumers by @aricart in https://github.com/nats-io/nats.js/pull/263
* feat(jetstream): support for pedantic mode in consumer creation by @aricart in https://github.com/nats-io/nats.js/pull/264 and https://github.com/nats-io/nats.js/pull/275
* feat(js): add support for subject-based sequence constraints. These allow constraints for sequences to be applied to a different using a different subject, simplifying constraints for hierarchical subjects by @aricart in https://github.com/nats-io/nats.js/pull/287
* fix(js): improve handling of 409 status and `max_bytes` edge cases by @aricart in https://github.com/nats-io/nats.js/pull/286
* fix(js): update tests to reflect changes in 2.11.6 behavior for `max_waiting` where 409 for exceeded `max_waiting` errors are not sent to the client when requests have an expires. This means that consumers will rely on heartbeats to pull again by @aricart in https://github.com/nats-io/nats.js/pull/291
* fix(js): improved the typings for `DirectBatchOptions` types by @aricart in https://github.com/nats-io/nats.js/pull/289
* tests(js): Add test and logic to bypass JetStream checks for bind-only by @aricart in https://github.com/nats-io/nats.js/pull/272
* tests(js): Add timeout tests for JetStream clients and managers by @aricart in https://github.com/nats-io/nats.js/pull/274

## KV
* feat(kv,jetstream)Add support for per-message TTLs in KV and JetStream by @aricart in https://github.com/nats-io/nats.js/pull/281
* feat(kv): timeout support for put and update operations by @aricart in https://github.com/nats-io/nats.js/pull/273

## Obj
* Update types.ts: clarify timeout in ObjectStorePutOpts by @alexbozhenko in https://github.com/nats-io/nats.js/pull/261

## Services
* fix(service): stop iterators when the subscription closes. by @aricart in https://github.com/nats-io/nats.js/pull/288

* Update README.md by @alexbozhenko in https://github.com/nats-io/nats.js/pull/262

## Transport-Node
* Introduced `NodeTlsOptions` and `NodeConnectionOptions` types to handle Node.js-specific TLS configurations, like `rejectUnauthorized`. Updated `connect`, for transport-node, and related logic to support these new options by @aricart in https://github.com/nats-io/nats.js/pull/260

## Docs
* doc: add extra link to runtimes to make it more discoverable by @alexbozhenko in https://github.com/nats-io/nats.js/pull/185
* Fix typo in a comment by @williamstein in https://github.com/nats-io/nats.js/pull/266
* Update URL paths for full JetStream examples by @maxdemaio in https://github.com/nats-io/nats.js/pull/267
* fix(doc): runtime was describing `Svc` (the original name of the type)  instead of `Svcm` by @aricart in https://github.com/nats-io/nats.js/pull/276
* fix(doc): fixed the deno installation command by @LeUKi in https://github.com/nats-io/nats.js/pull/279
* docs: added new types exposed by the current api by @aricart in https://github.com/nats-io/nats.js/pull/278
* updated docs by @aricart in https://github.com/nats-io/nats.js/pull/280

## CI
* chore: remove GitHub action workflows and update package versions by @aricart in https://github.com/nats-io/nats.js/pull/290
* chore: add utility for managing module versions by @aricart in https://github.com/nats-io/nats.js/pull/295

## New Contributors
* @williamstein made their first contribution in https://github.com/nats-io/nats.js/pull/266
* @maxdemaio made their first contribution in https://github.com/nats-io/nats.js/pull/267
* @LeUKi made their first contribution in https://github.com/nats-io/nats.js/pull/279
* @Roseidon made their first contribution in https://github.com/nats-io/nats.js/pull/298

**Full Changelog**: https://github.com/nats-io/nats.js/compare/v3.0.2...v3.1.0

---

## Open issues at 2026-09-04 (14) — number, opened, title

- #429 — 2026-08-31 — Updating JS consumer fails when moving from `filter_subject` to `filter_subjects`
- #427 — 2026-08-18 — Secrets Disclosure in Debug Logs
- #426 — 2026-08-10 — kv: history() reports a truncated read as a complete one when the link drops
- #423 — 2026-06-12 — status() returns a "reconnect" type status for each retry
- #419 — 2026-06-02 — Rename markerTTL in Bucket.create()
- #405 — 2026-05-08 — Implementing Cloudflare Workers Runtime
- #360 — 2026-01-22 — Protocol-level status iterator for observability/instrumentation
- #328 — 2025-09-21 — [JetStream] Client-side Partitioned Consumer Groups
- #292 — 2025-07-02 — Unresolved Connection
- #229 — 2025-03-17 — `Kvm.open` accepts `Partial<KvOptions>` but `Objm.open` does not.
- #228 — 2025-03-17 — TTL on KV and OS differ in unit size (nano/milli)
- #218 — 2025-03-12 — Explicit message pulling with `consume()`
- #188 — 2025-01-10 — ensure base api request uses the inherited timeouts, for some apis including kv gets
- #127 — 2024-11-08 — Feature: Chrome Direct Sockets API
