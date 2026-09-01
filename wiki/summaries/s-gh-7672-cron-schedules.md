---
title: "gh#7672 — Cron schedule supports ?"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/7672
source-path: raw/gh-discussions/gh-7672.md
author: "@evmd (asked); @MauriceVanVeen (answer, marked)"
article: "GitHub Discussion 7672 (Q&A)"
date: 2025-12-21
version: "2.12, 2.14"
tags: [message-scheduling, cron, 10189, release-timing]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# gh#7672 — cron schedules are 2.14, and on 2.12 they look like a syntax error

Four lines, a **marked** maintainer answer, and the whole value is that it names the version boundary
inside ADR-51 — and shows what crossing it looks like from the outside.

## Key claims

- The asker reads ADR-51, sends a cron schedule, and gets **`message schedules pattern is invalid`**
  (error **10189**): *"Cron-like schedules should work, but seems the server returns `message
  schedules pattern is invalid` when sending any cron formatted schedule specification. Is it
  supported ? **Can't find much more info in the docs or code.**"*
- @MauriceVanVeen, marked as the answer: *"Only single scheduled messages from that ADR were released
  as part of **2.12**… The remaining items, like cron-like schedules, will be part of version **2.14**
  to be released March of next year."* — with a link to the 2.12 release blog's
  *#delayed-message-scheduling* section.

## Practical takeaways

- **ADR-51 describes more than any one release implements.** Its `Tags` row reads `jetstream, 2.12,
  2.14` and its revision table maps each addition to a server version; a reader who takes the document
  as one feature will write a config the server rejects.
- **`10189` is one error code with at least two unrelated causes**, and it names neither: a 2.14
  expression on a 2.12 server, and a **5-field cron on any version** — the server wants six fields,
  seconds first ([[s-nats-server-message-schedules-observed]]). "Pattern is invalid" is the same
  message either way.
- **The asker looked in the docs first and found nothing.** That is the documentation gap this wiki
  recorded as `inbox/docs-issues.md` #42: a shipped feature with ten error codes, a header family and
  no prose page anywhere in the tree.

## Relevance to the wiki

Question-bank row 29, and the operator-visible half of the 2.12/2.14 boundary that
[[message-scheduling]] has to state on every field.

## Questions it answers

Row 29.

## Pages touched

[[message-scheduling]] · [[error-codes]] · [[nats-server-2.12]] · [[nats-server-2.14]]
