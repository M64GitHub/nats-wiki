---
title: "gh#7577 — Message ordering guarantees in core NATS"
type: summary
area: [core]
source-url: https://github.com/nats-io/nats-server/discussions/7577
source-path: raw/gh-discussions/gh-7577.md
author: "@Marko19907 (asker), @jnmoyne and @derekcollison (Synadia)"
article: "GitHub discussion #7577, Q&A, opened 2025-11-24, chosen answer the same day"
date: 2025-11-24
version: ""
tags: [ordering, core-nats, publisher-connection, fifo, interleaving]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# gh#7577 — Message ordering guarantees in core NATS

The thread behind question-bank row 25, answered by two maintainers within the day. One server, one
publisher connection publishing `m1`, `m2` on `foo`, `m3` on `bar`, `m4` on `foo`; one subscriber
connection with a subscription on each subject. Is order per subject, or global across subjects?

## Key claims

- **Order is per publisher connection, across all subjects.** "For Core NATS the ordering is guaranteed
  per publisher (connection): if a publisher uses a single connection to publish m1, m2, m3 then everyone
  subscribing to the subject(s) will see the messages in that order … This is true no matter what
  subjects the messages are published on (i.e. m1 m2 and m3 can be on any subject, the server processes
  the messages in the order it receives them from the client connection)" — @jnmoyne.
- **Several publishers interleave.** "there could be more than one publisher at the same time so their
  publications could get interlaced, but you will always see m2 after m1 and m3 after m2" — @jnmoyne.
- **The asker's restatement, confirmed**: a single publisher connection's messages reach each subscriber
  connection "in that same order, so that's one FIFO stream across subjects, and then the client library
  just demuxes them to the appropriate subscription callbacks" — "Yes for a single publish connection
  order will always be preserved globally" (@derekcollison, the chosen answer).

## Practical takeaways

- One connection per producer that needs order; two connections — or two producers — give you two
  interleaved streams, with no cross-stream promise.
- The docs' "doesn't guarantee that two subscribers see messages in the same order under load"
  ([[s-docs-core-nats-publish-subscribe]]) is the *between-publishers* complement of this, not a
  contradiction: each subscriber sees each publisher's sequence in order, and different subscribers may
  see the publishers' sequences interleaved differently.
- What the thread does not cover — and no source read here does — is what a queue group hand-off, a
  route hop or a reconnect do to that order; the page states those from the mechanism, not from this
  thread.

## Notable quotes

- "Yes for a single publish connection order will always be preserved globally." — @derekcollison

## Relevance to the wiki

The one public maintainer statement of core NATS's ordering rule, in the exact form an architect asks
it; the basis of the *Ordering* section of [[core-nats-delivery]].

## Questions it answers

25.

## Pages touched

[[core-nats-delivery]] · [[publishing]]
