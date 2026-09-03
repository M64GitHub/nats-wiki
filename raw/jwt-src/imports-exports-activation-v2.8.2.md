<!-- source: https://github.com/nats-io/jwt at tag v2.8.2 (the version nats-server v2.14.6's go.mod pins), files
     v2/imports.go, v2/exports.go, v2/activation_claims.go, from raw.githubusercontent.com · fetched 2026-09-03 -->
# jwt v2.8.2 — `Import.Share`, `Export.TokenReq`, `AccountTokenPosition`, and the activation claim

Only the ranges this wiki quotes, with their real line numbers, so each links to
`https://github.com/nats-io/jwt/blob/v2.8.2/v2/<file>#L<line>`. This is the library that defines the account
JWT the server reads: an import's `share` and `token`, an export's `token_req`, `revocations` and
`account_token_position`, and the activation JWT an exporting account issues to one importer.


## Imports


### `v2/imports.go` L17–L43 — the `Import` struct — `Token`, `Share` (JSON `share`), `AllowTrace`

```go
   17	
   18	// Import describes a mapping from another account into this one
   19	type Import struct {
   20		Name string `json:"name,omitempty"`
   21		// Subject field in an import is always from the perspective of the
   22		// initial publisher - in the case of a stream it is the account owning
   23		// the stream (the exporter), and in the case of a service it is the
   24		// account making the request (the importer).
   25		Subject Subject `json:"subject,omitempty"`
   26		Account string  `json:"account,omitempty"`
   27		Token   string  `json:"token,omitempty"`
   28		// Deprecated: use LocalSubject instead
   29		// To field in an import is always from the perspective of the subscriber
   30		// in the case of a stream it is the client of the stream (the importer),
   31		// from the perspective of a service, it is the subscription waiting for
   32		// requests (the exporter). If the field is empty, it will default to the
   33		// value in the Subject field.
   34		To Subject `json:"to,omitempty"`
   35		// Local subject used to subscribe (for streams) and publish (for services) to.
   36		// This value only needs setting if you want to change the value of Subject.
   37		// If the value of Subject ends in > then LocalSubject needs to end in > as well.
   38		// LocalSubject can contain $<number> wildcard references where number references the nth wildcard in Subject.
   39		// The sum of wildcard reference and * tokens needs to match the number of * token in Subject.
   40		LocalSubject RenamingSubject `json:"local_subject,omitempty"`
   41		Type         ExportType      `json:"type,omitempty"`
   42		Share        bool            `json:"share,omitempty"`
   43		AllowTrace   bool            `json:"allow_trace,omitempty"`
```


### `v2/imports.go` L58–L113 — `Import.Validate` — `share` is for services only; the activation token must match account, target, type and subject

```go
   58		return string(i.To)
   59	}
   60	
   61	// Validate checks if an import is valid for the wrapping account
   62	func (i *Import) Validate(actPubKey string, vr *ValidationResults) {
   63		if i == nil {
   64			vr.AddError("null import is not allowed")
   65			return
   66		}
   67		if !i.IsService() && !i.IsStream() {
   68			vr.AddError("invalid import type: %q", i.Type)
   69		}
   70		if i.IsService() && i.AllowTrace {
   71			vr.AddError("AllowTrace only valid for stream import")
   72		}
   73	
   74		if i.Account == "" {
   75			vr.AddError("account to import from is not specified")
   76		}
   77	
   78		if i.GetTo() != "" {
   79			vr.AddWarning("the field to has been deprecated (use LocalSubject instead)")
   80		}
   81	
   82		i.Subject.Validate(vr)
   83		if i.LocalSubject != "" {
   84			i.LocalSubject.Validate(i.Subject, vr)
   85			if i.To != "" {
   86				vr.AddError("Local Subject replaces To")
   87			}
   88		}
   89	
   90		if i.Share && !i.IsService() {
   91			vr.AddError("sharing information (for latency tracking) is only valid for services: %q", i.Subject)
   92		}
   93		var act *ActivationClaims
   94	
   95		if i.Token != "" {
   96			var err error
   97			act, err = DecodeActivationClaims(i.Token)
   98			if err != nil {
   99				vr.AddError("import %q contains an invalid activation token", i.Subject)
  100			}
  101		}
  102	
  103		if act != nil {
  104			if !(act.Issuer == i.Account || act.IssuerAccount == i.Account) {
  105				vr.AddError("activation token doesn't match account for import %q", i.Subject)
  106			}
  107			if act.ClaimsData.Subject != actPubKey {
  108				vr.AddError("activation token doesn't match account it is being included in, %q", i.Subject)
  109			}
  110			if act.ImportType != i.Type {
  111				vr.AddError("mismatch between token import type %s and type of import %s", act.ImportType, i.Type)
  112			}
  113			act.validateWithTimeChecks(vr, false)
```


## Exports


### `v2/exports.go` L111–L124 — the `Export` struct — `TokenReq` (JSON `token_req`), `Revocations`, `AccountTokenPosition`

```go
  111	type Export struct {
  112		Name                 string          `json:"name,omitempty"`
  113		Subject              Subject         `json:"subject,omitempty"`
  114		Type                 ExportType      `json:"type,omitempty"`
  115		TokenReq             bool            `json:"token_req,omitempty"`
  116		Revocations          RevocationList  `json:"revocations,omitempty"`
  117		ResponseType         ResponseType    `json:"response_type,omitempty"`
  118		ResponseThreshold    time.Duration   `json:"response_threshold,omitempty"`
  119		Latency              *ServiceLatency `json:"service_latency,omitempty"`
  120		AccountTokenPosition uint            `json:"account_token_position,omitempty"`
  121		Advertise            bool            `json:"advertise,omitempty"`
  122		AllowTrace           bool            `json:"allow_trace,omitempty"`
  123		Info
  124	}
```


### `v2/exports.go` L153–L201 — `Export.Validate` — `account_token_position` needs a wildcard subject and must point at a `*`

```go
  153	func (e *Export) Validate(vr *ValidationResults) {
  154		if e == nil {
  155			vr.AddError("null export is not allowed")
  156			return
  157		}
  158		if !e.IsService() && !e.IsStream() {
  159			vr.AddError("invalid export type: %q", e.Type)
  160		}
  161		if e.IsService() && !e.IsSingleResponse() && !e.IsChunkedResponse() && !e.IsStreamResponse() {
  162			vr.AddError("invalid response type for service: %q", e.ResponseType)
  163		}
  164		if e.IsStream() {
  165			if e.ResponseType != "" {
  166				vr.AddError("invalid response type for stream: %q", e.ResponseType)
  167			}
  168			if e.AllowTrace {
  169				vr.AddError("AllowTrace only valid for service export")
  170			}
  171		}
  172		if e.Latency != nil {
  173			if !e.IsService() {
  174				vr.AddError("latency tracking only permitted for services")
  175			}
  176			e.Latency.Validate(vr)
  177		}
  178		if e.ResponseThreshold.Nanoseconds() < 0 {
  179			vr.AddError("negative response threshold is invalid")
  180		}
  181		if e.ResponseThreshold.Nanoseconds() > 0 && !e.IsService() {
  182			vr.AddError("response threshold only valid for services")
  183		}
  184		e.Subject.Validate(vr)
  185		if e.AccountTokenPosition > 0 {
  186			if !e.Subject.HasWildCards() {
  187				vr.AddError("Account Token Position can only be used with wildcard subjects: %s", e.Subject)
  188			} else {
  189				subj := string(e.Subject)
  190				token := strings.Split(subj, ".")
  191				tkCnt := uint(len(token))
  192				if e.AccountTokenPosition > tkCnt {
  193					vr.AddError("Account Token Position %d exceeds length of subject '%s'",
  194						e.AccountTokenPosition, e.Subject)
  195				} else if tk := token[e.AccountTokenPosition-1]; tk != "*" {
  196					vr.AddError("Account Token Position %d matches '%s' but must match a * in: %s",
  197						e.AccountTokenPosition, tk, e.Subject)
  198				}
  199			}
  200		}
  201		e.Info.Validate(vr)
```


### `v2/exports.go` L203–L222 — `Revoke` / `RevokeAt` / `ClearRevocation` — revocations live on the export

```go
  203	
  204	// Revoke enters a revocation by publickey using time.Now().
  205	func (e *Export) Revoke(pubKey string) {
  206		e.RevokeAt(pubKey, time.Now())
  207	}
  208	
  209	// RevokeAt enters a revocation by publickey and timestamp into this export
  210	// If there is already a revocation for this public key that is newer, it is kept.
  211	func (e *Export) RevokeAt(pubKey string, timestamp time.Time) {
  212		if e.Revocations == nil {
  213			e.Revocations = RevocationList{}
  214		}
  215	
  216		e.Revocations.Revoke(pubKey, timestamp)
  217	}
  218	
  219	// ClearRevocation removes any revocation for the public key
  220	func (e *Export) ClearRevocation(pubKey string) {
  221		e.Revocations.ClearRevocation(pubKey)
  222	}
```


## The activation claim


### `v2/activation_claims.go` L28–L58 — `Activation` — `subject` (the import subject), `kind`, `issuer_account` when a signing key signs

```go
   28	// Activation defines the custom parts of an activation claim
   29	type Activation struct {
   30		ImportSubject Subject    `json:"subject,omitempty"`
   31		ImportType    ExportType `json:"kind,omitempty"`
   32		// IssuerAccount stores the public key for the account the issuer represents.
   33		// When set, the claim was issued by a signing key.
   34		IssuerAccount string `json:"issuer_account,omitempty"`
   35		GenericFields
   36	}
   37	
   38	// IsService returns true if an Activation is for a service
   39	func (a *Activation) IsService() bool {
   40		return a.ImportType == Service
   41	}
   42	
   43	// IsStream returns true if an Activation is for a stream
   44	func (a *Activation) IsStream() bool {
   45		return a.ImportType == Stream
   46	}
   47	
   48	// Validate checks the exports and limits in an activation JWT
   49	func (a *Activation) Validate(vr *ValidationResults) {
   50		if !a.IsService() && !a.IsStream() {
   51			vr.AddError("invalid import type: %q", a.ImportType)
   52		}
   53	
   54		a.ImportSubject.Validate(vr)
   55	}
   56	
   57	// ActivationClaims holds the data specific to an activation JWT
   58	type ActivationClaims struct {
```


### `v2/activation_claims.go` L60–L86 — `ActivationClaims` — an activation is a JWT whose `sub` is the importing account

```go
   60		Activation `json:"nats,omitempty"`
   61	}
   62	
   63	// NewActivationClaims creates a new activation claim with the provided sub
   64	func NewActivationClaims(subject string) *ActivationClaims {
   65		if subject == "" {
   66			return nil
   67		}
   68		ac := &ActivationClaims{}
   69		ac.Subject = subject
   70		return ac
   71	}
   72	
   73	// Encode turns an activation claim into a JWT strimg
   74	func (a *ActivationClaims) Encode(pair nkeys.KeyPair) (string, error) {
   75		return a.EncodeWithSigner(pair, nil)
   76	}
   77	
   78	func (a *ActivationClaims) EncodeWithSigner(pair nkeys.KeyPair, fn SignFn) (string, error) {
   79		if !nkeys.IsValidPublicAccountKey(a.ClaimsData.Subject) {
   80			return "", errors.New("expected subject to be an account")
   81		}
   82		a.Type = ActivationClaim
   83		return a.ClaimsData.encode(pair, a, fn)
   84	}
   85	
   86	// DecodeActivationClaims tries to create an activation claim from a JWT string
```


### `v2/activation_claims.go` L105–L118 — `Validate` and `validateWithTimeChecks`

```go
  105	func (a *ActivationClaims) Validate(vr *ValidationResults) {
  106		a.validateWithTimeChecks(vr, true)
  107	}
  108	
  109	// Validate checks the claims
  110	func (a *ActivationClaims) validateWithTimeChecks(vr *ValidationResults, timeChecks bool) {
  111		if timeChecks {
  112			a.ClaimsData.Validate(vr)
  113		}
  114		a.Activation.Validate(vr)
  115		if a.IssuerAccount != "" && !nkeys.IsValidPublicAccountKey(a.IssuerAccount) {
  116			vr.AddError("account_id is not an account public key")
  117		}
  118	}
```


### `v2/activation_claims.go` L128–L132 — `ExpectedPrefixes` — an account or an operator key may sign an activation

```go
  128	// ExpectedPrefixes defines the types that can sign an activation jwt, account and oeprator
  129	func (a *ActivationClaims) ExpectedPrefixes() []nkeys.PrefixByte {
  130		return []nkeys.PrefixByte{nkeys.PrefixByteAccount, nkeys.PrefixByteOperator}
  131	}
  132	
```
