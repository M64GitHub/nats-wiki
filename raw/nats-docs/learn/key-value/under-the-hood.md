<!-- source: https://docs.nats.io/learn/key-value/under-the-hood.md · fetched 2026-08-31 · section: under-the-hood -->
# Under the hood

You've built a whole `INVENTORY` bucket: keys with values, a watcher, safe decrements with compare-and-swap, and a TTL'd key that expires on its own. Every one of those used the key-value API and never mentioned a stream. This page shows the underlying mechanism. The bucket was a JetStream stream the whole time, and seeing it lets you understand how KV works internally.

This page first proves the bucket is a stream and traces one key down to the message that holds it. It then covers the one operation where the abstraction behaves differently depending on what you ask for: delete versus purge.

## A bucket is a stream

The index page stated it; here you can check it. A bucket is a JetStream stream named `KV_<bucket>` whose subjects are `$KV.<bucket>.>`. A key is the last token of that subject, and a value is a message on it. For `INVENTORY` the backing stream is `KV_INVENTORY`, its subjects are `$KV.INVENTORY.>`, and the key `widget-blue` is the message on `$KV.INVENTORY.widget-blue`.

The KV commands don't show the stream name, but the stream commands report it directly. Ask the server for the stream behind the bucket:

#### CLI

```
#!/bin/bash



# Inspect the bucket as the stream it really is.

#

# The INVENTORY bucket is a JetStream stream named KV_INVENTORY. The KV

# commands hide that name, but the stream commands see straight through to

# it. Ask the server for the stream that backs the bucket:

nats stream info KV_INVENTORY



# The configuration half proves every framing claim from this chapter:

#

#   Subjects: $KV.INVENTORY.>          # one subject per key

#   Discard Policy: New                # at a limit, rejects the newest write

#   Direct Get: true                   # get reads without a consumer

#   Allows Rollups: true               # purge replaces a key with one marker

#   Allows Msg Delete: false           # deny_delete: no raw stream deletes

#   Maximum Per Subject: 10            # this is the history depth (raised on

#                                      # the history page)

#

# The key widget-blue is the last token of its subject. Confirm it by

# asking the stream for the last message on that exact subject:

nats stream subjects KV_INVENTORY



# Expected output lists $KV.INVENTORY.widget-blue (and one subject per

# other key). The value 42 you put on page 1 is the body of the last

# message on $KV.INVENTORY.widget-blue.
```

#### C

```
// The INVENTORY bucket is a JetStream stream named KV_INVENTORY. The

// KV calls hide that name, but the stream API sees straight through

// to it. Ask for the stream, including its per-subject counts.

jsStreamInfo    *si  = NULL;

jsErrCode       jerr = 0;

jsOptions       o;



jsOptions_Init(&o);

o.Stream.Info.SubjectsFilter = "$KV.INVENTORY.>";



s = js_GetStreamInfo(&si, js, "KV_INVENTORY", &o, &jerr);

if (s == NATS_OK)

{

    // The config is the bucket's settings written in stream terms.

    printf("Subjects: %s\n", si->Config->Subjects[0]);

    printf("Maximum Per Subject: %" PRIi64 "\n",       // history depth

           si->Config->MaxMsgsPerSubject);

    printf("Discard Policy: %s\n",                     // limits reject

           (si->Config->Discard == js_DiscardNew) ? "New" : "Old");

    printf("Direct Get: %s\n",                         // get without a consumer

           si->Config->AllowDirect ? "true" : "false");

    printf("Allows Rollups: %s\n",                     // purge = one marker

           si->Config->AllowRollup ? "true" : "false");

    printf("Allows Msg Delete: %s\n",                  // deny_delete on

           si->Config->DenyDelete ? "false" : "true");



    // One subject per key: widget-blue is the message on

    // $KV.INVENTORY.widget-blue.

    if (si->State.Subjects != NULL)

    {

        int i;



        for (i = 0; i < si->State.Subjects->Count; i++)

            printf("  %s: %" PRIu64 " messages\n",

                   si->State.Subjects->List[i].Subject,

                   si->State.Subjects->List[i].Msgs);

    }

    jsStreamInfo_Destroy(si);

}
```

The configuration the server prints back is every KV claim from this chapter, written in stream terms:

* **Subjects: `$KV.INVENTORY.>`**. There is one subject branch, with one key per token under it.
* **Maximum Per Subject: `10`**. This *is* the history depth. You raised it to 10 on the history page to keep prior revisions; the bucket's history is the stream keeping more than one message per subject.
* **Discard Policy: `New`**. Once the bucket hits a limit, it rejects the newest write rather than silently dropping older messages to make room. This is why limits reject: the bucket keeps the messages it already holds rather than evicting them.
* **Direct Get: `true`**. Get doesn't open a consumer. More on that next.
* **Allows Rollups: `true`**. Purge replaces a key's whole subject with one message. More on that below.
* **Allows Msg Delete: `false`**. This maps to the stream's `deny_delete` setting: the stream refuses the JetStream message-delete API, so raw stream ops can't remove entries behind the KV API's back.

This is the same stream-storage model the JetStream chapter drew. The animation below is the one from that chapter, reused on purpose: the layer under your bucket is exactly the stream described there.

**Message flow — Core NATS vs JetStream (animated):** Core NATS versus JetStream for a subscriber that goes offline. In Core mode, messages published while the client is offline reach the server and go nowhere; when the client returns, only new messages arrive. In JetStream mode the stream stores what the client missed — the pending count climbs while it is offline and drains back as the stream replays every missed message once the client reconnects.

* Publisher → NATS

The full set of stream configuration the server reports here is documented in [Reference → Create Stream](/reference/jetstream/api/stream/create.md). You didn't set any of these by hand; the client mapped your bucket settings onto them.

## Get reads the last message, with no consumer

Reading a value doesn't replay the stream and doesn't open a consumer. It uses **direct get**: the server returns the last message on a subject straight from storage. The request goes to `$JS.API.DIRECT.GET.<stream>.<subject>` (for our key, `$JS.API.DIRECT.GET.KV_INVENTORY.$KV.INVENTORY.widget-blue`), and the server answers with the latest message there. That last message is the current value, its sequence is the revision, and its store time is the entry timestamp.

This is why `nats kv get INVENTORY widget-blue` is fast and stateless. There's no position to track, no message to acknowledge, and no consumer to clean up, so a get is one request and one reply. It's the reason a bucket behaves as a key-value store even though it's built from an append-only log: the bucket interface hides the stream, so you see key-value pairs rather than messages. Each get returns the last message per subject, served directly.

`Direct Get: true` in the stream config is what enables this path. It's set for you when the bucket is created. The exhaustive direct-read API lives in [Reference → Get Stream Message](/reference/jetstream/api/stream/msg-get.md); here you only need its shape, which is the last message for a subject, with no consumer.

## Delete versus purge

Removing a key is the one operation where the abstraction behaves differently depending on what you ask for, because "gone" can mean two different things underneath.

A **delete** leaves a non-destructive **marker**: a message with a `KV-Operation: DEL` header. The key now reads empty, but every prior revision the bucket still keeps — up to its history depth — stays in the stream and readable through history. Delete is the common case when you want a key to read as absent but don't need its past erased. (The marker is what other systems call a tombstone; after this paragraph we'll call it a marker.)

A **purge** is destructive. It writes a marker with a `KV-Operation: PURGE` header *and* a `Nats-Rollup: sub` header. The rollup tells the stream to drop every earlier message on that subject and keep only this one marker. History collapses to a single entry; the prior values are gone from disk. Reach for purge when you must actually remove the old values (for size, or because they were sensitive), not just hide them.

#### CLI

```
#!/bin/bash



# Delete and purge both make a key read empty, but they keep different

# amounts of history. The difference matters when the prior values are

# sensitive or when the bucket is filling up.



# Delete leaves a non-destructive marker. The key reads empty, but every

# prior revision is still in the backing stream and still readable through

# history.

nats kv del INVENTORY widget-blue



# A get now reports the key is deleted, yet history still shows the

# revisions that came before:

nats kv history INVENTORY widget-blue

#

# Expected output: the kept PUT revisions PLUS a final DELETE marker

# (columns abbreviated here):

#

#   Key          Revision  Op      Value

#   widget-blue  2         PUT     41

#   widget-blue  5         PUT     40

#   widget-blue  9         DELETE

#

# The values are still on disk, up to the bucket's history depth (raised to

# 10 on the history-and-revisions page). Delete is reversible knowledge: a

# deleted key can be put again, and its past is intact.



# Purge is destructive. It drops every prior revision for the key and

# leaves a single rollup marker behind, so history collapses to one entry.

nats kv purge INVENTORY widget-red



nats kv history INVENTORY widget-red

#

# Expected output: a single PURGE marker, the prior value gone

# (columns abbreviated here):

#

#   Key         Revision  Op     Value

#   widget-red  10        PURGE

#

# Reach for purge when you must actually remove the old values (size or

# privacy); reach for delete when "this key is gone for now" is enough.
```

#### C

```
// Delete and purge both make a key read empty, but they keep

// different amounts of history.

kvEntryList list;

const char  *ops[] = { "UNKNOWN", "PUT", "DELETE", "PURGE" };

int         i;



// Delete leaves a non-destructive marker. The key reads empty, but

// every prior revision the bucket keeps stays readable through

// history: the kept PUTs plus a final DELETE marker.

s = kvStore_Delete(kv, "widget-blue");

if (s == NATS_OK)

    s = kvStore_History(&list, kv, "widget-blue", NULL);

if (s == NATS_OK)

{

    printf("widget-blue after delete:\n");

    for (i = 0; i < list.Count; i++)

    {

        kvEntry *e = list.Entries[i];



        printf("  rev %" PRIu64 " %s %s\n",

               kvEntry_Revision(e), ops[kvEntry_Operation(e)],

               (kvEntry_Value(e) != NULL) ? kvEntry_ValueString(e) : "");

    }

    kvEntryList_Destroy(&list);

}



// Purge is destructive. It drops every earlier message on the key's

// subject and keeps only a rollup marker, so history collapses to a

// single PURGE entry; the prior values are gone from disk.

if (s == NATS_OK)

    s = kvStore_Purge(kv, "widget-red", NULL);

if (s == NATS_OK)

    s = kvStore_History(&list, kv, "widget-red", NULL);

if (s == NATS_OK)

{

    printf("widget-red after purge:\n");

    for (i = 0; i < list.Count; i++)

    {

        kvEntry *e = list.Entries[i];



        printf("  rev %" PRIu64 " %s %s\n",

               kvEntry_Revision(e), ops[kvEntry_Operation(e)],

               (kvEntry_Value(e) != NULL) ? kvEntry_ValueString(e) : "");

    }

    kvEntryList_Destroy(&list);

}
```

Both make a `get` report the key as gone. The difference is entirely in what history can still show you afterward: delete keeps the prior revisions, while purge erases them.

A bucket's `Replicas` field (how many servers hold a copy) is named here for completeness, because it shows up in the stream config too. Replication, leader election, and placement belong to [Clustering](/learn/clustering/.md) and aren't taught in this chapter.

## Pitfalls

Once you can see the stream, a few mistakes become tempting. Most come from treating the backing stream as something you operate directly.

**Delete does not remove history; only purge does.** It's easy to read "I deleted the key" as "the old values are gone." They are not. A deleted key still has every prior revision available through history, because delete only appends a marker. If you delete `widget-blue` to scrub a wrong count and assume the bad value is unrecoverable, it's sitting one `nats kv history` away. To actually drop prior values, purge.

The example above is the proof: delete `widget-blue`, then read its history and see the old revisions still there; purge `widget-red`, then read its history and see it collapsed to a single marker. Choose the operation by what you need to keep, the prior revisions or the disk space they occupy.

**Do not operate the backing stream directly.** The bucket is a managed stream. Don't hand-edit `KV_INVENTORY`'s configuration, and don't publish to `$KV.INVENTORY.>` with raw `nats pub`. The KV API sets the headers that make the store correct: the expected-revision header for compare-and-swap, the `KV-Operation` and `Nats-Rollup` headers for delete and purge. A raw publish writes a bare message with none of them, so a watcher can't tell it from a real put and a purge you meant never happens. The stream is built with `deny_delete` on so raw stream operations can't remove entries behind the KV API's back, but that setting doesn't stop a raw publish — which is exactly why you avoid one. Use `nats kv put`, not `nats pub`; use `nats kv del` and `nats kv purge`, not stream message deletion.

**A key has to be a legal subject token.** Now that you can see a key becomes the last token of `$KV.INVENTORY.<key>`, the name rules make sense: a key may contain only letters, digits, and `-`, `/`, `_`, `=`, and `.`, with no leading or trailing dot and no two dots in a row, because anything else would be an illegal subject. An order id like `ord:8w2k` carries a colon, so it can't be a key, and the bucket rejects the write instead of storing a broken key. This is the same validation introduced on [Your first bucket](/learn/key-value/your-first-bucket.md#pitfalls); the backing stream is why it exists.

## Where you are

You now have:

* The same `INVENTORY` bucket you built across the first four pages, from [Your first bucket](/learn/key-value/your-first-bucket.md) through [TTL and limits](/learn/key-value/ttl-and-limits.md), plus the ability to inspect it as the `KV_INVENTORY` stream it's always been.
* A map from every KV operation to its stream mechanism: put is a message, get is a direct read of the last message per subject, history is messages kept per subject, a revision is a sequence number, a watch is a consumer.
* A clear distinction between delete (marker, history kept) and purge (rollup marker, history dropped), and the rule never to operate the backing stream directly.

The abstraction is no longer opaque. It's a stream presented through the KV API, and you can now see both the KV interface and the stream beneath it.

## What's next

The last page steps back: it recaps the whole chapter, points you at where the exhaustive details live, and collects every page's pitfalls into one pre-production checklist.

Continue to [Where to go next](/learn/key-value/where-next.md).

## See also

* [Reference → Get Stream Message](/reference/jetstream/api/stream/msg-get.md) — the direct-get read path in full.
* [JetStream Deep Dive](/learn/jetstream/.md) — the stream and consumer model this bucket is built on.
* [Clustering](/learn/clustering/.md) — replicas, placement, and leader election for the backing stream.
