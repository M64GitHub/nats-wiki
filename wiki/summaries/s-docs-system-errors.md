---
title: "docs — reference/system/errors: the error tables, swept against the server"
type: summary
area: [core, monitoring, security]
source-url: https://docs.nats.io/reference/system/errors.md
source-path: raw/nats-docs/reference/system/errors.md
author: NATS documentation
article: "reference/system/errors.md, fetched 2026-08-31, diffed against reference/protocols/client.md's -ERR table and against server/errors.go and every sendErr call site at v2.14.6"
date: 2026-08-31
version: "unstated"
tags: [-ERR, error-strings, ClosedState, connz, sweep]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# docs — `reference/system/errors`: the error tables, swept against the server

The docs tree's second `-ERR` list (the first is `reference/protocols/client.md`), and the only one
that claims completeness: "This page documents **all** non-JetStream errors that the NATS server can
return to clients, routes, gateways, and leafnode connections" (`:4`). Phase E skipped it by
decision; step 4 read it and **swept every row** against `nats-server` v2.14.6
([[s-nats-server-client-errors]]), because both gotcha pages quote strings from it.

## Key claims

The page is thirteen tables, **129 rows**, grouped by area (auth, connection limits, protocol and
payload, subject and publishing, TLS, account, server name and cluster, wrong port, gateway,
leafnode, connection state, other, route, slow consumer) plus a final **Connection Close Reasons**
table which it correctly describes as monitoring data rather than wire errors.

## The sweep

Rows split into three kinds, and they hold up very differently.

| kind | rows | wrong |
|---|---|---|
| a Go identifier from `server/errors.go` (`ErrAuthExpired`, `ErrTooManySubs`, …) | 70 | **0** |
| a `ClosedState` name, in *Connection Close Reasons* | 37 | **0** |
| a literal string presented as an error "the server can return to clients" | 22 | **11** |

- The **70 `Err*` rows** each name a real identifier and its text. The only difference found across
  all of them is cosmetic: `ErrMappingDestinationNotSupportedForImport`'s row title adds backticks
  and a capital, against `the only mapping function allowed for import transforms is
  {{Wildcard()}}` in the source. Eight of the seventy are declared with `fmt.Errorf("%w: …")` rather
  than `errors.New`, which is why a naive grep misses them.
- The **37 close reasons** are exactly the `ClosedState` enum (`client.go:190–228`), in the enum's
  own order, with the right constant names. This is the most useful table on the page and the one
  the wiki now points at from [[monitoring-endpoints]].
- The **22 wire-error rows** are where it fails. Eleven of them are not sent to a client at v2.14.6:

| row | doc's constant | what the server actually has |
|---|---|---|
| `:32` | `Connection Throttling Is Active` | the string is `Connection throttling is active. Please try again later.` (`server.go:3503`) |
| `:33` | `Maximum Clients Exceeded` | **absent**; the string is `maximum connections exceeded` (`ErrTooManyConnections`), already row `:30` |
| `:46` | `Protocol Violation` | only a `ClosedState.String()` in `monitor.go:2639`; never sent |
| `:47` | `Parser Error` | **absent**; the parser sends `Unknown Protocol Operation` (`parser.go:1253`) or the parse error's own text |
| `:78` | `TLS Handshake Error` | **absent** as an `-ERR`; `TLSHandshakeError` is a close reason, and it skips the flush anyway |
| `:127` | `Connection to Gateway Rejected` | the string is `Connection to gateway %q rejected` (`gateway.go:1015`) |
| `:157` | `Route Authorization Violation` | **absent**; a route gets the same `Authorization Violation`, or a formatted rejection text (`route.go:3038–3040`, `:3073–3075`) |
| `:158` | `Duplicate Route` | only a `ClosedState.String()` (`monitor.go:2655`) |
| `:164` | `Slow Consumer Detected` | a **log line** (`c.Noticef`, `client.go:2613`), never on the wire — and `markConnAsClosed` explicitly skips the flush for both slow-consumer reasons |
| `:165` | `Consumer Is Slow` | **absent** from the source entirely |
| `:166` | `Write Deadline Exceeded` | **absent**; the log line is `Slow Consumer %s: WriteDeadline of %v exceeded with %d chunks of %d total bytes.` |

Eight of the eleven appear nowhere in `server/*.go` at v2.14.6; three exist only as a log line or a
monitoring reason. Recorded as docs issue #100.

### Diffed against the sibling table

`reference/protocols/client.md:419–435` lists fifteen `-ERR` strings. The two lists disagree on
five of them, in both directions:

- `protocols/client.md` has `Unknown Protocol Operation`, `Attempted To Connect To Route Port`,
  `Authorization Timeout`, `Invalid Client Protocol` and `Slow Consumer`; `errors.md` has the first
  three only in `Err*` form and does not have `Slow Consumer` at all under that name.
- `Authorization Timeout` is not a string the server sends: the literal is `Authentication Timeout`
  (`client.go:2496`) and `errors.md` gets it right in the close-reason table.
- `Slow Consumer` is not sent at all, by either name.
- The payload error is spelled two ways across the four protocol pages (`Maximum Payload Violation`
  / `Maximum Payload Exceeded`) where the server has one literal, `client.go:2554`.

The three wrong defaults on that page's table (`Authorization Timeout` "default 1 second" against
`AUTH_TIMEOUT = 2s`; `max_control_line` "1024 bytes" against `MAX_CONTROL_LINE_SIZE = 4096`;
`Slow Consumer` "default 10MB" against `MAX_PENDING_SIZE = 64 MB`) belong to
`reference/protocols/client.md` and are recorded with the wire-protocol read, not here.

## Practical takeaways

- Use the **Connection Close Reasons** table; it is accurate and it is what `/connz` reports.
- Do not build alerting on the wire-error strings from this page without checking them; half of the
  ones it presents as wire errors are log lines, close reasons, or nothing at all.
- There is no `-ERR` for a slow consumer in either direction. A cut connection is diagnosed from the
  **server's** log and `/connz?state=closed`, never from what the client received.

## Relevance to the wiki

The authority-checked half of [[error-codes]] and [[advisories]]'s `-ERR` material, and the reason
[[slow-consumer-in-the-client]] can say flatly that the server sends nothing.

## Questions it answers

182.

## Pages touched

[[error-codes]], [[advisories]], [[slow-consumer-in-the-client]],
[[connection-closed-after-auth-error]], [[monitoring-endpoints]], [[slow-consumer-detected]]
