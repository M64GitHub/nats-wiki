---
title: "jwt v2.8.2 — Import.Share, Export.TokenReq, AccountTokenPosition, and the activation claim"
type: summary
area: [security]
source-url: https://github.com/nats-io/jwt/tree/v2.8.2/v2
source-path: raw/jwt-src/imports-exports-activation-v2.8.2.md
author: nats-io/jwt maintainers (source at tag v2.8.2, the version nats-server v2.14.6 pins)
article: "v2/imports.go, v2/exports.go, v2/activation_claims.go — the structs and validators"
date: 2026-09-03
version: "jwt v2.8.2 (nats-server 2.14.6)"
tags: [jwt, import, export, share, token_req, activation, account_token_position, revocations, source]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# jwt v2.8.2 — the import, the export and the activation, as the account JWT carries them

The library that defines what an account JWT can say about sharing; the server reads these structs
([[s-nats-server-service-imports]]) and `nsc` writes them ([[s-nsc-imports-exports-activation]]).

## Key claims

- **`Import`** (`imports.go:19–43`): `name`, `subject`, `account`, `token`, `to` (deprecated for
  `local_subject`), `type`, **`share`**, `allow_trace`. The comment on `subject`: for a service it is
  "the account making the request (the importer)" side of the mapping.
- **`Import.Validate`** (`:58–113`): `share` on anything but a service is the error
  `sharing information (for latency tracking) is only valid for services`; `allow_trace` is for stream
  imports only; an activation token must decode, its issuer or `issuer_account` must be the import's
  `account`, its `sub` must be the account the import is written into ("activation token doesn't
  match account it is being included in"), its `kind` must match the import type, and the import
  subject must be contained in the token's subject.
- **`Export`** (`exports.go:111–124`): `subject`, `type`, **`token_req`**, `revocations`,
  `response_type`, `response_threshold`, `service_latency`, **`account_token_position`**,
  `advertise`, `allow_trace` — and **no account list**: the config-mode `accounts` guard has no JWT
  form; a JWT export is public, token-guarded, or position-guarded.
- **`Export.Validate`** (`:153–201`): latency and a response threshold are for services;
  `account_token_position` needs a wildcard subject and must point at a `*` token.
  `Revoke` / `RevokeAt` / `ClearRevocation` (`:203–222`) keep revocations **on the export**, keyed by
  the revoked account's public key with a timestamp.
- **`Activation`** (`activation_claims.go:28–35`): `subject` (the import subject), `kind`
  (stream or service), `issuer_account` "when set, the claim was issued by a signing key". An
  `ActivationClaims` is a JWT whose `sub` must be a public **account** key (`:78–85`); an account or
  an operator key may sign it (`ExpectedPrefixes`, `:128–132`).

## Practical takeaways

- `share` and `token` are fields of the **importing** account's JWT; `token_req`, `revocations` and
  `account_token_position` of the **exporting** account's. Revoking an importer therefore rewrites
  the exporter's JWT; issuing a token does not.
- A token names one importer, one subject and one kind; it cannot be reused for another account.

## Notable quotes

- "sharing information (for latency tracking) is only valid for services" (`imports.go:89`)

## Relevance to the wiki

The field-level truth behind [[cross-account-sharing]]'s export guards and
[[service-import-request-info]]'s `share`; the reason docs issue #80 (activation tokens on no docs
page) is a gap and not a nuance.

## Questions it answers

166, 167.

## Pages touched

[[service-import-request-info]] · [[cross-account-sharing]] · [[operator-mode]] · [[nsc]]
