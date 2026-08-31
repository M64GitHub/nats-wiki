---
title: Cross-account sharing
type: concept
area: [security, jetstream, kv]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [exports, imports, stream-export, service-export, prefix, to, external, api-prefix, 10021, 10022, 10024]
aliases: [exports, imports, export, import, cross-account, account import, account export, activation token, api prefix, external]
sources: [s-docs-cross-account, s-gh-5606-cross-account-jetstream, s-gh-7017-kv-across-accounts, s-nats-server-auth-and-tls]
created: 2026-08-31
updated: 2026-08-31
---

# Cross-account sharing

**An [[account]] boundary opens one named subject at a time, and only when both sides agree.** The
owning account declares an **export**; the receiving account declares a matching **import**. "Neither
half works alone" (source: [[s-docs-cross-account]]).

Sharing a *subject* is well documented. Sharing a **JetStream stream or KV bucket** is not — the
mechanism exists, no docs page describes it, and the public question asking for it has never been
answered. Both halves are below, with the second clearly marked.

## How it behaves

**Two export types, chosen by the direction of the messages:**

| type | pattern | direction |
|---|---|---|
| `stream` | publish/subscribe | one way, exporter → importers |
| `service` | request/reply | both ways |

"Despite the name, a stream export has nothing to do with JetStream streams — here the word only means
a one-way flow of messages across the account boundary."

**An export with no `accounts` field is public**: any account on the server may import it. Naming
accounts restricts it.

**Neither side can tell.** "`order-svc` publishes `orders.shipped` exactly as it always has" and the
subscriber receives it under the same name; "it lives entirely in the server's account
configuration". An import may rename on the way in with `prefix:` or `to:`, in which case the
subscriber must use the **new** name.

**An account's `exports` array is a complete inventory** of what can leave it — which is the property
that makes the boundary auditable.

## What configures it

```
accounts {
  ORDERS: {
    jetstream: enabled
    users: [ { user: order-svc, password: s3cr3t } ]
    exports: [
      { stream: "orders.shipped" }
      { stream: "orders.audit.>", accounts: [ANALYTICS] }
      { service: "orders.price" }
    ]
  }
  ANALYTICS: {
    users: [ { user: analytics-reader, password: an4lytics } ]
    imports: [
      { stream:  { account: ORDERS, subject: "orders.shipped" } }
      { service: { account: ORDERS, subject: "orders.price" } }
    ]
  }
}
```

"The `stream:` key does two jobs. It declares the export `type` as a stream, and it names the subject
being offered." The import names the type, the `account` that owns the export, and the `subject` "as
the exporter publishes it". Apply with `nats-server --signal reload=<pid>` — see
[[reload-server-config]].

**In [[operator-mode]]** the same pair lives in the two account JWTs:

```
nats auth account exports add Shipments "orders.shipped" ORDERS
nats auth account imports add Shipments "orders.shipped" ANALYTICS --source <ORDERS-public-key> --local orders.shipped
```

Both accounts must then be pushed. `nats auth` v0.4.0 has **no activation tokens** for private
exports; its substitute is `--token-position`, "which keys a wildcard export so each importing account
can only import the subject carrying its own account key". For activation tokens, use [[nsc]] on the
same store.

## Sharing JetStream: streams and KV buckets

This is what people actually ask for — "a single account owns a KV store, and I'd like to share access
to this KV store with other accounts" (source: [[s-gh-7017-kv-across-accounts]]) — and **no page of
docs.nats.io covers it** (docs issue #21). Two routes exist, and they solve different problems.

### Route 1 — import the other account's JetStream API (control plane)

A maintainer's answer to the same question: "You should be able to import the foreign account
jetstream API and manage it using the API prefix options in clients and CLI"
(source: [[s-gh-5606-cross-account-jetstream]]).

The owning account exports `$JS.API.>` as a **service** — request/reply, because that is what the
JetStream API is — and the importing account brings it in under a prefix of its own. Clients and the
`nats` CLI then address the foreign API through that prefix. A KV bucket is the stream `KV_<bucket>`
([[key-value]]), so this reaches buckets as well as streams.

**What no public source states**, and therefore what this page will not invent: the exact export and
import entries, and how to narrow the export below the whole `$JS.API.>` tree so an importer gets one
stream rather than the account's entire control plane. The thread says "with some restrictions" and
stops. Treat the whole-API export as all-or-nothing until you have verified narrower subjects
yourself.

### Route 2 — mirror or source the stream (data plane)

The stream config's `external` block reaches a stream in another account or domain
(`stream.go:425–429`):

```go
type ExternalStream struct {
	ApiPrefix     string `json:"api"`
	DeliverPrefix string `json:"deliver"`
}
```

It is a field of both `mirror` and each entry of `sources`. The server applies `api` by textual
substitution on the API subject (`stream.go:2818`), and reads a JetStream **domain** out of it as the
prefix's second token — which is why a domain prefix is written `$JS.<domain>.API`.

This gives the second account a **copy**, with the mirror's lag, not the same asset: a write there
does not reach the original. See [[mirrors-and-sources]].

Three things must line up, and the docs say so without documenting the fields: "the `external` block
plus matching exports and imports on both sides, and each of the three subjects has a required type.
The consumer API and flow-control subjects are *service* exports… The delivery subject is a *stream*
export… **Get a type wrong and replication doesn't fail with an error; the mirror never catches up.**"

Three error codes guard the prefixes:

| code | message |
|---|---|
| **10021** | `stream external api prefix {prefix} must not overlap with {subject}` |
| **10022** | `stream external delivery prefix {prefix} overlaps with stream subject {subject}` |
| **10024** | `stream external delivery prefix {prefix} must not contain wildcards` |

### What does not work

- **One user in several accounts.** "You cannot use one user to manage multiple streams." A connection
  is bound to one account for its whole life.
- **JetStream on the system account.** The server refuses to boot:
  `[FTL] Not allowed to enable JetStream on the system account` (`server.go:2429`). "The system
  account provides JetStream as a service to all enabled accounts", so it is an overview, never a
  management plane.
- **A shared subject name.** Two accounts using the same string are two different subjects.

## Limits and failure modes

- **The two halves fail asymmetrically, and only one of them is loud.** In **config mode** an import
  with no matching export stops the server at boot:

  ```
  nats-server: nats.conf:2:1: Error adding stream import "orders.shipped": stream import not authorized
  ```

  An export nobody imports is not an error at all — "the server starts, the config is valid, and no
  messages move." In **operator mode both are silent**: "JWT mode has no startup check to catch a
  mismatch." That is a real reason to keep account definitions in config while you are still wiring
  shares.
- **`No responders are available` has two meanings on a service import.** Either the import matched
  and nothing is answering in the exporting account, or there is no import at all and the request
  never left. Both answer immediately; the CLI exits 0 either way.
- **A renamed import is a different subject.** Subscribe to the name the import lands on.
- **No documented ceiling on imports.** Asked in public — "is there a theoretical maximum number of
  imports for a single account? I'm imagining importing thousands of tenants" — and never answered.
  This wiki states no number.

## To verify

- The **exact export/import entries for `$JS.API.>`**, and whether the export can be narrowed to one
  stream. Named by a maintainer, documented nowhere. `synadia-labs/cross-account-jetstream-sourcing`
  is offered in the same thread as a worked example of the *sourcing* route and has not been read.
- Whether **`nats account backup` / `nats account restore`** is the intended migration path between
  accounts. A maintainer says so in [[s-gh-4535-unauthenticated-connections]] and the commands exist
  at natscli v0.4.0 ([[s-natscli-account-tls]]), but no docs page describes the use.
- **Service export `response_type`** and the full import field list are in the generated reference
  under `reference/config/accounts/exports/` and `imports/`, indexed in
  `inbox/config-keys-table.md`, and not yet read.

## Related

[[account]] · [[subject-permissions]] · [[operator-mode]] · [[key-value]] ·
[[mirrors-and-sources]] · [[js-api-subjects]] · [[error-codes]] · [[reload-server-config]] ·
[[nsc]] · [[stream]]

## Sources

[[s-docs-cross-account]] · [[s-gh-5606-cross-account-jetstream]] · [[s-gh-7017-kv-across-accounts]] ·
[[s-nats-server-auth-and-tls]] · [[s-docs-mirrors-and-sources]]
