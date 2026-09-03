---
title: Cross-account sharing
type: concept
area: [security, jetstream, kv]
since: [2.10]   # present at v2.10.0 (share and the request-info header, accounts.go:132,1919); not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-09-03
tags: [exports, imports, stream-export, service-export, prefix, to, external, api-prefix, 10021, 10022, 10024]
aliases: [exports, imports, export, import, cross-account, account import, account export, activation token, api prefix, external]
sources: [s-docs-cross-account, s-gh-5606-cross-account-jetstream, s-gh-7017-kv-across-accounts, s-nats-server-auth-and-tls, s-docs-mirrors-and-sources, s-docs-object-store-under-the-hood, s-docs-authorization, s-docs-security-checklist, s-gh-5941-restrict-leafnode-subjects, s-gh-7881-cross-domain-sourcing, s-natscli-stream-external, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12, s-relnotes-2.14, s-nats-server-service-imports, s-nats-server-share-import-observed, s-jwt-imports-exports-activation, s-nsc-imports-exports-activation, s-natscli-auth-exports-imports, s-docs-config-accounts-exports-imports, s-nats-server-request-reply-observed, s-nats-server-request-reply]
created: 2026-08-31
updated: 2026-09-03
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

**Import and export permissions are a property of the account, not of a user** (source:
[[s-docs-authorization]]). No permission edit on a user opens or closes a boundary; the three rules
worth checking on every share are the security checklist's: pair every export with its import, match
the **type** to the flow (`stream` one way, `service` request/reply), and subscribe to the remapped
subject when an import uses `prefix:` or `to:` — plus the negative rule, "Never rely on a shared
subject name to bridge accounts; use an explicit export/import" (source:
[[s-docs-security-checklist]]).

**What the exporting side learns about the caller** is a header, not a permission: on every request
that crosses a service import the server stamps `Nats-Request-Info` with the requester's account, and
with the user too when the *importing* account's import carries `share: true` — the switch a
multi-tenant service turns on per tenant. The header, its two shapes, the first-hop rule on chained
imports and the `max_payload` edge are on [[service-import-request-info]] (source:
[[s-nats-server-service-imports]]; [[s-nats-server-share-import-observed]]).


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

## Who may import: the three export guards

An export with nothing set is public. Three settings on the **export** narrow it, and the server tries
them in a fixed order (`checkAuth`, `accounts.go:2863–2882`): the account-token position first, then
the activation token, then the account list (source: [[s-nats-server-service-imports]]). **Only two of
the three exist in operator mode**: a JWT export has `token_req` and `account_token_position` and no
account list at all — `accounts: [A, B]` is a config-mode key (source:
[[s-jwt-imports-exports-activation]]; `accounts.go:3606–3625` registers a JWT export with nothing but
those two). They differ in the one thing that matters when tenants come and go — **whose
definition changes**:

| guard | on the export | on each import | the exporter's definition changes when an importer joins? |
|---|---|---|---|
| `accounts: [A, B]` — **config mode only** | the list | nothing | **yes**, every time (a config edit and a reload) |
| activation token | `token_req: true` (`nsc add export --private`) | `token`: an activation JWT the exporter issued to *this* importer | **no** on join; **yes** on revocation (`revocations` lives on the export) |
| account token position | `account_token_position: <n>` on a wildcard subject (`nsc add export --account-token-position`, `nats auth … --token-position`) | the import subject must carry the importer's own account key at token `n` | **no**, and no token to mint |

**The activation token** is a JWT whose `sub` is the importing account's public key, with
`nats.subject` = the subject it may import, `nats.kind` = stream or service, optional `nbf` / `exp`,
and `issuer_account` = the exporting account when a **signing key** signs it. The exporter mints it —

```
nsc add export --account FABRIC --service --subject "api.>" --private
nsc generate activation --account FABRIC --subject "api.>" --target-account <tenant-account-key> --output-file tenant.jwt
```

— and the importer puts it into its import (`nsc add import --account TENANT --token tenant.jwt`);
`nsc` fills the subject, the type and the source account from the token and refuses one meant for
another account (source: [[s-nsc-imports-exports-activation]]). The server then checks, on every
import (`checkActivation`, `accounts.go:3044–3087`): the token decodes; its issuer is the exporting
account or one of its signing keys; its `sub` is the importer; the import subject is contained in the
token's; it has not expired — and when it does the server drops the import on a timer, no JWT push
needed; and the importer is not in the export's `revocations` (source:
[[s-nats-server-service-imports]]; the field rules in [[s-jwt-imports-exports-activation]]).

Two tooling limits: `nats auth` 0.4.0 has `--token-position` and `--share` but **no `--private` and
no activation command** — a private export still needs `nsc` on the same store (source:
[[s-natscli-auth-exports-imports]]); and `nsc` refuses `--private` together with
`--account-token-position` ("account token position is only valid for public exports")
(source: [[s-nsc-imports-exports-activation]]).

**In config mode** the same export accepts `accounts`, `latency`, `response_type`,
`response_threshold`, `account_token_position` and `allow_trace`, and an import accepts `prefix`,
`to`, `share` and `allow_trace` (`opts.go:4228–4283`, `4480–4514`); the generated docs reference lists
four keys on each side and none of `share`, `allow_trace`, `latency`, `response_threshold` or
`account_token_position` — docs issue #79 (source: [[s-docs-config-accounts-exports-imports]];
[[s-nats-server-service-imports]]). There is no activation token in config mode; the `accounts` list
is the guard.


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

**An [[object-store]] bucket is the same problem with a better-shaped surface.** The docs put it
plainly — "exporting the bucket to another account" is a security concern, "not an object-store one"
(source: [[s-docs-object-store-under-the-hood]]) — and the bucket's data plane is two ordinary subject
spaces, `$O.<bucket>.C.>` for chunks and `$O.<bucket>.M.>` for metadata. That means an export can be
split: a consuming account granted only `$O.<bucket>.M.>` can watch the bucket's inventory without
being able to read a single object's bytes ([[subject-permissions]]). Nothing public documents this
being done, so it is a shape the mechanism allows, not a recipe anyone has published — and the
control-plane caveat above still applies, because listing needs `$JS.API.CONSUMER.*` too
([[js-api-subjects]]).

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

**The `nats` CLI's two interactive branches are the clearest statement of what the block needs**, and
they differ in exactly the way that matters here (source: [[s-natscli-stream-external]], natscli
v0.4.0):

| | across a **domain** | across an **account** |
|---|---|---|
| API prefix | mechanical — the CLI composes `$JS.<domain>.API` from the domain name | **required**, and it is "the prefix where the foreign account JetStream API **has been imported**" — a *local* subject |
| delivery prefix | optional | **required**, likewise a local subject |

So the account branch states the precondition the docs never do: **the `external` block does not
create the import, it names the local prefix an existing import already lives under.** Route 1 is not
an alternative to Route 2 here — for the cross-account case it is a *prerequisite*.

**And the error you get without it names the missing half.** From a supercluster-plus-leafnodes setup
whose accounts had the shape right but no export on the far side:

```
Error adding service import "$JS.leaf01a.API.CONSUMER.CREATE.tank": service import not authorized
```

`CONSUMER.CREATE` is request/reply, so it must be a **service** export — the type rule above, failing
in the loud direction for once. That thread has **no maintainer reply** and its one community
suggestion ("export the `$JS.API.>` subjects … import those subjects into the same account") is
unaccepted, which is the honest state of this whole area (source:
[[s-gh-7881-cross-domain-sourcing]]; [[cross-domain-sourcing]]).

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

**Where this turns up unexpectedly: leafnodes.** In config mode a leafnode's `authorization` users
cannot carry permissions at all, so the only boundary available is the account — bind the leaf remote
to an account (`leafnodes.remotes[].account`) and the hub-side leaf user to the matching account
(`leafnodes.authorization.users[].account`), and **that account's imports and exports decide what
crosses the link**. Everything on this page is therefore the answer to "how do I restrict which
subjects a leafnode shares", in config mode (source: [[s-gh-5941-restrict-leafnode-subjects]];
[[leafnode]], [[subject-permissions]]).

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

## No responders across an import — since 2.10.26

The two-meanings rule above holds from **2.10.26**. Before it, a request through a service import
whose exporting account had no interest was **dropped silently** and the requester timed out; the
release body: "Publishing through a service import to an account with no interest will now generate
a 'no responders' error instead of silently dropping the message" (#6532, "A request through a
service import with no interest should return no responders") (source: [[s-relnotes-2.10]]). That is
the older behaviour the maintainer answer on discussion #4761 describes — a request over an import
never failed fast, because the import itself was a subscription — and why on 2.10.26 and later it
does. 2.10.28 added that "it is now possible with service imports to import the same subject from
multiple different accounts" (#6704).


### Run on 2.14.6 — the 503 crosses the import, and names the importer's subject

Row 150's question, on the binary (run G, source: [[s-nats-server-request-reply-observed]]): account
`APP` importing service `svc.check` from `SVC` with nobody subscribed in `SVC` got `No responders are
available` in 37 ms, exit 0 — the fast failure #6532 promised, not a timeout. On the wire the reply
was `HMSG _INBOX.x 1 41 41` with `Nats-Subject: svc.check`; with the import renamed `to: inv.stock` it
carried **`Nats-Subject: inv.stock`** — the subject the requester published, not the exporter's (the
server formats the header from the published subject, `client.go:4510–4511`, source:
[[s-nats-server-request-reply]]). With a responder in `SVC` both imports answered; a subject `APP`
never imported was no responders too. So on 2.14.6 the two meanings above are told apart only by what
*else* is true — an import that does not exist and an export with nobody listening produce the same
503 — and the request/reply mechanics are on [[request-reply]].


## Version notes: the 2.11 line

**Since.** `since: [2.10]` in the frontmatter means *present at 2.10, the oldest line this wiki covers*:
the 2.10 release bodies patch imports and exports from v2.10.17 on and none records the arrival, which is
older than the archive (source: [[s-relnotes-2.10]]).

- **2.11.2**: the same subject may be imported from several accounts (#6704, the 2.10.28 backport);
  a deadlock updating account claims with imports and exports fixed (#6726) (source:
  [[s-relnotes-2.11]]).
- **2.11.9**: subject interest propagated to leaf nodes "when daisy chaining imports/exports"
  (#7255). **2.11.12**: a subscription leak in a cluster when an import/export overlaps the `$JS.>`
  namespace (#7720). **2.11.15**: CVE-2026-33246 ("systems using leafnodes and service imports");
  messages from leafnodes to non-shared service imports rebuild the request-info header — the
  leafnode spoofing of `Nats-Request-Info`, on [[service-import-request-info]].


### The 2.12 line

- **2.12.0**: "No responders errors from the server now include the original subject in the
  `Nats-Subject` header" (#5250) — a requester behind an import can now see which subject had no
  responder (source: [[s-relnotes-2.12]]).
- **2.12.6**: "a bug which could result in the service import cycle detection failing to detect a
  genuine cycle" fixed (#7961). **2.12.12**: **service-import replies are delivered across cluster
  routes** (#8317); message tracing works with imports and exports.


## To verify

- The **exact export/import entries for `$JS.API.>`**, and whether the export can be narrowed to one
  stream. Named by a maintainer, documented nowhere. `synadia-labs/cross-account-jetstream-sourcing`
  is offered in the same thread as a worked example of the *sourcing* route and has not been read.
- Whether **`nats account backup` / `nats account restore`** is the intended migration path between
  accounts. A maintainer says so in [[s-gh-4535-unauthenticated-connections]] and the commands exist
  at natscli v0.4.0 ([[s-natscli-account-tls]]), but no docs page describes the use.

### The 2.14 line

**2.14.3**: **service-import replies can now be delivered across cluster routes** (#8317) — an import
whose responder sat on another node could lose the reply; message tracing works with service imports
and exports (source: [[s-relnotes-2.14]]). **2.14.4**: consumer-reset responses are no longer dropped
when sent through a service import (#8407). **2.14.6**: removal from service-import response maps is
constant-time (#8463). The v2 ack subjects (2.14.0, `js_ack_fc_v2`) are the reason an export or
import of `$JS.ACK.<stream>.>` must be rewritten before the default flips ([[js-api]]).


## Related

[[account]] · [[subject-permissions]] · [[operator-mode]] · [[key-value]] ·
[[mirrors-and-sources]] · [[js-api-subjects]] · [[error-codes]] · [[reload-server-config]] ·
[[nsc]] · [[stream]] · [[cross-domain-sourcing]] · [[jetstream-domain]] · [[leafnode]]

## Sources

[[s-docs-cross-account]] · [[s-gh-5606-cross-account-jetstream]] · [[s-gh-7017-kv-across-accounts]] ·
[[s-nats-server-auth-and-tls]] · [[s-docs-mirrors-and-sources]] ·
[[s-docs-object-store-under-the-hood]] · [[s-docs-authorization]] ·
[[s-docs-security-checklist]] · [[s-gh-5941-restrict-leafnode-subjects]] ·
[[s-gh-7881-cross-domain-sourcing]] · [[s-natscli-stream-external]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]] · [[s-nats-server-service-imports]] · [[s-nats-server-share-import-observed]] · [[s-jwt-imports-exports-activation]] · [[s-nsc-imports-exports-activation]] · [[s-natscli-auth-exports-imports]] · [[s-docs-config-accounts-exports-imports]] · [[s-nats-server-request-reply-observed]] · [[s-nats-server-request-reply]]
