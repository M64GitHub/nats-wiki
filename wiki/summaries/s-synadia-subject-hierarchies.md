---
title: "Synadia — How to Design NATS Subject Hierarchies"
type: summary
area: [core, jetstream, security]
source-url: https://www.synadia.com/blog/designing-nats-subject-hierarchies
source-path: raw/synadia-blog/designing-nats-subject-hierarchies.txt
author: "Andrew Connolly (Synadia)"
date: 2026-06-17
version: ""
article: "Synadia blog post, ~2,950 words, with an FAQ"
tags: [subject-design, token-order, namespace-first, identifier-first, multi-dimensional, reserved-prefixes, cardinality, correlation-id, versioning, subject-mappings, sublist, 32-tokens, JSMaxSubjectDetails]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# How to Design NATS Subject Hierarchies (Patterns, Pitfalls & Best Practices)

The only public article that is question-bank **row 109** rather than a piece of it, published
2026-06-17 — ten weeks before this wiki's docs tree was fetched. Written for engineers arriving from
Kafka, RabbitMQ or MQTT.

## Key claims

**The frame.** "Subject design is the first architectural decision you make on NATS, and the most
expensive one to reverse." The hierarchy "is the routing key, the authorization boundary, and (with
JetStream) the storage filter — all at once."

**Three patterns, chosen by the token subscribers will wildcard on:**

| pattern | shape | when |
|---|---|---|
| namespace-first | `{namespace}.{entity}.{action}` — `orders.customer.created` | teams own domains; service-oriented; **the default when unsure** |
| identifier-first | `{identifier}.{namespace}.{action}` — `tenant-acme.orders.created` | the dominant query is "everything that happened to this entity"; per-tenant, per-device, per-customer |
| multi-dimensional | `{env}.{region}.{service}.{entity}.{action}` | only when routing genuinely depends on environment or region |

"If two patterns look equally good, default to namespace-first. It's the easiest to grow into the
others later (**you can prepend a tenant token; you cannot easily un-prepend one**)."

**Constraints, stated carefully.** "There is **no hard cap** on token count, but practical guidance is
≤16 tokens and ≤256 characters. The NATS server's subscription matcher uses a **stack-allocated array
sized for 32 tokens**; subjects beyond that spill to the heap. This is a **soft performance cliff, not
a hard limit** — you won't get rejected, but very deep subjects pay a small allocation cost on every
match."

**Reserved prefixes** — the article's table adds three the docs' list does not: `$JSC.` (JetStream
cluster internals), `$NRG.` (Raft), and `_R_.` / `_GR_.` (routed and gateway reply subjects),
alongside `$SYS.`, `$JS.`, `$KV.`, `$OBJ.`, `_INBOX.`. "Subscribe to `$SYS.>` from a monitoring
service … but keep your application's root tokens free of any leading `$` or `_`."

**Cardinality.** "The single most common subject-design mistake is encoding high-cardinality,
per-message data into the subject itself — most often a correlation ID or request ID… Every unique
subject is a unique cache entry in the server's matching paths." Entity ids are fine ("bounded by your
customer count"); per-request ids are not; correlation ids go in a header — **and not in
`Nats-Msg-Id`**, "reserved by JetStream for publish-side deduplication, and reusing it will silently
drop 'duplicate' messages."

**JetStream.** "One stream per top-level namespace is the common default. Putting `orders.>` and
`payments.>` into the same stream **couples their retention, replication, and storage budget**." And:
"JetStream also exposes per-subject metadata, but its subject-detail listings are paginated and capped
(the server returns up to **100,000** subject entries per request). Schemas that explode subject
cardinality … make these views unusable."

**Security.** "Your subject hierarchy **is** your authorization model — there isn't a separate ACL
layer." Namespace-first gives team-aligned permissions, identifier-first gives tenant-aligned ones, and
"for hard multi-tenant isolation … combine identifier-first subjects with **separate NATS Accounts**.
Accounts give you cryptographic isolation; the subject prefix gives you organizational clarity inside
each account."

**Evolution.** "The honest answer: you can't change a subject in place." Two tools — a version token
(`orders.v1.customer.created`) and server-side `mappings`. The post takes a side and says so:

> "Our recommendation is to include a version token from day one… The counter-view, held by parts of
> the NATS community and reflected in some official guidance, is that the version belongs in a header
> rather than the subject… **Neither side is universally correct**; pick based on what kind of changes
> you actually ship."

The rule offered: "if a version change affects routing or subscription behavior, put it in the
subject. If it only affects payload parsing, a header is enough." And a migration order — "stream
filter updates, consumer filter updates, and permission updates. Skipping any of these is how
migrations turn into incidents."

**Common mistakes**: flat subjects (`order_created`); "anything past 8–10 tokens is usually a sign
that you're encoding data into the subject"; payload data in subjects; inconsistent casing or
separators; no plan for evolution.

## Verified against nats-server v2.14.6

Four checkable claims, all read from the source at the tag:

| claim | verdict | evidence |
|---|---|---|
| the matcher uses a stack array sized for **32 tokens** | **correct** | `tsa := [32]string{}` at `server/sublist.go:576` and `:662`, `var lnts [32]lnt` at `:869`, `tsa, tsb := [32]string{}, [32]string{}` at `:1343`, and `:1441`, `:1449`, `:1664` |
| there is **no hard cap** on tokens | **correct**, and it matches this wiki's own finding (docs issues #81, #82) | no length or token check on the publish path; `max_control_line` bounds the line, `max_subscription_tokens` is optional and off by default |
| subject-detail listings are capped at **100,000** per request | **correct** | `const JSMaxSubjectDetails = 100_000`, `server/jetstream_api.go:435`, used at `:2040`, `:2043`, `:2058` |
| `$JSC.`, `$NRG.`, `_R_.`, `_GR_.` are server-internal | **correct** | `jscAllSubj = "$JSC.>"` (`jetstream_cluster.go:11545`), `raftAllSubj = "$NRG.>"` (`raft.go:2360`), `replyPrefix = "_R_."` (`accounts.go:2450`), `gwReplyPrefix = "_GR_."` (`gateway.go:49`) |

**One claim is wrong about the mechanism** — "individual subscriptions win when interest is narrow and
stable, because the server can match them with **a direct hash lookup rather than traversing the
trie**". There is no separate hash path for literal subscriptions. `Sublist.match` looks the **whole
subject** up in `s.cache map[string]*SublistResult` first and returns on a hit — for wildcard and
literal subscriptions alike (`sublist.go:559–573`) — and on a miss `matchLevel` walks the trie one
token at a time, where the literal token *is* a map lookup (`n = l.nodes[t]`) and a `*` or `>` is a
pointer check on the same level (`l.pwc`, `l.fwc`, `sublist.go:771–796`). Recorded as docs issue
**#123**.

## Practical takeaways

- The 16-token advice is guidance, and this post is the first source to give it a **mechanism** —
  the 32-token stack array. That makes it a real cliff at 32, and 16 a conservative half of it.
- "You can prepend a tenant token; you cannot easily un-prepend one" is the single most useful
  sentence for a schema that has to survive a tenancy decision made later.
- The article and the accepted Stack Overflow answer on the same subject
  ([so#72585165](https://stackoverflow.com/questions/72585165)) **disagree on version tokens**, and
  this post says so itself. A wiki page carries both.
- `$JSC.` and `_R_.`/`_GR_.` belong on this wiki's reserved-prefix table, which had neither.

## Notable quotes

> "Subject design is the first architectural decision you make on NATS, and the most expensive one to
> reverse."

> "You can prepend a tenant token; you cannot easily un-prepend one."

> "Your subject hierarchy is your authorization model — there isn't a separate ACL layer."

## Relevance to the wiki

The backbone of `subject-design` (bank row 109): the three patterns, the choosing rule, the evolution
strategy and the mistakes. Also four verified additions to [[subjects-and-wildcards]] and
[[stream-and-consumer-config]], and one docs issue.

## Questions it answers

Row 109; row 108 in part (one stream per top-level namespace, and the account boundary for hard
tenancy); row 121 in part.

## Pages touched

[[subjects-and-wildcards]] · [[subject-permissions]] · [[subject-transforms]] · [[stream-and-consumer-config]]
