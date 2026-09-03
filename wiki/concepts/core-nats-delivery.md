---
title: Core NATS delivery
type: concept
area: [core, clients, monitoring]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-09-03
tags: [at-most-once, interest-graph, ordering, fire-and-forget, echo, NoEcho, max_payload, headers, no_header_support, wire-tap, subsz, nats-trace, reconnect, lame-duck, slow-consumer]
aliases: [core NATS, at-most-once delivery, interest graph, fire and forget, core NATS ordering, message ordering in core NATS, echo, NoEcho, "Maximum Payload Violation", "nats: maximum payload exceeded", debugging delivery, why did my message not arrive]
sources: [s-docs-core-nats-publish-subscribe, s-gh-7577-core-nats-ordering, s-nats-server-core-delivery, s-nats-server-core-delivery-observed, s-docs-core-nats-subjects-and-mapping, s-nats-cli-core-commands, s-nats-server-request-reply, s-nats-server-request-reply-observed, s-docs-core-nats-request-reply, s-docs-core-nats-queue-groups, s-gh-2760-one-connection-or-two, s-relnotes-2.2.0, s-adr-4-message-headers]
created: 2026-09-03
updated: 2026-09-03
---

# Core NATS delivery

**A core publish reaches every subscription whose interest matches at the moment the server processes
it — once, and only then.** Nothing is stored, retried or deduplicated; a publish with no matching
interest is discarded without a word to the publisher. Everything JetStream adds
([[stream]], [[consumer]], [[ack-and-redelivery]]) is a layer on top of this one, and everything on this
page happens before a stream is involved.

## What it is

The server keeps an in-memory **interest graph** — one entry per subscription, added on `SUB` and removed
on unsubscribe or disconnect — and matches each incoming message's subject against it token by token.
Every matching subscription gets its own copy; the publisher holds no list of receivers and receives no
count of them (source: [[s-docs-core-nats-publish-subscribe]]). The addressing rules are on
[[subjects-and-wildcards]].

## How it behaves

**At-most-once.** "A message reaches every interested subscriber that's connected at the moment of
publish, at most once. If a subscriber is offline, restarting, or not subscribed yet, it never sees
that message" (`learn/core-nats.md:16`). No interest is "a silent no-op: no error, no stored backlog";
the publisher cannot tell delivered-to-three from delivered-to-nobody. A subscriber that reconnects has
its subscriptions re-sent by its client, but what was published in the gap is gone
(source: [[s-docs-core-nats-publish-subscribe]]).

**Ordering: per publisher connection, across every subject.** The one public maintainer statement of the
rule is gh#7577: "if a publisher uses a single connection to publish m1, m2, m3 then everyone
subscribing to the subject(s) will see the messages in that order … no matter what subjects the messages
are published on", and the chosen answer, "for a single publish connection order will always be
preserved globally" (source: [[s-gh-7577-core-nats-ordering]]). Two publishers — or one publisher on two
connections — produce two sequences that other subscribers may see interleaved differently; that is the
docs' "doesn't guarantee that two subscribers see messages in the same order under load"
(`publish-subscribe.md:422`), the complement of the rule, not a contradiction. Consequences:

- one connection per producer whose order matters; a connection pool is a set of interleaved streams;
- a queue group hands each message to one member — a random pick, uniform across a cluster, measured on
  [[queue-groups]] (source: [[s-docs-core-nats-queue-groups]]) — so order across members is the members'
  problem ([[worker-pool]] is the durable form of that trade);
- JetStream orders by stream sequence, not by publisher — [[publishing]] — and *that* order is the one a
  consumer replays.

**Fan-out is by subscription, not by connection.** A wildcard subscriber is an ordinary subscriber; a
connection holding `orders.created` and `orders.>` receives two copies of one publish
(source: [[s-docs-core-nats-subjects-and-mapping]]).

**Echo is on.** A connection that both publishes and subscribes on a subject receives its own messages;
`NoEcho` at connect time makes the server skip the originating connection's subscriptions, fixed for the
life of the connection. In the server: `defaultOpts` carries `Echo: true`, the `CONNECT`'s `echo` field
overrides it, and `deliverMsg` skips a subscription owned by the publishing connection when echo is off —
except service-import shadows, which always deliver (`client.go:706`, `:2312`, `:3761–3768`; source:
[[s-nats-server-core-delivery]]).

**`max_payload` is checked twice, and the header block counts.** The server announces the limit in
`INFO` (`"max_payload":1048576`); an official client refuses a larger publish itself — `nats: error: nats:
maximum payload exceeded`, connection kept — and the server is the backstop for a raw writer: `-ERR
'Maximum Payload Violation'`, the log line `maximum payload exceeded: 1048577 vs 1048576`, and **the
connection is closed**. For an `HPUB` the size compared is header plus body: 600,000 header bytes and
500,000 body bytes, each under the limit, are refused together (`client.go:2916–2930`, `:2552–2556`; runs
B1–B5, source: [[s-nats-server-core-delivery-observed]]). The 8 MB warning threshold and the
`max_payload ≤ max_pending` rule are on [[defaults-and-limits]]; the header the server itself adds on a
service import is *not* counted — [[service-import-request-info]].

**Headers are negotiated at connect.** `INFO` carries `headers` (true unless `no_header_support` is set);
against a server without them `nats pub -H` fails client-side with `headers not supported by this
server`, and a `CONNECT` asking for `no_responders` without header support is refused with `-ERR 'no
responders requires headers support'` and closed (runs B6, B7, A5). Keys are case-sensitive and never
folded; `Nats-` is reserved. Headers, `no_responders` and the 503 have been in the server since 2.2.0 —
absent at 2.1.9 (source: [[s-relnotes-2.2.0]]) — framed as ADR-4 specifies: `HDR_LEN` from `NATS/1.0`
through the blank line, `TOT_LEN` header plus body, which is why the two count together against
`max_payload` (source: [[s-adr-4-message-headers]]). Status codes ride the version line — `NATS/1.0 503` with an empty body is the
no-responders signal, since 2.12.0 with a `Nats-Subject` header (`client.go:4506–4516`, run B1; sources: [[s-nats-server-request-reply]], [[s-nats-server-request-reply-observed]], [[s-docs-core-nats-request-reply]]); [[request-reply]] owns it and [[nats-timeout]] triages it.

**A slow subscriber is cut off, alone.** Past the server's pending threshold it "logs `Slow Consumer
Detected`, and closes its connection. The other subscribers are unaffected" (`publish-subscribe.md:576`).
That is the server-side symptom on [[slow-consumer-detected]]; the client-side pending limits — the
drops a client makes *before* the server notices — are step 4's page.

**The connection's part.** A publish returns when the bytes reach the client's write buffer, so a
short-lived publisher must flush (`nc.Flush()`) before it exits or the message never leaves. Through a
disconnect the client owns recovery: it re-dials, replays the handshake, re-sends every subscription,
and buffers *your* publishes ("8 MB by default" in the docs — nats.go's figure, pinned in step 3) while
what *others* publish is lost. Observed with `nats sub --trace` through a restart: `>>> Disconnected due
to: EOF, will attempt reconnect`, `>>> Setting reconnect delay to 725ms`, `>>> Reconnected to
nats://127.0.0.1:14222`; a `nats pub` in the gap fails at once with `nats: error: nats: no servers
available for connection` (run G1). Under `--signal ldm` the server logs `Entering lame duck mode, stop
accepting new clients`, and a single-server client sees only the same EOF disconnect — the CLI prints no
lame-duck line (run G2); the cluster form is on [[upgrade-a-cluster]] and [[how-clients-reach-a-cluster]].

## Debugging delivery: the four surfaces

"I published and nothing arrived" has three causes — nobody subscribed, subscribed to a different
subject, the subscriber's connection had dropped — and a plain publish cannot tell them apart. The docs'
tools, each run on 2.14.6 (source: [[s-docs-core-nats-publish-subscribe]],
[[s-nats-server-core-delivery-observed]]):

| question | surface | what it needs | what you get |
|---|---|---|---|
| did it leave the client, and on which subject? | wire tap: `nats sub ">"` — narrow it to `orders.>` | a client connection; permission to subscribe | one `[#N] Received on "<subject>"` line per message, the reply inbox for requests; a space in a subject shows up as `Received on "orders.us" with reply "created"` |
| who would a publish to *this* subject reach? | `curl 'http://127.0.0.1:8222/subsz?subs=1&acc=$G&test=orders.us.created'` | `nats-server -m 8222`; no credentials | `total` and a `subscriptions_list` of the matching subscriptions (wildcards included) with `subject`, `sid`, `cid`, and `qgroup` for a queue member; `total: 0` and no list when nobody would |
| is the subscriber's connection still open? | `/connz?subs=true` | the monitoring port | each connection's subscriptions; a subscriber absent here has lost its interest with its socket |
| the authoritative route, without side effects | `nats trace orders.us.created` (`--deliver` to also deliver) | **nats-server 2.11 or newer**; a client connection, **no system user** | `--X No active interest`, or one `--C Client "<name>" cid:<n> subject:"orders.>"` line per matching subscriber and an `Egress Count`; the delivered probe carries `Nats-Trace-Dest` and `Accept-Encoding: snappy` and an empty body |

`nats server request subscriptions` and `… connections` read the same state over `$SYS`: on a plain
server with no system user the first fails with `server request failed, ensure the account used has
system privileges and appropriate permissions` while the second answers with your own account's
connections; with a system-account user both answer, one reply per server (runs D5, D6) — the account
mechanics are on [[unauthenticated-clients-still-connect]] and [[system-subjects]]. `acc=$G` scopes
`/subsz` to the global account; even then four `$SYS.REQ.*` service-import subscriptions the server keeps
in every account appear beside yours. If `test=` and `nats trace` both match and the message still did
not arrive, the subscriber was absent at the instant of the publish: at-most-once, not a bug. A trace is
its own message and proves nothing about an earlier publish; a `>` tap on a busy account is itself a
slow-consumer candidate; the monitoring port answers with no authentication ([[monitoring-endpoints]]).

## What configures it

| where | key or field | default at 2.14.6 | change | governs |
|---|---|---|---|---|
| server | `max_payload` | `1048576` (`const.go:94`) | reload | header + body of one message; a violation closes the connection |
| server | `max_control_line` | `4096` (`const.go:90`) | reload | the whole `PUB`/`SUB` line — the only bound on a subject's length |
| server | `max_pending` | 64 MB (`const.go:102`) | restart | the outbound buffer behind *Slow Consumer Detected* |
| server | `no_header_support` | off | restart (no `reload.go` case) | `headers` in `INFO`; disables the 503 too |
| server | `ping_interval` / `ping_max` | `2m` / `2` (`const.go:120,123`) | reload | when an idle peer is declared dead; the client runs its own — step 3 |
| server | `mappings { }` | — | reload (`Reloaded: accounts`) | the subject rewrite before routing — [[subject-transforms]] |
| server | `max_subscription_tokens` | unlimited | **restart** | a token ceiling on *subscriptions* only — [[subjects-and-wildcards]] |
| `CONNECT` | `echo`, `pedantic`, `verbose`, `headers`, `no_responders`, `name` | client-dependent; nats.go leaves `pedantic` false unless its `Pedantic` option is set (pinned from the client source in step 3) | per connection | echo, the publish-subject check, `+OK`s, header support, the 503, the name `/connz` shows |
| CLI | `--connection-name`, `--trace`, `--timeout=5s`, `--inbox-prefix` | — | per command | the name in `/connz`, the `>>>` lifecycle lines, the request wait (source: [[s-nats-cli-core-commands]]) |

Reload behaviour is from [[config-keys]]; the constants from [[defaults-and-limits]].

## Limits and failure modes

- **The publisher never learns of a drop.** Design for it: a request where a reply matters, a stream
  where the message does — [[publishing]] and, for the choice itself, phase G's `core-or-jetstream`.
- **A payload violation is a disconnect**, not a refused message, and every subscription on that
  connection goes with it until the client reconnects.
- **A whitespace subject is routed, wrongly.** The `PUB` line is split on spaces, so `orders.us created`
  arrives as subject `orders.us` with reply subject `created` (run A2). The CLI and most clients refuse it
  first; the docs name nats.py's `publish`, the C client and nats.go before v1.48.0 as the ones that do
  not — [[subjects-and-wildcards]].
- **Pedantic mode is advisory.** A `pedantic` connection publishing to a wildcard gets `-ERR 'Invalid
  Publish Subject'` and the message is delivered anyway (run C3; `inbox/server-issues.md` SI-7).
- **A single connection is one FIFO.** A slow subscription and a fast one on the same connection share
  the socket and the client's read loop. The maintainers' rule (gh#2760): start with one connection;
  head-of-line blocking is "mostly from the system to your app (subscriptions)", so move a
  latency-sensitive subscription to a second connection only when a heavy one delays it — publishing
  needs no connection of its own (source: [[s-gh-2760-one-connection-or-two]]; the requester's side is
  on [[request-reply]]).

## To verify

- What a route or leafnode hop does to a publisher's order. gh#7577 is a single-server thread and the
  chapter is silent; the mechanism — one inbound connection processed in order, one outbound route
  connection written in order — suggests the FIFO survives a hop **(unverified)**.
- The reconnect buffer's size and overflow error, from nats.go at v1.53.1 rather than the docs' "8 MB"
  — step 3 of `inbox/plan-the-client-side-2026-09-03.md`.

## Related

[[subjects-and-wildcards]] · [[publishing]] · [[nats-timeout]] · [[slow-consumer-detected]] ·
[[monitoring-endpoints]] · [[defaults-and-limits]] · [[config-keys]] · [[subject-transforms]] ·
[[worker-pool]] · [[how-clients-reach-a-cluster]] · [[upgrade-a-cluster]] ·
[[unauthenticated-clients-still-connect]] · [[system-subjects]] · [[service-import-request-info]] ·
[[nats-cli]] · [[nats-server-2.11]]

## Sources

- [[s-docs-core-nats-publish-subscribe]] — the chapter's index, connecting, publish-subscribe, headers,
  connection lifecycle and debugging pages, with the primers folded.
- [[s-gh-7577-core-nats-ordering]] — the ordering rule, in the maintainers' words.
- [[s-nats-server-core-delivery]] — echo, the two `PUB` parsers, `max_payload` over header plus body,
  the header negotiation, the 503, `/subsz`, at v2.14.6 with lines.
- [[s-nats-server-core-delivery-observed]] — runs A–G on the binary: the misroute, the violations, the
  four surfaces, the restart and the lame duck.
- [[s-docs-core-nats-subjects-and-mapping]] — wildcard subscribers as ordinary subscribers.
- [[s-nats-cli-core-commands]] — the CLI flags and defaults quoted above.
- [[s-nats-server-request-reply]] · [[s-nats-server-request-reply-observed]] — the 503 with `Nats-Subject`, read
  and run.
- [[s-docs-core-nats-request-reply]] · [[s-docs-core-nats-queue-groups]] — the request/reply and queue-group
  pages of the chapter, for the two pointer sentences above.
- [[s-gh-2760-one-connection-or-two]] — one connection or two, the maintainers' rule.
- [[s-relnotes-2.2.0]] — headers and the 503 since 2.2.0. [[s-adr-4-message-headers]] — the framing.
