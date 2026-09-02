---
title: "gh#7032 — Maximum known-good value for MaxMsgs in a JetStream stream"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/7032
source-path: raw/gh-discussions/gh-7032.md
author: "@asymmetric (asked); @jnmoyne (chosen answer)"
article: "GitHub Discussion 7032 (Q&A, opened 2025-07-03, answered 2025-09-25)"
date: 2025-07-03
version: "2.11"
tags: [max_msgs, limits, event-store, stream-size, sharding, ordered-consumer, sizing]
aliases: []
sources: []
created: 2026-09-02
updated: 2026-09-02
---

# gh#7032 — the largest known-good `MaxMsgs`: no such number, because there is no hard limit

Question-bank row 5, answered by a maintainer: streams are bounded by resources, not by a count,
and the mitigation when a resource runs out is to shard by time.

## The question

An event store that should "~never be discarded" so any new consumer can replay from the beginning:
~100-byte events, ~5 M per year (~0.6 GB with overhead), `LimitsPolicy`, R3. *"I was considering
running a stream without a `MaxMsgs` — or a very large one, that would allow me years of runway
before hitting any hard limits. […] How long before I'd hit a hard limit? Are there people who have
configured streams in such a way, and what were the pitfalls?"*

## The answer (@jnmoyne, chosen)

> Many people use streams with no limit or a very large one, and store equivalent (or larger)
> message sets without a problem. You should be able to test this for yourself easily by using
> `nats bench` to generate a large amount of small messages into a stream and then to see for example
> how fast you can get them back from the stream and at the same time monitor resource usage on your
> servers. There is no hard limit to the size of a stream, but practically you will eventually run
> out of some kind of resource, be it disk space or memory space on the servers (as they maintain
> some per subject indexing). At that point you can investigate ways to shard onto multiple streams
> (e.g. you could have a stream per year, or decade) and then deploy more servers in your cluster to
> continue scaling up.
>
> For quick replay of a lot of messages (presented to you in order) consider using 'ordered'
> consumers.

## Practical takeaways

- **Leave `max_msgs` at −1** for a never-discard stream; a "very large" value buys nothing and
  costs a reservation estimate when `max_msg_size` is also set ([[s-nats-server-filestore-recovery]]).
- The two resources that bound it: **disk** (the stream's bytes × replicas, per node —
  [[jetstream-sizing]]) and **RAM for the per-subject index** (per distinct subject, not per message
  — [[s-gh-8333-high-cardinality-subjects]]). Restart time is the third, unmentioned here
  ([[jetstream-recovery-is-slow]]).
- The design move when one runs out: **one stream per period** (year, decade), and more servers.
- Replay from the beginning with an **ordered consumer**.

## Relevance to the wiki

The public statement that no known-good figure exists, which is what makes row 5 *answered* rather
than `no-public-answer`. Also a source for the event-store shape in phase G's stream-design pages.

## Questions it answers

Rows **5** and, together with [[s-gh-7147-one-billion-cap]], **4**.

## Pages touched

[[stream]] · [[jetstream-sizing]] · [[retention-policies]]
