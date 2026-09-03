---
title: "gh#3944 — Getting info about existing subjects in stream"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/3944
source-path: raw/gh-discussions/gh-3944.md
author: "@BinaryArchaism (asker), @derekcollison (chosen answer)"
date: 2023-03-06
version: ""               # pre-2.10; the answer points at what 2.10 would add
tags: [stream-info, subjects_filter, filter_subjects]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# gh#3944 — which subjects does a stream actually hold, and how to consume all but one

A stream on `info.*.>` with a few publishers; the asker wants everything except
`info.first_pub.super_info`, and notes that the stream config shows only the wildcard and the state
only `num_subjects: 6`. Q&A, answered the same day, two upvotes.

## Key claims

- The maintainer: "Consumers with multiple subjects are coming in 2.10" (`filter_subjects`, ADR-34,
  [[s-adr-34-multiple-filters]]) — a positive list, since there is no negative filter — and "The
  StreamInfo call has an option to return subject details for all messages. So you will get a map of
  all subjects with the associated message count."
- That option is `subjects_filter` on `$JS.API.STREAM.INFO.<stream>` (a wildcard; the reply's
  `state.subjects` maps each matching subject to its count, paged with `offset`, `limit` 100000 on
  2.14.6 — [[s-nats-server-config-mutability-observed]] §5); `nats stream info <s> --subjects` and
  `nats stream subjects <s>` wrap it.

## Practical takeaways

- Enumerate with `subjects_filter`, then create the consumer with `filter_subjects` listing
  everything but the excluded subject; new subjects appearing later need the list updated
  (`filter_subjects` is updatable — [[stream-and-consumer-config]]).

## Notable quotes

- "The stream config shows only wildcard subject, but not a real existing one."

## Relevance to the wiki

Row 146's public form; answered by [[stream-and-consumer-config]] and the `subjects_filter` note on
[[js-api-subjects]].

## Questions it answers

Row 146.

## Pages touched

[[stream-and-consumer-config]] · [[js-api-subjects]]
