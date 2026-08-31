<!-- source: https://docs.nats.io/learn/object-store/metadata-and-links.md · fetched 2026-08-31 · section: metadata-and-links -->
# Metadata and links

An object carries more than its bytes. So far `invoice-ord_8w2k.pdf` is only a name and a payload: `warehouse` has to fetch the whole thing to learn anything about it. This page adds metadata to the object: a human-readable description, HTTP-style headers, and a free-form metadata map that travel with the object. Then it teaches links, so one object can stand in for another.

The invoices you stored on the previous pages are still in the `INVOICES` bucket; keep that terminal open.

## Every object carries an ObjectInfo

When you `put` an object, the store writes the chunks and then one final metadata message describing the whole thing. That metadata message is an `ObjectInfo` record. Some of its fields the store computes for you: the byte size, the chunk count, the SHA-256 digest, the modification time, and whether the object is deleted. Three fields are ones you set.

The first is the **description**: a single human-readable label for the object. The second is **headers**: HTTP-style key/value pairs, the same shape as the headers on a NATS message. The third is the **metadata** map: free-form key/value strings for whatever your application wants to record.

Set them on the put. `order-svc` stores the invoice with a description and a `content-type` header so a reader knows the bytes are a PDF without fetching them first:

#### CLI

```
#!/bin/bash

# Put an invoice with metadata attached. Beyond the bytes, every object

# carries an ObjectInfo record. Three of its fields are yours to set:

#   --description  a human label for the object

#   -H / --header  HTTP-style headers (repeatable)

# and a free-form metadata map, set in the client libraries.

#

# Here `order-svc` stores invoice-ord_8w2k.pdf with a description and a

# content-type header so a reader knows the bytes are a PDF without

# downloading them first.

nats object put INVOICES invoice-ord_8w2k.pdf \

  --description "Invoice for order ord_8w2k" \

  --header "content-type:application/pdf"



# The metadata travels in the one metadata message that follows the

# chunks, so it costs nothing extra to read it back later — it is already

# beside the object, not in a separate lookup.
```

The object name and the bytes are unchanged: this is the same `invoice-ord_8w2k.pdf` from your first object, now carrying a description and a header. The metadata is held in that one trailing metadata message, so it adds no extra storage cost and no extra read cost.

## Reading the metadata back

Reading the metadata doesn't fetch the object's bytes. The store keeps the latest `ObjectInfo` for each name as one small message, so `warehouse` can read an object's details without reading the bytes.

#### CLI

```
#!/bin/bash

# Read the ObjectInfo for one object. `nats object info` prints the

# metadata you set (description, headers, metadata map) alongside the

# fields the store computed for you: size, chunk count, the SHA-256

# digest, the modification time, and whether the object is deleted.

#

# `warehouse` reads this before fetching the bytes — the content-type

# header tells it the object is a PDF, and the size tells it how big the

# get will be.

nats object info INVOICES invoice-ord_8w2k.pdf



# Expected output (abridged):

#

#   Object information for INVOICES > invoice-ord_8w2k.pdf

#

#              Size: 12 KiB

#      Modified: 2026-05-22 10:14:22

#         Chunks: 1

#         Digest: SHA-256=...

#   Description: Invoice for order ord_8w2k

#          Headers: content-type: application/pdf
```

The output shows your description and header next to the computed fields: size, chunks, digest, modification time. `warehouse` reads the `content-type` header and the size here, then decides whether to fetch the bytes. The metadata is a low-cost index over the bucket, and you only read the larger bytes when you need them.

There's one boundary to keep in mind. The metadata describes the *current* object, not a history of past versions. Each re-put replaces the metadata, keeping only the latest. If you want a full revision history per name, that's the Key-Value store's job, covered in [Key-Value](/learn/key-value/.md); the object store keeps the current `ObjectInfo`, not the trail of edits that produced it.

## Links point one object at another

A **link** is an object whose target is another object. A `get` on the link transparently returns the target's bytes: you request the link, the store follows it and returns the target. The link is a reference rather than a copy: it stores no chunks of its own, only a record of the target's bucket and name.

This is useful when two names should resolve to the same bytes. In the Acme platform a shipping label and an invoice can share a document, or a stable name can serve as the entry point for a frequently changing set of files. Here `label-ord_8w2k.png` becomes a link to the invoice, so fetching the label returns the invoice's bytes:

#### CLI

```
#!/bin/bash

# Add a link from one object to another. A link is an object whose target

# is another object; a get on the link transparently returns the target's

# bytes. Here `label-ord_8w2k.png` is a link that points at the invoice, so

# fetching the label hands back the invoice.

#

# Adding a link is a client-library operation (AddLink / AddBucketLink); the

# `nats` CLI has no link subcommand, so this snippet is illustration only —

# it shows the shape of the call with a client. The store records the target

# {bucket, name} at creation time, then traverses it on get.

#

# Pseudocode:

#

#   invoice = os.GetInfo("invoice-ord_8w2k.pdf")

#   os.AddLink("label-ord_8w2k.png", invoice)

#

# Once the link exists, a client get on the link name returns the invoice

# bytes, traversed for you:

#

#   os.Get("label-ord_8w2k.png")   # returns the invoice's bytes



# A bucket link points at a whole bucket instead of one object: pass an

# empty target name. It stores only a reference to the other bucket, so a

# get on a bucket link returns an error (ErrCantGetBucket in Go), not bytes.

# Read the link's info to learn the target bucket, then open that bucket

# yourself. Reach for a bucket link when you want a stored pointer to

# another store, not a gettable object.
```

A link can also target a whole bucket instead of a single object. That's a **bucket link**: the target name is empty, so it records only a reference to another bucket. A `get` on a bucket link doesn't return bytes — it returns an error (`ErrCantGetBucket` in Go). You read the link's info to learn the target bucket, then open that bucket yourself. Reach for a bucket link when you want a stored pointer to another store, not a gettable object.

Two rules constrain links, and the store enforces both. A link can't point at a deleted object, and a link can't point at another link — the store won't build a chain of links you'd have to follow. When you add a link, the store records the target as it stands at that moment and traverses it on every get from then on.

The full set of `ObjectInfo` fields and link options is documented in [Reference](/reference/.md). We only need the behavior here.

## Pitfalls

Metadata and links have two pitfalls: what a link does when its target moves, and what `UpdateMeta` will and won't change.

**A link is a snapshot rather than a live reference.** Adding a link records the target's bucket and name at creation time; it doesn't keep the target alive. Delete the target and the link is left dangling: a get on the link traverses to a deleted object and fails with `ErrObjectNotFound`. The link still exists, but its destination does not. Renames break a link the same way: the link holds the old name, so renaming the target leaves the link pointing at a name that no longer resolves. Do not assume `addLink` keeps the target around or follows it under a rename. Do verify the target exists with `info` before you depend on the link, and re-create the link after you delete or rename its target.

You can see the failure and the safe check side by side. Delete the invoice, get the now-stale label link, confirm the target with `info`, then re-put the invoice so the link resolves again and the bucket is back to where you left it:

#### CLI

```
#!/bin/bash

# A link is a snapshot of its target at creation time, not a live

# reference that keeps the target alive. Delete the target and the link

# is left dangling: a get on the link fails with a not-found error.

#

# Delete the invoice that label-ord_8w2k.png points at:

nats object rm INVOICES invoice-ord_8w2k.pdf --force



# Now get the link. The store traverses to invoice-ord_8w2k.pdf, finds it

# deleted, and fails — the link still exists, but its target does not:

#

#   nats: error: nats: object not found

#

# In a client library this surfaces as ErrObjectNotFound. Always confirm

# the target exists before depending on a link, and re-create the link

# after you delete or rename its target.

nats object get INVOICES label-ord_8w2k.png



# Confirm the target before you depend on the link. `nats object info`

# returns the metadata if the target is present and the same not-found

# error if it is gone:

nats object info INVOICES invoice-ord_8w2k.pdf



# Restore the running example. Re-put the invoice with its description and

# content-type header so the bucket is back to where the chapter left it

# and the label link resolves again:

nats object put INVOICES invoice-ord_8w2k.pdf --force \

  --description "Invoice for order ord_8w2k" \

  --header "content-type:application/pdf"
```

**`UpdateMeta` changes the name, description, headers, and metadata, not the chunk size or the link.** Changing the name renames the object in place. If you hand `UpdateMeta` a new chunk size or a new link target, those fields are discarded without error or notification: the call succeeds, but neither is stored. The chunk size is fixed when the bytes are written, and a link target is fixed when the link is created. Don't expect `UpdateMeta` to re-chunk an object or to change a link target. To change the chunk size, delete the object and put it again. To change a link target, delete the link and add a new one. And don't rename onto a name already in use: renaming an object to an existing, non-deleted name fails with `ErrObjectAlreadyExists`. You *can* rename onto a name that was deleted; that reclaims the name for the renamed object.

## Where you are

You now have:

* `invoice-ord_8w2k.pdf` carrying a description and a `content-type` header, readable without fetching the bytes.
* `label-ord_8w2k.png` as a link to the invoice, traversed transparently on get.
* A working sense of the two link rules (no link to a deleted object, no link to a link) and of what `UpdateMeta` does and doesn't touch.

The bucket now holds an object that carries its own metadata, and a link beside it. The next page moves from single objects to the whole bucket: how to take a snapshot of everything in it, and how to watch it change in real time.

## What's next

The next page teaches list and watch: a snapshot of every object in the bucket, and a live stream of metadata updates as `analytics` watches the bucket fill.

Continue to [Watching and listing](/learn/object-store/watching-and-listing.md).

## See also

* [Key-Value](/learn/key-value/.md) — the multi-revision store, when you want a history per key rather than the latest object.
* [Reference](/reference/.md) — the full set of `ObjectInfo` fields and link options.
