---
title: "gh#7590 — Automatic Message Payload Preservation in DLQ Stream"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/7590
source-path: raw/gh-discussions/gh-7590.md
author: "@Atanusaha143 (proposed); @ripienaar (maintainer); @jgriegershs, @ravithejatech714-create"
article: "GitHub Discussion 7590 (Ideas)"
date: 2025-11-28          # opened; still open, no answer chosen, last comment 2026-08-29
version: "2.12"
tags: [dead-letter, advisories, max_deliver, workqueue, payload, unresolved]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# gh#7590 — the advisory has no payload, and why the server will probably not add one

The dead-letter pattern's sharpest edge, argued out in public: the max-deliveries advisory carries
**metadata only**, so a DLQ built from advisories holds pointers, not messages. Opened 2025-11-28,
**still open** with no chosen answer; a maintainer explains why the obvious fix is resisted, and a
later commenter disputes the premise.

## Key claims

**The problem, with the evidence.** The reporter's DLQ stream captures
`$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.<stream>.<consumer>` and each stored message decodes to:

```json
{"type":"io.nats.jetstream.advisory.v1.max_deliver","id":"UCWRuls4iaD5xCOChWg8ju",
 "timestamp":"2025-11-14T07:03:51.861113678Z","stream":"booking_stream",
 "consumer":"booking_consumer","stream_seq":10,"deliveries":5}
```

"The advisory only contains metadata… but **no original message payload**", so it is impossible to
"inspect the actual message content that caused the failure", reprocess it, or keep an audit trail.
Following the documentation's own advice — use the sequence number to fetch the message — gave them
`Error: message not found (stream_seq: 10)`.

**Why a payload-carrying advisory is resisted** (@ripienaar, 2025-11-28): "We have considered this
before but has quite a lot of user feedback that this is a bad idea **due to the payloads potentially
being sensitive and DLQ advisories going to different locations outside of nats**. It might be
something that would make sense as a per consumer opt in though." Asked what the plan is: "I don't
think there is a plan per se. We have many feature requests and do prioritisation twice a year or so…
A fast way to make progress would be to contribute something via a pull request."

**The premise is disputed** (@jgriegershs, 2026-02-09): on a `workqueue` stream a message is removed
only when acked or expired, so on hitting `max_deliver` "it stays in the worker queue and an advisory
is emitted… enabling fetching the dead-lettered message with `nats s get my-work-queue
msg-seq-from-advisory` **including the payload**. As far as I can tell, this works with v2.12.4 and R1
streams. **With R3, messages might get lost** (I am about to create an issue for that)."

## What the server actually does

Settled on the binary rather than left as a disagreement
([[s-nats-server-nak-backoff-observed]], the addendum): on **v2.14.6, R1**, a message that exhausts
`max_deliver` **survives on both `workqueue` and `limits` streams** and is fetchable by the sequence
the advisory names. The advisory fires with `stream_seq` and `deliveries`, and
`nats stream info` still counts the message. **@jgriegershs is right.**

**And the R3 loss was a real defect, now fixed.** Issue
[#7817](https://github.com/nats-io/nats-server/issues/7817), *"Messages Lost with JetStream,
work-queue Retention and R3 on max-deliver reached [v2.12.4, v2.12.3]"* — opened 2026-02-11, closed
2026-02-18 by PR [#7845](https://github.com/nats-io/nats-server/pull/7845), *"[FIXED] Preserve max
delivered messages with WorkQueue retention"*. The fix shipped in **v2.12.5**: *"Ensure that messages
that have reached the max deliver state are preserved with the WorkQueue retention policy (#7845)."*

So the reporter's `message not found` was most likely this bug on 2.12.3/2.12.4 with R3 — which makes
the thread a **documentation-and-version problem** rather than a missing feature.

## Practical takeaways

- **Do not expect a payload in the advisory**, and do not expect that to change: the objection is
  privacy, and it is a considered position rather than a backlog item.
- **The fetch-by-sequence recipe works** — on 2.14.6, and on 2.12.5 and later where the R3 defect is
  fixed. On 2.12.3/2.12.4 with R3 it can silently return nothing.
- **A DLQ handler should copy the payload at capture time.** Even with the defect fixed, the window
  between the advisory and the fetch is bounded by retention on `workqueue` and `interest` streams
  ([[s-synadia-reliable-delivery-dlq]]).
- **The operational requirement is stated well by the last commenter** (2026-08-29): "a DLQ is only
  useful if operators can inspect the failed payload, retain provenance, decide whether it is safe to
  retry, and replay it with an audit trail."

## Relevance to the wiki

Half of what makes [[dead-letter-queue]] worth writing: the pattern is not just "capture the
advisory", it is "capture the advisory **and copy the message before it can go**", and the reason the
server will not do it for you is on the record.

## Questions it answers

Row 107.

## Pages touched

[[dead-letter-queue]] · [[advisories]] · [[retention-policies]] · [[ack-and-redelivery]]
