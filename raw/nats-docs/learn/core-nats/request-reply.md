<!-- source: https://docs.nats.io/learn/core-nats/request-reply.md · fetched 2026-08-31 · section: request-reply -->
# Request-reply

Pub/sub is one-way. A publisher publishes to `orders.created`, and a copy goes to every interested subscriber. The publisher never hears back.

Acme needs the other direction too. When an order arrives, the warehouse wants to ask one question and get one answer: *is this item in stock?* That's a request and a reply, not a broadcast.

This page builds an **inventory** service that answers that question on the subject `orders.inventory.check`. Along the way it shows the two things that make request-reply work: the private reply subject the client sets up for itself, and what happens when nobody is there to answer.

## How request-reply uses pub/sub

Request-reply isn't a new protocol; it's the pub/sub you already know, used twice.

Here are all the steps. The client invents a fresh, unique subject to receive the answer on. It subscribes to that subject. It then publishes the request, and includes that reply subject as a field on the message. The responder reads the request, sees the reply subject, and publishes its answer there. The client's subscription receives it.

**Message flow — Request / Reply:** Request-reply pattern where a client sends a request and waits for a response from a service

* Client → NATS (subject: get.user.150)
* NATS → Service (subject: get.user.150)
* Service → NATS (subject: \_INBOX.\<nuid>)
* NATS → Client (subject: \_INBOX.\<nuid>)

The orange arrow is the request traveling out on the request subject. The green dashed arrow is the reply traveling back on the private subject the client made for this one call.

Every NATS client wraps those steps in a single `request()` call, so you never write the subscribe-publish-wait by hand.

## The inbox

The private reply subject is called an **inbox**, and clients generate it under the reserved `_INBOX.` prefix: something like `_INBOX.nQ4k2v8...` with a random unique tail.

The inbox is per-request: each `request()` uses a fresh inbox, so two in-flight requests never get each other's replies. The `_INBOX.` prefix is reserved, so it never collides with the subjects you pick yourself; the client owns that namespace.

A client doesn't open a subscription for every `request()`. On its first request it subscribes once to a wildcard that stays fixed for the connection — a subject shaped like `_INBOX.<connection>.*` — and reuses that one subscription for every request after. Each request adds only its own final token to that prefix, so the per-request fresh inbox amounts to that fresh token, and the client routes each reply back to the request waiting on its token.

That's why thousands of concurrent requests cost one subscription, not thousands: every reply arrives on the same wildcard, and its final token identifies which request it belongs to. (Clients can be configured to fall back to one subscription per request; the shared one is the default.)

There's a size budget on the reply subject. The server limits the length of a single protocol line, subject plus reply subject combined, to 4 KB by default (`max_control_line`). Generated inbox names sit far under that, so this only matters if you hand-build unusually long subjects.

The default `_INBOX.` prefix is configurable per connection — a client option, exposed in natscli as the global `--inbox-prefix` flag. It exists for permissions: with a distinct prefix per application, an operator can grant each one its own reply-subject namespace instead of a shared `_INBOX.>`. Subject permissions are covered on the [Authorization](/learn/security/authorization.md) page.

## The inventory service

Now make the responder real. The inventory service subscribes to `orders.inventory.check` and replies to each request with an in-stock answer.

From the CLI, `nats reply` does exactly this: it subscribes to the subject (joining the default queue group `NATS-RPLY-22`) and publishes a reply to whatever inbox each request carries.

#### CLI

```
#!/bin/bash

# The inventory service: subscribe to orders.inventory.check and answer

# every request. `nats reply` subscribes to the subject and publishes the

# given body to whatever inbox each request carries.

#

# Leave this running in its own terminal. It answers every request with

# an in-stock reply until you stop it with Ctrl-C.

nats reply orders.inventory.check '{"in_stock":true,"warehouse":"us-east"}'
```

#### JavaScript/TypeScript

```
// The inventory service: subscribe to orders.inventory.check and answer

// every request by responding on the reply subject it carries.

const sub = nc.subscribe("orders.inventory.check");

for await (const msg of sub) {

  msg.respond('{"in_stock":true,"warehouse":"us-east"}');

}
```

#### Go

```
// The inventory service: subscribe to orders.inventory.check and answer

// every request by responding on the reply subject it carries.

nc.Subscribe("orders.inventory.check", func(m *nats.Msg) {

	m.Respond([]byte(`{"in_stock":true,"warehouse":"us-east"}`))

})
```

#### Python

```
# The inventory service: subscribe to orders.inventory.check and answer

# every request by publishing back to the reply subject each one carries.

async with await client.subscribe("orders.inventory.check") as subscription:

    async for message in subscription:

        if message.reply:

            await client.publish(message.reply, b'{"in_stock":true,"warehouse":"us-east"}')
```

#### Java

```
// The inventory service: subscribe to orders.inventory.check and answer

// every request by publishing back to the reply subject it carries.

nc.createDispatcher(msg -> {

    if (msg.getReplyTo() != null) {

        nc.publish(msg.getReplyTo(),

            "{\"in_stock\":true,\"warehouse\":\"us-east\"}".getBytes(StandardCharsets.UTF_8));

    }

}).subscribe("orders.inventory.check");
```

#### Rust

```
// The inventory service: subscribe to orders.inventory.check and answer

// every request by publishing back to the reply subject it carries.

let mut sub = client.subscribe("orders.inventory.check").await?;

while let Some(msg) = sub.next().await {

    if let Some(reply) = msg.reply {

        client

            .publish(reply, r#"{"in_stock":true,"warehouse":"us-east"}"#.into())

            .await?;

    }

}
```

#### C#/.NET

```
// The inventory service: subscribe to orders.inventory.check and answer

// every request by replying on the subject each one carries.

await foreach (var msg in client.SubscribeAsync<Order>("orders.inventory.check"))

{

    await msg.ReplyAsync(new InventoryReply(InStock: true, Warehouse: "us-east"));

}
```

#### C

```
// The inventory service: subscribe to orders.inventory.check and answer

// every request by publishing a reply on the reply subject it carries.

static void

onCheck(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    if (natsMsg_GetReply(msg) != NULL)

        natsConnection_PublishString(nc, natsMsg_GetReply(msg),

                                     "{\"in_stock\":true,\"warehouse\":\"us-east\"}");



    natsMsg_Destroy(msg);

}

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&sub, conn, "orders.inventory.check",

                                     onCheck, NULL);
```

Leave that running. It's now the one service in the Acme world that answers questions instead of just receiving messages. The warehouse, notifications, and analytics subscribers from the earlier pages keep running unchanged, and request-reply runs alongside them.

## Sending a request

In a second terminal, ask the question. The warehouse sends the order payload to `orders.inventory.check` and waits for the inventory service to answer.

#### CLI

```
#!/bin/bash

# Ask the inventory service whether an order's item is in stock.

# `nats request` creates a private inbox, subscribes to it, publishes the

# order payload to orders.inventory.check with the inbox attached, and

# prints the first reply it receives.

#

# --timeout bounds the wait: it is the longest the client waits for an answer

# before giving up. The CLI defaults it to 5s; here we set 2s. If no service is

# subscribed, the server sends a "no responders" signal immediately and the CLI

# logs "No responders are available" instead of waiting out the timeout.

nats request orders.inventory.check \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}' \

  --timeout 2s
```

#### JavaScript/TypeScript

```
// Ask the inventory service whether an order's item is in stock. The client

// creates a private inbox, sends the request, and waits up to the timeout for

// one reply. A missing service surfaces immediately as NoRespondersError; a

// slow one as TimeoutError.

const order =

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}';

try {

  const reply = await nc.request("orders.inventory.check", order, {

    timeout: 2000,

  });

  console.log(`inventory replied: ${reply.string()}`);

} catch (err) {

  if (err instanceof RequestError && err.isNoResponders()) {

    console.log("no inventory service is running");

  } else if (err instanceof TimeoutError) {

    console.log("inventory service did not answer in time");

  } else {

    throw err;

  }

}
```

#### Go

```
// Ask the inventory service whether an order's item is in stock. The client

// creates a private inbox, sends the request, and waits up to the timeout

// for one reply. A missing service surfaces immediately as

// nats.ErrNoResponders; a slow one as nats.ErrTimeout.

order := `{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}`

msg, err := nc.Request("orders.inventory.check", []byte(order), 2*time.Second)

switch err {

case nats.ErrNoResponders:

	fmt.Println("no inventory service is running")

case nats.ErrTimeout:

	fmt.Println("inventory service did not answer in time")

case nil:

	fmt.Printf("inventory replied: %s\n", string(msg.Data))

default:

	fmt.Printf("request failed: %v\n", err)

}
```

#### Python

```
# Ask the inventory service whether an order's item is in stock. The client

# creates a private inbox, sends the request, and waits up to the timeout

# for one reply. A missing service surfaces immediately as

# NoRespondersError; a slow one surfaces as TimeoutError.

order = '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

try:

    reply = await client.request("orders.inventory.check", order.encode(), timeout=2.0)

    print(f"inventory replied: {reply.data.decode()}")

except NoRespondersError:

    print("no inventory service is running")

except TimeoutError:

    print("inventory service did not answer in time")
```

#### Java

```
// Ask the inventory service whether an order's item is in stock. A missing

// service surfaces immediately as a canceled request; a slow one as a

// timeout.

byte[] order = ("{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

    + "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}").getBytes(StandardCharsets.UTF_8);

CompletableFuture<Message> future = nc.request("orders.inventory.check", order);

try {

    Message reply = future.get(2, TimeUnit.SECONDS);

    System.out.println("inventory replied: " + new String(reply.getData(), StandardCharsets.UTF_8));

}

catch (TimeoutException e) {

    System.out.println("inventory service did not answer in time");

}

catch (ExecutionException e) {

    // reportNoResponders() surfaces a missing service as a 503 status

    if (e.getCause() instanceof JetStreamStatusException) {

        System.out.println("no inventory service is running");

    }

    else {

        System.out.println("request failed: " + e.getMessage());

    }

}
```

#### Rust

```
// Ask the inventory service whether an order's item is in stock. The client

// creates a private inbox, sends the request, and waits for one reply. A

// missing service surfaces as NoResponders; a slow one as TimedOut.

let order = r#"{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}"#;

match client.request("orders.inventory.check", order.into()).await {

    Ok(response) => {

        println!(

            "inventory replied: {}",

            String::from_utf8_lossy(&response.payload)

        );

    }

    Err(err) => match err.kind() {

        RequestErrorKind::NoResponders => println!("no inventory service is running"),

        RequestErrorKind::TimedOut => println!("inventory service did not answer in time"),

        _ => eprintln!("request failed: {}", err),

    },

}
```

#### C#/.NET

```
// Ask the inventory service whether an order's item is in stock. The client

// creates a private inbox, sends the request, and waits for one reply.

// RequestAsync throws NatsNoRespondersException immediately when nothing is

// subscribed on the subject.

var order = new Order(OrderId: "ord_8w2k", Customer: "acme-co", TotalCents: 4200, Timestamp: DateTimeOffset.Parse("2026-05-22T10:14:22Z", CultureInfo.InvariantCulture));

try

{

    var reply = await client.RequestAsync<Order, InventoryReply>("orders.inventory.check", order);

    output.WriteLine($"inventory replied: {reply.Data}");

}

catch (NatsNoRespondersException)

{

    output.WriteLine("no inventory service is running");

}
```

#### C

```
// Ask the inventory service whether an order's item is in stock. The

// client creates a private inbox, sends the request, and waits up to

// the timeout for one reply. A missing service surfaces immediately as

// NATS_NO_RESPONDERS; a slow one as NATS_TIMEOUT.

const char *order = "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

                    "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}";

natsMsg    *reply = NULL;



s = natsConnection_RequestString(&reply, conn, "orders.inventory.check",

                                 order, 2000);

switch (s)

{

    case NATS_NO_RESPONDERS:

        printf("no inventory service is running\n");

        break;

    case NATS_TIMEOUT:

        printf("inventory service did not answer in time\n");

        break;

    case NATS_OK:

        printf("inventory replied: %.*s\n",

               natsMsg_GetDataLength(reply), natsMsg_GetData(reply));

        natsMsg_Destroy(reply);

        break;

    default:

        printf("request failed: %s\n", natsStatus_GetText(s));

        break;

}
```

You should see the reply printed back. Behind that one line, the client picked a fresh inbox subject, published your payload with the inbox attached, and matched the answer back to this call by its token on the subscription it already holds for its inbox prefix.

## Every request needs a timeout

A request can fail to come back — the responder might be slow or busy, or the reply lost in flight. Replies are [at-most-once](/learn/core-nats/publish-subscribe.md#at-most-once-delivery) like everything else: one that doesn't arrive is gone, not retried.

So every request carries a **timeout**: the longest the client will wait for the answer before giving up. The CLI sets `--timeout` for you (five seconds by default), and the request snippet above makes it explicit with `--timeout 2s`. Pick a value that covers the responder's work plus the network round-trip. In a client library you pass the timeout on every `request()` call, so a request can't wait indefinitely.

When the timeout expires with no reply, the call returns a timeout error. Your code decides what to do next: retry, fall back, or fail the caller. Core NATS won't make that decision for you, and it won't deliver the answer late.

A timeout tells you the answer didn't arrive in time, not *why* — the responder might be slow, or not there at all. The next section tells those apart.

## No responders

Waiting two seconds to discover that nobody is even listening is wasteful. NATS has a faster signal for that exact case.

When you send a request to a subject with zero subscribers, the server knows immediately that nobody can answer. Rather than let your timeout run, it sends back a **no responders** signal right away: a reply carrying a `503` status. Your client surfaces it as a distinct no-responders error, not a timeout.

This is the difference between "the inventory service is slow" (you get a timeout after 2s) and "the inventory service isn't running at all" (you get no responders in milliseconds). One is a latency problem; the other is a deployment problem. The signal lets your code react correctly to each.

See it for yourself. Stop the inventory service from the first terminal, then send the request again:

```
nats request orders.inventory.check \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}' \

  --timeout 2s
```

```
14:02:31 Sending request on "orders.inventory.check"

14:02:31 No responders are available
```

The no-responders signal comes back instantly, not after two seconds. The CLI prints the line and exits cleanly; a client library surfaces the same case as a distinct error you can branch on (`ErrNoResponders` in the Go client, with an equivalent in each language). Start the service again and the same request succeeds.

The signal rides the message header mechanism: the server delivers a reply with the header line `NATS/1.0 503`. A client needs header support to receive it, which every current client enables.

## Headers

That `503` mechanism points to a wider capability: NATS messages can carry **headers**, key/value metadata that travels alongside the payload in a format that looks like HTTP. A request can attach headers, and so can a reply.

You won't need them for the inventory call, so this page doesn't build with them. [Message headers](/learn/core-nats/headers.md) shows how to set and read them; the full wire format is in [Reference](/reference/.md). Reach for them when you want metadata that isn't part of the business payload: a request ID, a trace context, a content type.

## Request-reply, queue groups, and many answers

The inventory service has one responder. Two questions follow naturally, and each is its own page.

What if you run several inventory instances for capacity, and want exactly one of them to handle each request? That's a **queue group**, and the [next page](/learn/core-nats/queue-groups.md) builds one.

What if you want *every* responder on a subject to answer the same request, and you collect all the replies? That's [scatter-gather](/learn/core-nats/scatter-gather.md), two pages on.

If your request-reply services start to grow real endpoints, discovery, and stats, you're describing the [Services framework](/learn/services/.md), a layer built on exactly the request-reply and queue-group primitives in this chapter. This chapter stays on the primitives.

## Pitfalls

**A request without a timeout can wait forever.** Pass a deadline on every `request()` call, sized to the responder's work plus the round-trip — long enough not to give up on a merely-slow reply.

**Treating no responders as a hang.** No responders comes back in milliseconds, not as a slow timeout. Branch on it separately: no responders means nothing is deployed, a timeout means it's deployed but slow.

**Assuming exactly one reply.** A plain `request()` returns the first reply and discards the rest. If two inventory instances both answer on `orders.inventory.check`, the second answer is lost silently, with no indication that it ever arrived. When more than one service may answer, ask for it explicitly and gather by count or deadline:

#### CLI

```
#!/bin/bash

# A plain request returns only the FIRST reply and discards the rest.

# If more than one service answers on a subject, the extras are lost

# silently. Make the expectation explicit with --replies.

#

# --replies N waits for up to N replies instead of stopping at the first.

# --replies 0 collects every reply until --timeout ends the call.

nats request orders.inventory.check \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}' \

  --replies 0 --timeout 2s
```

#### JavaScript/TypeScript

```
// Gather more than one reply to a single request. A plain request() returns

// only the first reply, so when several services may answer, subscribe to your

// own inbox, publish the request with that inbox as the reply subject, and

// collect replies until they stop arriving.

const order =

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}';

const inbox = createInbox();

const sub = nc.subscribe(inbox);

nc.publish("orders.inventory.check", order, { reply: inbox });



const replies: string[] = [];

const gather = (async () => {

  for await (const msg of sub) {

    replies.push(msg.string());

  }

})();



// Stop once no further reply is expected.

setTimeout(() => sub.unsubscribe(), 300);

await gather;



console.log(`gathered ${replies.length} replies`);
```

#### Go

```
// Gather more than one reply to a single request. A plain Request returns

// only the first reply, so when several services may answer, subscribe to

// your own inbox, publish the request with that inbox as the reply subject,

// and collect replies until they stop arriving.

order := `{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}`

inbox := nats.NewInbox()

sub, _ := nc.SubscribeSync(inbox)

nc.PublishRequest("orders.inventory.check", inbox, []byte(order))



var replies [][]byte

for {

	// Stop once no further reply arrives within the gap deadline.

	msg, err := sub.NextMsg(300 * time.Millisecond)

	if err != nil {

		break

	}

	replies = append(replies, msg.Data)

}

fmt.Printf("gathered %d replies\n", len(replies))
```

#### Python

```
# Gather more than one reply to a single request. A plain request() returns

# only the first reply, so when several services may answer, subscribe to

# your own inbox and collect replies until they stop arriving.

order = '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

inbox = f"_INBOX.{uuid.uuid4().hex}"

async with await client.subscribe(inbox) as subscription:

    await client.publish("orders.inventory.check", order.encode(), reply=inbox)



    replies = []

    while True:

        try:

            # Stop once no further reply arrives within the gap deadline.

            message = await subscription.next(timeout=0.3)

            replies.append(message.data.decode())

        except TimeoutError:

            break



print(f"gathered {len(replies)} replies: {replies}")
```

#### Java

```
// Gather more than one reply to a single request. A plain request returns

// only the first reply, so when several services may answer, subscribe to

// your own inbox, publish the request with that inbox as the reply subject,

// and collect replies until they stop arriving.

byte[] order = ("{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

    + "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}").getBytes(StandardCharsets.UTF_8);

String inbox = nc.createInbox();

Subscription sub = nc.subscribe(inbox);

nc.publish("orders.inventory.check", inbox, order);



List<String> replies = new ArrayList<>();

Message m = sub.nextMessage(Duration.ofMillis(300));

while (m != null) {

    replies.add(new String(m.getData(), StandardCharsets.UTF_8));

    m = sub.nextMessage(Duration.ofMillis(300));

}

System.out.println("gathered " + replies.size() + " replies");
```

#### Rust

```
// Gather more than one reply to a single request. A plain request() returns

// only the first reply, so when several services may answer, subscribe to

// your own inbox, publish the request with that inbox as the reply subject,

// and collect replies until they stop arriving.

let order = r#"{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}"#;

let inbox = client.new_inbox();

let mut sub = client.subscribe(inbox.clone()).await?;

client

    .publish_with_reply("orders.inventory.check", inbox, order.into())

    .await?;

client.flush().await?;



let mut replies = Vec::new();

// Stop once no further reply arrives within the gap deadline.

while let Ok(Some(msg)) = tokio::time::timeout(Duration::from_millis(300), sub.next()).await {

    replies.push(String::from_utf8_lossy(&msg.payload).to_string());

}



println!("gathered {} replies", replies.len());
```

#### C#/.NET

```
// Gather more than one reply to a single request. A plain request returns

// only the first reply, so when several services may answer, subscribe to

// your own inbox, publish the request with that inbox as the reply subject,

// and collect replies until they stop arriving.

var order = new Order(OrderId: "ord_8w2k", Customer: "acme-co", TotalCents: 4200, Timestamp: DateTimeOffset.Parse("2026-05-22T10:14:22Z", CultureInfo.InvariantCulture));

var inbox = client.Connection.NewInbox();

await using var sub = await client.Connection.SubscribeCoreAsync<InventoryReply>(inbox);

await client.PublishAsync<Order>("orders.inventory.check", order, replyTo: inbox);



var replies = new List<InventoryReply>();

using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(300));

try

{

    // Stop once no further reply arrives within the gap deadline.

    await foreach (var msg in sub.Msgs.ReadAllAsync(cts.Token))

    {

        replies.Add(msg.Data!);

    }

}

catch (OperationCanceledException)

{

}



output.WriteLine($"gathered {replies.Count} replies");
```

#### C

```
// Gather more than one reply to a single request. A plain Request

// returns only the first reply, so when several services may answer,

// subscribe to your own inbox, publish the request with that inbox as

// the reply subject, and collect replies until they stop arriving.

const char *order = "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

                    "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}";

int        replies = 0;



if (s == NATS_OK)

    s = natsInbox_Create(&inbox);

if (s == NATS_OK)

    s = natsConnection_SubscribeSync(&sub, conn, (const char *) inbox);

if (s == NATS_OK)

    s = natsConnection_PublishRequestString(conn, "orders.inventory.check",

                                            (const char *) inbox, order);



while (s == NATS_OK)

{

    natsMsg *reply = NULL;



    // Stop once no further reply arrives within the gap deadline.

    s = natsSubscription_NextMsg(&reply, sub, 300);

    if (s != NATS_OK)

        break;



    replies++;

    natsMsg_Destroy(reply);

}

printf("gathered %d replies\n", replies);
```

When you actually want every responder to answer, that's [scatter-gather](/learn/core-nats/scatter-gather.md), not a bug. When you want exactly one of several instances to handle each request, that's a [queue group](/learn/core-nats/queue-groups.md).

**Doing slow work inside the responder.** A responder that runs a slow lookup before replying serializes every request behind it, so one expensive call adds latency to all the callers waiting in line. Keep the reply path fast, or run several instances in a [queue group](/learn/core-nats/queue-groups.md) so the load spreads across them instead of stacking on one.

## Where you are

The Acme world now has its first two-way conversation:

* An inventory service answers on `orders.inventory.check`, built with `nats reply` (or a client's `respond()`).
* The warehouse asks with `nats request` (or `request()`), every call bounded by a timeout.
* A missing responder surfaces instantly as no responders, not as a slow timeout.
* Replies are at-most-once like everything else in core NATS: not retried, not held.

## What's next

The inventory service is a single process. To scale it, you run several copies and let NATS hand each request to exactly one of them. That's a queue group: built-in load balancing with no broker in the middle. Build one on the next page: [Queue groups](/learn/core-nats/queue-groups.md).

## See also

* [Core Concepts → Request-reply](/concepts/request-reply.md) — the five-minute overview of the same pattern.
* [Learn → Services](/learn/services/.md) — the framework that turns request-reply responders into discoverable services.
* [Reference → Client protocol](/reference/protocols/client.md) — the wire-level `PUB`/`SUB`/`MSG` and header format.
