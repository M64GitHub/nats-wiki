---
title: "insufficient storage resources available (10047)"
type: gotcha
area: [jetstream, deploy]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [10047, 10028, max_bytes, max_file_store, reserved_storage, out-of-space, OUT_OF_STORAGE]
aliases: ["JetStream out of disk", "insufficient storage resources available", "insufficient memory resources available", "JetStream out of resources will be DISABLED", "10047", "10028", "out of storage"]
sources: [s-issue-4281-insufficient-storage, s-issue-8322-dynamic-maxstore-shrinks, s-nats-server-jetstream-resources, s-gh-7463-jetstream-corruption, s-docs-sizing-and-resources, s-nats-server-filestore-layout, s-nats-helm-chart-values-2.14.6, s-gh-5924-filestore-dirs-vanished]
created: 2026-08-31
updated: 2026-09-01
---

# "insufficient storage resources available (10047)"

Three different failures wear the same words, and only one of them is a full disk. Getting them
apart is the whole job: the fix for each is different, and two of them happen with the volume 90%
empty.

## Symptom

On a create, update or replica change:

```
nats: error: could not create Stream: insufficient storage resources available (10047)
```

or, for a memory stream, `insufficient memory resources available (10028)`. In the server log, on a
running node:

```
[ERR] JetStream out of File resources, will be DISABLED
[INF] Initiating JetStream Shutdown...
```

## Quick triage

```
nats server report jetstream
curl -s localhost:8222/varz | jq '.jetstream.config, .jetstream.stats'
```

The two numbers that decide everything are in `jetstream.stats`:

```json
      "storage": 4022205,
      "reserved_storage": 37580963840,
```

4 MB stored, **35 GiB reserved** (source: [[s-issue-4281-insufficient-storage]]).

| what you see | which failure |
|---|---|
| `reserved_storage` near `config.max_storage`, `storage` far below it | **reservation** — cause 1 |
| `config.max_storage` **lower than it was before the last restart**, and `max_file_store` is unset | **shrinking dynamic limit** — cause 2 |
| the ERR log line above, and the filesystem genuinely full | **a real write failure** — cause 3 |
| the ERR log line above, and the filesystem *not* full | not a storage problem at all — see [[malformed-or-corrupt-message]] |
| the publisher gets **`10077 maximum messages exceeded`**, not `10047` | one stream at its own limit under `discard: new` — see [[maximum-messages-exceeded]] |

## Causes

### 1. `max_bytes` is a reservation, and it is counted whether or not it is used

This is the usual answer. `10047` compares **reserved** bytes against the limit; it never looks at
what is on disk.

```go
func (js *jetStream) reserveStreamResources(cfg *StreamConfig) {
	if cfg == nil || cfg.MaxBytes <= 0 {
		return
	}
	…
		js.storeReserved += cfg.MaxBytes
```

(`jetstream.go:2688–2700`, source: [[s-nats-server-jetstream-resources]]). A maintainer states the
same thing in operator terms:

> "When you specify max_bytes that is now considered 'used' for all intent and purposes such that you
> should never fail to add a message to that stream since we pre-check for the reservation against all
> server and account limits. So even though they might be empty the system will see those as reserved
> and deny new streams if the capacity limit has been reached."
> — @derekcollison, 2024-12-05 (source: [[s-issue-4281-insufficient-storage]])

Two independent checks can fail, and the error is identical:

- the **server** limit — `serverBytes > js.config.MaxStore - js.storeReserved`, counting **one
  replica's** worth;
- the **account** limit — `accountBytes > selectedLimits.MaxStore - currentRes`, where on an
  **untiered** account `R3` counts **three times** and a **tiered** limit counts once
  (`jetstream.go:2511–2553`).

**How to confirm.** Sum `max_bytes` over every stream on the node and compare with
`config.max_storage`; then run `nats account info` and compare the account's tier limits with its
usage. In [[s-issue-4281-insufficient-storage]] the first reporter's account tier was **122 MiB**
while the server had gigabytes free.

**The fix.** Either raise `max_file_store` / the account's `MaxStore`, or lower the `max_bytes`
values. Note the asymmetry that makes the arithmetic surprising: a stream **without** `max_bytes`
reserves nothing and still fills the disk. Set it on every stream or on none.

**Still open:** a reporter with `max_file: 16G` and two streams at `--max-bytes=10G` and `5G` got
`10047` anyway on 2.10.22, and nobody has answered why (issue #4281 is open as of 2026-08-31).

### 2. The dynamic limit shrinks at every restart (fixed in 2.14.6)

If `max_file_store` is not set, the server computes it at startup as **75% of what is free** under
`store_dir` — not 75% of the volume:

```go
ba = int64(uint64(fs.Bavail) * uint64(fs.Bsize) / 4 * 3)   // disk_avail.go:31
```

Every byte JetStream itself has written reduces the free space, so the limit **ratchets downwards at
each restart** until a stream that was legal yesterday cannot be restored today. The reproduction is
four lines (source: [[s-issue-8322-dynamic-maxstore-shrinks]]):

> 512 MB empty volume → limit 338 MB · create a 300 MB stream · fill 250 MB · restart → limit
> **196 MB**, and the server refuses to restore the stream with `insufficient storage resources
> available (10047)`.

**How to confirm.** Compare the `Max Storage:` line in the startup banner with the previous boot's,
and check that `jetstream { max_file_store }` is genuinely unset.

**The fix.** Pin `max_file_store` to the volume — both maintainers who touched this say so:

> "We do not recommend auto-sizing for real world production uses. You should always configure
> JetStream to use as much disk as you want / need explicitly in the configuration. Auto detection is
> for development and testing." — @derekcollison, 2024-09-10

**Version note.** PR #8503, merged 2026-08-24, adds `finalizeDynamicMaxStore`, which adds recovered
bytes back into the dynamic limit after startup recovery. It is **absent from v2.14.5 and present in
v2.14.6** — so 2.14.6 is the floor. Even then the limit is computed only at startup, so a shared disk
still invalidates it.

**Do not use `max_file_store: 0` to mean "no limit".** An explicitly configured `0` is honoured as
zero, and no stream can be created (`jetstream.go:2760`).

### 3. A genuine out-of-space write disables JetStream on that server

When a write actually fails for want of space, `handleOutOfSpace` logs

```
JetStream out of File resources, will be DISABLED
```

calls `ShutdownJetStream()`, and publishes **`$JS.EVENT.ADVISORY.SERVER.OUT_OF_STORAGE`** — once,
guarded so it does not repeat (`jetstream.go:652–678`). `ShutdownJetStream` **preserves** the
persistent meta-Raft state on disk, so the server rejoins its groups on restart; the sibling
`DisableJetStream` (which deletes that state and has the metacontroller remove the peer) is *not*
what this path calls.

**How to confirm.** `df -h` on the volume holding `store_dir`, and check whether the advisory fired:

```
nats --context sys subscribe '$JS.EVENT.ADVISORY.SERVER.OUT_OF_STORAGE'
```

**The fix.** Free space or grow the volume, then restart the server; JetStream does not re-enable
itself. See [[advisories]] — this is one of the four events worth alerting on.

### 4. The same log line with plenty of free disk

`handleOutOfSpace` is also called from the Raft **critical write error** path
(`raft.go:5185`), so `JetStream out of resources, will be DISABLED` appears verbatim during a
filestore corruption with the disk 94% empty. That is [[malformed-or-corrupt-message]], not this
page.

### 5. The disk is not the one you think it is

On an Arm Mac, Docker Desktop's VM has its own virtual disk limit; reaching it produces `10047`
inside the container while the host has space (source: [[s-issue-4281-insufficient-storage]]).

Two more ways `store_dir` is not where you think. **A `store_dir` on tmpfs is RAM**, so it fills
against the memory limit rather than the volume — and it is not supported: "we don't support running
the JetStream file store on RAM disks and cannot rely on RAM disks being anything other than
temporary". A **memory** stream is the supported alternative, and the server already caches filestore
blocks in memory for speed, so the tmpfs trick buys nothing it does not already do. **And with no
`jetstream { store_dir }` set at all the default sits under `os.TempDir()`** — exactly where
`tmpwatch`, `tmpreaper`, `systemd-tmpfiles` and container image cleaners look, which is a different
failure with the same flavour: the directories go missing under a stream the server still lists
(source: [[s-gh-5924-filestore-dirs-vanished]]; that symptom is
[[stream-directories-disappear]]).

## Prevention

- **Pin `max_file_store` *below* the volume**, and `max_memory_store` below the container's memory
  limit. [[jetstream-sizing]] step 4 has the arithmetic, and the section below has the reason the
  margin is not optional. **On Kubernetes this is a change you have to make**: with
  `config.jetstream.fileStore.maxSize` unset, the Helm chart at `nats-2.14.6` renders
  `max_file_store` equal to `fileStore.pvc.size` — a 10Gi ceiling on a 10Gi volume, out of the box
  (source: [[s-nats-helm-chart-values-2.14.6]]; [[kubernetes-storage]]).
- **Alert on `$JS.EVENT.ADVISORY.SERVER.OUT_OF_STORAGE`.** It fires once and JetStream is already
  down by the time you see it, so the alert has to be on the event, not on a threshold crossing.
- **Track `reserved_storage` alongside `storage`**, not just `storage`. The gap between them is your
  actual headroom.
- In a **cluster** the standalone pre-check does not run at all: "If we are clustered we do not really
  know how many resources will be ultimately available. This needs to be handled out of band"
  (`jetstream.go:2633–2635`). Capacity planning cannot lean on the server to catch it.

## The volume can fill while every JetStream number says there is room

Every storage figure the server enforces or reports — `max_file_store`, a stream's `max_bytes`, an
account's `MaxStore`, `/jsz` `storage`, `/varz` `jetstream.stats.storage` — is the sum of the
**live message records**. None of them is the size of the files
(source: [[s-nats-server-filestore-layout]], `nats-server 2.14.6`).

The gap comes from three places, all documented on [[filestore-layout]]:

- deleted records stay in their block until it is compacted, and each delete **adds** a 30-byte
  tombstone;
- a block is only rewritten when **more than half of it is dead** — and only after `sync_interval`
  (default `2m`) if it is under 2MB;
- the **newest block is never compacted at all**, by design.

Measured: a server configured `max_file_store: 4MB` held **3,786,236 bytes** in its store directory
while `/jsz` reported **133,000 bytes** used — 3% of its own ceiling. Nothing was logged, and the
server would have accepted another 4 MB of logical writes.

**How to confirm on a running node**

```
curl -s localhost:8222/jsz | jq '{storage, reserved_storage, max: .config.max_storage}'
du -sb  /var/lib/nats/jetstream/
df -h   /var/lib/nats/jetstream
```

If `du` is far above `storage`, look for the stream that is idle and mostly-discarded rather than for
a leak — and give any busy stream one `sync_interval` before concluding anything.

**The fix** is to size the volume above `max_file_store`, not equal to it: `stream_bytes × 1.1` plus
one block size (usually 8MB, 4MB for a KV bucket) per stream. See [[jetstream-sizing]] step 1b.
This is recorded as **docs issue #33** — the docs' own sizing example sets `max_file_store` to the
volume size.


## A docs error worth knowing

The generated `reference/config/jetstream/max_file_store.md` says the key "Defaults to up to 1TB if
available". That is the **fallback** for when `statfs` fails, not the default; the real default is 75%
of the free space under `store_dir`. The hand-written `learn/deployment/sizing-and-resources.md` gets
it right, and the maintainers' "auto-sizing is for development and testing" appears nowhere in the
docs at all. Recorded as **docs issue #22** in `inbox/docs-issues.md`; this wiki uses the server
values.

## Explained by

[[jetstream-sizing]] for the numbers, [[s-nats-server-jetstream-resources]] for the code paths.

## Related

[[jetstream-sizing]] · [[malformed-or-corrupt-message]] · [[stream-directories-disappear]] ·
[[stream]] · [[replicas]] · [[account]] · [[error-codes]] · [[advisories]] ·
[[monitoring-endpoints]] · [[config-keys]] · [[defaults-and-limits]] · [[upgrade-a-cluster]] ·
[[maximum-messages-exceeded]]

## Sources

- [[s-issue-4281-insufficient-storage]] — the reservation model, `reserved_storage`, and the open
  counter-example.
- [[s-issue-8322-dynamic-maxstore-shrinks]] — the shrinking dynamic limit and the 2.14.6 fix.
- [[s-nats-server-jetstream-resources]] — every code path above, read at v2.14.6 with file and line.
- [[s-gh-7463-jetstream-corruption]] — the log line appearing with a nearly empty disk.
- [[s-docs-sizing-and-resources]] — the docs page that states the 75% default correctly.
- [[s-nats-server-filestore-layout]] — why the ceiling bounds a logical figure and the directory is
  bigger.
- [[s-nats-helm-chart-values-2.14.6]] — the chart rendering `max_file_store` equal to the PVC size. ·
[[s-gh-5924-filestore-dirs-vanished]]