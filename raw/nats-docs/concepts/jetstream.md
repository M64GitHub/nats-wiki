<!-- source: https://docs.nats.io/concepts/jetstream.md · fetched 2026-08-31 · section: jetstream -->
# JetStream

Core NATS delivers messages only to subscribers connected at the moment of publication - at most once, never replayed. JetStream adds a persistence layer on top, giving you at-least-once delivery - messages survive restarts and can be replayed.

Core NATS already decouples publisher and subscriber from each other, where a publisher does not need to know about the subscriber. JetStream extends that decoupling to time - the two no longer need to be online at the same moment.

For a runnable, step-by-step treatment, see the [JetStream deep dive](/learn/jetstream/.md).

**Message flow — Core NATS vs JetStream (animated):** Core NATS versus JetStream for a subscriber that goes offline. In Core mode, messages published while the client is offline reach the server and go nowhere; when the client returns, only new messages arrive. In JetStream mode the stream stores what the client missed — the pending count climbs while it is offline and drains back as the stream replays every missed message once the client reconnects.

* Publisher → NATS

## How It Works

JetStream introduces three pieces working together:

* A **stream** is a server-side store of messages, bound to one or more subjects.
* A **consumer** is a server-side, stateful view of a stream - the server tracks how far a client has progressed, so applications don't have to.
* A **client** is an application that connects to a consumer to receive messages and acknowledge them. A consumer can be shared by multiple clients to divide the work; each acknowledgment advances the consumer's position in the stream.

## Streams

A stream is bound to one or more subject patterns. When a publisher sends a message to a matching subject, the server appends it to the stream and assigns it a sequence number. Streams are configurable for storage (memory or disk), retention (whether limits or consumer acks remove messages), replication, and more.

## Consumers

A consumer is a server-side, stateful view of a stream that tracks how far a client has progressed. Multiple consumers can read the same stream independently, each with its own position. The server maintains that position so applications don't have to coordinate or remember it themselves.

**Message flow — Consumers with independent cursors (animated):** Three consumers read one 8-message stream from independent positions. Inventory, Email, and Analytics each start at a different point and move at their own speed, and each keeps its own cursor — one consumer catching up never moves another's position. The stream holds a single shared copy of every message and serves each consumer from where it left off.

The application that connects to a consumer - the **client** - receives messages and acknowledges each one. An acknowledgment advances the consumer's cursor - if a message isn't acknowledged in time, the server redelivers it, which is what gives you at-least-once delivery.

A consumer can be configured to start reading from the beginning of the stream, from the latest message, from a specific sequence number, or from a specific time.

## Putting It Together

#### CLI

```
# Create a stream that captures any subject under `orders.`

nats stream add ORDERS --subjects "orders.>" --storage file --retention limits --defaults



# Publish a few orders

nats pub orders.new "Order #1001"

nats pub orders.new "Order #1002"

nats pub orders.shipped "Order #1001 shipped"



# Create a durable pull consumer that delivers from the beginning of the stream

nats consumer add ORDERS order-processor --pull --deliver all --ack explicit --defaults



# Fetch and acknowledge the next batch of messages

nats consumer next ORDERS order-processor --count 3 --ack
```

#### JavaScript/TypeScript

```
// Create a stream that captures any subject under `orders.`

const jsm = await jetstreamManager(nc);

await jsm.streams.add({

  name: "ORDERS",

  subjects: ["orders.>"],

  storage: StorageType.File,

});



// Publish a few orders

const js = jetstream(nc);

await js.publish("orders.new", "Order #1001");

await js.publish("orders.new", "Order #1002");

await js.publish("orders.shipped", "Order #1001 shipped");



// Create a durable pull consumer that delivers from the beginning

await jsm.consumers.add("ORDERS", {

  durable_name: "order-processor",

  ack_policy: AckPolicy.Explicit,

});

const consumer = await js.consumers.get("ORDERS", "order-processor");



// Fetch a batch and acknowledge each message

const messages = await consumer.fetch({ max_messages: 3, expires: 5000 });

for await (const msg of messages) {

  console.log(`Received on ${msg.subject}: ${msg.string()}`);

  msg.ack();

}
```

#### Go

```
// Create a stream that captures any subject under `orders.`

stream, err := js.CreateStream(ctx, jetstream.StreamConfig{

	Name:     "ORDERS",

	Subjects: []string{"orders.>"},

	Storage:  jetstream.FileStorage,

})

if err != nil {

	log.Fatal(err)

}



// Publish a few orders

js.Publish(ctx, "orders.new", []byte("Order #1001"))

js.Publish(ctx, "orders.new", []byte("Order #1002"))

js.Publish(ctx, "orders.shipped", []byte("Order #1001 shipped"))



// Create a durable pull consumer that delivers from the beginning

consumer, err := stream.CreateOrUpdateConsumer(ctx, jetstream.ConsumerConfig{

	Durable:   "order-processor",

	AckPolicy: jetstream.AckExplicitPolicy,

})

if err != nil {

	log.Fatal(err)

}



// Fetch a batch and acknowledge each message

msgs, err := consumer.Fetch(3)

if err != nil {

	log.Fatal(err)

}

for msg := range msgs.Messages() {

	fmt.Printf("Received on %s: %s\n", msg.Subject(), string(msg.Data()))

	msg.Ack()

}
```

#### Python

```
# JetStream context

js = jetstream.new(nc)



# Create a stream that captures any subject under `orders.`

stream = await js.create_stream(name="ORDERS", subjects=["orders.>"], storage="file")



# Publish a few orders

await js.publish("orders.new", b"Order #1001")

await js.publish("orders.new", b"Order #1002")

await js.publish("orders.shipped", b"Order #1001 shipped")



# Create a durable pull consumer that delivers from the beginning

consumer = await stream.create_or_update_consumer(

    name="order-processor",

    ack_policy="explicit",

)



# Fetch a batch and acknowledge each message

batch = await consumer.fetch(max_messages=3, max_wait=2.0)

async for msg in batch:

    print(f"Received on {msg.subject}: {msg.data.decode()}")

    await msg.ack()
```

#### Java

```
// Create a stream that captures any subject under `orders.`

JetStreamManagement jsm = nc.jetStreamManagement();

StreamInfo streamInfo = jsm.addStream(StreamConfiguration.builder()

        .name("ORDERS")

        .subjects("orders.>")

        .storageType(StorageType.File)

    .build());



// Publish a few orders

JetStream js = nc.jetStream();

js.publish("orders.new", "Order #1001".getBytes(StandardCharsets.UTF_8));

js.publish("orders.new", "Order #1002".getBytes(StandardCharsets.UTF_8));

js.publish("orders.shipped", "Order #1001 shipped".getBytes(StandardCharsets.UTF_8));



// Create a durable pull consumer that delivers from the beginning

StreamContext stream = js.getStreamContext("ORDERS");

ConsumerContext consumer = stream.createOrUpdateConsumer(ConsumerConfiguration.builder()

    .durable("order-processor")

    .ackPolicy(AckPolicy.Explicit)

    .build());



// Fetch a batch and acknowledge each message

try (FetchConsumer fetchConsumer = consumer.fetchMessages(3)) {

    Message msg = fetchConsumer.nextMessage();

    while (msg != null) {

        System.out.printf("Received on %s: %s\n", msg.getSubject(), new String(msg.getData(), StandardCharsets.UTF_8));

        msg.ack();

        msg = fetchConsumer.nextMessage();

    }

}
```

#### Rust

```
// Create a stream that captures any subject under `orders.`

let stream = js

    .create_stream(jetstream::stream::Config {

        name: "ORDERS".to_string(),

        subjects: vec!["orders.>".into()],

        storage: StorageType::File,

        ..Default::default()

    })

    .await?;



// Publish a few orders

js.publish("orders.new", "Order #1001".into()).await?;

js.publish("orders.new", "Order #1002".into()).await?;

js.publish("orders.shipped", "Order #1001 shipped".into())

    .await?;



// Create a durable pull consumer that delivers from the beginning

let consumer: PullConsumer = stream

    .create_consumer(jetstream::consumer::pull::Config {

        durable_name: Some("order-processor".to_string()),

        ack_policy: jetstream::consumer::AckPolicy::Explicit,

        ..Default::default()

    })

    .await?;



// Fetch a batch and acknowledge each message

let mut messages = consumer.fetch().max_messages(3).messages().await?;

while let Some(message) = messages.next().await {

    let message = message?;

    println!(

        "Received on {}: {}",

        message.subject,

        String::from_utf8_lossy(&message.payload)

    );

    message.ack().await?;

}
```

#### C#/.NET

```
// Create a stream that captures any subject under `orders.`

var js = client.CreateJetStreamContext();

await js.CreateStreamAsync(new StreamConfig(name: "ORDERS", subjects: ["orders.>"])

{

    Storage = StreamConfigStorage.File,

});



// Publish a few orders

await js.PublishAsync<string>(subject: "orders.new", data: "Order #1001");

await js.PublishAsync<string>(subject: "orders.new", data: "Order #1002");

await js.PublishAsync<string>(subject: "orders.shipped", data: "Order #1001 shipped");



// Create a durable pull consumer that delivers from the beginning

var consumer = await js.CreateOrUpdateConsumerAsync(stream: "ORDERS", config: new ConsumerConfig

{

    Name = "order-processor",

    DurableName = "order-processor",

    AckPolicy = ConsumerConfigAckPolicy.Explicit,

});



// Fetch a batch and acknowledge each message

await foreach (var msg in consumer.FetchAsync<string>(new NatsJSFetchOpts { MaxMsgs = 3 }))

{

    output.WriteLine($"Received on {msg.Subject}: {msg.Data}");

    await msg.AckAsync();

}
```

#### C

```
// Create a stream that captures any subject under `orders.`

jsStreamConfig  cfg;

const char      *subjects[] = {"orders.>"};



jsStreamConfig_Init(&cfg);

cfg.Name        = "ORDERS";

cfg.Subjects    = subjects;

cfg.SubjectsLen = 1;

cfg.Storage     = js_FileStorage;



s = js_AddStream(&si, js, &cfg, NULL, &jerr);



// Publish a few orders

if (s == NATS_OK)

    s = js_Publish(NULL, js, "orders.new", "Order #1001",

                   (int) strlen("Order #1001"), NULL, &jerr);

if (s == NATS_OK)

    s = js_Publish(NULL, js, "orders.new", "Order #1002",

                   (int) strlen("Order #1002"), NULL, &jerr);

if (s == NATS_OK)

    s = js_Publish(NULL, js, "orders.shipped", "Order #1001 shipped",

                   (int) strlen("Order #1001 shipped"), NULL, &jerr);



// Create a durable pull consumer that delivers from the beginning

if (s == NATS_OK)

{

    jsConsumerConfig    cc;



    jsConsumerConfig_Init(&cc);

    cc.Durable   = "order-processor";

    cc.AckPolicy = js_AckExplicit;



    s = js_AddConsumer(&ci, js, "ORDERS", &cc, NULL, &jerr);

}



// Bind a pull subscription to the consumer

if (s == NATS_OK)

{

    jsSubOptions    so;



    jsSubOptions_Init(&so);

    so.Stream   = "ORDERS";

    so.Consumer = "order-processor";



    s = js_PullSubscribe(&sub, js, NULL, NULL, NULL, &so, &jerr);

}



// Fetch a batch and acknowledge each message

if (s == NATS_OK)

{

    natsMsgList list = {NULL, 0};



    s = natsSubscription_Fetch(&list, sub, 3, 2000, &jerr);

    if (s == NATS_OK)

    {

        for (int i = 0; i < list.Count; i++)

        {

            printf("Received on %s: %s\n",

                   natsMsg_GetSubject(list.Msgs[i]),

                   natsMsg_GetData(list.Msgs[i]));

            natsMsg_Ack(list.Msgs[i], NULL);

        }

        natsMsgList_Destroy(&list);

    }

}
```

## Beyond Streams and Consumers

JetStream also provides higher-level abstractions built on top of streams and consumers:

* **Key Value Store**: A simple key-value store with built-in replication and durability.
* **Object Store**: Store objects larger than a single message, split into chunks, with per-object metadata.

## Related Concepts

* [Publish-Subscribe](/concepts/pub-sub-basics.md) - The fire-and-forget messaging model JetStream builds on
* [Subjects](/concepts/subjects.md) - How streams capture messages by subject patterns
* [Queue Groups](/concepts/queue-groups.md) - Load balancing across consumers, also available with JetStream consumers

## Next steps

* [JetStream deep dive](/learn/jetstream/.md) — build a stream and consumer hands-on
* [Key-Value deep dive](/learn/key-value/.md) — durable key-value store on JetStream
* [Object Store deep dive](/learn/object-store/.md) — chunked object storage on JetStream
