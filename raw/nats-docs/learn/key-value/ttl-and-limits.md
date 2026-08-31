<!-- source: https://docs.nats.io/learn/key-value/ttl-and-limits.md · fetched 2026-08-31 · section: ttl-and-limits -->
# TTL and limits

Every key in `INVENTORY` so far lives until you overwrite or delete it. That's the right default for a stock count, but it's not the only thing a bucket holds. Some values should clean themselves up, such as a flash-sale price, a short-lived session token, or a "this SKU is locked for the next 30 minutes" flag.

This page adds two ways to bound the bucket by time. The first is the per-key TTL, a single key that expires on its own. The second is the set of bucket limits that bound the whole thing: total size, value size, history depth. When a key expires, the server leaves a marker so the warehouse dashboard learns the value is gone, the same way it learned about every other change.

You still have the `INVENTORY` bucket from the previous pages, with `widget-blue` decremented to 40 and the warehouse dashboard watching. You'll add a key with a TTL to it.

## A per-key TTL expires a single value

A **TTL** (time-to-live) is how long a value stays in the bucket before the server removes it. A **per-key TTL** attaches that clock to one key. The key lives for its TTL, then disappears on its own, with no service having to remember to delete it.

Per-key TTL is set at **create** time, and only at create time. You hand the TTL to create alongside the value, and the key starts its countdown the moment it lands. This is a deliberate restriction: a TTL belongs to the value you're writing now, not to a value that might be put over it later.

One setup step comes first. Per-key TTLs ride on a bucket feature called **limit markers**, the same mechanism that leaves a trace when a value expires. A bucket needs limit markers enabled before any key in it can carry a TTL. `INVENTORY` was created without them, so you turn them on once, then create the timed key:

#### CLI

```
#!/bin/bash



# Give a single key its own lifetime with a per-key TTL.

#

# Per-key TTL rides on the bucket's Limit Markers, so the bucket must have

# them enabled first. INVENTORY was created without them, so turn them on

# once (the duration is how long the bucket keeps the expiry marker):

nats kv edit INVENTORY --marker-ttl 1h



# Now create flash-sale with a 30-minute TTL. The value expires on its own

# 30 minutes after this create; no service has to remember to clean it up.

# Note: TTL is accepted on CREATE only.

nats kv create INVENTORY flash-sale 99 --ttl 30m



# Expected: create echoes the value it stored, and the key counts down on

# its own:

#

#   99

#

# Per-key TTL requires nats-server 2.11 or newer. On an older server the

# create is rejected because the bucket cannot enable Limit Markers.



# --- Per-key TTL is create-only: to change it, delete then create ---------

#

# Neither put nor update takes a --ttl; the CLI rejects the flag. Writing

# flash-sale again with put or update appends a new value with no TTL, so

# the key stops expiring rather than keeping its clock. To give flash-sale

# a different lifetime, remove it and create it again with the new TTL:

nats kv del INVENTORY flash-sale --force

nats kv create INVENTORY flash-sale 99 --ttl 10m



# The key now expires in 10 minutes instead of 30.
```

#### C

```
// Per-key TTL rides on the bucket's limit markers, so the bucket

// needs them enabled. The C client turns them on when the bucket is

// created: a LimitMarkerTTL > 0 enables per-key TTLs and is how long

// the bucket keeps an expiry marker. Requires nats-server 2.11+.

kvStore     *kv  = NULL;

uint64_t    rev  = 0;

kvConfig    cfg;



kvConfig_Init(&cfg);

cfg.Bucket         = "INVENTORY";

cfg.History        = 10;

cfg.LimitMarkerTTL = 60LL * 60 * 1000000000LL; // 1 hour, in nanoseconds



s = js_CreateKeyValue(&kv, js, &cfg);



// Create flash-sale with a 30-minute TTL (in milliseconds). The value

// removes itself 30 minutes later; no service has to clean it up.

// A TTL is accepted on create only: neither put nor update takes one.

if (s == NATS_OK)

    s = kvStore_CreateStringWithTTL(&rev, kv, "flash-sale", "99",

                                    30 * 60 * 1000);

if (s == NATS_OK)

    printf("created flash-sale at revision %" PRIu64 "\n", rev);



// A per-key TTL is create-only, and writing the key again appends a

// value with no TTL of its own. To change a TTL, delete the key and

// create it again with the new one.

if (s == NATS_OK)

    s = kvStore_Delete(kv, "flash-sale");

if (s == NATS_OK)

    s = kvStore_CreateStringWithTTL(&rev, kv, "flash-sale", "99",

                                    10 * 60 * 1000);

if (s == NATS_OK)

    printf("flash-sale now expires in 10 minutes\n");
```

The `flash-sale` key now holds `99` and will remove itself 30 minutes later. Because the TTL is stored with the value, this happens without a cron job, a separate cleanup service, or a sweep.

Per-key TTL needs **nats-server 2.11 or newer**; that's the release that added limit markers. On an older server, enabling markers on the bucket is rejected, and the timed create fails with it. If you're on 2.11, the feature is available.

## Bucket limits bound the whole bucket

Where a per-key TTL bounds one value, **bucket limits** bound the whole bucket. They keep a key-value store from growing without end, and you set them when you create the bucket. Three of them matter most:

* **Max bucket size**: the total bytes the bucket may hold across every key and every kept revision. The bucket won't grow past it.
* **Max value size**: the largest a single value may be. A put of something bigger is rejected. Key-value values are meant to be small; large values belong in the [Object Store](/learn/object-store/.md).
* **History depth**: how many prior revisions each key keeps, which you already met on the previous page. It caps at 64, and it doubles as a per-key cap: it's the most messages any single key may hold.

Here those limits go on a throwaway `CACHE` bucket, so the numbers stand on their own and don't imply anything about `INVENTORY`:

#### CLI

```
#!/bin/bash



# Create a throwaway CACHE bucket to show the three bucket-level limits.

# We use CACHE, not the pinned INVENTORY bucket, on purpose: INVENTORY's

# TTLs are per-key, not bucket-wide, and we do not want to imply the whole

# INVENTORY bucket expires.

#

#   --ttl 1h            bucket-wide max age: every value older than 1h is

#                       removed, regardless of key. This is the bucket's

#                       MaxAge, not a per-key TTL.

#   --max-bucket-size   the bucket's total size cap, in bytes.

#   --max-value-size    the largest a single value may be, in bytes.

nats kv add CACHE \

  --history 1 \

  --ttl 1h \

  --max-bucket-size 16MB \

  --max-value-size 64KB



# Expected output is the bucket's status. The CLI parses MB and KB as binary

# units (1 MB = 1 MiB, 1 KB = 1 KiB), so 16MB shows as 16 MiB and 64KB as

# 64 KiB (labels abbreviated here):

#

#   Information for Key-Value Store Bucket CACHE created <time>

#

#   Configuration:

#

#              Bucket Name: CACHE

#              History Kept: 1

#               Maximum Age: 1h0m0s

#       Maximum Bucket Size: 16 MiB

#        Maximum Value Size: 64 KiB

#     ...

#

# A KV bucket uses discard-new: a put that would push it past

# --max-bucket-size, or a value larger than --max-value-size, is rejected

# with an error and the existing values are kept. Size the bucket for the

# working set you need to hold, not the average, so a burst doesn't bounce

# writes.
```

#### C

```
// Create a throwaway CACHE bucket to show the three bucket-level

// limits. TTL here is the bucket-wide max age — every value older

// than 1 hour is removed, regardless of key — not a per-key TTL.

kvStore     *cache = NULL;

kvStatus    *sts   = NULL;

kvConfig    cfg;



kvConfig_Init(&cfg);

cfg.Bucket       = "CACHE";

cfg.History      = 1;

cfg.TTL          = 60LL * 60 * 1000000000LL; // 1 hour, in nanoseconds

cfg.MaxBytes     = 16 * 1024 * 1024;         // total size cap: 16 MiB

cfg.MaxValueSize = 64 * 1024;                // largest single value: 64 KiB



s = js_CreateKeyValue(&cache, js, &cfg);

if (s == NATS_OK)

    s = kvStore_Status(&sts, cache);

if (s == NATS_OK)

{

    // A put larger than the value cap, or one that would push the

    // bucket past its size cap, is rejected; existing values stay.

    printf("Bucket: %s\n", kvStatus_Bucket(sts));

    printf("History kept: %" PRIi64 "\n", kvStatus_History(sts));

    printf("Maximum age: %" PRIi64 "s\n", kvStatus_TTL(sts) / 1000000000LL);

    kvStatus_Destroy(sts);

}

kvStore_Destroy(cache);
```

The `--ttl` on the bucket above is a different clock from the per-key TTL. A bucket TTL expires *every* value once it reaches that age; the per-key TTL expires *one* value. The bucket-wide form is the stream's `MaxAge` limit — one deadline applied to every value in the bucket — and it lives with the other [stream limits](/learn/jetstream/shaping-the-stream.md). The per-key form is the one built on JetStream's [per-message TTL](/learn/jetstream/message-ttl.md), and it's the form unique to key-value that this chapter teaches.

The full set of bucket configuration options is documented in [Reference → Create Stream](/reference/jetstream/api/stream/create.md), because a bucket is created as a stream and these limits map onto stream fields. Here you only need the three above.

## Expiry leaves a marker for watchers

When a per-key TTL fires, the server leaves a **marker** instead of silently dropping the value: a small message that records the key is gone and why. You may have heard the marker called a *tombstone* elsewhere; the term in key-value is marker, and a TTL expiry leaves one with the reason `MaxAge`: the value aged out.

The marker matters because of the warehouse dashboard. A watcher receives the marker as a purge on the key — the CLI prints `PURGE` — just as if someone had purged it by hand. Without the marker, a watcher that saw `flash-sale` appear would never learn it had vanished, and its view of the bucket would drift out of date. The marker is how live readers stay correct when a value expires on its own.

**Message flow — KV per-key TTL expiry (animated):** A per-key TTL expiring on its own, seen by a watcher. The inventory service writes flash-sale=99 to KV\_INVENTORY with a 30-minute per-key TTL. The clock advances past 30 minutes, the value ages out, and the server places a marker on flash-sale with reason MaxAge. warehouse-dashboard, watching the bucket, receives that marker as a purge operation and learns the value is gone, without any service deleting it.

* inventory → inventory
* clock → inventory
* inventory → warehouse-dashboard

The animation walks the timeline: the inventory service creates `flash-sale` with a 30-minute TTL; the clock advances past it; the server places a marker on the key with reason `MaxAge`; and the warehouse dashboard receives that marker as a purge. The value expired without any service modifying it, and the watcher was still notified through the marker.

## Pitfalls

Two mistakes are common the first time you add a TTL or a limit to a bucket. Both come from expecting a TTL or a limit to behave in a way it does not.

**A per-key TTL is set at create, and only at create.** Neither put nor update takes a `--ttl`; the CLI rejects the flag outright. And writing the key again doesn't extend its TTL: a put or an update appends a new latest value with no TTL of its own, so the key simply stops expiring — put and update behave the same way here. To give a key a different TTL, delete it and create it again with the new one. Use delete-then-create to change a TTL, not put or update.

The handling is in the create snippet above: after the timed create, it deletes `flash-sale` and creates it again with a shorter TTL, which is the only way to change one.

**Limits reject, they do not make room for an oversized value.** A put of a value larger than the bucket's max value size is rejected outright, and so is a put that would push the bucket past its max size; the server returns an error and leaves every existing value in place. The inventory service sees that error on the put, not later on a get, so a `CACHE` bucket sized for the average load starts refusing writes the moment a burst pushes it to the cap. Size the bucket for the working set you actually need to hold, not the average, so a busy minute doesn't bounce writes you needed to land, and cap max value size above the largest value you legitimately store.

## Where you are

You now have:

* An `INVENTORY` bucket with limit markers enabled and a `flash-sale` key that expires on its own after a per-key TTL.
* A feel for the three bucket limits (max bucket size, max value size, and history depth) that bound the whole bucket.
* A working model of the expiry marker: when a value ages out, the server leaves a marker with reason `MaxAge`, and the warehouse dashboard receives it as a purge.

The bucket is now complete. It holds keys with values, keeps history, supports safe concurrent writes, and has values that remove themselves on a TTL.

## What's next

The next page shows the internals. It covers the `KV_INVENTORY` stream that's been under the bucket the whole time, the direct read path, and the difference between delete and purge.

Continue to [Under the hood](/learn/key-value/under-the-hood.md).

## See also

* [Reference → Create Stream](/reference/jetstream/api/stream/create.md) — every bucket limit and its valid range.
* [JetStream → Message TTL](/learn/jetstream/message-ttl.md) — the per-message expiry mechanism the per-key TTL is built on.
* [JetStream → Shaping the stream](/learn/jetstream/shaping-the-stream.md) — `MaxAge` and the other stream limits the bucket-wide TTL and size caps map onto.
* [Object Store](/learn/object-store/.md) — where large values belong when they outgrow a key-value bucket.
