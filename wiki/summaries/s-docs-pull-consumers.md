---
title: "docs.nats.io — Pull consumers in depth"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/learn/jetstream/pull-consumers.md
source-path: raw/nats-docs/learn/jetstream/pull-consumers.md
author: NATS documentation (Synadia Communications, Inc.)
article: Pull consumers in depth
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [pull, fetch, consume, batch, max_ack_pending]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Pull consumers in depth

The two ways client code drives a pull consumer, and the two fields that bound a single pull.

## Key claims

- **Fetch** asks for a batch of up to *N* messages and returns when the batch is full or a timeout
  expires, whichever comes first. **Consume** sets up a continuous flow: the library keeps pull
  requests in flight in the background and calls a handler per message until you stop it. Every
  client library names them the same way. Most services use consume.
- Both patterns issue the **same underlying pull request**, and two fields bound it:
  - **`batch`** — the maximum number of messages this pull may return. Bigger means fewer round
    trips and higher throughput; smaller means lower per-message latency and less work lost if the
    worker dies mid-batch.
  - **`expires`** — how long the server holds the pull open waiting for messages before returning
    what it has. It bounds latency on a quiet stream.
- **An empty fetch is normal, not an error.** When nothing is queued and `expires` elapses the
  server replies with **`408 Request Timeout`**; a *no-wait* fetch with no messages gets
  **`404 No Messages`** instead. Every client reports that as an empty batch, and the CLI exits
  non-zero.
- **`expires` set to zero never times out** — the server holds the pull until the batch fills.
  Client libraries protect against this with a default of about 30 seconds. The CLI bounds each
  pull with `--timeout`.
- **MaxAckPending default is 1000.** Set well below the batch size (a limit of 10 against a batch
  of 100) it caps throughput: the server delivers 10 messages then stops until the worker acks, no
  matter how large a batch is asked for. Keep it at or above the batch size.
- A worker pool sharing one consumer **shares that single MaxAckPending limit** across every
  worker.
- **`batch` counts messages, not bytes.** A large batch against large messages pulls more into
  memory in one round than expected. Most clients also allow bounding a pull by total size with a
  `max_bytes` option; whichever limit is hit first ends the pull.
- `nats consumer next --count N` is **not** one batch request: it issues N single-message pulls in
  a row, each bounded by `--timeout`, so it approximates a fetch loop.

## Practical takeaways

- A worker that treats an empty fetch as a failure fails on a quiet stream. Treat `408` /
  empty as "nothing right now": wait and fetch again.
- Size `max_ack_pending` against the batch size, not against intuition — it is the field that
  silently caps a well-tuned batch.

## Commands the page uses

```
nats consumer next ORDERS shipping --count 10 --wait 2s
nats consumer next ORDERS shipping --count 5
nats consumer next ORDERS shipping --count 10 --timeout 2s
```

## Relevance to the wiki

The source for the pull half of [[consumer]] and for the `batch` / `expires` / MaxAckPending
interaction that shows up as "my throughput is lower than the docs say".

## Questions it answers

Q15 in part (what `max_ack_pending` does to throughput).

## Pages touched

[[consumer]] · [[ack-and-redelivery]]
