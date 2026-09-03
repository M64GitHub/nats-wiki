<!-- source: https://github.com/nats-io/prometheus-nats-exporter at tag v0.20.2 — collector/*.go, exporter/exporter.go and main.go fetched from raw.githubusercontent.com · fetched 2026-09-03 -->
# prometheus-nats-exporter v0.20.2 — how the series are named, which collectors exist, and what each reads

Verbatim line ranges from the tagged source, with the real line numbers at tag v0.20.2, so each claim on
`wiki/reference/metrics.md` links to `https://github.com/nats-io/prometheus-nats-exporter/blob/v0.20.2/<file>#L<line>`.
Read for phase E step 3 (`inbox/plan-the-reference-layer-2026-09-03.md`). The behavioural half — every
series the exporter produced when scraped against a v2.14.6 lab cluster — is `metrics-observed-v0.20.2.md`
beside this file. Apache-2.0.

Two kinds of collector exist. The **generic** one (`collector.go`) fetches an endpoint's JSON and turns
every numeric field into a gauge named `<namespace>_<endpoint>_<flattened_field>`; it is used for `varz`,
`routez` and `subsz`. The **hand-written** ones (`jsz.go`, `connz.go`, `healthz.go`, `accountz.go`,
`accstatz.go`, `gatewayz.go`, `leafz.go`) declare each series and its labels explicitly. The namespace is
`gnatsd` for the core collectors and `jetstream` for the JetStream one unless `-prefix` replaces both.


## collector.go — the two namespaces, the generic gauge, the flattening rule


### `collector.go` lines 29–36

The two default namespaces. The comment explains why the core one is still `gnatsd`.

```go
   29	// System Name Variables
   30	var (
   31		// use gnatsd for backward compatibility. Changing would require users to
   32		// change their dashboards or other applications that rely on the
   33		// prometheus metric names.
   34		CoreSystem      = "gnatsd"
   35		JetStreamSystem = "jetstream"
   36	)
```


### `collector.go` lines 61–105

Every generic series is a `GaugeVec` labelled `server_id`; a string field becomes a "label gauge" whose value is 1 and whose `value` label carries the string. `prefix` (the `-prefix` flag) replaces the namespace.

```go
   61	// newPrometheusGaugeVec creates a custom GaugeVec
   62	// Based on our current integration, we're going to treat all metrics as gauges.
   63	// We are going to call the set message on the gauge when we receive an updated
   64	// metrics pull.
   65	func newPrometheusGaugeVec(system, subsystem, name, help, prefix string) (metric *prometheus.GaugeVec) {
   66		if help == "" {
   67			help = name
   68		}
   69		namespace := system
   70		if prefix != "" {
   71			namespace = prefix
   72		}
   73		opts := prometheus.GaugeOpts{
   74			Namespace: namespace,
   75			Subsystem: subsystem,
   76			Name:      name,
   77			Help:      help,
   78		}
   79		metric = prometheus.NewGaugeVec(opts, []string{"server_id"})
   80	
   81		Tracef("Created metric: %s, %s, %s, %s", namespace, subsystem, name, help)
   82		return metric
   83	}
   84	
   85	// newLabelGauge creates a dummy gauge whose value should always be 1. This
   86	// gauge is useful to report static information like a version.
   87	func newLabelGauge(system, subsystem, name, help, prefix, label string) *prometheus.GaugeVec {
   88		if help == "" {
   89			help = name
   90		}
   91		namespace := system
   92		if prefix != "" {
   93			namespace = prefix
   94		}
   95		opts := prometheus.GaugeOpts{
   96			Namespace: namespace,
   97			Subsystem: subsystem,
   98			Name:      name,
   99			Help:      help,
  100		}
  101		metric := prometheus.NewGaugeVec(opts, []string{"server_id", label})
  102	
  103		Tracef("Created metric: %s, %s, %s, %s", namespace, subsystem, name, help)
  104		return metric
  105	}
```


### `collector.go` lines 204–227

The generic collector re-reads the endpoint on every scrape and rebuilds the metric list when new keys appear.

```go
  204	// makeRequests makes HTTP request to the NATS server(s) monitor URLs and returns
  205	// a map of responses.
  206	func (nc *NATSCollector) makeRequests() map[string]map[string]interface{} {
  207		// query the URL for the most recent stats.
  208		// get all the Metrics at once, then set the stats and collect them together.
  209		resps := make(map[string]map[string]interface{})
  210		for _, u := range nc.servers {
  211			var response = map[string]interface{}{}
  212			if err := getMetricURL(nc.httpClient, u.URL, &response); err != nil {
  213				Debugf("ignoring server %s: %v", u.ID, err)
  214				delete(resps, u.ID)
  215			}
  216	
  217			// verify if there are any new keys in the response that we haven't seen before
  218			keys := mapKeys(response, "")
  219			if !maps.Equal(keys, nc.serverRespKeys) {
  220				Debugf("new keys found in the response from %s, updating metrics", u.URL)
  221				nc.objectToMetrics(response, nc.system)
  222				nc.serverRespKeys = keys
  223			}
  224			resps[u.ID] = response
  225		}
  226		return resps
  227	}
```


### `collector.go` lines 241–289

The value paths: JSON numbers are set on the gauge; strings are parsed as RFC 3339 times (epoch milliseconds) when marked `time`, otherwise become the `value` label.

```go
  241	// collectStatsFromRequests collects the statistics from a set of responses
  242	// returned by a NATS server.
  243	func (nc *NATSCollector) collectStatsFromRequests(
  244		key string, stat metric, resps map[string]map[string]interface{}, ch chan<- prometheus.Metric) {
  245		switch m := stat.metric.(type) {
  246		case *prometheus.GaugeVec:
  247			for id, response := range resps {
  248				switch v := lookupValue(response, stat.path).(type) {
  249				case float64: // json only has floats
  250					m.WithLabelValues(id).Set(v)
  251				case string:
  252					if stat.time {
  253						m.WithLabelValues(id).Set(parseDateString(v))
  254					} else {
  255						m.Reset()
  256						m.With(prometheus.Labels{"server_id": id, "value": v}).Set(1)
  257					}
  258				default:
  259					Debugf("value %s no longer a float", key, id, v)
  260				}
  261			}
  262			m.Collect(ch) // update the stat.
  263		case *prometheus.CounterVec:
  264			for id, response := range resps {
  265				switch v := lookupValue(response, stat.path).(type) {
  266				case float64: // json only has floats
  267					m.WithLabelValues(id).Add(v)
  268				default:
  269					Debugf("value %s no longer a float", key, id, v)
  270				}
  271			}
  272			m.Collect(ch) // update the stat.
  273		default:
  274			Tracef("Unknown Metric Type %s", key)
  275		}
  276	}
  277	
  278	// Collect all metrics for all URLs to send to Prometheus.
  279	func (nc *NATSCollector) Collect(ch chan<- prometheus.Metric) {
  280		nc.Lock()
  281		defer nc.Unlock()
  282	
  283		resps := nc.makeRequests()
  284		if len(resps) > 0 {
  285			for key, stat := range nc.Stats {
  286				nc.collectStatsFromRequests(key, stat, resps, ch)
  287			}
  288		}
  289	}
```


### `collector.go` lines 322–405

The naming rule: nested objects are flattened with `_`, `/` becomes `_`, doubled underscores collapse; the `skipFQN` list is dropped; only the eight `labelKeys` strings become label gauges (every other string field is silently ignored); booleans and arrays fall into the `default` case and are never exported.

```go
  322	// returns a sanitized fully qualified name and path
  323	func fqName(name string, prefix ...string) (string, []string) {
  324		l := len(prefix) + 1
  325		path := make([]string, 0, l)
  326		if l > 1 {
  327			path = append(path, prefix...)
  328		}
  329		path = append(path, name)
  330		fqn := strings.Trim(strings.ReplaceAll(strings.Join(path, "_"), "/", "_"), "_")
  331		for strings.Contains(fqn, "__") {
  332			fqn = strings.ReplaceAll(fqn, "__", "_")
  333		}
  334		return fqn, path
  335	}
  336	
  337	func (nc *NATSCollector) objectToMetrics(response map[string]interface{}, namespace string, prefix ...string) {
  338		skipFQN := map[string]struct{}{
  339			"leaf":                    {},
  340			"trusted_operators_claim": {},
  341			"cluster_tls_timeout":     {},
  342			"cluster_cluster_port":    {},
  343			"cluster_auth_timeout":    {},
  344			"gateway_port":            {},
  345			"gateway_auth_timeout":    {},
  346			"gateway_tls_timeout":     {},
  347			"gateway_connect_retries": {},
  348		}
  349	
  350		labelKeys := map[string]struct{}{
  351			"server_id":        {},
  352			"server_name":      {},
  353			"version":          {},
  354			"domain":           {},
  355			"leader":           {},
  356			"name":             {},
  357			"start":            {},
  358			"config_load_time": {},
  359		}
  360	
  361		for k := range response {
  362			fqn, path := fqName(k, prefix...)
  363			if _, ok := skipFQN[fqn]; ok {
  364				continue
  365			}
  366			// if it's not already defined in metricDefinitions
  367			if _, ok := nc.Stats[fqn]; ok {
  368				continue
  369			}
  370			i := response[k]
  371			switch v := i.(type) {
  372			case float64: // all json numbers are handled here.
  373				nc.Stats[fqn] = metric{
  374					path:   path,
  375					metric: newPrometheusGaugeVec(nc.system, nc.endpoint, fqn, "", namespace),
  376				}
  377			case string:
  378				if _, ok := labelKeys[k]; !ok {
  379					break
  380				}
  381	
  382				// Check if the value is a valid time string.
  383				// Go JSONMarshal time.Time in RFC3339Nano format.
  384				_, err := time.Parse(time.RFC3339Nano, v)
  385				if err == nil {
  386					nc.Stats[fqn] = metric{
  387						path:   path,
  388						metric: newPrometheusGaugeVec(nc.system, nc.endpoint, fqn, "", namespace),
  389						time:   true,
  390					}
  391				} else {
  392					nc.Stats[fqn] = metric{
  393						path:   path,
  394						metric: newLabelGauge(nc.system, nc.endpoint, fqn, "", namespace, "value"),
  395					}
  396				}
  397			case map[string]interface{}:
  398				// recurse and flatten
  399				nc.objectToMetrics(v, namespace, path...)
  400			default:
  401				// not one of the types currently handled
  402				Tracef("Unknown type:  %v %v, %v", fqn, k, v)
  403			}
  404		}
  405	}
```


### `collector.go` lines 431–461

Each generic collector polls `<url>/<endpoint>`; `getSystem` is where `-prefix` overrides the namespace.

```go
  431	func newNatsCollector(system, endpoint string, servers []*CollectedServer) prometheus.Collector {
  432		// TODO:  Potentially add TLS config in the transport.
  433		tr := &http.Transport{}
  434		hc := &http.Client{Transport: tr}
  435		nc := &NATSCollector{
  436			httpClient: hc,
  437			system:     system,
  438			endpoint:   endpoint,
  439		}
  440	
  441		// create our own deep copy, and tweak the urls to be polled
  442		// for this type of endpoint
  443		nc.servers = make([]*CollectedServer, len(servers))
  444		for i, s := range servers {
  445			nc.servers[i] = &CollectedServer{
  446				ID:  s.ID,
  447				URL: s.URL + "/" + endpoint,
  448			}
  449		}
  450	
  451		nc.initMetricsFromServers(system)
  452	
  453		return nc
  454	}
  455	
  456	func getSystem(system, prefix string) string {
  457		if prefix == "" {
  458			return system
  459		}
  460		return prefix
  461	}
```


### `collector.go` lines 470–504

The dispatch: which endpoint names get a hand-written collector, and that the JetStream collector is selected by the `jetstream` system rather than an endpoint name.

```go
  470	// NewCollector creates a new NATS Collector from a list of monitoring URLs.
  471	// Each URL should be to a specific endpoint (e.g. varz, connz, healthz, subsz, or routez)
  472	func NewCollector(system, endpoint, prefix string, servers []*CollectedServer) prometheus.Collector {
  473		if isHealthzEndpoint(system, endpoint) {
  474			return newHealthzCollector(getSystem(system, prefix), endpoint, servers)
  475		}
  476		if isConnzEndpoint(system, endpoint) {
  477			return newConnzCollector(getSystem(system, prefix), endpoint, servers)
  478		}
  479		if isGatewayzEndpoint(system, endpoint) {
  480			return newGatewayzCollector(getSystem(system, prefix), endpoint, servers)
  481		}
  482		if isAccstatzEndpoint(system, endpoint) {
  483			return newAccstatzCollector(getSystem(system, prefix), endpoint, servers)
  484		}
  485		if isAccountzEndpoint(system, endpoint) {
  486			return newAccountzCollector(getSystem(system, prefix), endpoint, servers)
  487		}
  488		if isLeafzEndpoint(system, endpoint) {
  489			return newLeafzCollector(getSystem(system, prefix), endpoint, servers)
  490		}
  491		if isJszEndpoint(system) {
  492			return newJszCollector(getSystem(system, prefix), endpoint, servers, []string{}, []string{})
  493		}
  494		return newNatsCollector(getSystem(system, prefix), endpoint, servers)
  495	}
  496	
  497	// NewJszCollector creates a new NATS JetStream Collector.
  498	func NewJszCollector(
  499		endpoint, prefix string,
  500		servers []*CollectedServer,
  501		streamMetaKeys, consumerMetaKeys []string,
  502	) prometheus.Collector {
  503		return newJszCollector(getSystem(JetStreamSystem, prefix), endpoint, servers, streamMetaKeys, consumerMetaKeys)
  504	}
```


## exporter/exporter.go — the defaults, the flag-to-collector mapping


### `exporter/exporter.go` lines 92–102

The listen defaults.

```go
   92	// Defaults
   93	var (
   94		DefaultListenPort        = 7777
   95		DefaultListenAddress     = "0.0.0.0"
   96		DefaultScrapePath        = "/metrics"
   97		DefaultMonitorURL        = "http://localhost:8222"
   98		DefaultRetryIntervalSecs = 30
   99	
  100		// bcryptPrefix from gnatsd
  101		bcryptPrefix = "$2a$"
  102	)
```


### `exporter/exporter.go` lines 187–263

One collector per flag; `-connz_detailed` replaces `-connz`; the three `healthz` variants are separate collectors and endpoints; `-jsz` accepts `account(s)`, `consumer(s)`, `stream(s)` or `all` and nothing else; the `jsz_*_meta_keys` become extra labels.

```go
  187	// InitializeCollectors initializes the Collectors for the exporter.
  188	// Caller must lock
  189	func (ne *NATSExporter) InitializeCollectors() error {
  190		opts := ne.opts
  191	
  192		if len(ne.servers) == 0 {
  193			return fmt.Errorf("no servers configured to obtain metrics")
  194		}
  195	
  196		if opts.GetSubz {
  197			ne.createCollector(collector.CoreSystem, "subsz")
  198		}
  199		if opts.GetVarz {
  200			ne.createCollector(collector.CoreSystem, "varz")
  201		}
  202		if opts.GetHealthz {
  203			ne.createCollector(collector.CoreSystem, "healthz")
  204		}
  205		if opts.GetHealthzJsEnabledOnly {
  206			ne.createCollector(collector.CoreSystem, "healthz_js_enabled_only")
  207		}
  208		if opts.GetHealthzJsServerOnly {
  209			ne.createCollector(collector.CoreSystem, "healthz_js_server_only")
  210		}
  211		if opts.GetConnzDetailed {
  212			ne.createCollector(collector.CoreSystem, "connz_detailed")
  213		} else if opts.GetConnz {
  214			ne.createCollector(collector.CoreSystem, "connz")
  215		}
  216		if opts.GetGatewayz {
  217			ne.createCollector(collector.CoreSystem, "gatewayz")
  218		}
  219		if opts.GetAccstatz {
  220			ne.createCollector(collector.CoreSystem, "accstatz")
  221		}
  222		if opts.GetAccountz {
  223			ne.createCollector(collector.CoreSystem, "accountz")
  224		}
  225		if opts.GetLeafz {
  226			ne.createCollector(collector.CoreSystem, "leafz")
  227		}
  228		if opts.GetRoutez {
  229			ne.createCollector(collector.CoreSystem, "routez")
  230		}
  231		if opts.GetJszFilter != "" {
  232			switch strings.ToLower(opts.GetJszFilter) {
  233			case "account", "accounts", "consumer", "consumers", "all", "stream", "streams":
  234			default:
  235				return fmt.Errorf("invalid jsz filter %q", opts.GetJszFilter)
  236			}
  237			var streamMetaKeys, consumerMetaKeys []string
  238			keyRegex := regexp.MustCompile("[a-zA-Z0-9_]+")
  239			if opts.JszStreamMetaKeys != "" {
  240				streamMetaKeys = strings.Split(opts.JszStreamMetaKeys, ",")
  241				for _, k := range streamMetaKeys {
  242					if !keyRegex.MatchString(k) {
  243						return fmt.Errorf("invalid jsz stream meta key: '%s'", k)
  244					}
  245				}
  246			}
  247	
  248			if opts.JszConsumerMetaKeys != "" {
  249				consumerMetaKeys = strings.Split(opts.JszConsumerMetaKeys, ",")
  250				for _, k := range consumerMetaKeys {
  251					if !keyRegex.MatchString(k) {
  252						return fmt.Errorf("invalid jsz consumer meta key: '%s'", k)
  253					}
  254				}
  255			}
  256			ne.createJszCollector(opts.GetJszFilter, streamMetaKeys, consumerMetaKeys)
  257		}
  258		if len(ne.Collectors) == 0 {
  259			return fmt.Errorf("no Collectors specified")
  260		}
  261	
  262		return nil
  263	}
```


### `exporter/exporter.go` lines 276–319

A private registry, plus the Go runtime and process collectors — which is where the `go_*` and `process_*` series on every scrape come from.

```go
  276	// Start runs the exporter process.
  277	func (ne *NATSExporter) Start() error {
  278		ne.Lock()
  279		defer ne.Unlock()
  280		if ne.mode == modeStarted {
  281			return nil
  282		}
  283		// Since we are adding metrics in runtime, we need to use a custom registry
  284		// instead of the default one. This is because the default registry is
  285		// global and collectors cannot be properly re-registered after being
  286		// modified.
  287		if ne.registry == nil {
  288			ne.registry = prometheus.NewRegistry()
  289		}
  290		if err := ne.registry.Register(collectors.NewGoCollector()); err != nil {
  291			if errors.As(err, &prometheus.AlreadyRegisteredError{}) {
  292				collector.Debugf("GoCollector already registered")
  293			} else {
  294				return fmt.Errorf("error registering GoCollector: %v", err)
  295			}
  296		}
  297		if err := ne.registry.Register(collectors.NewProcessCollector(collectors.ProcessCollectorOpts{})); err != nil {
  298			if errors.As(err, &prometheus.AlreadyRegisteredError{}) {
  299				collector.Debugf("ProcessCollector already registered")
  300			} else {
  301				return fmt.Errorf("error registering GoCollector: %v", err)
  302			}
  303		}
  304	
  305		if err := ne.InitializeCollectors(); err != nil {
  306			ne.ClearCollectors()
  307			return err
  308		}
  309	
  310		if err := ne.startHTTP(); err != nil {
  311			ne.ClearCollectors()
  312			return fmt.Errorf("error serving http:  %v", err)
  313		}
  314	
  315		ne.doneWg.Add(1)
  316		ne.mode = modeStarted
  317	
  318		return nil
  319	}
```


### `exporter/exporter.go` lines 376–382

The scrape handler uses default `promhttp.HandlerOpts{}` — no pedantic checks, which is why a series a collector emits without describing it still appears.

```go
  376	// getScrapeHandler returns the default handler if no nttp
  377	// auhtorization has been specificed.  Otherwise, it checks
  378	// basic authorization.
  379	func (ne *NATSExporter) getScrapeHandler() http.Handler {
  380		h := promhttp.InstrumentMetricHandler(
  381			ne.registry, promhttp.HandlerFor(ne.registry, promhttp.HandlerOpts{}),
  382		)
```


## main.go — the "defaulting to varz" test


### `main.go` lines 79–88

The condition is inverted: `opts.GetJszFilter == ""` is true whenever `-jsz` is *absent*, so with no flags at all `metricsSpecified` is true and nothing is defaulted (the exporter then exits with `no Collectors specified`), while `-jsz=…` alone makes it false and `varz` is switched on with the message. Both observed in `metrics-observed-v0.20.2.md` (runs E and F).

```go
   79		metricsSpecified := opts.GetConnz || opts.GetVarz || opts.GetSubz || opts.GetHealthz ||
   80			opts.GetHealthzJsEnabledOnly || opts.GetHealthzJsServerOnly ||
   81			opts.GetRoutez || opts.GetGatewayz || opts.GetAccstatz || opts.GetAccountz || opts.GetLeafz ||
   82			opts.GetJszFilter == ""
   83		if !metricsSpecified {
   84			// No logger setup yet, so use fmt
   85			fmt.Printf("No metrics specified.  Defaulting to varz.\n")
   86			opts.GetVarz = true
   87		}
   88	}
```


### `main.go` lines 145–147

The prefix and the two server-id flags.

```go
  145		flag.StringVar(&opts.Prefix, "prefix", "", "Replace the default prefix for all the metrics.")
  146		flag.BoolVar(&opts.UseInternalServerID, "use_internal_server_id", false, "Enables using ServerID from /varz")
  147		flag.BoolVar(&opts.UseServerName, "use_internal_server_name", false, "Enables using ServerName from /varz")
```


### `main.go` lines 157–169

More than one URL is permitted but warned against.

```go
  157		args := flag.Args()
  158		if len(args) < 1 {
  159			fmt.Printf("Usage:  %s <flags> url\n\n", os.Args[0])
  160			flag.Usage()
  161			return
  162		} else if len(args) > 1 {
  163			fmt.Println(
  164				`WARNING:  While permitted by this exporter, monitoring more than one server
  165	violates Prometheus guidelines and best practices.  Each Prometheus NATS
  166	exporter should monitor exactly one NATS server, preferably sitting right
  167	beside it on the same machine.  Aggregate multiple servers only when
  168	necessary.`)
  169		}
```


## collector/jsz.go — the JetStream collector: every series, every label, the endpoint it reads


### `jsz.go` lines 27–81

The 33 descriptors (7 server, 4 account, 8 stream, 10 consumer, 2 source, 2 mirror).

```go
   27	type jszCollector struct {
   28		sync.Mutex
   29		httpClient *http.Client
   30		servers    []*CollectedServer
   31		endpoint   string
   32	
   33		// JetStream server stats
   34		disabled   *prometheus.Desc
   35		streams    *prometheus.Desc
   36		consumers  *prometheus.Desc
   37		messages   *prometheus.Desc
   38		bytes      *prometheus.Desc
   39		maxMemory  *prometheus.Desc
   40		maxStorage *prometheus.Desc
   41	
   42		// Account stats
   43		maxAccountMemory  *prometheus.Desc
   44		maxAccountStorage *prometheus.Desc
   45		accountStorage    *prometheus.Desc
   46		accountMemory     *prometheus.Desc
   47	
   48		// Stream stats
   49		streamMessages      *prometheus.Desc
   50		streamBytes         *prometheus.Desc
   51		streamFirstSeq      *prometheus.Desc
   52		streamLastSeq       *prometheus.Desc
   53		streamConsumerCount *prometheus.Desc
   54		streamSubjectCount  *prometheus.Desc
   55		streamLimitBytes    *prometheus.Desc
   56		streamLimitMessages *prometheus.Desc
   57	
   58		// Consumer stats
   59		consumerDeliveredConsumerSeq *prometheus.Desc
   60		consumerDeliveredStreamSeq   *prometheus.Desc
   61		consumerLastDelivery         *prometheus.Desc
   62		consumerLastAck              *prometheus.Desc
   63		consumerNumAckPending        *prometheus.Desc
   64		consumerNumRedelivered       *prometheus.Desc
   65		consumerNumWaiting           *prometheus.Desc
   66		consumerNumPending           *prometheus.Desc
   67		consumerAckFloorStreamSeq    *prometheus.Desc
   68		consumerAckFloorConsumerSeq  *prometheus.Desc
   69	
   70		// Stream source stats
   71		streamSourceLag    *prometheus.Desc
   72		streamSourceActive *prometheus.Desc
   73	
   74		// Stream mirror stats
   75		streamMirrorLag    *prometheus.Desc
   76		streamMirrorActive *prometheus.Desc
   77	
   78		// metadata keys to extract
   79		streamMetaKeys   []string
   80		consumerMetaKeys []string
   81	}
```


### `jsz.go` lines 87–128

The label sets: six server labels on everything, plus `account`/`account_name`/`account_id`, four stream labels, four consumer labels, three source or mirror labels; `-jsz_stream_meta_keys` and `-jsz_consumer_meta_keys` add `stream_meta_<k>` / `consumer_meta_<k>`.

```go
   87	func newJszCollector(
   88		system, endpoint string,
   89		servers []*CollectedServer,
   90		streamMetaKeys, consumerMetaKeys []string,
   91	) prometheus.Collector {
   92		serverLabels := []string{"server_id", "server_name", "cluster", "domain", "meta_leader", "is_meta_leader"}
   93	
   94		streamLabels := append([]string{}, serverLabels...)
   95		streamLabels = append(streamLabels, "account")
   96		streamLabels = append(streamLabels, "account_name")
   97		streamLabels = append(streamLabels, "account_id")
   98		streamLabels = append(streamLabels, "stream_name")
   99		streamLabels = append(streamLabels, "stream_leader")
  100		streamLabels = append(streamLabels, "is_stream_leader")
  101		streamLabels = append(streamLabels, "stream_raft_group")
  102		for _, k := range streamMetaKeys {
  103			streamLabels = append(streamLabels, "stream_meta_"+k)
  104		}
  105	
  106		accountLabels := append([]string{}, serverLabels...)
  107		accountLabels = append(accountLabels, "account")
  108		accountLabels = append(accountLabels, "account_name")
  109		accountLabels = append(accountLabels, "account_id")
  110	
  111		consumerLabels := append([]string{}, streamLabels...)
  112		consumerLabels = append(consumerLabels, "consumer_name")
  113		consumerLabels = append(consumerLabels, "consumer_leader")
  114		consumerLabels = append(consumerLabels, "is_consumer_leader")
  115		consumerLabels = append(consumerLabels, "consumer_desc")
  116		for _, k := range consumerMetaKeys {
  117			consumerLabels = append(consumerLabels, "consumer_meta_"+k)
  118		}
  119	
  120		sourceLabels := append([]string{}, streamLabels...)
  121		sourceLabels = append(sourceLabels, "source_name")
  122		sourceLabels = append(sourceLabels, "source_api")
  123		sourceLabels = append(sourceLabels, "source_deliver")
  124	
  125		mirrorLabels := append([]string{}, streamLabels...)
  126		mirrorLabels = append(mirrorLabels, "mirror_name")
  127		mirrorLabels = append(mirrorLabels, "mirror_api")
  128		mirrorLabels = append(mirrorLabels, "mirror_deliver")
```


### `jsz.go` lines 130–367

The names and help strings, verbatim.

```go
  130		nc := &jszCollector{
  131			httpClient: &http.Client{
  132				Timeout: 5 * time.Second,
  133			},
  134			endpoint: endpoint,
  135			// jetstream_disabled
  136			disabled: prometheus.NewDesc(
  137				prometheus.BuildFQName(system, "server", "jetstream_disabled"),
  138				"JetStream disabled or not",
  139				serverLabels,
  140				nil,
  141			),
  142			// jetstream_server_total_streams
  143			streams: prometheus.NewDesc(
  144				prometheus.BuildFQName(system, "server", "total_streams"),
  145				"Total number of streams in JetStream",
  146				serverLabels,
  147				nil,
  148			),
  149			// jetstream_server_total_consumers
  150			consumers: prometheus.NewDesc(
  151				prometheus.BuildFQName(system, "server", "total_consumers"),
  152				"Total number of consumers in JetStream",
  153				serverLabels,
  154				nil,
  155			),
  156			// jetstream_server_total_messages
  157			messages: prometheus.NewDesc(
  158				prometheus.BuildFQName(system, "server", "total_messages"),
  159				"Total number of stored messages in JetStream",
  160				serverLabels,
  161				nil,
  162			),
  163			// jetstream_server_total_message_bytes
  164			bytes: prometheus.NewDesc(
  165				prometheus.BuildFQName(system, "server", "total_message_bytes"),
  166				"Total number of bytes stored in JetStream",
  167				serverLabels,
  168				nil,
  169			),
  170			// jetstream_server_max_memory
  171			maxMemory: prometheus.NewDesc(
  172				prometheus.BuildFQName(system, "server", "max_memory"),
  173				"JetStream Max Memory",
  174				serverLabels,
  175				nil,
  176			),
  177			// jetstream_server_max_storage
  178			maxStorage: prometheus.NewDesc(
  179				prometheus.BuildFQName(system, "server", "max_storage"),
  180				"JetStream Max Storage",
  181				serverLabels,
  182				nil,
  183			),
  184			// jetstream_account_max_memory
  185			maxAccountMemory: prometheus.NewDesc(
  186				prometheus.BuildFQName(system, "account", "max_memory"),
  187				"JetStream Account Max Memory in bytes",
  188				accountLabels,
  189				nil,
  190			),
  191			// jetstream_account_max_storage
  192			maxAccountStorage: prometheus.NewDesc(
  193				prometheus.BuildFQName(system, "account", "max_storage"),
  194				"JetStream Account Max Storage in bytes",
  195				accountLabels,
  196				nil,
  197			),
  198			// jetstream_account_storage_used
  199			accountStorage: prometheus.NewDesc(
  200				prometheus.BuildFQName(system, "account", "storage_used"),
  201				"Total number of bytes used by JetStream storage",
  202				accountLabels,
  203				nil,
  204			),
  205			// jetstream_account_memory_used
  206			accountMemory: prometheus.NewDesc(
  207				prometheus.BuildFQName(system, "account", "memory_used"),
  208				"Total number of bytes used by JetStream memory",
  209				accountLabels,
  210				nil,
  211			),
  212			// jetstream_stream_total_messages
  213			streamMessages: prometheus.NewDesc(
  214				prometheus.BuildFQName(system, "stream", "total_messages"),
  215				"Total number of messages from a stream",
  216				streamLabels,
  217				nil,
  218			),
  219			// jetstream_stream_limit_messages
  220			streamLimitMessages: prometheus.NewDesc(
  221				prometheus.BuildFQName(system, "stream", "limit_messages"),
  222				"The maximum number of messages allowed in a JetStream stream as per its configuration. "+
  223					"A value of -1 indicates no limit.",
  224				streamLabels,
  225				nil,
  226			),
  227			// jetstream_stream_total_bytes
  228			streamBytes: prometheus.NewDesc(
  229				prometheus.BuildFQName(system, "stream", "total_bytes"),
  230				"Total stored bytes from a stream",
  231				streamLabels,
  232				nil,
  233			),
  234			// jetstream_stream_limit_bytes
  235			streamLimitBytes: prometheus.NewDesc(
  236				prometheus.BuildFQName(system, "stream", "limit_bytes"),
  237				"The maximum configured storage limit (in bytes) for a JetStream stream. A value of -1 indicates no limit.",
  238				streamLabels,
  239				nil,
  240			),
  241			// jetstream_stream_first_seq
  242			streamFirstSeq: prometheus.NewDesc(
  243				prometheus.BuildFQName(system, "stream", "first_seq"),
  244				"First sequence from a stream",
  245				streamLabels,
  246				nil,
  247			),
  248			// jetstream_stream_last_seq
  249			streamLastSeq: prometheus.NewDesc(
  250				prometheus.BuildFQName(system, "stream", "last_seq"),
  251				"Last sequence from a stream",
  252				streamLabels,
  253				nil,
  254			),
  255			// jetstream_stream_consumer_count
  256			streamConsumerCount: prometheus.NewDesc(
  257				prometheus.BuildFQName(system, "stream", "consumer_count"),
  258				"Total number of consumers from a stream",
  259				streamLabels,
  260				nil,
  261			),
  262			// jetstream_stream_subjects
  263			streamSubjectCount: prometheus.NewDesc(
  264				prometheus.BuildFQName(system, "stream", "subject_count"),
  265				"Total number of subjects in a stream",
  266				streamLabels,
  267				nil,
  268			),
  269			// jetstream_consumer_delivered_consumer_seq
  270			consumerDeliveredConsumerSeq: prometheus.NewDesc(
  271				prometheus.BuildFQName(system, "consumer", "delivered_consumer_seq"),
  272				"Latest sequence number of a stream consumer",
  273				consumerLabels,
  274				nil,
  275			),
  276			// jetstream_consumer_delivered_stream_seq
  277			consumerDeliveredStreamSeq: prometheus.NewDesc(
  278				prometheus.BuildFQName(system, "consumer", "delivered_stream_seq"),
  279				"Latest sequence number of a stream",
  280				consumerLabels,
  281				nil,
  282			),
  283			// jetstream_consumer_last_delivery_seconds
  284			consumerLastDelivery: prometheus.NewDesc(
  285				prometheus.BuildFQName(system, "consumer", "last_delivery_seconds"),
  286				"Seconds since last message delivery to consumer",
  287				consumerLabels,
  288				nil,
  289			),
  290			// jetstream_consumer_last_ack_seconds
  291			consumerLastAck: prometheus.NewDesc(
  292				prometheus.BuildFQName(system, "consumer", "last_ack_seconds"),
  293				"Seconds since last ack from consumer",
  294				consumerLabels,
  295				nil,
  296			),
  297			// jetstream_consumer_num_ack_pending
  298			consumerNumAckPending: prometheus.NewDesc(
  299				prometheus.BuildFQName(system, "consumer", "num_ack_pending"),
  300				"Number of pending acks from a consumer",
  301				consumerLabels,
  302				nil,
  303			),
  304			// jetstream_consumer_num_redelivered
  305			consumerNumRedelivered: prometheus.NewDesc(
  306				prometheus.BuildFQName(system, "consumer", "num_redelivered"),
  307				"Number of redelivered messages from a consumer",
  308				consumerLabels,
  309				nil,
  310			),
  311			// jetstream_consumer_num_waiting
  312			consumerNumWaiting: prometheus.NewDesc(
  313				prometheus.BuildFQName(system, "consumer", "num_waiting"),
  314				"Number of inflight fetch requests from a pull consumer",
  315				consumerLabels,
  316				nil,
  317			),
  318			// jetstream_consumer_num_pending
  319			consumerNumPending: prometheus.NewDesc(
  320				prometheus.BuildFQName(system, "consumer", "num_pending"),
  321				"Number of pending messages from a consumer",
  322				consumerLabels,
  323				nil,
  324			),
  325			consumerAckFloorStreamSeq: prometheus.NewDesc(
  326				prometheus.BuildFQName(system, "consumer", "ack_floor_stream_seq"),
  327				"Number of ack floor stream seq from a consumer",
  328				consumerLabels,
  329				nil,
  330			),
  331			consumerAckFloorConsumerSeq: prometheus.NewDesc(
  332				prometheus.BuildFQName(system, "consumer", "ack_floor_consumer_seq"),
  333				"Number of ack floor consumer seq from a consumer",
  334				consumerLabels,
  335				nil,
  336			),
  337			// jetstream_stream_source_lag
  338			streamSourceLag: prometheus.NewDesc(
  339				prometheus.BuildFQName(system, "stream", "source_lag"),
  340				"Number of messages a stream source is behind",
  341				sourceLabels,
  342				nil,
  343			),
  344			// jetstream_stream_source_active_duration_ns
  345			streamSourceActive: prometheus.NewDesc(
  346				prometheus.BuildFQName(system, "stream", "source_active_duration_ns"),
  347				"Stream source active duration in nanoseconds (-1 indicates inactive)",
  348				sourceLabels,
  349				nil,
  350			),
  351			// jetstream_stream_mirror_lag
  352			streamMirrorLag: prometheus.NewDesc(
  353				prometheus.BuildFQName(system, "stream", "mirror_lag"),
  354				"Number of messages a stream mirror is behind",
  355				mirrorLabels,
  356				nil,
  357			),
  358			// jetstream_stream_mirror_active_duration_ns
  359			streamMirrorActive: prometheus.NewDesc(
  360				prometheus.BuildFQName(system, "stream", "mirror_active_duration_ns"),
  361				"Stream mirror active duration in nanoseconds (-1 indicates inactive)",
  362				mirrorLabels,
  363				nil,
  364			),
  365			streamMetaKeys:   streamMetaKeys,
  366			consumerMetaKeys: consumerMetaKeys,
  367		}
```


### `jsz.go` lines 381–436

`Describe` lists 27 of the 33 descriptors — the four `account_*` series and the consumer `ack_floor_stream_seq` / `ack_floor_consumer_seq` are emitted by `Collect` but never described (they still appear on a scrape, see the observed file, because the registry is not pedantic). The `/jsz` query each `-jsz` value sends: `all` and `consumers` fetch `?consumers=true&config=true&raft=true`, `streams` only `?streams=true` (so no `config` — no `limit_*` series — and no `raft` — an empty `stream_raft_group` label).

```go
  381	// Describe shares the info description from a prometheus metric.
  382	func (nc *jszCollector) Describe(ch chan<- *prometheus.Desc) {
  383		// Server state
  384		ch <- nc.disabled
  385		ch <- nc.streams
  386		ch <- nc.consumers
  387		ch <- nc.messages
  388		ch <- nc.bytes
  389		ch <- nc.maxMemory
  390		ch <- nc.maxStorage
  391	
  392		// Stream state
  393		ch <- nc.streamMessages
  394		ch <- nc.streamBytes
  395		ch <- nc.streamFirstSeq
  396		ch <- nc.streamLastSeq
  397		ch <- nc.streamConsumerCount
  398		ch <- nc.streamSubjectCount
  399		ch <- nc.streamLimitBytes
  400		ch <- nc.streamLimitMessages
  401	
  402		// Consumer state
  403		ch <- nc.consumerDeliveredConsumerSeq
  404		ch <- nc.consumerDeliveredStreamSeq
  405		ch <- nc.consumerLastDelivery
  406		ch <- nc.consumerLastAck
  407		ch <- nc.consumerNumAckPending
  408		ch <- nc.consumerNumRedelivered
  409		ch <- nc.consumerNumWaiting
  410		ch <- nc.consumerNumPending
  411	
  412		// Source state
  413		ch <- nc.streamSourceLag
  414		ch <- nc.streamSourceActive
  415	
  416		// Mirror state
  417		ch <- nc.streamMirrorLag
  418		ch <- nc.streamMirrorActive
  419	}
  420	
  421	// Collect gathers the server jsz metrics.
  422	func (nc *jszCollector) Collect(ch chan<- prometheus.Metric) {
  423		for _, server := range nc.servers {
  424			var resp nats.JSInfo
  425			var suffix string
  426	
  427			switch strings.ToLower(nc.endpoint) {
  428			case "account", "accounts":
  429				suffix = "/jsz?accounts=true"
  430			case "consumer", "consumers", "all":
  431				suffix = "/jsz?consumers=true&config=true&raft=true"
  432			case "stream", "streams":
  433				suffix = "/jsz?streams=true"
  434			default:
  435				suffix = "/jsz"
  436			}
```


### `jsz.go` lines 437–483

A second request to `/varz` for the server name; the leader labels; the seven server-level series.

```go
  437			if err := getMetricURL(nc.httpClient, server.URL+suffix, &resp); err != nil {
  438				Debugf("ignoring server %s: %v", server.ID, err)
  439				continue
  440			}
  441			var varz nats.Varz
  442			if err := getMetricURL(nc.httpClient, server.URL+"/varz", &varz); err != nil {
  443				Debugf("ignoring server %s: %v", server.ID, err)
  444				continue
  445			}
  446			var serverID, serverName, clusterName, jsDomain, clusterLeader string
  447			var streamName, streamLeader, streamRaftGroup string
  448			var consumerName, consumerDesc, consumerLeader string
  449			var isMetaLeader, isStreamLeader, isConsumerLeader string
  450			var accountName string
  451			var accountID string
  452	
  453			serverID = server.ID
  454			serverName = varz.Name
  455			if resp.Meta != nil {
  456				clusterName = resp.Meta.Name
  457				clusterLeader = resp.Meta.Leader
  458				if resp.Meta.Leader == serverName {
  459					isMetaLeader = "true"
  460				} else {
  461					isMetaLeader = "false"
  462				}
  463			} else {
  464				isMetaLeader = "true"
  465			}
  466			jsDomain = resp.Config.Domain
  467	
  468			serverMetric := func(key *prometheus.Desc, value float64) prometheus.Metric {
  469				return prometheus.MustNewConstMetric(key, prometheus.GaugeValue, value,
  470					serverID, serverName, clusterName, jsDomain, clusterLeader, isMetaLeader)
  471			}
  472	
  473			var isJetStreamDisabled float64
  474			if resp.Disabled {
  475				isJetStreamDisabled = 1
  476			}
  477			ch <- serverMetric(nc.disabled, isJetStreamDisabled)
  478			ch <- serverMetric(nc.maxMemory, float64(resp.Config.MaxMemory))
  479			ch <- serverMetric(nc.maxStorage, float64(resp.Config.MaxStore))
  480			ch <- serverMetric(nc.streams, float64(resp.Streams))
  481			ch <- serverMetric(nc.consumers, float64(resp.Consumers))
  482			ch <- serverMetric(nc.messages, float64(resp.Messages))
  483			ch <- serverMetric(nc.bytes, float64(resp.Bytes))
```


### `jsz.go` lines 485–543

Account and stream series; `limit_bytes` / `limit_messages` only when the response carries the config.

```go
  485			for _, account := range resp.AccountDetails {
  486				accountName = account.Name
  487				accountID = account.Id
  488	
  489				accountMetric := func(key *prometheus.Desc, value float64) prometheus.Metric {
  490					return prometheus.MustNewConstMetric(key, prometheus.GaugeValue, value,
  491						// Server Labels
  492						serverID, serverName, clusterName, jsDomain, clusterLeader, isMetaLeader,
  493						// Account Labels
  494						accountName, accountName, accountID)
  495				}
  496	
  497				ch <- accountMetric(nc.maxAccountStorage, float64(account.ReservedStore))
  498				ch <- accountMetric(nc.maxAccountMemory, float64(account.ReservedMemory))
  499				ch <- accountMetric(nc.accountStorage, float64(account.Store))
  500				ch <- accountMetric(nc.accountMemory, float64(account.Memory))
  501	
  502				for _, stream := range account.Streams {
  503					streamName = stream.Name
  504	
  505					if stream.Cluster != nil {
  506						streamLeader = stream.Cluster.Leader
  507						if streamLeader == serverName {
  508							isStreamLeader = "true"
  509						} else {
  510							isStreamLeader = "false"
  511						}
  512					} else {
  513						isStreamLeader = "true"
  514					}
  515					streamRaftGroup = stream.RaftGroup
  516	
  517					streamLabelValues := []string{
  518						// Server Labels
  519						serverID, serverName, clusterName, jsDomain, clusterLeader, isMetaLeader,
  520						// Stream Labels
  521						accountName, accountName, accountID, streamName, streamLeader, isStreamLeader, streamRaftGroup,
  522					}
  523					for _, k := range nc.streamMetaKeys {
  524						var v string
  525						if stream.Config != nil {
  526							v = stream.Config.Metadata[k]
  527						}
  528						streamLabelValues = append(streamLabelValues, v)
  529					}
  530					streamMetric := func(key *prometheus.Desc, value float64) prometheus.Metric {
  531						return prometheus.MustNewConstMetric(key, prometheus.GaugeValue, value, streamLabelValues...)
  532					}
  533					ch <- streamMetric(nc.streamMessages, float64(stream.State.Msgs))
  534					ch <- streamMetric(nc.streamBytes, float64(stream.State.Bytes))
  535					ch <- streamMetric(nc.streamFirstSeq, float64(stream.State.FirstSeq))
  536					ch <- streamMetric(nc.streamLastSeq, float64(stream.State.LastSeq))
  537					ch <- streamMetric(nc.streamConsumerCount, float64(stream.State.Consumers))
  538					ch <- streamMetric(nc.streamSubjectCount, float64(stream.State.NumSubjects))
  539	
  540					if stream.Config != nil {
  541						ch <- streamMetric(nc.streamLimitBytes, float64(stream.Config.MaxBytes))
  542						ch <- streamMetric(nc.streamLimitMessages, float64(stream.Config.MaxMsgs))
  543					}
```


### `jsz.go` lines 545–588

Source and mirror lag and `active` (nanoseconds since last activity, `-1` inactive).

```go
  545					// Now with the sources.
  546					for _, source := range stream.Sources {
  547						sourceName := source.Name
  548						var sourceAPI, sourceDeliver string
  549						if source.External != nil {
  550							sourceAPI = source.External.ApiPrefix
  551							sourceDeliver = source.External.DeliverPrefix
  552						}
  553						sourceMetric := func(key *prometheus.Desc, value float64) prometheus.Metric {
  554							return prometheus.MustNewConstMetric(key, prometheus.GaugeValue, value,
  555								// Server Labels
  556								serverID, serverName, clusterName, jsDomain, clusterLeader, isMetaLeader,
  557								// Stream Labels
  558								accountName, accountName, accountID, streamName, streamLeader, isStreamLeader, streamRaftGroup,
  559								// Source Labels
  560								sourceName, sourceAPI, sourceDeliver,
  561							)
  562						}
  563						ch <- sourceMetric(nc.streamSourceLag, float64(source.Lag))
  564						ch <- sourceMetric(nc.streamSourceActive, float64(source.Active))
  565					}
  566	
  567					// Now with the mirror. There can be only one.
  568					if stream.Mirror != nil {
  569						mirror := stream.Mirror
  570						mirrorName := mirror.Name
  571						var mirrorAPI, mirrorDeliver string
  572						if mirror.External != nil {
  573							mirrorAPI = mirror.External.ApiPrefix
  574							mirrorDeliver = mirror.External.DeliverPrefix
  575						}
  576						mirrorMetric := func(key *prometheus.Desc, value float64) prometheus.Metric {
  577							return prometheus.MustNewConstMetric(key, prometheus.GaugeValue, value,
  578								// Server Labels
  579								serverID, serverName, clusterName, jsDomain, clusterLeader, isMetaLeader,
  580								// Stream Labels
  581								accountName, accountName, accountID, streamName, streamLeader, isStreamLeader, streamRaftGroup,
  582								// Mirror Labels
  583								mirrorName, mirrorAPI, mirrorDeliver,
  584							)
  585						}
  586						ch <- mirrorMetric(nc.streamMirrorLag, float64(mirror.Lag))
  587						ch <- mirrorMetric(nc.streamMirrorActive, float64(mirror.Active))
  588					}
```


### `jsz.go` lines 590–645

Consumer series: `last_delivery_seconds` and `last_ack_seconds` are computed from the consumer's `ts` minus `delivered.last_active` / `ack_floor.last_active` and only when those exist; the eight counters are copied straight from the consumer info fields of the same name.

```go
  590					// Now with the consumers.
  591					for _, consumer := range stream.Consumer {
  592						consumerName = consumer.Name
  593						if consumer.Config != nil {
  594							consumerDesc = consumer.Config.Description
  595						}
  596						if consumer.Cluster != nil {
  597							consumerLeader = consumer.Cluster.Leader
  598							if consumerLeader == serverName {
  599								isConsumerLeader = "true"
  600							} else {
  601								isConsumerLeader = "false"
  602							}
  603						} else {
  604							isConsumerLeader = "true"
  605						}
  606	
  607						// (same labels as stream)
  608						consumerLabelValues := append([]string{}, streamLabelValues...)
  609	
  610						consumerLabelValues = append(
  611							consumerLabelValues,
  612							// Consumer Labels
  613							consumerName, consumerLeader, isConsumerLeader, consumerDesc,
  614						)
  615						for _, k := range nc.consumerMetaKeys {
  616							var v string
  617							if consumer.Config != nil {
  618								v = consumer.Config.Metadata[k]
  619							}
  620							consumerLabelValues = append(consumerLabelValues, v)
  621						}
  622						consumerMetric := func(key *prometheus.Desc, value float64) prometheus.Metric {
  623							return prometheus.MustNewConstMetric(key, prometheus.GaugeValue, value, consumerLabelValues...)
  624						}
  625						if consumer.Delivered.Last != nil {
  626							consumerLastDelivery := consumer.TimeStamp.Sub(*consumer.Delivered.Last).Seconds()
  627							ch <- consumerMetric(nc.consumerLastDelivery, consumerLastDelivery)
  628						}
  629						if consumer.AckFloor.Last != nil {
  630							consumerLastAck := consumer.TimeStamp.Sub(*consumer.AckFloor.Last).Seconds()
  631							ch <- consumerMetric(nc.consumerLastAck, consumerLastAck)
  632						}
  633						ch <- consumerMetric(nc.consumerDeliveredConsumerSeq, float64(consumer.Delivered.Consumer))
  634						ch <- consumerMetric(nc.consumerDeliveredStreamSeq, float64(consumer.Delivered.Stream))
  635						ch <- consumerMetric(nc.consumerNumAckPending, float64(consumer.NumAckPending))
  636						ch <- consumerMetric(nc.consumerNumRedelivered, float64(consumer.NumRedelivered))
  637						ch <- consumerMetric(nc.consumerNumWaiting, float64(consumer.NumWaiting))
  638						ch <- consumerMetric(nc.consumerNumPending, float64(consumer.NumPending))
  639						ch <- consumerMetric(nc.consumerAckFloorStreamSeq, float64(consumer.AckFloor.Stream))
  640						ch <- consumerMetric(nc.consumerAckFloorConsumerSeq, float64(consumer.AckFloor.Consumer))
  641					}
  642				}
  643			}
  644		}
  645	}
```


## collector/connz.go — the connection collector, summary and detailed


### `connz.go` lines 29–36

```go
   29	const (
   30		connzEndpoint         = "connz"
   31		connzDetailedEndpoint = "connz_detailed"
   32	)
   33	
   34	func isConnzEndpoint(system, endpoint string) bool {
   35		return system == CoreSystem && (endpoint == connzEndpoint || endpoint == connzDetailedEndpoint)
   36	}
```


### `connz.go` lines 72–137

The ten summary series, labelled `server_id` only.

```go
   72	func createConnzCollector(system string) *connzCollector {
   73		summaryLabels := []string{"server_id"}
   74		return &connzCollector{
   75			httpClient: http.DefaultClient,
   76			numConnections: prometheus.NewDesc(
   77				prometheus.BuildFQName(system, connzEndpoint, "num_connections"),
   78				"num_connections",
   79				summaryLabels,
   80				nil,
   81			),
   82			offset: prometheus.NewDesc(
   83				prometheus.BuildFQName(system, connzEndpoint, "offset"),
   84				"offset",
   85				summaryLabels,
   86				nil,
   87			),
   88			total: prometheus.NewDesc(
   89				prometheus.BuildFQName(system, connzEndpoint, "total"),
   90				"total",
   91				summaryLabels,
   92				nil,
   93			),
   94			limit: prometheus.NewDesc(
   95				prometheus.BuildFQName(system, connzEndpoint, "limit"),
   96				"limit",
   97				summaryLabels,
   98				nil,
   99			),
  100			totalPendingBytes: prometheus.NewDesc(
  101				prometheus.BuildFQName(system, connzEndpoint, "pending_bytes"),
  102				"pending_bytes",
  103				summaryLabels,
  104				nil,
  105			),
  106			totalSubscriptions: prometheus.NewDesc(
  107				prometheus.BuildFQName(system, connzEndpoint, "subscriptions"),
  108				"subscriptions",
  109				summaryLabels,
  110				nil,
  111			),
  112			totalInBytes: prometheus.NewDesc(
  113				prometheus.BuildFQName(system, connzEndpoint, "in_bytes"),
  114				"in_bytes",
  115				summaryLabels,
  116				nil,
  117			),
  118			totalOutBytes: prometheus.NewDesc(
  119				prometheus.BuildFQName(system, connzEndpoint, "out_bytes"),
  120				"out_bytes",
  121				summaryLabels,
  122				nil,
  123			),
  124			totalInMsgs: prometheus.NewDesc(
  125				prometheus.BuildFQName(system, connzEndpoint, "in_msgs"),
  126				"in_msgs",
  127				summaryLabels,
  128				nil,
  129			),
  130			totalOutMsgs: prometheus.NewDesc(
  131				prometheus.BuildFQName(system, connzEndpoint, "out_msgs"),
  132				"out_msgs",
  133				summaryLabels,
  134				nil,
  135			),
  136		}
  137	}
```


### `connz.go` lines 139–142

The fourteen labels of the detailed (per-connection) series.

```go
  139	func createConnzDetailedCollector(system string) *connzCollector {
  140		connzCollector := createConnzCollector(system)
  141		detailLabels := []string{"server_id", "cid", "kind", "type", "ip", "port", "name", "name_tag",
  142			"account", "account_id", "lang", "version", "tls_version", "tls_cipher_suite"}
```


### `connz.go` lines 212–236

The detailed collector adds `?auth=true` to the URL — and neither form sets `limit`, so the server's default page of 1024 connections is what the sums cover. Only `limit` is described.

```go
  212	func newConnzCollector(system, endpoint string, servers []*CollectedServer) prometheus.Collector {
  213		var nc *connzCollector
  214		if endpoint == connzDetailedEndpoint {
  215			nc = createConnzDetailedCollector(system)
  216			nc.detailed = true
  217		} else {
  218			nc = createConnzCollector(system)
  219		}
  220		nc.servers = make([]*CollectedServer, len(servers))
  221		for i, s := range servers {
  222			nc.servers[i] = &CollectedServer{
  223				ID:  s.ID,
  224				URL: s.URL + "/" + connzEndpoint,
  225			}
  226	
  227			if nc.detailed {
  228				nc.servers[i].URL += "?auth=true"
  229			}
  230		}
  231		return nc
  232	}
  233	
  234	func (nc *connzCollector) Describe(ch chan<- *prometheus.Desc) {
  235		ch <- nc.limit
  236	}
```


### `connz.go` lines 238–285

What is a counter: only the four `in_*` / `out_*` series (per connection and summed); everything else is a gauge or untyped; `account_id` receives the same value as `account`.

```go
  238	// Collect gathers the server connz metrics.
  239	func (nc *connzCollector) Collect(ch chan<- prometheus.Metric) {
  240		for _, server := range nc.servers {
  241			var resp Connz
  242			if err := getMetricURL(nc.httpClient, server.URL, &resp); err != nil {
  243				Debugf("ignoring server %s: %v", server.ID, err)
  244				continue
  245			}
  246	
  247			var pendingBytes, subscriptions, inBytes, outBytes, inMsgs, outMsgs float64
  248			for _, conn := range resp.Connections {
  249				pendingBytes += conn.PendingBytes
  250				subscriptions += conn.Subscriptions
  251				inBytes += conn.InBytes
  252				outBytes += conn.OutBytes
  253				inMsgs += conn.InMsgs
  254				outMsgs += conn.OutMsgs
  255				if nc.detailed {
  256					detailLabelValues := []string{server.ID, conn.Cid, conn.Kind, conn.Type, conn.IP, conn.Port,
  257						conn.Name, conn.NameTag, conn.Account, conn.Account, conn.Lang, conn.Version, conn.TLSVersion, conn.TLSCipherSuite}
  258					ch <- prometheus.MustNewConstMetric(nc.pendingBytes, prometheus.GaugeValue, conn.PendingBytes, detailLabelValues...)
  259					ch <- prometheus.MustNewConstMetric(nc.subscriptions, prometheus.GaugeValue, conn.Subscriptions,
  260						detailLabelValues...)
  261					ch <- prometheus.MustNewConstMetric(nc.inBytes, prometheus.CounterValue, conn.InBytes, detailLabelValues...)
  262					ch <- prometheus.MustNewConstMetric(nc.outBytes, prometheus.CounterValue, conn.OutBytes, detailLabelValues...)
  263					ch <- prometheus.MustNewConstMetric(nc.inMsgs, prometheus.CounterValue, conn.InMsgs, detailLabelValues...)
  264					ch <- prometheus.MustNewConstMetric(nc.outMsgs, prometheus.CounterValue, conn.OutMsgs, detailLabelValues...)
  265					ch <- prometheus.MustNewConstMetric(nc.start, prometheus.UntypedValue, conn.Start, detailLabelValues...)
  266					ch <- prometheus.MustNewConstMetric(nc.lastActivity, prometheus.UntypedValue, conn.LastActivity,
  267						detailLabelValues...)
  268					ch <- prometheus.MustNewConstMetric(nc.rtt, prometheus.GaugeValue, conn.Rtt, detailLabelValues...)
  269					ch <- prometheus.MustNewConstMetric(nc.uptime, prometheus.UntypedValue, conn.Uptime, detailLabelValues...)
  270					ch <- prometheus.MustNewConstMetric(nc.idle, prometheus.GaugeValue, conn.Idle, detailLabelValues...)
  271				}
  272			}
  273	
  274			ch <- prometheus.MustNewConstMetric(nc.numConnections, prometheus.GaugeValue, resp.NumConnections, server.ID)
  275			ch <- prometheus.MustNewConstMetric(nc.total, prometheus.GaugeValue, resp.Total, server.ID)
  276			ch <- prometheus.MustNewConstMetric(nc.offset, prometheus.GaugeValue, resp.Offset, server.ID)
  277			ch <- prometheus.MustNewConstMetric(nc.limit, prometheus.GaugeValue, resp.Limit, server.ID)
  278			ch <- prometheus.MustNewConstMetric(nc.totalPendingBytes, prometheus.GaugeValue, pendingBytes, server.ID)
  279			ch <- prometheus.MustNewConstMetric(nc.totalSubscriptions, prometheus.GaugeValue, subscriptions, server.ID)
  280			ch <- prometheus.MustNewConstMetric(nc.totalInBytes, prometheus.CounterValue, inBytes, server.ID)
  281			ch <- prometheus.MustNewConstMetric(nc.totalOutBytes, prometheus.CounterValue, outBytes, server.ID)
  282			ch <- prometheus.MustNewConstMetric(nc.totalInMsgs, prometheus.CounterValue, inMsgs, server.ID)
  283			ch <- prometheus.MustNewConstMetric(nc.totalOutMsgs, prometheus.CounterValue, outMsgs, server.ID)
  284		}
  285	}
```


### `connz.go` lines 323–365

`rtt` is converted to microseconds; `uptime` and `idle` to milliseconds through the server's own `y`/`d`/`h`/`m`/`s` format; `start` and `last_activity` to epoch milliseconds.

```go
  323	// UnmarshalJSON converts JSON string to struct. This is required as we want to
  324	// parse time or duration fields as `time.Duration` and then to milliseconds
  325	func (c *ConnzConnection) UnmarshalJSON(data []byte) error {
  326		var connection map[string]interface{}
  327		if err := json.Unmarshal(data, &connection); err != nil {
  328			return err
  329		}
  330		if val, exists := connection["cid"]; exists {
  331			c.Cid = fmt.Sprintf("%v", val)
  332		}
  333		if val, exists := connection["kind"]; exists {
  334			c.Kind = val.(string)
  335		}
  336		if val, exists := connection["type"]; exists {
  337			c.Type = val.(string)
  338		}
  339		if val, exists := connection["ip"]; exists {
  340			c.IP = val.(string)
  341		}
  342		if val, exists := connection["port"]; exists {
  343			c.Port = fmt.Sprintf("%v", val)
  344		}
  345		if val, exists := connection["start"]; exists {
  346			c.Start = parseDateString(val.(string))
  347		}
  348		if val, exists := connection["last_activity"]; exists {
  349			c.LastActivity = parseDateString(val.(string))
  350		}
  351		if val, exists := connection["rtt"]; exists {
  352			// rtt should be in seconds at most!
  353			if parsedVal, err := time.ParseDuration(val.(string)); err == nil {
  354				c.Rtt = float64(parsedVal.Microseconds())
  355			} else {
  356				Errorf("string %s could not be parsed as duration for rtt: %s", val.(string), err)
  357				c.Rtt = -1
  358			}
  359		}
  360		if val, exists := connection["uptime"]; exists {
  361			c.Uptime = parseDuration(val.(string))
  362		}
  363		if val, exists := connection["idle"]; exists {
  364			c.Idle = parseDuration(val.(string))
  365		}
```


### `connz.go` lines 408–453

```go
  408	// parse a date-time string as epoch milliseconds
  409	func parseDateString(data string) float64 {
  410		theTime, err := time.Parse(time.RFC3339Nano, data)
  411		if err != nil {
  412			Errorf("could not parse value %s as a date-time object using the layout %s", data, time.RFC3339Nano)
  413			return -1
  414		}
  415		return float64(theTime.UnixMilli())
  416	}
  417	
  418	// parse the duration as epoch milliseconds
  419	// for some reason NATS server deviated away from the allowed options
  420	// for duration. Please see https://github.com/nats-io/nats-server/blob/main/server/monitor.go#L1309
  421	// or (if the lines changed) check the function `server.myUptime(d time.Duration) string `
  422	// duration can possibly have `y`, `d`, `h`, `m`, `s`
  423	// for years 365 days is factored in NATS server
  424	func parseDuration(data string) float64 {
  425		accruedHours, i := extractHoursFromYearsAndDays(data)
  426		if accruedHours == -1 {
  427			return -1
  428		}
  429		durationWithoutYearsAndDays := data[i:]
  430		splitByHours := strings.Split(durationWithoutYearsAndDays, "h")
  431		durationToParse := ""
  432		switch len(splitByHours) {
  433		case 1:
  434			durationToParse = fmt.Sprintf("%dh%s", accruedHours, splitByHours[0])
  435		case 2:
  436			if hours, err := strconv.Atoi(splitByHours[0]); err == nil {
  437				accruedHours += hours
  438				durationToParse = fmt.Sprintf("%dh%s", accruedHours, splitByHours[1])
  439			} else {
  440				Errorf("string %s could not be parsed as duration: %s", data, err)
  441				return -1
  442			}
  443		default:
  444			Errorf("string %s could not be parsed as duration", data)
  445			return -1
  446		}
  447		parsedValue, err := time.ParseDuration(durationToParse)
  448		if err == nil {
  449			return float64(parsedValue.Milliseconds())
  450		}
  451		Errorf("string %s could not be parsed as duration: %s", data, err)
  452		return -1
  453	}
```


## collector/healthz.go — status is 0 when healthy


### `healthz.go` lines 25–45

Three endpoint names, one per flag; there is no `js-meta-only` variant.

```go
   25		healthzEndpoint              = "healthz"
   26		healthzJsEnabledOnlyEndpoint = "healthz_js_enabled_only"
   27		healthzJsServerOnlyEndpoint  = "healthz_js_server_only"
   28	)
   29	
   30	func isHealthzEndpoint(system, endpoint string) bool {
   31		return system == CoreSystem && (endpoint == healthzEndpoint ||
   32			endpoint == healthzJsEnabledOnlyEndpoint ||
   33			endpoint == healthzJsServerOnlyEndpoint)
   34	}
   35	
   36	type healthzCollector struct {
   37		sync.Mutex
   38	
   39		httpClient *http.Client
   40		servers    []*CollectedServer
   41	
   42		status      *prometheus.Desc
   43		statusValue *prometheus.Desc
   44	}
   45	
```


### `healthz.go` lines 46–80

The two series and the query string each variant sends.

```go
   46	func newHealthzCollector(system, endpoint string, servers []*CollectedServer) prometheus.Collector {
   47		nc := &healthzCollector{
   48			httpClient: http.DefaultClient,
   49			status: prometheus.NewDesc(
   50				prometheus.BuildFQName(system, endpoint, "status"),
   51				"status",
   52				[]string{"server_id"},
   53				nil,
   54			),
   55			statusValue: prometheus.NewDesc(
   56				prometheus.BuildFQName(system, endpoint, "status_value"),
   57				"status",
   58				[]string{"server_id", "value"},
   59				nil,
   60			),
   61		}
   62	
   63		healthzURLPathAndQuerryArgs := healthzEndpoint
   64		switch endpoint {
   65		case healthzJsEnabledOnlyEndpoint:
   66			healthzURLPathAndQuerryArgs = healthzEndpoint + "?js-enabled-only=true"
   67		case healthzJsServerOnlyEndpoint:
   68			healthzURLPathAndQuerryArgs = healthzEndpoint + "?js-server-only=true"
   69		}
   70	
   71		nc.servers = make([]*CollectedServer, len(servers))
   72		for i, s := range servers {
   73			nc.servers[i] = &CollectedServer{
   74				ID:  s.ID,
   75				URL: s.URL + "/" + healthzURLPathAndQuerryArgs,
   76			}
   77		}
   78	
   79		return nc
   80	}
```


### `healthz.go` lines 82–125

`<ns>_healthz_status` is **0 for `ok` and 1 otherwise** ("keep the existing metric behaving the same"); `<ns>_healthz_status_value{value="ok"|"<status>"|"unreachable"}` is 1 when ok and 0 otherwise and is the only series emitted when the server cannot be reached.

```go
   82	func (nc *healthzCollector) Describe(ch chan<- *prometheus.Desc) {
   83		ch <- nc.status
   84	}
   85	
   86	// Collect gathers the server healthz metrics.
   87	func (nc *healthzCollector) Collect(ch chan<- prometheus.Metric) {
   88		for _, server := range nc.servers {
   89			httpGetError := false
   90	
   91			var health Healthz
   92			if err := getMetricURL(nc.httpClient, server.URL, &health); err != nil {
   93				Debugf("error collecting server %s: %v", server.ID, err)
   94				httpGetError = true
   95			}
   96	
   97			// keep the existing metric behaving the same
   98			if !httpGetError {
   99				var status float64 = 1
  100				if health.Status == "ok" {
  101					status = 0
  102				}
  103				ch <- prometheus.MustNewConstMetric(nc.status, prometheus.GaugeValue, status, server.ID)
  104			}
  105	
  106			// additional metric to provide more information even if the server connection has issues
  107			{
  108				var status float64
  109				if health.Status == "ok" {
  110					status = 1
  111				} else {
  112					status = 0
  113				}
  114	
  115				var value string
  116				if httpGetError {
  117					value = "unreachable"
  118				} else {
  119					value = health.Status
  120				}
  121	
  122				ch <- prometheus.MustNewConstMetric(nc.statusValue, prometheus.GaugeValue, status, server.ID, value)
  123			}
  124		}
  125	}
```


## collector/accstatz.go and accountz.go — per-account series


### `accstatz.go` lines 24–47

Reads `/accstatz?unused=1`.

```go
   24	func isAccstatzEndpoint(system, endpoint string) bool {
   25		return system == CoreSystem && endpoint == "accstatz"
   26	}
   27	
   28	type accstatzCollector struct {
   29		sync.Mutex
   30	
   31		httpClient     *http.Client
   32		servers        []*CollectedServer
   33		accountMetrics *accountMetrics
   34	}
   35	
   36	func newAccstatzCollector(system, endpoint string, servers []*CollectedServer) prometheus.Collector {
   37		nc := &accstatzCollector{
   38			httpClient:     http.DefaultClient,
   39			accountMetrics: newAccountMetrics(system, endpoint),
   40		}
   41	
   42		nc.servers = make([]*CollectedServer, len(servers))
   43		for i, s := range servers {
   44			nc.servers[i] = &CollectedServer{
   45				ID:  s.ID,
   46				URL: s.URL + "/accstatz?unused=1",
   47			}
```


### `accstatz.go` lines 87–141

Nine series per account, labelled `server_id`, `account`, `account_id`, `account_name` — including `slow_consumers` per account.

```go
   87	func newAccountMetrics(system, endpoint string) *accountMetrics {
   88	
   89		// Base labels that are common to all metrics
   90		baseLabels := []string{"server_id", "account", "account_id", "account_name"}
   91	
   92		account := &accountMetrics{
   93			connections: prometheus.NewDesc(
   94				prometheus.BuildFQName(system, endpoint, "current_connections"),
   95				"current_connections",
   96				baseLabels,
   97				nil),
   98			totalConnections: prometheus.NewDesc(
   99				prometheus.BuildFQName(system, endpoint, "total_connections"),
  100				"total_connections",
  101				baseLabels,
  102				nil),
  103			numSubs: prometheus.NewDesc(
  104				prometheus.BuildFQName(system, endpoint, "subscriptions"),
  105				"subscriptions",
  106				baseLabels,
  107				nil),
  108			leafNodes: prometheus.NewDesc(
  109				prometheus.BuildFQName(system, endpoint, "leaf_nodes"),
  110				"leaf_nodes",
  111				baseLabels,
  112				nil),
  113			sentMsgs: prometheus.NewDesc(
  114				prometheus.BuildFQName(system, endpoint, "sent_messages"),
  115				"sent_messages",
  116				baseLabels,
  117				nil),
  118			sentBytes: prometheus.NewDesc(
  119				prometheus.BuildFQName(system, endpoint, "sent_bytes"),
  120				"sent_bytes",
  121				baseLabels,
  122				nil),
  123			receivedMsgs: prometheus.NewDesc(
  124				prometheus.BuildFQName(system, endpoint, "received_messages"),
  125				"received_messages",
  126				baseLabels,
  127				nil),
  128			receivedBytes: prometheus.NewDesc(
  129				prometheus.BuildFQName(system, endpoint, "received_bytes"),
  130				"received_bytes",
  131				baseLabels,
  132				nil),
  133			slowConsumers: prometheus.NewDesc(
  134				prometheus.BuildFQName(system, endpoint, "slow_consumers"),
  135				"slow_consumers",
  136				baseLabels,
  137				nil),
  138		}
  139	
  140		return account
  141	}
```


### `accountz.go` lines 25–36

```go
   25	func isAccountzEndpoint(system, endpoint string) bool {
   26		return system == CoreSystem && endpoint == "accountz"
   27	}
   28	
   29	type accountzCollector struct {
   30		sync.Mutex
   31	
   32		httpClient            *http.Client
   33		servers               []*CollectedServer
   34		accountDetailsMetrics *accountDetailsMetrics
   35	}
   36	
```


### `accountz.go` lines 81–101

Two phases: the account list, then `/accountz?acc=<id>` per account — one HTTP request per account per scrape.

```go
   81	// 2. Get detailed info for each account from /accountz?acc=<account_id>
   82	func (nc *accountzCollector) Collect(ch chan<- prometheus.Metric) {
   83		for _, server := range nc.servers {
   84			// Phase 1: Get list of accounts
   85			var accountList Accountz
   86			if err := getMetricURL(nc.httpClient, server.URL, &accountList); err != nil {
   87				Debugf("ignoring server %s: %v", server.ID, err)
   88				continue
   89			}
   90	
   91			// Phase 2: Get detailed info for each account
   92			for _, accountID := range accountList.Accounts {
   93				var accountDetail AccountzDetail
   94				accountURL := server.URL + "?acc=" + accountID
   95				if err := getMetricURL(nc.httpClient, accountURL, &accountDetail); err != nil {
   96					Debugf("ignoring account %s on server %s: %v", accountID, server.ID, err)
   97					continue
   98				}
   99	
  100				nc.accountDetailsMetrics.Collect(server, &accountDetail, ch)
  101			}
```


### `accountz.go` lines 127–131

```go
  127	func newAccountDetailsMetrics(system, endpoint string) *accountDetailsMetrics {
  128	
  129		// Base labels that are common to all metrics
  130		baseLabels := []string{"server_id", "account_id", "account_name"}
  131	
```


### `accountz.go` lines 133–210

The fifteen series: seven states and eight JWT limits.

```go
  133			connections: prometheus.NewDesc(
  134				prometheus.BuildFQName(system, endpoint, "client_connections"),
  135				"client_connections",
  136				baseLabels,
  137				nil),
  138			leafnodeConnections: prometheus.NewDesc(
  139				prometheus.BuildFQName(system, endpoint, "leafnode_connections"),
  140				"leafnode_connections",
  141				baseLabels,
  142				nil),
  143			subscriptions: prometheus.NewDesc(
  144				prometheus.BuildFQName(system, endpoint, "subscriptions"),
  145				"subscriptions",
  146				baseLabels,
  147				nil),
  148			isSystem: prometheus.NewDesc(
  149				prometheus.BuildFQName(system, endpoint, "is_system"),
  150				"is_system",
  151				baseLabels,
  152				nil),
  153			expired: prometheus.NewDesc(
  154				prometheus.BuildFQName(system, endpoint, "expired"),
  155				"expired",
  156				baseLabels,
  157				nil),
  158			complete: prometheus.NewDesc(
  159				prometheus.BuildFQName(system, endpoint, "complete"),
  160				"complete",
  161				baseLabels,
  162				nil),
  163			jetstreamEnabled: prometheus.NewDesc(
  164				prometheus.BuildFQName(system, endpoint, "jetstream_enabled"),
  165				"jetstream_enabled",
  166				baseLabels,
  167				nil),
  168			// New Limits metrics
  169			limitSubs: prometheus.NewDesc(
  170				prometheus.BuildFQName(system, endpoint, "limit_subs"),
  171				"limit_subs",
  172				baseLabels,
  173				nil),
  174			limitData: prometheus.NewDesc(
  175				prometheus.BuildFQName(system, endpoint, "limit_data"),
  176				"limit_data",
  177				baseLabels,
  178				nil),
  179			limitPayload: prometheus.NewDesc(
  180				prometheus.BuildFQName(system, endpoint, "limit_payload"),
  181				"limit_payload",
  182				baseLabels,
  183				nil),
  184			limitImports: prometheus.NewDesc(
  185				prometheus.BuildFQName(system, endpoint, "limit_imports"),
  186				"limit_imports",
  187				baseLabels,
  188				nil),
  189			limitExports: prometheus.NewDesc(
  190				prometheus.BuildFQName(system, endpoint, "limit_exports"),
  191				"limit_exports",
  192				baseLabels,
  193				nil),
  194			limitWildcards: prometheus.NewDesc(
  195				prometheus.BuildFQName(system, endpoint, "limit_wildcards"),
  196				"limit_wildcards",
  197				baseLabels,
  198				nil),
  199			limitConn: prometheus.NewDesc(
  200				prometheus.BuildFQName(system, endpoint, "limit_conn"),
  201				"limit_conn",
  202				baseLabels,
  203				nil),
  204			limitLeaf: prometheus.NewDesc(
  205				prometheus.BuildFQName(system, endpoint, "limit_leaf"),
  206				"limit_leaf",
  207				baseLabels,
  208				nil),
  209		}
  210	
```


## collector/gatewayz.go and leafz.go


### `gatewayz.go` lines 26–34

```go
   26	func isGatewayzEndpoint(system, endpoint string) bool {
   27		return system == CoreSystem && endpoint == "gatewayz"
   28	}
   29	
   30	type gatewayzCollector struct {
   31		sync.Mutex
   32	
   33		httpClient       *http.Client
   34		servers          []*CollectedServer
```


### `gatewayz.go` lines 95–160

Twelve series each for `outbound_gateway_*` and `inbound_gateway_*`; nothing is emitted when the server has no gateways.

```go
   95	func newGateway(system, endpoint, gwType string) *gateway {
   96		gw := &gateway{
   97			configured: prometheus.NewDesc(
   98				prometheus.BuildFQName(system, endpoint, gwType+"_configured"),
   99				"configured",
  100				[]string{"gateway_name", "cid", "remote_gateway_name", "server_id"},
  101				nil),
  102			connStart: prometheus.NewDesc(
  103				prometheus.BuildFQName(system, endpoint, gwType+"_conn_start_time_seconds"),
  104				"conn_start_time_seconds",
  105				[]string{"gateway_name", "cid", "remote_gateway_name", "server_id"},
  106				nil),
  107			connLastActivity: prometheus.NewDesc(
  108				prometheus.BuildFQName(system, endpoint, gwType+"_conn_last_activity_seconds"),
  109				"conn_last_activity_seconds",
  110				[]string{"gateway_name", "cid", "remote_gateway_name", "server_id"},
  111				nil),
  112			connUptime: prometheus.NewDesc(
  113				prometheus.BuildFQName(system, endpoint, gwType+"_conn_uptime_seconds"),
  114				"conn_uptime_seconds",
  115				[]string{"gateway_name", "cid", "remote_gateway_name", "server_id"},
  116				nil),
  117			connIdle: prometheus.NewDesc(
  118				prometheus.BuildFQName(system, endpoint, gwType+"_conn_idle_seconds"),
  119				"conn_idle_seconds",
  120				[]string{"gateway_name", "cid", "remote_gateway_name", "server_id"},
  121				nil),
  122			connRtt: prometheus.NewDesc(
  123				prometheus.BuildFQName(system, endpoint, gwType+"_conn_rtt"),
  124				"rtt",
  125				[]string{"gateway_name", "cid", "remote_gateway_name", "server_id"},
  126				nil),
  127			connPendingBytes: prometheus.NewDesc(
  128				prometheus.BuildFQName(system, endpoint, gwType+"_conn_pending_bytes"),
  129				"pending_bytes",
  130				[]string{"gateway_name", "cid", "remote_gateway_name", "server_id"},
  131				nil),
  132			connInMsgs: prometheus.NewDesc(
  133				prometheus.BuildFQName(system, endpoint, gwType+"_conn_in_msgs"),
  134				"in_msgs",
  135				[]string{"gateway_name", "cid", "remote_gateway_name", "server_id"},
  136				nil),
  137			connOutMsgs: prometheus.NewDesc(
  138				prometheus.BuildFQName(system, endpoint, gwType+"_conn_out_msgs"),
  139				"out_msgs",
  140				[]string{"gateway_name", "cid", "remote_gateway_name", "server_id"},
  141				nil),
  142			connInBytes: prometheus.NewDesc(
  143				prometheus.BuildFQName(system, endpoint, gwType+"_conn_in_bytes"),
  144				"in_bytes",
  145				[]string{"gateway_name", "cid", "remote_gateway_name", "server_id"},
  146				nil),
  147			connOutBytes: prometheus.NewDesc(
  148				prometheus.BuildFQName(system, endpoint, gwType+"_conn_out_bytes"),
  149				"out_bytes",
  150				[]string{"gateway_name", "cid", "remote_gateway_name", "server_id"},
  151				nil),
  152			connSubscriptions: prometheus.NewDesc(
  153				prometheus.BuildFQName(system, endpoint, gwType+"_conn_subscriptions"),
  154				"subscriptions",
  155				[]string{"gateway_name", "cid", "remote_gateway_name", "server_id"},
  156				nil),
  157		}
  158	
  159		return gw
  160	}
```


### `gatewayz.go` lines 162–177

```go
  162	// Describe
  163	func (gw *gateway) Describe(ch chan<- *prometheus.Desc) {
  164		ch <- gw.configured
  165		ch <- gw.connStart
  166		ch <- gw.connLastActivity
  167		ch <- gw.connUptime
  168		ch <- gw.connIdle
  169		ch <- gw.connRtt
  170		ch <- gw.connPendingBytes
  171		ch <- gw.connInMsgs
  172		ch <- gw.connOutMsgs
  173		ch <- gw.connInBytes
  174		ch <- gw.connOutBytes
  175		ch <- gw.connSubscriptions
  176	}
  177	
```


### `leafz.go` lines 27–30

```go
   27	func isLeafzEndpoint(system, endpoint string) bool {
   28		return system == CoreSystem && endpoint == "leafz"
   29	}
   30	
```


### `leafz.go` lines 42–58

`conn_nodes_total` is emitted even with no leaf connected (observed: 0).

```go
   42	func newLeafzCollector(system, endpoint string, servers []*CollectedServer) prometheus.Collector {
   43		nc := &leafzCollector{httpClient: http.DefaultClient}
   44		nc.leafNodesTotal = prometheus.NewDesc(
   45			prometheus.BuildFQName(system, endpoint, "conn_nodes_total"),
   46			"nodes_total",
   47			[]string{"server_id"},
   48			nil)
   49		nc.leafMetrics = newLeafMetrics(system, endpoint)
   50		nc.servers = make([]*CollectedServer, len(servers))
   51		for i, s := range servers {
   52			nc.servers[i] = &CollectedServer{
   53				ID:  s.ID,
   54				URL: s.URL + "/leafz",
   55			}
   56		}
   57		return nc
   58	}
```


### `leafz.go` lines 97–147

Eight series per leaf connection; `conn_subscriptions` carries one sample per subscription subject.

```go
   97	func newLeafMetrics(system, endpoint string) *leafMetrics {
   98	
   99		// Base labels that are common to all metrics
  100		baseLabels := []string{"server_id", "account", "account_id", "ip", "port", "name"}
  101		baseLabelsSub := []string{"server_id", "account", "account_id", "ip", "port", "name", "subscription"}
  102	
  103		leaf := &leafMetrics{
  104			info: prometheus.NewDesc(
  105				prometheus.BuildFQName(system, endpoint, "info"),
  106				"info",
  107				baseLabels,
  108				nil),
  109			connRtt: prometheus.NewDesc(
  110				prometheus.BuildFQName(system, endpoint, "conn_rtt"),
  111				"rtt",
  112				baseLabels,
  113				nil),
  114			connInMsgs: prometheus.NewDesc(
  115				prometheus.BuildFQName(system, endpoint, "conn_in_msgs"),
  116				"in_msgs",
  117				baseLabels,
  118				nil),
  119			connOutMsgs: prometheus.NewDesc(
  120				prometheus.BuildFQName(system, endpoint, "conn_out_msgs"),
  121				"out_msgs",
  122				baseLabels,
  123				nil),
  124			connInBytes: prometheus.NewDesc(
  125				prometheus.BuildFQName(system, endpoint, "conn_in_bytes"),
  126				"in_bytes",
  127				baseLabels,
  128				nil),
  129			connOutBytes: prometheus.NewDesc(
  130				prometheus.BuildFQName(system, endpoint, "conn_out_bytes"),
  131				"out_bytes",
  132				baseLabels,
  133				nil),
  134			connSubscriptionsTotal: prometheus.NewDesc(
  135				prometheus.BuildFQName(system, endpoint, "conn_subscriptions_total"),
  136				"subscriptions_total",
  137				baseLabels,
  138				nil),
  139			connSubscriptions: prometheus.NewDesc(
  140				prometheus.BuildFQName(system, endpoint, "conn_subscriptions"),
  141				"subscriptions",
  142				baseLabelsSub,
  143				nil),
  144		}
  145	
  146		return leaf
  147	}
```

