---
title: "docs.nats.io — Retention policies"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/learn/jetstream/retention-policies.md
source-path: raw/nats-docs/learn/jetstream/retention-policies.md
author: NATS documentation (Synadia Communications, Inc.)
article: Retention policies
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [retention, workqueue, interest, limits]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Retention policies

The three `retention` values, the kind of work each fits, and the two ways Interest and WorkQueue
bite in production.

## Key claims

- A stream has exactly one retention policy, set by the `retention` field. Three values:
  - **`limits`** (the default) — messages stay until `MaxMsgs`, `MaxBytes` or `MaxAge` removes
    them, whichever comes first. Consumers reading and acking has **no effect** on what the stream
    keeps.
  - **`interest`** — a message is removed once *every* consumer whose filter covers it has acked
    it. A message published on a subject **no consumer is interested in is dropped immediately**.
  - **`workqueue`** — a message is removed as soon as *one* consumer acks it. The first ack
    removes it for everyone.
- The one question that separates them: **who decides a message is finished.** Under `limits`, the
  limits do; under `interest`, every consumer must ack; under `workqueue`, the first ack.
- **Limits still apply under all three.** Retention removes a message when consumers are done with
  it; the stream's limits remove it when the stream grows too old or too large. On an Interest or
  WorkQueue stream the limits are the backstop that keeps it bounded when consumers fall behind.
- **Retention is effectively fixed at creation.** The server allows exactly one live change:
  `limits` ↔ `interest`, in either direction. Anything involving `workqueue` is refused with
  `stream configuration update can not change retention policy to/from workqueue`.
- **Even the allowed swap rewrites history.** Switching a `limits` stream to `interest` makes the
  server remove, from that moment, any message every consumer has already acked and any message on
  a subject no consumer is interested in — including history you meant to keep.
- **WorkQueue rejects overlapping consumers.** A second unfiltered consumer fails with
  `multiple non-filtered consumers not allowed on workqueue stream` (error **10099**); two
  consumers whose filters overlap fail with `filtered consumer not unique on workqueue stream`
  (error **10100**). A wildcard filter such as `fulfill.>` overlaps `fulfill.us` and `fulfill.eu`
  and is rejected.
- **Interest can fill the disk.** A message is removed only when every consumer whose filter
  covers it has acked. A stalled consumer holds up cleanup for every message it still owes an ack
  on, and the stream grows until it hits its limits or runs out of room. Interest retention still
  needs limits set, and it makes consumer health monitoring more important.
- To scale a single workload on a WorkQueue stream, add **workers to one consumer**, not more
  consumers. Several consumers are only valid when their filters **partition** the subjects, and
  each then handles only its slice.

## Practical takeaways

- Pick the policy from the kind of work: audit log or event history → `limits`; fan-out where
  every consumer must process each message → `interest`; job queue where each message is work for
  one worker → `workqueue`.
- Do not plan a migration that edits retention into or out of `workqueue`. Create a new stream
  with the policy you want and move the data.
- `natscli` accepts both `work` and `workq` as aliases for the `workqueue` value.

## Commands the page uses

```
nats stream add FULFILLMENT --subjects "fulfill.>" --retention work --defaults
nats stream info FULFILLMENT
nats consumer add FULFILLMENT us-shippers --pull --ack explicit --filter "fulfill.us" --defaults
nats consumer add FULFILLMENT eu-shippers --pull --ack explicit --filter "fulfill.eu" --defaults
nats stream edit FULFILLMENT --retention limits --force   # rejected
```

## Relevance to the wiki

The primary source for [[retention-policies]], and for the retention half of [[stream]]. The two
failure modes (Interest filling the disk behind a stalled consumer; WorkQueue refusing overlapping
consumers) are the two that turn into support threads.

## Questions it answers

Q20 (several consumers sharing a durable name with different filters on a WorkQueue stream), Q21
("disjoint filter subjects").

## Pages touched

[[retention-policies]] · [[stream]] · [[consumer]]
