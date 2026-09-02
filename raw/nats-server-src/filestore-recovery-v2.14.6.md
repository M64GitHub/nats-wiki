<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6, files fetched from raw.githubusercontent.com · fetched 2026-09-02 ·
     the pull-request bodies and release lines at the end are from the GitHub API (gh pr view / repos/nats-io/nats-server/releases), fetched 2026-09-02 -->
# nats-server v2.14.6 — how a file-backed stream is recovered at startup, and what a sourcing stream does next

Extracted line ranges, verbatim, from the tagged source. The line numbers are the real ones in that
file at that tag, so every claim on `wiki/internals/filestore-layout.md`, `wiki/concepts/mirrors-and-sources.md`
and `wiki/gotchas/jetstream-recovery-is-slow.md` can be checked against
`https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`.

Read for step 4 of `inbox/plan-the-runnable-scouts-2026-09-02.md` (question-bank rows **4, 5, 9, 13**):
what the `Restored N messages for stream … in <duration>` timer actually wraps, when `index.db` is
read and when it is refused, what the high-cardinality threshold switches off, and the backward scan a
stream with `sources` makes before it can source again. The runs are in
`stream-scale-observed-v2.14.6.md` in this directory.

## server/jetstream.go

### The two timers: `Took … to start JetStream`, and `Restored … in` per stream

`Took %s to start JetStream` wraps the whole of `EnableJetStream` (a deferred call at line 205).
Per stream, `rt` is taken at line 1555 and charged at line 1658 — **after** `a.recoverStream` returns,
which (see `server/stream.go` below) includes everything `addStreamWithAssignment` does, source
consumers included on an R1 stream.

```go
   203		s.Noticef("Starting JetStream")
   204		start := time.Now()
   205		defer func() {
   206			s.Noticef("Took %s to start JetStream", time.Since(start))
   207		}()
```

Streams of an account are recovered through one task queue whose width is the disk I/O semaphore,
capped at 64 (`max_concurrent_io`, `server/opts.go` below; 2.11.11 / 2.12.2 made this parallel):

```go
   749	func (s *Server) enableJetStreamAccounts() error {
   750		// Reuse the same task workers across all accounts, so that we don't explode
   751		// with a large number of goroutines on multi-account systems.
   752		tq := parallelTaskQueue(min(64, s.diskIOSemaphore().cap()))
   753		defer close(tq)
```

```go
  1554			s.Noticef("  Starting restore for stream '%s > %s'", a.Name, cfg.StreamConfig.Name)
  1555			rt := time.Now()
```

```go
  1568			// Add in the stream.
  1569			mset, err := a.recoverStream(&cfg.StreamConfig)
  1570			if err != nil {
  1571				s.Warnf("  Error recreating stream %q: %v", cfg.Name, err)
```

```go
  1657			state := mset.state()
  1658			s.Noticef("  Restored %s messages for stream '%s > %s' in %v",
  1659				comma(int64(state.Msgs)), mset.accName(), mset.name(), time.Since(rt).Round(time.Millisecond))
```

```go
  1675		if tq != nil {
  1676			// If a parallelTaskQueue was provided then use that for concurrency.
  1677			var wg sync.WaitGroup
  1678			wg.Add(len(fis))
  1679			for _, fi := range fis {
  1680				tq <- func() {
  1681					doStream(fi)
  1682					wg.Done()
  1683				}
  1684			}
  1685			wg.Wait()
  1686		} else {
  1687			// No parallelTaskQueue provided, do inline as before.
  1688			for _, fi := range fis {
  1689				doStream(fi)
  1690			}
  1691		}
```

## server/stream.go

### `recoverStream` is `addStreamWithAssignment` with `recovering = true`, and on a single server it becomes leader inline

```go
   724	func (a *Account) recoverStream(config *StreamConfig) (*stream, error) {
   725		return a.addStreamWithAssignment(config, nil, nil, false, true)
   726	}
```

```go
  1053		// Call directly to set leader if not in clustered mode.
  1054		// This can be called though before we actually setup clustering, so check both.
  1055		if singleServerMode {
  1056			if err := mset.setLeader(true, 0); err != nil {
  1057				mset.stop(true, false)
  1058				return nil, err
  1059			}
  1060		}
```

### `setLeader` → `subscribeToStream` → `setupSourceConsumers`, inline on R1, deferred by 100–600 ms on R3

```go
  1274	func (mset *stream) setLeader(isLeader bool, term uint64) error {
  1275		mset.mu.Lock()
  1276		wasLeader := mset.leader.Swap(isLeader)
  1277	
  1278		// We can skip the teardown if we were leader before and are still the leader now.
  1279		// But only at term 1, since that means scale up from or down to an unreplicated config.
  1280		// R1 assets have no raft node and use the coerced term 1.
  1281		if term < 1 {
  1282			term = 1
  1283		}
  1284		skipTeardown := wasLeader && isLeader && term == 1
  1285		mset.term = term
  1286		if !skipTeardown {
  1287			// cancel timer to create the source consumers if not fired yet
  1288			if mset.sourcesConsumerSetup != nil {
  1289				mset.sourcesConsumerSetup.Stop()
  1290				mset.sourcesConsumerSetup = nil
  1291			} else {
  1292				// Stop any source consumers
  1293				mset.stopSourceConsumers()
  1294			}
  1295	
  1296			// Stop responding to sync requests.
  1297			mset.stopClusterSubs()
  1298			// Unsubscribe from direct stream.
  1299			mset.unsubscribeToStream(false, false)
  1300			// Clear catchup state
  1301			mset.clearAllCatchupPeers()
  1302			mset.store.ResetState()
  1303		}
  1304	
  1305		// If we are here we have a change in leader status.
  1306		if isLeader {
  1307			// Make sure we are listening for sync requests.
  1308			// TODO(dlc) - Original design was that all in sync members of the group would do DQ.
  1309			if mset.isClustered() {
  1310				mset.startClusterSubs()
  1311			}
  1312	
  1313			// Setup subscriptions if we were not already the leader.
  1314			if err := mset.subscribeToStream(); err != nil {
  1315				if mset.isClustered() {
  1316					// Stepdown since we have an error.
  1317					mset.node.StepDown()
  1318				}
  1319				mset.mu.Unlock()
  1320				return err
```

```go
  4926	// Will create internal subscriptions for the stream.
  4927	// Lock should be held.
  4928	func (mset *stream) subscribeToStream() error {
  4929		if mset.active {
  4930			return nil
  4931		}
  4932		for _, subject := range mset.cfg.Subjects {
  4933			if _, err := mset.subscribeInternal(subject, mset.processInboundJetStreamMsg); err != nil {
  4934				return err
  4935			}
  4936		}
```

```go
  4958		} else if len(mset.cfg.Sources) > 0 && mset.sourcesConsumerSetup == nil {
  4959			// Setup the initial source infos for the sources
  4960			mset.resetSourceInfo()
  4961			// Delay the actual source consumer(s) creation(s) for after a delay if a replicated stream.
  4962			// If it's an R1, this is done at startup and we will do inline.
  4963			if mset.cfg.Replicas == 1 {
  4964				mset.setupSourceConsumers()
  4965			} else {
  4966				mset.sourcesConsumerSetup = time.AfterFunc(time.Duration(rand.Intn(int(500*time.Millisecond)))+100*time.Millisecond, func() {
  4967					mset.mu.Lock()
  4968					mset.setupSourceConsumers()
  4969					mset.mu.Unlock()
  4970				})
  4971			}
  4972		}
```

### `setupSourceConsumers` calls the scan first, then creates one consumer per source at `sseq + 1`

```go
  4896	// Setup our source consumers.
  4897	// Lock should be held.
  4898	func (mset *stream) setupSourceConsumers() error {
  4899		if mset.outq == nil {
  4900			return errors.New("outq required")
  4901		}
  4902		// Reset if needed.
  4903		for _, si := range mset.sources {
  4904			if si.sub != nil {
  4905				mset.cancelSourceConsumer(si.iname)
  4906			}
  4907		}
  4908	
  4909		// If we are no longer the leader, give up
  4910		if !mset.isLeader() {
  4911			return nil
  4912		}
  4913	
  4914		mset.startingSequenceForSources()
  4915	
  4916		// Setup our consumers at the proper starting position.
  4917		for _, ssi := range mset.cfg.Sources {
  4918			if si := mset.sources[ssi.iname]; si != nil {
  4919				mset.setupSourceConsumer(ssi.iname, si.sseq+1, time.Time{})
  4920			}
  4921		}
  4922	
  4923		return nil
  4924	}
```

### `startingSequenceForSources` — the backward scan

"Always reset" (line 4792–4793): whatever the stream knew about its sources before is discarded on
every call. The loop at 4866–4893 walks from `state.LastSeq` **backwards** with `LoadPrevMsgMulti`,
reads the `Nats-Stream-Source` header of each message that carries one, records the source it names
and removes that source from the sublist, and returns early only when every configured source has
been seen (`len(seqs) == expected`, line 4890). A source that has **no message in the stream** —
never delivered anything, or was added after the last message it would have matched — keeps the loop
running until `ErrStoreEOF`, i.e. sequence 1.

```go
  4787	func (mset *stream) startingSequenceForSources() {
  4788		if len(mset.cfg.Sources) == 0 {
  4789			return
  4790		}
  4791	
  4792		// Always reset here.
  4793		mset.resetSourceInfo()
  4794	
  4795		var state StreamState
  4796		mset.store.FastState(&state)
  4797	
  4798		// Bail if no messages, meaning no context.
  4799		if state.Msgs == 0 {
  4800			return
  4801		}
  4802	
  4803		// For short circuiting return.
  4804		expected := len(mset.cfg.Sources)
  4805		seqs := make(map[string]uint64)
  4806	
  4807		// Stamp our si seq records on the way out.
  4808		defer func() {
  4809			for sname, seq := range seqs {
  4810				// Ignore if not set.
  4811				if seq == 0 {
  4812					continue
  4813				}
  4814				if si := mset.sources[sname]; si != nil {
  4815					si.sseq = seq
  4816					si.dseq = 0
  4817				}
  4818			}
  4819		}()
  4820	
  4821		// Generate a list of sources and, from that, a sublist that contains
  4822		// the interested filters (including transforms). As we figure out the
  4823		// starting sequence for each source, we will eliminate the source from
  4824		// the map and then refresh the sublist, which in turn makes the sublist
  4825		// ideally more specific. This allows LoadPrevMsgsMulti to work most
  4826		// effectively.
  4827		// Because this is a SimpleSublist we can't just remove the entries per
  4828		// source so we have no other option but to rebuild it from scratch, but
  4829		// this is cheap enough to do so not the end of the world.
  4830		sources := map[string]*StreamSource{}
  4831		for _, src := range mset.cfg.Sources {
  4832			sources[src.composeIName()] = src
  4833		}
  4834		var sl *gsl.SimpleSublist
  4835		refreshSublist := func() {
  4836			sl = gsl.NewSimpleSublist()
  4837			for _, src := range sources {
  4838				if src.FilterSubject == _EMPTY_ {
  4839					sl.Insert(fwcs, struct{}{})
  4840				} else {
  4841					sl.Insert(src.FilterSubject, struct{}{})
  4842				}
  4843				for _, tr := range src.SubjectTransforms {
  4844					if tr.Destination == _EMPTY_ {
  4845						sl.Insert(fwcs, struct{}{})
  4846					} else {
  4847						sl.Insert(tr.Destination, struct{}{})
  4848					}
  4849				}
  4850			}
  4851		}
  4852		refreshSublist()
  4853	
  4854		update := func(iName string, seq uint64) {
  4855			// Only update active in case we have older ones in here that got configured out.
  4856			if si := mset.sources[iName]; si != nil {
  4857				if _, ok := seqs[iName]; !ok {
  4858					seqs[iName] = seq
  4859					delete(sources, iName)
  4860					refreshSublist()
  4861				}
  4862			}
  4863		}
  4864	
  4865		var smv StoreMsg
  4866		for last := state.LastSeq; ; {
  4867			sm, seq, err := mset.store.LoadPrevMsgMulti(sl, last, &smv)
  4868			if err == ErrStoreEOF || err != nil {
  4869				break
  4870			}
  4871			last = seq - 1
  4872			if len(sm.hdr) == 0 {
  4873				continue
  4874			}
  4875			ss := sliceHeader(JSStreamSource, sm.hdr)
  4876			if len(ss) == 0 {
  4877				continue
  4878			}
  4879	
  4880			streamName, iName, sseq := streamAndSeq(bytesToString(ss))
  4881			if iName == _EMPTY_ { // Pre-2.10 message header means it's a match for any source using that stream name
  4882				for _, ssi := range mset.cfg.Sources {
  4883					if streamName == ssi.Name || (ssi.External != nil && streamName == ssi.Name+":"+getHash(ssi.External.ApiPrefix)) {
  4884						update(ssi.iname, sseq)
  4885					}
  4886				}
  4887			} else {
  4888				update(iName, sseq)
  4889			}
  4890			if len(seqs) == expected {
  4891				return
  4892			}
  4893		}
  4894	}
```

## server/filestore.go

### The per-subject index in memory, and the threshold

`psim` is the in-memory per-subject index (an adaptive radix tree of `psi`: total messages, first and
last block). `highCardinalityThreshold` is a code constant, not a configuration key.

```go
   169	type psi struct {
   170		total uint64
   171		fblk  uint32
   172		lblk  uint32
   173	}
```

```go
   195		blks        []*msgBlock
   196		bim         map[uint32]*msgBlock
   197		psim        *stree.SubjectTree[psi]
   198		tsl         int
```

```go
   385		// Checksum size for hash for msg records.
   386		recordHashSize = 8
   387	
   388		// Above this number of subjects, index.db may not be written regularly anymore, and
   389		// certain psim optimisations may not be used.
   390		highCardinalityThreshold = 1_000_000
   391	)
```

```go
  8850		errStateTooBig   = errors.New("store state too big for optional write")
```

### The decision at store creation: try `index.db`, else read every block

`newFileStoreWithCreated`: `recoverFullState` is attempted first; on **any** error — file missing,
checksum mismatch, stale, corrupt — the state is reset and `recoverMsgs` reads the blocks. A missing
file is silent (`os.IsNotExist`); every other refusal logs `Recovering stream state from index
errored: …` in addition to the specific `Stream state …` warning.

```go
   509		// Attempt to recover our state.
   510		err = fs.recoverFullState()
   511		if err != nil {
   512			if !os.IsNotExist(err) {
   513				fs.warn("Recovering stream state from index errored: %v", err)
   514			}
   515			// Hold onto state
   516			prior := fs.state
   517			// Reset anything that could have been set from above.
   518			fs.state = StreamState{}
   519			fs.psim, fs.tsl = fs.psim.Empty(), 0
   520			fs.bim = make(map[uint32]*msgBlock)
   521			fs.blks = nil
   522			fs.tombs = nil
   523	
   524			// Recover our message state the old way
   525			if err := fs.recoverMsgs(); err != nil {
   526				return nil, err
   527			}
   528	
   529			fs.mu.Lock()
   530			// Check if our prior state remembers a last sequence past where we can see.
   531			// Unless we're async flushing, in which case this can happen if some blocks weren't flushed.
   532			if prior.LastSeq > fs.state.LastSeq && !fs.fcfg.AsyncFlush {
   533				if mb, err := fs.newMsgBlockForWrite(); err != nil {
   534					fs.mu.Unlock()
   535					return nil, err
   536				} else if err = mb.writeTombstone(prior.LastSeq, prior.LastTime.UnixNano()); err != nil {
   537					fs.mu.Unlock()
   538					return nil, err
   539				}
   540				fs.state.LastSeq, fs.state.LastTime = prior.LastSeq, prior.LastTime
   541				if fs.state.Msgs == 0 {
   542					fs.state.FirstSeq = fs.state.LastSeq + 1
   543					fs.state.FirstTime = time.Time{}
   544				}
   545			}
   546			// Since we recovered here, make sure to kick ourselves to write out our stream state.
   547			fs.dirty++
   548			fs.mu.Unlock()
   549		}
```

### `fs.warn` — the `Filestore [<stream>]` prefix every warning below carries

```go
  1861	func (fs *fileStore) warn(format string, args ...any) {
  1862		// No-op if no server configured.
  1863		if fs.srv == nil {
  1864			return
  1865		}
  1866		fs.srv.Warnf(fmt.Sprintf("Filestore [%s] %s", fs.cfg.Name, format), args...)
  1867	}
```

### `recoverFullState` — read `index.db`, rebuild `psim`, list the blocks without opening them, then decide whether to trust it

The file is trusted only if (a) the HighwayHash at its end matches (1956–1966), (b) the last block it
names exists on disk (2151–2158), (c) that block's **last record checksum** equals the one written into
the file (2159–2163 — the check a SIGKILL after the last periodic write fails), and (d) no block with a
higher index exists (2176–2190). Failing (b)–(d) returns `errPriorState` with a `Stream state …`
warning and the caller falls back to `recoverMsgs`.

```go
  1927	func (fs *fileStore) recoverFullState() (rerr error) {
  1928		fs.mu.Lock()
  1929		defer fs.mu.Unlock()
  1930	
  1931		// Check for any left over purged messages.
  1932		fs.dios.acquire()
  1933		if err := fs.recoverPartialPurge(); err != nil {
  1934			fs.dios.release()
  1935			return err
  1936		}
  1937		// Grab our stream state file and load it in.
  1938		fn := filepath.Join(fs.fcfg.StoreDir, msgDir, streamStreamStateFile)
  1939		buf, err := os.ReadFile(fn)
  1940		fs.dios.release()
  1941	
  1942		if err != nil {
  1943			if !os.IsNotExist(err) {
  1944				fs.warn("Could not read stream state file: %v", err)
  1945			}
  1946			return err
  1947		}
  1948	
  1949		const minLen = 32
  1950		if len(buf) < minLen {
  1951			_ = os.Remove(fn)
  1952			fs.warn("Stream state too short (%d bytes)", len(buf))
  1953			return errCorruptState
  1954		}
  1955	
  1956		// The highwayhash will be on the end. Check that it still matches.
  1957		h := buf[len(buf)-highwayhash.Size64:]
  1958		buf = buf[:len(buf)-highwayhash.Size64]
  1959		fs.hh.Reset()
  1960		fs.hh.Write(buf)
  1961		var hb [highwayhash.Size64]byte
  1962		if !bytes.Equal(h, fs.hh.Sum(hb[:0])) {
  1963			_ = os.Remove(fn)
  1964			fs.warn("Stream state checksum did not match")
  1965			return errCorruptState
  1966		}
  1967	
  1968		// Decrypt if needed.
  1969		// We can be setup for encryption but if this is a snapshot restore we will be missing the keyfile
  1970		// since snapshots strip encryption.
  1971		if fs.prf != nil && fs.aek != nil {
  1972			ns := fs.aek.NonceSize()
  1973			buf, err = fs.aek.Open(nil, buf[:ns], buf[ns:], nil)
  1974			if err != nil {
  1975				fs.warn("Stream state error reading encryption key: %v", err)
  1976				return err
  1977			}
  1978		}
  1979	
  1980		version := buf[1]
  1981		if buf[0] != fullStateMagic || version < fullStateMinVersion || version > fullStateVersion {
  1982			_ = os.Remove(fn)
  1983			fs.warn("Stream state magic and version mismatch")
  1984			return errCorruptState
  1985		}
  1986	
  1987		bi := hdrLen
  1988	
  1989		readU64 := func() uint64 {
  1990			if bi < 0 {
  1991				return 0
  1992			}
  1993			v, n := binary.Uvarint(buf[bi:])
  1994			if n <= 0 {
  1995				bi = -1
  1996				return 0
  1997			}
  1998			bi += n
  1999			return v
  2000		}
  2001		readI64 := func() int64 {
  2002			if bi < 0 {
  2003				return 0
  2004			}
  2005			v, n := binary.Varint(buf[bi:])
  2006			if n <= 0 {
  2007				bi = -1
  2008				return -1
  2009			}
  2010			bi += n
  2011			return v
  2012		}
  2013	
  2014		setTime := func(t *time.Time, ts int64) {
  2015			if ts == 0 {
  2016				*t = time.Time{}
  2017			} else {
  2018				*t = time.Unix(0, ts).UTC()
  2019			}
  2020		}
  2021	
  2022		var state StreamState
  2023		state.Msgs = readU64()
  2024		state.Bytes = readU64()
  2025		state.FirstSeq = readU64()
  2026		baseTime := readI64()
  2027		setTime(&state.FirstTime, baseTime)
  2028		state.LastSeq = readU64()
  2029		setTime(&state.LastTime, readI64())
  2030	
  2031		// Check for per subject info.
  2032		if numSubjects := int(readU64()); numSubjects > 0 {
  2033			fs.psim, fs.tsl = fs.psim.Empty(), 0
  2034			for i := 0; i < numSubjects; i++ {
  2035				if lsubj := int(readU64()); lsubj > 0 {
  2036					if bi+lsubj > len(buf) {
  2037						_ = os.Remove(fn)
  2038						fs.warn("Stream state bad subject len (%d)", lsubj)
  2039						return errCorruptState
  2040					}
  2041					// If we have lots of subjects this will alloc for each one.
  2042					// We could reference the underlying buffer, but we could guess wrong if
  2043					// number of blocks is large and subjects is low, since we would reference buf.
  2044					subj := buf[bi : bi+lsubj]
  2045					// We had a bug that could cause memory corruption in the PSIM that could have gotten stored to disk.
  2046					// Only would affect subjects, so do quick check.
  2047					if !isValidSubject(bytesToString(subj), true) {
  2048						_ = os.Remove(fn)
  2049						fs.warn("Stream state corrupt subject detected")
  2050						return errCorruptState
  2051					}
  2052					bi += lsubj
  2053					psi := psi{total: readU64(), fblk: uint32(readU64())}
  2054					if psi.total > 1 || version >= 4 {
  2055						psi.lblk = uint32(readU64())
  2056					} else {
  2057						psi.lblk = psi.fblk
  2058					}
  2059					fs.psim.Insert(subj, psi)
  2060					fs.tsl += lsubj
  2061				}
  2062			}
  2063		}
  2064	
  2065		// Track the state as represented by the blocks themselves.
  2066		var mstate StreamState
  2067	
  2068		if numBlocks := readU64(); numBlocks > 0 {
  2069			lastIndex := int(numBlocks - 1)
  2070			fs.blks = make([]*msgBlock, 0, numBlocks)
  2071			for i := 0; i < int(numBlocks); i++ {
  2072				index, nbytes, fseq, fts, lseq, lts, numDeleted := uint32(readU64()), readU64(), readU64(), readI64(), readU64(), readI64(), readU64()
  2073				var ttls uint64
  2074				if version >= 2 {
  2075					ttls = readU64()
  2076				}
  2077				var schedules uint64
  2078				if version >= 3 {
  2079					schedules = readU64()
  2080				}
  2081				if bi < 0 {
  2082					_ = os.Remove(fn)
  2083					return errCorruptState
  2084				}
  2085				mb := fs.initMsgBlock(index)
  2086				atomic.StoreUint64(&mb.first.seq, fseq)
  2087				atomic.StoreUint64(&mb.last.seq, lseq)
  2088				mb.msgs, mb.bytes = lseq-fseq+1, nbytes
  2089				mb.first.ts, mb.last.ts = fts+baseTime, lts+baseTime
  2090				mb.ttls = ttls
  2091				mb.schedules = schedules
  2092				if numDeleted > 0 {
  2093					dmap, n, err := avl.Decode(buf[bi:])
  2094					if err != nil {
  2095						_ = os.Remove(fn)
  2096						fs.warn("Stream state error decoding avl dmap: %v", err)
  2097						return errCorruptState
  2098					}
  2099					mb.dmap = *dmap
  2100					if mb.msgs > numDeleted {
  2101						mb.msgs -= numDeleted
  2102					} else {
  2103						mb.msgs = 0
  2104					}
  2105					bi += n
  2106				}
  2107	
  2108				// Pre-emptively mark block as closed, we'll confirm this block
  2109				// still exists on disk and report it as lost if not.
  2110				mb.closed = true
  2111	
  2112				// Only add in if not empty or the lmb.
  2113				if mb.msgs > 0 || i == lastIndex {
  2114					fs.addMsgBlock(mb)
  2115					updateTrackingState(&mstate, mb)
  2116				} else {
  2117					// Mark dirty to cleanup.
  2118					fs.dirty++
  2119				}
  2120			}
  2121		}
  2122	
  2123		// Pull in last block index for the block that had last checksum when we wrote the full state.
  2124		blkIndex := uint32(readU64())
  2125		var lchk [8]byte
  2126		if bi+len(lchk) > len(buf) {
  2127			bi = -1
  2128		} else {
  2129			copy(lchk[0:], buf[bi:bi+len(lchk)])
  2130		}
  2131	
  2132		// Check if we had any errors.
  2133		if bi < 0 {
  2134			_ = os.Remove(fn)
  2135			fs.warn("Stream state has no checksum present")
  2136			return errCorruptState
  2137		}
  2138	
  2139		// Move into place our state, msgBlks and subject info.
  2140		fs.state = state
  2141	
  2142		// First let's check the happy path, open the blk file that was the lmb when we created the full state.
  2143		// See if we have the last block available.
  2144		var matched bool
  2145		mb := fs.lmb
  2146		if mb == nil || mb.index != blkIndex {
  2147			_ = os.Remove(fn)
  2148			fs.warn("Stream state block does not exist or index mismatch")
  2149			return errCorruptState
  2150		}
  2151		if _, err := os.Stat(mb.mfn); err != nil && os.IsNotExist(err) {
  2152			// If our saved state is past what we see on disk, fallback and rebuild.
  2153			if ld, _, _ := mb.rebuildState(); ld != nil {
  2154				fs.addLostData(ld)
  2155			}
  2156			fs.warn("Stream state detected prior state, could not locate msg block %d", blkIndex)
  2157			return errPriorState
  2158		}
  2159		if matched = bytes.Equal(mb.lastChecksum(), lchk[:]); !matched {
  2160			// Detected a stale index.db, we didn't write it upon shutdown so can't rely on it being correct.
  2161			fs.warn("Stream state outdated, last block has additional entries, will rebuild")
  2162			return errPriorState
  2163		}
  2164	
  2165		// We need to see if any blocks exist after our last one even though we matched the last record exactly.
  2166		mdir := filepath.Join(fs.fcfg.StoreDir, msgDir)
  2167		var dirs []os.DirEntry
  2168	
  2169		fs.dios.acquire()
  2170		if f, err := os.Open(mdir); err == nil {
  2171			dirs, _ = f.ReadDir(-1)
  2172			f.Close()
  2173		}
  2174		fs.dios.release()
  2175	
  2176		var index uint32
  2177		for _, fi := range dirs {
  2178			// Ensure it's actually a block file, otherwise fmt.Sscanf also matches %d.blk.tmp
  2179			if !strings.HasSuffix(fi.Name(), blkSuffix) {
  2180				continue
  2181			}
  2182			if n, err := fmt.Sscanf(fi.Name(), blkScan, &index); err == nil && n == 1 {
  2183				if index > blkIndex {
  2184					fs.warn("Stream state outdated, found extra blocks, will rebuild")
  2185					return errPriorState
  2186				} else if mb, ok := fs.bim[index]; ok {
  2187					mb.closed = false
  2188				}
  2189			}
  2190		}
  2191	
  2192		var rebuild bool
  2193		for _, mb := range fs.blks {
  2194			if mb.closed {
  2195				rebuild = true
  2196				if ld, _, _ := mb.rebuildState(); ld != nil {
  2197					fs.addLostData(ld)
  2198				}
  2199				fs.warn("Stream state detected prior state, could not locate msg block %d", mb.index)
  2200			}
  2201		}
  2202		if rebuild {
  2203			return errPriorState
  2204		}
  2205	
  2206		// We check first and last seq and number of msgs and bytes. If there is a difference,
  2207		// return and error so we rebuild from the message block state on disk.
  2208		if !trackingStatesEqual(&fs.state, &mstate) {
  2209			_ = os.Remove(fn)
  2210			fs.warn("Stream state encountered internal inconsistency on recover")
  2211			return errCorruptState
  2212		}
  2213	
  2214		return nil
  2215	}
  2216	
```

### `recoverMsgs` — every `<n>.blk` in index order, through `recoverMsgBlock`

```go
  2454	func (fs *fileStore) recoverMsgs() error {
  2455		fs.mu.Lock()
  2456		defer fs.mu.Unlock()
  2457	
  2458		// Check for any left over purged messages.
  2459		fs.dios.acquire()
  2460		if err := fs.recoverPartialPurge(); err != nil {
  2461			fs.dios.release()
  2462			return err
  2463		}
  2464		mdir := filepath.Join(fs.fcfg.StoreDir, msgDir)
  2465		f, err := os.Open(mdir)
  2466		if err != nil {
  2467			fs.dios.release()
  2468			return errNotReadable
  2469		}
  2470		dirs, err := f.ReadDir(-1)
  2471		f.Close()
  2472		fs.dios.release()
  2473	
  2474		if err != nil {
  2475			return errNotReadable
  2476		}
  2477	
  2478		indices := make(sort.IntSlice, 0, len(dirs))
  2479		var index int
  2480		for _, fi := range dirs {
  2481			// Ensure it's actually a block file, otherwise fmt.Sscanf also matches %d.blk.tmp
  2482			if !strings.HasSuffix(fi.Name(), blkSuffix) {
  2483				continue
  2484			}
  2485			if n, err := fmt.Sscanf(fi.Name(), blkScan, &index); err == nil && n == 1 {
  2486				indices = append(indices, index)
  2487			}
  2488		}
  2489		indices.Sort()
  2490	
  2491		// Recover all of the msg blocks.
  2492		// We now guarantee they are coming in order.
  2493		for _, index := range indices {
  2494			if mb, err := fs.recoverMsgBlock(uint32(index)); err == nil && mb != nil {
```

```go
  2559		if len(fs.blks) > 0 {
  2560			fs.lmb = fs.blks[len(fs.blks)-1]
  2561		} else if _, err = fs.newMsgBlockForWrite(); err != nil {
  2562			return err
  2563		}
```

### `recoverMsgBlock` and `rebuildState` — the whole block file read and walked record by record

The `.idx` path at 1278–1294 is for stores written before 2.10 only; a 2.10+ block has no index file,
so `mb.rebuildState()` runs: `loadBlock` reads the whole file, decrypts and decompresses it, and
`rebuildStateFromBufLocked` walks every record to rebuild counts, the delete map and the per-block
subject state, after which `populateGlobalPerSubjectInfo` folds the block's subjects into `psim`.

```go
  1232	func (fs *fileStore) recoverMsgBlock(index uint32) (*msgBlock, error) {
  1233		mb := fs.initMsgBlock(index)
  1234		// Open up the message file, but we will try to recover from the index file.
  1235		// We will check that the last checksums match.
  1236		file, err := mb.openBlock()
  1237		if err != nil {
  1238			return nil, err
  1239		}
  1240		defer file.Close()
  1241	
  1242		if fi, err := file.Stat(); fi != nil {
  1243			mb.rbytes = uint64(fi.Size())
  1244		} else {
  1245			return nil, err
  1246		}
  1247	
  1248		// Make sure encryption loaded if needed.
  1249		if err = fs.loadEncryptionForMsgBlock(mb); err != nil {
  1250			// If the encryption key is truncated or unrecoverable, return the block so it can be deleted.
  1251			if err == errBadKeySize || err == errKeyInvalid {
  1252				return mb, err
  1253			}
  1254			return nil, err
  1255		}
  1256	
  1257		// Grab last checksum from main block file.
  1258		var lchk [8]byte
  1259		if mb.rbytes >= checksumSize {
  1260			if mb.bek != nil {
  1261				// We pass nil, so get a buf from the block pool, we'll need to recycle it afterward.
  1262				buf, _ := mb.loadBlock(nil)
  1263				if len(buf) >= checksumSize {
  1264					mb.bek.XORKeyStream(buf, buf)
  1265					copy(lchk[0:], buf[len(buf)-checksumSize:])
  1266				}
  1267				// We can recycle it now.
  1268				recycleMsgBlockBuf(buf)
  1269			} else if _, err = file.ReadAt(lchk[:], int64(mb.rbytes)-checksumSize); err != nil {
  1270				return nil, err
  1271			}
  1272		}
  1273	
  1274		if err = file.Close(); err != nil {
  1275			return nil, err
  1276		}
  1277	
  1278		// Read our index file. Use this as source of truth if possible.
  1279		// This not applicable in >= 2.10 servers. Here for upgrade paths from < 2.10.
  1280		if err := mb.readIndexInfo(); err == nil {
  1281			// Quick sanity check here.
  1282			// Note this only checks that the message blk file is not newer then this file, or is empty and we expect empty.
  1283			if (mb.rbytes == 0 && mb.msgs == 0) || bytes.Equal(lchk[:], mb.lchk[:]) {
  1284				if mb.msgs > 0 && !mb.noTrack && fs.psim != nil {
  1285					if err = fs.populateGlobalPerSubjectInfo(mb); err != nil {
  1286						return nil, err
  1287					}
  1288					// Try to dump any state we needed on recovery.
  1289					mb.tryForceExpireCacheLocked()
  1290				}
  1291				fs.addMsgBlock(mb)
  1292				return mb, nil
  1293			}
  1294		}
  1295	
  1296		// If we get data loss rebuilding the message block state record that with the fs itself.
  1297		ld, tombs, err := mb.rebuildState()
  1298		if err != nil {
  1299			return nil, err
  1300		} else if ld != nil {
  1301			fs.addLostData(ld)
  1302		}
  1303		// Collect all tombstones.
  1304		if len(tombs) > 0 {
  1305			fs.tombs = append(fs.tombs, tombs...)
  1306		}
  1307	
  1308		if mb.msgs > 0 && !mb.noTrack && fs.psim != nil {
  1309			if err = fs.populateGlobalPerSubjectInfo(mb); err != nil {
  1310				return nil, err
  1311			}
  1312			// Try to dump any state we needed on recovery.
  1313			mb.tryForceExpireCacheLocked()
  1314		}
  1315	
  1316		if err = mb.closeFDs(); err != nil {
  1317			return nil, err
  1318		}
  1319		fs.addMsgBlock(mb)
  1320	
  1321		return mb, nil
  1322	}
```

```go
  1558	func (mb *msgBlock) rebuildState() (*LostStreamData, []uint64, error) {
  1559		mb.mu.Lock()
  1560		defer mb.mu.Unlock()
  1561		return mb.rebuildStateLocked()
  1562	}
  1563	
  1564	// Rebuild the state of the blk based on what we have on disk in the N.blk file.
  1565	// Lock should be held.
  1566	func (mb *msgBlock) rebuildStateLocked() (*LostStreamData, []uint64, error) {
  1567		// Remove the .fss file and clear any cache we have set.
  1568		mb.clearCacheAndOffset()
  1569	
  1570		buf, err := mb.loadBlock(nil)
  1571		defer recycleMsgBlockBuf(buf)
  1572	
  1573		if err != nil || len(buf) == 0 {
  1574			// Only allow continuing to mark lost data if the file itself doesn't exist, or was empty.
  1575			if err != nil && err != errNoBlkData {
  1576				return nil, nil, err
  1577			}
  1578			var ld *LostStreamData
  1579			// No data to rebuild from here.
  1580			if mb.msgs > 0 {
  1581				// We need to declare lost data here.
  1582				ld = &LostStreamData{Msgs: make([]uint64, 0, mb.msgs), Bytes: mb.bytes}
  1583				firstSeq, lastSeq := atomic.LoadUint64(&mb.first.seq), atomic.LoadUint64(&mb.last.seq)
  1584				for seq := firstSeq; seq <= lastSeq; seq++ {
  1585					if !mb.dmap.Exists(seq) {
  1586						ld.Msgs = append(ld.Msgs, seq)
  1587					}
  1588				}
  1589				// Clear invalid state. We will let this blk be added in here.
  1590				mb.msgs, mb.bytes, mb.rbytes, mb.fss = 0, 0, 0, nil
  1591				mb.dmap.Empty()
  1592				atomic.StoreUint64(&mb.first.seq, atomic.LoadUint64(&mb.last.seq)+1)
  1593			}
  1594			return ld, nil, nil
  1595		}
  1596	
  1597		// Check if we need to decrypt.
  1598		if err = mb.encryptOrDecryptIfNeeded(buf); err != nil {
  1599			return nil, nil, err
  1600		}
  1601		// Check for compression.
  1602		if buf, err = mb.decompressIfNeeded(buf); err != nil {
  1603			return nil, nil, err
  1604		}
  1605		return mb.rebuildStateFromBufLocked(buf, true)
  1606	}
  1607	
  1608	// Lock should be held.
  1609	func (mb *msgBlock) rebuildStateFromBufLocked(buf []byte, allowTruncate bool) (*LostStreamData, []uint64, error) {
  1610		var err error
  1611		startLastSeq := atomic.LoadUint64(&mb.last.seq)
  1612	
  1613		// Clear state we need to rebuild.
  1614		mb.msgs, mb.bytes, mb.rbytes, mb.fss = 0, 0, 0, nil
  1615		atomic.StoreUint64(&mb.last.seq, 0)
  1616		mb.last.ts = 0
  1617		firstNeedsSet := true
  1618	
  1619		mb.rbytes = uint64(len(buf))
  1620	
```

### `flushStreamStateLoop`, `writeFullState`, `forceWriteFullState` — when `index.db` is written, and when the periodic write is skipped

The ticker is **2 minutes plus up to 30 seconds of jitter** per store (11904–11906). The unforced write
returns `errStateTooBig` without writing when the stream has more than 1,000,000 subjects **or** more
than 1,000,000 interior deletes (12000–12010). The forced write — purge, and `stop(delete, writeState)`
on a clean shutdown (12251–12256 below) — ignores the threshold.

```go
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
```

```go
 11935	// writeFullState will proceed to write the full meta state iff not complex and time consuming.
 11936	// Since this is for quick recovery it is optional and should not block/stall normal operations.
 11937	func (fs *fileStore) writeFullState() error {
 11938		return fs._writeFullState(false)
 11939	}
 11940	
 11941	// forceWriteFullState will proceed to write the full meta state.
 11942	func (fs *fileStore) forceWriteFullState() error {
 11943		return fs._writeFullState(true)
 11944	}
 11945	
 11946	// This will write the full binary state for the stream.
 11947	// This plus everything new since last hash will be the total recovered state.
 11948	// This state dump will have the following.
 11949	// 1. Stream summary - Msgs, Bytes, First and Last (Sequence and Timestamp)
 11950	// 2. PSIM - Per Subject Index Map - Tracks first and last blocks with subjects present.
 11951	// 3. MBs - Index, Bytes, First and Last Sequence and Timestamps, and the deleted map (avl.seqset).
 11952	// 4. Last block index and hash of record inclusive to this stream state.
 11953	func (fs *fileStore) _writeFullState(force bool) error {
 11954		if fs.isClosed() {
 11955			return nil
 11956		}
 11957	
 11958		// If we aren't forcing an update then only queue this up if we aren't already
 11959		// running. This means we can keep waiting on shutdown if needed but not build up
 11960		// lots of waiting goroutines in a bad timer case.
 11961		if fs.wfsrun.Add(1) > 1 && !force {
 11962			fs.wfsrun.Add(-1)
 11963			return nil
 11964		}
 11965		defer fs.wfsrun.Add(-1)
 11966	
 11967		// Only allow one _writeFullState to take place at a time, otherwise we can
 11968		// have multiple goroutines trying to write the same file after we've released
 11969		// the store lock.
 11970		fs.wfsmu.Lock()
 11971		defer fs.wfsmu.Unlock()
 11972	
 11973		start := time.Now()
 11974		fs.mu.RLock()
 11975		if fs.dirty == 0 {
 11976			fs.mu.RUnlock()
 11977			return nil
 11978		}
 11979	
 11980		// Configure encryption if needed.
 11981		if fs.prf != nil {
 11982			// Re-acquire temporarily as write lock to set up AEK.
 11983			fs.mu.RUnlock()
 11984			fs.mu.Lock()
 11985			err := fs.setupAEK()
 11986			fs.mu.Unlock()
 11987			if err != nil {
 11988				return err
 11989			}
 11990			fs.mu.RLock()
 11991		}
 11992	
 11993		// For calculating size and checking time costs for non forced calls.
 11994		numSubjects := fs.numSubjects()
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
```

### `stop` — the forced write on a clean stop

```go
 12216	func (fs *fileStore) stop(delete, writeState bool) error {
 12217		if fs.isClosed() {
 12218			return ErrStoreClosed
 12219		}
 12220	
 12221		fs.mu.Lock()
 12222		if fs.closing {
 12223			fs.mu.Unlock()
 12224			return ErrStoreClosed
 12225		}
 12226	
 12227		// Mark as closing. Do before releasing the lock to wait on the state flush loop
 12228		// so we don't end up with this function running more than once.
 12229		fs.closing = true
 12230	
 12231		// Release the state flusher loop.
 12232		if fs.qch != nil {
 12233			close(fs.qch)
 12234			fs.qch = nil
 12235		}
 12236	
 12237		if writeState {
 12238			// Wait for the state flush loop to exit.
 12239			fsld := fs.fsld
 12240			fs.mu.Unlock()
 12241			<-fsld
 12242			fs.mu.Lock()
 12243	
 12244			fs.checkAndFlushLastBlock()
 12245		}
 12246		fs.closeAllMsgBlocks(false)
 12247	
 12248		fs.cancelSyncTimer()
 12249		fs.cancelAgeChk()
 12250	
 12251		if writeState {
 12252			// Write full state if needed. If not dirty this is a no-op.
 12253			fs.mu.Unlock()
 12254			fs.forceWriteFullState()
 12255			fs.mu.Lock()
 12256		}
 12257	
 12258		// Mark as closed. Last message block needs to be cleared after
 12259		// writeFullState has completed.
 12260		fs.closed.Store(true)
 12261		fs.lmb = nil
 12262	
```

### `LoadPrevMsgMulti` and `prevMatchingMulti` — what one step of the backward scan costs

Under the store's read lock, from the block holding `start` down to block 0 (9704–9718). Per block,
`prevMatchingMulti` loads the block's messages into the cache if they are not there
(`loadMsgsWithLock`, 3199–3204): the whole block file, decompressed. That is the ~20 MB/s of constant
reads and the "< 2 cores" the row-13 reporter saw — one goroutine, one block at a time.

```go
  9683	func (fs *fileStore) LoadPrevMsgMulti(sl *gsl.SimpleSublist, start uint64, smp *StoreMsg) (sm *StoreMsg, skip uint64, err error) {
  9684		if fs.isClosed() {
  9685			return nil, 0, ErrStoreClosed
  9686		}
  9687	
  9688		if sl == nil || sl.MatchesFullWildcard() {
  9689			return fs.LoadPrevMsg(_EMPTY_, false, start, smp)
  9690		}
  9691		if filter, ok := sl.MatchesSingleFilter(); ok {
  9692			return fs.LoadPrevMsg(filter, subjectHasWildcard(filter), start, smp)
  9693		}
  9694		fs.mu.RLock()
  9695		defer fs.mu.RUnlock()
  9696	
  9697		if fs.state.Msgs == 0 || start < fs.state.FirstSeq {
  9698			return nil, fs.state.FirstSeq, ErrStoreEOF
  9699		}
  9700		if start > fs.state.LastSeq {
  9701			start = fs.state.LastSeq
  9702		}
  9703	
  9704		if bi, _ := fs.selectMsgBlockWithIndex(start); bi >= 0 {
  9705			for i := bi; i >= 0; i-- {
  9706				mb := fs.blks[i]
  9707				if sm, expireOk, err := mb.prevMatchingMulti(sl, start, smp); err == nil {
  9708					if expireOk {
  9709						mb.tryForceExpireCache()
  9710					}
  9711					return sm, sm.seq, nil
  9712				} else if err != ErrStoreMsgNotFound {
  9713					return nil, 0, err
  9714				} else if expireOk {
  9715					mb.tryForceExpireCache()
  9716				}
  9717			}
  9718		}
  9719	
  9720		return nil, fs.state.FirstSeq, ErrStoreEOF
  9721	}
```

```go
  3186	func (mb *msgBlock) prevMatchingMulti(sl *gsl.SimpleSublist, start uint64, sm *StoreMsg) (*StoreMsg, bool, error) {
  3187		mb.mu.Lock()
  3188		var didLoad bool
  3189		var updateLLTS bool
  3190		defer func() {
  3191			if updateLLTS {
  3192				mb.llts = ats.AccessTime()
  3193			}
  3194			mb.finishedWithCache()
  3195			mb.mu.Unlock()
  3196		}()
  3197	
  3198		// Need messages loaded from here on out.
  3199		if mb.cacheNotLoaded() {
  3200			if err := mb.loadMsgsWithLock(); err != nil {
  3201				return nil, false, err
  3202			}
  3203			didLoad = true
  3204		}
  3205	
  3206		// Make sure to start at mb.last.seq if lseq < mb.last.seq
  3207		if seq := atomic.LoadUint64(&mb.last.seq); start > seq {
  3208			start = seq
  3209		}
  3210		lseq := atomic.LoadUint64(&mb.first.seq)
  3211	
  3212		if sm == nil {
  3213			sm = new(StoreMsg)
  3214		}
  3215	
  3216		// If the FSS state has fewer entries than sequences in the linear scan,
  3217		// then use intersection instead as likely going to be cheaper. This will
  3218		// often be the case with high numbers of deletes, as well as a smaller
  3219		// number of subjects in the block.
  3220		if uint64(mb.fss.Size()) < start-lseq {
  3221			// If there are no subject matches then this is effectively no-op.
  3222			hseq := uint64(0)
  3223			var ierr error
  3224			stree.IntersectGSL(mb.fss, sl, func(subj []byte, ss *SimpleState) bool {
  3225				if ss.firstNeedsUpdate || ss.lastNeedsUpdate {
  3226					// mb is already loaded into the cache so should be fast-ish.
  3227					if ierr = mb.recalculateForSubj(bytesToString(subj), ss); ierr != nil {
  3228						return false
  3229					}
  3230				}
  3231				first := min(start, ss.Last)
  3232				// Skip if cutoff is before this subject's first, or if we already
  3233				// have a higher-or-equal candidate (hseq holds the highest found).
  3234				if first < ss.First || first <= hseq {
  3235					// The start cutoff is before the first sequence for this subject,
```

### `checkSkipFirstBlock` / `checkSkipFirstBlockMulti` — the second thing the threshold switches off

Above the threshold the filtered-read block skip is not attempted (3519–3521, 3544–3546): the reader
walks forward block by block instead of intersecting the whole subject index. Added in v2.14.2 /
v2.12.10 (#8227, below). The callers are `LoadNextMsgMulti` (line 9403) and `LoadNextMsg` (9477).

```go
  3511	func (fs *fileStore) checkSkipFirstBlock(filter string, wc bool, bi int) (int, error) {
  3512		// If we match everything, just move to next blk.
  3513		if filter == _EMPTY_ || filter == fwcs {
  3514			return bi + 1, nil
  3515		}
  3516		// Move through psim to gather start and stop bounds.
  3517		start, stop := uint32(math.MaxUint32), uint32(0)
  3518		if wc {
  3519			if fs.psim.Size() > highCardinalityThreshold {
  3520				return bi + 1, nil
  3521			}
  3522			fs.psim.Match(stringToBytes(filter), func(_ []byte, psi *psi) {
  3523				if psi.fblk < start {
  3524					start = psi.fblk
  3525				}
  3526				if psi.lblk > stop {
  3527					stop = psi.lblk
  3528				}
  3529			})
  3530		} else if psi, ok := fs.psim.Find(stringToBytes(filter)); ok {
  3531			start, stop = psi.fblk, psi.lblk
  3532		}
  3533		// Nothing was found.
  3534		if start == uint32(math.MaxUint32) {
  3535			return -1, ErrStoreEOF
  3536		}
  3537		return fs.selectSkipFirstBlock(bi, start, stop)
  3538	}
  3539	
  3540	// This is used to see if we can selectively jump start blocks based on filter subjects and a starting block index.
  3541	// Will return -1 and ErrStoreEOF if no matches at all or no more from where we are.
  3542	func (fs *fileStore) checkSkipFirstBlockMulti(sl *gsl.SimpleSublist, bi int) (int, error) {
  3543		// Don't bother if full wildcard.
  3544		if sl.MatchesFullWildcard() || fs.psim.Size() > highCardinalityThreshold {
  3545			return bi + 1, nil
  3546		}
  3547		// Move through psim to gather start and stop bounds.
  3548		start, stop := uint32(math.MaxUint32), uint32(0)
  3549		guard := fs.blks[bi].getIndex() + 1
  3550		stree.IntersectGSL(fs.psim, sl, func(subj []byte, psi *psi) bool {
```

## server/server.go and server/opts.go — `max_concurrent_io`

The recovery task queue above is `min(64, s.diskIOSemaphore().cap())`; the semaphore's capacity is
`jetstream { max_concurrent_io }` (since 2.14.4 — `s-relnotes-2.14.4`), accepted between 4 and 8192.

```go
  4794	func (s *Server) diskIOSemaphore() *diskIOSemaphore {
  4795		if s == nil || s.dios == nil {
  4796			return defaultDiskIOSemaphore()
  4797		}
  4798		return s.dios
  4799	}
```

```go
  2789				case "max_concurrent_io":
  2790					dios, ok := mv.(int64)
  2791					if !ok || dios < minConcurrentIOs || dios > maxConcurrentIOs {
  2792						return &configErr{tk, fmt.Sprintf("Expected an absolute size for %q between 4 and 8192, got %v", mk, mv)}
  2793					}
  2794					opts.JetStreamConcurrentIOs = int(dios)
```

## What changed around this, from the pull requests and release notes (GitHub API, fetched 2026-09-02)

### PR #8282 — `(2.15) [IMPROVED] Index stream sources to avoid backward scans` (merged 2026-08-20 into `main`)

> The second commit introduces indexing for stream sources, which will ensure that backward scanning
> for pre-existing stream sources is eliminated.
> - As messages come in, their `Nats-Stream-Source` is inspected and the source key is mapped to the
>   sequence that's sourced.
> - That state is kept in-memory and can be reused by methods like `mset.startingSequenceForSources()`
>   to use the index, and only fall back to backward scanning remaining sources if necessary.
> - This index is written to disk as `sources.db` when using file-based streams, similar to the
>   `thw.db` and `sched.db` files.
>
> The approach of having an index that scales by sources versus that scans the stream by messages
> results in a tremendous performance improvement, especially as streams get larger and the backward
> scan would otherwise need to reach way further back.
>
> The `sources.db` file is stored at the stream's root, as opposed to in the `msgs` directory, since
> it should not be removed if the stream is purged:
> ```
>   streams/<stream>/
>   ├── meta.inf, meta.sum,meta.key
> + ├── sources.db
>   ├── msgs/
>   │   ├── 1.blk, 2.blk, …
>   │   ├── index.db, thw.db, sched.db
>   └── obs/
>       └── <consumer>/…
> ```
>
> The third commit adds a check preventing users from publishing messages with the `Nats-Stream-Source`
> header directly. […] The fifth commit ensures the source state is replicated if the stream is,
> ensuring all replicas (especially as followers go offline, miss messages and are later caught up)
> end up at the same source state. Since it requires stream snapshot format changes, it requires an
> explicit opt-in of the `js_snapshot_sources` feature flag, which can become the default in 2.16.

### PR #8516 — `(2.15) [IMPROVED] Index all stream sources, drop stream-level scan` (merged 2026-08-28 into `main`)

> Previously we only indexed non-zero sources. However, if new sources were added but not used for an
> extended period of time, then backward scans would still happen every single time to come to the
> same conclusion of it not existing.
>
> This PR fixes that by fully removing the stream-level scan and ensuring the store-level scan always
> exposes the same information. Then the store only needs to scan once, and can reliably keep an
> up-to-date index. This also resolves the case where a source is added with no messages sourced,
> since the backward scan will only happen once and will be indexed/reused going forward.
>
> Note that `memStore` had no store-level scan at all and relied entirely on the stream-level one, so
> it gains a `recoverSourcesBackwardScan` of its own.

### Release lines (`repos/nats-io/nats-server/releases`, bodies as published)

- **v2.15.0-preview.1** (2026-08-24): *Stream source indexing (#8282)* — "Restarts and leader changes
  previously required expensive backward scans through the stream to find the last sourced indices.
  These are now persisted in an index for instant lookup."
- **v2.14.4** (2026-07-30): "Filestore blocks with unsynced or truncated key files are now removed and
  counted as lost data instead of failing to recover altogether (#8365)"
- **v2.14.2** and **v2.12.10** (2026-06-02): "The filestore no longer performs a block skip check on
  streams with extremely high subject counts, as it could result in runaway CPU usage (#8227)"
- **v2.14.0** (2026-04-30): "Filestore recovers from partial purge after hard kill (#7676)"
- **v2.12.5** (2026-03-09): "The filestore now always uses tombstones for recovering trailing deletes
  (#7782)"; "Fixed a race condition when rebuilding block state during recovery (#7783)"
- **v2.12.2** (2025-11-13): "Streams are now loaded in parallel when enabling JetStream, often reducing
  the time it takes to start up the server (#7482, #7526)"; "Improved the performance of enforcing
  `max_bytes` and `max_msgs` limits (#7455)"
- **v2.11.11** (2025-11-13): "Streams are now loaded in parallel when enabling JetStream, often reducing
  the time it takes to start up the server (#7482)"; "JetStream recovery parallelism now matches the
  I/O gated semaphore (#7526)"; "The filestore no longer loses the last sequence when recovering
  blocks containing only tombstones (#7384)"

No 2.10.x–2.14.x body mentions `startingSequenceForSources`, a backward scan, or `sources.db`.

### The one-billion constant, searched for and not found

`grep -nE '1_000_000_000|1000000000|1e9' server/{filestore,jetstream,stream,consumer,memstore,server,opts,const,jetstream_api,jetstream_cluster}.go`
at v2.14.6 matches nothing. Stream sequences are `uint64` throughout (`StreamState.FirstSeq` /
`LastSeq`, `mb.first.seq` / `mb.last.seq` above). `MaxMsgs` is an `int64` on `StreamConfig` (line 58);
the only validation is at 1713–1718 — a zero or a value below −1 is rewritten to −1 (unlimited; an
error only in pedantic mode) — and the only other use of the number at creation is the reservation
estimate at 1419–1421, which multiplies it by `max_msg_size` when both are set.

```go
    58		MaxMsgs      int64            `json:"max_msgs"`
```

```go
  1713		if cfg.MaxMsgs == 0 || cfg.MaxMsgs < -1 {
  1714			if pedantic && cfg.MaxMsgs < -1 {
  1715				return StreamConfig{}, NewJSPedanticError(fmt.Errorf("max_msgs must be set to -1"))
  1716			}
  1717			cfg.MaxMsgs = -1
  1718		}
```

```go
  1417		if mset.cfg.MaxBytes > 0 {
  1418			totalEstSize = uint64(mset.cfg.MaxBytes)
  1419		} else if mset.cfg.MaxMsgs > 0 {
  1420			// Determine max message size to estimate.
  1421			totalEstSize = mset.maxMsgSize() * uint64(mset.cfg.MaxMsgs)
  1422		} else if mset.cfg.MaxMsgsPer > 0 {
  1423			fsCfg.BlockSize = uint64(defaultKVBlockSize)
```
