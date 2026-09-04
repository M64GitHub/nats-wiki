---
title: "The twelve clients — release notes and open issues"
type: summary
area: [clients, core, jetstream]
source-url: https://github.com/nats-io/
source-path: raw/github-repos/nats-io__<repo>.releases-2026-09-04.md
author: the twelve official client repositories (release notes written by their maintainers)
article: the last ~10 release bodies and every open issue of the 12 official clients
date: 2026-09-04
version: "2.14"
tags: [clients, releases, open-issues, drain, reconnect, slow-consumer, subject-validation]
aliases: []
sources: [s-github-repo-facts, s-docs-resilient-clients-connecting, s-docs-resilient-clients-drain-and-shutdown, s-docs-resilient-clients-slow-consumers-and-request-reply, s-docs-core-nats-subjects-and-mapping, s-nats-server-core-delivery-observed]
created: 2026-09-04
updated: 2026-09-04
---

# The twelve clients — release notes and open issues

The `learn/resilient-clients` chapter states what each client does and **carries no version**
(source: [[s-docs-resilient-clients-connecting]]). A client's own release notes are the only public
record that dates those statements — and, in three places below, contradicts them. This is that
reading: the last ten release bodies of each of the twelve official clients (fewer where the repo has
fewer) and every open issue, fetched 2026-09-04 through the GitHub REST API and stored verbatim under
`raw/github-repos/nats-io__<repo>.releases-2026-09-04.md`.

Everything here is a **dated snapshot** of a moving record. What does not move is the shape: the
chapter describes a client at one moment and never says which.

## Key claims

### Subject validation arrived late, and separately, in every client

The docs say a subject with a space is not rejected by `nats.py`'s `publish` or by the C client, so
`orders.us created` reaches the server as subject `orders.us` with reply subject `created`
(source: [[s-docs-core-nats-subjects-and-mapping]]; the server's half is run A2 of
[[s-nats-server-core-delivery-observed]]). The release record shows this was true of **every** client
until recently, and is still true of two:

| client | validation arrived | the line |
|---|---|---|
| nats.go | **v1.48.0**, 2025-12-17 | "Add publish subject validation and a connection option to skip it (#1974, #1979)" |
| nats.java | **2.25.1**, 2026-01-15 | "Subject validation #1501" |
| nats.js | **v3.3.0**, 2025-12-16 | "Subject validation: Validate subjects for illegal whitespace characters (#348)" |
| nats.rs | **v0.47.0**, 2026-03-31 | "This release adds subject validation (with opt-out possibility)…" |
| nats.net | had it; the **opt-out** was deprecated in **v3.0.0**, 2026-07-10 | "SkipSubjectValidation is obsolete… Validation costs 0-5% on a publish microbenchmark and prevents silently misrouted messages: a subject containing a space splits into subject and reply-to tokens on the wire with no error" |
| nats.c, nats.py | **not in the last ten releases of either** | — |

The .NET note is the clearest independent statement of the mechanism the wiki reproduced on the
server: *subject and reply-to tokens on the wire, no error*.

### nats.net v3.0.0 changed two of the C# numbers the documentation states

The documentation was fetched 2026-08-31; nats.net **v3.0.0** shipped **2026-07-10**, seven weeks
earlier, and changed both:

- "All entry points (`NatsConnection`, `NatsClient`, DI builders) now share the `NatsOpts` defaults:
  pending channel capacity **16384** (up from 1024) and `BoundedChannelFullMode.DropNewest`.
  Previously `NatsClient` and the DI builders forced `Wait`, which can stall the socket read loop and
  get the client disconnected as a slow consumer. If a subscriber now falls behind by more than 16K
  messages, the newest messages are dropped and surfaced through `MessageDropped` instead of
  blocking." — against `slow-consumers.md:18`, "C# defaults to a 1,024-message channel… while the
  `NatsClient` wrapper waits instead".
- "`INatsSub<T>.DrainAsync()` drains a single subscription without disposing the connection: no new
  deliveries, in-flight messages fenced with a PING/PONG, channel completed." — against
  `drain-and-shutdown.md:215`, "C# is the exception: it has no drain call on a single subscription."

Recorded as `inbox/docs-issues.md` #121.

### nats.swift's README contradicts its own release notes

The README says "JetStream, KV, Object Store, Service API are on the roadmap"
(`raw/github-repos/nats-io__nats.swift.README.md:22`, fetched 2026-08-31). The **v0.4.0** release
notes of 2024-10-31 say "This release introduces JetStream support, including: JetStream management
API support (Streams and Consumers); Publishing messages to streams and getting/deleting individual
messages; Pull consumer support with `fetch()`". `Sources/JetStream/` exists at that tag and on the
default branch, holding `JetStreamContext.swift`, `Stream.swift`, `Consumer.swift` and
`Consumer+Pull.swift`. The release notes and the tree agree; the README is nearly two years stale.
Recorded as `inbox/docs-issues.md` #122.

### The Python maintainers publish a message-loss figure for their own client

The `nats-core/v0.1.0` notes of 2025-12-19 benchmark the new package against `nats-py` (Apple M3 Max,
1M messages, publisher and subscriber in one process) and footnote the `nats-py` column:

> \* nats-py dropped 47-87% of messages under load
>
> Zero message loss with nats-core across all configurations.

The measured subscriber throughput in the same table is 8,769 msg/s at 8 B for `nats-py` against
553,636 for `nats-core` on CPython. `nats-core` requires **Python 3.13+**.

### What each client's last ten releases changed, that an operator sees

- **nats.c v3.13.0** (2026-06-01): `natsOptions_SetIgnoreAuthErrorAbort` — "Clients can now be
  configured to opt out of aborting subsequent reconnect attempts if server returns the same auth
  error twice". Before it there was no opt-out. Also: "TLS is now automatically enabled when a URL
  with the `tls://` scheme is used" (#951) — it was not before; and `natsConnection_Close` "could
  fail to properly flush if data was just written to the socket and the buffer is empty" (#982).
  **v3.11.0**: "Connection drain could cause missed reply and/or a 100ms delay" (#915).
- **nats.ex v1.14.0** (2026-04-23): `KV.Watcher`'s push consumer "now enables server-driven flow
  control and a 5s idle heartbeat (matching nats.go's ordered-consumer defaults), so slow handlers
  apply backpressure instead of being dropped as slow consumers" — so before v1.14.0 they were.
  Same release, "**Behavior change (bugfix):** `PullConsumer` no longer forwards JetStream
  informational status messages (e.g. `100` idle heartbeat, `409` leadership change) to
  `c:handle_message/2`. These are not stream records and cannot be acked." **v1.16.0** (2026-07-10)
  "Add client name to NATS CONNECT settings (#227)" — before it, an Elixir connection has no name in
  `/connz`.
- **nats.java 2.26.1** (2026-08-04): "Count connect failure once per server, not once per resolved IP
  (#1595)" — a DNS name with several A records used to spend the reconnect budget once per address.
  **2.26.0** (2026-07-09) "Reconnect Delay Behavior and options cleanup #1578"; **2.25.2**
  (2026-03-03) "fix race condition in reconnect #1523" and "'Payload Size' includes header bytes, not
  just data #1525"; **2.25.1** "[bug] Properly count message/bytes when in discardWhenFull mode
  #1498".
- **nats.js v3.4.0** (2026-05-08): "inboxes match go client `_INBOX.<nuid>.<token>` (was
  `_INBOX.<nuid>.<nuid>`); nuids now base62 (#398)"; `getServers()`/`setServers()` (#400);
  `reconnectToServer` (#403). **v3.3.1** (2026-02-11) fixes object-store digest validation — "This is
  an important integrity fix".
- **nats-pure.rb v2.5.0** (2025-02-21), the last release: `Client#force_reconnect` (#159), the
  Service API (#160), KV watchers (#161).
- **nats.py v2.15.0** (2026-06-05): "Lame duck mode handling for graceful reconnection (#869)";
  v2.14.0 "Fix flush hanging when internal tasks are cancelled externally (#853)".
- **nats.rs v0.49.0** (2026-05-25): "adds missing client-side max-payload validations for some
  methods" — before it those paths sent an oversize message to the server. **v0.49.1** (2026-06-04)
  "Fix ping interval reset (#1594)" and "Fix recreating ordered consumer on server restart (#1599)";
  **v0.48.0** "Preserve unsubscribe_after limit across reconnects (#1560)"; **v0.50.0** repeats the
  Cargo warning: "Enabling `chrono` anywhere in the dependency graph selects the chrono backend for
  the whole build (Cargo feature unification)".
- **nats.swift v0.3.0** (2024-04-17): "suspend & resume (useful for gracefully pausing consumer when
  IOS device goes to sleep & wakes up)" and force reconnect.
- **nats.zig v0.1.0** (2026-04-28), the only release: "Object Store support is not included in this
  initial release. As this is a 0.x release, the public API may still evolve before 1.0."
- **nats.go v1.51.0** (2026-04-14): "Option to automatically reconnect on write error (#2055)" — so
  it does not by default — and "Option to customize write buffer size (#2057)". **v1.53.0**
  (2026-08-11) "Reject keys with consecutive dots in `keyValid` and `searchKeyValid` (#2076)";
  **v1.50.0** "Reject control characters in stream and consumer names (#2038)".
- **nats.net v3.0.0** (2026-07-10) beyond the two above: request/reply defaults to
  `NatsRequestReplyMode.Direct`; "`NatsHeaders` no longer becomes read-only after publish, so a single
  `NatsHeaders` instance should not be shared across concurrent publishes"; the DI package now depends
  on `NATS.Client.Simplified` rather than `NATS.Net`, so a DI-only reference that reached JetStream,
  KV, Object Store or Services transitively breaks on upgrade; `net6.0` dropped.

### The open issues that describe an operator-visible behaviour

Titles and numbers verbatim, with the date each was opened. None is a verdict — an open issue is a
report, not a finding — but each names a behaviour someone met in production.

| client | issue |
|---|---|
| nats.c | #1005 (2026-08-05) "libuv adapter: crash after silent-failure disconnect"; #1007 (2026-08-05) "libuv adapter: parser not destroyed on disconnect"; #735 (2024-03-20) "callbacks on natsConnection are called after natsConnection_destroy" |
| nats.ex | #160 (2024-05-28) "Connection credential is printed out in error log" |
| nats.java | #1616 (2026-08-18) "drain() future completes true even when the drain timed out" |
| nats.js | #426 (2026-08-10) "kv: history() reports a truncated read as a complete one when the link drops"; #423 (2026-06-12) "status() returns a \"reconnect\" type status for each retry" |
| nats-pure.rb | #169 (2025-05-28) "When client @pending_queue is full, the library blocks the process"; #79 (2022-08-22) "Long running jobs get killed when draining"; #88 (2022-10-06) "Implement Default Flush Timeout of 10s" |
| nats.py | #986 (2026-07-06) "fetch() still stalls on an orphan lingering request in 2.15.0 (regression / incomplete fix for #933)"; #962 (2026-05-29) "Pull consumer message streams leak disconnect/reconnect callbacks (never deregistered on stop())"; #461 (2023-06-19) "OutboundBufferLimitError exception on connection after `drain_timeout` passed" |
| nats.rs | #1607 (2026-07-01) "async-nats: Subscriber::drop panics when dropped outside a Tokio runtime"; #1276 (2024-06-07) "Support custom capacity per subscription"; #1261 (2024-05-13) "Hard to debug slow consumers with Rust client" |
| nats.swift | #122 (2026-07-01) "NatsClient abandoned mid-reconnect is never released (reconnect task and subscriptions retain the connection handler forever)" |
| nats.go | #1163 (2022-12-16) "Unbound memory footprint growth with slow consumers"; #1612 (2024-04-16) "JetStream: the value for max pending async messages can be exceeded"; #1562 (2024-02-21) "Panic on Calling Drain on a nil NATS Connection"; #580 (2020-06-24) "Hardcoded FlushTimeout values" |
| nats.net | #1124 (2026-05-06) "UnobservedTaskException from orphaned reconnect task and async void ReconnectLoop after DisposeAsync" |

nats.zig has two open issues, neither about the connection; nats.rb has three, none about drain,
reconnect or slow consumers.

### Release cadence, which is itself an operator fact

`nats.swift` v0.4.0 is **2024-10-31** and `nats-pure.rb` v2.5.0 is **2025-02-21** — the two
non-legacy clients whose newest release predates nats-server 2.11. `nats.zig` has exactly one
release. `nats.rb` has had none since **2019-06-11**.

## Practical takeaways

- **Do not assume the chapter's per-client table is current.** It is unversioned, and .NET moved two
  of its cells seven weeks before the docs were fetched.
- **A subject with a space is a client-version question, not a client question.** Ask which release,
  not which language.
- **Two clients still do not check the subject** in anything the last ten releases mention: the C
  client and `nats.py`.
- **Read the release notes before an upgrade of the client, not only of the server.** The
  behaviour changes above — .NET's channel default, Elixir's status-message routing, Java's
  per-IP failure counting — all change what a running service does under load.

## Notable quotes

> "Validation costs 0-5% on a publish microbenchmark and prevents silently misrouted messages: a
> subject containing a space splits into subject and reply-to tokens on the wire with no error."
> — nats.net v3.0.0 release notes

> "\* nats-py dropped 47-87% of messages under load" — nats.py, `nats-core/v0.1.0` release notes

> "Clients can now be configured to opt out of aborting subsequent reconnect attempts if server
> returns the same auth error twice" — nats.c v3.13.0 release notes

## Relevance to the wiki

It dates every unversioned per-client claim the resilient-clients chapter makes, and it is the
evidence behind the `## What bites you` section on all twelve client entity pages.

## Questions it answers

87 (partly — the Orbit module per language), 148 (no: nothing in the record mentions `TCP_NODELAY`),
156 (no).

## Pages touched

[[nats-c]] · [[nats-ex]] · [[nats-java]] · [[nats-js]] · [[nats-pure-rb]] · [[nats-py]] · [[nats-rb]] ·
[[nats-rs]] · [[nats-swift]] · [[nats-zig]] · [[nats-go]] · [[nats-net]] · [[client-defaults]] ·
[[subjects-and-wildcards]]

## Sources

[[s-github-repo-facts]] · [[s-docs-resilient-clients-connecting]] ·
[[s-docs-resilient-clients-drain-and-shutdown]] ·
[[s-docs-resilient-clients-slow-consumers-and-request-reply]] ·
[[s-docs-core-nats-subjects-and-mapping]] · [[s-nats-server-core-delivery-observed]]
