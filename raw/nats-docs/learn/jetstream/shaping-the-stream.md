<!-- source: https://docs.nats.io/learn/jetstream/shaping-the-stream.md · fetched 2026-08-31 · section: shaping-the-stream -->
# Shaping the stream

The `ORDERS` stream you created back on the [Your first stream](/learn/jetstream/your-first-stream.md) page has no limits. It keeps every message forever, on however much disk the server has. That was fine for learning, but not for production.

Without a limit, the stream keeps growing until it fills the disk and takes the server down with it.

This page covers two settings. The **limit** is the cap that decides when the stream is full. The **Discard policy** decides which message the server discards when the stream hits that limit: the new one or the oldest stored one.

## The limit

A stream under the default **Limits** retention policy keeps messages until a limit forces it to discard them. You saw that policy in the config printout on the [Your first stream](/learn/jetstream/your-first-stream.md) page. A limit is a ceiling on the stream. You set it with one of three options, depending on how you want to measure the stream:

* **MaxAge** caps how old a message may get. Set it to seven days and a message is discarded roughly seven days after it was stored. It fits when only recent events matter — a live order stream rarely needs one from last quarter.
* **MaxBytes** caps how much disk the stream may use. Set it to one gigabyte and the stream never grows past a gigabyte, no matter how old or new the messages are. This option protects the server itself.
* **MaxMsgs** caps how many messages the stream may hold. Set it to one million and the millionth-and-first message forces a discard. Use this when message count, rather than size or age, is what you reason about.

The three options work separately, and all of them are active at once. Whichever one is reached first triggers a discard. You don't have to set all three. Set the ones that match how you think about the stream, and leave the rest unlimited.

MaxAge evicts by the clock; MaxMsgs evicts by the count. Same discard, two different triggers:

**Message flow — MaxAge expires messages by age (animated):** MaxAge expires messages once they pass an age limit, no matter how full the stream is. Orders arrive a couple a day against a 7-day window; each order lives until it reaches 7 days old, then the server discards it, while everything still inside the window stays. The stream holds a rolling seven days of orders rather than a fixed count.

**Message flow — MaxMsgs keeps a fixed message count (animated):** MaxMsgs caps how many messages a stream keeps. The stream is full at MaxMsgs=5, so each new order discards the oldest to fit; the count stays at five and the stream holds only the most recent orders.

## Cap the ORDERS stream

Give `ORDERS` a seven-day age limit and a one-gigabyte ceiling. The `nats stream edit` command changes an existing stream in place, so the messages already stored stay where they are.

#### CLI

```
#!/bin/bash

# Cap the ORDERS stream so it cannot grow without bound.

#

# `nats stream edit` changes an existing stream in place. The three

# messages already stored stay where they are; only the configuration

# changes. The command prints a diff of what will change and asks for

# confirmation before applying it.

#

# --max-age sets MaxAge: the oldest a message may get. 7d means a

#   message is removed roughly seven days after it was stored.

# --max-bytes sets MaxBytes: the most disk the stream may occupy on

#   disk. 1GiB caps it at one gibibyte (about a gigabyte); the stream

#   never grows past it. nats reports the cap back as "1.0 GiB".

#

# MaxMsgs is left unset, so message count stays unlimited. Discard

# policy is left at its default (Old), so when a limit is hit the

# server drops the oldest messages to make room.



nats stream edit ORDERS \

  --max-age=7d \

  --max-bytes=1GiB
```

#### JavaScript/TypeScript

```
// Cap ORDERS with a seven-day age limit and a 1 GiB byte ceiling. streams.update

// takes just the fields you're changing and leaves the rest, and the stored

// messages, in place. max_age is in nanoseconds.

const jsm = await jetstreamManager(nc);

await jsm.streams.update("ORDERS", {

  max_age: 7 * 24 * 60 * 60 * 1_000_000_000, // 7 days

  max_bytes: 1024 * 1024 * 1024, // 1 GiB

});

console.log("ORDERS capped at 7d age and 1 GiB");
```

#### Go

```
// Cap ORDERS so it can't grow without bound. Fetch the current config, add

// a seven-day age limit and a 1 GiB byte ceiling, and update the stream in

// place. Editing limits leaves the messages already stored alone.

s, err := js.Stream(ctx, "ORDERS")

if err != nil {

	panic(err)

}

cfg := s.CachedInfo().Config

cfg.MaxAge = 7 * 24 * time.Hour

cfg.MaxBytes = 1 << 30 // 1 GiB

if _, err := js.UpdateStream(ctx, cfg); err != nil {

	panic(err)

}

fmt.Println("ORDERS capped at 7d age and 1 GiB")
```

#### Python

```
# Cap ORDERS with a seven-day age limit and a 1 GiB byte ceiling. Fetch the

# current config, set the limits, and update the stream in place; the stored

# messages stay put. max_age is in seconds.

info = await js.stream_info("ORDERS")

config = info.config

config.max_age = 7 * 24 * 3600  # 7 days

config.max_bytes = 1024 * 1024 * 1024  # 1 GiB

await js.update_stream(config)

print("ORDERS capped at 7d age and 1 GiB")
```

#### Java

```
// Cap ORDERS with a seven-day age limit and a 1 GiB byte ceiling.

// Build from the current config so other fields, and the stored

// messages, are left in place, then update the stream.

StreamInfo si = jsm.getStreamInfo("ORDERS");

StreamConfiguration cfg = StreamConfiguration.builder(si.getConfiguration())

    .maxAge(Duration.ofDays(7))

    .maxBytes(1L << 30) // 1 GiB

    .build();

jsm.updateStream(cfg);

System.out.println("ORDERS capped at 7d age and 1 GiB");
```

#### Rust

```
// Cap ORDERS so it can't grow without bound. Fetch the current config, add

// a seven-day age limit and a 1 GiB byte ceiling, and update the stream in

// place. Editing limits leaves the messages already stored alone.

let mut stream = js.get_stream("ORDERS").await?;

let mut config = stream.info().await?.config.clone();

config.max_age = Duration::from_secs(7 * 24 * 3600);

config.max_bytes = 1 << 30; // 1 GiB

js.update_stream(config).await?;

println!("ORDERS capped at 7d age and 1 GiB");
```

#### C#/.NET

```
// Cap ORDERS with a seven-day age limit and a 1 GiB byte ceiling. Fetch

// the current config, set the limits, and update the stream in place;

// the stored messages stay put.

var stream = await js.GetStreamAsync("ORDERS");

var config = stream.Info.Config;

config.MaxAge = TimeSpan.FromDays(7);

config.MaxBytes = 1L << 30; // 1 GiB

await js.UpdateStreamAsync(config);

output.WriteLine("ORDERS capped at 7d age and 1 GiB");
```

#### C

```
// Cap ORDERS so it can't grow without bound. Fetch the current

// config, add a seven-day age limit and a 1 GiB byte ceiling, and

// update the stream in place. Editing limits leaves the messages

// already stored alone.

s = js_GetStreamInfo(&si, js, "ORDERS", NULL, &jerr);

if (s == NATS_OK)

{

    si->Config->MaxAge   = (int64_t) 7 * 24 * 60 * 60 * 1000000000LL; // 7 days in ns

    si->Config->MaxBytes = 1024 * 1024 * 1024;                        // 1 GiB

    s = js_UpdateStream(NULL, js, si->Config, NULL, &jerr);

}

if (s == NATS_OK)

    printf("ORDERS capped at 7d age and 1 GiB\n");
```

`nats stream edit` shows the change and asks for confirmation before applying it. Confirm, then read the stream back:

```
nats stream info ORDERS
```

The configuration block now reports the two limits instead of `unlimited`:

```
Options:



                    Retention: Limits

              Acknowledgments: true

               Discard Policy: Old

             Duplicate Window: 2m0s



Limits:



             Maximum Messages: unlimited

          Maximum Per Subject: unlimited

                Maximum Bytes: 1.0 GiB

                  Maximum Age: 7d0h0m0s

         Maximum Message Size: unlimited

            Maximum Consumers: unlimited
```

`Maximum Messages` is still `unlimited`, because you set only age and bytes. (`Maximum Message Size`, also in the block, is a different limit — a cap on a single message rather than the whole stream — and stays unlimited here.) The stream now has clear bounds: it can't grow past a gigabyte, and it can't hold anything older than a week.

## The Discard policy

The Discard policy controls what happens at the moment a new message would push the stream past a limit: the server discards the new message or the oldest stored one. It has two settings.

**Discard Old** is the default, and it's what you have right now. When a limit is hit, the server discards the *oldest* messages to make room for the new one. The publish always succeeds: the newest message is stored, the oldest is discarded.

**Message flow — Discard Old drops the oldest when full (animated):** With Discard Old (the default), a full stream makes room by dropping its oldest message. Orders flow toward a stream at its limit; each new order is stored while the oldest is discarded to fit, so the publish always succeeds and the stream holds a moving window of the most recent messages.

**Discard New** is the opposite. When a size or count limit is hit — `MaxMsgs`, `MaxBytes`, or a per-subject cap — the server discards the *new* message: it rejects the publish, which fails with an error, and nothing already stored is dropped to make room. `MaxAge` isn't a Discard-policy choice: it expires stored messages on its own timer under either policy. The rule from the top of the page still holds — **the first limit to hit applies.**

**Message flow — Discard New rejects writes when full (animated):** With Discard New, a full stream rejects new writes instead of dropping old ones. Orders flow toward a stream already at its message limit; each new order is rejected with maximum messages exceeded, and the messages already stored are left untouched. The publisher feels the limit as a failed publish rather than silent data loss.

For `ORDERS`, Discard Old is the right choice. A live order stream wants the most recent week of events. If disk pressure forces a trade-off, the order from eight days ago is the one to discard, not today's. Leave the default in place.

Use Discard New when discarding an old message would lose data you're required to keep, and you'd rather slow the publisher down than lose history. The publisher then has to handle the rejected publish, which is why it's the less common choice.

## Limits apply to the stream, not the consumer

A limit discards a message for everyone. When MaxAge discards a message, it's gone from the stream, and every consumer reading that stream loses access to it at once.

Limits and consumers are separate decisions. The `shipping` consumer's position and the `analytics` consumer's filter don't protect a message from the stream's limits. If a consumer is too slow and a message ages out before that consumer reads it, the message is gone. The next page returns to that risk, where the retention policy itself changes.

## Per-subject limits

A stream can also limit messages *per subject* rather than across the whole stream, which is useful when `orders.>` should keep, say, the last hundred messages for each individual subject. That's the `MaxMsgsPerSubject` option.

The full set of stream limit options is documented in [Reference → Stream Configuration](/reference/jetstream/api/stream/create.md). We use only MaxAge, MaxBytes, and Discard here.

## Pitfalls

Limits are easy to set and easy to misread. Two traps account for most of the surprises.

**Discard Old discards the oldest message silently.** Discard Old never fails a publish. When a size or count limit is hit, the server drops the oldest message and the publish succeeds — right for a rolling window, but the publisher gets no warning and the oldest order is gone. To keep history and push back on the publisher, switch to Discard New, which rejects the publish (`maximum bytes exceeded` or `maximum messages exceeded`) instead of dropping a stored message. Discard New still leaves `MaxAge` in force — **the first limit to hit applies** — so if you must keep history, remove or raise the age limit too:

#### CLI

```
#!/bin/bash

# Switch ORDERS from Discard Old to Discard New so a full stream pushes

# backpressure to the publisher instead of silently dropping old orders.

#

# Under Discard Old (the default) a publish that exceeds a limit always

# succeeds, because the server drops the oldest message to make room and

# tells the publisher nothing. If you need to keep history, that silent

# drop is data loss you never see.

#

# --discard new flips the trade: when a limit is hit, the server rejects

# the new message and the publish fails with "maximum bytes exceeded" (or

# "maximum messages exceeded"). The publisher now feels the limit.



# Force the full condition so you can see the rejection. Discard New never

# drops messages that are already stored, so switching ORDERS to it and

# capping it at one message leaves the orders from earlier pages in place and

# puts the stream instantly over its limit -- both in one edit.

nats stream edit ORDERS --discard new --max-msgs 1



# ORDERS is now full. Under Discard New this publish fails instead of

# succeeding silently, so the publisher can retry, alert, or shed load:

nats pub orders.created \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

# -> nats: maximum messages exceeded



# Put ORDERS back the way it was: Discard Old and no message-count cap. The

# 7-day age and 1 GiB byte limits set earlier stay in place.

nats stream edit ORDERS --discard old --max-msgs -1
```

#### JavaScript/TypeScript

```
// Switch ORDERS to Discard New. Discard New never drops stored messages, so

// capping it at one message leaves the existing orders in place and puts the

// stream instantly over its limit; the next publish is rejected.

const jsm = await jetstreamManager(nc);

await jsm.streams.update("ORDERS", { discard: DiscardPolicy.New, max_msgs: 1 });



// This publish hits the full stream and rejects with "maximum messages

// exceeded" instead of succeeding silently. Handle it in the publisher.

const js = jetstream(nc);

try {

  await js.publish("orders.created", JSON.stringify({ order_id: "ord_8w2k" }));

} catch (err) {

  console.log(`publish rejected: ${(err as Error).message}`);

}



// Put ORDERS back: Discard Old, no message cap (age and byte limits stay).

await jsm.streams.update("ORDERS", { discard: DiscardPolicy.Old, max_msgs: -1 });
```

#### Go

```
// Switch ORDERS to Discard New. Discard New never drops messages already

// stored, so capping it at one message leaves the existing orders in place

// and puts the stream instantly over its limit. The next publish is

// rejected rather than evicting an older order.

s, err := js.Stream(ctx, "ORDERS")

if err != nil {

	panic(err)

}

cfg := s.CachedInfo().Config

cfg.Discard = jetstream.DiscardNew

cfg.MaxMsgs = 1

if _, err := js.UpdateStream(ctx, cfg); err != nil {

	panic(err)

}



// This publish hits the full stream and fails with "maximum messages

// exceeded" instead of succeeding silently. Handle it in the publisher.

if _, err := js.Publish(ctx, "orders.created", []byte(`{"order_id":"ord_8w2k"}`)); err != nil {

	fmt.Printf("publish rejected: %v\n", err)

}



// Put ORDERS back: Discard Old, no message cap (age and byte limits stay).

cfg.Discard = jetstream.DiscardOld

cfg.MaxMsgs = -1

if _, err := js.UpdateStream(ctx, cfg); err != nil {

	panic(err)

}
```

#### Python

```
# Switch ORDERS to Discard New. Discard New never drops stored messages, so

# capping it at one message leaves the existing orders in place and puts the

# stream instantly over its limit; the next publish is rejected.

info = await js.stream_info("ORDERS")

config = info.config

config.discard = DiscardPolicy.NEW

config.max_msgs = 1

await js.update_stream(config)



# This publish hits the full stream and is rejected instead of succeeding

# silently. Handle it in the publisher.

try:

    await js.publish("orders.created", b'{"order_id":"ord_8w2k"}')

except APIError as err:

    print(f"publish rejected: {err.description}")



# Put ORDERS back: Discard Old, no message cap (age and byte limits stay).

config.discard = DiscardPolicy.OLD

config.max_msgs = -1

await js.update_stream(config)
```

#### Java

```
// Switch ORDERS to Discard New. Discard New never drops stored

// messages, so capping it at one message leaves the existing orders

// in place and puts the stream instantly over its limit; the next

// publish is rejected.

StreamInfo si = jsm.getStreamInfo("ORDERS");

jsm.updateStream(StreamConfiguration.builder(si.getConfiguration())

    .discardPolicy(DiscardPolicy.New)

    .maxMessages(1)

    .build());



// This publish hits the full stream and is rejected instead of

// succeeding silently. Handle it in the publisher.

try {

    js.publish("orders.created", "{\"order_id\":\"ord_8w2k\"}".getBytes());

}

catch (JetStreamApiException e) {

    System.out.println("publish rejected: " + e.getMessage());

}



// Put ORDERS back: Discard Old, no message cap (age and byte limits

// stay).

jsm.updateStream(StreamConfiguration.builder(si.getConfiguration())

    .discardPolicy(DiscardPolicy.Old)

    .maxMessages(-1)

    .build());
```

#### Rust

```
// Switch ORDERS to Discard New. Discard New never drops messages already

// stored, so capping it at one message leaves the existing orders in place

// and puts the stream instantly over its limit. The next publish is

// rejected rather than evicting an older order.

let mut stream = js.get_stream("ORDERS").await?;

let mut config = stream.info().await?.config.clone();

config.discard = DiscardPolicy::New;

config.max_messages = 1;

js.update_stream(config.clone()).await?;



// This publish hits the full stream; the ack returns an error instead of

// the publish succeeding silently. Handle it in the publisher.

let ack = js

    .publish("orders.created", r#"{"order_id":"ord_8w2k"}"#.into())

    .await?;

if let Err(err) = ack.await {

    println!("publish rejected: {err}");

}



// Put ORDERS back: Discard Old, no message cap (age and byte limits stay).

config.discard = DiscardPolicy::Old;

config.max_messages = -1;

js.update_stream(config).await?;
```

#### C#/.NET

```
// Switch ORDERS to Discard New. Discard New never drops stored messages,

// so capping it at one message leaves the existing orders in place and

// puts the stream instantly over its limit; the next publish is rejected.

var stream = await js.GetStreamAsync("ORDERS");

var config = stream.Info.Config;

config.Discard = StreamConfigDiscard.New;

config.MaxMsgs = 1;

await js.UpdateStreamAsync(config);



// This publish hits the full stream and is rejected instead of

// succeeding silently. Handle it in the publisher.

try

{

    var ack = await js.PublishAsync<Order>(subject: "orders.created", data: new Order(OrderId: "ord_5k1m"));



    // PublishAsync returns the server's answer; EnsureSuccess turns a

    // rejection into an exception instead of leaving it unchecked.

    ack.EnsureSuccess();

}

catch (NatsJSApiException e)

{

    output.WriteLine($"publish rejected: {e.Message}");

    rejected = true;

}



// Put ORDERS back: Discard Old, no message cap (age and byte limits stay).

config.Discard = StreamConfigDiscard.Old;

config.MaxMsgs = -1;

await js.UpdateStreamAsync(config);
```

#### C

```
// Switch ORDERS to Discard New. Discard New never drops messages

// already stored, so capping it at one message leaves the existing

// orders in place and puts the stream instantly over its limit. The

// next publish is rejected rather than evicting an older order.

const char *order = "{\"order_id\":\"ord_8w2k\"}";



s = js_GetStreamInfo(&si, js, "ORDERS", NULL, &jerr);

if (s == NATS_OK)

{

    si->Config->Discard = js_DiscardNew;

    si->Config->MaxMsgs = 1;

    s = js_UpdateStream(NULL, js, si->Config, NULL, &jerr);

}



// This publish hits the full stream and fails with "maximum messages

// exceeded" instead of succeeding silently. Handle it in the

// publisher.

if (s == NATS_OK)

{

    if (js_Publish(NULL, js, "orders.created", order, (int) strlen(order), NULL, &jerr) != NATS_OK)

        printf("publish rejected: %s\n", nats_GetLastError(NULL));

}



// Put ORDERS back: Discard Old, no message cap (age and byte limits

// stay).

if (s == NATS_OK)

{

    si->Config->Discard = js_DiscardOld;

    si->Config->MaxMsgs = -1;

    s = js_UpdateStream(NULL, js, si->Config, NULL, &jerr);

}
```

The same quiet discard applies to MaxAge and MaxBytes together. The two limits work separately, so whichever is reached first triggers the discard. A seven-day MaxAge does not guarantee seven days of history. If traffic spikes, MaxBytes can be reached first and discard messages that are only hours old. Set MaxBytes for your busiest traffic, not your average, if the age window matters to you.

**Whole-stream limits don't balance across subjects.** MaxMsgs, MaxBytes, and MaxAge measure `ORDERS` as a whole, across every subject under `orders.>`. A high volume of `orders.created` counts toward the same ceiling as `orders.shipped`, so Discard Old can discard a shipped order to make room for a created one. When each subject needs its own limit, add a per-subject ceiling with `MaxMsgsPerSubject`:

#### CLI

```
#!/bin/bash

# Add a per-subject ceiling to ORDERS so one noisy subject cannot evict

# another subject's messages.

#

# MaxMsgs, MaxBytes, and MaxAge all measure the stream as a whole,

# across every subject under orders.>. If orders.created floods in, its

# messages count toward the same ceiling as orders.shipped, and Discard

# Old can drop a shipped order to make room for a created one.

#

# --max-msgs-per-subject sets MaxMsgsPerSubject: a separate ceiling

# applied to each individual subject. Set it to 100000 and every subject

# keeps its own most-recent 100000 messages, independent of how loud its

# neighbors are.



nats stream edit ORDERS --max-msgs-per-subject=100000



# Read the stream back; the per-subject limit now appears alongside the

# whole-stream limits.

nats stream info ORDERS
```

#### JavaScript/TypeScript

```
// Add a per-subject ceiling so one noisy subject can't evict another's

// messages. max_msgs_per_subject keeps the most recent N messages for every

// subject independently, alongside the whole-stream limits.

const jsm = await jetstreamManager(nc);

await jsm.streams.update("ORDERS", { max_msgs_per_subject: 100000 });

console.log("ORDERS now keeps 100000 messages per subject");
```

#### Go

```
// Add a per-subject ceiling so one noisy subject can't evict another's

// messages. MaxMsgsPerSubject keeps the most recent N messages for every

// subject independently, alongside the whole-stream limits.

s, err := js.Stream(ctx, "ORDERS")

if err != nil {

	panic(err)

}

cfg := s.CachedInfo().Config

cfg.MaxMsgsPerSubject = 100000

if _, err := js.UpdateStream(ctx, cfg); err != nil {

	panic(err)

}

fmt.Println("ORDERS now keeps 100000 messages per subject")
```

#### Python

```
# Add a per-subject ceiling so one noisy subject can't evict another's

# messages. max_msgs_per_subject keeps the most recent N messages for every

# subject independently, alongside the whole-stream limits.

info = await js.stream_info("ORDERS")

config = info.config

config.max_msgs_per_subject = 100000

await js.update_stream(config)

print("ORDERS now keeps 100000 messages per subject")
```

#### Java

```
// Add a per-subject ceiling so one noisy subject can't evict

// another's messages. maxMessagesPerSubject keeps the most recent N

// messages for every subject independently, alongside the

// whole-stream limits.

StreamInfo si = jsm.getStreamInfo("ORDERS");

StreamConfiguration cfg = StreamConfiguration.builder(si.getConfiguration())

    .maxMessagesPerSubject(100000)

    .build();

jsm.updateStream(cfg);

System.out.println("ORDERS now keeps 100000 messages per subject");
```

#### Rust

```
// Add a per-subject ceiling so one noisy subject can't evict another's

// messages. max_messages_per_subject keeps the most recent N messages for

// every subject independently, alongside the whole-stream limits.

let mut stream = js.get_stream("ORDERS").await?;

let mut config = stream.info().await?.config.clone();

config.max_messages_per_subject = 100_000;

js.update_stream(config).await?;

println!("ORDERS now keeps 100000 messages per subject");
```

#### C#/.NET

```
// Add a per-subject ceiling so one noisy subject can't evict another's

// messages. MaxMsgsPerSubject keeps the most recent N messages for every

// subject independently, alongside the whole-stream limits.

var stream = await js.GetStreamAsync("ORDERS");

var config = stream.Info.Config;

config.MaxMsgsPerSubject = 100000;

await js.UpdateStreamAsync(config);

output.WriteLine("ORDERS now keeps 100000 messages per subject");
```

#### C

```
// Add a per-subject ceiling so one noisy subject can't evict

// another's messages. MaxMsgsPerSubject keeps the most recent N

// messages for every subject independently, alongside the

// whole-stream limits.

s = js_GetStreamInfo(&si, js, "ORDERS", NULL, &jerr);

if (s == NATS_OK)

{

    si->Config->MaxMsgsPerSubject = 100000;

    s = js_UpdateStream(NULL, js, si->Config, NULL, &jerr);

}

if (s == NATS_OK)

    printf("ORDERS now keeps 100000 messages per subject\n");
```

Under Discard Old, a per-subject ceiling discards the oldest message *for that subject* once it fills. Discard New doesn't change that on its own: by default the per-subject limit still rolls, discarding the subject's oldest message rather than rejecting the publish. Making a full subject reject takes a second setting, `DiscardNewPerSubject` (the `discard_new_per_subject` config field), on top of Discard New. With both, a publish past the per-subject ceiling fails with `maximum messages per subject exceeded`, a third rejection string alongside the whole-stream `maximum bytes exceeded` and `maximum messages exceeded`. The field is in [Reference → Stream Configuration](/reference/jetstream/api/stream/create.md).

## Where you are

You now have:

* an `ORDERS` stream capped at a seven-day MaxAge and a 1 GiB MaxBytes ceiling
* the messages from earlier still stored (editing limits doesn't discard messages that already sit within them)
* Discard Old in place, so a future limit discards the oldest order, never the newest

## What's next

You set *limits* under the default Limits retention policy. The next page covers the policy choice itself: the three retention policies, Limits versus Interest versus WorkQueue, and which one to use when.

## See also

* [Reference → Stream Configuration](/reference/jetstream/api/stream/create.md) — every limit option, its type, range, and default.
