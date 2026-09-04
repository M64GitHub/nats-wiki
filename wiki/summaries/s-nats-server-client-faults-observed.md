---
title: "Observed on nats-server 2.14.6 — the three client faults: a slow consumer, a credential expiring, a TLS mismatch"
type: summary
area: [clients, core, security, monitoring]
source-url: https://github.com/nats-io/nats-server/releases/tag/v2.14.6
source-path: raw/nats-server-src/client-faults-observed-v2.14.6.md
author: this wiki (runs)
article: "runs A-C on nats-server v2.14.6 with nats CLI 0.4.0, nats.go v1.53.1, jwt/v2 v2.8.2, nkeys v0.4.16, Go 1.27.0, OpenSSL 3.x, 2026-09-04"
date: 2026-09-04
version: "nats-server 2.14.6"
tags: [observed, slow-consumer, SetPendingLimits, write_deadline, max_pending, user-authentication-expired, account-authentication-expired, authorization-violation, handshake_first, tlsfirst]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# Observed on nats-server 2.14.6 — the three client faults

Five passes on standalone servers, recorded verbatim with their scripts in
`raw/nats-server-src/client-faults-observed-v2.14.6.md`. The `nats` CLI can neither set pending
limits nor mint a JWT with a chosen expiry, so runs A and B use short Go programs kept beside the
transcript; no `nsc` was installed — `client-faults-mintjwt.go` builds the operator/account/user
chain with `nats-io/jwt` v2.8.2 and `nkeys` v0.4.16, the same libraries the server verifies against.

## Key claims

### A — the two slow consumers

**A1** async subscription, 20 ms handler, `SetPendingLimits(100, -1)`, 5,000 messages in 234 ms:
**4,889 dropped, 111 delivered**, `MaxPending` 101 msgs / 9,191 B, the subscription still valid, the
connection **CONNECTED** throughout, `LastError` = `nats: slow consumer, messages dropped`. With **no
async error callback set**, nats.go wrote **12 lines to stderr**:

```
nats: slow consumer, messages dropped on connection [5] for subscription on "orders.>"
```

The limits printed before any message arrived were **500,000 msgs / 67,108,864 B**.

**A2** the same with an explicit `ErrorHandler`: **13 fires for 4,888 drops**, every one with
`status CONNECTED`, and **stderr empty** — a caller's handler *replaces* `defaultErrHandler`. The
count is neither 1 nor 4,888 because `sub.sc` is cleared by the next message that fits.

**A3** `SetPendingLimits(0, -1)` and `(-1, 0)` both return `nats: invalid argument`; `(100, -1)`
succeeds and reads back as `msgs=100 bytes=-1`.

**A4** a **sync** subscription starts at **65,536 msgs / 64 MB**, not 500,000. After overflow
`NextMsg` returned `ErrSlowConsumer` **15 times** over 3,938 drops while delivering 62 — and the
connection's default handler wrote the same 15 lines. A sync subscriber is told twice.

**A5** the server's `write_deadline` branch (`write_deadline: "100ms"`, a raw subscriber that never
reads, 20,000 × 4 kB):

```
Slow Consumer Detected: WriteDeadline of 100ms exceeded with 2 chunks of 4029 total bytes.
Client connection closed: Slow Consumer (Write Deadline)
```

`/varz` `slow_consumers` 0 → 1, `slow_consumer_stats.clients` 1.

**A6** the `max_pending` branch (`write_deadline: "30s"`, `max_pending: 1MB`, same subscriber):

```
Slow Consumer Detected: MaxPending of 1048576 Exceeded
Client connection closed: Slow Consumer (Pending Bytes)
```

and `/connz?state=closed` → `reason: "Slow Consumer (Pending Bytes)"`. **The client received no
`-ERR`**: it drained 556,002 bytes and read EOF.

**A-varz** on the unmodified config: `max_pending: 67108864`, `write_deadline: 10000000000` — the
documented 64 MB and 10 s, read from the running server. During A1–A4 `slow_consumers` stayed **0**:
a client-side slow consumer is invisible to the server, and the server never "raises" one.

### B — a credential expiring under a live connection

**B1** a user JWT valid 20 s, raw client signing the nonce: at **t+20.01 s** the wire carried
`-ERR 'User Authentication Expired'` and then EOF; the server logged
`Client connection closed: Authentication Expired`.

**B2** the same expiry under `nats sub --creds`: in 45 s the CLI printed **two lines** —
`Subscribing on orders.>` and `>>> Disconnected due to: EOF, will attempt reconnect` — while the
server rejected it **eleven times** (one `-ERR User Authentication Expired`, then ten
`-ERR Authorization Violation`). The CLI never names the reason and never stops.

**B3** nats.go v1.53.1 with `ReconnectWait 500ms`: `ErrorHandler: nats: authentication expired`
while still CONNECTED, then **one** reconnect 0.51 s later that got the *same*
`User Authentication Expired` → abort → **CLOSED after 1 reconnect**.

**B6** the same at nats.go's own default `ReconnectWait` of **2 s**: the first reconnect (t+22.09)
got `Authorization Violation` — a *different* error, so it retried — and the second (t+24.12) got it
again → abort → **CLOSED 4.12 s after expiry, after 2 reconnects**, `LastError =
nats: Authorization Violation`.

**The number of attempts before the abort depends on the reconnect delay**, because the server's
answer changes with time: `jwt/v2`'s check is `now > c.Expires` at one-second resolution
(`claims.go:287`), so a CONNECT landing inside the expiry second is *accepted* and then expired at
once by `setExpiration`'s zero-length timer (`client.go:1344–1353`, `:5980–5985`,
[[s-nats-server-client-errors]]); from the next second the JWT fails validation and the answer is
`Authorization Violation`.

**B4** with `IgnoreAuthErrorAbort()` — the CLI's configuration: still **RECONNECTING after 45 s**,
46 attempts, one rejection every ~0.55 s.

**B5** an **account** JWT valid 25 s, user JWT unexpiring: `-ERR 'Account Authentication Expired'`
at t+25.00, then EOF, closed with the same `Authentication Expired` reason.

**B7** the creds file replaced 1 s after expiry — with an identical, still-expired file, so the
scene shows the window's timing and nothing more: CLOSED at t+19.14 after 2 reconnects.

### C — `handshake_first`, timed

| server `tls { … }` | plain client | `--tlsfirst` client | startup `[WRN]` | `openssl s_client` |
|---|---|---|---|---|
| (none) | works, 0.028 s | **fails**, 0.025 s, `nats: tls error: tls: first record does not look like a TLS handshake` | no | `wrong version number` |
| `handshake_first: true` | **fails**, 2.055 s, `read tcp …: i/o timeout` | works, 0.035 s | **yes** | clean, `Verify return code: 0 (ok)` |
| `handshake_first: "auto"` | works, **0.093 s** (~50 ms fallback) | works, 0.037 s | no | clean |
| `handshake_first: "300ms"` | works, **0.359 s** (~300 ms fallback) | works, 0.027 s | no | — |

The warning
`Clients that are not using "TLS Handshake First" option will fail to connect` appears **only** for
the bare `true`, because it is gated on there being no fallback (`server.go:2805–2812`).
A `--tlsfirst` client against a plain-TLS server fails in **25 ms**, not on a timeout.

## Practical takeaways

- A client-side slow consumer does not disconnect and does not reach the server; a server-side one
  disconnects and never reaches the client. Neither has an error string on the far end.
- Both server branches are worth having in an alert: the log line names which one it was, and
  `/connz?state=closed` keeps the reason.
- An expiring JWT costs one or two reconnect attempts and then a closed connection — seconds, not
  minutes. Do not plan on the retry window catching a rotation.
- `handshake_first: "auto"` is the migration setting: TLS-first clients work, plain clients still
  work, no startup warning, and `openssl s_client` starts behaving.

## Relevance to the wiki

The behavioural authority under [[slow-consumer-in-the-client]],
[[connection-closed-after-auth-error]], the client-side rows of [[slow-consumer-detected]], and the
client half of `handshake_first` on [[tls-in-nats]].

## Questions it answers

180, 181, 182.

## Pages touched

[[slow-consumer-in-the-client]], [[connection-closed-after-auth-error]], [[slow-consumer-detected]],
[[tls-in-nats]], [[client-defaults]], [[nats-go]], [[nats-cli]], [[operator-mode]],
[[monitoring-endpoints]], [[client-connection-lifecycle]]
