<!-- source: https://docs.nats.io/reference.md · fetched 2026-08-31 · section: reference -->
# Reference

Complete technical reference documentation for NATS protocols, APIs, and server components.

## [Configuration](/reference/config/.md)

NATS Server configuration reference:

* Server configuration options and settings
* Security and authentication setup
* Clustering and routing configuration

## [JetStream](/reference/jetstream/.md)

JetStream persistence layer reference:

* [API](/reference/jetstream/api/.md) - Management and data operations
* [Advisory](/reference/jetstream/advisory/.md) - System events and notifications
* [Metrics](/reference/jetstream/metric/.md) - Performance and usage metrics
* [Errors](/reference/jetstream/errors.md) - Error codes and troubleshooting

## [System](/reference/system/.md)

NATS system advisories and monitoring:

* [Advisory](/reference/system/advisory/.md) - Connection and system events
* [Monitoring](/reference/system/monitor/.md) - Health check and statistics endpoints
* [Metrics](/reference/system/metric/.md) - Server telemetry data

## [Services](/reference/services/.md)

NATS Services API for building microservices:

* [Info Response](/reference/services/info-response.md) - Service information
* [Ping Response](/reference/services/ping-response.md) - Health check responses
* [Stats Response](/reference/services/stats-response.md) - Service statistics

## [Protocols](/reference/protocols/.md)

Low-level protocol specifications for NATS communication:

* [Client Protocol](/reference/protocols/client.md) - Communication between clients and servers
* [Route Protocol](/reference/protocols/route.md) - Inter-server communication for clustering
* [Leafnode Protocol](/reference/protocols/leafnode.md) - Edge server connections
* [Gateway Protocol](/reference/protocols/gateway.md) - Super-cluster connectivity
