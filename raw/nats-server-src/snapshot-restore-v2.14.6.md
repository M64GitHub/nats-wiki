<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6, server/jetstream_api.go, server/stream.go and server/memstore.go fetched from raw.githubusercontent.com · fetched 2026-08-31 -->
# nats-server v2.14.6 — stream snapshot and restore

The ranges behind `nats stream backup` and `nats stream restore`: the snapshot size defaults and
clamps, the error a **memory** stream actually returns, and the two checks a restore makes. Read
while ingesting `learn/backup-recovery/stream-backup-restore.md`, which quotes an error string for
memory streams that the server does not produce. Line numbers are real at v2.14.6.

## server/jetstream_api.go — the snapshot request, and how a failure surfaces

```go
  4198			if req.CheckMsgs {
  4199				s.Noticef("Starting health check and snapshot for stream '%s > %s'", mset.jsa.account.Name, mset.name())
  4200			} else {
  4201				s.Noticef("Starting snapshot for stream '%s > %s'", mset.jsa.account.Name, mset.name())
  4202			}
  4203	
  4204			start := time.Now().UTC()
  4205	
  4206			sr, err := mset.snapshot(0, req.CheckMsgs, !req.NoConsumers)
  4207			if err != nil {
  4208				s.Warnf("Snapshot of stream '%s > %s' failed: %v", mset.jsa.account.Name, mset.name(), err)
  4209				resp.Error = NewJSStreamSnapshotError(err, Unless(err))
  4210				s.sendAPIErrResponse(ci, acc, subject, reply, smsg, s.jsonResponse(&resp))
  4211				return
  4212			}
```

## server/jetstream_api.go — chunk and window defaults, and their clamps

```go
  4261	// Default chunk size for now.
  4262	const defaultSnapshotChunkSize = 128 * 1024       // 128KiB
  4263	const defaultSnapshotWindowSize = 8 * 1024 * 1024 // 8MiB
  4264	const defaultSnapshotAckTimeout = 5 * time.Second
  4265	
  4266	var snapshotAckTimeout = defaultSnapshotAckTimeout
  4267	
  4268	// streamSnapshot will stream out our snapshot to the reply subject.
  4269	func (s *Server) streamSnapshot(acc *Account, mset *stream, sr *SnapshotResult, req *JSApiStreamSnapshotRequest) error {
  4270		chunkSize, wndSize := req.ChunkSize, req.WindowSize
  4271		if chunkSize == 0 {
  4272			chunkSize = defaultSnapshotChunkSize
  4273		}
  4274		if wndSize == 0 {
  4275			wndSize = defaultSnapshotWindowSize
  4276		}
  4277		chunkSize = min(max(1024, chunkSize), 1024*1024) // Clamp within 1KiB to 1MiB
  4278		wndSize = min(max(1024, wndSize), 32*1024*1024)  // Clamp within 1KiB to 32MiB
  4279		wndSize = max(wndSize, chunkSize)                // Guarantee at least one chunk
  4280		maxInflight := wndSize / chunkSize               // Between 1 and 32,768
  4281	
```

## server/stream.go — the snapshot goes straight to the store

```go
  9086	func (mset *stream) snapshot(deadline time.Duration, checkMsgs, includeConsumers bool) (*SnapshotResult, error) {
  9087		if mset.closed.Load() {
  9088			return nil, errStreamClosed
  9089		}
  9090		store := mset.store
  9091		return store.Snapshot(deadline, checkMsgs, includeConsumers)
  9092	}
```

## server/memstore.go — a memory stream's Snapshot

```go
  2424	func (ms *memStore) Snapshot(_ time.Duration, _, _ bool) (*SnapshotResult, error) {
  2425		return nil, fmt.Errorf("no impl")
  2426	}
```

## server/jetstream_api.go — the two checks on restore

```go
  3826	
  3827		stream := streamNameFromSubject(subject)
  3828	
  3829		if stream != req.Config.Name && req.Config.Name == _EMPTY_ {
  3830			req.Config.Name = stream
  3831		}
  3832		if stream != req.Config.Name {
  3833			resp.Error = NewJSStreamMismatchError()
  3834			s.sendAPIErrResponse(ci, acc, subject, reply, string(msg), s.jsonResponse(&resp))
  3835			return
  3836		}
  3837	
  3838		// Check for path like separators in the name.
  3839		if strings.ContainsAny(stream, `\/`) {
  3840			resp.Error = NewJSStreamNameContainsPathSeparatorsError()
```

```go
  3862		}
  3863	
  3864		if _, err := acc.lookupStream(stream); err == nil {
  3865			resp.Error = NewJSStreamNameExistRestoreFailedError()
  3866			s.sendAPIErrResponse(ci, acc, subject, reply, string(msg), s.jsonResponse(&resp))
  3867			return
  3868		}
  3869	
  3870		if hasJS, doErr := acc.checkJetStream(); !hasJS {
```
