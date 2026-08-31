---
title: "docs — JetStream: Filtering what you consume"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/learn/jetstream/filtering.md
source-path: raw/nats-docs/learn/jetstream/filtering.md
author: nats-io docs
article: "learn/jetstream/filtering.md"
date: 2026-08-31
version: ""
tags: [filter_subject, filter_subjects, overlap, workqueue, cursor, consumer]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — JetStream: Filtering what you consume

A consumer filter, and what it does not do. Short; two facts are worth taking.

## Key claims

**A filter that matches nothing is accepted, silently.** "The server accepts any filter subject, even
one that matches no message in the stream. A typo like `orders.shiped` creates a valid consumer that
never receives anything. **There's no error and no warning, just an empty pull.**" The check is
`nats consumer info` — the `Filter Subject` line against the stream's subjects. `Filter Subject` is
**absent** from the info output when a consumer has no filter: "No filter line means every subject in
the stream."

**Overlap means two different things, and only one of them is an error:**

- *Between* consumers — fine on limits and interest streams: "two separate consumers whose filters
  match the same subject each get their own full copy of those messages." **The exception is
  work-queue retention, where consumers' filters must not overlap each other**
  ([[retention-policies]]).
- *Inside* one consumer — "you can give a single consumer several filter subjects, but if one of
  those subjects already covers another, like `orders.>` next to `orders.shipped`, the create call
  fails with **`consumer subject filters cannot overlap`**. Filters that only partly overlap, where
  neither covers the other, are accepted."

**A filter never removes anything.** "After `analytics` reads `orders.shipped`, every
`orders.created` and `orders.canceled` message is still stored… Don't use a filter to prune a
stream."

**Two consumers, two cursors.** "The server stores the cursor alongside the consumer's config and ack
state, separate from the stream's messages… Neither one moves the other." Adding a consumer "did not
copy any data, it did not slow down `billing`" — the server keeps one copy and serves every consumer
from it. (What that costs at scale is [[jetstream-slows-as-consumers-grow]], which this page does not
mention.)

```
nats consumer add ORDERS analytics --filter "orders.shipped" --pull --ack explicit --defaults
```

## Practical takeaways

- An empty pull is as likely to be a typo in the filter as an empty stream. Check `Filter Subject`
  first.
- A partially-overlapping multi-filter consumer is legal; a fully-covering one is refused with a
  quotable error string.
- Filters are a view, never a retention mechanism.

## Relevance to the wiki

Gives [[consumer]] the exact overlap error and the silent-no-match failure, and gives
[[retention-policies]] the doc's own statement of the work-queue non-overlap rule.

## Questions it answers

No bank row directly.

## Pages touched

[[consumer]] · [[retention-policies]] · [[worker-pool]]

## Sources

The doc page.
