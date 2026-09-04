---
title: "gh#3871 — Is Tiered Storage currently planned?"
type: summary
area: [jetstream, deploy, interop]
source-url: https://github.com/nats-io/nats-server/discussions/3871
source-path: raw/gh-discussions/gh-3871.md
author: "@shafqatevo (asker); @derekcollison (maintainer); @Material-Scientist, @hpvd, @christhegrand"
date: 2023-02-15
version: ""
article: "GitHub discussion 3871, General, no chosen answer, 1 comment and 10 replies, 7 upvotes, still open"
tags: [tiered-storage, cold-storage, s3, offload, roadmap, kafka, pulsar, seaweedfs, symlink, sidecar]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# gh#3871 — Is Tiered Storage currently planned?

The public form of question-bank **row 198**, and the dated half of row 144's dead end. Opened
2023-02-15 because tiered storage was not on the roadmap; **still open on 2026-09-04, with no chosen
answer**, which is itself the answer an architect needs.

## Key claims

- **The only maintainer statement in the thread, and it is one sentence**: "We have it planned but no
  schedule yet on when we will do this work as of yet." — @derekcollison, **2023-02-16**.
- **Asked again twice, and never answered again.** 2024-10-31: "is there an update on this? Kafka has
  recently added tired storage support… for me it's the only thing that keeps me from dropping Kafka in
  favor of NATS Jetstream." @derekcollison replies asking *what* the requester values in tiered
  storage — and there is no further maintainer comment in the thread after that question.
  2024-12-07 adds Pulsar's offload-to-S3 as a second comparison. **Three and a half years of "planned"
  with no schedule, no design and no version.**
- **What the requesters actually want, stated concretely** (2024-10-31): Kafka's experimental
  `LocalTieredStorage` "just uses a local directory to move segments once they are rolled", pointed at a
  mounted SeaweedFS drive that ages data SSD → HDD → S3; "Both Kafka & SeaweedFS **cache the data back
  to the local drive** as soon as a consumer requires old segments." The stated motive is cost:
  "storage is often the most expensive part about operating Kafka".
- **The community's own interim design, and it fits JetStream's layout exactly** (2024-12-07): "Since
  Jetstream stores streams as 8MB blocks, maybe a simple interim solution would just be to have a
  **sidecar that watches for completed blocks, copies them to a remote directory, and then replaces the
  blocks in the original directory with symlinks**". Posted with a diagram; **no maintainer responded to
  it**. It is a proposal, not a tested recipe — the tested version is in
  [[s-gh-6478-s3-offload-and-query]].
- **Somebody is already doing it outside the server** (2024-12-20, @christhegrand): "We wrote a custom
  solution to periodically offload data from Jetstream into Google Cloud Storage, but would love to see
  this functionality built into Jetstream itself." No code, no detail.
- Two adjacent server issues are named as related: TTL in the KV store
  ([#3251](https://github.com/nats-io/nats-server/issues/3251)) and S3 compatibility for the object
  store ([#4871](https://github.com/nats-io/nats-server/issues/4871)). Neither was read for this ingest.

## Practical takeaways

- **There is no tiered storage in `nats-server`, and this thread is the reason to stop looking.** The
  maintainer statement is three and a half years old, unscheduled, and the two follow-ups asking for an
  update produced a question rather than an answer.
- The design question it settles is a *shape* one: JetStream's store is a directory of ~8 MB blocks
  ([[filestore-layout]]), which is exactly what makes a block-level offload look easy from outside and
  is exactly why it is not part of the server — a sealed block is still addressed by the in-memory
  per-subject index, so moving it changes what a read costs, not what a read *is*.
- The answer a design has to use instead is the one gh#3772 gives: **an archiving consumer**, i.e. a
  client that reads the stream and writes somewhere else ([[s-gh-3772-jetstream-as-an-event-store]]).
- Cite this thread for "no tiered storage" **with its date**. "Not built in" is a claim about a roadmap,
  and a roadmap claim goes stale in a way a mechanism claim does not.

## Notable quotes

> "We have it planned but no schedule yet on when we will do this work as of yet." — @derekcollison,
> 2023-02-16

> "Since Jetstream stores streams as 8MB blocks, maybe a simple interim solution would just be to have a
> sidecar that watches for completed blocks, copies them to a remote directory, and then replaces the
> blocks in the original directory with symlinks" — @Material-Scientist, 2024-12-07

## Relevance to the wiki

Row 198's whole answer, and the dated evidence behind the one dead end on
[[event-sourcing-on-jetstream]]. Also the strongest public statement of *why* people ask: storage cost,
and a direct comparison with Kafka's and Pulsar's tiered storage that any migration conversation has to
be able to answer — see *What a stream is, if you are coming from Kafka* on [[stream]].

## Questions it answers

Row **198**; row 144 in part (the cold-storage third of the question).

## Pages touched

[[event-sourcing-on-jetstream]] · [[stream]] · [[filestore-layout]]
