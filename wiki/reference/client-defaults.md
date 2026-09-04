---
title: Client connection defaults
type: reference
area: [clients, core]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats.go v1.53.1, natscli 0.4.0, nats-server 2.14.6
verified-on: 2026-09-04
tags: [client-defaults, reconnect, ReconnectWait, MaxReconnect, jitter, reconnect-buffer, ping, MaxPingsOut, DrainTimeout, flush, pending-limits, connect-timeout, discovery]
aliases: [client defaults, connection defaults, reconnect defaults, ReconnectWait, MaxReconnect, ReconnectBufSize, PingInterval, MaxPingsOut, DrainTimeout, DefaultSubPendingMsgsLimit, DefaultSubPendingBytesLimit, "connect timeout", "reconnect buffer size", "ping interval"]
sources: [s-nats-go-connection, s-nats-cli-reconnect, s-docs-resilient-clients-connecting, s-docs-resilient-clients-reconnection-and-events, s-docs-resilient-clients-drain-and-shutdown, s-nats-server-client-lifecycle-observed, s-nats-go-subscription, s-docs-resilient-clients-slow-consumers-and-request-reply, s-docs-resilient-clients-tls-and-auth, s-nats-server-client-faults-observed, s-docs-protocol-client, s-nats-server-wire-protocol, s-client-releases-and-issues, s-nats-pure-rb-client-source]
created: 2026-09-04
updated: 2026-09-04
---

# Client connection defaults

What each NATS client does when you configure nothing: connect timeout, reconnect policy, buffers,
keepalive, drain and flush. It covers the **connection**, not the API — per-language method reference
is deliberately out of scope for this wiki. The mechanisms these values govern are on
[[client-connection-lifecycle]]; the *server's* defaults are in [[defaults-and-limits]].

**Two levels of evidence, and the tables say which.** The **nats.go** and **`nats` CLI** columns are
read from the source at a pinned version, with file and line. Every other client's column is **the
documentation's word** — the `learn/resilient-clients` chapter is unversioned by design and names no
client version anywhere, so those values carry no version and were not re-checked against the client
in question. Step 6 of the client-side plan revisits them from each client's own README and release
notes.

## nats.go v1.53.1 — read from the source

Every value below is in one const block (`nats.go:51–69`) applied by `GetDefaultOptions()`
(`:163–178`), except the two pending limits (`:5762–5768`) (source: [[s-nats-go-connection]]).

| setting | option | default | what it governs |
|---|---|---|---|
| default URL | `Options.Url` | `nats://127.0.0.1:4222` | |
| connect timeout | `Timeout` | **`2s`** | the dial |
| reconnect on | `AllowReconnect` | **`true`** | |
| attempts per server | `MaxReconnect` | **`60`** | **per server**; spending it removes the server from the pool |
| wait between sweeps | `ReconnectWait` | **`2s`** | applied after a whole sweep, not per dial |
| jitter, plaintext | `ReconnectJitter` | **`100ms`** | |
| jitter, TLS | `ReconnectJitterTLS` | **`1s`** | chosen once for the whole pool, by `Secure \|\| TLSConfig != nil` |
| reconnect buffer | `ReconnectBufSize` | **`8MB`** | overflow → `ErrReconnectBufExceeded` |
| ping interval | `PingInterval` | **`2m`** | fires regardless of traffic |
| outstanding pings | `MaxPingsOut` | **`2`** | stale on the **third** interval → 6 minutes |
| drain timeout | `DrainTimeout` | **`30s`** | the subscription phase only |
| publish-flush bound in a drain | — | **`5s`, hardcoded** | `nats.go:6291` |
| `Flush()` | — | **`10s`, fixed** | `FlushTimeout()` takes your own |
| flusher timeout | `FlusherTimeout` | **`1m`** | |
| subscription pending, messages | `DefaultSubPendingMsgsLimit` | **`500_000`** | per subscription |
| subscription pending, bytes | `DefaultSubPendingBytesLimit` | **`64MB`** | per subscription |
| inbound channel length | `DefaultMaxChanLen` | **`65536`** | |
| async error callback | `AsyncErrorCB` | **`defaultErrHandler`** | writes to **stderr** when you set none |

## `nats` CLI 0.4.0 — read from the source

The CLI is **not** a stock nats.go connection, so a failover watched with `nats sub` is not a witness
for what an application would do (source: [[s-nats-cli-reconnect]]).

| setting | CLI value | vs the library |
|---|---|---|
| `MaxReconnects` | **`-1`** (unlimited) | library default is 60 per server |
| auth-error abort | **off** (`IgnoreAuthErrorAbort()`) | library aborts on the same error from the same server twice |
| reconnect delay | a **44-step table, 500 ms → 20 s**, saturating, each step jittered to `[0.5×, 1.5×]` | replaces `ReconnectWait` *and* the jitter |
| first delay actually used | drawn from the **750 ms** step | nats.go increments the sweep counter before calling the callback, so the table's 500 ms entry is never used (measured; docs issue #91) |
| connection name | `NATS CLI Version <version>` | `--connection-name` overrides |
| `nats rtt` | **5** round trips per server | |
| closed handler | `log.Fatalf` **1 s later** | the process exits |
| `nats reply` on Ctrl-C | `Drain()` then `log.Fatalf("Exiting")` | does **not** wait for the drain |
| async error line | printed **only** under `--trace` | the handler is registered twice and the trace-gated one wins |

## Other clients — the documentation's word

No version attaches to these: the chapter that states them is unversioned, and this wiki has not
checked them against the client (source: [[s-docs-resilient-clients-connecting]],
[[s-docs-resilient-clients-reconnection-and-events]], [[s-docs-resilient-clients-drain-and-shutdown]]).

| setting | Go | Java | Python | JavaScript | Rust | C# |
|---|---|---|---|---|---|---|
| connect timeout | 2 s | 2 s | 2 s | **20 s** | **5 s** | 2 s |
| `MaxReconnect` default | 60 | 60 | 60 | **10** | unlimited | unlimited |
| reconnect wait | fixed 2 s | fixed | fixed (`reconnect_time_wait`) | fixed | **grows per attempt** | **grows per attempt** |
| jitter | 100 ms / 1 s TLS | 100 ms / 1 s TLS | **none** | 100 ms / 1 s TLS | **none** | 100 ms always |
| reconnect buffer | 8 MB | 8 MB | **2 MB** | — | **backpressure on a bounded queue** | — |
| buffer overflow | `ErrReconnectBufExceeded` | error | error | — | **blocks** | — |
| subscription pending | 500 000 msgs / 64 MB | "similarly large" | "similarly large" | **unbounded, never drops** | **65 536** (`subscription_capacity`, per connection) | **1 024**-message channel |
| ping interval × budget | 2 m × 2 | 2 m × 2 | 2 m × 2 | 2 m × 2 | **1 m × 2 (fixed)** | 2 m × 2 |
| ping timer reset by inbound traffic | **no** | — | — | — | **yes** | — |
| drain phases visible | `DRAINING_SUBS`/`DRAINING_PUBS` | internal | `DRAINING_SUBS`/`DRAINING_PUBS` | internal | internal | opt-in on dispose |
| `Drain()` waits? | **no** — use `ClosedHandler` | `drain(Duration)` future | `await` | `await` | — | `DrainSubscriptionsOnDispose`, default `false` |
| per-subscription drain | yes | yes (`Subscription`, `Dispatcher`) | yes | yes | yes | **none** |
| flush | `Flush()` 10 s | `flush(Duration)` | `nc.flush()` | `await nc.flush()` | **no PONG wait** | **none** (`PingAsync()`) |
| RTT probe | `RTT()` | `RTT()` | `rtt()` | `rtt()` | **none** | `PingAsync()` |
| discovery opt-out | `IgnoreDiscoveredServers` | `ignoreDiscoveredServers()` | **none** | `ignoreClusterUpdates` | `ignore_discovered_servers` | **none** |
| discovered-servers event | `DiscoveredServersCB` | `DISCOVERED_SERVERS` | `discovered_server_cb` | `update` status | **none** | **none** |
| closed event | `ClosedHandler` | `CLOSED` | `closed_cb` | `nc.closed()` promise | `Event::Closed` | **none** — poll `ConnectionState` |
| state getter | `Status()` (7) | `getStatus()` (5) | four `is_*` properties | **none** beyond `isClosed()`/`isDraining()` | `connection_state()` (3) | `ConnectionState` (5) |
| first-connect retry | `RetryOnFailedConnect(true)` | `connectReconnectOnConnect` / `connectAsynchronously` | built in | `waitOnFirstConnect: true` | `retry_on_initial_connect()` | `RetryOnInitialConnect = true` |

**Three C# cells are out of date, and the client says so.** nats.net **v3.0.0** (2026-07-10) shipped
seven weeks before this documentation tree was fetched and changed all three (source:
[[s-client-releases-and-issues]]; the row is `inbox/docs-issues.md` #121):

| cell | the chapter | nats.net v3.0.0 |
|---|---|---|
| subscription pending | "a 1,024-message channel", `NatsClient` waits on overflow | **16,384** for every entry point, `BoundedChannelFullMode.DropNewest`, overflow surfaced as `MessageDropped` |
| per-subscription drain | "**none**" | **`INatsSub<T>.DrainAsync()`** — "no new deliveries, in-flight messages fenced with a PING/PONG, channel completed" |
| drain phases visible | opt-in on dispose | still `DrainSubscriptionsOnDispose` for the connection, **plus** the explicit call above |

Prefer the client's own release notes over the chapter for .NET on v3; the chapter's cells still hold
for the v2 line. The other five columns have not been re-checked this way — treat the table as the
documentation's word with one dated exception.

## Ruby — read from the client, because the documentation never names it

The chapter's per-client table has no Ruby column, and neither has any other `learn/` page: Go, Java,
Python, JavaScript, Rust and C# fill every sentence. These are read from `lib/nats/io/client.rb` at
tag **v2.5.0** — the current release, 2025-02-21 (source: [[s-nats-pure-rb-client-source]]).

| setting | nats-pure.rb v2.5.0 | line |
|---|---|---|
| connect timeout | **2 s** (`DEFAULT_CONNECT_TIMEOUT`) | `:1887` |
| read/write timeout | **2 s** (`DEFAULT_READ_WRITE_TIMEOUT`) — no other client documents one | `:1888` |
| `max_reconnect_attempts` | **10**, per server; `< 0` means unlimited | `:1869`, `:1714` |
| reconnect wait | **2 s** fixed, **no jitter** | `:1870` |
| ping interval × budget | **120 s × 2**, and the test is `>=` | `:1883–1884`, `:1421` |
| stale detected on | the **second** unanswered ping — about **4 minutes** (Go takes 6) | `:1421` |
| subscription pending | **65,536 msgs / 64 MB**, overflow **drops** with `NATS::IO::SlowConsumer` | `:1893–1894`, `:1041` |
| outbound queue | `SizedQueue` of **32,768** commands — a publish **blocks** when full | `:458`, `:1873` |
| drain | returns immediately (a thread); wait on `on_close` | `:842–848` |
| drain / close timeout | **30 s** each | `:1889–1890` |
| drain phases visible | **yes** — `DRAINING_SUBS`, `DRAINING_PUBS` | `:81–83` |
| auth error | drops that server from the pool at once, before any budget | `:1717–1718` |
| subscription concurrency | **24** threads total, **1** per subscription | `:1896–1897` |

Two of those change how a Ruby service behaves under a fault in a way no other client shares: it
**blocks the publisher** rather than failing the publish, and it gives up on a silent link two
minutes sooner than Go. The keepalive row is also the one client that implements ADR-40's rule as
written — see `inbox/docs-issues.md` #90.


## Measured, on nats-server 2.14.6

From the runs in [[s-nats-server-client-lifecycle-observed]]; the shapes are in
[[client-connection-lifecycle]].

| what | measured |
|---|---|
| reconnect gap, subscriber on a stopped node, 89 msg/s | **0 messages lost** |
| the same at 25 800 msg/s | **10 lost**, one contiguous run — a gap ≈ **0.39 ms** |
| a one-URL client's failover | **works**, via `connect_urls` gossip |
| lame duck → the `ldm` INFO reaches the client | **~1 s** after the notice (the Raft transfer wait, then the JetStream shutdown) |
| lame duck → clients closed | **10.0 s** after that INFO (`lame_duck_grace_period`), 11.0 s after the notice |
| client keepalive detection, nats.go defaults | **6 min 0 s** — the third ping interval |
| server keepalive, `ping_interval 5s` / `ping_max 2` | `-ERR 'Stale Connection'` at **t=12.19 s**, nothing in the server log |
| `nats reply` Ctrl-C, 1 s handler, 8 in flight | **4 answered, 4 abandoned** |
| pull consumer across a consumer-leader move | **1 fetch of 120** failed, `no responders`, 17 ms |
| un-acked messages when the leader moved | all **10** returned later with `tries: 2` |

## Pending limits: the Go default is two numbers, not one

The subscription pending buffer is per **subscription**, and in nats.go its message limit is set
from the subscription type at subscribe time — before any message arrives
(source: [[s-nats-go-subscription]]):

| nats.go subscription | message limit | byte limit |
|---|---|---|
| async (`Subscribe`, a callback) | `DefaultSubPendingMsgsLimit` = **500,000** | **64 MB** |
| sync (`SubscribeSync`) or channel (`ChanSubscribe`) | the channel capacity — `DefaultMaxChanLen` = **65,536** | **64 MB** |

Both were read off a running client (source: [[s-nats-server-client-faults-observed]], A1 and A4).
The chapter's "500,000 messages and 64 MB in the Go client" is the async row only
(source: [[s-docs-resilient-clients-slow-consumers-and-request-reply]]).

`SetPendingLimits(msgs, bytes)` has two rules the docs do not state, both measured (run A3):
**`0` in either argument returns `nats: invalid argument`**, and **a negative value means
unlimited** — so `SetPendingLimits(200, -1)` is the idiom for bounding the count alone. The overflow
fires the async error callback **once per transition**, and the transition re-arms on the next
message that fits: **13 callbacks for 4,888 dropped messages** in the run. See
[[slow-consumer-in-the-client]].

## The auth-error abort, per client

An authentication rejection is the one reconnect failure most clients refuse to retry indefinitely.
The rule and the opt-out differ (source: [[s-docs-resilient-clients-tls-and-auth]]; the Go row and
the CLI row are read from source, the rest are the documentation's word):

| client | rule | opt-out |
|---|---|---|
| nats.go | the **same error** from the **same server** twice in a row → CLOSED | `IgnoreAuthErrorAbort()` |
| nats.js | two auth errors in a row → abort | `ignoreAuthErrorAbort` |
| nats.java | the same server returns the same auth error twice → closes | — |
| nats.net | the same auth error twice in a row → `Failed` | same-named option |
| nats.py | **no abort** — cycles until every server exceeds `max_reconnect_attempts` (60) | — |
| nats.rs | **no abort** — cycles until `max_reconnects` runs out (unlimited) | — |
| nats.c | the same auth error twice → abort, with **no opt-out before v3.13.0** | `natsOptions_SetIgnoreAuthErrorAbort`, **v3.13.0** (2026-06-01) |
| nats-pure.rb | **any** auth error drops that server from the pool at once, whatever the budget | — |
| `nats` CLI 0.4.0 | **no abort** — sets `IgnoreAuthErrorAbort` *and* unlimited reconnects | — |

In the four clients with the rule, the abort applies **regardless of the retry budget**: unlimited
reconnects do not override it. Measured on nats.go v1.53.1 against an expiring user JWT: **CLOSED
0.51 s after expiry at `ReconnectWait 500ms` (1 attempt), 4.12 s at the default 2 s (2 attempts)** —
the count varies because the server's answer changes from `User Authentication Expired` to
`Authorization Violation` a second after the expiry
(source: [[s-nats-server-client-faults-observed]], B3/B6). See
[[connection-closed-after-auth-error]].

Which clients **re-read a `.creds` file** on every attempt, and which load it once, decides whether a
rotated file reaches a reconnect at all: nats.go, nats.java and nats.py re-read; nats.js, nats.rs and
nats.net load once and need the credential-callback form
(source: [[s-docs-resilient-clients-tls-and-auth]]).


## Publish subject validation, per client and per version

Whether a client rejects `orders.us created` before it reaches the wire is a **version** question,
not a language one — the check arrived separately in each client, all of it recently, and two clients
still have none. Without it the server reads the space as the field separator and delivers to
`orders.us` with reply subject `created`, silently (source: [[s-nats-server-core-delivery-observed]],
run A2; the rule is on [[subjects-and-wildcards]]). Read from each client's release notes (source:
[[s-client-releases-and-issues]]).

| client | validation arrived | opt-out |
|---|---|---|
| nats.js | **v3.3.0**, 2025-12-16 (#348) | — |
| nats.go | **v1.48.0**, 2025-12-17 (#1974, #1979) | yes, a connection option |
| nats.java | **2.25.1**, 2026-01-15 (#1501) | — |
| nats.rs | **v0.47.0**, 2026-03-31 (#1525) | yes |
| nats.net | had it; `SkipSubjectValidation` **deprecated at v3.0.0**, 2026-07-10 | being removed |
| nats.c | **none** in the last ten releases (v3.10.0 → v3.13.0) | n/a |
| nats.py | **none** in the last ten releases (v2.9.0 → v2.15.0) | n/a |


## The server's own connection defaults

The client values above are half the story: the other half is what the *server* will tolerate, and
every one of these is a hard stop the client cannot negotiate. Read from `const.go` at v2.14.6
(source: [[s-nats-server-wire-protocol]]); the full table with the `-ERR` each one produces is
[[wire-protocol]].

| setting | constant | default | what happens at the limit |
|---|---|---|---|
| `ping_interval` | `DEFAULT_PING_INTERVAL` | **`2m`** | with `ping_max`, gives a 6-minute stale budget |
| `ping_max` | `DEFAULT_PING_MAX_OUT` | **`2`** | `-ERR 'Stale Connection'` on interval `ping_max + 1` |
| `authorization { timeout }` | `AUTH_TIMEOUT` | **`2s`** | `-ERR 'Authentication Timeout'` |
| `tls { timeout }` | `TLS_TIMEOUT` | **`2s`** | the socket is dropped with **no** `-ERR` |
| `max_control_line` | `MAX_CONTROL_LINE_SIZE` | **`4096`** | `-ERR 'maximum control line exceeded'`; ×16 for non-client kinds |
| `max_payload` | `MAX_PAYLOAD_SIZE` | **`1MB`** | `-ERR 'Maximum Payload Violation'` |
| `max_pending` | `MAX_PENDING_SIZE` | **`64MB`** | the connection is closed with **no** `-ERR` |
| `max_connections` | `DEFAULT_MAX_CONNECTIONS` | **`65536`** | `-ERR 'maximum connections exceeded'` |
| `max_subscriptions` | — | **`0`** (unlimited) | `-ERR 'maximum subscriptions exceeded'`, connection survives |

`reference/protocols/client.md` states three of these wrongly on one table — the auth timeout as
1 second, `max_control_line` as 1024 bytes and the pending limit as 10 MB (`inbox/docs-issues.md`
#102, source: [[s-docs-protocol-client]]).


## How this was derived

- **nats.go**: `raw/nats-go-src/connection-v1.53.1.md` — 26 verbatim ranges of `nats.go` at tag
  v1.53.1, fetched from `raw.githubusercontent.com`. Regenerate by fetching
  `https://raw.githubusercontent.com/nats-io/nats.go/<tag>/nats.go` and re-reading the const block,
  `GetDefaultOptions`, `doReconnect`, `processPingTimer` and `drainConnection`.
- **`nats` CLI**: `raw/nats-cli/reconnect-0.4.0.md` — `cli/util.go`, `internal/util/backoff.go`,
  `cli/reply_command.go` and `cli/rtt_command.go` from the Go module cache at
  `$(go env GOMODCACHE)/github.com/nats-io/natscli@v0.4.0`.
- **Other clients**: `raw/nats-docs/learn/resilient-clients/*.md`, fetched 2026-08-31. The chapter
  states these in prose and gives no version; every cell above quotes it directly.
- **Client release notes and open issues**:
  `raw/github-repos/nats-io__<repo>.releases-2026-09-04.md`, one file per client — the last ten
  release bodies verbatim plus every open issue as number, date and title. Regenerate with
  `gh api repos/nats-io/<repo>/releases?per_page=10` and
  `gh api repos/nats-io/<repo>/issues?state=open --paginate`.
- **nats-pure.rb**: `raw/github-repos/nats-io__nats-pure.rb.client-v2.5.0.md` — quoted ranges of
  `lib/nats/io/client.rb` at tag v2.5.0. Regenerate with
  `gh api "repos/nats-io/nats-pure.rb/contents/lib/nats/io/client.rb?ref=v2.5.0"`.
- **Measured**: `raw/nats-server-src/client-lifecycle-observed-v2.14.6.md`, with
  `client-lifecycle-run.sh`, `-run2.sh`, `-run3.sh` and `-stale-run.sh` beside it. Re-run them
  against `tools/lab/cluster.sh` on the same release.

## Related

[[client-connection-lifecycle]] · [[defaults-and-limits]] · [[config-keys]] · [[nats-go]] ·
[[nats-cli]] · [[core-nats-delivery]] · [[how-clients-reach-a-cluster]] · [[nats-timeout]]

## Sources

[[s-nats-go-connection]] · [[s-nats-cli-reconnect]] · [[s-docs-resilient-clients-connecting]] · [[s-docs-resilient-clients-reconnection-and-events]] · [[s-docs-resilient-clients-drain-and-shutdown]] · [[s-nats-server-client-lifecycle-observed]] · [[s-nats-go-subscription]] · [[s-docs-resilient-clients-slow-consumers-and-request-reply]] · [[s-docs-resilient-clients-tls-and-auth]] · [[s-nats-server-client-faults-observed]] · [[s-docs-protocol-client]] · [[s-nats-server-wire-protocol]] · [[s-client-releases-and-issues]] · [[s-nats-pure-rb-client-source]]
