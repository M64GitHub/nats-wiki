<!-- source: https://github.com/nats-io/nats-server/issues/5106 (GitHub GraphQL API) · fetched 2026-09-02 -->
# nats-server issue #5106 — Object Store replication from LeafNode to Cluster nats: error: nats: no stream matches subject

State: CLOSED — closed 2024-03-04 by @b3rtram (no closing PR recorded) · opened 2024-02-19 by @b3rtram · labels: defect · comments: 11

Cross-references (from the issue timeline):
- nats-io/nats.go#1568 (PullRequest, merged) — chore: Bind Object Store bucket stream when getting object. — https://github.com/nats-io/nats.go/pull/1568
- nats-io/nats.js#155 (Issue, open) — Support mirrored ObjectStore — https://github.com/nats-io/nats.js/issues/155
- nats-io/nats.go#1874 (Issue, open) — Support mirrored ObjectStore — https://github.com/nats-io/nats.go/issues/1874

## Original post

### Observed behavior

I have a nats leaf-node port 6222 and a normal nats-server on port 4222. On leaf-node I will add files to object store and replicate it to the connected nats-server.  The Jetstream data is replicated from leaf node to nats server:

nats --server=localhost:4222 object ls

```
╭─────────────────────────╮
 │                          Object Store Buckets                         │
├────┬─────┬───────┬───┬──────┤
│ Bucket     │ Description │ Created           │ Size     │ Last Update │
├────┼─────┼───────┼───┼─────┤
│ dms_mirror │             │ 2024-02-19 17:43:10 │ 34 MiB │ 21m13s      │
╰────┴───┴───────────┴───┴─────╯

```


 but when I try to list the files there is an error:  

nats --server=localhost:4222 object ls dms                                                                             
`**nats: error: nats: stream not found**
`


### Expected behavior

nats --server=localhost:4222 object ls dms should show the same files like on the leaf node

nats --server=localhost:6222 object ls dms                                                                             
```
╭─────────────────────────────────────────────────╮
│                 Bucket Contents                 │
├────────────┬────────┬───────────────────────────┤
│ Name       │ Size   │ Time                      │
├────────────┼────────┼───────────────────────────┤
│ titel0.pdf │ 34 MiB │ 2024-02-19T17:22:53+01:00 │
╰────────────┴────────┴───────────────────────────╯

```


### Server and client version

nats-server: v2.10.11
nats-cli: 0.1.3

### Host environment

- Macbook Pro M2 16GB

### Steps to reproduce


Nats-server config:

```
server_name: nats-cluster-1
listen: 127.0.0.1:4222

leafnodes {
    port: 7422
}

jetstream {
    store_dir: "./data/cluster/store"
    domain: cluster
}

debug: true
```

Leaf Node config

```
server_name: nats-leaf-node
listen: 127.0.0.1:6222

leafnodes {
    remotes [
        {
            url: "nats://0.0.0.0:7422"
        }
    ]
}

jetstream: {
    store_dir: "./data/leaf/store"
    domain: leafnode
}

debug: false
```

Adding Object Store and files with Golang

```
	nc, err := nats.Connect("localhost:6222")
	if err != nil {
		fmt.Println(err)
	}

	js, err := nc.JetStream(nats.PublishAsyncMaxPending(256))
	if err != nil {
		fmt.Println(err)
	}

	obj, err := js.CreateObjectStore(&nats.ObjectStoreConfig{
		Bucket: "dms",
	})
	if err != nil {
		fmt.Println(err)
	}

	filePath := "./data/titel1.pdf"
	fileData, err := os.ReadFile(filePath)
	if err != nil {
		fmt.Println(err)
	}

	//go consume()

	i := 0
	for {
		obj.PutBytes("titel"+strconv.Itoa(i)+".pdf", fileData, nil)
		time.Sleep(10 * time.Second)
		i++
	}
```

leaf-node:
nats --server=localhost:6222 object info dms
                                                                           
```
Information for Object Store Bucket dms created 2024-02-19T17:57:00+01:00

Configuration:

          Bucket Name: dms
             Replicas: 1
                  TTL: unlimited
               Sealed: false
                 Size: 34 MiB
  Maximum Bucket Size: unlimited
   Backing Store Kind: JetStream
     JetStream Stream: OBJ_dms

Cluster Information:

                 Name: nats-leaf-node
               Leader: nats-leaf-node
```

Mirror OBJ_dms
nats --server=localhost:4222 stream add OBJ_dms_mirror --mirror OBJ_dms                                              
```

? Storage file
? Replication 1
? Retention Policy Limits
? Discard Policy Old
? Stream Messages Limit -1
? Total Stream Size -1
? Message TTL -1
? Max Message Size -1
? Allow message Roll-ups Yes
? Allow message deletion Yes
? Allow purging subjects or the entire stream Yes
? Adjust mirror start No
? Adjust mirror filter and transform No
? Import mirror from a different JetStream domain Yes
? Foreign JetStream domain name leafnode
? Delivery prefix 
Stream OBJ_dms_mirror was created

Information for Stream OBJ_dms_mirror created 2024-02-19 17:58:57

              Replicas: 1
               Storage: File

Options:

             Retention: Limits
       Acknowledgments: true
        Discard Policy: Old
      Duplicate Window: 0s
            Direct Get: true
     Allows Msg Delete: true
          Allows Purge: true
        Allows Rollups: true

Limits:

      Maximum Messages: unlimited
   Maximum Per Subject: unlimited
         Maximum Bytes: unlimited
           Maximum Age: unlimited
  Maximum Message Size: unlimited
     Maximum Consumers: unlimited

Replication:

                Mirror: OBJ_dms, API Prefix: $JS.leafnode.API

Mirror Information:

           Stream Name: OBJ_dms
                   Lag: 0
             Last Seen: never
       Ext. API Prefix: $JS.leafnode.API

State:

              Messages: 0
                 Bytes: 0 B
        First Sequence: 0
         Last Sequence: 0
      Active Consumers: 0
```

Jetstream is mirrored
nats  --server=localhost:4222 object ls                                                                              
```
╭───────────────────────────────────────────────────────────────────────╮
│                          Object Store Buckets                         │
├────────────┬─────────────┬─────────────────────┬────────┬─────────────┤
│ Bucket     │ Description │ Created             │ Size   │ Last Update │
├────────────┼─────────────┼─────────────────────┼────────┼─────────────┤
│ dms_mirror │             │ 2024-02-19 17:58:57 │ 34 MiB │ 2m3s        │
╰────────────┴─────────────┴─────────────────────┴────────┴─────────────╯
```

But showing files inside causes an error:

nats  --server=localhost:4222 object ls dms_mirror         
                                                         
`### nats: error: nats: no stream matches subject`

## Comment — @derekcollison (2024-02-19)

Will have some folks take a look @b3rtram, will circle back.

## Comment — @b3rtram (2024-02-19)

Additional Info, a stream with OBJ_dms_mirror is created

./nats  --server=localhost:4222 stream ls -a        
                                       
```
╭───────────────────────────────────────────────────────────────────────────────────────╮
│                                        Streams                                        │
├────────────────┬─────────────┬─────────────────────┬──────────┬────────┬──────────────┤
│ Name           │ Description │ Created             │ Messages │ Size   │ Last Message │
├────────────────┼─────────────┼─────────────────────┼──────────┼────────┼──────────────┤
│ OBJ_dms_mirror │             │ 2024-02-19 17:58:57 │ 270      │ 34 MiB │ 3h1m5s       │
╰────────────────┴─────────────┴─────────────────────┴──────────┴────────┴──────────────╯

```

## Comment — @Jarema (2024-02-20)

There are two reasons why this fails: 

First of all, CLI assumes that the subject name where to look for metadata and chunks is aligned with stream name, which is not the case for mirrors.
This one can be fix with stream subject tranform.

However, CLI also sends request to list all streams by subject, and that does not include mirrors.
We're figuring this one now.

## Comment — @b3rtram (2024-02-20)

can you give me a hint how to the stream subject transform should look like ?

## Comment — @Jarema (2024-02-20)

sure.

```
❯ nats s info --all
[localhost] ? Select a Stream OBJ_mirror
Information for Stream OBJ_mirror created 2024-02-20 11:31:47

                      Replicas: 1
                       Storage: File

Options:

                     Retention: Limits
               Acknowledgments: true
                Discard Policy: New
              Duplicate Window: 0s
                    Direct Get: true
             Allows Msg Delete: true
                  Allows Purge: true
                Allows Rollups: true

Limits:

              Maximum Messages: unlimited
           Maximum Per Subject: unlimited
                 Maximum Bytes: unlimited
                   Maximum Age: unlimited
          Maximum Message Size: unlimited
             Maximum Consumers: unlimited

Replication:

                        Mirror: OBJ_dms, API Prefix: $JS.leafnode.API

Mirror Information:

                   Stream Name: OBJ_dms
  Subject Filter and Transform: $O.dms.> to $O.mirror.>
                           Lag: 0
                     Last Seen: 976ms
               Ext. API Prefix: $JS.leafnode.API

State:

                      Messages: 2
                         Bytes: 462 B
                First Sequence: 1 @ 2024-02-20 11:04:29 UTC
                 Last Sequence: 2 @ 2024-02-20 11:04:29 UTC
              Active Consumers: 0
            Number of Subjects: 2

```

So you need to transform from the `$O.bucket.>` into `$O.mirror_bucket_name.>`.
Don't forget about the Object Store prefixes in names.

## Comment — @b3rtram (2024-03-02)

I tried a little but I did not get it work. I add the transform:

Information for Stream OBJ_dms_mirror created 2024-03-02 16:56:12

```
                      Replicas: 1
                       Storage: File

Options:

                     Retention: Limits
               Acknowledgments: true
                Discard Policy: Old
              Duplicate Window: 0s
                    Direct Get: true
             Allows Msg Delete: true
                  Allows Purge: true
                Allows Rollups: true

Limits:

              Maximum Messages: unlimited
           Maximum Per Subject: unlimited
                 Maximum Bytes: unlimited
                   Maximum Age: unlimited
          Maximum Message Size: unlimited
             Maximum Consumers: unlimited

Replication:

                        Mirror: OBJ_dms, API Prefix: $JS.leafnode.API

Mirror Information:

                   Stream Name: OBJ_dms
  Subject Filter and Transform: $O.dms.> to $O.dms_mirror.>
                           Lag: 0
                     Last Seen: 852µs
               Ext. API Prefix: $JS.leafnode.API

State:

                      Messages: 2,700
                         Bytes: 335 MiB
                First Sequence: 271 @ 2024-03-02 16:35:47 UTC
                 Last Sequence: 2,970 @ 2024-03-02 16:35:48 UTC
              Active Consumers: 0
            Number of Subjects: 20
```

Then I tried to get the documents by the following code:

```
package main

import (
	"fmt"

	"github.com/nats-io/nats.go"
)

func main() {
	nc, err := nats.Connect("localhost:4222")
	if err != nil {
		fmt.Println(err)
	}

	js, err := nc.JetStream(nats.PublishAsyncMaxPending(256))
	if err != nil {
		fmt.Println(err)
	}

	obj, err := js.ObjectStore("dms_mirror")
	if err != nil {
		fmt.Println(err)
	}

	watch, _ := obj.List()
	fmt.Println(watch)
}
```

But the output is an empty array:

```
go run main.go
[]
```

```
╭────────────────────────────────────────────────────────────────────────╮
│                          Object Store Buckets                          │
├────────────┬─────────────┬─────────────────────┬─────────┬─────────────┤
│ Bucket     │ Description │ Created             │ Size    │ Last Update │
├────────────┼─────────────┼─────────────────────┼─────────┼─────────────┤
│ dms_mirror │             │ 2024-03-02 16:56:12 │ 335 MiB │ 29m56s      │
╰────────────┴─────────────┴─────────────────────┴─────────┴─────────────╯

```

What do I need to do??

I add a Trace of the central server 4222 where it does not work:

```
[97662] 2024/03/02 17:51:07.519680 [INF] -------------------------------------------
[97662] 2024/03/02 17:51:07.521029 [INF]   Starting restore for stream '$G > OBJ_dms_mirror'
[97662] 2024/03/02 17:51:07.523112 [INF]   Restored 2,700 messages for stream '$G > OBJ_dms_mirror' in 2ms
[97662] 2024/03/02 17:51:07.523573 [INF] Listening for leafnode connections on 0.0.0.0:7422
[97662] 2024/03/02 17:51:07.524534 [INF] Listening for client connections on 127.0.0.1:4222
[97662] 2024/03/02 17:51:07.524541 [INF] Server is ready
[97662] 2024/03/02 17:51:12.672494 [TRC] JETSTREAM - <-> [DELSUB 3]
[97662] 2024/03/02 17:51:26.553758 [TRC] 127.0.0.1:58397 - cid:8 - <<- [CONNECT {"verbose":false,"pedantic":false,"tls_required":false,"name":"","lang":"go","version":"1.16.0","protocol":1,"echo":true,"headers":true,"no_responders":true}]
[97662] 2024/03/02 17:51:26.554154 [TRC] 127.0.0.1:58397 - cid:8 - <<- [PING]
[97662] 2024/03/02 17:51:26.554175 [TRC] 127.0.0.1:58397 - cid:8 - ->> [PONG]
[97662] 2024/03/02 17:51:26.554667 [TRC] 127.0.0.1:58397 - cid:8 - <<- [SUB _INBOX.Yc4NNicK4NE5Xf9YpiPeSb.*  1]
[97662] 2024/03/02 17:51:26.554689 [TRC] 127.0.0.1:58397 - cid:8 - <<- [PUB $JS.API.STREAM.INFO.OBJ_dms_mirror _INBOX.Yc4NNicK4NE5Xf9YpiPeSb.89CyKHrW 0]
[97662] 2024/03/02 17:51:26.554701 [TRC] 127.0.0.1:58397 - cid:8 - <<- MSG_PAYLOAD: [""]
[97662] 2024/03/02 17:51:26.556428 [TRC] 127.0.0.1:58397 - cid:8 - ->> [MSG _INBOX.Yc4NNicK4NE5Xf9YpiPeSb.89CyKHrW 1 1118]
[97662] 2024/03/02 17:51:26.556501 [TRC] ACCOUNT - <<- [PUB $JS.EVENT.ADVISORY.API  1701]
[97662] 2024/03/02 17:51:26.556516 [TRC] ACCOUNT - <<- MSG_PAYLOAD: ["{\"type\":\"io.nats.jetstream.advisory.v1.api_audit\",\"id\":\"gw0WpApYXPSPAIgmbVxQ0w\",\"timestamp\":\"2024-03-02T16:51:26.556361Z\",\"server\":\"nats-cluster-1\",\"client\":{\"start\":\"2024-03-02T17:51:26.552741+01:00\",\"host\":\"127.0.0.1\",\"id\":8,\"acc\":\"$G\",\"lang\":\"go\",\"ver\":\"1.16.0\",\"rtt\":1153916,\"server\":\"nats-cluster-1\",\"kind\":\"Client\",\"client_type\":\"nats\"},\"subject\":\"$JS.API.STREAM.INFO.OBJ_dms_mirror\",\"response\":\"{\\\"type\\\":\\\"io.nats.jetstream.api.v1.stream_info_response\\\",\\\"total\\\":0,\\\"offset\\\":0,\\\"limit\\\":0,\\\"config\\\":{\\\"name\\\":\\\"OBJ_dms_mirror\\\",\\\"retention\\\":\\\"limits\\\",\\\"max_consumers\\\":-1,\\\"max_msgs\\\":-1,\\\"max_bytes\\\":-1,\\\"max_age\\\":0,\\\"max_msgs_per_subject\\\":-1,\\\"max_msg_size\\\":-1,\\\"discard\\\":\\\"old\\\",\\\"storage\\\":\\\"file\\\",\\\"num_replicas\\\":1,\\\"mirror\\\":{\\\"name\\\":\\\"OBJ_dms\\\",\\\"subject_transforms\\\":[{\\\"src\\\":\\\"$O.dms.\\\\u003e\\\",\\\"dest\\\":\\\"$O.dms_mirror.\\\\u003e\\\"}],\\\"external\\\":{\\\"api\\\":\\\"$JS.leafnode.API\\\",\\\"deliver\\\":\\\"\\\"}},\\\"compression\\\":\\\"none\\\",\\\"allow_direct\\\":true,\\\"mirror_direct\\\":false,\\\"sealed\\\":false,\\\"deny_delete\\\":false,\\\"deny_purge\\\":false,\\\"allow_rollup_hdrs\\\":true,\\\"consumer_limits\\\":{}},\\\"created\\\":\\\"2024-03-02T15:56:12.706282Z\\\",\\\"state\\\":{\\\"messages\\\":2700,\\\"bytes\\\":351613700,\\\"first_seq\\\":271,\\\"first_ts\\\":\\\"2024-03-02T15:35:47.778329Z\\\",\\\"last_seq\\\":2970,\\\"last_ts\\\":\\\"2024-03-02T15:35:48.054462Z\\\",\\\"num_subjects\\\":20,\\\"consumer_count\\\":0},\\\"domain\\\":\\\"cluster\\\",\\\"cluster\\\":{\\\"leader\\\":\\\"nats-cluster-1\\\"},\\\"mirror\\\":{\\\"name\\\":\\\"OBJ_dms\\\",\\\"external\\\":{\\\"api\\\":\\\"$JS.leafnode.API\\\",\\\"deliver\\\":\\\"\\\"},\\\"lag\\\":0,\\\"active\\\":-1,\\\"subject_transforms\\\":[{\\\"src\\\":\\\"$O.dms.\\\\u003e\\\",\\\"dest\\\":\\\"$O.dms_mirror.\\\\u003e\\\"}]},\\\"ts\\\":\\\"2024-03-02T16:51:26.555504Z\\\"}\",\"domain\":\"cluster\"}"]
[97662] 2024/03/02 17:51:26.559565 [TRC] 127.0.0.1:58397 - cid:8 - <<- [PUB $JS.API.STREAM.MSG.GET.OBJ_dms_mirror _INBOX.Yc4NNicK4NE5Xf9YpiPeSb.DKBYHabF 41]
[97662] 2024/03/02 17:51:26.559633 [TRC] 127.0.0.1:58397 - cid:8 - <<- MSG_PAYLOAD: ["{\"last_by_subj\":\"$O.dms_mirror.M.\\u003e\"}"]
[97662] 2024/03/02 17:51:26.562559 [TRC] 127.0.0.1:58397 - cid:8 - ->> [MSG _INBOX.Yc4NNicK4NE5Xf9YpiPeSb.DKBYHabF 1 474]
[97662] 2024/03/02 17:51:26.562904 [TRC] 127.0.0.1:58397 - cid:8 - <<- [PUB $JS.API.STREAM.NAMES _INBOX.Yc4NNicK4NE5Xf9YpiPeSb.RlKKYFbr 36]
[97662] 2024/03/02 17:51:26.562930 [TRC] 127.0.0.1:58397 - cid:8 - <<- MSG_PAYLOAD: ["{\"subject\":\"$O.dms_mirror.M.\\u003e\"}"]
[97662] 2024/03/02 17:51:26.563213 [TRC] 127.0.0.1:58397 - cid:8 - ->> [MSG _INBOX.Yc4NNicK4NE5Xf9YpiPeSb.RlKKYFbr 1 106]
[97662] 2024/03/02 17:51:26.563234 [TRC] ACCOUNT - <<- [PUB $JS.EVENT.ADVISORY.API  581]
[97662] 2024/03/02 17:51:26.563241 [TRC] ACCOUNT - <<- MSG_PAYLOAD: ["{\"type\":\"io.nats.jetstream.advisory.v1.api_audit\",\"id\":\"gw0WpApYXPSPAIgmbVxQ64\",\"timestamp\":\"2024-03-02T16:51:26.563073Z\",\"server\":\"nats-cluster-1\",\"client\":{\"start\":\"2024-03-02T17:51:26.552741+01:00\",\"host\":\"127.0.0.1\",\"id\":8,\"acc\":\"$G\",\"lang\":\"go\",\"ver\":\"1.16.0\",\"rtt\":1153916,\"server\":\"nats-cluster-1\",\"kind\":\"Client\",\"client_type\":\"nats\"},\"subject\":\"$JS.API.STREAM.NAMES\",\"request\":\"{\\\"subject\\\":\\\"$O.dms_mirror.M.\\\\u003e\\\"}\",\"response\":\"{\\\"type\\\":\\\"io.nats.jetstream.api.v1.stream_names_response\\\",\\\"total\\\":0,\\\"offset\\\":0,\\\"limit\\\":1024,\\\"streams\\\":null}\",\"domain\":\"cluster\"}"]
[97662] 2024/03/02 17:51:26.563935 [TRC] 127.0.0.1:58397 - cid:8 - <-> [DELSUB 1]
[97662] 2024/03/02 17:51:27.859279 [TRC] JETSTREAM - <-> [DELSUB 4]
```

## Comment — @Jarema (2024-03-04)

You seem to be doing everything right @b3rtram 🙂 

The issue was that client was doing a stream lookup that could not work over mirrors.
There were two PRs that were fixing it: 
https://github.com/nats-io/nats.go/pull/1578
https://github.com/nats-io/nats.go/pull/1568

Let me know if `nats.go` `support-object-store-mirrors` branch works!

## Comment — @b3rtram (2024-03-04)

Thanks for the fast response. Now I get the list of the object but could not get the data out of the object store

```
package main

import (
	"fmt"

	"github.com/nats-io/nats.go"
)

func main() {
	nc, err := nats.Connect("localhost:4222")
	if err != nil {
		fmt.Println(err)
	}

	js, err := nc.JetStream(nats.PublishAsyncMaxPending(256))
	if err != nil {
		fmt.Println(err)
	}

	obj, err := js.ObjectStore("dms_mirror")
	if err != nil {
		fmt.Println(err)
	}

	watch, err := obj.List()
	if err != nil {
		fmt.Println(err)
	}

	for _, w := range watch {
		fmt.Println(w.Name)
	}

	b, err := obj.GetBytes("titel0.pdf")
	if err != nil {
		fmt.Println(err)
	}

	fmt.Println(len(b))
}

```

Output:

```
Get list of objects
titel0.pdf
titel1.pdf
titel2.pdf
titel3.pdf
titel4.pdf
titel5.pdf
titel6.pdf
titel7.pdf
titel8.pdf
titel9.pdf
Get object
nats: object not found
Get size of byte array
0
```

I will also try it in Java and C# because we need the implementation in C# and Java

## Comment — @Jarema (2024-03-04)

This is a bit weird, as we test that case, and I just successfuly tested it locally.
Are you sure that the file is not empty?

Definately test it also with the target client.
As concept of subject transforms over Object Store is a new topic, we didn't create a cross-client test to ensure that it works well across the ecosystem and all libraries. We will do that as soon as we will fix all related issues in nats.go client and propagate changes to others.

## Comment — @b3rtram (2024-03-04)

I will delete everything and try it new and give response

## Comment — @b3rtram (2024-03-04)

Ok, now it works, I can write files into the object store leafnode, mirror the stream over nats client to the central nats-server and get the data from the mirrored object store.

```
package main

import (
	"fmt"
	"os"

	"github.com/nats-io/nats.go"
)

func main() {
	nc, err := nats.Connect("localhost:4222")
	if err != nil {
		fmt.Println(err)
	}

	js, err := nc.JetStream(nats.PublishAsyncMaxPending(256))
	if err != nil {
		fmt.Println(err)
	}

	obj, err := js.ObjectStore("dms_mirror")
	if err != nil {
		fmt.Println(err)
	}

	fmt.Println("Get list of objects")
	watch, err := obj.List()
	if err != nil {
		fmt.Println(err)
	}

	for _, w := range watch {
		fmt.Println(w.Name)
	}

	fmt.Println("Get object")
	b, err := obj.GetBytes(watch[0].Name)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	fmt.Println("Get size of byte array")
	fmt.Println(len(b))

}
```

```
Get list of objects
data/titel1.pdf
titel1.pdf
data/titel2.pdf
Get object
Get size of byte array
35142796
```

Thank you very much, I think we can close this issue.

