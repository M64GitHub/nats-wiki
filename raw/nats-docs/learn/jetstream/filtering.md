<!-- source: https://docs.nats.io/learn/jetstream/filtering.md · fetched 2026-08-31 · section: filtering -->
# Filtering what you consume

The `billing` consumer from the previous page reads every message in the `ORDERS` stream — no filter, the whole log.

A reporting job needs only one thing: when an order ships. It has no use for `orders.created` or `orders.canceled`, so delivering those messages to it would be wasted work on both sides.

This page adds a second consumer that reads only `orders.shipped`, and shows why one consumer doesn't interfere with another.

## What a filter does

A **filter** is a subject pattern attached to a consumer. The consumer receives only the messages whose subject matches the filter; the rest of the stream is skipped.

The pattern can be a literal subject like `orders.shipped`, or a wildcard: a filter of `orders.*` matches every order event, while `orders.shipped` matches only the ships. The `*` and `>` wildcards behave exactly as they do for a [core subscription](/learn/core-nats/subjects-and-wildcards.md).

The stream still captures all of `orders.>`; nothing about the stream changes. The filter lives on the consumer and decides which of the stored messages this consumer receives.

Create the `analytics` consumer with a filter of `orders.shipped`:

#### CLI

```
#!/bin/bash



# Add a second consumer to the ORDERS stream that reads only orders.shipped.

# The --filter flag pins the consumer to a single subject.

nats consumer add ORDERS analytics \

  --filter "orders.shipped" \

  --pull \

  --ack explicit \

  --defaults



# Inspect it — the config now shows a Filter Subject line.

nats consumer info ORDERS analytics



# Pull from analytics: only orders.shipped messages come back.

# orders.created and orders.canceled are skipped for this consumer.

nats consumer next ORDERS analytics --count 5
```

#### JavaScript/TypeScript

```
// ORDERS already holds orders.created and orders.shipped messages. Create a

// durable pull consumer that only sees one of those subjects: filter_subject

// "orders.shipped" tells the server to skip everything else. ack_policy Explicit

// means a reader acks each delivered message. add() is idempotent.

const jsm = await jetstreamManager(nc);

await jsm.consumers.add("ORDERS", {

  durable_name: "analytics",

  ack_policy: AckPolicy.Explicit,

  filter_subject: "orders.shipped",

});

console.log("Created filtered consumer: analytics (orders.shipped)");



// Bind to it and pull a small batch. Only orders.shipped come back — the filter

// drops orders.created before it ever reaches this consumer.

const js = jetstream(nc);

const c = await js.consumers.get("ORDERS", "analytics");

const msgs = await c.fetch({ max_messages: 5, expires: 2000 });

for await (const m of msgs) {

  console.log(m.subject);

  await m.ack();

}
```

#### Go

```
// Create a durable pull consumer named "analytics" on the ORDERS stream.

// FilterSubject narrows delivery to "orders.shipped", so the consumer never

// sees "orders.created" messages even though the stream stores both.

cons, err := js.CreateOrUpdateConsumer(ctx, "ORDERS", jetstream.ConsumerConfig{

	Durable:       "analytics",

	FilterSubject: "orders.shipped",

	DeliverPolicy: jetstream.DeliverAllPolicy,

	AckPolicy:     jetstream.AckExplicitPolicy,

})

if err != nil {

	panic(err)

}



fmt.Printf("Created consumer: %s\n", cons.CachedInfo().Name)

fmt.Printf("Filter: %s\n", cons.CachedInfo().Config.FilterSubject)



// Fetch up to 5 messages with a short expiry. Only "orders.shipped"

// messages come back; the filter excludes everything else.

msgs, err := cons.Fetch(5, jetstream.FetchMaxWait(2*time.Second))

if err != nil {

	panic(err)

}

for msg := range msgs.Messages() {

	fmt.Printf("Received on %s\n", msg.Subject())

	msg.Ack()

}

if err := msgs.Error(); err != nil {

	panic(err)

}
```

#### Python

```
# Create a durable pull consumer that only sees orders.shipped.

# The filter is applied server-side: orders.created never reaches this consumer.

await js.add_consumer(

    "ORDERS",

    ConsumerConfig(

        durable_name="analytics",

        ack_policy=AckPolicy.EXPLICIT,

        filter_subject="orders.shipped",

    ),

)

print("Created filtered consumer analytics on stream ORDERS")



# Fetch a small batch. Only orders.shipped messages come back.

psub = await js.pull_subscribe_bind("analytics", stream="ORDERS")

msgs = await psub.fetch(batch=5, timeout=2)

for msg in msgs:

    print(f"got {msg.subject}")

    await msg.ack()
```

#### Java

```
// Create a durable pull consumer that only sees orders.shipped.

// The filter subject narrows the stream's subjects down to one.

ConsumerContext cc = sc.createOrUpdateConsumer(

    ConsumerConfiguration.builder()

        .durable("analytics")

        .filterSubject("orders.shipped")

        .ackPolicy(AckPolicy.Explicit)

        .build());



System.out.println("Created filtered consumer: " + cc.getConsumerName());



// Fetch a small batch. Only orders.shipped messages come back;

// orders.created is filtered out before it reaches this consumer.

try (FetchConsumer fc = cc.fetch(

        FetchConsumeOptions.builder().maxMessages(5).expiresIn(2000).build())) {

    Message m;

    while ((m = fc.nextMessage()) != null) {

        System.out.println("subject=" + m.getSubject());

        m.ack();

    }

}
```

#### Rust

```
// Create a durable pull consumer that only sees orders.shipped messages.

// The filter subject restricts delivery to one subject in the stream.

let stream = js.get_stream("ORDERS").await?;

let consumer = stream

    .create_consumer(pull::Config {

        durable_name: Some("analytics".to_string()),

        filter_subject: "orders.shipped".to_string(),

        ack_policy: AckPolicy::Explicit,

        ..Default::default()

    })

    .await?;



println!("Created filtered consumer: {}", consumer.cached_info().name);



// Fetch a small batch with a short expiry. Only orders.shipped come back.

let mut messages = consumer

    .fetch()

    .max_messages(5)

    .expires(std::time::Duration::from_secs(2))

    .messages()

    .await?;

while let Some(msg) = messages.next().await {

    let msg = msg?;

    println!("got: {}", msg.subject);

    msg.ack().await?;

}
```

#### C#/.NET

```
// Create a durable pull consumer that only sees orders.shipped

var consumer = await js.CreateOrUpdateConsumerAsync("ORDERS", new ConsumerConfig("analytics")

{

    AckPolicy = ConsumerConfigAckPolicy.Explicit,

    FilterSubject = "orders.shipped",

});



output.WriteLine($"Created durable consumer {consumer.Info.Config.Name} filtered on orders.shipped");



// Fetch a small batch; only orders.shipped comes back

await foreach (var msg in consumer.FetchAsync<Order>(opts: new NatsJSFetchOpts { MaxMsgs = 5, Expires = TimeSpan.FromSeconds(2) }))

{

    output.WriteLine($"{msg.Subject}: {msg.Data}");

    subjects.Add(msg.Subject);

    await msg.AckAsync();

}
```

#### C

```
// Create a durable pull consumer named "analytics" on the ORDERS

// stream. FilterSubject narrows delivery to "orders.shipped", so

// the consumer never sees "orders.created" messages even though

// the stream stores both.

jsConsumerConfig cc;

jsSubOptions     so;

natsMsgList      list = {NULL, 0};

int              i;



jsConsumerConfig_Init(&cc);

cc.Durable       = "analytics";

cc.FilterSubject = "orders.shipped";

cc.DeliverPolicy = js_DeliverAll;

cc.AckPolicy     = js_AckExplicit;

s = js_AddConsumer(&ci, js, "ORDERS", &cc, NULL, &jerr);

if (s == NATS_OK)

{

    printf("Created consumer: %s\n", ci->Name);

    printf("Filter: %s\n", ci->Config->FilterSubject);

}



// Bind to the consumer and fetch up to 5 messages with a short

// expiry. Only "orders.shipped" messages come back; the filter

// excludes everything else.

jsSubOptions_Init(&so);

so.Stream   = "ORDERS";

so.Consumer = "analytics";

if (s == NATS_OK)

    s = js_PullSubscribe(&sub, js, NULL, NULL, NULL, &so, &jerr);

if (s == NATS_OK)

    s = natsSubscription_Fetch(&list, sub, 5, 2000, &jerr);

for (i = 0; (s == NATS_OK) && (i < list.Count); i++)

{

    printf("Received on %s\n", natsMsg_GetSubject(list.Msgs[i]));

    natsMsg_Ack(list.Msgs[i], NULL);

}

natsMsgList_Destroy(&list);
```

The new flag is `--filter`. It ties the consumer to a single filter subject. A message on `orders.shipped` reaches `analytics`; a message on `orders.created` or `orders.canceled` does not.

Ask the server to describe the consumer:

```
nats consumer info ORDERS analytics
```

The configuration block now carries a line the `billing` consumer didn't have:

```
Configuration:



                Name: analytics

           Pull Mode: true

      Filter Subject: orders.shipped

      Deliver Policy: All

          Ack Policy: Explicit

            Ack Wait: 30.00s

       Replay Policy: Instant

     Max Ack Pending: 1,000

   Max Waiting Pulls: 512
```

`Filter Subject: orders.shipped` is the line that matters. The `billing` consumer has no filter, so its info output omits this line. No filter line means every subject in the stream.

## Two consumers with separate positions

The `analytics` consumer and the `billing` consumer read the same stream, but each tracks its own position in it.

From the previous page, a consumer keeps a cursor: the sequence number of the last message it delivered and saw acknowledged. That cursor belongs to the consumer, not to the stream. Two consumers on one stream have two separate cursors.

The server stores the cursor alongside the consumer's config and ack state, separate from the stream's messages. When `analytics` advances its cursor past sequence `3`, `billing`'s position does not change. Both consumers read the same stored messages from their own cursor.

**Message flow — Two consumers, separate positions (animated):** Two consumers read one ORDERS stream from independent positions. The billing consumer has no filter and delivers every order; the analytics consumer filters to orders.shipped and delivers only the shipped messages, skipping orders.created. Each keeps its own cursor, so reading from one never moves the other: billing advances through all six messages and reaches #6, while analytics has delivered only the two shipped orders and sits at #5. The stream keeps one shared copy of every message and serves each consumer from its own position.

`billing` reads every order and advances through all of them; `analytics` delivers only the `orders.shipped` messages and skips the rest, so the two cursors come to rest at different positions. Neither one moves the other.

Pull from `analytics` and see what comes back:

```
nats consumer next ORDERS analytics --count 5
```

`analytics` sees only the `orders.shipped` message stored on the publishing page, sequence `3`. The `orders.created` messages at sequences `1` and `2` don't appear for this consumer. They're still in the stream; the filter just hides them from `analytics`.

`billing` stays wherever you left it. Reading from `analytics` did not move `billing`'s cursor, and it did not consume or delete any message from the stream.

## A consumer is a view

A consumer is an independent **view** over the stored messages, with its own filter, cursor, and ack state. The stream holds the one shared copy of every message, and each consumer reads it from its own position.

Because consumers are independent, a filter is a cheap way to send the same messages to more than one reader. Adding `analytics` cost one command. It did not copy any data, it did not slow down `billing`, and it can start, stop, or fall behind without affecting any other consumer. The server keeps one copy of each message and serves every consumer from it.

This differs from the core NATS [queue group](/learn/core-nats/queue-groups.md) you met in core NATS. A queue group splits one subject's live traffic across workers that share the load. Here, each consumer gets its own full view of the stored stream, filtered to what it asked for. Sharing load within one consumer — the [worker-pool pattern](/learn/jetstream/worker-pool.md) — comes later in the chapter.

## Other filtering options

The `analytics` consumer filters on a single subject. A consumer can also filter on several subjects at once. That goes beyond what this scenario needs.

For the full set of consumer filtering options, including multiple filter subjects, see [Reference → Create Consumer](/reference/jetstream/api/consumer/create.md). We use only a single `Filter Subject` here.

## Pitfalls

A filter is a small piece of config, but a wrong one fails quietly.

**A filter that matches nothing.** The server accepts any filter subject, even one that matches no message in the stream. A typo like `orders.shiped` creates a valid consumer that never receives anything. There's no error and no warning, just an empty pull. Don't assume an empty pull means the stream is empty; first confirm the filter matches a subject the stream actually stores.

#### CLI

```
#!/bin/bash



# A filter that matches no subject in the stream is accepted without error.

# Here the typo "orders.shiped" matches nothing in ORDERS (orders.>).

nats consumer add ORDERS analytics-typo \

  --filter "orders.shiped" \

  --pull \

  --ack explicit \

  --defaults



# The consumer exists and its config looks fine.

nats consumer info ORDERS analytics-typo



# But pulling delivers nothing — the request just times out.

# No error tells you the filter was wrong; the consumer is simply silent.

nats consumer next ORDERS analytics-typo --count 5 --timeout 2s



# Confirm the filter never matched: Delivered shows 0 of the stored orders.

nats consumer info ORDERS analytics-typo | grep -A1 "Delivery counts"
```

#### JavaScript/TypeScript

```
// The filter_subject here has a typo: "orders.shiped" matches no subject ORDERS

// actually stores. The server still accepts the consumer — a filter that matches

// nothing is valid, just empty.

const jsm = await jetstreamManager(nc);

await jsm.consumers.add("ORDERS", {

  durable_name: "analytics-typo",

  ack_policy: AckPolicy.Explicit,

  filter_subject: "orders.shiped",

});

console.log("Created filtered consumer: analytics-typo (orders.shiped)");



// Try to pull. The fetch waits out its short expiry and returns nothing — no

// error, no message. A wrong filter fails silently: the pull just times out

// empty because no stored subject matches.

const js = jetstream(nc);

const c = await js.consumers.get("ORDERS", "analytics-typo");

const msgs = await c.fetch({ max_messages: 5, expires: 2000 });

let count = 0;

for await (const m of msgs) {

  count++;

  await m.ack();

}

if (count === 0) {

  console.log("pull returned nothing: filter matched no stored subject");

}
```

#### Go

```
// Create a durable pull consumer named "analytics-typo" on the ORDERS

// stream. The filter "orders.shiped" has a typo (one "p"), so it matches

// no subject the stream actually stores.

cons, err := js.CreateOrUpdateConsumer(ctx, "ORDERS", jetstream.ConsumerConfig{

	Durable:       "analytics-typo",

	FilterSubject: "orders.shiped",

	DeliverPolicy: jetstream.DeliverAllPolicy,

	AckPolicy:     jetstream.AckExplicitPolicy,

})

if err != nil {

	panic(err)

}



// Fetch with a short expiry. The fetch succeeds with no error, but the

// channel yields zero messages because the filter matched no stored subject.

msgs, err := cons.Fetch(5, jetstream.FetchMaxWait(2*time.Second))

if err != nil {

	panic(err)

}

count := 0

for range msgs.Messages() {

	count++

}

if err := msgs.Error(); err != nil {

	panic(err)

}



// A wrong filter fails silently: the pull returned nothing, and no error

// was raised. The consumer is healthy, it just never matches a message.

fmt.Printf("Received %d messages: the filter matched no stored subject, so the pull returned nothing (no error).\n", count)
```

#### Python

```
# Note the typo: "orders.shiped" matches no subject in the stream.  # codespell:ignore shiped

# JetStream accepts the consumer anyway. The wrong filter fails silently.

await js.add_consumer(

    "ORDERS",

    ConsumerConfig(

        durable_name="analytics-typo",

        ack_policy=AckPolicy.EXPLICIT,

        filter_subject="orders.shiped",  # codespell:ignore shiped

    ),

)



psub = await js.pull_subscribe_bind("analytics-typo", stream="ORDERS")

try:

    await psub.fetch(batch=5, timeout=2)

except nats.errors.TimeoutError:

    # No error from the server. The pull simply returned nothing because the

    # filter matched no stored subject. A wrong filter looks like an empty stream.

    print("Fetch timed out: the filter matched no stored subject")
```

#### Java

```
// The filter subject has a typo: "orders.shiped" matches no stored

// subject. The consumer is still created without error.

ConsumerContext cc = sc.createOrUpdateConsumer(

    ConsumerConfiguration.builder()

        .durable("analytics-typo")

        .filterSubject("orders.shiped")

        .ackPolicy(AckPolicy.Explicit)

        .build());



// The fetch blocks until the expiry, then returns nothing. A wrong

// filter fails silently: no messages, no error.

try (FetchConsumer fc = cc.fetch(

        FetchConsumeOptions.builder().maxMessages(5).expiresIn(2000).build())) {

    Message m = fc.nextMessage();

    if (m == null) {

        System.out.println("Pull returned nothing: filter matched no stored subject.");

    }

}
```

#### Rust

```
// Create a durable pull consumer whose filter has a typo: "orders.shiped"

// matches no stored subject, so the consumer is valid but empty.

let stream = js.get_stream("ORDERS").await?;

let consumer = stream

    .create_consumer(pull::Config {

        durable_name: Some("analytics-typo".to_string()),

        filter_subject: "orders.shiped".to_string(),

        ack_policy: AckPolicy::Explicit,

        ..Default::default()

    })

    .await?;



// The fetch waits up to the expiry, then returns with no messages and no

// error. A wrong filter fails silently: nothing matches, nothing arrives.

let mut messages = consumer

    .fetch()

    .max_messages(5)

    .expires(std::time::Duration::from_secs(2))

    .messages()

    .await?;

let mut count = 0;

while let Some(msg) = messages.next().await {

    msg?;

    count += 1;

}

if count == 0 {

    println!("Pull returned nothing: the filter matched no stored subject.");

}
```

#### C#/.NET

```
// The filter has a typo: "orders.shiped" matches no subject the stream stores

var consumer = await js.CreateOrUpdateConsumerAsync("ORDERS", new ConsumerConfig("analytics-typo")

{

    AckPolicy = ConsumerConfigAckPolicy.Explicit,

    FilterSubject = "orders.shiped",

});



// The fetch waits out its expiry and returns nothing, with no error

await foreach (var msg in consumer.FetchAsync<Order>(opts: new NatsJSFetchOpts { MaxMsgs = 5, Expires = TimeSpan.FromSeconds(2) }))

{

    received++;

    await msg.AckAsync();

}



output.WriteLine($"Pull returned {received} messages: the filter matched no stored subject, so a wrong filter fails silently");
```

#### C

```
// Create a durable pull consumer named "analytics-typo" on the ORDERS

// stream. The filter "orders.shiped" has a typo (one "p"), so it matches

// no subject the stream actually stores.

if (s == NATS_OK)

{

    jsSubOptions_Init(&so);

    so.Stream = "ORDERS";

    s = js_PullSubscribe(&sub, js, "orders.shiped", "analytics-typo", NULL, &so, &jerr);

}



// Fetch with a short wait. The fetch times out with zero messages

// because the filter matched no stored subject; that is not an error.

if (s == NATS_OK)

{

    s = natsSubscription_Fetch(&list, sub, 5, 2000, &jerr);

    if (s == NATS_TIMEOUT)

        s = NATS_OK;

}



// A wrong filter fails silently: the pull returned nothing, and no error

// was raised. The consumer is healthy, it just never matches a message.

if (s == NATS_OK)

    printf("Received %d messages: the filter matched no stored subject, so the pull returned nothing (no error).\n",

           list.Count);
```

When a pull comes back empty, run `nats consumer info` and check the `Filter Subject` line against the stream's subjects. A filter outside `orders.>` can never match.

**Expecting a filter to delete from the stream.** A filter narrows one consumer's view; it never removes messages. After `analytics` reads `orders.shipped`, every `orders.created` and `orders.canceled` message is still stored and still readable by `billing`. Don't use a filter to prune a stream. What stays and what ages out is controlled by the stream's limits, covered in [Shaping the stream](/learn/jetstream/shaping-the-stream.md), not by any consumer.

**Overlapping filters within one consumer.** Overlap *between* consumers is fine on limits and interest streams: two separate consumers whose filters match the same subject each get their own full copy of those messages. That's the kind of sharing this page relies on. The exception is work-queue retention, where consumers' filters must not overlap each other. See [Retention policies](/learn/jetstream/retention-policies.md).

Overlap *inside* one consumer is different. You can give a single consumer several filter subjects, but if one of those subjects already covers another, like `orders.>` next to `orders.shipped`, the create call fails with `consumer subject filters cannot overlap`. Filters that only partly overlap, where neither covers the other, are accepted.

## Where you are

The `ORDERS` stream now has two consumers reading it:

* `billing`: no filter, reads every order; the reader from the previous page
* `analytics`: filtered to `orders.shipped`, sees only ships

Both read the same stored messages. Neither consumer's progress affects the other, and the stream itself is untouched by either read.

## What's next

Both `billing` and `analytics` read on the happy path: pull a message, ack it, move on. The next page is about what that acknowledgment actually does — how a message is held in flight until it's confirmed, what a double ack adds, and how an unacked message is redelivered.

## See also

* [Reference → Create Consumer](/reference/jetstream/api/consumer/create.md) — every consumer config field, including multiple filter subjects.
* [Reading back the stream](/learn/jetstream/reading-back.md) — where you met the consumer cursor this page builds on.
