<!-- source: https://docs.nats.io/learn/jetstream/subject-mapping.md · fetched 2026-08-31 · section: subject-mapping -->
# Subject mapping and transforms

A [filter](/learn/jetstream/filtering.md) picks which stored messages a consumer sees without ever changing a subject. **Subject mapping** rewrites the subject itself, in three places:

* **On the way in** — a stream's *subject transform* rewrites a message's subject as it's stored.
* **On the way out** — *republish* re-emits each stored message onto a new subject, so plain core subscribers can watch a stream without a consumer.
* **While copying** — a source or a mirror can transform subjects as it pulls from another stream (see [Mirrors and sources](/learn/jetstream/mirrors-and-sources.md)).

All three use the same small transform language.

## The transform language

A transform is a `source → destination` pair. The source is a subject filter with the usual `*` and `>` wildcards; the destination is a subject template that pulls matched tokens back in by position:

* `{{wildcard(1)}}` — the token the first `*` matched (`{{wildcard(2)}}` the second, and so on). The older `$1` form means the same thing.
* `{{partition(n, 1)}}` — hash the token the first `*` matched into one of `n` buckets, `0`…`n-1`. The same value always lands in the same bucket, so it's a stable way to shard.
* A trailing `>` in the source carries across to a `>` in the destination unchanged — that's how `orders.>` maps to `dash.orders.>`, with every token after `orders` riding along.
* `{{split(1, -)}}`, `{{splitfromleft(1, 3)}}` — reshape a single matched token: split it wherever a bare delimiter appears (written without quotes, and it can't be `.`, which already separates tokens), or cut it at a character position.

ADR-30 (linked below) has the complete list. You'll mostly reach for `wildcard` and `partition`; `split`, `splitfromleft`/`splitfromright`, and `slicefromleft`/`slicefromright` chop a single token when you need it.

You can try a transform without a stream. `nats server mappings` takes the source, the destination, and a subject, and prints what it maps to:

```
nats server mappings "orders.*" "orders.{{wildcard(1)}}.archived" orders.created
```

```
orders.created.archived
```

## Rewrite subjects on the way in

A stream's **subject transform** rewrites the subject a message is stored under. The stream keeps listening on all its configured subjects: a message whose subject matches the transform's source is stored under the rewritten subject, and any other message is stored under its original subject. A transform rewrites subjects; it never drops a message.

**Message flow — A stream's subject transform (animated):** A stream's subject transform rewrites the subject a message is stored under. Messages arrive on ingest.\<customer>; as each passes through the transform orders.{{partition(3,1)}}.{{wildcard(1)}}, its subject is rewritten — the customer token is hashed into one of three buckets and carried into the new subject. The same customer always hashes to the same bucket, so acme and globex both land in bucket 1 while hooli goes to 0 and wayne to 2, which lets consumers split the load by bucket.

A common use is deterministic partitioning: hash a token into a fixed set of buckets so consumers can split the load by bucket. Leave `ORDERS` alone — this is a throwaway stream that ingests on `ingest.*` and shards each message into one of three buckets by hashing the customer token:

#### CLI

```
#!/bin/bash



# A subject transform rewrites the subject a message is STORED under, which

# is separate from the subjects the stream listens on. Leave ORDERS alone:

# this is a throwaway stream that ingests on ingest.* and shards each

# message into one of three buckets by hashing the customer token.

#   --transform-source        which incoming subjects to match (wildcards ok)

#   --transform-destination    the stored subject, pulling matched tokens in

#     {{partition(3,1)}}   hash the 1st token into bucket 0, 1, or 2

#     {{wildcard(1)}}      the 1st * token from the source

nats stream add ORDERS-SHARDED \

  --subjects "ingest.*" \

  --transform-source "ingest.*" \

  --transform-destination "orders.{{partition(3,1)}}.{{wildcard(1)}}" \

  --defaults
```

#### JavaScript/TypeScript

```
// Create ORDERS-SHARDED with a subject transform. Every message on `ingest.*`

// is rewritten before it is stored: `partition(3,1)` shards each customer

// (the first wildcard token) into one of three buckets, and `wildcard(1)`

// keeps the customer id, so `ingest.acme` becomes `orders.<0-2>.acme`.

const info = await jsm.streams.add({

  name: "ORDERS-SHARDED",

  subjects: ["ingest.*"],

  subject_transform: {

    src: "ingest.*",

    dest: "orders.{{partition(3,1)}}.{{wildcard(1)}}",

  },

});

console.log(`Created stream: ${info.config.name}`);
```

#### Go

```
// Create a stream that rewrites subjects as it stores them. The transform

// shards each customer into one of three buckets: partition(3,1) hashes the

// first wildcard token into 0, 1, or 2, and wildcard(1) keeps that token.

// So "ingest.alice" might land on "orders.2.alice".

stream, err := js.CreateStream(ctx, jetstream.StreamConfig{

	Name:     "ORDERS-SHARDED",

	Subjects: []string{"ingest.*"},

	SubjectTransform: &jetstream.SubjectTransformConfig{

		Source:      "ingest.*",

		Destination: "orders.{{partition(3,1)}}.{{wildcard(1)}}",

	},

})

if err != nil {

	panic(err)

}



fmt.Printf("Created stream: %s\n", stream.CachedInfo().Config.Name)
```

#### Python

```
# Create a stream that rewrites subjects as it stores them. Incoming

# ingest.<customer> messages become orders.<bucket>.<customer>, where

# partition(3,1) hashes the first wildcard token into one of three

# buckets — sharding each customer into a fixed partition.

info = await js.add_stream(

    StreamConfig(

        name="ORDERS-SHARDED",

        subjects=["ingest.*"],

        subject_transform=SubjectTransform(

            src="ingest.*",

            dest="orders.{{partition(3,1)}}.{{wildcard(1)}}",

        ),

    )

)



print(f"created stream {info.config.name}")
```

#### Java

```
// Rewrite each ingested subject as it lands in the stream. The template

// shards each customer into one of three buckets: partition(3,1) hashes

// the first wildcard token into 0, 1 or 2, and wildcard(1) keeps that

// same token as the trailing part of the stored subject.

SubjectTransform st = new SubjectTransform(

        "ingest.*",

        "orders.{{partition(3,1)}}.{{wildcard(1)}}");



StreamConfiguration sc = StreamConfiguration.builder()

        .name("ORDERS-SHARDED")

        .subjects("ingest.*")

        .subjectTransform(st)

        .build();

StreamInfo info = jsm.addStream(sc);



System.out.println("Created stream: " + info.getConfiguration().getName());
```

#### Rust

```
// Create a stream that rewrites each incoming subject as it is stored. Every

// message published to `ingest.*` is transformed into

// `orders.<bucket>.<original-token>`, where `partition(3, 1)` hashes the first

// wildcard token into one of three buckets (0, 1, or 2). This spreads orders

// across three shard subjects so consumers can filter by bucket.

let stream = js

    .create_stream(stream::Config {

        name: "ORDERS-SHARDED".to_string(),

        subjects: vec!["ingest.*".to_string()],

        subject_transform: Some(stream::SubjectTransform {

            source: "ingest.*".to_string(),

            destination: "orders.{{partition(3,1)}}.{{wildcard(1)}}".to_string(),

        }),

        ..Default::default()

    })

    .await?;



println!("Created stream: {}", stream.cached_info().config.name);
```

#### C#/.NET

```
// Ingest orders on `ingest.<customer>` and rewrite the subject on the way

// in. `partition(3, 1)` hashes the first wildcard token into one of three

// buckets, so each customer always shards to the same bucket.

var stream = await js.CreateStreamAsync(new StreamConfig(name: "ORDERS-SHARDED", subjects: ["ingest.*"])

{

    SubjectTransform = new SubjectTransform

    {

        Src = "ingest.*",

        Dest = "orders.{{partition(3,1)}}.{{wildcard(1)}}",

    },

});



output.WriteLine($"Created {stream.Info.Config.Name}");
```

#### C

```
// Create a stream that rewrites subjects as it stores them. The

// transform shards each customer into one of three buckets:

// partition(3,1) hashes the first wildcard token into 0, 1, or 2,

// and wildcard(1) keeps that token. So "ingest.alice" might land on

// "orders.2.alice".

jsStreamConfig  sc;

const char      *subjects[] = {"ingest.*"};



jsStreamConfig_Init(&sc);

sc.Name        = "ORDERS-SHARDED";

sc.Subjects    = subjects;

sc.SubjectsLen = 1;

sc.SubjectTransform.Source      = "ingest.*";

sc.SubjectTransform.Destination = "orders.{{partition(3,1)}}.{{wildcard(1)}}";

s = js_AddStream(&si, js, &sc, NULL, &jerr);

if (s == NATS_OK)

    printf("Created stream: %s\n", si->Config->Name);
```

Publish a few customers' orders, and each lands under `orders.<bucket>.<customer>`:

```
nats pub ingest.acme   "an order"

nats pub ingest.globex "an order"

nats pub ingest.wayne  "an order"

nats stream subjects ORDERS-SHARDED
```

```
Subject         │ Count

orders.1.acme   │ 1

orders.1.globex │ 1

orders.2.wayne  │ 1
```

Each customer hashes to the same bucket every time, so a consumer filtered to one bucket — `orders.1.>` here — always reads the same share of customers. Add or remove the transform on an existing stream with `nats stream edit --transform-source/--transform-destination`, or `--no-transform` to clear it.

The transform rewrites only what gets stored from the moment it's set. It doesn't touch messages already in the stream; the Pitfalls cover what that means.

## Republish to live subjects

**Republish** re-emits every message a stream stores onto a second subject, in real time. Core subscribers listen on that subject and see the data flow by without creating a consumer or replaying anything — a low-cost way to feed a dashboard or a monitor from a stored stream.

#### CLI

```
#!/bin/bash



# Republish re-emits every message the stream stores onto a second subject,

# in real time. A plain core subscriber on that subject sees the data flow

# by without creating a consumer. This adds republish to ORDERS; clear it

# later with: nats stream edit ORDERS --no-republish

nats stream edit ORDERS \

  --republish-source "orders.>" \

  --republish-destination "dash.orders.>"
```

#### JavaScript/TypeScript

```
// Add a republish rule so every message stored under `orders.>` is also

// published live to a matching `dash.orders.>` subject that dashboards can

// subscribe to, then apply the update.

const config = info.config;

config.republish = {

  src: "orders.>",

  dest: "dash.orders.>",

  // headers_only: true, // republish only the headers, not the message body

};

const updated = await jsm.streams.update("ORDERS", config);

console.log(`republish dest: ${updated.config.republish?.dest}`);
```

#### Go

```
// Read the current config, add a republish rule, and push the update.

// Every message stored on "orders.>" is also echoed live to "dash.orders.>"

// so a dashboard can subscribe without touching the stream.

cfg := stream.CachedInfo().Config

cfg.RePublish = &jetstream.RePublish{

	Source:      "orders.>",

	Destination: "dash.orders.>",

	// HeadersOnly: true, // republish only the headers, not the body

}



updated, err := js.UpdateStream(ctx, cfg)

if err != nil {

	panic(err)

}



fmt.Printf("Republish destination: %s\n", updated.CachedInfo().Config.RePublish.Destination)
```

#### Python

```
# Republish every stored orders.> message onto a dash.orders.> subject, so

# core subscribers can watch the stream live without a consumer.

# Set headers_only=True to republish just the headers, not the body.

config.republish = RePublish(

    src="orders.>",

    dest="dash.orders.>",

    # headers_only=True,

)

updated = await js.update_stream(config)



print(f"republishing to {updated.config.republish.dest}")
```

#### Java

```
// Republish every message ORDERS stores onto a parallel subject that

// ordinary core subscribers can watch, without them touching the stream.

Republish rp = Republish.builder()

        .source("orders.>")

        .destination("dash.orders.>")

        // .headersOnly(true) // republish only the headers, not the body

        .build();



StreamConfiguration updated = StreamConfiguration.builder(current)

        .republish(rp)

        .build();

StreamInfo info = jsm.updateStream(updated);



System.out.println("Republish destination: " + info.getConfiguration().getRepublish().getDestination());
```

#### Rust

```
// Republish a copy of every stored message onto a second subject so a

// dashboard can subscribe live without touching the stream. Set

// `headers_only: true` to republish just the headers (subject, sequence,

// size) and skip the payload.

config.republish = Some(async_nats::jetstream::stream::Republish {

    source: "orders.>".to_string(),

    destination: "dash.orders.>".to_string(),

    headers_only: false,

});

let info = js.update_stream(&config).await?;



println!(

    "Republishing to: {}",

    info.config

        .republish

        .as_ref()

        .map_or("", |r| r.destination.as_str())

);
```

#### C#/.NET

```
// Mirror every stored order onto a `dash.orders.>` subject as it lands.

// Read the current config, add the republish rule, and send it back.

var config = stream.Info.Config;

config.Republish = new Republish

{

    Src = "orders.>",

    Dest = "dash.orders.>",



    // HeadersOnly = true,

};



var updated = await js.UpdateStreamAsync(config);



output.WriteLine($"Republishing to {updated.Info.Config.Republish!.Dest}");
```

#### C

```
// Read the current config, add a republish rule, and push the

// update. Every message stored on "orders.>" is also echoed live to

// "dash.orders.>" so a dashboard can subscribe without touching the

// stream.

jsRePublish rp;



s = js_GetStreamInfo(&si, js, "ORDERS", NULL, &jerr);

if (s == NATS_OK)

{

    jsRePublish_Init(&rp);

    rp.Source      = "orders.>";

    rp.Destination = "dash.orders.>";

    // rp.HeadersOnly = true; // republish only the headers, not the body

    si->Config->RePublish = &rp;

    s = js_UpdateStream(&updated, js, si->Config, NULL, &jerr);

}

if (s == NATS_OK)

    printf("Republish destination: %s\n", updated->Config->RePublish->Destination);
```

Now a plain core subscription sees each order as it lands:

```
nats sub "dash.orders.>"
```

```
[#1] Received on "dash.orders.created"

Nats-Stream: ORDERS

Nats-Subject: orders.created

Nats-Sequence: 5

Nats-Time-Stamp: 2026-05-22T11:02:00Z

Nats-Last-Sequence: 4



{"order_id":"ord_5xk1","customer":"initech","total_cents":1500,"ts":"2026-05-22T11:02:00Z"}
```

Each republished message carries five headers describing where it came from: `Nats-Stream`, `Nats-Subject` (the original stored subject), `Nats-Sequence`, `Nats-Time-Stamp`, and `Nats-Last-Sequence` — the stream sequence of the previous message *on the same subject*, or `0` if there wasn't one, so a subscriber following one subject can tell it missed something. Any headers the publisher set are carried through too.

`--republish-headers` sends the headers without the bodies, for subscribers that only need to know something changed; each message then also carries a `Nats-Msg-Size` header with the omitted body's byte count. Clear republish with `nats stream edit ORDERS --no-republish`.

## Transform while copying

When a stream **sources** from or **mirrors** another stream, each source can carry its own subject transform, so you can re-namespace messages as you aggregate them — for example prefixing every region's orders as they merge into one stream. That belongs with the copying mechanics, so it's covered on [Mirrors and sources](/learn/jetstream/mirrors-and-sources.md).

## Not the same as account subject mapping

NATS also has [account-level subject mapping](/learn/core-nats/subject-mapping.md), configured on the server, not on a stream. It reroutes *core* subjects before they're ever published into a stream. That's a server-configuration topic, separate from the stream transforms on this page.

## Pitfalls

A few ways subject mapping trips people up.

**A transform that drops a token a consumer filters on.** A destination template keeps only the tokens you name. Rewrite `orders.*` to `orders.archived` and drop the `{{wildcard(1)}}`, and every order is stored under the one subject `orders.archived`, where a consumer can no longer filter by type. Keep every token a downstream filter needs in the destination.

**Republish is not a consumer.** A republished subject is plain core NATS: fire-and-forget, no storage, no acks, no replay. A subscriber that's down misses whatever was republished while it was away, and nothing redelivers it. Use republish to watch a stream live; use a consumer when a reader has to catch up on what it missed.

**A republish destination that loops back into the stream.** The destination can't overlap the stream's own subjects. Point a stream that ingests `orders.>` at destination `orders.dash.>` and the server rejects it as a cycle (error `10052`). Send republished messages to a separate subject space — `dash.orders.>`, not something under `orders.>` — and watch for loops that span two streams in one account, which the server can't always catch.

**Editing a transform doesn't rewrite what's already stored.** Adding or changing a subject transform only affects messages stored after the change. Messages already in the stream keep the subjects they were stored under. To re-namespace existing data, copy it into a new stream that sources from the old one with the transform applied.

**A partition count is fixed once consumers depend on it.** Consumers filter on bucket numbers (`orders.0.>`, `orders.1.>`, …). Change `partition(3, …)` to `partition(4, …)` later and the same customer can hash to a different bucket, so a consumer's filter quietly starts covering a different set. Pick the bucket count up front, the way you would for any partitioned system.

## Where you are

`ORDERS` is unchanged by the transform work — that ran on a throwaway `ORDERS-SHARDED` stream. If you added republish to `ORDERS` above, that's the one change; it's additive, and `nats stream edit ORDERS --no-republish` clears it. You saw the three places JetStream rewrites a subject:

* a **subject transform** that changes the stored subject on the way in
* **republish** that re-emits stored messages onto a live subject on the way out
* the per-source transforms that rewrite subjects while copying, over on [Mirrors and sources](/learn/jetstream/mirrors-and-sources.md)

## What's next

The next page covers [per-message TTL](/learn/jetstream/message-ttl.md): giving a single message a shorter lifespan than the rest of the stream.

## See also

* [Reference → Create Stream](/reference/jetstream/api/stream/create.md) — the `subject_transform`, `republish`, and per-source `subject_transforms` fields.
* [ADR-36: Subject Mapping Transforms in Streams](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-36.md) — where a transform attaches to a stream, a source, or a mirror.
* [ADR-30: Subject Transform](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-30.md) — the transform template functions and their exact behavior.
* [ADR-28: RePublish](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-28.md) — the republish headers and the loop-prevention rules.
* [Filtering what you consume](/learn/jetstream/filtering.md) — narrowing a consumer's view without changing subjects.
* [Mirrors and sources](/learn/jetstream/mirrors-and-sources.md) — transforms applied while aggregating streams.
