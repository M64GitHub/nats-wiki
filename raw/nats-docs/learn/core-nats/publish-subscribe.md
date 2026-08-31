<!-- source: https://docs.nats.io/learn/core-nats/publish-subscribe.md · fetched 2026-08-31 · section: publish-subscribe -->
# Publish-subscribe

Core NATS has one fundamental operation: a client publishes a message to a subject, and every client subscribed to that subject right now gets a copy. This page shows how that behaves on the wire: where the copies come from, what happens when nobody is listening, and what core NATS promises about delivery.

## The scenario

Acme runs an order platform. Three things happen to an order, and each one is a message on its own subject:

```
orders.created

orders.shipped

orders.canceled
```

Every message in this chapter carries the same small JSON payload:

```
{

  "order_id": "ord_8w2k",

  "customer": "acme-co",

  "total_cents": 4200,

  "ts": "2026-05-22T10:14:22Z"

}
```

Three services care about these messages. The `warehouse` service packs the box when an order is created. The `notifications` service emails the customer. The `analytics` service counts everything. None of them knows the others exist.

[Connecting](/learn/core-nats/connecting.md) already started one local `nats-server`. Leave it running for the rest of this chapter. If you landed here directly, start one now:

```
nats-server
```

That's the whole deployment, with no flags, no persistence, and no cluster. Add services to it as the chapter grows.

## Publishing a message

A **publisher** is a client that sends a message to a subject. The warehouse doesn't subscribe to anything yet, so start by publishing one `orders.created` message:

#### CLI

```
#!/bin/bash

# Publish one order to the orders.created subject. The publish is

# fire-and-forget: nats pub hands the message to the server and exits.

# It does not wait for, or report, any subscriber.

nats pub orders.created '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'
```

#### JavaScript/TypeScript

```
// Publish one order to the orders.created subject. Publishing is

// fire-and-forget: the call hands the message to the server and returns.

const order =

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}';

nc.publish("orders.created", order);
```

#### Go

```
// Publish one order to the orders.created subject. Publishing is

// fire-and-forget: the call hands the message to the server and returns.

order := `{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}`

nc.Publish("orders.created", []byte(order))
```

#### Python

```
# Publish one order to the orders.created subject. Publishing is

# fire-and-forget: the call hands the message to the server and returns.

order = '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

await client.publish("orders.created", order.encode())
```

#### Java

```
// Publish one order to the orders.created subject. Publishing is

// fire-and-forget: the call hands the message to the server and returns.

byte[] order = ("{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

    + "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}").getBytes(StandardCharsets.UTF_8);

nc.publish("orders.created", order);
```

#### Rust

```
// Publish one order to the orders.created subject. Publishing is

// fire-and-forget: the call hands the message to the server and returns.

let order = r#"{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}"#;

client.publish("orders.created", order.into()).await?;
```

#### C#/.NET

```
// Publish one order to the orders.created subject. Publishing is

// fire-and-forget: the call hands the message to the server and returns.

// The client serializes the Order record to JSON by default.

var order = new Order(

    OrderId: "ord_8w2k",

    Customer: "acme-co",

    TotalCents: 4200,

    Timestamp: DateTimeOffset.Parse("2026-05-22T10:14:22Z", CultureInfo.InvariantCulture));

await client.PublishAsync<Order>("orders.created", order);
```

#### C

```
// Publish one order to the orders.created subject. Publishing is

// fire-and-forget: the call hands the message to the client and

// returns. It does not wait for, or report, any subscriber.

if (s == NATS_OK)

    s = natsConnection_PublishString(conn, "orders.created",

            "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

            "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}");
```

The publish call returns immediately. It doesn't wait for a subscriber, and it doesn't tell you how many subscribers received the message, or whether any did. This is **fire-and-forget**: the publisher hands the message to the server and moves on.

A publisher always names a fully-qualified subject. `orders.created` is a concrete subject, not a pattern. Wildcards belong to subscribers, and we cover them on the [next page](/learn/core-nats/subjects-and-wildcards.md).

## Subscribing to a subject

A **subscriber** is a client that registers interest in a subject and receives a copy of every matching message. Start the warehouse service as a subscriber on `orders.created`:

#### CLI

```
#!/bin/bash

# Subscribe as the warehouse service to orders.created. Each matching

# message is printed as it arrives; Ctrl-C to stop. To receive every

# order subject at once instead, subscribe to the wildcard orders.>

nats sub orders.created
```

#### JavaScript/TypeScript

```
// Subscribe as the warehouse service to orders.created. Each matching

// message is delivered to this subscription as it is published.

const sub = nc.subscribe("orders.created");

for await (const msg of sub) {

  console.log(`warehouse received: ${msg.string()}`);

}
```

#### Go

```
// Subscribe as the warehouse service to orders.created. The callback runs

// for each matching message as it is published.

nc.Subscribe("orders.created", func(m *nats.Msg) {

	fmt.Printf("warehouse received: %s\n", string(m.Data))

})
```

#### Python

```
# Subscribe as the warehouse service to orders.created. Each matching

# message is delivered to this subscription as it is published.

async with await client.subscribe("orders.created") as subscription:

    async for message in subscription:

        print(f"warehouse received: {message.data.decode()}")
```

#### Java

```
// Subscribe as the warehouse service to orders.created. Each matching

// message is delivered to this dispatcher as it is published.

nc.createDispatcher(msg ->

    System.out.println("warehouse received: " + new String(msg.getData(), StandardCharsets.UTF_8))

).subscribe("orders.created");
```

#### Rust

```
// Subscribe as the warehouse service to orders.created. Each matching

// message is delivered to this subscription as it is published.

let mut sub = client.subscribe("orders.created").await?;

while let Some(msg) = sub.next().await {

    println!(

        "warehouse received: {}",

        String::from_utf8_lossy(&msg.payload)

    );

}
```

#### C#/.NET

```
// Subscribe as the warehouse service to orders.created. Each matching

// message is delivered to this subscription as it is published and

// deserialized from JSON into an Order record.

await foreach (var msg in client.SubscribeAsync<Order>("orders.created"))

{

    output.WriteLine($"warehouse received: {msg.Data}");

}
```

#### C

```
// The callback runs for each matching message as it is published.

static void

onMsg(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    printf("warehouse received: %.*s\n",

           natsMsg_GetDataLength(msg), natsMsg_GetData(msg));

    natsMsg_Destroy(msg);

}

    // Subscribe as the warehouse service to orders.created.

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&sub, conn, "orders.created", onMsg, NULL);
```

Now publish again with the snippet above. The warehouse receives the message. Run a second subscriber for `notifications` and a third for `analytics`, each on `orders.created`, and every one of them receives its own copy of the next publish.

Each subscriber gets an independent copy; subscribing isn't taking from a queue, and one subscriber receiving a message takes nothing from another.

If you want one subscriber to see *all* order subjects at once, it can subscribe to `orders.>` instead of a single subject. That `>` is a wildcard, and the [next page](/learn/core-nats/subjects-and-wildcards.md) is where we explain it.

## Unsubscribing

When a subscriber unsubscribes, the server removes its interest in that subject as soon as it processes the request. Any message published after that doesn't reach it, and there's nothing to clean up on the server side.

You can also have a subscription end itself after a fixed number of messages, without tracking the count yourself. This is **auto-unsubscribe**: a client calls its auto-unsubscribe method (`AutoUnsubscribe(N)` in Go), which tells the server to end the subscription once it has delivered N messages. The CLI's `nats sub --count N` gets the same result by counting messages itself and unsubscribing when it hits the limit. It fits a take-exactly-N flow, such as reading the next three orders and stopping.

#### CLI

```
#!/bin/bash

# Subscribe to orders.created and stop automatically after three messages.

# --count makes nats sub quit once it has received that many, giving a

# take-exactly-N read instead of an open-ended subscription you Ctrl-C.

nats sub orders.created --count 3
```

#### C

```
// Subscribe to orders.created and stop automatically after three

// messages. AutoUnsubscribe tells the client to remove the

// subscription once that many have been delivered, giving a

// take-exactly-N read instead of an open-ended subscription.

if (s == NATS_OK)

    s = natsConnection_SubscribeSync(&sub, conn, "orders.created");

if (s == NATS_OK)

    s = natsSubscription_AutoUnsubscribe(sub, 3);



// Read the three orders, waiting up to 10 seconds for each.

if (s == NATS_OK)

{

    int i;



    for (i = 0; (s == NATS_OK) && (i < 3); i++)

    {

        natsMsg *msg = NULL;



        s = natsSubscription_NextMsg(&msg, sub, 10000);

        if (s == NATS_OK)

        {

            printf("warehouse received: %.*s\n",

                   natsMsg_GetDataLength(msg), natsMsg_GetData(msg));

            natsMsg_Destroy(msg);

        }

    }

}
```

## The interest graph

The server tracks who's subscribed to what in an in-memory structure called the **interest graph**. Each subscription adds an entry; each unsubscribe or disconnect removes it.

**Message flow — Publish / Subscribe (animated):** Animated publish/subscribe: a publisher emits messages; NATS delivers a copy to every matching subscriber.

* Publisher → NATS (subject: updates)
* NATS → Subscriber 1 (subject: updates)
* NATS → Subscriber 2 (subject: updates)

When a message arrives, the server looks up the subject in the interest graph, finds the matching subscribers, and sends each one a copy. With three services subscribed to `orders.created`, one publish produces three deliveries. The publisher did nothing different; the fan-out happened entirely on the server.

The interest graph is the source of the decoupling. The publisher holds no list of subscribers. It publishes to a subject, and the server resolves interest at the moment the message arrives.

This is also why services can come and go freely. Start a fourth subscriber and it joins the graph; the next publish reaches it. Stop one and its entry is gone; the next publish skips it. Nobody coordinates, and the publisher never changes.

## When nobody is listening

Publish to `orders.created` while no service is subscribed. The publish still succeeds, and the message is dropped. The server finds no matching entry in the interest graph, so there's nothing to deliver to, and the message is discarded.

A publish with no interest is a silent no-op: no error, no stored backlog. The publisher can't tell "delivered to three subscribers" from "delivered to nobody" — both look like a successful publish. If the warehouse is restarting when an `orders.created` message is published, that message is gone.

## At-most-once delivery

Core NATS delivers each message **at-most-once**. A subscriber that's connected and interested when the message is published gets it once. A subscriber that's absent, slow, or disconnected at that instant gets it zero times. There's no second attempt.

Core NATS doesn't retry a missed message, doesn't detect or suppress duplicates, and doesn't guarantee that two subscribers see messages in the same order under load. Each is a property you add with [JetStream](/learn/jetstream/.md), not something core provides.

At-most-once is the right guarantee for a large class of messages: telemetry you sample, cache invalidations, a live dashboard feed. For those, a missed message costs nothing because another is already on the way. For an order that must be packed exactly once, it isn't enough. That's the boundary of core NATS.

## The 1 MB payload limit

A message payload has a maximum size. By default the server caps it at **1 MB** (`max_payload`, `1048576` bytes). The server announces this limit to every client when the connection opens, so the client knows the ceiling before it ever publishes.

Because the client knows the ceiling, it checks the payload before sending. An official client fails the publish call with `nats: maximum payload exceeded` and leaves the connection up, so the message never leaves the client. The server is the backstop for a client that sends an oversized message anyway: it replies `-ERR 'Maximum Payload Violation'` and closes the connection. The Acme order payload is a few hundred bytes, well under the ceiling, but a service that tries to ship a large blob inside a message will hit it.

For large data, publish a reference (an object-store key or a URL) and let the receiver fetch the bytes out of band.

## Try it in two terminals

Observe fire-and-forget and at-most-once directly. Open two terminals against the running server.

```
# Terminal 1 — the warehouse subscribes

nats sub orders.created
```

```
# Terminal 2 — publish three orders

nats pub orders.created '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

nats pub orders.created '{"order_id":"ord_2zr9","customer":"globex","total_cents":7800,"ts":"2026-05-22T10:14:25Z"}'

nats pub orders.created '{"order_id":"ord_5kq1","customer":"initech","total_cents":1500,"ts":"2026-05-22T10:14:29Z"}'
```

Terminal 1 prints each message the instant it's published. Now stop the subscriber in Terminal 1 with Ctrl-C, publish a fourth message, and restart the subscriber. The fourth message never appears. It was published into an empty interest graph and discarded, which is at-most-once delivery in action.

## Pitfalls

**Publishing over the limit fails the publish.** An official client checks the payload against `max_payload` and fails the call with `nats: maximum payload exceeded` before anything goes out; the connection stays up. Keep payloads under the limit and pass a reference for anything large.

#### CLI

```
#!/bin/bash

# Ask your connection for its limits before sizing a message. The

# "Maximum Payload" row comes from the INFO the server sends at connect

# (1 MB by default), so a plain no-auth connection can read it. An

# official client checks this ceiling and fails an oversized publish

# locally; the server rejects and closes the connection of any client

# that sends a larger PUB anyway.

nats account info



# A safe order publish stays far under the ceiling.

nats pub orders.created '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'



# Publishing over the ceiling fails immediately, client-side, before the

# message reaches the server. Try a 2 MB payload:

#

#   head -c 2000000 /dev/zero | tr '\0' x | nats pub orders.created --force-stdin

#   nats: error: nats: maximum payload exceeded

#

# So keep payloads small and pass a reference (an object-store key or a URL)

# for anything large, rather than discovering the limit the hard way.
```

#### C

```
// Ask the connection for its limit before sizing a message. The value

// comes from the INFO the server sent at connect (1 MB by default).

if (s == NATS_OK)

    printf("maximum payload: %d bytes\n",

           (int) natsConnection_GetMaxPayload(conn));



// A safe order publish stays far under the ceiling.

if (s == NATS_OK)

    s = natsConnection_PublishString(conn, "orders.created",

            "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

            "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}");



// Publishing over the ceiling fails immediately, client-side, before

// the message reaches the server. Try a 2 MB payload:

if (s == NATS_OK)

{

    int   bigLen = 2 * 1024 * 1024;

    char  *big   = malloc(bigLen);



    memset(big, 'x', bigLen);

    s = natsConnection_Publish(conn, "orders.created", big, bigLen);

    if (s == NATS_MAX_PAYLOAD)

    {

        printf("oversized publish rejected: %s\n", natsStatus_GetText(s));

        s = NATS_OK;

    }

    free(big);

}
```

**Exiting before the publish leaves the client drops it.** The publish call returns immediately because the client buffers the message and sends it in the background. A short-lived publisher that exits right after the call can quit before that buffered message reaches the server, and the message is gone. Flush (or drain) before you exit. The client waits for a round trip to the server, so everything buffered before it has arrived:

```
nc.Publish("orders.created", payload)

nc.Flush() // wait until the server has the message, then exit

nc.Close()
```

**A connection receives the messages it publishes.** When one connection both publishes and subscribes to the same subject, it gets a copy of its own messages, because echo is on by default for every connection. A service that publishes status updates and also subscribes to them can process its own updates in a loop. [Connecting](/learn/core-nats/connecting.md) covers turning it off.

**A slow subscriber gets cut off.** A subscriber that can't keep up with the rate of matching messages builds a backlog on the server. Past a threshold the server stops protecting it, logs `Slow Consumer Detected`, and closes its connection. The other subscribers are unaffected. The fix lives in the client: process messages fast enough, or hand them to a worker. [Resilient clients → Slow consumers](/learn/resilient-clients/slow-consumers.md) covers the tuning and recovery.

## Where you are

You have one local `nats-server` running, and the Acme order services talking over core publish-subscribe:

* A publisher sends `orders.created` messages fire-and-forget.
* The `warehouse`, `notifications`, and `analytics` subscribers each receive their own copy.
* A message published with no interest is discarded, and delivery is at-most-once.

## What's next

Right now every service subscribes to one exact subject. The next page, [Subjects & wildcards](/learn/core-nats/subjects-and-wildcards.md), shows how subjects form a hierarchy and how a subscriber uses `*` and `>` to match many subjects at once, including regional orders like `orders.us.created`.

## See also

* [Core Concepts → Publish-subscribe](/concepts/pub-sub-basics.md) — the five-minute overview of this pattern.
* [Learn → JetStream → Why a stream](/learn/jetstream/your-first-stream.md#why-a-stream) — the layer that keeps the messages core NATS discards.
* [Reference → Client protocol](/reference/protocols/client.md) — the wire-level `PUB`/`SUB`/`MSG` details.
