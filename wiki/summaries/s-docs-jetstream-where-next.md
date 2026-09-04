---
title: "docs: the JetStream chapter's closing — stream · consumer · ack, and the one line that says when to reach for a stream"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/learn/jetstream/where-next
source-path: raw/nats-docs/learn/jetstream/where-next.md
author: docs.nats.io
date: 2026-08-31
version: ""
article: "learn/jetstream/where-next.md — the chapter recap and its gathered production checklist"
tags: [stream, consumer, ack, production-checklist, supersedes, chapter-recap]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# docs: the JetStream chapter's closing page

The JetStream deep dive's recap and its **production checklist**: every page's Pitfalls section
gathered into one list, grouped by page. Read for step 7 of
`inbox/plan-the-client-side-2026-09-03.md` because line 53 is the rule of
[[s-docs-core-nats-chapter]] restated from the JetStream side — and because that line **is not where
it says it is** (below).

**Unversioned by design**: "This chapter teaches the ideas and is not tied to a server version. The
exact flags, defaults, and ranges live in **Reference**, which is tied to a version and covers every
option."

## Key claims

- **The three-idea model.** "A **stream** is a log of messages kept on the server. You publish to a
  subject. The server adds the message to any stream that captures that subject… A **consumer** is a
  position marker over a stream… An **ack** is the reader's way of saying a message is handled."
  Everything else — filtering, worker pools, retention, mirrors — "builds on stream, consumer, and
  ack."
- **The line worth quoting** (`:53`, in the *Your first stream* group of the checklist): "**Stay on
  plain pub-sub when the next message supersedes the last; reach for a stream only when a missed
  message has consequences.**"
- **"A stored message has not yet been processed."** The one-sentence separation of the two acks:
  a `PubAck` says stored, a consumer ack says handled. Restated in the *Publishing* group as "Wait for
  delivery and ack before acting on a business outcome; a `PubAck` means stored, not processed."
- **The publish group's three rules**: read the `PubAck` back ("a plain `nats pub` line isn't proof the
  message was stored"); give every retryable publish a stable `Nats-Msg-Id`; treat the `PubAck` as
  storage, not completion.
- **Two consumers on one stream do not interfere**: "Two consumers on the same stream can read the
  same messages at different positions without affecting each other."
- The checklist covers thirteen pages — first stream, publishing, reading back, delivery and
  acknowledgment, filtering, ack responses and redelivery, pull consumers, scaling a consumer,
  ordered consumers, priority groups, pausing, shaping the stream, retention policies, per-message
  TTL — each item linked back to the page that explains it.
- **Sibling chapters** are named as continuations of the same model: key-value ("a key-value bucket is
  a stream underneath. The keys become subjects. The history becomes sequence numbers. A watch is a
  consumer"), object store, clustering, monitoring, backup and recovery.

## A defect in the checklist

The `:53` bullet is filed under "**Your first stream** — see [Pitfalls](/learn/jetstream/your-first-stream.md#pitfalls)",
and that page's Pitfalls section contains exactly two items — *Unlimited defaults grow forever* and
*A stream name is permanent* — neither of which is this rule. `supersede` occurs **twice in the whole
861-page tree**: here, and at `learn/core-nats.md:18`. So the JetStream chapter's own answer to "when
do I need a stream" exists in one gathered checklist item that points at a page which does not state
it. Recorded as `inbox/docs-issues.md` #118.

## Practical takeaways

- Pair the two acks in any design review: `PubAck` = the stream has it; consumer ack = a worker
  finished with it. Most "we thought it was processed" incidents are the gap between them.
- The checklist is the best single artefact in the docs for a production readiness review of a
  JetStream deployment — it is short, each item is falsifiable, and each links to its explanation.

## Relevance to the wiki

The reciprocal half of [[core-or-jetstream]]'s decision rule, and the docs' own words for the two
acks on [[publishing]] and [[ack-and-redelivery]].

## Questions it answers

Row 133 in part.

## Pages touched

[[core-or-jetstream]] · [[stream]] · [[consumer]] · [[ack-and-redelivery]] · [[publishing]]
