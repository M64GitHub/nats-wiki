<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6 · files server/jetstream.go, server/disk_avail.go, server/jetstream_api.go, server/jetstream_cluster.go, server/stream.go, server/filestore.go, server/opts.go · fetched 2026-08-31 -->
# nats-server v2.14.6 — JetStream storage limits, reservations and out-of-space

Only the ranges this wiki quotes are stored, with their real line numbers, so each value links to
`https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`. Apache-2.0.

Read for question-bank Q26 (*what happens when JetStream runs out of disk*) and for the docs-issue
sweep of the generated `reference/config/jetstream` block.

### `server/jetstream.go` lines 2729–2784

```go
  2729	const (
  2730		// JetStreamStoreDir is the prefix we use.
  2731		JetStreamStoreDir = "jetstream"
  2732		// JetStreamMaxStoreDefault is the default disk storage limit. 1TB
  2733		JetStreamMaxStoreDefault = 1024 * 1024 * 1024 * 1024
  2734		// JetStreamMaxMemDefault is only used when we can't determine system memory. 256MB
  2735		JetStreamMaxMemDefault = 1024 * 1024 * 256
  2736		// snapshot staging for restores.
  2737		snapStagingDir = ".snap-staging"
  2738	)
  2739	
  2740	// Dynamically create a config with a tmp based directory (repeatable) and 75% of system memory.
  2741	func (s *Server) dynJetStreamConfig(storeDir string, maxStore, maxMem int64) *JetStreamConfig {
  2742		jsc := &JetStreamConfig{}
  2743		if storeDir != _EMPTY_ {
  2744			jsc.StoreDir = filepath.Join(storeDir, JetStreamStoreDir)
  2745		} else {
  2746			// Create one in tmp directory, but make it consistent for restarts.
  2747			jsc.StoreDir = filepath.Join(os.TempDir(), "nats", JetStreamStoreDir)
  2748			s.Warnf("Temporary storage directory used, data could be lost on system reboot")
  2749		}
  2750	
  2751		opts := s.getOpts()
  2752	
  2753		// Strict mode.
  2754		jsc.Strict = !opts.NoJetStreamStrict
  2755	
  2756		// Sync options.
  2757		jsc.SyncInterval = opts.SyncInterval
  2758		jsc.SyncAlways = opts.SyncAlways
  2759	
  2760		if maxStore > 0 || (opts.maxStoreSet && maxStore == 0) {
  2761			jsc.MaxStore = maxStore
  2762		} else {
  2763			jsc.MaxStore = diskAvailable(jsc.StoreDir)
  2764			jsc.maxStorePending = true
  2765		}
  2766	
  2767		if maxMem > 0 || (opts.maxMemSet && maxMem == 0) {
  2768			jsc.MaxMemory = maxMem
  2769		} else {
  2770			// Estimate to 75% of total memory if we can determine system memory.
  2771			if sysMem := sysmem.Memory(); sysMem > 0 {
  2772				// Check if we have been limited with GOMEMLIMIT and if lower use that value.
  2773				if gml := debug.SetMemoryLimit(-1); gml != math.MaxInt64 && gml < sysMem {
  2774					s.Debugf("JetStream detected GOMEMLIMIT of %v", friendlyBytes(gml))
  2775					sysMem = gml
  2776				}
  2777				jsc.MaxMemory = sysMem / 4 * 3
  2778			} else {
  2779				jsc.MaxMemory = JetStreamMaxMemDefault
  2780			}
  2781		}
  2782	
  2783		return jsc
  2784	}
```

### `server/disk_avail.go` lines 14–37

```go
    14	//go:build !windows && !openbsd && !netbsd && !wasm && !illumos && !solaris
    15	
    16	package server
    17	
    18	import (
    19		"os"
    20		"syscall"
    21	)
    22	
    23	func diskAvailable(storeDir string) int64 {
    24		var ba int64
    25		if _, err := os.Stat(storeDir); os.IsNotExist(err) {
    26			os.MkdirAll(storeDir, defaultDirPerms)
    27		}
    28		var fs syscall.Statfs_t
    29		if err := syscall.Statfs(storeDir, &fs); err == nil {
    30			// Estimate 75% of available storage.
    31			ba = int64(uint64(fs.Bavail) * uint64(fs.Bsize) / 4 * 3)
    32		} else {
    33			// Used 1TB default as a guess if all else fails.
    34			ba = JetStreamMaxStoreDefault
    35		}
    36		return ba
    37	}
```

### `server/jetstream.go` lines 543–566

```go
   543	// finalizeDynamicMaxStore settles a dynamic max store limit once all file based
   544	// streams have been recovered. diskAvailable only reports free space, so add back
   545	// what we occupy ourselves to keep the limit stable across restarts.
   546	func (js *jetStream) finalizeDynamicMaxStore() {
   547		js.mu.Lock()
   548		if !js.config.maxStorePending {
   549			js.mu.Unlock()
   550			return
   551		}
   552		// From here on the limit is real and can be enforced, see sufficientResources.
   553		js.config.maxStorePending = false
   554		recovered := atomic.LoadInt64(&js.storeUsed)
   555		if recovered <= 0 {
   556			js.mu.Unlock()
   557			return
   558		}
   559		// diskAvailable is already scaled down to 75% of what is free, so scale the
   560		// recovered bytes the same way before adding them back.
   561		maxStore := addSaturate(js.config.MaxStore, recovered/4*3)
   562		js.config.MaxStore = maxStore
   563		atomic.StoreInt64(&js.storeMax, maxStore)
   564		js.mu.Unlock()
   565	}
   566	
```

### `server/jetstream.go` lines 2377–2380

```go
  2377	func (js *jetStream) limitsExceeded(storeType StorageType) bool {
  2378		return js.wouldExceedLimits(storeType, 0)
  2379	}
  2380	
```

### `server/jetstream.go` lines 2508–2554

```go
  2508	// accountReservation returns how many bytes count against the account limit
  2509	// for a stream with the given replica count. Un-tiered limits are flat, so R>1
  2510	// is counted as Replicas*bytes; tiered limits already bake in replication.
  2511	func accountReservation(tier string, replicas int, bytes int64) int64 {
  2512		if bytes <= 0 {
  2513			return 0
  2514		}
  2515		if tier == _EMPTY_ && replicas > 1 {
  2516			return mulSaturate(int64(replicas), bytes)
  2517		}
  2518		return bytes
  2519	}
  2520	
  2521	// Check if additional bytes will exceed our account limits and optionally the server itself.
  2522	// Read Lock should be held.
  2523	func (js *jetStream) checkBytesLimits(selectedLimits *JetStreamAccountLimits, tier string, addBytes int64, replicas int, storage StorageType, checkServer bool, currentRes, maxBytesOffset int64) error {
  2524		if addBytes < 0 {
  2525			addBytes = 1
  2526		}
  2527		// The per-server footprint is a single replica's worth of bytes; the
  2528		// account footprint additionally accounts for replication in un-tiered setups.
  2529		serverBytes := addSaturate(addBytes, maxBytesOffset)
  2530		accountBytes := accountReservation(tier, replicas, serverBytes)
  2531	
  2532		switch storage {
  2533		case MemoryStorage:
  2534			// Account limits defined.
  2535			if selectedLimits.MaxMemory >= 0 && (currentRes > selectedLimits.MaxMemory || accountBytes > selectedLimits.MaxMemory-currentRes) {
  2536				return NewJSMemoryResourcesExceededError()
  2537			}
  2538			// Check if this server can handle request.
  2539			if checkServer && (js.memReserved > js.config.MaxMemory || serverBytes > js.config.MaxMemory-js.memReserved) {
  2540				return NewJSMemoryResourcesExceededError()
  2541			}
  2542		case FileStorage:
  2543			// Account limits defined.
  2544			if selectedLimits.MaxStore >= 0 && (currentRes > selectedLimits.MaxStore || accountBytes > selectedLimits.MaxStore-currentRes) {
  2545				return NewJSStorageResourcesExceededError()
  2546			}
  2547			// Check if this server can handle request.
  2548			if checkServer && (js.storeReserved > js.config.MaxStore || serverBytes > js.config.MaxStore-js.storeReserved) {
  2549				return NewJSStorageResourcesExceededError()
  2550			}
  2551		}
  2552	
  2553		return nil
  2554	}
```

### `server/jetstream.go` lines 2626–2682

```go
  2626	
  2627	// Check to see if we have enough system resources for this account.
  2628	// Lock should be held.
  2629	func (js *jetStream) sufficientResources(limits map[string]JetStreamAccountLimits) error {
  2630		// If we are clustered we do not really know how many resources will be ultimately available.
  2631		// This needs to be handled out of band.
  2632		// If we are a single server, we can make decisions here.
  2633		if limits == nil || !js.standAlone {
  2634			return nil
  2635		}
  2636	
  2637		totalMaxBytes := func(limits map[string]JetStreamAccountLimits) (int64, int64) {
  2638			totalMaxMemory := int64(0)
  2639			totalMaxStore := int64(0)
  2640			for _, l := range limits {
  2641				if l.MaxMemory > 0 {
  2642					totalMaxMemory += l.MaxMemory
  2643				}
  2644				if l.MaxStore > 0 {
  2645					totalMaxStore += l.MaxStore
  2646				}
  2647			}
  2648			return totalMaxMemory, totalMaxStore
  2649		}
  2650	
  2651		totalMaxMemory, totalMaxStore := totalMaxBytes(limits)
  2652	
  2653		// Reserved is now specific to the MaxBytes for streams.
  2654		if js.memReserved+totalMaxMemory > js.config.MaxMemory {
  2655			return NewJSMemoryResourcesExceededError()
  2656		}
  2657		// A dynamic limit is still provisional until recovery has run.
  2658		recovering := js.config.maxStorePending
  2659		if !recovering && js.storeReserved+totalMaxStore > js.config.MaxStore {
  2660			return NewJSStorageResourcesExceededError()
  2661		}
  2662	
  2663		// Since we know if we are here we are single server mode, check the account reservations.
  2664		var storeReserved, memReserved int64
  2665		for _, jsa := range js.accounts {
  2666			if jsa.account.IsExpired() {
  2667				continue
  2668			}
  2669			jsa.usageMu.RLock()
  2670			maxMemory, maxStore := totalMaxBytes(jsa.limits)
  2671			jsa.usageMu.RUnlock()
  2672			memReserved += maxMemory
  2673			storeReserved += maxStore
  2674		}
  2675	
  2676		if memReserved+totalMaxMemory > js.config.MaxMemory {
  2677			return NewJSMemoryResourcesExceededError()
  2678		}
  2679		if !recovering && storeReserved+totalMaxStore > js.config.MaxStore {
  2680			return NewJSStorageResourcesExceededError()
  2681		}
  2682	
```

### `server/jetstream.go` lines 2686–2700

```go
  2686	// This will reserve the stream resources requested.
  2687	// This will spin off off of MaxBytes.
  2688	func (js *jetStream) reserveStreamResources(cfg *StreamConfig) {
  2689		if cfg == nil || cfg.MaxBytes <= 0 {
  2690			return
  2691		}
  2692	
  2693		js.mu.Lock()
  2694		switch cfg.Storage {
  2695		case MemoryStorage:
  2696			js.memReserved += cfg.MaxBytes
  2697		case FileStorage:
  2698			js.storeReserved += cfg.MaxBytes
  2699		}
  2700		s, clustered := js.srv, !js.standAlone
```

### `server/jetstream.go` lines 636–696

```go
   636	func (s *Server) jetStreamOOSPending() (wasPending bool) {
   637		if js := s.getJetStream(); js != nil {
   638			js.mu.Lock()
   639			wasPending = js.oos
   640			js.oos = true
   641			js.mu.Unlock()
   642		}
   643		return wasPending
   644	}
   645	
   646	func (s *Server) setJetStreamDisabled() {
   647		if js := s.getJetStream(); js != nil {
   648			js.disabled.Store(true)
   649		}
   650	}
   651	
   652	func (s *Server) handleOutOfSpace(mset *stream) {
   653		if s.JetStreamEnabled() && !s.jetStreamOOSPending() {
   654			var stream string
   655			if mset != nil {
   656				stream = mset.name()
   657				s.Errorf("JetStream out of %s resources, will be DISABLED", mset.Store().Type())
   658			} else {
   659				s.Errorf("JetStream out of resources, will be DISABLED")
   660			}
   661	
   662			go s.ShutdownJetStream()
   663	
   664			adv := &JSServerOutOfSpaceAdvisory{
   665				TypedEvent: TypedEvent{
   666					Type: JSServerOutOfStorageAdvisoryType,
   667					ID:   nuid.Next(),
   668					Time: time.Now().UTC(),
   669				},
   670				Server:   s.Name(),
   671				ServerID: s.ID(),
   672				Stream:   stream,
   673				Cluster:  s.cachedClusterName(),
   674				Domain:   s.getOpts().JetStreamDomain,
   675			}
   676			s.publishAdvisory(nil, JSAdvisoryServerOutOfStorage, adv)
   677		}
   678	}
   679	
   680	// DisableJetStream will turn off JetStream and signals in clustered mode
   681	// to have the metacontroller remove us from the peer list. Persistent
   682	// meta-raft state on disk is removed. For transient runtime errors where
   683	// the server should rejoin its existing meta group on restart, use
   684	// ShutdownJetStream instead.
   685	func (s *Server) DisableJetStream() error {
   686		return s.disableJetStream(true)
   687	}
   688	
   689	// ShutdownJetStream is like DisableJetStream but preserves persistent
   690	// meta-raft state on disk so the server can rejoin the existing meta
   691	// group on restart. Use for transient runtime errors that the operator
   692	// is expected to fix before restarting.
   693	func (s *Server) ShutdownJetStream() error {
   694		return s.disableJetStream(false)
   695	}
   696	
```

### `server/raft.go` lines 752–759

```go
   752	// outOfResources checks to see if we are out of resources.
   753	func (n *raft) outOfResources() bool {
   754		js := n.js
   755		if !n.track || js == nil {
   756			return false
   757		}
   758		return js.limitsExceeded(n.wtype)
   759	}
```

### `server/raft.go` lines 5155–5188

```go
  5155		if err == ErrStoreClosed ||
  5156			err == ErrStoreEOF ||
  5157			err == ErrStoreMsgNotFound ||
  5158			err == errNoPending ||
  5159			err == errPartialCache {
  5160			return
  5161		}
  5162		// If this is a not found report but do not disable.
  5163		if os.IsNotExist(err) {
  5164			n.warn("Resource not found: %v", err)
  5165			return
  5166		}
  5167		n.error("Critical write error: %v", err)
  5168		n.werr = err
  5169		// Abort any inflight async snapshot checkpoint.
  5170		n.snapshotting = false
  5171		n.shutdown()
  5172		assert.Unreachable("Raft encountered write error", map[string]any{
  5173			"n.accName": n.accName,
  5174			"n.group":   n.group,
  5175			"n.id":      n.id,
  5176			"err":       err,
  5177		})
  5178	
  5179		if isPermissionError(err) {
  5180			go n.s.handleWritePermissionError()
  5181		}
  5182	
  5183		if isOutOfSpaceErr(err) {
  5184			// For now since this can be happening all under the covers, we will call up and disable JetStream.
  5185			go n.s.handleOutOfSpace(nil)
  5186		}
  5187	}
  5188	
```

---

## The generated config reference's defaults, verified

The values behind the `reference/config/jetstream` table, each at its definition site.

### `server/stream.go` lines 439–443

```go
   439	// For managing stream ingest.
   440	const (
   441		streamDefaultMaxQueueMsgs  = 100_000
   442		streamDefaultMaxQueueBytes = 128 * 1024 * 1024
   443	)
```

### `server/stream.go` lines 899–907

```go
   899		// Work out the stream ingest limits.
   900		mlen := s.opts.StreamMaxBufferedMsgs
   901		msz := uint64(s.opts.StreamMaxBufferedSize)
   902		if mlen == 0 {
   903			mlen = streamDefaultMaxQueueMsgs
   904		}
   905		if msz == 0 {
   906			msz = streamDefaultMaxQueueBytes
   907		}
```

### `server/jetstream_cluster.go` lines 11155–11159

```go
 11155	// 64MB for now, for the total server. This is max we will blast out if asked to
 11156	// do so to another server for purposes of catchups.
 11157	// This number should be ok on 1Gbit interface.
 11158	const defaultMaxTotalCatchupOutBytes = int64(64 * 1024 * 1024)
 11159	
```

### `server/jetstream.go` lines 421–435

```go
   421	func (s *Server) enableJetStream(cfg JetStreamConfig) error {
   422		js := &jetStream{srv: s, config: cfg, accounts: make(map[string]*jsAccount), apiSubs: NewSublistNoCache(), infoSubs: gsl.NewSimpleSublist()}
   423		s.gcbMu.Lock()
   424		if s.gcbOutMax = s.getOpts().JetStreamMaxCatchup; s.gcbOutMax == 0 {
   425			s.gcbOutMax = defaultMaxTotalCatchupOutBytes
   426		}
   427		s.gcbMu.Unlock()
   428	
   429		atomic.StoreInt64(&js.memMax, cfg.MaxMemory)
   430		atomic.StoreInt64(&js.storeMax, cfg.MaxStore)
   431	
   432		// TODO: Not currently reloadable.
   433		atomic.StoreInt64(&js.queueLimit, s.getOpts().JetStreamRequestQueueLimit)
   434		atomic.StoreInt64(&js.infoQueueLimit, s.getOpts().JetStreamInfoQueueLimit)
   435	
```

### `server/opts.go` lines 6177–6188

```go
  6177		if opts.SyncInterval == 0 && !opts.syncSet {
  6178			opts.SyncInterval = defaultSyncInterval
  6179		}
  6180		if opts.JetStreamRequestQueueLimit <= 0 {
  6181			opts.JetStreamRequestQueueLimit = JSDefaultRequestQueueLimit
  6182		}
  6183		if opts.JetStreamInfoQueueLimit <= 0 {
  6184			opts.JetStreamInfoQueueLimit = opts.JetStreamRequestQueueLimit
  6185		}
  6186		if opts.JetStreamConcurrentIOs <= 0 {
  6187			opts.JetStreamConcurrentIOs = defaultConcurrentIOs
  6188		}
```

### `server/jetstream_api.go` lines 364–368

```go
   364	
   365	// JSDefaultRequestQueueLimit is the default number of entries that we will
   366	// put on the global request queue before we react.
   367	const JSDefaultRequestQueueLimit = 10_000
   368	
```

### `server/filestore.go` lines 331–335

```go
   331		defaultCacheBufferExpiration = 10 * time.Second
   332		// default sync interval
   333		defaultSyncInterval = 2 * time.Minute
   334		// default idle timeout to close FDs.
   335		closeFDsIdle = 30 * time.Second
```
