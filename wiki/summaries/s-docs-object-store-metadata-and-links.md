---
title: "docs — Object Store: Metadata and links"
type: summary
area: [objectstore, jetstream]
source-url: https://docs.nats.io/learn/object-store/metadata-and-links.md
source-path: raw/nats-docs/learn/object-store/metadata-and-links.md
author: nats-io docs
article: "learn/object-store/metadata-and-links.md"
date: 2026-08-31
version: ""
tags: [ObjectInfo, link, bucket-link, UpdateMeta, ErrCantGetBucket, ErrObjectAlreadyExists]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — Object Store: Metadata and links

The `ObjectInfo` record, the three fields you set on it, and **links** — the one object-store feature
the `nats` CLI cannot drive at all.

## Key claims

**`ObjectInfo` splits into computed and caller-set fields.** Computed by the store: "the byte size,
the chunk count, the SHA-256 digest, the modification time, and whether the object is deleted".
Set by the caller: a **description** (one human-readable label), **headers** (HTTP-style key/value
pairs, "the same shape as the headers on a NATS message"), and a **metadata** map (free-form
key/value strings).

**Reading metadata costs nothing extra.** "The store keeps the latest `ObjectInfo` for each name as
one small message, so `warehouse` can read an object's details without reading the bytes." The page
calls it "a low-cost index over the bucket".

**Metadata describes the current object only.** "Each re-put replaces the metadata, keeping only the
latest… the object store keeps the current `ObjectInfo`, not the trail of edits that produced it."

**A link is an object whose target is another object.** "A `get` on the link transparently returns
the target's bytes… The link is a reference rather than a copy: it stores no chunks of its own, only
a record of the target's bucket and name."

**A bucket link targets a whole bucket**, with an empty target name. "A `get` on a bucket link
doesn't return bytes — it returns an error (`ErrCantGetBucket` in Go). You read the link's info to
learn the target bucket, then open that bucket yourself."

**Two link rules the store enforces**: "A link can't point at a deleted object, and a link can't
point at another link — the store won't build a chain of links you'd have to follow."

**A link is a snapshot, not a live reference.** "Adding a link records the target's bucket and name
at creation time; it doesn't keep the target alive. Delete the target and the link is left dangling:
a get on the link traverses to a deleted object and fails with `ErrObjectNotFound`… Renames break a
link the same way: the link holds the old name."

**`UpdateMeta` silently discards two fields.** "`UpdateMeta` changes the name, description, headers,
and metadata, not the chunk size or the link. If you hand `UpdateMeta` a new chunk size or a new link
target, those fields are **discarded without error or notification**: the call succeeds, but neither
is stored." To change either you delete and re-create.

**Renaming onto a live name fails** with `ErrObjectAlreadyExists`; renaming onto a **deleted** name
succeeds and "reclaims the name for the renamed object".

**Links are client-library only.** The page says so in its own code block: "Adding a link is a
client-library operation (`AddLink` / `AddBucketLink`); the `nats` CLI has no link subcommand, so
this snippet is illustration only". The calls shown are `os.AddLink(...)` and `os.Get(...)`.

## Practical takeaways

- Links look like symlinks and are not: nothing keeps the target alive, nothing repairs them on
  rename, and there is no chain. Any design that leans on a stable alias must re-create the link
  whenever the target moves.
- A silently discarded `UpdateMeta` field is the kind of failure that shows up months later. The
  chunk size in particular is fixed at write time and there is no way to change it in place.

## Notable quotes

> "Those fields are discarded without error or notification: the call succeeds, but neither is
> stored."

> "A link is a snapshot rather than a live reference."

## Relevance to the wiki

[[object-store]] listed `UpdateMeta` in its operations table with one line ("updating metadata of a
deleted object is an error") and had nothing on links at all. Both the link model and the silent
`UpdateMeta` discard are operator-visible behaviours this wiki owed the reader.

## Questions it answers

None directly; supports Q73.

## Pages touched

[[object-store]] · [[key-value]]

## Sources

`raw/nats-docs/learn/object-store/metadata-and-links.md`
