<!-- source: https://docs.nats.io/learn/services/scaling.md · fetched 2026-08-31 · section: scaling -->
# Scaling

`OrderInventory` answers every request, reports its endpoints through discovery, and keeps per-endpoint stats. So far one instance does all of that. This page runs more than one.

This page assumes you've read the [Core NATS](/learn/core-nats/.md) deep dive: you know how [request-reply](/learn/core-nats/request-reply.md) and [queue groups](/learn/core-nats/queue-groups.md) work. Scaling needs nothing on top of that. The framework already put every endpoint into a queue group when you created the service (you saw this happen on the [first page](/learn/services/your-first-service.md)). That queue group is the entire scaling story. You start more copies of the service, and the server spreads requests across them.

This page teaches two things: how running N instances load-balances with no extra configuration, and how to stop an instance without dropping the work it's holding.

## Run more instances

**Horizontal scaling** means running more than one copy of the same service. Each copy is an **instance**: one running service with its own service ID. All instances of `OrderInventory` share the same service name and the same version; only the auto-generated service ID differs.

You don't register instances anywhere. You don't configure a load balancer. You start a second instance the same way you started the first, with the same `Name`, `Version`, and endpoint. The framework auto-generates a fresh service ID and the new instance joins the work.

What makes the requests spread is the **default queue group `"q"`**. Every endpoint joins it unless you override it. When several instances subscribe to `orders.inventory.check` under the same queue group, the server delivers each request to exactly one member of that group. With two instances, one incoming request is handled by one of them. This is the queue-group behavior from Core NATS, now applied automatically across instances; the mechanics live on [Queue groups](/learn/core-nats/queue-groups.md).

Start a second instance, send a burst of orders, and watch them spread:

#### CLI

```
#!/bin/bash

# Scale OrderInventory by running more instances. There is no scaling

# command and no coordinator to register with: you start another copy of

# the same service, with the same Name, Version, and endpoint, and the

# framework does the rest. Each copy gets its own service ID but shares the

# name OrderInventory and the default queue group "q".

#

# The CLI has no flag to host this shape (`nats service serve` only runs a

# demo echo service), so start the second instance by running your service

# program again, in another terminal, while the first is still up.



# With two instances up, send a burst of requests. --count sends the

# request six times; because both instances joined the queue group "q",

# the server delivers each one to a single instance, so the six spread

# across the two without any extra config.

nats service request OrderInventory check \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}' \

  --count 6



# Confirm both instances are answering. `nats service stats` aggregates

# the per-instance counters by name, so num_requests across the two

# instances should add up to the six requests you just sent.

nats service stats OrderInventory
```

#### C

```
// A second instance is the same AddService call again: same Name,

// Version, and endpoint. The framework hands it a fresh service ID,

// and its check endpoint joins the same queue group "q".

if (err == NULL)

    err = micro_AddService(&svc2, conn2, &svcCfg);



// Send a burst of orders. The server delivers each request to exactly

// one member of the queue group, so the six spread across the two

// instances without any extra configuration.

const char *order = "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

                    "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}";

natsMsg    *reply = NULL;

natsStatus rs     = NATS_OK;

int        i;



for (i = 0; (err == NULL) && (rs == NATS_OK) && (i < 6); i++)

{

    rs = natsConnection_RequestString(&reply, conn,

                                      "orders.inventory.check", order, 2000);

    if (rs == NATS_OK)

    {

        natsMsg_Destroy(reply);

        reply = NULL;

    }

}



// Each instance keeps its own counters; the two totals add up to six.

microServiceStats *stats1 = NULL;

microServiceStats *stats2 = NULL;



if (err == NULL)

    err = microService_GetStats(&stats1, svc1);

if (err == NULL)

    err = microService_GetStats(&stats2, svc2);

if (err == NULL)

    printf("instance 1 handled %" PRId64 ", instance 2 handled %" PRId64 "\n",

           stats1->Endpoints[0].NumRequests,

           stats2->Endpoints[0].NumRequests);
```

Six requests across two instances land roughly three and three. The split isn't a round-robin you control: the server delivers each message to whichever queue-group member is ready. Add a third instance and the same six spread three ways. No coordinator decides this; the queue group does it on the server, per request.

**Message flow — Scaling a service with a queue group (animated):** Five OrderInventory instances share the queue group q and all subscribe to orders.inventory.check. Each request is delivered to exactly one instance, and across rounds the server spreads the requests over different members. Adding instances to the same queue group scales the service with no change on the client side.

* client → nats-server

The animation shows five `OrderInventory` instances sharing queue group `"q"`. Each request lights exactly one instance, and the next request can light a different one. That's the whole scaling model: more members in the same group, with one delivery per request.

Disabling the queue group breaks this. You met `WithEndpointQueueGroupDisabled` on [endpoints and groups](/learn/services/endpoints-and-groups.md): with it, an endpoint subscribes plainly instead of joining a group, so every instance receives every request. That's broadcast rather than scaling: it's useful for fan-out work, but wrong for load balancing. Keep the queue group on when you want to scale.

## Stop an instance cleanly

Scaling up is only part of the job. Scaling down (or rolling out a new version, or shutting an instance for maintenance) means stopping an instance. Stopping it abruptly drops any request it was mid-handle.

The framework gives you a graceful stop. Calling `Stop()` on a service **drains** each endpoint subscription: it removes the endpoint's queue-group interest right away, so the server stops routing new requests to this instance, then unsubscribes the `$SRV` discovery verbs. Requests the instance already accepted keep processing in the background. `Stop()` returns before that background processing finishes, so don't exit the process the moment it returns: keep the instance alive (drain the connection, or wait on the framework's `DoneHandler`) until the in-flight work completes, or you drop it after all.

Because the endpoint leaves the queue group as part of the stop, the remaining instances pick up every new request automatically. There's no window where a request lands on a queue group whose only member just vanished. Stop one instance and the others absorb the load:

#### CLI

```
#!/bin/bash

# Stop one instance gracefully. A graceful stop drains the endpoint

# subscriptions: it removes the instance's queue-group interest so the

# server stops routing new requests to it, lets requests already accepted

# finish processing, and unsubscribes the $SRV discovery verbs, so the

# instance disappears cleanly instead of dropping work on the floor.

#

# This is a client-library behavior: your service calls Stop() (svc.Stop()).

# There is no CLI equivalent. Ctrl-C on `nats service serve` closes the

# connection abruptly, with no drain, which is the failure mode to avoid.

# Stop the instance from your own service, then use the CLI to confirm the

# result.



# After stopping one instance, discovery reflects the new count. PING

# returns one reply per running instance, so a name that had two

# instances now answers with one.

nats service ping OrderInventory



# The remaining instance keeps answering. Send another order to confirm

# the queue group now routes every request to the one that is left.

nats service request OrderInventory check \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'
```

#### C

```
// Stop the first instance gracefully. Stop drains the endpoint

// subscriptions: the instance leaves queue group "q" so no new

// requests route to it, requests it already accepted finish, and the

// $SRV discovery verbs unsubscribe.

err = microService_Stop(svc1);



// The queue group rebalanced: every new order now lands on the

// remaining instance.

const char *order = "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

                    "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}";

natsMsg    *reply = NULL;



s = natsConnection_RequestString(&reply, conn, "orders.inventory.check",

                                 order, 2000);

if (s == NATS_OK)

{

    printf("survivor answered: %.*s\n",

           natsMsg_GetDataLength(reply), natsMsg_GetData(reply));

    natsMsg_Destroy(reply);

}
```

After the stop, a PING returns one fewer reply, and `nats service stats` aggregates the survivors. Roll a new version by starting fresh instances, then stopping the old ones one at a time; at every moment at least one instance is in the queue group answering orders.

When a service needs durable state to survive a stop (a count that must not reset, a queue of work that must outlive the process), that state doesn't belong in the instance. A service stores nothing; it's at-most-once request-reply. Put durable state behind [JetStream](/learn/jetstream/.md). Draining the connection itself on shutdown, beyond the framework's `Stop()`, belongs to [resilient clients](/learn/resilient-clients/.md).

You'll find the full set of service lifecycle and queue-group fields in [Reference](/reference/.md). We only need the behavior here.

## Pitfalls

Scaling out turns one easy-to-miss assumption into a bug: that only one instance is running. Each instance runs the same handler on its own connection, and they don't share memory. Two problems follow from that.

**Instances don't share memory — protect external state.** If a handler increments a counter, caches a value, or reserves stock in a local variable, each instance keeps its own copy. Run three instances and each one has its own independent counter, its own cache, and its own view of "remaining stock," and they drift apart. Don't assume one instance holds the correct value. Keep handlers stateless, and when work genuinely needs shared state, push it into an external store: a database, or a [JetStream](/learn/jetstream/.md) stream or key-value bucket that all instances read and write through. The instances stay interchangeable; the state lives in one place that all of them use.

**A blocking handler stops its instance from serving other requests.** Handlers run synchronously on the service's connection. While one handler blocks (a slow database call, a sleep, a lock it can't get), that instance answers no other request. The queue group masks this for a while by sending requests to the busy instance's peers instead, but if every instance blocks, the whole service stalls. Don't do slow work inline in a handler. Keep handlers fast, move long work off the request path, and add more instances so the rest absorb a momentary stall on one.

The fix for both is the same: instances are disposable, so make stopping one safe. A graceful stop drains in-flight work and hands new requests to the survivors, which is what you want when an instance is slow, overloaded, or being replaced. Stop one and the rest carry on:

#### CLI

```
#!/bin/bash

# Stop one instance gracefully. A graceful stop drains the endpoint

# subscriptions: it removes the instance's queue-group interest so the

# server stops routing new requests to it, lets requests already accepted

# finish processing, and unsubscribes the $SRV discovery verbs, so the

# instance disappears cleanly instead of dropping work on the floor.

#

# This is a client-library behavior: your service calls Stop() (svc.Stop()).

# There is no CLI equivalent. Ctrl-C on `nats service serve` closes the

# connection abruptly, with no drain, which is the failure mode to avoid.

# Stop the instance from your own service, then use the CLI to confirm the

# result.



# After stopping one instance, discovery reflects the new count. PING

# returns one reply per running instance, so a name that had two

# instances now answers with one.

nats service ping OrderInventory



# The remaining instance keeps answering. Send another order to confirm

# the queue group now routes every request to the one that is left.

nats service request OrderInventory check \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'
```

#### C

```
// Stop the first instance gracefully. Stop drains the endpoint

// subscriptions: the instance leaves queue group "q" so no new

// requests route to it, requests it already accepted finish, and the

// $SRV discovery verbs unsubscribe.

err = microService_Stop(svc1);



// The queue group rebalanced: every new order now lands on the

// remaining instance.

const char *order = "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

                    "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}";

natsMsg    *reply = NULL;



s = natsConnection_RequestString(&reply, conn, "orders.inventory.check",

                                 order, 2000);

if (s == NATS_OK)

{

    printf("survivor answered: %.*s\n",

           natsMsg_GetDataLength(reply), natsMsg_GetData(reply));

    natsMsg_Destroy(reply);

}
```

If the request after the stop still gets an answer, the queue group rebalanced cleanly and no order was dropped.

## Where you are

You now have:

* More than one `OrderInventory` instance, all sharing the name, version, and default queue group `"q"`.
* Requests spreading across instances with no coordinator: one delivery per request, decided on the server.
* A graceful `Stop()` that drains in-flight work and leaves the queue group, so the survivors absorb the load with nothing dropped.

Scaling up means running more instances and letting the queue group balance the load. Scaling down means stopping one instance cleanly so the rest pick up its work.

## What's next

That's the framework end to end: a named, versioned service with endpoints and groups, made discoverable and observable through `$SRV`, and scaled by running more instances. The last page recaps all of this and points to where the remaining details live.

Continue to [Where to go next](/learn/services/where-next.md).

## See also

* [Queue groups](/learn/core-nats/queue-groups.md) — the load-balancing mechanism the default queue group `"q"` is built on.
* [JetStream](/learn/jetstream/.md) — durable state for work that must survive an instance stopping.
* [Reference](/reference/.md) — the full set of service lifecycle and queue-group configuration fields.
