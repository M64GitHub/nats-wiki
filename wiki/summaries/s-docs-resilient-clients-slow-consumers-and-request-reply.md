---
title: "docs — Resilient Clients: Slow Consumers, and Request-Reply Resilience"
type: summary
area: [clients, core]
source-url: https://docs.nats.io/learn/resilient-clients/slow-consumers.md
source-path: raw/nats-docs/learn/resilient-clients/slow-consumers.md
author: NATS documentation
article: "learn/resilient-clients/slow-consumers.md and learn/resilient-clients/request-reply-resilience.md (with the matching where-next.md checklists), fetched 2026-08-31"
date: 2026-08-31
version: "unversioned by design"
tags: [slow-consumer, pending-limits, SetPendingLimits, async-error-callback, request-reply, no-responders, retry, idempotency, CustomInboxPrefix]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# docs — Resilient Clients: Slow Consumers, and Request-Reply Resilience

Pages 5 and 6 of the eight-page `learn/resilient-clients` chapter, read together because they are
the two faults that happen while the connection is *healthy*: the application cannot keep up, and a
request gets no answer. The chapter states no nats-server, client or ADR version anywhere and says
so on purpose — "This chapter is unversioned and concept-first" (`where-next.md:20`) — so every
version-bearing claim on the wiki pages this feeds comes from
[[s-nats-go-subscription]], [[s-nats-server-client-errors]] and
[[s-nats-server-client-faults-observed]], not from here.

## Key claims

### The subscription pending buffer, and the two things called a slow consumer

- An async subscription queues arriving messages **per subscription** and lets the handler drain
  them; that queue is the *pending buffer* (`slow-consumers.md:12`).
- "By default the pending buffer has generous built-in limits: 500,000 messages and 64 MB in the Go
  client, and similarly large caps in Python and Java" (`:16`). The per-client divergence is stated
  at `:18`: **Rust** 65,536 messages; **JavaScript** unbounded and never drops client-side, its
  slow-consumer option only raising a status; **C#** a 1,024-message channel, where the low-level
  `NatsConnection` "drops the newest queued message and raises a `MessageDropped` event" while the
  `NatsClient` wrapper "waits instead, which blocks the read loop rather than dropping".
- Where the limits are set varies: "Go and Java set them on the subscription after subscribing,
  Python and C# pass them as subscribe options, and Rust sets a single `subscription_capacity` on
  the connection options that applies to every subscription. Rust and C# cap message count only,
  not bytes" (`:24`).
- The CLI cannot set them: "The CLI can't set this knob; it's a client-library call" (`:26`).
- Sizing rule: "A limit sized to roughly the handler's latency times the subject's peak rate" (`:88`).
- On overflow, "Most clients drop that message and fire the **async error callback** with a
  slow-consumer error rather than blocking the read loop" (`:94`); the subscription "stays active;
  it is not closed" (`:96`).
- The Go observables named: status becomes `SubscriptionSlowConsumer`, `Pending()` against
  `PendingLimits()`, `Dropped()` for the running count (`:98`).
- **The claim this wiki contradicts**: "In Go a connection with no async error callback discards
  these reports, and dropped messages become invisible" (`:100`), repeated as `where-next.md:99`.
  nats.go installs `defaultErrHandler` and writes to stderr — docs issue #92,
  [[s-nats-go-subscription]].
- **The second claim this wiki contradicts**: the animation caption says "the server raises a
  SlowConsumer error back to that subscriber" (`:102`). The local slow consumer is entirely
  client-side; the server is not involved and its `slow_consumers` counter does not move
  ([[s-nats-server-client-faults-observed]] A1–A4). Docs issue #96.
- The *two* slow consumers are separated correctly at `:110–116`: a **local** one drops messages and
  keeps the connection; a **server-side** one loses the whole connection when the client "reads off
  its socket so slowly that the server can't finish writing to it within the server's per-client
  write deadline". "From the client's perspective this doesn't look like a dropped message and an
  async error. It looks like a disconnect with a read error" (`:114`).
- The real fix for a subject one subscriber cannot keep up with "is usually not a bigger buffer but
  more subscribers sharing the load" — a queue group (`:118`); see [[queue-groups]].

### A request has three outcomes, and two of them are failures

- Timeout, reply, or **no responders** — "the server sends back an immediate no-responders signal (a
  503 status with no body) and the request call returns at once instead of waiting out the timeout"
  (`request-reply-resilience.md:18`). See [[request-reply]] for the wire form, which carries a
  `Nats-Subject` header the docs never mention (docs issue #85).
- The inbox prefix is a client option — "nats.js calls the option `inboxPrefix`; Go calls it
  `CustomInboxPrefix`" — and it exists for restricted permissions: "a client whose subscribe
  permissions don't cover the default `_INBOX.>` can't receive replies" (`:6`). See
  [[subject-permissions]].
- Java needs `Options.Builder.reportNoResponders()` and the `CompletableFuture`-based request to
  tell the two failures apart (`:51–55`, `:183–187`).
- Retry policy **per outcome**: "Use a short, bounded retry for a timeout and an exponential backoff
  for no responders" (`:246`), bounded — "Cap the attempts (five is a reasonable default) and add
  jitter" (`:248`).
- Timeout sizing: "set the timeout to two or three times its p99" (`:262`).
- Idempotency: "A retried request is a *duplicate* request… key every inventory check by its
  `order_id`… the `inventory` responder remembers recently seen IDs" (`:250–252`).
- **A request in flight when the connection drops is lost outright**: "NATS doesn't persist it. The
  inbox re-subscribes automatically on reconnect… so a retry after the link returns works normally"
  (`:254`).
- The page's own CLI example concedes what docs issue #89 records: "The CLI exits 0 even when no
  reply arrives… so test for a reply body instead of the exit code" (`:305–313`).
- Dating: "The no-responders signal needs a server new enough to send the 503 and a client that
  advertised support for it during the connect handshake. Both have been the default for years"
  (`:154`) — no version. It arrived in **2.2.0** ([[s-relnotes-2.2.0]]); docs issue #97.

## Practical takeaways

- Bound the pending buffer on any subscription that does per-message work, and size it to handler
  latency × peak rate rather than to the default.
- Watch the async-error rate and the disconnect rate **separately**: they point at different fixes.
- Branch retries on the failure kind; a no-responders retry that does not back off floods a subject
  nobody is listening on.
- Key every retryable request by an id the responder de-dupes on.

## Notable quotes

> "A *local* slow consumer drops individual messages and keeps the connection; you tune it with
> pending limits and the async error callback. A *server-side* slow consumer loses the entire
> connection; you fix it by reading faster or by spreading the load." (`slow-consumers.md:116`)

> "a quiet drop is worse than a crash because you don't even know it happened."
> (`slow-consumers.md:126`)

## Relevance to the wiki

The source of the per-client pending-limit table on [[client-defaults]], of
[[slow-consumer-in-the-client]]'s shape, and of the retry-per-outcome material on
[[request-reply]] and [[nats-timeout]].

## Questions it answers

180, 181; supports 172–174.

## Pages touched

[[slow-consumer-in-the-client]], [[client-defaults]], [[slow-consumer-detected]],
[[request-reply]], [[nats-timeout]], [[queue-groups]], [[subject-permissions]],
[[client-connection-lifecycle]], [[worker-pool]]
