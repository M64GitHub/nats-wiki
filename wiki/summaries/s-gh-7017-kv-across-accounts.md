---
title: "gh#7017 — Sharing a KV Store with Multiple Accounts – Is It Supported?"
type: summary
area: [security, kv, jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/7017
source-path: raw/gh-discussions/gh-7017.md
author: "@dkc6gh (asked); no replies"
article: "GitHub Discussion 7017 (Q&A)"
date: 2025-06-29          # opened; no answer as of 2026-08-31
version: ""              # no server version stated
tags: [kv, accounts, imports, exports, unanswered]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#7017 — sharing a KV bucket across accounts

Opened 2025-06-29 and **still has no reply of any kind** as of 2026-08-31. Recorded because an
unanswered question is evidence about the documentation, and because it is the exact question
question-bank row Q51 was mined from.

## The question, in full

> "I have a scenario where a single account owns a KV store, and I'd like to share access to this KV
> store with other accounts, ideally with some restrictions—similar to how JetStream import/export
> settings work. Is it possible to export and import KV stores between accounts in this way? I looked
> for documentation about this but wasn't successful. Since KV is built on JetStream, it seems like
> this should be possible, but I wanted to confirm if this is supported and what the recommended
> approach is."

> "If this is possible, are there any example configurations to try out?"

## Key claims

There are none — nobody answered. What the thread establishes is negative and still useful:

- **The asker searched the docs first and found nothing.** That matches this wiki's own sweep: the
  words `api_prefix`, `deliver_prefix` and the `external` block appear **nowhere** in the 861-page
  docs mirror fetched 2026-08-31, and `learn/security/cross-account.md` covers only subject-level
  stream and service exports.
- **The reasoning in the question is correct.** A KV bucket *is* the stream `KV_<bucket>`
  ([[key-value]]), so the primitives that share a stream are the primitives that share a bucket.
- **"With some restrictions" is the hard part**, and the part with no public answer: a service export
  of `$JS.API.>` is all-or-nothing over the account's whole JetStream API unless the exported subject
  is narrowed by hand.

## Practical takeaways

- **The wiki answers this from adjacent sources, not from this thread.** The two routes —
  importing the owning account's JetStream API under a prefix, and mirroring or sourcing the
  underlying stream with an `external` block — come from [[s-gh-5606-cross-account-jetstream]] and
  the server source ([[s-nats-server-auth-and-tls]]). Both are stated on
  [[cross-account-sharing]] with their limits named.
- **Read access and write access are not symmetric.** A mirror of `KV_<bucket>` in the second account
  gives reads of a copy, with the mirror's lag; it is not the same bucket, and a write there does not
  reach the original.
- **Nobody should have to reverse-engineer this.** The gap is recorded as docs issue #21.

## Relevance to the wiki

Q51's source, and the reason [[cross-account-sharing]] carries an explicit "what no public source
states" section rather than presenting a configuration nobody has confirmed.

## Questions it answers

None directly — it *is* Q51.

## Pages touched

[[cross-account-sharing]] · [[key-value]] · [[account]] · [[mirrors-and-sources]]
