---
title: "nats-pure.rb v2.5.0 — the connection, read from the source"
type: summary
area: [clients, core]
source-url: https://github.com/nats-io/nats-pure.rb/blob/v2.5.0/lib/nats/io/client.rb
source-path: raw/github-repos/nats-io__nats-pure.rb.client-v2.5.0.md
author: nats-io/nats-pure.rb maintainers
article: "lib/nats/io/client.rb at tag v2.5.0 — the constants, drain, the ping loop, the queues"
date: 2026-09-04
version: "2.14"
tags: [clients, ruby, defaults, drain, reconnect, slow-consumer, keepalive]
aliases: []
sources: [s-docs-resilient-clients-connecting, s-docs-resilient-clients-reconnection-and-events, s-docs-resilient-clients-drain-and-shutdown, s-nats-go-connection, s-adr-40-nats-connection]
created: 2026-09-04
updated: 2026-09-04
---

# nats-pure.rb v2.5.0 — the connection, read from the source

The Ruby client is named in **none** of the eight `learn/resilient-clients` pages — Go, Java, Python,
JavaScript, Rust and C# fill every per-client sentence and every table cell (source:
[[s-docs-resilient-clients-connecting]]). Its ten release bodies state no default either. So for the
client the docs call "preferred Ruby client", the only public statement of what it does under a
network fault is its own source. This is that read, at tag **v2.5.0** (2025-02-21, the current
release), quoted in `raw/github-repos/nats-io__nats-pure.rb.client-v2.5.0.md` with the line numbers
the file has at that tag.

## Key claims

### The defaults (`lib/nats/io/client.rb:1863–1898`)

| constant | value | the other clients |
|---|---|---|
| `MAX_RECONNECT_ATTEMPTS` | **10** | 60 in Go, Java and Python; 10 in JavaScript; unlimited in Rust and C# |
| `RECONNECT_TIME_WAIT` | **2** (seconds), fixed, no jitter | 2 s in Go and Java, both with jitter |
| `DEFAULT_PING_INTERVAL` | **120** (seconds) | the same everywhere but Rust's 60 |
| `DEFAULT_PING_MAX` | **2** | the same everywhere |
| `DEFAULT_CONNECT_TIMEOUT` | **2** | 2 s in most, 5 in Rust, 20 in JavaScript |
| `DEFAULT_READ_WRITE_TIMEOUT` | **2** | not stated for any other client |
| `DEFAULT_DRAIN_TIMEOUT` | **30** | 30 s in C, 30 s in Go |
| `DEFAULT_CLOSE_TIMEOUT` | **30** | not stated for any other client |
| `DEFAULT_SUB_PENDING_MSGS_LIMIT` | **65536** | 500,000 in Go, 65,536 in Rust |
| `DEFAULT_SUB_PENDING_BYTES_LIMIT` | `65536 * 1024` = **64 MB** | 64 MB in Go |
| `MAX_PENDING_SIZE` | **32768**, the outbound `SizedQueue`'s bound | Go's `ReconnectBufSize` is 8 MB of bytes |
| `DEFAULT_TOTAL_SUB_CONCURRENCY` | **24** | no other client has a thread-pool default |

### Stale detection fires on the **second** unanswered ping, not the third

```ruby
if @pings_outstanding >= @options[:max_outstanding_pings]
  process_op_error(NATS::IO::StaleConnectionError.new("nats: stale connection"))
  return
end
```

(`:1421–1424`.) `>=` with `DEFAULT_PING_MAX = 2` means the loop gives up on the second interval that
passes without a `PONG` — about **four minutes**. nats.go's test is `pout > MaxPingsOut`, so it waits
for the **third**, about six minutes (source: [[s-nats-go-connection]]). ADR-40 states the rule as
"if two consecutive PONGs are missed, connection is marked as lost" (source:
[[s-adr-40-nats-connection]]); **Ruby implements the ADR's rule and Go does not**, which settles that
the disagreement recorded in `inbox/docs-issues.md` #94 is a real cross-client divergence rather than
a wording problem. Like Go, the loop pings on the interval whatever the traffic — only a `PONG`
clears `@pings_outstanding`.

### `drain` returns immediately, as in Go

```ruby
def drain
  return if draining?

  synchronize do
    @drain_t ||= Thread.new { do_drain }
  end
end
```

(`:842–848`.) The comment above it says to "use the `on_close` callback option to know when the
connection has moved from draining to closed" (`:837–841`) — the same trap the drain chapter states
for Go, in a client the chapter never mentions. The connection does report the phases: `DRAINING_SUBS
= 5` and `DRAINING_PUBS = 6` (`:81–83`), which the documentation attributes to nats.go and nats.py
only (source: [[s-docs-resilient-clients-drain-and-shutdown]]).

### A publish blocks when the outbound queue fills; it does not fail

`@pending_queue = SizedQueue.new(NATS::IO::MAX_PENDING_SIZE)` (`:458`). A Ruby `SizedQueue` **blocks
the pushing thread** when full, so an outage long enough to fill 32,768 queued commands stalls the
publisher rather than returning an error. Go, Java and Python fail the publish there (Go with
`ErrReconnectBufExceeded`); Rust blocks (source:
[[s-docs-resilient-clients-reconnection-and-events]]). Ruby is with Rust, and open issue **#169**
(2025-05-28, "When client @pending_queue is full, the library blocks the process") is that behaviour
being reported as a bug.

### The subscription side drops, with a slow-consumer error

```ruby
if (sub.pending_queue.size >= sub.pending_msgs_limit) \
  || (sub.pending_size >= sub.pending_bytes_limit)
  err = NATS::IO::SlowConsumer.new("nats: slow consumer, messages dropped")
```

(`:1041–1043`.) So the two directions differ: outbound blocks, inbound drops at 65,536 messages or
64 MB.

### The reconnect budget is per server, and a hard error deletes the server

```ruby
return true if @options[:max_reconnect_attempts] < 0
return false if server[:error_received]
server[:reconnect_attempts] <= @options[:max_reconnect_attempts]
```

(`:1714–1721`.) Negative means unlimited; an authorization error drops the server from the pool
outright ("In case of hard errors like authorization errors, drop the server already since won't be
able to connect"). This is the same shape as nats.go's `selectNextServer`, at a budget of 10 rather
than 60.

## Practical takeaways

- **Set `max_reconnect_attempts: -1` on any long-lived Ruby service.** Ten attempts per server at a
  fixed 2 s is twenty seconds of tolerance for a three-node cluster before the connection closes for
  good.
- **A Ruby publisher stalls in an outage rather than raising.** Code that expects an exception to
  signal a disconnect will simply stop, with no error to log.
- **Wait on `on_close`, not on `drain`'s return** — the same rule as Go.
- **Ruby notices a dead link two minutes sooner than Go does**, which changes what a failover test
  measures depending on which client runs it.

## Notable quotes

> "In case of hard errors like authorization errors, drop the server already since won't be able to
> connect." — `client.rb:1717–1718`

> "Maximum accumulated pending commands bytesize before forcing a flush." — the comment on
> `MAX_PENDING_SIZE` (`:1872`), which the code then uses as a `SizedQueue` **length** (`:458`)

## Relevance to the wiki

It is the only version-bearing statement this wiki has of any Ruby default, and it settles the
ADR-40 keepalive disagreement as a real divergence between clients rather than a documentation slip.

## Questions it answers

175, 178, 180, 181 — in each case by adding the Ruby column [[client-defaults]] did not have.

## Pages touched

[[nats-pure-rb]] · [[client-defaults]] · [[client-connection-lifecycle]] · [[nats-rb]]

## Sources

[[s-docs-resilient-clients-connecting]] · [[s-docs-resilient-clients-reconnection-and-events]] ·
[[s-docs-resilient-clients-drain-and-shutdown]] · [[s-nats-go-connection]] · [[s-adr-40-nats-connection]]
