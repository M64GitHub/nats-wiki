---
title: "gh#6490 — Understanding jetstream warnings (\"has high message lag\")"
type: summary
area: [jetstream, monitoring]
source-url: https://github.com/nats-io/nats-server/discussions/6490
source-path: raw/gh-discussions/gh-6490.md
author: "@astelmashenko and @rajeshkarka (asking), @derekcollison (maintainer, answering)"
article: "Understanding jetstream warnings"
date: 2025-02-10
version: "2.9.19 (reporter); the answer is version-independent"
tags: [message-lag, log-warnings, publish, timeout, ebs, replicas]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#6490 — What `has high message lag` means

The thread behind question-bank **Q62**. **No chosen answer**, but a maintainer answers the actual
question in one paragraph three months after it was asked, on a second reporter's follow-up.

## Key claims

**The symptom.** A 3-node cluster on `2.9.19`, EBS storage, "no high load or anything extraordinary".
An application publish failed with a `timeout` error while the server logged, over and over, roughly
every 5–14 seconds:

```
[61] 2025/02/08 15:25:27.467719 [WRN] JetStream stream '$G > DEFAULT_STREAM' has high message lag
```

interleaved with a consumer leader election. Only a restart cleared it.

**The second reporter's version** (@rajeshkarka, 2025-05-22): a 5-node cluster, R3 stream, the same
warning, "and publisher is becoming slower to push the traffic".

**The answer** (@derekcollison, 2025-05-22):

> "This means you are sending faster then the system can process and store messages into the stream.
> This can happen if you use a core publish into a stream or if you use async Jetstream publishes with
> many publishers."

Two named causes, both about **unacknowledged** publishing:

1. a **core NATS publish** into a stream's subject — fire-and-forget, no `PubAck`, so nothing
   throttles the publisher;
2. **async JetStream publishes** from many publishers at once — each publisher's own in-flight
   window is bounded, but the sum is not.

**Neither reporter got a further reply.** The first reporter's specific question — why it happened
with no load, and why only a restart cleared it — is unanswered.

## Practical takeaways

- The warning is about the **replication** pipeline on the stream leader, not about consumers: it
  fires when proposals accepted from publishers outrun what has been committed and applied locally.
  The threshold is a constant, verified as **10,000** at v2.14.6 in
  [[s-nats-server-jetstream-log-warnings]], and the log line is rate-limited, so its *frequency* is
  not a measure of severity.
- The client-visible partner symptom is the publish `timeout` the first reporter saw — the same shape
  as [[nats-timeout]].
- Both named causes remove the backpressure that a synchronous `PubAck` provides. That makes "did we
  switch a publisher to core NATS or to async publishes" the first question to ask, ahead of disk and
  network.

## Relevance to the wiki

The symptom page is [[stream-has-high-message-lag]], which pairs the maintainer's answer with the
threshold and the exact format string from the server source. It is also the concrete case behind
Q62's broader question about reading JetStream warnings, so that page carries a short table of the
neighbouring warnings read from the same source.

## Questions it answers

- **Q62** — how do I read and act on JetStream warnings in the server log.

## Pages touched

[[stream-has-high-message-lag]] · [[nats-timeout]] · [[replicas]] · [[jetstream-sizing]] ·
[[raft-in-nats]]
