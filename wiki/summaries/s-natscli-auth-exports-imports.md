---
title: "nats CLI 0.4.0 — nats auth account exports add and imports add: the flags"
type: summary
area: [security]
source-url: https://github.com/nats-io/natscli
source-path: raw/nats-cli/help-auth-account-exports-imports-0.4.0.md
author: this wiki (the two --help texts captured verbatim from nats CLI 0.4.0, 2026-09-03)
article: "nats auth account exports add --help; nats auth account imports add --help"
date: 2026-09-03
version: "nats CLI 0.4.0"
tags: [nats-cli, nats-auth, exports, imports, share, token-position]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats CLI 0.4.0 — `nats auth account exports add` / `imports add`

The flag lists behind the operator-mode examples on [[cross-account-sharing]], captured because no docs
page lists them.

## Key claims

- **`exports add [<flags>] <name> <subject> [<account>]`**: `--description`, `--url`,
  **`--token-position`** "The position to use for the Account name", `--advertise`, `--service`
  "Sets the Export to be a Service rather than a Stream". **No `--private`** and no activation
  command anywhere under `nats auth`.
- **`imports add [<flags>] <name> <subject> [<account>]`**: `--source` "The account public key to
  import from", `--local`, **`--share`** "Shares connection information with the exporter",
  `--traceable` "Enable tracing messages across Stream imports", `--service`.

## Practical takeaways

- `nats auth` can set `share` on a service import and `account_token_position` on an export; for a
  private export and its activation tokens use `nsc` on the same store
  ([[s-nsc-imports-exports-activation]]).
- The CLI's wording — "Shares connection information with the exporter" — is the plainest public
  description of what `share` does.

## Notable quotes

- `--share              Shares connection information with the exporter`

## Relevance to the wiki

The `nats auth` half of the commands on [[cross-account-sharing]] and the `nats` cheat sheet.

## Questions it answers

166, 167 (the tooling side).

## Pages touched

[[nats-cli]] · [[cross-account-sharing]] · [[service-import-request-info]]
