---
title: "docs — Object Store: Your first object"
type: summary
area: [objectstore, jetstream]
source-url: https://docs.nats.io/learn/object-store/your-first-object.md
source-path: raw/nats-docs/learn/object-store/your-first-object.md
author: nats-io docs
article: "learn/object-store/your-first-object.md"
date: 2026-08-31
version: ""
tags: [put, get, digest, SHA-256, ErrObjectNotFound, bucket-name]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — Object Store: Your first object

The chapter's opening page: create a bucket, `put` a file, `get` it back. Its value to this wiki is
not the two verbs but the **ordering guarantee** it states plainly and the two error branches it
insists are normal.

## Key claims

**A bucket is created, and the backing stream comes with it.** `nats object add INVOICES
--description "Invoice PDFs"` — "you don't create that stream yourself; creating the bucket creates
it for you."

**The bucket name rule is the stream name rule**: "letters, digits, underscores, and dashes only."

**Put is three steps, in this order**: split the bytes into chunks (one message each); compute a
running **SHA-256 digest** over the bytes as they flow; then write "a final metadata record for the
object" holding "the object's name, its size, the number of pieces, and the digest".

**The metadata is written last, and that is the durability contract.** "Put writes the pieces and
then the metadata, while get reads the metadata and then the pieces and then verifies. That ordering
is what lets get know how many pieces to expect and what digest to check them against."

**Get verifies before returning.** The store "recomputes the SHA-256 digest of what it reassembled.
Only if that digest matches the one recorded on put does get return the bytes." The chapter states
the contract in one sentence: *"what you get is byte-for-byte what you put, or you get an error. The
store does not return a quietly truncated file."*

**Two distinct failure modes, and the page is careful to separate them:**

- an **interrupted put** "leaves no gettable object at all: a get reports the name as not found, not
  a corrupt file";
- a **digest mismatch** "means the object was stored whole but some of its pieces were lost or
  corrupted afterward", and get returns `ErrDigestMismatch`.

**Not-found is a branch, not a failure.** "Ask for a name that was never put, or one that has been
deleted, and get fails with a not-found error; it doesn't hand back an empty file." In a client this
is `ErrObjectNotFound`.

**The CLI's object name is the path you typed, cleaned — not the basename.** "Putting
`./invoices/invoice-ord_8w2k.pdf` would store the object as `invoices/invoice-ord_8w2k.pdf`. Run the
command from the file's directory, or pass `--name` to control the stored name." Piping from stdin
**requires** `--name`.

**`nats object get --output` does not create parent directories**: "The target directory must
already exist; the CLI writes the file, it does not create parent directories."

## Practical takeaways

- The name-from-path behaviour is a real operational trap: a script that puts files by relative path
  from a parent directory silently stores objects under names containing `/`.
- "A put worked" is not observable from the put. The page's advice is to confirm with a get that
  reassembles and verifies.

## Notable quotes

> "What you get is byte-for-byte what you put, or you get an error."

> "The metadata record is written last, after the pieces, so an interrupted put leaves no gettable
> object at all."

## Relevance to the wiki

[[object-store]] carried the chunk/metadata split from ADR-20 but not the **write ordering** that
makes a failed put safe, and not the two named client errors. Both land here.

## Questions it answers

Q73 (partly — the object-store half of "when is this the wrong tool").

## Pages touched

[[object-store]]

*(Struck at ingest: [[jetstream-sizing]]. The page is about the put/get contract and the two client
error branches; it carries no rate, size, count or overhead figure, so there is nothing here for a
sizing page to hold. The chunk-count arithmetic sizing needs comes from
[[s-docs-object-store-chunking]] instead.)*

## Sources

`raw/nats-docs/learn/object-store/your-first-object.md`
