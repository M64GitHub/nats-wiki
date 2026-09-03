---
title: "docs — Core NATS: request-reply and scatter-gather"
type: summary
area: [core, clients]
source-url: https://docs.nats.io/learn/core-nats/request-reply.md
source-path: raw/nats-docs/learn/core-nats/request-reply.md
author: nats-io docs
article: "learn/core-nats/request-reply.md and scatter-gather.md; concepts/request-reply.md read and folded (its L589 and L1040–1046 carried as pointer lines)"
date: 2026-08-31
version: ""
tags: [request-reply, inbox, _INBOX, inbox-prefix, timeout, no-responders, 503, scatter-gather, replies, reply-timeout, wait-for-empty, NATS-RPLY-22, request-many]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# docs — Core NATS: request-reply and scatter-gather

Two pages of the *Core NATS deep dive* read as one article: the private reply subject a client sets
up for itself, the three ways a request ends, and what happens when several responders answer one
request. **Unversioned by design** ("This chapter is unversioned and concept-first",
`where-next.md:30`); every server fact below is pinned at v2.14.6 by [[s-nats-server-request-reply]]
and run in [[s-nats-server-request-reply-observed]], the CLI at 0.4.0 by
[[s-nats-cli-request-reply-source]]. The `concepts/request-reply.md` primer (2,055 lines) restates
these two pages; its two sentences with something of their own are carried below as pointer lines.

## Key claims

### The inbox (`request-reply.md`)

- Request-reply "isn't a new protocol; it's the pub/sub you already know, used twice" (L12): the
  client subscribes to a fresh subject, publishes the request with that subject as its reply field,
  and the responder publishes to it (L14).
- The reply subject is an **inbox** under the reserved `_INBOX.` prefix, `_INBOX.<nuid>` with a random
  tail, one per request (L29–31). A client "doesn't open a subscription for every `request()`": on its
  first request it subscribes once to `_INBOX.<connection>.*` and reuses that subscription, each request
  adding only its final token — "thousands of concurrent requests cost one subscription, not thousands"
  (L33–35). "Clients can be configured to fall back to one subscription per request; the shared one is
  the default" (L35).
- The size budget on the reply subject is `max_control_line`, "subject plus reply subject combined, to
  4 KB by default" (L37).
- The `_INBOX.` prefix is a client option, `--inbox-prefix` in the CLI, and it "exists for
  permissions: with a distinct prefix per application, an operator can grant each one its own
  reply-subject namespace instead of a shared `_INBOX.>`" (L39).
- `nats reply` "subscribes to the subject (joining the default queue group `NATS-RPLY-22`) and
  publishes a reply to whatever inbox each request carries" (L45).

### The three outcomes (`request-reply.md`)

- **A reply.** `nats request` "prints the first reply it receives" (L222); the CLI's `--timeout`
  defaults to 5 s (L228, L531).
- **A timeout.** "Every request carries a timeout … In a client library you pass the timeout on
  every `request()` call, so a request can't wait indefinitely" (L531); when it expires "the call
  returns a timeout error … Core NATS won't make that decision for you, and it won't deliver the
  answer late" (L533). A timeout says the answer did not arrive in time, "not *why*" (L535).
- **No responders.** With zero subscribers "the server knows immediately that nobody can answer.
  Rather than let your timeout run, it sends back a **no responders** signal right away: a reply
  carrying a `503` status" (L541) — "the difference between 'the inventory service is slow' … and 'the
  inventory service isn't running at all'" (L543). The CLI prints `No responders are available` "and
  exits cleanly" (L556–561). "The signal rides the message header mechanism: the server delivers a
  reply with the header line `NATS/1.0 503`. A client needs header support to receive it, which every
  current client enables" (L563). **Neither page names the `Nats-Subject` header the 503 carries since
  2.12.0** — docs issue #85, with the bytes from run B1.
- How each client names the two errors, from the snippets (L244–523): Go `nats.ErrNoResponders` /
  `nats.ErrTimeout`; JavaScript `RequestError` with `isNoResponders()` / `TimeoutError`; Python
  `NoRespondersError` / `TimeoutError`; Rust `RequestErrorKind::NoResponders` / `TimedOut`; .NET
  `NatsNoRespondersException` "immediately when nothing is subscribed"; C `NATS_NO_RESPONDERS` /
  `NATS_TIMEOUT`; **Java** needs the `reportNoResponders()` connect option, which "surfaces a missing
  service as a 503 status" (a `JetStreamStatusException`) — otherwise a missing service is a timeout
  (L380; the primer says it outright: "You must specify the `reportNoResponders()` connect option",
  `concepts/request-reply.md:1040–1046`).
- Pitfalls (L581–939): a request without a timeout "can wait forever"; treating no responders as a
  hang; **"assuming exactly one reply"** — "A plain `request()` returns the first reply and discards
  the rest. If two inventory instances both answer … the second answer is lost silently" (L587; the
  primer's form: "By default, the `request()` method returns the first response and drops the rest",
  `concepts/request-reply.md:589`); slow work inside a responder "serializes every request behind it"
  (L939).

### Scatter-gather (`scatter-gather.md`)

- Nothing in the mechanism limits the number of responders; the single reply "was just one responder
  plus a client that stopped after the first answer" (L23). It "works only when the responders are not
  in a queue group … Every responder must subscribe plainly" (L25).
- **The CLI trap**: `nats reply` "subscribes inside a queue group named `NATS-RPLY-22`. Three `nats
  reply` instances left on that default would form one queue group, and only one of them would ever
  answer"; give each its own `--queue` name — "A queue group of one member behaves like a plain
  subscriber" (L231–233). "The client library form has no such trap" (L235).
- **Gather by count**: `--replies 3` reads "until three replies arrive, then stop — or until replies
  stop arriving, whichever comes first" (L597). Helpers: "nats.js has `requestMany` and orbit.go has
  `RequestMany` (both follow ADR-47, 'Request Many', with count, stall, and sentinel stop conditions),
  and the .NET client has `RequestManyAsync`"; elsewhere "you build the loop yourself" (L599).
- **Gather by deadline**: a fixed count "blocks forever if only two answer" (L603); `--replies 0`
  makes `--timeout` "the whole collection window … `--reply-timeout` has no effect in this mode — it
  only bounds the gap between replies when you gather by count" (L607). With one provider down "you
  get the two quotes that answered and wait out the same two-second window. If no provider is
  subscribed at all, the command returns right away with a no responders signal … a provider that's
  subscribed but slow to answer still costs the full `--timeout`" (L617).
- **Sentinel**: `--wait-for-empty` collects "until a reply arrives with an empty payload … if the
  sentinel never comes the `--reply-timeout` bounds the gap between replies" (L621).
- At-most-once: "a reply dropped in transit is just absent from the gathered set, nothing redelivers
  it, and arrival order carries no meaning" (L625); a short set "isn't an error" (L767).

## Practical takeaways

- Size `--inbox-prefix` and the permission set together: a request needs *publish* on the subject and
  *subscribe* on its own inbox prefix, and the prefix is what an operator can scope per application.
- Branch on no responders and on timeout separately; the first is a deployment problem, the second a
  latency one. Java gets the first only with `reportNoResponders()`.
- A `nats reply` that should be one of several independent responders needs its own `--queue` name;
  a library responder needs nothing.
- Gather by deadline unless the responder count is fixed; `--reply-timeout` only matters when
  gathering by count or sentinel.

## Notable quotes

- "thousands of concurrent requests cost one subscription, not thousands" (`request-reply.md:35`).
- "A queue group of one member behaves like a plain subscriber" (`scatter-gather.md:233`).

## Relevance to the wiki

The docs' half of [[request-reply]]: the inbox, the three outcomes with each client's name for them,
the CLI's gather flags. Every timing claim above was run — [[s-nats-server-request-reply-observed]]
runs B, D and F — and the `503`'s missing header is docs issue #85. The primer `concepts/request-reply.md`
is **read and folded** here (nine of its sections restate the deep dive; the two surplus sentences are
the pointer lines above).

## Questions it answers

134 (the timeout, no-responders and scatter-gather parts of the design question), 150 (the 503's
meaning), 172.

## Pages touched

[[request-reply]] · [[queue-groups]] · [[nats-timeout]] · [[subject-permissions]] · [[nats-java]] ·
[[nats-cli]] · [[orbit]] · [[nats-js]] · [[nats-net]] · [[core-nats-delivery]]
