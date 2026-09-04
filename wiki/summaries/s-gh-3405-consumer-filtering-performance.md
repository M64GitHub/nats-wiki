---
title: "gh#3405 — Consumer filtering performance"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/3405
source-path: raw/gh-discussions/gh-3405.md
author: "@baldugus (asker); @derekcollison (chosen answer), @jnmoyne"
date: 2022-08-25
version: "2.9 (the answer names the 2.9 RC)"
article: "GitHub discussion 3405, Q&A, chosen answer, 1 comment and 2 replies, 2 upvotes, closed 2023-11-10"
tags: [filtered-consumer, table-scan, subject-index, replay, one-big-stream]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# gh#3405 — Consumer Filtering Performance

The public form of question-bank **row 111**, and the thread that states the fact the whole
"one big stream" design rests on.

## The question

@baldugus, 2022-08-25, having already reached the right conclusion and wanting the cost: "I thought of
using NATS with multiple streams consuming overlapping subjects, but soon realized the right way to do
it is by having a big stream with multiple consumers filtering the subjects." The worry is replay: a
stream on `foo.bar.>` with a million messages, a new consumer filtering `foo.bar.baz.xyz` with **one
matching message in the middle** — "would it go through the whole stream to find this message? Does it
have some sort of index?"

## Key claims

- **@derekcollison** (chosen answer, same day): "We have put alot of work into making that efficient.
  Try out the 2.9 RC … and test out to verify."
- **@jnmoyne** expands, and this is the load-bearing sentence: "**no the sever doesn't do like a table
  scan over all of the messages in the stream** and things indexing are used to make operations to
  find the first and last message(s) in a stream very efficient indeed."
- The asker never benchmarked it — "I'm yet to mark this as the answer because i didn't find the time
  to benchmark the 2.9 RC" — and the thread was closed 2023-11-10 with the answer marked anyway. **No
  number was ever published in it.**

## Practical takeaways

- A filtered consumer over a sparse filter is an indexed seek, not a scan. That is what makes
  "one stream, many filtered consumers" the default rather than a compromise.
- The answer is **four years and five minors old** (2.9, 2022) and was never measured in public. Treat
  it as the shape of the mechanism, not as a current performance claim; it needs re-running on the
  release in front of you.
- "First and last message" is the phrasing that matters: the index gives a per-subject range, which is
  why the cost of a filtered read tracks the *span* of a subject in the sequence space rather than the
  stream's size. [[consumer-slow-on-a-sparse-stream]] is what happens when that span is the whole
  stream and the interior is mostly deletes.

## Notable quotes

> "no the sever doesn't do like a table scan over all of the messages in the stream and things
> indexing are used to make operations to find the first and last message(s) in a stream very
> efficient indeed." — @jnmoyne, 2022-09-01

## Relevance to the wiki

Bank row 111's asked form. The public basis for "filtering is indexed", which every recommendation of
one-stream-with-filters depends on and which no page of this wiki had cited.

## Questions it answers

Row 111, in part — the mechanism, with no numbers and at 2.9.

## Pages touched

[[consumer]] · [[filestore-layout]] · [[jetstream-slows-as-consumers-grow]]
