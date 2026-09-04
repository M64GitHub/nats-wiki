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
| **`destination`** | which repository the fix belongs in: **`nats-docs`** for the documentation tree, **`ADR repo`** for `nats-io/nats-architecture-and-design`, **`natscli`** for `nats-io/natscli`. Five rows (#7, #30, #31, #37, #90) are ADR errors rather than docs errors, three (#40, #89, #91) are **CLI** findings, and one (#39) is a **published blog post** rather than a repository at all |
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
| 43 | ★ The JetStream API reference gets **two system-level subjects wrong**. The peer-remove endpoint is given as `$JS.API.META.SERVER.REMOVE` (meta index table and the page's own `## Subject`) while the server serves **`$JS.API.SERVER.REMOVE`** — which the same page's request/response captions use; a request to the documented subject is answered by the generic handler with `10039 JetStream not enabled for account`, so the mistake reads as a permissions problem. And account purge is given as `$JS.API.ACCOUNT.PURGE` where the server subscribes **`$JS.API.ACCOUNT.PURGE.<account>`**; the documented form gets **no reply at all** — and the same table marks it `System Account: No` where the handler returns unless the request comes from the system account. All 98 subject mentions in the 32 reference pages were swept against the server: these are the only wrong ones | `reference/jetstream/api/meta.md` line 7; `reference/jetstream/api/meta/server-remove.md` line 10; `reference/jetstream/api/account.md` line 7; `reference/jetstream/api/account/purge.md` lines 10, 14 | nats-docs | wrong-value | medium | not filed | wiki prints the server's subjects and says the docs disagree |
| 44 | Nothing in the documentation says that a standalone server's streams are **deleted** when it is restarted as a cluster member — the orphan check runs 30 s after the meta log is recovered, logs one WARN line, and has no flag. The topology chapter narrates that exact growth path ("The cluster is three servers, each one a server like `n1`, added without removing the single server", "the layer below keeps working exactly as it did"); its own configs use fresh store directories, so following them literally is safe, but the consequence of reusing the store is stated nowhere. `orphan` does not occur in the tree in this sense | `learn/topologies/putting-it-together.md` line 38; `learn/topologies/your-first-cluster.md`; `learn/topologies/jetstream-in-a-cluster.md` (introduces the meta layer) | nats-docs | missing | high | not filed | wiki gotcha carries the mechanism, the observed timeline and the backup-first rule |
| 45 | `learn/clustering/scaling-and-peers.md` calls the meta API reference "the full set of peer-management and stream-assignment operations"; that reference lists two subjects. The server's meta leader serves five system-account subjects, and `$JS.API.ACCOUNT.STREAM.MOVE.<account>.<stream>` / `…STREAM.CANCEL_MOVE.<account>.<stream>` — the mechanism behind moving a stream off a server — appear nowhere in the reference tree | `learn/clustering/scaling-and-peers.md` line 79; `reference/jetstream/api/meta.md` | nats-docs | missing | low | not filed | wiki lists both in the "absent from the API index" table |
| 46 | `reference/config/jetstream/extension_hint.md` documents neither what the key does nor its two accepted values — `no_extend` and `will_extend` — which the server itself names in its startup notices (`manually disable Observer Mode by setting the JetStream Option "extension_hint: no_extend"`). The page body is "Requires Restart" and a type table reading `string`, `-`, `-` | `reference/config/jetstream/extension_hint.md` | nats-docs | missing | low | not filed | wiki explains the key on `jetstream-domain` |
| 47 | The `/raftz` reference page — the one `learn/clustering/raft-and-leaders.md` and `replication-and-r3.md` send readers to for "the full set of RAFT internals", "its full field set", "append-entry batching, heartbeat intervals, log compaction" — is **173 bytes**: two request options and an empty response schema. Verified against the live site 2026-09-01. None of the promised parameters is an endpoint field; they are unexported constants in `raft.go` | `reference/system/monitor/raftz.md`; `learn/clustering/raft-and-leaders.md` lines 52, 162; `learn/clustering/replication-and-r3.md` line 257 | nats-docs | missing | medium | not filed | wiki prints the field set from `monitor.go` and the constants from `raft.go`, and says the page is empty |
| 48 | ★ Six generated monitor reference pages — `accountz`, `jsz`, `leafz`, `subsz`, `gatewayz`, `raftz` — print the JSON field names of the `$SYS.REQ.SERVER.PING.<Z>` request payload (`account`, `consumer`, `subscriptions`, `leader_only`, …) as "Request options for the … monitoring endpoint". The HTTP handlers read other names (`acc`, `consumers`, `subs`, `leader-only`, …) and **silently ignore the documented ones**: `/accountz?account=NOPE` returns the normal page, `/accountz?acc=NOPE` answers `400`. `connz` and `healthz` print the right names, so the tree contradicts itself. 14 pages swept | `reference/system/monitor/accountz.md`, `jsz.md`, `leafz.md`, `subsz.md`, `gatewayz.md`, `raftz.md` (request schemas) | nats-docs | wrong-value | medium | not filed | wiki tables use the HTTP names and say which pages differ |
| 49 | ADR-59 §*Internal consumers* says the replication consumer "is created with an explicit name following the pattern `mirror-<id>` or `src-<id>`" when a filter is set, and gets a server-generated name otherwise. That was `stream.go` at v2.10.0 and v2.12.0. The 2.14 server names it `JS_MIRROR_<id>` / `JS_SRC_<id>` unconditionally (`stream.go:3561`, `4019` at v2.14.6), which is what `/jsz?direct-consumers=true` prints and what ADR-60 specifies; ADR-59 revision 2 (2026-04-29) was not updated | `raw/adr/ADR-59.md` line 654 (§ *Internal consumers*) | ADR repo | wrong-value | low | not filed | wiki names both forms with their versions on `mirrors-and-sources` |
| 50 | Nothing in the docs tree says an object-store bucket can be mirrored, that the mirror needs the transform `$O.<origin>.>` → `$O.<mirror>.>`, or that `nats object add` has no `--mirror` while `nats kv add` does. The six `learn/object-store/` pages never contain the word *mirror*; `learn/jetstream/mirrors-and-sources.md` never mentions a bucket; the KV chapter has one paragraph for KV. The only public route is nats-server issue #5106 (closed 2024-03-04), and the obvious procedure without it yields a bucket that lists as empty (observed on 2.14.6 / CLI 0.4.0) | `learn/object-store/*.md`, `learn/jetstream/mirrors-and-sources.md` | nats-docs | missing | medium | not filed | wiki: *Mirroring a bucket* on `object-store` |
| 51 | ADR-57 §*Mirror Configuration* says a KV mirror gets `MirrorDirect` and a `KV_` prefix and thereby "Support[s] direct reads via the Direct GET API", but never says which subjects a client reads a mirror bucket at. The reference client reads a **same-domain** mirror at `$KV.<mirror>.>` (which the mirror does not hold — `nats kv ls M` prints `No keys found in bucket`) and a **cross-domain** mirror at `$KV.<origin>.>` (nats.go `jetstream/kv.go:1610–1618`, v1.53.1). Observed on 2.14.6: same-domain `kv get` → `key not found`, cross-domain `kv get` → the value | `raw/adr/ADR-57.md` lines 19–40 (§ *Mirror Configuration*) | ADR repo | missing | low | not filed | wiki: *Reading a mirror* on `key-value`; the asymmetry on `nats-go` |
| 52 | The sizing chapter's *Memory* paragraph says memory "holds connections, subscriptions, and (for memory-storage streams) message data" and that a file-storage stream's "messages live on disk, not in RAM" — and never mentions the per-subject index, which is in RAM for every file-backed stream (one entry per distinct subject, a few hundred bytes each; ~380 B measured), nor that a restart reads the whole stream after an unclean stop, nor that above 1,000,000 subjects the periodic `index.db` is not written. Nothing in the 861-page tree names `index.db`, the subject index, or the `Restored N messages … in` line | `learn/deployment/sizing-and-resources.md` line 16 (§ *The four resources a node spends*, **Memory**); the whole tree for the absent terms | nats-docs | missing | medium | not filed | wiki: *Subjects are a RAM term* on `jetstream-sizing`; *Recovery at startup* on `filestore-layout`; the gotcha `jetstream-recovery-is-slow` |
| 53 | `concepts/subjects.md` § *Performance Considerations*: "**Subjects are essentially free**: Creating new subjects has virtually no overhead - NATS efficiently handles millions of unique subjects." True for core NATS routing, which the sentence is about; read from JetStream — the page is the only place the docs discuss subject count at all — it is the opposite of the sizing rule a stream needs, and the docs never say the JetStream side differs | `concepts/subjects.md` line 1108 | nats-docs | enhancement | low | not filed | wiki: *Subjects are a RAM term* on `jetstream-sizing` |
| 54 | The v2.10.0 release notes announce four system-account requests — `$SYS.REQ.SERVER.<id>.RELOAD` (reload the config by message, #4307), `$SYS.REQ.SERVER.<id>.KICK` and `.LDM` (disconnect or lame-duck one client by id or name, #4298), `$SYS.REQ.SERVER.PING.IDZ` (basic server info, #3663) — and the docs tree never names any of them; across `learn/` and `reference/system/` the only `$SYS.REQ.SERVER` subjects written out are `PING.VARZ` and `PING.PROFILEZ`. The config-management chapter describes SIGHUP and `nats-server --signal reload` only | `learn/deployment/config-management.md`; `reference/system/monitor.md` | nats-docs | missing | medium | not filed | wiki: `reload-server-config` § *system account*, `evict-a-sick-server`, `monitoring-endpoints` |
| 55 | `reference/config/leafnodes/tls/handshake_first.md` types the leafnode listener's `handshake_first` as `boolean` (`true`, `false`) and describes only the forced form. Since 2.11.0 the leafnode listener accepts what `tls.handshake_first` accepts — `true`/`on`, `false`/`off`, `auto`/`auto_fallback`, or a duration that becomes the fallback delay — because every TLS block is parsed by the same `parseTLS`, and `parseLeafNodes` copies both `HandshakeFirst` and `FallbackDelay` into the listener options. Six sibling pages are typed `boolean`/`string`; the leafnode listener's is the odd one out (the remote's `boolean` is right in effect: the delay is discarded) | `reference/config/leafnodes/tls/handshake_first.md` | nats-docs | wrong-value | low | not filed | wiki: `tls-in-nats` § *which key arrived when*, `leafnode` |
| 56 | The per-account `jetstream { cluster_traffic: owner }` option — Raft traffic for that account's assets carried in the account instead of the system account, added in v2.11.0 (#5466, #5947) — is documented nowhere: no generated page under `reference/config/accounts/`, no mention in `learn/`, and the `traffic_account` / `system_account` fields that report it (stream and consumer info, `/jsz`, `/raftz`, since 2.11.9) are equally absent | `reference/config/accounts/…/jetstream/` (no page); `reference/system/monitor.md` | nats-docs | missing | medium | not filed | wiki: `replicas` § *Version notes*, `monitoring-endpoints` § *What arrived in 2.11* |
| 57 | Three monitoring fields the 2.11 line added are named nowhere in the docs tree: `config_digest` in `/varz` (2.11.0, #4325, the hash `nats-server -t` prints), `tls_cert_not_after` in `/varz` and the per-connection-type blocks (2.11.12, #7709), and `leader_since` in stream and consumer info and `/jsz` (2.11.9, #7189). The `/varz` reference page is generated and still omits them | `reference/system/monitor.md` (varz, jsz) | nats-docs | missing | low | not filed | wiki: `monitoring-endpoints` § *What arrived in 2.11*, `tls-in-nats` |
| 58 | `release-notes/upgrade-to-2.12.md` lists "`GOMAXPROCS` and `GOMEMLIMIT` in server stats" among what is new in 2.12 ("now also contains the effective Go limits"). The change shipped in **v2.10.28 and v2.11.2** (2025-04-25) — both bodies: "`GOMAXPROCS` and `GOMEMLIMIT` are now reported in both `statsz` and `varz` (#6791)", PR merged 2025-04-11 — five months before v2.12.0 | `release-notes/upgrade-to-2.12.md` line 44 | nats-docs | wrong-value | low | not filed | wiki: `nats-server-2.12` § *The docs' upgrade guide against the bodies* (via `s-relnotes-2.12`), `monitoring-endpoints` |
| 59 | `jetstream { max_concurrent_io }` — the size of the server-wide disk I/O semaphore, added in v2.12.14 / v2.14.4 (#8336) when the default rose from a CPU-scaled count to **4096** — has no page in the generated `reference/config/jetstream/` tree and no mention anywhere else; the server bounds it to 4 – 8192 | `reference/config/jetstream/` (no page) | nats-docs | missing | medium | not filed | wiki: `jetstream-sizing` § *Version notes: the 2.12 line*, `filestore-layout` |
| 60 | The `proxies { trusted [ … ] }` block — ADR-55 trusted proxies, v2.12.0 (#7153): "enforcing that connections arrive via a NATS protocol-aware proxy" — is documented nowhere; the generated reference has `proxy_protocol` and `authorization { proxy_required }`, and `reference/system/errors.md` names the `Proxy is not trusted` error "from a proxy not in the list of trusted proxies", but no page says how that list is configured | `reference/config/` (no `proxies` page); `reference/system/errors.md` line 11 | nats-docs | missing | medium | not filed | wiki: `run-nats-behind-a-proxy` § *Version notes: the 2.12 line* |
| 61 | `leafnodes { dial_timeout }` and `leafnodes { remotes [ { dial_timeout } ] }` — added in v2.14.5 / v2.12.15 (#8427): "allowing it to be increased above the default 1 second for high-latency links" — have no page in the generated `reference/config/leafnodes/` tree and no mention anywhere else in the docs; at v2.14.6 the fallback is `DEFAULT_ROUTE_DIAL` (`1s`) and a remote's value overrides the block's | `reference/config/leafnodes/` and `…/leafnodes/remotes/` (no page) | nats-docs | missing | medium | not filed | wiki: `leafnode` § *The 2.14 line*, `config-keys` § *Keys that arrived during 2.14*, `defaults-and-limits` (via `s-relnotes-2.14`) |
| 62 | `reference/config/feature_flags.md` documents the block as "Toggles for features that are not yet on by default. Names are server-internal and change between releases" and names **no flag** — while `release-notes/upgrade-to-2.14.md` tells operators to set `js_ack_fc_v2`, and the server at v2.14.6 defines exactly two flags, the second of which (`js_raft_delete_range`) carries a source warning that enabling it makes older peers **panic**; neither name, nor the warning, is documented | `reference/config/feature_flags.md` (whole page) | nats-docs | missing | medium | not filed | wiki: `config-keys` § *Keys that arrived during 2.14*, `mirrors-and-sources` § *Version notes: the 2.14 line*, `nats-server-2.14` (via `s-relnotes-2.14`) |
| 63 | `$JS.API.CONSUMER.RESET.<stream>.<consumer>` — the consumer reset API of v2.14.0 (#7489, ADR-60) — is absent from `reference/jetstream/api/consumer.md`, which lists nine consumer endpoints, and has no page under `reference/jetstream/api/consumer/`; the 2.14 upgrade guide describes the API without its subject | `reference/jetstream/api/consumer.md` lines 4–14; `reference/jetstream/api/consumer/` (no page) | nats-docs | missing | medium | not filed | wiki: `js-api-subjects` § *Documented elsewhere, absent from the API index* and § *The 2.14 line*, `consumer` (via `s-relnotes-2.14`) |
| 64 | Five generated config pages say "Available since NATS Server `2.12`" for keys the **2.11 line ships**: `write_timeout` (v2.11.11, #7513), `websocket { ping_interval }` (v2.11.12, #7614), and the block-level `cluster` / `gateway` / `leafnodes` `write_deadline` (parsed at v2.11.17, announced only by v2.12.1's #7405). An operator on 2.11.17 reads that the keys are not available to them | `reference/config/write_timeout.md`, `reference/config/websocket/ping_interval.md`, `reference/config/cluster/write_deadline.md`, `reference/config/gateway/write_deadline.md`, `reference/config/leafnodes/write_deadline.md` | nats-docs | wrong-value | low | not filed | wiki: `slow-consumer-detected` § *The 2.11 line* / *The 2.12 line*, `nats-server-2.11` § *The default diff* (via `s-relnotes-2.11`, `s-relnotes-2.12`) |
| 65 | `reference/system/monitor.md` presents fifteen "HTTP monitoring endpoints" reachable at `http://localhost:8222/<z>`; **`statsz`, `idz` and `profilez` are not HTTP endpoints** (404 on 2.14.6 — they exist only as `$SYS.REQ.SERVER.PING.<Z>` requests), and two paths the mux serves are documented nowhere: `/stacksz` and `/debug/vars` | `reference/system/monitor.md`, `monitor/statsz.md`, `monitor/idz.md`, `monitor/profilez.md` | nats-docs | wrong-value | ★ high | not filed | wiki lists the mux's paths |
| 66 | The account-connections event is documented on **`$SYS.ACCOUNT.{account}.CONNECTIONS`** and as fired "when account connection limits are reached"; the server publishes it on `$SYS.ACCOUNT.<acc>.SERVER.CONNS` (and the compatibility `$SYS.SERVER.ACCOUNT.<acc>.CONNS`) on every connect/disconnect **and every 30 s** as a heartbeat — the page's own schema line says so | `reference/system/advisory.md`, `advisory/account-connections.md` | nats-docs | wrong-value | ★ high | not filed | wiki uses the server subjects |
| 67 | Service latency is documented on a fixed subject, `$SYS.SERVER.METRIC.SERVICE.LATENCY`, under `$SYS.SERVER.METRIC.>`; the server publishes it on the subject the export's `latency { subject }` names, in the exporting account, and no `$SYS.SERVER.METRIC` subject exists; the field documented as `error` is `description` | `reference/system/metric.md`, `metric/service-latency.md` | nats-docs | wrong-value | high | not filed | wiki states the export subject |
| 68 | `varz.md` annotates `max_connections` — an integer count — with "nanoseconds depicting a duration in time" | `reference/system/monitor/varz.md` | nats-docs | wrong-value | low | not filed | — |
| 69 | `stream/names.md` documents the response array as `consumers string[]`; the server writes **`streams`** | `reference/jetstream/api/stream/names.md` | nats-docs | wrong-value | medium | not filed | wiki uses `streams` |
| 70 | Four advisory bodies contradict the server: `nak.md` and `terminated.md` type `consumer_seq` as a string (server: `uint64`); `snapshot-create.md` documents `blocks` and `block_size`, which do not exist (the server sends `state`); `stream-action.md` documents `template`, which does not exist; `stream-batch-abandoned.md` omits the `reason` value `unsupported` | `reference/jetstream/advisory/{nak,terminated,snapshot-create,stream-action,stream-batch-abandoned}.md` | nats-docs | wrong-value | ★ high | not filed | wiki carries the server bodies |
| 71 | Across the 24 advisory and metric pages: `domain` is missing from 12 and `account` from 4 more; `consumer-pause.md` and `consumer-group-pinned.md` carry descriptions copied from other pages; two string fields carry a numeric "Minimum: 1" | `reference/jetstream/advisory/`, `metric/consumer-ack.md` | nats-docs | enhancement | low | not filed | — |
| 72 | `reference/jetstream/metric.md` says metrics "can be enabled or disabled at the stream or consumer level"; the only switch is the consumer's `sample_freq`, and nothing in `StreamConfig` enables a metric | `reference/jetstream/metric.md` | nats-docs | wrong-value | low | not filed | — |
| 73 | `consumer/get-next.md` gives the pull request's `batch` a "Maximum: 256"; the server has no such ceiling — a pull of 300 and of 100000 was served on 2.14.6; the only limits are the consumer's `max_batch` (`409 Exceeded MaxRequestBatch of N`) and the server's `max_request_batch` | `reference/jetstream/api/consumer/get-next.md` | nats-docs | wrong-value | medium | not filed | wiki states the real ceiling |
| 74 | The consumer schema describes `opt_start_time` as "Start time used with the DeliverByStartSequence deliver policy"; it is used with `DeliverByStartTime` | `schemas/jetstream/api/v1/consumer_configuration.json` (jsm.go v0.4.1; the docs never render it, #4) | jsm.go | wrong-value | low | not filed | — |
| 75 | `stream/restore.md` labels its request section "A response from the JetStream $JS.API.STREAM.RESTORE API" | `reference/jetstream/api/stream/restore.md` | nats-docs | enhancement | low | not filed | — |
| 76 | `learn/monitoring/prometheus-and-dashboards.md` says "The full set of metric names, check flags, and surveyor options is documented in Reference" — no page of the reference tree lists a series name; and the exporter's default prefix for every core series, `gnatsd_`, is stated nowhere in the docs (only the JetStream `jetstream_` default is), so a reader who omits `-prefix nats` gets names no dashboard expects | `learn/monitoring/prometheus-and-dashboards.md` (lines 23–32, 149) | nats-docs | missing | medium | not filed | wiki tables every series under both prefixes (`reference/metrics`) |
| 77 | `nats-surveyor`'s `--prefix` is documented — the README's flag block and `--help` — as "Replace the default prefix for all the metrics"; at v0.9.11 the flag is parsed into a field declared `Prefix string // TODO` that nothing reads, and every name is built with the literal `nats` namespace: `--prefix x` renames nothing | `nats-io/nats-surveyor` README.md (the usage block) and `cmd/root.go:238` (the help text) | nats-surveyor | wrong-value | low | not filed | wiki says the flag is a no-op |
| 78 | The docs' sample `nats_consumer_num_pending{account,stream_name,consumer_name} 20` never says the value is computed on the consumer's leader only and reads **0 on every replica** — the 3 / 0 / 3 readings operators have reported since 2023 (exporter issue #218, unanswered) — nor that the series carries seventeen labels, `is_consumer_leader` among them | `learn/monitoring/prometheus-and-dashboards.md` (lines 32–43) | nats-docs | enhancement | medium | not filed | wiki states the leader rule with the server lines and the run |
| 79 | `reference/config/accounts/imports.md` lists four keys (`stream`, `service`, `prefix`, `to`) and `exports.md` four (`stream`, `service`, `accounts`, `response_type`); the server's parsers at v2.14.6 also accept `share` and `allow_trace` on an import and `latency`, `response_threshold` (three aliases), `account_token_position` and `allow_trace` on an export — six keys documented on no page of the tree. `imports/service.md` is also described as "Stream import source configuration" | `reference/config/accounts/imports.md`, `imports/service.md`, `exports.md` | nats-docs | missing | medium | not filed | wiki tables all keys in `reference/config-keys` and states `share` on `concepts/service-import-request-info` |
| 80 | Activation tokens — a private export (`token_req: true`, `nsc add export --private`), the `token` an import carries, `nsc generate activation`, expiry and revocation — are described on no page of the 861-page tree; the two mentions (`learn/security/operator-mode.md:14`, `learn/security/cross-account.md:260`) say only that `nats auth` v0.4.0 lacks them and that `nsc` has them. The mirror holds no `nsc` page at all | `learn/security/cross-account.md`, `learn/security/operator-mode.md` | nats-docs | missing | medium | not filed | wiki states the token, its checks and the two `nsc` commands on `concepts/cross-account-sharing` |
| 81 | `concepts/subjects.md:1101` — "**Keep it reasonable**: Limit to ~16 tokens and under 256 characters total" — states a limit no server enforces. At v2.14.6 `isValidSubject` checks empty tokens, whitespace and a non-final `>` and nothing else; the only bounds are `max_control_line` (4096 bytes for the whole line) and the optional `max_subscription_tokens`. The learn page (`learn/core-nats/subjects-and-wildcards.md`) states no such limit, and a reader who asked what the 16 meant was told it is "probably not strictly enforced" (gh#5097). The 256 is most likely `JSMaxNameLen = 255`, which bounds stream and consumer names | `concepts/subjects.md` (line 1101) | nats-docs | enhancement | low | not filed | wiki states the three enforced rules and the real bounds on `concepts/subjects-and-wildcards` |
| 82 | `reference/config/max_subscription_tokens.md` is an empty page: alias `max_sub_tokens`, "Requires Restart", type `integer`, and nothing else — no description, default, range or behaviour. The server: `uint8`, `1`–`255` (`0` refused as "value can not be negative", `256` as "value is too big"), unset = unlimited, applied to **subscriptions only**, violation `-ERR 'Permissions Violation for Subscription to "<subj>", too many tokens'` and log `Subscription Violation Too Many Tokens`. Sweep: the seven sibling `max_*` config pages' reload labels all agree with `reload.go`; this is the only empty one | `reference/config/max_subscription_tokens.md` | nats-docs | missing | medium | not filed | wiki tables the key on `reference/config-keys` and states the rule on `concepts/subjects-and-wildcards` |
| 83 | `concepts/subjects.md:1080–1087` lists `_INBOX` under "Subjects starting with `$` are reserved for system use: `$SYS`, `$JS`, `$KV`, `$O`, `$SRV`, `_INBOX`"; `_INBOX` does not start with `$`, and the learn page (`learn/core-nats/subjects-and-wildcards.md:418–422`) correctly separates the two families. The primer also omits that the server enforces none of the prefixes for a plain client | `concepts/subjects.md` (lines 1080–1087) | nats-docs | enhancement | low | not filed | wiki tables the prefixes and who enforces them on `concepts/subjects-and-wildcards` |
| 85 | The no-responders `503` has carried a `Nats-Subject: <subject>` header since 2.12.0 (#5250), and no page says so: `learn/core-nats/request-reply.md:563` and `headers.md:314–316, 378` describe the reply as `NATS/1.0 503` with an empty body and stop there; the five `Nats-Subject` mentions in the 861-page tree are all Direct Get's header. Run on 2.14.6: `HMSG _INBOX.x 1 38 38` + `NATS/1.0 503\r\nNats-Subject: nobody\r\n\r\n`; across a renamed service import the header names the subject the requester published (`inv.stock`) | `learn/core-nats/request-reply.md` (line 563), `learn/core-nats/headers.md` (lines 314–316, 378) | nats-docs | missing | low | not filed | wiki states the bytes and the version on `concepts/request-reply` |
| 86 | `learn/services/scaling.md:150` "the server delivers each message to whichever queue-group member is ready" and `:272` "The queue group masks this for a while by sending requests to the busy instance's peers instead" — the server picks a random start index over the group's members (`client.go:5516–5519`) and knows nothing of a handler's state. Run on 2.14.6: two members, one sleeping 1 s per request, split 20 concurrent requests 12 / 8 and then 8 / 12; the busy member kept receiving while busy and answered its share one per second | `learn/services/scaling.md` (lines 150, 272) | nats-docs | wrong-value | medium | not filed | wiki states the random pick and the run on `concepts/queue-groups` |
| 87 | `concepts/queue-groups.md:1528` "Use queue groups for operational work that needs to happen **exactly once**" against the same page's `:2131` "Core queue groups never redeliver — a message sent to a worker that crashes mid-processing is lost … Duplicates come only from publisher retries": a queue group is at-most-once, as the deep dive says (`learn/core-nats/queue-groups.md:230`) | `concepts/queue-groups.md` (lines 1528, 2131) | nats-docs | enhancement | low | not filed | wiki states at-most-once on `concepts/queue-groups` |
| 88 | `learn/core-nats/queue-groups.md:218` "On a single server the selection is uniform-random across the available members; a cluster adds a locality preference, covered below" — the section below (`:259–263`) is about several clusters; inside one cluster there is no preference: a peer's members are expanded to their weight in the match list (`sublist.go:741–747`) and picked like local ones. Run on the three-node lab, 2.14.6: one member on the publisher's server and three on a peer received 90 / 97 / 106 / 107 of 400 publishes. The preferences the server does have are across a leafnode (a leaf member is only a fallback, `client.go:5547–5552`) and across a gateway (an exclusion list) | `learn/core-nats/queue-groups.md` (line 218) | nats-docs | enhancement | low | not filed | wiki states the cluster, leafnode and gateway rules with the runs on `concepts/queue-groups` |
| 89 | `nats request` (natscli v0.4.0) exits 0 and prints nothing after `Sending request on "…"` when the request times out, exits 0 with `No responders are available` on a 503, and exits 0 on a reply — a script cannot tell a timeout from a served request by `$?` (`cli/req_command.go:143–150, 205`; run on 2.14.6). Second, `--replies N` ends on any reply with an empty body, `--wait-for-empty` or not (`:179–181`), and `--wait-for-empty` only sets `--replies` to 32767 (`:222–224`); the `--help` text describes neither. The docs' `learn/core-nats/request-reply.md:561` ("The CLI prints the line and exits cleanly") is right for no responders and silent on the timeout | `nats request` in natscli v0.4.0 (`cli/req_command.go`); `learn/core-nats/request-reply.md` (line 561), `scatter-gather.md` (line 621) | natscli | enhancement | low | not filed | wiki states the exit codes and the empty-reply rule on `concepts/request-reply` and `entities/nats-cli` |
| 90 | ADR-40's stale-connection rule is off by one ping. L178 "Missing two consecutive PONGs from the Server", L224 "If two consecutive PONGs are missed, connection is marked as lost triggering reconnect attempt" and L337 "If two (configurable) consecutive `PONGs are missed" — with the ADR's own 2-minute default that reads as **4 minutes**. nats.go does `nc.pout++` and *then* `if nc.pout > nc.Opts.MaxPingsOut` with `DefaultMaxPingOut = 2` (`nats.go:5899–5921`, `:61` at v1.53.1), so the **third** interval closes it, and `learn/resilient-clients/reconnection.md:325` says so ("detection waits for the third unanswered ping, up to about six minutes"). Measured on 2.14.6 against a `SIGSTOP`ped server: **exactly 6 minutes**. The server enforces the same shape (`ping_interval: "5s"`, `ping_max: 2` → `-ERR 'Stale Connection'` at t=12.19 s) | `raw/adr/ADR-40.md` (lines 178, 224, 337) | ADR repo | wrong-value | medium | not filed | wiki carries the run; `client-connection-lifecycle`, `upgrade-a-cluster` and `s-adr-40-nats-connection` corrected 2026-09-04 |
| 91 | The `nats` CLI's reconnect backoff never uses the first entry of its own table. `internal/util/backoff.go:31–38` starts at **500 ms**, and `learn/resilient-clients/reconnection.md:47` repeats it ("a delay callback whose wait starts at 500 ms"); but nats.go increments the sweep counter **before** calling the delay callback — `wlf++; st = crd(wlf)` (`nats.go:3424–3426`) — and `Duration(n)` indexes `Millis[n]`, so the first call is `Duration(1)` = 750 ms. Measured on 2.14.6: the printed delays were 640 ms, 800 ms, **2.15 s**, 1.979 s, 3.424 s, 1.873 s, and 2.15 s can only come from `Duration(3)` = 1500 ms jittered into [750, 2250] | natscli v0.4.0 `internal/util/backoff.go` (lines 31–48), `cli/util.go` (lines 248–256); `learn/resilient-clients/reconnection.md` (line 47) | natscli | enhancement | low | not filed | wiki states the measured first step on `reference/client-defaults` and `entities/nats-cli` |
| 92 | `learn/resilient-clients/slow-consumers.md:100` "In Go a connection with no async error callback discards these reports, and dropped messages become invisible", repeated as `where-next.md:99` "a nil one drops every overflow message silently". nats.go **installs one**: `if nc.Opts.AsyncErrorCB == nil { nc.Opts.AsyncErrorCB = defaultErrHandler }` (`nats.go:1979–1981` at v1.53.1), and `defaultErrHandler` writes `<err> on connection [<cid>] for subscription on "<subject>"` to **`os.Stderr`** (`:2006–2028`). The advice (always set one) is right; the reason given for it is not — and the client that really is silent here is the `nats` CLI, which overrides the handler with a trace-gated one | `learn/resilient-clients/slow-consumers.md` (line 100), `where-next.md` (line 99) | nats-docs | wrong-value | medium | not filed | wiki states the stderr fallback on `entities/nats-go` and `reference/client-defaults` |
| 93 | Two pages give the Go auth-error abort different scopes. `connection-events.md:244` "receiving the same authentication error twice aborts reconnecting"; `tls-and-auth.md:206` "nats.go closes the connection when **the same server** returns the same auth error twice in a row". The source keys on the *current server*: `if nc.current.lastErr == err && !nc.Opts.IgnoreAuthErrorAbort { nc.ar = true }` (`nats.go:4085–4089` at v1.53.1). The first page's wording is materially wrong for a pool: two auth errors from two different servers do not abort | `learn/resilient-clients/connection-events.md` (line 244) | nats-docs | wrong-value | low | not filed | wiki states the per-server rule on `client-connection-lifecycle` and `s-nats-go-connection` |
| 94 | Nothing in the chapter says that a drain issued while the connection is down **closes it instead**. nats.go's `Drain()` returns `ErrConnectionReconnecting` after calling `nc.Close()` when the status is CONNECTING or RECONNECTING (`nats.go:6310–6314`), and `drainConnection` repeats the check (`:6211–6215`). The consequence is the one the same chapter warns about elsewhere: `Close()` "drops the reconnect buffer" (`drain-and-shutdown.md:12`), so a SIGTERM that lands during an outage discards the buffered publishes a drain was expected to flush | `learn/resilient-clients/drain-and-shutdown.md` (the *Drain finishes in-flight work* and *drain timeout* sections) | nats-docs | missing | medium | not filed | wiki states it on `client-connection-lifecycle` and `entities/nats-go` |
| 95 | `learn/resilient-clients/drain-and-shutdown.md:146–168` uses the CLI's global `--timeout 30s` to stand in for a drain timeout and describes it as "a generous operation timeout so a slow handshake is not cut off mid-flush"; `nats --help` at 0.4.0 calls the same flag "Time to wait on responses from NATS" with a default of `5s`. The flag bounds waiting for a reply, not a handshake and not a flush, and the CLI has no drain-timeout flag at all — which the page does say two paragraphs earlier | `learn/resilient-clients/drain-and-shutdown.md` (lines 146, 168); `nats --help` at 0.4.0 | nats-docs | enhancement | low | not filed | wiki notes the CLI has no drain-timeout flag on `s-docs-resilient-clients-drain-and-shutdown` |
| 84 | `learn/core-nats/subject-mapping.md:646` "list the source subject itself as a destination, which tells the server your weights are final and stops it topping them up. This works because the source here is a literal subject" and `:772` "This only works for a literal source like `orders.created`" — the restriction is not in the server. `AddWeightedMappings` skips the auto-added remainder whenever the source string is among the destinations, wildcard or not (`accounts.go:844–862`); run on 2.14.6, `"orders.loss.>": [ { destination: "orders.loss.>", weight: 50 } ]` passed `nats-server -t` and dropped 102 of 200 publishes. The server's own example config uses exactly that shape as "A chaos testing trick that introduces 50% artificial message loss" (quoted in gh#5172). `reference/config/mappings/weight.md` mentions "artifical message loss" without saying how it is configured | `learn/core-nats/subject-mapping.md` (lines 646, 772); `reference/config/mappings/weight.md` | nats-docs | wrong-value | low | not filed | wiki states the rule with the literal and the wildcard run on `concepts/subject-transforms` |

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

**Evidence of harm, added 2026-09-03.** Because the node is collapsed, the reference also never says
the **unit** of `ack_wait`, `backoff`, `inactive_threshold` or any other duration field on the
consumer create request — the sibling response-field notes ("nanoseconds depicting a duration in
time, signed 64 bit integer", e.g. `pause_remaining` on the same page, `expires` on `get-next.md`)
are the only place the word appears. Stack Overflow #78603662 (2024-06-10, .NET, unanswered) is what
that costs: `Backoff = [10000]` sent as a raw number is ten microseconds, the first entry becomes
`ack_wait`, and every acked message is processed `MaxDeliver` times. Verified on 2.14.6: the server
stores `ack_wait: 10000` and the CLI prints `Ack Wait: 10µs` (`raw/nats-server-src/redelivery-observed-v2.14.6.md`,
run H). Suggested addition to the fix: expand the node **with units** on every duration field.

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

**Added 2026-09-03 — the description, not only the default.** The generated page says
`max_buffered_msgs` is "Messages the server buffers for a stream whose storage is temporarily
unavailable, before it starts discarding" and `max_buffered_size` is "Byte ceiling for that same
buffer". The v2.11.0 release body, which introduced both, says the opposite of "storage unavailable":
"Stream ingest rate limiting (#5796) — New `max_buffered_size` and `max_buffered_msgs` options in the
`jetstream` block of the server config control how many publishes should be queued before
rate-limiting, making it easier to protect the system against Core NATS publishes into JetStream —
Where a reply subject is provided, rate-limited messages will receive a 429 "Too Many Requests"
response and can retry later". The server agrees with the body: the values size the stream's inbound
queue (`stream.go:900–906`), and `queueInbound` (`stream.go:5768–5783`) drops a message the queue
refuses, logs `Dropping messages due to excessive stream ingest rate on '<account>' > '<stream>'`, and
answers a reply subject with `NATS/1.0 429 Too Many Requests` and `JSStreamTooManyRequestsError`.
Nothing about storage being unavailable. Suggested wording: "Publishes queued per stream before the
server rate-limits with `429 Too Many Requests` (when a reply subject is present) and drops the
message; default 100,000 messages / 128 MB."

**Added 2026-09-03 — where the 10,000 comes from.** It was the default when the keys arrived in
v2.11.0 (#5796); v2.12.0's body, *Changed / JetStream*: "The default value for `max_buffered_msgs`
has been increased by 10x to 100,000 messages (#6633)" (PR "(2.12) Raise max_buffered_msgs defaults
by 10x", merged 2025-08-28). The generated page carries the pre-2.12 value into the 2.14 docs tree.




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

## 43 · Two system-level subjects in the API reference are not the ones the server serves ★

**Impact: a request or an ACL built from the reference silently targets nothing.** Sent on the system
account to the documented subject, the request is answered by the generic `$JS.API.>` handler with an
unrelated error, so an operator debugging it is steered toward credentials rather than the subject.

**Docs:** `reference/jetstream/api/meta.md` line 7 — `| Meta server remove | … | $JS.API.META.SERVER.REMOVE | Yes |`;
`reference/jetstream/api/meta/server-remove.md` line 10, under `## Subject` — `` `$JS.API.META.SERVER.REMOVE` ``.
The **same page** captions its request and response "A request to the JetStream $JS.API.SERVER.REMOVE
API" (line 14) and "A response from the JetStream $JS.API.SERVER.REMOVE API" (line 26).

**Server, v2.14.6:** `server/jetstream_api.go:195` — `JSApiRemoveServer = "$JS.API.SERVER.REMOVE"`;
subscribed by the meta leader at `server/jetstream_cluster.go:7525`. ADR-61 and ADR-62 both write
`$JS.API.SERVER.REMOVE`.

**Observed** (`raw/nats-server-src/jetstream-cluster-observed-v2.14.6.md` §12), nats CLI 0.4.0 on the
system account:

```
$ nats req '$JS.API.META.SERVER.REMOVE' '{"peer":"nope"}'
{"type":"io.nats.jetstream.api.v1.system_response","error":{"code":503,"err_code":10039,"description":"JetStream not enabled for account"}}
$ nats req '$JS.API.SERVER.REMOVE' '{"peer":"nope"}'
{"type":"io.nats.jetstream.api.v1.meta_server_remove_response","error":{"code":400,"err_code":10044,"description":"server is not a member of the cluster"}}
```

**The second subject: account purge.** `reference/jetstream/api/account.md` line 7 and
`reference/jetstream/api/account/purge.md` lines 10 and 14 give `$JS.API.ACCOUNT.PURGE`. The server
defines `JSApiAccountPurge = "$JS.API.ACCOUNT.PURGE.*"` and `JSApiAccountPurgeT =
"$JS.API.ACCOUNT.PURGE.%s"` (`server/jetstream_api.go:200–201`) — the account is a subject token, and
a NATS `*` wildcard does not match the absence of a token. Observed on the system account (same raw
file, §12):

```
$ nats req '$JS.API.ACCOUNT.PURGE' '' --timeout 2s
21:58:37 Sending request on "$JS.API.ACCOUNT.PURGE"
(no response)
$ nats req '$JS.API.ACCOUNT.PURGE.NOPE' '' --timeout 2s
{"type":"io.nats.jetstream.api.v1.account_purge_response","initiated":true}
```

**The neighbours, checked.** Every `$JS.API.…` mention in the 32 pages under
`reference/jetstream/api/` — 98 of them, with `{stream}`-style placeholders normalised — was compared
with every `$JS.API.` string literal in `server/jetstream_api.go` at v2.14.6. Five mentions mismatch,
all of them these two subjects; the other 93 agree.

**The purge page's system-account column is also wrong.** `reference/jetstream/api/account.md` line 7
reads `| Account purge | … | No |`; `jsLeaderAccountPurgeRequest` (`server/jetstream_api.go:2841–2856`)
returns without replying when the request is not from the system account (`if acc != s.SystemAccount()
{ return }`, line 2851) — it is subscribed with `systemSubscribe` alongside stepdown and server-remove
(`server/jetstream_cluster.go:7537–7539`).

**Suggested fix:** `$JS.API.SERVER.REMOVE` on the two meta lines, matching the page's own captions and
the ADRs; `$JS.API.ACCOUNT.PURGE.{account}` on the three account lines, with the token documented, and
`Yes` in the account table's system-account column.

## 44 · Nothing says a standalone server's streams are deleted when it joins a cluster

**Impact: silent, total loss of a standalone server's JetStream data on a migration the documentation
itself narrates.** Not marked ★ because the chapter's literal configs use fresh server names and fresh
`store_dir`s (`./js/n1-east`, not the single server's `./js/n1`) and say "the durable `ORDERS` stream
isn't on `east` yet"; a reader who follows them exactly loses nothing. A reader who takes the
composition claim at its word — keeps `n1`, adds a `cluster {}` block — loses every stream, 30 seconds
after the restart, with one WARN line.

**Docs:** `learn/topologies/putting-it-together.md` line 38 — "The cluster is three servers, each one a
server like `n1`, added without removing the single server … the layer below keeps working exactly as
it did." `learn/topologies/your-first-cluster.md` line 4 — "That server publishes `orders.*` and holds
the `ORDERS` stream." `learn/topologies/jetstream-in-a-cluster.md` introduces the meta layer and never
says what a stream without an assignment in it becomes. The word `orphan` occurs in the tree only for
un-backed-up operator keys, object-store chunks and firewalled nodes.

**Server, v2.14.6:** `server/jetstream_cluster.go:1507–1585` — `checkForOrphans` and `getOrphans`:
"Streams and consumers are recovered from disk, and the meta layer's mappings should clean them up, but
under crash scenarios there could be orphans"; scheduled by `time.AfterFunc(30*time.Second,
js.checkForOrphans)` at the end of meta recovery; deletes every recovered stream absent from the
assignment map, logging `Detected orphaned stream '%s > %s', will cleanup`. No option gates it.

**Observed** (`raw/nats-server-src/jetstream-cluster-observed-v2.14.6.md` §10): a standalone server
holding `ORPHAN` (R1, 3 messages), restarted with a `cluster {}` block joining a live three-node cluster:
`Restored 3 messages for stream '$G > ORPHAN'` at 21:43:25.470, `JetStream cluster new metadata leader`
at 21:43:26.018, `Detected orphaned stream '$G > ORPHAN', will cleanup` at 21:43:55.584; the stream and
its directory were gone. The maintainers confirmed the behaviour and that in-place migration "is not
planned" in `nats-io/nats-server` discussion #7831 (2026-03).

**Suggested fix:** one paragraph on `learn/topologies/your-first-cluster.md` (or the Pitfalls list) and
one on `jetstream-in-a-cluster.md` stating that a server's JetStream store must not be carried into a
cluster: a stream with no meta-layer assignment is treated as an orphan and deleted 30 s after the
server joins; back up and restore, or mirror across a leafnode, instead. A `learn/` note on the
composition page that the reversibility claim covers the messaging layer, not JetStream state.

## 45 · The meta API reference is called complete and omits the stream-move subjects

**Impact: low** — the `nats` CLI and `nats-server` agree; only a reader building ACLs or tooling from
the reference is affected.

**Docs:** `learn/clustering/scaling-and-peers.md` line 79 — "The full set of peer-management and
stream-assignment operations is documented in [Reference → meta API]". `reference/jetstream/api/meta.md`
lists two rows: leader stepdown and server remove.

**Server, v2.14.6:** `server/jetstream_api.go:187–212` defines five system-account subjects, and
`server/jetstream_cluster.go:7522–7538` subscribes the meta leader to all five:
`$JS.API.META.LEADER.STEPDOWN`, `$JS.API.SERVER.REMOVE`, `$JS.API.ACCOUNT.STREAM.MOVE.*.*`,
`$JS.API.ACCOUNT.STREAM.CANCEL_MOVE.*.*`, `$JS.API.ACCOUNT.PURGE.*`. The sweep in #43 found the two
`STREAM.MOVE` forms in no file under `reference/jetstream/api/`; account purge has its own page under
`api/account/`.

**Suggested fix:** two rows in `reference/jetstream/api/meta.md` (system account: yes) with pages for
the move and cancel-move requests, or drop "full set" from the learn page.

## 46 · `extension_hint` is documented without its purpose or its values

**Impact: low.** The key matters only to leafnode deployments that share the system account, but for
those it decides whether a server forms its own JetStream domain or waits, possibly forever, to extend
another.

**Docs:** `reference/config/jetstream/extension_hint.md` in full: the title, "Requires Restart", and a
type table with `string` and two dashes. No description, no values.

**Server, v2.14.6:** `server/jetstream.go:567–568` — `jsNoExtend = "no_extend"`,
`jsWillExtend = "will_extend"`; `server/jetstream_cluster.go:1040` decides observer mode from it, and
lines `1052–1055` / `1069–1071` print the operator instruction
`manually disable Observer Mode by setting the JetStream Option "extension_hint: no_extend"`;
`server/jetstream.go:509–513` prints the `will_extend` counterpart for a standalone server.

**Suggested fix:** a description ("whether a server that solicits a leafnode connection sharing the
system account should extend that JetStream domain or run its own") and the two values in the
`Choices` column.

## 47 · The `/raftz` reference page is empty, and three learn pages promise it is not

**Impact: an operator sent to the reference for RAFT tuning or field meanings finds nothing, and may
conclude the parameters exist somewhere else.** They do not exist as parameters at all.

**Docs.** `reference/system/monitor/raftz.md`, fetched 2026-08-31 and re-fetched from the live site on
2026-09-01 (173 bytes, identical), in full: `## Request Schema` — "Request options for raftz monitoring
endpoint", `account` string, `group` string; `## Response Schema` — "Response from raftz monitoring
endpoint", and nothing under it. Compare the sibling `jsz.md`, whose response schema lists its fields
(`meta_cluster` object, …).

What sends readers there: `learn/clustering/raft-and-leaders.md` line 52 — "The full set of RAFT
internals it exposes is documented in Reference → /raftz: log compaction, the `$NRG.*` subjects peers
vote over, snapshot timing."; line 162 — "the RAFT group monitoring endpoint and its full field set.";
`learn/clustering/replication-and-r3.md` line 257 — "You'll find the full set of RAFT replication
parameters (append-entry batching, heartbeat intervals, log compaction) in Reference."

**Server, v2.14.6.** The response is `RaftzStatus` = `account → group → RaftzGroup`
(`server/monitor.go:4195–4232`): `id`, `state`, `size`, `quorum_needed`, `observer`, `paused`,
`overrun`, `overrun_count`, `committed`, `applied`, `catching_up`, `leader`, `leader_since`,
`ever_had_leader`, `term`, `voted_for`, `pterm`, `pindex`, `system_account`, `traffic_account`, four
`ipq_*_len` queue lengths, `wal`, `wal_error`, `peers{name, known, last_replicated_index, last_seen}`.
The things the learn pages promise are not fields: heartbeat `1s`, election `4–9s`, lost-quorum `10s`
(`server/raft.go:289–310`), append batch `256 KB / 512 entries` (`raft.go:3250–3251`), compaction
thresholds in `server/jetstream_cluster.go` (`1601–1628`, `3188–3197`, `6602–6612`) — package
constants, none exposed by any endpoint or set by any key (`opts.go` parses no key for them).

**Observed** (`raw/nats-server-src/raftz-v2.14.6.md`): the endpoint's real output on a four-node
cluster, follower and leader views.

**Suggested fix:** generate the response schema from `RaftzGroup` as the sibling pages do; and on the
two learn pages, either drop the parameter list or say plainly that heartbeat, election, batching and
compaction are fixed in the server. The `$NRG.*` subjects would be a reasonable addition to the
reference.

## 48 · Six monitor reference pages document request options the HTTP endpoints ignore ★

**Impact: a filter copied from the reference into a URL does nothing, silently.** The page returns its
unfiltered form, which for `/jsz`, `/subsz` and `/raftz` looks like a plausible answer.

**Docs, v2.14 tree.** Each page's `## Request Schema` opens "Request options for `<z>` monitoring
endpoint" and then lists the JSON tags of the Go options struct that the **system request**
`$SYS.REQ.SERVER.PING.<Z>` (and `nats server request <z>`) accepts:

| page | documented names | what the HTTP handler reads (`server/monitor.go`) |
|---|---|---|
| `accountz.md` | `account` | `acc` (`HandleAccountz`) |
| `jsz.md` | `account`, `consumer`, `direct_consumer`, `leader_only`, `stream_leader_only` | `acc`, `consumers`, `direct-consumers`, `leader-only`, `stream-leader-only` (`HandleJsz`) |
| `leafz.md` | `account`, `subscriptions` | `acc`, `subs` (`HandleLeafz`) |
| `subsz.md` | `account`, `subscriptions` | `acc`, `subs` (`HandleSubsz`) |
| `gatewayz.md` | `account_name`, `name`, `subscriptions`, `subscriptions_detail` | `acc_name`, `gw_name`, `accs` (`HandleGatewayz`) |
| `raftz.md` | `account` | `acc` (`HandleRaftz`, line 4241) |

The decode lines are quoted with line numbers in `raw/nats-server-src/raftz-v2.14.6.md`. `connz.md`
prints `acc` and matches its handler; `healthz.md` matches exactly. `routez`, `ipqueuesz`, `profilez`
and `statsz` were not resolved by the sweep (their handlers parse differently) and are not claimed.

**Observed, 2.14.6:**

```
/accountz?account=NOPE   → 200, the normal page
/accountz?acc=NOPE       → 400 "Account NOPE does not exist"
/raftz?account=NOPE      → 200, {"$SYS": {"_meta_": …}}
/raftz?acc=NOPE          → 200, {}
```

**Why it happens** is visible in the pages themselves: the schema is generated from the request
struct (`RaftzOptions{AccountFilter string `json:"account"`}`, `monitor.go:3021–3024`), whose tags
name the system-request payload, while `HandleRaftz` reads `r.URL.Query().Get("acc")` (`4241`). Both
interfaces are real; the pages describe one and are titled for the other.

**Suggested fix:** per page, a second column or a note giving the HTTP query name, or a sentence
saying the listed names are the `$SYS.REQ.SERVER.PING.<Z>` payload and the URL parameters differ —
with `connz.md` as the model, since it already prints the HTTP names.

## 49 · ADR-59 names the replication consumer `mirror-<id>` / `src-<id>`; the 2.14 server names it `JS_MIRROR_<id>` / `JS_SRC_<id>`

**Impact: an operator reading ADR-59 to find the internal consumer on an upstream (to inspect it, or
to know which consumer not to delete) looks for a name the 2.14 server never uses.** ADR-59 is
marked *Implemented* and calls itself "the authoritative reference for stream sourcing and mirroring".

**ADR.** `raw/adr/ADR-59.md` line 654, § *Internal consumers*: "When a filter subject is configured
(either directly via `filter_subject` or from a single `subject_transforms` entry), the consumer is
created with an explicit name following the pattern `mirror-<id>` or `src-<id>` using the extended
consumer create API. When no filter is present (or multiple subject transforms are configured), the
consumer is created via `$JS.API.CONSUMER.CREATE.<stream>` and receives a randomly generated name
from the server." Revision 1 (2026-03-03) "documents features up to 2.12.5"; revision 2
(2026-04-29) touched only the Mirror Direct section.

**Server.** At **v2.10.0** `server/stream.go:2558` and at **v2.12.0** `:3258` the code is
`req.Config.Name = fmt.Sprintf("mirror-%s", createConsumerName())` inside `if
req.Config.FilterSubject != _EMPTY_`, exactly as the ADR says. At **v2.14.6** the request is built
with `Name: fmt.Sprintf("JS_MIRROR_%s", id)` unconditionally (`stream.go:3561`; the source
equivalent `JS_SRC_%s` at `:4019`), where `id` is a stable hash, and the same name is recomputed to
delete the consumer (`:2797`, `:2805`); a fallback `JS_MIRROR_<id>_<random>` is used only when the
upstream rejects `sourcing` (`:3741`). ADR-60 (the 2.14 durable-sourcing spec) states the new form:
"Should be named in the form `JS_MIRROR_<suffix>`" (line 46) and `JS_SRC_<suffix>` (line 50).

**Observed** (`raw/nats-server-src/mirrors-observed-v2.14.6.md`, run A2): two mirrors of `KV_DNS`
on 2.14.6 produced `JS_MIRROR_OQyMJ0fQ-7i1hqwDz` and `JS_MIRROR_HNs8w7PP-7H9l9Nd5` in
`/jsz?…&direct-consumers=true`, both with `filter: null` — no filter, and still an explicit name.

**Suggested fix:** in ADR-59 § *Internal consumers*, state the 2.14 form (`JS_MIRROR_<id>` /
`JS_SRC_<id>`, always explicit, hidden from the consumer API by `Direct`) with a pointer to ADR-60,
and keep the `mirror-<id>` / `src-<id>` sentence as the ≤ 2.12 behaviour with that version on it.

## 50 · The docs never say an object-store bucket can be mirrored, or how

**Impact: the obvious procedure — `nats stream add OBJ_X_mirror --mirror OBJ_X` with the domain
import — produces a bucket that `nats object ls` lists but that lists as empty and whose objects
cannot be fetched; nothing in the docs says why, or that a transform is required.** The only public
statement of the recipe is a closed GitHub issue from 2024.

**Docs.** `grep -ril mirror raw/nats-docs/learn/object-store/` → nothing (six pages:
`your-first-object.md`, `chunking.md`, `metadata-and-links.md`, `watching-and-listing.md`,
`under-the-hood.md`, `where-next.md`). `learn/jetstream/mirrors-and-sources.md` → no match for
`object`, `bucket` or `$O.`. Across the whole tree (861 pages) the files containing both *mirror* and
*object store* are the index pages and `learn/key-value/where-next.md`, whose one paragraph is
about KV: "A bucket can be sourced from or mirrored into another bucket … kept in sync by a subject
transform from `$KV.SRC.>` to `$KV.DST.>`". `nats object add --help` (CLI 0.4.0) has no `--mirror`;
`nats kv add --help` has `--mirror` and `--mirror-domain`.

**Server and client.** A mirror has no subjects, and the client derives the metadata and chunk
subjects from the *bucket name* (`$O.<bucket>.M.>`, nats.go `jetstream/object.go:480–483`,
`598–606` at v1.53.1), so a mirror named differently from its origin must carry
`subject_transforms: [{"src": "$O.<origin>.>", "dest": "$O.<mirror>.>"}]`. Issue #5106
(`raw/gh-issues/issue-5106.md`) is where a client maintainer states this; nats.go #1874 (open) is
the request to make it first-class, declined for now.

**Observed** (`raw/nats-server-src/mirrors-observed-v2.14.6.md`, run C): without the transform,
`nats object ls dms_mirror` → `No entries found`, `nats object get dms_mirror f1.bin` → `nats:
error: nats: object not found`; with it, list, info, a byte-identical get, and live replication.

**Suggested fix:** a short section in the object-store chapter (or on
`learn/jetstream/mirrors-and-sources.md`): a bucket is a stream and can be mirrored; there is no
CLI or client flag; the stream config needs the `$O.` transform; the mirror is read-only and keeps
its own retention, so deletes on the origin do not propagate; do not reuse the stream name on both
sides of a domain instead (a server maintainer's warning in nats.go #1874).

## 51 · ADR-57 does not say how a mirrored KV bucket is *read*, and the reference client reads it two different ways

**Impact: `nats kv add M --mirror B` in one domain yields a bucket whose `nats kv ls M` prints `No
keys found in bucket` and whose every `nats kv get M <key>` answers `key not found`, while
`nats kv info M` reports all its values; the same command with `--mirror-domain` yields a bucket that
reads normally. No document explains the difference.**

**ADR.** `raw/adr/ADR-57.md` lines 19–40, § *Mirror Configuration*: clients "Prefix the mirror
stream name with `KV_` if not already prefixed" and "Enable `MirrorDirect` on the underlying stream
configuration", which "ensures that mirrored buckets … Support direct reads via the Direct GET API
… Automatically participate in RTT-based replica selection". Sources get an automatic
`$KV.<src>.>` → `$KV.<bucket>.>` transform (§ *Source Configuration*); mirrors deliberately get
none. Nothing says whether a client opening the *mirror* bucket by name reads `$KV.<mirror>.` or
`$KV.<origin>.`.

**Client, nats.go v1.53.1** (`raw/nats-go-src/kv-object-mirror-v1.53.1.md`): `mapStreamToKVS`
sets the read prefix to `$KV.<this bucket>.` (`jetstream/kv.go:1599`); for a mirror it rewrites the
**write** prefix to the origin's, and rewrites the **read** prefix to the origin's only when the
mirror has `external.api` set (`1610–1618`). So same-domain and cross-domain mirrors of the same
bucket answer differently to the same `Get`.

**Observed** (`raw/nats-server-src/mirrors-observed-v2.14.6.md`, run A4 and run C §8): same
domain — `$JS.API.DIRECT.GET.KV_DNS_FILE.$KV.DNS_FILE.k0000001` → `key not found`; across a domain —
`$JS.API.DIRECT.GET.KV_CFG_M.$KV.CFG.k1` → the value.

**Suggested fix:** state in ADR-57 which name a mirror bucket is meant to be read by. If the
intent is "always read the origin's name and let `mirror_direct` route it", say so and have the
same-domain client path either rewrite the read prefix as the cross-domain path does or refuse to
open the mirror by name; if the intent is "a mirror is readable by its own name", the client must
add the transform it adds for sources. Either way the two branches of `mapStreamToKVS` should
agree.

## 52 · The sizing chapter has no per-subject memory term and no recovery term

**Impact: an operator who sizes a file-backed stream from this chapter budgets no RAM for the
subject index and no time for the restart. A stream with a million distinct subjects holds a few
hundred megabytes of index in memory on every node with a replica; a stream of tens of millions of
messages is read end to end after an unclean stop — and, on 2.10–2.14, at every start when it has
`sources` and one of them is idle.**

**Docs.** `raw/nats-docs/learn/deployment/sizing-and-resources.md`, line 16, § *The four resources a
node spends*:

> **Memory** holds connections, subscriptions, and (for memory-storage streams) message data. The
> ORDERS stream uses file storage, so its messages live on disk, not in RAM. […] a few hundred
> connections fit comfortably in a few hundred megabytes.

The chapter sizes disk (well), file descriptors and CPU, and stops there. Searched across all 861
pages of the mirrored tree on 2026-09-02: no page contains `index.db`, "subject index", "per-subject
index", "radix", or the `Restored N messages for stream` log line; no page says that recovery after
an unclean stop reads every block; `reference/config/jetstream/sync_interval.md` is the only page
that mentions unclean shutdowns at all, and only to say syncing more often helps.

**Server, v2.14.6** (`raw/nats-server-src/filestore-recovery-v2.14.6.md`): the per-subject index is
`fs.psim *stree.SubjectTree[psi]` in memory (`filestore.go:197`, `psi` at `:169–173`), rebuilt at
every start; `recoverFullState` (`:1927–2216`) takes `index.db` after a clean stop and `recoverMsgs`
(`:2454–2563`) reads every block otherwise; above `highCardinalityThreshold = 1_000_000` (`:390`)
the periodic write is skipped (`:12006–12009`). Maintainers state the memory cost in public
(`raw/gh-discussions/gh-8333.md`: "in the order of 100 megs of RAM" per million small subjects;
`gh-5202.md`: the ART index since 2.10.9), and Synadia's blog gives "roughly a few hundred bytes"
per subject (`raw/synadia-blog/how-many-subjects-jetstream-stream.txt`, 2026-05-20). Measured
(`raw/nats-server-src/stream-scale-observed-v2.14.6.md`): ~380 B of RSS per subject at 1.2 M
subjects; a 50 M-message stream restored in 3–27 ms after a clean stop and 6.4 s after SIGKILL on an
SSD; a 1.6 GB sourcing stream restored in 2.57 s with one empty source and 23 ms without.

**Suggested fix:** in the *Memory* paragraph, add the per-subject index as a RAM term for file
streams ("budget a few hundred bytes per distinct subject, per node holding a replica; the index is
rebuilt at every start"); add a short *Restart time* item to the resource list (bytes on disk ÷
read throughput after an unclean stop; the source scan on sourcing streams before 2.15), and name
the `Filestore [<stream>] Stream state …` warnings that say the fast path was refused.

## 53 · "Subjects are essentially free" is a core-NATS statement that the docs never qualify for JetStream

**Impact: the one sentence in the docs about subject count says there is no cost, and a reader
designing a stream on `orders.<uuid>` has nothing to set against it.**

**Docs.** `raw/nats-docs/concepts/subjects.md`, line 1108, § *Performance Considerations*:

> **Subjects are essentially free**: Creating new subjects has virtually no overhead - NATS
> efficiently handles millions of unique subjects.

The section is about the interest graph ("Subjects Interest graph is in-memory and dynamic"), and
for core NATS the sentence is right: a subject with no subscriber costs nothing. The page never says
that a JetStream stream indexes every distinct subject it stores, and no JetStream page says it
either (#52).

**Server, v2.14.6:** as in #52 — one index entry per distinct stored subject, in RAM, plus
`len(subject) + 4` bytes in `index.db`, plus the recovery cost above a million.

**Suggested fix:** one clause — "free to *route*; a JetStream stream keeps an in-memory index entry
per distinct subject it stores, see *Sizing & resources*" — and the corresponding paragraph in the
sizing chapter.

## 54 · Four system-account requests from v2.10.0 — `RELOAD`, `KICK`, `LDM`, `PING.IDZ` — are documented nowhere

**Impact: an operator who reads the docs believes a config reload needs a signal to the process
(or the Kubernetes reloader sidecar), and that a single client can only be disconnected by finding
its server and killing the connection. The server has offered both as system-account requests since
2.10.0, and Helm and systemd are not the only environments — an embedded or Windows deployment has
no SIGHUP.**

**Docs.** `raw/nats-docs/learn/deployment/config-management.md` line 128: "With the config validated,
trigger the reload. The mechanism is a **SIGHUP** to the `nats-server` process." The chapter goes on
to the systemd `reload` and the Kubernetes reloader sidecar; the system-account request is not
mentioned. Sweep of 2026-09-03 over the whole docs mirror (`grep -rhoE '\$SYS\.REQ\.SERVER\.…'
raw/nats-docs`): the only `$SYS.REQ.SERVER` subjects written anywhere are `$SYS.REQ.SERVER.PING.VARZ`
(4 pages) and `$SYS.REQ.SERVER.PING.PROFILEZ` (2 pages). `reference/system/monitor.md` and its
subpages name none.

**Release notes.** The v2.10.0 body (`raw/release-notes/v2.10.0.md`, *Added*): "Reload server config
by sending a message in the system account to `$SYS.REQ.SERVER.{server-id}.RELOAD` (#4307)"; "Add
`$SYS.REQ.SERVER.<id>.KICK` NATS endpoint to disconnect a client by `id` or by `name` from the target
server (#4298)"; "Add `$SYS.REQ.SERVER.<id>.LDM` NATS endpoint that sends a "lame duck mode" message
to a client by `id` or `name` on the target server (#4298)"; "Add `$SYS.REQ.SERVER.PING.IDZ` NATS
endpoint for basic server info (#3663)".

**Server, v2.14.6** — `server/events.go`:

```go
clientKickReqSubj         = "$SYS.REQ.SERVER.%s.KICK"          // line 62
clientLDMReqSubj          = "$SYS.REQ.SERVER.%s.LDM"           // line 63
serverPingReqSubj         = "$SYS.REQ.SERVER.PING.%s"          // line 68
serverReloadReqSubj       = "$SYS.REQ.SERVER.%s.RELOAD"        // line 70, "with server ID"
```

and the `PING.<Z>` handler table at lines 1268–1315 registers `IDZ`, `STATSZ`, `VARZ`, `SUBSZ`,
`CONNZ`, `ROUTEZ`, `GATEWAYZ`, `LEAFZ`, `ACCOUNTZ`, `JSZ`, `HEALTHZ`, `PROFILEZ`, `EXPVARZ`,
`IPQUEUESZ`, `RAFTZ` — fifteen names, of which the docs write two. (The payload and URL-parameter
mismatch on the reference pages is #48; this row is about the subjects existing at all.) The wiki
observed `KICK` and `LDM` on the binary in `raw/nats-server-src/kick-ldm-observed-v2.14.6.md`.

**Suggested fix:** one paragraph in *Config management* — "a reload can also be requested over the
system account: publish to `$SYS.REQ.SERVER.<server-id>.RELOAD`" — and a table on the system
reference page listing the `$SYS.REQ.SERVER.<id>.<verb>` requests (`RELOAD`, `KICK`, `LDM`, and each
`<Z>`) with their request bodies, since the server has carried them for three minors.


## 55 · The leafnode listener's `handshake_first` takes a duration and `auto` since 2.11.0; the reference types it boolean

**Impact: an operator who wants the fallback behaviour on the leafnode listener — TLS first for
remotes that support it, the old order after a delay for those that do not — reads the reference and
concludes the leafnode listener cannot do it, or copies the boolean and loses the fallback.**

**Docs.** `raw/nats-docs/reference/config/leafnodes/tls/handshake_first.md`: "Force the leafnode
connection to use a TLS-first handshake prior to the remote sending the `INFO` protocol message …
| `boolean` | - | `true`, `false` |". Against `raw/nats-docs/reference/config/tls/handshake_first.md`:
"Send the TLS handshake before the `INFO` protocol message rather than after. A duration string
instead of `true` waits that long for a client that may not support it before falling back. |
`boolean` … | `string` |".

**Release notes.** v2.11.0 (`raw/release-notes/v2.11.0.md`, *Added / Leafnodes*): "Support for TLS
First on leafnode connections with the `handshake_first` option (#4119, #5783)". PR #5783 is "(2.11)
[ADDED] LeafNode: Support for TLS handshake_first duration" (merged 2024-08-13); #4119 is the 2.10.0
boolean.

**Server, v2.14.6** — `server/opts.go`. Every TLS block goes through `parseTLS` (`parseLeafNodes` calls
`parseTLS(tk, true)` at line 2875), whose `handshake_first` case (lines 5309–5331) accepts:

```go
case "handshake_first", "first", "immediate":
    switch mv := mv.(type) {
    case bool:
        tc.HandshakeFirst = mv
    case string:
        switch strings.ToLower(mv) {
        case "true", "on":   tc.HandshakeFirst = true
        case "false", "off": tc.HandshakeFirst = false
        case "auto", "auto_fallback":
            tc.HandshakeFirst = true
            tc.FallbackDelay = DEFAULT_TLS_HANDSHAKE_FIRST_FALLBACK_DELAY
        default:
            if dur, err := time.ParseDuration(mv); err == nil {
                tc.HandshakeFirst = true
                tc.FallbackDelay = dur
                break
            }
            return nil, &configErr{tk, fmt.Sprintf("field %q's value %q is invalid", mk, mv)}
```

and the leafnode listener keeps both values (lines 2888–2889):

```go
opts.LeafNode.TLSHandshakeFirst = tc.HandshakeFirst
opts.LeafNode.TLSHandshakeFirstFallback = tc.FallbackDelay
```

The remote side keeps only the boolean (line 3157, `remote.TLSHandshakeFirst = tc.HandshakeFirst`;
`RemoteLeafOpts` has no fallback field, line 265), so
`reference/config/leafnodes/remotes/tls/handshake_first.md` being `boolean` is right in effect.

**Sweep.** Of the eight `handshake_first` pages in the generated reference (`tls`, `cluster.tls`,
`gateway.tls`, `gateway.gateways.tls`, `mqtt.tls`, `websocket.tls`, `resolver_tls`, and the two
leafnode ones), six are typed `boolean`/`string`; only the leafnode listener's and the remote's are
`boolean`. One wrong.

**Suggested fix:** give `leafnodes/tls/handshake_first.md` the same type table and sentence as
`tls/handshake_first.md`, and say "since 2.11.0" for the duration form.

## 56 · `cluster_traffic: owner` — a v2.11.0 account option with no page anywhere

**Impact: an operator whose system account is a bottleneck for Raft replication traffic — or who
wants per-account accounting of that traffic — has an option the server has carried since 2.11.0
and no way to learn of it from the docs.**

**Docs.** No page. `grep -rl cluster_traffic raw/nats-docs/` returns nothing (mirror of 2026-08-31);
the generated `reference/config/accounts/` tree has no such key; `learn/clustering/` and
`learn/security/` never mention it. The reporting fields are absent too: `grep -rl traffic_account
raw/nats-docs/` and `grep -rl 'system_account' raw/nats-docs/reference/system/` find nothing for the
stream-info field.

**Release notes.** v2.11.0, *Added / JetStream*: "Ability to move cluster Raft traffic into the asset
account instead of using the system account using the new `cluster_traffic` configuration option
(#5466, #5947)". v2.11.9, *Improved*: "The `raftz` endpoint now reports the cluster traffic account
(#7186)"; "The stream info and consumer info endpoints now return `system_account` and
`traffic_account` (#7193)"; "The `jsz` monitoring endpoint now returns `system_account` and
`traffic_account` (#7193)". Fixes: 2.11.2 (#6733, startup parse), 2.11.9 (#7191, operator mode),
2.11.12 (#7723, config mode).

**Server, v2.14.6** — `server/opts.go`, inside `parseJetStreamForAccount` (function at line 2378),
lines 2451–2463:

```go
case "cluster_traffic":
    vv, ok := mv.(string)
    if !ok {
        return &configErr{tk, fmt.Sprintf("Expected either 'system' or 'owner' string value for %q, got %v", mk, mv)}
    }
    switch vv {
    case "system", _EMPTY_:
        acc.nrgAccount = _EMPTY_
    case "owner":
        acc.nrgAccount = acc.Name
    default:
        return &configErr{tk, fmt.Sprintf("Expected 'system' or 'owner' string value for %q, got %v", mk, mv)}
    }
```

So the key lives in an account's `jetstream { … }` block next to `max_ack_pending`, takes `system`
(the default) or `owner`, and is reported by `server/stream.go` lines 375–377 (`leader_since`,
`system_account`, `traffic_account` on the cluster info) and `jetstream_cluster.go:10997`.

**Suggested fix:** a generated page `reference/config/accounts/<name>/jetstream/cluster_traffic.md`
(type `string`, choices `system` | `owner`, default `system`, restart-only or reloadable as the
reload code says), a paragraph in the clustering chapter on when to move Raft traffic off the system
account, and the two fields on the stream-info and `jsz` reference pages.

## 57 · `config_digest`, `tls_cert_not_after`, `leader_since` — 2.11 monitoring fields the reference never lists

**Impact: the two fields an operator would alert on — a certificate about to expire, a config that
drifted from the file — and the one that answers "how long has this leader been leader" exist in
`/varz` and stream info and are not discoverable from the docs.**

**Docs.** `grep -rl` over the whole mirror (2026-08-31): `config_digest` 0 pages, `tls_cert_not_after`
0 pages, `leader_since` 0 pages. The generated `reference/system/monitor.md` and its `varz`, `jsz`
subpages are the natural home (and are already the subject of #48 for their field names).

**Release notes.** v2.11.0, *Added / General*: "Configuration state digest (#4325) — A hash of the
configuration file can be generated using the `-t` option on the command line — The hash of the
currently running configuration file can be seen in the `config_digest` option in `varz`". v2.11.12,
*Added / Monitoring*: "Added `tls_cert_not_after` to the `varz` monitoring endpoint for showing when
TLS certificates are due to expire (#7709)". v2.11.9, *Improved*: "The stream info and consumer info
endpoints now return `leader_since` (#7189)".

**Server, v2.14.6** — `server/monitor.go`: ``ConfigDigest string `json:"config_digest"` `` (line
1283); ``TLSCertNotAfter time.Time `json:"tls_cert_not_after,omitzero"` `` on `Varz` (line 1296) and on
the cluster, gateway, leafnode, MQTT and WebSocket option blocks (lines 1320, 1338, 1360, 1391,
1410); ``LeaderSince *time.Time `json:"leader_since,omitempty"` `` (line 4208), and in
`server/stream.go` line 375 on the cluster info.

**Suggested fix:** the three fields on the `varz` and stream/consumer-info reference pages, each
with its "since" (2.11.0, 2.11.12, 2.11.9).

**Added 2026-09-03 — two more.** `in_client_msgs`, `in_client_bytes`, `out_client_msgs` and
`out_client_bytes` in `/varz` — "for tracking data to/from normal clients only" (v2.12.9 / v2.14.1,
#7851) — and the `window_size` parameter of the stream snapshot endpoint (v2.12.5, #7839) are
likewise named on no docs page (`grep -rl` over the mirror: 0 each).


## 58 · The 2.12 upgrade guide dates `GOMAXPROCS` / `GOMEMLIMIT` reporting to 2.12; it shipped in 2.10.28 and 2.11.2

**Impact: small — an operator on 2.11 reading "what's new in 2.12" believes the two Go limits are
not in their `/varz` until they upgrade. They have been there since 2025-04-25.**

**Docs.** `raw/nats-docs/release-notes/upgrade-to-2.12.md`, line 44, under the 2.12 improvements:
"**`GOMAXPROCS` and `GOMEMLIMIT` in server stats:** The server stats already contained the CPU and
memory usage of the server but now also contains the effective Go limits."

**Release notes.** `raw/release-notes/v2.10.28.md` and `raw/release-notes/v2.11.2.md`, both
2025-04-25, *Improved / General*: "`GOMAXPROCS` and `GOMEMLIMIT` are now reported in both `statsz`
and `varz` (#6791)". PR #6791, "[ADDED] Report `GOMAXPROCS` and `GOMEMLIMIT` in `ServerStats`",
merged 2025-04-11. The v2.12.0 body (2025-09-22) does not list it.

**Suggested fix:** drop the bullet, or reword it as "since 2.10.28 / 2.11.2".

## 59 · `max_concurrent_io` (2.12.14 / 2.14.4) is documented nowhere

**Impact: the one JetStream knob that governs how many disk operations run at once — the number
that decides whether a large recovery or a burst of writes saturates a volume — cannot be found in
the docs, and neither can the fact that its default changed from a CPU-scaled count to 4096.**

**Docs.** `grep -rl max_concurrent_io raw/nats-docs/` returns nothing (mirror of 2026-08-31, the 2.14
tree); the generated `reference/config/jetstream/` has no page for it.

**Release notes.** `raw/release-notes/v2.12.14.md` and `raw/release-notes/v2.14.4.md` (2026-07-30),
*Improved / JetStream*: "The disk concurrency semaphore has been increased to 4096 slots, up from the
previous CPU-scaled count (#8336)"; "The disk concurrency semaphore can now be configured with the
`max_concurrent_io` option in the `jetstream` config block (#8336)". PR #8336: "Server-scope disk
I/O semaphore, add `max_concurrent_io`, raise default".

**Server, v2.14.6** — `server/dios.go` lines 21–23 and 35–36:

```go
const defaultConcurrentIOs = 4096
const minConcurrentIOs = 4
const maxConcurrentIOs = 8192

func newDiskIOSemaphore(n int) *diskIOSemaphore {
	n = max(minConcurrentIOs, min(n, maxConcurrentIOs))
```

`server/opts.go` lines 2789–2794 parse `max_concurrent_io` in the `jetstream` block into
`opts.JetStreamConcurrentIOs`, rejecting values outside `minConcurrentIOs`…`maxConcurrentIOs`;
`server/server.go` line 778 builds the semaphore from it; `jetstream.go` line 752 sizes the parallel
recovery task queue as `min(64, s.diskIOSemaphore().cap())`.

**Suggested fix:** a generated page `reference/config/jetstream/max_concurrent_io.md` (integer,
default 4096, range 4–8192, restart-only or reloadable as the reload code says, since 2.12.14 /
2.14.4), and a sentence in the sizing chapter.

## 60 · The `proxies { trusted [ … ] }` block of ADR-55 has no page

**Impact: v2.12.0 added a way to require that clients arrive through a NATS-aware proxy and to name
which proxies are trusted; the docs document the client-side switch (`proxy_required`) and the error
a rejected connection gets, and never the list itself.**

**Docs.** The generated reference has `reference/config/proxy_protocol.md` (the PROXY protocol,
2.12.2), `reference/config/authorization/proxy_required.md` and its leafnode siblings, and
`reference/system/errors.md` line 11: "Proxy is not trusted | `ErrAuthProxyNotTrusted` | An error
condition on failed authentication due to a connection from a proxy not in the list of trusted
proxies". `grep -rli 'trusted.prox' raw/nats-docs/` finds only that line; no `proxies` page exists.

**Release notes.** `raw/release-notes/v2.12.0.md`, *Added / JetStream*: "Support for trusted proxies
(#7153) — Allows enforcing that connections arrive via a NATS protocol-aware proxy — ADR:
…/ADR-55.md". PR #7153: "(2.12) [ADDED] Trusted proxies support".

**Server, v2.14.6** — `server/opts.go`: the top-level key `proxies` (line 1909) is parsed by
`parseProxies` (line 5720), whose one field is `trusted` (line 5737), a list parsed by
`parseProxiesTrusted` (line 5759) into `[]*ProxyConfig`; `authorization { proxy_required }` (line
2987) is the switch the docs do document. The per-entry fields of `ProxyConfig` were not read for
this row.

**Suggested fix:** a `reference/config/proxies.md` page with the `trusted` list and its entry fields,
linked from `proxy_required` and from the ADR-55 write-up.


## 61 · Leafnode `dial_timeout` has no page

**Impact: a leafnode remote over a high-latency link that never completes the TCP handshake in one
second reconnects forever, and the one setting that fixes it — shipped for exactly that case — cannot
be found in the documentation.**

**Docs.** `grep -rli dial_timeout raw/nats-docs/` (861 pages, fetched 2026-08-31) matches **no
file**. `reference/config/leafnodes/` holds `advertise, authorization, compression, host,
isolate_leafnode_interest, listen, min_version, no_advertise, port, reconnect, remotes, tls,
write_deadline, write_timeout`; `reference/config/leafnodes/remotes/` holds `account, compression,
credentials, deny_exports, deny_imports, disabled, first_info_timeout, hub, ignore_discovered_servers,
isolate_leafnode_interest, jetstream_cluster_migrate, nkey, no_randomize, proxy, request_isolation,
tls, url, ws_compression, ws_no_masking`. `ignore_discovered_servers` (v2.14.0, #8067) *is*
documented, so the generator has run since 2.14.0; `dial_timeout` (v2.14.5, 2026-08-12) is not.

**Release notes.** `raw/release-notes/v2.14.5.md`, *Added / Leafnodes*: "New `dial_timeout` option
can be specified in the `leafnode` config block or for specific remotes in the configuration,
allowing it to be increased above the default 1 second for high-latency links (#8427)". The same
line is in `v2.12.15.md`.

**Server, v2.14.6** (`raw/nats-server-src/feature-flags-dial-timeout-and-2.15-subjects.md` §1):
`server/opts.go` lines 232–238 (`LeafNodeOpts.DialTimeout`: "If not set (or <= 0),
DEFAULT_ROUTE_DIAL is used"), 275–280 (`RemoteLeafOpts.DialTimeout`: "If not set (or <= 0), the
server-wide LeafNodeOpts.DialTimeout is used, which itself defaults to DEFAULT_ROUTE_DIAL (1
second)"), 2872–2873 (`case "dial_timeout"` in the `leafnodes` block, a duration) and 3211–3212 (the
same inside a `remotes` entry); `server/const.go` line 156, `DEFAULT_ROUTE_DIAL = 1 * time.Second`;
`server/leafnode.go` lines 604–608 (the fallback) and 763–764 (the per-remote override).

**Suggested fix:** a `reference/config/leafnodes/dial_timeout.md` and a
`reference/config/leafnodes/remotes/dial_timeout.md`, each "Available since NATS Server 2.14.5",
type duration, default `1s`, with the sentence that the remote's value overrides the block's; and a
line on `learn/topologies/leaf-nodes.md` (or wherever high-latency remotes are discussed) naming it.


## 62 · The `feature_flags` reference page names no flag, and the one that can panic older peers is documented nowhere

**Impact: the 2.14 upgrade guide tells operators to set `feature_flags { js_ack_fc_v2: true }` to
test the ack-subject migration, and the only reference page for the block says its names are
"server-internal and change between releases"; the second flag the server ships, `js_raft_delete_range`,
carries a source comment that turning it on in a mixed-version cluster makes older peers panic, and
no documentation page names it, let alone warns.**

**Docs.** `raw/nats-docs/reference/config/feature_flags.md`, the whole page: "Available since NATS
Server `2.14` · Requires Restart · Toggles for features that are not yet on by default. Names are
server-internal and change between releases." Type `{ string: boolean }`, choices `true`, `false`.
`js_ack_fc_v2` appears in the docs only in `release-notes/upgrade-to-2.14.md` (lines 74–82).
`grep -rl js_raft_delete_range raw/nats-docs/` matches nothing.

**Release notes.** `raw/release-notes/v2.14.0.md`: "Feature flags in the server configuration
(#7866) — ADR: …/ADR-53.md" (no flag named), and under *Domain-aware ack and flow control subjects*:
"This is disabled by default and can be enabled with the `js_ack_fc_v2` feature flag, this will be
enabled by default in v2.15". `js_raft_delete_range` is named in no release body.

**Server, v2.14.6** (`raw/nats-server-src/feature-flags-dial-timeout-and-2.15-subjects.md` §2):
`server/feature_flags.go` lines 22–25 define exactly two names, `js_ack_fc_v2` and
`js_raft_delete_range`; lines 27–47 give each its default (`false`), its "Introduced: 2.14.0" and
"Enabled: TBD" lines, and for the second: "WARNING: Only enable once every peer in the cluster is on
a version that supports receiving `deleteRangeOp`. Older peers panic on apply of an unknown stream
entry operation." Lines 53–60: an unknown name is "Not supported" and reads as `false`.
`server/opts.go` lines 1842–1862 parse the block; a non-boolean value is the error
`error parsing feature flag "<name>": expected bool, got <type>`. At `v2.15.0-preview.1` the file
adds a third, `js_snapshot_sources` ("Introduced: 2.15.0"), and `js_ack_fc_v2` is still `false`.

**Suggested fix:** list the flags the release documents — name, what it toggles, the release it was
introduced in, the default, and the mixed-version warning for `js_raft_delete_range` — on
`reference/config/feature_flags.md`, and replace "Names are server-internal and change between
releases" with a pointer to that list; a `feature_flags` section in each upgrade guide from 2.14 on
saying which flags flipped.


## 63 · The consumer reset API is missing from the JetStream API reference

**Impact: an operator who reads in the 2.14 upgrade guide that "consumer delivery state can now be
reset back to the acknowledgement floor, or to an arbitrary sequence" and goes to the API reference
to find the subject and the request body finds nine consumer endpoints and no reset.**

**Docs.** `raw/nats-docs/reference/jetstream/api/consumer.md` lines 4–14 list CREATE, DELETE, INFO,
LIST, NAMES, MSG.NEXT, LEADER.STEPDOWN, PAUSE and UNPIN; `raw/nats-docs/reference/jetstream/api/consumer/`
holds those nine pages. `release-notes/upgrade-to-2.14.md` line 22 describes the API and links
ADR-60 without giving the subject. `grep -rl CONSUMER.RESET raw/nats-docs/` matches only the upgrade
guide (and only because the wiki's grep is case-insensitive on "Consumer reset").

**Release notes.** `raw/release-notes/v2.14.0.md`, *Added / JetStream*: "Consumer reset API (#7489)
— It is now possible to reset a consumer back to an earlier sequence number using the
`$JS.API.CONSUMER.RESET.stream.consumer` API without deleting and recreating it — ADR:
…/ADR-60.md#consumer-delivery-state-reset-api".

**Server, v2.14.6** (`raw/nats-server-src/feature-flags-dial-timeout-and-2.15-subjects.md` §3):
`server/jetstream_api.go` line 159, `JSApiConsumerResetT = "$JS.API.CONSUMER.RESET.%s.%s"`. The
request and reply shapes are on `wiki/reference/js-api-subjects.md` from ADR-60.

**Suggested fix:** a `reference/jetstream/api/consumer/reset.md` page (subject, the empty payload
and the `{"seq": <n>}` form, the delivery-policy constraints ADR-60 states, the reply), and a row in
the `consumer.md` index; the `PAUSE` and `UNPIN` rows show the generator already carries 2.11
additions, so this is a data gap, not a tooling one.


## 64 · Five config keys "available since 2.12" that the 2.11 line parses

**Impact: the generated `Available since` line dates a key to the minor it first shipped on the
main line, not to the patch releases that carried it; an operator on 2.11.11+ who wants
`write_timeout`, or on 2.11.12+ who wants a WebSocket ping interval, is told the key is not
available to them.**

**Docs.** `raw/nats-docs/reference/config/write_timeout.md`, `websocket/ping_interval.md`,
`cluster/write_deadline.md`, `gateway/write_deadline.md`, `leafnodes/write_deadline.md` (fetched
2026-08-31) — each: "Available since NATS Server `2.12`".

**Release notes.** `raw/release-notes/v2.11.11.md` line 25: "Added `write_timeout` option for
clients, routes, gateways and leafnodes which controls the behaviour on reaching the
`write_deadline`" (2025-11-13). `raw/release-notes/v2.11.12.md` line 26: "Added WebSocket-specific
ping interval configuration with `ping_internal` in the `websocket` block (#7614)" (2026-01-27). The
block-level `write_deadline` is announced only in `v2.12.1.md` (#7405) — no 2.11 body names it.

**Server** (`raw/nats-server-src/backported-keys-v2.11.17.md`): `server/opts.go` at **v2.11.17** —
`case "write_timeout"` at line 1303 (top level), 1950 (`parseCluster`), 2140 (`parseGateway`), 2638
(`parseLeafNodes`); `case "write_deadline"` inside the same three block parsers at lines 1948, 2138,
2636; `case "ping_interval"` in `parseWebsocket` at line 5211. At **v2.10.29** none of these
block-level cases exists (`"write_timeout"` occurs zero times). Found by diffing
`tools/check-defaults.py` reports at v2.10.29 and v2.11.17: the four `write_deadline` /
`ping_interval` rows go from *unresolved* to *agrees* between the two tags.

**Suggested fix:** "Available since NATS Server `2.11.11`" (`write_timeout`), "`2.11.12`"
(`websocket.ping_interval`), and for the three block-level `write_deadline` pages the 2.11 patch
that carried #7405 (the 2.12.1 twin, v2.11.10, is the likely one; its body does not say). More
generally, if the generator takes *since* from the main-line minor, say so on the page, or take it
from the oldest tag whose parser accepts the key.


## 65 · Three of the fifteen "HTTP monitoring endpoints" are not HTTP endpoints, and two that are go unmentioned ★

**Impact: an operator who reads the monitor reference builds a probe or a scrape against
`/statsz`, `/idz` or `/profilez` and gets a 404; the three names exist only as system-account
requests, which the page never says. `/stacksz` and `/debug/vars`, which the port does serve, are
documented nowhere.**

**Docs.** `raw/nats-docs/reference/system/monitor.md` (fetched 2026-08-31): "NATS Server exposes HTTP
monitoring endpoints … *Available Endpoints* … Statsz … IPQueuesz … Idz … Profilez … Raftz";
"Endpoints are then accessible at `http://localhost:8222/varz`". `monitor/statsz.md`, `idz.md`,
`profilez.md` each open "Request options for `<z>` monitoring endpoint".

**Server, v2.14.6** — `server/server.go` lines 3030–3044 declare the paths (`/`, `/varz`, `/connz`,
`/routez`, `/gatewayz`, `/leafz`, `/subsz`, `/stacksz`, `/accountz`, `/accstatz`, `/jsz`, `/healthz`,
`/ipqueuesz`, `/raftz`, `/debug/vars`) and lines 3134–3162 register exactly those plus the alias
`/subscriptionsz`; `server/events.go` lines 1268–1315 register `IDZ`, `STATSZ` and `PROFILEZ` (with
twelve others) as `$SYS.REQ.SERVER.PING.<Z>` / `$SYS.REQ.SERVER.<id>.<Z>` requests. Quoted in
`raw/nats-server-src/system-subjects-v2.14.6.md`.

**Observed, 2.14.6** (`raw/nats-server-src/system-subjects-observed-v2.14.6.md` §1–2):

```
/varz 200   /statsz 404   /idz 404   /profilez 404   /stacksz 200   /debug/vars 200   /subscriptionsz 200
$SYS.REQ.SERVER.PING.IDZ      → {"name":"n1","host":"127.0.0.1","id":"<n1 id>"}   (three replies)
$SYS.REQ.SERVER.PING.STATSZ   → {"server":{…},"statsz":{…}}
$SYS.REQ.SERVER.PING.PROFILEZ → {"server":{…},"data":{"profile":"H4sI…"}}
```

**Sweep.** All fifteen names checked against the mux: twelve are both, three are request-only, and
the tree omits the two HTTP-only paths.

**Suggested fix:** on `monitor.md`, split the list into "HTTP endpoints" (the twelve plus `/stacksz`
and `/debug/vars`) and "system-account requests" (`$SYS.REQ.SERVER.PING.<Z>` for all fifteen), and
say on the three pages that they answer over the system account only.

## 66 · The account-connections event's subject and trigger ★

**Impact: a subscription written from the reference — `$SYS.ACCOUNT.*.CONNECTIONS` — receives
nothing, silently; and an operator who reads "when account connection limits are reached" alerts on
an event that is in fact a 30-second heartbeat.**

**Docs.** `raw/nats-docs/reference/system/advisory.md`: "Account Connections — Published when account
connection limits are reached · Subject: `$SYS.ACCOUNT.{account}.CONNECTIONS` · Alerts when approaching
or exceeding limits". `advisory/account-connections.md`: "`$SYS.ACCOUNT.{account}.CONNECTIONS`" and,
in the schema description, "Regular advisory published with account states".

**Server, v2.14.6** — `server/events.go`:

```go
accConnsEventSubjNew      = "$SYS.ACCOUNT.%s.SERVER.CONNS"          // line 58
accConnsEventSubjOld      = "$SYS.SERVER.ACCOUNT.%s.CONNS" // kept for backward compatibility  // line 59
var eventsHBInterval = 30 * time.Second                              // line 100
```

`AccountNumConns` is documented in the source as sent "when the number of connections changes. It
will also HB updates in the absence of any changes" (lines 207–209); the timer is armed at line
2466; both subjects are sent at line 2545; the `$G` account is skipped at line 2543.

**Observed, 2.14.6** (§3 of the observed file): with one `APP` client connected and nothing
happening, `$SYS.ACCOUNT.APP.SERVER.CONNS` and `$SYS.SERVER.ACCOUNT.APP.CONNS` arrived at
01:47:31, 01:48:01, 01:48:31, 01:49:01; `CONNECTIONS` never appeared in two minutes of `$SYS.>`.
No limit was configured, let alone reached.

**Suggested fix:** the subject `$SYS.ACCOUNT.{account}.SERVER.CONNS` (with the compatibility form
noted); the trigger "on every connection change and every 30 seconds while the account has
connections"; drop "when limits are reached". Add `name` and `num_subscriptions`, which the body
carries.

## 67 · Service latency is not published on `$SYS.SERVER.METRIC.SERVICE.LATENCY`

**Impact: a system-account subscriber waiting on `$SYS.SERVER.METRIC.>` never sees a latency
sample; the samples go to the subject the exporting account configured, in that account.**

**Docs.** `raw/nats-docs/reference/system/metric.md`: "Metrics are published to specific subjects that
follow the pattern: `$SYS.SERVER.METRIC.>` — All server metrics; `$SYS.SERVER.METRIC.SERVICE.LATENCY`
— Service latency metrics". `metric/service-latency.md`: "Subscription Subject
`$SYS.SERVER.METRIC.SERVICE.LATENCY`"; field `error` — "A description of the status code when not
200".

**Server, v2.14.6** — `server/accounts.go` lines 1491–1500:

```go
func (a *Account) sendLatencyResult(si *serviceImport, sl *ServiceLatency) {
	…
	lsubj := si.latency.subject
	…
	a.srv.sendInternalAccountMsg(a, lsubj, sl)
}
```

and line 1432: `Error string \`json:"description,omitempty"\``. `grep -n 'SERVER.METRIC'
server/events.go server/accounts.go` at the tag: no match.

**Observed, 2.14.6** (§5): an export `latency { sampling: 100%, subject: "svc.latency" }` in account
`SVC`; the sample arrived on `svc.latency` in `SVC` (`"status":200,"service":15000,"system":1792,
"total":666084`); the `$SYS.>` subscriber saw nothing.

**Suggested fix:** "published on the subject named by the export's `latency.subject`, in the
exporting account" — and `description` for the error field. The `learn/` chapter on service
latency, if one exists, should be the page the reference links to.

## 68 · `max_connections` described as a duration in nanoseconds

**Docs.** `raw/nats-docs/reference/system/monitor/varz.md`: "max_connections integer — The maximum
amount of connections the server can accept — nanoseconds depicting a duration in time, signed 64
bit integer". **Server**: `server/monitor.go:1235`, `MaxConn int \`json:"max_connections"\``, "MaxConn is
the maximum amount of connections the server can accept". A generator misplacement (the annotation
belongs to `write_deadline`, which carries it too). **Suggested fix:** drop the annotation.

## 69 · `STREAM.NAMES` documents its array as `consumers`

**Docs.** `raw/nats-docs/reference/jetstream/api/stream/names.md`, response: "consumers string[]".
**Server**: `server/jetstream_api.go:464–468`:

```go
type JSApiStreamNamesResponse struct {
	ApiResponse
	ApiPaged
	Streams []string `json:"streams"`
}
```

**Observed, 2.14.6**: `nats req '$JS.API.STREAM.NAMES' '{}'` →
`{"type":"io.nats.jetstream.api.v1.stream_names_response","total":0,"offset":0,"limit":1024,"streams":null}`.
**Suggested fix:** `streams string[]`. (`consumer/names.md`'s `consumers` is right.)

## 70 · Four advisory bodies that contradict the server ★

**Impact: a consumer of `nak` / `terminated` advisories that types `consumer_seq` as a string fails to
parse the wire; a consumer of `snapshot_create` waiting for `blocks` never sees it; a filter on
`stream_action.template` matches nothing; a batch abandoned for an unsupported requirement carries a
`reason` the docs say cannot occur.**

**Docs versus `server/jetstream_events.go` at v2.14.6** (quoted whole in
`raw/nats-server-src/system-subjects-v2.14.6.md`):

| page | docs | server |
|---|---|---|
| `advisory/nak.md` | `consumer_seq` string | `JSConsumerDeliveryNakAdvisory.ConsumerSeq uint64 \`json:"consumer_seq"\`` |
| `advisory/terminated.md` | `consumer_seq` string | `JSConsumerDeliveryTerminatedAdvisory.ConsumerSeq uint64` |
| `advisory/snapshot-create.md` | `blocks` ("Approximate number of blocks in the snapshot"), `block_size` | `JSSnapshotCreateAdvisory{Stream, State StreamState \`json:"state"\`, Client, Domain}` — no `blocks`, no `block_size` |
| `advisory/stream-action.md` | `template` ("The Stream Template that manages the Stream") | `JSStreamActionAdvisory{Stream, Action, Domain}` — no `template` |
| `advisory/stream-batch-abandoned.md` | `reason` ∈ `timeout`, `large`, `incomplete` | `BatchAbandonReason` also `"unsupported"` (`BatchRequirementsNotMet`) |

**Sweep.** All 24 pages of `reference/jetstream/advisory/` and `metric/` were checked against the
file: these four (plus #71's omissions); the subjects were not re-checked (#1–#3).

**Suggested fix:** regenerate the four schemas from the server structs; the `template` field belongs
to stream templates, which no longer exist.

## 71 · The advisory pages omit `domain` and `account`, and carry copied descriptions

**Docs versus `server/jetstream_events.go` at v2.14.6.** Every advisory struct carries
`Domain string \`json:"domain,omitempty"\``; twelve pages omit it (`api-audit`, `consumer-action`,
`max-deliver`, `consumer-leader-elected`, `consumer-quorum-lost`, `stream-leader-elected`,
`stream-quorum-lost`, `restore-create`, `restore-complete`, `snapshot-complete`,
`server-out-of-space`, `metric/consumer-ack`), and the four leader/quorum pages also omit
`Account string \`json:"account,omitempty"\``. `consumer-pause.md` describes `consumer` as "The name of
the Consumer that elected a new leader"; `consumer-group-pinned.md` describes `group` as "The group
that unpinned a client"; `api-limit-reached.md` and `nak.md` give the string `domain` "Minimum: 1".
Not wrong values — a reader is not misled into a broken subscription — so `enhancement`.

**Suggested fix:** regenerate from the structs (which fixes #70 as well); fix the two descriptions.

## 72 · No stream-level metric switch exists

**Docs.** `raw/nats-docs/reference/jetstream/metric.md`: "Metrics can be enabled or disabled at the
stream or consumer level. Some metrics may impact performance when enabled". **Server**: the one
JetStream metric, `$JS.EVENT.METRIC.CONSUMER.ACK`, is emitted according to the consumer's
`SampleFrequency` (`server/consumer.go:103`, `json:"sample_freq"`); `StreamConfig` (`stream.go`) has no
metric field. **Suggested fix:** "enabled per consumer with `sample_freq`".


## 73 · The pull request's `batch` has no "Maximum: 256"

**Docs.** `raw/nats-docs/reference/jetstream/api/consumer/get-next.md`: "batch integer — How many
messages the server should deliver to the requestor — Minimum: `0` Maximum: `256`".

**Server, v2.14.6** — `JSApiConsumerGetNextRequest` (`jetstream_api.go:764–770`) carries `Batch int`
with no bound; the only checks on a pull are the consumer's own `max_batch`
(`consumer.go:834–835`: `NewJSConsumerMaxRequestBatchExceededError(srvLim.MaxRequestBatch)` at
creation against the server limit, and `Exceeded MaxRequestBatch` at pull time).

**Observed, 2.14.6** (`raw/nats-server-src/config-mutability-observed-v2.14.6.md` §6): a consumer with
no `max_batch` on a stream holding three messages, `{"batch":300,"no_wait":true}` → `m1`, `m2`, `m3`,
then `404 No Messages`; `{"batch":100000,"no_wait":true}` → `404 No Messages`. With `max_batch: 5`:
`Status 409, Description: Exceeded MaxRequestBatch of 5`.

**Suggested fix:** drop the maximum, or say "bounded by the consumer's `max_batch` and the server's
`jetstream.limits.max_request_batch`". The 256 may be a client library's default, not the server's.

## 74 · `opt_start_time` described with the wrong deliver policy

**Schema.** `raw/jsm-go/consumer_configuration-v0.4.1.json`, `opt_start_time`: "Start time used with
the DeliverByStartSequence deliver policy". **Server**: `DeliverByStartTime` (`consumer.go:306`) and
the validation `badStart("by start time", "start sequence")` / `notSet("by start time", "start time")`
(`consumer.go:942–945`). `destination` is jsm.go because the docs collapse the consumer schema (#4)
and never show the line.

**Suggested fix:** "Start time used with the DeliverByStartTime deliver policy".

## 75 · `restore.md`'s request is labelled a response

**Docs.** `raw/nats-docs/reference/jetstream/api/stream/restore.md`, under `## Request`: "A response
from the JetStream $JS.API.STREAM.RESTORE API". Cosmetic; the fields (`config`, `state`) are right.


## Internal — where this wiki records each of these

*Not part of the report.* This table maps each finding to the page in this wiki that carries it, so a
reader here can get from a finding to the prose that uses it. A recipient of the report can ignore it.

## 76 · The docs promise a reference list of metric names that does not exist, and never name the `gnatsd_` prefix

**Docs.** `raw/nats-docs/learn/monitoring/prometheus-and-dashboards.md` line 149: "The full set of
metric names, check flags, and surveyor options is documented in [Reference](/reference/.md)." Lines
23–32: "`-prefix nats` renames the metrics from the exporter's default `jetstream_` prefix to `nats_`"
and "By default the exporter prefixes JetStream metrics with `jetstream_`; the `-prefix nats` flag
renames them to the `nats_` prefix used here".

**The reference tree.** `grep -rlE 'gnatsd_|jetstream_consumer|nats_consumer_num_pending|nats_core_'
raw/nats-docs/` matches one file — the learn page itself. `reference/jetstream/metric/` and
`reference/system/metric/` are the advisory-type schemas (the ack metric event and service latency),
not series names.

**Exporter, v0.20.2** — `collector/collector.go:34–35`: `CoreSystem = "gnatsd"`,
`JetStreamSystem = "jetstream"`; `:456–461` (`getSystem`): `-prefix` replaces whichever namespace a
collector uses. The exporter's own README (line 154–162) shows `gnatsd_varz_in_bytes`.

**Observed, 2026-09-03** (`raw/prometheus-nats-exporter-src/metrics-observed-v0.20.2.md`, runs A and
B): with every collector on and no `-prefix`, 139 `gnatsd_*` and 28 `jetstream_*` series; with
`-prefix nats`, the same 167 names under `nats_`.

**Suggested fix:** either add the reference page the link promises (the exporter's series by
collector, as `wiki/reference/metrics.md` does) or drop the sentence; and state that the default
prefix is `gnatsd_` for every collector except `/jsz`, and that `-prefix nats` renames both.

## 77 · `nats-surveyor --prefix` is documented as renaming the metrics; it does nothing

**Docs.** `raw/github-repos/nats-io__nats-surveyor.README.md` line 49 (the usage block, identical to
`nats-surveyor --help` at v0.9.11): `--prefix string  Replace the default prefix for all the metrics.
(NATS_SURVEYOR_PREFIX)`.

**Source, v0.9.11** (the Go module cache, quoted in the appendix of
`raw/nats-surveyor-src/metrics-observed-v0.9.11.md`): `cmd/root.go:238` defines the flag with that
help and `:333` stores it in `opts.Prefix`; `surveyor/surveyor.go:82` declares the field as
`Prefix string // TODO`; no other line reads it. Every descriptor is built with
`prometheus.BuildFQName("nats", …)` — `surveyor/collector_statz.go:391` for the `nats_core_*` family,
`:574–652` for `nats_stream_*` / `nats_consumer_*`.

**Observed, 2026-09-03** (run S3): `nats-surveyor … --prefix x --jsz all` → 102 `nats_*` series, 0
`x_*`.

**Suggested fix:** implement the flag (thread `opts.Prefix` into `BuildFQName`) or remove it from the
README, the help and the `NATS_SURVEYOR_PREFIX` environment variable. `destination` is the surveyor
repository because the text and the code live there.

## 78 · `nats_consumer_num_pending` is 0 on every replica but the leader, and the page does not say so

**Docs.** `raw/nats-docs/learn/monitoring/prometheus-and-dashboards.md` lines 32–43: "The lag field
`num_pending` becomes `nats_consumer_num_pending` … `nats_consumer_num_pending{account="ORDERS",stream_name="ORDERS",consumer_name="shipping"} 20`",
presented as *the* series for a consumer's lag, with three labels.

**Server, v2.14.6** — `consumer.go:5628–5632` (`streamNumPending`): `if o.mset == nil || o.mset.store
== nil || !o.isLeader() { o.npc, o.npf = 0, 0; return 0, nil }`; `:3558–3565`: a follower's
`num_ack_pending` and `num_redelivered` come from the replicated store state. `num_pending` is
therefore leader-only on `CONSUMER.INFO`, `/jsz` and `STATSZ` alike.

**Observed, 2026-09-03** (`metrics-observed-v0.20.2.md` runs H1-n1 / H1-n2;
`metrics-observed-v0.9.11.md` run S1): `nats consumer info` *Unprocessed Messages: 20*; the leader's
exporter `jetstream_consumer_num_pending … 20`, both followers' `0`; surveyor 20 / 0 / 0. The series
carries seventeen labels, including `is_consumer_leader="true|false"`.

**Public report.** `nats-io/prometheus-nats-exporter` issue #218 (2023-04-11, open, no maintainer
reply; `raw/gh-issues/exporter-issue-218.md`): "`nats_consumer_num_pending` … 3 / 0 / 3" across three
pods, resolved by the reporter with `is_consumer_leader="true"`.

**Suggested fix:** one sentence after the sample — the value is computed on the consumer's leader and
is 0 on the replicas; alert on `nats_consumer_num_pending{is_consumer_leader="true"}` (exporter) or run
surveyor with `--jsz-leaders-only` — and a sample that shows the label.

## 81 · The subject length and token limit the docs state does not exist in the server

`concepts/subjects.md:1101`: "**Keep it reasonable**: Limit to ~16 tokens and under 256 characters total."
No source is given, and the learn page on the same subject (`learn/core-nats/subjects-and-wildcards.md:8–36`)
states no limit at all.

**The server** at v2.14.6: `isValidSubject` (`sublist.go:1209–1246`, `raw/nats-server-src/core-delivery-v2.14.6.md`)
rejects an empty subject, an empty token, a token containing ` \t\n\f\r`, and a `>` that is not the last token
— and nothing about length or token count. The bounds that exist: `MAX_CONTROL_LINE_SIZE = 4096`
(`const.go:90`) on the whole `PUB`/`SUB` line, and the **optional** `max_subscription_tokens`
(`opts.go:1370–1381`, `client.go:3090–3096`), unset by default and applied to subscriptions only. The
"256" is most likely `JSMaxNameLen = 255` (`jetstream_api.go`), which bounds **stream and consumer names**,
not subjects. **Run**: a four-token subscription and publish on a bare server pass; with
`max_subscription_tokens: 3` the subscription is refused and the publish still delivered
(`raw/nats-server-src/core-delivery-observed-v2.14.6.md`, run C5).

**Why it matters**: the number has already confused a reader — gh#5097 (2024-02-16) asks whether "16"
means characters or tokens and is told it is "probably not strictly enforced" — and it hides the real
bound, `max_control_line`, which *is* enforced and *is* configurable.

**Suggested fix**: replace the sentence with the enforced rules (no empty token, no whitespace, `>` last),
name `max_control_line` as the bound on the line and `max_subscription_tokens` as the optional token
ceiling on subscriptions, and keep "few tokens" as performance guidance without a number.

## 82 · The `max_subscription_tokens` reference page is empty

`reference/config/max_subscription_tokens.md` in full: the alias `max_sub_tokens`, "Requires Restart",
and a *Types* table with `integer`, description "-". No description, no default, no range, no behaviour.

**The server** (`opts.go:1370–1381`): the value is a `uint8`; `n > 255` → "`max_subscription_tokens value
is too big`"; `n <= 0` → "`max_subscription_tokens value can not be negative`" (so `0` cannot mean
unlimited — leaving the key unset does); the check runs on `SUB` only (`client.go:3090–3096`) and sends
`-ERR 'Permissions Violation for Subscription to "<subj>", too many tokens'` with the log line
`Subscription Violation Too Many Tokens - Subject "<subj>", SID <n>` (`:5814–5819`). "Requires Restart"
is correct: `reload.go` has no case for the field and a changed value fails the reload with
`config reload not supported for MaxSubTokens: old=3, new=4`. **Run**: `raw/nats-server-src/core-delivery-observed-v2.14.6.md`
runs C5–C7 (the error, the log line, the publish that is still delivered, the refused reload, the two refused values).

**Sweep**: the sibling pages `max_control_line`, `max_payload`, `max_pending`, `max_connections`,
`max_subscriptions`, `max_traced_msg_len` were checked for their reload label against `reload.go` at
v2.14.6 (`maxcontrolline`, `maxpayload`, `maxconn`, `maxtracedmsglen` reloadable; `max_pending` and
`max_subscriptions` "Requires Restart" with no reload case) — **7 pages checked, all consistent; this is
the only one with no content**.

**Suggested fix**: a description ("the maximum number of tokens a subscription's subject may have; unset
means unlimited"), the range `1`–`255`, that it applies to subscriptions only, and the error the client
sees.

## 83 · `_INBOX` is not a `$` prefix

`concepts/subjects.md:1080–1087`: "Subjects starting with `$` are reserved for system use", followed by a
list that ends with `_INBOX`. The learn page (`learn/core-nats/subjects-and-wildcards.md:418–422`) gives
the same six names in two sentences: the five `$` prefixes "belong to the server and its subsystems",
and "The `_INBOX` prefix is reserved for reply subjects that clients generate automatically."

Neither page says who enforces the reservation. **The server** enforces none of them for a plain client
(`$SRV` does not occur in `server/*.go`; a client may publish under `$SYS`, `$JS`, `$KV` or `$O` inside its
account and reaches whatever is subscribed there); the one `$` prefix it does refuse is `$NRG.` from a
client outside the system account (`client.go:4373–4378`, `raw/nats-server-src/core-delivery-v2.14.6.md`).

**Suggested fix**: split the list as the learn page does, and add one sentence that the prefixes are
conventions the server does not check — permissions do.

## 84 · The mapping loss trick works for a wildcard source too

`learn/core-nats/subject-mapping.md:646`: "If you want the leftover share dropped rather than kept — to
test how a subscriber copes with loss — list the source subject itself as a destination, which tells the
server your weights are final and stops it topping them up. **This works because the source here is a
literal subject.**" And `:772`: "This only works for a literal source like `orders.created`."

**The server** (`accounts.go:839–862`, `raw/nats-server-src/core-delivery-v2.14.6.md`): the auto-added
remainder is skipped when `seen[src]` holds — the source string was listed among the destinations —
"Iff the src was not already added in explicitly, meaning they want loss". `seen` is keyed by the
destination string, so a wildcard source that names itself is found exactly like a literal one, and the
transform `src → src` is built with `transformTokenize` for the wildcard case (`:849–852`).

**Run** (`raw/nats-server-src/core-delivery-observed-v2.14.6.md`, F5 and F8, v2.14.6): the literal
`orders.created` listed at weight 90 delivered 188 of 200 publishes; the **wildcard**
`"orders.loss.>": [ { destination: "orders.loss.>", weight: 50 } ]` passed `nats-server -t` and delivered
98 of 200 to `orders.loss.a`. The server's own example configuration carries this very shape —
"A chaos testing trick that introduces 50% artificial message loss of messages published to foo.loss:
`foo.loss.>: [ { destination: foo.loss.>, weight: 50% } ]`" — as quoted in a user's config in gh#5172
(`raw/gh-discussions/gh-5172.md`).

`reference/config/mappings/weight.md` says weights must sum to 100 per cluster "unless artifical message
loss is desired for testing" and never says how the loss is configured.

**Suggested fix**: drop the two "literal only" sentences, and state the rule as the code has it: the
remainder stays on the source unless the source — literal or wildcard — is listed as a destination, in
which case it is dropped. The `weight` reference page could carry the one-line example.

### Where the wiki records each of these

| # | wiki page |
|---|---|
| 1–3 | `wiki/reference/advisories.md` — *A docs error worth knowing* |
| 4 | `wiki/summaries/s-docs-consumer-config.md`, `wiki/reference/defaults-and-limits.md`; the unit: `wiki/gotchas/consumer-keeps-redelivering.md` — cause 1, `wiki/summaries/s-so-78603662-acked-but-redelivered.md` |
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
| 43 | `wiki/reference/js-api-subjects.md` — *Account*, *Meta* and *A docs error worth knowing*; `wiki/internals/meta-layer.md`; `wiki/summaries/s-nats-server-jetstream-cluster.md` |
| 44 | `wiki/gotchas/streams-deleted-when-clustering-a-standalone-server.md` — *Confirmed on 2.14.6*; `wiki/internals/meta-layer.md` — *Orphans*; `wiki/summaries/s-nats-server-jetstream-cluster.md` |
| 45 | `wiki/reference/js-api-subjects.md` — *Meta* and *Documented elsewhere, absent from the API index*; `wiki/summaries/s-nats-server-jetstream-cluster.md` |
| 46 | `wiki/concepts/jetstream-domain.md` — *Observer mode, and what `extension_hint` does*; `wiki/internals/meta-layer.md`; `wiki/summaries/s-nats-server-jetstream-cluster.md` |
| 47 | `wiki/reference/monitoring-endpoints.md` — *`/raftz` — scope it to an account*; `wiki/internals/raft-in-nats.md` — *`/raftz`, read and run*; `wiki/summaries/s-docs-monitor-raftz.md`; `wiki/summaries/s-nats-server-raftz.md` |
| 48 | `wiki/reference/monitoring-endpoints.md` — the endpoint table and *A docs error worth knowing* under `/raftz`; `wiki/summaries/s-nats-server-raftz.md` |
| 49 | `wiki/concepts/mirrors-and-sources.md` — *How a mirror catches up* and the note under *The internal consumers, on demand*; `wiki/summaries/s-nats-server-mirror.md` |
| 50 | `wiki/concepts/object-store.md` — *Mirroring a bucket*; `wiki/operations/cross-domain-sourcing.md` — step 5; `wiki/summaries/s-issue-5106-object-store-mirror-list.md` |
| 51 | `wiki/concepts/key-value.md` — *Reading a mirror: which name, which storage, which filter*; `wiki/entities/nats-go.md` — *What bites you*; `wiki/summaries/s-nats-go-kv-object-mirror.md` |
| 52 | `wiki/operations/jetstream-sizing.md` — *Subjects are a RAM term* and *What runs out first* (7); `wiki/internals/filestore-layout.md` — *Recovery at startup*; `wiki/gotchas/jetstream-recovery-is-slow.md`; `wiki/summaries/s-nats-server-filestore-recovery.md`, `s-nats-server-stream-scale-observed.md` |
| 53 | `wiki/operations/jetstream-sizing.md` — *Subjects are a RAM term*; `wiki/summaries/s-synadia-how-many-subjects.md` |
| 54 | `wiki/operations/reload-server-config.md` — *### system account request*; `wiki/operations/evict-a-sick-server.md`; `wiki/reference/monitoring-endpoints.md` — *What arrived in 2.10*; `wiki/summaries/s-relnotes-2.10.md` |
| 55 | `wiki/concepts/tls-in-nats.md` — *Version notes: which key arrived when*; `wiki/concepts/leafnode.md`; `wiki/summaries/s-relnotes-2.11.md` |
| 56 | `wiki/concepts/replicas.md` — *Version notes*; `wiki/reference/monitoring-endpoints.md` — *What arrived in 2.11*; `wiki/summaries/s-relnotes-2.11.md` |
| 57 | `wiki/reference/monitoring-endpoints.md` — *What arrived in 2.11*; `wiki/concepts/tls-in-nats.md`; `wiki/summaries/s-relnotes-2.11.md` |
| 58 | `wiki/entities/nats-server-2.12.md`; `wiki/summaries/s-relnotes-2.12.md` — *The docs' upgrade guide against the bodies* |
| 59 | `wiki/operations/jetstream-sizing.md` — *Version notes: the 2.12 line*; `wiki/internals/filestore-layout.md`; `wiki/summaries/s-relnotes-2.12.md` |
| 60 | `wiki/operations/run-nats-behind-a-proxy.md` — *Version notes: the 2.12 line*; `wiki/summaries/s-relnotes-2.12.md` |
| 61 | `wiki/concepts/leafnode.md` — *The 2.14 line*; `wiki/reference/config-keys.md` — *Keys that arrived during 2.14*; `wiki/reference/defaults-and-limits.md` — *Defaults that moved during 2.14*; `wiki/summaries/s-relnotes-2.14.md` |
| 62 | `wiki/reference/config-keys.md` — *Keys that arrived during 2.14*; `wiki/concepts/mirrors-and-sources.md` — *Version notes: the 2.14 line, and the preview*; `wiki/entities/nats-server-2.14.md` — *The docs' upgrade guide against the bodies*; `wiki/summaries/s-relnotes-2.14.md` |
| 63 | `wiki/reference/js-api-subjects.md` — *Documented elsewhere, absent from the API index* and *The 2.14 line, and the preview's subjects*; `wiki/concepts/consumer.md` — *The 2.14 line*; `wiki/summaries/s-relnotes-2.14.md` |
| 64 | `wiki/gotchas/slow-consumer-detected.md` — *The 2.11 line* and *The 2.12 line*; `wiki/entities/nats-server-2.11.md` — *The default diff*; `wiki/log.md` 2026-09-03 (phase D, step 8) |
| 65 | `wiki/reference/system-subjects.md` — *Server requests*; `wiki/reference/monitoring-endpoints.md` — *The endpoints the port serves*; `wiki/summaries/s-docs-system-monitor-reference.md`; `wiki/summaries/s-nats-server-system-subjects-observed.md` |
| 66 | `wiki/reference/system-subjects.md` — *Events the server publishes*; `wiki/reference/advisories.md` — *System events*; `wiki/summaries/s-docs-system-advisories-and-metrics.md` |
| 67 | `wiki/reference/system-subjects.md` — *Events the server publishes*; `wiki/summaries/s-docs-system-advisories-and-metrics.md` |
| 68 | `wiki/summaries/s-docs-system-monitor-reference.md` |
| 69 | `wiki/reference/js-api-subjects.md` — *What the operation pages add*; `wiki/summaries/s-docs-jetstream-api-index.md` |
| 70 | `wiki/reference/advisories.md` — *A docs error worth knowing*; `wiki/summaries/s-docs-jetstream-advisories-reference.md` |
| 71 | `wiki/summaries/s-docs-jetstream-advisories-reference.md` |
| 72 | `wiki/reference/advisories.md` — *A docs error worth knowing*; `wiki/summaries/s-docs-jetstream-advisories-reference.md` |
| 73 | `wiki/reference/stream-and-consumer-config.md` — *Consumer fields* (`max_batch`) and *What the docs do not render*; `wiki/summaries/s-nats-server-config-mutability-observed.md` |
| 74 | `wiki/reference/stream-and-consumer-config.md` — *Consumer fields* (`opt_start_time`); `wiki/summaries/s-jsm-go-config-schemas.md` |
| 75 | `wiki/summaries/s-docs-jetstream-api-index.md` |
| 76 | `wiki/reference/metrics.md` — *The naming rule, and the prefix nobody documents*, *What the docs say, and what they do not*; `wiki/entities/prometheus-nats-exporter.md` — *What an operator needs to know* |
| 77 | `wiki/reference/metrics.md` — *The naming rule…*; `wiki/entities/nats-surveyor.md` — *What bites you*; `wiki/summaries/s-nats-surveyor-metrics-observed.md` |
| 78 | `wiki/reference/metrics.md` — *Which node's exporter to read*; `wiki/concepts/consumer.md` — *The consumer's numbers as time series*; `wiki/entities/prometheus-nats-exporter.md` — *What bites you* |
| 79 | `wiki/reference/config-keys.md` — *`accounts { <name> { exports, imports } }`* (the six keys marked *unlisted*); `wiki/concepts/cross-account-sharing.md` — *Who may import*; `wiki/summaries/s-docs-config-accounts-exports-imports.md` |
| 80 | `wiki/concepts/cross-account-sharing.md` — *Who may import: the three export guards*; `wiki/concepts/operator-mode.md` — *Private exports and activation tokens*; `wiki/entities/nsc.md` — cheat sheet |
| 81 | `wiki/concepts/subjects-and-wildcards.md` — *No length limit, one line limit, one optional token limit*; `wiki/summaries/s-gh-5097-subject-token-limit.md` |
| 82 | `wiki/reference/config-keys.md` — *Three top-level keys the core-NATS pages need*; `wiki/concepts/subjects-and-wildcards.md`; `wiki/reference/defaults-and-limits.md` — *What the core-server rows do when crossed* |
| 83 | `wiki/concepts/subjects-and-wildcards.md` — *Reserved prefixes* |
| 85 | `wiki/concepts/request-reply.md` — *The 503, exactly*; `wiki/gotchas/nats-timeout.md`; `wiki/summaries/s-nats-server-request-reply-observed.md` (B1, G2, G3) |
| 86 | `wiki/concepts/queue-groups.md` — *The pick: random, not round-robin, not readiness-aware*; `wiki/operations/worker-pool.md` — *The core queue group, measured* |
| 87 | `wiki/concepts/queue-groups.md` — *At-most-once*; `wiki/summaries/s-docs-core-nats-queue-groups.md` |
| 88 | `wiki/concepts/queue-groups.md` — *In a cluster*, *Across a leafnode*, *Across a gateway*; `wiki/concepts/gateway.md` — *Inside one cluster there is no affinity at all* |
| 89 | `wiki/concepts/request-reply.md` — *The three outcomes*, the gather table; `wiki/entities/nats-cli.md` — *`nats request` and `nats reply`, as run on 0.4.0*; `wiki/summaries/s-nats-cli-request-reply-source.md` |
| 84 | `wiki/concepts/subject-transforms.md` — *Account-level `mappings`*; `wiki/summaries/s-nats-server-core-delivery-observed.md` (F5, F8); `wiki/summaries/s-gh-5172-mapping-in-config-or-stream.md` |
| 90 | `wiki/concepts/client-connection-lifecycle.md` — *The keepalive*; `wiki/operations/upgrade-a-cluster.md` — *Verify the drain*; `wiki/summaries/s-adr-40-nats-connection.md` — *What the ADR gets wrong*; `wiki/summaries/s-nats-server-client-lifecycle-observed.md` (D1, D3) |
| 91 | `wiki/reference/client-defaults.md` — *`nats` CLI 0.4.0*; `wiki/entities/nats-cli.md` — *What bites you — the connection the CLI opens is not the library's*; `wiki/summaries/s-nats-cli-reconnect.md` |
| 92 | `wiki/entities/nats-go.md` — *What bites you — the connection*; `wiki/reference/client-defaults.md` (the `AsyncErrorCB` row); `wiki/summaries/s-nats-go-connection.md` |
| 93 | `wiki/concepts/client-connection-lifecycle.md` — *Events, and the readiness signal*; `wiki/summaries/s-nats-go-connection.md` |
| 94 | `wiki/concepts/client-connection-lifecycle.md` — *Draining, and closing*; `wiki/entities/nats-go.md` — *What bites you — the connection* |
| 95 | `wiki/summaries/s-docs-resilient-clients-drain-and-shutdown.md` — *The drain timeout* |

## 79 · Six import/export keys the server accepts and the config reference never lists

**`reference/config/accounts/imports.md`** (fetched 2026-08-31) tables `stream`, `service`, `prefix` and
`to`, and nothing else; `imports/service.md` tables `account` and `subject` under the description
"Stream import source configuration. Exclusive of `stream`." — the stream entry's text with the type
swapped. **`reference/config/accounts/exports.md`** tables `stream`, `service`, `accounts` and
`response_type`.

**The server**, `server/opts.go` at v2.14.6 — `parseImportStreamOrService`:

```go
		case "share":                       // opts.go:4505
			share = mv.(bool)
			if curService != nil {
				curService.share = share
			}
		case "allow_trace":                 // opts.go:4510
```

and `parseExportStreamOrService`:

```go
		case "threshold", "response_threshold", "response_max_time", "response_time":   // opts.go:4228
		…
		case "accounts":                    // opts.go:4255
		case "latency":                     // opts.go:4265
		case "account_token_position":      // opts.go:4281
		case "allow_trace":                 // opts.go:4283
```

**Run** (2026-09-03, nats-server v2.14.6, `local/scratch/runs/share-import/server.conf`): with
`imports: [ { service: { account: SVC, subject: "svc.remote" }, to: "svc.local", share: true } ]` the
config loads, reloads with `--signal reload`, and the responder in `SVC` sees the requester's user in
`Nats-Request-Info` (`"acc":"APP","user":"app","name":"tenant-agent-1",…`); without `share` it sees
`{"acc":"APP","rtt":268000}` only. So `share` is not a dead key: it is the switch that decides whether a
service in one account can identify the *user* in another, which is what a multi-tenant design turns on.

**Sweep**: both sibling pages of the same generated kind were checked against the two parsers — 2 of 2
incomplete, 6 keys missing in total (2 on imports, 4 on exports). The keys the pages do list are
correct.

**Suggested fix**: add the six rows; `share` as "service imports only: put the requester's user, name,
client host, JWT and issuer key into the `Nats-Request-Info` header and the service-latency event
(default `false`: account and RTT only)"; `latency` with its `subject` / `sampling` sub-keys;
`response_threshold` with its aliases; `account_token_position`; `allow_trace` on both sides with the
rule from the jwt library — trace on a *stream* import and a *service* export only. Fix the
`imports/service.md` description.

## 80 · Activation tokens are documented nowhere in the tree

A private export is the one cross-account mechanism that lets the exporting account keep its JWT
unchanged as importers come and go: the export carries `token_req: true` (jwt v2.8.2 `exports.go:115`,
`nsc add export --private`), and each importer's import carries an activation JWT in `token`
(`imports.go:27`) that the exporting account — or one of its signing keys — issued for that importer's
public key with `nsc generate activation --target-account <key> --subject <subject>`. The server
checks it in `accounts.go:2863–2882` (`checkAuth`: account-token position first, then `tokenReq` →
`checkActivation`, then the `accounts` list) and `3046–3087` (`checkActivation`: the token's issuer must
be the exporting account or a signing key of it, the subject the importing account, the import subject
contained in the token's, not expired, not in the export's `revocations`).

**The docs**: `grep -rn -i 'activation' raw/nats-docs/` finds two sentences — `learn/security/operator-mode.md:14`
("A few `nsc` capabilities aren't in `nats auth` v0.4.0 yet — activation tokens and importing a single
account into an existing operator among them. For those, keep using `nsc` on the same store.") and
`learn/security/cross-account.md:260` ("`nats auth` has no activation tokens for private exports; its
substitute is `--token-position`…"). Neither says what a token is, who signs it, what it contains, how
it expires or how it is revoked. `grep -c -i nsc raw/nats-docs/_llms.txt` is **0**: the 861-page mirror
has no `nsc` page at all, so the tool the sentences defer to is documented nowhere in the tree either.

**Why it matters**: an architect choosing between the three export guards cannot find, on docs.nats.io,
that two of them (`accounts`, and any revocation) rewrite the exporter's JWT per tenant and one
(`token_req`) does not — the decision that bank row 167 asks about.

**Suggested fix**: a page under `learn/security/` — *Private exports and activation tokens* — with the
export flag, the token's fields (`sub` = importing account, `nats.subject`, `nats.kind`, `exp`,
`issuer_account` when a signing key signs), the `nsc` commands, `revocations`, and the comparison with
`accounts` and `account_token_position`. Until `nats auth` gains the command, the page has to name `nsc`.

## 85 · The 503 carries `Nats-Subject`, and no page says so

`learn/core-nats/request-reply.md:563`: "The signal rides the message header mechanism: the server
delivers a reply with the header line `NATS/1.0 503`. A client needs header support to receive it, which
every current client enables." `learn/core-nats/headers.md:314–316`: "the line reads `NATS/1.0 503`, and
the message carries no payload … a reply with the header line `NATS/1.0 503` and an empty body"; `:378`
repeats it. `grep -rn Nats-Subject raw/nats-docs/` finds five lines, all Direct Get's header
(`learn/jetstream/get-direct.md:625, 817`, `learn/jetstream/subject-mapping.md:618, 631`,
`reference/jetstream/api/headers.md:90`).

**The server**: `client.go:4508–4511` at v2.14.6 (`raw/nats-server-src/request-reply-v2.14.6.md`):

```go
hdrLen := 32 /* header without the subject */ + len(c.pa.subject)
proto := fmt.Sprintf("HMSG %s %s %d %d\r\nNATS/1.0 503\r\nNats-Subject: %s\r\n\r\n\r\n", c.pa.reply, sub.sid, hdrLen, hdrLen, c.pa.subject)
```

At v2.2.0 the same send was `HMSG %s %s 16 16\r\nNATS/1.0 503\r\n\r\n\r\n` (`client.go:3498`,
`raw/nats-server-src/headers-arrival-v2.2.0.md`); the header arrived with v2.12.0 — "No responders errors
from the server now include the original subject in the `Nats-Subject` header (#5250)"
(`raw/release-notes/v2.12.0.md:19`).

**Run** (2026-09-03, `raw/nats-server-src/request-reply-observed-v2.14.6.md` B1, G2, G3): `HMSG _INBOX.x 1
38 38` with the header block `NATS/1.0 503\r\nNats-Subject: nobody\r\n\r\n`; over a service import renamed
with `to: inv.stock` the header read `Nats-Subject: inv.stock` — the subject as the requester published
it.

**Why it matters**: a client that handles many in-flight requests on one inbox, or a gather helper, can
tell *which* request found no responders only from this header; and a 2.2.0–2.11 server does not send it,
which a client reading it must tolerate.

**Suggested fix**: on `request-reply.md:563` and `headers.md:316`, state the header and its version:
"since 2.12.0 the reply also carries `Nats-Subject: <the subject you published to>`, so a client can match
the signal to the request".

## 86 · The queue group is not readiness-aware

`learn/services/scaling.md:150`: "The split isn't a round-robin you control: the server delivers each
message to whichever queue-group member is ready." `:272`: "While one handler blocks … that instance
answers no other request. The queue group masks this for a while by sending requests to the busy
instance's peers instead, but if every instance blocks, the whole service stalls."

**The server** (`client.go:5514–5520` at v2.14.6, `raw/nats-server-src/request-reply-v2.14.6.md`):

```go
sindex := 0
lqs := len(qsubs)
if lqs > 1 {
	sindex = int(fastrand.Uint32() % uint32(lqs))
}
// Find a subscription that is able to deliver this message starting at a random index.
```

Nothing in the selection reads a member's pending buffer or knows whether a handler is running; a member
leaves the list only when its subscription or connection goes.

**Run** (2026-09-03, `request-reply-observed-v2.14.6.md` C1, C1', C3, nats CLI 0.4.0): two `nats reply`
members of group `inv`, one answering at once and one running `sleep 1` before every reply, under 20
concurrent requests: the slow member received **8 of 20**, then **12 of 20** on the repeat (`/subsz`:
`msgs 8`, `msgs 12`), and answered them one per second, so the batch took 8.6 s and 12.3 s; 20 sequential
requests split 8 / 12. The busy member kept receiving while busy.

**Why it matters**: an architect reading L272 sizes a service on the assumption that a stalled instance
sheds its load to its peers; it does not — its random share queues behind the stall until the requesters'
timeouts fire. The learn page's own queue-group chapter says it right ("Selection is random per
message", `learn/core-nats/queue-groups.md:218`; the primer adds "does not account for how busy a member
is", `concepts/queue-groups.md:24`).

**Suggested fix**: L150 → "the server picks a member at random per request"; L272 → "a blocked instance
keeps receiving its share of requests, which wait behind the block until the caller's timeout — keep
handlers fast, and size the requester's timeout for it".

## 87 · "Exactly once" on a page that says at-most-once

`concepts/queue-groups.md:1528`: "Use queue groups for operational work that needs to happen **exactly
once**, and regular subscribers for observational tasks." `:2131` on the same page: "**At-most-once
delivery**: Core queue groups never redeliver — a message sent to a worker that crashes mid-processing is
lost … Duplicates come only from publisher retries, so make processing idempotent if the publisher may
resend." The deep dive, `learn/core-nats/queue-groups.md:230`: "if the server picks a packer and it dies
*after* delivery, that message is gone — the server won't retry it with another member."

**Suggested fix**: L1528 → "work that should be handled by one member, not by every subscriber".

## 88 · "A cluster adds a locality preference" — it does not, inside one cluster

`learn/core-nats/queue-groups.md:218`: "On a single server the selection is uniform-random across the
available members; a cluster adds a locality preference, covered below." The section below (`:259–263`,
*A note on placement across regions*) is about "members in several clusters"; nothing on the page says
what happens between the servers of one cluster.

**The server**: a peer's members reach a server as one `RS+ <account> <subject> <queue> <weight>` entry
(`route.go:1498, 1573`) and the sublist expands it to its weight before the pick — "Shadow these
subscriptions … for n := 0; n < int(ns); n++" (`sublist.go:741–747`) — so a routed member is as likely as
a local one; the loop takes a route entry outright ("Pick this one and be done", `client.go:5570–5571`).

**Run** (2026-09-03, `request-reply-observed-v2.14.6.md` E1–E5 on `tools/lab/cluster.sh`): one member on
the publisher's node and one on a peer, 200 publishes: 92 / 108, then 116 / 84; one on the publisher's node
and **three** on a peer, 400 publishes: **90 / 97 / 106 / 107**, then 105 / 98 / 102 / 95; two local and one
remote: 100 / 104 / 96. Uniform per member, no preference for the local server. The preferences the server
does have: across a **leafnode** a leaf member is only a fallback (`client.go:5547–5552`; run H: 200 / 0 and
0 / 200) and across a **gateway** the served queue names are excluded (`gateway.go:2638–2654`).

**Suggested fix**: L218 → "… uniform-random across the available members, on one server and across a
cluster alike; across a leafnode the publisher's own side is preferred, and across a super-cluster the
publisher's cluster — covered below".

## 89 · `nats request`: a silent timeout with exit 0, and a gather that any empty reply ends

`nats request` at natscli v0.4.0 (`raw/nats-cli/request-reply-0.4.0.md`, `cli/req_command.go`):

```go
143:				if err == nats.ErrTimeout {
144:					// continue to publish additional messages.
145:					break
146:				}
147:				if err == nats.ErrNoResponders {
148:					log.Printf("No responders are available")
149:					return nil
150:				}
…
179:			if c.replyCount > 0 && len(m.Data) == 0 {
180:				break
181:			}
…
222:	if c.terminateOnEmpty {
223:		c.replyCount = math.MaxInt16
224:	}
```

**Run** (2026-09-03, `raw/nats-server-src/request-reply-observed-v2.14.6.md` B6–B8, D8'–D11, nats CLI
0.4.0 on nats-server 2.14.6): a timed-out request printed only `Sending request on "nobody"` and exited
**0** after 1.058 s; no responders printed `No responders are available` and exited **0**; a served
request exited **0**. With two quoting responders and one answering an empty body after 200 ms,
`--replies 5` ended at the empty reply exactly as `--wait-for-empty` did (`nil body`, 0.25 s), while
`--replies 2` took the first two and never saw it.

**The docs**: `learn/core-nats/request-reply.md:561` — "The CLI prints the line and exits cleanly" (no
responders); `scatter-gather.md:621` — "With `--wait-for-empty`, the command keeps collecting until a reply
arrives with an empty payload"; neither the `--help` text nor the pages say that a timeout is silent, that
its exit status is 0, or that a counted gather ends on an empty reply without the flag.

**Why it matters**: `nats request` in a health check or a deploy script cannot distinguish a timeout from
success by exit status, and a responder whose legitimate answer is empty cuts every `--replies N` short.

**Suggested fix** (natscli): print `Request timed out` on the timeout path and exit non-zero for a timeout
and for no responders (as `nats sub --wait` and `nats server check` do); document the empty-reply rule in
`--replies`' help text.

## 90 · ADR-40's stale-connection rule is one ping short

**The ADR** (`raw/adr/ADR-40.md`, *Client Connection*, status *Implemented*) says it three times:

```
178:1. Missing two consecutive PONGs from the Server (number of missing PONGs can be
179:   configured).
…
224:server, expecting PONG. If two consecutive PONGs are missed, connection is
225:marked as lost triggering reconnect attempt.
…
337:If two (configurable) consecutive `PONGs are missed, the client should treat the
338:connection as broken, and it should start reconnect attempts.
```

with `**default**: 2 minutes` for the interval (L220). Read literally that is **four minutes** to
detect a wedged link, and that is how this wiki read it until 2026-09-04.

**The client**, `nats.go` at v1.53.1:

```go
  5899	func (nc *Conn) processPingTimer() {
  5906		// Check for violation
  5907		nc.pout++
  5908		if nc.pout > nc.Opts.MaxPingsOut {
  5909			nc.mu.Unlock()
  5910			if shouldClose := nc.processOpErr(ErrStaleConnection, false); shouldClose {
```

with `DefaultMaxPingOut = 2` (`:61`). The counter is incremented *before* the comparison and the
test is strictly greater, so the timer fires three times before the connection is declared stale:
**interval × (MaxPingsOut + 1) = 6 minutes**.

**The sibling documentation agrees with the source, not with the ADR.**
`learn/resilient-clients/reconnection.md:325`: "The client declares the link stale once the
outstanding pings exceed `MaxPingsOut`, so with the defaults — a two-minute ping interval (one
minute in Rust) and two allowed outstanding pings — detection waits for the **third** unanswered
ping, up to about **six minutes** (three in Rust)."

**Run** (2026-09-04, `raw/nats-server-src/client-lifecycle-observed-v2.14.6.md`, D3): a standalone
`nats-server v2.14.6` on default settings, a `nats sub --trace` connected at 02:02:25, the server
`SIGSTOP`ped at 02:02:28. The client printed

```
02:08:25 >>> Disconnected due to: nats: stale connection, will attempt reconnect
```

— **exactly six minutes** after the connect. The server enforces the same shape in the other
direction (D1, with `ping_interval: "5s"` and `ping_max: 2`): `PING` at t=2.186 and t=7.187, then
`-ERR 'Stale Connection'` at **t=12.189**, where the third `PING` would have gone — and **nothing in
the server log** at default level.

**Suggested fix**: L178 → "Missing `max_pings_out` consecutive PONGs, so the connection is declared
lost on the *next* ping interval after that — with the defaults, the third"; L224 and L337 likewise,
and state the resulting window (2 m × 3 = 6 m) since that number is what an operator sizes a rolling
upgrade against.

## 91 · The CLI's reconnect backoff never reaches the first entry of its own table

**natscli v0.4.0** (`raw/nats-cli/reconnect-0.4.0.md`):

```go
   248		nats.CustomReconnectDelay(func(attempts int) time.Duration {
   249			d := iu.DefaultBackoff.Duration(attempts)
```

```go
    31	var DefaultBackoff = BackoffPolicy{
    32		Millis: []int{
    33			500, 750, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000,
…
    43	func (b BackoffPolicy) Duration(n int) time.Duration {
…
    48		return time.Duration(jitter(b.Millis[n])) * time.Millisecond
```

**The client**, `nats.go` at v1.53.1, increments the sweep counter before calling the callback:

```go
  3423			i = 0
  3424			var st time.Duration
  3425			if crd != nil {
  3426				wlf++
  3427				st = crd(wlf)
```

so the first call is `Duration(1)` = 750 ms and `Millis[0]` = 500 ms is unreachable.

**Run** (2026-09-04, D3 transcript): the six delays printed under `--trace` were
**640 ms, 800 ms, 2.15 s, 1.979 s, 3.424 s, 1.873 s**. `jitter()` returns `[0.5×, 1.5×)` of the
step, so 2.15 s excludes `Duration(2)` = 1000 ms (max 1500 ms) and fits `Duration(3)` = 1500 ms
(750–2250 ms); 3.424 s excludes `Duration(4)` = 2000 ms (max 3000 ms) and fits `Duration(5)` =
2500 ms. The calls are therefore 1, 2, 3, 4, 5, 6 — not 0-based.

The practical effect is one skipped step, not a defect an operator would notice; it is recorded
because the documentation states the 500 ms figure as the CLI's first wait
(`learn/resilient-clients/reconnection.md:47`) and this wiki quotes such numbers.

**Suggested fix** (natscli): call `iu.DefaultBackoff.Duration(attempts - 1)`, or document that the
callback is 1-based. The docs sentence then becomes true as written.

## 92 · nats.go does not discard slow-consumer reports when you set no callback

**The docs**, `learn/resilient-clients/slow-consumers.md:100`:

> "In Go a connection with no async error callback **discards these reports, and dropped messages
> become invisible**; Rust, JavaScript, and C# behave the same way unless you wire up their event
> callback, status iterator, or logger."

and `where-next.md:99`: "Always set the async-error callback and log the slow-consumer error loudly;
**a nil one drops every overflow message silently**."

**The client**, `nats.go` at v1.53.1, installs a handler when the caller sets none:

```go
  1978		// Set a default error handler that will print to stderr.
  1979		if nc.Opts.AsyncErrorCB == nil {
  1980			nc.Opts.AsyncErrorCB = defaultErrHandler
  1981		}
```

```go
  2006	func defaultErrHandler(nc *Conn, sub *Subscription, err error) {
…
  2024			errStr = fmt.Sprintf("%s on connection [%d] for subscription on %q\n", err.Error(), cid, subject)
  2025		} else {
  2026			errStr = fmt.Sprintf("%s on connection [%d]\n", err.Error(), cid)
  2027		}
  2028		os.Stderr.WriteString(errStr)
```

So in Go the report is **written to stderr**, not discarded. The messages themselves are of course
still dropped — that part is right — but they are not invisible, and the advice's stated reason is
wrong. (The `AsyncErrorCB` field can only be nil if a caller assigns nil *after* `Connect`; the
option constructor path always ends at `defaultErrHandler`.)

Worth noting for anyone reproducing this: the client that really is silent here is the **`nats`
CLI**, which replaces the default handler with a trace-gated one — see #91's source file and
`wiki/entities/nats-cli.md`.

**Suggested fix**: "In Go, a connection with no async error callback still reports these — nats.go
installs a default handler that writes them to stderr — which is enough to see a drop but not to
alert on it; set your own. Rust, JavaScript and C# report nothing unless you wire up their event
callback, status iterator, or logger."

## 93 · "the same authentication error twice" — twice from *the same server*

Two pages of one chapter give the same rule different scopes.

**`learn/resilient-clients/connection-events.md:244`**:

> "in Go, for example, receiving the same authentication error twice aborts reconnecting regardless
> of the reconnect policy, unless you opt out with `IgnoreAuthErrorAbort`."

**`learn/resilient-clients/tls-and-auth.md:206`**:

> "nats.go closes the connection when **the same server** returns the same auth error twice in a
> row; the `IgnoreAuthErrorAbort()` option opts out."

**The client**, `nats.go` at v1.53.1, `processAuthError`:

```go
  4084		// We should give up if we tried twice on this server and got the
  4085		// same error. This behavior can be modified using IgnoreAuthErrorAbort.
  4086		if nc.current.lastErr == err && !nc.Opts.IgnoreAuthErrorAbort {
  4087			nc.ar = true
  4088		} else {
  4089			nc.current.lastErr = err
  4090		}
```

`nc.current` is the server being dialled, so the state is per server and is reset by dialling a
different one. With a three-server pool, three different servers each returning one auth error do
**not** abort; the same server returning it twice in a row does. The `tls-and-auth.md` sentence is
exact; the `connection-events.md` one is not, and an operator reading only the events page will
mis-predict when a credential problem ends in CLOSED.

**Suggested fix**: `connection-events.md:244` → "receiving the same authentication error twice in a
row **from the same server** aborts reconnecting …".

## 94 · A drain issued while the connection is down closes it, and no page says so

The chapter is careful about what `Close()` costs — "it stops delivering buffered inbound messages
to your handlers and **drops the reconnect buffer**" (`drain-and-shutdown.md:12`) — and it teaches
drain as the alternative. It never says that during an outage the two are the same call.

**The client**, `nats.go` at v1.53.1:

```go
  6307	func (nc *Conn) Drain() error {
…
  6310		if nc.isConnecting() || nc.isReconnecting() {
  6311			nc.mu.Unlock()
  6312			nc.Close()
  6313			return ErrConnectionReconnecting
  6314		}
```

and `drainConnection` guards it again (`:6211–6215`, with the comment "Move to closed state").

The operational shape is ordinary: a rolling deploy sends SIGTERM to a pod while its server is
already gone, the shutdown handler calls `Drain()`, and the buffered publishes the reconnect buffer
was holding are discarded rather than flushed on reconnect. The connection also never reaches
DRAINING_SUBS, so a shutdown that waits on the drain's own phases waits for something that will not
happen — it must wait on CLOSED, which the chapter does say.

**Suggested fix**: in *Drain finishes in-flight work, then closes*, add: "Drain only applies to a
connected client. If the connection is CONNECTING or RECONNECTING when you call it, the client
closes instead and returns a reconnecting error (`ErrConnectionReconnecting` in nats.go) — which
means the reconnect buffer is dropped, not flushed. A shutdown handler should therefore treat a
drain during an outage as a close."

## 95 · The CLI's `--timeout` is not a handshake or flush bound

`learn/resilient-clients/drain-and-shutdown.md` illustrates the drain timeout with the CLI's global
flag:

```
146:# --timeout bounds how long a single operation waits. The point this
…
152:# This publishes the canonical order event with a generous operation
153:# timeout so a slow handshake is not cut off mid-flush.
…
168:  --timeout 30s
```

`nats --help` at 0.4.0 describes the same flag as **"Time to wait on responses from NATS"**, default
**`5s`**. It bounds waiting for a reply — it is not a connect timeout, and a `nats pub` of a core
message waits for no response at all, so the flag does nothing in the example shown.

The page is honest two paragraphs earlier ("the CLI has no drain-timeout flag"), which is what makes
the comment avoidable: the example demonstrates a flag that has no effect on the thing being taught.

**Suggested fix**: keep the example but change the comment to say the CLI has no drain timeout and
that `--timeout` is shown only because it is the nearest thing the CLI has — or drop the flag from
the snippet and leave the C example to carry `natsConnection_DrainTimeout`.

