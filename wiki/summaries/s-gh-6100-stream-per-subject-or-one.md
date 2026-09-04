---
title: "gh#6100 — Stream per subject, or one stream with many subjects"
type: summary
area: [jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/discussions/6100
source-path: raw/gh-discussions/gh-6100.md
author: "@YashasAnand (asker); @Jarema (maintainer, chosen answer)"
date: 2024-11-11
version: ""
article: "GitHub discussion 6100, Q&A, chosen answer, 3 comments, 2 upvotes"
tags: [stream-count, stream-per-subject, raft-overhead, filtered-consumers, consumer-leader, retention]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# gh#6100 — Does Stream Per Subject have any performance benifits over multiple subjects within same stream

The public form of question-bank **row 108**, asked at the smallest scale it has: 100 subjects, and
should that be 100 streams or one. Chosen answer by @Jarema the same day.

## The question

@YashasAnand, 2024-11-11: "If i have 100 subjects, is it ideal to create 100 streams … or is it
better to have 1 stream with 100 subjects with subject filters?" — with the asker's own test already
in hand: on one stream with 100 subjects, "even if 1 consumer goes down, it does not block the other
unique messages arriving on diffrent subject filters."

## Key claims

- **The default is one stream.** "Many Consumers per single Stream is usually the simple and good
  pattern as a starting point. **It's rarely a good idea to have stream per subject.**"
- **The cost of the alternative is named, and it is Raft**: "Each Stream, if replicated (3 or more
  replicas) will have some overhead for maintaing its own RAFT group." No figure is given for that
  overhead — only its existence and its condition (`R>1`).
- **Filtering is the reason one stream works**: "NATS with it's unique subject wildcards and filters
  allows for efficient filtering messages from the stream."
- **The one stated exception**: "I would stick to one stream, **unless you need different retention
  policies for some subjects** for example." Retention is a stream property, so a subject that needs a
  different one needs its own stream.
- **Consumers scale across the replica set, not on the leader**: "each consumer leader (if replicated)
  can live on different Stream replica, balancing the load."
- **The follow-up is refused.** Asked for documentation of how JetStream manages consumers in the
  one-stream case, @Jarema points at the clustering docs, then: "For info how subjects are handled by
  a consumer, **you would need to dig the source code**. We, at Synadia, also provide consulting…"

## Practical takeaways

- Start with one stream per namespace and many filtered consumers; reach for a second stream when a
  subject needs a **different retention, replication or storage** setting — a per-asset property, not
  a performance one.
- "Stream per subject" is the anti-pattern with a name in this thread; "stream per *tenant*" is a
  different question and gets the opposite public answer (see
  [Synadia's per-tenant FIFO post](https://www.synadia.com/blog/nats-jetstream-per-tenant-fifo-processing),
  scouted 2026-09-04). Neither answer is measured, which is why this wiki measures it.
- The Raft overhead is per **replicated** stream. At R1 the argument in this thread does not apply —
  which does not make many streams free, only differently priced.

## Notable quotes

> "It's rarely a good idea to have stream per subject." — @Jarema, 2024-11-11

> "Each Stream, if replicated (3 or more replicas) will have some overhead for maintaing its own RAFT
> group." — @Jarema, 2024-11-11

## Relevance to the wiki

The maintainer's default for bank row 108, and the only public statement of *why* — the per-stream
Raft group. The exception it names (different retention per subject) is the hinge the answer turns on.

## Questions it answers

Row 108, in part — the default and its reason, with no numbers.

## Pages touched

[[stream]] · [[raft-in-nats]] · [[retention-policies]]
