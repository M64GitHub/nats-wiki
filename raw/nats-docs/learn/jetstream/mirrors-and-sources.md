<!-- source: https://docs.nats.io/learn/jetstream/mirrors-and-sources.md · fetched 2026-08-31 · section: mirrors-and-sources -->
# Mirrors and sources

So far the running example has been a single `ORDERS` stream.

This page covers the two ways to build one stream from another. A **mirror** is a read-only copy of a single stream. Sources aggregate many streams into one.

Both behaviors are specified in [ADR-59](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-59.md), the authoritative document for stream sourcing and mirroring.

## What a mirror is

A mirror is a stream that continuously copies every message from one upstream stream.

**Message flow — A mirror catches up and stays current (animated):** A mirror keeps its own copy of another stream by continuously pulling from it. ORDERS already holds five orders and a publisher keeps adding more; the mirror copies faster than the publisher writes, so its lag falls until it catches up. Once caught up, each new order is mirrored the moment it lands and the lag stays at zero.

The copy is exact. A message in the mirror keeps the same sequence number, the same timestamp, and the same subject it had upstream. If `orders.created` was sequence `1` in `ORDERS`, it's sequence `1` in the mirror too.

A mirror is read-only. You can't publish to it directly, because it listens on no subjects of its own. Its only job is to follow the upstream. A publish lands in whatever stream owns the subject, not the mirror.

A mirror keeps its own retention. The upstream might keep messages for seven days while the mirror keeps them forever — the mirror's own limits decide what it stores, independent of the upstream's.

Its configuration is fixed at creation. You can't point a mirror at a different upstream or add a filter later; to change any of that you delete it and create it again. That's cheap, because the upstream still holds the data and the new mirror catches up on its own.

## What sources are

A **source** is the inverse of a mirror. Where a mirror copies from one upstream, a stream with sources pulls from several upstreams at once and merges them into a single stream.

Consider three regional order streams — `ORDERS-US`, `ORDERS-EU`, `ORDERS-APAC`. A stream that lists all three as sources becomes one combined `ALL-ORDERS` view, fed by every region.

**Message flow — Sources merge many streams into one (animated):** A sourced stream pulls from several upstreams at once into one. ALL-ORDERS sources from US, EU, and APAC; each upstream keeps its own order, and across them the messages interleave by arrival time, so one stream carries the merged flow of all three regions.

The merge interleaves. Messages from one upstream keep their own order, but across upstreams there's no ordering guarantee, and the aggregate gives them fresh sequence numbers as they arrive — it doesn't preserve each upstream's the way a mirror does.

A sourced stream can also listen on its own subjects. Unlike a mirror, it may accept direct publishes alongside the messages it pulls in, so one stream can hold both what it gathered and what was published straight to it.

Sources can also change after creation. You add an upstream, drop one, or adjust a filter by updating the stream config — no need to delete and recreate.

## Mirror or source?

The two solve different problems. A mirror is one stream copied exactly; a source is many streams merged into one.

|                                | Mirror                   | Source                            |
| ------------------------------ | ------------------------ | --------------------------------- |
| Upstreams                      | exactly one              | one or many                       |
| Sequence numbers               | kept from the upstream   | fresh, interleaved across sources |
| Own subjects, direct publishes | no — read-only           | yes, optional                     |
| Change the config later        | no — delete and recreate | yes — add, drop, or edit sources  |

Reach for a **mirror** when you want a second copy of one stream: a read replica close to a remote region, a stream that survives the loss of the upstream's cluster, or a long-retention archive of a short-retention stream.

Reach for **sources** when you want to combine many streams into one: merging per-region or per-tenant streams for reporting, or building a derived view that draws from several streams.

## Build them

### Build the ORDERS-ARCHIVE mirror

Create a second stream that mirrors `ORDERS`. Call it `ORDERS-ARCHIVE`, and give it no limits, so it becomes a permanent record of every order:

#### CLI

```
#!/bin/bash

# Create ORDERS-ARCHIVE as a read-only mirror of the ORDERS stream.

# A mirror takes no --subjects of its own; it follows the upstream.

nats stream add ORDERS-ARCHIVE --mirror ORDERS



# Confirm the mirror caught up. The Mirror Information section reports

# the upstream stream name, the replication Lag, and the Last Seen time.

nats stream info ORDERS-ARCHIVE
```

#### JavaScript/TypeScript

```
// Create ORDERS-ARCHIVE as a read-only mirror of ORDERS. A mirror takes

// no subjects of its own; it follows the upstream stream.

const jsm = await jetstreamManager(nc);

const info = await jsm.streams.add({

  name: "ORDERS-ARCHIVE",

  mirror: { name: "ORDERS" },

});

console.log(`Created mirror ${info.config.name} of ${info.config.mirror?.name}`);
```

#### Go

```
// Create ORDERS-ARCHIVE as a read-only mirror of ORDERS. A mirror takes

// no subjects of its own; it follows the upstream stream.

stream, err := js.CreateStream(ctx, jetstream.StreamConfig{

	Name:   "ORDERS-ARCHIVE",

	Mirror: &jetstream.StreamSource{Name: "ORDERS"},

})

if err != nil {

	panic(err)

}



// Confirm: the new stream mirrors ORDERS.

cfg := stream.CachedInfo().Config

fmt.Printf("Created mirror %s of %s\n", cfg.Name, cfg.Mirror.Name)
```

#### Python

```
# Create ORDERS-ARCHIVE as a read-only mirror of ORDERS. A mirror takes

# no subjects of its own; it follows the upstream stream.

info = await js.add_stream(name="ORDERS-ARCHIVE", mirror=StreamSource(name="ORDERS"))



print(f"Created mirror {info.config.name} of {info.config.mirror.name}")
```

#### Java

```
// Create ORDERS-ARCHIVE as a read-only mirror of ORDERS. A mirror

// takes no subjects of its own; it follows the upstream stream.

JetStreamManagement jsm = nc.jetStreamManagement();

StreamInfo streamInfo = jsm.addStream(StreamConfiguration.builder()

        .name("ORDERS-ARCHIVE")

        .mirror(Mirror.builder().sourceName("ORDERS").build())

        .storageType(StorageType.File)

    .build());



// Confirm: the new stream mirrors ORDERS

StreamConfiguration config = streamInfo.getConfiguration();

System.out.println("Created mirror " + config.getName()

        + " of " + config.getMirror().getSourceName());
```

#### Rust

```
// Create ORDERS-ARCHIVE as a read-only mirror of ORDERS. A mirror takes

// no subjects of its own; it follows the upstream stream.

let stream = js

    .create_stream(jetstream::stream::Config {

        name: "ORDERS-ARCHIVE".to_string(),

        mirror: Some(Source {

            name: "ORDERS".to_string(),

            ..Default::default()

        }),

        ..Default::default()

    })

    .await?;



// Confirm: the new stream mirrors ORDERS.

let cfg = &stream.cached_info().config;

println!(

    "Created mirror {} of {}",

    cfg.name,

    cfg.mirror.as_ref().map_or("unknown", |m| m.name.as_str())

);
```

#### C#/.NET

```
// Create ORDERS-ARCHIVE as a read-only mirror of ORDERS. A mirror takes

// no subjects of its own; it follows the upstream stream.

var stream = await js.CreateStreamAsync(new StreamConfig(name: "ORDERS-ARCHIVE", subjects: [])

{

    Mirror = new StreamSource { Name = "ORDERS" },

});



// Confirm: the new stream mirrors ORDERS

output.WriteLine($"Created mirror {stream.Info.Config.Name} of {stream.Info.Config.Mirror!.Name}");
```

#### C

```
// Create ORDERS-ARCHIVE as a read-only mirror of ORDERS. A mirror takes

// no subjects of its own; it follows the upstream stream.

if (s == NATS_OK)

{

    jsStreamConfig_Init(&mc);

    jsStreamSource_Init(&mirror);

    mirror.Name = "ORDERS";

    mc.Name     = "ORDERS-ARCHIVE";

    mc.Mirror   = &mirror;

    s = js_AddStream(&si, js, &mc, NULL, &jerr);

}



// Confirm: the new stream mirrors ORDERS.

if (s == NATS_OK)

    printf("Created mirror %s of %s\n", si->Config->Name, si->Config->Mirror->Name);
```

The `--mirror ORDERS` flag tells the server this new stream is a mirror of `ORDERS` rather than a normal stream. You don't give it `--subjects`, because a mirror listens on no subjects of its own. The CLI exposes only the simplest mirror; for one that filters or rewrites subjects you supply a JSON config, covered in the Reference.

Right after creation the mirror catches up. Within moments it holds the same three orders that `ORDERS` does, reported in a section a normal stream doesn't have:

```
Mirror Information:



          Stream Name: ORDERS

                  Lag: 0

            Last Seen: 1.20s
```

**Stream Name** is the upstream the mirror follows. **Lag** is how many messages it's still behind — `0` means fully caught up, and a lag that climbs and stays high means it can't keep pace. **Last Seen** is the time since the last message or heartbeat from the upstream; a small, steady value is healthy.

Publish a fourth order into `ORDERS`, then re-run `nats stream info ORDERS-ARCHIVE`. The mirror picks it up on its own, with no consumer and no client code involved, and the lag ticks back to `0`.

### Build the ALL-ORDERS source

A source needs streams to aggregate. Create three regional streams, each owning its own subjects, then create `ALL-ORDERS` to source all three at once:

#### CLI

```
#!/bin/bash

# Sources aggregate many streams into one. First, the three regional streams

# ALL-ORDERS will pull from — each owns its own subjects:

nats stream add ORDERS-US   --subjects 'us.orders.>'

nats stream add ORDERS-EU   --subjects 'eu.orders.>'

nats stream add ORDERS-APAC --subjects 'apac.orders.>'



# Create ALL-ORDERS as an aggregate of all three. A sourced stream can list

# several upstreams (a mirror takes exactly one). It needs no --subjects of

# its own.

nats stream add ALL-ORDERS --source ORDERS-US --source ORDERS-EU --source ORDERS-APAC



# Confirm. The Source Information section lists each upstream, with its own Lag.

nats stream info ALL-ORDERS



# Source Information:

#

#           Stream Name: ORDERS-US

#                   Lag: 0

#             Last Seen: 1.20s

#

#           Stream Name: ORDERS-EU

#                   Lag: 0

#             Last Seen: 1.20s

#

#           Stream Name: ORDERS-APAC

#                   Lag: 0

#             Last Seen: 1.20s
```

#### JavaScript/TypeScript

```
// Create ALL-ORDERS as an aggregate that sources the three regional streams

// into one. Unlike a mirror, a stream can list several sources.

const info = await jsm.streams.add({

  name: "ALL-ORDERS",

  sources: [

    { name: "ORDERS-US" },

    { name: "ORDERS-EU" },

    { name: "ORDERS-APAC" },

  ],

});

console.log(`Created ${info.config.name} sourcing ${info.config.sources?.length} streams`);
```

#### Go

```
// Create ALL-ORDERS as an aggregate that sources the three regional streams

// into one. Unlike a mirror, a stream can list several sources.

stream, err := js.CreateStream(ctx, jetstream.StreamConfig{

	Name: "ALL-ORDERS",

	Sources: []*jetstream.StreamSource{

		{Name: "ORDERS-US"},

		{Name: "ORDERS-EU"},

		{Name: "ORDERS-APAC"},

	},

})

if err != nil {

	panic(err)

}



cfg := stream.CachedInfo().Config

fmt.Printf("Created %s sourcing %d streams\n", cfg.Name, len(cfg.Sources))
```

#### Python

```
# Create ALL-ORDERS as an aggregate that sources the three regional streams

# into one. Unlike a mirror, a stream can list several sources.

info = await js.add_stream(

    name="ALL-ORDERS",

    sources=[

        StreamSource(name="ORDERS-US"),

        StreamSource(name="ORDERS-EU"),

        StreamSource(name="ORDERS-APAC"),

    ],

)



print(f"Created {info.config.name} sourcing {len(info.config.sources)} streams")
```

#### Java

```
// Create ALL-ORDERS as an aggregate that sources the three regional

// streams into one. Unlike a mirror, a stream can list several sources.

StreamInfo streamInfo = jsm.addStream(StreamConfiguration.builder()

        .name("ALL-ORDERS")

        .sources(

            Source.builder().sourceName("ORDERS-US").build(),

            Source.builder().sourceName("ORDERS-EU").build(),

            Source.builder().sourceName("ORDERS-APAC").build())

        .storageType(StorageType.File)

    .build());



// Confirm: the aggregate lists three sources

StreamConfiguration config = streamInfo.getConfiguration();

System.out.println("Created " + config.getName()

        + " sourcing " + config.getSources().size() + " streams");
```

#### Rust

```
// Create ALL-ORDERS as an aggregate that sources the three regional streams

// into one. Unlike a mirror, a stream can list several sources.

let stream = js

    .create_stream(jetstream::stream::Config {

        name: "ALL-ORDERS".to_string(),

        sources: Some(vec![

            Source {

                name: "ORDERS-US".to_string(),

                ..Default::default()

            },

            Source {

                name: "ORDERS-EU".to_string(),

                ..Default::default()

            },

            Source {

                name: "ORDERS-APAC".to_string(),

                ..Default::default()

            },

        ]),

        ..Default::default()

    })

    .await?;



let cfg = &stream.cached_info().config;

println!(

    "Created {} sourcing {} streams",

    cfg.name,

    cfg.sources.as_ref().map_or(0, |s| s.len())

);
```

#### C#/.NET

```
// Create ALL-ORDERS as an aggregate that sources the three regional

// streams into one. Unlike a mirror, a stream can list several sources.

var stream = await js.CreateStreamAsync(new StreamConfig(name: "ALL-ORDERS", subjects: [])

{

    Sources =

    [

        new StreamSource { Name = "ORDERS-US" },

        new StreamSource { Name = "ORDERS-EU" },

        new StreamSource { Name = "ORDERS-APAC" },

    ],

});



// Confirm: the aggregate lists three sources

output.WriteLine($"Created {stream.Info.Config.Name} sourcing {stream.Info.Config.Sources!.Count} streams");
```

#### C

```
// Create ALL-ORDERS as an aggregate that sources the three regional

// streams into one. Unlike a mirror, a stream can list several sources.

jsStreamConfig  sc;

jsStreamSource  us, eu, apac;

jsStreamSource  *sources[] = {&us, &eu, &apac};



jsStreamSource_Init(&us);

us.Name = "ORDERS-US";

jsStreamSource_Init(&eu);

eu.Name = "ORDERS-EU";

jsStreamSource_Init(&apac);

apac.Name = "ORDERS-APAC";



jsStreamConfig_Init(&sc);

sc.Name = "ALL-ORDERS";

sc.Sources = sources;

sc.SourcesLen = 3;



s = js_AddStream(&si, js, &sc, NULL, &jerr);

if (s == NATS_OK)

    printf("Created %s sourcing %d streams\n",

           si->Config->Name, si->Config->SourcesLen);
```

`ALL-ORDERS` takes no `--subjects` of its own here; it just lists its upstreams. Its info carries a Source Information section — one block per upstream, because each source replicates on its own:

```
Source Information:



          Stream Name: ORDERS-US

                  Lag: 0

            Last Seen: 1.20s



          Stream Name: ORDERS-EU

                  Lag: 0

            Last Seen: 1.20s



          Stream Name: ORDERS-APAC

                  Lag: 0

            Last Seen: 1.20s
```

Each upstream has its own Lag and Last Seen. `ALL-ORDERS` now holds every order from every region, interleaved in arrival order. Add or drop a region later by updating the stream — no recreation needed.

## Filters, transforms, and reach

A mirror or source can copy a subset of subjects with a filter, rewrite subjects with a subject transform, or reach a stream in another account or JetStream domain. Each is one extra field on the mirror or source configuration.

Reaching across an account or domain involves three subjects, each with a required export type. Setting one wrong is a common mistake — the Pitfalls below cover which type each subject needs and what goes wrong.

The full set of mirror and source options (`filter_subject`, `subject_transforms`, `opt_start_seq`, `external`, and the rest) is documented in [Reference → Stream Configuration](/reference/jetstream/api/stream/create.md). We use only the plain `--mirror` and `--source` forms here.

Using mirrors for disaster recovery (switching over to a mirror when the primary cluster is lost) is its own operational topic, covered in [Operate → Backup & Recovery](/learn/backup-recovery/mirrors-and-sources.md).

## Pitfalls

Mirrors and sources add little configuration, but a few of their rules are easy to get wrong the first time.

**Treating a mirror as writable.** A mirror listens on no subjects of its own, so no subject routes a publish to it. Publish `orders.shipped` and the message lands in the origin `ORDERS` stream that owns that subject — never in `ORDERS-ARCHIVE`. A plain publish reaches the origin unless subject mapping or a cross-domain setup redirects it, in which case it fails. Force the mirror by name with a `Nats-Expected-Stream: ORDERS-ARCHIVE` header and the server rejects the publish with `expected stream does not match` (error `10060`), because the subject still routed to `ORDERS`, not the mirror. A mirror is read-only either way: publish to the upstream `ORDERS` and let the mirror copy the message on its own.

#### CLI

```
#!/bin/bash

# A mirror is read-only. It captures no subjects of its own, so a publish

# aimed at the mirror name reaches no stream. A JetStream publish waits for

# a PubAck that never comes and fails with "no responders available".

# (A plain `nats pub` would instead report "Published N bytes" and the

# message would silently go nowhere.)

nats pub --jetstream ORDERS-ARCHIVE '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

# Published 88 bytes to "ORDERS-ARCHIVE"

# nats: error: nats: no responders available for request



# Publish to the upstream ORDERS stream instead. The mirror copies the

# message on its own, with no client code involved.

nats pub --jetstream orders.created '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

# Published 88 bytes to "orders.created"

# Stored in Stream: ORDERS Sequence: 4
```

**Treating mirror contents as real-time.** A mirror is eventually consistent: the server copies the upstream stream continuously, so the mirror can run slightly behind. During a burst of writes, its `Lag` climbs above `0` until it catches up. Don't assume a message in `ORDERS` is already in `ORDERS-ARCHIVE` the instant it lands. Read the `Lag` field first, and treat a lag that climbs and stays high as a sign the mirror can't keep pace.

#### CLI

```
#!/bin/bash

# A mirror is eventually consistent, not real-time. Read the Lag field

# before you trust the mirror to hold what the upstream just received.

# Lag 0 means fully caught up; a non-zero Lag means messages are still

# in flight from the upstream.

nats stream info ORDERS-ARCHIVE



# Mirror Information:

#

#           Stream Name: ORDERS

#                   Lag: 0

#             Last Seen: 1.20s
```

#### JavaScript/TypeScript

```
// A mirror is eventually consistent. Read its lag before trusting it to

// hold what the upstream just received: 0 means fully caught up.

const jsm = await jetstreamManager(nc);

const info = await jsm.streams.info("ORDERS-ARCHIVE");

console.log(`Upstream:  ${info.mirror?.name}`);

console.log(`Lag:       ${info.mirror?.lag}`);

console.log(`Last seen: ${info.mirror?.active} ns ago`);
```

#### Go

```
// A mirror is eventually consistent. Read its Lag before trusting it to

// hold what the upstream just received: 0 means fully caught up.

stream, err := js.Stream(ctx, "ORDERS-ARCHIVE")

if err != nil {

	panic(err)

}



info, err := stream.Info(ctx)

if err != nil {

	panic(err)

}



fmt.Printf("Upstream:  %s\n", info.Mirror.Name)

fmt.Printf("Lag:       %d\n", info.Mirror.Lag)

fmt.Printf("Last seen: %s ago\n", info.Mirror.Active)
```

#### Python

```
# A mirror is eventually consistent. Read its lag before trusting it to

# hold what the upstream just received: 0 means fully caught up.

info = await js.stream_info("ORDERS-ARCHIVE")



print(f"Upstream:  {info.mirror.name}")

print(f"Lag:       {info.mirror.lag}")

print(f"Last seen: {info.mirror.active}")
```

#### Java

```
// A mirror is eventually consistent. Read its lag before trusting

// it to hold what the upstream just received: 0 means caught up.

StreamInfo streamInfo = jsm.getStreamInfo("ORDERS-ARCHIVE");

MirrorInfo mirror = streamInfo.getMirrorInfo();



System.out.println("Upstream:  " + mirror.getName());

System.out.println("Lag:       " + mirror.getLag());

System.out.println("Last seen: " + mirror.getActive());
```

#### Rust

```
// A mirror is eventually consistent. Read its lag before trusting it to

// hold what the upstream just received: 0 means fully caught up.

let mut stream = js.get_stream("ORDERS-ARCHIVE").await?;

let info = stream.info().await?;

let Some(mirror) = info.mirror.as_ref() else {

    println!("stream is not a mirror");

    return Ok(());

};



println!("Upstream:  {}", mirror.name);

println!("Lag:       {}", mirror.lag);

println!("Last seen: {:?} ago", mirror.active);
```

#### C#/.NET

```
// A mirror is eventually consistent. Read its lag before trusting it to

// hold what the upstream just received: 0 means fully caught up.

var stream = await js.GetStreamAsync("ORDERS-ARCHIVE");

var mirror = stream.Info.Mirror!;



output.WriteLine($"Upstream:  {mirror.Name}");

output.WriteLine($"Lag:       {mirror.Lag}");

output.WriteLine($"Last seen: {mirror.Active}");
```

#### C

```
// A mirror is eventually consistent. Read its Lag before trusting it to

// hold what the upstream just received: 0 means fully caught up.

s = js_GetStreamInfo(&si, js, "ORDERS-ARCHIVE", NULL, &jerr);

if ((s == NATS_OK) && (si->Mirror != NULL))

{

    printf("Upstream:  %s\n", si->Mirror->Name);

    printf("Lag:       %" PRIu64 "\n", si->Mirror->Lag);

    printf("Last seen: %.2fs ago\n", (double) si->Mirror->Active / 1E9);

}
```

**Combining a filter with a transform on one source.** On a single source or mirror entry, you can set `filter_subject` or `subject_transforms`, but not both: the server rejects a config that sets both. Use `filter_subject` when you only need to select a subset of subjects, and `subject_transforms` when you also need to rename them (a transform filters and renames in one step). Don't reach for both fields on the same entry. Pick the one that fits.

**Cross-domain config that fails silently.** Reaching a stream in another account or JetStream domain needs the `external` block plus matching exports and imports on both sides, and each of the three subjects has a required type. The consumer API and flow-control subjects are *service* exports, because they work as request and reply. The delivery subject is a *stream* export, because the messages flow one way. Get a type wrong and replication doesn't fail with an error; the mirror never catches up. Check each import type against [Reference → Stream Configuration](/reference/jetstream/api/stream/create.md). Setting up cross-account and cross-domain access is part of configuring accounts and authorization.

## Where you are

You now have:

* an `ORDERS` stream, unchanged
* an `ORDERS-ARCHIVE` mirror — an exact, read-only copy of it
* an `ALL-ORDERS` aggregate that sources three regional streams into one

## What's next

The next page covers [reading messages directly](/learn/jetstream/get-direct.md): getting one message or a batch straight from the stream, with no consumer, served by any replica or mirror. After that, [subject mapping](/learn/jetstream/subject-mapping.md), [per-message TTL](/learn/jetstream/message-ttl.md), and [stream and consumer policies](/learn/jetstream/policies.md), then [Where to go next](/learn/jetstream/where-next.md) recaps the chapter.

## See also

* [Reference → ADR-59](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-59.md) — the authoritative spec for mirroring and sourcing behavior.
* [Reference → Stream Configuration](/reference/jetstream/api/stream/create.md) — every mirror and source field and its valid values.
* [Operate → Backup & Recovery](/learn/backup-recovery/mirrors-and-sources.md) — using mirrors for disaster recovery.
