<!-- source: https://docs.nats.io/reference/system/monitor/varz.md · fetched 2026-08-31 · section: varz -->
# Varz

<!-- -->

## Request Schema

Request options for varz monitoring endpoint

## Response Schema

NATS Server VARZ Monitoring output

Expand All

server\_idstring

The unique server ID generated at start

server\_namestring

The configured server name, equals ID when not set

versionstring

The version of the running server

protointeger

The protocol version this server supports

git\_commitstring

The git repository commit hash that the build corresponds with

gostring

The version of Go used to build this binary

hoststring

The hostname the server runs on

portinteger

The port the server listens on for client connections

auth\_requiredboolean

Indicates if users are required to authenticate to join the server

tls\_requiredboolean

Indicates if connections must use TLS when connecting to this server

tls\_verifyboolean

Indicates if full TLS verification will be performed

tls\_ocsp\_peer\_verifyboolean

Indicates if the OCSP protocol will be used to verify peers

ipstring

The IP address the server listens on if set

connect\_urlsstring\[]

The list of URLs NATS clients can use to connect to this server

ws\_connect\_urlsstring\[]

The list of URLs websocket clients can use to connect to this server

max\_connectionsinteger

The maximum amount of connections the server can accept

nanoseconds depicting a duration in time, signed 64 bit integer

Minimum:`-9223372036854776000`

Maximum:`9223372036854776000`

max\_subscriptionsinteger

The maximum amount of subscriptions the server can manage

ping\_intervalnumber

The interval the server will send PING messages during periods of inactivity on a connection

ping\_maxinteger

The number of unanswered PINGs after which the connection will be considered stale

http\_hoststring

The HTTP host monitoring connections are accepted on

http\_portinteger

The port monitoring connections are accepted on

http\_base\_pathstring

The path prefix for access to monitor endpoints

https\_portinteger

The HTTPS port monitoring connections are accepted on

auth\_timeoutnumber

The amount of seconds connections have to complete authentication

max\_control\_lineinteger

The amount of bytes a signal control message may be

max\_payloadinteger

The maximum amount of bytes a message may have as payload

max\_pendinginteger

The maximum amount of unprocessed bytes a connection may have

▶clusterobject

Monitoring cluster information

▶gatewayobject

Monitoring gateway information

▶leafobject

Monitoring leaf node information

▶mqttobject

Monitoring MQTT information

▶websocketobject

Monitoring websocket information

▶jetstreamobject

Basic runtime information about JetStream

tls\_timeoutnumber

How long TLS operations have to complete

write\_deadlineinteger

The maximum time writes to sockets have to complete

nanoseconds depicting a duration in time, signed 64 bit integer

Minimum:`-9223372036854776000`

Maximum:`9223372036854776000`

write\_timeoutany

The policy to apply to sockets being closed due to write\_deadline

Allowed values:`default``close``retry`

startstring

Time when the server was started

nowstring

The current time of the server

uptimestring

How long the server has been running

meminteger

The resident memory allocation

coresinteger

The number of cores the process has access to

gomaxprocsinteger

The configured GOMAXPROCS value

gomemlimitinteger

The configured GOMEMLIMIT value

cpunumber

The current total CPU usage

connectionsinteger

The current connected connections

total\_connectionsinteger

The total connections the server have ever handled

routesinteger

The number of connected route servers

remotesinteger

The configured route remote endpoints

leafnodesinteger

The number connected leafnode clients

in\_msgsinteger

The number of messages this server received

out\_msgsinteger

The number of message this server sent

in\_bytesinteger

The number of bytes this server received

out\_bytesinteger

The number of bytes this server sent

slow\_consumersinteger

The total count of clients that were disconnected since start due to being slow consumers

stale\_connectionsinteger

The total count of stale connections that were detected

stalled\_clientsinteger

The total number of times that clients have been stalled

subscriptionsinteger

The count of active subscriptions

http\_req\_stats{ \[key: string]: integer }

The number of requests each HTTP endpoint received

config\_load\_timestring

The time the configuration was loaded or reloaded

config\_digeststring

A calculated hash of the current configuration

tagsstring\[]

The tags assigned to the server in configuration

metadata{ \[key: string]: string }

The metadata assigned to the server in configuration

trusted\_operators\_jwtstring\[]

The JWTs for all trusted operators

trusted\_operators\_claimobject\[]

The decoded claims for each trusted operator

system\_accountstring

The name of the System account

pinned\_account\_failsinteger

How often user logon fails due to the issuer account not being pinned

▶ocsp\_peer\_cacheobject

OCSP response cache information

▶slow\_consumer\_statsobject

Information about slow consumers from different type of connections

▶stale\_connection\_statsobject

Information about stale consumers from different type of connections

tls\_cert\_not\_afterstring

The expiration date of the TLS certificate
