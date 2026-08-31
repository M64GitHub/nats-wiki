<!-- source: https://docs.nats.io/learn/core-nats/subjects-and-wildcards.md · fetched 2026-08-31 · section: subjects-and-wildcards -->
# Subjects & wildcards

On the previous page Acme published `orders.created` and three services subscribed to it. That subject was a flat name. This page gives the subject some structure and lets a subscriber match a whole family of them at once.

Acme is opening regional fulfillment. Orders no longer all look the same: a US order and an EU order need to land somewhere a regional service can tell them apart. The subject is where that distinction lives.

## A subject is a sequence of tokens

A **subject** is a string the server uses to match publishers to subscribers. You already used one: `orders.created`.

The `.` (dot) splits the subject into **tokens**. `orders.created` is two tokens, `orders` then `created`. The server treats each token as a separate unit when it matches.

That splitting turns a flat name into a hierarchy. Acme can put the region in the middle:

```
orders.us.created

orders.eu.created

orders.us.canceled

orders.eu.canceled
```

Each of those is three tokens. The first token groups them all under `orders`. The second token says which region. The third says what happened. The server isn't configured to know "region" means anything; the meaning lives entirely in the names Acme chose.

A few rules govern what a token may contain.

Subjects are **case-sensitive**. `Orders.created` and `orders.created` are two different subjects. A publisher to one won't reach a subscriber on the other.

Tokens are split by single dots only. Spaces, tabs, and line breaks aren't allowed anywhere in a subject. Stick to letters, digits, `-`, and `_` inside a token and you'll never be surprised.

## Subjects cost almost nothing to create

Acme just invented four new subjects without telling the server first — that's allowed, and it costs almost nothing. The interest graph from the previous page holds an entry for a subject only once something subscribes to it, so a subject nobody listens to has no presence on the server at all. You never declare or clean up subjects, and a system can use millions of them without slowing the server down, because matching walks the token tree rather than scanning every subscription.

## Wildcards: subscribe to many subjects at once

A publisher always names one full subject. `nats pub` to `orders.*.created` isn't "publish to every region": it would publish to the literal subject containing a `*`, which nobody wants. Wildcards are a **subscriber-only** tool.

A **wildcard** is a token in a subscription that matches more than one literal subject. NATS has exactly two of them, and they differ in how many tokens they match.

**Message flow — Subject wildcards (animated):** Animated subject wildcards: messages on different subjects (orders.us.created, orders.eu.created, …) are routed by matching wildcard subscriptions.

* Publisher 1 → NATS (subject: orders.retail.placed)
* Publisher 2 → NATS (subject: orders.retail.shipped)
* Publisher 3 → NATS (subject: orders.wholesale.placed)
* NATS → Subscriber (subject: orders.retail.\*)
* NATS → Subscriber

### The single-token wildcard `*`

The **single-token wildcard** `*` matches exactly one token — not zero, not two.

Acme wants one analytics view of created orders across every region. Instead of subscribing to `orders.us.created` and `orders.eu.created` separately, it subscribes once to `orders.*.created`:

#### CLI

```
#!/bin/bash



# Regional analytics: catch created orders from every region with one

# subscription. The single-token wildcard * matches exactly one token in

# the region position, so orders.us.created and orders.eu.created both

# match, while orders.created and orders.us.west.created do not.

nats sub "orders.*.created"
```

#### JavaScript/TypeScript

```
// Regional analytics: one subscription catches created orders from every

// region. The single-token wildcard * matches exactly one token, so both

// orders.us.created and orders.eu.created match, while orders.created and

// orders.us.west.created do not.

const sub = nc.subscribe("orders.*.created");

for await (const msg of sub) {

  console.log(`analytics: new order on ${msg.subject}`);

}
```

#### Go

```
// Regional analytics: one subscription catches created orders from every

// region. The single-token wildcard * matches exactly one token, so

// orders.us.created and orders.eu.created both match, while orders.created

// and orders.us.west.created do not.

nc.Subscribe("orders.*.created", func(m *nats.Msg) {

	fmt.Printf("analytics: new order on %s\n", m.Subject)

})
```

#### Python

```
# Regional analytics: one subscription catches created orders from every

# region. The single-token wildcard * matches exactly one token, so both

# orders.us.created and orders.eu.created match, while orders.created and

# orders.us.west.created do not.

async with await client.subscribe("orders.*.created") as subscription:

    async for message in subscription:

        print(f"analytics: new order on {message.subject}")
```

#### Java

```
// Regional analytics: one subscription catches created orders from every

// region. The single-token wildcard * matches exactly one token, so both

// orders.us.created and orders.eu.created match, while orders.created and

// orders.us.west.created do not.

nc.createDispatcher(msg ->

    System.out.println("analytics: new order on " + msg.getSubject())

).subscribe("orders.*.created");
```

#### Rust

```
// Regional analytics: one subscription catches created orders from every

// region. The single-token wildcard * matches exactly one token, so both

// orders.us.created and orders.eu.created match, while orders.created and

// orders.us.west.created do not.

let mut sub = client.subscribe("orders.*.created").await?;

while let Some(msg) = sub.next().await {

    println!("analytics: new order on {}", msg.subject);

}
```

#### C#/.NET

```
// Regional analytics: one subscription catches created orders from every

// region. The single-token wildcard * matches exactly one token, so both

// orders.us.created and orders.eu.created match, while orders.created and

// orders.us.west.created do not.

await foreach (var msg in client.SubscribeAsync<Order>("orders.*.created"))

{

    output.WriteLine($"analytics: new order on {msg.Subject}");

}
```

#### C

```
// Regional analytics: one subscription catches created orders from every

// region. The single-token wildcard * matches exactly one token, so

// orders.us.created and orders.eu.created both match, while orders.created

// and orders.us.west.created do not.

static void

onOrder(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    printf("analytics: new order on %s\n", natsMsg_GetSubject(msg));



    natsMsg_Destroy(msg);

}

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&sub, conn, "orders.*.created",

                                     onOrder, NULL);
```

The `*` sits in the region position. Walk through what it catches:

* `orders.us.created` matches: `*` takes the single token `us`.
* `orders.eu.created` matches: `*` takes the single token `eu`.
* `orders.created` does not match: there's no token in the region position, and `*` needs exactly one.
* `orders.us.west.created` does not match: two tokens sit where `*` allows only one.

The position of `*` is fixed; the token in it is free. You can also use more than one: `orders.*.*` matches any three-token subject under `orders`, with both middle and last tokens free.

### The multi-token wildcard `>`

The **multi-token wildcard** `>` matches one or more tokens, and it must be the last token in the pattern.

Acme is adding an audit service that wants every order message, at every depth, regardless of region or action. One subscription covers it:

#### CLI

```
#!/bin/bash



# Audit service: catch every order message at any depth. The multi-token

# wildcard > matches one or more tokens and must be the last token, so

# orders.> matches orders.created, orders.us.created, and

# orders.us.west.created alike.

nats sub "orders.>"
```

#### JavaScript/TypeScript

```
// Audit service: catch every order message at any depth. The multi-token

// wildcard > matches one or more tokens and must be the last token, so

// orders.> matches orders.created, orders.us.created, and

// orders.us.west.created alike.

const sub = nc.subscribe("orders.>");

for await (const msg of sub) {

  console.log(`audit: ${msg.subject}`);

}
```

#### Go

```
// Audit service: catch every order message at any depth. The multi-token

// wildcard > matches one or more tokens and must be the last token, so

// orders.> matches orders.created, orders.us.created, and

// orders.us.west.created alike.

nc.Subscribe("orders.>", func(m *nats.Msg) {

	fmt.Printf("audit: %s\n", m.Subject)

})
```

#### Python

```
# Audit service: catch every order message at any depth. The multi-token

# wildcard > matches one or more tokens and must be the last token, so

# orders.> matches orders.created, orders.us.created, and

# orders.us.west.created alike.

async with await client.subscribe("orders.>") as subscription:

    async for message in subscription:

        print(f"audit: {message.subject}")
```

#### Java

```
// Audit service: catch every order message at any depth. The multi-token

// wildcard > matches one or more tokens and must be the last token, so

// orders.> matches orders.created, orders.us.created, and

// orders.us.west.created alike.

nc.createDispatcher(msg ->

    System.out.println("audit: " + msg.getSubject())

).subscribe("orders.>");
```

#### Rust

```
// Audit service: catch every order message at any depth. The multi-token

// wildcard > matches one or more tokens and must be the last token, so

// orders.> matches orders.created, orders.us.created, and

// orders.us.west.created alike.

let mut sub = client.subscribe("orders.>").await?;

while let Some(msg) = sub.next().await {

    println!("audit: {}", msg.subject);

}
```

#### C#/.NET

```
// Audit service: catch every order message at any depth. The multi-token

// wildcard > matches one or more tokens and must be the last token, so

// orders.> matches orders.created, orders.us.created, and

// orders.us.west.created alike.

await foreach (var msg in client.SubscribeAsync<Order>("orders.>"))

{

    output.WriteLine($"audit: {msg.Subject}");

}
```

#### C

```
// Audit service: catch every order message at any depth. The multi-token

// wildcard > matches one or more tokens and must be the last token, so

// orders.> matches orders.created, orders.us.created, and

// orders.us.west.created alike.

static void

onOrder(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    printf("audit: %s\n", natsMsg_GetSubject(msg));



    natsMsg_Destroy(msg);

}

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&sub, conn, "orders.>", onOrder, NULL);
```

`orders.>` reaches the entire hierarchy under `orders`:

* `orders.created` matches: `>` takes the one token `created`.
* `orders.us.created` matches: `>` takes the two tokens `us.created`.
* `orders.us.west.created` matches: `>` takes all three remaining tokens.
* `orders` does not match: `>` needs at least one token after the prefix.

Because `>` matches a token *and everything after it*, it only makes sense at the end. `orders.>.created` is invalid: the server rejects the subscription with an Invalid Subject error. There's no way to anchor a tail wildcard in the middle and still know where it stops.

This is the difference to keep: `*` is a placeholder for one token in a known shape; `>` is "everything from here down."

## A wildcard subscriber behaves like any subscriber

A wildcard doesn't change the delivery model from the last page. It changes which subjects count as a match, nothing else.

The audit service on `orders.>` is just another interested subscriber. When Acme publishes `orders.us.created`, every matching subscriber gets its own copy: the warehouse on `orders.created` does *not* (different subject now), the regional analytics on `orders.*.created` does, and the audit service on `orders.>` does. The server fans one publish out to all of them. Delivery is still [at-most-once](/learn/core-nats/publish-subscribe.md#at-most-once-delivery): a wildcard lets a service that joins now see everything published *from now on*, not what it missed before joining. Capturing that backlog is what [JetStream](/learn/jetstream/.md) adds.

## Reserved prefixes to avoid

Acme can name subjects almost anything, but two prefixes are reserved.

Subjects beginning with `$` belong to the server and its subsystems: `$SYS` for system events, and `$JS`, `$KV`, `$O`, and `$SRV` for the JetStream, Key-Value, Object-Store, and Services subsystems. Don't publish application messages under `$`.

The `_INBOX` prefix is reserved for reply subjects that clients generate automatically. You don't pick `_INBOX` names yourself, and you don't publish business messages there. The next page, on request-reply, shows exactly what `_INBOX` is for.

## Try it in two terminals

With `nats-server` running, watch a wildcard catch messages it was never told about by name:

```
# Terminal 1 — the audit service: every order message, any depth

nats sub "orders.>"
```

```
# Terminal 2 — publish to two regions and a flat subject

nats pub orders.us.created '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

nats pub orders.eu.created '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

nats pub orders.shipped    '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'
```

All three arrive in Terminal 1. Now restart Terminal 1 with `nats sub "orders.*.created"` and re-run Terminal 2: only the two `*.created` messages arrive; `orders.shipped` no longer matches.

## Pitfalls

**`>` only works as the last token.** Use `*` for a free token in the middle: subscribe to `orders.*.created`, not the invalid `orders.>.created`, which the server rejects.

**Publishers can't publish "to a wildcard."** Wildcards are a subscriber-only tool. A publisher always names one fully-qualified subject. The trap is that publishing to `orders.*.created` doesn't produce an error: the `*` is taken as a literal character, so the message lands on the odd literal subject `orders.*.created`. A service subscribed to the exact subject `orders.us.created` never sees it, while wildcard subscribers like the regional analytics on `orders.*.created` and the audit service on `orders.>` do get it — a subscription's `*` matches any single token, including a literal `*` — which makes the mistake confusing to debug. Publish the real subject (`orders.us.created`); reserve `*` and `>` for `nats sub` and the subscribe call in your client.

**An over-broad `orders.>` pulls more than you want.** It's tempting to subscribe to `orders.>` and filter in code, but that subscriber then receives *every* order message at every depth, for all regions and actions, including subjects created later. Subscribe to the narrowest pattern that covers your need: `orders.*.created` for regional new-order analytics, the exact subject for a single concern. Narrow interest keeps unwanted traffic off the wire entirely, rather than having your code discard it after delivery.

**Whitespace is never allowed in a subject.** A token can't contain a space, tab, or line break: on the wire, a space separates the subject from the reply subject and byte count, so a space inside a subject would be read as a boundary. The CLI and most clients catch this before sending — publishing to `orders.us created` fails with `nats: invalid subject`, and nothing is sent. A client that skips the check (nats.py's `publish` does) writes the space straight into the `PUB` line, and the server silently misroutes: `orders.us` becomes the subject and `created` a reply subject. Don't rely on the check; keep spaces out of the subject:

#### CLI

```
#!/bin/bash



# A subject token can't contain whitespace. On the wire, a space separates the

# subject from the reply subject and byte count, so a modern client rejects the

# subject before anything is sent. This publish therefore FAILS with

#   nats: error: nats: invalid subject

# and exits non-zero -- the message never reaches the server.

nats pub "orders.us created" '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'



# (An older client -- nats.go before v1.48.0 -- or a raw-protocol writer skips

# this check and would instead misroute silently: the server would read

# "orders.us" as the subject and "created" as a reply subject.)



# The fix is one token per dot, no spaces: orders.us.created

nats pub "orders.us.created" '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'
```

#### C

```
// A subject token can't contain whitespace: on the wire, a space

// separates the subject from the reply subject and byte count. The C

// client's publish skips the check, so this call does NOT fail: the

// space goes straight into the PUB line and the server silently

// misroutes: "orders.us" becomes the subject and "created" a reply

// subject. Nobody subscribed to orders.us.created ever sees it.

const char *order = "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

                    "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}";



s = natsConnection_PublishString(conn, "orders.us created", order);

printf("publish with a space returned: %s\n", natsStatus_GetText(s));



// Don't rely on a client-side check; keep spaces out of the subject.

// The fix is one token per dot: orders.us.created.

if (s == NATS_OK)

    s = natsConnection_PublishString(conn, "orders.us.created", order);
```

## Where you are

Acme's order traffic now has a shape:

* Orders publish to structured subjects: `orders.created`, `orders.us.created`, `orders.eu.created`, and so on.
* Regional analytics subscribes to `orders.*.created` to catch every region's new orders with one subscription.
* An audit service subscribes to `orders.>` to catch the whole hierarchy.

Subjects address messages; wildcards let one subscriber match a family of them. That's the addressing layer everything else in core NATS uses.

## What's next

So far every message flows one way: a publisher sends, subscribers receive, and nobody sends a reply back. The next page, [Request-reply](/learn/core-nats/request-reply.md), adds a reply path: Acme builds an inventory service that *answers* a question on `orders.inventory.check`, using a reserved `_INBOX` subject you just met.

## See also

* [Core Concepts → Subjects](/concepts/subjects.md) — the short overview of tokens and wildcards.
* [Learn → Security](/learn/security/.md) — granting or denying access per subject and wildcard.
* [Learn → Super-clusters](/learn/topologies/super-clusters.md) — how subject interest propagates across servers and regions.
