---
title: Mirrors and sources
type: concept
area: [jetstream, topology, deploy]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [mirror, sources, lag, mirror_direct, subject_transforms, filter_subject, external, dr, 10060, 10029, 10045, AckFlowControl, JS_SRC, workqueue]
aliases: [mirror, mirrors, sources, source stream, stream sourcing, mirror_direct]
sources: [s-docs-mirrors-and-sources, s-docs-mirrors-as-dr, s-adr-31-direct-get, s-natscli-stream-external, s-gh-7881-cross-domain-sourcing, s-adr-59-sourcing-and-mirroring, s-adr-60-reliable-sourcing, s-docs-subject-mapping, s-adr-57-kv-subject-transforms, s-docs-disaster-recovery, s-docs-get-direct, s-gh-4342-memory-stream-backup, s-gh-5606-cross-account-jetstream, s-gh-6328-jetstream-behind-gateways, s-gh-7017-kv-across-accounts, s-gh-7438-multi-region-availability, s-gh-7831-standalone-to-cluster, s-adr-51-message-scheduler, s-synadia-delayed-scheduling]
created: 2026-08-31
updated: 2026-09-01
---

# Mirrors and sources

The two ways to build one [[stream]] from another. A **mirror** is an exact read-only copy of a
single stream; **sources** merge many streams into one. Both replicate continuously and both are
eventually consistent (source: [[s-docs-mirrors-and-sources]]).

For an operator they are three different tools wearing one mechanism: a read replica, an aggregate,
and a disaster-recovery copy at a second site.

## How they behave

| | **Mirror** | **Source** |
|---|---|---|
| upstreams | exactly **one** | one or **many** |
| sequence numbers | **kept from the upstream** | **fresh**, interleaved across sources |
| timestamps and subjects | kept from the upstream | as delivered |
| own subjects, direct publishes | **no — read-only** | yes, optional |
| change the config later | **no — delete and recreate** | yes — add, drop or edit sources |
| ordering | the upstream's order | per-upstream order kept; **no order across upstreams** |

**A mirror's copy is exact.** "A message in the mirror keeps the same sequence number, the same
timestamp, and the same subject it had upstream." If `orders.created` was sequence 1 upstream, it is
sequence 1 in the mirror.

**A mirror is read-only because it listens on no subjects of its own.** A publish routes to whatever
stream owns the subject — the origin, never the mirror.

**Both keep their own retention.** The upstream may keep seven days while the mirror keeps forever;
the mirror's own limits decide what it stores.

**Replication is asynchronous.** "The upstream stores a message and acknowledges the publisher
*before* the mirror has it." The gap is `Lag`.

## What configures it

```
nats stream add ORDERS-ARCHIVE --mirror ORDERS
nats stream add ALL-ORDERS --source ORDERS-US --source ORDERS-EU --source ORDERS-APAC
nats stream add ORDERS_DR --mirror ORDERS --defaults      # run against the second site
nats stream info ORDERS-ARCHIVE
```

Per-entry fields on a mirror or source: `filter_subject`, `subject_transforms`, `opt_start_seq`,
`external`. A mirror also interacts with [[direct-get]] through **`mirror_direct`** — see below.

`nats stream info` grows a block that a plain stream does not have:

```
Mirror Information:
  Stream Name: ORDERS
          Lag: 0
    Last Seen: 1.20s
```

A **sourced** stream carries a `Source Information` block **per upstream**, each with its own `Lag`
and `Last Seen`, "because each source replicates on its own".

Reading these three fields (source: [[s-docs-mirrors-as-dr]]):

- **`Stream Name`** — the upstream. "If it says anything else, the mirror points at the wrong source."
- **`Lag`** — messages the upstream has that the mirror does not. **This is your RPO**: "any number
  above zero is the data you'd lose if the primary vanished this instant."
- **`Last Seen`** — how long since the mirror heard from the upstream. A growing value means "the
  `Lag` you read is already stale". In the monitoring JSON this field is named **`active`**, not
  `last_seen`.

## Mirrors and Direct Get

A mirror can answer reads addressed to its **upstream**, which is how read load reaches servers in
another cluster or region. The switch is **`mirror_direct`** on the *mirror's* config, and it has
four rules that surprise people (source: [[s-adr-31-direct-get]]):

1. At create time, if the upstream is visible, `mirror_direct` is **forced to match the upstream's
   `allow_direct`** — a disagreeing value is rejected in pedantic mode and silently aligned
   otherwise.
2. If the upstream is not visible (an External mirror across domains), your value is preserved.
3. A mirror **only joins the read pool once it has caught up** to within a small lag window, so a
   fresh mirror contributes nothing to read availability yet.
4. **`mirror_direct` is captured at create time and never refreshed.** Toggling the upstream's
   `allow_direct` later desynchronises every mirror until each one is itself updated. Enabling or
   disabling mirror participation is therefore **two operations**: the upstream *and* an update on
   each mirror.

ADR-31's own advice: "always set `mirror_direct` to their desired value."

**And the read you get from a mirror is a read that may be behind.** Direct Get "answers from any
replica or mirror, which may trail the leader", so it is the wrong tool for a read-after-write check
such as confirming a publish landed; `nats stream get` goes to the leader and is always current
(source: [[s-docs-get-direct]]). That staleness is the price of the read spreading this section is
about — see [[direct-get]].

## Limits and failure modes

- **A mirror is not a backup.** "A mirror follows the upstream's live writes, so a corrupt write
  lands in the mirror too — and a mirror keeps no earlier state to rewind to." It gives you
  availability (short RTO), not a recovery point. Pair it with snapshots; see
  [[backup-and-restore-jetstream]].
- **Delete the upstream and the mirror does not die — it freezes.** It "keeps every message it had
  already copied, stops receiving new ones, and records the fault in the **`Error` field** of its
  Mirror Information". Purge a range upstream and the mirror keeps what it already stored, detects
  the sequence gap and skips the missing messages — reliably **only on a Limits upstream**, because
  the server distinguishes "the upstream dropped these" from "we missed these" by comparing the
  upstream sequence with the consumer's delivery sequence (source:
  [[s-adr-59-sourcing-and-mirroring]]). Either way you are left with a stale copy frozen
  at the break, not a chosen point in time.
- **Publishing to a mirror fails in a confusing way.** The message lands in the origin stream that
  owns the subject. Force it with `Nats-Expected-Stream: ORDERS-ARCHIVE` and the server rejects it —
  **`expected stream does not match`, error `10060`** — because the subject routed to the origin.
- **`filter_subject` and `subject_transforms` are mutually exclusive on one entry.** The server
  rejects a config setting both. A transform filters *and* renames in one step; use it when you need
  the rename, `filter_subject` when you only need the subset.
- **Cross-account and cross-domain config fails silently.** The `external` block needs matching
  exports and imports, and **each of the three subjects has a required type**: the consumer API and
  flow-control subjects are **service** exports (request/reply), the delivery subject is a **stream**
  export (one-way). "Get a type wrong and replication doesn't fail with an error; the mirror never
  catches up."
- **A mirror's config is fixed at creation.** Changing the upstream, the filter or the transform is a
  delete-and-recreate. That is cheap — the upstream still holds the data — but it is not an edit.
  Sources, by contrast, can be added, dropped and edited in place.

## What a mirror may not be, and what a source may

ADR-59 is the authoritative spec, and its restriction lists are the fastest way to find out why a
create was rejected (source: [[s-adr-59-sourcing-and-mirroring]]).

A **mirror** cannot be combined with `subjects`, `sources`, `first_seq`, `allow_msg_counter`,
`allow_atomic`, `allow_msg_schedules` or `subject_delete_marker_ttl` — the last because "delete
markers would insert new messages and break sequence alignment", and a mirror's whole promise is that
sequences match. It *can* use the stream-level `subject_transform`, `republish`, `compression` and
`allow_msg_ttl`.

A **sourced** stream is only barred from `mirror` and `allow_msg_schedules`. It may keep its own
`subjects` and take direct publishes alongside what it replicates.

Two source entries count as **duplicates** on four fields together — stream name, `filter_subject`,
`subject_transforms` and the external API prefix — so the same upstream may be sourced twice as long
as one of those differs:

```
nats stream add SPLIT --source ORDERS --source ORDERS   # rejected: identical entries
```

**Transforms apply in a fixed order**: the per-source `filter_subject` or `subject_transforms` as
messages are selected upstream, then the stream-level `subject_transform` on everything entering the
stream — including direct publishes.

**Cycle detection stops at the account boundary.** The server prevents A→B→A *within one account*;
across domains or accounts "it is the operator's responsibility to ensure that cross-domain
configurations do not create replication cycles". Nothing warns you.

## When the upstream is a WorkQueue or an Interest stream

Before **2.14** the answer was "don't": the internal replication consumer is ephemeral and
`AckNone`, and on those retentions a delivered message is removed immediately, so anything lost in
flight is lost for good (source: [[s-adr-59-sourcing-and-mirroring]]). ADR-59 gives both reasons —
on a WorkQueue the replication consumer is a `Direct` consumer that **bypasses the subject-overlap
check**, so it can silently coexist with a real worker consumer on the same subjects and break the
one-consumer-per-partition guarantee; on an Interest stream the replication consumer's inactive
threshold is **10s** (`sourceHealthCheckInterval`, `stream.go:3121` at 2.14.6), so a link down for
longer leaves nobody holding interest and new messages are dropped before they can be copied.

**2.14 fixes it by making the replication consumer durable** (source:
[[s-adr-60-reliable-sourcing]]). What an operator sees change:

- **A visible consumer appears on the upstream**, named `JS_MIRROR_<suffix>` or `JS_SRC_<suffix>`,
  carrying metadata `_nats.mirror.stream` / `_nats.src.stream` (plus `.acc`, and `.domain` when one
  is set) naming the stream that created it. Read that metadata before deleting anything.
- **Removing the source does not reliably remove the consumer.** Deletion is best-effort by design;
  a leftover `JS_SRC_*` on the upstream is yours to delete.
- **A new ack policy, `AckFlowControl`**, replaces `AckNone` on these consumers: flow-control
  messages carrying `Nats-Last-Stream` and `Nats-Last-Consumer` acknowledge what the destination has
  actually stored, which is what allows a WorkQueue message to be removed only once it is safe.
  `AckWait` and `BackOff` must be unset on such a consumer and `MaxDeliver` must be `-1`.
- **It requires API level 4 on the upstream server** — the create request carries
  `Nats-Required-Api-Level: 4` (`stream.go:3679`, 2.14.6), so a half-upgraded cluster or an older hub
  will not give you reliable sourcing.
- **You may bring your own consumer** ("durable sourcing"): `sources[].consumer` takes a `name` and
  a `deliver_subject`, and then `opt_start_seq`, `opt_start_time` and `filter_subject` must be set on
  the *consumer*, not on the source. That buys lifecycle control — **pausing the consumer pauses
  replication** — and two shapes the built-in path cannot express, `DeliverPolicy=last_per_subject`
  and `ReplayPolicy=original`.

The WorkQueue overlap rule still applies to the durable consumer: it blocks any other consumer with
an overlapping filter, so a WorkQueue stream that is both worked and mirrored wants to be an Interest
or Limits stream instead.

## Reading the replication state when `Lag` is not enough

Three things ADR-59 documents that no CLI output shows (source: [[s-adr-59-sourcing-and-mirroring]]):

**The two error codes.** A replication consumer that cannot be created reports `10029` (mirror) or
`10045` (source) in the `error` field of the mirror/source info — wrapping the real cause: upstream
missing, permission denied, external domain unreachable, subscription failure, or a **30s** timeout
waiting for the consumer-create response. It clears itself on reconnection, so an alert must read it
rather than a human. See [[error-codes]].

**The internal consumers, on demand.** They are hidden from the consumer API by a `Direct` flag, but
`/jsz` will show them:

```
curl -s 'http://127.0.0.1:8222/jsz?streams=true&consumers=true&direct-consumers=true&config=true&acc=APP'
```

`direct_consumer_detail` then carries full `ConsumerInfo` for each `mirror-<id>` / `src-<id>`
consumer, whose delivered and ack-floor positions can be compared against the upstream's state — the
detail behind `lag`, `active` and `error`.

**Where a message came from.** Every sourced message carries
`Nats-Stream-Source: <stream> <sequence> <filter> <dest> <original-subject>`, with `>` meaning
"none" — for example `ORDERS 42 > > orders.us.new`. When sources are daisy-chained the server
**replaces** the header, so it always names the immediate upstream, not the origin of the chain.


## Why an operator cares

- **`Lag` is the number to alert on, and `Last Seen` is what validates it.** An alert on `Lag` alone
  reads healthy while replication is dead. On a sourced stream you need one alert per upstream.
- **Two of the failure modes are silent** — the wrong export type, and a desynchronised
  `mirror_direct`. Neither produces a log line; both produce a copy that quietly never catches up.
- **R3 is not a second site.** Replication protects against losing one node in a cluster; a mirror is
  what survives losing the cluster. See [[replicas]].
- **A mirror is the only way to back up a memory stream.** A snapshot reads a stream's on-disk files
  and a memory stream has none, so `nats stream backup` fails; the maintainer's answer is blunt —
  "If you really need to, create a file backed mirror and back that up" (source:
  [[s-gh-4342-memory-stream-backup]]; [[backup-and-restore-jetstream]]).
- **Promotion is a metadata operation, so it needs the meta group.** Every `stream rm` and
  `stream edit` in the promotion goes through the JetStream metadata group: no edit succeeds until
  the cluster recovers, and "the promoted stream must live where that quorum survives" — which is why
  a DR mirror normally sits in its own [[jetstream-domain]] or its own cluster. Step order matters
  too: dropping the mirror config (`--no-mirror`) comes before removing the lost stream's assignment
  (`nats stream rm ORDERS --force`), which exists only because the dead stream's subjects still
  occupy the account and would otherwise collide with `subjects overlap with an existing stream`
  (**10065**) (source: [[s-docs-disaster-recovery]]; [[disaster-recovery]] has the runbook).

## Crossing a domain or an account

The `external` block is the field that lets a mirror or a source reach a stream in another
[[jetstream-domain]] or another [[account]]. Its two fields are two lines of the server
(`stream.go:425–429`) and appear **nowhere** in the docs tree (`inbox/docs-issues.md` #21):

```go
type ExternalStream struct {
	ApiPrefix     string `json:"api"`
	DeliverPrefix string `json:"deliver"`
}
```

The `nats` CLI has built both cases interactively for years, and its two branches are the clearest
statement of the difference (source: [[s-natscli-stream-external]]):

| | across a **domain** | across an **account** |
|---|---|---|
| `api` | `$JS.<domain>.API`, composed by the CLI | **your local prefix** where the foreign JetStream API "has been imported" |
| `deliver` | optional | required |
| precondition | the two domains differ and the link is up | the export/import pair already exists |

The server takes the domain back out of the prefix as its **second token**
(`ExternalStream.Domain()`, `stream.go:432–437`), so `$JS.<domain>.API` is a required shape, not a
convention. A prefix that overlaps `$JS.API` is rejected at create time — error **10021**.

The full procedure, including what the docs cannot tell you and what this wiki could not verify, is
[[cross-domain-sourcing]].

**This is the data plane of every cross-boundary question**, and the reason mirrors and sources keep
turning up as the answer to problems that sound like something else:

- **Across accounts.** There is no cross-account user, so the two ways to reach another tenant's
  JetStream are importing its `$JS.API.>` under a prefix (control plane) or **sourcing its streams**
  into your own (data plane) — the maintainer's own framing, with a worked repository at
  `synadia-labs/cross-account-jetstream-sourcing` (source: [[s-gh-5606-cross-account-jetstream]];
  [[cross-account-sharing]], [[account]]).
- **Sharing a KV bucket across accounts** has no first-class form, and mirroring `KV_<bucket>` into
  the second account is the shape people reach for. Note what it is not: **read access and write
  access are not symmetric**, because a mirror is read-only (source:
  [[s-gh-7017-kv-across-accounts]]).
- **Across regions**, whichever topology you pick. "Crossing a JetStream boundary is a
  **mirror-or-source** operation either way", so the choice between a gateway and a leafnode is a
  network decision, not a replication one (source: [[s-gh-6328-jetstream-behind-gateways]]) — and in
  a super-cluster "sourcing and consuming from streams in other regions remains the same", which is
  the convenience a single virtual cluster buys at the price of one WAN-wide meta group
  (source: [[s-gh-7438-multi-region-availability]]; [[multi-region-jetstream]]).
- **Off a standalone server and into a cluster.** Because adding a `cluster` block deletes the
  standalone server's streams, a maintainer's suggested lower-downtime path is to "leafnode connect
  the standalone server to a cluster and create mirrors of the streams first, then unplug the
  leafnode standalone server and make the streams stop being mirrors" — called "the most 'native' way
  to do this migration" (source: [[s-gh-7831-standalone-to-cluster]];
  [[streams-deleted-when-clustering-a-standalone-server]]).


## Transforming subjects while copying

Each `sources` entry, and a `mirror`, can carry its own **subject transform**, so messages can be
re-namespaced as they are copied — prefixing every region's orders as they merge into one aggregate,
for instance. The template language and the two other places it is used are on
[[subject-transforms]]; the config fields are the per-source `subject_transforms`
(source: [[s-docs-subject-mapping]], [[s-docs-stream-config]]).

**A KV bucket copied to another bucket is a stream copy with two extras** (source:
[[s-adr-57-kv-subject-transforms]]). Because a bucket *is* a stream ([[key-value]]), the client
builds the copy for you and fills in what you would otherwise get wrong:

- **A KV mirror always sets `mirror_direct`**, and its stream name is `KV_`-prefixed if it is not
  already — so a KV mirror is expected to serve reads for the upstream bucket, joining its responder
  pool. Every `mirror_direct` alignment rule above applies to it unchanged.
- **A KV source gets a subject transform generated for it.** A source with no explicit transform is
  assumed to be a KV bucket, `KV_`-prefixed, and given
  `$KV.<source>.>` → `$KV.<bucket>.>` so keys land in the destination bucket's own subject space.
  Sourcing `ORDERS` into `NEW_ORDERS` with a key filter `NEW.>` produces:

  ```json
  {"sources": [{"name": "KV_ORDERS",
                "subject_transforms": [{"src": "$KV.ORDERS.NEW.>", "dest": "$KV.NEW_ORDERS.>"}]}]}
  ```

**Two constraints that come from elsewhere and land here.** A mirror **cannot also be a
batch-publish target** — the server refuses the config with
`10209 stream mirrors can not also use batch publishing` ([[error-codes]], [[publishing]]). And a
stream that is a mirror or a source **never gets the default `duplicate_window`** substituted, which
is why deduplication behaves differently on a copy than on the original ([[stream]]).

## Related

The promotion procedure that turns a mirror into a writable primary is [[disaster-recovery]];
what a snapshot protects that a mirror cannot is [[backup-and-restore-jetstream]].


[[stream]] · [[replicas]] · [[direct-get]] · [[error-codes]] · [[key-value]] · [[message-ttl]] ·
[[backup-and-restore-jetstream]] · [[monitoring-endpoints]] · [[account]] ·
[[cross-account-sharing]] · [[multi-region-jetstream]] · [[jetstream-domain]] ·
[[streams-deleted-when-clustering-a-standalone-server]] · [[disaster-recovery]] ·
[[cross-domain-sourcing]] · [[subject-transforms]]

## A stream that copies cannot schedule

`allow_msg_schedules` ([[message-scheduling]]) is refused on both shapes, with a code for each
(source: [[s-adr-51-message-scheduler]], observed at v2.14.6):

```
nats: error: could not create Stream: stream mirrors can not also schedule messages (10186)
nats: error: could not create Stream: stream source can not also schedule messages (10187)
```

The reason is the one this page turns on: a mirror or a source is **fed** by another stream, and a
schedule has to be *stored* on the stream that will fire it. So the schedule and the copy cannot be
the same stream.

**That constraint shapes the recommended design for interest retention.** ADR-51's preferred layout
puts the schedules in a dedicated `workqueue` stream and has the `interest` stream **source** the
target subjects from it — schedules on one side, application consumers on the other. The asymmetry is
the point: `allow_msg_schedules` goes on the **source** stream only, because the downstream stream
has sources configured and therefore cannot set it. See [[retention-policies]].


### Where NATS sits against other brokers on delayed delivery

Worth knowing when someone arrives expecting a feature from elsewhere: "Amazon SQS offers delay
queues natively. RabbitMQ supports delayed delivery through a plugin. **Kafka has no built-in
per-message delay at all**" (source: [[s-synadia-delayed-scheduling]]). NATS's answer is
[[message-scheduling]] — server-side, per-message and header-driven — and it is the one feature a
stream **cannot** have while it mirrors or sources another.


## To verify

- Whether a **KV mirror on file storage** is materially slower than on memory storage
  (question-bank Q76) is not addressed by any source read here.

## Sources

[[s-docs-mirrors-and-sources]] · [[s-docs-mirrors-as-dr]] · [[s-adr-31-direct-get]] · [[s-natscli-stream-external]] · [[s-gh-7881-cross-domain-sourcing]] · [[s-adr-59-sourcing-and-mirroring]] · [[s-adr-60-reliable-sourcing]] · [[s-docs-subject-mapping]] ·
[[s-adr-57-kv-subject-transforms]] · [[s-docs-disaster-recovery]] · [[s-docs-get-direct]] ·
[[s-gh-4342-memory-stream-backup]] · [[s-gh-5606-cross-account-jetstream]] ·
[[s-gh-6328-jetstream-behind-gateways]] · [[s-gh-7017-kv-across-accounts]] ·
[[s-gh-7438-multi-region-availability]] · [[s-gh-7831-standalone-to-cluster]] · [[s-adr-51-message-scheduler]] · [[s-synadia-delayed-scheduling]]
