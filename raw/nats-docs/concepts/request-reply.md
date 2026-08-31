<!-- source: https://docs.nats.io/concepts/request-reply.md · fetched 2026-08-31 · section: request-reply -->
# Request-Reply

Request-Reply is a communication pattern that brings synchronous communication to NATS's asynchronous messaging system. It allows a client to send a request and wait for a response, building RPC-style interactions on top of the core publish-subscribe mechanism.

For a runnable, step-by-step treatment, see the [request-reply chapter in the Core NATS deep dive](/learn/core-nats/request-reply.md).

## How Request-Reply Works

Under the hood, request-reply uses NATS's publish-subscribe with these steps:

1. **Client creates a unique reply subject** (inbox)
2. **Client subscribes to the reply subject**
3. **Client publishes the request** with the reply subject
4. **Service receives the request** and sees the reply subject
5. **Service publishes the response** to the reply subject
6. **Client receives the response**

This pattern is so common that NATS clients provide a simplified `request()` method that handles all these steps automatically.

**Message flow — Request / Reply:** Request-reply pattern where a client sends a request and waits for a response from a service

* Client → NATS (subject: get.user.150)
* NATS → Service (subject: get.user.150)
* Service → NATS (subject: \_INBOX.\<nuid>)
* NATS → Client (subject: \_INBOX.\<nuid>)

In the animation above:

* The **orange arrow** shows the request flowing from client to service
* The **green dashed arrow** shows the reply flowing back
* This demonstrates the bidirectional, synchronous nature of request-reply

## Basic Request-Reply

#### CLI

```
# Terminal 1: Set up a service that responds to time requests

nats reply time --command "date"



# Terminal 2: Make a request

nats request time ""



# Output: Wed Nov 15 10:23:45 PST 2023
```

#### JavaScript/TypeScript

```
// Set up a service

nc.subscribe("time", {

  callback: (_err, msg) => {

    const time = new Date().toISOString();

    msg.respond(time);

  },

});



// Make a request



await nc.request("time", "")

  .then((m) => {

    console.log(`Response: ${m.string()}`);

  })

  .catch((err) => {

    console.log(`Request failed: ${err.message}`);

  });
```

#### Go

```
// Set up a service

nc.Subscribe("time", func(m *nats.Msg) {

	timeStr := time.Now().Format(time.RFC3339)

	m.Respond([]byte(timeStr))

})



// Make a request

msg, err := nc.Request("time", nil, 1*time.Second)

if err != nil {

	fmt.Printf("Request failed: %v\n", err)

	return

}

fmt.Printf("Response: %s\n", string(msg.Data))
```

#### Python

```
# Set up a service

sub = await nc.subscribe("time")



async def time_service():

    async for msg in sub:

        now = datetime.now(timezone.utc).isoformat()

        if msg.reply:

            await nc.publish(msg.reply, now.encode())



asyncio.create_task(time_service())

await nc.flush()



# Make a request with a timeout and direct response

try:

    m = await nc.request("time", b"", timeout=1)

    print(f"Response: {m.data.decode()}")

except (TimeoutError, NoRespondersError):

    print("Request failed, no response.")
```

#### Java

```
// Set up a service

Dispatcher dTime = nc.createDispatcher(msg -> {

    nc.publish(msg.getReplyTo(), ZonedDateTime.now()

        .withZoneSameInstant(ZoneId.of("GMT"))

        .format(DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.nnnnnnnnn'Z'"))

        .getBytes(StandardCharsets.ISO_8859_1));

});

dTime.subscribe("time");



// Make a request with a timeout and direct response

Message m = nc.request("time", null, Duration.ofSeconds(1));

if (m == null) {

    System.out.println("Request failed, no response.");

}

else {

    System.out.println("Response: " + new String(m.getData()));

}
```

#### Rust

```
// Set up a service

let mut sub = client.subscribe("time").await?;

let service_client = client.clone();



tokio::spawn(async move {

    while let Some(msg) = sub.next().await {

        let time = chrono::Utc::now().to_rfc3339();

        if let Some(reply) = msg.reply {

            service_client.publish(reply, time.into()).await.ok();

        }

    }

});



// Make a request

let response = client.request("time", "".into()).await?;

println!("Response: {}", String::from_utf8_lossy(&response.payload));
```

#### C#/.NET

```
// Set up a service that replies with the current time

// DateTime would be serialized as an ISO-formatted string, just like all primitive types.

_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<DateTime>("time"))

    {

        await msg.ReplyAsync(DateTime.Now);

    }

});



// Give the subscription task time to start before publishing

await Task.Delay(1000);



// Make a request

var reply = await client.RequestAsync<DateTime>("time");

output.WriteLine($"Time is {reply.Data:O}");
```

#### C

```
// Set up a service: reply to each request with the current time

static void

onTimeRequest(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    char    timeStr[64];

    time_t  now = time(NULL);



    strftime(timeStr, sizeof(timeStr), "%Y-%m-%dT%H:%M:%S%z", localtime(&now));

    natsConnection_PublishString(nc, natsMsg_GetReply(msg), timeStr);

    natsMsg_Destroy(msg);

}

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&sub, conn, "time", onTimeRequest, NULL);



    // Make a request and wait up to 1 second for the reply

    if (s == NATS_OK)

        s = natsConnection_Request(&reply, conn, "time", NULL, 0, 1000);

    if (s == NATS_OK)

        printf("Response: %.*s\n",

               natsMsg_GetDataLength(reply), natsMsg_GetData(reply));

    else

        printf("Request failed: %s\n", natsStatus_GetText(s));
```

## Handling Timeouts

Timeouts are crucial in request-reply to prevent indefinite waiting. All NATS clients support configurable timeouts:

#### CLI

```
# Request with 2 second timeout

nats request service "" --timeout 2s



# If no response within 2 seconds, returns error
```

#### JavaScript/TypeScript

```
// Request with custom timeout

await nc.request("service", "data", { timeout: 2000 })

  .then((m) => {

    console.log(`Response: ${m.string()}`);

  })

  .catch((err) => {

    console.log(`Request failed: ${err.message}`);

  });
```

#### Go

```
// Request with custom timeout

msg, err := nc.Request("service", []byte("data"), 2*time.Second)

if err != nil {

	if err == nats.ErrTimeout {

		fmt.Println("Request timed out")

	} else {

		fmt.Printf("Request failed: %v\n", err)

	}

	return

}

fmt.Printf("Response: %s\n", string(msg.Data))
```

#### Python

```
# Request with custom timeout

try:

    m = await nc.request("service", b"data", timeout=2)

    print(f"Response: {m.data.decode()}")

except TimeoutError:

    print("Request timed out")

except NoRespondersError:

    print("No responders for the request")
```

#### Java

```
// Make a request expecting a future

CompletableFuture<Message> responseFuture = nc.request("service", null);

try {

    Message m = responseFuture.get(2, TimeUnit.SECONDS);

    System.out.println("1) Response: " + new String(m.getData()));

}

catch (CancellationException | ExecutionException | TimeoutException e) {

    System.out.println("1) No Response: " + e);

}



// Make a request with a timeout and direct response

Message m = nc.request("service", null, Duration.ofSeconds(2));

if (m == null) {

    System.out.println("2) No Response");

}

else {

    System.out.println("2) Response: " + new String(m.getData()));

}
```

#### Rust

```
// Request with custom timeout.

// `tokio::time::timeout` returns Ok(request_result) or Err(Elapsed).

match tokio::time::timeout(

    Duration::from_secs(2),

    client.request("service", "data".into()),

)

.await

{

    // Request succeeded

    Ok(Ok(response)) => {

        println!("Response: {}", String::from_utf8_lossy(&response.payload));

    }

    // Request failed (e.g. no responders)

    Ok(Err(e)) => {

        eprintln!("Request failed: {}", e);

    }

    // Timed out

    Err(_) => {

        println!("Request timed out");

    }

}
```

#### C#/.NET

```
// Set the per-request timeout via reply options

var replyOpts = new NatsSubOpts { Timeout = TimeSpan.FromSeconds(1) };

try

{

    var reply = await client.RequestAsync<string>("service", replyOpts: replyOpts);

    output.WriteLine($"Response: {reply.Data}");

}

catch (NatsNoReplyException)

{

    output.WriteLine("No Response: timed out");

}
```

#### C

```
// Request with a custom timeout of 2 seconds

s = natsConnection_RequestString(&reply, conn, "service", "data", 2000);

if (s == NATS_TIMEOUT)

    printf("Request timed out\n");

else if (s != NATS_OK)

    printf("Request failed: %s\n", natsStatus_GetText(s));

else

    printf("Response: %.*s\n",

           natsMsg_GetDataLength(reply), natsMsg_GetData(reply));
```

## Multiple Responders

When multiple services subscribe to the same request subject, NATS supports two distinct patterns depending on whether queue groups are used:

### Pattern 1: All Services Respond (Scatter-Gather)

If each app creates a "service" subscription, all of them will receive the request and **all** can respond. The client can collect multiple responses:

**Message flow — Request / Reply — scatter-gather:** Request to multiple services - all respond (scatter-gather pattern)

* Client → NATS (subject: get.status)
* NATS → Service A
* NATS → Service B
* NATS → Service C
* Service A → NATS
* Service B → NATS
* Service C → NATS
* NATS → Client (subject: 3 replies)

In this pattern, one request is broadcast to all three services (A, B, C), and all three send responses back. This is useful for:

* Gathering data from multiple sources
* Aggregating results from distributed services
* Querying multiple replicas for consensus

### Pattern 2: One Service Responds (Load Balancing)

With [queue groups](/concepts/queue-groups.md), **only one** service receives the request and responds, providing automatic load balancing for scalability:

**Message flow — Request / Reply with queue group:** Request with queue group - only one service responds (load balancing)

* Client → NATS (subject: work.process)
* NATS → Service A
* Service A → NATS
* NATS → Client (subject: 1 reply)
* Client → NATS
* NATS → Service B
* Service B → NATS
* NATS → Client
* Client → NATS
* NATS → Service C
* Service C → NATS
* NATS → Client
* NATS → Service A
* NATS → Service B
* NATS → Service C

In this pattern, NATS selects one service from the queue group (Service B in this example) to handle the request. This provides:

* Automatic load distribution across service instances
* Horizontal scalability
* Built-in failover (if one service is down, another handles it)

By default, the `request()` method returns the first response and drops the rest. The example below starts multiple responders and shows the client receiving a single reply. To gather every response, subscribe to a reply inbox directly and read messages until a timeout instead of calling `request()`.

#### CLI

```
# Terminal 1: First service

nats reply service "Response from service 1"



# Terminal 2: Second service

nats reply service "Response from service 2"



# Terminal 3: Make request (nats reply puts both in a shared queue group,

# so one instance answers and the client gets a single reply)

nats request service ""
```

#### JavaScript/TypeScript

```
// Multiple responders - only first response is returned

const subA = nc.subscribe("calc.add");

(async (sub: Subscription) => {

  for await (const m of sub) {

    m.respond("calculated result from A");

  }

})(subA).catch(console.error);



const subB = nc.subscribe("calc.add");

(async (sub: Subscription) => {

  for await (const m of sub) {

    m.respond("calculated result from B");

  }

})(subB).catch(console.error);



// Gets one response

try {

  const response = await nc.request("calc.add", "data");

  console.log(`Got response: ${response.string()}`);

} catch (e) {

  console.error(`Request failed: ${(e as Error).message}`);

}
```

#### Go

```
processCalculation := func(data []byte) []byte {

	return []byte("calculated result")

}



// Multiple responders - only first response is returned

nc.Subscribe("calc.add", func(m *nats.Msg) {

	result := processCalculation(m.Data)

	m.Respond(append(result, []byte(" from A")...))

})



nc.Subscribe("calc.add", func(m *nats.Msg) {

	result := processCalculation(m.Data)

	m.Respond(append(result, []byte(" from B")...))

})



// Gets one response

msg, _ := nc.Request("calc.add", []byte("data"), time.Second)

fmt.Printf("Got response: %s\n", msg.Data)
```

#### Python

```
# Multiple responders - only the first response is returned to the requester

sub_a = await nc.subscribe("calc.add")

sub_b = await nc.subscribe("calc.add")



async def service(sub, label):

    async for msg in sub:

        if msg.reply:

            await nc.publish(msg.reply, f"calculated result from {label}".encode())



asyncio.create_task(service(sub_a, "A"))

asyncio.create_task(service(sub_b, "B"))

await nc.flush()



# Gets one response

try:

    m = await nc.request("calc.add", b"", timeout=0.5)

    print(f"Got response: {m.data.decode()}")

except (TimeoutError, NoRespondersError):

    print("No Response")
```

#### Java

```
// Set up 2 instances of the service

Dispatcher dServiceA = nc.createDispatcher(msg -> {

    byte[] response = ("calculated result from A").getBytes(StandardCharsets.ISO_8859_1);

    nc.publish(msg.getReplyTo(), response);

});

dServiceA.subscribe("calc.add");



Dispatcher dServiceB = nc.createDispatcher(msg -> {

    byte[] response = ("calculated result from B").getBytes(StandardCharsets.ISO_8859_1);

    nc.publish(msg.getReplyTo(), response);

});

dServiceB.subscribe("calc.add");



// Make a request expecting a future

CompletableFuture<Message> responseFuture = nc.request("calc.add", null);

try {

    Message m = responseFuture.get(500, TimeUnit.MILLISECONDS);

    System.out.println("1) Got response: " + new String(m.getData()));

}

catch (CancellationException | ExecutionException | TimeoutException e) {

    System.out.println("1) No Response");

}



// Make a request with a timeout and direct response

Message m = nc.request("calc.add", null, Duration.ofMillis(500));

if (m == null) {

    System.out.println("2) No Response");

}

else {

    System.out.println("2) Got response: " + new String(m.getData()));

}
```

#### Rust

```
// Multiple responders - only first response is returned

let mut sub_a = client.subscribe("calc.add").await?;

let client_a = client.clone();

tokio::spawn(async move {

    while let Some(msg) = sub_a.next().await {

        let response = "calculated result from A".to_string();

        if let Some(reply) = msg.reply {

            client_a.publish(reply, response.into()).await.ok();

        }

    }

});



let mut sub_b = client.subscribe("calc.add").await?;

let client_b = client.clone();

tokio::spawn(async move {

    while let Some(msg) = sub_b.next().await {

        let response = "calculated result from B".to_string();

        if let Some(reply) = msg.reply {

            client_b.publish(reply, response.into()).await.ok();

        }

    }

});



// Gets one response

let response = client.request("calc.add", "data".into()).await?;

println!(

    "Got response: {}",

    String::from_utf8_lossy(&response.payload)

);
```

#### C#/.NET

```
// Two service instances reply on the same subject; the first reply wins

_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<string>("calc.add"))

    {

        await msg.ReplyAsync("calculated result from A");

    }

});



_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<string>("calc.add"))

    {

        await msg.ReplyAsync("calculated result from B");

    }

});



// Give the subscription tasks time to start before publishing

await Task.Delay(1000);



var reply = await client.RequestAsync<string>("calc.add");

output.WriteLine($"Got response: {reply.Data}");
```

#### C

```
// Each responder replies with its own name (passed as the closure)

static void

onCalcRequest(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    char result[64];



    snprintf(result, sizeof(result),

             "calculated result from %s", (const char*) closure);

    natsConnection_PublishString(nc, natsMsg_GetReply(msg), result);

    natsMsg_Destroy(msg);

}

    // Multiple responders - only the first response is returned

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&subA, conn, "calc.add", onCalcRequest, (void*) "A");

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&subB, conn, "calc.add", onCalcRequest, (void*) "B");



    // Gets one response

    if (s == NATS_OK)

        s = natsConnection_RequestString(&reply, conn, "calc.add", "data", 1000);

    if (s == NATS_OK)

        printf("Got response: %.*s\n",

               natsMsg_GetDataLength(reply), natsMsg_GetData(reply));
```

## No Responders Detection

NATS will detect when no services are available to handle a request. When there are no subscribers for the request subject, NATS server will return a "no responders" error immediately:

#### CLI

```
#!/bin/bash



# Request to a subject with no subscribers

nats request no.such.service "test"



# Error: no responders available for request
```

#### JavaScript/TypeScript

```
await nc.request("no.such.service", "test")

  .then((m) => {

    console.log(`Response: ${m.string()}`);

  })

  .catch((err) => {

    console.log(`Request failed: ${err.message}`);

  });
```

#### Go

```
msg, err := nc.Request("no.such.service", []byte("test"), time.Second)

if err == nats.ErrNoResponders {

	log.Println("No services available to handle request")

}
```

#### Python

```
try:

    m = await nc.request("no.such.service", b"test", timeout=0.5)

    print(f"Response: {m.data.decode()}")

except NoRespondersError:

    print("No services available to handle request")

except TimeoutError:

    print("Request timed out")
```

#### Java

```
// You must specify the reportNoResponders() connect option

Options options = Options.builder()

    .server("nats://localhost:4222")

    .reportNoResponders()

    .build();

try (Connection nc = Nats.connect(options)) {

    // Make a request expecting a future

    CompletableFuture<Message> responseFuture = nc.request("no.such.service", null);

    try {

        Message m = responseFuture.get(500, TimeUnit.MILLISECONDS);

        System.out.println("Response: " + new String(m.getData()));

    }

    catch (CancellationException | ExecutionException | TimeoutException e) {

        System.out.println("No services available to handle request: " + e);

    }

}
```

#### Rust

```
match client.request("no.such.service", "test".into()).await {

    Err(e) if e.kind() == async_nats::RequestErrorKind::NoResponders => {

        println!("No services available to handle request");

    }

    Err(e) => println!("Request error: {}", e),

    Ok(msg) => println!("Response: {}", String::from_utf8_lossy(&msg.payload)),

}
```

#### C#/.NET

```
// RequestAsync throws NatsNoRespondersException by default when nobody is listening

try

{

    var reply = await client.RequestAsync<string, string>(subject: "no.such.service", data: "test");

    output.WriteLine($"Response: {reply.Data}");

}

catch (NatsNoRespondersException)

{

    output.WriteLine("No services available to handle the request");

}
```

#### C

```
// Nothing subscribes to this subject, so the server reports

// the missing service right away instead of waiting for the timeout.

if (s == NATS_OK)

{

    s = natsConnection_RequestString(&reply, conn, "no.such.service", "test", 1000);

    if (s == NATS_NO_RESPONDERS)

        printf("No services available to handle request\n");

}
```

## Request with Headers

NATS supports headers in request-reply, enabling metadata exchange:

#### CLI

```
#!/bin/bash



# Send request with headers

nats request service "data" -H "X-Request-ID:123" -H "X-Priority:high"
```

#### JavaScript/TypeScript

```
// Header Aware service

const sub = nc.subscribe("service");

(async (sub: Subscription) => {

  for await (const m of sub) {

    const h = headers();

    const id = m.headers?.get("X-Request-ID");

    if (id) {

      h.append("X-Response-ID", id);

      h.append("X-Request-ID", id);

    }

    const pri = m.headers?.get("X-Priority");

    if (pri) {

      h.append("X-Priority", pri);

    }

    m.respond(m.data, {

      headers: h,

    });

  }

})(sub).catch(console.error);



// Create message with headers

const h = headers();

h.append("X-Request-ID", "123");

h.append("X-Priority", "high");



const response = await nc.request("service", "data", {

  headers: h,

  timeout: 1000,

});

console.log(`Response: ${response.string()}`);

const responseId = response.headers?.get("X-Response-ID");

if (responseId) {

  console.log(`Response ID: ${responseId}`);

}
```

#### Go

```
// Header Aware service

nc.Subscribe("service", func(msg *nats.Msg) {

	responseMsg := nats.NewMsg(msg.Reply)

	responseMsg.Data = msg.Data

	responseMsg.Header.Add("X-Response-ID", "123")

	responseMsg.Header.Add("X-Request-ID", msg.Header.Get("X-Request-ID"))

	responseMsg.Header.Add("X-Priority", msg.Header.Get("X-Priority"))

	nc.PublishMsg(responseMsg)

})



// Create message with headers

msg := nats.NewMsg("service")

msg.Header.Add("X-Request-ID", "123")

msg.Header.Add("X-Priority", "high")

msg.Data = []byte("data")



// Send request with headers

response, err := nc.RequestMsg(msg, time.Second)

if err == nil {

	fmt.Printf("Response: %s\n", response.Data)

	fmt.Printf("Response ID: %s\n", response.Header.Get("X-Response-ID"))

} else {

	fmt.Printf("Error: %s\n", err)

}
```

#### Python

```
# Header aware service

sub = await nc.subscribe("service")



async def service():

    async for msg in sub:

        response_headers: dict[str, str | list[str]] = {}

        if msg.headers:

            request_id = msg.headers.get("X-Request-ID") or ""

            response_headers["X-Response-ID"] = request_id

            for key, values in msg.headers.items():

                response_headers[key] = values

        if msg.reply:

            await nc.publish(msg.reply, msg.data, headers=response_headers)



asyncio.create_task(service())

await nc.flush()



# Make a request with headers

headers = {"X-Request-ID": "123", "X-Priority": "high"}

try:

    m = await nc.request("service", b"data", timeout=0.5, headers=headers)

    data = m.data.decode() if m.data else ""

    print(f"Response: {data}")

    if m.headers:

        print(f"Response ID: {m.headers.get('X-Response-ID')}")

except (TimeoutError, NoRespondersError):

    print("No Response")
```

#### Java

```
// Header Aware service

Dispatcher dService = nc.createDispatcher(msg -> {

    Headers hIncoming = msg.getHeaders();

    Headers hResponse = new Headers();

    for (String keys : hIncoming.keySet()) {

        hResponse.put("X-Response-ID", hIncoming.getFirst("X-Request-ID"));

        hResponse.put(keys, hIncoming.get(keys));

    }

    nc.publish(msg.getReplyTo(), hResponse, msg.getData());

});

dService.subscribe("service");



// Make a request expecting a future

Headers headers = new Headers();

headers.put("X-Request-ID", "123");

headers.put("X-Priority", "high");

CompletableFuture<Message> responseFuture = nc.request("service", headers, "data".getBytes());

try {

    Message m = responseFuture.get(500, TimeUnit.MILLISECONDS);

    Headers hIncoming = m.getHeaders();

    byte[] data = m.getData();

    String s = data == null ? "" : new String(data);

    System.out.println("Response: " + s);

    System.out.println("Response ID: " + hIncoming.getFirst("X-Response-ID"));

}

catch (CancellationException | ExecutionException | TimeoutException e) {

    System.out.println("No Response");

}
```

#### Rust

```
// Create message with headers

let mut headers = HeaderMap::new();

headers.insert("X-Request-ID", "123");

headers.insert("X-Priority", "high");



let response = client

    .request_with_headers("service", headers, "data".into())

    .await?;



println!("Response: {}", String::from_utf8_lossy(&response.payload));

if let Some(response_id) = response

    .headers

    .as_ref()

    .and_then(|h| h.get("X-Response-ID"))

{

    println!("Response ID: {}", response_id);

}
```

#### C#/.NET

```
// Send a request with headers

var requestHeaders = new NatsHeaders

{

    ["X-Request-ID"] = "123",

    ["X-Priority"] = "high",

};



var reply = await client.RequestAsync<string, string>(subject: "service", data: "data", headers: requestHeaders);

output.WriteLine($"Response: {reply.Data}");

output.WriteLine($"Response ID: {reply.Headers?["X-Response-ID"]}");
```

#### C

```
// Header aware service: echo the data and the request headers back

static void

onServiceRequest(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    natsMsg     *responseMsg = NULL;

    const char  *requestID   = NULL;

    const char  *priority    = NULL;



    natsMsgHeader_Get(msg, "X-Request-ID", &requestID);

    natsMsgHeader_Get(msg, "X-Priority", &priority);



    natsMsg_Create(&responseMsg, natsMsg_GetReply(msg), NULL,

                   natsMsg_GetData(msg), natsMsg_GetDataLength(msg));

    natsMsgHeader_Add(responseMsg, "X-Response-ID", "123");

    if (requestID != NULL)

        natsMsgHeader_Add(responseMsg, "X-Request-ID", requestID);

    if (priority != NULL)

        natsMsgHeader_Add(responseMsg, "X-Priority", priority);



    natsConnection_PublishMsg(nc, responseMsg);



    natsMsg_Destroy(responseMsg);

    natsMsg_Destroy(msg);

}

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&sub, conn, "service", onServiceRequest, NULL);



    // Create a message with headers

    if (s == NATS_OK)

        s = natsMsg_Create(&msg, "service", NULL, "data", 4);

    if (s == NATS_OK)

        s = natsMsgHeader_Add(msg, "X-Request-ID", "123");

    if (s == NATS_OK)

        s = natsMsgHeader_Add(msg, "X-Priority", "high");



    // Send the request with headers

    if (s == NATS_OK)

        s = natsConnection_RequestMsg(&response, conn, msg, 1000);

    if (s == NATS_OK)

    {

        const char *responseID = NULL;



        printf("Response: %.*s\n",

               natsMsg_GetDataLength(response), natsMsg_GetData(response));

        if (natsMsgHeader_Get(response, "X-Response-ID", &responseID) == NATS_OK)

            printf("Response ID: %s\n", responseID);

    }

    else

        printf("Error: %s\n", natsStatus_GetText(s));
```

## Best Practices

### Timeout Strategy

* **Set appropriate timeouts**: Too short may miss valid responses, too long blocks unnecessarily
* **Consider network latency**: Add buffer for network round-trip time
* **Implement retry logic**: For transient failures

### Error Handling

* **Always handle timeouts**: Don't assume responses will arrive
* **Check for no responders**: React appropriately when services are unavailable
* **Validate responses**: Ensure response data is valid before processing

### Service Design

* **Idempotent operations**: Requests might be retried
* **Lightweight processing**: Long operations should be async
* **Health checks**: Implement service health endpoints
* **Graceful shutdown**: Drain pending requests before shutting down

### Performance

* **Connection pooling**: Reuse connections for multiple requests
* **Inbox reuse**: Modern clients reuse inbox subjects for efficiency
* **Batch operations**: Group related requests when possible

## Request-Reply vs Publish-Subscribe

Choose request-reply when you need:

* **Synchronous communication**: Wait for a response before continuing
* **Service discovery**: Automatic "no responders" detection
* **Load balancing**: Combined with queue groups
* **RPC-style APIs**: Traditional request-response patterns

Use publish-subscribe when you need:

* **Fire-and-forget**: No response needed
* **Multiple consumers**: All subscribers should receive the message
* **Event streaming**: Continuous flow of events
* **Decoupled systems**: Publishers shouldn't know about subscribers

## Related Concepts

* [Subjects](/concepts/subjects.md) - Understanding subject-based addressing
* [Queue Groups](/concepts/queue-groups.md) - Load balancing for services
* [Publish-Subscribe](/concepts/pub-sub-basics.md) - Asynchronous messaging patterns

## Try It Yourself

Create a simple calculator service:

#### CLI

```
#!/bin/bash



# Terminal 1: Calculator service (adds the two numbers in the request body)

nats reply calc.add --command "sh -c \"echo \$NATS_REQUEST_BODY | awk '{print \$1 + \$2}'\""



# Terminal 2: Make calculations

nats request calc.add "5 3"

# Output: 8

nats request calc.add "10 7"

# Output: 17
```

#### JavaScript/TypeScript

```
// Calculator service

const sub = nc.subscribe("calc.add");

(async (sub: Subscription) => {

  for await (const m of sub) {

    try {

      const {a, b} = m.json<{ a: number, b: number }>();

      if (typeof a !== "number" || typeof b !== "number") {

        throw new Error("invalid input");

      }

      m.respond(JSON.stringify({result: a+b}))

    } catch(err) {

      m.respond("error: invalid input");

    }

  }

})(sub).catch(console.error);



// Make calculations

let resp = await nc.request("calc.add", JSON.stringify({a: 5, b: 3}));

console.log(`5 + 3 = ${resp.string()}`);



resp = await nc.request("calc.add", JSON.stringify({a: 10, b: 7}));

console.log(`10 + 7 = ${resp.string()}`);



resp = await nc.request("calc.add", JSON.stringify({a: 10, b: "x"}));

console.log(`10 + x = ${resp.string()}`);
```

#### Go

```
// Calculator service

nc.Subscribe("calc.add", func(msg *nats.Msg) {

	parts := strings.Fields(string(msg.Data))

	if len(parts) == 2 {

		a, _ := strconv.Atoi(parts[0])

		b, _ := strconv.Atoi(parts[1])

		result := fmt.Sprintf("%d", a+b)

		msg.Respond([]byte(result))

	}

})



// Make calculations

time.Sleep(100 * time.Millisecond)



resp, _ := nc.Request("calc.add", []byte("5 3"), time.Second)

fmt.Printf("5 + 3 = %s\n", string(resp.Data))



resp, _ = nc.Request("calc.add", []byte("10 7"), time.Second)

fmt.Printf("10 + 7 = %s\n", string(resp.Data))
```

#### Python

```
# Calculator service

sub = await nc.subscribe("calc.add")



async def calc_service():

    async for msg in sub:

        # data is in the form "x y"

        try:

            parts = msg.data.decode().split()

            if len(parts) == 2 and msg.reply:

                x = int(parts[0])

                y = int(parts[1])

                await nc.publish(msg.reply, str(x + y).encode())

        except Exception:

            # you could send some other reply here

            pass



asyncio.create_task(calc_service())

await nc.flush()



# Make a request with a timeout

try:

    m = await nc.request("calc.add", b"5 3", timeout=0.5)

    print(f"5 + 3 = {m.data.decode()}")

except (TimeoutError, NoRespondersError):

    print("1) No Response")



# Make another request

try:

    m = await nc.request("calc.add", b"10 7", timeout=0.5)

    print(f"10 + 7 = {m.data.decode()}")

except (TimeoutError, NoRespondersError):

    print("2) No Response")
```

#### Java

```
// Calculator service

Dispatcher dCalcAdd = nc.createDispatcher(msg -> {

    // data is in the form "x y"

    try {

        String[] parts = new String(msg.getData()).split(" ");

        if (parts.length == 2) {

            int x = Integer.parseInt(parts[0]);

            int y = Integer.parseInt(parts[1]);

            nc.publish(msg.getReplyTo(), ("" + (x + y)).getBytes(StandardCharsets.UTF_8));

            return;

        }

        // fall through

    }

    catch (Exception e) {

        // fall through

    }

    nc.publish(msg.getReplyTo(), "error: invalid input".getBytes(StandardCharsets.UTF_8));

});

dCalcAdd.subscribe("calc.add");



// Make a request expecting a future

CompletableFuture<Message> responseFuture = nc.request("calc.add", "5 3".getBytes(StandardCharsets.UTF_8));

try {

    Message m = responseFuture.get(500, TimeUnit.MILLISECONDS);

    System.out.printf("5 + 3 = %s\n", new String(m.getData()));

}

catch (CancellationException | ExecutionException | TimeoutException e) {

    System.out.println("1) No Response");

}



// Make a request with a timeout and direct response

Message m = nc.request("calc.add", "10 7".getBytes(StandardCharsets.UTF_8), Duration.ofMillis(500));

if (m == null) {

    System.out.println("2) No Response");

}

else {

    System.out.printf("10 + 7 = %s\n", new String(m.getData()));

}



// Make a request with a timeout and direct response

m = nc.request("calc.add", "10 x".getBytes(StandardCharsets.UTF_8), Duration.ofMillis(500));

if (m == null) {

    System.out.println("3) No Response");

}

else {

    System.out.printf("10 + x = %s\n", new String(m.getData()));

}
```

#### Rust

```
// Calculator service - replies with a fixed result for any request

let mut sub = client.subscribe("calc.add").await?;

let service_client = client.clone();

tokio::spawn(async move {

    while let Some(msg) = sub.next().await {

        if let Some(reply) = msg.reply {

            service_client.publish(reply, "42".into()).await.ok();

        }

    }

});



// Make calculations

let resp = client.request("calc.add", "5 3".into()).await?;

println!("5 + 3 = {}", String::from_utf8_lossy(&resp.payload));



let resp = client.request("calc.add", "10 7".into()).await?;

println!("10 + 7 = {}", String::from_utf8_lossy(&resp.payload));
```

#### C#/.NET

```
// Calculator service: takes in an array of integers and replies with the sum

// An integer array would be serialized as a JSON array, while a single integer

// would be serialized as a string, just like all other primitive types.

_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<int[]>("calc.sum"))

    {

        var sum = msg.Data!.Sum();

        await msg.ReplyAsync(sum);

    }

});



// Give the subscription task time to start before publishing

await Task.Delay(1000);



var reply1 = await client.RequestAsync<int[], int>("calc.sum", [5, 3, 1]);

output.WriteLine($"5 + 3 + 1 = {reply1.Data}");



var reply2 = await client.RequestAsync<int[], int>("calc.sum", [10, 7]);

output.WriteLine($"10 + 7 = {reply2.Data}");
```

#### C

```
// Calculator service: parse two numbers and reply with their sum

static void

onCalcAdd(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    int     a = 0;

    int     b = 0;

    char    result[32];



    if (sscanf(natsMsg_GetData(msg), "%d %d", &a, &b) == 2)

    {

        snprintf(result, sizeof(result), "%d", a + b);

        natsConnection_PublishString(nc, natsMsg_GetReply(msg), result);

    }

    natsMsg_Destroy(msg);

}

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&sub, conn, "calc.add", onCalcAdd, NULL);



    // Give the service a moment to be ready, then make calculations

    nats_Sleep(100);



    if (s == NATS_OK)

        s = natsConnection_RequestString(&reply, conn, "calc.add", "5 3", 1000);

    if (s == NATS_OK)

    {

        printf("5 + 3 = %.*s\n",

               natsMsg_GetDataLength(reply), natsMsg_GetData(reply));

        natsMsg_Destroy(reply);

        reply = NULL;



        s = natsConnection_RequestString(&reply, conn, "calc.add", "10 7", 1000);

    }

    if (s == NATS_OK)

        printf("10 + 7 = %.*s\n",

               natsMsg_GetDataLength(reply), natsMsg_GetData(reply));
```

## Next steps

* [Request-reply in the Core NATS deep dive](/learn/core-nats/request-reply.md) — runnable, step-by-step walkthrough
* [The Services framework](/learn/services/.md) — build production request-reply services
