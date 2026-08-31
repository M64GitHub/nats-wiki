<!-- source: https://docs.nats.io/reference/services/stats-response.md · fetched 2026-08-31 · section: stats-response -->
# Stats Response

Service statistics and metrics response.

<!-- -->

## Request Subject

`$SRV.STATS`

Services respond to stats requests on their specific subjects:

* `$SRV.STATS.{service}` - Statistics for all instances of a service
* `$SRV.STATS.{service}.{id}` - Statistics for a specific service instance

## Response Schema

A response from the NATS Micro $SRV.STATS API

Expand All

typeconst: "io.nats.micro.v1.stats\_response"required

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

startedstring\<date-time>required

The time the service was stated in RFC3339 format

A point in time in RFC3339 format including timezone, though typically in UTC

▶endpointsobject\[]required

Statistics for each known endpoint
