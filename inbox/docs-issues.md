# Docs issues found while building this wiki

Errors, gaps and inconsistencies found in **public NATS documentation** while ingesting it. This
file is **not a wiki page** — it is a report, kept so it can be sent to the docs maintainers or
turned into issues against `nats-io/nats-docs` and `nats-io/nats-architecture-and-design`.

**Every row is verified against a stated authority**, normally the `nats-server` source at a
release tag, and gives the exact evidence. Nothing here is a guess or a style opinion. Where the
docs are merely terse, the row is marked `enhancement` and kept separate from the ones that are
factually wrong.

- `★` marks a **confirmed factual error with real impact** — following the docs produces a broken
  result, silently.
- `where` is the doc path; for docs.nats.io prefix `https://docs.nats.io/`.
- `status` is this wiki's handling, not the upstream state.

Found while working `inbox/plan-first-ingests-2026-08-31.md`. Verified against **nats-server
v2.14.6** and the docs tree fetched **2026-08-31**.

| # | issue | where | kind | severity | status |
|---|---|---|---|---|---|
| 1 | Nak advisory subject is `MSG_NAK`; the server publishes `MSG_NAKED` | `reference/jetstream/advisory/nak.md` | wrong-value | ★ high | wiki uses the server value |
| 2 | Pinned advisory subject is `GROUP_PINNED`; the server publishes `PINNED` | `reference/jetstream/advisory/consumer-group-pinned.md` | wrong-value | ★ high | wiki uses the server value |
| 3 | Unpinned advisory subject is `GROUP_UNPINNED`; the server publishes `UNPINNED` | `reference/jetstream/advisory/consumer-group-unpinned.md` | wrong-value | ★ high | wiki uses the server value |
| 4 | Consumer config object is collapsed, so **no consumer default is readable** anywhere in the reference | `reference/jetstream/api/consumer/create.md` | missing | high | wiki reads the server source instead |
| 5 | `duplicate_window` default documented only as "0 for default" — the substituted value is never stated | `reference/jetstream/api/stream/create.md` | missing | medium | wiki reads the server source instead |
| 6 | `max_payload` "not recommended" over 8MB without saying what actually happens | `reference/config/max_payload.md` | enhancement | low | wiki states the real behaviour |
| 7 | ADR-42 is tagged `2.11` but describes the `prioritized` policy, which shipped in 2.12 | `nats-architecture-and-design` ADR-42 | wrong-value | medium | wiki corrects the attribution |

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
holds the tracked message IDs in RAM. A reader sizing a high-cardinality publisher cannot find the
number they are sizing against. The only public statement of "2 minutes" found anywhere was a
Synadia blog post from 2025-08-08.

**Suggested fix:** state the substituted value, and ideally the conditions under which it applies.

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

## How these were found

Not by looking for them. Each fell out of ingesting a source and cross-checking it against another:

- **1–3**: writing `wiki/reference/advisories.md` meant choosing between two subjects for the nak
  advisory, because the learn page and the reference page disagreed. Resolving that against the
  server source turned into a sweep of all 22 advisory pages, which found two more.
- **4–5**: writing `wiki/reference/defaults-and-limits.md` required defaults the docs do not carry.
- **6**: answering "what breaks above 8MB" (question-bank Q12) required knowing whether the boundary
  is enforced.
- **7**: writing the release entity pages put ADR dates and shipping versions side by side.

**The generalisable lesson for the docs:** the three factual errors are all in **generated**
reference pages, and in all three cases a **hand-written** page (a learn page, an ADR) had the
correct value. A generator that cross-checked its output against the server constants it claims to
describe would have caught all three.

## Where the wiki records each of these

| # | wiki page |
|---|---|
| 1–3 | `wiki/reference/advisories.md` — *A docs error worth knowing* |
| 4 | `wiki/summaries/s-docs-consumer-config.md`, `wiki/reference/defaults-and-limits.md` |
| 5 | `wiki/concepts/stream.md` — *The deduplication window* |
| 6 | `wiki/reference/defaults-and-limits.md` — *The 8 MB question* |
| 7 | `wiki/concepts/priority-groups.md`, `wiki/entities/nats-server-2.11.md` |
