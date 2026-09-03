---
title: "ADR-34 — JetStream Consumers Multiple Filters"
type: summary
area: [jetstream, clients]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-34.md
source-path: raw/adr/ADR-34.md
author: "@Jarema"
article: ADR-34
date: 2023-01-18
version: "2.10"           # shipped in 2.10.0 (#3500)
tags: [adr, filter_subjects, consumer-config]
aliases: [ADR-34]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# ADR-34 — JetStream Consumers Multiple Filters

Approved, 2023-01-18; server PR #3500, shipped in 2.10.0 ([[s-relnotes-2.10]]). A consumer may filter
on several subjects with a new field, `filter_subjects []string`, beside the single `filter_subject`.

## Key claims

- The subjects "can't overlap each other and have to fit the interest of the Stream"; overlapping
  filters are error **10136**; passing both `filter_subject` and `filter_subjects` is **10134**; on
  servers that predate the feature, the new field is ignored, so clients "should check the returned
  info … if the filters are set up properly".
- Server side: "a buffer of first message for each subject filtered", delivered in order, refilled
  per subject — "close to no overhead after the initial buffer".
- Updatable: `filter_subjects` may be changed on an existing consumer, and a consumer may switch
  from `filter_subject` to `filter_subjects` by update (observed on 2.14.6,
  [[s-nats-server-config-mutability-observed]]).

## Practical takeaways

- Positive lists only: to consume "everything except X", enumerate with `subjects_filter` on
  `STREAM.INFO` and list the rest (gh#3944, [[s-gh-3944-subjects-in-a-stream]]).

## Relevance to the wiki

The `filter_subject` / `filter_subjects` rows of [[stream-and-consumer-config]].

## Questions it answers

Row 146 in part.

## Pages touched

[[stream-and-consumer-config]]
