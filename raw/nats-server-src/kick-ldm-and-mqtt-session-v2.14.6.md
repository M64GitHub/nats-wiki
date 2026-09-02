<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6 · files server/mqtt.go, server/events.go, server/server.go, server/jetstream_cluster.go · fetched 2026-09-01 -->
# nats-server v2.14.6 — kicking a client, lame-ducking a client, and the MQTT session record

Only the ranges this wiki quotes are stored, verbatim, with their real line numbers, so each value
links to `https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`. Apache-2.0.

Read for `inbox/plan-the-meta-layer-2026-09-01.md` step 2 — question-bank **Q37**
(`raw/gh-discussions/gh-7533.md`: an MQTT deployment losing quorum after days of stable operation,
whose first symptom is `unable to persist session … wrong last sequence: 0 (10071)`) and **Q40**
(`raw/gh-discussions/gh-6892.md`: evicting a sick-but-not-dead server and its clients). Both threads
are unanswered upstream; these ranges are what the server says. The kick and LDM requests were then
**run** against a live client on the three-node cluster of `jetstream-cluster-observed-v2.14.6.md`;
that transcript is `kick-ldm-observed-v2.14.6.md` in this directory.

## server/mqtt.go — how a session record is persisted, and what `wrong last sequence` means

### `server/mqtt.go` lines 3357–3399 — `mqttSession.save` — the session record is published with `Nats-Expected-Last-Subject-Sequence: <seq>`; a mismatch is `unable to persist session … wrong last sequence`

```go
  3357	func (sess *mqttSession) save() error {
  3358		sess.mu.Lock()
  3359		ps := mqttPersistedSession{
  3360			Origin: sess.jsa.id,
  3361			ID:     sess.id,
  3362			Clean:  sess.clean,
  3363			Subs:   sess.subs,
  3364			Cons:   sess.cons,
  3365			PubRel: sess.pubRelConsumer,
  3366		}
  3367		b, _ := json.Marshal(&ps)
  3368	
  3369		domainTk, cidHash := sess.domainTk, sess.idHash
  3370		seq := sess.seq
  3371		sess.mu.Unlock()
  3372	
  3373		var hdr int
  3374		if seq != 0 {
  3375			bb := bytes.Buffer{}
  3376			bb.WriteString(hdrLine)
  3377			bb.WriteString(JSExpectedLastSubjSeq)
  3378			bb.WriteString(":")
  3379			bb.WriteString(strconv.FormatInt(int64(seq), 10))
  3380			bb.WriteString(CR_LF)
  3381			bb.WriteString(CR_LF)
  3382			hdr = bb.Len()
  3383			bb.Write(b)
  3384			b = bb.Bytes()
  3385		}
  3386	
  3387		resp, err := sess.jsa.storeSessionMsg(domainTk, cidHash, hdr, b)
  3388		if err != nil {
  3389			return fmt.Errorf("unable to persist session %q (seq=%v): %v", ps.ID, seq, err)
  3390		}
  3391		// Guard before dereferencing below.
  3392		if resp == nil || resp.PubAck == nil {
  3393			return fmt.Errorf("unable to persist session %q (seq=%v): invalid pub ack response", ps.ID, seq)
  3394		}
  3395		sess.mu.Lock()
  3396		sess.seq = resp.Sequence
  3397		sess.mu.Unlock()
  3398		return nil
  3399	}
```

### `server/mqtt.go` lines 3100–3125 — `createOrRestoreSession` — `loading session record: …` wraps any error other than *no message found*

```go
  3100	// Creates the session stream (limit msgs of 1) for this client ID if it does
  3101	// not already exist. If it exists, recover the single record to rebuild the
  3102	// state of the session. If there is a session record but this session is not
  3103	// registered in the runtime of this server, then a request is made to the
  3104	// owner to close the client associated with this session since specification
  3105	// [MQTT-3.1.4-2] specifies that if the ClientId represents a Client already
  3106	// connected to the Server then the Server MUST disconnect the existing client.
  3107	//
  3108	// Runs from the client's readLoop.
  3109	// Lock not held on entry, but session is in the locked map.
  3110	func (as *mqttAccountSessionManager) createOrRestoreSession(clientID string, opts *Options) (*mqttSession, bool, error) {
  3111		jsa := &as.jsa
  3112	
  3113		hash := getHash(clientID)
  3114		smsg, err := jsa.loadSessionMsg(as.domainTk, hash)
  3115		if err != nil {
  3116			if isErrorOtherThan(err, JSNoMessageFoundErr) {
  3117				return nil, false, fmt.Errorf("loading session record: %w", err)
  3118			}
  3119			// Message not found, so reate the session...
  3120			// Create a session and indicate that this session did not exist.
  3121			sess := mqttSessionCreate(jsa, clientID, hash, 0, opts)
  3122			sess.domainTk = as.domainTk
  3123			return sess, false, nil
  3124		}
  3125		// We need to recover the existing record now.
```

## server/events.go and server/server.go — the two per-client system requests

### `server/events.go` lines 60–70 — the `$SYS.REQ.SERVER.<server-id>.KICK` and `.LDM` subjects

```go
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
```

### `server/events.go` lines 1499–1510 — each server subscribes for its own id only

```go
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
  1509			return
  1510		}
```

### `server/events.go` lines 3213–3253 — `kickClient` / `ldmClient` — both take `{"cid": <n>}`

```go
  3213	type KickClientReq struct {
  3214		CID uint64 `json:"cid"`
  3215	}
  3216	
  3217	type LDMClientReq struct {
  3218		CID uint64 `json:"cid"`
  3219	}
  3220	
  3221	func (s *Server) kickClient(_ *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
  3222		if !s.eventsRunning() {
  3223			return
  3224		}
  3225	
  3226		var req KickClientReq
  3227		if err := json.Unmarshal(msg, &req); err != nil {
  3228			s.sys.client.Errorf("Error unmarshalling kick client request: %v", err)
  3229			return
  3230		}
  3231	
  3232		optz := &EventFilterOptions{}
  3233		s.zReq(c, reply, hdr, msg, optz, optz, func() (any, error) {
  3234			return nil, s.DisconnectClientByID(req.CID)
  3235		})
  3236	
  3237	}
  3238	
  3239	func (s *Server) ldmClient(_ *subscription, c *client, _ *Account, subject, reply string, hdr, msg []byte) {
  3240		if !s.eventsRunning() {
  3241			return
  3242		}
  3243	
  3244		var req LDMClientReq
  3245		if err := json.Unmarshal(msg, &req); err != nil {
  3246			s.sys.client.Errorf("Error unmarshalling kick client request: %v", err)
  3247			return
  3248		}
  3249	
  3250		optz := &EventFilterOptions{}
  3251		s.zReq(c, reply, hdr, msg, optz, optz, func() (any, error) {
  3252			return nil, s.LDMClientByID(req.CID)
  3253		})
```

### `server/server.go` lines 4753–4765 — `DisconnectClientByID`

```go
  4753	func (s *Server) DisconnectClientByID(id uint64) error {
  4754		if s == nil {
  4755			return ErrServerNotRunning
  4756		}
  4757		if client := s.getClient(id); client != nil {
  4758			client.closeConnection(Kicked)
  4759			return nil
  4760		} else if client = s.GetLeafNode(id); client != nil {
  4761			client.closeConnection(Kicked)
  4762			return nil
  4763		}
  4764		return errors.New("no such client or leafnode id")
  4765	}
```

### `server/server.go` lines 4768–4792 — `LDMClientByID` — sends the client an INFO with `ldm: true`; nothing more

```go
  4768	func (s *Server) LDMClientByID(id uint64) error {
  4769		if s == nil {
  4770			return ErrServerNotRunning
  4771		}
  4772		s.mu.RLock()
  4773		c := s.clients[id]
  4774		if c == nil {
  4775			s.mu.RUnlock()
  4776			return errors.New("no such client id")
  4777		}
  4778		info := s.copyInfo()
  4779		info.LameDuckMode = true
  4780		s.mu.RUnlock()
  4781		c.mu.Lock()
  4782		defer c.mu.Unlock()
  4783		if c.opts.Protocol >= ClientProtoInfo && c.flags.isSet(firstPongSent) {
  4784			// sendInfo takes care of checking if the connection is still
  4785			// valid or not, so don't duplicate tests here.
  4786			c.Debugf("Sending Lame Duck Mode info to client")
  4787			c.enqueueProto(c.generateClientInfoJSON(info, true))
  4788			return nil
  4789		} else {
  4790			return errors.New("client does not support Lame Duck Mode or is not ready to receive the notification")
  4791		}
  4792	}
```

## server/jetstream_cluster.go — the stream-leader log lines

### `server/jetstream_cluster.go` lines 4735–4742 — `processStreamLeaderChange` — `JetStream cluster new stream leader for '<account> > <stream>'` and the leader-elected advisory

```go
  4735	
  4736		streamName := mset.name()
  4737	
  4738		if isLeader {
  4739			s.Noticef("JetStream cluster new stream leader for '%s > %s'", account, streamName)
  4740			s.sendStreamLeaderElectAdvisory(mset)
  4741		} else {
  4742			// We are stepping down.
```

### `server/jetstream_cluster.go` lines 3868–3880 — a scale-down or move: `Transfer of stream leader for '<account> > <stream>' to '<server>'`

```go
  3868			for _, r := range ci.Replicas {
  3869				if r.Current && newPeerSet[r.Peer] {
  3870					current++
  3871					if newLeader == _EMPTY_ {
  3872						newLeaderPeer, newLeader = r.Peer, r.Name
  3873					}
  3874				}
  3875			}
  3876			// Check if we have a quorom.
  3877			if current >= neededCurrent {
  3878				s.Noticef("Transfer of stream leader for '%s > %s' to '%s'", accName, streamName, newLeader)
  3879				n.ProposeKnownPeers(newPeers)
  3880				n.StepDown(newLeaderPeer)
```

