<!-- source: https://docs.nats.io/tutorials/request-reply.md · fetched 2026-08-31 · section: request-reply -->
# 2. Request and reply

In [Hello NATS](/tutorials/hello-nats.md) a publisher sent a message and never heard back. This time you'll build a two-way conversation: a small **responder** that answers questions on a subject, and a **request** that calls it and gets exactly one reply. By the end you'll start a `time` service in one terminal and ask it for the time from another.

**Message flow — Request / Reply:** Request-reply pattern where a client sends a request and waits for a response from a service

* Client → NATS (subject: get.user.150)
* NATS → Service (subject: get.user.150)
* Service → NATS (subject: \_INBOX.\<nuid>)
* NATS → Client (subject: \_INBOX.\<nuid>)

## What you'll need

* The `nats` CLI and a running `nats-server` from [Hello NATS](/tutorials/hello-nats.md). If the server isn't running, start it:

  ```
  nats-server
  ```

* Two terminals: one for the responder, one for the request.

## Step 1: Start a responder

In your first terminal, start a responder on the subject `time`. The `--command` flag tells `nats reply` to run a command for each request and send its output back as the reply.

#### CLI

```
#!/bin/bash

# Start a responder on the subject "time". `nats reply` subscribes to the

# subject and, for every request it receives, runs the command and sends its

# output back on the request's private reply subject. Leave this running.

nats reply time --command "date"
```

#### C

```
// Answer every request on "time" with the current date and time, sent

// back on the request's private reply subject.

static void

onRequest(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    char   now[64];

    time_t t = time(NULL);



    strftime(now, sizeof(now), "%a %b %e %H:%M:%S %Z %Y", localtime(&t));

    if (natsMsg_GetReply(msg) != NULL)

        natsConnection_PublishString(nc, natsMsg_GetReply(msg), now);



    natsMsg_Destroy(msg);

}

    // Subscribe on "time" and leave the responder running; Ctrl-C to stop.

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&sub, conn, "time", onRequest, NULL);
```

You should see it start up and wait:

```
17:42:10 Listening on "time" in group "NATS-RPLY-22"
```

Leave this terminal running. It's now a service waiting to answer.

## Step 2: Send a request

Open your second terminal and call the service. `nats request` publishes one message on `time` and waits for a single reply, up to the global `--timeout` (five seconds by default).

#### CLI

```
#!/bin/bash

# Call the responder once. `nats request` creates a private inbox, subscribes

# to it, publishes an (empty) request on "time" with the inbox attached, and

# prints the first reply it gets back. --timeout is the longest it waits.

nats request time "" --timeout 2s
```

#### C

```
// Call the responder once. The client creates a private inbox,

// publishes an empty request on "time" with the inbox attached, and

// waits up to two seconds for the first reply.

natsMsg *reply = NULL;



s = natsConnection_RequestString(&reply, conn, "time", "", 2000);

if (s == NATS_OK)

{

    printf("received: %.*s\n",

           natsMsg_GetDataLength(reply), natsMsg_GetData(reply));

    natsMsg_Destroy(reply);

}

else if (s == NATS_NO_RESPONDERS)

{

    // Nobody is subscribed to "time": the server says so right away

    // instead of letting the request wait out the timeout.

    printf("no responders are available\n");

}
```

You should see one reply printed, the current date and time from the responder:

```
17:42:31 Sending request on "time"

17:42:31 Received with rtt 612µs

Mon Jun  9 17:42:31 CEST 2026
```

That date came from the responder's `date` command, sent back to your request.

## Step 3: Watch the responder log the call

Switch back to your first terminal. You should see the responder log the call:

```
17:42:31 [#0] Received on subject "time":
```

Each time you rerun the request in your second terminal, the counter goes up by one (`[#1]`, `[#2]`, …) and a fresh reply comes back. Try it a couple of times.

## Step 4: See what happens with no responder

Stop the responder in your first terminal with `Ctrl+C`, then send the request again from your second terminal:

```
nats request time "" --timeout 2s
```

Instead of waiting out the timeout, the request returns right away, because the server knows nobody is subscribed to `time`:

```
17:43:02 No responders are available
```

Start the responder again and the same request succeeds.

## What you built

You ran a `time` responder and called it with a request, getting exactly one reply per call, all over NATS with no shared address between the two sides.

## Next

* Next tutorial: [3. Work queue](/tutorials/work-queue.md) — split work across several workers so each message goes to exactly one of them.
* Understand how this works: [Core NATS deep dive → Request-reply](/learn/core-nats/request-reply.md) covers the inbox, timeouts, and the no-responders signal.
* Turn responders into discoverable services with stats and schemas: [Learn → Services](/learn/services/.md).
