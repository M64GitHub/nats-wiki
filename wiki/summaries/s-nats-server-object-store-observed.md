---
title: "nats-server v2.14.6 — the object store, run rather than read"
type: summary
area: [objectstore, jetstream, monitoring]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/object-store-observed-v2.14.6.md
author: nats-io/nats-server contributors (the binary); this wiki (the experiments)
article: "Nine experiments run on the v2.14.6 binary with nats CLI 0.4.0"
date: 2026-08-31
version: "2.14.6"
tags: [objectstore, chunk-size, max_payload, Nats-Rollup, soft-delete, last_per_subject, "$JS.API", mtime, 10109]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — the object store, run rather than read

Run to settle question-bank row **Q75** — *"Why is listing an object-store bucket slow (or timing
out) while uploads run?"* — whose source thread ([[s-gh-6836-object-store-list-slow]]) has no answer
from anyone, and to put numbers on the claims `learn/object-store` states without them. Nine
experiments on **nats-server v2.14.6** with **nats CLI 0.4.0**, darwin/arm64, over loopback.

## Key claims

**The backing stream matched the docs field for field.** `nats stream info OBJ_INVOICES --json`
returned exactly the config `learn/object-store/under-the-hood.md` prints: subjects
`$O.INVOICES.C.>` and `$O.INVOICES.M.>`, `discard: "new"`, `allow_rollup_hdrs: true`,
`allow_direct: true`, `max_age: 0`, `max_bytes: -1`, `storage: "file"`, `num_replicas: 1`. Two fields
the docs omit: **`duplicate_window` is 2m** (the stream default is not suppressed for object buckets)
and `max_msgs_per_subject` is `-1`.

**The default chunk size is exactly 128 KiB.** A 3,145,728-byte file landed **24 chunks** —
3145728/24 = 131072. At `--chunk-size 65536` it landed 48; at `524288`, 6. A 200 MiB object landed
**1,600 chunks plus one metadata message** (`nats stream info`: 1601 msgs).

**A chunk size above `max_payload` fails client-side, and costs nothing.** `--chunk-size 2097152`
against `max_payload 1048576` returned `nats: error: nats: maximum payload exceeded` — the Go
client's `ErrMaxPayload`, raised from the `INFO` the server advertised. **The previously stored
object survived** (`Chunks: 6` unchanged) and `nats stream subjects` showed **no orphan chunks**:
seven messages, one metadata subject and one chunk subject.

**All chunks of one put share one subject.** `$O.<bucket>.C.<nuid>` carried a count of 6 for a
six-chunk object — it is one subject per *put*, not per chunk. The metadata subject is the object
name in **padded** base64url: `$O.INVOICES.M.aW52b2ljZS1vcmRfOXgzbS5wZGY=` decodes to
`invoice-ord_9x3m.pdf`.

**The metadata message, raw:**

```
Headers:
  Nats-Rollup: sub

{"name":"invoice-ord_9x3m.pdf","options":{"max_chunk_size":524288},"bucket":"INVOICES",
 "nuid":"2YrBblmFpoTLsXRGbLyeZo","size":3145728,"mtime":"0001-01-01T00:00:00Z","chunks":6,
 "digest":"SHA-256=gjJlkc6IUi_HXQeYNBCoMH_S1O7w2K6qTcHk8-gupUY="}
```

Four things at once: `Nats-Rollup: sub` is present; the digest is stored as `SHA-256=<base64url>`
while `nats object info` renders it as hex; **`mtime` is the zero time `0001-01-01T00:00:00Z`** — the
observable behind ADR-20's "modified time is never stored", with the printed `Modification Time`
coming from the *message* timestamp; and `options.max_chunk_size` is stored per object, which is why
`UpdateMeta` cannot change it.

**The soft-delete tombstone** carried `size: 0`, `chunks: 0`, `deleted: true` and **no `digest` field
at all** (absent, not emptied). Stream state went `7 msgs / 3146470 bytes` → `1 msg / 291 bytes`;
`nats object get` then returned `nats: error: nats: object not found` (exit 1) and `nats object ls`
returned `No entries found` (exit **0**).

**Disk reclamation on delete is 98.4 % synchronous.** A fresh bucket, one 200 MiB object, then a
delete, sampling `du -sk` on the stream directory:

| moment | `du` | stream state |
|---|---|---|
| after the 200 MiB put | 204,912 KB | 1601 msgs / 209,819,520 bytes |
| delete + 0 s | **3,212 KB** | 1 msg / 260 bytes |
| delete + 2/10/30/60 s | 3,212 KB | 1 msg / 260 bytes |

What lingers is **one trailing block** (a single 3,279,785-byte `26.blk`), not a slow drain of the
object. On a second bucket the residue was two blocks, 13,460 KB, still there at +5 s and down to
4,760 KB about four minutes later with no other activity. Separately: 200 MiB of payload occupied
204,912 KB on disk — about **2.4 % overhead** at the 128 KiB default.

**`nats object ls` is four `$JS.API` calls, one of them an ephemeral consumer.** Traced with
`nats sub '$JS.API.>'`:

1. `$JS.API.STREAM.INFO.OBJ_LISTLAB`
2. `$JS.API.DIRECT.GET.OBJ_LISTLAB.$O.LISTLAB.M.>`
3. `$JS.API.CONSUMER.CREATE.…` with
   `{"deliver_policy":"last_per_subject","ack_policy":"none","filter_subject":"$O.LISTLAB.M.>","flow_control":true,"idle_heartbeat":5000000000,"num_replicas":1,"mem_storage":true}`
4. `$JS.API.CONSUMER.DELETE.…`

So **a list creates and destroys a `last_per_subject` push consumer on every call**, filtered to the
metadata subject space. It never touches `$O.<bucket>.C.>`.

**Q75, measured.** Idle, list latency barely depends on object count: 200 objects took 0.027–0.034 s,
**5,000 objects took 0.044–0.046 s** — 25× the objects for 1.6× the time. Under a sustained upload
into one bucket:

| command | idle | during upload |
|---|---|---|
| `nats rtt` (core NATS) | 0.081 s | 0.084–0.087 s |
| `nats stream info` (the written stream) | 0.028 s | 0.037–0.040 s |
| `nats stream info` (an unrelated stream) | 0.028 s | 0.037–0.039 s |
| `nats object ls` (an unrelated bucket) | 0.044–0.045 s | 0.056–0.057 s |
| `nats object ls` (**the written bucket**) | 0.027–0.034 s | **0.043–0.187 s** |

Twelve consecutive lists on the written bucket during the upload:
`0.042, 0.029, 0.090, 0.119, 0.036, 0.187, 0.132, 0.059, 0.104, 0.112, 0.056, 0.052` s.

**Core NATS is untouched** (+4 %). Every JetStream call pays a flat **server-wide tax of ~+27–35 %**
while the server is writing — an unrelated stream pays exactly as much as the busy one. On top of
that, and **only on the bucket being written to**, list latency becomes 2× to **6.9×** the idle floor
and highly variable. That two-part shape reproduces the reporter's 4–6× on loopback with no network
involved.

**A negative result on the timeout.** `--timeout` does not bound the whole list:
`nats object ls BIG --timeout=10ms` and `--timeout=1ms` both **completed successfully**. It bounds
the individual request/reply round trips. The reporter's `>5 s` matches the CLI's `5s` default.

**Bucket names, exit codes, sealing.** `has.dot`, `has space` and `has>gt` were each rejected with
`nats: error: nats: invalid object-store name` — a **client-side** check (no `err_code`), consistent
with ADR-20's `A-Z a-z 0-9 - _`. An empty bucket list exits **0**; a missing object's get and info
each exit **1** with `nats: error: nats: object not found`. A put into a sealed bucket fails with
`code=400 err_code=10109 description=invalid operation on sealed stream` — the **stream's** error,
not an object-store-specific one.

## Practical takeaways

- **The answer to "why is my `ls` slow" is not "too many objects".** Object count is nearly free;
  concurrent writes to the same bucket are what costs, and the effect has two layers — a small
  server-wide one and a larger, jittery same-stream one.
- Polling `list` on a bucket that is being written is the anti-pattern the numbers point at. A
  **watch** costs one long-lived consumer instead of one created and destroyed per poll.
- A soft delete does give the disk back promptly; size for one trailing block, not for the object.
- A chunk size over `max_payload` is a safe failure — nothing is written, nothing is lost.

## Notable quotes

Not applicable; this is a run, not a text. The verbatim output is in the raw file.

## Relevance to the wiki

Q75 had no public answer. This is the answer, with the mechanism and the numbers, and it is the
evidence base for [[object-store-list-is-slow]]. It also confirms on the running server every claim
[[object-store]] carried from ADR-20 alone, and corrects the docs' disk-reclamation pitfall from
qualitative alarm to a bounded, measured residue.

## Questions it answers

Q75.

## Pages touched

[[object-store]] · [[object-store-list-is-slow]] · [[filestore-layout]] · [[jetstream-sizing]] ·
[[js-api-subjects]] · [[defaults-and-limits]]

## Sources

`raw/nats-server-src/object-store-observed-v2.14.6.md` · [[s-gh-6836-object-store-list-slow]]
