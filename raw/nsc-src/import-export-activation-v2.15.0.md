<!-- source: https://github.com/nats-io/nsc at tag v2.15.0 (the latest release on 2026-09-03; the three files are
     byte-identical to main that day), files cmd/addimport.go, cmd/addexport.go, cmd/generateactivation.go, from
     raw.githubusercontent.com · fetched 2026-09-03 -->
# nsc v2.15.0 — `add import --share` / `--token`, `add export --private` / `--account-token-position`, `generate activation`

Only the ranges this wiki quotes, with their real line numbers, so each links to
`https://github.com/nats-io/nsc/blob/v2.15.0/cmd/<file>#L<line>`. `nsc` is the tool that writes the fields
`raw/jwt-src/imports-exports-activation-v2.8.2.md` defines; `nats auth` v0.4.0 has `--share` but no
activation command (`raw/nats-cli/help-auth-account-exports-imports-0.4.0.md`).


## `nsc add import`


### `cmd/addimport.go` L30–L54 — the flags — `--token` for private imports, `--share` "share data when tracking latency (service only)"

```go
   30		var params AddImportParams
   31		cmd := &cobra.Command{
   32			Use:          "import",
   33			Short:        "Add an import",
   34			Args:         MaxArgs(0),
   35			Example:      params.longHelp(),
   36			SilenceUsage: true,
   37			RunE: func(cmd *cobra.Command, args []string) error {
   38				return RunAction(cmd, args, &params)
   39			},
   40		}
   41		cmd.Flags().StringVarP(&params.tokenSrc, "token", "u", "", "path to token file can be a local path or an url (private imports only)")
   42	
   43		cmd.Flags().StringVarP(&params.name, "name", "n", "", "import name")
   44		cmd.Flags().StringVarP(&params.local, "local-subject", "s", "", "local subject")
   45		params.srcAccount.BindFlags("src-account", "", nkeys.PrefixByteAccount, cmd)
   46		cmd.Flags().StringVarP(&params.remote, "remote-subject", "", "", "remote subject (only public imports)")
   47		cmd.Flags().BoolVarP(&params.service, "service", "", false, "service")
   48		cmd.Flags().BoolVarP(&params.share, "share", "", false, "share data when tracking latency (service only)")
   49		cmd.Flags().BoolVarP(&params.allowTrace, "allow-trace", "", false, "allow trace requests")
   50	
   51		params.AccountContextParams.BindFlags(cmd)
   52	
   53		return cmd
   54	}
```


### `cmd/addimport.go` L366–L396 — `initFromActivation` — a token fills in subject, type and source account; it must be intended for this account

```go
  366	func (p *AddImportParams) initFromActivation(_ ActionCtx) error {
  367		var err error
  368		if p.token == nil {
  369			p.token, err = p.loadImport()
  370			if err != nil {
  371				return err
  372			}
  373		}
  374	
  375		ac, err := jwt.DecodeActivationClaims(string(p.token))
  376		if err != nil {
  377			return err
  378		}
  379	
  380		if p.name == "" {
  381			p.name = ac.Name
  382		}
  383		p.remote = string(ac.ImportSubject)
  384		p.service = ac.ImportType == jwt.Service
  385		if p.service && p.local == "" {
  386			p.local = p.remote
  387		}
  388	
  389		p.srcAccount.publicKey = ac.Issuer
  390		if ac.IssuerAccount != "" {
  391			p.srcAccount.publicKey = ac.IssuerAccount
  392		}
  393		if ac.Subject != "public" && p.claim.Subject != ac.Subject {
  394			return fmt.Errorf("activation is not intended for this account - it is for %q", ac.Subject)
  395		}
  396		return nil
```


### `cmd/addimport.go` L477–L482 — `share` is refused on a stream import

```go
  477		kind := jwt.Stream
  478		if p.service {
  479			kind = jwt.Service
  480		} else if p.share {
  481			return fmt.Errorf("only services can set the share property")
  482		}
```


### `cmd/addimport.go` L542–L560 — `createImport` — `Share` only on a service; a URL token is stored by reference

```go
  542	func (p *AddImportParams) createImport() *jwt.Import {
  543		var im jwt.Import
  544		im.Name = p.name
  545		im.Subject = jwt.Subject(p.remote)
  546		im.LocalSubject = jwt.RenamingSubject(p.local)
  547		im.Account = p.srcAccount.publicKey
  548		im.Type = jwt.Stream
  549	
  550		if p.service {
  551			im.Type = jwt.Service
  552			im.Share = p.share
  553		} else if p.allowTrace {
  554			im.AllowTrace = true
  555		}
  556	
  557		if p.tokenSrc != "" {
  558			if IsURL(p.tokenSrc) {
  559				im.Token = p.tokenSrc
  560			}
```


## `nsc add export`


### `cmd/addexport.go` L40–L58 — the flags — `--private` "requires an activation to access", `--account-token-position` "(public exports only)"

```go
   40			},
   41		}
   42		cmd.Flags().StringVarP(&params.export.Name, "name", "n", "", "export name")
   43		cmd.Flags().StringVarP(&params.subject, "subject", "s", "", "subject")
   44		cmd.Flags().BoolVarP(&params.service, "service", "r", false, "export type service")
   45		cmd.Flags().BoolVarP(&params.private, "private", "p", false, "private export - requires an activation to access")
   46		cmd.Flags().StringVarP(&params.latSubject, "latency", "", "", "latency metrics subject (services only)")
   47		cmd.Flags().StringVarP(&params.latSampling, "sampling", "", "", "latency sampling percentage [1-100] or `header`  (services only)")
   48		cmd.Flags().DurationVarP(&params.responseThreshold, "response-threshold", "", 0, "response threshold duration (units ms/s/m/h) (services only)")
   49		hm := fmt.Sprintf("response type for the service [%s | %s | %s] (services only)", jwt.ResponseTypeSingleton, jwt.ResponseTypeStream, jwt.ResponseTypeChunked)
   50		cmd.Flags().StringVarP(&params.responseType, "response-type", "", jwt.ResponseTypeSingleton, hm)
   51		params.AccountContextParams.BindFlags(cmd)
   52	
   53		cmd.Flags().BoolVarP(&params.allowTrace, "allow-trace", "", false, "allow trace requests")
   54	
   55		cmd.Flags().UintVarP(&params.accountTokenPosition, "account-token-position", "", 0, "subject token position where account is expected (public exports only)")
   56		cmd.Flags().BoolVarP(&params.advertise, "advertise", "", false, "advertise export")
   57		cmd.Flag("advertise").Hidden = true
   58	
```


### `cmd/addexport.go` L96–L100 — `--private` becomes `TokenReq`

```go
   96	
   97		p.export.TokenReq = p.private
   98		p.export.AccountTokenPosition = p.accountTokenPosition
   99		p.export.Advertise = p.advertise
  100		p.export.Subject = jwt.Subject(p.subject)
```


### `cmd/addexport.go` L279–L281 — the two guards are mutually exclusive

```go
  279		if p.private && p.accountTokenPosition != 0 {
  280			return errors.New("account token position is only valid for public exports")
  281		}
```


### `cmd/addexport.go` L342–L356 — the report says public or private

```go
  342	func (p *AddExportParams) Run(ctx ActionCtx) (store.Status, error) {
  343		token, err := p.claim.Encode(p.signerKP)
  344		if err != nil {
  345			return nil, err
  346		}
  347	
  348		visibility := "public"
  349		if p.export.TokenReq {
  350			visibility = "private"
  351		}
  352		r := store.NewDetailedReport(false)
  353		StoreAccountAndUpdateStatus(ctx, token, r)
  354		if r.HasNoErrors() {
  355			r.AddOK("added %s %s export %q", visibility, p.export.Type, p.export.Name)
  356		}
```


## `nsc generate activation`


### `cmd/generateactivation.go` L30–L50 — the flags — `--subject`, `--target-account`, `--push`, the time flags

```go
   30		var params GenerateActivationParams
   31		cmd := &cobra.Command{
   32			Use:          "activation",
   33			Short:        "Generate an export activation jwt token",
   34			Args:         MaxArgs(0),
   35			SilenceUsage: true,
   36			RunE: func(cmd *cobra.Command, args []string) error {
   37				return RunAction(cmd, args, &params)
   38			},
   39		}
   40		cmd.Flags().StringVarP(&params.subject, "subject", "s", "", "export subject")
   41		cmd.Flags().StringVarP(&params.out, "output-file", "o", "--", "output file '--' is stdout")
   42		cmd.Flags().BoolVarP(&params.push, "push", "", false, "push activation token to operator's account server (exclusive of output-file")
   43		params.accountKey.BindFlags("target-account", "t", nkeys.PrefixByteAccount, cmd)
   44		params.timeParams.BindFlags(cmd)
   45		params.AccountContextParams.BindFlags(cmd)
   46	
   47		return cmd
   48	}
   49	
   50	func init() {
```


### `cmd/generateactivation.go` L215–L256 — the claim — `sub` = the target account, `nats.subject`, `nats.kind`, `nbf`/`exp`, `issuer_account` when a signing key signs

```go
  215		if err = p.SignerParams.Resolve(ctx); err != nil {
  216			return err
  217		}
  218		return nil
  219	}
  220	
  221	func (p *GenerateActivationParams) Run(ctx ActionCtx) (store.Status, error) {
  222		var err error
  223		p.activation = jwt.NewActivationClaims(p.accountKey.publicKey)
  224		p.activation.NotBefore, _ = p.timeParams.StartDate()
  225		p.activation.Expires, _ = p.timeParams.ExpiryDate()
  226		p.activation.Name = p.subject
  227		// p.subject is subset of the export
  228		p.activation.Activation.ImportSubject = jwt.Subject(p.subject)
  229		p.activation.Activation.ImportType = p.export.Type
  230	
  231		spub, err := p.signerKP.PublicKey()
  232		if err != nil {
  233			return nil, err
  234		}
  235		if p.claims.Subject != spub {
  236			p.activation.IssuerAccount = p.claims.Subject
  237		}
  238	
  239		p.token, err = p.activation.Encode(p.signerKP)
  240		if err != nil {
  241			return nil, err
  242		}
  243	
  244		d, err := jwt.DecorateJWT(p.token)
  245		if err != nil {
  246			return nil, err
  247		}
  248		r := store.NewDetailedReport(true)
  249		r.AddOK("generated %q activation for account %q", p.export.Name, p.accountKey.publicKey)
  250		if p.activation.NotBefore > 0 {
  251			r.AddOK("token valid %s - %s", UnixToDate(p.activation.NotBefore), HumanizedDate(p.activation.NotBefore))
  252		}
  253		if p.activation.Expires > 0 {
  254			r.AddOK("token expires %s - %s", UnixToDate(p.activation.Expires), HumanizedDate(p.activation.Expires))
  255		}
  256	
```
