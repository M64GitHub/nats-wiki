<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6, files server/const.go, server/opts.go,
     server/auth.go, server/auth_callout.go, server/monitor.go, server/server.go, server/events.go,
     server/stream.go · fetched 2026-08-31 -->
# nats-server v2.14.6 — authentication, TLS and the account trust chain

Only the ranges this wiki quotes are stored, with their real line numbers, so each value links to
`https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`.

## Auth and TLS timeout defaults

### `server/const.go` L104–L118 — TLS_TIMEOUT, the TLS-first fallback delay, and AUTH_TIMEOUT

```go
  104		// DEFAULT_MAX_CONNECTIONS is the default maximum connections allowed.
  105		DEFAULT_MAX_CONNECTIONS = (64 * 1024)
  106	
  107		// TLS_TIMEOUT is the TLS wait time.
  108		TLS_TIMEOUT = 2 * time.Second
  109	
  110		// DEFAULT_TLS_HANDSHAKE_FIRST_FALLBACK_DELAY is the default amount of
  111		// time for the server to wait for the TLS handshake with a client to
  112		// be initiated before falling back to sending the INFO protocol first.
  113		// See TLSHandshakeFirst and TLSHandshakeFirstFallback options.
  114		DEFAULT_TLS_HANDSHAKE_FIRST_FALLBACK_DELAY = 50 * time.Millisecond
  115	
  116		// AUTH_TIMEOUT is the authorization wait time.
  117		AUTH_TIMEOUT = 2 * time.Second
  118	
```

### `server/const.go` L161–L166 — DEFAULT_LEAF_TLS_TIMEOUT

```go
  161		// DEFAULT_LEAF_NODE_RECONNECT LeafNode reconnect interval.
  162		DEFAULT_LEAF_NODE_RECONNECT = time.Second
  163	
  164		// DEFAULT_LEAF_TLS_TIMEOUT TLS timeout for LeafNodes
  165		DEFAULT_LEAF_TLS_TIMEOUT = 2 * time.Second
  166	
```

### `server/opts.go` L6191–L6199 — getDefaultAuthTimeout — with TLS the auth timeout is tls_timeout + 1

```go
 6191	func getDefaultAuthTimeout(tls *tls.Config, tlsTimeout float64) float64 {
 6192		var authTimeout float64
 6193		if tls != nil {
 6194			authTimeout = tlsTimeout + 1.0
 6195		} else {
 6196			authTimeout = float64(AUTH_TIMEOUT / time.Second)
 6197		}
 6198		return authTimeout
 6199	}
```

### `server/opts.go` L6019–L6036 — setDefaults: client and cluster TLS/auth timeouts

```go
 6019			opts.MaxPingsOut = DEFAULT_PING_MAX_OUT
 6020		}
 6021		if opts.TLSTimeout == 0 {
 6022			opts.TLSTimeout = float64(TLS_TIMEOUT) / float64(time.Second)
 6023		}
 6024		if opts.AuthTimeout == 0 {
 6025			opts.AuthTimeout = getDefaultAuthTimeout(opts.TLSConfig, opts.TLSTimeout)
 6026		}
 6027		if opts.Cluster.Port != 0 || opts.Cluster.ListenStr != _EMPTY_ {
 6028			if opts.Cluster.Host == _EMPTY_ {
 6029				opts.Cluster.Host = DEFAULT_HOST
 6030			}
 6031			if opts.Cluster.TLSTimeout == 0 {
 6032				opts.Cluster.TLSTimeout = float64(TLS_TIMEOUT) / float64(time.Second)
 6033			}
 6034			if opts.Cluster.AuthTimeout == 0 {
 6035				opts.Cluster.AuthTimeout = getDefaultAuthTimeout(opts.Cluster.TLSConfig, opts.Cluster.TLSTimeout)
 6036			}
```

### `server/opts.go` L6074–L6082 — setDefaults: leafnode TLS/auth timeouts

```go
 6074				opts.LeafNode.Host = DEFAULT_HOST
 6075			}
 6076			if opts.LeafNode.TLSTimeout == 0 {
 6077				opts.LeafNode.TLSTimeout = float64(TLS_TIMEOUT) / float64(time.Second)
 6078			}
 6079			if opts.LeafNode.AuthTimeout == 0 {
 6080				opts.LeafNode.AuthTimeout = getDefaultAuthTimeout(opts.LeafNode.TLSConfig, opts.LeafNode.TLSTimeout)
 6081			}
 6082			// Default to compression "s2_auto".
```

### `server/opts.go` L6142–L6150 — setDefaults: gateway TLS/auth timeouts

```go
 6142				opts.Gateway.Host = DEFAULT_HOST
 6143			}
 6144			if opts.Gateway.TLSTimeout == 0 {
 6145				opts.Gateway.TLSTimeout = float64(TLS_TIMEOUT) / float64(time.Second)
 6146			}
 6147			if opts.Gateway.AuthTimeout == 0 {
 6148				opts.Gateway.AuthTimeout = getDefaultAuthTimeout(opts.Gateway.TLSConfig, opts.Gateway.TLSTimeout)
 6149			}
 6150		}
```

### `server/opts.go` L6164–L6169 — setDefaults: MQTT TLS timeout

```go
 6164				opts.MQTT.Host = DEFAULT_HOST
 6165			}
 6166			if opts.MQTT.TLSTimeout == 0 {
 6167				opts.MQTT.TLSTimeout = float64(TLS_TIMEOUT) / float64(time.Second)
 6168			}
 6169		}
```

### `server/opts.go` L3148–L3157 — leafnode remote TLS timeout default

```go
 3148					// If ca_file is defined, GenTLSConfig() sets TLSConfig.ClientCAs.
 3149					// Set RootCAs since this tls.Config is used when soliciting
 3150					// a connection (therefore behaves as a client).
 3151					remote.TLSConfig.RootCAs = remote.TLSConfig.ClientCAs
 3152					if tc.Timeout > 0 {
 3153						remote.TLSTimeout = tc.Timeout
 3154					} else {
 3155						remote.TLSTimeout = float64(DEFAULT_LEAF_TLS_TIMEOUT) / float64(time.Second)
 3156					}
 3157					remote.TLSHandshakeFirst = tc.HandshakeFirst
```

## Certificate expiry on the monitoring port

### `server/monitor.go` L1294–L1297 — Varz.TLSCertNotAfter

```go
 1294		DiskIOWaitStats       *DiskIOWaitStats       `json:"disk_io_wait_stats"`                // DiskIOWaitStats are statistics about disk I/O semaphore contention
 1295		Proxies               *ProxiesOptsVarz       `json:"proxies,omitempty"`                 // Proxies hold information about network proxy devices
 1296		TLSCertNotAfter       time.Time              `json:"tls_cert_not_after,omitzero"`       // TLSCertNotAfter is the expiration date of the TLS certificate of this server
 1297	}
```

### `server/monitor.go` L1485–L1499 — tlsCertNotAfter — the leaf certificate of the first configured cert

```go
 1485	func tlsCertNotAfter(config *tls.Config) time.Time {
 1486		if config == nil || len(config.Certificates) == 0 {
 1487			return time.Time{}
 1488		}
 1489		cert := config.Certificates[0]
 1490		leaf := cert.Leaf
 1491		if leaf == nil {
 1492			var err error
 1493			leaf, err = x509.ParseCertificate(cert.Certificate[0])
 1494			if err != nil {
 1495				return time.Time{}
 1496			}
 1497		}
 1498		return leaf.NotAfter
 1499	}
```

### `server/monitor.go` L1836–L1845 — every listener's certificate expiry is filled into Varz

```go
 1836		v.TLSOCSPPeerVerify = s.ocspPeerVerify && v.TLSRequired && s.opts.tlsConfigOpts != nil && s.opts.tlsConfigOpts.OCSPPeerConfig != nil && s.opts.tlsConfigOpts.OCSPPeerConfig.Verify
 1837	
 1838		v.TLSCertNotAfter = tlsCertNotAfter(opts.TLSConfig)
 1839		v.Cluster.TLSCertNotAfter = tlsCertNotAfter(opts.Cluster.TLSConfig)
 1840		v.Gateway.TLSCertNotAfter = tlsCertNotAfter(opts.Gateway.TLSConfig)
 1841		v.LeafNode.TLSCertNotAfter = tlsCertNotAfter(opts.LeafNode.TLSConfig)
 1842		v.LeafNode.Remotes = s.varzLeafNodeRemotes(opts)
 1843		v.MQTT.TLSCertNotAfter = tlsCertNotAfter(opts.MQTT.TLSConfig)
 1844		v.Websocket.TLSCertNotAfter = tlsCertNotAfter(opts.Websocket.TLSConfig)
 1845	
```

## Mapping a client certificate to a user (`verify_and_map`)

### `server/auth.go` L1336–L1395 — the SAN-then-subject order, and 'selecting first' when several certs arrive

```go
 1336		}
 1337		if len(tlsState.PeerCertificates) == 0 {
 1338			c.Debugf("User required in cert, no peer certificates found")
 1339			return false
 1340		}
 1341		cert := tlsState.PeerCertificates[0]
 1342		if len(tlsState.PeerCertificates) > 1 {
 1343			c.Debugf("Multiple peer certificates found, selecting first")
 1344		}
 1345	
 1346		hasSANs := len(cert.DNSNames) > 0
 1347		hasEmailAddresses := len(cert.EmailAddresses) > 0
 1348		hasSubject := len(cert.Subject.String()) > 0
 1349		hasURIs := len(cert.URIs) > 0
 1350		if !hasSANs && !hasEmailAddresses && !hasSubject && !hasURIs {
 1351			c.Debugf("User required in cert, none found")
 1352			return false
 1353		}
 1354	
 1355		switch {
 1356		case hasEmailAddresses:
 1357			for _, u := range cert.EmailAddresses {
 1358				if match, ok := fn(u, nil, false); ok {
 1359					c.Debugf("Using email found in cert for auth [%q]", match)
 1360					return true
 1361				}
 1362			}
 1363			fallthrough
 1364		case hasSANs:
 1365			for _, u := range cert.DNSNames {
 1366				if match, ok := fn(u, nil, true); ok {
 1367					c.Debugf("Using SAN found in cert for auth [%q]", match)
 1368					return true
 1369				}
 1370			}
 1371			fallthrough
 1372		case hasURIs:
 1373			for _, u := range cert.URIs {
 1374				if match, ok := fn(u.String(), nil, false); ok {
 1375					c.Debugf("Using URI found in cert for auth [%q]", match)
 1376					return true
 1377				}
 1378			}
 1379		}
 1380	
 1381		// Use the string representation of the full RDN Sequence including
 1382		// the domain components in case there are any.
 1383		rdn := cert.Subject.ToRDNSequence().String()
 1384	
 1385		// Match using the raw subject to avoid ignoring attributes.
 1386		// https://github.com/golang/go/issues/12342
 1387		dn, err := ldap.FromRawCertSubject(cert.RawSubject)
 1388		if err == nil {
 1389			if match, ok := fn(_EMPTY_, dn, false); ok {
 1390				c.Debugf("Using DistinguishedNameMatch for auth [%q]", match)
 1391				return true
 1392			}
 1393			c.Debugf("DistinguishedNameMatch could not be used for auth [%q]", rdn)
 1394		}
 1395	
```

## Auth callout

### `server/auth_callout.go` L28–L34 — the callout subject and the xkey header

```go
   28	
   29	const (
   30		AuthCalloutSubject    = "$SYS.REQ.USER.AUTH"
   31		AuthRequestSubject    = "nats-authorization-request"
   32		AuthRequestXKeyHeader = "Nats-Server-Xkey"
   33	)
   34	
```

### `server/opts.go` L393–L408 — the AuthCallout config block

```go
  393	// AuthCallout option used to map external AuthN to NATS based AuthZ.
  394	type AuthCallout struct {
  395		// Must be a public account Nkey.
  396		Issuer string
  397		// Account to be used for sending requests.
  398		Account string
  399		// Users that will bypass auth_callout and be used for the auth service itself.
  400		AuthUsers []string
  401		// XKey is a public xkey for the authorization service.
  402		// This will enable encryption for server requests and the authorization service responses.
  403		XKey string
  404		// AllowedAccounts that will be delegated to the auth service.
  405		// If empty then all accounts will be delegated.
  406		AllowedAccounts []string
  407	}
  408	
```

### `server/auth_callout.go` L336–L384 — the request claim the server signs, and its expiry

```go
  336		// Build our request claims - jwt subject should be nkey
  337		jwtSub := acc.Name
  338		if opts.AuthCallout != nil {
  339			jwtSub = opts.AuthCallout.Issuer
  340		}
  341	
  342		// The public key of the server, if set is available on Varz.Key
  343		// This means that when a service connects, it can now peer
  344		// authenticate if it wants to - but that also means that it needs to be
  345		// listening to cluster changes
  346		claim := jwt.NewAuthorizationRequestClaims(jwtSub)
  347		claim.Audience = AuthRequestSubject
  348		// Set expected public user nkey.
  349		claim.UserNkey = pub
  350	
  351		s.mu.RLock()
  352		claim.Server = jwt.ServerID{
  353			Name:    s.info.Name,
  354			Host:    s.info.Host,
  355			ID:      s.info.ID,
  356			Version: s.info.Version,
  357			Cluster: s.info.Cluster,
  358		}
  359		s.mu.RUnlock()
  360	
  361		// Tags
  362		claim.Server.Tags = s.getOpts().Tags
  363	
  364		// Check if we have been requested to encrypt.
  365		// FIXME: possibly this public key also needs to be on the
  366		//  Varz, because then it can be peer verified?
  367		if xkp != nil {
  368			claim.Server.XKey = xkey
  369		}
  370	
  371		authTimeout := secondsToDuration(s.getOpts().AuthTimeout)
  372		claim.Expires = time.Now().Add(time.Duration(authTimeout)).UTC().Unix()
  373	
  374		// Grab client info for the request.
  375		c.mu.Lock()
  376		c.fillClientInfo(&claim.ClientInformation)
  377		c.fillConnectOpts(&claim.ConnectOptions, ujwt)
  378		// If we have a sig in the client opts, fill in nonce.
  379		if claim.ConnectOptions.SignedNonce != _EMPTY_ {
  380			claim.ClientInformation.Nonce = string(c.nonce)
  381		}
  382	
  383		// TLS
  384		if c.flags.isSet(handshakeComplete) && c.nc != nil {
```

### `server/auth_callout.go` L475–L503 — fillConnectOpts — the client's credentials are copied, not checked

```go
  475	// Fill in client options.
  476	// Lock should be held.
  477	func (c *client) fillConnectOpts(opts *jwt.ConnectOptions, ujwt string) {
  478		if c == nil || (c.kind != CLIENT && c.kind != LEAF && c.kind != JETSTREAM && c.kind != ACCOUNT) {
  479			return
  480		}
  481	
  482		o := c.opts
  483		if ujwt == _EMPTY_ {
  484			// The caller may supply a reconstructed JWT that should be sent to auth
  485			// callout without storing it in c.opts.JWT. If not, fall back to the client
  486			// option as before.
  487			ujwt = o.JWT
  488		}
  489	
  490		// Do it this way to fail to compile if fields are added to jwt.ClientInformation.
  491		*opts = jwt.ConnectOptions{
  492			JWT:         ujwt,
  493			Nkey:        o.Nkey,
  494			SignedNonce: o.Sig,
  495			Token:       o.Token,
  496			Username:    o.Username,
  497			Password:    o.Password,
  498			Name:        o.Name,
  499			Lang:        o.Lang,
  500			Version:     o.Version,
  501			Protocol:    o.Protocol,
  502		}
  503	}
```

## The global account, the system account and `no_auth_user`

### `server/server.go` L1441–L1463 — the fabricated no-auth user created when only the system account is declared

```go
 1441			// If we have defined a system account here check to see if its just us and the $G account.
 1442			// We would do this to add user/pass to the system account. If this is the case add in
 1443			// no-auth-user for $G.
 1444			// Only do this if non-operator mode and we did not have an authorization block defined.
 1445			if len(opts.TrustedOperators) == 0 && numAccounts == 2 && opts.NoAuthUser == _EMPTY_ && !opts.authBlockDefined {
 1446				// If we come here from config reload, let's not recreate the fake user name otherwise
 1447				// it will cause currently clients to be disconnected.
 1448				uname := s.sysAccOnlyNoAuthUser
 1449				if uname == _EMPTY_ {
 1450					// Create a unique name so we do not collide.
 1451					var b [8]byte
 1452					rn := rand.Int63()
 1453					for i, l := 0, rn; i < len(b); i++ {
 1454						b[i] = digits[l%base]
 1455						l /= base
 1456					}
 1457					uname = fmt.Sprintf("nats-%s", b[:])
 1458					s.sysAccOnlyNoAuthUser = uname
 1459				}
 1460				opts.Users = append(opts.Users, &User{Username: uname, Password: uname[6:], Account: s.gacc})
 1461				opts.NoAuthUser = uname
 1462			}
 1463		}
```

### `server/server.go` L3286–L3293 — auth_required is not cleared for that fabricated user

```go
 3286		authRequired = info.AuthRequired
 3287	
 3288		// Check to see if we have auth_required set but we also have a no_auth_user.
 3289		// If so set back to false.
 3290		if info.AuthRequired && opts.NoAuthUser != _EMPTY_ && opts.NoAuthUser != s.sysAccOnlyNoAuthUser {
 3291			info.AuthRequired = false
 3292		}
 3293	
```

### `server/server.go` L2425–L2432 — JetStream may not be enabled on the system account

```go
 2425		// the system account setup above. JetStream will create its
 2426		// own system account if one is not present.
 2427		if opts.JetStream {
 2428			// Make sure someone is not trying to enable on the system account.
 2429			if sa := s.SystemAccount(); sa != nil && len(sa.jsLimits) > 0 {
 2430				s.Fatalf("Not allowed to enable JetStream on the system account")
 2431			}
 2432			cfg := &JetStreamConfig{
```

### `server/events.go` L41–L48 — the account-claims subjects an account push uses

```go
   41	const (
   42		accLookupReqTokens = 6
   43		accLookupReqSubj   = "$SYS.REQ.ACCOUNT.%s.CLAIMS.LOOKUP"
   44		accPackReqSubj     = "$SYS.REQ.CLAIMS.PACK"
   45		accListReqSubj     = "$SYS.REQ.CLAIMS.LIST"
   46		accClaimsReqSubj   = "$SYS.REQ.CLAIMS.UPDATE"
   47		accDeleteReqSubj   = "$SYS.REQ.CLAIMS.DELETE"
   48	
```

## Reaching a stream in another account or domain

### `server/stream.go` L405–L438 — StreamSource and ExternalStream

```go
  405	// StreamSource dictates how streams can source from other streams.
  406	type StreamSource struct {
  407		Name              string                   `json:"name"`
  408		OptStartSeq       uint64                   `json:"opt_start_seq,omitempty"`
  409		OptStartTime      *time.Time               `json:"opt_start_time,omitempty"`
  410		FilterSubject     string                   `json:"filter_subject,omitempty"`
  411		SubjectTransforms []SubjectTransformConfig `json:"subject_transforms,omitempty"`
  412		External          *ExternalStream          `json:"external,omitempty"`
  413		Consumer          *StreamConsumerSource    `json:"consumer,omitempty"`
  414	
  415		// Internal
  416		iname string // For indexing when stream names are the same for multiple sources.
  417	}
  418	
  419	// StreamConsumerSource dictates a durable consumer with a specific name is used for sourcing.
  420	type StreamConsumerSource struct {
  421		Name           string `json:"name,omitempty"`
  422		DeliverSubject string `json:"deliver_subject,omitempty"`
  423	}
  424	
  425	// ExternalStream allows you to qualify access to a stream source in another account or domain.
  426	type ExternalStream struct {
  427		ApiPrefix     string `json:"api"`
  428		DeliverPrefix string `json:"deliver"`
  429	}
  430	
  431	// Will return the domain for this external stream.
  432	func (ext *ExternalStream) Domain() string {
  433		if ext == nil || ext.ApiPrefix == _EMPTY_ {
  434			return _EMPTY_
  435		}
  436		return tokenAt(ext.ApiPrefix, 2)
  437	}
  438	
```

### `server/stream.go` L2815–L2820 — the API prefix substitution

```go
 2815		accName, streamName, sourceName := acc.Name, mset.cfg.Name, source.Name
 2816		subject := fmt.Sprintf(JSApiConsumerDeleteT, sourceName, consumerName)
 2817		if source.External != nil {
 2818			subject = strings.Replace(subject, JSApiPrefix, source.External.ApiPrefix, 1)
 2819			subject = strings.ReplaceAll(subject, "..", ".")
 2820		}
```
