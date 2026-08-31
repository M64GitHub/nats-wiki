---
title: "ADR-7 — NATS Server Error Codes"
type: summary
area: [jetstream, core]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-7.md
source-path: raw/adr/ADR-7.md
author: "@ripienaar"
article: "ADR-7: NATS Server Error Codes"
date: 2021-05-12
version: ""              # no server version stated
tags: [error-codes, err_code, errors.json]
aliases: [ADR-7]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-7 — NATS Server Error Codes

Status **Partially Implemented** — "The current focus is JetStream APIs, we will as a followup do a
refactor and generalization and move onto other areas of the server." So the numbering below is
reliable for JetStream and **not yet applied server-wide**.

## Key claims

### The number ranges

| range | subsystem |
|---|---|
| **1xxxx** | JetStream related errors |
| **2xxxx** | MQTT related errors |

**"every error has a unique number within a range that indicates the subsystem it belongs to."**

### Why the code exists

The motivating example: a consumer-info request returning `404` gives no way to tell whether the
*stream* or the *consumer* was missing — and some conditions that are really I/O failures surface
as `404` too. Parsing the description text would make **the error text part of the public API**,
which "means we can never improve errors, fix spelling errors or translate errors into other
languages".

So: **`code` and `err_code` are the public API; `description` is explicitly outside SemVer
protection and changing it is not a breaking change.**

### The wire shape

```go
type ApiError struct {
	Code        int    `json:"code"`
	ErrCode     int    `json:"err_code,omitempty"`
	Description string `json:"description,omitempty"`
	URL         string `json:"-"`
	Help        string `json:"-"`
}
```

`ApiError` implements `error`, and **when logged it appends the code to the log line**:

```
stream not found (10059)
```

That is the format to grep server logs for.

### Where the codes are defined

**`server/errors.json`** in the `nats-server` repo holds the data the constants are generated
from — each entry has `constant`, `code`, `error_code`, `description`, and optionally `help` and
`url`:

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

`go generate` at the repo root regenerates the constants from it, and the generator **verifies that
`error_code` and `constant` are unique**.

### Naming convention

A constant ending in **`...ErrF`** takes printf-style interpolation; a plain `...Err` does not.
Interpolated tokens have fixed types — **`{err}` is always an `error`, `{seq}` always a `uint64`**.
Because interpolated errors are new instances, `err == ApiErrors[x]` fails; **`IsNatsError()` is the
correct comparison**.

### Tooling

```
nats error 10059          # lookup: description, HTTP code, Go constant, help, URLs
nats errors               # edit, add and view the error definitions
nats errors --errors <file>   # view a local errors.json during development
```

## Why an operator cares

- **`(10059)` in a log line is a code, not a count.** Server log lines append the error code in
  parentheses, so log-based alerting can match on the number rather than on prose.
- **The description text is unstable by design.** Any alert, dashboard or runbook that matches on
  error strings will break on a server upgrade. Match `err_code`.
- **`nats error <code>` is the lookup tool** and it carries `help` and `url` fields the API response
  does not — the JSON envelope drops both (`json:"-"`).
- The status is **Partially Implemented**: outside JetStream (and MQTT's 2xxxx range) an error may
  still have no code at all.

## Relevance to the wiki

The model behind the future [[error-codes]] reference page — it explains what the columns of
`raw/nats-docs/reference/jetstream/errors.md` mean and where the canonical list is generated from,
which is what makes that table regenerable rather than transcribed.

## Questions it answers

None directly; it is the key to reading every error this wiki quotes, and the reason those quotes
carry numbers.

## Pages touched

[[js-api]] · [[error-codes]] · [[stream-placement]] · [[retention-policies]]
