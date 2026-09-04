<!-- source: https://github.com/nats-io/nats.go at tag v1.53.1, nats.go fetched from raw.githubusercontent.com · fetched 2026-09-04 -->
# nats.go v1.53.1 — the connection: defaults, reconnect, keepalive, drain, flush

Extracted line ranges, verbatim, with their real line numbers at the tag
(`https://github.com/nats-io/nats.go/blob/v1.53.1/nats.go#L<line>`). Read for step 3 of
`inbox/plan-the-client-side-2026-09-03.md` — the reference implementation's own values behind
`wiki/concepts/client-connection-lifecycle.md` and `wiki/reference/client-defaults.md`, because
`raw/nats-docs/learn/resilient-clients/` is unversioned by design and names no client version
anywhere. The `nats` CLI 0.4.0 uses this client (its `go.mod` pins v1.51.0; every value quoted here
was read at **v1.53.1**, the version the `nats-go` entity is verified against).

What the ranges settle, in the order they appear:

- every default a Go connection starts with, in one const block, and the `Options` struct that
  applies them;
- the seven connection **states**, including the two draining ones no other client's enum has;
- that a connection with **no async error callback does not discard** its slow-consumer and
  auth reports — nats.go installs `defaultErrHandler`, which writes them to **stderr**;
- `selectNextServer`: the pool rotates, and a server that spends its `MaxReconnect` budget is
  **removed from the pool** — so `MaxReconnect` is a per-server budget, and an empty pool is CLOSED;
- that the reconnect **sleep happens only after a whole sweep** of the pool, that the TLS jitter is
  chosen by `Opts.Secure || TLSConfig != nil` for every URL in the pool, and that
  `CustomReconnectDelay` replaces the wait **and** the jitter;
- the reconnect **buffer** check (`ErrReconnectBufExceeded`) and where in a publish it sits;
- the keepalive: `pout++` then `pout > MaxPingsOut`, so the **third** unanswered ping is the one
  that trips it;
- `processAuthError`: the abort is *the same error from the same server twice in a row*, unless
  `IgnoreAuthErrorAbort`;
- `drainConnection`: subs first with the `DrainTimeout` deadline, then `DRAINING_PUBS` and a
  **hardcoded 5 s** flush, then `Close()` — and that a drain issued while RECONNECTING **closes**
  the connection instead of draining it;
- `Drain()` returns at once; `Flush()` is `FlushTimeout(10 * time.Second)`.

### The default constants (`nats.go:51–69`)

```go
    50	// Default Constants
    51	const (
    52		Version                   = "1.53.1"
    53		DefaultURL                = "nats://127.0.0.1:4222"
    54		DefaultPort               = 4222
    55		DefaultMaxReconnect       = 60
    56		DefaultReconnectWait      = 2 * time.Second
    57		DefaultReconnectJitter    = 100 * time.Millisecond
    58		DefaultReconnectJitterTLS = time.Second
    59		DefaultTimeout            = 2 * time.Second
    60		DefaultPingInterval       = 2 * time.Minute
    61		DefaultMaxPingOut         = 2
    62		DefaultMaxChanLen         = 64 * 1024       // 64k
    63		DefaultReconnectBufSize   = 8 * 1024 * 1024 // 8MB
    64		DefaultWriteBufSize       = defaultBufSize
    65		RequestChanLen            = 8
    66		DefaultDrainTimeout       = 30 * time.Second
    67		DefaultFlusherTimeout     = time.Minute
    68		LangString                = "go"
    69	)
```

### `GetDefaultOptions` — the options a connection starts with (`:163–178`)

```go
   162	// GetDefaultOptions returns default configuration options for the client.
   163	func GetDefaultOptions() Options {
   164		return Options{
   165			AllowReconnect:     true,
   166			MaxReconnect:       DefaultMaxReconnect,
   167			ReconnectWait:      DefaultReconnectWait,
   168			ReconnectJitter:    DefaultReconnectJitter,
   169			ReconnectJitterTLS: DefaultReconnectJitterTLS,
   170			Timeout:            DefaultTimeout,
   171			PingInterval:       DefaultPingInterval,
   172			MaxPingsOut:        DefaultMaxPingOut,
   173			SubChanLen:         DefaultMaxChanLen,
   174			ReconnectBufSize:   DefaultReconnectBufSize,
   175			DrainTimeout:       DefaultDrainTimeout,
   176			FlusherTimeout:     DefaultFlusherTimeout,
   177		}
   178	}
```

### The connection states (`:185–216`)

```go
   185	// Status represents the state of the connection.
   186	type Status int
   187	
   188	const (
   189		DISCONNECTED = Status(iota)
   190		CONNECTED
   191		CLOSED
   192		RECONNECTING
   193		CONNECTING
   194		DRAINING_SUBS
   195		DRAINING_PUBS
   196	)
   197	
   198	func (s Status) String() string {
   199		switch s {
   200		case DISCONNECTED:
   201			return "DISCONNECTED"
   202		case CONNECTED:
   203			return "CONNECTED"
   204		case CLOSED:
   205			return "CLOSED"
   206		case RECONNECTING:
   207			return "RECONNECTING"
   208		case CONNECTING:
   209			return "CONNECTING"
   210		case DRAINING_SUBS:
   211			return "DRAINING_SUBS"
   212		case DRAINING_PUBS:
   213			return "DRAINING_PUBS"
   214		}
   215		return "unknown status"
   216	}
```

### The errors this page cites (`:126–130` and the slow-consumer / draining strings)

```go
   125		ErrSyncSubRequired               = errors.New("nats: illegal call on an async subscription")
   126		ErrMultipleTLSConfigs            = errors.New("nats: multiple tls.Configs not allowed")
   127		ErrClientCertOrRootCAsRequired   = errors.New("nats: at least one of certCB or rootCAsCB must be set")
   128		ErrNoInfoReceived                = errors.New("nats: protocol exception, INFO not received")
   129		ErrReconnectBufExceeded          = errors.New("nats: outbound buffer limit exceeded")
   130		ErrInvalidConnection             = errors.New("nats: invalid connection")
   131		ErrInvalidMsg                    = errors.New("nats: invalid message or message nil")
   132		ErrInvalidArg                    = errors.New("nats: invalid argument")
   133		ErrInvalidContext                = errors.New("nats: invalid context")
```

### `ErrReconnectBufExceeded` and `ErrSlowConsumer` in the same block

```go
   111		ErrBadQueueName                  = errors.New("nats: invalid queue name")
   112		ErrSlowConsumer                  = errors.New("nats: slow consumer, messages dropped")
   113		ErrTimeout                       = errors.New("nats: timeout")
```

### The default async-error handler is installed when the caller sets none (`:1975–1981`)

```go
  1974		// Create the async callback handler.
  1975		nc.ach = &asyncCallbacksHandler{}
  1976		nc.ach.cond = sync.NewCond(&nc.ach.mu)
  1977	
  1978		// Set a default error handler that will print to stderr.
  1979		if nc.Opts.AsyncErrorCB == nil {
  1980			nc.Opts.AsyncErrorCB = defaultErrHandler
  1981		}
  1982	
```

### `defaultErrHandler` — what it writes, and where (`:2006–2028`)

```go
  2006	func defaultErrHandler(nc *Conn, sub *Subscription, err error) {
  2007		var cid uint64
  2008		if nc != nil {
  2009			nc.mu.RLock()
  2010			cid = nc.info.CID
  2011			nc.mu.RUnlock()
  2012		}
  2013		var errStr string
  2014		if sub != nil {
  2015			var subject string
  2016			sub.mu.Lock()
  2017			if sub.jsi != nil {
  2018				subject = sub.jsi.psubj
  2019			} else {
  2020				subject = sub.Subject
  2021			}
  2022			sub.mu.Unlock()
  2023			errStr = fmt.Sprintf("%s on connection [%d] for subscription on %q\n", err.Error(), cid, subject)
  2024		} else {
  2025			errStr = fmt.Sprintf("%s on connection [%d]\n", err.Error(), cid)
  2026		}
  2027		os.Stderr.WriteString(errStr)
  2028	}
```

### `selectNextServer` — the rotation and the drop (`:2069–2091`)

```go
  2068	
  2069	// Pop the current server and put onto the end of the list. Select head of list as long
  2070	// as number of reconnect attempts under MaxReconnect.
  2071	func (nc *Conn) selectNextServer() (*Server, error) {
  2072		i, s := nc.currentServer()
  2073		if i < 0 {
  2074			return nil, ErrNoServers
  2075		}
  2076		sp := nc.srvPool
  2077		num := len(sp)
  2078		copy(sp[i:num-1], sp[i+1:num])
  2079		maxReconnect := nc.Opts.MaxReconnect
  2080		if maxReconnect < 0 || s.Reconnects < maxReconnect {
  2081			nc.srvPool[num-1] = s
  2082		} else {
  2083			nc.srvPool = sp[0 : num-1]
  2084		}
  2085		if len(nc.srvPool) <= 0 {
  2086			nc.current = nil
  2087			return nil, ErrNoServers
  2088		}
  2089		nc.current = nc.srvPool[0]
  2090		return nc.srvPool[0], nil
  2091	}
```

### `ForceReconnect` (`:2582–2624`)

```go
  2581	
  2582	// ForceReconnect forces a reconnect attempt to the server.
  2583	// This is a non-blocking call and will start the reconnect
  2584	// process without waiting for it to complete.
  2585	//
  2586	// If the connection is already in the process of reconnecting,
  2587	// this call will force an immediate reconnect attempt (bypassing
  2588	// the current reconnect delay).
  2589	func (nc *Conn) ForceReconnect() error {
  2590		nc.mu.Lock()
  2591		defer nc.mu.Unlock()
  2592	
  2593		if nc.isClosed() {
  2594			return ErrConnectionClosed
  2595		}
  2596		if nc.isReconnecting() {
  2597			// if we're already reconnecting, force a reconnect attempt
  2598			// even if we're in the middle of a backoff
  2599			if nc.rqch != nil {
  2600				close(nc.rqch)
  2601				nc.rqch = nil
  2602			}
  2603			return nil
  2604		}
  2605	
  2606		// Clear any queued pongs
  2607		nc.clearPendingFlushCalls()
  2608	
  2609		// Clear any queued and blocking requests.
  2610		nc.clearPendingRequestCalls()
  2611	
  2612		// Stop ping timer if set.
  2613		nc.stopPingTimer()
  2614	
  2615		// flush any pending data and switch to pending mode to buffer new outgoing
  2616		// data until we reconnect and can flush it.
  2617		nc.bw.flush()
  2618		nc.bw.switchToPending()
  2619		nc.conn.Close()
  2620	
  2621		nc.changeConnStatus(RECONNECTING)
  2622		go nc.doReconnect(nil, true)
  2623		return nil
  2624	}
```

### `doReconnect` — the disconnect callback and the first-connect path (`:3272–3302`)

```go
  3272	func (nc *Conn) doReconnect(err error, forceReconnect bool) {
  3273		// We want to make sure we have the other watchers shutdown properly
  3274		// here before we proceed past this point.
  3275		nc.waitForExits()
  3276	
  3277		// FIXME(dlc) - We have an issue here if we have
  3278		// outstanding flush points (pongs) and they were not
  3279		// sent out, but are still in the pipe.
  3280	
  3281		// Hold the lock manually and release where needed below,
  3282		// can't do defer here.
  3283		nc.mu.Lock()
  3284	
  3285		// Clear any errors.
  3286		nc.err = nil
  3287	
  3288		// Perform appropriate callback if needed for a disconnect.
  3289		// DisconnectedErrCB has priority over deprecated DisconnectedCB
  3290		if !nc.initc {
  3291			if disconnectedErrCB := nc.Opts.DisconnectedErrCB; disconnectedErrCB != nil {
  3292				nc.ach.push(func() { disconnectedErrCB(nc, err) })
  3293			} else if disconnectedCB := nc.Opts.DisconnectedCB; disconnectedCB != nil {
  3294				nc.ach.push(func() { disconnectedCB(nc) })
  3295			}
  3296		} else if nc.Opts.RetryOnFailedConnect && nc.initc && err != nil {
  3297			// For initial connection failure with RetryOnFailedConnect,
  3298			// report the error via ReconnectErrCB if available
  3299			if nc.Opts.ReconnectErrCB != nil {
  3300				nc.ach.push(func() { nc.Opts.ReconnectErrCB(nc, err) })
  3301			}
  3302		}
```

### `doReconnect` — the wait, the jitter, and which one the TLS value applies to (`:3305–3337`)

```go
  3305		// but an error occurs after that.
  3306		waitForGoRoutines := false
  3307		var rt *time.Timer
  3308		// Channel used to kick routine out of sleep when conn is closed.
  3309		rqch := nc.rqch
  3310	
  3311		// if rqch is nil, we need to set it up to signal
  3312		// the reconnect loop to reconnect immediately
  3313		// this means that `ForceReconnect` was called
  3314		// before entering doReconnect
  3315		if rqch == nil {
  3316			rqch = make(chan struct{})
  3317			close(rqch)
  3318		}
  3319	
  3320		// Counter that is increased when the whole list of servers has been tried.
  3321		var wlf int
  3322	
  3323		var jitter time.Duration
  3324		var rw time.Duration
  3325		// If a custom reconnect delay handler is set, this takes precedence.
  3326		crd := nc.Opts.CustomReconnectDelayCB
  3327		if crd == nil {
  3328			rw = nc.Opts.ReconnectWait
  3329			// TODO: since we sleep only after the whole list has been tried, we can't
  3330			// rely on individual *srv to know if it is a TLS or non-TLS url.
  3331			// We have to pick which type of jitter to use, for now, we use these hints:
  3332			jitter = nc.Opts.ReconnectJitter
  3333			if nc.Opts.Secure || nc.Opts.TLSConfig != nil {
  3334				jitter = nc.Opts.ReconnectJitterTLS
  3335			}
  3336		}
  3337	
```

### `doReconnect` — the sleep happens only after a whole sweep of the pool (`:3388–3398`)

```go
  3388			var doSleep bool
  3389			if cur == nil {
  3390				cur, err = nc.selectNextServer()
  3391				if err != nil {
  3392					nc.err = err
  3393					break
  3394				}
  3395				doSleep = i+1 >= len(nc.srvPool) && !forceReconnect
  3396			}
  3397	
  3398			forceReconnect = false
```

### `doReconnect` — the custom delay replaces wait *and* jitter (`:3419–3450`)

```go
  3419				}
  3420			} else if !doSleep {
  3421				i++
  3422				// Release the lock to give a chance to a concurrent nc.Close() to break the loop.
  3423				runtime.Gosched()
  3424			} else {
  3425				i = 0
  3426				var st time.Duration
  3427				if crd != nil {
  3428					wlf++
  3429					st = crd(wlf)
  3430				} else {
  3431					st = rw
  3432					if jitter > 0 {
  3433						st += time.Duration(rand.Int63n(int64(jitter)))
  3434					}
  3435				}
  3436				if rt == nil {
  3437					rt = time.NewTimer(st)
  3438				} else {
  3439					rt.Reset(st)
  3440				}
  3441				select {
  3442				case <-rqch:
  3443					rt.Stop()
  3444	
  3445					// we need to reset the rqch channel to avoid
  3446					// closing a closed channel in the next iteration
  3447					nc.mu.Lock()
  3448					nc.rqch = make(chan struct{})
  3449					nc.mu.Unlock()
  3450				case <-rt.C:
```

### `doReconnect` — `Reconnects++`, the reset on success, resend then flush (`:3456–3527`)

```go
  3456				waitForGoRoutines = false
  3457			}
  3458			nc.mu.Lock()
  3459	
  3460			// Check if we have been closed first.
  3461			if nc.isClosed() {
  3462				break
  3463			}
  3464	
  3465			// Mark that we tried a reconnect
  3466			cur.Reconnects++
  3467	
  3468			// Try to create a new connection
  3469			err = nc.createConn()
  3470			// Not yet connected, retry...
  3471			// Continue to hold the lock
  3472			if err != nil {
  3473				// Perform appropriate callback for a failed connection attempt.
  3474				if reconnectErrCB := nc.Opts.ReconnectErrCB; reconnectErrCB != nil {
  3475					nc.ach.push(func() { reconnectErrCB(nc, err) })
  3476				}
  3477				nc.err = nil
  3478				continue
  3479			}
  3480	
  3481			// We are reconnected
  3482			nc.Reconnects++
  3483	
  3484			// Process connect logic
  3485			if nc.err = nc.processConnectInit(); nc.err != nil {
  3486				// Check if we should abort reconnect. If so, break out
  3487				// of the loop and connection will be closed.
  3488				if nc.ar {
  3489					break
  3490				}
  3491				nc.changeConnStatus(RECONNECTING)
  3492				continue
  3493			}
  3494	
  3495			// Clear possible lastErr under the connection lock after
  3496			// a successful processConnectInit().
  3497			nc.current.lastErr = nil
  3498	
  3499			// Clear out server stats for the server we connected to..
  3500			cur.didConnect = true
  3501			cur.Reconnects = 0
  3502	
  3503			// Send existing subscription state
  3504			nc.resendSubscriptions()
  3505	
  3506			// Now send off and clear pending buffer
  3507			nc.err = nc.flushReconnectPendingItems()
  3508			if nc.err != nil {
  3509				nc.changeConnStatus(RECONNECTING)
  3510				// Stop the ping timer (if set)
  3511				nc.stopPingTimer()
  3512				// Since processConnectInit() returned without error, the
  3513				// go routines were started, so wait for them to return
  3514				// on the next iteration (after releasing the lock).
  3515				waitForGoRoutines = true
  3516				continue
  3517			}
  3518	
  3519			// Done with the pending buffer
  3520			nc.bw.doneWithPending()
  3521	
  3522			// Queue up the correct callback. If we are in initial connect state
  3523			// (using retry on failed connect), we will call the ConnectedCB,
  3524			// otherwise the ReconnectedCB.
  3525			if reconnectedCB := nc.Opts.ReconnectedCB; reconnectedCB != nil && !nc.initc {
  3526				nc.ach.push(func() { reconnectedCB(nc) })
  3527			} else if connectedCB := nc.Opts.ConnectedCB; connectedCB != nil && nc.initc {
```

### `doReconnect` — no servers left: `close(CLOSED)` (`:3544–3550`)

```go
  3544		// Call into close.. We have no servers left..
  3545		if nc.err == nil {
  3546			nc.err = ErrNoServers
  3547		}
  3548		nc.mu.Unlock()
  3549		nc.close(CLOSED, true, nil)
  3550	}
```

### `publish` — the reconnect-buffer limit (`:4584–4597`)

```go
  4583		// Proactively reject payloads over the threshold set by server.
  4584		msgSize := int64(len(data) + len(hdr))
  4585		// Skip this check if we are not yet connected (RetryOnFailedConnect)
  4586		if !nc.initc && msgSize > nc.info.MaxPayload {
  4587			nc.mu.Unlock()
  4588			return ErrMaxPayload
  4589		}
  4590	
  4591		// Check if we are reconnecting, and if so check if
  4592		// we have exceeded our reconnect outbound buffer limits.
  4593		if nc.bw.atLimitIfUsingPending() {
  4594			nc.mu.Unlock()
  4595			return ErrReconnectBufExceeded
  4596		}
  4597	
```

### `processAuthError` — the same error on the same server aborts (`:4077–4092`)

```go
  4077	func (nc *Conn) processAuthError(err error) bool {
  4078		nc.err = err
  4079		if !nc.initc {
  4080			if asyncErrorCB := nc.Opts.AsyncErrorCB; asyncErrorCB != nil {
  4081				nc.ach.push(func() { asyncErrorCB(nc, nil, err) })
  4082			}
  4083		}
  4084		// We should give up if we tried twice on this server and got the
  4085		// same error. This behavior can be modified using IgnoreAuthErrorAbort.
  4086		if nc.current.lastErr == err && !nc.Opts.IgnoreAuthErrorAbort {
  4087			nc.ar = true
  4088		} else {
  4089			nc.current.lastErr = err
  4090		}
  4091		return nc.ar
  4092	}
```

### `Subscription.Drain` (`:5191–5203`)

```go
  5185	// when the drain operation completes. If a failure occurs when deleting
  5186	// the JetStream consumer, an error will be reported to the asynchronous
  5187	// error callback.
  5188	// If you do not wish the JetStream consumer to be automatically deleted,
  5189	// ensure that the consumer is not created by the library, which means
  5190	// create the consumer with AddConsumer and bind to this consumer.
  5191	func (s *Subscription) Drain() error {
  5192		if s == nil {
  5193			return ErrBadSubscription
  5194		}
  5195		s.mu.Lock()
  5196		conn := s.conn
  5197		s.mu.Unlock()
  5198		if conn == nil {
  5199			return ErrBadSubscription
  5200		}
  5201		return conn.unsubscribe(s, 0, true)
  5202	}
  5203	
```

### The per-subscription pending defaults (`:5762–5768`)

```go
  5761	
  5762	// Pending Limits
  5763	const (
  5764		// DefaultSubPendingMsgsLimit will be 500k msgs.
  5765		DefaultSubPendingMsgsLimit = 500_000
  5766		// DefaultSubPendingBytesLimit is 64MB
  5767		DefaultSubPendingBytesLimit = 64 * 1024 * 1024
  5768	)
```

### `processPingTimer` — the third unanswered ping (`:5899–5921`)

```go
  5899	func (nc *Conn) processPingTimer() {
  5900		nc.mu.Lock()
  5901	
  5902		if nc.status != CONNECTED {
  5903			nc.mu.Unlock()
  5904			return
  5905		}
  5906	
  5907		// Check for violation
  5908		nc.pout++
  5909		if nc.pout > nc.Opts.MaxPingsOut {
  5910			nc.mu.Unlock()
  5911			if shouldClose := nc.processOpErr(ErrStaleConnection, false); shouldClose {
  5912				nc.close(CLOSED, true, nil)
  5913			}
  5914			return
  5915		}
  5916	
  5917		nc.sendPing(nil)
  5918		nc.ptmr.Reset(nc.Opts.PingInterval)
  5919		nc.mu.Unlock()
  5920	}
  5921	
```

### `Flush` is `FlushTimeout(10s)` (`:5978–5983`)

```go
  5975		return time.Since(start), nil
  5976	}
  5977	
  5978	// Flush will perform a round trip to the server and return when it
  5979	// receives the internal reply.
  5980	func (nc *Conn) Flush() error {
  5981		return nc.FlushTimeout(10 * time.Second)
  5982	}
  5983	
```

### `drainConnection` — closes instead of draining when reconnecting (`:6202–6231`)

```go
  6202	func (nc *Conn) drainConnection() {
  6203		// Snapshot subs list.
  6204		nc.mu.Lock()
  6205	
  6206		// Check again here if we are in a state to not process.
  6207		if nc.isClosed() {
  6208			nc.mu.Unlock()
  6209			return
  6210		}
  6211		if nc.isConnecting() || nc.isReconnecting() {
  6212			nc.mu.Unlock()
  6213			// Move to closed state.
  6214			nc.Close()
  6215			return
  6216		}
  6217	
  6218		subs := make([]*Subscription, 0, len(nc.subs))
  6219		for _, s := range nc.subs {
  6220			if s == nc.respMux {
  6221				// Skip since might be in use while messages
  6222				// are being processed (can miss responses).
  6223				continue
  6224			}
  6225			subs = append(subs, s)
  6226		}
  6227		errCB := nc.Opts.AsyncErrorCB
  6228		drainWait := nc.Opts.DrainTimeout
  6229		respMux := nc.respMux
  6230		nc.mu.Unlock()
  6231	
```

### `drainConnection` — the subscription phase and its deadline (`:6241–6283`)

```go
  6241	
  6242		// Do subs first, skip request handler if present.
  6243		for _, s := range subs {
  6244			if err := s.Drain(); err != nil {
  6245				// We will notify about these but continue.
  6246				pushErr(err)
  6247			}
  6248		}
  6249	
  6250		// Wait for the subscriptions to drop to zero.
  6251		timeout := time.Now().Add(drainWait)
  6252		var min int
  6253		if respMux != nil {
  6254			min = 1
  6255		} else {
  6256			min = 0
  6257		}
  6258		for time.Now().Before(timeout) {
  6259			if nc.NumSubscriptions() == min {
  6260				break
  6261			}
  6262			time.Sleep(10 * time.Millisecond)
  6263		}
  6264	
  6265		// In case there was a request/response handler
  6266		// then need to call drain at the end.
  6267		if respMux != nil {
  6268			if err := respMux.Drain(); err != nil {
  6269				// We will notify about these but continue.
  6270				pushErr(err)
  6271			}
  6272			for time.Now().Before(timeout) {
  6273				if nc.NumSubscriptions() == 0 {
  6274					break
  6275				}
  6276				time.Sleep(10 * time.Millisecond)
  6277			}
  6278		}
  6279	
  6280		// Check if we timed out.
  6281		if nc.NumSubscriptions() != 0 {
  6282			pushErr(ErrDrainTimeout)
  6283		}
```

### `drainConnection` — `DRAINING_PUBS`, the hardcoded 5 s flush, then `Close()` (`:6284–6298`)

```go
  6284	
  6285		// Flip State
  6286		nc.mu.Lock()
  6287		nc.changeConnStatus(DRAINING_PUBS)
  6288		nc.mu.Unlock()
  6289	
  6290		// Do publish drain via Flush() call.
  6291		err := nc.FlushTimeout(5 * time.Second)
  6292		if err != nil {
  6293			pushErr(err)
  6294		}
  6295	
  6296		// Move to closed state.
  6297		nc.Close()
  6298	}
```

### `Drain` returns at once (`:6300–6327`)

```go
  6299	
  6300	// Drain will put a connection into a drain state. All subscriptions will
  6301	// immediately be put into a drain state. Upon completion, the publishers
  6302	// will be drained and can not publish any additional messages. Upon draining
  6303	// of the publishers, the connection will be closed. Use the ClosedCB
  6304	// option to know when the connection has moved from draining to closed.
  6305	//
  6306	// See note in Subscription.Drain for JetStream subscriptions.
  6307	func (nc *Conn) Drain() error {
  6308		nc.mu.Lock()
  6309		if nc.isClosed() {
  6310			nc.mu.Unlock()
  6311			return ErrConnectionClosed
  6312		}
  6313		if nc.isConnecting() || nc.isReconnecting() {
  6314			nc.mu.Unlock()
  6315			nc.Close()
  6316			return ErrConnectionReconnecting
  6317		}
  6318		if nc.isDraining() {
  6319			nc.mu.Unlock()
  6320			return nil
  6321		}
  6322		nc.changeConnStatus(DRAINING_SUBS)
  6323		go nc.drainConnection()
  6324		nc.mu.Unlock()
  6325	
  6326		return nil
  6327	}
```

### `StatusChanged` (`:6629–6642`)

```go
  6628	
  6629	// StatusChanged returns a channel on which given list of connection status changes will be reported.
  6630	// If no statuses are provided, defaults will be used: CONNECTED, RECONNECTING, DISCONNECTED, CLOSED.
  6631	func (nc *Conn) StatusChanged(statuses ...Status) chan Status {
  6632		if len(statuses) == 0 {
  6633			statuses = []Status{CONNECTED, RECONNECTING, DISCONNECTED, CLOSED}
  6634		}
  6635		ch := make(chan Status, 10)
  6636		nc.mu.Lock()
  6637		defer nc.mu.Unlock()
  6638		for _, s := range statuses {
  6639			nc.registerStatusChangeListener(s, ch)
  6640		}
  6641		return ch
  6642	}
```

