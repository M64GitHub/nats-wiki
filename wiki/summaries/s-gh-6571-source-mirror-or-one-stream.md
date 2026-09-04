---
title: "gh#6571 — Source plus mirror, or one stream with two consumers"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/6571
source-path: raw/gh-discussions/gh-6571.md
author: "@nrapendra-singh (asker); @jnmoyne (maintainer, chosen answer)"
date: 2025-02-24
version: ""
article: "GitHub discussion 6571, Q&A, chosen answer, 1 comment and 2 replies, 1 upvote"
tags: [mirror, source, retention, workqueue, limits, large-stream, per-subject-index, fast-and-slow-consumer]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# gh#6571 — Which NATS JetStream Setup is Better?

The public form of question-bank **row 114**, posed the way an architect poses it: two designs written
out with their own pros and cons, asking which is right. The maintainer's answer rejects the premise.

## The question

@nrapendra-singh, 2025-02-24. One stream, two consumers — a fast real-time one and a slow analytics
one. **Approach 1**: a WorkQueue source stream (messages deleted once the real-time consumer acks)
plus a Limits **mirror** kept for analytics — "keeps the source stream lightweight for fast
processing", at the cost of duplication and cluster resources. **Approach 2**: one Limits stream, both
consumers on it — simpler, but "Stream can grow large, potentially slowing down real-time processing."

## Key claims

- **The premise is wrong, and that is the answer**: "**It's not because a stream is larger that
  delivery of messages to consumers takes longer**, therefore approach 2 is simpler, more efficient
  and doesn't have the Cons you list."
- **Asked what a large stream *does* cost**, the answer names one thing and only one: "Mostly increased
  memory usage if you have a lot of different subject being used in the stream (**the servers maintain
  per subject indexing**)."
- So the cost of a big stream is **subject cardinality**, not message count — the same axis as gh#4170
  and gh#8333, arrived at from the opposite direction.

## Practical takeaways

- Do not build a second stream to keep the first one small. A second stream is for a different
  retention, a different replication or a different location — not for performance.
- The "fast consumer and slow consumer on one stream" shape is supported by design: consumers are
  independent cursors, and a slow one does not hold the fast one back. What a slow consumer *does*
  hold is the stream's data under Interest or WorkQueue retention — which is why the asker's instinct
  to combine WorkQueue with a second reader was going to fail anyway (see [[s-gh-4499-workqueue-fanout-retention]]).
- The one real cost named — per-subject index memory — is a **subject design** consequence, so row 114
  and row 109 meet here.

## Notable quotes

> "It's not because a stream is larger that delivery of messages to consumers takes longer, therefore
> approach 2 is simpler, more efficient and doesn't have the Cons you list." — @jnmoyne, 2025-03-02

> "Mostly increased memory usage if you have a lot of different subject being used in the stream (the
> servers maintain per subject indexing)." — @jnmoyne, 2025-03-02

## Relevance to the wiki

Bank row 114's asked form. The public statement that a replication shape is not a performance tool,
which the *when not to use it* half of a replication-design page needs.

## Questions it answers

Row 114, in part — when a second copy is **not** the answer; row 110 in part.

## Pages touched

[[mirrors-and-sources]] · [[retention-policies]] · [[consumer]] · [[stream-topology-design]]
