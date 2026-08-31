<!-- source: https://github.com/nats-io/nats.go at tag v1.53.1 · files nats.go, jetstream/errors.go · fetched 2026-08-31 -->
# nats.go v1.53.1 — the error strings an operator sees

Only the ranges this wiki quotes are stored, with their real line numbers, so each value links to
`https://github.com/nats-io/nats.go/blob/v1.53.1/<file>#L<line>`. Apache-2.0.

Read for question-bank Q77 (*what does an unexpected `nats: timeout` actually mean*), to separate
the client-produced timeout from the server-produced no-responders reply.

### `nats.go` lines 100–152 (excerpted)

```go
   102		ErrConnectionClosed              = errors.New("nats: connection closed")
   112		ErrSlowConsumer                  = errors.New("nats: slow consumer, messages dropped")
   113		ErrTimeout                       = errors.New("nats: timeout")
   151		ErrNoResponders                  = errors.New("nats: no responders available for request")
```

### `jetstream/errors.go` lines 260–266

```go
   260		ErrMsgAlreadyAckd JetStreamError = &jsError{message: "message was already acknowledged"}
   261	
   262		// ErrNoStreamResponse is returned when there is no response from stream
   263		// (e.g. no responders error).
   264		ErrNoStreamResponse JetStreamError = &jsError{message: "no response from stream"}
   265	
   266		// ErrNotJSMessage is returned when attempting to get metadata from non
```
