---
title: "docs.nats.io — reference/config/accounts: exports and imports"
type: summary
area: [security]
source-url: https://docs.nats.io/reference/config/accounts/imports.md
source-path: raw/nats-docs/reference/config/accounts/imports.md
author: nats-docs (generated reference, fetched 2026-08-31)
article: "reference/config/accounts/exports.md, exports/{accounts,service,stream,response_type}.md, imports.md, imports/{service,stream,prefix,to}.md and their sub-pages"
date: 2026-08-31
version: "unversioned (generated reference); checked against nats-server 2.14.6"
tags: [config, exports, imports, accounts, response_type, prefix, to, docs-issue]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# docs.nats.io — the generated reference for `exports` and `imports`

The config-mode field tables for [[cross-account-sharing]], read for the `share` query. Short pages,
and incomplete: **docs issue #79**.

## Key claims

- **`exports.md`** tables four keys: `stream` "A subject or subject with wildcards that the account
  will publish to. Exclusive of `service`", `service` "… that the account will subscribe to",
  `accounts` "A list of account names that can import the stream or service. If not specified, the
  service or stream is public and any account can import it", `response_type` "`single` or `stream`"
  (default `single`). Reload note: "The whole export set is discarded and rebuilt from the config
  file on every reload; changes apply to connections that are already up."
- **`imports.md`** tables `stream`, `service`, `prefix` "A local subject prefix mapping for the
  imported stream. Applicable to `stream`", `to` "A local subject mapping for the imported service.
  Applicable to `service`". Reload note: "every reload tears down and re-creates ALL of the account's
  service-import subscriptions, so there is a short window where imported service subjects have no
  subscriber and requests arriving in it are dropped."
- `imports/service.md` is described as "Stream import source configuration. Exclusive of `stream`."
  and tables `account` "Account name owning the export" and `subject`.
- **Against the server at 2.14.6** ([[s-nats-server-service-imports]]): the parsers also accept
  `share` and `allow_trace` on an import, and `latency`, `response_threshold` (with three aliases),
  `account_token_position` and `allow_trace` on an export — **six keys on no page**, and the
  `imports/service.md` description is the stream entry's text.

## Practical takeaways

- The tables are correct for what they list; do not read them as complete.
- The reload notes are the useful part: an import reload has a drop window, an export reload does
  not.

## Notable quotes

- "If not specified, the service or stream is public and any account can import it."

## Relevance to the wiki

Closes the *To verify* item on [[cross-account-sharing]] that named these pages as unread, and is the
docs side of docs issue #79.

## Questions it answers

167 (the `accounts` guard's documented form); 48, 51 in part.

## Pages touched

[[cross-account-sharing]] · [[service-import-request-info]] · [[config-keys]]
