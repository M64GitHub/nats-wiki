<!-- source: https://github.com/nats-io/nats.go at tag v1.53.1 (`js.go`, `jetstream/publish.go`) and https://github.com/nats-io/natscli at tag v0.4.0 (`cli/pub_command.go`), fetched from raw.githubusercontent.com · fetched 2026-09-04 -->
# nats.go v1.53.1 and natscli v0.4.0 — what a JetStream publish actually is

Extracted line ranges, verbatim, with their real line numbers at the tags
(`https://github.com/nats-io/nats.go/blob/v1.53.1/js.go#L<line>`,
`…/nats.go/blob/v1.53.1/jetstream/publish.go#L<line>`,
`https://github.com/nats-io/natscli/blob/v0.4.0/cli/pub_command.go#L<line>`). Read for step 7 of
`inbox/plan-the-client-side-2026-09-03.md`, to check `raw/adr/ADR-22.md` against the reference
implementation and to explain the error string run G of
`raw/nats-server-src/core-or-jetstream-observed-v2.14.6.md` captured.

What the ranges settle:

- ADR-22's stated defaults — `250ms`, 2 retries — are **still the defaults at v1.53.1**, in both the
  legacy `js.go` API and the newer `jetstream` package.
- The retry fires only on `ErrNoResponders`, and when it is exhausted the error the caller sees
  changes to `ErrNoStreamResponse` (`nats: no response from stream`). That difference is how you tell
  a client that retried from one that did not.
- `RetryAttempts(-1)` means "until the deadline": the loop condition is `r < o.retryAttempts ||
  o.retryAttempts < 0`.
- **`nats pub -J` does not use any of this.** natscli issues a plain `nc.RequestMsg` and parses the
  reply as a `PubAck`, which is why its failure is `nats: no responders available for request` with no
  retry — and which is also the clearest statement anywhere that a JetStream publish *is* a core
  request.

---

## `nats.go` v1.53.1 · `js.go` — the legacy JetStream API

### 228-240 · the publish retry defaults, beside the async in-flight window

```go
  228		// routine. Without this, the subscription would possibly stall until
  229		// a new message or heartbeat/fc are received.
  230		chanSubFCCheckInterval = 250 * time.Millisecond
  231	
  232		// Default time wait between retries on Publish iff err is NoResponders.
  233		DefaultPubRetryWait = 250 * time.Millisecond
  234	
  235		// Default number of retries
  236		DefaultPubRetryAttempts = 2
  237	
  238		// defaultAsyncPubAckInflight is the number of async pub acks inflight.
  239		defaultAsyncPubAckInflight = 4000
  240	)
```

### 540-545 · the defaults become the per-publish options

```go
  540	
  541	// PublishMsg publishes a Msg to a stream from JetStream.
  542	func (js *js) PublishMsg(m *Msg, opts ...PubOpt) (*PubAck, error) {
  543		var o = pubOpts{rwait: DefaultPubRetryWait, rnum: DefaultPubRetryAttempts}
  544		if len(opts) > 0 {
  545			if m.Header == nil {
```

### 586-620 · the retry loop and the error it turns into

```go
  586	
  587		if o.ttl > 0 {
  588			resp, err = js.nc.RequestMsg(m, time.Duration(o.ttl))
  589		} else {
  590			resp, err = js.nc.RequestMsgWithContext(o.ctx, m)
  591		}
  592	
  593		if err != nil {
  594			for r, ttl := 0, o.ttl; errors.Is(err, ErrNoResponders) && (r < o.rnum || o.rnum < 0); r++ {
  595				// To protect against small blips in leadership changes etc, if we get a no responders here retry.
  596				if o.ctx != nil {
  597					select {
  598					case <-o.ctx.Done():
  599					case <-time.After(o.rwait):
  600					}
  601				} else {
  602					time.Sleep(o.rwait)
  603				}
  604				if o.ttl > 0 {
  605					ttl -= o.rwait
  606					if ttl <= 0 {
  607						err = ErrTimeout
  608						break
  609					}
  610					resp, err = js.nc.RequestMsg(m, time.Duration(ttl))
  611				} else {
  612					resp, err = js.nc.RequestMsgWithContext(o.ctx, m)
  613				}
  614			}
  615			if err != nil {
  616				if errors.Is(err, ErrNoResponders) {
  617					err = ErrNoStreamResponse
  618				}
  619				return nil, err
  620			}
```

### 1203-1220 · the two options ADR-22 asked for

```go
 1203	}
 1204	
 1205	// RetryWait sets the retry wait time when ErrNoResponders is encountered.
 1206	func RetryWait(dur time.Duration) PubOpt {
 1207		return pubOptFn(func(opts *pubOpts) error {
 1208			opts.rwait = dur
 1209			return nil
 1210		})
 1211	}
 1212	
 1213	// RetryAttempts sets the retry number of attempts when ErrNoResponders is encountered.
 1214	func RetryAttempts(num int) PubOpt {
 1215		return pubOptFn(func(opts *pubOpts) error {
 1216			opts.rnum = num
 1217			return nil
 1218		})
 1219	}
 1220	
```

---

## `nats.go` v1.53.1 · `jetstream/publish.go` — the newer API

### 154-162 · the same two defaults

```go
  154	
  155	const (
  156		// Default time wait between retries on Publish if err is ErrNoResponders.
  157		DefaultPubRetryWait = 250 * time.Millisecond
  158	
  159		// Default number of retries
  160		DefaultPubRetryAttempts = 2
  161	)
  162	
```

### 240-262 · the same loop, the same terminal error

```go
  240	
  241		var resp *nats.Msg
  242		var err error
  243	
  244		resp, err = js.conn.RequestMsgWithContext(ctx, m)
  245	
  246		if err != nil {
  247			for r := 0; errors.Is(err, nats.ErrNoResponders) && (r < o.retryAttempts || o.retryAttempts < 0); r++ {
  248				// To protect against small blips in leadership changes etc, if we get a no responders here retry.
  249				select {
  250				case <-ctx.Done():
  251				case <-time.After(o.retryWait):
  252				}
  253				resp, err = js.conn.RequestMsgWithContext(ctx, m)
  254			}
  255			if err != nil {
  256				if errors.Is(err, nats.ErrNoResponders) {
  257					return nil, ErrNoStreamResponse
  258				}
  259				return nil, err
  260			}
  261		}
  262	
```

---

## `natscli` v0.4.0 · `cli/pub_command.go` — what `nats pub -J` really does

### 253-290 · a core request, parsed as a PubAck

```go
  253	func (c *pubCmd) doJetstream(nc *nats.Conn, pub *iu.Publisher) error {
  254		for i := 1; i <= c.cnt; i++ {
  255			start := time.Now()
  256			body, subj, bodyErr, subjErr := pub.ParseTemplates(c.body, c.subject, i)
  257			if bodyErr != nil {
  258				log.Printf("Could not parse body template: %s", bodyErr)
  259			}
  260			if subjErr != nil {
  261				log.Printf("Could not parse subject template: %s", subjErr)
  262			}
  263	
  264			msg, err := pub.PrepareMsg(subj, c.replyTo, []byte(body), c.hdrs, i)
  265			if err != nil {
  266				return err
  267			}
  268	
  269			if c.schedules {
  270				err = c.addScheduleHeaders(msg)
  271				if err != nil {
  272					return err
  273				}
  274			}
  275	
  276			if !c.quiet {
  277				log.Printf("Published %d bytes to %q\n", len(body), subj)
  278			}
  279			resp, err := nc.RequestMsg(msg, opts().Timeout)
  280			if err != nil {
  281				return err
  282			}
  283	
  284			ack, err := jsm.ParsePubAck(resp)
  285			if err != nil {
  286				return err
  287			}
  288	
  289			if opts().Trace {
  290				fmt.Printf("<<< %+v\n", string(resp.Data))
```

Two things an operator can see follow from this range:

1. `log.Printf("Published %d bytes to %q\n", …)` at **277** runs *before* `nc.RequestMsg` at **279**,
   so `nats pub -J` prints `Published …` for a publish that then fails. Both lines appear together in
   every failing run in `core-or-jetstream-observed-v2.14.6.md`.
2. There is no `js.Publish`, no `RetryWait` and no `RetryAttempts` anywhere on this path. The CLI is
   not a resilient JetStream publisher and does not claim to be.
