<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6, server/stream.go, consumer.go, jetstream.go, jetstream_api.go, jetstream_cluster.go and opts.go fetched from raw.githubusercontent.com · fetched 2026-09-02/03 -->
# nats-server v2.14.6 — `StreamConfig` and `ConsumerConfig`: the structs, the defaults the server applies, the validation, and what may change after creation

Verbatim line ranges from the tagged source, in the form of `constants-v2.14.6.md`. Behind
`wiki/reference/stream-and-consumer-config.md` (phase E step 2, `inbox/plan-the-reference-layer-2026-09-03.md`).
The behavioural half — every refusal string on the wire — is `config-mutability-observed-v2.14.6.md`.

## stream.go — `StreamConfig`

Every field with its JSON tag; the comments are the source's own. 38 JSON fields — the jsm.go schema at v0.4.1 has the same 38.

```go
   52	type StreamConfig struct {
   53		Name         string           `json:"name"`
   54		Description  string           `json:"description,omitempty"`
   55		Subjects     []string         `json:"subjects,omitempty"`
   56		Retention    RetentionPolicy  `json:"retention"`
   57		MaxConsumers int              `json:"max_consumers"`
   58		MaxMsgs      int64            `json:"max_msgs"`
   59		MaxBytes     int64            `json:"max_bytes"`
   60		MaxAge       time.Duration    `json:"max_age"`
   61		MaxMsgsPer   int64            `json:"max_msgs_per_subject"`
   62		MaxMsgSize   int32            `json:"max_msg_size,omitempty"`
   63		Discard      DiscardPolicy    `json:"discard"`
   64		Storage      StorageType      `json:"storage"`
   65		Replicas     int              `json:"num_replicas"`
   66		NoAck        bool             `json:"no_ack,omitempty"`
   67		Duplicates   time.Duration    `json:"duplicate_window,omitempty"`
   68		Placement    *Placement       `json:"placement,omitempty"`
   69		Mirror       *StreamSource    `json:"mirror,omitempty"`
   70		Sources      []*StreamSource  `json:"sources,omitempty"`
   71		Compression  StoreCompression `json:"compression"`
   72		FirstSeq     uint64           `json:"first_seq,omitempty"`
   73	
   74		// Allow applying a subject transform to incoming messages before doing anything else
   75		SubjectTransform *SubjectTransformConfig `json:"subject_transform,omitempty"`
   76	
   77		// Allow republish of the message after being sequenced and stored.
   78		RePublish *RePublish `json:"republish,omitempty"`
   79	
   80		// Allow higher performance, direct access to get individual messages. E.g. KeyValue
   81		AllowDirect bool `json:"allow_direct"`
   82		// Allow higher performance and unified direct access for mirrors as well.
   83		MirrorDirect bool `json:"mirror_direct"`
   84	
   85		// Allow KV like semantics to also discard new on a per subject basis
   86		DiscardNewPer bool `json:"discard_new_per_subject,omitempty"`
   87	
   88		// Optional qualifiers. These can not be modified after set to true.
   89	
   90		// Sealed will seal a stream so no messages can get out or in.
   91		Sealed bool `json:"sealed"`
   92		// DenyDelete will restrict the ability to delete messages.
   93		DenyDelete bool `json:"deny_delete"`
   94		// DenyPurge will restrict the ability to purge messages.
   95		DenyPurge bool `json:"deny_purge"`
   96		// AllowRollup allows messages to be placed into the system and purge
   97		// all older messages using a special msg header.
   98		AllowRollup bool `json:"allow_rollup_hdrs"`
   99	
  100		// The following defaults will apply to consumers when created against
  101		// this stream, unless overridden manually.
  102		// TODO(nat): Can/should we name these better?
  103		ConsumerLimits StreamConsumerLimits `json:"consumer_limits"`
  104	
  105		// AllowMsgTTL allows header initiated per-message TTLs. If disabled,
  106		// then the `NATS-TTL` header will be ignored.
  107		AllowMsgTTL bool `json:"allow_msg_ttl"`
  108	
  109		// SubjectDeleteMarkerTTL sets the TTL of delete marker messages left behind by
  110		// subject delete markers.
  111		SubjectDeleteMarkerTTL time.Duration `json:"subject_delete_marker_ttl,omitempty"`
  112	
  113		// AllowMsgCounter allows a stream to use (only) counter CRDTs.
  114		AllowMsgCounter bool `json:"allow_msg_counter,omitempty"`
  115	
  116		// AllowAtomicPublish allows atomic batch publishing into the stream.
  117		AllowAtomicPublish bool `json:"allow_atomic,omitempty"`
  118	
  119		// AllowMsgSchedules allows the scheduling of messages.
  120		AllowMsgSchedules bool `json:"allow_msg_schedules,omitempty"`
  121	
  122		// PersistMode allows to opt-in to different persistence mode settings.
  123		PersistMode PersistModeType `json:"persist_mode,omitempty"`
  124	
  125		// AllowBatchPublish allows fast batch publishing into the stream.
  126		AllowBatchPublish bool `json:"allow_batched,omitempty"`
  127	
  128		// Metadata is additional metadata for the Stream.
  129		Metadata map[string]string `json:"metadata,omitempty"`
  130	}
```

## stream.go — `StreamConsumerLimits`, `SubjectTransformConfig`, `RePublish`

```go
  166	}
  167	
  168	type StreamConsumerLimits struct {
  169		InactiveThreshold time.Duration `json:"inactive_threshold,omitempty"`
  170		MaxAckPending     int           `json:"max_ack_pending,omitempty"`
  171	}
  172	
  173	// SubjectTransformConfig is for applying a subject transform (to matching messages) before doing anything else when a new message is received
  174	type SubjectTransformConfig struct {
  175		Source      string `json:"src"`
  176		Destination string `json:"dest"`
  177	}
  178	
  179	// RePublish is for republishing messages once committed to a stream.
  180	type RePublish struct {
  181		Source      string `json:"src,omitempty"`
  182		Destination string `json:"dest"`
  183		HeadersOnly bool   `json:"headers_only,omitempty"`
  184	}
  185	
```

## stream.go — `StreamSourceInfo`, `StreamSource`, `StreamConsumerSource`, `ExternalStream`

```go
  395	type StreamSourceInfo struct {
  396		Name              string                   `json:"name"`
  397		External          *ExternalStream          `json:"external,omitempty"`
  398		Lag               uint64                   `json:"lag"`
  399		Active            time.Duration            `json:"active"`
  400		Error             *ApiError                `json:"error,omitempty"`
  401		FilterSubject     string                   `json:"filter_subject,omitempty"`
  402		SubjectTransforms []SubjectTransformConfig `json:"subject_transforms,omitempty"`
  403	}
  404	
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
```

## stream.go — the batch constants — the atomic and fast batch limits the docs call "operator-configurable"

```go
  440	const (
  441		streamDefaultMaxQueueMsgs  = 100_000
  442		streamDefaultMaxQueueBytes = 128 * 1024 * 1024
  443	)
  444	
  445	// For managing stream batches.
  446	const (
  447		streamDefaultMaxBatchTimeout = 10 * time.Second
  448		// Atomic batches.
  449		streamDefaultMaxAtomicBatchInflightPerStream = 50
  450		streamDefaultMaxAtomicBatchInflightTotal     = 1000
  451		streamDefaultMaxAtomicBatchSize              = 1000
  452		// Fast batches.
  453		streamDefaultMaxFastBatchInflightPerStream = 1000
  454		streamDefaultMaxFastBatchInflightTotal     = 50_000
  455	)
  456	
  457	var (
  458		streamMaxBatchTimeout = streamDefaultMaxBatchTimeout
  459		// Atomic batches.
  460		streamMaxAtomicBatchInflightPerStream = streamDefaultMaxAtomicBatchInflightPerStream
  461		streamMaxAtomicBatchInflightTotal     = streamDefaultMaxAtomicBatchInflightTotal
  462		streamMaxAtomicBatchSize              = streamDefaultMaxAtomicBatchSize
  463		// Fast batches.
  464		streamMaxFastBatchInflightPerStream = streamDefaultMaxFastBatchInflightPerStream
  465		streamMaxFastBatchInflightTotal     = streamDefaultMaxFastBatchInflightTotal
  466	)
  467	
  468	// Stream is a jetstream stream of messages. When we receive a message internally destined
  469	// for a Stream we will direct link from the client to this structure.
  470	type stream struct {
```

## stream.go — `StreamMaxReplicas`

```go
  714	
  715	// Replicas Range
  716	const StreamMaxReplicas = 5
  717	
```

## stream.go — `StreamDefaultDuplicatesWindow` and `checkStreamCfg` — the defaults the server fills in and the first validations

`cfg.Storage = FileStorage`, `cfg.Replicas = 1`, the `-1` limits, the 2-minute duplicate window clamped by the server limit and by `max_age`, `max_age >= 100ms`, the counter and scheduling exclusions, the `async` persist-mode conditions — and, in pedantic mode, every silent correction becomes an error.

```go
 1657	// StreamDefaultDuplicatesWindow default duplicates window.
 1658	const StreamDefaultDuplicatesWindow = 2 * time.Minute
 1659	
 1660	func (s *Server) checkStreamCfg(config *StreamConfig, acc *Account, pedantic bool) (StreamConfig, *ApiError) {
 1661		lim := &s.getOpts().JetStreamLimits
 1662	
 1663		if config == nil {
 1664			return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("stream configuration invalid"))
 1665		}
 1666		if !isValidAssetName(config.Name) {
 1667			return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("stream name is required and can not contain '.', '*', '>', '\\', '/'"))
 1668		}
 1669		if len(config.Name) > JSMaxNameLen {
 1670			return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("stream name is too long, maximum allowed is %d", JSMaxNameLen))
 1671		}
 1672		if len(config.Description) > JSMaxDescriptionLen {
 1673			return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("stream description is too long, maximum allowed is %d", JSMaxDescriptionLen))
 1674		}
 1675	
 1676		var metadataLen int
 1677		for k, v := range config.Metadata {
 1678			metadataLen += len(k) + len(v)
 1679		}
 1680		if metadataLen > JSMaxMetadataLen {
 1681			return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("stream metadata exceeds maximum size of %d bytes", JSMaxMetadataLen))
 1682		}
 1683	
 1684		cfg := *config
 1685	
 1686		if _, err := cfg.Retention.MarshalJSON(); err != nil {
 1687			return cfg, NewJSStreamInvalidConfigError(fmt.Errorf("invalid retention"))
 1688		}
 1689		if _, err := cfg.Discard.MarshalJSON(); err != nil {
 1690			return cfg, NewJSStreamInvalidConfigError(fmt.Errorf("invalid discard policy"))
 1691		}
 1692		if _, err := cfg.Compression.MarshalJSON(); err != nil {
 1693			return cfg, NewJSStreamInvalidConfigError(fmt.Errorf("invalid compression"))
 1694		}
 1695	
 1696		// Make file the default.
 1697		if cfg.Storage == 0 {
 1698			cfg.Storage = FileStorage
 1699		}
 1700		if _, err := cfg.Storage.MarshalJSON(); err != nil {
 1701			return cfg, NewJSStreamInvalidConfigError(fmt.Errorf("invalid storage type"))
 1702		}
 1703	
 1704		if cfg.Replicas == 0 {
 1705			cfg.Replicas = 1
 1706		}
 1707		if cfg.Replicas > StreamMaxReplicas {
 1708			return cfg, NewJSStreamInvalidConfigError(fmt.Errorf("maximum replicas is %d", StreamMaxReplicas))
 1709		}
 1710		if cfg.Replicas < 0 {
 1711			return cfg, NewJSReplicasCountCannotBeNegativeError()
 1712		}
 1713		if cfg.MaxMsgs == 0 || cfg.MaxMsgs < -1 {
 1714			if pedantic && cfg.MaxMsgs < -1 {
 1715				return StreamConfig{}, NewJSPedanticError(fmt.Errorf("max_msgs must be set to -1"))
 1716			}
 1717			cfg.MaxMsgs = -1
 1718		}
 1719		if cfg.MaxMsgsPer == 0 || cfg.MaxMsgsPer < -1 {
 1720			if pedantic && cfg.MaxMsgsPer < -1 {
 1721				return StreamConfig{}, NewJSPedanticError(fmt.Errorf("max_msgs_per_subject must be set to -1"))
 1722			}
 1723			cfg.MaxMsgsPer = -1
 1724		}
 1725		if cfg.MaxBytes == 0 || cfg.MaxBytes < -1 {
 1726			if pedantic && cfg.MaxBytes < -1 {
 1727				return StreamConfig{}, NewJSPedanticError(fmt.Errorf("max_bytes must be set to -1"))
 1728			}
 1729			cfg.MaxBytes = -1
 1730		}
 1731		if cfg.MaxMsgSize == 0 || cfg.MaxMsgSize < -1 {
 1732			if pedantic && cfg.MaxMsgSize < -1 {
 1733				return StreamConfig{}, NewJSPedanticError(fmt.Errorf("max_msg_size must be set to -1"))
 1734			}
 1735			cfg.MaxMsgSize = -1
 1736		}
 1737		if cfg.MaxConsumers == 0 || cfg.MaxConsumers < -1 {
 1738			if pedantic && cfg.MaxConsumers < -1 {
 1739				return StreamConfig{}, NewJSPedanticError(fmt.Errorf("max_consumers must be set to -1"))
 1740			}
 1741			cfg.MaxConsumers = -1
 1742		}
 1743		if cfg.MaxAge < 0 {
 1744			return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("max age can not be negative"))
 1745		}
 1746		if cfg.MaxAge != 0 && cfg.MaxAge < 100*time.Millisecond {
 1747			return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("max age needs to be >= 100ms"))
 1748		}
 1749	
 1750		if cfg.Duplicates == 0 && cfg.Mirror == nil && len(cfg.Sources) == 0 {
 1751			maxWindow := StreamDefaultDuplicatesWindow
 1752			if lim.Duplicates > 0 && maxWindow > lim.Duplicates {
 1753				if pedantic {
 1754					return StreamConfig{}, NewJSPedanticError(fmt.Errorf("duplicate window limits are higher than current limits"))
 1755				}
 1756				maxWindow = lim.Duplicates
 1757			}
 1758			if cfg.MaxAge != 0 && cfg.MaxAge < maxWindow {
 1759				if pedantic {
 1760					return StreamConfig{}, NewJSPedanticError(fmt.Errorf("duplicate window cannot be bigger than max age"))
 1761				}
 1762				cfg.Duplicates = cfg.MaxAge
 1763			} else {
 1764				cfg.Duplicates = maxWindow
 1765			}
 1766		}
 1767		if cfg.Duplicates < 0 {
 1768			return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("duplicates window can not be negative"))
 1769		}
 1770		// Check that duplicates is not larger then age if set.
 1771		if cfg.MaxAge != 0 && cfg.Duplicates > cfg.MaxAge {
 1772			return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("duplicates window can not be larger then max age"))
 1773		}
 1774		if lim.Duplicates > 0 && cfg.Duplicates > lim.Duplicates {
 1775			return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("duplicates window can not be larger then server limit of %v",
 1776				lim.Duplicates.String()))
 1777		}
 1778		if cfg.Duplicates > 0 && cfg.Duplicates < 100*time.Millisecond {
 1779			return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("duplicates window needs to be >= 100ms"))
 1780		}
 1781	
 1782		if cfg.DenyPurge && cfg.AllowRollup {
 1783			return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("roll-ups require the purge permission"))
 1784		}
 1785	
 1786		// Counter is not compatible with some settings.
 1787		if cfg.AllowMsgCounter {
 1788			if cfg.Discard == DiscardNew {
 1789				return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("counter stream cannot use discard new"))
 1790			}
 1791			if cfg.AllowMsgTTL {
 1792				return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("counter stream cannot use message TTLs"))
 1793			}
 1794			if cfg.AllowMsgSchedules {
 1795				return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("counter stream cannot use message schedules"))
 1796			}
 1797			if cfg.Retention != LimitsPolicy {
 1798				return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("counter stream can only use limits retention"))
 1799			}
 1800		}
 1801	
 1802		// Check for new discard new per subject, we require the discard policy to also be new.
 1803		if cfg.DiscardNewPer {
 1804			if cfg.Discard != DiscardNew {
 1805				return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("discard new per subject requires discard new policy to be set"))
 1806			}
 1807			if cfg.MaxMsgsPer <= 0 {
 1808				return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("discard new per subject requires max msgs per subject > 0"))
 1809			}
 1810		}
 1811	
 1812		if cfg.SubjectDeleteMarkerTTL > 0 {
 1813			if cfg.SubjectDeleteMarkerTTL < time.Second {
 1814				return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("subject delete marker TTL must be at least 1 second"))
 1815			}
 1816			if !cfg.AllowMsgTTL {
 1817				if pedantic {
 1818					return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("subject delete marker cannot be set if message TTLs are disabled"))
 1819				}
 1820				cfg.AllowMsgTTL = true
 1821			}
 1822			if !cfg.AllowRollup {
 1823				if pedantic {
 1824					return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("subject delete marker cannot be set if roll-ups are disabled"))
 1825				}
 1826				cfg.AllowRollup, cfg.DenyPurge = true, false
 1827			}
 1828		} else if cfg.SubjectDeleteMarkerTTL < 0 {
 1829			return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("subject delete marker TTL must not be negative"))
 1830		}
 1831	
 1832		if cfg.AllowMsgSchedules {
 1833			if cfg.Discard == DiscardNew {
 1834				return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("message scheduling cannot use discard new"))
 1835			}
 1836			if !cfg.AllowRollup {
 1837				if pedantic {
 1838					return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("message scheduling cannot be set if roll-ups are disabled"))
 1839				}
 1840				cfg.AllowRollup, cfg.DenyPurge = true, false
 1841			}
 1842		}
 1843	
 1844		if cfg.PersistMode == AsyncPersistMode {
 1845			if cfg.Storage != FileStorage {
 1846				return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("async persist mode is only supported on file storage"))
 1847			}
 1848			if cfg.Replicas > 1 {
 1849				return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("async persist mode is not supported on replicated streams"))
 1850			}
 1851			if cfg.AllowAtomicPublish {
 1852				return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("async persist mode is not supported with atomic batch publish"))
 1853			}
 1854		}
 1855	
 1856		getStream := func(streamName string) (bool, StreamConfig) {
 1857			var exists bool
 1858			var cfg StreamConfig
 1859			if s.JetStreamIsClustered() {
 1860				if js, _ := s.getJetStreamCluster(); js != nil {
```

## stream.go — `checkStreamCfg`, continued — mirrors and sources, subject checks, republish, placement

```go
 1860				if js, _ := s.getJetStreamCluster(); js != nil {
 1861					js.mu.RLock()
 1862					if sa := js.streamAssignment(acc.Name, streamName); sa != nil {
 1863						cfg = *sa.Config.clone()
 1864						exists = true
 1865					}
 1866					js.mu.RUnlock()
 1867				}
 1868			} else if mset, err := acc.lookupStream(streamName); err == nil {
 1869				cfg = mset.cfg
 1870				exists = true
 1871			}
 1872			return exists, cfg
 1873		}
 1874	
 1875		hasStream := func(streamName string) (bool, int32, []string) {
 1876			exists, cfg := getStream(streamName)
 1877			return exists, cfg.MaxMsgSize, cfg.Subjects
 1878		}
 1879	
 1880		var streamSubs []string
 1881		var deliveryPrefixes []string
 1882		var apiPrefixes []string
 1883	
 1884		// Do some pre-checking for mirror config to avoid cycles in clustered mode.
 1885		if cfg.Mirror != nil {
 1886			if cfg.FirstSeq > 0 {
 1887				return StreamConfig{}, NewJSMirrorWithFirstSeqError()
 1888			}
 1889			if len(cfg.Subjects) > 0 {
 1890				return StreamConfig{}, NewJSMirrorWithSubjectsError()
 1891			}
 1892			if len(cfg.Sources) > 0 {
 1893				return StreamConfig{}, NewJSMirrorWithSourcesError()
 1894			}
 1895			if cfg.AllowMsgCounter {
 1896				return StreamConfig{}, NewJSMirrorWithCountersError()
 1897			}
 1898			if cfg.AllowAtomicPublish {
 1899				return StreamConfig{}, NewJSMirrorWithAtomicPublishError()
 1900			}
 1901			if cfg.AllowBatchPublish {
 1902				return StreamConfig{}, NewJSMirrorWithBatchPublishError()
 1903			}
 1904			if cfg.AllowMsgSchedules {
 1905				return StreamConfig{}, NewJSMirrorWithMsgSchedulesError()
 1906			}
 1907			if c := cfg.Mirror.Consumer; c != nil {
 1908				if !isValidAssetName(c.Name) {
 1909					return StreamConfig{}, NewJSMirrorDurableConsumerCfgInvalidError()
 1910				}
 1911				if !subjectIsLiteral(c.DeliverSubject) || !IsValidSubject(c.DeliverSubject) {
 1912					return StreamConfig{}, NewJSMirrorDurableConsumerCfgInvalidError()
 1913				}
 1914				if cfg.Mirror.OptStartSeq != 0 || cfg.Mirror.OptStartTime != nil {
 1915					return StreamConfig{}, NewJSMirrorDurableConsumerCfgInvalidError()
 1916				}
 1917				if cfg.Mirror.FilterSubject != _EMPTY_ {
 1918					return StreamConfig{}, NewJSMirrorDurableConsumerCfgInvalidError()
 1919				}
 1920			}
 1921			if cfg.Mirror.FilterSubject != _EMPTY_ && len(cfg.Mirror.SubjectTransforms) != 0 {
 1922				return StreamConfig{}, NewJSMirrorMultipleFiltersNotAllowedError()
 1923			}
 1924			if cfg.SubjectDeleteMarkerTTL > 0 {
 1925				// Delete markers cannot be configured on a mirror as it would result in new
 1926				// tombstones which would use up sequence numbers, diverging from the origin
 1927				// stream.
 1928				return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("subject delete markers forbidden on mirrors"))
 1929			}
 1930			// Check subject filters overlap.
 1931			for outer, tr := range cfg.Mirror.SubjectTransforms {
 1932				if tr.Source != _EMPTY_ && !IsValidSubject(tr.Source) {
 1933					return StreamConfig{}, NewJSMirrorInvalidSubjectFilterError(fmt.Errorf("%w %s", ErrBadSubject, tr.Source))
 1934				}
 1935	
 1936				err := ValidateMapping(tr.Source, tr.Destination)
 1937				if err != nil {
 1938					return StreamConfig{}, NewJSMirrorInvalidTransformDestinationError(err)
 1939				}
 1940	
 1941				for inner, innertr := range cfg.Mirror.SubjectTransforms {
 1942					if inner != outer && SubjectsCollide(tr.Source, innertr.Source) {
 1943						return StreamConfig{}, NewJSMirrorOverlappingSubjectFiltersError()
 1944					}
 1945				}
 1946			}
 1947			// Do not perform checks if External is provided, as it could lead to
 1948			// checking against itself (if sourced stream name is the same on different JetStream)
 1949			if cfg.Mirror.External == nil {
 1950				if !isValidAssetName(cfg.Mirror.Name) {
 1951					return StreamConfig{}, NewJSMirrorInvalidStreamNameError()
 1952				}
 1953				// We do not require other stream to exist anymore, but if we can see it check payloads.
 1954				exists, maxMsgSize, subs := hasStream(cfg.Mirror.Name)
 1955				if len(subs) > 0 {
 1956					streamSubs = append(streamSubs, subs...)
 1957				}
 1958				if exists {
 1959					if cfg.MaxMsgSize > 0 && maxMsgSize > 0 && cfg.MaxMsgSize < maxMsgSize {
 1960						return StreamConfig{}, NewJSMirrorMaxMessageSizeTooBigError()
 1961					}
 1962				}
 1963				// Determine if we are inheriting direct gets.
 1964				if exists, ocfg := getStream(cfg.Mirror.Name); exists {
 1965					if pedantic && cfg.MirrorDirect != ocfg.AllowDirect {
 1966						return StreamConfig{}, NewJSPedanticError(fmt.Errorf("origin stream has direct get set, mirror has it disabled"))
 1967					}
 1968					cfg.MirrorDirect = ocfg.AllowDirect
 1969				} else if js := s.getJetStream(); js != nil && js.isClustered() {
 1970					// Could not find it here. If we are clustered we can look it up.
 1971					js.mu.RLock()
 1972					if cc := js.cluster; cc != nil {
 1973						if as := cc.streams[acc.Name]; as != nil {
 1974							if sa := as[cfg.Mirror.Name]; sa != nil {
 1975								if pedantic && cfg.MirrorDirect != sa.Config.AllowDirect {
 1976									js.mu.RUnlock()
 1977									return StreamConfig{}, NewJSPedanticError(fmt.Errorf("origin stream has direct get set, mirror has it disabled"))
 1978								}
 1979								cfg.MirrorDirect = sa.Config.AllowDirect
 1980							}
 1981						}
 1982					}
 1983					js.mu.RUnlock()
 1984				}
 1985			} else {
 1986				if cfg.Mirror.External.DeliverPrefix != _EMPTY_ {
 1987					deliveryPrefixes = append(deliveryPrefixes, cfg.Mirror.External.DeliverPrefix)
 1988				}
 1989	
 1990				if cfg.Mirror.External.ApiPrefix != _EMPTY_ {
 1991					apiPrefixes = append(apiPrefixes, cfg.Mirror.External.ApiPrefix)
 1992				}
 1993			}
 1994		}
 1995	
 1996		if len(cfg.Sources) > 0 {
 1997			if cfg.AllowMsgSchedules {
 1998				return StreamConfig{}, NewJSSourceWithMsgSchedulesError()
 1999			}
 2000		}
 2001	
 2002		// check sources for duplicates
 2003		var iNames = make(map[string]struct{})
 2004		var cNames = make(map[string]struct{})
 2005		for _, src := range cfg.Sources {
 2006			if src == nil || !isValidAssetName(src.Name) {
 2007				return StreamConfig{}, NewJSSourceInvalidStreamNameError()
 2008			}
 2009			if _, ok := iNames[src.composeIName()]; !ok {
 2010				iNames[src.composeIName()] = struct{}{}
 2011			} else {
 2012				return StreamConfig{}, NewJSSourceDuplicateDetectedError()
 2013			}
 2014	
 2015			if src.FilterSubject != _EMPTY_ && len(src.SubjectTransforms) != 0 {
 2016				return StreamConfig{}, NewJSSourceMultipleFiltersNotAllowedError()
 2017			}
 2018	
 2019			for _, tr := range src.SubjectTransforms {
 2020				if tr.Source != _EMPTY_ && !IsValidSubject(tr.Source) {
 2021					return StreamConfig{}, NewJSSourceInvalidSubjectFilterError(fmt.Errorf("%w %s", ErrBadSubject, tr.Source))
 2022				}
 2023				err := ValidateMapping(tr.Source, tr.Destination)
 2024				if err != nil {
 2025					return StreamConfig{}, NewJSSourceInvalidTransformDestinationError(err)
 2026				}
 2027			}
 2028	
 2029			// Check subject filters overlap.
 2030			for outer, tr := range src.SubjectTransforms {
 2031				for inner, innertr := range src.SubjectTransforms {
 2032					if inner != outer && subjectIsSubsetMatch(tr.Source, innertr.Source) {
 2033						return StreamConfig{}, NewJSSourceOverlappingSubjectFiltersError()
 2034					}
 2035				}
 2036			}
 2037	
 2038			if c := src.Consumer; c != nil {
 2039				if !isValidAssetName(c.Name) {
 2040					return StreamConfig{}, NewJSSourceDurableConsumerCfgInvalidError()
 2041				}
 2042				if !subjectIsLiteral(c.DeliverSubject) || !IsValidSubject(c.DeliverSubject) {
 2043					return StreamConfig{}, NewJSSourceDurableConsumerCfgInvalidError()
 2044				}
 2045				if src.OptStartSeq != 0 || src.OptStartTime != nil {
 2046					return StreamConfig{}, NewJSSourceDurableConsumerCfgInvalidError()
 2047				}
 2048				if src.FilterSubject != _EMPTY_ {
 2049					return StreamConfig{}, NewJSSourceDurableConsumerCfgInvalidError()
 2050				}
 2051				// Reusing the same consumer for multiple sources of the same stream isn't allowed.
 2052				if _, ok := cNames[src.composeCName()]; !ok {
 2053					cNames[src.composeCName()] = struct{}{}
 2054				} else {
 2055					return StreamConfig{}, NewJSSourceDurableConsumerDuplicateDetectedError()
 2056				}
 2057			}
 2058	
 2059			// Do not perform checks if External is provided, as it could lead to
 2060			// checking against itself (if sourced stream name is the same on different JetStream)
 2061			if src.External == nil {
 2062				exists, maxMsgSize, subs := hasStream(src.Name)
 2063				if len(subs) > 0 {
 2064					streamSubs = append(streamSubs, subs...)
 2065				}
 2066				if exists {
 2067					if cfg.MaxMsgSize > 0 && maxMsgSize > 0 && cfg.MaxMsgSize < maxMsgSize {
 2068						return StreamConfig{}, NewJSSourceMaxMessageSizeTooBigError()
 2069					}
 2070				}
 2071				continue
 2072			} else {
 2073				if src.External.DeliverPrefix != _EMPTY_ {
 2074					deliveryPrefixes = append(deliveryPrefixes, src.External.DeliverPrefix)
 2075				}
 2076				if src.External.ApiPrefix != _EMPTY_ {
 2077					apiPrefixes = append(apiPrefixes, src.External.ApiPrefix)
 2078				}
 2079			}
 2080		}
 2081	
 2082		// check prefix overlap with subjects
 2083		for _, pfx := range deliveryPrefixes {
 2084			if !IsValidPublishSubject(pfx) {
 2085				return StreamConfig{}, NewJSStreamInvalidExternalDeliverySubjError(pfx)
 2086			}
 2087			for _, sub := range streamSubs {
 2088				if SubjectsCollide(sub, fmt.Sprintf("%s.%s", pfx, sub)) {
 2089					return StreamConfig{}, NewJSStreamExternalDelPrefixOverlapsError(pfx, sub)
 2090				}
 2091			}
 2092		}
 2093		// check if api prefixes overlap
 2094		for _, apiPfx := range apiPrefixes {
 2095			if !IsValidPublishSubject(apiPfx) {
 2096				return StreamConfig{}, NewJSStreamInvalidConfigError(
 2097					fmt.Errorf("stream external api prefix %q must be a valid subject without wildcards", apiPfx))
 2098			}
 2099			if SubjectsCollide(apiPfx, JSApiPrefix) {
 2100				return StreamConfig{}, NewJSStreamExternalApiOverlapError(apiPfx, JSApiPrefix)
 2101			}
 2102		}
 2103	
 2104		// cycle check for source cycle
 2105		toVisit := []*StreamConfig{&cfg}
 2106		visited := make(map[string]struct{})
 2107		overlaps := func(subjects []string, filter string) bool {
 2108			if filter == _EMPTY_ {
 2109				return true
 2110			}
 2111			for _, subject := range subjects {
 2112				if SubjectsCollide(subject, filter) {
 2113					return true
 2114				}
 2115			}
 2116			return false
 2117		}
 2118	
 2119		for len(toVisit) > 0 {
 2120			cfg := toVisit[0]
 2121			toVisit = toVisit[1:]
 2122			visited[cfg.Name] = struct{}{}
 2123			for _, src := range cfg.Sources {
 2124				if src.External != nil {
 2125					continue
 2126				}
 2127				// We can detect a cycle between streams, but let's double check that the
 2128				// subjects actually form a cycle.
 2129				if _, ok := visited[src.Name]; ok {
 2130					if overlaps(cfg.Subjects, src.FilterSubject) {
 2131						return StreamConfig{}, NewJSStreamInvalidConfigError(errors.New("detected cycle"))
 2132					}
 2133				} else if exists, cfg := getStream(src.Name); exists {
 2134					toVisit = append(toVisit, &cfg)
 2135				}
 2136			}
 2137			// Avoid cycles hiding behind mirrors
 2138			if m := cfg.Mirror; m != nil {
 2139				if m.External == nil {
 2140					if _, ok := visited[m.Name]; ok {
 2141						return StreamConfig{}, NewJSStreamInvalidConfigError(errors.New("detected cycle"))
 2142					}
 2143					if exists, cfg := getStream(m.Name); exists {
 2144						toVisit = append(toVisit, &cfg)
 2145					}
 2146				}
 2147			}
 2148		}
 2149	
 2150		if len(cfg.Subjects) == 0 {
 2151			if cfg.Mirror == nil && len(cfg.Sources) == 0 {
 2152				cfg.Subjects = append(cfg.Subjects, cfg.Name)
 2153			}
 2154		} else {
 2155			if cfg.Mirror != nil {
 2156				return StreamConfig{}, NewJSMirrorWithSubjectsError()
 2157			}
 2158	
 2159			// Check for literal duplication of subject interest in config
 2160			// and no overlap with any JS or SYS API subject space.
 2161			dset := make(map[string]struct{}, len(cfg.Subjects))
 2162			for i, subj := range cfg.Subjects {
 2163				// Make sure the subject is valid. Check this first.
 2164				if !IsValidSubject(subj) {
 2165					return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("invalid subject"))
 2166				}
 2167				if _, ok := dset[subj]; ok {
 2168					return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("duplicate subjects detected"))
 2169				}
 2170				// Check for trying to capture everything.
 2171				if subj == fwcs {
 2172					if !cfg.NoAck {
 2173						return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("capturing all subjects requires no-ack to be true"))
 2174					}
 2175					// Capturing everything also will require R1.
 2176					if cfg.Replicas != 1 {
 2177						return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("capturing all subjects requires replicas of 1"))
 2178					}
 2179				}
 2180				// Also check to make sure we do not overlap with our $JS API subjects.
 2181				if !cfg.NoAck {
 2182					for _, namespace := range []string{"$JS.>", "$JSC.>", "$NRG.>"} {
 2183						if SubjectsCollide(subj, namespace) {
 2184							// We allow an exception for $JS.EVENT.> since these could have been created in the past.
 2185							if !subjectIsSubsetMatch(subj, "$JS.EVENT.>") {
 2186								return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("subjects that overlap with jetstream api require no-ack to be true"))
 2187							}
 2188						}
 2189					}
 2190					if SubjectsCollide(subj, "$SYS.>") {
 2191						if !subjectIsSubsetMatch(subj, "$SYS.ACCOUNT.>") {
 2192							return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("subjects that overlap with system api require no-ack to be true"))
 2193						}
 2194					}
 2195				}
 2196				// Now check if we have multiple subjects that we do not overlap ourselves
 2197				// which would cause duplicate entries (assuming no MsgID).
 2198				for _, tsubj := range cfg.Subjects[i+1:] {
 2199					if SubjectsCollide(tsubj, subj) {
 2200						return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("subject %q overlaps with %q", subj, tsubj))
 2201					}
 2202				}
 2203				// Mark for duplicate check.
 2204				dset[subj] = struct{}{}
 2205			}
 2206		}
 2207	
 2208		if len(cfg.Subjects) == 0 && len(cfg.Sources) == 0 && cfg.Mirror == nil {
 2209			return StreamConfig{}, NewJSStreamInvalidConfigError(
 2210				fmt.Errorf("stream needs at least one configured subject or be a source/mirror"))
 2211		}
 2212	
 2213		// Check for MaxBytes required and it's limit
 2214		if required, limit := acc.maxBytesLimits(&cfg); required && cfg.MaxBytes <= 0 {
 2215			return StreamConfig{}, NewJSStreamMaxBytesRequiredError()
 2216		} else if limit > 0 && cfg.MaxBytes > limit {
 2217			return StreamConfig{}, NewJSStreamMaxStreamBytesExceededError()
 2218		}
 2219	
 2220		// Check the subject transform if any
 2221		if cfg.SubjectTransform != nil {
 2222			if cfg.SubjectTransform.Source != _EMPTY_ && !IsValidSubject(cfg.SubjectTransform.Source) {
 2223				return StreamConfig{}, NewJSStreamTransformInvalidSourceError(fmt.Errorf("%w %s", ErrBadSubject, cfg.SubjectTransform.Source))
 2224			}
 2225	
 2226			err := ValidateMapping(cfg.SubjectTransform.Source, cfg.SubjectTransform.Destination)
 2227			if err != nil {
 2228				return StreamConfig{}, NewJSStreamTransformInvalidDestinationError(err)
 2229			}
 2230		}
 2231	
 2232		// If we have a republish directive check if we can create a transform here.
 2233		if cfg.RePublish != nil {
 2234			// Check to make sure source is a valid subset of the subjects we have.
 2235			// Also make sure it does not form a cycle.
 2236			// Empty same as all.
 2237			if cfg.RePublish.Source == _EMPTY_ {
 2238				if pedantic {
 2239					return StreamConfig{}, NewJSPedanticError(fmt.Errorf("republish source can not be empty"))
 2240				}
 2241				cfg.RePublish.Source = fwcs
 2242			}
 2243			// A RePublish from '>' to '>' could be used, normally this would form a cycle with the stream subjects.
 2244			// But if this aligns to a different subject based on the transform, we allow it still.
 2245			// The RePublish will be implicit based on the transform, but only if the transform's source
 2246			// is the only stream subject.
 2247			if cfg.RePublish.Destination == fwcs && cfg.RePublish.Source == fwcs && cfg.SubjectTransform != nil &&
 2248				len(cfg.Subjects) == 1 && cfg.SubjectTransform.Source == cfg.Subjects[0] {
 2249				if pedantic {
 2250					return StreamConfig{}, NewJSPedanticError(fmt.Errorf("implicit republish based on subject transform"))
 2251				}
 2252				// RePublish all messages with the transformed subject.
 2253				cfg.RePublish.Source, cfg.RePublish.Destination = cfg.SubjectTransform.Destination, cfg.SubjectTransform.Destination
 2254			}
 2255			var formsCycle bool
 2256			for _, subj := range cfg.Subjects {
 2257				if SubjectsCollide(cfg.RePublish.Destination, subj) {
 2258					formsCycle = true
 2259					break
 2260				}
 2261			}
 2262			if formsCycle {
 2263				return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("stream configuration for republish destination forms a cycle"))
 2264			}
 2265			if _, err := NewSubjectTransform(cfg.RePublish.Source, cfg.RePublish.Destination); err != nil {
 2266				return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("stream configuration for republish with transform from '%s' to '%s' not valid", cfg.RePublish.Source, cfg.RePublish.Destination))
 2267			}
 2268		}
 2269	
 2270		// Remove placement if it's an empty object.
 2271		if cfg.Placement != nil && reflect.DeepEqual(cfg.Placement, &Placement{}) {
 2272			cfg.Placement = nil
 2273		}
 2274		// For now don't allow preferred server in placement.
 2275		if cfg.Placement != nil && cfg.Placement.Preferred != _EMPTY_ {
 2276			return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("preferred server not permitted in placement"))
 2277		}
 2278	
 2279		return cfg, nil
 2280	}
```

## stream.go — `configUpdateCheck` — what an update may and may not change

The refusals: name, storage, retention to/from `workqueue`, unseal, cancelling `deny_delete` / `deny_purge`, a changed `mirror` (removing it is allowed — promotion), `discard_new_per_subject` without its preconditions, disabling `allow_msg_ttl`, changing `allow_msg_counter`, disabling `allow_msg_schedules`, changing `persist_mode`; the adjustments sealing forces; the `max_bytes` reservation arithmetic.

```go
 2300	func (jsa *jsAccount) configUpdateCheck(old, new *StreamConfig, s *Server, pedantic bool) (*StreamConfig, error) {
 2301		cfg, apiErr := s.checkStreamCfg(new, jsa.acc(), pedantic)
 2302		if apiErr != nil {
 2303			return nil, apiErr
 2304		}
 2305	
 2306		// Name must match.
 2307		if cfg.Name != old.Name {
 2308			return nil, NewJSStreamInvalidConfigError(fmt.Errorf("stream configuration name must match original"))
 2309		}
 2310		singleServerMode := !s.JetStreamIsClustered() && s.standAloneMode()
 2311		if singleServerMode && cfg.Replicas > 1 {
 2312			return nil, ApiErrors[JSStreamReplicasNotSupportedErr]
 2313		}
 2314		// Can't change storage types.
 2315		if cfg.Storage != old.Storage {
 2316			return nil, NewJSStreamInvalidConfigError(fmt.Errorf("stream configuration update can not change storage type"))
 2317		}
 2318		// Can only change retention from limits to interest or back, not to/from work queue for now.
 2319		if cfg.Retention != old.Retention {
 2320			if old.Retention == WorkQueuePolicy || cfg.Retention == WorkQueuePolicy {
 2321				return nil, NewJSStreamInvalidConfigError(fmt.Errorf("stream configuration update can not change retention policy to/from workqueue"))
 2322			}
 2323		}
 2324		// Can not change from true to false.
 2325		if !cfg.Sealed && old.Sealed {
 2326			return nil, NewJSStreamInvalidConfigError(fmt.Errorf("stream configuration update can not unseal a sealed stream"))
 2327		}
 2328		// Can not change from true to false.
 2329		if !cfg.DenyDelete && old.DenyDelete {
 2330			return nil, NewJSStreamInvalidConfigError(fmt.Errorf("stream configuration update can not cancel deny message deletes"))
 2331		}
 2332		// Can not change from true to false.
 2333		if !cfg.DenyPurge && old.DenyPurge {
 2334			return nil, NewJSStreamInvalidConfigError(fmt.Errorf("stream configuration update can not cancel deny purge"))
 2335		}
 2336		// Check for mirror changes which are not allowed.
 2337		// We will allow removing the mirror config to "promote" the mirror to a normal stream.
 2338		if cfg.Mirror != nil && !reflect.DeepEqual(cfg.Mirror, old.Mirror) {
 2339			return nil, NewJSStreamMirrorNotUpdatableError()
 2340		}
 2341	
 2342		// Check on new discard new per subject.
 2343		if cfg.DiscardNewPer {
 2344			if cfg.Discard != DiscardNew {
 2345				return nil, NewJSStreamInvalidConfigError(fmt.Errorf("discard new per subject requires discard new policy to be set"))
 2346			}
 2347			if cfg.MaxMsgsPer <= 0 {
 2348				return nil, NewJSStreamInvalidConfigError(fmt.Errorf("discard new per subject requires max msgs per subject > 0"))
 2349			}
 2350		}
 2351	
 2352		// Check on the allowed message TTL status.
 2353		if old.AllowMsgTTL && !cfg.AllowMsgTTL {
 2354			return nil, NewJSStreamInvalidConfigError(fmt.Errorf("message TTL status can not be disabled"))
 2355		}
 2356	
 2357		// Can't change counter setting.
 2358		if cfg.AllowMsgCounter != old.AllowMsgCounter {
 2359			return nil, NewJSStreamInvalidConfigError(fmt.Errorf("stream configuration update can not change message counter setting"))
 2360		}
 2361	
 2362		// Can't disable message schedules setting.
 2363		if old.AllowMsgSchedules && !cfg.AllowMsgSchedules {
 2364			return nil, NewJSStreamInvalidConfigError(fmt.Errorf("message schedules can not be disabled"))
 2365		}
 2366	
 2367		if old.PersistMode != cfg.PersistMode {
 2368			return nil, NewJSStreamInvalidConfigError(fmt.Errorf("stream configuration update can not change persist mode"))
 2369		}
 2370	
 2371		// Do some adjustments for being sealed.
 2372		// Pedantic mode will allow those changes to be made, as they are deterministic and important to get a sealed stream.
 2373		if cfg.Sealed {
 2374			cfg.MaxAge = 0
 2375			cfg.Discard = DiscardNew
 2376			cfg.DenyDelete, cfg.DenyPurge = true, true
 2377			cfg.AllowRollup = false
 2378		}
 2379	
 2380		// Check limits. We need some extra handling to allow updating MaxBytes.
 2381	
 2382		// First, let's calculate the difference between the new and old MaxBytes.
 2383		maxBytesDiff := max(cfg.MaxBytes, 0) - max(old.MaxBytes, 0)
 2384		if maxBytesDiff < 0 {
 2385			// If we're updating to a lower MaxBytes (maxBytesDiff is negative),
 2386			// then set to zero so checkBytesLimits doesn't set addBytes to 1.
 2387			maxBytesDiff = 0
 2388		}
 2389		// If maxBytesDiff == 0, then that means MaxBytes didn't change.
 2390		// If maxBytesDiff > 0, then we want to reserve additional bytes.
 2391	
 2392		// Save the user configured MaxBytes.
 2393		newMaxBytes := cfg.MaxBytes
 2394	
 2395		// We temporarily set cfg.MaxBytes to maxBytesDiff because checkAllLimits
 2396		// adds cfg.MaxBytes to the current reserved limit and checks if we've gone
 2397		// over. However, we don't want an additional cfg.MaxBytes, we only want to
 2398		// reserve the difference between the new and the old values.
 2399		cfg.MaxBytes = maxBytesDiff
 2400	
 2401		// Check limits.
 2402		js, isClustered := jsa.jetStreamAndClustered()
 2403		jsa.mu.RLock()
 2404		acc := jsa.account
 2405		jsa.usageMu.RLock()
 2406		selected, tier, hasTier := jsa.selectLimits(cfg.Replicas)
 2407		if !hasTier && old.Replicas != cfg.Replicas {
 2408			selected, tier, hasTier = jsa.selectLimits(old.Replicas)
 2409		}
 2410		jsa.usageMu.RUnlock()
 2411		reserved := int64(0)
 2412		if !isClustered {
 2413			reserved = jsa.tieredReservation(tier, &cfg)
 2414		}
 2415		jsa.mu.RUnlock()
 2416		if !hasTier {
 2417			return nil, NewJSNoLimitsError()
 2418		}
 2419		js.mu.RLock()
 2420		defer js.mu.RUnlock()
 2421		if isClustered {
 2422			_, reserved = js.tieredStreamAndReservationCount(acc.Name, tier, &cfg)
 2423		}
 2424		// reserved covers only the other streams. checkAllLimits adds this stream's
 2425		// footprint via cfg.MaxBytes, which is currently maxBytesDiff, so it only
 2426		// adds the diff. Add the remaining (newMaxBytes - maxBytesDiff) here so the
 2427		// two together equal this stream's true new footprint, even when Replicas
 2428		// changes on update.
 2429		reserved = addSaturate(reserved, accountReservation(tier, cfg.Replicas, newMaxBytes-maxBytesDiff))
 2430		if err := js.checkAllLimits(&selected, tier, &cfg, reserved, 0); err != nil {
 2431			return nil, err
 2432		}
 2433		// Restore the user configured MaxBytes.
 2434		cfg.MaxBytes = newMaxBytes
 2435		return &cfg, nil
 2436	}
 2437	
```

## stream.go — `update`, `updatePedantic`, `updateWithAdvisory` — the consumer-limit re-check on update

```go
 2438	// Update will allow certain configuration properties of an existing stream to be updated.
 2439	func (mset *stream) update(config *StreamConfig) error {
 2440		return mset.updateWithAdvisory(config, true, false)
 2441	}
 2442	
 2443	func (mset *stream) updatePedantic(config *StreamConfig, pedantic bool) error {
 2444		return mset.updateWithAdvisory(config, true, pedantic)
 2445	}
 2446	
 2447	// Update will allow certain configuration properties of an existing stream to be updated.
 2448	func (mset *stream) updateWithAdvisory(config *StreamConfig, sendAdvisory bool, pedantic bool) error {
 2449		_, jsa, err := mset.acc.checkForJetStream()
 2450		if err != nil {
 2451			return err
 2452		}
 2453	
 2454		mset.mu.RLock()
 2455		ocfg := mset.cfg
 2456		s := mset.srv
 2457		mset.mu.RUnlock()
 2458	
 2459		cfg, err := mset.jsa.configUpdateCheck(&ocfg, config, s, pedantic)
 2460		if err != nil {
 2461			return NewJSStreamInvalidConfigError(err, Unless(err))
 2462		}
 2463	
 2464		// In the event that some of the stream-level limits have changed, yell appropriately
 2465		// if any of the consumers exceed that limit.
 2466		oldInactiveThreshold, newInactiveThreshold := ocfg.ConsumerLimits.InactiveThreshold, cfg.ConsumerLimits.InactiveThreshold
 2467		oldMaxAckPending, newMaxAckPending := ocfg.ConsumerLimits.MaxAckPending, cfg.ConsumerLimits.MaxAckPending
 2468		updateLimits := (newInactiveThreshold > 0 && oldInactiveThreshold != newInactiveThreshold) ||
 2469			(newMaxAckPending > 0 && oldMaxAckPending != newMaxAckPending)
 2470	
 2471		// Only check if not clustered. The meta leader performs clustered checks.
 2472		if updateLimits && !mset.js.isClustered() {
 2473			var errorConsumers []string
 2474			mset.mu.RLock()
 2475			clist := make([]*consumer, 0, len(mset.consumers))
```

## stream.go — where a message's timestamp is taken — the leader's clock, before the proposal (row 140)

`processJetStreamMsg` receives `ts`; when it is zero (a direct publish, not a replay) the leader stamps `time.Now().UnixNano()` here and the value travels in the Raft proposal, so every replica stores the same timestamp.

```go
 6926		}
 6927	
 6928		// Grab timestamp if not already set.
 6929		if ts == 0 && lseq > 0 {
 6930			ts = time.Now().UnixNano()
 6931		}
 6932	
```

## stream.go — the same for an atomic batch

```go
 7484	
 7485		// Proceed with proposing the batch.
 7486		ts := time.Now().UnixNano()
 7487	
 7488		// Need to hold this lock even if we're not clustered, because we'll
```

## consumer.go — `ConsumerConfig`

35 JSON fields; the jsm.go schema has 34 — `sourcing` is internal.

```go
   88	type ConsumerConfig struct {
   89		Durable         string          `json:"durable_name,omitempty"`
   90		Name            string          `json:"name,omitempty"`
   91		Description     string          `json:"description,omitempty"`
   92		DeliverPolicy   DeliverPolicy   `json:"deliver_policy"`
   93		OptStartSeq     uint64          `json:"opt_start_seq,omitempty"`
   94		OptStartTime    *time.Time      `json:"opt_start_time,omitempty"`
   95		AckPolicy       AckPolicy       `json:"ack_policy"`
   96		AckWait         time.Duration   `json:"ack_wait,omitempty"`
   97		MaxDeliver      int             `json:"max_deliver,omitempty"`
   98		BackOff         []time.Duration `json:"backoff,omitempty"`
   99		FilterSubject   string          `json:"filter_subject,omitempty"`
  100		FilterSubjects  []string        `json:"filter_subjects,omitempty"`
  101		ReplayPolicy    ReplayPolicy    `json:"replay_policy"`
  102		RateLimit       uint64          `json:"rate_limit_bps,omitempty"` // Bits per sec
  103		SampleFrequency string          `json:"sample_freq,omitempty"`
  104		MaxWaiting      int             `json:"max_waiting,omitempty"`
  105		MaxAckPending   int             `json:"max_ack_pending,omitempty"`
  106		FlowControl     bool            `json:"flow_control,omitempty"`
  107		HeadersOnly     bool            `json:"headers_only,omitempty"`
  108	
  109		// Pull based options.
  110		MaxRequestBatch    int           `json:"max_batch,omitempty"`
  111		MaxRequestExpires  time.Duration `json:"max_expires,omitempty"`
  112		MaxRequestMaxBytes int           `json:"max_bytes,omitempty"`
  113	
  114		// Push based consumers.
  115		DeliverSubject string        `json:"deliver_subject,omitempty"`
  116		DeliverGroup   string        `json:"deliver_group,omitempty"`
  117		Heartbeat      time.Duration `json:"idle_heartbeat,omitempty"`
  118	
  119		// Ephemeral inactivity threshold.
  120		InactiveThreshold time.Duration `json:"inactive_threshold,omitempty"`
  121	
  122		// Generally inherited by parent stream and other markers, now can be configured directly.
  123		Replicas int `json:"num_replicas"`
  124		// Force memory storage.
  125		MemoryStorage bool `json:"mem_storage,omitempty"`
  126	
  127		// Don't add to general clients.
  128		Direct   bool `json:"direct,omitempty"`
  129		Sourcing bool `json:"sourcing,omitempty"`
  130	
  131		// Metadata is additional metadata for the Consumer.
  132		Metadata map[string]string `json:"metadata,omitempty"`
  133	
  134		// PauseUntil is for suspending the consumer until the deadline.
  135		PauseUntil *time.Time `json:"pause_until,omitempty"`
  136	
  137		// Priority groups
  138		PriorityGroups []string       `json:"priority_groups,omitempty"`
  139		PriorityPolicy PriorityPolicy `json:"priority_policy,omitempty"`
  140		PinnedTTL      time.Duration  `json:"priority_timeout,omitempty"`
  141	}
```

## consumer.go — the priority, deliver, ack and replay policy enumerations

```go
  224	const (
  225		// No priority policy.
  226		PriorityNone PriorityPolicy = iota
  227		// Clients will get the messages only if certain criteria are specified.
  228		PriorityOverflow
  229		// Single client takes over handling of the messages, while others are on standby.
  230		PriorityPinnedClient
  231		// Clients with lowest priority will be selected first.
  232		PriorityPrioritized
  233	)
  234	
  235	const (
  236		PriorityNoneJSONString         = `"none"`
  237		PriorityOverflowJSONString     = `"overflow"`
  238		PriorityPinnedClientJSONString = `"pinned_client"`
  239		PriorityPrioritizedJSONString  = `"prioritized"`
  240	)
  241	
  242	var (
  243		PriorityNoneJSONBytes         = []byte(PriorityNoneJSONString)
  244		PriorityOverflowJSONBytes     = []byte(PriorityOverflowJSONString)
  245		PriorityPinnedClientJSONBytes = []byte(PriorityPinnedClientJSONString)
  246		PriorityPrioritizedJSONBytes  = []byte(PriorityPrioritizedJSONString)
```

## consumer.go — `DeliverPolicy`, `AckPolicy`, `ReplayPolicy` values

```go
  296	const (
  297		// DeliverAll will be the default so can be omitted from the request.
  298		DeliverAll DeliverPolicy = iota
  299		// DeliverLast will start the consumer with the last sequence received.
  300		DeliverLast
  301		// DeliverNew will only deliver new messages that are sent after the consumer is created.
  302		DeliverNew
  303		// DeliverByStartSequence will look for a defined starting sequence to start.
  304		DeliverByStartSequence
  305		// DeliverByStartTime will select the first messsage with a timestamp >= to StartTime.
  306		DeliverByStartTime
  307		// DeliverLastPerSubject will start the consumer with the last message for all subjects received.
  308		DeliverLastPerSubject
  309	)
  310	
  311	func (dp DeliverPolicy) String() string {
  312		switch dp {
  313		case DeliverAll:
  314			return "all"
  315		case DeliverLast:
  316			return "last"
  317		case DeliverNew:
  318			return "new"
  319		case DeliverByStartSequence:
  320			return "by_start_sequence"
  321		case DeliverByStartTime:
  322			return "by_start_time"
  323		case DeliverLastPerSubject:
  324			return "last_per_subject"
  325		default:
  326			return "undefined"
  327		}
  328	}
  329	
  330	// AckPolicy determines how the consumer should acknowledge delivered messages.
  331	type AckPolicy int
  332	
  333	const (
  334		// AckNone requires no acks for delivered messages.
  335		AckNone AckPolicy = iota
  336		// AckAll when acking a sequence number, this implicitly acks all sequences below this one as well.
  337		AckAll
  338		// AckExplicit requires ack or nack for all messages.
  339		AckExplicit
  340		// AckFlowControl functions like AckAll, but acks based on responses to flow control.
  341		AckFlowControl
  342	)
  343	
  344	func (a AckPolicy) String() string {
  345		switch a {
  346		case AckNone:
  347			return "none"
  348		case AckAll:
  349			return "all"
  350		case AckFlowControl:
  351			return "flow_control"
  352		default:
  353			return "explicit"
  354		}
  355	}
  356	
  357	// ReplayPolicy determines how the consumer should replay messages it already has queued in the stream.
  358	type ReplayPolicy int
  359	
  360	const (
  361		// ReplayInstant will replay messages as fast as possible.
  362		ReplayInstant ReplayPolicy = iota
  363		// ReplayOriginal will maintain the same timing as the messages were received.
  364		ReplayOriginal
  365	)
  366	
```

## consumer.go — the consumer default constants

```go
  570	
  571	const (
  572		// JsAckWaitDefault is the default AckWait, only applicable on explicit ack policy consumers.
  573		JsAckWaitDefault = 30 * time.Second
  574		// JsDeleteWaitTimeDefault is the default amount of time we will wait for non-durable
  575		// consumers to be in an inactive state before deleting them.
  576		JsDeleteWaitTimeDefault = 5 * time.Second
  577		// JsFlowControlMaxPending specifies default pending bytes during flow control that can be outstanding.
  578		JsFlowControlMaxPending = 32 * 1024 * 1024
  579		// JsDefaultMaxAckPending is set for consumers with explicit ack that do not set the max ack pending.
  580		JsDefaultMaxAckPending = 1000
  581		// JsDefaultPinnedTTL is the default grace period for the pinned consumer to send a new request before a new pin
  582		// is picked by a server.
  583		JsDefaultPinnedTTL = 2 * time.Minute
  584	)
  585	
  586	// Helper function to set consumer config defaults from above.
```

## consumer.go — `setConsumerConfigDefaults` — what the server fills in, in which order, and what pedantic mode refuses

`max_deliver` → -1; `max_waiting` → 512 (`JSWaitQueueDefaultMax`) for pull consumers; `ack_wait` → 30 s for `explicit` and `all`; a `backoff` overwrites `ack_wait` with its first entry; `max_ack_pending` → the stream's `consumer_limits`, else 1000 clamped by the server and account limits; `inactive_threshold` → the stream's limit; `max_batch` → the server limit; `priority_timeout` → 2 m for `pinned_client`.

```go
  587	func setConsumerConfigDefaults(config *ConsumerConfig, streamCfg *StreamConfig, lim *JSLimitOpts, accLim *JetStreamAccountLimits, pedantic bool) *ApiError {
  588		// Setup default of -1, meaning no limit for MaxDeliver.
  589		if config.MaxDeliver == 0 || config.MaxDeliver < -1 {
  590			if pedantic && config.MaxDeliver < -1 {
  591				return NewJSPedanticError(errors.New("max_deliver must be set to -1"))
  592			}
  593			config.MaxDeliver = -1
  594		}
  595		// Setup zero defaults.
  596		if config.MaxWaiting < 0 {
  597			if pedantic {
  598				return NewJSPedanticError(errors.New("max_waiting must not be negative"))
  599			}
  600			config.MaxWaiting = 0
  601		}
  602		if config.MaxAckPending < -1 {
  603			if pedantic {
  604				return NewJSPedanticError(errors.New("max_ack_pending must be set to -1"))
  605			}
  606			config.MaxAckPending = -1
  607		}
  608		if config.MaxRequestBatch < 0 {
  609			if pedantic {
  610				return NewJSPedanticError(errors.New("max_batch must not be negative"))
  611			}
  612			config.MaxRequestBatch = 0
  613		}
  614		if config.MaxRequestExpires < 0 {
  615			if pedantic {
  616				return NewJSPedanticError(errors.New("max_expires must not be negative"))
  617			}
  618			config.MaxRequestExpires = 0
  619		}
  620		if config.MaxRequestMaxBytes < 0 {
  621			if pedantic {
  622				return NewJSPedanticError(errors.New("max_bytes must not be negative"))
  623			}
  624			config.MaxRequestMaxBytes = 0
  625		}
  626		if config.Heartbeat < 0 {
  627			if pedantic {
  628				return NewJSPedanticError(errors.New("idle_heartbeat must not be negative"))
  629			}
  630			config.Heartbeat = 0
  631		}
  632		if config.InactiveThreshold < 0 {
  633			if pedantic {
  634				return NewJSPedanticError(errors.New("inactive_threshold must not be negative"))
  635			}
  636			config.InactiveThreshold = 0
  637		}
  638		if config.PinnedTTL < 0 {
  639			if pedantic {
  640				return NewJSPedanticError(errors.New("priority_timeout must not be negative"))
  641			}
  642			config.PinnedTTL = 0
  643		}
  644	
  645		// Set to default if not specified.
  646		if config.DeliverSubject == _EMPTY_ && config.MaxWaiting == 0 {
  647			config.MaxWaiting = JSWaitQueueDefaultMax
  648		}
  649		// Setup proper default for ack wait if we are in explicit ack mode.
  650		if config.AckWait == 0 && (config.AckPolicy == AckExplicit || config.AckPolicy == AckAll) {
  651			config.AckWait = JsAckWaitDefault
  652		}
  653		// If BackOff was specified that will override the AckWait and the MaxDeliver.
  654		if len(config.BackOff) > 0 {
  655			if pedantic && config.AckWait != config.BackOff[0] {
  656				return NewJSPedanticError(errors.New("first backoff value has to equal batch AckWait"))
  657			}
  658			config.AckWait = config.BackOff[0]
  659		}
  660		if config.MaxAckPending == 0 {
  661			if pedantic && streamCfg.ConsumerLimits.MaxAckPending > 0 {
  662				return NewJSPedanticError(errors.New("max_ack_pending must be set if it's configured in stream limits"))
  663			}
  664			config.MaxAckPending = streamCfg.ConsumerLimits.MaxAckPending
  665		}
  666		if config.InactiveThreshold == 0 {
  667			if pedantic && streamCfg.ConsumerLimits.InactiveThreshold > 0 {
  668				return NewJSPedanticError(errors.New("inactive_threshold must be set if it's configured in stream limits"))
  669			}
  670			config.InactiveThreshold = streamCfg.ConsumerLimits.InactiveThreshold
  671		}
  672		// Set proper default for max ack pending if we are ack explicit and none has been set.
  673		if config.MaxAckPending == 0 && config.AckPolicy != AckNone {
  674			ackPending := JsDefaultMaxAckPending
  675			if lim.MaxAckPending > 0 && lim.MaxAckPending < ackPending {
  676				ackPending = lim.MaxAckPending
  677			}
  678			if accLim.MaxAckPending > 0 && accLim.MaxAckPending < ackPending {
  679				ackPending = accLim.MaxAckPending
  680			}
  681			config.MaxAckPending = ackPending
  682		}
  683		// if applicable set max request batch size
  684		if config.DeliverSubject == _EMPTY_ && config.MaxRequestBatch == 0 && lim.MaxRequestBatch > 0 {
  685			if pedantic {
  686				return NewJSPedanticError(errors.New("max_request_batch must be set if it's JetStream limits are set"))
  687			}
  688			config.MaxRequestBatch = lim.MaxRequestBatch
  689		}
  690	
  691		// set the default value only if pinned policy is used.
  692		if config.PriorityPolicy == PriorityPinnedClient && config.PinnedTTL == 0 {
  693			config.PinnedTTL = JsDefaultPinnedTTL
  694		}
  695	
  696		// Set default values for flow control policy.
  697		if config.AckPolicy == AckFlowControl && !pedantic {
  698			config.FlowControl = true
  699			config.Heartbeat = sourceHealthHB
  700		}
  701		return nil
  702	}
  703	
  704	// Check the consumer config. If we are recovering don't check filter subjects.
```

## consumer.go — `checkConsumerCfg` — the validation rules

```go
  705	func checkConsumerCfg(
  706		config *ConsumerConfig,
  707		srvLim *JSLimitOpts,
  708		cfg *StreamConfig,
  709		_ *Account,
  710		accLim *JetStreamAccountLimits,
  711		isRecovering bool,
  712	) *ApiError {
  713	
  714		if config.Name != _EMPTY_ && !isValidAssetName(config.Name) {
  715			return NewJSStreamInvalidConfigError(errors.New("consumer name can not contain '.', '*', '>', '\\', '/'"))
  716		}
  717		if config.Durable != _EMPTY_ && !isValidAssetName(config.Durable) {
  718			return NewJSStreamInvalidConfigError(errors.New("consumer durable name can not contain '.', '*', '>', '\\', '/'"))
  719		}
  720	
  721		// Check if replicas is defined but exceeds parent stream.
  722		if config.Replicas > 0 && config.Replicas > cfg.Replicas {
  723			return NewJSConsumerReplicasExceedsStreamError()
  724		}
  725		// Check that it is not negative
  726		if config.Replicas < 0 {
  727			return NewJSReplicasCountCannotBeNegativeError()
  728		}
  729		// If the stream is interest or workqueue retention make sure the replicas
  730		// match that of the stream. This is REQUIRED for now.
  731		if cfg.Retention == InterestPolicy || cfg.Retention == WorkQueuePolicy {
  732			// Only error here if not recovering.
  733			// We handle recovering in a different spot to allow consumer to come up
  734			// if previous version allowed it to be created. We do not want it to not come up.
  735			if !isRecovering && config.Replicas != 0 && config.Replicas != cfg.Replicas {
  736				return NewJSConsumerReplicasShouldMatchStreamError()
  737			}
  738		}
  739	
  740		if _, err := config.AckPolicy.MarshalJSON(); err != nil {
  741			return NewJSConsumerAckPolicyInvalidError()
  742		}
  743		if _, err := config.ReplayPolicy.MarshalJSON(); err != nil {
  744			return NewJSConsumerReplayPolicyInvalidError()
  745		}
  746	
  747		// Check not negative AckWait/BackOff
  748		for _, backoff := range config.BackOff {
  749			if backoff < 0 {
  750				return NewJSConsumerBackOffNegativeError()
  751			}
  752		}
  753		if config.AckWait < 0 {
  754			return NewJSConsumerAckWaitNegativeError()
  755		}
  756	
  757		// Ack Flow Control policy requires push-based flow-controlled consumer.
  758		if config.AckPolicy == AckFlowControl {
  759			if config.DeliverSubject == _EMPTY_ {
  760				return NewJSConsumerAckFCRequiresPushError()
  761			}
  762			if !config.FlowControl {
  763				return NewJSConsumerAckFCRequiresFCError()
  764			}
  765			// We currently limit using heartbeat of 1s, since those are used for ephemeral sourcing consumers as well.
  766			// We could decide to relax this in the future, but need to be careful to not allow a heartbeat larger
  767			// than the stalled source timeout.
  768			if config.Heartbeat != sourceHealthHB {
  769				return NewJSStreamInvalidConfigError(fmt.Errorf("flow control ack policy heartbeat needs to be 1s"))
  770			}
  771			if config.MaxAckPending <= 0 {
  772				return NewJSConsumerAckFCRequiresMaxAckPendingError()
  773			}
  774			if config.AckWait != 0 || len(config.BackOff) > 0 {
  775				return NewJSConsumerAckFCRequiresNoAckWaitError()
  776			}
  777			if config.MaxDeliver > 0 {
  778				return NewJSConsumerAckFCRequiresNoMaxDeliverError()
  779			}
  780		}
  781	
  782		// Check if we have a BackOff defined that MaxDeliver is within range etc.
  783		if lbo := len(config.BackOff); lbo > 0 && config.MaxDeliver != -1 && lbo > config.MaxDeliver {
  784			return NewJSConsumerMaxDeliverBackoffError()
  785		}
  786	
  787		if len(config.Description) > JSMaxDescriptionLen {
  788			return NewJSConsumerDescriptionTooLongError(JSMaxDescriptionLen)
  789		}
  790	
  791		// For now expect a literal subject if its not empty. Empty means work queue mode (pull mode).
  792		if config.DeliverSubject != _EMPTY_ {
  793			if !subjectIsLiteral(config.DeliverSubject) {
  794				return NewJSConsumerDeliverToWildcardsError()
  795			}
  796			if !IsValidSubject(config.DeliverSubject) {
  797				return NewJSConsumerInvalidDeliverSubjectError()
  798			}
  799			if deliveryFormsCycle(cfg, config.DeliverSubject) {
  800				return NewJSConsumerDeliverCycleError()
  801			}
  802			if config.MaxWaiting != 0 {
  803				return NewJSConsumerPushMaxWaitingError()
  804			}
  805			if config.MaxAckPending > 0 && config.AckPolicy == AckNone {
  806				return NewJSConsumerMaxPendingAckPolicyRequiredError()
  807			}
  808			if config.Heartbeat > 0 && config.Heartbeat < 100*time.Millisecond {
  809				return NewJSConsumerSmallHeartbeatError()
  810			}
  811		} else {
  812			// Pull mode with work queue retention from the stream requires an explicit ack.
  813			if config.AckPolicy == AckNone && cfg.Retention == WorkQueuePolicy {
  814				return NewJSConsumerPullRequiresAckError()
  815			}
  816			if config.RateLimit > 0 {
  817				return NewJSConsumerPullWithRateLimitError()
  818			}
  819			if config.MaxWaiting < 0 {
  820				return NewJSConsumerMaxWaitingNegativeError()
  821			}
  822			if config.Heartbeat > 0 {
  823				return NewJSConsumerHBRequiresPushError()
  824			}
  825			if config.FlowControl {
  826				return NewJSConsumerFCRequiresPushError()
  827			}
  828			if config.MaxRequestBatch < 0 {
  829				return NewJSConsumerMaxRequestBatchNegativeError()
  830			}
  831			if config.MaxRequestExpires != 0 && config.MaxRequestExpires < time.Millisecond {
  832				return NewJSConsumerMaxRequestExpiresTooSmallError()
  833			}
  834			if srvLim.MaxRequestBatch > 0 && config.MaxRequestBatch > srvLim.MaxRequestBatch {
  835				return NewJSConsumerMaxRequestBatchExceededError(srvLim.MaxRequestBatch)
  836			}
  837		}
  838		if srvLim.MaxAckPending > 0 && config.MaxAckPending > srvLim.MaxAckPending {
  839			return NewJSConsumerMaxPendingAckExcessError(srvLim.MaxAckPending)
  840		}
  841		if accLim.MaxAckPending > 0 && config.MaxAckPending > accLim.MaxAckPending {
  842			return NewJSConsumerMaxPendingAckExcessError(accLim.MaxAckPending)
  843		}
  844		if cfg.ConsumerLimits.MaxAckPending > 0 && config.MaxAckPending > cfg.ConsumerLimits.MaxAckPending {
  845			return NewJSConsumerMaxPendingAckExcessError(cfg.ConsumerLimits.MaxAckPending)
  846		}
  847		if cfg.ConsumerLimits.InactiveThreshold > 0 && config.InactiveThreshold > cfg.ConsumerLimits.InactiveThreshold {
  848			return NewJSConsumerInactiveThresholdExcessError(cfg.ConsumerLimits.InactiveThreshold)
  849		}
  850	
  851		// Direct need to be non-mapped ephemerals.
  852		if config.Direct {
  853			if config.DeliverSubject == _EMPTY_ {
  854				return NewJSConsumerDirectRequiresPushError()
  855			}
  856			if isDurableConsumer(config) {
  857				return NewJSConsumerDirectRequiresEphemeralError()
  858			}
  859		}
  860	
  861		// Do not allow specifying both FilterSubject and FilterSubjects,
  862		// as that's probably unintentional without any difference from passing
  863		// all filters in FilterSubjects.
  864		if config.FilterSubject != _EMPTY_ && len(config.FilterSubjects) > 0 {
  865			return NewJSConsumerDuplicateFilterSubjectsError()
  866		}
  867	
  868		if config.FilterSubject != _EMPTY_ && !IsValidSubject(config.FilterSubject) {
  869			return NewJSStreamInvalidConfigError(ErrBadSubject)
  870		}
  871	
  872		// We treat FilterSubjects: []string{""} as a misconfig, so we validate against it.
  873		for _, filter := range config.FilterSubjects {
  874			if filter == _EMPTY_ {
  875				return NewJSConsumerEmptyFilterError()
  876			}
  877		}
  878		subjectFilters := gatherSubjectFilters(config.FilterSubject, config.FilterSubjects)
  879	
  880		// Check subject filters do not overlap.
  881		for outer, subject := range subjectFilters {
  882			if !IsValidSubject(subject) {
  883				return NewJSStreamInvalidConfigError(ErrBadSubject)
  884			}
  885			for inner, ssubject := range subjectFilters {
  886				if inner != outer && subjectIsSubsetMatch(subject, ssubject) {
  887					return NewJSConsumerOverlappingSubjectFiltersError()
  888				}
  889			}
  890		}
  891	
  892		// Helper function to formulate similar errors.
  893		badStart := func(dp, start string) error {
  894			return fmt.Errorf("consumer delivery policy is deliver %s, but optional start %s is also set", dp, start)
  895		}
  896		notSet := func(dp, notSet string) error {
  897			return fmt.Errorf("consumer delivery policy is deliver %s, but optional %s is not set", dp, notSet)
  898		}
  899	
  900		// Check on start position conflicts.
  901		switch config.DeliverPolicy {
  902		case DeliverAll:
  903			if config.OptStartSeq > 0 {
  904				return NewJSConsumerInvalidPolicyError(badStart("all", "sequence"))
  905			}
  906			if config.OptStartTime != nil {
  907				return NewJSConsumerInvalidPolicyError(badStart("all", "time"))
  908			}
  909		case DeliverLast:
  910			if config.OptStartSeq > 0 {
  911				return NewJSConsumerInvalidPolicyError(badStart("last", "sequence"))
  912			}
  913			if config.OptStartTime != nil {
  914				return NewJSConsumerInvalidPolicyError(badStart("last", "time"))
  915			}
  916		case DeliverLastPerSubject:
  917			if config.OptStartSeq > 0 {
  918				return NewJSConsumerInvalidPolicyError(badStart("last per subject", "sequence"))
  919			}
  920			if config.OptStartTime != nil {
  921				return NewJSConsumerInvalidPolicyError(badStart("last per subject", "time"))
  922			}
  923			if config.FilterSubject == _EMPTY_ && len(config.FilterSubjects) == 0 {
  924				return NewJSConsumerInvalidPolicyError(notSet("last per subject", "filter subject"))
  925			}
  926		case DeliverNew:
  927			if config.OptStartSeq > 0 {
  928				return NewJSConsumerInvalidPolicyError(badStart("new", "sequence"))
  929			}
  930			if config.OptStartTime != nil {
  931				return NewJSConsumerInvalidPolicyError(badStart("new", "time"))
  932			}
  933		case DeliverByStartSequence:
  934			if config.OptStartSeq == 0 {
  935				return NewJSConsumerInvalidPolicyError(notSet("by start sequence", "start sequence"))
  936			}
  937			if config.OptStartTime != nil {
  938				return NewJSConsumerInvalidPolicyError(badStart("by start sequence", "time"))
  939			}
  940		case DeliverByStartTime:
  941			if config.OptStartTime == nil {
  942				return NewJSConsumerInvalidPolicyError(notSet("by start time", "start time"))
  943			}
  944			if config.OptStartSeq != 0 {
  945				return NewJSConsumerInvalidPolicyError(badStart("by start time", "start sequence"))
  946			}
  947		}
  948	
  949		if config.SampleFrequency != _EMPTY_ {
  950			s := strings.TrimSuffix(config.SampleFrequency, "%")
  951			if sampleFreq, err := strconv.Atoi(s); err != nil || sampleFreq < 0 {
  952				return NewJSConsumerInvalidSamplingError(err)
  953			}
  954		}
  955	
  956		// We reject if flow control is set without heartbeats.
  957		if config.FlowControl && config.Heartbeat == 0 {
  958			return NewJSConsumerWithFlowControlNeedsHeartbeatsError()
  959		}
  960	
  961		if config.Durable != _EMPTY_ && config.Name != _EMPTY_ {
  962			if config.Name != config.Durable {
  963				return NewJSConsumerCreateDurableAndNameMismatchError()
  964			}
  965		}
  966	
  967		var metadataLen int
  968		for k, v := range config.Metadata {
  969			metadataLen += len(k) + len(v)
  970		}
  971		if metadataLen > JSMaxMetadataLen {
  972			return NewJSConsumerMetadataLengthError(fmt.Sprintf("%dKB", JSMaxMetadataLen/1024))
  973		}
  974	
  975		if config.PriorityPolicy != PriorityNone {
  976			if config.DeliverSubject != "" {
  977				return NewJSConsumerPushWithPriorityGroupError()
  978			}
  979			if len(config.PriorityGroups) == 0 {
  980				return NewJSConsumerPriorityPolicyWithoutGroupError()
  981			}
  982	
  983			for _, group := range config.PriorityGroups {
  984				if group == _EMPTY_ {
  985					return NewJSConsumerEmptyGroupNameError()
  986				}
  987				if !validGroupName.MatchString(group) {
  988					return NewJSConsumerInvalidGroupNameError()
  989				}
  990			}
  991		} else {
  992			// If PriorityPolicy is None or not set, reject if PriorityGroups or PinnedTTL are set
  993			if len(config.PriorityGroups) > 0 {
  994				return NewJSConsumerPriorityGroupWithPolicyNoneError()
  995			}
  996			if config.PinnedTTL > 0 {
  997				return NewJSConsumerPinnedTTLWithoutPriorityPolicyNoneError()
  998			}
  999		}
 1000	
```

## consumer.go — the ephemeral inactivity default — 5 s plus jitter

```go
 1473	// cfg.InactiveThreshold to JsDeleteWaitTimeDefault for ephemerals
 1474	// if not explicitly already specified by the user.
 1475	// Lock should be held.
 1476	func (o *consumer) updateInactiveThreshold(cfg *ConsumerConfig) {
 1477		// Ephemerals will always have inactive thresholds.
 1478		if !o.isDurable() && cfg.InactiveThreshold <= 0 {
 1479			// Add in 1 sec of jitter above and beyond the default of 5s.
 1480			o.dthresh = JsDeleteWaitTimeDefault + 100*time.Millisecond + time.Duration(rand.Int63n(900))*time.Millisecond
 1481			// Only stamp config with default sans jitter.
 1482			cfg.InactiveThreshold = JsDeleteWaitTimeDefault
 1483		} else if cfg.InactiveThreshold > 0 {
 1484			// Add in up to 1 sec of jitter if pull mode.
```

## consumer.go — `checkNewConsumerConfig` — what an update may not change

```go
 2481	func (acc *Account) checkNewConsumerConfig(cfg, ncfg *ConsumerConfig) error {
 2482		if reflect.DeepEqual(cfg, ncfg) {
 2483			return nil
 2484		}
 2485		// Something different, so check since we only allow certain things to be updated.
 2486		if cfg.DeliverPolicy != ncfg.DeliverPolicy {
 2487			return errors.New("deliver policy can not be updated")
 2488		}
 2489		if cfg.MemoryStorage != ncfg.MemoryStorage {
 2490			return errors.New("storage type can not be updated")
 2491		}
 2492		// Direct and Sourcing classify the consumer for its whole lifetime, which the
 2493		// stream relies on when walking its consumer list, so they can not change.
 2494		if cfg.Direct != ncfg.Direct {
 2495			return errors.New("direct can not be updated")
 2496		}
 2497		if cfg.Sourcing != ncfg.Sourcing {
 2498			return errors.New("sourcing can not be updated")
 2499		}
 2500		if cfg.OptStartSeq != ncfg.OptStartSeq {
 2501			return errors.New("start sequence can not be updated")
 2502		}
 2503		if cfg.OptStartTime != nil && ncfg.OptStartTime != nil {
 2504			// Both have start times set, compare them directly:
 2505			if !cfg.OptStartTime.Equal(*ncfg.OptStartTime) {
 2506				return errors.New("start time can not be updated")
 2507			}
 2508		} else if cfg.OptStartTime != nil || ncfg.OptStartTime != nil {
 2509			// At least one start time is set and the other is not
 2510			return errors.New("start time can not be updated")
 2511		}
 2512		if cfg.AckPolicy != ncfg.AckPolicy {
 2513			return errors.New("ack policy can not be updated")
 2514		}
 2515		if cfg.ReplayPolicy != ncfg.ReplayPolicy {
 2516			return errors.New("replay policy can not be updated")
 2517		}
 2518		if cfg.Heartbeat != ncfg.Heartbeat {
 2519			return errors.New("heart beats can not be updated")
 2520		}
 2521		if cfg.FlowControl != ncfg.FlowControl {
 2522			return errors.New("flow control can not be updated")
 2523		}
 2524	
 2525		// Deliver Subject is conditional on if its bound.
 2526		if cfg.DeliverSubject != ncfg.DeliverSubject {
 2527			if cfg.DeliverSubject == _EMPTY_ {
 2528				return errors.New("can not update pull consumer to push based")
 2529			}
 2530			if ncfg.DeliverSubject == _EMPTY_ {
 2531				return errors.New("can not update push consumer to pull based")
 2532			}
 2533			if acc.sl.HasInterest(cfg.DeliverSubject) {
 2534				return NewJSConsumerNameExistError()
 2535			}
 2536		}
 2537	
 2538		if cfg.MaxWaiting != ncfg.MaxWaiting {
 2539			return errors.New("max waiting can not be updated")
 2540		}
 2541	
 2542		// Check if BackOff is defined, MaxDeliver is within range.
 2543		if lbo := len(ncfg.BackOff); lbo > 0 && ncfg.MaxDeliver != -1 && lbo > ncfg.MaxDeliver {
 2544			return NewJSConsumerMaxDeliverBackoffError()
 2545		}
 2546	
 2547		return nil
 2548	}
 2549	
```

## consumer.go — `updateConfig` — what an update applies

```go
 2551	func (o *consumer) updateConfig(cfg *ConsumerConfig) error {
 2552		o.mu.Lock()
 2553		defer o.mu.Unlock()
 2554	
 2555		if o.closed || o.mset == nil {
 2556			return NewJSConsumerDoesNotExistError()
 2557		}
 2558	
 2559		if err := o.acc.checkNewConsumerConfig(&o.cfg, cfg); err != nil {
 2560			return err
 2561		}
 2562	
 2563		// Make sure we always store PauseUntil in UTC.
 2564		if cfg.PauseUntil != nil {
 2565			utc := (*cfg.PauseUntil).UTC()
 2566			cfg.PauseUntil = &utc
 2567		}
 2568	
 2569		if o.store != nil {
 2570			// Update local state always.
 2571			if err := o.store.UpdateConfig(cfg); err != nil {
 2572				return err
 2573			}
 2574		}
 2575	
 2576		// DeliverSubject
 2577		if cfg.DeliverSubject != o.cfg.DeliverSubject {
 2578			o.updateDeliverSubjectLocked(cfg.DeliverSubject)
 2579		}
 2580	
 2581		// MaxAckPending
 2582		if cfg.MaxAckPending != o.cfg.MaxAckPending {
 2583			o.maxp = cfg.MaxAckPending
 2584			o.signalNewMessages()
 2585			// If MaxAckPending is lowered, we could have allocated a pending deliveries map of larger size.
 2586			// Reset it here, so we can shrink the map.
 2587			if cfg.MaxAckPending < o.cfg.MaxAckPending {
 2588				o.resetPendingDeliveries()
 2589			}
 2590		}
 2591		// AckWait
 2592		if cfg.AckWait != o.cfg.AckWait {
 2593			if o.ptmr != nil {
 2594				o.resetPtmr(100 * time.Millisecond)
 2595			}
 2596		}
 2597		// Rate Limit
 2598		if cfg.RateLimit != o.cfg.RateLimit {
 2599			// We need both locks here so do in Go routine.
 2600			go o.setRateLimitNeedsLocks()
 2601		}
 2602		if cfg.SampleFrequency != o.cfg.SampleFrequency {
 2603			s := strings.TrimSuffix(cfg.SampleFrequency, "%")
 2604			if sampleFreq, err := strconv.ParseInt(s, 10, 32); err == nil {
 2605				o.sfreq = int32(sampleFreq)
 2606			}
 2607		}
 2608		// Set MaxDeliver if changed
 2609		if cfg.MaxDeliver != o.cfg.MaxDeliver {
 2610			// MaxDeliver is negative (-1) when infinite.
 2611			o.maxdc = uint64(max(cfg.MaxDeliver, 0))
 2612		}
 2613		// Set InactiveThreshold if changed.
 2614		if val := cfg.InactiveThreshold; val != o.cfg.InactiveThreshold {
 2615			o.updateInactiveThreshold(cfg)
 2616			stopAndClearTimer(&o.dtmr)
 2617			// Restart timer only if we are the leader.
 2618			if o.isLeader() && o.dthresh > 0 {
 2619				o.dtmr = time.AfterFunc(o.dthresh, o.deleteNotActive)
 2620			}
 2621		}
 2622		// Check whether the pause has changed
 2623		{
 2624			var old, new time.Time
 2625			if o.cfg.PauseUntil != nil {
 2626				old = *o.cfg.PauseUntil
 2627			}
 2628			if cfg.PauseUntil != nil {
 2629				new = *cfg.PauseUntil
 2630			}
 2631			if !old.Equal(new) {
 2632				o.updatePauseState(cfg)
 2633				if o.isLeader() {
 2634					o.sendPauseAdvisoryLocked(cfg)
 2635				}
 2636			}
 2637		}
 2638	
 2639		// Check for Subject Filters update.
 2640		newSubjects := gatherSubjectFilters(cfg.FilterSubject, cfg.FilterSubjects)
 2641		updatedFilters := !subjectSliceEqual(newSubjects, o.subjf.subjects())
 2642		if updatedFilters {
 2643			newSubjf := make(subjectFilters, 0, len(newSubjects))
 2644			for _, newFilter := range newSubjects {
 2645				fs := &subjectFilter{
 2646					subject:          newFilter,
 2647					hasWildcard:      subjectHasWildcard(newFilter),
 2648					tokenizedSubject: tokenizeSubjectIntoSlice(nil, newFilter),
 2649				}
 2650				newSubjf = append(newSubjf, fs)
 2651			}
 2652			// Make sure we have correct signaling setup.
 2653			// Consumer lock can not be held.
 2654			mset := o.mset
 2655			o.mu.Unlock()
 2656			mset.swapSigSubs(o, newSubjf.subjects())
 2657			o.mu.Lock()
 2658	
 2659			// When we're done with signaling, we can replace the subjects.
 2660			// If filters were removed, set `o.subjf` to nil.
 2661			if len(newSubjf) == 0 {
 2662				o.subjf = nil
 2663				o.filters = nil
 2664			} else {
 2665				o.subjf = newSubjf
 2666				if len(o.subjf) == 1 {
 2667					o.filters = nil
 2668				} else {
 2669					o.filters = gsl.NewSublist[struct{}]()
 2670					for _, filter := range o.subjf {
 2671						o.filters.Insert(filter.subject, struct{}{})
 2672					}
 2673				}
 2674			}
 2675		}
 2676	
 2677		// Record new config for others that do not need special handling.
 2678		// Allowed but considered no-op, [Description, SampleFrequency, MaxWaiting, HeadersOnly]
 2679		o.cfg = *cfg
 2680	
 2681		if cfg.Sourcing && (!o.srv.JetStreamIsClustered() && o.srv.standAloneMode()) {
 2682			o.resetStartingSeqLocked(0, _EMPTY_, false)
 2683		}
 2684		if updatedFilters {
 2685			// Cleanup messages that lost interest.
 2686			if o.retention == InterestPolicy {
 2687				// Capture mset under the lock.
 2688				mset := o.mset
 2689				o.mu.Unlock()
 2690				if mset != nil {
 2691					o.cleanupNoInterestMessages(mset, false)
 2692				}
 2693				o.mu.Lock()
 2694			}
 2695	
 2696			// Re-calculate num pending on update.
 2697			o.streamNumPending()
 2698		}
 2699	
 2700		return nil
 2701	}
 2702	
 2703	// This is a config change for the delivery subject for a
 2704	// push based consumer.
 2705	func (o *consumer) updateDeliverSubject(newDeliver string) {
```

## jetstream.go — `JetStreamConfig`, `JetStreamStats`, `JetStreamAccountLimits`, `JetStreamTier`

```go
   43	type JetStreamConfig struct {
   44		MaxMemory    int64         `json:"max_memory"`              // MaxMemory is the maximum size of memory type streams
   45		MaxStore     int64         `json:"max_storage"`             // MaxStore is the maximum size of file store type streams
   46		StoreDir     string        `json:"store_dir,omitempty"`     // StoreDir is where storage files are stored
   47		SyncInterval time.Duration `json:"sync_interval,omitempty"` // SyncInterval is how frequently we sync to disk in the background by calling fsync
   48		SyncAlways   bool          `json:"sync_always,omitempty"`   // SyncAlways indicates flushes are done after every write
   49		Domain       string        `json:"domain,omitempty"`        // Domain is the JetStream domain
   50		CompressOK   bool          `json:"compress_ok,omitempty"`   // CompressOK indicates if compression is supported
   51		UniqueTag    string        `json:"unique_tag,omitempty"`    // UniqueTag is the unique tag assigned to this instance
   52		Strict       bool          `json:"strict,omitempty"`        // Strict indicates if strict JSON parsing is performed
   53	
   54		// maxStorePending is set when MaxStore was derived from the available disk
   55		// space rather than configured, and has not been adjusted yet for the space
   56		// that recovered streams already occupy. See finalizeDynamicMaxStore.
   57		maxStorePending bool
   58	}
   59	
   60	// Statistics about JetStream for this server.
   61	type JetStreamStats struct {
   62		Memory         uint64            `json:"memory"`
   63		Store          uint64            `json:"storage"`
   64		ReservedMemory uint64            `json:"reserved_memory"`
   65		ReservedStore  uint64            `json:"reserved_storage"`
   66		Accounts       int               `json:"accounts"`
   67		HAAssets       int               `json:"ha_assets"`
   68		API            JetStreamAPIStats `json:"api"`
   69	}
   70	
   71	type JetStreamAccountLimits struct {
   72		MaxMemory            int64 `json:"max_memory"`
   73		MaxStore             int64 `json:"max_storage"`
   74		MaxStreams           int   `json:"max_streams"`
   75		MaxConsumers         int   `json:"max_consumers"`
   76		MaxAckPending        int   `json:"max_ack_pending"`
   77		MemoryMaxStreamBytes int64 `json:"memory_max_stream_bytes"`
   78		StoreMaxStreamBytes  int64 `json:"storage_max_stream_bytes"`
   79		MaxBytesRequired     bool  `json:"max_bytes_required"`
   80	}
   81	
   82	type JetStreamTier struct {
   83		Memory         uint64                 `json:"memory"`
   84		Store          uint64                 `json:"storage"`
   85		ReservedMemory uint64                 `json:"reserved_memory"`
   86		ReservedStore  uint64                 `json:"reserved_storage"`
   87		Streams        int                    `json:"streams"`
   88		Consumers      int                    `json:"consumers"`
   89		Limits         JetStreamAccountLimits `json:"limits"`
   90	}
   91	
   92	// JetStreamAccountStats returns current statistics about the account's JetStream usage.
   93	type JetStreamAccountStats struct {
   94		JetStreamTier                          // in case tiers are used, reflects totals with limits not set
   95		Domain        string                   `json:"domain,omitempty"`
```

## opts.go — `JSLimitOpts` — the server-wide `jetstream { limits { … } }`

```go
  375	type JSLimitOpts struct {
  376		MaxRequestBatch           int           `json:"max_request_batch,omitempty"`             // MaxRequestBatch is the maximum amount of updates that can be sent in a batch
  377		MaxAckPending             int           `json:"max_ack_pending,omitempty"`               // MaxAckPending is the server limit for maximum amount of outstanding Acks
  378		MaxHAAssets               int           `json:"max_ha_assets,omitempty"`                 // MaxHAAssets is the maximum of Streams and Consumers that may have more than 1 replica
  379		Duplicates                time.Duration `json:"max_duplicate_window,omitempty"`          // Duplicates is the maximum value for duplicate tracking on Streams
  380		MaxBatchInflightPerStream int           `json:"max_batch_inflight_per_stream,omitempty"` // MaxBatchInflightPerStream is the maximum amount of open batches per stream
  381		MaxBatchInflightTotal     int           `json:"max_batch_inflight_total,omitempty"`      // MaxBatchInflightTotal is the maximum amount of total open batches per server
  382		MaxBatchSize              int           `json:"max_batch_size,omitempty"`                // MaxBatchSize is the maximum amount of messages allowed in a batch publish to a Stream
  383		MaxBatchTimeout           time.Duration `json:"max_batch_timeout,omitempty"`             // MaxBatchTimeout is the maximum time to receive the commit message after receiving the first message of a batch
  384	}
```

## jetstream_api.go — `JSMaxDescriptionLen`, `JSMaxMetadataLen`, `JSMaxNameLen`, `JSWaitQueueDefaultMax`

```go
  353	
  354	// JSMaxDescription is the maximum description length for streams and consumers.
  355	const JSMaxDescriptionLen = 4 * 1024
  356	
  357	// JSMaxMetadataLen is the maximum length for streams and consumers metadata map.
  358	// It's calculated by summing length of all keys and values.
  359	const JSMaxMetadataLen = 128 * 1024
  360	
  361	// JSMaxNameLen is the maximum name lengths for streams, consumers and templates.
  362	// Picked 255 as it seems to be a widely used file name limit
  363	const JSMaxNameLen = 255
  364	
```

## jetstream_api.go — `JSWaitQueueDefaultMax`

```go
  703	
  704	// JSWaitQueueDefaultMax is the default max number of outstanding requests for pull consumers.
  705	const JSWaitQueueDefaultMax = 512
  706	
```

## jetstream_api.go — `JSApiStreamInfoRequest` (`subjects_filter`), `JSApiConsumerGetNextRequest`

```go
  437	type JSApiStreamInfoRequest struct {
  438		ApiPagedRequest
  439		DeletedDetails bool   `json:"deleted_details,omitempty"`
  440		SubjectsFilter string `json:"subjects_filter,omitempty"`
  441	}
  442	
  443	type JSApiStreamInfoResponse struct {
  444		ApiResponse
  445		ApiPaged
  446		*StreamInfo
  447	}
```

## jetstream_api.go — `JSApiConsumerGetNextRequest` — no `batch` ceiling in the struct

```go
  762	
  763	// JSApiConsumerGetNextRequest is for getting next messages for pull based consumers.
  764	type JSApiConsumerGetNextRequest struct {
  765		Expires   time.Duration `json:"expires,omitempty"`
  766		Batch     int           `json:"batch,omitempty"`
  767		MaxBytes  int           `json:"max_bytes,omitempty"`
  768		NoWait    bool          `json:"no_wait,omitempty"`
  769		Heartbeat time.Duration `json:"idle_heartbeat,omitempty"`
  770		PriorityGroup
  771	}
  772	
```

## jetstream_cluster.go — `Placement`

```go
  114	type Placement struct {
  115		Cluster   string   `json:"cluster,omitempty"`
  116		Tags      []string `json:"tags,omitempty"`
  117		Preferred string   `json:"preferred,omitempty"`
  118	}
  119	
  120	// Define types of the entry.
```
