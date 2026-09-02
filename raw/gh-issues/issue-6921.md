<!-- source: https://github.com/nats-io/nats-server/issues/6921 (GitHub GraphQL API, repository.issue(number:)) · fetched 2026-09-03 -->
# nats-server issue #6921 — Explicit Acks on JetStream with multiple messages per subject causes deadlock

State: CLOSED — closed 2025-10-01 as `completed` (no closing PR recorded on the issue; the last comment, the same minute, is a maintainer's "Thanks for confirming!" after the reporter bisected the fix to v2.11.5) · opened 2025-05-23 by @Jgfrausing · labels: defect · comments: 15

Cross-references (from the issue timeline):
- nats-io/nats-server#6795 (Issue) — MaxMsgsPerSubject not working as intended [v2.11.1] — https://github.com/nats-io/nats-server/issues/6795
- nats-io/nats-server#6772 (Issue) — Jetstream / MessageConsumer not working in Kubernetes environment — https://github.com/nats-io/nats-server/issues/6772

## Original post

### Observed behavior

[Repost of issue in nats.net](https://github.com/nats-io/nats.net/issues/860)

### Observed behavior

I'm sorry if this is not a bug, but I cannot find any documentation to why this should be the behavior.

## TLDR
JetStream with multiple messages per subject and a consumer with Explicit ACK that only cares about last message per subject. Some *ACKs* are not registered causing the message to being redelivered. 

## Setup
I have the following JetStream:

```bash
Information for Stream CONTRACTS created 2024-12-05 09:38:36

              Subjects: contracts.>
              Replicas: 1
               Storage: File

Options:

             Retention: Limits
       Acknowledgments: true
        Discard Policy: Old
      Duplicate Window: 2m0s
     Allows Msg Delete: true
          Allows Purge: true
        Allows Rollups: false

Limits:

      Maximum Messages: unlimited
   Maximum Per Subject: 5           # This seems to be the cause of the issue
         Maximum Bytes: unlimited
           Maximum Age: 2d0h0m0s
  Maximum Message Size: unlimited
     Maximum Consumers: unlimited

...
```

And I subscribe using:

```csharp
  ...
            AckPolicy = ConsumerConfigAckPolicy.Explicit,
            DeliverPolicy = ConsumerConfigDeliverPolicy.LastPerSubject,
  ...
```

After a few successfully ACKed messages the producer stalls as it no longer receives the ACK. After the wait time the messages are being redelivered, but ACK are still not registered. This is visible by the `Acknowledgment Floor` not changing its sequence number and that `Unprocessed messages` remain the same.

The Outstanding ACKs would be "1000 out of maximum 1000". I also tried with higher and lower values. 

Changing `WaitTime` to 30 seconds (default is 2) also did not resolve anything.

## Work-around
Changing the AckPolicy to None or the DeliverPolicy to All resolves the issue



### Expected behavior



With a stream with subjects/messages like:
foo.bar/1, foo.more/2, foo.bar/3, .., foo.more/89

And a consumer that must ACK explicit and only cares about the last message on each subject.

I would expect:
- the consumer to receive foo.bar/3 and foo.more/89 (and whatever else is available inbetween)
- That no messages are being redelivered
- Unprocessed messages goes gradually down to 0

### Server and client version


2.11.1-binary
0.1.6


### Host environment

_No response_

### Steps to reproduce

Setting the `Max ACK Pending` to 1 and a high `Wait Time` ensures that the program pauses exactly when the issue arises.

## Comment — @Jgfrausing (2025-05-23)

I've also been able to reproduce this issue in Rust, indicating that this might be a server bug. (or two individual implementations having the same issue)

I'm really unsure if this is faulty behavior or if I'm missing some general understanding.

## Comment — @swb2-izu-ssp (2025-05-23)

If you are only interested in the last message for a given subject, why not setting 
 _Maximum Per Subject: 1_      
I suppose in this case, there is no more ACK issue.

Nicolas

## Comment — @neilalexander (2025-05-23)

Can you please check if this still reproduces on 2.11.4? There was a fix around last message per subject included there.

## Comment — @Jgfrausing (2025-05-23)

> If you are only interested in the last message for a given subject, why not setting _Maximum Per Subject: 1_ I suppose in this case, there is no more ACK issue.
> 
> Nicolas

@swb2-izu-ssp correct. But just because one consumer needs only the last, it might be, that others need more.

## Comment — @Jgfrausing (2025-05-23)

> Can you please check if this still reproduces on 2.11.4? There was a fix around last message per subject included there.

@neilalexander that is a good first step. I'll see if I can get around to do that next week. I will report back. 👍

## Comment — @neilalexander (2025-05-23)

Just as an FYI I think it's #6899 that fixed this, which is in 2.11.4. Do let us know how you get on.

## Comment — @Jgfrausing (2025-05-26)

@neilalexander the 2.11.4 did not solve it, unfortunately. :( 

As you can see with the following two consumers, the only thing I change is from `Deliver Policy='Last Per Subject'` to `'All'`. I have `Max Ack Pending=1` in both cases to make the stalling/deadlock easily detectable. Anyway, the first scenario the first message is acked correctly after which, consumer sequence for the acknowledge floor is stuck at 1. (for 58 seconds when I ran the command).

In the other case each message is acked immediately (~1ms after delivery). 

### Stalling
```bash
➜  ~ nats consumer info CONTRACTS myconsumer
Information for Consumer CONTRACTS > myconsumer created 2025-05-26T08:46:38+02:00

Configuration:

                    Name: myconsumer
               Pull Mode: true
          Filter Subject: >
          Deliver Policy: Last Per Subject
              Ack Policy: Explicit
                Ack Wait: 30.00s
           Replay Policy: Instant
      Maximum Deliveries: 3
         Max Ack Pending: 1
       Max Waiting Pulls: 512

Metadata:

             _nats.level: 1
         _nats.req.level: 0
               _nats.ver: 2.11.4

State:

  Last Delivered Message: Consumer sequence: 3 Stream sequence: 77,826,706 Last delivery: 26.17s ago
    Acknowledgment Floor: Consumer sequence: 1 Stream sequence: 77,826,605 Last Ack: 56.18s ago
        Outstanding Acks: 1 out of maximum 1
    Redelivered Messages: 1
    Unprocessed Messages: 70,382
           Waiting Pulls: 0 of maximum 512
```

### Successful
```bash
➜  ~ nats consumer info CONTRACTS myconsumer
Information for Consumer CONTRACTS > myconsumer created 2025-05-26T08:49:07+02:00

Configuration:

                    Name: myconsumer
               Pull Mode: true
          Filter Subject: >
          Deliver Policy: All
              Ack Policy: Explicit
                Ack Wait: 30.00s
           Replay Policy: Instant
      Maximum Deliveries: 3
         Max Ack Pending: 1
       Max Waiting Pulls: 512

Metadata:

             _nats.level: 1
         _nats.req.level: 0
               _nats.ver: 2.11.4

State:

  Last Delivered Message: Consumer sequence: 308 Stream sequence: 77,826,854 Last delivery: 16ms ago
    Acknowledgment Floor: Consumer sequence: 307 Stream sequence: 77,826,853 Last Ack: 17ms ago
        Outstanding Acks: 1 out of maximum 1
    Redelivered Messages: 0
    Unprocessed Messages: 244,374
           Waiting Pulls: 1 of maximum 512
```

## Comment — @Jgfrausing (2025-06-06)

I think it might not be a server issue. I can reproduce it in both Rust and CSharp, but am unable to do so in Golang. It might be, that I'm doing something different in the go implementation so before I jump to any conclusions, then maybe you can help verify?

# Setup nats
```bash
docker run -d --name nats -p 4222:4222 -p 8222:8222 nats -js
```

```bash
nats context add --select local

nats stream add --max-msgs-per-subject=5 --subjects "five.>" --max-age 1h --storage file FIVE --defaults

nats pub five.1 1 && nats pub five.1 2 && nats pub five.2 1 && nats pub five.2 2 && nats pub five.3 1 && nats pub five.3 2 && nats pub five.4 1 && nats pub five.4 2 && nats pub five.5 1 && nats pub five.5 2
```

# C#: Not working implementation

**make sure you are in your desired code folder**

```bash
mkdir NetExample && cd NetExample
dotnet new console
dotnet add package NATS.net

cat > Program.cs << 'EOF'
using NATS.Client.JetStream.Models;
using NATS.Net;

const string consumerName = "Consumer";
var js = new NatsClient().CreateJetStreamContext();

try { await js.DeleteConsumerAsync("FIVE", consumerName); }
catch (Exception e) { /* ignored */ }

var jsConsumer = await js.CreateOrUpdateConsumerAsync("FIVE", new ConsumerConfig()
{
    Name = consumerName,
    DurableName= consumerName,
    AckPolicy = ConsumerConfigAckPolicy.Explicit,
    DeliverPolicy = ConsumerConfigDeliverPolicy.LastPerSubject,
    FilterSubject = ">",
    MaxAckPending = 1,
}); 

await foreach (var message in jsConsumer.ConsumeAsync<string>())
{
    Console.WriteLine($"{message.Subject}: {message.Data}");
    await message.AckAsync();
}
EOF

dotnet run
```

I'm not sure, if it is consistently failing, but if it works the first time, then just run `dotnet run` from within the Example folder. 


# Go: Working implementation

**make sure you are in your desired code folder**

```bash
mkdir -p GoExample && cd GoExample
go mod init example.com/jsfetch

go get github.com/nats-io/nats.go@latest

cat > main.go << 'EOF'
package main

import (
	"context"
	"log"
	"time"

	"github.com/nats-io/nats.go"
)

func main() {
	nc, _ := nats.Connect(nats.DefaultURL)
	defer nc.Drain()

	js, _ := nc.JetStream()

	consumerName := "Consumer"

	_ = js.DeleteConsumer("FIVE", consumerName);

	_, _ = js.AddConsumer("FIVE", &nats.ConsumerConfig{
		Durable:       consumerName,
		AckPolicy:     nats.AckExplicitPolicy,
		DeliverPolicy: nats.DeliverLastPerSubjectPolicy,
		FilterSubject: "five.>",
	})

	sub, _ := js.PullSubscribe(
		"five.>",
		consumerName,
		nats.BindStream("FIVE"),
		nats.DeliverLastPerSubject(),
	)

	for {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		msgs, _ := sub.Fetch(1, nats.Context(ctx))
		cancel()

		if len(msgs) == 1 {
			msg := msgs[0]
			log.Printf("%s: %s", msg.Subject, string(msg.Data))
			msg.Ack()
		}
	}
}
EOF

go build -o fetcher
./fetcher
```

## Comment — @osery (2025-06-08)

Hi, I am having the same issue. With server versions 2.11.0+.

@Jgfrausing looking at your Go implementation, could it be that you are missing the `MaxAckPending: 1` setting and thus using the default of 1000?

## Comment — @Jgfrausing (2025-06-11)

> Hi, I am having the same issue. With server versions 2.11.0+.
> 
> [@Jgfrausing](https://github.com/Jgfrausing) looking at your Go implementation, could it be that you are missing the `MaxAckPending: 1` setting and thus using the default of 1000?

Awesome, @osery !!
Yes that was exactly what was missing. Changing the PullSubscriber to 

```golang
sub, _ := js.PullSubscribe(
		"five.>",
		consumerName,
		nats.BindStream("FIVE"),
		nats.DeliverLastPerSubject(),
		MaxAckPending: 1,
	)
```
Trigger the exact same behavior as in rust and C#. 

I'm still very certain that it is not `MaxAckPending` that is the issue. I believe that the it makes it more likely to occur, though. In my actual code, it was unset (default 1000), but the messages where more than 50k with up to 5 duplicates on each subject.

## Comment — @osery (2025-06-11)

> I'm still very certain that it is not `MaxAckPending` that is the issue. I believe that the it makes it more likely to occur, though. In my actual code, it was unset (default 1000), but the messages where more than 50k with up to 5 duplicates on each subject.

Yes, I agree. We had the same issue with 1000, just happening less often.

Sadly, we cannot use the workaround in https://github.com/nats-io/nats-server/issues/6921#issuecomment-2903668125 because we have a stream consumed by a mix of consumers with LastPerSubject and New policies.

## Comment — @osery (2025-09-30)

Any update on this issue? It is currently blocking us in updating past version 2.11.0.

## Comment — @neilalexander (2025-09-30)

Would you be willing to confirm if this is still an issue on 2.12.1-RC.1?

## Comment — @osery (2025-10-01)

Apologies. I should have tried before pinging the bug. I bisected, and the issues seems to have been fixed in 2.11.5.
I think this issue can be closed. Thanks for fixing :pray:.

## Comment — @neilalexander (2025-10-01)

Thanks for confirming!
