<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6, server/server.go and server/raft.go fetched from raw.githubusercontent.com · fetched 2026-08-31 -->
# nats-server v2.14.6 — lame-duck mode, as implemented

`Server.lameDuckMode()` in full, plus the two things it calls and the startup validation of its two
config keys. Read while ingesting `learn/deployment/rolling-upgrades.md`, which advises sizing
`lame_duck_duration` to cover JetStream's leadership move — an ordering the code does not support.
Line numbers are real at v2.14.6:
`https://github.com/nats-io/nats-server/blob/v2.14.6/server/server.go#L4439`.

## server/server.go — `validateOptions`, the grace-period rule

```go
  1151	func validateOptions(o *Options) error {
  1152		if o.LameDuckDuration > 0 && o.LameDuckGracePeriod >= o.LameDuckDuration {
  1153			return fmt.Errorf("lame duck grace period (%v) should be strictly lower than lame duck duration (%v)",
  1154				o.LameDuckGracePeriod, o.LameDuckDuration)
  1155		}
  1156		if int64(o.MaxPayload) > o.MaxPending {
```

## server/server.go — `lameDuckMode`, the drain

```go
  4439	func (s *Server) lameDuckMode() {
  4440		s.mu.Lock()
  4441		// Check if there is actually anything to do
  4442		if s.isShuttingDown() || s.ldm || s.listener == nil {
  4443			s.mu.Unlock()
  4444			return
  4445		}
  4446		s.Noticef("Entering lame duck mode, stop accepting new clients")
  4447		s.ldm = true
  4448		s.sendLDMShutdownEventLocked()
  4449		expected := 1
  4450		s.listener.Close()
  4451		s.listener = nil
  4452		expected += s.closeWebsocketServer()
  4453		s.ldmCh = make(chan bool, expected)
  4454		opts := s.getOpts()
  4455		gp := opts.LameDuckGracePeriod
  4456		// For tests, we want the grace period to be in some cases bigger
  4457		// than the ldm duration, so to by-pass the validateOptions() check,
  4458		// we use negative number and flip it here.
  4459		if gp < 0 {
  4460			gp *= -1
  4461		}
  4462		s.mu.Unlock()
  4463	
  4464		// If we are running any raftNodes transfer leaders.
  4465		if hadTransfers := s.transferRaftLeaders(); hadTransfers {
  4466			// They will transfer leadership quickly, but wait here for a second.
  4467			select {
  4468			case <-time.After(time.Second):
  4469			case <-s.quitCh:
  4470				return
  4471			}
  4472		}
  4473	
  4474		// Now check and shutdown jetstream.
  4475		s.shutdownJetStream()
  4476	
  4477		// Now shutdown the nodes
  4478		s.shutdownRaftNodes()
  4479	
  4480		// Wait for accept loops to be done to make sure that no new
  4481		// client can connect
  4482		for i := 0; i < expected; i++ {
  4483			<-s.ldmCh
  4484		}
  4485	
  4486		s.mu.Lock()
  4487		// Need to recheck few things
  4488		if s.isShuttingDown() || len(s.clients) == 0 {
  4489			s.mu.Unlock()
  4490			// If there is no client, we need to call Shutdown() to complete
  4491			// the LDMode. If server has been shutdown while lock was released,
  4492			// calling Shutdown() should be no-op.
  4493			s.Shutdown()
  4494			return
  4495		}
  4496		dur := int64(opts.LameDuckDuration)
  4497		dur -= int64(gp)
  4498		if dur <= 0 {
  4499			dur = int64(time.Second)
  4500		}
  4501		numClients := int64(len(s.clients))
  4502		batch := 1
  4503		// Sleep interval between each client connection close.
  4504		var si int64
  4505		if numClients != 0 {
  4506			si = dur / numClients
  4507		}
  4508		if si < 1 {
  4509			// Should not happen (except in test with very small LD duration), but
  4510			// if there are too many clients, batch the number of close and
  4511			// use a tiny sleep interval that will result in yield likely.
  4512			si = 1
  4513			batch = int(numClients / dur)
  4514		} else if si > int64(time.Second) {
  4515			// Conversely, there is no need to sleep too long between clients
  4516			// and spread say 10 clients for the 2min duration. Sleeping no
  4517			// more than 1sec.
  4518			si = int64(time.Second)
  4519		}
  4520	
  4521		// Now capture all clients
  4522		clients := make([]*client, 0, len(s.clients))
  4523		for _, client := range s.clients {
  4524			clients = append(clients, client)
  4525		}
  4526		// Now that we know that no new client can be accepted,
  4527		// send INFO to routes and clients to notify this state.
  4528		s.sendLDMToRoutes()
  4529		s.sendLDMToClients()
  4530		s.mu.Unlock()
```

## server/server.go — the grace timer and the staggered close

```go
  4531	
  4532		t := time.NewTimer(gp)
  4533		// Delay start of closing of client connections in case
  4534		// we have several servers that we want to signal to enter LD mode
  4535		// and not have their client reconnect to each other.
  4536		select {
  4537		case <-t.C:
  4538			s.Noticef("Closing existing clients")
  4539		case <-s.quitCh:
  4540			t.Stop()
  4541			return
  4542		}
  4543		for i, client := range clients {
  4544			client.closeConnection(ServerShutdown)
  4545			if i == len(clients)-1 {
  4546				break
  4547			}
  4548			if batch == 1 || i%batch == 0 {
  4549				// We pick a random interval which will be at least si/2
  4550				v := rand.Int63n(si)
  4551				if v < si/2 {
  4552					v = si / 2
  4553				}
  4554				t.Reset(time.Duration(v))
  4555				// Sleep for given interval or bail out if kicked by Shutdown().
  4556				select {
  4557				case <-t.C:
  4558				case <-s.quitCh:
  4559					t.Stop()
  4560					return
  4561				}
  4562			}
  4563		}
  4564		s.Shutdown()
  4565		s.WaitForShutdown()
```

## server/raft.go — `transferRaftLeaders`

```go
   883	func (s *Server) transferRaftLeaders() bool {
   884		if s == nil {
   885			return false
   886		}
   887		s.rnMu.RLock()
   888		if len(s.raftNodes) == 0 {
   889			s.rnMu.RUnlock()
   890			return false
   891		}
   892		nodes := make([]RaftNode, 0, len(s.raftNodes))
   893		for _, n := range s.raftNodes {
   894			nodes = append(nodes, n)
   895		}
   896		s.rnMu.RUnlock()
   897	
   898		var didTransfer bool
   899		for _, node := range nodes {
   900			if err := node.StepDown(); err == nil {
   901				didTransfer = true
   902			}
   903			node.SetObserver(true)
   904		}
   905		return didTransfer
   906	}
```
