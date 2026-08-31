<!-- source: https://docs.nats.io/learn/jetstream/get-direct.md · fetched 2026-08-31 · section: get-direct -->
# Reading messages directly

[Reading back the stream](/learn/jetstream/reading-back.md) built a consumer to walk the whole log in order. That's the right tool when a reader works through every message and keeps its place between runs. Some reads need less than that: one message by its sequence, or the latest order on a subject, with no consumer to create and no position to track.

JetStream has a lighter read for those. You ask the stream for a message and the server returns it straight from the store.

## Get one message

Every stored message has a sequence number, the one the `PubAck` returned when you published it. Give the server that number and it hands the message back:

#### CLI

```
#!/bin/bash



# Get one stored message by its sequence number — the number the PubAck

# returned when the message was published. No consumer, no ack, no cursor:

# the server reads the message straight from the stream's store and returns it.

nats stream get ORDERS 2
```

#### JavaScript/TypeScript

```
// Read the message at stream sequence 2 through the regular get API, which is

// served by the stream leader.

const m = await jsm.streams.getMessage("ORDERS", { seq: 2 });

console.log(`subject: ${m?.subject}`);

console.log(`payload: ${m?.string()}`);
```

#### Go

```
// Read the message stored at stream sequence 2. This is the regular get,

// served by the stream leader.

msg, err := stream.GetMsg(ctx, 2)

if err != nil {

	panic(err)

}



fmt.Printf("Subject: %s\n", msg.Subject)

fmt.Printf("Payload: %s\n", string(msg.Data))
```

#### Python

```
# Get one stored message by its sequence number — the number the PubAck

# returned when it was published. This regular get is served by the

# stream's leader, so it always sees the latest write.

msg = await js.get_msg("ORDERS", seq=2)



print(f"seq {msg.seq} on {msg.subject}: {msg.data.decode()}")
```

#### Java

```
// Read the message stored at stream sequence 2. Without Direct Get

// enabled this is a regular get, served by the stream leader.

MessageInfo mi = sc.getMessage(2);



System.out.println("Subject: " + mi.getSubject());

System.out.println("Payload: " + new String(mi.getData(), StandardCharsets.UTF_8));
```

#### Rust

```
// Read the message stored at stream sequence 2. This raw-message get always

// goes to the stream leader.

let message = stream.get_raw_message(2).await?;



println!("Subject: {}", message.subject);

println!("Payload: {}", String::from_utf8_lossy(&message.payload));
```

#### C#/.NET

```
// Fetch one specific message by its stream sequence. This is a regular

// get, served by the stream leader.

var response = await stream.GetAsync(new StreamMsgGetRequest { Seq = 2 });



var message = response.Message;

var payload = Encoding.UTF8.GetString(message.Data.Span);

output.WriteLine($"Subject: {message.Subject}");

output.WriteLine($"Payload: {payload}");
```

#### C

```
// Read the message stored at stream sequence 2. This is the regular get,

// served by the stream leader.

if (s == NATS_OK)

    s = js_GetMsg(&msg, js, "ORDERS", 2, NULL, &jerr);



if (s == NATS_OK)

{

    printf("Subject: %s\n", natsMsg_GetSubject(msg));

    printf("Payload: %.*s\n", natsMsg_GetDataLength(msg), natsMsg_GetData(msg));

}
```

```
Item: ORDERS#2 received 2026-05-22 10:14:25 +0000 UTC (36h2m11s) on Subject orders.created



{"order_id":"ord_2zr9","customer":"globex","total_cents":7800,"ts":"2026-05-22T10:14:25Z"}
```

More often you don't have the sequence; you have the subject and want its most recent message. `--last-for` returns the last message stored on a subject:

#### CLI

```
#!/bin/bash



# Get the most recent message stored on a subject, when you know the subject

# but not the sequence. This is the read a key-value lookup is built on:

# "the latest value for a key" is "the last message on its subject".

nats stream get ORDERS --last-for orders.shipped
```

#### JavaScript/TypeScript

```
// Read the last message stored on subject orders.shipped through the regular

// get API, which is served by the stream leader.

const m = await jsm.streams.getMessage("ORDERS", {

  last_by_subj: "orders.shipped",

});

console.log(`subject: ${m?.subject}`);

console.log(`payload: ${m?.string()}`);
```

#### Go

```
// Read the last message stored on subject orders.shipped. This is the

// regular get, served by the stream leader.

msg, err := stream.GetLastMsgForSubject(ctx, "orders.shipped")

if err != nil {

	panic(err)

}



fmt.Printf("Subject: %s\n", msg.Subject)

fmt.Printf("Payload: %s\n", string(msg.Data))
```

#### Python

```
# Get the most recent message stored on a subject, when you know the

# subject but not the sequence. This is the read a key-value lookup uses.

msg = await js.get_last_msg("ORDERS", "orders.shipped")



print(f"seq {msg.seq} on {msg.subject}: {msg.data.decode()}")
```

#### Java

```
// Read the most recent message on a subject. Without Direct Get

// enabled this is a regular get, served by the stream leader.

MessageInfo mi = sc.getLastMessage("orders.shipped");



System.out.println("Subject: " + mi.getSubject());

System.out.println("Payload: " + new String(mi.getData(), StandardCharsets.UTF_8));
```

#### Rust

```
// Read the last message stored on subject `orders.shipped`. This raw-message

// get always goes to the stream leader.

let message = stream

    .get_last_raw_message_by_subject("orders.shipped")

    .await?;



println!("Subject: {}", message.subject);

println!("Payload: {}", String::from_utf8_lossy(&message.payload));
```

#### C#/.NET

```
// Fetch the most recent message on a subject. This is a regular get,

// served by the stream leader.

var response = await stream.GetAsync(new StreamMsgGetRequest { LastBySubj = "orders.shipped" });



var message = response.Message;

var payload = Encoding.UTF8.GetString(message.Data.Span);

output.WriteLine($"Subject: {message.Subject}");

output.WriteLine($"Payload: {payload}");
```

#### C

```
// Read the last message stored on subject orders.shipped. This is the

// regular get, served by the stream leader.

if (s == NATS_OK)

    s = js_GetLastMsg(&msg, js, "ORDERS", "orders.shipped", NULL, &jerr);



if (s == NATS_OK)

{

    printf("Subject: %s\n", natsMsg_GetSubject(msg));

    printf("Payload: %.*s\n", natsMsg_GetDataLength(msg), natsMsg_GetData(msg));

}
```

```
Item: ORDERS#3 received 2026-05-22 10:14:31 +0000 UTC (36h2m05s) on Subject orders.shipped



{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:31Z"}
```

This is the read a key-value lookup is built on. A KV bucket is a stream keyed by subject, and "get the value for this key" is "get the last message on this subject." The [Key-Value deep dive](/learn/key-value/.md) uses exactly this read underneath.

Both forms ask the stream's leader, the one server that holds the latest write, so a `nats stream get` right after a publish always sees it.

## Direct Get reads from any replica

`nats stream get` goes to the leader. That's fine for the occasional lookup. For a read you run often, or from far away, JetStream offers **Direct Get**: the same by-sequence and by-subject reads, answered by *any* server that holds a copy of the stream, not only the leader.

**Message flow — Direct Get reads from any replica (animated):** Direct Get reads one message by sequence from any copy of a replicated stream, not only the leader. ORDERS is replicated across three servers — a leader and two replicas, each holding a full copy. A reader fires a stream of Direct Gets, each for a different sequence number; every read is answered by whichever copy serves it — sometimes the leader, sometimes a replica — and a per-server tally shows the read load spreading across all three.

Direct Get is the stream's `allow_direct` setting. Check it with `nats stream info ORDERS`: its output carries a `Direct Get: true` line when the setting is on, and no such line when it's off. The CLI enables it for new streams, so `ORDERS` already has it — turn it on for a stream that doesn't:

#### CLI

```
#!/bin/bash



# Turn on Direct Get for a stream that doesn't have it. The CLI enables it

# for new streams, so ORDERS already shows "Direct Get: true" in stream info;

# run this only if a stream shows "Direct Get: false".

nats stream edit ORDERS --allow-direct
```

#### JavaScript/TypeScript

```
// Turn on direct access by setting allow_direct on the stream config and

// applying the update.

const config = info.config;

config.allow_direct = true;

const updated = await jsm.streams.update("ORDERS", config);

console.log(`allow_direct: ${updated.config.allow_direct}`);
```

#### Go

```
// Read the current config, turn on direct access, and push the update.

// AllowDirect lets any replica serve single-message gets.

info, err := stream.Info(ctx)

if err != nil {

	panic(err)

}



cfg := info.Config

cfg.AllowDirect = true



updated, err := js.UpdateStream(ctx, cfg)

if err != nil {

	panic(err)

}



fmt.Printf("AllowDirect: %v\n", updated.CachedInfo().Config.AllowDirect)
```

#### Python

```
# Turn on Direct Get for the stream. With allow_direct enabled, get-message

# requests can be served by any replica instead of only the stream leader.

config.allow_direct = True

updated = await js.update_stream(config)



print(f"allow_direct is now {updated.config.allow_direct}")
```

#### Java

```
// Turn on Direct Get for ORDERS. Reads can then be served by any

// replica or mirror instead of only the stream leader.

StreamConfiguration updated = StreamConfiguration.builder(current)

        .allowDirect(true)

        .build();

StreamInfo info = jsm.updateStream(updated);



System.out.println("AllowDirect: " + info.getConfiguration().getAllowDirect());
```

#### Rust

```
// Turn on direct get for the stream, then push the updated config.

config.allow_direct = true;

let info = js.update_stream(&config).await?;



println!("allow_direct is now: {}", info.config.allow_direct);
```

#### C#/.NET

```
// Turn on direct get by updating the stream config. Read the current

// config, set AllowDirect, and send the update back.

var config = stream.Info.Config;

config.AllowDirect = true;



var updated = await js.UpdateStreamAsync(config);



output.WriteLine($"AllowDirect: {updated.Info.Config.AllowDirect}");
```

#### C

```
// Read the current config, turn on direct access, and push the update.

// AllowDirect lets any replica serve single-message gets.

if (s == NATS_OK)

    s = js_GetStreamInfo(&si, js, "ORDERS", NULL, &jerr);



if (s == NATS_OK)

{

    si->Config->AllowDirect = true;

    s = js_UpdateStream(&updated, js, si->Config, NULL, &jerr);

}



if (s == NATS_OK)

    printf("AllowDirect: %s\n", updated->Config->AllowDirect ? "true" : "false");
```

With it on, read directly with the Direct Get API. This fetches the message at sequence 1 from any replica that holds it, not just the leader:

#### CLI

```
#!/bin/bash



# Read directly from the stream's store with the Direct Get API. --direct

# routes the read to any server holding a copy of the stream, not just the

# leader. This fetches the message at sequence 1 from whichever replica

# answers, marked "(direct)" to show it came over the Direct Get API.

nats sub --stream ORDERS --direct --start-sequence 1 --count 1
```

#### JavaScript/TypeScript

```
// Read a single message at sequence 1 through the Direct Get API. This needs

// allow_direct on the stream and can be served by any replica, not just the

// leader.

const m = await jsm.direct.getMessage("ORDERS", { seq: 1 });

console.log(`subject: ${m?.subject}`);

console.log(`payload: ${m?.string()}`);
```

#### Go

```
// Read the message at sequence 1. Because the stream has AllowDirect

// enabled, GetMsg is served by the Direct Get API, so any replica can

// answer it, not only the leader.

msg, err := stream.GetMsg(ctx, 1)

if err != nil {

	panic(err)

}



fmt.Printf("Subject: %s\n", msg.Subject)

fmt.Printf("Payload: %s\n", string(msg.Data))
```

#### Python

```
# Read directly from the stream's store with the Direct Get API. With

# direct=True the read is served by any server holding a copy of the

# stream, not just the leader (the stream must have allow_direct set).

msg = await js.get_msg("ORDERS", seq=1, direct=True)



print(f"seq {msg.seq} on {msg.subject} (direct): {msg.data.decode()}")
```

#### Java

```
// Read the message at stream sequence 1. Because ORDERS has

// AllowDirect enabled, the client sends this over the Direct Get

// API, so any replica or mirror can answer instead of the leader.

MessageInfo mi = sc.getMessage(1);



System.out.println("Subject: " + mi.getSubject());

System.out.println("Payload: " + new String(mi.getData(), StandardCharsets.UTF_8));
```

#### Rust

```
// Read the message at stream sequence 1 with the Direct Get API. This can be

// served by any replica, not just the leader.

let message = stream.direct_get(1).await?;



println!("Subject: {}", message.subject);

println!("Payload: {}", String::from_utf8_lossy(&message.payload));
```

#### C#/.NET

```
// Read sequence 1 with a direct get. Any replica can serve this, not

// just the stream leader. The original subject comes back as a header.

var msg = await stream.GetDirectAsync<Order>(new StreamMsgGetRequest { Seq = 1 });



msg.Headers!.TryGetLastValue("Nats-Subject", out var subject);

output.WriteLine($"Subject: {subject}");

output.WriteLine($"Payload: {msg.Data}");
```

#### C

```
// Read the message at sequence 1. Because the stream has AllowDirect

// enabled, the Direct Get API serves the read, so any replica can

// answer it, not only the leader.

if (s == NATS_OK)

{

    jsDirectGetMsgOptions_Init(&dgo);

    dgo.Sequence = 1;

    s = js_DirectGetMsg(&msg, js, "ORDERS", NULL, &dgo);

}



if (s == NATS_OK)

{

    printf("Subject: %s\n", natsMsg_GetSubject(msg));

    printf("Payload: %.*s\n", natsMsg_GetDataLength(msg), natsMsg_GetData(msg));

}
```

```
Subscribing to JetStream Stream (direct) holding messages with subject orders.> starting with sequence 1

[#1] Received JetStream message (direct): stream: ORDERS seq 1 / subject: orders.created / time: 2026-05-22 10:14:22
```

The `(direct)` marks the path: the message came from a server's local store over the Direct Get API, not from the leader through the regular read. On a replicated stream that spreads read load across the servers, and when a mirror stream sets `mirror_direct`, the mirror's servers also answer Direct Get requests for the origin, so a reader can be served by a nearby [mirror](/learn/jetstream/mirrors-and-sources.md) instead of the origin.

The trade-off is freshness. A replica or mirror can sit a moment behind the leader, so Direct Get is **not read-after-write coherent**: a message you just published might not show up on a direct read for a beat, where `nats stream get` against the leader always sees it. For a latest-value lookup that tolerates being a little stale — a cache, a dashboard — that's a fair trade for spreading the load. When you must see your own most recent write, read the leader with `nats stream get`.

## Get a batch in one request

A single request can return more than one message. Ask Direct Get for a range and the server streams the matching messages back over one request, instead of a round trip each. This reads three messages starting at sequence 1:

#### CLI

```
#!/bin/bash



# Direct Get can return a batch of messages over a single request. Ask for three

# starting at sequence 1; the server streams them back without a round trip

# each, every message carrying a Nats-Num-Pending header that counts down to 0

# on the last one.

nats sub --stream ORDERS --direct --start-sequence 1 --count 3
```

#### JavaScript/TypeScript

```
// Fetch up to 3 messages starting at stream sequence 1 in a single Direct Get

// request. This needs allow_direct on the stream and can be served by any

// replica, not just the leader. getBatch returns an iterator of stored

// messages in stream order.

const iter = await jsm.direct.getBatch("ORDERS", { seq: 1, batch: 3 });

for await (const m of iter) {

  console.log(`seq ${m.seq} on ${m.subject}`);

}
```

#### Go

```
// Fetch up to 3 messages from ORDERS in a single Direct Get request,

// starting at stream sequence 1, and iterate them in order.

msgs, err := jetstreamext.GetBatch(ctx, js, "ORDERS", 3, jetstreamext.GetBatchSeq(1))

if err != nil {

	log.Fatalf("get batch: %v", err)

}

for msg, err := range msgs {

	if err != nil {

		log.Fatalf("read message: %v", err)

	}

	fmt.Printf("seq %d on %s\n", msg.Sequence, msg.Subject)

}
```

#### Java

```
// Batch Direct Get: in one request, read up to 3 messages from the

// ORDERS stream starting at stream sequence 1, then iterate in order.

DirectBatchContext direct = new DirectBatchContext(nc, STREAM);

MessageBatchGetRequest request = MessageBatchGetRequest.batch(">", 3, 1);



List<MessageInfo> messages = direct.fetchMessageBatch(request);

for (MessageInfo mi : messages) {

    System.out.println("sequence " + mi.getSeq() + " | subject " + mi.getSubject());

}
```

#### Rust

```
// Fetch up to 3 messages starting at stream sequence 1, all in one request.

let mut messages = js.get_batch("ORDERS", 3).sequence(1).send().await?;



// The batch arrives as a stream of messages in sequence order.

while let Some(msg) = messages.next().await {

    let msg = msg?;

    println!("seq {} on subject {}", msg.sequence, msg.subject);

}
```

#### C#/.NET

```
// Fetch up to three messages starting at stream sequence 1, in one request.

var request = new StreamMsgBatchGetRequest

{

    Seq = 1,

    Batch = 3,

};



// The server streams the messages back in sequence order.

await foreach (NatsMsg<string> msg in js.GetBatchDirectAsync<string>("ORDERS", request))

{

    // On a direct get the stream sequence and original subject come back in

    // headers, not in msg.Subject (which is the reply subject).

    msg.Headers!.TryGetValue("Nats-Sequence", out var sequence);

    msg.Headers!.TryGetValue("Nats-Subject", out var subject);



    Console.WriteLine($"seq {sequence}: {subject}");

}
```

Each message carries a `Nats-Num-Pending` header counting how many still match after it, so the client knows when the batch is complete — the count reaches `0` on the last message:

```
[#1] ... seq 1 ...   Nats-Num-Pending: 2

[#2] ... seq 2 ...   Nats-Num-Pending: 1

[#3] ... seq 3 ...   Nats-Num-Pending: 0
```

**Message flow — Batch Direct Get over one request (animated):** Batch Direct Get returns many messages over a single request, and any copy of a replicated stream can serve it. ORDERS is replicated across three servers — a leader and two replicas. Three batches run in turn, each served by a different copy, so batch reads spread across all three. Within a batch the serving copy streams the messages back one after another, each carrying a Nats-Num-Pending header that counts down — 2, then 1, then 0 on the last message — so the reader knows the batch is complete.

That makes Direct Get a cheap way to pull a slice of the log without standing up a consumer: a range from a sequence, the latest message on each of several subjects (`--last-per-subject`), or a point-in-time snapshot across subjects. A batch is bounded by a count or a byte budget; the request fields (`batch`, `max_bytes`, `multi_last`) are in the [reference](/reference/jetstream/api/stream/msg-get.md). `nats.js` sends a batched Direct Get directly; Go, Rust, Java, and C# reach it through the [Synadia Orbit](https://github.com/synadia-io) helper libraries.

A batch read is still a one-shot snapshot, not a subscription. It returns what's stored when you ask and stops. To keep receiving new orders as they arrive, that's a consumer's job.

## Direct Get or a consumer?

Both read a stream; they answer different needs.

* Reach for **Direct Get** (or `nats stream get`) for a point read: one message by sequence, the latest value on a subject, or a bounded batch snapshot. Nothing is acked, no position is kept, and any replica can answer.
* Reach for a **[consumer](/learn/jetstream/reading-back.md)** to work through the log: read every message in order, keep a durable position across restarts, ack as you go, and pick up new messages as they're published.

A direct read never moves a consumer's position and never removes a message. It only reads what's stored.

## Pitfalls

A direct read is simple, but a few assumptions trip people up.

**Direct Get is off, so the read hangs.** If `allow_direct` isn't set, no server answers the Direct Get subject and the request times out with nothing returned. Check `nats stream info` for `Direct Get: true`, or set it with `nats stream edit ORDERS --allow-direct`, before you point a direct reader at a stream.

**A direct read can be stale.** Direct Get answers from any replica or mirror, which may trail the leader. Don't use it for read-after-write checks — confirming a publish landed, reading a value you wrote a moment ago. Use `nats stream get` against the leader for those, and keep Direct Get for high-volume or far-away reads that tolerate a little lag.

**A batch isn't a subscription.** A direct batch returns the stored messages that match and stops. Code that expects to keep receiving new messages from it reads the backlog once and then sits idle. Use a consumer when you need to follow the stream as it grows.

## Where you are

`ORDERS` is unchanged. You now have a second way to read it, alongside the consumer from [reading back](/learn/jetstream/reading-back.md):

* `nats stream get` for one message, by sequence or by the last on a subject, answered by the leader and always current.
* **Direct Get** (`--direct`) for the same reads answered by any replica or mirror, and for pulling a bounded batch in one request — at the cost of read-after-write freshness.
* The split between a point read (Direct Get) and working through the log (a consumer).

## What's next

You've read messages by sequence and by subject. The next page changes the subjects themselves: [subject mapping](/learn/jetstream/subject-mapping.md) rewrites a message's subject on the way into a stream and on the way back out.

## See also

* [ADR-31: JetStream Direct Get](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-31.md) — the authoritative spec for `allow_direct`, the by-sequence, by-subject, batch, and multi-subject request forms, and the response headers.
* [Reference → Stream Configuration](/reference/jetstream/api/stream/create.md) — the `allow_direct` and `mirror_direct` fields alongside every other stream setting.
* [Reading back the stream](/learn/jetstream/reading-back.md) — the durable consumer that walks the whole log and keeps its place.
* [Mirrors and sources](/learn/jetstream/mirrors-and-sources.md) — mirrors that can answer Direct Get reads near a client.
