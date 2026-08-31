---
title: "docs — Object Store: Under the hood"
type: summary
area: [objectstore, jetstream]
source-url: https://docs.nats.io/learn/object-store/under-the-hood.md
source-path: raw/nats-docs/learn/object-store/under-the-hood.md
author: nats-io docs
article: "learn/object-store/under-the-hood.md"
date: 2026-08-31
version: ""
tags: [OBJ_bucket, "$O.", Nats-Rollup, soft-delete, allow_rollup_hdrs, allow_direct, discard-new]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — Object Store: Under the hood

The page that takes the lid off: the bucket is one stream, `OBJ_<bucket>`, holding two subject
spaces, and the whole "latest wins" behaviour is one header. Everything on it was checked against the
running server (`raw/nats-server-src/object-store-observed-v2.14.6.md`) and matched.

## Key claims

**The bucket is the stream `OBJ_<bucket>`.** "When you ran `nats object add INVOICES`, the server
created a JetStream stream and named it by convention: `OBJ_<bucket>`… Every `put` was a publish to
that stream; every `get` was a read from it."

**Two subject spaces, verbatim:**

- `$O.INVOICES.C.>` — "the **chunk** messages: the bytes of every object, one message per chunk";
- `$O.INVOICES.M.>` — "the **metadata** messages: one `ObjectInfo` per object".

**The subject tails.** The chunk subject "ends in a per-put identity, `$O.INVOICES.C.<object-nuid>`,
which is why a re-put never collides with old chunks". The metadata subject "ends in the object name,
base64url-encoded as `$O.INVOICES.M.<base64url(name)>`, so any object name, spaces and slashes
included, becomes a safe NATS subject."

**The digest's stored form**: "the SHA-256 from the put, stored as `SHA-256=<base64url(hash)>`, the
exact string a get re-computes the reassembled bytes against."

**The backing stream config the page prints:**

```json
{
  "name": "OBJ_INVOICES",
  "subjects": ["$O.INVOICES.C.>", "$O.INVOICES.M.>"],
  "max_age": 0, "max_bytes": -1, "storage": "file", "num_replicas": 1,
  "discard": "new", "allow_rollup_hdrs": true, "allow_direct": true
}
```

with the reasons: "`AllowRollup` is true so the header is honored; the discard policy is set to `new`
so the stream **rejects writes when full rather than dropping old chunks**; `AllowDirect` is true so
a get can read the latest metadata without a consumer."

**Rollup is the whole mechanism.** "Every metadata publish carries one header, `Nats-Rollup: sub`.
That header tells the stream: when this message lands, purge every earlier message on the same
subject and keep only this one. Because each object name maps to one metadata subject, a rollup on a
re-put deletes the prior `ObjectInfo` for that name." The page's own summary: "This is why the store
is rollup-latest, not multi-revision."

**A delete is a rollup too.** "The store doesn't drop the name. It writes one more metadata message,
a **soft delete**, that marks the object `Deleted=true`, sets `Size` and `Chunks` to zero, and clears
the digest… the object's chunk messages are then purged from the stream." The surviving marker "is
what lets `watch` tell a subscriber that an object disappeared".

**The tombstone is hidden by default**: "to read it you pass the client's show-deleted option
(`GetObjectInfoShowDeleted` or `ListObjectsShowDeleted` in Go), **which the `nats` CLI doesn't
expose**."

**The disk pitfall.** "A delete writes the soft-delete metadata message and then purges the object's
chunks. The purge is what frees the bytes, and on a busy file-backed stream the on-disk space is
reclaimed as the stream cleans up, **not synchronously at the call**. Don't delete a large object and
immediately assert the disk is smaller."

**A re-put after a delete is a new identity**, "not a restored history… It creates a brand-new object
that happens to share the name."

**Securing the bucket is a plain subject problem**: "Securing these subjects (limiting who can
publish to `$O.INVOICES.C.>` or read `$O.INVOICES.M.>`, or exporting the bucket to another account)
is a security concern, not an object-store one."

## Practical takeaways

- `discard: new` on the backing stream means a full object bucket **rejects new puts** rather than
  ageing out old objects — the same failure shape a full KV bucket has, and the opposite of what a
  file-store intuition suggests.
- The metadata subject space is small and the chunk subject space is large; every operator-facing
  read (`ls`, `info`, `watch`) touches only the former, and every ACL should be written per subject
  space, not per bucket.

## Notable quotes

> "The object store is chunks plus rollup metadata on a JetStream stream."

> "The discard policy is set to `new` so the stream rejects writes when full rather than dropping old
> chunks."

## Relevance to the wiki

Confirms, from a hand-written page, everything [[object-store]] carried from ADR-20 alone — and adds
the `discard: new` rationale, the CLI's inability to show a tombstone, and the disk-reclamation
pitfall. The last of these the wiki has now **measured**, and the docs overstate it: 98.4 % of the
bytes come back with the call
(`raw/nats-server-src/object-store-observed-v2.14.6.md`, [[filestore-layout]]).

## Questions it answers

Q73 (the object-store half), Q75 (background).

## Pages touched

[[object-store]] · [[subject-permissions]] · [[filestore-layout]] · [[cross-account-sharing]]

## Sources

`raw/nats-docs/learn/object-store/under-the-hood.md` · run against the server in
`raw/nats-server-src/object-store-observed-v2.14.6.md`
