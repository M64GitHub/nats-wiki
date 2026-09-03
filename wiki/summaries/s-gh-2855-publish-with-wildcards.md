---
title: "gh#2855 — Could I publish message with wildcards"
type: summary
area: [core]
source-url: https://github.com/nats-io/nats-server/discussions/2855
source-path: raw/gh-discussions/gh-2855.md
author: "@fy2462 (asker), @derekcollison (Synadia)"
article: "GitHub discussion #2855, Q&A, opened 2022-02-09, chosen answer the same day"
date: 2022-02-09
version: ""
tags: [subjects, wildcards, publish, literal]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# gh#2855 — Could I publish message with wildcards

"Could I use some wildcards to broadcast message? `publish_topic: "abc.*.cd.>"`?"

## Key claims

- The chosen answer, in full: "You can only send to literal subjects when publishing. Wildcards are only
  applicable for subscriptions."
- What the thread does not say, and the server shows: a publish to `abc.*.cd.>` is not refused by
  default — it is routed as a literal subject whose tokens happen to be `*` and `>`, so wildcard
  subscribers receive it and literal ones do not; only a pedantic connection gets an `-ERR`, and it is
  delivered anyway ([[s-nats-server-core-delivery-observed]] runs C2, C3).

## Practical takeaways

- There is no broadcast-by-pattern in core NATS. Fan-out is the subscribers' wildcards, not the
  publisher's.

## Relevance to the wiki

The public form of the *Publish-side wildcards* rule on [[subjects-and-wildcards]]; joins row 169.

## Questions it answers

169.

## Pages touched

[[subjects-and-wildcards]]
