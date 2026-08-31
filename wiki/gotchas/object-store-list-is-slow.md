---
title: "Listing an object-store bucket is slow while uploads run"
type: gotcha
area: [objectstore, jetstream, monitoring]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [objectstore, list, watch, last_per_subject, ephemeral-consumers, timeout, measured]
aliases: ["nats obj ls slow", "object store list timeout", "object listing times out", "nats object ls slow during upload"]
sources: [s-gh-6836-object-store-list-slow, s-nats-server-object-store-observed, s-docs-object-store-watching-and-listing, s-docs-object-store-under-the-hood, s-docs-object-store-chunking]
created: 2026-08-31
updated: 2026-08-31
---

# Listing an object-store bucket is slow while uploads run

`nats object ls` on a quiet bucket returns in a fraction of a second. Start uploading into the same
bucket and the same command takes several times as long, unpredictably, and sometimes hits the
client's timeout.

> **No public source answers this.** The only public report,
> [gh#6836](https://github.com/nats-io/nats-server/discussions/6836) (opened 2025-04-25), has one
> comment — the asker's own follow-up — and **no reply from anyone else** sixteen months later
> (source: [[s-gh-6836-object-store-list-slow]]). The docs page that covers listing says only that
> "a list is cheap: it reads metadata, never chunks" and never mentions concurrency (source:
> [[s-docs-object-store-watching-and-listing]]). Everything below the *Symptom* section was
> **measured on nats-server 2.14.6** rather than cited (source:
> [[s-nats-server-object-store-observed]]).

## Symptom

The reporter's numbers: `nats obj ls <bucket>` takes **0.3–0.5 s** normally, **~2 s** while an upload
into that bucket is running, and occasionally exceeds **5 s** and fails. Reproduced by the same
person with both the `nats` CLI and the Python SDK, so it is not one client library
(source: [[s-gh-6836-object-store-list-slow]]).

A second symptom travels with it: upload throughput sagging from ~3 MiB/s to 200–500 KiB/s, and
recovering after a while.

## Quick triage

```
nats object ls <bucket>                     # time it while the bucket is quiet
nats stream info OBJ_<bucket>               # a plain JS API call, for comparison
nats rtt                                    # core NATS, as a control
```

Run all three again during the upload. The **shape** of the three answers tells you which of the two
effects below you have, and whether the problem is JetStream at all.

## What a list actually does

Traced with `nats sub '$JS.API.>'`, one `nats object ls` is four JetStream API calls:

| # | subject |
|---|---|
| 1 | `$JS.API.STREAM.INFO.OBJ_<bucket>` |
| 2 | `$JS.API.DIRECT.GET.OBJ_<bucket>.$O.<bucket>.M.>` |
| 3 | `$JS.API.CONSUMER.CREATE.OBJ_<bucket>.<ephemeral>.$O.<bucket>.M.>` |
| 4 | `$JS.API.CONSUMER.DELETE.OBJ_<bucket>.<ephemeral>` |

The third carries
`{"deliver_policy":"last_per_subject","ack_policy":"none","filter_subject":"$O.<bucket>.M.>","flow_control":true,"idle_heartbeat":5000000000,"num_replicas":1,"mem_storage":true}`.

So **a list creates and destroys an ephemeral `last_per_subject` push consumer on every call**,
filtered to the metadata subject space. It never reads `$O.<bucket>.C.>` — the docs are right that no
object bytes move (source: [[s-docs-object-store-watching-and-listing]]). The cost is not the bytes;
it is a consumer created against a stream that is being written to hard.

## Causes, ranked

### 1 · Concurrent writes to the same bucket — the dominant effect

Two layers stack, and they are separable. Measured on 2.14.6 over loopback, with a sustained upload
into one bucket (source: [[s-nats-server-object-store-observed]]):

| command | idle | during upload | factor |
|---|---|---|---|
| `nats rtt` (core NATS) | 0.081 s | 0.084–0.087 s | ×1.04 |
| `nats stream info` — the written stream | 0.028 s | 0.037–0.040 s | ×1.4 |
| `nats stream info` — an **unrelated** stream | 0.028 s | 0.037–0.039 s | ×1.4 |
| `nats object ls` — an **unrelated** bucket | 0.044–0.045 s | 0.056–0.057 s | ×1.3 |
| `nats object ls` — **the written bucket** | 0.027–0.034 s | **0.043–0.187 s** | **×2 – ×6.9** |

- **Core NATS is untouched.** If your `nats rtt` also degrades, this page is the wrong page — look at
  [[slow-consumer-detected]] or the network.
- A **flat, server-wide JetStream tax of roughly +27–35 %** hits everything while the server is
  writing. An unrelated stream pays exactly as much as the busy one, so this half is not contention
  on your bucket.
- On top of that, and **only on the bucket being written to**, list latency runs 2× to 6.9× the idle
  floor and is highly variable. Twelve consecutive lists during one upload:
  `0.042, 0.029, 0.090, 0.119, 0.036, 0.187, 0.132, 0.059, 0.104, 0.112, 0.056, 0.052` s.

**How to confirm**: the two `stream info` rows. If the unrelated stream is as slow as the written one,
the server-wide half is what you are seeing; if only the written bucket's `ls` blows out, it is the
same-stream half.

**The fix** is to stop listing a bucket that is being written to. See *Prevention*.

### 2 · Polling `list` in a loop where a watch belongs

Every poll is a consumer created and destroyed. A **watch** is one long-lived consumer that delivers
metadata updates as they happen — the docs describe it as exactly this replacement: `analytics`
"keeps up with the bucket instead of polling list in a loop" (source:
[[s-docs-object-store-watching-and-listing]]). A watch on a bucket of 100 MB objects still carries
only `ObjectInfo` records; the bytes never ride it.

**How to confirm**: count how often your service lists. If the answer is "on a timer", this is your
cause regardless of what the latency numbers say.

### 3 · It is *not* the number of objects

The obvious hypothesis is wrong, and testing it is cheap. Idle, on 2.14.6:

| objects in bucket | idle `nats object ls` |
|---|---|
| 200 | 0.027–0.034 s |
| 5,000 | 0.044–0.046 s |

**25× the objects for 1.6× the time.** Growing a bucket does not meaningfully slow its listing; a
bucket that lists slowly is a bucket that is busy, not a bucket that is large (source:
[[s-nats-server-object-store-observed]]).

### 4 · A client-side deadline, not a server error

The reporter's `>5 s` failures match the `nats` CLI's `--timeout` default of `5s` exactly. But
`--timeout` does **not** bound the whole operation: `nats object ls --timeout=1ms` still completed
successfully against a 200-object bucket and a 5,000-object bucket. It bounds the individual
request/reply round trips — the `STREAM.INFO`, the direct get, the consumer create. So a "timeout"
here is one of those four calls missing its deadline while the JetStream API is busy, not the listing
itself running long.

**How to confirm**: raise `--timeout` and see whether the same call succeeds slowly. If it does, you
are queueing behind the JetStream API, not waiting on data.

## Prevention

- **Replace polling with a watch.** One consumer, no per-poll churn, metadata only.
- **Do not list on the hot path of an upload pipeline.** If a producer needs to know what it just
  wrote, it already knows.
- **Separate the busy bucket from the browsed one** where the workload allows. The unrelated-bucket
  numbers above show a browsing client pays only the flat server-wide tax when the writes land
  somewhere else.
- **Raise the client timeout before concluding anything is broken.** The failure the report describes
  is a deadline, and the work behind it completes.

## Explained by

[[object-store]] — the two subject spaces and why a list touches only one of them. [[consumer]] and
[[ordered-consumer]] — what the ephemeral `last_per_subject` consumer is.

## Related

[[object-store]] · [[kv-watchers-stall-the-cluster]] · [[jetstream-slows-as-consumers-grow]] ·
[[js-api-subjects]] · [[jetstream-sizing]]

## Sources

[[s-gh-6836-object-store-list-slow]] · [[s-nats-server-object-store-observed]] ·
[[s-docs-object-store-watching-and-listing]] · [[s-docs-object-store-under-the-hood]] ·
[[s-docs-object-store-chunking]]
