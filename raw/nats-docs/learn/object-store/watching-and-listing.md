<!-- source: https://docs.nats.io/learn/object-store/watching-and-listing.md · fetched 2026-08-31 · section: watching-and-listing -->
# Watching and listing

The `INVOICES` bucket now holds a few objects: `invoice-ord_8w2k.pdf` with its description and `content-type` header, the large multi-chunk `invoice-ord_9x3m.pdf` from the Chunking page, and `label-ord_8w2k.png` linked to the first invoice. Getting one back means knowing its name. But the `analytics` service doesn't know the names ahead of time. It wants to discover what's in the bucket, and to learn the moment a new object lands.

This page gives it two operations. List takes a snapshot of every object in the bucket right now, and watch streams metadata updates as they happen, so `analytics` sees each new invoice the instant `order-svc` puts it. These are the two ways to read a bucket without already knowing what's inside it.

## List is a snapshot

A **list** returns every non-deleted object in the bucket as a one-time snapshot. It doesn't stay open and it doesn't stream changes; it answers the question "what's in here now?" and returns.

Run it against `INVOICES`:

#### CLI

```
#!/bin/bash

# List every live object in the INVOICES bucket. `analytics` does not know

# the object names ahead of time, so it lists the bucket to discover what

# is there right now. A list is a one-time snapshot: it reads metadata for

# each object and returns — it does not stay open or stream changes.

#

# A list reads metadata only, never chunks, so it is cheap even when the

# objects themselves are large. Soft-deleted objects are filtered out: the

# list shows only what is really in the bucket.

nats object ls INVOICES



# Expected output: one row per object, metadata only, e.g.

#

#   Name                   Size     Time

#   invoice-ord_8w2k.pdf   18 KiB   2026-05-22 10:14:22

#   invoice-ord_9x3m.pdf   3.0 MiB  2026-05-22 10:15:30

#   label-ord_8w2k.png     0 B      2026-05-22 10:15:01

#

# An empty bucket is not an error — it lists zero rows. In client code an

# empty bucket surfaces as a "no objects found" condition; treat it as the

# valid answer "nothing here yet", not as a failure.
```

The result is one entry per object: `invoice-ord_8w2k.pdf`, `invoice-ord_9x3m.pdf`, and `label-ord_8w2k.png`. Each entry carries the object's metadata (name, size, chunk count, description, modification time) but not its bytes. A list is cheap: it reads metadata, never chunks. You can list a bucket of thousand-megabyte invoices without moving any of the object data.

A list skips soft-deleted objects. When `order-svc` removes an invoice, the object is marked deleted and its chunks are purged, but a metadata record lingers to mark the deletion. List filters those out, so it shows only what's really there. The deletion mechanism itself lives on [Under the hood](/learn/object-store/under-the-hood.md); here, the behavior is all you need: list shows only live objects.

An empty bucket isn't an error. Listing a freshly created bucket returns an empty result, not a failure. In the client libraries it surfaces as a "no objects found" condition you treat as zero results, not as a problem. The Pitfalls section makes that distinction runnable.

## Watch streams metadata updates

A **watch** is the live counterpart to list. It opens a stream of metadata updates and stays open, delivering one update each time an object in the bucket changes, whether that change is a new put, a re-put, or a delete. It's how `analytics` keeps up with the bucket instead of polling list in a loop.

Start `analytics` watching `INVOICES`. Run this in its own terminal and leave it running:

#### CLI

```
#!/bin/bash

# Watch the INVOICES bucket for changes. This is the `analytics` service:

# it wants to learn about every new invoice the instant `order-svc` puts

# it, with no polling.

#

# A watch delivers metadata updates in order, one per change (put, re-put,

# or delete). When it has caught up with everything already in the bucket,

# it delivers a single nil sentinel to mark the snapshot/live boundary,

# then streams live changes until you stop it (Ctrl-C). The CLI consumes

# the sentinel for you and keeps printing. Run this in its own terminal.

nats object watch INVOICES



# Expected output: one line per existing object (the catch-up snapshot),

# then it waits. Leave it running and, from another terminal, have

# `order-svc` put the packing slip for the same order:

#

#   echo "PACK ord_8w2k: 3 items" | \

#     nats object put INVOICES --name packing-slip-ord_8w2k.txt

#

# The watch prints the live metadata update the moment the put lands:

#

#   [2026-05-22 10:16:40] PUT INVOICES > packing-slip-ord_8w2k.txt

#

# Each update carries the object's metadata — name, size, chunk count,

# digest — never the chunk bytes. To read the data, issue a separate get.
```

The watch delivers in order. Updates arrive in the sequence the bucket recorded them, so `analytics` never sees a later state before an earlier one. When the watch has caught up with everything already in the bucket, it delivers a single **nil sentinel**: one empty update that signals "you're now current; everything after this is a live change." The CLI consumes that sentinel for you and keeps printing. In client code you see it and handle it: recognize the nil update as the boundary, then keep reading.

Now, from another terminal, have `order-svc` put a new object, the packing slip for the same order:

```
echo "PACK ord_8w2k: 3 items" | nats object put INVOICES --name packing-slip-ord_8w2k.txt
```

The update appears in the watching terminal the instant the put lands, without any polling or delay. `analytics` learned about `packing-slip-ord_8w2k.txt` as soon as `order-svc` stored it.

**Message flow — Object watch and sync (animated):** A watch on the INVOICES object store is metadata-then-bytes. order-svc puts an object; the watch pushes a metadata-only update to the analytics watcher, which then issues a separate get to fetch the actual bytes. The update tells the watcher what changed; the bytes come only when it asks for them.

* order-svc → INVOICES
* INVOICES → analytics
* analytics → INVOICES (subject: get invoice-7841 bytes)

That update carries the new object's *metadata* (name, size, chunk count, digest) and nothing else; the bytes are not on the watch. That is the most important fact about watch, and the next section covers it.

## Watch carries metadata, never the bytes

An object's metadata and its chunks live on two different subjects. A watch subscribes to the metadata side. So every update it delivers is an `ObjectInfo` record — never the chunk bytes that make up the object's data.

This is by design, and it's what makes watch cheap. `analytics` can watch a bucket of 3 MB invoices and 100 MB media files without any object data crossing the watch. It learns that an object changed and what its metadata says; if it wants the data, it issues a separate get.

The pattern is two steps: watch to learn what changed, then get the bytes you actually want. `analytics` only needs the invoice total for its dashboard, so it might read the metadata and never get the data at all. A re-rendering service would watch, then get every new object. Both read the same watch; they differ only in whether step two runs.

This separation is also the difference from the Key-Value store's watch. There, a watch delivers each key's *value* directly, because values are small. Here, an object can be gigabytes, so the watch delivers only the metadata and leaves the data fetch to you. The contrast is covered on [Key-Value → Watching](/learn/key-value/watching.md); the rule for objects is that watch tells you what changed and get returns the bytes.

A watch has more options than the plain form shown here: replaying full history, ignoring deletes, or skipping the catch-up snapshot to see only new updates. They tune the same stream of metadata you just saw. The full set of watch options is documented in [Reference](/reference/.md). We only need the default behavior here.

## Pitfalls

Two mistakes are common the first time you read a bucket without knowing its contents. Both come straight from this page's two concepts: what a list returns, and what a watch delivers.

**Watch delivers metadata, not the bytes.** A watch update is an `ObjectInfo` record: name, size, chunk count, digest. It is not the object's data. A service that treats the watch update as the file, and tries to read a 100 MB payload off the watch, finds only metadata and breaks. The fix is the two-step pattern: use watch to learn *what* changed, then issue a get for the objects whose bytes you actually need. Do not expect the data to arrive on the watch.

Watch, then get only when you need the bytes:

#### CLI

```
#!/bin/bash

# Watch tells you WHAT changed; get gives you the bytes. A watch update is

# an ObjectInfo record — name, size, chunk count, digest — and never the

# object's data. The chunks live on a separate subject, so the bytes do

# not ride the watch. This keeps watch cheap even for gigabyte objects.

#

# The pattern is two steps: watch to learn what changed, then get only the

# objects whose bytes you actually need. Do not expect the data to arrive

# on the watch.

#

# Step 1 — watch for changes (run in its own terminal, leave it running):

nats object watch INVOICES



# The watch prints a metadata line when `order-svc` puts a new object,

# e.g.

#

#   [2026-05-22 10:16:40] PUT INVOICES > packing-slip-ord_8w2k.txt

#

# Step 2 — now that you know what changed, get the bytes you want. Run

# this from another terminal for the object the watch reported. Without

# --output the file lands in the current directory under the object's name;

# --output writes it to a path you choose (the directory must exist):

nats object get INVOICES packing-slip-ord_8w2k.txt --output ./packing-slip-ord_8w2k.txt



# In client code the loop reads the watch, branches on the nil sentinel

# (the snapshot/live boundary) and keeps going, then issues a get only for

# the objects it needs:

#

#   for info in watcher:

#       if info is None:                 # caught-up sentinel; keep reading

#           continue

#       if needs_bytes(info.name):       # only fetch what you actually use

#           data = bucket.get_bytes(info.name)

#

# Reading the bytes directly off the watch update would find only

# metadata. Use watch to learn what, get to fetch the data.
```

**An empty bucket is an empty result, not an error.** Listing a bucket with no live objects doesn't fail; it returns zero entries. In the client libraries this surfaces as a distinct "no objects found" condition, and code that treats it as a fatal error will crash on a bucket that's just empty, or one whose objects were all deleted. Do treat an empty list as the valid answer "nothing here yet." Don't conflate "no objects" with "the bucket is missing"; those are different conditions, and only the second is a real problem.

## Where you are

You now have:

* A list of `INVOICES`: a snapshot of `invoice-ord_8w2k.pdf`, `invoice-ord_9x3m.pdf`, and `label-ord_8w2k.png`, metadata only, soft-deleted objects filtered out.
* `analytics` watching the bucket, with `packing-slip-ord_8w2k.txt` added during the demo and surfaced as a live metadata update.
* The two-step pattern in hand: watch tells you what changed; get fetches the bytes.

## What's next

You've now used the bucket from every angle: put, get, chunking, metadata, links, list, and watch. The last page shows the internals. The bucket *is* a JetStream stream named `OBJ_INVOICES`, and the next page reads its stream config to show you the chunk and metadata subjects, the rollup that keeps one current record per object, and how a soft delete really works.

Continue to [Under the hood](/learn/object-store/under-the-hood.md).

## See also

* [Key-Value → Watching](/learn/key-value/watching.md) — the per-key watch that delivers values directly, and how it contrasts with object watch.
* [Under the hood](/learn/object-store/under-the-hood.md) — the metadata subject a watch reads and the soft delete a list filters out.
* [Reference](/reference/.md) — the full set of watch options.
