<!-- source: https://docs.nats.io/concepts/queue-groups.md · fetched 2026-08-31 · section: queue-groups -->
# Queue Groups

In standard publish-subscribe, every subscriber receives every message. Queue groups change this: when subscribers share a **queue name**, NATS delivers each message to only **one randomly chosen member** of that group.

**Message flow — Queue group (animated):** Animated queue group: a publisher emits messages; NATS load-balances each message to exactly one worker in the queue group.

* Publisher → Worker 1
* Publisher → Worker 2
* Publisher → Worker 3

Watch how each message (animated dot) flows to only one worker, even though all three are subscribed. NATS automatically distributes the load.

For a runnable, step-by-step treatment, see the [Queue groups in the Core NATS deep dive](/learn/core-nats/queue-groups.md).

## How It Works

Queue groups operate at the subject level - subscribers still filter messages by subject, but NATS adds distribution logic:

1. **Single member**: A lone subscriber in a queue group receives all messages for that subject
2. **Multiple members**: NATS randomly selects one member for each message
3. **Member joins/leaves**: Distribution automatically adjusts without configuration

The queue name is application-defined, not server-configured. Subscribers specify it when subscribing, and NATS handles the rest. Selection is random per message and does not account for how busy a member is. A member stops receiving messages only when its subscription or connection goes away, including when the server disconnects it as a slow consumer; the server then picks among the remaining members.

## Basic Queue Groups

Multiple subscribers use the same queue group name when subscribing to a subject. NATS ensures each message is delivered to only one member of that group, chosen randomly.

Common use cases: background job processing, API request handling across service instances, event processing pipelines, batch operations.

#### CLI

```
# Terminal 1: First worker in queue group

nats sub orders.new --queue workers



# Terminal 2: Second worker in same queue group

nats sub orders.new --queue workers



# Terminal 3: Third worker in same queue group

nats sub orders.new --queue workers



# Terminal 4: Publish messages (distributed across workers)

nats pub orders.new "Order 1"

nats pub orders.new "Order 2"

nats pub orders.new "Order 3"

nats pub orders.new "Order 4"



# Each message goes to exactly one worker
```

#### JavaScript/TypeScript

```
// Create three workers in the same queue group

async function process(label: string) {

  const sub = nc.subscribe("orders.new", { queue: "workers" });

  for await (const msg of sub) {

    console.log(`Worker ${label} processed: ${msg.string()}`);

  }

}



process("A").catch(console.error);

process("B").catch(console.error);

process("C").catch(console.error);



// Publish messages - automatically load balanced

for (let i = 1; i <= 10; i++) {

  nc.publish("orders.new", `Order ${i}`);

}
```

#### Go

```
// Create three workers in the same queue group

nc.QueueSubscribe("orders.new", "workers", func(m *nats.Msg) {

	fmt.Printf("Worker A processed: %s\n", string(m.Data))

})



nc.QueueSubscribe("orders.new", "workers", func(m *nats.Msg) {

	fmt.Printf("Worker B processed: %s\n", string(m.Data))

})



nc.QueueSubscribe("orders.new", "workers", func(m *nats.Msg) {

	fmt.Printf("Worker C processed: %s\n", string(m.Data))

})



// Publish messages - automatically load balanced

for i := 1; i <= 10; i++ {

	nc.Publish("orders.new", []byte(fmt.Sprintf("Order %d", i)))

}
```

#### Python

```
async def worker(sub, name):

    async for msg in sub:

        print(f"Worker {name} Received: {msg.data.decode()}")



sub_a = await nc.subscribe("orders.new", queue="new-orders-queue")

sub_b = await nc.subscribe("orders.new", queue="new-orders-queue")

sub_c = await nc.subscribe("orders.new", queue="new-orders-queue")



asyncio.create_task(worker(sub_a, "A"))

asyncio.create_task(worker(sub_b, "B"))

asyncio.create_task(worker(sub_c, "C"))



# flush() waits for the server to acknowledge all pending commands.

# This ensures all subscriptions are at the server before publish starts.

await nc.flush(timeout=1)



for i in range(1, 11):

    await nc.publish("orders.new", f"Order {i}".encode())
```

#### Java

```
// Worker A

Dispatcher workerA = nc.createDispatcher(msg -> {

    System.out.println("Worker A Received: " +

        new String(msg.getData(), StandardCharsets.UTF_8));

});

workerA.subscribe("orders.new", "new-orders-queue");



// Worker B

Dispatcher workerB = nc.createDispatcher(msg -> {

    System.out.println("Worker B Received: " +

        new String(msg.getData(), StandardCharsets.UTF_8));

});

workerB.subscribe("orders.new", "new-orders-queue");



// Worker C

Dispatcher workerC = nc.createDispatcher(msg -> {

    System.out.println("Worker C Received: " +

        new String(msg.getData(), StandardCharsets.UTF_8));

});

workerC.subscribe("orders.new", "new-orders-queue");



try {

    // flush() queues a ping message and waits for a pong

    // response. This ensures that all the subscriptions

    // are at the server before publish starts

    nc.flush(Duration.ofSeconds(1));

}

catch (TimeoutException e) {

    throw new RuntimeException(e);

}



for (int i = 1; i <= 10; i++) {

    byte[] data = ("Order " + i).getBytes(StandardCharsets.UTF_8);

    nc.publish("orders.new", data);

}
```

#### Rust

```
// Create three workers in the same queue group

let mut worker_a = client

    .queue_subscribe("orders.new", "workers".to_string())

    .await?;



let mut worker_b = client

    .queue_subscribe("orders.new", "workers".to_string())

    .await?;



let mut worker_c = client

    .queue_subscribe("orders.new", "workers".to_string())

    .await?;



// Spawn tasks to process messages

tokio::spawn(async move {

    while let Some(msg) = worker_a.next().await {

        println!(

            "Worker A processed: {}",

            String::from_utf8_lossy(&msg.payload)

        );

    }

});



tokio::spawn(async move {

    while let Some(msg) = worker_b.next().await {

        println!(

            "Worker B processed: {}",

            String::from_utf8_lossy(&msg.payload)

        );

    }

});



tokio::spawn(async move {

    while let Some(msg) = worker_c.next().await {

        println!(

            "Worker C processed: {}",

            String::from_utf8_lossy(&msg.payload)

        );

    }

});



// Publish messages - automatically load balanced

for i in 1..=10 {

    client

        .publish("orders.new", format!("Order {}", i).into())

        .await?;

}
```

#### C#/.NET

```
// Create three workers in the same queue group

_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<string>("orders.new", queueGroup: "new-orders-queue"))

    {

        output.WriteLine($"Worker A processed: {msg.Data}");

    }

});



_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<string>("orders.new", queueGroup: "new-orders-queue"))

    {

        output.WriteLine($"Worker B processed: {msg.Data}");

    }

});



_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<string>("orders.new", queueGroup: "new-orders-queue"))

    {

        output.WriteLine($"Worker C processed: {msg.Data}");

    }

});



// Give the subscription tasks time to start before publishing

await Task.Delay(1000);



// Publish messages once all subscriptions are set up

for (var i = 1; i <= 10; i++)

{

    await client.PublishAsync("orders.new", $"Order Number: {i}");

}
```

#### C

```
// Each worker prints its own name; the closure carries it.

static void

onOrder(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    printf("Worker %s processed: %.*s\n", (const char *) closure,

           natsMsg_GetDataLength(msg), natsMsg_GetData(msg));



    natsMsg_Destroy(msg);

}

    // Create three workers in the same queue group

    if (s == NATS_OK)

        s = natsConnection_QueueSubscribe(&subA, conn, "orders.new",

                                          "workers", onOrder, (void *) "A");

    if (s == NATS_OK)

        s = natsConnection_QueueSubscribe(&subB, conn, "orders.new",

                                          "workers", onOrder, (void *) "B");

    if (s == NATS_OK)

        s = natsConnection_QueueSubscribe(&subC, conn, "orders.new",

                                          "workers", onOrder, (void *) "C");



    // Publish messages - automatically load balanced

    for (int i = 1; (s == NATS_OK) && (i <= 10); i++)

    {

        char order[32];



        snprintf(order, sizeof(order), "Order %d", i);

        s = natsConnection_PublishString(conn, "orders.new", order);

    }
```

## Dynamic Scaling

Add or remove workers at any time and NATS automatically adjusts distribution. When a worker joins, it immediately starts receiving messages. When it leaves, NATS stops routing to it within milliseconds.

Perfect for auto-scaling scenarios where orchestration systems (Kubernetes, ECS) spin up new workers based on metrics. Supports gradual rollouts, traffic spike handling, and cost optimization.

#### CLI

```
# Start with one worker

nats sub tasks --queue workers



# Load increases - add more workers (in new terminals)

nats sub tasks --queue workers

nats sub tasks --queue workers



# Load decreases - stop workers with Ctrl+C

# Remaining workers automatically take over
```

#### JavaScript/TypeScript

```
// Worker that can be dynamically added/removed

function process(id: string): Promise<{id: string, sub: Subscription}> {

  const sub = nc.subscribe("tasks", { queue: "workers" });

  (async () => {

    for await (const msg of sub) {

      console.log(`Worker ${id} processing: ${msg.string()}`);

      // Simulate work

      await delay(100);

    }

  })().catch(console.error);

  return Promise.resolve({ id, sub });

}



setInterval(() => {

  nc.publish("tasks", new Date().toISOString());

}, 50)



// Dynamic scaling

const workers: { id: string, sub: Subscription }[] = [];



// Scale up

for (let i = 1; i <= 5; i++) {

  workers.push(await process(`${i}`));

}



// Scale down

await delay(1000);

const removed = workers.pop();

if (removed) {

  removed.sub.unsubscribe();

}
```

#### Go

```
// Worker that can be dynamically added/removed

type Worker struct {

	ID   string

	sub  *nats.Subscription

	done chan bool

}



NewWorker := func(nc *nats.Conn, id string) *Worker {

	w := &Worker{ID: id, done: make(chan bool)}



	w.sub, _ = nc.QueueSubscribe("tasks", "workers", func(m *nats.Msg) {

		fmt.Printf("Worker %s processing: %s\n", id, string(m.Data))

		// Simulate work

		time.Sleep(100 * time.Millisecond)

	})



	return w

}



Stop := func(w *Worker) {

	w.sub.Unsubscribe()

	close(w.done)

}



// Dynamic scaling

workers := make([]*Worker, 0)



// Scale up

for i := 1; i <= 5; i++ {

	worker := NewWorker(nc, fmt.Sprintf("%d", i))

	workers = append(workers, worker)

}



// Scale down

for i := 0; i < 5; i++ {

	Stop(workers[i])

}
```

#### Python

```
class Worker:

    def __init__(self, worker_id):

        self.id = worker_id

        self.subscription = None

        self.task = None



    async def start(self, nc, subject, queue):

        self.subscription = await nc.subscribe(subject, queue=queue)

        self.task = asyncio.create_task(self._run())



    async def _run(self):

        async for msg in self.subscription:

            print(f"Worker {self.id} processing: {msg.data.decode()}")



    async def stop(self):

        await self.subscription.unsubscribe()





async def main():

    nc = await client.connect("nats://demo.nats.io")



    workers = []

    subject = "tasks"

    queue = "workers"



    # Scale up

    for i in range(1, 6):

        w = Worker(i)

        await w.start(nc, subject, queue)

        workers.append(w)



    # Scale down

    for w in workers:

        await w.stop()



    await nc.close()
```

#### Java

```
static class Worker implements MessageHandler {

    final int id;

    Dispatcher dispatcher;



    public Worker(int id, Connection nc, String subject, String queueName) {

        this.id = id;

        dispatcher = nc.createDispatcher(this); // this is a MessageHandler

        dispatcher.subscribe(subject, queueName);

    }



    @Override

    public void onMessage(Message msg) throws InterruptedException {

        System.out.println("Worker " + id + " processing: " +

            new String(msg.getData(), StandardCharsets.UTF_8));

    }

}



public static void main(String[] args) {

    try (Connection nc = Nats.connect("nats://localhost:4222")) {

        List<Worker> workers = new ArrayList<Worker>();



        String subject = "tasks";

        String queueName = "workers";



        // Scale up

        for (int i = 1; i <= 5; i++) {

            workers.add(new Worker(i, nc, subject, queueName));

        }



        // Scale down

        for (Worker w : workers) {

            w.dispatcher.unsubscribe(subject);

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
// Worker that can be dynamically added/removed

struct Worker {

    handle: tokio::task::JoinHandle<()>,

}



let new_worker = |client: async_nats::Client, id: i32| async move {

    let mut sub = client

        .queue_subscribe("tasks", "workers".to_string())

        .await?;



    let handle = tokio::spawn(async move {

        while let Some(msg) = sub.next().await {

            println!(

                "Worker {} processing: {}",

                id,

                String::from_utf8_lossy(&msg.payload)

            );

        }

    });



    Ok::<Worker, async_nats::Error>(Worker { handle })

};



let mut workers: Vec<Worker> = Vec::new();



// Scale up

for i in 1..=5 {

    workers.push(new_worker(client.clone(), i).await?);

}



// Scale down: drop one worker

if let Some(worker) = workers.pop() {

    worker.handle.abort();

}
```

#### C#/.NET

```
// Start workers in the same queue group; track them so we can scale down later

var workers = new List<INatsSub<string>>();



for (var i = 1; i <= 5; i++)

{

    var id = i;

    var sub = await client.Connection.SubscribeCoreAsync<string>("tasks", queueGroup: "workers");

    _ = Task.Run(async () =>

    {

        await foreach (var msg in sub.Msgs.ReadAllAsync())

        {

            output.WriteLine($"Worker {id} processing: {msg.Data}");

        }

    });

    workers.Add(sub);

}



// Scale down: drop the first worker

await workers[0].DisposeAsync();

workers.RemoveAt(0);
```

#### C

```
// A worker is a queue subscription plus an ID for logging.

typedef struct

{

    char                id[16];

    natsSubscription    *sub;

} Worker;



static void

onTask(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    Worker *w = (Worker *) closure;



    printf("Worker %s processing: %.*s\n", w->id,

           natsMsg_GetDataLength(msg), natsMsg_GetData(msg));

    // Simulate work

    nats_Sleep(100);



    natsMsg_Destroy(msg);

}



static natsStatus

startWorker(Worker *w, natsConnection *nc, int id)

{

    snprintf(w->id, sizeof(w->id), "%d", id);

    return natsConnection_QueueSubscribe(&(w->sub), nc, "tasks",

                                         "workers", onTask, (void *) w);

}



static void

stopWorker(Worker *w)

{

    // Leaving the queue group: remaining members keep sharing the load.

    natsSubscription_Unsubscribe(w->sub);

}

    // Scale up: add five workers to the group

    for (int i = 0; (s == NATS_OK) && (i < 5); i++)

        s = startWorker(&workers[i], conn, i + 1);



    // Scale down: remove them again

    if (s == NATS_OK)

    {

        for (int i = 0; i < 5; i++)

            stopWorker(&workers[i]);

    }
```

## Queue Groups with Request-Reply

Queue groups enable horizontally scalable services without a service mesh or API gateway. Each request goes to exactly one service instance, providing automatic load balancing.

Your service code doesn't need to know about other instances, handle leader election, or coordinate work. Just subscribe with a queue group name and respond to requests.

#### CLI

```
# Terminal 1: Service instance 1

nats reply api.calculate --queue api-workers "Result from instance 1"



# Terminal 2: Service instance 2

nats reply api.calculate --queue api-workers "Result from instance 2"



# Terminal 3: Service instance 3

nats reply api.calculate --queue api-workers "Result from instance 3"



# Terminal 4: Make requests (load balanced across instances)

nats request api.calculate ""

nats request api.calculate ""

nats request api.calculate ""
```

#### JavaScript/TypeScript

```
// Service instance with queue group for load balancing

function createServiceInstance(instanceId: string) {

  const sub = nc.subscribe("api.calculate", { queue: "api-workers" });

  (async () => {

    for await (const msg of sub) {

      const data = msg.string().split(",");

      const result = parseInt(data[0], 10) + parseInt(data[1], 10);

      const response =

        `Result: ${result}, processed by: instance-${instanceId}`;

      msg.respond(response);

      console.log(`Instance ${instanceId} processed request`);

    }

  })().catch(console.error);

}



// Start multiple service instances

for (let i = 1; i <= 3; i++) {

  createServiceInstance(`instance-${i}`);

}



// Make requests - automatically load balanced

for (let i = 0; i < 10; i++) {

  try {

    const response = await nc.request("api.calculate", `${i},${i * 2}`, {

      timeout: 1000,

    });

    console.log(`Response: ${response.string()}`);

  } catch (e) {

    console.error(`Request failed: ${(e as Error).message}`);

  }

}
```

#### Go

```
// Service instance with queue group for load balancing

createServiceInstance := func(nc *nats.Conn, instanceID string) {

	nc.QueueSubscribe("api.calculate", "api-workers", func(m *nats.Msg) {

		// Parse request

		var request map[string]int

		json.Unmarshal(m.Data, &request)



		// Process request

		result := request["a"] + request["b"]



		// Send response

		response := map[string]interface{}{

			"result":      result,

			"processedBy": instanceID,

		}

		responseData, _ := json.Marshal(response)

		m.Respond(responseData)



		fmt.Printf("Instance %s processed request\n", instanceID)

	})

}



// Start multiple service instances

for i := 1; i <= 3; i++ {

	createServiceInstance(nc, fmt.Sprintf("instance-%d", i))

}



// Make requests - automatically load balanced

for i := 0; i < 10; i++ {

	request := map[string]int{"a": i, "b": i * 2}

	requestData, _ := json.Marshal(request)



	msg, _ := nc.Request("api.calculate", requestData, time.Second)



	var response map[string]interface{}

	json.Unmarshal(msg.Data, &response)

	fmt.Printf("Result: %v, processed by: %s\n",

		response["result"], response["processedBy"])

}
```

#### Python

```
async def service_instance(sub, instance_id):

    async for msg in sub:

        parts = msg.data.decode().split(",")

        result = int(parts[0]) + int(parts[1])

        response = f"Result: {result}, processed by: instance-{instance_id}"

        if msg.reply:

            await nc.publish(msg.reply, response.encode())

        print(f"Instance instance-{instance_id} processed request")



# Set up 3 instances of the service

for i in range(1, 4):

    sub = await nc.subscribe("api.calculate", queue="api-workers-queue")

    asyncio.create_task(service_instance(sub, i))



await nc.flush()



# Make requests - messages are balanced among the subscribers in the queue

for i in range(10):

    data = f"{i},{i * 2}"

    try:

        m = await nc.request("api.calculate", data.encode(), timeout=0.5)

        print(m.data.decode())

    except (TimeoutError, NoRespondersError):

        print(f"{i}) No Response")
```

#### Java

```
List<Dispatcher> dispatchers = new ArrayList<>();

// Set up 3 instances of the service

for (int i = 1; i <= 3; i++) {

    final int instanceID = i;

    Dispatcher d = nc.createDispatcher(msg -> {

        String[] data = new String(msg.getData()).split(",");

        int result = Integer.parseInt(data[0]) + Integer.parseInt(data[1]);

        String response = String.format("Result: %d, processed by: instance-%d", result, instanceID);

        nc.publish(msg.getReplyTo(), response.getBytes(StandardCharsets.ISO_8859_1));

        System.out.printf("Instance instance-%d processed request\n", instanceID);

    });

    d.subscribe("api.calculate", "api-workers-queue");

    dispatchers.add(d);

}



// Make requests - messages are balanced among the subscribers in the queue

for (int i = 0; i < 10; i++) {

    String data = String.format("%d,%d", i, i * 2);

    Message m = nc.request("api.calculate", data.getBytes(StandardCharsets.ISO_8859_1), Duration.ofMillis(500));

    if (m == null) {

        System.out.println(i + ") No Response");

    }

    else {

        System.out.println(new String(m.getData()));

    }

}
```

#### Rust

```
// Start multiple service instances with queue group for load balancing

for i in 1..=3 {

    let client = client.clone();

    let instance_id = format!("instance-{}", i);

    let mut sub = client

        .queue_subscribe("api.calculate", "api-workers".to_string())

        .await?;



    tokio::spawn(async move {

        while let Some(msg) = sub.next().await {

            let response = format!("handled by {}", instance_id);



            if let Some(reply) = msg.reply {

                client.publish(reply, response.into()).await.ok();

            }



            println!("Instance {} processed request", instance_id);

        }

    });

}



// Make requests - automatically load balanced

for i in 0..10 {

    let response = client

        .request("api.calculate", format!("request {}", i).into())

        .await?;

    println!("Response: {}", String::from_utf8_lossy(&response.payload));

}
```

#### C#/.NET

```
// Start three service instances sharing the same queue group

for (var i = 1; i <= 3; i++)

{

    var id = i;

    _ = Task.Run(async () =>

    {

        await foreach (var msg in client.SubscribeAsync<string>("api.calculate", queueGroup: "api-workers"))

        {

            await msg.ReplyAsync($"Result from instance {id}");

        }

    });

}



// Give the subscription tasks time to start before publishing

await Task.Delay(1000);



// Make 10 requests; the queue group balances them across instances

var replyOpts = new NatsSubOpts { Timeout = TimeSpan.FromSeconds(1) };

for (var i = 0; i < 10; i++)

{

    var reply = await client.RequestAsync<string>("api.calculate", replyOpts: replyOpts);

    output.WriteLine($"{i}) {reply.Data}");

}
```

#### C

```
// Service instance: parse the request, compute, reply with the result

// and the instance that handled it.

static void

onCalculate(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    const char  *instanceID = (const char *) closure;

    int         a = 0;

    int         b = 0;

    char        response[128];



    // Parse request

    sscanf(natsMsg_GetData(msg), "{\"a\":%d,\"b\":%d}", &a, &b);



    // Process request and send response

    snprintf(response, sizeof(response),

             "{\"result\":%d,\"processedBy\":\"%s\"}", a + b, instanceID);

    if (natsMsg_GetReply(msg) != NULL)

        natsConnection_PublishString(nc, natsMsg_GetReply(msg), response);



    printf("Instance %s processed request\n", instanceID);



    natsMsg_Destroy(msg);

}

    // Start multiple service instances in the same queue group

    for (int i = 0; (s == NATS_OK) && (i < 3); i++)

        s = natsConnection_QueueSubscribe(&subs[i], conn, "api.calculate",

                                          "api-workers", onCalculate,

                                          (void *) ids[i]);



    // Make requests - automatically load balanced

    for (int i = 0; (s == NATS_OK) && (i < 10); i++)

    {

        natsMsg *reply = NULL;

        char    request[64];



        snprintf(request, sizeof(request), "{\"a\":%d,\"b\":%d}", i, i * 2);

        s = natsConnection_RequestString(&reply, conn, "api.calculate",

                                         request, 1000);

        if (s == NATS_OK)

        {

            printf("Reply: %.*s\n",

                   natsMsg_GetDataLength(reply), natsMsg_GetData(reply));

            natsMsg_Destroy(reply);

        }

    }
```

## Mixed Subscribers

Queue groups coexist with regular subscribers on the same subject. Regular subscribers receive every message (pub-sub), while queue group members share the load (work distribution).

Use queue groups for operational work that needs to happen exactly once, and regular subscribers for observational tasks (audit logging, monitoring, analytics).

#### CLI

```
#!/bin/bash



# Terminal 1: Audit logger (sees all messages)

nats sub "orders.>"



# Terminal 2: Worker 1 in queue group

nats sub "orders.new" --queue workers



# Terminal 3: Worker 2 in queue group

nats sub "orders.new" --queue workers



# Terminal 4: Publish messages

nats pub orders.new "Order 123"

# Audit logger sees it

# One worker processes it
```

#### JavaScript/TypeScript

```
// add a function that creates a subscription and optionally processes messages

// in a queue group

function addWorker(label: string, queue = "") {

  const sub = nc.subscribe("orders.new", { queue });

  (async () => {

    for await (const msg of sub) {

      console.log(`[WORKER ${label}] Processing: ${msg.string()}`);

    }

  })().catch(console.error);

}



// Audit logger - receives all messages

addWorker("AUDIT");

// Metrics collector - receives all messages

addWorker("METRICS");



// Workers in queue group - load balanced

addWorker("A", "q");

addWorker("B", "q");



// Publish order

nc.publish("orders.new", "Order 123");

nc.publish("orders.new", "Order 124");

nc.publish("orders.new", "Order 125");
```

#### Go

```
// Audit logger - receives all messages

nc.Subscribe("orders.>", func(m *nats.Msg) {

	log.Printf("[AUDIT] %s: %s", m.Subject, string(m.Data))

})



// Metrics collector - receives all messages

nc.Subscribe("orders.>", func(m *nats.Msg) {

	log.Printf("[METRICS] %s: %s", m.Subject, string(m.Data))

})



// Workers in queue group - load balanced

nc.QueueSubscribe("orders.new", "workers", func(m *nats.Msg) {

	fmt.Printf("[WORKER A] Processing: %s\n", string(m.Data))

	processOrder(m.Data)

})



nc.QueueSubscribe("orders.new", "workers", func(m *nats.Msg) {

	fmt.Printf("[WORKER B] Processing: %s\n", string(m.Data))

	processOrder(m.Data)

})



// Publish orders

nc.Publish("orders.new", []byte("Order 123"))

nc.Publish("orders.new", []byte("Order 124"))

// Audit and metrics see them, one worker processes each
```

#### Python

```
async def reader(sub, label):

    async for msg in sub:

        print(f"[{label}] {msg.subject}: {msg.data.decode()}")



# Audit logger - receives all messages

audit_sub = await nc.subscribe("orders.>")

asyncio.create_task(reader(audit_sub, "AUDIT"))



# Metrics collector - receives all messages

metrics_sub = await nc.subscribe("orders.>")

asyncio.create_task(reader(metrics_sub, "METRICS"))



# Workers in queue group - load balanced

worker_a_sub = await nc.subscribe("orders.new", queue="new-orders-queue")

asyncio.create_task(reader(worker_a_sub, "WORKER A"))



worker_b_sub = await nc.subscribe("orders.new", queue="new-orders-queue")

asyncio.create_task(reader(worker_b_sub, "WORKER B"))



await nc.flush()



# Publish order

await nc.publish("orders.new", b"Order 123")

await nc.publish("orders.new", b"Order 124")

# Audit and metrics see them, one worker processes each
```

#### Java

```
// Audit logger - receives all messages

Dispatcher dAudit = nc.createDispatcher(msg -> {

    System.out.printf("[AUDIT] %s: %s\n", msg.getSubject(), new String(msg.getData(), StandardCharsets.UTF_8));

});

dAudit.subscribe("orders.>");



Dispatcher dMetrics = nc.createDispatcher(msg -> {

    System.out.printf("[METRICS] %s: %s\n", msg.getSubject(), new String(msg.getData(), StandardCharsets.UTF_8));

});

dMetrics.subscribe("orders.>");



Dispatcher dNewOrderWorker1 = nc.createDispatcher(msg -> {

    System.out.printf("[WORKER A] %s: %s\n", msg.getSubject(), new String(msg.getData(), StandardCharsets.UTF_8));

});

dNewOrderWorker1.subscribe("orders.new", "new-orders-queue");



Dispatcher dNewOrderWorker2 = nc.createDispatcher(msg -> {

    System.out.printf("[WORKER B] %s: %s\n", msg.getSubject(), new String(msg.getData(), StandardCharsets.UTF_8));

});

dNewOrderWorker2.subscribe("orders.new", "new-orders-queue");



// Publish order

nc.publish("orders.new", "Order 123".getBytes(StandardCharsets.ISO_8859_1));

nc.publish("orders.new", "Order 124".getBytes(StandardCharsets.ISO_8859_1));

// Audit and metrics see them, one worker processes each
```

#### Rust

```
// Audit logger - receives all messages

let mut audit_sub = client.subscribe("orders.>").await?;

tokio::spawn(async move {

    while let Some(msg) = audit_sub.next().await {

        println!(

            "[AUDIT] {}: {}",

            msg.subject,

            String::from_utf8_lossy(&msg.payload)

        );

    }

});



// Metrics collector - receives all messages

let mut metrics_sub = client.subscribe("orders.>").await?;

tokio::spawn(async move {

    while let Some(msg) = metrics_sub.next().await {

        println!(

            "[METRICS] {}: {}",

            msg.subject,

            String::from_utf8_lossy(&msg.payload)

        );

    }

});



// Workers in queue group - load balanced

let mut worker_a = client

    .queue_subscribe("orders.new", "workers".to_string())

    .await?;

tokio::spawn(async move {

    while let Some(msg) = worker_a.next().await {

        println!(

            "[WORKER A] Processing: {}",

            String::from_utf8_lossy(&msg.payload)

        );

    }

});



let mut worker_b = client

    .queue_subscribe("orders.new", "workers".to_string())

    .await?;

tokio::spawn(async move {

    while let Some(msg) = worker_b.next().await {

        println!(

            "[WORKER B] Processing: {}",

            String::from_utf8_lossy(&msg.payload)

        );

    }

});



// Publish order

client.publish("orders.new", "Order 123".into()).await?;

client.publish("orders.new", "Order 124".into()).await?;

// Audit and metrics see them, one worker processes each
```

#### C#/.NET

```
// Audit logger - receives all order messages

_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<string>("orders.>"))

    {

        output.WriteLine($"[AUDIT] {msg.Subject}: {msg.Data}");

    }

});



// Metrics collector - receives all order messages

_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<string>("orders.>"))

    {

        output.WriteLine($"[METRICS] {msg.Subject}: {msg.Data}");

    }

});



// Workers - share load via a queue group

_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<string>("orders.new", queueGroup: "workers"))

    {

        output.WriteLine($"[WORKER A] Processing: {msg.Data}");

    }

});



_ = Task.Run(async () =>

{

    await foreach (var msg in client.SubscribeAsync<string>("orders.new", queueGroup: "workers"))

    {

        output.WriteLine($"[WORKER B] Processing: {msg.Data}");

    }

});



// Give the subscription tasks time to start before publishing

await Task.Delay(1000);



// Audit and metrics see every message; one worker processes each

await client.PublishAsync("orders.new", "Order 123");
```

#### C

```
// Regular subscribers receive every message; the closure names them.

static void

onAll(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    printf("[%s] %s: %.*s\n", (const char *) closure,

           natsMsg_GetSubject(msg),

           natsMsg_GetDataLength(msg), natsMsg_GetData(msg));



    natsMsg_Destroy(msg);

}



// Queue group members share the load: one worker per message.

static void

onWork(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    printf("[WORKER %s] Processing: %.*s\n", (const char *) closure,

           natsMsg_GetDataLength(msg), natsMsg_GetData(msg));



    natsMsg_Destroy(msg);

}

    // Audit logger - receives all messages

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&audit, conn, "orders.>",

                                     onAll, (void *) "AUDIT");



    // Metrics collector - receives all messages

    if (s == NATS_OK)

        s = natsConnection_Subscribe(&metrics, conn, "orders.>",

                                     onAll, (void *) "METRICS");



    // Workers in queue group - load balanced

    if (s == NATS_OK)

        s = natsConnection_QueueSubscribe(&workA, conn, "orders.new",

                                          "workers", onWork, (void *) "A");

    if (s == NATS_OK)

        s = natsConnection_QueueSubscribe(&workB, conn, "orders.new",

                                          "workers", onWork, (void *) "B");



    // Publish orders

    if (s == NATS_OK)

        s = natsConnection_PublishString(conn, "orders.new", "Order 123");

    if (s == NATS_OK)

        s = natsConnection_PublishString(conn, "orders.new", "Order 124");

    // Audit and metrics see them, one worker processes each
```

## Geo-Affinity in Super-Clusters

In globally distributed NATS super-clusters, queue groups exhibit **geo-affinity** - automatically preferring local workers when available.

### How It Works

When you have queue group subscribers distributed across multiple regions:

1. **Local preference**: Messages are delivered to workers in the same cluster/region as the publisher
2. **Automatic failover**: If no local workers are available, NATS routes to workers in other regions
3. **No configuration needed**: This happens automatically based on network topology

### Example Scenario

Consider a queue group named `"order-processors"` with workers in three regions:

| Region      | Workers   | Publisher Location |
| ----------- | --------- | ------------------ |
| **US-East** | 3 workers | ✅ Publisher here  |
| **US-West** | 2 workers | -                  |
| **EU-West** | 2 workers | -                  |

**Result**: Messages from the US-East publisher are preferentially delivered to the 3 US-East workers. Only if all US-East workers are unavailable will messages route to US-West or EU-West workers.

### Benefits

* **Lower latency**: Local processing is faster
* **Reduced bandwidth**: Fewer cross-region transfers
* **Natural failover**: Automatic global distribution if local workers fail
* **No configuration**: Works out of the box in super-clusters

## Best Practices

### Naming Conventions

Queue groups follow similar naming conventions as subjects. Here are some common patterns:

```
# Service-based naming

api.auth.workers

api.payments.workers

api.notifications.workers



# Environment-based naming

prod.order-processors

staging.order-processors

dev.order-processors



# Version-based naming

service.v1.workers

service.v2.workers
```

### Worker Design

1. **At-most-once delivery**: Core queue groups never redeliver — a message sent to a worker that crashes mid-processing is lost. For redelivery and durability, use [JetStream worker pools](/learn/jetstream/worker-pool.md). Duplicates come only from publisher retries, so make processing idempotent if the publisher may resend.
2. **Graceful shutdown**: Drain messages before stopping
3. **Error handling**: Failed messages should be handled appropriately
4. **Health checks**: Monitor worker health and availability

### Scaling Strategy

1. **Start small**: Begin with few workers
2. **Monitor metrics**: Track queue depth and processing time
3. **Scale based on load**: Add workers when queue grows
4. **Auto-scaling**: Use metrics to automatically scale

### Monitoring

Track these metrics for queue groups:

* Message processing rate
* Queue depth (with JetStream)
* Worker count
* Processing latency
* Error rates

## Next steps

* [Queue groups in the Core NATS deep dive](/learn/core-nats/queue-groups.md) — runnable, step-by-step walkthrough
* [Services](/learn/services/.md) — queue-group load balancing for services
* [JetStream worker pools](/learn/jetstream/worker-pool.md) — durable work distribution at scale
* [Request-Reply](/concepts/request-reply.md) — synchronous communication patterns
* [Publish-Subscribe](/concepts/pub-sub-basics.md) — one-to-many messaging
