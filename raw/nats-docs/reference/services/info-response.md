<!-- source: https://docs.nats.io/reference/services/info-response.md · fetched 2026-08-31 · section: info-response -->
# Info Response

Service information and metadata response.

<!-- -->

## Request Subject

`$SRV.INFO`

Services respond to info requests on their specific subjects:

* `$SRV.INFO.{service}` - Info for all instances of a service
* `$SRV.INFO.{service}.{id}` - Info for a specific service instance

## Response Schema

A response from the NATS Micro $SRV.INFO API

Expand All

typeconst: "io.nats.micro.v1.info\_response"required

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

descriptionstringrequired

The description of the service supplied as configuration while creating the service

▶endpointsobject\[]

List of declared endpoints
