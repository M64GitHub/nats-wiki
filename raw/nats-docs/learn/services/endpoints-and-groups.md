<!-- source: https://docs.nats.io/learn/services/endpoints-and-groups.md · fetched 2026-08-31 · section: endpoints-and-groups -->
# Endpoints and groups

The previous page gave you a running `OrderInventory` service with exactly one endpoint, `check`, answering on `orders.inventory.check`. That's the smallest useful shape: one service, one handler, one subject.

Real services rarely stay that small. A service usually answers more than one kind of request, and once it does you want those subjects organized rather than scattered. This page adds the two pieces that do that: a service can hold multiple endpoints, and a group gives a set of endpoints a shared subject prefix.

By the end you'll have a second service, `ShippingQuote`, alongside `OrderInventory`, and you'll know how to lay out several endpoints under one prefix.

## A service can hold multiple endpoints

An **endpoint** is a named handler on a subject. You met one on the last page; nothing stops a service from having several. Each call to `AddEndpoint(name, handler)` registers another named handler, and the endpoint's subject **defaults to its name**.

Add a second service the same way you added the first. `ShippingQuote` promotes the Core NATS `shipping.quote` providers into a named service. It has one endpoint, `quote`, and because you want it to answer on `shipping.quote` rather than on the bare name `quote`, you set the subject explicitly:

#### CLI

```
#!/bin/bash

# Add a second service alongside OrderInventory.

#

# A service is created by your client library, not by the CLI: the

# library call is AddService(Name: "ShippingQuote", Version: "1.0.0")

# with one endpoint named "quote" whose subject is set to

# "shipping.quote". The CLI does not create endpoints; it talks to the

# services your code runs. This snippet shows the second service once it

# is running, the way every other language tab creates it.



# With ShippingQuote running, send a request to its endpoint. The

# service answers on shipping.quote, independent of OrderInventory.

nats service request ShippingQuote quote \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'



# Confirm both services are now visible. Two independent services run

# against the same nats-server, each with its own name, version, and

# auto-generated service ID.

nats service list
```

#### C

```
// The quote handler: read the order, answer with a shipping quote.

static microError *

onQuote(microRequest *req)

{

    const char *quote = "{\"carrier\":\"carrier-a\",\"quote_cents\":1500}";



    return microRequest_Respond(req, quote, strlen(quote));

}

    // A second service alongside OrderInventory. ShippingQuote promotes

    // the Core NATS shipping.quote providers into a named service: one

    // endpoint, "quote", answering on shipping.quote. Because the wire

    // subject differs from the endpoint name, set the subject explicitly.

    microServiceConfig svcConfig = {

        .Name        = "ShippingQuote",

        .Version     = "1.0.0",

        .Description = "Quotes shipping for an order",

    };

    microEndpointConfig quoteConfig = {

        .Name    = "quote",

        .Subject = "shipping.quote",

        .Handler = onQuote,

    };



    if (err == NULL)

        err = micro_AddService(&svc, conn, &svcConfig);

    if (err == NULL)

        err = microService_AddEndpoint(svc, &quoteConfig);
```

Two services now run against the same `nats-server`. `OrderInventory` answers on `orders.inventory.check`; `ShippingQuote` answers on `shipping.quote`. Each is independent, with its own name, its own version, and its own discovery. The framework gave each a unique service ID without you asking.

When the subject should match the endpoint name, you can omit it. An endpoint named `quote` with no subject set answers on `quote`. You set the subject explicitly only when the wire subject and the endpoint name differ, which is the common case once subjects carry structure like `orders.inventory.check`.

The handler contract is unchanged from the last page: you read the request with `req.Data()` and reply with `req.Respond()`. Adding endpoints doesn't change how a single request is served; it only adds more named handlers to the same running service.

## A group is a subject prefix

Once a service grows past one endpoint, the subjects start to repeat. Two inventory endpoints would naturally be `orders.inventory.check` and `orders.inventory.reserve`: the same `orders.inventory` stem, twice. A **group** captures that stem once.

`AddGroup("orders.inventory")` returns a group, and any endpoint you add to that group answers on `{group}.{endpoint}`. An endpoint named `check` inside the `orders.inventory` group answers on `orders.inventory.check`; an endpoint named `reserve` answers on `orders.inventory.reserve`. You write the prefix once and the framework joins it to each endpoint name.

#### CLI

```
#!/bin/bash

# Organize endpoints under a group subject prefix.

#

# Grouping is a library call: AddGroup("orders.inventory") returns a

# group, and an endpoint named "check" added to that group answers on

# {group}.{endpoint} = orders.inventory.check. The CLI does not build

# groups; it sends to the subject the group produced. This snippet shows

# that the grouped endpoint answers on the joined subject, exactly as the

# other language tabs construct it.



# The grouped "check" endpoint answers on orders.inventory.check — the

# group prefix joined to the endpoint name. A caller only needs the

# subject; it never sees whether a group built it.

nats service request OrderInventory check \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'



# Read back the service to see each endpoint's resolved subject. The

# subject column shows orders.inventory.check, the group prefix applied.

nats service info OrderInventory
```

#### C

```
// A group captures the shared subject prefix once. Every endpoint

// added to the group answers on {group}.{endpoint}, so "check" ends

// up on orders.inventory.check without repeating the stem.

microGroup       *inventory       = NULL;

microGroupConfig groupConfig      = {

    .Prefix = "orders.inventory",

};

microEndpointConfig checkConfig   = {

    .Name    = "check",

    .Handler = onCheck,

};



if (err == NULL)

    err = microService_AddGroup(&inventory, svc, &groupConfig);

if (err == NULL)

    err = microGroup_AddEndpoint(inventory, &checkConfig);
```

The subject a caller sends to is always `{group}.{endpoint}`. There's no separate routing layer; the group is just a way to build the subject. A client that knows the subject doesn't need to know whether the endpoint was added directly or through a group. The wire looks identical either way.

Groups also nest. A group added inside another group combines both prefixes, so the subject becomes `{outer}.{inner}.{endpoint}`. You rarely need more than one level for a service this size, but the prefixes stack the way you'd expect.

## A group can set the queue group

Every endpoint joins a **queue group**, the load-balancing group that makes the server deliver each request to exactly one member. The default name is `"q"`, and you've been using it without touching it: all instances of `OrderInventory` share `"q"`, so a request goes to one of them, not all of them. The queue group mechanism itself lives in [Core NATS](/learn/core-nats/queue-groups.md); here it's just the default a service endpoint already uses.

The queue group is set at three levels, and each level overrides the one above it. The service sets a default. A group can override it for every endpoint under it. A single endpoint can override it again. If none of them set anything, the endpoint falls back to `"q"`.

You override the queue group on an endpoint with one option. Here `check` joins a custom queue group instead of the default `"q"`:

#### CLI

```
#!/bin/bash

# Override the queue group on one endpoint.

#

# The queue group is a library setting on the endpoint: the option

# WithEndpointQueueGroup("q-inventory") makes "check" load-balance in

# its own group instead of the service default "q". The CLI does not set

# queue groups; it sends requests that the server delivers to one member

# of whatever group the endpoint joined. This snippet shows the observable

# result, the way the other language tabs configure the override.



# Send a request to the check endpoint. Whether check uses the default

# "q" or a custom queue group, the caller behavior is identical: the

# server delivers the request to exactly one instance in that group and

# one reply comes back.

nats service request OrderInventory check \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'



# Inspect the endpoint to confirm its queue group. The info output lists

# each endpoint with its subject and queue group, so you can verify the

# override took effect.

nats service info OrderInventory
```

#### C

```
// Override the queue group on one endpoint. Instead of the service

// default "q", check load-balances in its own group "q-inventory":

// instances sharing that group split check requests among themselves,

// separately from any other endpoint.

microEndpointConfig checkConfig = {

    .Name       = "check",

    .Subject    = "orders.inventory.check",

    .QueueGroup = "q-inventory",

    .Handler    = onCheck,

};



if (err == NULL)

    err = microService_AddEndpoint(svc, &checkConfig);
```

Most services never need this. The default `"q"` already load-balances all instances of a service against each other, which is what you want almost every time. Reach for an override only when you want a subset of endpoints to load-balance separately. The full set of endpoint and group options is documented in [Reference](/reference/.md). We only need the behavior here.

**Message flow — Service endpoints (animated):** One service exposes two endpoints, and the request subject picks which one runs. A request to orders.inventory.check reaches the check endpoint directly. The quote endpoint sits inside a shipping group, so its subject is prefixed to shipping.quote — the group adds a subject prefix in front of the endpoints it holds.

* client → server
* server → inventory svc
* inventory svc → check (subject: orders.inventory.check)
* inventory svc → quote (subject: shipping.quote)

The animation isolates the routing rule. It puts two endpoints on one service, `check` on `orders.inventory.check` and a grouped `quote` on `shipping.quote`, and shows the subject on each request selecting the handler: a request to `orders.inventory.check` runs `check`, a request to `shipping.quote` runs `quote`, and only the endpoint whose subject matches runs. In this chapter those two subjects belong to two separate services, `OrderInventory` and `ShippingQuote`, but the selection rule is identical when one service hosts several endpoints.

## Pitfalls

Endpoints and groups have two common pitfalls: one about the queue group, and one about what can't be undone.

**Disabling the queue group turns an endpoint into broadcast.** Overriding the queue group changes *who* load-balances with whom. Disabling it entirely is a sharper change: an endpoint with no queue group is a plain subscription, so **every instance** receives **every** request instead of one instance receiving each. For a request-reply endpoint that means the caller gets one reply per instance and the rest are noise. Do not disable the queue group to "make sure a request is handled": that's exactly what the default `"q"` already guarantees, with one handler, not N. Disable it only when you genuinely want all instances to act, which is rare for a service that responds.

You control this with one option. Override the queue group when you want a subset of endpoints to load-balance separately; never disable it on an endpoint that responds. Send a request and inspect the endpoint to confirm which queue group it joined (the default `"q"`, an override, or none):

#### CLI

```
#!/bin/bash

# Override the queue group on one endpoint.

#

# The queue group is a library setting on the endpoint: the option

# WithEndpointQueueGroup("q-inventory") makes "check" load-balance in

# its own group instead of the service default "q". The CLI does not set

# queue groups; it sends requests that the server delivers to one member

# of whatever group the endpoint joined. This snippet shows the observable

# result, the way the other language tabs configure the override.



# Send a request to the check endpoint. Whether check uses the default

# "q" or a custom queue group, the caller behavior is identical: the

# server delivers the request to exactly one instance in that group and

# one reply comes back.

nats service request OrderInventory check \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'



# Inspect the endpoint to confirm its queue group. The info output lists

# each endpoint with its subject and queue group, so you can verify the

# override took effect.

nats service info OrderInventory
```

#### C

```
// Override the queue group on one endpoint. Instead of the service

// default "q", check load-balances in its own group "q-inventory":

// instances sharing that group split check requests among themselves,

// separately from any other endpoint.

microEndpointConfig checkConfig = {

    .Name       = "check",

    .Subject    = "orders.inventory.check",

    .QueueGroup = "q-inventory",

    .Handler    = onCheck,

};



if (err == NULL)

    err = microService_AddEndpoint(svc, &checkConfig);
```

**Endpoints are immutable once added.** There's no remove. You can't detach an endpoint, rename it, or change its subject on a running service. The same holds for the metadata you attach to a service or endpoint: it's fixed at creation. If a service's shape needs to change, you stop it and start a new one with the new layout. Decide the endpoint names and subjects before the service goes live, deliberately and the first time, the same way you pick a stream name in JetStream.

You handle this by inspecting the shape, not editing it. Read back the running service to see exactly which endpoints, subjects, and queue groups it registered; to change any of them, stop the service and start a replacement:

#### CLI

```
#!/bin/bash

# Endpoints are fixed once a service is running — inspect, then restart to change.

#

# There is no library call to remove, rename, or re-subject an endpoint:

# AddEndpoint only appends, and the subject, queue group, and metadata are

# set at creation. The CLI cannot detach an endpoint either; it can only

# read the shape your code registered. This snippet shows how to inspect

# the running layout and confirms there is no remove operation — the way

# every language tab treats endpoints as immutable.



# Read back the service to see the exact endpoints it registered: each name,

# its resolved subject, and its queue group. This is the layout your code

# fixed at AddEndpoint time; nothing here can be edited in place.

nats service info OrderInventory



# There is no "nats service remove-endpoint" — endpoints cannot be detached

# from a running service. To change the shape, stop the service in your code

# (svc.Stop()) and start a new one with the new endpoint names and subjects.

nats service list
```

#### C

```
// Endpoints are immutable once added: there is no remove, rename, or

// re-subject on a running service. Read the shape back to see exactly

// which endpoints, subjects, and queue groups it registered.

microServiceInfo *info = NULL;



if (err == NULL)

    err = microService_GetInfo(&info, svc);

if (err == NULL)

{

    for (int i = 0; i < info->EndpointsLen; i++)

        printf("endpoint %s on %s (queue group %s)\n",

               info->Endpoints[i].Name,

               info->Endpoints[i].Subject,

               info->Endpoints[i].QueueGroup);

    microServiceInfo_Destroy(info);

}



// To change the layout, stop the service and start a replacement

// with the new shape -- here check plus a new reserve endpoint.

microEndpointConfig reserveConfig = {

    .Name    = "reserve",

    .Subject = "orders.inventory.reserve",

    .Handler = onReserve,

};

microService *replacement = NULL;



if (err == NULL)

    err = microService_Stop(svc);

if (err == NULL)

    err = micro_AddService(&replacement, conn, &svcConfig);

if (err == NULL)

    err = microService_AddEndpoint(replacement, &checkConfig);

if (err == NULL)

    err = microService_AddEndpoint(replacement, &reserveConfig);
```

## Where you are

You now have:

* Two services running against one `nats-server`: `OrderInventory` answering on `orders.inventory.check`, and `ShippingQuote` answering on `shipping.quote`.
* The shape to add more endpoints to either, with subjects that default to the endpoint name.
* A group to give related endpoints a shared subject prefix, and the three levels at which a queue group can be set.

Both services still do exactly what their Core NATS responders did. They've only gained structure: names, subjects, and the framework's load-balancing default underneath.

## What's next

Two services are running, each with its own name and endpoints. The next page asks the server what's out there: the `$SRV` discovery verbs let any client learn which services exist, what endpoints they expose, and which instances are answering.

Continue to [Discovery](/learn/services/discovery.md).

## See also

* [Queue groups](/learn/core-nats/queue-groups.md) — how the load-balancing group under every endpoint actually works.
* [Scatter-gather](/learn/core-nats/scatter-gather.md) — the request pattern the `ShippingQuote` providers used before becoming a named service.
* [Reference](/reference/.md) — the full set of endpoint and group configuration options.
