---
title: "docs — JetStream: Shaping the stream"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/learn/jetstream/shaping-the-stream.md
source-path: raw/nats-docs/learn/jetstream/shaping-the-stream.md
author: nats-io docs
article: "learn/jetstream/shaping-the-stream.md"
date: 2026-08-31
version: ""
tags: [MaxAge, MaxBytes, MaxMsgs, MaxMsgsPerSubject, discard, discard_new_per_subject, limits]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — JetStream: Shaping the stream

The limits-and-discard page. Most of it confirms [[stream]]; three things are sharper here than
anywhere else the wiki has read.

## Key claims

**The three limits are independent and all active.** "Whichever one is reached first triggers a
discard… You don't have to set all three." `MaxAge` caps age, `MaxBytes` caps disk, `MaxMsgs` caps
count.

**`MaxAge` is not a discard-policy choice.** "It expires stored messages on its own timer under
either policy." Discard Old / Discard New decide only what happens when a **size or count** limit is
hit.

**The three rejection strings, named together** — this is the sharpest thing on the page:

| limit hit | error the publisher sees |
|---|---|
| whole-stream bytes | `maximum bytes exceeded` |
| whole-stream count | `maximum messages exceeded` |
| per-subject count | `maximum messages per subject exceeded` |

**A per-subject ceiling still rolls under Discard New.** "By default the per-subject limit still
rolls, discarding the subject's oldest message rather than rejecting the publish. Making a full
subject reject takes a second setting, `DiscardNewPerSubject` (the `discard_new_per_subject` config
field), **on top of** Discard New."

**Whole-stream limits do not balance across subjects.** "A high volume of `orders.created` counts
toward the same ceiling as `orders.shipped`, so Discard Old can discard a shipped order to make room
for a created one." And: "A seven-day MaxAge does not guarantee seven days of history. If traffic
spikes, MaxBytes can be reached first and discard messages that are only hours old."

**Limits are a stream property, not a consumer one.** "When MaxAge discards a message, it's gone from
the stream, and every consumer reading that stream loses access to it at once."

**Editing limits does not discard what already fits.** `nats stream edit ORDERS --max-age=7d
--max-bytes=1GiB` "changes an existing stream in place… only the configuration changes", and the
command "prints a diff of what will change and asks for confirmation before applying it".

The `nats stream info` block it prints (`Duplicate Window: 2m0s`, `Discard Policy: Old`,
`Maximum Messages: unlimited`) is quoted on [[stream]].

## Practical takeaways

- Set `MaxBytes` for peak traffic, not average, whenever the age window is the thing you actually
  promised.
- `discard_new_per_subject` is a **second** flag: Discard New alone does not make a full subject
  reject.
- The publisher-visible difference between the policies is whether a full stream is silent data loss
  or a failed publish.

## Relevance to the wiki

Enriches [[stream]] and [[maximum-messages-exceeded]], which had two of the three rejection strings
and not the per-subject one.

## Questions it answers

Contributes to **Q24** only indirectly (what "the stream" holds). No bank row is closed by this page
alone.

## Pages touched

[[stream]] · [[maximum-messages-exceeded]] · [[retention-policies]] · [[jetstream-sizing]]

## Sources

The doc page.
