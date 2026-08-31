<!-- source: https://docs.nats.io/learn/key-value/watching.md · fetched 2026-08-31 · section: watching -->
# Watching

You have the `INVENTORY` bucket from the last page, with `widget-blue` at `42`. Reading it with get tells you the count *now*. The warehouse dashboard needs the count the moment it changes, without polling get in a loop.

A watch does that. This page runs the warehouse dashboard watching `INVENTORY`, shows you the two things a watch always delivers in order, and ends with a wildcard watch over a subset of keys.

## What a watch delivers

A **watch** delivers the current value of every matching key as an initial snapshot, and then streams every later change as it happens. One call gives you both halves: the state of the bucket now, and the changes from now on.

Start the warehouse dashboard watching the whole bucket. Run this in its own terminal and leave it running:

#### CLI

```
#!/bin/bash



# Watch the whole INVENTORY bucket. This is the warehouse dashboard:

# it wants every stock change as it happens, with no polling.

#

# On start, watch first replays the current value of every key in the

# bucket as an initial snapshot, then blocks and streams live changes

# until you stop it (Ctrl-C). Run this in its own terminal.

nats kv watch INVENTORY



# Expected output: one line per existing key (the snapshot), e.g.

#

#   [2026-05-22 10:14:22] PUT INVENTORY > widget-blue: 42

#

# then it waits. Leave it running and put a new count from another

# terminal:

#

#   nats kv put INVENTORY widget-blue 41

#

# The watch prints the live update the moment it lands:

#

#   [2026-05-22 10:15:03] PUT INVENTORY > widget-blue: 41
```

#### C

```
// Watch the whole INVENTORY bucket. The watch first delivers the

// current value of every key (the snapshot), then streams every

// later change as it lands.

kvEntry *e = NULL;



s = kvStore_WatchAll(&w, kv, NULL);

while (s == NATS_OK)

{

    s = kvWatcher_Next(&e, w, 60000);

    if (s != NATS_OK)

        break;

    // A NULL entry marks the end of the snapshot. Skip it and

    // keep reading: everything after it is a live change.

    if (e == NULL)

        continue;

    printf("%s: %.*s\n", kvEntry_Key(e),

           kvEntry_ValueLen(e), (const char*) kvEntry_Value(e));

    kvEntry_Destroy(e);

    e = NULL;

}
```

The snapshot comes first. The watch immediately prints the current value of every key already in the bucket; right now that's one line for `widget-blue` at `42`. Then it blocks, waiting.

Now, from another terminal, change a count:

```
nats kv put INVENTORY widget-blue 41
```

The line appears in the watching terminal the instant the put lands, without polling and without delay. The dashboard receives the change as soon as the inventory service records it.

The inventory service also stocks two more SKUs, so the bucket holds more than one key from here on:

```
nats kv put INVENTORY widget-red 17

nats kv put INVENTORY gadget-pro 5
```

Each put appears in the watching terminal the moment it lands, the same as the change to `widget-blue`.

The snapshot-then-live shape matters here. A new dashboard that connects mid-day doesn't start without data: it gets the full current picture first, then keeps up with every change after. A watch covers both reading the state and watching for changes, so you don't have to choose between them.

**Message flow — KV watch — snapshot then live (animated):** A KV watch is snapshot-then-live. The warehouse-dashboard opens a watch on KV\_INVENTORY, which creates an ephemeral ordered consumer over the backing stream. The current value of every key replays first as the initial snapshot; a nil end-of-initial-data marker signals the watcher is caught up; from then on each fresh put streams through live.

* warehouse-dashboard → KV\_INVENTORY
* KV\_INVENTORY → ordered consumer
* ordered consumer → warehouse-dashboard

Underneath, a watch is an ephemeral ordered consumer on the backing stream, replaying the last value per key and then following new writes. You don't configure or manage it: opening the watch creates it, and closing the watch removes it. How consumers track position and deliver messages is the JetStream chapter's job; see [Why a stream](/learn/jetstream/your-first-stream.md#why-a-stream) if you want the layer below. Here, the behavior is what matters: snapshot, then live.

## The end-of-initial-data signal

There's a boundary between the snapshot and the live stream, and the watch marks it for you. After the last snapshot entry and before the first live change, the watch delivers one **end-of-initial-data signal**: a single nil entry. It carries no key and no value. It indicates only that the snapshot is complete and everything after it is a live change.

The CLI consumes that signal silently and keeps printing, so you never see it on the command line. In client code you handle the boundary explicitly, but how it reaches you depends on the client. Go and Python deliver a nil/None entry in the same stream as your real entries: read it, recognize it as the boundary, and keep reading. JavaScript sets an `isUpdate` flag on each entry, Java calls an `endOfData()` callback, C# takes an `OnNoData` option, and Rust has no marker at all — you pick snapshot-plus-live or live-only when you open the watch. The idea is the same everywhere, a boundary between the snapshot and the live changes; only the signal differs. The example below shows the nil-entry form:

#### CLI

```
#!/bin/bash



# The end-of-initial-data signal in practice.

#

# A client watch delivers the snapshot, then ONE nil entry to mark the

# snapshot/live boundary, then live updates. A program that reads the

# watch must consume that nil entry and keep going, not treat it as the

# end of the stream. The CLI consumes it for you and keeps printing;

# the comment below shows what a client loop must do.

#

# Run the watch and confirm it does not stop after the snapshot:

nats kv watch INVENTORY



# The CLI prints the snapshot, silently steps over the nil end-of-initial

# -data entry, and keeps waiting for live changes. In client code the

# equivalent loop is:

#

#   for entry in watcher:

#       if entry is None:        # end-of-initial-data marker

#           continue             # snapshot done; keep reading live updates

#       handle(entry.key, entry.value, entry.revision)

#

# Stopping the loop on the nil entry would miss every live change. Keep

# reading.
```

#### C

```
// Watch the whole bucket: the snapshot comes first, then live

// changes.

s = kvStore_Watch(&w, kv, ">", NULL);

while (s == NATS_OK)

{

    kvEntry *e = NULL;



    s = kvWatcher_Next(&e, w, 5000);

    if (s != NATS_OK)

        break;



    // A NULL entry is the end-of-initial-data signal: the snapshot

    // is complete and everything after it is a live change. Consume

    // it and keep reading — breaking here would miss every live

    // update, which is the reason to watch.

    if (e == NULL)

    {

        printf("snapshot complete, now live\n");

        continue;

    }



    printf("%s @ rev %" PRIu64 ": %s\n",

           kvEntry_Key(e), kvEntry_Revision(e), kvEntry_ValueString(e));

    kvEntry_Destroy(e);

}
```

The signal is useful beyond bookkeeping. A dashboard can hold its "loading" state until the nil entry arrives, then flip to "live" knowing it has the complete current picture. A cache-warming job can populate from the snapshot, treat the nil entry as "warm," and switch to incremental updates. The boundary carries information you can act on.

It's also the most common watch bug, and the Pitfalls section below includes a runnable version.

## Watching a subset

Watching the whole bucket gives you every key. Often you want fewer. A watch takes an optional key filter, matched against the key the same way NATS matches a subject: a key is a sequence of dot-separated tokens, `*` stands for exactly one whole token, and `>` for one or more tokens at the end. (Keys map to subject tokens; that's the [subjects](/concepts/subjects.md) model the backing stream is built on.)

The SKU keys here are single tokens: `widget-blue` is one token, and the hyphen is an ordinary character, not a separator. So a filter like `widget-*` is not a wildcard at all — `*` is only special as a whole token — and it matches nothing. To split keys with a wildcard you'd design them with dots, such as `widget.blue` and `widget.red`, so that `widget.*` matches both.

With flat SKU names, watch a subset by naming an exact key. The dashboard for the blue widget watches just `widget-blue`:

#### CLI

```
#!/bin/bash



# Watch a subset of the bucket, not every key.

#

# A watch filter is matched against the key the same way a subject is:

# '*' stands for exactly one whole token and '>' for the rest. The SKU

# keys here are single tokens (widget-blue is one token; the hyphen is an

# ordinary character), so a prefix like 'widget-*' is NOT a wildcard and

# matches nothing. To watch a subset of flat keys, name an exact key:

nats kv watch INVENTORY widget-blue



# Expected: the snapshot shows only widget-blue at its current value, then

# it waits. A later put to gadget-pro or widget-red never reaches this

# watcher; a put to widget-blue does:

#

#   [2026-05-22 10:16:40] PUT INVENTORY > widget-blue: 41
```

#### C

```
// Watch a subset of the bucket. The filter is matched like a

// subject: '*' stands for a whole dot-separated token, so

// "widget-*" is not a wildcard and matches nothing. With flat

// SKU keys, name an exact key instead.

kvEntry *e = NULL;



s = kvStore_Watch(&w, kv, "widget-blue", NULL);

while (s == NATS_OK)

{

    s = kvWatcher_Next(&e, w, 60000);

    if (s != NATS_OK)

        break;

    // NULL marks the end of the snapshot; keep reading.

    if (e == NULL)

        continue;

    // Only widget-blue arrives here: the filter applies to both

    // the snapshot and the live changes.

    printf("%s: %.*s\n", kvEntry_Key(e),

           kvEntry_ValueLen(e), (const char*) kvEntry_Value(e));

    kvEntry_Destroy(e);

    e = NULL;

}
```

The snapshot now lists only `widget-blue`, and the live stream only carries changes to it. A put to `gadget-pro` or `widget-red` never reaches this watcher; a put to `widget-blue` does. The filter applies to both halves, snapshot and live, so a filtered watch is a smaller, cheaper view of the bucket rather than every change for you to filter afterward.

A watch supports a few more options, each tuning the same two halves you just saw: `IncludeHistory` replays the full history of every key instead of just the current snapshot, `IgnoreDeletes` skips deleted keys, `UpdatesOnly` drops the snapshot so you see only live changes, and `MetaOnly` sends each entry's metadata without its value. You can combine them, with one exception: `IncludeHistory` and `UpdatesOnly` conflict — one asks for the full snapshot with history, the other for no snapshot at all — and a client rejects the pair. These are client-side watch options, implemented as settings on the ephemeral consumer the watch opens; the [Reference → Create Consumer](/reference/jetstream/api/consumer/create.md) page documents that consumer configuration.

## Pitfalls

Two mistakes are common the first time you watch a bucket. Both come from the two concepts above: the snapshot/live boundary, and what a watch actually is.

**Don't stop reading at the boundary signal.** In the clients that deliver it as a nil/None entry (Go and Python), that entry rides the same stream as your real ones. A loop that treats nil as "the stream ended" and breaks will read the snapshot and see the boundary marker, then quit before every live change that was the reason to watch. The fix is one line: when an entry is nil, skip it and keep looping. Do not break. In the clients that signal the boundary with a flag or a callback instead, the same mistake is treating the end of the snapshot as the end of the watch.

The handling example above doubles as the demo: the loop continues past the nil entry instead of stopping on it.

#### CLI

```
#!/bin/bash



# The end-of-initial-data signal in practice.

#

# A client watch delivers the snapshot, then ONE nil entry to mark the

# snapshot/live boundary, then live updates. A program that reads the

# watch must consume that nil entry and keep going, not treat it as the

# end of the stream. The CLI consumes it for you and keeps printing;

# the comment below shows what a client loop must do.

#

# Run the watch and confirm it does not stop after the snapshot:

nats kv watch INVENTORY



# The CLI prints the snapshot, silently steps over the nil end-of-initial

# -data entry, and keeps waiting for live changes. In client code the

# equivalent loop is:

#

#   for entry in watcher:

#       if entry is None:        # end-of-initial-data marker

#           continue             # snapshot done; keep reading live updates

#       handle(entry.key, entry.value, entry.revision)

#

# Stopping the loop on the nil entry would miss every live change. Keep

# reading.
```

#### C

```
// Watch the whole bucket: the snapshot comes first, then live

// changes.

s = kvStore_Watch(&w, kv, ">", NULL);

while (s == NATS_OK)

{

    kvEntry *e = NULL;



    s = kvWatcher_Next(&e, w, 5000);

    if (s != NATS_OK)

        break;



    // A NULL entry is the end-of-initial-data signal: the snapshot

    // is complete and everything after it is a live change. Consume

    // it and keep reading — breaking here would miss every live

    // update, which is the reason to watch.

    if (e == NULL)

    {

        printf("snapshot complete, now live\n");

        continue;

    }



    printf("%s @ rev %" PRIu64 ": %s\n",

           kvEntry_Key(e), kvEntry_Revision(e), kvEntry_ValueString(e));

    kvEntry_Destroy(e);

}
```

**A watch is live state, not a point read.** A watch is an ephemeral ordered consumer: it exists only while your process holds it open, and it goes away when the process ends. It's the right tool when you want to *keep up* with a bucket, and the wrong tool when you want a single current value once. For that, reach for get, which you saw on the last page, or history, which the next page covers. Don't open a watch, read the first entry, and close it to fake a point read; you pay for a consumer and a snapshot to get one value get would have handed you directly.

## Where you are

You now have:

* The `INVENTORY` bucket with `widget-blue` at `41` (a put landed during the watch demo), plus `widget-red` and `gadget-pro` now stocked.
* A working warehouse dashboard: a watch that delivered the snapshot, then a live update.
* The end-of-initial-data signal in hand: you know it marks the snapshot/live boundary and must be consumed, not treated as the end.
* A filtered watch that views a single key (`widget-blue`), and the rule that a key filter's `*` matches a whole token, not a prefix.

## What's next

The next page reads the history each put creates and uses revisions to make safe, concurrent updates: [History and revisions](/learn/key-value/history-and-revisions.md).

## See also

* [Why a stream](/learn/jetstream/your-first-stream.md#why-a-stream) — the consumer model a watch is built on.
* [Reference → Create Consumer](/reference/jetstream/api/consumer/create.md) — the consumer configuration a watch's options map onto.
