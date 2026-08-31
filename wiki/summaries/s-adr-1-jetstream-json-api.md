---
title: "ADR-1 — JetStream JSON API Design"
type: summary
area: [jetstream, clients]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-1.md
source-path: raw/adr/ADR-1.md
author: "@ripienaar"
article: "ADR-1: JetStream JSON API Design"
date: 2020-04-30
version: ""              # no server version stated
tags: [js-api, schemas, paging, error-envelope]
aliases: [ADR-1]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-1 — JetStream JSON API Design

Status **Implemented**. The shape of every `$JS.API` call: request-reply, typed JSON, paged
listings, and a two-level error envelope.

## Key claims

### Request-reply over a unique subject per API

A request to **`$JS.API.STREAM.INFO.ORDERS`** returns a JSON document of type
`io.nats.jetstream.api.v1.stream_info_response`. **"every API has a unique subject and generally
the subjects include tokens indicating the item being accessed. This is to assist in generating
ACLs giving people access to either subsets of API or even down to a single Stream or Consumer."**

The server accepts **nil, an empty string, or `{}`** as an empty request body.

The stream subjects the ADR lists (explicitly "not an exhaustive list"):

```
$JS.API.STREAM.CREATE.%s        $JS.API.STREAM.UPDATE.%s
$JS.API.STREAM.NAMES            $JS.API.STREAM.LIST
$JS.API.STREAM.INFO.%s          $JS.API.STREAM.DELETE.%s
$JS.API.STREAM.PURGE.%s         $JS.API.STREAM.MSG.DELETE.%s
$JS.API.STREAM.MSG.GET.%s       $JS.API.STREAM.SNAPSHOT.%s
$JS.API.STREAM.RESTORE.%s       $JS.API.STREAM.PEER.REMOVE.%s
$JS.API.STREAM.LEADER.STEPDOWN.%s
```

### Paging

Listing APIs are paged, signalled by `total`, `offset` and `limit` in the reply. **The default
`limit` shown is 1024.** Move through pages with an `offset` in the request:

```
nats req '$JS.API.STREAM.NAMES' '{"offset": 1024}'
```

### The error envelope

```json
{
  "type": "io.nats.jetstream.api.v1.consumer_info_response",
  "error": { "code": 404, "err_code": 10059, "description": "stream not found" }
}
```

- **The `error` key is present only on failure**; its absence usually indicates success.
- **`code` is HTTP-like**; `err_code` is the specific NATS error.
- **`description` is explicitly not covered by SemVer** — "the `description` field is variable and
  can change its content between server versions". Parse `err_code`, never the text.
- **The fields of a healthy response are not shown for an error response.**
- A few APIs still answer with a text error of the form **`-ERR <reason>`**; these are "very
  uncommon now in the API and will likely be entirely removed in time".

### Schemas and data types

- Every JSON request and response has a **JSON Schema Draft 7** document; requests are inferred
  from the subject, **replies all carry a `type` hint**. Schemas live in the
  [`jsm.go` repository](https://github.com/nats-io/jsm.go/tree/main/schemas).
- **Durations are sent as nanoseconds.**
- **Timestamps are RFC 3339 with sub-second precision**, usually UTC — the server accepts and may
  return zoned times.
- **Sequence numbers are unsigned 64-bit** and exceed what JSON can represent at the top of the
  range; a language may need a custom parser. In practice only reachable "after many many years of
  creating data at full theoretical limit of message ingest".
- Some integers are **dynamically sized by the server's architecture** — assume 64-bit. `max_deliver`
  is the ADR's example. `max_msg_size` is a **signed 32-bit** integer with minimum `-1`.

### Tooling

```
nats req '$JS.API.STREAM.NAMES' '{}'
nats schema list stream_create
nats schema show io.nats.jetstream.api.v1.stream_create_request --yaml
nats schema validate io.nats.jetstream.api.v1.stream_create_request x.json
nats error show 10059
```

Adding **`--trace`** to any `nats` command logs every JetStream API subject and body unmodified —
"an invaluable way to observe the interaction model".

## Why an operator cares

- **The per-item subject tokens are the ACL surface.** `$JS.API.STREAM.INFO.ORDERS` can be granted
  without granting `$JS.API.STREAM.INFO.*`.
- **`nats --trace`** is the tool for "what is my client actually asking the server".
- **Never match on error text.** The description is explicitly unstable across versions;
  `err_code` is the contract.

## Relevance to the wiki

The structural source for the future [[js-api-subjects]] reference page and for [[js-api]]. It
also settles the units question (nanoseconds, RFC 3339) that the generated schema pages assume.

## Questions it answers

None directly; it underpins any answer that quotes a `$JS.API` subject or an error code.

## Pages touched

[[js-api]] · [[js-api-subjects]] · [[error-codes]] · [[stream]]
