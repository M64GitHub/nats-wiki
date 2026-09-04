<!-- source: nats-io/nats-server at tag v2.14.6, from the release tarball tools/check-defaults.py keeps in .cache/nats-server-2.14.6/ · read 2026-09-04 -->
# nats-server v2.14.6 — the wire protocol: the `INFO` and `CONNECT` fields, every verb, and the settings behind each `-ERR`

Extracted line ranges, verbatim, with their real line numbers at the tag
(`https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`). Read for step 5 of
`inbox/plan-the-client-side-2026-09-03.md` — the source side of `wiki/reference/wire-protocol.md`,
against which the four pages of `raw/nats-docs/reference/protocols/` were swept. The behaviour is run
in `raw/nats-server-src/wire-protocol-observed-v2.14.6.md`. The complete list of `-ERR` strings is in
`raw/nats-server-src/client-errors-v2.14.6.md` (step 4), which this extract **corrects on one point**
and extends on another; see the two notes below.

What the ranges settle:

- **`INFO` is one struct for all four connection kinds** (`server.go:108–165`). A client is offered
  the first block plus whatever the deployment turns on; the `// Route Specific`, `// Gateways
  Specific` and `// LeafNode Specific` comments in the struct are the server's own division of the
  rest. Six fields a client is sent at v2.14.6 appear in **no** row of the documented table:
  `cluster_dynamic`, `compression`, `connect_info`, `acc_is_sys`, `api_lvl`, `xkey` — and `api_lvl`
  and `xkey` are on the standalone default INFO, not an exotic one.
- **An `INFO` line ends with a space before its CRLF.** `generateInfoJSON` joins
  `["INFO", <json>, "\r\n"]` with `" "` as the separator (`util.go:360–364`), so the third join puts a
  space between the JSON and the CRLF. The gateway path formats `InfoProto = "INFO %s" + _CRLF_`
  (`route.go:129`) instead and has no trailing space. Both were observed.
- **Every field of `CONNECT` is optional, and three of them default to `true` when omitted**:
  `var defaultOpts = ClientOpts{Verbose: true, Pedantic: true, Echo: true}` (`client.go:706`) is the
  value `json.Unmarshal` merges into, so `CONNECT {}` is a *verbose, pedantic, echoing* connection.
  The documented `Required` column has no counterpart in the server.
- **`account` / `new_account` in a CONNECT is now an error**, not a feature: "we used to have this as
  an optional feature for dynamic sandbox environments. Now its considered an error"
  (`client.go:2387–2392`) — `authViolation()`, so the client gets `Authorization Violation`.
- **The connection kind decides the ping behaviour.** `processPingTimer` sends unconditionally for
  `ROUTER`, `GATEWAY` and a *spoke* `LEAF`, and only for a client uses inbound traffic as a proxy for
  a PONG (`client.go:5846–5857`). The ceiling differs too: `routeMaxPingInterval = 30s`
  (`route.go:140`, `:147`) and `gwMaxPingInterval = 15s` (`gateway.go:58`) cap whatever `ping_interval` says.
- **`Stale Connection` is the one `-ERR` that does not go through `sendErr`.** It is written directly
  with `c.enqueueProto([]byte(fmt.Sprintf(errProto, "Stale Connection")))` at `client.go:5867` and
  `client.go:5908`. `client-errors-v2.14.6.md` says an `-ERR` "reaches a client only through `sendErr`
  / `sendErrAndDebug` / `sendErrAndErr`"; that is true of 58 of the 60 sites and **not** of these two.
  The complete count at v2.14.6 is **60**.
- **Five close reasons discard the `-ERR` that was just enqueued.** `markConnAsClosed` sets
  `skipFlushOnClose` for `ReadError`, `WriteError`, `SlowConsumerPendingBytes`,
  `SlowConsumerWriteDeadline` and `TLSHandshakeError` (`client.go:2022–2025`). The third and fourth
  were the finding of step 4; the fifth means **`Secure Connection - TLS Required` can never reach a
  client at v2.14.6** — it is composed at `server.go:3684` and thrown away by the `closeConnection`
  on the next line. Observed: nothing at all arrives (`wire-protocol-observed-v2.14.6.md`, C16).
- **`max_control_line` is multiplied by 16 for every non-client kind** (`parser.go:1276–1284`), so the
  4 KB default is a 64 KB allowance on a route, gateway or leaf — "which matches maxBufSize so a
  single oversized read is caught on the very next parse call".
- **The origin cluster is the *first* token of a route's `LS+` / `LS-`**, not the last
  (`route.go:1729–1740`), and it is a **route** protocol feature (`c.route.lnoc` / `c.route.lnocu`),
  not a leafnode one. A leafnode connection's own `LS+` never carries a cluster.
- **`LS+` takes one or three arguments, never two** (`leafnode.go:2926–2941`): a queue subscription
  must carry its weight. `LMSG` has four shapes, with `+` marking a reply and `|` marking the queue
  list (`leafnode.go:3233–3269`) — and a leaf's **header** messages are `HMSG`, not `LMSG`
  (`parser.go:381–385`).
- **Interest-only is not a fallback any more.** `info.GatewayIOM = true` is set unconditionally
  outside tests, and the comment dates it: "since v2.9.0 … this server will switch all accounts to
  InterestOnly mode when accepting an inbound or when a new account is fetched"
  (`gateway.go:552–558`). `defaultGatewayMaxRUnsubBeforeSwitch = 1000` (`gateway.go:41`) is the older
  path's threshold. Observed: `"gateway_iom":true` on the gateway listener's INFO (A5).
- **The mapped-reply prefix is `_GR_.`** (`gateway.go:49`); `$GR.` is `oldGWReplyPrefix`
  (`gateway.go:43`) and `$GNR.` survives only in comments (`gateway.go:148`, `server.go:158`). The
  form is `_GR_.<6-char cluster hash>.<6-char server hash>.<original reply>` — observed at G.

### `server.go` — `type Info struct`: every INFO field the server can send, and which connection kind it is for

```go
   108	type Info struct {
   109		ID                string   `json:"server_id"`
   110		Name              string   `json:"server_name"`
   111		Version           string   `json:"version"`
   112		Proto             int      `json:"proto"`
   113		GitCommit         string   `json:"git_commit,omitempty"`
   114		GoVersion         string   `json:"go"`
   115		Host              string   `json:"host"`
   116		Port              int      `json:"port"`
   117		Headers           bool     `json:"headers"`
   118		AuthRequired      bool     `json:"auth_required,omitempty"`
   119		TLSRequired       bool     `json:"tls_required,omitempty"`
   120		TLSVerify         bool     `json:"tls_verify,omitempty"`
   121		TLSAvailable      bool     `json:"tls_available,omitempty"`
   122		MaxPayload        int32    `json:"max_payload"`
   123		JetStream         bool     `json:"jetstream,omitempty"`
   124		IP                string   `json:"ip,omitempty"`
   125		CID               uint64   `json:"client_id,omitempty"`
   126		ClientIP          string   `json:"client_ip,omitempty"`
   127		Nonce             string   `json:"nonce,omitempty"`
   128		Cluster           string   `json:"cluster,omitempty"`
   129		Dynamic           bool     `json:"cluster_dynamic,omitempty"`
   130		Domain            string   `json:"domain,omitempty"`
   131		ClientConnectURLs []string `json:"connect_urls,omitempty"`    // Contains URLs a client can connect to.
   132		WSConnectURLs     []string `json:"ws_connect_urls,omitempty"` // Contains URLs a ws client can connect to.
   133		LameDuckMode      bool     `json:"ldm,omitempty"`
   134		Compression       string   `json:"compression,omitempty"`
   135		ConnectInfo       bool     `json:"connect_info,omitempty"`   // When true this is the server INFO response to CONNECT
   136		RemoteAccount     string   `json:"remote_account,omitempty"` // Lets the client or leafnode side know the remote account that they bind to.
   137		IsSystemAccount   bool     `json:"acc_is_sys,omitempty"`     // Indicates if the account is a system account.
   138		JSApiLevel        int      `json:"api_lvl,omitempty"`
   139	
   140		// Route Specific
   141		Import        *SubjectPermission `json:"import,omitempty"`
   142		Export        *SubjectPermission `json:"export,omitempty"`
   143		LNOC          bool               `json:"lnoc,omitempty"`
   144		LNOCU         bool               `json:"lnocu,omitempty"`
   145		InfoOnConnect bool               `json:"info_on_connect,omitempty"` // When true the server will respond to CONNECT with an INFO
   146		RoutePoolSize int                `json:"route_pool_size,omitempty"`
   147		RoutePoolIdx  int                `json:"route_pool_idx,omitempty"`
   148		RouteAccount  string             `json:"route_account,omitempty"`
   149		RouteAccReqID string             `json:"route_acc_add_reqid,omitempty"`
   150		GossipMode    byte               `json:"gossip_mode,omitempty"`
   151	
   152		// Gateways Specific
   153		Gateway           string   `json:"gateway,omitempty"`             // Name of the origin Gateway (sent by gateway's INFO)
   154		GatewayURLs       []string `json:"gateway_urls,omitempty"`        // Gateway URLs in the originating cluster (sent by gateway's INFO)
   155		GatewayURL        string   `json:"gateway_url,omitempty"`         // Gateway URL on that server (sent by route's INFO)
   156		GatewayCmd        byte     `json:"gateway_cmd,omitempty"`         // Command code for the receiving server to know what to do
   157		GatewayCmdPayload []byte   `json:"gateway_cmd_payload,omitempty"` // Command payload when needed
   158		GatewayNRP        bool     `json:"gateway_nrp,omitempty"`         // Uses new $GNR. prefix for mapped replies
   159		GatewayIOM        bool     `json:"gateway_iom,omitempty"`         // Indicate that all accounts will be switched to InterestOnly mode "right away"
   160	
   161		// LeafNode Specific
   162		LeafNodeURLs []string `json:"leafnode_urls,omitempty"` // LeafNode URLs that the server can reconnect to.
   163	
   164		XKey string `json:"xkey,omitempty"` // Public server's x25519 key.
   165	}
```

### `server.go` — the route protocol versions, and the two first-ping intervals

```go
    55	const (
    56		// Interval for the first PING for non client connections.
    57		firstPingInterval = time.Second
    58	
    59		// This is for the first ping for client connections.
    60		firstClientPingInterval = 2 * time.Second
    61	)
    62	
    63	// These are protocol versions sent between server connections: ROUTER, LEAF and
    64	// GATEWAY. We may have protocol versions that have a meaning only for a certain
    65	// type of connections, but we don't have to have separate enums for that.
    66	// However, it is CRITICAL to not change the order of those constants since they
    67	// are exchanged between servers. When adding a new protocol version, add to the
    68	// end of the list, don't try to group them by connection types.
    69	const (
    70		// RouteProtoZero is the original Route protocol from 2009.
    71		// http://nats.io/documentation/internals/nats-protocol/
    72		RouteProtoZero = iota
    73		// RouteProtoInfo signals a route can receive more then the original INFO block.
    74		// This can be used to update remote cluster permissions, etc...
    75		RouteProtoInfo
    76		// RouteProtoV2 is the new route/cluster protocol that provides account support.
    77		RouteProtoV2
    78		// MsgTraceProto indicates that this server understands distributed message tracing.
```

### `server.go` — the eight compression mode names and the `s2_auto` RTT thresholds

```go
   443	// Compression modes.
   444	const (
   445		CompressionNotSupported   = "not supported"
   446		CompressionOff            = "off"
   447		CompressionAccept         = "accept"
   448		CompressionS2Auto         = "s2_auto"
   449		CompressionS2Uncompressed = "s2_uncompressed"
   450		CompressionS2Fast         = "s2_fast"
   451		CompressionS2Better       = "s2_better"
   452		CompressionS2Best         = "s2_best"
   453	)
   454	
   455	// defaultCompressionS2AutoRTTThresholds is the default of RTT thresholds for
   456	// the CompressionS2Auto mode.
   457	var defaultCompressionS2AutoRTTThresholds = []time.Duration{
   458		// [0..10ms] -> CompressionS2Uncompressed
   459		10 * time.Millisecond,
   460		// ]10ms..50ms] -> CompressionS2Fast
   461		50 * time.Millisecond,
   462		// ]50ms..100ms] -> CompressionS2Better
   463		100 * time.Millisecond,
   464		// ]100ms..] -> CompressionS2Best
   465	}
```

### `server.go` — the only place `Secure Connection - TLS Required` is sent: a TLS **handshake timeout**

```go
  3660			updateInfo(&s.info.WSConnectURLs, s.websocket.connectURLs, s.websocket.connectURLsMap)
  3661		}
  3662		if cliUpdated || wsUpdated {
  3663			// Send to all registered clients that support async INFO protocols.
  3664			s.sendAsyncInfoToClients(cliUpdated, wsUpdated)
  3665		}
  3666	}
  3667	
  3668	// Handle closing down a connection when the handshake has timedout.
  3669	func tlsTimeout(c *client, conn *tls.Conn) {
  3670		c.mu.Lock()
  3671		closed := c.isClosed()
  3672		c.mu.Unlock()
  3673		// Check if already closed
  3674		if closed {
  3675			return
  3676		}
  3677		cs := conn.ConnectionState()
  3678		if !cs.HandshakeComplete {
  3679			if c.kind == CLIENT || c.kind == LEAF {
  3680				c.Debugf("TLS handshake timeout")
  3681			} else {
  3682				c.Errorf("TLS handshake timeout")
  3683			}
  3684			c.sendErr("Secure Connection - TLS Required")
  3685			c.closeConnection(TLSHandshakeError)
  3686		}
  3687	}
```

### `util.go` — `generateInfoJSON`: why an INFO line carries a space before its CRLF

```go
   359	// Returns a byte slice for the INFO protocol.
   360	func generateInfoJSON(info *Info) []byte {
   361		b, _ := json.Marshal(info)
   362		pcs := [][]byte{[]byte("INFO"), b, []byte(CR_LF)}
   363		return bytes.Join(pcs, []byte(" "))
   364	}
```

### `route.go` — `InfoProto`, the six subscription verbs as bytes, and the route ping ceiling

```go
    44	)
    45	
    46	// Include the space for the proto
    47	var (
    48		aSubBytes   = []byte{'A', '+', ' '}
    49		aUnsubBytes = []byte{'A', '-', ' '}
    50		rSubBytes   = []byte{'R', 'S', '+', ' '}
    51		rUnsubBytes = []byte{'R', 'S', '-', ' '}
    52		lSubBytes   = []byte{'L', 'S', '+', ' '}
    53		lUnsubBytes = []byte{'L', 'S', '-', ' '}
    54	)
    55	
    56	type route struct {
    57		remoteID     string
    58		remoteName   string
    59		didSolicit   bool
    60		retry        bool
    61		lnoc         bool
    62		lnocu        bool
    63		routeType    RouteType
    64		url          *url.URL
    65		authRequired bool
    66		tlsRequired  bool
    67		jetstream    bool
    68		connectURLs  []string
    69		wsConnURLs   []string
    70		gatewayURL   string
    71		leafnodeURL  string
    72		hash         string
    73		idHash       string
    74		// Location of the route in the slice: s.routes[remoteID][]*client.
    75		// Initialized to -1 on creation, as to indicate that it is not
    76		// added to the list.
    77		poolIdx int
    78		// If this is set, it means that the route is dedicated for this
    79		// account and the account name will not be included in protocols.
    80		accName []byte
    81		// This is set to true if this is a route connection to an old
    82		// server or a server that has pooling completely disabled.
    83		noPool bool
    84		// Selected compression mode, which may be different from the
    85		// server configured mode.
    86		compression string
    87		// Transient value used to set the Info.GossipMode when initiating
    88		// an implicit route and sending to the remote.
    89		gossipMode byte
    90		// This will be set in case of pooling so that a route can trigger
    91		// the creation of the next after receiving a PONG, ensuring
    92		// that authentication did not fail.
    93		startNewRoute *routeInfo
    94	}
    95	
    96	// This contains the information required to create a new route.
    97	type routeInfo struct {
    98		url        *url.URL
    99		rtype      RouteType
   100		gossipMode byte
   101	}
   102	
   103	// Do not change the values/order since they are exchanged between servers.
   104	const (
   105		gossipDefault = byte(iota)
   106		gossipDisabled
   107		gossipOverride
   108	)
   109	
   110	type connectInfo struct {
   111		Echo     bool   `json:"echo"`
   112		Verbose  bool   `json:"verbose"`
   113		Pedantic bool   `json:"pedantic"`
   114		User     string `json:"user,omitempty"`
   115		Pass     string `json:"pass,omitempty"`
   116		TLS      bool   `json:"tls_required"`
   117		Headers  bool   `json:"headers"`
   118		Name     string `json:"name"`
   119		Cluster  string `json:"cluster"`
   120		Dynamic  bool   `json:"cluster_dynamic,omitempty"`
   121		LNOC     bool   `json:"lnoc,omitempty"`
   122		LNOCU    bool   `json:"lnocu,omitempty"` // Support for LS- with origin cluster name
   123		Gateway  string `json:"gateway,omitempty"`
   124	}
   125	
   126	// Route protocol constants
   127	const (
   128		ConProto  = "CONNECT %s" + _CRLF_
   129		InfoProto = "INFO %s" + _CRLF_
   130	)
   131	
   132	const (
   133		// Warning when user configures cluster TLS insecure
   134		clusterTLSInsecureWarning = "TLS certificate chain and hostname of solicited routes will not be verified. DO NOT USE IN PRODUCTION!"
   135	
   136		// The default ping interval is set to 2 minutes, which is fine for client
   137		// connections, etc.. but for route compression, the CompressionS2Auto
   138		// mode uses RTT measurements (ping/pong) to decide which compression level
   139		// to use, we want the interval to not be that high.
   140		defaultRouteMaxPingInterval = 30 * time.Second
   141	)
   142	
   143	// Can be changed for tests
   144	var (
   145		routeConnectDelay    = DEFAULT_ROUTE_CONNECT
   146		routeConnectMaxDelay = DEFAULT_ROUTE_CONNECT_MAX
   147		routeMaxPingInterval = defaultRouteMaxPingInterval
   148	)
```

### `const.go` — the protocol constants and the defaults behind the `-ERR` strings

```go
    67	const (
    68		// VERSION is the current version for the server.
    69		VERSION = "2.14.6"
    70	
    71		// PROTO is the currently supported protocol.
    72		// 0 was the original
    73		// 1 maintains proto 0, adds echo abilities for CONNECT from the client. Clients
    74		// should not send echo unless proto in INFO is >= 1.
    75		PROTO = 1
    76	
    77		// DEFAULT_PORT is the default port for client connections.
    78		DEFAULT_PORT = 4222
    79	
    80		// RANDOM_PORT is the value for port that, when supplied, will cause the
    81		// server to listen on a randomly-chosen available port. The resolved port
    82		// is available via the Addr() method.
    83		RANDOM_PORT = -1
    84	
    85		// DEFAULT_HOST defaults to all interfaces.
    86		DEFAULT_HOST = "0.0.0.0"
    87	
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
   124	
   125		// CR_LF string
   126		CR_LF = "\r\n"
```

### `const.go` — the argument-count ceilings of each verb, and the snippet size

```go
   168		PROTO_SNIPPET_SIZE = 32
   169	
   170		// MAX_CONTROL_LINE_SNIPPET_SIZE is the default size of proto to print on max control line errors.
   171		MAX_CONTROL_LINE_SNIPPET_SIZE = 128
   172	
   173		// MAX_MSG_ARGS Maximum possible number of arguments from MSG proto.
   174		MAX_MSG_ARGS = 4
   175	
   176		// MAX_RMSG_ARGS Maximum possible number of arguments from RMSG proto.
   177		MAX_RMSG_ARGS = 6
   178	
   179		// MAX_HMSG_ARGS Maximum possible number of arguments from HMSG proto.
   180		MAX_HMSG_ARGS = 7
   181	
   182		// MAX_PUB_ARGS Maximum possible number of arguments from PUB proto.
   183		MAX_PUB_ARGS = 3
   184	
   185		// MAX_HPUB_ARGS Maximum possible number of arguments from HPUB proto.
   186		MAX_HPUB_ARGS = 4
   187	
   188		// MAX_RSUB_ARGS Maximum possible number of arguments from a RS+/LS+ proto.
   189		MAX_RSUB_ARGS = 6
   190	
```

### `client.go` — `errProto`, and the three functions that put an `-ERR` on the wire

```go
    92		pingProto = "PING" + _CRLF_
    93		pongProto = "PONG" + _CRLF_
    94		errProto  = "-ERR '%s'" + _CRLF_
    95		okProto   = "+OK" + _CRLF_
    96	)
```

### `client.go` — `ClientProtoZero` / `ClientProtoInfo`

```go
    80	)
    81	
    82	const (
    83		// ClientProtoZero is the original Client protocol from 2009.
    84		// http://nats.io/documentation/internals/nats-protocol/
    85		ClientProtoZero = iota
    86		// ClientProtoInfo signals a client can receive more then the original INFO block.
    87		// This can be used to update clients on other cluster members, etc.
    88		ClientProtoInfo
    89	)
    90	
```

### `client.go` — `type ClientOpts struct` and `defaultOpts`: what a CONNECT may carry, and what an omitted field means

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
```

### `client.go` — `sendErr` / `sendErrAndErr` / `sendErrAndDebug`

```go
  2720	func (c *client) sendErr(err string) {
  2721		c.mu.Lock()
  2722		if c.trace {
  2723			c.traceOutOp("-ERR", []byte(err))
  2724		}
  2725		if !c.isMqtt() {
  2726			c.enqueueProto([]byte(fmt.Sprintf(errProto, err)))
  2727		}
  2728		c.mu.Unlock()
  2729	}
  2730	
  2731	func (c *client) sendOK() {
  2732		c.mu.Lock()
  2733		if c.trace {
  2734			c.traceOutOp("OK", nil)
  2735		}
  2736		c.enqueueProto([]byte(okProto))
  2737		c.mu.Unlock()
  2738	}
  2739	
  2740	func (c *client) processPing() {
  2741		c.mu.Lock()
  2742	
  2743		if c.isClosed() {
  2744			c.mu.Unlock()
  2745			return
```

### `client.go` — `processConnect`: the protocol check, the retired `account` field, and the `+OK`

```go
  2380						return ErrTooManyAccountConnections
  2381					}
  2382				}
  2383				c.authViolation()
  2384				return ErrAuthentication
  2385			}
  2386	
  2387			// Check for Account designation, we used to have this as an optional feature for dynamic
  2388			// sandbox environments. Now its considered an error.
  2389			if accountNew || account != _EMPTY_ {
  2390				c.authViolation()
  2391				return ErrAuthentication
  2392			}
  2393	
  2394			// If no account designation.
  2395			// Do this only for CLIENT and LEAF connections.
  2396			if c.acc == nil && (c.kind == CLIENT || c.kind == LEAF) {
  2397				// By default register with the global account.
  2398				c.registerWithAccount(srv.globalAccount())
  2399			}
  2400	
  2401			// Initialize user info used in logs.
  2402			c.mu.Lock()
  2403			acc := c.acc
  2404			if c.getRawAuthUser() != _EMPTY_ {
  2405				c.ncsUser.Store(c.getAuthUserLabel())
  2406			}
  2407			c.mu.Unlock()
  2408			if acc != nil {
  2409				acc.mu.RLock()
  2410				c.ncsAcc.Store(acc.traceLabel())
  2411				acc.mu.RUnlock()
  2412			}
  2413	
  2414			// Enable logging connection details and auth info for this client.
  2415			if c.kind == CLIENT && firstConnect && c.srv != nil {
  2416				var ncs string
  2417				if c.opts.Version != _EMPTY_ {
  2418					ncs = fmt.Sprintf("v%s", c.opts.Version)
  2419				}
  2420				if c.opts.Lang != _EMPTY_ {
  2421					if c.opts.Version == _EMPTY_ {
  2422						ncs = c.opts.Lang
  2423					} else {
  2424						ncs = fmt.Sprintf("%s:%s", ncs, c.opts.Lang)
  2425					}
  2426				}
  2427				if c.opts.Name != _EMPTY_ {
  2428					if c.opts.Version == _EMPTY_ && c.opts.Lang == _EMPTY_ {
  2429						ncs = c.opts.Name
  2430					} else {
  2431						ncs = fmt.Sprintf("%s:%s", ncs, c.opts.Name)
  2432					}
  2433				}
  2434				var acs string
  2435				accl := c.ncsAcc.Load()
  2436				authUser := c.ncsUser.Load()
  2437				if accl != nil && authUser != nil {
  2438					acs = fmt.Sprintf("%s/%s", accl, authUser)
  2439				}
  2440				switch {
  2441				case ncs != _EMPTY_ && acs != _EMPTY_:
  2442					c.ncs.Store(fmt.Sprintf("%s - %q - %q", c, ncs, acs))
  2443				case ncs != _EMPTY_:
  2444					c.ncs.Store(fmt.Sprintf("%s - %q", c, ncs))
  2445				case acs != _EMPTY_:
  2446					c.ncs.Store(fmt.Sprintf("%s - %q", c, acs))
  2447				}
  2448			}
  2449		}
  2450	
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
  2469			if verbose {
  2470				c.sendOK()
  2471			}
  2472		case ROUTER:
  2473			// Delegate the rest of processing to the route
  2474			return c.processRouteConnect(srv, arg, lang)
  2475		case GATEWAY:
  2476			// Delegate the rest of processing to the gateway
  2477			return c.processGatewayConnect(arg)
  2478		case LEAF:
  2479			// Delegate the rest of processing to the leaf node
  2480			return c.processLeafNodeConnect(srv, arg, lang)
  2481		}
  2482		return nil
  2483	}
  2484	
```

### `client.go` — `markConnAsClosed`: the five reasons whose pending `-ERR` is discarded

```go
  2014	func (c *client) markConnAsClosed(reason ClosedState) {
  2015		// Possibly set skipFlushOnClose flag even if connection has already been
  2016		// mark as closed. The rationale is that a connection may be closed with
  2017		// a reason that justifies a flush (say after sending an -ERR), but then
  2018		// the flushOutbound() gets a write error. If that happens, connection
  2019		// being lost, there is no reason to attempt to flush again during the
  2020		// teardown when the writeLoop exits.
  2021		var skipFlush bool
  2022		switch reason {
  2023		case ReadError, WriteError, SlowConsumerPendingBytes, SlowConsumerWriteDeadline, TLSHandshakeError:
  2024			c.flags.set(skipFlushOnClose)
  2025			skipFlush = true
  2026		case StaleConnection:
  2027			// Track stale connections statistics.
  2028			atomic.AddInt64(&c.srv.staleConnections, 1)
  2029			switch c.kind {
  2030			case CLIENT:
  2031				c.srv.staleStats.clients.Add(1)
  2032			case ROUTER:
  2033				c.srv.staleStats.routes.Add(1)
  2034			case GATEWAY:
  2035				c.srv.staleStats.gateways.Add(1)
  2036			case LEAF:
  2037				c.srv.staleStats.leafs.Add(1)
  2038			}
  2039		}
  2040		if c.flags.isSet(connMarkedClosed) {
```

### `client.go` — the permission-violation strings, exactly as formatted

```go
  5783	func (c *client) pubPermissionViolation(subject []byte) {
  5784		errTxt := fmt.Sprintf("Permissions Violation for Publish to %q", subject)
  5785		if mt, _ := c.isMsgTraceEnabled(); mt != nil {
  5786			mt.setIngressError(errTxt)
  5787		}
  5788		c.sendErr(errTxt)
  5789		c.Errorf("Publish Violation - Subject %q", subject)
  5790	}
  5791	
  5792	func (c *client) subPermissionViolation(sub *subscription) {
  5793		errTxt := fmt.Sprintf("Permissions Violation for Subscription to %q", sub.subject)
  5794		logTxt := fmt.Sprintf("Subscription Violation - Subject %q, SID %s", sub.subject, sub.sid)
  5795	
  5796		if sub.queue != nil {
  5797			errTxt = fmt.Sprintf("Permissions Violation for Subscription to %q using queue %q", sub.subject, sub.queue)
  5798			logTxt = fmt.Sprintf("Subscription Violation - Subject %q, Queue: %q, SID %s", sub.subject, sub.queue, sub.sid)
  5799		}
  5800	
  5801		c.sendErr(errTxt)
  5802		c.Errorf(logTxt)
  5803	}
  5804	
  5805	func (c *client) replySubjectViolation(reply []byte) {
  5806		errTxt := fmt.Sprintf("Permissions Violation for Publish with Reply of %q", reply)
  5807		if mt, _ := c.isMsgTraceEnabled(); mt != nil {
  5808			mt.setIngressError(errTxt)
  5809		}
  5810		c.sendErr(errTxt)
  5811		c.Errorf("Publish Violation - Reply %q", reply)
  5812	}
  5813	
  5814	func (c *client) maxTokensViolation(sub *subscription) {
  5815		errTxt := fmt.Sprintf("Permissions Violation for Subscription to %q, too many tokens", sub.subject)
  5816		logTxt := fmt.Sprintf("Subscription Violation Too Many Tokens - Subject %q, SID %s", sub.subject, sub.sid)
  5817		c.sendErr(errTxt)
  5818		c.Errorf(logTxt)
  5819	}
  5820	
```

### `client.go` — `processPingTimer`: no ping delay for ROUTER, GATEWAY or a spoke LEAF

```go
  5821	func (c *client) processPingTimer() {
  5822		c.mu.Lock()
  5823		c.ping.tmr = nil
  5824		// Check if connection is still opened
  5825		if c.isClosed() {
  5826			c.mu.Unlock()
  5827			return
  5828		}
  5829	
  5830		c.Debugf("%s Ping Timer", c.kindString())
  5831	
  5832		var sendPing bool
  5833	
  5834		opts := c.srv.getOpts()
  5835		pingInterval := opts.PingInterval
  5836		if c.kind == ROUTER && opts.Cluster.PingInterval > 0 {
  5837			pingInterval = opts.Cluster.PingInterval
  5838		}
  5839		if c.isWebsocket() && opts.Websocket.PingInterval > 0 {
  5840			pingInterval = opts.Websocket.PingInterval
  5841		}
  5842		pingInterval = adjustPingInterval(c.kind, pingInterval)
  5843		now := time.Now()
  5844		needRTT := c.rtt == 0 || now.Sub(c.rttStart) > DEFAULT_RTT_MEASUREMENT_INTERVAL
  5845	
  5846		// Do not delay PINGs for ROUTER, GATEWAY or spoke LEAF connections.
  5847		if c.kind == ROUTER || c.kind == GATEWAY || c.isSpokeLeafNode() {
  5848			sendPing = true
  5849		} else {
  5850			// If we received client data or a ping from the other side within the PingInterval,
  5851			// then there is no need to send a ping.
  5852			if delta := now.Sub(c.lastIn); delta < pingInterval && !needRTT {
  5853				c.Debugf("Delaying PING due to remote client data or ping %v ago", delta.Round(time.Second))
  5854			} else {
  5855				sendPing = true
  5856			}
  5857		}
  5858	
  5859		if sendPing {
  5860			// Check for violation
  5861			maxPingsOut := opts.MaxPingsOut
  5862			if c.kind == ROUTER && opts.Cluster.MaxPingsOut > 0 {
  5863				maxPingsOut = opts.Cluster.MaxPingsOut
  5864			}
  5865			if c.ping.out+1 > maxPingsOut {
  5866				c.Debugf("Stale Client Connection - Closing")
  5867				c.enqueueProto([]byte(fmt.Sprintf(errProto, "Stale Connection")))
  5868				c.mu.Unlock()
  5869				c.closeConnection(StaleConnection)
  5870				return
  5871			}
  5872			// Send PING
  5873			c.sendPing()
  5874		}
  5875	
  5876		// Reset to fire again.
  5877		c.setPingTimer()
  5878		c.mu.Unlock()
  5879	}
  5880	
  5881	// Returns the smallest value between the given `d` and some max value
  5882	// based on the connection kind.
  5883	func adjustPingInterval(kind int, d time.Duration) time.Duration {
  5884		switch kind {
  5885		case ROUTER:
  5886			if d > routeMaxPingInterval {
  5887				return routeMaxPingInterval
  5888			}
  5889		case GATEWAY:
  5890			if d > gatewayMaxPingInterval {
  5891				return gatewayMaxPingInterval
  5892			}
  5893		}
  5894		return d
  5895	}
```

### `client.go` — `watchForStaleConnection`: the second place `Stale Connection` is enqueued

```go
  5897	// This is used when a connection cannot yet start to send PINGs because
  5898	// the remote would not be able to handle them (case of compression,
  5899	// or outbound gateway, etc...), but we still want to close the connection
  5900	// if the timer has not been reset by the time we reach the time equivalent
  5901	// to have sent the max number of pings.
  5902	//
  5903	// Lock should be held
  5904	func (c *client) watchForStaleConnection(pingInterval time.Duration, pingMax int) {
  5905		c.ping.tmr = time.AfterFunc(pingInterval*time.Duration(pingMax+1), func() {
  5906			c.mu.Lock()
  5907			c.Debugf("Stale Client Connection - Closing")
  5908			c.enqueueProto([]byte(fmt.Sprintf(errProto, "Stale Connection")))
  5909			c.mu.Unlock()
  5910			c.closeConnection(StaleConnection)
  5911		})
  5912	}
```

### `client.go` — `setFirstPingTimer`: the shortened and randomised first ping

```go
  6994	func (c *client) setFirstPingTimer() {
  6995		s := c.srv
  6996		if s == nil {
  6997			return
  6998		}
  6999		opts := s.getOpts()
  7000		d := opts.PingInterval
  7001	
  7002		if c.kind == ROUTER && opts.Cluster.PingInterval > 0 {
  7003			d = opts.Cluster.PingInterval
  7004		}
  7005		if c.isWebsocket() && opts.Websocket.PingInterval > 0 {
  7006			d = opts.Websocket.PingInterval
  7007		}
  7008		if !opts.DisableShortFirstPing {
  7009			if c.kind != CLIENT {
  7010				if d > firstPingInterval {
  7011					d = firstPingInterval
  7012				}
  7013				d = adjustPingInterval(c.kind, d)
  7014			} else if d > firstClientPingInterval {
  7015				d = firstClientPingInterval
  7016			}
  7017		}
  7018		// We randomize the first one by an offset up to 20%, e.g. 2m ~= max 24s.
  7019		addDelay := rand.Int63n(int64(d / 5))
  7020		d += time.Duration(addDelay)
  7021		// In the case of ROUTER/LEAF and when compression is configured, it is possible
  7022		// that this timer was already set, but just to detect a stale connection
  7023		// since we have to delay the first PING after compression negotiation
  7024		// occurred.
  7025		if c.ping.tmr != nil {
  7026			c.ping.tmr.Stop()
  7027		}
  7028		c.ping.tmr = time.AfterFunc(d, c.processPingTimer)
  7029	}
```

### `parser.go` — `overMaxControlLineLimit`: the ×16 allowance for non-client kinds, and the parse-error string

```go
  1274	func (c *client) overMaxControlLineLimit(arg []byte, mcl int32) error {
  1275		// Widen to int64 so mcl*16 cannot overflow for large configured values.
  1276		effective := int64(mcl)
  1277		if c.kind != CLIENT {
  1278			// This is the upper bound on argBuf length for LEAF, ROUTER, and GATEWAY connections.
  1279			// These kinds need longer arg lines than CLIENT (which is capped at mcl=4096 by default)
  1280			// because cluster/leaf frames encode origin, account, reply, and queue groups.
  1281			// By default, this is 64 KB, which matches maxBufSize so a single oversized read
  1282			// is caught on the very next parse call.
  1283			effective *= 16
  1284		}
  1285		if int64(len(arg)) > effective {
  1286			err := NewErrorCtx(ErrMaxControlLine, "State %d, max_control_line %d, Buffer len %d (snip: %s...)",
  1287				c.state, int(mcl), len(c.argBuf), protoSnippet(0, MAX_CONTROL_LINE_SNIPPET_SIZE, arg))
  1288			c.sendErr(err.Error())
  1289			c.closeConnection(MaxControlLineExceeded)
  1290			return err
  1291		}
  1292		return nil
  1293	}
```

### `route.go` — `type connectInfo struct`: what a route's CONNECT carries

```go
   110	type connectInfo struct {
   111		Echo     bool   `json:"echo"`
   112		Verbose  bool   `json:"verbose"`
   113		Pedantic bool   `json:"pedantic"`
   114		User     string `json:"user,omitempty"`
   115		Pass     string `json:"pass,omitempty"`
   116		TLS      bool   `json:"tls_required"`
   117		Headers  bool   `json:"headers"`
   118		Name     string `json:"name"`
   119		Cluster  string `json:"cluster"`
   120		Dynamic  bool   `json:"cluster_dynamic,omitempty"`
   121		LNOC     bool   `json:"lnoc,omitempty"`
   122		LNOCU    bool   `json:"lnocu,omitempty"` // Support for LS- with origin cluster name
   123		Gateway  string `json:"gateway,omitempty"`
   124	}
```

### `route.go` — `addRouteSubOrUnsubProtoToBuf`: the origin cluster is the **first** token of `LS+` / `LS-`

```go
  1726	func (c *client) addRouteSubOrUnsubProtoToBuf(buf []byte, accName string, sub *subscription, isSubProto bool) []byte {
  1727		// If we have an origin cluster and the other side supports leafnode origin clusters
  1728		// send an LS+/LS- version instead.
  1729		if len(sub.origin) > 0 && c.route.lnoc {
  1730			if isSubProto {
  1731				buf = append(buf, lSubBytes...)
  1732				buf = append(buf, sub.origin...)
  1733				buf = append(buf, ' ')
  1734			} else {
  1735				buf = append(buf, lUnsubBytes...)
  1736				if c.route.lnocu {
  1737					buf = append(buf, sub.origin...)
  1738					buf = append(buf, ' ')
  1739				}
  1740			}
  1741		} else {
  1742			if isSubProto {
  1743				buf = append(buf, rSubBytes...)
  1744			} else {
  1745				buf = append(buf, rUnsubBytes...)
  1746			}
  1747		}
  1748		if len(c.route.accName) == 0 {
  1749			buf = append(buf, accName...)
  1750			buf = append(buf, ' ')
  1751		}
  1752		buf = append(buf, sub.subject...)
  1753		if len(sub.queue) > 0 {
  1754			buf = append(buf, ' ')
  1755			buf = append(buf, sub.queue...)
  1756			// Send our weight if we are a sub proto
  1757			if isSubProto {
  1758				buf = append(buf, ' ')
  1759				var b [12]byte
  1760				var i = len(b)
  1761				for l := sub.qw; l > 0; l /= 10 {
  1762					i--
  1763					b[i] = digits[l%10]
  1764				}
  1765				buf = append(buf, b[i:]...)
  1766			}
  1767		}
  1768		buf = append(buf, CR_LF...)
  1769		return buf
  1770	}
```

### `route.go` — `processRouteConnect`: the wrong-port, wrong-kind and cluster-name rejections

```go
  3021	func (c *client) processRouteConnect(srv *Server, arg []byte, lang string) error {
  3022		// Way to detect clients that incorrectly connect to the route listen
  3023		// port. Client provide Lang in the CONNECT protocol while ROUTEs don't.
  3024		if lang != "" {
  3025			c.sendErrAndErr(ErrClientConnectedToRoutePort.Error())
  3026			c.closeConnection(WrongPort)
  3027			return ErrClientConnectedToRoutePort
  3028		}
  3029		// Unmarshal as a route connect protocol
  3030		proto := &connectInfo{}
  3031	
  3032		if err := json.Unmarshal(arg, proto); err != nil {
  3033			return err
  3034		}
  3035		// Reject if this has Gateway which means that it would be from a gateway
  3036		// connection that incorrectly connects to the Route port.
  3037		if proto.Gateway != "" {
  3038			errTxt := fmt.Sprintf("Rejecting connection from gateway %q on the Route port", proto.Gateway)
  3039			c.Errorf(errTxt)
  3040			c.sendErr(errTxt)
  3041			c.closeConnection(WrongGateway)
  3042			return ErrWrongGateway
  3043		}
  3044	
  3045		if srv == nil {
  3046			return ErrServerNotRunning
  3047		}
  3048	
  3049		perms := srv.getOpts().Cluster.Permissions
  3050		clusterName := srv.ClusterName()
  3051	
  3052		// If we have a cluster name set, make sure it matches ours.
  3053		if proto.Cluster != clusterName {
  3054			shouldReject := true
  3055			// If we have a dynamic name we will do additional checks.
  3056			if srv.isClusterNameDynamic() {
  3057				if !proto.Dynamic || strings.Compare(clusterName, proto.Cluster) < 0 {
  3058					// We will take on their name since theirs is configured or higher then ours.
  3059					srv.setClusterName(proto.Cluster)
  3060					if !proto.Dynamic {
  3061						srv.optsMu.Lock()
  3062						srv.opts.Cluster.Name = proto.Cluster
  3063						srv.optsMu.Unlock()
  3064					}
  3065					c.mu.Lock()
  3066					remoteID := c.opts.Name
  3067					c.mu.Unlock()
  3068					srv.removeAllRoutesExcept(remoteID)
  3069					shouldReject = false
  3070				}
  3071			}
  3072			if shouldReject {
  3073				errTxt := fmt.Sprintf("Rejecting connection, cluster name %q does not match %q", proto.Cluster, clusterName)
  3074				c.Errorf(errTxt)
  3075				c.sendErr(errTxt)
  3076				c.closeConnection(ClusterNameConflict)
  3077				return ErrClusterNameRemoteConflict
  3078			}
  3079		}
  3080	
```

### `gateway.go` — the gateway constants: both reply prefixes, the interest-only threshold, the ping ceiling, the three `gateway_cmd` codes and the three interest modes

```go
    36		defaultSolicitGatewaysDelay         = time.Second
    37		defaultGatewayConnectDelay          = time.Second
    38		defaultGatewayConnectMaxDelay       = 30 * time.Second
    39		defaultGatewayReconnectDelay        = time.Second
    40		defaultGatewayRecentSubExpiration   = 2 * time.Second
    41		defaultGatewayMaxRUnsubBeforeSwitch = 1000
    42	
    43		oldGWReplyPrefix    = "$GR."
    44		oldGWReplyPrefixLen = len(oldGWReplyPrefix)
    45		oldGWReplyStart     = oldGWReplyPrefixLen + 5 // len of prefix above + len of hash (4) + "."
    46	
    47		// The new prefix is "_GR_.<cluster>.<server>." where <cluster> is 6 characters
    48		// hash of origin cluster name and <server> is 6 characters hash of origin server pub key.
    49		gwReplyPrefix    = "_GR_."
    50		gwReplyPrefixLen = len(gwReplyPrefix)
    51		gwHashLen        = 6
    52		gwClusterOffset  = gwReplyPrefixLen
    53		gwServerOffset   = gwClusterOffset + gwHashLen + 1
    54		gwSubjectOffset  = gwServerOffset + gwHashLen + 1
    55	
    56		// Gateway connections send PINGs regardless of traffic. The interval is
    57		// either Options.PingInterval or this value, whichever is the smallest.
    58		gwMaxPingInterval = 15 * time.Second
    59	)
    60	
    61	var (
    62		gatewayConnectDelay          = defaultGatewayConnectDelay
    63		gatewayConnectMaxDelay       = defaultGatewayConnectMaxDelay
    64		gatewayReconnectDelay        = defaultGatewayReconnectDelay
    65		gatewayMaxRUnsubBeforeSwitch = defaultGatewayMaxRUnsubBeforeSwitch
    66		gatewaySolicitDelay          = int64(defaultSolicitGatewaysDelay)
    67		gatewayMaxPingInterval       = gwMaxPingInterval
    68	)
    69	
    70	// Warning when user configures gateway TLS insecure
    71	const gatewayTLSInsecureWarning = "TLS certificate chain and hostname of solicited gateways will not be verified. DO NOT USE IN PRODUCTION!"
    72	
    73	// SetGatewaysSolicitDelay sets the initial delay before gateways
    74	// connections are initiated.
    75	// Used by tests.
    76	func SetGatewaysSolicitDelay(delay time.Duration) {
    77		atomic.StoreInt64(&gatewaySolicitDelay, int64(delay))
    78	}
    79	
    80	// ResetGatewaysSolicitDelay resets the initial delay before gateways
    81	// connections are initiated to its default values.
    82	// Used by tests.
    83	func ResetGatewaysSolicitDelay() {
    84		atomic.StoreInt64(&gatewaySolicitDelay, int64(defaultSolicitGatewaysDelay))
    85	}
    86	
    87	const (
    88		gatewayCmdGossip          byte = 1
    89		gatewayCmdAllSubsStart    byte = 2
    90		gatewayCmdAllSubsComplete byte = 3
    91	)
    92	
    93	// GatewayInterestMode represents an account interest mode for a gateway connection
    94	type GatewayInterestMode byte
    95	
    96	// GatewayInterestMode values
    97	const (
    98		// optimistic is the default mode where a cluster will send
    99		// to a gateway unless it is been told that there is no interest
   100		// (this is for plain subscribers only).
   101		Optimistic GatewayInterestMode = iota
   102		// transitioning is when a gateway has to send too many
   103		// no interest on subjects to the remote and decides that it is
   104		// now time to move to modeInterestOnly (this is on a per account
   105		// basis).
   106		Transitioning
   107		// interestOnly means that a cluster sends all it subscriptions
   108		// interest to the gateway, which in return does not send a message
   109		// unless it knows that there is explicit interest.
   110		InterestOnly
   111	)
   112	
```

### `gateway.go` — `gateway_iom`: since v2.9.0 every account goes to interest-only at once

```go
   540			ID:           s.info.ID,
   541			Name:         opts.ServerName,
   542			Version:      s.info.Version,
   543			AuthRequired: authRequired,
   544			TLSRequired:  tlsReq,
   545			TLSVerify:    tlsReq,
   546			MaxPayload:   s.info.MaxPayload,
   547			Gateway:      opts.Gateway.Name,
   548			GatewayNRP:   true,
   549			Headers:      s.supportsHeaders(),
   550			Proto:        s.getServerProto(),
   551		}
   552		// Unless in some tests we want to keep the old behavior, we are now
   553		// (since v2.9.0) indicate that this server will switch all accounts
   554		// to InterestOnly mode when accepting an inbound or when a new
   555		// account is fetched.
   556		if !gwDoNotForceInterestOnlyMode {
   557			info.GatewayIOM = true
   558		}
   559	
   560		// If we have selected a random port...
```

### `gateway.go` — the wrong-port and wrong-gateway rejections on an outbound gateway

```go
  1093					}
  1094					s.processImplicitGateway(info)
  1095					return
  1096				}
  1097				// Otherwise, this is a failure...
  1098				// We are reporting this error in the log...
  1099				c.Errorf("Failing connection to gateway %q, remote gateway name is %q",
  1100					gwName, info.Gateway)
  1101				// ...and sending this back to the remote so that the error
  1102				// makes more sense in the remote server's log.
  1103				c.sendErr(fmt.Sprintf("Connection from %q rejected, wanted to connect to %q, this is %q",
  1104					s.getGatewayName(), gwName, info.Gateway))
  1105				c.closeConnection(WrongGateway)
  1106				return
  1107			}
  1108	
  1109			// Check for duplicate server name with servers in our cluster
  1110			if s.isDuplicateServerName(info.Name) {
```

### `leafnode.go` — the leafnode constants: `$LDS.`, the three 30 s delays and the WebSocket path

```go
    36		"time"
    37	
    38		"github.com/klauspost/compress/s2"
    39		"github.com/nats-io/jwt/v2"
    40		"github.com/nats-io/nkeys"
    41		"github.com/nats-io/nuid"
    42	)
    43	
    44	const (
    45		// Warning when user configures leafnode TLS insecure
    46		leafnodeTLSInsecureWarning = "TLS certificate chain and hostname of solicited leafnodes will not be verified. DO NOT USE IN PRODUCTION!"
    47	
    48		// When a loop is detected, delay the reconnect of solicited connection.
    49		leafNodeReconnectDelayAfterLoopDetected = 30 * time.Second
    50	
    51		// When a server receives a message causing a permission violation, the
    52		// connection is closed and it won't attempt to reconnect for that long.
    53		leafNodeReconnectAfterPermViolation = 30 * time.Second
    54	
    55		// When we have the same cluster name as the hub.
    56		leafNodeReconnectDelayAfterClusterNameSame = 30 * time.Second
    57	
    58		// Prefix for loop detection subject
    59		leafNodeLoopDetectionSubjectPrefix = "$LDS."
    60	
    61		// Path added to URL to indicate to WS server that the connection is a
    62		// LEAF connection as opposed to a CLIENT.
```

### `leafnode.go` — `type leafConnectInfo struct`: the leaf CONNECT's real JSON tags

```go
  2171	type leafConnectInfo struct {
  2172		Version   string   `json:"version,omitempty"`
  2173		Nkey      string   `json:"nkey,omitempty"`
  2174		JWT       string   `json:"jwt,omitempty"`
  2175		Sig       string   `json:"sig,omitempty"`
  2176		User      string   `json:"user,omitempty"`
  2177		Pass      string   `json:"pass,omitempty"`
  2178		Token     string   `json:"auth_token,omitempty"`
  2179		ID        string   `json:"server_id,omitempty"`
  2180		Domain    string   `json:"domain,omitempty"`
  2181		Name      string   `json:"name,omitempty"`
  2182		Hub       bool     `json:"is_hub,omitempty"`
  2183		Cluster   string   `json:"cluster,omitempty"`
  2184		Headers   bool     `json:"headers,omitempty"`
  2185		JetStream bool     `json:"jetstream,omitempty"`
  2186		DenyPub   []string `json:"deny_pub,omitempty"`
  2187		Isolate   bool     `json:"isolate,omitempty"`
  2188	
  2189		// There was an existing field called:
  2190		// >> Comp bool `json:"compression,omitempty"`
  2191		// that has never been used. With support for compression, we now need
  2192		// a field that is a string. So we use a different json tag:
  2193		Compression string `json:"compress_mode,omitempty"`
  2194	
  2195		// Just used to detect wrong connection attempts.
  2196		Gateway string `json:"gateway,omitempty"`
  2197	
  2198		// Tells the accept side which account the remote is binding to.
  2199		RemoteAccount string `json:"remote_account,omitempty"`
  2200	
  2201		// The accept side of a LEAF connection, unlike ROUTER and GATEWAY, receives
  2202		// only the CONNECT protocol, and no INFO. So we need to send the protocol
  2203		// version as part of the CONNECT. It will indicate if a connection supports
  2204		// some features, such as message tracing.
  2205		// We use `protocol` as the JSON tag, so this is automatically unmarshal'ed
  2206		// in the low level process CONNECT.
  2207		Proto int `json:"protocol,omitempty"`
  2208	}
```

### `leafnode.go` — `processLeafNodeConnect`: the six rejections, in the order they are checked

```go
  2213	func (c *client) processLeafNodeConnect(s *Server, arg []byte, lang string) error {
  2214		// Way to detect clients that incorrectly connect to the route listen
  2215		// port. Client provided "lang" in the CONNECT protocol while LEAFNODEs don't.
  2216		if lang != _EMPTY_ {
  2217			c.sendErrAndErr(ErrClientConnectedToLeafNodePort.Error())
  2218			c.closeConnection(WrongPort)
  2219			return ErrClientConnectedToLeafNodePort
  2220		}
  2221	
  2222		// Unmarshal as a leaf node connect protocol
  2223		proto := &leafConnectInfo{}
  2224		if err := json.Unmarshal(arg, proto); err != nil {
  2225			return err
  2226		}
  2227	
  2228		// Reject a cluster that contains spaces.
  2229		if proto.Cluster != _EMPTY_ && strings.Contains(proto.Cluster, " ") {
  2230			c.sendErrAndErr(ErrClusterNameHasSpaces.Error())
  2231			c.closeConnection(ProtocolViolation)
  2232			return ErrClusterNameHasSpaces
  2233		}
  2234	
  2235		// Check for cluster name collisions.
  2236		if cn := s.cachedClusterName(); cn != _EMPTY_ && proto.Cluster != _EMPTY_ && proto.Cluster == cn {
  2237			c.sendErrAndErr(ErrLeafNodeHasSameClusterName.Error())
  2238			c.closeConnection(ClusterNamesIdentical)
  2239			return ErrLeafNodeHasSameClusterName
  2240		}
  2241	
  2242		// Reject if this has Gateway which means that it would be from a gateway
  2243		// connection that incorrectly connects to the leafnode port.
  2244		if proto.Gateway != _EMPTY_ {
  2245			errTxt := fmt.Sprintf("Rejecting connection from gateway %q on the leafnode port", proto.Gateway)
  2246			c.Errorf(errTxt)
  2247			c.sendErr(errTxt)
  2248			c.closeConnection(WrongGateway)
  2249			return ErrWrongGateway
  2250		}
  2251	
  2252		if mv := s.getOpts().LeafNode.MinVersion; mv != _EMPTY_ {
  2253			major, minor, update, _ := versionComponents(mv)
  2254			if !versionAtLeast(proto.Version, major, minor, update) {
  2255				// Send back an INFO so recent remote servers process the rejection
  2256				// cleanly, then close immediately. The soliciting side applies the
  2257				// reconnect delay when it processes the error.
  2258				s.sendPermsAndAccountInfo(c)
  2259				c.sendErrAndErr(fmt.Sprintf("%s %q", ErrLeafNodeMinVersionRejected, mv))
  2260				c.closeConnection(MinimumVersionRequired)
  2261				return ErrMinimumVersionRequired
  2262			}
  2263		}
  2264	
  2265		// Check if this server supports headers.
```

### `leafnode.go` — `processLeafSub`: `LS+` takes one or three arguments, never two

```go
  2909	func (c *client) processLeafSub(argo []byte) (err error) {
  2910		// Indicate activity.
  2911		c.in.subs++
  2912	
  2913		srv := c.srv
  2914		if srv == nil {
  2915			return nil
  2916		}
  2917	
  2918		// Copy so we do not reference a potentially large buffer
  2919		arg := make([]byte, len(argo))
  2920		copy(arg, argo)
  2921	
  2922		args := splitArg(arg)
  2923		sub := &subscription{client: c}
  2924	
  2925		delta := int32(1)
  2926		switch len(args) {
  2927		case 1:
  2928			sub.queue = nil
  2929		case 3:
  2930			sub.queue = args[1]
  2931			sub.qw = int32(parseSize(args[2]))
  2932			// TODO: (ik) We should have a non empty queue name and a queue
  2933			// weight >= 1. For 2.11, we may want to return an error if that
  2934			// is not the case, but for now just overwrite `delta` if queue
  2935			// weight is greater than 1 (it is possible after a reconnect/
  2936			// server restart to receive a queue weight > 1 for a new sub).
  2937			if sub.qw > 1 {
  2938				delta = sub.qw
  2939			}
  2940		default:
  2941			return fmt.Errorf("processLeafSub Parse Error: '%s'", arg)
  2942		}
  2943		sub.subject = args[0]
  2944	
  2945		c.mu.Lock()
```

### `leafnode.go` — `processLeafMsgArgs`: the four `LMSG` shapes and the `+` / `|` indicators

```go
  3211	func (c *client) processLeafMsgArgs(arg []byte) error {
  3212		// Unroll splitArgs to avoid runtime/heap issues
  3213		args := c.argsa[:0]
  3214		start := -1
  3215		for i, b := range arg {
  3216			switch b {
  3217			case ' ', '\t', '\r', '\n':
  3218				if start >= 0 {
  3219					args = append(args, arg[start:i])
  3220					start = -1
  3221				}
  3222			default:
  3223				if start < 0 {
  3224					start = i
  3225				}
  3226			}
  3227		}
  3228		if start >= 0 {
  3229			args = append(args, arg[start:])
  3230		}
  3231	
  3232		c.pa.arg = arg
  3233		switch len(args) {
  3234		case 0, 1:
  3235			return fmt.Errorf("processLeafMsgArgs Parse Error: '%s'", args)
  3236		case 2:
  3237			c.pa.reply = nil
  3238			c.pa.queues = nil
  3239			c.pa.szb = args[1]
  3240			c.pa.size = parseSize(args[1])
  3241		case 3:
  3242			c.pa.reply = args[1]
  3243			c.pa.queues = nil
  3244			c.pa.szb = args[2]
  3245			c.pa.size = parseSize(args[2])
  3246		default:
  3247			// args[1] is our reply indicator. Should be + or | normally.
  3248			if len(args[1]) != 1 {
  3249				return fmt.Errorf("processLeafMsgArgs Bad or Missing Reply Indicator: '%s'", args[1])
  3250			}
  3251			switch args[1][0] {
  3252			case '+':
  3253				c.pa.reply = args[2]
  3254			case '|':
  3255				c.pa.reply = nil
  3256			default:
  3257				return fmt.Errorf("processLeafMsgArgs Bad or Missing Reply Indicator: '%s'", args[1])
  3258			}
  3259			// Grab size.
  3260			c.pa.szb = args[len(args)-1]
  3261			c.pa.size = parseSize(c.pa.szb)
  3262	
  3263			// Grab queue names.
  3264			if c.pa.reply != nil {
  3265				c.pa.queues = args[3 : len(args)-1]
  3266			} else {
  3267				c.pa.queues = args[2 : len(args)-1]
  3268			}
  3269		}
  3270		if c.pa.size < 0 {
  3271			return fmt.Errorf("processLeafMsgArgs Bad or Missing Size: '%s'", args)
  3272		}
  3273		maxPayload := atomic.LoadInt32(&c.mpay)
  3274		if maxPayload != jwt.NoLimit && int64(c.pa.size) > int64(maxPayload) {
  3275			c.maxPayloadViolation(c.pa.size, maxPayload)
  3276			return ErrMaxPayload
  3277		}
  3278	
  3279		// Common ones processed after check for arg length
  3280		c.pa.subject = args[0]
  3281	
  3282		return nil
  3283	}
```

