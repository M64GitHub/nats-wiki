---
title: "docs — Key/Value: TTL and limits"
type: summary
area: [kv, jetstream]
source-url: https://docs.nats.io/learn/key-value/ttl-and-limits.md
source-path: raw/nats-docs/learn/key-value/ttl-and-limits.md
author: nats-io docs
article: "learn/key-value/ttl-and-limits.md"
date: 2026-08-31
version: "2.11"          # names 2.11 as the floor for per-key TTL
tags: [per-key-ttl, marker-ttl, limit-markers, MaxAge, max-bucket-size, max-value-size, history, discard-new]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — Key/Value: TTL and limits

Per-key TTL, the three bucket limits, and the marker a watcher sees when a value expires on its own.

## Key claims

**Per-key TTL rides on limit markers, and the bucket must opt in first.**

```
nats kv edit INVENTORY --marker-ttl 1h
nats kv create INVENTORY flash-sale 99 --ttl 30m
```

"Per-key TTLs ride on a bucket feature called **limit markers**… A bucket needs limit markers enabled
before any key in it can carry a TTL." `--marker-ttl` is the CLI spelling of the stream's
`subject_delete_marker_ttl` ([[message-ttl]]), and the doc describes the duration as "how long the
bucket keeps the expiry marker". **It never states a server-side default for it** — the value is
always passed explicitly here.

**Per-key TTL requires nats-server 2.11 or newer**, "that's the release that added limit markers. On
an older server, enabling markers on the bucket is rejected, and the timed create fails with it."

**TTL is a create-only argument, and this is the trap:**

> "Neither put nor update takes a `--ttl`; the CLI rejects the flag outright. And writing the key
> again doesn't extend its TTL: a put or an update appends a new latest value **with no TTL of its
> own, so the key simply stops expiring**."

To change a TTL you delete and create again. A key you thought was ephemeral becomes permanent the
first time anything writes it with `put`.

**Two different clocks.** The bucket's `--ttl` is the stream's `MaxAge` — "one deadline applied to
every value in the bucket". The per-key TTL is JetStream's per-message TTL. Same word, different
scope.

**The three bucket limits:**

| limit | what it bounds |
|---|---|
| max bucket size (`--max-bucket-size`) | total bytes across every key and every kept revision |
| max value size (`--max-value-size`) | the largest single value; "key-value values are meant to be small; large values belong in the Object Store" |
| history depth (`--history`) | prior revisions per key — **caps at 64**, and doubles as "the most messages any single key may hold" |

**The CLI parses `MB`/`KB` as binary units**: "1 MB = 1 MiB, 1 KB = 1 KiB", so `--max-bucket-size
16MB` prints back as `16 MiB` and `--max-value-size 64KB` as `64 KiB`.

**Limits reject; they never make room.** "A put of a value larger than the bucket's max value size is
rejected outright, and so is a put that would push the bucket past its max size; the server returns an
error and leaves every existing value in place… **Size the bucket for the working set you actually
need to hold, not the average**, so a busy minute doesn't bounce writes you needed to land."

**An expiry leaves a marker, and a watcher sees it as a purge.** "When a per-key TTL fires, the server
leaves a marker instead of silently dropping the value… a TTL expiry leaves one with the reason
`MaxAge`… A watcher receives the marker as a purge on the key — the CLI prints `PURGE`." Without it
"a watcher that saw `flash-sale` appear would never learn it had vanished."

## Practical takeaways

- **A `put` over a TTL'd key silently makes it permanent.** There is no error and no warning; the new
  revision simply carries no TTL.
- Bucket limits behave like a `discard: new` stream because that is what they are — a full bucket
  fails the writer rather than dropping history.
- A watcher cannot distinguish a TTL expiry from a manual purge; both arrive as `PURGE`. If that
  distinction matters, it has to come from the marker's reason, not from the operation.

## Relevance to the wiki

Gives [[key-value]] the per-key-TTL mechanics and the `--marker-ttl` CLI spelling, and gives
[[message-ttl]] a second source that **still does not state the `subject_delete_marker_ttl` default** —
so that open item survives this read.

## Questions it answers

Contributes to **Q73** (what a bucket is not for: large values, and anything that must not be
rejected under load) and to the lease half of **Q74**.

## Pages touched

[[key-value]] · [[message-ttl]] · [[object-store]]

## Sources

The doc page.
