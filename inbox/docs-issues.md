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
v2.14.6** and the docs tree fetched **2026-08-31**. Rows 8–10 concern **client** claims, so their
authority is the client repository at its current release plus the package registry, not the server
— stated per row.

| # | issue | where | kind | severity | status |
|---|---|---|---|---|---|
| 1 | Nak advisory subject is `MSG_NAK`; the server publishes `MSG_NAKED` | `reference/jetstream/advisory/nak.md` | wrong-value | ★ high | wiki uses the server value |
| 2 | Pinned advisory subject is `GROUP_PINNED`; the server publishes `PINNED` | `reference/jetstream/advisory/consumer-group-pinned.md` | wrong-value | ★ high | wiki uses the server value |
| 3 | Unpinned advisory subject is `GROUP_UNPINNED`; the server publishes `UNPINNED` | `reference/jetstream/advisory/consumer-group-unpinned.md` | wrong-value | ★ high | wiki uses the server value |
| 4 | Consumer config object is collapsed, so **no consumer default is readable** anywhere in the reference | `reference/jetstream/api/consumer/create.md` | missing | high | wiki reads the server source instead |
| 5 | `duplicate_window` default documented only as "0 for default" — the substituted value is never stated | `reference/jetstream/api/stream/create.md` | missing | medium | wiki reads the server source instead |
| 6 | `max_payload` "not recommended" over 8MB without saying what actually happens | `reference/config/max_payload.md` | enhancement | low | wiki states the real behaviour |
| 7 | ADR-42 is tagged `2.11` but describes the `prioritized` policy, which shipped in 2.12 | `nats-architecture-and-design` ADR-42 | wrong-value | medium | wiki corrects the attribution |
| 8 | `nats.net` is described as ".NET 6+"; the current client **dropped `net6.0`** | `concepts/ecosystem.md` | wrong-value | medium | wiki states the v3 target frameworks |
| 9 | `nats.deno` is listed among "the archived" repos superseded by `nats.js`; it is **not archived** | `concepts/ecosystem.md` | wrong-value | low | wiki says which three are archived |
| 10 | The Python client's two PyPI distributions are never reconciled: the client map names neither, and `nats-core` appears only on a WebSocket page | `concepts/ecosystem.md`, `concepts/getting-started.md`, `learn/websocket/your-first-websocket-connection.md` | missing | medium | wiki lists both packages and their Python floors |

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

## How these were found

Not by looking for them. Each fell out of ingesting a source and cross-checking it against another:

- **1–3**: writing `wiki/reference/advisories.md` meant choosing between two subjects for the nak
  advisory, because the learn page and the reference page disagreed. Resolving that against the
  server source turned into a sweep of all 22 advisory pages, which found two more.
- **4–5**: writing `wiki/reference/defaults-and-limits.md` required defaults the docs do not carry.
- **6**: answering "what breaks above 8MB" (question-bank Q12) required knowing whether the boundary
  is enforced.
- **7**: writing the release entity pages put ADR dates and shipping versions side by side.
- **8–10**: writing one entity page per official client meant reading all twelve READMEs next to the
  docs' client table. Every claim in that table was checked against its repository; three did not
  survive. The two `wrong-value` rows are both **staleness in a hand-maintained table** — the docs
  page is correct as written for an earlier release of the thing it describes.

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
| 8 | `wiki/entities/nats-net.md` — *What an operator needs to know* |
| 9 | `wiki/entities/nats-js.md` — *What an operator needs to know* |
| 10 | `wiki/entities/nats-py.md` — *What an operator needs to know* |
