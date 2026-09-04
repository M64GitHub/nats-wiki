---
title: "docs — reference/protocols and reference/protocols/client: the client wire protocol"
type: summary
area: [core, clients, interop]
source-url: https://docs.nats.io/reference/protocols/client.md
source-path: raw/nats-docs/reference/protocols/client.md
author: NATS documentation
article: "reference/protocols.md (the four-page index, folded in here) and reference/protocols/client.md, fetched 2026-08-31, swept against nats-server v2.14.6"
date: 2026-08-31
version: "1.2.0 in both examples; no server version is stated for any claim"
tags: [wire-protocol, INFO, CONNECT, PUB, SUB, MSG, HPUB, HMSG, PING, PONG, -ERR, +OK]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# docs — `reference/protocols` and `reference/protocols/client`: the client wire protocol

The reference tree's account of the protocol a client speaks: twelve verbs, the `INFO` and `CONNECT`
field tables, and a fifteen-row `-ERR` table with a `Recoverable` column. Read for step 5 of
`inbox/plan-the-client-side-2026-09-03.md` and swept, field by field and string by string, against
`nats-server` v2.14.6 ([[s-nats-server-wire-protocol]]).

`reference/protocols.md` (the index, 64 lines) is folded in here: it is four paragraphs of
description plus a *Protocol Selection* table (client / route / leafnode / gateway against a use
case) and a *Common Protocol Features* list. It states no version, no field and no value, and adds
nothing the four child pages do not say.

## Key claims

**The transport.** "The default transport is a TCP/IP socket, however WebSockets are supported as
well as a UNIX domain socket if the server is embedded within a Go process" (`:4`).

**Case insensitivity.** "NATS protocol operation names are case insensitive, thus `SUB foo 1␍␊` and
`sub foo 1␍␊` are equivalent" (`:8`). **Confirmed on the binary** — `connect`, `sub`, `pub` and
`ping` all work (run B17).

**The twelve verbs**, with `INFO`, `MSG`, `HMSG`, `+OK` and `-ERR` sent by the server, `CONNECT`,
`PUB`, `HPUB`, `SUB`, `UNSUB` by the client, and `PING` / `PONG` by both (`:10–23`). Every syntax
line and every example was checked and holds:

```
PUB <subject> [reply-to] <#bytes>␍␊[payload]␍␊
HPUB <subject> [reply-to] <#header bytes> <#total bytes>␍␊[headers]␍␊␍␊[payload]␍␊
SUB <subject> [queue group] <sid>␍␊
UNSUB <sid> [max_msgs]␍␊
MSG <subject> <sid> [reply-to] <#bytes>␍␊[payload]␍␊
HMSG <subject> <sid> [reply-to] <#header bytes> <#total bytes>␍␊[headers]␍␊␍␊[payload]␍␊
```

**`INFO` can arrive at any time.** "When using the updated client protocol … `INFO` messages can be
sent anytime by the server. This means clients with that protocol level need to be able to
asynchronously handle `INFO` messages" (`:31`).

**`connect_urls` is topology gossip.** "When a NATS server cluster expands, an `INFO` message is sent
to the client with an updated `connect_urls` list" (`:73`), formatted `"connect_urls":["10.0.0.184:4333", …]`.

**PING/PONG uses traffic as a proxy.** "The server uses normal traffic as a ping/pong proxy, so a
client that has messages flowing may not receive a ping from the server" (`:363`). **Confirmed in the
source** — but only for `CLIENT`: `processPingTimer` sends unconditionally for `ROUTER`, `GATEWAY` and
a spoke `LEAF` (`client.go:5846–5857`).

**`+OK` is the default.** "When the `verbose` connection option is set to `true` (the default value),
the server acknowledges each well-formed protocol message" (`:399`). **Confirmed** — and it is the one
place the page is right where the intuition is wrong: `CONNECT {}` gets a `+OK`, because
`defaultOpts` is `{Verbose: true, Pedantic: true, Echo: true}` (`client.go:706`, run B2).

## What the sweep found

Sixteen findings, recorded as `inbox/docs-issues.md` #102–#107. Grouped:

**Three wrong defaults on one table** (`:424`, `:426`, `:431`):

| the page | the server at v2.14.6 |
|---|---|
| `Authorization Timeout … (default 1 second)` | `AUTH_TIMEOUT = 2 * time.Second` (`const.go:117`) — and the string is `Authentication Timeout` |
| `max_control_line … The default is 1024 bytes` | `MAX_CONTROL_LINE_SIZE = 4096` (`const.go:90`) |
| `Slow Consumer … (default 10MB)` | `MAX_PENDING_SIZE = 64 MB` (`const.go:102`) — and no `-ERR` is ever sent |

**Four of the fifteen `-ERR` strings are not what the server sends.** `Authorization Timeout` →
`Authentication Timeout`; `Maximum Connections Exceeded` → `maximum connections exceeded`;
`Attempted To Connect To Route Port` → `attempted to connect to route port`; `Invalid Client
Protocol` → `invalid client protocol`. The Title Case forms come from `errors.go`'s *identifier*
names, not from the wire — every string derived from an `errors.New(…)` is lowercase, every string
written as a literal at the call site is Title Case. **`Maximum Control Line Exceeded`** and
**`Parser Error`** are `ClosedState` names (`monitor.go:2650`, `:2639`), not wire strings; the wire
gives `maximum control line exceeded` and `Unknown Protocol Operation`. **`Secure Connection - TLS
Required`** is composed (`server.go:3684`) and then discarded, because `TLSHandshakeError` is in
`markConnAsClosed`'s skip-flush set.

**The `Recoverable` column is wrong three ways.** Observed (run C): `Invalid Subject` — Yes, correct;
`Permissions Violation …` — Yes, correct; but `Invalid Publish Subject` (not on the table at all) and
**`maximum subscriptions exceeded`** (also not on the table) are both recoverable, and the connection
keeps delivering afterwards.

**Six INFO fields a 2.14.6 client is sent are on no row**: `cluster_dynamic`, `compression`,
`connect_info`, `acc_is_sys`, `api_lvl`, `xkey`. The last two are on the **default** INFO of a
standalone server (run A1). **`client_id` is listed twice**, at `:52` as `uint64` ("The internal
client identifier in the server") and at `:63` as `string` ("The ID of the client"); the struct has
one field, `CID uint64` (`server.go:125`).

**`Required: true` has no counterpart in the server.** The page marks `verbose`, `pedantic`,
`tls_required`, `lang` and `version` required; `CONNECT {}` is accepted, and the CONNECT that fails is
one whose JSON does not parse — which gets **no** `-ERR` at all (run B9). Five CONNECT fields the
server accepts are undocumented (`account`, `new_account`, `import`, `export`, `remote_account`), and
`account` / `new_account` are now an **error**: "we used to have this as an optional feature for
dynamic sandbox environments. Now its considered an error" (`client.go:2387–2392`).

**The ping values are never stated.** The page describes the mechanism at `:359–363` and gives no
number; `DEFAULT_PING_INTERVAL = 2m` and `DEFAULT_PING_MAX_OUT = 2` (`const.go:120,123`), and the rule
is `(ping_max + 1) × ping_interval` — observed at 6139.9 ms with `2s` / `2` (run C17).

**The payload error is spelled two ways across the tree.** `Maximum Payload Violation` here (`:432`),
`Maximum Payload Exceeded` on the gateway (`:301`) and leafnode (`:395`) pages; the server has one
literal, `Maximum Payload Violation` (`client.go:2554`). See [[s-docs-protocols-internal]].

## Practical takeaways

- Treat this page's `-ERR` table as a list of *topics*, not of strings. The strings are in
  [[wire-protocol]], generated from the call sites.
- `CONNECT {}` is a **verbose** connection. A hand-written client or a `telnet` session that omits
  `verbose` will get an `+OK` per op and must read them.
- Nothing on this page is version-tagged; the only version in it is `1.2.0` in two 2018-era examples.

## Relevance to the wiki

The primary source for [[wire-protocol]], and the reason that page states the
server's strings rather than the docs'.

## Questions it answers

Bank rows 183, 184, 186.

## Pages touched

[[wire-protocol]], [[core-nats-delivery]], [[client-connection-lifecycle]], [[client-defaults]],
[[defaults-and-limits]], [[error-codes]], [[subject-permissions]], [[tls-in-nats]], [[monitoring-endpoints]],
[[how-clients-reach-a-cluster]], [[slow-consumer-in-the-client]], [[connection-closed-after-auth-error]].

## Sources

- `raw/nats-docs/reference/protocols/client.md` (fetched 2026-08-31)
- `raw/nats-docs/reference/protocols.md` (fetched 2026-08-31)
- Swept against [[s-nats-server-wire-protocol]] and [[s-nats-server-client-errors]].
