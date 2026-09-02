---
title: "gh#8333 — Is there performance issues possible with a high cardinality subjects for a stream?"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/8333
source-path: raw/gh-discussions/gh-8333.md
author: "@ashumkin (asked); @jnmoyne (maintainer comment, not marked as the answer)"
article: "GitHub Discussion 8333 (General, opened 2026-06-23, one comment 2026-06-24)"
date: 2026-06-23
version: "2.14"
tags: [subjects, cardinality, psim, radix-tree, memory, sizing, filestore]
aliases: []
sources: []
created: 2026-09-02
updated: 2026-09-02
---

# gh#8333 — a million UUID subjects in one stream: what it costs

The question as an architect holds it, and a maintainer's one-paragraph answer with the only public
RAM figure for the per-subject index. Question-bank row 9.

## The question

A file-backed stream on `subject.>`, about **one million** subjects of the form
`subject.<uuid-v4>`, 10 GB and 5–10 days of retention, R3 on a three-node cluster, consumers in
Python (faststream) and Go. *"Is there any performance issues expected because of subject
cardinality? In any case: consuming, subscribing, publishing, cluster startup, RAFT leader election,
etc."*

## The answer (@jnmoyne, 2026-06-24)

> No problem with having a lot of subjects in a stream in terms of performance impact, even with a
> lot more than a million subjects.
>
> The only thing to keep in mind is that the server will use RAM to store its index of subjects
> (radix tree index). It depends on the size of the subjects of course but for something around 1
> million subjects it would be in the order of 100 megs of RAM (with small subjects).

Nothing was said about startup, which is where the server source says cardinality *does* cost
(see [[s-nats-server-filestore-recovery]]): above 1,000,000 subjects the periodic `index.db` is no
longer written, so an unclean stop always means every block is read, and the filtered-read block skip
is switched off. The wiki's measurement on 2.14.6 — 1.2 M seven-digit subjects, RSS **~380 B per
subject** above a 6-subject stream of the same size — is in [[s-nats-server-stream-scale-observed]];
Synadia's published figure is "a few hundred bytes" ([[s-synadia-how-many-subjects]]).

## Practical takeaways

- Budget RAM per distinct subject, not per message: the maintainer's order of magnitude is
  **100 MB per million short subjects**; measured, with the block cache included, nearer 400 MB.
- The number is a *floor* that survives restarts (the index is rebuilt from disk) and does not shrink
  when messages expire until their subjects have no messages left.
- A million subjects is fine for reads, writes and elections; plan the **restart** — see
  [[jetstream-recovery-is-slow]] — and keep the stop clean.

## Relevance to the wiki

Row 9's public answer, from a maintainer, on the version line this wiki verifies. Not marked as the
discussion's answer, so cited as a maintainer comment.

## Questions it answers

Row **9**.

## Pages touched

[[jetstream-sizing]] · [[stream]] · [[filestore-layout]]
