---
title: "gh#6746 — Watch different keys without creating a watcher for each key?"
type: summary
area: [kv, jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/6746
source-path: raw/gh-discussions/gh-6746.md
author: "@pablitovicente (asking and self-answering)"
article: "Watch different keys without creating a watcher for each key?"
date: 2025-03-31
version: "not stated; multiple filter subjects require nats-server 2.10+"
tags: [kv, watch, filter-subjects, self-answered]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#6746 — One watcher, several keys

The thread question-bank **Q69** was mined from. It is short, **self-answered within the hour**, and
it is worth recording mainly because it shows what the row actually asked — the row's wording had
drifted into a second question ("misses updates") that this thread never raises.

## Key claims

**The question.** Keys that do not share a stable prefix, so `subset.*` does not cover them:

> "I have a use case on which I need to watch different keys that might not follow a stable pattern
> like `subset.*` is there a way to watch keys without creating a watcher for each of these keys as I
> suspect that can be taxing on the NATS server?"

with the shape he wanted:

```javascript
natsSDk.watch('foo', 'bar', 'baz')
```

instead of three separate `watch()` calls.

**The answer, from the asker** (marked as the answer):

> "Oh I should have checked https://nats-io.github.io/nats.js/kv/types/KvWatchOptions.html it seems
> this is already supported... will close after validating."

**The suspicion in the question is correct and is the reason the answer matters.** A KV watcher is an
ephemeral [[ordered-consumer]] on the bucket's stream, so one watcher per key is one consumer per key.
Several keys on **one** watcher become several **filter subjects** on **one** consumer — which is what
[[key-value]] already states from ADR-8, and what makes the difference between one consumer and *n*.

## Practical takeaways

- Multiple keys on one watcher is a **client-side** feature name (`KvWatchOptions` in nats.js) over a
  **server-side** capability: multiple filter subjects on a single consumer, which requires
  nats-server **2.10** or later. A client on an older server, or a client that has not implemented it,
  will still open one consumer per key.
- Filter-subject count is not free either: [[jetstream-slows-as-consumers-grow]] records the ~300
  filter threshold. One watcher over thousands of keys is not the answer; a wildcard that covers them
  is.
- The asker never posted the validation. Treat the answer as the documented client capability, not as
  a confirmed measurement.

## Relevance to the wiki

Answers the real **Q69** ("watch many keys without one watcher per key"), which [[key-value]] already
states. The scale half of the KV-watcher problem is a different thread — [[s-gh-5243-kv-watchers-at-scale]] —
and the page for it is [[kv-watchers-stall-the-cluster]].

## Questions it answers

- **Q69** (as corrected) — how do I watch many keys at once without one watcher per key.

## Pages touched

[[key-value]] · [[ordered-consumer]] · [[kv-watchers-stall-the-cluster]] ·
[[jetstream-slows-as-consumers-grow]]
