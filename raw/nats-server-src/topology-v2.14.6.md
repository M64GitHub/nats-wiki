<!-- source: https://github.com/nats-io/nats-server/tree/v2.14.6/server (raw.githubusercontent.com) · fetched 2026-08-31 -->
# nats-server v2.14.6 — topology: gateways, leafnodes, and the checks that run before the server starts

Only the ranges this wiki quotes are stored, with their real line numbers, so each claim links to
`https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`. Fetched for plan step 6
(topology). Apache-2.0.

Behaviour marked "observed" below was reproduced locally against **nats-server v2.14.5** (the binary
on the machine, one patch behind the tag the source is read at); the configs used are quoted with
each observation.

## `server/server.go` — the option checks that run inside `NewServer`, before anything starts

```go
723:	httpBasePath := normalizeBasePath(opts.HTTPBasePath)
724:
725:	// Validate some options. This is here because we cannot assume that
726:	// server will always be started with configuration parsing (that could
727:	// report issues). Its options can be (incorrectly) set by hand when
728:	// server is embedded. If there is an error, return nil.
729:	if err := validateOptions(opts); err != nil {
730:		return nil, err
731:	}
732:
733:	info := Info{
734:		ID:           pub,
735:		XKey:         xpub,
736:		Version:      VERSION,
```

```go
1151:func validateOptions(o *Options) error {
1152:	if o.LameDuckDuration > 0 && o.LameDuckGracePeriod >= o.LameDuckDuration {
1153:		return fmt.Errorf("lame duck grace period (%v) should be strictly lower than lame duck duration (%v)",
1154:			o.LameDuckGracePeriod, o.LameDuckDuration)
1155:	}
1156:	if int64(o.MaxPayload) > o.MaxPending {
1157:		return fmt.Errorf("max_payload (%v) cannot be higher than max_pending (%v)",
1158:			o.MaxPayload, o.MaxPending)
1159:	}
1160:	if o.ServerName != _EMPTY_ && strings.Contains(o.ServerName, " ") {
1161:		return errors.New("server name cannot contain spaces")
1162:	}
1163:	// Check that the trust configuration is correct.
1164:	if err := validateTrustedOperators(o); err != nil {
1165:		return err
1166:	}
1167:	// Check on leaf nodes which will require a system
1168:	// account when gateways are also configured.
1169:	if err := validateLeafNode(o); err != nil {
1170:		return err
1171:	}
1172:	// Check that authentication is properly configured.
1173:	if err := validateAuth(o); err != nil {
1174:		return err
1175:	}
1176:	// Check that proxies is properly configured.
1177:	if err := validateProxies(o); err != nil {
1178:		return err
1179:	}
1180:	// Check that gateway is properly configured. Returns no error
1181:	// if there is no gateway defined.
1182:	if err := validateGatewayOptions(o); err != nil {
1183:		return err
1184:	}
1185:	// Check that cluster name if defined matches any gateway name.
1186:	if err := validateCluster(o); err != nil {
1187:		return err
1188:	}
1189:	if err := validateMQTTOptions(o); err != nil {
1190:		return err
1191:	}
1192:	if err := validateJetStreamOptions(o); err != nil {
1193:		return err
1194:	}
1195:	// Finally check websocket options.
1196:	return validateWebsocketOptions(o)
```

`validateCluster`, showing that an **unset** `cluster.name` is adopted from `gateway.name`:

```go
1098:func validateCluster(o *Options) error {
1099:	if o.Cluster.Name != _EMPTY_ && strings.Contains(o.Cluster.Name, " ") {
1100:		return ErrClusterNameHasSpaces
1101:	}
1102:	if p := o.Cluster.Permissions; p != nil {
1103:		perms := &Permissions{Publish: p.Import, Subscribe: p.Export}
1104:		if err := checkClusterPermissionSubjects(perms); err != nil {
1105:			return err
1106:		}
1107:	}
1108:	if o.Cluster.Compression.Mode != _EMPTY_ {
1109:		if err := validateAndNormalizeCompressionOption(&o.Cluster.Compression, CompressionS2Fast); err != nil {
1110:			return err
1111:		}
1112:	}
1113:	if err := validatePinnedCerts(o.Cluster.TLSPinnedCerts); err != nil {
1114:		return fmt.Errorf("cluster: %v", err)
1115:	}
1116:	// Check that cluster name if defined matches any gateway name.
1117:	// Note that we have already verified that the gateway name does not have spaces.
1118:	if o.Gateway.Name != _EMPTY_ && o.Gateway.Name != o.Cluster.Name {
1119:		if o.Cluster.Name != _EMPTY_ {
1120:			return ErrClusterNameConfigConflict
1121:		}
1122:		// Set this here so we do not consider it dynamic.
1123:		o.Cluster.Name = o.Gateway.Name
1124:	}
1125:	if l := len(o.Cluster.PinnedAccounts); l > 0 {
```

## `server/errors.go` — the two name errors the docs quote

```go
164:	// ErrGatewayNameHasSpaces signals that the gateway name contains spaces, which is not allowed.
165:	ErrGatewayNameHasSpaces = errors.New("gateway name cannot contain spaces")
191:	// ErrClusterNameConfigConflict signals that the options for cluster name in cluster and gateway are in conflict.
192:	ErrClusterNameConfigConflict = errors.New("cluster name conflicts between cluster and gateway definitions")
193:
194:	// ErrClusterNameRemoteConflict signals that a remote server has a different cluster name.
195:	ErrClusterNameRemoteConflict = errors.New("cluster name from remote server conflicts")
196:
197:	// ErrClusterNameHasSpaces signals that the cluster name contains spaces, which is not allowed.
198:	ErrClusterNameHasSpaces = errors.New("cluster name cannot contain spaces")
```

## `server/leafnode.go` — the system-account requirement, and what `deny_imports` / `deny_exports` are

`validateLeafNodeOptions`, tail: no leafnode listener means no further checks; a leafnode listener **plus** a gateway requires a system account.

```go
326:	}
327:
328:	if o.LeafNode.Port == 0 {
329:		return nil
330:	}
331:
332:	// If MinVersion is defined, check that it is valid.
333:	if mv := o.LeafNode.MinVersion; mv != _EMPTY_ {
334:		if err := checkLeafMinVersionConfig(mv); err != nil {
335:			return err
336:		}
337:	}
338:
339:	// The checks below will be done only when detecting that we are configured
340:	// with gateways. So if an option validation needs to be done regardless,
341:	// it MUST be done before this point!
342:
343:	if o.Gateway.Name == _EMPTY_ && o.Gateway.Port == 0 {
344:		return nil
345:	}
346:	// If we are here we have both leaf nodes and gateways defined, make sure there
347:	// is a system account defined.
348:	if o.SystemAccount == _EMPTY_ {
349:		return fmt.Errorf("leaf nodes and gateways (both being defined) require a system account to also be configured")
350:	}
```

`newLeafNodeCfg` — the two deny lists become a **publish** deny and a **subscribe** deny on the leaf connection. There is no allow list.

```go
466:// Creates a leafNodeCfg object that wraps the RemoteLeafOpts.
467:func newLeafNodeCfg(remote *RemoteLeafOpts) *leafNodeCfg {
468:	cfg := &leafNodeCfg{
469:		RemoteLeafOpts: remote,
470:		urls:           make([]*url.URL, 0, len(remote.URLs)),
471:		quitCh:         make(chan struct{}, 1),
472:	}
473:	if len(remote.DenyExports) > 0 || len(remote.DenyImports) > 0 {
474:		perms := &Permissions{}
475:		if len(remote.DenyExports) > 0 {
476:			perms.Publish = &SubjectPermission{Deny: remote.DenyExports}
477:		}
478:		if len(remote.DenyImports) > 0 {
479:			perms.Subscribe = &SubjectPermission{Deny: remote.DenyImports}
480:		}
481:		cfg.perms = perms
482:	}
483:	// Start with the one that is configured. We will add to this
```

`processLeafNodeInfo` — the hub's permissions for this leaf arrive in the INFO, and the remote's local denies are **merged** on top.

```go
1713:
1714:	// Only solicited leafnode connections trust permission updates from INFO.
1715:	if didSolicit && (info.Import != nil || info.Export != nil) {
1716:		perms := &Permissions{
1717:			Publish:   info.Export,
1718:			Subscribe: info.Import,
1719:		}
1720:		// Check if we have local deny clauses that we need to merge.
1721:		if remote := c.leaf.remote; remote != nil {
1722:			if len(remote.DenyExports) > 0 {
1723:				if perms.Publish == nil {
1724:					perms.Publish = &SubjectPermission{}
1725:				}
1726:				perms.Publish.Deny = append(perms.Publish.Deny, remote.DenyExports...)
1727:			}
1728:			if len(remote.DenyImports) > 0 {
1729:				if perms.Subscribe == nil {
1730:					perms.Subscribe = &SubjectPermission{}
1731:				}
1732:				perms.Subscribe.Deny = append(perms.Subscribe.Deny, remote.DenyImports...)
1733:			}
1734:		}
1735:		c.setPermissions(perms)
1736:	}
```

`processLeafNodeConnect` — on the hub the leaf's permissions are **reversed**, because data flows the other way.

```go
2306:
2307:	// When a leaf solicits a connection to a hub, the perms that it will use on the soliciting leafnode's
2308:	// behalf are correct for them, but inside the hub need to be reversed since data is flowing in the opposite direction.
2309:	if !c.isSolicitedLeafNode() && c.perms != nil {
2310:		sp, pp := c.perms.sub, c.perms.pub
2311:		c.perms.sub, c.perms.pub = pp, sp
2312:		// setPermissions populated darray from the subscribe permissions,
2313:		// which are the import permissions advertised to the spoke. Keep
2314:		// those parsed denies after reversing the live permission directions.
2315:		if c.opts.Import == nil {
2316:			c.darray = nil
2317:		}
2318:	}
2319:
```

`sendPermsAndAccountInfo` — what the hub pushes back for the leaf to enforce locally.

```go
2414:// Sends back an info block to the soliciting leafnode to let it know about
2415:// its permission settings for local enforcement.
2416:func (s *Server) sendPermsAndAccountInfo(c *client) {
2417:	// Copy
2418:	s.mu.Lock()
2419:	info := s.copyLeafNodeInfo()
2420:	s.mu.Unlock()
2421:	c.mu.Lock()
2422:	info.CID = c.cid
2423:	info.Import = c.opts.Import
2424:	info.Export = c.opts.Export
2425:	info.RemoteAccount = c.acc.Name
2426:	// s.SystemAccount() uses an atomic operation and does not get the server lock, so this is safe.
2427:	info.IsSystemAccount = c.acc == s.SystemAccount()
2428:	info.ConnectInfo = true
2429:	c.enqueueProto(generateInfoJSON(info))
2430:	c.mu.Unlock()
2431:}
```

## `server/gateway.go` — the port check, and the name-mismatch pair of log lines

`validateGatewayOptions`: **`gateway.port` has no default.** A gateway block without a port is a startup error.

```go
305:// Ensure that gateway is properly configured.
306:func validateGatewayOptions(o *Options) error {
307:	if o.Gateway.Name == _EMPTY_ && o.Gateway.Port == 0 {
308:		return nil
309:	}
310:	if o.Gateway.Name == _EMPTY_ {
311:		return errors.New("gateway has no name")
312:	}
313:	if strings.Contains(o.Gateway.Name, " ") {
314:		return ErrGatewayNameHasSpaces
315:	}
316:	if o.Gateway.Port == 0 {
317:		return fmt.Errorf("gateway %q has no port specified (select -1 for random port)", o.Gateway.Name)
318:	}
319:	for i, g := range o.Gateway.Gateways {
320:		if g.Name == _EMPTY_ {
321:			return fmt.Errorf("gateway in the list %d has no name", i)
322:		}
323:		if len(g.URLs) == 0 {
324:			return fmt.Errorf("gateway %q has no URL", g.Name)
325:		}
326:	}
327:	if err := validatePinnedCerts(o.Gateway.TLSPinnedCerts); err != nil {
328:		return fmt.Errorf("gateway %q: %v", o.Gateway.Name, err)
329:	}
330:	return nil
```

The name mismatch. The local server logs the first line; the **remote** is sent the second, which names all three values.

```go
1084:		// Check that the gateway name we got is what we expect
1085:		if info.Gateway != gwName {
1086:			// Unless this is the very first INFO, it may be ok if this is
1087:			// a gossip request to connect to other gateways.
1088:			if !isFirstINFO && info.GatewayCmd == gatewayCmdGossip {
1089:				// If we are configured to reject unknown, do not attempt to
1090:				// connect to one that we don't have configured.
1091:				if s.gateway.rejectUnknown() && s.getRemoteGateway(info.Gateway) == nil {
1092:					return
1093:				}
1094:				s.processImplicitGateway(info)
1095:				return
1096:			}
1097:			// Otherwise, this is a failure...
1098:			// We are reporting this error in the log...
1099:			c.Errorf("Failing connection to gateway %q, remote gateway name is %q",
1100:				gwName, info.Gateway)
1101:			// ...and sending this back to the remote so that the error
1102:			// makes more sense in the remote server's log.
1103:			c.sendErr(fmt.Sprintf("Connection from %q rejected, wanted to connect to %q, this is %q",
1104:				s.getGatewayName(), gwName, info.Gateway))
1105:			c.closeConnection(WrongGateway)
1106:			return
1107:		}
```

`sendMsgToGateways` — geo-affinity as implemented: a remote queue group whose name is already in `qgroups` (served locally) is dropped from the list, and if nothing is left **and** there is no plain-subscriber interest, the gateway is skipped entirely.

```go
2611:		} else {
2612:			// Plain sub interest and queue sub results for this account/subject
2613:			psi, qr := gwc.gatewayInterest(accName, subject)
2614:			if !psi && qr == nil {
2615:				continue
2616:			}
2617:			queues = queuesa[:0]
2618:			if qr != nil {
2619:				for i := 0; i < len(qr.qsubs); i++ {
2620:					qsubs := qr.qsubs[i]
2621:					if len(qsubs) > 0 {
2622:						queue := qsubs[0].queue
2623:						if checkLeafQF {
2624:							// Skip any queue that is not in the leaf's queue filter.
2625:							skip := true
2626:							for _, qn := range c.pa.queues {
2627:								if bytes.Equal(queue, qn) {
2628:									skip = false
2629:									break
2630:								}
2631:							}
2632:							if skip {
2633:								continue
2634:							}
2635:							// Now we still need to check that it was not delivered
2636:							// locally by checking the given `qgroups`.
2637:						}
2638:						add := true
2639:						for _, qn := range qgroups {
2640:							if bytes.Equal(queue, qn) {
2641:								add = false
2642:								break
2643:							}
2644:						}
2645:						if add {
2646:							qgroups = append(qgroups, queue)
2647:							queues = append(queues, queue...)
2648:							queues = append(queues, ' ')
2649:						}
2650:					}
2651:				}
2652:			}
2653:			if !psi && len(queues) == 0 {
2654:				continue
2655:			}
```

## `server/client.go` — the queue names the gateway carries, and the fast-producer stall

Why the queue names are collected at all:

```go
4480:	if len(r.psubs)+len(r.qsubs) > 0 {
4481:		flag := pmrNoFlag
4482:		// If there are matching queue subs and we are in gateway mode,
4483:		// we need to keep track of the queue names the messages are
4484:		// delivered to. When sending to the GWs, the RMSG will include
4485:		// those names so that the remote clusters do not deliver messages
4486:		// to their queue subs of the same names.
4487:		if len(r.qsubs) > 0 && c.srv.gateway.enabled &&
4488:			atomic.LoadInt64(&c.srv.gateway.totalQSubs) > 0 {
4489:			flag |= pmrCollectQueueNames
4490:		}
4491:		didDeliver, qnames = c.processMsgResults(acc, r, msg, c.pa.deliver, c.pa.subject, c.pa.reply, flag)
4492:	}
```

The stall constants, the stall itself, and the log line it eventually prints:

```go
124:	// For stalling fast producers
125:	stallClientMinDuration = 2 * time.Millisecond
126:	stallClientMaxDuration = 5 * time.Millisecond
127:	stallTotalAllowed      = 10 * time.Millisecond
128:)
```

```go
3935:	// sending to is in a stalled state, go ahead and wait here
3936:	// with a limit.
3937:	if c.kind == CLIENT && client.out.stc != nil {
3938:		if srv.getOpts().NoFastProducerStall {
3939:			mt.addEgressEvent(client, sub, errMsgTraceFastProdNoStall)
3940:			client.mu.Unlock()
3941:			return false
3942:		}
3943:		client.stalledWait(c)
3944:	}
3945:
```

```go
3711:func (c *client) stalledWait(producer *client) {
3712:	// Check to see if we have exceeded our total wait time per readLoop invocation.
3713:	if producer.in.tst > stallTotalAllowed {
3714:		return
3715:	}
3716:
3717:	// Grab stall channel which the slow consumer will close when caught up.
3718:	stall := c.out.stc
3719:
3720:	// Calculate stall time.
3721:	ttl := stallClientMinDuration
3722:	if c.out.pb >= c.out.mp {
3723:		ttl = stallClientMaxDuration
3724:	}
3725:
3726:	c.mu.Unlock()
3727:	defer c.mu.Lock()
3728:
3729:	// Track per client and total client stalls.
3730:	atomic.AddInt64(&c.stalls, 1)
3731:	if c.srv != nil {
3732:		atomic.AddInt64(&c.srv.stalls, 1)
3733:	}
3734:
3735:	// Now check if we are close to total allowed.
3736:	if producer.in.tst+ttl > stallTotalAllowed {
3737:		ttl = stallTotalAllowed - producer.in.tst
3738:	}
3739:	delay := time.NewTimer(ttl)
3740:	defer delay.Stop()
```

```go
1449:
1450:func (c *client) resetReadLoopStallTime() {
1451:	if c.in.tst >= stallClientMaxDuration {
1452:		c.rateLimitFormatWarnf("Producer was stalled for a total of %v", c.in.tst.Round(time.Millisecond))
1453:	}
1454:	c.in.tst = 0
1455:}
```

## `server/monitor.go` — the two stall counters, neither of which the docs name

```go
133:	Stalls         int64          `json:"stalls,omitempty"`
597:	ci.Stalls = atomic.LoadInt64(&client.stalls)
1279:	StalledClients        int64                  `json:"stalled_clients"`                   // StalledClients is the total number of times that clients have been stalled.
1909:	v.StalledClients = atomic.LoadInt64(&s.stalls)
```

## `server/opts.go` — what a leafnode user may carry, and the only place 7422 is used

`parseLeafUsers` — "a trimmed down version of parseUsers": **four** fields, and `permissions` is not one of them.

```go
3005:// This is a trimmed down version of parseUsers that is adapted
3006:// for the users possibly defined in the authorization{} section
3007:// of leafnodes {}.
3008:func parseLeafUsers(mv any, errors *[]error) ([]*User, error) {
3009:	var (
3010:		tk    token
3011:		lt    token
3012:		users = []*User{}
3013:	)
3014:	defer convertPanicToErrorList(&lt, errors)
3015:
3016:	tk, mv = unwrapValue(mv, &lt)
3017:	// Make sure we have an array
3018:	uv, ok := mv.([]any)
3019:	if !ok {
3020:		return nil, &configErr{tk, fmt.Sprintf("Expected users field to be an array, got %v", mv)}
3021:	}
3022:	for _, u := range uv {
3023:		tk, u = unwrapValue(u, &lt)
3024:		// Check its a map/struct
3025:		um, ok := u.(map[string]any)
3026:		if !ok {
3027:			err := &configErr{tk, fmt.Sprintf("Expected user entry to be a map/struct, got %v", u)}
3028:			*errors = append(*errors, err)
3029:			continue
3030:		}
3031:		user := &User{}
3032:		for k, v := range um {
3033:			tk, v = unwrapValue(v, &lt)
3034:			switch strings.ToLower(k) {
3035:			case "user", "username":
3036:				user.Username = v.(string)
3037:			case "pass", "password":
3038:				user.Password = v.(string)
3039:			case "account":
3040:				// We really want to save just the account name here, but
3041:				// the User object is *Account. So we create an account object
3042:				// but it won't be registered anywhere. The server will just
3043:				// use opts.LeafNode.Users[].Account.Name. Alternatively
3044:				// we need to create internal objects to store u/p and account
3045:				// name and have a server structure to hold that.
3046:				user.Account = NewAccount(v.(string))
3047:			case "proxy_required":
3048:				user.ProxyRequired = v.(bool)
3049:			default:
3050:				if !tk.IsUsedVariable() {
3051:					err := &unknownConfigFieldErr{
3052:						field: k,
3053:						configErr: configErr{
3054:							token: tk,
3055:						},
3056:					}
3057:					*errors = append(*errors, err)
3058:					continue
3059:				}
3060:			}
3061:		}
3062:		users = append(users, user)
3063:	}
3064:	return users, nil
```

`DEFAULT_LEAFNODE_PORT` is used **once**, to fill in a missing port on a remote's URL — never to open a listener:

```go
6091:	// Set baseline connect port for remotes.
6092:	for _, r := range opts.LeafNode.Remotes {
6093:		if r != nil {
6094:			for _, u := range r.URLs {
6095:				if u.Port() == _EMPTY_ {
6096:					u.Host = net.JoinHostPort(u.Host, strconv.Itoa(DEFAULT_LEAFNODE_PORT))
6097:				}
6098:			}
```

The host defaults that *are* applied, and only when a port is already set:

```go
6072:	if opts.LeafNode.Port != 0 {
6073:		if opts.LeafNode.Host == _EMPTY_ {
6074:			opts.LeafNode.Host = DEFAULT_HOST
6075:		}
6076:		if opts.LeafNode.TLSTimeout == 0 {
6077:			opts.LeafNode.TLSTimeout = float64(TLS_TIMEOUT) / float64(time.Second)
6078:		}
```

```go
6140:	if opts.Gateway.Port != 0 {
6141:		if opts.Gateway.Host == _EMPTY_ {
6142:			opts.Gateway.Host = DEFAULT_HOST
6143:		}
6144:		if opts.Gateway.TLSTimeout == 0 {
6145:			opts.Gateway.TLSTimeout = float64(TLS_TIMEOUT) / float64(time.Second)
6146:		}
```

## `server/const.go` — the leafnode constants

```go
160:
161:	// DEFAULT_LEAF_NODE_RECONNECT LeafNode reconnect interval.
162:	DEFAULT_LEAF_NODE_RECONNECT = time.Second
163:
164:	// DEFAULT_LEAF_TLS_TIMEOUT TLS timeout for LeafNodes
165:	DEFAULT_LEAF_TLS_TIMEOUT = 2 * time.Second
166:
167:	// PROTO_SNIPPET_SIZE is the default size of proto to print on parse errors.
202:	// DEFAULT_LEAFNODE_INFO_WAIT Route dial timeout.
203:	DEFAULT_LEAFNODE_INFO_WAIT = 1 * time.Second
204:
205:	// DEFAULT_LEAFNODE_PORT is the default port for remote leafnode connections.
206:	DEFAULT_LEAFNODE_PORT = 7422
207:
```

## Observed on nats-server v2.14.5

**1 · The docs' composed topology config does not start.** `learn/topologies/putting-it-together.md`
prints an `n1-east.conf` with `cluster {}`, `gateway {}`, `leafnodes { listen }` and `jetstream {}`,
and no `system_account`. Typed verbatim:

```
$ nats-server -c n1-east.conf -t
nats-server: configuration file n1-east.conf is valid (sha256:ddbe986aa9531262de2a5a88b79818e203cd2ae564edda74fdb1c1e9dd7c4431)
$ nats-server -c n1-east.conf
nats-server: leaf nodes and gateways (both being defined) require a system account to also be configured
```

**2 · `-t` checks syntax, not options.** Every `validateOptions` failure passes the dry run:

```
$ cat ld.conf
listen: 127.0.0.1:4222
lame_duck_duration: "30s"
lame_duck_grace_period: "60s"
$ nats-server -c ld.conf -t
nats-server: configuration file ld.conf is valid (sha256:bcaec…)
$ nats-server -c ld.conf
nats-server: lame duck grace period (1m0s) should be strictly lower than lame duck duration (30s)
```

**3 · `gateway.port` has no default.**

```
$ cat gw.conf
listen: 127.0.0.1:4222
gateway {
  name: east
  gateways: [ { name: west, urls: ["nats://127.0.0.1:7322"] } ]
}
$ nats-server -c gw.conf -t
nats-server: configuration file gw.conf is valid (sha256:4d532…)
$ nats-server -c gw.conf
nats-server: gateway "east" has no port specified (select -1 for random port)
```

**4 · `leafnodes.port` has no default either — the block just does nothing.**

```
$ cat lf.conf
listen: 127.0.0.1:4222
leafnodes { }
$ nats-server -c lf.conf
[INF] Listening for client connections on 127.0.0.1:4222
$ lsof -nP -iTCP -sTCP:LISTEN -a -p <pid>
nats-serv 30905 m64 6u IPv4 … TCP 127.0.0.1:4222 (LISTEN)
```

Only 4222. No 7422. The same holds for `cluster { name: east }` with no port: no 6222 listener.

**5 · gh#5941's follow-up reproduces exactly.** A hub with the leaf user's permissions in the
**global** `authorization {}` block, and the leaf user itself declared in `leafnodes.authorization`:

```
# hub.conf
leafnodes {
  listen: 127.0.0.1:7422
  authorization { user: "leafuser", password: "test" }
}
authorization {
  users = [
    { user: default_user, permissions: { publish: ">", subscribe: ">" } }
    { user: leafuser, password: "test", permissions: { publish: { deny: ">" }, subscribe: { allow: ">" } } }
  ]
}
no_auth_user: default_user
```

```
$ nats pub cli.demo "hello from leaf node" --server nats://127.0.0.1:4300
Published 20 bytes to "cli.demo"
$ nats sub cli.demo --server nats://127.0.0.1:4222
[#1] Received on "cli.demo"
hello from leaf node
```

The `publish: { deny: ">" }` is not applied: that entry governs *client* connections. Moving the
permissions into `leafnodes.authorization` does not work either — the config is rejected at parse
time, which is `parseLeafUsers` above:

```
nats-server: hub2.conf:8:9: unknown field "permissions"
```
