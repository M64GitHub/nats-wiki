---
title: "nats CLI 0.4.0 — the connection it opens, and the reconnect policy it overrides"
type: summary
area: [clients, core]
source-url: https://github.com/nats-io/natscli/blob/v0.4.0/cli/util.go
source-path: raw/nats-cli/reconnect-0.4.0.md
author: nats-io
article: "natscli v0.4.0 — cli/util.go natsOpts(), internal/util/backoff.go, cli/reply_command.go, cli/rtt_command.go"
date: 2026-09-04
version: "natscli 0.4.0"
tags: [nats-cli, reconnect, backoff, jitter, MaxReconnects, IgnoreAuthErrorAbort, trace, drain, rtt, error-handler]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# nats CLI 0.4.0 — the connection it opens, and the reconnect policy it overrides

The `nats` CLI is the tool an operator watches a failover with, so what it does *differently* from a
stock nats.go connection is part of every observation made with it. Extract:
`raw/nats-cli/reconnect-0.4.0.md`. Its `go.mod` pins nats.go **v1.51.0** (`go.mod:25`); the client
values this wiki quotes are read at v1.53.1 in [[s-nats-go-connection]], and the two constants the
CLI depends on are set by the CLI itself rather than defaulted.

## Key claims

### Two deliberate departures from the library defaults (`cli/util.go:246–247`)

```go
	nats.MaxReconnects(-1),
	nats.IgnoreAuthErrorAbort(),
```

The CLI **reconnects forever** and **never aborts on a repeated authentication error**. A `nats sub`
left running through an outage is therefore *not* a witness for what an application on the library
defaults would do: the application would spend a 60-attempt per-server budget and close, and it
would abort on the second identical auth error.

### The backoff table (`cli/util.go:248–256`, `internal/util/backoff.go:31–48, 95–103`)

`CustomReconnectDelay` returns `iu.DefaultBackoff.Duration(attempts)`, a **44-step table from 500 ms
to 20 s**:

```
500, 750, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000,
5500, 5750, 6000, 6500, 7000, 7500, 8000, 8500, 9000, 9500, 10000,
10500, 10750, 11000, 11500, 12000, 12500, 13000, 13500, 14000, 14500, 15000,
15500, 15750, 16000, 16500, 17000, 17500, 18000, 18500, 19000, 19500, 20000
```

saturating at the last entry, each step passed through `jitter()`, which returns
`millis/2 + rand.N(millis)` — "a random integer uniformly distributed in the range
`[0.5 * millis .. 1.5 * millis]`". Because nats.go adds no jitter of its own when a custom delay is
set ([[s-nats-go-connection]]), this table *is* the whole policy. It confirms the docs'
"500 ms rising to a 20-second cap, each step randomized between half and one-and-a-half times its
value" (`reconnection.md:47–57`).

### The six `>>>` lines, and which need `--trace` (`cli/util.go:248–292`)

| line | gated on `--trace`? |
|---|---|
| `>>> Setting reconnect delay to <d>` | yes — **and the docs never mention it** |
| `>>> Connected to <url> (<addr>)` | yes |
| `>>> Discovered new servers, known servers are now <urls>` | yes |
| `>>> Disconnected due to: <err>, will attempt reconnect` | **no** |
| `>>> Reconnected to <url> (<addr>)` | yes |
| `>>> Connection is closed: <err>` | **no** — and it is a `log.Fatalf` |
| `>>> Reconnect error: <err>` | yes |
| `>>> Unexpected NATS error: <err>` | **effectively yes** — see below |

### The async error handler is registered twice (`cli/util.go:280–292`)

`nats.ErrorHandler(...)` appears at `:280` (unconditional `log.Printf`) and again at `:288`
(trace-gated). Each call assigns `Opts.AsyncErrorCB`, so **the second registration wins** and
`>>> Unexpected NATS error` never prints without `--trace`. A client-side slow consumer under a
plain `nats sub` is therefore silent — the CLI has replaced nats.go's `defaultErrHandler`, which
would have written it to stderr, with a handler that logs nothing.

### Closed is fatal, one second later (`cli/util.go:277–279`)

```go
	nats.ClosedHandler(func(nc *nats.Conn) {
		time.AfterFunc(time.Second, func() { log.Fatalf(">>> Connection is closed: %v", nc.LastError()) })
	}),
```

### `nats reply` drains and then exits immediately (`cli/reply_command.go:223–228`)

```go
	signal.Notify(ic, os.Interrupt)
	<-ic

	log.Printf("\nDraining...")
	nc.Drain()
	log.Fatalf("Exiting")
```

`Drain()` in nats.go returns as soon as it has started the background drain, so the `log.Fatalf`
kills the process while the drain is still running. The docs describe this deliberately
([[s-docs-resilient-clients-drain-and-shutdown]], L47); run C4 in
[[s-nats-server-client-lifecycle-observed]] counts what it loses — four of eight in-flight requests.

### `nats rtt` (`cli/rtt_command.go:52–54`)

`Arg("iterations", …).Default("5")` — five round trips per server, as the docs say.

## Practical takeaways

- Reading a failover with `nats sub --trace` shows you the *CLI's* policy, not your application's.
  The two differ in exactly the ways that matter under a long outage.
- `--trace` is not optional when watching a client: without it the CLI prints two lines and swallows
  every async error, including a slow consumer.
- `nats reply` is a demonstration of where `Drain()` belongs, never a demonstration of a drain.

## Relevance to the wiki

The natscli column of [[client-defaults]], the *What bites you* section of [[nats-cli]], and the
caveat every observed run in this wiki made with the CLI needs.

## Questions it answers

Contributes to rows 177 and 179; the CLI half of row 82.

## Pages touched

[[client-defaults]] · [[client-connection-lifecycle]] · [[nats-cli]] · [[slow-consumer-detected]]
