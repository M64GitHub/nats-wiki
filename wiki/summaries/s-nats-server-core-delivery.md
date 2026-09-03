---
title: "nats-server v2.14.6 — core delivery: subject validation, the PUB parsers, echo, headers and max_payload, the 503, account mappings, /subsz"
type: summary
area: [core, monitoring]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/core-delivery-v2.14.6.md
author: nats-io (Apache-2.0), extracted by this wiki
article: "client.go, parser.go, opts.go, accounts.go, sublist.go, server.go, const.go, errors.go, monitor.go, reload.go at tag v2.14.6 — the ranges quoted in the raw file"
date: 2026-09-03
version: "2.14.6"
tags: [isValidSubject, processPub, processHeaderPub, pedantic, echo, max_payload, no_responders, NATS/1.0 503, Nats-Subject, max_subscription_tokens, mappings, AddWeightedMappings, selectMappedSubject, subsz, reload]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.14.6 — core delivery, read from the source

The server side of what the core-NATS chapter describes, with file and line at the tag. The behavioural
half — every claim below that says *run* — is [[s-nats-server-core-delivery-observed]].

## Key claims

### What a subject may contain

- `isValidSubject` (`sublist.go:1209–1246`) rejects an **empty subject**, an **empty token**, any token
  containing **` \t\n\f\r`** (space, tab, newline, form feed, carriage return), and a `>` that is not
  the **last** token. Nothing else: no length, no token count, no character set — "any UTF-8" holds for
  routing. The NUL and invalid-UTF-8 checks run only with `checkRunes`, which the subscribe path does
  not pass. A `*` inside a longer token (`orders.1*`) passes as a literal (`subjectIsLiteral`,
  `:1187–1197` — the rule behind `inbox/server-issues.md` SI-3).
- **Publish subjects are checked only in pedantic mode**: both `processPub` (`client.go:2984–2986`) and
  `processHeaderPub` (`:2931–2933`) run `if c.opts.Pedantic && !IsValidLiteralSubject(...) {
  c.sendErr("Invalid Publish Subject") }` — and then **return `nil`**, so the message is processed
  anyway (run C3). `defaultOpts` is `{Verbose: true, Pedantic: true, Echo: true}` (`:706`), but the value is
  overwritten by whatever the client's `CONNECT` carries; nats.go sends `false` unless its `Pedantic` option is
  set (step 3 pins the client source).
- A `PUB` line is split on **spaces and tabs** into 2 or 3 arguments — subject, [reply], size
  (`client.go:2938–2973`). A space inside a subject is therefore the boundary before a reply subject
  (run A2). `HPUB` takes 3 or 4: subject, [reply], header size, **total** size (`:2887–2905`).
- The subscribe path: the sublist insert fails for an invalid subject and the client gets
  `-ERR 'Invalid Subject'` (`:3125–3127`, `ErrMalformedSubject`); the connection stays open (run C1).

### `max_subscription_tokens` / `max_sub_tokens`

- `opts.go:1370–1381`: a `uint8`; `> 255` is "`value is too big`", `<= 0` is "`value can not be
  negative`" (so `0` is refused with a misleading message, run C7); unset means unlimited.
- Checked **on subscribe only** (`client.go:3090–3096`): more tokens than the limit →
  `-ERR 'Permissions Violation for Subscription to "<subj>", too many tokens'` and the log line
  `Subscription Violation Too Many Tokens - Subject "<subj>", SID <n>` (`:5814–5819`); a publish with
  more tokens is delivered (run C5).
- **Not reloadable**: `reload.go` has no case for `MaxSubTokens`, so a changed value fails the whole
  reload with `config reload not supported for MaxSubTokens: old=3, new=4` (`:1782`; run C6).

### Echo, headers, `no_responders`

- `c.echo = c.opts.Echo` at `CONNECT` (`client.go:2312`); `deliverMsg` skips a subscription owned by the
  publishing connection when `!client.echo`, except service-import shadows (`:3761–3768`).
- The `INFO` line's `headers` is `!opts.NoHeaderSupport` (`server.go:748`); `no_header_support` is a
  plain boolean option (`opts.go:1750–1751`) with no `reload.go` case. `processHeaderPub` returns
  `ErrMsgHeadersNotSupported` when the connection has no header support (`client.go:2862–2864`).
- A `CONNECT` with `no_responders: true` on a connection without header support is refused:
  `-ERR 'no responders requires headers support'` and the connection is closed (`:2459–2468`; runs A5, B7).

### `max_payload` counts the header block

- `processHeaderPub` compares `c.pa.size` — the `HPUB` **total** of header and body — against
  `max_payload` (`client.go:2916–2930`); `processPub` compares the body (`:2978–2983`). A violation is
  `maxPayloadViolation`: the log line `maximum payload exceeded: <size> vs <max>`, `-ERR 'Maximum
  Payload Violation'`, and **`closeConnection`** (`:2552–2556`; runs B2, B4). The check runs on the
  control line, before the body is read.

### The 503 the server sends

- After a message with a reply subject was delivered to nobody, and only if the publishing connection
  set `no_responders`, the server queues to that connection
  `HMSG <reply> <sid> <hdrLen> <hdrLen>\r\nNATS/1.0 503\r\nNats-Subject: <subject>\r\n\r\n\r\n` — an
  empty body, a header block of 32 bytes plus the subject (`client.go:4504–4517`). **`Nats-Subject`**
  carries the request subject; no docs page names the header (recorded with step 2's run).

### Account-level mappings

- `parser.go:519–527`: for CLIENT and LEAF connections with the account's `hasMappings` flag set, the
  subject is rewritten by `selectMappedSubject` **before** the message is routed; with `-DV` the rewrite
  is traced as `MAPPING <from> -> <to>`.
- `AddWeightedMappings` (`accounts.go:794–892`): a duplicate destination is refused; **each weight ≤
  100** ("`individual weights need to be <= 100`"); the **total per cluster ≤ 100**
  ("`total weight needs to be <= 100`", run F4); destinations without a `cluster` go to `m.dests`, the
  rest to `m.cdests[cluster]`. Then, per destination list, **the source is auto-added at `100 −
  total` unless the source itself was listed** ("Iff the src was not already added in explicitly,
  meaning they want loss", `:844–862`); weights are sorted and made cumulative.
- `selectMappedSubject` (`:951–1028`): a literal source matches by equality, a wildcard source by
  `isSubsetMatch`; a cluster-scoped list is used when the server's cluster name matches, else the
  unscoped one; one destination at weight 100 short-circuits, otherwise a roll of `fastrand.Uint32n(100)`
  picks the first cumulative weight above it — **and when the listed weights total less than 100 with the
  source listed, a roll past them selects nothing and the message is dropped** (`ndest` stays empty;
  run F5: 12 of 200).
- A top-level `mappings` block is parsed as the **`$G` account's** mappings (`opts.go:1188–1195`), which
  is why a changed block reloads through the `accounts` case of `reload.go` (`:1744–1745`,
  `Reloaded: accounts`; run F3).

### `/subsz`

- `HandleSubsz` reads `subs`, `offset`, `limit`, `test` and `acc` (`monitor.go:1104–1131`); `test`
  returns "only subscriptions that would match if a message was sent to this subject" (`:972–973`);
  a queue subscription's detail carries `qgroup` (`:981`).

### Constants and errors

- `const.go:88–123`: `MAX_CONTROL_LINE_SIZE = 4096`, `MAX_PAYLOAD_SIZE = 1 MB`, the 8 MB warning
  threshold, `MAX_PENDING_SIZE = 64 MB`, `DEFAULT_MAX_CONNECTIONS = 64 * 1024`, `TLS_TIMEOUT` and
  `AUTH_TIMEOUT = 2s`, `DEFAULT_PING_INTERVAL = 2m`, `DEFAULT_PING_MAX_OUT = 2`.
- `errors.go`: `maximum payload exceeded` (`:43`), `invalid subject` (`:55`), `subject has exceeded number
  of tokens limit` (`:79`), `message headers not supported` (`:185`), `no responders requires headers
  support` (`:189`), `malformed subject` (`:201`).
- The lame-duck notice is `Entering lame duck mode, stop accepting new clients` (`server.go:4446`).

## Practical takeaways

- The server is permissive on the publish side by design: it will route a subject containing `*`, a
  subject with 40 tokens, a subject under `$SRV`. The client library is the only guard for those.
- `max_subscription_tokens` and `no_header_support` need a restart; `mappings` and `max_payload` do not.
- Size the header block into `max_payload`, and expect a violation to **close** the connection.

## Relevance to the wiki

The authority for every server-side statement on [[subjects-and-wildcards]] and [[core-nats-delivery]],
and the mechanism behind the *Account-level mappings* section of [[subject-transforms]].

## Questions it answers

25, 169, 170, 171 (with the observed summary and the docs summaries).

## Pages touched

[[subjects-and-wildcards]] · [[core-nats-delivery]] · [[subject-transforms]] · [[defaults-and-limits]] ·
[[config-keys]] · [[monitoring-endpoints]] · [[publishing]]
