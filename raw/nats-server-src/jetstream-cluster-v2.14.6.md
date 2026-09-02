<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6 · files server/jetstream_cluster.go, server/raft.go, server/jetstream_api.go, server/monitor.go, server/jetstream.go, server/server.go, server/opts.go, server/errors.json · fetched 2026-09-01 -->
# nats-server v2.14.6 — the JetStream meta layer

Only the ranges this wiki quotes are stored, verbatim, with their real line numbers, so each value
links to `https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`. Apache-2.0.
`server/jetstream_cluster.go` is 11,584 lines and `server/raft.go` 5,574 at this tag; they were read
for the five questions in `inbox/plan-the-meta-layer-2026-09-01.md` step 1, not summarised.

Read for `wiki/internals/meta-layer.md` and the `## To verify` items on `wiki/internals/raft-in-nats.md`
and `wiki/concepts/replicas.md`. The behavioural half — a three-node cluster run on the v2.14.6
binary — is `jetstream-cluster-observed-v2.14.6.md` in this directory.

## server/errors.json — the cluster error codes

| `error_code` | constant | HTTP | description |
|---|---|---|---|
| 10004 | `JSClusterIncompleteErr` | 503 | incomplete results |
| 10005 | `JSClusterNoPeersErrF` | 400 | `{err}` |
| 10006 | `JSClusterNotActiveErr` | 500 | JetStream not in clustered mode |
| 10007 | `JSClusterNotAssignedErr` | 500 | JetStream cluster not assigned to this server |
| 10008 | `JSClusterNotAvailErr` | 503 | JetStream system temporarily unavailable |
| 10009 | `JSClusterNotLeaderErr` | 500 | JetStream cluster can not handle request |
| 10010 | `JSClusterRequiredErr` | 503 | JetStream clustering support required |
| 10011 | `JSClusterTagsErr` | 400 | tags placement not supported for operation |
| 10036 | `JSClusterUnSupportFeatureErr` | 503 | not currently supported in clustered mode |
| 10040 | `JSClusterPeerNotMemberErr` | 400 | peer not a member |
| 10044 | `JSClusterServerNotMemberErr` | 400 | server is not a member of the cluster |
| 10075 | `JSPeerRemapErr` | 503 | peer remap failed |
| 10202 | `JSClusterServerMemberChangeInflightErr` | 400 | cluster member change is in progress |

## server/jetstream_cluster.go

### `server/jetstream_cluster.go` lines 457–462 — the meta group's name and its store block size

```go
   457	const (
   458		defaultStoreDirName  = "_js_"
   459		defaultMetaGroupName = "_meta_"
   460		defaultMetaFSBlkSize = 1024 * 1024
   461		jsExcludePlacement   = "!jetstream"
   462	)
```

### `server/jetstream_cluster.go` lines 43–89 — `jetStreamCluster` — what a server holds for the meta layer

```go
    43	type jetStreamCluster struct {
    44		// The metacontroller raftNode.
    45		meta RaftNode
    46		// For stream and consumer assignments. All servers will have this be the same.
    47		// ACCOUNT -> STREAM -> Stream Assignment -> Consumers
    48		streams map[string]map[string]*streamAssignment
    49		// These are inflight proposals and used to apply limits when there are
    50		// concurrent requests that would otherwise be accepted.
    51		// We also record the assignment for the stream/consumer. This is needed since if we have
    52		// concurrent requests for same account and stream/consumer we need to let it process to get
    53		// a response but they need to be same group, peers etc. and sync subjects.
    54		inflightStreams   map[string]map[string]*inflightStreamInfo
    55		inflightConsumers map[string]map[string]map[string]*inflightConsumerInfo
    56		// Tracks raft groups currently being started by createRaftGroup, so that
    57		// concurrent callers for the same group can wait without holding js.mu
    58		// across the disk I/O performed during startup.
    59		creatingRaftGroups map[string]chan struct{}
    60		// Holds a map of a peer ID to the reply subject, to only respond after gaining
    61		// quorum on the peer-remove action.
    62		peerRemoveReply map[string]peerRemoveInfo
    63		// Raft term, used to determine if we are still the leader for the current term.
    64		term uint64
    65		// Signals meta-leader should check the stream assignments.
    66		streamsCheck bool
    67		// Server.
    68		s *Server
    69		// Internal client.
    70		c *client
    71		// Processing assignment results.
    72		streamResults   *subscription
    73		consumerResults *subscription
    74		// System level request to have the leader stepdown.
    75		stepdown *subscription
    76		// System level requests to remove a peer.
    77		peerRemove *subscription
    78		// System level request to move a stream
    79		peerStreamMove *subscription
    80		// System level request to cancel a stream move
    81		peerStreamCancelMove *subscription
    82		// To pop out the monitorCluster before the raft layer.
    83		qch chan struct{}
    84		// To notify others that monitorCluster has actually stopped.
    85		stopped chan struct{}
    86		// Track last meta snapshot time and duration for monitoring.
    87		lastMetaSnapTime     int64 // Unix nanoseconds
    88		lastMetaSnapDuration int64 // Duration in nanoseconds
    89	}
```

### `server/jetstream_cluster.go` lines 121–155 — `entryOp` — the operations written to the meta log (and to stream/consumer logs)

```go
   121	type entryOp uint8
   122	
   123	// ONLY ADD TO THE END, DO NOT INSERT IN BETWEEN WILL BREAK SERVER INTEROP.
   124	const (
   125		// Meta ops.
   126		assignStreamOp entryOp = iota
   127		assignConsumerOp
   128		removeStreamOp
   129		removeConsumerOp
   130		// Stream ops.
   131		streamMsgOp
   132		purgeStreamOp
   133		deleteMsgOp
   134		// Consumer ops.
   135		updateDeliveredOp
   136		updateAcksOp
   137		// Compressed consumer assignments.
   138		assignCompressedConsumerOp
   139		// Filtered Consumer skip.
   140		updateSkipOp
   141		// Update Stream.
   142		updateStreamOp
   143		// For updating information on pending pull requests.
   144		addPendingRequest
   145		removePendingRequest
   146		// For sending compressed streams, either through RAFT or catchup.
   147		compressedStreamMsgOp
   148		// For sending deleted gaps on catchups for replicas.
   149		deleteRangeOp
   150		// Batch stream ops.
   151		batchMsgOp
   152		batchCommitMsgOp
   153		// Consumer rest to specific starting sequence.
   154		resetSeqOp
   155	)
```

### `server/jetstream_cluster.go` lines 159–168 — `raftGroup` — a stream's or consumer's group as the meta layer records it

```go
   159	type raftGroup struct {
   160		Name      string      `json:"name"`
   161		Peers     []string    `json:"peers"`
   162		Storage   StorageType `json:"store"`
   163		Cluster   string      `json:"cluster,omitempty"`
   164		Preferred string      `json:"preferred,omitempty"`
   165		ScaleUp   bool        `json:"scale_up,omitempty"`
   166		// Internal
   167		node RaftNode
   168	}
```

### `server/jetstream_cluster.go` lines 171–189 — `streamAssignment` — the record whose absence makes a stream an orphan

```go
   171	type streamAssignment struct {
   172		Client     *ClientInfo     `json:"client,omitempty"`
   173		Created    time.Time       `json:"created"`
   174		ConfigJSON json.RawMessage `json:"stream"`
   175		Config     *StreamConfig   `json:"-"`
   176		Group      *raftGroup      `json:"group"`
   177		Sync       string          `json:"sync"`
   178		Subject    string          `json:"subject,omitempty"`
   179		Reply      string          `json:"reply,omitempty"`
   180		Restore    *StreamState    `json:"restore_state,omitempty"`
   181		// Internal
   182		consumers   map[string]*consumerAssignment
   183		responded   atomic.Bool // copied via clone() to satisfy go vet's noCopy check
   184		recovering  bool
   185		reassigning bool // i.e. due to placement issues, lack of resources, etc.
   186		resetting   bool // i.e. there was an error, and we're stopping and starting the stream
   187		err         error
   188		unsupported *unsupportedStreamAssignment
   189	}
```

### `server/jetstream_cluster.go` lines 294–310 — `consumerAssignment`

```go
   294	type consumerAssignment struct {
   295		Client     *ClientInfo     `json:"client,omitempty"`
   296		Created    time.Time       `json:"created"`
   297		Name       string          `json:"name"`
   298		Stream     string          `json:"stream"`
   299		ConfigJSON json.RawMessage `json:"consumer"`
   300		Config     *ConsumerConfig `json:"-"`
   301		Group      *raftGroup      `json:"group"`
   302		Subject    string          `json:"subject,omitempty"`
   303		Reply      string          `json:"reply,omitempty"`
   304		State      *ConsumerState  `json:"state,omitempty"`
   305		// Internal
   306		responded   atomic.Bool // copied via clone() to satisfy go vet's noCopy check
   307		recovering  bool
   308		err         error
   309		unsupported *unsupportedConsumerAssignment
   310	}
```

### `server/jetstream_cluster.go` lines 2010–2017 — `writeableStreamAssignment` — what a meta snapshot stores per stream

```go
  2010	type writeableStreamAssignment struct {
  2011		Client     *ClientInfo     `json:"client,omitempty"`
  2012		Created    time.Time       `json:"created"`
  2013		ConfigJSON json.RawMessage `json:"stream"`
  2014		Group      *raftGroup      `json:"group"`
  2015		Sync       string          `json:"sync"`
  2016		Consumers  []*writeableConsumerAssignment
  2017	}
```

### `server/jetstream_cluster.go` lines 496–506 — `JetStreamIsClustered` / `JetStreamIsLeader`

```go
   496	func (s *Server) JetStreamIsClustered() bool {
   497		return s.jsClustered.Load()
   498	}
   499	
   500	func (s *Server) JetStreamIsLeader() bool {
   501		return s.isMetaLeader.Load()
   502	}
   503	
   504	func (s *Server) JetStreamIsCurrent() bool {
   505		js := s.getJetStream()
   506		if js == nil {
```

### `server/jetstream_cluster.go` lines 636–663 — `JetStreamClusterPeers` — the meta peers the leader counts as live

```go
   636	func (s *Server) JetStreamClusterPeers() []string {
   637		js := s.getJetStream()
   638		if js == nil {
   639			return nil
   640		}
   641		js.mu.RLock()
   642		defer js.mu.RUnlock()
   643	
   644		cc := js.cluster
   645		if !cc.isLeader() || cc.meta == nil {
   646			return nil
   647		}
   648		peers := cc.meta.Peers()
   649		var nodes []string
   650		for _, p := range peers {
   651			si, ok := s.nodeToInfo.Load(p.ID)
   652			if !ok || si == nil {
   653				continue
   654			}
   655			ni := si.(nodeInfo)
   656			// Ignore if offline, no JS, or no current stats have been received.
   657			if ni.offline || !ni.js || ni.stats == nil {
   658				continue
   659			}
   660			nodes = append(nodes, si.(nodeInfo).name)
   661		}
   662		return nodes
   663	}
```

### `server/jetstream_cluster.go` lines 1009–1123 — `setupMetaGroup` — store path, bootstrap vs recovery, observer mode

```go
  1009	func (js *jetStream) setupMetaGroup() error {
  1010		s := js.srv
  1011		s.Noticef("Creating JetStream metadata controller")
  1012	
  1013		// Setup our WAL for the metagroup.
  1014		sysAcc := s.SystemAccount()
  1015		if sysAcc == nil {
  1016			return ErrNoSysAccount
  1017		}
  1018		storeDir := filepath.Join(js.config.StoreDir, sysAcc.Name, defaultStoreDirName, defaultMetaGroupName)
  1019	
  1020		js.srv.optsMu.RLock()
  1021		syncAlways := js.srv.opts.SyncAlways
  1022		syncInterval := js.srv.opts.SyncInterval
  1023		js.srv.optsMu.RUnlock()
  1024		fs, err := newFileStoreWithCreated(
  1025			FileStoreConfig{StoreDir: storeDir, BlockSize: defaultMetaFSBlkSize, AsyncFlush: false, SyncAlways: syncAlways, SyncInterval: syncInterval, srv: s},
  1026			StreamConfig{Name: defaultMetaGroupName, Storage: FileStorage},
  1027			time.Now().UTC(),
  1028			s.jsKeyGen(s.getOpts().JetStreamKey, defaultMetaGroupName),
  1029			s.jsKeyGen(s.getOpts().JetStreamOldKey, defaultMetaGroupName),
  1030		)
  1031		if err != nil {
  1032			s.Errorf("Error creating filestore: %v", err)
  1033			return err
  1034		}
  1035	
  1036		cfg := &RaftConfig{Name: defaultMetaGroupName, Store: storeDir, Log: fs, Recovering: true}
  1037	
  1038		// If we are soliciting leafnode connections and we are sharing a system account and do not disable it with a hint,
  1039		// we want to move to observer mode so that we extend the solicited cluster or supercluster but do not form our own.
  1040		cfg.Observer = s.canExtendOtherDomain() && s.getOpts().JetStreamExtHint != jsNoExtend
  1041	
  1042		var bootstrap bool
  1043		if ps, err := readPeerState(s.diskIOSemaphore(), storeDir); err != nil {
  1044			s.Noticef("JetStream cluster bootstrapping")
  1045			bootstrap = true
  1046			peers := s.ActivePeers()
  1047			s.Debugf("JetStream cluster initial peers: %+v", peers)
  1048			if err := s.bootstrapRaftNode(cfg, peers, false); err != nil {
  1049				return err
  1050			}
  1051			if cfg.Observer {
  1052				s.Noticef("Turning JetStream metadata controller Observer Mode on")
  1053				s.Noticef("In cases where the JetStream domain is not intended to be extended through a SYS account leaf node connection")
  1054				s.Noticef("and waiting for leader election until first contact is not acceptable,")
  1055				s.Noticef(`manually disable Observer Mode by setting the JetStream Option "extension_hint: %s"`, jsNoExtend)
  1056			}
  1057		} else {
  1058			s.Noticef("JetStream cluster recovering state")
  1059			// correlate the value of observer with observations from a previous run.
  1060			if cfg.Observer {
  1061				switch ps.domainExt {
  1062				case extExtended:
  1063					s.Noticef("Keeping JetStream metadata controller Observer Mode on - due to previous contact")
  1064				case extNotExtended:
  1065					s.Noticef("Turning JetStream metadata controller Observer Mode off - due to previous contact")
  1066					cfg.Observer = false
  1067				case extUndetermined:
  1068					s.Noticef("Turning JetStream metadata controller Observer Mode on - no previous contact")
  1069					s.Noticef("In cases where the JetStream domain is not intended to be extended through a SYS account leaf node connection")
  1070					s.Noticef("and waiting for leader election until first contact is not acceptable,")
  1071					s.Noticef(`manually disable Observer Mode by setting the JetStream Option "extension_hint: %s"`, jsNoExtend)
  1072				}
  1073			} else {
  1074				// To track possible configuration changes, responsible for an altered value of cfg.Observer,
  1075				// set extension state to undetermined.
  1076				ps.domainExt = extUndetermined
  1077				if err := writePeerState(s.diskIOSemaphore(), storeDir, ps); err != nil {
  1078					return err
  1079				}
  1080			}
  1081		}
  1082	
  1083		// Start up our meta node.
  1084		n, err := s.startRaftNode(sysAcc.GetName(), cfg, pprofLabels{
  1085			"type":    "metaleader",
  1086			"account": sysAcc.Name,
  1087		})
  1088		if err != nil {
  1089			s.Warnf("Could not start metadata controller: %v", err)
  1090			return err
  1091		}
  1092	
  1093		// If we are bootstrapped with no state, start campaign early.
  1094		if bootstrap {
  1095			n.Campaign()
  1096		}
  1097	
  1098		c := s.createInternalJetStreamClient()
  1099	
  1100		js.mu.Lock()
  1101		defer js.mu.Unlock()
  1102		js.cluster = &jetStreamCluster{
  1103			meta:    n,
  1104			streams: make(map[string]map[string]*streamAssignment),
  1105			s:       s,
  1106			c:       c,
  1107			qch:     make(chan struct{}),
  1108			stopped: make(chan struct{}),
  1109		}
  1110		atomic.StoreInt32(&js.clustered, 1)
  1111		c.registerWithAccount(sysAcc)
  1112	
  1113		// Set to true before we start.
  1114		js.metaRecovering = true
  1115		js.srv.startGoRoutine(
  1116			js.monitorCluster,
  1117			pprofLabels{
  1118				"type":    "metaleader",
  1119				"account": sysAcc.Name,
  1120			},
  1121		)
  1122		return nil
  1123	}
```

### `server/jetstream_cluster.go` lines 1140–1156 — `isLeaderless` — when the API answers 10008 instead of staying silent

```go
  1140	func (js *jetStream) isLeaderless() bool {
  1141		js.mu.RLock()
  1142		cc := js.cluster
  1143		if cc == nil || cc.meta == nil {
  1144			js.mu.RUnlock()
  1145			return false
  1146		}
  1147		meta := cc.meta
  1148		js.mu.RUnlock()
  1149	
  1150		// If we don't have a leader.
  1151		// Make sure we have been running for enough time.
  1152		if meta.Leaderless() && time.Since(meta.Created()) > lostQuorumIntervalDefault {
  1153			return true
  1154		}
  1155		return false
  1156	}
```

### `server/jetstream_cluster.go` lines 1159–1201 — `isGroupLeaderless` — the same test for a stream's or consumer's group

```go
  1159	func (js *jetStream) isGroupLeaderless(rg *raftGroup) bool {
  1160		if rg == nil || js == nil {
  1161			return false
  1162		}
  1163		js.mu.RLock()
  1164		cc := js.cluster
  1165		started := js.started
  1166	
  1167		// If we are not a member we can not say..
  1168		if cc.meta == nil {
  1169			js.mu.RUnlock()
  1170			return false
  1171		}
  1172		if !rg.isMember(cc.meta.ID()) {
  1173			js.mu.RUnlock()
  1174			return false
  1175		}
  1176		// Single peer groups always have a leader if we are here.
  1177		if rg.node == nil {
  1178			js.mu.RUnlock()
  1179			return false
  1180		}
  1181		node := rg.node
  1182		js.mu.RUnlock()
  1183		// If we don't have a leader.
  1184		if node.Leaderless() {
  1185			// Threshold for jetstream startup.
  1186			const startupThreshold = 10 * time.Second
  1187	
  1188			if node.HadPreviousLeader() {
  1189				// Make sure we have been running long enough to intelligently determine this.
  1190				if time.Since(started) > startupThreshold {
  1191					return true
  1192				}
  1193			}
  1194			// Make sure we have been running for enough time.
  1195			if time.Since(node.Created()) > lostQuorumIntervalDefault {
  1196				return true
  1197			}
  1198		}
  1199	
  1200		return false
  1201	}
```

### `server/jetstream_cluster.go` lines 1507–1560 — `checkForOrphans` — the deletion behind the standalone-to-cluster gotcha

```go
  1507	// Called after recovery of the cluster on startup to check for any orphans.
  1508	// Streams and consumers are recovered from disk, and the meta layer's mappings
  1509	// should clean them up, but under crash scenarios there could be orphans.
  1510	func (js *jetStream) checkForOrphans() {
  1511		// Can not hold jetstream lock while trying to delete streams or consumers.
  1512		js.mu.Lock()
  1513		s, cc := js.srv, js.cluster
  1514		s.Debugf("JetStream cluster checking for orphans")
  1515	
  1516		// We only want to cleanup any orphans if we know we are current with the meta-leader.
  1517		meta := cc.meta
  1518		if meta == nil || meta.Leaderless() {
  1519			js.mu.Unlock()
  1520			s.Debugf("JetStream cluster skipping check for orphans, no meta-leader")
  1521			return
  1522		}
  1523		if !meta.Healthy() {
  1524			js.mu.Unlock()
  1525			s.Debugf("JetStream cluster skipping check for orphans, not current with the meta-leader")
  1526			return
  1527		}
  1528		streams, consumers := js.getOrphans()
  1529		js.mu.Unlock()
  1530	
  1531		for _, mset := range streams {
  1532			mset.mu.RLock()
  1533			accName, stream := mset.acc.Name, mset.cfg.Name
  1534			mset.mu.RUnlock()
  1535			s.Warnf("Detected orphaned stream '%s > %s', will cleanup", accName, stream)
  1536			if err := mset.delete(); err != nil {
  1537				s.Warnf("Deleting stream encountered an error: %v", err)
  1538			}
  1539		}
  1540		for _, o := range consumers {
  1541			o.mu.RLock()
  1542			accName, mset, consumer := o.acc.Name, o.mset, o.name
  1543			o.mu.RUnlock()
  1544			stream := "N/A"
  1545			if mset != nil {
  1546				mset.mu.RLock()
  1547				stream = mset.cfg.Name
  1548				mset.mu.RUnlock()
  1549			}
  1550			if o.isDurable() {
  1551				s.Warnf("Detected orphaned durable consumer '%s > %s > %s', will cleanup", accName, stream, consumer)
  1552			} else {
  1553				s.Debugf("Detected orphaned consumer '%s > %s > %s', will cleanup", accName, stream, consumer)
  1554			}
  1555	
  1556			if err := o.delete(); err != nil {
  1557				s.Warnf("Deleting consumer encountered an error: %v", err)
  1558			}
  1559		}
  1560	}
```

### `server/jetstream_cluster.go` lines 1562–1585 — `getOrphans` — recovered from disk but not in `cc.streams`

```go
  1562	// Returns orphaned streams and consumers that were recovered from disk, but don't
  1563	// exist as clustered stream/consumer assignments.
  1564	// Lock should be held.
  1565	func (js *jetStream) getOrphans() (streams []*stream, consumers []*consumer) {
  1566		cc := js.cluster
  1567		for accName, jsa := range js.accounts {
  1568			asa := cc.streams[accName]
  1569			jsa.mu.RLock()
  1570			for stream, mset := range jsa.streams {
  1571				if sa := asa[stream]; sa == nil {
  1572					streams = append(streams, mset)
  1573				} else {
  1574					// This one is good, check consumers now.
  1575					for _, o := range mset.getPublicConsumers() {
  1576						if sa.consumers[o.String()] == nil {
  1577							consumers = append(consumers, o)
  1578						}
  1579					}
  1580				}
  1581			}
  1582			jsa.mu.RUnlock()
  1583		}
  1584		return streams, consumers
  1585	}
```

### `server/jetstream_cluster.go` lines 1601–1628 — `monitorCluster` — the meta apply loop's timers and thresholds

```go
  1601		const compactInterval = time.Minute
  1602		const compactMinInterval = 15 * time.Second
  1603		t := time.NewTicker(compactInterval)
  1604		defer t.Stop()
  1605	
  1606		// Used to check cold boot cluster when possibly in mixed mode.
  1607		const leaderCheckInterval = time.Second
  1608		lt := time.NewTicker(leaderCheckInterval)
  1609		defer lt.Stop()
  1610	
  1611		// Check the general health once an hour.
  1612		const healthCheckInterval = 1 * time.Hour
  1613		ht := time.NewTicker(healthCheckInterval)
  1614		defer ht.Stop()
  1615	
  1616		// Utility to check health.
  1617		checkHealth := func() {
  1618			if hs := s.healthz(nil); hs.Error != _EMPTY_ {
  1619				s.Warnf("%v", hs.Error)
  1620			}
  1621		}
  1622	
  1623		var (
  1624			isLeader       bool
  1625			lastSnapTime   time.Time
  1626			compactSizeMin = uint64(8 * 1024 * 1024) // 8MB
  1627			minSnapDelta   = 30 * time.Second
  1628		)
```

### `server/jetstream_cluster.go` lines 1649–1670 — `doSnapshot` — when the meta log is compacted (`meta_compact`, `meta_compact_size`, `meta_compact_sync`)

```go
  1649		doSnapshot := func(force bool) {
  1650			// Suppress during recovery.
  1651			// If snapshots have failed, and we're not forced to, we'll wait for the timer since it'll now be forced.
  1652			if recovering || (!force && failedSnapshots.Load() > 0) {
  1653				return
  1654			}
  1655			// Suppress if an async snapshot is already in progress.
  1656			snapMu.Lock()
  1657			if snapshotting {
  1658				snapMu.Unlock()
  1659				return
  1660			}
  1661			// Look up what the threshold is for compaction. Re-reading from config here as it is reloadable.
  1662			js.srv.optsMu.RLock()
  1663			ethresh := js.srv.opts.JetStreamMetaCompact
  1664			szthresh := js.srv.opts.JetStreamMetaCompactSize
  1665			// Allows reverting to sync/blocking snapshots instead of the default async snapshots.
  1666			syncSnapshot := js.srv.opts.JetStreamMetaCompactSync
  1667			js.srv.optsMu.RUnlock()
  1668			// Work out our criteria for snapshotting.
  1669			byEntries, bySize := ethresh > 0, szthresh > 0
  1670			byNeither := !byEntries && !bySize
```

### `server/jetstream_cluster.go` lines 1876–1916 — end of recovery: first snapshot, the 30-second orphan timer, the snapshot triggers

```go
  1876						// Signals we have replayed all of our metadata.
  1877						wasMetaRecovering := js.isMetaRecovering()
  1878						js.clearMetaRecovering()
  1879						recovering = false
  1880						// Clear.
  1881						ru = nil
  1882						s.Debugf("Recovered JetStream cluster metadata")
  1883						// Snapshot now so we start with freshly compacted log.
  1884						doSnapshot(true)
  1885						if wasMetaRecovering {
  1886							// Reset, it could be we didn't need to install a snapshot. This ensures we don't degrade
  1887							// to a blocking snapshot if we install our first snapshot during normal operations.
  1888							snapMu.Lock()
  1889							fallbackSnapshot = false
  1890							snapMu.Unlock()
  1891							oc = time.AfterFunc(30*time.Second, js.checkForOrphans)
  1892							// Do a health check here as well.
  1893							go checkHealth()
  1894						}
  1895						continue
  1896					}
  1897					if isRecovering, didSnap, err := js.applyMetaEntries(ce.Entries, ru); err == nil {
  1898						var nb uint64
  1899						// Some entries can fail without an error when shutting down, don't move applied forward.
  1900						if !js.isShuttingDown() {
  1901							_, nb = n.Applied(ce.Index)
  1902						}
  1903						if js.hasPeerEntries(ce.Entries) || (didSnap && !isLeader) {
  1904							doSnapshot(true)
  1905						} else if nb > compactSizeMin {
  1906							snapMu.Lock()
  1907							expired := time.Since(lastSnapTime) > minSnapDelta
  1908							snapMu.Unlock()
  1909							if expired {
  1910								doSnapshot(false)
  1911							}
  1912						}
  1913						recovering = isRecovering
  1914					} else {
  1915						s.Warnf("Error applying JetStream cluster entries: %v", err)
  1916					}
```

### `server/jetstream_cluster.go` lines 1921–1951 — leader change and the periodic timers

```go
  1921			case lc := <-lch:
  1922				isLeader = lc.isLeader
  1923				// Process the change.
  1924				js.processLeaderChange(isLeader, lc.term)
  1925				if isLeader {
  1926					s.sendInternalMsgLocked(serverStatsPingReqSubj, _EMPTY_, nil, nil)
  1927					// Install a snapshot as we become leader.
  1928					js.checkClusterSize()
  1929					doSnapshot(false)
  1930				}
  1931	
  1932			case <-t.C:
  1933				// Start forcing snapshots if they failed previously.
  1934				forceIfFailed := failedSnapshots.Load() > 0
  1935				doSnapshot(forceIfFailed)
  1936				// Periodically check the cluster size.
  1937				if n.Leader() {
  1938					js.checkClusterSize()
  1939				}
  1940			case <-ht.C:
  1941				// Do this in a separate go routine.
  1942				go checkHealth()
  1943	
  1944			case <-lt.C:
  1945				s.Debugf("Checking JetStream cluster state")
  1946				// If we have a current leader or had one in the past we can cancel this here since the metaleader
  1947				// will be in charge of all peer state changes.
  1948				// For cold boot only.
  1949				if !n.Leaderless() || n.HadPreviousLeader() {
  1950					lt.Stop()
  1951					continue
```

### `server/jetstream_cluster.go` lines 1966–2007 — `checkClusterSize` — the expected peer set is adjusted down in mixed mode

```go
  1966	func (js *jetStream) checkClusterSize() {
  1967		s, n := js.server(), js.getMetaGroup()
  1968		if n == nil {
  1969			return
  1970		}
  1971		// We will check that we have a correct cluster set size by checking for any non-js servers
  1972		// which can happen in mixed mode.
  1973		ps := n.(*raft).currentPeerState()
  1974		if len(ps.knownPeers) >= ps.clusterSize {
  1975			return
  1976		}
  1977	
  1978		// Grab our active peers.
  1979		peers := s.ActivePeers()
  1980	
  1981		// If we have not registered all of our peers yet we can't do
  1982		// any adjustments based on a mixed mode. We will periodically check back.
  1983		if len(peers) < ps.clusterSize {
  1984			return
  1985		}
  1986	
  1987		s.Debugf("Checking JetStream cluster size")
  1988	
  1989		// If we are here our known set as the leader is not the same as the cluster size.
  1990		// Check to see if we have a mixed mode setup.
  1991		var totalJS int
  1992		for _, p := range peers {
  1993			if si, ok := s.nodeToInfo.Load(p); ok && si != nil {
  1994				if si.(nodeInfo).js {
  1995					totalJS++
  1996				}
  1997			}
  1998		}
  1999		// If we have less then our cluster size adjust that here. Can not do individual peer removals since
  2000		// they will not be in the tracked peers.
  2001		if totalJS < ps.clusterSize {
  2002			s.Debugf("Adjusting JetStream cluster size from %d to %d", ps.clusterSize, totalJS)
  2003			if err := n.AdjustClusterSize(totalJS); err != nil {
  2004				s.Warnf("Error adjusting JetStream cluster size: %v", err)
  2005			}
  2006		}
  2007	}
```

### `server/jetstream_cluster.go` lines 2479–2533 — `processAddPeer` — a returning peer is folded back into streams missing peers

```go
  2479	func (js *jetStream) processAddPeer(peer string) {
  2480		js.mu.Lock()
  2481		defer js.mu.Unlock()
  2482	
  2483		s, cc := js.srv, js.cluster
  2484		if cc == nil || cc.meta == nil {
  2485			return
  2486		}
  2487		isLeader := cc.isLeader()
  2488	
  2489		// Now check if we are meta-leader. We will check for any re-assignments.
  2490		if !isLeader {
  2491			return
  2492		}
  2493	
  2494		sir, ok := s.nodeToInfo.Load(peer)
  2495		if !ok || sir == nil {
  2496			return
  2497		}
  2498		si := sir.(nodeInfo)
  2499	
  2500		for accName, sa := range js.streamAssignmentsOrInflightSeqAllAccounts() {
  2501			if sa.unsupported != nil {
  2502				continue
  2503			}
  2504			if sa.missingPeers() {
  2505				// Make sure the right cluster etc.
  2506				if si.cluster != sa.Client.Cluster {
  2507					continue
  2508				}
  2509				// If we are here we can add in this peer.
  2510				csa := sa.copyGroup()
  2511				csa.Group.Peers = append(csa.Group.Peers, peer)
  2512				// Send our proposal for this csa. Also use same group definition for all the consumers as well.
  2513				if err := cc.meta.Propose(cc.term, encodeAddStreamAssignment(csa)); err != nil {
  2514					return
  2515				}
  2516				cc.trackInflightStreamProposal(accName, csa, false)
  2517				for ca := range js.consumerAssignmentsOrInflightSeq(accName, csa.Config.Name) {
  2518					if ca.unsupported != nil {
  2519						continue
  2520					}
  2521					// Ephemerals are R=1, so only auto-remap durables, or R>1.
  2522					if ca.Config.Durable != _EMPTY_ || len(ca.Group.Peers) > 1 {
  2523						cca := ca.copyGroup()
  2524						cca.Group.Peers = csa.Group.Peers
  2525						if err := cc.meta.Propose(cc.term, encodeAddConsumerAssignment(cca)); err != nil {
  2526							return
  2527						}
  2528						cc.trackInflightConsumerProposal(accName, csa.Config.Name, cca, false)
  2529					}
  2530				}
  2531			}
  2532		}
  2533	}
```

### `server/jetstream_cluster.go` lines 2535–2586 — `processRemovePeer` — a removed server disables its own JetStream

```go
  2535	func (js *jetStream) processRemovePeer(peer string) {
  2536		// We may be already disabled.
  2537		if js == nil || js.disabled.Load() {
  2538			return
  2539		}
  2540	
  2541		js.mu.Lock()
  2542		s, cc := js.srv, js.cluster
  2543		if cc == nil || cc.meta == nil {
  2544			js.mu.Unlock()
  2545			return
  2546		}
  2547		isLeader := cc.isLeader()
  2548		// All nodes will check if this is them.
  2549		isUs := cc.meta.ID() == peer
  2550		js.mu.Unlock()
  2551	
  2552		if isUs {
  2553			s.Errorf("JetStream being DISABLED, our server was removed from the cluster")
  2554			adv := &JSServerRemovedAdvisory{
  2555				TypedEvent: TypedEvent{
  2556					Type: JSServerRemovedAdvisoryType,
  2557					ID:   nuid.Next(),
  2558					Time: time.Now().UTC(),
  2559				},
  2560				Server:   s.Name(),
  2561				ServerID: s.ID(),
  2562				Cluster:  s.cachedClusterName(),
  2563				Domain:   s.getOpts().JetStreamDomain,
  2564			}
  2565			s.publishAdvisory(nil, JSAdvisoryServerRemoved, adv)
  2566	
  2567			go s.DisableJetStream()
  2568		}
  2569	
  2570		// Now check if we are meta-leader. We will attempt re-assignment.
  2571		if !isLeader {
  2572			return
  2573		}
  2574	
  2575		js.mu.Lock()
  2576		defer js.mu.Unlock()
  2577	
  2578		for _, sa := range js.streamAssignmentsOrInflightSeqAllAccounts() {
  2579			if sa.unsupported != nil {
  2580				continue
  2581			}
  2582			if rg := sa.Group; rg.isMember(peer) {
  2583				js.removePeerFromStreamLocked(sa, peer)
  2584			}
  2585		}
  2586	}
```

### `server/jetstream_cluster.go` lines 2673–2735 — `applyMetaEntries` — snapshot, remove-peer, add-peer, then the `entryOp` switch

```go
  2673	func (js *jetStream) applyMetaEntries(entries []*Entry, ru *recoveryUpdates) (bool, bool, error) {
  2674		var didSnap bool
  2675		isRecovering := ru != nil
  2676	
  2677		for _, e := range entries {
  2678			// If we received a lower-level catchup entry, mark that we're recovering.
  2679			// We can optimize by staging all meta operations until we're caught up.
  2680			// At that point we can apply the diff in one go.
  2681			if e.Type == EntryCatchup {
  2682				isRecovering = true
  2683				// A catchup entry only contains this, so we can exit now and have the
  2684				// recoveryUpdates struct be populated for the next invocation of applyMetaEntries.
  2685				return isRecovering, didSnap, nil
  2686			}
  2687	
  2688			if e.Type == EntrySnapshot {
  2689				if err := js.applyMetaSnapshot(e.Data, ru, isRecovering); err != nil {
  2690					return isRecovering, didSnap, err
  2691				}
  2692				didSnap = true
  2693			} else if e.Type == EntryRemovePeer {
  2694				if !js.isMetaRecovering() {
  2695					peer := string(e.Data)
  2696					js.processRemovePeer(peer)
  2697	
  2698					// The meta leader can now respond to the peer-removal,
  2699					// since a quorum of nodes has this in their log.
  2700					s := js.srv
  2701					if s.JetStreamIsLeader() {
  2702						var (
  2703							info peerRemoveInfo
  2704							ok   bool
  2705						)
  2706						js.mu.Lock()
  2707						if cc := js.cluster; cc != nil && cc.peerRemoveReply != nil {
  2708							if info, ok = cc.peerRemoveReply[peer]; ok {
  2709								delete(cc.peerRemoveReply, peer)
  2710							}
  2711							if len(cc.peerRemoveReply) == 0 {
  2712								cc.peerRemoveReply = nil
  2713							}
  2714						}
  2715						js.mu.Unlock()
  2716	
  2717						if info.reply != _EMPTY_ {
  2718							sysAcc := s.SystemAccount()
  2719							var resp = JSApiMetaServerRemoveResponse{ApiResponse: ApiResponse{Type: JSApiMetaServerRemoveResponseType}}
  2720							resp.Success = true
  2721							s.sendAPIResponse(info.ci, sysAcc, info.subject, info.reply, info.request, s.jsonResponse(&resp))
  2722						}
  2723					}
  2724				}
  2725			} else if e.Type == EntryAddPeer {
  2726				if !js.isMetaRecovering() {
  2727					js.processAddPeer(string(e.Data))
  2728				}
  2729			} else {
  2730				buf := e.Data
  2731				if len(buf) == 0 {
  2732					return isRecovering, didSnap, errBadEntryOp
  2733				}
  2734				switch entryOp(buf[0]) {
  2735				case assignStreamOp:
```

### `server/jetstream_cluster.go` lines 7601–7678 — `processLeaderChange` — the metadata-leader log lines

```go
  7601	func (js *jetStream) processLeaderChange(isLeader bool, term uint64) {
  7602		if js == nil {
  7603			return
  7604		}
  7605		s := js.srv
  7606		if s == nil {
  7607			return
  7608		}
  7609	
  7610		if isLeader {
  7611			s.Noticef("Self is new JetStream cluster metadata leader")
  7612			s.sendDomainLeaderElectAdvisory()
  7613		} else {
  7614			var node string
  7615			if meta := js.getMetaGroup(); meta != nil {
  7616				node = meta.GroupLeader()
  7617			}
  7618			if node == _EMPTY_ {
  7619				s.Noticef("JetStream cluster no metadata leader")
  7620			} else if srv := js.srv.serverNameForNode(node); srv == _EMPTY_ {
  7621				s.Noticef("JetStream cluster new remote metadata leader")
  7622			} else if clst := js.srv.clusterNameForNode(node); clst == _EMPTY_ {
  7623				s.Noticef("JetStream cluster new metadata leader: %s", srv)
  7624			} else {
  7625				s.Noticef("JetStream cluster new metadata leader: %s/%s", srv, clst)
  7626			}
  7627		}
  7628	
  7629		js.mu.Lock()
  7630		defer js.mu.Unlock()
  7631	
  7632		// Update our server atomic, while holding the lock to not race with API requests.
  7633		s.isMetaLeader.Store(isLeader)
  7634		js.cluster.term = term
  7635	
  7636		// Clear replies for peer-removes.
  7637		js.cluster.peerRemoveReply = nil
  7638	
  7639		// Clear inflight proposal tracking.
  7640		js.cluster.inflightStreams = nil
  7641		js.cluster.inflightConsumers = nil
  7642	
  7643		if isLeader {
  7644			if meta := js.cluster.meta; meta != nil && meta.IsObserver() {
  7645				meta.StepDown()
  7646				return
  7647			}
  7648		}
  7649	
  7650		if isLeader {
  7651			js.startUpdatesSub()
  7652		} else {
  7653			js.stopUpdatesSub()
  7654			// TODO(dlc) - stepdown.
  7655		}
  7656	
  7657		// If we have been signaled to check the streams, this is for a bug that left stream
  7658		// assignments with no sync subject after an update and no way to sync/catchup outside of the RAFT layer.
  7659		if isLeader && js.cluster.streamsCheck {
  7660			cc := js.cluster
  7661			for acc, sa := range js.streamAssignmentsOrInflightSeqAllAccounts() {
  7662				if sa.unsupported != nil {
  7663					continue
  7664				}
  7665				if sa.Sync == _EMPTY_ {
  7666					s.Warnf("Stream assignment corrupt for stream '%s > %s'", acc, sa.Config.Name)
  7667					nsa := &streamAssignment{Group: sa.Group, Config: sa.Config, Subject: sa.Subject, Reply: sa.Reply, Client: sa.Client, Created: sa.Created}
  7668					nsa.Sync = syncSubjForStream()
  7669					if err := cc.meta.Propose(cc.term, encodeUpdateStreamAssignment(nsa)); err != nil {
  7670						return
  7671					}
  7672					cc.trackInflightStreamProposal(acc, nsa, false)
  7673				}
  7674			}
  7675			// Clear check.
  7676			cc.streamsCheck = false
  7677		}
  7678	}
```

### `server/jetstream_cluster.go` lines 7508–7537 — the meta leader's subscriptions: assignment results, `$JS.API.META.LEADER.STEPDOWN`, `$JS.API.SERVER.REMOVE`, stream move

```go
  7508	const (
  7509		streamAssignmentSubj   = "$SYS.JSC.STREAM.ASSIGNMENT.RESULT"
  7510		consumerAssignmentSubj = "$SYS.JSC.CONSUMER.ASSIGNMENT.RESULT"
  7511	)
  7512	
  7513	// Lock should be held.
  7514	func (js *jetStream) startUpdatesSub() {
  7515		cc, s, c := js.cluster, js.srv, js.cluster.c
  7516		if cc.streamResults == nil {
  7517			cc.streamResults, _ = s.systemSubscribe(streamAssignmentSubj, _EMPTY_, false, c, js.processStreamAssignmentResults)
  7518		}
  7519		if cc.consumerResults == nil {
  7520			cc.consumerResults, _ = s.systemSubscribe(consumerAssignmentSubj, _EMPTY_, false, c, js.processConsumerAssignmentResults)
  7521		}
  7522		if cc.stepdown == nil {
  7523			cc.stepdown, _ = s.systemSubscribe(JSApiLeaderStepDown, _EMPTY_, false, c, s.jsLeaderStepDownRequest)
  7524		}
  7525		if cc.peerRemove == nil {
  7526			cc.peerRemove, _ = s.systemSubscribe(JSApiRemoveServer, _EMPTY_, false, c, s.jsLeaderServerRemoveRequest)
  7527		}
  7528		if cc.peerStreamMove == nil {
  7529			cc.peerStreamMove, _ = s.systemSubscribe(JSApiServerStreamMove, _EMPTY_, false, c, s.jsLeaderServerStreamMoveRequest)
  7530		}
  7531		if cc.peerStreamCancelMove == nil {
  7532			cc.peerStreamCancelMove, _ = s.systemSubscribe(JSApiServerStreamCancelMove, _EMPTY_, false, c, s.jsLeaderServerStreamCancelMoveRequest)
  7533		}
  7534		if js.accountPurge == nil {
  7535			js.accountPurge, _ = s.systemSubscribe(JSApiAccountPurge, _EMPTY_, false, c, s.jsLeaderAccountPurgeRequest)
  7536		}
  7537	}
```

### `server/jetstream_cluster.go` lines 8305–8320 — `jsClusteredStreamRequest` — a stream create is a proposal to the meta group

```go
  8305		// Preserve the original creation time on an idempotent create retry.
  8306		created := time.Now().UTC()
  8307		if self != nil {
  8308			created = self.Created
  8309		}
  8310		// Sync subject for post snapshot sync.
  8311		sa := &streamAssignment{Group: rg, Sync: syncSubject, Config: cfg, Subject: subject, Reply: reply, Client: ci, Created: created}
  8312		if err := cc.meta.Propose(cc.term, encodeAddStreamAssignment(sa)); err != nil {
  8313			return
  8314		}
  8315		// On success, add this as an inflight proposal so we can apply limits
  8316		// on concurrent create requests while this stream assignment has
  8317		// possibly not been processed yet.
  8318		cc.trackInflightStreamProposal(acc.Name, sa, false)
  8319	}
  8320	
```

### `server/jetstream_cluster.go` lines 3188–3197 — stream-group compaction constants (`monitorStream`)

```go
  3188		const (
  3189			compactInterval    = 2 * time.Minute
  3190			compactMinInterval = 15 * time.Second
  3191			compactSizeMin     = 8 * 1024 * 1024
  3192			compactNumMin      = 65536
  3193		)
  3194	
  3195		// Spread these out for large numbers on server restart.
  3196		rci := time.Duration(rand.Int63n(int64(time.Minute)))
  3197		t := time.NewTicker(compactInterval + rci)
```

### `server/jetstream_cluster.go` lines 6602–6612 — consumer-group compaction constants (`monitorConsumer`)

```go
  6602		const (
  6603			compactInterval    = 2 * time.Minute
  6604			compactMinInterval = 15 * time.Second
  6605			compactSizeMin     = 64 * 1024 // What is stored here is always small for consumers.
  6606			compactNumMin      = 1024
  6607			minSnapDelta       = 10 * time.Second
  6608		)
  6609	
  6610		// Spread these out for large numbers on server restart.
  6611		rci := time.Duration(rand.Int63n(int64(time.Minute)))
  6612		t := time.NewTicker(compactInterval + rci)
```

## server/raft.go

### `server/raft.go` lines 289–310 — the timing constants: election window, heartbeat, lost-quorum interval, peer-remove timeout

```go
   289	const (
   290		minElectionTimeoutDefault      = 4 * time.Second
   291		maxElectionTimeoutDefault      = 9 * time.Second
   292		minCampaignTimeoutDefault      = 100 * time.Millisecond
   293		maxCampaignTimeoutDefault      = 8 * minCampaignTimeoutDefault
   294		hbIntervalDefault              = 1 * time.Second
   295		lostQuorumIntervalDefault      = hbIntervalDefault * 10 // 10 seconds
   296		lostQuorumCheckIntervalDefault = hbIntervalDefault * 10 // 10 seconds
   297		observerModeIntervalDefault    = 48 * time.Hour
   298		peerRemoveTimeoutDefault       = 5 * time.Minute
   299	)
   300	
   301	var (
   302		minElectionTimeout   = minElectionTimeoutDefault
   303		maxElectionTimeout   = maxElectionTimeoutDefault
   304		minCampaignTimeout   = minCampaignTimeoutDefault
   305		maxCampaignTimeout   = maxCampaignTimeoutDefault
   306		hbInterval           = hbIntervalDefault
   307		lostQuorumInterval   = lostQuorumIntervalDefault
   308		lostQuorumCheck      = lostQuorumCheckIntervalDefault
   309		observerModeInterval = observerModeIntervalDefault
   310		peerRemoveTimeout    = peerRemoveTimeoutDefault
```

### `server/raft.go` lines 364–404 — `bootstrapRaftNode` — the expected meta peer count at first start

```go
   364	func (s *Server) bootstrapRaftNode(cfg *RaftConfig, knownPeers []string, allPeersKnown bool) error {
   365		if cfg == nil {
   366			return errNilCfg
   367		}
   368		// Check validity of peers if presented.
   369		for _, p := range knownPeers {
   370			if len(p) != idLen {
   371				return fmt.Errorf("raft: illegal peer: %q", p)
   372			}
   373		}
   374		expected := len(knownPeers)
   375		// We need to adjust this is all peers are not known.
   376		if !allPeersKnown {
   377			s.Debugf("Determining expected peer size for JetStream meta group")
   378			if expected < 2 {
   379				expected = 2
   380			}
   381			opts := s.getOpts()
   382			nrs := len(opts.Routes)
   383	
   384			cn := s.ClusterName()
   385			ngwps := 0
   386			for _, gw := range opts.Gateway.Gateways {
   387				// Ignore our own cluster if specified.
   388				if gw.Name == cn {
   389					continue
   390				}
   391				// Each configured gateway URL represents one remote endpoint, so
   392				// count it as a single peer. We must not resolve the host and add
   393				// one per returned address: a hostname on a dual-stack host (e.g.
   394				// "localhost" -> 127.0.0.1 + ::1) would then count the same server
   395				// multiple times, inflating the expected meta-group size above the
   396				// real node count and preventing meta leader election.
   397				ngwps += len(gw.URLs)
   398			}
   399	
   400			if expected < nrs+ngwps {
   401				expected = nrs + ngwps
   402				s.Debugf("Adjusting expected peer set size to %d with %d known", expected, len(knownPeers))
   403			}
   404		}
```

### `server/raft.go` lines 1029–1050 — `ProposeAddPeer`

```go
  1029	func (n *raft) ProposeAddPeer(peer string) error {
  1030		n.RLock()
  1031		// Check state under lock, we might not be leader anymore.
  1032		if n.State() != Leader {
  1033			n.RUnlock()
  1034			return errNotLeader
  1035		}
  1036		// Error if we had a previous write error.
  1037		if werr := n.werr; werr != nil {
  1038			n.RUnlock()
  1039			return werr
  1040		}
  1041		if n.membChange != nil {
  1042			n.RUnlock()
  1043			return errMembershipChange
  1044		}
  1045		prop := n.prop
  1046		n.RUnlock()
  1047	
  1048		prop.push(newProposedEntry(newEntry(EntryAddPeer, []byte(peer)), _EMPTY_))
  1049		return nil
  1050	}
```

### `server/raft.go` lines 1053–1089 — `ProposeRemovePeer` — forwarded to the leader; the last node cannot be removed

```go
  1053	func (n *raft) ProposeRemovePeer(peer string) error {
  1054		n.RLock()
  1055	
  1056		// Error if we had a previous write error.
  1057		if werr := n.werr; werr != nil {
  1058			n.RUnlock()
  1059			return werr
  1060		}
  1061	
  1062		if n.State() != Leader {
  1063			subj := n.rpsubj
  1064			n.RUnlock()
  1065	
  1066			// Forward the proposal to the leader
  1067			n.sendRPC(subj, _EMPTY_, []byte(peer))
  1068			return nil
  1069		}
  1070	
  1071		if n.membChange != nil {
  1072			n.RUnlock()
  1073			return errMembershipChange
  1074		}
  1075		if _, ok := n.peers[peer]; !ok {
  1076			n.RUnlock()
  1077			return errPeerNotFound
  1078		}
  1079		if len(n.peers) <= 1 {
  1080			n.RUnlock()
  1081			return errRemoveLastNode
  1082		}
  1083	
  1084		prop := n.prop
  1085		n.RUnlock()
  1086	
  1087		prop.push(newProposedEntry(newEntry(EntryRemovePeer, []byte(peer)), _EMPTY_))
  1088		return nil
  1089	}
```

### `server/raft.go` lines 1099–1103 — `ClusterSize`

```go
  1099	func (n *raft) ClusterSize() int {
  1100		n.Lock()
  1101		defer n.Unlock()
  1102		return n.csz
  1103	}
```

### `server/raft.go` lines 1108–1125 — `AdjustBootClusterSize` — quorum is `csz/2 + 1`

```go
  1108	func (n *raft) AdjustBootClusterSize(csz int) error {
  1109		n.Lock()
  1110		defer n.Unlock()
  1111	
  1112		if n.leader != noLeader || n.pleader.Load() {
  1113			return errAdjustBootCluster
  1114		}
  1115		// Same floor as bootstrap.
  1116		if csz < 2 {
  1117			csz = 2
  1118		}
  1119		// Adjust the cluster size and the number of nodes needed to establish
  1120		// a quorum.
  1121		n.csz = csz
  1122		n.qn = n.csz/2 + 1
  1123	
  1124		return nil
  1125	}
```

### `server/raft.go` lines 1129–1149 — `AdjustClusterSize`

```go
  1129	func (n *raft) AdjustClusterSize(csz int) error {
  1130		n.Lock()
  1131		defer n.Unlock()
  1132	
  1133		// Check state under lock, we might not be leader anymore.
  1134		if n.State() != Leader {
  1135			return errNotLeader
  1136		}
  1137		// Same floor as bootstrap.
  1138		if csz < 2 {
  1139			csz = 2
  1140		}
  1141	
  1142		// Adjust the cluster size and the number of nodes needed to establish
  1143		// a quorum.
  1144		n.csz = csz
  1145		n.qn = n.csz/2 + 1
  1146	
  1147		n.sendPeerState()
  1148		return nil
  1149	}
```

### `server/raft.go` lines 2018–2095 — `StepDown` — how a successor is chosen (seen within `hbInterval*3`)

```go
  2018	func (n *raft) StepDown(preferred ...string) error {
  2019		n.Lock()
  2020		// Check state under lock, we might not be leader anymore.
  2021		if n.State() != Leader {
  2022			n.Unlock()
  2023			return errNotLeader
  2024		}
  2025		if len(preferred) > 1 {
  2026			n.Unlock()
  2027			return errTooManyPrefs
  2028		}
  2029	
  2030		n.debug("Being asked to stepdown")
  2031	
  2032		// See if we have up to date followers.
  2033		maybeLeader := noLeader
  2034		if len(preferred) > 0 {
  2035			if preferred[0] != _EMPTY_ {
  2036				maybeLeader = preferred[0]
  2037			} else {
  2038				preferred = nil
  2039			}
  2040		}
  2041	
  2042		// Can't pick ourselves.
  2043		if maybeLeader == n.id {
  2044			maybeLeader = noLeader
  2045			preferred = nil
  2046		}
  2047	
  2048		// If we have a preferred check it first.
  2049		if maybeLeader != noLeader {
  2050			var isHealthy bool
  2051			if ps, ok := n.peers[maybeLeader]; ok {
  2052				si, ok := n.s.nodeToInfo.Load(maybeLeader)
  2053				isHealthy = ok && !si.(nodeInfo).offline && time.Since(ps.ts) < hbInterval*3
  2054			}
  2055			if !isHealthy {
  2056				maybeLeader = noLeader
  2057			}
  2058		}
  2059	
  2060		// If we do not have a preferred at this point pick the first healthy one.
  2061		// Make sure not ourselves.
  2062		if maybeLeader == noLeader {
  2063			for peer, ps := range n.peers {
  2064				if peer == n.id {
  2065					continue
  2066				}
  2067				si, ok := n.s.nodeToInfo.Load(peer)
  2068				isHealthy := ok && !si.(nodeInfo).offline && time.Since(ps.ts) < hbInterval*3
  2069				if isHealthy {
  2070					maybeLeader = peer
  2071					break
  2072				}
  2073			}
  2074		}
  2075		n.Unlock()
  2076	
  2077		if len(preferred) > 0 && maybeLeader == noLeader {
  2078			n.debug("Can not transfer to preferred peer %q", preferred[0])
  2079		}
  2080	
  2081		// If we have a new leader selected, transfer over to them.
  2082		// Send the append entry directly rather than via the proposals queue,
  2083		// as we will switch to follower state immediately and will blow away
  2084		// the contents of the proposal queue in the process.
  2085		if maybeLeader != noLeader {
  2086			n.debug("Selected %q for new leader, stepping down due to leadership transfer", maybeLeader)
  2087			ae := newEntry(EntryLeaderTransfer, []byte(maybeLeader))
  2088			n.sendAppendEntry([]*Entry{ae})
  2089		}
  2090	
  2091		// Force us to stepdown here.
  2092		n.stepdown(noLeader)
  2093	
  2094		return nil
  2095	}
```

### `server/raft.go` lines 2306–2357 — `Reset` — what a leaf discards when it extends another domain

```go
  2306	func (n *raft) Reset() {
  2307		n.Lock()
  2308		defer n.Unlock()
  2309	
  2310		n.debug("Resetting Raft state")
  2311	
  2312		n.stepdownLocked(_EMPTY_)
  2313	
  2314		// Cancel any in-flight catchup so it does not race the reset.
  2315		n.cancelCatchup()
  2316	
  2317		// Drop proposals and inbound entries; they are no longer meaningful
  2318		// against whatever log this node ends up following.
  2319		n.prop.drain()
  2320		n.entry.drain()
  2321		n.resp.drain()
  2322		n.apply.drain()
  2323		n.reqs.drain()
  2324		n.votes.drain()
  2325	
  2326		// Remove every snapshot under our snapshots dir, not just the one referenced
  2327		// by n.snapfile. Orphans (e.g. from a crash between install and the previous
  2328		// file's removal) would otherwise be picked up by setupLastSnapshot on the
  2329		// next restart and reseed the state we are discarding here.
  2330		snapDir := filepath.Join(n.sd, snapshotsDir)
  2331		if err := os.RemoveAll(snapDir); err != nil {
  2332			n.warn("Error removing snapshots directory during reset: %v", err)
  2333		}
  2334		if err := os.MkdirAll(snapDir, defaultDirPerms); err != nil {
  2335			n.warn("Error recreating snapshots directory during reset: %v", err)
  2336		}
  2337		n.snapfile = _EMPTY_
  2338	
  2339		// Abort any inflight async snapshot checkpoint.
  2340		n.snapshotting = false
  2341	
  2342		// Reset the WAL, but reset these first to not trip the assertion.
  2343		n.commit, n.hcommit, n.applied, n.processed, n.papplied = 0, 0, 0, 0, 0
  2344		n.resetWAL()
  2345	
  2346		// Reset peer set to just ourselves; a new leader will fold us back into
  2347		// the cluster's membership view via processPeerState.
  2348		n.peers = map[string]*lps{n.id: {time.Time{}, 0}}
  2349		n.removed = nil
  2350		n.adjustClusterSizeAndQuorum()
  2351	
  2352		n.term, n.vote = 0, _EMPTY_
  2353		n.writeTermVote()
  2354	
  2355		// Persist the cleared peer state so a restart picks up the reset.
  2356		n.writePeerState(n.currentPeerStateLocked())
  2357	}
```

### `server/raft.go` lines 2359–2371 — the `$NRG.*` subjects

```go
  2359	const (
  2360		raftAllSubj        = "$NRG.>"
  2361		raftVoteSubj       = "$NRG.V.%s"
  2362		raftAppendSubj     = "$NRG.AE.%s"
  2363		raftPropSubj       = "$NRG.P.%s"
  2364		raftRemovePeerSubj = "$NRG.RP.%s"
  2365		raftReply          = "$NRG.R.%s"
  2366		raftCatchupReply   = "$NRG.CR.%s"
  2367		// Catchup progress replies happen in their own subject space for
  2368		// flow control to the leader, but not counting toward quorum.
  2369		raftCatchupProgressReply = "$NRG.CP.%s"
  2370		raftCatchupProgressPre   = "$NRG.CP."
  2371	)
```

### `server/raft.go` lines 2443–2446 — `randElectionTimeout`

```go
  2443	func randElectionTimeout() time.Duration {
  2444		delta := rand.Int63n(int64(maxElectionTimeout - minElectionTimeout))
  2445		return (minElectionTimeout + time.Duration(delta))
  2446	}
```

### `server/raft.go` lines 3231–3235 — `runAsLeader` — the heartbeat and lost-quorum tickers

```go
  3231		hb := time.NewTicker(hbInterval)
  3232		defer hb.Stop()
  3233	
  3234		lq := time.NewTicker(lostQuorumCheck)
  3235		defer lq.Stop()
```

### `server/raft.go` lines 3316–3329 — `Quorum`

```go
  3316	func (n *raft) Quorum() bool {
  3317		n.RLock()
  3318		defer n.RUnlock()
  3319	
  3320		nc := 0
  3321		for id, peer := range n.peers {
  3322			if id == n.id || time.Since(peer.ts) < lostQuorumInterval {
  3323				if nc++; nc >= n.qn {
  3324					return true
  3325				}
  3326			}
  3327		}
  3328		return false
  3329	}
```

### `server/raft.go` lines 3331–3354 — `lostQuorum` — a peer counts while heard from within `lostQuorumInterval`

```go
  3331	func (n *raft) lostQuorum() bool {
  3332		n.RLock()
  3333		defer n.RUnlock()
  3334		return n.lostQuorumLocked()
  3335	}
  3336	
  3337	func (n *raft) lostQuorumLocked() bool {
  3338		// In order to avoid false positives that can happen in heavily loaded systems
  3339		// make sure nothing is queued up that we have not processed yet.
  3340		// Also make sure we let any scale up actions settle before deciding.
  3341		if n.resp.len() != 0 || (!n.lsut.IsZero() && time.Since(n.lsut) < lostQuorumInterval) {
  3342			return false
  3343		}
  3344	
  3345		nc := 0
  3346		for id, peer := range n.peers {
  3347			if id == n.id || time.Since(peer.ts) < lostQuorumInterval {
  3348				if nc++; nc >= n.qn {
  3349					return false
  3350				}
  3351			}
  3352		}
  3353		return true
  3354	}
```

### `server/raft.go` lines 3823–3840 — `adjustClusterSizeAndQuorum`

```go
  3823	func (n *raft) adjustClusterSizeAndQuorum() {
  3824		pcsz, ncsz := n.csz, len(n.peers)
  3825		n.csz = ncsz
  3826		n.qn = n.csz/2 + 1
  3827	
  3828		if ncsz > pcsz {
  3829			n.debug("Expanding our clustersize: %d -> %d", pcsz, ncsz)
  3830			n.lsut = time.Now()
  3831		} else if ncsz < pcsz {
  3832			n.debug("Decreasing our clustersize: %d -> %d", pcsz, ncsz)
  3833			if n.State() == Leader {
  3834				go n.sendHeartbeat()
  3835			}
  3836		}
  3837		if ncsz != pcsz {
  3838			n.recreateInternalSubsLocked()
  3839		}
  3840	}
```

### `server/raft.go` lines 3855–3882 — `trackPeer` — a removed peer can be re-added after `peerRemoveTimeout`

```go
  3855	// Track interactions with this peer.
  3856	func (n *raft) trackPeer(peer string) error {
  3857		n.Lock()
  3858		var needPeerAdd, isRemoved bool
  3859		var rts time.Time
  3860		if n.removed != nil {
  3861			rts, isRemoved = n.removed[peer]
  3862			// Removed peers can rejoin after timeout.
  3863			if isRemoved && time.Since(rts) >= peerRemoveTimeout {
  3864				isRemoved = false
  3865			}
  3866		}
  3867		if n.State() == Leader {
  3868			if _, ok := n.peers[peer]; !ok {
  3869				// Check if this peer had been removed previously.
  3870				needPeerAdd = !isRemoved
  3871			}
  3872		}
  3873		if ps := n.peers[peer]; ps != nil {
  3874			ps.ts = time.Now()
  3875		}
  3876		n.Unlock()
  3877	
  3878		if needPeerAdd {
  3879			n.ProposeAddPeer(peer)
  3880		}
  3881		return nil
  3882	}
```

### `server/raft.go` lines 4816–4827 — the append-entry overrun thresholds (2.14)

```go
  4816	const (
  4817		pauseQuorumThreshold = 100_000
  4818		pauseQuorumBytes     = 1 * 1024 * 1024 * 1024 // 1GB
  4819	
  4820		paeDropThreshold = 20_000
  4821		paeDropBytes     = 256 * 1024 * 1024 // 256MB
  4822	
  4823		paeWarnThreshold   = 10_000
  4824		paeWarnModulo      = 5_000
  4825		paeWarnBytes       = 128 * 1024 * 1024 // 128MB
  4826		paeWarnBytesModulo = 32 * 1024 * 1024  // 32MB
  4827	)
```

### `server/raft.go` lines 5072–5072 — `peers.idx`

```go
  5072	const peerStateFile = "peers.idx"
```

### `server/raft.go` lines 5512–5551 — `switchToCandidate` — who may not campaign; the 20-second quorum-lost signal

```go
  5512	func (n *raft) switchToCandidate() {
  5513		if n.State() == Closed {
  5514			return
  5515		}
  5516	
  5517		n.Lock()
  5518		defer n.Unlock()
  5519	
  5520		// If we are catching up or are in observer mode we can not switch.
  5521		// Avoid petitioning to become leader if we're behind on applies.
  5522		if n.observer || n.paused || n.processed < n.commit {
  5523			n.resetElect(minElectionTimeout / 4)
  5524			return
  5525		}
  5526	
  5527		// Do not campaign with an uncommitted membership change about us,
  5528		// otherwise we would try to become leader outside our peer set.
  5529		if n.membChange != nil && n.membChange.peer == n.id {
  5530			n.resetElect(minElectionTimeout)
  5531			return
  5532		}
  5533	
  5534		if n.State() != Candidate {
  5535			n.debug("Switching to candidate")
  5536		} else {
  5537			if n.lostQuorumLocked() && time.Since(n.llqrt) > 20*time.Second {
  5538				// We signal to the upper layers such that can alert on quorum lost.
  5539				n.updateLeadChange(false)
  5540				n.llqrt = time.Now()
  5541			}
  5542		}
  5543		// Increment the term.
  5544		n.term++
  5545		n.vote = noVote
  5546		// Reset quorum paused. If it was previously set, we checked above that we've applied all committed entries.
  5547		n.quorumPaused = false
  5548		// Clear current Leader.
  5549		n.updateLeader(noLeader)
  5550		n.switchState(Candidate)
  5551	}
```

## server/jetstream_api.go

### `server/jetstream_api.go` lines 187–212 — the system-account subjects: `$JS.API.META.LEADER.STEPDOWN`, **`$JS.API.SERVER.REMOVE`**, account purge, stream move

```go
   187		// JSApiLeaderStepDown is the endpoint to have our metaleader stepdown.
   188		// Only works from system account.
   189		// Will return JSON response.
   190		JSApiLeaderStepDown = "$JS.API.META.LEADER.STEPDOWN"
   191	
   192		// JSApiRemoveServer is the endpoint to remove a peer server from the cluster.
   193		// Only works from system account.
   194		// Will return JSON response.
   195		JSApiRemoveServer = "$JS.API.SERVER.REMOVE"
   196	
   197		// JSApiAccountPurge is the endpoint to purge the js content of an account
   198		// Only works from system account.
   199		// Will return JSON response.
   200		JSApiAccountPurge  = "$JS.API.ACCOUNT.PURGE.*"
   201		JSApiAccountPurgeT = "$JS.API.ACCOUNT.PURGE.%s"
   202	
   203		// JSApiServerStreamMove is the endpoint to move streams off a server
   204		// Only works from system account.
   205		// Will return JSON response.
   206		JSApiServerStreamMove  = "$JS.API.ACCOUNT.STREAM.MOVE.*.*"
   207		JSApiServerStreamMoveT = "$JS.API.ACCOUNT.STREAM.MOVE.%s.%s"
   208	
   209		// JSApiServerStreamCancelMove is the endpoint to cancel a stream move
   210		// Only works from system account.
   211		// Will return JSON response.
   212		JSApiServerStreamCancelMove  = "$JS.API.ACCOUNT.STREAM.CANCEL_MOVE.*.*"
```

### `server/jetstream_api.go` lines 338–348 — the domain mapping table (`$JS.<domain>.API.META.>` → `$JS.API.META.>`)

```go
   338		for srcMappingSuffix, to := range map[string]string{
   339			"INFO":       JSApiAccountInfo,
   340			"STREAM.>":   "$JS.API.STREAM.>",
   341			"CONSUMER.>": "$JS.API.CONSUMER.>",
   342			"DIRECT.>":   "$JS.API.DIRECT.>",
   343			"META.>":     "$JS.API.META.>",
   344			"SERVER.>":   "$JS.API.SERVER.>",
   345			"ACCOUNT.>":  "$JS.API.ACCOUNT.>",
   346			"$KV.>":      "$KV.>",
   347			"$OBJ.>":     "$OBJ.>",
   348		} {
```

### `server/jetstream_api.go` lines 798–806 — `apiDispatch` ignores the two system-level subjects

```go
   798	
   799	func (js *jetStream) apiDispatch(sub *subscription, c *client, acc *Account, subject, reply string, rmsg []byte) {
   800		// Ignore system level directives meta stepdown and peer remove requests here.
   801		if subject == JSApiLeaderStepDown ||
   802			subject == JSApiRemoveServer ||
   803			strings.HasPrefix(subject, jsAPIAccountPre) {
   804			return
   805		}
   806		// No lock needed, those are immutable.
```

### `server/jetstream_api.go` lines 1295–1309 — the pattern every meta-handled request uses: leaderless → 10008, not leader → silence

```go
  1295		if s.JetStreamIsClustered() {
  1296			js, cc := s.getJetStreamCluster()
  1297			if js == nil || cc == nil {
  1298				return
  1299			}
  1300			if js.isLeaderless() {
  1301				resp.Error = NewJSClusterNotAvailError()
  1302				s.sendAPIErrResponse(ci, acc, subject, reply, string(msg), s.jsonResponse(&resp))
  1303				return
  1304			}
  1305			// Make sure we are meta leader.
  1306			if !s.JetStreamIsLeader() {
  1307				return
  1308			}
  1309		}
```

### `server/jetstream_api.go` lines 2486–2521 — `jsLeaderServerRemoveRequest` — one change at a time, name → peer, 10044

```go
  2486		js.mu.Lock()
  2487		defer js.mu.Unlock()
  2488	
  2489		// Another peer-remove is already in progress, don't allow multiple concurrent changes.
  2490		if cc.peerRemoveReply != nil {
  2491			resp.Error = NewJSClusterServerMemberChangeInflightError()
  2492			s.sendAPIErrResponse(ci, acc, subject, reply, string(msg), s.jsonResponse(&resp))
  2493			return
  2494		}
  2495	
  2496		var found string
  2497		for _, p := range meta.Peers() {
  2498			// If Peer is specified, it takes precedence
  2499			if req.Peer != _EMPTY_ {
  2500				if p.ID == req.Peer {
  2501					found = req.Peer
  2502					break
  2503				}
  2504				continue
  2505			}
  2506			si, ok := s.nodeToInfo.Load(p.ID)
  2507			if ok && si.(nodeInfo).name == req.Server {
  2508				found = p.ID
  2509				break
  2510			}
  2511		}
  2512	
  2513		if found == _EMPTY_ {
  2514			resp.Error = NewJSClusterServerNotMemberError()
  2515			s.sendAPIErrResponse(ci, acc, subject, reply, string(msg), s.jsonResponse(&resp))
  2516			return
  2517		}
  2518	
  2519		if err := meta.ProposeRemovePeer(found); err != nil {
  2520			if err == errMembershipChange {
  2521				resp.Error = NewJSClusterServerMemberChangeInflightError()
```

### `server/jetstream_api.go` lines 2956–2975 — `jsLeaderStepDownRequest` — system account only

```go
  2956	// Request to have the meta leader stepdown.
  2957	// These will only be received by the meta leader, so less checking needed.
  2958	func (s *Server) jsLeaderStepDownRequest(sub *subscription, c *client, _ *Account, subject, reply string, rmsg []byte) {
  2959		if c == nil || !s.JetStreamEnabled() {
  2960			return
  2961		}
  2962	
  2963		ci, acc, hdr, msg, err := s.getRequestInfo(c, rmsg)
  2964		if err != nil {
  2965			s.Warnf(badAPIRequestT, msg)
  2966			return
  2967		}
  2968	
  2969		// This should only be coming from the System Account.
  2970		if acc != s.SystemAccount() {
  2971			s.RateLimitWarnf("JetStream API stepdown request from non-system account: %q user: %q", ci.serviceAccount(), ci.User)
  2972			return
  2973		}
  2974	
  2975		js, cc := s.getJetStreamCluster()
```

### `server/jetstream_api.go` lines 4424–4447 — `STREAM.INFO` on a work-queue or interest stream needs the meta leader

```go
  4424					}
  4425					// If the stream is WQ or Interest, we need the meta leader to answer.
  4426					if sa.Config.Retention != LimitsPolicy {
  4427						direct = false
  4428					}
  4429					js.mu.RUnlock()
  4430					if direct {
  4431						// Check to see if we have this stream and are the stream leader.
  4432						if !acc.JetStreamIsStreamLeader(streamNameFromSubject(subject)) {
  4433							return
  4434						}
  4435					} else {
  4436						if js.isLeaderless() {
  4437							resp.Error = NewJSClusterNotAvailError()
  4438							s.sendAPIErrResponse(ci, acc, subject, reply, string(msg), s.jsonResponse(&resp))
  4439							return
  4440						}
  4441						// Make sure we are meta leader.
  4442						if !s.JetStreamIsLeader() {
  4443							return
  4444						}
  4445					}
  4446				}
  4447			} else {
```

### `server/jetstream_api.go` lines 2841–2856 — `jsLeaderAccountPurgeRequest` — system account only

```go
  2841	func (s *Server) jsLeaderAccountPurgeRequest(sub *subscription, c *client, _ *Account, subject, reply string, rmsg []byte) {
  2842		if c == nil || !s.JetStreamEnabled() {
  2843			return
  2844		}
  2845	
  2846		ci, acc, hdr, msg, err := s.getRequestInfo(c, rmsg)
  2847		if err != nil {
  2848			s.Warnf(badAPIRequestT, msg)
  2849			return
  2850		}
  2851		if acc != s.SystemAccount() {
  2852			return
  2853		}
  2854	
  2855		js := s.getJetStream()
  2856		if js == nil {
```

## server/monitor.go

### `server/monitor.go` lines 2995–3004 — `HealthzOptions` — `js-meta-only`

```go
  2995	type HealthzOptions struct {
  2996		// Deprecated: Use JSEnabledOnly instead
  2997		JSEnabled     bool   `json:"js-enabled,omitempty"`
  2998		JSEnabledOnly bool   `json:"js-enabled-only,omitempty"`
  2999		JSServerOnly  bool   `json:"js-server-only,omitempty"`
  3000		JSMetaOnly    bool   `json:"js-meta-only,omitempty"`
  3001		Account       string `json:"account,omitempty"`
  3002		Stream        string `json:"stream,omitempty"`
  3003		Consumer      string `json:"consumer,omitempty"`
  3004		Details       bool   `json:"details,omitempty"`
```

### `server/monitor.go` lines 3089–3099 — `MetaClusterInfo` — `/jsz`'s `meta_cluster` object

```go
  3089	type MetaClusterInfo struct {
  3090		Name            string             `json:"name,omitempty"`     // Name is the name of the cluster
  3091		Leader          string             `json:"leader,omitempty"`   // Leader is the server name of the cluster leader
  3092		Peer            string             `json:"peer,omitempty"`     // Peer is unique ID of the leader
  3093		Replicas        []*PeerInfo        `json:"replicas,omitempty"` // Replicas is a list of known peers
  3094		Size            int                `json:"cluster_size"`       // Size is the known size of the cluster
  3095		Pending         int                `json:"pending"`            // Pending is how many RAFT messages are not yet processed
  3096		PendingRequests int                `json:"pending_requests"`   // PendingRequests is how many CRUD operations are queued for processing
  3097		PendingInfos    int                `json:"pending_infos"`      // PendingInfos is how many info operations are queued for processing
  3098		Snapshot        *MetaSnapshotStats `json:"snapshot"`           // Snapshot contains meta snapshot statistics
  3099	}
```

### `server/monitor.go` lines 3868–3907 — `healthz` — the meta-layer checks and their five messages

```go
  3868		var meta RaftNode
  3869		js.mu.RLock()
  3870		meta = cc.meta
  3871		js.mu.RUnlock()
  3872	
  3873		// Check meta layer health.
  3874		var metaNoLeader, metaClosed, metaUnhealthy bool
  3875		var metaWerr error
  3876		if meta != nil {
  3877			metaNoLeader = meta.GroupLeader() == _EMPTY_
  3878			metaClosed = meta.State() == Closed
  3879			metaUnhealthy = !meta.Healthy()
  3880			metaWerr = meta.GetWriteErr()
  3881		}
  3882		metaRecovering := js.isMetaRecovering()
  3883		if meta == nil || metaNoLeader || metaClosed || metaUnhealthy || metaWerr != nil || metaRecovering {
  3884			var desc string
  3885			if metaWerr != nil {
  3886				desc = fmt.Sprintf("JetStream meta layer write error: %v", metaWerr)
  3887			} else if metaClosed {
  3888				desc = "JetStream meta layer is not running"
  3889			} else if meta != nil && metaRecovering {
  3890				desc = "JetStream is still recovering meta layer"
  3891			} else if meta == nil || metaNoLeader {
  3892				desc = "JetStream has not established contact with a meta leader"
  3893			} else {
  3894				desc = "JetStream is not current with the meta leader"
  3895			}
  3896			if !details {
  3897				health.Status = na
  3898				health.Error = desc
  3899			} else {
  3900				health.Errors = []HealthzError{
  3901					{
  3902						Type:  HealthzErrorJetStream,
  3903						Error: desc,
  3904					},
  3905				}
  3906			}
  3907			return health
```

## server/jetstream.go

### `server/jetstream.go` lines 509–516 — a standalone server refuses to extend a domain unless `extension_hint: will_extend`

```go
   509		standAlone, canExtend := s.standAloneMode(), s.canExtendOtherDomain()
   510		if standAlone && canExtend && s.getOpts().JetStreamExtHint != jsWillExtend {
   511			canExtend = false
   512			s.Noticef("Standalone server started in clustered mode do not support extending domains")
   513			s.Noticef(`Manually disable standalone mode by setting the JetStream Option "extension_hint: %s"`, jsWillExtend)
   514		}
   515	
   516		// Indicate if we will be standalone for checking resource reservations, etc.
```

### `server/jetstream.go` lines 567–586 — `jsNoExtend`, `jsWillExtend`, `canExtendOtherDomain`

```go
   567	const jsNoExtend = "no_extend"
   568	const jsWillExtend = "will_extend"
   569	
   570	// This will check if we have a solicited leafnode that shares the system account
   571	// and extension is not manually disabled
   572	func (s *Server) canExtendOtherDomain() bool {
   573		opts := s.getOpts()
   574		sysAcc := s.SystemAccount().GetName()
   575		for _, r := range opts.LeafNode.Remotes {
   576			if r.LocalAccount == sysAcc {
   577				for _, denySub := range r.DenyImports {
   578					if subjectIsSubsetMatch(denySub, raftAllSubj) {
   579						return false
   580					}
   581				}
   582				return true
   583			}
   584		}
   585		return false
   586	}
```

### `server/jetstream.go` lines 704–733 — shutdown: the meta leader transfers leadership and waits 2 s

```go
   704		if s.JetStreamIsClustered() {
   705			isLeader := s.JetStreamIsLeader()
   706			js, cc := s.getJetStreamCluster()
   707			if js == nil {
   708				s.shutdownJetStream()
   709				return nil
   710			}
   711			js.mu.RLock()
   712			meta := cc.meta
   713			js.mu.RUnlock()
   714	
   715			if meta != nil {
   716				if isLeader {
   717					s.Warnf("JetStream initiating meta leader transfer")
   718					meta.StepDown()
   719					select {
   720					case <-s.quitCh:
   721						return nil
   722					case <-time.After(2 * time.Second):
   723					}
   724					if !s.JetStreamIsCurrent() {
   725						s.Warnf("JetStream timeout waiting for meta leader transfer")
   726					}
   727				}
   728				if deleteState {
   729					meta.Delete()
   730				} else {
   731					meta.Stop()
   732					meta.WaitForStop()
   733				}
```

### `server/jetstream.go` lines 2730–2731 — `JetStreamStoreDir`

```go
  2730		// JetStreamStoreDir is the prefix we use.
  2731		JetStreamStoreDir = "jetstream"
```

### `server/jetstream.go` lines 2844–2852 — a server that hits its resource limits gives up meta leadership

```go
  2844		// If we are meta leader we should relinquish that here.
  2845		if didAlert {
  2846			if js := s.getJetStream(); js != nil {
  2847				js.mu.RLock()
  2848				if cc := js.cluster; cc != nil && cc.meta != nil {
  2849					cc.meta.StepDown()
  2850				}
  2851				js.mu.RUnlock()
  2852			}
```

## server/server.go

### `server/server.go` lines 1570–1579 — `ActivePeers` — every known node that is not offline

```go
  1570	func (s *Server) ActivePeers() (peers []string) {
  1571		s.nodeToInfo.Range(func(k, v any) bool {
  1572			si := v.(nodeInfo)
  1573			if !si.offline {
  1574				peers = append(peers, k.(string))
  1575			}
  1576			return true
  1577		})
  1578		return peers
  1579	}
```

## server/opts.go

### `server/opts.go` lines 2772–2788 — the three `jetstream { meta_compact* }` keys

```go
  2772				case "meta_compact":
  2773					thres, ok := mv.(int64)
  2774					if !ok || thres < 0 {
  2775						return &configErr{tk, fmt.Sprintf("Expected an absolute size for %q, got %v", mk, mv)}
  2776					}
  2777					opts.JetStreamMetaCompact = uint64(thres)
  2778				case "meta_compact_size":
  2779					s, err := getStorageSize(mv)
  2780					if err != nil {
  2781						return &configErr{tk, fmt.Sprintf("%s %s", strings.ToLower(mk), err)}
  2782					}
  2783					if s < 0 {
  2784						return &configErr{tk, fmt.Sprintf("Expected an absolute size for %q, got %v", mk, mv)}
  2785					}
  2786					opts.JetStreamMetaCompactSize = uint64(s)
  2787				case "meta_compact_sync":
  2788					opts.JetStreamMetaCompactSync = mv.(bool)
```

### `server/opts.go` lines 2730–2731 — `jetstream { extension_hint }`

```go
  2730				case "extension_hint":
  2731					opts.JetStreamExtHint = mv.(string)
```

