---
title: "docs — JetStream: Reading back the stream"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/learn/jetstream/reading-back.md
source-path: raw/nats-docs/learn/jetstream/reading-back.md
author: nats-io docs
article: "learn/jetstream/reading-back.md"
date: 2026-08-31
version: ""
tags: [consumer, durable, ephemeral, stream-sequence, consumer-sequence, deliver-policy, replay-policy, metadata]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — JetStream: Reading back the stream

The chapter's first consumer page. Mostly confirms [[consumer]]; three things are stated more
precisely here than in anything the wiki had read.

## Key claims

**Stream sequence vs consumer sequence, defined against each other:**

- **stream sequence** — "the message's fixed position in the log. The server assigned it when the
  message was published, and it never changes."
- **consumer sequence** — "this consumer's own counter. The server adds one every time the consumer
  delivers a message, **redeliveries included**, so it tracks how many deliveries this consumer has
  made, not how many distinct messages it has seen."

They "drift apart whenever a consumer delivers a different set of messages than the stream stores in
order: one that starts partway through, one that filters to a subset of subjects, or one that has a
message redelivered." `nats consumer info` prints them side by side under `Last Delivered Message`.

**Read the state off the message, not with an API call.** "Every message a consumer delivers carries
the same state in its **metadata** — its stream and consumer sequence, how many messages are still
pending, how many times it's been delivered. That metadata rides along with the delivery for free,
while `nats consumer info` is a separate request to the server: fine for a one-off check, **too
costly to call for every message**."

**Pull is the default for new consumers.** "An older push model exists, but the consumers you create
in this chapter are pull."

**Delivery policy sets *where*; replay policy sets the *pace*.** Delivery: `--deliver all` (sequence
1), `--deliver last`, a window (`--deliver 1h`), or a known sequence (`--deliver 1000`). Replay:
`instant` (the default) "hands messages over as fast as the client reads them"; `original` "spaces
deliveries out to match the gaps between the messages' original timestamps, replaying recorded
traffic at something like its real speed."

**Reusing a durable name with a different config is refused.** "The server returns *consumer already
exists*; it won't silently reconfigure a consumer a reader is using. Edit the consumer
(`nats consumer edit`) instead, or pick a new name."

**An ephemeral consumer keeps no position.** "It's removed once it goes idle, and a reconnect then
starts over from the beginning." The CLI builds one when `nats sub` is given a JetStream flag such as
`--all`.

**A caught-up reader waits rather than exiting.** "`--terminate-at-end` stops once it has delivered
everything stored, but if there's nothing new, there's nothing to stop after, so it waits."

CLI shapes worth keeping:

```
nats consumer add ORDERS billing --deliver all --pull --ack explicit --defaults
nats sub --stream ORDERS --durable billing --terminate-at-end --ack
nats sub "orders.>" --all --terminate-at-end        # ephemeral, no ack
```

The `nats consumer info` state block it prints (`Outstanding Acks: 0 out of maximum 1,000`,
`Waiting Pulls: 0 of maximum 512`) matches the defaults on [[defaults-and-limits]].

## Practical takeaways

- A consumer sequence that runs ahead of the stream sequence is redelivery, not corruption.
- Never call `nats consumer info` (or its API equivalent) per message; the numbers are already on the
  message.
- `replay: original` exists and is rarely what production wants — it deliberately slows delivery to
  the original inter-message gaps.

## Relevance to the wiki

Enriches [[consumer]] with the two-sequence distinction and the metadata rule; confirms the pull
default and the ephemeral-consumer caveat [[ordered-consumer]] already leans on.

## Questions it answers

Contributes to **Q24** — the per-stream ordering a consumer reads in, and why its own counter is not
the stream's.

## Pages touched

[[consumer]] · [[stream]] · [[ordered-consumer]] · [[defaults-and-limits]]

## Sources

The doc page.
