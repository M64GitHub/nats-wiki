---
title: Cross-domain JetStream sourcing
type: operation
kind: runbook
area: [jetstream, topology, security]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [external, api-prefix, deliver-prefix, jetstream-domain, sourcing, mirror, service-import, 10021, 10022, 10024]
aliases: [cross-domain sourcing, cross domain mirror, source from another domain, external stream, api prefix, deliver prefix]
sources: [s-natscli-stream-external, s-gh-7881-cross-domain-sourcing, s-nats-server-leafnode-js-domains, s-docs-mirrors-and-sources, s-gh-5606-cross-account-jetstream, s-docs-cross-account, s-gh-7438-multi-region-availability, s-adr-59-sourcing-and-mirroring, s-docs-mirrors-as-dr]
created: 2026-08-31
updated: 2026-08-31
---

# Cross-domain JetStream sourcing

**Goal.** Copy a stream from a JetStream system in one [[jetstream-domain]] into a stream in another
— a regional read replica on a leaf, or aggregation from leaves up into a hub.

**Read this first:** the docs cannot get you there. `external`, `api` and `deliver` appear **nowhere**
in the 861-page docs tree (`inbox/docs-issues.md` #21), and
[gh#7881](https://github.com/nats-io/nats-server/discussions/7881) asks exactly this question and has
**no maintainer reply** (source: [[s-gh-7881-cross-domain-sourcing]]). This page is assembled from
the server source, the `nats` CLI's own prompts and one maintainer sentence, and it says at each step
what is verified and what is not.

## Preconditions

- Both sides run JetStream and have **different** `jetstream { domain }` values. Identical domains
  either extend one JetStream onto the other or are actively denied — [[jetstream-domain]].
- A [[leafnode]] link between them, up and in the account that will hold the stream.
- **Same account on both sides** for the simple case. Cross-account *and* cross-domain is the hard
  case; it is section 3 below and it is where the public record runs out.
- `nats` CLI. The versions here are natscli **0.4.0**.

## Steps

### 1 · Confirm the two domains are separate and reachable

```
nats --js-domain hub stream ls
nats --js-domain eu  stream ls
```

Both must answer, from the same client. If one returns the other's streams, the link is *extending*
rather than bridging two domains — check the log for the line that says it is not:

```
JetStream using domains: local "eu", remote "hub"
```

Its **absence** on a leafnode connection means that connection extended
(source: [[s-nats-server-leafnode-js-domains]]).

### 2 · Same account, two domains — the simple case

This is the one the CLI builds for you. Run `nats stream add` with no flags and answer:

```
? Import mirror from a different JetStream domain  Yes
? Foreign JetStream domain name  hub
? Delivery prefix  (leave empty)
```

The CLI composes the prefix itself (`stream_command.go:3023`):

```go
mirror.External.ApiPrefix = fmt.Sprintf("$JS.%s.API", domainName)
```

so the resulting stream config is:

```json
{
  "name": "ORDERS-EU",
  "mirror": {
    "name": "ORDERS",
    "external": { "api": "$JS.hub.API" }
  }
}
```

The delivery prefix is **optional** in this branch — the CLI does not mark it required
(source: [[s-natscli-stream-external]]).

To automate, capture and replay the config rather than hand-writing it:

```
nats stream add --output orders-eu.json      # build once, interactively
nats stream add --config orders-eu.json --validate
nats stream add --config orders-eu.json
```

Use `--source` instead of `--mirror` when you want a merged aggregate that keeps its own writes; the
`external` block is identical and lives on each `sources[]` entry.

### 3 · Different accounts as well — the export/import pair

The `external` block does **not** create the access. It names the local prefix under which the remote
JetStream API has already been imported — the CLI's own help text says so: "The prefix where the
foreign account JetStream API has been imported."

So the order is: build the export/import pair first, then point `external` at your local prefix.

Three subject families cross, and **each has a required export type**
(source: [[s-docs-mirrors-and-sources]]):

| what crosses | export type | why |
|---|---|---|
| the consumer API (`$JS.…API.CONSUMER.>`) | **service** | request/reply |
| flow control | **service** | request/reply |
| the delivery subject | **stream** | one-way |

Get a type wrong and "replication doesn't fail with an error; the mirror never catches up".

The failure when the import is missing names the subject:

```
Error adding service import "$JS.leaf01a.API.CONSUMER.CREATE.tank": service import not authorized
```

Read the subject to learn which side is missing the export
(source: [[s-gh-7881-cross-domain-sourcing]]).

In the CLI, this is the **second** branch — decline the domain question and answer:

```
? Import mirror from a different JetStream domain  No
? Import mirror from a different account  Yes
? Foreign account API prefix  <your local import prefix>
? Foreign account delivery prefix  <your local import prefix>
```

Both are **required** here, unlike the domain branch.

The only public maintainer statement on this path is one sentence, from a different thread: "You
should be able to import the foreign account jetstream API and manage it using the API prefix options
in clients and CLI" (source: [[s-gh-5606-cross-account-jetstream]]).

### 4 · What the server checks

At stream create (`stream.go:2093–2101`, v2.14.6):

- the API prefix "must be a valid subject without wildcards";
- it must not collide with `$JS.API` itself — `NewJSStreamExternalApiOverlapError`;
- a delivery prefix must be a valid subject and must not overlap the stream's own subjects —
  `NewJSStreamInvalidExternalDeliverySubjError`, `NewJSStreamExternalDelPrefixOverlapsError`.

The three error codes these belong to are **10021**, **10022** and **10024** — see [[error-codes]].

The server derives the domain back out of the prefix by taking its **second token**
(`ExternalStream.Domain()`, `stream.go:432–437`), which is why the `$JS.<domain>.API` shape is not a
convention you may vary.

## Verify

```
nats --js-domain eu stream info ORDERS-EU
```

```
Ext. API Prefix: $JS.hub.API
```

and the replication block:

```
Mirror Information:
  Stream Name: ORDERS
          Lag: 0
    Last Seen: 1.20s
```

- **`Lag` is your RPO.** Any value above zero is what you would lose right now.
- **`Last Seen` validates the `Lag`.** A growing `Last Seen` means the `Lag` you are reading is
  already stale — alert on both (source: [[s-docs-mirrors-as-dr]]).
- `nats stream report` has an API-prefix column, so one command audits every external source at once.

## Rollback

A mirror's configuration is **fixed at creation**: changing the upstream, the filter or the transform
is a delete-and-recreate. That is cheap — the upstream still holds the data — but it is not an edit.
Sources can be added, dropped and edited in place (source: [[s-docs-mirrors-and-sources]]).

```
nats --js-domain eu stream rm ORDERS-EU
```

Removing the stream leaves the exports and imports in place; remove those separately if they were
added only for this.

## Pitfalls

- **`external` without the import does nothing visible on the upstream.** The error appears on the
  side adding the stream, as a *service import not authorized*, naming the subject.
- **The wrong export type is completely silent.** The consumer API is request/reply and must be a
  **service** export; the delivery subject is one-way and must be a **stream** export. This is one of
  the two silent failure modes on [[mirrors-and-sources]].
- **`mirror_direct` is captured at create time** and, for an external mirror whose upstream is not
  visible, your value is preserved rather than aligned. Set it deliberately — see
  [[direct-get]] and [[mirrors-and-sources]].
- **Hand-writing `$JS.<domain>.API` is the easiest thing to get wrong**, and the server only tells
  you at create time if it collides with `$JS.API`. Let `nats stream add` compose it.
- **A mirror is not a backup.** It follows live writes, so a bad write arrives too, and it keeps no
  earlier state — pair it with [[backup-and-restore-jetstream]].
- **Cycle detection does not cross the domain boundary.** The server refuses A→B→A inside one
  account; across domains or accounts "it is the operator's responsibility to ensure that
  cross-domain configurations do not create replication cycles" — there is no warning and no log
  line, only a stream pair that never settles (source: [[s-adr-59-sourcing-and-mirroring]]).
- **The third subject is easy to forget.** ADR-59 lists `$JS.API.CONSUMER.>` (service),
  the delivery subject (stream) **and `$JS.FC.>` (service)** — flow control back to the origin. A
  mirror that starts and then stalls with no error is the shape of a missing flow-control import.

## Related

[[jetstream-domain]] · [[mirrors-and-sources]] · [[multi-region-jetstream]] · [[leafnode]] ·
[[cross-account-sharing]] · [[account]] · [[disaster-recovery]] · [[js-api-subjects]] ·
[[error-codes]] · [[nats-cli]] · [[direct-get]]

## Sources

[[s-natscli-stream-external]] · [[s-gh-7881-cross-domain-sourcing]] ·
[[s-nats-server-leafnode-js-domains]] · [[s-docs-mirrors-and-sources]] · [[s-docs-mirrors-as-dr]] ·
[[s-gh-5606-cross-account-jetstream]] · [[s-docs-cross-account]] ·
[[s-gh-7438-multi-region-availability]] ·
[[s-adr-59-sourcing-and-mirroring]]

## To verify

- **Section 3 has no worked example anywhere public.** The export and import declarations that make a
  cross-account, cross-domain source work are **not stated by any source in `raw/`** — the field
  semantics, the required export types and the error string are, but the account block that
  implements them is not. This page deliberately stops at "point `external` at your local import
  prefix" rather than invent the account config. gh#7881 has been open since 2026-02-26 asking for
  exactly that.
- Whether the delivery prefix may be omitted in the **cross-account** case is unverified. The CLI
  marks it required; the server only validates it when present (`stream.go:2073–2091`). The two do
  not obviously agree.
- The `Consumer` (`StreamConsumerSource`) branch — sourcing through a **named durable** with an
  explicit deliver subject — is in the CLI and the server struct and is **not covered here**. No
  source in `raw/` explains when to use it.
