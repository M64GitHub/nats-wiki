<!-- source: https://docs.nats.io/tutorials/hello-nats.md · fetched 2026-08-31 · section: hello-nats -->
# 1. Hello NATS

In this tutorial you install NATS, start a server, and send your first message. You'll subscribe to a **subject** in one terminal, publish a message to it from another, and watch it arrive. By the end you'll have a working NATS server on your machine, and you'll have moved a message through it from both the CLI and a client.

## What you'll need

* a terminal you can open two or three tabs in
* permission to install software (Homebrew, a download, or Docker)
* about ten minutes

## Step 1: Install the NATS server and CLI

Install `nats-server` (the server) and `nats` (the command-line client).

#### macOS (Homebrew)

```
brew install nats-server

brew install nats-io/nats-tools/nats
```

#### Linux

```
# Server (installs nats-server into /usr/local/bin, prompting for sudo)

curl -sf https://binaries.nats.dev/nats-io/nats-server/v2@latest | PREFIX=/usr/local/bin sh



# CLI (installs nats into /usr/local/bin)

curl -sf https://binaries.nats.dev/nats-io/natscli/v0@latest | PREFIX=/usr/local/bin sh
```

#### Docker

```
# Run the server in Docker instead of installing it. This runs in the

# foreground and ends with "[INF] Server is ready" — leave it running.

# You already have a server this way, so skip Step 2 below.

docker run -p 4222:4222 nats:latest



# In another terminal, install just the CLI on your host (macOS shown)

brew install nats-io/nats-tools/nats
```

Check that the CLI is installed:

```
nats --version
```

You should see a version number, for example `nats version 0.4.0`. If you installed the server directly (Homebrew or the Linux script, not Docker), check it too — you should see something like `nats-server: v2.11.0`:

```
nats-server --version
```

## Step 2: Start the server

If you started the server with Docker in Step 1, it's already running — leave that terminal alone and skip to Step 3.

Otherwise, in your first terminal, start the server:

```
nats-server
```

You should see startup lines ending with:

```
[INF] Server is ready
```

The server now listens on `localhost:4222`. Leave this terminal running for the rest of the tutorial.

## Step 3: Subscribe to a subject

Open a **second terminal**. A subscriber registers interest in a subject and receives a copy of every matching message. Subscribe to the `greet` subject:

#### CLI

```
#!/bin/bash

# Subscribe to the greet subject and wait for messages.

# Each matching message prints as it arrives. Ctrl-C to stop.

nats sub greet
```

#### C

```
// The callback runs once for each message published to greet.

static void

onMsg(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    printf("received on \"%s\": %.*s\n",

           natsMsg_GetSubject(msg),

           natsMsg_GetDataLength(msg), natsMsg_GetData(msg));

    natsMsg_Destroy(msg);

}

    // Subscribe to the greet subject and wait for messages. Ctrl-C to stop.

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&sub, conn, "greet", onMsg, NULL);
```

You should see the subscriber start and wait:

```
17:42:01 Subscribing on greet
```

Leave this terminal running and listening.

## Step 4: Publish a message

Open a **third terminal**. A publisher sends a message to a subject. Publish `Hello NATS!` to `greet`:

#### CLI

```
#!/bin/bash

# Publish one message to the greet subject. The publish is

# fire-and-forget: it hands the message to the server and exits.

nats pub greet "Hello NATS!"
```

#### C

```
// Publish one message to the greet subject. The publish is

// fire-and-forget: it hands the message to the server and returns.

if (s == NATS_OK)

    s = natsConnection_PublishString(conn, "greet", "Hello NATS!");

if (s == NATS_OK)

    printf("published to \"greet\"\n");
```

In this third terminal you should see the publish confirmed:

```
17:42:09 Published 11 bytes to "greet"
```

Now switch back to your **second terminal**. The subscriber received the message and printed it:

```
[#1] Received on "greet"

Hello NATS!
```

That's one message making the round trip: published to a subject, matched against the subscriber's interest, and delivered.

## Step 5: See the flow

Here's an animation of the publish-to-subscriber path you just ran:

**Message flow — Publish / Subscribe (animated):** Animated publish/subscribe: a publisher emits messages; NATS delivers a copy to every matching subscriber.

* Publisher → NATS (subject: updates)
* NATS → Subscriber 1 (subject: updates)
* NATS → Subscriber 2 (subject: updates)

Publish a few more times from the third terminal and watch the counter in the second terminal climb: `[#2]`, `[#3]`, and so on. Each publish delivers a fresh copy to every active subscriber on the subject.

## What you built

You have a running NATS server, and you've sent your first message through it: one terminal subscribed to the `greet` subject, another published to it, and the message arrived. The same pub/sub works from any NATS client, which is what the code tabs above show.

## Next

* Build a responder you can call and get an answer back: [Request-Reply](/tutorials/request-reply.md).
* Understand how publish-subscribe really works (the interest graph, delivery guarantees, and wildcards): the [Core NATS deep dive](/learn/core-nats/.md), or the shorter [publish-subscribe primer](/concepts/pub-sub-basics.md).
