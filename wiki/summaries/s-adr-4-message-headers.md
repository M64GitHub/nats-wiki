---
title: "ADR-4 — NATS Message Headers"
type: summary
area: [core, clients]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-4.md
source-path: raw/adr/ADR-4.md
author: "@aricart, @scottf, @tbeets"
date: 2021-05-12
version: ""
article: "ADR-4, revision 2 (2025-05-15, 'Clarified ASCII'); status Implemented; tags server, client"
tags: [headers, HPUB, HMSG, NATS/1.0, case-preserving, ASCII, adr]
aliases: [ADR-4]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# ADR-4 — NATS Message Headers

The wire format of a message header, from the client's side: what a header may contain, how it is
framed in `HPUB` and `HMSG`, and the case rules every client is asked to follow. Two revisions,
2021-05-12 and 2025-05-15; *Implemented*. The ADR does not say which server release shipped it —
[[s-relnotes-2.2.0]] settles that from the source at v2.1.9 and v2.2.0.

## Key claims

- Headers are "similar to HTTP headers with some important differences" (L18–21): `name: colon,
  optional whitespace, value`, no space before the colon, keys may repeat (L23–32). Revision 2 pins
  the character set to RFC 822: a field name is "printable ASCII characters (i.e., characters that have
  values between 33. and 126., decimal, except colon)", a body "any ASCII characters, except CR or LF"
  (L34–49).
- **Version line**: instead of an HTTP request line, "a string identifying the header version
  (`NATS/X.x`), currently 1.0, so it is rendered as `NATS/1.0␍␊`" (L53–56).
- **Case preserving**: "NATS treats application headers as a part of the message *payload* … The server
  will not change the case in message conveyance"; "This is *different* from HTTP headers", where
  participants ignore case (L58–65).
- **Negotiation**: the server "will specify so in its `INFO` protocol message. The `headers` field if
  present, will have a boolean value. If the client wishes to send headers … it must add a `headers`
  field with the `true` value in its `CONNECT` message" (L71–86).
- **Framing**: `HPUB <SUBJ> [REPLY] <HDR_LEN> <TOT_LEN>` (L98) and `HMSG <SUBJECT> <SID> [REPLY] <HDR_LEN>
  <TOT_LEN>` (L118); `HDR_LEN` "includes the entire serialized header, from the start of the version
  string (`NATS/1.0`) up to and including the ␍␊ before the payload", `TOT_LEN` is payload plus header
  (L104–106, L122–124). A header-only message has `TOT_LEN == HDR_LEN` (the second example on L94, L114).
- **Client operations**: `GET`, `VALUES`, `SET`, `DELETE`, `APPEND` are case-sensitive; a case-insensitive
  option is "only suggested, and not required to be implemented by clients" (L141–186).
- **Multiple values** are serialised "one per line", not comma-joined: "Libraries, such as Go, do not
  interpret comma-separated values as lists" (L188–195).
- The ADR reserves no prefix; the docs do ("Keep the `Nats-` prefix …", `learn/core-nats/headers.md:198`,
  [[s-docs-core-nats-publish-subscribe]]).

## Practical takeaways

- A status reply from the server is a header-only message with a code on the version line —
  `NATS/1.0 503` for no responders, `NATS/1.0 100 Idle Heartbeat`, the `408` / `409` of a pull —
  and `TOT_LEN == HDR_LEN` is how a client knows there is no body.
- `HDR_LEN` and `TOT_LEN` are what `max_payload` is compared against together ([[core-nats-delivery]]).
- A header name with a non-ASCII byte is outside the specification; a client may refuse it.

## Notable quotes

- "NATS headers are *case preserving*" (L60).

## Relevance to the wiki

The header framing behind the 503 on [[request-reply]] and the `Nats-*` headers the JetStream pages
quote; the case rule for [[publishing]]'s `Nats-Msg-Id`. Row 4 of `inbox/adr-toc.md`.

## Questions it answers

150 (what the 503 is, physically).

## Pages touched

[[request-reply]] · [[core-nats-delivery]]
