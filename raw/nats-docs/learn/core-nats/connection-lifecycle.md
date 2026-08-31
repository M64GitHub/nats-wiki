<!-- source: https://docs.nats.io/learn/core-nats/connection-lifecycle.md · fetched 2026-08-31 · section: connection-lifecycle -->
# Connection lifecycle

The [Connecting](/learn/core-nats/connecting.md) page opened a client's connection: the handshake, a connection name, and the heartbeats that tell client and server the link is still alive. A connection doesn't stay up forever, though. The server it's attached to restarts, or a network blip cuts the socket, and the connection drops.

This page answers one question: what happens to your client, and to your messages, when that drop happens. The client handles most of it for you. Knowing exactly what it does, and what it can't do, tells you which failures you can ignore and which you have to design around.

Two ideas carry the page. First, the client owns reconnection: it re-dials and rebuilds its own state without your help. Second, you watch the whole lifecycle through a few callbacks. After that, two shorter sections point at where the tuning and hardening live, in the [Resilient clients](/learn/resilient-clients/.md) chapter.

## The client owns reconnection

When the socket drops, the client reconnects for you rather than surfacing the failure and stopping. It re-dials a server, replays the connect handshake, and re-sends every subscription it had, so messages start flowing again. This is on by default in every client library.

The client has to re-send its subscriptions because the server keeps no per-client memory. A subscription exists only as an entry in the server's in-memory interest graph, tied to one socket. When that socket dies the entry is gone, and to the server the reconnecting client is a brand-new connection. So a packer's interest in `orders.created` isn't restored by the server; the client library restores it by subscribing again.

That leaves the messages, and the client treats the ones you send and the ones you'd receive very differently.

The publishes *you* make while disconnected are held. A publish call during the gap doesn't fail; the client writes it to a **reconnect buffer**, an outbound queue that keeps your publishes during the outage and flushes them, in order, once the link returns. That buffer is bounded (8 MB by default), and a publish that would overflow it returns an error rather than growing without limit. Sizing it, and handling that overflow, belongs to [Reconnection](/learn/resilient-clients/reconnection.md).

The messages *other* publishers send while you're away are gone, and no buffer on your side can change that. Core NATS is [at-most-once](/learn/core-nats/publish-subscribe.md#at-most-once-delivery): while your subscription is missing, an `orders.created` message from another service finds no interest to match, so the server discards it. When you reconnect your subscription is back, but that message was never kept and isn't coming.

That gap is the reason to reach for a server-side store when missed messages actually matter, such as an order that must be handled even if the subscriber was restarting. That store is [JetStream](/learn/jetstream/.md), the layer this chapter stops short of.

## Observing the lifecycle

A connection moves through states a single publish or subscribe call never shows you: CONNECTED, then RECONNECTING after a drop, then CONNECTED again, and eventually CLOSED. To see those transitions you register **lifecycle callbacks** when you open the connection, functions the client runs as the connection changes state.

Three of them mark the transitions:

* a **disconnect handler** runs when the link drops and reconnection begins,
* a **reconnect handler** runs when the client re-establishes a connection,
* a **closed handler** runs once, when the connection is finished for good and won't come back.

A disconnect followed by a reconnect is routine and needs nothing from you beyond a log line. The closed handler is the one that matters: it means the client gave up retrying, or you closed the connection deliberately, and this connection is over.

A fourth callback isn't about state at all. The **async error handler** is where the client reports errors that don't belong to any single call you made, such as the server rejecting a subscription because your credentials don't permit that subject. An error a publish call can detect comes back from the call itself, but these arrive with no call to attach them to, so the client routes them all to this one handler. Wire it up in every real service; without it, those errors are invisible.

Registering these four is the first thing a production connection does, before it publishes or subscribes a single message. The [Reconnection](/learn/resilient-clients/reconnection.md) page shows a service registering a callback that logs every failed reconnect attempt through a long outage. A connection also reaches CLOSED the clean way, when you shut down on purpose; draining it first so in-flight work finishes is [Drain & Shutdown](/learn/resilient-clients/drain-and-shutdown.md).

## Force a reconnect

Reconnection usually happens *to* a client: the server drops the link and the client reacts. A client can also start it deliberately. **Force reconnect** is a call that closes the current connection and immediately re-dials the pool, running the same path a real disconnect would: subscriptions are restored and buffered publishes flush, exactly as if the server had gone away.

You use it when the connection is healthy but you want to move it. After you scale a cluster out, clients stay on the servers they first dialed and a new server sits idle; forcing a reconnect across the fleet spreads clients onto it. It's also how a client leaves a server you know is about to go down, on your schedule instead of waiting for the socket to close.

nats.go exposes this as `Conn.ForceReconnect()`, and several other clients offer the same call under their own naming. There's nothing new to learn in the mechanics; it's the ordinary reconnect from the top of this page, started by you.

## Lame-duck mode

A server doesn't always vanish without warning. When an operator takes one down for an upgrade, the server can enter **lame-duck mode**: it stops accepting new connections, announces to every connected client that it's about to go away, and then closes the existing ones gradually rather than all at once.

From the client's side this is a gentler disconnect. A client that watches for the notice can reconnect to another server in the pool *before* its socket is cut — the lame-duck callback wired to a forced reconnect — and move without ever seeing a hard drop. Even a client that does nothing special is disconnected in a spread-out wave, instead of every client on the server reconnecting at the same instant.

An operator triggers it with a signal to the server process:

#### CLI

```
#!/bin/bash

# Lame-duck mode: tell a running server to step down gracefully instead of

# dropping every client at once. Keep the local nats-server running, with a

# subscriber (nats sub orders.created) attached in another terminal.

#

# Signal the server to enter lame-duck mode. With a single nats-server on the

# box you don't pass a pid -- the CLI finds the one running process:

nats-server --signal ldm



# The running server logs that it is draining and stops taking new clients:

#

#   [INF] Entering lame duck mode, stop accepting new clients

#

# It then closes existing clients gradually rather than all at once. Across a

# cluster, a client that watches for the lame-duck notice can move to another

# server before its socket is cut; the rest are disconnected in a spread-out

# wave and reconnect elsewhere on their own. Against this single server

# there is nowhere else to go, so the subscriber is disconnected gracefully

# and reconnects once you start the server again -- the same stop and start as

# any restart.

#

# The grace period before clients are closed, and the window the disconnects

# are spread over, are server settings an operator tunes. See the server-side

# walkthrough in Deployment -> Rolling upgrades.
```

#### C

```
// Register a callback for the lame-duck notice. When an operator takes

// the server down gracefully (nats-server --signal ldm), the server

// stops accepting new connections and announces to every connected

// client that it is about to go away; this callback is that notice.

if (s == NATS_OK)

    s = natsOptions_SetLameDuckModeCB(opts, onLameDuck, NULL);



if (s == NATS_OK)

    s = natsConnection_Connect(&conn, opts);



// Keep the client running. Signal the server from another terminal

// with: nats-server --signal ldm

if (s == NATS_OK)

{

    printf("connected, waiting for the lame-duck notice...\n");

    while (natsConnection_Status(conn) != NATS_CONN_STATUS_CLOSED)

        nats_Sleep(100);

}
```

The server-side details, the signal itself and the timing it uses to spread the disconnects, are an operations task covered in [Deployment → Rolling upgrades](/learn/deployment/rolling-upgrades.md). Lame-duck mode matters most across a cluster, where the client has another server to move to. Against the single local server in this chapter there's nowhere else to go, so the client waits out the graceful shutdown and reconnects when the server comes back, the same stop and start as any other restart.

## Try it

You can watch the client reconnect against the single local server. Subscribe in one terminal, then stop and restart the server underneath it. The subscriber logs the drop, reconnects on its own, and resumes, and you never restart the subscriber:

#### CLI

```
#!/bin/bash

# Watch the client reconnect on its own. Keep the local nats-server from

# earlier in the chapter running in its own terminal.

#

# In this terminal, subscribe as the warehouse service on orders.created:

nats sub orders.created



# Now stop the nats-server (Ctrl-C in its terminal) and start it again. The

# subscriber keeps running the whole time. It logs the drop -- the reason is

# EOF because the server closed the socket cleanly on the way down:

#

#   14:02:11 Subscribing on orders.created

#   14:02:19 >>> Disconnected due to: EOF, will attempt reconnect

#

# You never restart the subscriber. Once the server is back, publish an order

# and the subscriber prints it, because the client re-dialed and re-sent the

# subscription itself. Add --trace to log an explicit reconnect line too,

# along with the initial connect and each retry delay:

#

#   nats sub orders.created --trace

#   14:02:21 >>> Reconnected to nats://127.0.0.1:4222 (127.0.0.1:4222)

#

# Publishing WHILE the server is down fails instead: nats pub has no server

# to connect to, and nothing queues the message server-side. The at-most-once

# loss happens on a live server: a message that arrives before the

# subscription is restored finds no interest and is discarded.
```

#### C

```
// Register the lifecycle callbacks before connecting: one for the

// drop, one for the recovery.

if (s == NATS_OK)

    s = natsOptions_SetDisconnectedCB(opts, onDisconnected, NULL);

if (s == NATS_OK)

    s = natsOptions_SetReconnectedCB(opts, onReconnected, NULL);



if (s == NATS_OK)

    s = natsConnection_Connect(&conn, opts);



// Subscribe as the warehouse service. Now stop and restart the

// nats-server: the client logs the drop, re-dials, and re-sends this

// subscription on its own -- you never restart this program. Publish

// an orders.created message once the server is back and it prints,

// proving the subscription was restored on the new connection.

if (s == NATS_OK)

    s = natsConnection_Subscribe(&sub, conn, "orders.created", onMsg, NULL);



if (s == NATS_OK)

{

    printf("subscribed to orders.created, restart the server underneath me\n");

    while (natsConnection_Status(conn) != NATS_CONN_STATUS_CLOSED)

        nats_Sleep(100);

}
```

Publish an `orders.created` message once the server is back and the subscriber prints it, which proves the subscription was restored on the new connection. Publishing *while* the server is down fails instead: `nats pub` has no server to connect to, and nothing queues the message server-side. The at-most-once loss from earlier in the page happens on a live server: a message that arrives in the gap before your subscription is restored finds no interest, and the server discards it.

## Pitfalls

Each of these turns the automatic reconnect into a quiet way to lose data or stall a service.

**Trusting the reconnect buffer as a delivery guarantee.** The buffer holds your publishes through a disconnect, but it lives in your client's memory. It isn't written anywhere durable, and if the process itself dies, everything in the buffer dies with it. Treat it as a short-term hold over a brief outage, not as storage you can rely on. A publish that must survive regardless needs the server-side store from earlier in the page.

**Doing real work inside a connection callback.** The disconnect, reconnect, closed, and error handlers run on the client's own thread. Block one with a database write or a slow HTTP call, and every other callback on that connection waits behind it; in some clients the connection's processing does too. Keep the handlers to a log line or a signal on a channel, and do the actual work elsewhere.

**Letting infinite reconnect hide a dead configuration.** A long-lived service should retry forever, but "forever" also means a client pointed at a wrong address, or refused by auth, retries that mistake silently and looks healthy while it never connects. Log the drop from the disconnect handler and every failed attempt from the reconnect-error callback the Reconnection page wires up, so a misconfiguration shows up as constant errors in your logs instead of silence. The retry-limit setting and its defaults are in [Reconnection](/learn/resilient-clients/reconnection.md).

## Where you are

You now know what a dropped connection does to a client:

* The client owns reconnection. It re-dials, replays the handshake, and re-subscribes on its own, because the server keeps no per-client state.
* Your outgoing publishes are buffered through the gap and flushed on reconnect; messages others published while you were away are gone, which is at-most-once at work.
* You observe the whole cycle through the disconnect, reconnect, closed, and async error callbacks, wired up before the first message.
* A client can force its own reconnect, and a server in lame-duck mode lets clients leave gracefully before it stops.

## What's next

A connection can drop and heal without you noticing, which is usually what you want, but it also means a delivery problem can hide behind a healthy-looking client. The next page, [Debugging delivery](/learn/core-nats/debugging-delivery.md), is how you tell a message that reached no subscriber from one that never left the client at all, using the server's own view of the connection.

## See also

* [Resilient clients → Reconnection](/learn/resilient-clients/reconnection.md) — tuning backoff, jitter, retry limits, and the reconnect buffer for a long-lived service.
* [Resilient clients → Drain & Shutdown](/learn/resilient-clients/drain-and-shutdown.md) — closing a connection cleanly so in-flight work isn't dropped.
* [Deployment → Rolling upgrades](/learn/deployment/rolling-upgrades.md) — the server side of lame-duck mode: the signal, the grace period, and the timing.
* [Publish-subscribe → At-most-once delivery](/learn/core-nats/publish-subscribe.md#at-most-once-delivery) — why a message published with no interest is gone for good.
