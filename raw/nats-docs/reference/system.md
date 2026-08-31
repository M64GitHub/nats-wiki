<!-- source: https://docs.nats.io/reference/system.md · fetched 2026-08-31 · section: system -->
# System Reference

System reference for monitoring, observability, and system management.

## Overview

The NATS Server provides comprehensive interfaces for:

* Real-time event notifications via advisories
* Performance monitoring through metrics
* HTTP endpoints for health checks and statistics
* Detailed error reporting for troubleshooting

## Categories

### [Advisory](/reference/system/advisory/.md)

System event notifications:

* Client connection and disconnection events
* Account limit warnings
* Cluster state changes
* Authentication events

### [Metrics](/reference/system/metric/.md)

Performance and telemetry data:

* Resource utilization metrics
* Throughput measurements

### [Monitoring](/reference/system/monitor/.md)

HTTP monitoring endpoints:

* Health check endpoints
* Cluster state information
* Connection details

### [Errors](/reference/system/errors.md)

Server error responses:

* Protocol violations
* Authentication failures
* Resource limits
* Configuration errors
