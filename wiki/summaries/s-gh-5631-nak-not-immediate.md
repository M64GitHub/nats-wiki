---
title: "gh#5631 — Nak does not immediately lead to a message redelivery"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/5631
source-path: raw/gh-discussions/gh-5631.md
author: "@funkye (asked); nobody replied"
article: "GitHub Discussion 5631 (Q&A)"
date: 2024-07-09          # opened; still no comment of any kind as of 2026-09-01
version: "2.10.14"        # the reporter's server version
tags: [nak, redelivery, ack_wait, unanswered, dotnet]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# gh#5631 — a nak that did not redeliver immediately, and nobody ever answered

Opened 2024-07-09 and **still has no comment of any kind** as of 2026-09-01 — two years and no
reply. Recorded because it is the question question-bank row 18 was mined from, and because the wiki
answers it from the binary rather than from the thread.

## The question, in full

> "In some cases in our product, Nak does not immediately lead to a message redelivery. Instead, the
> message is sent again after the accept timeout. However, I do not have any error when calling the
> Nak client method in problematic cases. The internal fields of the 'msg' class become the same as
> in the case of successful execution of Nak."

> "I also cannot reproduce the problem separately from the product and cannot understand what
> additional actions lead to this behavior."

Server version **2.10.14**, C# client **1.0.4**.

## Key claims

There are none — nobody answered. What the report establishes is the shape of the symptom, and it is
precise enough to be useful:

- The redelivery **does** happen, but at `ack_wait` rather than at once.
- **The nak returns no error**, and the client-side message object looks identical to the working
  case. So nothing on the client tells the operator anything.
- It is **intermittent** and could not be reproduced in isolation.

## Practical takeaways

- **A nak is fire-and-forget**, which is why there is nothing to see: the client publishes to the
  message's `$JS.ACK.…` subject and does not wait for a reply. Any reason the server declines to act
  on it is invisible from the client side.
- **One mechanism at v2.14.6 produces exactly this symptom**, found while settling row 18
  ([[s-nats-server-nak-backoff-observed]]): on a consumer with a `backoff`, a nak that carries a
  delay is redelivered after `delay + (BackOff[dc] − BackOff[0])`, not after `delay` — and that holds
  even when the delay is **zero**. Measured: `-NAK {"delay":0}` on a consumer with
  `backoff` `[5s, 10s, 15s]` came back after **4.94 s** and then **9.94 s**, while a bare `-NAK` on
  the same consumer came back in **0.00 s**. Since the server forces `ack_wait` to the first backoff
  entry, "the redelivery arrives about an ack-timeout late" is precisely what that looks like. **The
  trigger is whether the client sends anything after `-NAK`**: an empty options object counts, so a
  library that always serialises its nak options takes the delayed path for what its API calls a
  plain nak.
- **Why no error is ever reported**, whatever the cause: a nak is fire-and-forget, and `processNak`
  discards one whose delivery is out of range (`dseq <= o.adflr || dseq > o.dseq`) or whose message
  is no longer pending, with no reply and no log line. There is nothing for a client to surface —
  which matches "I do not have any error when calling the Nak client method" exactly, and means the
  absence of an error is not evidence the nak was acted on.
- **This is not confirmed to be the reporter's cause.** Their server is **2.10.14**, only v2.14.6 was
  run, they never say whether the consumer had a backoff, and no reproduction exists. The wiki states
  the mechanism, names the version it was observed on, and says the original report is unanswered.

## Relevance to the wiki

Question-bank row 18. It is also why row 18 is answered by a page that states two candidate
mechanisms and their limits rather than by a claim about this thread: the honest answer to "why
doesn't my nak redeliver immediately" is "here are the two ways the server can do that to you at
2.14.6, and nobody ever diagnosed the 2.10.14 report."

## Questions it answers

None directly — it *is* row 18.

## Pages touched

[[ack-and-redelivery]] · [[consumer]]
