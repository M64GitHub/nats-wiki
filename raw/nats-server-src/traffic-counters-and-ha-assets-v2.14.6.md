<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6, server/client.go, server/monitor.go, server/consumer.go, server/jetstream.go, server/jetstream_cluster.go, server/raft.go and server/opts.go fetched from raw.githubusercontent.com · fetched 2026-09-03 -->
# nats-server v2.14.6 — the traffic counters behind `/varz`, `/connz` and `nats-top`; the consumer fields only the leader computes; `ha_assets` and `max_ha_assets`

Verbatim line ranges from the tagged source, in the form of `constants-v2.14.6.md`, with the real line
numbers at v2.14.6. Read for phase E step 3 (`inbox/plan-the-reference-layer-2026-09-03.md`), behind
`wiki/reference/metrics.md`: question-bank row 139 (are the `in_msgs` / `out_msgs` / byte counters exact?),
the leader-only consumer fields the exporter and surveyor runs showed, and row 153 (what an "HA asset" is
and how many a server may hold).


## 1 · The traffic counters are exact, per server, and count payload bytes


### `server/client.go` lines 4338–4347

Every inbound client message increments the per-parse-buffer counters by one message and by the payload length without its trailing CR LF — so `in_bytes` counts payload bytes (headers included), not wire bytes.

```go
 4338	
 4339	// processInboundClientMsg is called to process an inbound msg from a client.
 4340	// Return if the message was delivered, and if the message was not delivered
 4341	// due to a permission issue.
 4342	func (c *client) processInboundClientMsg(msg []byte) (bool, bool) {
 4343		// Update statistics
 4344		// The msg includes the CR_LF, so pull back out for accounting.
 4345		c.in.msgs++
 4346		c.in.bytes += int32(len(msg) - LEN_CR_LF)
 4347	
```


### `server/client.go` lines 1596–1634

After each read-buffer parse the per-connection, per-account and per-server counters are updated atomically; `in_client_*` counts only `CLIENT` connections.

```go
 1596		postParse:
 1597			// If we are a ROUTER/LEAF and have processed an INFO, it is possible that
 1598			// we are asked to switch to compression now.
 1599			if checkCompress && c.in.flags.isSet(switchToCompression) {
 1600				c.in.flags.clear(switchToCompression)
 1601				// For now we support only s2 compression...
 1602				reader = s2.NewReader(nc)
 1603				decompress = true
 1604			}
 1605	
 1606			// Updates stats for client and server that were collected
 1607			// from parsing through the buffer.
 1608			if c.in.msgs > 0 {
 1609				inMsgs := int64(c.in.msgs)
 1610				inBytes := int64(c.in.bytes)
 1611	
 1612				atomic.AddInt64(&c.inMsgs, inMsgs)
 1613				atomic.AddInt64(&c.inBytes, inBytes)
 1614	
 1615				if acc != nil {
 1616					acc.stats.Lock()
 1617					acc.stats.inMsgs += inMsgs
 1618					acc.stats.inBytes += inBytes
 1619					if c.kind == LEAF {
 1620						acc.stats.ln.inMsgs += int64(inMsgs)
 1621						acc.stats.ln.inBytes += int64(inBytes)
 1622					}
 1623					acc.stats.Unlock()
 1624				}
 1625	
 1626				if c.kind == CLIENT {
 1627					atomic.AddInt64(&s.inClientMsgs, inMsgs)
 1628					atomic.AddInt64(&s.inClientBytes, inBytes)
 1629				}
 1630	
 1631				atomic.AddInt64(&s.inMsgs, inMsgs)
 1632				atomic.AddInt64(&s.inBytes, inBytes)
 1633			}
 1634	
```


### `server/client.go` lines 5296–5320

The delivery side: per-account and per-server `out` counters, atomic.

```go
 5296				clientBytes -= dlvClientMsgs * int64(LEN_CR_LF)
 5297			}
 5298	
 5299			if acc != nil {
 5300				acc.stats.Lock()
 5301				acc.stats.outMsgs += dlvMsgs
 5302				acc.stats.outBytes += totalBytes
 5303				if dlvRouteMsgs > 0 {
 5304					acc.stats.rt.outMsgs += dlvRouteMsgs
 5305					acc.stats.rt.outBytes += routeBytes
 5306				}
 5307				if dlvLeafMsgs > 0 {
 5308					acc.stats.ln.outMsgs += dlvLeafMsgs
 5309					acc.stats.ln.outBytes += leafBytes
 5310				}
 5311				acc.stats.Unlock()
 5312			}
 5313	
 5314			if srv := c.srv; srv != nil {
 5315				atomic.AddInt64(&srv.outMsgs, dlvMsgs)
 5316				atomic.AddInt64(&srv.outBytes, totalBytes)
 5317	
 5318				atomic.AddInt64(&srv.outClientMsgs, dlvClientMsgs)
 5319				atomic.AddInt64(&srv.outClientBytes, clientBytes)
 5320			}
```


### `server/monitor.go` lines 1264–1296

The `Varz` fields with the comments the source gives them — `in_msgs` includes routes, gateways and leaf nodes; `in_client_msgs` is clients only; `slow_consumers` is a since-start count; `stalled_clients` is a since-start count of stall events.

```go
 1264		Connections           int                    `json:"connections"`                       // Connections is the current connected connections
 1265		TotalConnections      uint64                 `json:"total_connections"`                 // TotalConnections is the total connections the server have ever handled
 1266		Routes                int                    `json:"routes"`                            // Routes is the number of connected route servers
 1267		Remotes               int                    `json:"remotes"`                           // Remotes is the configured route remote endpoints
 1268		Leafs                 int                    `json:"leafnodes"`                         // Leafs is the number connected leafnode clients
 1269		InMsgs                int64                  `json:"in_msgs"`                           // InMsgs is the total number of messages this server received. This includes messages from the clients, routers, gateways and leaf nodes
 1270		InBytes               int64                  `json:"in_bytes"`                          // InBytes is the total number of bytes this server received. This includes messages from the clients, routers, gateways and leaf nodes
 1271		InClientMsgs          int64                  `json:"in_client_msgs"`                    // InClientMsgs is the number of messages this server received from the clients
 1272		InClientBytes         int64                  `json:"in_client_bytes"`                   // InClientBytes is the number of bytes this server received from the clients
 1273		OutMsgs               int64                  `json:"out_msgs"`                          // OutMsgs is the total number of message this server sent. This includes messages sent to the clients, routers, gateways and leaf nodes
 1274		OutBytes              int64                  `json:"out_bytes"`                         // OutBytes is the total number of bytes this server sent. This includes messages sent to the clients, routers, gateways and leaf nodes
 1275		OutClientMsgs         int64                  `json:"out_client_msgs"`                   // OutClientMsgs is the number of messages this server sent to the clients
 1276		OutClientBytes        int64                  `json:"out_client_bytes"`                  // OutClientBytes is the number of bytes this server sent to the clients
 1277		SlowConsumers         int64                  `json:"slow_consumers"`                    // SlowConsumers is the total count of clients that were disconnected since start due to being slow consumers
 1278		StaleConnections      int64                  `json:"stale_connections"`                 // StaleConnections is the total count of stale connections that were detected
 1279		StalledClients        int64                  `json:"stalled_clients"`                   // StalledClients is the total number of times that clients have been stalled.
 1280		Subscriptions         uint32                 `json:"subscriptions"`                     // Subscriptions is the count of active subscriptions
 1281		HTTPReqStats          map[string]uint64      `json:"http_req_stats"`                    // HTTPReqStats is the number of requests each HTTP endpoint received
 1282		ConfigLoadTime        time.Time              `json:"config_load_time"`                  // ConfigLoadTime is the time the configuration was loaded or reloaded
 1283		ConfigDigest          string                 `json:"config_digest"`                     // ConfigDigest is a calculated hash of the current configuration
 1284		Tags                  jwt.TagList            `json:"tags,omitempty"`                    // Tags are the tags assigned to the server in configuration
 1285		Metadata              map[string]string      `json:"metadata,omitempty"`                // Metadata is the metadata assigned to the server in configuration
 1286		FeatureFlags          map[string]bool        `json:"feature_flags,omitempty"`           // FeatureFlags is the feature flags enabled/disabled in configuration
 1287		TrustedOperatorsJwt   []string               `json:"trusted_operators_jwt,omitempty"`   // TrustedOperatorsJwt is the JWTs for all trusted operators
 1288		TrustedOperatorsClaim []*jwt.OperatorClaims  `json:"trusted_operators_claim,omitempty"` // TrustedOperatorsClaim is the decoded claims for each trusted operator
 1289		SystemAccount         string                 `json:"system_account,omitempty"`          // SystemAccount is the name of the System account
 1290		PinnedAccountFail     uint64                 `json:"pinned_account_fails,omitempty"`    // PinnedAccountFail is how often user logon fails due to the issuer account not being pinned.
 1291		OCSPResponseCache     *OCSPResponseCacheVarz `json:"ocsp_peer_cache,omitempty"`         // OCSPResponseCache is the state of the OCSP cache
 1292		SlowConsumersStats    *SlowConsumersStats    `json:"slow_consumer_stats"`               // SlowConsumersStats are statistics about all detected Slow Consumer
 1293		StaleConnectionStats  *StaleConnectionStats  `json:"stale_connection_stats,omitempty"`  // StaleConnectionStats are statistics about all detected Stale Connections
 1294		DiskIOWaitStats       *DiskIOWaitStats       `json:"disk_io_wait_stats"`                // DiskIOWaitStats are statistics about disk I/O semaphore contention
 1295		Proxies               *ProxiesOptsVarz       `json:"proxies,omitempty"`                 // Proxies hold information about network proxy devices
 1296		TLSCertNotAfter       time.Time              `json:"tls_cert_not_after,omitzero"`       // TLSCertNotAfter is the expiration date of the TLS certificate of this server
```


### `server/monitor.go` lines 1894–1914

`/varz` reads the counters with `atomic.LoadInt64` — a snapshot of exact values, nothing sampled.

```go
 1894		}
 1895		v.Connections = len(s.clients)
 1896		v.TotalConnections = s.totalClients
 1897		v.Routes = s.numRoutes()
 1898		v.Remotes = s.numRemotes()
 1899		v.Leafs = len(s.leafs)
 1900		v.InMsgs = atomic.LoadInt64(&s.inMsgs)
 1901		v.InBytes = atomic.LoadInt64(&s.inBytes)
 1902		v.OutMsgs = atomic.LoadInt64(&s.outMsgs)
 1903		v.OutBytes = atomic.LoadInt64(&s.outBytes)
 1904		v.InClientMsgs = atomic.LoadInt64(&s.inClientMsgs)
 1905		v.InClientBytes = atomic.LoadInt64(&s.inClientBytes)
 1906		v.OutClientMsgs = atomic.LoadInt64(&s.outClientMsgs)
 1907		v.OutClientBytes = atomic.LoadInt64(&s.outClientBytes)
 1908		v.SlowConsumers = atomic.LoadInt64(&s.slowConsumers)
 1909		v.StalledClients = atomic.LoadInt64(&s.stalls)
 1910		v.SlowConsumersStats = &SlowConsumersStats{
 1911			Clients:  s.NumSlowConsumersClients(),
 1912			Routes:   s.NumSlowConsumersRoutes(),
 1913			Gateways: s.NumSlowConsumersGateways(),
 1914			Leafs:    s.NumSlowConsumersLeafs(),
```


### `server/monitor.go` lines 583–597

`/connz` copies each connection's own counters the same way.

```go
  583		ci.Uptime = myUptime(now.Sub(client.start))
  584		ci.Idle = myUptime(now.Sub(client.last))
  585		ci.RTT = rtt.String()
  586		ci.OutMsgs = client.outMsgs
  587		ci.OutBytes = client.outBytes
  588		ci.NumSubs = uint32(len(client.subs))
  589		ci.Pending = int(client.out.pb)
  590		ci.Name = client.opts.Name
  591		ci.Lang = client.opts.Lang
  592		ci.Version = client.opts.Version
  593		// inMsgs and inBytes are updated outside of the client's lock, so
  594		// we need to use atomic here.
  595		ci.InMsgs = atomic.LoadInt64(&client.inMsgs)
  596		ci.InBytes = atomic.LoadInt64(&client.inBytes)
  597		ci.Stalls = atomic.LoadInt64(&client.stalls)
```


### `server/monitor.go` lines 169–173

The default page size of `/connz` and `/subsz`: 1024 entries unless `limit` is given.

```go
  169	// DefaultConnListSize is the default size of the connection list.
  170	const DefaultConnListSize = 1024
  171	
  172	// DefaultSubListSize is the default size of the subscriptions list.
  173	const DefaultSubListSize = 1024
```


### `server/monitor.go` lines 448–466

With `?auth=true`, `account` is filled only for accounts other than the global account `$G`; `name_tag` falls back to the account name.

```go
  448				if subsDet {
  449					ci.SubsDetail = newSubsDetailList(client)
  450				} else if subs {
  451					ci.Subs = newSubsList(client)
  452				}
  453			}
  454			// Fill in user if auth requested.
  455			if auth {
  456				ci.AuthorizedUser = client.getRawAuthUser()
  457				if name := client.acc.GetName(); name != globalAccountName {
  458					ci.Account = name
  459				}
  460				ci.JWT = client.opts.JWT
  461				ci.IssuerKey = issuerForClient(client)
  462				ci.Tags = client.tags
  463				ci.NameTag = client.acc.getNameTag()
  464			}
  465			client.mu.Unlock()
  466			ci.JWT = redactBearerJWT(ci.JWT)
```


## 2 · Consumer info on a follower: `num_ack_pending` and `num_redelivered` come from the replicated state, `num_pending` is computed by the leader only


### `server/consumer.go` lines 3547–3566

`infoWithSnapAndReply` — the branch every `CONSUMER.INFO`, `/jsz` and `STATSZ` reply goes through.

```go
 3547		// We always need to pull certain data from our store.
 3548		if o.store != nil {
 3549			state, err := o.store.BorrowState()
 3550			if err != nil {
 3551				o.mu.Unlock()
 3552				return nil
 3553			}
 3554	
 3555			// If we are the leader we could have o.sseq that is skipped ahead.
 3556			// To maintain consistency in reporting (e.g. jsz) we always take the state for our delivered/ackfloor stream sequence.
 3557			// Only use skipped ahead o.sseq if we're a new consumer and have not yet replicated this state yet.
 3558			leader := o.isLeader()
 3559			if !leader || o.store.HasState() {
 3560				info.Delivered.Consumer, info.Delivered.Stream = state.Delivered.Consumer, state.Delivered.Stream
 3561			}
 3562			info.AckFloor.Consumer, info.AckFloor.Stream = state.AckFloor.Consumer, state.AckFloor.Stream
 3563			if !leader {
 3564				info.NumAckPending = len(state.Pending)
 3565				info.NumRedelivered = len(state.Redelivered)
 3566			}
```


### `server/consumer.go` lines 5625–5640

`streamNumPending` returns 0 without looking at the store unless this server is the consumer's leader.

```go
 5625	// Will force a set from the stream store of num pending on the consumer leader.
 5626	// Depends on delivery policy, for last per subject we calculate differently.
 5627	// Lock should be held.
 5628	func (o *consumer) streamNumPending() (uint64, error) {
 5629		if o.mset == nil || o.mset.store == nil || !o.isLeader() {
 5630			o.npc, o.npf = 0, 0
 5631			return 0, nil
 5632		}
 5633		npc, npf, err := o.calculateNumPending()
 5634		if err != nil {
 5635			return 0, err
 5636		}
 5637		o.npc, o.npf = int64(npc), npf
 5638		return o.numPending(), nil
 5639	}
 5640	
```


## 3 · `ha_assets`: the number of Raft nodes on this server, and the `max_ha_assets` limit


### `server/jetstream.go` lines 60–70

`JetStreamStats` — the `stats` block of `/varz`'s `jetstream` object, of `/jsz` and of `STATSZ`.

```go
   60	// Statistics about JetStream for this server.
   61	type JetStreamStats struct {
   62		Memory         uint64            `json:"memory"`
   63		Store          uint64            `json:"storage"`
   64		ReservedMemory uint64            `json:"reserved_memory"`
   65		ReservedStore  uint64            `json:"reserved_storage"`
   66		Accounts       int               `json:"accounts"`
   67		HAAssets       int               `json:"ha_assets"`
   68		API            JetStreamAPIStats `json:"api"`
   69	}
   70	
```


### `server/jetstream.go` lines 2615–2625

`ha_assets` is the count of Raft nodes this server runs.

```go
 2615			used = 0
 2616		}
 2617		stats.Memory = uint64(used)
 2618		used = atomic.LoadInt64(&js.storeUsed)
 2619		if used < 0 {
 2620			used = 0
 2621		}
 2622		stats.Store = uint64(used)
 2623		stats.HAAssets = s.numRaftNodes()
 2624		return &stats
 2625	}
```


### `server/raft.go` lines 798–802



```go
  798	func (s *Server) numRaftNodes() int {
  799		s.rnMu.RLock()
  800		defer s.rnMu.RUnlock()
  801		return len(s.raftNodes)
  802	}
```


### `server/opts.go` lines 376–380

The limit, in `jetstream { limits { max_ha_assets } }`: "the maximum of Streams and Consumers that may have more than 1 replica".

```go
  376		MaxRequestBatch           int           `json:"max_request_batch,omitempty"`             // MaxRequestBatch is the maximum amount of updates that can be sent in a batch
  377		MaxAckPending             int           `json:"max_ack_pending,omitempty"`               // MaxAckPending is the server limit for maximum amount of outstanding Acks
  378		MaxHAAssets               int           `json:"max_ha_assets,omitempty"`                 // MaxHAAssets is the maximum of Streams and Consumers that may have more than 1 replica
  379		Duplicates                time.Duration `json:"max_duplicate_window,omitempty"`          // Duplicates is the maximum value for duplicate tracking on Streams
  380		MaxBatchInflightPerStream int           `json:"max_batch_inflight_per_stream,omitempty"` // MaxBatchInflightPerStream is the maximum amount of open batches per stream
```


### `server/jetstream_cluster.go` lines 2952–2960

Enforced when a new Raft group would be created: the warning and the error the client sees.

```go
 2952		// Check here to see if we have a max HA Assets limit set.
 2953		if maxHaAssets := s.getOpts().JetStreamLimits.MaxHAAssets; maxHaAssets > 0 {
 2954			if s.numRaftNodes()+len(cc.creatingRaftGroups) > maxHaAssets {
 2955				s.Warnf("Maximum HA Assets limit reached: %d", maxHaAssets)
 2956				// Since the meta leader assigned this, send a statsz update to them to get them up to date.
 2957				go s.sendStatszUpdate()
 2958				return nil, errors.New("system limit reached")
 2959			}
 2960		}
```


### `server/jetstream_cluster.go` lines 7912–7936

Placement counts HA assets per peer from the assignments (the stats value is asynchronous).

```go
 7912	
 7913		// Grab the number of streams and HA assets currently assigned to each peer.
 7914		// HAAssets under usage is async, so calculate here in realtime based on assignments.
 7915		peerStreams := make(map[string]int, len(peers))
 7916		peerHA := make(map[string]int, len(peers))
 7917		for _, asa := range cc.streams {
 7918			for _, sa := range asa {
 7919				if sa.unsupported != nil {
 7920					continue
 7921				}
 7922				isHA := len(sa.Group.Peers) > 1
 7923				for _, peer := range sa.Group.Peers {
 7924					peerStreams[peer]++
 7925					if isHA {
 7926						peerHA[peer]++
 7927					}
 7928				}
 7929			}
 7930		}
 7931	
 7932		maxHaAssets := s.getOpts().JetStreamLimits.MaxHAAssets
 7933	
 7934		// An error is a result of multiple individual placement decisions.
 7935		// Which is why we keep taps on how often which one happened.
 7936		err := selectPeerError{}
```


### `server/jetstream_cluster.go` lines 8028–8036

A peer above the limit is discarded for the placement of a replicated stream — and the comment says the `_meta_` group is counted in `ha_assets`, so the comparison is `>` not `>=`.

```go
 8028				err.noStorage = true
 8029				continue
 8030			}
 8031			// HAAssets contain _meta_ which we want to ignore, hence > and not >=.
 8032			if maxHaAssets > 0 && ni.stats != nil && ni.stats.HAAssets > maxHaAssets {
 8033				s.Warnf("Peer selection: discard %s@%s (HA Asset Count: %d) exceeds max ha asset limit of %d for stream placement",
 8034					ni.name, ni.cluster, ni.stats.HAAssets, maxHaAssets)
 8035				err.misc = true
 8036				continue
```


### `server/jetstream_cluster.go` lines 8087–8090



```go
 8087		// If we are placing a replicated stream, let's sort based on HAAssets, as that is more important to balance.
 8088		if cfg.Replicas > 1 {
 8089			slices.SortStableFunc(nodes, func(i, j wn) int {
 8090				// Prefer online servers to offline ones.
```

