---
title: "docs.nats.io — Cross-account"
type: summary
area: [security]
source-url: https://docs.nats.io/learn/security/cross-account.md
source-path: raw/nats-docs/learn/security/cross-account.md
author: NATS documentation (Synadia Communications, Inc.)
article: Cross-account
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [exports, imports, stream-export, service-export, prefix, to, activation-token]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Cross-account

The one deliberate hole in the account boundary: a matched export/import pair for a single subject.
Everything else stays isolated, and the two halves fail in opposite ways.

## Key claims

**Both halves are required, and neither works alone.** "An export with no matching import shares
nothing, because the offer goes unused. An import with no matching export is refused: the server
rejects the configuration at startup."

**Two export types, chosen by the messaging pattern:**

| type | pattern | direction |
|---|---|---|
| **`stream`** | publish/subscribe | one way, exporter → importers |
| **`service`** | request/reply | both ways |

"Despite the name, a stream export has nothing to do with JetStream streams — here the word only
means a one-way flow of messages across the account boundary."

**The config, both halves:**

```
accounts {
  ORDERS: {
    jetstream: enabled
    users: [ { user: order-svc, password: s3cr3t,
      permissions: { publish: { allow: ["orders.>"] }, subscribe: { allow: ["_INBOX.>"] } } } ]
    exports: [
      { stream: "orders.shipped" }
    ]
  }
  ANALYTICS: {
    users: [ { user: analytics-reader, password: an4lytics } ]
    imports: [
      { stream: { account: ORDERS, subject: "orders.shipped" } }
    ]
  }
}
```

"The `stream:` key does two jobs. It declares the export `type` as a stream, and it names the subject
being offered." The import names three things: the type key, `account` (who owns the export) and
`subject` ("the subject as the exporter publishes it").

**An export with no `accounts` field is public** — "Any account on the server may import
`orders.shipped`." Restrict it by listing importers:

```
{ stream: "orders.shipped", accounts: [ANALYTICS] }
```

"More sophisticated export restrictions are available when using Operator mode."

**Apply with a reload:** `nats-server --signal reload=<pid>` (or a restart).

**An import may rename on the way in** with `prefix:` or `to:`. "The import lands at the same
subject name by default."

**Neither side observes the wiring.** "`order-svc` publishes `orders.shipped` exactly as it always
has… it lives entirely in the server's account configuration." A third account sees nothing "unless
it too imports the exported subject. It could import on a distinct name, without impacting upon
existing importers."

**The operator-mode equivalent:**

```
nats auth account exports add Shipments "orders.shipped" ORDERS
nats auth account imports add Shipments "orders.shipped" ANALYTICS --source <ORDERS-public-key> --local orders.shipped
```

"Both changed account JWTs must then be pushed to the server; until then the share silently doesn't
exist, because **JWT mode has no startup check to catch a mismatch**." And: "`nats auth` has no
activation tokens for private exports; its substitute is `--token-position`, which keys a wildcard
export so each importing account can only import the subject carrying its own account key."

## Practical takeaways

- **The two halves fail asymmetrically, and only one of them is loud.** An unmatched import stops
  the server at boot:

  ```
  nats-server: nats.conf:2:1: Error adding stream import "orders.shipped": stream import not authorized
  ```

  An unmatched export is not an error at all — "the server starts, the config is valid, and no
  messages move." In **operator mode both are silent**.
- **`No responders are available` means the import matched but nothing answered.** For a service
  import with no responder in the exporting account, the answer comes back immediately — the CLI
  "prints the status and exits 0". "A request with no import at all gets the same immediate answer,
  because it never leaves `ANALYTICS`."
- **Subscribe to the name the import lands on**, not the name the exporter published, once `prefix:`
  or `to:` is in play.
- **The exports array is a complete inventory:** "you can read an account's `exports` array and know
  the complete list of what leaves it."

## Notable quotes

> "That isolation is the right default, but sometimes you need to share across it."

> "Neither half works alone."

## Relevance to the wiki

The mechanism behind Q51 and Q90 — but only for **subjects**. The page never mentions sharing a
JetStream stream or KV bucket, which is what the public questions actually ask; that gap is
[[cross-account-sharing]]'s `## To verify` and the reason
[[s-gh-5606-cross-account-jetstream]] and [[s-gh-7017-kv-across-accounts]] were read.

## Questions it answers

Q51 (partly), Q90 (partly).

## Pages touched

[[cross-account-sharing]] · [[account]] · [[subject-permissions]] · [[operator-mode]] ·
[[reload-server-config]] · [[error-codes]]
