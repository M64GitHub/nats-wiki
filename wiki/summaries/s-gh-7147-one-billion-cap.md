---
title: "gh#7147 — Is jetstream message count capped at 1 billion for a single stream?"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/7147
source-path: raw/gh-discussions/gh-7147.md
author: "@ftong2020 (asked); @wallyqs (maintainer reply, no answer chosen)"
article: "GitHub Discussion 7147 (Q&A, opened 2025-08-04, unanswered)"
date: 2025-08-04
version: "2.11.7"
tags: [max_msgs, limits, discard, stream-size, billion, unanswered]
aliases: []
sources: []
created: 2026-09-02
updated: 2026-09-02
---

# gh#7147 — "messages are discarded at one billion": there is no such cap

Question-bank row 4. A reporter whose runaway producer filled a stream saw messages discarded and
concluded there is a one-billion-message cap. A maintainer showed a stream past that number the next
day; the reporter said *"Let me try to reproduce"* and never returned.

## The report

A service "went wild" and produced into one stream; *"some messages are discarded (can not figure
out if it is latest message/oldest message)"*; *"For the tenant and the stream, maxMessageSize and
MaxMessages are all set to 0"*; *"it turned out that message number is capped at 1 billion. I can't
find any documentation about the '1 billion cap' behavior."*

The thread never shows the stream's `max_bytes`, `max_age`, `discard` policy, the account's
`max_store`, or the server's `max_file_store` — any of which discards at a size, none at a count.

## The reply (@wallyqs, 2025-08-05)

> we would need more info about your setup or the type of stream that you are using as currently
> cannot think of an obvious limit, a limits based stream should be possible to have +1B msgs:

```
            Host Version: 2.11.7
                Messages: 1,174,510,552
                   Bytes: 36 GiB
          First Sequence: 1 @ 2025-08-04 16:32:49
           Last Sequence: 1,174,510,552 @ 2025-08-04 19:54:14
        Active Consumers: 0
      Number of Subjects: 1
```

That is 1.17 billion messages of ~33 bytes, filled in about three and a half hours, on one subject.

## What the server says

At v2.14.6 no constant of a billion exists in the filestore, stream, consumer, memstore, server,
options or JetStream API sources; sequences are `uint64`; `max_msgs` is an `int64` whose only
validation turns 0 or anything below −1 into −1, unlimited ([[s-nats-server-filestore-recovery]]).
The `nats stream edit --max-msgs 10000000000` run in [[s-nats-server-stream-scale-observed]] is
accepted.

## Practical takeaways

- **No count cap.** What discards at scale is a *size*: `max_bytes` on the stream, `max_file_store`
  on the server (auto-sized from free disk, and re-sized at every restart — [[jetstream-out-of-disk]]),
  or the account's storage limit; or `max_age`. Under `discard: old` (the default) all of them drop
  the oldest silently, which is the "cannot figure out which" the reporter saw.
- When a stream loses messages you did not delete, read `nats stream info` — *Limits* and *State* —
  and `nats account info`, not the message count.
- The reporter's loss is **unexplained** in the thread. This wiki does not name a cause for it.

## Relevance to the wiki

The public form of row 4; the maintainer's stream is the largest message count quoted in any source
read here.

## Questions it answers

Row **4**.

## Pages touched

[[stream]] · [[jetstream-sizing]] · [[defaults-and-limits]]
