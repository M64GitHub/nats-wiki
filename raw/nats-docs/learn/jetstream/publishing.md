<!-- source: https://docs.nats.io/learn/jetstream/publishing.md · fetched 2026-08-31 · section: publishing -->
# Publishing

The `ORDERS` stream is empty. This page puts messages into it. Publishing into a stream works like a normal NATS publish, with one difference: the server sends back a confirmation that it stored the message. This page covers that confirmation, called a `PubAck`, and how to make a publish safe to retry.

**Message flow — Publish and PubAck (animated):** Animated PubAck flow: a publisher sends a message to a subject; the ORDERS stream accepts it (it listens on orders.>), stores it and assigns a sequence number, then returns a PubAck with the stream name and sequence.

* Publisher → orders.created (subject: orders.created)

## Publish from the CLI

Start in the terminal. A plain `nats pub` is a core NATS publish: the client sends the message and the server returns nothing. When you publish into a stream you usually want a confirmation, so add the `--jetstream` flag:

```
nats pub --jetstream orders.created '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'
```

The server appends the message to `ORDERS` (the stream captures `orders.>`) and replies on the same call:

```
Stored in Stream: ORDERS Sequence: 1
```

That reply is the `PubAck`. It contains the name of the stream that stored the message and the sequence number the stream gave it. Sequence numbers start at `1` and only increase. The server gives each new message the next number and never reuses one.

Publish two more messages so the stream has some content. Each one is acknowledged with the next sequence number, `2` and then `3`:

```
nats pub --jetstream orders.created '{"order_id":"ord_2zr9","customer":"globex","total_cents":7800,"ts":"2026-05-22T10:14:25Z"}'

nats pub --jetstream orders.shipped '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:31Z"}'
```

You can check the whole stream with `nats stream info ORDERS`. It now reports three messages:

```
State:



                     Messages: 3

                        Bytes: 404 B

               First Sequence: 1 @ 2026-05-22 10:14:22

                Last Sequence: 3 @ 2026-05-22 10:14:31

             Active Consumers: 0

           Number of Subjects: 2
```

You didn't have to run that command to know the writes succeeded. Each publish already reported its sequence number when it returned.

## Publish from a client library

On the CLI, the `PubAck` is printed to the screen. In application code it is a return value: the same confirmation from the server, as an object your program can read. The `PubAck` is the main thing you work with when publishing to JetStream, and the next section covers what it contains.

Here are the same three publishes from a client library:

#### JavaScript/TypeScript

```
// Publish three orders and read each PubAck, which confirms the stream that

// stored the message and the sequence it was assigned

const orders = [

  {

    subject: "orders.created",

    data:

      `{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}`,

  },

  {

    subject: "orders.created",

    data:

      `{"order_id":"ord_2zr9","customer":"globex","total_cents":7800,"ts":"2026-05-22T10:14:25Z"}`,

  },

  {

    subject: "orders.shipped",

    data:

      `{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:31Z"}`,

  },

];



for (const order of orders) {

  const pa = await js.publish(order.subject, order.data);

  console.log(`Stored in ${pa.stream}, sequence ${pa.seq}`);

}
```

#### Go

```
// Publish three order messages into the ORDERS stream. Each Publish blocks

// until the server replies with a PubAck confirming where it was stored.

orders := []struct {

	subject string

	payload string

}{

	{"orders.created", `{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}`},

	{"orders.created", `{"order_id":"ord_2zr9","customer":"globex","total_cents":7800,"ts":"2026-05-22T10:14:25Z"}`},

	{"orders.shipped", `{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:31Z"}`},

}



for _, order := range orders {

	ack, err := js.Publish(ctx, order.subject, []byte(order.payload))

	if err != nil {

		panic(err)

	}

	fmt.Printf("Stored in %s, sequence %d\n", ack.Stream, ack.Sequence)

}
```

#### Python

```
# Publish three orders. Each publish waits for the server's acknowledgement,

# which carries the stream name and the assigned sequence number.

ack = await js.publish(

    "orders.created",

    b'{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}',

)

print(f"Stored in {ack.stream}, sequence {ack.seq}")



ack = await js.publish(

    "orders.created",

    b'{"order_id":"ord_2zr9","customer":"globex","total_cents":7800,"ts":"2026-05-22T10:14:25Z"}',

)

print(f"Stored in {ack.stream}, sequence {ack.seq}")



ack = await js.publish(

    "orders.shipped",

    b'{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:31Z"}',

)

print(f"Stored in {ack.stream}, sequence {ack.seq}")
```

#### Java

```
// Publish three orders to the "ORDERS" stream and read each ack

PublishAck ack1 = js.publish("orders.created",

    "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\",\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}".getBytes(StandardCharsets.UTF_8));

System.out.printf("Stored in %s at sequence %d%n", ack1.getStream(), ack1.getSeqno());



PublishAck ack2 = js.publish("orders.created",

    "{\"order_id\":\"ord_2zr9\",\"customer\":\"globex\",\"total_cents\":7800,\"ts\":\"2026-05-22T10:14:25Z\"}".getBytes(StandardCharsets.UTF_8));

System.out.printf("Stored in %s at sequence %d%n", ack2.getStream(), ack2.getSeqno());



PublishAck ack3 = js.publish("orders.shipped",

    "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\",\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:31Z\"}".getBytes(StandardCharsets.UTF_8));

System.out.printf("Stored in %s at sequence %d%n", ack3.getStream(), ack3.getSeqno());
```

#### Rust

```
// Publish three orders into the ORDERS stream, reading each ack as it returns.

let messages = [

    (

        "orders.created",

        r#"{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}"#,

    ),

    (

        "orders.created",

        r#"{"order_id":"ord_2zr9","customer":"globex","total_cents":7800,"ts":"2026-05-22T10:14:25Z"}"#,

    ),

    (

        "orders.shipped",

        r#"{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:31Z"}"#,

    ),

];



for (subject, payload) in messages {

    // The first await sends the message; the second waits for the server ack.

    let ack = js.publish(subject, payload.into()).await?.await?;

    println!("Stored in {} at sequence {}", ack.stream, ack.sequence);

}
```

#### C#/.NET

```
// Publish each order and read the ack the stream returns

var ack1 = await js.PublishAsync<Order>(

    subject: "orders.created",

    data: new Order(OrderId: "ord_8w2k", Customer: "acme-co", TotalCents: 4200, Timestamp: DateTimeOffset.Parse("2026-05-22T10:14:22Z", CultureInfo.InvariantCulture)));

output.WriteLine($"Stored in {ack1.Stream} at sequence {ack1.Seq}");



var ack2 = await js.PublishAsync<Order>(

    subject: "orders.created",

    data: new Order(OrderId: "ord_2zr9", Customer: "globex", TotalCents: 7800, Timestamp: DateTimeOffset.Parse("2026-05-22T10:14:25Z", CultureInfo.InvariantCulture)));

output.WriteLine($"Stored in {ack2.Stream} at sequence {ack2.Seq}");



var ack3 = await js.PublishAsync<Order>(

    subject: "orders.shipped",

    data: new Order(OrderId: "ord_8w2k", Customer: "acme-co", TotalCents: 4200, Timestamp: DateTimeOffset.Parse("2026-05-22T10:14:31Z", CultureInfo.InvariantCulture)));

output.WriteLine($"Stored in {ack3.Stream} at sequence {ack3.Seq}");
```

#### C

```
// Publish three order messages into the ORDERS stream. Each js_Publish

// blocks until the server replies with an ack confirming where it was

// stored.

const char *subjects[] = {"orders.created", "orders.created", "orders.shipped"};

const char *payloads[] = {

    "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\",\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}",

    "{\"order_id\":\"ord_2zr9\",\"customer\":\"globex\",\"total_cents\":7800,\"ts\":\"2026-05-22T10:14:25Z\"}",

    "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\",\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:31Z\"}"};



for (int i = 0; (i < 3) && (s == NATS_OK); i++)

{

    jsPubAck *ack = NULL;



    s = js_Publish(&ack, js, subjects[i],

                   payloads[i], (int) strlen(payloads[i]),

                   NULL, &jerr);

    if (s == NATS_OK)

    {

        printf("Stored in %s, sequence %" PRIu64 "\n", ack->Stream, ack->Sequence);

        jsPubAck_Destroy(ack);

    }

}
```

Two details show up in every one of these snippets:

1. You publish to a subject, not to a stream. The server finds the stream that captures the subject and stores the message there. Your code doesn't need to know which stream is bound to which subject.
2. The publish call returns a `PubAck` instead of nothing. That return value is how you know the message reached a stream. The next section reads it.

## What a PubAck contains

A `PubAck` has three fields you use regularly:

* **stream**: the stream that stored the message. Useful in tests and logs; in normal code you already know it.
* **sequence**: the sequence number the stream gave the message. It's the number shown by `nats stream info`. If you save it next to your business record, you can replay the stream from that point later.
* **duplicate**: `false` for a new message, `true` if the server recognized the message as a repeat. Duplicate detection is covered in [Avoiding duplicate writes](#avoiding-duplicate-writes) below.

A `PubAck` can also include a few situational fields, such as a `domain` for multi-tenant or leaf-node setups. The full list is in [Reference](/reference/jetstream/api/stream/pub-ack.md). The three above are the ones day-to-day publishing code reads.

The snippets in the previous section already return this object; reading its fields is all there is to it.

The rule: the `PubAck` is your only proof that the message was stored. When a publish fails, what you know depends on how it failed. A subject that no stream captures fails immediately (a "no responders" error), and nothing was stored. But a network timeout means no confirmation, not no write: the server may have stored the message and the ack got lost on the way back. So handle a failed publish by retrying it or reporting the failure — and make the retry safe with the `Nats-Msg-Id` header covered in [Avoiding duplicate writes](#avoiding-duplicate-writes) below.

## Stored versus delivered

A `PubAck` confirms that the server stored the message. It does not confirm that any consumer has received it. Storage and delivery are separate.

In core NATS, a message is delivered at almost the same moment the publish completes, so the two are easy to treat as one thing. In JetStream they happen at different times:

1. The publisher publishes. The server stores the message and returns a `PubAck`.
2. Later (possibly minutes, hours, or days) a client reads the message through a consumer.
3. After processing it, the client acknowledges it. Only then is the message considered handled.

The rest of this chapter covers steps 2 and 3. This page has done step 1.

## Avoiding duplicate writes

A real publisher retries when a publish fails. But a failed publish doesn't mean the message wasn't stored: a timeout can fire after the server stored the message, with only the ack lost. A plain retry then stores the same message twice. To prevent that, tag the publish with a `Nats-Msg-Id` header. The server refuses to store the same ID twice within the stream's duplicate-tracking window (the two-minute setting from the previous page's config). A blocked duplicate is the `duplicate: true` case in the `PubAck`.

On the CLI, set the header with `--header` and publish with `nats pub --jetstream` so the `PubAck` is shown:

```
nats pub --jetstream orders.created \

  --header "Nats-Msg-Id:ord_8w2k-created" \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'
```

Run that command twice. The first call stores the message and prints its sequence number (`Stored in Stream: ORDERS Sequence: …`). The second call prints the same sequence number with `Duplicate: true`, and nothing new is stored. The same header from a client library:

#### JavaScript/TypeScript

```
// Publish the same order twice with a stable msgID. Within the stream's

// duplicate window the server stores it once: the second PubAck reports the

// same sequence and `duplicate: true`

const data =

  `{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}`;



const first = await js.publish("orders.created", data, {

  msgID: "ord_8w2k-created",

});

console.log(`First:  sequence ${first.seq}, duplicate ${first.duplicate}`);



const second = await js.publish("orders.created", data, {

  msgID: "ord_8w2k-created",

});

console.log(`Second: sequence ${second.seq}, duplicate ${second.duplicate}`);
```

#### Go

```
// Publish the same message twice with a message ID. The stream uses the ID

// to detect duplicates within its dedupe window.

first, err := js.Publish(ctx, "orders.created", []byte(payload), jetstream.WithMsgID("ord_8w2k-created"))

if err != nil {

	panic(err)

}

fmt.Printf("First:  sequence %d, duplicate %t\n", first.Sequence, first.Duplicate)



// Re-publish with the same ID. The server recognizes it and reports the

// original sequence instead of storing the message again.

second, err := js.Publish(ctx, "orders.created", []byte(payload), jetstream.WithMsgID("ord_8w2k-created"))

if err != nil {

	panic(err)

}

fmt.Printf("Second: sequence %d, duplicate %t\n", second.Sequence, second.Duplicate)
```

#### Python

```
# Set "Nats-Msg-Id" so the server can detect duplicates within the stream's

# duplicate window.

payload = b'{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

headers = {"Nats-Msg-Id": "ord_8w2k-created"}



# Publish the same message twice with the same id.

first = await js.publish("orders.created", payload, headers=headers)

print(f"First:  sequence {first.seq}, duplicate {first.duplicate}")



second = await js.publish("orders.created", payload, headers=headers)

print(f"Second: sequence {second.seq}, duplicate {second.duplicate}")
```

#### Java

```
// Tag the message with a stable id so a retry is deduplicated

PublishOptions options = PublishOptions.builder()

    .messageId("ord_8w2k-created")

    .build();



// First publish stores the message

PublishAck first = js.publish("orders.created", body, options);

System.out.printf("First:  seq=%d duplicate=%b%n", first.getSeqno(), first.isDuplicate());



// Re-publishing the same id returns the original sequence, marked duplicate

PublishAck second = js.publish("orders.created", body, options);

System.out.printf("Second: seq=%d duplicate=%b%n", second.getSeqno(), second.isDuplicate());
```

#### Rust

```
// Publish the same order twice, tagging both with the same message id.

// The server stores the first and detects the second as a duplicate.

let first = js

    .send_publish(

        "orders.created",

        PublishMessage::build()

            .payload(payload.into())

            .message_id("ord_8w2k-created"),

    )

    .await?

    .await?;

println!(

    "First:  sequence {}, duplicate {}",

    first.sequence, first.duplicate

);



let second = js

    .send_publish(

        "orders.created",

        PublishMessage::build()

            .payload(payload.into())

            .message_id("ord_8w2k-created"),

    )

    .await?

    .await?;

println!(

    "Second: sequence {}, duplicate {}",

    second.sequence, second.duplicate

);
```

#### C#/.NET

```
var order = new Order(OrderId: "ord_8w2k", Customer: "acme-co", TotalCents: 4200, Timestamp: DateTimeOffset.Parse("2026-05-22T10:14:22Z", CultureInfo.InvariantCulture));



// Tag the message with a unique id. The stream uses it to detect duplicates.

var opts = new NatsJSPubOpts { MsgId = "ord_8w2k-created" };



// First publish: the stream stores the message

var ack1 = await js.PublishAsync<Order>(subject: "orders.created", data: order, opts: opts);

output.WriteLine($"First:  seq={ack1.Seq} duplicate={ack1.Duplicate}");



// Republish with the same id: the stream recognizes it and stores nothing new

var ack2 = await js.PublishAsync<Order>(subject: "orders.created", data: order, opts: opts);

output.WriteLine($"Second: seq={ack2.Seq} duplicate={ack2.Duplicate}");
```

#### C

```
// Publish the same message twice with a message ID. The stream uses

// the ID to detect duplicates within its dedupe window.

jsPubAck        *first   = NULL;

jsPubAck        *second  = NULL;

jsPubOptions    po;

const char      *payload = "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\",\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}";



jsPubOptions_Init(&po);

po.MsgId = "ord_8w2k-created";



s = js_Publish(&first, js, "orders.created",

               payload, (int) strlen(payload),

               &po, &jerr);

if (s == NATS_OK)

{

    printf("First:  sequence %" PRIu64 ", duplicate %s\n",

           first->Sequence, first->Duplicate ? "true" : "false");

    jsPubAck_Destroy(first);



    // Re-publish with the same ID. The server recognizes it and

    // reports the original sequence instead of storing the message

    // again.

    s = js_Publish(&second, js, "orders.created",

                   payload, (int) strlen(payload),

                   &po, &jerr);

}

if (s == NATS_OK)

{

    printf("Second: sequence %" PRIu64 ", duplicate %s\n",

           second->Sequence, second->Duplicate ? "true" : "false");

    jsPubAck_Destroy(second);

}
```

Give every publish you might retry a stable `Nats-Msg-Id` that the producer can recompute, such as an order ID, a request ID, or a hash of the payload. The full set of publish headers is in [Reference → JetStream Headers](/reference/jetstream/api/headers.md). The tracking window is a stream setting, not a header: it's the `Duplicate Window` covered on the [stream page](/learn/jetstream/your-first-stream.md). This page uses only `Nats-Msg-Id`.

## What we've skipped

A few things this page leaves out. The other publishing modes get their own page later in the chapter; the rest is in Reference:

* **Async publish** — fire many publishes and collect the `PubAcks` later, for higher throughput. See [Advanced publishing](/learn/jetstream/advanced-publishing.md).
* **Atomic batch publish** — store a group of messages all-or-nothing (server 2.12+). See [Advanced publishing](/learn/jetstream/advanced-publishing.md).
* **Fast-ingest batch publish** — flow-controlled, high-throughput ingest without atomicity (server 2.14+). See [Advanced publishing](/learn/jetstream/advanced-publishing.md).
* **Expected-stream and expected-sequence headers** — fail a publish unless the stream is in a specific state, for optimistic concurrency. See [Reference → JetStream Headers](/reference/jetstream/api/headers.md).

## Pitfalls

Three mistakes are common on a first publish into a stream. Each follows from something above.

**Ignoring the `PubAck`.** A publish returns a `PubAck`, and code that discards it can't tell a stored message from a lost one. This is easy to miss on the CLI: a plain `nats pub` is a core publish, so it prints `Published N bytes` whether or not a stream captured the subject. That line doesn't prove the message was stored. Read the `PubAck` instead: in code, check the return value; on the CLI, publish with `nats pub --jetstream`, which reports the stream and sequence number.

#### CLI

```
#!/bin/bash

# Plain `nats pub` is a core NATS publish: it reports "Published" whether

# or not a stream stored the message. Publish to a subject nothing

# captures and it still looks fine:

nats pub invoices.created "test"

# 17:31:21 Published 4 bytes to "invoices.created"



# The same publish with --jetstream reads the PubAck -- and now the miss

# is visible, because no stream captured the subject:

nats pub --jetstream invoices.created "test"

# 17:31:21 Published 4 bytes to "invoices.created"

# nats: error: nats: no responders available for request



# On a captured subject, the PubAck confirms the write with the stream

# name and the assigned sequence:

nats pub --jetstream orders.created \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

# 17:31:21 Published 91 bytes to "orders.created"

# 17:31:21 Stored in Stream: ORDERS Sequence: 4
```

#### JavaScript/TypeScript

```
// `publish` resolves only once the server has persisted the message. Awaiting

// the PubAck and reading its stream and sequence confirms the order is stored

const data =

  `{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}`;

const pa = await js.publish("orders.created", data);

console.log(`Stored in ${pa.stream} at sequence ${pa.seq}`);
```

#### Go

```
// Publish one order and confirm it was stored. A failed publish returns an

// error rather than losing the message silently, so check err first.

ack, err := js.Publish(ctx, "orders.created", []byte(payload))

if err != nil {

	panic(err)

}



// The returned PubAck is proof the message is on disk in the stream.

fmt.Printf("Stored in %s at sequence %d\n", ack.Stream, ack.Sequence)
```

#### Python

```
# Publish one order. The publish only resolves once the server has stored

# the message, so reading the acknowledgement confirms it is durable.

ack = await js.publish(

    "orders.created",

    b'{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}',

)



# The stream name and sequence number prove the message is stored.

print(f"Confirmed stored in {ack.stream} at sequence {ack.seq}")
```

#### Java

```
// Publish one order; the returned ack confirms it was stored

PublishAck ack = js.publish("orders.created",

    "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\",\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}".getBytes(StandardCharsets.UTF_8));



// A non-null ack means the server persisted the message

System.out.printf("Confirmed stored in %s at sequence %d%n", ack.getStream(), ack.getSeqno());
```

#### Rust

```
// Publish, then await the ack. The `?` turns a failed store into an error

// instead of letting the program continue as if the message was saved.

let ack = js.publish("orders.created", payload.into()).await?.await?;



// Reaching this line means the server persisted the message.

println!(

    "Confirmed stored in {} at sequence {}",

    ack.stream, ack.sequence

);
```

#### C#/.NET

```
// Publish an order and read the ack

var ack = await js.PublishAsync<Order>(

    subject: "orders.created",

    data: new Order(OrderId: "ord_8w2k", Customer: "acme-co", TotalCents: 4200, Timestamp: DateTimeOffset.Parse("2026-05-22T10:14:22Z", CultureInfo.InvariantCulture)));



// Throw if the stream rejected the message; otherwise the ack confirms storage

ack.EnsureSuccess();



output.WriteLine($"Confirmed: stored in {ack.Stream} at sequence {ack.Seq}");
```

#### C

```
// Publish one order and confirm it was stored. A failed publish

// returns an error status rather than losing the message silently,

// so check s first.

jsPubAck    *ack     = NULL;

const char  *payload = "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\",\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}";



s = js_Publish(&ack, js, "orders.created",

               payload, (int) strlen(payload),

               NULL, &jerr);

if (s == NATS_OK)

{

    // The returned ack is proof the message is on disk in the stream.

    printf("Stored in %s at sequence %" PRIu64 "\n", ack->Stream, ack->Sequence);

    jsPubAck_Destroy(ack);

}
```

The plain publish reports `Published` even on a subject no stream captures. The `--jetstream` version surfaces the miss as a "no responders" error, and confirms a real write with `Stored in Stream … Sequence …`.

**Retrying without a `Nats-Msg-Id`.** A publisher that retries after a timeout (which any well-built publisher does) can store the message twice: the timed-out publish may have been stored with only its ack lost, and the retry adds a second copy unless it carries the same `Nats-Msg-Id`. The duplicate-tracking window is two minutes by default, so a retry that arrives after that also stores a second copy. Don't retry a bare publish. Give every retryable publish a stable `Nats-Msg-Id`, as shown in [Avoiding duplicate writes](#avoiding-duplicate-writes) above.

**Treating "published" as "delivered".** A `PubAck` means the stream stored the message, not that a consumer processed it. Code that marks an order shipped as soon as the `PubAck` returns is acting on a write that no shipping logic has seen. Keep business outcomes separate from the publish. The delivery-and-ack half of the story is on the [next page](/learn/jetstream/reading-back.md) and in [delivery and acknowledgment](/learn/jetstream/delivery-and-acknowledgment.md).

## Where you are

The `ORDERS` stream now holds three messages, each confirmed by a `PubAck`, and a repeated publish no longer stores a second copy.

No consumer has read these messages yet. The next page, [Reading back the stream](/learn/jetstream/reading-back.md), reads them back.

## See also

* [Reference → JetStream Headers](/reference/jetstream/api/headers.md) — every publish-side header, including dedup, expected state, and batch.
* [Reference → Publish Acknowledgement](/reference/jetstream/api/stream/pub-ack.md) — the exact fields returned by a publish.
