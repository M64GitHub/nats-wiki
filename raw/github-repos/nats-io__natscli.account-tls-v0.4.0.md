<!-- source: https://github.com/nats-io/natscli at tag v0.4.0, files cli/account_tls_command.go
     and cli/account_command.go · fetched 2026-08-31 -->
# natscli v0.4.0 — `nats account tls` and `nats account backup` / `restore`

Only the ranges this wiki quotes are stored, with their real line numbers, so each value links to
`https://github.com/nats-io/natscli/blob/v0.4.0/cli/<file>#L<line>`.

## `nats account tls` — the certificate-chain report

### `cli/account_tls_command.go` L39–L48 — the command, its flags and their defaults

```go
   39	func configureAccountTLSCommand(srv *fisk.CmdClause) {
   40		c := &ActTLSCmd{}
   41	
   42		tls := srv.Command("tls", "Report TLS chain for connected server").Action(c.showTLS)
   43		tls.Tag("scope:user", "impact:ro")
   44		tls.Flag("expire-warn", "Warn about certs expiring this soon, 0 to disable").Default("1w").DurationVar(&c.expireWarnDuration)
   45		tls.Flag("ocsp", "Report OCSP information, if any").UnNegatableBoolVar(&c.wantOCSP)
   46		tls.Flag("pem", "Show PEM Certificate blocks (true)").Default("true").BoolVar(&c.wantPEM)
   47	
   48		// TODO: consider NAGIOS-compatible option (output format, exit statuses)
```

### `cli/account_tls_command.go` L50–L92 — showTLS — the chain comes from the client's own NATS connection

```go
   50	
   51	func (c *ActTLSCmd) showTLS(_ *fisk.ParseContext) error {
   52		c.now = time.Now()
   53		if c.expireWarnDuration > 0 {
   54			c.warnIfBefore = c.now.Add(c.expireWarnDuration)
   55		}
   56	
   57		nc, _, err := prepareHelper("", natsOpts()...)
   58		if err != nil {
   59			return err
   60		}
   61	
   62		t, err := nc.TLSConnectionState()
   63		if err != nil {
   64			return err
   65		}
   66	
   67		var showingOCSP bool
   68		if c.wantOCSP {
   69			if len(t.OCSPResponse) > 0 {
   70				showingOCSP = true
   71			} else {
   72				fmt.Printf("# No OCSP Response found in TLS connection\n\n")
   73			}
   74		}
   75	
   76		fmt.Printf("# TLS Verified Chains count: %d\n", len(t.VerifiedChains))
   77		if len(t.VerifiedChains) < 1 {
   78			return fmt.Errorf("no verified chains found in TLS")
   79		}
   80	
   81		err = nil
   82		for i := range t.VerifiedChains {
   83			fmt.Printf("\n# chain: %d\n", i+1)
   84			if chainErr := c.showOneTLSChain(t.VerifiedChains[i], i+1); chainErr != nil && err == nil {
   85				err = chainErr
   86			}
   87			if showingOCSP {
   88				if ocspErr := c.showOneOCSP(t.VerifiedChains[i], i+1, t); ocspErr != nil && err == nil {
   89					err = ocspErr
   90				}
   91			}
   92		}
```

### `cli/account_tls_command.go` L94–L133 — showOneTLSChain — the expiry checks, the error return, and the stable grep pattern

```go
   94	}
   95	
   96	func (c *ActTLSCmd) showOneTLSChain(chain []*x509.Certificate, chain_number int) error {
   97		var err error
   98		for ci, cert := range chain {
   99			fmt.Printf("# chain=%d cert=%d isCA=%v Subject=%q\n", chain_number, ci+1, cert.IsCA, cert.Subject.String())
  100			if cert.NotAfter.Before(c.now) {
  101				// I don't think this should happen because we're for verified chains, but protect against being called on an unverified chain.
  102				fmt.Printf("# EXPIRED after %v\n", cert.NotAfter)
  103				if err == nil {
  104					err = fmt.Errorf("expired cert chain=%d cert=%d expiration=%q subject=%q", chain_number, ci+1, cert.NotAfter, cert.Subject.String())
  105				}
  106			} else if cert.NotAfter.Before(c.warnIfBefore) {
  107				fmt.Printf("# EXPIRING SOON: within %v of %v\n", c.expireWarnDuration, cert.NotAfter)
  108				if err == nil {
  109					err = fmt.Errorf("cert expiring soon chain=%d cert=%d expiration=%q subject=%q", chain_number, ci+1, cert.NotAfter, cert.Subject.String())
  110				}
  111			}
  112			// Always show expiration in this form, even if already shown, to have a stable grep pattern
  113			fmt.Printf("#   Expiration: %s\n", cert.NotAfter)
  114			if len(cert.DNSNames) > 0 {
  115				fmt.Printf("#   SAN: DNS Names: %v\n", cert.DNSNames)
  116			}
  117			if len(cert.IPAddresses) > 0 {
  118				fmt.Printf("#   SAN: IP Addresses: %v\n", cert.IPAddresses)
  119			}
  120			if len(cert.URIs) > 0 {
  121				fmt.Printf("#   SAN: URIs: %v\n", cert.URIs)
  122			}
  123			if len(cert.EmailAddresses) > 0 {
  124				fmt.Printf("#   SAN: Email Addresses: %v\n", cert.EmailAddresses)
  125			}
  126			fmt.Printf("#   Serial: %v\n#   Signed-with: %v\n", cert.SerialNumber, cert.SignatureAlgorithm)
  127			if c.wantPEM {
  128				pem.Encode(os.Stdout, &pem.Block{
  129					Type:  "CERTIFICATE",
  130					Bytes: cert.Raw,
  131				})
  132			}
  133		}
```

## `nats account backup` / `nats account restore`

### `cli/account_command.go` L58–L100 — every account subcommand and flag at v0.4.0

```go
   58	func configureActCommand(app commandHost) {
   59		c := &actCmd{}
   60		act := app.Command("account", "Account information and status").Alias("a")
   61		addCheat("account", act)
   62	
   63		info := act.Command("info", "Account information").Alias("nfo").Action(c.infoAction)
   64		info.Tag("scope:user", "impact:ro")
   65	
   66		report := act.Command("report", "Report on account metrics").Alias("rep")
   67		report.Tag("scope:user", "impact:ro")
   68	
   69		conns := report.Command("connections", "Report on connections").Alias("conn").Alias("connz").Alias("conns").Action(c.reportConnectionsAction)
   70		conns.Tag("scope:user", "impact:ro")
   71		conns.Flag("sort", "Sort by a specific property (in-bytes,out-bytes,in-msgs,out-msgs,uptime,cid,subs)").Default("subs").EnumVar(&c.sort, "in-bytes", "out-bytes", "in-msgs", "out-msgs", "uptime", "cid", "subs")
   72		conns.Flag("top", "Limit results to the top results").Default("1000").IntVar(&c.topk)
   73		conns.Flag("subject", "Limits responses only to those connections with matching subscription interest").StringVar(&c.subject)
   74		conns.Flag("username", "Limits responses only to those connections for a specific authentication username").StringVar(&c.user)
   75		conns.Flag("reverse", "Reverse sort connections").Short('R').UnNegatableBoolVar(&c.reverse)
   76		conns.Flag("state", "Limits responses only to those connections that are in a specific state (open, closed, all)").Default("open").EnumVar(&c.stateFilter, "open", "closed", "all")
   77		conns.Flag("closed-reason", "Filter results based on a closed reason").PlaceHolder("REASON").StringVar(&c.filterReason)
   78	
   79		stats := report.Command("statistics", "Report on server statistics").Alias("stats").Alias("statsz").Action(c.reportServerStats)
   80		stats.Tag("scope:user", "impact:ro")
   81	
   82		backup := act.Command("backup", "Creates a backup of all  JetStream Streams over the NATS network").Alias("snapshot").Action(c.backupAction)
   83		backup.Tag("scope:user", "impact:ro")
   84		backup.Arg("target", "Directory to create the backup in").Required().StringVar(&c.backupDirectory)
   85		backup.Flag("check", "Checks the Stream for health prior to backup").UnNegatableBoolVar(&c.healthCheck)
   86		backup.Flag("consumers", "Enable or disable consumer backups").Default("true").BoolVar(&c.snapShotConsumers)
   87		backup.Flag("force", "Perform backup without prompting").Short('f').UnNegatableBoolVar(&c.force)
   88		backup.Flag("critical-warnings", "Treat warnings as failures").Short('w').UnNegatableBoolVar(&c.failOnWarn)
   89	
   90		restore := act.Command("restore", "Restore an account backup over the NATS network").Action(c.restoreAction)
   91		restore.Tag("scope:user", "impact:rw")
   92		restore.Arg("directory", "The directory holding the account backup to restore").Required().ExistingDirVar(&c.backupDirectory)
   93		restore.Flag("cluster", "Place the stream in a specific cluster").StringVar(&c.placementCluster)
   94		restore.Flag("tag", "Place the stream on servers that has specific tags (pass multiple times)").StringsVar(&c.placementTags)
   95	
   96		configureAccountTLSCommand(act)
   97	}
   98	
   99	func init() {
  100		registerCommand("account", 0, configureActCommand)
```
