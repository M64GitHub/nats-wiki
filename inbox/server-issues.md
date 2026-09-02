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
