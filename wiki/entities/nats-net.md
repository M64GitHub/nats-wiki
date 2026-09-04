---
title: nats.net
type: entity
kind: client
area: [clients, jetstream, monitoring]
verified-against: NATS .NET v3.2.0 (behaviour changes read at v3.0.0)
verified-on: 2026-09-04
tags: [client, tier-1, dotnet, csharp, opentelemetry, net10, net6-dropped]
aliases: [nats.net, "nats-io/nats.net", ".net client", "c# client", NATS.Net]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-getting-started, s-so-78603662-acked-but-redelivered, s-nats-server-redelivery-observed, s-issue-6921-last-per-subject-acks, s-docs-core-nats-request-reply, s-adr-47-request-many, s-client-releases-and-issues, s-nats-server-core-delivery-observed]
created: 2026-08-31
updated: 2026-09-04
---

# nats.net

The **.NET client** — pub/sub and request-reply, JetStream, KV, Object Store and Services, published
to NuGet as `NATS.Net` (source: [[s-github-repo-facts]]).

## Where it fits

Tier 1, and as of v3 the client with **first-class OpenTelemetry** — the only official client whose
release notes advertise tracing *and* metrics out of the box.

## Facts

| | |
|---|---|
| repo | `nats-io/nats.net` |
| tier | **1** |
| latest release | **v3.2.0**, 2026-08-29 (v3.0.0 was 2026-07-10) |
| licence | Apache-2.0 |
| package | **`NATS.Net`** on NuGet |
| target frameworks (v3) | `netstandard2.0`, `netstandard2.1`, `net8.0`, `net10.0` |
| **dropped in v3** | **`net6.0`** |

```
dotnet add package NATS.Net
```

## What an operator needs to know

- **.NET 6 is no longer a supported target.** The v3.0.0 release notes say it plainly: "3.0 targets
  `netstandard2.0`, `netstandard2.1`, `net8.0`, and `net10.0`. `net6.0` has been dropped." The docs'
  ecosystem page still describes the client as ".NET 6+" — see `inbox/docs-issues.md` #8. A service
  pinned to .NET 6 must stay on the v2 line or move its runtime first.
- **v3 adds OpenTelemetry tracing and metrics**, including ack and dropped-message metrics and a
  custom span destination-name formatter. For a shop already running OTel collectors, this is the
  cheapest per-message observability of any official client — and it is a v3-only capability.
- **`netstandard2.0` is still a target**, so .NET Framework consumers are not cut off by the v3 jump
  the way `net6.0` apps are.

## What bites you

Two public reports, both from .NET, both looking like the client until they were not:

- **A `Backoff` typed as numbers is in nanoseconds on the wire.** A `ConsumerConfig` with
  `MaxDeliver = 2` and `Backoff = new List<long> { 10000 }` produced messages "processed twice despite
  calling `msg.AckAsync()`", more times with a higher `MaxDeliver`, and the one Stack Overflow answer
  (add a durable name) never touched the cause: the server stores the first backoff entry as
  `ack_wait`, and `10000` is ten microseconds — `Ack Wait: 10µs` in `nats consumer info`. Reproduced
  on 2.14.6 with the same numbers: exactly twice with 5 ms of work before the ack (source:
  [[s-so-78603662-acked-but-redelivered]], [[s-nats-server-redelivery-observed]]). Whether the
  client's model passed the number through unchanged at the poster's version is inferred from the
  match, not read from the client's source.
- **Issue #6921 was filed first as nats.net #860** — a `last_per_subject` consumer with explicit acks
  whose floor froze on a stream with `max_msgs_per_subject: 5`. It reproduced in Rust, and in Go once
  the Go code set the same `MaxAckPending`; it was a server defect in 2.11.0–2.11.4, fixed in 2.11.5
  (source: [[s-issue-6921-last-per-subject-acks]]).

The symptom page is [[consumer-keeps-redelivering]].


## `RequestManyAsync`, and no responders by default

`RequestAsync` "throws `NatsNoRespondersException` immediately when nothing is subscribed on the
subject" — no opt-in, unlike Java — and the client ships ADR-47's gather helper as `RequestManyAsync`
(source: [[s-docs-core-nats-request-reply]], [[s-adr-47-request-many]]). The stop conditions and what
each costs are on [[request-reply]].



## What bites you — what v3.0.0 changed under you

The two reports above are about the server. These are about the client, read from the last ten
release bodies (v2.8.2 → v3.2.0, 2026-08-29) and the open issues at 2026-09-04 (source:
[[s-client-releases-and-issues]]). **v3.0.0 (2026-07-10) moved two of the .NET numbers the
documentation still states**, so the docs and the client disagree for anyone on v3 — recorded as
`inbox/docs-issues.md` #121, and reflected on [[client-defaults]].

- **The subscription channel is 16,384 and drops the newest, everywhere.** v3.0.0: "All entry points
  (`NatsConnection`, `NatsClient`, DI builders) now share the `NatsOpts` defaults: pending channel
  capacity 16384 (up from 1024) and `BoundedChannelFullMode.DropNewest`. Previously `NatsClient` and
  the DI builders forced `Wait`, which can stall the socket read loop and get the client disconnected
  as a slow consumer." So on v2, a `NatsClient` or DI-built connection with a slow handler got
  **disconnected by the server** as a slow consumer; on v3 it silently **drops messages** and raises
  `MessageDropped` instead. Both are data loss; only one shows up in the server's `slow_consumers`
  counter ([[slow-consumer-detected]], [[slow-consumer-in-the-client]]).
- **There is now a per-subscription drain**, against the documentation's "C# is the exception: it has
  no drain call on a single subscription". v3.0.0: "`INatsSub<T>.DrainAsync()` drains a single
  subscription without disposing the connection: no new deliveries, in-flight messages fenced with a
  PING/PONG, channel completed." For JetStream loops the opt-in `DrainOnCancel` consume option
  "delivers buffered messages after cancellation so handlers can still ack" — off by default, so a
  cancelled consume still stops immediately unless you set it ([[ack-and-redelivery]]).
- **`SkipSubjectValidation` is obsolete**, and the release notes state the mechanism better than the
  docs do: "a subject containing a space splits into subject and reply-to tokens on the wire with no
  error". That is exactly what this wiki reproduced on 2.14.6 (source:
  [[s-nats-server-core-delivery-observed]], run A2) — [[subjects-and-wildcards]].
- **Request/reply defaults to `Direct` mode** since v3.0.0: replies are correlated through the
  connection's existing inbox subscription rather than a subscription and channel per request.
  "Semantics are unchanged, including `ThrowIfNoResponders`" — but the inbox subject shape a
  permission matches on changes with it ([[subject-permissions]], [[request-reply]]).
- **A shared `NatsHeaders` instance is no longer safe across concurrent publishes.** v3.0.0:
  "`NatsHeaders` no longer becomes read-only after publish, so a single `NatsHeaders` instance should
  not be shared across concurrent publishes." Code that relied on the old read-only-after-publish
  behaviour to reuse one instance now races.
- **A DI-only package reference loses JetStream on upgrade.** "`NATS.Extensions.Microsoft.DependencyInjection`
  now depends on `NATS.Client.Simplified` instead of the all-inclusive `NATS.Net`" — an app that
  reached JetStream, KV, Object Store or Services through the transitive dependency has to add the
  reference explicitly.
- **`net6.0` is gone** (above), and a disposed connection can leave a reconnect task behind: open
  issue **#1124** (2026-05-06), "UnobservedTaskException from orphaned reconnect task and async void
  ReconnectLoop after DisposeAsync".

## Related

[[orbit]] · [[nats-go]] · [[monitoring-endpoints]] · [[nats-server]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-getting-started]] · [[s-so-78603662-acked-but-redelivered]] · [[s-nats-server-redelivery-observed]] · [[s-issue-6921-last-per-subject-acks]] · [[s-docs-core-nats-request-reply]] · [[s-adr-47-request-many]] · [[s-client-releases-and-issues]] · [[s-nats-server-core-delivery-observed]]
