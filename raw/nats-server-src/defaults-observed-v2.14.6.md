<!-- source: nats-server v2.14.6 (Homebrew bottle, arm64), run locally · 2026-08-31 · plus source
     ranges from https://github.com/nats-io/nats-server at tag v2.14.6 -->
# nats-server v2.14.6 — the config-default sweep: source ranges and what the binary does

Evidence for the three findings the mechanical sweep of `inbox/config-keys-table.md` turned up
(`tools/check-defaults.py`, report in `inbox/check-defaults-v2.14.6.md`): the **leafnode compression
default**, **`mqtt.max_ack_pending`** and **`mqtt.port`**. Source quotes first, then the runs.

The binary is the same release the ranges come from:

```
$ nats-server --version
nats-server: v2.14.6
```

---

## 1 · Leafnode compression defaults to `s2_auto`, not `accept`

`server/opts.go`, `setBaselineOptions()` — the incoming-leafnode side (v2.14.6):

```go
6082:		// Default to compression "s2_auto".
6083:		if c := &opts.LeafNode.Compression; c.Mode == _EMPTY_ {
6084:			if testDefaultLeafNodeCompression != _EMPTY_ {
6085:				c.Mode = testDefaultLeafNodeCompression
6086:			} else {
6087:				c.Mode = CompressionS2Auto
6088:			}
6089:		}
```

and the remote side, in the loop over `opts.LeafNode.Remotes`:

```go
6099:			// Default to compression "s2_auto".
6100:			if c := &r.Compression; c.Mode == _EMPTY_ {
6101:				if testDefaultLeafNodeCompression != _EMPTY_ {
6102:					c.Mode = testDefaultLeafNodeCompression
6103:				} else {
6104:					c.Mode = CompressionS2Auto
6105:				}
6106:			}
```

`testDefaultLeafNodeCompression` is a test hook — declared with no value in a `var` block in
`server/server.go:440` (`testDefaultClusterCompression` is its sibling at 439) and assigned only from
`_test.go` files — so in a released binary it is empty and the branch taken is `CompressionS2Auto`.

The route (cluster) side, twenty lines earlier, is the one that really does default to `accept`:

```go
6061:		// Default to compression "accept", which means that compression is not
6062:		// initiated, but if the remote selects compression, this server will
6063:		// use the same.
6064:		if c := &opts.Cluster.Compression; c.Mode == _EMPTY_ {
6065:			if testDefaultClusterCompression != _EMPTY_ {
6066:				c.Mode = testDefaultClusterCompression
6067:			} else {
6068:				c.Mode = CompressionAccept
6069:			}
6070:		}
```

The mode names (`server/server.go`):

```go
447:	CompressionAccept         = "accept"
448:	CompressionS2Auto         = "s2_auto"
449:	CompressionS2Uncompressed = "s2_uncompressed"
```

`s2_uncompressed` is the level `s2_auto` selects while the RTT is below the first threshold
(`selectS2AutoModeBasedOnRTT`, `server/server.go:625`), so seeing it on a connection is proof that
`s2_auto` — not `accept` — is in force.

### Observed — default, nothing configured

```
$ cat hub.conf
server_name: hub
port: 4222
http_port: 8222
leafnodes { port: 7422 }

$ cat leaf.conf
server_name: leaf
port: 4223
http_port: 8223
leafnodes { remotes: [ { url: "nats://127.0.0.1:7422" } ] }

$ nats-server -c hub.conf &  ;  nats-server -c leaf.conf &
$ curl -s http://127.0.0.1:8223/leafz
{
  "leafnodes": 1,
  "leafs": [
    {
      "id": 5,
      "name": "hub",
      "is_spoke": true,
      "account": "$G",
      "ip": "127.0.0.1",
      "port": 7422,
      "rtt": "453µs",
      "subscriptions": 5,
      "compression": "s2_uncompressed"
    }
  ]
}
```

The hub reports the same for its side of the connection (`"compression": "s2_uncompressed"`).

### Observed — `compression: accept` on both sides, which is what the docs claim is the default

```
$ cat accept-hub.conf
server_name: hub2
port: 4224
http_port: 8224
leafnodes { port: 7423, compression: accept }

$ cat accept-leaf.conf
server_name: leaf2
port: 4225
http_port: 8225
leafnodes { remotes: [ { url: "nats://127.0.0.1:7423", compression: accept } ] }

$ curl -s http://127.0.0.1:8225/leafz | grep compression
      "compression": "off"
```

**`off` versus `s2_uncompressed`**: configuring the documented default changes the connection's
behaviour, which is the clearest possible demonstration that it is not the default.

---

## 2 · `mqtt.max_ack_pending` defaults to 1024, not 100

`server/mqtt.go` (v2.14.6):

```go
149:	// This is the default for the outstanding number of pending QoS 1
150:	// messages sent to a session with QoS 1 subscriptions.
151:	mqttDefaultMaxAckPending = 1024
```

It is applied where the option is read, not where it is parsed — three sites, all the same shape:

```go
3333:// Returns a new mqttSession object with max ack pending set based on
3334:// option or use mqttDefaultMaxAckPending if no option set.
3335:func mqttSessionCreate(jsa *mqttJSA, id, idHash string, seq uint64, opts *Options) *mqttSession {
3336:	maxp := opts.MQTT.MaxAckPending
3337:	if maxp == 0 {
3338:		maxp = mqttDefaultMaxAckPending
3339:	}
```

```go
5497:		maxAckPending := int(opts.MQTT.MaxAckPending)
5498:		if maxAckPending == 0 {
5499:			maxAckPending = mqttDefaultMaxAckPending
5500:		}
```

```go
5633:			maxAckPending := int(opts.MQTT.MaxAckPending)
5634:			if maxAckPending == 0 {
5635:				maxAckPending = mqttDefaultMaxAckPending
5636:			}
```

Because the default is applied at the use site, the option itself stays zero, and `/varz` (which
tags the field `omitempty`) omits it entirely — so the server demonstrably does not hold `100`:

```
$ cat mqtt.conf
server_name: m1
port: 4226
http_port: 8226
jetstream { store_dir: "/tmp/obs/js" }
mqtt { port: 1883 }

$ curl -s http://127.0.0.1:8226/varz | jq .mqtt
{
  "host": "0.0.0.0",
  "port": 1883,
  "tls_timeout": 2
}
```

The same output also shows `tls_timeout: 2` for MQTT, and the top level reports
`"auth_timeout": 2, "tls_timeout": 2` — the values docs issue #19 records as 500ms and 1 in the
reference.

---

## 3 · `mqtt.port` has no default: with no port, MQTT silently does not listen

`server/mqtt.go`, `validateMQTTOptions()`:

```go
689:func validateMQTTOptions(o *Options) error {
690:	mo := &o.MQTT
691:	// If no port is defined, we don't care about other options
692:	if mo.Port == 0 {
693:		return nil
694:	}
```

`server/websocket.go:1125` opens `validateWebsocketOptions()` with the same two lines.

`1883` does not appear anywhere in the non-test server source.

```
$ cat mqtt-noport.conf
server_name: m2
port: 4227
http_port: 8227
jetstream { store_dir: "/tmp/obs/js2" }
mqtt { }

$ nats-server -c mqtt-noport.conf
[4152] 2026/08/31 08:07:28.199457 [INF] Starting nats-server
[4152] 2026/08/31 08:07:28.199548 [INF]   Version:  2.14.6
[4152] 2026/08/31 08:07:28.199572 [INF] Using configuration file: mqtt-noport.conf (sha256:f7c27c7b10fa02bd34a267a24d8d0d24e61ffeb3f5d79a87a00d964204b8cfec)
[4152] 2026/08/31 08:07:28.199867 [INF] Starting http monitor on 0.0.0.0:8227
[4152] 2026/08/31 08:07:28.199923 [INF] Starting JetStream
   … no "Listening for MQTT clients" line …

$ curl -s http://127.0.0.1:8227/varz | jq .mqtt
{}
```

With the port set, the same binary logs it:

```
[3868] 2026/08/31 08:07:10.712017 [INF] Listening for MQTT clients on mqtt://0.0.0.0:1883
```

So the server starts, the `mqtt` block is accepted, and no MQTT listener exists — the same silent
outcome docs issue #23 records for `cluster.port` and `leafnodes.port`.
