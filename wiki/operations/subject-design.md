---
title: Subject design
type: operation
kind: pattern
area: [core, jetstream, security]
since: [2.10]   # the mechanisms this page uses — `filter_subjects`, stream subject transforms — are 2.10; the design question is older
verified-against: nats-server 2.14.6
verified-on: 2026-09-04
tags: [subject-design, token-order, namespace-first, identifier-first, cardinality, wildcards, reserved-prefixes, versioning, mappings, partition, JSMaxSubjectDetails, "32 tokens", schema-migration]
aliases: [subject hierarchy, subject schema, subject naming, designing subjects, token order, subject taxonomy, subject namespace, how to name subjects]
sources: [s-synadia-subject-hierarchies, s-gh-4170-subject-indexing-internals, s-nats-server-stream-topology-observed, s-nats-server-stream-scale-observed, s-gh-8333-high-cardinality-subjects, s-synadia-how-many-subjects, s-gh-5202-max-unique-subjects, s-gh-5097-subject-token-limit, s-nats-server-core-or-jetstream-observed, s-docs-core-nats-subjects-and-mapping, s-docs-subject-mapping, s-gh-5172-mapping-in-config-or-stream, s-docs-filtering]
created: 2026-09-04
updated: 2026-09-04
---

# Subject design

**The subject tree is the one thing on a NATS system that everything else is laid over** — routing,
permissions, stream capture, consumer filters, KV keys and the per-subject index are all the same
strings — and it is the hardest thing to change once traffic is on it. This page is the *choices*;
[[subjects-and-wildcards]] is the *rules* the server enforces, and it does not repeat them here.

## The problem

You are about to name the first few hundred subjects a system will use, and four different mechanisms
will read those names for the rest of its life:

- the **sublist**, which routes every message by matching them;
- **[[subject-permissions]]**, which is the only authorization surface there is — "your subject
  hierarchy **is** your authorization model — there isn't a separate ACL layer" (source:
  [[s-synadia-subject-hierarchies]]);
- a **[[stream]]**'s subject list, which decides what gets stored — and takes over anything that
  matches;
- a **[[consumer]]**'s filter, which is the only way to read a subset back, and can only express sets
  that correspond to token positions.

The cost of getting it wrong is not a performance number, it is that **you cannot rename a subject in
place**: once `orders.customer.created` is in production, every publisher, subscriber, stream filter,
consumer filter and permission is bound to that string. "Subject design is the first architectural
decision you make on NATS, and the most expensive one to reverse" (source:
[[s-synadia-subject-hierarchies]]).

## The design

### Start from the queries, not from the data

The maintainer's frame for the whole exercise, answering exactly this question: *"Its mostly in how you
want to define all possible sets within a stream and make sure they represent tokens in the subjects"*
(source: [[s-gh-4170-subject-indexing-internals]], @derekcollison, 2023-05-18). A stream has **two
lookup keys and only two** — by sequence and by subject — so any set a reader will ever want must be
expressible as a subject pattern, or it does not exist. Write down the subscriptions and the consumer
filters you expect *before* the subjects, and check each one can be written as a pattern.

A token that is not in the subject cannot be filtered on later without re-publishing every message.
A token that *is* there costs a little memory and nothing else, until it becomes high-cardinality
(below).

### Three shapes, and the rule for picking one

The published taxonomy, chosen by the token subscribers will wildcard on (source:
[[s-synadia-subject-hierarchies]]):

| shape | example | when |
|---|---|---|
| **namespace-first** | `orders.customer.created` — `{namespace}.{entity}.{action}` | teams own domains, service-oriented; **the default when unsure** |
| **identifier-first** | `tenant-acme.orders.created` — `{identifier}.{namespace}.{action}` | the dominant query is "everything that happened to this entity": per-tenant, per-device, per-customer |
| **multi-dimensional** | `prod.eu-west.orders.customer.created` | only when routing genuinely depends on environment or region |

The rule when two look equally good: **take namespace-first**, because of the one sentence in these
sources most worth keeping —

> "You can prepend a tenant token; you cannot easily un-prepend one." (source:
> [[s-synadia-subject-hierarchies]])

Growing `orders.customer.created` into `tenant-acme.orders.customer.created` is a mapping and a
permission change. Going the other way means rewriting every subscriber's filter.

### Token order: what you will filter on goes left, coarse before fine

Two independent reasons, and they agree:

1. **Matching.** A literal token is a map lookup on its level, `>` is a single pointer check, and `*`
   is the expensive one — a *recursive* call for the remainder of the subject at every position it
   appears (`sublist.go:771–796`, on [[subjects-and-wildcards]]). A deep tree read as
   `prefix.prefix.prefix.>` is cheap; `*` in the middle is what costs. So the tokens that select — the
   ones a filter will pin to a literal — belong on the **left**, and the ones that vary belong on the
   right where a `>` can absorb them.
2. **Growth.** Everything you might later want to split on — a tenant, a region, a version, a
   retention class — has to already be a token, and it has to be **left of** the things it partitions,
   because a stream's subject list and a consumer's filter both grow leftward badly and rightward
   easily. `orders.>` can become `orders.v2.>`; `orders.created` cannot become `orders.created.v2`
   without every subscriber changing.

The practical form: `{scope}.{entity}.{id}.{action}`, coarse to fine, with the identifiers late enough
that a wildcard can cover them and early enough that a filter can pin one.

### Where a wildcard goes

The mechanics are on [[subjects-and-wildcards]]; the design consequences are:

- **`>` only ever last, and it is the cheap one.** It is the right ending for "everything under this
  scope" — a stream subject, a monitoring subscription, a permission grant.
- **`*` is one token, anywhere, and it is the one that costs.** Prefer one `*` to three; prefer a `>`
  tail to a `*` in the middle when both express what you want.
- **A publish subject never contains a wildcard.** The server does not check it — a literal `*`
  published reaches wildcard subscribers and nobody else, which is why the Go client added a
  client-side check ([[subjects-and-wildcards]]). Design so that nothing ever wants to.
- **A consumer filter that matches nothing is not an error**: `num_pending` is `0` and the pull waits
  out its expiry and answers `NATS/1.0 408 Request Timeout` (source:
  [[s-nats-server-stream-topology-observed]], run C1b). A filter that no longer matches after a schema
  change fails the same silent way (source: [[s-docs-filtering]]) — which is why the migration order
  below matters.

### Cardinality: entity ids yes, per-message ids no

**The single most common subject-design mistake is putting high-cardinality per-message data in the
subject** — a correlation id, a request id (source: [[s-synadia-subject-hierarchies]]).
`orders.customer.created.req-7f3a9b21-4c8e-11ee` makes every message a new sublist cache entry, a new
entry in the stream's per-subject index, and it makes JetStream's own subject views unusable.

**Entity ids are the opposite case and are the point.** `orders.customer.123.created` is bounded by
your customer count, and it is what buys per-entity replay — a filtered consumer over one subject —
and per-entity optimistic concurrency ([[publishing]], [[event-sourcing-on-jetstream]]). The index
that makes this work is an adaptive radix tree with path compression, in memory, since **2.10.10**, so
**long common prefixes cost little and random suffixes cost the most** (source:
[[s-gh-5202-max-unique-subjects]]; the maintainer said ">= 2.10.9" and the tree arrives at 2.10.10).
There is **no configured maximum** for subjects in a stream; the bound is RAM.

Put the correlation id in a header — but **never in `Nats-Msg-Id`**, which JetStream reads as the
deduplication key, so reusing it silently drops "duplicates" ([[publishing]]).

### The subjects a stream must never be given

A stream captures by subject and **the publisher is never told one exists**, so a subject list widened
by one token silently takes over traffic nobody meant to store. Four rules, in the order they bite:

1. **Never let a stream's subjects cover a request/reply verb.** A stream that captures a subject
   somebody is using for request/reply **answers those requests itself**, with its own `PubAck`, and it
   arrives *first* — 277 µs against the responder's 407 µs, two indistinguishable `MSG` frames on one
   inbox. A client that takes one reply takes the ack; the responder's answer is discarded, and the
   stream stores every request with its payload (source:
   [[s-nats-server-core-or-jetstream-observed]], runs D1–D4; docs issue **#119**). Keep
   `orders.created` in the stream's tree and `orders.inventory.check` outside it — the documentation's
   own tutorial walks into this exact trap ([[core-or-jetstream]]).
2. **Never build a stream on `>`.** The server accepts one only with `no_ack` **and** `replicas: 1`,
   which is the server telling you what it is for; it then collects every reply inbox, `$SRV.PING.…`
   and `$JS.API.STREAM.INFO.<itself>` — reading the stream writes to it ([[core-or-jetstream]]).
3. **Keep your root tokens free of `$` and `_`.** Reserved, server-side: `$SYS.`, `$JS.`, `$JSC.`
   (JetStream cluster internals), `$NRG.` (Raft), `$KV.`, `$OBJ.`, `_INBOX.`, and `_R_.` / `_GR_.`
   (routed and gateway reply subjects) — all four of the last set verified in the source at v2.14.6
   (source: [[s-synadia-subject-hierarchies]]). The server refuses a stream overlapping `$JS.>` /
   `$JSC.>` / `$NRG.>` (except `$JS.EVENT.>`) or `$SYS.>` (except `$SYS.ACCOUNT.>`) without `no_ack`,
   with `10052`, and nothing else.
4. **List a stream's subjects explicitly rather than sweeping a tree**, and check
   `nats stream subjects <name>` after any change to either side. `svc.>` is not one of the refused
   shapes, so nothing warns you.

### The tenant token, and what an account buys instead

A tenant token in the subject gives **organizational clarity**; an [[account]] gives **isolation**. They
are not alternatives at the same layer: "for hard multi-tenant isolation … combine identifier-first
subjects with **separate NATS Accounts**. Accounts give you cryptographic isolation; the subject prefix
gives you organizational clarity inside each account" (source: [[s-synadia-subject-hierarchies]]).

What only an account can do: separate subject *spaces* (two tenants may both use `orders.created`),
separate limits, separate JetStream storage budgets, and a boundary a permission mistake cannot cross.
What a token can do that an account cannot: be wildcarded across tenants in one query. Choosing between
them, and what many accounts cost, is [[account]]'s subject and phase G4's; the subject-design half is
only this — **if tenancy is even possible, put the tenant token in from day one**, because prepending
one later is a mapping and un-prepending one is a rewrite.

### Versioning: the one place the public sources disagree

Both positions are defensible and this wiki carries both ([[subject-transforms]]):

- **In the subject** (`orders.v1.customer.created`) — a breaking change then produces a *different
  subject*: v1 and v2 subscribers coexist without inspecting payloads, streams can be split on the
  version boundary, and `orders.v2.>` can be granted without touching v1. Recommended from day one by
  source [[s-synadia-subject-hierarchies]].
- **In a header** — the accepted answer on
  [so#72585165](https://stackoverflow.com/questions/72585165) says to keep the version out of the
  subject and carry the schema version in a header, keeping subjects stable.

The rule that reconciles them, from the post that names the disagreement: **if the change affects
routing or subscription, it belongs in the subject; if it only affects payload parsing, a header is
enough.**

## The configuration that implements it

The subject scheme is not a config key — it is the same strings appearing in five places, and they have
to be changed in a fixed order:

| where | what it is | note |
|---|---|---|
| a publisher's `PUB` | the literal subject | never a wildcard |
| `nats stream add … --subjects "orders.*.created"` | what is stored | wildcards allowed; **explicit beats a swept tree** |
| `nats consumer add … --filter 'orders.eu.created'`, or `filter_subjects` (2.10+) | what is read back | a non-matching filter fails **silently** (source: [[s-docs-filtering]]) |
| `permissions { publish: {allow: […]}, subscribe: {…} }` | who may use it | [[subject-permissions]] |
| `mappings { }` in the account, or a stream `subject_transform` | rewriting | below |

**The two escape hatches**, and the rule for which layer:

```
# account-level: rewrite before routing, so publishers and subscribers can move separately
mappings = {
  "orders.customer.created": "orders.v1.customer.created"
}
```

```
# stream-level: deterministic sharding of a subject space into a fixed number of buckets
nats stream add ORDERS-SHARDED \
  --subjects "ingest.*" \
  --transform-source "ingest.*" \
  --transform-destination "orders.{{partition(3,1)}}.{{wildcard(1)}}" \
  --defaults
```

The maintainer's rule for choosing the layer: core mapping is **account data**, applied as a message is
published; a partition **for a stream** goes in the stream (source:
[[s-gh-5172-mapping-in-config-or-stream]]). `{{partition(n,1)}}` hashes each key to the same bucket
every time, so a consumer filtered to `orders.1.>` always reads the same share — and **the bucket count
is effectively permanent**, because changing `n` moves keys between buckets and a consumer's filter
quietly starts covering a different set ([[subject-transforms]], source: [[s-docs-subject-mapping]]).

**The migration order, when a scheme does change**: stream subject filters, then consumer filters, then
permissions. Skipping a step is how a migration becomes an incident, and every one of those three fails
*silently* rather than erroring (source: [[s-synadia-subject-hierarchies]]).

## Trade-offs and costs

### What cardinality actually costs, measured

The same stream, the same 1,000,000 × 128 B messages, the same 13-byte subject shape — only the number
of **distinct** subjects changes (source: [[s-nats-server-stream-topology-observed]], run E, one laptop
on 2.14.6, so a ratio and never a limit):

| at 10 / 10,000 / 1,000,000 distinct subjects | |
|---|---|
| RSS with the stream filled | **50.0 / 78.0 / 294.0 MiB** ⇒ ~**256 B per subject** |
| `index.db` after a clean stop | **738 / 170,549 / 17,000,550 bytes** — exactly `Σ(len(subject) + 4)` plus a ~550-byte header ([[filestore-layout]]) |
| `Took … to start JetStream` | **130.8 / 178.1 / 421.2 ms** clean, **245.8 / 279.1 / 604.9 ms** after SIGKILL |
| publish rate while filling | 179,717 / 185,289 / 198,078 msg/s — **cardinality did not slow the publish path** |
| `nats stream subjects` | **0.01 / 0.04 / 5.40 s** |
| `STREAM.INFO` with `subjects_filter: >` | 0.2 ms / 1,150 B · 2.3 ms / 200,927 B · **372.7 ms / 1,800,931 B**, and at a million it returns **100,000 of them**, paged by `offset` (`JSMaxSubjectDetails`, `jetstream_api.go:435`) |
| a consumer filtered on **one** subject | create 1.1 / 0.9 / 1.0 ms, first message 2.5 / 1.5 / 3.3 ms — **flat** |
| a consumer on the **wildcard** `c.*.evt` | create 1.1 → **18.6 ms**, first message 0.1 → **19.2 ms** |

So cardinality is a **RAM and subject-listing-API budget**, plus a few hundred milliseconds of restart.
It is not a throughput budget, and it is not a cost to a consumer filtered on one subject — the thing it
makes expensive is the **wildcard** consumer, 170× on create and 190× on first message between ten
subjects and a million.

The published figures agree on the order of magnitude and are worth having for a sizing conversation:
"in the order of **100 megs** of RAM" per million short subjects (source:
[[s-gh-8333-high-cardinality-subjects]], @jnmoyne), "roughly a few hundred bytes" each and "around 10
million subjects may add roughly **3–4 GB**" (source: [[s-synadia-how-many-subjects]]), and this wiki's
earlier run at 1.2 M seven-digit subjects, **~380 B of RSS each** with the block cache included (source:
[[s-nats-server-stream-scale-observed]]). Budget **per distinct subject, not per message**, and note the
figure is a floor that survives restarts and does not shrink when messages expire until a subject has no
messages left. The other end of the cost — recovery — is [[jetstream-recovery-is-slow]]; above 1,000,000
subjects the periodic `index.db` is no longer written at all.

And the honest caveat from the same sources: subject count "by itself is not the only question", and the
real cost at scale is usually **consumers, not subjects** (source: [[s-synadia-how-many-subjects]]) —
which is [[stream-topology-design]].

### The three things that are not limits

Because all three are repeated as if they were, and a design bent around them is bent for nothing
([[subjects-and-wildcards]] has the evidence):

| the belief | at v2.14.6 |
|---|---|
| "at most ~16 tokens" | **no such check exists.** The number appears in the docs, in an accepted Stack Overflow answer and in Synadia's own post, and nowhere in the server (docs issues #81, #82; source: [[s-gh-5097-subject-token-limit]]). What is real is a **32-token stack array** in the matcher — beyond 32 the tokenizer's slice escapes to the heap on every match that misses the cache. A soft cliff at 32, not a cap, and 16 is half of it |
| "under 256 characters" | **no length limit.** 256 is the size of a stack buffer in the subject-tree walk (`stree/stree.go`), so a longer subject costs an allocation per matched walk. The only real ceiling is **`max_control_line`** (default `4096`), which bounds the whole `PUB`/`SUB` line |
| "there is a token limit you can hit" | only if you set one: **`max_subscription_tokens`** (`1`–`255`, unset = unlimited) refuses a *subscription* with too many tokens, and it **requires a restart** to change |

Design to 32 tokens as a soft ceiling and 8–10 as a smell — "anything past 8–10 tokens is usually a
sign that you're encoding data into the subject" (source: [[s-synadia-subject-hierarchies]]) — but never
because the server will stop you.

## When *not* to put it in the subject

- **Per-message identifiers** — correlation ids, request ids, trace ids. A header, always.
- **Payload data.** If a consumer has to parse a token to get a value it also has in the body, the token
  is duplication with a migration cost.
- **A version that only changes how the payload parses.** Header. Only a version that changes *routing*
  earns a token.
- **Anything unbounded that nobody will ever filter on individually.** The test is the one at the top:
  name the query. If no consumer filter and no permission will ever pin that token, it is paying index
  memory for nothing.
- **Isolation.** A prefix is not a boundary — a permission mistake crosses it and an account does not.
  [[account]].

## Related

[[subjects-and-wildcards]] · [[stream-topology-design]] · [[stream]] · [[consumer]] ·
[[subject-transforms]] · [[subject-permissions]] · [[account]] · [[core-or-jetstream]] ·
[[publishing]] · [[filestore-layout]] · [[jetstream-sizing]] · [[jetstream-recovery-is-slow]] ·
[[jetstream-slows-as-consumers-grow]] · [[event-sourcing-on-jetstream]] · [[key-value]] ·
[[core-nats-delivery]]

## Sources

- [[s-synadia-subject-hierarchies]] — the three shapes, the choosing rule, cardinality as *the* mistake,
  the authorization sentence, the migration order, and the version-token position.
- [[s-gh-4170-subject-indexing-internals]] — two lookup keys and only two; the subject space as the set
  definition; cardinality as a memory cost, from the maintainer.
- [[s-nats-server-stream-topology-observed]] — run E, the cardinality table above; run C1b, the filter
  that matches nothing.
- [[s-nats-server-stream-scale-observed]] — ~380 B of RSS per subject at 1.2 M subjects.
- [[s-gh-8333-high-cardinality-subjects]] — "in the order of 100 megs" per million short subjects.
- [[s-synadia-how-many-subjects]] — the per-subject byte estimate, the 10-million figure, and the
  warning that consumers cost more than subjects.
- [[s-gh-5202-max-unique-subjects]] — the adaptive radix tree, path compression, and no configured
  maximum.
- [[s-gh-5097-subject-token-limit]] — the 16-token figure has no server basis.
- [[s-nats-server-core-or-jetstream-observed]] — the stream that answers the requests it captures, and
  the `>` stream.
- [[s-docs-core-nats-subjects-and-mapping]] — tokens, wildcards, the reserved prefixes, case
  sensitivity.
- [[s-docs-subject-mapping]] — the transform language and `{{partition(n, 1)}}`.
- [[s-gh-5172-mapping-in-config-or-stream]] — which layer a rewrite belongs in.
- [[s-docs-filtering]] — a consumer filter that matches nothing fails silently.
