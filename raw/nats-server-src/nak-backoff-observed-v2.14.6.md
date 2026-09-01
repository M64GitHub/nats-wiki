<!-- source: nats-server v2.14.6 (homebrew binary) with nats CLI 0.4.0, run locally 2026-09-01 · plus
     server/consumer.go at tag v2.14.6 from raw.githubusercontent.com · verbatim transcript -->

# Does a consumer backoff slow a nak? — run on nats-server v2.14.6, 2026-09-01

The question `inbox/plan-delivery-timing-2026-09-01.md` step 2 exists to settle. Three public sources
disagree:

- `raw/nats-docs/learn/jetstream/acknowledgment.md` says **no**, three times (lines 42, 298, 586).
- `raw/synadia-blog/jetstream-reliable-delivery-dlq-replay.txt` says **yes** (lines 55, 65, 570).
- `raw/gh-discussions/gh-5631.md` reports a nak that did not redeliver immediately, and nobody ever
  replied to it.

The claim is behavioural, so it was **run**, not read — and then the source was read to explain what
the run showed. **Both answers are wrong**, and the real rule is stated at the end.

## What was run

```
$ nats-server --version
nats-server: v2.14.6
$ nats --version
0.4.0
```

`v2.14.6` is the version `wiki/concepts/ack-and-redelivery.md` cites, so the observations here are attributable to
the release the wiki already names.

Server config (`nak.conf`), started with `-DV` so every frame below is also in the server's own trace
log:

```
port: 14222
http: 18222
server_name: nak-probe
jetstream {
  store_dir: "<store>"
}
```

Stream, once, for every experiment:

```
nats stream add TEST --subjects='test.>' --storage=file --replicas=1 --defaults
```

**The instrument.** The `nats` CLI at v0.4.0 has **no delayed-nak flag** — `nats consumer next` offers
only `--ack`, `--nak` and `--term` — so a nak carrying a delay cannot be sent from the CLI at all.
`nats-probe-client.py` in this directory is a ~90-line stdlib-only NATS client written for these runs:
it connects, subscribes, issues `$JS.API.CONSUMER.MSG.NEXT` pull requests, and publishes the raw ack
payloads (`+ACK`, `-NAK`, `-NAK {"delay":<ns>}`) to the `$JS.ACK.…` reply subject of a delivered
message, recording a monotonic timestamp for each delivery.

**A harness bug was caught and is recorded here on purpose.** The first run created every consumer
with **no filter subject** on a stream with subject `test.>`, so each consumer received *every*
experiment's messages and the delivery counts in the tables were a mix of several messages. The
symptom was a `tries` column reading `1, 1, 2` instead of `1, 2, 3`. Every table below carries the
**stream sequence** alongside `tries` for exactly that reason: if the sequence moves, the row is a
different message and the timing means nothing. All tables below are single-sequence.

## The consumers

Each experiment gets its own consumer **with its own filter subject**. Two shapes:

```
# no backoff
nats consumer add TEST <name> --pull --ack=explicit --max-deliver=10 --wait=<W> \
  --max-pending=1000 --filter=test.<n> --backoff=none --defaults

# with a backoff
nats consumer add TEST <name> --pull --ack=explicit --max-deliver=10 --wait=30s \
  --max-pending=1000 --filter=test.<n> \
  --backoff=linear --backoff-steps=3 --backoff-min=5s --backoff-max=20s --defaults
```

What the second one actually stores — note `ack_wait`, which was asked for as **30s**:

```
$ nats consumer info TEST c_e11 --json | …
c_e11 filter= test.e11 ack_wait= 5.0 backoff= [5.0, 10.0, 15.0]
```

`--backoff-steps=3 --backoff-min=5s --backoff-max=20s` produces **5s, 10s, 15s** — the maximum is not
one of the steps. Recorded as an observation about nats CLI 0.4.0, not as a defect; no source states
what the generator should produce.

## E1 · control — bare nak, no backoff (`e1_plain`, ack_wait 30s)
### E1
    publish test.e1 -> {"stream":"TEST","seq":4}

| # | tries | stream seq | seconds since the previous delivery's answer (or delivery, if unanswered) | answer sent |
|---|---|---|---|---|
| 1 | 1 | 4 | — | `-NAK` |
| 2 | 2 | 4 | **0.00** | `-NAK` |
| 3 | 3 | 4 | **0.00** | `-NAK` |
| 4 | 4 | 4 | **0.00** | `+ACK` |

## E2 · bare nak on a consumer WITH backoff 5s/10s/15s (`e2_backoff`)
### E2
    publish test.e2 -> {"stream":"TEST","seq":5}

| # | tries | stream seq | seconds since the previous delivery's answer (or delivery, if unanswered) | answer sent |
|---|---|---|---|---|
| 1 | 1 | 5 | — | `-NAK` |
| 2 | 2 | 5 | **0.00** | `-NAK` |
| 3 | 3 | 5 | **0.00** | `-NAK` |
| 4 | 4 | 5 | **0.00** | `+ACK` |

## E3 · nak carrying its own 2s delay, backoff consumer (`e3_backoff`)
### E3
    publish test.e3 -> {"stream":"TEST","seq":6}

| # | tries | stream seq | seconds since the previous delivery's answer (or delivery, if unanswered) | answer sent |
|---|---|---|---|---|
| 1 | 1 | 6 | — | `-NAK {"delay":2000000000}` |
| 2 | 2 | 6 | **1.95** | `-NAK {"delay":2000000000}` |
| 3 | 3 | 6 | **6.95** | `+ACK` |

## E6 · `-NAK` with an explicit **zero** delay, no backoff, ack_wait 5s (`c_e6`)
### E6
    publish test.e6 -> {"stream":"TEST","seq":7}

| # | tries | stream seq | seconds since the previous delivery's answer (or delivery, if unanswered) | answer sent |
|---|---|---|---|---|
| 1 | 1 | 7 | — | `-NAK {"delay":0}` |
| 2 | 2 | 7 | **0.00** | `-NAK {"delay":0}` |
| 3 | 3 | 7 | **0.00** | `+ACK` |

## E7 · `-NAK {}` — an empty options object, no backoff, ack_wait 5s (`c_e7`)
### E7
    publish test.e7 -> {"stream":"TEST","seq":8}

| # | tries | stream seq | seconds since the previous delivery's answer (or delivery, if unanswered) | answer sent |
|---|---|---|---|---|
| 1 | 1 | 8 | — | `-NAK {}` |
| 2 | 2 | 8 | **0.00** | `-NAK {}` |
| 3 | 3 | 8 | **0.00** | `+ACK` |

## E8 · repeated 2s-delay naks, NO backoff, ack_wait 5s (`c_e8`)
### E8
    publish test.e8 -> {"stream":"TEST","seq":9}

| # | tries | stream seq | seconds since the previous delivery's answer (or delivery, if unanswered) | answer sent |
|---|---|---|---|---|
| 1 | 1 | 9 | — | `-NAK {"delay":2000000000}` |
| 2 | 2 | 9 | **1.95** | `-NAK {"delay":2000000000}` |
| 3 | 3 | 9 | **1.95** | `-NAK {"delay":2000000000}` |
| 4 | 4 | 9 | **1.95** | `+ACK` |

## E9 · bare `-NAK`, no backoff, ack_wait 5s — control for E6/E7 (`c_e9`)
### E9
    publish test.e9 -> {"stream":"TEST","seq":10}

| # | tries | stream seq | seconds since the previous delivery's answer (or delivery, if unanswered) | answer sent |
|---|---|---|---|---|
| 1 | 1 | 10 | — | `-NAK` |
| 2 | 2 | 10 | **0.00** | `-NAK` |
| 3 | 3 | 10 | **0.00** | `+ACK` |

## E11 · four 2s-delay naks on a backoff consumer (backoff 5s/10s/15s) (`c_e11`)
### E11
    publish test.e11 -> {"stream":"TEST","seq":11}

| # | tries | stream seq | seconds since the previous delivery's answer (or delivery, if unanswered) | answer sent |
|---|---|---|---|---|
| 1 | 1 | 11 | — | `-NAK {"delay":2000000000}` |
| 2 | 2 | 11 | **1.95** | `-NAK {"delay":2000000000}` |
| 3 | 3 | 11 | **6.95** | `-NAK {"delay":2000000000}` |
| 4 | 4 | 11 | **11.95** | `-NAK {"delay":2000000000}` |
| 5 | 5 | 11 | **11.95** | `+ACK` |

## E12 · positive control — **no answer at all**, backoff 5s/10s/15s (`c_e12`)
If the backoff schedule is inert, this shows the plain ack_wait instead. Clock runs from delivery.
### E12
    publish test.e12 -> {"stream":"TEST","seq":12}

| # | tries | stream seq | seconds since the previous delivery's answer (or delivery, if unanswered) | answer sent |
|---|---|---|---|---|
| 1 | 1 | 12 | — | `None` |
| 2 | 2 | 12 | **5.00** | `None` |
| 3 | 3 | 12 | **10.00** | `None` |
| 4 | 4 | 12 | **15.00** | `+ACK` |

## E13 · a nak asking for **no** delay (`-NAK {"delay":0}`), backoff 5s/10s/15s (`c_e13`)
The client asks for an immediate redelivery and supplies the options object. Compare with E6,
which is the same answer on a consumer with no backoff.
### E13
    publish test.e13 -> {"stream":"TEST","seq":13}

| # | tries | stream seq | seconds since the previous delivery's answer (or delivery, if unanswered) | answer sent |
|---|---|---|---|---|
| 1 | 1 | 13 | — | `-NAK {"delay":0}` |
| 2 | 2 | 13 | **0.00** | `-NAK {"delay":0}` |
| 3 | 3 | 13 | **4.94** | `-NAK {"delay":0}` |
| 4 | 4 | 13 | **9.94** | `+ACK` |

## E14 · the blog post's consumer config, created through `$JS.API.CONSUMER.CREATE` (not the CLI)

Requested (the post's Go snippet, verbatim in JSON):
```
ack_wait: 30s   max_deliver: 5   backoff: [1s, 5s, 30s, 2m]   max_ack_pending: 1000
```

Stored by the server:
```
ack_wait: 1.0s   max_deliver: 5   backoff: [1.0, 5.0, 30.0, 120.0]
```

## E16 · does a delayed nak still hold its `max_ack_pending` slot? (`c_e16`, cap **2**, ack_wait 60s)

| step | what was asked | what came back |
|---|---|---|
| 1 | pull batch=2 | 2 messages, stream seq ['14', '15'] |
| 2 | nak both with a **30s** delay | (no server reply; a nak is fire-and-forget) |
| 3 | pull batch=2 again, while both naks sleep | **status `408 Request Timeout`** — no message |

## The same measurement from the server's own trace log

The client's clock is not the authority; the server was run with `-DV`, so every delivery and every
ack payload is in its trace. E11 (four 2s naks, backoff 5s/10s/15s), delivery frames only:

```
04:01:11.260918 ->> [MSG test.e11 1 $JS.ACK.TEST.c_e11.1.11.1.1788228071260743000.0 9]
04:01:11.261007 <<- MSG_PAYLOAD: ["-NAK {\"delay\":2000000000}"]
04:01:13.261377 ->> [MSG test.e11 1 $JS.ACK.TEST.c_e11.2.11.2.1788228071260743000.0 9]
04:01:13.262020 <<- MSG_PAYLOAD: ["-NAK {\"delay\":2000000000}"]
04:01:20.262592 ->> [MSG test.e11 1 $JS.ACK.TEST.c_e11.3.11.3.1788228071260743000.0 9]
04:01:20.263269 <<- MSG_PAYLOAD: ["-NAK {\"delay\":2000000000}"]
04:01:32.265327 ->> [MSG test.e11 1 $JS.ACK.TEST.c_e11.4.11.4.1788228071260743000.0 9]
04:01:32.266035 <<- MSG_PAYLOAD: ["-NAK {\"delay\":2000000000}"]
04:01:44.267235 ->> [MSG test.e11 1 $JS.ACK.TEST.c_e11.5.11.5.1788228071260743000.0 9]
```

nak → next delivery, to the millisecond: **2.000 · 7.000 · 12.000 · 12.001**. The client asked for
2 seconds every time.

E12, the positive control (no answer at all, same backoff):

```
04:01:44.325304 ->> [MSG test.e12 1 $JS.ACK.TEST.c_e12.1.12.1.1788228104324724000.0 9]
04:01:49.327520 ->> [MSG test.e12 1 $JS.ACK.TEST.c_e12.2.12.2.1788228104324724000.0 9]
04:01:59.327656 ->> [MSG test.e12 1 $JS.ACK.TEST.c_e12.3.12.3.1788228104324724000.0 9]
04:02:14.328897 ->> [MSG test.e12 1 $JS.ACK.TEST.c_e12.4.12.4.1788228104324724000.0 9]
```

**5.002 · 10.000 · 15.001** — the backoff schedule, exactly as documented, for `AckWait` timeouts.
So the schedule is not inert; E2's "no effect on a bare nak" is a real negative, not a broken setup.

## Why: the server source at v2.14.6

Three ranges of `server/consumer.go` at tag **v2.14.6** explain every number above.

**1 · A backoff silently overwrites `AckWait`** (`consumer.go:649–659`):

```go
	// Setup proper default for ack wait if we are in explicit ack mode.
	if config.AckWait == 0 && (config.AckPolicy == AckExplicit || config.AckPolicy == AckAll) {
		config.AckWait = JsAckWaitDefault
	}
	// If BackOff was specified that will override the AckWait and the MaxDeliver.
	if len(config.BackOff) > 0 {
		if pedantic && config.AckWait != config.BackOff[0] {
			return NewJSPedanticError(errors.New("first backoff value has to equal batch AckWait"))
		}
		config.AckWait = config.BackOff[0]
	}
```

with `JsAckWaitDefault = 30 * time.Second` (`consumer.go:572–573`). This is the **server**, not the
CLI: E14 sends the config straight to `$JS.API.CONSUMER.CREATE` and gets the same override. In
**pedantic** mode it is an error instead of a silent rewrite — nats CLI 0.4.0 exposes no `--pedantic`
flag on `nats consumer add`.

**2 · A nak with a delay backdates the pending timestamp by `AckWait`** (`consumer.go:3208–3242`):

```go
	// Check to see if we have delays attached.
	if len(nak) > len(AckNak) {
		arg := bytes.TrimSpace(nak[len(AckNak):])
		if len(arg) > 0 {
			var d time.Duration
			var err error
			if arg[0] == '{' {
				var nd ConsumerNakOptions
				if err = json.Unmarshal(arg, &nd); err == nil {
					d = nd.Delay
				}
			} else {
				d, err = time.ParseDuration(string(arg))
			}
			if err != nil {
				// Treat this as normal NAK.
				o.srv.Warnf("JetStream consumer '%s > %s > %s' bad NAK delay value: %q", …)
			} else {
				…
				o.removeFromRedeliverQueue(sseq)
				if p, ok := o.pending[sseq]; ok {
					// now - ackWait is expired now, so offset from there.
					p.Timestamp = time.Now().Add(-o.cfg.AckWait).Add(d).UnixNano()
					…
				}
				// Nothing else for use to do now so return.
				return
			}
		}
	}

	// If already queued up also ignore.
	if !o.onRedeliverQueue(sseq) {
		o.addToRedeliverQueue(sseq)
	}
```

Two branches, and **which one runs is decided by whether the payload has anything after `-NAK`**
(`AckNak = []byte("-NAK")`, `consumer.go:386`). A bare `-NAK` falls through to the redeliver queue —
immediate, no timer, no backoff. Anything after it, **including an empty `{}`**, takes the delay
branch, because `json.Unmarshal([]byte("{}"), &nd)` succeeds with `d == 0`.

**3 · The deadline the backdated timestamp is measured against is the backoff, not `AckWait`**
(`consumer.go:6052–6070`, inside `checkPending`):

```go
		elapsed, deadline := now-p.Timestamp, ttl
		if len(o.cfg.BackOff) > 0 {
			dc := int(o.rdc[seq])
			if dc < 0 {
				dc = 0
			}
			nbi := dc + 1
			if dc+1 >= len(o.cfg.BackOff) {
				dc = len(o.cfg.BackOff) - 1
				nbi = dc
			}
			deadline = int64(o.cfg.BackOff[dc])
			…
		}
		if elapsed >= deadline {
```

## The rule, stated

Put the three together. A nak carrying a delay `d`, on redelivery count `dc`, is redelivered when

```
now  ≥  (nak_time − AckWait + d) + BackOff[min(dc, len−1)]
```

and `AckWait` **is** `BackOff[0]`, because §1 made it so. So the wait a client actually gets is

```
effective wait  =  d  +  ( BackOff[min(dc, len−1)] − BackOff[0] )
```

Against the numbers, with `BackOff = [5s, 10s, 15s]` and `d = 2s`:

| redelivery count `dc` | `BackOff[dc] − BackOff[0]` | predicted | **observed (E11)** |
|---|---|---|---|
| 0 | 0s | 2s | **2.000** |
| 1 | 5s | 7s | **7.000** |
| 2 | 10s | 12s | **12.000** |
| 3 → capped at 2 | 10s | 12s | **12.001** |

and with `d = 0` (E13), predicted 0s · 5s · 10s, observed **0.00 · 4.94 · 9.94**.

With **no** backoff the extra term is zero and the client gets exactly what it asked for — E8's
`2s, 2s, 2s`.

## What each source got right and wrong

| claim | source | verdict at v2.14.6 |
|---|---|---|
| "A plain nak redelivers immediately" | docs, line 42 | **correct** (E1, E9: 0.00s) |
| "a configured backoff doesn't slow it" — of a **bare** nak | docs, lines 298, 586 | **correct** (E2: 0.00s with a 5s/10s/15s schedule) |
| the same sentence, of a nak carrying a delay | docs, lines 298, 586 | **wrong** — E11 turns a 2s delay into 12s, E13 turns *no* delay into 10s |
| "the consumer's BackOff schedule applies an escalating series of delays across successive redeliveries", offered as the answer to "how do I retry with a backoff? Negatively acknowledge it" | blog, line 570 | **wrong for a bare nak** (E2), **accidentally right for a delayed one**, and right for `AckWait` timeouts (E12) |
| `AckWait: 30s` alongside `BackOff: [1s, …]` in a copyable Go snippet | blog, lines 268–294 | **the server stores `ack_wait: 1s`** (E14) — a 30× shorter ack deadline than the code says |
| "the last interval repeats until the delivery bound is reached" | blog, line 240; docs | **correct** (`consumer.go:6060–6063`; E11 row 4) |
| `AckWait` default 30s | docs, line 586 | **correct** (`JsAckWaitDefault`, `consumer.go:573`) |

## The neighbour sweep

The rulebook requires the wrong page's siblings to be checked against the same authority. Every
timing claim in `learn/jetstream/acknowledgment.md` was checked — **five checked, one wrong**:

1. "A plain nak redelivers immediately" — **correct** (E1, E9).
2. "the CLI's `--nak` only asks for immediate redelivery" — **correct**; `nats consumer next` exposes
   `--ack`, `--nak`, `--term` and no delay flag at v0.4.0, and a bare `-NAK` is immediate.
3. "AckWait … the default is 30 seconds" — **correct** (`consumer.go:573`).
4. Backoff "reuses the last entry" past the end of the list — **correct** (`consumer.go:6060–6063`).
5. "it doesn't slow a nak" — **wrong** for a nak carrying a delay, which is the only kind of nak the
   sentence's own paragraph is about ("A delayed nak sets the wait one redelivery at a time…").

## What was NOT tested

- **Clustered consumers.** Everything here is R1 on a single server. `updateDelivered` replicates the
  backdated timestamp to followers; whether a leader change while a delayed nak is sleeping preserves
  the timing was not tested.
- **Push consumers.** Pull only.
- **Whether any client library sends `-NAK {}` for a plain nak.** E7 and E13 show what the *server*
  does with it; which clients emit it was not surveyed, and that is the missing half of gh#5631.
- **2.10.14**, the version in gh#5631. Only v2.14.6 was run; the code above is the 2.14.6 tag.
- **`nats-server -t`** on any of these configs, and pedantic mode, for which the CLI has no flag.

## Addendum — does a max-delivered message survive? (same session, 2026-09-01)

`nats-io/nats-server` discussion #7590 reports that the documented dead-letter recipe fails —
`nats stream get <stream> <seq>` returns `message not found` for the sequence the max-deliveries
advisory named — while a later commenter says it works. Run on **v2.14.6**, R1:

```
nats stream add WQ  --subjects='wq.>'  --retention=work   --discard=old
nats stream add LIM --subjects='lim.>' --retention=limits --discard=old
nats consumer add <stream> <name> --pull --ack=explicit --max-deliver=2 --wait=2s
```

One message published to each, then fetched with `--no-ack` until the deliveries were exhausted, with
`nats sub '$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.>'` attached:

```
[#1] Received on "$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.WQ.w"
{"type":"io.nats.jetstream.advisory.v1.max_deliver","id":"TMbth7XzlJOkyzkRhNWQTR",
 "timestamp":"2026-09-01T02:36:13.790078Z","stream":"WQ","consumer":"w","stream_seq":1,"deliveries":2}
```

and afterwards, on **both** streams:

```
$ nats stream get WQ 1
Item: WQ#1 received 2026-09-01 02:35:49.736858 +0000 UTC on Subject wq.a
work-payload

$ nats stream get LIM 1
Item: LIM#1 received 2026-09-01 02:35:49.747384 +0000 UTC on Subject lim.a
limits-payload
```

`nats stream info WQ` reports **2 messages** still stored. **The message survives max-deliver on a
WorkQueue stream at v2.14.6 R1**, and the advisory's `stream_seq` fetches it — the later commenter is
right.

**The reporter's failure was real on their version.** `nats-io/nats-server` issue
[#7817](https://github.com/nats-io/nats-server/issues/7817) — "Messages Lost with JetStream,
work-queue Retention and R3 on max-deliver reached [v2.12.4, v2.12.3]" — was opened 2026-02-11 and
closed 2026-02-18 by PR [#7845](https://github.com/nats-io/nats-server/pull/7845), *"[FIXED] Preserve
max delivered messages with WorkQueue retention"*. The **v2.12.5** release notes carry it: *"Ensure
that messages that have reached the max deliver state are preserved with the WorkQueue retention
policy (#7845)"*.

**Not tested:** the R3 case on any version, and 2.12.3/2.12.4 themselves. The run above is R1 on
2.14.6, which is after the fix.
