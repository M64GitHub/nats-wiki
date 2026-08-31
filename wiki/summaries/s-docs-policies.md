---
title: "docs.nats.io — Stream and consumer policies"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/learn/jetstream/policies.md
source-path: raw/nats-docs/learn/jetstream/policies.md
author: NATS documentation (Synadia Communications, Inc.)
article: Stream and consumer policies
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [policies, immutable-config]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Stream and consumer policies

The nine stream and consumer policies in one place, and — the operationally important part —
which five of them are **fixed at creation**.

## Key claims

**Five stream policies**

- **Retention** — `limits` (default), `interest`, `workqueue`. Covered in
  [[s-docs-retention-policies]].
- **Discard** — `old` (default) deletes the oldest messages to make room; `new` refuses the
  publish.
- **Storage** — `file` (survives a restart) or `memory` (RAM only). Applies to the whole stream,
  replicas included.
- **Compression** — `none` (default) or `s2`. Makes a file-storage stream compress message blocks
  on disk, spending CPU to cut disk usage. Repetitive payloads such as JSON compress well;
  already-compressed payloads such as images do not. Set at creation with `--compression s2`.
- **Persist mode** — by default the message is flushed to storage first and the `PubAck` follows.
  On `async` the server acknowledges first and flushes in the background: a higher ingest rate in
  exchange for a window in which a crash loses messages the server already acked. `async` is
  **only accepted on a file-storage stream with a single replica**, and an `async` stream
  **refuses atomic batch publishing**.

**Four consumer policies**

- **Deliver policy** — `all` (default), `last`, `new`, `by_start_sequence`, `by_start_time`,
  `last_per_subject`. CLI: `--deliver 1000` for a sequence, `--deliver 1h` for an hour back.
  `last_per_subject` starts with the newest message for each subject the consumer matches and is
  what Key-Value watches are built on.
- **Ack policy** — `explicit`, `none`, `all`, `flow_control`. See [[s-docs-acknowledgment]].
- **Replay policy** — `instant` (default) delivers as fast as the reader takes them; `original`
  spaces deliveries to match the gaps between the original timestamps.
- **Priority policy** — `none` (default), `overflow`, `pinned_client`, `prioritized`.

**What can be changed on a live object**

| Stream policy | On a live stream |
|---|---|
| Retention | `limits` ↔ `interest` allowed, and the switch re-applies to messages already stored; to or from `workqueue` refused |
| Discard | Can change |
| Storage | **Fixed at creation** |
| Compression | Can change; takes effect only after a server or leader restart, and blocks already on disk stay as they are |
| Persist mode | **Fixed at creation** |

| Consumer policy | On a live consumer |
|---|---|
| Deliver policy | **Fixed at creation** |
| Ack policy | **Fixed at creation** |
| Replay policy | **Fixed at creation** |
| Priority policy | Can change; `nats consumer edit` has no flag for it, so pass a config file with `--config` |

- The server's refusals, verbatim: `stream configuration update can not change storage type`
  and `deliver policy can not be updated`.

## Practical takeaways

- Settle storage, persist mode and the three fixed consumer policies **before** creating anything
  durable. Recreating a stream means moving the data (a mirror can copy it across, but a mirror is
  read-only and turning it into a publishable replacement takes further steps); recreating a
  consumer **loses the saved position** — the new one starts wherever its deliver policy says.
- Deliver policy `new` applies **once, at creation**. A durable created with `new` keeps a saved
  position like any other durable; a client that restarts and re-attaches resumes from that
  position, backlog included. It is not a way to skip the backlog on every reconnect.
- Two different features answer to "last per subject": the consumer deliver policy
  `last_per_subject` (a standing latest-per-subject view) and the Direct Get `--last-per-subject`
  flag (a one-shot read with no consumer).

## Relevance to the wiki

The authority for the "what configures it" and "what you cannot change later" sections of
[[stream]] and [[consumer]], and for the immutability rule that turns a wrong policy choice into
a data migration.

## Questions it answers

Q55 in part (which changes take effect on a live object — for stream and consumer config, not for
server config reload).

## Pages touched

[[stream]] · [[consumer]] · [[retention-policies]]
