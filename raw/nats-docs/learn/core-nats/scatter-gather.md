<!-- source: https://docs.nats.io/learn/core-nats/scatter-gather.md · fetched 2026-08-31 · section: scatter-gather -->
# Scatter-gather

The inventory service answered one request with one reply, which is the common case of a single question producing a single answer.

Some questions have several answers. "What would it cost to ship this order?" is one of them. Acme works with three carriers, and each one quotes a different price. The order service wants all three quotes, then picks the cheapest.

That's **scatter-gather**: fan one request out to every responder, then gather the replies that come back. This page builds it on `shipping.quote` with three quote providers.

**Message flow — Request / Reply — scatter-gather:** Request to multiple services - all respond (scatter-gather pattern)

* Client → NATS (subject: get.status)
* NATS → Service A
* NATS → Service B
* NATS → Service C
* Service A → NATS
* Service B → NATS
* Service C → NATS
* NATS → Client (subject: 3 replies)

## Why one request can produce many replies

Recall how request-reply works: the client subscribes to a unique `_INBOX` subject and publishes the request carrying that inbox as its reply subject. Nothing in that mechanism limits the number of responders. If three providers subscribe to `shipping.quote`, all three receive the request (plain publish-subscribe) and all three can reply to the inbox. The single reply you saw earlier was just one responder plus a client that stopped after the first answer.

This works only when the responders are not in a queue group — a queue group hands each request to one member, which is load balancing, not scatter-gather. Every responder must subscribe plainly. The CLI demo below makes that explicit, because the CLI's default does the opposite.

## Set up three quote providers

A provider subscribes to `shipping.quote`, reads the order, and replies with a price. Run three of them, each quoting a different number.

#### CLI

```
#!/bin/bash

# Three shipping-quote providers, each answering on shipping.quote.

#

# IMPORTANT: `nats reply` subscribes inside a queue group by default

# (NATS-RPLY-22). Three providers left on that default would share ONE

# queue group, so only one would ever answer. To scatter the request to

# all three, give each provider its OWN queue group name with --queue.

# A queue group of one member behaves like a plain subscriber.

#

# Run each line in its own terminal.



# Terminal 1 — carrier A quotes 1500 cents.

nats reply shipping.quote --queue carrier-a '{"carrier":"carrier-a","quote_cents":1500}'



# Terminal 2 — carrier B quotes 1200 cents.

nats reply shipping.quote --queue carrier-b '{"carrier":"carrier-b","quote_cents":1200}'



# Terminal 3 — carrier C quotes 1800 cents.

nats reply shipping.quote --queue carrier-c '{"carrier":"carrier-c","quote_cents":1800}'
```

#### JavaScript/TypeScript

```
// A shipping-quote provider. Subscribe plainly to shipping.quote (NOT in a

// queue group, so every provider sees each request) and reply with a price.

// Run several copies, each quoting a different number.

const sub = nc.subscribe("shipping.quote");

for await (const msg of sub) {

  msg.respond('{"carrier":"carrier-a","quote_cents":1500}');

}
```

#### Go

```
// A shipping-quote provider. Subscribe plainly to shipping.quote (NOT a

// queue group, so every provider sees each request) and reply with a price.

// Run several copies, each quoting a different number.

nc.Subscribe("shipping.quote", func(m *nats.Msg) {

	m.Respond([]byte(`{"carrier":"carrier-a","quote_cents":1500}`))

})
```

#### Python

```
# A shipping-quote provider. Subscribe plainly to shipping.quote (NOT in a

# queue group, so every provider sees each request) and reply with a price.

# Run several copies, each quoting a different number.

async with await client.subscribe("shipping.quote") as subscription:

    async for message in subscription:

        if message.reply:

            await client.publish(message.reply, b'{"carrier":"carrier-a","quote_cents":1500}')
```

#### Java

```
// A shipping-quote provider. Subscribe plainly to shipping.quote (NOT in a

// queue group, so every provider sees each request) and reply with a price.

// Run several copies, each quoting a different number.

nc.createDispatcher(msg -> {

    if (msg.getReplyTo() != null) {

        nc.publish(msg.getReplyTo(),

            "{\"carrier\":\"carrier-a\",\"quote_cents\":1500}".getBytes(StandardCharsets.UTF_8));

    }

}).subscribe("shipping.quote");
```

#### Rust

```
// A shipping-quote provider. Subscribe plainly to shipping.quote (NOT in a

// queue group, so every provider sees each request) and reply with a price.

// Run several copies, each quoting a different number.

let mut sub = client.subscribe("shipping.quote").await?;

while let Some(msg) = sub.next().await {

    if let Some(reply) = msg.reply {

        client

            .publish(

                reply,

                r#"{"carrier":"carrier-a","quote_cents":1500}"#.into(),

            )

            .await?;

    }

}
```

#### C#/.NET

```
// A shipping-quote provider. Subscribe plainly to shipping.quote (NOT in a

// queue group, so every provider sees each request) and reply with a price.

// Run several copies, each quoting a different number.

await foreach (var msg in client.SubscribeAsync<Order>("shipping.quote"))

{

    await msg.ReplyAsync(new ShippingQuote(Carrier: "carrier-a", QuoteCents: 1500));

}
```

#### C

```
// A shipping-quote provider. Subscribe plainly to shipping.quote (NOT a

// queue group, so every provider sees each request) and reply with a

// price. Run several copies, each quoting a different number.

static void

onQuote(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    if (natsMsg_GetReply(msg) != NULL)

        natsConnection_PublishString(nc, natsMsg_GetReply(msg),

                                     "{\"carrier\":\"carrier-a\",\"quote_cents\":1500}");



    natsMsg_Destroy(msg);

}

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&sub, conn, "shipping.quote",

                                     onQuote, NULL);
```

There's one trap to know about with `nats reply`. By default, the CLI subscribes inside a queue group named `NATS-RPLY-22`. Three `nats reply` instances left on that default would form one queue group, and only one of them would ever answer. That's the load-balancing behavior from the previous page, not what we want here.

To make each provider an independent responder, give each one its own queue group name with `--queue`. A queue group of one member behaves like a plain subscriber: it receives every matching request. The CLI source for the snippet above runs the three providers with distinct names (`carrier-a`, `carrier-b`, `carrier-c`), so all three see each request.

The client library form has no such trap. A library subscribes plainly unless you ask for a queue group, so three plain subscribers on `shipping.quote` already scatter correctly.

## Gather by count

Now the gather side. The client sends one request to `shipping.quote` and collects replies until it's heard from every provider.

#### CLI

```
#!/bin/bash

# Send one request to shipping.quote and gather replies from every provider.



# Gather by count: stop after 3 replies have arrived.

nats request shipping.quote \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}' \

  --replies 3 --timeout 2s



# Gather by deadline instead: --replies 0 collects every reply that arrives

# during the full --timeout window, then returns. It is a fixed, predictable

# budget; --reply-timeout has no effect in this mode. Use this when you do

# not know how many providers are running.

nats request shipping.quote \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}' \

  --replies 0 --timeout 2s
```

#### JavaScript/TypeScript

```
// Scatter one request to every shipping-quote provider and gather the replies.

// Subscribe to a private inbox, publish the request with that inbox as the

// reply subject, then collect quotes until they stop arriving and pick the

// cheapest.

const order =

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}';

const inbox = createInbox();

const sub = nc.subscribe(inbox);

nc.publish("shipping.quote", order, { reply: inbox });



const quotes: string[] = [];

const gather = (async () => {

  for await (const msg of sub) {

    quotes.push(msg.string());

  }

})();



// Stop once no further reply is expected.

setTimeout(() => sub.unsubscribe(), 300);

await gather;



console.log(`gathered ${quotes.length} quotes: ${JSON.stringify(quotes)}`);
```

#### Go

```
// Scatter one request to every shipping-quote provider and gather the

// replies. Subscribe to a private inbox, publish the request with that

// inbox as the reply subject, then collect quotes until they stop arriving

// and pick the cheapest.

order := `{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}`

inbox := nats.NewInbox()

sub, _ := nc.SubscribeSync(inbox)

nc.PublishRequest("shipping.quote", inbox, []byte(order))



var quotes []string

for {

	msg, err := sub.NextMsg(300 * time.Millisecond)

	if err != nil {

		break

	}

	quotes = append(quotes, string(msg.Data))

}

fmt.Printf("gathered %d quotes: %v\n", len(quotes), quotes)
```

#### Python

```
# Scatter one request to every shipping-quote provider and gather the

# replies. Subscribe to a private inbox, publish the request with that inbox

# as the reply subject, then collect quotes until they stop arriving and

# pick the cheapest.

order = '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

inbox = f"_INBOX.{uuid.uuid4().hex}"

async with await client.subscribe(inbox) as subscription:

    await client.publish("shipping.quote", order.encode(), reply=inbox)



    quotes = []

    while True:

        try:

            message = await subscription.next(timeout=0.3)

            quotes.append(message.data.decode())

        except TimeoutError:

            break



print(f"gathered {len(quotes)} quotes: {quotes}")
```

#### Java

```
// Scatter one request to every shipping-quote provider and gather the

// replies. Subscribe to a private inbox, publish the request with that

// inbox as the reply subject, then collect quotes until they stop arriving

// and pick the cheapest.

byte[] order = ("{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

    + "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}").getBytes(StandardCharsets.UTF_8);

String inbox = nc.createInbox();

Subscription sub = nc.subscribe(inbox);

nc.publish("shipping.quote", inbox, order);



List<String> quotes = new ArrayList<>();

Message m = sub.nextMessage(Duration.ofMillis(300));

while (m != null) {

    quotes.add(new String(m.getData(), StandardCharsets.UTF_8));

    m = sub.nextMessage(Duration.ofMillis(300));

}

System.out.println("gathered " + quotes.size() + " quotes");
```

#### Rust

```
// Scatter one request to every shipping-quote provider and gather the

// replies. Subscribe to a private inbox, publish the request with that inbox

// as the reply subject, then collect quotes until they stop arriving and

// pick the cheapest.

let order = r#"{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}"#;

let inbox = client.new_inbox();

let mut sub = client.subscribe(inbox.clone()).await?;

client

    .publish_with_reply("shipping.quote", inbox, order.into())

    .await?;

client.flush().await?;



let mut quotes = Vec::new();

while let Ok(Some(msg)) = tokio::time::timeout(Duration::from_millis(300), sub.next()).await {

    quotes.push(String::from_utf8_lossy(&msg.payload).to_string());

}



println!("gathered {} quotes: {:?}", quotes.len(), quotes);
```

#### C#/.NET

```
// Scatter one request to every shipping-quote provider and gather the

// replies. Subscribe to a private inbox, publish the request with that inbox

// as the reply subject, then collect quotes until they stop arriving and

// pick the cheapest.

var order = new Order(OrderId: "ord_8w2k", Customer: "acme-co", TotalCents: 4200, Timestamp: DateTimeOffset.Parse("2026-05-22T10:14:22Z", CultureInfo.InvariantCulture));

var inbox = client.Connection.NewInbox();

await using var sub = await client.Connection.SubscribeCoreAsync<ShippingQuote>(inbox);

await client.PublishAsync<Order>("shipping.quote", order, replyTo: inbox);



var quotes = new List<ShippingQuote>();

using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(300));

try

{

    await foreach (var msg in sub.Msgs.ReadAllAsync(cts.Token))

    {

        quotes.Add(msg.Data!);

    }

}

catch (OperationCanceledException)

{

}



output.WriteLine($"gathered {quotes.Count} quotes");
```

#### C

```
// Scatter one request to every shipping-quote provider and gather the

// replies. Subscribe to a private inbox, publish the request with that

// inbox as the reply subject, then collect quotes until they stop

// arriving and pick the cheapest.

const char *order = "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

                    "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}";

int        quotes = 0;



if (s == NATS_OK)

    s = natsInbox_Create(&inbox);

if (s == NATS_OK)

    s = natsConnection_SubscribeSync(&sub, conn, (const char *) inbox);

if (s == NATS_OK)

    s = natsConnection_PublishRequestString(conn, "shipping.quote",

                                            (const char *) inbox, order);



while (s == NATS_OK)

{

    natsMsg *quote = NULL;



    // Stop once no further quote arrives within the gap deadline.

    s = natsSubscription_NextMsg(&quote, sub, 300);

    if (s != NATS_OK)

        break;



    printf("quote: %.*s\n",

           natsMsg_GetDataLength(quote), natsMsg_GetData(quote));

    quotes++;

    natsMsg_Destroy(quote);

}

printf("gathered %d quotes\n", quotes);
```

The CLI uses `--replies 3`: read from the inbox until three replies arrive, then stop — or until replies stop arriving, whichever comes first. With the three providers running, the output shows three quotes, one per carrier. The client compares the prices and keeps the lowest.

A library does the same thing, and how much you hand-roll depends on the client. A plain `request()` returns only the first reply — on its own it never returns a list, because the client can't know how many responders exist. Some clients ship a gather helper that returns many: nats.js has `requestMany` and orbit.go has `RequestMany` (both follow ADR-47, "Request Many", with count, stall, and sentinel stop conditions), and the .NET client has `RequestManyAsync`. Where no helper exists, you build the loop yourself: subscribe to a fresh inbox, publish the request with that inbox as the reply subject, then read from the subscription and append each reply to a list until your count or deadline is reached, then unsubscribe.

## Gather by deadline

Counting replies assumes you know how many providers there are. Often you don't. Carriers come and go; one might be down. Write that gather yourself with no read deadline, and waiting for a fixed count of three blocks forever if only two answer — the read for the third reply never returns.

The safer approach gathers by **deadline** instead. Collect every reply that arrives within a time budget, then act on whatever you have.

From the CLI, `--replies 0` switches to deadline mode: `--timeout` becomes the whole collection window. The command reads replies for the full window and returns when it closes, so `--replies 0 --timeout 2s` gathers everything that arrives in those two seconds. It's a fixed, predictable budget, and `--reply-timeout` has no effect in this mode — it only bounds the gap between replies when you gather by count.

```
nats request shipping.quote \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}' \

  --replies 0 --timeout 2s
```

With three providers up, all three quotes arrive within milliseconds, but the command still holds open for the full two seconds before returning the set. With one provider down, you get the two quotes that answered and wait out the same two-second window. If no provider is subscribed at all, the command returns right away with a no responders signal instead of waiting — though a provider that's subscribed but slow to answer still costs the full `--timeout`. Either way the wait is bounded; it never blocks forever.

A deadline changes the rule from waiting for every responder to waiting only for whoever answers in time, which is the only safe assumption when the responder set isn't fixed.

There's a third way to end a gather: a **sentinel**. With `--wait-for-empty`, the command keeps collecting until a reply arrives with an empty payload, which a responder sends to mark the end of the set. This counts replies rather than watching a single deadline, so if the sentinel never comes the `--reply-timeout` bounds the gap between replies and the wait still ends.

## Delivery guarantees

Scatter-gather is [at-most-once](/learn/core-nats/publish-subscribe.md#at-most-once-delivery) like everything else: a reply dropped in transit is just absent from the gathered set, nothing redelivers it, and arrival order carries no meaning. Treat the set as whatever answers happened to arrive, not a ranked list. That's fine for a shipping quote — re-asking is cheap. When each reply must survive a crash, that's [JetStream](/learn/jetstream/.md), not a core gather.

## Pitfalls

**Taking only the first reply.** A plain `nats request` stops after one reply, because its `--replies` flag defaults to `1`. Point it at three providers and you get whichever carrier answered first; the other two quotes are discarded and you never learn there were more. A plain `request()` in a client library does the same. When you mean to gather, use `--replies 0` from the CLI, reach for your client's gather helper where it has one (nats.js `requestMany`, orbit.go `RequestMany`), or subscribe to the inbox yourself and read in a loop.

#### CLI

```
#!/bin/bash

# The "first reply only" trap, and the fix.

#

# `nats request` defaults to --replies 1: it reads ONE reply and stops.

# With three providers up, you get whichever carrier answered first and

# the other two quotes are silently discarded. That is a single request,

# not a scatter-gather.



# WRONG for scatter-gather — takes only the first quote that lands.

nats request shipping.quote \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'



# RIGHT — gather every quote, then pick the cheapest. --replies 0 collects

# every reply that arrives during the full --timeout window, then returns —

# a fixed, predictable budget. If a carrier is down, its quote is simply

# absent from the set; --reply-timeout has no effect in this mode.

nats request shipping.quote \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}' \

  --replies 0 --timeout 2s
```

#### C

```
// The "first reply only" trap: a plain request reads ONE reply and

// stops. With three providers up, you get whichever carrier answered

// first and the other two quotes are silently discarded.

const char *order = "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

                    "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}";

natsMsg    *first = NULL;



if (s == NATS_OK)

    s = natsConnection_RequestString(&first, conn, "shipping.quote",

                                     order, 2000);

if (s == NATS_OK)

{

    printf("first quote only: %.*s\n",

           natsMsg_GetDataLength(first), natsMsg_GetData(first));

    natsMsg_Destroy(first);

}



// The fix: gather every quote yourself. Subscribe to a private inbox,

// publish the request with that inbox as the reply subject, and read

// replies until they stop arriving.

int quotes = 0;



if (s == NATS_OK)

    s = natsInbox_Create(&inbox);

if (s == NATS_OK)

    s = natsConnection_SubscribeSync(&sub, conn, (const char *) inbox);

if (s == NATS_OK)

    s = natsConnection_PublishRequestString(conn, "shipping.quote",

                                            (const char *) inbox, order);



while (s == NATS_OK)

{

    natsMsg *quote = NULL;



    s = natsSubscription_NextMsg(&quote, sub, 300);

    if (s != NATS_OK)

        break;



    printf("quote: %.*s\n",

           natsMsg_GetDataLength(quote), natsMsg_GetData(quote));

    quotes++;

    natsMsg_Destroy(quote);

}

printf("gathered %d quotes\n", quotes);
```

**No deadline, so you wait for replies that never come.** A hand-rolled gather that reads with no deadline blocks forever if a provider is down — the read for the missing reply never returns. Bound the wait: gather by deadline (`--replies 0 --timeout 2s`) so a missing carrier just leaves its quote out of the set.

**Reading the gathered set as ranked.** Arrival order isn't priority and a short set isn't an error. Compare every reply on its merits (here, the lowest `quote_cents`).

## Where you are

The Acme ORDERS world now talks in four shapes over one local `nats-server`:

* `notifications` and `analytics` each receive their own copy of every `orders.created` message (publish-subscribe).
* Regional analytics spans `orders.us.created` and `orders.eu.created` with `orders.*.created`, and an audit service reads the whole hierarchy on `orders.>`.
* The `inventory` service answers single requests on `orders.inventory.check` (request-reply).
* A `packers` queue group shares the work on `orders.created`, one packer per order.
* Three providers answer one `shipping.quote` request, and the client gathers every reply within a deadline and picks the cheapest.

That's the whole of core NATS: subjects, interest, reply inboxes, and queue groups. Everything is ephemeral and at-most-once, and nothing is remembered after it's delivered.

## What's next

The next page adds a third piece to every message, beside its subject and payload: headers, a set of key/value metadata. You'll put a request id and a trace id on the orders flow and read the status header the server uses to signal no responders. Continue to [Message headers](/learn/core-nats/headers.md).

## See also

* [Concepts → Request-reply](/concepts/request-reply.md) — the five-minute overview of the pattern this page extends.
* [Learn → Services](/learn/services/.md) — when many responders become a managed service that aggregates results for you.
* [Reference](/reference/.md) — gather helper signatures per client library.
