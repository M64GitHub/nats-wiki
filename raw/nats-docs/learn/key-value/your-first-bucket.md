<!-- source: https://docs.nats.io/learn/key-value/your-first-bucket.md · fetched 2026-08-31 · section: your-first-bucket -->
# Your first bucket

Time to make the `INVENTORY` bucket real. The inventory service keeps a stock count for each SKU, and a bucket is where those counts live. This page creates the bucket with one command, puts a count, gets it back, and reads the bucket's status, and does nothing more than that.

The previous chapter gave you JetStream. A bucket rides on top of it: a **bucket** is a JetStream stream the key-value API creates and configures for you, so you never write the stream by hand. You ask for a bucket, and the server stores one stream named `KV_INVENTORY` behind the friendly name `INVENTORY`. The stream is the topic of the [under the hood](/learn/key-value/under-the-hood.md) page; here you only need to know it exists.

## Create the bucket

A running `nats-server` with JetStream enabled is the one prerequisite. The key-value API is part of JetStream, so without `-js` the next command has nothing to talk to:

```
nats-server -js
```

In another terminal, create the bucket:

#### CLI

```
#!/bin/bash

# Create the INVENTORY bucket. A bucket is created as a JetStream stream,

# so this one command sets up the backing stream KV_INVENTORY on the

# subjects $KV.INVENTORY.>.

#

# --history 1 keeps only the current value of each key. We raise this

# later on the history-and-revisions page; 1 is the default and is all

# the inventory service needs to start.



nats kv add INVENTORY --history 1



# Expected output is the bucket's status, ending with its configuration

# (labels abbreviated here):

#

#   Information for Key-Value Store Bucket INVENTORY created <time>

#

#   Configuration:

#

#              Bucket Name: INVENTORY

#              History Kept: 1

#          JetStream Stream: KV_INVENTORY

#     ...
```

#### C

```
// Create the INVENTORY bucket. The server stores it as the

// JetStream stream KV_INVENTORY behind the friendly name.

kvConfig cfg;



kvConfig_Init(&cfg);

cfg.Bucket  = "INVENTORY";

// Keep only the current value of each key. This is the default;

// the history-and-revisions page raises it.

cfg.History = 1;



s = js_CreateKeyValue(&kv, js, &cfg);

if (s == NATS_OK)

    printf("Created bucket %s\n", kvStore_Bucket(kv));
```

Two parts of this command matter. The first is the **bucket name**: `INVENTORY`. Bucket names are case-sensitive identifiers, and they show up in every command and every error message in this chapter. The name maps straight onto the backing stream: `INVENTORY` becomes `KV_INVENTORY`.

The second is `--history 1`. **History** is how many prior values the bucket keeps for each key. One means the bucket holds only the current value of a key and forgets the rest. That's the default and all the inventory service needs to start. The depth can go as high as 64, but no higher; [History and revisions](/learn/key-value/history-and-revisions.md) raises it so a key remembers where it's been, and for now, one is enough.

You didn't set any other configuration. A bucket has the same long list of stream knobs underneath, all filled with sensible defaults. The full set of bucket configuration options lives in [Reference → Create Stream](/reference/jetstream/api/stream/create.md), since a bucket is created as a stream. We use only `History` here.

## Put a value, get an entry

The bucket is empty. Put the first stock count into it. The **key** is the SKU, and the **value** is the count stored as bytes:

#### CLI

```
#!/bin/bash

# Put the stock count for widget-blue into the bucket. The key is the SKU,

# the value is the count as bytes. A put is unconditional: it writes the

# value whether or not the key already exists.

#

# This is the inventory service recording that there are 42 widget-blue

# units in stock.



nats kv put INVENTORY widget-blue 42



# The put API returns the new revision to client code; the CLI just echoes

# the value it stored. Because INVENTORY is empty, this first write lands at

# revision 1, which you can confirm with `nats kv get`. The output here is

# only the value:

#

#   42
```

#### C

```
// Put the stock count for widget-blue. The key is the SKU, the

// value is the count as bytes. A put is unconditional: it writes

// whether or not the key already exists.

uint64_t rev = 0;



s = kvStore_PutString(&rev, kv, "widget-blue", "42");

if (s == NATS_OK)

{

    // The bucket assigns each write a revision from a single

    // counter. INVENTORY is empty, so this first write lands at 1.

    printf("Stored widget-blue at revision %llu\n",

           (unsigned long long) rev);

}
```

That's a **put**: an unconditional write. It stores the value whether or not the key already exists. Each write also gets a **revision**: a number the bucket assigns from a single counter it keeps across every key, not a per-key count. Because `INVENTORY` is empty, this first write lands at revision 1; in a bucket that already holds other keys, the same put would take the next number in the bucket's sequence instead. The put API returns that revision to client code; the CLI prints only the value you stored. Revisions are how the bucket tracks change over time, and [History and revisions](/learn/key-value/history-and-revisions.md) builds on them.

Now read it back:

#### CLI

```
#!/bin/bash

# Get widget-blue back. By default a get returns the whole entry: the

# value plus its revision and timestamp. --raw asks for only the value

# bytes, which is what a program usually wants.



nats kv get INVENTORY widget-blue --raw



# Prints just the value:

#

#   42



# Without --raw you see the full entry the server returns:

nats kv get INVENTORY widget-blue



#   INVENTORY > widget-blue created @ ...

#

#   42

#

# A get for a key that was never put fails with a key-not-found error,

# which is distinct from a key whose value is empty. Check for that error

# before using the value:

nats kv get INVENTORY widget-green --raw || echo "widget-green not in stock yet"
```

#### C

```
// A get returns an entry, not a bare value: the value together

// with its revision and the time it was written.

kvEntry *e = NULL;



s = kvStore_Get(&e, kv, "widget-blue");

if (s == NATS_OK)

{

    printf("value:    %.*s\n",

           kvEntry_ValueLen(e), (const char*) kvEntry_Value(e));

    printf("revision: %llu\n",

           (unsigned long long) kvEntry_Revision(e));

    printf("created:  %lld (unix seconds)\n",

           (long long) (kvEntry_Created(e) / 1000000000LL));

    kvEntry_Destroy(e);

    e = NULL;

}



// A key that was never put fails with NATS_NOT_FOUND, which is

// distinct from a key whose value is empty. Check for absence

// instead of treating a missing SKU as "the count is zero".

s = kvStore_Get(&e, kv, "widget-green");

if (s == NATS_NOT_FOUND)

{

    printf("widget-green not in stock yet\n");

    s = NATS_OK;

}
```

A **get** returns an **entry** rather than a bare value: the value together with its revision and the time it was written. The CLI's `--raw` flag strips the entry down to just the value bytes (`42`), which is usually what a program wants, but the full object is what the server actually sends.

That shape is intentional, because the inventory service rarely wants only the count; it wants the count *and* the revision, because [history and revisions](/learn/key-value/history-and-revisions.md) uses that revision to decrement the value safely. The entry carries both in one read, so you never have to make a second call to learn which revision you just saw.

The timestamp on the entry matters too. It records when the value was written, not when you read it, so the inventory service can tell a count taken seconds ago from one that has sat untouched for a week. You get all three facts — value, revision, and write time — from the single get you already made.

## Read the bucket's status

One command summarizes the bucket as a whole:

#### CLI

```
#!/bin/bash

# Ask the server about the bucket as a whole. Status reports the bucket's

# configuration and how many values it currently holds.



nats kv status INVENTORY



# Expected output reports the bucket name, history depth, value count, and

# the backing stream (labels abbreviated here):

#

#   Information for Key-Value Store Bucket INVENTORY created <time>

#

#   Configuration:

#

#              Bucket Name: INVENTORY

#              History Kept: 1

#             Values Stored: 1

#        Backing Store Kind: JetStream

#          JetStream Stream: KV_INVENTORY

#

# The "JetStream Stream" line names the stream under the bucket:

# KV_INVENTORY. That is the proof the bucket is a stream; the

# under-the-hood page opens it up.
```

#### C

```
// Ask the server about the bucket as a whole: the history depth

// you set and how many values it currently holds.

kvStatus *sts = NULL;



s = kvStore_Status(&sts, kv);

if (s == NATS_OK)

{

    printf("Bucket:         %s\n", kvStatus_Bucket(sts));

    printf("History kept:   %lld\n",

           (long long) kvStatus_History(sts));

    printf("Values stored:  %llu\n",

           (unsigned long long) kvStatus_Values(sts));

    // A bucket is a stream with a friendlier name: the backing

    // stream is KV_<bucket>, here KV_INVENTORY.

    printf("Backing stream: KV_%s\n", kvStatus_Bucket(sts));

    kvStatus_Destroy(sts);

}
```

The status reports the bucket name, the history depth you set, and how many values it holds. It also reports the **backing stream**: the stream the bucket is built on, named `KV_INVENTORY`. That line is your first concrete proof that a bucket is a stream with a friendlier name. The [under the hood](/learn/key-value/under-the-hood.md) page opens that stream and reads it directly.

## Pitfalls

Two mistakes are common on your very first bucket, and each is easy to avoid once you've seen it.

**A get returns an entry rather than a value, and a missing key is signaled distinctly from an empty one.** Reaching straight for the value bytes works only when the key exists. A key that was never put doesn't return an empty entry: the CLI and some clients (Go, Python, C#) fail with a key-not-found error, while others (JavaScript, Rust, Java) return null or None. Either way, absence is reported as its own thing, separate from a value that happens to be empty: an empty value is a value, and a missing key is the absence of one. Don't treat a missing key as "the count is zero." The get example above ends with exactly this case: its last line gets a SKU that was never stocked, the get signals absence, and the program decides what a missing SKU means instead of reading a stale or zero count by accident. Check for absence first, then read the value.

**Bucket and key names are validated.** A bucket name may contain only letters, digits, dash, and underscore, and it can't be empty. A key is more permissive (letters, digits, and the characters `-`, `/`, `_`, `=`, and `.`), but nothing beyond that set, no leading or trailing dot, and no two dots in a row (`a..b` is rejected even though `a.b` is fine). An order id like `ord:8w2k` has a colon, so it can't be a key; the client library validates the name and rejects the write before it's sent, rather than storing a broken key. Pick names from the allowed set, and reach for an underscore or dash where you'd have used a colon:

#### CLI

```
#!/bin/bash

# Key and bucket names are validated. A bucket name may use only letters,

# digits, dash, and underscore. A key may use letters, digits, and the

# characters - / _ = . — and nothing else.

#

# An order id like "ord:8w2k" has a colon, which is not allowed as a key.

# The client library validates the name and rejects the put before it is

# sent, so nothing is written to the bucket:



nats kv put INVENTORY "ord:8w2k" 42 || echo "rejected: ':' is not a legal key character"



# A legal key with the same intent uses an allowed separator, e.g.

#

#   nats kv put INVENTORY ord_8w2k 42

#

# We don't run that against INVENTORY here: it's the running example for the

# whole chapter and should still hold only widget-blue at this point.
```

#### C

```
// "ord:8w2k" has a colon, which is not a legal key character.

// The client validates the key and rejects the put before

// anything is sent, so nothing is written to the bucket.

uint64_t rev = 0;



s = kvStore_PutString(&rev, kv, "ord:8w2k", "42");

if (s == NATS_INVALID_ARG)

{

    printf("rejected: ':' is not a legal key character\n");

    // A legal key with the same intent uses an allowed

    // separator, e.g. "ord_8w2k".

    s = NATS_OK;

}
```

## Where you are

You now have:

* An `INVENTORY` bucket, backed by the stream `KV_INVENTORY`.
* The key `widget-blue` holding the value `42` at revision 1.
* The ability to put a value, get back its entry, and read the bucket's status.

## What's next

The next page puts the **warehouse dashboard** on the bucket: a watch that streams every stock change live, starting with a snapshot of what's already there.

Continue to [Watching](/learn/key-value/watching.md).

## See also

* [Reference → Create Stream](/reference/jetstream/api/stream/create.md) — every configuration option a bucket inherits from its backing stream.
* [Core Concepts → JetStream](/concepts/jetstream.md) — the storage layer a bucket is built on.
* [Watching](/learn/key-value/watching.md) — stream live changes off the bucket.
