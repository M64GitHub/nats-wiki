---
title: "nats-server v2.14.6 — service imports: the Nats-Request-Info header, share, and the export guards"
type: summary
area: [security, core]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/service-imports-v2.14.6.md
author: nats-server maintainers (source at tag v2.14.6; v2.10.0 for the arrival)
article: "server/accounts.go, client.go, events.go, jetstream.go, jetstream_api.go, stream.go, opts.go — the ranges on service imports"
date: 2026-09-03
version: "2.14.6"
tags: [service-import, Nats-Request-Info, share, ClientInfo, activation, token_req, account_token_position, exports, imports, source]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.14.6 — service imports, from the source

The ranges behind [[service-import-request-info]] and the *Who may import* section of
[[cross-account-sharing]], quoted verbatim with their line numbers in the raw file. The behavioural
half is [[s-nats-server-share-import-observed]].

## Key claims

**The header and the flag.**

- `const ClientInfoHdr = "Nats-Request-Info"` (`accounts.go:163`); a `serviceImport` carries a `share`
  bool (`:183`), copied from the import claim when the import is added: `share = claim.Share`
  (`:2199–2203`). In config mode the key is `share` on an import and is applied to a *service* import
  only (`opts.go:4505–4509`); `SetServiceImportSharing` is its setter, commented "Used for service
  latency tracking at the moment", and refuses claim-based accounts with `claim based accounts can not
  be updated directly` (`accounts.go:1795–1806`).
- `getClientInfo(detailed)` (`client.go:6590–6622`) always sets **`acc` and `rtt`**; with `detailed`
  it adds `start`, `host`, `id`, `name`, `user`, `lang`, `ver`, `jwt`, `issuer_key`, `name_tag`,
  `tags`, `kind`, `client_type`, and the server and cluster names. `detailed` **is** the import's
  `share`. The full `ClientInfo` field list with its JSON names is `events.go:309–333`; `svc` is the
  account a chained import passed through, `reply` the original reply subject.

**Where the header is stamped** (`client.go:4930–4993`, inside `processServiceImport`):

- once per request, never on a response (`if !isResponse`);
- **on a chain the first hop's `share` is kept**: `share := si.share; if hadPrevSi { share =
  c.pa.psi[lpsi-1].share }` (`:4932–4935`), and an existing header is carried forward with
  `Service = acc.Name`; moving into a sharing account or the system account only adds server and
  cluster info (`:4970–4976`);
- a header forwarded by a **leafnode is replaced** with "the identity of the authenticated leaf
  connection instead of trusting forwarded values" (`:4950–4954`);
- the header is written with `c.setHeader` and **no size check** (`:4989–4993`) — issue #8271.
- `checkLeafClientInfoHeader` (`:5756–5783`) rewrites `acc` to the hub-side account name when the
  leaf's remote account is mapped to a different one.

**The mechanism is load-bearing for JetStream.** The system account's `$JS.API.>` import into every
JetStream-enabled account is forced to `si.share = true` — "Capture si so we can turn on implicit
sharing with JetStream layer" (`jetstream.go:787–797`) — and the JetStream API lets a request
without the header through only if it comes from the system account (`jetstream_api.go:809–815`).
A stream **strips** the header before storing a message: "For now remove. TODO(dlc) - Should this be
opt-in or opt-out?" (`stream.go:6354–6358`).

**The three export guards** (`exportAuth{tokenReq, accountPos, approved, actsRevoked}`,
`accounts.go:293–298`), checked in this order by `checkAuth` (`:2863–2882`):

1. nothing set → the export is public;
2. `accountPos > 0` → the import subject's token at that position must equal the importing account's
   name;
3. `tokenReq` → `checkActivation`;
4. otherwise the `approved` map (the config-mode `accounts` list) must contain the importer — a JWT
   export never fills it: `:3606–3625` registers a JWT export with `TokenReq` and
   `AccountTokenPosition` only.

`checkServiceExportApproved` (`:2911–2932`) matches the exact subject first, then any export the
import subject is a subset of. `checkActivation` (`:3044–3087`): the import must carry a `Token`;
the import claim validates; the token decodes; `isIssuerClaimTrusted` (`:3089–3106`) — with
`issuer_account` set it must be this account and the issuer one of its **signing keys**; the token
validates; an expired token fails and, on the first check, a `time.AfterFunc` is armed to drop the
import at `exp`; last, `isRevoked(ea.actsRevoked, act.Subject, act.IssuedAt)`. A JWT export's
`TokenReq` becomes the `tokenAuthReq` sentinel (`authAccounts`, `:3362–3367`) when the account's
exports are registered (`:3606–3625`).

**What the config parsers accept.** Exports: `stream` / `service`, `response_type`, the threshold
aliases `threshold` / `response_threshold` / `response_max_time` / `response_time` (`opts.go:4228`),
`accounts`, `latency`, `account_token_position`, `allow_trace` (`:4255–4283`). Imports: `stream` /
`service`, `prefix`, `to`, `share`, `allow_trace` (`:4480–4514`); `allow_trace` on a service import
is the error `Detected allow_trace directive on a non-stream`.

**The two helpers.** `addServerAndClusterInfo` (`client.go:6563–6580`) sets `server` — the *remote*
server's name when the requester is a leaf — and `cluster`; `getRawAuthUser` (`:6765–6777`) decides
what `user` holds: an NKey login's public key, a username, a **JWT login's user public key**
(`c.pubKey`), or the literal `[REDACTED]` for a bare token.

**Present at v2.10.0**: the header name (`accounts.go:132`), `share = claim.Share` (`:1919`), and the
pre-CVE leaf branch `else if c.kind == LEAF && (si.share || isSysImport)` (`client.go:4200`) that
trusted a forwarded header.

## Practical takeaways

- Without `share: true` on the tenant's import a service sees the tenant **account** and an RTT,
  nothing else; with it, the user, the client name and host, and in operator mode the whole user JWT.
- `share` is decided by the **importing** account's JWT alone; the exporter cannot demand it.
- On a two-hop import the tenant-facing hop decides. Behind a leafnode the header names the leaf
  connection, not the end client, and its `acc` is the hub-side name.
- Only `token_req` leaves the exporter's JWT untouched when an importer joins; `accounts` and any
  revocation rewrite it.

## Notable quotes

- "Used for service latency tracking at the moment." (`accounts.go:1796`)
- "Leaf nodes may forward a Nats-Request-Info from a remote domain, but the local server must
  replace it with the identity of the authenticated leaf connection instead of trusting forwarded
  values." (`client.go:4951–4953`)
- "For now remove. TODO(dlc) - Should this be opt-in or opt-out?" (`stream.go:6355`)

## Relevance to the wiki

The source behind a design decision no docs page covers: whether a service in one account can
identify the *user* in another, and what guards an export. Docs issue #79 (the six undocumented
config keys) rests on the two parser ranges.

## Questions it answers

166, 167, 168 (with [[s-nats-server-share-import-observed]] and [[s-issue-8271-request-info-max-payload]]).

## Pages touched

[[service-import-request-info]] · [[cross-account-sharing]] · [[leafnode]] · [[js-api]]
