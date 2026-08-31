<!-- source: nats-io/nats-server at tag v2.14.6, quoted ranges from server/*.go, plus runs against
     the v2.14.6 binary with nats CLI 0.4.0 · observed 2026-09-01. -->

# nats-server v2.14.6 — how `/varz` CPU and `/connz` RTT are measured, and the advisory subjects on the wire

Read and run while ingesting `learn/monitoring`, to answer question-bank rows **Q60** and **Q61** —
neither of which any page of that chapter states — and to cross-check docs issues **#1–#3**, the three
advisory subject names, against something other than a source constant.

---

## 1 · Q60 — what `/varz` `cpu` actually measures

`Varz.CPU` is filled from `pse.ProcUsage` (`monitor.go:1609–1618`, `:1884–1888`,
`:2009–2031`). The struct comments and json tags (`monitor.go:1260–1263`):

```go
1260:	Cores                 int     `json:"cores"`       // Cores is the number of cores the process has access to
1261:	MaxProcs              int     `json:"gomaxprocs"`  // MaxProcs is the configured GOMAXPROCS value
1263:	CPU                   float64 `json:"cpu"`         // CPU is the current total CPU usage
```

filled at `monitor.go:1727–1728` with `runtime.NumCPU()` and `runtime.GOMAXPROCS(0)`.

**On Linux the number is sampled once a second by a background timer**, not computed at request time
(`server/pse/pse_linux.go:49–86`):

```go
49:	func periodic() {
50:		contents, err := os.ReadFile(procStatFile)          // /proc/<pid>/stat
...
57:		pstart := parseInt64(fields[startPos])               // field 21
58:		utime  := parseInt64(fields[utimePos])               // field 13
59:		stime  := parseInt64(fields[stimePos])               // field 14
60:		total  := utime + stime
62:		var sysinfo syscall.Sysinfo_t
63:		if err := syscall.Sysinfo(&sysinfo); err != nil { return }
65:		seconds := int64(sysinfo.Uptime) - (pstart / ticks)
...
77:		total   -= lt        // delta since the previous sample
78:		seconds -= ls
80:		if seconds > 0 {
81:			atomic.StoreInt64(&ipcpu, (total*1000/ticks)/seconds)
82:		}
84:		time.AfterFunc(1*time.Second, periodic)
85:	}
```

and read back unchanged (`pse_linux.go:91–107`):

```go
102:		// PCPU
103:		// We track this with periodic sampling, so just load and go.
104:		*pcpu = float64(atomic.LoadInt64(&ipcpu)) / 10.0
```

**The arithmetic, and the answer to the question.** `total` is the process's own CPU time in clock
ticks over the last second; `ticks` is 100 ticks/second; so one full second of CPU per second of wall
clock gives `(100*1000/100)/1 = 1000`, and `/10.0` = **100.0**.

> **`cpu` is a percentage of ONE core.** `100.0` means one core fully consumed; `250.0` means two and
> a half cores. It is relative to **neither** the host's core count **nor** any container CPU
> allocation — it is an absolute "cores consumed × 100".

That is the exact question asked in gh#7483 and never answered there.

**Two caveats visible in the same function:**

- **`ticks` is hardcoded to 100**, not read from the system (`pse_linux.go:42–43`):
  ```go
  42:		// Avoiding to generate docker image without CGO
  43:		ticks = 100 // int64(C.sysconf(C._SC_CLK_TCK))
  ```
  On a kernel whose `CLK_TCK` is not 100 the reported percentage is scaled wrong.
- **`seconds` is derived from `syscall.Sysinfo().Uptime`**, which is the **host's** uptime, not the
  container's or the process's.

**`cores` is `runtime.NumCPU()`**, which is the Go runtime's view. The struct comment calls it "the
number of cores the process has access to"; the gh#7483 reporter observed `"cores": 2` on an AWS
Fargate task allocated **0.25 vCPU**, i.e. the host's logical CPUs. Nothing in `monitor.go` or
`pse_linux.go` consults a cgroup CPU quota.

**On darwin** (this machine) `ProcUsage` is a different implementation
(`server/pse/pse_darwin.go:83–86`, delegating to `updateUsage()`), so the tick arithmetic above is the
**Linux** path. Observed here only as a sanity check:

```
curl -s localhost:8281/varz
  cpu          0.1
  cores        10
  gomaxprocs   10
  mem          24576000
```

## 2 · Q61 — how `/routez` and `/connz` `rtt` are measured

`ci.RTT = c.rtt` (`client.go:6605`), and `c.rtt` is set in exactly two places.

**At connect, from the connection setup time — not a ping** (`client.go:2286–2289`):

```go
2286:	c.last = time.Now().UTC()
2287:	// Estimate RTT to start.
2288:	if c.kind == CLIENT {
2289:		c.rtt = computeRTT(c.start)
```

**On every PONG, from the matching PING** (`client.go:2690` and `:2798–2801`):

```go
2690:	c.rttStart = time.Now().UTC()      // in sendPing()
...
2798:	func (c *client) processPong() {
2799:		c.mu.Lock()
2800:		c.ping.out = 0
2801:		c.rtt = computeRTT(c.rttStart)
```

with (`client.go:2262–2267`):

```go
2262:	func computeRTT(start time.Time) time.Duration {
2263:		rtt := time.Since(start)
2264:		if rtt <= 0 {
2265:			rtt = time.Nanosecond
2266:		}
2267:		return rtt
2268:	}
```

so a measurement is **floored at 1ns** and `rtt` is never reported as zero once set.

**How often it refreshes — the fact the public thread never got.** `const.go:222–224`:

```go
222:	// DEFAULT_RTT_MEASUREMENT_INTERVAL is how often we want to measure RTT from
223:	// this server to clients, routes, gateways or leafnode connections.
224:	DEFAULT_RTT_MEASUREMENT_INTERVAL = time.Hour
```

used at `client.go:5844`:

```go
5844:	needRTT := c.rtt == 0 || now.Sub(c.rttStart) > DEFAULT_RTT_MEASUREMENT_INTERVAL
5846:	// Do not delay PINGs for ROUTER, GATEWAY or spoke LEAF connections.
5847:	if c.kind == ROUTER || c.kind == GATEWAY || c.isSpokeLeafNode() {
5848:		sendPing = true
5849:	} else {
5850:		// If we received client data or a ping from the other side within the PingInterval,
5851:		// then there is no need to send a ping.
5852:		if delta := now.Sub(c.lastIn); delta < pingInterval && !needRTT {
```

So:

- **A route, gateway or spoke-leaf connection is pinged on every ping-timer tick**, so its `rtt`
  refreshes at the ping interval (default `2m`).
- **A client connection is not.** If the client has sent anything within the ping interval, the server
  skips the PING unless `needRTT` — which becomes true only when `c.rtt == 0` or **more than an hour**
  has passed since the last one. On a busy client, `/connz` `rtt` is therefore **the connect-time
  estimate, then refreshed roughly hourly**.

That is precisely what the gh#7362 reporter observed and was never told: *"I don't see these values
getting updated, even if we wait minutes. The rtt seems to be set when the connection opens and then
not again thereafter."*

**MQTT connections never get an RTT ping at all** (`client.go:2671–2673`):

```go
2671:	func (c *client) sendRTTPingLocked() bool {
2672:		if c.isMqtt() {
2673:			return false
```

**Observed**, three fresh loopback client connections:

```
cid=12 rtt=314µs uptime=40s
cid=20 rtt=286µs uptime=18s
cid=23 rtt=177µs uptime=2s
```

Hundreds of microseconds on loopback, where a real ping round trip is tens — consistent with these
being the **connect-time** estimate rather than a ping measurement.

## 3 · The advisory subjects, from the constants and from the wire

Every `JSAdvisory*Pre` constant at v2.14.6 (`jetstream_api.go:241–301`):

```
$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES      $JS.EVENT.ADVISORY.STREAM.CREATED
$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED           $JS.EVENT.ADVISORY.STREAM.DELETED
$JS.EVENT.ADVISORY.CONSUMER.MSG_TERMINATED      $JS.EVENT.ADVISORY.STREAM.UPDATED
$JS.EVENT.ADVISORY.CONSUMER.CREATED             $JS.EVENT.ADVISORY.STREAM.SNAPSHOT_CREATE
$JS.EVENT.ADVISORY.CONSUMER.DELETED             $JS.EVENT.ADVISORY.STREAM.SNAPSHOT_COMPLETE
$JS.EVENT.ADVISORY.CONSUMER.PAUSE               $JS.EVENT.ADVISORY.STREAM.RESTORE_CREATE
$JS.EVENT.ADVISORY.CONSUMER.PINNED              $JS.EVENT.ADVISORY.STREAM.RESTORE_COMPLETE
$JS.EVENT.ADVISORY.CONSUMER.UNPINNED            $JS.EVENT.ADVISORY.STREAM.LEADER_ELECTED
$JS.EVENT.ADVISORY.CONSUMER.LEADER_ELECTED      $JS.EVENT.ADVISORY.STREAM.QUORUM_LOST
$JS.EVENT.ADVISORY.CONSUMER.QUORUM_LOST         $JS.EVENT.ADVISORY.STREAM.BATCH_ABANDONED
```

### Run: two advisories produced and their subjects read off the wire

Server: `listen 127.0.0.1:4281`, `http 8281`, JetStream on file storage. Stream `ORDERS` on
`orders.>`; consumer `shipping` pull, `--max-deliver 2 --ack explicit --wait 1s`; one message
published and fetched repeatedly with `--no-ack`, with `nats sub '$JS.EVENT.ADVISORY.>'` attached
throughout.

```
[#1] Received on "$JS.EVENT.ADVISORY.API"
[#2] Received on "$JS.EVENT.ADVISORY.API"
[#3] Received on "$JS.EVENT.ADVISORY.API"
[#4] Received on "$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping"
{"type":"io.nats.jetstream.advisory.v1.max_deliver","id":"9lWb25w5SokA1gpeK2wgeB","timestamp":"2026-08-31T22:39:02.825838Z","stream":"ORDERS","consumer":"shipping","stream_seq":1,"deliveries":2}
```

Then a second consumer `naktest` (`--max-deliver 20 --wait 30s`), one message, fetched with `--nak`:

```
"$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED.ORDERS.naktest"
```

**Two results:**

1. **Docs issue #1 is now confirmed on the wire**, not only from a constant: the nak advisory really
   is published on `$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED.<stream>.<consumer>`, while
   `reference/jetstream/advisory/nak.md` documents `…CONSUMER.MSG_NAK.{stream}.{consumer}`.
2. **The max-deliveries subject carries `.CONSUMER.`** — `$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES`
   — which the prose of `learn/monitoring/advisories-and-events.md` states correctly and its own
   animation caption drops, three times, writing `$JS.EVENT.ADVISORY.MAX_DELIVERIES.ORDERS.shipping`.

**The advisory body carries two fields the docs' example omits**: `id` and `timestamp`. The docs show
`{type, stream, consumer, stream_seq, deliveries}`; the wire adds a NUID `id` and an RFC-3339
`timestamp`.

**`$JS.EVENT.ADVISORY.API` fires for ordinary API calls** — three of them here, from the stream and
consumer creates — so a subscription to the whole advisory tree is noisier than the chapter's example
suggests.

## What was not run

- **A leader-elected or quorum-lost advisory**: both need a clustered stream, and this was a single
  server.
- **`$SYS.ACCOUNT.<acct>.CONNECT` / `DISCONNECT` and `$SYS.SERVER.<id>.STATSZ`**: not captured; they
  need a system-account connection.
- **Profiling**: neither `nats server request profile` nor `prof_port` was exercised.
- **The Linux CPU path**: this machine is darwin, so the `pse_linux.go` arithmetic above is read, not
  observed. The `/varz` values quoted are from the darwin implementation.
- **Anything about cgroup CPU quotas.** The claim that `cores` ignores them rests on the gh#7483
  reporter's observation on Fargate plus the absence of any cgroup read in the source, not on a
  container run here.
