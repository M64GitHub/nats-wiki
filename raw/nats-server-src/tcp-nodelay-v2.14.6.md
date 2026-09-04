<!-- source: nats-server v2.14.6 source tree (`.cache/nats-server-2.14.6/`, the tarball tools/check-defaults.py keeps, from https://github.com/nats-io/nats-server/archive/refs/tags/v2.14.6.tar.gz) and the Go standard library at go1.27.0 (`$(go env GOROOT)/src/net/tcpsock.go`, https://github.com/golang/go/blob/go1.27.0/src/net/tcpsock.go) · read 2026-09-04 · the two greps and one quoted range, verbatim -->
# Is Nagle's algorithm disabled on NATS connections? — the two greps that settle it

For question-bank row 148 ("Is Nagle's algorithm (`TCP_NODELAY`) disabled on client and route
connections?", gh#4267). The answer is not in the server's source, and that absence *is* the answer:
the server never touches the option, and Go's `net` package sets it on every TCP connection it
creates.

## 1 · The server never calls it, anywhere, at v2.14.6

```
$ grep -rn "SetNoDelay\|NoDelay\|TCP_NODELAY" .cache/nats-server-2.14.6/
(no output)
```

The tree searched is the whole release archive — `server/`, `internal/`, `logger/`, `util/`, `test/`,
`conf/` and `main.go`. There is no configuration key either: nothing named `no_delay`, `nodelay` or
`tcp_nodelay` exists in `server/opts.go` or in `conf/`.

## 2 · Go sets it unconditionally, for every TCP connection

`/opt/homebrew/Cellar/go/1.27.0/libexec/src/net/tcpsock.go` at **go1.27.0**, `newTCPConn` — the constructor every accepted and every
dialled `*TCPConn` goes through:

```go
func newTCPConn(fd *netFD, keepAliveIdle time.Duration, keepAliveCfg KeepAliveConfig, preKeepAliveHook func(*netFD), keepAliveHook func(KeepAliveConfig)) *TCPConn {
	setNoDelay(fd, true)
```

(line 289–290.) `SetNoDelay(true)` means the OS should **not** delay sending — Nagle off. The
doc comment on the exported method says so (line 259–263):

```go
// SetNoDelay controls whether the operating system should delay
// packet transmission in hopes of sending fewer packets (Nagle's
// algorithm).  The default is true (no delay), meaning that data is
// sent as soon as possible after a Write.
func (c *TCPConn) SetNoDelay(noDelay bool) error {
```

## What that gives

Every NATS connection the server accepts or dials — client, route, leafnode, gateway, WebSocket and
MQTT alike, since all of them are `net.Listener`/`net.Dial` TCP connections — has `TCP_NODELAY` set,
because Go set it and the server never unsets it. The same holds for every Go client (nats.go, the
`nats` CLI) and for any other client whose runtime does the same; a client in a language whose
sockets default to Nagle **on** would have to disable it itself, and this file says nothing about
those.

**Not tested**: whether the option is actually visible on a live socket (`sysctl`/`ss -i` or an
equivalent). This is a source reading of two trees, not a run.
