---
title: nats.net
type: entity
kind: client
area: [clients, jetstream, monitoring]
verified-against: NATS .NET v3.2.0
verified-on: 2026-08-31
tags: [client, tier-1, dotnet, csharp, opentelemetry, net10, net6-dropped]
aliases: [nats.net, "nats-io/nats.net", ".net client", "c# client", NATS.Net]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-getting-started, s-so-78603662-acked-but-redelivered, s-nats-server-redelivery-observed, s-issue-6921-last-per-subject-acks, s-docs-core-nats-request-reply, s-adr-47-request-many]
created: 2026-08-31
updated: 2026-09-03
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


## Related

[[orbit]] · [[nats-go]] · [[monitoring-endpoints]] · [[nats-server]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-getting-started]] · [[s-so-78603662-acked-but-redelivered]] · [[s-nats-server-redelivery-observed]] · [[s-issue-6921-last-per-subject-acks]] · [[s-docs-core-nats-request-reply]] · [[s-adr-47-request-many]]
