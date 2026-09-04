---
title: "gh#3507 — will JetStream support an external database like Postgres?"
type: summary
area: [jetstream, interop]
source-url: https://github.com/nats-io/nats-server/discussions/3507
source-path: raw/gh-discussions/gh-3507.md
author: "@raricent (asker); @derekcollison (chosen answer)"
date: 2022-09-28
version: ""
article: "GitHub discussion 3507, Q&A, chosen answer, 2 upvotes"
tags: [storage, postgres, nats-streaming, memory, file, mirrors, sources]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# gh#3507 — Will JetStream support an external DB like Postgres for persistence?

One question, one chosen answer, and it closes a whole branch of the storage decision. The asker is
migrating from **NATS Streaming**, whose store was pluggable: "We used postgres with nats-streaming
for persistence. We replicated the DB ourselves. With Jetstream, I do not see an option for postgres.
Will it not be supported?"

## Key claims

- **@derekcollison, the chosen answer**: "**No, we will support memory and file based for the store
  level.** We can replicate in either store and each store can also have digital twins or source
  mux/demux streams."
- Two storage backends, and no third is planned. The replication answer is *inside* NATS — replicas,
  mirrors and sources — not an external database underneath it.

## Practical takeaways

- The storage decision for a stream is `memory` or `file`, full stop. There is no "put JetStream on
  our existing Postgres/S3/NFS" option to evaluate, and a design that assumed one is a design that
  needs redoing before it starts — [[stream]], [[jetstream-sizing]].
- The migration path from NATS Streaming loses the pluggable store along with everything else about
  it; durability is bought with replicas and mirrors instead — [[nats-streaming]],
  [[mirrors-and-sources]], [[replicas]].
- "Digital twins" is the maintainer's phrase for a mirror: a second stream kept in step with the
  first, in either store, which is the closest NATS gets to "the data is also somewhere else".

## Notable quotes

> "No, we will support memory and file based for the store level. We can replicate in either store and
> each store can also have digital twins or source mux/demux streams." — @derekcollison, 2022-09-28

## Relevance to the wiki

Bounds the storage half of [[core-or-jetstream]]'s decision and answers bank row 143 on the page that
owns storage, [[stream]].

## Questions it answers

Rows 143, 197 in part.

## Pages touched

[[stream]] · [[core-or-jetstream]] · [[nats-streaming]]
