# Server issues found while building this wiki

Behaviours of **`nats-server` itself** that this wiki found surprising, undocumented, or inconsistent
with its own conventions — recorded so they can be **asked upstream** on
`nats-io/nats-server`. This file is **not a wiki page** and it is deliberately **not**
`inbox/docs-issues.md`.

**Why the two are separate.** `docs-issues.md` runs on one rule: the **server is the authority**, so
every row there is *settled* — the docs say X, the server does Y, here is the line of code and here is
the run. A finding about the server itself inverts that. There is no higher authority to check it
against, so an entry here can only ever be **an observation plus a question**, never a verdict. Keeping
them in one file would quietly erode what makes the settled file trustworthy.

So the discipline here is different:

- **No `wrong-value`.** Nothing in this file is called an error. The kinds are:
  - **`unexpected`** — the server does something a careful reader of the public sources would not
    predict, and the consequence is operator-visible.
  - **`inconsistent`** — the server contradicts itself, or one part of it contradicts a convention the
    rest follows.
  - **`undocumented`** — a behaviour with real consequences that no public source describes. (When the
    *documentation gap* is the point, the row belongs in `docs-issues.md`; when the **behaviour** is
    the point, it belongs here. A finding can legitimately produce a row in each — see SI-1.)
- **Every entry states what would settle it.** We cannot. That field is the question we are actually
  asking upstream, and it is required.
- **Every entry carries a reproduction that runs**, with the exact config and the exact output, and
  names the release it was run on.
- **Every entry states what was *not* tested.** An unasked question is part of the report.

`★` marks an entry with a **data-integrity or security consequence**, not merely a surprise.

| # | finding | kind | severity | run on | upstream |
|---|---|---|---|---|---|
| SI-1 | The leafnode JetStream deny list names `$OBJ.>`, but the object store's subjects are `$O.<bucket>.C.>` and `$O.<bucket>.M.>` — so object-store data crosses a JetStream domain boundary that KV data does not, and two same-named buckets on either side of a leafnode silently converge | inconsistent | ★ high | v2.14.6 | not filed |
| SI-2 | A nak that carries a delay is redelivered after `delay + (BackOff[dc] − BackOff[0])`, not after `delay`: `processNak` backdates the pending timestamp by `o.cfg.AckWait` while `checkPending` measures it against the attempt's backoff entry. A client asking for 2s gets 12s; a client asking for **0s** gets 10s. A **bare** `-NAK` is unaffected, and `-NAK {}` is not bare | unexpected | high | v2.14.6 | not filed |
| SI-3 | A `*` inside a subject token — `orders.1*` — is a wildcard to the subject tree and a literal to the sublist: a consumer filtered on it reports `num_pending` for every subject beginning `orders.1`, and `STREAM.INFO`'s `subjects_filter` lists those subjects, while delivery and a direct get match the literal token and find nothing. The consumer shows a backlog it can never deliver | inconsistent | low | v2.14.6 | not filed |
| SI-4 | The `client_connect` event's `timestamp` is UTC (`…Z`) while the `client_disconnect` event's carries the server's local offset (`…+02:00`) — `accountConnectEvent` stamps `time.Now().UTC()`, `accountDisconnectEvent` the `now` its caller passes; the auth-error twin of the same body is UTC again | inconsistent | low | v2.14.6 | not filed |
| SI-5 | After `--signal ldm` on a server with no clients, `$SYS.SERVER.<id>.LAMEDUCK` arrived and the server exited within a millisecond, but no `$SYS.SERVER.<id>.SHUTDOWN` reached a subscriber on a peer; a plain SIGTERM on the same server did deliver `SHUTDOWN` | unexpected | low | v2.14.6 | not filed |
| SI-6 | Config mode accepts `share: true` on a **stream** import and ignores it (`nats-server -t`: valid, exit 0; the parser applies `share` to service imports only), while the account-JWT library rejects the same import with `sharing information (for latency tracking) is only valid for services` — the two modes disagree on whether the key is an error | inconsistent | low | v2.14.6 | not filed |
| SI-8 | With a leafnode holding *n* members of a queue group, a publisher on the hub sees the hub's own members split unevenly: the member that follows the leaf's *n* entries in the match list receives its own share plus the leaf's — two hub members and two leaf members split 148 / 52, 89 / 311, 297 / 103 and 302 / 98 over four runs; two and one 137 / 263; three and two 70 / 75 / 255; the control with no leaf member 196 / 204. The leaf's members receive nothing while the hub has one | unexpected | medium | v2.14.6 | not filed |
| SI-7 | A `pedantic` client publishing to a subject that fails `IsValidLiteralSubject` — `orders.*.created` — receives `-ERR 'Invalid Publish Subject'` **and the message is delivered anyway**: both `processPub` and `processHeaderPub` send the error and return `nil`, so the publish is routed as a literal subject and wildcard subscribers get it. The error reads as a refusal and is not one | unexpected | low | v2.14.6 | not filed |
| SI-9 | A **push consumer delivers nothing** when the only interest on its deliver subject is a **wildcard** subscription that covers it: `Sublist.registerNotification` counts interest only for a subscriber whose subject is *literally equal* to the deliver subject. A second stream subscribed on `copy.>` never wakes a consumer delivering to `copy.evt` — 0 of 1,000 messages, `num_pending` stuck at 1,000, nothing logged — and one plain `nats sub copy.evt` releases all of them at once | unexpected | medium | v2.14.6 | not filed |

---

## SI-1 · Object-store subjects cross a leafnode where KV subjects do not

**The observation.** With two servers joined by a leafnode in a **non-system account** and carrying
**different** JetStream domains — the configuration that logs
`JetStream using domains: local "leaf", remote "hub"` and merges `denyAllClientJs` both ways —
`$KV.>` traffic is denied across the link and `$O.…` traffic is not.

**Why.** `server/jetstream_api.go:323–324` at v2.14.6:

```go
var denyAllClientJs = []string{jsAllAPI, "$KV.>", "$OBJ.>"}
var denyAllJs = []string{jscAllSubj, raftAllSubj, jsAllAPI, "$KV.>", "$OBJ.>"}
```

and the domain mapping table at `:347` carries `"$OBJ.>": "$OBJ.>"`.

But an object-store bucket lives on **`$O.<bucket>.C.>`** (chunks) and **`$O.<bucket>.M.>`**
(metadata) — per ADR-20, per `learn/object-store/under-the-hood.md`, and per
`nats stream info OBJ_<bucket>` on the running server. `$OBJ.>` is a literal first token and matches
none of them. **`grep -rn '\$OBJ' ` over the 861-page docs tree returns nothing**; the prefix appears
in the server and nowhere in the documentation.

**The consequence, measured.** Two object buckets of the same name, in the same account, on either
side of such a link **converge**. One 600 KiB `nats object put` on the leaf only:

| | leaf `OBJ_SHARED` | hub `OBJ_SHARED` |
|---|---|---|
| before | 0 msgs / 0 bytes | 0 msgs / 0 bytes |
| after the leaf-side put | 6 msgs / 615,040 bytes | **6 msgs / 615,040 bytes** |

and the hub then lists an object nobody put there, with both subject spaces present:

```
nats object ls SHARED
│ payload.bin │ 600 KiB │ 2026-08-31 23:39:15 │

nats stream subjects OBJ_SHARED
│ $O.SHARED.M.cGF5bG9hZC5iaW4=       │ 1     │
│ $O.SHARED.C.kVUgvDAOdPXVz64dqECKBD │ 5     │
```

It is a complete, gettable object on a server that was never asked to store it. **Nothing is logged on
either side**, and the put looks entirely normal from the leaf.

**The control.** Same servers, same account, same procedure with a KV bucket: `kv put CONF k1` on the
leaf left the hub's `KV_CONF` at **0 msgs**, and `nats kv get CONF k1` on the hub returned
`nats: error: nats: key not found`. A second control confirmed the link was up and the account shared:
`nats pub demo.x` on the leaf reached a `demo.>` subscriber on the hub.

**Reproduction.** Full configs, all four experiments and their verbatim output are in
`raw/nats-server-src/object-store-across-leafnode-observed-v2.14.6.md`. In outline: a hub with
`jetstream { domain: hub }` and `leafnodes { port: 7451 }`, a leaf with `jetstream { domain: leaf }`
and a remote bound to a shared non-system account `APP`, `jetstream: enabled` on that account **on both
servers** (without it every JetStream call fails with `could not pick a Stream to operate on`), then
`nats object add SHARED` on each and one put on the leaf.

**What would settle this.** One question, and we cannot answer it:

> **Is `$OBJ.>` in `denyAllClientJs` / `denyAllJs` intended to be the object store's subject space?**

- If **yes**, it does not match `$O.` and object-store data is crossing a boundary it was meant not
  to — a defect with a data-integrity consequence.
- If **no** — if `$OBJ` is a legacy, reserved, or planned prefix — then the object store is
  *deliberately* not isolated by a JetStream domain, which is a documentation gap rather than a
  defect, and one worth stating loudly because the KV case sets the opposite expectation.

The source comment at `jetstream_api.go:330–337` explains **why** `$KV` and `$OBJ` were made
independent subject spaces ("For optics $KV and $OBJ where made to be independent subject spaces")
but never says which prefix the object store actually uses.

**Searched and not found.** No public issue, discussion or ADR read so far mentions `$OBJ` against
`$O.`, and no doc page states what a JetStream domain does to either store.

**What was not tested.**

- The **same-domain** case, and the **system-account** (`denyAllJs`) case.
- **Gateways**, and superclusters.
- Clients other than the `nats` CLI. All use the same subjects, so the result should not depend on the
  client — but that is reasoning, not observation.
- Whether anything **cleans up** the converged bucket, or what happens when both sides write
  concurrently to the same object name.

**Where the wiki records this:** `wiki/concepts/object-store.md` — *A bucket is not isolated by a
JetStream domain*; `wiki/concepts/jetstream-domain.md`; `wiki/concepts/leafnode.md`;
`wiki/gotchas/streams-not-visible-across-a-leafnode.md`;
`wiki/summaries/s-nats-server-object-store-leafnode.md`. The **documentation** half — that no page
states what a domain does to either store — is `inbox/docs-issues.md` **#35**.

---

## SI-2 · A delayed nak waits longer than the delay it was given, when the consumer has a backoff

**The observation.** On a pull consumer with `BackOff = [5s, 10s, 15s]`, a nak carrying an explicit
**2-second** delay was redelivered after **2.000 s, 7.000 s, 12.000 s, 12.001 s** on successive
attempts — measured from the server's own trace log, run on **v2.14.6**. The client asked for two
seconds every time. On the same consumer, a nak carrying an explicit **zero** delay
(`-NAK {"delay":0}`) was redelivered after **0.00 s, 4.94 s, 9.94 s**.

A **bare** `-NAK` on the same consumer is unaffected — 0.00 s every time.

**Why.** Three places in `server/consumer.go` at tag v2.14.6 compose into it.

1 · A backoff **overwrites** `AckWait` at creation (`consumer.go:653–659`):

```go
	// If BackOff was specified that will override the AckWait and the MaxDeliver.
	if len(config.BackOff) > 0 {
		if pedantic && config.AckWait != config.BackOff[0] {
			return NewJSPedanticError(errors.New("first backoff value has to equal batch AckWait"))
		}
		config.AckWait = config.BackOff[0]
	}
```

2 · A delayed nak backdates the pending timestamp by that `AckWait` (`consumer.go:3229–3231`):

```go
				if p, ok := o.pending[sseq]; ok {
					// now - ackWait is expired now, so offset from there.
					p.Timestamp = time.Now().Add(-o.cfg.AckWait).Add(d).UnixNano()
```

3 · But `checkPending` measures the elapsed time against **the attempt's backoff entry**, not against
`AckWait` (`consumer.go:6052–6066`):

```go
		elapsed, deadline := now-p.Timestamp, ttl
		if len(o.cfg.BackOff) > 0 {
			dc := int(o.rdc[seq])
			…
			deadline = int64(o.cfg.BackOff[dc])
		}
		if elapsed >= deadline {
```

The comment in §2 — *"now - ackWait is expired now, so offset from there"* — is exact only when the
deadline in §3 is also `AckWait`, which is true only for a consumer with **no** backoff. With one, the
message is redelivered when

```
now  ≥  (nak_time − BackOff[0] + d) + BackOff[min(dc, len−1)]
```

so the wait a client receives is `d + (BackOff[min(dc, len−1)] − BackOff[0])`. Predicted 2 · 7 · 12 · 12
against `[5s, 10s, 15s]`; observed 2.000 · 7.000 · 12.000 · 12.001.

**Which naks take this path.** `processNak` branches on `len(nak) > len(AckNak)` — anything after the
four bytes `-NAK`. An empty options object counts: `json.Unmarshal([]byte("{}"), &nd)` succeeds with
`d == 0`, so **`-NAK {}` is not treated as a bare nak** and picks up the backoff term above. A client
library that always serialises its nak options therefore gets different timing from one that omits
them, for the same API call.

**The reproduction.** `raw/nats-server-src/nak-backoff-observed-v2.14.6.md` — thirteen runs on the
v2.14.6 binary with nats CLI 0.4.0, 2026-09-01, including the positive control (E12: no answer at all
gives 5.00 · 10.00 · 15.00, the documented schedule) that rules out an inert backoff, and the
no-backoff control (E8: three 2s naks give 1.95 · 1.95 · 1.95). The instrument is
`raw/nats-server-src/nats-probe-client.py`, written because **nats CLI 0.4.0 cannot send a delayed
nak at all** — `nats consumer next` offers `--ack`, `--nak` and `--term` and no delay flag.

**What would settle it.** One question, for `nats-io/nats-server`:

> Is a delayed nak's delay meant to be honoured exactly? If it is, the backdating in `processNak`
> should offset by the same deadline `checkPending` will apply (`BackOff[dc]`) rather than by
> `cfg.AckWait`. If it is *not* — if the backoff is deliberately additive to a nak delay — then the
> documented rule that a backoff "doesn't slow a nak" is the thing that needs changing, and
> `-NAK {}` still deserves to behave like `-NAK`.

**Searched and not found.** No public issue, discussion or ADR read so far describes the interaction
of `BackOff` with a delayed nak. `learn/jetstream/acknowledgment.md` states the opposite three times
(`inbox/docs-issues.md` **#38**), and the one blog post that claims backoff applies to naks claims it
for the *bare* nak, which is the case where it does not (**#39**).

**What was not tested.**

- **Clustered consumers.** All runs are R1 on one server. `updateDelivered` replicates the backdated
  timestamp to followers; a leader change while a delayed nak sleeps was not tested.
- **Push consumers**, and `AckAll` / `AckNone` policies. Pull with `AckExplicit` only.
- **A decreasing backoff schedule**, where `BackOff[dc] − BackOff[0]` would be negative and the
  redelivery would presumably fire *before* the requested delay. The CLI's generator only produces
  increasing schedules; the API would accept a decreasing one.
- **Which client libraries send `-NAK {}`** rather than a bare `-NAK` for a plain nak. That is the
  missing half of `nats-io/nats-server` discussion #5631, which reports exactly this symptom on
  2.10.14 with the C# client and has never been answered.
- **2.10.14 itself.** Only v2.14.6 was run.

**Where the wiki records this:** `wiki/concepts/ack-and-redelivery.md` — *What a delayed nak actually
waits*. The **documentation** half — that the docs state a flat independence which does not hold — is
`inbox/docs-issues.md` **#38**, and the blog post that states the opposite error is **#39**.

## SI-3 · A `*` inside a token counts as a wildcard in the subject tree and as a literal everywhere else

**The observation.** On **v2.14.6** (nats CLI 0.4.0), a five-message stream `PT` on `pt.>` holding
`pt.10`, `pt.11`, `pt.20`, `pt.3`, `pt.100`. A pull consumer with `filter_subject: pt.1*`:

```
filter pt.1*   num_pending at create=3    next --count 5 got: <nothing, timeout>   after: pending/delivered=0/0
filter pt.*    num_pending at create=5    … after: pending/delivered=0/5
filter pt.10   num_pending at create=1    … after: pending/delivered=0/1
filter pt.1>   num_pending at create=0    … after: pending/delivered=0/0
$ nats stream subjects PT 'pt.1*'   →   3 Subjects in stream PT
$ nats stream get PT --last-for 'pt.1*'   →   nats: error: could not retrieve PT#-1: no message found (10037)
```

`num_pending` says **3** (`pt.10`, `pt.11`, `pt.100` — the subjects whose second token *begins with*
`1`), the subjects report says 3, delivery delivers **nothing** and the pending count then drops to
0; a direct get for the same string finds no message. `pt.1>` is a literal on both sides. First seen
at scale: a consumer filtered on `card.1*` over a 1,200,000-subject stream reported 400,000 pending
(the 200,000 subjects `card.1000000`–`card.1199999` × 2 messages) and delivered none, which made
`nats bench js consume` wait forever (`raw/nats-server-src/stream-scale-observed-v2.14.6.md`, run E
§E5 and the *SI probe*).

**Why.** Two matchers disagree about a `*` that is not a whole token.

1 · The sublist and the delivery path use `subjectHasWildcard` (`server/sublist.go:1172–1183` at
v2.14.6), for which `*` and `>` are wildcards only when preceded by the start or a `.` and followed
by the end or a `.` — so `pt.1*` is literal, and `IsValidSubject` (`:1209–1246`) accepts it as such,
which is why the consumer is created.

2 · `NumPending` counts through the per-block subject tree (`server/filestore.go:4322`,
`mb.fss.Match(stringToBytes(filter), …)`), and the `subjects_filter` report through `fs.psim`. The
tree's `genParts` (`server/stree/parts.go:23–75`) correctly leaves a mid-token `*` inside its literal
part — but `matchParts` (`:79–147`) compares a part against a stored fragment and, when the fragment
is shorter than the part, **truncates the part to what was consumed** (`:128–138`) and carries the
rest, `*`, into the next node. At the next node a one-byte part equal to `*` is taken as the
partial-wildcard placeholder (`:94–106`) and matches the rest of the token. So `pt.1*` becomes
`pt.1` followed by anything up to the next `.`.

**What would settle it.** One question, for `nats-io/nats-server`:

> Is a `*` (or `>`) inside a token meant to be accepted in `filter_subject` / `filter_subjects` and
> `subjects_filter`? If it is a literal, `stree.matchParts` should not promote a truncated literal
> part to a wildcard, so that `num_pending` and the subjects report agree with delivery; if it is
> meant to be rejected, consumer creation should refuse it the way it refuses an empty filter, and
> `IsValidSubject` is the wrong test for a filter.

**Searched and not found.** GitHub issues in `nats-io/nats-server` for "wildcard inside token",
"stree partial match" and "num_pending wrong filter" on 2026-09-02: nothing on this. The docs'
subject rules (`concepts/subjects.md`) say wildcards are whole tokens and say nothing about what a
`*` inside a token means to a filter.

**What was not tested.** `filter_subjects` (the multi-filter form) and `LoadNextMsgMulti`'s path;
the memory store; a `*` inside the *first* token; whether the same tree matcher is reached by
`DIRECT.GET` with `multi_last`; anything before v2.14.6.

**Where the wiki records this:** `wiki/summaries/s-nats-server-stream-scale-observed.md` — *Found on
the way*; the run in `raw/nats-server-src/stream-scale-observed-v2.14.6.md`. No reader page yet:
the trigger is a filter that is not a NATS wildcard, so it belongs in a page on subject filters when
one exists.

## SI-4 · Connect events are stamped in UTC, disconnect events in local time

**The observation.** On **v2.14.6** (nats CLI 0.4.0, a standalone server, system-account subscriber on
`$SYS.>`; `raw/nats-server-src/system-subjects-observed-v2.14.6.md` §3–4):

```
$SYS.ACCOUNT.APP.CONNECT     "timestamp":"2026-09-03T01:47:27.113195Z"
$SYS.ACCOUNT.APP.DISCONNECT  "timestamp":"2026-09-03T03:47:29.141611+02:00"
$SYS.SERVER.<id>.CLIENT.AUTH.ERR   "timestamp":"2026-09-03T01:47:30.189954Z"      (a client_disconnect body)
$SYS.ACCOUNT.$G.DISCONNECT   "timestamp":"2026-09-03T03:47:30.189966+02:00"      (the same event)
```

The `client.start` field inside the same bodies is local time in both. The `server.time` field is
UTC in both.

**Why.** `accountConnectEvent` builds its `TypedEvent` with `time.Now().UTC()`;
`accountDisconnectEvent(c *client, now time.Time, reason string)` uses the `now` it is handed, which
its callers take from `time.Now()` without `.UTC()`; `sendAuthErrorEvent` uses `time.Now().UTC()`
(`server/events.go:2551–2720` at v2.14.6, quoted in `raw/nats-server-src/system-subjects-v2.14.6.md`).
Both are RFC 3339 and parse to the same instant, so nothing is wrong; a consumer that compares or
sorts the strings, or that assumes the `Z` form, is surprised.

**What would settle it.** Whether the difference is intended, and whether the `TypedEvent.Time`
of every `$SYS` event should be normalised to UTC as the JetStream advisories' are.

**Searched and not found.** GitHub issues in `nats-io/nats-server` for "disconnect event timestamp
timezone" (no result) and "client_disconnect timestamp UTC" (no result) — none about the zone.

**What was not tested.** Whether a server started with `TZ=UTC` shows the difference (it would not,
which is presumably why it goes unnoticed in containers); the leafnode and route disconnect paths.

## SI-5 · No `SHUTDOWN` event after a lame-duck exit with no clients

**The observation.** On **v2.14.6**, lab cluster n1–n3, `nats sub '$SYS.>'` as the system user on n1
(`raw/nats-server-src/system-subjects-observed-v2.14.6.md` §7). `nats-server --signal ldm=<n2 pid>`
at 03:50:54.077:

```
[#127] Received on "$SYS.SERVER.<n2 id>.LAMEDUCK"   {"name":"n2",…,"time":"2026-09-03T01:50:54.084721Z"}
n2.log: 03:50:54.084705 [INF] Entering lame duck mode, stop accepting new clients
        03:50:54.085188 [INF] Server Exiting..
```

No `$SYS.SERVER.<n2 id>.SHUTDOWN` reached the subscriber (none in the whole log). The restarted n2,
sent a plain SIGTERM at 03:52:27, produced `[#187] Received on "$SYS.SERVER.<n2 id>.SHUTDOWN"`.

**Why, as far as the source says.** `sendShutdownEvent` (`events.go:689–707`) pushes the event as
the last message of the system send queue and sets `s.sys.sendq = nil`; with no clients the
lame-duck drain finishes in under a millisecond and the routes close on `Server Exiting`. Whether the
queued message was flushed to the route before it closed is what this run cannot see. The lame-duck
event itself (`sendLDMShutdownEventLocked`, `:679`) arrived.

**What would settle it.** Whether `SHUTDOWN` is expected to be delivered after a lame-duck exit
(with and without clients), or whether `LAMEDUCK` is the only event an operator should rely on for
a drained server.

**Searched and not found.** GitHub issues in `nats-io/nats-server` for "SHUTDOWN event lame duck"
(no result) and "system event SHUTDOWN not received" (no result) — nothing about a missing shutdown event.

**What was not tested.** A lame-duck exit with connected clients (a drain of `lame_duck_duration`);
whether `SHUTDOWN` arrives on the server's own local system subscriber rather than a peer's; a
standalone server.

## SI-6 · `share` on a stream import: a config-mode no-op, a JWT-mode error

**The observation.** On **v2.14.6**, `raw/nats-server-src/share-import-observed-v2.14.6.md` scene D
(`share-import-run.sh`):

```
accounts {
  SVC: { exports: [ { stream: "ev.>" } ] }
  APP: { imports: [ { stream: { account: SVC, subject: "ev.>" }, share: true } ] }
}
```

```
$ nats-server -t -c d.conf
nats-server: configuration file d.conf is valid (sha256:58b2e1d8…)
exit: 0
```

The key is silently dropped: `parseImportStreamOrService` assigns `share` to `curService` only
(`opts.go:4505–4509`, `raw/nats-server-src/service-imports-v2.14.6.md`). The same import written into
an account JWT fails validation — `Import.Validate`: "sharing information (for latency tracking) is
only valid for services" (jwt v2.8.2 `imports.go:88–90`, `raw/jwt-src/imports-exports-activation-v2.8.2.md`)
— and `nsc add import --share` on a stream refuses with "only services can set the share property".

**What would settle it.** Whether config mode should reject `share` on a stream import the way the JWT
library does (a parse error, like `allow_trace` on a service import already is: "Detected allow_trace
directive on a non-stream"), or whether ignoring unknown-for-this-type keys is the intended
config-mode behaviour.

**Searched and not found.** GitHub issues in `nats-io/nats-server` for "share stream import" and
"share latency import config" (`gh search issues`, 2026-09-03) — no result either way.

**What was not tested.** Whether a *reload* with the key behaves the same (only `-t` and a fresh start
were run); other keys that are valid on one import type only.

**Consequence.** Low: an operator who puts `share` on a stream import gets no latency data and no
error. No data-integrity or security effect. Related: docs issue #79 (the key is documented nowhere).

## SI-7 · Pedantic mode sends `-ERR 'Invalid Publish Subject'` and delivers the message anyway

**The observation.** On **v2.14.6**, `raw/nats-server-src/core-delivery-observed-v2.14.6.md` run C3
(`core-delivery-run.sh`, `core-delivery-raw.py`), a bare server with a `nats sub 'orders.>'` tap:

```
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": true, "headers": true}
>> PUB orders.*.created 0
>> (empty line)
>> PING
<< -ERR 'Invalid Publish Subject'
<< PONG
-- socket still open after 1.0s
orders.> tap:
[#1] Received on "orders.*.created"
```

The same publish from a non-pedantic connection (run C2) is delivered with no error, to `orders.>` and to a
subscriber on `orders.*.created`, whose `*` matches the literal `*` token. **The code**: `processPub`
(`client.go:2984–2986`) and `processHeaderPub` (`:2931–2933`) run
`if c.opts.Pedantic && !IsValidLiteralSubject(...) { c.sendErr("Invalid Publish Subject") }` and then
`return nil`, so the parser goes on to route the message (`raw/nats-server-src/core-delivery-v2.14.6.md`).
`defaultOpts` sets `Pedantic: true` (`:706`), but the value is overwritten by the client's `CONNECT`; nats.go
sends `false` unless its `Pedantic` option is set, so the case is reached only by a client that opts in.

**What would settle it.** Whether `Invalid Publish Subject` in pedantic mode is meant as a warning (the
protocol reference describes `pedantic` as "Turns on additional strict format checking, e.g. for properly
formed subjects" and lists no such error) or as a refusal — in which case the publish should not be
routed. Every other `-ERR` the server sends on a `PUB` (`Maximum Payload Violation`, the permission
violations) accompanies a message that is **not** delivered.

**Searched and not found.** `Invalid Publish Subject` occurs in none of the 861 pages of the docs mirror
(`grep -rn` on 2026-09-03), in none of the 484 `nats-io/nats-server` discussions' titles, bodies, comments
or replies (`local/scratch/gh-index/threads-2026-09-03.md`), and `reference/protocols/client.md`'s `-ERR`
table does not list it.

**What was not tested.** Whether any official client sets `pedantic: true` by default (the CLI does not);
a pedantic `HPUB`; whether a pedantic `SUB` differs from a non-pedantic one (both go through the sublist
insert, which refuses independently of the flag).

**Consequence.** Low: a client that asked for strict checking sees an error line for a publish that was
nevertheless routed, so an application that treats `-ERR` as "not sent" and retries would publish twice.
Nothing at the default setting. No data-integrity or security effect.

## SI-8 · A leaf's queue members skew the hub's own members' split

**The observation.** On **v2.14.6**, `raw/nats-server-src/request-reply-observed-v2.14.6.md` runs H5–H8
(`request-reply-run3.sh`, `request-reply-run4.sh`): a standalone hub (`leafnodes { port: 17422 }`) and a
standalone leaf (`leafnodes { remotes: [ { url: nats-leaf://127.0.0.1:17422 } ] }`), plain `nats sub
orders.created --queue workers` members on each side, `nats pub --count 400` on the hub:

```
--- H5.1: two on the hub, two on the leaf; 400 publishes on the hub
hub-e1-1 89 · hub-e2-1 311 · leaf-e1-1 0 · leaf-e2-1 0
--- H5.2: two on the hub, two on the leaf; 400 publishes on the hub
hub-e1-2 297 · hub-e2-2 103 · leaf-e1-2 0 · leaf-e2-2 0
--- H5.3: two on the hub, two on the leaf; 400 publishes on the hub
hub-e1-3 302 · hub-e2-3 98 · leaf-e1-3 0 · leaf-e2-3 0
--- H6: two on the hub, one on the leaf; 400 publishes on the hub
hub-f1 137 · hub-f2 263 · leaf-f 0
--- H7: three on the hub, two on the leaf; 400 publishes on the hub
hub-g1 70 · hub-g2 75 · hub-g3 255 · leaf-g1 0 · leaf-g2 0
--- H8: two on the hub, no leaf member; 400 publishes on the hub (the control)
hub-h1 196 · hub-h2 204
```

(The first pass, `request-reply-run3.sh` H5 with 200 publishes: 148 / 52.) The ratios are 3 : 1 for two
hub members and two leaf members, 2 : 1 for two and one, 3 : 1 : 1 for three and two, and even without a
leaf member; which hub member is favoured changed between repeats, each made with a new publisher
connection.

**The code** (`raw/nats-server-src/request-reply-v2.14.6.md`). The sublist expands a leaf's queue
subscription to its weight — one entry per member behind it — when building the match result
(`sublist.go:741–747`, "Shadow these subscriptions"). `processMsgResults` draws a random start index over
that list (`client.go:5516`) and walks it; for a message from a client, a LEAF entry is not delivered to
but remembered as the fallback and skipped — "Remember that leaf in case we don't find any other
candidate … continue" (`:5547–5553`) — so every start index that lands on one of the leaf's *n* adjacent
entries walks on to the same next local member. With the list `[hub-1, hub-2, leaf, leaf]` the member
after the leaf entries is reached from three of the four start indexes.

**What would settle it.** Whether the skew is intended. Two readings are possible: the leaf entries are
meant to be fallbacks only and the walk should re-draw among the local members after skipping them (the
route-vs-leaf fallback already re-randomises with a coin flip, `:5497–5504`, #6040); or the expansion to
the weight should not apply to entries that cannot be delivered to on this pass. Either way the docs' "the
selection is uniform-random across the available members" (`learn/core-nats/queue-groups.md:218`) does not
hold for a hub with a leaf-side group.

**Searched and not found.** The docs mirror's topology pages (`learn/topologies/leaf-nodes.md` has no
queue-group statement); the 484 `nats-io/nats-server` discussions' titles, bodies, comments and replies
for "queue group" with "leaf" (`local/scratch/gh-index/threads-2026-09-03.md`, 2026-09-03); the release
bodies — 2.10.22 "Load balancing of queue groups over leafnode connections (#5982)" and 2.10.23 "Load
balancing queue groups from leaf nodes in a cluster (#6043)" are about a message arriving *from* a leaf,
which was not the shape here.

**What was not tested.** A leaf *cluster* (several leaf servers) and a hub cluster (the hub was one
server); a publisher on the leaf with several hub members (H2 and H4 had one leaf member taking all,
which is the fallback rule, not the skew); a gateway; whether the skew changes with route pooling or
`isolate_leafnode_interest`; a spoke leaf on a cluster.

**Consequence.** Medium: uneven load on hub-side members whenever a leaf also hosts members of the same
group — one hub member carries the leaf's share on top of its own, and an operator sizing a hub pool on
"uniform across members" under-provisions it. No message is lost or duplicated; the leaf's members are
simply never chosen while the hub has one.

## SI-9 · A push consumer's deliver subject is only woken by an exact-subject subscriber

**The observation.** On **v2.14.6**, `raw/nats-server-src/stream-topology-observed-v2.14.6.md`, runs
F2 (`stream-topology-runF2.sh`) and F3 (`-runF3.sh`). A stream `SRC2` with 1,000 messages, a second
stream `COPY2` whose only subject is `copy2.>`, and a durable **push** consumer on `SRC2` delivering
to `copy2.evt`. Nothing else is connected:

```
--- does COPY2's subscription show up in the account sublist? ---
num_subscriptions 11
   src2.> sid 1 account $G
   copy2.> sid 1 account $G
create: ok
consumer after 3s: delivered {'consumer_seq': 0, 'stream_seq': 0} num_pending 1000 push_bound None
COPY2 messages: 0
```

`COPY2`'s interest is in the account sublist, `copy2.>` matches `copy2.evt`, and the consumer stays
at zero. Start one ordinary subscriber on the **literal** deliver subject and everything moves at
once:

```
### G2 · the same consumer with a real subscriber on copy2.evt
consumer with a subscriber: delivered {'consumer_seq': 1000, 'stream_seq': 1000, ...} num_pending 0
COPY2 messages: 1000
```

It is not about streams. Run F3 takes the stream out of it entirely — a plain
`nats sub 'd.>'` against a consumer delivering to `d.evt`:

```
### H1 · a push consumer with only a WILDCARD subscriber on its deliver subject
--- subscriber: nats sub 'd.>' (a wildcard that covers d.evt) ---
with only a WILDCARD subscriber d.> : delivered 0 num_pending 1000
--- what the wildcard subscriber saw ---
0
### H2 · now an EXACT subscriber on d.evt, same consumer
with an EXACT subscriber d.evt : delivered 349 num_pending 651
3
```

**The code.** A push consumer registers a notification on its deliver subject, and the sublist's
initial interest test is an exact string comparison:

```go
169:	func (s *Sublist) registerNotification(subject, queue string, notify chan<- bool) error {
170:		if subjectHasWildcard(subject) {
171:			return ErrInvalidSubject
172:		}
…
177:		var hasInterest bool
178:		r := s.Match(subject)
179:
180:		if len(r.psubs)+len(r.qsubs) > 0 {
181:			if queue == _EMPTY_ {
182:				for _, sub := range r.psubs {
183:					if string(sub.subject) == subject {
184:						hasInterest = true
185:						break
186:					}
187:				}
```

(`server/sublist.go:169–187` at v2.14.6.) `s.Match(subject)` has already found the wildcard
subscription — it is in `r.psubs` — and the loop then discards it because its subject is `copy2.>`
and not `copy2.evt`. The consumer's `o.active` is set from that value (`consumer.go:2134`,
`:1822`), and `hasNoLocalInterest` (`:6477`) reads `o.acc.sl.HasInterest(o.cfg.DeliverSubject)`,
which *does* count the wildcard — so the two tests in the same code path disagree about whether
interest exists.

**What would settle it.** Whether a wildcard subscription is *meant* to count as interest for a push
consumer's deliver subject. There is a defensible reason for the exact test — a notification is
registered on a literal subject and a wildcard subscriber may be a monitor rather than a worker — but
if that is the intent, the consumer's silence should be visible. It is not: nothing is logged at any
level, `num_pending` simply grows, and `CONSUMER.INFO` carries **no `push_bound` field at all** in
this state — the same as when the consumer is working (it is `omitempty`, so `false` and "absent"
are the same wire form). The narrower question: should `CONSUMER.INFO` distinguish "no interest on
the deliver subject" from "bound and idle"?

**Searched and not found.** `docs.nats.io`'s consumer chapter describes a push consumer's deliver
subject without mentioning that the subscriber's subject must match it literally (`grep -rn` over the
861-page mirror on 2026-09-04 for `deliver_subject`, `push consumer`, `no interest`). No entry among
the 484 `nats-io/nats-server` discussions cached in `local/scratch/gh-index/threads-2026-09-03.md`
matches `deliver subject` with `wildcard` or `no interest`.

**What was not tested.** A **queue** deliver group (`deliver_group`), which takes the `qsubs` branch
of the same loop and compares the queue name as well; a replicated (`R3`) push consumer, where the
interest test runs on the consumer leader; a wildcard subscriber that arrives *after* an exact one has
come and gone; whether a leafnode's or a gateway's propagated interest behaves as an exact subscriber;
and MQTT and WebSocket subscribers, which register through the same sublist but by different paths.

**Consequence.** Medium, and it is a design consequence rather than a data one. "Copy a stream with a
consumer that delivers into a second stream" is a shape people reach for — it is the third option in
question-bank row 114 — and it does not work server-side: a stream's subject filter is a wildcard
subscription in every realistic case. The failure is silent, and the visible symptom, a consumer with
`num_pending` climbing and `delivered` at zero, reads like a broken worker. No data-integrity or
security effect: nothing is lost, nothing is delivered twice, and everything flows the moment an
exact subscriber attaches.

**Where the wiki records this:** `wiki/operations/stream-topology-design.md` — *How a second copy is
made*, where it is stated as a design rule (row 114's third shape does not exist server-side, and a
client has to make the copy); `wiki/concepts/mirrors-and-sources.md` — *What each copy costs,
measured*. The run is `raw/nats-server-src/stream-topology-observed-v2.14.6.md`, runs F2/F3 (G1–G3,
H1–H3), summarised in `wiki/summaries/s-nats-server-stream-topology-observed.md`.
