<!-- source: https://github.com/nats-io/nats.net through the GitHub REST API (`gh api repos/nats-io/nats.net/releases?per_page=10` and `gh api repos/nats-io/nats.net/issues?state=open --paginate`) · fetched 2026-09-04 · release bodies verbatim (CRLF normalised to LF); open issues as number, open date and title only, pull requests excluded -->
# nats-io/nats.net — the last 10 release bodies, and the open issues at 2026-09-04

Fetched for step 8 of `inbox/plan-the-client-side-2026-09-03.md` (*What bites you* on the client entities). The `learn/resilient-clients` chapter states each client's behaviour without a version; a client's own release notes are the only public record that dates it.

## Releases

### `v3.2.0` — NATS .NET v3.2.0 — published 2026-08-29

https://github.com/nats-io/nats.net/releases/tag/v3.2.0

**Breaking for implementers:** `INatsJSStream` and `INatsJSConsumer` gained members (`ResetConsumerAsync`, `ResetAsync`). Anything implementing these interfaces directly, such as a test double, needs updating. Callers are unaffected. Default implementations are not possible while the client targets netstandard2.0.

JetStream parity with server 2.14:

- Offline assets are now reported on the stream and consumer list responses, keyed by name with the reason, alongside the existing `missing` list (#1248)
- `ConsumerConfig.Sourcing` exposes the flag the server sets on consumers it creates for interest and work queue stream sourcing (#1249)
- Consumers can be reset from the stream and consumer objects, not just the context (#1250)
- Fix TlsPreferTest hang that aborts the Core2 test run (#1246)

---

### `v3.1.1` — NATS .NET v3.1.1 — published 2026-08-25

https://github.com/nats-io/nats.net/releases/tag/v3.1.1

[![NuGet](https://img.shields.io/badge/NuGet-3.1.1-blue)](https://www.nuget.org/packages/NATS.Net/3.1.1)

Patch release on top of 3.1.0, promoting 3.1.1-preview.1 to stable. Most of it is the OpenTelemetry receive path. Receive spans for messages consumed internally by the Key/Value watcher, the ordered push consumer behind the Object Store and service endpoints were never ended, so they never reached a backend; shared-inbox request-reply produced disconnected traces with no request span; a JetStream direct get was traced under the write that stored the value rather than the read; and several span tags were wrong. Also fixes a null array passed on the netstandard2.0 object store put path, and a stall when TCP splits the trailing CRLF of an empty payload message.

* Fix receive activity leak when tracing is enabled (#1229)
* Fix inverted array check in object store put path (#1235)
* Fix OpenTelemetry receive span lifecycle, parenting and tags (#1236)
* Update OpenTelemetry documentation (#1242)
* Fix stall when TCP splits the trailing CRLF of an empty payload message (#1243)

Three changes in #1236 are visible in a tracing backend, so queries and dashboards built on the client's spans may need updating: `messaging.operation` on subscribe and request spans now reads `subscribe` and `request` rather than `publish`, the subscribe span is `ActivityKind.Client` rather than `Producer`, and a reply whose trace id differs from its request is linked rather than parented.

## Thanks

* @ani-philips for reporting the receive activity leak (#1225)
* @fresh55 for the object store put fix (#1235) and for reporting the empty payload stall (#1237)

**Full Changelog**: https://github.com/nats-io/nats.net/compare/v3.1.0...v3.1.1

---

### `v3.1.1-preview.1` — NATS .NET v3.1.1-preview.1 — published 2026-08-07

https://github.com/nats-io/nats.net/releases/tag/v3.1.1-preview.1

[![NuGet](https://img.shields.io/badge/NuGet-3.1.1--preview.1-blue)](https://www.nuget.org/packages/NATS.Net/3.1.1-preview.1)

Preview on the 3.1 patch line with one fix. Receive activities were created on the connection's read loop and left in `Activity.Current`, so a message without its own trace context took the previous message's activity as a parent; unrelated messages chained together and the chain stayed reachable for the life of the connection. Receive activities are now parented only by trace context carried in the message, and activities that were never ended before (messages evicted from a full subscription channel, messages that never reach a consumer) are ended. Worth testing if you run with OpenTelemetry tracing enabled.

- Fix receive activity leak when tracing is enabled (#1229)

Adjacent issues in the same receive path are not covered here: the remainder of #1227, plus #1228, #1230, #1232 and #1233.

Thanks to @ani-philips for reporting the leak (#1225).

**Full Changelog**: https://github.com/nats-io/nats.net/compare/v3.1.0...v3.1.1-preview.1

---

### `v3.1.0` — NATS .NET v3.1.0 — published 2026-07-31

https://github.com/nats-io/nats.net/releases/tag/v3.1.0

[![NuGet](https://img.shields.io/badge/NuGet-3.1.0-blue)](https://www.nuget.org/packages/NATS.Net/3.1.0)

Minor release on top of 3.0.1. Adds subscription events with an OnSubscribed callback, enables full-graph NuGet dependency auditing, and adds documentation examples.

* Add subscription events with OnSubscribed callback (#1217)
* Audit transitive dependencies (#1220)
* Add subject-dispatch serialization example (#1218)
* Add docs.nats.io examples to main (#1216)

The async enumerable returned by SubscribeAsync does not establish the subscription until it is iterated. When the enumerable is handed off to another task, the new OnSubscribed callback signals when it is safe to publish messages the subscription must observe:

```csharp
var subscribed = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

var opts = new NatsSubOpts
{
    Events = new NatsSubEvents
    {
        OnSubscribed = _ =>
        {
            subscribed.TrySetResult();
            return default;
        },
    },
};

var consumer = Task.Run(async () =>
{
    await foreach (var msg in nats.SubscribeAsync<string>("greet", opts: opts))
    {
        // process messages
    }
});

await subscribed.Task;
await nats.PublishAsync("greet", "hello"); // subscription is established
```

OnSubscribed fires once the SUB protocol message has been queued on the subscribing connection, which is enough when publishing on the same connection. If the publisher uses a different connection, add a PingAsync round-trip on the subscribing connection after the callback to be sure the server has processed the subscription:

```csharp
await subscribed.Task;
await nats.PingAsync(); // server has processed the SUB
await otherConnection.PublishAsync("greet", "hello");
```

## Thanks

* @btzdnl for reporting the SubscribeAsync early-return issue and helping with the design (#1178)

---

### `v3.0.1` — NATS .NET v3.0.1 — published 2026-07-20

https://github.com/nats-io/nats.net/releases/tag/v3.0.1

[![NuGet](https://img.shields.io/badge/NuGet-3.0.1-blue)](https://www.nuget.org/packages/NATS.Net/3.0.1)

Patch release on top of 3.0.0. Fixes a JetStream list enumeration cancellation bug and adds opt-in W3C Baggage propagation to the OpenTelemetry integration.

* Fix silent completion when JetStream list enumeration is cancelled (#1214)
* OpenTelemetry: opt-in W3C Baggage propagation (#1208)
* Add explicit permissions to CI workflows (#1213)
* Update README for 3.0 release (#1212)

## Thanks

* @paagamelo2 for reporting the JetStream list cancellation issue (#1193)
* @iamadamreed for the opt-in W3C Baggage propagation support (#1208)

---

### `v3.0.0` — NATS .NET v3.0.0 — published 2026-07-10

https://github.com/nats-io/nats.net/releases/tag/v3.0.0

[![NuGet](https://img.shields.io/badge/NuGet-3.0.0-blue)](https://www.nuget.org/packages/NATS.Net/3.0.0)

NATS .NET 3.0 is now stable. This release has been in the works since early this year and brings OpenTelemetry tracing and metrics, .NET 10 target, and a number of API and behavior changes refined over the preview series. Thanks to everyone who tried the previews and reported issues along the way. There are no changes since 3.0.0-preview.11.

## .NET 10 Target

3.0 targets `netstandard2.0`, `netstandard2.1`, `net8.0`, and `net10.0`. `net6.0` has been dropped.

## OpenTelemetry

* Add OTel metrics support https://github.com/nats-io/nats.net/pull/1154
* Add OpenTelemetry package (tracing) https://github.com/nats-io/nats.net/pull/1172
* Add custom span destination name formatter https://github.com/nats-io/nats.net/pull/1201
* Add OTel ack/dropped metrics and collapse inbox trace tags https://github.com/nats-io/nats.net/pull/1194
* Exclude NATS status frames from consumed metrics https://github.com/nats-io/nats.net/pull/1195
* Fix server.port type and trace tag source https://github.com/nats-io/nats.net/pull/1175
* Fix null-key tag in OpenTelemetry receive fallback https://github.com/nats-io/nats.net/pull/1205
* Match OpenTelemetry subject filters without per-message allocation https://github.com/nats-io/nats.net/pull/1206
* Make shared OpenTelemetry instrumentation options thread-visible https://github.com/nats-io/nats.net/pull/1207

## API and behavior changes

* Add message context to serialization interfaces https://github.com/nats-io/nats.net/pull/1082
* Move socket connection interfaces to NATS.Client.Abstractions https://github.com/nats-io/nats.net/pull/1192
* Default request-reply to Direct mode https://github.com/nats-io/nats.net/pull/1182
* Add explicit subscription and consumer drain https://github.com/nats-io/nats.net/pull/1177
* Deprecate SkipSubjectValidation https://github.com/nats-io/nats.net/pull/1180
* Unify subscription channel overflow defaults https://github.com/nats-io/nats.net/pull/1181
* Use System.Threading.Lock on NET9_0_OR_GREATER https://github.com/nats-io/nats.net/pull/1118
* Clean up NET6 and optimize NETSTANDARD https://github.com/nats-io/nats.net/pull/1072
* Update DI package dependencies and documentation https://github.com/nats-io/nats.net/pull/1075

## Performance and internals

* Optimize header handling with SearchValues https://github.com/nats-io/nats.net/pull/1203
* Simplify object store base64url encoder https://github.com/nats-io/nats.net/pull/1199

## Tests and docs

* Add abstractions package boundary test https://github.com/nats-io/nats.net/pull/1197
* Gate positive-path test connections with ConnectRetryAsync https://github.com/nats-io/nats.net/pull/1198
* Fix flaky CI tests https://github.com/nats-io/nats.net/pull/1179
* Remove stale net6.0 references https://github.com/nats-io/nats.net/pull/1196
* Clarify AddNats vs AddNatsClient https://github.com/nats-io/nats.net/pull/1210

## Thanks

Thanks to the community for the contributions and issue reports behind this release:

* @colprog for the header handling optimization (#1203), the custom span destination name formatter (#1201), and requesting the explicit drain API (#1176)
* @to11mtm for the object store base64url encoding work (#557, #565) behind the encoder simplification (#1199)
* @thompson-tomo for the abstractions and package consolidation proposals (#851, #866) behind moving the socket interfaces to NATS.Client.Abstractions (#1192)

## Upgrade notes

Details of the API and behavior changes, with the preview each first shipped in.

### Target frameworks (since preview.1)

`net6.0` is dropped and `net10.0` added; the full set is `netstandard2.0`, `netstandard2.1`, `net8.0`, `net10.0`. Apps targeting .NET 6 or 7 keep working through the `netstandard2.1` build, whose encoding hot paths were optimized in 3.0 (#1072), but .NET 8+ gets the fastest code paths.

### Request-reply defaults to Direct mode (since preview.9)

`NatsOpts.RequestReplyMode` now defaults to `NatsRequestReplyMode.Direct`: replies are correlated through the connection's existing inbox subscription instead of setting up a subscription and channel per request. Semantics are unchanged, including `ThrowIfNoResponders`. To restore the previous behavior:

```csharp
var opts = new NatsOpts { RequestReplyMode = NatsRequestReplyMode.SharedInbox };
```

### Subscription channel overflow defaults unified (since preview.9)

All entry points (`NatsConnection`, `NatsClient`, DI builders) now share the `NatsOpts` defaults: pending channel capacity 16384 (up from 1024) and `BoundedChannelFullMode.DropNewest`. Previously `NatsClient` and the DI builders forced `Wait`, which can stall the socket read loop and get the client disconnected as a slow consumer. If a subscriber now falls behind by more than 16K messages, the newest messages are dropped and surfaced through `MessageDropped` instead of blocking. To restore blocking, accepting the slow consumer risk:

```csharp
var opts = new NatsOpts { SubPendingChannelFullMode = BoundedChannelFullMode.Wait };
```

### SkipSubjectValidation is obsolete (since preview.9)

The option still works but produces a compiler warning. Validation costs 0-5% on a publish microbenchmark and prevents silently misrouted messages: a subject containing a space splits into subject and reply-to tokens on the wire with no error.

### Serializers can opt into message context (since preview.3)

New opt-in `INatsSerializeWithContext<T>`, `INatsDeserializeWithContext<T>`, and `INatsSerializerWithContext<T>` interfaces receive a `NatsMsgContext` (subject, reply-to, headers) during (de)serialization. Existing serializers work unchanged. One side effect: `NatsHeaders` no longer becomes read-only after publish, so a single `NatsHeaders` instance should not be shared across concurrent publishes.

### Socket interfaces moved to NATS.Client.Abstractions (since preview.11)

`INatsSocketConnection` and `INatsTlsUpgradeableSocketConnection` moved to the `NATS.Client.Abstractions` package so custom transports can implement them without referencing Core. The namespace is unchanged and the types are forwarded, so existing code is source and binary compatible.

### OpenTelemetry package (metrics since preview.8, package since preview.11)

The new `NATS.Client.OpenTelemetry` package adds `AddNatsClientInstrumentation()` extensions for both `TracerProviderBuilder` and `MeterProviderBuilder`, with options for subject filtering and custom span destination names.

```csharp
using NATS.Client.OpenTelemetry;

services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddNatsClientInstrumentation(opts => opts.FilterSubjects(exclude: ["_INBOX.>"])))
    .WithMetrics(metrics => metrics
        .AddNatsClientInstrumentation());
```

### Explicit drain (since preview.9)

`INatsSub<T>.DrainAsync()` drains a single subscription without disposing the connection: no new deliveries, in-flight messages fenced with a PING/PONG, channel completed.

```csharp
var sub = await nats.SubscribeCoreAsync<Order>("orders.>");
// ... read from sub.Msgs ...
await sub.DrainAsync(); // in-flight messages still delivered, connection stays open
```

For JetStream consume loops, the opt-in `DrainOnCancel` consume option delivers buffered messages after cancellation so handlers can still ack; the default keeps the previous stop-immediately behavior.

```csharp
var opts = new NatsJSConsumeOpts { DrainOnCancel = true };
await foreach (var msg in consumer.ConsumeAsync<Order>(opts: opts, cancellationToken: ct))
{
    await msg.AckAsync();
}
// on cancellation the loop drains: stops pulling, delivers buffered messages, then completes
```

### DI package dependencies (since preview.2)

`NATS.Extensions.Microsoft.DependencyInjection` now depends on `NATS.Client.Simplified` instead of the all-inclusive `NATS.Net`, and `NATS.Net` now includes the DI package. If you referenced only the DI package and used JetStream, Key-Value, Object Store, or Services through its transitive dependency, add a direct `NATS.Net` reference (or the specific packages you use).

**Full Changelog**: https://github.com/nats-io/nats.net/compare/v2.8.2...v3.0.0

---

### `v3.0.0-preview.11` — NATS .NET v3.0.0-preview.11 — published 2026-07-02

https://github.com/nats-io/nats.net/releases/tag/v3.0.0-preview.11

[![NuGet](https://img.shields.io/badge/NuGet-3.0.0--preview.11-blue)](https://www.nuget.org/packages/NATS.Net/3.0.0-preview.11)

Last planned preview on the 3.0 line centered on OpenTelemetry: a new `NATS.Client.OpenTelemetry` package, richer metrics, and lower-overhead tracing. Also moves the socket connection interfaces into `NATS.Client.Abstractions` and tightens the header-parsing hot path.

**OpenTelemetry:**
- Add OpenTelemetry package (#1172)
- Add custom span destination name formatter (#1201)
- Add ack/dropped metrics and collapse inbox trace tags (#1194)
- Exclude NATS status frames from consumed metrics (#1195)
- Make shared instrumentation options thread-visible (#1207)
- Match subject filters without per-message allocation (#1206)
- Fix null-key tag in receive fallback (#1205)

**Core & packaging:**
- Move socket connection interfaces to NATS.Client.Abstractions (#1192)
- Add abstractions package boundary test (#1197)
- Optimize header handling with SearchValues (#1203)
- Simplify object store base64url encoder (#1199)
- Gate positive-path test connections with ConnectRetryAsync (#1198)
- Remove stale net6.0 references (#1196)

Thanks to @colprog for the custom span destination name formatter (#1201) and the SearchValues header optimization (#1203).

Thanks to everyone testing the previews so far. This should be the last one;  please give it one more round of testing, and if no bugs turn up we'll cut the stable 3.0 release in about a week.

**Full Changelog**: https://github.com/nats-io/nats.net/compare/v3.0.0-preview.10...v3.0.0-preview.11

---

### `v3.0.0-preview.10` — NATS .NET v3.0.0-preview.10 — published 2026-06-17

https://github.com/nats-io/nats.net/releases/tag/v3.0.0-preview.10

[![NuGet](https://img.shields.io/badge/NuGet-3.0.0--preview.10-blue)](https://www.nuget.org/packages/NATS.Net/3.0.0-preview.10)

Bug-fix preview on the 3.0 line. Carries the ordered push consumer subscription teardown fixes from the 2.x line; no 3.0-only changes this round.

From the 2.x line:
- jetstream: simplify ordered push consumer sub teardown (#1191)
- jetstream: dispose ordered push consumer sub on teardown (#1188)

**Full Changelog**: https://github.com/nats-io/nats.net/compare/v3.0.0-preview.9...v3.0.0-preview.10

---

### `v2.8.2` — NATS .NET v2.8.2 — published 2026-06-17

https://github.com/nats-io/nats.net/releases/tag/v2.8.2

[![NuGet](https://img.shields.io/badge/NuGet-2.8.2-blue)](https://www.nuget.org/packages/NATS.Net/2.8.2)

Patch release on the 2.8 line. Fixes ordered push consumer subscription teardown. Thanks to @haoguanjun for the fix.

## What's Changed
* Bump MessagePack from 3.1.1 to 3.1.7  https://github.com/nats-io/nats.net/pull/1183
* Clarify DI package descriptions https://github.com/nats-io/nats.net/pull/1163
* Fix ordered push consumer subscription leak on teardown https://github.com/nats-io/nats.net/pull/1188
* Simplify ordered push consumer sub teardown https://github.com/nats-io/nats.net/pull/1191
* Release 2.8.2 https://github.com/nats-io/nats.net/pull/1189


**Full Changelog**: https://github.com/nats-io/nats.net/compare/v2.8.1...v2.8.2

---

### `v3.0.0-preview.9` — NATS .NET v3.0.0-preview.9 — published 2026-06-15

https://github.com/nats-io/nats.net/releases/tag/v3.0.0-preview.9

[![NuGet](https://img.shields.io/badge/NuGet-3.0.0--preview.9-blue)](https://www.nuget.org/packages/NATS.Net/3.0.0-preview.9)

Ninth preview of NATS .NET 3.0. Request-reply now defaults to Direct mode, and subscriptions and consumers can be drained explicitly.

Heads-up: the default request-reply mode is now `NatsRequestReplyMode.Direct` (previously `SharedInbox`). Direct uses the same inbox prefix but skips per-reply muxer processing, making `RequestAsync` more resource-efficient. At the default it still throws `NatsNoRespondersException` on a no-responders reply, so existing `RequestAsync` behavior is preserved. If you already set `RequestReplyMode` explicitly to either mode, nothing changes for you. To keep the old default mechanism, set `NatsOpts.RequestReplyMode = NatsRequestReplyMode.SharedInbox`.

3.0-only changes:
- Default request-reply to Direct mode (#1182)
- Add explicit subscription and consumer drain (#1177)
- Unify subscription channel overflow defaults (#1181)
- Deprecate SkipSubjectValidation (#1180)
- Fix OTel server.port tag type and source (#1175)

Also from the 2.x line:
- Bump MessagePack 3.1.1 -> 3.1.7 (#1183)

**Full Changelog**: https://github.com/nats-io/nats.net/compare/v3.0.0-preview.8...v3.0.0-preview.9

---

## Open issues at 2026-09-04 (53) — number, opened, title

- #1254 — 2026-09-01 — Allow removing endpoints from Services
- #1247 — 2026-08-26 — Allow keeping history of recently deleted keys in PurgeDeletesAsync
- #1244 — 2026-08-21 — Add a direct IBufferWriter<byte> publish overload
- #1238 — 2026-08-13 — KV reads are broken on buckets with AllowDirect = false
- #1219 — 2026-07-24 — Add JsonWriterOptions to NatsJsonSerializer<T> constructor
- #1173 — 2026-05-29 — Add NatsSubject type
- #1170 — 2026-05-28 — Move PushEvent out from under _gate lock
- #1169 — 2026-05-28 — Subscription EndReason can be lost or mis-attributed
- #1139 — 2026-05-13 — Tighten header parsing and protocol hot path with .NET 8+ APIs
- #1124 — 2026-05-06 — UnobservedTaskException from orphaned reconnect task and async void ReconnectLoop after DisposeAsync
- #1059 — 2026-02-03 — Proposal: JetStream GetAutoAsync() and NatsStreamMsg<T>
- #1049 — 2026-01-22 — Enable throttling object store reads
- #1046 — 2026-01-21 — GetKeysAsync with filters hangs indefinitely when no keys match the filter  pattern
- #1044 — 2026-01-15 — Proposal: NatsClient Defaults and Options
- #1042 — 2026-01-13 — There is no option to limit internal queues by size
- #1027 — 2025-12-22 — Make INats(Js)Msg<T> implement INatsJsMsg
- #993 — 2025-10-29 — Add Opt-In Concurrency to Service Endpoints
- #952 — 2025-09-14 — Excessive NatsJSTimeoutNotification from NatsJSConsume due to periodic heartbeat timer
- #941 — 2025-08-28 — Object store rents 128k ends up in LOH
- #904 — 2025-07-17 — NatsNoReplyException when acknowledging a message with DoubleAck = true
- #813 — 2025-04-08 — JS IAsyncEnumerable ConsumeAsync - high network traffic
- #791 — 2025-03-24 — Ephemeral JetStream consumer disconnected without any exception in IAsyncEnumerable
- #786 — 2025-03-22 — `SubjectDeleteMarkerTTL`-enabled removals should be interpreted as `Operation = Purge`
- #736 — 2025-02-04 — Removing DuplicateWindow rules in NatsKVContext.CreateStoreAsync makes recreation of bucket fail
- #727 — 2025-01-25 — TlsOptsTest hangs
- #691 — 2024-12-06 — Perf/NatsKVStore: Investigate Splitting Large Method GetEntryAsync 
- #686 — 2024-12-02 — Implement Push Consumers
- #642 — 2024-10-01 — KV Bucket Mirror and Domain Support
- #634 — 2024-09-19 — Tests/usage of mirroring and stream sourcing
- #628 — 2024-09-11 — Fetch on already deleted consumer does not throw an exception
- #621 — 2024-08-29 — INatsKVStore.GetKeysAsync cause connection leak
- #611 — 2024-08-23 — AOT-friendly documentation
- #575 — 2024-07-22 — Add additional key checks for KV
- #568 — 2024-07-17 — Proposal: Real-World Examples and Setup for Long-Lived Services
- #558 — 2024-07-09 — Improve Test fixtures
- #557 — 2024-07-09 — Optimize Objectstore Base64URL encoding bits
- #546 — 2024-07-06 — Check multiple KV filters against consumer info
- #539 — 2024-07-03 — Inconsistency in the use of classes and interfaces
- #519 — 2024-06-18 — Improve netstandard SHA performance
- #477 — 2024-04-16 — Support consumer pause
- #457 — 2024-03-28 — Implement tests for OCSP
- #435 — 2024-03-07 — Make JSON response objects read-only
- #419 — 2024-02-28 — JetStream FilterSubjects is null
- #391 — 2024-02-10 — Ordered consumer performance
- #352 — 2024-01-24 — Models nullability review 2
- #348 — 2024-01-23 — Event handler improvements
- #345 — 2024-01-22 — Improve documentation
- #322 — 2024-01-10 — Consider using BoundedChannel instead of SemaphoreSlim
- #320 — 2024-01-10 — Consider wrapping throw in call to encourage JITter
- #318 — 2024-01-10 — Potential issue with codegen for struct types
- #282 — 2023-12-11 — Investigate Improvements to NatsMsg<T> struct size
- #36 — 2022-06-15 — Latency Benchmark
- #22 — 2022-06-15 — Full Reconnect Behavior
