<!-- source: https://docs.nats.io/learn/jetstream/delivery-and-acknowledgment.md · fetched 2026-08-31 · section: delivery-and-acknowledgment -->
# Delivery and acknowledgment

The [reading-back](/learn/jetstream/reading-back.md) and [filtering](/learn/jetstream/filtering.md) pages created consumers — `billing` to read the stream back, then `analytics` to filter it — and acked each message on the happy path, where every message succeeded. This page is the part those pages took for granted: what an acknowledgment actually does, and what happens to a message that's delivered but never acked.

That's the **ack/redeliver loop**, and it's one of the pieces that give JetStream its **at-least-once** delivery: a message stays available and is redelivered until a reader confirms it, so it's handled at least once even when things fail. A reader can crash mid-message, a handler can throw, a process can be killed — and the message it was working on comes back instead of vanishing. (At-least-once also leans on the durable stream from the earlier pages; the ack loop is the consumer half.)

You already have the orders in `ORDERS` and the `billing` and `analytics` consumers from the previous pages.

## A consumer to experiment with

The demos below deliberately skip an ack to watch a message come back, so they're easier to follow on a consumer of their own. Create one named `shipping` — a pull consumer with explicit ack, the same kind you made on the previous pages:

#### CLI

```
#!/bin/bash

# Create a durable pull consumer named `shipping` on the ORDERS stream.

# --pull: reader fetches messages on demand (pull consumer)

# --ack explicit: every delivered message must be individually acknowledged

nats consumer add ORDERS shipping --pull --ack explicit --defaults
```

#### JavaScript/TypeScript

```
// Create a durable pull consumer on the ORDERS stream. The durable keeps its

// position under a fixed name, so a reader can come back later and pick up where

// it left off. ack_policy Explicit means the server only advances that position

// once a reader acks each message. deliver_policy All starts from the first

// stored message. add() is idempotent: calling it again with the same config is

// a no-op.

const jsm = await jetstreamManager(nc);

await jsm.consumers.add("ORDERS", {

  durable_name: "shipping",

  ack_policy: AckPolicy.Explicit,

  deliver_policy: DeliverPolicy.All,

});

console.log("Created durable consumer: shipping");
```

#### Go

```
// Create a durable pull consumer named "shipping" on the ORDERS stream.

// DeliverAllPolicy starts from the first message in the stream, and

// AckExplicitPolicy means every message must be acknowledged by hand.

cons, err := js.CreateOrUpdateConsumer(ctx, "ORDERS", jetstream.ConsumerConfig{

	Durable:       "shipping",

	DeliverPolicy: jetstream.DeliverAllPolicy,

	AckPolicy:     jetstream.AckExplicitPolicy,

})

if err != nil {

	panic(err)

}



// Confirm the consumer is ready.

fmt.Printf("Created consumer: %s\n", cons.CachedInfo().Name)
```

#### Python

```
# Create a durable pull consumer that reads the whole stream from the start.

# add_consumer is idempotent: calling it again with the same config is a no-op.

await js.add_consumer(

    "ORDERS",

    ConsumerConfig(

        durable_name="shipping",

        ack_policy=AckPolicy.EXPLICIT,

        deliver_policy=DeliverPolicy.ALL,

    ),

)

print("Created durable consumer shipping on stream ORDERS")
```

#### Java

```
// Create a durable pull consumer that delivers every stored message.

// AckPolicy.Explicit means each message must be acknowledged.

ConsumerContext cc = sc.createOrUpdateConsumer(

    ConsumerConfiguration.builder()

        .durable("shipping")

        .deliverPolicy(DeliverPolicy.All)

        .ackPolicy(AckPolicy.Explicit)

        .build());



System.out.println("Created durable consumer: " + cc.getConsumerName());
```

#### Rust

```
// Create a durable pull consumer that starts at the first stored message

// and acknowledges each message explicitly, so the server tracks progress.

let stream = js.get_stream("ORDERS").await?;

let consumer = stream

    .create_consumer(pull::Config {

        durable_name: Some("shipping".to_string()),

        deliver_policy: DeliverPolicy::All,

        ack_policy: AckPolicy::Explicit,

        ..Default::default()

    })

    .await?;



println!("Created durable consumer: {}", consumer.cached_info().name);
```

#### C#/.NET

```
// Create a durable pull consumer that delivers every stored message from the start

var consumer = await js.CreateOrUpdateConsumerAsync("ORDERS", new ConsumerConfig("shipping")

{

    AckPolicy = ConsumerConfigAckPolicy.Explicit,

    DeliverPolicy = ConsumerConfigDeliverPolicy.All,

});



output.WriteLine($"Created durable consumer {consumer.Info.Config.Name} on stream ORDERS");
```

#### C

```
// Create a durable pull consumer named "shipping" on the ORDERS stream.

// js_DeliverAll starts from the first message in the stream, and

// js_AckExplicit means every message must be acknowledged by hand.

jsConsumerConfig cfg;



jsConsumerConfig_Init(&cfg);

cfg.Durable       = "shipping";

cfg.DeliverPolicy = js_DeliverAll;

cfg.AckPolicy     = js_AckExplicit;



s = js_AddConsumer(&ci, js, "ORDERS", &cfg, NULL, &jerr);

if (s == NATS_OK)

{

    // Confirm the consumer is ready.

    printf("Created consumer: %s\n", ci->Name);

}
```

It starts at the beginning of `ORDERS`, so it has the stored orders to work through.

## The delivery lifecycle

A message moves through a few states on a consumer:

1. **Delivered, in flight.** The consumer hands the message to a reader. The message stays in the stream, and the consumer's **acknowledgment floor** — how far it has confirmed handling — hasn't moved past it. The message is in flight: out with a reader, not yet confirmed.
2. **Acked.** The reader processes the message and sends an **ack**. The floor advances past it; the message is done as far as this consumer is concerned.
3. **Redelivered.** If no ack arrives within the **Ack Wait** deadline, the server assumes the reader failed and delivers the message again — to the same reader or another one on the same consumer.

**Message flow — Consumers with independent cursors (animated):** Three consumers read one 8-message stream from independent positions. Inventory, Email, and Analytics each start at a different point and move at their own speed, and each keeps its own cursor — one consumer catching up never moves another's position. The stream holds a single shared copy of every message and serves each consumer from where it left off.

The gap between what's been delivered and what's been acked is the set of in-flight messages. The rest of this page opens and closes that gap on purpose.

## Acknowledge a message

Pull one message from `shipping` and ack it:

#### CLI

```
#!/bin/bash

# Pull one message from the `shipping` consumer and acknowledge it.

# --ack (default) acks each received message, advancing the durable cursor.

nats consumer next ORDERS shipping --ack
```

#### JavaScript/TypeScript

```
// Bind to the existing durable and pull one message with next(). Handle it, then

// ack() so the server advances the consumer past it and won't redeliver it.

const js = jetstream(nc);

const c = await js.consumers.get("ORDERS", "shipping");



const m = await c.next();

if (m) {

  console.log(`${m.subject}: ${m.string()}`);

  m.ack();

} else {

  console.log("nothing to read");

}
```

#### Go

```
// Bind to the durable "shipping" consumer created earlier.

cons, err := js.Consumer(ctx, "ORDERS", "shipping")

if err != nil {

	panic(err)

}



// Fetch a single message from the consumer.

msg, err := cons.Next()

if err != nil {

	panic(err)

}

fmt.Printf("Received on %s: %s\n", msg.Subject(), string(msg.Data()))



// Acknowledge so the server advances the consumer past this message.

if err := msg.Ack(); err != nil {

	panic(err)

}
```

#### Python

```
# Bind to the durable consumer and pull a single message.

psub = await js.pull_subscribe_bind("shipping", stream="ORDERS")



msgs = await psub.fetch(batch=1, timeout=5)

msg = msgs[0]

print(f"{msg.subject}: {msg.data.decode()}")



# Explicit ack removes the message from this consumer's pending list.

await msg.ack()
```

#### Java

```
// Pull one message, process it, then acknowledge so the server

// advances the consumer and never redelivers this message.

Message m = cc.next(Duration.ofSeconds(5));

if (m == null) {

    System.out.println("Nothing to read.");

    return;

}



System.out.printf("subject=%s data=%s%n",

    m.getSubject(),

    new String(m.getData(), StandardCharsets.UTF_8));



m.ack();
```

#### Rust

```
// Bind to the existing durable consumer.

let stream = js.get_stream("ORDERS").await?;

let consumer: PullConsumer = stream.get_consumer("shipping").await?;



// Fetch a single message, process it, then acknowledge it.

let mut messages = consumer.fetch().max_messages(1).messages().await?;

while let Some(msg) = messages.next().await {

    let msg = msg?;

    println!("{}: {}", msg.subject, std::str::from_utf8(&msg.payload)?);

    // Acknowledge so the server records this message as handled.

    msg.ack().await?;

}
```

#### C#/.NET

```
// Bind to the existing durable consumer

var consumer = await js.GetConsumerAsync("ORDERS", "shipping");



// Pull one message and process it

var msg = await consumer.NextAsync<Order>();

if (msg is { } order)

{

    output.WriteLine($"{order.Subject}: {order.Data}");



    // Acknowledge the message so the consumer advances past it

    await order.AckAsync();

}
```

#### C

```
// Bind to the durable "shipping" consumer created earlier.

jsSubOptions so;



jsSubOptions_Init(&so);

so.Stream   = "ORDERS";

so.Consumer = "shipping";



s = js_PullSubscribe(&sub, js, NULL, NULL, NULL, &so, &jerr);



// Fetch a single message from the consumer.

if (s == NATS_OK)

    s = natsSubscription_Fetch(&list, sub, 1, 5000, &jerr);

if (s == NATS_OK)

{

    natsMsg *msg = list.Msgs[0];



    printf("Received on %s: %.*s\n",

           natsMsg_GetSubject(msg),

           natsMsg_GetDataLength(msg),

           natsMsg_GetData(msg));



    // Acknowledge so the server advances the consumer past this message.

    s = natsMsg_Ack(msg, NULL);

}
```

You get the first stored order, and the ack confirms it:

```
[10:14:52] subj: orders.created / tries: 1 / cons seq: 1 / str seq: 1 / pending: 2



{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}



Acknowledged message
```

`tries: 1` is the delivery count — this is the first time the message has gone out. Check the consumer:

```
State:



  Last Delivered Message: Consumer sequence: 1 Stream sequence: 1

    Acknowledgment Floor: Consumer sequence: 1 Stream sequence: 1

        Outstanding Acks: 0 out of maximum 1,000

    Redelivered Messages: 0
```

Both cursors advanced to sequence 1: delivered, then acked, with nothing left in flight. You read the `tries`, sequences, and pending count off the delivered message itself — no `nats consumer info` call needed, as the previous pages noted. The full `State` block is here only to show the floor moving.

## Double ack: make sure the ack landed

A plain ack is fire-and-forget. The client sends it and moves on without waiting to hear that the server recorded it. Almost always that's fine. But if the ack is lost on the way to the server — a connection drops at the wrong moment — the server never advances the floor, Ack Wait elapses, and the message is redelivered. The reader handled it once and will see it again.

A **double ack** closes that window. The client sends the ack and waits for the server to confirm it before treating the message as done. Reach for it when reprocessing a message would be harmful and you can't make the handler idempotent — a payment capture, say. It costs a round-trip per message, so it's a deliberate choice, not the default.

**Message flow — Plain ack vs double ack (animated):** Plain ack versus double ack. In both, the server (the consumer) delivers a message to the client and the client sends an ack back. With a plain ack the client moves on the instant it sends the ack (fire-and-forget). With a double ack the ack is a request: the client waits for the server to confirm the ack landed before treating the message as done.

There's no CLI flag for it — a double ack is a client-library call. Pull a message and double-ack it:

#### JavaScript/TypeScript

```
// Bind to the existing durable and pull one message with next(). ackAck() sends

// the ack and waits for the server to confirm it landed, so you know the

// consumer position advanced before moving on. Plain ack() is fire-and-forget.

const js = jetstream(nc);

const c = await js.consumers.get("ORDERS", "shipping");



const m = await c.next();

if (m) {

  console.log(`${m.subject}: ${m.string()}`);

  await m.ackAck();

} else {

  console.log("nothing to read");

}
```

#### Go

```
// Bind to the durable "shipping" consumer created earlier.

cons, err := js.Consumer(ctx, "ORDERS", "shipping")

if err != nil {

	panic(err)

}



// Fetch a single message from the consumer.

msg, err := cons.Next()

if err != nil {

	panic(err)

}

fmt.Printf("Received on %s: %s\n", msg.Subject(), string(msg.Data()))



// DoubleAck blocks until the server confirms it recorded the acknowledgment.

// Use it when losing an ack would be worse than the extra round trip.

if err := msg.DoubleAck(ctx); err != nil {

	panic(err)

}

fmt.Println("Acknowledgment confirmed by the server")
```

#### Python

```
# Bind to the durable consumer and pull a single message.

psub = await js.pull_subscribe_bind("shipping", stream="ORDERS")



msgs = await psub.fetch(batch=1, timeout=5)

msg = msgs[0]

print(f"{msg.subject}: {msg.data.decode()}")



# Double ack: wait for the server to confirm the ack was recorded.

await msg.ack_sync()
```

#### Java

```
// Pull one message and acknowledge it with a confirmed ack.

// ackSync waits for the server to confirm the ack was stored, so

// you know the consumer advanced before moving on.

Message m = cc.next(Duration.ofSeconds(5));

if (m == null) {

    System.out.println("Nothing to read.");

    return;

}



System.out.printf("subject=%s data=%s%n",

    m.getSubject(),

    new String(m.getData(), StandardCharsets.UTF_8));



m.ackSync(Duration.ofSeconds(1));

System.out.println("Ack confirmed by server.");
```

#### Rust

```
// Bind to the existing durable consumer.

let stream = js.get_stream("ORDERS").await?;

let consumer: PullConsumer = stream.get_consumer("shipping").await?;



// Fetch a single message and confirm the ack with the server.

let mut messages = consumer.fetch().max_messages(1).messages().await?;

while let Some(msg) = messages.next().await {

    let msg = msg?;

    println!("{}: {}", msg.subject, std::str::from_utf8(&msg.payload)?);

    // double_ack waits for the server to confirm the acknowledgment,

    // so you know the message will not be redelivered.

    msg.double_ack().await?;

}
```

#### C#/.NET

```
// Bind to the existing durable consumer

var consumer = await js.GetConsumerAsync("ORDERS", "shipping");



// Pull one message and process it

var msg = await consumer.NextAsync<Order>();

if (msg is { } order)

{

    output.WriteLine($"{order.Subject}: {order.Data}");



    // Double-ack: wait for the server to confirm the acknowledgment was stored

    await order.AckAsync(new AckOpts { DoubleAck = true });

}
```

#### C

```
// Bind to the durable "shipping" consumer created earlier.

jsSubOptions so;



jsSubOptions_Init(&so);

so.Stream   = "ORDERS";

so.Consumer = "shipping";



s = js_PullSubscribe(&sub, js, NULL, NULL, NULL, &so, &jerr);



// Fetch a single message from the consumer.

if (s == NATS_OK)

    s = natsSubscription_Fetch(&list, sub, 1, 5000, &jerr);

if (s == NATS_OK)

{

    natsMsg *msg = list.Msgs[0];



    printf("Received on %s: %.*s\n",

           natsMsg_GetSubject(msg),

           natsMsg_GetDataLength(msg),

           natsMsg_GetData(msg));



    // AckSync blocks until the server confirms it recorded the

    // acknowledgment. Use it when losing an ack would be worse than

    // the extra round trip.

    s = natsMsg_AckSync(msg, NULL, &jerr);

    if (s == NATS_OK)

        printf("Acknowledgment confirmed by the server\n");

}
```

The call is named differently across clients — `DoubleAck` in Go, `ackAck` in JavaScript, `ack_sync` in Python, `ackSync` in Java, `AckAsync` (with the double-ack option) in .NET, `double_ack` in Rust — but each waits for the server to confirm the ack before returning.

## Redelivery: when a message isn't acked

To see redelivery, pull a message but skip the ack:

#### CLI

```
#!/bin/bash

# Pull one message from the `shipping` consumer but skip the ack.

# --no-ack leaves the message in flight; after Ack Wait elapses it is redelivered.

nats consumer next ORDERS shipping --no-ack
```

#### JavaScript/TypeScript

```
// Bind to the existing durable and pull one message with next(). Here we handle

// it but never ack. The message stays in flight: once Ack Wait passes with no

// ack, the server redelivers it to a reader of this consumer.

const js = jetstream(nc);

const c = await js.consumers.get("ORDERS", "shipping");



const m = await c.next();

if (m) {

  console.log(`${m.subject}: ${m.string()}`);

  // no ack here — the message stays in flight and is redelivered after Ack Wait

} else {

  console.log("nothing to read");

}
```

#### Go

```
// Bind to the durable "shipping" consumer created earlier.

cons, err := js.Consumer(ctx, "ORDERS", "shipping")

if err != nil {

	panic(err)

}



// Fetch a single message from the consumer.

msg, err := cons.Next()

if err != nil {

	panic(err)

}

fmt.Printf("Received on %s: %s\n", msg.Subject(), string(msg.Data()))



// We deliberately do not acknowledge this message. It stays in flight, and

// the server redelivers it once the consumer's Ack Wait window elapses.
```

#### Python

```
# Bind to the durable consumer and pull a single message.

psub = await js.pull_subscribe_bind("shipping", stream="ORDERS")



msgs = await psub.fetch(batch=1, timeout=5)

msg = msgs[0]

print(f"{msg.subject}: {msg.data.decode()}")



# No ack here. The message stays in flight and is redelivered after Ack Wait.
```

#### Java

```
// Pull one message but do not acknowledge it. Because there is no

// ack, the message stays in flight and the server redelivers it

// after the consumer's Ack Wait window expires.

Message m = cc.next(Duration.ofSeconds(5));

if (m == null) {

    System.out.println("Nothing to read.");

    return;

}



System.out.printf("subject=%s data=%s%n",

    m.getSubject(),

    new String(m.getData(), StandardCharsets.UTF_8));

// No m.ack() — the message is redelivered after Ack Wait.
```

#### Rust

```
// Bind to the existing durable consumer.

let stream = js.get_stream("ORDERS").await?;

let consumer: PullConsumer = stream.get_consumer("shipping").await?;



// Fetch a single message and read it, but do not acknowledge it.

let mut messages = consumer.fetch().max_messages(1).messages().await?;

while let Some(msg) = messages.next().await {

    let msg = msg?;

    println!("{}: {}", msg.subject, std::str::from_utf8(&msg.payload)?);

    // Without an ack the message stays in flight and the server

    // redelivers it once the Ack Wait period expires.

}
```

#### C#/.NET

```
// Bind to the existing durable consumer

var consumer = await js.GetConsumerAsync("ORDERS", "shipping");



// Pull one message and look at it

var msg = await consumer.NextAsync<Order>();

if (msg is { } order)

{

    output.WriteLine($"{order.Subject}: {order.Data}");



    // No Ack here: the message stays in flight and is redelivered after Ack Wait

}
```

#### C

```
// Bind to the durable "shipping" consumer created earlier.

jsSubOptions so;



jsSubOptions_Init(&so);

so.Stream   = "ORDERS";

so.Consumer = "shipping";



s = js_PullSubscribe(&sub, js, NULL, NULL, NULL, &so, &jerr);



// Fetch a single message from the consumer.

if (s == NATS_OK)

    s = natsSubscription_Fetch(&list, sub, 1, 5000, &jerr);

if (s == NATS_OK)

{

    natsMsg *msg = list.Msgs[0];



    printf("Received on %s: %.*s\n",

           natsMsg_GetSubject(msg),

           natsMsg_GetDataLength(msg),

           natsMsg_GetData(msg));

}



// We deliberately do not acknowledge this message. It stays in flight,

// and the server redelivers it once the consumer's Ack Wait window

// elapses.
```

This delivers the next order, sequence 2, and leaves it in flight. The state now shows the gap:

```
State:



  Last Delivered Message: Consumer sequence: 2 Stream sequence: 2

    Acknowledgment Floor: Consumer sequence: 1 Stream sequence: 1

        Outstanding Acks: 1 out of maximum 1,000

    Redelivered Messages: 0
```

Last Delivered moved to 2, but the Acknowledgment Floor stayed at 1. That one message is in flight: `Outstanding Acks: 1`. Wait out the Ack Wait deadline — 30 seconds by default — pull again, and the server hands you sequence 2 a second time, now with `tries: 2`. It came back because you never acked it.

A redelivery doesn't slot back into stream order. A consumer usually has several messages in flight at once — the `out of maximum 1,000` in the state above is **MaxAckPending**, the cap on how many it delivers before they're acked. While one message waits to be redelivered, the consumer keeps handing out later ones, so the repeat can arrive *after* messages with higher sequence numbers.

**Message flow — Out-of-order redelivery (animated):** Redelivery is in delivery order, not stream order. A consumer delivers messages 1 through 5; the client acks 1, 2, 4, and 5 but skips 3. While 3 sits unacked an Ack Wait timer fills; when it completes the server redelivers message 3, so it arrives after 4 and 5 — out of stream order — and the client acks it that second time, before the consumer continues with message 6.

If a consumer must process strictly in order, set MaxAckPending to 1. It then delivers one message at a time and won't move past it until it's acked, so a redelivery always comes back before anything new:

```
nats consumer edit ORDERS shipping --max-pending 1
```

That ordering guarantee costs throughput — one message in flight means no overlap between handlers — so use it only when order actually matters.

A reader doesn't have to wait out the deadline, and a stuck message doesn't have to retry forever. A reader can answer a message in other ways — ask for an immediate retry, give up on a message that can never be handled, or signal that it's still working — and the server has controls that decide how long it waits between retries and when it stops. Those responses and controls are the [next page](/learn/jetstream/acknowledgment.md).

## Pitfalls

**Forgetting to ack.** A handler that processes a message but never acks looks identical to a crashed reader: the message stays in flight, Ack Wait elapses, and it's redelivered — and with the default unlimited delivery limit, that repeats forever. Always ack on the success path. The [next page](/learn/jetstream/acknowledgment.md) covers how to retire a message that genuinely can't be processed, so it stops coming back.

**Acking the same message twice.** Once you ack a message, the floor moves past it. A second ack does nothing useful. Some clients (Go, Python) reject it locally with *"message was already acknowledged"*; others ignore or resend it, and the server ignores the duplicate either way. Ack each delivery exactly once, in one place in your handler.

## Where you are

`shipping` is a durable pull consumer with explicit ack, and you've seen the core of the loop:

* a message is **delivered** and held **in flight** until it's confirmed
* an **ack** (or a **double ack**, when a lost ack would hurt) advances the acknowledgment floor past it
* an unacked message is **redelivered** after the Ack Wait deadline

The delivery count (`tries`) rides along on each message, so a reader always knows how many times it's seen one.

## What's next

You've seen the happy path and that an unacked message comes back. The next page goes deep on the four ways a client answers a message — ack, nak, term, and in-progress — and the server controls (Ack Wait, MaxDeliver, backoff) that decide when a message comes back and when it stops.

## See also

* [Reference → Create Consumer](/reference/jetstream/api/consumer/create.md) — every consumer option, the four ack policies, and push consumers.
