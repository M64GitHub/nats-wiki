---
title: "nats-server issue #8271 — the Nats-Request-Info header can push a service-import request over max_payload"
type: summary
area: [core, security]
source-url: https://github.com/nats-io/nats-server/issues/8271
source-path: raw/gh-issues/issue-8271.md
author: "@0xasritha (reporting and fixing), @MauriceVanVeen and @neilalexander (maintainers)"
article: "Service-import request metadata can exceed max_payload, with the thread of its fix PR #8278"
date: 2026-06-07
version: "reported on a 2.15.0-dev build (commit 63537e843269); reproduced by this wiki on 2.14.6; open, unfixed on 2026-09-03"
tags: [max_payload, Nats-Request-Info, service-import, 8271, 8278, open]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# issue #8271 — a request that passed `max_payload` at ingress is delivered oversized

**Open**, labelled `defect` and `stale`, opened 2026-06-07. Its fix, PR #8278 *Enforce service import
max payload*, is **unmerged** — and the two maintainers who looked at it lean towards not merging it.

## Key claims

- The server checks `max_payload` on the inbound `PUB` / `HPUB`; the service-import path then adds
  `Nats-Request-Info` "before delivering the request into the destination account" and "does not
  repeat the payload-size check after adding the metadata". Reported with `max_payload: 128`: a
  128-byte request arrived as an `HMSG` "with a 62-byte header block and a 190-byte total message
  size".
- Preconditions named by the reporter: a service import, a low or tight `max_payload`, and a
  request within a header's size of the limit.
- **PR #8278** (opened the same day, 3 files, a regression test
  `TestServiceImportRequestInfoRespectsMaxPayload`): re-check the size after the header is added and
  "suppress oversized imported requests". @MauriceVanVeen asked for a test patch, then wrote: "I'm
  starting to doubt whether this should be done.. the max payload is already checked at least once,
  and it is generally about what the client sends not what the server needs to add to it for
  tracking purposes. Here the request is then also essentially silently swallowed."
  @neilalexander (2026-06-15): "I don't think it's good if requests are silently dropped after ingest
  into the system. I think the question is more whether or not they might traverse an account
  boundary and then hit a payload limit on an upstream connection type, but to my knowledge this
  hasn't been an issue to this point." No further activity.
- This wiki reproduced it on **2.14.6**: 250 bytes under `max_payload: 256` delivered as
  `HMSG … 257 507` ([[s-nats-server-share-import-observed]]).

## Practical takeaways

- Treat the delivered size as *request + header*, and the header as up to ~250 bytes plus the user
  JWT when the import shares. Keep the tenant-facing limit below `max_payload` by that much.
- Do not wait for a server fix: the maintainers' stated position is that `max_payload` governs what
  the client sends, not what the server appends.
- The open question they name is the one to watch: a downstream hop with its own limit (a route,
  gateway or leafnode) receiving the oversized frame.

## Notable quotes

- "it is generally about what the client sends not what the server needs to add to it for tracking
  purposes" — @MauriceVanVeen, 2026-06-08

## Relevance to the wiki

The one public record of the `max_payload` edge of [[service-import-request-info]]; bank row 168.

## Questions it answers

168.

## Pages touched

[[service-import-request-info]] · [[publishing]]
