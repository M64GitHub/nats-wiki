---
title: "docs.nats.io — Security: where to go next (production checklist)"
type: summary
area: [security]
source-url: https://docs.nats.io/learn/security/where-next.md
source-path: raw/nats-docs/learn/security/where-next.md
author: NATS documentation (Synadia Communications, Inc.)
article: Where to go next
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [checklist, four-questions, centralized, decentralized, hardening]
aliases: [security production checklist]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Security: where to go next

The chapter's closing page: the model in four questions, the two ways to answer one of them, and
the only consolidated security checklist the docs publish.

## Key claims

**Four questions describe any connection's security posture:**

| question | answered by |
|---|---|
| whose traffic is this? | the **account** — the tenant boundary |
| who are you? | the **user** — an identity inside that account |
| what may you touch? | **permissions** — publish and subscribe subject lists |
| who can read the wire? | **TLS** — and with mTLS the certificate can be the identity |

"If you can answer those four questions for a connection, you understand its security posture."

**Both authentication styles produce the same runtime model.** "An authenticated user, scoped to an
account, bound by permissions. They differ only in where the identity lives and who signs it."

- **Centralized** — the list is in the server config; "A change means editing the server's config and
  reloading it (`nats-server --signal reload`) — no restart. It's the right tool for one server and a
  handful of users."
- **Decentralized** — "Adding a user touches no server config at all. It's the right tool when you
  have many tenants, or when teams need to issue their own credentials."
- **Auth callout** is the third answer: "the check can live in whatever identity system you already
  have."

**Four things the chapter explicitly does not cover:** multiple servers (each connection type carries
its own TLS and authentication), leaf nodes specifically, deployment hardening, and JetStream's
stored data. On the last: "Security decides who may access a stream; replication decides whether it's
still there to be accessed."

## The checklist, condensed

The page gathers every Pitfalls section into one list. Grouped as the docs group them:

**Authentication** — give every server a user list; store bcrypt hashes, not plaintext; keep
credentials out of committed config; put them in a named context, never in the connection URL.

**Authorization** — allow `_INBOX.>` on the subscribe side for any user that makes requests; prefer a
wildcard over an enumerated allow-list; "Scope each user to its actual subject prefix — never grant
`>`"; "Check the subscriber's deny lists when messages silently go missing".

**Accounts** — "Point `no_auth_user` at a deliberately narrow user, never a wide-open account";
declare a `SYS` account with a user and set `system_account: SYS`; "Never rely on a shared subject
name to bridge accounts; use an explicit export/import."

**Cross-account** — pair every export with its import; match the type to the flow (`stream` one way,
`service` request/reply); subscribe to the remapped subject when an import uses `prefix:` or `to:`.

**Operator mode** — "Run `nats auth account push` after every account change — including user
revocations and signing-key changes, which live in the account JWT"; keep the system account
configured; `0600` on `.creds` files; monitor credential expiry if you set one.

**Decentralized auth** — back up the operator offline before building on it; "Configure the server
with the operator JWT — public material only — never a private seed"; sign users with a scoped
signing key, not the account root seed; mint credentials with a deliberate expiry and a re-issue
plan.

**Auth callout** — run more than one `auth-svc` and set `timeout` deliberately; list only `auth-svc`
in `auth_users`; run it in its own account and reach for `xkey`.

**Encryption & TLS** — add `verify` or `verify_and_map`; match the mapped user string to the
certificate identity read with `openssl x509 -noout -subject`; configure TLS on cluster, leafnode and
gateway blocks too; give each cluster certificate both `serverAuth` and `clientAuth`; migrate to
TLS-first with a duration value before setting `true`; "Rotate certificates ahead of expiry and send
`nats-server --signal reload` afterwards; certificate files are read once at startup"; keep the
JetStream encryption key out of the config file and carry `prev_key` for one restart only.

## Practical takeaways

- The checklist is the closest thing the docs have to a security review sheet, and every item traces
  back to a named failure on another page.
- The teardown instruction is worth copying for anyone following the chapter on a workstation: stop
  the server, delete the scratch configs, certificates and JetStream store, "and remove the operator
  store".

## Notable quotes

> "Both produce the same runtime model."

> "Use this chapter to understand how the pieces fit; use the reference for the exact field, type,
> and default."

## Relevance to the wiki

The spine of the wiki's `security` area: the four questions map one-to-one onto [[account]],
[[operator-mode]], [[subject-permissions]] and [[tls-in-nats]], and the checklist items are the
pitfalls those pages carry.

## Questions it answers

None on its own — it is the index over the chapter.

## Pages touched

[[account]] · [[subject-permissions]] · [[operator-mode]] · [[tls-in-nats]] · [[auth-callout]] ·
[[cross-account-sharing]] · [[rotate-tls-certificates]] · [[set-up-operator-mode]]
