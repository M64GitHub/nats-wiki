<!-- source: https://docs.nats.io/reference/system/monitor.md · fetched 2026-08-31 · section: monitor -->
# Server Monitoring

Server monitoring endpoints provide detailed information about the NATS server state, performance metrics, and operational health.

## Overview

NATS Server exposes HTTP monitoring endpoints that return JSON-formatted data about server operations. These endpoints are essential for:

* Health checks and liveness probes
* Performance monitoring
* Troubleshooting issues
* Capacity planning
* Integration with monitoring systems

## Available Endpoints

### [Varz](/reference/system/monitor/varz.md)

General server information including:

* Server version and configuration
* Current connections and subscriptions
* Message rates and data throughput
* Memory and CPU usage
* Cluster membership information

### [Connz](/reference/system/monitor/connz.md)

Detailed connection information for all clients connected to the server:

* Client connection details
* Connection state and statistics
* IP addresses and ports
* Subscription counts per connection

### [Subsz](/reference/system/monitor/subsz.md)

Subscription routing details:

* Active subscriptions
* Queue group information
* Subscription statistics
* Filtering and pagination options

### [Routez](/reference/system/monitor/routez.md)

Cluster route information:

* Route connections between cluster nodes
* Route statistics and health
* Cluster topology information

### [Gatewayz](/reference/system/monitor/gatewayz.md)

Gateway connections for superclusters:

* Gateway connection status
* Remote gateway information
* Traffic statistics between gateways

### [Leafz](/reference/system/monitor/leafz.md)

Leafnode connections:

* Leafnode server connections
* Remote leafnode details
* Connection statistics

### [Accountz](/reference/system/monitor/accountz.md)

Account information:

* Account configuration and limits
* Connection and subscription counts per account
* Import/export configurations

### [Accstatz](/reference/system/monitor/accstatz.md)

Account statistics:

* Detailed account usage statistics
* Message and byte counts
* Connection metrics per account

### [JSz](/reference/system/monitor/jsz.md)

JetStream information:

* Stream and consumer details
* JetStream cluster status
* Memory and storage usage

### [Healthz](/reference/system/monitor/healthz.md)

Health check endpoint:

* Server health status
* Suitable for liveness/readiness probes
* Simple OK/Error responses

### [Statsz](/reference/system/monitor/statsz.md)

Server statistics summary:

* Aggregated server metrics
* Performance statistics
* System resource usage

### [IPQueuesz](/reference/system/monitor/ipqueuesz.md)

IP queue information:

* Client IP-based queue statistics
* Connection queuing metrics

### [Idz](/reference/system/monitor/idz.md)

Server identification:

* Server identity information
* Unique server identifiers

### [Profilez](/reference/system/monitor/profilez.md)

Server profiling data:

* CPU and memory profiling endpoints
* Performance debugging information

### [Raftz](/reference/system/monitor/raftz.md)

Raft consensus information:

* JetStream Raft cluster details
* Leader election status
* Raft log information

## Access Configuration

Monitoring endpoints are configured in the server configuration file:

```
http_port: 8222
```

Endpoints are then accessible at:

```
http://localhost:8222/varz
```

## Security Considerations

* Use authentication to protect monitoring endpoints
* Consider TLS for encrypted monitoring traffic
* Limit access to monitoring endpoints via firewall rules
* Be aware that some endpoints may expose sensitive information

## Integration

Monitoring endpoints integrate well with:

* Prometheus for metrics collection
* Grafana for visualization
* Kubernetes liveness/readiness probes
* Custom monitoring solutions
* Alert managers
