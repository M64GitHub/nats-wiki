<!-- source: https://github.com/nats-io/nats.rs through the GitHub REST API (`gh api repos/nats-io/nats.rs/releases?per_page=10` and `gh api repos/nats-io/nats.rs/issues?state=open --paginate`) · fetched 2026-09-04 · release bodies verbatim (CRLF normalised to LF); open issues as number, open date and title only, pull requests excluded -->
# nats-io/nats.rs — the last 10 release bodies, and the open issues at 2026-09-04

Fetched for step 8 of `inbox/plan-the-client-side-2026-09-03.md` (*What bites you* on the client entities). The `learn/resilient-clients` chapter states each client's behaviour without a version; a client's own release notes are the only public record that dates it.

## Releases

### `async-nats/v0.50.0` — async-nats/v0.50.0 — published 2026-07-20

https://github.com/nats-io/nats.rs/releases/tag/async-nats/v0.50.0

## Overview

This release allows for on-demand swap between `chrono` and `time` crates.

## What's Changed
* Add chrono as alternative to time crate by @Jarema in https://github.com/nats-io/nats.rs/pull/1595
* Use new start method for retry start in nats-server crate by @Jarema in https://github.com/nats-io/nats.rs/pull/1603
* Fix account info deser failure on servers with tiered jetstream by @xanderio in https://github.com/nats-io/nats.rs/pull/1604

## Chrono vs Time

Enabling `chrono` anywhere in the
dependency graph selects the chrono backend for the whole build (Cargo feature unification).

## New Contributors
* @xanderio made their first contribution in https://github.com/nats-io/nats.rs/pull/1604

**Full Changelog**: https://github.com/nats-io/nats.rs/compare/async-nats/v0.49.1...async-nats/v0.50.0

---

### `async-nats/v0.49.1` — async-nats/v0.49.1 — published 2026-06-04

https://github.com/nats-io/nats.rs/releases/tag/async-nats/v0.49.1

## Overview
Release focusing on fixing behaviour around server connectivity.

## What's Changed
* Fix ping interval reset by @Jarema in https://github.com/nats-io/nats.rs/pull/1594
* Fix recreating ordered consumer on server restart by @Jarema in https://github.com/nats-io/nats.rs/pull/1599


**Full Changelog**: https://github.com/nats-io/nats.rs/compare/async-nats/v0.49.0...async-nats/v0.49.1

---

### `async-nats/v0.49.0` — async-nats/v0.49.0 — published 2026-05-25

https://github.com/nats-io/nats.rs/releases/tag/async-nats/v0.49.0

## Overview

This is a small release adding missing client-side max-payload validations for some methods.
It is a minor release as it adds new error kind variants for relevant calls.

## What's Changed
* Add TryFrom impls for HeaderName by @yordis in https://github.com/nats-io/nats.rs/pull/1587
* Add max payload validation where it was missing by @Jarema in https://github.com/nats-io/nats.rs/pull/1590

## New Contributors
* @scottf made their first contribution in https://github.com/nats-io/nats.rs/pull/1579

**Full Changelog**: https://github.com/nats-io/nats.rs/compare/async-nats/v0.48.0...async-nats/v0.49.0

---

### `async-nats/v0.48.0` — async-nats/v0.48.0 — published 2026-05-07

https://github.com/nats-io/nats.rs/releases/tag/async-nats/v0.48.0

This release focuses on 2.14 nats-server features support.

## Added
* Add recent jetstream error codes by @Jarema in https://github.com/nats-io/nats.rs/pull/1564
* Add server pool callback by @Jarema in https://github.com/nats-io/nats.rs/pull/1559
* Add Source.consumer for durable sourcing by @Jarema in https://github.com/nats-io/nats.rs/pull/1581
* Add AckPolicy::FlowControl by @Jarema in https://github.com/nats-io/nats.rs/pull/1581
* Add Consumer Reset API by @Jarema in https://github.com/nats-io/nats.rs/pull/1581
* Add 2.14 schedule, batch, and rollup header constants by @Jarema in https://github.com/nats-io/nats.rs/pull/1581
* Add PublishAck batch_id and batch_size fields by @Jarema in https://github.com/nats-io/nats.rs/pull/1581
* Add `try_server_info` and `max_payload` methods by @yordis in https://github.com/nats-io/nats.rs/pull/1567

## Fixed
* Fix typo in create_or_update_key_value example by @ayymart in https://github.com/nats-io/nats.rs/pull/1569
* Fix linter warning by @Jarema in https://github.com/nats-io/nats.rs/pull/1570
* Preserve unsubscribe_after limit across reconnects by @MattPatchava in https://github.com/nats-io/nats.rs/pull/1560
* Fix panic on reading non-utf8 data by @Jarema in https://github.com/nats-io/nats.rs/pull/1573

## Changed
* Bump rand by @Jarema in https://github.com/nats-io/nats.rs/pull/1566
* Bump to thiserror v2 by @aumetra in https://github.com/nats-io/nats.rs/pull/1571
* Orbit docs by @Jarema in https://github.com/nats-io/nats.rs/pull/1580
* Cover remaining 2.14 server error codes and predefined cron schedules by @Jarema in https://github.com/nats-io/nats.rs/pull/1581

## New Contributors
* @ayymart made their first contribution in https://github.com/nats-io/nats.rs/pull/1569
* @aumetra made their first contribution in https://github.com/nats-io/nats.rs/pull/1571
* @yordis made their first contribution in https://github.com/nats-io/nats.rs/pull/1567

**Full Changelog**: https://github.com/nats-io/nats.rs/compare/async-nats/v0.47.0...async-nats/v0.48.0
# v0.47.0

---

### `async-nats/v0.47.0` — async-nats/v0.47.0 — published 2026-03-31

https://github.com/nats-io/nats.rs/releases/tag/async-nats/v0.47.0

This release adds subject validation (with opt-out possibility) and wraps while connect attempt in timeout, making it more robust.

## Added
* Add Subject Validation by @Jarema in https://github.com/nats-io/nats.rs/pull/1525
* Add respond_with_headers method to handle responses with custom headers by @giddyos in https://github.com/nats-io/nats.rs/pull/1554
* Add local_address option to bind client to a specific local IP by @wallyqs in https://github.com/nats-io/nats.rs/pull/1539
* Implement Clone for ConnectOptions by @MattPatchava in https://github.com/nats-io/nats.rs/pull/1552

## Fixed
* Fix invalid consumer rate limit json by @Totodore in https://github.com/nats-io/nats.rs/pull/1536
* Return error instead of panic when reply subject is empty by @liamkinne in https://github.com/nats-io/nats.rs/pull/1514
* Use proper doc comments by @Xaeroxe in https://github.com/nats-io/nats.rs/pull/1543
* Fix connection_timeout to cover full NATS handshake by @rahsonaw in https://github.com/nats-io/nats.rs/pull/1544

## Changed
* Update rustls-native-certs from 0.7 to 0.8 by @FreeMasen in https://github.com/nats-io/nats.rs/pull/1507
* Remove `once_cell` and use std::sync::LazyLock instead by @Jarema in https://github.com/nats-io/nats.rs/pull/1534
* Bump bytes crate by @Jarema in https://github.com/nats-io/nats.rs/pull/1540
* Bump msrv by @Jarema in https://github.com/nats-io/nats.rs/pull/1509
* Update rustls-webpki to 0.103.10 by @JohnMoon-Voyager in https://github.com/nats-io/nats.rs/pull/1550
* Update dictionary by @Jarema in https://github.com/nats-io/nats.rs/pull/1556

## New Contributors
* @FreeMasen made their first contribution in https://github.com/nats-io/nats.rs/pull/1507
* @Xaeroxe made their first contribution in https://github.com/nats-io/nats.rs/pull/1543
* @MattPatchava made their first contribution in https://github.com/nats-io/nats.rs/pull/1552
* @JohnMoon-Voyager made their first contribution in https://github.com/nats-io/nats.rs/pull/1550
* @giddyos made their first contribution in https://github.com/nats-io/nats.rs/pull/1554
* @rahsonaw made their first contribution in https://github.com/nats-io/nats.rs/pull/1544

**Full Changelog**: https://github.com/nats-io/nats.rs/compare/async-nats/v0.46.0...async-nats/v0.47.0

---

### `async-nats/v0.46.0` — async-nats/v0.46.0 — published 2026-01-20

https://github.com/nats-io/nats.rs/releases/tag/async-nats/v0.46.0

This release introduces disabled by default feature-gating of features and modules.
Users can now disable `nkeys`, `object-store`, or others, to limit the size of the final binary and dependency pulled in.

## Added
* Hide features & modules behind feature flags by @Jarema in https://github.com/nats-io/nats.rs/pull/1494

## Fixed
* Eliminate build-time warnings for `async-nats` by @vkolomeyko in https://github.com/nats-io/nats.rs/pull/1489
* Fix error deserialization when err_code is absent by @Jarema in https://github.com/nats-io/nats.rs/pull/1497
* Fix slow subscription shutdown after drain by @Jarema in https://github.com/nats-io/nats.rs/pull/1504

## Changed
* Relax type constraints around `ServiceBuilder::start` by @vkolomeyko in https://github.com/nats-io/nats.rs/pull/1486
* Use with_source for CreateError to maintain original error source by @LouiseSianEvans in https://github.com/nats-io/nats.rs/pull/1495
* Switch to rustls-pki-types by @Jarema in https://github.com/nats-io/nats.rs/pull/1492
* Tidy-up `async-nats/src/service/mod.rs` by @vkolomeyko in https://github.com/nats-io/nats.rs/pull/1487
* Make some consumer/stream config accept `omitempty` case by @Jarema in https://github.com/nats-io/nats.rs/pull/1493
* Improve the `drain` docs for better clarity by @Jarema in https://github.com/nats-io/nats.rs/pull/1484

## New Contributors
* @vkolomeyko made their first contribution in https://github.com/nats-io/nats.rs/pull/1489
* @LouiseSianEvans made their first contribution in https://github.com/nats-io/nats.rs/pull/1495

**Full Changelog**: https://github.com/nats-io/nats.rs/compare/async-nats/v0.45.0...async-nats/v0.46.0

---

### `async-nats/v0.45.0` — async-nats/v0.45.0 — published 2025-12-29

https://github.com/nats-io/nats.rs/releases/tag/async-nats/v0.45.0

## Overview

A smaller release adding missing `value` field to `pub_ack` and some additional fixes.

## Added
* Add pub ack `value` field by @Jarema in https://github.com/nats-io/nats.rs/pull/1473
* Add `double_ack_with` method to JetStream Messages by @OtaK in https://github.com/nats-io/nats.rs/pull/1474

## Fixed
* Fix object store headers serde by @Jarema in https://github.com/nats-io/nats.rs/pull/1472
* Fix Kv limit markers in watches by @Jarema in https://github.com/nats-io/nats.rs/pull/1475

**Full Changelog**: https://github.com/nats-io/nats.rs/compare/async-nats/v0.44.2...async-nats/v0.45.0

---

### `async-nats/v0.44.2` — async-nats/v0.44.2 — published 2025-10-08

https://github.com/nats-io/nats.rs/releases/tag/async-nats/v0.44.2

## Overview

This PR adds a new method to Context traits and fixes the docs build

## What's Changed
* Add send_request method to JetStream Context by @Jarema in https://github.com/nats-io/nats.rs/pull/1466
* Fix docs by @Jarema in https://github.com/nats-io/nats.rs/pull/1468


**Full Changelog**: https://github.com/nats-io/nats.rs/compare/async-nats/v0.44.1...async-nats/v0.44.2

---

### `async-nats/v0.44.1` — release async-nats/v0.44.1 — published 2025-10-02

https://github.com/nats-io/nats.rs/releases/tag/async-nats/v0.44.1

## What's Changed
* Add missing errors types by @Jarema in https://github.com/nats-io/nats.rs/pull/1464

**Full Changelog**: https://github.com/nats-io/nats.rs/compare/async-nats/v0.44.0...async-nats/v0.44.1

---

### `async-nats/v0.44.0` — release async-nats/v0.44.0 — published 2025-10-02

https://github.com/nats-io/nats.rs/releases/tag/async-nats/v0.44.0

## Overview
A release that focuses on reorganization of types and improvement of extension traits for [orbit](https://github.com/synadia-io/orbit.rs)

## What's Changed
* Enable service API by default by @Jarema in https://github.com/nats-io/nats.rs/pull/1461
* Extend client traits by @Jarema in https://github.com/nats-io/nats.rs/pull/1456
* Reorganize `message` types by @Jarema in https://github.com/nats-io/nats.rs/pull/1462


**Full Changelog**: https://github.com/nats-io/nats.rs/compare/async-nats/v0.43.1...async-nats/v0.44.0

---

## Open issues at 2026-09-04 (49) — number, opened, title

- #1617 — 2026-08-22 — request() leaks memory for life of Client if no response is received
- #1615 — 2026-08-19 — async-nats: Object Store get/read panics (unwrap() on TimedOut) when the backing stream loses quorum during a leader re-election
- #1613 — 2026-08-18 — Missing Secrets Redaction in Debug formatter for nats::Options
- #1611 — 2026-08-14 — Ordered consumer hardcoded batch size
- #1607 — 2026-07-01 — async-nats: Subscriber::drop panics when dropped outside a Tokio runtime
- #1605 — 2026-06-16 — ObjectStore: modified (mtime) read from JSON payload instead of server message timestamp
- #1585 — 2026-05-11 — Create security patch release for v0.45.0
- #1584 — 2026-05-07 — pull::Consumer::messages() stream exhaustion inconsistency on consumer deletion
- #1561 — 2026-04-05 — Ordered recreates Consumer u32::MAX times
- #1548 — 2026-03-20 — Inconsistent construction of `HeaderValue`
- #1541 — 2026-03-16 — Creating KV store with mirror does not allow the domain field to be used
- #1515 — 2026-02-20 — Long nested log lines `recreate_ordered_consumer`
- #1499 — 2026-01-04 — Add JetStream advisory subject constants
- #1498 — 2026-01-03 — Improve error message for subject overlap errors (ErrorCode 10065)
- #1478 — 2025-10-28 — Types that represent `nats schema` payloads
- #1471 — 2025-10-08 — Support credentials reloading when using `with_credentials_file`
- #1443 — 2025-09-11 — `create_or_update_stream` does not return a `Stream`
- #1436 — 2025-09-04 — BadSignature error when using a (self signed) certificate from the windows certificate store for TLS in the nats server
- #1433 — 2025-08-22 — Space in the subject causes a reply subject to be declared
- #1397 — 2025-04-08 — Durable Consumers time out error w/o explicit error message for `direct_get` when `allow_direct=false` on the stream
- #1371 — 2025-02-13 — JS Push consumers crash the process when the NATS server goes away
- #1369 — 2025-02-11 — Make async-nats independent on the runtime
- #1368 — 2025-01-27 — fromSeed not importing correctly
- #1350 — 2024-12-17 — The source's "domain" is ignored in jetstream.update_stream
- #1317 — 2024-09-15 — create_consumer stuck
- #1313 — 2024-09-11 — Add get_or_create_key_value
- #1284 — 2024-07-04 — Subscription Violation not returned as Subcribe error
- #1276 — 2024-06-07 — Support custom capacity per subscription
- #1272 — 2024-05-27 — Expose a blocking module in async_nats
- #1269 — 2024-05-23 — async-nats is missing a `GetRevision` equivalent
- #1261 — 2024-05-13 — Hard to debug slow consumers with Rust client
- #1260 — 2024-05-11 — Do not print events in case custom event callback was specified
- #1203 — 2024-02-01 — Deliver Subject field in Push Consumer Config should not have a default or warn/error about it being empty
- #1200 — 2024-01-26 — Add more concrete error types
- #1198 — 2024-01-24 — async-nats: Pull consumer issue: "pull request failed: request failed: missing field `stream_name` at line 1 column 129"
- #1194 — 2024-01-15 — async_nats: Endpoint: Remove endpoint from list of stats endpoints when dropped.
- #1193 — 2024-01-11 — The NATS url needs to manually percent decode the username and the password
- #1190 — 2024-01-04 — Support for reading PEM-encoded CA Certificates from a PEM-encoded String
- #1163 — 2023-11-20 — ESP32 Support (or just `no_std` in general)
- #1098 — 2023-08-22 — Enable NATS Client to Run in WebAssembly
- #1078 — 2023-08-04 — Make HeaderValue use `Bytes` internally 
- #1075 — 2023-08-03 — Break apart request and response
- #1042 — 2023-07-18 — async_nats: double_ack() should return an error if the ack_wait period is over
- #909 — 2023-04-03 — Implement `Client::rtt` for async_nats
- #896 — 2023-03-23 — async-nats 1.0.0 release planning
- #798 — 2023-01-05 — Review and verify that on create of streams and consumers, naming errors are surfaced in the client
- #795 — 2023-01-04 — KV Watch iterator hangs on stale bucket connections.
- #685 — 2022-11-02 — Who not supply close() function for async_nats::Client
- #6 — 2020-03-02 — Tracking Async Errors
