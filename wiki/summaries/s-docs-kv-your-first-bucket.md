---
title: "docs — Key/Value: Your first bucket"
type: summary
area: [kv, jetstream]
source-url: https://docs.nats.io/learn/key-value/your-first-bucket.md
source-path: raw/nats-docs/learn/key-value/your-first-bucket.md
author: nats-io docs
article: "learn/key-value/your-first-bucket.md"
date: 2026-08-31
version: ""
tags: [bucket, kv-add, history, revision, entry, bucket-name, key-charset]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — Key/Value: Your first bucket

The chapter's opening page. Short, and it carries two naming rules and one default the wiki had only
from the client side.

## Key claims

**One command creates the bucket and its stream.**

```
nats kv add INVENTORY --history 1
```

"This one command sets up the backing stream `KV_INVENTORY` on the subjects `$KV.INVENTORY.>`." The
bucket's status prints `JetStream Stream: KV_INVENTORY` back, so the mapping is visible from the KV
side without touching the stream commands.

**`--history 1` is the default**, "and all the inventory service needs to start. The depth can go as
high as 64, but no higher."

**Bucket names are case-sensitive identifiers** and the charset is narrower than a key's: the
chapter's own production checklist says "keep bucket names to alphanumerics, dashes, and underscores;
the server rejects anything else" (`where-next.md`). A **key** may additionally carry `/`, `=` and
`.`, with no leading or trailing dot.

**A put is unconditional and returns a revision.** "It stores the value whether or not the key already
exists. Each write also gets a revision: a number the bucket assigns **from a single counter it keeps
across every key, not a per-key count**." The API returns the revision to client code; "the CLI prints
only the value you stored."

**A get returns an entry, not a value** — "the value plus its revision and timestamp" — and `--raw`
asks for only the value. The checklist's matching rule: "check that an entry exists before reading
its value; a key-not-found isn't the same as an empty value."

## Practical takeaways

- Bucket names and key names have **different** legal charsets. A name that works as a key may be
  rejected as a bucket.
- `--history 1` is the default, so a bucket keeps no history unless you ask for it — and raising it
  later is not retroactive ([[s-docs-kv-history-and-revisions]]).
- Read the entry, not the value, whenever the answer "the key is absent" differs from "the key holds
  an empty value".

## Relevance to the wiki

Confirms [[key-value]]'s `max_msgs_per_subject` min/max (1–64) and the client default of 1 from the
docs' side rather than from ADR-8, and adds the bucket-name charset.

## Questions it answers

No bank row directly.

## Pages touched

[[key-value]] · [[nats-cli]]

## Sources

The doc page, plus the production checklist on `learn/key-value/where-next.md` for the two naming
rules (that page is a chapter recap and was not ingested separately).
