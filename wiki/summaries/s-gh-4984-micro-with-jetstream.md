---
title: "gh#4984 — Nats micro with JetStream"
type: summary
area: [core, jetstream, clients]
source-url: https://github.com/nats-io/nats-server/discussions/4984
source-path: raw/gh-discussions/gh-4984.md
author: "@suikast42, @ripienaar, @nickchomey, @dnbsd"
date: 2024-01-23
version: ""
article: "nats-server discussion 4984, General, 8 upvotes, no chosen answer; last reply 2025-04-22"
tags: [services, micro, jetstream, persistence, ack, redelivery, roadmap]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# gh#4984 — Nats micro with JetStream

The public form of the services framework's hardest boundary: it has no persistence, and there is no
supported way to give it one. Opened 2024-01-23, eight upvotes, still without a chosen answer after
fifteen months of replies.

## Key claims

- **The question.** "Nats micro looks very well for managing and deploying services over nats. But as
  I understand the hanlders are registrered as a 'persistence less' listener to a subject. It could be
  very handy to combine nats micro with jetstream. The handler should be able to ack and nack messages
  for handling redelivery." (@suikast42, 2024-01-23)
- **The answer in 2024**: "Something like this is roughly planned for a future itteration, agree it
  would be useful. No immediate plans though" (@ripienaar, 2024-01-23).
- **The answer fifteen months later, to a direct "any update?"**: "Not yet no. It's fairly easy to do
  for a particular case but solving it generically for everyone is quite hard. Though the missing
  piece was per message TTLs which we do now have so it's more likely we will be able to do something
  good here. Still not on the immediate roadmap" (@ripienaar, 2025-04-22).
- **What people build instead**: "I just built a mechanism on micro only to realize it didn't have
  persistence. So had to build a separate one that used jetstream and a replyto subject header, with
  a separate subscriber for the response on that subject" (@nickchomey, 2025-04-21).

## Practical takeaways

- The framework is core NATS all the way down and will stay so for the foreseeable future: there is no
  acking handler, no redelivery, no dead-letter path. A design that needs any of those needs a stream
  and a consumer beside the service, not inside it.
- The pattern the third commenter describes — publish into a stream, carry the caller's reply subject
  in a header, answer from a separate subscriber — is the standard way to bridge the two, and it is a
  different failure model from request/reply, not a drop-in upgrade.
- Per-message TTLs (2.12 and later) are named as what was previously missing, so this may change; as of
  2.14.6 nothing has shipped.

## Notable quotes

- "the hanlders are registrered as a 'persistence less' listener to a subject" (the original post)
- "solving it generically for everyone is quite hard" (@ripienaar, 2025-04-22)

## Relevance to the wiki

The public evidence for *when not to use it* on [[services-on-core-nats]] and for the durability limit
on [[services-framework]]: the boundary between a service layer and [[worker-pool]] is not a matter of
taste, it is that one side has no acknowledgement at all.

## Questions it answers

193, and half of 134 (the boundary the pattern page has to name).

## Pages touched

[[services-on-core-nats]], [[services-framework]], [[worker-pool]], [[core-nats-delivery]]
