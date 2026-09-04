---
title: "gh#4170 — Subject indexing and ordering internals"
type: summary
area: [jetstream, core]
source-url: https://github.com/nats-io/nats-server/discussions/4170
source-path: raw/gh-discussions/gh-4170.md
author: "@Zetanova (asker); @derekcollison (maintainer, chosen answer); @kerimcharfi (2025 follow-up)"
date: 2023-05-16
version: "2.9, with improvements promised for 2.10"
article: "GitHub discussion 4170, Q&A, chosen answer, 2 comments and 6 replies, 1 upvote"
tags: [subject-index, cardinality, filtered-consumer, ordering, event-sourcing, aggregate, sparse-subjects]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# gh#4170 — Subject Indexing and Ordering Internals

The public form of question-bank **row 109**, asked by someone designing an event-sourcing store and
worried about year three rather than day one. Chosen answer by @derekcollison two days later.

## The question

@Zetanova, 2023-05-16, three questions the docs did not answer: how does JetStream index subjects for
filtered consumers; how does it perform with a lot of unique subject names **over a long period**; and
does `a.s1.eventType1` and `a.s1.eventType2` give the same ordering guarantee as publishing only to
`a.s1`. The stated shape: "The unique AggregateRoot-Id count can reach view millions of entries per
year… a single AR is only used/appended over a short period of time (days) and for a good
EventSourcing store the index/subject count should not effect the performance of the 'tail' stream."

## Key claims

- **There are two lookup keys, and only two.** "We have meta state that allows us to index efficiently
  by sequence number **and by subject**." Later, plainly: "Within JetStream, you have two options,
  lookup by sequence or by subject."
- **Cardinality is a memory cost, stated as such**: "Currently the subject addressing layer to a stream
  **takes more memory the more unique subjects that you have**. We are working to make this more memory
  friendly in future releases and plan to have some improvements in 2.10. For now it will work just
  needs memory to hold the state."
- **Ordering**: "For JetStream yes, all consumption through consumers will be globally ordered. For
  NATS core the only ordering guarantee is **per publishing connection**." The asker's reaction is
  itself evidence: "In the doc is only `publisher` mentioned. I didn't substitute `publisher` with
  `connection`."
- **Subject design is the lever**: "Its mostly in how you want to define all possible sets within a
  stream and make sure they represent tokens in the subjects. We will expand the abilities for
  filtering messages beyond subjects in the future, but for now this can be powerful with a bit of
  work designing the subject space."
- **The asker's own design, left unanswered**: `events.{tenant}.{arType}.{arId}.{eventType}` with
  tenant 2–10, arType 5–15, **arId 10,000–2,000,000**, eventType 5–40; the journal query
  `events.{boundary}.*.{arType}.{arId}.>` from a start sequence.
- **The 2025 follow-up is the sharpest question in the thread and has no reply at all** (@kerimcharfi,
  2025-07-27): how much memory per stream; can JetStream handle millions of individual streams; "How
  exactly are they indexed? (subject -> (startSeq, endSeq) will **suck on sparse subjects** with
  messages over a large interval)"; is there a skip scan; "Can we walk backwards (looking for history)
  efficiently?"

## Practical takeaways

- The subject space is the query language. A token that is not there cannot be filtered on later
  without re-publishing, so token *order* and token *presence* are the design decision — and the
  maintainer says so directly.
- Per-subject state costs memory that grows with **distinct subjects**, not with messages. An entity
  id in a subject is a design that buys per-entity replay with per-entity memory.
- The unanswered 2025 questions map exactly onto what this wiki has measured elsewhere:
  [[jetstream-recovery-is-slow]] on more than a million subjects, [[consumer-slow-on-a-sparse-stream]]
  on the sparse-subject case, and [[filestore-layout]] on `index.db`. The public record stops where
  this wiki's runs start.

## Notable quotes

> "Currently the subject addressing layer to a stream takes more memory the more unique subjects that
> you have." — @derekcollison, 2023-05-18

> "For NATS core the only ordering guarantee is per publishing connection." — @derekcollison,
> 2023-05-18

## Relevance to the wiki

Bank row 109's asked form and the maintainer's frame for it: two lookup keys, subjects as the set
definition, memory as the cost. Also a second, independent maintainer statement of the core ordering
rule that [[core-nats-delivery]] carries from gh#7577.

## Questions it answers

Row 109, in part; row 144 in part (the event-sourcing framing); corroborates row 25.

## Pages touched

[[subjects-and-wildcards]] · [[filestore-layout]] · [[core-nats-delivery]]
