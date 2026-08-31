---
title: "gh#6605 — How to find which consumer has been detected as slow?"
type: summary
area: [monitoring, core]
source-url: https://github.com/nats-io/nats-server/discussions/6605
source-path: raw/gh-discussions/gh-6605.md
author: "@superlevure (asked); @terradek and @tehsphinx (community)"
article: "GitHub Discussion 6605 (Q&A)"
date: 2025-03-05          # opened; last reply 2026-02-12
version: ""              # no server version stated
tags: [slow-consumer, write_deadline, nats-top, unanswered]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#6605 — which consumer is the slow one?

Opened 2025-03-05, **no answer chosen, and still effectively open as of the last reply on
2026-02-12**. It is included here because an unanswered question with a real log line is worth more
to this wiki than a confident guess.

## The report

```
Slow Consumer Detected: WriteDeadline of 10s exceeded with 2 chunks of 645 total bytes.
```

> "How can we find which consumer is at fault here? Looking at the metrics, it is not obvious which
> one the server considers slow."

Note the numbers: **2 chunks, 645 total bytes**. The connection was not moving a large backlog — it
failed to accept a very small amount of data within the `write_deadline`.

## The responses

**@terradek (2025-04-07)** — the only suggestion offered:

> "Use `nats-top -sort pending` to view the queues of the customers on the Nats server. Then, you
> can check the port used by the customer to locate it."

**@tehsphinx (2026-02-12)** — reports the suggestion not working:

> "I have the same question. `nats top` reports 2 slow consumers but all the connections show
> 'Pending: 0'."

## What this establishes, and what it does not

**Established:**

- The log line's shape, verbatim, including that it reports the exceeded **`write_deadline`** and
  the chunk count and byte total that were outstanding — not a consumer or stream name.
- **The log line does not name the connection.** That is the whole question.
- `nats-top -sort pending` is the community's suggested approach, and the connection's **port** is
  the identifier you would then correlate on.
- **`Pending: 0` on every connection while `nats-top` still reports slow consumers is a reported
  observation**, from a second person, eleven months after the question. So sorting by pending can
  show nothing even when the counter says slow consumers exist.

**Not established, by anything in this thread:**

- Whether a slow *client connection* and a slow *JetStream consumer* are being conflated — the log
  line is about a connection missing its `write_deadline`, which is a core NATS concept, while
  "consumer" in JetStream means something else entirely. Neither responder addresses the ambiguity.
- Any endpoint, metric or field that names the offending connection.
- Whether the `Pending: 0` observation is a `nats-top` sampling artefact, a different slow-consumer
  class, or a bug.

## Relevance to the wiki

The source for [[slow-consumer-detected]], written honestly as a gotcha whose **fix is not known**.
The rulebook is explicit that "a gotcha page with no confirmed fix is still worth writing — say what
is unknown", and this is that page. It also flags a terminology collision worth naming in the wiki:
*slow consumer* in a NATS log line is not a JetStream [[consumer]].

## Questions it answers

**None fully.** Q58 ("How do I find which consumer the server has flagged as slow?") is the bank row
this thread backs, and the honest state of it is: the wiki can describe the symptom, name
`write_deadline`, and record that the documented approach was reported not to work. It cannot yet
state a reliable answer.

## Pages touched

[[slow-consumer-detected]] · [[consumer]] · [[monitoring-endpoints]] · [[nats-cli]]
