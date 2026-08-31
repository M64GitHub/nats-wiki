---
title: "gh#5044 — Prevent a NATS user from creating durable consumers"
type: summary
area: [security, jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/5044
source-path: raw/gh-discussions/gh-5044.md
author: "@pontus-andersson-wowgroup (asked); @derekcollison, @0xeb-bp"
article: "GitHub Discussion 5044 (Q&A)"
date: 2024-02-06          # opened; no answer chosen, last reply 2025-01-31
version: ""              # no server version stated
tags: ["$JS.API.CONSUMER.CREATE", permissions, durable, ephemeral, websocket, unresolved]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#5044 — stopping untrusted clients from creating durable consumers

Opened 2024-02-06, **no answer chosen**, and reopened by a second person in 2025 who could not make
the suggested approach work. Recorded with its limits stated, because the honest answer to Q52 is
partly "you cannot, cleanly".

## Key claims

**The problem.** Browser clients over WebSocket need JetStream history, "However, I am worried that
giving clients that I don't control access to the jetstream API will allow them to create durable
consumers that will take up resources on the servers."

**The lever is the subject, as always.** The asker found the extended create subject himself:

> "The closest I have gotten is to only allow the user/client to publish to this subject
> `$JS.API.CONSUMER.CREATE.<stream>.*.<subject>`. This limits what subjects the user can see, however,
> this still allows the user to create durable consumers."

**The maintainer's answer** (@derekcollison, not marked as the answer):

> "Yes, you can add in the allow permission that create extended version you want to allow and
> disallow the plain `$JS.API.CONSUMER.CREATE.<stream>`"

On restricting *which* subjects a user may consume: "You can, via delivery subject restrictions for
push consumers. For pull consumers, possible but a bit more involved to construct."

**The follow-up that undermines it.** A year later, @0xeb-bp reported that on their server **both**
kinds of consumer are created on the same subject shape, so the durable/ephemeral distinction is not
visible in the subject at all:

```
Received on "$JS.API.CONSUMER.CREATE.test_stream.test123"
{"stream_name":"test_stream","config":{…,"durable_name":"test123","name":"test123",…}}
```

```
Received on "$JS.API.CONSUMER.CREATE.test_stream.qTVy35Ay"
{"stream_name":"test_stream","config":{…,"name":"qTVy35Ay",…}}
```

The durable name is in the **payload**, not the subject — and subject permissions cannot see a
payload. The older `$JS.API.CONSUMER.DURABLE.CREATE.<stream>.<consumer>` subject, which *would* have
been separable, is not what modern clients use. Nobody answered this, and the thread ends there.

**A wish stated and not granted:** "It would be nice if I could just set constraints during stream
creation for the allowed consumer types and limits, but I don't see that as an option."

## Practical takeaways

- **Subject permissions cannot distinguish a durable from an ephemeral consumer** on a modern client,
  because both use `$JS.API.CONSUMER.CREATE.<stream>.<name>` and the difference is in the request
  body. Any rule built on the older `DURABLE.CREATE` subject only catches clients that still send it.
- **What subject permissions *can* do** is narrow the blast radius: allow the filtered create subject
  `$JS.API.CONSUMER.CREATE.<stream>.*.<subject>` and deny the unfiltered
  `$JS.API.CONSUMER.CREATE.<stream>`, which pins the filter the consumer may use.
- **The account is the real limit.** Per-account JetStream limits — `max_consumers` among them — are
  the enforceable control, and they bound resource use regardless of who creates what. That is the
  answer this thread never reaches.
- **Consider not exposing the API at all.** Direct Get and a republish subject give untrusted clients
  history with no consumer to create ([[direct-get]]), which is the approach
  [[jetstream-slows-as-consumers-grow]] argues for on capacity grounds too.

## Notable quotes

> "I am missing how I can restrict the ability for end user's to create durable consumers."
> — @0xeb-bp, ending the thread

## Relevance to the wiki

Q52's source. The row stays **partly answered**: the wiki can state the subject-level lever, the
payload problem that defeats it and the account limits that do work, but no public source gives a
clean way to forbid durables per user.

## Questions it answers

Q52 (partly, with the limitation stated).

## Pages touched

[[subject-permissions]] · [[account]] · [[js-api-subjects]] · [[consumer]] · [[direct-get]] ·
[[jetstream-slows-as-consumers-grow]]
