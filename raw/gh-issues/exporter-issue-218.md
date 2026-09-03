<!-- source: https://github.com/nats-io/prometheus-nats-exporter/issues/218 (GitHub GraphQL API, repository.issue(number:)) · fetched 2026-09-03 · an issue of nats-io/prometheus-nats-exporter, not of nats-server -->
# prometheus-nats-exporter issue #218 — NATS cluster has different values of the same metric

State: OPEN — no maintainer reply as of the fetch · opened 2023-04-11 by @andreyreshetnikov-zh · comments: 6

## Original post

question about NATS Jetstream metrics, we deployed NATS in k8s, using helm chart and metrics are collected using exporter(prometheus-nats-exporter:0.10.1) in each nats pod.
NATS cluster consists of three pods and `nats_consumer_num_pending` metric shows this result:
```
{account="test-account", consumer_name="test-consumer", pod="nats-0", stream_name="STREAM"} 3
{account="test-account", consumer_name="test-consumer", pod="nats-1", stream_name="STREAM"} 0
{account="test-account", consumer_name="test-consumer", pod="nats-2", stream_name="STREAM"} 3
```
the same situation with `nats_consumer_delivered_consumer_seq` metric, it differs between pods. It is possible that there is a difference with other metrics too, but I noticed only this. There are 3 NATS servers in the cluster and replication is set to 3, therefore, the metrics should be the same.
I want to set up alerts by these metrics and try to understand why there is such a difference and how to fix it.


Stream settings:

nats stream info STREAM -j
```
{
  "config": {
    "name": "STREAM",
    "subjects": [
      "STREAM.\u003e"
    ],
    "retention": "limits",
    "max_consumers": -1,
    "max_msgs_per_subject": -1,
    "max_msgs": -1,
    "max_bytes": -1,
    "max_age": 604800000000000,
    "max_msg_size": 1048576,
    "storage": "file",
    "discard": "old",
    "num_replicas": 3,
    "duplicate_window": 120000000000,
    "sealed": false,
    "deny_delete": true,
    "deny_purge": true,
    "allow_rollup_hdrs": false,
    "allow_direct": true,
    "mirror_direct": false
  },
  "created": "2023-01-06T16:32:45.94453806Z",
  "state": {
    "messages": 12,
    "bytes": 8249,
    "first_seq": 16,
    "first_ts": "2023-03-29T08:39:41.044331931Z",
    "last_seq": 27,
    "last_ts": "2023-03-29T14:08:50.155790148Z",
    "num_subjects": 3,
    "consumer_count": 4
  },
  "cluster": {
    "name": "nats",
    "leader": "nats-1",
    "replicas": [
      {
        "name": "nats-0",
        "current": true,
        "active": 515564749
      },
      {
        "name": "nats-2",
        "current": true,
        "active": 515204233
      }
    ]
  }
}
```

nats consumer info STREAM test-consumer -j
```
{
  "stream_name": "STREAM",
  "name": "test-consumer",
  "config": {
    "ack_policy": "explicit",
    "ack_wait": 30000000000,
    "deliver_policy": "all",
    "durable_name": "test-consumer",
    "name": "test-consumer",
    "filter_subject": "STREAM.dd.fff",
    "max_ack_pending": 65536,
    "max_deliver": 3,
    "max_waiting": 512,
    "replay_policy": "instant",
    "num_replicas": 0
  },
  "created": "2023-02-16T15:51:29.457341009Z",
  "delivered": {
    "consumer_seq": 3,
    "stream_seq": 27,
    "last_active": "2023-03-29T14:08:50.156400032Z"
  },
  "ack_floor": {
    "consumer_seq": 3,
    "stream_seq": 27,
    "last_active": "2023-03-29T14:08:50.168461189Z"
  },
  "num_ack_pending": 0,
  "num_redelivered": 0,
  "num_waiting": 5,
  "num_pending": 0,
  "cluster": {
    "name": "nats",
    "leader": "nats-1",
    "replicas": [
      {
        "name": "nats-0",
        "current": true,
        "active": 601400909
      },
      {
        "name": "nats-2",
        "current": true,
        "active": 601065181
      }
    ]
  }
}
```

## Comment — @jlange-koch (2023-04-23)

Hey, 
we have the same issue with `jetstream_consumer_num_pending` .
As a workaround I added `!= 0` in my Grafana dashboard and set "Connect null values" to "Always" in the Time series panel. You might be able to use this for alerting if you dont alert on "null values", just keep in mind that you have less data points as prometheus sometimes scrapes the wrong value (for us the wrong value is always 0 ). 
I am not sure I would trust such an alert 100% though.

## Comment — @niklasmtj (2023-06-26)

Same behaviour for us with `jetstream_consumer_num_pending`. This already happened with the exporter in version 0.9.1. Upgraded it to 0.11.0 but it still shows the same behaviour.

## Comment — @andreyreshetnikov-zh (2023-07-07)

Hello @wallyqs, sorry for ping you, but in general, it is difficult to understand which server displays the real information.
we have different values from each nats server(**0 / 8 / 0**):
```
nats_consumer_num_pending{account="TEST",account_id="ID",cluster="nats",consumer_desc="",consumer_leader="nats-1",
consumer_name="monitor",domain="",is_consumer_leader="false",is_meta_leader="false",is_stream_leader="false",
meta_leader="nats-2",server_name="nats-0",stream_leader="nats-2",stream_name="TEST"} 0

nats_consumer_num_pending{account="TEST",account_id="ID",cluster="nats",consumer_desc="",consumer_leader="nats-1",
consumer_name="monitor",domain="",is_consumer_leader="true",is_meta_leader="false",is_stream_leader="false",
meta_leader="nats-2",server_name="nats-1",stream_leader="nats-2",stream_name="TEST"} 8

nats_consumer_num_pending{account="TEST",account_id="ID",cluster="nats",consumer_desc="",consumer_leader="nats-1",
consumer_name="monitor",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="true",
meta_leader="nats-2",server_name="nats-2",stream_leader="nats-2",stream_name="TEST"} 0
```
and in this case nats-1 is the leader.
result of `nats consumer info`:
```
nats consumer info TEST monitor |grep -E 'Leader|Unprocessed'                                                                                                                                                     
              Leader: nats-1
     Unprocessed Messages: 8
```
and it's difficult to say what exactly is true, since the leader displays 8, but the other two servers are 0. 
Could you say where the error is possible and I could prepare a PR.

## Comment — @andreyreshetnikov-zh (2023-07-07)

A few new points, I used the promql query:
`count(nats_consumer_num_pending > 0) by (cluster_id, account, consumer_name, stream_name, consumer_leader) > 0`
and I found that if there is a difference in the same metric between different servers, then the metric difference is always on consumer_leader side.

and the second point is that when I try to restart the prometheus-nats-exporter container inside the nats server pod(with metric differences) by:
`kill -HUP $(ps aufx |grep '[p]rometheus-nats-exporter' |awk '{print $1}')`
prometheus-nats-exporter container is successfully restarted, but the metric value doesnt change. I tried restarting the whole pod, but the result is the same, nothing changes.
apparently, the error is not with the exporter, as if the nats server displays another metric value.
it looks like consumer replicas don't replicate these metrics from the consumer_leader.

## Comment — @andreyreshetnikov-zh (2023-07-10)

as far as I understand, when using the `nats consumer info` command, information about "Unprocessed Messages" is always given by the consumer leader. Is there any way to view this metric on each nats server? there is a desire to connect to each server and see the list of unprocessed messages and compare their number with the metric, to understand where the error is

## Comment — @andreyreshetnikov-zh (2023-07-12)

after testing, it turned out that the nats pod, which is consumer_leader at the moment, always shows the correct value for pending messages and for ack pending messages. I added the label `is_consumer_leader="true"` to Grafana dashboard and it solved the problem of incorrect data display.
the same for alerts expression:
```
nats_consumer_num_pending{env="stage", is_consumer_leader="true"} > 0
```
it will always be triggered only when the current values are.

@jlange-koch, `!= 0` is not always true, as I have observed situations that replicas show `!= 0`, but in fact there are no pending messages and the leader correctly displays 0.
