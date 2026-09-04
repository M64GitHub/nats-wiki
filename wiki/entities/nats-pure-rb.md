---
title: nats-pure.rb
type: entity
kind: client
area: [clients, jetstream]
verified-against: nats-pure v2.5.0
verified-on: 2026-09-04
tags: [client, tier-2, ruby, pure-ruby, thread-safe]
aliases: [nats-pure.rb, "nats-io/nats-pure.rb", nats-pure, ruby client]
sources: [s-docs-ecosystem, s-github-repo-facts, s-nats-pure-rb-client-source, s-client-releases-and-issues]
created: 2026-08-31
updated: 2026-09-04
---

# nats-pure.rb

The **preferred Ruby client** — "Pure Ruby — preferred Ruby client" (source: [[s-docs-ecosystem]]),
thread-safe and with no EventMachine dependency, unlike the legacy [[nats-rb]].

## Where it fits

Tier 2. It is the Ruby client both the docs and the legacy client's own README point new work at.

## Facts

| | |
|---|---|
| repo | `nats-io/nats-pure.rb` |
| tier | **2** |
| latest release | **v2.5.0**, 2025-02-21 |
| licence | Apache-2.0 |
| gem | **`nats-pure`** |
| implementation | "A thread safe Ruby client … written in pure Ruby" |

```
gem install nats-pure
```

```ruby
require 'nats/client'
nats = NATS.connect("demo.nats.io")
```

## What an operator needs to know

- **`require 'nats/client'` is the same require path as the legacy gem.** Both gems answer to it, so
  a Gemfile that still lists `nats` alongside `nats-pure` is ambiguous — pick one.
- **Thread-safe, no reactor.** The legacy client's EventMachine reactor dictated the shape of the
  host application; this one does not.
- **Tier 2 means check before assuming a new server feature is exposed** — the docs say so directly,
  and the release cadence here is slower than tier 1.


## What bites you

The Ruby client is named in **none** of the eight `learn/resilient-clients` pages and its release
bodies state no default, so this section is read from its own source at tag **v2.5.0** (source:
[[s-nats-pure-rb-client-source]]) and from its open issues at 2026-09-04 (source:
[[s-client-releases-and-issues]]). Line numbers are `lib/nats/io/client.rb` at that tag; the whole
per-client picture is on [[client-defaults]].

- **The reconnect budget is 10, not 60.** `MAX_RECONNECT_ATTEMPTS = 10` (`:1869`) with
  `RECONNECT_TIME_WAIT = 2` and no jitter — about twenty seconds per server before it is dropped from
  the pool, against Go's, Java's and Python's sixty. Set `max_reconnect_attempts: -1` on anything
  long-lived; the code reads `< 0` as unlimited (`:1714`).
- **A publish blocks in an outage instead of failing.** The outbound queue is a
  `SizedQueue.new(MAX_PENDING_SIZE)` — 32,768 entries (`:458`, `:1873`) — and a Ruby `SizedQueue`
  blocks the pushing thread when full. Go, Java and Python return an error there
  (`ErrReconnectBufExceeded` in Go); Ruby stalls the caller. Reported, as a bug, in open issue **#169**
  (2025-05-28, "When client @pending_queue is full, the library blocks the process").
- **Inbound overflow drops, at 65,536 messages or 64 MB**, with
  `NATS::IO::SlowConsumer.new("nats: slow consumer, messages dropped")` (`:1041–1043`). So the two
  directions behave differently: outbound blocks, inbound drops — [[slow-consumer-in-the-client]].
- **A dead link is noticed on the second unanswered ping, about four minutes** —
  `@pings_outstanding >= @options[:max_outstanding_pings]` at `DEFAULT_PING_INTERVAL = 120` and
  `DEFAULT_PING_MAX = 2` (`:1421`, `:1883–1884`). nats.go's test is `pout > MaxPingsOut`, so it waits
  for the third and takes about six. A failover budget measured with a Go client is two minutes
  optimistic for Ruby, and vice versa — [[client-connection-lifecycle]].
- **`drain` returns immediately**, exactly as in Go: it starts a thread (`:842–848`). The comment says
  to "use the `on_close` callback option to know when the connection has moved from draining to
  closed". `DEFAULT_DRAIN_TIMEOUT = 30`. Open issue **#79** (2022-08-22) is "Long running jobs get
  killed when draining".
- **An auth error deletes that server from the pool at once**, before any budget applies — "In case of
  hard errors like authorization errors, drop the server already since won't be able to connect"
  (`:1717–1718`) — so unlimited reconnects do not save a connection whose credential expired
  ([[connection-closed-after-auth-error]]).
- **No release since 2025-02-21.** v2.5.0 predates nats-server 2.12 and 2.14 entirely, so per-message
  TTL, priority groups, batch publish and message schedules are not exposed here.

## Related

[[nats-rb]] · [[nats-server]] · [[nats-ex]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-nats-pure-rb-client-source]] · [[s-client-releases-and-issues]]
