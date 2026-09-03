<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6, server/events.go, server/server.go, server/jetstream_events.go and server/accounts.go fetched from raw.githubusercontent.com · fetched 2026-09-03 -->
# nats-server v2.14.6 — the `$SYS` subjects: every subject the server publishes on or answers, with the request options, the event bodies and the HTTP mux

Verbatim line ranges from the tagged source, in the form of `constants-v2.14.6.md`: the line numbers are
the real ones at tag v2.14.6, so each claim on `wiki/reference/system-subjects.md` links to
`https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`. Read for phase E step 1
(`inbox/plan-the-reference-layer-2026-09-03.md`), behind `wiki/reference/system-subjects.md`, the
correction of `wiki/reference/monitoring-endpoints.md`, and the advisory-schema sweep of
`raw/nats-docs/reference/jetstream/advisory/` (`jetstream_events.go` is quoted whole because it is the
authority every one of those 24 pages is checked against). The behavioural half is
`system-subjects-observed-v2.14.6.md`.


## events.go — the subject constants, and the two intervals

Every `$SYS` subject the server knows, with the comments the source gives them; `eventsHBInterval` (30 s) is the account-connections heartbeat, `statsHBInterval` (10 s) the per-server `STATSZ` heartbeat, `statszRateLimit` (1 s) the floor between two `STATSZ` broadcasts.

```go
   40	
   41	const (
   42		accLookupReqTokens = 6
   43		accLookupReqSubj   = "$SYS.REQ.ACCOUNT.%s.CLAIMS.LOOKUP"
   44		accPackReqSubj     = "$SYS.REQ.CLAIMS.PACK"
   45		accListReqSubj     = "$SYS.REQ.CLAIMS.LIST"
   46		accClaimsReqSubj   = "$SYS.REQ.CLAIMS.UPDATE"
   47		accDeleteReqSubj   = "$SYS.REQ.CLAIMS.DELETE"
   48	
   49		connectEventSubj    = "$SYS.ACCOUNT.%s.CONNECT"
   50		disconnectEventSubj = "$SYS.ACCOUNT.%s.DISCONNECT"
   51		accDirectReqSubj    = "$SYS.REQ.ACCOUNT.%s.%s"
   52		accPingReqSubj      = "$SYS.REQ.ACCOUNT.PING.%s" // atm. only used for STATZ and CONNZ import from system account
   53		// kept for backward compatibility when using http resolver
   54		// this overlaps with the names for events but you'd have to have the operator private key in order to succeed.
   55		accUpdateEventSubjOld     = "$SYS.ACCOUNT.%s.CLAIMS.UPDATE"
   56		accUpdateEventSubjNew     = "$SYS.REQ.ACCOUNT.%s.CLAIMS.UPDATE"
   57		connsRespSubj             = "$SYS._INBOX_.%s"
   58		accConnsEventSubjNew      = "$SYS.ACCOUNT.%s.SERVER.CONNS"
   59		accConnsEventSubjOld      = "$SYS.SERVER.ACCOUNT.%s.CONNS" // kept for backward compatibility
   60		lameDuckEventSubj         = "$SYS.SERVER.%s.LAMEDUCK"
   61		shutdownEventSubj         = "$SYS.SERVER.%s.SHUTDOWN"
   62		clientKickReqSubj         = "$SYS.REQ.SERVER.%s.KICK"
   63		clientLDMReqSubj          = "$SYS.REQ.SERVER.%s.LDM"
   64		authErrorEventSubj        = "$SYS.SERVER.%s.CLIENT.AUTH.ERR"
   65		authErrorAccountEventSubj = "$SYS.ACCOUNT.CLIENT.AUTH.ERR"
   66		serverStatsSubj           = "$SYS.SERVER.%s.STATSZ"
   67		serverDirectReqSubj       = "$SYS.REQ.SERVER.%s.%s"
   68		serverPingReqSubj         = "$SYS.REQ.SERVER.PING.%s"
   69		serverStatsPingReqSubj    = "$SYS.REQ.SERVER.PING"             // use $SYS.REQ.SERVER.PING.STATSZ instead
   70		serverReloadReqSubj       = "$SYS.REQ.SERVER.%s.RELOAD"        // with server ID
   71		leafNodeConnectEventSubj  = "$SYS.ACCOUNT.%s.LEAFNODE.CONNECT" // for internal use only
   72		remoteLatencyEventSubj    = "$SYS.LATENCY.M2.%s"
   73		inboxRespSubj             = "$SYS._INBOX.%s.%s"
   74	
   75		// Used to return information to a user on bound account and user permissions.
   76		userDirectInfoSubj = "$SYS.REQ.USER.INFO"
   77		userDirectReqSubj  = "$SYS.REQ.USER.%s.INFO"
   78	
   79		// FIXME(dlc) - Should account scope, even with wc for now, but later on
   80		// we can then shard as needed.
   81		accNumSubsReqSubj = "$SYS.REQ.ACCOUNT.NSUBS"
   82	
   83		// These are for exported debug services. These are local to this server only.
   84		accSubsSubj = "$SYS.DEBUG.SUBSCRIBERS"
   85	
   86		shutdownEventTokens = 4
   87		serverSubjectIndex  = 2
   88		accUpdateTokensNew  = 6
   89		accUpdateTokensOld  = 5
   90		accUpdateAccIdxOld  = 2
   91	
   92		accReqTokens   = 5
   93		accReqAccIndex = 3
   94	
   95		ocspPeerRejectEventSubj           = "$SYS.SERVER.%s.OCSP.PEER.CONN.REJECT"
   96		ocspPeerChainlinkInvalidEventSubj = "$SYS.SERVER.%s.OCSP.PEER.LINK.INVALID"
   97	)
   98	
   99	// FIXME(dlc) - make configurable.
  100	var eventsHBInterval = 30 * time.Second
  101	var statsHBInterval = 10 * time.Second
  102	
  103	// Default minimum wait time for sending statsz
  104	const defaultStatszRateLimit = 1 * time.Second
  105	
  106	// Variable version so we can set in tests.
  107	var statszRateLimit = defaultStatszRateLimit
  108	
```

## events.go — `ServerStatsMsg`, `ConnectEventMsg`, `DisconnectEventMsg`, the OCSP events, `AccountNumConns` / `AccountStat`, `accNumConnsReq`, `ServerID`, `ServerInfo`

The bodies of the published events. Note that `AccountNumConns` is documented in the source as sent "when the number of connections changes" **and** as a heartbeat "in the absence of any changes".

```go
  150	type ServerStatsMsg struct {
  151		Server ServerInfo  `json:"server"`
  152		Stats  ServerStats `json:"statsz"`
  153	}
  154	
  155	// ConnectEventMsg is sent when a new connection is made that is part of an account.
  156	type ConnectEventMsg struct {
  157		TypedEvent
  158		Server ServerInfo `json:"server"`
  159		Client ClientInfo `json:"client"`
  160	}
  161	
  162	// ConnectEventMsgType is the schema type for ConnectEventMsg
  163	const ConnectEventMsgType = "io.nats.server.advisory.v1.client_connect"
  164	
  165	// DisconnectEventMsg is sent when a new connection previously defined from a
  166	// ConnectEventMsg is closed.
  167	type DisconnectEventMsg struct {
  168		TypedEvent
  169		Server   ServerInfo `json:"server"`
  170		Client   ClientInfo `json:"client"`
  171		Sent     DataStats  `json:"sent"`
  172		Received DataStats  `json:"received"`
  173		Reason   string     `json:"reason"`
  174	}
  175	
  176	// DisconnectEventMsgType is the schema type for DisconnectEventMsg
  177	const DisconnectEventMsgType = "io.nats.server.advisory.v1.client_disconnect"
  178	
  179	// OCSPPeerRejectEventMsg is sent when a peer TLS handshake is ultimately rejected due to OCSP invalidation.
  180	// A "peer" can be an inbound client connection or a leaf connection to a remote server. Peer in event payload
  181	// is always the peer's (TLS) leaf cert, which may or may be the invalid cert (See also OCSPPeerChainlinkInvalidEventMsg)
  182	type OCSPPeerRejectEventMsg struct {
  183		TypedEvent
  184		Kind   string           `json:"kind"`
  185		Peer   certidp.CertInfo `json:"peer"`
  186		Server ServerInfo       `json:"server"`
  187		Reason string           `json:"reason"`
  188	}
  189	
  190	// OCSPPeerRejectEventMsgType is the schema type for OCSPPeerRejectEventMsg
  191	const OCSPPeerRejectEventMsgType = "io.nats.server.advisory.v1.ocsp_peer_reject"
  192	
  193	// OCSPPeerChainlinkInvalidEventMsg is sent when a certificate (link) in a valid TLS chain is found to be OCSP invalid
  194	// during a peer TLS handshake. A "peer" can be an inbound client connection or a leaf connection to a remote server.
  195	// Peer and Link may be the same if the invalid cert was the peer's leaf cert
  196	type OCSPPeerChainlinkInvalidEventMsg struct {
  197		TypedEvent
  198		Link   certidp.CertInfo `json:"link"`
  199		Peer   certidp.CertInfo `json:"peer"`
  200		Server ServerInfo       `json:"server"`
  201		Reason string           `json:"reason"`
  202	}
  203	
  204	// OCSPPeerChainlinkInvalidEventMsgType is the schema type for OCSPPeerChainlinkInvalidEventMsg
  205	const OCSPPeerChainlinkInvalidEventMsgType = "io.nats.server.advisory.v1.ocsp_peer_link_invalid"
  206	
  207	// AccountNumConns is an event that will be sent from a server that is tracking
  208	// a given account when the number of connections changes. It will also HB
  209	// updates in the absence of any changes.
  210	type AccountNumConns struct {
  211		TypedEvent
  212		Server ServerInfo `json:"server"`
  213		AccountStat
  214	}
  215	
  216	// AccountStat contains the data common between AccountNumConns and AccountStatz
  217	type AccountStat struct {
  218		Account       string    `json:"acc"`
  219		Name          string    `json:"name"`
  220		Conns         int       `json:"conns"`
  221		LeafNodes     int       `json:"leafnodes"`
  222		TotalConns    int       `json:"total_conns"`
  223		NumSubs       uint32    `json:"num_subscriptions"`
  224		Sent          DataStats `json:"sent"`
  225		Received      DataStats `json:"received"`
  226		SlowConsumers int64     `json:"slow_consumers"`
  227	}
  228	
  229	const AccountNumConnsMsgType = "io.nats.server.advisory.v1.account_connections"
  230	
  231	// accNumConnsReq is sent when we are starting to track an account for the first
  232	// time. We will request others send info to us about their local state.
  233	type accNumConnsReq struct {
  234		Server  ServerInfo `json:"server"`
  235		Account string     `json:"acc"`
  236	}
  237	
  238	// ServerID is basic static info for a server.
  239	type ServerID struct {
  240		Name string `json:"name"`
  241		Host string `json:"host"`
  242		ID   string `json:"id"`
  243	}
  244	
  245	// Type for our server capabilities.
  246	type ServerCapability uint64
  247	
  248	// ServerInfo identifies remote servers.
  249	type ServerInfo struct {
  250		Name         string            `json:"name"`
  251		Host         string            `json:"host"`
  252		ID           string            `json:"id"`
  253		Cluster      string            `json:"cluster,omitempty"`
  254		Domain       string            `json:"domain,omitempty"`
  255		Version      string            `json:"ver"`
  256		Tags         []string          `json:"tags,omitempty"`
  257		Metadata     map[string]string `json:"metadata,omitempty"`
  258		FeatureFlags map[string]bool   `json:"feature_flags,omitempty"`
  259		// Whether JetStream is enabled (deprecated in favor of the `ServerCapability`).
  260		JetStream bool `json:"jetstream"`
  261		// Generic capability flags
  262		Flags ServerCapability `json:"flags"`
  263		// Sequence and Time from the remote server for this message.
  264		Seq  uint64    `json:"seq"`
  265		Time time.Time `json:"time"`
  266	}
```

## events.go — `ClientInfo` (the `client` object of connect, disconnect and auth-error events)

```go
  309	type ClientInfo struct {
  310		Start      *time.Time    `json:"start,omitempty"`
  311		Host       string        `json:"host,omitempty"`
  312		ID         uint64        `json:"id,omitempty"`
  313		Account    string        `json:"acc,omitempty"`
  314		Service    string        `json:"svc,omitempty"`
  315		User       string        `json:"user,omitempty"`
  316		Name       string        `json:"name,omitempty"`
  317		Lang       string        `json:"lang,omitempty"`
  318		Version    string        `json:"ver,omitempty"`
  319		RTT        time.Duration `json:"rtt,omitempty"`
  320		Server     string        `json:"server,omitempty"`
  321		Cluster    string        `json:"cluster,omitempty"`
  322		Alternates []string      `json:"alts,omitempty"`
  323		Stop       *time.Time    `json:"stop,omitempty"`
  324		Jwt        string        `json:"jwt,omitempty"`
  325		IssuerKey  string        `json:"issuer_key,omitempty"`
  326		NameTag    string        `json:"name_tag,omitempty"`
  327		Tags       jwt.TagList   `json:"tags,omitempty"`
  328		Kind       string        `json:"kind,omitempty"`
  329		ClientType string        `json:"client_type,omitempty"`
  330		MQTTClient string        `json:"client_id,omitempty"` // This is the MQTT client ID
  331		Nonce      string        `json:"nonce,omitempty"`
  332		Reply      string        `json:"reply,omitempty"` // Original reply subject after a service import (only when needed).
  333	}
```

## events.go — `ServerStats` (the `statsz` object), `RouteStat`, `GatewayStat`, `MsgBytes`, `DataStats`

```go
  367	type ServerStats struct {
  368		Start                time.Time             `json:"start"`
  369		Mem                  int64                 `json:"mem"`
  370		Cores                int                   `json:"cores"`
  371		CPU                  float64               `json:"cpu"`
  372		Connections          int                   `json:"connections"`
  373		TotalConnections     uint64                `json:"total_connections"`
  374		ActiveAccounts       int                   `json:"active_accounts"`
  375		NumSubs              uint32                `json:"subscriptions"`
  376		Sent                 DataStats             `json:"sent"`
  377		SentToClients        DataStats             `json:"sent_to_clients"`
  378		Received             DataStats             `json:"received"`
  379		ReceivedFromClients  DataStats             `json:"received_from_clients"`
  380		SlowConsumers        int64                 `json:"slow_consumers"`
  381		SlowConsumersStats   *SlowConsumersStats   `json:"slow_consumer_stats,omitempty"`
  382		StaleConnections     int64                 `json:"stale_connections,omitempty"`
  383		StaleConnectionStats *StaleConnectionStats `json:"stale_connection_stats,omitempty"`
  384		StalledClients       int64                 `json:"stalled_clients,omitempty"`
  385		Routes               []*RouteStat          `json:"routes,omitempty"`
  386		Gateways             []*GatewayStat        `json:"gateways,omitempty"`
  387		ActiveServers        int                   `json:"active_servers,omitempty"`
  388		JetStream            *JetStreamVarz        `json:"jetstream,omitempty"`
  389		MemLimit             int64                 `json:"gomemlimit,omitempty"`
  390		MaxProcs             int                   `json:"gomaxprocs,omitempty"`
  391	}
  392	
  393	// RouteStat holds route statistics.
  394	type RouteStat struct {
  395		ID       uint64    `json:"rid"`
  396		Name     string    `json:"name,omitempty"`
  397		Sent     DataStats `json:"sent"`
  398		Received DataStats `json:"received"`
  399		Pending  int       `json:"pending"`
  400	}
  401	
  402	// GatewayStat holds gateway statistics.
  403	type GatewayStat struct {
  404		ID         uint64    `json:"gwid"`
  405		Name       string    `json:"name"`
  406		Sent       DataStats `json:"sent"`
  407		Received   DataStats `json:"received"`
  408		NumInbound int       `json:"inbound_connections"`
  409	}
  410	
  411	type MsgBytes struct {
  412		Msgs  int64 `json:"msgs"`
  413		Bytes int64 `json:"bytes"`
  414	}
  415	
  416	// DataStats reports how may msg and bytes. Applicable for both sent and received.
  417	type DataStats struct {
  418		MsgBytes
  419		Gateways *MsgBytes `json:"gateways,omitempty"`
  420		Routes   *MsgBytes `json:"routes,omitempty"`
  421		Leafs    *MsgBytes `json:"leafs,omitempty"`
  422	}
  423	
  424	// Used for internally queueing up messages that the server wants to send.
```

## events.go — lame-duck and shutdown events

Both carry an empty `ServerInfo` body, filled in by the send queue with the server's own `ServerInfo`; `sendShutdownEvent` is the last message the send queue takes.

```go
  679	func (s *Server) sendLDMShutdownEventLocked() {
  680		if s.sys == nil || s.sys.sendq == nil {
  681			return
  682		}
  683		subj := fmt.Sprintf(lameDuckEventSubj, s.info.ID)
  684		si := &ServerInfo{}
  685		s.sys.sendq.push(newPubMsg(nil, subj, _EMPTY_, si, nil, si, noCompression, false, true))
  686	}
  687	
  688	// Will send a shutdown message.
  689	func (s *Server) sendShutdownEvent() {
  690		s.mu.Lock()
  691		if s.sys == nil || s.sys.sendq == nil {
  692			s.mu.Unlock()
  693			return
  694		}
  695		subj := fmt.Sprintf(shutdownEventSubj, s.info.ID)
  696		sendq := s.sys.sendq
  697		// Stop any more messages from queueing up.
  698		s.sys.sendq = nil
  699		// Unhook all msgHandlers. Normal client cleanup will deal with subs, etc.
  700		s.sys.replies = nil
  701		// Send to the internal queue and mark as last.
  702		si := &ServerInfo{}
  703		sendq.push(newPubMsg(nil, subj, _EMPTY_, si, nil, si, noCompression, false, true))
  704		s.mu.Unlock()
  705	}
  706	
  707	// Used to send an internal message to an arbitrary account.
```

## events.go — `sendStatsz` — the `STATSZ` body, and `statszReq` rate limiting

```go
  896	func (s *Server) sendStatsz(subj string) {
  897		var m ServerStatsMsg
  898		s.updateServerUsage(&m.Stats)
  899	
  900		if s.limitStatsz(subj) {
  901			return
  902		}
  903	
  904		s.mu.RLock()
  905		defer s.mu.RUnlock()
  906	
  907		// Check that we have a system account, etc.
  908		if s.sys == nil || s.sys.account == nil {
  909			return
  910		}
  911	
  912		shouldCheckInterest := func() bool {
  913			opts := s.getOpts()
  914			if opts.Cluster.Port != 0 || opts.Gateway.Port != 0 || opts.LeafNode.Port != 0 {
  915				return false
  916			}
  917			// If we are here we have no clustering or gateways and are not a leafnode hub.
  918			// Check for leafnode remotes that connect the system account.
  919			if len(opts.LeafNode.Remotes) > 0 {
  920				sysAcc := s.sys.account.GetName()
  921				for _, r := range opts.LeafNode.Remotes {
  922					if r.LocalAccount == sysAcc {
  923						return false
  924					}
  925				}
  926			}
  927			return true
  928		}
  929	
  930		// if we are running standalone, check for interest.
  931		if shouldCheckInterest() {
  932			// Check if we even have interest in this subject.
  933			sacc := s.sys.account
  934			rr := sacc.sl.Match(subj)
  935			totalSubs := len(rr.psubs) + len(rr.qsubs)
```

## events.go — the `STATSZ` heartbeat: rate limit, back-off from 250 ms to `statsHBInterval`

```go
 1085		s.mu.Lock()
 1086		defer s.mu.Unlock()
 1087	
 1088		if s.sys == nil {
 1089			return true
 1090		}
 1091	
 1092		// Only limit the normal broadcast subject.
 1093		if subj != fmt.Sprintf(serverStatsSubj, s.ID()) {
 1094			return false
 1095		}
 1096	
 1097		interval := statszRateLimit
 1098		if s.sys.cstatsz < interval {
 1099			interval = s.sys.cstatsz
 1100		}
 1101		if time.Since(s.sys.lastStatsz) < interval {
 1102			// Reschedule heartbeat for the next interval.
 1103			if s.sys.stmr != nil {
 1104				s.sys.stmr.Reset(time.Until(s.sys.lastStatsz.Add(interval)))
 1105			}
 1106			return true
 1107		}
 1108		s.sys.lastStatsz = time.Now()
 1109		return false
 1110	}
 1111	
 1112	// Send out our statz update.
 1113	// This should be wrapChk() to setup common locking.
 1114	func (s *Server) heartbeatStatsz() {
 1115		if s.sys.stmr != nil {
 1116			// Increase after startup to our max.
 1117			if s.sys.cstatsz < s.sys.statsz {
 1118				s.sys.cstatsz *= 2
 1119				if s.sys.cstatsz > s.sys.statsz {
 1120					s.sys.cstatsz = s.sys.statsz
 1121				}
 1122			}
 1123			s.sys.stmr.Reset(s.sys.cstatsz)
 1124		}
 1125		// Do in separate Go routine.
 1126		go s.sendStatszUpdate()
 1127	}
 1128	
 1129	// Reset statsz rate limit for the next broadcast.
 1130	// This should be wrapChk() to setup common locking.
 1131	func (s *Server) resetLastStatsz() {
 1132		s.sys.lastStatsz = time.Time{}
 1133	}
 1134	
 1135	func (s *Server) sendStatszUpdate() {
 1136		s.sendStatsz(fmt.Sprintf(serverStatsSubj, s.ID()))
 1137	}
 1138	
 1139	// This should be wrapChk() to setup common locking.
 1140	func (s *Server) startStatszTimer() {
 1141		// We will start by sending out more of these and trail off to the statsz being the max.
 1142		s.sys.cstatsz = 250 * time.Millisecond
 1143		// Send out the first one quickly, we will slowly back off.
 1144		s.sys.stmr = time.AfterFunc(s.sys.cstatsz, s.wrapChk(s.heartbeatStatsz))
 1145	}
 1146	
```

## events.go — `initEventTracking` — the subscriptions: `STATSZ` (old form), the `PING.<Z>` and `<id>.<Z>` table, `PROFILEZ`

The fifteen names in `monSrvc` are subscribed twice each (`$SYS.REQ.SERVER.<id>.<Z>` and `$SYS.REQ.SERVER.PING.<Z>`). There is no `STACKSZ` entry — `/stacksz` is HTTP-only — and `EXPVARZ` is the request form of `/debug/vars`.

```go
 1196		}
 1197		// Create a system hash which we use for other servers to target us specifically.
 1198		sys.shash = getHash(s.info.Name)
 1199	
 1200		// This will be for all inbox responses.
 1201		subject := fmt.Sprintf(inboxRespSubj, sys.shash, "*")
 1202		if _, err := s.sysSubscribe(subject, s.inboxReply); err != nil {
 1203			s.Errorf("Error setting up internal tracking: %v", err)
 1204			return
 1205		}
 1206		sys.inboxPre = subject
 1207		// This is for remote updates for connection accounting.
 1208		subject = fmt.Sprintf(accConnsEventSubjOld, "*")
 1209		if _, err := s.sysSubscribe(subject, s.noInlineCallback(s.remoteConnsUpdate)); err != nil {
 1210			s.Errorf("Error setting up internal tracking for %s: %v", subject, err)
 1211			return
 1212		}
 1213		// This will be for responses for account info that we send out.
 1214		subject = fmt.Sprintf(connsRespSubj, s.info.ID)
 1215		if _, err := s.sysSubscribe(subject, s.noInlineCallback(s.remoteConnsUpdate)); err != nil {
 1216			s.Errorf("Error setting up internal tracking: %v", err)
 1217			return
 1218		}
 1219		// Listen for broad requests to respond with number of subscriptions for a given subject.
 1220		if _, err := s.sysSubscribe(accNumSubsReqSubj, s.noInlineCallback(s.nsubsRequest)); err != nil {
 1221			s.Errorf("Error setting up internal tracking: %v", err)
 1222			return
 1223		}
 1224		// Listen for statsz from others.
 1225		subject = fmt.Sprintf(serverStatsSubj, "*")
 1226		if sub, err := s.sysSubscribe(subject, s.noInlineCallback(s.remoteServerUpdate)); err != nil {
 1227			s.Errorf("Error setting up internal tracking: %v", err)
 1228			return
 1229		} else {
 1230			// Keep track of this one.
 1231			sys.remoteStatsSub = sub
 1232		}
 1233	
 1234		// Listen for all server shutdowns.
 1235		subject = fmt.Sprintf(shutdownEventSubj, "*")
 1236		if _, err := s.sysSubscribe(subject, s.noInlineCallback(s.remoteServerShutdown)); err != nil {
 1237			s.Errorf("Error setting up internal tracking: %v", err)
 1238			return
 1239		}
 1240		// Listen for servers entering lame-duck mode.
 1241		// NOTE: This currently is handled in the same way as a server shutdown, but has
 1242		// a different subject in case we need to handle differently in future.
 1243		subject = fmt.Sprintf(lameDuckEventSubj, "*")
 1244		if _, err := s.sysSubscribe(subject, s.noInlineCallback(s.remoteServerShutdown)); err != nil {
 1245			s.Errorf("Error setting up internal tracking: %v", err)
 1246			return
 1247		}
 1248		// Listen for account claims updates.
 1249		subscribeToUpdate := true
 1250		if s.accResolver != nil {
 1251			subscribeToUpdate = !s.accResolver.IsTrackingUpdate()
 1252		}
 1253		if subscribeToUpdate {
 1254			for _, sub := range []string{accUpdateEventSubjOld, accUpdateEventSubjNew} {
 1255				if _, err := s.sysSubscribe(fmt.Sprintf(sub, "*"), s.noInlineCallback(s.accountClaimUpdate)); err != nil {
 1256					s.Errorf("Error setting up internal tracking: %v", err)
 1257					return
 1258				}
 1259			}
 1260		}
 1261		// Listen for ping messages that will be sent to all servers for statsz.
 1262		// This subscription is kept for backwards compatibility. Got replaced by ...PING.STATZ from below
 1263		if _, err := s.sysSubscribe(serverStatsPingReqSubj, s.noInlineCallbackStatsz(s.statszReq)); err != nil {
 1264			s.Errorf("Error setting up internal tracking: %v", err)
 1265			return
 1266		}
 1267		monSrvc := map[string]sysMsgHandler{
 1268			"IDZ":    s.idzReq,
 1269			"STATSZ": s.statszReq,
 1270			"VARZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1271				optz := &VarzEventOptions{}
 1272				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) { return s.Varz(&optz.VarzOptions) })
 1273			},
 1274			"SUBSZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1275				optz := &SubszEventOptions{}
 1276				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) { return s.Subsz(&optz.SubszOptions) })
 1277			},
 1278			"CONNZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1279				optz := &ConnzEventOptions{}
 1280				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) { return s.Connz(&optz.ConnzOptions) })
 1281			},
 1282			"ROUTEZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1283				optz := &RoutezEventOptions{}
 1284				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) { return s.Routez(&optz.RoutezOptions) })
 1285			},
 1286			"GATEWAYZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1287				optz := &GatewayzEventOptions{}
 1288				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) { return s.Gatewayz(&optz.GatewayzOptions) })
 1289			},
 1290			"LEAFZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1291				optz := &LeafzEventOptions{}
 1292				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) { return s.Leafz(&optz.LeafzOptions) })
 1293			},
 1294			"ACCOUNTZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1295				optz := &AccountzEventOptions{}
 1296				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) { return s.Accountz(&optz.AccountzOptions) })
 1297			},
 1298			"JSZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1299				optz := &JszEventOptions{}
 1300				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) { return s.Jsz(&optz.JSzOptions) })
 1301			},
 1302			"HEALTHZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1303				optz := &HealthzEventOptions{}
 1304				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) { return s.healthz(&optz.HealthzOptions), nil })
 1305			},
 1306			"PROFILEZ": nil, // Special case, see below
 1307			"EXPVARZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1308				optz := &ExpvarzEventOptions{}
 1309				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) { return s.expvarz(optz), nil })
 1310			},
 1311			"IPQUEUESZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1312				optz := &IpqueueszEventOptions{}
 1313				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) { return s.Ipqueuesz(&optz.IpqueueszOptions), nil })
 1314			},
 1315			"RAFTZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1316				optz := &RaftzEventOptions{}
 1317				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) { return s.Raftz(&optz.RaftzOptions), nil })
 1318			},
 1319		}
 1320		profilez := func(_ *subscription, c *client, _ *Account, _, rply string, rmsg []byte) {
 1321			hdr, msg := c.msgParts(rmsg)
 1322			// Need to copy since we are passing those to the go routine below.
 1323			hdr, msg = copyBytes(hdr), copyBytes(msg)
 1324			// Execute in its own go routine because CPU profiling, for instance,
 1325			// could take several seconds to complete.
 1326			go func() {
 1327				optz := &ProfilezEventOptions{}
 1328				s.zReq(c, rply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) {
 1329					return s.profilez(&optz.ProfilezOptions), nil
 1330				})
 1331			}()
 1332		}
 1333		for name, req := range monSrvc {
 1334			var h msgHandler
 1335			switch name {
 1336			case "PROFILEZ":
 1337				h = profilez
 1338			case "STATSZ":
 1339				h = s.noInlineCallbackStatsz(req)
 1340			default:
 1341				h = s.noInlineCallback(req)
```

## events.go — `initEventTracking` — the per-account table (`$SYS.REQ.ACCOUNT.<acc>.<Z>`), `USER.INFO`, `ACCOUNT.PING.STATZ`, the leafnode, latency, debug, reload, kick and LDM subscriptions

```go
 1341				h = s.noInlineCallback(req)
 1342			}
 1343			subject = fmt.Sprintf(serverDirectReqSubj, s.info.ID, name)
 1344			if _, err := s.sysSubscribe(subject, h); err != nil {
 1345				s.Errorf("Error setting up internal tracking: %v", err)
 1346				return
 1347			}
 1348			subject = fmt.Sprintf(serverPingReqSubj, name)
 1349			if _, err := s.sysSubscribe(subject, h); err != nil {
 1350				s.Errorf("Error setting up internal tracking: %v", err)
 1351				return
 1352			}
 1353		}
 1354		extractAccount := func(subject string) (string, error) {
 1355			if tk := strings.Split(subject, tsep); len(tk) != accReqTokens {
 1356				return _EMPTY_, fmt.Errorf("subject %q is malformed", subject)
 1357			} else {
 1358				return tk[accReqAccIndex], nil
 1359			}
 1360		}
 1361		monAccSrvc := map[string]sysMsgHandler{
 1362			"SUBSZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1363				optz := &SubszEventOptions{}
 1364				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) {
 1365					if acc, err := extractAccount(subject); err != nil {
 1366						return nil, err
 1367					} else {
 1368						optz.SubszOptions.Subscriptions = true
 1369						optz.SubszOptions.Account = acc
 1370						return s.Subsz(&optz.SubszOptions)
 1371					}
 1372				})
 1373			},
 1374			"CONNZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1375				optz := &ConnzEventOptions{}
 1376				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) {
 1377					if acc, err := extractAccount(subject); err != nil {
 1378						return nil, err
 1379					} else {
 1380						optz.ConnzOptions.Account = acc
 1381						return s.Connz(&optz.ConnzOptions)
 1382					}
 1383				})
 1384			},
 1385			"LEAFZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1386				optz := &LeafzEventOptions{}
 1387				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) {
 1388					if acc, err := extractAccount(subject); err != nil {
 1389						return nil, err
 1390					} else {
 1391						optz.LeafzOptions.Account = acc
 1392						return s.Leafz(&optz.LeafzOptions)
 1393					}
 1394				})
 1395			},
 1396			"JSZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1397				optz := &JszEventOptions{}
 1398				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) {
 1399					if acc, err := extractAccount(subject); err != nil {
 1400						return nil, err
 1401					} else {
 1402						optz.Account = acc
 1403						return s.JszAccount(&optz.JSzOptions)
 1404					}
 1405				})
 1406			},
 1407			"INFO": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1408				optz := &AccInfoEventOptions{}
 1409				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) {
 1410					if acc, err := extractAccount(subject); err != nil {
 1411						return nil, err
 1412					} else {
 1413						return s.accountInfo(acc)
 1414					}
 1415				})
 1416			},
 1417			// STATZ is essentially a duplicate of CONNS with an envelope identical to the others.
 1418			// For historical reasons CONNS is the odd one out.
 1419			// STATZ is also less heavy weight than INFO
 1420			"STATZ": func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1421				optz := &AccountStatzEventOptions{}
 1422				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) {
 1423					if acc, err := extractAccount(subject); err != nil {
 1424						return nil, err
 1425					} else if acc == "PING" { // Filter PING subject. Happens for server as well. But wildcards are not used
 1426						return nil, errSkipZreq
 1427					} else {
 1428						optz.Accounts = []string{acc}
 1429						if stz, err := s.AccountStatz(&optz.AccountStatzOptions); err != nil {
 1430							return nil, err
 1431						} else if len(stz.Accounts) == 0 && !optz.IncludeUnused {
 1432							return nil, errSkipZreq
 1433						} else {
 1434							return stz, nil
 1435						}
 1436					}
 1437				})
 1438			},
 1439			"CONNS": s.connsRequest,
 1440		}
 1441		for name, req := range monAccSrvc {
 1442			if _, err := s.sysSubscribe(fmt.Sprintf(accDirectReqSubj, "*", name), s.noInlineCallback(req)); err != nil {
 1443				s.Errorf("Error setting up internal tracking: %v", err)
 1444				return
 1445			}
 1446		}
 1447	
 1448		// User info. Do not propagate interest so that we know the local server to the connection
 1449		// is the only one that will answer the requests.
 1450		if _, err := s.sysSubscribeInternal(fmt.Sprintf(userDirectReqSubj, "*"), s.userInfoReq); err != nil {
 1451			s.Errorf("Error setting up internal tracking: %v", err)
 1452			return
 1453		}
 1454	
 1455		// For now only the STATZ subject has an account specific ping equivalent.
 1456		if _, err := s.sysSubscribe(fmt.Sprintf(accPingReqSubj, "STATZ"),
 1457			s.noInlineCallback(func(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1458				optz := &AccountStatzEventOptions{}
 1459				s.zReq(c, reply, hdr, msg, &optz.EventFilterOptions, optz, func() (any, error) {
 1460					if stz, err := s.AccountStatz(&optz.AccountStatzOptions); err != nil {
 1461						return nil, err
 1462					} else if len(stz.Accounts) == 0 && !optz.IncludeUnused {
 1463						return nil, errSkipZreq
 1464					} else {
 1465						return stz, nil
 1466					}
 1467				})
 1468			})); err != nil {
 1469			s.Errorf("Error setting up internal tracking: %v", err)
 1470			return
 1471		}
 1472	
 1473		// Listen for updates when leaf nodes connect for a given account. This will
 1474		// force any gateway connections to move to `modeInterestOnly`
 1475		subject = fmt.Sprintf(leafNodeConnectEventSubj, "*")
 1476		if _, err := s.sysSubscribe(subject, s.noInlineCallback(s.leafNodeConnected)); err != nil {
 1477			s.Errorf("Error setting up internal tracking: %v", err)
 1478			return
 1479		}
 1480		// For tracking remote latency measurements.
 1481		subject = fmt.Sprintf(remoteLatencyEventSubj, sys.shash)
 1482		if _, err := s.sysSubscribe(subject, s.noInlineCallback(s.remoteLatencyUpdate)); err != nil {
 1483			s.Errorf("Error setting up internal latency tracking: %v", err)
 1484			return
 1485		}
 1486		// This is for simple debugging of number of subscribers that exist in the system.
 1487		if _, err := s.sysSubscribeInternal(accSubsSubj, s.noInlineCallback(s.debugSubscribers)); err != nil {
 1488			s.Errorf("Error setting up internal debug service for subscribers: %v", err)
 1489			return
 1490		}
 1491	
 1492		// Listen for requests to reload the server configuration.
 1493		subject = fmt.Sprintf(serverReloadReqSubj, s.info.ID)
 1494		if _, err := s.sysSubscribe(subject, s.noInlineCallback(s.reloadConfig)); err != nil {
 1495			s.Errorf("Error setting up server reload handler: %v", err)
 1496			return
 1497		}
 1498	
 1499		// Client connection kick
 1500		subject = fmt.Sprintf(clientKickReqSubj, s.info.ID)
 1501		if _, err := s.sysSubscribe(subject, s.noInlineCallback(s.kickClient)); err != nil {
 1502			s.Errorf("Error setting up client kick service: %v", err)
 1503			return
 1504		}
 1505		// Client connection LDM
 1506		subject = fmt.Sprintf(clientLDMReqSubj, s.info.ID)
 1507		if _, err := s.sysSubscribe(subject, s.noInlineCallback(s.ldmClient)); err != nil {
 1508			s.Errorf("Error setting up client LDM service: %v", err)
```

## events.go — `UserInfo` — the body `$SYS.REQ.USER.INFO` answers with

```go
 1510		}
 1511	}
 1512	
 1513	// UserInfo returns basic information to a user about bound account and user permissions.
 1514	// For account information they will need to ping that separately, and this allows security
 1515	// controls on each subsystem if desired, e.g. account info, jetstream account info, etc.
 1516	type UserInfo struct {
 1517		UserID      string        `json:"user"`
 1518		Account     string        `json:"account"`
 1519		AccountName string        `json:"account_name,omitempty"`
 1520		UserName    string        `json:"user_name,omitempty"`
 1521		Permissions *Permissions  `json:"permissions,omitempty"`
 1522		Expires     time.Duration `json:"expires,omitempty"`
 1523	}
 1524	
 1525	// Process a user info request.
```

## events.go — `connsRequest` — `$SYS.REQ.ACCOUNT.<acc>.CONNS`, a server-to-server request

```go
 1917	
 1918	// Request for our local connection count.
 1919	func (s *Server) connsRequest(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 1920		if !s.eventsRunning() {
 1921			return
 1922		}
 1923		tk := strings.Split(subject, tsep)
 1924		if len(tk) != accReqTokens {
 1925			s.sys.client.Errorf("Bad subject account connections request message")
 1926			return
 1927		}
 1928		a := tk[accReqAccIndex]
 1929		m := accNumConnsReq{Account: a}
 1930		if len(msg) > 0 {
 1931			if err := json.Unmarshal(msg, &m); err != nil {
 1932				s.sys.client.Errorf("Error unmarshalling account connections request message: %v", err)
 1933				return
 1934			}
 1935		}
 1936		if m.Account != a {
 1937			s.sys.client.Errorf("Error unmarshalled account does not match subject")
 1938			return
 1939		}
 1940		// Here we really only want to lookup the account if its local. We do not want to fetch this
 1941		// account if we have no interest in it.
 1942		var acc *Account
 1943		if v, ok := s.accounts.Load(m.Account); ok {
 1944			acc = v.(*Account)
 1945		}
 1946		if acc == nil {
 1947			return
 1948		}
 1949		// We know this is a local connection.
 1950		if nlc := acc.NumLocalConnections(); nlc > 0 {
 1951			s.mu.Lock()
 1952			s.sendAccConnsUpdate(acc, reply)
 1953			s.mu.Unlock()
 1954		}
 1955	}
 1956	
 1957	// leafNodeConnected is an event we will receive when a leaf node for a given account connects.
```

## events.go — `EventFilterOptions` and the `<Z>EventOptions` request bodies

```go
 1977	
 1978	// Common filter options for system requests STATSZ VARZ SUBSZ CONNZ ROUTEZ GATEWAYZ LEAFZ
 1979	type EventFilterOptions struct {
 1980		Name       string   `json:"server_name,omitempty"` // filter by server name
 1981		Cluster    string   `json:"cluster,omitempty"`     // filter by cluster name
 1982		Host       string   `json:"host,omitempty"`        // filter by host name
 1983		ExactMatch bool     `json:"exact_match,omitempty"` // if the above filters should use exact matching or only "contains"
 1984		Tags       []string `json:"tags,omitempty"`        // filter by tags (must match all tags)
 1985		Domain     string   `json:"domain,omitempty"`      // filter by JS domain
 1986	}
 1987	
 1988	// StatszEventOptions are options passed to Statsz
 1989	type StatszEventOptions struct {
 1990		// No actual options yet
 1991		EventFilterOptions
 1992	}
 1993	
 1994	// Options for account Info
 1995	type AccInfoEventOptions struct {
 1996		// No actual options yet
 1997		EventFilterOptions
 1998	}
 1999	
 2000	// In the context of system events, ConnzEventOptions are options passed to Connz
 2001	type ConnzEventOptions struct {
 2002		ConnzOptions
 2003		EventFilterOptions
 2004	}
 2005	
 2006	// In the context of system events, RoutezEventOptions are options passed to Routez
 2007	type RoutezEventOptions struct {
 2008		RoutezOptions
 2009		EventFilterOptions
 2010	}
 2011	
 2012	// In the context of system events, SubzEventOptions are options passed to Subz
 2013	type SubszEventOptions struct {
 2014		SubszOptions
 2015		EventFilterOptions
 2016	}
 2017	
 2018	// In the context of system events, VarzEventOptions are options passed to Varz
 2019	type VarzEventOptions struct {
 2020		VarzOptions
 2021		EventFilterOptions
 2022	}
 2023	
 2024	// In the context of system events, GatewayzEventOptions are options passed to Gatewayz
 2025	type GatewayzEventOptions struct {
 2026		GatewayzOptions
 2027		EventFilterOptions
 2028	}
 2029	
 2030	// In the context of system events, LeafzEventOptions are options passed to Leafz
 2031	type LeafzEventOptions struct {
 2032		LeafzOptions
 2033		EventFilterOptions
 2034	}
 2035	
 2036	// In the context of system events, AccountzEventOptions are options passed to Accountz
 2037	type AccountzEventOptions struct {
 2038		AccountzOptions
 2039		EventFilterOptions
 2040	}
 2041	
 2042	// In the context of system events, AccountzEventOptions are options passed to Accountz
 2043	type AccountStatzEventOptions struct {
 2044		AccountStatzOptions
 2045		EventFilterOptions
 2046	}
 2047	
 2048	// In the context of system events, JszEventOptions are options passed to Jsz
 2049	type JszEventOptions struct {
 2050		JSzOptions
 2051		EventFilterOptions
 2052	}
 2053	
 2054	// In the context of system events, HealthzEventOptions are options passed to Healthz
 2055	type HealthzEventOptions struct {
 2056		HealthzOptions
 2057		EventFilterOptions
 2058	}
 2059	
 2060	// In the context of system events, ProfilezEventOptions are options passed to Profilez
 2061	type ProfilezEventOptions struct {
 2062		ProfilezOptions
 2063		EventFilterOptions
 2064	}
 2065	
 2066	// In the context of system events, ExpvarzEventOptions are options passed to Expvarz
 2067	type ExpvarzEventOptions struct {
 2068		EventFilterOptions
 2069	}
 2070	
 2071	// In the context of system events, IpqueueszEventOptions are options passed to Ipqueuesz
 2072	type IpqueueszEventOptions struct {
 2073		EventFilterOptions
 2074		IpqueueszOptions
 2075	}
 2076	
 2077	// In the context of system events, RaftzEventOptions are options passed to Raftz
 2078	type RaftzEventOptions struct {
 2079		EventFilterOptions
 2080		RaftzOptions
 2081	}
 2082	
 2083	// returns true if the request does NOT apply to this server and can be ignored.
```

## events.go — `ServerAPIResponse` — the `{server, data, error}` envelope

```go
 2123	
 2124	// ServerAPIResponse is the response type for the server API like varz, connz etc.
 2125	type ServerAPIResponse struct {
 2126		Server *ServerInfo `json:"server"`
 2127		Data   any         `json:"data,omitempty"`
 2128		Error  *ApiError   `json:"error,omitempty"`
 2129	
 2130		// Private to indicate compression if any.
 2131		compress compressionType
 2132	}
 2133	
 2134	// Specialized response types for unmarshalling. These structures are not
```

## events.go — `statszReq` and `idzReq` — why `STATSZ` answers with `statsz` and `IDZ` with a bare `ServerID`

```go
 2222	// statszReq is a request for us to respond with current statsz.
 2223	func (s *Server) statszReq(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 2224		if !s.EventsEnabled() {
 2225			return
 2226		}
 2227	
 2228		// No reply is a signal that we should use our normal broadcast subject.
 2229		if reply == _EMPTY_ {
 2230			reply = fmt.Sprintf(serverStatsSubj, s.info.ID)
 2231			s.wrapChk(s.resetLastStatsz)()
 2232		}
 2233	
 2234		opts := StatszEventOptions{}
 2235		if len(msg) != 0 {
 2236			if err := json.Unmarshal(msg, &opts); err != nil {
 2237				response := &ServerAPIResponse{
 2238					Server: &ServerInfo{},
 2239					Error:  &ApiError{Code: http.StatusBadRequest, Description: err.Error()},
 2240				}
 2241				s.sendInternalMsgLocked(reply, _EMPTY_, response.Server, response)
 2242				return
 2243			} else if ignore := s.filterRequest(&opts.EventFilterOptions); ignore {
 2244				return
 2245			}
 2246		}
 2247		s.sendStatsz(reply)
 2248	}
 2249	
 2250	// idzReq is for a request for basic static server info.
 2251	// Try to not hold the write lock or dynamically create data.
 2252	func (s *Server) idzReq(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 2253		s.mu.RLock()
 2254		defer s.mu.RUnlock()
 2255		id := &ServerID{
 2256			Name: s.info.Name,
 2257			Host: s.info.Host,
 2258			ID:   s.info.ID,
 2259		}
 2260		s.sendInternalMsg(reply, _EMPTY_, nil, &id)
 2261	}
 2262	
```

## events.go — the built-in imports every account gets: `$SYS.REQ.ACCOUNT.PING.CONNZ` and `.STATZ`

```go
 2370			return
 2371		}
 2372		dstAccName := sacc.Name
 2373		// FIXME(dlc) - make a shared list between sys exports etc.
 2374	
 2375		importSrvc := func(subj, mappedSubj string) {
 2376			if !a.serviceImportExists(dstAccName, subj) {
 2377				if err := a.addServiceImportWithClaim(sacc, subj, mappedSubj, nil, true); err != nil {
 2378					s.Errorf("Error setting up system service import %s -> %s for account: %v",
 2379						subj, mappedSubj, err)
 2380				}
 2381			}
 2382		}
 2383		// Add in this to the account in 2 places.
 2384		// "$SYS.REQ.SERVER.PING.CONNZ" and "$SYS.REQ.ACCOUNT.PING.CONNZ"
 2385		mappedConnzSubj := fmt.Sprintf(accDirectReqSubj, a.Name, "CONNZ")
 2386		importSrvc(fmt.Sprintf(accPingReqSubj, "CONNZ"), mappedConnzSubj)
 2387		importSrvc(fmt.Sprintf(serverPingReqSubj, "CONNZ"), mappedConnzSubj)
 2388		importSrvc(fmt.Sprintf(accPingReqSubj, "STATZ"), fmt.Sprintf(accDirectReqSubj, a.Name, "STATZ"))
 2389	
 2390		// This is for user's looking up their own info.
 2391		mappedSubject := fmt.Sprintf(userDirectReqSubj, a.Name)
 2392		importSrvc(userDirectInfoSubj, mappedSubject)
 2393		// Make sure to share details.
 2394		a.setServiceImportSharing(sacc, mappedSubject, false, true)
 2395	}
```

## events.go — `sendLeafNodeConnect` (a no-op without gateways), `sendAccConnsUpdate` (the 30 s heartbeat timer), `accConnsUpdate` (both `CONNS` subjects, never for `$G`)

```go
 2414	// Event on leaf node connect.
 2415	// Lock should NOT be held on entry.
 2416	func (s *Server) sendLeafNodeConnect(a *Account) {
 2417		s.mu.Lock()
 2418		// If we are not in operator mode, or do not have any gateways defined, this should also be a no-op.
 2419		if a == nil || !s.eventsEnabled() || !s.gateway.enabled {
 2420			s.mu.Unlock()
 2421			return
 2422		}
 2423		s.sendLeafNodeConnectMsg(a.Name)
 2424		s.mu.Unlock()
 2425	
 2426		s.switchAccountToInterestMode(a.Name)
 2427	}
 2428	
 2429	// Send the leafnode connect message.
 2430	// Lock should be held.
 2431	func (s *Server) sendLeafNodeConnectMsg(accName string) {
 2432		subj := fmt.Sprintf(leafNodeConnectEventSubj, accName)
 2433		m := accNumConnsReq{Account: accName}
 2434		s.sendInternalMsg(subj, _EMPTY_, &m.Server, &m)
 2435	}
 2436	
 2437	// sendAccConnsUpdate is called to send out our information on the
 2438	// account's local connections.
 2439	// Lock should be held on entry.
 2440	func (s *Server) sendAccConnsUpdate(a *Account, subj ...string) {
 2441		if !s.eventsEnabled() || a == nil {
 2442			return
 2443		}
 2444		sendQ := s.sys.sendq
 2445		if sendQ == nil {
 2446			return
 2447		}
 2448		// Build event with account name and number of local clients and leafnodes.
 2449		eid := s.nextEventID()
 2450		a.mu.Lock()
 2451		stat := a.statz()
 2452		m := AccountNumConns{
 2453			TypedEvent: TypedEvent{
 2454				Type: AccountNumConnsMsgType,
 2455				ID:   eid,
 2456				Time: time.Now().UTC(),
 2457			},
 2458			AccountStat: *stat,
 2459		}
 2460		// Set timer to fire again unless we are at zero.
 2461		if m.TotalConns == 0 {
 2462			clearTimer(&a.ctmr)
 2463		} else {
 2464			// Check to see if we have an HB running and update.
 2465			if a.ctmr == nil {
 2466				a.ctmr = time.AfterFunc(eventsHBInterval, func() { s.accConnsUpdate(a) })
 2467			} else {
 2468				a.ctmr.Reset(eventsHBInterval)
 2469			}
 2470		}
 2471		for _, sub := range subj {
 2472			msg := newPubMsg(nil, sub, _EMPTY_, &m.Server, nil, &m, noCompression, false, false)
 2473			sendQ.push(msg)
 2474		}
 2475		a.mu.Unlock()
 2476	}
 2477	
 2478	// Lock should be held on entry.
 2479	func (a *Account) statz() *AccountStat {
 2480		localConns := a.numLocalConnections()
 2481		leafConns := a.numLocalLeafNodes()
 2482	
 2483		a.stats.Lock()
 2484		received := DataStats{
 2485			MsgBytes: MsgBytes{
 2486				Msgs:  a.stats.inMsgs,
 2487				Bytes: a.stats.inBytes,
 2488			},
 2489			Gateways: &MsgBytes{
 2490				Msgs:  a.stats.gw.inMsgs,
 2491				Bytes: a.stats.gw.inBytes,
 2492			},
 2493			Routes: &MsgBytes{
 2494				Msgs:  a.stats.rt.inMsgs,
 2495				Bytes: a.stats.rt.inBytes,
 2496			},
 2497			Leafs: &MsgBytes{
 2498				Msgs:  a.stats.ln.inMsgs,
 2499				Bytes: a.stats.ln.inBytes,
 2500			},
 2501		}
 2502		sent := DataStats{
 2503			MsgBytes: MsgBytes{
 2504				Msgs:  a.stats.outMsgs,
 2505				Bytes: a.stats.outBytes,
 2506			},
 2507			Gateways: &MsgBytes{
 2508				Msgs:  a.stats.gw.outMsgs,
 2509				Bytes: a.stats.gw.outBytes,
 2510			},
 2511			Routes: &MsgBytes{
 2512				Msgs:  a.stats.rt.outMsgs,
 2513				Bytes: a.stats.rt.outBytes,
 2514			},
 2515			Leafs: &MsgBytes{
 2516				Msgs:  a.stats.ln.outMsgs,
 2517				Bytes: a.stats.ln.outBytes,
 2518			},
 2519		}
 2520		slowConsumers := a.stats.slowConsumers
 2521		a.stats.Unlock()
 2522	
 2523		return &AccountStat{
 2524			Account:       a.Name,
 2525			Name:          a.getNameTagLocked(),
 2526			Conns:         localConns,
 2527			LeafNodes:     leafConns,
 2528			TotalConns:    localConns + leafConns,
 2529			NumSubs:       a.sl.Count(),
 2530			Received:      received,
 2531			Sent:          sent,
 2532			SlowConsumers: slowConsumers,
 2533		}
 2534	}
 2535	
 2536	// accConnsUpdate is called whenever there is a change to the account's
 2537	// number of active connections, or during a heartbeat.
 2538	// We will not send for $G.
 2539	func (s *Server) accConnsUpdate(a *Account) {
 2540		s.mu.Lock()
 2541		defer s.mu.Unlock()
 2542		if !s.eventsEnabled() || a == nil || a == s.gacc {
 2543			return
 2544		}
 2545		s.sendAccConnsUpdate(a, fmt.Sprintf(accConnsEventSubjOld, a.Name), fmt.Sprintf(accConnsEventSubjNew, a.Name))
 2546	}
 2547	
 2548	// server lock should be held
```

## events.go — `accountConnectEvent` and `accountDisconnectEvent` — the `CONNECT` / `DISCONNECT` subjects

```go
 2551	}
 2552	
 2553	// accountConnectEvent will send an account client connect event if there is interest.
 2554	// This is a billing event.
 2555	func (s *Server) accountConnectEvent(c *client) {
 2556		s.mu.Lock()
 2557		if !s.eventsEnabled() {
 2558			s.mu.Unlock()
 2559			return
 2560		}
 2561		eid := s.nextEventID()
 2562		s.mu.Unlock()
 2563	
 2564		c.mu.Lock()
 2565		if c.acc == nil {
 2566			c.mu.Unlock()
 2567			return
 2568		}
 2569	
 2570		m := ConnectEventMsg{
 2571			TypedEvent: TypedEvent{
 2572				Type: ConnectEventMsgType,
 2573				ID:   eid,
 2574				Time: time.Now().UTC(),
 2575			},
 2576			Client: ClientInfo{
 2577				Start:      &c.start,
 2578				Host:       c.host,
 2579				ID:         c.cid,
 2580				Account:    accForClient(c),
 2581				User:       c.getRawAuthUser(),
 2582				Name:       c.opts.Name,
 2583				Lang:       c.opts.Lang,
 2584				Version:    c.opts.Version,
 2585				Jwt:        c.opts.JWT,
 2586				IssuerKey:  issuerForClient(c),
 2587				Tags:       c.tags,
 2588				NameTag:    c.acc.getNameTag(),
 2589				Kind:       c.kindString(),
 2590				ClientType: c.clientTypeString(),
 2591				MQTTClient: c.getMQTTClientID(),
 2592			},
 2593		}
 2594		subj := fmt.Sprintf(connectEventSubj, c.acc.Name)
 2595		c.mu.Unlock()
 2596	
 2597		s.sendInternalMsgLocked(subj, _EMPTY_, &m.Server, &m)
 2598	}
 2599	
 2600	// accountDisconnectEvent will send an account client disconnect event if there is interest.
 2601	// This is a billing event.
 2602	func (s *Server) accountDisconnectEvent(c *client, now time.Time, reason string) {
 2603		s.mu.Lock()
 2604		if !s.eventsEnabled() {
 2605			s.mu.Unlock()
 2606			return
 2607		}
 2608		eid := s.nextEventID()
 2609		s.mu.Unlock()
 2610	
 2611		c.mu.Lock()
 2612	
 2613		if c.acc == nil {
 2614			c.mu.Unlock()
 2615			return
 2616		}
 2617		m := DisconnectEventMsg{
 2618			TypedEvent: TypedEvent{
 2619				Type: DisconnectEventMsgType,
 2620				ID:   eid,
 2621				Time: now,
 2622			},
 2623			Client: ClientInfo{
 2624				Start:      &c.start,
 2625				Stop:       &now,
 2626				Host:       c.host,
 2627				ID:         c.cid,
 2628				Account:    accForClient(c),
 2629				User:       c.getRawAuthUser(),
 2630				Name:       c.opts.Name,
 2631				Lang:       c.opts.Lang,
 2632				Version:    c.opts.Version,
 2633				RTT:        c.getRTT(),
 2634				Jwt:        c.opts.JWT,
 2635				IssuerKey:  issuerForClient(c),
 2636				Tags:       c.tags,
 2637				NameTag:    c.acc.getNameTag(),
 2638				Kind:       c.kindString(),
 2639				ClientType: c.clientTypeString(),
 2640				MQTTClient: c.getMQTTClientID(),
 2641			},
 2642			Sent: DataStats{
 2643				MsgBytes: MsgBytes{
 2644					Msgs:  atomic.LoadInt64(&c.inMsgs),
 2645					Bytes: atomic.LoadInt64(&c.inBytes),
 2646				},
 2647			},
 2648			Received: DataStats{
 2649				MsgBytes: MsgBytes{
 2650					Msgs:  c.outMsgs,
 2651					Bytes: c.outBytes,
 2652				},
 2653			},
 2654			Reason: reason,
 2655		}
 2656		accName := c.acc.Name
 2657		c.mu.Unlock()
 2658	
 2659		subj := fmt.Sprintf(disconnectEventSubj, accName)
 2660		s.sendInternalMsgLocked(subj, _EMPTY_, &m.Server, &m)
 2661	}
 2662	
```

## events.go — `sendAuthErrorEvent` and `sendAccountAuthErrorEvent` — a `client_disconnect` body on `$SYS.SERVER.<id>.CLIENT.AUTH.ERR` and `$SYS.ACCOUNT.CLIENT.AUTH.ERR`

```go
 2664	func (s *Server) sendAuthErrorEvent(c *client, reason string) {
 2665		s.mu.Lock()
 2666		if !s.eventsEnabled() {
 2667			s.mu.Unlock()
 2668			return
 2669		}
 2670		eid := s.nextEventID()
 2671		s.mu.Unlock()
 2672	
 2673		now := time.Now().UTC()
 2674		c.mu.Lock()
 2675		m := DisconnectEventMsg{
 2676			TypedEvent: TypedEvent{
 2677				Type: DisconnectEventMsgType,
 2678				ID:   eid,
 2679				Time: now,
 2680			},
 2681			Client: ClientInfo{
 2682				Start:      &c.start,
 2683				Stop:       &now,
 2684				Host:       c.host,
 2685				ID:         c.cid,
 2686				Account:    accForClient(c),
 2687				User:       c.getRawAuthUser(),
 2688				Name:       c.opts.Name,
 2689				Lang:       c.opts.Lang,
 2690				Version:    c.opts.Version,
 2691				RTT:        c.getRTT(),
 2692				Jwt:        c.opts.JWT,
 2693				IssuerKey:  issuerForClient(c),
 2694				Tags:       c.tags,
 2695				NameTag:    c.acc.getNameTag(),
 2696				Kind:       c.kindString(),
 2697				ClientType: c.clientTypeString(),
 2698				MQTTClient: c.getMQTTClientID(),
 2699			},
 2700			Sent: DataStats{
 2701				MsgBytes: MsgBytes{
 2702					Msgs:  c.inMsgs,
 2703					Bytes: c.inBytes,
 2704				},
 2705			},
 2706			Received: DataStats{
 2707				MsgBytes: MsgBytes{
 2708					Msgs:  c.outMsgs,
 2709					Bytes: c.outBytes,
 2710				},
 2711			},
 2712			Reason: reason,
 2713		}
 2714		c.mu.Unlock()
 2715	
 2716		s.mu.Lock()
 2717		subj := fmt.Sprintf(authErrorEventSubj, s.info.ID)
 2718		s.sendInternalMsg(subj, _EMPTY_, &m.Server, &m)
 2719		s.mu.Unlock()
 2720	}
 2721	
 2722	// This is the account level event sent to the origin account for account owners.
 2723	func (s *Server) sendAccountAuthErrorEvent(c *client, acc *Account, reason string) {
 2724		if acc == nil {
 2725			return
 2726		}
 2727		s.mu.Lock()
 2728		if !s.eventsEnabled() {
 2729			s.mu.Unlock()
 2730			return
 2731		}
 2732		eid := s.nextEventID()
 2733		s.mu.Unlock()
 2734	
 2735		now := time.Now().UTC()
 2736		c.mu.Lock()
 2737		m := DisconnectEventMsg{
 2738			TypedEvent: TypedEvent{
 2739				Type: DisconnectEventMsgType,
 2740				ID:   eid,
 2741				Time: now,
 2742			},
 2743			Client: ClientInfo{
 2744				Start:      &c.start,
 2745				Stop:       &now,
 2746				Host:       c.host,
 2747				ID:         c.cid,
 2748				Account:    acc.Name,
 2749				User:       c.getRawAuthUser(),
 2750				Name:       c.opts.Name,
 2751				Lang:       c.opts.Lang,
 2752				Version:    c.opts.Version,
 2753				RTT:        c.getRTT(),
 2754				Jwt:        c.opts.JWT,
 2755				IssuerKey:  issuerForClient(c),
 2756				Tags:       c.tags,
 2757				NameTag:    c.acc.getNameTag(),
 2758				Kind:       c.kindString(),
 2759				ClientType: c.clientTypeString(),
 2760				MQTTClient: c.getMQTTClientID(),
 2761			},
 2762			Sent: DataStats{
 2763				MsgBytes: MsgBytes{
 2764					Msgs:  c.inMsgs,
 2765					Bytes: c.inBytes,
 2766				},
 2767			},
 2768			Received: DataStats{
 2769				MsgBytes: MsgBytes{
 2770					Msgs:  c.outMsgs,
 2771					Bytes: c.outBytes,
 2772				},
 2773			},
 2774			Reason: reason,
 2775		}
 2776		c.mu.Unlock()
 2777	
 2778		s.sendInternalAccountSysMsg(acc, authErrorAccountEventSubj, &m.Server, &m, noCompression)
 2779	}
 2780	
```

## events.go — `accNumSubsReq` — the `$SYS.REQ.ACCOUNT.NSUBS` body

```go
 2999	type accNumSubsReq struct {
 3000		Account string `json:"acc"`
 3001		Subject string `json:"subject"`
 3002		Queue   []byte `json:"queue,omitempty"`
 3003	}
 3004	
```

## events.go — `reloadConfig` — `$SYS.REQ.SERVER.<id>.RELOAD`

```go
 3199	}
 3200	
 3201	func (s *Server) reloadConfig(sub *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
 3202		if !s.eventsRunning() {
 3203			return
 3204		}
 3205	
 3206		optz := &EventFilterOptions{}
 3207		s.zReq(c, reply, hdr, msg, optz, optz, func() (any, error) {
 3208			// Reload the server config, as requested.
 3209			return nil, s.Reload()
 3210		})
 3211	}
 3212	
```

## events.go — `KickClientReq`, `LDMClientReq`

```go
 3213	type KickClientReq struct {
 3214		CID uint64 `json:"cid"`
 3215	}
 3216	
 3217	type LDMClientReq struct {
 3218		CID uint64 `json:"cid"`
 3219	}
 3220	
```

## server.go — the HTTP monitoring paths and the mux — the only fifteen the server serves over HTTP

```go
 3028	// HTTP endpoints
 3029	const (
 3030		RootPath         = "/"
 3031		VarzPath         = "/varz"
 3032		ConnzPath        = "/connz"
 3033		RoutezPath       = "/routez"
 3034		GatewayzPath     = "/gatewayz"
 3035		LeafzPath        = "/leafz"
 3036		SubszPath        = "/subsz"
 3037		StackszPath      = "/stacksz"
 3038		AccountzPath     = "/accountz"
 3039		AccountStatzPath = "/accstatz"
 3040		JszPath          = "/jsz"
 3041		HealthzPath      = "/healthz"
 3042		IPQueuesPath     = "/ipqueuesz"
 3043		RaftzPath        = "/raftz"
 3044		ExpvarzPath      = "/debug/vars"
 3045	)
```

## server.go — `startMonitoring` — every `HandleFunc` the HTTP server registers

```go
 3130	
 3131		mux := http.NewServeMux()
 3132	
 3133		// Root
 3134		mux.HandleFunc(s.basePath(RootPath), s.HandleRoot)
 3135		// Varz
 3136		mux.HandleFunc(s.basePath(VarzPath), s.HandleVarz)
 3137		// Connz
 3138		mux.HandleFunc(s.basePath(ConnzPath), s.HandleConnz)
 3139		// Routez
 3140		mux.HandleFunc(s.basePath(RoutezPath), s.HandleRoutez)
 3141		// Gatewayz
 3142		mux.HandleFunc(s.basePath(GatewayzPath), s.HandleGatewayz)
 3143		// Leafz
 3144		mux.HandleFunc(s.basePath(LeafzPath), s.HandleLeafz)
 3145		// Subz
 3146		mux.HandleFunc(s.basePath(SubszPath), s.HandleSubsz)
 3147		// Subz alias for backwards compatibility
 3148		mux.HandleFunc(s.basePath("/subscriptionsz"), s.HandleSubsz)
 3149		// Stacksz
 3150		mux.HandleFunc(s.basePath(StackszPath), s.HandleStacksz)
 3151		// Accountz
 3152		mux.HandleFunc(s.basePath(AccountzPath), s.HandleAccountz)
 3153		// Accstatz
 3154		mux.HandleFunc(s.basePath(AccountStatzPath), s.HandleAccountStatz)
 3155		// Jsz
 3156		mux.HandleFunc(s.basePath(JszPath), s.HandleJsz)
 3157		// Healthz
 3158		mux.HandleFunc(s.basePath(HealthzPath), s.HandleHealthz)
 3159		// IPQueuesz
 3160		mux.HandleFunc(s.basePath(IPQueuesPath), s.HandleIPQueuesz)
 3161		// Raftz
 3162		mux.HandleFunc(s.basePath(RaftzPath), s.HandleRaftz)
 3163		// Expvarz
 3164		mux.Handle(s.basePath(ExpvarzPath), expvar.Handler())
 3165	
```

## accounts.go — `ServiceLatency` — the service-latency metric body, and `sendLatencyResult` — published on the export's own `latency { subject }`, in the exporting account

```go
 1424	// ServiceLatency is the JSON message sent out in response to latency tracking for
 1425	// an accounts exported services. Additional client info is available in requestor
 1426	// and responder. Note that for a requestor, the only information shared by default
 1427	// is the RTT used to calculate the total latency. The requestor's account can
 1428	// designate to share the additional information in the service import.
 1429	type ServiceLatency struct {
 1430		TypedEvent
 1431		Status         int           `json:"status"`
 1432		Error          string        `json:"description,omitempty"`
 1433		Requestor      *ClientInfo   `json:"requestor,omitempty"`
 1434		Responder      *ClientInfo   `json:"responder,omitempty"`
 1435		RequestHeader  http.Header   `json:"header,omitempty"` // only contains header(s) triggering the measurement
 1436		RequestStart   time.Time     `json:"start"`
 1437		ServiceLatency time.Duration `json:"service"`
 1438		SystemLatency  time.Duration `json:"system"`
 1439		TotalLatency   time.Duration `json:"total"`
 1440	}
 1441	
 1442	// ServiceLatencyType is the NATS Event Type for ServiceLatency
 1443	const ServiceLatencyType = "io.nats.server.metric.v1.service_latency"
 1444	
 1445	// NATSTotalTime is a helper function that totals the NATS latencies.
 1446	func (m1 *ServiceLatency) NATSTotalTime() time.Duration {
 1447		return m1.Requestor.RTT + m1.Responder.RTT + m1.SystemLatency
 1448	}
 1449	
 1450	// Merge function to merge m1 and m2 (requestor and responder) measurements
 1451	// when there are two samples. This happens when the requestor and responder
 1452	// are on different servers.
 1453	//
 1454	// m2 ServiceLatency is correct, so use that.
 1455	// m1 TotalLatency is correct, so use that.
 1456	// Will use those to back into NATS latency.
 1457	func (m1 *ServiceLatency) merge(m2 *ServiceLatency) {
 1458		rtt := time.Duration(0)
 1459		if m2.Responder != nil {
 1460			rtt = m2.Responder.RTT
 1461		}
 1462		m1.SystemLatency = m1.ServiceLatency - (m2.ServiceLatency + rtt)
 1463		m1.ServiceLatency = m2.ServiceLatency
 1464		m1.Responder = m2.Responder
 1465		sanitizeLatencyMetric(m1)
 1466	}
 1467	
 1468	// sanitizeLatencyMetric adjusts latency metric values that could go
 1469	// negative in some edge conditions since we estimate client RTT
 1470	// for both requestor and responder.
 1471	// These numbers are never meant to be negative, it just could be
 1472	// how we back into the values based on estimated RTT.
 1473	func sanitizeLatencyMetric(sl *ServiceLatency) {
 1474		if sl.ServiceLatency < 0 {
 1475			sl.ServiceLatency = 0
 1476		}
 1477		if sl.SystemLatency < 0 {
 1478			sl.SystemLatency = 0
 1479		}
 1480	}
 1481	
 1482	// Used for transporting remote latency measurements.
 1483	type remoteLatency struct {
 1484		Account    string         `json:"account"`
 1485		ReqId      string         `json:"req_id"`
 1486		M2         ServiceLatency `json:"m2"`
 1487		respThresh time.Duration
 1488	}
 1489	
 1490	// sendLatencyResult will send a latency result and clear the si of the requestor(rc).
 1491	func (a *Account) sendLatencyResult(si *serviceImport, sl *ServiceLatency) {
 1492		sl.Type = ServiceLatencyType
 1493		sl.ID = a.nextEventID()
 1494		sl.Time = time.Now().UTC()
 1495		a.mu.Lock()
 1496		lsubj := si.latency.subject
 1497		si.rc = nil
 1498		a.mu.Unlock()
 1499	
 1500		a.srv.sendInternalAccountMsg(a, lsubj, sl)
 1501	}
 1502	
```

## jetstream_events.go — whole file (the advisory and metric types, their schema-type strings and their JSON bodies)

Quoted whole: this is the authority the 24 generated pages under `raw/nats-docs/reference/jetstream/advisory/` and `/metric/` were swept against on 2026-09-03 (the subjects themselves are constants in `jetstream.go` and `consumer.go`, quoted in `monitoring-observed-v2.14.6.md` §3).

```go
    1	// Copyright 2020-2025 The NATS Authors
    2	// Licensed under the Apache License, Version 2.0 (the "License");
    3	// you may not use this file except in compliance with the License.
    4	// You may obtain a copy of the License at
    5	//
    6	// http://www.apache.org/licenses/LICENSE-2.0
    7	//
    8	// Unless required by applicable law or agreed to in writing, software
    9	// distributed under the License is distributed on an "AS IS" BASIS,
   10	// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   11	// See the License for the specific language governing permissions and
   12	// limitations under the License.
   13	
   14	package server
   15	
   16	import (
   17		"encoding/json"
   18		"time"
   19	)
   20	
   21	// publishAdvisory sends the given advisory into the account. Returns true if
   22	// it was sent, false if not (i.e. due to lack of interest or a marshal error).
   23	func (s *Server) publishAdvisory(acc *Account, subject string, adv any) bool {
   24		if acc == nil {
   25			acc = s.SystemAccount()
   26			if acc == nil {
   27				return false
   28			}
   29		}
   30	
   31		// If there is no one listening for this advisory then save ourselves the effort
   32		// and don't bother encoding the JSON or sending it.
   33		if sl := acc.sl; (sl != nil && !sl.HasInterest(subject)) && !s.hasGatewayInterest(acc.Name, subject) {
   34			return false
   35		}
   36	
   37		ej, err := json.Marshal(adv)
   38		if err == nil {
   39			err = s.sendInternalAccountMsg(acc, subject, ej)
   40			if err != nil {
   41				s.Warnf("Advisory could not be sent for account %q: %v", acc.Name, err)
   42			}
   43		} else {
   44			s.Warnf("Advisory could not be serialized for account %q: %v", acc.Name, err)
   45		}
   46		return err == nil
   47	}
   48	
   49	// JSAPIAudit is an advisory about administrative actions taken on JetStream
   50	type JSAPIAudit struct {
   51		TypedEvent
   52		Server   string      `json:"server"`
   53		Client   *ClientInfo `json:"client"`
   54		Subject  string      `json:"subject"`
   55		Request  string      `json:"request,omitempty"`
   56		Response string      `json:"response"`
   57		Domain   string      `json:"domain,omitempty"`
   58	}
   59	
   60	const JSAPIAuditType = "io.nats.jetstream.advisory.v1.api_audit"
   61	
   62	// ActionAdvisoryType indicates which action against a stream, consumer or template triggered an advisory
   63	type ActionAdvisoryType string
   64	
   65	const (
   66		CreateEvent ActionAdvisoryType = "create"
   67		DeleteEvent ActionAdvisoryType = "delete"
   68		ModifyEvent ActionAdvisoryType = "modify"
   69	)
   70	
   71	// JSStreamActionAdvisory indicates that a stream was created, edited or deleted
   72	type JSStreamActionAdvisory struct {
   73		TypedEvent
   74		Stream string             `json:"stream"`
   75		Action ActionAdvisoryType `json:"action"`
   76		Domain string             `json:"domain,omitempty"`
   77	}
   78	
   79	const JSStreamActionAdvisoryType = "io.nats.jetstream.advisory.v1.stream_action"
   80	
   81	// JSConsumerActionAdvisory indicates that a consumer was created or deleted
   82	type JSConsumerActionAdvisory struct {
   83		TypedEvent
   84		Stream   string             `json:"stream"`
   85		Consumer string             `json:"consumer"`
   86		Action   ActionAdvisoryType `json:"action"`
   87		Domain   string             `json:"domain,omitempty"`
   88	}
   89	
   90	const JSConsumerActionAdvisoryType = "io.nats.jetstream.advisory.v1.consumer_action"
   91	
   92	// JSConsumerPauseAdvisory indicates that a consumer was paused or unpaused
   93	type JSConsumerPauseAdvisory struct {
   94		TypedEvent
   95		Stream     string    `json:"stream"`
   96		Consumer   string    `json:"consumer"`
   97		Paused     bool      `json:"paused"`
   98		PauseUntil time.Time `json:"pause_until,omitempty"`
   99		Domain     string    `json:"domain,omitempty"`
  100	}
  101	
  102	const JSConsumerPauseAdvisoryType = "io.nats.jetstream.advisory.v1.consumer_pause"
  103	
  104	// JSConsumerAckMetric is a metric published when a user acknowledges a message, the
  105	// number of these that will be published is dependent on SampleFrequency
  106	type JSConsumerAckMetric struct {
  107		TypedEvent
  108		Stream      string `json:"stream"`
  109		Consumer    string `json:"consumer"`
  110		ConsumerSeq uint64 `json:"consumer_seq"`
  111		StreamSeq   uint64 `json:"stream_seq"`
  112		Delay       int64  `json:"ack_time"`
  113		Deliveries  uint64 `json:"deliveries"`
  114		Domain      string `json:"domain,omitempty"`
  115	}
  116	
  117	// JSConsumerAckMetricType is the schema type for JSConsumerAckMetricType
  118	const JSConsumerAckMetricType = "io.nats.jetstream.metric.v1.consumer_ack"
  119	
  120	// JSConsumerDeliveryExceededAdvisory is an advisory informing that a message hit
  121	// its MaxDeliver threshold and so might be a candidate for DLQ handling
  122	type JSConsumerDeliveryExceededAdvisory struct {
  123		TypedEvent
  124		Stream     string `json:"stream"`
  125		Consumer   string `json:"consumer"`
  126		StreamSeq  uint64 `json:"stream_seq"`
  127		Deliveries uint64 `json:"deliveries"`
  128		Domain     string `json:"domain,omitempty"`
  129	}
  130	
  131	// JSConsumerDeliveryExceededAdvisoryType is the schema type for JSConsumerDeliveryExceededAdvisory
  132	const JSConsumerDeliveryExceededAdvisoryType = "io.nats.jetstream.advisory.v1.max_deliver"
  133	
  134	// JSConsumerDeliveryNakAdvisory is an advisory informing that a message was
  135	// naked by the consumer
  136	type JSConsumerDeliveryNakAdvisory struct {
  137		TypedEvent
  138		Stream      string `json:"stream"`
  139		Consumer    string `json:"consumer"`
  140		ConsumerSeq uint64 `json:"consumer_seq"`
  141		StreamSeq   uint64 `json:"stream_seq"`
  142		Deliveries  uint64 `json:"deliveries"`
  143		Domain      string `json:"domain,omitempty"`
  144	}
  145	
  146	// JSConsumerDeliveryNakAdvisoryType is the schema type for JSConsumerDeliveryNakAdvisory
  147	const JSConsumerDeliveryNakAdvisoryType = "io.nats.jetstream.advisory.v1.nak"
  148	
  149	// JSConsumerDeliveryTerminatedAdvisory is an advisory informing that a message was
  150	// terminated by the consumer, so might be a candidate for DLQ handling
  151	type JSConsumerDeliveryTerminatedAdvisory struct {
  152		TypedEvent
  153		Stream      string `json:"stream"`
  154		Consumer    string `json:"consumer"`
  155		ConsumerSeq uint64 `json:"consumer_seq"`
  156		StreamSeq   uint64 `json:"stream_seq"`
  157		Deliveries  uint64 `json:"deliveries"`
  158		Reason      string `json:"reason,omitempty"`
  159		Domain      string `json:"domain,omitempty"`
  160	}
  161	
  162	// JSConsumerDeliveryTerminatedAdvisoryType is the schema type for JSConsumerDeliveryTerminatedAdvisory
  163	const JSConsumerDeliveryTerminatedAdvisoryType = "io.nats.jetstream.advisory.v1.terminated"
  164	
  165	// JSSnapshotCreateAdvisory is an advisory sent after a snapshot is successfully started
  166	type JSSnapshotCreateAdvisory struct {
  167		TypedEvent
  168		Stream string      `json:"stream"`
  169		State  StreamState `json:"state"`
  170		Client *ClientInfo `json:"client"`
  171		Domain string      `json:"domain,omitempty"`
  172	}
  173	
  174	// JSSnapshotCreatedAdvisoryType is the schema type for JSSnapshotCreateAdvisory
  175	const JSSnapshotCreatedAdvisoryType = "io.nats.jetstream.advisory.v1.snapshot_create"
  176	
  177	// JSSnapshotCompleteAdvisory is an advisory sent after a snapshot is successfully started
  178	type JSSnapshotCompleteAdvisory struct {
  179		TypedEvent
  180		Stream string      `json:"stream"`
  181		Start  time.Time   `json:"start"`
  182		End    time.Time   `json:"end"`
  183		Client *ClientInfo `json:"client"`
  184		Domain string      `json:"domain,omitempty"`
  185	}
  186	
  187	// JSSnapshotCompleteAdvisoryType is the schema type for JSSnapshotCreateAdvisory
  188	const JSSnapshotCompleteAdvisoryType = "io.nats.jetstream.advisory.v1.snapshot_complete"
  189	
  190	// JSRestoreCreateAdvisory is an advisory sent after a snapshot is successfully started
  191	type JSRestoreCreateAdvisory struct {
  192		TypedEvent
  193		Stream string      `json:"stream"`
  194		Client *ClientInfo `json:"client"`
  195		Domain string      `json:"domain,omitempty"`
  196	}
  197	
  198	// JSRestoreCreateAdvisoryType is the schema type for JSSnapshotCreateAdvisory
  199	const JSRestoreCreateAdvisoryType = "io.nats.jetstream.advisory.v1.restore_create"
  200	
  201	// JSRestoreCompleteAdvisory is an advisory sent after a snapshot is successfully started
  202	type JSRestoreCompleteAdvisory struct {
  203		TypedEvent
  204		Stream string      `json:"stream"`
  205		Start  time.Time   `json:"start"`
  206		End    time.Time   `json:"end"`
  207		Bytes  int64       `json:"bytes"`
  208		Client *ClientInfo `json:"client"`
  209		Domain string      `json:"domain,omitempty"`
  210	}
  211	
  212	// JSRestoreCompleteAdvisoryType is the schema type for JSSnapshotCreateAdvisory
  213	const JSRestoreCompleteAdvisoryType = "io.nats.jetstream.advisory.v1.restore_complete"
  214	
  215	// Clustering specific.
  216	
  217	// JSClusterLeaderElectedAdvisoryType is sent when the system elects a new meta leader.
  218	const JSDomainLeaderElectedAdvisoryType = "io.nats.jetstream.advisory.v1.domain_leader_elected"
  219	
  220	// JSClusterLeaderElectedAdvisory indicates that a domain has elected a new leader.
  221	type JSDomainLeaderElectedAdvisory struct {
  222		TypedEvent
  223		Leader   string      `json:"leader"`
  224		Replicas []*PeerInfo `json:"replicas"`
  225		Cluster  string      `json:"cluster"`
  226		Domain   string      `json:"domain,omitempty"`
  227	}
  228	
  229	// JSStreamLeaderElectedAdvisoryType is sent when the system elects a new leader for a stream.
  230	const JSStreamLeaderElectedAdvisoryType = "io.nats.jetstream.advisory.v1.stream_leader_elected"
  231	
  232	// JSStreamLeaderElectedAdvisory indicates that a stream has elected a new leader.
  233	type JSStreamLeaderElectedAdvisory struct {
  234		TypedEvent
  235		Account  string      `json:"account,omitempty"`
  236		Stream   string      `json:"stream"`
  237		Leader   string      `json:"leader"`
  238		Replicas []*PeerInfo `json:"replicas"`
  239		Domain   string      `json:"domain,omitempty"`
  240	}
  241	
  242	// JSStreamQuorumLostAdvisoryType is sent when the system detects a clustered stream and
  243	// its consumers are stalled and unable to make progress.
  244	const JSStreamQuorumLostAdvisoryType = "io.nats.jetstream.advisory.v1.stream_quorum_lost"
  245	
  246	// JSStreamQuorumLostAdvisory indicates that a stream has lost quorum and is stalled.
  247	type JSStreamQuorumLostAdvisory struct {
  248		TypedEvent
  249		Account  string      `json:"account,omitempty"`
  250		Stream   string      `json:"stream"`
  251		Replicas []*PeerInfo `json:"replicas"`
  252		Domain   string      `json:"domain,omitempty"`
  253	}
  254	
  255	// JSStreamBatchAbandonedAdvisoryType is sent when a stream's atomic batch is abandoned.
  256	const JSStreamBatchAbandonedAdvisoryType = "io.nats.jetstream.advisory.v1.stream_batch_abandoned"
  257	
  258	// JSStreamBatchAbandonedAdvisory indicates that a stream's batch was abandoned.
  259	type JSStreamBatchAbandonedAdvisory struct {
  260		TypedEvent
  261		Account string             `json:"account,omitempty"`
  262		Stream  string             `json:"stream"`
  263		Domain  string             `json:"domain,omitempty"`
  264		BatchId string             `json:"batch"`
  265		Reason  BatchAbandonReason `json:"reason"`
  266	}
  267	
  268	type BatchAbandonReason string
  269	
  270	var (
  271		BatchTimeout            BatchAbandonReason = "timeout"
  272		BatchLarge              BatchAbandonReason = "large"
  273		BatchIncomplete         BatchAbandonReason = "incomplete"
  274		BatchRequirementsNotMet BatchAbandonReason = "unsupported"
  275	)
  276	
  277	// JSConsumerLeaderElectedAdvisoryType is sent when the system elects a leader for a consumer.
  278	const JSConsumerLeaderElectedAdvisoryType = "io.nats.jetstream.advisory.v1.consumer_leader_elected"
  279	
  280	// JSConsumerLeaderElectedAdvisory indicates that a consumer has elected a new leader.
  281	type JSConsumerLeaderElectedAdvisory struct {
  282		TypedEvent
  283		Account  string      `json:"account,omitempty"`
  284		Stream   string      `json:"stream"`
  285		Consumer string      `json:"consumer"`
  286		Leader   string      `json:"leader"`
  287		Replicas []*PeerInfo `json:"replicas"`
  288		Domain   string      `json:"domain,omitempty"`
  289	}
  290	
  291	// JSConsumerQuorumLostAdvisoryType is sent when the system detects a clustered consumer and
  292	// is stalled and unable to make progress.
  293	const JSConsumerQuorumLostAdvisoryType = "io.nats.jetstream.advisory.v1.consumer_quorum_lost"
  294	
  295	// JSConsumerQuorumLostAdvisory indicates that a consumer has lost quorum and is stalled.
  296	type JSConsumerQuorumLostAdvisory struct {
  297		TypedEvent
  298		Account  string      `json:"account,omitempty"`
  299		Stream   string      `json:"stream"`
  300		Consumer string      `json:"consumer"`
  301		Replicas []*PeerInfo `json:"replicas"`
  302		Domain   string      `json:"domain,omitempty"`
  303	}
  304	
  305	const JSConsumerGroupPinnedAdvisoryType = "io.nats.jetstream.advisory.v1.consumer_group_pinned"
  306	
  307	// JSConsumerGroupPinnedAdvisory that a group switched to a new pinned client
  308	type JSConsumerGroupPinnedAdvisory struct {
  309		TypedEvent
  310		Account        string `json:"account,omitempty"`
  311		Stream         string `json:"stream"`
  312		Consumer       string `json:"consumer"`
  313		Domain         string `json:"domain,omitempty"`
  314		Group          string `json:"group"`
  315		PinnedClientId string `json:"pinned_id"`
  316	}
  317	
  318	const JSConsumerGroupUnpinnedAdvisoryType = "io.nats.jetstream.advisory.v1.consumer_group_unpinned"
  319	
  320	// JSConsumerGroupUnpinnedAdvisory indicates that a pin was lost
  321	type JSConsumerGroupUnpinnedAdvisory struct {
  322		TypedEvent
  323		Account  string `json:"account,omitempty"`
  324		Stream   string `json:"stream"`
  325		Consumer string `json:"consumer"`
  326		Domain   string `json:"domain,omitempty"`
  327		Group    string `json:"group"`
  328		// one of "admin" or "timeout", could be an enum up to the implementor to decide
  329		Reason string `json:"reason"`
  330	}
  331	
  332	// JSServerOutOfStorageAdvisoryType is sent when the server is out of storage space.
  333	const JSServerOutOfStorageAdvisoryType = "io.nats.jetstream.advisory.v1.server_out_of_space"
  334	
  335	// JSServerOutOfSpaceAdvisory indicates that a stream has lost quorum and is stalled.
  336	type JSServerOutOfSpaceAdvisory struct {
  337		TypedEvent
  338		Server   string `json:"server"`
  339		ServerID string `json:"server_id"`
  340		Stream   string `json:"stream,omitempty"`
  341		Cluster  string `json:"cluster"`
  342		Domain   string `json:"domain,omitempty"`
  343	}
  344	
  345	// JSServerRemovedAdvisoryType is sent when the server has been removed and JS disabled.
  346	const JSServerRemovedAdvisoryType = "io.nats.jetstream.advisory.v1.server_removed"
  347	
  348	// JSServerRemovedAdvisory indicates that a stream has lost quorum and is stalled.
  349	type JSServerRemovedAdvisory struct {
  350		TypedEvent
  351		Server   string `json:"server"`
  352		ServerID string `json:"server_id"`
  353		Cluster  string `json:"cluster"`
  354		Domain   string `json:"domain,omitempty"`
  355	}
  356	
  357	// JSAPILimitReachedAdvisoryType is sent when the JS API request queue limit is reached.
  358	const JSAPILimitReachedAdvisoryType = "io.nats.jetstream.advisory.v1.api_limit_reached"
  359	
  360	// JSAPILimitReachedAdvisory is a advisory published when JetStream hits the queue length limit.
  361	type JSAPILimitReachedAdvisory struct {
  362		TypedEvent
  363		Server  string `json:"server"`           // Server that created the event, name or ID
  364		Domain  string `json:"domain,omitempty"` // Domain the server belongs to
  365		Dropped int64  `json:"dropped"`          // How many messages did we drop from the queue
  366	}
  367	
```
