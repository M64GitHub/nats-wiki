<!-- source: https://docs.nats.io/learn/jetstream/worker-pool.md · fetched 2026-08-31 · section: worker-pool -->
# Scaling a consumer

On the [previous page](/learn/jetstream/pull-consumers.md), one worker consumed the `shipping` consumer: a continuous pull loop that ships each order and acks. That kept up while Acme shipped a few orders an hour.

Then Acme's order volume climbed. Orders arrive faster than one worker can ship them, and the unshipped ones pile up in `ORDERS`.

You clear that backlog by adding workers. Point several processes at the same `shipping` consumer and they share the load: the server hands each stored order to exactly one worker. You reuse the `ORDERS` stream and `shipping` consumer you already have.

## One consumer, many workers

Each worker names the same `shipping` consumer and runs the same pull loop. Start that loop in several processes at once:

#### CLI

```
#!/bin/bash

# A worker loop for the shipping consumer.

# Run this same loop in three separate terminals to form a pool of

# three workers. All three share the one "shipping" consumer, and the

# server splits the stored messages across them.



# Each pass: pull one message, "process" it, and acknowledge it.

# --count 1 pulls a single message at a time.

# --ack acknowledges the message after it is received.

while true; do

  nats consumer next ORDERS shipping --count 1 --ack

done



# Publish work from a fourth terminal and watch it spread across the

# three running loops:

#   nats pub orders.shipped '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

#

# To see in-flight redelivery: stop one worker (Ctrl-C) right after it

# pulls a message but before it acks. After AckWait (30s default), the

# server redelivers that message to one of the surviving workers.
```

#### JavaScript/TypeScript

```
// Bind to the durable "shipping" consumer created earlier.

const js = jetstream(nc);

const c = await js.consumers.get("ORDERS", "shipping");



// consume() yields the orders the server hands this worker. Run this same

// program in several processes: they all share the one "shipping" consumer, and

// the server splits the stored orders across them, one order to one worker.

const messages = await c.consume();

for await (const m of messages) {

  console.log(`shipping ${m.string()}`);

  m.ack();

}
```

#### Go

```
// Bind to the durable "shipping" consumer created earlier.

cons, err := js.Consumer(ctx, "ORDERS", "shipping")

if err != nil {

	panic(err)

}



// Consume runs the handler for every order the server hands this worker.

// Start this same program in several processes: they all share the one

// "shipping" consumer, and the server splits the stored orders across them,

// one order to one worker.

consCtx, err := cons.Consume(func(msg jetstream.Msg) {

	fmt.Printf("shipping %s\n", string(msg.Data()))

	msg.Ack()

})

if err != nil {

	panic(err)

}

defer consCtx.Stop()



// Keep this worker running until interrupted (Ctrl-C).

sig := make(chan os.Signal, 1)

signal.Notify(sig, os.Interrupt)

<-sig
```

#### Python

```
# Bind to the durable "shipping" consumer created earlier. Run this same

# program in several processes: they all share the one consumer, and the

# server splits the stored orders across them, one order to one worker.

psub = await js.pull_subscribe_bind("shipping", stream="ORDERS")



# Pull one order at a time and ack it. fetch times out when nothing is

# waiting; keep looping so the worker stays ready for the next order.

while True:

    try:

        msgs = await psub.fetch(batch=1, timeout=5)

    except nats.errors.TimeoutError:

        continue



    for msg in msgs:

        print(f"shipping {msg.data.decode()}")

        await msg.ack()
```

#### Java

```
// consume() runs the handler for every order the server hands this

// worker. Run this same program in several processes: they all share

// the one "shipping" consumer, and the server splits the stored

// orders across them, one order to one worker.

try (MessageConsumer mc = cc.consume(msg -> {

    System.out.println("shipping " + new String(msg.getData(), StandardCharsets.UTF_8));

    msg.ack();

})) {

    // Keep this worker running until the process is stopped.

    Thread.sleep(Long.MAX_VALUE);

}
```

#### Rust

```
// Bind to the durable "shipping" consumer created earlier.

let stream = js.get_stream("ORDERS").await?;

let consumer: PullConsumer = stream.get_consumer("shipping").await?;



// messages() is a never-ending stream of orders the server hands this

// worker. Run this same program in several processes: they all share the

// one "shipping" consumer, and the server splits the stored orders across

// them, one order to one worker.

let mut messages = consumer.messages().await?;

while let Some(msg) = messages.next().await {

    let msg = msg?;

    println!("shipping {}", std::str::from_utf8(&msg.payload)?);

    msg.ack().await?;

}
```

#### C#/.NET

```
// Bind to the durable "shipping" consumer created earlier.

var consumer = await js.GetConsumerAsync("ORDERS", "shipping");



// ConsumeAsync yields the orders the server hands this worker. Run this

// same program in several processes: they all share the one "shipping"

// consumer, and the server splits the stored orders across them, one

// order to one worker.

await foreach (var msg in consumer.ConsumeAsync<Order>())

{

    output.WriteLine($"shipping {msg.Data}");

    await msg.AckAsync();



    // A real worker loops forever; stop once the backlog is clear so the

    // example returns.

    if (++shipped == 3)

    {

        break;

    }

}
```

#### C

```
// The handler runs for every order the server hands this worker.

static void

onOrder(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    printf("shipping %.*s\n", natsMsg_GetDataLength(msg), natsMsg_GetData(msg));

    natsMsg_Ack(msg, NULL);

    natsMsg_Destroy(msg);

}

    // Bind to the durable "shipping" consumer created earlier and deliver

    // messages to the handler. Start this same program in several processes:

    // they all share the one "shipping" consumer, and the server splits the

    // stored orders across them, one order to one worker.

    jsSubOptions so;



    jsSubOptions_Init(&so);

    so.Stream    = "ORDERS";

    so.Consumer  = "shipping";

    so.ManualAck = true;



    s = js_PullSubscribeAsync(&sub, js, NULL, NULL, onOrder, NULL, NULL, &so, &jerr);



    // Keep this worker running until interrupted (Ctrl-C).

    while ((s == NATS_OK) && !done)

        nats_Sleep(100);
```

Open three terminals and run that loop in each. The `ORDERS` stream already holds the orders from earlier pages; now add a fresh handful of `orders.shipped` messages from a fourth terminal so all three workers have something to compete for:

```
nats pub --jetstream orders.shipped '{"order_id":"ord_9x3f","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T11:01:50Z"}'

nats pub --jetstream orders.shipped '{"order_id":"ord_7p4d","customer":"globex","total_cents":7800,"ts":"2026-05-22T11:01:55Z"}'

nats pub --jetstream orders.shipped '{"order_id":"ord_5xk1","customer":"initech","total_cents":1500,"ts":"2026-05-22T11:02:00Z"}'
```

Each `--jetstream` publish returns a `PubAck` confirming the order landed in `ORDERS`. The server hands each waiting order to one worker, serving pull requests in the order they arrived. No two workers get the same order, so the three split the backlog roughly evenly, because each loop pulls one order at a time:

**Message flow — Workers sharing one consumer (animated):** Several workers share one pull consumer. The ORDERS stream holds a backlog of stored orders and the single shipping consumer has one read position that sweeps through them. Each order is handed to exactly one worker, rotating round-robin across the workers that are asking, so three workers end up with an even share. Acked orders stay in the stream — the workers share a read position, not the messages.

A worker only takes a turn while it's actually asking. One that's still shipping an order has no pull request open, so the server skips it and gives the order to the next worker in line. Distribution follows demand: a faster worker pulls more often and ships more.

The consumer still tracks a single position through all of this. Ask the server and the acked count climbs as one number:

```
nats consumer info ORDERS shipping
```

```
State:



  Last Delivered Message: Consumer sequence: ... Stream sequence: ...

     Acknowledgment Floor: Consumer sequence: ... Stream sequence: ...

         Outstanding Acks: 0 out of maximum 1,000
```

Your exact sequence numbers depend on the earlier pages; what matters is the shape. The two Acknowledgment Floor numbers advance together as workers ack, and the Last Delivered pair sits at or ahead of them. The position belongs to the consumer, not to each worker, so it advances the same whether one process pulls or three.

## This works on the log you already have

`ORDERS` is the same Limits-retention stream from page one; nothing about it changed to make this work. Sharing is a property of the consumer, not the stream: point many workers at one consumer and the server splits the work on any stream.

One consequence matters here. An ack advances the position, it doesn't remove the order. The order stays in `ORDERS` for `billing`, `analytics`, and any consumer that reads the log later. The workers share a *position*, not the messages.

## How this differs from a queue group

If you read the Core Concepts, this looks like a queue group, but the two balance different things.

A queue group splits **live** messages across core NATS subscribers as each one arrives, with no storage behind it. A subscriber that's offline when a message arrives misses it for good.

Workers sharing a consumer split **stored** messages against the stream. A message waits in the stream until some worker pulls it and acks it, so a worker that's offline just leaves its share for the others.

Only the stream-backed split survives a worker dropping out or a restart.

## When a worker crashes mid-message

A worker pulls an order and starts shipping it. Before it acks, the process dies. On the consumer that order is still in progress: the server delivered it and is waiting on the ack. When `AckWait` runs out (30 seconds by default), the server hands the order to another worker. This is the redelivery loop from the [acknowledgment page](/learn/jetstream/acknowledgment.md), now spread across the pool.

**Message flow — Crash mid-message, then redelivery (animated):** One order is delivered to a worker that crashes before it acks. The order stays in progress on the shipping consumer while the AckWait timer runs; the server can't see the crash, only the missing ack. When AckWait elapses the server redelivers the same order to a surviving worker, which ships it and acks. The order is handled exactly once even though the first worker failed.

Watch it happen. The loop above acks the instant it pulls, so there's no window to interrupt — a real ship takes time. Add a brief delay before the ack (a `sleep 5` in the shell loop, or a pause in your handler), then kill that worker during the delay. After `AckWait` (30 seconds by default), the order reappears on a surviving worker and ships once, because some worker eventually acks it. If the dead worker had already shipped the order before crashing, it ships twice; the pitfall below covers keying side effects by `order_id`.

## Capping how many orders are in progress

Each worker can hold an order in progress, so more workers mean more in progress at once. There's a ceiling on that.

The ceiling is `MaxAckPending`: how many delivered-but-unacked messages the consumer allows at once, default 1000. Hit it and the server stops delivering new orders until some get acked. The cap is shared across the whole consumer, not per worker: five workers get 1000 between them, not 1000 each.

You set it when you create or update the consumer:

```
nats consumer edit ORDERS shipping --max-pending 1000
```

Set it too low and workers sit idle waiting for a slot. Set it too high and a slow ack leaves a big in-progress backlog that all redelivers at once if many workers die together.

## Pitfalls

Running several workers makes two consumer settings, `AckWait` and `MaxAckPending`, matter in practice.

**A redelivered order can arrive at a second worker.** When one worker crashes mid-order, the server gives that order to another worker after `AckWait`, so the work still gets done. The same order can then run twice, so key side effects by `order_id`. A redelivery shows up in the message's delivery count.

The pool shares work by demand, so you don't choose which worker gets an order. For that control, use [priority groups](/learn/jetstream/priority-groups.md): send everything to one worker until it fails, or keep a standby worker idle until the pool falls behind.

**A low `MaxAckPending` starves a large set of workers.** The cap is shared across the whole consumer, not per worker. Set it to 3 and only three messages are ever in progress, so ten workers leave seven of them idle no matter how much is stored. Set the cap to at least your worker count, with room to spare.

**A crashed worker holds its order until `AckWait`.** The server can't tell a crash from slow work; it only knows the ack hasn't come. Until the timer runs out (30 seconds by default), that order stays in progress and goes to no one else. Set `AckWait` to your normal processing time: too short redelivers while a healthy worker is still working, too long leaves real failures stuck. The full set of in-progress and redelivery options (`AckWait`, `MaxDeliver`, backoff arrays) is in [Reference → Consumer Configuration](/reference/jetstream/api/consumer/create.md).

## Where you are

You now have:

* One `shipping` consumer, unchanged from earlier pages.
* Several workers pulling from it, splitting the stored messages between them.
* A name for the ceiling on how much runs at once: `MaxAckPending`, shared across every worker.

You scale by starting more processes; the consumer is unchanged. And because `ORDERS` is a log, it keeps every order after a worker handles it.

## What's next

Every consumer so far — `billing`, `analytics`, `shipping` — was built to last: named, durable, resumable. The next page is the opposite kind of read: an [ordered consumer](/learn/jetstream/ordered-consumer.md), a fast single pass over the whole log, in order, that cleans up after itself — for a job like totaling every order once, with no position to keep.

## See also

* [Reference → Consumer Configuration](/reference/jetstream/api/consumer/create.md) — `MaxAckPending`, `AckWait`, backoff, and every other consumer field.
* [Core Concepts → Queue Groups](/concepts/queue-groups.md) — the core NATS balancing this page contrasts with.
