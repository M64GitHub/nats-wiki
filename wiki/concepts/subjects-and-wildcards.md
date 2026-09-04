---
title: Subjects and wildcards
type: concept
area: [core, jetstream]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-09-04
tags: [subjects, tokens, wildcards, "*", ">", reserved-prefixes, "$SYS", "_INBOX", max_subscription_tokens, max_sub_tokens, max_control_line, Invalid Subject, Invalid Publish Subject, pedantic, cardinality]
aliases: [subject, subjects, wildcard, wildcards, tokens, subject naming, reserved prefixes, "$ prefix", "_INBOX prefix", max_subscription_tokens, max_sub_tokens, "Invalid Subject", "Invalid Publish Subject", subject length limit, subject token limit, "Permissions Violation for Subscription to, too many tokens"]
sources: [s-docs-core-nats-subjects-and-mapping, s-nats-server-core-delivery, s-nats-server-core-delivery-observed, s-gh-5097-subject-token-limit, s-gh-2855-publish-with-wildcards, s-nats-cli-core-commands, s-gh-8333-high-cardinality-subjects, s-nats-server-stream-scale-observed, s-nats-go-relnotes-1.48.0, s-docs-core-nats-publish-subscribe, s-gh-5172-mapping-in-config-or-stream, s-docs-core-nats-chapter, s-client-releases-and-issues, s-synadia-subject-hierarchies, s-gh-4170-subject-indexing-internals]
created: 2026-09-03
updated: 2026-09-04
---

# Subjects and wildcards

**A subject is a dot-separated string of tokens, and the server enforces exactly three rules about it —
no empty token, no whitespace, `>` only last — on subscriptions.** Everything else people believe about
subjects (the `$` prefixes, a length or token ceiling, "you cannot publish to a wildcard") is a
convention, a client-side check, or an optional server setting. The conventions still matter, because
JetStream's filestore and the sublist pay per token and per distinct subject.

## What it is

`orders.us.created` is three tokens, split on single dots; the server treats each as a unit when it
matches, so a flat name becomes a hierarchy without the server knowing what any token means. Subjects are
**case-sensitive** (`Orders.created` ≠ `orders.created`). A subject "cost[s] almost nothing": the interest
graph holds an entry only once something subscribes, so an unsubscribed subject has no presence on the
server, and matching walks a token tree rather than every subscription (source:
[[s-docs-core-nats-subjects-and-mapping]]).

## How it behaves: what the server checks, and when

Read from `isValidSubject` at v2.14.6 and run (sources: [[s-nats-server-core-delivery]],
[[s-nats-server-core-delivery-observed]]):

| the subject | `SUB` | `PUB` from a default client | `PUB` from a `pedantic` client |
|---|---|---|---|
| empty, or an empty token (`orders..created`) | `-ERR 'Invalid Subject'`; connection stays open (run C4) | not run | `-ERR 'Invalid Publish Subject'` and processed — the same code path as the `*` row below; not run |
| a space, tab, newline, form feed or carriage return in a token | `Invalid Subject` | **misrouted**: the line is split on spaces, so `orders.us created` becomes subject `orders.us` with reply `created` (run A2) | the same misroute |
| `>` not as the last token (`orders.>.created`) | `Invalid Subject` (run C1) | not run — `processPub` makes no check, so it would be routed as a literal | `Invalid Publish Subject` and processed — the same code path as the `*` row below; not run |
| `*` or `>` as a whole token, in a publish | — | routed as a **literal** `*`: a subscriber on `orders.*.created` receives it (its `*` matches any token, the literal `*` included), `orders.>` receives it, `orders.us.created` does not (run C2) | `-ERR 'Invalid Publish Subject'`, **and still delivered** (run C3; `inbox/server-issues.md` SI-7) |
| `*` inside a token (`orders.1*`) | valid: a literal to the sublist | routed as a literal | — |
| any other byte, including non-ASCII UTF-8 | valid | valid | valid |
| more tokens than `max_subscription_tokens` | `-ERR 'Permissions Violation for Subscription to "<subj>", too many tokens'` and the log `Subscription Violation Too Many Tokens - Subject "<subj>", SID <n>` (run C5) | delivered — the limit is subscriptions only | delivered |

Three things follow. **The wire is the reason for the whitespace rule**: a `PUB` line is
`PUB <subject> [reply] <size>` split on spaces, so a space inside a subject is read as the boundary before
a reply subject and the server has no way to tell. The CLI and most clients refuse such a subject before
sending (`nats: error: nats: invalid subject`, exit 1 — run A3); the docs name the ones that do not:
nats.py's `publish`, the C client, and nats.go before **v1.48.0** — the last dated by that release's
line "Add publish subject validation and a connection option to skip it (#1974, #1979)", 2025-12-17
(source: [[s-nats-go-relnotes-1.48.0]]). Reading the twelve clients' release notes dates the rest:
the check arrived in **nats.js v3.3.0** (2025-12-16), **nats.java 2.25.1** (2026-01-15) and
**nats.rs v0.47.0** (2026-03-31), nats.net deprecated its `SkipSubjectValidation` opt-out at
**v3.0.0** (2026-07-10) — "a subject containing a space splits into subject and reply-to tokens on
the wire with no error", its own words for the mechanism — and **neither nats.c nor nats.py adds it
in their last ten releases**, so for those two the docs' word still stands (source:
[[s-client-releases-and-issues]]; the table is on [[client-defaults]], the pages are [[nats-py]] and
[[nats-c]]). **Whether a client rejects a bad subject is a version question, not a language one.** **Pedantic mode is advisory**: the check
sends the error and returns `nil`, so the message is processed (`client.go:2984–2986`). **The NUL and
invalid-UTF-8 checks exist but the subscribe path does not run them** (`checkRunes` is false), so "any
UTF-8 except whitespace" holds for routing.

## Wildcards

Wildcards are **a subscriber's tool** — "You can only send to literal subjects when publishing. Wildcards
are only applicable for subscriptions" (source: [[s-gh-2855-publish-with-wildcards]]). Two exist:

| wildcard | matches | where it may sit | example |
|---|---|---|---|
| `*` | **exactly one** token — not zero, not two | any position; several allowed (`orders.*.*`) | `orders.*.created` matches `orders.us.created`, not `orders.created` and not `orders.us.west.created` |
| `>` | **one or more** tokens | last only — `orders.>.created` is refused | `orders.>` matches `orders.created` and `orders.us.west.created`, not `orders` |

A wildcard subscriber is an ordinary subscriber: one copy per matching subscription, at-most-once, and a
late joiner sees only what is published after it subscribes ([[core-nats-delivery]]). Subscribe to the
narrowest pattern that covers the need: `orders.>` "pulls more than you want", and a `>` tap on a busy
account is a slow-consumer candidate. A `*` is a whole token, never a prefix — `widget-*` matches nothing
— which is also why a [[key-value]] key filter and a `{{partition(n,1)}}` transform work on tokens
([[subject-transforms]]). One trap the wiki has recorded elsewhere: a `*` **inside** a token is a literal
to the sublist but a wildcard to JetStream's subject tree, so a consumer filtered on `orders.1*` reports
pending messages it can never deliver — `inbox/server-issues.md` SI-3
(source: [[s-nats-server-stream-scale-observed]]).

## Reserved prefixes

The docs reserve six, and the server enforces **none of them for a plain client** (source:
[[s-docs-core-nats-subjects-and-mapping]], [[s-nats-server-core-delivery]]). The last three rows are
not in the docs' list at all; they come from Synadia's 2026-06-17 subject-design post and were read
from the v2.14.6 source to check them (source: [[s-synadia-subject-hierarchies]]):

| prefix | who uses it | on this wiki |
|---|---|---|
| `$SYS` | system events and requests | [[system-subjects]] |
| `$JS` | the JetStream API and advisories | [[js-api-subjects]], [[advisories]] |
| `$KV` | Key-Value buckets (`$KV.<bucket>.<key>`) | [[key-value]] |
| `$O` | Object Store (`$O.<bucket>.C.>`, `$O.<bucket>.M.>`) | [[object-store]] — and the leafnode deny list names `$OBJ.>` instead, SI-1 |
| `$SRV` | the services framework's discovery subjects — a **client-library convention**; the string appears nowhere in `server/*.go` | step 6 of the client-side plan |
| `_INBOX` | reply subjects clients generate (`_INBOX.<nuid>.<token>`); `--inbox-prefix` / `CustomInboxPrefix` rename it, and an allow-list needs `_INBOX.>` | [[nats-timeout]], [[subject-permissions]] |
| `$JSC` | JetStream **cluster** internals — `$JSC.>`, `$JSC.SYNC`, `$JSC.R`, `$JSC.ACK.*`, `$JSC.SI.<…>`, `$JSC.CI.<…>` (`jetstream_cluster.go:11545–11582`) | [[meta-layer]] |
| `$NRG` | Raft — see the paragraph below; the one `$` prefix the server actively refuses | [[raft-in-nats]] |
| `_R_` / `_GR_` | server-generated reply subjects for routed (`accounts.go:2450`) and gateway (`gateway.go:49`) replies | [[gateway]] |

The one `$` prefix the server does refuse is `$NRG.` — Raft traffic — from a client outside the system
account, as a publish permission violation (`client.go:4373–4378`). Everything else under `$` is guarded
by permissions you write, or not at all; a tenant that publishes to `$SYS.REQ.SERVER.PING.STATSZ` inside
its own account reaches only that account's service-import subscription for it.

## No length limit, one line limit, one optional token limit

- **There is no subject length or token limit in the server.** The docs' "Limit to ~16 tokens and under
  256 characters total" (`concepts/subjects.md:1101`) has no server basis — `inbox/docs-issues.md` #81 —
  and when a reader asked what the 16 meant, the maintainer's answer was "probably not strictly enforced
  it would have performance impact" (source: [[s-gh-5097-subject-token-limit]]). The 256 is most likely
  `JSMaxNameLen = 255`, which bounds **stream and consumer names**, not subjects.
- **`max_control_line`** (default `4096`, reloadable) bounds the whole `PUB`/`HPUB`/`SUB` line — subject,
  reply subject, sizes and queue name together — so it is the only real ceiling on a subject's length
  ([[defaults-and-limits]]).
- **`max_subscription_tokens`** (alias `max_sub_tokens`; `1`–`255`; unset = unlimited) refuses a
  *subscription* with more tokens, with the error and log line in the table above. It **requires a
  restart**: a reload with the value changed fails whole with `config reload not supported for
  MaxSubTokens: old=3, new=4` (run C6); `0` is refused as "value can not be negative", `256` as "value is
  too big" (run C7). The docs' page for the key says "Requires Restart" and nothing else — #82
  ([[config-keys]]).

## What subject cardinality costs

In core NATS, nothing per subject until something subscribes to it, and "millions" of subscriptions are
the docs' stated scale. In JetStream every distinct subject stored costs memory and disk: about **380 B of
RSS** per subject at 1.2 M subjects measured on 2.14.6 (source: [[s-nats-server-stream-scale-observed]]),
"in the order of 100 megs" per million in a maintainer's words (source:
[[s-gh-8333-high-cardinality-subjects]]), `index.db` at `len(subject) + 4` per subject on disk
([[filestore-layout]]), and a recovery-time and filtered-consumer cost that [[jetstream-recovery-is-slow]]
and [[jetstream-slows-as-consumers-grow]] measure. Token *order* decides what a filter can express and
what `{{partition(n, 1)}}` can shard on ([[subject-transforms]]); the design question — which token goes
where — is bank row 109, phase G's page.

Two neighbours. The interest graph these subjects address, and the wire tap that shows a misrouted one,
are on [[core-nats-delivery]] (source: [[s-docs-core-nats-publish-subscribe]]); whether a rename or a shard
belongs in the account's `mappings` or in a stream's transform is the maintainer's rule quoted on
[[subject-transforms]] — core mapping is account data, applied as a message is published; a partition
for a stream goes in the stream (source: [[s-gh-5172-mapping-in-config-or-stream]]).


## The 32-token cliff, and why "16 tokens" keeps being repeated

Everybody repeats the number and nobody sources it. The docs' primer states "Limit to ~16 tokens and
under 256 characters total" with no basis (#81); the accepted answer on
[so#72585165](https://stackoverflow.com/questions/72585165) gives "a reasonable value of 16 tokens
max"; and Synadia's own subject-design post repeats both figures. That post, alone among the three,
is careful to say what they are — "There is **no hard cap** on token count, but practical guidance is
≤16 tokens and ≤256 characters" — and it gives the mechanism nobody else does (source:
[[s-synadia-subject-hierarchies]]):

> The NATS server's subscription matcher uses a stack-allocated array sized for 32 tokens; subjects
> beyond that spill to the heap. This is a soft performance cliff, not a hard limit.

**Checked at v2.14.6, and it is right.** The sublist tokenizes into a `[32]string{}` on the stack at
every matching path — `sublist.go:576` and `:662` (`match` and its no-lock twin), `:1343`
(`subjectIsSubsetMatch`), `:1441`, `:1449`, `:1664`, and `var lnts [32]lnt` at `:869`. A subject with
more than 32 tokens does not fail; `append` moves the slice to the heap and every match of that
subject pays an allocation.

So the honest form of the advice is: **the cliff is at 32, and 16 is half of it.** Neither is a limit,
neither is checked, and nothing rejects a 40-token subject — `max_control_line` and, if you set it,
`max_subscription_tokens` are still the only refusals (above).

The 256 characters have no such backing. The nearest constant is `JSMaxNameLen = 255`, which bounds
**stream and consumer names**, not subjects.

## What a matcher actually does, so the wildcard question can be answered

The same post says individual subscriptions beat wildcards for a narrow, fixed interest set "because
the server can match them with a direct hash lookup rather than traversing the trie". There is no such
separate path — recorded as docs issue **#123** — and the real shape is worth knowing, because it is
what makes a wide `>` subscription cheap:

- `Sublist.match(subject)` looks the **whole subject** up in `cache map[string]*SublistResult` and
  returns on a hit, for literal and wildcard subscriptions alike (`sublist.go:559–573`). Every repeat
  publish to a subject already seen is one map lookup, whatever is subscribed.
- On a miss, `matchLevel` walks the trie once per token (`sublist.go:771–796`): the literal token *is*
  a map lookup on that level (`n = l.nodes[t]`), `>` is a single pointer check (`l.fwc`), and `*` is
  the expensive one — a **recursive call** for the remainder of the subject at every position it
  appears (`l.pwc`).

The design consequence is the opposite of the folklore: a deep tree with `>` at the end is cheap, and
the thing that costs is `*` in the middle — and, far more than either, a subject space so large that
the cache never hits because every subject is new (source: [[s-synadia-subject-hierarchies]]).

## Cardinality: the mistake that has a name

The single most common subject-design error, stated as such: encoding high-cardinality per-message
data — a correlation id, a request id — into the subject (source: [[s-synadia-subject-hierarchies]]).
`orders.customer.created.req-7f3a9b21-4c8e-11ee` makes every message a new cache entry and a new
per-subject index entry, and it makes JetStream's own subject views unusable — `STREAM.INFO` returns
at most **`JSMaxSubjectDetails = 100_000`** subject entries per request (`jetstream_api.go:435`).

**Entity ids are the opposite case and are the point**: `customer-123.orders.created` is bounded by
your customer count, and it is what buys per-entity replay — a filtered consumer over one subject, and
optimistic concurrency per entity ([[publishing]]). The maintainer's frame is that the subject space
*is* the query language: "Its mostly in how you want to define all possible sets within a stream and
make sure they represent tokens in the subjects" (source: [[s-gh-4170-subject-indexing-internals]]) — and the cost of doing so is
memory, stated in the same thread: "the subject addressing layer to a stream takes more memory the more
unique subjects that you have".

Put the correlation id in a header — but **never in `Nats-Msg-Id`**, which JetStream reads as the
deduplication key, so reusing it silently drops "duplicates" ([[publishing]]).


## What configures it

| key or field | default | change | see |
|---|---|---|---|
| `max_control_line` | `4096` | reload | [[defaults-and-limits]] |
| `max_subscription_tokens` / `max_sub_tokens` | unlimited | **restart** | [[config-keys]] |
| `pedantic` in `CONNECT` | `true` in `defaultOpts`, `false` from every client read here | per connection | the advisory publish check above |
| `mappings { }` | — | reload | rewrites a subject before routing — [[subject-transforms]] |
| `permissions { publish, subscribe }` | allow everything | reload / push | [[subject-permissions]] |

## Limits and failure modes

- **The misroute is silent.** Nothing is logged when a space splits a subject; the wire tap on
  [[core-nats-delivery]] is the way to see it.
- **A literal `*` in a publish reaches wildcard subscribers and nobody else** — the mistake "confusing to
  debug" in the docs' words, and reproduced.
- **A `$` subject is a convention.** Nothing stops an application publishing under `$KV.` or `$JS.`
  inside its account; what happens next depends on what is subscribed there.
- **The token limit is not a length limit.** `max_subscription_tokens: 3` still admits a three-token
  subject of 4,000 characters.

## The subject space is designed once, and durability is chosen per subject afterwards

The docs' running example makes the point without saying it: the core chapter builds the whole Acme
`orders.>` world — `orders.created`, `orders.shipped`, `orders.canceled`, an `orders.inventory.check`
responder, a `packers` queue group — "before it adds any persistence", and the JetStream chapter then
picks up the **identical subjects** and adds `nats stream add ORDERS --subjects "orders.>"` (source:
[[s-docs-core-nats-chapter]]).

So subject design comes first and is independent of the choice: name the things that happen, group
them by what they act on, and decide afterwards which of them a stream should capture. The one thing
that decision does impose back on the naming is separation — an event subject a stream may capture
should not sit under the same wildcard as a request/reply verb, because a stream that captures a
request subject answers it. [[core-or-jetstream]] is that decision; [[stream]] is what it does to a
subject.


## Related

[[core-nats-delivery]] · [[subject-transforms]] · [[subject-permissions]] · [[key-value]] ·
[[object-store]] · [[system-subjects]] · [[js-api-subjects]] · [[filestore-layout]] · [[jetstream-sizing]] ·
[[jetstream-slows-as-consumers-grow]] · [[jetstream-recovery-is-slow]] · [[defaults-and-limits]] ·
[[config-keys]] · [[nats-timeout]] · [[nats-py]] · [[nats-c]] · [[nats-go]]

## Sources

[[s-docs-core-nats-subjects-and-mapping]] · [[s-nats-server-core-delivery]] · [[s-nats-server-core-delivery-observed]] · [[s-gh-5097-subject-token-limit]] · [[s-gh-2855-publish-with-wildcards]] · [[s-nats-cli-core-commands]] · [[s-gh-8333-high-cardinality-subjects]] · [[s-nats-server-stream-scale-observed]] · [[s-nats-go-relnotes-1.48.0]] · [[s-docs-core-nats-publish-subscribe]] · [[s-gh-5172-mapping-in-config-or-stream]] · [[s-docs-core-nats-chapter]] · [[s-client-releases-and-issues]] · [[s-synadia-subject-hierarchies]] · [[s-gh-4170-subject-indexing-internals]]
