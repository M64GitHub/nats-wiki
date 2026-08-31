<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6, files fetched from raw.githubusercontent.com · fetched 2026-08-31 -->
# nats-server v2.14.6 — the filestore on disk

Extracted line ranges, verbatim, from the tagged source. The line numbers are the real ones in that
file at that tag, so every figure on `wiki/internals/filestore-layout.md` can be checked against
`https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`.

Read for plan step 5 (`inbox/plan-drift-and-adrs-2026-08-31.md`): question-bank rows **Q1** (size a
3-node R3 cluster) and **Q2** (what a stream costs on disk beyond the raw message bytes). The
behavioural half — what the files actually look like on a running server — is in
`filestore-observed-v2.14.6.md`.

## server/filestore.go

### The message-block accounting fields — `bytes` vs `rbytes`

`bytes` is what `nats stream info` reports; `rbytes` is what the block file actually holds,
including records that have been deleted and the tombstones written for them.

```go
   236		liwsz       int64
   237		index       uint32
   238		bytes       uint64 // User visible bytes count.
   239		rbytes      uint64 // Total bytes (raw) including deleted. Used for rolling to new blk.
   240		cbytes      uint64 // Bytes count after last compaction. 0 if no compaction happened yet.
   241		msgs        uint64 // User visible message count.
   242		fss         *stree.SubjectTree[SimpleState]
   243		kfn         string
   244		lwts        int64
```

### The filestore constants — magic, directory names, block sizes

```go
   293	const (
   294		// Magic is used to identify the file store files.
   295		magic = uint8(22)
   296		// Version
   297		version = uint8(1)
   298		// New IndexInfo Version
   299		newVersion = uint8(2)
   300		// hdrLen
   301		hdrLen = 2
   302		// This is where we keep the streams.
   303		streamsDir = "streams"
   304		// This is where we keep inflight batches for streams.
   305		batchesDir = "batches"
   306		// This is where we keep the message store blocks.
   307		msgDir = "msgs"
   308		// This is where we temporarily move the messages dir.
   309		purgeDir = "__msgs__"
   310		// This is where we temporarily move the new message block during purge.
   311		newMsgDir = "__new_msgs__"
   312		// used to scan blk file names.
   313		blkScan = "%d.blk"
   314		// suffix of a block file
   315		blkSuffix = ".blk"
   316		// used for compacted blocks that are staged.
   317		newScan = "%d.new"
   318		// used to scan index file names.
   319		indexScan = "%d.idx"
   320		// used to store our block encryption key.
   321		keyScan = "%d.key"
   322		// to look for orphans
   323		keyScanAll = "*.key"
   324		// This is where we keep state on consumers.
   325		consumerDir = "obs"
   326		// Index file for a consumer.
   327		consumerState = "o.dat"
   328		// The suffix that will be given to a new temporary block for compression or when rewriting the full file.
   329		blkTmpSuffix = ".tmp"
   330		// default cache buffer expiration
   331		defaultCacheBufferExpiration = 10 * time.Second
   332		// default sync interval
   333		defaultSyncInterval = 2 * time.Minute
   334		// default idle timeout to close FDs.
   335		closeFDsIdle = 30 * time.Second
   336		// default expiration time for mb.fss when idle.
   337		defaultFssExpiration = 2 * time.Minute
   338		// coalesceMinimum
   339		coalesceMinimum = 16 * 1024
   340		// maxFlushWait is maximum we will wait to gather messages to flush.
   341		maxFlushWait = 8 * time.Millisecond
   342	
   343		// Metafiles for streams and consumers.
   344		JetStreamMetaFile    = "meta.inf"
   345		JetStreamMetaFileSum = "meta.sum"
   346		JetStreamMetaFileKey = "meta.key"
   347	
   348		// This is the full snapshotted state for the stream.
   349		streamStreamStateFile = "index.db"
   350	
   351		// This is the encoded time hash wheel for TTLs.
   352		ttlStreamStateFile = "thw.db"
   353	
   354		// This is the encoded message scheduling file.
   355		msgSchedulingStreamStateFile = "sched.db"
   356	
   357		// AEK key sizes
   358		minMetaKeySize = 64
   359		minBlkKeySize  = 64
   360	
   361		// Default stream block size.
   362		defaultLargeBlockSize = 8 * 1024 * 1024 // 8MB
   363		// Default for workqueue or interest based.
   364		defaultMediumBlockSize = 4 * 1024 * 1024 // 4MB
   365		// For smaller reuse buffers. Usually being generated during contention on the lead write buffer.
   366		// E.g. mirrors/sources etc.
   367		defaultSmallBlockSize = 1 * 1024 * 1024 // 1MB
   368		// NOT an actual block size, but used for the sync.Pools, so that we don't allocate huge buffers
   369		// unnecessarily until there are enough writes to justify it.
   370		defaultTinyBlockSize = 1 * 1024 * 256 // 256KB
   371		// Maximum size for the encrypted head block.
   372		maximumEncryptedBlockSize = 2 * 1024 * 1024 // 2MB
   373		// Default for KV based
   374		defaultKVBlockSize = defaultMediumBlockSize
   375		// max block size for now.
   376		maxBlockSize = defaultLargeBlockSize
   377		// Compact minimum threshold.
   378		compactMinimum = 2 * 1024 * 1024 // 2MB
   379		// FileStoreMinBlkSize is minimum size we will do for a blk size.
   380		FileStoreMinBlkSize = 32 * 1000 // 32kib
   381		// FileStoreMaxBlkSize is maximum size we will do for a blk size.
   382		FileStoreMaxBlkSize = maxBlockSize
   383		// Check for bad record length value due to corrupt data.
   384		rlBadThresh = 32 * 1024 * 1024
   385		// Checksum size for hash for msg records.
   386		recordHashSize = 8
   387	
   388		// Above this number of subjects, index.db may not be written regularly anymore, and
   389		// certain psim optimisations may not be used.
   390		highCardinalityThreshold = 1_000_000
   391	)
```

### The message record header

`emptyRecordLen` (30) is the whole cost of a record that carries neither subject, headers nor
payload — it is also the exact size of a delete tombstone.

```go
  1117	
  1118	const (
  1119		msgHdrSize     = 22
  1120		checksumSize   = 8
  1121		emptyRecordLen = msgHdrSize + checksumSize
  1122	)
```

### `dynBlkSize` — the block size the server picks when `block_size` is not set

Note the middle branch: **any `max_bytes` that resolves to more than `FileStoreMinBlkSize` and less
than 8MB collapses to exactly `defaultMediumBlockSize` (4MB)**, so a 1MB stream is given a 4MB
block. With no `max_bytes` a `limits` stream gets 8MB and every other retention 4MB.

```go
   816	func dynBlkSize(retention RetentionPolicy, maxBytes int64, encrypted bool) uint64 {
   817		if maxBytes > 0 {
   818			blkSize := (maxBytes / 4) + 1 // (25% overhead)
   819			// Round up to nearest 100
   820			if m := blkSize % 100; m != 0 {
   821				blkSize += 100 - m
   822			}
   823			if blkSize <= FileStoreMinBlkSize {
   824				blkSize = FileStoreMinBlkSize
   825			} else if blkSize >= FileStoreMaxBlkSize {
   826				blkSize = FileStoreMaxBlkSize
   827			} else {
   828				blkSize = defaultMediumBlockSize
   829			}
   830			if encrypted && blkSize > maximumEncryptedBlockSize {
   831				// Notes on this below.
   832				blkSize = maximumEncryptedBlockSize
   833			}
   834			return uint64(blkSize)
   835		}
   836	
   837		switch {
   838		case encrypted:
   839			// In the case of encrypted stores, large blocks can result in worsened perf
   840			// since many writes on disk involve re-encrypting the entire block. For now,
   841			// we will enforce a cap on the block size when encryption is enabled to avoid
   842			// this.
   843			return maximumEncryptedBlockSize
   844		case retention == LimitsPolicy:
   845			// TODO(dlc) - Make the blocksize relative to this if set.
   846			return defaultLargeBlockSize
   847		default:
   848			// TODO(dlc) - Make the blocksize relative to this if set.
   849			return defaultMediumBlockSize
   850		}
   851	}
```

### `shouldCompactInline` / `shouldCompactSync` — when a block file shrinks

Inline compaction needs the block over 2MB **and** more than half of it dead. The periodic pass
(every `sync_interval`, default 2m) drops the 2MB minimum but keeps the half-dead test.

```go
  6247		return nil
  6248	}
  6249	
  6250	// Tests whether we should try to compact this block while inline removing msgs.
  6251	// We will want rbytes to be over the minimum and have a 2x potential savings.
  6252	// If we compacted before but rbytes didn't improve much, guard against constantly compacting.
  6253	// Lock should be held.
  6254	func (mb *msgBlock) shouldCompactInline() bool {
  6255		return mb.rbytes > compactMinimum && mb.bytes*2 < mb.rbytes && (mb.cbytes == 0 || mb.bytes*2 < mb.cbytes)
  6256	}
  6257	
  6258	// Tests whether we should try to compact this block while running periodic sync.
  6259	// We will want rbytes to be over the minimum and have a 2x potential savings.
  6260	// Ignores 2MB minimum.
  6261	// Lock should be held.
  6262	func (mb *msgBlock) shouldCompactSync() bool {
  6263		return mb.bytes*2 < mb.rbytes && !mb.noCompact
  6264	}
  6265	
  6266	// This will compact and rewrite this block. This version will not process any tombstone cleanup.
```

### The two places a block is compacted — and the block that never is

Both paths skip the **last** message block. A stream that has discarded most of its newest block and
then goes idle keeps that block on disk at full raw size, indefinitely.

```go
  6145			// Out of order delete.
  6146			mb.dmap.Insert(seq)
  6147			// Make simple check here similar to Compact(). If we can save 50% and over a certain threshold do inline.
  6148			// All other more thorough cleanup will happen in syncBlocks logic.
  6149			// Note that we do not have to store empty records for the deleted, so don't use to calculate.
  6150			// TODO(dlc) - This should not be inline, should kick the sync routine.
  6151			if !isLastBlock && mb.shouldCompactInline() {
  6152				if err = mb.compact(); err != nil {
  6153					finishedWithCache()
  6154					mb.mu.Unlock()
  6155					return false, err
  6156				}
  6157			}
  6158		}
```

```go
  8033			if firstMoved && mb.noCompact {
  8034				mb.noCompact = false
  8035			}
  8036			// Check if we should compact here as well.
  8037			// Do not compact last mb.
  8038			var needsCompact bool
  8039			if mb != lmb && mb.ensureRawBytesLoaded() == nil && mb.shouldCompactSync() {
  8040				needsCompact = true
  8041				markDirty = true
  8042			}
  8043	
  8044			// Flush anything that may be pending.
  8045			if _, err := mb.flushPendingMsgsLocked(); err != nil {
  8046				mb.mu.Unlock()
  8047				storeFsWerr(err)
  8048				continue
```

### The on-disk record format, written by `writeMsgRecordLocked`

The comment above the write is the authoritative statement of the format; the code below it is what
puts the 22-byte header down, appends subject, optional `hdr_len`+headers, payload, and the 8-byte
highwayhash.

```go
  7499		// Indexing
  7500		index := len(mb.cache.buf)
  7501	
  7502		// Formats
  7503		// Format with no header
  7504		// total_len(4) sequence(8) timestamp(8) subj_len(2) subj msg hash(8)
  7505		// With headers, high bit on total length will be set.
  7506		// total_len(4) sequence(8) timestamp(8) subj_len(2) subj hdr_len(4) hdr msg hash(8)
  7507	
  7508		var le = binary.LittleEndian
  7509	
  7510		l := uint32(rl)
  7511		hasHeaders := len(mhdr) > 0
  7512		if hasHeaders {
  7513			l |= hbit
  7514		}
  7515	
  7516		// Reserve space for the header on the underlying buffer.
  7517		mb.cache.buf = append(mb.cache.buf, make([]byte, msgHdrSize)...)
  7518		hdr := mb.cache.buf[len(mb.cache.buf)-msgHdrSize : len(mb.cache.buf)]
  7519		le.PutUint32(hdr[0:], l)
  7520		le.PutUint64(hdr[4:], seq)
  7521		le.PutUint64(hdr[12:], uint64(ts))
  7522		le.PutUint16(hdr[20:], uint16(len(subj)))
  7523	
  7524		// Now write to underlying buffer.
  7525		mb.cache.buf = append(mb.cache.buf, subj...)
  7526	
  7527		if hasHeaders {
  7528			var hlen [4]byte
  7529			le.PutUint32(hlen[0:], uint32(len(mhdr)))
  7530			mb.cache.buf = append(mb.cache.buf, hlen[:]...)
  7531			mb.cache.buf = append(mb.cache.buf, mhdr...)
  7532		}
  7533		mb.cache.buf = append(mb.cache.buf, msg...)
  7534	
  7535		// Calculate hash.
  7536		mb.hh.Reset()
  7537		mb.hh.Write(hdr[4:20])
  7538		mb.hh.Write(stringToBytes(subj))
  7539		if hasHeaders {
  7540			mb.hh.Write(mhdr)
  7541		}
  7542		mb.hh.Write(msg)
  7543		checksum := mb.hh.Sum(mb.lchk[:0:highwayhash.Size64])
  7544		copy(mb.lchk[0:], checksum)
  7545	
  7546		// Update write through cache.
```

### `updateAccounting` — why the reported bytes and the file size diverge

Every record adds `rl` to `rbytes`; only a live message adds it to `bytes`.

```go
  7682	func (mb *msgBlock) updateAccounting(seq uint64, ts int64, rl uint64) {
  7683		isDeleted := seq&ebit != 0
  7684		if isDeleted {
  7685			seq = seq &^ ebit
  7686		}
  7687	
  7688		fseq := atomic.LoadUint64(&mb.first.seq)
  7689		if (fseq == 0 || mb.first.ts == 0) && seq >= fseq {
  7690			atomic.StoreUint64(&mb.first.seq, seq)
  7691			mb.first.ts = ts
  7692		}
  7693		// Need atomics here for selectMsgBlock speed.
  7694		atomic.StoreUint64(&mb.last.seq, seq)
  7695		mb.last.ts = ts
  7696		mb.rbytes += rl
  7697		if !isDeleted {
  7698			mb.bytes += rl
  7699			mb.msgs++
  7700		}
  7701	}
  7702	
```

### `checkLastBlock` — the block rolls before the record that would overflow it

A record is never split across two blocks. A block therefore never exceeds `BlockSize` unless a
single record is larger than the whole block, in which case it is written alone into a fresh one.

```go
  7704	// Lock should be held.
  7705	func (fs *fileStore) checkLastBlock(rl uint64) (lmb *msgBlock, err error) {
  7706		// Grab our current last message block.
  7707		lmb = fs.lmb
  7708		rbytes := lmb.blkSize()
  7709		if lmb == nil || (rbytes > 0 && rbytes+rl > fs.fcfg.BlockSize) {
  7710			if lmb, err = fs.newMsgBlockForWrite(); err != nil {
  7711				return nil, err
  7712			}
  7713		}
  7714		return lmb, nil
  7715	}
  7716	
  7717	// Lock should be held.
  7718	func (fs *fileStore) writeMsgRecord(seq uint64, ts int64, subj string, hdr, msg []byte) (uint64, error) {
```

### `fileStoreMsgSize` — the per-message record length, in one function

```go
  9819	}
  9820	
  9821	func fileStoreMsgSizeRaw(slen, hlen, mlen int) uint64 {
  9822		if hlen == 0 {
  9823			// length of the message record (4bytes) + seq(8) + ts(8) + subj_len(2) + subj + msg + hash(8)
  9824			return uint64(22 + slen + mlen + 8)
  9825		}
  9826		// length of the message record (4bytes) + seq(8) + ts(8) + subj_len(2) + subj + hdr_len(4) + hdr + msg + hash(8)
  9827		return uint64(22 + slen + 4 + hlen + mlen + 8)
  9828	}
  9829	
  9830	func fileStoreMsgSize(subj string, hdr, msg []byte) uint64 {
  9831		return fileStoreMsgSizeRaw(len(subj), len(hdr), len(msg))
  9832	}
  9833	
  9834	// isFileStoreMsgTooLarge reports whether a message record cannot be represented
  9835	// safely by the file store.
  9836	func isFileStoreMsgTooLarge(rl uint64) bool {
  9837		return rl&hbit != 0 || rl > rlBadThresh
  9838	}
  9839	
  9840	func fileStoreMsgSizeEstimate(slen, maxPayload int) uint64 {
  9841		return uint64(emptyRecordLen + slen + 4 + maxPayload)
  9842	}
  9843	
```

### `index.db` — the full-state snapshot, its version and its size estimate

Written by the `flushStreamStateLoop` goroutine every **2 minutes plus up to 30 seconds of
jitter**, and forced on purge and on a clean stop. `errStateTooBig` above 1,000,000 subjects or
1,000,000 interior deletes is why a high-cardinality stream may stop getting one.

```go
 11888	// The full state file is versioned.
 11889	// - 0x1: original binary index.db format
 11890	// - 0x2: adds support for TTL count field after num deleted
 11891	const (
 11892		fullStateMagic      = uint8(11)
 11893		fullStateMinVersion = uint8(1) // What is the minimum version we know how to parse?
 11894		fullStateVersion    = uint8(4) // What is the current version written out to index.db?
 11895	)
 11896	
 11897	// This go routine periodically writes out our full stream state index.
```

```go
 11897	// This go routine periodically writes out our full stream state index.
 11898	func (fs *fileStore) flushStreamStateLoop(qch, done chan struct{}) {
 11899		// Signal we are done on exit.
 11900		defer close(done)
 11901	
 11902		// Make sure we do not try to write these out too fast.
 11903		// Spread these out for large numbers on a server restart.
 11904		const writeThreshold = 2 * time.Minute
 11905		writeJitter := time.Duration(mrand.Int63n(int64(30 * time.Second)))
 11906		t := time.NewTicker(writeThreshold + writeJitter)
 11907		defer t.Stop()
 11908	
 11909		for {
 11910			select {
 11911			case <-t.C:
 11912				err := fs.writeFullState()
 11913				if isPermissionError(err) && fs.srv != nil {
 11914					fs.warn("File system permission denied when flushing stream state, disabling JetStream: %v", err)
 11915					// messages in block cache could be lost in the worst case.
 11916					// In the clustered mode it is very highly unlikely as a result of replication.
 11917					fs.srv.ShutdownJetStream()
 11918					return
 11919				}
 11920	
 11921			case <-qch:
 11922				return
 11923			}
 11924		}
 11925	}
 11926	
 11927	// Helper since unixnano of zero time undefined.
 11928	func timestampNormalized(t time.Time) int64 {
 11929		if t.IsZero() {
 11930			return 0
 11931		}
 11932		return t.UnixNano()
 11933	}
 11934	
 11935	// writeFullState will proceed to write the full meta state iff not complex and time consuming.
 11936	// Since this is for quick recovery it is optional and should not block/stall normal operations.
 11937	func (fs *fileStore) writeFullState() error {
 11938		return fs._writeFullState(false)
```

The per-subject and per-block cost of the file, from the size estimate and the writer:

```go
 11995	
 11996		// If we are not being forced to write out our state, check the complexity for time costs as to not
 11997		// block or stall normal operations.
 11998		// We will base off of number of subjects and interior deletes. A very large number of msg blocks could also
 11999		// be used, but for next server version will redo all meta handling to be disk based. So this is temporary.
 12000		if !force {
 12001			// Calculate interior deletes.
 12002			var numDeleted int
 12003			if fs.state.LastSeq > fs.state.FirstSeq {
 12004				numDeleted = int((fs.state.LastSeq - fs.state.FirstSeq + 1) - fs.state.Msgs)
 12005			}
 12006			if numSubjects > highCardinalityThreshold || numDeleted > highCardinalityThreshold {
 12007				fs.mu.RUnlock()
 12008				return errStateTooBig
 12009			}
 12010		}
 12011	
 12012		// We track this through subsequent runs to get an avg per blk used for subsequent runs.
 12013		avgDmapLen := fs.wfsadml
 12014		// If first time through could be 0
 12015		if avgDmapLen == 0 && ((fs.state.LastSeq-fs.state.FirstSeq+1)-fs.state.Msgs) > 0 {
 12016			avgDmapLen = 1024
 12017		}
 12018	
 12019		// Calculate and estimate of the uper bound on the  size to avoid multiple allocations.
 12020		sz := hdrLen + // Magic and Version
 12021			(binary.MaxVarintLen64 * 6) + // FS data
 12022			binary.MaxVarintLen64 + fs.tsl + // NumSubjects + total subject length
 12023			numSubjects*(binary.MaxVarintLen64*4) + // psi record
 12024			binary.MaxVarintLen64 + // Num blocks.
 12025			len(fs.blks)*((binary.MaxVarintLen64*8)+avgDmapLen) + // msg blocks, avgDmapLen is est for dmaps
 12026			binary.MaxVarintLen64 + 8 + 8 // last index + record checksum + full state checksum
 12027	
 12028		// Do 4k on stack if possible.
 12029		const ssz = 4 * 1024
 12030		var buf []byte
 12031	
 12032		if sz <= ssz {
 12033			var _buf [ssz]byte
 12034			buf, sz = _buf[0:hdrLen:ssz], ssz
 12035		} else {
 12036			buf = make([]byte, hdrLen, sz)
 12037		}
 12038	
 12039		buf[0], buf[1] = fullStateMagic, fullStateVersion
 12040		buf = binary.AppendUvarint(buf, fs.state.Msgs)
 12041		buf = binary.AppendUvarint(buf, fs.state.Bytes)
 12042		buf = binary.AppendUvarint(buf, fs.state.FirstSeq)
 12043		buf = binary.AppendVarint(buf, timestampNormalized(fs.state.FirstTime))
 12044		buf = binary.AppendUvarint(buf, fs.state.LastSeq)
 12045		buf = binary.AppendVarint(buf, timestampNormalized(fs.state.LastTime))
 12046	
 12047		// Do per subject information map if applicable.
 12048		buf = binary.AppendUvarint(buf, uint64(numSubjects))
 12049		if numSubjects > 0 {
 12050			fs.psim.Match([]byte(fwcs), func(subj []byte, psi *psi) {
 12051				buf = binary.AppendUvarint(buf, uint64(len(subj)))
 12052				buf = append(buf, subj...)
 12053				buf = binary.AppendUvarint(buf, psi.total)
 12054				buf = binary.AppendUvarint(buf, uint64(psi.fblk))
 12055				buf = binary.AppendUvarint(buf, uint64(psi.lblk))
 12056			})
 12057		}
 12058	
```

## server/stream.go

### `autoTuneFileStorageBlockSize` — the block size a *stream* gets, before the filestore is asked

This runs first, and only falls through to `dynBlkSize` when the stream sets none of `max_bytes`,
`max_msgs` or `max_msgs_per_subject`. Three things follow:

- `max_msgs` alone is turned into bytes with `maxMsgSize()`, which uses `max_msg_size` if set, else
  the account's `max_payload`, else `MAX_PAYLOAD_SIZE` (1MB) — so `max_msgs: 100000` with no
  `max_msg_size` estimates 100GB and lands on the 8MB cap.
- `max_msgs_per_subject` alone gives `defaultKVBlockSize` (4MB) and returns. Every **KV bucket**
  takes this branch, because a bucket is a stream with `max_msgs_per_subject` set to its history.
- The comment says the target is "125% of the theoretical limit"; the arithmetic is the same
  `/4 + 1` used by `dynBlkSize`.

```go
  1409	
  1410	// If we are file based and the file storage config was not explicitly set
  1411	// we can autotune block sizes to better match. Our target will be to store 125%
  1412	// of the theoretical limit. We will round up to nearest 100 bytes as well.
  1413	func (mset *stream) autoTuneFileStorageBlockSize(fsCfg *FileStoreConfig) {
  1414		var totalEstSize uint64
  1415	
  1416		// MaxBytes will take precedence for now.
  1417		if mset.cfg.MaxBytes > 0 {
  1418			totalEstSize = uint64(mset.cfg.MaxBytes)
  1419		} else if mset.cfg.MaxMsgs > 0 {
  1420			// Determine max message size to estimate.
  1421			totalEstSize = mset.maxMsgSize() * uint64(mset.cfg.MaxMsgs)
  1422		} else if mset.cfg.MaxMsgsPer > 0 {
  1423			fsCfg.BlockSize = uint64(defaultKVBlockSize)
  1424			return
  1425		} else {
  1426			// If nothing set will let underlying filestore determine blkSize.
  1427			return
  1428		}
  1429	
  1430		blkSize := (totalEstSize / 4) + 1 // (25% overhead)
  1431		// Round up to nearest 100
  1432		if m := blkSize % 100; m != 0 {
  1433			blkSize += 100 - m
  1434		}
  1435		if blkSize <= FileStoreMinBlkSize {
  1436			blkSize = FileStoreMinBlkSize
  1437		} else if blkSize >= FileStoreMaxBlkSize {
  1438			blkSize = FileStoreMaxBlkSize
  1439		} else {
  1440			blkSize = defaultMediumBlockSize
  1441		}
  1442		fsCfg.BlockSize = uint64(blkSize)
```

The message-size estimate it uses:

```go
  1374	}
  1375	
  1376	// Helper to determine the max msg size for this stream if file based.
  1377	func (mset *stream) maxMsgSize() uint64 {
  1378		maxMsgSize := mset.cfg.MaxMsgSize
  1379		if maxMsgSize <= 0 {
  1380			// Pull from the account.
  1381			if mset.jsa != nil {
  1382				if acc := mset.jsa.acc(); acc != nil {
  1383					acc.mu.RLock()
  1384					maxMsgSize = acc.mpay
  1385					acc.mu.RUnlock()
  1386				}
  1387			}
  1388			// If all else fails use default.
  1389			if maxMsgSize <= 0 {
  1390				maxMsgSize = MAX_PAYLOAD_SIZE
  1391			}
  1392		}
  1393		// Now determine an estimation for the subjects etc.
  1394		maxSubject := -1
  1395		for _, subj := range mset.cfg.Subjects {
  1396			if subjectIsLiteral(subj) {
  1397				if len(subj) > maxSubject {
  1398					maxSubject = len(subj)
  1399				}
  1400			}
  1401		}
  1402		if maxSubject < 0 {
  1403			const defaultMaxSubject = 256
  1404			maxSubject = defaultMaxSubject
  1405		}
  1406		// filestore will add in estimates for record headers, etc.
  1407		return fileStoreMsgSizeEstimate(maxSubject, int(maxMsgSize))
  1408	}
```

## server/memstore.go

### `memStoreMsgSizeRaw` — a memory stream counts different bytes

Sixteen bytes per message, and **no 4-byte `hdr_len` field**, against the filestore's 30 (+4 with
headers). The same message therefore reports a different `bytes` in `nats stream info` depending on
the stream's storage type; the two numbers are not comparable.

```go
  2332	}
  2333	
  2334	func memStoreMsgSizeRaw(slen, hlen, mlen int) uint64 {
  2335		return uint64(slen + hlen + mlen + 16) // 8*2 for seq + age
  2336	}
  2337	
  2338	func memStoreMsgSize(subj string, hdr, msg []byte) uint64 {
  2339		return memStoreMsgSizeRaw(len(subj), len(hdr), len(msg))
  2340	}
  2341	
```
