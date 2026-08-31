<!-- source: https://docs.nats.io/learn/services/discovery.md · fetched 2026-08-31 · section: discovery -->
# Discovery

Your `OrderInventory` service answers on `orders.inventory.check`, and `ShippingQuote` answers on `shipping.quote`. To call them, you had to know those subjects in advance. This page removes that requirement.

Every service the framework creates also answers a second, automatic set of subjects: the **discovery verbs**. Through them, a caller can ask the running system what services exist, what each one answers, and how it's doing, without anyone hard-coding a subject or maintaining a registry on the side.

You add no code to get this. The moment `AddService` returned on the `your-first-service` page, the framework subscribed to these subjects for you. This page shows how to use them.

## The three discovery verbs

Discovery is **learning what services exist and what they answer** through a fixed set of subjects under the `$SRV` prefix. Every service answers three verbs there:

* **PING**: checks whether a service is present. The reply carries the service name, instance id, and version. Use it to find services and measure round-trip time.
* **INFO**: reports what a service answers. The reply adds the description and the list of endpoints, each with its subject and queue group.
* **STATS**: reports how a service is doing. The reply adds per-endpoint counters. We read those on the next page; for now, it's enough to know the verb exists.

The verbs are uppercase, and so are their subjects. A service doesn't publish to `$SRV` itself; it subscribes there and replies to your requests, the same request-reply you already know.

## Three levels of address

Each verb answers at three levels, narrowing from every service down to one instance:

| Subject                         | Who answers                           |
| ------------------------------- | ------------------------------------- |
| `$SRV.INFO`                     | every service in the account          |
| `$SRV.INFO.OrderInventory`      | every instance named `OrderInventory` |
| `$SRV.INFO.OrderInventory.<id>` | the one instance with that id         |

The same three levels work for `PING` and `STATS`. The first level is how you enumerate an unfamiliar system. The second narrows to one service name. The third reaches a single **instance**: one running copy of a service, identified by the **service id** the framework generated for it.

Ask `OrderInventory` to describe itself at the name level, and read the endpoint list out of the reply:

#### CLI

```
#!/bin/bash

# Ask the OrderInventory service to describe itself. INFO is a discovery

# verb every service answers automatically on the $SRV subject tree. The

# name level ($SRV.INFO.OrderInventory) reaches every running instance of

# OrderInventory, and each one replies with its name, id, version, and the

# list of endpoints it serves.

#

# Discovery is broadcast: a plain request would return only the first

# reply, so the CLI waits a short window and collects every responder.

# That is why the timeout matters here.

nats request '$SRV.INFO.OrderInventory' '' --replies=0 --timeout=1s



# The reply for each instance is JSON like:

#

#   {

#     "type": "io.nats.micro.v1.info_response",

#     "name": "OrderInventory",

#     "id": "JJTBR2MN3JSAYBI5ST7E32",

#     "version": "1.0.0",

#     "endpoints": [

#       { "name": "check",

#         "subject": "orders.inventory.check",

#         "queue_group": "q" }

#     ]

#   }

#

# Read the endpoints array to learn what the service answers and on which

# subject -- no documentation lookup required.

#

# The same information, formatted, comes from the CLI ops shortcut:

nats service info OrderInventory
```

#### C

```
// Ask every running instance of OrderInventory to describe itself.

// INFO is a discovery verb the framework answers automatically; the

// name level ($SRV.INFO.OrderInventory) reaches every instance, and

// each one replies with its name, id, version, and endpoint list.

//

// Discovery is broadcast: a plain request would return only the first

// reply. Subscribe to a private inbox, send the request there, and

// collect replies until none arrives within the deadline.

int instances = 0;



if (s == NATS_OK)

    s = natsInbox_Create(&inbox);

if (s == NATS_OK)

    s = natsConnection_SubscribeSync(&sub, conn, (const char *) inbox);

if (s == NATS_OK)

    s = natsConnection_PublishRequestString(conn, "$SRV.INFO.OrderInventory",

                                            (const char *) inbox, "");



while (s == NATS_OK)

{

    natsMsg *info = NULL;



    // Stop once no further instance replies within the deadline.

    s = natsSubscription_NextMsg(&info, sub, 1000);

    if (s != NATS_OK)

        break;



    // Each reply is an info_response JSON document; its "endpoints"

    // array lists each endpoint's subject and queue group.

    printf("info: %.*s\n",

           natsMsg_GetDataLength(info), natsMsg_GetData(info));

    instances++;

    natsMsg_Destroy(info);

}

printf("collected %d instance(s)\n", instances);
```

The reply tells you the `check` endpoint listens on `orders.inventory.check` in queue group `"q"`. That's the same fact you configured by hand earlier, but now any caller can read it back from the live service instead of trusting documentation.

The `$SRV.PING`/`INFO`/`STATS` wire format and JSON response schemas are documented in [Reference](/reference/services/.md). We only need the behavior here.

## Discovery is broadcast, not load-balanced

One detail on this page works differently than you might expect. The endpoints you built answer in a **queue group**, so each request goes to exactly one instance. The discovery verbs do **not**. A `$SRV.INFO.OrderInventory` request reaches *every* instance named `OrderInventory`, and every one of them replies.

That's deliberate. The point of discovery is to get a response from every instance, all three of them, not whichever one happened to answer first. So a caller doesn't wait for a single reply; it waits a short deadline and collects however many responses arrive in that window.

**Message flow — Service discovery (animated):** Service discovery, broadcast then targeted. A discovery request fans out from the client to all three OrderInventory instances, and each replies with its INFO. A second request addressed to one instance by its id reaches only that instance, id2, and only it replies with STATS. The same service subjects serve both the broadcast and the point-to-point query.

* client → server
* server → client

The animation shows it: one `$SRV.INFO.OrderInventory` request fans out to all three instances, and three INFO replies come back. The single targeted query at the end, `$SRV.STATS.OrderInventory.id2`, reaches only `id2`, because the third address level pins the request to one instance.

## Targeting one instance

When you already know an id (from a PING or INFO reply), you can address that instance alone. This is how you inspect or compare a single copy of a service that's running many.

The third level reaches exactly one instance, so you expect a single reply and don't need a deadline loop:

#### CLI

```
#!/bin/bash

# The third discovery level adds the service id, addressing exactly one

# instance instead of all of them. Use it when several instances of

# OrderInventory are running and you want to inspect one in particular.

#

# Pick an id from an earlier INFO or PING reply, then target it. Replace

# the id below with one your own service printed.

INSTANCE_ID="JJTBR2MN3JSAYBI5ST7E32"



# $SRV.STATS.OrderInventory.<id> reaches only the instance with that id,

# so a single reply is expected -- no deadline loop needed for one

# instance.

nats request "\$SRV.STATS.OrderInventory.$INSTANCE_ID" '' --timeout=1s



# PING at the instance level is the lightweight check: it confirms that

# one specific instance is alive and reports its name, id, and version.

nats request "\$SRV.PING.OrderInventory.$INSTANCE_ID" '' --timeout=1s
```

#### C

```
// The third discovery level adds the service id, addressing exactly

// one instance instead of all of them. Pick an id from an earlier

// INFO or PING reply; replace the one below with your own.

const char *instanceID = "JJTBR2MN3JSAYBI5ST7E32";

natsMsg    *reply      = NULL;

char       subject[256];



// $SRV.STATS.OrderInventory.<id> reaches only the instance with that

// id, so a single reply is expected -- no deadline loop needed.

snprintf(subject, sizeof(subject),

         "$SRV.STATS.OrderInventory.%s", instanceID);

if (s == NATS_OK)

    s = natsConnection_RequestString(&reply, conn, subject, "", 1000);

if (s == NATS_OK)

{

    printf("stats: %.*s\n",

           natsMsg_GetDataLength(reply), natsMsg_GetData(reply));

    natsMsg_Destroy(reply);

    reply = NULL;

}



// PING at the instance level is the lightweight check: it confirms

// that one specific instance is alive and reports its name, id, and

// version.

snprintf(subject, sizeof(subject),

         "$SRV.PING.OrderInventory.%s", instanceID);

if (s == NATS_OK)

    s = natsConnection_RequestString(&reply, conn, subject, "", 1000);

if (s == NATS_OK)

{

    printf("ping: %.*s\n",

           natsMsg_GetDataLength(reply), natsMsg_GetData(reply));

    natsMsg_Destroy(reply);

}
```

## Collecting replies with the CLI

For interactive use, the `nats` CLI wraps the broadcast loop. `nats service list` enumerates every service and instance it can find; `nats service info` formats one service's endpoints; `nats service ping` measures round-trip time to each responder:

```
nats service list

nats service info OrderInventory

nats service ping
```

These run the same `$SRV` requests internally and gather the replies by deadline. They're the fastest way to see what's running while you develop; the programmatic verbs above are what your own tooling uses.

## Pitfalls

Two mistakes are common the first time you query discovery. Both come from the broadcast behavior above.

**Discovery is broadcast: a single reply is not the whole answer.** A plain request returns the first response and stops. Against `$SRV.INFO.OrderInventory` that gives you one instance and silently hides the rest, so five running instances appear as one. Don't treat a discovery request like a normal request-reply call. Wait a deadline and collect every reply, exactly as the CLI does:

#### CLI

```
#!/bin/bash

# Ask the OrderInventory service to describe itself. INFO is a discovery

# verb every service answers automatically on the $SRV subject tree. The

# name level ($SRV.INFO.OrderInventory) reaches every running instance of

# OrderInventory, and each one replies with its name, id, version, and the

# list of endpoints it serves.

#

# Discovery is broadcast: a plain request would return only the first

# reply, so the CLI waits a short window and collects every responder.

# That is why the timeout matters here.

nats request '$SRV.INFO.OrderInventory' '' --replies=0 --timeout=1s



# The reply for each instance is JSON like:

#

#   {

#     "type": "io.nats.micro.v1.info_response",

#     "name": "OrderInventory",

#     "id": "JJTBR2MN3JSAYBI5ST7E32",

#     "version": "1.0.0",

#     "endpoints": [

#       { "name": "check",

#         "subject": "orders.inventory.check",

#         "queue_group": "q" }

#     ]

#   }

#

# Read the endpoints array to learn what the service answers and on which

# subject -- no documentation lookup required.

#

# The same information, formatted, comes from the CLI ops shortcut:

nats service info OrderInventory
```

#### C

```
// Ask every running instance of OrderInventory to describe itself.

// INFO is a discovery verb the framework answers automatically; the

// name level ($SRV.INFO.OrderInventory) reaches every instance, and

// each one replies with its name, id, version, and endpoint list.

//

// Discovery is broadcast: a plain request would return only the first

// reply. Subscribe to a private inbox, send the request there, and

// collect replies until none arrives within the deadline.

int instances = 0;



if (s == NATS_OK)

    s = natsInbox_Create(&inbox);

if (s == NATS_OK)

    s = natsConnection_SubscribeSync(&sub, conn, (const char *) inbox);

if (s == NATS_OK)

    s = natsConnection_PublishRequestString(conn, "$SRV.INFO.OrderInventory",

                                            (const char *) inbox, "");



while (s == NATS_OK)

{

    natsMsg *info = NULL;



    // Stop once no further instance replies within the deadline.

    s = natsSubscription_NextMsg(&info, sub, 1000);

    if (s != NATS_OK)

        break;



    // Each reply is an info_response JSON document; its "endpoints"

    // array lists each endpoint's subject and queue group.

    printf("info: %.*s\n",

           natsMsg_GetDataLength(info), natsMsg_GetData(info));

    instances++;

    natsMsg_Destroy(info);

}

printf("collected %d instance(s)\n", instances);
```

The reverse holds too: when you want one specific instance, use the `$SRV.STATS.OrderInventory.<id>` level instead of filtering a broadcast. It reaches that instance directly and returns one reply.

**`$SRV` is a reserved subject prefix: do not publish to it yourself.** The framework owns the entire `$SRV` tree; services subscribe there to answer PING, INFO, and STATS. Publishing your own messages under `$SRV` collides with that machinery and corrupts what callers discover. Keep your own subjects under your own prefixes (`orders.*`, `shipping.*`) and let the framework own `$SRV`. Who may even see `$SRV` across account boundaries is a separate question, covered in [Security](/learn/security/.md).

## Where you are

You can now discover the system instead of memorizing it. With `$SRV` PING, INFO, and STATS, you can enumerate every service in the account, ask one service which endpoints it answers, and target a single instance by its id. You also know the catch: discovery is broadcast, so you gather replies by deadline rather than taking the first one.

`OrderInventory` and `ShippingQuote` are still running. Nothing about them changed; you just learned to ask them what they are.

## What's next

INFO told you *what* a service answers. The STATS verb tells you *how it's doing*: request counts, error counts, and processing time per endpoint. The next page reads those counters and shows how a handler records an error.

Continue to [Observability](/learn/services/observability.md).

## See also

* [Request-reply](/learn/core-nats/request-reply.md) — the mechanism every `$SRV` reply rides on.
* [Observability](/learn/services/observability.md) — what the STATS verb reports and how to read it.
* [Reference](/reference/services/.md) — the `$SRV` wire format and response schemas.
