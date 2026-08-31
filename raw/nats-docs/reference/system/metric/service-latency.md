<!-- source: https://docs.nats.io/reference/system/metric/service-latency.md · fetched 2026-08-31 · section: service-latency -->
# Service Latency

Service latency metrics.

<!-- -->

## Subscription Subject

`$SYS.SERVER.METRIC.SERVICE.LATENCY`

## Metric Schema

Metric published about sampled service requests showing request status and latencies

Expand All

typeconst: "io.nats.server.metric.v1.service\_latency"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

▶requestorobject

Details about the service requestor

▶responderobject

Details about the service responder

headerobject

When header based latency is enabled, the headers that triggered the event

statusintegerrequired

The status of the request. 200 OK, 400 Bad Request, no reply subject. 408 Request Timeout, requester lost interest before request completed. 503 Service Unavailable. 504 Service Timeout.

Allowed values:`200``400``408``503``504`

errorstring

A description of the status code when not 200

startstringrequired

The time the request started in RFC3339 format

serviceintegerrequired

The time taken by the service to perform the request in nanoseconds

systemintegerrequired

Time spend traversing the NATS network in nanoseconds

totalintegerrequired

The overall request duration in nanoseconds
