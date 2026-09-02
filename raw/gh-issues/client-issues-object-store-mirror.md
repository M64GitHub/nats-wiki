<!-- source: three client-repository issues cross-referenced from nats-server issue #5106, fetched through the GitHub GraphQL API · fetched 2026-09-02 -->
# The client side of a mirrored object bucket — nats.go #1874, nats.go #1648, nats.js #155

Fetched together because `raw/gh-issues/issue-5106.md` cross-references them; they are the public record of whether a mirrored object-store bucket is a first-class thing in any client. Bodies verbatim, comments verbatim.

## nats-io/nats.go#1874 — Support mirrored ObjectStore

https://github.com/nats-io/nats.go/issues/1874 · opened 2025-05-15 by @shaunco · state: OPEN · comments: 8

### Original post

### Proposed change

The nats.go `jetstream.CreateObjectStore` API should support creating mirrors and sourced object stores, which means adding `Mirror *StreamSource` and `Sources []*StreamSource` to `ObjectStoreConfig`.

Currently it requires a call to `CreateStream` with all the right options:
```go
js.CreateStream(ctx, jetstream.StreamConfig{
			Name:        "OBJ_MYBUCKET",
			Description: "Mirror of OBJ_MYBUCKET",
			Mirror: &jetstream.StreamSource{
				Name:   "OBJ_MYBUCKET",
				Domain: "myleafdomain"
			},
			Replicas:    1,
			MaxAge:      time.Hour * 24 * 14,
			MaxBytes:    -1,
			Discard:     jetstream.DiscardNew,
			AllowRollup: true,
			AllowDirect: true,
			Storage:     jetstream.FileStorage,
			Compression: jetstream.S2Compression,
		})
```

The manual stream creations works great since #5106 was fixed, but first class support would align with KV and streams. Also, similar request is open for nats.js: https://github.com/nats-io/nats.js/issues/155

### Use case

We have leafnodes that write objects to a local object store bucket, and want those objects mirrored to an object store in the cluster. Ideally, we'd like a WorkStream style policy that removes them from the leafnode once mirrored, but for now we just use a short (~12hr) TTL on the leafnode and a longer (14 day) TTL for the cluster side mirror.

### Contribution

_No response_

### Comment — @Jarema (2025-05-19)

Unfortunately, that is not  that straightforward.

To have properly working mirrors, you need to adapt subject names too and use subject transforms.
Additionally, deletes of objects will not propagete to mirrors, as mirrors/sources have different limits than the original stream, by design.

### Comment — @shaunco (2025-05-19)

If I keep the stream name the same in both domains, it seems to work just fine for copying and access.

If WorkStream style policy was supported, I would expect the objects to move from the origin to the mirror (copy, then delete from origin), but with the above mirror stream I wouldn't expect that. I simply manage cleanup on the origin through a shorter TTL than the mirror.

### Comment — @ripienaar (2025-05-20)

Same stream in multiple domains has numerous bugs and issues. You absolutely should not do that. 

Until object store had a rethink I don’t think we should allow this.

### Comment — @shaunco (2025-05-20)

To be clear - not the same stream, just the same name to avoid breaking `$JS.M.*` hashed names that would otherwise need mappings to fix. Stream `A` in domain `X` has a mirror of `Domain: Y, Stream A`. The [JetStream on Leaf Nodes docs](https://docs.nats.io/running-a-nats-service/configuration/leafnodes/jetstream_leafnodes) specifically say:
> Please be aware that each domain is an independent name space. Meaning, inside the same account it is legal to use the same stream name in different domains.

Do you have references to issue IDs I should be on the lookout for? It absolutely works for our use case currently (moving objects from the leafnode to the hub). Outright disallowing it would completely break us.

### Comment — @ripienaar (2025-05-20)

Certain kinds of consumers break and can potentially double ack between streams. Object store doesn’t surface most of them in its usage patterns but it’s certainly not good to use in the general case.

### Comment — @shaunco (2025-05-20)

A consumer unexpectedly jumping over a domain boundary to ack a stream in a totally different name space sounds like a very serious bug in nats-server that should be addressed - especially if ACLs don't allow it, and the default leaf node supporession of `$JS.API.>` is being bypassed. Additionally, identical stream names in different domains for KVs and generic streams are used in many nats unit tests and examples showcasing leaf nodes, and all of those should be changed or massive blinking red warnings that `domains don't actually provide independent namespaces` should be added everywhere.

### Comment — @shaunco (2025-05-20)

@Jarema - the requirement to adapt/map subject names seems to have been solved with https://github.com/nats-io/nats-server/issues/5106 . Since you were active on that issue, any details on what I might be missing? Perhaps I'm not running into this because I just keep the stream name ("OBJ_TEST") the same on both the leaf and the hub?

### Comment — @Jarema (2025-05-28)

@shaunco yes, this is possible that you are not running in some of the issues because of that.
However, number of issue is bigger - including lack of ability to propagate deletes to mirrors, and others.

It can for sure work for your use case, and you can manually edit & create the streams, but it's not a good idea in current shape of Object Store to make it generally available, as it will cause problems and confusion to others.

When we rethink and rework Object Store (also after server supports features it requires), that should be safe for general purpose.

## nats-io/nats.go#1648 — Object store publishes chunks without using domain in subject

https://github.com/nats-io/nats.go/issues/1648 · opened 2024-06-14 by @scottf · state: OPEN · comments: 4

### Original post

### Steps to recreate

```
CLI way of doing the file dance
add --trace to any of these for more verbose output

create the store on hub
nats --server nats://testUser:testPass@localhost:4222 --js-domain HUB object add CliStore

upload file with js domain HUB on hub
nats --server nats://testUser:testPass@localhost:4222 --js-domain HUB object put CliStore ./nats/tmp.txt

check it exists from both servers views using the js domain of HUB
nats --server nats://testUser:testPass@localhost:4222 --js-domain HUB object ls CliStore
nats --server nats://testUser:testPass@localhost:4223 --js-domain HUB object ls CliStore

this can prove the file is stored on hub and not spoke. look at mem and file in use under Jetstream
nats --server nats://admin:admin@localhost:4222 server info
nats --server nats://admin:admin@localhost:4223 server info

spoke should be able to download the file if the HUB domain is used
nats --server nats://testUser:testPass@localhost:4223 --js-domain HUB object get CliStore nats/tmp.txt -O spokeout.txt

spoke should be able to delete the file if the HUB domain is used
nats --server nats://testUser:testPass@localhost:4223 --js-domain HUB object del CliStore nats/tmp.txt -f

spoke should be able to upload the file if the HUB domain is used
nats --trace --server nats://testUser:testPass@localhost:4223 --js-domain HUB object put CliStore ./nats/tmp.txt

hub should be able to download the file that the spoke uploaded
nats --server nats://testUser:testPass@localhost:4222 --js-domain HUB object get CliStore nats/tmp.txt -O hubout.txt

hub should be able to delete the file too
nats --server nats://testUser:testPass@localhost:4222 --js-domain HUB object del CliStore nats/tmp.txt -f
```

### Expected behavior

When a js-domain is specified, objects are published to the domain meaning the publish subject has the domain in the api.

### Server and client version

Latest CLI, Server N/A

### Based on
https://github.com/nats-io/nats.java/issues/1157

### Comment — @ripienaar (2024-06-14)

Go code that reproduce the problem. Check with a sub on $O.> and you will see wrong subjects.  

https://gist.github.com/ripienaar/554b9679983bf5cba6da6a75e7ea844f

### Comment — @scottf (2024-06-17)

@ripienaar @piotrpio  The go client might be correct but I would verify.

I found a bug in the java/.net v1 libraries. On the connection to the leaf, it's correct to use the js domain information on js api calls. But for a consumer, the actual filter subject of the consumer of chunks is just the normal $O subject, not some js api subject.

My code was calling `pubSubChunkSubject` which gives that full domain specific subject. But it should have called my `rawChunkSubject` which is just normal.

https://github.com/nats-io/nats.java/pull/1160/files#diff-4fe4c868c242b0c63faee28649d7af470fcd3de4d3627929d911e3557d751663L236

### Comment — @ripienaar (2024-06-17)

Did you implement the behaviour described here @scottf ?

this seems to suggest yes - and server is doing mapping on those subjects. 

I never really bought into this design but anyway seems to be what you have?

https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-19.md#kv-example

### Comment — @scottf (2024-06-17)

I think I followed the KV spec
My problem was when creating a consumer, I treated the consumer filter subject as something that had to be domainified. Creating the consumer itself is done correctly with a domainified CREATE_CONSUMER

## nats-io/nats.js#155 — Support mirrored ObjectStore

https://github.com/nats-io/nats.js/issues/155 · opened 2024-11-22 by @Naymi · state: CLOSED (closed 2025-07-02) · comments: 1

### Original post

### Observed behavior

no stream subject

### Expected behavior

getting value

### Server and client version

Nats server
Version:  2.10.22
Git:      [240e9a4]

nats cli - 0.1.5

node package manager - yarn 4.3.1
package nats - 2.28.2

### Host environment

macos 15.1 (24B83)
docker 4.21.1
image nats:alpine - sha256:75531e0cd58e417f674a8e110cb1b6e032052abc49a34eedf099ba501b1d32b4

### Steps to reproduce

https://github.com/nats-io/nats-server/issues/5106


```ts
import 'source-map-support'
import { connect } from "nats";
function stringToReadableStream(str: string) {
  const encoder = new TextEncoder();
  const encodedStr = encoder.encode(str);

  return new ReadableStream({
    start(controller) {
      controller.enqueue(encodedStr);
      controller.close();
    }
  });
}

async function readStreamToString(stream: any) {
  if (!stream) return stream
  const reader = stream.getReader();
  const decoder = new TextDecoder();
  let result = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) {
      break;
    }
    result += decoder.decode(value, { stream: true });
  }

  // Декодирование оставшихся данных
  result += decoder.decode();

  return result;
}

const main = async () => {
  const nc = await connect()
  const js = nc.jetstream()
  const jsm = await js.jetstreamManager()
  const sourceS3 = await js.views.os('source')
//  const c = await js.consumers.get('ss')
  console.log('source initialized');
  let message = await jsm.streams.list();
  for await (const messageElement of message) {
    console.log(messageElement.config.name)
  }
  let osDestStreamName: string = 'OBJ_dest';
  await jsm.streams.delete(osDestStreamName).catch(()=>{})
  let objSourceStreamName: string = 'OBJ_source';
  jsm.streams.list()
  const destStream = await jsm.streams.add({
    name: osDestStreamName,
    allow_rollup_hdrs: true,
    mirror: {
      name: objSourceStreamName,
      subject_transforms: [
        {
          src: '$O.source.C.>',
          dest: '$O.dest.C.>',
        },
        {
          src: '$O.source.M.>',
          dest: '$O.dest.M.>',
        },
      ]
    }
  })
  console.log('dest initialized');
  const destS3 = await js.views.os('dest')
  await sourceS3.put({
    name: 'foo',
  }, stringToReadableStream('bar'))
  setTimeout(async ()=> {
    const fooFromSourceValue = await sourceS3.get('foo')
    const fooFromDestValue = await destS3.get('foo')
    console.log('fooFromDestValue', await readStreamToString(fooFromDestValue?.data))
    console.log('fooFromSourceValue', await readStreamToString(fooFromSourceValue?.data))

    let message = await jsm.streams.list();
    for await (const messageElement of message) {
      console.log(messageElement.config.name)
    }
    {
      const c = await js.consumers.get(osDestStreamName)
      for await (const fetch of await c.fetch()) {
        console.log('itm dst', fetch.string());
        console.log('itm dst subj', fetch.subject);
      }
    }
    {
      const c = await js.consumers.get(objSourceStreamName)
      for await (const fetch of await c.fetch()) {
        console.log('itm src', fetch.string());
        console.log('itm src subj', fetch.subject);
      }
    }
    process.exit()
  }, 5e3)
}

main()
```

### Comment — @aricart (2025-07-02)

Closing for now. Clients don't have a strategy for supporting this right now, but we are aware of it.

