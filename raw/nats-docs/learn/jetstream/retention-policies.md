<!-- source: https://docs.nats.io/learn/jetstream/retention-policies.md · fetched 2026-08-31 · section: retention-policies -->
# Retention policies

The previous page shaped `ORDERS` with limits: how many messages it keeps, for how long, in how many bytes. Those limits decide when a message leaves the stream because the stream ran out of room.

There's a second, separate question: should a message ever leave the stream because a consumer finished with it? Limits don't ask that. A message capped only by age or size stays until its limit hits, read or unread, acked or not.

Some workloads need the other behavior. A job queue wants a message gone once a worker completes it. A fan-out wants a message gone once every interested consumer has seen it. Limits can't express either.

The **retention policy** is the field that does. It decides what makes a message ready to leave the stream. You picked one already, by accepting a default, when you created `ORDERS`.

## The three policies

A stream has exactly one retention policy, fixed by the `retention` field. There are three values.

**Limits** is the default, and the one `ORDERS` has. Messages stay until a limit is reached: `MaxMsgs`, `MaxBytes`, or `MaxAge`, whichever comes first. Consumers reading and acking messages has no effect on what the stream keeps. The stream is a log, and the log holds everything inside its limits.

**Message flow — Limits retention — acks keep the message (animated):** Limits retention. A consumer reads and acks every order in the ORDERS stream, and each one stays in place — acking never removes a message here. Only a limit (MaxAge, MaxBytes, or MaxMsgs) removes one. The read cursor sweeps the stored messages while all of them remain.

**Interest** keeps a message only while some consumer still wants it. A message is removed once *every* consumer whose filter covers it has acked it. If no consumer is interested in a subject, a message on that subject is removed right away.

**Message flow — Interest retention — all-ack and no-interest (animated):** Interest retention, both behaviors. When an order is published on orders.shipped, a subject both consumers subscribe to, it is stored and removed once every consumer has acked it. When an order is published on orders.archived, a subject no consumer subscribes to, it is dropped the instant it is published — no interest, nothing stored.

**WorkQueue** keeps a message only until *one* consumer acks it. The first ack removes the message for everyone. Each message is delivered once and then removed.

**Message flow — WorkQueue retention — first ack drains it (animated):** WorkQueue retention. Each order is delivered to exactly one worker; the first ack removes it for everyone, so the stream drains back to empty. Workers take turns: an order is published, one worker pulls and acks it, and the message is gone.

The three policies differ in who decides a message is finished. Under Limits, the limits decide. Under Interest, every consumer must ack before the message is removed. Under WorkQueue, the first consumer to ack removes it.

Limits still apply under all three. Retention removes a message when consumers are done with it; the stream's limits remove it when the stream grows too old or too large. On an Interest or WorkQueue stream the limits are the backstop that keeps it bounded when consumers fall behind — retention doesn't replace limits, it adds a second way a message can leave.

## Pick the policy from the kind of work

Choose a retention policy from the kind of work the stream does. The policy follows from the work, not the other way around.

**An audit log or event history → Limits.** You want to keep every message for a window of time no matter who read it, and you want to replay from any point. `ORDERS` is this kind of stream. Late consumers, re-reads, and the replay on the reading-back page all depend on messages staying after they're consumed. Limits is the only policy that allows that, which is why it's the default and why `ORDERS` keeps it.

**A fan-out where every consumer must process each message → Interest.** Several independent services each need to handle every order once, and once they all have, the message is no longer needed. The stream stays small because it drops a message once the last interested consumer is done. You get fan-out delivery without an ever-growing log.

**A job queue where each message is work for one worker → WorkQueue.** This is the home for Acme's shipping workers from [Scaling a consumer](/learn/jetstream/worker-pool.md). Each message is an order to ship. One shipping worker claims it, ships it, and acks, and then the task is removed so no one ships the same order twice. The queue drains as the workers keep up, where a log would only grow.

## A WorkQueue stream for the shipping work

`ORDERS` stays Limits; don't change it — it's the record of what customers did. But Acme also has *work* to do on each order: when one is paid, a [shipping worker](/learn/jetstream/worker-pool.md) has to ship it, exactly once. Ship the same order twice and a second parcel goes out the door. That's a job queue, not a log — each task goes to one worker and is gone once it's done. Give it its own `FULFILLMENT` stream with WorkQueue retention:

#### CLI

```
#!/bin/bash



# A WorkQueue stream for the shipping work. Leave ORDERS alone — that's

# the record. FULFILLMENT is a separate queue of paid orders waiting to

# ship, worked by the shipping workers from the Scaling a consumer page.



# --retention work sets the WorkQueue policy. natscli accepts "work" and

# "workq" as aliases. Under WorkQueue a message is removed the moment the

# first consumer acks it, so the queue drains as the workers keep up.

nats stream add FULFILLMENT \

  --subjects "fulfill.>" \

  --retention work \

  --defaults



# Inspect it — the Options block now reads Retention: WorkQueue, where

# ORDERS reads Retention: Limits.

nats stream info FULFILLMENT



# Enqueue one order to ship, then have a shipping worker pull and ack it.

# After the ack the task is gone — the message count drops back to zero,

# which no limit on a Limits stream like ORDERS would ever do.

nats pub fulfill.us '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

nats consumer add FULFILLMENT shippers --pull --ack explicit --defaults

nats consumer next FULFILLMENT shippers --count 1 --ack



# Confirm the ack removed the task: Messages is back to 0.

nats stream info FULFILLMENT
```

#### JavaScript/TypeScript

```
// FULFILLMENT is the queue of paid orders waiting to ship. WorkQueue retention

// means the stream holds each task only until a worker acks it, then drops it.

// That is the opposite of a Limits stream like ORDERS, which keeps the record.

const info = await jsm.streams.add({

  name: "FULFILLMENT",

  subjects: ["fulfill.>"],

  retention: RetentionPolicy.Workqueue,

});

console.log(`Created stream FULFILLMENT, retention: ${info.config.retention}`);



// Queue one order to ship in the US region.

const order = `{"order_id":"ord_8w2k","customer":"acme-co"}`;

const pa = await js.publish("fulfill.us", order);

console.log(`Queued ${pa.stream} seq ${pa.seq}`);



// A durable pull consumer drains the queue. WorkQueue streams require explicit

// ack, so the worker acks each task it finishes.

await jsm.consumers.add("FULFILLMENT", {

  durable_name: "shippers",

  ack_policy: AckPolicy.Explicit,

});



// Pull the order, ship it, and ack. ackAck waits for the server to confirm the

// ack landed, so the next read sees the result.

const c = await js.consumers.get("FULFILLMENT", "shippers");

const msgs = await c.fetch({ max_messages: 1, expires: 5000 });

for await (const m of msgs) {

  console.log(`Shipping ${m.subject}: ${m.string()}`);

  await m.ackAck();

}



// The ack removed the task, so the stream is now empty. A Limits stream would

// still hold the message; a WorkQueue stream drains to zero.

const after = await jsm.streams.info("FULFILLMENT");

console.log(`Messages in FULFILLMENT after ack: ${after.state.messages}`);
```

#### Go

```
// FULFILLMENT is the queue of paid orders awaiting shipment. With WorkQueue

// retention the server keeps each message only until a consumer acks it,

// then deletes it from the stream.

stream, err := js.CreateStream(ctx, jetstream.StreamConfig{

	Name:      "FULFILLMENT",

	Subjects:  []string{"fulfill.>"},

	Retention: jetstream.WorkQueuePolicy,

})

if err != nil {

	panic(err)

}

fmt.Printf("FULFILLMENT retention: %s\n", stream.CachedInfo().Config.Retention)



// Queue one order to ship.

if _, err := js.Publish(ctx, "fulfill.us", []byte(`{"order_id":"ord_8w2k","customer":"acme-co"}`)); err != nil {

	panic(err)

}



// A shipping worker binds to a durable pull consumer with explicit ack.

cons, err := stream.CreateOrUpdateConsumer(ctx, jetstream.ConsumerConfig{

	Durable:   "shippers",

	AckPolicy: jetstream.AckExplicitPolicy,

})

if err != nil {

	panic(err)

}



// Fetch the order and ack it once the worker has shipped it.

msgs, err := cons.Fetch(1)

if err != nil {

	panic(err)

}

for msg := range msgs.Messages() {

	fmt.Printf("shipping order: %s\n", string(msg.Data()))

	if err := msg.Ack(); err != nil {

		panic(err)

	}

}

if msgs.Error() != nil {

	panic(msgs.Error())

}



// The ack removed the task from the queue, so the stream is now empty. A

// Limits stream like ORDERS would still hold the message; a WorkQueue

// stream drains to zero as workers finish.

info, err := stream.Info(ctx)

if err != nil {

	panic(err)

}

fmt.Printf("messages left in FULFILLMENT: %d\n", info.State.Msgs)
```

#### Python

```
# FULFILLMENT is the queue of paid orders awaiting shipment. WorkQueue

# retention delivers each order to a single worker; the first ack removes

# it for everyone, so the stream drains to empty.

info = await js.add_stream(

    StreamConfig(

        name="FULFILLMENT",

        subjects=["fulfill.>"],

        retention=RetentionPolicy.WORK_QUEUE,

    )

)

print(f"FULFILLMENT retention is {info.config.retention}")



# A paid order arrives and needs shipping.

await js.publish(

    "fulfill.us",

    json.dumps({"order_id": "ord_8w2k", "customer": "acme-co"}).encode(),

)



# Shipping workers pull from a durable consumer with explicit ack.

await js.add_consumer(

    "FULFILLMENT",

    ConsumerConfig(durable_name="shippers", ack_policy=AckPolicy.EXPLICIT),

)



# A worker takes one order and acks it once the order has shipped.

psub = await js.pull_subscribe_bind("shippers", stream="FULFILLMENT")

msgs = await psub.fetch(batch=1, timeout=5)

await msgs[0].ack()

print(f"shipped {msgs[0].data.decode()}")



# The ack removed the task, so the WorkQueue stream is now empty. A Limits

# stream like ORDERS would still hold the message after the ack.

info = await js.stream_info("FULFILLMENT")

print(f"messages left in FULFILLMENT: {info.state.messages}")
```

#### Java

```
// FULFILLMENT is the queue of paid orders awaiting shipment, separate

// from the ORDERS record stream. WorkQueue retention delivers each task

// to one consumer; the first ack removes it, so the stream drains to empty.

StreamInfo info = jsm.addStream(StreamConfiguration.builder()

    .name("FULFILLMENT")

    .subjects("fulfill.>")

    .retentionPolicy(RetentionPolicy.WorkQueue)

    .build());



System.out.println("Retention policy: " + info.getConfiguration().getRetentionPolicy());



// Queue one paid order for a US shipper to pick up.

js.publish("fulfill.us",

    "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\"}".getBytes(StandardCharsets.UTF_8));



// A durable pull consumer with explicit ack: a shipping worker must

// acknowledge each task once it has handled the order.

jsm.addOrUpdateConsumer("FULFILLMENT", ConsumerConfiguration.builder()

    .durable("shippers")

    .ackPolicy(AckPolicy.Explicit)

    .build());



// Fetch one task and ack it, as a shipping worker would.

ConsumerContext shippers = js.getConsumerContext("FULFILLMENT", "shippers");

try (FetchConsumer fc = shippers.fetchMessages(1)) {

    Message task = fc.nextMessage();

    System.out.println("Shipping: " + new String(task.getData(), StandardCharsets.UTF_8));

    task.ack();

}



// The ack removed the task, so the WorkQueue stream is now empty.

// A Limits stream like ORDERS would still hold the message.

long count = jsm.getStreamInfo("FULFILLMENT").getStreamState().getMsgCount();

System.out.println("Messages remaining in FULFILLMENT: " + count);
```

#### Rust

```
// FULFILLMENT is the queue of paid orders waiting to ship, separate from the

// ORDERS record. WorkQueue retention means each message is delivered to one

// consumer, and the first ack removes it for everyone, draining the stream.

let mut stream = js

    .create_stream(Config {

        name: "FULFILLMENT".to_string(),

        subjects: vec!["fulfill.>".to_string()],

        retention: RetentionPolicy::WorkQueue,

        ..Default::default()

    })

    .await?;

println!("retention is {:?}", stream.cached_info().config.retention);



// Queue one paid order for a shipper to pick up.

js.publish(

    "fulfill.us",

    r#"{"order_id":"ord_8w2k","customer":"acme-co"}"#.into(),

)

.await?

.await?;



// Shipping workers drain the queue through a durable pull consumer that

// acknowledges each task explicitly.

let consumer = stream

    .create_consumer(pull::Config {

        durable_name: Some("shippers".to_string()),

        ack_policy: AckPolicy::Explicit,

        ..Default::default()

    })

    .await?;



// Take one task and ack it once the order is shipped.

let mut messages = consumer.fetch().max_messages(1).messages().await?;

while let Some(message) = messages.next().await {

    let message = message?;

    println!("shipping {}", std::str::from_utf8(&message.payload)?);

    message.ack().await?;

}



// The ack removed the task from the WorkQueue stream, so the count is now 0.

// A Limits stream like ORDERS would still hold the message after ack.

let count = stream.info().await?.state.messages;

println!("messages left in FULFILLMENT: {count}");
```

#### C#/.NET

```
// FULFILLMENT is the queue of paid orders waiting to ship. WorkQueue

// retention means an order leaves the stream the moment a worker acks it.

var stream = await js.CreateStreamAsync(new StreamConfig(name: "FULFILLMENT", subjects: ["fulfill.>"])

{

    Retention = StreamConfigRetention.Workqueue,

});



output.WriteLine($"FULFILLMENT retention is {stream.Info.Config.Retention}");



// One paid order waiting to ship to a US address

await js.PublishAsync<Order>(subject: "fulfill.us", data: new Order(OrderId: "ord_8w2k", Customer: "acme-co"));



// A durable pull consumer the shipping workers share

var consumer = await js.CreateOrUpdateConsumerAsync("FULFILLMENT", new ConsumerConfig("shippers")

{

    AckPolicy = ConsumerConfigAckPolicy.Explicit,

});



// Fetch the one order and ack it. DoubleAck waits for the server to confirm

// the ack, so the WorkQueue removal has happened before we read the count.

await foreach (var msg in consumer.FetchAsync<Order>(opts: new NatsJSFetchOpts { MaxMsgs = 1 }))

{

    output.WriteLine($"shipping {msg.Data}");

    await msg.AckAsync(new AckOpts { DoubleAck = true });

}



// The ack removed the task, so a WorkQueue stream drains back to empty. A

// Limits stream like ORDERS would still be holding this order.

var info = await js.GetStreamAsync("FULFILLMENT");

output.WriteLine($"Messages left in FULFILLMENT: {info.Info.State.Messages}");
```

#### C

```
// FULFILLMENT is the queue of paid orders awaiting shipment. With

// WorkQueue retention the server keeps each message only until a

// consumer acks it, then deletes it from the stream.

jsStreamConfig  sc;

const char      *subjects[] = {"fulfill.>"};

const char      *order = "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\"}";



jsStreamConfig_Init(&sc);

sc.Name        = "FULFILLMENT";

sc.Subjects    = subjects;

sc.SubjectsLen = 1;

sc.Retention   = js_WorkQueuePolicy;

s = js_AddStream(&si, js, &sc, NULL, &jerr);

if (s == NATS_OK)

    printf("FULFILLMENT retention: %s\n",

           (si->Config->Retention == js_WorkQueuePolicy) ? "workqueue" : "other");



// Queue one order to ship.

if (s == NATS_OK)

    s = js_Publish(NULL, js, "fulfill.us", order, (int) strlen(order), NULL, &jerr);



// A shipping worker binds to a durable pull consumer with explicit ack.

if (s == NATS_OK)

{

    jsConsumerConfig cc;



    jsConsumerConfig_Init(&cc);

    cc.Durable   = "shippers";

    cc.AckPolicy = js_AckExplicit;

    s = js_AddConsumer(NULL, js, "FULFILLMENT", &cc, NULL, &jerr);

}

if (s == NATS_OK)

{

    jsSubOptions so;



    jsSubOptions_Init(&so);

    so.Stream   = "FULFILLMENT";

    so.Consumer = "shippers";

    s = js_PullSubscribe(&sub, js, NULL, "shippers", NULL, &so, &jerr);

}



// Fetch the order and ack it once the worker has shipped it.

if (s == NATS_OK)

    s = natsSubscription_Fetch(&list, sub, 1, 5000, &jerr);

for (i = 0; (s == NATS_OK) && (i < list.Count); i++)

{

    printf("shipping order: %s\n", natsMsg_GetData(list.Msgs[i]));

    s = natsMsg_AckSync(list.Msgs[i], NULL, &jerr);

}

natsMsgList_Destroy(&list);



// The ack removed the task from the queue, so the stream is now

// empty. A Limits stream like ORDERS would still hold the message; a

// WorkQueue stream drains to zero as workers finish.

if (s == NATS_OK)

    s = js_GetStreamInfo(&info, js, "FULFILLMENT", NULL, &jerr);

if (s == NATS_OK)

    printf("messages left in FULFILLMENT: %d\n", (int) info->State.Msgs);
```

The `--retention work` flag is the only change from how you built `ORDERS`. `nats stream info FULFILLMENT` shows it in the `Options` block:

```
nats stream info FULFILLMENT
```

```
             Subjects: fulfill.>



Options:



            Retention: WorkQueue

       Discard Policy: Old
```

Enqueue one order to ship and have a shipping worker ack it, and the stream's message count drops back to zero. The ack removed the task, which no limit on `ORDERS` does. The worker publishes `orders.shipped` back to `ORDERS` as it finishes, so the record lands in the log while the task drains from the queue.

Those shipping workers run as a pool sharing **one** consumer on `FULFILLMENT`, exactly as on [Scaling a consumer](/learn/jetstream/worker-pool.md): WorkQueue hands each order to the consumer, one worker ships it, and the ack clears it. You scale by adding workers to that one consumer, not by adding consumers — WorkQueue won't let two consumers claim the same order (the pitfalls below cover why).

## Switching retention on a live stream

Set retention when you create the stream, and leave it there.

The server allows exactly one live change: it swaps Limits and Interest, in either direction. Anything involving WorkQueue is locked — see the pitfall below. And even the allowed swap applies to messages already stored, right away. Say a stream has been collecting an audit history under Limits and you switch it to Interest. From that moment the server removes any message every consumer has already acked, and any message on a subject no consumer is interested in — including history you meant to keep.

Treat the policy as fixed at creation. If you want a different policy than the stream has, create a new stream with the right policy rather than editing the running one. `ORDERS` was created as Limits on purpose, and it stays Limits.

## How Interest and WorkQueue can go wrong

Interest and WorkQueue each have a way they can go wrong. Know it before you use them.

**Interest can fill the disk.** A message is removed only when every consumer whose filter covers it has acked it. A slow consumer holds up cleanup for every message it still owes an ack on. If a consumer stalls (a stuck worker, a service that's down), its unacked messages never become ready to leave, and the stream grows until it hits its limits or runs out of room. Interest retention still needs limits set, and it makes watching consumer health more important.

**WorkQueue delivers each message once.** The first ack removes the message for everyone, so no two consumers can claim the same message — the server rejects overlapping consumers outright (the pitfall below). You can still run more than one consumer if their filters *partition* the subjects, but each then handles only its slice; none sees the whole stream. For several consumers that each see every message, use Interest or Limits instead. To scale a single workload, use a worker *pool* sharing one consumer (the worker-pool page), not multiple consumers.

The full set of retention behavior, including how Interest and WorkQueue interact with stream republish, mirrors, and sources, is in [Reference → Stream Configuration](/reference/jetstream/api/stream/create.md). This page uses only the three `retention` values.

## Pitfalls

Both of these are WorkQueue constraints. The server checks them when you create or edit a stream, so you find out right away rather than in production.

**Retention to or from WorkQueue is locked after creation.** The earlier section covered the Limits–Interest swap the server allows, and how even that rewrites your history. The rule underneath it is stricter: the server rejects any change that adds or removes WorkQueue. A stream that isn't WorkQueue at creation can't become one, and a WorkQueue stream can't change to another policy.

Don't plan a migration path that edits retention into or out of WorkQueue. Create a new stream with the policy you want and move the data. The edit below is rejected with `stream configuration update can not change retention policy to/from workqueue`.

#### CLI

```
#!/bin/bash



# Pitfall: you cannot switch a stream's retention to or from WorkQueue

# on a live stream. Limits and Interest can swap, but WorkQueue is fixed

# at creation. Try to move FULFILLMENT (WorkQueue) to Limits and the

# server refuses:

#   stream configuration update can not change retention policy to/from

#   workqueue

# The command exits non-zero — FULFILLMENT keeps its WorkQueue policy.

nats stream edit FULFILLMENT --retention limits --force



# The safe move is a new stream with the policy you want, then migrate.

# ORDERS itself stays Limits — never edit a live stream's retention to

# WorkQueue hoping to convert it.

nats stream info FULFILLMENT
```

#### JavaScript/TypeScript

```
// Retention is fixed at creation. Read the live config, flip it from WorkQueue

// to Limits, and submit the update. The server rejects the change with err

// 10052: it won't move a stream to or from workqueue retention. To change

// retention, create a new stream instead.

const fulfillment = await jsm.streams.info("FULFILLMENT");

fulfillment.config.retention = RetentionPolicy.Limits;

try {

  await jsm.streams.update("FULFILLMENT", fulfillment.config);

} catch (err) {

  if (err instanceof JetStreamApiError) {

    console.log(`Rejected (err ${err.code}): ${err.message}`);

  } else {

    throw err;

  }

}
```

#### Go

```
// Load FULFILLMENT and take its current config.

stream, err := js.Stream(ctx, "FULFILLMENT")

if err != nil {

	panic(err)

}

cfg := stream.CachedInfo().Config



// Try to turn the WorkQueue stream into a Limits stream by flipping

// retention and pushing the update back.

cfg.Retention = jetstream.LimitsPolicy

if _, err := js.UpdateStream(ctx, cfg); err != nil {

	// The server refuses: a stream's retention policy is fixed for its

	// lifetime (err 10052: stream configuration update can not change

	// retention policy to/from workqueue). To change it, recreate the stream.

	fmt.Printf("retention switch rejected: %v\n", err)

	return

}

fmt.Println("update unexpectedly succeeded")
```

#### Python

```
# Read the current config and try to switch FULFILLMENT from WorkQueue to

# Limits retention. The server refuses: retention is fixed at create time,

# so you cannot turn a queue into a record (or back) on an existing stream.

info = await js.stream_info("FULFILLMENT")

try:

    await js.update_stream(info.config, retention=RetentionPolicy.LIMITS)

    print("retention changed (unexpected)")

except APIError as e:

    print(f"retention switch rejected: {e}")
```

#### Java

```
// You can't change a stream's retention policy after it's created.

// Switching FULFILLMENT from WorkQueue to Limits is rejected; to change

// retention you would delete the stream and recreate it.

try {

    jsm.updateStream(StreamConfiguration.builder()

        .name("FULFILLMENT")

        .subjects("fulfill.>")

        .retentionPolicy(RetentionPolicy.Limits)

        .build());

}

catch (JetStreamApiException e) {

    System.out.println("Rejected: " + e.getMessage());

    // stream configuration update can not change retention policy to/from workqueue [10052]

}
```

#### Rust

```
// Retention is fixed once a stream exists. Trying to switch FULFILLMENT from

// WorkQueue to Limits is rejected by the server (err 10052: stream

// configuration update can not change retention policy to/from workqueue).

match js

    .update_stream(Config {

        name: "FULFILLMENT".to_string(),

        subjects: vec!["fulfill.>".to_string()],

        retention: RetentionPolicy::Limits,

        ..Default::default()

    })

    .await

{

    Ok(_) => println!("unexpected: retention switch was accepted"),

    Err(err) => println!("rejected: {err}"),

}
```

#### C#/.NET

```
// Try to turn FULFILLMENT into a plain Limits stream after the fact.

var stream = await js.GetStreamAsync("FULFILLMENT");

var config = stream.Info.Config;

config.Retention = StreamConfigRetention.Limits;



try

{

    await js.UpdateStreamAsync(config);

    output.WriteLine("update accepted");

}

catch (NatsJSApiException e)

{

    // The server won't switch retention into or out of WorkQueue on a live

    // stream. To change it, recreate the stream.

    output.WriteLine($"rejected (err {e.Error.ErrCode}): {e.Error.Description}");

}
```

#### C

```
// Load FULFILLMENT and take its current config.

s = js_GetStreamInfo(&si, js, "FULFILLMENT", NULL, &jerr);

if (s == NATS_OK)

{

    // Try to turn the WorkQueue stream into a Limits stream by

    // flipping retention and pushing the update back.

    jsStreamInfo *updated = NULL;



    si->Config->Retention = js_LimitsPolicy;



    s = js_UpdateStream(&updated, js, si->Config, NULL, &jerr);

    if (s != NATS_OK)

    {

        // The server refuses: a stream's retention policy is fixed

        // for its lifetime (err 10052: stream configuration update

        // can not change retention policy to/from workqueue). To

        // change it, recreate the stream.

        printf("retention switch rejected: %s\n", nats_GetLastError(NULL));

        s = NATS_OK;

    }

    else

    {

        printf("update unexpectedly succeeded\n");

        jsStreamInfo_Destroy(updated);

    }

}
```

**WorkQueue rejects consumers that overlap.** The first ack removes a message for everyone, so the server won't let two consumers claim the same message. Adding a second unfiltered consumer, or two consumers whose filters overlap, fails the create: `multiple non-filtered consumers not allowed on workqueue stream`, or `filtered consumer not unique on workqueue stream` for overlapping filters.

Give each consumer a filter that splits the subjects between them, so no message belongs to two consumers. A worker *pool* sharing one consumer is the other valid setup; see [A pool of workers](/learn/jetstream/worker-pool.md).

#### CLI

```
#!/bin/bash



# Pitfall: a WorkQueue stream rejects a second consumer whose subjects

# overlap an existing one. The server won't let two consumers fight over

# the same task, so it refuses the create up front.



# FULFILLMENT is the WorkQueue stream from earlier on this page. Add one

# unfiltered consumer — fine, it owns the whole queue.

nats consumer add FULFILLMENT shippers --pull --ack explicit --defaults



# Now try to add a second unfiltered consumer. The server rejects it:

#   multiple non-filtered consumers not allowed on workqueue stream

# (error 10099). The command exits non-zero.

nats consumer add FULFILLMENT eu-shippers --pull --ack explicit --defaults



# The fix is non-overlapping filters so each task belongs to exactly one

# consumer — here, one shipper consumer per region. Delete the broad

# consumer, then split by subject.

nats consumer rm FULFILLMENT shippers --force



nats consumer add FULFILLMENT us-shippers --pull --ack explicit --filter "fulfill.us" --defaults

nats consumer add FULFILLMENT eu-shippers --pull --ack explicit --filter "fulfill.eu" --defaults



# These two coexist because fulfill.us and fulfill.eu never collide.

# A wildcard like fulfill.> would overlap both and be rejected with

# "filtered consumer not unique on workqueue stream" (error 10100).
```

#### JavaScript/TypeScript

```
// One unfiltered consumer reads every subject in the queue. On a WorkQueue

// stream that is fine on its own.

await jsm.consumers.add("FULFILLMENT", {

  durable_name: "shippers",

  ack_policy: AckPolicy.Explicit,

});

console.log("Created consumer: shippers");



// A WorkQueue stream hands each task to exactly one consumer, so two unfiltered

// consumers would both claim the same subjects. The server rejects the second

// one with err 10099.

try {

  await jsm.consumers.add("FULFILLMENT", {

    durable_name: "eu-shippers",

    ack_policy: AckPolicy.Explicit,

  });

} catch (err) {

  if (err instanceof JetStreamApiError) {

    console.log(`Rejected (err ${err.code}): ${err.message}`);

  } else {

    throw err;

  }

}



// Give each worker its own slice of the queue instead. Drop the unfiltered

// consumer, then create one consumer per region. Their filters do not overlap,

// so both are allowed.

await jsm.consumers.delete("FULFILLMENT", "shippers");



await jsm.consumers.add("FULFILLMENT", {

  durable_name: "us-shippers",

  ack_policy: AckPolicy.Explicit,

  filter_subject: "fulfill.us",

});

await jsm.consumers.add("FULFILLMENT", {

  durable_name: "eu-shippers",

  ack_policy: AckPolicy.Explicit,

  filter_subject: "fulfill.eu",

});

console.log("Created filtered consumers: us-shippers, eu-shippers");
```

#### Go

```
// One unfiltered consumer covers every order in the queue.

if _, err := stream.CreateConsumer(ctx, jetstream.ConsumerConfig{

	Durable:   "shippers",

	AckPolicy: jetstream.AckExplicitPolicy,

}); err != nil {

	panic(err)

}

fmt.Println("created unfiltered consumer: shippers")



// A WorkQueue stream delivers each message to exactly one consumer, so it

// refuses a second consumer whose reach overlaps the first. Two unfiltered

// consumers both cover fulfill.> , so this is rejected

// (err 10099: multiple non-filtered consumers not allowed on workqueue stream).

if _, err := stream.CreateConsumer(ctx, jetstream.ConsumerConfig{

	Durable:   "eu-shippers",

	AckPolicy: jetstream.AckExplicitPolicy,

}); err != nil {

	fmt.Printf("second unfiltered consumer rejected: %v\n", err)

}



// Drop the catch-all consumer so we can split the queue by region instead.

if err := stream.DeleteConsumer(ctx, "shippers"); err != nil {

	panic(err)

}



// Filtered consumers are allowed as long as their subjects don't overlap.

// us-shippers takes fulfill.us, eu-shippers takes fulfill.eu, and each

// order still goes to exactly one worker.

if _, err := stream.CreateConsumer(ctx, jetstream.ConsumerConfig{

	Durable:       "us-shippers",

	FilterSubject: "fulfill.us",

	AckPolicy:     jetstream.AckExplicitPolicy,

}); err != nil {

	panic(err)

}

if _, err := stream.CreateConsumer(ctx, jetstream.ConsumerConfig{

	Durable:       "eu-shippers",

	FilterSubject: "fulfill.eu",

	AckPolicy:     jetstream.AckExplicitPolicy,

}); err != nil {

	panic(err)

}

fmt.Println("created filtered consumers: us-shippers (fulfill.us), eu-shippers (fulfill.eu)")
```

#### Python

```
# One unfiltered consumer covers every fulfill.> subject. That is allowed.

await js.add_consumer(

    "FULFILLMENT",

    ConsumerConfig(durable_name="shippers", ack_policy=AckPolicy.EXPLICIT),

)

print("added unfiltered consumer shippers")



# A WorkQueue stream gives each message to exactly one consumer, so two

# consumers whose subjects overlap would compete for the same orders. A

# second unfiltered consumer overlaps with the first and is rejected.

try:

    await js.add_consumer(

        "FULFILLMENT",

        ConsumerConfig(durable_name="eu-shippers", ack_policy=AckPolicy.EXPLICIT),

    )

except APIError as e:

    print(f"second unfiltered consumer rejected: {e}")



# Drop the unfiltered consumer so the subject space is free again.

await js.delete_consumer("FULFILLMENT", "shippers")



# Filtered consumers work as long as their subjects do not overlap. Split

# the queue by region: one worker pool per destination.

await js.add_consumer(

    "FULFILLMENT",

    ConsumerConfig(

        durable_name="us-shippers",

        filter_subject="fulfill.us",

        ack_policy=AckPolicy.EXPLICIT,

    ),

)

await js.add_consumer(

    "FULFILLMENT",

    ConsumerConfig(

        durable_name="eu-shippers",

        filter_subject="fulfill.eu",

        ack_policy=AckPolicy.EXPLICIT,

    ),

)

print("added filtered consumers us-shippers and eu-shippers")
```

#### Java

```
// One unfiltered consumer on a WorkQueue stream is fine: it owns every

// subject, so each task still has exactly one owner.

jsm.addOrUpdateConsumer("FULFILLMENT", ConsumerConfiguration.builder()

    .durable("shippers")

    .ackPolicy(AckPolicy.Explicit)

    .build());

System.out.println("Added consumer: shippers");



// A second unfiltered consumer would let two workers claim the same

// task, so the WorkQueue stream rejects it.

try {

    jsm.addOrUpdateConsumer("FULFILLMENT", ConsumerConfiguration.builder()

        .durable("eu-shippers")

        .ackPolicy(AckPolicy.Explicit)

        .build());

}

catch (JetStreamApiException e) {

    System.out.println("Rejected: " + e.getMessage());

    // multiple non-filtered consumers not allowed on workqueue stream [10099]

}



// To split the work, drop the catch-all consumer...

jsm.deleteConsumer("FULFILLMENT", "shippers");



// ...and give each region its own subject filter. The filters don't

// overlap, so every task still maps to exactly one consumer.

jsm.addOrUpdateConsumer("FULFILLMENT", ConsumerConfiguration.builder()

    .durable("us-shippers")

    .filterSubject("fulfill.us")

    .ackPolicy(AckPolicy.Explicit)

    .build());

jsm.addOrUpdateConsumer("FULFILLMENT", ConsumerConfiguration.builder()

    .durable("eu-shippers")

    .filterSubject("fulfill.eu")

    .ackPolicy(AckPolicy.Explicit)

    .build());

System.out.println("Added filtered consumers: us-shippers (fulfill.us), eu-shippers (fulfill.eu)");
```

#### Rust

```
// One unfiltered consumer claims every order on the queue. That is allowed.

stream

    .create_consumer(pull::Config {

        durable_name: Some("shippers".to_string()),

        ack_policy: AckPolicy::Explicit,

        ..Default::default()

    })

    .await?;



// A WorkQueue stream gives each message to exactly one consumer, so two

// unfiltered consumers would both claim the same orders. The server rejects

// the second one (err 10099: multiple non-filtered consumers not allowed on

// workqueue stream).

match stream

    .create_consumer(pull::Config {

        durable_name: Some("eu-shippers".to_string()),

        ack_policy: AckPolicy::Explicit,

        ..Default::default()

    })

    .await

{

    Ok(_) => println!("unexpected: second unfiltered consumer was accepted"),

    Err(err) => println!("rejected: {err}"),

}



// Split the work by subject instead. Drop the unfiltered consumer, then add

// one consumer per region. Their filters do not overlap, so both succeed.

stream.delete_consumer("shippers").await?;



stream

    .create_consumer(pull::Config {

        durable_name: Some("us-shippers".to_string()),

        filter_subject: "fulfill.us".to_string(),

        ack_policy: AckPolicy::Explicit,

        ..Default::default()

    })

    .await?;

stream

    .create_consumer(pull::Config {

        durable_name: Some("eu-shippers".to_string()),

        filter_subject: "fulfill.eu".to_string(),

        ack_policy: AckPolicy::Explicit,

        ..Default::default()

    })

    .await?;

println!("us-shippers and eu-shippers created");
```

#### C#/.NET

```
// One unfiltered consumer over the whole queue is fine.

await js.CreateOrUpdateConsumerAsync("FULFILLMENT", new ConsumerConfig("shippers")

{

    AckPolicy = ConsumerConfigAckPolicy.Explicit,

});



// A second unfiltered consumer would see the same orders, so two workers

// could each be handed the same task. A WorkQueue stream refuses it.

try

{

    await js.CreateOrUpdateConsumerAsync("FULFILLMENT", new ConsumerConfig("eu-shippers")

    {

        AckPolicy = ConsumerConfigAckPolicy.Explicit,

    });

}

catch (NatsJSApiException e)

{

    output.WriteLine($"rejected (err {e.Error.ErrCode}): {e.Error.Description}");

}



// Give each worker its own slice of the subjects instead. Drop the

// catch-all consumer first...

await js.DeleteConsumerAsync("FULFILLMENT", "shippers");



// ...then create two consumers whose filters don't overlap. Both succeed,

// because no order can be claimed by more than one of them.

await js.CreateOrUpdateConsumerAsync("FULFILLMENT", new ConsumerConfig("us-shippers")

{

    AckPolicy = ConsumerConfigAckPolicy.Explicit,

    FilterSubject = "fulfill.us",

});



await js.CreateOrUpdateConsumerAsync("FULFILLMENT", new ConsumerConfig("eu-shippers")

{

    AckPolicy = ConsumerConfigAckPolicy.Explicit,

    FilterSubject = "fulfill.eu",

});



output.WriteLine("Created us-shippers and eu-shippers on non-overlapping filters");
```

#### C

```
// One unfiltered consumer covers every order in the queue.

jsConsumerConfig cc;



jsConsumerConfig_Init(&cc);

cc.Durable   = "shippers";

cc.AckPolicy = js_AckExplicit;

s = js_AddConsumer(NULL, js, "FULFILLMENT", &cc, NULL, &jerr);

if (s == NATS_OK)

    printf("created unfiltered consumer: shippers\n");



// A WorkQueue stream delivers each message to exactly one consumer,

// so it refuses a second consumer whose reach overlaps the first.

// Two unfiltered consumers both cover fulfill.>, so this is rejected

// (err 10099: multiple non-filtered consumers not allowed on

// workqueue stream).

if (s == NATS_OK)

{

    jsConsumerConfig_Init(&cc);

    cc.Durable   = "eu-shippers";

    cc.AckPolicy = js_AckExplicit;

    if (js_AddConsumer(NULL, js, "FULFILLMENT", &cc, NULL, &jerr) != NATS_OK)

        printf("second unfiltered consumer rejected: %s\n", nats_GetLastError(NULL));

}



// Drop the catch-all consumer so we can split the queue by region

// instead.

if (s == NATS_OK)

    s = js_DeleteConsumer(js, "FULFILLMENT", "shippers", NULL, &jerr);



// Filtered consumers are allowed as long as their subjects don't

// overlap. us-shippers takes fulfill.us, eu-shippers takes

// fulfill.eu, and each order still goes to exactly one worker.

if (s == NATS_OK)

{

    jsConsumerConfig_Init(&cc);

    cc.Durable       = "us-shippers";

    cc.FilterSubject = "fulfill.us";

    cc.AckPolicy     = js_AckExplicit;

    s = js_AddConsumer(NULL, js, "FULFILLMENT", &cc, NULL, &jerr);

}

if (s == NATS_OK)

{

    jsConsumerConfig_Init(&cc);

    cc.Durable       = "eu-shippers";

    cc.FilterSubject = "fulfill.eu";

    cc.AckPolicy     = js_AckExplicit;

    s = js_AddConsumer(NULL, js, "FULFILLMENT", &cc, NULL, &jerr);

}

if (s == NATS_OK)

    printf("created filtered consumers: us-shippers (fulfill.us), eu-shippers (fulfill.eu)\n");
```

## Where you are

`ORDERS` is unchanged. It's a Limits stream that holds its order history and lets late and repeat consumers replay.

You now have:

* The three retention policies (Limits, Interest, WorkQueue) and the one question that separates them: who decides a message is finished.
* Which policy fits which kind of work: audit log → Limits, fan-out → Interest, job queue → WorkQueue.
* A `FULFILLMENT` WorkQueue stream — the shipping workers' queue — that dropped a task on ack while `ORDERS` kept the record.
* The rule that retention is fixed at creation, not switched on a live stream.

## What's next

Retention removes messages on a schedule the server runs. The next page covers removing them by hand: [deleting a single message](/learn/jetstream/altering-stream-state.md) and purging the stream.

## See also

* [Reference → Stream Configuration](/reference/jetstream/api/stream/create.md) — the `retention` field, its three values, and how each interacts with limits, republish, and mirrors.
* [Shaping the stream](/learn/jetstream/shaping-the-stream.md) — the limits that govern a Limits stream.
* [A pool of workers](/learn/jetstream/worker-pool.md) — the worker pool that shares one consumer, the pattern that fits WorkQueue.
