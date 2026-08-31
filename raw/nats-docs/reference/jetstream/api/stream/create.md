<!-- source: https://docs.nats.io/reference/jetstream/api/stream/create.md · fetched 2026-08-31 · section: create -->
# Create Stream

Creates a new stream with the specified configuration.

<!-- -->

## Subject

`$JS.API.STREAM.CREATE.{stream}`

Where `{stream}` is the name of the stream to create.

## Request

A request to the JetStream $JS.API.STREAM.CREATE API

Expand All

All of the following:

namestring

A unique name for the Stream, empty for Stream Templates.

Pattern:`^[^.*>]*$`

Min length:`0`

descriptionstring

A short description of the purpose of this stream

Max length:`4096`

subjectsstring\[]

A list of subjects to consume, supports wildcards. Must be empty when a mirror is configured. May be empty when sources are configured.

Min length:`0`

▶subject\_transformobject

Subject transform to apply to matching messages

retentionstringrequired

How messages are retained in the Stream, once this is exceeded old messages are removed.

Allowed values:

`limits`Keep messages until a stream limit removes them (max\_msgs, max\_bytes, or max\_age).`interest`Remove a message once every consumer whose filter matches it has acknowledged it; a message with no matching consumer is dropped immediately.`workqueue`Remove a message as soon as one consumer acknowledges it; consumers must use non-overlapping subject filters.

Default:`limits`

max\_consumersintegerrequired

How many Consumers can be defined for a given Stream. -1 for unlimited.

integer with a dynamic bit size depending on the platform the cluster runs on, can be up to 64bit

Minimum:`-1`

Maximum:`9223372036854776000`

Default:`-1`

max\_msgsintegerrequired

How many messages may be in a Stream, oldest messages will be removed if the Stream exceeds this size. -1 for unlimited.

signed 64 bit integer

Minimum:`-1`

Maximum:`9223372036854776000`

Default:`-1`

max\_msgs\_per\_subjectinteger

For wildcard streams ensure that for every unique subject this many messages are kept - a per subject retention limit

signed 64 bit integer

Minimum:`-1`

Maximum:`9223372036854776000`

Default:`-1`

max\_bytesintegerrequired

How big the Stream may be, when the combined stream size exceeds this old messages are removed. -1 for unlimited.

signed 64 bit integer

Minimum:`-1`

Maximum:`9223372036854776000`

Default:`-1`

max\_ageintegerrequired

Maximum age of any message in the stream, expressed in nanoseconds. 0 for unlimited.

nanoseconds depicting a duration in time, signed 64 bit integer

Minimum:`0`

Maximum:`9223372036854776000`

Default:`0`

max\_msg\_sizeinteger

The largest message that will be accepted by the Stream. -1 for unlimited.

signed 32 bit integer

Minimum:`-1`

Maximum:`2147483647`

Default:`-1`

storagestringrequired

The storage backend to use for the Stream.

Allowed values:

`file`Keep stream data on disk.`memory`Keep stream data only in memory; it does not survive a server restart.

Default:`file`

compressionstring

Optional compression algorithm used for the Stream.

Allowed values:

`none`Store message blocks uncompressed.`s2`Compress stored message blocks with the S2 algorithm (an extension of Snappy).

Default:`none`

first\_seqinteger

A custom sequence to use for the first message in the stream

unsigned 64 bit integer

Minimum:`0`

Maximum:`18446744073709552000`

num\_replicasintegerrequired

How many replicas to keep for each message.

integer with a dynamic bit size depending on the platform the cluster runs on, can be up to 64bit

Minimum:`1`

Maximum:`5`

Default:`1`

no\_ackboolean

Disables acknowledging messages that are received by the Stream.

Default:`false`

discardstring

When a Stream reach it's limits either old messages are deleted or new ones are denied

Allowed values:

`old`Remove the oldest messages to make room for new ones when a limit is reached.`new`Reject new messages while the stream sits at its limit.

Default:`old`

duplicate\_windowinteger

The time window to track duplicate messages for, expressed in nanoseconds. 0 for default

nanoseconds depicting a duration in time, signed 64 bit integer

Minimum:`0`

Maximum:`9223372036854776000`

Default:`0`

▶placementobject

Placement directives to consider when placing replicas of this stream, random placement when unset

▶mirrorobject

Maintains a 1:1 mirror of another stream with name matching this property. When a mirror is configured subjects and sources must be empty.

▶sourcesobject\[]

List of Stream names to replicate into this Stream

sealedboolean

Sealed streams do not allow messages to be deleted via limits or API, sealed streams can not be unsealed via configuration update. Can only be set on already created streams via the Update API

Default:`false`

deny\_deleteboolean

Restricts the ability to delete messages from a stream via the API. Cannot be changed once set to true

Default:`false`

deny\_purgeboolean

Restricts the ability to purge messages from a stream via the API. Cannot be change once set to true

Default:`false`

allow\_rollup\_hdrsboolean

Allows the use of the Nats-Rollup header to replace all contents of a stream, or subject in a stream, with a single new message

Default:`false`

allow\_directboolean

Allow higher performance, direct access to get individual messages

Default:`false`

allow\_atomicboolean

Allow atomic batched publishes

Default:`false`

allow\_msg\_counterboolean

Configures a stream to be a counter and to reject all other messages

Default:`false`

allow\_msg\_schedulesboolean

Allows the scheduling of messages

Default:`false`

mirror\_directboolean

Allow higher performance, direct access for mirrors as well

Default:`false`

▶republishobject

Rules for republishing messages from a stream with subject mapping onto new subjects for partitioning and more

discard\_new\_per\_subjectboolean

When discard policy is new and the stream is one with max messages per subject set, this will apply the new behavior to every subject. Essentially turning discard new from maximum number of subjects into maximum number of messages in a subject.

Default:`false`

metadata{ \[key: string]: string }

Additional metadata for the Stream

▶consumer\_limitsobject

Limits of certain values that consumers can set, defaults for those who don't set these settings

allow\_msg\_ttlboolean

Enables per-message TTL using headers

Default:`false`

subject\_delete\_marker\_ttlinteger

Enables and sets a duration for adding server markers for delete, purge and max age limits

nanoseconds depicting a duration in time, signed 64 bit integer

Minimum:`0`

Maximum:`9223372036854776000`

persist\_modestring

Sets a specific persistence mode for writing to the Stream

Allowed values:

`""`Not set; the server uses the default mode.`default`Writes are flushed to storage before the publish is acknowledged.`async`Writes are flushed in the background; a publish may be acknowledged before the message is stored.

Default:``

allow\_batchedboolean

Allows fast batch publishing into the Stream

Default:`false`

pedanticboolean

Enables pedantic mode where the server will not apply defaults or change the request

Default:`false`

## Response

A response from the JetStream $JS.API.STREAM.CREATE API

Expand All

One of the following:

Option

<!-- -->

1

<!-- -->

(

<!-- -->

object

<!-- -->

)

▶configobjectrequired

The active configuration for the Stream

▶stateobjectrequired

Detail about the current State of the Stream

createdstring\<date-time>required

Timestamp when the stream was created

A point in time in RFC3339 format including timezone, though typically in UTC

tsstring\<date-time>

The server time the stream info was created

A point in time in RFC3339 format including timezone, though typically in UTC

▶clusterobject

▶mirrorobject

Information about an upstream stream source in a mirror

▶sourcesobject\[]

Streams being sourced into this Stream

▶alternatesobject\[]

List of mirrors sorted by priority

domainstring

The JetStream domain the stream is in

Option

<!-- -->

2

<!-- -->

(

<!-- -->

object

<!-- -->

)

▶errorobjectrequired

typeconst: "io.nats.jetstream.api.v1.stream\_create\_response"required
