<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6, files server/accounts.go, server/client.go,
     server/events.go, server/jetstream.go, server/jetstream_api.go, server/stream.go, server/opts.go; and at tag
     v2.10.0, server/accounts.go and server/client.go, for the arrival · fetched 2026-09-03 -->
# nats-server v2.14.6 — service imports: the `Nats-Request-Info` header, `share`, and the three export guards

Only the ranges this wiki quotes are stored, with their real line numbers, so each value links to
`https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`. Read for
`wiki/concepts/service-import-request-info.md` and the *Who may import* section of
`wiki/concepts/cross-account-sharing.md`. The behavioural half is `share-import-observed-v2.14.6.md`.


## The header and the import's `share` flag


### `accounts.go` L163–L188 — the header name and the `serviceImport` struct with its `share` field

```go
  163	const ClientInfoHdr = "Nats-Request-Info"
  164	
  165	// Import service mapping struct
  166	type serviceImport struct {
  167		acc         *Account
  168		claim       *jwt.Import
  169		se          *serviceExport
  170		sid         []byte
  171		from        string
  172		to          string
  173		tr          *subjectTransform
  174		ts          int64
  175		rt          ServiceRespType
  176		latency     *serviceLatency
  177		m1          *ServiceLatency
  178		rc          *client
  179		mt          *msgTrace
  180		usePub      bool
  181		response    bool
  182		invalid     bool
  183		share       bool
  184		tracking    bool
  185		didDeliver  bool
  186		atrc        bool        // allow trace (got from service export)
  187		trackingHdr http.Header // header from request
  188	}
```


### `accounts.go` L2199–L2203 — `share` is copied from the import claim when the import is added

```go
 2199		var share bool
 2200		if claim != nil {
 2201			share = claim.Share
 2202		}
 2203		si := &serviceImport{dest, claim, se, nil, from, to, tr, 0, rt, lat, nil, nil, nil, usePub, false, false, share, false, false, atrc, nil}
```


### `accounts.go` L1795–L1819 — `SetServiceImportSharing` — the config-mode setter, "used for service latency tracking at the moment"

```go
 1795	// SetServiceImportSharing will allow sharing of information about requests with the export account.
 1796	// Used for service latency tracking at the moment.
 1797	func (a *Account) SetServiceImportSharing(destination *Account, to string, allow bool) error {
 1798		return a.setServiceImportSharing(destination, to, true, allow)
 1799	}
 1800	
 1801	// setServiceImportSharing will allow sharing of information about requests with the export account.
 1802	func (a *Account) setServiceImportSharing(destination *Account, to string, check, allow bool) error {
 1803		a.mu.Lock()
 1804		defer a.mu.Unlock()
 1805		if check && a.isClaimAccount() {
 1806			return fmt.Errorf("claim based accounts can not be updated directly")
 1807		}
 1808		// We can't use getServiceImportForAccountLocked() here since we are looking
 1809		// for the service import with the si.to == to, which may not be the key
 1810		// for the service import in the map.
 1811		for _, sis := range a.imports.services {
 1812			for _, si := range sis {
 1813				if si.acc.Name == destination.Name && si.to == to {
 1814					si.share = allow
 1815					return nil
 1816				}
 1817			}
 1818		}
 1819		return fmt.Errorf("service import not found")
```


### `accounts.go` L1424–L1428 — what the requestor shares by default, per the `ServiceLatency` comment

```go
 1424	// ServiceLatency is the JSON message sent out in response to latency tracking for
 1425	// an accounts exported services. Additional client info is available in requestor
 1426	// and responder. Note that for a requestor, the only information shared by default
 1427	// is the RTT used to calculate the total latency. The requestor's account can
 1428	// designate to share the additional information in the service import.
```


### `client.go` L6590–L6622 — `getClientInfo(detailed)` — account and RTT always; the rest only when `detailed`

```go
 6590	func (c *client) getClientInfo(detailed bool) *ClientInfo {
 6591		if c == nil || (c.kind != CLIENT && c.kind != LEAF && c.kind != JETSTREAM && c.kind != ACCOUNT) {
 6592			return nil
 6593		}
 6594	
 6595		// Result
 6596		var ci ClientInfo
 6597	
 6598		if detailed {
 6599			c.addServerAndClusterInfo(&ci)
 6600		}
 6601	
 6602		c.mu.Lock()
 6603		// RTT and Account are always added.
 6604		ci.Account = accForClient(c)
 6605		ci.RTT = c.rtt
 6606		// Detailed signals additional opt in.
 6607		if detailed {
 6608			ci.Start = &c.start
 6609			ci.Host = c.host
 6610			ci.ID = c.cid
 6611			ci.Name = c.opts.Name
 6612			ci.User = c.getRawAuthUser()
 6613			ci.Lang = c.opts.Lang
 6614			ci.Version = c.opts.Version
 6615			ci.Jwt = c.opts.JWT
 6616			ci.IssuerKey = issuerForClient(c)
 6617			ci.NameTag = c.nameTag
 6618			ci.Tags = c.tags
 6619			ci.Kind = c.kindString()
 6620			ci.ClientType = c.clientTypeString()
 6621		}
 6622		c.mu.Unlock()
```


### `events.go` L309–L333 — the `ClientInfo` struct — every field the header can carry

```go
  309	type ClientInfo struct {
  310		Start      *time.Time    `json:"start,omitempty"`
  311		Host       string        `json:"host,omitempty"`
  312		ID         uint64        `json:"id,omitempty"`
  313		Account    string        `json:"acc,omitempty"`
  314		Service    string        `json:"svc,omitempty"`
  315		User       string        `json:"user,omitempty"`
  316		Name       string        `json:"name,omitempty"`
  317		Lang       string        `json:"lang,omitempty"`
  318		Version    string        `json:"ver,omitempty"`
  319		RTT        time.Duration `json:"rtt,omitempty"`
  320		Server     string        `json:"server,omitempty"`
  321		Cluster    string        `json:"cluster,omitempty"`
  322		Alternates []string      `json:"alts,omitempty"`
  323		Stop       *time.Time    `json:"stop,omitempty"`
  324		Jwt        string        `json:"jwt,omitempty"`
  325		IssuerKey  string        `json:"issuer_key,omitempty"`
  326		NameTag    string        `json:"name_tag,omitempty"`
  327		Tags       jwt.TagList   `json:"tags,omitempty"`
  328		Kind       string        `json:"kind,omitempty"`
  329		ClientType string        `json:"client_type,omitempty"`
  330		MQTTClient string        `json:"client_id,omitempty"` // This is the MQTT client ID
  331		Nonce      string        `json:"nonce,omitempty"`
  332		Reply      string        `json:"reply,omitempty"` // Original reply subject after a service import (only when needed).
  333	}
```


## Where the header is stamped, rebuilt and stripped


### `client.go` L4838–L4838 — `processServiceImport` — the function head

```go
 4838	func (c *client) processServiceImport(si *serviceImport, acc *Account, msg []byte) bool {
```


### `client.go` L4930–L4993 — the header is stamped once per request; on a chain the first hop's `share` is kept; a leaf's forwarded header is replaced

```go
 4930		// Set previous service import to detect chaining.
 4931		lpsi := len(c.pa.psi)
 4932		hadPrevSi, share := lpsi > 0, si.share
 4933		if hadPrevSi {
 4934			share = c.pa.psi[lpsi-1].share
 4935		}
 4936		c.pa.psi = append(c.pa.psi, si)
 4937	
 4938		// Place our client info for the request in the original message.
 4939		// This will survive going across routes, etc.
 4940		if !isResponse {
 4941			isSysImport := siAcc == c.srv.SystemAccount()
 4942			var ci *ClientInfo
 4943			var cis *ClientInfo
 4944			if c.pa.hdr >= 0 {
 4945				var hci ClientInfo
 4946				if err := json.Unmarshal(sliceHeader(ClientInfoHdr, msg[:c.pa.hdr]), &hci); err == nil {
 4947					cis = &hci
 4948				}
 4949			}
 4950			if c.kind == LEAF && c.pa.hdr >= 0 && len(sliceHeader(ClientInfoHdr, msg[:c.pa.hdr])) > 0 {
 4951				// Leaf nodes may forward a Nats-Request-Info from a remote domain,
 4952				// but the local server must replace it with the identity of the
 4953				// authenticated leaf connection instead of trusting forwarded values.
 4954				ci = c.getClientInfo(share)
 4955				if hadPrevSi && cis != nil && cis.Reply != _EMPTY_ {
 4956					ci.Reply = cis.Reply
 4957				} else if bytes.HasSuffix(c.pa.reply, []byte(FastBatchSuffix)) {
 4958					// Fast batch requires knowledge of the original reply subject.
 4959					ci.Reply = bytesToString(c.pa.reply)
 4960				}
 4961				if hadPrevSi {
 4962					ci.Service = acc.Name
 4963					if !share && (si.share || isSysImport) {
 4964						c.addServerAndClusterInfo(ci)
 4965					}
 4966				} else if !share && isSysImport {
 4967					c.addServerAndClusterInfo(ci)
 4968				}
 4969			} else if hadPrevSi && cis != nil {
 4970				ci = cis
 4971				ci.Service = acc.Name
 4972				// Check if we are moving into a share details account from a non-shared
 4973				// and add in server and cluster details.
 4974				if !share && (si.share || isSysImport) {
 4975					c.addServerAndClusterInfo(ci)
 4976				}
 4977			} else if c.kind != LEAF || c.pa.hdr < 0 || len(sliceHeader(ClientInfoHdr, msg[:c.pa.hdr])) == 0 {
 4978				ci = c.getClientInfo(share)
 4979				// Fast batch requires knowledge of the original reply subject.
 4980				if bytes.HasSuffix(c.pa.reply, []byte(FastBatchSuffix)) {
 4981					ci.Reply = bytesToString(c.pa.reply)
 4982				}
 4983				// If we did not share but the imports destination is the system account add in the server and cluster info.
 4984				if !share && isSysImport {
 4985					c.addServerAndClusterInfo(ci)
 4986				}
 4987			}
 4988			// Set clientInfo if present.
 4989			if ci != nil {
 4990				if b, _ := json.Marshal(ci); b != nil {
 4991					msg = c.setHeader(ClientInfoHdr, bytesToString(b), msg)
 4992				}
 4993			}
```


### `client.go` L5756–L5783 — `checkLeafClientInfoHeader` — `acc` is rewritten to the hub-side account name across a leafnode

```go
 5756	// Check and swap accounts on a client info header destined across a leafnode.
 5757	func (c *client) checkLeafClientInfoHeader(msg []byte) (dmsg []byte, setHdr bool) {
 5758		if c.pa.hdr < 0 || len(msg) < c.pa.hdr {
 5759			return msg, false
 5760		}
 5761		cir := sliceHeader(ClientInfoHdr, msg[:c.pa.hdr])
 5762		if len(cir) == 0 {
 5763			return msg, false
 5764		}
 5765	
 5766		dmsg = msg
 5767	
 5768		var ci ClientInfo
 5769		if err := json.Unmarshal(cir, &ci); err == nil {
 5770			if v, _ := c.srv.leafRemoteAccounts.Load(ci.Account); v != nil {
 5771				remoteAcc := v.(string)
 5772				if ci.Account != remoteAcc {
 5773					ci.Account = remoteAcc
 5774					if b, _ := json.Marshal(ci); b != nil {
 5775						dmsg, setHdr = c.setHeader(ClientInfoHdr, bytesToString(b), msg), true
 5776					}
 5777				}
 5778			}
 5779		}
 5780		return dmsg, setHdr
 5781	}
 5782	
 5783	func (c *client) pubPermissionViolation(subject []byte) {
```


### `jetstream.go` L787–L797 — the system account's `$JS.API.>` import is forced to share

```go
  787		if !a.serviceImportExists(dstAccName, jsAllAPI) {
  788			// Capture si so we can turn on implicit sharing with JetStream layer.
  789			// Make sure to set "to" otherwise will incur performance slow down.
  790			si, err := a.addServiceImport(s.SystemAccount(), jsAllAPI, jsAllAPI, nil)
  791			if err != nil {
  792				return fmt.Errorf("Error setting up jetstream service imports for account: %v", err)
  793			}
  794			a.mu.Lock()
  795			si.share = true
  796			a.mu.Unlock()
  797		}
```


### `jetstream_api.go` L809–L815 — the JetStream API drops a request that arrives without the header

```go
  809		hdr, msg := c.msgParts(rmsg)
  810		if len(sliceHeader(ClientInfoHdr, hdr)) == 0 {
  811			// Check if this is the system account. We will let these through for the account info only.
  812			sacc := s.SystemAccount()
  813			if sacc != acc {
  814				return
  815			}
```


### `stream.go` L6354–L6358 — a stream strips the header before storing a message

```go
 6354		// If we have received this message across an account we may have request information attached.
 6355		// For now remove. TODO(dlc) - Should this be opt-in or opt-out?
 6356		if len(hdr) > 0 {
 6357			hdr = removeHeaderIfPresent(hdr, ClientInfoHdr)
 6358		}
```


## The three export guards


### `accounts.go` L293–L298 — `exportAuth` — token required, account token position, the approved list, revocations

```go
  293	type exportAuth struct {
  294		tokenReq    bool
  295		accountPos  uint
  296		approved    map[string]*Account
  297		actsRevoked map[string]int64
  298	}
```


### `accounts.go` L2863–L2882 — `checkAuth` — the order: public, then account position, then token, then the list

```go
 2863	func (a *Account) checkAuth(ea *exportAuth, account *Account, imClaim *jwt.Import, tokens []string) bool {
 2864		// if ea is nil or ea.approved is nil, that denotes a public export
 2865		if ea == nil || (len(ea.approved) == 0 && !ea.tokenReq && ea.accountPos == 0) {
 2866			return true
 2867		}
 2868		// Check if the export is protected and enforces presence of importing account identity
 2869		if ea.accountPos > 0 {
 2870			return ea.accountPos <= uint(len(tokens)) && tokens[ea.accountPos-1] == account.Name
 2871		}
 2872		// Check if token required
 2873		if ea.tokenReq {
 2874			return a.checkActivation(account, imClaim, ea, true)
 2875		}
 2876		if ea.approved == nil {
 2877			return false
 2878		}
 2879		// If we have a matching account we are authorized
 2880		_, ok := ea.approved[account.Name]
 2881		return ok
 2882	}
```


### `accounts.go` L2911–L2932 — `checkServiceExportApproved` — exact subject first, then the export that contains the import

```go
 2911	func (a *Account) checkServiceExportApproved(account *Account, subject string, imClaim *jwt.Import) bool {
 2912		// Check direct match of subject first
 2913		se, ok := a.exports.services[subject]
 2914		if ok {
 2915			// if se is nil or eq.approved is nil, that denotes a public export
 2916			if se == nil {
 2917				return true
 2918			}
 2919			return a.checkAuth(&se.exportAuth, account, imClaim, nil)
 2920		}
 2921		// ok if we are here we did not match directly so we need to test each one.
 2922		// The import subject arg has to take precedence, meaning the export
 2923		// has to be a true subset of the import claim. We already checked for
 2924		// exact matches above.
 2925		tokens := strings.Split(subject, tsep)
 2926		for subj, se := range a.exports.services {
 2927			if isSubsetMatch(tokens, subj) {
 2928				if se == nil {
 2929					return true
 2930				}
 2931				return a.checkAuth(&se.exportAuth, account, imClaim, tokens)
 2932			}
```


### `accounts.go` L3044–L3087 — `checkActivation` — decode, issuer, validate, expiry (with a timer), revocation

```go
 3044	// checkActivation will check the activation token for validity.
 3045	// ea may only be nil in cases where revocation may not be checked, say triggered by expiration timer.
 3046	func (a *Account) checkActivation(importAcc *Account, claim *jwt.Import, ea *exportAuth, expTimer bool) bool {
 3047		if claim == nil || claim.Token == _EMPTY_ {
 3048			return false
 3049		}
 3050		// Create a quick clone so we can inline Token JWT.
 3051		clone := *claim
 3052	
 3053		vr := jwt.CreateValidationResults()
 3054		clone.Validate(importAcc.Name, vr)
 3055		if vr.IsBlocking(true) {
 3056			return false
 3057		}
 3058		act, err := jwt.DecodeActivationClaims(clone.Token)
 3059		if err != nil {
 3060			return false
 3061		}
 3062		if !a.isIssuerClaimTrusted(act) {
 3063			return false
 3064		}
 3065		vr = jwt.CreateValidationResults()
 3066		act.Validate(vr)
 3067		if vr.IsBlocking(true) {
 3068			return false
 3069		}
 3070		if act.Expires != 0 {
 3071			tn := time.Now().Unix()
 3072			if act.Expires <= tn {
 3073				return false
 3074			}
 3075			if expTimer {
 3076				expiresAt := time.Duration(act.Expires - tn)
 3077				time.AfterFunc(expiresAt*time.Second, func() {
 3078					importAcc.activationExpired(a, string(act.ImportSubject), claim.Type)
 3079				})
 3080			}
 3081		}
 3082		if ea == nil {
 3083			return true
 3084		}
 3085		// Check for token revocation..
 3086		return !isRevoked(ea.actsRevoked, act.Subject, act.IssuedAt)
 3087	}
```


### `accounts.go` L3089–L3106 — `isIssuerClaimTrusted` — the token's issuer must be the exporting account or one of its signing keys

```go
 3089	// Returns true if the activation claim is trusted. That is the issuer matches
 3090	// the account or is an entry in the signing keys.
 3091	func (a *Account) isIssuerClaimTrusted(claims *jwt.ActivationClaims) bool {
 3092		// if no issuer account, issuer is the account
 3093		if claims.IssuerAccount == _EMPTY_ {
 3094			return true
 3095		}
 3096		// If the IssuerAccount is not us, then this is considered an error.
 3097		if a.Name != claims.IssuerAccount {
 3098			if a.srv != nil {
 3099				a.srv.Errorf("Invalid issuer account %q in activation claim (subject: %q - type: %q) for account %q",
 3100					claims.IssuerAccount, claims.Activation.ImportSubject, claims.Activation.ImportType, a.Name)
 3101			}
 3102			return false
 3103		}
 3104		_, ok := a.hasIssuerNoLock(claims.Issuer)
 3105		return ok
 3106	}
```


### `accounts.go` L3362–L3367 — `authAccounts` — `token_req` in the JWT becomes the `tokenAuthReq` sentinel

```go
 3362	func authAccounts(tokenReq bool) []*Account {
 3363		if tokenReq {
 3364			return tokenAuthReq
 3365		}
 3366		return nil
 3367	}
```


### `accounts.go` L3606–L3625 — the exports of an account JWT are registered with `TokenReq` and `AccountTokenPosition`

```go
 3606	
 3607		for _, e := range ac.Exports {
 3608			switch e.Type {
 3609			case jwt.Stream:
 3610				s.Debugf("Adding stream export %q for %s", e.Subject, tl)
 3611				if err := a.addStreamExportWithAccountPos(
 3612					string(e.Subject), authAccounts(e.TokenReq), e.AccountTokenPosition); err != nil {
 3613					s.Debugf("Error adding stream export to account [%s]: %v", tl, err.Error())
 3614				}
 3615			case jwt.Service:
 3616				s.Debugf("Adding service export %q for %s", e.Subject, tl)
 3617				rt := Singleton
 3618				switch e.ResponseType {
 3619				case jwt.ResponseTypeStream:
 3620					rt = Streamed
 3621				case jwt.ResponseTypeChunked:
 3622					rt = Chunked
 3623				}
 3624				if err := a.addServiceExportWithResponseAndAccountPos(
 3625					string(e.Subject), rt, authAccounts(e.TokenReq), e.AccountTokenPosition); err != nil {
```


## Config mode: the keys the parsers accept


### `opts.go` L4108–L4108 — `parseExportStreamOrService` — the head

```go
 4108	func parseExportStreamOrService(v any, errors *[]error) (*export, *export, error) {
```


### `opts.go` L4228–L4228 — the response-threshold aliases

```go
 4228			case "threshold", "response_threshold", "response_max_time", "response_time":
```


### `opts.go` L4255–L4283 — `accounts`, `latency`, `account_token_position`, `allow_trace` on an export

```go
 4255			case "accounts":
 4256				for _, iv := range mv.([]any) {
 4257					_, mv := unwrapValue(iv, &lt)
 4258					accounts = append(accounts, mv.(string))
 4259				}
 4260				if curStream != nil {
 4261					curStream.accs = accounts
 4262				} else if curService != nil {
 4263					curService.accs = accounts
 4264				}
 4265			case "latency":
 4266				latToken = tk
 4267				var err error
 4268				lat, err = parseServiceLatency(tk, mv)
 4269				if err != nil {
 4270					*errors = append(*errors, err)
 4271					continue
 4272				}
 4273				if curStream != nil {
 4274					err = &configErr{tk, "Detected latency directive on non-service"}
 4275					*errors = append(*errors, err)
 4276					continue
 4277				}
 4278				if curService != nil {
 4279					curService.lat = lat
 4280				}
 4281			case "account_token_position":
 4282				accTokPos = uint(mv.(int64))
 4283			case "allow_trace":
```


### `opts.go` L4398–L4410 — `parseImportStreamOrService` — the head and its locals

```go
 4398	func parseImportStreamOrService(v any, errors *[]error) (*importStream, *importService, error) {
 4399		var (
 4400			curStream  *importStream
 4401			curService *importService
 4402			pre, to    string
 4403			share      bool
 4404			lt         token
 4405			atrc       bool
 4406			atrcSeen   bool
 4407			atrcToken  token
 4408		)
 4409		defer convertPanicToErrorList(&lt, errors)
 4410	
```


### `opts.go` L4480–L4514 — `prefix`, `to`, `share`, `allow_trace` on an import; `share` is applied to a service import only

```go
 4480				curService = &importService{an: accountName, sub: subject}
 4481				if to != _EMPTY_ {
 4482					curService.to = to
 4483				} else {
 4484					curService.to = subject
 4485				}
 4486				curService.share = share
 4487			case "prefix":
 4488				pre = mv.(string)
 4489				if curStream != nil {
 4490					curStream.pre = pre
 4491				}
 4492			case "to":
 4493				to = mv.(string)
 4494				if curService != nil {
 4495					curService.to = to
 4496				}
 4497				if curStream != nil {
 4498					curStream.to = to
 4499					if curStream.pre != _EMPTY_ {
 4500						err := &configErr{tk, "Stream import can not have a 'prefix' and a 'to' property"}
 4501						*errors = append(*errors, err)
 4502						continue
 4503					}
 4504				}
 4505			case "share":
 4506				share = mv.(bool)
 4507				if curService != nil {
 4508					curService.share = share
 4509				}
 4510			case "allow_trace":
 4511				if curService != nil {
 4512					err := &configErr{tk, "Detected allow_trace directive on a non-stream"}
 4513					*errors = append(*errors, err)
 4514					continue
```


## The two helpers behind the detailed fields

### `client.go` L6563–L6580 — `addServerAndClusterInfo`: the server name (the remote server's, over a leaf) and the cluster

```go
 6563	func (c *client) addServerAndClusterInfo(ci *ClientInfo) {
 6564		if ci == nil {
 6565			return
 6566		}
 6567		// Server
 6568		if c.kind != LEAF {
 6569			ci.Server = c.srv.Name()
 6570		} else if c.kind == LEAF {
 6571			ci.Server = c.leaf.remoteServer
 6572		}
 6573		// Cluster
 6574		ci.Cluster = c.srv.cachedClusterName()
 6575		// If we have gateways fill in cluster alternates.
 6576		// These will be in RTT asc order.
 6577		if c.srv.gateway.enabled {
 6578			var gws []*client
 6579			c.srv.getOutboundGatewayConnections(&gws)
 6580			for _, c := range gws {
```

### `client.go` L6765–L6777 — `getRawAuthUser`: what the `user` field holds per authentication method

```go
 6765	func (c *client) getRawAuthUser() string {
 6766		switch {
 6767		case c.opts.Nkey != _EMPTY_:
 6768			return c.opts.Nkey
 6769		case c.opts.Username != _EMPTY_:
 6770			return c.opts.Username
 6771		case c.opts.JWT != _EMPTY_:
 6772			return c.pubKey
 6773		case c.opts.Token != _EMPTY_:
 6774			return "[REDACTED]"
 6775		default:
 6776			return _EMPTY_
 6777		}
```

## Present at v2.10.0

The same header name, the same copy from the claim, and the pre-CVE leaf branch (compare L4930–L4993 above).


### `v2.10.0/accounts.go` L132–L132 — the header name at v2.10.0

```go
  132	const ClientInfoHdr = "Nats-Request-Info"
```


### `v2.10.0/accounts.go` L1917–L1921 — `share = claim.Share` at v2.10.0

```go
 1917		var share bool
 1918		if claim != nil {
 1919			share = claim.Share
 1920		}
 1921		si := &serviceImport{dest, claim, se, nil, from, to, tr, 0, rt, lat, nil, nil, usePub, false, false, share, false, false, nil}
```


### `v2.10.0/client.go` L4168–L4210 — the header stamping at v2.10.0 — a leaf's forwarded header was trusted

```go
 4168		}
 4169	
 4170		// Set previous service import to detect chaining.
 4171		lpsi := len(c.pa.psi)
 4172		hadPrevSi, share := lpsi > 0, si.share
 4173		if hadPrevSi {
 4174			share = c.pa.psi[lpsi-1].share
 4175		}
 4176		c.pa.psi = append(c.pa.psi, si)
 4177	
 4178		// Place our client info for the request in the original message.
 4179		// This will survive going across routes, etc.
 4180		if !isResponse {
 4181			isSysImport := siAcc == c.srv.SystemAccount()
 4182			var ci *ClientInfo
 4183			if hadPrevSi && c.pa.hdr >= 0 {
 4184				var cis ClientInfo
 4185				if err := json.Unmarshal(getHeader(ClientInfoHdr, msg[:c.pa.hdr]), &cis); err == nil {
 4186					ci = &cis
 4187					ci.Service = acc.Name
 4188					// Check if we are moving into a share details account from a non-shared
 4189					// and add in server and cluster details.
 4190					if !share && (si.share || isSysImport) {
 4191						c.addServerAndClusterInfo(ci)
 4192					}
 4193				}
 4194			} else if c.kind != LEAF || c.pa.hdr < 0 || len(getHeader(ClientInfoHdr, msg[:c.pa.hdr])) == 0 {
 4195				ci = c.getClientInfo(share)
 4196				// If we did not share but the imports destination is the system account add in the server and cluster info.
 4197				if !share && isSysImport {
 4198					c.addServerAndClusterInfo(ci)
 4199				}
 4200			} else if c.kind == LEAF && (si.share || isSysImport) {
 4201				// We have a leaf header here for ci, augment as above.
 4202				ci = c.getClientInfo(si.share)
 4203				if !si.share && isSysImport {
 4204					c.addServerAndClusterInfo(ci)
 4205				}
 4206			}
 4207			// Set clientInfo if present.
 4208			if ci != nil {
 4209				if b, _ := json.Marshal(ci); b != nil {
 4210					msg = c.setHeader(ClientInfoHdr, string(b), msg)
```
