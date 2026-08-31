<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6 · files server/stream.go, server/jetstream_cluster.go, server/consumer.go, server/filestore.go, server/raft.go, server/jetstream_api.go · fetched 2026-08-31 -->
# nats-server v2.14.6 — the JetStream log warnings this wiki quotes

Only the ranges this wiki quotes are stored, with their real line numbers, so each line links to
`https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`. Apache-2.0.

Read for question-bank Q62 (*how do I read and act on JetStream warnings in the server log*),
Q39 (*what corrupted a JetStream cluster*), Q69 (*KV watchers*) and Q77 (*unexpected `nats: timeout`*),
against `raw/gh-discussions/gh-6490.md`, `gh-7463.md`, `gh-5243.md` and `gh-5859.md`.

### `server/jetstream_cluster.go` lines 10211–10215

```go
 10211	
 10212	// To warn when we are getting too far behind from what has been proposed vs what has been committed.
 10213	const streamLagWarnThreshold = 10_000
 10214	
 10215	// processClusteredInboundMsg will propose the inbound message to the underlying raft group.
```

### `server/stream.go` lines 7644–7658

```go
  7644			// and not interleaved with other proposals.
  7645			if err = node.ProposeMulti(term, entries); err == nil {
  7646				diff.commit(mset)
  7647				mset.trackReplicationTraffic(node, sz, r)
  7648	
  7649				// Check to see if we are being overrun.
  7650				// TODO(dlc) - Make this a limit where we drop messages to protect ourselves, but allow to be configured.
  7651				if mset.clseq-(lseq+mset.clfs) > streamLagWarnThreshold {
  7652					lerr := fmt.Errorf("JetStream stream '%s > %s' has high message lag", jsa.acc().Name, name)
  7653					s.RateLimitWarnf("%s", lerr.Error())
  7654				}
  7655			} else {
  7656				mset.clseq = oclseq
  7657			}
  7658			mset.clMu.Unlock()
```

### `server/filestore.go` lines 5295–5305

```go
  5295				"name":  fs.cfg.Name,
  5296				"err":   err,
  5297				"stack": string(debug.Stack()),
  5298			})
  5299			return
  5300		}
  5301		fs.error("Critical write error: %v", err)
  5302		fs.werr = err
  5303		assert.Unreachable("Filestore encountered write error", map[string]any{
  5304			"name":  fs.cfg.Name,
  5305			"err":   err,
```

### `server/filestore.go` lines 8850–8865

```go
  8850		errStateTooBig   = errors.New("store state too big for optional write")
  8851	)
  8852	
  8853	type (
  8854		errBadMsg struct{ fn, detail string }
  8855	)
  8856	
  8857	func (e errBadMsg) Error() string {
  8858		if e.detail != _EMPTY_ {
  8859			return fmt.Sprintf("malformed or corrupt message in %s: %s", filepath.Base(e.fn), e.detail)
  8860		}
  8861		return fmt.Sprintf("malformed or corrupt message in %s", filepath.Base(e.fn))
  8862	}
  8863	
  8864	const (
  8865		// "Checksum bit" is used in "mb.cache.idx" for marking messages that have had their checksums checked.
```

### `server/jetstream_cluster.go` lines 3505–3535

```go
  3505							}
  3506							// If the error signals we timed out of a snapshot, we should try to replay the snapshot
  3507							// instead of fully resetting the state. Resetting the clustered state may result in
  3508							// race conditions and should only be used as a last effort attempt.
  3509							if errors.Is(err, errCatchupAbortedNoLeader) || err == errCatchupTooManyRetries || err == errAlreadyLeader {
  3510								if n.DrainAndReplaySnapshot() {
  3511									break
  3512								} else if n.IsDeleted() {
  3513									// The only reason we can't replay is our node being deleted, which
  3514									// means the meta layer is deliberately tearing this monitor down.
  3515									// Don't fall through to a reset, that would resurrect this group.
  3516									s.Warnf("Will not reset stream '%s > %s', raft group %q was removed",
  3517										accName, sa.Config.Name, n.Group())
  3518									aq.recycle(&ces)
  3519									return
  3520								}
  3521							}
  3522							// We will attempt to reset our cluster state.
  3523							if mset.resetClusteredState(n, err) {
  3524								aq.recycle(&ces)
  3525								return
  3526							}
  3527						} else if isOutOfSpaceErr(err) {
  3528							// If applicable this will tear all of this down, but don't assume so and return.
  3529							s.handleOutOfSpace(mset)
  3530						} else {
  3531							// Encountered an unexpected error, can't continue.
  3532							mset.setWriteErr(err)
  3533							aq.recycle(&ces)
  3534							return
  3535						}
```

### `server/jetstream_cluster.go` lines 3912–3995

```go
  3912	func (mset *stream) resetClusteredState(n RaftNode, err error) bool {
  3913		mset.mu.RLock()
  3914		s, js, jsa, sa, acc, node, name := mset.srv, mset.js, mset.jsa, mset.sa, mset.acc, mset.node, mset.nameLocked(false)
  3915		stype, tierName, replicas := mset.cfg.Storage, mset.tier, mset.cfg.Replicas
  3916		mset.mu.RUnlock()
  3917	
  3918		// The stream might already be deleted and not assigned to us anymore.
  3919		// In any case, don't revive the stream if it's already closed.
  3920		// A nil node means it was removed out from underneath us, which only happens
  3921		// when the meta layer is deliberately tearing this monitor down.
  3922		if mset.closed.Load() || node == nil || node.IsDeleted() {
  3923			s.Warnf("Will not reset stream '%s > %s', stream is closed", acc, mset.name())
  3924			// Explicitly returning true here, we want the outside to break out of the monitoring loop as well.
  3925			return true
  3926		}
  3927	
  3928		// The node we were monitoring is no longer this stream's node. The meta layer has
  3929		// remapped us into a different group and is tearing this monitor down, so resetting
  3930		// here would resurrect a group that has already been replaced.
  3931		if n != nil && n != node {
  3932			s.Warnf("Will not reset stream '%s > %s', raft group %q was replaced by %q",
  3933				acc, mset.name(), n.Group(), node.Group())
  3934			// Explicitly returning true here, we want the outside to break out of the monitoring loop as well.
  3935			return true
  3936		}
  3937	
  3938		assert.Unreachable("Reset clustered state", map[string]any{
  3939			"stream":  name,
  3940			"account": acc.Name,
  3941			"err":     err,
  3942		})
  3943	
  3944		// Stepdown regardless if we are the leader here.
  3945		node.StepDown()
  3946	
  3947		// If we detect we are shutting down just return.
  3948		if js != nil && js.isShuttingDown() {
  3949			s.Debugf("Will not reset stream '%s > %s', JetStream shutting down", acc, mset.name())
  3950			return false
  3951		}
  3952	
  3953		// Server
  3954		if js.limitsExceeded(stype) {
  3955			s.Warnf("Will not reset stream '%s > %s', server resources exceeded", acc, mset.name())
  3956			return false
  3957		}
  3958	
  3959		// Account
  3960		if exceeded, _ := jsa.limitsExceeded(stype, tierName, replicas); exceeded {
  3961			s.Warnf("Stream '%s > %s' errored, account resources exceeded", acc, mset.name())
  3962			return false
  3963		}
  3964	
  3965		if errors.Is(err, errCatchupAbortedNoLeader) || err == errCatchupTooManyRetries {
  3966			// Don't delete all state, could've just been temporarily unable to reach the leader.
  3967			node.Stop()
  3968		} else {
  3969			// We delete our raft state. Will recreate.
  3970			node.Delete()
  3971		}
  3972	
  3973		// Preserve our current state and messages unless we have a first sequence mismatch.
  3974		shouldDelete := err == errFirstSequenceMismatch
  3975	
  3976		// Need to do the rest in a separate Go routine.
  3977		go func() {
  3978			mset.stopMonitoring()
  3979			mset.resetAndWaitOnConsumers()
  3980			// Stop our stream.
  3981			mset.stop(shouldDelete, false)
  3982	
  3983			if sa != nil {
  3984				js.mu.Lock()
  3985				if js.shuttingDown {
  3986					js.mu.Unlock()
  3987					return
  3988				}
  3989	
  3990				s.Warnf("Resetting stream cluster state for '%s > %s'", sa.Client.serviceAccount(), sa.Config.Name)
  3991				// Mark stream assignment as resetting, so we don't double-account reserved resources.
  3992				// But only if we're not also releasing the resources as part of the delete.
  3993				sa.resetting = !shouldDelete
  3994				// Now wipe groups from assignments.
  3995				sa.Group.node = nil
```

### `server/consumer.go` lines 2312–2330

```go
  2312					js.mu.RLock()
  2313					if js.shuttingDown {
  2314						js.mu.RUnlock()
  2315						return
  2316					}
  2317					nca = js.consumerAssignment(acc, stream, name)
  2318					// Make sure this is the same consumer assignment, and not a new consumer with the same name.
  2319					match := ca.sameIdentity(nca)
  2320					js.mu.RUnlock()
  2321					if match {
  2322						s.Warnf("Consumer assignment for '%s > %s > %s' not cleaned up, retrying", acc, stream, name)
  2323						meta.ForwardProposal(removeEntry)
  2324						if interval < cnaMax {
  2325							interval *= 2
  2326							ticker.Reset(interval)
  2327						}
  2328						continue
  2329					}
  2330					// We saw that consumer has been removed, all done.
```

### `server/jetstream_api.go` lines 845–895

```go
   845			if c.kind == CLIENT || c.kind == LEAF {
   846				ci, acc, _, _, _ := s.getRequestInfo(c, rmsg)
   847				var resp = ApiResponse{
   848					Type:  JSApiSystemResponseType,
   849					Error: NewJSBadRequestError(),
   850				}
   851				s.sendAPIErrResponse(ci, acc, subject, reply, string(msg), s.jsonResponse(&resp))
   852			}
   853			return
   854		}
   855		jsub := rr.psubs[0]
   856	
   857		// We need to make sure not to block. We will send the request to a long-lived
   858		// pool of go routines.
   859	
   860		// Increment inflight. Do this before queueing.
   861		atomic.AddInt64(&js.apiInflight, 1)
   862	
   863		// Copy the state. Note the JSAPI only uses the hdr index to piece apart the
   864		// header from the msg body. No other references are needed.
   865		// Check pending and warn if getting backed up.
   866		var queue *ipQueue[*jsAPIRoutedReq]
   867		var limit int64
   868		if js.infoSubs.HasInterest(subject) {
   869			queue = s.jsAPIRoutedInfoReqs
   870			limit = atomic.LoadInt64(&js.infoQueueLimit)
   871		} else {
   872			queue = s.jsAPIRoutedReqs
   873			limit = atomic.LoadInt64(&js.queueLimit)
   874		}
   875		pending, _ := queue.push(&jsAPIRoutedReq{jsub, sub, acc, subject, reply, copyBytes(rmsg), c.pa})
   876		if pending >= int(limit) {
   877			s.rateLimitFormatWarnf("%s limit reached, dropping %d requests", queue.name, pending)
   878			drained := int64(queue.drain())
   879			atomic.AddInt64(&js.apiInflight, -drained)
   880	
   881			s.publishAdvisory(nil, JSAdvisoryAPILimitReached, JSAPILimitReachedAdvisory{
   882				TypedEvent: TypedEvent{
   883					Type: JSAPILimitReachedAdvisoryType,
   884					ID:   nuid.Next(),
   885					Time: time.Now().UTC(),
   886				},
   887				Server:  s.Name(),
   888				Domain:  js.config.Domain,
   889				Dropped: drained,
   890			})
   891		}
   892	}
   893	
   894	func (s *Server) processJSAPIRoutedRequests() {
   895		defer s.grWG.Done()
```

### `server/jetstream_api.go` lines 950–960

```go
   950		mp := runtime.GOMAXPROCS(0)
   951		// Cap at 16 max for now on larger core setups.
   952		if mp > maxProcs {
   953			mp = maxProcs
   954		}
   955		s.jsAPIRoutedReqs = newIPQueue[*jsAPIRoutedReq](s, "JetStream API queue")
   956		s.jsAPIRoutedInfoReqs = newIPQueue[*jsAPIRoutedReq](s, "JetStream API info queue")
   957		for i := 0; i < mp; i++ {
   958			s.startGoRoutine(s.processJSAPIRoutedRequests)
   959		}
   960	
```

---

## The neighbouring JetStream warnings

The other `Warnf`/`RateLimitWarnf` call sites an operator meets, quoted so the wiki's table of them
can be regenerated. Collected with
`grep -n 'Warnf("JetStream\|RateLimitWarnf("JetStream' server/*.go` at v2.14.6.

### `server/jetstream_cluster.go` lines 4809–4813

```go
  4809		}
  4810	
  4811		s.Warnf("JetStream cluster stream '%s > %s' has NO quorum, stalled", acc.GetName(), stream)
  4812	
  4813		subj := JSAdvisoryStreamQuorumLostPre + "." + stream
```

### `server/jetstream_cluster.go` lines 7306–7310

```go
  7306		}
  7307	
  7308		s.Warnf("JetStream cluster consumer '%s > %s > %s' has NO quorum, stalled.", acc.GetName(), stream, consumer)
  7309	
  7310		subj := JSAdvisoryConsumerQuorumLostPre + "." + stream + "." + consumer
```

### `server/jetstream_cluster.go` lines 3255–3260

```go
  3255				if err := n.InstallSnapshot(mset.stateSnapshot(), true); err != nil &&
  3256					err != errNoSnapAvailable && err != errNodeClosed {
  3257					s.RateLimitWarnf("Failed to install snapshot for '%s > %s' [%s]: %v",
  3258						mset.acc.Name, mset.name(), n.Group(), err)
  3259				}
  3260				return
```

### `server/jetstream_cluster.go` lines 2606–2610

```go
  2606		accName := sa.Client.serviceAccount()
  2607		if !replaced {
  2608			s.Warnf("JetStream cluster could not replace peer for stream '%s > %s'", accName, sa.Config.Name)
  2609		}
  2610	
```

### `server/jetstream_cluster.go` lines 5236–5240

```go
  5236			// Make sure we have not had a new group assigned to us.
  5237			if osa.Group.Name != sa.Group.Name {
  5238				s.Warnf("JetStream cluster detected stream remapping for '%s > %s' from %q to %q",
  5239					acc, cfg.Name, osa.Group.Name, sa.Group.Name)
  5240				mset.removeNode()
```

### `server/jetstream_cluster.go` lines 7459–7463

```go
  7459					apiErr = result.Restore.Error
  7460				}
  7461				s.Warnf("Stream assignment for '%s > %s' rejected by assigned member: %v", sa.Client.serviceAccount(), sa.Config.Name, apiErr)
  7462				sa.err = NewJSClusterNotAssignedError()
  7463				if err := cc.meta.Propose(cc.term, encodeDeleteStreamAssignment(sa)); err != nil {
```

### `server/jetstream_cluster.go` lines 7664–7668

```go
  7664				}
  7665				if sa.Sync == _EMPTY_ {
  7666					s.Warnf("Stream assignment corrupt for stream '%s > %s'", acc, sa.Config.Name)
  7667					nsa := &streamAssignment{Group: sa.Group, Config: sa.Config, Subject: sa.Subject, Reply: sa.Reply, Client: sa.Client, Created: sa.Created}
  7668					nsa.Sync = syncSubjForStream()
```

### `server/jetstream_cluster.go` lines 10289–10293

```go
 10289				err = NewJSAccountResourcesExceededError()
 10290			}
 10291			s.RateLimitWarnf("JetStream account limits exceeded for '%s': %s", jsa.acc().GetName(), err.Error())
 10292			if canRespond {
 10293				var resp = &JSPubAckResponse{PubAck: &PubAck{Stream: name}}
```

### `server/jetstream_cluster.go` lines 1705–1709

```go
  1705				}
  1706				if thresh := 10 * szthresh; nsz >= thresh {
  1707					s.rateLimitFormatWarnf("JetStream cluster metalayer log size has exceeded async threshold (%s), will fall back to blocking snapshot", friendlyBytes(thresh))
  1708					fallbackSnapshot = true
  1709				}
```

### `server/consumer.go` lines 1329–1334

```go
  1329			// Only performed for non-replicated consumers for now.
  1330			if replicas == 1 && lseq < sseq && isRecovering {
  1331				s.Warnf("JetStream consumer '%s > %s > %s' delivered sequence %d past last stream sequence of %d",
  1332					o.acc.Name, o.stream, o.name, sseq, lseq)
  1333	
  1334				o.mu.Lock()
```

### `server/consumer.go` lines 3693–3698

```go
  3693			mset.store.FastState(&ss)
  3694			if sseq > ss.LastSeq {
  3695				o.srv.Warnf("JetStream consumer '%s > %s > %s' ACK sequence %d past last stream sequence of %d",
  3696					o.acc.Name, o.stream, o.name, sseq, ss.LastSeq)
  3697				// FIXME(dlc) - For 2.11 onwards should we return an error here to the caller?
  3698			}
```
