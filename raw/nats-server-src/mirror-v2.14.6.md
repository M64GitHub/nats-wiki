<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6 (and v2.10.0, v2.12.0 for one comparison), server/stream.go and server/filestore.go fetched from raw.githubusercontent.com · fetched 2026-09-02 -->
# nats-server v2.14.6 — how a mirror catches up, and what a filtered read costs on a sparse stream

Extracted line ranges, verbatim, with their real line numbers at the tag, so every claim on
`wiki/concepts/mirrors-and-sources.md`, `wiki/internals/filestore-layout.md` and the gotcha page
can be checked against `https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`.
Read for step 2 of `inbox/plan-the-runnable-scouts-2026-09-02.md` (question-bank rows 76, 91, 105);
the runs that go with it are in `mirrors-observed-v2.14.6.md`.

## server/stream.go

### The stream's inbound queue limits — why an un-acked flood is dropped

The run's first fill hit these (`Dropping messages due to excessive stream ingest rate … IPQ len
limit reached`).


```go
   439	// For managing stream ingest.
   440	const (
   441		streamDefaultMaxQueueMsgs  = 100_000
   442		streamDefaultMaxQueueBytes = 128 * 1024 * 1024
   443	)
```

```go
   920			consumers: make(map[string]*consumer),
   921			msgs: newIPQueue[*inMsg](s, qpfx+"messages",
   922				ipqSizeCalculation(func(msg *inMsg) uint64 {
   923					return uint64(len(msg.hdr) + len(msg.msg) + len(msg.rply) + len(msg.subj))
   924				}),
   925				ipqLimitByLen[*inMsg](mlen),
   926				ipqLimitBySize[*inMsg](msz),
   927			),
```

### The names of the internal consumers, and their best-effort deletion


```go
  2793	// tryDeleteMirrorConsumer is a best-effort single try to delete a consumer used for stream mirroring.
  2794	// Lock should be held.
  2795	func (mset *stream) tryDeleteMirrorConsumer(mirror *StreamSource) {
  2796		id := mset.createStableConsumerHash()
  2797		consumerName := fmt.Sprintf("JS_MIRROR_%s", id)
  2798		log := mset.mirror != nil && mset.mirror.cname == consumerName
  2799		mset.tryDeleteSourcingConsumer("mirror", mirror, consumerName, log)
  2800	}
  2801	
  2802	// tryDeleteSourceConsumer is a best-effort single try to delete a consumer used for stream sourcing.
  2803	// Lock should be held.
  2804	func (mset *stream) tryDeleteSourceConsumer(id string, source *StreamSource) {
  2805		consumerName := fmt.Sprintf("JS_SRC_%s", id)
  2806		si := mset.sources[source.iname]
  2807		log := si != nil && si.cname == consumerName
  2808		mset.tryDeleteSourcingConsumer("source", source, consumerName, log)
```

### The two intervals the mirror runs on


```go
  3117	const (
  3118		// Our consumer HB interval.
  3119		sourceHealthHB = 1 * time.Second
  3120		// How often we check and our stalled interval.
  3121		sourceHealthCheckInterval = 10 * time.Second
  3122	)
```

### `processMirrorMsgs` — the goroutine that drains the mirror consumer's deliveries

Every 10 s (`sourceHealthCheckInterval`) it checks whether anything has arrived since the last
check; if not, it is *stalled* and re-creates the consumer.


```go
  3125	func (mset *stream) processMirrorMsgs(mirror *sourceInfo, ready *sync.WaitGroup) {
  3126		s := mset.srv
  3127		defer func() {
  3128			mirror.wg.Done()
  3129			s.grWG.Done()
  3130		}()
  3131	
  3132		// Grab stream quit channel.
  3133		mset.mu.Lock()
  3134		msgs, qch, siqch := mirror.msgs, mset.qch, mirror.qch
  3135		// If the mirror was already canceled before we got here, exit early.
  3136		if siqch == nil {
  3137			mset.mu.Unlock()
  3138			ready.Done()
  3139			return
  3140		}
  3141		// Set the last seen as now so that we don't fail at the first check.
  3142		mirror.last.Store(time.Now().UnixNano())
  3143		mset.mu.Unlock()
  3144	
  3145		// Signal the caller that we have captured the above fields.
  3146		ready.Done()
  3147	
  3148		// Make sure we have valid ipq for msgs.
  3149		if msgs == nil {
  3150			mset.mu.Lock()
  3151			mset.cancelMirrorConsumer()
  3152			mset.mu.Unlock()
  3153			return
  3154		}
  3155	
  3156		t := time.NewTicker(sourceHealthCheckInterval)
  3157		defer t.Stop()
  3158	
  3159		for {
  3160			select {
  3161			case <-s.quitCh:
  3162				return
  3163			case <-qch:
  3164				return
  3165			case <-siqch:
  3166				return
  3167			case <-msgs.ch:
  3168				ims := msgs.pop()
  3169				for _, im := range ims {
  3170					if !mset.processInboundMirrorMsg(im) {
  3171						break
  3172					}
  3173					im.returnToPool()
  3174				}
  3175				msgs.recycle(&ims)
  3176			case <-t.C:
  3177				mset.mu.RLock()
  3178				var stalled bool
  3179				if mset.mirror != nil {
  3180					stalled = time.Since(time.Unix(0, mset.mirror.last.Load())) > sourceHealthCheckInterval
  3181				}
  3182				isLeader := mset.isLeader()
  3183				mset.mu.RUnlock()
  3184				// No longer leader.
  3185				if !isLeader {
  3186					mset.mu.Lock()
  3187					mset.cancelMirrorConsumer()
  3188					mset.mu.Unlock()
  3189					return
  3190				}
  3191				// We are stalled.
  3192				if stalled {
  3193					mset.retryMirrorConsumer()
  3194				}
  3195			}
  3196		}
  3197	}
  3198	
  3199	// Checks that the message is from our current direct consumer. We can not depend on sub comparison
  3200	// since cross account imports break.
  3201	func (si *sourceInfo) isCurrentSub(cname string) bool {
  3202		return si.cname != _EMPTY_ && si.cname == cname
  3203	}
  3204	
  3205	// processInboundMirrorMsg handles processing messages bound for a stream.
```

### `processInboundMirrorMsg` — heartbeats, flow control, and the sequence gap

A heartbeat carries `Nats-Last-Consumer`; a mismatch with the mirror's own delivered count means a
retry. The *else* branch at the end is the sparse-stream case: the consumer's delivery sequence is
contiguous but the stream sequence jumped, so "the upstream stream has expired or deleted messages"
and the mirror fills the hole with `skipMsgs`.


```go
  3206	func (mset *stream) processInboundMirrorMsg(m *inMsg) bool {
  3207		mset.mu.Lock()
  3208		if mset.mirror == nil {
  3209			mset.mu.Unlock()
  3210			return false
  3211		}
  3212		if !mset.isLeader() {
  3213			mset.cancelMirrorConsumer()
  3214			mset.mu.Unlock()
  3215			return false
  3216		}
  3217	
  3218		isControl := m.isControlMsg()
  3219		cname := consumerFromAckReply(m.rply)
  3220	
  3221		// Ignore from old subscriptions.
  3222		// The reason we can not just compare subs is that on cross account imports they will not match.
  3223		if !mset.mirror.isCurrentSub(cname) && !isControl {
  3224			mset.mu.Unlock()
  3225			return false
  3226		}
  3227	
  3228		// Check for heartbeats and flow control messages.
  3229		if isControl {
  3230			var needsRetry bool
  3231			// Flow controls have reply subjects.
  3232			if m.rply != _EMPTY_ {
  3233				mset.handleFlowControl(m, mset.mirror.dseq, mset.mirror.sseq)
  3234			} else {
  3235				// For idle heartbeats make sure we did not miss anything and check if we are considered stalled.
  3236				if ldseq := parseInt64(sliceHeader(JSLastConsumerSeq, m.hdr)); ldseq > 0 && uint64(ldseq) != mset.mirror.dseq {
  3237					needsRetry = true
  3238				} else if fcReply := sliceHeader(JSConsumerStalled, m.hdr); len(fcReply) > 0 {
  3239					// Other side thinks we are stalled, so send flow control reply.
  3240					mset.outq.sendMsg(string(fcReply), nil)
  3241				}
  3242			}
  3243			mset.mu.Unlock()
  3244			if needsRetry {
  3245				mset.retryMirrorConsumer()
  3246			}
  3247			return !needsRetry
  3248		}
  3249	
  3250		sseq, dseq, dc, ts, pending := ackReplyInfo(m.rply)
  3251	
  3252		if dc > 1 {
  3253			mset.mu.Unlock()
  3254			return false
  3255		}
  3256	
  3257		// Mirror info tracking.
  3258		olag, osseq, odseq := mset.mirror.lag, mset.mirror.sseq, mset.mirror.dseq
  3259		if sseq <= mset.mirror.sseq {
  3260			// Ignore older messages.
  3261			// If the deliver sequence matches, we only update delivered accounting.
  3262			if dseq == mset.mirror.dseq+1 {
  3263				mset.mirror.dseq++
  3264			}
  3265			mset.mu.Unlock()
  3266			return true
  3267		} else if sseq == mset.mirror.sseq+1 {
  3268			mset.mirror.dseq = dseq
  3269			mset.mirror.sseq++
  3270		} else if mset.mirror.cname == _EMPTY_ {
  3271			mset.mirror.cname = cname
  3272			mset.mirror.dseq, mset.mirror.sseq = dseq, sseq
  3273		} else {
  3274			// If the deliver sequence matches then the upstream stream has expired or deleted messages.
  3275			if dseq == mset.mirror.dseq+1 {
  3276				if err := mset.skipMsgs(mset.mirror.sseq+1, sseq-1); err != nil {
  3277					mset.mirror.sseq = osseq
  3278					mset.mirror.dseq = odseq
  3279					mset.mu.Unlock()
  3280					mset.retryMirrorConsumer()
  3281					return false
  3282				}
  3283				mset.mirror.dseq++
  3284				mset.mirror.sseq = sseq
  3285			} else {
  3286				mset.mu.Unlock()
  3287				mset.retryMirrorConsumer()
  3288				return false
  3289			}
  3290		}
  3291	
  3292		if pending == 0 {
  3293			mset.mirror.lag = 0
  3294		} else {
  3295			mset.mirror.lag = pending - 1
  3296		}
  3297	
  3298		// Check if we allow mirror direct here. If so check they we have mostly caught up.
  3299		// The reason we do not require 0 is if the source is active we may always be slightly behind.
  3300		if mset.cfg.MirrorDirect && mset.mirrorDirectSub == nil && pending < dgetCaughtUpThresh {
```

### `retryMirrorConsumer`, `skipMsgs`, and the retry backoff

`skipMsgs` is one store call when the mirror is R1, and one Raft entry per skipped sequence (in
batches of 10,000) when it is replicated — unless `FeatureFlagJsRaftDeleteRange` is on, in which
case a single `DeleteRange` op.


```go
  3394	func (mset *stream) retryMirrorConsumer() error {
  3395		mset.mu.Lock()
  3396		defer mset.mu.Unlock()
  3397		mset.srv.Debugf("Retrying mirror consumer for '%s > %s'", mset.acc.Name, mset.cfg.Name)
  3398		mset.cancelMirrorConsumer()
  3399		return mset.setupMirrorConsumer()
  3400	}
  3401	
  3402	// Lock should be held.
  3403	func (mset *stream) skipMsgs(start, end uint64) error {
  3404		node, store := mset.node, mset.store
  3405		// If we are not clustered we can short circuit now with store.SkipMsgs
  3406		if node == nil {
  3407			if err := store.SkipMsgs(start, end-start+1); err != nil {
  3408				return err
  3409			}
  3410			mset.lseq = end
  3411			return nil
  3412		}
  3413	
  3414		// Must only be enabled once every peer in the cluster supports receiving
  3415		// deleteRangeOp in the normal apply path; older peers panic on unknown ops.
  3416		if mset.srv.getOpts().getFeatureFlag(FeatureFlagJsRaftDeleteRange) {
  3417			return node.Propose(mset.term, encodeDeleteRange(&DeleteRange{First: start, Num: end - start + 1}))
  3418		}
  3419	
  3420		var entries []*Entry
  3421		for seq := start; seq <= end; seq++ {
  3422			entries = append(entries, newEntry(EntryNormal, encodeStreamMsg(_EMPTY_, _EMPTY_, nil, nil, seq-1, 0, false)))
  3423			// So a single message does not get too big.
  3424			if len(entries) > 10_000 {
  3425				if err := node.ProposeMulti(mset.term, entries); err != nil {
  3426					return err
  3427				}
  3428				// We need to re-create `entries` because there is a reference
  3429				// to it in the node's pae map.
  3430				entries = entries[:0]
  3431			}
  3432		}
  3433		// Send all at once.
  3434		if len(entries) > 0 {
  3435			return node.ProposeMulti(mset.term, entries)
  3436		}
  3437		return nil
  3438	}
  3439	
  3440	const (
  3441		// Base retry backoff duration.
  3442		retryBackOff = 5 * time.Second
  3443		// Maximum amount we will wait.
  3444		retryMaximum = 2 * time.Minute
  3445	)
  3446	
  3447	// Calculate our backoff based on number of failures.
  3448	func calculateRetryBackoff(fails int) time.Duration {
  3449		backoff := time.Duration(retryBackOff) * time.Duration(fails*2)
  3450		if backoff > retryMaximum {
  3451			backoff = retryMaximum
  3452		}
  3453		return backoff
  3454	}
  3455	
  3456	// This will schedule a call to setupMirrorConsumer, taking into account the last
  3457	// time it was retried and determine the soonest setupMirrorConsumer can be called
  3458	// without tripping the sourceConsumerRetryThreshold. We will also take into account
  3459	// number of failures and will back off our retries.
  3460	// The mset.mirror pointer has been verified to be not nil by the caller.
  3461	//
  3462	// Lock held on entry
  3463	func (mset *stream) scheduleSetupMirrorConsumerRetry() {
  3464		// We are trying to figure out how soon we can retry. setupMirrorConsumer will reject
  3465		// a retry if last was done less than "sourceConsumerRetryThreshold" ago.
  3466		next := sourceConsumerRetryThreshold - time.Since(mset.mirror.lreq)
  3467		if next < 0 {
  3468			// It means that we have passed the threshold and so we are ready to go.
  3469			next = 0
  3470		}
```

### The consumer the server asks the upstream for

Always named `JS_MIRROR_<id>` at this tag, `Direct` and `Sourcing`, `AckNone`, `AckWait` 22 h,
`MaxDeliver` 1, a 1 s heartbeat, flow control, `InactiveThreshold` 10 s, no filter unless the
mirror config has one.


```go
  3550		id := mset.createStableConsumerHash()
  3551		metadata := map[string]string{}
  3552		metadata["_nats.mirror.stream"] = mset.cfg.Name
  3553		metadata["_nats.mirror.acc"] = mset.acc.Name
  3554		if domain := mset.srv.getOpts().JetStreamDomain; domain != _EMPTY_ {
  3555			metadata["_nats.mirror.domain"] = domain
  3556		}
  3557	
  3558		req := &CreateConsumerRequest{
  3559			Stream: mset.cfg.Mirror.Name,
  3560			Config: ConsumerConfig{
  3561				Name:              fmt.Sprintf("JS_MIRROR_%s", id),
  3562				DeliverSubject:    deliverSubject,
  3563				DeliverPolicy:     DeliverByStartSequence,
  3564				OptStartSeq:       state.LastSeq + 1,
  3565				AckPolicy:         AckNone,
  3566				AckWait:           22 * time.Hour,
  3567				MaxDeliver:        1,
  3568				Heartbeat:         sourceHealthHB,
  3569				FlowControl:       true,
  3570				Direct:            true,
  3571				Sourcing:          true,
  3572				InactiveThreshold: sourceHealthCheckInterval,
  3573				Metadata:          metadata,
  3574			},
  3575		}
```

```go
  3586		}
  3587		if req.Config.OptStartSeq == 0 && req.Config.OptStartTime == nil {
  3588			// If starting out and lastSeq is 0.
  3589			req.Config.DeliverPolicy = DeliverAll
  3590		}
  3591	
  3592		// Filters
  3593		if mset.cfg.Mirror.FilterSubject != _EMPTY_ {
  3594			req.Config.FilterSubject = mset.cfg.Mirror.FilterSubject
  3595			mirror.sf = mset.cfg.Mirror.FilterSubject
  3596		}
  3597	
  3598		if lst := len(mset.cfg.Mirror.SubjectTransforms); lst > 0 {
```

### The fallback name when the upstream does not know `sourcing`


```go
  3733	
  3734				if ccr.Error != nil || ccr.ConsumerInfo == nil || ccr.ConsumerInfo.Config == nil {
  3735					// If the responding server doesn't support sourcing consumers, retry without it.
  3736					if req.Config.Sourcing && ccr.Error != nil &&
  3737						(ccr.Error.ErrCode == uint16(JSRequiredApiLevelErr) || ccr.Error.ErrCode == uint16(JSInvalidJSONErr)) {
  3738						// Unset for retry.
  3739						req.Config.Sourcing = false
  3740						// Specify a unique consumer name, as the other end will not know to do this.
  3741						req.Config.Name = fmt.Sprintf("JS_MIRROR_%s_%s", id, createConsumerName())
  3742						b, _ := json.Marshal(req)
  3743						// Regenerate subject since the previous name could've been included in it.
  3744						subject = generateSubject()
  3745						// Recreate the reply subscription so we don't get stale responses from other servers.
```

### The retry threshold


```go
  3924	const sourceConsumerRetryThreshold = 2 * time.Second
```

### For comparison — the names at v2.10.0 and v2.12.0

ADR-59 (revision 2, 2026-04-29) says the internal consumer "is created with an explicit name
following the pattern `mirror-<id>` or `src-<id>`". That was the code through 2.12; 2.14 (ADR-60)
renamed it.

`server/stream.go` at **v2.10.0**:


```go
  2554		b, _ := json.Marshal(req)
  2555	
  2556		var subject string
  2557		if req.Config.FilterSubject != _EMPTY_ {
  2558			req.Config.Name = fmt.Sprintf("mirror-%s", createConsumerName())
  2559			subject = fmt.Sprintf(JSApiConsumerCreateExT, mset.cfg.Mirror.Name, req.Config.Name, req.Config.FilterSubject)
  2560		} else {
```

`server/stream.go` at **v2.12.0**:


```go
  3254		}
  3255	
  3256		var subject string
  3257		if req.Config.FilterSubject != _EMPTY_ {
  3258			req.Config.Name = fmt.Sprintf("mirror-%s", createConsumerName())
  3259			subject = fmt.Sprintf(JSApiConsumerCreateExT, mset.cfg.Mirror.Name, req.Config.Name, req.Config.FilterSubject)
  3260		} else {
```

## server/filestore.go

### The high-cardinality threshold


```go
   388		// Above this number of subjects, index.db may not be written regularly anymore, and
   389		// certain psim optimisations may not be used.
   390		highCardinalityThreshold = 1_000_000
```

### `firstMatching` — the linear-scan heuristic gh#8417's answer names

`doLinearScan` is true when the filter matches everything (`isAll`) **or** when the stream has
exactly one subject and the filter *is* that subject — true on a KV bucket's own stream, false on
a mirror, which has no subjects. Otherwise the block is scanned linearly only if it holds fewer than
four sequences per tracked subject, measured on `lseq - fseq` — the sequence range, holes included.


```go
  3031	// Find the first matching message.
  3032	// fs lock should be held.
  3033	func (mb *msgBlock) firstMatching(filter string, wc bool, start uint64, sm *StoreMsg) (*StoreMsg, bool, error) {
  3034		mb.mu.Lock()
  3035		var updateLLTS bool
  3036		defer func() {
  3037			if updateLLTS {
  3038				mb.llts = ats.AccessTime()
  3039			}
  3040			mb.finishedWithCache()
  3041			mb.mu.Unlock()
  3042		}()
  3043	
  3044		fseq, isAll := start, filter == _EMPTY_ || filter == fwcs
  3045	
  3046		var didLoad bool
  3047		if mb.fssNotLoaded() {
  3048			// Make sure we have fss loaded.
  3049			if err := mb.loadMsgsWithLock(); err != nil {
```

```go
  3080	
  3081		// Optionally build the isMatch for wildcard filters.
  3082		var isMatch func(subj string) bool
  3083		// Decide to build.
  3084		if wc {
  3085			_tsa, _fsa := [32]string{}, [32]string{}
  3086			tsa, fsa := _tsa[:0], tokenizeSubjectIntoSlice(_fsa[:0], filter)
  3087			isMatch = func(subj string) bool {
  3088				tsa = tokenizeSubjectIntoSlice(tsa[:0], subj)
  3089				return isSubsetMatchTokenized(tsa, fsa)
  3090			}
  3091		}
  3092	
  3093		subjs := mb.fs.cfg.Subjects
  3094		// If isAll or our single filter matches the filter arg do linear scan.
  3095		doLinearScan := isAll || (wc && len(subjs) == 1 && subjs[0] == filter)
  3096		// If we do not think we should do a linear scan check how many fss we
  3097		// would need to scan vs the full range of the linear walk. Optimize for
  3098		// 25th quantile of a match in a linear walk. Filter should be a wildcard.
  3099		// We should consult fss if our cache is not loaded and we only have fss loaded.
  3100		if !doLinearScan && wc && mb.cacheAlreadyLoaded() {
  3101			doLinearScan = mb.fss.Size()*4 > int(lseq-fseq)
  3102		}
  3103	
```

```go
  3139		}
  3140	
  3141		// Need messages loaded from here on out.
  3142		if mb.cacheNotLoaded() {
  3143			if err := mb.loadMsgsWithLock(); err != nil {
  3144				return nil, false, err
  3145			}
  3146			didLoad = true
  3147		}
  3148	
  3149		if sm == nil {
  3150			sm = new(StoreMsg)
```

### `LoadNextMsg` — one read lock for the whole walk


```go
  9427	func (fs *fileStore) LoadNextMsg(filter string, wc bool, start uint64, sm *StoreMsg) (*StoreMsg, uint64, error) {
  9428		if fs.isClosed() {
  9429			return nil, 0, ErrStoreClosed
  9430		}
  9431	
  9432		fs.mu.RLock()
  9433		defer fs.mu.RUnlock()
  9434	
  9435		if fs.state.Msgs == 0 || start > fs.state.LastSeq {
  9436			return nil, fs.state.LastSeq, ErrStoreEOF
  9437		}
  9438		if start < fs.state.FirstSeq {
  9439			start = fs.state.FirstSeq
  9440		}
  9441	
  9442		// If start is less than or equal to beginning of our stream, meaning our first call,
  9443		// let's check the psim to see if we can skip ahead.
  9444		if start <= fs.state.FirstSeq {
  9445			var ss SimpleState
```

### `StoreRawMsg`, `StoreMsg` — the write lock


```go
  5311	func (fs *fileStore) StoreRawMsg(subj string, hdr, msg []byte, seq uint64, ts, ttl int64, discardNewCheck bool) error {
```

```go
  5336	func (fs *fileStore) StoreMsg(subj string, hdr, msg []byte, ttl int64) (uint64, int64, error) {
  5337		fs.mu.Lock()
  5338		// Always return previous write errors.
```

### `SkipMsgs` — how a mirror records the upstream's holes

Under the store's exclusive lock: inserts every skipped sequence into the last block's delete map
(or, if the block is empty, just moves its first/last), starts a new block when the map would exceed
64 K entries, and writes one 30-byte placeholder record.


```go
  5464	// SkipMsgs skips multiple msgs. We will determine if we can fit into current lmb or we need to create a new block.
  5465	func (fs *fileStore) SkipMsgs(seq uint64, num uint64) error {
  5466		fs.mu.Lock()
  5467		defer fs.mu.Unlock()
  5468	
  5469		// Always return previous write errors.
  5470		if err := fs.werr; err != nil {
  5471			return err
  5472		}
  5473	
  5474		// Check sequence matches our last sequence.
  5475		if seq != fs.state.LastSeq+1 {
  5476			if seq > 0 {
  5477				return ErrSequenceMismatch
  5478			}
  5479			seq = fs.state.LastSeq + 1
  5480		}
  5481	
  5482		// Limit number of dmap entries
  5483		const maxDeletes = 64 * 1024
  5484		mb := fs.lmb
  5485	
  5486		var msgs uint64
  5487		numDeletes := int(num)
  5488		if mb != nil {
  5489			mb.mu.RLock()
  5490			numDeletes += mb.dmap.Size()
  5491			msgs = mb.msgs
  5492			mb.mu.RUnlock()
  5493		}
  5494		if mb == nil || numDeletes > maxDeletes && msgs > 0 || msgs > 0 && mb.blkSize()+emptyRecordLen > fs.fcfg.BlockSize {
  5495			var err error
  5496			if mb, err = fs.newMsgBlockForWrite(); err != nil {
  5497				return err
  5498			}
  5499		}
  5500	
  5501		// Insert into dmap all entries and place last as marker.
  5502		var ts int64
  5503		if !fs.state.LastTime.IsZero() {
  5504			ts = fs.state.LastTime.UnixNano()
  5505		} else {
  5506			ts = ats.AccessTime()
  5507		}
  5508		lseq := seq + num - 1
  5509	
  5510		mb.mu.Lock()
  5511		if err := mb.werr; err != nil {
  5512			mb.mu.Unlock()
  5513			return err
  5514		}
  5515		// If we are empty update meta directly.
  5516		if mb.msgs == 0 {
  5517			atomic.StoreUint64(&mb.last.seq, lseq)
  5518			mb.last.ts = ts
  5519			atomic.StoreUint64(&mb.first.seq, lseq+1)
  5520			mb.first.ts = 0
  5521		} else {
  5522			for ; seq <= lseq; seq++ {
  5523				mb.dmap.Insert(seq)
  5524			}
  5525		}
  5526		// Write out our placeholder.
  5527		err := mb.writeMsgRecordLocked(emptyRecordLen, lseq|ebit, _EMPTY_, nil, nil, ts, true, true)
  5528		mb.mu.Unlock()
  5529		if err != nil {
  5530			fs.setWriteErr(err)
```
