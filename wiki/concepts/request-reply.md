---
title: Request-reply
type: concept
area: [core, clients]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; the 503 is 2.2.0, its Nats-Subject header 2.12.0
verified-against: nats-server 2.14.6
verified-on: 2026-09-03
tags: [request-reply, inbox, _INBOX, inbox-prefix, timeout, no-responders, 503, Nats-Subject, scatter-gather, request-many, replies, reply-timeout, wait-for-empty, NATS-RPLY-22, service-import, head-of-line]
aliases: [request/reply, request reply, request-response, inbox, _INBOX, reply subject, reply inbox, "no responders", "No responders are available", "NATS/1.0 503", "nats: no responders available for request", scatter-gather, scatter gather, request many, RequestMany, requestMany, RequestManyAsync, --replies, --inbox-prefix, CustomInboxPrefix, "nats request", "nats reply"]
sources: [s-docs-core-nats-request-reply, s-nats-server-request-reply, s-nats-server-request-reply-observed, s-nats-cli-request-reply-source, s-adr-4-message-headers, s-adr-47-request-many, s-relnotes-2.2.0, s-gh-2760-one-connection-or-two, s-docs-core-nats-queue-groups, s-nats-cli-core-commands, s-relnotes-2.12, s-relnotes-2.10, s-nats-server-core-delivery]
created: 2026-09-03
updated: 2026-09-03
---

# Request-reply

**A request is a publish that carries a private reply subject, and a reply is a publish to it.** The
client subscribes to a subject nobody else knows, sends the request with that subject in the reply
field, and waits — for the first reply, for its own deadline, or for the server's `503` saying nobody
could have answered. Everything on this page sits on [[core-nats-delivery]]: no retry, no storage,
first reply wins.

## What it is

Request-reply "isn't a new protocol; it's the pub/sub you already know, used twice" (source:
[[s-docs-core-nats-request-reply]]). The reply subject is an **inbox** under `_INBOX.`, and a client
does not open a subscription per request: on its first request it subscribes once to
`_INBOX.<nuid>.*` — the *mux* — and every later request adds only its own last token, so "thousands
of concurrent requests cost one subscription, not thousands". The `nats` CLI does exactly this
(`nc.NewRespInbox()` and a sync subscription on it, `req_command.go:113–121`; source:
[[s-nats-cli-request-reply-source]]); a client can be told to fall back to one subscription per
request instead (nats.go's `UseOldRequestStyle`, the docs' "clients can be configured").

The prefix is a connection option — `--inbox-prefix` in the CLI, `CustomInboxPrefix` in nats.go —
and it exists for permissions: a requester needs *publish* on the request subject and *subscribe* on
its inbox prefix, so an operator can give each application its own prefix instead of a shared
`_INBOX.>` ([[subject-permissions]] has the allow-list and the silent failure when the inbox
subscription is denied). The whole line — subject plus reply subject — is bounded by
`max_control_line`, 4 KB by default ([[subjects-and-wildcards]]).

## How it behaves

### The three outcomes

| outcome | who decides | when | what the client sees | the `nats` CLI (0.4.0) |
|---|---|---|---|---|
| **a reply** | a responder | first reply to arrive | the message; later replies are discarded silently | prints it, **exit 0** |
| **a timeout** | the client, on its own deadline | no reply within the deadline | Go `nats.ErrTimeout`, JavaScript `TimeoutError`, Python `TimeoutError`, Rust `TimedOut`, C `NATS_TIMEOUT` | prints **nothing** after `Sending request on "…"`, **exit 0** (run B7) |
| **no responders** | the server, at once | nothing was subscribed to the subject when the request arrived | Go `nats.ErrNoResponders`, JavaScript `RequestError.isNoResponders()`, Python `NoRespondersError`, Rust `RequestErrorKind::NoResponders`, .NET `NatsNoRespondersException`, C `NATS_NO_RESPONDERS`; **Java only with `reportNoResponders()`**, otherwise a timeout | `No responders are available` in ~37 ms, **exit 0** (run B6) |

The client names are the docs' (source: [[s-docs-core-nats-request-reply]]); the CLI's lines and exit
codes were run (source: [[s-nats-server-request-reply-observed]]). A timeout says the answer did not
arrive in time, "not *why*"; no responders says the service is not deployed. They are different
problems and deserve different branches — the triage of the first is [[nats-timeout]]. **One exit
code for all three outcomes, and the timeout is silent**, so a script must read the output rather
than `$?` (`inbox/docs-issues.md` #89).

### The 503, exactly

The server sends the no-responders reply only when **all four** hold (`client.go:4506–4516`; source:
[[s-nats-server-request-reply]]): nothing took the message — no plain subscriber, no queue member,
no route, leaf or gateway; the publish carried a reply subject; the connection's `CONNECT` asked for
`no_responders`; and **the requesting connection itself holds a plain subscription matching that
reply subject** (`subForReply`). On the wire it is a header-only message (source:
[[s-adr-4-message-headers]] for the framing, run B1 for the bytes):

```
HMSG _INBOX.x 1 38 38
NATS/1.0 503
Nats-Subject: nobody

```

Header length equals total length — no body — and 38 is 32 bytes plus the subject. Consequences,
each run on 2.14.6:

- `no_responders` needs `headers` in the same `CONNECT`; without it the server answers `-ERR 'no
  responders requires headers support'` **and closes the connection** (run B3; `client.go:2454–2470`,
  source: [[s-nats-server-core-delivery]]). A server with `no_header_support: true` therefore has no
  503 at all ([[core-nats-delivery]]).
- A subscriber that exists but never answers is **not** a 503; it is a timeout (run B5).
- A request whose inbox is subscribed on *another* connection gets no 503 (run B4): the mux
  subscription and the publish must share the connection.
- **Since 2.2.0** — headers, `HPUB`/`HMSG`, `no_responders` and the 503 are in the server at that tag
  and absent at 2.1.9 (source: [[s-relnotes-2.2.0]]); the **`Nats-Subject` header is since 2.12.0**
  (#5250, source: [[s-relnotes-2.12]]) — a 2.2.0–2.11 server sends `NATS/1.0 503` alone. The header
  is stated nowhere in the docs (`inbox/docs-issues.md` #85).

### Timeouts

No client supplies a default deadline for a request; "you pass the timeout on every `request()`
call" (source: [[s-docs-core-nats-request-reply]]). The CLI's is `--timeout=5s` (source:
[[s-nats-cli-core-commands]]). Size it to the responder's work plus the round trip; when it expires
the client returns its error and the server will not deliver the answer late — a reply that arrives
after the deadline lands on a mux subscription with nobody waiting for its token and is dropped.

### Scatter-gather: every responder answers

Nothing in the mechanism limits the number of responders. Three plain subscribers on `shipping.quote`
all receive the request and all reply to the same inbox; the single reply of a plain `request()` "was
just one responder plus a client that stopped after the first answer". Two rules (source:
[[s-docs-core-nats-request-reply]]):

- **the responders must not share a queue group** — a group hands each request to one member
  ([[queue-groups]]). The CLI trap: `nats reply` joins the group `NATS-RPLY-22` by default, so three
  of them answer once between them; give each its own `--queue` name, because "a queue group of one
  member behaves like a plain subscriber" (run A: two groups, two replies; a third member in the
  default group, still two);
- **the requester must ask for more than one reply.** ADR-47 names the four stop conditions — a
  *total timeout* (always), a *stall* gap, a *max messages* count, a *sentinel* (the standard one is an
  empty payload) — and says a 503 in place of a reply is terminal (source: [[s-adr-47-request-many]]).
  The CLI's flags are those conditions, measured against three responders and two (run D; source:
  [[s-nats-server-request-reply-observed]], [[s-nats-cli-request-reply-source]]):

| flags | stops when | measured on 2.14.6 |
|---|---|---|
| `--replies 1` (default) | the first reply | 1 reply in 34 ms; the rest discarded |
| `--replies 3 --timeout 2s` | 3 replies, or the gap since the last exceeds the average reply time plus `--reply-timeout` (300 ms) | 3 replies in 41 ms; with one responder gone, 2 replies in 364 ms; `--reply-timeout 1s` → 1.06 s |
| `--replies 0 --timeout 2s` | the whole `--timeout` window; `--reply-timeout` is not read | 3 replies, returned after 2.06 s; 2 replies, still 2.04 s; nobody subscribed → no responders in 38 ms |
| `--wait-for-empty --timeout 2s` | a reply with an empty body, or the gap | the two quotes then `nil body` at 212 ms, returned at 250 ms |
| `--replies 5 --timeout 2s` with an empty reply among them | **the same** — an empty reply ends any counted gather (`req_command.go:179–181`) | identical to the row above; `--replies 2` took the first two and never saw the empty one |

Gather by count only when the responder count is fixed; by deadline when it is not — a missing
responder then leaves its answer out of the set instead of blocking the read. Helpers that implement
ADR-47 exist in nats.js (`requestMany`), orbit.go (`RequestMany`) and the .NET client
(`RequestManyAsync`); elsewhere the loop is written by hand — subscribe to a fresh inbox, publish with
it as the reply, read until the count or the deadline. Replies are at-most-once and their arrival
order "carries no meaning".

### Across an account import

A request over a service import that finds no interest in the exporting account is answered with a
503 **since 2.10.26** (#6532, "instead of silently dropping the message"; source: [[s-relnotes-2.10]]).
Run G on 2.14.6: account `APP` importing `svc.check` from `SVC` with nobody subscribed in `SVC` got
`No responders are available` in 37 ms; on the wire the header read `Nats-Subject: svc.check`, and
with the import renamed `to: inv.stock` it read **`Nats-Subject: inv.stock`** — the subject the
requester published, not the exporter's. The other reasons a cross-account request fails, and how
they differ, are on [[cross-account-sharing]] and [[account]].

### Responders

`nats reply` is one queue subscription in `NATS-RPLY-22` whose callback runs one request at a time:
`--sleep` (random, up to the value) and `--command` (run synchronously, its output the reply body)
hold every later request on that member (source: [[s-nats-cli-request-reply-source]]). The docs'
pitfall follows: "a responder that runs a slow lookup before replying serializes every request
behind it" — keep the reply path fast or run several responders in a [[queue-groups|queue group]],
and read there what a busy member does to the share it keeps receiving. A service layer with named
endpoints, discovery and stats is the *services framework*, a client-library convention on top of
these two primitives; it gets its own page later in this plan.

### One connection or two

A single connection is one socket and one read loop, so a heavy subscription delays a
latency-sensitive one on the same connection; publishing is not the bottleneck. The maintainers'
advice on gh#2760: "start with one connection … if you have multiple subscriptions and might
encounter latency sensitive processing that could be affected by head of line blocking, then move
subscriptions across multiple connections" (source: [[s-gh-2760-one-connection-or-two]]). A
requester's mux subscription is one more subscription on that loop — a reply queued behind a bulk
subscription's backlog counts against the request's deadline.

## What configures it

| where | key, flag or field | default | governs |
|---|---|---|---|
| server | `no_header_support` | off | headers in `INFO`; on, there is no 503 (restart) |
| server | `max_control_line` | `4096` | subject plus reply subject on one `PUB` line |
| server | `max_payload` | `1048576` | a reply is a publish: the same ceiling, header plus body |
| `CONNECT` | `headers`, `no_responders` | client-dependent; the CLI and nats.go send both | whether the 503 is sent, and whether the connection survives asking for it |
| client | the timeout, per call | none | the deadline; nats.go `Request(subj, data, timeout)` |
| client | `--inbox-prefix` / `CustomInboxPrefix` | `_INBOX` | the reply-subject namespace a permission set must allow on subscribe |
| client | one-subscription-per-request mode | off (the mux is the default) | nats.go `UseOldRequestStyle` |
| CLI | `nats request --timeout=5s --replies=1 --reply-timeout=300ms [--wait-for-empty] [--count=N] [-H k:v] [--raw]` | as shown | the gather (source: [[s-nats-cli-core-commands]]) |
| CLI | `nats reply --queue=NATS-RPLY-22 [--echo] [--command=…] [--sleep=MAX] [--count=N]` | as shown | the responder; `--echo` copies the request's headers and adds `NATS-Reply-Counter` |
| permissions | publish on the subject, subscribe on the inbox prefix | — | a denied inbox subscription fails silently — [[subject-permissions]] |

Server defaults from [[defaults-and-limits]].

## Limits and failure modes

- **First reply wins, silently.** Two responders outside a queue group answer twice; a plain request
  keeps one and the requester never learns of the other. Put responders in a group, or gather.
- **The 503 has preconditions.** Headers and `no_responders` in `CONNECT`, the inbox subscribed on
  the requesting connection, no interest of any kind — a plain subscriber that never answers, a queue
  member that crashed after delivery, a gateway with far-side interest: all timeouts.
- **Java times out where every other client reports no responders**, unless `reportNoResponders()`
  is set ([[nats-java]]).
- **A timed-out `nats request` looks like a served one to a script**: exit 0, no output.
- **A denied inbox is a timeout.** A subscribe permission that omits the requester's prefix drops
  the reply with nothing but a server-side `Subscription Violation` log line ([[subject-permissions]]).
- **A counted gather ends on any empty reply**, flag or no flag; a responder that legitimately
  answers an empty body cuts a `--replies N` short.
- **Replies are at-most-once** and share `max_payload`; a reply the responder cannot deliver (a
  disconnected requester, a too-large body) is gone, and the responder is not told.

## Related

[[core-nats-delivery]] · [[queue-groups]] · [[nats-timeout]] · [[subject-permissions]] ·
[[cross-account-sharing]] · [[service-import-request-info]] · [[account]] · [[subjects-and-wildcards]] ·
[[worker-pool]] · [[defaults-and-limits]] · [[nats-cli]] · [[nats-java]] · [[orbit]] · [[nats-js]] ·
[[nats-net]] · [[nats-server-2.12]]

## Sources

- [[s-docs-core-nats-request-reply]] — the inbox, the three outcomes with each client's name, the
  gather flags and the two rules of scatter-gather, the responder pitfall.
- [[s-nats-server-request-reply]] — the four conditions of the 503 and its bytes at v2.14.6.
- [[s-nats-server-request-reply-observed]] — runs A, B, D, F and G: the bytes, the exit codes, the
  gather timings, the import.
- [[s-nats-cli-request-reply-source]] — why the CLI gathers, ends and exits as it does, at 0.4.0.
- [[s-adr-4-message-headers]] — the header framing, header length equal to total length.
- [[s-adr-47-request-many]] — the four stop conditions and the terminal 503.
- [[s-relnotes-2.2.0]] — headers, `no_responders` and the 503 dated from the source at the tag.
- [[s-gh-2760-one-connection-or-two]] — head-of-line blocking and when to split subscriptions.
- [[s-docs-core-nats-queue-groups]] — a queue group of one behaves like a plain subscriber.
- [[s-nats-cli-core-commands]] — the flags and defaults of `nats request` and `nats reply`.
- [[s-relnotes-2.12]] — `Nats-Subject` on the 503 (#5250).
- [[s-relnotes-2.10]] — no responders over a service import (2.10.26, #6532).
- [[s-nats-server-core-delivery]] — the `CONNECT` check that closes a connection asking for
  `no_responders` without headers.
