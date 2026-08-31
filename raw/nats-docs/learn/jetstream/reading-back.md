<!-- source: https://docs.nats.io/learn/jetstream/reading-back.md · fetched 2026-08-31 · section: reading-back -->
# Reading back the stream

The `ORDERS` stream holds the orders you published on the previous page. So far you've only seen them through `nats stream info`, which counts the messages but doesn't show their contents.

This page reads them back through Acme's **billing** service. Billing acts on every order — it charges the customer when one is created, captures the payment when it ships, refunds a cancellation — so when it first comes up, or restarts after downtime, it has to work through the whole stream from the first order and miss none. That's a durable consumer reading the log from sequence 1, which is what this page builds. First, the three pieces that move a message from a publisher to a reader.

You might have run the publish commands once, or a few times while experimenting, so the stream could hold three messages or thirty. None of the steps below assume a number: they read back whatever is there.

## How a producer, a stream, and a consumer fit together

Three pieces move a message through JetStream:

* A **producer** publishes messages to a subject, reads the `PubAck` and retries on failure.
* A **stream** stores the messages, in order. As it stores each one it assigns a **stream sequence**, the message's position in the store.
* A **consumer** is a server-side cursor on a stream. A **client** connects to it to receive messages; the consumer tracks how far that client has progressed and hands out the next one. Each consumer keeps its own **consumer sequence**, a counter the server bumps on every delivery — redeliveries included — so it counts deliveries, not distinct messages.

**Message flow — Producer, stream, and consumer (animated):** Animated JetStream pipeline: a producer publishes into the ORDERS stream, where each message gets a fixed stream sequence; one consumer then reads the stored messages in order, advancing its own consumer sequence, and hands each to a client. The stream sequence is the message's position in the log; the consumer sequence is how many messages this consumer has read.

A stream can feed many consumers at once, each reading at its own pace and each with its own position. This page uses one consumer; later pages add more.

## Streams keep messages

In core NATS, a message published to a subject exists only as long as it takes to reach whoever is subscribed right now. The [Why a stream](/learn/jetstream/your-first-stream.md#why-a-stream) page covers why that's too short for orders.

A stream keeps its messages. They're durable records with fixed stream sequences. They don't disappear when you read them, and they don't move. Reading message 1 leaves message 1 where it was, available to the next reader. You can re-read a stream whenever you want: a new consumer created a month from now starts at the same sequence 1 you're about to read today.

## A consumer is a server-side object

To read a stream you create a consumer. A consumer isn't part of your application; it's an object on the server, sitting next to the stream. Your application is the **client**: it connects to the consumer to receive messages. The stored messages and the read position both stay on the server, so the client can disconnect and reconnect without losing its place or tracking any sequence numbers itself.

**Message flow — A consumer is server-side (animated):** Architecture diagram: the NATS server contains two entities, the ORDERS stream (the stored messages) and the billing consumer (a server-side cursor over the stream). A separate client application connects from outside the server: it pulls messages from the consumer and receives them. The stored messages and the read position both live on the server, not in the client.

Create a consumer named `billing`:

#### CLI

```
#!/bin/bash



# Create a named, durable consumer on the ORDERS stream.

# A durable consumer has a name you choose. The server keeps its position on

# disk under that name, so a reader resumes where it left off after a

# disconnect or a server restart instead of starting over.

#   --deliver all   start at the first message in the stream (sequence 1)

#   --pull          the reader asks for messages when it's ready

#   --ack explicit  acknowledge each message; the position advances only once

#                   a message is acked (the default for a pull consumer)

nats consumer add ORDERS billing \

  --deliver all \

  --pull \

  --ack explicit \

  --defaults
```

#### JavaScript/TypeScript

```
// Create a durable consumer on the ORDERS stream. A durable keeps its position

// under a fixed name, so a reader can come back later and pick up where it left

// off. With explicit acks the server only advances that position once a reader

// acks each message. add() is idempotent: calling it again with the same config

// is a no-op.

const jsm = await jetstreamManager(nc);

await jsm.consumers.add("ORDERS", {

  durable_name: "billing",

  ack_policy: AckPolicy.Explicit,

  deliver_policy: DeliverPolicy.All,

});

console.log("Created durable consumer: billing");
```

#### Go

```
// Create a durable consumer on the ORDERS stream. The durable name lets a

// reader bind to the same consumer later and pick up where it left off.

cons, err := js.CreateOrUpdateConsumer(ctx, "ORDERS", jetstream.ConsumerConfig{

	Durable:       "billing",

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
# Create a durable consumer that reads the whole stream from the start.

# add_consumer is idempotent: calling it again with the same config is a no-op.

await js.add_consumer(

    "ORDERS",

    ConsumerConfig(

        durable_name="billing",

        ack_policy=AckPolicy.EXPLICIT,

        deliver_policy=DeliverPolicy.ALL,

    ),

)

print("Created durable consumer billing on stream ORDERS")
```

#### Java

```
// Create a durable consumer that delivers every stored message.

// AckPolicy.Explicit means each message must be acknowledged.

ConsumerContext cc = sc.createOrUpdateConsumer(

    ConsumerConfiguration.builder()

        .durable("billing")

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

        durable_name: Some("billing".to_string()),

        deliver_policy: DeliverPolicy::All,

        ack_policy: AckPolicy::Explicit,

        ..Default::default()

    })

    .await?;



println!("Created durable consumer: {}", consumer.cached_info().name);
```

#### C#/.NET

```
// Create a durable consumer that delivers every stored message from the start

var consumer = await js.CreateOrUpdateConsumerAsync("ORDERS", new ConsumerConfig("billing")

{

    AckPolicy = ConsumerConfigAckPolicy.Explicit,

    DeliverPolicy = ConsumerConfigDeliverPolicy.All,

});



output.WriteLine($"Created durable consumer {consumer.Info.Config.Name} on stream ORDERS");
```

#### C

```
// Create a durable consumer on the ORDERS stream. The durable name

// lets a reader bind to the same consumer later and pick up where it

// left off.

jsConsumerInfo      *ci = NULL;

jsConsumerConfig    cc;



jsConsumerConfig_Init(&cc);

cc.Durable       = "billing";

cc.DeliverPolicy = js_DeliverAll;

cc.AckPolicy     = js_AckExplicit;



s = js_AddConsumer(&ci, js, "ORDERS", &cc, NULL, &jerr);

if (s == NATS_OK)

{

    // Confirm the consumer is ready.

    printf("Created consumer: %s\n", ci->Name);

    jsConsumerInfo_Destroy(ci);

}
```

Three settings define how it reads:

* **Deliver all** starts the consumer at the first message in the stream, sequence 1, so it reads the whole log.
* **Pull** means the client asks the server for messages when it's ready, rather than having the server push them on its own. Pull is the default for new consumers; an older push model exists, but the consumers you create in this chapter are pull.
* **Ack explicit** means the client acknowledges each message it handles, and the consumer's position advances only as acks arrive. It's the default for a pull consumer. On this page you read and ack on the happy path; a [later page](/learn/jetstream/delivery-and-acknowledgment.md) digs into what acknowledgment buys you — the redelivery loop that makes delivery reliable.

Look at the consumer before it has read anything:

```
nats consumer info ORDERS billing
```

```
State:



  Last Delivered Message: Consumer sequence: 0 Stream sequence: 0

    Acknowledgment Floor: Consumer sequence: 0 Stream sequence: 0

        Outstanding Acks: 0 out of maximum 1,000

    Redelivered Messages: 0

    Unprocessed Messages: 3

           Waiting Pulls: 0 of maximum 512
```

`Unprocessed Messages` is how many stored messages the consumer hasn't delivered yet: the whole stream, since it hasn't started. Yours shows however many you published. The acknowledgment fields below it stay at zero until the consumer starts delivering and acking; the next page works through them.

## Read the stored messages

Now read. Binding to the consumer reuses its position, delivers everything it hasn't seen, and acknowledges each message as it goes:

#### CLI

```
#!/bin/bash



# Read every message the stream currently holds, in order, then stop.

# Binding 'nats sub' to the durable consumer reuses its on-disk position.

#   --stream ORDERS --durable billing  bind to the durable consumer

#   --terminate-at-end                       stop once all stored messages are read

#   --ack                                    acknowledge each message it delivers

#

# This makes no assumption about how many messages are stored: it reads

# whatever is there and stops when 'pending' reaches 0.

nats sub --stream ORDERS --durable billing --terminate-at-end --ack
```

#### JavaScript/TypeScript

```
// Bind to the existing durable and read every stored message in order. Ask the

// consumer how many are waiting (num_pending) instead of guessing a count, then

// fetch exactly that many. Ack each message after handling it so the server

// advances the consumer past it and won't redeliver it.

const js = jetstream(nc);

const c = await js.consumers.get("ORDERS", "billing");

const info = await c.info();

const n = info.num_pending;



if (n === 0) {

  console.log("nothing to read");

} else {

  const msgs = await c.fetch({ max_messages: Number(n) });

  for await (const m of msgs) {

    console.log(

      `stream seq ${m.info.streamSequence}, delivery seq ${m.info.deliverySequence}: ${m.string()}`,

    );

    await m.ack();

  }

}
```

#### Go

```
// Bind to the durable consumer created earlier.

cons, err := js.Consumer(ctx, "ORDERS", "billing")

if err != nil {

	panic(err)

}



// Ask the consumer how many messages are still waiting, then read exactly

// that many. This drains everything stored without assuming a count.

info, err := cons.Info(ctx)

if err != nil {

	panic(err)

}

pending := info.NumPending

if pending == 0 {

	fmt.Println("nothing to read")

	return

}



msgs, err := cons.Fetch(int(pending))

if err != nil {

	panic(err)

}



for msg := range msgs.Messages() {

	// Metadata carries the position of this message in the stream and in

	// the consumer's own delivery sequence.

	meta, err := msg.Metadata()

	if err != nil {

		panic(err)

	}

	fmt.Printf("stream seq=%d consumer seq=%d payload=%s\n",

		meta.Sequence.Stream, meta.Sequence.Consumer, string(msg.Data()))



	// Acknowledge so the server advances the consumer past this message.

	if err := msg.Ack(); err != nil {

		panic(err)

	}

}

if msgs.Error() != nil {

	panic(msgs.Error())

}
```

#### Python

```
# Bind to the durable consumer created earlier and pull every stored message.

psub = await js.pull_subscribe_bind("billing", stream="ORDERS")



# Fetch in batches until a fetch times out, which means the stream is drained.

# The consumer uses explicit ack, so acknowledge each message after handling it.

while True:

    try:

        msgs = await psub.fetch(batch=100, timeout=1)

    except nats.errors.TimeoutError:

        break



    for msg in msgs:

        print(

            f"stream seq {msg.metadata.sequence.stream}, "

            f"consumer seq {msg.metadata.sequence.consumer}: "

            f"{msg.data.decode()}"

        )

        await msg.ack()
```

#### Java

```
// Ask the consumer how many messages are still waiting, then fetch

// exactly that many so the loop ends without guessing a count.

long pending = cc.getConsumerInfo().getNumPending();

if (pending == 0) {

    System.out.println("Nothing to read.");

    return;

}



try (FetchConsumer fc = cc.fetch(

        FetchConsumeOptions.builder().maxMessages((int) pending).build())) {

    Message m;

    while ((m = fc.nextMessage()) != null) {

        System.out.printf("stream_seq=%d consumer_seq=%d data=%s%n",

            m.metaData().streamSequence(),

            m.metaData().consumerSequence(),

            new String(m.getData(), StandardCharsets.UTF_8));

        // Acknowledge each message so the server advances the consumer.

        m.ack();

    }

}
```

#### Rust

```
// Bind to the existing durable consumer.

let stream = js.get_stream("ORDERS").await?;

let mut consumer: PullConsumer = stream.get_consumer("billing").await?;



// Ask the consumer how many messages are still waiting, then fetch exactly

// that many. This reads everything in order without assuming a count.

let pending = consumer.info().await?.num_pending;

if pending == 0 {

    println!("nothing to read");

    return Ok(());

}



let mut messages = consumer

    .fetch()

    .max_messages(usize::try_from(pending).unwrap_or(usize::MAX))

    .messages()

    .await?;

while let Some(msg) = messages.next().await {

    let msg = msg?;

    let info = msg.info()?;

    println!(

        "stream {} consumer {}: {}",

        info.stream_sequence,

        info.consumer_sequence,

        std::str::from_utf8(&msg.payload)?

    );

    // Acknowledge so the server records this message as read.

    msg.ack().await?;

}
```

#### C#/.NET

```
// Bind to the existing durable consumer

var consumer = await js.GetConsumerAsync("ORDERS", "billing");



// Read exactly what the stream is holding, no count assumed up front

var pending = (long)consumer.Info.NumPending;

if (pending == 0)

{

    output.WriteLine("nothing to read");

}

else

{

    await foreach (var msg in consumer.FetchAsync<Order>(opts: new NatsJSFetchOpts { MaxMsgs = (int)pending }))

    {

        output.WriteLine($"stream {msg.Metadata?.Sequence.Stream} consumer {msg.Metadata?.Sequence.Consumer}: {msg.Data}");

        read++;



        // Acknowledge each message so the consumer advances past it

        await msg.AckAsync();

    }

}
```

#### C

```
// Ask the consumer how many messages are still waiting, then read

// exactly that many. This drains everything stored without assuming

// a count.

jsConsumerInfo  *ci     = NULL;

uint64_t        pending = 0;



s = js_GetConsumerInfo(&ci, js, "ORDERS", "billing", NULL, &jerr);

if (s == NATS_OK)

{

    pending = ci->NumPending;

    jsConsumerInfo_Destroy(ci);

}

if ((s == NATS_OK) && (pending == 0))

    printf("nothing to read\n");



if ((s == NATS_OK) && (pending > 0))

{

    // Bind to the durable consumer created earlier and fetch the

    // pending messages.

    jsSubOptions so;

    natsMsgList  list = {NULL, 0};



    jsSubOptions_Init(&so);

    so.Stream   = "ORDERS";

    so.Consumer = "billing";



    s = js_PullSubscribe(&sub, js, NULL, NULL, NULL, &so, &jerr);

    if (s == NATS_OK)

        s = natsSubscription_Fetch(&list, sub, (int) pending, 5000, &jerr);

    if (s == NATS_OK)

    {

        for (int i = 0; i < list.Count; i++)

        {

            // Metadata carries the position of this message in the

            // stream and in the consumer's own delivery sequence.

            jsMsgMetaData *meta = NULL;



            s = natsMsg_GetMetaData(&meta, list.Msgs[i]);

            if (s != NATS_OK)

                break;



            printf("stream seq=%" PRIu64 " consumer seq=%" PRIu64 " payload=%s\n",

                   meta->Sequence.Stream, meta->Sequence.Consumer,

                   natsMsg_GetData(list.Msgs[i]));

            jsMsgMetaData_Destroy(meta);



            // Acknowledge so the server advances the consumer past

            // this message.

            natsMsg_Ack(list.Msgs[i], NULL);

        }

        natsMsgList_Destroy(&list);

    }

}
```

The messages arrive oldest first, each with its stream sequence:

```
[#1] Received JetStream message: stream: ORDERS seq: 1 / pending: 2 / subject: orders.created / time: 2026-05-22 10:14:22

{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}



[#2] Received JetStream message: stream: ORDERS seq: 2 / pending: 1 / subject: orders.created / time: 2026-05-22 10:14:25

{"order_id":"ord_2zr9","customer":"globex","total_cents":7800,"ts":"2026-05-22T10:14:25Z"}



[#3] Received JetStream message: stream: ORDERS seq: 3 / pending: 0 / subject: orders.shipped / time: 2026-05-22 10:14:31

{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:31Z"}
```

The `pending` count is how many stored messages are still waiting. It falls by one with each message and the read stops when it reaches `0`, whether the stream held three messages or three hundred. The stream sequences (`seq: 1`, `2`, `3`) match what `nats stream info` reported on the previous page. You're reading the same append-only log, in order.

## Stream sequence versus consumer sequence

Read the consumer again, now that it has caught up:

```
nats consumer info ORDERS billing
```

```
State:



  Last Delivered Message: Consumer sequence: 3 Stream sequence: 3

    Acknowledgment Floor: Consumer sequence: 3 Stream sequence: 3

    Unprocessed Messages: 0
```

`Last Delivered Message` carries the two sequence numbers side by side, and they're worth telling apart:

* **Stream sequence** is the message's fixed position in the log. The server assigned it when the message was published, and it never changes. It's the same number you saw in the `PubAck` and in `nats stream info`.
* **Consumer sequence** is this consumer's own counter. The server adds one every time the consumer delivers a message, redeliveries included, so it tracks how many deliveries this consumer has made, not how many distinct messages it has seen.

Here both read `3` because `billing` started at the beginning and read straight through, so its third delivery was stream message 3. They drift apart whenever a consumer delivers a different set of messages than the stream stores in order: one that starts partway through, one that [filters](/learn/jetstream/filtering.md) to a subset of subjects, or one that has a message [redelivered](/learn/jetstream/delivery-and-acknowledgment.md). The consumer sequence counts deliveries; the stream sequence stays pinned to the message.

You read these numbers with `nats consumer info`, but in code you rarely need that call. Every message a consumer delivers carries the same state in its **metadata** — its stream and consumer sequence, how many messages are still pending, how many times it's been delivered. That metadata rides along with the delivery for free, while `nats consumer info` is a separate request to the server: fine for a one-off check, too costly to call for every message. In a handler, read the state off the message — the read example above already does this, pulling the stream and consumer sequence straight from each delivery.

## The consumer remembers where it stopped

The position you just saw is on disk. To see it work, publish one more order:

```
nats pub --jetstream orders.created \

  '{"order_id":"ord_5xk1","customer":"initech","total_cents":1500,"ts":"2026-05-22T11:02:00Z"}'
```

Then read again with the same command. The consumer delivers only the new message, not the whole log:

```
[#1] Received JetStream message: stream: ORDERS seq: 4 / pending: 0 / subject: orders.created / time: 2026-05-22 11:02:00

{"order_id":"ord_5xk1","customer":"initech","total_cents":1500,"ts":"2026-05-22T11:02:00Z"}
```

It resumed from where it left off. A disconnect or a server restart wouldn't change that: the position is durable, tied to the name `billing`. An unnamed reader wouldn't have it, which the next section gets to.

## Reading once without a named consumer

Creating a durable consumer is the right move when a reader comes back. For a throwaway look at a stream you don't need one. Passing `nats sub` a JetStream flag like `--all` switches it from a live core subscription to a stream read: the CLI builds an **ephemeral** consumer, reads the backlog, and discards the consumer when the command exits:

#### CLI

```
#!/bin/bash



# Replay every message stored in the ORDERS stream, from sequence 1.

# 'nats sub' against a stream-bound subject uses an ephemeral consumer

# with no ack by default.

#   --all              start at the beginning of the stream

#   --terminate-at-end stop once all stored messages have been read

nats sub "orders.>" --all --terminate-at-end
```

An ephemeral consumer keeps no position you can return to. It's fine for a one-off read, but for anything you need to resume after an interruption, use the durable consumer from this page: an ephemeral one is removed once it goes idle, and a reconnect then starts over from the beginning. In client code, the same one-pass read has a dedicated form — see [Ordered consumers](/learn/jetstream/ordered-consumer.md).

## The stream is unchanged

Run `nats stream info ORDERS` again. The `State` block holds the same message count and sequences as before the read (plus the one order you just published). Reading a stream doesn't remove its data. Unlike taking an item off a queue, the messages stay in place for the next reader.

## Pitfalls

Reading a stream back is safe, but a few habits cause trouble the first time you point a reader at real data.

**Re-running a caught-up reader waits.** The read command stops once it has delivered everything stored, but if there's nothing new, there's nothing to stop after, so it waits for the next message instead of returning. That's correct for a live subscription and surprising for a one-shot read. To read the current backlog and exit, run it when there's something to read; to watch for new messages, leave it running and let them arrive.

**Replaying a huge stream from the beginning.** `Deliver all` starts at sequence 1 and reads the entire log. On a three-message `ORDERS` stream that's instant. On a stream holding millions of orders it takes time and moves a lot of data. Read the whole history only when you want it. To start elsewhere, create the consumer with a different delivery policy: the most recent messages (`--deliver last`), messages from a window back to now (`--deliver 1h`), or a known sequence (`--deliver 1000`). The full set is in [Reference → Create Consumer](/reference/jetstream/api/consumer/create.md).

Delivery policy sets *where* a consumer starts; a separate **replay policy** sets the *pace* once it's reading. The default, `instant`, hands messages over as fast as the client reads them. The other value, `original`, spaces deliveries out to match the gaps between the messages' original timestamps, replaying recorded traffic at something like its real speed. This chapter uses `instant` throughout; both are listed in [Reference → Create Consumer](/reference/jetstream/api/consumer/create.md).

**Reusing a durable name with a different config.** A durable consumer is identified by its name. Create `billing` again with different settings and the server returns *consumer already exists*; it won't silently reconfigure a consumer a reader is using. Edit the consumer (`nats consumer edit`) instead, or pick a new name.

## Where you are

The `ORDERS` stream is unchanged by reading. You now have:

* the `ORDERS` stream bound to `orders.>`, holding the messages you published
* a durable consumer, `billing`, with a position saved on the server
* a clear split between the **stream sequence** (the message's fixed slot) and the **consumer sequence** (how far a reader has progressed)

## What's next

You've read the log with one consumer and acked each message. The next page adds a second consumer with a filter and shows how several consumers read the same stream as independent views, each at its own position.

## See also

* [Reference → Consumer Configuration](/reference/jetstream/api/consumer/.md) — every consumer option, including delivery policies and ordered consumers.
* [Filtering what you consume](/learn/jetstream/filtering.md) — add a second consumer that reads only the subjects it needs.
