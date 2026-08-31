---
title: "gh#7982 — Unable to increase stream replicas from 1 to 3 (no suitable peers, 10005)"
type: summary
area: [topology, jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/7982
source-path: raw/gh-discussions/gh-7982.md
author: "@ramasauskas (asked and self-answered)"
article: "GitHub Discussion 7982 (Q&A)"
date: 2026-03-24          # opened; answer chosen 2026-04-08
version: "2.12.5"         # the version the reporter was running
tags: [placement, 10005, debug-logs, peer-selection]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#7982 — `no suitable peers for placement (10005)` on a replica increase

A Q&A thread, opened 2026-03-24, **answer chosen 2026-04-08 by the person who asked**. Short, and
worth its length entirely for the diagnostic technique.

## The report

Running **nats-server 2.12.5**. A healthy HA cluster that creates new streams fine, but editing an
existing stream from R1 to R3 fails:

```
could not edit Stream <xxx>: no suitable peers for placement (10005)
```

The reporter had already **verified storage requirements were met on all nodes**, and asked the
question that makes this thread useful:

> "Is there a way to diagnose what exactly imposes the `no suitable peers for placement` error? It
> is now very difficult to pinpoint what is exactly wrong."

## The answer

**Enable debug logging.** The peer-selection decision is logged per candidate peer, with the reason
it was discarded:

```
[2590221] 2026/04/08 10:06:24.179347 [DBG] Peer selection: discard ** reason: not target cluster **
```

In this case a **configuration mismatch pointed the stream at the wrong cluster** — the servers
were healthy and had capacity, but none of them were in the cluster the stream's placement named.

The reporter's closing remark stands as the open problem:

> "However, it would be nice to somehow receive this error when trying to mutate"

The `10005` response names, at most, an unmatched tag. It does **not** say which peers were
considered and why each was rejected — that is only in the debug log.

## Practical takeaways

- **`no suitable peers for placement` is a class of error, not one cause.** Storage capacity is one
  candidate; the wrong `cluster` in the placement is another, and it looks identical from the
  client.
- **The `Peer selection: discard … reason:` debug lines are the diagnostic.** They exist per
  rejected peer and give the actual reason. Nothing else does.
- It reproduces on a **live edit**, on a cluster that creates new streams without complaint — so
  "new streams work" is not evidence that placement is configured correctly.

## Relevance to the wiki

Turns [[stream-placement]] from a description of the rule into something diagnosable, and is the
source for the gotcha page [[no-suitable-peers-for-placement]]. The debug-log technique is the only
published way found so far to see the server's reasoning.

## Questions it answers

Q33 (can I change the replica count of a live stream, and why does it fail with "no suitable peers
for placement") — this is the thread the bank's row links to.

## Pages touched

[[no-suitable-peers-for-placement]] · [[stream-placement]] · [[replicas]] · [[error-codes]]
