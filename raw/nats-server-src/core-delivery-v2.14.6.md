<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6 — client.go, opts.go, accounts.go, sublist.go, server.go, const.go fetched from raw.githubusercontent.com (2026-09-02/03, cached in local/scratch/src/v2.14.6/), errors.go, monitor.go, parser.go, reload.go from the release tarball tools/check-defaults.py keeps in .cache/ · extracted 2026-09-03 -->
# nats-server v2.14.6 — core delivery: subjects, the control line, echo, headers and `max_payload`, the 503, account mappings

Verbatim line ranges from the tagged source, one block per file, in the form of `constants-v2.14.6.md`; the line numbers are the real ones at the tag, so each can be checked at `https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`. Read for `wiki/concepts/core-nats-delivery.md` and `wiki/concepts/subjects-and-wildcards.md` (phase F step 1); the behavioural half is `core-delivery-observed-v2.14.6.md` beside this file.

## server/const.go — the control line, the payload, the pending ceiling, the ping defaults

```go
   88		// MAX_CONTROL_LINE_SIZE is the maximum allowed protocol control line size.
   89		// 4k should be plenty since payloads sans connect/info string are separate.
   90		MAX_CONTROL_LINE_SIZE = 4096
   91	
   92		// MAX_PAYLOAD_SIZE is the maximum allowed payload size. Should be using
   93		// something different if > 1MB payloads are needed.
   94		MAX_PAYLOAD_SIZE = (1024 * 1024)
   95	
   96		// MAX_PAYLOAD_MAX_SIZE is the size at which the server will warn about
   97		// max_payload being too high. In the future, the server may enforce/reject
   98		// max_payload above this value.
   99		MAX_PAYLOAD_MAX_SIZE = (8 * 1024 * 1024)
  100	
  101		// MAX_PENDING_SIZE is the maximum outbound pending bytes per client.
  102		MAX_PENDING_SIZE = (64 * 1024 * 1024)
  103	
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
  119		// DEFAULT_PING_INTERVAL is how often pings are sent to clients, etc...
  120		DEFAULT_PING_INTERVAL = 2 * time.Minute
  121	
  122		// DEFAULT_PING_MAX_OUT is maximum allowed pings outstanding before disconnect.
  123		DEFAULT_PING_MAX_OUT = 2
```

## server/client.go — `ClientOpts` and `defaultOpts` (echo, verbose, pedantic on by default)

```go
  675	type ClientOpts struct {
  676		Echo         bool   `json:"echo"`
  677		Verbose      bool   `json:"verbose"`
  678		Pedantic     bool   `json:"pedantic"`
  679		TLSRequired  bool   `json:"tls_required"`
  680		Nkey         string `json:"nkey,omitempty"`
  681		JWT          string `json:"jwt,omitempty"`
  682		Sig          string `json:"sig,omitempty"`
  683		Token        string `json:"auth_token,omitempty"`
  684		Username     string `json:"user,omitempty"`
  685		Password     string `json:"pass,omitempty"`
  686		Name         string `json:"name"`
  687		Lang         string `json:"lang"`
  688		Version      string `json:"version"`
  689		Protocol     int    `json:"protocol"`
  690		Account      string `json:"account,omitempty"`
  691		AccountNew   bool   `json:"new_account,omitempty"`
  692		Headers      bool   `json:"headers,omitempty"`
  693		NoResponders bool   `json:"no_responders,omitempty"`
  694	
  695		// Routes and Leafnodes only
  696		Import *SubjectPermission `json:"import,omitempty"`
  697		Export *SubjectPermission `json:"export,omitempty"`
  698	
  699		// Leafnodes
  700		RemoteAccount string `json:"remote_account,omitempty"`
  701	
  702		// Proxy would include its own nonce signature.
  703		ProxySig string `json:"proxy_sig,omitempty"`
  704	}
  705	
  706	var defaultOpts = ClientOpts{Verbose: true, Pedantic: true, Echo: true}
  707	var internalOpts = ClientOpts{Verbose: false, Pedantic: false, Echo: false}

 2309		firstConnect := !c.flags.isSet(connectReceived)
 2310		c.flags.set(connectReceived)
 2311		// Capture these under lock
 2312		c.echo = c.opts.Echo
```

## server/client.go — the CONNECT check: `no_responders` needs header support

```go
 2451		switch kind {
 2452		case CLIENT:
 2453			// Check client protocol request if it exists.
 2454			if proto < ClientProtoZero || proto > ClientProtoInfo {
 2455				c.sendErr(ErrBadClientProtocol.Error())
 2456				c.closeConnection(BadClientProtocolVersion)
 2457				return ErrBadClientProtocol
 2458			}
 2459			// Check to see that if no_responders is requested
 2460			// they have header support on as well.
 2461			c.mu.Lock()
 2462			misMatch := c.opts.NoResponders && !c.headers
 2463			c.mu.Unlock()
 2464			if misMatch {
 2465				c.sendErr(ErrNoRespondersRequiresHeaders.Error())
 2466				c.closeConnection(NoRespondersRequiresHeaders)
 2467				return ErrNoRespondersRequiresHeaders
 2468			}
```

## server/client.go — the payload violation, and the two PUB parsers (`HPUB` counts header + body as `size`; the pedantic literal-subject check)

A `PUB` line is split on spaces and tabs into 2 or 3 arguments — subject, [reply], size — so a space inside a subject is read as the boundary before a reply subject (run A2). `processHeaderPub` compares `c.pa.size`, the **total** of header and body bytes, against `max_payload` (run B4). The pedantic check sends `Invalid Publish Subject` and returns `nil`: the message is still processed (run C3).

```go
 2552	func (c *client) maxPayloadViolation(sz int, max int32) {
 2553		c.Errorf("%s: %d vs %d", ErrMaxPayload.Error(), sz, max)
 2554		c.sendErr("Maximum Payload Violation")
 2555		c.closeConnection(MaxPayloadExceeded)
 2556	}

 2861	func (c *client) processHeaderPub(arg, remaining []byte) error {
 2862		if !c.headers {
 2863			return ErrMsgHeadersNotSupported
 2864		}
 2865	
 2866		// Unroll splitArgs to avoid runtime/heap issues
 2867		a := [MAX_HPUB_ARGS][]byte{}
 2868		args := a[:0]
 2869		start := -1
 2870		for i, b := range arg {
 2871			switch b {
 2872			case ' ', '\t':
 2873				if start >= 0 {
 2874					args = append(args, arg[start:i])
 2875					start = -1
 2876				}
 2877			default:
 2878				if start < 0 {
 2879					start = i
 2880				}
 2881			}
 2882		}
 2883		if start >= 0 {
 2884			args = append(args, arg[start:])
 2885		}
 2886	
 2887		c.pa.arg = arg
 2888		switch len(args) {
 2889		case 3:
 2890			c.pa.subject = args[0]
 2891			c.pa.reply = nil
 2892			c.pa.hdr = parseSize(args[1])
 2893			c.pa.size = parseSize(args[2])
 2894			c.pa.hdb = args[1]
 2895			c.pa.szb = args[2]
 2896		case 4:
 2897			c.pa.subject = args[0]
 2898			c.pa.reply = args[1]
 2899			c.pa.hdr = parseSize(args[2])
 2900			c.pa.size = parseSize(args[3])
 2901			c.pa.hdb = args[2]
 2902			c.pa.szb = args[3]
 2903		default:
 2904			return fmt.Errorf("processHeaderPub Parse Error: %q", arg)
 2905		}
 2906		if c.pa.hdr < 0 {
 2907			return fmt.Errorf("processHeaderPub Bad or Missing Header Size: %q", arg)
 2908		}
 2909		// If number overruns an int64, parseSize() will have returned a negative value
 2910		if c.pa.size < 0 {
 2911			return fmt.Errorf("processHeaderPub Bad or Missing Total Size: %q", arg)
 2912		}
 2913		if c.pa.hdr > c.pa.size {
 2914			return fmt.Errorf("processHeaderPub Header Size larger then TotalSize: %q", arg)
 2915		}
 2916		maxPayload := atomic.LoadInt32(&c.mpay)
 2917		// Use int64() to avoid int32 overrun...
 2918		if maxPayload != jwt.NoLimit && int64(c.pa.size) > int64(maxPayload) {
 2919			// If we are given the remaining read buffer (since we do blind reads
 2920			// we may have the beginning of the message header/payload), we will
 2921			// look for the tracing header and if found, we will generate a
 2922			// trace event with the max payload ingress error.
 2923			// Do this only for CLIENT connections.
 2924			if c.kind == CLIENT && c.pa.hdr > 0 && len(remaining) > 0 {
 2925				hdr := remaining[:min(len(remaining), c.pa.hdr)]
 2926				c.sendMsgTraceIngressErrEvent(hdr, ErrMaxPayload)
 2927			}
 2928			c.maxPayloadViolation(c.pa.size, maxPayload)
 2929			return ErrMaxPayload
 2930		}
 2931		if c.opts.Pedantic && !IsValidLiteralSubject(bytesToString(c.pa.subject)) {
 2932			c.sendErr("Invalid Publish Subject")
 2933		}
 2934		return nil
 2935	}
 2936	
 2937	func (c *client) processPub(arg []byte) error {
 2938		// Unroll splitArgs to avoid runtime/heap issues
 2939		a := [MAX_PUB_ARGS][]byte{}
 2940		args := a[:0]
 2941		start := -1
 2942		for i, b := range arg {
 2943			switch b {
 2944			case ' ', '\t':
 2945				if start >= 0 {
 2946					args = append(args, arg[start:i])
 2947					start = -1
 2948				}
 2949			default:
 2950				if start < 0 {
 2951					start = i
 2952				}
 2953			}
 2954		}
 2955		if start >= 0 {
 2956			args = append(args, arg[start:])
 2957		}
 2958	
 2959		c.pa.arg = arg
 2960		switch len(args) {
 2961		case 2:
 2962			c.pa.subject = args[0]
 2963			c.pa.reply = nil
 2964			c.pa.size = parseSize(args[1])
 2965			c.pa.szb = args[1]
 2966		case 3:
 2967			c.pa.subject = args[0]
 2968			c.pa.reply = args[1]
 2969			c.pa.size = parseSize(args[2])
 2970			c.pa.szb = args[2]
 2971		default:
 2972			return fmt.Errorf("processPub Parse Error: %q", arg)
 2973		}
 2974		// If number overruns an int64, parseSize() will have returned a negative value
 2975		if c.pa.size < 0 {
 2976			return fmt.Errorf("processPub Bad or Missing Size: %q", arg)
 2977		}
 2978		maxPayload := atomic.LoadInt32(&c.mpay)
 2979		// Use int64() to avoid int32 overrun...
 2980		if maxPayload != jwt.NoLimit && int64(c.pa.size) > int64(maxPayload) {
 2981			c.maxPayloadViolation(c.pa.size, maxPayload)
 2982			return ErrMaxPayload
 2983		}
 2984		if c.opts.Pedantic && !IsValidLiteralSubject(bytesToString(c.pa.subject)) {
 2985			c.sendErr("Invalid Publish Subject")
 2986		}
 2987		return nil
```

## server/client.go — the subscribe path: `max_subscription_tokens`, and the sublist insert that yields `Invalid Subject`

```go
 3090			if opts := srv.getOpts(); opts != nil && opts.MaxSubTokens > 0 {
 3091				if len(bytes.Split(sub.subject, []byte(tsep))) > int(opts.MaxSubTokens) {
 3092					c.mu.Unlock()
 3093					c.maxTokensViolation(sub)
 3094					return nil, ErrTooManySubTokens
 3095				}
 3096			}
 3097		}

 3125		if err != nil {
 3126			c.sendErr("Invalid Subject")
 3127			return nil, ErrMalformedSubject
 3128		} else if c.opts.Verbose && kind != SYSTEM {

 5814	func (c *client) maxTokensViolation(sub *subscription) {
 5815		errTxt := fmt.Sprintf("Permissions Violation for Subscription to %q, too many tokens", sub.subject)
 5816		logTxt := fmt.Sprintf("Subscription Violation Too Many Tokens - Subject %q, SID %s", sub.subject, sub.sid)
 5817		c.sendErr(errTxt)
 5818		c.Errorf(logTxt)
 5819	}
```

## server/client.go — the echo skip in `deliverMsg`

```go
 3756	func (c *client) deliverMsg(prodIsMQTT bool, sub *subscription, acc *Account, subject, reply, mh, msg []byte, gwrply bool) bool {
 3757		// Check if message tracing is enabled.
 3758		mt, traceOnly := c.isMsgTraceEnabled()
 3759	
 3760		client := sub.client
 3761		// Check sub client and check echo. Only do this if not a service import.
 3762		if client == nil || (c == client && !client.echo && !sub.si && !sub.rsi) {
 3763			if client != nil && mt != nil {
 3764				client.mu.Lock()
 3765				mt.addEgressEvent(client, sub, errMsgTraceNoEcho)
 3766				client.mu.Unlock()
 3767			}
 3768			return false
```

## server/client.go — the account mapping applied to an inbound publish, and the 503 the server sends to a requester with no responders

The 503 is an `HMSG` on the reply subject whose header block is `NATS/1.0 503\r\nNats-Subject: <subject>\r\n\r\n` and whose body is empty — `hdrLen` is 32 bytes plus the subject. It is only sent when the connection asked for `no_responders` in its `CONNECT`.

```go
 4325	// selectMappedSubject will choose the mapped subject based on the client's inbound subject.
 4326	func (c *client) selectMappedSubject() bool {
 4327		nsubj, changed := c.acc.selectMappedSubject(bytesToString(c.pa.subject))
 4328		if changed {
 4329			c.pa.mapped = c.pa.subject
 4330			c.pa.subject = []byte(nsubj)
 4331		}
 4332		return changed
 4333	}

 4504		// Check to see if we did not deliver to anyone and the client has a reply subject set
 4505		// and wants notification of no_responders.
 4506		if !didDeliver && len(c.pa.reply) > 0 {
 4507			c.mu.Lock()
 4508			if c.opts.NoResponders {
 4509				if sub := c.subForReply(c.pa.reply); sub != nil {
 4510					hdrLen := 32 /* header without the subject */ + len(c.pa.subject)
 4511					proto := fmt.Sprintf("HMSG %s %s %d %d\r\nNATS/1.0 503\r\nNats-Subject: %s\r\n\r\n\r\n", c.pa.reply, sub.sid, hdrLen, hdrLen, c.pa.subject)
 4512					c.queueOutbound([]byte(proto))
 4513					c.addToPCD(c)
 4514				}
 4515			}
 4516			c.mu.Unlock()
 4517		}
```

## server/client.go — the one `$`-prefix the server does refuse a plain client: `$NRG.` (Raft traffic) outside the system account

```go
 4373		// Check if the client is trying to publish to reserved NRG subjects.
 4374		// Doesn't apply to NRGs themselves as they use SYSTEM-kind clients instead.
 4375		if c.kind == CLIENT && bytes.HasPrefix(c.pa.subject, clientNRGPrefix) && acc != c.srv.SystemAccount() {
 4376			c.pubPermissionViolation(c.pa.subject)
 4377			return false, true
 4378		}
```

## server/parser.go — where the mapping is applied: before the message is routed, for CLIENT and LEAF connections only

```go
  512				var mt *msgTrace
  513				var skip bool
  514				if c.pa.hdr > 0 {
  515					skip, mt = c.initMsgTrace(c.msgBuf[:c.pa.hdr], nil)
  516				}
  517				if !skip {
  518					// Check for mappings.
  519					if (c.kind == CLIENT || c.kind == LEAF) && c.in.flags.isSet(hasMappings) {
  520						changed := c.selectMappedSubject()
  521						if changed {
  522							if trace {
  523								c.traceInOp("MAPPING", []byte(fmt.Sprintf("%s -> %s", c.pa.mapped, c.pa.subject)))
  524							}
  525							// c.pa.subject is the subject the original is now mapped to.
  526							mt.addSubjectMappingEvent(c.pa.subject)
  527						}
  528					}
```

## server/opts.go — `max_subscription_tokens` / `max_sub_tokens`, `no_header_support`, and top-level `mappings` as the `$G` account's mappings

A top-level `mappings` block is parsed into an `Account` named `$G` appended to `o.Accounts` — which is why a changed `mappings` block reloads through the `accounts` path (run F3) while `MaxSubTokens`, which no `reload.go` case handles, does not (run C6).

```go
  434		MaxSubTokens               uint8         `json:"-"`

 1188		case "mappings", "maps":
 1189			gacc := NewAccount(globalAccountName)
 1190			o.Accounts = append(o.Accounts, gacc)
 1191			err := parseAccountMappings(tk, gacc, errors)
 1192			if err != nil {
 1193				*errors = append(*errors, err)
 1194				return
 1195			}

 1370		case "max_sub_tokens", "max_subscription_tokens":
 1371			if n := v.(int64); n > math.MaxUint8 {
 1372				err := &configErr{tk, fmt.Sprintf("%s value is too big", k)}
 1373				*errors = append(*errors, err)
 1374				return
 1375			} else if n <= 0 {
 1376				err := &configErr{tk, fmt.Sprintf("%s value can not be negative", k)}
 1377				*errors = append(*errors, err)
 1378				return
 1379			} else {
 1380				o.MaxSubTokens = uint8(n)
 1381			}

 1750		case "no_header_support":
 1751			o.NoHeaderSupport = v.(bool)
```

## server/accounts.go — `MapDest`, `AddWeightedMappings` (the two weight checks, the auto-added source at the difference unless the source is listed, the cumulative weights) and `selectMappedSubject` (cluster-scoped destinations, the random pick, an empty destination when the roll lands past the listed weights)

```go
  762	// MapDest is for mapping published subjects for clients.
  763	type MapDest struct {
  764		Subject string `json:"subject"`
  765		Weight  uint8  `json:"weight"`
  766		Cluster string `json:"cluster,omitempty"`
  767	}
  768	
  769	func NewMapDest(subject string, weight uint8) *MapDest {
  770		return &MapDest{subject, weight, _EMPTY_}
  771	}
  772	
  773	// destination is for internal representation for a weighted mapped destination.
  774	type destination struct {
  775		tr     *subjectTransform
  776		weight uint8
  777	}
  778	
  779	// mapping is an internal entry for mapping subjects.
  780	type mapping struct {
  781		src    string
  782		wc     bool
  783		dests  []*destination
  784		cdests map[string][]*destination
  785	}
  786	
  787	// AddMapping adds in a simple route mapping from src subject to dest subject
  788	// for inbound client messages.
  789	func (a *Account) AddMapping(src, dest string) error {
  790		return a.AddWeightedMappings(src, NewMapDest(dest, 100))
  791	}
  792	
  793	// AddWeightedMappings will add in a weighted mappings for the destinations.
  794	func (a *Account) AddWeightedMappings(src string, dests ...*MapDest) error {
  795		a.mu.Lock()
  796		defer a.mu.Unlock()
  797	
  798		if !IsValidSubject(src) {
  799			return ErrBadSubject
  800		}
  801	
  802		m := &mapping{src: src, wc: subjectHasWildcard(src), dests: make([]*destination, 0, len(dests)+1)}
  803		seen := make(map[string]struct{})
  804	
  805		var tw = make(map[string]uint8)
  806		for _, d := range dests {
  807			if _, ok := seen[d.Subject]; ok {
  808				return fmt.Errorf("duplicate entry for %q", d.Subject)
  809			}
  810			seen[d.Subject] = struct{}{}
  811			if d.Weight > 100 {
  812				return fmt.Errorf("individual weights need to be <= 100")
  813			}
  814			tw[d.Cluster] += d.Weight
  815			if tw[d.Cluster] > 100 {
  816				return fmt.Errorf("total weight needs to be <= 100")
  817			}
  818			err := ValidateMapping(src, d.Subject)
  819			if err != nil {
  820				return err
  821			}
  822			tr, err := NewSubjectTransform(src, d.Subject)
  823			if err != nil {
  824				return err
  825			}
  826			if d.Cluster == _EMPTY_ {
  827				m.dests = append(m.dests, &destination{tr, d.Weight})
  828			} else {
  829				// We have a cluster scoped filter.
  830				if m.cdests == nil {
  831					m.cdests = make(map[string][]*destination)
  832				}
  833				ad := m.cdests[d.Cluster]
  834				ad = append(ad, &destination{tr, d.Weight})
  835				m.cdests[d.Cluster] = ad
  836			}
  837		}
  838	
  839		processDestinations := func(dests []*destination) ([]*destination, error) {
  840			var ltw uint8
  841			for _, d := range dests {
  842				ltw += d.weight
  843			}
  844			// Auto add in original at weight difference if all entries weight does not total to 100.
  845			// Iff the src was not already added in explicitly, meaning they want loss.
  846			_, haveSrc := seen[src]
  847			if ltw != 100 && !haveSrc {
  848				dest := src
  849				if m.wc {
  850					// We need to make the appropriate markers for the wildcards etc.
  851					dest = transformTokenize(dest)
  852				}
  853				tr, err := NewSubjectTransform(src, dest)
  854				if err != nil {
  855					return nil, err
  856				}
  857				aw := 100 - ltw
  858				if len(dests) == 0 {
  859					aw = 100
  860				}
  861				dests = append(dests, &destination{tr, aw})
  862			}
  863			slices.SortFunc(dests, func(i, j *destination) int { return cmp.Compare(i.weight, j.weight) })
  864	
  865			var lw uint8
  866			for _, d := range dests {
  867				d.weight += lw
  868				lw = d.weight
  869			}
  870			return dests, nil
  871		}
  872	
  873		var err error
  874		if m.dests, err = processDestinations(m.dests); err != nil {
  875			return err
  876		}
  877	
  878		// Option cluster scoped destinations
  879		for cluster, dests := range m.cdests {
  880			if dests, err = processDestinations(dests); err != nil {
  881				return err
  882			}
  883			m.cdests[cluster] = dests
  884		}
  885	
  886		// Replace an old one if it exists.
  887		for i, em := range a.mappings {
  888			if em.src == src {
  889				a.mappings[i] = m
  890				return nil
  891			}
  892		}

  942	func (a *Account) hasMappings() bool {
  943		if a == nil {
  944			return false
  945		}
  946		return a.hasMapped.Load()
  947	}
  948	
  949	// This performs the logic to map to a new dest subject based on mappings.
  950	// Should only be called from processInboundClientMsg or service import processing.
  951	func (a *Account) selectMappedSubject(dest string) (string, bool) {
  952		if !a.hasMappings() {
  953			return dest, false
  954		}
  955	
  956		a.mu.RLock()
  957		// In case we have to tokenize for subset matching.
  958		tsa := [32]string{}
  959		tts := tsa[:0]
  960	
  961		var m *mapping
  962		for _, rm := range a.mappings {
  963			if !rm.wc && rm.src == dest {
  964				m = rm
  965				break
  966			} else {
  967				// tokenize and reuse for subset matching.
  968				if len(tts) == 0 {
  969					start := 0
  970					subject := dest
  971					for i := 0; i < len(subject); i++ {
  972						if subject[i] == btsep {
  973							tts = append(tts, subject[start:i])
  974							start = i + 1
  975						}
  976					}
  977					tts = append(tts, subject[start:])
  978				}
  979				if isSubsetMatch(tts, rm.src) {
  980					m = rm
  981					break
  982				}
  983			}
  984		}
  985	
  986		if m == nil {
  987			a.mu.RUnlock()
  988			return dest, false
  989		}
  990	
  991		// The selected destination for the mapping.
  992		var d *destination
  993		var ndest string
  994	
  995		dests := m.dests
  996		if len(m.cdests) > 0 {
  997			cn := a.srv.cachedClusterName()
  998			dests = m.cdests[cn]
  999			if dests == nil {
 1000				// Fallback to main if we do not match the cluster.
 1001				dests = m.dests
 1002			}
 1003		}
 1004	
 1005		// Optimize for single entry case.
 1006		if len(dests) == 1 && dests[0].weight == 100 {
 1007			d = dests[0]
 1008		} else {
 1009			w := uint8(fastrand.Uint32n(100))
 1010			for _, rm := range dests {
 1011				if w < rm.weight {
 1012					d = rm
 1013					break
 1014				}
 1015			}
 1016		}
 1017	
 1018		if d != nil {
 1019			if len(d.tr.dtokmftokindexesargs) == 0 {
 1020				ndest = d.tr.dest
 1021			} else {
 1022				ndest = d.tr.TransformTokenizedSubject(tts)
 1023			}
 1024		}
 1025	
 1026		a.mu.RUnlock()
 1027		return ndest, true
 1028	}
```

## server/sublist.go — what a valid subject is: `subjectIsLiteral`, `IsValidPublishSubject`, `isValidSubject` (empty token, ` \t\n\f\r`, a non-final `>`; NUL and invalid UTF-8 only with `checkRunes`), `IsValidLiteralSubject`

```go
 1187	func subjectIsLiteral(subject string) bool {
 1188		for i, c := range subject {
 1189			if c == pwc || c == fwc {
 1190				if (i == 0 || subject[i-1] == btsep) &&
 1191					(i+1 == len(subject) || subject[i+1] == btsep) {
 1192					return false
 1193				}
 1194			}
 1195		}
 1196		return true
 1197	}
 1198	
 1199	// IsValidPublishSubject returns true if a subject is valid and a literal, false otherwise
 1200	func IsValidPublishSubject(subject string) bool {
 1201		return IsValidSubject(subject) && subjectIsLiteral(subject)
 1202	}
 1203	
 1204	// IsValidSubject returns true if a subject is valid, false otherwise
 1205	func IsValidSubject(subject string) bool {
 1206		return isValidSubject(subject, false)
 1207	}
 1208	
 1209	func isValidSubject(subject string, checkRunes bool) bool {
 1210		if subject == _EMPTY_ {
 1211			return false
 1212		}
 1213		if checkRunes {
 1214			// Check if we have embedded nulls.
 1215			if bytes.IndexByte(stringToBytes(subject), 0) >= 0 {
 1216				return false
 1217			}
 1218			// Since casting to a string will always produce valid UTF-8, we need to look for replacement runes.
 1219			// This signals something is off or corrupt.
 1220			for _, r := range subject {
 1221				if r == utf8.RuneError {
 1222					return false
 1223				}
 1224			}
 1225		}
 1226		sfwc := false
 1227		for t := range strings.SplitSeq(subject, tsep) {
 1228			length := len(t)
 1229			if length == 0 || sfwc {
 1230				return false
 1231			}
 1232			if length > 1 {
 1233				if strings.ContainsAny(t, "\t\n\f\r ") {
 1234					return false
 1235				}
 1236				continue
 1237			}
 1238			switch t[0] {
 1239			case fwc:
 1240				sfwc = true
 1241			case ' ', '\t', '\n', '\r', '\f':
 1242				return false
 1243			}
 1244		}
 1245		return true
 1246	}
 1247	
 1248	// IsValidLiteralSubject returns true if a subject is valid and literal (no wildcards), false otherwise
 1249	func IsValidLiteralSubject(subject string) bool {
 1250		return isValidLiteralSubject(strings.SplitSeq(subject, tsep))
 1251	}
 1252	
 1253	// isValidLiteralSubject returns true if the tokens are valid and literal (no wildcards), false otherwise
 1254	func isValidLiteralSubject(tokens iter.Seq[string]) bool {
 1255		for t := range tokens {
 1256			if len(t) == 0 {
 1257				return false
 1258			}
 1259			if len(t) > 1 {
 1260				continue
 1261			}
 1262			switch t[0] {
 1263			case pwc, fwc:
 1264				return false
 1265			}
 1266		}
 1267		return true
 1268	}
```

## server/server.go — `headers` in the `INFO` line, and the lame-duck notice

```go
  742			Port:         opts.Port,
  743			AuthRequired: false,
  744			TLSRequired:  tlsReq && !opts.AllowNonTLS,
  745			TLSVerify:    verify,
  746			MaxPayload:   opts.MaxPayload,
  747			JetStream:    opts.JetStream,
  748			Headers:      !opts.NoHeaderSupport,
  749			Cluster:      opts.Cluster.Name,
  750			Domain:       opts.JetStreamDomain,
  751			JSApiLevel:   JSApiLevel,
  752		}

 4439	func (s *Server) lameDuckMode() {
 4440		s.mu.Lock()
 4441		// Check if there is actually anything to do
 4442		if s.isShuttingDown() || s.ldm || s.listener == nil {
 4443			s.mu.Unlock()
 4444			return
 4445		}
 4446		s.Noticef("Entering lame duck mode, stop accepting new clients")
 4447		s.ldm = true
 4448		s.sendLDMShutdownEventLocked()
```

## server/errors.go — the error values behind the `-ERR` strings and the log lines

```go
   42		// ErrMaxPayload represents an error condition when the payload is too big.
   43		ErrMaxPayload = errors.New("maximum payload exceeded")

   54		// ErrBadSubject represents an error condition for an invalid subject.
   55		ErrBadSubject = errors.New("invalid subject")

   78		// ErrTooManySubTokens signals a client that the subject has too many tokens.
   79		ErrTooManySubTokens = errors.New("subject has exceeded number of tokens limit")

  183		// ErrMsgHeadersNotSupported signals the parser detected a message header
  184		// but they are not supported on this server.
  185		ErrMsgHeadersNotSupported = errors.New("message headers not supported")
  186	
  187		// ErrNoRespondersRequiresHeaders signals that a client needs to have headers
  188		// on if they want no responders behavior.
  189		ErrNoRespondersRequiresHeaders = errors.New("no responders requires headers support")

  200		// ErrMalformedSubject is returned when a subscription is made with a subject that does not conform to subject rules.
  201		ErrMalformedSubject = errors.New("malformed subject")
```

## server/monitor.go — `/subsz`: the options (`subs`, `offset`, `limit`, `acc`, `test`) and the per-subscription detail (`qgroup` for a queue subscription)

```go
  957	type SubszOptions struct {
  958		// Offset is used for pagination. Subsz() only returns connections starting at this
  959		// offset from the global results.
  960		Offset int `json:"offset"`
  961	
  962		// Limit is the maximum number of subscriptions that should be returned by Subsz().
  963		Limit int `json:"limit"`
  964	
  965		// Subscriptions indicates if subscription details should be included in the results.
  966		Subscriptions bool `json:"subscriptions"`
  967	
  968		// Filter based on this account name.
  969		Account string `json:"account,omitempty"`
  970	
  971		// Test the list against this subject. Needs to be literal since it signifies a publish subject.
  972		// We will only return subscriptions that would match if a message was sent to this subject.
  973		Test string `json:"test,omitempty"`
  974	}
  975	
  976	// SubDetail is for verbose information for subscriptions.
  977	type SubDetail struct {
  978		Account    string `json:"account,omitempty"`
  979		AccountTag string `json:"account_tag,omitempty"`
  980		Subject    string `json:"subject"`
  981		Queue      string `json:"qgroup,omitempty"`
  982		Sid        string `json:"sid"`
  983		Msgs       int64  `json:"msgs"`
  984		Max        int64  `json:"max,omitempty"`
  985		Cid        uint64 `json:"cid"`
  986	}

 1104	func (s *Server) HandleSubsz(w http.ResponseWriter, r *http.Request) {
 1105		s.mu.Lock()
 1106		s.httpReqStats[SubszPath]++
 1107		s.mu.Unlock()
 1108	
 1109		subs, err := decodeBool(w, r, "subs")
 1110		if err != nil {
 1111			return
 1112		}
 1113		offset, err := decodeInt(w, r, "offset")
 1114		if err != nil {
 1115			return
 1116		}
 1117		limit, err := decodeInt(w, r, "limit")
 1118		if err != nil {
 1119			return
 1120		}
 1121		testSub := r.URL.Query().Get("test")
 1122		// Filtered account.
 1123		filterAcc := r.URL.Query().Get("acc")
 1124	
 1125		subszOpts := &SubszOptions{
 1126			Subscriptions: subs,
 1127			Offset:        offset,
 1128			Limit:         limit,
 1129			Account:       filterAcc,
 1130			Test:          testSub,
 1131		}
```

## server/reload.go — a changed `accounts` value is reloaded through `accountsOption`; an option with no case is refused

```go
  714	// accountsOption implements the option interface.
  715	// Ensure that authorization code is executed if any change in accounts
  716	type accountsOption struct {
  717		authOption
  718	}
  719	
  720	// Apply is a no-op. Changes will be applied in reloadAuthorization
  721	func (a *accountsOption) Apply(s *Server) {
  722		s.Noticef("Reloaded: accounts")
  723	}

 1744			case "accounts":
 1745				diffOpts = append(diffOpts, &accountsOption{})

 1778	
 1779				// If there is really a change prevents reload.
 1780				if !reflect.DeepEqual(tmpOld, tmpNew) {
 1781					// See TODO(ik) note below about printing old/new values.
 1782					return nil, fmt.Errorf("config reload not supported for %s: old=%v, new=%v",
 1783						field.Name, oldValue, newValue)
```

