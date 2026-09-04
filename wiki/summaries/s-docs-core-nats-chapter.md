---
title: "docs: the Core NATS chapter index — 'core NATS is ephemeral', and when that is exactly right"
type: summary
area: [core, jetstream]
source-url: https://docs.nats.io/learn/core-nats
source-path: raw/nats-docs/learn/core-nats.md
author: docs.nats.io
date: 2026-08-31
version: ""
article: "learn/core-nats.md — the chapter index (its eleven pages have their own summaries)"
tags: [at-most-once, ephemeral, superseded, acme-orders, chapter-map, interest]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# docs: the Core NATS chapter index

The chapter's opening page. Steps 1 and 2 of `inbox/plan-the-client-side-2026-09-03.md` ingested its
substantive pages; this one is summarised on its own for step 7, because its §*Core NATS is
ephemeral* is **the single clearest statement of the core-versus-JetStream rule in the whole docs
tree**, and it is the only place that gives the rule worked examples on both sides.

**Unversioned.** No nats-server version anywhere on the page.

## Key claims

- **The rule, with its examples** (`learn/core-nats.md:18`): at-most-once "behavior is intentional. It
  keeps core NATS small and fast, and it's **exactly right when each message is superseded by the next
  one, such as a live price, a current temperature, or a cache invalidation**."
- **And its converse** (`:20`): "When you need messages to **wait for a subscriber, survive a restart,
  or be replayed later**, you add a stream. That's JetStream, the persistence layer that sits on top
  of core NATS. This chapter is everything that happens *before* you reach for it."
- **What at-most-once means, spelled out** (`:16`): "A message reaches every interested subscriber
  that's connected at the moment of publish, at most once. If a subscriber is offline, restarting, or
  not subscribed yet, it never sees that message. The server does not store it for later."
- **One idea, four patterns**: "That single idea, subjects plus interest, is enough to build four
  communication patterns and the addressing they share" — publish-subscribe, request-reply, queue
  groups, scatter-gather.
- **The running example is deliberately the same one the JetStream chapter continues**: "the Acme
  ORDERS platform, shown at its foundation, **before it adds any persistence**", on
  `orders.created` / `orders.shipped` / `orders.canceled` with a `warehouse`, a `notifications`
  service, an `analytics` pipeline, an `inventory` responder, a `packers` queue group and three
  shipping-quote providers. `learn/jetstream/your-first-stream.md#why-a-stream` picks up the identical
  world and adds `nats stream add ORDERS --subjects "orders.>"`.
- **The chapter map** names the eleven pages and what each teaches, including the two that are
  CLI-only because they are server-side (subject mapping, debugging delivery).
- **Prerequisites are one plain `nats-server`**: "core NATS requires no flags."

## Practical takeaways

- The docs' decision rule is a property of the *message*, not of the system: does the next one
  supersede this one? A price tick, a temperature, a cache invalidation — core. An order, a payment,
  an audit entry — a stream.
- "This chapter is everything that happens *before* you reach for it" is the docs' own statement that
  the two are layers, not alternatives: the JetStream chapter continues the same subjects and the same
  services.
- Because `nats-server` needs no flag for core NATS and `-js` for JetStream, "which one" is also a
  deployment question — and gh#2961 ([[s-gh-2961-js-and-core-one-cluster]]) is the maintainers saying
  it is one cluster, not two.

## Relevance to the wiki

The rule [[core-or-jetstream]]'s decision table is built on, and the docs' own framing for
[[core-nats-delivery]].

## Questions it answers

Row 133 in part (the rule, not the mixed design).

## Pages touched

[[core-or-jetstream]] · [[core-nats-delivery]] · [[stream]] · [[subjects-and-wildcards]]
