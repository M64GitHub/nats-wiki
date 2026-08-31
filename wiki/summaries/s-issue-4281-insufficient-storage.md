---
title: "nats-server issue #4281 — insufficient storage resources available (10047)"
type: summary
area: [jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/issues/4281
source-path: raw/gh-issues/issue-4281.md
author: "@jeffmccune (reporting), @derekcollison and @wallyqs (maintainers), plus five more reporters"
article: "nats: error: could not create Stream: insufficient storage resources available (10047)"
date: 2023-06-29
version: "2.9.16 through 2.10.24; still open at 2026-08-31"
tags: [10047, max_bytes, reservation, overcommit, varz, docker, account-limits]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# issue #4281 — `10047` with an almost empty disk

**Open since 2023-06-29** with six independent reporters across `2.9.16`, `2.10.17`, `2.10.22` and
`2.10.24`. The maintainer explanation is clear and is the single most useful fact about error
**10047**; the last reporter's counter-example to it has never been answered.

## Key claims

**`max_bytes` is a reservation, not a ceiling** (@derekcollison, 2024-12-04):

> "`max_bytes` will reserve that for you against the jetstream limits for the servers and the account.
>
> We currently do not do overcommit in the face of max_bytes."

and again, more precisely (2024-12-05):

> "When you specify max_bytes that is now considered 'used' for all intent and purposes such that you
> should never fail to add a message to that stream since we pre-check for the reservation against all
> server and account limits.
>
> So even though they might be empty the system will see those as reserved and deny new streams if the
> capacity limit has been reached."

That is the whole mechanism: `10047` compares **reserved** bytes to the limit, and reserved bytes come
from every stream's `max_bytes` whether or not a single message has been published. Verified in the
source at v2.14.6 — `reserveStreamResources` adds `cfg.MaxBytes` and returns early when it is `<= 0`,
`checkBytesLimits` compares against `js.storeReserved` — in
[[s-nats-server-jetstream-resources]].

**The field that shows it.** A `/varz` dump posted by @dee-ynput (2024-07-27) has the reservation and
the reality side by side:

```
      "storage": 4022205,
      "reserved_storage": 37580963840,
```

4 MB stored, **35 GiB reserved**.

**The workaround people find** (@dee-ynput, 2024-07-27):

> "I could not create more than a few (almost empty) streams before receiving err_code 10047 (or 10028
> for memory streams).
>
> I had to set jetstream max file to 100G instead of 10G in order to create my streams, even though my
> steams were less than 5Mo."

**The unanswered counter-example** (@derhuerst, 2025-01-13, `2.10.22`): `max_file: 16G` on the server,
two streams at `--max-bytes=10G` and `--max-bytes=5G` — 15 G of reservation under a 16 G limit — and
still `insufficient storage resources available (10047)`. He restated it on 2025-04-11:

> "But in my case, the sum of the two streams' `max_bytes` was *less* than NATS' `max_file`."

The maintainer's reply was "Can you upgrade to 2.10.27 and see if the issue persists?". Nothing
further was posted. **The issue is still open.**

**A cause that is not NATS at all** (@heimalne, 2025-01-06): on an Arm Mac, Docker Desktop's VM has a
virtual disk size limit; reaching it produces the same error inside the container.

**A distinct earlier report in the same thread** (@jeffmccune, 2023): an operator-mode account whose
**account** tier limits were `122 MiB` of memory and storage, with the server's own limits far higher —
`10047` came from the *account* half of the same check, not the server half. His `nats account info`
output makes that readable at a glance.

## Practical takeaways

- `10047` (and `10028` for memory) does **not** mean the disk is full. It means
  *reserved + requested > limit*, on either the **server** (`max_file_store`) or the **account**
  (`MaxStore` tier).
- Read `jetstream.stats.reserved_storage` and `jetstream.stats.storage` from `/varz` together. If
  reserved is far above stored, the answer is `max_bytes` arithmetic, not capacity.
- Setting `max_bytes` on **every** stream is what makes the guarantee work ("you should never fail to
  add a message to that stream"). Setting it on *some* streams is what makes the numbers surprising:
  streams without it reserve nothing and still consume real disk.
- On an untiered account, R3 counts **three times** against the account limit; the server limit counts
  a single replica's worth. That asymmetry is in [[jetstream-sizing]] and is verified in
  [[s-nats-server-jetstream-resources]].

## Relevance to the wiki

The page is [[jetstream-out-of-disk]], which separates the three distinct things that all read as
"out of storage": a reservation failure (this issue), a shrinking dynamic limit
([[s-issue-8322-dynamic-maxstore-shrinks]]), and a genuine write failure on a full filesystem.

## Questions it answers

- The new **Q26** — what happens when JetStream runs out of disk (the reservation half).

## Pages touched

[[jetstream-out-of-disk]] · [[jetstream-sizing]] · [[error-codes]] · [[monitoring-endpoints]] ·
[[stream]] · [[account]]
