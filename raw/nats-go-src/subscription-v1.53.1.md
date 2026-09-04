<!-- source: https://github.com/nats-io/nats.go at tag v1.53.1, nats.go fetched from raw.githubusercontent.com · fetched 2026-09-04 -->
# nats.go v1.53.1 — the subscription: pending limits, the slow-consumer signal, and the auth errors

Extracted line ranges, verbatim, with their real line numbers at the tag
(`https://github.com/nats-io/nats.go/blob/v1.53.1/nats.go#L<line>`). Read for step 4 of
`inbox/plan-the-client-side-2026-09-03.md` — the reference implementation behind
`wiki/gotchas/slow-consumer-in-the-client.md` and
`wiki/gotchas/connection-closed-after-auth-error.md`, because
`raw/nats-docs/learn/resilient-clients/` is unversioned by design and names no client version
anywhere. Companion to `raw/nats-go-src/connection-v1.53.1.md` (step 3), which holds the connection
defaults, the reconnect loop, the keepalive and drain; the two share `defaultErrHandler` and
`processAuthError`, quoted in both so each stands alone.

What the ranges settle, in the order they appear:

- the client-side slow consumer is **per subscription**, not per connection: `pMsgsLimit` /
  `pBytesLimit` default to **500,000 messages and 64 MB** and are set at subscribe time, before any
  message arrives;
- `SetPendingLimits` **rejects zero** (`ErrInvalidArg`) and reads a **negative value as unlimited** —
  so `SetPendingLimits(100, -1)` bounds the message count and leaves bytes uncapped;
- the overflow path drops the **arriving** message (`sub.dropped++`), undoes the pending stats, and
  fires the async error callback with `ErrSlowConsumer` — **once per transition**, not once per drop
  (`sc := !sub.sc`), and the subscription stays open;
- a *sync* subscription clears the flag on the next `NextMsg`, which returns `ErrSlowConsumer` once
  and then delivers normally again;
- a connection with **no async error callback does not discard** the report — nats.go installs
  `defaultErrHandler`, which writes `<err> on connection [<cid>] for subscription on "<subject>"`
  to **stderr**;
- `processErr` sorts the server's `-ERR` strings into three fates: **transient** (permissions,
  max subscriptions — callback only), **reconnect** (stale connection, the two connection-limit
  errors), and **auth** (the four strings `checkAuthError` matches, which go through
  `processAuthError`); everything else **closes** the connection;
- `processAuthError` aborts on *the same error from the same server twice in a row*, unless
  `IgnoreAuthErrorAbort`;
- `UserCredentials` stores two **callbacks**, and `userFromFile` does `os.ReadFile` inside one of
  them — so the `.creds` file is re-read from disk on **every** connect and reconnect attempt;
- `connectProto` runs those callbacks per attempt and signs the *current* nonce, and sends
  `no_responders` only when the server's `INFO` advertised `headers`;
- `Request` turns the server's 503 into `ErrNoResponders` by reading the status header on an
  empty-body reply.

### The errors this extract cites (`nats.go:112`, `:115–119`, `:151`)

```go
   111		ErrBadQueueName                  = errors.New("nats: invalid queue name")
   112		ErrSlowConsumer                  = errors.New("nats: slow consumer, messages dropped")
   113		ErrTimeout                       = errors.New("nats: timeout")
   114		ErrBadTimeout                    = errors.New("nats: timeout invalid")
   115		ErrAuthorization                 = errors.New("nats: authorization violation")
   116		ErrAuthExpired                   = errors.New("nats: authentication expired")
   117		ErrAuthRevoked                   = errors.New("nats: authentication revoked")
   118		ErrPermissionViolation           = errors.New("nats: permissions violation")
   119		ErrAccountAuthExpired            = errors.New("nats: account authentication expired")
```

### `ErrNoResponders` and its neighbours (`:150–152`)

```go
   150		ErrBadHeaderMsg                  = errors.New("nats: message could not decode headers")
   151		ErrNoResponders                  = errors.New("nats: no responders available for request")
   152		ErrMaxConnectionsExceeded        = errors.New("nats: server maximum connections exceeded")
```

### The server error strings nats.go matches on (`:72–97`)

```go
    71	const (
    72		// STALE_CONNECTION is for detection and proper handling of stale connections.
    73		STALE_CONNECTION = "stale connection"
    74	
    75		// PERMISSIONS_ERR is for when nats server subject authorization has failed.
    76		PERMISSIONS_ERR = "permissions violation"
    77	
    78		// AUTHORIZATION_ERR is for when nats server user authorization has failed.
    79		AUTHORIZATION_ERR = "authorization violation"
    80	
    81		// AUTHENTICATION_EXPIRED_ERR is for when nats server user authorization has expired.
    82		AUTHENTICATION_EXPIRED_ERR = "user authentication expired"
    83	
    84		// AUTHENTICATION_REVOKED_ERR is for when user authorization has been revoked.
    85		AUTHENTICATION_REVOKED_ERR = "user authentication revoked"
    86	
    87		// ACCOUNT_AUTHENTICATION_EXPIRED_ERR is for when nats server account authorization has expired.
    88		ACCOUNT_AUTHENTICATION_EXPIRED_ERR = "account authentication expired"
    89	
    90		// MAX_CONNECTIONS_ERR is for when nats server denies the connection due to server max_connections limit.
    91		MAX_CONNECTIONS_ERR = "maximum connections exceeded"
    92	
    93		// MAX_ACCOUNT_CONNECTIONS_ERR is for when nats server denies the connection due to server max_connections limit on the account.
    94		MAX_ACCOUNT_CONNECTIONS_ERR = `maximum account active connections exceeded`
    95	
    96		// MAX_SUBSCRIPTIONS_ERR is for when nats server denies the connection due to server subscriptions limit.
    97		MAX_SUBSCRIPTIONS_ERR = "maximum subscriptions exceeded"
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

### Where the defaults are applied at subscribe time (`:5041–5054`)

```go
  5041		sub := &Subscription{
  5042			Subject: subj,
  5043			Queue:   queue,
  5044			mcb:     cb,
  5045			conn:    nc,
  5046			jsi:     js,
  5047		}
  5048		// Set pending limits.
  5049		if ch != nil {
  5050			sub.pMsgsLimit = cap(ch)
  5051		} else {
  5052			sub.pMsgsLimit = DefaultSubPendingMsgsLimit
  5053		}
  5054		sub.pBytesLimit = DefaultSubPendingBytesLimit
```

### `PendingLimits` (`:5770–5786`)

```go
  5770	// PendingLimits returns the current limits for this subscription.
  5771	// If no error is returned, a negative value indicates that the
  5772	// given metric is not limited.
  5773	func (s *Subscription) PendingLimits() (int, int, error) {
  5774		if s == nil {
  5775			return -1, -1, ErrBadSubscription
  5776		}
  5777		s.mu.Lock()
  5778		defer s.mu.Unlock()
  5779		if s.conn == nil || s.closed {
  5780			return -1, -1, ErrBadSubscription
  5781		}
  5782		if s.typ == ChanSubscription {
  5783			return -1, -1, ErrTypeSubscription
  5784		}
  5785		return s.pMsgsLimit, s.pBytesLimit, nil
  5786	}
```

### `SetPendingLimits` — zero is rejected, negative means unlimited (`:5788–5807`)

```go
  5788	// SetPendingLimits sets the limits for pending msgs and bytes for this subscription.
  5789	// Zero is not allowed. Any negative value means that the given metric is not limited.
  5790	func (s *Subscription) SetPendingLimits(msgLimit, bytesLimit int) error {
  5791		if s == nil {
  5792			return ErrBadSubscription
  5793		}
  5794		s.mu.Lock()
  5795		defer s.mu.Unlock()
  5796		if s.conn == nil || s.closed {
  5797			return ErrBadSubscription
  5798		}
  5799		if s.typ == ChanSubscription {
  5800			return ErrTypeSubscription
  5801		}
  5802		if msgLimit == 0 || bytesLimit == 0 {
  5803			return ErrInvalidArg
  5804		}
  5805		s.pMsgsLimit, s.pBytesLimit = msgLimit, bytesLimit
  5806		return nil
  5807	}
```

### `Pending` — the live counters (`:5713–5727`)

```go
  5713	// Pending returns the number of queued messages and queued bytes in the client for this subscription.
  5714	func (s *Subscription) Pending() (int, int, error) {
  5715		if s == nil {
  5716			return -1, -1, ErrBadSubscription
  5717		}
  5718		s.mu.Lock()
  5719		defer s.mu.Unlock()
  5720		if s.conn == nil || s.closed {
  5721			return -1, -1, ErrBadSubscription
  5722		}
  5723		if s.typ == ChanSubscription {
  5724			return -1, -1, ErrTypeSubscription
  5725		}
  5726		return s.pMsgs, s.pBytes, nil
  5727	}
```

### `Dropped` — the running count, and its caveat (`:5822–5836`)

```go
  5822	// Dropped returns the number of known dropped messages for this subscription.
  5823	// This will correspond to messages dropped by violations of PendingLimits. If
  5824	// the server declares the connection a SlowConsumer, this number may not be
  5825	// valid.
  5826	func (s *Subscription) Dropped() (int, error) {
  5827		if s == nil {
  5828			return -1, ErrBadSubscription
  5829		}
  5830		s.mu.Lock()
  5831		defer s.mu.Unlock()
  5832		if s.conn == nil || s.closed {
  5833			return -1, ErrBadSubscription
  5834		}
  5835		return s.dropped, nil
  5836	}
```

### The overflow path: `sub.dropped++`, the one-shot transition, the callback (`:4005–4029`)

```go
  4005	slowConsumer:
  4006		sub.dropped++
  4007		sc := !sub.sc
  4008		sub.sc = true
  4009		// Undo stats from above
  4010		if sub.typ != ChanSubscription {
  4011			sub.pMsgs--
  4012			sub.pBytes -= len(m.Data)
  4013		}
  4014		if sc {
  4015			sub.changeSubStatus(SubscriptionSlowConsumer)
  4016			sub.mu.Unlock()
  4017			// Now we need connection's lock and we may end-up in the situation
  4018			// that we were trying to avoid, except that in this case, the client
  4019			// is already experiencing client-side slow consumer situation.
  4020			nc.mu.Lock()
  4021			nc.err = ErrSlowConsumer
  4022			if asyncErrorCB := nc.Opts.AsyncErrorCB; asyncErrorCB != nil {
  4023				nc.ach.push(func() { asyncErrorCB(nc, sub, ErrSlowConsumer) })
  4024			}
  4025			nc.mu.Unlock()
  4026		} else {
  4027			sub.mu.Unlock()
  4028		}
  4029	}
```

### `NextMsg`'s validity check returns `ErrSlowConsumer` once, then clears it (`:5626–5646`)

```go
  5626		if s.mcb != nil {
  5627			return ErrSyncSubRequired
  5628		}
  5629		// if this subscription previously had a permissions error
  5630		// and no reconnect has been attempted, return the permissions error
  5631		// since the subscription does not exist on the server
  5632		if s.conn.Opts.PermissionErrOnSubscribe && s.permissionsErr != nil {
  5633			return s.permissionsErr
  5634		}
  5635		if s.sc {
  5636			s.changeSubStatus(SubscriptionActive)
  5637			s.sc = false
  5638			return ErrSlowConsumer
  5639		}
  5640		// Unless this is from an internal call, reject use of this API.
  5641		// Users should use Fetch() instead.
  5642		if !pullSubInternal && s.jsi != nil && s.jsi.pull {
  5643			return ErrTypeSubscription
  5644		}
  5645		return nil
  5646	}
```

### The default async-error handler is installed when the caller sets none (`:1974–1981`)

```go
  1974		// Create the async callback handler.
  1975		nc.ach = &asyncCallbacksHandler{}
  1976		nc.ach.cond = sync.NewCond(&nc.ach.mu)
  1977	
  1978		// Set a default error handler that will print to stderr.
  1979		if nc.Opts.AsyncErrorCB == nil {
  1980			nc.Opts.AsyncErrorCB = defaultErrHandler
  1981		}
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

### `processTransientError` — permissions and max-subs do not close the connection (`:4036–4070`)

```go
  4036	// processTransientError is called when the server signals a non terminal error
  4037	// which does not close the connection or trigger a reconnect.
  4038	// This will trigger the async error callback if set.
  4039	// These errors include the following:
  4040	// - permissions violation on publish or subscribe
  4041	// - maximum subscriptions exceeded
  4042	func (nc *Conn) processTransientError(err error) {
  4043		nc.mu.Lock()
  4044		nc.err = err
  4045		if errors.Is(err, ErrPermissionViolation) {
  4046			matches := permissionsRe.FindStringSubmatch(err.Error())
  4047			if len(matches) >= 2 {
  4048				queueMatches := permissionsQueueRe.FindStringSubmatch(err.Error())
  4049				var q string
  4050				if len(queueMatches) >= 2 {
  4051					q = queueMatches[1]
  4052				}
  4053				subject := matches[1]
  4054				for _, sub := range nc.subs {
  4055					if sub.Subject == subject && sub.Queue == q && sub.permissionsErr == nil {
  4056						sub.mu.Lock()
  4057						if sub.errCh != nil {
  4058							sub.errCh <- err
  4059						}
  4060						sub.permissionsErr = err
  4061						sub.mu.Unlock()
  4062					}
  4063				}
  4064			}
  4065		}
  4066		if asyncErrorCB := nc.Opts.AsyncErrorCB; asyncErrorCB != nil {
  4067			nc.ach.push(func() { asyncErrorCB(nc, nil, err) })
  4068		}
  4069		nc.mu.Unlock()
  4070	}
```

### `processAuthError` — the same error on the same server aborts (`:4072–4092`)

```go
  4072	// processAuthError generally processing for auth errors. We want to do retries
  4073	// unless we get the same error again. This allows us for instance to swap credentials
  4074	// and have the app reconnect, but if nothing is changing we should bail.
  4075	// This function will return true if the connection should be closed, false otherwise.
  4076	// Connection lock is held on entry
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

### `checkAuthError` — the four auth strings nats.go recognises (`:4286–4302`)

```go
  4286	// Check if the given error string is an auth error, and if so returns
  4287	// the corresponding ErrXXX error, nil otherwise
  4288	func checkAuthError(e string) error {
  4289		if strings.HasPrefix(e, AUTHORIZATION_ERR) {
  4290			return ErrAuthorization
  4291		}
  4292		if strings.HasPrefix(e, AUTHENTICATION_EXPIRED_ERR) {
  4293			return ErrAuthExpired
  4294		}
  4295		if strings.HasPrefix(e, AUTHENTICATION_REVOKED_ERR) {
  4296			return ErrAuthRevoked
  4297		}
  4298		if strings.HasPrefix(e, ACCOUNT_AUTHENTICATION_EXPIRED_ERR) {
  4299			return ErrAccountAuthExpired
  4300		}
  4301		return nil
  4302	}
```

### `processErr` — which `-ERR` closes, which reconnects, which is transient (`:4304–4338`)

```go
  4304	// processErr processes any error messages from the server and
  4305	// sets the connection's LastError.
  4306	func (nc *Conn) processErr(ie string) {
  4307		// Trim, remove quotes
  4308		ne := normalizeErr(ie)
  4309		// convert to lower case.
  4310		e := strings.ToLower(ne)
  4311	
  4312		var close bool
  4313	
  4314		// FIXME(dlc) - process Slow Consumer signals special.
  4315		if e == STALE_CONNECTION {
  4316			close = nc.processOpErr(ErrStaleConnection, false)
  4317		} else if e == MAX_CONNECTIONS_ERR {
  4318			close = nc.processOpErr(ErrMaxConnectionsExceeded, false)
  4319		} else if e == MAX_ACCOUNT_CONNECTIONS_ERR {
  4320			close = nc.processOpErr(ErrMaxAccountConnectionsExceeded, false)
  4321		} else if strings.HasPrefix(e, PERMISSIONS_ERR) {
  4322			nc.processTransientError(fmt.Errorf("%w: %s", ErrPermissionViolation, ne))
  4323		} else if strings.HasPrefix(e, MAX_SUBSCRIPTIONS_ERR) {
  4324			nc.processTransientError(ErrMaxSubscriptionsExceeded)
  4325		} else if authErr := checkAuthError(e); authErr != nil {
  4326			nc.mu.Lock()
  4327			close = nc.processAuthError(authErr)
  4328			nc.mu.Unlock()
  4329		} else {
  4330			close = true
  4331			nc.mu.Lock()
  4332			nc.err = errors.New("nats: " + ne)
  4333			nc.mu.Unlock()
  4334		}
  4335		if close {
  4336			nc.close(CLOSED, true, nil)
  4337		}
  4338	}
```

### `UserCredentials` — two callbacks, not a parsed file (`:1499–1515`)

```go
  1499	// UserCredentials is a convenience function that takes a filename
  1500	// for a user's JWT and a filename for the user's private Nkey seed.
  1501	func UserCredentials(userOrChainedFile string, seedFiles ...string) Option {
  1502		userCB := func() (string, error) {
  1503			return userFromFile(userOrChainedFile)
  1504		}
  1505		var keyFile string
  1506		if len(seedFiles) > 0 {
  1507			keyFile = seedFiles[0]
  1508		} else {
  1509			keyFile = userOrChainedFile
  1510		}
  1511		sigCB := func(nonce []byte) ([]byte, error) {
  1512			return sigHandler(nonce, keyFile)
  1513		}
  1514		return UserJWT(userCB, sigCB)
  1515	}
```

### `userFromFile` — the JWT is read from disk on every call (`:6743–6755`)

```go
  6743	func userFromFile(userFile string) (string, error) {
  6744		path, err := expandPath(userFile)
  6745		if err != nil {
  6746			return _EMPTY_, fmt.Errorf("nats: %w", err)
  6747		}
  6748	
  6749		contents, err := os.ReadFile(path)
  6750		if err != nil {
  6751			return _EMPTY_, fmt.Errorf("nats: %w", err)
  6752		}
  6753		defer wipeSlice(contents)
  6754		return nkeys.ParseDecoratedJWT(contents)
  6755	}
```

### `connectProto` — the callbacks run per attempt; `no_responders` follows `headers` (`:3068–3106`)

```go
  3068		// Look for user jwt.
  3069		if o.UserJWT != nil {
  3070			if jwt, err := o.UserJWT(); err != nil {
  3071				return _EMPTY_, err
  3072			} else {
  3073				ujwt = jwt
  3074			}
  3075			if nkey != _EMPTY_ {
  3076				return _EMPTY_, ErrNkeyAndUser
  3077			}
  3078		}
  3079	
  3080		if ujwt != _EMPTY_ || nkey != _EMPTY_ {
  3081			if o.SignatureCB == nil {
  3082				if ujwt == _EMPTY_ {
  3083					return _EMPTY_, ErrNkeyButNoSigCB
  3084				}
  3085				return _EMPTY_, ErrUserButNoSigCB
  3086			}
  3087			sigraw, err := o.SignatureCB([]byte(nc.info.Nonce))
  3088			if err != nil {
  3089				return _EMPTY_, fmt.Errorf("error signing nonce: %w", err)
  3090			}
  3091			sig = base64.RawURLEncoding.EncodeToString(sigraw)
  3092		}
  3093	
  3094		if nc.Opts.TokenHandler != nil {
  3095			if token != _EMPTY_ {
  3096				return _EMPTY_, ErrTokenAlreadySet
  3097			}
  3098			token = nc.Opts.TokenHandler()
  3099		}
  3100	
  3101		// If our server does not support headers then we can't do them or no responders.
  3102		hdrs := nc.info.Headers
  3103		cinfo := connectInfo{
  3104			o.Verbose, o.Pedantic, ujwt, nkey, sig, user, pass, token,
  3105			o.Secure, o.Name, LangString, Version, clientProtoInfo, !o.NoEcho, hdrs, hdrs,
  3106		}
```

### `Request` — the 503 becomes `ErrNoResponders` (`:4766–4781`)

```go
  4766	
  4767		var m *Msg
  4768		var err error
  4769	
  4770		if nc.useOldRequestStyle() {
  4771			m, err = nc.oldRequest(subj, hdr, data, timeout)
  4772		} else {
  4773			m, err = nc.newRequest(subj, hdr, data, timeout)
  4774		}
  4775	
  4776		// Check for no responder status.
  4777		if err == nil && len(m.Data) == 0 && m.Header.Get(statusHdr) == noResponders {
  4778			m, err = nil, ErrNoResponders
  4779		}
  4780		return m, err
  4781	}
```

