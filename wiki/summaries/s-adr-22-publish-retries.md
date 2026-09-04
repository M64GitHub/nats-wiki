---
title: "ADR-22 — JetStream publish retries on no responders"
type: summary
area: [jetstream, clients]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-22.md
source-path: raw/adr/ADR-22.md
author: "@wallyqs"
date: 2022-03-18
version: ""
article: "ADR-22; status Partially Implemented; tags jetstream, client"
tags: [publish, no-responders, "503", retry, retrywait, retryattempts, puback, adr]
aliases: [ADR-22, "JetStream Publish Retries on No Responders"]
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# ADR-22 — JetStream Publish Retries on No Responders

Short, and the only ADR that sits exactly on the boundary between core NATS and JetStream: it is the
document that says out loud that **a JetStream publish is a core request/reply**, and specifies what a
client should do when nobody answers it. Status **Partially Implemented** (the repo's own label);
`inbox/adr-toc.md` row 22.

## Key claims

- **The problem**: "When the NATS Server is running with JetStream on cluster mode, there can be
  occasional blips in leadership which can result in a number of `no responders available` errors
  during the election."
- **The mechanism, stated plainly**: "A `no responders available` error uses the **503 status header**
  to signal a client that there was no one available to serve the published request. **A synchronous
  `Publish` request when using the JetStream context internally uses a `Request` to produce a
  message**, and if the JetStream service was not ready at the moment of publishing, the server will
  send to the requestor a 503 status message right away."
- **The remedy**: "a client can back off for a bit and then try to send the message again later. **By
  default the Go client waits for `250ms` and will retry 2 times** sending the message (so that in
  total it would have attempted to send the message 3 times)."
- **The terminal errors**: "After exhausting the number of attempts, the result should either be a
  **timeout error** in case the deadline expired or a **`nats: no response from stream`** error if the
  error from the last attempt was still a `no responders error`."
- **The two options** it asks clients for: `nats.RetryWait(250*time.Millisecond)` and
  `nats.RetryAttempts(10)`, with **`RetryAttempts(-1)`** meaning retry until the context deadline —
  the ADR's own example pairs it with `nats.Context(ctx)` on a 10-second timeout, and with
  `nats.AckWait(10*time.Second)`.
- The example code is Go and uses `nc.Request(subject, …)` directly, catching `nats.ErrNoResponders` —
  making the equivalence with a core request explicit rather than implied.

## Checked against the implementation and the server

Read at **nats.go v1.53.1** (`raw/nats-go-src/jetstream-publish-v1.53.1.md`): the ADR's defaults hold
in **both** client APIs — `DefaultPubRetryWait = 250 * time.Millisecond` and
`DefaultPubRetryAttempts = 2` at `js.go:233,236` and `jetstream/publish.go:157,160` — the loop fires
only on `ErrNoResponders`, `RetryAttempts(-1)` is the `o.retryAttempts < 0` branch, and the exhausted
error becomes `ErrNoStreamResponse` (`nats: no response from stream`) exactly as specified.

Observed on the binary (`raw/nats-server-src/core-or-jetstream-observed-v2.14.6.md`, run G): on an R3
stream, a stream-leader step-down cost a publisher **exactly one** publish, as
`nats: no responders available for request`, 32 ms after the step-down was issued — the blip the ADR
was written for, measured. The **meta**-leader step-down in the same run cost nothing.

**`nats` CLI 0.4.0 does not implement any of this.** `cli/pub_command.go:279` is a plain
`nc.RequestMsg(msg, opts().Timeout)`, so `nats pub -J` never retries; its failure surfaces as
`nats: no responders available for request` rather than the ADR's `nats: no response from stream`,
and the difference between those two strings is how you tell a retrying client from one that is not.

## Practical takeaways

- Budget for it: on a cluster, a leader election is a **transient 503 on publish**, not an outage. A
  publisher that treats `no responders` as fatal will raise alerts on every rolling restart.
- The retry is client-side and per-client. A polyglot estate has as many retry policies as it has
  clients; check each one rather than assuming ADR-22's numbers.
- `no responders` at publish time has two very different causes that look identical: a leadership blip
  (retry) and **no stream captures this subject** (a design error — retrying forever will not help).
  Both were observed in `core-or-jetstream-observed-v2.14.6.md`, runs G and B2.

## Relevance to the wiki

The cost line of [[core-or-jetstream]]'s decision, the version and spec layer for [[publishing]]'s
`PubAck`, and the reason [[nats-timeout]] separates a 503 from a timeout.

## Questions it answers

Row 133 in part; row 195 (added with this ingest).

## Pages touched

[[core-or-jetstream]] · [[publishing]] · [[nats-timeout]] · [[nats-go]] · [[nats-cli]] · [[core-nats-delivery]]
