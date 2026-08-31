<!-- source: https://docs.nats.io/learn/object-store/your-first-object.md · fetched 2026-08-31 · section: your-first-object -->
# Your first object

Acme's `order-svc` already publishes order messages into the `ORDERS` stream. But an order produces more than a message. Once payment clears it produces an invoice PDF, a file too large and too binary to send as a message payload. That file needs to be stored somewhere, and the `warehouse` service needs to fetch it back before it ships the box.

That somewhere is an **object store**. This page creates Acme's first bucket, stores one invoice in it, and gets that invoice back. This page covers two operations, `put` and `get`.

## A bucket holds objects

A **bucket** is a named object store. An **object** is one stored file: a name and its bytes. The bucket for this chapter is `INVOICES`, and it will hold invoice PDFs for Acme's orders.

A bucket is backed by a JetStream stream, the same kind you built in the [JetStream deep dive](/learn/jetstream/.md). You don't create that stream yourself; creating the bucket creates it for you. Everything you already know about streams still applies underneath, and this chapter points back to it rather than re-teaching it.

Create the bucket with a name and a human-readable description:

#### CLI

```
#!/bin/bash

# Create the INVOICES bucket. A bucket is a named object store: hand it a

# name and a description and the server provisions the JetStream stream

# that backs it. `order-svc` will put invoice PDFs here; `warehouse` will

# get them before shipping.

#

# The --description text is stored on the bucket and shows up in

# `nats object info INVOICES`.

nats object add INVOICES --description "Invoice PDFs"
```

The description is stored on the bucket and shows up whenever you inspect it. The bucket name follows the same rule as a stream name: letters, digits, underscores, and dashes only. `INVOICES` is fine.

## Put: store a name and bytes

**Put** is the store verb. You give the store an object name and its bytes, and the store keeps them. The bytes can come from a file on disk, from memory, or from a stream you read as you go. Every client offers convenient forms for these.

Here `order-svc` puts the invoice for order `ord_8w2k`:

#### CLI

```
#!/bin/bash

# Put a file into the bucket. `order-svc` hands the store a name and the

# bytes; the store splits the bytes into chunks, computes a running

# SHA-256 digest as it goes, and finishes by writing one metadata message

# that records the name, size, chunk count, and digest.

#

# By default the object name is the file path exactly as you type it

# (cleaned), not just its basename: putting ./invoices/invoice-ord_8w2k.pdf

# would store the object as `invoices/invoice-ord_8w2k.pdf`. Run the command

# from the file's directory, or pass --name to control the stored name. Here

# the argument is a bare filename, so the object is stored as

# invoice-ord_8w2k.pdf.

nats object put INVOICES invoice-ord_8w2k.pdf



# You can also pipe bytes in from stdin instead of a file on disk. Then

# --name is required, because there is no filename to take the name from.

echo "PDF-bytes-for-ord_8w2k" | nats object put INVOICES --name invoice-ord_8w2k.pdf
```

Three things happen inside that one call. First, the store splits the bytes into pieces. Each piece is one message. You'll see that splitting in detail on the [next page](/learn/object-store/chunking.md); for now it's enough to know a large file doesn't become one giant message.

Second, as the bytes flow past, the store computes a running **SHA-256 digest**, a fixed-size fingerprint of the exact bytes you put. A digest is a one-way hash: the same bytes always produce the same digest, and any change to the bytes produces a different one.

Third, once the bytes are stored, the store writes a final metadata record for the object. That record holds the object's name, its size, the number of pieces, and the digest. The digest is the part that matters on get.

## Get: fetch by name, verified

**Get** is the fetch verb. You ask for an object by name, and the store hands the bytes back. The `warehouse` service gets the invoice it needs to ship `ord_8w2k`:

#### CLI

```
#!/bin/bash

# Get the file back. `warehouse` asks for the object by name. The store

# reads the metadata for that name, streams the chunks back in order,

# reassembles them, and verifies the reassembled bytes against the stored

# SHA-256 digest before handing them over. A digest mismatch is an error,

# not a silently truncated file.

#

# Without --output the bytes are written to a file named after the object

# in the current directory.

nats object get INVOICES invoice-ord_8w2k.pdf



# Override the destination filename with --output. The target directory

# must already exist; the CLI writes the file, it does not create parent

# directories.

nats object get INVOICES invoice-ord_8w2k.pdf --output ./warehouse/invoice.pdf
```

Get verifies the bytes before returning them. The store reads the object's metadata record, streams the pieces back in order, reassembles them, and recomputes the SHA-256 digest of what it reassembled. Only if that digest matches the one recorded on put does get return the bytes. If the two differ (a piece went missing, a transfer was cut short), get returns an error instead of a corrupt file.

That's the contract of an object store: what you get is byte-for-byte what you put, or you get an error. The store does not return a quietly truncated file.

## Watch put and get flow

The animation below shows the round trip. On put, `order-svc` sends the pieces and then the metadata record into the `INVOICES` bucket. On get, `warehouse` reads the metadata first, then pulls the pieces in order, reassembles them, and verifies the digest before handing the invoice over.

**Message flow — Object put and get (animated):** The Object Store splits a large object into chunks. Writing to the INVOICES bucket, order-svc streams four chunk messages and then a metadata message. Reading it back, the warehouse receives the metadata first, then the chunks, and reassembles them in order; a digest check over the reassembled bytes turns green when it verifies.

* order-svc → INVOICES
* order-svc → INVOICES
* INVOICES → warehouse
* INVOICES → warehouse

Put writes the pieces and then the metadata, while get reads the metadata and then the pieces and then verifies. That ordering is what lets get know how many pieces to expect and what digest to check them against.

## Pitfalls

Two mistakes are common on a first object. Both come from treating put and get as if they couldn't fail.

**A digest mismatch means do not use the bytes.** The metadata record is written last, after the pieces, so an interrupted put (the process dies, the connection drops) leaves no gettable object at all: a get reports the name as not found, not a corrupt file. A digest mismatch is a different failure. It means the object was stored whole but some of its pieces were lost or corrupted afterward, so get verifies the reassembled bytes against the stored digest and returns `ErrDigestMismatch`. The mistake is to ignore that error and use the bytes anyway. Do check the get result before you act on it; an `ErrDigestMismatch` means retry the get, and a repeated mismatch means the object is damaged and should be put again. Don't assume a put "worked" without a get confirming it round-trips.

**Getting a missing object is an error, not empty bytes.** Ask for a name that was never put, or one that has been deleted, and get fails with a not-found error; it doesn't hand back an empty file. The `warehouse` must treat "invoice not found" as a real branch: the invoice may not have been produced yet. Do check for the not-found case and retry or wait; don't ship the order on the assumption that an absent invoice is an empty one.

Here's the not-found path, and the safe check that precedes a get:

#### CLI

```
#!/bin/bash

# Getting a name that was never put — or one that has been deleted —

# fails with a not-found error rather than returning empty bytes. Always

# check the result of a get before using what it returns.

#

#   nats: error: nats: object not found

#

# In a client library this surfaces as ErrObjectNotFound. Treat it as a

# normal branch: the warehouse asked for an invoice that has not been

# produced yet, so wait and retry rather than shipping without it.

nats object get INVOICES invoice-ord_NOPE.pdf



# Confirm the object exists before you depend on its bytes. `nats object

# info` returns the metadata if the name is present and the same

# not-found error if it is not.

nats object info INVOICES invoice-ord_8w2k.pdf
```

The full set of object store configuration options is documented in [Reference](/reference/.md). We only need put, get, and the digest behavior here.

## Where you are

You now have:

* An `INVOICES` bucket, backed by a JetStream stream the server created for you.
* One object, `invoice-ord_8w2k.pdf`, put by `order-svc`.
* That same invoice fetched back by `warehouse`, with its SHA-256 digest verified on the way out.

The session is live. The next pages add to this exact bucket rather than starting over.

## What's next

Put split the invoice into pieces and get reassembled them. The next page names that mechanism, **chunking**, and stores an invoice large enough to span many chunks, so you can read the chunk count for yourself.

Continue to [Chunking](/learn/object-store/chunking.md).

## See also

* [JetStream deep dive](/learn/jetstream/.md) — the streams that back every bucket.
* [Reference](/reference/.md) — the full set of object store configuration options.
* [Key-Value deep dive](/learn/key-value/.md) — the sibling store for small, multi-revision values.
