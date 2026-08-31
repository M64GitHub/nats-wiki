<!-- source: https://docs.nats.io/tutorials/build-an-app.md · fetched 2026-08-31 · section: build-an-app -->
# 7. Capstone: build a small NATS app

This is the capstone: one small, runnable app that combines everything from the earlier tutorials. It connects to NATS, publishes order events into a JetStream stream, and answers a request that reports how many orders it has seen. Run it once and watch all three patterns work together: publish/subscribe, request/reply, and a stream that keeps your messages.

## What you'll need

* A `nats-server` installed and the `nats` CLI ([Tutorial 1: Hello NATS](/tutorials/hello-nats.md)).
* A language runtime for the client tab you pick (Go, Node.js, Python, and others).
* About 15 minutes. You'll use three terminals.

## Step 1: Start a JetStream server

In your first terminal, start the server with JetStream enabled so it can store your stream:

```
nats-server -js
```

You should see startup logs ending with a line that mentions JetStream:

```
[INF] Starting nats-server

[INF] Starting JetStream

[INF] Server is ready
```

Leave this terminal running.

## Step 2: Create the stream

Open a second terminal. Create a stream named `ORDERS` that captures every message published on subjects under `orders.>`:

#### CLI

```
#!/bin/bash

# Create the ORDERS stream that captures every order event your app

# publishes. The stream stores every message on subjects under orders.>

# so nothing is lost between runs.

nats stream add ORDERS \

  --subjects "orders.>" \

  --storage file \

  --defaults
```

#### C

```
// Create the ORDERS stream that captures every order event your app

// publishes. The stream stores every message on subjects under

// orders.> on disk, so nothing is lost between runs.

jsStreamConfig  cfg;

const char      *subjects[] = {"orders.>"};



jsStreamConfig_Init(&cfg);

cfg.Name        = "ORDERS";

cfg.Subjects    = subjects;

cfg.SubjectsLen = 1;

cfg.Storage     = js_FileStorage;



s = js_AddStream(&si, js, &cfg, NULL, &jerr);

if (s == NATS_OK)

    printf("Stream %s was created\n", si->Config->Name);
```

You should see a confirmation summarizing the new stream:

```
Stream ORDERS was created



Subjects: orders.>

 Storage: File
```

## Step 3: Write and run the app

Now write the app itself. It connects to NATS, publishes three order events into the stream, then subscribes to `orders.count` and replies to any request with the running total it published.

Save the code for your language as a single file, then install its dependencies and run it in your second terminal:

#### Go

```
package main



import (

	"context"

	"fmt"

	"time"



	"github.com/nats-io/nats.go"

	"github.com/nats-io/nats.go/jetstream"

)



func main() {

	// Connect to the server you started in Step 1.

	nc, _ := nats.Connect(nats.DefaultURL)

	defer nc.Drain()



	js, _ := jetstream.New(nc)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)

	defer cancel()



	// Publish three order events into the ORDERS stream.

	orders := []string{"orders.created", "orders.created", "orders.shipped"}

	for _, subject := range orders {

		js.Publish(ctx, subject, []byte("event"))

	}

	count := len(orders)

	fmt.Printf("published %d order events\n", count)



	// Reply to any request on orders.count with the running total.

	nc.Subscribe("orders.count", func(msg *nats.Msg) {

		msg.Respond([]byte(fmt.Sprintf("%d orders", count)))

	})



	fmt.Println("ready: send a request to orders.count")

	select {} // keep running so it can answer requests

}
```

Save it as `main.go`, then set up the module and run it:

```
go mod init orders-app

go get github.com/nats-io/nats.go

go run main.go
```

#### JavaScript/TypeScript

```
import { connect } from "@nats-io/transport-node";

import { jetstream } from "@nats-io/jetstream";



(async () => {

  // Connect to the server you started in Step 1.

  const nc = await connect({ servers: "nats://localhost:4222" });

  const js = jetstream(nc);



  // Publish three order events into the ORDERS stream.

  const orders = ["orders.created", "orders.created", "orders.shipped"];

  for (const subject of orders) {

    await js.publish(subject, "event");

  }

  const count = orders.length;

  console.log(`published ${count} order events`);



  // Reply to any request on orders.count with the running total.

  nc.subscribe("orders.count", {

    callback: (_err, msg) => {

      msg.respond(`${count} orders`);

    },

  });



  console.log("ready: send a request to orders.count");



  // Keep running so it can answer requests.

  await nc.closed();

})();
```

Save it as `app.mjs` (the `.mjs` extension enables the `import` syntax), then install the dependencies and run it:

```
npm install @nats-io/transport-node @nats-io/jetstream

node app.mjs
```

You should see the app print its progress and then wait:

```
published 3 order events

ready: send a request to orders.count
```

Leave the app running.

## Step 4: Confirm the events landed in the stream

Open a third terminal. Read the messages your app stored in the `ORDERS` stream:

#### CLI

```
#!/bin/bash

# Show the messages your app published into the ORDERS stream. Each order

# event the app sent is now stored on the stream and can be read back.

nats stream view ORDERS
```

#### C

```
// Show the messages your app published into the ORDERS stream. An

// ordered consumer reads them back from the first one, oldest first,

// and we stop once nothing is pending.

jsSubOptions so;



jsSubOptions_Init(&so);

so.Stream  = "ORDERS";

so.Ordered = true;



s = js_SubscribeSync(&sub, js, "orders.>", NULL, &so, &jerr);



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

        printf("[%" PRIu64 "] Subject: %s\n",

               meta->Sequence.Stream, natsMsg_GetSubject(msg));

        jsMsgMetaData_Destroy(meta);

    }

    natsMsg_Destroy(msg);



    if ((s == NATS_OK) && (pending == 0))

        break;

}

// An empty stream simply times out waiting for the first message.

if (s == NATS_TIMEOUT)

    s = NATS_OK;
```

You should see the three order events the app published, each on its subject:

```
[1] Subject: orders.created

[2] Subject: orders.created

[3] Subject: orders.shipped
```

The events are now in the stream, ready for a consumer to read back:

**Message flow — Consumers with independent cursors (animated):** Three consumers read one 8-message stream from independent positions. Inventory, Email, and Analytics each start at a different point and move at their own speed, and each keeps its own cursor — one consumer catching up never moves another's position. The stream holds a single shared copy of every message and serves each consumer from where it left off.

## Step 5: Ask the app a question

Still in your third terminal, send a request to the app on `orders.count`:

#### CLI

```
#!/bin/bash

# Ask your running app how many orders it has seen. The app subscribes to

# orders.count and replies with the current total, so the request returns

# a single reply message.

nats request orders.count ""
```

#### C

```
// Ask your running app how many orders it has seen. The app subscribes

// to orders.count and replies with the current total, so the request

// returns a single reply message.

if (s == NATS_OK)

{

    natsMsg *reply = NULL;



    s = natsConnection_RequestString(&reply, conn, "orders.count", "", 2000);

    if (s == NATS_OK)

    {

        printf("%.*s\n",

               natsMsg_GetDataLength(reply), natsMsg_GetData(reply));

        natsMsg_Destroy(reply);

    }

}
```

You should see the app's reply come straight back:

```
3 orders
```

That's it — the app answered your request with the total it published.

## What you built

A single app that connects to NATS, publishes order events into a durable stream, and answers a live request with a computed total: publish/subscribe, JetStream, and request/reply working together in one program.

## Next

You've finished the tutorials. To understand *why* each piece works the way it does, move on to the deep dives:

* Subjects, publish/subscribe, and request/reply: [Core NATS deep dive](/learn/core-nats/.md)
* Streams, consumers, and acknowledgments: [JetStream deep dive](/learn/jetstream/.md)
