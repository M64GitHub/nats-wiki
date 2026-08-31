<!-- source: https://docs.nats.io/concepts/subjects.md · fetched 2026-08-31 · section: subjects -->
# Subjects

NATS implements a subject-based messaging system where publishers and subscribers communicate through named channels called subjects. This provides a location-transparent, interest-based communication pattern that automatically routes messages across distributed NATS servers.

For a runnable, step-by-step treatment, see the [Subjects and wildcards in the Core NATS deep dive](/learn/core-nats/subjects-and-wildcards.md).

## What is a Subject?

A subject is a string of characters that forms a name which publishers and subscribers use to find each other. It acts as the address for message routing within NATS. Subjects are case-sensitive and can contain any UTF-8 characters except whitespace, tabs and line breaks. It's a good practice to use alphanumeric characters along with `-` (dash) and `_` (underscore) for readability.

**Message flow — Publish / Subscribe:** Basic publish-subscribe pattern where messages flow through the NATS server to multiple subscribers

* Publisher → NATS (subject: events.data)
* NATS → Subscriber 1 (subject: events.data)
* NATS → Subscriber 2 (subject: events.data)
* NATS → Subscriber 3 (subject: other.data)

In the animation above, `events.data` is the subject - it's the named channel that connects the publisher to all subscribers without any direct addressing.

## Subject Hierarchies

The `.` (dot) character creates a subject hierarchy, enabling logical grouping of related subjects. This hierarchical namespace helps organize your messaging architecture:

```
orders.retail.placed

orders.retail.shipped

orders.retail.returned

orders.wholesale.placed

orders.wholesale.shipped

orders.wholesale.returned
```

## Wildcards

NATS provides two wildcards for flexible subscription patterns. While publishers always send to a fully specified subject, subscribers can use wildcards to receive messages from multiple subjects.

**Message flow — Subject wildcards (animated):** Animated subject wildcards: messages on different subjects (orders.us.created, orders.eu.created, …) are routed by matching wildcard subscriptions.

* Publisher 1 → NATS (subject: orders.retail.placed)
* Publisher 2 → NATS (subject: orders.retail.shipped)
* Publisher 3 → NATS (subject: orders.wholesale.placed)
* NATS → Subscriber (subject: orders.retail.\*)
* NATS → Subscriber

The subscriber with pattern `orders.retail.*` receives messages from matching subjects (green and blue paths) but not from non-matching subjects (red path). The `*` wildcard matches exactly one token.

### Single Token Wildcard (`*`)

The `*` wildcard matches exactly one token. For example:

* `orders.retail.*` matches:

  * `orders.retail.placed`
  * `orders.retail.shipped`
  * `orders.retail.returned`

* `orders.*.placed` matches:

  * `orders.retail.placed`
  * `orders.wholesale.placed`

#### CLI

```
# Subscribe using single token wildcard.

# Since each sub waits indefinitely, try each sub

# in a different terminal or just repeat the

# publishes for each sub.

nats sub "orders.*.shipped"

nats sub "orders.*.placed"

nats sub "orders.retail.*"



# Publish to specific subjects (use a different terminal)

nats pub orders.wholesale.placed "Order W73737"

nats pub orders.retail.placed "Order R65432"

nats pub orders.wholesale.shipped "Order W73001"

nats pub orders.retail.shipped "Order R65321"
```

#### JavaScript/TypeScript

```
async function process(subject: string) {

  const sub = nc.subscribe(subject);

  const label = `[${subject}]`.padEnd(20);

  for await (const msg of sub) {

    console.log(`${label}${msg.string()}  (${msg.subject})`);

  }

}



process("orders.*.shipped").catch(console.error);

process("orders.*.placed").catch(console.error);

process("orders.retail.*").catch(console.error);



// Publish to specific subjects

nc.publish("orders.wholesale.placed", "Order W73737");

nc.publish("orders.retail.placed", "Order R65432");

nc.publish("orders.wholesale.shipped", "Order W73001");

nc.publish("orders.retail.shipped", "Order R65321");
```

#### Go

```
// Subscribe with single token wildcard

nc.Subscribe("orders.*.shipped", func(m *nats.Msg) {

	fmt.Printf("[orders.*.shipped]  %s  (%s)\n", string(m.Data), m.Subject)

})



nc.Subscribe("orders.*.placed", func(m *nats.Msg) {

	fmt.Printf("[orders.*.placed]   %s  (%s)\n", string(m.Data), m.Subject)

})



nc.Subscribe("orders.retail.*", func(m *nats.Msg) {

	fmt.Printf("[orders.retail.*]   %s  (%s)\n", string(m.Data), m.Subject)

})



// Publish to specific subjects

nc.Publish("orders.wholesale.placed", []byte("Order W73737"))

nc.Publish("orders.retail.placed", []byte("Order R65432"))

nc.Publish("orders.wholesale.shipped", []byte("Order W73001"))

nc.Publish("orders.retail.shipped", []byte("Order R65321"))
```

#### Python

```
# Subscribe to shipped orders

sub_shipped = await nc.subscribe("orders.*.shipped")



# Subscribe to placed orders

sub_placed = await nc.subscribe("orders.*.placed")



# Subscribe to retail orders

sub_retail = await nc.subscribe("orders.retail.*")



async def reader(sub, label):

    async for msg in sub:

        print(f"[{label:<18}] {msg.data.decode()}  ({msg.subject})")



asyncio.create_task(reader(sub_shipped, "orders.*.shipped"))

asyncio.create_task(reader(sub_placed, "orders.*.placed"))

asyncio.create_task(reader(sub_retail, "orders.retail.*"))



await nc.flush()



# Publish to specific subjects

await nc.publish("orders.wholesale.placed", b"Order W73737")

await nc.publish("orders.retail.placed", b"Order R65432")

await nc.publish("orders.wholesale.shipped", b"Order W73001")

await nc.publish("orders.retail.shipped", b"Order R65321")
```

#### Java

```
// Subscribe to the shipped orders

Dispatcher dShipped = nc.createDispatcher(msg -> {

    System.out.printf("[orders.*.shipped]  %s  (%s)\n", new String(msg.getData()),  msg.getSubject());

});

dShipped.subscribe("orders.*.shipped");



Dispatcher dPlaced = nc.createDispatcher(msg -> {

    System.out.printf("[orders.*.placed]   %s  (%s)\n", new String(msg.getData()),  msg.getSubject());

});

dPlaced.subscribe("orders.*.placed");



// Subscribe to the retail orders

Dispatcher dRetail = nc.createDispatcher(msg -> {

    System.out.printf("[orders.retail.*]   %s  (%s)\n", new String(msg.getData()),  msg.getSubject());

});

dRetail.subscribe("orders.retail.*");



// Publish messages to the various subjects

nc.publish("orders.wholesale.placed", "Order W73737".getBytes());

nc.publish("orders.retail.placed", "Order R65432".getBytes());

nc.publish("orders.wholesale.shipped", "Order W73001".getBytes());

nc.publish("orders.retail.shipped", "Order R65321".getBytes());
```

#### Rust

```
// Subscribe with single token wildcard

let mut sub1 = client.subscribe("orders.*.shipped").await?;

tokio::spawn(async move {

    while let Some(msg) = sub1.next().await {

        println!(

            "[orders.*.shipped]  {}  ({})",

            String::from_utf8_lossy(&msg.payload),

            msg.subject

        );

    }

});



let mut sub2 = client.subscribe("orders.*.placed").await?;

tokio::spawn(async move {

    while let Some(msg) = sub2.next().await {

        println!(

            "[orders.*.placed]   {}  ({})",

            String::from_utf8_lossy(&msg.payload),

            msg.subject

        );

    }

});



let mut sub3 = client.subscribe("orders.retail.*").await?;

tokio::spawn(async move {

    while let Some(msg) = sub3.next().await {

        println!(

            "[orders.retail.*]   {}  ({})",

            String::from_utf8_lossy(&msg.payload),

            msg.subject

        );

    }

});



// Publish to specific subjects

client

    .publish("orders.wholesale.placed", "Order W73737".into())

    .await?;

client

    .publish("orders.retail.placed", "Order R65432".into())

    .await?;

client

    .publish("orders.wholesale.shipped", "Order W73001".into())

    .await?;

client

    .publish("orders.retail.shipped", "Order R65321".into())

    .await?;
```

#### C#/.NET

```
// Subscribe to the shipped orders

_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<string>("orders.*.shipped"))

    {

        output.WriteLine($"[orders.*.shipped] {msg.Data,-12} ({msg.Subject})");

    }

});



_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<string>("orders.*.placed"))

    {

        output.WriteLine($"[orders.*.placed]  {msg.Data,-12} ({msg.Subject})");

    }

});



// Subscribe to the retail orders

_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<string>("orders.retail.*"))

    {

        output.WriteLine($"[orders.retail.*]  {msg.Data,-12} ({msg.Subject})");

    }

});



// Give the subscription tasks time to start before publishing

await Task.Delay(1000);



// Publish to specific subjects

await client.PublishAsync("orders.wholesale.placed", "Order W73737");

await client.PublishAsync("orders.retail.placed", "Order R65432");

await client.PublishAsync("orders.wholesale.shipped", "Order W73001");

await client.PublishAsync("orders.retail.shipped", "Order R65321");
```

#### C

```
// Print which subscription pattern (passed as the closure) got the message

static void

onOrderMsg(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    printf("%s%.*s  (%s)\n",

           (const char*) closure,

           natsMsg_GetDataLength(msg),

           natsMsg_GetData(msg),

           natsMsg_GetSubject(msg));

    natsMsg_Destroy(msg);

}

    // Subscribe with single token wildcards

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&shipped, conn, "orders.*.shipped",

                                     onOrderMsg, (void*) "[orders.*.shipped]  ");

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&placed, conn, "orders.*.placed",

                                     onOrderMsg, (void*) "[orders.*.placed]   ");

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&retail, conn, "orders.retail.*",

                                     onOrderMsg, (void*) "[orders.retail.*]   ");



    // Publish to specific subjects

    if (s == NATS_OK)

        s = natsConnection_PublishString(conn, "orders.wholesale.placed", "Order W73737");

    if (s == NATS_OK)

        s = natsConnection_PublishString(conn, "orders.retail.placed", "Order R65432");

    if (s == NATS_OK)

        s = natsConnection_PublishString(conn, "orders.wholesale.shipped", "Order W73001");

    if (s == NATS_OK)

        s = natsConnection_PublishString(conn, "orders.retail.shipped", "Order R65321");
```

### Multi-Token Wildcard (`>`)

The `>` wildcard matches one or more tokens and can only appear at the end of a subject. If your domain is like this:

```
sensor.alarm.smoke                   # unqualified

sensor.alarm.smoke.critical          # qualified

sensor.alarm.water

sensor.alarm.water.critical
```

The `>` wildcard matches one or more tokens and can only appear at the end of a subject. For example, `sensor.>` matches all sensor subjects

#### CLI

```
# Subscribe using single token wildcard.

# Since each sub waits indefinitely, try each sub

# in a different terminal or just repeat the

# publishes for each sub.

nats sub "sensor.alarm.*"

nats sub "sensor.*.*.critical"

nats sub "sensor.>"



# Publish to specific subjects (use a different terminal)

nats pub sensor.alarm.smoke "kitchen,14:22"

nats pub sensor.alarm.smoke.critical "kitchen,14:23"

nats pub sensor.alarm.water "basement,16:42"

nats pub sensor.alarm.water.critical "basement,16:43"
```

#### JavaScript/TypeScript

```
async function process(subject: string) {

  const sub = nc.subscribe(subject);

  const label = `[${subject}]`.padEnd(23);

  for await (const msg of sub) {

    console.log(`${label}${msg.string().padEnd(15)} (${msg.subject})`);

  }

}



// Subscribe to all alarms

process("sensor.alarm.*").catch(console.error);



// Subscribe to all critical

process("sensor.*.*.critical").catch(console.error);



// Subscribe to everything

process("sensor.>").catch(console.error);



// Publish to specific subjects

nc.publish("sensor.alarm.smoke", "kitchen,14:22");

nc.publish("sensor.alarm.smoke.critical", "kitchen,14:23");

nc.publish("sensor.alarm.water", "basement,16:42");

nc.publish("sensor.alarm.water.critical", "basement,16:43");
```

#### Go

```
// Subscribe to all alarms

nc.Subscribe("sensor.alarm.*", func(m *nats.Msg) {

	fmt.Printf("[sensor.alarm.*]       %-15s (%s)\n", string(m.Data), m.Subject)

})



// Subscribe to all critical

nc.Subscribe("sensor.*.*.critical", func(m *nats.Msg) {

	fmt.Printf("[sensor.*.*.critical]  %-15s (%s)\n", string(m.Data), m.Subject)

})



// Subscribe to everything

nc.Subscribe("sensor.>", func(m *nats.Msg) {

	fmt.Printf("[sensor.>]             %-15s (%s)\n", string(m.Data), m.Subject)

})



// Publish to specific subjects

nc.Publish("sensor.alarm.smoke", []byte("kitchen,14:22"))

nc.Publish("sensor.alarm.smoke.critical", []byte("kitchen,14:23"))

nc.Publish("sensor.alarm.water", []byte("basement,16:42"))

nc.Publish("sensor.alarm.water.critical", []byte("basement,16:43"))
```

#### Python

```
# Subscribe to all alarms

sub_alarm = await nc.subscribe("sensor.alarm.*")



# Subscribe to all critical

sub_critical = await nc.subscribe("sensor.*.*.critical")



# Subscribe to everything under sensor

sub_all = await nc.subscribe("sensor.>")



async def reader(sub, label):

    async for msg in sub:

        print(f"[{label:<22}] {msg.data.decode():<15} ({msg.subject})")



asyncio.create_task(reader(sub_alarm, "sensor.alarm.*"))

asyncio.create_task(reader(sub_critical, "sensor.*.*.critical"))

asyncio.create_task(reader(sub_all, "sensor.>"))



await nc.flush()



# Publish to specific subjects

await nc.publish("sensor.alarm.smoke", b"kitchen,14:22")

await nc.publish("sensor.alarm.smoke.critical", b"kitchen,14:23")

await nc.publish("sensor.alarm.water", b"basement,16:42")

await nc.publish("sensor.alarm.water.critical", b"basement,16:43")
```

#### Java

```
public static void main(String[] args) {

    try (Connection nc = Nats.connect("nats://localhost:4222")) {



        // Subscribe to all alarms

        Dispatcher dShipped = nc.createDispatcher(msg -> {

            System.out.printf("[sensor.alarm.*]        %-15s (%s)\n", new String(msg.getData()),  msg.getSubject());

        });

        dShipped.subscribe("sensor.alarm.*");



        // Subscribe to the all critical

        Dispatcher dPlaced = nc.createDispatcher(msg -> {

            System.out.printf("[sensor.*.*.critical]   %-15s (%s)\n", new String(msg.getData()),  msg.getSubject());

        });

        dPlaced.subscribe("sensor.*.*.critical");



        // Subscribe to everything

        Dispatcher dRetail = nc.createDispatcher(msg -> {

            System.out.printf("[sensor.>]              %-15s (%s)\n", new String(msg.getData()),  msg.getSubject());

        });

        dRetail.subscribe("sensor.>");



        // Publish messages to the various subjects

        nc.publish("sensor.alarm.smoke", "kitchen,14:22".getBytes());

        nc.publish("sensor.alarm.smoke.critical", "kitchen,14:23".getBytes());

        nc.publish("sensor.alarm.water", "basement,16:42".getBytes());

        nc.publish("sensor.alarm.water.critical", "basement,16:43".getBytes());
```

#### Rust

```
// Subscribe to all alarms

let mut sub1 = client.subscribe("sensor.alarm.*").await?;

tokio::spawn(async move {

    while let Some(msg) = sub1.next().await {

        println!(

            "[sensor.alarm.*]       {:15} ({})",

            String::from_utf8_lossy(&msg.payload),

            msg.subject

        );

    }

});



// Subscribe to the all critical

let mut sub2 = client.subscribe("sensor.*.*.critical").await?;

tokio::spawn(async move {

    while let Some(msg) = sub2.next().await {

        println!(

            "[sensor.*.*.critical]  {:15} ({})",

            String::from_utf8_lossy(&msg.payload),

            msg.subject

        );

    }

});



// Subscribe to everything

let mut sub3 = client.subscribe("sensor.>").await?;

tokio::spawn(async move {

    while let Some(msg) = sub3.next().await {

        println!(

            "[sensor.>]             {:15} ({})",

            String::from_utf8_lossy(&msg.payload),

            msg.subject

        );

    }

});



// Publish to specific subjects

client

    .publish("sensor.alarm.smoke", "kitchen,14:22".into())

    .await?;

client

    .publish("sensor.alarm.smoke.critical", "kitchen,14:23".into())

    .await?;

client

    .publish("sensor.alarm.water", "basement,16:42".into())

    .await?;

client

    .publish("sensor.alarm.water.critical", "basement,16:43".into())

    .await?;
```

#### C#/.NET

```
// Subscribe to all non-critical alarms

_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<string>("sensor.alarm.*"))

    {

        output.WriteLine($"[sensor.alarm.*]      {msg.Data,-15} ({msg.Subject})");

    }

});



// Subscribe to all critical

_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<string>("sensor.*.*.critical"))

    {

        output.WriteLine($"[sensor.*.*.critical] {msg.Data,-15} ({msg.Subject})");

    }

});



// Subscribe to everything

_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<string>("sensor.>"))

    {

        output.WriteLine($"[sensor.>]            {msg.Data,-15} ({msg.Subject})");

    }

});



// Give the subscription tasks time to start before publishing

await Task.Delay(1000);



// Publish to specific subjects

await client.PublishAsync("sensor.alarm.smoke", "kitchen,14:22");

await client.PublishAsync("sensor.alarm.smoke.critical", "kitchen,14:23");

await client.PublishAsync("sensor.alarm.water", "basement,16:42");

await client.PublishAsync("sensor.alarm.water.critical", "basement,16:43");
```

#### C

```
// Print which subscription pattern (passed as the closure) got the message

static void

onSensorMsg(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    printf("%s%-15.*s (%s)\n",

           (const char*) closure,

           natsMsg_GetDataLength(msg),

           natsMsg_GetData(msg),

           natsMsg_GetSubject(msg));

    natsMsg_Destroy(msg);

}

    // Subscribe to all alarms

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&alarms, conn, "sensor.alarm.*",

                                     onSensorMsg, (void*) "[sensor.alarm.*]       ");



    // Subscribe to all critical

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&critical, conn, "sensor.*.*.critical",

                                     onSensorMsg, (void*) "[sensor.*.*.critical]  ");



    // Subscribe to everything

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&all, conn, "sensor.>",

                                     onSensorMsg, (void*) "[sensor.>]             ");



    // Publish to specific subjects

    if (s == NATS_OK)

        s = natsConnection_PublishString(conn, "sensor.alarm.smoke", "kitchen,14:22");

    if (s == NATS_OK)

        s = natsConnection_PublishString(conn, "sensor.alarm.smoke.critical", "kitchen,14:23");

    if (s == NATS_OK)

        s = natsConnection_PublishString(conn, "sensor.alarm.water", "basement,16:42");

    if (s == NATS_OK)

        s = natsConnection_PublishString(conn, "sensor.alarm.water.critical", "basement,16:43");
```

### Wildcard Comparison

You can combine wildcards for more complex patterns and compare how `*` and `>` wildcards behave differently:

Comparing `*` (single token) vs `>` (multiple tokens) wildcards

Press enter or space to select a node. You can then use the arrow keys to move the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it or escape to cancel.

**Subject**

**sensor.alarm.\***

**sensor.\*.\*.critical**

**sensor.>**

**sensor.alarm.smoke**

✓

✗ (too few tokens)

✓

**sensor.alarm.smoke.critical**

✗ (too many tokens)

✓

✓

**sensor.alarm.water**

✓

✗ (too few tokens)

✓

**sensor.alarm.water.critical**

✗ (too many tokens)

✓

✓

The visualization demonstrates:

* **Single token wildcard** `*`: Matches exactly one token, as in `sensor.alarm.*` and `sensor.*.*.critical`
* **Multi-token wildcard** `>`: Matches one or more tokens, as in `sensor.>`

## Subject Naming Conventions

### Recommended Characters

* **Alphanumeric**: `a-z`, `A-Z`, `0-9`
* **Special**: `-` (dash) and `_` (underscore)
* **Delimiter**: `.` (dot) for hierarchy

### Reserved Characters

* `.` (dot) - Used for hierarchy, cannot be part of a token
* `*` (asterisk) - Wildcard, cannot be in subject names
* `>` (greater than) - Wildcard, cannot be in subject names
* Whitespace - Not allowed in subjects

### Reserved Prefixes

Subjects starting with `$` are reserved for system use:

* `$SYS` - System subjects
* `$JS` - JetStream API subjects
* `$KV` - Key-Value store subjects
* `$O` - Object Store subjects
* `$SRV` - Service API subjects
* `_INBOX` - Auto-generated reply subjects

## Best Practices

### Subject Hierarchy Design

1. **Start general, get specific**: Use the first tokens for broad categorization

   ```
   app.region.service.entity.action

   myapp.us-east.users.profile.update
   ```

2. **Keep it reasonable**: Limit to \~16 tokens and under 256 characters total

3. **Be consistent**: Establish naming conventions early and stick to them

4. **Plan for wildcards**: Design hierarchies that work well with wildcard subscriptions

### Performance Considerations

* **Subjects Interest graph is in-memory and dynamic**: NATS builds a routing table only for subjects with active subscribers, kept entirely in RAM for fast lookups
* **Subjects are essentially free**: Creating new subjects has virtually no overhead - NATS efficiently handles millions of unique subjects.
* **Wildcard matching is optimized**: Subscriptions with wildcards (`*` and `>`) use efficient trie-based matching.

### Security and Filtering

Well-designed subject hierarchies enable:

* Fine-grained access control per user/account
* Efficient message filtering in JetStream streams
* Clean import/export patterns between accounts
* Logical organization for monitoring and debugging

## Location Transparency

One of NATS' key features is location transparency through subject-based addressing:

* Subscriptions automatically propagate across the NATS cluster
* Messages route to all interested subscribers regardless of their location
* No configuration needed for message routing between servers
* Publishers and subscribers don't need to know about each other's location

## Wire Taps and Monitoring

The `>` wildcard enables powerful monitoring capabilities:

#### CLI

```
# Monitor all messages in the system (subject to permissions)

nats sub ">"



# Monitor all orders

nats sub "orders.>"



# Monitor specific service communications

nats sub "myservice.>"
```

#### JavaScript/TypeScript

```
// Create a wire tap for monitoring

const sub = nc.subscribe(">");

(async () => {

  for await (const msg of sub) {

    console.log(`[MONITOR] ${msg.subject}: ${msg.string()}`);

  }

})().catch(console.error);
```

#### Go

```
// Create a wire tap for monitoring

nc.Subscribe(">", func(m *nats.Msg) {

	fmt.Printf("[MONITOR] %s: %s\n", m.Subject, string(m.Data))

})
```

#### Python

```
# Create a wire tap for monitoring - subscribe to everything

sub = await nc.subscribe(">")

received = asyncio.Event()

seen = 0



async def monitor():

    nonlocal seen

    async for msg in sub:

        seen += 1

        print(f"[MONITOR] {msg.subject} --> {msg.data.decode()}")

        if seen >= 3:

            received.set()



asyncio.create_task(monitor())

await nc.flush()



# Publish a message to various subjects

await nc.publish("hello", b"Hello NATS!")

await nc.publish("event.new", b"click")

await nc.publish("weather.north.fr", "Temperature: 11°C".encode())



print("Waiting for messages...")

await received.wait()
```

#### Java

```
// Asynchronous subscribers require a dispatcher

// Subscribe to everything

CountDownLatch latch = new CountDownLatch(3);

Dispatcher dEverything = nc.createDispatcher(msg -> {

    latch.countDown();

    System.out.println("[MONITOR] " +

        msg.getSubject() + " --> " +

        new String(msg.getData(), StandardCharsets.UTF_8));

});

dEverything.subscribe(">");
```

#### Rust

```
// Create a wire tap for monitoring

let mut sub = client.subscribe(">").await?;



tokio::spawn(async move {

    while let Some(msg) = sub.next().await {

        println!(

            "[MONITOR] {}: {}",

            msg.subject,

            String::from_utf8_lossy(&msg.payload)

        );

    }

});



// Publish to a few subjects so the monitor has something to print

client.publish("orders.new", "Order 1".into()).await?;

client

    .publish("sensor.alarm.smoke", "kitchen".into())

    .await?;

client

    .publish("billing.invoice.paid", "INV-42".into())

    .await?;
```

#### C#/.NET

```
// Wire tap: subscribe to everything for monitoring

await foreach (var msg in client.SubscribeAsync<string>(">"))

{

    output.WriteLine($"[MONITOR] {msg.Subject}: {msg.Data}");

}
```

#### C

```
// Print every message that flows through the server

static void

onMonitorMsg(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    printf("[MONITOR] %s: %.*s\n",

           natsMsg_GetSubject(msg),

           natsMsg_GetDataLength(msg),

           natsMsg_GetData(msg));

    natsMsg_Destroy(msg);

}

    // Create a wire tap for monitoring

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&sub, conn, ">", onMonitorMsg, NULL);
```

## Related Concepts

* [Publish-Subscribe Basics](/concepts/pub-sub-basics.md) - Core messaging patterns
* [Request-Reply](/concepts/request-reply.md) - Synchronous communication using subjects
* [Queue Groups](/concepts/queue-groups.md) - Load balancing with subject subscriptions

## Try It Yourself

Experiment with subjects using the NATS CLI:

```
# Terminal 1: Subscribe with wildcards

nats sub "demo.>"



# Terminal 2: Publish to various subjects

nats pub demo.test "Hello"

nats pub demo.test.nested "Nested message"

nats pub demo.another.topic "Another topic"
```

Each message published in Terminal 2 will be received by the wildcard subscription in Terminal 1, demonstrating how subject hierarchies and wildcards work together.

## Next steps

* [Subjects and wildcards in the Core NATS deep dive](/learn/core-nats/subjects-and-wildcards.md) — runnable, step-by-step walkthrough
* [Subject-based authorization](/learn/security/authorization.md) — control access by subject pattern
