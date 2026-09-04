---
title: NATS Streaming (STAN) — deprecated
type: entity
kind: repo
area: [jetstream]
deprecated: true
verified-against: nats-streaming-server v0.25.6
verified-on: 2026-08-31
tags: [repo, deprecated, archived, stan, nats-streaming, jetstream-replacement]
aliases: [stan, nats-streaming, nats streaming, "nats-io/nats-streaming-server", nats-streaming-server]
sources: [s-github-repo-facts, s-gh-3507-no-external-store]
created: 2026-08-31
updated: 2026-09-04
---

# NATS Streaming (STAN) — deprecated

**Dead, archived, and replaced by JetStream.** NATS Streaming was a separate server process that
added persistence on top of core NATS. It is kept as a page here only so that a search for "STAN"
lands on the replacement instead of on a 2019 tutorial.

> **The replacement is [[stream]] — JetStream, built into [[nats-server]].**

## Facts

| | |
|---|---|
| repo | `nats-io/nats-streaming-server` — **archived** |
| last release | **v0.25.6**, **2023-11-17** |
| licence | Apache-2.0 |
| deprecation notice | "Critical bug fixes and security fixes will be applied **until June of 2023**" |
| replacement | JetStream, in the same binary as the server |
| docs | moved to a "legacy NATS docs" space; not part of docs.nats.io |

## What an operator needs to know

- **Support ended before the archive did.** The README's window — critical fixes until June 2023 —
  has passed, and the repository is archived, so nothing further will ship, including security fixes.
- **It was a separate process; JetStream is not.** Migrating is not a version upgrade: STAN channels
  become [[stream]]s, STAN durable subscriptions become [[consumer]]s, and the client API changes
  entirely. There is no in-place path.
- **The C client can still be built with Streaming support** ([[nats-c]]), which is compatibility,
  not endorsement.
- **"STAN" still appears in old blog posts and Stack Overflow answers.** Anything that mentions
  `stan.Connect`, channels, or a separate streaming binary is about this system and does not apply to
  JetStream.

## What the migration loses that is easy to miss: the pluggable store

NATS Streaming's store was pluggable — people ran it on SQL, and replicated the database themselves.
JetStream's is not. Asked directly whether Postgres would be supported, the chosen answer was "no, we
will support memory and file based for the store level. We can replicate in either store and each
store can also have digital twins or source mux/demux streams" (source:
[[s-gh-3507-no-external-store]], @derekcollison, 2022-09-28), and that is still the whole list at
2.14.6.

So a migration that was relying on the database for replication, backup or for letting the rest of the
estate query the messages has to replace all three with NATS mechanisms: [[replicas]] for the quorum,
[[mirrors-and-sources]] for a second copy, [[backup-and-restore-jetstream]] for an offline one, and a
republish or [[direct-get]] for the query path.


## Related

[[stream]] · [[consumer]] · [[nats-server]] · [[nats-c]] · [[retention-policies]]

## Sources

[[s-github-repo-facts]] · [[s-gh-3507-no-external-store]]
