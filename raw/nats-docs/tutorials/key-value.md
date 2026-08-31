<!-- source: https://docs.nats.io/tutorials/key-value.md · fetched 2026-08-31 · section: key-value -->
# 6. Store state in Key-Value

You'll create a Key-Value bucket, put a value into it, read it back, and then watch the bucket from a second terminal so you see changes the moment they happen. By the end you'll have a tiny live state store you can read, write, and observe.

## What you'll need

* `nats-server` and the `nats` CLI installed (see [1. Hello NATS](/tutorials/hello-nats.md)).
* A Key-Value bucket is backed by a JetStream stream, so you'll start the server with JetStream enabled in Step 1.

## Step 1: Start the server with JetStream

A Key-Value bucket is stored in JetStream, so start the server with the `-js` flag.

```
nats-server -js
```

You should see a startup log line confirming JetStream is on:

```
[INF] Starting JetStream

[INF] Server is ready
```

Leave this running and open a new terminal for the next steps.

## Step 2: Create a bucket

Create a bucket called `profiles`. This is where your values will live.

#### CLI

```
#!/bin/bash

# Create a Key-Value bucket called profiles. A bucket is where your

# values live.



nats kv add profiles



# You should see a confirmation with the bucket name and config:

#

#   Information for Key-Value Store Bucket profiles created 2026-06-09 10:13:41

#

#   Configuration:

#

#              Bucket Name: profiles

#             History Kept: 1

#                      ...

#       Backing Store Kind: JetStream
```

#### C

```
// Create a Key-Value bucket called profiles. A bucket is where your

// values live.

kvConfig cfg;



kvConfig_Init(&cfg);

cfg.Bucket = "profiles";



s = js_CreateKeyValue(&kv, js, &cfg);

if (s == NATS_OK)

    printf("Created bucket %s\n", kvStore_Bucket(kv));
```

You should see a confirmation with the bucket's configuration:

```
Information for Key-Value Store Bucket profiles created 2026-06-09 10:13:41



Configuration:



           Bucket Name: profiles

          History Kept: 1

                   ...

    Backing Store Kind: JetStream
```

## Step 3: Put a value and read it back

Store a value under a key, then get it back. The key is `sue.color` and the value is `blue`.

#### CLI

```
#!/bin/bash

# Put a value: the key is sue.color, the value is blue.



nats kv put profiles sue.color blue



# You should see the value echoed back with its revision:

#

#   blue



# Get the value back out by its key.



nats kv get profiles sue.color



# You should see the full entry, including the value:

#

#   profiles > sue.color revision: 1 created @ ...

#

#   blue
```

#### C

```
// Put a value: the key is sue.color, the value is blue. The bucket

// assigns the write a revision; the first write lands at 1.

uint64_t rev   = 0;

kvEntry  *e    = NULL;



s = kvStore_PutString(&rev, kv, "sue.color", "blue");

if (s == NATS_OK)

    printf("stored sue.color at revision %llu\n",

           (unsigned long long) rev);



// Get the value back out by its key. A get returns the full entry:

// the value together with its revision.

if (s == NATS_OK)

    s = kvStore_Get(&e, kv, "sue.color");

if (s == NATS_OK)

{

    printf("sue.color revision: %llu value: %.*s\n",

           (unsigned long long) kvEntry_Revision(e),

           kvEntry_ValueLen(e), (const char*) kvEntry_Value(e));

    kvEntry_Destroy(e);

}
```

The put echoes the value back, and the get returns the full entry:

```
blue

profiles > sue.color revision: 1 created @ ...



blue
```

You now have one value stored and confirmed.

## Step 4: Watch the bucket from a second terminal

A watch streams every change to the bucket as it happens. Open a **second terminal** and start watching `profiles`.

#### CLI

```
#!/bin/bash

# Watch the whole profiles bucket. On start it replays the current value

# of every key, then blocks and prints each change live until you stop it

# with Ctrl-C. Run this in its own terminal.



nats kv watch profiles



# You should see the current value first, then it waits:

#

#   [2026-06-09 10:14:22] PUT profiles > sue.color: blue
```

#### C

```
// Watch the whole profiles bucket. The watch first replays the

// current value of every key, then delivers each change live the

// moment it lands.

kvEntry *e = NULL;



s = kvStore_WatchAll(&w, kv, NULL);

while (s == NATS_OK)

{

    s = kvWatcher_Next(&e, w, 60000);

    if (s != NATS_OK)

        break;

    // A NULL entry marks the end of the initial replay. Skip it

    // and keep reading: everything after it is a live change.

    if (e == NULL)

        continue;

    printf("PUT %s: %.*s\n", kvEntry_Key(e),

           kvEntry_ValueLen(e), (const char*) kvEntry_Value(e));

    kvEntry_Destroy(e);

    e = NULL;

}
```

The watch first replays the current value, then waits:

```
[2026-06-09 10:14:22] PUT profiles > sue.color: blue
```

Leave the watch running. Here's the flow you've just set up: a writer puts a value, and the watcher receives it live.

**Message flow — KV watch — snapshot then live (animated):** A KV watch is snapshot-then-live. The warehouse-dashboard opens a watch on KV\_INVENTORY, which creates an ephemeral ordered consumer over the backing stream. The current value of every key replays first as the initial snapshot; a nil end-of-initial-data marker signals the watcher is caught up; from then on each fresh put streams through live.

* warehouse-dashboard → KV\_INVENTORY
* KV\_INVENTORY → ordered consumer
* ordered consumer → warehouse-dashboard

## Step 5: Update the value and see the watch fire

Back in your **first terminal**, put a new value for the same key.

#### CLI

```
#!/bin/bash

# Put a new value for the same key. This is a normal put: it overwrites

# whatever was there.



nats kv put profiles sue.color green



# You should see the new value echoed back:

#

#   green

#

# In the terminal running the watch, a new line appears the instant this

# lands:

#

#   [2026-06-09 10:15:03] PUT profiles > sue.color: green
```

#### C

```
// Put a new value for the same key. This is a normal put: it

// overwrites whatever was there, and the watcher in the other

// terminal sees the change the instant it lands.

uint64_t rev = 0;



s = kvStore_PutString(&rev, kv, "sue.color", "green");

if (s == NATS_OK)

    printf("stored sue.color at revision %llu\n",

           (unsigned long long) rev);
```

The put returns the new value:

```
green
```

Switch to the watch terminal. A new line appears the instant the change lands:

```
[2026-06-09 10:15:03] PUT profiles > sue.color: green
```

Stop the watch with `Ctrl-C` when you're done.

## What you built

You have a Key-Value bucket holding live state: you put and got a value, and a watcher in a second terminal received every change the moment it happened.

## Next

* Capstone: [7. Build an app](/tutorials/build-an-app.md) — combine publish/subscribe, request/reply, and a stream in one program.
* Now understand how this works: the [Key-Value deep dive](/learn/key-value/.md) explains buckets, revisions, watching, and the stream underneath.
