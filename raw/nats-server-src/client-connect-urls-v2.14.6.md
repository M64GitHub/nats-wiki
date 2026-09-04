<!-- source: nats-server v2.14.6 source tree (`.cache/nats-server-2.14.6/`, the tarball tools/check-defaults.py keeps, from https://github.com/nats-io/nats-server/archive/refs/tags/v2.14.6.tar.gz) · read 2026-09-04 · one grep and three quoted ranges, verbatim, line numbers as in the release archive -->
# nats-server 2.14.6 — who feeds `connect_urls`, and who does not

For question-bank row 156 ("Does a client discover the other clusters of a supercluster, and how do I
fail clients over to another cluster?", gh#7328). The question is settled by which files call the
two helpers that rewrite the server's `INFO` for clients.

## 1 · The helpers, and every call site

`server/server.go:3610–3630` defines the pair (comments verbatim):

```go
// Adds to the list of client and websocket clients connect URLs.
// If there was a change, an INFO protocol is sent to registered clients
// that support async INFO protocols.
// Server lock held on entry.
func (s *Server) addConnectURLsAndSendINFOToClients(curls, wsurls []string) {
	s.updateServerINFOAndSendINFOToClients(curls, wsurls, true)
}

// Removes from the list of client and websocket clients connect URLs.
// If there was a change, an INFO protocol is sent to registered clients
// that support async INFO protocols.
// Server lock held on entry.
func (s *Server) removeConnectURLsAndSendINFOToClients(curls, wsurls []string) {
	s.updateServerINFOAndSendINFOToClients(curls, wsurls, false)
}
```

Every call, in the whole `server/` package:

```
$ grep -rn "addConnectURLsAndSendINFOToClients(\|removeConnectURLsAndSendINFOToClients(" \
    .cache/nats-server-2.14.6/server/*.go | grep -v "func (s \*Server)"
server/route.go:728:			s.removeConnectURLsAndSendINFOToClients(connectURLs, wsConnectURLs)
server/route.go:2389:				s.addConnectURLsAndSendINFOToClients(info.ClientConnectURLs, info.WSConnectURLs)
server/route.go:3205:				s.removeConnectURLsAndSendINFOToClients(connectURLs, wsConnectURLs)
```

**Three call sites, all in `route.go`.** `gateway.go` and `leafnode.go` call neither.

## 2 · The three sites, in context

`server/route.go:2386–2391` — a route's `INFO` arrives and its client URLs are merged in:

```go
			// Unless disabled, possibly update the server's INFO protocol
			// and send to clients that know how to handle async INFOs.
			if !opts.Cluster.NoAdvertise {
				s.addConnectURLsAndSendINFOToClients(info.ClientConnectURLs, info.WSConnectURLs)
			}
```

`server/route.go:723–730` — the remote enters lame duck mode and its URLs are withdrawn:

```go
		// If the remote is going into LDM and there are client connect URLs
		// associated with this route and we are allowed to advertise, remove
		// those URLs and update our clients.
		if (len(connectURLs) > 0 || len(wsConnectURLs) > 0) && !opts.Cluster.NoAdvertise {
			s.mu.Lock()
			s.removeConnectURLsAndSendINFOToClients(connectURLs, wsConnectURLs)
			s.mu.Unlock()
		}
```

`server/route.go:3198–3206` — the last route to a remote closes:

```go
		if empty {
			delete(s.routes, rID)

			// Since this is the last route for this remote, possibly update
			// the client connect URLs and send an update to connected
			// clients.
			if (len(connectURLs) > 0 || len(wsConnectURLs) > 0) && !opts.Cluster.NoAdvertise {
				s.removeConnectURLsAndSendINFOToClients(connectURLs, wsConnectURLs)
			}
```

All three are gated on `!opts.Cluster.NoAdvertise` — the `cluster { no_advertise }` key.

## 3 · What a gateway does carry, next to it

The same `route.go:2384–2385`, immediately above the first site, sends the *gateway* configuration to
the route, not to clients:

```go
			// Send info about the known gateways to this route.
			s.sendGatewayConfigsToRoute(c)
```

## What that gives

A client's `connect_urls` is built from **routes only** — the members of its own cluster. No gateway
path adds a client address, so a client connected to one cluster of a supercluster never learns that
another cluster exists, let alone how to reach it. Failing clients across clusters has to be
configured in the client's URL list or in front of it (DNS, load balancer).

**Not tested**: no run was made for this file; it is a source reading. The measured behaviour of
gossip *within* one cluster is in `raw/nats-server-src/client-lifecycle-observed-v2.14.6.md` (a
one-URL client fails over via `connect_urls`).
