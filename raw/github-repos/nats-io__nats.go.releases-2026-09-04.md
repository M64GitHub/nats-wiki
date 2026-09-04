<!-- source: https://github.com/nats-io/nats.go through the GitHub REST API (`gh api repos/nats-io/nats.go/releases?per_page=10` and `gh api repos/nats-io/nats.go/issues?state=open --paginate`) · fetched 2026-09-04 · release bodies verbatim (CRLF normalised to LF); open issues as number, open date and title only, pull requests excluded -->
# nats-io/nats.go — the last 10 release bodies, and the open issues at 2026-09-04

Fetched for step 8 of `inbox/plan-the-client-side-2026-09-03.md` (*What bites you* on the client entities). The `learn/resilient-clients` chapter states each client's behaviour without a version; a client's own release notes are the only public record that dates it.

## Releases

### `v1.53.1` — Release v1.53.1 — published 2026-08-11

https://github.com/nats-io/nats.go/releases/tag/v1.53.1

## Changelog

This is a patch release containing no functional changes.

### FIXED

- `Version` const and the README install line, which were not updated for v1.53.0 (#2118)

### Complete Changes

https://github.com/nats-io/nats.go/compare/v1.53.0...v1.53.1

---

### `v1.53.0` — Release v1.53.0 — published 2026-08-11

https://github.com/nats-io/nats.go/releases/tag/v1.53.0

## Changelog

### ADDED

- JetStream:
  - `WithPublishAsyncAckHandler` option for JetStream async publish. Thanks @occamist for the contribution (#2109)
  - `AckFlowControlPolicy` to legacy API (#2091)
- Micro:
  - `micro.WithEndpointMetadataKey`. Thanks @joeriddles for the contribution (#2079)

### FIXED

- Core NATS:
  - Websocket connection with path. Thanks @joeriddles for the contribution (#2092)
  - `MsgsTimeout` iterator yielding a spurious `(nil, nil)` after a timeout. Thanks @sueun-dev and @c-tonneslan for the contributions (#2099, #2093)
- JetStream:
  - Data race in `resetOrderedConsumer` when resets overlap (#2111)
  - Avoid panic in `PullSubscribe` consumer create path. Thanks @wyf027 for the contribution (#2088)
  - Honor per-request `JSOpt` API prefix across JetStream APIs. Thanks @wyf027 for the contribution (#2087)
  - Add nil checks for empty JetStream API responses. Thanks @colecschmidt for the contribution (#2073)
- KeyValue:
  - Recognize error code 10164 for replicated KV CAS conflicts (#2098)
  - Reject keys with consecutive dots in `keyValid` and `searchKeyValid`. Thanks @c-tonneslan for the contribution (#2076)
- Micro:
  - Endpoint subject prefix over-match. Thanks @vsaraikin for the contribution (#2105)

### IMPROVED

- Performance enhancement when publishing core NATS messages with headers. Thanks @jonchammer for the contribution (#2083)
- Migrate tests to ntf (#2082)
- Add docs.nats.io examples to main (#2106)
- Improve readme wording for JetStream consumers. Thanks @trevorah for the contribution (#2104)

### Complete Changes

https://github.com/nats-io/nats.go/compare/v1.52.0...v1.53.0

---

### `v1.52.0` — Release v1.52.0 — published 2026-05-07

https://github.com/nats-io/nats.go/releases/tag/v1.52.0

## Changelog

This release focuses on 2.14 nats-server features support.

### ADDED

- JetStream:
  - Added fast batch stream config field (#2052)
  - Added message scheduling headers and publish opts (#2051)
  - Updated `StreamConfig` with `Consumer` field and added `AckFlowControlPolicy` (#2070)
  - Added reset consumer API (#2069)

### FIXED

- Core NATS:
  - Fix Subscription.StatusChanged channel closure on Closed Subscription. Thanks @nithimani38-prog for the contribution (#2034)

### IMPROVED

- Fixed Flaky JS cluster tests (#2062)

### Complete Changes

https://github.com/nats-io/nats.go/compare/v1.51.0...v1.52.0

---

### `v1.51.0` — Release v1.51.0 — published 2026-04-14

https://github.com/nats-io/nats.go/releases/tag/v1.51.0

## Changelog

### ADDED

- Core NATS:
  - Option to customize write buffer size (#2057)
  - Option to automatically reconnect on write error (#2055)
  - Accessors for JetStream API level and `IsSysAccount` from `ServerInfo` (#2060)

### FIXED

- Core NATS:
  - Make websocket frame validation more robust (#2050)
- JetStream:
  - Fix deadlock in `Consume()` when calling `Stop`/`Drain` from `ConsumeErrHandler` (#2059)

### IMPROVED

- Fix typos in tests. Thanks @deining for the contribution (#2049)
- Fix deprecation warnings by bumping GH actions to their latest versions. Thanks @deining for the contibution (#2048) 
- Code linting: remove functions min and max. Thanks @deining for the contribution (#2047)

### Complete Changes

https://github.com/nats-io/nats.go/compare/v1.50.0...v1.51.0

---

### `v1.50.0` — Release v1.50.0 — published 2026-03-25

https://github.com/nats-io/nats.go/releases/tag/v1.50.0

## Changelog

### FIXED

- Core NATS:
  - Fix WebSocket close frame discarding buffered data frames (#2032)
- JetStream:
  - Remove status listener in Consume()/Messages() cleanup. Thanks @txuna for the contribution (#1993)
  - Fix race condition in `orderedSubscription.Drain()` (#2030)
  - Fixed `OrderedConsumer.Consume()` race in handler (#2043)

### IMPROVED

- Core NATS:
  - De-flake TestAlwaysReconnectOnAccountMaxConnectionsExceededErr (#2042)
  - Wrap EOF/connection reset errors with TLS context after handshake (#2031)
- JetStream:
  - Reject control characters in stream and consumer names (#2038)
  - Add missing `AccountLimits` fields in `jetstream` package (#2041)
  - Fix flaky TestConsumerPrioritized/messages test (#2033)
- KeyValue:
  - Deduplicate keys in KeyValue.Keys() and document ListKeys behavior (#2029)
  - Fix flaky TestKeyValueWithSources (#2036)

### CHANGED

- Bump go version to 1.25 and update dependencies (#2044, #2039)

### Complete Changes

https://github.com/nats-io/nats.go/compare/v1.49.0...v1.50.0

---

### `v1.49.0` — Release v1.49.0 — published 2026-02-23

https://github.com/nats-io/nats.go/releases/tag/v1.49.0

## Changelog

### ADDED

- Core NATS:
  - `IgnoreDiscoveredServers` option for skipping advertised servers (#2022)
  - Reconnect to selected server callback option #1958)
  - Set custom server pool (#1958)
- KeyValue:
  - `Config()` method for `KeyValueStatus` (#2014)

### FIXED

- Core NATS:
  - Only remove requested status listener (#1991)
- JetStream:
  - Cleanup JS Publisher Status Channel (#1993)
- Legacy JetStream:
  - Fix nil pointer dereference in `ConsumerInfo`. Thanks @olde-ducke for the contribution (#1987) 
- Object store:
  - Use default timeout on object `Put` when context has no deadline (#2013)

### IMPROVED

- Various docs and test improvements across the codebase. Thanks @jjpinto for the contribution! (#1995, #1996, #1997, #1998, #1999, #2000, #2001, #2002, #2003, #2004, #2005, #2007, #2008, #2009, #2010, #2011, #2012, #2016, #2017, #2018, #2019, #2020)
- Add JetStream migration guide (#2023)

### Complete Changes

https://github.com/nats-io/nats.go/compare/v1.48.0...v1.49.0

---

### `v1.48.0` — Release v1.48.0 — published 2025-12-17

https://github.com/nats-io/nats.go/releases/tag/v1.48.0

## Changelog

### ADDED
- Core NATS:
  - Add publish subject validation and a connection option to skip it (#1974, #1979)
- KeyValue:
  - Enable custom subject transforms on KV sourcing (#1960)

### FIXED
- JetStream:
  - Fix function pointer check in `js.apiRequestWithContext`. Thanks @svenfoo for the contribution (#1957)
  - Use QueueSubscribe if DeliverGroup is configured on PushConsumer (#1966)
- KeyValue:
  - Fix data race when closing watcher updates channel in kv.go (#1965)

### IMPROVED
- Remove extraneous PullThresholdMessages type definition from README. Thanks @PeterBParker for the contribution (#1959)
- Fix typo in README for service creation method (#1962)
- Mention performance implications of using Consumer.Fetch in docs (#1983)

### Complete Changes

https://github.com/nats-io/nats.go/compare/v1.47.0...v1.48.0

---

### `v1.47.0` — Release v1.47.0 — published 2025-10-14

https://github.com/nats-io/nats.go/releases/tag/v1.47.0

## Changelog

### ADDED
- Core NATS:
  - Support sending custom WebSocket headers on connect. Thanks @saurabhojha for the contribution (#1919)

### FIXED
- Core NATS:
  - Capture async callbacks before pushing on dispatch queue (#1955)
- Object Store:
  - Fixed data race when cancelling context while getting object (#1949)
- JetStream:
  - Fixed double channel close on simultaneous Stop and Drain (#1953)

### IMPROVED
- Clarify `MessagesContext.Next()` doc (#1951)

### Complete Changes

https://github.com/nats-io/nats.go/compare/v1.46.1...v1.47.0

---

### `v1.46.1` — Release v1.46.1 — published 2025-09-30

https://github.com/nats-io/nats.go/releases/tag/v1.46.1

## Changelog

### FIXED
- JetStream:
  - Add omitempty to AllowMsgTTL and AllowMsgCounter (#1947)

### Complete Changes

https://github.com/nats-io/nats.go/compare/v1.46.0...v1.46.1

---

### `v1.46.0` — Release v1.46.0 — published 2025-09-22

https://github.com/nats-io/nats.go/releases/tag/v1.46.0

## Changelog

### Overview
This release enables features introduced in [nats-server@v2.12.0](https://github.com/nats-io/nats-server/releases/tag/v2.12.0).

Some features, while enabled in the client by adding relevant configuration, have APIs exposed in [synadia-io/orbit.go](https://github.com/synadia-io/orbit.go), namely:
- [Distributed Counters](https://github.com/synadia-io/orbit.go/blob/main/counters/README.md)
- [Atomic batch publish](https://github.com/synadia-io/orbit.go/blob/main/jetstreamext/README.md#atomic-batch-publishing)

### ADDED
- JetStream:
  - Stream counters configuration option (#1932, #1939)
  - New fields in `ClusterInfo` (#1935)
  - `AllowAtomicPublish` stream configuration option (#1940)
  - `PersistMode` stream config option for configurable stream persistence settings (#1943)
  - `AllowMsgSchedules` stream configuration option to enable message scheduling (#1942)
  - Context and timeout options to `Messages.Next()` plus `Fetch` context support (#1938)
  - Support custom name prefix for ordered consumers (#1928)
  - Prioritized priority policy (#1937)
- KeyValue:
  - Added KeyValue bucket metadada support (#1944)

### IMPROVED
- JetStream:
  - Add max consumers limit error (code=10026). Thanks @Arlet2 for the contribution (#1922)
  - Return more specific cons info error on ordered consumer recreation (#1931)

### Complete Changes

https://github.com/nats-io/nats.go/compare/v1.45.0...v1.46.0

---

## Open issues at 2026-09-04 (120) — number, opened, title

- #2128 — 2026-09-01 — Receiving `ErrConnectionClosed` from `RequestWithContext` during a reconnect
- #2115 — 2026-08-06 — High severity vulnerability on dependency github.com/klauspost/compress
- #2107 — 2026-07-22 — Ordered consumer silently loses messages on a client-side slow-consumer episode (no gap detection, no reset)
- #2100 — 2026-06-29 — bug: DecodeHeadersMsg slice out-of-range panic on short status token
- #2068 — 2026-05-05 — Reduce overhead associated when publishing core NATS messages with headers
- #2063 — 2026-04-23 — `ErrConsumerLeadershipChanged` does not trigger new pull request, causing consumer to stall
- #2053 — 2026-03-12 — Object store mtime is alsways '0001-01-01T00:00:00Z'
- #2028 — 2026-02-23 — JetStream consumers not processing messages
- #2024 — 2026-02-19 — EOF returned instead of real error when connecting with websockets and an expired jwt token
- #1994 — 2026-01-20 — KeyValue.Update does not properly reset TTL
- #1992 — 2026-01-16 — Option to specify or check minimum server version on connection
- #1985 — 2025-12-18 — Publishing the scheduled message to NATS
- #1969 — 2025-11-18 — Add JSON representation of KeyValueEntry
- #1968 — 2025-11-14 — Jetstream: key header changes when received by the consumer
- #1961 — 2025-10-28 — Document message lifecycle
- #1929 — 2025-08-28 — Jetstream messages being handled after redelivery
- #1908 — 2025-07-22 — r=3 object store fails to accept large files
- #1895 — 2025-07-06 — Cross-account Object Store - Unable to Put
- #1874 — 2025-05-15 — Support mirrored ObjectStore
- #1870 — 2025-05-03 — nats.ConnectedHandler is not being called
- #1867 — 2025-05-01 — Add Keys function to Header
- #1865 — 2025-04-24 — Deadlock on PublishMsgAsync on 1.41.2
- #1855 — 2025-04-15 — Document `Subscription` (and possibly other types) as thread-safe
- #1854 — 2025-04-15 — Multi-threaded use of sub.Fetch may result in server spamming
- #1861 — 2025-03-21 — JetStream bucket put calls should support ctx
- #1809 — 2025-02-27 — NATS Protocol Violation on newline in subject
- #1800 — 2025-02-12 — missing dependencies
- #1799 — 2025-02-05 — Jetstream consumer max deliver
- #1784 — 2025-01-22 — KV cross-account watch not receiving any messages
- #1781 — 2025-01-16 — JetStream publish api needs better Leader election signal
- #1777 — 2025-01-15 — Key Value Watch does not automatically recover after connection lost
- #1757 — 2024-12-19 — Add more options to create a jetstream.GetMsgOpt
- #1738 — 2024-11-19 — Pagination to Jetstream KV
- #1731 — 2024-10-27 — Add identification property to subscriptions
- #1717 — 2024-09-23 — why consumer redelivered again when msg.DoubleAck with no error
- #1718 — 2024-09-13 — Pull consumer with max bytes setting causes high CPU usage [v2.10.18]
- #1703 — 2024-08-23 — Consume() timeout in between pulls
- #1696 — 2024-08-08 — Unexpected delay and duplicate messages on Fetch for pull-based subscription
- #1679 — 2024-07-18 — Failed to create OrderedConsumer
- #1662 — 2024-06-21 — Using Fetch() with and OrderedConsumer and a delivery policy of DeliverLastPerSubjectPolicy returns incorrect results
- #1650 — 2024-06-16 — Memory leak in readMIMEHeader 
- #1648 — 2024-06-14 — Object store publishes chunks without using domain in subject
- #1641 — 2024-06-05 — Panic when creating jet stream consumer on wildcard stream
- #1627 — 2024-05-03 — Request Reply for JetStream for autoscaling and scaling to zero (similar to Knative)
- #1622 — 2024-04-22 — I often get the error nats: no heartbeat received
- #1620 — 2024-04-22 —  How to retrieve the status of a consumer.
- #1614 — 2024-04-17 — Cannot unsubscribe after panic, alloc lots of memory when startup
- #1612 — 2024-04-16 — JetStream: the value for max pending async messages can be exceeded
- #1593 — 2024-03-28 — jetStreamContext.PublishMsg memory consumption grow over time if nats server fail or restart
- #1591 — 2024-03-21 — jetstream.CreateOrUpdateKeyValue doesn't handle the Domain property of jetstream.ExternalStream correctly when mirroring
- #1590 — 2024-03-21 — Fetch in the JetStream Simplified Client should behave similar to the old API.
- #1588 — 2024-03-20 — jetstream.Consumer.Consume() does not respect ConsumerConfig
- #1583 — 2024-03-12 — SubscribeSync should return error on permissions violation
- #1572 — 2024-02-28 — [BUG] If the subject is very long, the connection will be broken
- #1562 — 2024-02-21 — Panic on Calling Drain on a nil NATS Connection
- #1535 — 2024-01-26 — Sequence number mismatch in NATS client after reconnection
- #1528 — 2024-01-18 — Document typed errors returned by interfaces
- #1545 — 2023-12-29 — Trailing slash on URL leads to connection errors
- #1508 — 2023-12-26 — Implement the `io.ReadSeeker` interface for the `ObjectResult` type
- #1501 — 2023-12-18 — MaxPending gives decrease number
- #1485 — 2023-12-11 — KV and Object need to allow for an option to limit the number of entries they return when listing keys
- #1483 — 2023-12-06 — Client labels or custom attributes
- #1482 — 2023-12-02 — Proper timeout handling in `func (*pullConsumer) fetch()`
- #1480 — 2023-11-28 — NATS JetStream Pull Subscribe Not delivering messages on a Work Queue intermittently 
- #1461 — 2023-11-06 — `jetstream.PublishMsg` is not guaranteed to return `ErrNoStreamResponse` when there is no stream configured
- #1446 — 2023-10-17 — Proposal to update channel subscriptions behavior and/or documentation around Pending and Draining
- #1407 — 2023-09-19 — JetSteam: New API that returns new *nats.Conn connected to Stream's Leader
- #1403 — 2023-09-15 — OpenAPIV3Schema Should also contain Status Property
- #1363 — 2023-08-04 — Automatically detect and handle certificate changes
- #1297 — 2023-06-06 — Micro should have dynamic subscribe and unsubscribe for extra endpoints
- #1276 — 2023-05-28 — Client encoding headers using http.Header.Write discards valid headers under ADR-4
- #1269 — 2023-05-18 — consumer is already bound to a subscription
- #1262 — 2023-05-11 — More flexible inbox prefix.
- #1255 — 2023-04-26 — IdleHeartbeat for nats.KeyWatcher
- #1252 — 2023-04-20 — Parity issue with `ObjectInfo.ModTime`
- #1247 — 2023-04-14 — Allow to use `SubscribeSync` for `EncodedConn`
- #1243 — 2023-04-02 — Object deletion leads to unexpected result
- #1241 — 2023-03-29 — Middleware for nats.micro
- #1222 — 2023-02-28 — Use faster json encoder/decoder
- #1198 — 2023-01-26 — ability to set up the eviction policy in the KV Store
- #1191 — 2023-01-17 — nats does not release memory
- #1183 — 2023-01-05 — Review and verify that on create of streams and consumers, naming errors are surfaced in the client
- #1163 — 2022-12-16 — Unbound memory footprint growth with slow consumers
- #1120 — 2022-11-03 — Improve error messages
- #1103 — 2022-10-08 — Failed initial INFO message from server is hard to understand
- #1098 — 2022-10-04 — Improve error/status tracking for ordered consumers
- #1093 — 2022-09-26 — UserCredentials should return error
- #1065 — 2022-09-01 — Add support for proxy configuration for websocket connection
- #1033 — 2022-08-04 — Ordered consumer subscription can become invalid
- #1021 — 2022-07-26 — Partial PUT and Get objectstore
- #1017 — 2022-07-20 — PubOpt adding compression configuration
- #1003 — 2022-06-24 — Can't get large file
- #940 — 2022-03-29 — Connection string options
- #891 — 2022-01-28 — ADD: Option to instruct client to ignore discovered URLs from server INFO messages, and use only the initial Connect URL
- #889 — 2022-01-26 — Golang client JSON encoder reply response coming back in base64
- #867 — 2021-12-02 — JetStream Examples
- #855 — 2021-11-04 — Remove requirement for context.Context to have a deadline
- #839 — 2021-10-06 — When stream is not available the error message is shown as JetStream system temporarily unavailable
- #817 — 2021-09-06 — Support for Go Micro Broker plugin
- #741 — 2021-06-02 — unify JS errors 
- #738 — 2021-05-27 — Parser accepts inlined status directly after `NATS/1.0`
- #736 — 2021-05-26 — PullSubscription must match Consumer Filter Subject
- #701 — 2021-04-01 — Add Callback similar to nats.ConnErrHandler for in options for nc.JetStream()
- #661 — 2021-02-16 — Support for wasm
- #616 — 2020-12-07 — Stream not being stored (file) after first run when NATS and JS embedded
- #588 — 2020-08-18 — Support cross compiling for Web Browsers and Embedded devices.
- #584 — 2020-08-12 — add a Request() that has a option to wait for multiple results rather than just 1
- #580 — 2020-06-24 — Hardcoded FlushTimeout values
- #556 — 2020-04-23 — multiple response requests `Stream`, `Chunked` should be one 'Multiple'
- #555 — 2020-04-23 — subject rewriting responses are handled incorrectly
- #553 — 2020-04-20 — JSON encoded connection doesn't report error on bad JSON
- #551 — 2020-04-17 — The readme page shows usage that won't work if an user tries it out
- #547 — 2020-03-18 — Possible bug in sub pending()
- #545 — 2020-03-01 — ConnectedURL should show tls
- #517 — 2019-09-11 — nc.Request speed test 
- #474 — 2019-06-01 — Error message required when invalid message subject is given.
- #413 — 2018-12-12 — add support for multi subcribe topic master/ backup mode ?
- #307 — 2017-07-19 — Connect error visibility
- #197 — 2016-06-30 — Add Tuning Parameters
- #86 — 2015-10-13 — Better capture pending writes when getting disconnected
