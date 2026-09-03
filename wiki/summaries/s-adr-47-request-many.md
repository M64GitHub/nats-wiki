---
title: "ADR-47 — Request Many"
type: summary
area: [core, clients]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-47.md
source-path: raw/adr/ADR-47.md
author: "@aricart, @scottf, @Jarema"
date: 2024-09-26
version: ""
article: "ADR-47, revision 1; status Partially Implemented; tags client, spec, orbit"
tags: [request-many, scatter-gather, sentinel, stall, total-timeout, max-messages, mux-inbox, orbit, adr]
aliases: [ADR-47, request many]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# ADR-47 — Request Many

The client-side specification for receiving many replies to one request: a total timeout, an
optional stall timer, an optional message cap, an optional sentinel, and what to do when a 503
arrives instead of a reply. *Partially Implemented*, tagged `orbit` — the helpers live in the
extension repos and a few clients, not in every core client.

## Key claims

- The problem: "support receiving multiple replies from a single request, instead of limiting the
  client to the first reply, and support patterns like scatter-gather and sentinel" (L15–16).
- "The client doesn't assume success or failure - only that it might receive messages"; "Request Many
  is not a recoverable operation, but it could be wrapped in a retry pattern"; "The client should
  communicate status whenever possible, for instance if it gets a 503 No Responders" (L23–27).
- **Total timeout** — "Always used", the wait for the first message is always the total timeout,
  "Defaults to the connection or system request timeout" (L31–37).
- **Stall timer** — the wait for messages after the first; "Less than 1 or greater than or equal to the
  total timeout behaves the same as if not supplied"; subsequent waits are "the lesser of the stall time
  or the calculated remaining time" so the total is honoured (L39–48).
- **Max messages** — the request is complete when reached (L50–55). **Sentinel** — a way to stop;
  "the 'standard sentinel', which is a message with a null/nil or empty payload"; a predicate returning
  false stops (L57–62, L90–95).
- **A status or error "in place of a user message … is terminal"**, and "probably useful information
  for the user" conveyed with the end of data (L79–82). Blocking callback time must not count against
  the timeouts (L84–88).
- **Strategies** are pre-canned configurations: *Timeout or Wait* (total only, the default), *Stall*
  ("the lessor of 1/10th of the total wait time … or the default connection timeout"), *Max Responses*
  (L108–116).
- **Subscription management**: "it should always unsubscribe upon completion … instead of leaving it up
  to the server to time it out"; with a max and a non-mux inbox, unsubscribe with a count right after
  subscribing, but "you still must check the count manually"; with the mux inbox neither applies
  (L118–128).

## Practical takeaways

- The `nats` CLI's flags are the three stop conditions: `--replies N` is *max messages*,
  `--reply-timeout` the *stall*, `--wait-for-empty` the *standard sentinel*, `--timeout` the *total*;
  what each does when run is in [[s-nats-server-request-reply-observed]] run D and, from the CLI's
  source, [[s-nats-cli-request-reply-source]].
- Which client ships a helper is the docs' word ([[s-docs-core-nats-request-reply]]): nats.js
  `requestMany`, orbit.go `RequestMany`, .NET `RequestManyAsync`; a 503 ends the gather everywhere.

## Notable quotes

- "Request Many is not a recoverable operation" (L26).

## Relevance to the wiki

The specification behind the *Scatter-gather* section of [[request-reply]] and the *RequestMany*
lines on [[orbit]], [[nats-js]] and [[nats-net]]. Row 47 of `inbox/adr-toc.md`.

## Questions it answers

172 (the stop conditions).

## Pages touched

[[request-reply]] · [[orbit]] · [[nats-js]] · [[nats-net]] · [[nats-cli]]
