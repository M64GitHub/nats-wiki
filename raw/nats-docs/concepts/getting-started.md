<!-- source: https://docs.nats.io/concepts/getting-started.md · fetched 2026-08-31 · section: getting-started -->
# Getting Started with NATS

Get up and running with NATS in minutes. This guide will walk you through installation, basic setup, and your first NATS application.

## Installation

### Quick Start with Docker

The fastest way to get NATS running:

```
docker run -p 4222:4222 -p 8222:8222 nats:latest
```

This starts NATS Server with:

* Client connections on port 4222
* HTTP monitoring on port 8222

### Install NATS Server

#### macOS

```
brew install nats-server
```

#### Linux

```
curl -sf https://binaries.nats.dev/nats-io/nats-server/v2@latest | sh

sudo mv nats-server /usr/local/bin/
```

#### Windows

Download the latest release from [GitHub Releases](https://github.com/nats-io/nats-server/releases).

### Verify Installation

```
nats-server --version
```

## Start NATS Server

### Basic Server

```
nats-server
```

### With Monitoring

```
nats-server -m 8222
```

Visit <http://localhost:8222> to see server metrics.

### With JetStream (Persistence)

```
nats-server -js
```

## Install NATS CLI

The NATS CLI tool helps you interact with NATS:

```
# macOS

brew install nats-io/nats-tools/nats



# Linux

curl -sf https://binaries.nats.dev/nats-io/natscli/nats@latest | sh

sudo mv nats /usr/local/bin/
```

## Your First NATS Application

### Using the CLI

```
# Subscribe to a subject

nats sub hello &



# Publish a message

nats pub hello "Hello NATS!"
```

### Install Client Libraries

#### CLI

```
# The NATS CLI is already installed (see above)

# You can use it directly for pub/sub operations
```

#### JavaScript/TypeScript

```
npm install nats
```

#### Go

```
go get github.com/nats-io/nats.go
```

#### Java

Gradle

```
dependencies {

  implementation 'io.nats:jnats:2.25.2'

}
```

Maven

```
<dependency>

    <groupId>io.nats</groupId>

    <artifactId>jnats</artifactId>

    <version>2.25.2</version>

</dependency>
```

#### Rust

Cargo.toml

```
[dependencies]

async-nats = "0.47.0"

tokio = { version = "1", features = ["full"] }
```

#### C#/.NET

```
dotnet add package NATS.Net
```

See [NATS.Net on NuGet](https://www.nuget.org/packages/NATS.Net) for the latest version.

### Publisher Example

#### CLI

```
#!/bin/bash



# Publish a message to demo.nats.io

nats pub --server=demo.nats.io hello "Hello NATS!"
```

#### JavaScript/TypeScript

```
/*

 * Copyright 2026 The NATS Authors

 * Licensed under the Apache License, Version 2.0 (the "License");

 * you may not use this file except in compliance with the License.

 * You may obtain a copy of the License at

 *

 * http://www.apache.org/licenses/LICENSE-2.0

 *

 * Unless required by applicable law or agreed to in writing, software

 * distributed under the License is distributed on an "AS IS" BASIS,

 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

 * See the License for the specific language governing permissions and

 * limitations under the License.

 */



// import the connect function from a transport

import { connect } from "@nats-io/transport-deno";



// connect to NATS demo server

const nc = await connect();



// publish a message to the 'hello' subject

nc.publish("hello", "Hello NATS!");

console.log("Message published to hello");



// drain the connection (flushes and closes)

await nc.drain();
```

#### Go

```
package main



import (

	"log"



	"github.com/nats-io/nats.go"

)



func main() {

	// Connect to NATS demo server

	nc, err := nats.Connect("demo.nats.io")

	if err != nil {

		log.Fatal(err)

	}

	defer nc.Close()



	// Publish a message

	err = nc.Publish("hello", []byte("Hello NATS!"))

	if err != nil {

		log.Fatal(err)

	}



	log.Println("Message published to hello")

}
```

#### Python

```
async def main():

    # Connect to NATS demo server

    nc = await client.connect("nats://demo.nats.io")



    # Publish a message to the subject "hello"

    await nc.publish("hello", b"Hello NATS!")

    await nc.flush()



    print("Message published to hello")



    await nc.close()
```

#### Java

```
public static void main(String[] args) {

    try (Connection nc = Nats.connect("nats://localhost:4222")) {

        // Publish a message to the subject "hello"

        byte[] data = "Hello NATS!".getBytes(StandardCharsets.UTF_8);

        nc.publish("hello", data);

        System.out.println("Message published to hello");

    }

    catch (InterruptedException e) {

        // can be thrown by connect

        Thread.currentThread().interrupt();

    }

    catch (IOException e) {

        // can be thrown by connect

    }

}
```

#### Rust

```
// Connect to NATS demo server

let client = async_nats::connect("demo.nats.io").await?;



// Publish a message to the subject "hello"

client.publish("hello", "Hello NATS!".into()).await?;

client.flush().await?;



println!("Message published to hello");
```

#### C#/.NET

```
await using var client = new NatsClient("demo.nats.io");



// Publish a message to the subject "hello"

await client.PublishAsync("hello", "Hello NATS!");
```

#### C

```
// Connect to the NATS server

const char *url = getenv("NATS_URL");



s = natsConnection_ConnectTo(&conn, (url == NULL) ? NATS_DEFAULT_URL : url);



// Publish a message

if (s == NATS_OK)

    s = natsConnection_PublishString(conn, "hello", "Hello NATS!");



if (s == NATS_OK)

    printf("Message published to hello\n");
```

### Subscriber Example

#### CLI

```
#!/bin/bash



# Subscribe to messages from demo.nats.io

nats sub --server=demo.nats.io hello
```

#### JavaScript/TypeScript

```
// Subscribe to the "weather.updates" subject; auto-close after 1 message

const sub = nc.subscribe("weather.updates");



// iterate over messages received (sub will end after the first message)

for await (const msg of sub) {

  console.log(`Received: ${msg.string()}`);

  break;

}
```

#### Go

```
package main



import (

	"log"



	"github.com/nats-io/nats.go"

)



func main() {

	// Connect to NATS demo server

	nc, err := nats.Connect("demo.nats.io")

	if err != nil {

		log.Fatal(err)

	}

	defer nc.Close()



	// Subscribe to 'hello'

	_, err = nc.Subscribe("hello", func(msg *nats.Msg) {

		log.Printf("Received: %s", string(msg.Data))

	})

	if err != nil {

		log.Fatal(err)

	}



	log.Println("Listening for messages on 'hello'...")



	// Keep the process running

	select {}

}
```

#### Python

```
async def main():

    nc = await client.connect("nats://demo.nats.io")



    # Asynchronous subscriber - iterate messages in a background task

    async_sub = await nc.subscribe("hello")



    async def async_handler():

        async for msg in async_sub:

            print(f"Asynchronous Subscriber Received: {msg.data.decode()}")



    asyncio.create_task(async_handler())



    # Synchronous subscription

    sync_sub = await nc.subscribe("hello")



    print("Waiting for message on 'hello'")



    # Process messages synchronously

    while True:

        try:

            msg = await sync_sub.next(timeout=1)

            print(f"Synchronous Subscriber Received: {msg.data.decode()}")

        except TimeoutError:

            break



    await nc.close()
```

#### Java

```
public static void main(String[] args) {

    try (Connection nc = Nats.connect("nats://localhost:4222")) {

        // Asynchronous Subscriber requires a dispatcher

        // Dispatchers can be shared

        Dispatcher d = nc.createDispatcher(msg -> {

            System.out.println("Asynchronous Subscriber Received: " +

                new String(msg.getData(), StandardCharsets.UTF_8));

        });



        // Subscribe to 'hello' subject

        d.subscribe("hello");



        // Subscribe to 'hello' synchronously

        Subscription syncSub = nc.subscribe("hello");



        System.out.println("Waiting for message on 'hello'");



        // Process messages

        Message m = syncSub.nextMessage(1000);

        while (m != null) {

            System.out.println("Synchronous Subscriber Received: " +

                new String(m.getData(), StandardCharsets.UTF_8));

            m = syncSub.nextMessage(1000);

        }

    }

    catch (InterruptedException e) {

        // can be thrown by connect

        Thread.currentThread().interrupt();

    }

    catch (IOException e) {

        // can be thrown by connect

    }

}
```

#### Rust

```
// Connect to NATS demo server

let client = async_nats::connect("demo.nats.io").await?;



// Subscribe to the 'hello' subject

let mut subscriber = client.subscribe("hello").await?;

println!("Listening for messages on 'hello'...");



// Process messages

while let Some(msg) = subscriber.next().await {

    println!("Received: {}", String::from_utf8_lossy(&msg.payload));

}
```

#### C#/.NET

```
await using var client = new NatsClient("demo.nats.io");



// Subscribe to 'hello' and process messages

await foreach (var msg in client.SubscribeAsync<string>("hello"))

{

    output.WriteLine($"Received: {msg.Data}");

}
```

#### C

```
// The callback runs for each message received on 'hello'.

static void

onMsg(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    printf("Received: %.*s\n",

           natsMsg_GetDataLength(msg), natsMsg_GetData(msg));



    natsMsg_Destroy(msg);

}

    // Connect to the NATS server

    const char *url = getenv("NATS_URL");



    s = natsConnection_ConnectTo(&conn, (url == NULL) ? NATS_DEFAULT_URL : url);



    // Subscribe to 'hello'

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&sub, conn, "hello", onMsg, NULL);



    if (s == NATS_OK)

        printf("Listening for messages on 'hello'...\n");
```

### Running the Examples

#### CLI

```
# Terminal 1 - Start subscriber

nats sub hello



# Terminal 2 - Publish messages

nats pub hello "Hello NATS!"

nats pub hello "Welcome to messaging"



# Request-Reply pattern

# Terminal 1 - Start replier

nats reply hello "Hi there!"



# Terminal 2 - Send request

nats request hello "Anyone there?" --timeout=2s
```

#### JavaScript/TypeScript

```
# Terminal 1 - Start subscriber

node subscribe.js



# Terminal 2 - Run publisher

node publish.js
```

#### Go

```
# Terminal 1 - Start subscriber

go run subscribe.go



# Terminal 2 - Run publisher

go run publish.go
```

#### Java

```
It's best to run the examples from your IDE or 

command line where Java is installed.



Clone https://github.com/nats-io/nats.java

and navigate to src/main/java/io/nats/examples/natsIoDoc
```

#### Rust

```
# Terminal 1 - Start subscriber

cargo run --bin subscribe



# Terminal 2 - Run publisher

cargo run --bin publish
```

#### C#/.NET

```
It's best to run the examples from your IDE or

command line where the .NET SDK is installed.



Clone https://github.com/nats-io/nats.net

and navigate to examples/Example.NatsIODocs
```

## Next Steps

Congratulations! You've successfully:

* ✅ Installed NATS Server
* ✅ Published and subscribed to messages
* ✅ Built your first NATS application

### What to explore next:

* [Core NATS deep dive](/learn/core-nats/.md) — hands-on path through the fundamentals
* [JetStream deep dive](/learn/jetstream/.md) — persistence and streaming
* [The full Learn section](/learn/.md) — guided, runnable chapters
* [Request-Reply Pattern](/concepts/request-reply.md) — synchronous communication
* [Subjects](/concepts/subjects.md) — understanding subject-based messaging

### Client Libraries

NATS has official clients for:

* [Go](https://github.com/nats-io/nats.go)
* [Java](https://github.com/nats-io/nats.java)
* [JavaScript/TypeScript](https://github.com/nats-io/nats.js)
* [Python](https://github.com/nats-io/nats.py)
* [Rust](https://github.com/nats-io/nats.rs)
* [C](https://github.com/nats-io/nats.c)
* [.NET](https://github.com/nats-io/nats.net)

### Resources

* [NATS by Example](https://natsbyexample.com) - Interactive examples
* [Slack Community](https://slack.nats.io) - Get help from the community
