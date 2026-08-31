<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6, files fetched from raw.githubusercontent.com · fetched 2026-08-31 -->
# nats-server v2.14.6 — the constants this wiki quotes

Extracted line ranges, verbatim, from the tagged source. One block per file; the line numbers
are the real ones in that file at that tag, so every default on `wiki/reference/defaults-and-limits.md`
can be checked against `https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`.

## server/const.go

```go
    78		DEFAULT_PORT = 4222

    86		DEFAULT_HOST = "0.0.0.0"

    90		MAX_CONTROL_LINE_SIZE = 4096

    94		MAX_PAYLOAD_SIZE = (1024 * 1024)

    96		// MAX_PAYLOAD_MAX_SIZE is the size at which the server will warn about
    97		// max_payload being too high. In the future, the server may enforce/reject
    98		// max_payload above this value.
    99		MAX_PAYLOAD_MAX_SIZE = (8 * 1024 * 1024)

   102		MAX_PENDING_SIZE = (64 * 1024 * 1024)

   105		DEFAULT_MAX_CONNECTIONS = (64 * 1024)

   108		TLS_TIMEOUT = 2 * time.Second

   117		AUTH_TIMEOUT = 2 * time.Second

   120		DEFAULT_PING_INTERVAL = 2 * time.Minute

   123		DEFAULT_PING_MAX_OUT = 2

   132		DEFAULT_FLUSH_DEADLINE = 10 * time.Second

   135		DEFAULT_HTTP_PORT = 8222

   192		DEFAULT_MAX_CLOSED_CLIENTS = 10000
```

## server/consumer.go

```go
   572		// JsAckWaitDefault is the default AckWait, only applicable on explicit ack policy consumers.
   573		JsAckWaitDefault = 30 * time.Second
   574		// JsDeleteWaitTimeDefault is the default amount of time we will wait for non-durable
   575		// consumers to be in an inactive state before deleting them.
   576		JsDeleteWaitTimeDefault = 5 * time.Second

   579		// JsDefaultMaxAckPending is set for consumers with explicit ack that do not set the max ack pending.
   580		JsDefaultMaxAckPending = 1000
   581		// JsDefaultPinnedTTL is the default grace period for the pinned consumer to send a new request before a new pin
   582		// is picked by a server.
   583		JsDefaultPinnedTTL = 2 * time.Minute

   589		if config.MaxDeliver == 0 || config.MaxDeliver < -1 {
   590			if pedantic && config.MaxDeliver < -1 {
   591				return NewJSPedanticError(errors.New("max_deliver must be set to -1"))
   592			}
   593			config.MaxDeliver = -1
```

## server/stream.go

```go
  1657	// StreamDefaultDuplicatesWindow default duplicates window.
  1658	const StreamDefaultDuplicatesWindow = 2 * time.Minute
```

## server/filestore.go

```go
   332		// default sync interval
   333		defaultSyncInterval = 2 * time.Minute
```

## server/server.go

```go
  2342		if opts.MaxPayload > MAX_PAYLOAD_MAX_SIZE {
  2343			s.Warnf("Maximum payloads over %v are generally discouraged and could lead to poor performance",
  2344				friendlyBytes(int64(MAX_PAYLOAD_MAX_SIZE)))
  2345		}
```

## server/jetstream_api.go

Advisory subject prefixes. The full subject appends `.<stream>` or `.<stream>.<consumer>`.

```go
   232		JSAdvisoryPrefix = "$JS.EVENT.ADVISORY"

   241		JSAdvisoryConsumerMaxDeliveryExceedPre = "$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES"

   244		JSAdvisoryConsumerMsgNakPre = "$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED"

   247		JSAdvisoryConsumerMsgTerminatedPre = "$JS.EVENT.ADVISORY.CONSUMER.MSG_TERMINATED"

   250		JSAdvisoryStreamCreatedPre = "$JS.EVENT.ADVISORY.STREAM.CREATED"

   253		JSAdvisoryStreamDeletedPre = "$JS.EVENT.ADVISORY.STREAM.DELETED"

   256		JSAdvisoryStreamUpdatedPre = "$JS.EVENT.ADVISORY.STREAM.UPDATED"

   259		JSAdvisoryConsumerCreatedPre = "$JS.EVENT.ADVISORY.CONSUMER.CREATED"

   262		JSAdvisoryConsumerDeletedPre = "$JS.EVENT.ADVISORY.CONSUMER.DELETED"

   265		JSAdvisoryConsumerPausePre = "$JS.EVENT.ADVISORY.CONSUMER.PAUSE"

   268		JSAdvisoryConsumerPinnedPre = "$JS.EVENT.ADVISORY.CONSUMER.PINNED"

   271		JSAdvisoryConsumerUnpinnedPre = "$JS.EVENT.ADVISORY.CONSUMER.UNPINNED"

   274		JSAdvisoryStreamSnapshotCreatePre = "$JS.EVENT.ADVISORY.STREAM.SNAPSHOT_CREATE"

   277		JSAdvisoryStreamSnapshotCompletePre = "$JS.EVENT.ADVISORY.STREAM.SNAPSHOT_COMPLETE"

   280		JSAdvisoryStreamRestoreCreatePre = "$JS.EVENT.ADVISORY.STREAM.RESTORE_CREATE"

   283		JSAdvisoryStreamRestoreCompletePre = "$JS.EVENT.ADVISORY.STREAM.RESTORE_COMPLETE"

   286		JSAdvisoryDomainLeaderElected = "$JS.EVENT.ADVISORY.DOMAIN.LEADER_ELECTED"

   289		JSAdvisoryStreamLeaderElectedPre = "$JS.EVENT.ADVISORY.STREAM.LEADER_ELECTED"

   292		JSAdvisoryStreamQuorumLostPre = "$JS.EVENT.ADVISORY.STREAM.QUORUM_LOST"

   295		JSAdvisoryStreamBatchAbandonedPre = "$JS.EVENT.ADVISORY.STREAM.BATCH_ABANDONED"

   298		JSAdvisoryConsumerLeaderElectedPre = "$JS.EVENT.ADVISORY.CONSUMER.LEADER_ELECTED"

   301		JSAdvisoryConsumerQuorumLostPre = "$JS.EVENT.ADVISORY.CONSUMER.QUORUM_LOST"

   304		JSAdvisoryServerOutOfStorage = "$JS.EVENT.ADVISORY.SERVER.OUT_OF_STORAGE"

   307		JSAdvisoryServerRemoved = "$JS.EVENT.ADVISORY.SERVER.REMOVED"

   310		JSAdvisoryAPILimitReached = "$JS.EVENT.ADVISORY.API.LIMIT_REACHED"

   314		JSAuditAdvisory = "$JS.EVENT.ADVISORY.API"
```

