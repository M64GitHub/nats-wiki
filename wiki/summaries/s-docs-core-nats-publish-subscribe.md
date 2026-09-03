---
title: "docs — Core NATS: connecting, publish-subscribe, headers, connection lifecycle, debugging delivery"
type: summary
area: [core, clients, monitoring]
source-url: https://docs.nats.io/learn/core-nats.md
source-path: raw/nats-docs/learn/core-nats/publish-subscribe.md
author: nats-io docs
article: "learn/core-nats.md (index), learn/core-nats/connecting.md, publish-subscribe.md, headers.md, connection-lifecycle.md, debugging-delivery.md, where-next.md; concepts/pub-sub-basics.md, what-is-nats.md and intro.md read and folded"
date: 2026-08-31
version: ""
tags: [core-nats, at-most-once, interest-graph, echo, max_payload, headers, NATS/1.0 503, reconnect, reconnect-buffer, lame-duck, wire-tap, subsz, nats-trace, connection-name, ping-pong]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# docs — Core NATS: connecting, publish-subscribe, headers, connection lifecycle, debugging delivery

Seven pages of the *Core NATS deep dive* — everything on the chapter's spine that is not subjects,
mapping, request/reply or queue groups ([[s-docs-core-nats-subjects-and-mapping]] and step 2 hold
those) — read as one article: what a core publish promises, what the connection does around it, and
the three tools that show why a message never arrived. **Unversioned by design** ("This chapter is
unversioned and concept-first", `where-next.md:30`); the only version on any page is `"version":"2.14.0"`
in a sample `INFO` line (`connecting.md:59`). Server facts are pinned by
[[s-nats-server-core-delivery]] and [[s-nats-server-core-delivery-observed]] at v2.14.6.

## Key claims

### The promise (`core-nats.md`, `publish-subscribe.md`)

- "**core NATS is at-most-once**. A message reaches every interested subscriber that's connected at
  the moment of publish, at most once. If a subscriber is offline, restarting, or not subscribed yet, it
  never sees that message. The server does not store it for later." (`core-nats.md:16`)
- A publish is **fire-and-forget**: it "doesn't wait for a subscriber, and it doesn't tell you how many
  subscribers received the message, or whether any did" (`publish-subscribe.md:166`). A publisher
  "always names a fully-qualified subject" (L168).
- Every subscriber gets **its own copy**; "subscribing isn't taking from a queue" (L314). Unsubscribe
  takes effect "as soon as it processes the request" (L320); **auto-unsubscribe** ends a subscription
  after N messages server-side (`AutoUnsubscribe(N)` in Go; `nats sub --count N` counts client-side,
  L322).
- The **interest graph** is in memory; one publish to three subscribers is three deliveries, resolved
  "at the moment the message arrives" (L398–410). **No interest → dropped**, "a silent no-op: no error,
  no stored backlog" — the publisher cannot tell delivered-to-three from delivered-to-nobody (L414–416).
- Core NATS "doesn't retry a missed message, doesn't detect or suppress duplicates, and doesn't guarantee
  that two subscribers see messages in the same order under load" (L422) — the complement of the
  per-publisher order [[s-gh-7577-core-nats-ordering]] states.
- **`max_payload`**: 1 MB, `1048576` bytes, announced in `INFO` (L428). An official client fails first
  with `nats: maximum payload exceeded` and keeps the connection; the server "is the backstop" and
  replies `-ERR 'Maximum Payload Violation'` and **closes the connection** (L430). The 2 MB demo
  `head -c 2000000 /dev/zero | tr '\0' x | nats pub orders.created --force-stdin` (L493) — reproduced
  (run B1); the server's half reproduced with a raw `PUB` (run B2). `nats account info` shows the
  ceiling (L477).
- Pitfalls: exiting before the write buffer is flushed loses the publish — `nc.Flush()` before
  `nc.Close()` (L564–572); echo (L574); "**A slow subscriber gets cut off**": past a threshold the server
  "logs `Slow Consumer Detected`, and closes its connection. The other subscribers are unaffected"
  (L576) — the server side is [[slow-consumer-detected]].

### The connection (`connecting.md`)

- One long-lived TCP connection carries every publish and subscription, multiplexed (L16–20); the
  default URL is `nats://127.0.0.1:4222`; `tls://`, `ws://`, `wss://` name the transport (L24–26).
- The handshake: the server sends `INFO` first — `max_payload`, `headers` — and the client answers
  `CONNECT` (L34). Any raw TCP tool sees the `INFO` line (`nc localhost 4222`, L51) — run A1.
- **Name the connection**: `--connection-name` on every `nats` command; unnamed CLI connections show as
  `NATS CLI Version …` (L140–142; `nats rtt --connection-name warehouse`, L161). The name surfaces in
  `nats server report connections` — which "answers fully once you connect with system-account
  credentials" — and on the monitoring port (L230).
- **Echo is on by default**: a connection receives its own messages; `NoEcho` at connect time is "fixed
  for the life of the connection" (L234–236). Server: `defaultOpts` has `Echo: true`.
- **PING/PONG**: "a PING every two minutes, and the connection is declared dead after two unanswered
  PINGs", the same on both sides (L242) — matches `DEFAULT_PING_INTERVAL = 2m`, `DEFAULT_PING_MAX_OUT = 2`.
- Pitfalls (L250–254): a connection per message; echo; exiting before buffered publishes are sent.

### Headers (`headers.md`)

- Text that looks like HTTP: `NATS/1.0` then `Key: Value` lines; a key may repeat; **keys are
  case-sensitive and never folded** (L10–22); the block travels separately from the body (L24).
- `nats pub -H 'Key:Value'` (repeatable); `nats sub` prints headers above the body; `--headers-only`
  skips bodies (L28, L100, L129). `Content-Type` is the common one; **`Nats-` is reserved** (L198).
- `nats reply --echo` copies request headers onto the reply and adds a `NATS-Reply-Counter` (L223–231).
- **Status codes ride the version line**: `NATS/1.0 503` with no payload is the no-responders signal
  (L314–316). Support is negotiated at connect: the `INFO` `headers` field, on by default, and the
  client's `CONNECT` (L320). With `no_header_support` set on the server a publish with a header fails
  client-side with `headers not supported by this server` (L322) — run B6: `nats: error: nats: headers
  not supported by this server`; and no-responders cannot be received without headers (L324).
- **"Headers count against the payload limit"**: the server "checks the combined size of the header
  block and the body against `max_payload`" (L368) — run B4: 600,000 + 500,000 bytes refused with
  `maximum payload exceeded: 1100000 vs 1048576`.

### The connection lifecycle (`connection-lifecycle.md`)

- **The client owns reconnection**: it re-dials, replays the handshake and re-sends every subscription,
  because "the server keeps no per-client memory" (L12–14). Publishes made while disconnected go to a
  **reconnect buffer**, "8 MB by default", and an overflowing publish "returns an error" (L18 — the
  figure is nats.go's `DefaultReconnectBufSize`, pinned in step 3); messages others publish meanwhile
  "are gone, and no buffer on your side can change that" (L20).
- States CONNECTED → RECONNECTING → CONNECTED → CLOSED; the disconnect, reconnect and closed handlers,
  and the **async error handler** without which "those errors are invisible" (L26–36).
- **Force reconnect** (`Conn.ForceReconnect()` in nats.go) runs the same path deliberately — to spread
  clients onto a new server or leave one before it goes down (L42–46).
- **Lame duck**: the server "stops accepting new connections, announces to every connected client that
  it's about to go away, and then closes the existing ones gradually"; a client watching the notice can
  move first (L50–52). `nats-server --signal ldm`; the log line `[INF] Entering lame duck mode, stop
  accepting new clients` (L73, L81) — run G2 reproduced the line; with one client the server exited a
  second later, and the CLI printed **no** lame-duck line, only its disconnect.
- The demo (L181–201): `nats sub orders.created`, restart the server → `>>> Disconnected due to: EOF,
  will attempt reconnect`; with `--trace`, `>>> Reconnected to nats://127.0.0.1:4222 (127.0.0.1:4222)`;
  "Publishing WHILE the server is down fails instead" — run G1 reproduced all three (the gap publish:
  `nats: error: nats: no servers available for connection`).
- Pitfalls (L268–272): the reconnect buffer is client memory, not durability; do no real work inside a
  callback; infinite reconnect hides a wrong address or refused auth — log every failed attempt.

### Debugging delivery (`debugging-delivery.md`)

- Three causes of "published, nothing arrived": nobody subscribed, subscribed to a different subject, the
  subscriber's connection had dropped (L6–8). A plain publish cannot tell them apart.
- **Wire tap**: `nats sub ">"` (narrow it: `nats sub "orders.>"`) prints the literal subject and, for
  requests, the reply inbox (L14–71); a `>` tap on a busy account "gets cut off as a slow consumer" (L76).
- **`/subsz`** on `nats-server -m 8222`: `subs=1` adds `subscriptions_list` (account, subject, `cid`);
  `acc=$G` scopes the counts; "a few `$SYS.REQ.*` service subscriptions the server keeps in every
  account show up"; **`test=<subject>`** returns only the subscriptions a publish to that literal subject
  would match, wildcards included — an empty list means the message would be dropped (L107–154).
  `/connz?subs=true` tells a missing subscription from a cut connection (L131, L158). All reproduced
  (runs D1–D4: four `$SYS.REQ.*` entries, `qgroup` on a queue subscription, `total: 0` with nobody).
- `nats server request subscriptions` and `… connections` ride `$SYS`; on a plain server the first
  fails with `server request failed, ensure the account used has system privileges and appropriate
  permissions` and the second answers "only with your own account's connections" (L160) — run D5 exact;
  run D6 shows both answering per node with a system user.
- **`nats trace <subject>`** "needs NATS Server 2.11 or newer"; without `--deliver` the traced message
  is **not** handed to subscribers (L164–216). The sample output — `--X No active interest`, the legend,
  a `--C` line per matching subscriber — reproduced (runs E1–E3); with `--deliver` the subscriber received
  the message carrying `Nats-Trace-Dest` and `Accept-Encoding: snappy`.
- The symptom → tool table (L222–227) and the last resort: if `test=` and `nats trace` both match but the
  message did not arrive, the subscriber "was absent at the instant you published" (L229). Pitfalls: a
  `>` tap on production; a trace proves nothing about an earlier publish; the monitoring port answers
  without authentication (L233–237).

### `where-next.md`

The four ideas — subject, interest, reply subject, queue group (L12–20); "Core NATS does not store
messages" (L24); the **production checklist** (L52–144) collapses every pitfall above into one list.

### The primers, folded

`concepts/pub-sub-basics.md` restates the at-most-once, active-subscribers-only, copy-per-subscriber and
1 MB points in eight languages and adds nothing the learn page lacks; `concepts/what-is-nats.md` is the
overview (its "typically ~15MB" memory footprint is unsourced marketing, not recorded); `concepts/intro.md`
is navigation.

## Practical takeaways

- Two counters answer "did it deliver": `/subsz?subs=1&acc=$G&test=<subject>` before the publish, and
  a `>` tap while it happens. `nats trace` answers "who *would* get it now", nothing about the past.
- Budget headers into `max_payload`; the server compares header plus body, and it closes the connection
  on a violation rather than just refusing the message.
- Name every long-lived connection; the monitoring port and `/connz` are otherwise a list of numbers.

## Notable quotes

- "A publish with no interest is a silent no-op: no error, no stored backlog." (`publish-subscribe.md:416`)
- "The client owns reconnection." (`connection-lifecycle.md:9`)

## Relevance to the wiki

The docs' whole statement of what a core publish promises and what the connection does around it —
the material [[core-nats-delivery]] rests on, and the four debugging surfaces no reader page had.

## Questions it answers

25 (with [[s-gh-7577-core-nats-ordering]]), 171.

## Pages touched

[[core-nats-delivery]] · [[subjects-and-wildcards]] · [[monitoring-endpoints]] · [[slow-consumer-detected]] ·
[[nats-cli]] · [[nats-server-2.11]] · [[unauthenticated-clients-still-connect]] · [[defaults-and-limits]] ·
[[config-keys]] · [[publishing]]
