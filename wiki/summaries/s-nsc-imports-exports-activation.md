---
title: "nsc v2.15.0 — add import --share / --token, add export --private, generate activation"
type: summary
area: [security]
source-url: https://github.com/nats-io/nsc/tree/v2.15.0/cmd
source-path: raw/nsc-src/import-export-activation-v2.15.0.md
author: nats-io/nsc maintainers (source at tag v2.15.0, the latest release on 2026-09-03)
article: "cmd/addimport.go, cmd/addexport.go, cmd/generateactivation.go — the flags and the claims they write"
date: 2026-09-03
version: "nsc v2.15.0"
tags: [nsc, import, export, share, private, activation, account-token-position]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nsc v2.15.0 — the commands that write `share`, `token_req` and an activation

`nsc` is not installed on this machine; the flags are read from the source at the release tag. The
fields it writes are defined in [[s-jwt-imports-exports-activation]].

## Key claims

- **`nsc add import`** (`addimport.go:41–49`): `--token <path or URL>` "(private imports only)",
  `--local-subject`, `--src-account`, `--remote-subject` "(only public imports)", `--service`,
  **`--share`** "share data when tracking latency (service only)", `--allow-trace`. With a token,
  `initFromActivation` (`:366–396`) fills the subject, the type and the source account from the token
  and refuses one meant for someone else: `activation is not intended for this account - it is for
  %q`. `--share` on a stream is `only services can set the share property` (`:477–482`);
  `createImport` (`:542–560`) sets `Share` only on a service and stores a URL token by reference.
- **`nsc add export`** (`addexport.go:45–55`): **`--private`** "private export - requires an
  activation to access" becomes `TokenReq` (`:97`); **`--account-token-position`** "subject token
  position where account is expected (public exports only)"; the two together are `account token
  position is only valid for public exports` (`:279–281`). The report says `added private service
  export …` (`:349–353`).
- **`nsc generate activation`** (`generateactivation.go:40–45`): `--subject`, `--target-account`,
  `--output-file`, `--push` "push activation token to operator's account server", and the time
  flags. The claim (`:221–239`): `sub` = the target account, `name` = the subject,
  `nats.subject`, `nats.kind` = the export's type, `nbf` / `exp` from the time flags, and
  `issuer_account` = the account when the signer is a **signing key** rather than the account key.

## Practical takeaways

- Minting a token touches no JWT: it is signed by the exporting account's key and handed to the
  importer, who puts it into their import with `--token`.
- `--private` and `--account-token-position` are alternatives, never combined.
- `nats auth` v0.4.0 has `--share` and `--token-position` but no `--private` and no activation
  command ([[s-natscli-auth-exports-imports]]): a private export still needs `nsc` on the same store.

## Notable quotes

- "share data when tracking latency (service only)" (`addimport.go:48`)
- "private export - requires an activation to access" (`addexport.go:45`)

## Relevance to the wiki

The runnable form of the export guards for [[cross-account-sharing]] and the `nsc` cheat sheet.

## Questions it answers

167 (with [[s-jwt-imports-exports-activation]]); 166 (the `--share` flag).

## Pages touched

[[nsc]] · [[cross-account-sharing]] · [[service-import-request-info]]
