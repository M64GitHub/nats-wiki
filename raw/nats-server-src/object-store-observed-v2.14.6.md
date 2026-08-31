<!-- source: run locally against nats-server v2.14.6 (`nats-server --version` -> v2.14.6) and
     nats CLI 0.4.0 · observed 2026-08-31 · configs and output verbatim below. -->

# Observed on nats-server v2.14.6 — the object store: chunking, rollup, soft delete, and why `ls` slows

Eight experiments, run to settle claims the `learn/object-store` chapter states without a number,
and to answer question-bank **Q75** ("why is listing an object-store bucket slow, or timing out,
while uploads run"), whose source thread — `nats-io/nats-server` discussion
[#6836](https://github.com/nats-io/nats-server/discussions/6836), opened 2025-04-25 — has one
comment, by the asker, and no reply from anyone else.

Every command and every line of output below was run on **nats-server v2.14.6** with **nats CLI
0.4.0** on darwin/arm64, 2026-08-31, over loopback.

### Setup

```
port: 4241
http: 8241
server_name: objlab
jetstream {
  store_dir: "<scratch>/objlab/store"
  max_memory_store: 1GB
  max_file_store: 20GB
}
```

`curl -s localhost:8241/varz` reports `version 2.14.6`, `max_payload 1048576`. The server log's
JetStream banner reads `API Level: 4`, `Strict: true`.

---

## 1 · The stream a bucket is, verbatim

```
nats object add INVOICES --description "Invoice PDFs"
```

```
          Bucket Name: INVOICES
          Description: Invoice PDFs
             Replicas: 1
                  TTL: unlimited
               Sealed: false
                 Size: 0 B
  Maximum Bucket Size: unlimited
              Storage: File
   Backing Store Kind: JetStream
     JetStream Stream: OBJ_INVOICES
```

`nats stream info OBJ_INVOICES --json`, `config` only:

```json
{
 "name": "OBJ_INVOICES",
 "description": "Invoice PDFs",
 "subjects": ["$O.INVOICES.C.>", "$O.INVOICES.M.>"],
 "retention": "limits",
 "max_consumers": -1,
 "max_msgs_per_subject": -1,
 "max_msgs": -1,
 "max_bytes": -1,
 "max_age": 0,
 "max_msg_size": -1,
 "storage": "file",
 "discard": "new",
 "num_replicas": 1,
 "duplicate_window": 120000000000,
 "sealed": false,
 "deny_delete": false,
 "deny_purge": false,
 "allow_rollup_hdrs": true,
 "allow_direct": true,
 "mirror_direct": false,
 "metadata": {"_nats.level": "4", "_nats.req.level": "0", "_nats.ver": "2.14.6"},
 "consumer_limits": {}
}
```

This matches the config `learn/object-store/under-the-hood.md` prints, field for field, on every
field that page names. Two fields the page does not show: **`duplicate_window` is 2m** (the stream
default, not suppressed for object buckets) and **`max_msgs_per_subject: -1`** — the rollup, not a
per-subject limit, is what keeps one metadata message per object.

## 2 · The default chunk size is exactly 128 KiB, and `--chunk-size` moves it

A 3,145,728-byte (3 MiB) file of `/dev/urandom`:

```
nats object put INVOICES invoice-ord_9x3m.pdf --no-progress
nats object info INVOICES invoice-ord_9x3m.pdf
```

```
               Size: 3.0 MiB
  Modification Time: 2026-08-31 23:17:16
             Chunks: 24
             Digest: SHA-256 82326591ce88522fc75d07983410a8307fd2d4eef0d8aeaa4dc1e4f3e82ea546
```

3145728 / 24 = **131072 bytes = 128 KiB exactly**. `chunking.md` says "roughly 24 chunks"; it is
exactly 24, because the default is `128 * 1024` and the file is a whole multiple of it.

| `--chunk-size` | chunks for the same 3 MiB file |
|---|---|
| (unset) | 24 |
| `65536` | 48 |
| `524288` | 6 |

A 200 MiB object at the default lands **1,600 chunks** (`200 * 1024 / 128`), plus one metadata
message: `nats stream info` reports **1601 msgs**.

## 3 · A chunk size above `max_payload` fails the put — before anything is written

```
nats object put INVOICES invoice-ord_9x3m.pdf --chunk-size 2097152 --force --no-progress
```

```
nats: error: nats: maximum payload exceeded
```

That string is the **Go client's** `nats.ErrMaxPayload`, raised from the `max_payload` the server
advertised in its `INFO`; the message never reaches the server. Two consequences, both checked:

- The **previously stored object survives intact.** `nats object info` still reported `Chunks: 6`
  from the preceding `--chunk-size 524288` put.
- **No orphan chunks are left.** `nats stream subjects OBJ_INVOICES` afterwards:

```
│ Subject                                    │ Count │
│ $O.INVOICES.M.aW52b2ljZS1vcmRfOXgzbS5wZGY= │ 1     │
│ $O.INVOICES.C.2YrBblmFpoTLsXRGbLyeZo       │ 6     │
```

Seven messages total. `chunking.md` says the *server* rejects the oversized message; on this path
the client rejects it first, which is why the put costs nothing at all.

Note the two subject shapes: **all chunks of one put share a single subject**,
`$O.<bucket>.C.<nuid>` — not one subject per chunk. The metadata subject is the object name in
padded base64url: `aW52b2ljZS1vcmRfOXgzbS5wZGY=` decodes to `invoice-ord_9x3m.pdf`.

## 4 · The metadata message, raw — rollup header, ObjectInfo JSON, and a zero `mtime`

```
nats stream get OBJ_INVOICES --last-for '$O.INVOICES.M.aW52b2ljZS1vcmRfOXgzbS5wZGY='
```

```
Item: OBJ_INVOICES#81 received 2026-08-31 21:17:26.080035 +0000 UTC on Subject $O.INVOICES.M.aW52b2ljZS1vcmRfOXgzbS5wZGY=

Headers:
  Nats-Rollup: sub

{"name":"invoice-ord_9x3m.pdf","options":{"max_chunk_size":524288},"bucket":"INVOICES","nuid":"2YrBblmFpoTLsXRGbLyeZo","size":3145728,"mtime":"0001-01-01T00:00:00Z","chunks":6,"digest":"SHA-256=gjJlkc6IUi_HXQeYNBCoMH_S1O7w2K6qTcHk8-gupUY="}
```

Four things settled at once:

- **`Nats-Rollup: sub`** is on the metadata publish, as `under-the-hood.md` says.
- The digest is stored as **`SHA-256=<base64url>`** — `_` and `-` appear in the value — while
  `nats object info` renders it as `SHA-256 <hex>`. Same digest, two presentations.
- **`mtime` is the zero time `0001-01-01T00:00:00Z`.** The `Modification Time` the CLI prints comes
  from the *message* timestamp, not from the record. This is the observable confirmation of
  ADR-20's "modified time is never stored".
- **`options.max_chunk_size` is stored per object**, which is why `UpdateMeta` cannot change it.

## 5 · Soft delete: the tombstone, verbatim

```
nats object del INVOICES invoice-ord_9x3m.pdf --force
nats stream get OBJ_INVOICES --last-for '$O.INVOICES.M.aW52b2ljZS1vcmRfOXgzbS5wZGY='
```

```
Headers:
  Nats-Rollup: sub

{"name":"invoice-ord_9x3m.pdf","options":{"max_chunk_size":524288},"bucket":"INVOICES","nuid":"2YrBblmFpoTLsXRGbLyeZo","size":0,"mtime":"0001-01-01T00:00:00Z","chunks":0,"deleted":true}
```

`size: 0`, `chunks: 0`, `deleted: true`, and the **`digest` field is gone entirely** (not emptied —
absent). Stream state went `7 msgs / 3146470 bytes` -> `1 msg / 291 bytes`, and
`nats stream subjects` showed the chunk subject gone. Afterwards:

```
nats object get INVOICES invoice-ord_9x3m.pdf   -> nats: error: nats: object not found   (exit 1)
nats object ls  INVOICES                        -> No entries found                       (exit 0)
```

## 6 · How much disk a soft delete actually reclaims, and when

Fresh bucket `RECLAIM`, one 200 MiB object at the default chunk size, then deleted. `du -sk` on
`<store>/jetstream/$G/streams/OBJ_RECLAIM`:

| moment | `du` | stream state |
|---|---|---|
| empty bucket | 8 KB | — |
| after the 200 MiB put | **204,912 KB** | 1601 msgs / 209,819,520 bytes |
| delete + 0 s | **3,212 KB** | 1 msg / 260 bytes |
| delete + 2 s | 3,212 KB | 1 msg / 260 bytes |
| delete + 10 s | 3,212 KB | 1 msg / 260 bytes |
| delete + 30 s | 3,212 KB | 1 msg / 260 bytes |
| delete + 60 s | 3,212 KB | 1 msg / 260 bytes |

`ls msgs/` afterwards: a single `26.blk` of 3,279,785 bytes.

So **98.4 % of the bytes come back synchronously with the delete call**, and what lingers is one
trailing block — not a slow drain of the whole object. `under-the-hood.md`'s pitfall ("the on-disk
space is reclaimed as the stream cleans up, not synchronously at the call") is directionally right
and quantitatively misleading: the residue is bounded by one block, not by the object.

The residue does eventually go. On the earlier `OBJ_INVOICES` bucket the same shape held —
207,184 KB after the put, 13,460 KB immediately after the delete (two blocks, 8,263,327 and
4,855,360 bytes) still 13,460 KB at +5 s, and **4,760 KB when sampled again about four minutes
later**, with no other activity on that stream.

Also worth recording: 200 MiB of payload occupied 204,912 KB on disk — about **2.4 % overhead** at
the 128 KiB default chunk size, because there are only 1,601 messages to carry it.

## 7 · What `nats object ls` actually does on the wire

`nats sub '$JS.API.>'` while one `nats object ls LISTLAB` runs. Four requests, in order:

```
[#1] $JS.API.STREAM.INFO.OBJ_LISTLAB                              (nil body)
[#2] $JS.API.DIRECT.GET.OBJ_LISTLAB.$O.LISTLAB.M.>                (nil body)
[#3] $JS.API.CONSUMER.CREATE.OBJ_LISTLAB.44l2NbiT.$O.LISTLAB.M.>
     {"stream_name":"OBJ_LISTLAB","config":{"deliver_policy":"last_per_subject",
      "ack_policy":"none","ack_wait":79200000000000,"max_deliver":1,
      "filter_subject":"$O.LISTLAB.M.>","replay_policy":"instant","flow_control":true,
      "idle_heartbeat":5000000000,"deliver_subject":"_INBOX...","num_replicas":1,
      "mem_storage":true}}
[#4] $JS.API.CONSUMER.DELETE.OBJ_LISTLAB.44l2NbiT                 (nil body)
```

A list is therefore **an ephemeral `last_per_subject` push consumer, created and destroyed on every
call**, filtered to the metadata subject space, with an in-memory consumer state
(`mem_storage: true`) and `ack_policy: none`. It never touches `$O.<bucket>.C.>`.

## 8 · Q75 — listing while uploads run, measured

Two buckets: `LISTLAB` with 200 small objects, and `BIG` with 5,000 metadata subjects. The load is
a loop of `nats object put LISTLAB huge.bin --name huge-loop.bin --force` with a 500 MiB file
(4,000 chunks per put; ~0.37 s per put on loopback, ~1.3 GB/s).

**Idle, and the object count barely matters:**

| bucket | objects | idle `nats object ls` |
|---|---|---|
| `LISTLAB` | 200 | 0.027 – 0.034 s |
| `BIG` | 5,000 | 0.044 – 0.046 s |

25× the objects costs 1.6× the time. **List latency is not driven by how many objects a bucket
holds.**

**During a sustained upload into `LISTLAB`:**

| command | idle | during upload |
|---|---|---|
| `nats rtt` (core NATS) | 0.081 s | 0.084 – 0.087 s |
| `nats stream info OBJ_LISTLAB` (the stream being written) | 0.028 s | 0.037 – 0.040 s |
| `nats stream info OBJ_INVOICES` (an unrelated stream) | 0.028 s | 0.037 – 0.039 s |
| `nats object ls BIG` (an unrelated bucket) | 0.044 – 0.045 s | 0.056 – 0.057 s |
| `nats object ls LISTLAB` (the bucket being written) | 0.027 – 0.034 s | **0.043 – 0.187 s** |

A longer run of twelve consecutive lists on `LISTLAB` during the upload:
`0.042, 0.029, 0.090, 0.119, 0.036, 0.187, 0.132, 0.059, 0.104, 0.112, 0.056, 0.052` s.

Reading the table: **core NATS is untouched** (+4 %). Every JetStream call pays a flat, uniform
**server-wide tax** of roughly +27 – 35 % while the server is writing — an unrelated stream's
`stream info` and an unrelated bucket's `ls` slow by the same amount as the busy one's. On top of
that, and only on **the bucket being written to**, list latency becomes **2× to 6.9× the idle
figure and highly variable** — the worst sample, 0.187 s, is 6.9× the 0.027 s floor.

That two-part shape reproduces the reporter's numbers in #6836 (0.3–0.5 s idle -> ~2 s under
upload, i.e. 4–6×), on loopback, with no network involved. Nothing timed out here; the reporter's
`>5 s` is the `nats` CLI's `--timeout` default of `5s`.

**One negative result worth recording.** `--timeout` does not bound the whole operation:
`nats object ls BIG --timeout=10ms` and `nats object ls LISTLAB --timeout=1ms` both **completed
successfully**, printing the full table. It bounds the individual request/reply round trips.

## 9 · Bucket names, empty buckets, missing objects, sealing

Bucket name charset, checked by attempting each:

```
nats object add good-name_1   -> created
nats object add has.dot       -> nats: error: nats: invalid object-store name
nats object add "has space"   -> nats: error: nats: invalid object-store name
nats object add "has>gt"      -> nats: error: nats: invalid object-store name
```

The rejection is client-side (`nats:` prefix, no `API error` / `err_code`), consistent with ADR-20's
`restricted-term` = `A-Z a-z 0-9 - _`.

```
nats object ls   <empty bucket>          -> "No entries found"                (exit 0)
nats object get  <missing object>        -> nats: error: nats: object not found (exit 1)
nats object info <missing object>        -> nats: error: nats: object not found (exit 1)
```

An empty bucket is exit **0**; a missing object is exit **1**. `learn/object-store` says an empty
bucket is "not an error" and this is the exit code that backs it.

Sealing:

```
nats object seal LISTLAB --force   -> "LISTLAB has been sealed",  Sealed: true
nats object put  LISTLAB huge.bin --name after-seal.bin --force
  -> nats: error: nats: API error: code=400 err_code=10109 description=invalid operation on sealed stream
```

A sealed bucket rejects puts with the **stream's** error, `10109 JSStreamSealedErr`, not an
object-store-specific one.

## What was not run

- Anything involving **links** (`AddLink`, `AddBucketLink`, `ErrCantGetBucket`) or **`UpdateMeta`**.
  The `nats` CLI has no `link` subcommand (`nats object --help` lists only
  `add, edit, put, del, get, info, ls, seal, watch`) and no `update-meta`, so those claims in
  `metadata-and-links.md` remain client-library claims, untested here.
- `ErrDigestMismatch` on get. Producing one requires corrupting a stored chunk behind the server's
  back; not attempted.
- Anything clustered. `num_replicas` was 1 throughout.
