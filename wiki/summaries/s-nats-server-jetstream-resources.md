---
title: "nats-server v2.14.6 — JetStream storage limits, reservations and out-of-space"
type: summary
area: [jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/jetstream-resources-v2.14.6.md
author: nats-io/nats-server contributors
article: "server/jetstream.go, disk_avail.go, jetstream_api.go, jetstream_cluster.go, stream.go, filestore.go, opts.go, raft.go at v2.14.6"
date: 2026-08-31
version: "2.14.6"
tags: [max_file_store, diskAvailable, 10047, 10028, reserved_storage, out-of-space, OUT_OF_STORAGE, config-defaults]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — what "out of storage" actually means

Read to settle what the three "insufficient resources" errors compare, what the JetStream storage
default really is, and what the server does when a write genuinely fails for want of space. Every
claim is a line of `nats-server` at tag **v2.14.6**; the quoted ranges are in
`raw/nats-server-src/jetstream-resources-v2.14.6.md`.

## Key claims

### The dynamic storage limit is 75% of **free** space, computed once at startup

`dynJetStreamConfig` (`jetstream.go:2741`) sets `MaxStore` from `diskAvailable(jsc.StoreDir)` whenever
`max_file_store` is not set (`jetstream.go:2762–2764`). `diskAvailable` (`disk_avail.go:23–36`) is

```go
ba = int64(uint64(fs.Bavail) * uint64(fs.Bsize) / 4 * 3)   // disk_avail.go:31
```

— 75% of `statfs`'s **available blocks**, i.e. of what is free *now*. `JetStreamMaxStoreDefault` (1 TB,
`jetstream.go:2733`) is used **only** in the `else` branch when `statfs` fails, and the file carries a
build tag excluding Windows and several other platforms, which have their own implementations.

Memory is different in kind: `MaxMemory` is `sysMem / 4 * 3` where `sysMem` is **total** system memory,
capped by `GOMEMLIMIT` if that is lower (`jetstream.go:2769–2781`), with `JetStreamMaxMemDefault`
(256 MB, `jetstream.go:2735`) only when system memory cannot be read. The server's own comment on the
memory branch says "Estimate to 75% of **total** memory".

An explicitly configured `0` is honoured as zero, not as unlimited: the condition is
`if maxStore > 0 || (opts.maxStoreSet && maxStore == 0)` (`jetstream.go:2760`).

Where the store directory is unset, JetStream places it under `os.TempDir()` and warns
`Temporary storage directory used, data could be lost on system reboot` (`jetstream.go:2746–2749`).

### Since 2.14.6 the dynamic limit no longer shrinks across restarts

`finalizeDynamicMaxStore` (`jetstream.go:546–565`) runs after file-based streams are recovered and adds
the recovered bytes back, scaled the same way:

```go
maxStore := addSaturate(js.config.MaxStore, recovered/4*3)   // jetstream.go:561
```

Until it runs, `maxStorePending` marks the limit provisional and the reservation check is skipped
(`recovering := js.config.maxStorePending`, `jetstream.go:2657`). The function is **absent from v2.14.5
and earlier**; see [[s-issue-8322-dynamic-maxstore-shrinks]].

### 10047 and 10028 compare **reservations**, never actual usage

`reserveStreamResources` (`jetstream.go:2688–2700`) returns immediately unless `cfg.MaxBytes > 0`, then
adds `cfg.MaxBytes` to `js.storeReserved` or `js.memReserved`. A stream with no `max_bytes` reserves
**nothing**, however much disk it later occupies.

`checkBytesLimits` (`jetstream.go:2523–2553`) then compares:

- against the **account** limit: `accountBytes > selectedLimits.MaxStore - currentRes`
- against the **server** limit: `serverBytes > js.config.MaxStore - js.storeReserved`

returning `NewJSStorageResourcesExceededError()` (**10047**) or `NewJSMemoryResourcesExceededError()`
(**10028**).

`accountReservation` (`jetstream.go:2511–2519`) is the replica rule in three lines: on an **untiered**
account, `R>1` counts as `replicas × bytes`; a **tiered** limit "already bake[s] in replication" and
counts once. The per-server footprint is always a single replica's worth.

`sufficientResources` (`jetstream.go:2629–2680`) applies only when standalone — the code says so:

```go
// If we are clustered we do not really know how many resources will be ultimately available.
// This needs to be handled out of band.
if limits == nil || !js.standAlone { return nil }
```

### A real out-of-space write disables JetStream on that server

`handleOutOfSpace` (`jetstream.go:652–678`) logs, at ERR, one of

```
JetStream out of <File|Memory> resources, will be DISABLED
JetStream out of resources, will be DISABLED
```

(the first when a stream is known, the second when it is not), calls `s.ShutdownJetStream()`, and
publishes `$JS.EVENT.ADVISORY.SERVER.OUT_OF_STORAGE`. A guard (`jetStreamOOSPending`) makes it fire
once.

`ShutdownJetStream` is `disableJetStream(false)` (`jetstream.go:693–695`) and **preserves** the
persistent meta-Raft state on disk so the server rejoins its group on restart. `DisableJetStream`
(`deleteState = true`) is the other one: it removes that state and has the metacontroller drop the
peer.

Two paths call it, and only one of them is about disk:

- `jetstream_cluster.go:3529` — an apply error on a stream that `isOutOfSpaceErr`;
- `raft.go:5185` — inside the Raft **critical write error** handler, `if isOutOfSpaceErr(err)`.

The second is why `JetStream out of resources, will be DISABLED` appears in logs with 94% of the disk
free, as in [[s-gh-7463-jetstream-corruption]]: the same handler serves both, and the Raft path
reaches it after `n.error("Critical write error: %v", err)` and `n.shutdown()`
(`raft.go:5167–5171`). `outOfResources` (`raft.go:752–759`) is the *other* direction — Raft asking
JetStream whether limits are already exceeded before proposing.

### The generated config reference's defaults, checked

Four of the ten values in the docs' `jetstream` block table are wrong; the evidence is in the raw
extract and the finding is **docs issue #22**.

| key | docs | server at v2.14.6 |
|---|---|---|
| `max_file_store` | "Defaults to up to 1TB if available" | **75% of free space under `store_dir`**; 1 TB only when `statfs` fails — `jetstream.go:2763`, `disk_avail.go:31` |
| `max_buffered_msgs` | `10000` | **100,000** — `streamDefaultMaxQueueMsgs`, `stream.go:441`, applied `stream.go:900–904` |
| `max_outstanding_catchup` | `32M` | **64 MB** — `defaultMaxTotalCatchupOutBytes`, `jetstream_cluster.go:11158`, applied `jetstream.go:424–425` |
| `info_queue_limit` | `100000` | **defaults to `request_queue_limit`**, so 10,000 unless that is set — `opts.go:6183–6185` |
| `max_buffered_size` | `128MB` | 128 MB ✓ — `stream.go:442` |
| `request_queue_limit` | `10000` | 10,000 ✓ — `JSDefaultRequestQueueLimit`, `jetstream_api.go:367` |
| `sync_interval` | `2m` | 2m ✓ — `defaultSyncInterval`, `filestore.go:333` |
| `strict` | `true` | true ✓ — `jsc.Strict = !opts.NoJetStreamStrict`, `jetstream.go:2754` |
| `store_dir` | `/tmp/nats/jetstream` | `os.TempDir()/nats/jetstream` ✓ — `jetstream.go:2747` |
| `max_memory_store` | "75% of available memory" | 75% of **total** memory, or `GOMEMLIMIT`; 256 MB fallback — `jetstream.go:2769–2781` |

## Practical takeaways

- Three different conditions produce "out of storage" wording and they need different fixes: a
  **reservation** arithmetic failure (10047/10028 on create or update), a **shrinking dynamic limit**
  at restart (pre-2.14.6), and a **real ENOSPC** (which disables JetStream and raises an advisory).
- `reserved_storage` in `/varz` is the number that matters for 10047, not `storage`.
- In a cluster the standalone pre-check does not run at all — the comment says the clustered case is
  "handled out of band" — so capacity planning cannot lean on it.

## Relevance to the wiki

The authority behind [[jetstream-out-of-disk]] and half of [[malformed-or-corrupt-message]]; the
version floor stated on [[jetstream-sizing]]; and the evidence for **docs issue #22**.

## Questions it answers

- **Q26** — what happens when JetStream runs out of disk.

## Pages touched

[[jetstream-out-of-disk]] · [[malformed-or-corrupt-message]] · [[jetstream-sizing]] ·
[[defaults-and-limits]] · [[config-keys]] · [[error-codes]] · [[advisories]] · [[replicas]]
