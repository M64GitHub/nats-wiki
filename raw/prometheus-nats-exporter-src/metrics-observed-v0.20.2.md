<!-- source: prometheus-nats-exporter v0.20.2 (go install github.com/nats-io/prometheus-nats-exporter@v0.20.2, module version confirmed with go version -m) scraped against nats-server v2.14.6, nats CLI 0.4.0, macOS, 2026-09-03 · the lab cluster of tools/lab/cluster.sh (n1–n3); scripts metrics-run.sh and metrics-run2.sh beside this file -->
# prometheus-nats-exporter v0.20.2 against nats-server v2.14.6 — every series it emitted, observed

The behavioural half of `collector-v0.20.2.md`, for `wiki/reference/metrics.md` (phase E step 3). The
exporter was started once per configuration against node n1's monitoring port (n2's in run H1-n2),
scraped once with `curl`, and stopped; the scrape bodies below are verbatim except that the Go runtime
and process series the Prometheus client library adds to every scrape (`go_*`, `process_*`,
`promhttp_*` — 38 `# HELP` lines in run A) are dropped, with the count stated per run. The shape on the
cluster: one R3 file stream `ORDERS` with 30 messages; a pull consumer `shipping` (`ack_wait: 3s`,
`max_deliver: -1`) that fetched 10 messages without acking, let the ack wait expire, and fetched them
again, so it holds 10 unacked messages each delivered twice; an R1 mirror `ORDERS_MIRROR` and an R1
sourcing stream `ORDERS_AGG`, both placed on n2. Runs H1 and H2 follow one acknowledged redelivery
and add a live client. The lab's only application account is `$G`; its system user is `sys`.

## 0 · The shape, as built (transcript of `metrics-run.sh`, first part)

```

== shape

$ nats stream add ORDERS --subjects orders.> --replicas 3 --storage file --defaults
Stream ORDERS was created

Information for Stream ORDERS created 2026-09-03 04:41:44

                     Subjects: orders.>
                     Replicas: 3
                      Storage: File

Options:

                    Retention: Limits
              Acknowledgments: true
               Discard Policy: Old
             Duplicate Window: 2m0s
                   Direct Get: true
  Allows Atomic Batch Publish: false
    Allows Fast Batch Publish: false
              Allows Counters: false
            Allows Msg Delete: true
       Allows Per-Message TTL: false
                 Allows Purge: true
             Allows Schedules: false
               Allows Rollups: false

Limits:

             Maximum Messages: unlimited
          Maximum Per Subject: unlimited
                Maximum Bytes: unlimited
                  Maximum Age: unlimited
         Maximum Message Size: unlimited
            Maximum Consumers: unlimited

Cluster Information:

                         Name: east
                Cluster Group: S-R3F-zHrMNfYE
                       Leader: n2 (60µs)
                      Replica: n1, current, seen 68µs ago
                      Replica: n3, outdated, not seen, 1 operation behind

State:

                 Host Version: 2.14.6
           Required API Level: 0 hosted at level 4
                     Messages: 0
                        Bytes: 0 B
               First Sequence: 0
                Last Sequence: 0
             Active Consumers: 0

$ nats pub orders.new --count 30 order {{Count}}
 done! [30 in 2ms; 13.19K/s]

$ nats consumer add ORDERS shipping --pull --ack explicit --wait 3s --max-deliver=-1 --deliver all --filter orders.> --defaults
Information for Consumer ORDERS > shipping created 2026-09-03 04:41:44

Configuration:

                    Name: shipping
               Pull Mode: true
          Filter Subject: orders.>
          Deliver Policy: All
              Ack Policy: Explicit
                Ack Wait: 3.00s
           Replay Policy: Instant
         Max Ack Pending: 1,000
       Max Waiting Pulls: 512

Cluster Information:

                    Name: east
              Raft Group: C-R3F-xfHKk1O2
                  Leader: n2 (4ms)
                 Replica: n1, current, seen 4ms ago
                 Replica: n3, outdated, not seen

State:

            Host Version: 2.14.6
      Required API Level: 0 hosted at level 4
  Last Delivered Message: Consumer sequence: 0 Stream sequence: 0
    Acknowledgment Floor: Consumer sequence: 0 Stream sequence: 0
        Outstanding Acks: 0 out of maximum 1,000
    Redelivered Messages: 0
    Unprocessed Messages: 30
           Waiting Pulls: 0 of maximum 512

$ nats consumer next ORDERS shipping --count 10 --no-ack
[04:41:45] subj: orders.new / tries: 1 / cons seq: 1 / str seq: 1 / pending: 29

order 1
[04:41:45] subj: orders.new / tries: 1 / cons seq: 2 / str seq: 2 / pending: 28

order 2
[04:41:45] subj: orders.new / tries: 1 / cons seq: 3 / str seq: 3 / pending: 27

order 3
[04:41:45] subj: orders.new / tries: 1 / cons seq: 4 / str seq: 4 / pending: 26

order 4
[04:41:45] subj: orders.new / tries: 1 / cons seq: 5 / str seq: 5 / pending: 25

order 5
[04:41:45] subj: orders.new / tries: 1 / cons seq: 6 / str seq: 6 / pending: 24

order 6
[04:41:45] subj: orders.new / tries: 1 / cons seq: 7 / str seq: 7 / pending: 23

order 7
[04:41:45] subj: orders.new / tries: 1 / cons seq: 8 / str seq: 8 / pending: 22

order 8
[04:41:45] subj: orders.new / tries: 1 / cons seq: 9 / str seq: 9 / pending: 21

order 9
[04:41:45] subj: orders.new / tries: 1 / cons seq: 10 / str seq: 10 / pending: 20

order 10

$ nats consumer next ORDERS shipping --count 10 --no-ack
[04:41:49] subj: orders.new / tries: 2 / cons seq: 11 / str seq: 1 / pending: 20

order 1
[04:41:49] subj: orders.new / tries: 2 / cons seq: 12 / str seq: 2 / pending: 20

order 2
[04:41:49] subj: orders.new / tries: 2 / cons seq: 13 / str seq: 3 / pending: 20

order 3
[04:41:49] subj: orders.new / tries: 2 / cons seq: 14 / str seq: 4 / pending: 20

order 4
[04:41:49] subj: orders.new / tries: 2 / cons seq: 15 / str seq: 5 / pending: 20

order 5
[04:41:49] subj: orders.new / tries: 2 / cons seq: 16 / str seq: 6 / pending: 20

order 6
[04:41:49] subj: orders.new / tries: 2 / cons seq: 17 / str seq: 7 / pending: 20

order 7
[04:41:49] subj: orders.new / tries: 2 / cons seq: 18 / str seq: 8 / pending: 20

order 8
[04:41:49] subj: orders.new / tries: 2 / cons seq: 19 / str seq: 9 / pending: 20

order 9
[04:41:49] subj: orders.new / tries: 2 / cons seq: 20 / str seq: 10 / pending: 20

order 10

$ nats stream add ORDERS_MIRROR --mirror ORDERS --replicas 1 --storage file --defaults
Stream ORDERS_MIRROR was created

Information for Stream ORDERS_MIRROR created 2026-09-03 04:41:49

                     Replicas: 1
                      Storage: File

Options:

                    Retention: Limits
              Acknowledgments: true
               Discard Policy: Old
             Duplicate Window: 0s
                   Direct Get: true
            Mirror Direct Get: true
  Allows Atomic Batch Publish: false
    Allows Fast Batch Publish: false
              Allows Counters: false
            Allows Msg Delete: true
       Allows Per-Message TTL: false
                 Allows Purge: true
             Allows Schedules: false
               Allows Rollups: false

Limits:

             Maximum Messages: unlimited
          Maximum Per Subject: unlimited
                Maximum Bytes: unlimited
                  Maximum Age: unlimited
         Maximum Message Size: unlimited
            Maximum Consumers: unlimited

Replication:

                       Mirror: ORDERS

Cluster Information:

                         Name: east
                       Leader: n2

Mirror Information:

                  Stream Name: ORDERS
                          Lag: 0
                    Last Seen: never

State:

                 Host Version: 2.14.6
           Required API Level: 0 hosted at level 4
                     Messages: 0
                        Bytes: 0 B
               First Sequence: 0
                Last Sequence: 0
             Active Consumers: 0

$ nats stream add ORDERS_AGG --source ORDERS --replicas 1 --storage file --defaults
Stream ORDERS_AGG was created

Information for Stream ORDERS_AGG created 2026-09-03 04:41:49

                     Replicas: 1
                      Storage: File

Options:

                    Retention: Limits
              Acknowledgments: true
               Discard Policy: Old
             Duplicate Window: 2m0s
                   Direct Get: true
  Allows Atomic Batch Publish: false
    Allows Fast Batch Publish: false
              Allows Counters: false
            Allows Msg Delete: true
       Allows Per-Message TTL: false
                 Allows Purge: true
             Allows Schedules: false
               Allows Rollups: false

Limits:

             Maximum Messages: unlimited
          Maximum Per Subject: unlimited
                Maximum Bytes: unlimited
                  Maximum Age: unlimited
         Maximum Message Size: unlimited
            Maximum Consumers: unlimited

Replication:

                      Sources: ORDERS

Cluster Information:

                         Name: east
                       Leader: n2

Source Information:

                  Stream Name: ORDERS
                          Lag: 0
                    Last Seen: never

State:

                 Host Version: 2.14.6
           Required API Level: 0 hosted at level 4
                     Messages: 0
                        Bytes: 0 B
               First Sequence: 0
                Last Sequence: 0
             Active Consumers: 0

$ nats consumer info ORDERS shipping
Information for Consumer ORDERS > shipping created 2026-09-03 04:41:44

Configuration:

                    Name: shipping
               Pull Mode: true
          Filter Subject: orders.>
          Deliver Policy: All
              Ack Policy: Explicit
                Ack Wait: 3.00s
           Replay Policy: Instant
         Max Ack Pending: 1,000
       Max Waiting Pulls: 512

Cluster Information:

                    Name: east
              Raft Group: C-R3F-xfHKk1O2
                  Leader: n2 (6.16s)
                 Replica: n1, current, seen 157ms ago
                 Replica: n3, current, seen 158ms ago

State:

            Host Version: 2.14.6
      Required API Level: 0 hosted at level 4
  Last Delivered Message: Consumer sequence: 20 Stream sequence: 10 Last delivery: 2.08s ago
    Acknowledgment Floor: Consumer sequence: 0 Stream sequence: 0
        Outstanding Acks: 10 out of maximum 1,000
    Redelivered Messages: 10
    Unprocessed Messages: 20
           Waiting Pulls: 0 of maximum 512

$ nats stream info ORDERS
Information for Stream ORDERS created 2026-09-03 04:41:44

                     Subjects: orders.>
                     Replicas: 3
                      Storage: File

Options:

                    Retention: Limits
              Acknowledgments: true
               Discard Policy: Old
             Duplicate Window: 2m0s
                   Direct Get: true
  Allows Atomic Batch Publish: false
    Allows Fast Batch Publish: false
              Allows Counters: false
            Allows Msg Delete: true
       Allows Per-Message TTL: false
                 Allows Purge: true
             Allows Schedules: false
               Allows Rollups: false

Limits:

             Maximum Messages: unlimited
          Maximum Per Subject: unlimited
                Maximum Bytes: unlimited
                  Maximum Age: unlimited
         Maximum Message Size: unlimited
            Maximum Consumers: unlimited

Cluster Information:

                         Name: east
                Cluster Group: S-R3F-zHrMNfYE
                       Leader: n2 (6.61s)
                      Replica: n1, current, seen 611ms ago
                      Replica: n3, current, seen 611ms ago

State:

                 Host Version: 2.14.6
           Required API Level: 0 hosted at level 4
                     Messages: 30
                        Bytes: 1.4 KiB
               First Sequence: 1 @ 2026-09-03 04:41:44
                Last Sequence: 30 @ 2026-09-03 04:41:44
             Active Consumers: 1
           Number of Subjects: 1
                   Alternates:        ORDERS: Cluster: east
                               ORDERS_MIRROR: Cluster: east
```


## Run A · every collector, default prefixes, node n1

```
$ prometheus-nats-exporter -varz -connz -routez -subz -healthz -healthz_js_enabled_only -healthz_js_server_only -gatewayz -leafz -accountz -accstatz -jsz=all -port 7777 http://127.0.0.1:8291
```

Exporter log (first lines):

```
[18136] 2026/09/03 04:41:51.279164 [INF] Prometheus exporter listening at http://0.0.0.0:7777/metrics
```

Scrape of `http://127.0.0.1:7777/metrics` — 167 `# HELP` lines kept, 38 `go_*`/`process_*`/`promhttp_*` series (122 lines) dropped:

```
# HELP gnatsd_accountz_client_connections client_connections
# TYPE gnatsd_accountz_client_connections gauge
gnatsd_accountz_client_connections{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accountz_client_connections{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_accountz_complete complete
# TYPE gnatsd_accountz_complete gauge
gnatsd_accountz_complete{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 1
gnatsd_accountz_complete{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_accountz_expired expired
# TYPE gnatsd_accountz_expired gauge
gnatsd_accountz_expired{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accountz_expired{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_accountz_is_system is_system
# TYPE gnatsd_accountz_is_system gauge
gnatsd_accountz_is_system{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accountz_is_system{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_accountz_jetstream_enabled jetstream_enabled
# TYPE gnatsd_accountz_jetstream_enabled gauge
gnatsd_accountz_jetstream_enabled{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 1
gnatsd_accountz_jetstream_enabled{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_accountz_leafnode_connections leafnode_connections
# TYPE gnatsd_accountz_leafnode_connections gauge
gnatsd_accountz_leafnode_connections{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accountz_leafnode_connections{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_accountz_limit_conn limit_conn
# TYPE gnatsd_accountz_limit_conn gauge
gnatsd_accountz_limit_conn{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accountz_limit_conn{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_accountz_limit_data limit_data
# TYPE gnatsd_accountz_limit_data gauge
gnatsd_accountz_limit_data{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accountz_limit_data{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_accountz_limit_exports limit_exports
# TYPE gnatsd_accountz_limit_exports gauge
gnatsd_accountz_limit_exports{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accountz_limit_exports{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_accountz_limit_imports limit_imports
# TYPE gnatsd_accountz_limit_imports gauge
gnatsd_accountz_limit_imports{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accountz_limit_imports{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_accountz_limit_leaf limit_leaf
# TYPE gnatsd_accountz_limit_leaf gauge
gnatsd_accountz_limit_leaf{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accountz_limit_leaf{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_accountz_limit_payload limit_payload
# TYPE gnatsd_accountz_limit_payload gauge
gnatsd_accountz_limit_payload{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accountz_limit_payload{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_accountz_limit_subs limit_subs
# TYPE gnatsd_accountz_limit_subs gauge
gnatsd_accountz_limit_subs{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accountz_limit_subs{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_accountz_limit_wildcards limit_wildcards
# TYPE gnatsd_accountz_limit_wildcards gauge
gnatsd_accountz_limit_wildcards{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accountz_limit_wildcards{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_accountz_subscriptions subscriptions
# TYPE gnatsd_accountz_subscriptions gauge
gnatsd_accountz_subscriptions{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 30
gnatsd_accountz_subscriptions{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 228
# HELP gnatsd_accstatz_current_connections current_connections
# TYPE gnatsd_accstatz_current_connections gauge
gnatsd_accstatz_current_connections{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accstatz_current_connections{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_accstatz_leaf_nodes leaf_nodes
# TYPE gnatsd_accstatz_leaf_nodes gauge
gnatsd_accstatz_leaf_nodes{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accstatz_leaf_nodes{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_accstatz_received_bytes received_bytes
# TYPE gnatsd_accstatz_received_bytes gauge
gnatsd_accstatz_received_bytes{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 2469
gnatsd_accstatz_received_bytes{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 182640
# HELP gnatsd_accstatz_received_messages received_messages
# TYPE gnatsd_accstatz_received_messages gauge
gnatsd_accstatz_received_messages{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 83
gnatsd_accstatz_received_messages{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 884
# HELP gnatsd_accstatz_sent_bytes sent_bytes
# TYPE gnatsd_accstatz_sent_bytes gauge
gnatsd_accstatz_sent_bytes{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 11777
gnatsd_accstatz_sent_bytes{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 93705
# HELP gnatsd_accstatz_sent_messages sent_messages
# TYPE gnatsd_accstatz_sent_messages gauge
gnatsd_accstatz_sent_messages{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 83
gnatsd_accstatz_sent_messages{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 454
# HELP gnatsd_accstatz_slow_consumers slow_consumers
# TYPE gnatsd_accstatz_slow_consumers gauge
gnatsd_accstatz_slow_consumers{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accstatz_slow_consumers{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_accstatz_subscriptions subscriptions
# TYPE gnatsd_accstatz_subscriptions gauge
gnatsd_accstatz_subscriptions{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 30
gnatsd_accstatz_subscriptions{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 228
# HELP gnatsd_accstatz_total_connections total_connections
# TYPE gnatsd_accstatz_total_connections gauge
gnatsd_accstatz_total_connections{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
gnatsd_accstatz_total_connections{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_in_bytes in_bytes
# TYPE gnatsd_connz_in_bytes counter
gnatsd_connz_in_bytes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_in_msgs in_msgs
# TYPE gnatsd_connz_in_msgs counter
gnatsd_connz_in_msgs{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_limit limit
# TYPE gnatsd_connz_limit gauge
gnatsd_connz_limit{server_id="http://127.0.0.1:8291"} 1024
# HELP gnatsd_connz_num_connections num_connections
# TYPE gnatsd_connz_num_connections gauge
gnatsd_connz_num_connections{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_offset offset
# TYPE gnatsd_connz_offset gauge
gnatsd_connz_offset{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_out_bytes out_bytes
# TYPE gnatsd_connz_out_bytes counter
gnatsd_connz_out_bytes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_out_msgs out_msgs
# TYPE gnatsd_connz_out_msgs counter
gnatsd_connz_out_msgs{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_pending_bytes pending_bytes
# TYPE gnatsd_connz_pending_bytes gauge
gnatsd_connz_pending_bytes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_subscriptions subscriptions
# TYPE gnatsd_connz_subscriptions gauge
gnatsd_connz_subscriptions{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_total total
# TYPE gnatsd_connz_total gauge
gnatsd_connz_total{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_healthz_js_enabled_only_status status
# TYPE gnatsd_healthz_js_enabled_only_status gauge
gnatsd_healthz_js_enabled_only_status{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_healthz_js_enabled_only_status_value status
# TYPE gnatsd_healthz_js_enabled_only_status_value gauge
gnatsd_healthz_js_enabled_only_status_value{server_id="http://127.0.0.1:8291",value="ok"} 1
# HELP gnatsd_healthz_js_server_only_status status
# TYPE gnatsd_healthz_js_server_only_status gauge
gnatsd_healthz_js_server_only_status{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_healthz_js_server_only_status_value status
# TYPE gnatsd_healthz_js_server_only_status_value gauge
gnatsd_healthz_js_server_only_status_value{server_id="http://127.0.0.1:8291",value="ok"} 1
# HELP gnatsd_healthz_status status
# TYPE gnatsd_healthz_status gauge
gnatsd_healthz_status{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_healthz_status_value status
# TYPE gnatsd_healthz_status_value gauge
gnatsd_healthz_status_value{server_id="http://127.0.0.1:8291",value="ok"} 1
# HELP gnatsd_leafz_conn_nodes_total nodes_total
# TYPE gnatsd_leafz_conn_nodes_total gauge
gnatsd_leafz_conn_nodes_total{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_routez_num_routes num_routes
# TYPE gnatsd_routez_num_routes gauge
gnatsd_routez_num_routes{server_id="http://127.0.0.1:8291"} 8
# HELP gnatsd_routez_server_id server_id
# TYPE gnatsd_routez_server_id gauge
gnatsd_routez_server_id{server_id="http://127.0.0.1:8291",value="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S"} 1
# HELP gnatsd_routez_server_name server_name
# TYPE gnatsd_routez_server_name gauge
gnatsd_routez_server_name{server_id="http://127.0.0.1:8291",value="n1"} 1
# HELP gnatsd_subsz_avg_fanout avg_fanout
# TYPE gnatsd_subsz_avg_fanout gauge
gnatsd_subsz_avg_fanout{server_id="http://127.0.0.1:8291"} 1.9574468085106382
# HELP gnatsd_subsz_cache_hit_rate cache_hit_rate
# TYPE gnatsd_subsz_cache_hit_rate gauge
gnatsd_subsz_cache_hit_rate{server_id="http://127.0.0.1:8291"} 0.5497630331753555
# HELP gnatsd_subsz_limit limit
# TYPE gnatsd_subsz_limit gauge
gnatsd_subsz_limit{server_id="http://127.0.0.1:8291"} 1024
# HELP gnatsd_subsz_max_fanout max_fanout
# TYPE gnatsd_subsz_max_fanout gauge
gnatsd_subsz_max_fanout{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_subsz_num_cache num_cache
# TYPE gnatsd_subsz_num_cache gauge
gnatsd_subsz_num_cache{server_id="http://127.0.0.1:8291"} 47
# HELP gnatsd_subsz_num_inserts num_inserts
# TYPE gnatsd_subsz_num_inserts gauge
gnatsd_subsz_num_inserts{server_id="http://127.0.0.1:8291"} 289
# HELP gnatsd_subsz_num_matches num_matches
# TYPE gnatsd_subsz_num_matches gauge
gnatsd_subsz_num_matches{server_id="http://127.0.0.1:8291"} 211
# HELP gnatsd_subsz_num_removes num_removes
# TYPE gnatsd_subsz_num_removes gauge
gnatsd_subsz_num_removes{server_id="http://127.0.0.1:8291"} 31
# HELP gnatsd_subsz_num_subscriptions num_subscriptions
# TYPE gnatsd_subsz_num_subscriptions gauge
gnatsd_subsz_num_subscriptions{server_id="http://127.0.0.1:8291"} 258
# HELP gnatsd_subsz_offset offset
# TYPE gnatsd_subsz_offset gauge
gnatsd_subsz_offset{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_subsz_server_id server_id
# TYPE gnatsd_subsz_server_id gauge
gnatsd_subsz_server_id{server_id="http://127.0.0.1:8291",value="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S"} 1
# HELP gnatsd_subsz_total total
# TYPE gnatsd_subsz_total gauge
gnatsd_subsz_total{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_auth_timeout auth_timeout
# TYPE gnatsd_varz_auth_timeout gauge
gnatsd_varz_auth_timeout{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_cluster_name cluster_name
# TYPE gnatsd_varz_cluster_name gauge
gnatsd_varz_cluster_name{server_id="http://127.0.0.1:8291",value="east"} 1
# HELP gnatsd_varz_cluster_pool_size cluster_pool_size
# TYPE gnatsd_varz_cluster_pool_size gauge
gnatsd_varz_cluster_pool_size{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_varz_config_load_time config_load_time
# TYPE gnatsd_varz_config_load_time gauge
gnatsd_varz_config_load_time{server_id="http://127.0.0.1:8291"} 1.788403202188e+12
# HELP gnatsd_varz_connections connections
# TYPE gnatsd_varz_connections gauge
gnatsd_varz_connections{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_cores cores
# TYPE gnatsd_varz_cores gauge
gnatsd_varz_cores{server_id="http://127.0.0.1:8291"} 10
# HELP gnatsd_varz_cpu cpu
# TYPE gnatsd_varz_cpu gauge
gnatsd_varz_cpu{server_id="http://127.0.0.1:8291"} 0.5
# HELP gnatsd_varz_disk_io_wait_stats_max_wait_time disk_io_wait_stats_max_wait_time
# TYPE gnatsd_varz_disk_io_wait_stats_max_wait_time gauge
gnatsd_varz_disk_io_wait_stats_max_wait_time{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_disk_io_wait_stats_wait_time disk_io_wait_stats_wait_time
# TYPE gnatsd_varz_disk_io_wait_stats_wait_time gauge
gnatsd_varz_disk_io_wait_stats_wait_time{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_disk_io_wait_stats_waiters disk_io_wait_stats_waiters
# TYPE gnatsd_varz_disk_io_wait_stats_waiters gauge
gnatsd_varz_disk_io_wait_stats_waiters{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_disk_io_wait_stats_waits disk_io_wait_stats_waits
# TYPE gnatsd_varz_disk_io_wait_stats_waits gauge
gnatsd_varz_disk_io_wait_stats_waits{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_gomaxprocs gomaxprocs
# TYPE gnatsd_varz_gomaxprocs gauge
gnatsd_varz_gomaxprocs{server_id="http://127.0.0.1:8291"} 10
# HELP gnatsd_varz_http_port http_port
# TYPE gnatsd_varz_http_port gauge
gnatsd_varz_http_port{server_id="http://127.0.0.1:8291"} 8291
# HELP gnatsd_varz_http_req_stats_accountz http_req_stats_accountz
# TYPE gnatsd_varz_http_req_stats_accountz gauge
gnatsd_varz_http_req_stats_accountz{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_http_req_stats_accstatz http_req_stats_accstatz
# TYPE gnatsd_varz_http_req_stats_accstatz gauge
gnatsd_varz_http_req_stats_accstatz{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_varz_http_req_stats_connz http_req_stats_connz
# TYPE gnatsd_varz_http_req_stats_connz gauge
gnatsd_varz_http_req_stats_connz{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_varz_http_req_stats_gatewayz http_req_stats_gatewayz
# TYPE gnatsd_varz_http_req_stats_gatewayz gauge
gnatsd_varz_http_req_stats_gatewayz{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_varz_http_req_stats_healthz http_req_stats_healthz
# TYPE gnatsd_varz_http_req_stats_healthz gauge
gnatsd_varz_http_req_stats_healthz{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_http_req_stats_jsz http_req_stats_jsz
# TYPE gnatsd_varz_http_req_stats_jsz gauge
gnatsd_varz_http_req_stats_jsz{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_http_req_stats_leafz http_req_stats_leafz
# TYPE gnatsd_varz_http_req_stats_leafz gauge
gnatsd_varz_http_req_stats_leafz{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_varz_http_req_stats_routez http_req_stats_routez
# TYPE gnatsd_varz_http_req_stats_routez gauge
gnatsd_varz_http_req_stats_routez{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_varz_http_req_stats_subsz http_req_stats_subsz
# TYPE gnatsd_varz_http_req_stats_subsz gauge
gnatsd_varz_http_req_stats_subsz{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_varz_http_req_stats_varz http_req_stats_varz
# TYPE gnatsd_varz_http_req_stats_varz gauge
gnatsd_varz_http_req_stats_varz{server_id="http://127.0.0.1:8291"} 5
# HELP gnatsd_varz_https_port https_port
# TYPE gnatsd_varz_https_port gauge
gnatsd_varz_https_port{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_in_bytes in_bytes
# TYPE gnatsd_varz_in_bytes gauge
gnatsd_varz_in_bytes{server_id="http://127.0.0.1:8291"} 93789
# HELP gnatsd_varz_in_client_bytes in_client_bytes
# TYPE gnatsd_varz_in_client_bytes gauge
gnatsd_varz_in_client_bytes{server_id="http://127.0.0.1:8291"} 2327
# HELP gnatsd_varz_in_client_msgs in_client_msgs
# TYPE gnatsd_varz_in_client_msgs gauge
gnatsd_varz_in_client_msgs{server_id="http://127.0.0.1:8291"} 63
# HELP gnatsd_varz_in_msgs in_msgs
# TYPE gnatsd_varz_in_msgs gauge
gnatsd_varz_in_msgs{server_id="http://127.0.0.1:8291"} 525
# HELP gnatsd_varz_jetstream_config_max_memory jetstream_config_max_memory
# TYPE gnatsd_varz_jetstream_config_max_memory gauge
gnatsd_varz_jetstream_config_max_memory{server_id="http://127.0.0.1:8291"} 2.5769803776e+10
# HELP gnatsd_varz_jetstream_config_max_storage jetstream_config_max_storage
# TYPE gnatsd_varz_jetstream_config_max_storage gauge
gnatsd_varz_jetstream_config_max_storage{server_id="http://127.0.0.1:8291"} 7.424265216e+10
# HELP gnatsd_varz_jetstream_config_sync_interval jetstream_config_sync_interval
# TYPE gnatsd_varz_jetstream_config_sync_interval gauge
gnatsd_varz_jetstream_config_sync_interval{server_id="http://127.0.0.1:8291"} 1.2e+11
# HELP gnatsd_varz_jetstream_meta_cluster_size jetstream_meta_cluster_size
# TYPE gnatsd_varz_jetstream_meta_cluster_size gauge
gnatsd_varz_jetstream_meta_cluster_size{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_varz_jetstream_meta_leader jetstream_meta_leader
# TYPE gnatsd_varz_jetstream_meta_leader gauge
gnatsd_varz_jetstream_meta_leader{server_id="http://127.0.0.1:8291",value="n1"} 1
# HELP gnatsd_varz_jetstream_meta_name jetstream_meta_name
# TYPE gnatsd_varz_jetstream_meta_name gauge
gnatsd_varz_jetstream_meta_name{server_id="http://127.0.0.1:8291",value="east"} 1
# HELP gnatsd_varz_jetstream_meta_pending jetstream_meta_pending
# TYPE gnatsd_varz_jetstream_meta_pending gauge
gnatsd_varz_jetstream_meta_pending{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_meta_pending_infos jetstream_meta_pending_infos
# TYPE gnatsd_varz_jetstream_meta_pending_infos gauge
gnatsd_varz_jetstream_meta_pending_infos{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_meta_pending_requests jetstream_meta_pending_requests
# TYPE gnatsd_varz_jetstream_meta_pending_requests gauge
gnatsd_varz_jetstream_meta_pending_requests{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_meta_snapshot_pending_entries jetstream_meta_snapshot_pending_entries
# TYPE gnatsd_varz_jetstream_meta_snapshot_pending_entries gauge
gnatsd_varz_jetstream_meta_snapshot_pending_entries{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_jetstream_meta_snapshot_pending_size jetstream_meta_snapshot_pending_size
# TYPE gnatsd_varz_jetstream_meta_snapshot_pending_size gauge
gnatsd_varz_jetstream_meta_snapshot_pending_size{server_id="http://127.0.0.1:8291"} 4180
# HELP gnatsd_varz_jetstream_stats_accounts jetstream_stats_accounts
# TYPE gnatsd_varz_jetstream_stats_accounts gauge
gnatsd_varz_jetstream_stats_accounts{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_varz_jetstream_stats_api_errors jetstream_stats_api_errors
# TYPE gnatsd_varz_jetstream_stats_api_errors gauge
gnatsd_varz_jetstream_stats_api_errors{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_varz_jetstream_stats_api_level jetstream_stats_api_level
# TYPE gnatsd_varz_jetstream_stats_api_level gauge
gnatsd_varz_jetstream_stats_api_level{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_jetstream_stats_api_total jetstream_stats_api_total
# TYPE gnatsd_varz_jetstream_stats_api_total gauge
gnatsd_varz_jetstream_stats_api_total{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_jetstream_stats_ha_assets jetstream_stats_ha_assets
# TYPE gnatsd_varz_jetstream_stats_ha_assets gauge
gnatsd_varz_jetstream_stats_ha_assets{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_varz_jetstream_stats_memory jetstream_stats_memory
# TYPE gnatsd_varz_jetstream_stats_memory gauge
gnatsd_varz_jetstream_stats_memory{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_stats_reserved_memory jetstream_stats_reserved_memory
# TYPE gnatsd_varz_jetstream_stats_reserved_memory gauge
gnatsd_varz_jetstream_stats_reserved_memory{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_stats_reserved_storage jetstream_stats_reserved_storage
# TYPE gnatsd_varz_jetstream_stats_reserved_storage gauge
gnatsd_varz_jetstream_stats_reserved_storage{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_stats_storage jetstream_stats_storage
# TYPE gnatsd_varz_jetstream_stats_storage gauge
gnatsd_varz_jetstream_stats_storage{server_id="http://127.0.0.1:8291"} 1431
# HELP gnatsd_varz_leafnodes leafnodes
# TYPE gnatsd_varz_leafnodes gauge
gnatsd_varz_leafnodes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_max_connections max_connections
# TYPE gnatsd_varz_max_connections gauge
gnatsd_varz_max_connections{server_id="http://127.0.0.1:8291"} 65536
# HELP gnatsd_varz_max_control_line max_control_line
# TYPE gnatsd_varz_max_control_line gauge
gnatsd_varz_max_control_line{server_id="http://127.0.0.1:8291"} 4096
# HELP gnatsd_varz_max_payload max_payload
# TYPE gnatsd_varz_max_payload gauge
gnatsd_varz_max_payload{server_id="http://127.0.0.1:8291"} 1.048576e+06
# HELP gnatsd_varz_max_pending max_pending
# TYPE gnatsd_varz_max_pending gauge
gnatsd_varz_max_pending{server_id="http://127.0.0.1:8291"} 6.7108864e+07
# HELP gnatsd_varz_mem mem
# TYPE gnatsd_varz_mem gauge
gnatsd_varz_mem{server_id="http://127.0.0.1:8291"} 2.9212672e+07
# HELP gnatsd_varz_out_bytes out_bytes
# TYPE gnatsd_varz_out_bytes gauge
gnatsd_varz_out_bytes{server_id="http://127.0.0.1:8291"} 105482
# HELP gnatsd_varz_out_client_bytes out_client_bytes
# TYPE gnatsd_varz_out_client_bytes gauge
gnatsd_varz_out_client_bytes{server_id="http://127.0.0.1:8291"} 10906
# HELP gnatsd_varz_out_client_msgs out_client_msgs
# TYPE gnatsd_varz_out_client_msgs gauge
gnatsd_varz_out_client_msgs{server_id="http://127.0.0.1:8291"} 33
# HELP gnatsd_varz_out_msgs out_msgs
# TYPE gnatsd_varz_out_msgs gauge
gnatsd_varz_out_msgs{server_id="http://127.0.0.1:8291"} 537
# HELP gnatsd_varz_ping_interval ping_interval
# TYPE gnatsd_varz_ping_interval gauge
gnatsd_varz_ping_interval{server_id="http://127.0.0.1:8291"} 1.2e+11
# HELP gnatsd_varz_ping_max ping_max
# TYPE gnatsd_varz_ping_max gauge
gnatsd_varz_ping_max{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_port port
# TYPE gnatsd_varz_port gauge
gnatsd_varz_port{server_id="http://127.0.0.1:8291"} 4291
# HELP gnatsd_varz_proto proto
# TYPE gnatsd_varz_proto gauge
gnatsd_varz_proto{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_varz_remotes remotes
# TYPE gnatsd_varz_remotes gauge
gnatsd_varz_remotes{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_routes routes
# TYPE gnatsd_varz_routes gauge
gnatsd_varz_routes{server_id="http://127.0.0.1:8291"} 8
# HELP gnatsd_varz_server_id server_id
# TYPE gnatsd_varz_server_id gauge
gnatsd_varz_server_id{server_id="http://127.0.0.1:8291",value="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S"} 1
# HELP gnatsd_varz_server_name server_name
# TYPE gnatsd_varz_server_name gauge
gnatsd_varz_server_name{server_id="http://127.0.0.1:8291",value="n1"} 1
# HELP gnatsd_varz_slow_consumer_stats_clients slow_consumer_stats_clients
# TYPE gnatsd_varz_slow_consumer_stats_clients gauge
gnatsd_varz_slow_consumer_stats_clients{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumer_stats_gateways slow_consumer_stats_gateways
# TYPE gnatsd_varz_slow_consumer_stats_gateways gauge
gnatsd_varz_slow_consumer_stats_gateways{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumer_stats_leafs slow_consumer_stats_leafs
# TYPE gnatsd_varz_slow_consumer_stats_leafs gauge
gnatsd_varz_slow_consumer_stats_leafs{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumer_stats_routes slow_consumer_stats_routes
# TYPE gnatsd_varz_slow_consumer_stats_routes gauge
gnatsd_varz_slow_consumer_stats_routes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumers slow_consumers
# TYPE gnatsd_varz_slow_consumers gauge
gnatsd_varz_slow_consumers{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_clients stale_connection_stats_clients
# TYPE gnatsd_varz_stale_connection_stats_clients gauge
gnatsd_varz_stale_connection_stats_clients{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_gateways stale_connection_stats_gateways
# TYPE gnatsd_varz_stale_connection_stats_gateways gauge
gnatsd_varz_stale_connection_stats_gateways{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_leafs stale_connection_stats_leafs
# TYPE gnatsd_varz_stale_connection_stats_leafs gauge
gnatsd_varz_stale_connection_stats_leafs{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_routes stale_connection_stats_routes
# TYPE gnatsd_varz_stale_connection_stats_routes gauge
gnatsd_varz_stale_connection_stats_routes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connections stale_connections
# TYPE gnatsd_varz_stale_connections gauge
gnatsd_varz_stale_connections{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stalled_clients stalled_clients
# TYPE gnatsd_varz_stalled_clients gauge
gnatsd_varz_stalled_clients{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_start start
# TYPE gnatsd_varz_start gauge
gnatsd_varz_start{server_id="http://127.0.0.1:8291"} 1.788403202188e+12
# HELP gnatsd_varz_subscriptions subscriptions
# TYPE gnatsd_varz_subscriptions gauge
gnatsd_varz_subscriptions{server_id="http://127.0.0.1:8291"} 258
# HELP gnatsd_varz_tls_timeout tls_timeout
# TYPE gnatsd_varz_tls_timeout gauge
gnatsd_varz_tls_timeout{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_total_connections total_connections
# TYPE gnatsd_varz_total_connections gauge
gnatsd_varz_total_connections{server_id="http://127.0.0.1:8291"} 9
# HELP gnatsd_varz_version version
# TYPE gnatsd_varz_version gauge
gnatsd_varz_version{server_id="http://127.0.0.1:8291",value="2.14.6"} 1
# HELP gnatsd_varz_write_deadline write_deadline
# TYPE gnatsd_varz_write_deadline gauge
gnatsd_varz_write_deadline{server_id="http://127.0.0.1:8291"} 1e+10
# HELP jetstream_account_max_memory JetStream Account Max Memory in bytes
# TYPE jetstream_account_max_memory gauge
jetstream_account_max_memory{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1.8446744073709552e+19
# HELP jetstream_account_max_storage JetStream Account Max Storage in bytes
# TYPE jetstream_account_max_storage gauge
jetstream_account_max_storage{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1.8446744073709552e+19
# HELP jetstream_account_memory_used Total number of bytes used by JetStream memory
# TYPE jetstream_account_memory_used gauge
jetstream_account_memory_used{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 0
# HELP jetstream_account_storage_used Total number of bytes used by JetStream storage
# TYPE jetstream_account_storage_used gauge
jetstream_account_storage_used{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 9006
# HELP jetstream_consumer_ack_floor_consumer_seq Number of ack floor consumer seq from a consumer
# TYPE jetstream_consumer_ack_floor_consumer_seq gauge
jetstream_consumer_ack_floor_consumer_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0
# HELP jetstream_consumer_ack_floor_stream_seq Number of ack floor stream seq from a consumer
# TYPE jetstream_consumer_ack_floor_stream_seq gauge
jetstream_consumer_ack_floor_stream_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0
# HELP jetstream_consumer_delivered_consumer_seq Latest sequence number of a stream consumer
# TYPE jetstream_consumer_delivered_consumer_seq gauge
jetstream_consumer_delivered_consumer_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 20
# HELP jetstream_consumer_delivered_stream_seq Latest sequence number of a stream
# TYPE jetstream_consumer_delivered_stream_seq gauge
jetstream_consumer_delivered_stream_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 10
# HELP jetstream_consumer_last_delivery_seconds Seconds since last message delivery to consumer
# TYPE jetstream_consumer_last_delivery_seconds gauge
jetstream_consumer_last_delivery_seconds{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 2.156446
# HELP jetstream_consumer_num_ack_pending Number of pending acks from a consumer
# TYPE jetstream_consumer_num_ack_pending gauge
jetstream_consumer_num_ack_pending{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 10
# HELP jetstream_consumer_num_pending Number of pending messages from a consumer
# TYPE jetstream_consumer_num_pending gauge
jetstream_consumer_num_pending{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0
# HELP jetstream_consumer_num_redelivered Number of redelivered messages from a consumer
# TYPE jetstream_consumer_num_redelivered gauge
jetstream_consumer_num_redelivered{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 10
# HELP jetstream_consumer_num_waiting Number of inflight fetch requests from a pull consumer
# TYPE jetstream_consumer_num_waiting gauge
jetstream_consumer_num_waiting{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0
# HELP jetstream_server_jetstream_disabled JetStream disabled or not
# TYPE jetstream_server_jetstream_disabled gauge
jetstream_server_jetstream_disabled{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 0
# HELP jetstream_server_max_memory JetStream Max Memory
# TYPE jetstream_server_max_memory gauge
jetstream_server_max_memory{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 2.5769803776e+10
# HELP jetstream_server_max_storage JetStream Max Storage
# TYPE jetstream_server_max_storage gauge
jetstream_server_max_storage{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 7.424265216e+10
# HELP jetstream_server_total_consumers Total number of consumers in JetStream
# TYPE jetstream_server_total_consumers gauge
jetstream_server_total_consumers{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1
# HELP jetstream_server_total_message_bytes Total number of bytes stored in JetStream
# TYPE jetstream_server_total_message_bytes gauge
jetstream_server_total_message_bytes{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1431
# HELP jetstream_server_total_messages Total number of stored messages in JetStream
# TYPE jetstream_server_total_messages gauge
jetstream_server_total_messages{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 30
# HELP jetstream_server_total_streams Total number of streams in JetStream
# TYPE jetstream_server_total_streams gauge
jetstream_server_total_streams{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1
# HELP jetstream_stream_consumer_count Total number of consumers from a stream
# TYPE jetstream_stream_consumer_count gauge
jetstream_stream_consumer_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP jetstream_stream_first_seq First sequence from a stream
# TYPE jetstream_stream_first_seq gauge
jetstream_stream_first_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP jetstream_stream_last_seq Last sequence from a stream
# TYPE jetstream_stream_last_seq gauge
jetstream_stream_last_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 30
# HELP jetstream_stream_limit_bytes The maximum configured storage limit (in bytes) for a JetStream stream. A value of -1 indicates no limit.
# TYPE jetstream_stream_limit_bytes gauge
jetstream_stream_limit_bytes{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} -1
# HELP jetstream_stream_limit_messages The maximum number of messages allowed in a JetStream stream as per its configuration. A value of -1 indicates no limit.
# TYPE jetstream_stream_limit_messages gauge
jetstream_stream_limit_messages{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} -1
# HELP jetstream_stream_subject_count Total number of subjects in a stream
# TYPE jetstream_stream_subject_count gauge
jetstream_stream_subject_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP jetstream_stream_total_bytes Total stored bytes from a stream
# TYPE jetstream_stream_total_bytes gauge
jetstream_stream_total_bytes{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1431
# HELP jetstream_stream_total_messages Total number of messages from a stream
# TYPE jetstream_stream_total_messages gauge
jetstream_stream_total_messages{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 30

[http 200]
```


## Run B · the same with `-prefix nats`

```
$ prometheus-nats-exporter -prefix nats -varz -connz -routez -subz -healthz -healthz_js_enabled_only -healthz_js_server_only -gatewayz -leafz -accountz -accstatz -jsz=all -port 7777 http://127.0.0.1:8291
```

Exporter log (first lines):

```
[18144] 2026/09/03 04:41:51.301699 [INF] Prometheus exporter listening at http://0.0.0.0:7777/metrics
```

Scrape of `http://127.0.0.1:7777/metrics` — 167 `# HELP` lines kept, 38 `go_*`/`process_*`/`promhttp_*` series (122 lines) dropped:

```
# HELP nats_account_max_memory JetStream Account Max Memory in bytes
# TYPE nats_account_max_memory gauge
nats_account_max_memory{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1.8446744073709552e+19
# HELP nats_account_max_storage JetStream Account Max Storage in bytes
# TYPE nats_account_max_storage gauge
nats_account_max_storage{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1.8446744073709552e+19
# HELP nats_account_memory_used Total number of bytes used by JetStream memory
# TYPE nats_account_memory_used gauge
nats_account_memory_used{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 0
# HELP nats_account_storage_used Total number of bytes used by JetStream storage
# TYPE nats_account_storage_used gauge
nats_account_storage_used{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 9006
# HELP nats_accountz_client_connections client_connections
# TYPE nats_accountz_client_connections gauge
nats_accountz_client_connections{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accountz_client_connections{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_accountz_complete complete
# TYPE nats_accountz_complete gauge
nats_accountz_complete{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 1
nats_accountz_complete{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 1
# HELP nats_accountz_expired expired
# TYPE nats_accountz_expired gauge
nats_accountz_expired{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accountz_expired{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_accountz_is_system is_system
# TYPE nats_accountz_is_system gauge
nats_accountz_is_system{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accountz_is_system{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 1
# HELP nats_accountz_jetstream_enabled jetstream_enabled
# TYPE nats_accountz_jetstream_enabled gauge
nats_accountz_jetstream_enabled{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 1
nats_accountz_jetstream_enabled{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_accountz_leafnode_connections leafnode_connections
# TYPE nats_accountz_leafnode_connections gauge
nats_accountz_leafnode_connections{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accountz_leafnode_connections{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_accountz_limit_conn limit_conn
# TYPE nats_accountz_limit_conn gauge
nats_accountz_limit_conn{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accountz_limit_conn{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_accountz_limit_data limit_data
# TYPE nats_accountz_limit_data gauge
nats_accountz_limit_data{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accountz_limit_data{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_accountz_limit_exports limit_exports
# TYPE nats_accountz_limit_exports gauge
nats_accountz_limit_exports{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accountz_limit_exports{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_accountz_limit_imports limit_imports
# TYPE nats_accountz_limit_imports gauge
nats_accountz_limit_imports{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accountz_limit_imports{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_accountz_limit_leaf limit_leaf
# TYPE nats_accountz_limit_leaf gauge
nats_accountz_limit_leaf{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accountz_limit_leaf{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_accountz_limit_payload limit_payload
# TYPE nats_accountz_limit_payload gauge
nats_accountz_limit_payload{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accountz_limit_payload{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_accountz_limit_subs limit_subs
# TYPE nats_accountz_limit_subs gauge
nats_accountz_limit_subs{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accountz_limit_subs{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_accountz_limit_wildcards limit_wildcards
# TYPE nats_accountz_limit_wildcards gauge
nats_accountz_limit_wildcards{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accountz_limit_wildcards{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_accountz_subscriptions subscriptions
# TYPE nats_accountz_subscriptions gauge
nats_accountz_subscriptions{account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 30
nats_accountz_subscriptions{account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 228
# HELP nats_accstatz_current_connections current_connections
# TYPE nats_accstatz_current_connections gauge
nats_accstatz_current_connections{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accstatz_current_connections{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_accstatz_leaf_nodes leaf_nodes
# TYPE nats_accstatz_leaf_nodes gauge
nats_accstatz_leaf_nodes{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accstatz_leaf_nodes{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_accstatz_received_bytes received_bytes
# TYPE nats_accstatz_received_bytes gauge
nats_accstatz_received_bytes{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 2469
nats_accstatz_received_bytes{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 182640
# HELP nats_accstatz_received_messages received_messages
# TYPE nats_accstatz_received_messages gauge
nats_accstatz_received_messages{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 83
nats_accstatz_received_messages{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 884
# HELP nats_accstatz_sent_bytes sent_bytes
# TYPE nats_accstatz_sent_bytes gauge
nats_accstatz_sent_bytes{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 11777
nats_accstatz_sent_bytes{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 93705
# HELP nats_accstatz_sent_messages sent_messages
# TYPE nats_accstatz_sent_messages gauge
nats_accstatz_sent_messages{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 83
nats_accstatz_sent_messages{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 454
# HELP nats_accstatz_slow_consumers slow_consumers
# TYPE nats_accstatz_slow_consumers gauge
nats_accstatz_slow_consumers{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accstatz_slow_consumers{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_accstatz_subscriptions subscriptions
# TYPE nats_accstatz_subscriptions gauge
nats_accstatz_subscriptions{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 30
nats_accstatz_subscriptions{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 228
# HELP nats_accstatz_total_connections total_connections
# TYPE nats_accstatz_total_connections gauge
nats_accstatz_total_connections{account="$G",account_id="$G",account_name="$G",server_id="http://127.0.0.1:8291"} 0
nats_accstatz_total_connections{account="$SYS",account_id="$SYS",account_name="$SYS",server_id="http://127.0.0.1:8291"} 0
# HELP nats_connz_in_bytes in_bytes
# TYPE nats_connz_in_bytes counter
nats_connz_in_bytes{server_id="http://127.0.0.1:8291"} 0
# HELP nats_connz_in_msgs in_msgs
# TYPE nats_connz_in_msgs counter
nats_connz_in_msgs{server_id="http://127.0.0.1:8291"} 0
# HELP nats_connz_limit limit
# TYPE nats_connz_limit gauge
nats_connz_limit{server_id="http://127.0.0.1:8291"} 1024
# HELP nats_connz_num_connections num_connections
# TYPE nats_connz_num_connections gauge
nats_connz_num_connections{server_id="http://127.0.0.1:8291"} 0
# HELP nats_connz_offset offset
# TYPE nats_connz_offset gauge
nats_connz_offset{server_id="http://127.0.0.1:8291"} 0
# HELP nats_connz_out_bytes out_bytes
# TYPE nats_connz_out_bytes counter
nats_connz_out_bytes{server_id="http://127.0.0.1:8291"} 0
# HELP nats_connz_out_msgs out_msgs
# TYPE nats_connz_out_msgs counter
nats_connz_out_msgs{server_id="http://127.0.0.1:8291"} 0
# HELP nats_connz_pending_bytes pending_bytes
# TYPE nats_connz_pending_bytes gauge
nats_connz_pending_bytes{server_id="http://127.0.0.1:8291"} 0
# HELP nats_connz_subscriptions subscriptions
# TYPE nats_connz_subscriptions gauge
nats_connz_subscriptions{server_id="http://127.0.0.1:8291"} 0
# HELP nats_connz_total total
# TYPE nats_connz_total gauge
nats_connz_total{server_id="http://127.0.0.1:8291"} 0
# HELP nats_consumer_ack_floor_consumer_seq Number of ack floor consumer seq from a consumer
# TYPE nats_consumer_ack_floor_consumer_seq gauge
nats_consumer_ack_floor_consumer_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0
# HELP nats_consumer_ack_floor_stream_seq Number of ack floor stream seq from a consumer
# TYPE nats_consumer_ack_floor_stream_seq gauge
nats_consumer_ack_floor_stream_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0
# HELP nats_consumer_delivered_consumer_seq Latest sequence number of a stream consumer
# TYPE nats_consumer_delivered_consumer_seq gauge
nats_consumer_delivered_consumer_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 20
# HELP nats_consumer_delivered_stream_seq Latest sequence number of a stream
# TYPE nats_consumer_delivered_stream_seq gauge
nats_consumer_delivered_stream_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 10
# HELP nats_consumer_last_delivery_seconds Seconds since last message delivery to consumer
# TYPE nats_consumer_last_delivery_seconds gauge
nats_consumer_last_delivery_seconds{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 2.180119
# HELP nats_consumer_num_ack_pending Number of pending acks from a consumer
# TYPE nats_consumer_num_ack_pending gauge
nats_consumer_num_ack_pending{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 10
# HELP nats_consumer_num_pending Number of pending messages from a consumer
# TYPE nats_consumer_num_pending gauge
nats_consumer_num_pending{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0
# HELP nats_consumer_num_redelivered Number of redelivered messages from a consumer
# TYPE nats_consumer_num_redelivered gauge
nats_consumer_num_redelivered{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 10
# HELP nats_consumer_num_waiting Number of inflight fetch requests from a pull consumer
# TYPE nats_consumer_num_waiting gauge
nats_consumer_num_waiting{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0
# HELP nats_healthz_js_enabled_only_status status
# TYPE nats_healthz_js_enabled_only_status gauge
nats_healthz_js_enabled_only_status{server_id="http://127.0.0.1:8291"} 0
# HELP nats_healthz_js_enabled_only_status_value status
# TYPE nats_healthz_js_enabled_only_status_value gauge
nats_healthz_js_enabled_only_status_value{server_id="http://127.0.0.1:8291",value="ok"} 1
# HELP nats_healthz_js_server_only_status status
# TYPE nats_healthz_js_server_only_status gauge
nats_healthz_js_server_only_status{server_id="http://127.0.0.1:8291"} 0
# HELP nats_healthz_js_server_only_status_value status
# TYPE nats_healthz_js_server_only_status_value gauge
nats_healthz_js_server_only_status_value{server_id="http://127.0.0.1:8291",value="ok"} 1
# HELP nats_healthz_status status
# TYPE nats_healthz_status gauge
nats_healthz_status{server_id="http://127.0.0.1:8291"} 0
# HELP nats_healthz_status_value status
# TYPE nats_healthz_status_value gauge
nats_healthz_status_value{server_id="http://127.0.0.1:8291",value="ok"} 1
# HELP nats_leafz_conn_nodes_total nodes_total
# TYPE nats_leafz_conn_nodes_total gauge
nats_leafz_conn_nodes_total{server_id="http://127.0.0.1:8291"} 0
# HELP nats_routez_num_routes num_routes
# TYPE nats_routez_num_routes gauge
nats_routez_num_routes{server_id="http://127.0.0.1:8291"} 8
# HELP nats_routez_server_id server_id
# TYPE nats_routez_server_id gauge
nats_routez_server_id{server_id="http://127.0.0.1:8291",value="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S"} 1
# HELP nats_routez_server_name server_name
# TYPE nats_routez_server_name gauge
nats_routez_server_name{server_id="http://127.0.0.1:8291",value="n1"} 1
# HELP nats_server_jetstream_disabled JetStream disabled or not
# TYPE nats_server_jetstream_disabled gauge
nats_server_jetstream_disabled{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 0
# HELP nats_server_max_memory JetStream Max Memory
# TYPE nats_server_max_memory gauge
nats_server_max_memory{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 2.5769803776e+10
# HELP nats_server_max_storage JetStream Max Storage
# TYPE nats_server_max_storage gauge
nats_server_max_storage{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 7.424265216e+10
# HELP nats_server_total_consumers Total number of consumers in JetStream
# TYPE nats_server_total_consumers gauge
nats_server_total_consumers{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1
# HELP nats_server_total_message_bytes Total number of bytes stored in JetStream
# TYPE nats_server_total_message_bytes gauge
nats_server_total_message_bytes{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1431
# HELP nats_server_total_messages Total number of stored messages in JetStream
# TYPE nats_server_total_messages gauge
nats_server_total_messages{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 30
# HELP nats_server_total_streams Total number of streams in JetStream
# TYPE nats_server_total_streams gauge
nats_server_total_streams{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1
# HELP nats_stream_consumer_count Total number of consumers from a stream
# TYPE nats_stream_consumer_count gauge
nats_stream_consumer_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP nats_stream_first_seq First sequence from a stream
# TYPE nats_stream_first_seq gauge
nats_stream_first_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP nats_stream_last_seq Last sequence from a stream
# TYPE nats_stream_last_seq gauge
nats_stream_last_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 30
# HELP nats_stream_limit_bytes The maximum configured storage limit (in bytes) for a JetStream stream. A value of -1 indicates no limit.
# TYPE nats_stream_limit_bytes gauge
nats_stream_limit_bytes{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} -1
# HELP nats_stream_limit_messages The maximum number of messages allowed in a JetStream stream as per its configuration. A value of -1 indicates no limit.
# TYPE nats_stream_limit_messages gauge
nats_stream_limit_messages{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} -1
# HELP nats_stream_subject_count Total number of subjects in a stream
# TYPE nats_stream_subject_count gauge
nats_stream_subject_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP nats_stream_total_bytes Total stored bytes from a stream
# TYPE nats_stream_total_bytes gauge
nats_stream_total_bytes{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1431
# HELP nats_stream_total_messages Total number of messages from a stream
# TYPE nats_stream_total_messages gauge
nats_stream_total_messages{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 30
# HELP nats_subsz_avg_fanout avg_fanout
# TYPE nats_subsz_avg_fanout gauge
nats_subsz_avg_fanout{server_id="http://127.0.0.1:8291"} 1.9574468085106382
# HELP nats_subsz_cache_hit_rate cache_hit_rate
# TYPE nats_subsz_cache_hit_rate gauge
nats_subsz_cache_hit_rate{server_id="http://127.0.0.1:8291"} 0.5497630331753555
# HELP nats_subsz_limit limit
# TYPE nats_subsz_limit gauge
nats_subsz_limit{server_id="http://127.0.0.1:8291"} 1024
# HELP nats_subsz_max_fanout max_fanout
# TYPE nats_subsz_max_fanout gauge
nats_subsz_max_fanout{server_id="http://127.0.0.1:8291"} 3
# HELP nats_subsz_num_cache num_cache
# TYPE nats_subsz_num_cache gauge
nats_subsz_num_cache{server_id="http://127.0.0.1:8291"} 47
# HELP nats_subsz_num_inserts num_inserts
# TYPE nats_subsz_num_inserts gauge
nats_subsz_num_inserts{server_id="http://127.0.0.1:8291"} 289
# HELP nats_subsz_num_matches num_matches
# TYPE nats_subsz_num_matches gauge
nats_subsz_num_matches{server_id="http://127.0.0.1:8291"} 211
# HELP nats_subsz_num_removes num_removes
# TYPE nats_subsz_num_removes gauge
nats_subsz_num_removes{server_id="http://127.0.0.1:8291"} 31
# HELP nats_subsz_num_subscriptions num_subscriptions
# TYPE nats_subsz_num_subscriptions gauge
nats_subsz_num_subscriptions{server_id="http://127.0.0.1:8291"} 258
# HELP nats_subsz_offset offset
# TYPE nats_subsz_offset gauge
nats_subsz_offset{server_id="http://127.0.0.1:8291"} 0
# HELP nats_subsz_server_id server_id
# TYPE nats_subsz_server_id gauge
nats_subsz_server_id{server_id="http://127.0.0.1:8291",value="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S"} 1
# HELP nats_subsz_total total
# TYPE nats_subsz_total gauge
nats_subsz_total{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_auth_timeout auth_timeout
# TYPE nats_varz_auth_timeout gauge
nats_varz_auth_timeout{server_id="http://127.0.0.1:8291"} 2
# HELP nats_varz_cluster_name cluster_name
# TYPE nats_varz_cluster_name gauge
nats_varz_cluster_name{server_id="http://127.0.0.1:8291",value="east"} 1
# HELP nats_varz_cluster_pool_size cluster_pool_size
# TYPE nats_varz_cluster_pool_size gauge
nats_varz_cluster_pool_size{server_id="http://127.0.0.1:8291"} 3
# HELP nats_varz_config_load_time config_load_time
# TYPE nats_varz_config_load_time gauge
nats_varz_config_load_time{server_id="http://127.0.0.1:8291"} 1.788403202188e+12
# HELP nats_varz_connections connections
# TYPE nats_varz_connections gauge
nats_varz_connections{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_cores cores
# TYPE nats_varz_cores gauge
nats_varz_cores{server_id="http://127.0.0.1:8291"} 10
# HELP nats_varz_cpu cpu
# TYPE nats_varz_cpu gauge
nats_varz_cpu{server_id="http://127.0.0.1:8291"} 0.5
# HELP nats_varz_disk_io_wait_stats_max_wait_time disk_io_wait_stats_max_wait_time
# TYPE nats_varz_disk_io_wait_stats_max_wait_time gauge
nats_varz_disk_io_wait_stats_max_wait_time{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_disk_io_wait_stats_wait_time disk_io_wait_stats_wait_time
# TYPE nats_varz_disk_io_wait_stats_wait_time gauge
nats_varz_disk_io_wait_stats_wait_time{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_disk_io_wait_stats_waiters disk_io_wait_stats_waiters
# TYPE nats_varz_disk_io_wait_stats_waiters gauge
nats_varz_disk_io_wait_stats_waiters{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_disk_io_wait_stats_waits disk_io_wait_stats_waits
# TYPE nats_varz_disk_io_wait_stats_waits gauge
nats_varz_disk_io_wait_stats_waits{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_gomaxprocs gomaxprocs
# TYPE nats_varz_gomaxprocs gauge
nats_varz_gomaxprocs{server_id="http://127.0.0.1:8291"} 10
# HELP nats_varz_http_port http_port
# TYPE nats_varz_http_port gauge
nats_varz_http_port{server_id="http://127.0.0.1:8291"} 8291
# HELP nats_varz_http_req_stats_accountz http_req_stats_accountz
# TYPE nats_varz_http_req_stats_accountz gauge
nats_varz_http_req_stats_accountz{server_id="http://127.0.0.1:8291"} 9
# HELP nats_varz_http_req_stats_accstatz http_req_stats_accstatz
# TYPE nats_varz_http_req_stats_accstatz gauge
nats_varz_http_req_stats_accstatz{server_id="http://127.0.0.1:8291"} 4
# HELP nats_varz_http_req_stats_connz http_req_stats_connz
# TYPE nats_varz_http_req_stats_connz gauge
nats_varz_http_req_stats_connz{server_id="http://127.0.0.1:8291"} 4
# HELP nats_varz_http_req_stats_gatewayz http_req_stats_gatewayz
# TYPE nats_varz_http_req_stats_gatewayz gauge
nats_varz_http_req_stats_gatewayz{server_id="http://127.0.0.1:8291"} 3
# HELP nats_varz_http_req_stats_healthz http_req_stats_healthz
# TYPE nats_varz_http_req_stats_healthz gauge
nats_varz_http_req_stats_healthz{server_id="http://127.0.0.1:8291"} 10
# HELP nats_varz_http_req_stats_jsz http_req_stats_jsz
# TYPE nats_varz_http_req_stats_jsz gauge
nats_varz_http_req_stats_jsz{server_id="http://127.0.0.1:8291"} 7
# HELP nats_varz_http_req_stats_leafz http_req_stats_leafz
# TYPE nats_varz_http_req_stats_leafz gauge
nats_varz_http_req_stats_leafz{server_id="http://127.0.0.1:8291"} 3
# HELP nats_varz_http_req_stats_routez http_req_stats_routez
# TYPE nats_varz_http_req_stats_routez gauge
nats_varz_http_req_stats_routez{server_id="http://127.0.0.1:8291"} 6
# HELP nats_varz_http_req_stats_subsz http_req_stats_subsz
# TYPE nats_varz_http_req_stats_subsz gauge
nats_varz_http_req_stats_subsz{server_id="http://127.0.0.1:8291"} 6
# HELP nats_varz_http_req_stats_varz http_req_stats_varz
# TYPE nats_varz_http_req_stats_varz gauge
nats_varz_http_req_stats_varz{server_id="http://127.0.0.1:8291"} 10
# HELP nats_varz_https_port https_port
# TYPE nats_varz_https_port gauge
nats_varz_https_port{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_in_bytes in_bytes
# TYPE nats_varz_in_bytes gauge
nats_varz_in_bytes{server_id="http://127.0.0.1:8291"} 93789
# HELP nats_varz_in_client_bytes in_client_bytes
# TYPE nats_varz_in_client_bytes gauge
nats_varz_in_client_bytes{server_id="http://127.0.0.1:8291"} 2327
# HELP nats_varz_in_client_msgs in_client_msgs
# TYPE nats_varz_in_client_msgs gauge
nats_varz_in_client_msgs{server_id="http://127.0.0.1:8291"} 63
# HELP nats_varz_in_msgs in_msgs
# TYPE nats_varz_in_msgs gauge
nats_varz_in_msgs{server_id="http://127.0.0.1:8291"} 525
# HELP nats_varz_jetstream_config_max_memory jetstream_config_max_memory
# TYPE nats_varz_jetstream_config_max_memory gauge
nats_varz_jetstream_config_max_memory{server_id="http://127.0.0.1:8291"} 2.5769803776e+10
# HELP nats_varz_jetstream_config_max_storage jetstream_config_max_storage
# TYPE nats_varz_jetstream_config_max_storage gauge
nats_varz_jetstream_config_max_storage{server_id="http://127.0.0.1:8291"} 7.424265216e+10
# HELP nats_varz_jetstream_config_sync_interval jetstream_config_sync_interval
# TYPE nats_varz_jetstream_config_sync_interval gauge
nats_varz_jetstream_config_sync_interval{server_id="http://127.0.0.1:8291"} 1.2e+11
# HELP nats_varz_jetstream_meta_cluster_size jetstream_meta_cluster_size
# TYPE nats_varz_jetstream_meta_cluster_size gauge
nats_varz_jetstream_meta_cluster_size{server_id="http://127.0.0.1:8291"} 3
# HELP nats_varz_jetstream_meta_leader jetstream_meta_leader
# TYPE nats_varz_jetstream_meta_leader gauge
nats_varz_jetstream_meta_leader{server_id="http://127.0.0.1:8291",value="n1"} 1
# HELP nats_varz_jetstream_meta_name jetstream_meta_name
# TYPE nats_varz_jetstream_meta_name gauge
nats_varz_jetstream_meta_name{server_id="http://127.0.0.1:8291",value="east"} 1
# HELP nats_varz_jetstream_meta_pending jetstream_meta_pending
# TYPE nats_varz_jetstream_meta_pending gauge
nats_varz_jetstream_meta_pending{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_jetstream_meta_pending_infos jetstream_meta_pending_infos
# TYPE nats_varz_jetstream_meta_pending_infos gauge
nats_varz_jetstream_meta_pending_infos{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_jetstream_meta_pending_requests jetstream_meta_pending_requests
# TYPE nats_varz_jetstream_meta_pending_requests gauge
nats_varz_jetstream_meta_pending_requests{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_jetstream_meta_snapshot_pending_entries jetstream_meta_snapshot_pending_entries
# TYPE nats_varz_jetstream_meta_snapshot_pending_entries gauge
nats_varz_jetstream_meta_snapshot_pending_entries{server_id="http://127.0.0.1:8291"} 4
# HELP nats_varz_jetstream_meta_snapshot_pending_size jetstream_meta_snapshot_pending_size
# TYPE nats_varz_jetstream_meta_snapshot_pending_size gauge
nats_varz_jetstream_meta_snapshot_pending_size{server_id="http://127.0.0.1:8291"} 4180
# HELP nats_varz_jetstream_stats_accounts jetstream_stats_accounts
# TYPE nats_varz_jetstream_stats_accounts gauge
nats_varz_jetstream_stats_accounts{server_id="http://127.0.0.1:8291"} 1
# HELP nats_varz_jetstream_stats_api_errors jetstream_stats_api_errors
# TYPE nats_varz_jetstream_stats_api_errors gauge
nats_varz_jetstream_stats_api_errors{server_id="http://127.0.0.1:8291"} 1
# HELP nats_varz_jetstream_stats_api_level jetstream_stats_api_level
# TYPE nats_varz_jetstream_stats_api_level gauge
nats_varz_jetstream_stats_api_level{server_id="http://127.0.0.1:8291"} 4
# HELP nats_varz_jetstream_stats_api_total jetstream_stats_api_total
# TYPE nats_varz_jetstream_stats_api_total gauge
nats_varz_jetstream_stats_api_total{server_id="http://127.0.0.1:8291"} 4
# HELP nats_varz_jetstream_stats_ha_assets jetstream_stats_ha_assets
# TYPE nats_varz_jetstream_stats_ha_assets gauge
nats_varz_jetstream_stats_ha_assets{server_id="http://127.0.0.1:8291"} 3
# HELP nats_varz_jetstream_stats_memory jetstream_stats_memory
# TYPE nats_varz_jetstream_stats_memory gauge
nats_varz_jetstream_stats_memory{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_jetstream_stats_reserved_memory jetstream_stats_reserved_memory
# TYPE nats_varz_jetstream_stats_reserved_memory gauge
nats_varz_jetstream_stats_reserved_memory{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_jetstream_stats_reserved_storage jetstream_stats_reserved_storage
# TYPE nats_varz_jetstream_stats_reserved_storage gauge
nats_varz_jetstream_stats_reserved_storage{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_jetstream_stats_storage jetstream_stats_storage
# TYPE nats_varz_jetstream_stats_storage gauge
nats_varz_jetstream_stats_storage{server_id="http://127.0.0.1:8291"} 1431
# HELP nats_varz_leafnodes leafnodes
# TYPE nats_varz_leafnodes gauge
nats_varz_leafnodes{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_max_connections max_connections
# TYPE nats_varz_max_connections gauge
nats_varz_max_connections{server_id="http://127.0.0.1:8291"} 65536
# HELP nats_varz_max_control_line max_control_line
# TYPE nats_varz_max_control_line gauge
nats_varz_max_control_line{server_id="http://127.0.0.1:8291"} 4096
# HELP nats_varz_max_payload max_payload
# TYPE nats_varz_max_payload gauge
nats_varz_max_payload{server_id="http://127.0.0.1:8291"} 1.048576e+06
# HELP nats_varz_max_pending max_pending
# TYPE nats_varz_max_pending gauge
nats_varz_max_pending{server_id="http://127.0.0.1:8291"} 6.7108864e+07
# HELP nats_varz_mem mem
# TYPE nats_varz_mem gauge
nats_varz_mem{server_id="http://127.0.0.1:8291"} 2.9294592e+07
# HELP nats_varz_out_bytes out_bytes
# TYPE nats_varz_out_bytes gauge
nats_varz_out_bytes{server_id="http://127.0.0.1:8291"} 105482
# HELP nats_varz_out_client_bytes out_client_bytes
# TYPE nats_varz_out_client_bytes gauge
nats_varz_out_client_bytes{server_id="http://127.0.0.1:8291"} 10906
# HELP nats_varz_out_client_msgs out_client_msgs
# TYPE nats_varz_out_client_msgs gauge
nats_varz_out_client_msgs{server_id="http://127.0.0.1:8291"} 33
# HELP nats_varz_out_msgs out_msgs
# TYPE nats_varz_out_msgs gauge
nats_varz_out_msgs{server_id="http://127.0.0.1:8291"} 537
# HELP nats_varz_ping_interval ping_interval
# TYPE nats_varz_ping_interval gauge
nats_varz_ping_interval{server_id="http://127.0.0.1:8291"} 1.2e+11
# HELP nats_varz_ping_max ping_max
# TYPE nats_varz_ping_max gauge
nats_varz_ping_max{server_id="http://127.0.0.1:8291"} 2
# HELP nats_varz_port port
# TYPE nats_varz_port gauge
nats_varz_port{server_id="http://127.0.0.1:8291"} 4291
# HELP nats_varz_proto proto
# TYPE nats_varz_proto gauge
nats_varz_proto{server_id="http://127.0.0.1:8291"} 1
# HELP nats_varz_remotes remotes
# TYPE nats_varz_remotes gauge
nats_varz_remotes{server_id="http://127.0.0.1:8291"} 2
# HELP nats_varz_routes routes
# TYPE nats_varz_routes gauge
nats_varz_routes{server_id="http://127.0.0.1:8291"} 8
# HELP nats_varz_server_id server_id
# TYPE nats_varz_server_id gauge
nats_varz_server_id{server_id="http://127.0.0.1:8291",value="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S"} 1
# HELP nats_varz_server_name server_name
# TYPE nats_varz_server_name gauge
nats_varz_server_name{server_id="http://127.0.0.1:8291",value="n1"} 1
# HELP nats_varz_slow_consumer_stats_clients slow_consumer_stats_clients
# TYPE nats_varz_slow_consumer_stats_clients gauge
nats_varz_slow_consumer_stats_clients{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_slow_consumer_stats_gateways slow_consumer_stats_gateways
# TYPE nats_varz_slow_consumer_stats_gateways gauge
nats_varz_slow_consumer_stats_gateways{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_slow_consumer_stats_leafs slow_consumer_stats_leafs
# TYPE nats_varz_slow_consumer_stats_leafs gauge
nats_varz_slow_consumer_stats_leafs{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_slow_consumer_stats_routes slow_consumer_stats_routes
# TYPE nats_varz_slow_consumer_stats_routes gauge
nats_varz_slow_consumer_stats_routes{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_slow_consumers slow_consumers
# TYPE nats_varz_slow_consumers gauge
nats_varz_slow_consumers{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_stale_connection_stats_clients stale_connection_stats_clients
# TYPE nats_varz_stale_connection_stats_clients gauge
nats_varz_stale_connection_stats_clients{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_stale_connection_stats_gateways stale_connection_stats_gateways
# TYPE nats_varz_stale_connection_stats_gateways gauge
nats_varz_stale_connection_stats_gateways{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_stale_connection_stats_leafs stale_connection_stats_leafs
# TYPE nats_varz_stale_connection_stats_leafs gauge
nats_varz_stale_connection_stats_leafs{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_stale_connection_stats_routes stale_connection_stats_routes
# TYPE nats_varz_stale_connection_stats_routes gauge
nats_varz_stale_connection_stats_routes{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_stale_connections stale_connections
# TYPE nats_varz_stale_connections gauge
nats_varz_stale_connections{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_stalled_clients stalled_clients
# TYPE nats_varz_stalled_clients gauge
nats_varz_stalled_clients{server_id="http://127.0.0.1:8291"} 0
# HELP nats_varz_start start
# TYPE nats_varz_start gauge
nats_varz_start{server_id="http://127.0.0.1:8291"} 1.788403202188e+12
# HELP nats_varz_subscriptions subscriptions
# TYPE nats_varz_subscriptions gauge
nats_varz_subscriptions{server_id="http://127.0.0.1:8291"} 258
# HELP nats_varz_tls_timeout tls_timeout
# TYPE nats_varz_tls_timeout gauge
nats_varz_tls_timeout{server_id="http://127.0.0.1:8291"} 2
# HELP nats_varz_total_connections total_connections
# TYPE nats_varz_total_connections gauge
nats_varz_total_connections{server_id="http://127.0.0.1:8291"} 9
# HELP nats_varz_version version
# TYPE nats_varz_version gauge
nats_varz_version{server_id="http://127.0.0.1:8291",value="2.14.6"} 1
# HELP nats_varz_write_deadline write_deadline
# TYPE nats_varz_write_deadline gauge
nats_varz_write_deadline{server_id="http://127.0.0.1:8291"} 1e+10

[http 200]
```


## Run C · `-connz_detailed` alone, no client connected at the time

```
$ prometheus-nats-exporter -connz_detailed -port 7777 http://127.0.0.1:8291
```

Exporter log (first lines):

```
[18152] 2026/09/03 04:41:51.324582 [INF] Prometheus exporter listening at http://0.0.0.0:7777/metrics
```

Scrape of `http://127.0.0.1:7777/metrics` — 10 `# HELP` lines kept, 38 `go_*`/`process_*`/`promhttp_*` series (122 lines) dropped:

```
# HELP gnatsd_connz_in_bytes in_bytes
# TYPE gnatsd_connz_in_bytes counter
gnatsd_connz_in_bytes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_in_msgs in_msgs
# TYPE gnatsd_connz_in_msgs counter
gnatsd_connz_in_msgs{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_limit limit
# TYPE gnatsd_connz_limit gauge
gnatsd_connz_limit{server_id="http://127.0.0.1:8291"} 1024
# HELP gnatsd_connz_num_connections num_connections
# TYPE gnatsd_connz_num_connections gauge
gnatsd_connz_num_connections{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_offset offset
# TYPE gnatsd_connz_offset gauge
gnatsd_connz_offset{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_out_bytes out_bytes
# TYPE gnatsd_connz_out_bytes counter
gnatsd_connz_out_bytes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_out_msgs out_msgs
# TYPE gnatsd_connz_out_msgs counter
gnatsd_connz_out_msgs{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_pending_bytes pending_bytes
# TYPE gnatsd_connz_pending_bytes gauge
gnatsd_connz_pending_bytes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_subscriptions subscriptions
# TYPE gnatsd_connz_subscriptions gauge
gnatsd_connz_subscriptions{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_total total
# TYPE gnatsd_connz_total gauge
gnatsd_connz_total{server_id="http://127.0.0.1:8291"} 0

[http 200]
```


## Run D · `-jsz=streams` alone

```
$ prometheus-nats-exporter -jsz=streams -port 7777 http://127.0.0.1:8291
```

Exporter log (first lines):

```
No metrics specified.  Defaulting to varz.
[18160] 2026/09/03 04:41:51.344718 [INF] Prometheus exporter listening at http://0.0.0.0:7777/metrics
```

Scrape of `http://127.0.0.1:7777/metrics` — 100 `# HELP` lines kept, 38 `go_*`/`process_*`/`promhttp_*` series (122 lines) dropped:

```
# HELP gnatsd_varz_auth_timeout auth_timeout
# TYPE gnatsd_varz_auth_timeout gauge
gnatsd_varz_auth_timeout{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_cluster_name cluster_name
# TYPE gnatsd_varz_cluster_name gauge
gnatsd_varz_cluster_name{server_id="http://127.0.0.1:8291",value="east"} 1
# HELP gnatsd_varz_cluster_pool_size cluster_pool_size
# TYPE gnatsd_varz_cluster_pool_size gauge
gnatsd_varz_cluster_pool_size{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_varz_config_load_time config_load_time
# TYPE gnatsd_varz_config_load_time gauge
gnatsd_varz_config_load_time{server_id="http://127.0.0.1:8291"} 1.788403202188e+12
# HELP gnatsd_varz_connections connections
# TYPE gnatsd_varz_connections gauge
gnatsd_varz_connections{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_cores cores
# TYPE gnatsd_varz_cores gauge
gnatsd_varz_cores{server_id="http://127.0.0.1:8291"} 10
# HELP gnatsd_varz_cpu cpu
# TYPE gnatsd_varz_cpu gauge
gnatsd_varz_cpu{server_id="http://127.0.0.1:8291"} 0.5
# HELP gnatsd_varz_disk_io_wait_stats_max_wait_time disk_io_wait_stats_max_wait_time
# TYPE gnatsd_varz_disk_io_wait_stats_max_wait_time gauge
gnatsd_varz_disk_io_wait_stats_max_wait_time{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_disk_io_wait_stats_wait_time disk_io_wait_stats_wait_time
# TYPE gnatsd_varz_disk_io_wait_stats_wait_time gauge
gnatsd_varz_disk_io_wait_stats_wait_time{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_disk_io_wait_stats_waiters disk_io_wait_stats_waiters
# TYPE gnatsd_varz_disk_io_wait_stats_waiters gauge
gnatsd_varz_disk_io_wait_stats_waiters{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_disk_io_wait_stats_waits disk_io_wait_stats_waits
# TYPE gnatsd_varz_disk_io_wait_stats_waits gauge
gnatsd_varz_disk_io_wait_stats_waits{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_gomaxprocs gomaxprocs
# TYPE gnatsd_varz_gomaxprocs gauge
gnatsd_varz_gomaxprocs{server_id="http://127.0.0.1:8291"} 10
# HELP gnatsd_varz_http_port http_port
# TYPE gnatsd_varz_http_port gauge
gnatsd_varz_http_port{server_id="http://127.0.0.1:8291"} 8291
# HELP gnatsd_varz_http_req_stats_accountz http_req_stats_accountz
# TYPE gnatsd_varz_http_req_stats_accountz gauge
gnatsd_varz_http_req_stats_accountz{server_id="http://127.0.0.1:8291"} 12
# HELP gnatsd_varz_http_req_stats_accstatz http_req_stats_accstatz
# TYPE gnatsd_varz_http_req_stats_accstatz gauge
gnatsd_varz_http_req_stats_accstatz{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_http_req_stats_connz http_req_stats_connz
# TYPE gnatsd_varz_http_req_stats_connz gauge
gnatsd_varz_http_req_stats_connz{server_id="http://127.0.0.1:8291"} 7
# HELP gnatsd_varz_http_req_stats_gatewayz http_req_stats_gatewayz
# TYPE gnatsd_varz_http_req_stats_gatewayz gauge
gnatsd_varz_http_req_stats_gatewayz{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_http_req_stats_healthz http_req_stats_healthz
# TYPE gnatsd_varz_http_req_stats_healthz gauge
gnatsd_varz_http_req_stats_healthz{server_id="http://127.0.0.1:8291"} 13
# HELP gnatsd_varz_http_req_stats_jsz http_req_stats_jsz
# TYPE gnatsd_varz_http_req_stats_jsz gauge
gnatsd_varz_http_req_stats_jsz{server_id="http://127.0.0.1:8291"} 8
# HELP gnatsd_varz_http_req_stats_leafz http_req_stats_leafz
# TYPE gnatsd_varz_http_req_stats_leafz gauge
gnatsd_varz_http_req_stats_leafz{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_http_req_stats_routez http_req_stats_routez
# TYPE gnatsd_varz_http_req_stats_routez gauge
gnatsd_varz_http_req_stats_routez{server_id="http://127.0.0.1:8291"} 6
# HELP gnatsd_varz_http_req_stats_subsz http_req_stats_subsz
# TYPE gnatsd_varz_http_req_stats_subsz gauge
gnatsd_varz_http_req_stats_subsz{server_id="http://127.0.0.1:8291"} 6
# HELP gnatsd_varz_http_req_stats_varz http_req_stats_varz
# TYPE gnatsd_varz_http_req_stats_varz gauge
gnatsd_varz_http_req_stats_varz{server_id="http://127.0.0.1:8291"} 15
# HELP gnatsd_varz_https_port https_port
# TYPE gnatsd_varz_https_port gauge
gnatsd_varz_https_port{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_in_bytes in_bytes
# TYPE gnatsd_varz_in_bytes gauge
gnatsd_varz_in_bytes{server_id="http://127.0.0.1:8291"} 93789
# HELP gnatsd_varz_in_client_bytes in_client_bytes
# TYPE gnatsd_varz_in_client_bytes gauge
gnatsd_varz_in_client_bytes{server_id="http://127.0.0.1:8291"} 2327
# HELP gnatsd_varz_in_client_msgs in_client_msgs
# TYPE gnatsd_varz_in_client_msgs gauge
gnatsd_varz_in_client_msgs{server_id="http://127.0.0.1:8291"} 63
# HELP gnatsd_varz_in_msgs in_msgs
# TYPE gnatsd_varz_in_msgs gauge
gnatsd_varz_in_msgs{server_id="http://127.0.0.1:8291"} 525
# HELP gnatsd_varz_jetstream_config_max_memory jetstream_config_max_memory
# TYPE gnatsd_varz_jetstream_config_max_memory gauge
gnatsd_varz_jetstream_config_max_memory{server_id="http://127.0.0.1:8291"} 2.5769803776e+10
# HELP gnatsd_varz_jetstream_config_max_storage jetstream_config_max_storage
# TYPE gnatsd_varz_jetstream_config_max_storage gauge
gnatsd_varz_jetstream_config_max_storage{server_id="http://127.0.0.1:8291"} 7.424265216e+10
# HELP gnatsd_varz_jetstream_config_sync_interval jetstream_config_sync_interval
# TYPE gnatsd_varz_jetstream_config_sync_interval gauge
gnatsd_varz_jetstream_config_sync_interval{server_id="http://127.0.0.1:8291"} 1.2e+11
# HELP gnatsd_varz_jetstream_meta_cluster_size jetstream_meta_cluster_size
# TYPE gnatsd_varz_jetstream_meta_cluster_size gauge
gnatsd_varz_jetstream_meta_cluster_size{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_varz_jetstream_meta_leader jetstream_meta_leader
# TYPE gnatsd_varz_jetstream_meta_leader gauge
gnatsd_varz_jetstream_meta_leader{server_id="http://127.0.0.1:8291",value="n1"} 1
# HELP gnatsd_varz_jetstream_meta_name jetstream_meta_name
# TYPE gnatsd_varz_jetstream_meta_name gauge
gnatsd_varz_jetstream_meta_name{server_id="http://127.0.0.1:8291",value="east"} 1
# HELP gnatsd_varz_jetstream_meta_pending jetstream_meta_pending
# TYPE gnatsd_varz_jetstream_meta_pending gauge
gnatsd_varz_jetstream_meta_pending{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_meta_pending_infos jetstream_meta_pending_infos
# TYPE gnatsd_varz_jetstream_meta_pending_infos gauge
gnatsd_varz_jetstream_meta_pending_infos{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_meta_pending_requests jetstream_meta_pending_requests
# TYPE gnatsd_varz_jetstream_meta_pending_requests gauge
gnatsd_varz_jetstream_meta_pending_requests{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_meta_snapshot_pending_entries jetstream_meta_snapshot_pending_entries
# TYPE gnatsd_varz_jetstream_meta_snapshot_pending_entries gauge
gnatsd_varz_jetstream_meta_snapshot_pending_entries{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_jetstream_meta_snapshot_pending_size jetstream_meta_snapshot_pending_size
# TYPE gnatsd_varz_jetstream_meta_snapshot_pending_size gauge
gnatsd_varz_jetstream_meta_snapshot_pending_size{server_id="http://127.0.0.1:8291"} 4180
# HELP gnatsd_varz_jetstream_stats_accounts jetstream_stats_accounts
# TYPE gnatsd_varz_jetstream_stats_accounts gauge
gnatsd_varz_jetstream_stats_accounts{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_varz_jetstream_stats_api_errors jetstream_stats_api_errors
# TYPE gnatsd_varz_jetstream_stats_api_errors gauge
gnatsd_varz_jetstream_stats_api_errors{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_varz_jetstream_stats_api_level jetstream_stats_api_level
# TYPE gnatsd_varz_jetstream_stats_api_level gauge
gnatsd_varz_jetstream_stats_api_level{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_jetstream_stats_api_total jetstream_stats_api_total
# TYPE gnatsd_varz_jetstream_stats_api_total gauge
gnatsd_varz_jetstream_stats_api_total{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_jetstream_stats_ha_assets jetstream_stats_ha_assets
# TYPE gnatsd_varz_jetstream_stats_ha_assets gauge
gnatsd_varz_jetstream_stats_ha_assets{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_varz_jetstream_stats_memory jetstream_stats_memory
# TYPE gnatsd_varz_jetstream_stats_memory gauge
gnatsd_varz_jetstream_stats_memory{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_stats_reserved_memory jetstream_stats_reserved_memory
# TYPE gnatsd_varz_jetstream_stats_reserved_memory gauge
gnatsd_varz_jetstream_stats_reserved_memory{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_stats_reserved_storage jetstream_stats_reserved_storage
# TYPE gnatsd_varz_jetstream_stats_reserved_storage gauge
gnatsd_varz_jetstream_stats_reserved_storage{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_stats_storage jetstream_stats_storage
# TYPE gnatsd_varz_jetstream_stats_storage gauge
gnatsd_varz_jetstream_stats_storage{server_id="http://127.0.0.1:8291"} 1431
# HELP gnatsd_varz_leafnodes leafnodes
# TYPE gnatsd_varz_leafnodes gauge
gnatsd_varz_leafnodes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_max_connections max_connections
# TYPE gnatsd_varz_max_connections gauge
gnatsd_varz_max_connections{server_id="http://127.0.0.1:8291"} 65536
# HELP gnatsd_varz_max_control_line max_control_line
# TYPE gnatsd_varz_max_control_line gauge
gnatsd_varz_max_control_line{server_id="http://127.0.0.1:8291"} 4096
# HELP gnatsd_varz_max_payload max_payload
# TYPE gnatsd_varz_max_payload gauge
gnatsd_varz_max_payload{server_id="http://127.0.0.1:8291"} 1.048576e+06
# HELP gnatsd_varz_max_pending max_pending
# TYPE gnatsd_varz_max_pending gauge
gnatsd_varz_max_pending{server_id="http://127.0.0.1:8291"} 6.7108864e+07
# HELP gnatsd_varz_mem mem
# TYPE gnatsd_varz_mem gauge
gnatsd_varz_mem{server_id="http://127.0.0.1:8291"} 2.9360128e+07
# HELP gnatsd_varz_out_bytes out_bytes
# TYPE gnatsd_varz_out_bytes gauge
gnatsd_varz_out_bytes{server_id="http://127.0.0.1:8291"} 105482
# HELP gnatsd_varz_out_client_bytes out_client_bytes
# TYPE gnatsd_varz_out_client_bytes gauge
gnatsd_varz_out_client_bytes{server_id="http://127.0.0.1:8291"} 10906
# HELP gnatsd_varz_out_client_msgs out_client_msgs
# TYPE gnatsd_varz_out_client_msgs gauge
gnatsd_varz_out_client_msgs{server_id="http://127.0.0.1:8291"} 33
# HELP gnatsd_varz_out_msgs out_msgs
# TYPE gnatsd_varz_out_msgs gauge
gnatsd_varz_out_msgs{server_id="http://127.0.0.1:8291"} 537
# HELP gnatsd_varz_ping_interval ping_interval
# TYPE gnatsd_varz_ping_interval gauge
gnatsd_varz_ping_interval{server_id="http://127.0.0.1:8291"} 1.2e+11
# HELP gnatsd_varz_ping_max ping_max
# TYPE gnatsd_varz_ping_max gauge
gnatsd_varz_ping_max{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_port port
# TYPE gnatsd_varz_port gauge
gnatsd_varz_port{server_id="http://127.0.0.1:8291"} 4291
# HELP gnatsd_varz_proto proto
# TYPE gnatsd_varz_proto gauge
gnatsd_varz_proto{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_varz_remotes remotes
# TYPE gnatsd_varz_remotes gauge
gnatsd_varz_remotes{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_routes routes
# TYPE gnatsd_varz_routes gauge
gnatsd_varz_routes{server_id="http://127.0.0.1:8291"} 8
# HELP gnatsd_varz_server_id server_id
# TYPE gnatsd_varz_server_id gauge
gnatsd_varz_server_id{server_id="http://127.0.0.1:8291",value="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S"} 1
# HELP gnatsd_varz_server_name server_name
# TYPE gnatsd_varz_server_name gauge
gnatsd_varz_server_name{server_id="http://127.0.0.1:8291",value="n1"} 1
# HELP gnatsd_varz_slow_consumer_stats_clients slow_consumer_stats_clients
# TYPE gnatsd_varz_slow_consumer_stats_clients gauge
gnatsd_varz_slow_consumer_stats_clients{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumer_stats_gateways slow_consumer_stats_gateways
# TYPE gnatsd_varz_slow_consumer_stats_gateways gauge
gnatsd_varz_slow_consumer_stats_gateways{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumer_stats_leafs slow_consumer_stats_leafs
# TYPE gnatsd_varz_slow_consumer_stats_leafs gauge
gnatsd_varz_slow_consumer_stats_leafs{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumer_stats_routes slow_consumer_stats_routes
# TYPE gnatsd_varz_slow_consumer_stats_routes gauge
gnatsd_varz_slow_consumer_stats_routes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumers slow_consumers
# TYPE gnatsd_varz_slow_consumers gauge
gnatsd_varz_slow_consumers{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_clients stale_connection_stats_clients
# TYPE gnatsd_varz_stale_connection_stats_clients gauge
gnatsd_varz_stale_connection_stats_clients{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_gateways stale_connection_stats_gateways
# TYPE gnatsd_varz_stale_connection_stats_gateways gauge
gnatsd_varz_stale_connection_stats_gateways{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_leafs stale_connection_stats_leafs
# TYPE gnatsd_varz_stale_connection_stats_leafs gauge
gnatsd_varz_stale_connection_stats_leafs{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_routes stale_connection_stats_routes
# TYPE gnatsd_varz_stale_connection_stats_routes gauge
gnatsd_varz_stale_connection_stats_routes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connections stale_connections
# TYPE gnatsd_varz_stale_connections gauge
gnatsd_varz_stale_connections{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stalled_clients stalled_clients
# TYPE gnatsd_varz_stalled_clients gauge
gnatsd_varz_stalled_clients{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_start start
# TYPE gnatsd_varz_start gauge
gnatsd_varz_start{server_id="http://127.0.0.1:8291"} 1.788403202188e+12
# HELP gnatsd_varz_subscriptions subscriptions
# TYPE gnatsd_varz_subscriptions gauge
gnatsd_varz_subscriptions{server_id="http://127.0.0.1:8291"} 258
# HELP gnatsd_varz_tls_timeout tls_timeout
# TYPE gnatsd_varz_tls_timeout gauge
gnatsd_varz_tls_timeout{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_total_connections total_connections
# TYPE gnatsd_varz_total_connections gauge
gnatsd_varz_total_connections{server_id="http://127.0.0.1:8291"} 9
# HELP gnatsd_varz_version version
# TYPE gnatsd_varz_version gauge
gnatsd_varz_version{server_id="http://127.0.0.1:8291",value="2.14.6"} 1
# HELP gnatsd_varz_write_deadline write_deadline
# TYPE gnatsd_varz_write_deadline gauge
gnatsd_varz_write_deadline{server_id="http://127.0.0.1:8291"} 1e+10
# HELP jetstream_account_max_memory JetStream Account Max Memory in bytes
# TYPE jetstream_account_max_memory gauge
jetstream_account_max_memory{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1.8446744073709552e+19
# HELP jetstream_account_max_storage JetStream Account Max Storage in bytes
# TYPE jetstream_account_max_storage gauge
jetstream_account_max_storage{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1.8446744073709552e+19
# HELP jetstream_account_memory_used Total number of bytes used by JetStream memory
# TYPE jetstream_account_memory_used gauge
jetstream_account_memory_used{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 0
# HELP jetstream_account_storage_used Total number of bytes used by JetStream storage
# TYPE jetstream_account_storage_used gauge
jetstream_account_storage_used{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 9006
# HELP jetstream_server_jetstream_disabled JetStream disabled or not
# TYPE jetstream_server_jetstream_disabled gauge
jetstream_server_jetstream_disabled{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 0
# HELP jetstream_server_max_memory JetStream Max Memory
# TYPE jetstream_server_max_memory gauge
jetstream_server_max_memory{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 2.5769803776e+10
# HELP jetstream_server_max_storage JetStream Max Storage
# TYPE jetstream_server_max_storage gauge
jetstream_server_max_storage{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 7.424265216e+10
# HELP jetstream_server_total_consumers Total number of consumers in JetStream
# TYPE jetstream_server_total_consumers gauge
jetstream_server_total_consumers{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1
# HELP jetstream_server_total_message_bytes Total number of bytes stored in JetStream
# TYPE jetstream_server_total_message_bytes gauge
jetstream_server_total_message_bytes{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1431
# HELP jetstream_server_total_messages Total number of stored messages in JetStream
# TYPE jetstream_server_total_messages gauge
jetstream_server_total_messages{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 30
# HELP jetstream_server_total_streams Total number of streams in JetStream
# TYPE jetstream_server_total_streams gauge
jetstream_server_total_streams{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1
# HELP jetstream_stream_consumer_count Total number of consumers from a stream
# TYPE jetstream_stream_consumer_count gauge
jetstream_stream_consumer_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group=""} 1
# HELP jetstream_stream_first_seq First sequence from a stream
# TYPE jetstream_stream_first_seq gauge
jetstream_stream_first_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group=""} 1
# HELP jetstream_stream_last_seq Last sequence from a stream
# TYPE jetstream_stream_last_seq gauge
jetstream_stream_last_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group=""} 30
# HELP jetstream_stream_subject_count Total number of subjects in a stream
# TYPE jetstream_stream_subject_count gauge
jetstream_stream_subject_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group=""} 1
# HELP jetstream_stream_total_bytes Total stored bytes from a stream
# TYPE jetstream_stream_total_bytes gauge
jetstream_stream_total_bytes{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group=""} 1431
# HELP jetstream_stream_total_messages Total number of messages from a stream
# TYPE jetstream_stream_total_messages gauge
jetstream_stream_total_messages{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group=""} 30

[http 200]
```


## Run E · no collector flag at all

```
$ prometheus-nats-exporter -port 7777 http://127.0.0.1:8291
```

Exporter log (first lines):

```
[18168] 2026/09/03 04:41:51.366215 [FTL] error starting the exporter: no Collectors specified
```

Scrape of `http://127.0.0.1:7777/metrics`:

```

[http 000]
```


## Run F · `-jsz=all` alone

```
$ prometheus-nats-exporter -jsz=all -port 7777 http://127.0.0.1:8291
```

Exporter log (first lines):

```
No metrics specified.  Defaulting to varz.
[18525] 2026/09/03 04:42:02.789280 [INF] Prometheus exporter listening at http://0.0.0.0:7777/metrics
```

Scrape of `http://127.0.0.1:7777/metrics` — 112 `# HELP` lines kept, 38 `go_*`/`process_*`/`promhttp_*` series (122 lines) dropped:

```
# HELP gnatsd_varz_auth_timeout auth_timeout
# TYPE gnatsd_varz_auth_timeout gauge
gnatsd_varz_auth_timeout{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_cluster_name cluster_name
# TYPE gnatsd_varz_cluster_name gauge
gnatsd_varz_cluster_name{server_id="http://127.0.0.1:8291",value="east"} 1
# HELP gnatsd_varz_cluster_pool_size cluster_pool_size
# TYPE gnatsd_varz_cluster_pool_size gauge
gnatsd_varz_cluster_pool_size{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_varz_config_load_time config_load_time
# TYPE gnatsd_varz_config_load_time gauge
gnatsd_varz_config_load_time{server_id="http://127.0.0.1:8291"} 1.788403202188e+12
# HELP gnatsd_varz_connections connections
# TYPE gnatsd_varz_connections gauge
gnatsd_varz_connections{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_cores cores
# TYPE gnatsd_varz_cores gauge
gnatsd_varz_cores{server_id="http://127.0.0.1:8291"} 10
# HELP gnatsd_varz_cpu cpu
# TYPE gnatsd_varz_cpu gauge
gnatsd_varz_cpu{server_id="http://127.0.0.1:8291"} 0.3
# HELP gnatsd_varz_disk_io_wait_stats_max_wait_time disk_io_wait_stats_max_wait_time
# TYPE gnatsd_varz_disk_io_wait_stats_max_wait_time gauge
gnatsd_varz_disk_io_wait_stats_max_wait_time{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_disk_io_wait_stats_wait_time disk_io_wait_stats_wait_time
# TYPE gnatsd_varz_disk_io_wait_stats_wait_time gauge
gnatsd_varz_disk_io_wait_stats_wait_time{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_disk_io_wait_stats_waiters disk_io_wait_stats_waiters
# TYPE gnatsd_varz_disk_io_wait_stats_waiters gauge
gnatsd_varz_disk_io_wait_stats_waiters{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_disk_io_wait_stats_waits disk_io_wait_stats_waits
# TYPE gnatsd_varz_disk_io_wait_stats_waits gauge
gnatsd_varz_disk_io_wait_stats_waits{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_gomaxprocs gomaxprocs
# TYPE gnatsd_varz_gomaxprocs gauge
gnatsd_varz_gomaxprocs{server_id="http://127.0.0.1:8291"} 10
# HELP gnatsd_varz_http_port http_port
# TYPE gnatsd_varz_http_port gauge
gnatsd_varz_http_port{server_id="http://127.0.0.1:8291"} 8291
# HELP gnatsd_varz_http_req_stats_accountz http_req_stats_accountz
# TYPE gnatsd_varz_http_req_stats_accountz gauge
gnatsd_varz_http_req_stats_accountz{server_id="http://127.0.0.1:8291"} 12
# HELP gnatsd_varz_http_req_stats_accstatz http_req_stats_accstatz
# TYPE gnatsd_varz_http_req_stats_accstatz gauge
gnatsd_varz_http_req_stats_accstatz{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_http_req_stats_connz http_req_stats_connz
# TYPE gnatsd_varz_http_req_stats_connz gauge
gnatsd_varz_http_req_stats_connz{server_id="http://127.0.0.1:8291"} 7
# HELP gnatsd_varz_http_req_stats_gatewayz http_req_stats_gatewayz
# TYPE gnatsd_varz_http_req_stats_gatewayz gauge
gnatsd_varz_http_req_stats_gatewayz{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_http_req_stats_healthz http_req_stats_healthz
# TYPE gnatsd_varz_http_req_stats_healthz gauge
gnatsd_varz_http_req_stats_healthz{server_id="http://127.0.0.1:8291"} 13
# HELP gnatsd_varz_http_req_stats_jsz http_req_stats_jsz
# TYPE gnatsd_varz_http_req_stats_jsz gauge
gnatsd_varz_http_req_stats_jsz{server_id="http://127.0.0.1:8291"} 11
# HELP gnatsd_varz_http_req_stats_leafz http_req_stats_leafz
# TYPE gnatsd_varz_http_req_stats_leafz gauge
gnatsd_varz_http_req_stats_leafz{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_http_req_stats_routez http_req_stats_routez
# TYPE gnatsd_varz_http_req_stats_routez gauge
gnatsd_varz_http_req_stats_routez{server_id="http://127.0.0.1:8291"} 6
# HELP gnatsd_varz_http_req_stats_subsz http_req_stats_subsz
# TYPE gnatsd_varz_http_req_stats_subsz gauge
gnatsd_varz_http_req_stats_subsz{server_id="http://127.0.0.1:8291"} 6
# HELP gnatsd_varz_http_req_stats_varz http_req_stats_varz
# TYPE gnatsd_varz_http_req_stats_varz gauge
gnatsd_varz_http_req_stats_varz{server_id="http://127.0.0.1:8291"} 20
# HELP gnatsd_varz_https_port https_port
# TYPE gnatsd_varz_https_port gauge
gnatsd_varz_https_port{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_in_bytes in_bytes
# TYPE gnatsd_varz_in_bytes gauge
gnatsd_varz_in_bytes{server_id="http://127.0.0.1:8291"} 99966
# HELP gnatsd_varz_in_client_bytes in_client_bytes
# TYPE gnatsd_varz_in_client_bytes gauge
gnatsd_varz_in_client_bytes{server_id="http://127.0.0.1:8291"} 2327
# HELP gnatsd_varz_in_client_msgs in_client_msgs
# TYPE gnatsd_varz_in_client_msgs gauge
gnatsd_varz_in_client_msgs{server_id="http://127.0.0.1:8291"} 63
# HELP gnatsd_varz_in_msgs in_msgs
# TYPE gnatsd_varz_in_msgs gauge
gnatsd_varz_in_msgs{server_id="http://127.0.0.1:8291"} 590
# HELP gnatsd_varz_jetstream_config_max_memory jetstream_config_max_memory
# TYPE gnatsd_varz_jetstream_config_max_memory gauge
gnatsd_varz_jetstream_config_max_memory{server_id="http://127.0.0.1:8291"} 2.5769803776e+10
# HELP gnatsd_varz_jetstream_config_max_storage jetstream_config_max_storage
# TYPE gnatsd_varz_jetstream_config_max_storage gauge
gnatsd_varz_jetstream_config_max_storage{server_id="http://127.0.0.1:8291"} 7.424265216e+10
# HELP gnatsd_varz_jetstream_config_sync_interval jetstream_config_sync_interval
# TYPE gnatsd_varz_jetstream_config_sync_interval gauge
gnatsd_varz_jetstream_config_sync_interval{server_id="http://127.0.0.1:8291"} 1.2e+11
# HELP gnatsd_varz_jetstream_meta_cluster_size jetstream_meta_cluster_size
# TYPE gnatsd_varz_jetstream_meta_cluster_size gauge
gnatsd_varz_jetstream_meta_cluster_size{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_varz_jetstream_meta_leader jetstream_meta_leader
# TYPE gnatsd_varz_jetstream_meta_leader gauge
gnatsd_varz_jetstream_meta_leader{server_id="http://127.0.0.1:8291",value="n1"} 1
# HELP gnatsd_varz_jetstream_meta_name jetstream_meta_name
# TYPE gnatsd_varz_jetstream_meta_name gauge
gnatsd_varz_jetstream_meta_name{server_id="http://127.0.0.1:8291",value="east"} 1
# HELP gnatsd_varz_jetstream_meta_pending jetstream_meta_pending
# TYPE gnatsd_varz_jetstream_meta_pending gauge
gnatsd_varz_jetstream_meta_pending{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_meta_pending_infos jetstream_meta_pending_infos
# TYPE gnatsd_varz_jetstream_meta_pending_infos gauge
gnatsd_varz_jetstream_meta_pending_infos{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_meta_pending_requests jetstream_meta_pending_requests
# TYPE gnatsd_varz_jetstream_meta_pending_requests gauge
gnatsd_varz_jetstream_meta_pending_requests{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_meta_snapshot_last_duration jetstream_meta_snapshot_last_duration
# TYPE gnatsd_varz_jetstream_meta_snapshot_last_duration gauge
gnatsd_varz_jetstream_meta_snapshot_last_duration{server_id="http://127.0.0.1:8291"} 233875
# HELP gnatsd_varz_jetstream_meta_snapshot_pending_entries jetstream_meta_snapshot_pending_entries
# TYPE gnatsd_varz_jetstream_meta_snapshot_pending_entries gauge
gnatsd_varz_jetstream_meta_snapshot_pending_entries{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_meta_snapshot_pending_size jetstream_meta_snapshot_pending_size
# TYPE gnatsd_varz_jetstream_meta_snapshot_pending_size gauge
gnatsd_varz_jetstream_meta_snapshot_pending_size{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_stats_accounts jetstream_stats_accounts
# TYPE gnatsd_varz_jetstream_stats_accounts gauge
gnatsd_varz_jetstream_stats_accounts{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_varz_jetstream_stats_api_errors jetstream_stats_api_errors
# TYPE gnatsd_varz_jetstream_stats_api_errors gauge
gnatsd_varz_jetstream_stats_api_errors{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_varz_jetstream_stats_api_level jetstream_stats_api_level
# TYPE gnatsd_varz_jetstream_stats_api_level gauge
gnatsd_varz_jetstream_stats_api_level{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_jetstream_stats_api_total jetstream_stats_api_total
# TYPE gnatsd_varz_jetstream_stats_api_total gauge
gnatsd_varz_jetstream_stats_api_total{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_jetstream_stats_ha_assets jetstream_stats_ha_assets
# TYPE gnatsd_varz_jetstream_stats_ha_assets gauge
gnatsd_varz_jetstream_stats_ha_assets{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_varz_jetstream_stats_memory jetstream_stats_memory
# TYPE gnatsd_varz_jetstream_stats_memory gauge
gnatsd_varz_jetstream_stats_memory{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_stats_reserved_memory jetstream_stats_reserved_memory
# TYPE gnatsd_varz_jetstream_stats_reserved_memory gauge
gnatsd_varz_jetstream_stats_reserved_memory{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_stats_reserved_storage jetstream_stats_reserved_storage
# TYPE gnatsd_varz_jetstream_stats_reserved_storage gauge
gnatsd_varz_jetstream_stats_reserved_storage{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_stats_storage jetstream_stats_storage
# TYPE gnatsd_varz_jetstream_stats_storage gauge
gnatsd_varz_jetstream_stats_storage{server_id="http://127.0.0.1:8291"} 1431
# HELP gnatsd_varz_leafnodes leafnodes
# TYPE gnatsd_varz_leafnodes gauge
gnatsd_varz_leafnodes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_max_connections max_connections
# TYPE gnatsd_varz_max_connections gauge
gnatsd_varz_max_connections{server_id="http://127.0.0.1:8291"} 65536
# HELP gnatsd_varz_max_control_line max_control_line
# TYPE gnatsd_varz_max_control_line gauge
gnatsd_varz_max_control_line{server_id="http://127.0.0.1:8291"} 4096
# HELP gnatsd_varz_max_payload max_payload
# TYPE gnatsd_varz_max_payload gauge
gnatsd_varz_max_payload{server_id="http://127.0.0.1:8291"} 1.048576e+06
# HELP gnatsd_varz_max_pending max_pending
# TYPE gnatsd_varz_max_pending gauge
gnatsd_varz_max_pending{server_id="http://127.0.0.1:8291"} 6.7108864e+07
# HELP gnatsd_varz_mem mem
# TYPE gnatsd_varz_mem gauge
gnatsd_varz_mem{server_id="http://127.0.0.1:8291"} 2.9671424e+07
# HELP gnatsd_varz_out_bytes out_bytes
# TYPE gnatsd_varz_out_bytes gauge
gnatsd_varz_out_bytes{server_id="http://127.0.0.1:8291"} 111987
# HELP gnatsd_varz_out_client_bytes out_client_bytes
# TYPE gnatsd_varz_out_client_bytes gauge
gnatsd_varz_out_client_bytes{server_id="http://127.0.0.1:8291"} 10906
# HELP gnatsd_varz_out_client_msgs out_client_msgs
# TYPE gnatsd_varz_out_client_msgs gauge
gnatsd_varz_out_client_msgs{server_id="http://127.0.0.1:8291"} 33
# HELP gnatsd_varz_out_msgs out_msgs
# TYPE gnatsd_varz_out_msgs gauge
gnatsd_varz_out_msgs{server_id="http://127.0.0.1:8291"} 602
# HELP gnatsd_varz_ping_interval ping_interval
# TYPE gnatsd_varz_ping_interval gauge
gnatsd_varz_ping_interval{server_id="http://127.0.0.1:8291"} 1.2e+11
# HELP gnatsd_varz_ping_max ping_max
# TYPE gnatsd_varz_ping_max gauge
gnatsd_varz_ping_max{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_port port
# TYPE gnatsd_varz_port gauge
gnatsd_varz_port{server_id="http://127.0.0.1:8291"} 4291
# HELP gnatsd_varz_proto proto
# TYPE gnatsd_varz_proto gauge
gnatsd_varz_proto{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_varz_remotes remotes
# TYPE gnatsd_varz_remotes gauge
gnatsd_varz_remotes{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_routes routes
# TYPE gnatsd_varz_routes gauge
gnatsd_varz_routes{server_id="http://127.0.0.1:8291"} 8
# HELP gnatsd_varz_server_id server_id
# TYPE gnatsd_varz_server_id gauge
gnatsd_varz_server_id{server_id="http://127.0.0.1:8291",value="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S"} 1
# HELP gnatsd_varz_server_name server_name
# TYPE gnatsd_varz_server_name gauge
gnatsd_varz_server_name{server_id="http://127.0.0.1:8291",value="n1"} 1
# HELP gnatsd_varz_slow_consumer_stats_clients slow_consumer_stats_clients
# TYPE gnatsd_varz_slow_consumer_stats_clients gauge
gnatsd_varz_slow_consumer_stats_clients{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumer_stats_gateways slow_consumer_stats_gateways
# TYPE gnatsd_varz_slow_consumer_stats_gateways gauge
gnatsd_varz_slow_consumer_stats_gateways{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumer_stats_leafs slow_consumer_stats_leafs
# TYPE gnatsd_varz_slow_consumer_stats_leafs gauge
gnatsd_varz_slow_consumer_stats_leafs{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumer_stats_routes slow_consumer_stats_routes
# TYPE gnatsd_varz_slow_consumer_stats_routes gauge
gnatsd_varz_slow_consumer_stats_routes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumers slow_consumers
# TYPE gnatsd_varz_slow_consumers gauge
gnatsd_varz_slow_consumers{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_clients stale_connection_stats_clients
# TYPE gnatsd_varz_stale_connection_stats_clients gauge
gnatsd_varz_stale_connection_stats_clients{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_gateways stale_connection_stats_gateways
# TYPE gnatsd_varz_stale_connection_stats_gateways gauge
gnatsd_varz_stale_connection_stats_gateways{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_leafs stale_connection_stats_leafs
# TYPE gnatsd_varz_stale_connection_stats_leafs gauge
gnatsd_varz_stale_connection_stats_leafs{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_routes stale_connection_stats_routes
# TYPE gnatsd_varz_stale_connection_stats_routes gauge
gnatsd_varz_stale_connection_stats_routes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connections stale_connections
# TYPE gnatsd_varz_stale_connections gauge
gnatsd_varz_stale_connections{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stalled_clients stalled_clients
# TYPE gnatsd_varz_stalled_clients gauge
gnatsd_varz_stalled_clients{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_start start
# TYPE gnatsd_varz_start gauge
gnatsd_varz_start{server_id="http://127.0.0.1:8291"} 1.788403202188e+12
# HELP gnatsd_varz_subscriptions subscriptions
# TYPE gnatsd_varz_subscriptions gauge
gnatsd_varz_subscriptions{server_id="http://127.0.0.1:8291"} 258
# HELP gnatsd_varz_tls_timeout tls_timeout
# TYPE gnatsd_varz_tls_timeout gauge
gnatsd_varz_tls_timeout{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_total_connections total_connections
# TYPE gnatsd_varz_total_connections gauge
gnatsd_varz_total_connections{server_id="http://127.0.0.1:8291"} 9
# HELP gnatsd_varz_version version
# TYPE gnatsd_varz_version gauge
gnatsd_varz_version{server_id="http://127.0.0.1:8291",value="2.14.6"} 1
# HELP gnatsd_varz_write_deadline write_deadline
# TYPE gnatsd_varz_write_deadline gauge
gnatsd_varz_write_deadline{server_id="http://127.0.0.1:8291"} 1e+10
# HELP jetstream_account_max_memory JetStream Account Max Memory in bytes
# TYPE jetstream_account_max_memory gauge
jetstream_account_max_memory{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1.8446744073709552e+19
# HELP jetstream_account_max_storage JetStream Account Max Storage in bytes
# TYPE jetstream_account_max_storage gauge
jetstream_account_max_storage{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1.8446744073709552e+19
# HELP jetstream_account_memory_used Total number of bytes used by JetStream memory
# TYPE jetstream_account_memory_used gauge
jetstream_account_memory_used{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 0
# HELP jetstream_account_storage_used Total number of bytes used by JetStream storage
# TYPE jetstream_account_storage_used gauge
jetstream_account_storage_used{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 9006
# HELP jetstream_consumer_ack_floor_consumer_seq Number of ack floor consumer seq from a consumer
# TYPE jetstream_consumer_ack_floor_consumer_seq gauge
jetstream_consumer_ack_floor_consumer_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0
# HELP jetstream_consumer_ack_floor_stream_seq Number of ack floor stream seq from a consumer
# TYPE jetstream_consumer_ack_floor_stream_seq gauge
jetstream_consumer_ack_floor_stream_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0
# HELP jetstream_consumer_delivered_consumer_seq Latest sequence number of a stream consumer
# TYPE jetstream_consumer_delivered_consumer_seq gauge
jetstream_consumer_delivered_consumer_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 20
# HELP jetstream_consumer_delivered_stream_seq Latest sequence number of a stream
# TYPE jetstream_consumer_delivered_stream_seq gauge
jetstream_consumer_delivered_stream_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 10
# HELP jetstream_consumer_last_delivery_seconds Seconds since last message delivery to consumer
# TYPE jetstream_consumer_last_delivery_seconds gauge
jetstream_consumer_last_delivery_seconds{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 13.670275
# HELP jetstream_consumer_num_ack_pending Number of pending acks from a consumer
# TYPE jetstream_consumer_num_ack_pending gauge
jetstream_consumer_num_ack_pending{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 10
# HELP jetstream_consumer_num_pending Number of pending messages from a consumer
# TYPE jetstream_consumer_num_pending gauge
jetstream_consumer_num_pending{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0
# HELP jetstream_consumer_num_redelivered Number of redelivered messages from a consumer
# TYPE jetstream_consumer_num_redelivered gauge
jetstream_consumer_num_redelivered{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 10
# HELP jetstream_consumer_num_waiting Number of inflight fetch requests from a pull consumer
# TYPE jetstream_consumer_num_waiting gauge
jetstream_consumer_num_waiting{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0
# HELP jetstream_server_jetstream_disabled JetStream disabled or not
# TYPE jetstream_server_jetstream_disabled gauge
jetstream_server_jetstream_disabled{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 0
# HELP jetstream_server_max_memory JetStream Max Memory
# TYPE jetstream_server_max_memory gauge
jetstream_server_max_memory{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 2.5769803776e+10
# HELP jetstream_server_max_storage JetStream Max Storage
# TYPE jetstream_server_max_storage gauge
jetstream_server_max_storage{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 7.424265216e+10
# HELP jetstream_server_total_consumers Total number of consumers in JetStream
# TYPE jetstream_server_total_consumers gauge
jetstream_server_total_consumers{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1
# HELP jetstream_server_total_message_bytes Total number of bytes stored in JetStream
# TYPE jetstream_server_total_message_bytes gauge
jetstream_server_total_message_bytes{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1431
# HELP jetstream_server_total_messages Total number of stored messages in JetStream
# TYPE jetstream_server_total_messages gauge
jetstream_server_total_messages{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 30
# HELP jetstream_server_total_streams Total number of streams in JetStream
# TYPE jetstream_server_total_streams gauge
jetstream_server_total_streams{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1
# HELP jetstream_stream_consumer_count Total number of consumers from a stream
# TYPE jetstream_stream_consumer_count gauge
jetstream_stream_consumer_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP jetstream_stream_first_seq First sequence from a stream
# TYPE jetstream_stream_first_seq gauge
jetstream_stream_first_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP jetstream_stream_last_seq Last sequence from a stream
# TYPE jetstream_stream_last_seq gauge
jetstream_stream_last_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 30
# HELP jetstream_stream_limit_bytes The maximum configured storage limit (in bytes) for a JetStream stream. A value of -1 indicates no limit.
# TYPE jetstream_stream_limit_bytes gauge
jetstream_stream_limit_bytes{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} -1
# HELP jetstream_stream_limit_messages The maximum number of messages allowed in a JetStream stream as per its configuration. A value of -1 indicates no limit.
# TYPE jetstream_stream_limit_messages gauge
jetstream_stream_limit_messages{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} -1
# HELP jetstream_stream_subject_count Total number of subjects in a stream
# TYPE jetstream_stream_subject_count gauge
jetstream_stream_subject_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP jetstream_stream_total_bytes Total stored bytes from a stream
# TYPE jetstream_stream_total_bytes gauge
jetstream_stream_total_bytes{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1431
# HELP jetstream_stream_total_messages Total number of messages from a stream
# TYPE jetstream_stream_total_messages gauge
jetstream_stream_total_messages{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 30

[http 200]
```


## Run G · `-use_internal_server_name`

```
$ prometheus-nats-exporter -use_internal_server_name -varz -port 7777 http://127.0.0.1:8291
```

Exporter log (first lines):

```
[18533] 2026/09/03 04:42:02.817555 [INF] Prometheus exporter listening at http://0.0.0.0:7777/metrics
```

Scrape of `http://127.0.0.1:7777/metrics` — 84 `# HELP` lines kept, 38 `go_*`/`process_*`/`promhttp_*` series (122 lines) dropped:

```
# HELP gnatsd_varz_auth_timeout auth_timeout
# TYPE gnatsd_varz_auth_timeout gauge
gnatsd_varz_auth_timeout{server_id="n1"} 2
# HELP gnatsd_varz_cluster_name cluster_name
# TYPE gnatsd_varz_cluster_name gauge
gnatsd_varz_cluster_name{server_id="n1",value="east"} 1
# HELP gnatsd_varz_cluster_pool_size cluster_pool_size
# TYPE gnatsd_varz_cluster_pool_size gauge
gnatsd_varz_cluster_pool_size{server_id="n1"} 3
# HELP gnatsd_varz_config_load_time config_load_time
# TYPE gnatsd_varz_config_load_time gauge
gnatsd_varz_config_load_time{server_id="n1"} 1.788403202188e+12
# HELP gnatsd_varz_connections connections
# TYPE gnatsd_varz_connections gauge
gnatsd_varz_connections{server_id="n1"} 0
# HELP gnatsd_varz_cores cores
# TYPE gnatsd_varz_cores gauge
gnatsd_varz_cores{server_id="n1"} 10
# HELP gnatsd_varz_cpu cpu
# TYPE gnatsd_varz_cpu gauge
gnatsd_varz_cpu{server_id="n1"} 0.3
# HELP gnatsd_varz_disk_io_wait_stats_max_wait_time disk_io_wait_stats_max_wait_time
# TYPE gnatsd_varz_disk_io_wait_stats_max_wait_time gauge
gnatsd_varz_disk_io_wait_stats_max_wait_time{server_id="n1"} 0
# HELP gnatsd_varz_disk_io_wait_stats_wait_time disk_io_wait_stats_wait_time
# TYPE gnatsd_varz_disk_io_wait_stats_wait_time gauge
gnatsd_varz_disk_io_wait_stats_wait_time{server_id="n1"} 0
# HELP gnatsd_varz_disk_io_wait_stats_waiters disk_io_wait_stats_waiters
# TYPE gnatsd_varz_disk_io_wait_stats_waiters gauge
gnatsd_varz_disk_io_wait_stats_waiters{server_id="n1"} 0
# HELP gnatsd_varz_disk_io_wait_stats_waits disk_io_wait_stats_waits
# TYPE gnatsd_varz_disk_io_wait_stats_waits gauge
gnatsd_varz_disk_io_wait_stats_waits{server_id="n1"} 0
# HELP gnatsd_varz_gomaxprocs gomaxprocs
# TYPE gnatsd_varz_gomaxprocs gauge
gnatsd_varz_gomaxprocs{server_id="n1"} 10
# HELP gnatsd_varz_http_port http_port
# TYPE gnatsd_varz_http_port gauge
gnatsd_varz_http_port{server_id="n1"} 8291
# HELP gnatsd_varz_http_req_stats_accountz http_req_stats_accountz
# TYPE gnatsd_varz_http_req_stats_accountz gauge
gnatsd_varz_http_req_stats_accountz{server_id="n1"} 12
# HELP gnatsd_varz_http_req_stats_accstatz http_req_stats_accstatz
# TYPE gnatsd_varz_http_req_stats_accstatz gauge
gnatsd_varz_http_req_stats_accstatz{server_id="n1"} 4
# HELP gnatsd_varz_http_req_stats_connz http_req_stats_connz
# TYPE gnatsd_varz_http_req_stats_connz gauge
gnatsd_varz_http_req_stats_connz{server_id="n1"} 7
# HELP gnatsd_varz_http_req_stats_gatewayz http_req_stats_gatewayz
# TYPE gnatsd_varz_http_req_stats_gatewayz gauge
gnatsd_varz_http_req_stats_gatewayz{server_id="n1"} 4
# HELP gnatsd_varz_http_req_stats_healthz http_req_stats_healthz
# TYPE gnatsd_varz_http_req_stats_healthz gauge
gnatsd_varz_http_req_stats_healthz{server_id="n1"} 13
# HELP gnatsd_varz_http_req_stats_jsz http_req_stats_jsz
# TYPE gnatsd_varz_http_req_stats_jsz gauge
gnatsd_varz_http_req_stats_jsz{server_id="n1"} 11
# HELP gnatsd_varz_http_req_stats_leafz http_req_stats_leafz
# TYPE gnatsd_varz_http_req_stats_leafz gauge
gnatsd_varz_http_req_stats_leafz{server_id="n1"} 4
# HELP gnatsd_varz_http_req_stats_routez http_req_stats_routez
# TYPE gnatsd_varz_http_req_stats_routez gauge
gnatsd_varz_http_req_stats_routez{server_id="n1"} 6
# HELP gnatsd_varz_http_req_stats_subsz http_req_stats_subsz
# TYPE gnatsd_varz_http_req_stats_subsz gauge
gnatsd_varz_http_req_stats_subsz{server_id="n1"} 6
# HELP gnatsd_varz_http_req_stats_varz http_req_stats_varz
# TYPE gnatsd_varz_http_req_stats_varz gauge
gnatsd_varz_http_req_stats_varz{server_id="n1"} 25
# HELP gnatsd_varz_https_port https_port
# TYPE gnatsd_varz_https_port gauge
gnatsd_varz_https_port{server_id="n1"} 0
# HELP gnatsd_varz_in_bytes in_bytes
# TYPE gnatsd_varz_in_bytes gauge
gnatsd_varz_in_bytes{server_id="n1"} 99966
# HELP gnatsd_varz_in_client_bytes in_client_bytes
# TYPE gnatsd_varz_in_client_bytes gauge
gnatsd_varz_in_client_bytes{server_id="n1"} 2327
# HELP gnatsd_varz_in_client_msgs in_client_msgs
# TYPE gnatsd_varz_in_client_msgs gauge
gnatsd_varz_in_client_msgs{server_id="n1"} 63
# HELP gnatsd_varz_in_msgs in_msgs
# TYPE gnatsd_varz_in_msgs gauge
gnatsd_varz_in_msgs{server_id="n1"} 590
# HELP gnatsd_varz_jetstream_config_max_memory jetstream_config_max_memory
# TYPE gnatsd_varz_jetstream_config_max_memory gauge
gnatsd_varz_jetstream_config_max_memory{server_id="n1"} 2.5769803776e+10
# HELP gnatsd_varz_jetstream_config_max_storage jetstream_config_max_storage
# TYPE gnatsd_varz_jetstream_config_max_storage gauge
gnatsd_varz_jetstream_config_max_storage{server_id="n1"} 7.424265216e+10
# HELP gnatsd_varz_jetstream_config_sync_interval jetstream_config_sync_interval
# TYPE gnatsd_varz_jetstream_config_sync_interval gauge
gnatsd_varz_jetstream_config_sync_interval{server_id="n1"} 1.2e+11
# HELP gnatsd_varz_jetstream_meta_cluster_size jetstream_meta_cluster_size
# TYPE gnatsd_varz_jetstream_meta_cluster_size gauge
gnatsd_varz_jetstream_meta_cluster_size{server_id="n1"} 3
# HELP gnatsd_varz_jetstream_meta_leader jetstream_meta_leader
# TYPE gnatsd_varz_jetstream_meta_leader gauge
gnatsd_varz_jetstream_meta_leader{server_id="n1",value="n1"} 1
# HELP gnatsd_varz_jetstream_meta_name jetstream_meta_name
# TYPE gnatsd_varz_jetstream_meta_name gauge
gnatsd_varz_jetstream_meta_name{server_id="n1",value="east"} 1
# HELP gnatsd_varz_jetstream_meta_pending jetstream_meta_pending
# TYPE gnatsd_varz_jetstream_meta_pending gauge
gnatsd_varz_jetstream_meta_pending{server_id="n1"} 0
# HELP gnatsd_varz_jetstream_meta_pending_infos jetstream_meta_pending_infos
# TYPE gnatsd_varz_jetstream_meta_pending_infos gauge
gnatsd_varz_jetstream_meta_pending_infos{server_id="n1"} 0
# HELP gnatsd_varz_jetstream_meta_pending_requests jetstream_meta_pending_requests
# TYPE gnatsd_varz_jetstream_meta_pending_requests gauge
gnatsd_varz_jetstream_meta_pending_requests{server_id="n1"} 0
# HELP gnatsd_varz_jetstream_meta_snapshot_last_duration jetstream_meta_snapshot_last_duration
# TYPE gnatsd_varz_jetstream_meta_snapshot_last_duration gauge
gnatsd_varz_jetstream_meta_snapshot_last_duration{server_id="n1"} 233875
# HELP gnatsd_varz_jetstream_meta_snapshot_pending_entries jetstream_meta_snapshot_pending_entries
# TYPE gnatsd_varz_jetstream_meta_snapshot_pending_entries gauge
gnatsd_varz_jetstream_meta_snapshot_pending_entries{server_id="n1"} 0
# HELP gnatsd_varz_jetstream_meta_snapshot_pending_size jetstream_meta_snapshot_pending_size
# TYPE gnatsd_varz_jetstream_meta_snapshot_pending_size gauge
gnatsd_varz_jetstream_meta_snapshot_pending_size{server_id="n1"} 0
# HELP gnatsd_varz_jetstream_stats_accounts jetstream_stats_accounts
# TYPE gnatsd_varz_jetstream_stats_accounts gauge
gnatsd_varz_jetstream_stats_accounts{server_id="n1"} 1
# HELP gnatsd_varz_jetstream_stats_api_errors jetstream_stats_api_errors
# TYPE gnatsd_varz_jetstream_stats_api_errors gauge
gnatsd_varz_jetstream_stats_api_errors{server_id="n1"} 1
# HELP gnatsd_varz_jetstream_stats_api_level jetstream_stats_api_level
# TYPE gnatsd_varz_jetstream_stats_api_level gauge
gnatsd_varz_jetstream_stats_api_level{server_id="n1"} 4
# HELP gnatsd_varz_jetstream_stats_api_total jetstream_stats_api_total
# TYPE gnatsd_varz_jetstream_stats_api_total gauge
gnatsd_varz_jetstream_stats_api_total{server_id="n1"} 4
# HELP gnatsd_varz_jetstream_stats_ha_assets jetstream_stats_ha_assets
# TYPE gnatsd_varz_jetstream_stats_ha_assets gauge
gnatsd_varz_jetstream_stats_ha_assets{server_id="n1"} 3
# HELP gnatsd_varz_jetstream_stats_memory jetstream_stats_memory
# TYPE gnatsd_varz_jetstream_stats_memory gauge
gnatsd_varz_jetstream_stats_memory{server_id="n1"} 0
# HELP gnatsd_varz_jetstream_stats_reserved_memory jetstream_stats_reserved_memory
# TYPE gnatsd_varz_jetstream_stats_reserved_memory gauge
gnatsd_varz_jetstream_stats_reserved_memory{server_id="n1"} 0
# HELP gnatsd_varz_jetstream_stats_reserved_storage jetstream_stats_reserved_storage
# TYPE gnatsd_varz_jetstream_stats_reserved_storage gauge
gnatsd_varz_jetstream_stats_reserved_storage{server_id="n1"} 0
# HELP gnatsd_varz_jetstream_stats_storage jetstream_stats_storage
# TYPE gnatsd_varz_jetstream_stats_storage gauge
gnatsd_varz_jetstream_stats_storage{server_id="n1"} 1431
# HELP gnatsd_varz_leafnodes leafnodes
# TYPE gnatsd_varz_leafnodes gauge
gnatsd_varz_leafnodes{server_id="n1"} 0
# HELP gnatsd_varz_max_connections max_connections
# TYPE gnatsd_varz_max_connections gauge
gnatsd_varz_max_connections{server_id="n1"} 65536
# HELP gnatsd_varz_max_control_line max_control_line
# TYPE gnatsd_varz_max_control_line gauge
gnatsd_varz_max_control_line{server_id="n1"} 4096
# HELP gnatsd_varz_max_payload max_payload
# TYPE gnatsd_varz_max_payload gauge
gnatsd_varz_max_payload{server_id="n1"} 1.048576e+06
# HELP gnatsd_varz_max_pending max_pending
# TYPE gnatsd_varz_max_pending gauge
gnatsd_varz_max_pending{server_id="n1"} 6.7108864e+07
# HELP gnatsd_varz_mem mem
# TYPE gnatsd_varz_mem gauge
gnatsd_varz_mem{server_id="n1"} 2.9687808e+07
# HELP gnatsd_varz_out_bytes out_bytes
# TYPE gnatsd_varz_out_bytes gauge
gnatsd_varz_out_bytes{server_id="n1"} 111987
# HELP gnatsd_varz_out_client_bytes out_client_bytes
# TYPE gnatsd_varz_out_client_bytes gauge
gnatsd_varz_out_client_bytes{server_id="n1"} 10906
# HELP gnatsd_varz_out_client_msgs out_client_msgs
# TYPE gnatsd_varz_out_client_msgs gauge
gnatsd_varz_out_client_msgs{server_id="n1"} 33
# HELP gnatsd_varz_out_msgs out_msgs
# TYPE gnatsd_varz_out_msgs gauge
gnatsd_varz_out_msgs{server_id="n1"} 602
# HELP gnatsd_varz_ping_interval ping_interval
# TYPE gnatsd_varz_ping_interval gauge
gnatsd_varz_ping_interval{server_id="n1"} 1.2e+11
# HELP gnatsd_varz_ping_max ping_max
# TYPE gnatsd_varz_ping_max gauge
gnatsd_varz_ping_max{server_id="n1"} 2
# HELP gnatsd_varz_port port
# TYPE gnatsd_varz_port gauge
gnatsd_varz_port{server_id="n1"} 4291
# HELP gnatsd_varz_proto proto
# TYPE gnatsd_varz_proto gauge
gnatsd_varz_proto{server_id="n1"} 1
# HELP gnatsd_varz_remotes remotes
# TYPE gnatsd_varz_remotes gauge
gnatsd_varz_remotes{server_id="n1"} 2
# HELP gnatsd_varz_routes routes
# TYPE gnatsd_varz_routes gauge
gnatsd_varz_routes{server_id="n1"} 8
# HELP gnatsd_varz_server_id server_id
# TYPE gnatsd_varz_server_id gauge
gnatsd_varz_server_id{server_id="n1",value="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S"} 1
# HELP gnatsd_varz_server_name server_name
# TYPE gnatsd_varz_server_name gauge
gnatsd_varz_server_name{server_id="n1",value="n1"} 1
# HELP gnatsd_varz_slow_consumer_stats_clients slow_consumer_stats_clients
# TYPE gnatsd_varz_slow_consumer_stats_clients gauge
gnatsd_varz_slow_consumer_stats_clients{server_id="n1"} 0
# HELP gnatsd_varz_slow_consumer_stats_gateways slow_consumer_stats_gateways
# TYPE gnatsd_varz_slow_consumer_stats_gateways gauge
gnatsd_varz_slow_consumer_stats_gateways{server_id="n1"} 0
# HELP gnatsd_varz_slow_consumer_stats_leafs slow_consumer_stats_leafs
# TYPE gnatsd_varz_slow_consumer_stats_leafs gauge
gnatsd_varz_slow_consumer_stats_leafs{server_id="n1"} 0
# HELP gnatsd_varz_slow_consumer_stats_routes slow_consumer_stats_routes
# TYPE gnatsd_varz_slow_consumer_stats_routes gauge
gnatsd_varz_slow_consumer_stats_routes{server_id="n1"} 0
# HELP gnatsd_varz_slow_consumers slow_consumers
# TYPE gnatsd_varz_slow_consumers gauge
gnatsd_varz_slow_consumers{server_id="n1"} 0
# HELP gnatsd_varz_stale_connection_stats_clients stale_connection_stats_clients
# TYPE gnatsd_varz_stale_connection_stats_clients gauge
gnatsd_varz_stale_connection_stats_clients{server_id="n1"} 0
# HELP gnatsd_varz_stale_connection_stats_gateways stale_connection_stats_gateways
# TYPE gnatsd_varz_stale_connection_stats_gateways gauge
gnatsd_varz_stale_connection_stats_gateways{server_id="n1"} 0
# HELP gnatsd_varz_stale_connection_stats_leafs stale_connection_stats_leafs
# TYPE gnatsd_varz_stale_connection_stats_leafs gauge
gnatsd_varz_stale_connection_stats_leafs{server_id="n1"} 0
# HELP gnatsd_varz_stale_connection_stats_routes stale_connection_stats_routes
# TYPE gnatsd_varz_stale_connection_stats_routes gauge
gnatsd_varz_stale_connection_stats_routes{server_id="n1"} 0
# HELP gnatsd_varz_stale_connections stale_connections
# TYPE gnatsd_varz_stale_connections gauge
gnatsd_varz_stale_connections{server_id="n1"} 0
# HELP gnatsd_varz_stalled_clients stalled_clients
# TYPE gnatsd_varz_stalled_clients gauge
gnatsd_varz_stalled_clients{server_id="n1"} 0
# HELP gnatsd_varz_start start
# TYPE gnatsd_varz_start gauge
gnatsd_varz_start{server_id="n1"} 1.788403202188e+12
# HELP gnatsd_varz_subscriptions subscriptions
# TYPE gnatsd_varz_subscriptions gauge
gnatsd_varz_subscriptions{server_id="n1"} 258
# HELP gnatsd_varz_tls_timeout tls_timeout
# TYPE gnatsd_varz_tls_timeout gauge
gnatsd_varz_tls_timeout{server_id="n1"} 2
# HELP gnatsd_varz_total_connections total_connections
# TYPE gnatsd_varz_total_connections gauge
gnatsd_varz_total_connections{server_id="n1"} 9
# HELP gnatsd_varz_version version
# TYPE gnatsd_varz_version gauge
gnatsd_varz_version{server_id="n1",value="2.14.6"} 1
# HELP gnatsd_varz_write_deadline write_deadline
# TYPE gnatsd_varz_write_deadline gauge
gnatsd_varz_write_deadline{server_id="n1"} 1e+10

[http 200]
```


## Run H1-n2 · after one ack: node n2, the leader of the R3 stream and consumer and the only holder of the two R1 streams

```
$ prometheus-nats-exporter -varz -jsz=all -port 7777 http://127.0.0.1:8292
```

Exporter log (first lines):

```
[24530] 2026/09/03 04:45:20.070050 [INF] Prometheus exporter listening at http://0.0.0.0:7777/metrics
```

The acknowledgement that precedes runs H1 (transcript of `metrics-run2.sh`):

```
== H1: one ack, then n2 and n1

$ nats consumer next ORDERS shipping --count 1 --ack
[04:45:20] subj: orders.new / tries: 3 / cons seq: 21 / str seq: 1 / pending: 20

order 1

Acknowledged message

State:

            Host Version: 2.14.6
      Required API Level: 0 hosted at level 4
  Last Delivered Message: Consumer sequence: 21 Stream sequence: 10 Last delivery: 12ms ago
    Acknowledgment Floor: Consumer sequence: 1 Stream sequence: 1 Last Ack: 12ms ago
        Outstanding Acks: 9 out of maximum 1,000
    Redelivered Messages: 9
    Unprocessed Messages: 20
           Waiting Pulls: 0 of maximum 512
```

Scrape of `http://127.0.0.1:7777/metrics` — 110 `# HELP` lines kept, 38 `go_*`/`process_*`/`promhttp_*` series (122 lines) dropped:

```
# HELP gnatsd_varz_auth_timeout auth_timeout
# TYPE gnatsd_varz_auth_timeout gauge
gnatsd_varz_auth_timeout{server_id="http://127.0.0.1:8292"} 2
# HELP gnatsd_varz_cluster_name cluster_name
# TYPE gnatsd_varz_cluster_name gauge
gnatsd_varz_cluster_name{server_id="http://127.0.0.1:8292",value="east"} 1
# HELP gnatsd_varz_cluster_pool_size cluster_pool_size
# TYPE gnatsd_varz_cluster_pool_size gauge
gnatsd_varz_cluster_pool_size{server_id="http://127.0.0.1:8292"} 3
# HELP gnatsd_varz_config_load_time config_load_time
# TYPE gnatsd_varz_config_load_time gauge
gnatsd_varz_config_load_time{server_id="http://127.0.0.1:8292"} 1.788403202356e+12
# HELP gnatsd_varz_connections connections
# TYPE gnatsd_varz_connections gauge
gnatsd_varz_connections{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_cores cores
# TYPE gnatsd_varz_cores gauge
gnatsd_varz_cores{server_id="http://127.0.0.1:8292"} 10
# HELP gnatsd_varz_cpu cpu
# TYPE gnatsd_varz_cpu gauge
gnatsd_varz_cpu{server_id="http://127.0.0.1:8292"} 0.8
# HELP gnatsd_varz_disk_io_wait_stats_max_wait_time disk_io_wait_stats_max_wait_time
# TYPE gnatsd_varz_disk_io_wait_stats_max_wait_time gauge
gnatsd_varz_disk_io_wait_stats_max_wait_time{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_disk_io_wait_stats_wait_time disk_io_wait_stats_wait_time
# TYPE gnatsd_varz_disk_io_wait_stats_wait_time gauge
gnatsd_varz_disk_io_wait_stats_wait_time{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_disk_io_wait_stats_waiters disk_io_wait_stats_waiters
# TYPE gnatsd_varz_disk_io_wait_stats_waiters gauge
gnatsd_varz_disk_io_wait_stats_waiters{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_disk_io_wait_stats_waits disk_io_wait_stats_waits
# TYPE gnatsd_varz_disk_io_wait_stats_waits gauge
gnatsd_varz_disk_io_wait_stats_waits{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_gomaxprocs gomaxprocs
# TYPE gnatsd_varz_gomaxprocs gauge
gnatsd_varz_gomaxprocs{server_id="http://127.0.0.1:8292"} 10
# HELP gnatsd_varz_http_port http_port
# TYPE gnatsd_varz_http_port gauge
gnatsd_varz_http_port{server_id="http://127.0.0.1:8292"} 8292
# HELP gnatsd_varz_http_req_stats_healthz http_req_stats_healthz
# TYPE gnatsd_varz_http_req_stats_healthz gauge
gnatsd_varz_http_req_stats_healthz{server_id="http://127.0.0.1:8292"} 4
# HELP gnatsd_varz_http_req_stats_jsz http_req_stats_jsz
# TYPE gnatsd_varz_http_req_stats_jsz gauge
gnatsd_varz_http_req_stats_jsz{server_id="http://127.0.0.1:8292"} 2
# HELP gnatsd_varz_http_req_stats_varz http_req_stats_varz
# TYPE gnatsd_varz_http_req_stats_varz gauge
gnatsd_varz_http_req_stats_varz{server_id="http://127.0.0.1:8292"} 4
# HELP gnatsd_varz_https_port https_port
# TYPE gnatsd_varz_https_port gauge
gnatsd_varz_https_port{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_in_bytes in_bytes
# TYPE gnatsd_varz_in_bytes gauge
gnatsd_varz_in_bytes{server_id="http://127.0.0.1:8292"} 219594
# HELP gnatsd_varz_in_client_bytes in_client_bytes
# TYPE gnatsd_varz_in_client_bytes gauge
gnatsd_varz_in_client_bytes{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_in_client_msgs in_client_msgs
# TYPE gnatsd_varz_in_client_msgs gauge
gnatsd_varz_in_client_msgs{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_in_msgs in_msgs
# TYPE gnatsd_varz_in_msgs gauge
gnatsd_varz_in_msgs{server_id="http://127.0.0.1:8292"} 1927
# HELP gnatsd_varz_jetstream_config_max_memory jetstream_config_max_memory
# TYPE gnatsd_varz_jetstream_config_max_memory gauge
gnatsd_varz_jetstream_config_max_memory{server_id="http://127.0.0.1:8292"} 2.5769803776e+10
# HELP gnatsd_varz_jetstream_config_max_storage jetstream_config_max_storage
# TYPE gnatsd_varz_jetstream_config_max_storage gauge
gnatsd_varz_jetstream_config_max_storage{server_id="http://127.0.0.1:8292"} 7.4242679808e+10
# HELP gnatsd_varz_jetstream_config_sync_interval jetstream_config_sync_interval
# TYPE gnatsd_varz_jetstream_config_sync_interval gauge
gnatsd_varz_jetstream_config_sync_interval{server_id="http://127.0.0.1:8292"} 1.2e+11
# HELP gnatsd_varz_jetstream_meta_cluster_size jetstream_meta_cluster_size
# TYPE gnatsd_varz_jetstream_meta_cluster_size gauge
gnatsd_varz_jetstream_meta_cluster_size{server_id="http://127.0.0.1:8292"} 3
# HELP gnatsd_varz_jetstream_meta_leader jetstream_meta_leader
# TYPE gnatsd_varz_jetstream_meta_leader gauge
gnatsd_varz_jetstream_meta_leader{server_id="http://127.0.0.1:8292",value="n1"} 1
# HELP gnatsd_varz_jetstream_meta_name jetstream_meta_name
# TYPE gnatsd_varz_jetstream_meta_name gauge
gnatsd_varz_jetstream_meta_name{server_id="http://127.0.0.1:8292",value="east"} 1
# HELP gnatsd_varz_jetstream_meta_pending jetstream_meta_pending
# TYPE gnatsd_varz_jetstream_meta_pending gauge
gnatsd_varz_jetstream_meta_pending{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_jetstream_meta_pending_infos jetstream_meta_pending_infos
# TYPE gnatsd_varz_jetstream_meta_pending_infos gauge
gnatsd_varz_jetstream_meta_pending_infos{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_jetstream_meta_pending_requests jetstream_meta_pending_requests
# TYPE gnatsd_varz_jetstream_meta_pending_requests gauge
gnatsd_varz_jetstream_meta_pending_requests{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_jetstream_meta_snapshot_last_duration jetstream_meta_snapshot_last_duration
# TYPE gnatsd_varz_jetstream_meta_snapshot_last_duration gauge
gnatsd_varz_jetstream_meta_snapshot_last_duration{server_id="http://127.0.0.1:8292"} 305333
# HELP gnatsd_varz_jetstream_meta_snapshot_pending_entries jetstream_meta_snapshot_pending_entries
# TYPE gnatsd_varz_jetstream_meta_snapshot_pending_entries gauge
gnatsd_varz_jetstream_meta_snapshot_pending_entries{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_jetstream_meta_snapshot_pending_size jetstream_meta_snapshot_pending_size
# TYPE gnatsd_varz_jetstream_meta_snapshot_pending_size gauge
gnatsd_varz_jetstream_meta_snapshot_pending_size{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_jetstream_stats_accounts jetstream_stats_accounts
# TYPE gnatsd_varz_jetstream_stats_accounts gauge
gnatsd_varz_jetstream_stats_accounts{server_id="http://127.0.0.1:8292"} 1
# HELP gnatsd_varz_jetstream_stats_api_errors jetstream_stats_api_errors
# TYPE gnatsd_varz_jetstream_stats_api_errors gauge
gnatsd_varz_jetstream_stats_api_errors{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_jetstream_stats_api_level jetstream_stats_api_level
# TYPE gnatsd_varz_jetstream_stats_api_level gauge
gnatsd_varz_jetstream_stats_api_level{server_id="http://127.0.0.1:8292"} 4
# HELP gnatsd_varz_jetstream_stats_api_total jetstream_stats_api_total
# TYPE gnatsd_varz_jetstream_stats_api_total gauge
gnatsd_varz_jetstream_stats_api_total{server_id="http://127.0.0.1:8292"} 13
# HELP gnatsd_varz_jetstream_stats_ha_assets jetstream_stats_ha_assets
# TYPE gnatsd_varz_jetstream_stats_ha_assets gauge
gnatsd_varz_jetstream_stats_ha_assets{server_id="http://127.0.0.1:8292"} 3
# HELP gnatsd_varz_jetstream_stats_memory jetstream_stats_memory
# TYPE gnatsd_varz_jetstream_stats_memory gauge
gnatsd_varz_jetstream_stats_memory{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_jetstream_stats_reserved_memory jetstream_stats_reserved_memory
# TYPE gnatsd_varz_jetstream_stats_reserved_memory gauge
gnatsd_varz_jetstream_stats_reserved_memory{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_jetstream_stats_reserved_storage jetstream_stats_reserved_storage
# TYPE gnatsd_varz_jetstream_stats_reserved_storage gauge
gnatsd_varz_jetstream_stats_reserved_storage{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_jetstream_stats_storage jetstream_stats_storage
# TYPE gnatsd_varz_jetstream_stats_storage gauge
gnatsd_varz_jetstream_stats_storage{server_id="http://127.0.0.1:8292"} 6144
# HELP gnatsd_varz_leafnodes leafnodes
# TYPE gnatsd_varz_leafnodes gauge
gnatsd_varz_leafnodes{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_max_connections max_connections
# TYPE gnatsd_varz_max_connections gauge
gnatsd_varz_max_connections{server_id="http://127.0.0.1:8292"} 65536
# HELP gnatsd_varz_max_control_line max_control_line
# TYPE gnatsd_varz_max_control_line gauge
gnatsd_varz_max_control_line{server_id="http://127.0.0.1:8292"} 4096
# HELP gnatsd_varz_max_payload max_payload
# TYPE gnatsd_varz_max_payload gauge
gnatsd_varz_max_payload{server_id="http://127.0.0.1:8292"} 1.048576e+06
# HELP gnatsd_varz_max_pending max_pending
# TYPE gnatsd_varz_max_pending gauge
gnatsd_varz_max_pending{server_id="http://127.0.0.1:8292"} 6.7108864e+07
# HELP gnatsd_varz_mem mem
# TYPE gnatsd_varz_mem gauge
gnatsd_varz_mem{server_id="http://127.0.0.1:8292"} 3.0212096e+07
# HELP gnatsd_varz_out_bytes out_bytes
# TYPE gnatsd_varz_out_bytes gauge
gnatsd_varz_out_bytes{server_id="http://127.0.0.1:8292"} 274059
# HELP gnatsd_varz_out_client_bytes out_client_bytes
# TYPE gnatsd_varz_out_client_bytes gauge
gnatsd_varz_out_client_bytes{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_out_client_msgs out_client_msgs
# TYPE gnatsd_varz_out_client_msgs gauge
gnatsd_varz_out_client_msgs{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_out_msgs out_msgs
# TYPE gnatsd_varz_out_msgs gauge
gnatsd_varz_out_msgs{server_id="http://127.0.0.1:8292"} 1903
# HELP gnatsd_varz_ping_interval ping_interval
# TYPE gnatsd_varz_ping_interval gauge
gnatsd_varz_ping_interval{server_id="http://127.0.0.1:8292"} 1.2e+11
# HELP gnatsd_varz_ping_max ping_max
# TYPE gnatsd_varz_ping_max gauge
gnatsd_varz_ping_max{server_id="http://127.0.0.1:8292"} 2
# HELP gnatsd_varz_port port
# TYPE gnatsd_varz_port gauge
gnatsd_varz_port{server_id="http://127.0.0.1:8292"} 4292
# HELP gnatsd_varz_proto proto
# TYPE gnatsd_varz_proto gauge
gnatsd_varz_proto{server_id="http://127.0.0.1:8292"} 1
# HELP gnatsd_varz_remotes remotes
# TYPE gnatsd_varz_remotes gauge
gnatsd_varz_remotes{server_id="http://127.0.0.1:8292"} 2
# HELP gnatsd_varz_routes routes
# TYPE gnatsd_varz_routes gauge
gnatsd_varz_routes{server_id="http://127.0.0.1:8292"} 8
# HELP gnatsd_varz_server_id server_id
# TYPE gnatsd_varz_server_id gauge
gnatsd_varz_server_id{server_id="http://127.0.0.1:8292",value="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO"} 1
# HELP gnatsd_varz_server_name server_name
# TYPE gnatsd_varz_server_name gauge
gnatsd_varz_server_name{server_id="http://127.0.0.1:8292",value="n2"} 1
# HELP gnatsd_varz_slow_consumer_stats_clients slow_consumer_stats_clients
# TYPE gnatsd_varz_slow_consumer_stats_clients gauge
gnatsd_varz_slow_consumer_stats_clients{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_slow_consumer_stats_gateways slow_consumer_stats_gateways
# TYPE gnatsd_varz_slow_consumer_stats_gateways gauge
gnatsd_varz_slow_consumer_stats_gateways{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_slow_consumer_stats_leafs slow_consumer_stats_leafs
# TYPE gnatsd_varz_slow_consumer_stats_leafs gauge
gnatsd_varz_slow_consumer_stats_leafs{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_slow_consumer_stats_routes slow_consumer_stats_routes
# TYPE gnatsd_varz_slow_consumer_stats_routes gauge
gnatsd_varz_slow_consumer_stats_routes{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_slow_consumers slow_consumers
# TYPE gnatsd_varz_slow_consumers gauge
gnatsd_varz_slow_consumers{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_stale_connection_stats_clients stale_connection_stats_clients
# TYPE gnatsd_varz_stale_connection_stats_clients gauge
gnatsd_varz_stale_connection_stats_clients{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_stale_connection_stats_gateways stale_connection_stats_gateways
# TYPE gnatsd_varz_stale_connection_stats_gateways gauge
gnatsd_varz_stale_connection_stats_gateways{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_stale_connection_stats_leafs stale_connection_stats_leafs
# TYPE gnatsd_varz_stale_connection_stats_leafs gauge
gnatsd_varz_stale_connection_stats_leafs{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_stale_connection_stats_routes stale_connection_stats_routes
# TYPE gnatsd_varz_stale_connection_stats_routes gauge
gnatsd_varz_stale_connection_stats_routes{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_stale_connections stale_connections
# TYPE gnatsd_varz_stale_connections gauge
gnatsd_varz_stale_connections{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_stalled_clients stalled_clients
# TYPE gnatsd_varz_stalled_clients gauge
gnatsd_varz_stalled_clients{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_start start
# TYPE gnatsd_varz_start gauge
gnatsd_varz_start{server_id="http://127.0.0.1:8292"} 1.788403202356e+12
# HELP gnatsd_varz_subscriptions subscriptions
# TYPE gnatsd_varz_subscriptions gauge
gnatsd_varz_subscriptions{server_id="http://127.0.0.1:8292"} 260
# HELP gnatsd_varz_tls_timeout tls_timeout
# TYPE gnatsd_varz_tls_timeout gauge
gnatsd_varz_tls_timeout{server_id="http://127.0.0.1:8292"} 2
# HELP gnatsd_varz_total_connections total_connections
# TYPE gnatsd_varz_total_connections gauge
gnatsd_varz_total_connections{server_id="http://127.0.0.1:8292"} 0
# HELP gnatsd_varz_version version
# TYPE gnatsd_varz_version gauge
gnatsd_varz_version{server_id="http://127.0.0.1:8292",value="2.14.6"} 1
# HELP gnatsd_varz_write_deadline write_deadline
# TYPE gnatsd_varz_write_deadline gauge
gnatsd_varz_write_deadline{server_id="http://127.0.0.1:8292"} 1e+10
# HELP jetstream_account_max_memory JetStream Account Max Memory in bytes
# TYPE jetstream_account_max_memory gauge
jetstream_account_max_memory{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2"} 1.8446744073709552e+19
# HELP jetstream_account_max_storage JetStream Account Max Storage in bytes
# TYPE jetstream_account_max_storage gauge
jetstream_account_max_storage{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2"} 1.8446744073709552e+19
# HELP jetstream_account_memory_used Total number of bytes used by JetStream memory
# TYPE jetstream_account_memory_used gauge
jetstream_account_memory_used{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2"} 0
# HELP jetstream_account_storage_used Total number of bytes used by JetStream storage
# TYPE jetstream_account_storage_used gauge
jetstream_account_storage_used{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2"} 9006
# HELP jetstream_consumer_ack_floor_consumer_seq Number of ack floor consumer seq from a consumer
# TYPE jetstream_consumer_ack_floor_consumer_seq gauge
jetstream_consumer_ack_floor_consumer_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="true",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP jetstream_consumer_ack_floor_stream_seq Number of ack floor stream seq from a consumer
# TYPE jetstream_consumer_ack_floor_stream_seq gauge
jetstream_consumer_ack_floor_stream_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="true",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP jetstream_consumer_delivered_consumer_seq Latest sequence number of a stream consumer
# TYPE jetstream_consumer_delivered_consumer_seq gauge
jetstream_consumer_delivered_consumer_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="true",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 21
# HELP jetstream_consumer_delivered_stream_seq Latest sequence number of a stream
# TYPE jetstream_consumer_delivered_stream_seq gauge
jetstream_consumer_delivered_stream_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="true",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 10
# HELP jetstream_consumer_last_ack_seconds Seconds since last ack from consumer
# TYPE jetstream_consumer_last_ack_seconds gauge
jetstream_consumer_last_ack_seconds{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="true",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0.245671
# HELP jetstream_consumer_last_delivery_seconds Seconds since last message delivery to consumer
# TYPE jetstream_consumer_last_delivery_seconds gauge
jetstream_consumer_last_delivery_seconds{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="true",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0.246041
# HELP jetstream_consumer_num_ack_pending Number of pending acks from a consumer
# TYPE jetstream_consumer_num_ack_pending gauge
jetstream_consumer_num_ack_pending{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="true",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 9
# HELP jetstream_consumer_num_pending Number of pending messages from a consumer
# TYPE jetstream_consumer_num_pending gauge
jetstream_consumer_num_pending{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="true",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 20
# HELP jetstream_consumer_num_redelivered Number of redelivered messages from a consumer
# TYPE jetstream_consumer_num_redelivered gauge
jetstream_consumer_num_redelivered{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="true",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 9
# HELP jetstream_consumer_num_waiting Number of inflight fetch requests from a pull consumer
# TYPE jetstream_consumer_num_waiting gauge
jetstream_consumer_num_waiting{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="true",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0
# HELP jetstream_server_jetstream_disabled JetStream disabled or not
# TYPE jetstream_server_jetstream_disabled gauge
jetstream_server_jetstream_disabled{cluster="east",domain="",is_meta_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2"} 0
# HELP jetstream_server_max_memory JetStream Max Memory
# TYPE jetstream_server_max_memory gauge
jetstream_server_max_memory{cluster="east",domain="",is_meta_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2"} 2.5769803776e+10
# HELP jetstream_server_max_storage JetStream Max Storage
# TYPE jetstream_server_max_storage gauge
jetstream_server_max_storage{cluster="east",domain="",is_meta_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2"} 7.4242679808e+10
# HELP jetstream_server_total_consumers Total number of consumers in JetStream
# TYPE jetstream_server_total_consumers gauge
jetstream_server_total_consumers{cluster="east",domain="",is_meta_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2"} 1
# HELP jetstream_server_total_message_bytes Total number of bytes stored in JetStream
# TYPE jetstream_server_total_message_bytes gauge
jetstream_server_total_message_bytes{cluster="east",domain="",is_meta_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2"} 6144
# HELP jetstream_server_total_messages Total number of stored messages in JetStream
# TYPE jetstream_server_total_messages gauge
jetstream_server_total_messages{cluster="east",domain="",is_meta_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2"} 90
# HELP jetstream_server_total_streams Total number of streams in JetStream
# TYPE jetstream_server_total_streams gauge
jetstream_server_total_streams{cluster="east",domain="",is_meta_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2"} 3
# HELP jetstream_stream_consumer_count Total number of consumers from a stream
# TYPE jetstream_stream_consumer_count gauge
jetstream_stream_consumer_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
jetstream_stream_consumer_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_AGG",stream_raft_group="S-R1F-4xqNIVlf"} 0
jetstream_stream_consumer_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_MIRROR",stream_raft_group="S-R1F-Cp5pI54v"} 0
# HELP jetstream_stream_first_seq First sequence from a stream
# TYPE jetstream_stream_first_seq gauge
jetstream_stream_first_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
jetstream_stream_first_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_AGG",stream_raft_group="S-R1F-4xqNIVlf"} 1
jetstream_stream_first_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_MIRROR",stream_raft_group="S-R1F-Cp5pI54v"} 1
# HELP jetstream_stream_last_seq Last sequence from a stream
# TYPE jetstream_stream_last_seq gauge
jetstream_stream_last_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 30
jetstream_stream_last_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_AGG",stream_raft_group="S-R1F-4xqNIVlf"} 30
jetstream_stream_last_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_MIRROR",stream_raft_group="S-R1F-Cp5pI54v"} 30
# HELP jetstream_stream_limit_bytes The maximum configured storage limit (in bytes) for a JetStream stream. A value of -1 indicates no limit.
# TYPE jetstream_stream_limit_bytes gauge
jetstream_stream_limit_bytes{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} -1
jetstream_stream_limit_bytes{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_AGG",stream_raft_group="S-R1F-4xqNIVlf"} -1
jetstream_stream_limit_bytes{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_MIRROR",stream_raft_group="S-R1F-Cp5pI54v"} -1
# HELP jetstream_stream_limit_messages The maximum number of messages allowed in a JetStream stream as per its configuration. A value of -1 indicates no limit.
# TYPE jetstream_stream_limit_messages gauge
jetstream_stream_limit_messages{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} -1
jetstream_stream_limit_messages{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_AGG",stream_raft_group="S-R1F-4xqNIVlf"} -1
jetstream_stream_limit_messages{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_MIRROR",stream_raft_group="S-R1F-Cp5pI54v"} -1
# HELP jetstream_stream_mirror_active_duration_ns Stream mirror active duration in nanoseconds (-1 indicates inactive)
# TYPE jetstream_stream_mirror_active_duration_ns gauge
jetstream_stream_mirror_active_duration_ns{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",mirror_api="",mirror_deliver="",mirror_name="ORDERS",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_MIRROR",stream_raft_group="S-R1F-Cp5pI54v"} 8.44315e+08
# HELP jetstream_stream_mirror_lag Number of messages a stream mirror is behind
# TYPE jetstream_stream_mirror_lag gauge
jetstream_stream_mirror_lag{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",mirror_api="",mirror_deliver="",mirror_name="ORDERS",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_MIRROR",stream_raft_group="S-R1F-Cp5pI54v"} 0
# HELP jetstream_stream_source_active_duration_ns Stream source active duration in nanoseconds (-1 indicates inactive)
# TYPE jetstream_stream_source_active_duration_ns gauge
jetstream_stream_source_active_duration_ns{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",source_api="",source_deliver="",source_name="ORDERS",stream_leader="n2",stream_name="ORDERS_AGG",stream_raft_group="S-R1F-4xqNIVlf"} 7.79108e+08
# HELP jetstream_stream_source_lag Number of messages a stream source is behind
# TYPE jetstream_stream_source_lag gauge
jetstream_stream_source_lag{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",source_api="",source_deliver="",source_name="ORDERS",stream_leader="n2",stream_name="ORDERS_AGG",stream_raft_group="S-R1F-4xqNIVlf"} 0
# HELP jetstream_stream_subject_count Total number of subjects in a stream
# TYPE jetstream_stream_subject_count gauge
jetstream_stream_subject_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
jetstream_stream_subject_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_AGG",stream_raft_group="S-R1F-4xqNIVlf"} 1
jetstream_stream_subject_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_MIRROR",stream_raft_group="S-R1F-Cp5pI54v"} 1
# HELP jetstream_stream_total_bytes Total stored bytes from a stream
# TYPE jetstream_stream_total_bytes gauge
jetstream_stream_total_bytes{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1431
jetstream_stream_total_bytes{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_AGG",stream_raft_group="S-R1F-4xqNIVlf"} 3282
jetstream_stream_total_bytes{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_MIRROR",stream_raft_group="S-R1F-Cp5pI54v"} 1431
# HELP jetstream_stream_total_messages Total number of messages from a stream
# TYPE jetstream_stream_total_messages gauge
jetstream_stream_total_messages{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 30
jetstream_stream_total_messages{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_AGG",stream_raft_group="S-R1F-4xqNIVlf"} 30
jetstream_stream_total_messages{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="false",is_stream_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8292",server_name="n2",stream_leader="n2",stream_name="ORDERS_MIRROR",stream_raft_group="S-R1F-Cp5pI54v"} 30

[http 200]
```


## Run H1-n1 · after one ack: node n1 again

```
$ prometheus-nats-exporter -varz -jsz=all -port 7777 http://127.0.0.1:8291
```

Exporter log (first lines):

```
[24554] 2026/09/03 04:45:20.306508 [INF] Prometheus exporter listening at http://0.0.0.0:7777/metrics
```

Scrape of `http://127.0.0.1:7777/metrics` — 113 `# HELP` lines kept, 38 `go_*`/`process_*`/`promhttp_*` series (122 lines) dropped:

```
# HELP gnatsd_varz_auth_timeout auth_timeout
# TYPE gnatsd_varz_auth_timeout gauge
gnatsd_varz_auth_timeout{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_cluster_name cluster_name
# TYPE gnatsd_varz_cluster_name gauge
gnatsd_varz_cluster_name{server_id="http://127.0.0.1:8291",value="east"} 1
# HELP gnatsd_varz_cluster_pool_size cluster_pool_size
# TYPE gnatsd_varz_cluster_pool_size gauge
gnatsd_varz_cluster_pool_size{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_varz_config_load_time config_load_time
# TYPE gnatsd_varz_config_load_time gauge
gnatsd_varz_config_load_time{server_id="http://127.0.0.1:8291"} 1.788403202188e+12
# HELP gnatsd_varz_connections connections
# TYPE gnatsd_varz_connections gauge
gnatsd_varz_connections{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_cores cores
# TYPE gnatsd_varz_cores gauge
gnatsd_varz_cores{server_id="http://127.0.0.1:8291"} 10
# HELP gnatsd_varz_cpu cpu
# TYPE gnatsd_varz_cpu gauge
gnatsd_varz_cpu{server_id="http://127.0.0.1:8291"} 0.5
# HELP gnatsd_varz_disk_io_wait_stats_max_wait_time disk_io_wait_stats_max_wait_time
# TYPE gnatsd_varz_disk_io_wait_stats_max_wait_time gauge
gnatsd_varz_disk_io_wait_stats_max_wait_time{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_disk_io_wait_stats_wait_time disk_io_wait_stats_wait_time
# TYPE gnatsd_varz_disk_io_wait_stats_wait_time gauge
gnatsd_varz_disk_io_wait_stats_wait_time{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_disk_io_wait_stats_waiters disk_io_wait_stats_waiters
# TYPE gnatsd_varz_disk_io_wait_stats_waiters gauge
gnatsd_varz_disk_io_wait_stats_waiters{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_disk_io_wait_stats_waits disk_io_wait_stats_waits
# TYPE gnatsd_varz_disk_io_wait_stats_waits gauge
gnatsd_varz_disk_io_wait_stats_waits{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_gomaxprocs gomaxprocs
# TYPE gnatsd_varz_gomaxprocs gauge
gnatsd_varz_gomaxprocs{server_id="http://127.0.0.1:8291"} 10
# HELP gnatsd_varz_http_port http_port
# TYPE gnatsd_varz_http_port gauge
gnatsd_varz_http_port{server_id="http://127.0.0.1:8291"} 8291
# HELP gnatsd_varz_http_req_stats_accountz http_req_stats_accountz
# TYPE gnatsd_varz_http_req_stats_accountz gauge
gnatsd_varz_http_req_stats_accountz{server_id="http://127.0.0.1:8291"} 12
# HELP gnatsd_varz_http_req_stats_accstatz http_req_stats_accstatz
# TYPE gnatsd_varz_http_req_stats_accstatz gauge
gnatsd_varz_http_req_stats_accstatz{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_http_req_stats_connz http_req_stats_connz
# TYPE gnatsd_varz_http_req_stats_connz gauge
gnatsd_varz_http_req_stats_connz{server_id="http://127.0.0.1:8291"} 7
# HELP gnatsd_varz_http_req_stats_gatewayz http_req_stats_gatewayz
# TYPE gnatsd_varz_http_req_stats_gatewayz gauge
gnatsd_varz_http_req_stats_gatewayz{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_http_req_stats_healthz http_req_stats_healthz
# TYPE gnatsd_varz_http_req_stats_healthz gauge
gnatsd_varz_http_req_stats_healthz{server_id="http://127.0.0.1:8291"} 13
# HELP gnatsd_varz_http_req_stats_jsz http_req_stats_jsz
# TYPE gnatsd_varz_http_req_stats_jsz gauge
gnatsd_varz_http_req_stats_jsz{server_id="http://127.0.0.1:8291"} 12
# HELP gnatsd_varz_http_req_stats_leafz http_req_stats_leafz
# TYPE gnatsd_varz_http_req_stats_leafz gauge
gnatsd_varz_http_req_stats_leafz{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_http_req_stats_routez http_req_stats_routez
# TYPE gnatsd_varz_http_req_stats_routez gauge
gnatsd_varz_http_req_stats_routez{server_id="http://127.0.0.1:8291"} 6
# HELP gnatsd_varz_http_req_stats_subsz http_req_stats_subsz
# TYPE gnatsd_varz_http_req_stats_subsz gauge
gnatsd_varz_http_req_stats_subsz{server_id="http://127.0.0.1:8291"} 6
# HELP gnatsd_varz_http_req_stats_varz http_req_stats_varz
# TYPE gnatsd_varz_http_req_stats_varz gauge
gnatsd_varz_http_req_stats_varz{server_id="http://127.0.0.1:8291"} 29
# HELP gnatsd_varz_https_port https_port
# TYPE gnatsd_varz_https_port gauge
gnatsd_varz_https_port{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_in_bytes in_bytes
# TYPE gnatsd_varz_in_bytes gauge
gnatsd_varz_in_bytes{server_id="http://127.0.0.1:8291"} 286350
# HELP gnatsd_varz_in_client_bytes in_client_bytes
# TYPE gnatsd_varz_in_client_bytes gauge
gnatsd_varz_in_client_bytes{server_id="http://127.0.0.1:8291"} 4057
# HELP gnatsd_varz_in_client_msgs in_client_msgs
# TYPE gnatsd_varz_in_client_msgs gauge
gnatsd_varz_in_client_msgs{server_id="http://127.0.0.1:8291"} 89
# HELP gnatsd_varz_in_msgs in_msgs
# TYPE gnatsd_varz_in_msgs gauge
gnatsd_varz_in_msgs{server_id="http://127.0.0.1:8291"} 1761
# HELP gnatsd_varz_jetstream_config_max_memory jetstream_config_max_memory
# TYPE gnatsd_varz_jetstream_config_max_memory gauge
gnatsd_varz_jetstream_config_max_memory{server_id="http://127.0.0.1:8291"} 2.5769803776e+10
# HELP gnatsd_varz_jetstream_config_max_storage jetstream_config_max_storage
# TYPE gnatsd_varz_jetstream_config_max_storage gauge
gnatsd_varz_jetstream_config_max_storage{server_id="http://127.0.0.1:8291"} 7.424265216e+10
# HELP gnatsd_varz_jetstream_config_sync_interval jetstream_config_sync_interval
# TYPE gnatsd_varz_jetstream_config_sync_interval gauge
gnatsd_varz_jetstream_config_sync_interval{server_id="http://127.0.0.1:8291"} 1.2e+11
# HELP gnatsd_varz_jetstream_meta_cluster_size jetstream_meta_cluster_size
# TYPE gnatsd_varz_jetstream_meta_cluster_size gauge
gnatsd_varz_jetstream_meta_cluster_size{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_varz_jetstream_meta_leader jetstream_meta_leader
# TYPE gnatsd_varz_jetstream_meta_leader gauge
gnatsd_varz_jetstream_meta_leader{server_id="http://127.0.0.1:8291",value="n1"} 1
# HELP gnatsd_varz_jetstream_meta_name jetstream_meta_name
# TYPE gnatsd_varz_jetstream_meta_name gauge
gnatsd_varz_jetstream_meta_name{server_id="http://127.0.0.1:8291",value="east"} 1
# HELP gnatsd_varz_jetstream_meta_pending jetstream_meta_pending
# TYPE gnatsd_varz_jetstream_meta_pending gauge
gnatsd_varz_jetstream_meta_pending{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_meta_pending_infos jetstream_meta_pending_infos
# TYPE gnatsd_varz_jetstream_meta_pending_infos gauge
gnatsd_varz_jetstream_meta_pending_infos{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_meta_pending_requests jetstream_meta_pending_requests
# TYPE gnatsd_varz_jetstream_meta_pending_requests gauge
gnatsd_varz_jetstream_meta_pending_requests{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_meta_snapshot_last_duration jetstream_meta_snapshot_last_duration
# TYPE gnatsd_varz_jetstream_meta_snapshot_last_duration gauge
gnatsd_varz_jetstream_meta_snapshot_last_duration{server_id="http://127.0.0.1:8291"} 233875
# HELP gnatsd_varz_jetstream_meta_snapshot_pending_entries jetstream_meta_snapshot_pending_entries
# TYPE gnatsd_varz_jetstream_meta_snapshot_pending_entries gauge
gnatsd_varz_jetstream_meta_snapshot_pending_entries{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_meta_snapshot_pending_size jetstream_meta_snapshot_pending_size
# TYPE gnatsd_varz_jetstream_meta_snapshot_pending_size gauge
gnatsd_varz_jetstream_meta_snapshot_pending_size{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_stats_accounts jetstream_stats_accounts
# TYPE gnatsd_varz_jetstream_stats_accounts gauge
gnatsd_varz_jetstream_stats_accounts{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_varz_jetstream_stats_api_errors jetstream_stats_api_errors
# TYPE gnatsd_varz_jetstream_stats_api_errors gauge
gnatsd_varz_jetstream_stats_api_errors{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_varz_jetstream_stats_api_level jetstream_stats_api_level
# TYPE gnatsd_varz_jetstream_stats_api_level gauge
gnatsd_varz_jetstream_stats_api_level{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_jetstream_stats_api_total jetstream_stats_api_total
# TYPE gnatsd_varz_jetstream_stats_api_total gauge
gnatsd_varz_jetstream_stats_api_total{server_id="http://127.0.0.1:8291"} 4
# HELP gnatsd_varz_jetstream_stats_ha_assets jetstream_stats_ha_assets
# TYPE gnatsd_varz_jetstream_stats_ha_assets gauge
gnatsd_varz_jetstream_stats_ha_assets{server_id="http://127.0.0.1:8291"} 3
# HELP gnatsd_varz_jetstream_stats_memory jetstream_stats_memory
# TYPE gnatsd_varz_jetstream_stats_memory gauge
gnatsd_varz_jetstream_stats_memory{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_stats_reserved_memory jetstream_stats_reserved_memory
# TYPE gnatsd_varz_jetstream_stats_reserved_memory gauge
gnatsd_varz_jetstream_stats_reserved_memory{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_stats_reserved_storage jetstream_stats_reserved_storage
# TYPE gnatsd_varz_jetstream_stats_reserved_storage gauge
gnatsd_varz_jetstream_stats_reserved_storage{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_jetstream_stats_storage jetstream_stats_storage
# TYPE gnatsd_varz_jetstream_stats_storage gauge
gnatsd_varz_jetstream_stats_storage{server_id="http://127.0.0.1:8291"} 1431
# HELP gnatsd_varz_leafnodes leafnodes
# TYPE gnatsd_varz_leafnodes gauge
gnatsd_varz_leafnodes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_max_connections max_connections
# TYPE gnatsd_varz_max_connections gauge
gnatsd_varz_max_connections{server_id="http://127.0.0.1:8291"} 65536
# HELP gnatsd_varz_max_control_line max_control_line
# TYPE gnatsd_varz_max_control_line gauge
gnatsd_varz_max_control_line{server_id="http://127.0.0.1:8291"} 4096
# HELP gnatsd_varz_max_payload max_payload
# TYPE gnatsd_varz_max_payload gauge
gnatsd_varz_max_payload{server_id="http://127.0.0.1:8291"} 1.048576e+06
# HELP gnatsd_varz_max_pending max_pending
# TYPE gnatsd_varz_max_pending gauge
gnatsd_varz_max_pending{server_id="http://127.0.0.1:8291"} 6.7108864e+07
# HELP gnatsd_varz_mem mem
# TYPE gnatsd_varz_mem gauge
gnatsd_varz_mem{server_id="http://127.0.0.1:8291"} 3.088384e+07
# HELP gnatsd_varz_out_bytes out_bytes
# TYPE gnatsd_varz_out_bytes gauge
gnatsd_varz_out_bytes{server_id="http://127.0.0.1:8291"} 349372
# HELP gnatsd_varz_out_client_bytes out_client_bytes
# TYPE gnatsd_varz_out_client_bytes gauge
gnatsd_varz_out_client_bytes{server_id="http://127.0.0.1:8291"} 110556
# HELP gnatsd_varz_out_client_msgs out_client_msgs
# TYPE gnatsd_varz_out_client_msgs gauge
gnatsd_varz_out_client_msgs{server_id="http://127.0.0.1:8291"} 102
# HELP gnatsd_varz_out_msgs out_msgs
# TYPE gnatsd_varz_out_msgs gauge
gnatsd_varz_out_msgs{server_id="http://127.0.0.1:8291"} 1830
# HELP gnatsd_varz_ping_interval ping_interval
# TYPE gnatsd_varz_ping_interval gauge
gnatsd_varz_ping_interval{server_id="http://127.0.0.1:8291"} 1.2e+11
# HELP gnatsd_varz_ping_max ping_max
# TYPE gnatsd_varz_ping_max gauge
gnatsd_varz_ping_max{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_port port
# TYPE gnatsd_varz_port gauge
gnatsd_varz_port{server_id="http://127.0.0.1:8291"} 4291
# HELP gnatsd_varz_proto proto
# TYPE gnatsd_varz_proto gauge
gnatsd_varz_proto{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_varz_remotes remotes
# TYPE gnatsd_varz_remotes gauge
gnatsd_varz_remotes{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_routes routes
# TYPE gnatsd_varz_routes gauge
gnatsd_varz_routes{server_id="http://127.0.0.1:8291"} 8
# HELP gnatsd_varz_server_id server_id
# TYPE gnatsd_varz_server_id gauge
gnatsd_varz_server_id{server_id="http://127.0.0.1:8291",value="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S"} 1
# HELP gnatsd_varz_server_name server_name
# TYPE gnatsd_varz_server_name gauge
gnatsd_varz_server_name{server_id="http://127.0.0.1:8291",value="n1"} 1
# HELP gnatsd_varz_slow_consumer_stats_clients slow_consumer_stats_clients
# TYPE gnatsd_varz_slow_consumer_stats_clients gauge
gnatsd_varz_slow_consumer_stats_clients{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumer_stats_gateways slow_consumer_stats_gateways
# TYPE gnatsd_varz_slow_consumer_stats_gateways gauge
gnatsd_varz_slow_consumer_stats_gateways{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumer_stats_leafs slow_consumer_stats_leafs
# TYPE gnatsd_varz_slow_consumer_stats_leafs gauge
gnatsd_varz_slow_consumer_stats_leafs{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumer_stats_routes slow_consumer_stats_routes
# TYPE gnatsd_varz_slow_consumer_stats_routes gauge
gnatsd_varz_slow_consumer_stats_routes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_slow_consumers slow_consumers
# TYPE gnatsd_varz_slow_consumers gauge
gnatsd_varz_slow_consumers{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_clients stale_connection_stats_clients
# TYPE gnatsd_varz_stale_connection_stats_clients gauge
gnatsd_varz_stale_connection_stats_clients{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_gateways stale_connection_stats_gateways
# TYPE gnatsd_varz_stale_connection_stats_gateways gauge
gnatsd_varz_stale_connection_stats_gateways{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_leafs stale_connection_stats_leafs
# TYPE gnatsd_varz_stale_connection_stats_leafs gauge
gnatsd_varz_stale_connection_stats_leafs{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connection_stats_routes stale_connection_stats_routes
# TYPE gnatsd_varz_stale_connection_stats_routes gauge
gnatsd_varz_stale_connection_stats_routes{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stale_connections stale_connections
# TYPE gnatsd_varz_stale_connections gauge
gnatsd_varz_stale_connections{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_stalled_clients stalled_clients
# TYPE gnatsd_varz_stalled_clients gauge
gnatsd_varz_stalled_clients{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_varz_start start
# TYPE gnatsd_varz_start gauge
gnatsd_varz_start{server_id="http://127.0.0.1:8291"} 1.788403202188e+12
# HELP gnatsd_varz_subscriptions subscriptions
# TYPE gnatsd_varz_subscriptions gauge
gnatsd_varz_subscriptions{server_id="http://127.0.0.1:8291"} 258
# HELP gnatsd_varz_tls_timeout tls_timeout
# TYPE gnatsd_varz_tls_timeout gauge
gnatsd_varz_tls_timeout{server_id="http://127.0.0.1:8291"} 2
# HELP gnatsd_varz_total_connections total_connections
# TYPE gnatsd_varz_total_connections gauge
gnatsd_varz_total_connections{server_id="http://127.0.0.1:8291"} 14
# HELP gnatsd_varz_version version
# TYPE gnatsd_varz_version gauge
gnatsd_varz_version{server_id="http://127.0.0.1:8291",value="2.14.6"} 1
# HELP gnatsd_varz_write_deadline write_deadline
# TYPE gnatsd_varz_write_deadline gauge
gnatsd_varz_write_deadline{server_id="http://127.0.0.1:8291"} 1e+10
# HELP jetstream_account_max_memory JetStream Account Max Memory in bytes
# TYPE jetstream_account_max_memory gauge
jetstream_account_max_memory{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1.8446744073709552e+19
# HELP jetstream_account_max_storage JetStream Account Max Storage in bytes
# TYPE jetstream_account_max_storage gauge
jetstream_account_max_storage{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1.8446744073709552e+19
# HELP jetstream_account_memory_used Total number of bytes used by JetStream memory
# TYPE jetstream_account_memory_used gauge
jetstream_account_memory_used{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 0
# HELP jetstream_account_storage_used Total number of bytes used by JetStream storage
# TYPE jetstream_account_storage_used gauge
jetstream_account_storage_used{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 9006
# HELP jetstream_consumer_ack_floor_consumer_seq Number of ack floor consumer seq from a consumer
# TYPE jetstream_consumer_ack_floor_consumer_seq gauge
jetstream_consumer_ack_floor_consumer_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP jetstream_consumer_ack_floor_stream_seq Number of ack floor stream seq from a consumer
# TYPE jetstream_consumer_ack_floor_stream_seq gauge
jetstream_consumer_ack_floor_stream_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP jetstream_consumer_delivered_consumer_seq Latest sequence number of a stream consumer
# TYPE jetstream_consumer_delivered_consumer_seq gauge
jetstream_consumer_delivered_consumer_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 21
# HELP jetstream_consumer_delivered_stream_seq Latest sequence number of a stream
# TYPE jetstream_consumer_delivered_stream_seq gauge
jetstream_consumer_delivered_stream_seq{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 10
# HELP jetstream_consumer_last_ack_seconds Seconds since last ack from consumer
# TYPE jetstream_consumer_last_ack_seconds gauge
jetstream_consumer_last_ack_seconds{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0.269232
# HELP jetstream_consumer_last_delivery_seconds Seconds since last message delivery to consumer
# TYPE jetstream_consumer_last_delivery_seconds gauge
jetstream_consumer_last_delivery_seconds{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0.269628
# HELP jetstream_consumer_num_ack_pending Number of pending acks from a consumer
# TYPE jetstream_consumer_num_ack_pending gauge
jetstream_consumer_num_ack_pending{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 9
# HELP jetstream_consumer_num_pending Number of pending messages from a consumer
# TYPE jetstream_consumer_num_pending gauge
jetstream_consumer_num_pending{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0
# HELP jetstream_consumer_num_redelivered Number of redelivered messages from a consumer
# TYPE jetstream_consumer_num_redelivered gauge
jetstream_consumer_num_redelivered{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 9
# HELP jetstream_consumer_num_waiting Number of inflight fetch requests from a pull consumer
# TYPE jetstream_consumer_num_waiting gauge
jetstream_consumer_num_waiting{account="$G",account_id="$G",account_name="$G",cluster="east",consumer_desc="",consumer_leader="n2",consumer_name="shipping",domain="",is_consumer_leader="false",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 0
# HELP jetstream_server_jetstream_disabled JetStream disabled or not
# TYPE jetstream_server_jetstream_disabled gauge
jetstream_server_jetstream_disabled{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 0
# HELP jetstream_server_max_memory JetStream Max Memory
# TYPE jetstream_server_max_memory gauge
jetstream_server_max_memory{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 2.5769803776e+10
# HELP jetstream_server_max_storage JetStream Max Storage
# TYPE jetstream_server_max_storage gauge
jetstream_server_max_storage{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 7.424265216e+10
# HELP jetstream_server_total_consumers Total number of consumers in JetStream
# TYPE jetstream_server_total_consumers gauge
jetstream_server_total_consumers{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1
# HELP jetstream_server_total_message_bytes Total number of bytes stored in JetStream
# TYPE jetstream_server_total_message_bytes gauge
jetstream_server_total_message_bytes{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1431
# HELP jetstream_server_total_messages Total number of stored messages in JetStream
# TYPE jetstream_server_total_messages gauge
jetstream_server_total_messages{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 30
# HELP jetstream_server_total_streams Total number of streams in JetStream
# TYPE jetstream_server_total_streams gauge
jetstream_server_total_streams{cluster="east",domain="",is_meta_leader="true",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1"} 1
# HELP jetstream_stream_consumer_count Total number of consumers from a stream
# TYPE jetstream_stream_consumer_count gauge
jetstream_stream_consumer_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP jetstream_stream_first_seq First sequence from a stream
# TYPE jetstream_stream_first_seq gauge
jetstream_stream_first_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP jetstream_stream_last_seq Last sequence from a stream
# TYPE jetstream_stream_last_seq gauge
jetstream_stream_last_seq{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 30
# HELP jetstream_stream_limit_bytes The maximum configured storage limit (in bytes) for a JetStream stream. A value of -1 indicates no limit.
# TYPE jetstream_stream_limit_bytes gauge
jetstream_stream_limit_bytes{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} -1
# HELP jetstream_stream_limit_messages The maximum number of messages allowed in a JetStream stream as per its configuration. A value of -1 indicates no limit.
# TYPE jetstream_stream_limit_messages gauge
jetstream_stream_limit_messages{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} -1
# HELP jetstream_stream_subject_count Total number of subjects in a stream
# TYPE jetstream_stream_subject_count gauge
jetstream_stream_subject_count{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1
# HELP jetstream_stream_total_bytes Total stored bytes from a stream
# TYPE jetstream_stream_total_bytes gauge
jetstream_stream_total_bytes{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 1431
# HELP jetstream_stream_total_messages Total number of messages from a stream
# TYPE jetstream_stream_total_messages gauge
jetstream_stream_total_messages{account="$G",account_id="$G",account_name="$G",cluster="east",domain="",is_meta_leader="true",is_stream_leader="false",meta_leader="n1",server_id="http://127.0.0.1:8291",server_name="n1",stream_leader="n2",stream_name="ORDERS",stream_raft_group="S-R3F-zHrMNfYE"} 30

[http 200]
```


## Run H2 · `-connz_detailed` with one `nats sub` client connected

```
$ prometheus-nats-exporter -connz_detailed -port 7777 http://127.0.0.1:8291
```

Exporter log (first lines):

```
[24592] 2026/09/03 04:45:21.345807 [INF] Prometheus exporter listening at http://0.0.0.0:7777/metrics
```

Scrape of `http://127.0.0.1:7777/metrics` — 15 `# HELP` lines kept, 38 `go_*`/`process_*`/`promhttp_*` series (122 lines) dropped:

```
# HELP gnatsd_connz_idle idle time duration in milliseconds
# TYPE gnatsd_connz_idle gauge
gnatsd_connz_idle{account="",account_id="",cid="41",ip="127.0.0.1",kind="Client",lang="go",name="NATS CLI Version 0.4.0",name_tag="$G",port="52446",server_id="http://127.0.0.1:8291",tls_cipher_suite="",tls_version="",type="nats",version="1.51.0"} 1000
# HELP gnatsd_connz_in_bytes in_bytes
# TYPE gnatsd_connz_in_bytes counter
gnatsd_connz_in_bytes{server_id="http://127.0.0.1:8291"} 0
gnatsd_connz_in_bytes{account="",account_id="",cid="41",ip="127.0.0.1",kind="Client",lang="go",name="NATS CLI Version 0.4.0",name_tag="$G",port="52446",server_id="http://127.0.0.1:8291",tls_cipher_suite="",tls_version="",type="nats",version="1.51.0"} 0
# HELP gnatsd_connz_in_msgs in_msgs
# TYPE gnatsd_connz_in_msgs counter
gnatsd_connz_in_msgs{server_id="http://127.0.0.1:8291"} 0
gnatsd_connz_in_msgs{account="",account_id="",cid="41",ip="127.0.0.1",kind="Client",lang="go",name="NATS CLI Version 0.4.0",name_tag="$G",port="52446",server_id="http://127.0.0.1:8291",tls_cipher_suite="",tls_version="",type="nats",version="1.51.0"} 0
# HELP gnatsd_connz_last_activity epoch time at which the last activity was registred
# TYPE gnatsd_connz_last_activity untyped
gnatsd_connz_last_activity{account="",account_id="",cid="41",ip="127.0.0.1",kind="Client",lang="go",name="NATS CLI Version 0.4.0",name_tag="$G",port="52446",server_id="http://127.0.0.1:8291",tls_cipher_suite="",tls_version="",type="nats",version="1.51.0"} 1.788403520333e+12
# HELP gnatsd_connz_limit limit
# TYPE gnatsd_connz_limit gauge
gnatsd_connz_limit{server_id="http://127.0.0.1:8291"} 1024
# HELP gnatsd_connz_num_connections num_connections
# TYPE gnatsd_connz_num_connections gauge
gnatsd_connz_num_connections{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_connz_offset offset
# TYPE gnatsd_connz_offset gauge
gnatsd_connz_offset{server_id="http://127.0.0.1:8291"} 0
# HELP gnatsd_connz_out_bytes out_bytes
# TYPE gnatsd_connz_out_bytes counter
gnatsd_connz_out_bytes{server_id="http://127.0.0.1:8291"} 0
gnatsd_connz_out_bytes{account="",account_id="",cid="41",ip="127.0.0.1",kind="Client",lang="go",name="NATS CLI Version 0.4.0",name_tag="$G",port="52446",server_id="http://127.0.0.1:8291",tls_cipher_suite="",tls_version="",type="nats",version="1.51.0"} 0
# HELP gnatsd_connz_out_msgs out_msgs
# TYPE gnatsd_connz_out_msgs counter
gnatsd_connz_out_msgs{server_id="http://127.0.0.1:8291"} 0
gnatsd_connz_out_msgs{account="",account_id="",cid="41",ip="127.0.0.1",kind="Client",lang="go",name="NATS CLI Version 0.4.0",name_tag="$G",port="52446",server_id="http://127.0.0.1:8291",tls_cipher_suite="",tls_version="",type="nats",version="1.51.0"} 0
# HELP gnatsd_connz_pending_bytes pending_bytes
# TYPE gnatsd_connz_pending_bytes gauge
gnatsd_connz_pending_bytes{server_id="http://127.0.0.1:8291"} 0
gnatsd_connz_pending_bytes{account="",account_id="",cid="41",ip="127.0.0.1",kind="Client",lang="go",name="NATS CLI Version 0.4.0",name_tag="$G",port="52446",server_id="http://127.0.0.1:8291",tls_cipher_suite="",tls_version="",type="nats",version="1.51.0"} 0
# HELP gnatsd_connz_rtt response time latency in microseconds
# TYPE gnatsd_connz_rtt gauge
gnatsd_connz_rtt{account="",account_id="",cid="41",ip="127.0.0.1",kind="Client",lang="go",name="NATS CLI Version 0.4.0",name_tag="$G",port="52446",server_id="http://127.0.0.1:8291",tls_cipher_suite="",tls_version="",type="nats",version="1.51.0"} 146
# HELP gnatsd_connz_start epoch time at which the connection was started
# TYPE gnatsd_connz_start untyped
gnatsd_connz_start{account="",account_id="",cid="41",ip="127.0.0.1",kind="Client",lang="go",name="NATS CLI Version 0.4.0",name_tag="$G",port="52446",server_id="http://127.0.0.1:8291",tls_cipher_suite="",tls_version="",type="nats",version="1.51.0"} 1.788403520333e+12
# HELP gnatsd_connz_subscriptions subscriptions
# TYPE gnatsd_connz_subscriptions gauge
gnatsd_connz_subscriptions{server_id="http://127.0.0.1:8291"} 1
gnatsd_connz_subscriptions{account="",account_id="",cid="41",ip="127.0.0.1",kind="Client",lang="go",name="NATS CLI Version 0.4.0",name_tag="$G",port="52446",server_id="http://127.0.0.1:8291",tls_cipher_suite="",tls_version="",type="nats",version="1.51.0"} 1
# HELP gnatsd_connz_total total
# TYPE gnatsd_connz_total gauge
gnatsd_connz_total{server_id="http://127.0.0.1:8291"} 1
# HELP gnatsd_connz_uptime uptime duration in milliseconds
# TYPE gnatsd_connz_uptime untyped
gnatsd_connz_uptime{account="",account_id="",cid="41",ip="127.0.0.1",kind="Client",lang="go",name="NATS CLI Version 0.4.0",name_tag="$G",port="52446",server_id="http://127.0.0.1:8291",tls_cipher_suite="",tls_version="",type="nats",version="1.51.0"} 1000

[http 200]
```


## The endpoint bodies the exporter read (n1, before run A)

`/jsz?consumers=true&config=true&raft=true` — the request `-jsz=all` sends:

```json
{
  "memory": 0,
  "storage": 1431,
  "reserved_memory": 0,
  "reserved_storage": 0,
  "accounts": 1,
  "ha_assets": 3,
  "api": {
    "level": 4,
    "total": 4,
    "errors": 1
  },
  "server_id": "NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",
  "now": "2026-09-03T02:41:51.261724Z",
  "config": {
    "max_memory": 25769803776,
    "max_storage": 74242652160,
    "store_dir": "<lab>/n1/store/jetstream",
    "sync_interval": 120000000000,
    "strict": true
  },
  "limits": {},
  "streams": 1,
  "consumers": 1,
  "messages": 30,
  "bytes": 1431,
  "meta_cluster": {
    "name": "east",
    "leader": "n1",
    "peer": "fjFyEjc1",
    "replicas": [
      {
        "name": "n2",
        "current": true,
        "active": 776787042,
        "peer": "44jzkV9D"
      },
      {
        "name": "n3",
        "current": true,
        "active": 776784667,
        "peer": "BXScrY9i"
      }
    ],
    "cluster_size": 3,
    "pending": 0,
    "pending_requests": 0,
    "pending_infos": 0,
    "snapshot": {
      "pending_entries": 4,
      "pending_size": 4180,
      "last_time": "0001-01-01T00:00:00Z"
    }
  },
  "account_details": [
    {
      "name": "$G",
      "id": "$G",
      "memory": 0,
      "storage": 9006,
      "reserved_memory": 18446744073709551615,
      "reserved_storage": 18446744073709551615,
      "accounts": 0,
      "ha_assets": 0,
      "api": {
        "level": 0,
        "total": 14,
        "errors": 1
      },
      "stream_detail": [
        {
          "name": "ORDERS",
          "created": "2026-09-03T02:41:44.526489Z",
          "cluster": {
            "name": "east",
            "raft_group": "S-R3F-zHrMNfYE",
            "leader": "n2",
            "system_account": true,
            "traffic_account": "$SYS",
            "replicas": [
              {
                "name": "n2",
                "current": true,
                "active": 632022458,
                "peer": "44jzkV9D"
              },
              {
                "name": "n3",
                "current": false,
                "active": 0,
                "peer": "BXScrY9i"
              }
            ]
          },
          "config": {
            "name": "ORDERS",
            "subjects": [
              "orders.\u003e"
            ],
            "retention": "limits",
            "max_consumers": -1,
            "max_msgs": -1,
            "max_bytes": -1,
            "max_age": 0,
            "max_msgs_per_subject": -1,
            "max_msg_size": -1,
            "discard": "old",
            "storage": "file",
            "num_replicas": 3,
            "duplicate_window": 120000000000,
            "compression": "none",
            "allow_direct": true,
            "mirror_direct": false,
            "sealed": false,
            "deny_delete": false,
            "deny_purge": false,
            "allow_rollup_hdrs": false,
            "consumer_limits": {},
            "allow_msg_ttl": false,
            "metadata": {
              "_nats.req.level": "0"
            }
          },
          "state": {
            "messages": 30,
            "bytes": 1431,
            "first_seq": 1,
            "first_ts": "2026-09-03T02:41:44.643133Z",
            "last_seq": 30,
            "last_ts": "2026-09-03T02:41:44.645033Z",
            "num_subjects": 1,
            "consumer_count": 1
          },
          "consumer_detail": [
            {
              "stream_name": "ORDERS",
              "name": "shipping",
              "created": "2026-09-03T02:41:44.959917Z",
              "config": {
                "durable_name": "shipping",
                "name": "shipping",
                "deliver_policy": "all",
                "ack_policy": "explicit",
                "ack_wait": 3000000000,
                "max_deliver": -1,
                "filter_subject": "orders.\u003e",
                "replay_policy": "instant",
                "max_waiting": 512,
                "max_ack_pending": 1000,
                "num_replicas": 0,
                "metadata": {
                  "_nats.req.level": "0"
                },
                "pause_until": "0001-01-01T00:00:00Z"
              },
              "delivered": {
                "consumer_seq": 20,
                "stream_seq": 10,
                "last_active": "2026-09-03T02:41:49.131023Z"
              },
              "ack_floor": {
                "consumer_seq": 0,
                "stream_seq": 0
              },
              "num_ack_pending": 10,
              "num_redelivered": 10,
              "num_waiting": 0,
              "num_pending": 0,
              "cluster": {
                "name": "east",
                "raft_group": "C-R3F-xfHKk1O2",
                "leader": "n2",
                "system_account": true,
                "traffic_account": "$SYS",
                "replicas": [
                  {
                    "name": "n2",
                    "current": true,
                    "active": 204886625,
                    "peer": "44jzkV9D"
                  },
                  {
                    "name": "n3",
                    "current": false,
                    "active": 0,
                    "peer": "BXScrY9i"
                  }
                ]
              },
              "ts": "2026-09-03T02:41:51.261745Z"
            }
          ],
          "stream_raft_group": "S-R3F-zHrMNfYE",
          "consumer_raft_groups": [
            {
              "name": "shipping",
              "raft_group": "C-R3F-xfHKk1O2"
            }
          ]
        }
      ]
    }
  ],
  "total": 1
}
```

`/varz`:

```json
{
  "server_id": "NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",
  "server_name": "n1",
  "version": "2.14.6",
  "proto": 1,
  "go": "go1.27.0",
  "host": "127.0.0.1",
  "port": 4291,
  "auth_required": true,
  "connect_urls": [
    "127.0.0.1:4291",
    "127.0.0.1:4293",
    "127.0.0.1:4292"
  ],
  "max_connections": 65536,
  "ping_interval": 120000000000,
  "ping_max": 2,
  "http_host": "127.0.0.1",
  "http_port": 8291,
  "http_base_path": "",
  "https_port": 0,
  "auth_timeout": 2,
  "max_control_line": 4096,
  "max_payload": 1048576,
  "max_pending": 67108864,
  "cluster": {
    "name": "east",
    "addr": "127.0.0.1",
    "cluster_port": 6291,
    "auth_timeout": 2,
    "urls": [
      "127.0.0.1:6292",
      "127.0.0.1:6293"
    ],
    "tls_timeout": 2,
    "pool_size": 3
  },
  "gateway": {},
  "leaf": {},
  "mqtt": {},
  "websocket": {},
  "jetstream": {
    "config": {
      "max_memory": 25769803776,
      "max_storage": 74242652160,
      "store_dir": "<lab>/n1/store/jetstream",
      "sync_interval": 120000000000,
      "strict": true
    },
    "stats": {
      "memory": 0,
      "storage": 1431,
      "reserved_memory": 0,
      "reserved_storage": 0,
      "accounts": 1,
      "ha_assets": 3,
      "api": {
        "level": 4,
        "total": 4,
        "errors": 1
      }
    },
    "meta": {
      "name": "east",
      "leader": "n1",
      "peer": "fjFyEjc1",
      "replicas": [
        {
          "name": "n2",
          "current": true,
          "active": 768318417,
          "peer": "44jzkV9D"
        },
        {
          "name": "n3",
          "current": true,
          "active": 768316042,
          "peer": "BXScrY9i"
        }
      ],
      "cluster_size": 3,
      "pending": 0,
      "pending_requests": 0,
      "pending_infos": 0,
      "snapshot": {
        "pending_entries": 4,
        "pending_size": 4180,
        "last_time": "0001-01-01T00:00:00Z"
      }
    },
    "limits": {}
  },
  "tls_timeout": 2,
  "write_deadline": 10000000000,
  "start": "2026-09-03T02:40:02.188888Z",
  "now": "2026-09-03T02:41:51.253256Z",
  "uptime": "1m49s",
  "mem": 28196864,
  "cores": 10,
  "gomaxprocs": 10,
  "cpu": 0.5,
  "connections": 0,
  "total_connections": 9,
  "routes": 8,
  "remotes": 2,
  "leafnodes": 0,
  "in_msgs": 525,
  "in_bytes": 93789,
  "in_client_msgs": 63,
  "in_client_bytes": 2327,
  "out_msgs": 537,
  "out_bytes": 105482,
  "out_client_msgs": 33,
  "out_client_bytes": 10906,
  "slow_consumers": 0,
  "stale_connections": 0,
  "stalled_clients": 0,
  "subscriptions": 258,
  "http_req_stats": {
    "/healthz": 1,
    "/jsz": 2,
    "/varz": 1
  },
  "config_load_time": "2026-09-03T02:40:02.188888Z",
  "config_digest": "sha256:23f0c061b4b83357e74d987cc52fe1b9257a81e686732b6dc04f93dd21d7994a",
  "feature_flags": {
    "js_ack_fc_v2": false,
    "js_raft_delete_range": false
  },
  "system_account": "$SYS",
  "slow_consumer_stats": {
    "clients": 0,
    "routes": 0,
    "gateways": 0,
    "leafs": 0
  },
  "stale_connection_stats": {
    "clients": 0,
    "routes": 0,
    "gateways": 0,
    "leafs": 0
  },
  "disk_io_wait_stats": {
    "waiters": 0,
    "waits": 0,
    "wait_time": 0,
    "max_wait_time": 0
  }
}
```

