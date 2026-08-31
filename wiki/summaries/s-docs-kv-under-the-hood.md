---
title: "docs — Key/Value: Under the hood"
type: summary
area: [kv, jetstream]
source-url: https://docs.nats.io/learn/key-value/under-the-hood.md
source-path: raw/nats-docs/learn/key-value/under-the-hood.md
author: nats-io docs
article: "learn/key-value/under-the-hood.md"
date: 2026-08-31
version: ""
tags: [KV_bucket, "$KV", direct-get, KV-Operation, Nats-Rollup, deny_delete, rollup_hdrs, discard-new, key-charset]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — Key/Value: Under the hood

The chapter page that opens *"a bucket is a stream"* and walks the real `KV_<bucket>` config. Most of
it confirms what [[key-value]] already carried from ADR-8; three things are sharper, and one is a
trap the wiki did not state.

## Key claims

**The mapping, in the server's own `nats stream info` output.** A bucket is the stream
`KV_<bucket>` on subjects `$KV.<bucket>.>`; a key is the **last token** of that subject; a value is a
message on it. For `INVENTORY`: stream `KV_INVENTORY`, subjects `$KV.INVENTORY.>`, key `widget-blue`
at `$KV.INVENTORY.widget-blue`.

```
Subjects: $KV.INVENTORY.>          # one subject per key
Discard Policy: New                # at a limit, rejects the newest write
Direct Get: true                   # get reads without a consumer
Allows Rollups: true               # purge replaces a key with one marker
Allows Msg Delete: false           # deny_delete: no raw stream deletes
Maximum Per Subject: 10            # this IS the history depth
```

**`Discard Policy: New` explained, not just listed:** "Once the bucket hits a limit, it rejects the
newest write rather than silently dropping older messages to make room. **This is why limits reject:
the bucket keeps the messages it already holds rather than evicting them.**"

**The direct-get subject, written out.** A get "uses direct get: the server returns the last message
on a subject straight from storage. The request goes to
`$JS.API.DIRECT.GET.<stream>.<subject>`" — for the example key, literally
`$JS.API.DIRECT.GET.KV_INVENTORY.$KV.INVENTORY.widget-blue`. "That last message is the current value,
its sequence is the revision, and its store time is the entry timestamp." No consumer, no position,
no ack.

**Delete versus purge, with the headers:**

- **delete** → a marker carrying `KV-Operation: DEL`. "The key now reads empty, but every prior
  revision the bucket still keeps — up to its history depth — stays in the stream and readable through
  history."
- **purge** → a marker carrying `KV-Operation: PURGE` **and** `Nats-Rollup: sub`. "The rollup tells
  the stream to drop every earlier message on that subject and keep only this one marker."

The worked demonstration is the point: delete `widget-blue`, and `nats kv history` still lists the
PUT revisions plus a final DELETE row; purge `widget-red`, and its history "collapses to one entry".

**The trap the wiki did not carry: `deny_delete` does not stop a raw publish.**

> "The stream is built with `deny_delete` on so raw stream operations can't remove entries behind the
> KV API's back, but **that setting doesn't stop a raw publish** — which is exactly why you avoid
> one."

A raw `nats pub` to `$KV.<bucket>.<key>` "writes a bare message with none of them, so a watcher can't
tell it from a real put and a purge you meant never happens." The headers the KV API sets and a raw
publish does not: the expected-revision header for compare-and-swap, and `KV-Operation` /
`Nats-Rollup` for delete and purge.

**The key charset, spelled out and explained by the subject rule.** A key "may contain only letters,
digits, and `-`, `/`, `_`, `=`, and `.`, with no leading or trailing dot and no two dots in a row,
because anything else would be an illegal subject." An order id like `ord:8w2k` carries a colon, "so
it can't be a key, and the bucket rejects the write instead of storing a broken key."

## Practical takeaways

- Every KV operation has a stream mechanism: put is a message, get is a direct read of the last
  message per subject, history is messages kept per subject, a revision is a sequence, a watch is a
  consumer.
- **`deny_delete` protects against the delete API, not against a publisher.** An ACL on
  `$KV.<bucket>.>` is the only thing that stops a raw write corrupting a bucket
  ([[subject-permissions]]).
- Delete keeps history; only purge erases it. If a value was deleted *because* it was wrong or
  sensitive, it is one `nats kv history` away.

## Relevance to the wiki

Confirms [[key-value]]'s stream-config table from a second source and adds the raw-publish hole, the
literal direct-get subject, and the key charset.

## Questions it answers

Contributes to **Q73** (when a bucket is the wrong tool — the operations it does *not* protect).

## Pages touched

[[key-value]] · [[direct-get]] · [[subject-permissions]]

## Sources

The doc page.
