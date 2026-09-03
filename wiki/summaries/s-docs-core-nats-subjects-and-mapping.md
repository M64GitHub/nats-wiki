---
title: "docs — Core NATS: subjects & wildcards, and account-level subject mapping"
type: summary
area: [core]
source-url: https://docs.nats.io/learn/core-nats/subjects-and-wildcards.md
source-path: raw/nats-docs/learn/core-nats/subjects-and-wildcards.md
author: nats-io docs
article: "learn/core-nats/subjects-and-wildcards.md, learn/core-nats/subject-mapping.md, reference/config/mappings.md (+ mappings/destination.md, weight.md, cluster.md); concepts/subjects.md read and folded"
date: 2026-08-31
version: ""
tags: [subjects, wildcards, tokens, mappings, weight, partition, cluster, reserved-prefixes, whitespace, invalid-subject, nats-server-mappings]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# docs — Core NATS: subjects & wildcards, and account-level subject mapping

Two pages of the *Core NATS deep dive* read as one article — the addressing layer and the server-side
rewrite of it — with the generated `mappings` reference and the `concepts/subjects.md` primer folded in.
**The chapter is unversioned by design** ("This chapter is unversioned and concept-first",
`where-next.md:968`), so every server fact below is pinned by [[s-nats-server-core-delivery]] and
[[s-nats-server-core-delivery-observed]] at v2.14.6, never by this page.

## Key claims

### Subjects (`subjects-and-wildcards.md`)

- A subject is a string of **tokens split by single dots**; the server matches token by token (L12).
  Subjects are **case-sensitive** (L30). "Spaces, tabs, and line breaks aren't allowed anywhere in a
  subject. Stick to letters, digits, `-`, and `_` inside a token" (L32). No length or token-count rule
  is stated anywhere on the page.
- **Subjects cost almost nothing**: the interest graph "holds an entry for a subject only once something
  subscribes to it", so an unsubscribed subject "has no presence on the server at all"; "a system can use
  millions of them", matching walks "the token tree rather than scanning every subscription" (L36).
- **Wildcards are subscriber-only** (L40). `*` matches **exactly one** token, more than one `*` is
  allowed (`orders.*.*`, L54, L229); `>` matches **one or more** tokens and "must be the last token"
  (L233). `orders.>.created` "is invalid: the server rejects the subscription with an Invalid Subject
  error" (L406) — confirmed on 2.14.6, connection kept open (run C1).
- A wildcard subscriber is an ordinary subscriber; delivery stays at-most-once — a late joiner sees
  "everything published *from now on*, not what it missed" (L414).
- **Reserved prefixes** (L418–422): `$SYS`, `$JS`, `$KV`, `$O`, `$SRV` "belong to the server and its
  subsystems"; `_INBOX` is reserved for generated reply subjects. The page does not say the server
  enforces any of them for a plain client — it does not (`$SRV` appears nowhere in `server/*.go`;
  [[s-nats-server-core-delivery]]).
- **Publishing "to a wildcard" produces no error** by default: "the `*` is taken as a literal character",
  a subscriber on the exact `orders.us.created` never sees it, while `orders.*.created` and `orders.>`
  subscribers **do** — "a subscription's `*` matches any single token, including a literal `*`" (L450).
  Confirmed exactly (run C2). What the page does not say: a `pedantic` connection gets
  `-ERR 'Invalid Publish Subject'` **and the message is still delivered** (run C3).
- **Whitespace misroutes**: on the wire a space "separates the subject from the reply subject and byte
  count", so a client that skips the check writes the space into the `PUB` line and "the server silently
  misroutes: `orders.us` becomes the subject and `created` a reply subject" (L454). Confirmed to the
  letter (run A2). The CLI and "most clients" fail first with `nats: invalid subject` (run A3/A4: exit 1).
  The page names the clients that skip it: **nats.py's `publish`** (L454), **the C client** (L493–503), and
  "nats.go before v1.48.0" (L477) — the last confirmed by the v1.48.0 release body (2025-12-17: "Add
  publish subject validation and a connection option to skip it (#1974, #1979)",
  `raw/github-repos/nats-io__nats.go.release-v1.48.0.md`); the first two are the docs' word, unverified here.
- Pitfall (L452): an over-broad `orders.>` "pulls more than you want" — subscribe to the narrowest pattern.

### Account-level mapping (`subject-mapping.md`)

- The server "rewrites a message's subject the moment it arrives, before it looks for interested
  subscribers" (L548); the publisher "gets no signal that a mapping exists" (L574). This is the
  **account-level** mapping; a stream's `subject_transform` and `republish` are a different mechanism on
  [[subject-transforms]] (L552).
- The config: `mappings { orders.placed: orders.created }`, started with `nats-server -c server.conf`
  (L563–571). The top-level block "belongs to the server's built-in account"; "Mapping is always scoped
  to an account" and never crosses accounts (L576). **Reloadable** with `nats-server --signal reload`
  (L578) — confirmed (run F3: `Reloaded: accounts`).
- **Dry run without a server**: `nats server mappings "<source>" "<dest>" <subject>` "runs the same
  transform code the server uses" (L582); `{{wildcard(1)}}` pulls the first `*` token into the
  destination, numbered left to right (L622). All the page's outputs reproduced (run F1).
- **Weighted mapping**: several destinations, "each with a weight from 0 to 100", picked "per message at
  random in proportion" (L626). Weights totalling less than 100 leave "the leftover share" on the
  **source** subject (L644); listing the source itself as a destination "tells the server your weights
  are final and stops it topping them up", so the leftover is **dropped** — "This works because the
  source here is a literal subject" (L646). "Each weight must be 100 or less, and the weights for one
  source must total 100 or less, or the server rejects the config" (L648). All three confirmed: 17 / 200
  at weight 10, 12 of 200 dropped with the source at 90, `total weight needs to be <= 100` at 60 + 50
  (runs F2, F4, F5).
- **Partitioning**: `{{partition(n, 1)}}` hashes the first `*` token into one of `n` buckets, `0`…`n-1`,
  deterministically (L652); the docs' config `"orders.created.*": "orders.created.{{partition(3, 1)}}.{{wildcard(1)}}"`
  sends `ord_8w2k` to bucket 0, `ord_7mn3` to 1, `ord_2zr9` to 2 (L666–678) — reproduced exactly (runs
  F1, F6). Pools subscribe to the bucket subjects; "a subscriber still on the pre-map
  `orders.created.ord_8w2k` receives nothing" (L680; run F7: 0 messages).
- `cluster`: a destination with a `cluster` field "applies only to messages published through a server in
  that named cluster", with fallback to the unscoped mapping (L686).
- Pitfalls: a mapping "quietly changes who receives what" (L770); weights under 100 keep the rest
  (L772); **the partition count is part of the subject contract** — raising `n` reshuffles keys (L774).

### The generated reference (`reference/config/mappings.md` and its three property pages)

- Alias **`maps`**; *Hot Reloadable*; properties `destination` (alias `dest`), `weight` ("A number between
  0 and 100 (inclusive). The string form allows for a trailing `%` sign"), `cluster`. The `weight` page
  adds the one rule the learn page lacks: with `cluster`, "weights across the destinations must add up
  to 100% on a per-cluster basis unless artifical message loss is desired for testing" — which is the
  `tw[d.Cluster]` per-cluster total in `AddWeightedMappings` ([[s-nats-server-core-delivery]]).

### The primer, folded (`concepts/subjects.md`)

Nine tenths of the primer restates the learn page in eight languages. Three lines are its own:
"Subjects are case-sensitive and can contain **any UTF-8 characters** except whitespace, tabs and line
breaks" (L10 — true for routing; the server's rune check runs only on filestore recovery);
"**Keep it reasonable**: Limit to ~16 tokens and under 256 characters total" (L1101 — **no server
limit exists**; `inbox/docs-issues.md` #81); and `_INBOX` listed under "Subjects starting with `$`"
(L1080–1087; #83).

## Practical takeaways

- The server enforces exactly three things about a subject a client sends: no empty token, no
  ` \t\n\f\r`, and `>` only last — on **subscriptions**. A publish subject is checked only in pedantic
  mode, and even then delivered. Everything else (`$` prefixes, `_INBOX`, length, token count) is
  convention, or the optional `max_subscription_tokens`.
- Before mapping a subject that services already use, `/subsz?subs=1&acc=$G&test=<subject>` shows who
  will go silent; `nats server mappings` shows what the rewrite produces; keep a share on the source if
  the old subscribers still need it.
- Choose `partition(n, …)` once. Changing `n` is a re-shard.

## Notable quotes

- "Wildcards are a **subscriber-only** tool." (`subjects-and-wildcards.md:40`)
- "The subject a publisher writes is no longer always the subject a subscriber matches — the server
  config sits in between." (`subject-mapping.md:784`)

## Relevance to the wiki

The addressing rules behind every subject this wiki names, and the only docs treatment of account-level
`mappings` — which the wiki's [[subject-transforms]] page had explicitly declared "a different topic".

## Questions it answers

25 (with [[s-gh-7577-core-nats-ordering]]), 169, 170 (with [[s-gh-5172-mapping-in-config-or-stream]]).

## Pages touched

[[subjects-and-wildcards]] · [[core-nats-delivery]] · [[subject-transforms]] · [[config-keys]] ·
[[defaults-and-limits]] · [[nats-cli]] · [[nats-py]] · [[nats-go]] · [[nats-c]]
