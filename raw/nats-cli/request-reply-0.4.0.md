<!-- source: https://github.com/nats-io/natscli at tag v0.4.0 — cli/req_command.go and cli/reply_command.go, read from the Go module cache (`$(go env GOMODCACHE)/github.com/nats-io/natscli@v0.4.0/`, the published module of the tag; its go.mod pins nats.go v1.51.0) on 2026-09-03 -->
# natscli v0.4.0 — `nats request` and `nats reply`: the gather loop, the two exit paths, the reply handler

Verbatim line ranges with their real line numbers, for the observed runs in `raw/nats-server-src/request-reply-observed-v2.14.6.md`; the `--help` texts are in `help-core-0.4.0.md`. What the ranges settle: a request is a sync subscription on `nc.NewRespInbox()` (the connection's shared `_INBOX.<nuid>.*` mux); `--replies N` ends on the N-th reply **or on any reply with an empty body**; `--wait-for-empty` only sets `--replies` to 32767; with `--replies 0` the wait is the remaining `--timeout` and `--reply-timeout` is not read; with `--replies N` each further wait is the average reply time so far plus `--reply-timeout`; no responders prints `No responders are available` and returns `nil` (**exit 0**); a timeout `break`s out silently and returns `nil` (**exit 0**). `nats reply` is one `QueueSubscribe` callback — nats.go runs a subscription's callbacks one at a time — so `--sleep` (random up to the maximum) and `--command` (run synchronously, its combined output becoming the reply body, empty output an empty reply) hold every later request on that member.

## cli/req_command.go — the flags

```go
   79		req.Flag("count", "Publish multiple messages").Default("1").IntVar(&c.cnt)
   80		req.Flag("replies", "Wait for multiple replies from services. 0 waits until timeout").Default("1").IntVar(&c.replyCount)
   81		req.Flag("reply-timeout", "Maximum time between replies when waiting for more than one").Default("300ms").DurationVar(&c.replyTimeout)
   82		req.Flag("wait-for-empty", "Wait for multiple replies until a empty message is received").UnNegatableBoolVar(&c.terminateOnEmpty)
```

## cli/req_command.go — the gather loop and its exits

```go
  108			msg, err := pub.PrepareMsg(subj, c.replyTo, []byte(body), c.hdrs, i)
  109			if err != nil {
  110				return err
  111			}
  112	
  113			msg.Reply = nc.NewRespInbox()
  114	
  115			s, err := nc.SubscribeSync(msg.Reply)
  116			if err != nil {
  117				return err
  118			}
  119	
  120			err = nc.PublishMsg(msg)
  121			if err != nil {
  122				return err
  123			}
  124	
  125			if pub.Tracker != nil {
  126				pub.Tracker.Increment(1)
  127			}
  128	
  129			// loop through the reply count.
  130			start := time.Now()
  131	
  132			// Honor the overall timeout for the first response.  No
  133			// responders will circuit break.
  134			timeout := opts().Timeout
  135	
  136			// loop until reply count is met, or if zero, until we
  137			// timeout receiving messages.
  138			rc := 0
  139			var rttAg time.Duration
  140			for {
  141				m, err := s.NextMsg(timeout)
  142				if err != nil {
  143					if err == nats.ErrTimeout {
  144						// continue to publish additional messages.
  145						break
  146					}
  147					if err == nats.ErrNoResponders {
  148						log.Printf("No responders are available")
  149						return nil
  150					}
  151					return err
  152				}
  153	
  154				rtt := time.Since(start)
  155	
  156				switch {
  157				case c.raw:
  158					outPutMSGBody(m.Data, c.translate, m.Subject, "")
  159				case logOutput:
  160					log.Printf("Received with rtt %v", rtt)
  161	
  162					if len(m.Header) > 0 {
  163						for h, vals := range m.Header {
  164							for _, val := range vals {
  165								log.Printf("%s: %s", h, val)
  166							}
  167						}
  168						log.Println()
  169					}
  170	
  171					outPutMSGBody(m.Data, c.translate, m.Subject, "")
  172				}
  173	
  174				rc++
  175				if c.replyCount > 0 && rc == c.replyCount {
  176					break
  177				}
  178	
  179				if c.replyCount > 0 && len(m.Data) == 0 {
  180					break
  181				}
  182	
  183				if c.replyCount == 0 {
  184					// if we are waiting for the general timeout then
  185					// calculate remaining
  186					timeout = opts().Timeout - time.Since(start)
  187				} else {
  188					// Otherwise, use the average response deltas
  189					rttAg += rtt
  190					timeout = rttAg/time.Duration(rc) + c.replyTimeout
  191				}
  192			}
  193	
  194			// Unsubscribe for the unbound case, NOOP is already auto unsubscribed.
  195			s.Unsubscribe()
  196	
  197			// If applicable, account for the wait duration in a publish sleep.
  198			if c.cnt > 1 && c.sleep > 0 {
  199				st := c.sleep - time.Since(start)
  200				if st > 0 {
  201					time.Sleep(st)
  202				}
  203			}
  204		}
  205		return nil
```

## cli/req_command.go — `--wait-for-empty` is `--replies 32767`

```go
  218		if c.cnt < 1 {
  219			c.cnt = math.MaxInt16
  220		}
  221	
  222		if c.terminateOnEmpty {
  223			c.replyCount = math.MaxInt16
  224		}
```

## cli/reply_command.go — the flags, echo mode, the handler

```go
   88		act.Flag("echo", "Echo back what is received").UnNegatableBoolVar(&c.echo)
   89		act.Flag("command", "Runs a command and responds with the output if exit code was 0").StringVar(&c.command)
   90		act.Flag("queue", "Queue group name").Default("NATS-RPLY-22").Short('q').StringVar(&c.queue)
   91		act.Flag("sleep", "Inject a random sleep delay between replies up to this duration max").PlaceHolder("MAX").DurationVar(&c.sleep)
```

```go
  106		if c.body == "" && c.command == "" && !c.echo {
  107			log.Println("No body or command supplied, enabling echo mode")
  108			c.echo = true
```

```go
  114		sub, _ := nc.QueueSubscribe(c.subject, c.queue, func(m *nats.Msg) {
  115			log.Printf("[#%d] Received on subject %q:", i, m.Subject)
  116			for h, vals := range m.Header {
  117				for _, val := range vals {
  118					log.Printf("%s: %s", h, val)
  119				}
  120			}
  121	
  122			fmt.Println()
  123			fmt.Println(string(m.Data))
  124	
  125			if c.sleep != 0 {
  126				time.Sleep(time.Duration(rand.Intn(int(c.sleep))))
  127			}
```

```go
  137			switch {
  138			case c.echo:
  139				if nc.HeadersSupported() {
  140					for h, vals := range m.Header {
  141						for _, v := range vals {
  142							msg.Header.Add(h, v)
  143						}
  144					}
  145	
  146					msg.Header.Add("NATS-Reply-Counter", strconv.Itoa(i))
  147				}
  148	
  149				msg.Data = m.Data
  150	
  151			case c.command != "":
  152				rawCmd := c.command
  153				tokens := strings.Split(m.Subject, ".")
  154	
  155				for i, t := range tokens {
  156					rawCmd = strings.Replace(rawCmd, fmt.Sprintf("{{%d}}", i), t, -1)
  157				}
  158	
  159				parsedCmd, err := iu.PubReplyBodyTemplate(rawCmd, string(m.Data), i)
  160				if err != nil {
  161					log.Printf("Could not parse command template: %s", err)
  162				}
  163				rawCmd = string(parsedCmd)
  164	
  165				cmdParts, err := shellquote.Split(rawCmd)
  166				if err != nil {
  167					log.Printf("Could not parse command: %s", err)
  168					return
  169				}
  170	
  171				args := []string{}
  172				if len(cmdParts) > 1 {
  173					args = cmdParts[1:]
  174				}
  175	
  176				if opts().Trace {
  177					log.Printf("Executing: %s", strings.Join(cmdParts, " "))
  178				}
  179	
  180				cmd := exec.Command(cmdParts[0], args...)
  181				cmd.Env = os.Environ()
  182				cmd.Env = append(cmd.Env, fmt.Sprintf("NATS_REQUEST_SUBJECT=%s", m.Subject))
  183				cmd.Env = append(cmd.Env, fmt.Sprintf("NATS_REQUEST_BODY=%s", string(m.Data)))
  184				msg.Data, err = cmd.CombinedOutput()
  185				if err != nil {
  186					log.Printf("Command %q failed to run: %s", rawCmd, err)
  187				}
  188	
  189			default:
  190				body, err := iu.PubReplyBodyTemplate(c.body, string(m.Data), i)
  191				if err != nil {
  192					log.Printf("Could not parse body template: %s", err)
  193				}
  194	
  195				msg.Data = body
  196			}
  197	
  198			err = m.RespondMsg(msg)
  199			if err != nil {
  200				log.Printf("Could not publish reply: %s", err)
```
