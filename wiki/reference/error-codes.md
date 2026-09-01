---
title: JetStream error codes
type: reference
area: [jetstream, core]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [error-codes, err_code, errors.json, 10005, 10052]
aliases: [error codes, err_code, JetStream errors, "10005", "10052"]
sources: [s-nats-server-jetstream-resources, s-adr-7-server-error-codes, s-adr-1-jetstream-json-api, s-nats-server-auth-and-tls, s-gh-5606-cross-account-jetstream, s-adr-59-sourcing-and-mirroring, s-adr-61-meta-quorum-rescue, s-adr-10-extended-purge, s-adr-43-per-message-ttl, s-docs-accounts-and-multitenancy, s-docs-cross-account, s-docs-disaster-recovery, s-docs-mirrors-and-sources, s-docs-scaling-and-peers, s-docs-single-server, s-docs-stream-backup-restore, s-gh-7982-no-suitable-peers, s-issue-4281-insufficient-storage, s-nats-server-snapshot-restore, s-docs-advanced-publishing, s-docs-subject-mapping, s-adr-51-message-scheduler, s-gh-7672-cron-schedules, s-nats-server-message-schedules-observed]
created: 2026-08-31
updated: 2026-09-01
---

# JetStream error codes

What a numeric `err_code` means, where the list comes from, and how to look one up. **The full
222-row table is not reproduced here** — it lives in the docs and in the server, and both are
linked below. This page gives the structure, the lookup, and the codes this wiki cites.

## The rule that matters

**`code` and `err_code` are the public API. `description` is not**
(source: [[s-adr-7-server-error-codes]]):

> the `description` field is "specifically out of scope for SemVer protection and changes to these
> will not be considered a breaking change".

**Any alert, dashboard, log filter or runbook that matches on error text will break on an upgrade.**
Match the number. See [[js-api]].

**One code this wiki cites does not exist yet**: `10224`,
`JetStream system rescue not applied: {err}`, HTTP 400 — the rejection from `$JS.API.META.RESCUE`,
which is **2.15 only** and absent from the v2.14.6 source (source:
[[s-adr-61-meta-quorum-rescue]], [[disaster-recovery]]).

## The number ranges

| range | subsystem |
|---|---|
| **1xxxx** | JetStream |
| **2xxxx** | MQTT |

ADR-7's status is **Partially Implemented**: "The current focus is JetStream APIs, we will as a
followup do a refactor and generalization and move onto other areas of the server." **Outside
JetStream and MQTT an error may carry no code at all.**

Two failures an operator meets often carry no number, so there is nothing to look up. A cross-account
config error stops the server at boot as plain text, with a file and line instead of a code:

```
nats-server: nats.conf:2:1: Error adding stream import "orders.shipped": stream import not authorized
```

and `No responders are available` is a core NATS status, not a JetStream error — an unmatched
*export* is not an error at all: the server starts, the config is valid, and no messages move
(source: [[s-docs-cross-account]]). See [[cross-account-sharing]].

## What the 2.14 table contains

`raw/nats-docs/reference/jetstream/errors.md` holds **222 codes** spanning **10002–10223**, grouped
into nine categories:

| category | codes |
|---|---:|
| Consumer errors | 83 |
| Stream errors | 51 |
| General errors | 23 |
| Mirror errors | 16 |
| Message errors | 16 |
| Clustering errors | 12 |
| Source errors | 10 |
| Atomic publish errors | 8 |
| Account errors | 3 |

By HTTP status: **400** ×167, **500** ×33, **503** ×12, **404** ×4, **429** ×3, **412** ×2,
**409** ×1.

Two structural notes from the table's own appendix:

- **A constant ending `F` carries placeholders** — `{err}`, `{limit}`, `{seq}` — substituted at
  runtime. So its `description` column shows the template, not a message you can match on. This is
  the same convention ADR-7 describes for the Go constants, where `{err}` is always an `error` and
  `{seq}` always a `uint64`.
- Some errors carry **help text** and a **URL** that the API response does not include — both are
  `json:"-"` on `ApiError`, so they exist only in the lookup table.

## The codes this wiki cites

| code | constant | HTTP | description | where |
|---|---|---|---|---|
| **10002** | `JSAccountResourcesExceededErr` | 400 | resource limits exceeded for account | [[jetstream-sizing]] |
| **10003** | `JSBadRequestErr` | 400 | bad request | [[js-api]] · [[maximum-messages-exceeded]] |
| **10005** | `JSClusterNoPeersErrF` | 400 | `{err}` | [[no-suitable-peers-for-placement]] |
| **10014** | `JSConsumerNotFoundErr` | 404 | consumer not found | [[js-api]] |
| **10023** | `JSInsufficientResourcesErr` | 503 | insufficient resources | [[jetstream-sizing]] · [[jetstream-out-of-disk]] |
| **10028** | `JSMemoryResourcesExceededErr` | 500 | insufficient memory resources available | [[jetstream-out-of-disk]] |
| **10047** | `JSStorageResourcesExceededErr` | 500 | insufficient storage resources available | [[jetstream-out-of-disk]] |
| **10021** | `JSStreamExternalApiOverlapErrF` | 400 | stream external api prefix `{prefix}` must not overlap with `{subject}` | [[cross-account-sharing]] |
| **10022** | `JSStreamExternalDelPrefixOverlapsErrF` | 400 | stream external delivery prefix `{prefix}` overlaps with stream subject `{subject}` | [[cross-account-sharing]] |
| **10024** | `JSStreamInvalidExternalDeliverySubjErrF` | 400 | stream external delivery prefix `{prefix}` must not contain wildcards | [[cross-account-sharing]] |
| **10029** | `JSMirrorConsumerSetupFailedErrF` | 500 | `{err}` — the mirror's replication consumer could not be created | [[mirrors-and-sources]] |
| **10035** | `JSNoAccountErr` | 503 | account not found | [[account]] |
| **10045** | `JSSourceConsumerSetupFailedErrF` | 500 | `{err}` — a source's replication consumer could not be created | [[mirrors-and-sources]] |
| **10039** | `JSNotEnabledForAccountErr` | 503 | JetStream not enabled for account | [[account]] |
| **10052** | `JSStreamInvalidConfigF` | 500 | `{err}` | [[message-ttl]] |
| **10059** | `JSStreamNotFoundErr` | 404 | stream not found | [[js-api]] |
| **10060** | `JSStreamNotMatchErr` | 400 | expected stream does not match | [[mirrors-and-sources]] |
| **10064** | `JSStreamSnapshotErrF` | 500 | snapshot failed: `{err}` | [[backup-and-restore-jetstream]] |
| **10065** | `JSStreamSubjectOverlapErr` | 400 | subjects overlap with an existing stream | [[disaster-recovery]] |
| **10071** | `JSStreamWrongLastSequenceErrF` | 400 | wrong last sequence: `{seq}` | [[stream]] |
| **10074** | `JSStreamReplicasNotSupportedErr` | 500 | replicas > 1 not supported in non-clustered mode | [[install-nats-server]] |
| **10075** | `JSPeerRemapErr` | 503 | peer remap failed | [[rebalance-streams]] |
| **10077** | `JSStreamStoreFailedF` | 503 | `{err}` — `maximum messages exceeded`, `maximum bytes exceeded`, `maximum messages per subject exceeded` | [[maximum-messages-exceeded]] |
| **10109** | `JSStreamSealedErr` | 400 | invalid operation on sealed stream | [[stream]] |
| **10110** | `JSStreamPurgeFailedF` | 500 | `{err}` — e.g. `stream purge not permitted` on a `deny_purge` stream | [[maximum-messages-exceeded]] |
| **10099** | `JSConsumerWQMultipleUnfilteredErr` | 400 | multiple non-filtered consumers not allowed on workqueue stream | [[retention-policies]] |
| **10100** | `JSConsumerWQConsumerNotUniqueErr` | 400 | filtered consumer not unique on workqueue stream | [[retention-policies]] |
| **10165** | `JSMessageTTLInvalidErr` | 400 | invalid per-message TTL | [[message-ttl]] |
| **10166** | `JSMessageTTLDisabledErr` | 400 | per-message TTL is disabled | [[message-ttl]] |
| **10130** | `JSStreamNameExistRestoreFailedErr` | 400 | stream name already in use, cannot restore | [[backup-and-restore-jetstream]] |
| **10176** | `JSAtomicPublishIncompleteBatchErr` | 400 | atomic publish batch is incomplete | [[publishing]] |
| **10179** | `JSAtomicPublishInvalidBatchIDErr` | 400 | atomic publish batch ID is invalid | [[publishing]] |
| **10199** | `JSAtomicPublishTooLargeBatchErrF` | 400 | atomic publish batch is too large: `{size}` | [[publishing]] |
| **10201** | `JSAtomicPublishContainsDuplicateMessageErr` | 400 | atomic publish batch contains duplicate message id | [[publishing]] |
| **10210** | `JSAtomicPublishTooManyInflight` | **429** | atomic publish too many inflight | [[publishing]] |
| **10205** | `JSBatchPublishDisabledErr` | 400 | batch publish is disabled | [[publishing]] |
| **10206** | `JSBatchPublishInvalidPatternErr` | 400 | batch publish pattern is invalid | [[publishing]] |
| **10207** | `JSBatchPublishInvalidBatchIDErr` | 400 | batch publish ID is invalid | [[publishing]] |
| **10208** | `JSBatchPublishUnknownBatchIDErr` | 400 | batch publish ID unknown | [[publishing]] |
| **10209** | `JSMirrorWithBatchPublishErr` | 400 | stream mirrors can not also use batch publishing | [[publishing]] · [[mirrors-and-sources]] |
| **10211** | `JSBatchPublishTooManyInflight` | **429** | batch publish too many inflight | [[publishing]] |
| **10202** | `JSClusterServerMemberChangeInflightErr` | 400 | cluster member change is in progress | [[rebalance-streams]] |

**`10047` and `10028` do not mean the disk or the RAM is full.** They compare **reservations** —
the sum of every stream's `max_bytes` — against the server or account limit, and never look at actual
usage (`jetstream.go:2523–2553`, source: [[s-nats-server-jetstream-resources]]). A server with 4 MB
stored and 35 GiB reserved returns `10047`. `10023` is the clustered sibling, returned when the meta
layer cannot find a peer that will accept the assignment. All three are read the same way: see
[[jetstream-out-of-disk]].

**`10064` is the one whose text you must read.** Its whole description is `{err}`, and for a **memory**
stream the substituted text is `no impl` — see [[backup-and-restore-jetstream]], which is also why
matching on the number alone tells you nothing here.

**`10021`, `10022` and `10024` are the only public sign that the `external` block exists.** They
validate `external.api` and `external.deliver` on a stream source or mirror — the fields that reach a
stream in another account or JetStream domain — and **no docs page documents those fields at all**
(`inbox/docs-issues.md` #21). See [[cross-account-sharing]].

**`10077` is the one an operator never sees in a log.** It is the publish-side refusal of a
`discard: new` stream at its limit, and it is delivered **only in the `PubAck`** — the server's own
record of it is a rate-limited *debug* line (`server/stream.go:7063`), so at the default log level
nothing appears. Its description is `{err}` again, and the three substituted strings
(`server/store.go:48-53`) are what tell you *which* limit was hit. See
[[maximum-messages-exceeded]].

### The batch-publish family, and the only two `429`s this wiki cites

The eleven codes above are two families, one per publish mode ([[publishing]]), and they are worth
reading as a pair because the names are nearly identical and the modes are not:

- **`JSAtomicPublish*`** — atomic batch publishing, `allow_atomic`, **since 2.12**. An
  `IncompleteBatch` is the sequence-gap rejection; `TooLargeBatch` carries the offending `{size}`.
- **`JSBatchPublish*`** — fast-ingest batch publishing, `allow_batched`, **since 2.14**.
  `Disabled` is what you get when the stream never set the flag.

**`10210` and `10211` are `429 Too Many Requests`** — the only two codes in this table that are, and
the in-flight-batch ceiling is the thing they report. The docs say a stream allows at most 50 batches
in flight by default; this wiki has not confirmed that number against the server
(see *To verify* on [[publishing]]).

**`10209 stream mirrors can not also use batch publishing`** is a configuration rejection, not a
runtime one: a stream cannot be both a mirror and a batch-publish target
([[mirrors-and-sources]]).

**`10052` also covers a republish cycle.** Its whole description is `{err}`, so the code alone never
tells you which config was rejected; a republish destination overlapping the stream's own subjects is
one of its cases ([[subject-transforms]], source: [[s-docs-subject-mapping]]).

**`10005` and `10052` are the two to know.** Both have `{err}` as their whole description, so the
number alone tells you almost nothing and the *text* is the only detail — the exact inversion of the
match-on-the-number rule. [[no-suitable-peers-for-placement]] and [[message-ttl]] enumerate the
distinct conditions hiding behind each.

### Message scheduling — ten codes, all observed at v2.14.6

Every code below was produced on the binary and read off the `PubAck`
(source: [[s-nats-server-message-schedules-observed]]); see [[message-scheduling]] for what each
condition means.

| code | constant | condition |
|---|---|---|
| `10186` | `JSMirrorWithMsgSchedulesErr` | `allow_msg_schedules` on a mirror |
| `10187` | `JSSourceWithMsgSchedulesErr` | `allow_msg_schedules` on a stream with sources |
| `10188` | `JSMessageSchedulesDisabledErr` | a schedule, or a cancel, on a stream with schedules off |
| `10189` | `JSMessageSchedulesPatternInvalidErr` | the pattern is bad — **four unrelated causes**, below |
| `10190` | `JSMessageSchedulesTargetInvalidErr` | no `Nats-Schedule-Target`, or one outside the stream |
| `10191` | `JSMessageSchedulesTTLInvalidErr` | a malformed `Nats-Schedule-TTL`, or one below the TTL floor |
| `10192` | `JSMessageSchedulesRollupInvalidErr` | `Nats-Schedule-Rollup` other than `sub` |
| `10203` | `JSMessageSchedulesSourceInvalidErr` | a wildcard `Nats-Schedule-Source` |
| `10212` | `JSMessageSchedulesSchedulerInvalidErr` | five `Nats-Scheduler` / `Nats-Schedule-Next` conditions |
| `10223` | `JSMessageSchedulesTimeZoneInvalidErr` | a fixed offset (`+02:00`) or an empty time-zone header |

**`10189` is the one to be careful with.** The same code and the same text —
`message schedules pattern is invalid` — comes back for at least four different mistakes:

1. a **five-field** cron (`*/5 * * * *`); the server wants six, seconds first;
2. `@every` below the `1s` minimum;
3. a `Nats-Schedule-Time-Zone` on a non-cron schedule — *not* the time-zone code;
4. a **2.14 expression sent to a 2.12 server**, where cron did not exist yet
   (source: [[s-gh-7672-cron-schedules]]) — and, by the same path, an IANA zone the host has no tzdata
   for (source: [[s-adr-51-message-scheduler]]).

**Two scheduling refusals do not get a scheduling code at all.** `message scheduling cannot use
discard new` and `message schedules can not be disabled` both arrive as **`10052`**
(`JSStreamInvalidConfigF`, HTTP 500), the generic invalid-stream-config wrapper — so the reason is
only in the text, and code-matching cannot distinguish them from any other bad stream config. This is
the page's own rule about never matching on error text meeting a case where the code is not enough.


## Reading a code

**In a server log**, `ApiError` appends the code in parentheses:

```
stream not found (10059)
```

**From the CLI:**

```
nats error 10059
```

```
NATS Error Code: 10059

        Description: stream not found
          HTTP Code: 404
  Go Index Constant: JSStreamNotFoundErr
```

`nats errors` lists, searches and edits the definitions; `nats errors --errors <file>` reads a local
`errors.json` during development.

**In an API response** the envelope is:

```json
{
  "type": "io.nats.jetstream.api.v1.consumer_info_response",
  "error": { "code": 404, "err_code": 10059, "description": "stream not found" }
}
```

## How this was derived

- The counts, categories, HTTP distribution and code range are computed from
  `raw/nats-docs/reference/jetstream/errors.md` — the 2.14 docs tree's generated error table, 222
  rows matching `| <5-digit code> | \`<constant>\` | <http> | <description> |`. To regenerate,
  re-parse that file.
- The structure, the SemVer rule, the `F`-suffix convention and the `nats error` tooling come from
  **ADR-7** (`raw/adr/ADR-7.md`).
- **The canonical list is `server/errors.json` in the `nats-server` repo**, from which the Go
  constants and this documentation table are both generated with `go generate`. The generator
  verifies that every `error_code` and `constant` is unique. That file — not this page and not the
  docs — is the authority.

## Why the full table is not copied here

222 rows of generated content would be a verbatim copy of a docs page that is itself generated from
the server, and it would go stale silently. The wiki's rule is to summarise and link
(`CLAUDE.md` → *Copyright*). Look a code up with `nats error <code>`, or read
`raw/nats-docs/reference/jetstream/errors.md` locally. The rows above are the ones this wiki has
reason to explain.

## Related

[[js-api]] · [[js-api-subjects]] · [[no-suitable-peers-for-placement]] · [[message-ttl]] ·
[[retention-policies]] · [[stream-placement]] · [[nats-cli]] · [[defaults-and-limits]] ·
[[install-nats-server]] · [[rebalance-streams]] · [[backup-and-restore-jetstream]] ·
[[disaster-recovery]] · [[cross-account-sharing]] · [[account]] · [[cross-domain-sourcing]] ·
[[jetstream-domain]] · [[maximum-messages-exceeded]]

## Sources

[[s-adr-7-server-error-codes]] · [[s-adr-1-jetstream-json-api]] · [[s-nats-server-auth-and-tls]] ·
[[s-gh-5606-cross-account-jetstream]] · [[s-nats-server-jetstream-resources]] ·
[[s-adr-10-extended-purge]] ·
[[s-adr-59-sourcing-and-mirroring]] · [[s-adr-61-meta-quorum-rescue]]

The rows in *The codes this wiki cites* are in the table because a page needed them; these are the
summaries that put them there — [[s-adr-43-per-message-ttl]] (`10052`, `10165`, `10166`) ·
[[s-docs-accounts-and-multitenancy]] (`10039`) · [[s-docs-cross-account]] (the failures with no code)
· [[s-docs-disaster-recovery]] (`10065`) · [[s-docs-mirrors-and-sources]] (`10060`) ·
[[s-docs-scaling-and-peers]] (`10075`, `10202`) · [[s-docs-single-server]] (`10074`) ·
[[s-docs-stream-backup-restore]] (`10064`) · [[s-gh-7982-no-suitable-peers]] (`10005`) ·
[[s-issue-4281-insufficient-storage]] (`10028`, `10047`) · [[s-nats-server-snapshot-restore]]
(`10060`, `10064`, `10130`) · [[s-docs-advanced-publishing]] (the eleven `JSAtomicPublish*` and
`JSBatchPublish*` codes) · [[s-docs-subject-mapping]] (`10052` as a republish cycle). · [[s-adr-51-message-scheduler]] · [[s-gh-7672-cron-schedules]] · [[s-nats-server-message-schedules-observed]]
