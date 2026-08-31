---
title: "nats-server v2.14.6 — snapshot and restore"
type: summary
area: [jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/blob/v2.14.6/server/jetstream_api.go
source-path: raw/nats-server-src/snapshot-restore-v2.14.6.md
author: nats-io/nats-server maintainers
article: "streamSnapshot, processStreamRestore and memStore.Snapshot at tag v2.14.6"
date: 2026-08-27          # v2.14.6 publish date
version: "2.14.6"
tags: [snapshot, restore, chunk_size, window_size, memory-streams, no-impl, 10064, 10130]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — snapshot and restore

Read to check what a **memory** stream really does when you back it up. The docs promise a clear
error; the server returns `no impl`. The same range confirms the three snapshot numbers the docs give
and adds the clamps they do not.

## Key claims

**A memory stream's snapshot is not implemented, and says so** (`server/memstore.go:2424–2426`):

```go
func (ms *memStore) Snapshot(_ time.Duration, _, _ bool) (*SnapshotResult, error) {
	return nil, fmt.Errorf("no impl")
}
```

`mset.snapshot()` passes straight through to the store (`stream.go:9086–9092`), and the API handler
wraps whatever comes back (`jetstream_api.go:4206–4209`):

```go
		sr, err := mset.snapshot(0, req.CheckMsgs, !req.NoConsumers)
		if err != nil {
			s.Warnf("Snapshot of stream '%s > %s' failed: %v", mset.jsa.account.Name, mset.name(), err)
			resp.Error = NewJSStreamSnapshotError(err, Unless(err))
```

So the operator sees error **10064** `JSStreamSnapshotErrF` with the substituted text — **`snapshot
failed: no impl`** — and the server logs
`Snapshot of stream '<account> > <stream>' failed: no impl`. The string
`memory streams do not support snapshots` appears nowhere in the server, and the `nats` CLI does not
pre-check storage type either ([[s-natscli-backup-restore]]).

**The three snapshot numbers the docs give are correct** (`jetstream_api.go:4262–4264`):

```go
const defaultSnapshotChunkSize = 128 * 1024       // 128KiB
const defaultSnapshotWindowSize = 8 * 1024 * 1024 // 8MiB
const defaultSnapshotAckTimeout = 5 * time.Second
```

8 MiB ÷ 128 KiB = **64 chunks in flight**, exactly as the docs say.

**And the clamps they do not** (`:4277–4280`):

```go
	chunkSize = min(max(1024, chunkSize), 1024*1024) // Clamp within 1KiB to 1MiB
	wndSize = min(max(1024, wndSize), 32*1024*1024)  // Clamp within 1KiB to 32MiB
	wndSize = max(wndSize, chunkSize)                // Guarantee at least one chunk
	maxInflight := wndSize / chunkSize               // Between 1 and 32,768
```

`window_size`'s 32 MiB ceiling matches the generated reference. **`chunk_size`'s 1 MiB ceiling does
not**: the reference gives its maximum as `9223372036854776000` (int64), and a larger request is
silently clamped rather than rejected — `inbox/docs-issues.md` **#17**.

**Restore makes two checks, in this order** (`jetstream_api.go:3826–3870`):

```go
	if stream != req.Config.Name {
		resp.Error = NewJSStreamMismatchError()
	}
	// Check for path like separators in the name.
	if strings.ContainsAny(stream, `\/`) {
		resp.Error = NewJSStreamNameContainsPathSeparatorsError()
	}
	…
	if _, err := acc.lookupStream(stream); err == nil {
		resp.Error = NewJSStreamNameExistRestoreFailedError()
	}
```

- a name that does not match the subject → **10060** `JSStreamNotMatchErr`,
  "expected stream does not match" — *not* the message the docs quote;
- a name containing `\` or `/` → `JSStreamNameContainsPathSeparatorsErr`;
- **the stream already existing** → **10130** `JSStreamNameExistRestoreFailedErr`,
  "stream name already in use, cannot restore" — the code behind the docs' "restore expects the
  stream not to already exist".

**Restore is logged and advertised.** `Starting restore for stream '<account> > <stream>'`
(`:3885`), plus `$JS.EVENT.ADVISORY.STREAM.RESTORE_CREATE.<stream>` and `…RESTORE_COMPLETE.<stream>`
advisories ([[advisories]]) — which is how you alert on a restore nobody authorised.

## Practical takeaways

- **`snapshot failed: no impl` is the memory-stream answer**, and it is unsearchable. Anyone who
  hits it should be told it means "this stream has no on-disk file to copy" — the fix is
  `Storage: File`, decided at stream creation and unchangeable after
  ([[stream]], [[backup-and-restore-jetstream]]).
- **Asking for a larger chunk than 1 MiB does nothing**, silently. Tuning a slow link is a
  *smaller*-chunk exercise, and the window can go to 32 MiB.
- **10130 is the code to catch in a restore script** — it means "something is already there", which
  during a recovery usually means someone recreated the stream by hand first.
- **The restore advisories are free monitoring** for an operation that rewrites a stream.

## Relevance to the wiki

The memory-stream and error-code sections of [[backup-and-restore-jetstream]], and docs issues
#15–#17.

## Questions it answers

**Q32**, the memory-stream half, with the message an operator actually sees.

## Pages touched

[[backup-and-restore-jetstream]] · [[disaster-recovery]] · [[error-codes]] · [[stream]] ·
[[advisories]]
