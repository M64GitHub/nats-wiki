---
title: "gh#5172 — Docu about programatic configuration of subject mapping"
type: summary
area: [core, jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/5172
source-path: raw/gh-discussions/gh-5172.md
author: "@suikast42 (asker), @jnmoyne (Synadia)"
article: "GitHub discussion #5172, General, opened 2024-03-04, one comment and seven replies to 2024-03-08, no chosen answer"
date: 2024-03-08
version: ""
tags: [mappings, subject_transform, partition, account, stream, chaos-testing, weight]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# gh#5172 — subject mapping in the server config or in the stream?

A user partitioning `ingress.devicetracking.*` with a `mappings` block in the server config asked why
the same partitioning "does not work" when configured on a stream. The thread ends with the mapping in
the right place; on the way a maintainer states where each kind of mapping belongs.

## Key claims

- **Two mechanisms, two purposes**: "You can do either 'Core NATS subject mapping' in which case it's
  part of the account data (i.e. in the server's config, or in the account's JWT), and/or inside a
  stream's definition. They are different mappings for different purposes (in one case the subject
  transformation is applied as the Core NATS message is being published, while in the other case the
  subject transformation is applied as messages are ingested into the stream)" — @jnmoyne.
- **Where a stream's partitioning belongs**: "You do not want to put the mappings you want to do inside
  streams (e.g. inserting a partition number) in the server config, only in the stream config" — let the
  stream listen on `ingress.devicetracking.*` and transform there. "you need nats-server v2.10 for stream
  subject transforms to work."
- **The argument order of `partition`**: the asker had written `{{partition(1,10)}}`; it is "first the
  number of partitions, followed by one (or more) wildcard index numbers", and `{{partition(10,1,2)}}`
  hashes two wildcard tokens together. Put `{{partition()}}` **before** the `{{wildcard()}}` tokens in
  the destination, so consumers filter on `ingress.iosensor.0.>`.
- **The asker's config quotes the server's example file**, including a weighted mapping "Change
  dynamically at any time with a server reload", `$1`-style token references, a cluster-scoped
  destination, and "A chaos testing trick that introduces 50% artificial message loss":
  `foo.loss.>: [ { destination: foo.loss.>, weight: 50% } ]` — a **wildcard** source listed as its own
  destination, which the docs say works only for a literal source. Run on 2.14.6: it works for the
  wildcard too ([[s-nats-server-core-delivery-observed]] run F8).
- Consumer-group elasticity is deferred to a client-side library ("something we are currently working
  on", ADR PR #263) — the [[orbit]] partitioned consumer groups.

## Practical takeaways

- Account-level `mappings` rename, split or shard **core** subjects before routing; a stream's
  `subject_transform` shards what the stream stores. Shard in the stream unless core subscribers need
  the sharded subject too.

## Relevance to the wiki

The public form of question-bank row 170, and the maintainers' placement rule for the *Account-level
mappings* section of [[subject-transforms]].

## Questions it answers

170.

## Pages touched

[[subject-transforms]] · [[subjects-and-wildcards]]
