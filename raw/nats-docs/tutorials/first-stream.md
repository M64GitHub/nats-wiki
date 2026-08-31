<!-- source: https://docs.nats.io/tutorials/first-stream.md · fetched 2026-08-31 · section: first-stream -->
# 4. Persist messages with JetStream

So far your messages have been fleeting: a subscriber that isn't listening at the moment you publish never sees them. In this tutorial you turn on JetStream, create a **stream** that stores messages durably, publish a few, and then **replay** them from the very beginning. By the end you'll have proof that the messages survived, sitting in storage, ready to read again.

**Message flow — Core NATS vs JetStream (animated):** Core NATS versus JetStream for a subscriber that goes offline. In Core mode, messages published while the client is offline reach the server and go nowhere; when the client returns, only new messages arrive. In JetStream mode the stream stores what the client missed — the pending count climbs while it is offline and drains back as the stream replays every missed message once the client reconnects.

* Publisher → NATS

## What you'll need

* `nats-server` and the `nats` CLI installed (from [Hello NATS](/tutorials/hello-nats.md)).
* A terminal. You'll start the server in one and run commands in another.

## Step 1: Start the server with JetStream

Stop any server you started earlier, then start a new one with the `-js` flag. That flag turns on JetStream, the subsystem that stores messages.

```
nats-server -js
```

You should see a startup log that mentions JetStream, including a line like:

```
[INF] Starting JetStream

[INF] Server is ready
```

Leave this running. Open a second terminal for the remaining steps.

## Step 2: Create a stream

In the second terminal, create a stream named `EVENTS` that captures every subject beginning with `events.`. The `--defaults` flag fills in sensible starting values so you aren't prompted for anything.

#### CLI

```
#!/bin/bash



# Create a stream named EVENTS that captures every subject under events.>

# --defaults fills in sensible starting values so the CLI does not prompt.

nats stream add EVENTS --subjects "events.>" --defaults
```

#### C

```
// Create a stream named EVENTS that captures every subject under

// events.>. Every other setting keeps its sensible default.

jsStreamConfig  cfg;

const char      *subjects[] = {"events.>"};



jsStreamConfig_Init(&cfg);

cfg.Name        = "EVENTS";

cfg.Subjects    = subjects;

cfg.SubjectsLen = 1;



s = js_AddStream(&si, js, &cfg, NULL, &jerr);

if (s == NATS_OK)

    printf("Stream %s was created\n", si->Config->Name);
```

You should see output ending with:

```
Stream EVENTS was created
```

Your stream now exists and is waiting for messages.

## Step 3: Publish a few messages

Publish three messages to subjects under `events.`. Because each subject matches the stream, the server stores every one.

#### CLI

```
#!/bin/bash



# Publish three messages. Each subject starts with events. so the EVENTS

# stream captures and stores every one. For each publish the CLI prints a

# "Stored in Stream" line with the assigned sequence, confirming it was stored.

nats pub events.page_loaded   '{"page":"/home"}'    --jetstream

nats pub events.input_changed '{"field":"email"}'   --jetstream

nats pub events.page_loaded   '{"page":"/pricing"}' --jetstream
```

#### C

```
// Publish three messages. Each subject starts with events. so the

// EVENTS stream stores every one. The returned ack carries the

// stream name and the sequence the message was stored at.

const char *subjects[] = {"events.page_loaded",

                          "events.input_changed",

                          "events.page_loaded"};

const char *payloads[] = {"{\"page\":\"/home\"}",

                          "{\"field\":\"email\"}",

                          "{\"page\":\"/pricing\"}"};

int        i;



for (i = 0; (s == NATS_OK) && (i < 3); i++)

{

    jsPubAck *ack = NULL;



    s = js_Publish(&ack, js, subjects[i],

                   payloads[i], (int) strlen(payloads[i]),

                   NULL, &jerr);

    if (s == NATS_OK)

    {

        printf("Stored in Stream: %s Sequence: %" PRIu64 "\n",

               ack->Stream, ack->Sequence);

        jsPubAck_Destroy(ack);

    }

}
```

For each publish you should see two lines: one confirming the message was sent, and one confirming the stream stored it with an assigned sequence number:

```
13:42:01 Published 16 bytes to "events.page_loaded"

13:42:01 Stored in Stream: EVENTS Sequence: 1

13:42:01 Published 17 bytes to "events.input_changed"

13:42:01 Stored in Stream: EVENTS Sequence: 2

13:42:01 Published 19 bytes to "events.page_loaded"

13:42:01 Stored in Stream: EVENTS Sequence: 3
```

Confirm the stream now holds three messages:

```
nats stream info EVENTS
```

You should see a `State` block reporting three messages:

```
State:



             Messages: 3

                Bytes: 159 B

       First Sequence: 1 @ 2026-06-09 13:42:01

        Last Sequence: 3 @ 2026-06-09 13:42:01

     Active Consumers: 0

   Number of Subjects: 2
```

## Step 4: Replay the stored messages

Now read the messages back. This replays every message the stream holds, oldest first, starting from the very first one. Nothing is removed: replaying a stream is a read.

#### CLI

```
#!/bin/bash



# Replay every message stored in the stream, oldest first.

#   --all              start at the first stored message (sequence 1)

#   --terminate-at-end stop once all stored messages have been read

nats sub "events.>" --all --terminate-at-end
```

#### C

```
// Replay every message stored in the stream, oldest first. An

// ordered consumer starts at the first stored message; the metadata

// on each message tells us how many are still pending, so we stop

// once we've read everything. Nothing is removed: this is a read.

jsSubOptions so;



jsSubOptions_Init(&so);

so.Stream  = "EVENTS";

so.Ordered = true;



s = js_SubscribeSync(&sub, js, "events.>", NULL, &so, &jerr);



while (s == NATS_OK)

{

    natsMsg         *msg    = NULL;

    jsMsgMetaData   *meta   = NULL;

    uint64_t        pending = 0;



    s = natsSubscription_NextMsg(&msg, sub, 5000);

    if (s != NATS_OK)

        break;



    s = natsMsg_GetMetaData(&meta, msg);

    if (s == NATS_OK)

    {

        pending = meta->NumPending;

        printf("seq: %" PRIu64 " / subject: %s\n%.*s\n\n",

               meta->Sequence.Stream, natsMsg_GetSubject(msg),

               natsMsg_GetDataLength(msg), natsMsg_GetData(msg));

        jsMsgMetaData_Destroy(meta);

    }

    natsMsg_Destroy(msg);



    // Exit on our own once everything stored has been read.

    if ((s == NATS_OK) && (pending == 0))

        break;

}

// An empty stream simply times out waiting for the first message.

if (s == NATS_TIMEOUT)

    s = NATS_OK;
```

You should see all three messages, in the order they were published:

```
[#1] Received JetStream message: stream: EVENTS seq: 1 / pending: 2 / subject: events.page_loaded / time: 2026-06-09 13:42:01

{"page":"/home"}



[#2] Received JetStream message: stream: EVENTS seq: 2 / pending: 1 / subject: events.input_changed / time: 2026-06-09 13:42:01

{"field":"email"}



[#3] Received JetStream message: stream: EVENTS seq: 3 / pending: 0 / subject: events.page_loaded / time: 2026-06-09 13:42:01

{"page":"/pricing"}
```

The command exits on its own once it's read everything stored. Run it again and you'll see the same three messages: the stream still has them.

## What you built

You enabled JetStream, created the `EVENTS` stream, published three messages into it, and replayed all three back from storage. And they were still there to read again afterward.

## Next

* Next tutorial: [Read a stream with a durable consumer](/tutorials/stream-consumer.md) — a reader that tracks what it's processed and resumes after a restart.
* Understand how this works: the [JetStream deep dive](/learn/jetstream/.md) explains what a stream really is, and [Your first stream](/learn/jetstream/your-first-stream.md) walks through every value JetStream filled in for you.
