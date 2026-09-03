---
title: "gh#5097 — Subject token limit"
type: summary
area: [core]
source-url: https://github.com/nats-io/nats-server/discussions/5097
source-path: raw/gh-discussions/gh-5097.md
author: "@albionb96 (asker), @MauriceVanVeen (Synadia)"
article: "GitHub discussion #5097, Q&A, opened 2024-02-16, chosen answer the same day"
date: 2024-02-16
version: ""
tags: [subjects, tokens, limit, 16-tokens, docs]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# gh#5097 — Subject token limit

A user read the docs' "keep the maximum number of tokens in your subjects to a reasonable value of 16
tokens max" and asked whether it means 16 characters per token or 16 tokens per subject.

## Key claims

- The maintainer's answer: tokens, not characters — "The `.` separates tokens. Should indeed keep that at
  a reasonable value and not go overboard with the amount of tokens. That way the server can guarantee
  performance of subjects up to that maximum, **although it's probably not strictly enforced** it would
  have performance impact."
- The figure is the docs' guidance, and the server does not enforce it: at v2.14.6 there is **no**
  default token or length limit on a subject; the only bounds are `max_control_line` (4096 bytes for the
  whole `PUB` line) and the optional `max_subscription_tokens`, which applies to subscriptions
  ([[s-nats-server-core-delivery]]). The current docs give the number as "~16 tokens and under 256
  characters" with no source (`concepts/subjects.md:1101`; `inbox/docs-issues.md` #81).

## Practical takeaways

- Design subjects for the filters and the filestore, not for a 16-token ceiling that does not exist;
  what token count costs is on [[subjects-and-wildcards]].

## Relevance to the wiki

The public form of question-bank row 169, and evidence that the unsourced docs figure confuses readers.

## Questions it answers

169.

## Pages touched

[[subjects-and-wildcards]]
