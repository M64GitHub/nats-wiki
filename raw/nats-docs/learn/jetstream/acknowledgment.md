<!-- source: https://docs.nats.io/learn/jetstream/acknowledgment.md · fetched 2026-08-31 · section: acknowledgment -->
# Ack responses and redelivery

The `shipping` consumer was created with `AckPolicy=explicit`. That choice means every message it delivers must be answered. A message is not done until the client says so.

This page covers the four responses a client can give — ack, nak, term ("give up on this one"), and in-progress ("still working") — and the server-side controls that decide what happens when an answer is late or never comes.

## Why the server waits for an answer

A message stays in flight from the moment the server delivers it until the consumer answers. The server keeps a copy on the pending list and starts a timer.

If the answer never comes, the server assumes the worker stopped and delivers the message again. This is the redelivery loop from the previous page. It has two parts.

The first part is the timer. Its length is AckWait, and it defaults to 30 seconds.

The second part is the answer itself. The answer takes one of four forms.

## The four responses

A client answers a delivered message in exactly one of four ways.

**ack**: the acknowledgment. The work succeeded. The server removes the message from the pending list and never delivers it again. This is the answer you send when a message is handled.

**nak**: a negative acknowledgment. The work failed, redeliver this message. The server puts it back for another attempt. A plain nak asks for redelivery right away, or after a delay you set — see [below](#negative-ack-with-a-delay).

**term**: stop trying. This message can never be handled, so don't deliver it again to anyone. The server drops it from the pending list as it does for an ack, but the work was never done.

**in-progress**: still working. This is not a final answer. It resets the AckWait timer so a long job doesn't trip redelivery. The client then keeps going and answers for real later.

ack, nak, and term are final. Each one closes out a delivery. in-progress extends the timer instead.

**Message flow — The four ack responses (animated):** The four responses shown as consequences on a real stream of deliveries. The consumer delivers message #1 and the client acks it, so the consumer hands over the next message, #2. The client naks #2 and the same message is redelivered immediately; the retry is then acked and delivery moves on to #3. The client terms #3: it is dropped and turns red, and the next message, #4, is delivered at once. For #4 the client sends in-progress, which is not a final answer — it refills the Ack Wait window to keep the slow message in flight — then finally acks it and moves on to #5. In short: ack advances to the next message, nak redelivers the same message immediately, term drops the message and advances to the next, and in-progress extends the Ack Wait window.

The rest of this page takes the three non-trivial answers — nak, term, and the controls behind them — one at a time.

## Negative ack with a delay

A plain nak redelivers immediately. That's rarely what you want.

A failure is often temporary. A service it calls is briefly down, a row is locked, or a rate limit is hit. Redelivering in the same instant fails again right away, and the message retries over and over with no pause.

To avoid that, nak with a delay. The client tells the server to redeliver the message but wait a given time first. The server holds the message for that delay, then puts it back. Passing that delay is a client-library call — the CLI's `--nak` only asks for immediate redelivery — so there's no CLI tab here. (To space out redeliveries from the CLI, set a consumer [backoff](#backoff-a-growing-delay-between-attempts) instead.)

#### JavaScript/TypeScript

```
// Bind to the existing durable and pull one message with next(). nak() tells the

// server to redeliver instead of advancing. Passing a delay (in milliseconds)

// holds the redelivery for that long, which backs off a downstream that isn't

// ready yet.

const js = jetstream(nc);

const c = await js.consumers.get("ORDERS", "shipping");



const m = await c.next();

if (m) {

  console.log(`${m.subject}: ${m.string()}`);

  m.nak(10_000); // ask for redelivery after 10 seconds

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



// Negatively acknowledge with a delay. The server holds the message and

// redelivers it after the delay instead of right away, which is useful when

// a downstream dependency needs time to recover.

if err := msg.NakWithDelay(10 * time.Second); err != nil {

	panic(err)

}

fmt.Println("Message NAK'd, redelivery delayed by 10s")
```

#### Python

```
# Bind to the durable consumer and pull a single message.

psub = await js.pull_subscribe_bind("shipping", stream="ORDERS")



msgs = await psub.fetch(batch=1, timeout=5)

msg = msgs[0]

print(f"{msg.subject}: {msg.data.decode()}")



# Negative ack with a delay: redeliver this message after 10 seconds.

await msg.nak(delay=10)
```

#### Java

```
// Pull one message and negatively acknowledge it with a delay.

// The server holds the message and redelivers it after 10 seconds,

// which backs off retries instead of looping immediately.

Message m = cc.next(Duration.ofSeconds(5));

if (m == null) {

    System.out.println("Nothing to read.");

    return;

}



System.out.printf("subject=%s data=%s%n",

    m.getSubject(),

    new String(m.getData(), StandardCharsets.UTF_8));



m.nakWithDelay(Duration.ofSeconds(10));

System.out.println("Nak sent; redelivery delayed 10s.");
```

#### Rust

```
// Bind to the existing durable consumer.

let stream = js.get_stream("ORDERS").await?;

let consumer: PullConsumer = stream.get_consumer("shipping").await?;



// Fetch a single message and negatively acknowledge it with a delay.

let mut messages = consumer.fetch().max_messages(1).messages().await?;

while let Some(msg) = messages.next().await {

    let msg = msg?;

    println!("{}: {}", msg.subject, std::str::from_utf8(&msg.payload)?);

    // Tell the server to redeliver this message, but wait 10 seconds

    // before doing so. Use this to back off on a transient failure.

    msg.ack_with(AckKind::Nak(Some(std::time::Duration::from_secs(10))))

        .await?;

}
```

#### C#/.NET

```
// Bind to the existing durable consumer

var consumer = await js.GetConsumerAsync("ORDERS", "shipping");



// Pull one message

var msg = await consumer.NextAsync<Order>();

if (msg is { } order)

{

    output.WriteLine($"{order.Subject}: {order.Data}");



    // Negative ack with a delay: ask the server to redeliver after 10 seconds

    await order.NakAsync(new AckOpts { NakDelay = TimeSpan.FromSeconds(10) });

}
```

#### C

```
// Bind to the durable "shipping" consumer created earlier.

jsSubOptions so;

natsMsgList  list = {NULL, 0};



jsSubOptions_Init(&so);

so.Stream   = "ORDERS";

so.Consumer = "shipping";

s = js_PullSubscribe(&sub, js, NULL, NULL, NULL, &so, &jerr);



// Fetch a single message from the consumer.

if (s == NATS_OK)

    s = natsSubscription_Fetch(&list, sub, 1, 5000, &jerr);

if ((s == NATS_OK) && (list.Count > 0))

{

    natsMsg *msg = list.Msgs[0];



    printf("Received on %s: %.*s\n", natsMsg_GetSubject(msg),

           natsMsg_GetDataLength(msg), natsMsg_GetData(msg));



    // Negatively acknowledge with a delay. The server holds the

    // message and redelivers it after the delay instead of right

    // away, which is useful when a downstream dependency needs

    // time to recover.

    s = natsMsg_NakWithDelay(msg, 10000, NULL);

    if (s == NATS_OK)

        printf("Message NAK'd, redelivery delayed by 10s\n");

}

natsMsgList_Destroy(&list);
```

A nak returns the message to the consumer, not to the worker that nak'd it. If several workers share one consumer, the redelivery can land on a different worker (see [worker pool](/learn/jetstream/worker-pool.md)). Each nak also raises a nak advisory on `$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED.ORDERS.shipping`; its fields are in [Reference → Nak advisory](/reference/jetstream/advisory/nak.md).

A delayed nak sets the wait one redelivery at a time, and the client chooses it. A **backoff** on the consumer grows the wait automatically, but it only shapes redeliveries that fire when the AckWait timer runs out — it doesn't slow a nak. Backoff is covered below.

## Term: the poison message path

Some failures aren't temporary. A message with a broken payload, or one that fails a check that will never pass, is a poison message. Redelivering it just wastes delivery attempts.

For these, the client answers term. The message leaves the pending list and the server never delivers it again, no matter how many attempts remain.

#### CLI

```
#!/bin/bash

# This message can never be processed (a poison message: malformed

# payload, a validation that will never pass). Terminate it so the

# server drops it from the pending list and never redelivers it,

# regardless of how many delivery attempts remain.



# Pull the next message and term it.

nats consumer next ORDERS shipping --term
```

#### JavaScript/TypeScript

```
// Bind to the existing durable and pull one message with next(). term() stops

// delivery for good: the server advances past the message and never redelivers

// it. Use it for a poison message that will fail every time, so it doesn't loop

// forever.

const js = jetstream(nc);

const c = await js.consumers.get("ORDERS", "shipping");



const m = await c.next();

if (m) {

  console.log(`${m.subject}: ${m.string()}`);

  m.term();

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



// Terminate the message. This is for a poison message the consumer can never

// process. The server stops redelivering it and advances past it for good.

if err := msg.Term(); err != nil {

	panic(err)

}

fmt.Println("Message terminated, it will not be redelivered")
```

#### Python

```
# Bind to the durable consumer and pull a single message.

psub = await js.pull_subscribe_bind("shipping", stream="ORDERS")



msgs = await psub.fetch(batch=1, timeout=5)

msg = msgs[0]

print(f"{msg.subject}: {msg.data.decode()}")



# Terminate a poison message: stop delivery for good, no redelivery.

await msg.term()
```

#### Java

```
// Pull one message that can never be processed (a poison message)

// and terminate it. The server stops redelivering without marking

// it as successfully processed.

Message m = cc.next(Duration.ofSeconds(5));

if (m == null) {

    System.out.println("Nothing to read.");

    return;

}



System.out.printf("subject=%s data=%s%n",

    m.getSubject(),

    new String(m.getData(), StandardCharsets.UTF_8));



m.term();

System.out.println("Message terminated; no more redeliveries.");
```

#### Rust

```
// Bind to the existing durable consumer.

let stream = js.get_stream("ORDERS").await?;

let consumer: PullConsumer = stream.get_consumer("shipping").await?;



// Fetch a single message and terminate it. A terminated message is one

// this consumer can never process, so the server stops redelivering it.

let mut messages = consumer.fetch().max_messages(1).messages().await?;

while let Some(msg) = messages.next().await {

    let msg = msg?;

    println!("{}: {}", msg.subject, std::str::from_utf8(&msg.payload)?);

    msg.ack_with(AckKind::Term).await?;

}
```

#### C#/.NET

```
// Bind to the existing durable consumer

var consumer = await js.GetConsumerAsync("ORDERS", "shipping");



// Pull one message

var msg = await consumer.NextAsync<Order>();

if (msg is { } order)

{

    output.WriteLine($"{order.Subject}: {order.Data}");



    // Terminate: stop redelivery of a poison message that will never succeed

    await order.AckTerminateAsync();

}
```

#### C

```
// Bind to the durable "shipping" consumer created earlier.

jsSubOptions so;

natsMsgList  list = {NULL, 0};



jsSubOptions_Init(&so);

so.Stream   = "ORDERS";

so.Consumer = "shipping";

s = js_PullSubscribe(&sub, js, NULL, NULL, NULL, &so, &jerr);



// Fetch a single message from the consumer.

if (s == NATS_OK)

    s = natsSubscription_Fetch(&list, sub, 1, 5000, &jerr);

if ((s == NATS_OK) && (list.Count > 0))

{

    natsMsg *msg = list.Msgs[0];



    printf("Received on %s: %.*s\n", natsMsg_GetSubject(msg),

           natsMsg_GetDataLength(msg), natsMsg_GetData(msg));



    // Terminate the message. This is for a poison message the

    // consumer can never process. The server stops redelivering

    // it and advances past it for good.

    s = natsMsg_Term(msg, NULL);

    if (s == NATS_OK)

        printf("Message terminated, it will not be redelivered\n");

}

natsMsgList_Destroy(&list);
```

**After a term**, the message is gone from this consumer but not from the stream. Term runs through the same path as an ack: the pending entry clears and the acknowledgment floor moves past the message, so it's never redelivered to this consumer. The message itself stays in the stream under the default `Limits` retention — other consumers still see it, and it ages out with the stream's limits like any other message. On a `WorkQueue` or `Interest` stream, where a handled message is removed, a term removes it just as an ack would; see [Retention policies](/learn/jetstream/retention-policies.md).

The difference from an ack is that the work never happened, so the server records the give-up. It publishes a **terminated advisory** on `$JS.EVENT.ADVISORY.CONSUMER.MSG_TERMINATED.ORDERS.shipping`, carrying the stream and consumer sequence, the delivery count, and an optional reason you can attach to the term. Watch it the way the pitfall below watches the max-deliveries advisory, so a terminated `order_id` doesn't disappear without a trace. The advisory's fields are in [Reference → Terminated advisory](/reference/jetstream/advisory/terminated.md).

Use term only when the code can tell that no future attempt will succeed. When in doubt, nak with a delay and let the delivery limit below decide.

## The server controls

The four responses are the client's side. The server has two settings that work with them, both on the consumer.

**AckWait** is the timer. If a delivery is not ack'd, nak'd, or kept alive with in-progress before AckWait runs out, the server treats it as a silent failure and redelivers. The default is 30 seconds. Shorten it for fast work, lengthen it for slow work.

**MaxDeliver** is the limit on attempts. It caps how many times the server will deliver one message before giving up. The default is `-1`, which means no limit. A message can be redelivered forever.

These two cover the two ways a delivery can fail. AckWait handles the case where no answer arrives. MaxDeliver caps the case where a worker keeps sending a nak on the same message.

A timeout and a nak both cause redelivery, but they're timed differently. The backoff schedule below only spaces out redeliveries that fire when the AckWait timer runs out. A bare nak redelivers right away, and a configured backoff doesn't slow it — to delay a nak, the client attaches the delay to the nak itself.

Set both on the consumer with `nats consumer edit`:

#### CLI

```
#!/bin/bash

# Set the two server-side ack controls on the shipping consumer.

#

#   --ack=explicit   each message must be answered on its own

#   --wait=10s       AckWait: redeliver if no answer within 10 seconds

#   --max-deliver=5  cap delivery attempts at 5 (default -1 = unlimited)

nats consumer edit ORDERS shipping \

  --ack=explicit \

  --wait=10s \

  --max-deliver=5



# Read the controls back. Look for: Ack Wait, Maximum Deliveries.

nats consumer info ORDERS shipping
```

Read them back from `nats consumer info ORDERS shipping`:

```
Configuration:



           Ack Policy: Explicit

             Ack Wait: 10.00s

        Replay Policy: Instant

   Maximum Deliveries: 5

      Max Ack Pending: 1,000
```

With `--max-deliver=5`, a message that fails five times stops being delivered. Without a term path, that message is dropped after the fifth attempt. With a term path, your code retires the poison message itself, before the limit is reached.

## Backoff: a growing delay between attempts

A flat AckWait waits the same amount of time before every redelivery. A backoff makes that wait grow.

The server holds a list of delays, one per attempt: wait one second before the second delivery, five seconds before the third, 30 before the fourth. The wait between attempts grows each round instead of staying the same.

The CLI builds the list for you from a range:

```
nats consumer edit ORDERS shipping --backoff=linear --backoff-steps=5 --backoff-min=1s --backoff-max=30s
```

If the list has fewer entries than MaxDeliver allows, the server reuses the last entry for the remaining attempts.

Setting a backoff replaces AckWait: the first entry in the list becomes the wait before the first redelivery, so it's also the ack deadline for the first delivery. Here `--backoff-min=1s` drops the effective AckWait to 1 second, overriding the 10 seconds set earlier. Pick a `--backoff-min` at least as long as normal processing takes, or a slow job trips redelivery while it's still running.

`nats consumer edit --help` lists every backoff flag. We use only a linear range here.

## Ack policy: the other values

This page assumed `explicit`, the policy `shipping` was created with. AckPolicy has three more values.

`explicit` answers each message on its own. It's what `shipping` uses and the right default for work that must not be lost — everything on this page depends on it. `none` requires no answer at all: the server treats a message as done the moment it's delivered, so there's no pending list, no Ack Wait, and no redelivery, and nothing on this page applies. `all` lets one ack answer every earlier message too — cheaper, but it only fits a consumer that processes strictly in order, since acking message 10 also retires 1 through 9. Strict order is a requirement you have to create, not something a consumer does by default: [Delivery and acknowledgment](/learn/jetstream/delivery-and-acknowledgment.md) showed that a redelivery arrives after later messages unless `MaxAckPending` is 1. On a consumer without that setting, acking message 10 also retires a message 7 that failed and was waiting to come back — silent data loss. A fourth value, `flow_control`, is for the push consumers the server creates for durable mirrors and sources: acks ride the flow-control responses and behave like `all`. You won't set it on a work consumer like `shipping`.

The full list of available policies is in [Reference → Consumer configuration](/reference/jetstream/api/consumer/create.md). This page uses `explicit`.

## Pitfalls

Each response and control is simple on its own. Most traps come from how they combine.

**A plain nak retries with no delay.** A nak with no delay asks for redelivery in the same instant. A temporary failure then retries right away, fails again, and ties up one worker on one message. Don't send a bare nak for a temporary failure. Nak with a delay so the redelivery waits before it retries (covered above). A consumer backoff won't help here — it spaces out AckWait timeouts, not naks.

**A poison message with no term path uses every attempt.** Without term, a broken payload is nak'd over and over until MaxDeliver gives up, using the full set of attempts and holding up the messages behind it. When the code can tell no future attempt will succeed, answer term so the message leaves the pending list at once instead of working through the limit.

**MaxDeliver drops a message with no dead-letter.** When a message hits the delivery limit, the server removes it from the consumer's pending list and never delivers it again. The message stays in the stream, but the `shipping` consumer's normal output says nothing, so the drop is easy to miss. JetStream has no built-in dead-letter queue. You can still catch the drop: the server publishes a max-deliveries advisory on `$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping` the moment a message goes past its limit ([Reference → Max-deliveries advisory](/reference/jetstream/advisory/max-deliver.md)). Subscribe to it so a poison `order_id` isn't dropped without notice:

#### CLI

```
#!/bin/bash

# A message that hits MaxDeliver leaves the consumer with no dead-letter

# queue. It is not lost from the stream, but the shipping consumer stops

# delivering it -- and nothing in the consumer's normal output says so.

#

# The drop is observable: the server publishes an advisory the moment a

# message exceeds its delivery limit. Watch for it so a poison message

# does not vanish unnoticed.



# Subscribe to the max-deliveries advisory for the shipping consumer.

# The server publishes here when a message (e.g. order ord_8w2k) is

# delivered MaxDeliver times without a final ack.

nats sub '$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping'



# Or watch every JetStream advisory in one stream, including this one:

#   nats events --js-advisory --no-srv-advisory
```

#### JavaScript/TypeScript

```
// The server publishes a max-deliveries advisory when a message on the shipping

// consumer hits its delivery limit without an ack. It's a plain core subject, so

// subscribe with the core client to watch for poison messages. Each advisory is

// JSON describing the stream, consumer, and sequence that gave up.

const sub = nc.subscribe(

  "$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping",

);

for await (const m of sub) {

  console.log(`max deliveries reached: ${m.string()}`);

}
```

#### Go

```
// Max-deliveries advisories are plain core NATS messages, so subscribe with

// the core client instead of a JetStream consumer. The server publishes one

// each time a message on the "shipping" consumer hits its delivery limit.

subject := "$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping"

sub, err := nc.SubscribeSync(subject)

if err != nil {

	panic(err)

}

defer sub.Unsubscribe()



// Print each advisory as it arrives.

for {

	msg, err := sub.NextMsg(nats.DefaultTimeout)

	if err == nats.ErrTimeout {

		// No advisory yet; keep waiting.

		continue

	}

	if err != nil {

		panic(err)

	}

	fmt.Printf("Max-deliveries advisory: %s\n", string(msg.Data))

}
```

#### Python

```
# JetStream publishes an advisory when a message hits its max delivery limit.

# Subscribe with the core API to watch them for the shipping consumer.

subject = "$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping"



async def handler(msg):

    print(f"max deliveries advisory: {msg.data.decode()}")



await nc.subscribe(subject, cb=handler)

print(f"Watching {subject}")



# Keep the subscription open to receive advisories as they arrive.

await asyncio.sleep(60)
```

#### Java

```
// Watch the max-deliveries advisory for this consumer. The server

// publishes one of these whenever a message hits MaxDeliver and is

// dropped, which is your signal to route it to a dead-letter flow.

String advisory = "$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping";



Dispatcher d = nc.createDispatcher(msg ->

    System.out.println("max-deliveries advisory: " +

        new String(msg.getData(), StandardCharsets.UTF_8)));

d.subscribe(advisory);



// Keep the subscription open so advisories can arrive.

Thread.sleep(60_000);
```

#### Rust

```
// Subscribe to the max-deliveries advisory for the shipping consumer.

// The server publishes here when a message hits the consumer's

// MaxDeliver limit, which is how you find poison messages.

let mut advisories = client

    .subscribe("$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping")

    .await?;



while let Some(advisory) = advisories.next().await {

    println!(

        "max deliveries: {}",

        std::str::from_utf8(&advisory.payload)?

    );

}
```

#### C#/.NET

```
// Watch for messages a consumer gave up on after hitting MaxDeliver

var subject = "$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping";

await foreach (var advisory in client.SubscribeAsync<string>(subject, cancellationToken: cts.Token))

{

    output.WriteLine($"max deliveries reached: {advisory.Data}");

}
```

#### C

```
// Max-deliveries advisories are plain core NATS messages, so

// subscribe with the core client instead of a JetStream consumer.

// The server publishes one each time a message on the "shipping"

// consumer hits its delivery limit.

const char *subject = "$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping";



s = natsConnection_SubscribeSync(&sub, conn, subject);



// Print each advisory as it arrives.

while (s == NATS_OK)

{

    natsMsg *msg = NULL;



    s = natsSubscription_NextMsg(&msg, sub, 60000);

    if (s == NATS_OK)

    {

        printf("Max-deliveries advisory: %.*s\n",

               natsMsg_GetDataLength(msg), natsMsg_GetData(msg));

        natsMsg_Destroy(msg);

    }

}
```

**AckWait shorter than real processing time causes double work.** If a job often takes longer than AckWait and the worker never sends in-progress, the server decides the worker stopped and redelivers a message that's still being handled, so two workers run the same order. Either raise AckWait to cover the slow case, or send in-progress to reset the timer while a long job runs (both covered above).

## Where you are

The `shipping` consumer is unchanged in shape (still pull, still `AckPolicy=explicit`), but now you understand it fully. You know the four answers a client gives, and the two server controls, AckWait and MaxDeliver, that decide when a message comes back and when it stops. A poison message has a clear exit through term.

## What's next

One worker pulls one order at a time. The next page covers the two ways a client drives a pull consumer — [fetching a batch versus consuming a continuous flow](/learn/jetstream/pull-consumers.md) — and when to reach for each.

## See also

* [Reference → Consumer configuration](/reference/jetstream/api/consumer/create.md) — AckWait, MaxDeliver, backoff arrays, and every other field.
* [Reference → Terminated advisory](/reference/jetstream/advisory/terminated.md), [Nak advisory](/reference/jetstream/advisory/nak.md), and [Max-deliveries advisory](/reference/jetstream/advisory/max-deliver.md) — the events the server raises on term, nak, and a delivery-limit drop.
