<!-- source: https://docs.nats.io/learn/services/your-first-service.md · fetched 2026-08-31 · section: your-first-service -->
# Your first service

In the Core NATS chapter you built an inventory responder. It subscribed to `orders.inventory.check`, read each request, and published an answer back. It worked, but it was anonymous: nothing on the network knew its name, its version, or which subjects it served.

This page promotes that responder into a **service**: the same answering behavior, now wrapped by the micro framework so it gains a name, a version, and a built-in identity. The bytes on the wire stay the same. The responder becomes a first-class thing the network can name and, on later pages, discover, observe, and scale.

You need a local `nats-server` running and you should already be comfortable with [request-reply](/learn/core-nats/request-reply.md). This page covers the two things the framework adds on top of how a reply finds its way back, rather than re-teaching that.

## A service is a named responder

A **service** is a request-reply responder that the framework formalizes. You create one by calling `AddService` with three values: a `Name`, a `Version`, and a `Description`. The framework takes those, opens the necessary subscriptions, and hands you back a handle to manage it.

The `Name` is shared by every copy of this service you ever run. Here it is `OrderInventory`. The `Version` is a SemVer string, `1.0.0` for our first cut. The `Description` is free text for humans.

When you create the service, the framework also generates a unique **service ID** for this one running copy, an auto-generated NUID like `IcpremQQGTYS0fK1iyfQ86`. You never set it. The **service name** identifies the kind of service; the **service ID** identifies this one instance of it. That distinction is what later lets you run five copies of `OrderInventory` and still talk to exactly one of them.

A service on its own answers nothing yet. It needs an **endpoint**: a named handler bound to a subject. This is where the inventory logic lives. Add one endpoint, `check`, on the subject `orders.inventory.check` (the same subject the Core NATS responder used) and give it the handler that answers the in-stock question.

#### CLI

```
#!/bin/bash

# Create the OrderInventory service. This is a client-library call, not a

# CLI one: your code calls AddService(Name: "OrderInventory",

# Version: "1.0.0", Description: ...) and then AddEndpoint("check", handler)

# with the subject set to "orders.inventory.check". The framework opens the

# subscriptions, joins the endpoint to the default queue group "q", and

# subscribes the discovery verbs under $SRV.

#

# The CLI cannot host this shape: `nats service serve` only runs a demo

# echo service on <name>.echo, not a named endpoint on a subject you choose.

# So start OrderInventory from your service program, then use the CLI to

# talk to it. With the service running, read its registration back:

nats service info OrderInventory
```

#### C

```
// The check endpoint handler: the same answering behavior as the raw

// responder. The framework already read the reply subject off the

// incoming request; Respond sends the answer back to it.

static microError *

handleCheck(microRequest *req)

{

    const char *answer = "{\"in_stock\":true,\"warehouse\":\"us-east\"}";



    return microRequest_Respond(req, answer, strlen(answer));

}

    // Promote the responder into a service: a Name, a SemVer Version, and

    // a Description. The "check" endpoint binds the handler to

    // orders.inventory.check and joins the default queue group "q".

    microEndpointConfig checkCfg = {

        .Name    = "check",

        .Subject = "orders.inventory.check",

        .Handler = handleCheck,

    };

    microServiceConfig svcCfg = {

        .Name        = "OrderInventory",

        .Version     = "1.0.0",

        .Description = "Checks whether an order's items are in stock",

        .Endpoint    = &checkCfg,

    };



    err = micro_AddService(&svc, conn, &svcCfg);

    if (err == NULL)

    {

        printf("OrderInventory 1.0.0 answering on orders.inventory.check\n");

        // Block until the service stops.

        err = microService_Run(svc);

    }
```

Two details matter. First, the endpoint joins the framework's default **queue group**, `"q"`, automatically. That's the same queue group mechanism from [Core NATS](/learn/core-nats/queue-groups.md): if you run more than one copy of this service, each request goes to exactly one of them. You get load balancing for free, and the [scaling](/learn/services/scaling.md) page builds on it.

Second, creating the service quietly subscribes it to a set of **discovery** subjects under `$SRV`: the verbs that let callers find it and read its stats. You don't see them here; the [discovery](/learn/services/discovery.md) page is where they are used. For now, know that they exist the moment the service starts.

The full set of service configuration fields and their valid ranges is documented in [Reference](/reference/.md). We only need the behavior here.

## The handler contract

Inside an endpoint, the **handler** is the function that processes a request. Its contract is the request-reply you already know, with the framework managing the connection. Each request hands you a request object. You read the incoming bytes with `Data()` and you send the answer with `Respond()`.

That covers the whole shape, `Data()` to read and `Respond()` to answer. The framework took care of subscribing on `orders.inventory.check`, joining the queue group, reading the reply subject off the incoming message, and publishing your answer to it. The handler doesn't touch a reply subject or an inbox; the framework does, the same work the raw responder performed manually.

With the service running, a caller asks the same question as before. The `order-svc` client sends the canonical order payload to the `check` endpoint and waits for one reply:

#### CLI

```
#!/bin/bash

# Ask the OrderInventory service whether an order's item is in stock.

# `nats service request` looks the service up by name, resolves the

# endpoint's subject from its discovery info, sends the order payload,

# and prints the reply.

#

# The arguments are the service name, the endpoint name, and the payload.

# Underneath it is plain request-reply: a private reply subject, the

# request out on the endpoint's subject, and one answer back.

nats service request OrderInventory check \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'
```

#### C

```
// Ask the OrderInventory service whether the order's item is in stock.

// Underneath it is plain request-reply: a private reply subject, the

// request out on the check endpoint's subject, and one answer back.

const char *order = "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

                    "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}";

natsMsg    *reply = NULL;



s = natsConnection_RequestString(&reply, conn, "orders.inventory.check",

                                 order, 2000);

if (s == NATS_OK)

{

    printf("OrderInventory replied: %.*s\n",

           natsMsg_GetDataLength(reply), natsMsg_GetData(reply));

    natsMsg_Destroy(reply);

}
```

The request travels to `orders.inventory.check`, the framework routes it into the `check` endpoint's queue subscription, your handler runs, and the response flows back to the caller's reply subject. Here's the round trip with the framework wrapper in place:

**Message flow — Service request / reply (animated):** A single request to a micro service. order-svc sends a request on orders.inventory.check; NATS routes it to the OrderInventory service's check endpoint, which belongs to queue group q. The handler runs and its reply travels back through NATS to the caller's \_INBOX. To the client it is an ordinary request/reply.

* order-svc → NATS (subject: orders.inventory.check)
* NATS → OrderInventory
* OrderInventory → NATS (subject: \_INBOX reply)
* NATS → order-svc (subject: reply)

The orange arrow is the request out on `orders.inventory.check`. The green arrow is the answer coming back. Underneath, it's plain request-reply over a queue group; the framework gave the responder a name and an identity.

## Pitfalls

Two mistakes are common when building your first service. Both are about validation: the framework names your responder and sets up its subscriptions, but it doesn't validate the data that flows through it.

**Validate the request body; never let bad input crash the handler.** The framework hands your handler whatever bytes the caller sent. If your handler blindly parses them and the caller sent garbage, the parse fails and, depending on the language, the handler can panic, return nothing, or leave the caller waiting out a timeout. Don't assume the payload is well-formed. Parse it, and on failure respond with a **service error** instead: a response that carries `Nats-Service-Error` and a `Nats-Service-Error-Code` header whose value is always safe to parse as a number (use `400` for bad input). The caller then sees a clear "bad request" rather than a hang, and the service stays up for the next caller.

Send a deliberately malformed body and watch the service answer with the error rather than fall over:

#### CLI

```
#!/bin/bash

# Pitfall demo: send a malformed body to the running OrderInventory service.

# A handler that validates its input parses req.Data() and, on failure,

# responds with a service error carrying the Nats-Service-Error and

# Nats-Service-Error-Code (400) headers instead of crashing or hanging.

#

# The default output prints the reply headers, so you can see the error

# headers the handler returned. The caller still gets a clear answer back,

# those headers tell it the request was bad, and the service stays up for

# the next caller.

nats service request OrderInventory check 'not-json'
```

#### C

```
// Validate the request body before using it. On bad input the handler

// returns a service error: the framework attaches the Nats-Service-Error

// and Nats-Service-Error-Code headers to the response and the service

// stays up for the next caller.

static microError *

handleCheck(microRequest *req)

{

    const char *data   = microRequest_GetData(req);

    int         len    = microRequest_GetDataLength(req);

    const char *answer = "{\"in_stock\":true,\"warehouse\":\"us-east\"}";



    // A real handler parses the JSON; the point is to reject garbage

    // instead of letting it crash the parse.

    if ((len == 0) || (data[0] != '{'))

        return micro_ErrorfCode(400, "invalid order: body is not JSON");



    return microRequest_Respond(req, answer, strlen(answer));

}

    // Send a deliberately malformed body. The service answers with the

    // error headers rather than falling over; the caller reads them on

    // the reply.

    natsMsg *reply = NULL;



    s = natsConnection_RequestString(&reply, conn, "orders.inventory.check",

                                     "not-json", 2000);

    if (s == NATS_OK)

    {

        const char *code = NULL;

        const char *desc = NULL;



        natsMsgHeader_Get(reply, "Nats-Service-Error-Code", &code);

        natsMsgHeader_Get(reply, "Nats-Service-Error", &desc);

        if (code != NULL)

            printf("service error %s: %s\n", code, desc);

        natsMsg_Destroy(reply);

    }
```

The full mechanics of reading that error code back live on the [observability](/learn/services/observability.md#pitfalls) page; here the point is only that the handler must produce it.

**A service `Name` and `Version` are validated at creation.** The `Name` must match the framework's character rule (letters, digits, hyphens, underscores; no dots or spaces), and the `Version` must be valid SemVer. A `Name` of `Order Inventory` (with a space) or a `Version` of `v1` (not SemVer) fails the `AddService` call outright; the service never starts. Don't discover this in production: pick a valid `Name` and a real SemVer `Version` (`1.0.0`) the first time. The same goes for any `Metadata` you attach. It's immutable once set, so there's no editing it after creation; you stop the service and start a new one. The full character rules are in [Reference](/reference/.md).

## Where you are

The Acme world now has its first real service:

* `OrderInventory`, version `1.0.0`, with a unique service ID assigned by the framework.
* One endpoint, `check`, answering on `orders.inventory.check` in the default queue group `"q"`.
* The same in-stock behavior as the Core NATS responder, now named and wrapped, plus discovery subscriptions running quietly under `$SRV`.

Nothing about the payload or the subject changed; the responder became a service.

## What's next

One service with one endpoint is the smallest useful shape. Real services expose several endpoints and organize them under subject prefixes called groups. The next page adds a second endpoint and a second service.

Continue to [Endpoints and groups](/learn/services/endpoints-and-groups.md).

## See also

* [Core NATS → Request-reply](/learn/core-nats/request-reply.md) — how the reply actually finds its way back, which this page assumes.
* [Core NATS → Queue groups](/learn/core-nats/queue-groups.md) — the default `"q"` group that an endpoint joins.
* [Reference](/reference/.md) — every service configuration field and its valid range.
