---
title: The JetStream API and its errors
type: internals
area: [jetstream, security]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [js-api, err_code, schemas, paging, acl, errors.json]
aliases: ["$JS.API", js api, err_code, ApiError, error envelope]
sources: [s-adr-1-jetstream-json-api, s-adr-7-server-error-codes, s-docs-stream-config, s-docs-consumer-config, s-docs-upgrade-to-2.12, s-docs-upgrade-to-2.14, s-relnotes-2.14.0, s-nats-server-jetstream-log-warnings, s-gh-5859-unexpected-nats-timeout]
created: 2026-08-31
updated: 2026-09-01
---

# The JetStream API and its errors

Everything JetStream does administratively is a **NATS request-reply over a `$JS.API.…` subject
with a JSON body**. Knowing the shape matters for three operator jobs: writing ACLs, reading an
error, and tracing what a client is actually asking for
(source: [[s-adr-1-jetstream-json-api]], [[s-adr-7-server-error-codes]]).

## What the server does

### One subject per API, with the object in the subject

A request to `$JS.API.STREAM.INFO.ORDERS` returns a JSON document of type
`io.nats.jetstream.api.v1.stream_info_response`. The ADR is explicit about *why* the object name is
a subject token:

> "every API has a unique subject and generally the subjects include tokens indicating the item
> being accessed. This is to assist in generating ACLs giving people access to either subsets of
> API or even down to a single Stream or Consumer."

**That is the security consequence**: `$JS.API.STREAM.INFO.ORDERS` can be granted without granting
`$JS.API.STREAM.INFO.*`. Subject-level permissions are the JetStream authorisation model — see
[[account]].

The stream subjects ADR-1 lists (explicitly not exhaustive):

Since **2.14** there is also **`$JS.API.CONSUMER.RESET.<stream>.<consumer>`**, which resets a
consumer's delivery state to the acknowledgement floor or an arbitrary sequence **without deleting
and recreating it**; the resulting state equals a delete-and-recreate at that sequence
(source: [[s-relnotes-2.14.0]]).

```
$JS.API.STREAM.CREATE.<stream>          $JS.API.STREAM.UPDATE.<stream>
$JS.API.STREAM.NAMES                    $JS.API.STREAM.LIST
$JS.API.STREAM.INFO.<stream>            $JS.API.STREAM.DELETE.<stream>
$JS.API.STREAM.PURGE.<stream>           $JS.API.STREAM.MSG.DELETE.<stream>
$JS.API.STREAM.MSG.GET.<stream>         $JS.API.STREAM.SNAPSHOT.<stream>
$JS.API.STREAM.RESTORE.<stream>         $JS.API.STREAM.PEER.REMOVE.<stream>
$JS.API.STREAM.LEADER.STEPDOWN.<stream>
```

Consumer creation is `$JS.API.CONSUMER.CREATE.<stream>.<consumer>` with the consumer name optional
(source: [[s-docs-consumer-config]]). The complete list belongs on [[js-api-subjects]].

**An empty request body may be nil, an empty string, or `{}`.**

### Listings are paged

A paged reply carries `total`, `offset` and `limit`; the default `limit` shown in the ADR is
**1024**. Page with an `offset` in the request:

```
nats req '$JS.API.STREAM.NAMES' '{"offset": 1024}'
```

A tool that reads `$JS.API.STREAM.NAMES` once and believes it has every stream is wrong past 1024
streams.

### The error envelope

```json
{
  "type": "io.nats.jetstream.api.v1.consumer_info_response",
  "error": { "code": 404, "err_code": 10059, "description": "stream not found" }
}
```

- **The `error` key is present only on failure**; its absence usually indicates success.
- **The healthy response's fields are not present** on an error — an error reply is not a partial
  success.
- `code` is HTTP-like; **`err_code` is the specific NATS error**.
- A few APIs still answer with a bare **`-ERR <reason>`** string. ADR-1 calls these "very uncommon
  now in the API and will likely be entirely removed in time".

### `err_code` is the contract; `description` is not

This is the rule that matters most operationally
(source: [[s-adr-7-server-error-codes]]):

> the `description` field is "specifically out of scope for SemVer protection and changes to these
> will not be considered a breaking change".

The motivating problem was that a consumer-info `404` could mean the stream was missing (`10059`)
or the consumer was (`10014`) — or be an I/O error surfaced as a 404. Parsing the text would make
the wording part of the public API, so the server can never fix a typo or translate a message.

**Any alert, dashboard, log filter or runbook that matches on error text will break on an upgrade.
Match the number.**

### The number ranges

| range | subsystem |
|---|---|
| **1xxxx** | JetStream errors |
| **2xxxx** | MQTT errors |

ADR-7's status is **Partially Implemented** — "The current focus is JetStream APIs, we will as a
followup do a refactor and generalization and move onto other areas of the server." Outside
JetStream and MQTT an error may carry no code at all.

### Strict mode: an invalid request is an error since 2.12

From **2.11** the server *logged* a JetStream request it could not parse:

```
[WRN] Invalid JetStream request '$G > $JS.API.STREAM.CREATE.test-stream': json: unknown field "unknown"
```

From **2.12 strict mode is on by default and the server also returns an error to the client** —
invalid requests are rejected (source: [[s-docs-upgrade-to-2.12]]). A cluster on 2.11 that has been
ignoring those log lines will see them become client-visible failures on upgrade, so they are the
pre-flight check for that hop. The escape hatch, for buying time to fix clients:

```
jetstream {
  strict: false
}
```

### The ack and flow-control subjects change default in 2.15

`$JS.ACK` and `$JS.FC` are the reply subjects a consumer's acks ride on, and **their format is
versioned**:

```
v1: $JS.ACK.<stream>.<consumer>.<num delivered>.<stream seq>.<consumer seq>.<timestamp>.<num pending>
v2: $JS.ACK.<domain>.<account hash>.<stream>.<consumer>.<num delivered>.<stream seq>.<consumer seq>.<timestamp>.<num pending>
```

2.14 supports both with **v1 as the default**; **2.15 makes v2 the default**. Because these are
subjects, they are an **ACL surface** — any account import/export or subject permission naming
`$JS.ACK.<stream>.>` or `$JS.FC.<stream>.>` must be updated before 2.15. See
[[nats-server-2.15-preview]].

### Info APIs are deprioritised since 2.14

Account info, stream info, stream list, consumer info and consumer list requests are **queued
separately from, and below, create-update-delete operations** (source: [[s-relnotes-2.14.0]]). A
monitoring poller hammering `$JS.API.STREAM.INFO.*` on a busy server will see its own latency rise
before it slows anyone's stream creation down — which is the intended trade, and worth knowing
before tuning a scrape interval. See [[monitoring-endpoints]].

### There are two queues, and a full one drops every request without replying

The deprioritisation above is not a scheduling hint — the server keeps **two separate queues**, named
`JetStream API queue` and `JetStream API info queue` (`jetstream_api.go:955–956` at v2.14.6). Each is
bounded, and when one fills the server does not shed the newest request: it **drains the whole
queue** (`jetstream_api.go:876–890`, source: [[s-nats-server-jetstream-log-warnings]]):

```go
pending, _ := queue.push(&jsAPIRoutedReq{…})
if pending >= int(limit) {
    s.rateLimitFormatWarnf("%s limit reached, dropping %d requests", queue.name, pending)
    drained := int64(queue.drain())
    …
    s.publishAdvisory(nil, JSAdvisoryAPILimitReached, JSAPILimitReachedAdvisory{…})
}
```

```
JetStream API queue limit reached, dropping 10000 requests
JetStream API info queue limit reached, dropping 10000 requests
```

The bounds are **`request_queue_limit`** (default **10,000**) and **`info_queue_limit`**, which
defaults to `request_queue_limit`; `$JS.API.STREAM.INFO`-style requests use the second one. See
[[config-keys]].

**This is the sharpest server-side cause of a client-side `nats: timeout`.** `drain()` discards the
requests entirely, so **no reply of any kind is sent — not even an error envelope**. Nothing in the
sections above applies: there is no `err_code` to match, because there is no response. The only two
traces are the rate-limited log line and the advisory
**`$JS.EVENT.ADVISORY.API.LIMIT_REACHED`**, which carries the `Dropped` count — so alert on the
advisory, never on log-line frequency ([[advisories]]).

The client's side of this is deliberately quiet: `nats: timeout` "is a **client-side** error: the
reply never arrived inside the client's deadline. The server does not send it and does not log it",
which is why two independent reporters went hunting through server logs and found nothing
(source: [[s-gh-5859-unexpected-nats-timeout]]). Distinguish it from
`no responders available for request`, which the server *does* produce and which means the opposite —
nothing was subscribed at all. See [[nats-timeout]].

### Units and types on the wire

| type | wire form |
|---|---|
| durations | **nanoseconds** |
| timestamps | **RFC 3339** with sub-second precision, usually UTC; the server accepts and may return zoned times |
| sequences | **unsigned 64-bit**, exceeding what JSON can represent at the top of the range — a language may need a custom parser |
| some integers | **dynamically sized by the server's architecture**; assume 64-bit (`max_deliver` is the example) |
| `max_msg_size` | **signed 32-bit**, minimum `-1` |

Every JSON request and response has a **JSON Schema Draft 7** document. Requests are inferred from
the subject; **replies all carry a `type` hint**. The schemas live in the
[`jsm.go`](https://github.com/nats-io/jsm.go/tree/main/schemas) repository — the same schemas the
docs' generated reference pages are built from.

## Where it lives

The error definitions are generated from **`server/errors.json`** in the `nats-server` repo, one
entry per error:

```json
{
  "constant": "JSNotEnabledErr",
  "code": 503,
  "error_code": 10039,
  "description": "JetStream not enabled for account",
  "help": "This error indicates that JetStream is not enabled either at a global level or at global and account level",
  "url": "https://docs.nats.io/jetstream"
}
```

`go generate` at the repo root regenerates the constants, and the generator **verifies that
`error_code` and `constant` are unique**. That file is why [[error-codes]] can be regenerated
rather than transcribed.

Naming convention inside the server: a constant ending **`...ErrF`** takes printf-style
interpolation, a plain `...Err` does not. Tokens have fixed types — **`{err}` is always an `error`,
`{seq}` always a `uint64`**. Interpolated errors are new instances, so equality comparison fails and
`IsNatsError()` is the correct check.

## What you can observe

**In the server log**, `ApiError` appends the code in parentheses:

```
stream not found (10059)
```

So log-based alerting can match `\(10059\)` rather than prose.

**From the CLI:**

```
nats --trace <any command>    # logs every $JS.API subject and body, unmodified
nats error 10059              # description, HTTP code, Go constant, help text and URL
nats errors                   # list, search and edit the error definitions
nats schema list stream_create
nats schema show io.nats.jetstream.api.v1.stream_create_request --yaml
nats schema validate io.nats.jetstream.api.v1.stream_create_request x.json
```

`nats error <code>` surfaces the `help` and `url` fields that **the API response does not carry** —
both are `json:"-"` in `ApiError`, so they exist only in the lookup table.

## Why an operator cares

**`nats --trace` is the answer to "what is my client actually sending".** It prints subjects and
bodies unmodified, which is the fastest way to see a client using an API you did not expect, or
paging a listing it should not.

**Error codes are stable, error text is not.** Everything this wiki quotes an error for carries its
number for this reason — `10005` on [[stream-placement]], `10099` and `10100` on
[[retention-policies]], `10052`, `10165` and `10166` on [[message-ttl]].

**The subject tokens are the permission boundary.** Restricting an application to its own streams is
done with subject permissions on `$JS.API.*.<stream>`, not with a JetStream-specific ACL system.

## To verify

- The subject list above is ADR-1's own, marked "not an exhaustive list", and predates most of the
  API. The complete set for 2.14 is in `raw/nats-docs/reference/jetstream/api/` (32 pages), not yet
  turned into [[js-api-subjects]].
- ADR-7 is **Partially Implemented** and dated 2021-05-12; whether the generalisation beyond
  JetStream has since happened is not established by anything ingested.

## Related

[[stream]] · [[consumer]] · [[error-codes]] · [[js-api-subjects]] · [[message-ttl]] ·
[[stream-placement]] · [[retention-policies]] · [[account]] · [[nats-cli]] · [[nats-timeout]] ·
[[advisories]]

## Sources

[[s-adr-1-jetstream-json-api]] · [[s-adr-7-server-error-codes]] · [[s-docs-stream-config]] ·
[[s-docs-consumer-config]] · [[s-docs-upgrade-to-2.12]] · [[s-docs-upgrade-to-2.14]] ·
[[s-relnotes-2.14.0]] ·
[[s-nats-server-jetstream-log-warnings]] · [[s-gh-5859-unexpected-nats-timeout]]