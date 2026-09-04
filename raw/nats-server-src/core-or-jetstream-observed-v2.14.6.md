<!-- observed run · nats-server v2.14.6 (`nats-server --version` → `nats-server: v2.14.6`), nats CLI 0.4.0, nats.go v1.53.1 and natscli v0.4.0 read at their tags · macOS 15 (darwin/arm64) · 2026-09-04 -->
# nats-server v2.14.6 observed — core NATS or JetStream: what the two publishes look like on the wire, what they cost, and what happens when a stream is laid over a core subject

Runs for step 7 of `inbox/plan-the-client-side-2026-09-03.md`, the evidence behind
`wiki/operations/core-or-jetstream.md`. The spec side is `raw/adr/ADR-22.md`; the docs side is
`raw/nats-docs/concepts/jetstream.md`, `raw/nats-docs/learn/core-nats.md` and
`raw/nats-docs/learn/jetstream/where-next.md`.

**The one-line result.** A JetStream publish *is* a core publish with a reply subject, and every
difference between the two follows from that: the round trip is the cost, the `PubAck` is the proof,
the 503 is the failure, and a stream that captures a subject somebody is already using for
request/reply will answer those requests itself.

Seven passes, all on one machine, all against the same binary:

| pass | script | what it does |
|---|---|---|
| A | `core-or-jetstream-runA.sh` | the same subject published both ways, watched by a raw client |
| B | `core-or-jetstream-runB.sh` | what the publisher learns when nothing captures the subject |
| B (2nd) | `core-or-jetstream-runB3.sh` | the cost: core, JetStream sync, JetStream async, memory stream |
| C | `core-or-jetstream-runC.sh` | does a core publisher outrun the stream's ingest |
| D | `core-or-jetstream-runD.sh` | a stream laid over a core request/reply subject |
| E | `core-or-jetstream-runE.sh` | the only stream on `>` the server accepts, and what it swallows |
| F | `core-or-jetstream-runF.sh` | the mixed design: a stream added under an unchanged publisher |
| G | `core-or-jetstream-runG.sh` | a leader step-down under both publishers at once (the lab, R3) |
| H | `core-or-jetstream-runH.sh` | the docs' own Acme example, both chapters' commands at once |

`core-or-jetstream-coj-raw.py` is the step-3 `core-delivery-raw.py`, unchanged. Configs are quoted
inline. Transcripts are the unedited originals in the maintainer's scratch
(`local/scratch/runs/core-or-jetstream/`, not public); everything quoted below is copied from them.

Single-server config (`core-or-jetstream-server.conf`) for A–F:

```
port: 14222
http: 18222
server_name: coj1
jetstream {
  store_dir: "<scratch>/store"
  max_memory_store: 1GB
  max_file_store: 5GB
}
```

G runs on the repo's lab, `bash tools/lab/cluster.sh up 3` (n1–n3, cluster `east`, ports 4291–4293,
system user `sys`/`sys`).

---

## A · The same subject, published two ways

Stream: `nats stream add ORDERS --subjects 'orders.>' --storage file --retention limits --replicas 1 --defaults`.

### A1 · what a raw client subscribed to `orders.>` sees

```
>> SUB orders.> 1
<< MSG orders.created 1 4 | payload: core\r\n
<< MSG orders.created 1 _INBOX.1txK6pvF28KZIqM5DTYvDe.jqAH1uoV 4 | payload: jets\r\n
```

The first line is `nats pub orders.created 'core'`; the second is `nats pub orders.created 'jets' -J`.
**The only difference on the wire is the reply subject.** Same verb, same subject, same payload
length. A JetStream publish is a core publish that asks for an answer.

The publishers printed:

```
05:53:30 Published 4 bytes to "orders.created"
--- jetstream ---
05:53:30 Published 4 bytes to "orders.created"
05:53:30 Stored in Stream: ORDERS Sequence: 2
```

### A2 · the stream keeps them identically

```
Messages: 2 · Bytes: 96 B · First Sequence: 1 · Last Sequence: 2
Item: ORDERS#1 … on Subject orders.created →  core
Item: ORDERS#2 … on Subject orders.created →  jets
```

`nats stream get ORDERS 3 --json` and `… 4 --json` for a later pair (`core-2` / `jets-2`):

```
{ "subject": "orders.created", "seq": 3, "data": "Y29yZS0y", "time": "2026-09-04T03:53:36.64492Z" }
{ "subject": "orders.created", "seq": 4, "data": "amV0cy0y", "time": "2026-09-04T03:53:36.655467Z" }
```

**No header, no marker, nothing that says which one asked for an ack.** Once stored, a message
published with `-J` and a message published without it are the same message. The difference is
entirely on the publisher's side: one of them knows.

---

## B · What the publisher learns

### B1 · a core publish nobody hears

```
05:54:00 Published 4 bytes to "nostream.x"
real 0.01
exit=0
```

`/varz` afterwards: `in_msgs 3 out_msgs 2 slow_consumers 0`. The message was counted in and not
counted out. The publisher was told nothing.

### B2 · a JetStream publish to a subject no stream captures

```
05:54:00 Published 4 bytes to "nostream.x"
nats: error: nats: no responders available for request
exit=1
elapsed 0.024s
```

**24 ms**, and the process exits non-zero. This is the 503 no-responders of `raw/adr/ADR-22.md`,
raised by the CLI as `nats.ErrNoResponders`. Note the ordering: the CLI prints `Published …` *before*
it has an answer (`natscli` v0.4.0 `cli/pub_command.go:277` precedes `:279`).

### B3–B7 · the cost of the round trip (`core-or-jetstream-runB3.sh`)

Streams `BENCH` (`bench.>`, file) and `MEMBENCH` (`mem.>`, memory), one client, 128 B, 200,000
messages each, same server, same laptop. Publisher-side rates as `nats bench` reports them:

| what | rate | latency (avg / P50 / P99) |
|---|---:|---|
| core publish (`nats bench pub bench.core`) | **2,882,347 msgs/s** (352 MiB/s) | 0.29 µs / 0.04 µs / 0.25 µs |
| JetStream **sync** publish (`bench js pub sync`) | **30,876 msgs/s** (3.8 MiB/s) | 32.33 µs / 28.87 µs / 72.45 µs |
| JetStream **async** publish (`bench js pub async`) | **366,110 msgs/s** (45 MiB/s) | 1,364.92 µs / 1,286.87 µs / 2,170.45 µs |
| JetStream async, **memory** stream | **591,419 msgs/s** (72 MiB/s) | 844.53 µs / 741.33 µs / 2,322.41 µs |
| core publish into a subject a stream **does** capture | **2,885,763 msgs/s** (352 MiB/s) | 0.30 µs / 0.04 µs / 0.20 µs |

These are one-laptop numbers and are quoted as **ratios, not capacities**: on this machine a
synchronous JetStream publish is ~93× slower than a core publish, an asynchronous one ~7.9×, and a
core publish is not slowed *at all* by the stream that captures it — the publisher pays nothing
because it waits for nothing. The core figure is a client-side publish rate into the socket, not an
end-to-end delivery rate; the JetStream figures are round trips and are end-to-end by construction.

**Not settled:** the `BENCH` message count read one second after the last publish (742,460) did not
reconcile with the 800,000 published into `bench.>` across B4–B8. Run C was written to settle whether
that is loss or lag; it is lag (see C1). The B8 count is therefore not evidence of anything and is
not quoted on any page.

---

## C · Does a core publisher outrun the stream?

`core-or-jetstream-runC.sh`, 100,000 core publishes at 2,714,916 msgs/s into `cap.x`, captured by a
file stream `CAP` on `cap.>`:

```
  t+1s stored: 100000
  t+2s stored: 100000
  t+3s stored: 100000
  t+4s stored: 100000
  t+5s stored: 100000
  expected: 100000
  varz: in_msgs 100007 slow_consumers 0
```

No loss, and no log line about one. `nats pub cap2.x --count 5000` into a second stream: 5000 stored.
**A core publisher into a captured subject loses nothing**; it simply is not told when the write
landed. The ingest was already complete at the first sample (t+1 s), so this run does not measure the
lag, only that it closes.

---

## D · A stream laid over a core request/reply subject

This is the finding the page is written around. A responder is running: `nats reply svc.echo 'pong'`.

### D1 · the control, no stream

```
05:56:37 Received with rtt 406.958µs
pong
```

### D2 · then `nats stream add SVC --subjects 'svc.>' …` and the same request

```
--- nats request svc.echo ping (one reply) ---
05:56:38 Received with rtt 276.917µs
{"stream":"SVC","seq":1}
```

**The requester got the stream's `PubAck` as its answer.** The responder's `pong` never reached it:
`nats request` takes the first reply and stops. Gathering everything until the deadline shows both:

```
--- nats request svc.echo ping --replies=0 ---
05:56:38 Received with rtt 335.291µs
{"stream":"SVC","seq":2}

05:56:38 Received with rtt 451.166µs
pong
```

The stream answers **first**, every time in these runs — 277 µs and 335 µs against the responder's
407 µs and 451 µs.

### D3 · on the wire

```
>> SUB _INBOX.rawcoj.1 9
>> PUB svc.echo _INBOX.rawcoj.1 4
>> ping
<< MSG _INBOX.rawcoj.1 9 24 | payload: {"stream":"SVC","seq":3}\r\n
<< MSG _INBOX.rawcoj.1 9 4  | payload: pong\r\n
```

Two `MSG` frames on one inbox. Nothing distinguishes them but their content: no header, no status.
A client that takes one reply takes the `PubAck`.

### D4 · and the stream kept the requests

```
1 Subjects in stream SVC   ·   svc.echo   3
```

Every request is now stored, including its payload. The stream has become a recording of a
request/reply conversation nobody asked it to record.

### D5 · the server's own rule about this

```
$ nats stream add EVERYTHING --subjects '>' --storage memory --retention limits --replicas 1 --defaults
nats: error: could not create Stream: capturing all subjects requires no-ack to be true (10052)
```

Still refused after the overlapping stream is deleted — it is not an overlap check. The rule is
`server/stream.go:2170–2196` at v2.14.6:

```go
// Check for trying to capture everything.
if subj == fwcs {
    if !cfg.NoAck {
        return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("capturing all subjects requires no-ack to be true"))
    }
    // Capturing everything also will require R1.
    if cfg.Replicas != 1 {
        return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("capturing all subjects requires replicas of 1"))
    }
}
// Also check to make sure we do not overlap with our $JS API subjects.
if !cfg.NoAck {
    for _, namespace := range []string{"$JS.>", "$JSC.>", "$NRG.>"} {
        if SubjectsCollide(subj, namespace) {
            // We allow an exception for $JS.EVENT.> since these could have been created in the past.
            if !subjectIsSubsetMatch(subj, "$JS.EVENT.>") {
                return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("subjects that overlap with jetstream api require no-ack to be true"))
            }
        }
    }
    if SubjectsCollide(subj, "$SYS.>") {
        if !subjectIsSubsetMatch(subj, "$SYS.ACCOUNT.>") {
            return StreamConfig{}, NewJSStreamInvalidConfigError(fmt.Errorf("subjects that overlap with system api require no-ack to be true"))
        }
    }
}
```

So the server refuses exactly the three cases where the acking stream would hijack a reply that the
server itself depends on — `>`, `$JS.>`/`$JSC.>`/`$NRG.>` and `$SYS.>` — and refuses nothing else.
**`svc.>` is not one of those cases**, which is why D2 is allowed and silent. `10052` is
`JSStreamInvalidConfigF`, whose description is `{err}`, so the code carries no information of its own.

---

## E · The only stream on `>` the server accepts

`nats stream add EVERYTHING --subjects '>' --storage memory --retention limits --replicas 1 --no-ack --defaults` — accepted.

### E2 · request/reply works again

```
pong
```

With `no_ack` the stream sends nothing back, so the responder's answer is the only reply. The hijack
in D is a consequence of acking, not of capturing.

### E4 · what one `>` stream swallowed from six commands

```
12 Subjects in stream EVERYTHING
_INBOX.9QhrHR9vpYuo9xPyXqFoAv.QmTpieYa         1
$SRV.PING.DEMO                                 1
DEMO.echo                                      1
_INBOX.5RHzlW1CLR2YJXiHdKNY3n.6enc0dxB         1
_INBOX.0OJp3zAObRIGm7Io2gTpc9.Lop88Ham         1
_INBOX.12v3NLpf1c8e4bCT14Sc0Y.5twUVPe4         1
svc.echo                                       1
_INBOX.DiEZPQaB9mTsi0RhjtnFQB.zkbLQ6ey         1
$JS.EVENT.ADVISORY.STREAM.CREATED.EVERYTHING   1
_INBOX.8BBUKNwsT060hMd9OJ4qsN.x3WCYB7S         1
$JS.EVENT.ADVISORY.API                         3
$JS.API.STREAM.INFO.EVERYTHING                 3
```

Every reply inbox, the services-framework ping, the JetStream API requests **about the stream
itself**, and the API advisories. Total after that handful of commands: **41 messages**.

### E5 · it grows when you look at it

A second `nats stream subjects` a moment later:

```
$JS.API.STREAM.INFO.EVERYTHING   6
$JS.EVENT.ADVISORY.API           6
```

Three more of each, from the two commands that asked. **Reading the stream writes to the stream.**

### E6 · and a JetStream publish into it can never succeed

```
05:57:20 Published 13 bytes to "cap.x"
nats: error: nats: timeout
elapsed 3.042s
```

Three seconds (the CLI's `--timeout=3s`), then a timeout — a `no_ack` stream never answers, so a
JetStream publish into it always waits out the deadline. (The `exit=$?` printed after this line in the
script is `tail`'s status, not the CLI's; the exit code was not measured.)

---

## F · The mixed design

### F1 · core only

Publishes `A B C D`; subscriber 1 is up for `A`, then leaves; `B` and `C` are published to nobody;
subscriber 2 arrives and gets `D`.

```
--- first subscriber saw ---   A
--- second subscriber saw ---  D
```

### F2 · add the stream; the publisher command does not change

`nats stream add ORDERS --subjects 'orders.>' …`, then the byte-identical
`nats pub orders.created 'E'` and `… 'F'` — no `-J`, no client change, nobody subscribed.

### F3 · one live core subscriber and one consumer, from the same publish

```
--- the core subscriber saw ---                       G
--- the consumer replays everything it captured ---   E F G
```

**One publish, two readers, two guarantees.** The live subscriber got `G` at-most-once; the pull
consumer replayed `E`, `F` and `G` and acked them.

### F4 · remove the stream; the core path is untouched

```
--- the core subscriber saw ---  H
--- and a JetStream publish now? ---
05:58:07 Published 1 bytes to "orders.created"
nats: error: nats: no responders available for request
```

Adding and removing the stream is invisible to a core publisher and a core subscriber, and decisive
for a JetStream one.

---

## G · A leader step-down under both publishers (R3, the lab)

`bash tools/lab/cluster.sh up 3`; `ORDERS` at `--replicas 3` on `orders.>`; leader `n2`. Two
publishers run for 12 s at ~20 ms intervals — one `nats pub orders.created x -J`, one plain
`nats pub orders.core x` — while the stream leader is stepped down at t≈4 s and the **meta** leader at
t≈7 s.

```
--- JetStream publisher ---
t+ 4.032s      14.0ms  ERR  05:58:40 Published 1 bytes to "orders.created" | nats: error: nats: no responders available for request
-- js publishes: ok=311 err=1
--- core publisher ---
-- core publishes: ok=312 err=0
```

- The stream leader's step-down cost the JetStream publisher **exactly one publish**, as a 503
  no-responders, 32 ms after the step-down command was issued. This is ADR-22's motivation, observed.
- **The meta leader's step-down cost nothing** — `05:58:43 Requesting leader step down of "n3" … New
  leader elected "n1"` produced no publish error. Stream publishes are served by the stream's leader,
  not the meta leader.
- The core publisher, on the same server through the same seconds, saw **nothing at all**. It cannot:
  it never asks.
- The stream ended on `n3` with **622 messages**. 311 acknowledged JetStream publishes plus 312 core
  publishes is 623. The one-message difference was not resolved — `stream info` was read immediately
  after the last publish — and nothing is claimed from it.

### G · what the CLI does not do

The 14.0 ms of the failed publish is the whole subprocess, including ~11 ms of process start (B3), so
**no retry happened**. `natscli` v0.4.0 does not use `js.Publish`; `cli/pub_command.go:279` is

```go
resp, err := nc.RequestMsg(msg, opts().Timeout)
```

a plain core request (the full range is in `raw/nats-go-src/jetstream-publish-v1.53.1.md`). ADR-22's
retry lives in the Go client and is skipped by the CLI, which is why
the error is `nats: no responders available for request` (`nats.ErrNoResponders`) rather than the
`nats: no response from stream` (`ErrNoStreamResponse`) a retried-and-exhausted `js.Publish` returns.

ADR-22's stated defaults do hold in **nats.go v1.53.1**, in both APIs:

```go
// js.go:233,236 and jetstream/publish.go:157,160
DefaultPubRetryWait = 250 * time.Millisecond
DefaultPubRetryAttempts = 2

// jetstream/publish.go:247-256
for r := 0; errors.Is(err, nats.ErrNoResponders) && (r < o.retryAttempts || o.retryAttempts < 0); r++ {
    select {
    case <-ctx.Done():
    case <-time.After(o.retryWait):
    }
    resp, err = js.conn.RequestMsgWithContext(ctx, m)
}
if err != nil {
    if errors.Is(err, nats.ErrNoResponders) {
        return nil, ErrNoStreamResponse
    }
```

---

---

## H · The docs' own example does this to itself

Run D used made-up subjects. Run H uses the documentation's, verbatim, in the order the documentation
teaches them: `learn/core-nats/request-reply.md` builds "an **inventory** service that answers that
question on the subject `orders.inventory.check`", `learn/core-nats/where-next.md` says the
`inventory` service is "still as you left [it]" and sends the reader on ("the JetStream deep dive …
resumes the same Acme ORDERS story right where you are now"), and
`learn/jetstream/your-first-stream.md`'s first command is
`nats stream add ORDERS --subjects "orders.>" --defaults`.

### H1 · the inventory service, before the stream

```
$ nats reply orders.inventory.check 'in stock: 42' &
$ nats request orders.inventory.check '{"sku":"ord_8w2k"}'
in stock: 42
```

### H2-H3 · then the JetStream chapter's first command, and the same request

```
$ nats stream add ORDERS --subjects "orders.>" --defaults
$ nats request orders.inventory.check '{"sku":"ord_8w2k"}'
{"stream":"ORDERS","seq":1}
```

Gathering every reply shows the responder is alive and simply lost the race:

```
{"stream":"ORDERS","seq":2}

06:13:41 Received with rtt 374.333micros
in stock: 42
```

### H4 · and the stream is recording the requests

```
1 Subjects in stream ORDERS
orders.inventory.check   2
```

Nothing in either chapter warns about this, the server raises no error, and the stream creation
succeeds. Recorded as `inbox/docs-issues.md` **#119**.

## What was not tested

- Any client but `nats` CLI 0.4.0 and the raw Python writer. The nats.go retry loop was **read**, not
  run; no run here observes a retry actually firing.
- The `no_ack` hijack across an account import, a leafnode or a gateway.
- Whether a *mirror* or a *source* of a stream over a request/reply subject behaves the same way
  (a mirror has no ingest subjects, so it should not, but it was not run).
- Backpressure on the asynchronous JetStream publisher. The async figures use whatever in-flight
  window `nats bench js pub async` defaults to; which of nats.go's two APIs the CLI's bench uses, and
  therefore whether that window is `defaultAsyncPubAckInflight = 4000` (`js.go:239`), was not checked.
- Anything at a scale larger than one laptop, one client and 200,000 messages. Every rate above is a
  ratio on one machine.
- Whether the 622/623 discrepancy in G is lag or loss.
- Whether every client library races the same way in H. The ordering (stream first) was consistent
  across five requests here, but nothing makes it a guarantee, and a client that gathers rather than
  taking the first reply sees both.
