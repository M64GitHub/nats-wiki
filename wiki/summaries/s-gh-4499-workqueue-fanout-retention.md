---
title: "gh#4499 — WorkQueue, fan-out, and 10100"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/4499
source-path: raw/gh-discussions/gh-4499.md
author: "@riton (asker); @ripienaar (maintainer, chosen answer)"
date: 2023-09-07
version: ""
article: "GitHub discussion 4499, Q&A, chosen answer, 1 comment and 3 replies, 1 upvote"
tags: [retention, workqueue, interest, limits, fan-out, 10100, durable-consumer, max-deliver]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# gh#4499 — JetStream and Work retention policy Stream with Durable consumers and fan-out

The public form of question-bank **row 110**, and it is not a comparison — it is someone discovering
the answer by hitting an error. That is how the retention choice is actually met.

## The question

@riton, 2023-09-07, four requirements: do not lose an event; any app may go offline and must get what
it missed; the number of apps is not known in advance; and **multiple instances of one app must share
the work**. The initial design is a `--retention=work` stream on `EVENTS.*` with one durable consumer
per app, each filtering `EVENTS.*`.

The first consumer works. The second fails:

```
nats: error: Consumer creation failed: filtered consumer not unique on workqueue stream (10100)
```

## Key claims

- **@ripienaar's first answer misreads the requirement** — "Insted of ading more consumers, connect
  your apps to the same consumer" — and the asker disproves it with a five-message run pasted into the
  thread: app 1 gets messages 2, 4, 5 and app 2 gets 1, 3, because one consumer distributes rather
  than duplicates.
- **The corrected answer is the row's answer**: "OK, reading again you want more than 1 app to process
  the same message. **Then dont use WorkQueue. WorkQueue is designed for any message being processed
  succesfully once only. Use Interest or limits.** With those messages will distribute within multiple
  instances of teh same App (they would share a consumer) and multiple apps all get all the messages
  (each app is a consumer)."
- **The two axes are named in one sentence**: instances of one app share **a consumer**; different apps
  each get **their own consumer**. Retention decides only whether the second is allowed.
- **Confirmed by the asker two weeks later** (2023-09-21): "I'm now using `limits` policy and it work
  as expected."
- An incidental find in the asker's own command line: `--max-deliver=9999999999999`, with the note
  "`-1` … was set to this ridiculously high value. If `-1` of `indifinetly` was a valid value, I would
  have go for it." `-1` **is** valid — the CLI takes it in the equals form.

## Practical takeaways

- The retention question in practice is not "which of three" but "does more than one independent
  reader need this message". If yes, WorkQueue is excluded before any other consideration.
- `10100 filtered consumer not unique on workqueue stream` is a **design error surfacing as a create
  error**, and it surfaces on the *second* consumer — so it is found after the first app is already in
  production.
- The failure is not a redelivery bug or a filter bug; the asker's first instinct, that the filter
  string was the problem, is the wrong diagnosis and costs him two weeks.

## Notable quotes

> "Then dont use WorkQueue. WorkQueue is designed for any message being processed succesfully once
> only. Use Interest or limits." — @ripienaar, 2023-09-07

## Relevance to the wiki

Bank row 110's asked form, and the shape a *Choosing retention* section has to take: start from how
many independent readers the message has, not from the three policy names.

## Questions it answers

Row 110, in part — the WorkQueue exclusion rule, with the error it produces.

## Pages touched

[[retention-policies]] · [[worker-pool]] · [[error-codes]]
