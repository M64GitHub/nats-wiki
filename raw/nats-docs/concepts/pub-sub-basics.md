<!-- source: https://docs.nats.io/concepts/pub-sub-basics.md · fetched 2026-08-31 · section: pub-sub-basics -->
# Publish-Subscribe

Everything in NATS starts with publish-subscribe. A publisher sends a message to a subject, and every subscriber listening on that subject gets a copy. This is the foundation everything else builds on.

For a runnable, step-by-step treatment, see the [Core NATS deep dive](/learn/core-nats/.md).

**Message flow — Publish / Subscribe (animated):** Animated publish/subscribe: a publisher emits messages; NATS delivers a copy to every matching subscriber.

* Publisher → NATS (subject: updates)
* NATS → Subscriber 1 (subject: updates)
* NATS → Subscriber 2 (subject: updates)

Watch how messages flow as subscribers join. With no subscribers, messages reach the server but aren't delivered. As subscribers connect, each one receives a copy of every message.

## How It Works

1. **Publishers** send messages to a [subject](/concepts/subjects.md) — a simple string like `orders.created`
2. **Subscribers** express interest in subjects they care about
3. **NATS delivers** a copy of each message to every matching subscriber
4. **No coupling** — publishers don't know about subscribers, and subscribers don't know about publishers

This decoupling gives you tremendous flexibility. Services can be added, removed, or restarted without coordinating with anyone else.

## Publishing Messages

You publish a message by sending it to a subject:

#### CLI

```
#!/bin/bash



# Publish a message to the "weather.updates" subject

nats pub weather.updates "Temperature: 72°F"
```

#### JavaScript/TypeScript

```
// Publish a message to the "weather.updates" subject

nc.publish("weather.updates", "Temperature: 72°F");
```

#### Go

```
// Publish a message to the 'weather.updates' subject

nc.Publish("weather.updates", []byte("Temperature: 72°F"))
```

#### Python

```
# Publish a message to the subject "weather.updates"

await nc.publish("weather.updates", "Temperature: 72°F".encode())
```

#### Java

```
// Publish a message to the subject "weather.updates"

byte[] data = "Temperature: 72°F".getBytes(StandardCharsets.UTF_8);

nc.publish("weather.updates", data);
```

#### Rust

```
// Publish a message to the subject "weather.updates"

nc.publish("weather.updates", "Temperature: 72°F".into())

    .await?;
```

#### C#/.NET

```
// Publish a message to the subject "weather.updates"

await client.PublishAsync("weather.updates", "Temperature: 72F");
```

#### C

```
// Publish a message to the 'weather.updates' subject

if (s == NATS_OK)

    s = natsConnection_PublishString(conn, "weather.updates",

                                     "Temperature: 72°F");
```

Key points:

* Publishers don't wait for acknowledgments (fire-and-forget)
* Messages are delivered to all active subscribers
* If no subscribers exist, the message is simply discarded

## Subscribing to Subjects

Subscribers express interest in subjects to receive messages:

#### CLI

```
#!/bin/bash



# Subscribe to messages on the "weather.updates" subject

nats sub "weather.updates"
```

#### JavaScript/TypeScript

```
// Subscribe to the "weather.updates" subject; auto-close after 1 message

const sub = nc.subscribe("weather.updates");



// iterate over messages received (sub will end after the first message)

for await (const msg of sub) {

  console.log(`Received: ${msg.string()}`);

  break;

}
```

#### Go

```
// Subscribe to weather updates

sub, _ := nc.Subscribe("weather.updates", func(msg *nats.Msg) {

	fmt.Printf("Received: %s\n", string(msg.Data))

})
```

#### Python

```
# Subscribe to 'weather.updates' synchronously

sub = await nc.subscribe("weather.updates")



# Process messages

while True:

    try:

        msg = await sub.next(timeout=1)

        print(f"Received: {msg.data.decode()}")

    except TimeoutError:

        break
```

#### Java

```
// Subscribe to 'weather.updates' synchronously

Subscription sub = nc.subscribe("weather.updates");



// Process messages

Message m = sub.nextMessage(1000);

while (m != null) {

    System.out.println("Received: " + new String(m.getData(), StandardCharsets.UTF_8));

    m = sub.nextMessage(1000);

}
```

#### Rust

```
//  Subscribe to the "weather.updates" subject

let mut sub = nc.subscribe("weather.updates").await?;



while let Some(msg) = sub.next().await {

    println!("Received: {}", String::from_utf8_lossy(&msg.payload));

}
```

#### C#/.NET

```
// Subscribe to 'weather.updates' and process messages

await foreach (var msg in client.SubscribeAsync<string>("weather.updates"))

{

    output.WriteLine($"Received: {msg.Data}");

}
```

#### C

```
// The callback runs for each message published to 'weather.updates'.

static void

onUpdate(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    printf("Received: %.*s\n",

           natsMsg_GetDataLength(msg), natsMsg_GetData(msg));



    natsMsg_Destroy(msg);

}

    // Subscribe to weather updates

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&sub, conn, "weather.updates",

                                     onUpdate, NULL);
```

## When to Use Pub/Sub

Publish-subscribe is ideal when multiple services need to react to the same event:

* **Event broadcasting** — notify services about user signups, order placements, deployments
* **Data distribution** — send updates to multiple dashboards or monitoring services
* **Fan-out notifications** — alert all interested parties about state changes
* **Audit logging** — multiple services independently log the same events

### Real-world example

Imagine an e-commerce system where an order is placed. You publish a single event:

```
nats pub orders.created '{"orderId": "123", "total": 99.99}'
```

Multiple services subscribe and each reacts differently:

* **Inventory Service** updates stock levels
* **Email Service** sends a confirmation email
* **Analytics Service** records metrics
* **Shipping Service** prepares the shipment

One publish, four independent reactions — no coordination needed.

## Pub/Sub Patterns

### Fan-Out

One publisher, multiple subscribers — perfect for event notification:

**Message flow — Fan-out:** Fan-out pattern where a single message is broadcasted to multiple independent services

* Event Source → Analytics (subject: events.\*)
* Event Source → Logging
* Event Source → Monitoring
* Event Source → Notification

### Fan-In

Multiple publishers, one subscriber — ideal for aggregation:

**Message flow — Fan-in:** Fan-in pattern where many publishers send messages to a single subscriber for aggregation

* Publisher A → Aggregator (subject: metrics.\*)
* Publisher B → Aggregator
* Publisher C → Aggregator
* Publisher D → Aggregator

## Subject Hierarchies

NATS subjects support hierarchical naming using dots (`.`) as delimiters:

```
orders.us.created

orders.eu.created

orders.us.canceled
```

This creates logical namespaces for organizing your messages. You can use wildcards to subscribe across hierarchies — `orders.*.created` catches orders from any region.

For a deep dive into subjects, hierarchies, wildcards, and naming conventions, see [Subjects](/concepts/subjects.md).

## How Delivery Works

* **At-most-once delivery**: Core NATS delivers messages without persistence. If you need guaranteed delivery, that's what [JetStream](/concepts/jetstream.md) is for.
* **Active subscribers only**: Only subscribers connected when the message is published will receive it. Messages aren't stored for later.
* **Every subscriber gets a copy**: Subscribing doesn't consume or remove messages — each subscriber independently receives its own copy.
* **Message size**: NATS has a default max message size of 1MB (configurable). For large data, consider using object stores or passing references.
* **Subscription efficiency**: NATS handles millions of subscriptions efficiently. Use wildcards to reduce subscription overhead when possible.

## Try It Yourself

Open two terminals and see pub/sub in action:

```
# Terminal 1 — subscribe to all demo messages

nats sub 'demo.>'



# Terminal 2 — publish some messages

nats pub demo.hello "Hello NATS!"

nats pub demo.greeting "Welcome to pub/sub"

nats pub demo.test.nested "Hierarchical subjects work!"
```

You'll see each message arrive in Terminal 1 the instant it's published. Try opening a third terminal with another `nats sub 'demo.>'` — both subscribers will receive every message.

## Next steps

* [Core NATS deep dive](/learn/core-nats/.md) — the full runnable walkthrough
* [Publish-subscribe, step by step](/learn/core-nats/publish-subscribe.md) — build pub/sub up from scratch
* [Subjects](/concepts/subjects.md) — the addressing system that makes pub/sub flexible
* [Queue Groups](/concepts/queue-groups.md) — same pub/sub, but with built-in load balancing
* [Request-Reply](/concepts/request-reply.md) — pub/sub with a reply subject for synchronous patterns
