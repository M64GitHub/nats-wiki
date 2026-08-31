---
title: "gh#6836 — object-store list slow, sometimes timing out, while an upload runs"
type: summary
area: [objectstore, jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/6836
source-path: raw/gh-discussions/gh-6836.md
author: "@minons1"
article: "nats-io/nats-server discussion 6836"
date: 2025-04-25
version: ""
tags: [objectstore, list, timeout, unanswered]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#6836 — object-store list slow, sometimes timing out, while an upload runs

The source of question-bank row **Q75**, and — as of 2026-08-31, sixteen months after it was opened —
**still unanswered by anyone but the asker**. One comment on the thread, and that comment is the
author's own follow-up. Recorded here because an unanswered public question is evidence, and because
this wiki answered it by running it ([[s-nats-server-object-store-observed]]).

## Key claims

**The symptom, in the reporter's numbers.** "When there is an uploading file to a bucket,
`nats obj ls <bucket>` operation is so slow, on normal condition when I run the command it only took
**0.3-0.5s**, but when an upload is happening, the command could took **~2s**, sometimes I get
**timeout (>5s)**."

**It is not the client library.** "I also have the same problem with nats python sdk, at first I
suspect it because of the sdk, but I also have the same problem with nats-cli."

**A second, coupled symptom.** "Sometimes upload file speed is slow, but gradually increased after a
while, usually when this happens, list object command is also slow… on my regular network condition,
I could get up to **3MiB/s** speed, but when it is slow it could go down to **~200-500KiB**."

**What the report does not say**: server version, client versions, object count, object sizes,
deployment shape (single server or cluster), or storage backend. None are given.

## Practical takeaways

- The 3 MiB/s ceiling says the reporter's client was **remote and network-bound**, not colocated with
  the server — worth holding when reading the throughput half of the complaint.
- The `>5 s` threshold is exactly the `nats` CLI's `--timeout` default of `5s`, which makes the
  "timeout" a client-side deadline rather than a server error.

## Notable quotes

> "on normal condition when I run the command it only took 0.3-0.5s, but when an upload is happening,
> the command could took ~2s, sometimes I get timeout (>5s)"

## Relevance to the wiki

This is the whole public record on Q75. `learn/object-store/watching-and-listing.md` — the page the
plan expected to answer the row — says only that "a list is cheap: it reads metadata, never chunks"
and never mentions concurrency. So the row could be closed only by measurement, which is what
[[s-nats-server-object-store-observed]] is, and [[object-store-list-is-slow]] is where the answer
lives.

## Questions it answers

Q75 (it *asks* it; the answer is measured, not cited).

## Pages touched

[[object-store-list-is-slow]] · [[object-store]]

## Sources

`raw/gh-discussions/gh-6836.md`
