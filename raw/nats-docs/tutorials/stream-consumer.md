<!-- source: https://docs.nats.io/tutorials/stream-consumer.md · fetched 2026-08-31 · section: stream-consumer -->
# 5. A consumer that survives restarts

In the [previous tutorial](/tutorials/first-stream.md) you stored messages in a **stream**. Now you'll read them with a durable **consumer**: pull each message, acknowledge it, then stop and start again and watch the consumer pick up exactly where it left off — no message read twice, none skipped.

**Message flow — Consumers with independent cursors (animated):** Three consumers read one 8-message stream from independent positions. Inventory, Email, and Analytics each start at a different point and move at their own speed, and each keeps its own cursor — one consumer catching up never moves another's position. The stream holds a single shared copy of every message and serves each consumer from where it left off.

## What you'll need

* The `nats` CLI installed.
* A `nats-server` running with JetStream enabled, and the `EVENTS` stream with a few messages in it, which is what you set up in [Tutorial 4: Persist messages with JetStream](/tutorials/first-stream.md). Keep that server running.

## Step 1: Start from a clean set of three messages

So the sequence numbers in this tutorial line up, reset the `EVENTS` stream to a known state. Purging a stream keeps counting sequences from where it left off, so instead delete the stream you created in Tutorial 4 and re-create it, which starts sequences again at 1:

```
nats stream rm EVENTS --force

nats stream add EVENTS --subjects "events.>" --defaults
```

The delete prints nothing; the re-create prints the new stream's configuration, ending with:

```
Stream EVENTS was created
```

Now publish three fresh messages for the consumer to work through:

```
nats pub events.page_loaded '{"page":"/home"}' --jetstream

nats pub events.input_changed '{"field":"email"}' --jetstream

nats pub events.page_loaded '{"page":"/pricing"}' --jetstream
```

You should see each publish confirmed by the server, along with the sequence the stream assigned it:

```
14:22:01 Published 16 bytes to "events.page_loaded"

14:22:01 Stored in Stream: EVENTS Sequence: 1

14:22:01 Published 17 bytes to "events.input_changed"

14:22:01 Stored in Stream: EVENTS Sequence: 2

14:22:01 Published 19 bytes to "events.page_loaded"

14:22:01 Stored in Stream: EVENTS Sequence: 3
```

Confirm the stream now holds exactly your three messages:

```
nats stream info EVENTS
```

You should see a `Messages` count of `3` in the `State` block.

## Step 2: Add a durable consumer

Create a durable pull consumer named `worker` on the `EVENTS` stream. A pull consumer hands you messages when you ask for them, and acknowledges them one at a time.

#### CLI

```
#!/bin/bash

# Add a durable pull consumer named `worker` to the EVENTS stream.

# --pull: the reader fetches messages on demand (a pull consumer)

# --ack explicit: every delivered message must be individually acknowledged

# --defaults: accept the default values for everything else

nats consumer add EVENTS worker --pull --ack explicit --defaults
```

#### C

```
// Add a durable pull consumer named "worker" to the EVENTS stream.

// Naming it makes it durable: the server keeps its place in the

// stream by name after you stop pulling. js_AckExplicit means every

// delivered message must be individually acknowledged.

jsConsumerConfig cfg;



jsConsumerConfig_Init(&cfg);

cfg.Durable   = "worker";

cfg.AckPolicy = js_AckExplicit;



s = js_AddConsumer(&ci, js, "EVENTS", &cfg, NULL, &jerr);

if (s == NATS_OK)

    printf("created consumer %s on stream EVENTS\n", ci->Name);
```

You should see the consumer created and its configuration printed:

```
Information for Consumer EVENTS > worker



Configuration:



                    Name: worker

               Pull Mode: true

          Deliver Policy: All

              Ack Policy: Explicit
```

Naming the consumer `worker` makes it **durable**: the server keeps it (and its place in the stream) by name after you stop pulling.

## Step 3: Pull and acknowledge a message

Ask the consumer for its next message and acknowledge it:

#### CLI

```
#!/bin/bash

# Pull the next message from the `worker` consumer and acknowledge it.

# Acknowledging advances the durable consumer so this message is never resent.

nats consumer next EVENTS worker --ack
```

#### C

```
// Bind to the durable "worker" consumer on the EVENTS stream.

jsSubOptions so;



jsSubOptions_Init(&so);

so.Stream   = "EVENTS";

so.Consumer = "worker";



s = js_PullSubscribe(&sub, js, NULL, NULL, NULL, &so, &jerr);



// Pull the next message, then acknowledge it. Acknowledging

// advances the consumer so this message is never resent.

if (s == NATS_OK)

    s = natsSubscription_Fetch(&list, sub, 1, 5000, &jerr);

if (s == NATS_OK)

{

    natsMsg *msg = list.Msgs[0];



    printf("received on %s: %.*s\n",

           natsMsg_GetSubject(msg),

           natsMsg_GetDataLength(msg),

           natsMsg_GetData(msg));



    s = natsMsg_Ack(msg, NULL);

}
```

You should see the first message, followed by the acknowledgment:

```
[14:23:10] subj: events.page_loaded / tries: 1 / cons seq: 1 / str seq: 1 / pending: 2



{"page":"/home"}



Acknowledged message
```

`{"page":"/home"}` is the message body, the first one you published. `pending: 2` tells you two more messages are waiting, and the `Acknowledged message` line confirms the server recorded that you're done with this one.

Run the same command once more to read and acknowledge the second message:

```
nats consumer next EVENTS worker --ack
```

You should see `{"field":"email"}`, with `cons seq: 2` and `pending: 1`.

## Step 4: Check how far you've read

Look at how far the consumer has progressed:

```
nats consumer info EVENTS worker
```

In the `State` block you should see it sitting after the two messages you acked:

```
State:



   Last Delivered Message: Consumer sequence: 2 Stream sequence: 2

     Acknowledgment Floor: Consumer sequence: 2 Stream sequence: 2

         Outstanding Acks: 0 out of maximum 1,000
```

`Acknowledgment Floor` shows you've acknowledged through message 2, so the next pull will hand you message 3.

## Step 5: Restart and resume

Now simulate a restart. Stop the server with `Ctrl+C` in its terminal, then start it again the same way you did in Tutorial 4 so it reads the stream and consumer back from where it stored them:

```
nats-server -js
```

The stream and the consumer come back exactly as they were. Pull the next message:

```
nats consumer next EVENTS worker --ack
```

You should see the third message, not the first:

```
[14:25:40] subj: events.page_loaded / tries: 1 / cons seq: 3 / str seq: 3 / pending: 0



{"page":"/pricing"}



Acknowledged message
```

The consumer picked up right where it left off. `pending: 0` means you've now read every message. Nothing was redelivered, and nothing was missed.

## What you built

A durable consumer that pulls messages from a stream, acknowledges each one, and resumes after a restart, so your reader always picks up exactly where it left off, with nothing read twice and nothing skipped.

## Next

* Next tutorial: [Build a tiny state store with Key-Value](/tutorials/key-value.md).
* Now understand the why (acknowledgment, redelivery, and how the cursor works): [JetStream deep dive: Delivery and acknowledgment](/learn/jetstream/delivery-and-acknowledgment.md).
