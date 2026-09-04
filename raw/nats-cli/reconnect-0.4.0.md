<!-- source: natscli v0.4.0 from the Go module cache ($(go env GOMODCACHE)/github.com/nats-io/natscli@v0.4.0), the tag the installed `nats` 0.4.0 was built from · read 2026-09-04 -->
# `nats` CLI 0.4.0 — the connection it opens, and the reconnect policy it overrides

Extracted line ranges, verbatim, with their real line numbers at the version
(`https://github.com/nats-io/natscli/blob/v0.4.0/<path>#L<line>`). Read for step 3 of
`inbox/plan-the-client-side-2026-09-03.md`. The CLI is the tool an operator watches a failover
with, so what it does differently from a stock `nats.go` connection is part of every observation
made with it. Its `go.mod` pins **nats.go v1.51.0** (`go.mod:25`); the client values this wiki
quotes are read at **v1.53.1** in `raw/nats-go-src/connection-v1.53.1.md`, and the two constants
this file depends on (`MaxReconnects`, the custom delay) are set by the CLI itself, not defaulted.

What the ranges settle:

- the CLI reconnects **forever** (`MaxReconnects(-1)`) and **never aborts on a repeated auth
  error** (`IgnoreAuthErrorAbort()`) — two deliberate departures from the library defaults, so a
  `nats sub` left running is not a witness for what an application would do;
- its `CustomReconnectDelay` replaces nats.go's 2 s wait + jitter with a **44-step table from
  500 ms to 20 s**, each step randomised to **half to one-and-a-half** times its value;
- the six `>>>` lines and which of them need `--trace`: the **disconnect** line and the **closed**
  line print always, the rest are trace-gated;
- the async error handler is registered **twice**, and the second registration (trace-gated) is the
  one that survives — so `>>> Unexpected NATS error` never prints without `--trace`, and a
  client-side slow consumer under `nats sub` is silent;
- the closed handler is a `log.Fatalf` fired **one second later**, so the CLI exits on a closed
  connection;
- `nats reply` on Ctrl-C calls `Drain()` and then `log.Fatalf("Exiting")` immediately — `Drain()`
  in nats.go returns at once, so the process dies while its own drain is still running;
- `nats rtt` does five round trips by default.

### `natsOpts()` — every connection option the `nats` CLI sets, and the six `>>>` lines

`cli/util.go:230–294`

```go
   230	func natsOpts() []nats.Option {
   231		var copts []nats.Option
   232		var err error
   233	
   234		if opts().Config != nil {
   235			copts, err = opts().Config.NATSOptions()
   236			fisk.FatalIfError(err, "configuration error")
   237		}
   238	
   239		connectionName := strings.TrimSpace(opts().ConnectionName)
   240		if len(connectionName) == 0 {
   241			connectionName = "NATS CLI Version " + Version
   242		}
   243	
   244		return append(copts, []nats.Option{
   245			nats.Name(connectionName),
   246			nats.MaxReconnects(-1),
   247			nats.IgnoreAuthErrorAbort(),
   248			nats.CustomReconnectDelay(func(attempts int) time.Duration {
   249				d := iu.DefaultBackoff.Duration(attempts)
   250	
   251				if opts().Trace {
   252					log.Printf(">>> Setting reconnect delay to %v", d)
   253				}
   254	
   255				return d
   256			}),
   257			nats.ConnectHandler(func(conn *nats.Conn) {
   258				if opts().Trace {
   259					log.Printf(">>> Connected to %s (%s)", conn.ConnectedUrlRedacted(), conn.ConnectedAddr())
   260				}
   261			}),
   262			nats.DiscoveredServersHandler(func(conn *nats.Conn) {
   263				if opts().Trace {
   264					log.Printf(">>> Discovered new servers, known servers are now %s", strings.Join(conn.Servers(), ", "))
   265				}
   266			}),
   267			nats.DisconnectErrHandler(func(nc *nats.Conn, err error) {
   268				if err != nil {
   269					log.Printf(">>> Disconnected due to: %s, will attempt reconnect", err)
   270				}
   271			}),
   272			nats.ReconnectHandler(func(nc *nats.Conn) {
   273				if opts().Trace {
   274					log.Printf(">>> Reconnected to %s (%s)", nc.ConnectedUrlRedacted(), nc.ConnectedAddr())
   275				}
   276			}),
   277			nats.ClosedHandler(func(nc *nats.Conn) {
   278				time.AfterFunc(time.Second, func() { log.Fatalf(">>> Connection is closed: %v", nc.LastError()) })
   279			}),
   280			nats.ErrorHandler(func(nc *nats.Conn, _ *nats.Subscription, err error) {
   281				log.Printf(">>> Unexpected NATS error: %s", err)
   282			}),
   283			nats.ReconnectErrHandler(func(conn *nats.Conn, err error) {
   284				if opts().Trace {
   285					log.Printf(">>> Reconnect error: %s", err)
   286				}
   287			}),
   288			nats.ErrorHandler(func(nc *nats.Conn, _ *nats.Subscription, err error) {
   289				if opts().Trace {
   290					log.Printf(">>> Unexpected NATS error: %s", err)
   291				}
   292			}),
   293		}...)
   294	}
```

### `DefaultBackoff` — the 44-step table the CLI reconnects on

`internal/util/backoff.go:30–48`

```go
    30	// DefaultBackoff is the default backoff policy to use
    31	var DefaultBackoff = BackoffPolicy{
    32		Millis: []int{
    33			500, 750, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000,
    34			5500, 5750, 6000, 6500, 7000, 7500, 8000, 8500, 9000, 9500, 10000,
    35			10500, 10750, 11000, 11500, 12000, 12500, 13000, 13500, 14000, 14500, 15000,
    36			15500, 15750, 16000, 16500, 17000, 17500, 18000, 18500, 19000, 19500, 20000,
    37		},
    38	}
    39	
    40	// Duration returns the time duration of the n'th wait cycle in a
    41	// backoff policy. This is b.Millis[n], randomized to avoid thundering
    42	// herds.
    43	func (b BackoffPolicy) Duration(n int) time.Duration {
    44		if n >= len(b.Millis) {
    45			n = len(b.Millis) - 1
    46		}
    47	
    48		return time.Duration(jitter(b.Millis[n])) * time.Millisecond
```

### `jitter()` — half to one-and-a-half times the step

`internal/util/backoff.go:95–103`

```go
    95	// jitter returns a random integer uniformly distributed in the range
    96	// [0.5 * millis .. 1.5 * millis]
    97	func jitter(millis int) int {
    98		if millis == 0 {
    99			return 0
   100		}
   101	
   102		return millis/2 + rand.N(millis)
   103	}
```

### `nats reply` on Ctrl-C: `Drain()` then `log.Fatalf` — it does not wait

`cli/reply_command.go:220–229`

```go
   220	
   221		log.Printf("Listening on %q in group %q", c.subject, c.queue)
   222	
   223		signal.Notify(ic, os.Interrupt)
   224		<-ic
   225	
   226		log.Printf("\nDraining...")
   227		nc.Drain()
   228		log.Fatalf("Exiting")
   229	
```

### `nats rtt` — five round trips by default

`cli/rtt_command.go:52–54`

```go
    52		rtt := app.Command("rtt", "Compute round-trip time to NATS server").Action(c.rtt)
    53		rtt.Tag("scope:user", "impact:rw")
    54		rtt.Arg("iterations", "How many round trips to do when testing").Default("5").IntVar(&c.iterations)
```

