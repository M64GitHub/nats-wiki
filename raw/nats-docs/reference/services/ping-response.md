<!-- source: https://docs.nats.io/reference/services/ping-response.md · fetched 2026-08-31 · section: ping-response -->
# Ping Response

Service health check response.

<!-- -->

## Request Subject

`$SRV.PING`

Services respond to ping requests on their specific subjects:

* `$SRV.PING.{service}` - Ping all instances of a service
* `$SRV.PING.{service}.{id}` - Ping a specific service instance

## Response Schema

A response from the NATS Micro $SRV.PING API

Expand All

typeconst: "io.nats.micro.v1.ping\_response"required

namestringrequired

The kind of the service. Shared by all the services that have the same name

Pattern:`^[a-zA-Z0-9_-]+$`

Min length:`1`

idstringrequired

A unique ID for this instance of a service

Min length:`1`

versionstringrequired

The version of the service

Pattern:`^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$`

Min length:`5`

▶metadataoneOf
