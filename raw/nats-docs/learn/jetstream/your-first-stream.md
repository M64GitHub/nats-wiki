<!-- source: https://docs.nats.io/learn/jetstream/your-first-stream.md · fetched 2026-08-31 · section: your-first-stream -->
# Your first stream

This page creates the `ORDERS` stream with one CLI command, then looks at it with another.

## Why a stream

The running example for this chapter is a small online store, the Acme `ORDERS` platform. Each thing that happens to an order shows up as a message on a [subject](/concepts/subjects.md):

* `orders.created` — a new order comes in
* `orders.shipped` — the order leaves the warehouse
* `orders.canceled` — the order is called off

Services react to those messages:

* a warehouse service packs the box on `orders.created`
* a notification service emails the customer on `orders.shipped`
* an analytics service counts everything

Plain core NATS drops any of these messages the moment no service is listening. A **stream** saves them instead. A stream is a store that runs on the server and keeps every message on the subjects you choose. You can read the saved messages again whenever you need them, minutes or a month after they arrived.

## Prerequisites

A running `nats-server` with JetStream enabled. If you haven't yet:

```
nats-server -js
```

The `-js` flag turns on JetStream. Without it, the next command won't run.

## Create the stream

In another terminal:

#### CLI

```
#!/bin/bash



# Create the ORDERS stream, capturing every subject under orders.>

# --defaults fills in the remaining config with sensible starting values.

nats stream add ORDERS --subjects "orders.>" --defaults



# Expected: output ending with

#   Stream ORDERS was created
```

#### JavaScript/TypeScript

```
// Get a JetStream manager and create the ORDERS stream, which captures

// every Acme order subject under `orders.`

const jsm = await jetstreamManager(nc);

const info = await jsm.streams.add({

  name: "ORDERS",

  subjects: ["orders.>"],

});

console.log(`Created stream: ${info.config.name}`);
```

#### Go

```
// Create the ORDERS stream, capturing every subject under 'orders.>'.

stream, err := js.CreateStream(ctx, jetstream.StreamConfig{

	Name:     "ORDERS",

	Subjects: []string{"orders.>"},

})

if err != nil {

	panic(err)

}



// Confirm the stream was created.

fmt.Printf("Created stream: %s\n", stream.CachedInfo().Config.Name)
```

#### Python

```
# Create the "ORDERS" stream, capturing every subject under "orders.".

info = await js.add_stream(name="ORDERS", subjects=["orders.>"])



# Confirm success by printing the stream name the server returned.

print(f"Created stream: {info.config.name}")
```

#### Java

```
// Create a stream named "ORDERS" that captures any subject under `orders.`

JetStreamManagement jsm = nc.jetStreamManagement();

StreamInfo streamInfo = jsm.addStream(StreamConfiguration.builder()

        .name("ORDERS")

        .subjects("orders.>")

        .storageType(StorageType.File)

    .build());



// Confirm the stream was created

System.out.println("Created stream: " + streamInfo.getConfiguration().getName());
```

#### Rust

```
// Create the ORDERS stream, capturing every subject under `orders.`.

let stream = js

    .create_stream(jetstream::stream::Config {

        name: "ORDERS".to_string(),

        subjects: vec!["orders.>".to_string()],

        storage: StorageType::File,

        ..Default::default()

    })

    .await?;



// Confirm success by printing the name the server assigned.

println!("Created stream: {}", stream.cached_info().config.name);
```

#### C#/.NET

```
// Create the ORDERS stream, capturing every subject under `orders.`

var stream = await js.CreateStreamAsync(new StreamConfig(name: "ORDERS", subjects: ["orders.>"]));



// Confirm the stream was created

output.WriteLine($"Created stream: {stream.Info.Config.Name}");
```

#### C

```
// Create the ORDERS stream, capturing every subject under 'orders.>'.

jsStreamConfig  cfg;

const char      *subjects[] = {"orders.>"};



jsStreamConfig_Init(&cfg);

cfg.Name        = "ORDERS";

cfg.Subjects    = subjects;

cfg.SubjectsLen = 1;



s = js_AddStream(&si, js, &cfg, NULL, &jerr);

if (s == NATS_OK)

{

    // Confirm the stream was created.

    printf("Created stream: %s\n", si->Config->Name);

}
```

Two parts of that command matter.

The first is the **stream name**: `ORDERS`. Stream names are case-sensitive. They can't contain dots, `*`, `>`, spaces, or slashes, so a subject like `orders.created` won't work as a name. The name shows up in every command and every error message in this chapter.

The second is the **subjects** the stream keeps: `orders.>`. That's a [wildcard](/concepts/subjects.md#wildcards). Any subject that starts with `orders.` goes into this stream. `orders.created`, `orders.shipped`, and `orders.canceled` all match. So would `orders.refunded` next month, with no change to the stream.

The `--defaults` flag tells `nats` not to prompt you for the other settings. The server fills them in with its standard defaults. We'll look at what those values are in a moment. For now, the defaults are fine.

You should see output ending with something like:

```
Stream ORDERS was created
```

If the command fails instead with `no responders available for request`, your server started without `-js`: JetStream isn't running, so nothing answers the request. Restart it with the flag and try again.

## Checking the created stream

Look at what the server just created:

#### CLI

```
#!/bin/bash



# Inspect the stream: its configuration (what you asked for plus the

# defaults the server filled in) and its state (what's stored right now).

nats stream info ORDERS
```

#### JavaScript/TypeScript

```
// Get a JetStream manager and look up the ORDERS stream, then print the

// key fields from its configuration and current state

const jsm = await jetstreamManager(nc);

const info = await jsm.streams.info("ORDERS");

console.log(`Stream:   ${info.config.name}`);

console.log(`Subjects: ${info.config.subjects?.join(", ")}`);

console.log(`Messages: ${info.state.messages}`);
```

#### Go

```
// Look up the ORDERS stream and fetch its latest info from the server.

stream, err := js.Stream(ctx, "ORDERS")

if err != nil {

	panic(err)

}



info, err := stream.Info(ctx)

if err != nil {

	panic(err)

}



// Print key fields: name, captured subjects, and current message count.

fmt.Printf("Name:     %s\n", info.Config.Name)

fmt.Printf("Subjects: %v\n", info.Config.Subjects)

fmt.Printf("Messages: %d\n", info.State.Msgs)
```

#### Python

```
# Fetch the latest information about the "ORDERS" stream.

info = await js.stream_info("ORDERS")



# Print key fields: name and subjects come from the config,

# the live message count comes from the stream state.

print(f"Stream:   {info.config.name}")

print(f"Subjects: {info.config.subjects}")

print(f"Messages: {info.state.messages}")
```

#### Java

```
// Fetch info for the "ORDERS" stream and print key fields

StreamInfo streamInfo = jsm.getStreamInfo("ORDERS");



StreamConfiguration config = streamInfo.getConfiguration();

StreamState state = streamInfo.getStreamState();



System.out.println("Name:     " + config.getName());

System.out.println("Subjects: " + config.getSubjects());

System.out.println("Messages: " + state.getMsgCount());
```

#### Rust

```
// Fetch the ORDERS stream and read its current info from the server.

let mut stream = js.get_stream("ORDERS").await?;

let info = stream.info().await?;



// Print the key fields: name, captured subjects, and message count.

println!("Stream name:    {}", info.config.name);

println!("Subjects:       {:?}", info.config.subjects);

println!("Message count:  {}", info.state.messages);
```

#### C#/.NET

```
// Fetch information about the ORDERS stream

var stream = await js.GetStreamAsync("ORDERS");



// Read key fields: name and subjects come from the config, the

// message count comes from the live stream state

var info = stream.Info;

var subjects = string.Join(", ", info.Config.Subjects ?? []);

output.WriteLine($"Name:     {info.Config.Name}");

output.WriteLine($"Subjects: {subjects}");

output.WriteLine($"Messages: {info.State.Messages}");
```

#### C

```
// Look up the ORDERS stream and fetch its latest info from the server.

s = js_GetStreamInfo(&si, js, "ORDERS", NULL, &jerr);

if (s == NATS_OK)

{

    int i;



    // Print key fields: name, captured subjects, and current message count.

    printf("Name:     %s\n", si->Config->Name);

    printf("Subjects:");

    for (i = 0; i < si->Config->SubjectsLen; i++)

        printf(" %s", si->Config->Subjects[i]);

    printf("\n");

    printf("Messages: %" PRIu64 "\n", si->State.Msgs);

}
```

The output has two halves.

The **configuration** half shows what you asked for and what the defaults filled in — the header plus the `Options` and `Limits` sections:

```
Information for Stream ORDERS



                     Subjects: orders.>

                     Replicas: 1

                      Storage: File



Options:



                    Retention: Limits

              Acknowledgments: true

               Discard Policy: Old

             Duplicate Window: 2m0s



Limits:



             Maximum Messages: unlimited

          Maximum Per Subject: unlimited

                Maximum Bytes: unlimited

                  Maximum Age: unlimited

         Maximum Message Size: unlimited

            Maximum Consumers: unlimited
```

The `Options` section also lists a `Direct Get` line and a run of `Allows …` feature toggles. The CLI turns direct get on by default, so that line shows here; client libraries leave it off unless you set it. They're trimmed and covered where each feature comes up.

The **state** half shows what's in the stream right now:

```
State:



                     Messages: 0

                        Bytes: 0 B

               First Sequence: 0

                Last Sequence: 0

             Active Consumers: 0
```

A new stream is empty: zero messages, zero bytes, no consumers. The first message you publish gets sequence `1`.

## The defaults

You didn't set any of the configuration values above. The server filled them in with its standard defaults, the values a stream gets whenever a field is left unset. Here is what each one means.

* **Replicas: 1**. The stream lives on one server. If that server goes down, the stream goes down with it. That's fine on a laptop, but risky in production. We come back to this on the [Surviving node loss](/learn/jetstream/surviving-node-loss.md) page.
* **Storage: File**. Messages are written to disk. The other option is memory, which is faster but lost on restart.
* **Retention: Limits**. The stream keeps messages until it hits a limit (size, age, or count). The other options are `Interest` and `WorkQueue`, which delete messages once a consumer has read them. We cover the three policies on the [Retention policies](/learn/jetstream/retention-policies.md) page.
* **Discard Policy: Old**. When the stream finally hits a limit, the oldest messages are deleted to make room. The other option is `New`, which turns away new messages when the stream is full.
* **Maximum Messages / Bytes / Age / Message Size: unlimited**. No upper bound today. On a real cluster you'd always set at least one of these. We do that on the [Shaping the stream](/learn/jetstream/shaping-the-stream.md) page.
* **Duplicate Window: 2m0s**. For two minutes after a message is stored, the server turns away a second message that carries the same [`Nats-Msg-Id`](/reference/jetstream/api/headers.md) header. This is what lets you publish the same message twice without storing it twice. The [Publishing](/learn/jetstream/publishing.md) page uses it.

The full set of stream configuration options is listed in [Reference → Create Stream](/reference/jetstream/api/stream/create.md). We use only the defaults here.

## Subjects bind to exactly one stream

Only one stream can keep a given subject. If you try to create a second stream whose subjects overlap `orders.>`, the server turns it down:

```
nats stream add ARCHIVE --subjects "orders.*" --defaults
```

```
nats: error: could not create Stream: subjects overlap with an existing stream (10065)
```

The check covers any overlap, not just the identical filter: `ORDERS` keeps `orders.>`, so a new stream asking for `orders.*`, or even the single subject `orders.created`, is turned down the same way.

This is on purpose. When a message lands on a subject, JetStream always knows which stream it goes into.

To keep overlapping subjects, you use **mirrors** and **sources**. A mirror keeps a copy of one other stream. Sources pull messages from several streams into one. The running scenario doesn't need either, so we don't set one up here. The [Mirrors and sources](/learn/jetstream/mirrors-and-sources.md) page builds both from start to finish, and [Reference → Create Stream](/reference/jetstream/api/stream/create.md) lists the `mirror` and `sources` configuration fields.

## Pitfalls

A few things catch people on a first stream.

**Unlimited defaults grow forever.** With `--defaults`, `Maximum Messages`, `Maximum Bytes`, and `Maximum Age` are all `unlimited`. The `ORDERS` stream then keeps every order it ever stored until the disk fills up, and a full disk takes the server down with it. That's fine while you're learning on a laptop, but a production stream needs at least one limit so old orders age out before the disk does. Setting limits is the [Shaping the stream](/learn/jetstream/shaping-the-stream.md) page; here the defaults are deliberately left unbounded.

**A stream name is permanent.** There's no rename. `nats stream edit` has no `--name` flag, and the server turns down any update that changes an existing stream's name with `stream configuration name must match original`. The only way to "rename" `ORDERS` is to delete it and create a new stream, which loses every order already stored. So pick the name carefully the first time. If you do outgrow a name, the safe move is to add a new stream on new subjects and let the old one age out.

## Where you are

You now have:

* an `ORDERS` stream bound to `orders.>`
* zero messages in it
* a configuration of default values

The next page, [Publishing](/learn/jetstream/publishing.md), sends the first few messages and shows what the server returns.

## See also

* [Reference → Create Stream](/reference/jetstream/api/stream/create.md): every configuration option and its valid range
* [Reference → JetStream API](/reference/jetstream/api/.md): the full list of stream and consumer operations
