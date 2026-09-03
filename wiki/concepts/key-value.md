---
title: Key-Value
type: concept
area: [kv, jetstream]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [kv, bucket, tombstone, watch, direct-get]
aliases: [KV, key value, KV bucket, KV_]
sources: [s-gh-6746-watch-many-keys, s-gh-5243-kv-watchers-at-scale, s-adr-8-key-value-store, s-adr-43-per-message-ttl, s-adr-17-ordered-consumer, s-docs-stream-config, s-gh-7017-kv-across-accounts, s-gh-5606-cross-account-jetstream, s-adr-48-kv-ttl, s-adr-57-kv-subject-transforms, s-adr-54-kv-codecs, s-nats-server-filestore-layout, s-docs-kv-under-the-hood, s-docs-kv-watching, s-docs-kv-history-and-revisions, s-docs-kv-ttl-and-limits, s-docs-kv-your-first-bucket, s-docs-object-store-watching-and-listing, s-docs-object-store-metadata-and-links, s-adr-20-object-store, s-adr-31-direct-get, s-docs-get-direct, s-docs-mirrors-and-sources, s-gh-6328-jetstream-behind-gateways, s-nats-server-leafnode-js-domains, s-nats-server-mirrors-observed, s-nats-go-kv-object-mirror, s-gh-8417-kv-mirror-file-vs-memory, s-nats-server-mirror, s-relnotes-2.14.4, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12]
created: 2026-08-31
updated: 2026-09-03
---

# Key-Value

A KV bucket **is a [[stream]]** with a fixed set of properties, a reserved name and a reserved
subject space. Every operator question about KV — why a delete grows the bucket, why a read can be
stale, why key listing is cheap — is answered by that mapping
(source: [[s-adr-8-key-value-store]]).

## The stream a bucket actually is

| property | value, fixed by the KV spec |
|---|---|
| stream name | **`KV_<bucket>`** |
| subjects | **`$KV.<bucket>.>`** |
| history per key | `max_msgs_per_subject` — **min 1, max 64**; clients use `1` when the user gives no value |
| `discard` | **always `new`** |
| `rollup_hdrs` | **always `true`** — safe key purges that delete history require it |
| `deny_delete` | **always `true`** |
| `allow_direct` | **always `true`**; changeable out-of-band only, never through a bucket update |
| storage | write replicas are **file** backed; the replica count may vary |
| key TTL (whole bucket) | the stream's `max_age` |
| value size cap | `max_msg_size` |
| bucket size cap | `max_bytes` |
| compression | `compression: "s2"` when requested |
| **number of keys** | **cannot currently be limited** |

`placement`, `republish` and stream `metadata` are all allowed. Deleting a bucket deletes the
stream.

This means **`nats stream info KV_<bucket>` works and tells you the truth** — a KV bucket is
inspectable, sizable and placeable with everything on [[stream]], [[replicas]] and
[[stream-placement]]. The docs print exactly that output as the proof
(source: [[s-docs-kv-under-the-hood]]):

```
Subjects: $KV.INVENTORY.>          # one subject per key
Discard Policy: New                # at a limit, rejects the newest write
Direct Get: true                   # get reads without a consumer
Allows Rollups: true               # purge replaces a key with one marker
Allows Msg Delete: false           # deny_delete: no raw stream deletes
Maximum Per Subject: 10            # this IS the history depth
```

**`discard: new` is why a full bucket rejects rather than forgets**: "the bucket keeps the messages it
already holds rather than evicting them", which is the opposite of the `discard: old` default a
plain stream gets ([[stream]]).

**And `deny_delete` is narrower protection than it looks.** It blocks the JetStream *message-delete*
API, so nothing can remove entries behind the KV API's back — but **it does not stop a raw publish**:

> "That setting doesn't stop a raw publish — which is exactly why you avoid one." A raw `nats pub` to
> `$KV.<bucket>.<key>` "writes a bare message with none of them, so a watcher can't tell it from a
> real put and a purge you meant never happens." (source: [[s-docs-kv-under-the-hood]])

The headers a raw publish omits are the ones that make the store correct: the expected-revision header
behind compare-and-swap, and `KV-Operation` / `Nats-Rollup` behind delete and purge. **The only thing
that actually prevents this is an ACL** denying publish on `$KV.<bucket>.>` to everything but the KV
clients ([[subject-permissions]]).

**A get is a [[direct-get]], addressed literally.** The request goes to
`$JS.API.DIRECT.GET.<stream>.<subject>` — for a key `widget-blue` in bucket `INVENTORY`, that is
`$JS.API.DIRECT.GET.KV_INVENTORY.$KV.INVENTORY.widget-blue`. "That last message is the current value,
its sequence is the revision, and its store time is the entry timestamp"
(source: [[s-docs-kv-under-the-hood]]).

### The `max_age` / `duplicate_window` rule

When a bucket-wide key TTL is set, `duplicate_window` must follow `max_age`
(source: [[s-adr-8-key-value-store]]):

- `max_age` **> 2 minutes** → `duplicate_window` must be **2 minutes**;
- `max_age` **≤ 2 minutes** → `duplicate_window` must equal `max_age`.

If no key TTL is set, leaving `duplicate_window` unset is fine — the ADR states the server applies
this logic itself and defaults to 2 minutes. See *The deduplication window* on [[stream]].

## How it behaves

**Writes are publishes.** Key `auth.username` in bucket `CONFIGURATION` is a JetStream request to
`$KV.CONFIGURATION.auth.username`.

**A revision is the stream sequence, so the counter is bucket-wide, not per key.**

> "The bucket keeps one counter across all of its keys, and every write — to any key — takes the next
> number. So a revision always increases when you write a key, but not by one each time: writes to
> other keys advance the counter in between." (source: [[s-docs-kv-history-and-revisions]])

The docs' worked history shows one key at revisions **2** and **5**, with 3 and 4 taken by other keys.
**Never derive anything from the gap between two revisions of one key** — it is other keys' traffic,
not lost data.

### Compare-and-swap is two operations

Optimistic concurrency, no locks and no waiting (source: [[s-docs-kv-history-and-revisions]]):

| operation | the condition it checks |
|---|---|
| **`create`** | the key is at **revision 0** — i.e. it does not exist |
| **`update`** | the key is still at **the revision you name** |

```
REVISION=$(nats kv get INVENTORY widget-blue | sed -n 's/.*revision: \([0-9]*\).*/\1/p')
nats kv update INVENTORY widget-blue 40 "$REVISION"
```

Three rules follow, and each is a real bug when broken:

- **A rejected update is dropped, not queued.** "If you fire-and-forget an update, a conflict silently
  loses the write." Every read-modify-write needs a re-get-and-retry loop; without it, `update` has
  exactly the lost-write bug `put` had.
- **Read the value and its revision from a *single* get.** Two gets "could pair a stale value with a
  fresh revision if a concurrent write landed in between".
- **`put` is unconditional** and belongs only where the new value does not depend on the old one.

**History depth is raised in place and is not retroactive**: `nats kv edit <bucket> --history 10`
starts keeping revisions from that moment, and "the values written before the raise are already gone".
It caps at **64**, and it is also "the most messages any single key may hold".

**Compare-and-set is a header.** `Nats-Expected-Last-Subject-Sequence` carries the revision the
write expects; the special value `0` means "only if this is the first message on the subject", and
it is **purge-aware** — after a purge, `0` is accepted again.

**Reads go through Direct Get.** `$JS.API.DIRECT.GET.<STREAM>.<SUBJECT>` "should be used for
performing all gets on a bucket if direct is enabled", and disabling direct get on a bucket is not
supported. The older `stream_msg_get_request` + `last_by_subj` path exists only for legacy buckets.
See [[direct-get]].

### There is no read-after-write consistency

Quoting the spec directly:

> "We do not provide read-after-write consistency. Reads are performed directly to any replica,
> including out of date ones. If those replicas do not catch up multiple reads of the same key can
> give different values between reads."

A healthy cluster will *mostly* return consistent values, "but this should not be relied on to be
true." Read-after-write existed historically and is **deprecated**. This follows directly from
Direct Get being answerable by any replica — see [[replicas]].

**The mechanism, exactly.** Direct Get is served by a **queue group of stream peers** named `_sys_`,
so "the number of servers eligible to respond to read requests is the same as the replica count of
the stream" (source: [[s-adr-31-direct-get]]). A KV read is therefore load-balanced across R replicas
by design, and the stale read is the price of that. The read itself has no KV-specific machinery: the
docs put it plainly — "This is the read a key-value lookup is built on: **'the latest value for a key'
is 'the last message on its subject'**" (source: [[s-docs-get-direct]]). Which means a KV get is
inspectable as a stream read, without a KV client:

```
nats stream get KV_INVENTORY --last-for '$KV.INVENTORY.widget-blue'
```

See [[direct-get]].

## Deletes do not remove data

This is the single most surprising KV behaviour, and it falls straight out of the stream mapping
(source: [[s-adr-8-key-value-store]]):

| operation | what actually happens |
|---|---|
| **Delete** | **publishes a new message** with a nil body and the header **`KV-Operation: DEL`**. History is preserved. The bucket grows. |
| **Purge** | publishes **`KV-Operation: PURGE`** *plus* **`Nats-Rollup: sub`**, which makes the server place the purge message and then delete every message for that key **up to before it**. One message remains. |

So a delete **adds** a message and a purge leaves a tombstone behind. Space comes back when the
stream's own limits (`max_age`, `max_msgs_per_subject`, `max_bytes`) remove the remaining entries —
or, since 2.11, when a TTL expires the tombstone itself. A purge can carry a TTL, which adds
`Nats-TTL` to the purge message. See [[message-ttl]].

Any entry whose `KV-Operation` header is set is deleted data. A plain get turns that into a
*key not found* error; watchers and history surface it as an entry with the operation set.

## Watch, history and listing keys

All three are **ephemeral [[ordered-consumer|ordered consumers]]** under the hood
(source: [[s-adr-8-key-value-store]]):

| operation | how it is built |
|---|---|
| **Watch** | ordered consumer starting at **`last_per_subject`**, so it opens with the newest value of every matching key. Multiple keys = **multiple filter subjects** — one consumer, not one per key (source: [[s-gh-6746-watch-many-keys]]; needs nats-server **2.10+** and a client that exposes it). |
| **History** | ordered consumer filtered by subject, reading with `deliver_all`. The latest value is the one with `Pending == 0`. |
| **Keys** | a **headers-only** consumer set to **deliver last per subject** — keys are parsed out of the subject and delete/purge operations skipped. **No values cross the wire.** |

That last row is the answer to "how do I count keys without fetching them": key listing already
transfers no values.

**Watch options**: `IncludeHistory`, `IgnoreDeletes`, `MetaOnly`, `UpdatesOnly`. The default with no
options sends every `last_per_subject` value **including delete and purge operations**.

**End of initial data** is signalled the first time a message has `Pending == 0`, and the spec
requires the signal to be sent **always** — including for an empty bucket.

**What that signal looks like to a client differs per language, and one client does not have it at
all** (source: [[s-docs-kv-watching]]):

| client | how the boundary arrives |
|---|---|
| Go, Python | a **nil / `None` entry** in the same stream as real entries |
| JavaScript | an **`isUpdate` flag** on each entry |
| Java | an **`endOfData()` callback** |
| C# | an **`OnNoData` option** |
| **Rust** | **no marker** — snapshot-plus-live or live-only is chosen when the watch is opened |
| `nats` CLI | consumed silently; never printed |

**This is the most common watch bug, and it is what "the watcher missed updates" usually means.** A
loop that treats the nil entry as end-of-stream reads the snapshot, sees the boundary, and quits
before the first live change — "stopping the loop on the nil entry would miss every live change".
The signal is also useful in its own right: hold a dashboard in "loading" until it arrives, or treat
it as "cache warm".

**`IncludeHistory` and `UpdatesOnly` conflict** — one asks for a full snapshot with history, the
other for no snapshot — "and a client rejects the pair" (source: [[s-docs-kv-watching]]).

**The [[object-store]] watch has the same boundary and a different payload**, and the contrast is the
cleanest statement of what each store is for. A KV watch "delivers each key's *value* directly,
because values are small"; an object-store watch delivers only the `ObjectInfo` — name, size, chunk
count, digest — "so the watch delivers only the metadata and leaves the data fetch to you", and the
caller issues a separate get for the bytes it wants (source:
[[s-docs-object-store-watching-and-listing]]). Same nil sentinel, same trap; a KV watcher that quits
on it misses live values, an object watcher that quits on it misses live *names*.

### A filter is a subject filter, so key naming decides what can be watched

A watch's key filter is matched the way a subject is: **`*` is exactly one whole token**, `>` is one
or more trailing tokens. So on flat keys the obvious filter does not work:

> "`widget-blue` is one token, and the hyphen is an ordinary character, not a separator. So a filter
> like `widget-*` **is not a wildcard at all** … and it matches nothing. To split keys with a
> wildcard you'd design them with dots, such as `widget.blue` and `widget.red`, so that `widget.*`
> matches both." (source: [[s-docs-kv-watching]])

The filter applies to **both** halves — snapshot and live — so a filtered watch is genuinely cheaper,
not a client-side filter over everything. This is a second reason *Keys are subjects* below is a
design decision made once: a hyphen buys you nothing, a dot buys you a filter.

**A watch is not a point read.** It is an ephemeral consumer that dies with the process; using one to
fetch a single value "pays for a consumer and a snapshot to get one value get would have handed you
directly" ([[direct-get]]).

Because watches and key listings create and drop ephemeral consumers, a busy KV workload shows up
as consumer churn; see [[ordered-consumer]] and the memory note on [[jetstream-sizing]]. At scale the
churn — not the count — is what breaks: 1000 clients each watching one key in a bucket holding a
single 118-byte message pinned a 3-node cluster at its CPU limit and it did not recover
(source: [[s-gh-5243-kv-watchers-at-scale]]). See [[kv-watchers-stall-the-cluster]].

## Limit markers and per-key TTL

Since **2.11**, KV supports a TTL per key, built on per-message TTL
(source: [[s-adr-43-per-message-ttl]], [[s-adr-8-key-value-store]]). With limit markers enabled,
clients receive a **`Nats-Marker-Reason`** header:

| value | treat as |
|---|---|
| `MaxAge` | `PURGE` |
| `Purge` | `PURGE` |
| `Remove` | `DEL` |

Enabling markers requires `allow_msg_ttl: true` and a `subject_delete_marker_ttl` of **at least one
second**, and a server at **API level 1 or newer (2.11+)**. The spec is specific that clients should
assert this with **`$JS.API.INFO`, not the connected server's version string**.

### What the TTL spec actually allows

Three rules from ADR-48, the refinement that added per-key TTL (source: [[s-adr-48-kv-ttl]]):

- **"Limit Markers" is one setting that writes two stream fields** — `allow_msg_ttl: true` and
  `subject_delete_marker_ttl: <duration>`. So `nats stream info KV_<bucket>` tells you whether a
  bucket has them.
- **The duration must be ≥ 1 second**, and the setting is **one-way**: it can be enabled on a bucket
  that lacks it, and the spec deliberately does not offer disabling it.
- **A TTL is accepted on `Create` and `Purge` only.** Not on `Put`, and the reason is worth knowing:
  "a TTL on `Put()` might mean older revisions could come back from the dead once the TTL expires".
  A `Purge` with a TTL is also the supported replacement for compaction — it removes old subjects
  permanently while still producing something a watcher can see.

**The `put`-over-a-TTL trap.** The spec says why `Put` cannot take a TTL; the docs say what actually
happens when someone writes the key again anyway, and it is worse than an error:

> "Writing the key again doesn't extend its TTL: a put or an update appends a new latest value
> **with no TTL of its own, so the key simply stops expiring**." (source: [[s-docs-kv-ttl-and-limits]])

No error, no warning — the key silently becomes permanent. **To change a key's TTL you delete it and
create it again.** This is the failure mode to watch for on a bucket used for sessions or leases: one
ordinary `put` from anywhere turns an expiring key into a permanent one.

**The CLI spelling is `--marker-ttl`**, on `nats kv add` or `nats kv edit`:

```
nats kv edit INVENTORY --marker-ttl 1h
nats kv create INVENTORY flash-sale 99 --ttl 30m
```

**A watcher cannot tell a TTL expiry from a manual purge.** The expiry marker carries the reason
`MaxAge`, but the operation a watcher receives is `PURGE` either way, "just as if someone had purged
it by hand" — the reason header is the only distinguishing signal
(source: [[s-docs-kv-ttl-and-limits]]).

### Bucket limits reject; they never make room

The three limits, and the CLI's unit convention (source: [[s-docs-kv-ttl-and-limits]]):

| flag | bounds | stream field |
|---|---|---|
| `--max-bucket-size` | total bytes across every key **and every kept revision** | `max_bytes` |
| `--max-value-size` | the largest single value | `max_msg_size` |
| `--history` | prior revisions per key, **max 64** | `max_msgs_per_subject` |
| `--ttl` | every value's age — **the bucket-wide clock, not the per-key one** | `max_age` |

"A put of a value larger than the bucket's max value size is rejected outright, and so is a put that
would push the bucket past its max size; the server returns an error and leaves every existing value
in place." That is `discard: new` doing what it says. **Size a bucket for the working set, not the
average** — a bucket at its cap starts bouncing writes during exactly the busy minute you needed them.

**The CLI parses `MB` and `KB` as binary units** — `16MB` prints back as `16 MiB`, `64KB` as
`64 KiB`.

## Mirrors and sources of a bucket

A KV bucket is a stream, so it mirrors and sources like one ([[mirrors-and-sources]]) — but a
conforming client writes a specific stream config, and knowing it makes `nats stream info` readable
(source: [[s-adr-57-kv-subject-transforms]], **Proposed**, so verify against the client you use):

- **A KV mirror always gets `mirror_direct` enabled**, and its stream name is `KV_`-prefixed. That is
  what puts a mirrored bucket into the upstream's Direct Get queue group and gives readers the
  nearest copy — subject to the alignment rules on [[mirrors-and-sources]].
- **A KV source gets a subject transform generated for it**: `$KV.<source>.>` → `$KV.<bucket>.>`, so
  keys land in the destination bucket's own subject space. Sourcing `ORDERS` into `NEW_ORDERS` with
  a key filter `NEW.>` produces `{"src": "$KV.ORDERS.NEW.>", "dest": "$KV.NEW_ORDERS.>"}`.
- **`Lag` is the staleness number, and a sourced bucket needs one alert per upstream.** A mirror or
  source reports its own `Lag` and `Last Seen` in `nats stream info`, "because each source replicates
  on its own" — a lag that climbs and stays high is the signal, not a lag that moves
  (source: [[s-docs-mirrors-and-sources]]). For a bucket this is the honest bound on how old a
  replicated read can be, where the [[replicas]] case is bounded only by catch-up.
- **The maintainer-recommended shape for a regional read replica is a leafnode, not a gateway.**
  Asked for regional read replicas of a KV bucket holding auth sessions across four continents, a
  maintainer answered: "You don't even need a super-cluster, you could simply have your 3 node cluster
  in the US and have each of your 1 nodes in other parts of the world connect to the cluster as Leaf
  Nodes. Then you can enable JS on those leaf nodes and create read replica streams that source from
  streams located in the cluster" (source: [[s-gh-6328-jetstream-behind-gateways]]). A stream's
  replicas never leave their cluster, so crossing a JetStream boundary is a mirror-or-source operation
  whatever the connection type — which makes the choice a network and isolation question. See
  [[choosing-a-topology]] and [[leafnode]].
- **Supplying your own transform turns the automation off entirely** — including the `KV_` prefix on
  the source name. That is how an **ordinary stream becomes a KV source**
  (`events.processed.>` → `$KV.EVENT_CACHE.>`, a bucket as a materialised view) and how keys can be
  remapped between buckets (`$KV.INVENTORY.warehouse.*.product.>` → `$KV.PRODUCTS.>` turns
  `warehouse.nyc.product.item123` into `item123`).

### Reading a mirror: which name, which storage, which filter

Three things a mirrored bucket does that the origin does not, all measured on nats-server 2.14.6
with `nats` CLI 0.4.0 / nats.go 1.53.1 (sources: [[s-nats-server-mirrors-observed]],
[[s-nats-go-kv-object-mirror]]):

**Which name.** `nats kv add DNS_FILE --mirror DNS --storage file` builds a mirror that holds
`$KV.DNS.>` — no transform is added, exactly as ADR-57 specifies — but the client reads a bucket at
its *own* prefix, so `nats kv ls DNS_FILE` prints `No keys found in bucket` and `nats kv get DNS_FILE
k1` says `key not found` (the trace: `$JS.API.DIRECT.GET.KV_DNS_FILE.$KV.DNS_FILE.k1`) while
`nats kv info DNS_FILE` reports every value. Two ways out: **read the origin's name** and let
`mirror_direct` route the get to the nearest mirror — the design ADR-57 describes; or build the
mirror as a stream with `$KV.DNS.>` → `$KV.DNS_TR.>` (`nats stream add KV_DNS_TR --config …` with
`max_msgs_per_subject: 1`, `allow_direct`, `mirror_direct`, `discard: new`, `deny_delete`,
`allow_rollup_hdrs`), which is readable by name at once. A **cross-domain** mirror
(`--mirror-domain leaf`) is readable by its own name without any of that: for a mirror with an
`external` block the client rewrites the read prefix to the origin's (`jetstream/kv.go:1610–1618`).
Writes through a mirror bucket always go to the origin.

**Which storage.** The same mirror on memory storage synced 400,000 live keys over 2.4 M sequences
in 0.74 s against 1.24 s on file, and read at the same speed with or without a filter. A **file**
mirror read with the bucket's own filter `$KV.DNS.>` ran at 267,866 msg/s against 1,740,462
without it — the sequence space of a bucket with a hot key space is mostly holes, a mirror has no
subjects of its own, and the file store's linear-scan heuristic then sends every lookup through the
per-subject state (source: [[s-nats-server-mirror]]; the public report measured 65× on 2.14.2,
[[s-gh-8417-kv-mirror-file-vs-memory]]). The origin bucket is immune: its filter *is* its subject.

**Which filter.** Everything that reads a whole bucket passes that filter — a watch, `nats kv ls`
(a `last_per_subject`, `headers_only` push consumer on `$KV.<bucket>.>`), a `last_per_subject`
consumer. `nats kv ls` on a 400,000-key file mirror took 1.533 s against 0.427 s on the origin. So
for a file mirror that is meant to be *scanned*, either leave the filter off the consumer, or scan
the origin, or make the hot-read mirror a memory one. 2.14.4 made the delete-map lookups cheaper but
did not change the heuristic (source: [[s-relnotes-2.14.4]]). The symptom page:
[[consumer-slow-on-a-sparse-stream]].


## Keys are subjects, and nothing escapes them for you

A key is a subject token path under `$KV.<bucket>.`, so a key containing a space, or a dot meaning
something other than a separator, cannot be stored as written — and **the server offers no
escaping** (source: [[s-adr-54-kv-codecs]], **Proposed**). The proposed answer is entirely
client-side: key and value codecs wrapped around a normal bucket handle, with `Base64Codec`
(`"Acme Inc.contact"` → `"QWNtZSBJbmMuY29udGFjdA=="`) and `PathCodec`
(`user/profile/settings` → `user.profile.settings`) as built-ins.

Two consequences an operator meets before the design does:

- **Encoded keys are what `nats kv ls` shows**, not the application's keys — and a watcher written
  against a raw key matches nothing, because a codec encodes the filter's wildcards too unless it
  deliberately does not.
- **A value codec is client-side encryption**: the server stores ciphertext, so compression and any
  server-side reading of values stop being meaningful. It is not the same thing as JetStream
  encryption at rest.

**Key naming is decided before the first `Put`.** Changing it later is a rewrite of the bucket.


## A lock or a lease, built from `create` and a TTL

There is **no lock primitive**, and no source publishes a recipe — but every part of one is a
documented operation, and they compose in exactly one way:

| step | operation | why it is safe |
|---|---|---|
| **acquire** | `create <bucket> <lock-key> <holder-id> --ttl <lease>` | `create` is CAS against revision 0, so **exactly one caller wins**; the loser gets an error, not a queue slot |
| **hold / renew** | `update <bucket> <lock-key> <holder-id> <revision>` | CAS against the revision you hold, so a holder that was superseded cannot renew |
| **release** | `delete` (or `purge`) the key | leaves a marker a watcher sees |
| **expire** | the per-key TTL fires on its own | the server removes the key with reason `MaxAge`; nothing has to be running to clean up |

(sources: [[s-docs-kv-history-and-revisions]] for the CAS semantics,
[[s-docs-kv-ttl-and-limits]] for the per-key TTL and its marker, [[s-adr-48-kv-ttl]] for what the TTL
spec allows.)

**What this is not.** Being explicit matters more here than the recipe:

- **It is a lease, not a mutual-exclusion guarantee.** The holder's TTL can expire while its work is
  still running — the server does not know what the holder is doing. Anything the lock protects must
  still be safe if two holders overlap briefly, exactly as with [[priority-groups]]' pinned client.
- **Renewal is the hard part, and the `put` trap is lethal here.** A renewal written with `put`
  instead of `update` silently drops the TTL and the lock **never expires again**
  ([[s-docs-kv-ttl-and-limits]]). On a lock bucket that is an outage, not a bug report.
- **There is no fencing token beyond the revision.** The revision is bucket-wide and monotonic, so it
  works as one — but nothing downstream checks it for you.
- **A waiter has to watch or poll.** `create` fails immediately; there is no blocking acquire. A
  watcher on the lock key ([[s-docs-kv-watching]]) is the event-driven form, and it inherits the
  watcher costs on [[kv-watchers-stall-the-cluster]].
- **Per-key TTL needs 2.11+** and limit markers enabled on the bucket first.

No public source states this composition end to end; the pieces are each sourced above and the
composition is this wiki's, which is why the caveats are spelled out rather than the recipe polished.

## When a bucket is the wrong tool

A bucket is a stream with a key-value face, and every limit of the stream shows through. Reach for
something else when:

- **You need read-after-write.** There is none — see *There is no read-after-write consistency*
  above. A `put` followed immediately by a `get` on another connection can return the old value.
- **Values are large.** They are capped by `max_msg_size` and meant to be small; "large values belong
  in the Object Store" ([[object-store]], source: [[s-docs-kv-ttl-and-limits]]). The boundary runs
  the other way too, and it is the *history* that decides it: the object store "keeps the current
  `ObjectInfo`, not the trail of edits that produced it", so a re-put replaces the metadata and
  nothing keeps the old version. If you need versions of a value, it is a KV key however large it
  feels; if you need bytes and only ever the latest, it is an object however small
  (source: [[s-docs-object-store-metadata-and-links]]). This is not a gap waiting to be filled:
  ADR-20 lists **"versioning and revisions"** among the object store's *possible future features*,
  i.e. not implemented (source: [[s-adr-20-object-store]], [[object-store]]).
- **You need an audit trail.** History is per key, bounded at **64** revisions, and trimmed silently.
  "It isn't an audit log of the whole bucket" (source: [[s-docs-kv-history-and-revisions]]). Use a
  [[stream]] with the retention you actually need.
- **You need writes to keep succeeding under pressure.** A bucket is `discard: new`: at its cap it
  **rejects the writer**. That is the right behaviour for a config store and the wrong one for
  telemetry.
- **Deleting must actually delete.** A delete keeps every prior revision within the history depth;
  only a purge removes them (source: [[s-docs-kv-under-the-hood]]).
- **Many clients each watch a key.** The cost is consumer churn, not key count — see
  [[kv-watchers-stall-the-cluster]].
- **Keys are not legal subject tokens.** Nothing escapes them for you; see *Keys are subjects* below.

## Sharing a bucket with another account

There is no KV-specific sharing mechanism. Because a bucket **is** the stream `KV_<bucket>`, the two
routes are the JetStream ones, and both are in [[cross-account-sharing]]:

- **import the owning account's JetStream API** as a service export and address it with an API
  prefix — one user then manages assets in the other account;
- **mirror or source `KV_<bucket>`** with an `external` block — the second account gets a *copy*,
  with the mirror's lag, and a write there does not reach the original bucket.

**No docs page covers either**, and the public question — "a single account owns a KV store, and I'd
like to share access to this KV store with other accounts, ideally with some restrictions" — has had
**no reply since 2025-06-29** (source: [[s-gh-7017-kv-across-accounts]]). The only public answer is a
single line from a maintainer on the equivalent stream question: "You should be able to import the
foreign account jetstream API and manage it using the API prefix options in clients and CLI"
(source: [[s-gh-5606-cross-account-jetstream]]).

The restrictions half is the part with no public answer at all. A service export of `$JS.API.>` hands
over the account's whole JetStream control plane, not one bucket; narrowing it to a single
`KV_<bucket>` is not documented and this wiki has not verified it.

**One narrow route is at least specified, and it is read-only.** ADR-31 gives Direct Get a second,
*Subject-Appended* request subject — **`$JS.API.DIRECT.GET.<stream>.>`**, where the tokens after the
stream name *are* the `last_by_subj` — and says it exists for exactly this: "so that environments may
choose to apply subject-based interest restrictions (user permissions within an account and/or
cross-account export/import grants) such that only specific subjects in stream may be read"
(source: [[s-adr-31-direct-get]]). For a bucket that makes per-key read access expressible as an
ordinary subject grant on `$JS.API.DIRECT.GET.KV_<bucket>.<key…>` — see [[subject-permissions]].
Sending a payload to that subject "is an error (408)". Two caveats: it covers **reads only**, leaving
writes and the control plane where they were, and **this wiki has not verified the grant end to end**
against a running server.

## Across a leafnode or a domain, `$KV.>` is its own subject space

A bucket does not live under `$JS.API.>`, and that has consequences no KV documentation states. The
server's own deny list for a leafnode that does not extend JetStream is
**`["$JS.API.>", "$KV.>", "$OBJ.>"]`** (`denyAllClientJs`, `jetstream_api.go:323–324` at v2.14.6) —
three separate entries, because `$KV` and `$OBJ` are independent subject spaces
(source: [[s-nats-server-leafnode-js-domains]]). So:

- **Any deny or allow list that means to cover KV must name `$KV.>` itself.** Writing `$JS.API.>` and
  stopping there covers the control plane and leaves the data path open — or, on a leafnode, denies
  the API while the bucket's own subjects were never in question. See [[subject-permissions]].
- **Addressing a bucket in another JetStream domain needs the mapping the server installs for you**:
  `$JS.<domain>.API.$KV.>` → `$KV.>`, added to every non-system account when `domain` is set. The
  source's comment on that mapping table is "This set of mappings is very very very ugly", and it says
  why: because `$KV` and `$OBJ` were made independent rather than living under `$JS.API`.
- **Over a leafnode where the domains differ, `$KV.>` is denied in both directions** unless you
  address the far side by domain (`nats --js-domain <name> …`). Matching domains alone extend nothing.

See [[jetstream-domain]] and [[streams-not-visible-across-a-leafnode]].


## Version notes

| server | what arrived |
|---|---|
| **2.6.0** | the JetStream features KV is built on |
| **2.10.0** | sourced buckets, read-replica mirror buckets, compression, bucket metadata |
| **2.11.0** | max-age limit markers, per-key TTL; non-direct gets removed from the spec |

### The 2.10 line

- 2.10.0's largest JetStream item is a KV item: "significant optimisations and reduced memory impact
  for replicated streams with a large number of interior deletes (common in large KVs)" (#4070,
  #4071, #4075, #4284, #4520, #4553) (source: [[s-relnotes-2.10]]).
- **2.10.3** fixed "Stream / KV lookups fail after decreasing history size" (#4656) — lowering
  `max_msgs_per_subject` on a live bucket was unsafe before it.
- **2.10.19 broke compare-and-swap on R1 buckets; 2.10.20 fixed it** ("Fix regression in KV CAS
  operations on R=1 replicas introduced in v2.10.19", #5841).
- 2.10.5: "resiliency when doing lots of conditional updates to a KV and restarting servers" (#4764);
  2.10.28: purge performance "particularly for KV `PurgeDeletes` calls" (#6801).


### The 2.11 line

- **2.11.0** fixed "issues where KV creates/updates to a key during leader changes could desync the
  stream" — a new leader now answers only once up to date with its Raft log (#6194, #6485, #6518)
  (source: [[s-relnotes-2.11]]). Per-key TTL and limit markers ride on the same release's
  per-message TTL ([[message-ttl]]).
- **2.11.2**: KV `PurgeDeletes` faster (#6801, #6825 — the 2.10.28 backport); delete markers placed
  for TTL expiry (#6741). **2.11.7**: a purge with markers configured no longer leaves "a redundant
  extra delete marker" (#7026).


### The 2.12 line

- **2.12.7 – 2.12.10 are unsafe for buckets**: every KV bucket sets `max_msgs_per_subject`, and
  those releases carry "stale subject state tracking which could manifest in `Message Not Found`
  errors when a max messages per subject limit is configured" — fixed in 2.12.11 (#8285), never
  present on 2.14 (source: [[s-relnotes-2.12]]).
- **2.12.10**: the per-subject state's last block stored correctly with a limit of 1 (#8254);
  purges consistent between file and memory stores (#8241). **2.12.12**: `MultiLastSeqs` no longer
  reorders the configured subjects (#8315); the memory store no longer overcounts pending for
  `last_per_subject` (#8313).


## To verify

- ~~**Why a KV watcher would *miss* updates**~~ — **answered, and the answer is client-side.** The
  docs name it as "the most common watch bug": a reader that treats the end-of-initial-data signal as
  end-of-stream stops at the snapshot boundary and never sees a live change
  (source: [[s-docs-kv-watching]], now in *Watch, history and listing keys* above). That is a
  watcher that appears to miss every update while the server did nothing wrong. The earlier note
  stands on its own terms — nobody has publicly reported a *server-side* missed update, and the
  gap-detection mechanism ADR-8 gives ([[ordered-consumer]]) remains a candidate cause with no report
  behind it. The KV-watcher failure people do report is [[kv-watchers-stall-the-cluster]].
- Whether a **mirror on file storage** is materially slower than on memory storage (Q76) is **still
  not covered**. The `learn/key-value` chapter was read end to end on 2026-08-31 and mentions mirrors
  exactly once, in its closing recap, with no performance claim of any kind. No source in `raw/`
  states one.
- **The server-side default for `subject_delete_marker_ttl`** is still unstated. `ttl-and-limits.md`
  always passes `--marker-ttl` explicitly and never says what happens without it — see the same open
  item on [[message-ttl]].

## What a bucket costs on disk

A bucket is a stream with `max_msgs_per_subject` set to its history, and that single fact fixes its
on-disk shape (source: [[s-nats-server-filestore-layout]], `nats-server 2.14.6`):

- **Block size is 4MB**, always — `max_msgs_per_subject` takes the `defaultKVBlockSize` branch of
  `autoTuneFileStorageBlockSize` (`stream.go:1412–1443`) regardless of how small the bucket is.
  Budget 4MB of slack per bucket: the newest block is never compacted, so a small idle bucket can
  hold several megabytes on disk while reporting a few hundred kilobytes.
- **Each key costs `len($KV.<bucket>.<key>) + 4` bytes in `index.db`**, the stream's full-state
  snapshot, rewritten every two minutes plus jitter. Measured at 40,000 keys: a 708,987-byte
  `index.db`. A bucket with a million keys is tens of megabytes of `index.db` per replica, rewritten
  on that cadence — this is the cost that scales with **key count**, not with value size.
- **Each revision costs `30 + len(subject)` bytes** beyond the value, and `4 + len(headers)` more
  for the headers KV puts on every entry.

Above **1,000,000** subjects the periodic `index.db` write is skipped entirely
(`highCardinalityThreshold`), so a very large bucket stops getting one.

See [[filestore-layout]] for the mechanism and [[jetstream-sizing]] for sizing a volume from it.


## Related

[[stream]] · [[consumer]] · [[ordered-consumer]] · [[message-ttl]] · [[direct-get]] ·
[[object-store]] · [[replicas]] · [[kv-watchers-stall-the-cluster]] · [[cross-account-sharing]] ·
[[account]] · [[mirrors-and-sources]]

## Sources

[[s-adr-8-key-value-store]] · [[s-adr-43-per-message-ttl]] · [[s-adr-17-ordered-consumer]] ·
[[s-docs-stream-config]] · [[s-gh-7017-kv-across-accounts]] · [[s-gh-5606-cross-account-jetstream]] ·
[[s-gh-6746-watch-many-keys]] · [[s-gh-5243-kv-watchers-at-scale]] · [[s-adr-48-kv-ttl]] · [[s-adr-57-kv-subject-transforms]] · [[s-adr-54-kv-codecs]] · [[s-nats-server-filestore-layout]] ·
[[s-docs-kv-under-the-hood]] · [[s-docs-kv-watching]] · [[s-docs-kv-history-and-revisions]] ·
[[s-docs-kv-ttl-and-limits]] · [[s-docs-kv-your-first-bucket]] ·
[[s-docs-object-store-watching-and-listing]] · [[s-docs-object-store-metadata-and-links]] ·
[[s-adr-20-object-store]] · [[s-adr-31-direct-get]] · [[s-docs-get-direct]] ·
[[s-docs-mirrors-and-sources]] · [[s-gh-6328-jetstream-behind-gateways]] ·
[[s-nats-server-leafnode-js-domains]] · [[s-nats-server-mirrors-observed]] · [[s-nats-go-kv-object-mirror]] · [[s-gh-8417-kv-mirror-file-vs-memory]] · [[s-nats-server-mirror]] · [[s-relnotes-2.14.4]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]]
