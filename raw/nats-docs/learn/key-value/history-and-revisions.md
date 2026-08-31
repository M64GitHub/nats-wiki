<!-- source: https://docs.nats.io/learn/key-value/history-and-revisions.md · fetched 2026-08-31 · section: history-and-revisions -->
# History and revisions

So far every write to a key has been a `put`: the new value replaces the old one, and you never had to think about who wrote last. That works until two writers touch the same key at the same time.

This page adds the two ideas that make concurrent writes safe. The first is the revision: a number the bucket assigns to every write, in sequence, and `history` keeps a key's prior ones. The second is compare-and-swap (CAS): a write that only succeeds if the key still holds the revision you read. Together they let the inventory service decrement `widget-blue` from 41 to 40 without ever losing a sale.

You still have the `INVENTORY` bucket from the first page. After the live update on the watching page, `widget-blue` holds 41, and the warehouse dashboard from that page is still attached. This page builds on both of those.

## Revisions and history

A **revision** is the number the server assigns to a write. The bucket keeps one counter across all of its keys, and every write — to any key — takes the next number. So a revision always increases when you write a key, but not by one each time: writes to other keys advance the counter in between. You don't set the revision; the server assigns it, and `get` returns it alongside the value as part of the **entry**.

The entry you got back on the first page already carried it. Your put of `widget-blue 42` landed at revision 1, the first write to an empty bucket. The put of `41` over it on the watching page landed at revision 2. The puts to `widget-red` and `gadget-pro` that followed took their own numbers, so `widget-blue`'s next write won't be revision 3. What matters for a safe write is only that the revision you read names the exact version you saw, which you'll use in a moment.

The bucket also keeps the **history**: the prior revisions of a key, up to the bucket's history depth. You set that depth when you created the bucket with `--history`, and `INVENTORY` was created with `--history 1`, which keeps only the latest value of each key. Raise it now so a key remembers where it's been:

```
nats kv edit INVENTORY --history 10
```

The depth caps at 64. Raising it keeps every future write to a key, up to ten revisions deep. The values written before the raise are already gone, because at depth 1 each new write dropped the one before it.

## Compare-and-swap: writing without locks

Consider a problem `put` can't solve. Two copies of the inventory service both sell a `widget-blue`. Each reads the count as 41, computes 40, and puts 40. Two sales happened, but the count only dropped by one. One write overwrote the other, and a unit of stock was lost from the count.

The fix is **optimistic concurrency**, which uses no locks and no waiting. Instead, each writer reads the current revision, then writes *on the condition* that the revision hasn't changed since. If another writer got there first, the condition fails and the write is rejected; nothing is overwritten. The rejected writer reads the fresh value and tries again.

The mechanism behind that condition is **compare-and-swap (CAS)**: you hand the server the revision you expect the key to be at, and the server swaps in your new value only if the key is still at that revision. NATS exposes CAS through two operations:

* **create** writes a key only if it doesn't exist yet. It's CAS against the expectation "this key is at revision 0" (no value present).
* **update** writes a key only if it's at the revision you name. It's CAS against "this key is still at the revision I read."

To decrement `widget-blue` safely, the inventory service reads the entry, takes its revision, computes the new count, and calls update with that revision. If the key is still at the revision it read, the write lands. If not, the write is rejected and nothing is lost.

#### CLI

```
#!/bin/bash

# Decrement widget-blue from 41 to 40 safely with compare-and-swap.

# Read the current entry, take its revision, then update on the condition

# that the key is still at that revision. If another writer got there

# first, the update is rejected and nothing is overwritten.



# Read the current revision from a get. The get prints a header line

# "... revision: N created @ ..." followed by the value, so pull N from it.

REVISION=$(nats kv get INVENTORY widget-blue | sed -n 's/.*revision: \([0-9]*\).*/\1/p')



# Update succeeds only if widget-blue is still at REVISION.

nats kv update INVENTORY widget-blue 40 "$REVISION"
```

#### C

```
// Decrement widget-blue from 41 to 40 safely with compare-and-swap.

kvEntry     *entry    = NULL;

uint64_t    revision  = 0;

uint64_t    newRev    = 0;



// Read the current entry; it carries the value and its revision.

s = kvStore_Get(&entry, kv, "widget-blue");

if (s == NATS_OK)

{

    revision = kvEntry_Revision(entry);

    printf("widget-blue is %s at revision %" PRIu64 "\n",

           kvEntry_ValueString(entry), revision);

    kvEntry_Destroy(entry);



    // Update succeeds only if widget-blue is still at that revision.

    // If another writer got there first, the update is rejected and

    // nothing is overwritten.

    s = kvStore_UpdateString(&newRev, kv, "widget-blue", "40", revision);

}

if (s == NATS_OK)

    printf("decremented widget-blue to 40 at revision %" PRIu64 "\n", newRev);
```

This is the read-modify-write you use whenever the new value depends on the old one, such as a decrement, an increment, or a status transition. The revision is what makes the write safe.

**Message flow — KV compare-and-swap retry (animated):** Optimistic concurrency on the KV bucket KV\_INVENTORY. The inventory service gets widget-blue and reads revision 7, then sends an update that only applies if the key is still at revision 7. A concurrent writer commits first and bumps widget-blue to revision 8, so the compare-and-set is rejected on the revision mismatch. The service re-gets widget-blue at revision 8, reapplies its change with the fresh revision, and this update is accepted. No write is lost and the service never holds a lock.

* inventory → KV\_INVENTORY
* other writer → KV\_INVENTORY

The animation shows the conflict: the service gets `widget-blue` at revision 7 and calls update expecting 7, but a concurrent writer has already bumped the key to revision 8. The server rejects the update on the revision mismatch. The service re-gets (now revision 8) and retries with the fresh revision, which the server accepts. No write was lost, and the service never held a lock.

## Read the history back

With the depth raised, the trail behind `widget-blue` is now visible. Read its history:

#### CLI

```
#!/bin/bash

# Read the kept history of a key. With history raised to 10 on this page,

# the trail behind widget-blue is now visible. Each row is one revision:

# the key, its revision number, the operation, when it was written, its

# length, and the value.

nats kv history INVENTORY widget-blue



# Expected output after the CAS decrement — two revisions kept:

#

#   History for INVENTORY > widget-blue

#

#   Key          Revision  Op   Created  Length  Value

#   widget-blue  2         PUT  ...      2       41

#   widget-blue  5         PUT  ...      2       40

#

# The revision numbers aren't consecutive — writes to widget-red and

# gadget-pro took the numbers in between — because the revision counter is

# bucket-wide, not per key. The value 42 written before the raise is gone;

# at history 1 each write dropped the one before it.
```

#### C

```
// Read the kept history of a key, oldest first. Each entry is one

// revision: the key, its revision number, the operation, and the

// value. The revision numbers aren't consecutive — the counter is

// bucket-wide, not per key.

kvEntryList list;

int         i;



s = kvStore_History(&list, kv, "widget-blue", NULL);

if (s == NATS_OK)

{

    printf("History for INVENTORY > widget-blue\n");

    for (i = 0; i < list.Count; i++)

    {

        kvEntry *e = list.Entries[i];



        printf("  %s rev %" PRIu64 " %s %s\n",

               kvEntry_Key(e), kvEntry_Revision(e),

               (kvEntry_Operation(e) == kvOp_Put) ? "PUT" : "MARKER",

               (kvEntry_Value(e) != NULL) ? kvEntry_ValueString(e) : "");

    }

    kvEntryList_Destroy(&list);

}
```

You see two revisions: `41` from the watching page and `40` from the decrement you just made. Their revision numbers aren't consecutive — the puts to `widget-red` and `gadget-pro` took the numbers in between — which is the revision counter being bucket-wide, not per key. Each entry is one line: the key, its revision, the operation, when it was written, and the value. The `42` written before the raise isn't here; depth 1 had already dropped it.

History holds the prior revisions of a single key, up to the depth. It isn't an audit log of the whole bucket, and it doesn't grow without bound: once a key has more revisions than the depth allows, the oldest one is removed. The full set of bucket configuration options is documented in [Reference → Create Stream](/reference/jetstream/api/stream/create.md).

## Pitfalls

Two mistakes are common the first time you rely on revisions. Both come from treating a CAS write like an unconditional one.

**A rejected update is dropped rather than queued, and you must retry.** Optimistic concurrency doesn't wait. When update finds the key at a different revision than you named, the server returns an error and your value is not written. If you fire-and-forget an update, a conflict silently loses the write. Don't assume an update succeeded; check the result, and on a revision mismatch, re-get the key and try again with the fresh revision. That re-get-and-retry loop is what CAS exists to support. Without that loop you have the same lost-write bug `put` had.

Here's the handling: get the current revision, attempt the update, and on a mismatch re-get and retry once with the new revision.

#### CLI

```
#!/bin/bash

# CAS retry loop. A rejected update is dropped, not queued, so on a

# revision mismatch re-get the key and retry with the fresh revision.

# Here the inventory service decrements widget-blue by one, safely.



# Read the value AND its revision from a SINGLE get, so the pair is

# consistent. Two separate gets could pair a stale value with a fresh

# revision if a concurrent write landed in between. The get prints a header

# line "... revision: N created @ ..." then a blank line then the value.

ENTRY=$(nats kv get INVENTORY widget-blue)

VALUE=$(printf '%s\n' "$ENTRY" | tail -n1)

REVISION=$(printf '%s\n' "$ENTRY" | sed -n 's/.*revision: \([0-9]*\).*/\1/p')

NEW_VALUE=$((VALUE - 1))



# Try the update; if a concurrent writer bumped the revision, re-get and retry once.

if nats kv update INVENTORY widget-blue "$NEW_VALUE" "$REVISION"; then

  echo "decremented widget-blue to $NEW_VALUE"

else

  echo "revision conflict, re-getting and retrying"

  ENTRY=$(nats kv get INVENTORY widget-blue)

  VALUE=$(printf '%s\n' "$ENTRY" | tail -n1)

  REVISION=$(printf '%s\n' "$ENTRY" | sed -n 's/.*revision: \([0-9]*\).*/\1/p')

  NEW_VALUE=$((VALUE - 1))

  nats kv update INVENTORY widget-blue "$NEW_VALUE" "$REVISION"

fi
```

#### C

```
// CAS retry loop. A rejected update is dropped, not queued, so on a

// revision mismatch re-get the key and retry with the fresh revision.

// Here the inventory service decrements widget-blue by one, safely.

kvEntry     *entry    = NULL;

uint64_t    revision  = 0;

uint64_t    newRev    = 0;

char        newValue[32];



// Read the value AND its revision from a single get, so the pair is

// consistent. Two separate gets could pair a stale value with a fresh

// revision if a concurrent write landed in between.

s = kvStore_Get(&entry, kv, "widget-blue");

if (s == NATS_OK)

{

    revision = kvEntry_Revision(entry);

    snprintf(newValue, sizeof(newValue), "%d",

             atoi(kvEntry_ValueString(entry)) - 1);

    kvEntry_Destroy(entry);



    // Try the update; if a concurrent writer bumped the revision,

    // re-get and retry once.

    s = kvStore_UpdateString(&newRev, kv, "widget-blue", newValue, revision);

    if (s != NATS_OK)

    {

        printf("revision conflict, re-getting and retrying\n");

        s = kvStore_Get(&entry, kv, "widget-blue");

        if (s == NATS_OK)

        {

            revision = kvEntry_Revision(entry);

            snprintf(newValue, sizeof(newValue), "%d",

                     atoi(kvEntry_ValueString(entry)) - 1);

            kvEntry_Destroy(entry);



            s = kvStore_UpdateString(&newRev, kv, "widget-blue",

                                     newValue, revision);

        }

    }

}

if (s == NATS_OK)

    printf("decremented widget-blue to %s\n", newValue);
```

**Do not use put for a read-modify-write.** Put is unconditional: it writes no matter what the key holds now, so it will overwrite a value a concurrent writer just stored. Put is correct when the new value doesn't depend on the old one, such as setting a SKU's count to a known absolute number from an inventory recount. When the new value is computed *from* the current value, like a decrement on a sale, use update with the revision instead. Use put to set a key to a given value, and update to change it from the value it currently holds.

## Where you are

You now have:

* An `INVENTORY` bucket whose `widget-blue` key has been decremented from 41 to 40 with a CAS update, not a blind put.
* The ability to read a key's history and reason about its revision.
* A working model of optimistic concurrency: read the revision, write on that condition, retry on mismatch.

The warehouse dashboard from the watching page saw that decrement arrive live, the same as any other change.

## What's next

The next page gives a key its own lifetime with a per-key **TTL**, and bounds the whole bucket with limits.

Continue to [TTL and limits](/learn/key-value/ttl-and-limits.md).

## See also

* [Reference → Create Stream](/reference/jetstream/api/stream/create.md) — every bucket configuration option, including history depth.
* [Watching](/learn/key-value/watching.md) — how a watcher receives the changes you make with update.
