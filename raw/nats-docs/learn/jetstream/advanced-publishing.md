<!-- source: https://docs.nats.io/learn/jetstream/advanced-publishing.md · fetched 2026-08-31 · section: advanced-publishing -->
# Advanced publishing

[Publishing](/learn/jetstream/publishing.md) sent one order at a time and waited for each `PubAck`. That's the right default, and most services never need anything else. Two things change that: publishing at high volume, where waiting for each ack in turn is too slow, and writing a group of orders that only make sense together. JetStream has three publish modes for those cases.

This page covers each one — what it does, when to reach for it, and what it costs. The `ORDERS` stream you've used all chapter doesn't change; these are choices the publisher makes.

## Async publish

A normal publish blocks until the `PubAck` comes back, so a service that sends a thousand orders pays a thousand round trips end to end. An **async publish** doesn't wait: you fire each publish and keep going, then collect the acks afterward. The round trips overlap, so the same thousand orders take a fraction of the wall-clock time.

The contract is unchanged — one `PubAck` per message, at-least-once storage — so you still have to check every ack. What's new is when you check it: later, in a batch, instead of right after each call.

### The order trap

Async publish has one failure mode a synchronous publish doesn't, and it's the reason to understand the mode before using it.

The server numbers messages in the order they arrive and get stored. When you fire orders 1 through 6 async, they're stored at sequences 1 through 6. Now say order 3's ack fails — a timeout, a dropped connection — while 4, 5, and 6 succeeded.

The reorder is an after-effect of the retry. A failed publish doesn't land, so order 3 is simply missing — and you send it again, automatically or by hand. By then 4, 5, and 6 are already stored, so the re-sent order takes a higher sequence and ends up *after* the orders you sent next.

**Message flow — A late async retry lands out of order (animated):** Async publishing doesn't wait for each PubAck before sending the next order, so publishes can finish out of order. The server numbers five orders as they land, but order 3's ack fails. Nothing is resent on its own — order 3 is simply missing until your code re-publishes it. By the time the retry runs, orders 4, 5, and 6 are already stored, so the re-published order 3 lands last, at sequence 7. An async publish you never check is a lost write, and a late retry reorders the stream.

There are two fixes, for two different problems:

* **If the ack was lost but the message was actually stored**, re-publishing stores a second copy. Give each publish a stable `Nats-Msg-Id` (the same header from [Avoiding duplicate writes](/learn/jetstream/publishing.md#avoiding-duplicate-writes)), and the server drops the repeat instead of storing it twice.
* **If the order itself matters**, set `Nats-Expected-Last-Subject-Sequence` on each publish. The server stores the message only when the subject's last sequence is the one you expect, and rejects it otherwise. An out-of-order retry then fails fast — you handle the rejection — instead of silently landing in the wrong place.

One rule covers the rest: **an async publish you never check is a lost write.** Firing publishes without reading the acks gives up the only guarantee a JetStream publish offers. Collect every ack and confirm it.

Async publish is a client-library feature — there's no stream setting to turn it on — and the API differs by language. Each one below fires several orders without awaiting each ack, then collects and checks them all afterward:

#### JavaScript/TypeScript

```
// Async publish: call publish() for every order WITHOUT awaiting each one, so

// the round trips overlap. Collect the promises, await them together, then

// check each result -- a rejected promise is a failed publish you must retry.

const orders = [

  `{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200}`,

  `{"order_id":"ord_2zr9","customer":"globex","total_cents":7800}`,

  `{"order_id":"ord_5t1m","customer":"initech","total_cents":1500}`,

  `{"order_id":"ord_9p3x","customer":"hooli","total_cents":9900}`,

];



const pending = orders.map((order) => js.publish("orders.created", order));

const results = await Promise.allSettled(pending);



results.forEach((result, i) => {

  if (result.status === "fulfilled") {

    console.log(`order ${i + 1} stored at sequence ${result.value.seq}`);

  } else {

    console.log(`order ${i + 1} failed, re-publish it: ${result.reason}`);

  }

});
```

#### Go

```
// Async publish: fire every order without waiting for its PubAck, then

// collect the futures and check each one. The round trips overlap, so this

// is far faster than publishing one at a time -- but you still have to

// confirm every ack, because a publish whose ack never arrives is a lost

// order, not a stored one.

orders := []string{

	`{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200}`,

	`{"order_id":"ord_2zr9","customer":"globex","total_cents":7800}`,

	`{"order_id":"ord_5t1m","customer":"initech","total_cents":1500}`,

	`{"order_id":"ord_9p3x","customer":"hooli","total_cents":9900}`,

}



// PublishAsync returns immediately, before the server replies.

futures := make([]jetstream.PubAckFuture, 0, len(orders))

for _, order := range orders {

	f, err := js.PublishAsync("orders.created", []byte(order))

	if err != nil {

		panic(err)

	}

	futures = append(futures, f)

}



// Wait until every publish has been answered, or give up after a timeout.

select {

case <-js.PublishAsyncComplete():

case <-time.After(5 * time.Second):

	panic(fmt.Sprintf("timed out with %d publishes unconfirmed", js.PublishAsyncPending()))

}



// Check each ack. A publish whose ack failed has to be re-published.

for i, f := range futures {

	select {

	case ack := <-f.Ok():

		fmt.Printf("order %d stored at sequence %d\n", i+1, ack.Sequence)

	case err := <-f.Err():

		fmt.Printf("order %d failed, re-publish it: %v\n", i+1, err)

	}

}
```

#### Python

```
# nats.py has no dedicated async-publish API: publish() already returns a

# coroutine, so the async-publish pattern is to start them all and gather

# the results instead of awaiting one at a time. The round trips overlap,

# but the client does not bound how many are in flight -- check every ack,

# and add your own limit for large bursts.

orders = [

    b'{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200}',

    b'{"order_id":"ord_2zr9","customer":"globex","total_cents":7800}',

    b'{"order_id":"ord_5t1m","customer":"initech","total_cents":1500}',

    b'{"order_id":"ord_9p3x","customer":"hooli","total_cents":9900}',

]



pending = [js.publish("orders.created", order) for order in orders]

results = await asyncio.gather(*pending, return_exceptions=True)



for i, result in enumerate(results, start=1):

    if isinstance(result, Exception):

        print(f"order {i} failed, re-publish it: {result}")

    else:

        print(f"order {i} stored at sequence {result.seq}")
```

#### Java

```
// Async publish: publishAsync returns a CompletableFuture immediately,

// before the server replies, so the round trips overlap. Collect the

// futures, then read each ack -- a future that completes exceptionally

// is a failed publish you must re-send.

String[] orders = {

    "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\",\"total_cents\":4200}",

    "{\"order_id\":\"ord_2zr9\",\"customer\":\"globex\",\"total_cents\":7800}",

    "{\"order_id\":\"ord_5t1m\",\"customer\":\"initech\",\"total_cents\":1500}",

    "{\"order_id\":\"ord_9p3x\",\"customer\":\"hooli\",\"total_cents\":9900}"

};



List<CompletableFuture<PublishAck>> futures = new ArrayList<>();

for (String order : orders) {

    futures.add(js.publishAsync("orders.created",

        order.getBytes(StandardCharsets.UTF_8)));

}



for (int i = 0; i < futures.size(); i++) {

    try {

        PublishAck ack = futures.get(i).get();

        System.out.printf("order %d stored at sequence %d%n", i + 1, ack.getSeqno());

    } catch (Exception e) {

        System.out.printf("order %d failed, re-publish it: %s%n", i + 1, e.getMessage());

    }

}
```

#### Rust

```
// Async publish: the first await only sends the message and returns a

// PublishAckFuture. Collect the futures without awaiting them, so the round

// trips overlap. Then await each future to read its ack -- a future that

// resolves to an error is a failed publish you must re-publish.

let orders = [

    r#"{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200}"#,

    r#"{"order_id":"ord_2zr9","customer":"globex","total_cents":7800}"#,

    r#"{"order_id":"ord_5t1m","customer":"initech","total_cents":1500}"#,

    r#"{"order_id":"ord_9p3x","customer":"hooli","total_cents":9900}"#,

];



let mut acks = Vec::with_capacity(orders.len());

for order in orders {

    let future = js.publish("orders.created", order.into()).await?;

    acks.push(future);

}



// Now await each future to confirm the order was stored.

for (i, future) in acks.into_iter().enumerate() {

    match future.await {

        Ok(ack) => println!("order {} stored at sequence {}", i + 1, ack.sequence),

        Err(err) => println!("order {} failed, re-publish it: {}", i + 1, err),

    }

}
```

#### C#/.NET

```
// Async publish: PublishConcurrentAsync sends the message and returns a

// future without waiting for the ack, so the round trips overlap. Collect

// the futures, then await each one and call EnsureSuccess -- a future whose

// ack reports an error is a failed publish you must re-send.

Order[] orders =

[

    new Order(OrderId: "ord_8w2k", Customer: "acme-co", TotalCents: 4200),

    new Order(OrderId: "ord_2zr9", Customer: "globex", TotalCents: 7800),

    new Order(OrderId: "ord_5t1m", Customer: "initech", TotalCents: 1500),

    new Order(OrderId: "ord_9p3x", Customer: "hooli", TotalCents: 9900),

];



var futures = new List<NatsJSPublishConcurrentFuture>();

foreach (var order in orders)

{

    futures.Add(await js.PublishConcurrentAsync<Order>("orders.created", order));

}



for (var i = 0; i < futures.Count; i++)

{

    await using var future = futures[i];

    var ack = await future.GetResponseAsync();

    ack.EnsureSuccess();

    output.WriteLine($"order {i + 1} stored at sequence {ack.Seq}");

}
```

#### C

```
// Async publish: fire every order without waiting for its PubAck,

// then wait for all acks at once. The round trips overlap, so this

// is far faster than publishing one at a time -- but you still have

// to confirm every ack, because a publish whose ack never arrives

// is a lost order, not a stored one.

const char *orders[] = {

    "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\",\"total_cents\":4200}",

    "{\"order_id\":\"ord_2zr9\",\"customer\":\"globex\",\"total_cents\":7800}",

    "{\"order_id\":\"ord_5t1m\",\"customer\":\"initech\",\"total_cents\":1500}",

    "{\"order_id\":\"ord_9p3x\",\"customer\":\"hooli\",\"total_cents\":9900}"};

int         i;

jsPubOptions wait;



// js_PublishAsync returns immediately, before the server replies.

// A failed ack is reported to the ErrHandler registered on the

// JetStream context (see asyncPubErr above).

for (i = 0; (s == NATS_OK) && (i < 4); i++)

    s = js_PublishAsync(js, "orders.created", orders[i],

                        (int) strlen(orders[i]), NULL);



// Wait until every publish has been answered, or give up after

// a timeout.

jsPubOptions_Init(&wait);

wait.MaxWait = 5000;

if (s == NATS_OK)

    s = js_PublishAsyncComplete(js, &wait);

if (s == NATS_TIMEOUT)

{

    // Publishes still unconfirmed after the wait are lost writes:

    // take them back and re-publish or report each one.

    natsMsgList pending = {NULL, 0};



    if (js_PublishAsyncGetPendingList(&pending, js) == NATS_OK)

        printf("timed out with %d publishes unconfirmed\n", pending.Count);

    natsMsgList_Destroy(&pending);

}

else if (s == NATS_OK)

    printf("all 4 orders stored\n");
```

A note per language: Go, Java, .NET, and Rust have a dedicated async-publish call that hands back a future you collect; nats.js does it by not awaiting each `publish()` and gathering the promises; nats.py has no first-class async publish, so the example approximates it with `asyncio.gather` and you add your own limit on how many run at once. On the CLI, the everyday `nats pub` is synchronous; the async path lives in the benchmark, `nats bench js pub async orders.created --batch 1000`.

## Atomic batch publish

An **atomic batch** stores a group of messages all-or-nothing. Either the whole batch commits, or none of it does. Use it when several messages only make sense together — the line items of one order, where a half-written order would leave the data inconsistent.

**Message flow — An atomic batch commits all-or-nothing (animated):** An atomic batch commits all of its messages together or none at all. You open a batch and the server stages each message — nothing is visible in ORDERS yet. Add the second and third and all three sit in the staging buffer, still uncommitted. On commit, the whole batch lands in ORDERS at once, at sequences 1, 2, and 3, visible together and never half-written. If the batch is abandoned, every staged message is discarded and ORDERS is unchanged.

The stream opts in with `AllowAtomicPublish`. The client opens a batch with a `Nats-Batch-Id`, tags each message with an increasing `Nats-Batch-Sequence`, and marks the last one with `Nats-Batch-Commit`. The server holds the messages in a staging buffer and writes them as a unit only on commit. The committing `PubAck` carries two extra fields, `batch` and `count`, so you can confirm the whole group landed.

A batch is bounded, and it can be abandoned. By default it's capped at 1,000 messages and a stream allows at most 50 batches in flight — both are operator-configurable server limits, not fixed protocol caps. A sequence gap or an over-limit batch is rejected with an error `PubAck`, so the publisher hears about it. A batch that goes ten seconds without a message is dropped with no error reply — the server raises a `stream_batch_abandoned` advisory instead of committing a partial group. Treat the final `PubAck` as the only proof the batch committed. Atomic batch was added in server 2.12.

Opt the stream in with `AllowAtomicPublish`, then open a batch, stage messages, and commit them as a unit. The CLI and nats.js have this in the core client; Go, Java, Rust, and .NET reach it through the [Synadia Orbit](https://github.com/synadia-io) companion libraries; nats.py drives it with the `Nats-Batch-*` headers directly. Each example commits three line items of one order:

#### CLI

```
#!/bin/bash

# Atomic batch publish from the CLI. The stream must be created with

# --allow-batch (AllowAtomicPublish). The --atomic flag reads one message per

# line from STDIN and commits the whole batch at end of input: either all three

# line items land together, or none of them do.

printf '%s\n' \

  '{"order_id":"ord_8w2k","line":"sku-1"}' \

  '{"order_id":"ord_8w2k","line":"sku-2"}' \

  '{"order_id":"ord_8w2k","line":"sku-3"}' \

  | nats pub --atomic --send-on=newline --force-stdin orders.created



# Prints e.g. `Wrote batch ID: heTjQHWT0emRc98Os9nUtx Messages: 3 Sequence: 3`.

# The batch is committed as a unit; a sequence gap or a stall abandons it whole.
```

#### JavaScript/TypeScript

```
// Atomic batch: all three line items of order ord_8w2k reach the stream

// together, or none of them do. startBatch() opens the batch with the first

// item, add() stages the next without its own round trip, and commit()

// publishes the last item and seals the batch. The server stores every staged

// message at once and answers with a single ack for the whole batch.

const batch = await js.startBatch("orders.created", lineItems[0]);

batch.add("orders.created", lineItems[1]);

const ack = await batch.commit("orders.created", lineItems[2]);

console.log(`batch ${ack.batch} stored ${ack.count} line items`);
```

#### Go

```
// Publish the three line items of order ORD-42 as one atomic batch:

// all three land in the ORDERS stream, or none do.

batch, err := jetstreamext.NewBatchPublisher(js)

if err != nil {

	log.Fatalf("create batch publisher: %v", err)

}

if err := batch.Add("orders.created", []byte(`{"order":"ORD-42","sku":"COFFEE-1KG","qty":2}`)); err != nil {

	log.Fatalf("add line item: %v", err)

}

if err := batch.Add("orders.created", []byte(`{"order":"ORD-42","sku":"FILTER-100","qty":1}`)); err != nil {

	log.Fatalf("add line item: %v", err)

}

// Commit sends the final line item and atomically commits the batch.

ack, err := batch.Commit(ctx, "orders.created", []byte(`{"order":"ORD-42","sku":"MUG-WHITE","qty":4}`))

if err != nil {

	log.Fatalf("commit batch: %v", err)

}

log.Printf("batch %q committed: %d line items stored", ack.BatchID, ack.BatchSize)
```

#### Python

```
# Atomic batch (ADR-50): tag each line item with one batch id and a rising

# sequence, then mark the last one committed. The server stores all three or

# none, and sends a single ack -- on the commit -- for the whole batch.

batch = "ord_8w2k-batch"

await js.client.request(

    "orders.created", b'{"sku":"TEE"}', headers={NATS_BATCH_ID: batch, NATS_BATCH_SEQUENCE: "1"}

)

await js.client.publish(

    "orders.created", b'{"sku":"MUG"}', headers={NATS_BATCH_ID: batch, NATS_BATCH_SEQUENCE: "2"}

)

ack = await js.publish(

    "orders.created",

    b'{"sku":"CAP"}',

    headers={NATS_BATCH_ID: batch, NATS_BATCH_SEQUENCE: "3", NATS_BATCH_COMMIT: NATS_BATCH_COMMIT_FINAL},

)

print(f"committed batch {ack.batch_id}: {ack.batch_size} messages stored")
```

#### Java

```
// One order, three line items, stored as a single atomic batch:

// either all three messages land in the stream, or none do.

BatchPublisher publisher = BatchPublisher.builder()

    .connection(nc)

    .batchId(BATCH_ID)

    .build();



publisher.add(SUBJECT, "{\"sku\":\"NATS-TEE\",\"qty\":2}".getBytes());

publisher.add(SUBJECT, "{\"sku\":\"NATS-MUG\",\"qty\":1}".getBytes());

PublishAck ack = publisher.commit(SUBJECT, "{\"sku\":\"NATS-CAP\",\"qty\":1}".getBytes());



System.out.println("Committed batch [" + publisher.getBatchId() + "]"

    + " of " + ack.getBatchSize() + " line items"

    + " at stream sequence " + ack.getSeqno() + ".");
```

#### Rust

```
// Open a batch, add the first two line items, then commit with the third.

// Every message carries the same batch id; the order is stored only if the

// commit succeeds.

let mut batch = js.batch_publish().build();

batch

    .add("orders.created", r#"{"sku":"NATS-TEE","qty":2}"#.into())

    .await?;

batch

    .add("orders.created", r#"{"sku":"NATS-MUG","qty":1}"#.into())

    .await?;

let ack = batch

    .commit("orders.created", r#"{"sku":"NATS-CAP","qty":3}"#.into())

    .await?;



println!(

    "batch {} committed {} line items",

    ack.batch_id, ack.batch_size

);
```

#### C#/.NET

```
await using var batch = new NatsJSBatchPublisher(js);



// Three line items of one order. They all land, or none do.

await batch.AddAsync("orders.created", "{\"sku\":\"COFFEE-1KG\",\"qty\":2}");

await batch.AddAsync("orders.created", "{\"sku\":\"FILTER-100\",\"qty\":1}");



// The final item commits the batch and returns one ack for the whole order.

NatsJSBatchAck ack = await batch.CommitAsync("orders.created", "{\"sku\":\"MUG-350ML\",\"qty\":4}");



Console.WriteLine($"Committed batch {ack.BatchId}: {ack.BatchSize} messages into {ack.Stream}");
```

#### C

```
// Publish the three line items of order ORD-42 as one atomic batch:

// all three land in the ORDERS stream, or none do.

jsPubAck *ack = NULL;



// Start the batch with the first line item.

s = js_BatchPublishStart(&batch, NULL, js, msg1, NULL, &jerr);



// Add the second line item to the batch.

if (s == NATS_OK)

    s = js_BatchPublishAdd(NULL, batch, msg2, NULL, &jerr);



// Commit sends the final line item and atomically commits the

// batch. The ack carries the batch ID and how many messages the

// batch stored.

if (s == NATS_OK)

    s = js_BatchPublishCommit(&ack, batch, msg3, NULL, &jerr);

if (s == NATS_OK)

{

    printf("batch \"%s\" committed: %" PRIu64 " line items stored\n",

           ack->Batch, ack->Count);

    jsPubAck_Destroy(ack);

}

jsAtomicBatchCtx_Destroy(batch);
```

The wire protocol is the same underneath — the `Nats-Batch-Id`, `Nats-Batch-Sequence`, and `Nats-Batch-Commit` headers — so a client without an Orbit helper can drive a batch with raw headers, as the Python tab shows. See [ADR-50](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-50.md) for the full header set and limits.

## Fast-ingest batch publish

A **fast-ingest batch** moves data into a stream at high speed with the server setting the pace. It's built to replace async publish: instead of the client guessing how fast to push and paying to track every ack, the client opens one channel and the server runs flow control over it. The server acks in batches and tells each publisher how fast it may go — ramping up while it keeps up, slowing down under load — so many concurrent fast publishers stay balanced.

**Message flow — Fast ingest widens its ack window (animated):** Fast ingest raises publish throughput by acking batches of messages instead of every one. The server starts slow, acking each message while it gauges the load, then widens its window so one ack covers two messages, then four — fewer acks, higher throughput. The trade-off shows when a message is dropped in flight: it is never acked, so it leaves a gap the client has to notice for itself.

It trades away atomicity, and that trade is the choice you make per batch. A batch can run unbounded, and a dropped message means one of two things:

* **`gap: fail`** abandons the batch on the first gap, so what's stored is in order with no holes. Use it for ordered data, like the chunks of an object.
* **`gap: ok`** reports the gap and keeps going. Use it where a hole is acceptable, like a stream of metrics.

The stream opts in with `AllowBatchPublish`. Fast-ingest was added in server 2.14, and client support is still landing:

| Client             | Fast-ingest publish                                            |
| ------------------ | -------------------------------------------------------------- |
| CLI                | `nats bench js pub fast` (benchmark only)                      |
| Go                 | Synadia Orbit — `jetstreamext.NewFastPublisher`                |
| Rust               | Synadia Orbit — `jetstream_extra`'s `fast_publish`             |
| nats.js            | Synadia Orbit — `@synadiaorbit/fastingest` (`startFastIngest`) |
| Python, Java, .NET | `AllowBatchPublish` stream flag; Orbit publishers catching up  |

Because there's no stable public publisher in most clients, this page doesn't show per-language code for it. When you need fast ingest today, the practical paths are the Orbit libraries for Go, Rust, and JavaScript; the rest will follow. The flow-control protocol is in [ADR-50](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-50.md).

## Choosing a mode

Most services should publish one at a time and check each `PubAck`. Reach past that only when one of these is true:

| Mode          | Reach for it when                                                        | All-or-nothing | Opt-in               |
| ------------- | ------------------------------------------------------------------------ | -------------- | -------------------- |
| One at a time | The default — simple, ordered, safe to retry                             | n/a            | none                 |
| Async         | You publish at volume and one-at-a-time is too slow                      | no             | none                 |
| Atomic batch  | A group of messages must land together or not at all                     | yes            | `AllowAtomicPublish` |
| Fast-ingest   | You need maximum sustained throughput and can tolerate (or fail on) gaps | no             | `AllowBatchPublish`  |

## Pitfalls

A few things separate these modes from a plain publish.

**An async publish you never check is a lost write.** Firing publishes without reading the `PubAcks` gives up the one guarantee a JetStream publish offers. Collect and check every ack — and if order matters, add `Nats-Expected-Last-Subject-Sequence` so a retry fails fast instead of landing out of order.

**An atomic batch can be abandoned.** A sequence gap or a batch over the size limit (1,000 messages by default) comes back as an error `PubAck`. A batch that goes ten seconds without a message is dropped with no error reply — only an advisory. Either way the whole batch is dropped, so treat the final `PubAck` as the only proof it committed; don't assume a half-sent batch landed.

**`AllowAtomicPublish` and async persistence don't mix.** A stream set to persist asynchronously (`PersistMode: async`) rejects atomic publishing, because the atomicity depends on the synchronous write path. Fast-ingest batches are fine on such a stream.

**Fast-ingest gaps lose data in `gap: ok` mode.** That mode keeps going past a dropped message on purpose. Use it only when a hole is acceptable, like metrics; for anything you can't lose, use `gap: fail` or an atomic batch.

## Where you are

Nothing about `ORDERS` changed on this page. You now have the three publish modes beyond one-at-a-time, and the code for the one most services actually reach for:

* **Async** overlaps round trips for throughput. You collect and check every `PubAck` yourself, and watch the order trap on retries.
* **Atomic batch** commits a group all-or-nothing, gated by `AllowAtomicPublish`.
* **Fast-ingest batch** trades atomicity for server-paced speed, gated by `AllowBatchPublish`.

The default one-at-a-time publish from the [publishing page](/learn/jetstream/publishing.md) still fits most services.

## What's next

The next page covers copying a stream's data elsewhere: **mirrors and sources**, the building blocks for read-replicas, aggregation, and disaster recovery across regions.

## See also

* [ADR-50: JetStream Batch Publishing](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-50.md) — the full atomic and fast-ingest protocols, headers, and limits.
* [Reference → Create Stream](/reference/jetstream/api/stream/create.md) — the `allow_atomic` and `allow_batched` stream settings.
* [Reference → JetStream Headers](/reference/jetstream/api/headers.md) — `Nats-Expected-Last-Subject-Sequence` and the batch headers.
* [Reference → Publish Acknowledgement](/reference/jetstream/api/stream/pub-ack.md) — the `batch` and `count` fields a batch `PubAck` carries.
