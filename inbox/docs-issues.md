# Docs issues found while building this wiki

Errors, gaps and inconsistencies found in **public NATS documentation** while ingesting it. This
file is **not a wiki page** — it is a report, kept so it can be sent to the docs maintainers or
turned into issues against `nats-io/nats-docs` and `nats-io/nats-architecture-and-design`.

## How to read this, if you maintain the docs

**Every row is verified against a stated authority** — normally the `nats-server` source at a release
tag, quoted with file and line, with the documentation's own wording beside it. Nothing here is a
guess, an inference, or a style opinion. Where a page is correct but unhelpful, the row is marked
`enhancement` and kept apart from the ones that are factually wrong; we would rather under-claim than
send you a list you have to re-verify.

**Nothing here asks you to adopt our wording.** Each detail section ends with a *Suggested fix*, and
those are suggestions — the point of the report is the finding, not the patch.

| column | what it means to you |
|---|---|
| `★` | a **confirmed factual error with real impact** — following the documentation produces a broken result, **silently**. If you triage on one thing, triage on this |
| `where` | the doc path. For docs.nats.io prefix `https://docs.nats.io/` |
| **`destination`** | which repository the fix belongs in: **`nats-docs`** for the documentation tree, **`ADR repo`** for `nats-io/nats-architecture-and-design`, **`natscli`** for `nats-io/natscli`. Three rows (#7, #30, #31) are ADR errors rather than docs errors, one (#40) is a **CLI defect**, and one (#39) is a **published blog post** rather than a repository at all |
| `kind` | `wrong-value` and `missing` are defects; `enhancement` is correct-but-unhelpful |
| `severity` | our estimate of consequence, not of effort |
| **`upstream`** | where this was filed and what became of it. `not filed` means we have not sent it yet |
| `status` | **ours, not yours** — how this wiki handled the finding internally. Safe to ignore |

**Which release.** Unless a row says otherwise, the authority is `nats-server` **v2.14.6** and the docs
tree as fetched **2026-08-31**. Where a row says *observed*, the behaviour was **run on the binary**,
not only read from the source.

**Findings about the server itself are not in this file.** They are in `inbox/server-issues.md`,
because a server finding cannot be settled the way a docs finding can — there is no higher authority to
check it against, so those entries are observations and questions rather than verdicts. One finding can
legitimately appear in both: #35 here is the documentation gap, and `SI-1` there is the behaviour
behind it.

**Paths beginning `raw/`, `wiki/` or `inbox/` are internal to the repository this report was written
in.** They are cited so the evidence is traceable on our side; nothing in the report depends on being
able to open them.

Rows 1–10 were found while working `inbox/plan-first-ingests-2026-08-31.md`; rows 11–26 while
working `inbox/plan-runbooks-and-security-2026-08-31.md`; rows 27–29 by the **mechanical sweep** of
`inbox/plan-drift-and-adrs-2026-08-31.md` step 1 — `tools/check-defaults.py` compared **all 216
documented defaults** in `inbox/config-keys-table.md` against the option parser, the use sites, the
flags and the constants of `nats-server` v2.14.6 (report: `inbox/check-defaults-v2.14.6.md`). That
sweep re-derived #19, #22 and #23 from the source with no human input, found the three below, and
left 26 keys it could not resolve — those are listed in the report for a human, not guessed at.
Row 33 was found while working step 5 (the sizing rows), by reading `server/filestore.go` at v2.14.6 and
then measuring the same claims on the binary. Rows 30–32 were found while working step 4 of that plan (the remaining ★ ADRs): two are **ADR** errors
rather than docs errors, which is the direction that matters for client and tooling authors, and one
is a generator bug that repeats on every page it touches. Verified against **nats-server v2.14.6**
and the docs tree fetched **2026-08-31**. Where a row says *observed*, the behaviour was **run on the
v2.14.6 binary**, not only read from the source at that tag; the configs and output are in
`raw/nats-server-src/topology-observed-v2.14.6.md` and, for rows 30–31,
`raw/nats-server-src/compression-purge-discovery-observed-v2.14.6.md`; for row 33,
`raw/nats-server-src/filestore-observed-v2.14.6.md`. Row 34 was found while working step 1 of `inbox/plan-the-unread-chapters-2026-08-31.md` — the question-bank row **Q97** run on the binary rather than read — and its evidence is in `raw/nats-server-src/tls-reload-observed-v2.14.6.md`. Row 35 was found while working step 4 of the same plan (the `learn/object-store` chapter): reading the leafnode deny lists next to the object store's real subject spaces raised the question, and a hub/leaf pair on the v2.14.6 binary settled it — `raw/nats-server-src/object-store-across-leafnode-observed-v2.14.6.md`, with the chapter's own claims checked in `raw/nats-server-src/object-store-observed-v2.14.6.md`. Row 36 was found while working step 6 of the same plan (`learn/monitoring`), and its evidence — including a **wire capture that upgrades row 1 from a source constant to an observed subject** — is in `raw/nats-server-src/monitoring-observed-v2.14.6.md`. Rows 8–10 concern **client** claims, so their authority is
the client repository at its current release plus the package registry, not the server — stated per
row.

| # | issue | where | destination | kind | severity | upstream | status |
|---|---|---|---|---|---|---|---|
| 1 | Nak advisory subject is `MSG_NAK`; the server publishes `MSG_NAKED` | `reference/jetstream/advisory/nak.md` | nats-docs | wrong-value | ★ high | not filed | wiki uses the server value |
| 2 | Pinned advisory subject is `GROUP_PINNED`; the server publishes `PINNED` | `reference/jetstream/advisory/consumer-group-pinned.md` | nats-docs | wrong-value | ★ high | not filed | wiki uses the server value |
| 3 | Unpinned advisory subject is `GROUP_UNPINNED`; the server publishes `UNPINNED` | `reference/jetstream/advisory/consumer-group-unpinned.md` | nats-docs | wrong-value | ★ high | not filed | wiki uses the server value |
| 4 | Consumer config object is collapsed, so **no consumer default is readable** anywhere in the reference | `reference/jetstream/api/consumer/create.md` | nats-docs | missing | high | not filed | wiki reads the server source instead |
| 5 | `duplicate_window` default documented only as "0 for default" in the generated reference, where the field is defined — the substituted value **is** stated, in prose, three pages away in the `learn` chapter | `reference/jetstream/api/stream/create.md` | nats-docs | missing | low | not filed | wiki states the value and cites both |
| 6 | `max_payload` "not recommended" over 8MB without saying what actually happens | `reference/config/max_payload.md` | nats-docs | enhancement | low | not filed | wiki states the real behaviour |
| 7 | ADR-42 is tagged `2.11` but describes the `prioritized` policy, which shipped in 2.12 | `nats-architecture-and-design` ADR-42 | ADR repo | wrong-value | medium | not filed | wiki corrects the attribution |
| 8 | `nats.net` is described as ".NET 6+"; the current client **dropped `net6.0`** | `concepts/ecosystem.md` | nats-docs | wrong-value | medium | not filed | wiki states the v3 target frameworks |
| 9 | `nats.deno` is listed among "the archived" repos superseded by `nats.js`; it is **not archived** | `concepts/ecosystem.md` | nats-docs | wrong-value | low | not filed | wiki says which three are archived |
| 10 | The Python client's two PyPI distributions are never reconciled: the client map names neither, and `nats-core` appears only on a WebSocket page | `concepts/ecosystem.md`, `concepts/getting-started.md`, `learn/websocket/your-first-websocket-connection.md` | nats-docs | missing | medium | not filed | wiki lists both packages and their Python floors |
| 11 | A cluster-name mismatch is documented as always splitting the cluster; an **unset** `cluster.name` is silently **adopted** from the peer instead | `learn/clustering/forming-a-cluster.md`, `learn/topologies/your-first-cluster.md`, `reference/config/cluster/name.md` | nats-docs | missing | medium | not filed | wiki states both branches |
| 12 | The hardening page's systemd extract drops `User=`/`Group=` and `ExecStop=` from the unit it is quoting | `learn/deployment/hardening.md` | nats-docs | enhancement | low | not filed | wiki quotes the shipped unit instead |
| 13 | `lame_duck_duration` is presented as covering JetStream's leadership move; the server does that work **before** the timer starts, so the documented failure mode cannot occur and the sizing advice tunes the wrong knob | `learn/deployment/rolling-upgrades.md` | nats-docs | wrong-value | ★ medium | not filed | wiki states what the duration actually governs |
| 14 | "grace period" means two different things two paragraphs apart — `lame_duck_grace_period` (must be **shorter** than the duration) and `terminationGracePeriodSeconds` (must be **longer**) | `learn/deployment/rolling-upgrades.md` | nats-docs | enhancement | low | not filed | wiki names both keys explicitly |
| 15 | A memory stream's backup is documented to fail with `memory streams do not support snapshots`; the server returns **`no impl`** | `learn/backup-recovery/stream-backup-restore.md` | nats-docs | wrong-value | ★ medium | not filed | wiki states the real error and code |
| 16 | The restore rename error is quoted as the **server's** and in the singular; it is the **CLI's**, and reads `stream names may not be changed during restore` | `learn/backup-recovery/stream-backup-restore.md` | nats-docs | wrong-value | low | not filed | wiki quotes the CLI string and the server's code |
| 17 | `chunk_size`'s documented maximum is `9223372036854776000`; the server clamps it to **1 MiB**, silently | `reference/jetstream/api/stream/snapshot.md` | nats-docs | wrong-value | low | not filed | wiki states the real clamps |
| 18 | `nats stream restore` accepts `--config`, `--cluster`, `--tag` and `--replicas`; the backup chapter mentions none, and presents a restore as reproducing the original configuration | `learn/backup-recovery/stream-backup-restore.md`, `learn/backup-recovery/disaster-recovery.md` | nats-docs | missing | medium | not filed | wiki documents the restore-elsewhere path |
| 19 | **15 timeout defaults in the generated config reference are wrong**: all 9 `tls.timeout` keys say `500ms` (server: **2s**) and all 6 `authorization.timeout` keys say `1` (server: **2s**, or `tls_timeout + 1` when TLS is configured) | `reference/config/tls/timeout.md` + 8 siblings, `reference/config/authorization.md` + 5 siblings | nats-docs | wrong-value | ★ medium | not filed | wiki states the server values and the TLS-dependent rule |
| 20 | `/varz` has exposed **`tls_cert_not_after`** per listener since PR #7709, and the whole docs tree never names it — the TLS page says to "monitor validity dates" with no way to do it | `learn/security/encryption.md`, `learn/monitoring/monitoring-endpoints.md` | nats-docs | missing | ★ medium | not filed | wiki documents the field and `nats account tls` |
| 21 | Cross-domain and cross-account replication is said to need "the `external` block", pointing at a reference page that never mentions it; `external`, `api` and `deliver` appear **nowhere** in the 861-page docs tree | `learn/jetstream/mirrors-and-sources.md`, `reference/jetstream/api/stream/create.md` | nats-docs | missing | ★ medium | not filed | wiki reads the fields from the server source and says what is still unverified |
| 22 | **Four defaults in the generated `jetstream` block are wrong**, including the most-quoted number in NATS sizing: `max_file_store` "Defaults to up to 1TB if available" (server: **75% of the space free under `store_dir`**, 1 TB only when `statfs` fails), `max_buffered_msgs` `10000` (**100000**), `max_outstanding_catchup` `32M` (**64MB**), `info_queue_limit` `100000` (**defaults to `request_queue_limit`**). The maintainers' "auto-sizing is for development and testing" appears nowhere in the tree, and `max_file_store: 0` silently means *no storage*, not *unlimited* | `reference/config/jetstream.md`, `reference/config/jetstream/max_file_store.md` + 3 siblings | nats-docs | wrong-value | ★ high | not filed | wiki states the server values and the restart hazard |
| 23 | **The three topology listener ports are documented with defaults the server never applies**: `cluster.port` `6222`, `leafnodes.port` `7422` and `gateway.port` `7222`. Omitting `cluster.port` or `leafnodes.port` opens **no listener, silently**; omitting `gateway.port` **stops the server from starting** | `reference/config/cluster.md`, `reference/config/leafnodes.md`, `reference/config/gateway.md` | nats-docs | wrong-value | ★ medium | not filed | wiki states "no default" and the per-key consequence |
| 24 | The chapter's **composed topology config does not start** — `cluster {}` + `gateway {}` + `leafnodes { listen }` with no `system_account` fails validation, and `nats-server -t` reports the same file valid | `learn/topologies/putting-it-together.md`, `learn/deployment/config-management.md` | nats-docs | wrong-value | ★ medium | not filed | wiki quotes the error and says `-t` is a syntax check |
| 25 | The fast-producer stall — the mechanism by which one slow destination throttles a publisher — is **absent from the 861-page tree**, along with both counters that expose it (`/varz` `stalled_clients`, `/connz` `stalls`) and its log line | whole tree; `learn/monitoring/monitoring-endpoints.md`, `learn/topologies/super-clusters.md` | nats-docs | missing | ★ medium | not filed | wiki documents both counters, the constants and the geo-affinity caveat |
| 27 | The **leafnode compression default is `accept`** in the reference; the server defaults both the listener and every remote to **`s2_auto`**. The two behave differently on the wire | `reference/config/leafnodes/compression.md` + `leafnodes/remotes/compression.md` and their `mode` pages | nats-docs | wrong-value | ★ medium | not filed | wiki states the server value, observed |
| 28 | `mqtt.max_ack_pending` is documented as `100`; the server's default is **1024** | `reference/config/mqtt.md` | nats-docs | wrong-value | medium | not filed | wiki states the server value |
| 29 | `mqtt.port` is documented as defaulting to `1883`; the server applies **no default** — `mqtt { }` with no port starts **no MQTT listener**, silently | `reference/config/mqtt.md` | nats-docs | wrong-value | ★ medium | not filed | wiki states "no default", as for the other listeners |
| 26 | Four `leafnodes.remotes` keys are published with a **completely empty description**: `hub`, `deny_imports`, `deny_exports`, `jetstream_cluster_migrate` — including the two keys the only public question on the topic asks about | `reference/config/leafnodes/remotes.md` and the four property pages | nats-docs | missing | medium | not filed | wiki states what the two deny keys do, from the source |
| 30 | ADR-35 says a `compression` change applies to "newly minted blocks"; on a live stream the running store keeps writing with the algorithm it was **created** with, so nothing changes until the store re-opens | `nats-architecture-and-design` ADR-35 | ADR repo | wrong-value | medium | not filed | wiki states the observed behaviour and says the docs are right here |
| 31 | The connection spec's **Servers discovery** section is two paragraphs, a truncated sentence and a `TODO`, in an ADR marked *Implemented* — so what a server advertises to clients is stated nowhere public; `max reconnects` also has no readable default (`**default: 3 / none`) | `nats-architecture-and-design` ADR-40 | ADR repo | missing | medium | not filed | wiki observes the `INFO` directly and records what the server sends |
| 32 | Every `unsigned 64 bit integer` field in the generated JetStream reference publishes `Maximum: 18446744073709552000` — **385 more than uint64 can hold**, and a value the server cannot accept. 11 pages, all of them | `reference/jetstream/api/*`, `reference/jetstream/advisory/*`, `reference/jetstream/metric/consumer-ack.md` | nats-docs | wrong-value | low | not filed | wiki quotes no maximum from these pages |
| 33 | The sizing chapter tells operators to pin `max_file_store` to the volume size, and never says that **every JetStream storage figure is logical, not physical** — a server set to `max_file_store: 4MB` was measured holding 3.79 MB on disk while reporting 133,000 bytes used. The per-message record overhead (`30 + len(subject)`) is also stated nowhere in the tree | `learn/deployment/sizing-and-resources.md`, `reference/config/jetstream/max_file_store.md` | nats-docs | missing | ★ high | not filed | wiki states the arithmetic and the slack, observed |
| 34 | Six leafnode-remote TLS keys carry a bug note scoped to "2.11/2.12" and never say whether it still applies; on **2.14.6** `cert_file`, `key_file` and `ca_file` all reload correctly, so the note now reads as a standing warning against the supported rotation procedure | `reference/config/leafnodes/remotes/tls/cert_file.md` + 5 siblings | nats-docs | enhancement | medium | not filed | wiki states the observed 2.14.6 behaviour and names the three keys it did not test |
| 35 | No page anywhere in the docs states what happens to **KV and Object Store subjects across a JetStream domain boundary** — and the two behave differently, so a reader who generalises from the KV case is wrong about the Object Store one. (The *behaviour* is `inbox/server-issues.md` **SI-1**; this row is the documentation gap alone) | `learn/topologies/leaf-nodes.md`; `learn/object-store/under-the-hood.md`; `learn/key-value/under-the-hood.md` | nats-docs | missing | high | not filed | wiki states the observed 2.14.6 behaviour on four pages and flags the defect question as open |
| 36 | The advisories chapter's own diagram caption drops `.CONSUMER.` from the max-deliveries advisory subject — `$JS.EVENT.ADVISORY.MAX_DELIVERIES.ORDERS.shipping`, three times — while the prose on the same page has it right; a subscription copied from the caption receives nothing | `learn/monitoring/advisories-and-events.md` | nats-docs | wrong-value | low | not filed | wiki states the observed subject and notes the page contradicts itself |
| 37 | ADR-42 states that a consumer's priority policy and groups cannot be changed after creation ("Only `PriorityTimeout` is updatable today") and that more than one group per consumer is an error; at 2.14.6 all three forbidden transitions are accepted and two groups are accepted and stored. `learn/jetstream/policies.md` says the opposite of the ADR and is right | `nats-architecture-and-design` ADR-42 | ADR repo | wrong-value | medium | not filed | wiki states the observed behaviour and says the ADR and the docs disagree |
| 38 | The acknowledgment chapter says three times that a consumer `backoff` "doesn't slow a nak" (lines 42, 298, 586). True of a **bare** nak; **false of a nak carrying a delay**, which is the only kind the sentence's own paragraph is about. At 2.14.6 a nak asking for 2s waits 12s, and a nak asking for **0s** waits 10s, on a consumer with `backoff` `[5s,10s,15s]` | `learn/jetstream/acknowledgment.md` | nats-docs | wrong-value | high | not filed | wiki states the measured rule and says the sources disagree |
| 39 | A Synadia engineering post answers "how do I retry a failed message with a backoff?" with "Negatively acknowledge it" — but a bare nak is the one case a backoff does **not** shape. Its copyable Go consumer config also sets `AckWait: 30s` next to `BackOff: [1s, …]`, and **the server silently stores `ack_wait: 1s`**, a 30× shorter ack deadline than the code reads | [synadia.com/blog/jetstream-reliable-delivery-dlq-replay](https://www.synadia.com/blog/jetstream-reliable-delivery-dlq-replay) | Synadia blog | wrong-value | ★ high | not filed | wiki states the observed behaviour and cites the post for the parts that hold |
| 40 | `nats pub --schedule-after` emits `Nats-Schedule: <RFC3339>` **without the `@at ` prefix**, which the server always rejects with `10189 message schedules pattern is invalid`. The flag cannot work at all; the sibling `--schedule-at`, `--schedule-every` and `--schedule-cron` emit valid patterns | nats CLI 0.4.0, `nats pub --schedule-after` | natscli | wrong-value | high | not filed | wiki documents `--schedule-at` and warns off the flag |
| 41 | The JetStream header reference describes `Nats-Scheduler` as a "Scheduler ID" (it is **the subject holding the schedule**) and `Nats-Schedule-TTL` as "Time-to-live for **the schedule**" (it sets `Nats-TTL` on the **generated message**). `Nats-Schedule-Time-Zone` and `Nats-Schedule-Rollup` have **empty descriptions**, and the section never says the stream must set `allow_msg_schedules` | `reference/jetstream/api/headers.md` | nats-docs | wrong-value | high | not filed | wiki states the observed header values |
| 42 | **The message scheduler has no prose page anywhere in the documentation.** Four release-note bullets across 2.12 and 2.14 announce it and all four link only to ADR-51; the whole tree's coverage is one header table and ten error codes. Verified against the **live** `docs.nats.io/llms.txt` on 2026-09-01: no entry mentions scheduling, cron or delayed publishing | `learn/jetstream/` (absent); `release-notes/upgrade-to-2.12.md`, `upgrade-to-2.14.md` | nats-docs | missing | high | not filed | wiki writes `message-scheduling` from ADR-51 and the binary |

---

## 1–3 · Three advisory subjects in the reference do not match the server ★

**Impact: a subscription written from these pages receives nothing, with no error.** This is the
worst failure shape for a monitoring integration — it looks wired up and is silently deaf.

All three were found by cross-checking every page under
`raw/nats-docs/reference/jetstream/advisory/` against the `JSAdvisory*Pre` constants in
`server/jetstream_api.go` at **v2.14.6**. Of the 22 advisory pages, **19 match and these 3 do not.**

| # | docs say | server publishes | server constant |
|---|---|---|---|
| 1 | `$JS.EVENT.ADVISORY.CONSUMER.MSG_NAK.{stream}.{consumer}` | `$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED.<stream>.<consumer>` | `JSAdvisoryConsumerMsgNakPre`, `jetstream_api.go:244` |
| 2 | `$JS.EVENT.ADVISORY.CONSUMER.GROUP_PINNED.{stream}.{consumer}` | `$JS.EVENT.ADVISORY.CONSUMER.PINNED.<stream>.<consumer>` | `JSAdvisoryConsumerPinnedPre`, `jetstream_api.go:268` |
| 3 | `$JS.EVENT.ADVISORY.CONSUMER.GROUP_UNPINNED.{stream}.{consumer}` | `$JS.EVENT.ADVISORY.CONSUMER.UNPINNED.<stream>.<consumer>` | `JSAdvisoryConsumerUnpinnedPre`, `jetstream_api.go:271` |

**Evidence — the constants** (`server/jetstream_api.go`, v2.14.6):

```go
244:	JSAdvisoryConsumerMsgNakPre = "$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED"
268:	JSAdvisoryConsumerPinnedPre = "$JS.EVENT.ADVISORY.CONSUMER.PINNED"
271:	JSAdvisoryConsumerUnpinnedPre = "$JS.EVENT.ADVISORY.CONSUMER.UNPINNED"
```

**Evidence — the publish sites** (`server/consumer.go`, v2.14.6), so these are the subjects actually
used, not just declared:

```go
1244:	o.nakEventT = JSAdvisoryConsumerMsgNakPre + "." + o.stream + "." + o.name
1997:	subj := JSAdvisoryConsumerPinnedPre + "." + o.stream + "." + o.name
2016:	subj := JSAdvisoryConsumerUnpinnedPre + "." + o.stream + "." + o.name
```

**Corroboration inside the docs themselves.** For #1, the docs are internally inconsistent — the
*learn* page has it right and only the generated *reference* page is wrong
(`learn/jetstream/acknowledgment.md`):

> "Each nak also raises a nak advisory on `$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED.ORDERS.shipping`"

For #2 and #3, **ADR-42 also has it right** (`adr/ADR-42.md`, lines 226–227):

```go
const JSAdvisoryConsumerPinnedPre = "$JS.EVENT.ADVISORY.CONSUMER.PINNED"
const JSAdvisoryConsumerUnpinnedPre = "$JS.EVENT.ADVISORY.CONSUMER.UNPINNED"
```

So in all three cases the reference page is the **only** place carrying the wrong value.

**Suggested fix:** correct the `## Subscription Subject` line on the three pages. Since these pages
appear to be generated, the more durable fix is in whatever maps advisory schema names to subjects —
note that the wrong values look like they were derived from the *schema type* name
(`consumer_group_pinned`) rather than from the subject constant, which would explain all three at
once and suggests other generated subjects are worth auditing the same way.

---

## 4 · No consumer default is readable anywhere in the reference

**`reference/jetstream/api/consumer/create.md`** renders the consumer configuration as a collapsed
schema node and never expands it:

```
▶configobjectrequired

The consumer configuration
```

The sibling page `reference/jetstream/api/stream/create.md` **does** expand, listing every
`StreamConfig` field with its type, range and default. So the two most important config objects in
JetStream are documented to completely different depths.

**Impact:** `ack_wait`, `max_deliver`, `max_ack_pending`, `backoff`, `inactive_threshold` and
`PriorityTimeout` have **no discoverable default** in the reference. A reader has to find them in
prose in the learn chapter (which covers three of them) or read the server source (which is what
this wiki ended up doing).

The values, for reference, from `server/consumer.go` at v2.14.6:

| field | default | line |
|---|---|---|
| `ack_wait` | `30s` | 573 |
| `max_deliver` | `-1` | 589–593 |
| `max_ack_pending` | `1000` | 580 |
| `inactive_threshold` (ephemeral) | `5s` | 576 |
| `PriorityTimeout` | `2m` | 582 |

**Suggested fix:** expand the `config` node the way `stream/create.md` does.

---

## 5 · `duplicate_window`'s real default is never stated

**`reference/jetstream/api/stream/create.md`** documents the field as:

> `duplicate_window` integer — The time window to track duplicate messages for, expressed in
> nanoseconds. **0 for default** … Default: `0`

It never says what "default" is. The server substitutes **2 minutes**
(`StreamDefaultDuplicatesWindow`, `server/stream.go:1658`), and only when the stream sets no window
of its own and is neither a mirror nor a source (`stream.go:1750`), clamped down by the account
`Duplicates` limit and by `max_age` if either is smaller.

**Impact:** deduplication window is both a correctness setting and a **memory** setting — the server
holds the tracked message IDs in RAM.

**Corrected 2026-08-31, and the correction narrows this row.** When it was first written, the only
public statement of "2 minutes" found anywhere was a Synadia blog post from 2025-08-08. Reading the
`learn/jetstream` chapter for plan step 2 found the value stated plainly, in **three** doc pages:

```
learn/jetstream/publishing.md
  "The duplicate-tracking window is two minutes by default, so a retry that arrives after that
   also stores a second copy."
learn/jetstream/your-first-stream.md:447   Duplicate Window: 2m0s
learn/jetstream/your-first-stream.md:499
  "**Duplicate Window: 2m0s**. For two minutes after a message is stored, the server turns away a
   second message that carries the same Nats-Msg-Id header."
learn/jetstream/shaping-the-stream.md      Duplicate Window: 2m0s   (in a `nats stream info` block)
```

All three agree with the server (`StreamDefaultDuplicatesWindow = 2 * time.Minute`,
`server/stream.go:1658` at v2.14.6). **So the docs are not wrong and the value is not missing from
the tree — it is missing from the page where the field is defined**, which is the page a reader
consults when they want a default. Severity drops from medium to low, and the kind stays `missing`
because the reference page genuinely never states it.

What remains genuinely undocumented anywhere is the *conditions*: the default applies only when the
stream sets no window and is neither a mirror nor a source (`stream.go:1750`), and is then clamped
down by the account `Duplicates` limit and by `max_age` if either is smaller.

**Suggested fix:** state the substituted value on the reference page, and ideally the conditions
under which it applies.

---

## 6 · `max_payload` says "not recommended" without saying what happens · enhancement

**`reference/config/max_payload.md`**:

> "It is not recommended to use values over 8MB but `max_payload` can be set up to 64MB."

What actually happens above 8MB, from `server/server.go:2342` at v2.14.6, is a **startup warning and
nothing else**:

```go
if opts.MaxPayload > MAX_PAYLOAD_MAX_SIZE {
    s.Warnf("Maximum payloads over %v are generally discouraged and could lead to poor performance",
        friendlyBytes(int64(MAX_PAYLOAD_MAX_SIZE)))
}
```

and the constant's own comment (`server/const.go:96–98`) records the intent:

```go
// MAX_PAYLOAD_MAX_SIZE is the size at which the server will warn about
// max_payload being too high. In the future, the server may enforce/reject
// max_payload above this value.
```

**Impact:** low, but this is a recurring public question (e.g.
[gh#7068](https://github.com/nats-io/nats-server/discussions/7068)) precisely because "not
recommended" does not say whether it is a soft or hard boundary. It is soft **today** and the
comment warns it may not stay soft.

**Suggested fix:** say that above 8MB the server logs a warning at startup, and that a future
version may reject it.

---

## 7 · ADR-42 is tagged 2.11 but describes a 2.12 feature

**`nats-architecture-and-design`, `adr/ADR-42.md`** — *Pull Consumer Priority Groups*. Its metadata
tags are `jetstream, server, 2.11`, and it describes three priority policies together: `overflow`,
`pinned_client` and `prioritized`.

But `prioritized` shipped in **2.12**, per the docs' own upgrade guide
(`release-notes/upgrade-to-2.12.md`):

> "**Prioritized pull consumer policy:** In addition to the consumer policies like overflow or
> client pinning, a new `prioritized` policy has been added."

Revision 4 of the ADR ("Add priority client policy", 2025-07-17) postdates the 2.11 tag, so the tag
was simply never updated as the ADR grew.

**Impact:** a reader planning against a 2.11 cluster would expect a policy that is not there. This
is a general hazard of the ADR revision model — the metadata `Tags` row carries one version while
the revision table records several.

**Suggested fix:** version-tag the individual policies, or note the shipping version in the revision
table. (ADR-42 already does this well for *unimplemented* features — the `failover` option carries
an explicit "As of NATS Server 2.14 this feature is not currently implemented" admonition. The same
treatment for *arrival* versions would close this.)

---

## 8 · The .NET client is documented as ".NET 6+", and v3 dropped .NET 6

**`concepts/ecosystem.md`**, tier 1 client table:

> | C# / .NET | [nats-io/nats.net](https://github.com/nats-io/nats.net) | **.NET 6+**. Modern async client |

**Authority: the client repository at its current release.** `nats.net`'s latest release is
**v3.2.0** (2026-08-29); the v3.0.0 release notes (2026-07-10) say:

> "3.0 targets `netstandard2.0`, `netstandard2.1`, `net8.0`, and `net10.0`. **`net6.0` has been
> dropped.**"

The repository README repeats it in an admonition at the top of the page: "v3 adds OpenTelemetry
tracing and metrics, .NET 10 support, and **drops .NET 6.0**."

**Impact:** a team on .NET 6 reads the docs' client map, picks the current `NATS.Net` package, and
the build fails on target framework. Not silent — which is why this is `medium` and not ★ — but the
docs' own client-selection page is the wrong place to learn it. The correct advice for a .NET 6
service is to pin the v2 line or move the runtime first.

**Suggested fix:** change the cell to name the supported targets, e.g. "`netstandard2.0/2.1`,
`net8.0`, `net10.0` (v3); .NET 6 users must stay on v2". Better still, drop the version from the
prose and link the repo's target-framework list, which is what actually moves.

---

## 9 · `nats.deno` is listed as archived; it is not

**`concepts/ecosystem.md`**:

> | JavaScript / TypeScript | nats-io/nats.js | Node, Deno, Bun, browser (WebSocket). Supersedes **the archived** `nats.node`, `nats.deno`, `nats.ws`, `nats.ts` |

**Authority: the GitHub API, fetched 2026-08-31** (`raw/github-repos/`):

| repo | `archived` | last pushed |
|---|---|---|
| `nats-io/nats.node` | `true` | 2025-12-15 |
| `nats-io/nats.ws` | `true` | 2025-12-15 |
| `nats-io/nats.ts` | `true` | 2023-02-24 |
| **`nats-io/nats.deno`** | **`false`** | 2025-12-15 |

Three of the four are archived. `nats.deno` is superseded — `nats.js`'s own README says "This
repository now supersedes: nats.deno, nats.ws" — but it is not archived, so the sentence is right
about supersession and wrong about the state of one repo.

**Impact:** low. A reader checking `nats.deno` finds a live repository and may reasonably conclude it
is still maintained.

**Suggested fix:** either archive `nats.deno` (which is presumably the intent, given its siblings) or
reword to "Supersedes `nats.node`, `nats.deno`, `nats.ws` and `nats.ts`", dropping the claim about
their archive state.

---

## 10 · The Python client now ships two packages, and no docs page says which to install

Three docs pages touch the Python client and none of them resolves it:

1. **`concepts/ecosystem.md`** names the repo and describes it as "asyncio-based, Python 3 only". No
   package name.
2. **`concepts/getting-started.md`** has an "Install Client Libraries" section with lines for
   JavaScript, Go, Java, Rust and .NET — and **no Python line at all**, though it links the Python
   repo in its closing list.
3. **`learn/websocket/your-first-websocket-connection.md`** is the only page in the whole tree that
   names a Python package, and it names a different one:

   > "The `nats-core` client keeps its WebSocket transport behind an optional extra, so plain
   > `pip install nats-core` can't open a `ws://` connection — install `nats-core[websocket]`.
   > **It's the new Python client** and needs **Python 3.13 or later**."

**Authority: PyPI and the repository, checked 2026-08-31.** Both packages exist and both point at
`nats-io/nats.py`:

| package | version | `requires_python` | summary |
|---|---|---|---|
| `nats-py` | 2.15.0 | **>=3.7** | "NATS client for Python" |
| `nats-core` | **0.2.0** | **>=3.13** | "NATS core implementation in Python" |

The repository root confirms the split — alongside `nats/` it holds `nats-core/`, `nats-jetstream/`,
`nats-key-value/` and `nats-server/` directories — while the repo's own README documents only
`nats-py` and `nats-server` and states "Should be compatible with at least Python +3.8".

**Impact:** a Python reader following the docs cannot tell which package to install, and the one
package the docs do name is a 0.2.0 release with a Python floor five minor versions above the mature
client's. The claim on the WebSocket page is *correct*, which is why this is `missing` rather than
`wrong-value` — the defect is that it is the only place it appears.

**Suggested fix:** give `concepts/getting-started.md` a Python install line (`pip install nats-py`),
and say in `concepts/ecosystem.md` that the Python client publishes `nats-py` today with a modular
`nats-core` line in progress, with its 3.13 floor. The same modular split already happened to
[[nats-js]] and the docs handle that one well — the Python entry can follow the same pattern.

---

## 11 · An unset `cluster.name` is adopted from the peer, not rejected

Two learn pages state the cluster-name rule as an absolute, and it is not one.

`learn/clustering/forming-a-cluster.md`:

> "`name` is the cluster identifier, `east`. Every server that should join must set the exact same
> name. A route to a server whose name differs is rejected the moment the names are compared … so the
> odd server forms a separate cluster of its own."

`learn/topologies/your-first-cluster.md`:

> "A typo in `name` doesn't raise an error. The server with the odd name forms its own cluster and
> never joins `east`."

Both describe the **configured-name** case correctly, including the log line. Neither states what
happens when a server has **no** `cluster { name }` at all — which is the default, since
`reference/config/cluster/name.md` gives the key no default and says only "Name of the cluster."

**Evidence** — `server/route.go` at **v2.14.6**, the check when accepting a route
(`processRouteConnect`, lines 3052–3078), quoted in `raw/nats-server-src/route-v2.14.6.md`:

```go
3052:	// If we have a cluster name set, make sure it matches ours.
3053:	if proto.Cluster != clusterName {
3054:		shouldReject := true
3055:		// If we have a dynamic name we will do additional checks.
3056:		if srv.isClusterNameDynamic() {
3057:			if !proto.Dynamic || strings.Compare(clusterName, proto.Cluster) < 0 {
3058:				// We will take on their name since theirs is configured or higher then ours.
3059:				srv.setClusterName(proto.Cluster)
…
3068:				srv.removeAllRoutesExcept(remoteID)
3069:				shouldReject = false
3070:			}
3071:		}
3072:		if shouldReject {
3073:			errTxt := fmt.Sprintf("Rejecting connection, cluster name %q does not match %q", proto.Cluster, clusterName)
…
3076:			c.closeConnection(ClusterNameConflict)
```

The same branch exists on the soliciting side, on an async INFO (`processRouteInfo`,
`route.go:571–584`, `s.isClusterNameDynamic()` at `:576`), where the adoption likewise calls
`s.removeAllRoutesExcept(…)` — the joiner drops every other route it holds at that moment.

So the real rule has two branches:

| this server's `cluster.name` | peer's name differs | outcome |
|---|---|---|
| **configured** | configured | route rejected, `ClusterNameConflict`, two clusters |
| **unset** (dynamic) | configured | **this server takes the peer's name** and drops its other routes |
| **unset** (dynamic) | also unset | the lexicographically higher name wins |

The server itself warns about it, and neither page mentions the warning
(`server/route.go:2718–2720`):

```go
s.Noticef("Cluster name is %s", clusterName)
if s.isClusterNameDynamic() {
	s.Warnf("Cluster name was dynamically generated, consider setting one")
}
```

**Impact.** An operator who omits `name` on one node does not get the documented symptom (a split
cluster). They get a node that joins — possibly the *wrong* cluster, if two clusters share a route
network — under a name nobody configured, having dropped its existing routes to do so. The
documented advice ("set the identical name on every server") happens to prevent it, which is why
this is `missing` rather than `wrong-value`.

**Suggested fix.** On `reference/config/cluster/name.md`, state that an unset name is generated and
that the server will adopt a peer's configured name. On both learn pages' pitfall sections, add one
sentence: *a mismatch splits the cluster only when both names are configured; an unset name is
adopted from the peer* — and name the two log lines
(`Cluster name is …`, `Cluster name was dynamically generated, consider setting one`), which are the
only local, credential-free way to check.

---

## 12 · The hardening page's systemd extract drops the two lines that make it a service · enhancement

`learn/deployment/hardening.md` says "The NATS distribution ships a hardened unit
(`nats-server-hardened.service`) … you adapt it rather than write it from scratch", and then shows an
extract of it. The file it names exists at `util/nats-server-hardened.service` (checked at
**v2.14.6**, saved verbatim in `raw/nats-server-src/systemd-units-v2.14.6.md`), and the page's
extract is accurate as far as it goes. What it omits, from a page whose whole subject is running the
server safely:

| in the shipped unit | in the docs extract | why it matters |
|---|---|---|
| `User=nats` / `Group=nats` | absent | the extract, run as shown, starts the server **as root** — on a hardening page |
| `ExecStop=/bin/kill -s SIGUSR2 $MAINPID` | absent | without it `systemctl stop` is SIGTERM: clients are dropped rather than drained through lame-duck mode |
| `TimeoutStopSec=150` | absent | systemd's default stop timeout is shorter than `lame_duck_duration` (`2m`), so a drain gets killed partway |
| `Restart=on-failure`, `RestartSec=5` | absent | the unit does not come back |
| `EnvironmentFile=-/etc/default/nats-server` | absent; the page puts `GOMEMLIMIT` in the unit | the shipped file recommends the environment file so a limit change needs no `daemon-reload` |

The page's own pitfall about `MemoryMax` is good advice that the shipped unit already encodes by
leaving every resource cap commented out.

**Why this is `enhancement` and not a defect:** the page tells you to copy the real file and adjust
three fields, so a reader who follows the instruction gets all of the above. Only a reader who copies
the code block — the thing code blocks invite — loses them.

**Suggested fix.** Add `User=`, `Group=`, `ExecStop=` and `TimeoutStopSec=` to the extract (four
lines), or label the block explicitly as a partial extract with a link to the file. The `ExecStop`
line is also the missing connection to `learn/deployment/rolling-upgrades.md`, which teaches the same
drain as `kill -SIGUSR2 $(cat /var/run/nats/nats.pid)` and never mentions that a systemd deployment
already has it wired to `systemctl stop`.

---

## 13 · `lame_duck_duration` does not bound JetStream's work ★

`learn/deployment/rolling-upgrades.md` makes two claims about what the duration covers:

> "Set the duration to comfortably cover how long your clients take to reconnect *and* how long
> JetStream needs to move leadership off this node. A duration shorter than the rebalance drops
> clients before the stream has caught up."

and, in Pitfalls:

> "**A `lame_duck_duration` shorter than the rebalance drops clients early.** If you set the duration
> to `30s` but JetStream needs `45s` to move the `ORDERS` leadership and resync replicas off the
> node, the node kicks its clients and exits while the stream is still catching up."

**The ordering in the code excludes that race.** `Server.lameDuckMode()` at **v2.14.6**
(`server/server.go:4439–4565`, quoted in `raw/nats-server-src/lame-duck-v2.14.6.md`) does the
JetStream work first and only then computes the client-close schedule:

```go
4465:	// If we are running any raftNodes transfer leaders.
4466:	if hadTransfers := s.transferRaftLeaders(); hadTransfers {
4467:		// They will transfer leadership quickly, but wait here for a second.
4468:		select {
4469:		case <-time.After(time.Second):
…
4474:	// Now check and shutdown jetstream.
4475:	s.shutdownJetStream()
4477:	// Now shutdown the nodes
4478:	s.shutdownRaftNodes()
…
4496:	dur := int64(opts.LameDuckDuration)
4497:	dur -= int64(gp)
```

`transferRaftLeaders()` (`server/raft.go:883–906`) calls `StepDown()` on every Raft node the server
holds and marks each an observer; the only wait it gets is the **fixed one second** at line 4469.
Nothing between lines 4465 and 4478 consults `LameDuckDuration`.

**Two further numbers the page does not give**, both from the same range:

| the page implies | the code does |
|---|---|
| clients are spread over `lame_duck_duration` | over **`lame_duck_duration` − `lame_duck_grace_period`** (`:4496–4497`) |
| a larger duration spreads them further | the per-client interval is **capped at one second** (`:4514–4518`), so 10 clients drain in ~10s at any duration |

**Impact.** An operator following the page raises `lame_duck_duration` — and on Kubernetes must then
raise `terminationGracePeriodSeconds` with it, per the chart's own rule — to buy time for work that
the timer never waited for. The knob that actually protects the stream is the page's own `current`
gate between nodes, which the page states correctly.

**Suggested fix.** Say that `lame_duck_duration` is the window over which **client connections** are
closed, minus the grace period and capped at one second per client; that Raft stepdown and JetStream
shutdown complete before it starts, with their own fixed one-second wait; and that the protection
against taking down a still-syncing node is the `current` gate, not the duration. The Pitfalls entry
can then be re-aimed at the real failure — starting the next node before the previous one is
`current`.

---

## 14 · Two different "grace periods" two paragraphs apart · enhancement

Same page. First, about the NATS key:

> "`lame_duck_grace_period` (default `10s`) is how long the node waits before it starts kicking
> clients … **The grace period must be shorter than the duration.**"

Then, about Kubernetes:

> "The chart defaults `lame_duck_duration` to `30s` and `terminationGracePeriodSeconds` to `60s`. If
> you raise the duration, **raise the grace period above `lame_duck_duration`** plus shutdown
> overhead too, or the kubelet SIGKILLs the node mid-drain."

The same words carry **opposite** requirements: `lame_duck_grace_period` must be *below* the
duration (enforced at startup — `server/server.go:1152`), while `terminationGracePeriodSeconds` must
be *above* it. A reader who applies the second sentence to the first key gets a server that refuses
to start:

```
lame duck grace period (60s) should be strictly lower than lame duck duration (30s)
```

**Suggested fix.** Name the key in the second sentence: "raise `terminationGracePeriodSeconds`".
The chart's own comment already does this correctly — `podTemplate.terminationGracePeriodSeconds`
"should be at least `lameDuckGracePeriod` + `lameDuckDuration` + 20s shutdown overhead"
(`helm/charts/nats/values.yaml` at chart release `nats-2.14.6`).

---

## 15 · A memory stream fails with `no impl`, not the documented message ★

`learn/backup-recovery/stream-backup-restore.md`, Pitfalls:

> "**Memory streams cannot be snapshotted.** A snapshot reads a stream's on-disk files, so a stream
> with `Storage: Memory` has nothing to read. The backup fails with
> `memory streams do not support snapshots`."

The behaviour is right. The message is not — that string does not exist in `nats-server` at
**v2.14.6**. What a memory stream's store returns is (`server/memstore.go:2424–2426`, quoted in
`raw/nats-server-src/snapshot-restore-v2.14.6.md`):

```go
func (ms *memStore) Snapshot(_ time.Duration, _, _ bool) (*SnapshotResult, error) {
	return nil, fmt.Errorf("no impl")
}
```

`mset.snapshot()` passes the store's error straight up (`server/stream.go:9086–9092`) and the API
handler wraps it (`server/jetstream_api.go:4206–4209`):

```go
		sr, err := mset.snapshot(0, req.CheckMsgs, !req.NoConsumers)
		if err != nil {
			s.Warnf("Snapshot of stream '%s > %s' failed: %v", mset.jsa.account.Name, mset.name(), err)
			resp.Error = NewJSStreamSnapshotError(err, Unless(err))
```

`JSStreamSnapshotErrF` is error **10064**, whose description is the template `snapshot failed:
{err}` (`reference/jetstream/errors.md:170`). So the operator sees:

```
snapshot failed: no impl (10064)
```

and the server logs `Snapshot of stream '<account> > <stream>' failed: no impl`.

**The `nats` CLI does not soften it either.** `nats stream backup` at natscli **v0.4.0** has no
storage-type branch (`cli/stream_command.go:417–425`, `:1465`), so nothing produces a friendlier
message before the request goes out.

**Impact.** This is the exact question operators ask
([question-bank Q32](https://github.com/nats-io/nats-server/discussions/4342)), and `no impl` is
unsearchable: it appears in no documentation, matches no error page, and does not name the cause. A
reader who searches the documented string finds a page that says the failure will look nothing like
what they are seeing.

**Suggested fix.** Two options, and the first is cheap: quote the real error on the page
(`snapshot failed: no impl (10064)`) and explain it. Better, give `memStore.Snapshot` a real message
— `fmt.Errorf("memory streams do not support snapshots")` — which would make the documentation
correct as written.

---

## 16 · The restore rename error is the CLI's, and is quoted in the singular

Same page:

> "the server rejects a restore that would rename the stream with
> `stream name may not be changed during restore`"

Two corrections, both from `natscli` **v0.4.0** (`cli/stream_command.go:1296–1312`, quoted in
`raw/github-repos/nats-io__natscli.stream-backup-v0.4.0.md`):

```go
		// we need to confirm this new config has the same stream
		// name as the snapshot else the server state can get confused
		// see https://github.com/nats-io/nats-server/issues/2850
		if bm.Config.Name != cfg.Name {
			return fmt.Errorf("stream names may not be changed during restore")
		}
```

1. It is the **client** that produces this message, not the server — and only when `--config` is
   passed, because that is the only way the CLI can be handed a differing name.
2. The text is `stream names` (**plural**), so the documented string does not match.

The **server's** own rejection is different: a name that does not match the restore subject returns
`NewJSStreamMismatchError()` — error **10060** `JSStreamNotMatchErr`, "expected stream does not
match" (`server/jetstream_api.go:3832–3835`).

**Impact.** Low, but it is an error string, and error strings get grepped, alerted on and pasted into
search engines.

**Suggested fix.** Quote the CLI message verbatim and say it is the CLI's, or quote the server's
10060 for the API path.

---

## 17 · The snapshot schema's `chunk_size` maximum is off by ~9 quintillion

`reference/jetstream/api/stream/snapshot.md` documents the request fields:

| field | documented range |
|---|---|
| `chunk_size` | Minimum `1024`, **Maximum `9223372036854776000`** |
| `window_size` | Minimum `1024`, Maximum `33554432` |

The server clamps both (`server/jetstream_api.go:4277–4280`, v2.14.6):

```go
	chunkSize = min(max(1024, chunkSize), 1024*1024) // Clamp within 1KiB to 1MiB
	wndSize = min(max(1024, wndSize), 32*1024*1024)  // Clamp within 1KiB to 32MiB
```

`window_size`'s documented 32 MiB maximum is exactly right. **`chunk_size`'s is not**: the real
ceiling is **1 MiB**, and a larger request is silently clamped rather than rejected — so a client
asking for 8 MiB chunks gets 1 MiB chunks and no indication that anything was ignored.

This is the same shape as issues #1–3: a **generated** reference page carrying a value the server
contradicts, where the generator has emitted the field's type bound in place of its validated range.

**Suggested fix.** Emit `1048576` as `chunk_size`'s maximum, the way `window_size`'s is emitted.

---

## 18 · A restore can change everything but the name, and the chapter never says so

`learn/backup-recovery/stream-backup-restore.md` presents restore as reproducing the original:

> "Restore … recreates the stream from it: same messages, same sequence numbers, same
> configuration."

and the only escape it offers is:

> "If you do need a second copy under a new name, restore to `ORDERS` first and then mirror or source
> it."

`nats stream restore` at natscli **v0.4.0** takes four flags neither that page nor
`learn/backup-recovery/disaster-recovery.md` mentions
(`cli/stream_command.go:427–434`):

| flag | help text |
|---|---|
| `--config <file>` | "Load a different configuration when restoring the stream" |
| `--cluster <name>` | "Place the stream in a specific cluster" |
| `--tag <tag>` | "Place the stream on servers that has specific tags (pass multiple times)" |
| `--replicas <n>` | "Override how many replicas of the data to create" |

`--cluster` and `--tag` become the restored stream's `Placement` (`:1313–1318`).

**Impact.** These are exactly the flags a disaster-recovery reader needs — "restore the production
R3 snapshot into the DR cluster as R1" is one command, and the chapter's own DR page never offers
it, framing cross-site recovery solely as mirror promotion. The name is the one thing that genuinely
cannot change, and the reason is linked in the CLI source (`nats-server` issue #2850).

**Suggested fix.** Add the four flags to the restore section, and a line to the DR page's restore
path: a snapshot can be restored into another cluster, on tagged servers, at a different replica
count.

---

## 19 · Fifteen timeout defaults in the generated config reference ★

**Impact: every documented default for a TLS handshake or authentication budget is wrong**, and one
of them is wrong in a way that matters operationally — auth callout's deadline is
`authorization { timeout }`, so anyone sizing an auth service against the documented `1` is planning
against a third of the real budget.

Authority: `nats-io/nats-server` at **v2.14.6**, quoted in
`raw/nats-server-src/auth-tls-v2.14.6.md`.

```go
TLS_TIMEOUT              = 2 * time.Second   // const.go:108
AUTH_TIMEOUT             = 2 * time.Second   // const.go:117
DEFAULT_LEAF_TLS_TIMEOUT = 2 * time.Second   // const.go:165
```

```go
func getDefaultAuthTimeout(tls *tls.Config, tlsTimeout float64) float64 {   // opts.go:6191
	var authTimeout float64
	if tls != nil {
		authTimeout = tlsTimeout + 1.0
	} else {
		authTimeout = float64(AUTH_TIMEOUT / time.Second)
	}
	return authTimeout
}
```

**The sweep.** Every `timeout` key of both families in `inbox/config-keys-table.md` was checked
against `setDefaults` in `opts.go`:

| documented key | docs say | server | evidence |
|---|---|---|---|
| `tls.timeout` | `500ms` | **2s** | `opts.go:6021–6023` |
| `cluster.tls.timeout` | `500ms` | **2s** | `opts.go:6031–6033` |
| `leafnodes.tls.timeout` | `500ms` | **2s** | `opts.go:6076–6078` |
| `gateway.tls.timeout` | `500ms` | **2s** | `opts.go:6144–6146` |
| `mqtt.tls.timeout` | `500ms` | **2s** | `opts.go:6166–6168` |
| `leafnodes.remotes.tls.timeout` | `500ms` | **2s** | `opts.go:3155`, `DEFAULT_LEAF_TLS_TIMEOUT` |
| `websocket.tls.timeout` | `500ms` | **no such option** | `WebsocketOpts` has no `TLSTimeout` field; it carries `HandshakeTimeout` for the whole websocket handshake |
| `gateway.gateways.tls.timeout`, `resolver_tls.timeout` | `500ms` | *not checked* | the per-remote parse takes `tlsopts.Timeout` (`opts.go:3335`) with no default assignment found |
| `authorization.timeout` | `1` | **2s**, or `tls_timeout + 1` | `opts.go:6024–6026` |
| `cluster.authorization.timeout` | `1` | same rule | `opts.go:6034–6036` |
| `leafnodes.authorization.timeout` | `1` | same rule | `opts.go:6079–6081` |
| `gateway.authorization.timeout` | `1` | same rule | `opts.go:6147–6149` |
| `mqtt.authorization.timeout`, `websocket.authorization.timeout` | `1` | *not checked* | both blocks parse `auth.timeout` (`opts.go:5666`, `:5574`) |

**Of 15 keys, 10 are verified wrong, 1 documents an option that does not exist, and 4 were not
checked.** No key of either family was found where `500ms` or `1` is correct.

**Two further problems in the same pages.** The generated reference gives
`authorization.timeout` **no default at all** on its own property page
(`reference/config/authorization/timeout.md`) while the parent table states `1` — so the two
generated pages disagree with each other. And `tls.timeout`'s documented type is `duration`, while
the parser accepts "a float in seconds **or** a duration string" (`opts.go:5222–5232`); the
hand-written learn page uses the float form (`timeout: 2`) that the reference's type forbids.

**The hand-written pages are closer to right than the generated ones**, again: `learn/security/
encryption.md` says the TLS handshake default "is `2`", which matches the server.

**Suggested fix.** Emit `2s` for every `tls.timeout` and drop the `websocket.tls.timeout` page.
For the auth family, state the rule rather than a number: *2 seconds, or `tls_timeout + 1` when TLS
is configured on the same listener.*

## 20 · Certificate expiry is on `/varz` and the docs never say so ★

**Impact: the docs tell operators to do something they give them no way to do.**
`learn/security/encryption.md` closes its rotation pitfall with "A certificate that expires unnoticed
fails as a handshake rejection, not an auth error — **monitor validity dates** and pair renewal with
the reload signal", and names no mechanism. The public thread that asked for one
([gh#7684](https://github.com/nats-io/nats-server/discussions/7684)) ends with a maintainer pointing
at [PR #7709](https://github.com/nats-io/nats-server/pull/7709), which shipped the field.

**It is in the server this docs tree describes.** At v2.14.6:

```go
TLSCertNotAfter time.Time `json:"tls_cert_not_after,omitzero"`   // monitor.go:1296
```

filled for the client listener and for `cluster`, `gateway`, `leafnode`, `mqtt` and `websocket`
(`monitor.go:1838–1845`), from the leaf certificate of the first configured certificate
(`tlsCertNotAfter`, `monitor.go:1485–1498`).

**The docs' evidence.** `grep -r tls_cert_not_after` over the 861-page tree fetched 2026-08-31
returns **nothing** — not in `learn/security/encryption.md`, not in
`learn/monitoring/monitoring-endpoints.md`, not in `learn/deployment/hardening.md`, which is the page
that tells you to rotate ahead of expiry.

**Also unmentioned: `nats account tls`**, in the CLI the docs recommend (natscli **v0.4.0**,
`cli/account_tls_command.go`), which does exactly this job across the whole verified chain, with
`--expire-warn` defaulting to `1w` and a non-zero exit for a monitoring pipeline. It appears on no
docs page either.

**Suggested fix.** Add `tls_cert_not_after` to the monitoring endpoint page's `/varz` field list, and
replace "monitor validity dates" on the TLS page with the two concrete checks.

## 21 · The `external` block is required, undocumented, and pointed at the wrong page ★

**Impact: cross-account and cross-domain replication is unbuildable from the docs**, and the failure
is silent — "Get a type wrong and replication doesn't fail with an error; the mirror never catches
up", by the docs' own admission.

`learn/jetstream/mirrors-and-sources.md` says:

> "Reaching a stream in another account or JetStream domain needs the `external` block plus matching
> exports and imports on both sides… Check each import type against
> [Reference → Stream Configuration](/reference/jetstream/api/stream/create.md)."

**That reference page does not mention `external`.** Neither does any other. `grep -r` over the tree
for `api_prefix`, `deliver_prefix`, `"external"` and `external:` returns **nothing**.

The fields exist and are two lines long (`stream.go:425–429` at v2.14.6):

```go
// ExternalStream allows you to qualify access to a stream source in another account or domain.
type ExternalStream struct {
	ApiPrefix     string `json:"api"`
	DeliverPrefix string `json:"deliver"`
}
```

They are a field of `mirror` and of every entry of `sources` (`stream.go:397`, `:412`), validated by
three error codes the docs do not connect to them — **10021**, **10022** and **10024** — and applied
by substitution on the API subject (`stream.go:2818`).

**The same gap is visible from the other side.** `learn/security/cross-account.md` builds the whole
export/import model and never mentions JetStream;
[gh#7017](https://github.com/nats-io/nats-server/discussions/7017), "Sharing a KV Store with Multiple
Accounts – Is It Supported?", says "I looked for documentation about this but wasn't successful" and
**has had no reply since 2025-06-29**. The only public answer is one line in
[gh#5606](https://github.com/nats-io/nats-server/discussions/5606): "You should be able to import the
foreign account jetstream API and manage it using the API prefix options in clients and CLI."

**Suggested fix.** Document `external.api` and `external.deliver` on the stream configuration
reference, and add a cross-account JetStream section to `learn/security/cross-account.md` with the
three subject types and their required export kinds.


## 22 · Four defaults in the generated `jetstream` block, including the one everyone quotes ★

**Impact: production servers left on the auto-sized storage limit fail to restart.** This is not a
cosmetic wrong number — the docs' description of `max_file_store` is what makes operators leave it
unset, and leaving it unset is what breaks the restart.

### The headline: `max_file_store`

`reference/config/jetstream/max_file_store.md`, and the same sentence in the parent table
`reference/config/jetstream.md`:

> "Maximum size of the *file* storage. Defaults to up to 1TB if available."

The server (`server/jetstream.go:2760–2764` at v2.14.6):

```go
	if maxStore > 0 || (opts.maxStoreSet && maxStore == 0) {
		jsc.MaxStore = maxStore
	} else {
		jsc.MaxStore = diskAvailable(jsc.StoreDir)
		jsc.maxStorePending = true
	}
```

and `server/disk_avail.go:28–35`:

```go
	var fs syscall.Statfs_t
	if err := syscall.Statfs(storeDir, &fs); err == nil {
		// Estimate 75% of available storage.
		ba = int64(uint64(fs.Bavail) * uint64(fs.Bsize) / 4 * 3)
	} else {
		// Used 1TB default as a guess if all else fails.
		ba = JetStreamMaxStoreDefault
	}
```

**1 TB is the `statfs`-failure fallback**, named `JetStreamMaxStoreDefault` and reached only in the
`else`. The default is **75% of the space free under `store_dir` at startup**.

Three things follow that the docs never say:

1. **It is 75% of *free* space, not of the volume**, so it falls as JetStream fills the disk. Before
   nats-server **2.14.6** the ceiling ratcheted downwards at every restart until the server could no
   longer restore its own streams —
   [issue #8322](https://github.com/nats-io/nats-server/issues/8322),
   [issue #5871](https://github.com/nats-io/nats-server/issues/5871) — with the reproduction being
   four lines: 512 MB volume → limit 338 MB → 300 MB stream → fill 250 MB → restart → limit 196 MB →
   `insufficient storage resources available (10047)`. Fixed by PR
   [#8503](https://github.com/nats-io/nats-server/pull/8503) (merged 2026-08-24, first in v2.14.6;
   `finalizeDynamicMaxStore` is absent from v2.14.5).
2. **The maintainers say not to use it in production, twice, and neither statement is in the docs.**
   @derekcollison, 2024-09-10: *"We do not recommend auto-sizing for real world production uses…
   Auto detection is for development and testing."* @MauriceVanVeen, 2026-06-18: *"Production-grade
   systems… shouldn't rely on these dynamic values."* The reporter asked directly — *"Is this
   recommendation to avoid the default value mentioned anywhere in the docs?"* — and was answered
   *"Not sure about the docs"*.
3. **`max_file_store: 0` means zero, not unlimited.** The condition above takes an explicitly set `0`
   literally, so no stream can be created. A reporter hit exactly this: *"It also no longer seems to
   be possible to specify there should be no limit, as setting the value to 0 (as mentioned in the
   docs) prevents the creation of any stream."*

The **hand-written** page has it right — `learn/deployment/sizing-and-resources.md` says "**File
storage** defaults to 75% of the disk space actually available under `store_dir`, falling back to
**1 TB** only when the platform can't report disk size". This is the same generated-vs-hand-written
split as #1–3 and #19.

### The sweep: every value in the block, checked

`reference/config/jetstream.md` states ten defaults. All ten were checked against v2.14.6; **four are
wrong**.

| key | docs | server | evidence |
|---|---|---|---|
| `max_file_store` | "up to 1TB if available" | **75% of free space under `store_dir`** | `jetstream.go:2763`, `disk_avail.go:31` |
| `max_buffered_msgs` | `10000` | **100000** | `streamDefaultMaxQueueMsgs`, `stream.go:441`; applied `stream.go:900–904` |
| `max_outstanding_catchup` | `32M` | **64MB** | `defaultMaxTotalCatchupOutBytes`, `jetstream_cluster.go:11158`; applied `jetstream.go:424–425` |
| `info_queue_limit` | `100000` | **`request_queue_limit`**, so 10000 unless set | `opts.go:6183–6185` |
| `max_buffered_size` | `128MB` | 128MB ✓ | `stream.go:442` |
| `request_queue_limit` | `10000` | 10000 ✓ | `JSDefaultRequestQueueLimit`, `jetstream_api.go:367` |
| `sync_interval` | `2m` | 2m ✓ | `defaultSyncInterval`, `filestore.go:333` |
| `strict` | `true` | true ✓ | `jetstream.go:2754` |
| `store_dir` | `/tmp/nats/jetstream` | `os.TempDir()/nats/jetstream` ✓ | `jetstream.go:2747` |
| `max_memory_store` | "75% of available memory" | 75% of **total** memory, or `GOMEMLIMIT`; 256MB fallback | `jetstream.go:2769–2781` |

The last row is terse rather than wrong — the server's own comment says "Estimate to 75% of **total**
memory" and the 256 MB fallback and `GOMEMLIMIT` cap are simply absent from the page.

**The two siblings are described inconsistently with each other**, which is the tell:
`max_memory_store` says "75% of available memory" and `max_file_store` says "up to 1TB". They are the
same mechanism, ten lines apart in the same function.

**Suggested fix.** Change `max_file_store`'s description to match its sibling — "Defaults to 75% of
the disk space free under `store_dir` at startup; falls back to 1 TB only when the platform cannot
report disk size" — correct the three numeric defaults, state that `info_queue_limit` inherits
`request_queue_limit`, note that an explicit `0` disables the storage class, and add the maintainers'
production guidance to `learn/deployment/sizing-and-resources.md`, which already has the arithmetic
right.




## 23 · Three topology ports documented with defaults the server does not apply ★

**Impact: two of the three fail silently**, and the third stops the server after `nats-server -t` has
said the file is fine.

The generated block tables state a `Default` for each listener port:

| page | key | documented default |
|---|---|---|
| `reference/config/cluster.md` | `port` | `6222` |
| `reference/config/leafnodes.md` | `port` | `7422` |
| `reference/config/gateway.md` | `port` | `7222` |

The server applies none of them, and the three consequences differ.

**Evidence — gateway** (`server/gateway.go`, v2.14.6). `validateGatewayOptions`:

```go
316:	if o.Gateway.Port == 0 {
317:		return fmt.Errorf("gateway %q has no port specified (select -1 for random port)", o.Gateway.Name)
318:	}
```

**Evidence — leafnodes** (`server/leafnode.go`, v2.14.6). `validateLeafNodeOptions` returns before
any listener work when the port is zero, and no accept loop is started:

```go
328:	if o.LeafNode.Port == 0 {
329:		return nil
330:	}
```

**Evidence — the one real use of 7422** (`server/opts.go`, v2.14.6). `DEFAULT_LEAFNODE_PORT`
(`const.go:206`) fills in a missing port on a **remote's URL**, never a listener:

```go
6091:	// Set baseline connect port for remotes.
6092:	for _, r := range opts.LeafNode.Remotes {
6093:		if r != nil {
6094:			for _, u := range r.URLs {
6095:				if u.Port() == _EMPTY_ {
6096:					u.Host = net.JoinHostPort(u.Host, strconv.Itoa(DEFAULT_LEAFNODE_PORT))
```

**Evidence — the `host` defaults are real, and gated on the port** (`opts.go:6072–6074`,
`:6140–6142`): `DEFAULT_HOST` is applied only inside `if opts.LeafNode.Port != 0 {` and
`if opts.Gateway.Port != 0 {`. The same table is therefore right about `host` and wrong about `port`,
which is part of what makes the error easy to miss.

**Observed on nats-server v2.14.6.**

```
$ cat lf.conf
listen: 127.0.0.1:4222
leafnodes { }
$ nats-server -c lf.conf
[INF] Listening for client connections on 127.0.0.1:4222
$ lsof -nP -iTCP -sTCP:LISTEN -a -p <pid>
nats-serv 127.0.0.1:4222
```

One listening socket, 4222. No 7422. `cluster { name: east }` with no port behaves the same way — no
6222. And the gateway case:

```
$ nats-server -c gw.conf -t
nats-server: configuration file gw.conf is valid (sha256:4d532…)
$ nats-server -c gw.conf
nats-server: gateway "east" has no port specified (select -1 for random port)
```

**Suggested fix.** Set the `Default` cell for all three keys to `—` and add a note per key: for
`cluster` and `leafnodes`, "if unset, the server does not listen for this connection type"; for
`gateway`, "required whenever a `gateway {}` block is present". 6222 / 7422 / 7222 are real as
**conventions** and belong in the prose, not in the Default column. `leafnodes/port.md` may also note
that 7422 *is* the port assumed for a remote URL that omits one.


## 24 · The chapter's own composed configuration does not start ★

**Impact: the page's central example — the one demonstrating its central idea — cannot be run**, and
the docs' recommended pre-flight check passes it.

`learn/topologies/putting-it-together.md` prints `n1-east.conf` under *One server, three roles*, with
`cluster {}`, `gateway {}`, `leafnodes { listen }` and `jetstream {}`, and calls it "all
'composition' means". It has no `system_account`, and the page states two sections later that the
chapter does not set one up: "To *survey* the whole fabric instead… you need the **system account**
(`$SYS`), which this chapter doesn't set up."

**Evidence** (`server/leafnode.go`, v2.14.6) — `validateLeafNodeOptions`, past its two early returns:

```go
343:	if o.Gateway.Name == _EMPTY_ && o.Gateway.Port == 0 {
344:		return nil
345:	}
346:	// If we are here we have both leaf nodes and gateways defined, make sure there
347:	// is a system account defined.
348:	if o.SystemAccount == _EMPTY_ {
349:		return fmt.Errorf("leaf nodes and gateways (both being defined) require a system account to also be configured")
350:	}
```

`opts.SystemAccount` is set only by `system_account:` (`opts.go:1038`) or a trusted operator
(`opts.go:1535`). The runtime fallback that creates `$SYS` (`server.go:2371–2373`) runs **after**
`validateOptions`, which is called inside `NewServer` at `server.go:729` — so it cannot satisfy the
check.

**Observed on nats-server v2.14.6**, with the page's config typed verbatim:

```
$ nats-server -c n1-east.conf -t
nats-server: configuration file n1-east.conf is valid (sha256:ddbe986aa9531262de2a5a88b79818e203cd2ae564edda74fdb1c1e9dd7c4431)
$ nats-server -c n1-east.conf
nats-server: leaf nodes and gateways (both being defined) require a system account to also be configured
```

**The second half of this issue is `-t` itself.** `learn/deployment/config-management.md` presents
`nats-server -c … -t` as the way to check a config before applying it, and qualifies it with one
exception: "A JetStream cluster missing `server_name` or `routes` passes `-t` yet still fails to
boot." That understates the boundary. `-t` parses and exits; **every** `validateOptions` check is
downstream of it. Another, observed on v2.14.6:

```
$ cat ld.conf
listen: 127.0.0.1:4222
lame_duck_duration: "30s"
lame_duck_grace_period: "60s"
$ nats-server -c ld.conf -t
nats-server: configuration file ld.conf is valid (sha256:bcaec…)
$ nats-server -c ld.conf
nats-server: lame duck grace period (1m0s) should be strictly lower than lame duck duration (30s)
```

**Suggested fix.** Add `system_account` (and the matching `accounts` block) to the composed example,
or drop the `gateway {}` block from it. And change the `-t` description in `config-management.md`
from an exception to a rule: `-t` validates syntax, not option semantics, so a config that must
survive a restart should be started once on a scratch server.


## 25 · The fast-producer stall, and both counters that expose it, are absent from the docs ★

**Impact: a mechanism documented nowhere is the answer to a recurring performance question**, and the
two fields that diagnose it are missing from the monitoring reference.

`grep -r` over the 861-page tree for `stalled_clients`, `"stalls"` and `Producer was stalled` returns
**nothing**. The only trace of the feature is the config key
`reference/config/no_fast_producer_stall.md`, whose complete description is: "Do not stall a fast
producer when a consumer cannot keep up. The server drops messages to the slow consumer instead." It
never says what the stall it disables *is*, how long it lasts, or how to see it happen.

**Evidence — the mechanism** (`server/client.go`, v2.14.6):

```go
125:	stallClientMinDuration = 2 * time.Millisecond
126:	stallClientMaxDuration = 5 * time.Millisecond
127:	stallTotalAllowed      = 10 * time.Millisecond
```

```go
3937:	if c.kind == CLIENT && client.out.stc != nil {
3938:		if srv.getOpts().NoFastProducerStall {
3941:			return false
3942:		}
3943:		client.stalledWait(c)
```

**Evidence — the observables** (`server/monitor.go`, v2.14.6):

```go
133:	Stalls         int64          `json:"stalls,omitempty"`
597:	ci.Stalls = atomic.LoadInt64(&client.stalls)
1279:	StalledClients        int64                  `json:"stalled_clients"`                   // StalledClients is the total number of times that clients have been stalled.
1909:	v.StalledClients = atomic.LoadInt64(&s.stalls)
```

and the log line (`server/client.go:1451`): `Producer was stalled for a total of %v`.

**Why it matters now.** [gh#7494](https://github.com/nats-io/nats-server/discussions/7494), open and
unanswered since 2025-10-30, reports a global super-cluster where adding a subscriber in a distant
cluster drops the **local** rate from 70–80k msg/s to 2k. That is this mechanism, plus the fact that
geo-affinity covers queue groups only. Neither half is stated in the docs, so the question is
unanswerable from them.

**The related gap in the same area.** `learn/topologies/super-clusters.md` describes geo-affinity as
"the message never crosses the gateway, because it doesn't need to". Its own summary line scopes it
correctly — "geo-affinity keeps queue-group and request traffic in its home region" — but nothing on
the page says what happens with a **plain** subscriber on the far side, which is the common case and
the one that produces the surprise. The implementation is an exclusion list over queue-group *names*
(`client.go:4482–4487`), and the gateway is skipped only when there is no plain-subscriber interest
either:

```go
2652:			if !psi && len(queues) == 0 {
2653:				continue
```

**Suggested fix.** Add `stalled_clients` to the `/varz` field list and `stalls` to `/connz` in
`learn/monitoring/monitoring-endpoints.md`, with a sentence on what a rising value means; expand
`no_fast_producer_stall`'s description to name the stall's 10 ms per-read-loop budget; and add one
sentence to the geo-affinity section of `super-clusters.md` saying that a plain (non-queue)
subscriber in a remote cluster receives every message, and geo-affinity does not apply to it.


## 26 · Four `leafnodes.remotes` keys are published with no description at all

**Impact: the two keys the only public question on this topic asks about are documented as their own
names.**

`reference/config/leafnodes/remotes.md` lists 20 properties. Sixteen carry a description. These four
carry an empty Description cell, and their own property pages contain nothing but a type table:

| key | default | description in the docs |
|---|---|---|
| `hub` | – | *(empty)* |
| `deny_imports` (alias `deny_import`) | – | *(empty)* |
| `deny_exports` (alias `deny_export`) | – | *(empty)* |
| `jetstream_cluster_migrate` (alias `js_cluster_migrate`) | `true` | *(empty)* |

[gh#5941](https://github.com/nats-io/nats-server/discussions/5941), "Proper way to configure Leaf
Nodes to only export some subjects", opens with: "In the docs I see mention of `deny_exports` and
`deny_imports`, but I can't really find any examples of people using this how I intend."

**Evidence — what the two deny keys are** (`server/leafnode.go`, v2.14.6):

```go
473:	if len(remote.DenyExports) > 0 || len(remote.DenyImports) > 0 {
474:		perms := &Permissions{}
475:		if len(remote.DenyExports) > 0 {
476:			perms.Publish = &SubjectPermission{Deny: remote.DenyExports}
477:		}
478:		if len(remote.DenyImports) > 0 {
479:			perms.Subscribe = &SubjectPermission{Deny: remote.DenyImports}
480:		}
```

`deny_exports` is a **publish** deny and `deny_imports` is a **subscribe** deny, both on the leaf's
own remote, and **neither has an `allow` counterpart** — which is exactly why the asker's stated goal
("default to exclude everything, then add an exception for one pattern") is not achievable with them,
and why the accepted answer redirects to user permissions instead.

**A follow-up in the same thread has been unanswered since 2024-12-18**, because that redirect does
not work in config mode: `leafnodes.authorization` users accept no `permissions` at all
(`parseLeafUsers`, `opts.go:3005–3064`, "a trimmed down version of parseUsers", four keys), and a
same-named entry in the global `authorization.users` block governs client connections, not leafnode
ones. Both reproduced on v2.14.6; the second is a parse error:

```
nats-server: hub2.conf:8:9: unknown field "permissions"
```

**Suggested fix.** Fill the four descriptions. For the deny keys, state the direction of each
("subjects this leaf will not publish to the remote" / "…will not subscribe for on the remote"), that
they are deny-only, and that the hub's own permissions for the leaf user are merged with them
(`leafnode.go:1715–1735`). And add to `learn/security/` a note that permissions on a **leafnode** user
require operator mode — in config mode the boundary is the account.


## How these were found

Not by looking for them. Each fell out of ingesting a source and cross-checking it against another:

- **1–3**: writing `wiki/reference/advisories.md` meant choosing between two subjects for the nak
  advisory, because the learn page and the reference page disagreed. Resolving that against the
  server source turned into a sweep of all 22 advisory pages, which found two more.
- **4–5**: writing `wiki/reference/defaults-and-limits.md` required defaults the docs do not carry.
- **6**: answering "what breaks above 8MB" (question-bank Q12) required knowing whether the boundary
  is enforced.
- **7**: writing the release entity pages put ADR dates and shipping versions side by side.
- **15–18**: writing the backup runbook meant answering question-bank Q32, which asks about
  **memory** streams specifically. Checking the documented error against `memstore.go` found #15;
  reading the CLI to confirm its flags found #16 and #18; and comparing the snapshot request's
  documented ranges against the server's clamps found #17.
- **13–14**: writing the upgrade runbook meant stating what `lame_duck_duration` is for. The docs
  give it two jobs; reading `Server.lameDuckMode()` showed it has one, and reading the same page
  twice showed "grace period" naming two different keys with opposite requirements.
- **11–12**: writing the install and cluster runbooks meant quoting commands and a unit file, and
  `CLAUDE.md` forbids quoting one this wiki has not read. Fetching `server/route.go` to check a log
  line found the dynamic-name branch; fetching `util/nats-server-hardened.service` to check the unit
  found what the page's extract leaves out.
- **19–21**: writing the TLS runbook meant naming a way to see a certificate's expiry, which the
  docs do not give — reading `server/monitor.go` for one found `tls_cert_not_after` (#20), and
  reading `opts.go` for the reload story found `getDefaultAuthTimeout`, which then justified a sweep
  of every timeout default in `inbox/config-keys-table.md` (#19). #21 came from the opposite
  direction: question-bank Q51 has an unanswered public thread, so the mechanism had to be read from
  `server/stream.go`, and the docs page that names the field turned out to point at a reference page
  that omits it.
- **23–26**: writing the topology pages meant quoting a `leafnodes {}` and a `gateway {}` block, and
  `CLAUDE.md` forbids quoting a config this wiki has not read. Typing the docs' own composed example
  into `nats-server` found #24 — and the `-t` half of it, which then had to be checked against
  `validateOptions` to see how wide the gap is. That check produced #23, a sweep of the three
  listener-port defaults. #25 came from the other direction: question-bank Q46 has an unanswered
  public thread with clean measurements, so the mechanism had to be read from `server/client.go` and
  `server/gateway.go` — and neither it nor its two counters exists anywhere in the tree. #26 fell out
  of writing the *what configures it* table for the leafnode page: four cells in the generated table
  are simply empty, and two of them are the subject of the only public question on leafnode subject
  restriction.
- **8–10**: writing one entity page per official client meant reading all twelve READMEs next to the
  docs' client table. Every claim in that table was checked against its repository; three did not
  survive. The two `wrong-value` rows are both **staleness in a hand-maintained table** — the docs
  page is correct as written for an earlier release of the thing it describes.

**The generalisable lesson for the docs:** the errors cluster in two places — **generated**
reference pages, and **quoted error strings in hand-written pages** (#15, #16), where the prose was
written from intent rather than from a run. Both are mechanically checkable against the server.

**The original observation still holds:** three of the first factual errors are all in **generated**
reference pages, and in all three cases a **hand-written** page (a learn page, an ADR) had the
correct value. A generator that cross-checked its output against the server constants it claims to
describe would have caught all three.

## 27 · The documented leafnode compression default is `accept`; the server uses `s2_auto` ★

**Impact: a leafnode link compresses by default, and the docs say it does not.** Compression is a
CPU/bandwidth trade, so this is the kind of default an operator sizes against — and the two values
produce visibly different connections.

`reference/config/leafnodes/compression.md`, *Properties*:

| Name | Type | Default | Reloadable |
|---|---|---|---|
| `mode` | `string` | `accept` | Yes |

`reference/config/leafnodes/remotes/compression.md` publishes the same `accept` for the remote side.
The same page explains what `accept` means, which is why the value matters:

> "The value of `accept` indicates it will inherit the mode of the server it is connecting to. If
> both have `accept`, no compression will be used."

**Evidence — the server** (`server/opts.go`, `setBaselineOptions()`, v2.14.6), for the listener and
for every remote, each with the comment stating the intent:

```go
6082:		// Default to compression "s2_auto".
6083:		if c := &opts.LeafNode.Compression; c.Mode == _EMPTY_ {
6087:				c.Mode = CompressionS2Auto

6099:			// Default to compression "s2_auto".
6100:			if c := &r.Compression; c.Mode == _EMPTY_ {
6104:					c.Mode = CompressionS2Auto
```

The `accept` default twenty lines earlier is the **route** (cluster) one, `opts.go:6061–6070` — where
the reference is right. The docs look like they carried the cluster value across to the leafnode
pages.

**Evidence — observed on v2.14.6** (`raw/nats-server-src/defaults-observed-v2.14.6.md`). A hub and a
leaf with nothing but a port and a remote URL:

```
$ curl -s http://127.0.0.1:8223/leafz | grep compression
      "compression": "s2_uncompressed"
```

`s2_uncompressed` is the level `s2_auto` picks while the RTT is under the first threshold
(`selectS2AutoModeBasedOnRTT`, `server/server.go:625`). Setting the *documented* default explicitly
on both sides gives a different connection:

```
$ curl -s http://127.0.0.1:8225/leafz | grep compression
      "compression": "off"
```

**Suggested fix:** set the `Default` cell on both leafnode compression pages to `s2_auto`, and check
whether the generator is copying the route block's defaults into the leafnode block — `gateway`'s
compression pages are worth the same look.

---

## 28 · `mqtt.max_ack_pending` is documented as 100; the server's default is 1024

`reference/config/mqtt.md`, *Properties*, states `100`. The key's own page
(`reference/config/mqtt/max_ack_pending.md`) explains the range `[0..65535]` and the 65535 session
total but states no default, so the parent table is the only place a reader can get one.

**Evidence** (`server/mqtt.go`, v2.14.6):

```go
149:	// This is the default for the outstanding number of pending QoS 1
150:	// messages sent to a session with QoS 1 subscriptions.
151:	mqttDefaultMaxAckPending = 1024
```

applied wherever the option is read — `mqttSessionCreate` (`mqtt.go:3336–3339`) and the two
subscription paths (`mqtt.go:5497–5500`, `mqtt.go:5633–5636`), all in the shape
`if maxAckPending == 0 { maxAckPending = mqttDefaultMaxAckPending }`.

Because the default is applied at the use site, the option itself stays zero, and `/varz` — which
tags the field `omitempty` — omits it, confirming the server holds no `100`:

```
$ curl -s http://127.0.0.1:8226/varz | jq .mqtt
{ "host": "0.0.0.0", "port": 1883, "tls_timeout": 2 }
```

`mqtt.ack_wait`'s documented `30s` is **correct** by the same mechanism (`mqttDefaultAckWait`,
`mqtt.go:147`), so this is one wrong cell in a table whose neighbours are right.

**Suggested fix:** `100` → `1024` in the `mqtt.md` properties table.

---

## 29 · `mqtt.port` is documented as `1883`; the server applies no default ★

**Impact: identical to #23 — a config that looks complete opens no listener, and the server says
nothing.** This is the fourth listener with a published default the server never applies; #23
covers `cluster.port`, `leafnodes.port` and `gateway.port`.

`reference/config/mqtt.md`, *Properties*, gives `port` the default `1883`. The string `1883` does
not appear anywhere in the non-test server source at v2.14.6.

**Evidence** (`server/mqtt.go`):

```go
689:func validateMQTTOptions(o *Options) error {
690:	mo := &o.MQTT
691:	// If no port is defined, we don't care about other options
692:	if mo.Port == 0 {
693:		return nil
694:	}
```

`server/websocket.go:1125` opens `validateWebsocketOptions()` with the same two lines — and the docs
are right about websocket, where they state no default port.

**Evidence — observed on v2.14.6**, `mqtt { }` with no port, JetStream enabled:

```
[4152] 2026/08/31 08:07:28.199923 [INF] Starting JetStream
   … no "Listening for MQTT clients" line …
$ curl -s http://127.0.0.1:8227/varz | jq .mqtt
{}
```

and with `port: 1883` set explicitly, the same binary logs
`[INF] Listening for MQTT clients on mqtt://0.0.0.0:1883`.

**Suggested fix:** state "no default" and say what omitting it does, as for `cluster.port` and
`leafnodes.port`. The four listener pages should be fixed together — one generator is producing all
of them.

---

## 30 · ADR-35 says a compression change reaches new blocks; it does not until the store restarts

**Impact: an operator turns compression on, sees `STREAM.INFO` report `s2`, and gets no compression
at all** — possibly for weeks, until the server happens to restart. The setting looks applied
because every surface says it is.

ADR-35, *Decision*:

> "The compression algorithm can be updated after the stream has been created. **Newly minted blocks
> will use the newly selected compression algorithm**, but this will not result in existing blocks
> being proactively compressed or decompressed."

The second clause is right. The first is not, at v2.14.6.

**Evidence — the source.** The algorithm the store writes with is `fs.fcfg.Compression`, set once
when the store is constructed:

```go
// server/stream.go:994, in addStreamWithAssignment
fsCfg.Compression = config.Compression
// …
// server/stream.go:1004
if err := mset.setupStore(fsCfg); err != nil {
```

`setupStore` has exactly one caller (`stream.go:1004`). A live update takes the other path,
`mset.store.UpdateConfig(cfg)` (`stream.go:2788`), and `fileStore.UpdateConfig`
(`filestore.go:686`) never assigns `fcfg.Compression` — the field has three readers
(`filestore.go:4971`, `:7769`, `:7848`) and no writer outside construction.

**Evidence — observed on the v2.14.6 binary** (full run in
`raw/nats-server-src/compression-purge-discovery-observed-v2.14.6.md`). A file stream created with
`compression: none`, edited to `s2` while running, then restarted. Block magic bytes: `636d7001` is
`cmp` + S2, `0a040000` is an uncompressed record header.

```
phase 1  (compression: none)          1.blk 31020 0a040000   2.blk 10340 0a040000
phase 2  (after --compression=s2)     1.blk 31020 0a040000   2.blk 31020 0a040000   3.blk 20680 0a040000
phase 3  (after a server restart)     3.blk   801 636d7001   4.blk   790 636d7001   5.blk 5170 0a040000
```

`2.blk` sealed **after** the edit, in the same server run, and is uncompressed at the full 31020
bytes. After the restart the same content compresses to ~800 bytes.

**The docs get this right**, which is the unusual part: `learn/jetstream/policies.md` says the new
setting "waits until the stream's store restarts, on a server restart or a leader change, and blocks
already on disk stay as they are". Only the ADR is wrong — and the ADR is what client and tooling
authors read.

One nuance neither source states: the block that was the **tail** when the store re-opened *is*
compressed, as soon as it stops being the tail (`3.blk`, 20680 → 801 bytes). "Blocks already on
disk stay as they are" holds for sealed blocks only.

**Suggested fix:** in ADR-35, replace "Newly minted blocks will use the newly selected compression
algorithm" with a statement that the algorithm is fixed for the lifetime of the store instance and
that a change takes effect when the stream's store is next opened.

---

## 31 · The connection spec never says what a server advertises, and one default is unreadable

**Impact: the single most common deployment question about clients — "will my clients be handed
addresses they can reach?" — has no public answer.** Anyone deploying behind a load balancer, NAT or
Kubernetes has to read the server source or run `nc` against the port, as this wiki did.

ADR-40 is **Implemented**, four revisions, dated 2023-10-12 to 2025-11-05. Its *Servers discovery*
section is, in full:

> "**Note**: Server will send back the info only
>
> When Server sends back INFO. It may contain additional URLs to which the client can make
> connection attempts. The client should store those URLs and use them in the Reconnection Strategy.
>
> A client should have an option to turn off using advertised URLs. By default, those URLs are used.
>
> **TODO**: Add more in-depth explanation how topology discovery works."

The first line is a sentence fragment. The section never says **which** URLs a server puts there,
how they are resolved, or that `no_advertise` and `client_advertise` exist. A second `**TODO**`
stands in for the auth flow, and a third for the WebSocket flow.

Separately, under *Max reconnects*:

```
**default: 3 / none
```

— an unclosed bold marker and two values with nothing saying which applies. This is a client default
that can permanently stop a service reconnecting; it deserves a number.

**Evidence — what the server actually does**, observed on v2.14.6 (`INFO` read with `nc`, full runs
in `raw/nats-server-src/compression-purge-discovery-observed-v2.14.6.md`):

```
standalone                     connect_urls: null
2-node cluster, defaults       connect_urls: ["<host-ip>:4231", "<host-ip>:4232"]   # own + peer, routable address
3 nodes, no_advertise on m1    m1: null   m2: [m2, m3]   m3: [m3, m2]               # m1 vanishes from every list
3 nodes, client_advertise m1   every node lists "nats.example.internal:4222" for m1
```

The server-side keys are documented — `reference/config/cluster/no_advertise.md` and
`reference/config/client_advertise.md` are both correct and both marked *Hot Reloadable* — but
nothing connects them to the client behaviour ADR-40 specifies, in either direction.

**Suggested fix:** replace the TODO with the four sentences above, and cross-link the two config
pages. Give `max reconnects` one number and say what happens when it is exhausted.

---

## 32 · Every uint64 maximum in the generated JetStream reference is 385 too large

**Impact: low, but mechanical and everywhere.** A client or tool that trusts the published maximum
sends a value the server cannot represent.

Every field typed `unsigned 64 bit integer` in the generated reference publishes:

```
Minimum:`0`

Maximum:`18446744073709552000`
```

The maximum of a uint64 is **18446744073709551615**. `18446744073709552000` is 385 larger, is not a
valid uint64, and is the exact value you get by round-tripping 2^64−1 through an IEEE-754 double —
the signature of a JSON-Schema generator serialising the bound as a JavaScript number.

**Sweep of the neighbours: all 11 pages in the docs tree that state a uint64 maximum carry the wrong
one**, and the correct value `18446744073709551615` appears **nowhere** in the 861-page tree:

```
reference/jetstream/api/stream/create.md      reference/jetstream/api/stream/update.md
reference/jetstream/api/stream/purge.md       reference/jetstream/api/stream/msg-delete.md
reference/jetstream/api/stream/pub-ack.md     reference/jetstream/api/consumer/create.md
reference/jetstream/api/consumer/info.md      reference/jetstream/advisory/nak.md
reference/jetstream/advisory/terminated.md    reference/jetstream/advisory/max-deliver.md
reference/jetstream/metric/consumer-ack.md
```

**Suggested fix:** emit the bound as a string in the generator, or omit it — a reader does not need
to be told that a uint64 field holds a uint64, and a wrong number is worse than none.

---

## 33 · The docs' own `max_file_store` advice does not protect the volume ★

**Impact: an operator who follows the sizing chapter exactly can fill the disk while every NATS
number says there is room.** This is the same failure shape as #22, one layer up: #22 was the wrong
*default*; this is the missing fact that makes the *recommended setting* unsafe.

**What the docs say.** `learn/deployment/sizing-and-resources.md` sets the key to the volume size
and moves on:

> "Pin `max_file_store` to what the volume can actually hold"

```
jetstream {
  store_dir:      "/var/lib/nats/jetstream"
  max_memory_store: 256MB
  max_file_store:   10GB
}
```

> "A 10 GiB `max_file_store` per node leaves ample room for an ORDERS stream sized to fit the default
> 10 GiB volume the Kubernetes chapter provisions."

**What the server does.** `max_file_store` is compared against the sum of the **live message record
lengths**, the same figure `nats stream info`, `/jsz` `storage` and an account's `MaxStore` use.
The files under `store_dir` are always larger, by three mechanisms in `server/filestore.go` at
v2.14.6:

- a delete leaves its record in the block **and appends a 30-byte tombstone** (`updateAccounting`,
  `filestore.go:7696–7700`);
- a block is only rewritten when **more than half of it is dead**, and only after `sync_interval`
  (default `2m`) if it is under 2MB (`filestore.go:6254–6264`);
- the **last block is never compacted at all** — `!isLastBlock` at `filestore.go:6151` and
  `mb != lmb` under the comment `// Do not compact last mb.` at `filestore.go:8037–8039`.

**Observed, on the v2.14.6 binary** (full run in
`raw/nats-server-src/filestore-observed-v2.14.6.md`, §11). A server configured deliberately small:

```
jetstream { store_dir: "<store>"  max_file_store: 4MB  max_memory_store: 1MB }
```

```
[INF]   Max Storage:     4.00 MB
```

One stream, `max_msgs_per_subject: 1000`, 60,000 messages published to one subject, then idle:

```
$ nats stream info CAP --json | jq '.state | {messages, bytes}'
{ "messages": 1000, "bytes": 133000 }

$ curl -s http://127.0.0.1:8233/jsz | jq '{storage, max: .config.max_storage}'
{ "storage": 133000, "max": 4194304 }

$ find <store> -type f -exec stat -f "%z %N" {} \;
       508  .../streams/CAP/meta.inf
        16  .../streams/CAP/meta.sum
   3785712  .../streams/CAP/msgs/2.blk
```

**JetStream reports 3% of its ceiling used. The directory holds 90% of it.** Nothing is logged and
nothing is wrong with the stream. Scale that to the documented example and a 10 GiB
`max_file_store` on a 10 GiB volume has no margin at all.

**The Helm chart renders exactly this setting by default.** Found while scouting question-bank row
Q65 on 2026-08-31. `helm/charts/nats/files/config/jetstream.yaml` at chart release **nats-2.14.6**:

```
{{- if .maxSize }}
max_file_store: << {{ .maxSize }} >>
{{- else if .pvc.enabled }}
max_file_store: << {{ .pvc.size }} >>
{{- end }}
```

`config.jetstream.fileStore.maxSize` is empty in `values.yaml` (its comment reads "defaults to the
PVC size") and `fileStore.pvc.size` is `10Gi`, so a stock JetStream install comes up with
`max_file_store: 10Gi` on a 10Gi volume — the docs' example, shipped. Extract:
`raw/github-repos/nats-io__k8s.values-jetstream-storage-nats-2.14.6.md`. This is a *chart* default
rather than a doc sentence, so it is not a separate row; it is recorded here because it is what most
readers will actually be running, and because it means the fix has to be stated as "set
`fileStore.maxSize`", not only as "pin `max_file_store`".

**The second half: the per-message overhead is nowhere in the tree.** A stored message costs
`30 + len(subject)` bytes beyond payload and headers (`fileStoreMsgSizeRaw`,
`filestore.go:9821–9828`), plus `4 + len(headers)` when headers are present. That is **+40% on a
100-byte message** with a ten-character subject. A grep of all 861 pages for `emptyRecordLen`,
`index.db`, "per-message overhead", "storage overhead" and "bytes per message" returns **one hit** —
`learn/object-store/chunking.md`, which mentions "per-message overhead" qualitatively without a
number. The sizing chapter, whose subject is exactly this, contains none of it.

**Sweep of the neighbours.** Checked every page in the tree that states a JetStream storage number:
`learn/deployment/sizing-and-resources.md`, `reference/config/jetstream.md` and its four
`max_file_store` / `max_memory_store` / `store_dir` / `sync_interval` property pages,
`learn/jetstream/shaping-the-stream.md`, `learn/jetstream/policies.md` and
`reference/jetstream/api/stream/create.md`. **None of the nine states that the figure is logical**,
and none gives the record overhead. `sync_interval` is documented as a durability knob with no
mention that it is also the compaction cadence.

**Suggested fix**, in the order that helps most:

1. In `learn/deployment/sizing-and-resources.md`, one sentence: *"`max_file_store`, `max_bytes` and
   `MaxStore` all count message records, not disk. Size the volume above `max_file_store`."*
2. A worked overhead line in the same chapter: `record bytes = 30 + len(subject) + len(payload)
   (+ 4 + len(headers))`.
3. On `reference/config/jetstream/sync_interval.md`, say that this is also the interval at which
   dead message blocks are compacted.

**This wiki's handling:** [[filestore-layout]] states the layout and the arithmetic;
[[jetstream-sizing]] step 1b gives the slack rule (`stream_bytes × 1.1 + 8MB per stream`);
[[jetstream-out-of-disk]] carries the symptom.

---

## 36 · The advisories chapter's diagram contradicts its own prose

**Impact: small but silent.** A reader who copies the subject out of the page's diagram gets a
subscription that matches nothing, with no error — the same failure mode as issue #1, from the same
family of advisory-subject errors, in the hand-written tree rather than the generated one.

**What the docs say.** The prose of `learn/monitoring/advisories-and-events.md` is **correct**:

> "When a message on the `shipping` consumer exhausts its delivery attempts, the server publishes one
> advisory here: `$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping`"

The animation caption on the same page drops `.CONSUMER.`, three times:

> "publishes one advisory on $JS.EVENT.ADVISORY.MAX\_DELIVERIES.ORDERS.shipping"
>
> "* n2-east JetStream → $JS.EVENT.ADVISORY…\nMAX\_DELIVERIES.ORDERS.shipping"
>
> "* $JS.EVENT.ADVISORY…\nMAX\_DELIVERIES.ORDERS.shipping → monitor"

**What the server does.** `server/jetstream_api.go:241` at v2.14.6:

```go
JSAdvisoryConsumerMaxDeliveryExceedPre = "$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES"
```

**Verified on the wire**, not only from the constant. A pull consumer with `--max-deliver 2 --wait 1s`
was fetched repeatedly with `--no-ack` while `nats sub '$JS.EVENT.ADVISORY.>'` was attached
(`raw/nats-server-src/monitoring-observed-v2.14.6.md`):

```
[#4] Received on "$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping"
{"type":"io.nats.jetstream.advisory.v1.max_deliver","id":"9lWb25w5SokA1gpeK2wgeB",
 "timestamp":"2026-08-31T22:39:02.825838Z","stream":"ORDERS","consumer":"shipping",
 "stream_seq":1,"deliveries":2}
```

**Suggested fix:** correct the three occurrences in the diagram caption to match the prose.

**Two smaller things found in the same run**, neither filed as its own row:

- The page's example advisory body shows `{type, stream, consumer, stream_seq, deliveries}`; the wire
  also carries **`id`** (a NUID) and **`timestamp`** (RFC 3339). The example is abridged rather than
  wrong, so this is a note, not a defect.
- `$JS.EVENT.ADVISORY.API` fires for ordinary API calls — creating one stream and two consumers
  produced three of them before the first interesting advisory. The chapter's
  `nats subscribe '$JS.EVENT.ADVISORY.>'` example is therefore noisier in practice than it reads.

**Why this is `low` and not `★`.** The correct subject is on the same page, in prose, immediately
above the diagram. A reader who reads the page rather than only the picture gets the right value.


## 37 · ADR-42's update rules do not hold at 2.14.6, and the docs contradict them

**Found by consolidation, not by ingest.** [[consumer]] carried the docs' claim ("Priority
policy — can change") and [[priority-groups]] carried the ADR's ("you cannot … switch
policy. Only `PriorityTimeout` is updatable"). Two pages of this wiki disagreed because two public
sources do. This is the second ADR-42 row, after **#7**.

**What ADR-42 says.** Status *Approved*, tagged `2.11`, eight revisions to 2026-04-29:

> "**You cannot update a consumer from having groups to not having them, or vice versa, and you
> cannot switch between policies.** Only `PriorityTimeout` is updatable today."

> "**The initial implementation allows exactly one group per consumer**; more than one is an error."

**What the docs say.** `learn/jetstream/policies.md`, in its *what can be changed on a live consumer*
table:

> | Priority policy | Can change; `nats consumer edit` has no flag for it, so pass a config file with `--config` |

and `learn/jetstream/priority-groups.md` says the server accepts more than one group and silently
uses only the first.

**What the server does.** Run on **nats-server v2.14.6** with **nats CLI 0.4.0**, 2026-09-01, full
transcript in `raw/nats-server-src/priority-groups-observed-v2.14.6.md`. Every transition the ADR
forbids is accepted with no error:

```
# 1. created with priority_policy=overflow, priority_groups=["g1"]
priority_policy=overflow  priority_groups=['g1']  priority_timeout=None

# 2. "you cannot switch between policies"  ->  edit to pinned_client
(accepted, no error)
priority_policy=pinned_client  priority_groups=['g1']  priority_timeout=120000000000

# 3. "you cannot update a consumer from having groups to not having them"  ->  edit them away
(accepted, no error)
priority_policy=None  priority_groups=None  priority_timeout=None

# 4. "...or vice versa"  ->  give them back
(accepted, no error)
priority_policy=overflow  priority_groups=['g1']  priority_timeout=None

# 5. "more than one is an error"  ->  create with two groups
(accepted, no error)
priority_policy=overflow  priority_groups=['g1', 'g2']
```

**The neighbour sweep.** Four of ADR-42's hard rules were checked against the same binary, not just
the one that started this. **Two are wrong and two hold**, and the two that hold do so with their
error codes:

| ADR-42 rule | v2.14.6 |
|---|---|
| policy and groups are not updatable; only `PriorityTimeout` is | **wrong** — all three transitions accepted |
| exactly one group per consumer; more is an error | **wrong** — two accepted and both stored |
| group name matches `limited-term` and is capped at 16 characters | **holds** — `10162 Valid priority group name must match A-Z, a-z, 0-9, -_/=)+ and may not exceed 16 characters` |
| priority groups are pull-only; a push consumer is an error | **holds** — `10178 priority groups can not be used with push consumers` |

A fifth observation, not a defect: setting `pinned_client` with no explicit `priority_timeout` fills
the field with **`120000000000` ns (2 minutes)**, matching the ADR's example value — and
`priority_timeout` is indeed updatable, which is the one thing the sentence gets right.

**Suggested fix.** ADR-42 already carries exactly the right shape of note for this, on `failover`:
*"As of NATS Server 2.14 the `failover` option is not implemented; the server silently ignores the
field and does not enforce the bounds described above."* Add the same kind of note to the update rule
and the one-group rule — or, if the restrictions are still intended, they are unimplemented and the
ADR should say which release will carry them.

**Why this is `medium` and not `★`.** Nothing is corrupted and nothing is silently wrong on the wire:
the ADR describes a restriction that is *absent*, so a reader designs around a constraint that does
not exist (recreating a consumer, and losing its position, to change a policy that could have been
edited). The one-group claim is the more dangerous half in the other direction — a design that
configures two groups is accepted by the server, and `learn/jetstream/priority-groups.md` says only
the first is used, which this run did **not** test.

## 35 · The docs never say what a JetStream domain does to KV and Object Store — and it does different things to each

**Impact: an operator who reads "a domain isolates JetStream" and runs object buckets on both sides of
a leafnode gets objects appearing on servers nobody put them on.** The put succeeds normally, nothing
is logged on either side, and the two buckets converge silently. The KV equivalent is genuinely
isolated, so the mental model an operator builds from the KV case is wrong for the object case.

**What the docs say.** Nothing. `learn/topologies/leaf-nodes.md` covers leafnodes and domains and does
not mention either store. `learn/object-store/under-the-hood.md` sends the reader to Security for
"exporting the bucket to another account" and never mentions domains or leafnodes.
`learn/key-value/under-the-hood.md` is the same. **`grep -rn '\$OBJ' raw/nats-docs/` returns nothing**
— the prefix the server denies on does not appear anywhere in the 861-page tree.

**What the server does.** `server/jetstream_api.go:323–324` at v2.14.6:

```go
var denyAllClientJs = []string{jsAllAPI, "$KV.>", "$OBJ.>"}
var denyAllJs = []string{jscAllSubj, raftAllSubj, jsAllAPI, "$KV.>", "$OBJ.>"}
```

and the domain mapping table at `:347` carries `"$OBJ.>": "$OBJ.>"`.

But the object store's subject spaces are **`$O.<bucket>.C.>`** and **`$O.<bucket>.M.>`** — ADR-20,
`learn/object-store/under-the-hood.md`, and `nats stream info OBJ_INVOICES` on the running 2.14.6
server all agree. `$OBJ.>` is a literal first token and matches none of them.

**Verified by running it** (`raw/nats-server-src/object-store-across-leafnode-observed-v2.14.6.md`) —
a hub and a leaf with domains `hub` and `leaf`, joined in a non-system account, the branch that logs
`JetStream using domains: local "leaf", remote "hub"` and merges `denyAllClientJs` both ways:

| published on the leaf | reached the hub? |
|---|---|
| `plain.subject` | yes — ordinary account traffic (connectivity control) |
| `$KV.TEST.key1` | **no** — matches `$KV.>` |
| `$OBJ.TEST.thing` | **no** — matches `$OBJ.>` |
| `$O.TEST.C.abc` | **yes** |
| `$O.TEST.M.abc` | **yes** |

With an object bucket `SHARED` created on *each* server in the same account, one 600 KiB
`nats object put` **on the leaf only**:

| | leaf `OBJ_SHARED` | hub `OBJ_SHARED` |
|---|---|---|
| before | 0 msgs / 0 bytes | 0 msgs / 0 bytes |
| after | 6 msgs / 615,040 bytes | **6 msgs / 615,040 bytes** |

`nats object ls SHARED` on the hub then listed `payload.bin  600 KiB`, and `nats stream subjects`
showed both `$O.SHARED.M.cGF5bG9hZC5iaW4=` and `$O.SHARED.C.kVUgvDAOdPXVz64dqECKBD` — a complete,
gettable object on a server that was never asked to store it.

The KV control, same servers and account: `kv put CONF k1` on the leaf left the hub's `KV_CONF` at
**0 msgs**, and `nats kv get CONF k1` on the hub returned `nats: error: nats: key not found`.

**Suggested fix**, in order of what the docs can do without waiting on the server:

1. **State the rule at all.** `learn/topologies/leaf-nodes.md` should say what a differing domain does
   to each of the four subject spaces — `$JS.API.>`, `$KV.>`, `$O.`, and the Raft/cluster subjects —
   rather than leaving "JetStream is isolated" to be generalised by the reader.
2. **Say that object-store data is not covered**, and give the `deny_exports` / `deny_imports` entry
   for `$O.>` as the mitigation, until the server changes.
3. **Reconcile `$OBJ` and `$O.`**. If `$OBJ.>` in the deny list is meant to be the object store, this
   is a server defect and the fix is `$O.>`; if it is a legacy or reserved prefix, the docs should say
   what uses it, because today nothing public does.

**What is not established**, and is deliberately not asserted here: whether the mismatch is a defect
or an intended asymmetry. No public issue, discussion or ADR read so far mentions `$OBJ` against
`$O.`. The source comment at `jetstream_api.go:330–337` explains why `$KV` and `$OBJ` were made
independent subject spaces but never says which prefix the object store uses.

**So this row reports only the documentation gap, which is unambiguous either way.** Whichever answer
the server maintainers give, `learn/topologies/leaf-nodes.md` should state what a differing JetStream
domain does to each subject space — and today it says nothing about either store. The **behaviour**,
and the question of whether it is a defect, is a separate report:
`inbox/server-issues.md` **SI-1**, which carries the full reproduction and states what would settle
it.

**Not tested**: the same-domain case, the system-account (`denyAllJs`) case, gateways, and clients
other than the `nats` CLI.

## 34 · Six leafnode-remote TLS keys warn about a bug without saying which releases still have it

**Impact: an operator reading the reference concludes a leaf's certificate cannot be rotated without
restarting the leaf.** On a hub-and-spoke that is a much larger operation than a reload, and on
2.14.6 it is unnecessary.

**What the docs say.** Six pages under `reference/config/leafnodes/remotes/tls/` carry a one-line
caveat directly under `Hot Reloadable`:

| page | the line |
|---|---|
| `cert_file.md` | "On 2.11/2.12 the reload succeeds but the old certificate keeps being used." |
| `ca_file.md` | "On 2.11/2.12 the reload succeeds but nothing changes." |
| `key_file.md` | "On 2.11/2.12 the reload succeeds but nothing changes." |
| `cipher_suites.md` | "On 2.11/2.12 the reload succeeds but nothing changes." |
| `curve_preferences.md` | "On 2.11/2.12 the reload succeeds but nothing changes." |
| `insecure.md` | "On 2.11/2.12 the reload succeeds but nothing changes." |

Two things are missing and both matter. The note names **2.11/2.12** — two releases back — and never
says whether 2.14, the release the same tree documents, still behaves that way; and the sibling pages
one level up say the opposite without qualification, so the tree contradicts itself depending on
which page you land on:

```
reference/config/tls/cert_file.md
  "Applies to new connections only; existing TLS sessions keep the old certificate."
reference/config/leafnodes/tls/cert_file.md
  "Applies to newly accepted leafnode connections only; existing connections keep the old
   certificate until they reconnect."
```

**Observed, on the v2.14.6 binary** (full run in
`raw/nats-server-src/tls-reload-observed-v2.14.6.md`, the leafnode section). A hub whose leafnode
listener accepts exactly one certificate identity, so it reports which certificate the leaf
presented:

```
leafnodes {
  port: 7422
  authorization { users: [ { user: "CN=leaf-A" } ] }
  tls { cert_file: "c/hub-cert.pem"  key_file: "c/hub-key.pem"  ca_file: "c/ca1.pem"
        verify_and_map: true  timeout: 5 }
}
```

| what was changed on the leaf | after reload + re-handshake |
|---|---|
| `cert_file`+`key_file` **files** replaced in place (`CN=leaf-A` -> `CN=leaf-B`, same CA) | `User in cert ["CN=leaf-B"], not found` — the **new** certificate |
| `cert_file`+`key_file` **paths** changed in the config | `User in cert ["CN=leaf-B"], not found` |
| `ca_file` repointed at a CA that did not sign the hub | `tls: failed to verify certificate: x509: certificate signed by unknown authority` |

Both controls are clean: restarting the hub with **no** reload leaves the leaf connected
(`leafnodes: 1`), and reloading with **no** file change leaves it connected too. So each result above
is caused by the change, not by the reload or the restart.

**Sweep of the neighbours: 3 of the 6 caveated keys were tested, and all 3 reload.**
`cipher_suites`, `curve_preferences` and `insecure` were **not** tested and this report claims
nothing about them. The `deny_exports` / `deny_imports` pages in the same directory carry a
differently-worded caveat — "on 2.11/2.12 the reload returns success; the new deny_exports take
effect only after a restart" — which was also not tested.

**Why this is filed as `enhancement` and not `wrong-value`.** The sentence is scoped to 2.11/2.12 and
this wiki has not run those releases, so it is not demonstrably false — it is *unusable*. A caveat
with no "fixed in" and no current-release status is read as current, and the reader's only safe
response is to stop using reload for leafnode certificate rotation entirely.

**Suggested fix:** give each of the six a resolution — "fixed in 2.14" where that is true, or a
current-release statement where it is not — and align the wording with the sibling pages at
`reference/config/tls/` and `reference/config/leafnodes/tls/`, which describe the same mechanism with
no caveat at all.

---

## 38 · "A backoff doesn't slow a nak" is true of a bare nak and false of a delayed one

**Impact: a retry waits up to six times longer than the code asked for, silently.** Nothing errors
and nothing is logged; the message simply comes back later than the client's `nakWithDelay` said.

**What the docs say**, in three places in `learn/jetstream/acknowledgment.md`:

> line 42 — "Passing that delay is a client-library call — the CLI's `--nak` only asks for immediate
> redelivery — so there's no CLI tab here. (To space out redeliveries from the CLI, set a consumer
> backoff instead.)"

> line 298 — "A delayed nak sets the wait one redelivery at a time, and the client chooses it. A
> **backoff** on the consumer grows the wait automatically, but it only shapes redeliveries that fire
> when the AckWait timer runs out — **it doesn't slow a nak**."

> line 586 — "A bare nak redelivers right away, and a configured backoff doesn't slow it — to delay a
> nak, the client attaches the delay to the nak itself."

Line 586 is careful and correct: it says *a bare nak*. Line 298 is not — it draws the contrast with
the **delayed** nak in its own first sentence and then denies any interaction, and line 42 sends a
reader who wants spaced retries to the backoff as if the two were alternatives.

**What the server does.** Run on **v2.14.6** with a consumer whose backoff is `5s, 10s, 15s`
(`raw/nats-server-src/nak-backoff-observed-v2.14.6.md`, thirteen experiments):

| what the client sent | attempt | asked for | **got** |
|---|---|---|---|
| `-NAK` (bare) | 1, 2, 3 | immediate | **0.00 s** — the docs are right |
| `-NAK {"delay":2000000000}` | 1 | 2 s | **2.000 s** |
| `-NAK {"delay":2000000000}` | 2 | 2 s | **7.000 s** |
| `-NAK {"delay":2000000000}` | 3 | 2 s | **12.000 s** |
| `-NAK {"delay":0}` | 2 | immediate | **4.94 s** |
| `-NAK {"delay":0}` | 3 | immediate | **9.94 s** |

with two controls: no answer at all gives the documented schedule exactly (**5.00 · 10.00 · 15.00**,
so the backoff is not inert), and the same delayed naks on a consumer with **no** backoff give
**1.95 · 1.95 · 1.95**, so the delay is honoured when there is nothing to interfere.

**The mechanism**, from `server/consumer.go` at v2.14.6: `processNak` backdates the pending timestamp
by `o.cfg.AckWait` (`:3231`), `checkPending` measures it against `o.cfg.BackOff[dc]` (`:6066`), and
`AckWait` was overwritten with `BackOff[0]` at creation (`:658`). The wait a client receives is
therefore `delay + (BackOff[dc] − BackOff[0])`. The **behaviour** is
`inbox/server-issues.md` **SI-2**; this row is the documentation half.

**One more thing the same sentence hides:** `-NAK {}` — an empty options object — is **not** treated
as a bare nak. `processNak` branches on there being anything after `-NAK`, and an empty object parses
to a zero delay, so it takes the delayed path and picks up the backoff term. Two client libraries
implementing the same "plain nak" API can therefore produce different timing.

**Suggested fix:** make line 298 say what line 586 says — that a backoff does not slow a **bare** nak
— and add one sentence for the case the page currently leaves out: on a consumer with a backoff, a
nak that carries a delay is redelivered after that delay **plus** the difference between the current
attempt's backoff entry and the first one. If the server behaviour is judged a defect instead
(SI-2), the sentence should say the delay is honoured and the docs will be right once it is fixed.

**Why this is `high` and not `★`.** The retry still happens and no message is lost or lost track of;
what is wrong is its timing. That is worth a `high` — a 2-second retry that takes 12 seconds will
break an SLA and no signal anywhere says why — but it is not the silent-total-failure shape the ★
rows have.

## 39 · A Synadia post recommends the one nak a backoff does not shape, and its consumer snippet sets an ack deadline 30× shorter than it reads ★

**Impact: a reader who copies the post's consumer config gets a 1-second ack deadline instead of the
30 seconds written two lines above it** — so every handler slower than a second is redelivered while
it is still working, duplicating the work. Nothing warns; the value is simply overwritten by the
server.

*Recorded here although the destination is a blog rather than a repository: it is a public,
first-party engineering post that the wiki draws on, and this file is where this wiki records what a
source got wrong.*

**What the post says.** *Reliable Message Delivery in NATS JetStream: Acks, Retries, Dead Letters, and
Replay*, Andrew Connolly, 2026-07-24 (`raw/synadia-blog/jetstream-reliable-delivery-dlq-replay.txt`):

> line 570 — "How do I retry a failed message with a backoff? Negatively acknowledge it. Nak schedules
> an immediate redelivery, NakWithDelay waits a fixed interval, and the consumer's BackOff schedule
> applies an escalating series of delays across successive redeliveries."

> line 55 — "explicit acknowledgment gives the consumer three verbs: ack (done), nak (redeliver
> immediately, after a delay, or **on a backoff schedule**), and term (stop trying)"

and the copyable Go snippet at lines 268–294:

```go
cfg := jetstream.ConsumerConfig{
    Durable:       "order-processor",
    AckPolicy:     jetstream.AckExplicitPolicy,
    AckWait:       30 * time.Second,
    MaxAckPending: 1000,
    MaxDeliver:    5,
    BackOff:       []time.Duration{1 * time.Second, 5 * time.Second, 30 * time.Second, 2 * time.Minute},
}
```

**What the server does.** Two findings, both run on **v2.14.6**
(`raw/nats-server-src/nak-backoff-observed-v2.14.6.md`):

**a · A bare nak is the one case the backoff does not touch.** Three bare naks on a consumer with
`backoff` `[5s, 10s, 15s]` were redelivered after **0.00 s** each. The escalating schedule applies to
redeliveries that fire when `AckWait` expires (measured: 5.00 · 10.00 · 15.00) and, by the accident in
SI-2, to a nak that carries a delay — never to the bare nak the sentence names first.

**b · `AckWait` next to a `BackOff` is silently discarded.** That exact config, sent to
`$JS.API.CONSUMER.CREATE` rather than through the CLI so nothing client-side could interfere:

```
requested:  ack_wait: 30s   max_deliver: 5   backoff: [1s, 5s, 30s, 2m]
stored:     ack_wait: 1.0s  max_deliver: 5   backoff: [1.0, 5.0, 30.0, 120.0]
```

`server/consumer.go:653–659` at v2.14.6 is explicit about it — *"If BackOff was specified that will
override the AckWait and the MaxDeliver"* — and in **pedantic** mode the same branch returns
`first backoff value has to equal batch AckWait` instead of overwriting. The post's own text never
mentions the override, and the number it writes is the one a reader will believe.

**What the post gets right**, and the wiki cites it for: `MaxDeliver` must be sized against the length
of the backoff schedule; the last backoff interval repeats once the schedule is exhausted (confirmed,
`consumer.go:6060–6063`); and the dead-letter pattern built on the `MAX_DELIVERIES` advisory.

**Suggested fix:** in the FAQ answer, attach the backoff to `AckWait` expiry rather than to the nak;
and in the snippet, either drop `AckWait` or set it to the first backoff entry, with a line saying the
server overwrites it.

## 40 · `nats pub --schedule-after` produces a schedule the server always rejects

**Impact: a documented flag that cannot succeed, and an error that points somewhere else.** The
rejection blames the schedule *pattern*, so a user debugs their duration string, the ADR's cron
grammar, or their server version — never the flag.

*Recorded here although the destination is the `natscli` repository rather than a documentation tree:
the finding is settled the way every other row here is — the ADR defines the correct form and the
server enforces it — so it belongs with the settled findings rather than in `inbox/server-issues.md`.*

**What the CLI sends.** From the server's own `-DV` trace at v2.14.6, the four scheduling flags side
by side (`raw/nats-server-src/message-schedules-observed-v2.14.6.md`):

```
--schedule-after=3s              ->  Nats-Schedule: 2026-09-01T02:21:28Z      ->  10189
--schedule-at=<ts>               ->  Nats-Schedule: @at 2026-09-01T02:21:50Z  ->  OK
--schedule-every=1m              ->  Nats-Schedule: @every 1m0s               ->  OK
--schedule-cron='0 */5 * * * *'  ->  Nats-Schedule: 0 */5 * * * *             ->  OK
```

`--schedule-after` resolves the duration to an absolute time correctly and then omits the `@at `
prefix. ADR-51 defines the single-delayed-message form as `@at <RFC3339>`; a bare timestamp matches no
schedule grammar, so `server/stream.go` rejects it.

**What the user sees:**

```
$ nats pub -J schedules.orders.delay 'body' --schedule-after=3s --schedule-dest=orders
nats: error: message schedules pattern is invalid (10189)
```

**Version:** nats CLI **0.4.0** (`nats --version`), against nats-server v2.14.6.

**Suggested fix:** prefix the computed timestamp with `@at ` in the `--schedule-after` path, as
`--schedule-at` already does.

**Why this is `high` and not `★`.** The flag implies `--jetstream`, so the `PubAck` is read and the
error is printed — the failure is loud. It becomes silent only if a user reproduces the same headers
by hand with a plain `nats pub`, which is a **core NATS publish**: no reply subject, so the `PubAck`
and its rejection go nowhere and the CLI prints `Published N bytes` for a message the server threw
away. That behaviour is not a defect, but it is the reason every check in the transcript above was
re-run through a client that reads the `PubAck`.

## 41 · The JetStream header reference gets two scheduling headers wrong and leaves two blank

**Impact: one of the two errors is silent.** A reader who believes `Nats-Schedule-TTL` bounds *the
schedule* will set it expecting a recurring schedule to stop itself, and the schedule will keep firing
forever while the messages it produces quietly expire — the opposite of the intent, with nothing to
see.

**What the docs say**, in `reference/jetstream/api/headers.md` under *Scheduled Messages*:

| header | the page's description |
|---|---|
| `Nats-Scheduler` | value "Scheduler ID"; "Identifier for the scheduler" |
| `Nats-Schedule-TTL` | "Time-to-live for **the schedule**" |
| `Nats-Schedule-Time-Zone` | *(empty)* |
| `Nats-Schedule` | value "Cron expression" |

and, in a different section entirely (*Message Rollup*, not *Scheduled Messages*):

| `Nats-Schedule-Rollup` | String | *(empty)* |

**What the server does**, run on **v2.14.6**
(`raw/nats-server-src/message-schedules-observed-v2.14.6.md`). A schedule published with
`Nats-Schedule-TTL: 5m` produced this message on the target subject:

```
Item: SCHED#4 on Subject orders

Headers:
  X-Custom: kept
  Nats-Scheduler: schedules.orders.single
  Nats-Schedule-Next: purge
  Nats-TTL: 5m

delayed-body
```

- **`Nats-Scheduler` is a subject** — the subject that held the schedule. It is not an opaque
  identifier, and when a *client* sets it (to cancel a schedule) the server requires it to be a valid
  publish subject that differs from the one being published to, or answers `10212`
  (`server/stream.go` at v2.14.6). ADR-51 says so directly: "`Nats-Scheduler` — The subject holding
  the schedule."
- **`Nats-Schedule-TTL` sets the TTL on the generated message**, not on the schedule. ADR-51: "When
  publishing sets a TTL on the message if the stream supports per message TTLs." The schedule's own
  lifetime is set by a plain `Nats-TTL` on the schedule message — a different header with the opposite
  target.
- **`Nats-Schedule` is not only a cron expression.** `@at <RFC3339>` (the only form 2.12 supported),
  `@every <duration>` and `@yearly`/`@monthly`/`@weekly`/`@daily`/`@hourly` are all accepted.
- **`Nats-Schedule-Rollup` takes `sub` and nothing else** — `all` is refused with `10192` — and it
  belongs in the *Scheduled Messages* table rather than under *Message Rollup*.
- **`Nats-Schedule-Time-Zone`** accepts an IANA name, `UTC` or `Local`; a fixed offset or an empty
  value is refused with `10223`, and it is rejected outright on a non-cron schedule.

**Also missing from the section:** none of these headers do anything unless the stream sets
`allow_msg_schedules`, in which case the server answers `10188 message schedules is disabled`. The
page never mentions the stream field.

**Suggested fix:** correct the two descriptions, fill the two empty ones, move `Nats-Schedule-Rollup`
into the scheduling table, and add one sentence naming `allow_msg_schedules` as the precondition.

## 42 · The message scheduler has no prose page anywhere in the documentation

**Impact: an operator cannot learn this feature from the documentation at all.** They can learn that
it exists, and they can look up the headers' names. Everything else — the six-field cron, the tzdata
requirement, what enabling the stream field does to two other fields, how to stop a schedule, which
retention policies quietly disable one — exists only in an ADR, which is a design document rather than
user documentation.

**Verified against the live site, not only the mirror.** `https://docs.nats.io/llms.txt`, fetched
**2026-09-01**: no entry mentions scheduling, cron or delayed publishing. In the 861-page mirror
fetched 2026-08-31, `Nats-Schedule` appears in exactly **two** files —
`reference/jetstream/api/headers.md` and `release-notes/upgrade-to-2.14.md`.

**Four release-note bullets announce the feature across two releases, and all four link only to the
ADR:**

- `upgrade-to-2.12.md` — *"Delayed Message Scheduling: The `AllowMsgSchedules` stream configuration
  option allows the scheduling of messages… More information is available in ADR-51."*
- `upgrade-to-2.14.md` — *Recurring schedules*, *Scheduled subject sampling*, *Scheduled subject
  rollups*.

**The neighbours, checked.** This is not the only bullet without a page — of 2.12's 18 feature
bullets, 3 link to a `/learn/` page and 3 link only to an ADR; of 2.14's 15, 3 and 4 respectively. What
distinguishes scheduling is that it is announced **four times across two releases** and still has no
page, while comparable features do: the *Prioritized pull consumer policy* bullet immediately below
2.12's scheduling bullet links to `/learn/jetstream/priority-groups.md`, and 2.14's atomic-batch
bullet links to `/learn/jetstream/advanced-publishing.md`.

**A shipped feature's public footprint, in full:** one stream config field, eight `Nats-Schedule*`
headers, **ten** error codes (10186, 10187, 10188, 10189, 10190, 10191, 10192, 10203, 10212, 10223),
four release-note bullets — and no chapter. The asker of `nats-io/nats-server` discussion
[#7672](https://github.com/nats-io/nats-server/discussions/7672) puts it plainly while trying to find
out whether cron works at all: *"Can't find much more info in the docs or code."*

**This is `missing`, not `enhancement`.** The rulebook's line is that `enhancement` means correct but
unhelpful; here there is no page to be unhelpful.

**Suggested fix:** a `learn/jetstream/message-scheduling.md` covering the model (one schedule per
subject, target in the same stream), the header family, the 2.12/2.14 boundary, the six-field cron and
the `@every` minimum, the tzdata requirement for named time zones, stopping a schedule, and the
retention table — and link it from the four release-note bullets.

## Internal — where this wiki records each of these

*Not part of the report.* This table maps each finding to the page in this wiki that carries it, so a
reader here can get from a finding to the prose that uses it. A recipient of the report can ignore it.

### Where the wiki records each of these

| # | wiki page |
|---|---|
| 1–3 | `wiki/reference/advisories.md` — *A docs error worth knowing* |
| 4 | `wiki/summaries/s-docs-consumer-config.md`, `wiki/reference/defaults-and-limits.md` |
| 5 | `wiki/concepts/stream.md` — *The deduplication window*; `wiki/concepts/publishing.md` — *Exactly-once, honestly* |
| 6 | `wiki/reference/defaults-and-limits.md` — *The 8 MB question* |
| 7 | `wiki/concepts/priority-groups.md`, `wiki/entities/nats-server-2.11.md` |
| 8 | `wiki/entities/nats-net.md` — *What an operator needs to know* |
| 9 | `wiki/entities/nats-js.md` — *What an operator needs to know* |
| 10 | `wiki/entities/nats-py.md` — *What an operator needs to know* |
| 11 | `wiki/operations/build-a-3-node-cluster.md` — *Pitfalls*; `wiki/summaries/s-nats-server-route-cluster-formation.md` |
| 12 | `wiki/operations/install-nats-server.md` — *Run it under systemd*; `wiki/summaries/s-nats-server-systemd-units.md` |
| 13 | `wiki/operations/upgrade-a-cluster.md` — *Per node: drain, restart, wait* and *Pitfalls*; `wiki/summaries/s-nats-server-lame-duck.md` |
| 14 | `wiki/operations/upgrade-a-cluster.md` — *Kubernetes*; `wiki/entities/nats-helm-charts.md` |
| 15 | `wiki/operations/backup-and-restore-jetstream.md` — *Memory streams*; `wiki/concepts/stream.md`; `wiki/reference/error-codes.md` |
| 16 | `wiki/operations/backup-and-restore-jetstream.md` — *Restore it* |
| 17 | `wiki/operations/backup-and-restore-jetstream.md` — *Tuning a slow or distant link* |
| 18 | `wiki/operations/backup-and-restore-jetstream.md` — *Restore somewhere else, at a different size*; `wiki/entities/nats-cli.md` |
| 19 | `wiki/reference/defaults-and-limits.md` — *Authentication and TLS handshake budgets*; `wiki/concepts/tls-in-nats.md`; `wiki/concepts/auth-callout.md` |
| 20 | `wiki/operations/rotate-tls-certificates.md` — *Find out what is actually deployed*; `wiki/reference/monitoring-endpoints.md` |
| 21 | `wiki/concepts/cross-account-sharing.md` — *Sharing JetStream*; `wiki/summaries/s-gh-7017-kv-across-accounts.md` |
| 22 | `wiki/gotchas/jetstream-out-of-disk.md` — *A docs error worth knowing*; `wiki/reference/defaults-and-limits.md` — *JetStream — server*; `wiki/reference/config-keys.md` — *`jetstream { … }`*; `wiki/operations/jetstream-sizing.md` — *Step 4*; `wiki/summaries/s-nats-server-jetstream-resources.md` |
| 23 | `wiki/reference/defaults-and-limits.md` — *Topology — leafnodes and gateways*; `wiki/reference/config-keys.md` — *The three listener ports have no default*; `wiki/concepts/leafnode.md`; `wiki/concepts/gateway.md` |
| 24 | `wiki/operations/reload-server-config.md` — the dry-run section; `wiki/operations/build-a-3-node-cluster.md` — *If this cluster will also carry a gateway or leafnodes*; `wiki/summaries/s-docs-putting-it-together.md` |
| 25 | `wiki/reference/monitoring-endpoints.md` — *The two stall counters*; `wiki/reference/defaults-and-limits.md` — *Fast-producer stall*; `wiki/gotchas/supercluster-slows-when-a-remote-subscriber-joins.md`; `wiki/concepts/gateway.md` — *Geo-affinity, precisely* |
| 26 | `wiki/concepts/leafnode.md` — *Restricting what crosses*; `wiki/summaries/s-gh-5941-restrict-leafnode-subjects.md` |
| 27 | `wiki/concepts/leafnode.md` — *Compression is on by default*; `wiki/reference/defaults-and-limits.md` — *Topology — leafnodes and gateways*; `wiki/reference/config-keys.md` — *`leafnodes { … }`* |
| 28–29 | `wiki/reference/config-keys.md` — *`websocket { … }` and `mqtt { … }`*; `wiki/reference/defaults-and-limits.md` — *Topology — leafnodes and gateways* |
| 30 | `wiki/concepts/stream-compression.md` — *Changing it on a live stream does nothing until the store restarts*; `wiki/concepts/stream.md`; `wiki/summaries/s-adr-35-filestore-compression.md` |
| 31 | `wiki/operations/how-clients-reach-a-cluster.md` — *What the server actually advertises*; `wiki/summaries/s-adr-40-nats-connection.md`; `wiki/operations/build-a-3-node-cluster.md` |
| 32 | nowhere — the wiki quotes no maximum from these pages; recorded here so the generator bug is reported |
| 33 | `wiki/internals/filestore-layout.md`; `wiki/operations/jetstream-sizing.md` — *Step 1* and *Step 1b*; `wiki/gotchas/jetstream-out-of-disk.md` — *The volume can fill while every JetStream number says there is room*; `wiki/reference/monitoring-endpoints.md` — *`storage` is a logical figure, not disk*; `wiki/operations/kubernetes-storage.md` — *Set `max_file_store` below the volume size*; `wiki/gotchas/jetstream-out-of-disk.md` — *Prevention* |
| 34 | `wiki/concepts/leafnode.md` — *Rotating a remote's certificate*; `wiki/operations/rotate-tls-certificates.md` — *Settled by running it* and step 4; `wiki/summaries/s-nats-server-tls-reload.md` |
| 35 | `wiki/concepts/object-store.md` — *A bucket is not isolated by a JetStream domain*; `wiki/concepts/jetstream-domain.md`; `wiki/concepts/leafnode.md` — *Limits and failure modes*; `wiki/gotchas/streams-not-visible-across-a-leafnode.md`; `wiki/summaries/s-nats-server-object-store-leafnode.md` |
| 36 | `wiki/reference/advisories.md` — *A docs error worth knowing*; `wiki/summaries/s-docs-monitoring-advisories-and-events.md` |
| 37 | `wiki/concepts/priority-groups.md` — *Hard rules* and *What the ADR says that the server does not do*; `wiki/concepts/consumer.md` — *Priority policy*; `wiki/summaries/s-adr-42-priority-groups.md` |
| 38 | `wiki/concepts/ack-and-redelivery.md` — *What a delayed nak actually waits*; `wiki/summaries/s-nats-server-nak-backoff-observed.md`; the behaviour half is `inbox/server-issues.md` **SI-2** |
| 39 | `wiki/concepts/ack-and-redelivery.md` — *What a delayed nak actually waits* and *Backoff*; `wiki/summaries/s-synadia-reliable-delivery-dlq.md` |
| 40 | `wiki/concepts/message-scheduling.md` — *Limits and failure modes* item 4 and the cheat sheet; `wiki/summaries/s-nats-server-message-schedules-observed.md` |
| 41 | `wiki/concepts/message-scheduling.md` — *What configures it* and *Where the documentation is*; `wiki/summaries/s-docs-jetstream-headers.md`; `wiki/concepts/message-ttl.md` |
| 42 | `wiki/concepts/message-scheduling.md` — the whole page, and *Where the documentation is*; `wiki/summaries/s-adr-51-message-scheduler.md` |
