<!-- source: nats-surveyor v0.9.11 (go install github.com/nats-io/nats-surveyor@v0.9.11, module version confirmed with go version -m) run against nats-server v2.14.6, nats CLI 0.4.0, macOS, 2026-09-03 · the lab cluster of tools/lab/cluster.sh (n1–n3), system user sys; script metrics-run.sh (in raw/prometheus-nats-exporter-src/) beside the exporter runs · the appendix quotes the v0.9.11 source from the Go module cache (github.com/nats-io/nats-surveyor@v0.9.11) -->
# nats-surveyor v0.9.11 against nats-server v2.14.6 — every series it emitted, observed, and the source lines behind the names

Three runs of surveyor over the system account of the lab cluster, on the same shape as
`raw/prometheus-nats-exporter-src/metrics-observed-v0.20.2.md` (one R3 stream with 30 messages, a pull
consumer holding 10 twice-delivered unacked messages, an R1 mirror and an R1 sourcing stream on n2),
before the acknowledgement of run H1 there. Each run started `nats-surveyor -s nats://127.0.0.1:4291
--user sys --password sys -c 3 -p 7778 …`, waited three seconds, scraped `/metrics` once and stopped.
The `go_*`, `process_*` and `promhttp_*` series are dropped as in the exporter file, with the count
stated. For `wiki/reference/metrics.md` (phase E step 3).


## Run S1 · every optional collector on

```
$ nats-surveyor -s nats://127.0.0.1:4291 --user sys --password sys -c 3 -p 7778 --jsz all --accounts --raftz
```

Surveyor log (first lines):

```
2026-09-03T04:42:02+02:00 [INFO] NATS_Surveyor - <host> connected to NATS Deployment: 127.0.0.1:4291
2026-09-03T04:42:02+02:00 [INFO] Prometheus exporter listening at http://0.0.0.0:7778/metrics
```

Scrape of `http://127.0.0.1:7778/metrics` — 105 `# HELP` lines kept, 2 `go_*`/`process_*`/`promhttp_*` series (8 lines) dropped:

```
# HELP nats_consumer_ack_floor_consumer_seq Number of ack floor consumer seq from a consumer
# TYPE nats_consumer_ack_floor_consumer_seq gauge
nats_consumer_ack_floor_consumer_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 0
nats_consumer_ack_floor_consumer_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 0
nats_consumer_ack_floor_consumer_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 0
# HELP nats_consumer_ack_floor_stream_seq Number of ack floor stream seq from a consumer
# TYPE nats_consumer_ack_floor_stream_seq gauge
nats_consumer_ack_floor_stream_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 0
nats_consumer_ack_floor_stream_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 0
nats_consumer_ack_floor_stream_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 0
# HELP nats_consumer_delivered_consumer_seq Latest consumer sequence number of a stream consumer
# TYPE nats_consumer_delivered_consumer_seq gauge
nats_consumer_delivered_consumer_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 20
nats_consumer_delivered_consumer_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 20
nats_consumer_delivered_consumer_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 20
# HELP nats_consumer_delivered_stream_seq Latest stream sequence number of a stream
# TYPE nats_consumer_delivered_stream_seq gauge
nats_consumer_delivered_stream_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 10
nats_consumer_delivered_stream_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 10
nats_consumer_delivered_stream_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 10
# HELP nats_consumer_num_ack_pending Number of pending acks from a consumer
# TYPE nats_consumer_num_ack_pending gauge
nats_consumer_num_ack_pending{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 10
nats_consumer_num_ack_pending{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 10
nats_consumer_num_ack_pending{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 10
# HELP nats_consumer_num_pending Number of pending messages from a consumer
# TYPE nats_consumer_num_pending gauge
nats_consumer_num_pending{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 20
nats_consumer_num_pending{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 0
nats_consumer_num_pending{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 0
# HELP nats_consumer_num_redelivered Number of redelivered messages from a consumer
# TYPE nats_consumer_num_redelivered gauge
nats_consumer_num_redelivered{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 10
nats_consumer_num_redelivered{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 10
nats_consumer_num_redelivered{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 10
# HELP nats_consumer_num_waiting Number of inflight fetch requests from a pull consumer
# TYPE nats_consumer_num_waiting gauge
nats_consumer_num_waiting{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 0
nats_consumer_num_waiting{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 0
nats_consumer_num_waiting{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 0
# HELP nats_core_account_bytes_recv The number of bytes received on this account across all connections
# TYPE nats_core_account_bytes_recv counter
nats_core_account_bytes_recv{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 871
nats_core_account_bytes_recv{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_bytes_recv{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2469
nats_core_account_bytes_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 183104
nats_core_account_bytes_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 190122
nats_core_account_bytes_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 231024
# HELP nats_core_account_bytes_sent The number of bytes sent on this account across all connections
# TYPE nats_core_account_bytes_sent counter
nats_core_account_bytes_sent{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 2884
nats_core_account_bytes_sent{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_bytes_sent{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 11777
nats_core_account_bytes_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 117378
nats_core_account_bytes_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 81164
nats_core_account_bytes_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 129283
# HELP nats_core_account_conn_count The number of client connections to this account
# TYPE nats_core_account_conn_count gauge
nats_core_account_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
nats_core_account_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_account_count The number of accounts detected
# TYPE nats_core_account_count gauge
nats_core_account_count 2
# HELP nats_core_account_jetstream_consumer_count The number of consumers per stream for this account
# TYPE nats_core_account_jetstream_consumer_count gauge
nats_core_account_jetstream_consumer_count{account="$G",account_name="$G",raft_group="S-R1F-4xqNIVlf",stream="ORDERS_AGG"} 0
nats_core_account_jetstream_consumer_count{account="$G",account_name="$G",raft_group="S-R1F-Cp5pI54v",stream="ORDERS_MIRROR"} 0
nats_core_account_jetstream_consumer_count{account="$G",account_name="$G",raft_group="S-R3F-zHrMNfYE",stream="ORDERS"} 1
# HELP nats_core_account_jetstream_enabled Whether JetStream is enabled or not for this account
# TYPE nats_core_account_jetstream_enabled gauge
nats_core_account_jetstream_enabled{account="$G",account_name="$G"} 1
nats_core_account_jetstream_enabled{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_memory_reserved The number of bytes reserved by JetStream memory
# TYPE nats_core_account_jetstream_memory_reserved gauge
nats_core_account_jetstream_memory_reserved{account="$G",account_name="$G"} 1.8446744073709552e+19
nats_core_account_jetstream_memory_reserved{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_memory_used The number of bytes used by JetStream memory
# TYPE nats_core_account_jetstream_memory_used gauge
nats_core_account_jetstream_memory_used{account="$G",account_name="$G"} 0
nats_core_account_jetstream_memory_used{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_replica_count The number of replicas per stream for this account
# TYPE nats_core_account_jetstream_replica_count gauge
nats_core_account_jetstream_replica_count{account="$G",account_name="$G",raft_group="S-R1F-4xqNIVlf",stream="ORDERS_AGG"} 1
nats_core_account_jetstream_replica_count{account="$G",account_name="$G",raft_group="S-R1F-Cp5pI54v",stream="ORDERS_MIRROR"} 1
nats_core_account_jetstream_replica_count{account="$G",account_name="$G",raft_group="S-R3F-zHrMNfYE",stream="ORDERS"} 3
# HELP nats_core_account_jetstream_storage_reserved The number of bytes reserved by JetStream storage
# TYPE nats_core_account_jetstream_storage_reserved gauge
nats_core_account_jetstream_storage_reserved{account="$G",account_name="$G"} 1.8446744073709552e+19
nats_core_account_jetstream_storage_reserved{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_storage_used The number of bytes used by JetStream storage
# TYPE nats_core_account_jetstream_storage_used gauge
nats_core_account_jetstream_storage_used{account="$G",account_name="$G"} 9006
nats_core_account_jetstream_storage_used{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_stream_count The number of streams in this account
# TYPE nats_core_account_jetstream_stream_count gauge
nats_core_account_jetstream_stream_count{account="$G",account_name="$G"} 3
nats_core_account_jetstream_stream_count{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_tiered_storage_reserved The number of bytes reserved by JetStream storage tier
# TYPE nats_core_account_jetstream_tiered_storage_reserved gauge
nats_core_account_jetstream_tiered_storage_reserved{account="$G",account_name="$G",tier="R1"} 0
nats_core_account_jetstream_tiered_storage_reserved{account="$G",account_name="$G",tier="R3"} 0
# HELP nats_core_account_jetstream_tiered_storage_used The number of bytes used by JetStream storage tier
# TYPE nats_core_account_jetstream_tiered_storage_used gauge
nats_core_account_jetstream_tiered_storage_used{account="$G",account_name="$G",tier="R1"} 4713
nats_core_account_jetstream_tiered_storage_used{account="$G",account_name="$G",tier="R3"} 1431
# HELP nats_core_account_leaf_count The number of leafnode connections to this account
# TYPE nats_core_account_leaf_count gauge
nats_core_account_leaf_count{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_leaf_count{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_leaf_count{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
nats_core_account_leaf_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_leaf_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_leaf_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_account_msgs_recv The number of messages received on this account across all connections
# TYPE nats_core_account_msgs_recv counter
nats_core_account_msgs_recv{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 50
nats_core_account_msgs_recv{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_msgs_recv{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 83
nats_core_account_msgs_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1142
nats_core_account_msgs_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 804
nats_core_account_msgs_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1077
# HELP nats_core_account_msgs_sent The number of messages sent on this account across all connections
# TYPE nats_core_account_msgs_sent counter
nats_core_account_msgs_sent{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 80
nats_core_account_msgs_sent{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_msgs_sent{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 83
nats_core_account_msgs_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 580
nats_core_account_msgs_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 377
nats_core_account_msgs_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 569
# HELP nats_core_account_slow_consumer_count The number of slow consumers detected in this account
# TYPE nats_core_account_slow_consumer_count gauge
nats_core_account_slow_consumer_count{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_slow_consumer_count{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_slow_consumer_count{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
nats_core_account_slow_consumer_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_slow_consumer_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_slow_consumer_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_account_sub_count The number of subscriptions on this account
# TYPE nats_core_account_sub_count gauge
nats_core_account_sub_count{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 32
nats_core_account_sub_count{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 30
nats_core_account_sub_count{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 30
nats_core_account_sub_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 230
nats_core_account_sub_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 230
nats_core_account_sub_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 230
# HELP nats_core_account_total_conn_count The combined current number of client and leafnode connections to this account
# TYPE nats_core_account_total_conn_count gauge
nats_core_account_total_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_total_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_total_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
nats_core_account_total_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_total_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_total_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_active_account_count Number of active accounts gauge
# TYPE nats_core_active_account_count gauge
nats_core_active_account_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 2
nats_core_active_account_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 2
nats_core_active_account_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2
# HELP nats_core_connection_count Current number of client connections gauge
# TYPE nats_core_connection_count gauge
nats_core_connection_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_connection_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_connection_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_core_count Machine cores gauge
# TYPE nats_core_core_count gauge
nats_core_core_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 10
nats_core_core_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 10
nats_core_core_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 10
# HELP nats_core_cpu_percentage Server cpu utilization gauge
# TYPE nats_core_cpu_percentage gauge
nats_core_cpu_percentage{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0.3
nats_core_cpu_percentage{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0.2
nats_core_cpu_percentage{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0.3
# HELP nats_core_gateway_count Number of active gateways gauge
# TYPE nats_core_gateway_count gauge
nats_core_gateway_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_gateway_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_gateway_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_go_memlimit_bytes Server GOMEMLIMIT gauge (0 if not set)
# TYPE nats_core_go_memlimit_bytes gauge
nats_core_go_memlimit_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_go_memlimit_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_go_memlimit_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_gomaxprocs Server GOMAXPROCS gauge (maximum number of threads to use for running goroutines at once)
# TYPE nats_core_gomaxprocs gauge
nats_core_gomaxprocs{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 10
nats_core_gomaxprocs{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 10
nats_core_gomaxprocs{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 10
# HELP nats_core_info General Server information Summary gauge
# TYPE nats_core_info gauge
nats_core_info{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_version="2.14.6"} 1
nats_core_info{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_version="2.14.6"} 1
nats_core_info{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_version="2.14.6"} 1
# HELP nats_core_jetstream_accounts Number of NATS Accounts present on a Jetstream server
# TYPE nats_core_jetstream_accounts gauge
nats_core_jetstream_accounts{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1
nats_core_jetstream_accounts{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1
nats_core_jetstream_accounts{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_api_errors Number of Jetstream API Errors. Value is 0 when server starts
# TYPE nats_core_jetstream_api_errors counter
nats_core_jetstream_api_errors{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_api_errors{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_api_errors{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_api_pending Number of Jetstream API in the queue waiting to be processed
# TYPE nats_core_jetstream_api_pending gauge
nats_core_jetstream_api_pending{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_api_pending{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_api_pending{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_api_requests Number of Jetstream API Requests processed. Value is 0 when server starts
# TYPE nats_core_jetstream_api_requests counter
nats_core_jetstream_api_requests{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 11
nats_core_jetstream_api_requests{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_api_requests{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 4
# HELP nats_core_jetstream_cluster_raft_group_info Provides metadata about a RAFT Group
# TYPE nats_core_jetstream_cluster_raft_group_info gauge
nats_core_jetstream_cluster_raft_group_info{cluster_name="_meta_",jetstream_domain="Default",leader="n1",raft_group="_meta_",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1
nats_core_jetstream_cluster_raft_group_info{cluster_name="_meta_",jetstream_domain="Default",leader="n1",raft_group="_meta_",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1
nats_core_jetstream_cluster_raft_group_info{cluster_name="east",jetstream_domain="Default",leader="n1",raft_group="_meta_",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_cluster_raft_group_leader 1 if this server is leader of raft group, 0 otherwise
# TYPE nats_core_jetstream_cluster_raft_group_leader gauge
nats_core_jetstream_cluster_raft_group_leader{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_cluster_raft_group_leader{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_cluster_raft_group_leader{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_cluster_raft_group_replica_peer_active Jetstream RAFT Group Peer last Active time. Very large values may imply raft is stalled
# TYPE nats_core_jetstream_cluster_raft_group_replica_peer_active gauge
nats_core_jetstream_cluster_raft_group_replica_peer_active{cluster_name="east",peer="n2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 4.07728125e+08
nats_core_jetstream_cluster_raft_group_replica_peer_active{cluster_name="east",peer="n3",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 4.0773025e+08
# HELP nats_core_jetstream_cluster_raft_group_replica_peer_current Jetstream RAFT Group Peer is current: 1 or not: 0
# TYPE nats_core_jetstream_cluster_raft_group_replica_peer_current gauge
nats_core_jetstream_cluster_raft_group_replica_peer_current{cluster_name="east",peer="n2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
nats_core_jetstream_cluster_raft_group_replica_peer_current{cluster_name="east",peer="n3",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_cluster_raft_group_replica_peer_offline Jetstream RAFT Group Peer is offline: 1 or online: 0
# TYPE nats_core_jetstream_cluster_raft_group_replica_peer_offline gauge
nats_core_jetstream_cluster_raft_group_replica_peer_offline{cluster_name="east",peer="n2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
nats_core_jetstream_cluster_raft_group_replica_peer_offline{cluster_name="east",peer="n3",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_cluster_raft_group_replicas Info about replicas from leaders perspective
# TYPE nats_core_jetstream_cluster_raft_group_replicas gauge
nats_core_jetstream_cluster_raft_group_replicas{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_cluster_raft_group_replicas{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_cluster_raft_group_replicas{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2
# HELP nats_core_jetstream_cluster_raft_group_size Number of peers in a RAFT group
# TYPE nats_core_jetstream_cluster_raft_group_size gauge
nats_core_jetstream_cluster_raft_group_size{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 3
nats_core_jetstream_cluster_raft_group_size{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 3
nats_core_jetstream_cluster_raft_group_size{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 3
# HELP nats_core_jetstream_enabled 1 if Jetstream is enabled, 0 otherwise.  A gauge.
# TYPE nats_core_jetstream_enabled gauge
nats_core_jetstream_enabled{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1
nats_core_jetstream_enabled{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1
nats_core_jetstream_enabled{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_filestore_reserved_bytes Account Reservations of jetstream filesystem storage in bytes
# TYPE nats_core_jetstream_filestore_reserved_bytes gauge
nats_core_jetstream_filestore_reserved_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_filestore_reserved_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_filestore_reserved_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_filestore_size_bytes Capacity of jetstream filesystem storage in bytes
# TYPE nats_core_jetstream_filestore_size_bytes gauge
nats_core_jetstream_filestore_size_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 7.4242679808e+10
nats_core_jetstream_filestore_size_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 7.42426368e+10
nats_core_jetstream_filestore_size_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 7.424265216e+10
# HELP nats_core_jetstream_filestore_used_bytes Consumption of jetstream filesystem storage in bytes
# TYPE nats_core_jetstream_filestore_used_bytes gauge
nats_core_jetstream_filestore_used_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 6144
nats_core_jetstream_filestore_used_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1431
nats_core_jetstream_filestore_used_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1431
# HELP nats_core_jetstream_ha_assets Number of HA (R>1) assets used by NATS
# TYPE nats_core_jetstream_ha_assets gauge
nats_core_jetstream_ha_assets{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 3
nats_core_jetstream_ha_assets{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 3
nats_core_jetstream_ha_assets{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 3
# HELP nats_core_jetstream_info  Always 1. Contains metadata for cross-reference from other time-series
# TYPE nats_core_jetstream_info gauge
nats_core_jetstream_info{server_cluster="east",server_domain="Default",server_host="127.0.0.1",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_jetstream="true",server_name="n2",server_version="2.14.6"} 1
nats_core_jetstream_info{server_cluster="east",server_domain="Default",server_host="127.0.0.1",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_jetstream="true",server_name="n3",server_version="2.14.6"} 1
nats_core_jetstream_info{server_cluster="east",server_domain="Default",server_host="127.0.0.1",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_jetstream="true",server_name="n1",server_version="2.14.6"} 1
# HELP nats_core_jetstream_memstore_reserved_bytes Account Reservations of  jetstream in-memory store in bytes
# TYPE nats_core_jetstream_memstore_reserved_bytes gauge
nats_core_jetstream_memstore_reserved_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_memstore_reserved_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_memstore_reserved_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_memstore_size_bytes Capacity of jetstream in-memory store in bytes
# TYPE nats_core_jetstream_memstore_size_bytes gauge
nats_core_jetstream_memstore_size_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 2.5769803776e+10
nats_core_jetstream_memstore_size_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 2.5769803776e+10
nats_core_jetstream_memstore_size_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2.5769803776e+10
# HELP nats_core_jetstream_memstore_used_bytes Consumption of jetstream in-memory store in bytes
# TYPE nats_core_jetstream_memstore_used_bytes gauge
nats_core_jetstream_memstore_used_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_memstore_used_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_memstore_used_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_meta_snapshot_last_duration_seconds Duration of the last meta snapshot in seconds
# TYPE nats_core_jetstream_meta_snapshot_last_duration_seconds gauge
nats_core_jetstream_meta_snapshot_last_duration_seconds{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0.000305333
nats_core_jetstream_meta_snapshot_last_duration_seconds{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0.000137292
nats_core_jetstream_meta_snapshot_last_duration_seconds{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0.000233875
# HELP nats_core_jetstream_meta_snapshot_last_timestamp_seconds Timestamp of the last meta snapshot as Unix epoch in seconds
# TYPE nats_core_jetstream_meta_snapshot_last_timestamp_seconds gauge
nats_core_jetstream_meta_snapshot_last_timestamp_seconds{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1.788403322e+09
nats_core_jetstream_meta_snapshot_last_timestamp_seconds{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1.788403322e+09
nats_core_jetstream_meta_snapshot_last_timestamp_seconds{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1.788403322e+09
# HELP nats_core_jetstream_meta_snapshot_pending_bytes Size in bytes of pending entries awaiting meta snapshot
# TYPE nats_core_jetstream_meta_snapshot_pending_bytes gauge
nats_core_jetstream_meta_snapshot_pending_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_meta_snapshot_pending_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_meta_snapshot_pending_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_meta_snapshot_pending_entries Number of pending entries awaiting meta snapshot
# TYPE nats_core_jetstream_meta_snapshot_pending_entries gauge
nats_core_jetstream_meta_snapshot_pending_entries{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_meta_snapshot_pending_entries{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_meta_snapshot_pending_entries{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_server_jetstream_disabled JetStream disabled or not
# TYPE nats_core_jetstream_server_jetstream_disabled gauge
nats_core_jetstream_server_jetstream_disabled{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_server_jetstream_disabled{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_server_jetstream_disabled{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_server_max_memory JetStream Max Memory
# TYPE nats_core_jetstream_server_max_memory gauge
nats_core_jetstream_server_max_memory{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 2.5769803776e+10
nats_core_jetstream_server_max_memory{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 2.5769803776e+10
nats_core_jetstream_server_max_memory{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2.5769803776e+10
# HELP nats_core_jetstream_server_max_storage JetStream Max Storage
# TYPE nats_core_jetstream_server_max_storage gauge
nats_core_jetstream_server_max_storage{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 7.4242679808e+10
nats_core_jetstream_server_max_storage{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 7.42426368e+10
nats_core_jetstream_server_max_storage{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 7.424265216e+10
# HELP nats_core_jetstream_server_total_consumer_leaders Number of consumer leaders on this server (sum across servers gives total consumer count)
# TYPE nats_core_jetstream_server_total_consumer_leaders gauge
nats_core_jetstream_server_total_consumer_leaders{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1
nats_core_jetstream_server_total_consumer_leaders{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_server_total_consumer_leaders{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_server_total_consumers Number of consumer replicas on this server (includes R1 consumers)
# TYPE nats_core_jetstream_server_total_consumers gauge
nats_core_jetstream_server_total_consumers{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1
nats_core_jetstream_server_total_consumers{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1
nats_core_jetstream_server_total_consumers{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_server_total_message_bytes Total number of bytes stored in JetStream
# TYPE nats_core_jetstream_server_total_message_bytes gauge
nats_core_jetstream_server_total_message_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 6144
nats_core_jetstream_server_total_message_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1431
nats_core_jetstream_server_total_message_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1431
# HELP nats_core_jetstream_server_total_messages Total number of stored messages in JetStream
# TYPE nats_core_jetstream_server_total_messages gauge
nats_core_jetstream_server_total_messages{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 90
nats_core_jetstream_server_total_messages{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 30
nats_core_jetstream_server_total_messages{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 30
# HELP nats_core_jetstream_server_total_stream_leaders Number of stream leaders on this server (sum across servers gives total stream count)
# TYPE nats_core_jetstream_server_total_stream_leaders gauge
nats_core_jetstream_server_total_stream_leaders{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 3
nats_core_jetstream_server_total_stream_leaders{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_server_total_stream_leaders{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_server_total_streams Number of stream replicas on this server (includes R1 streams)
# TYPE nats_core_jetstream_server_total_streams gauge
nats_core_jetstream_server_total_streams{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 3
nats_core_jetstream_server_total_streams{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1
nats_core_jetstream_server_total_streams{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_mem_bytes Server memory gauge
# TYPE nats_core_mem_bytes gauge
nats_core_mem_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 2.8442624e+07
nats_core_mem_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 2.7475968e+07
nats_core_mem_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2.9769728e+07
# HELP nats_core_raftz_meta_applied Highest applied log entry index of the meta Raft group
# TYPE nats_core_raftz_meta_applied gauge
nats_core_raftz_meta_applied{cluster_name="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_id="east",server_name="n2"} 7
nats_core_raftz_meta_applied{cluster_name="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_id="east",server_name="n3"} 7
nats_core_raftz_meta_applied{cluster_name="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_id="east",server_name="n1"} 7
# HELP nats_core_raftz_meta_committed Highest committed log entry index of the meta Raft group
# TYPE nats_core_raftz_meta_committed gauge
nats_core_raftz_meta_committed{cluster_name="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_id="east",server_name="n2"} 7
nats_core_raftz_meta_committed{cluster_name="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_id="east",server_name="n3"} 7
nats_core_raftz_meta_committed{cluster_name="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_id="east",server_name="n1"} 7
# HELP nats_core_raftz_meta_pindex Log entry index at last snapshot of the meta Raft group
# TYPE nats_core_raftz_meta_pindex gauge
nats_core_raftz_meta_pindex{cluster_name="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_id="east",server_name="n2"} 7
nats_core_raftz_meta_pindex{cluster_name="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_id="east",server_name="n3"} 7
nats_core_raftz_meta_pindex{cluster_name="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_id="east",server_name="n1"} 7
# HELP nats_core_recv_bytes Number of bytes received by the server from all connections including clients, routes, gateways and leafnodes counter
# TYPE nats_core_recv_bytes counter
nats_core_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 92279
nats_core_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 94917
nats_core_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 112335
# HELP nats_core_recv_from_client_bytes_total Number of bytes received by the server from client connections (excludes routes, gateways, leafnodes) counter
# TYPE nats_core_recv_from_client_bytes_total counter
nats_core_recv_from_client_bytes_total{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_recv_from_client_bytes_total{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_recv_from_client_bytes_total{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2669
# HELP nats_core_recv_from_client_msgs_total Number of messages received by the server from client connections (excludes routes, gateways, leafnodes) counter
# TYPE nats_core_recv_from_client_msgs_total counter
nats_core_recv_from_client_msgs_total{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_recv_from_client_msgs_total{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_recv_from_client_msgs_total{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 68
# HELP nats_core_recv_msgs_count Number of messages received by the server from all connections including clients, routes, gateways and leafnodes counter
# TYPE nats_core_recv_msgs_count counter
nats_core_recv_msgs_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 619
nats_core_recv_msgs_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 400
nats_core_recv_msgs_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 619
# HELP nats_core_route_count Number of active routes gauge
# TYPE nats_core_route_count gauge
nats_core_route_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 8
nats_core_route_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 8
nats_core_route_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 8
# HELP nats_core_route_pending_bytes Number of bytes pending in the route gauge
# TYPE nats_core_route_pending_bytes gauge
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="11"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="8"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="9"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="15"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="12"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="14"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="9"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="11"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="13"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="15"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="10"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="11"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="9"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="15"} 0
# HELP nats_core_route_recv_bytes Number of bytes received over the route counter
# TYPE nats_core_route_recv_bytes counter
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="11"} 871
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="8"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="9"} 54482
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="12"} 36926
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="15"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="12"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="14"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="9"} 48570
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="11"} 46347
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="13"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="15"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="10"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="11"} 142
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="8"} 68156
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="9"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="13"} 41368
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="15"} 0
# HELP nats_core_route_recv_msg_count Number of messages received over the route counter
# TYPE nats_core_route_recv_msg_count counter
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="11"} 50
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="8"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="9"} 362
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="12"} 207
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="15"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="12"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="14"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="9"} 185
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="11"} 215
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="13"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="15"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="10"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="11"} 20
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="8"} 363
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="9"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="13"} 168
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="15"} 0
# HELP nats_core_route_sent_bytes Number of bytes sent over the route counter
# TYPE nats_core_route_sent_bytes counter
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="11"} 142
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="8"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="9"} 68156
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="12"} 46347
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="15"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="12"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="14"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="9"} 41368
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="11"} 36926
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="13"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="15"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="10"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="11"} 871
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="8"} 54482
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="9"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="13"} 48570
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="15"} 0
# HELP nats_core_route_sent_msg_count Number of messages sent over the route counter
# TYPE nats_core_route_sent_msg_count counter
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="11"} 20
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="8"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="9"} 363
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="12"} 215
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="15"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="12"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="14"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="9"} 168
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="11"} 207
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="13"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="15"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="10"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="11"} 50
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="8"} 362
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="9"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="13"} 185
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="15"} 0
# HELP nats_core_rtt_nanoseconds RTT in nanoseconds gauge
# TYPE nats_core_rtt_nanoseconds gauge
nats_core_rtt_nanoseconds{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 381708
nats_core_rtt_nanoseconds{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 325958
nats_core_rtt_nanoseconds{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 304792
# HELP nats_core_sent_bytes Number of bytes sent by the server to all connections including clients, routes, gateways and leafnodes counter
# TYPE nats_core_sent_bytes counter
nats_core_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 114645
nats_core_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 78294
nats_core_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 132005
# HELP nats_core_sent_msgs_count Number of messages sent by the server to all connections including clients, routes, gateways and leafnodes counter
# TYPE nats_core_sent_msgs_count counter
nats_core_sent_msgs_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 598
nats_core_sent_msgs_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 375
nats_core_sent_msgs_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 642
# HELP nats_core_sent_to_client_bytes_total Number of bytes sent by the server to client connections (excludes routes, gateways, leafnodes) counter
# TYPE nats_core_sent_to_client_bytes_total counter
nats_core_sent_to_client_bytes_total{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_sent_to_client_bytes_total{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_sent_to_client_bytes_total{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 28082
# HELP nats_core_sent_to_client_msgs_total Number of messages sent by the server to client connections (excludes routes, gateways, leafnodes) counter
# TYPE nats_core_sent_to_client_msgs_total counter
nats_core_sent_to_client_msgs_total{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_sent_to_client_msgs_total{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_sent_to_client_msgs_total{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 45
# HELP nats_core_slow_consumer_count Number of slow consumers gauge
# TYPE nats_core_slow_consumer_count gauge
nats_core_slow_consumer_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_slow_consumer_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_slow_consumer_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_start_time Server start time gauge
# TYPE nats_core_start_time gauge
nats_core_start_time{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1.788403202356733e+18
nats_core_start_time{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1.788403202526818e+18
nats_core_start_time{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1.788403202188888e+18
# HELP nats_core_subs_count Current number of subscriptions gauge
# TYPE nats_core_subs_count gauge
nats_core_subs_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 261
nats_core_subs_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 259
nats_core_subs_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 259
# HELP nats_core_total_connection_count Total number of client connections serviced counter
# TYPE nats_core_total_connection_count counter
nats_core_total_connection_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_total_connection_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_total_connection_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 10
# HELP nats_core_uptime Server uptime gauge
# TYPE nats_core_uptime gauge
nats_core_uptime{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 123.539461
nats_core_uptime{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 123.369305
nats_core_uptime{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 123.707149
# HELP nats_jetstream_advisory_count Number of JetStream Advisory listeners that are running
# TYPE nats_jetstream_advisory_count gauge
nats_jetstream_advisory_count 0
# HELP nats_latency_observations_count Number of Service Latency listeners that are running
# TYPE nats_latency_observations_count gauge
nats_latency_observations_count 0
# HELP nats_stream_consumer_count Total number of consumers from a stream
# TYPE nats_stream_consumer_count gauge
nats_stream_consumer_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 0
nats_stream_consumer_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 0
nats_stream_consumer_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 0
nats_stream_consumer_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 0
nats_stream_consumer_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 0
# HELP nats_stream_first_seq First sequence from a stream
# TYPE nats_stream_first_seq gauge
nats_stream_first_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 1
nats_stream_first_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 1
nats_stream_first_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 1
nats_stream_first_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 1
nats_stream_first_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 1
# HELP nats_stream_last_seq Last sequence from a stream
# TYPE nats_stream_last_seq gauge
nats_stream_last_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 30
nats_stream_last_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 30
nats_stream_last_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 30
nats_stream_last_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 30
nats_stream_last_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 30
# HELP nats_stream_subject_count Total number of subjects in a stream
# TYPE nats_stream_subject_count gauge
nats_stream_subject_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 1
nats_stream_subject_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 1
nats_stream_subject_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 1
nats_stream_subject_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 1
nats_stream_subject_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 1
# HELP nats_stream_total_bytes Total stored bytes from a stream
# TYPE nats_stream_total_bytes gauge
nats_stream_total_bytes{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 3282
nats_stream_total_bytes{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 1431
nats_stream_total_bytes{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 1431
nats_stream_total_bytes{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 1431
nats_stream_total_bytes{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 1431
# HELP nats_stream_total_messages Total number of messages from a stream
# TYPE nats_stream_total_messages gauge
nats_stream_total_messages{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 30
nats_stream_total_messages{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 30
nats_stream_total_messages{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 30
nats_stream_total_messages{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 30
nats_stream_total_messages{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 30
# HELP nats_survey_duration_seconds Time it took to gather the surveyed data histogram
# TYPE nats_survey_duration_seconds summary
nats_survey_duration_seconds_sum 0.012927167
nats_survey_duration_seconds_count 2
# HELP nats_survey_expected_count Number of remote hosts expected to responded gauge
# TYPE nats_survey_expected_count gauge
nats_survey_expected_count 3
# HELP nats_survey_surveyed_count Number of remote hosts successfully surveyed gauge
# TYPE nats_survey_surveyed_count gauge
nats_survey_surveyed_count 3
# HELP nats_up 1 if connected to NATS, 0 otherwise.  A gauge.
# TYPE nats_up gauge
nats_up 1

[http 200]
```


## Run S2 · the same with `--jsz-leaders-only`

```
$ nats-surveyor -s nats://127.0.0.1:4291 --user sys --password sys -c 3 -p 7778 --jsz all --accounts --raftz --jsz-leaders-only
```

Surveyor log (first lines):

```
2026-09-03T04:42:05+02:00 [INFO] NATS_Surveyor - <host> connected to NATS Deployment: 127.0.0.1:4291
2026-09-03T04:42:05+02:00 [INFO] Prometheus exporter listening at http://0.0.0.0:7778/metrics
```

Scrape of `http://127.0.0.1:7778/metrics` — 105 `# HELP` lines kept, 2 `go_*`/`process_*`/`promhttp_*` series (8 lines) dropped:

```
# HELP nats_consumer_ack_floor_consumer_seq Number of ack floor consumer seq from a consumer
# TYPE nats_consumer_ack_floor_consumer_seq gauge
nats_consumer_ack_floor_consumer_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 0
# HELP nats_consumer_ack_floor_stream_seq Number of ack floor stream seq from a consumer
# TYPE nats_consumer_ack_floor_stream_seq gauge
nats_consumer_ack_floor_stream_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 0
# HELP nats_consumer_delivered_consumer_seq Latest consumer sequence number of a stream consumer
# TYPE nats_consumer_delivered_consumer_seq gauge
nats_consumer_delivered_consumer_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 20
# HELP nats_consumer_delivered_stream_seq Latest stream sequence number of a stream
# TYPE nats_consumer_delivered_stream_seq gauge
nats_consumer_delivered_stream_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 10
# HELP nats_consumer_num_ack_pending Number of pending acks from a consumer
# TYPE nats_consumer_num_ack_pending gauge
nats_consumer_num_ack_pending{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 10
# HELP nats_consumer_num_pending Number of pending messages from a consumer
# TYPE nats_consumer_num_pending gauge
nats_consumer_num_pending{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 20
# HELP nats_consumer_num_redelivered Number of redelivered messages from a consumer
# TYPE nats_consumer_num_redelivered gauge
nats_consumer_num_redelivered{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 10
# HELP nats_consumer_num_waiting Number of inflight fetch requests from a pull consumer
# TYPE nats_consumer_num_waiting gauge
nats_consumer_num_waiting{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 0
# HELP nats_core_account_bytes_recv The number of bytes received on this account across all connections
# TYPE nats_core_account_bytes_recv counter
nats_core_account_bytes_recv{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 871
nats_core_account_bytes_recv{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_bytes_recv{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2469
nats_core_account_bytes_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 196874
nats_core_account_bytes_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 203818
nats_core_account_bytes_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 286208
# HELP nats_core_account_bytes_sent The number of bytes sent on this account across all connections
# TYPE nats_core_account_bytes_sent counter
nats_core_account_bytes_sent{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 2884
nats_core_account_bytes_sent{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_bytes_sent{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 11777
nats_core_account_bytes_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 133927
nats_core_account_bytes_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 96423
nats_core_account_bytes_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 172743
# HELP nats_core_account_conn_count The number of client connections to this account
# TYPE nats_core_account_conn_count gauge
nats_core_account_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
nats_core_account_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_account_count The number of accounts detected
# TYPE nats_core_account_count gauge
nats_core_account_count 2
# HELP nats_core_account_jetstream_consumer_count The number of consumers per stream for this account
# TYPE nats_core_account_jetstream_consumer_count gauge
nats_core_account_jetstream_consumer_count{account="$G",account_name="$G",raft_group="S-R1F-4xqNIVlf",stream="ORDERS_AGG"} 0
nats_core_account_jetstream_consumer_count{account="$G",account_name="$G",raft_group="S-R1F-Cp5pI54v",stream="ORDERS_MIRROR"} 0
nats_core_account_jetstream_consumer_count{account="$G",account_name="$G",raft_group="S-R3F-zHrMNfYE",stream="ORDERS"} 1
# HELP nats_core_account_jetstream_enabled Whether JetStream is enabled or not for this account
# TYPE nats_core_account_jetstream_enabled gauge
nats_core_account_jetstream_enabled{account="$G",account_name="$G"} 1
nats_core_account_jetstream_enabled{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_memory_reserved The number of bytes reserved by JetStream memory
# TYPE nats_core_account_jetstream_memory_reserved gauge
nats_core_account_jetstream_memory_reserved{account="$G",account_name="$G"} 1.8446744073709552e+19
nats_core_account_jetstream_memory_reserved{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_memory_used The number of bytes used by JetStream memory
# TYPE nats_core_account_jetstream_memory_used gauge
nats_core_account_jetstream_memory_used{account="$G",account_name="$G"} 0
nats_core_account_jetstream_memory_used{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_replica_count The number of replicas per stream for this account
# TYPE nats_core_account_jetstream_replica_count gauge
nats_core_account_jetstream_replica_count{account="$G",account_name="$G",raft_group="S-R1F-4xqNIVlf",stream="ORDERS_AGG"} 1
nats_core_account_jetstream_replica_count{account="$G",account_name="$G",raft_group="S-R1F-Cp5pI54v",stream="ORDERS_MIRROR"} 1
nats_core_account_jetstream_replica_count{account="$G",account_name="$G",raft_group="S-R3F-zHrMNfYE",stream="ORDERS"} 3
# HELP nats_core_account_jetstream_storage_reserved The number of bytes reserved by JetStream storage
# TYPE nats_core_account_jetstream_storage_reserved gauge
nats_core_account_jetstream_storage_reserved{account="$G",account_name="$G"} 1.8446744073709552e+19
nats_core_account_jetstream_storage_reserved{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_storage_used The number of bytes used by JetStream storage
# TYPE nats_core_account_jetstream_storage_used gauge
nats_core_account_jetstream_storage_used{account="$G",account_name="$G"} 9006
nats_core_account_jetstream_storage_used{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_stream_count The number of streams in this account
# TYPE nats_core_account_jetstream_stream_count gauge
nats_core_account_jetstream_stream_count{account="$G",account_name="$G"} 3
nats_core_account_jetstream_stream_count{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_tiered_storage_reserved The number of bytes reserved by JetStream storage tier
# TYPE nats_core_account_jetstream_tiered_storage_reserved gauge
nats_core_account_jetstream_tiered_storage_reserved{account="$G",account_name="$G",tier="R1"} 0
nats_core_account_jetstream_tiered_storage_reserved{account="$G",account_name="$G",tier="R3"} 0
# HELP nats_core_account_jetstream_tiered_storage_used The number of bytes used by JetStream storage tier
# TYPE nats_core_account_jetstream_tiered_storage_used gauge
nats_core_account_jetstream_tiered_storage_used{account="$G",account_name="$G",tier="R1"} 4713
nats_core_account_jetstream_tiered_storage_used{account="$G",account_name="$G",tier="R3"} 1431
# HELP nats_core_account_leaf_count The number of leafnode connections to this account
# TYPE nats_core_account_leaf_count gauge
nats_core_account_leaf_count{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_leaf_count{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_leaf_count{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
nats_core_account_leaf_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_leaf_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_leaf_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_account_msgs_recv The number of messages received on this account across all connections
# TYPE nats_core_account_msgs_recv counter
nats_core_account_msgs_recv{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 50
nats_core_account_msgs_recv{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_msgs_recv{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 83
nats_core_account_msgs_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1204
nats_core_account_msgs_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 854
nats_core_account_msgs_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1153
# HELP nats_core_account_msgs_sent The number of messages sent on this account across all connections
# TYPE nats_core_account_msgs_sent counter
nats_core_account_msgs_sent{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 80
nats_core_account_msgs_sent{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_msgs_sent{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 83
nats_core_account_msgs_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 609
nats_core_account_msgs_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 400
nats_core_account_msgs_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 631
# HELP nats_core_account_slow_consumer_count The number of slow consumers detected in this account
# TYPE nats_core_account_slow_consumer_count gauge
nats_core_account_slow_consumer_count{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_slow_consumer_count{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_slow_consumer_count{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
nats_core_account_slow_consumer_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_slow_consumer_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_slow_consumer_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_account_sub_count The number of subscriptions on this account
# TYPE nats_core_account_sub_count gauge
nats_core_account_sub_count{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 32
nats_core_account_sub_count{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 30
nats_core_account_sub_count{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 30
nats_core_account_sub_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 230
nats_core_account_sub_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 230
nats_core_account_sub_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 230
# HELP nats_core_account_total_conn_count The combined current number of client and leafnode connections to this account
# TYPE nats_core_account_total_conn_count gauge
nats_core_account_total_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_total_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_total_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
nats_core_account_total_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_total_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_total_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_active_account_count Number of active accounts gauge
# TYPE nats_core_active_account_count gauge
nats_core_active_account_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 2
nats_core_active_account_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 2
nats_core_active_account_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2
# HELP nats_core_connection_count Current number of client connections gauge
# TYPE nats_core_connection_count gauge
nats_core_connection_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_connection_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_connection_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_core_count Machine cores gauge
# TYPE nats_core_core_count gauge
nats_core_core_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 10
nats_core_core_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 10
nats_core_core_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 10
# HELP nats_core_cpu_percentage Server cpu utilization gauge
# TYPE nats_core_cpu_percentage gauge
nats_core_cpu_percentage{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0.5
nats_core_cpu_percentage{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0.3
nats_core_cpu_percentage{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0.2
# HELP nats_core_gateway_count Number of active gateways gauge
# TYPE nats_core_gateway_count gauge
nats_core_gateway_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_gateway_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_gateway_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_go_memlimit_bytes Server GOMEMLIMIT gauge (0 if not set)
# TYPE nats_core_go_memlimit_bytes gauge
nats_core_go_memlimit_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_go_memlimit_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_go_memlimit_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_gomaxprocs Server GOMAXPROCS gauge (maximum number of threads to use for running goroutines at once)
# TYPE nats_core_gomaxprocs gauge
nats_core_gomaxprocs{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 10
nats_core_gomaxprocs{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 10
nats_core_gomaxprocs{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 10
# HELP nats_core_info General Server information Summary gauge
# TYPE nats_core_info gauge
nats_core_info{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_version="2.14.6"} 1
nats_core_info{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_version="2.14.6"} 1
nats_core_info{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_version="2.14.6"} 1
# HELP nats_core_jetstream_accounts Number of NATS Accounts present on a Jetstream server
# TYPE nats_core_jetstream_accounts gauge
nats_core_jetstream_accounts{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1
nats_core_jetstream_accounts{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1
nats_core_jetstream_accounts{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_api_errors Number of Jetstream API Errors. Value is 0 when server starts
# TYPE nats_core_jetstream_api_errors counter
nats_core_jetstream_api_errors{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_api_errors{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_api_errors{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_api_pending Number of Jetstream API in the queue waiting to be processed
# TYPE nats_core_jetstream_api_pending gauge
nats_core_jetstream_api_pending{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_api_pending{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_api_pending{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_api_requests Number of Jetstream API Requests processed. Value is 0 when server starts
# TYPE nats_core_jetstream_api_requests counter
nats_core_jetstream_api_requests{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 11
nats_core_jetstream_api_requests{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_api_requests{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 4
# HELP nats_core_jetstream_cluster_raft_group_info Provides metadata about a RAFT Group
# TYPE nats_core_jetstream_cluster_raft_group_info gauge
nats_core_jetstream_cluster_raft_group_info{cluster_name="_meta_",jetstream_domain="Default",leader="n1",raft_group="_meta_",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1
nats_core_jetstream_cluster_raft_group_info{cluster_name="_meta_",jetstream_domain="Default",leader="n1",raft_group="_meta_",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1
nats_core_jetstream_cluster_raft_group_info{cluster_name="east",jetstream_domain="Default",leader="n1",raft_group="_meta_",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_cluster_raft_group_leader 1 if this server is leader of raft group, 0 otherwise
# TYPE nats_core_jetstream_cluster_raft_group_leader gauge
nats_core_jetstream_cluster_raft_group_leader{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_cluster_raft_group_leader{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_cluster_raft_group_leader{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_cluster_raft_group_replica_peer_active Jetstream RAFT Group Peer last Active time. Very large values may imply raft is stalled
# TYPE nats_core_jetstream_cluster_raft_group_replica_peer_active gauge
nats_core_jetstream_cluster_raft_group_replica_peer_active{cluster_name="east",peer="n2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 4.80186292e+08
nats_core_jetstream_cluster_raft_group_replica_peer_active{cluster_name="east",peer="n3",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 4.80184833e+08
# HELP nats_core_jetstream_cluster_raft_group_replica_peer_current Jetstream RAFT Group Peer is current: 1 or not: 0
# TYPE nats_core_jetstream_cluster_raft_group_replica_peer_current gauge
nats_core_jetstream_cluster_raft_group_replica_peer_current{cluster_name="east",peer="n2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
nats_core_jetstream_cluster_raft_group_replica_peer_current{cluster_name="east",peer="n3",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_cluster_raft_group_replica_peer_offline Jetstream RAFT Group Peer is offline: 1 or online: 0
# TYPE nats_core_jetstream_cluster_raft_group_replica_peer_offline gauge
nats_core_jetstream_cluster_raft_group_replica_peer_offline{cluster_name="east",peer="n2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
nats_core_jetstream_cluster_raft_group_replica_peer_offline{cluster_name="east",peer="n3",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_cluster_raft_group_replicas Info about replicas from leaders perspective
# TYPE nats_core_jetstream_cluster_raft_group_replicas gauge
nats_core_jetstream_cluster_raft_group_replicas{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_cluster_raft_group_replicas{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_cluster_raft_group_replicas{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2
# HELP nats_core_jetstream_cluster_raft_group_size Number of peers in a RAFT group
# TYPE nats_core_jetstream_cluster_raft_group_size gauge
nats_core_jetstream_cluster_raft_group_size{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 3
nats_core_jetstream_cluster_raft_group_size{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 3
nats_core_jetstream_cluster_raft_group_size{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 3
# HELP nats_core_jetstream_enabled 1 if Jetstream is enabled, 0 otherwise.  A gauge.
# TYPE nats_core_jetstream_enabled gauge
nats_core_jetstream_enabled{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1
nats_core_jetstream_enabled{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1
nats_core_jetstream_enabled{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_filestore_reserved_bytes Account Reservations of jetstream filesystem storage in bytes
# TYPE nats_core_jetstream_filestore_reserved_bytes gauge
nats_core_jetstream_filestore_reserved_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_filestore_reserved_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_filestore_reserved_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_filestore_size_bytes Capacity of jetstream filesystem storage in bytes
# TYPE nats_core_jetstream_filestore_size_bytes gauge
nats_core_jetstream_filestore_size_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 7.4242679808e+10
nats_core_jetstream_filestore_size_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 7.42426368e+10
nats_core_jetstream_filestore_size_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 7.424265216e+10
# HELP nats_core_jetstream_filestore_used_bytes Consumption of jetstream filesystem storage in bytes
# TYPE nats_core_jetstream_filestore_used_bytes gauge
nats_core_jetstream_filestore_used_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 6144
nats_core_jetstream_filestore_used_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1431
nats_core_jetstream_filestore_used_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1431
# HELP nats_core_jetstream_ha_assets Number of HA (R>1) assets used by NATS
# TYPE nats_core_jetstream_ha_assets gauge
nats_core_jetstream_ha_assets{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 3
nats_core_jetstream_ha_assets{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 3
nats_core_jetstream_ha_assets{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 3
# HELP nats_core_jetstream_info  Always 1. Contains metadata for cross-reference from other time-series
# TYPE nats_core_jetstream_info gauge
nats_core_jetstream_info{server_cluster="east",server_domain="Default",server_host="127.0.0.1",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_jetstream="true",server_name="n2",server_version="2.14.6"} 1
nats_core_jetstream_info{server_cluster="east",server_domain="Default",server_host="127.0.0.1",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_jetstream="true",server_name="n3",server_version="2.14.6"} 1
nats_core_jetstream_info{server_cluster="east",server_domain="Default",server_host="127.0.0.1",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_jetstream="true",server_name="n1",server_version="2.14.6"} 1
# HELP nats_core_jetstream_memstore_reserved_bytes Account Reservations of  jetstream in-memory store in bytes
# TYPE nats_core_jetstream_memstore_reserved_bytes gauge
nats_core_jetstream_memstore_reserved_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_memstore_reserved_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_memstore_reserved_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_memstore_size_bytes Capacity of jetstream in-memory store in bytes
# TYPE nats_core_jetstream_memstore_size_bytes gauge
nats_core_jetstream_memstore_size_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 2.5769803776e+10
nats_core_jetstream_memstore_size_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 2.5769803776e+10
nats_core_jetstream_memstore_size_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2.5769803776e+10
# HELP nats_core_jetstream_memstore_used_bytes Consumption of jetstream in-memory store in bytes
# TYPE nats_core_jetstream_memstore_used_bytes gauge
nats_core_jetstream_memstore_used_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_memstore_used_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_memstore_used_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_meta_snapshot_last_duration_seconds Duration of the last meta snapshot in seconds
# TYPE nats_core_jetstream_meta_snapshot_last_duration_seconds gauge
nats_core_jetstream_meta_snapshot_last_duration_seconds{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0.000305333
nats_core_jetstream_meta_snapshot_last_duration_seconds{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0.000137292
nats_core_jetstream_meta_snapshot_last_duration_seconds{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0.000233875
# HELP nats_core_jetstream_meta_snapshot_last_timestamp_seconds Timestamp of the last meta snapshot as Unix epoch in seconds
# TYPE nats_core_jetstream_meta_snapshot_last_timestamp_seconds gauge
nats_core_jetstream_meta_snapshot_last_timestamp_seconds{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1.788403322e+09
nats_core_jetstream_meta_snapshot_last_timestamp_seconds{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1.788403322e+09
nats_core_jetstream_meta_snapshot_last_timestamp_seconds{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1.788403322e+09
# HELP nats_core_jetstream_meta_snapshot_pending_bytes Size in bytes of pending entries awaiting meta snapshot
# TYPE nats_core_jetstream_meta_snapshot_pending_bytes gauge
nats_core_jetstream_meta_snapshot_pending_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_meta_snapshot_pending_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_meta_snapshot_pending_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_meta_snapshot_pending_entries Number of pending entries awaiting meta snapshot
# TYPE nats_core_jetstream_meta_snapshot_pending_entries gauge
nats_core_jetstream_meta_snapshot_pending_entries{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_meta_snapshot_pending_entries{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_meta_snapshot_pending_entries{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_server_jetstream_disabled JetStream disabled or not
# TYPE nats_core_jetstream_server_jetstream_disabled gauge
nats_core_jetstream_server_jetstream_disabled{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_server_jetstream_disabled{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_server_jetstream_disabled{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_server_max_memory JetStream Max Memory
# TYPE nats_core_jetstream_server_max_memory gauge
nats_core_jetstream_server_max_memory{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 2.5769803776e+10
nats_core_jetstream_server_max_memory{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 2.5769803776e+10
nats_core_jetstream_server_max_memory{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2.5769803776e+10
# HELP nats_core_jetstream_server_max_storage JetStream Max Storage
# TYPE nats_core_jetstream_server_max_storage gauge
nats_core_jetstream_server_max_storage{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 7.4242679808e+10
nats_core_jetstream_server_max_storage{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 7.42426368e+10
nats_core_jetstream_server_max_storage{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 7.424265216e+10
# HELP nats_core_jetstream_server_total_consumer_leaders Number of consumer leaders on this server (sum across servers gives total consumer count)
# TYPE nats_core_jetstream_server_total_consumer_leaders gauge
nats_core_jetstream_server_total_consumer_leaders{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1
nats_core_jetstream_server_total_consumer_leaders{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_server_total_consumer_leaders{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_server_total_consumers Number of consumer replicas on this server (includes R1 consumers)
# TYPE nats_core_jetstream_server_total_consumers gauge
nats_core_jetstream_server_total_consumers{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1
nats_core_jetstream_server_total_consumers{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1
nats_core_jetstream_server_total_consumers{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_server_total_message_bytes Total number of bytes stored in JetStream
# TYPE nats_core_jetstream_server_total_message_bytes gauge
nats_core_jetstream_server_total_message_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 6144
nats_core_jetstream_server_total_message_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1431
nats_core_jetstream_server_total_message_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1431
# HELP nats_core_jetstream_server_total_messages Total number of stored messages in JetStream
# TYPE nats_core_jetstream_server_total_messages gauge
nats_core_jetstream_server_total_messages{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 90
nats_core_jetstream_server_total_messages{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 30
nats_core_jetstream_server_total_messages{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 30
# HELP nats_core_jetstream_server_total_stream_leaders Number of stream leaders on this server (sum across servers gives total stream count)
# TYPE nats_core_jetstream_server_total_stream_leaders gauge
nats_core_jetstream_server_total_stream_leaders{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 3
nats_core_jetstream_server_total_stream_leaders{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_server_total_stream_leaders{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_server_total_streams Number of stream replicas on this server (includes R1 streams)
# TYPE nats_core_jetstream_server_total_streams gauge
nats_core_jetstream_server_total_streams{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 3
nats_core_jetstream_server_total_streams{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1
nats_core_jetstream_server_total_streams{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_mem_bytes Server memory gauge
# TYPE nats_core_mem_bytes gauge
nats_core_mem_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 2.875392e+07
nats_core_mem_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 2.7918336e+07
nats_core_mem_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 3.0015488e+07
# HELP nats_core_raftz_meta_applied Highest applied log entry index of the meta Raft group
# TYPE nats_core_raftz_meta_applied gauge
nats_core_raftz_meta_applied{cluster_name="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_id="east",server_name="n2"} 7
nats_core_raftz_meta_applied{cluster_name="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_id="east",server_name="n3"} 7
nats_core_raftz_meta_applied{cluster_name="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_id="east",server_name="n1"} 7
# HELP nats_core_raftz_meta_committed Highest committed log entry index of the meta Raft group
# TYPE nats_core_raftz_meta_committed gauge
nats_core_raftz_meta_committed{cluster_name="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_id="east",server_name="n2"} 7
nats_core_raftz_meta_committed{cluster_name="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_id="east",server_name="n3"} 7
nats_core_raftz_meta_committed{cluster_name="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_id="east",server_name="n1"} 7
# HELP nats_core_raftz_meta_pindex Log entry index at last snapshot of the meta Raft group
# TYPE nats_core_raftz_meta_pindex gauge
nats_core_raftz_meta_pindex{cluster_name="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_id="east",server_name="n2"} 7
nats_core_raftz_meta_pindex{cluster_name="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_id="east",server_name="n3"} 7
nats_core_raftz_meta_pindex{cluster_name="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_id="east",server_name="n1"} 7
# HELP nats_core_recv_bytes Number of bytes received by the server from all connections including clients, routes, gateways and leafnodes counter
# TYPE nats_core_recv_bytes counter
nats_core_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 99164
nats_core_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 101765
nats_core_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 140317
# HELP nats_core_recv_from_client_bytes_total Number of bytes received by the server from client connections (excludes routes, gateways, leafnodes) counter
# TYPE nats_core_recv_from_client_bytes_total counter
nats_core_recv_from_client_bytes_total{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_recv_from_client_bytes_total{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_recv_from_client_bytes_total{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 3279
# HELP nats_core_recv_from_client_msgs_total Number of messages received by the server from client connections (excludes routes, gateways, leafnodes) counter
# TYPE nats_core_recv_from_client_msgs_total counter
nats_core_recv_from_client_msgs_total{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_recv_from_client_msgs_total{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_recv_from_client_msgs_total{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 76
# HELP nats_core_recv_msgs_count Number of messages received by the server from all connections including clients, routes, gateways and leafnodes counter
# TYPE nats_core_recv_msgs_count counter
nats_core_recv_msgs_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 650
nats_core_recv_msgs_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 425
nats_core_recv_msgs_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 661
# HELP nats_core_route_count Number of active routes gauge
# TYPE nats_core_route_count gauge
nats_core_route_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 8
nats_core_route_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 8
nats_core_route_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 8
# HELP nats_core_route_pending_bytes Number of bytes pending in the route gauge
# TYPE nats_core_route_pending_bytes gauge
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="11"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="8"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="9"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="15"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="12"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="14"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="9"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="11"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="13"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="15"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="10"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="11"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="9"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="15"} 0
# HELP nats_core_route_recv_bytes Number of bytes received over the route counter
# TYPE nats_core_route_recv_bytes counter
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="11"} 871
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="8"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="9"} 59163
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="12"} 39130
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="15"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="12"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="14"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="9"} 53101
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="11"} 48664
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="13"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="15"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="10"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="11"} 142
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="8"} 82388
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="9"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="13"} 54508
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="15"} 0
# HELP nats_core_route_recv_msg_count Number of messages received over the route counter
# TYPE nats_core_route_recv_msg_count counter
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="11"} 50
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="8"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="9"} 384
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="12"} 216
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="15"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="12"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="14"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="9"} 201
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="11"} 224
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="13"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="15"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="10"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="11"} 20
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="8"} 383
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="9"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="13"} 182
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="15"} 0
# HELP nats_core_route_sent_bytes Number of bytes sent over the route counter
# TYPE nats_core_route_sent_bytes counter
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="11"} 142
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="8"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="9"} 82388
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="12"} 48664
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="15"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="12"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="14"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="9"} 54508
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="11"} 39130
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="13"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="15"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="10"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="11"} 871
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="8"} 59163
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="9"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="13"} 53101
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="15"} 0
# HELP nats_core_route_sent_msg_count Number of messages sent over the route counter
# TYPE nats_core_route_sent_msg_count counter
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="11"} 20
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="8"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="9"} 383
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="12"} 224
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="15"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="12"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="14"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="9"} 182
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="11"} 216
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="13"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="15"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="10"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="11"} 50
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="8"} 384
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="9"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="13"} 201
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="15"} 0
# HELP nats_core_rtt_nanoseconds RTT in nanoseconds gauge
# TYPE nats_core_rtt_nanoseconds gauge
nats_core_rtt_nanoseconds{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 491666
nats_core_rtt_nanoseconds{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 431416
nats_core_rtt_nanoseconds{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 406666
# HELP nats_core_sent_bytes Number of bytes sent by the server to all connections including clients, routes, gateways and leafnodes counter
# TYPE nats_core_sent_bytes counter
nats_core_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 131194
nats_core_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 93638
nats_core_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 175556
# HELP nats_core_sent_msgs_count Number of messages sent by the server to all connections including clients, routes, gateways and leafnodes counter
# TYPE nats_core_sent_msgs_count counter
nats_core_sent_msgs_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 627
nats_core_sent_msgs_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 398
nats_core_sent_msgs_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 704
# HELP nats_core_sent_to_client_bytes_total Number of bytes sent by the server to client connections (excludes routes, gateways, leafnodes) counter
# TYPE nats_core_sent_to_client_bytes_total counter
nats_core_sent_to_client_bytes_total{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_sent_to_client_bytes_total{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_sent_to_client_bytes_total{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 62421
# HELP nats_core_sent_to_client_msgs_total Number of messages sent by the server to client connections (excludes routes, gateways, leafnodes) counter
# TYPE nats_core_sent_to_client_msgs_total counter
nats_core_sent_to_client_msgs_total{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_sent_to_client_msgs_total{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_sent_to_client_msgs_total{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 69
# HELP nats_core_slow_consumer_count Number of slow consumers gauge
# TYPE nats_core_slow_consumer_count gauge
nats_core_slow_consumer_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_slow_consumer_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_slow_consumer_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_start_time Server start time gauge
# TYPE nats_core_start_time gauge
nats_core_start_time{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1.788403202356733e+18
nats_core_start_time{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1.788403202526818e+18
nats_core_start_time{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1.788403202188888e+18
# HELP nats_core_subs_count Current number of subscriptions gauge
# TYPE nats_core_subs_count gauge
nats_core_subs_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 261
nats_core_subs_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 259
nats_core_subs_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 259
# HELP nats_core_total_connection_count Total number of client connections serviced counter
# TYPE nats_core_total_connection_count counter
nats_core_total_connection_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_total_connection_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_total_connection_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 11
# HELP nats_core_uptime Server uptime gauge
# TYPE nats_core_uptime gauge
nats_core_uptime{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 126.612001
nats_core_uptime{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 126.441838
nats_core_uptime{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 126.779678
# HELP nats_jetstream_advisory_count Number of JetStream Advisory listeners that are running
# TYPE nats_jetstream_advisory_count gauge
nats_jetstream_advisory_count 0
# HELP nats_latency_observations_count Number of Service Latency listeners that are running
# TYPE nats_latency_observations_count gauge
nats_latency_observations_count 0
# HELP nats_stream_consumer_count Total number of consumers from a stream
# TYPE nats_stream_consumer_count gauge
nats_stream_consumer_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 0
nats_stream_consumer_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 0
nats_stream_consumer_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 0
# HELP nats_stream_first_seq First sequence from a stream
# TYPE nats_stream_first_seq gauge
nats_stream_first_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 1
nats_stream_first_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 1
nats_stream_first_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 1
# HELP nats_stream_last_seq Last sequence from a stream
# TYPE nats_stream_last_seq gauge
nats_stream_last_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 30
nats_stream_last_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 30
nats_stream_last_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 30
# HELP nats_stream_subject_count Total number of subjects in a stream
# TYPE nats_stream_subject_count gauge
nats_stream_subject_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 1
nats_stream_subject_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 1
nats_stream_subject_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 1
# HELP nats_stream_total_bytes Total stored bytes from a stream
# TYPE nats_stream_total_bytes gauge
nats_stream_total_bytes{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 3282
nats_stream_total_bytes{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 1431
nats_stream_total_bytes{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 1431
# HELP nats_stream_total_messages Total number of messages from a stream
# TYPE nats_stream_total_messages gauge
nats_stream_total_messages{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 30
nats_stream_total_messages{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 30
nats_stream_total_messages{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 30
# HELP nats_survey_duration_seconds Time it took to gather the surveyed data histogram
# TYPE nats_survey_duration_seconds summary
nats_survey_duration_seconds_sum 0.011022375000000001
nats_survey_duration_seconds_count 2
# HELP nats_survey_expected_count Number of remote hosts expected to responded gauge
# TYPE nats_survey_expected_count gauge
nats_survey_expected_count 3
# HELP nats_survey_surveyed_count Number of remote hosts successfully surveyed gauge
# TYPE nats_survey_surveyed_count gauge
nats_survey_surveyed_count 3
# HELP nats_up 1 if connected to NATS, 0 otherwise.  A gauge.
# TYPE nats_up gauge
nats_up 1

[http 200]
```


## Run S3 · `--prefix x` — the flag whose help says "Replace the default prefix for all the metrics"

```
$ nats-surveyor -s nats://127.0.0.1:4291 --user sys --password sys -c 3 -p 7778 --prefix x --jsz all
```

Surveyor log (first lines):

```
2026-09-03T04:42:08+02:00 [INFO] NATS_Surveyor - <host> connected to NATS Deployment: 127.0.0.1:4291
2026-09-03T04:42:08+02:00 [INFO] Prometheus exporter listening at http://0.0.0.0:7778/metrics
```

Scrape of `http://127.0.0.1:7778/metrics` — 102 `# HELP` lines kept, 2 `go_*`/`process_*`/`promhttp_*` series (8 lines) dropped:

```
# HELP nats_consumer_ack_floor_consumer_seq Number of ack floor consumer seq from a consumer
# TYPE nats_consumer_ack_floor_consumer_seq gauge
nats_consumer_ack_floor_consumer_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 0
nats_consumer_ack_floor_consumer_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 0
nats_consumer_ack_floor_consumer_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 0
# HELP nats_consumer_ack_floor_stream_seq Number of ack floor stream seq from a consumer
# TYPE nats_consumer_ack_floor_stream_seq gauge
nats_consumer_ack_floor_stream_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 0
nats_consumer_ack_floor_stream_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 0
nats_consumer_ack_floor_stream_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 0
# HELP nats_consumer_delivered_consumer_seq Latest consumer sequence number of a stream consumer
# TYPE nats_consumer_delivered_consumer_seq gauge
nats_consumer_delivered_consumer_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 20
nats_consumer_delivered_consumer_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 20
nats_consumer_delivered_consumer_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 20
# HELP nats_consumer_delivered_stream_seq Latest stream sequence number of a stream
# TYPE nats_consumer_delivered_stream_seq gauge
nats_consumer_delivered_stream_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 10
nats_consumer_delivered_stream_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 10
nats_consumer_delivered_stream_seq{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 10
# HELP nats_consumer_num_ack_pending Number of pending acks from a consumer
# TYPE nats_consumer_num_ack_pending gauge
nats_consumer_num_ack_pending{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 10
nats_consumer_num_ack_pending{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 10
nats_consumer_num_ack_pending{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 10
# HELP nats_consumer_num_pending Number of pending messages from a consumer
# TYPE nats_consumer_num_pending gauge
nats_consumer_num_pending{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 20
nats_consumer_num_pending{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 0
nats_consumer_num_pending{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 0
# HELP nats_consumer_num_redelivered Number of redelivered messages from a consumer
# TYPE nats_consumer_num_redelivered gauge
nats_consumer_num_redelivered{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 10
nats_consumer_num_redelivered{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 10
nats_consumer_num_redelivered{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 10
# HELP nats_consumer_num_waiting Number of inflight fetch requests from a pull consumer
# TYPE nats_consumer_num_waiting gauge
nats_consumer_num_waiting{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 0
nats_consumer_num_waiting{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 0
nats_consumer_num_waiting{account="$G",account_name="$G",cluster_name="east",consumer_leader="n2",consumer_name="shipping",raft_group="C-R3F-xfHKk1O2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 0
# HELP nats_core_account_bytes_recv The number of bytes received on this account across all connections
# TYPE nats_core_account_bytes_recv counter
nats_core_account_bytes_recv{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 871
nats_core_account_bytes_recv{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_bytes_recv{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2469
nats_core_account_bytes_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 202188
nats_core_account_bytes_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 209048
nats_core_account_bytes_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 326282
# HELP nats_core_account_bytes_sent The number of bytes sent on this account across all connections
# TYPE nats_core_account_bytes_sent counter
nats_core_account_bytes_sent{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 2884
nats_core_account_bytes_sent{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_bytes_sent{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 11777
nats_core_account_bytes_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 144705
nats_core_account_bytes_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 106029
nats_core_account_bytes_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 206331
# HELP nats_core_account_conn_count The number of client connections to this account
# TYPE nats_core_account_conn_count gauge
nats_core_account_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
nats_core_account_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_account_count The number of accounts detected
# TYPE nats_core_account_count gauge
nats_core_account_count 2
# HELP nats_core_account_jetstream_consumer_count The number of consumers per stream for this account
# TYPE nats_core_account_jetstream_consumer_count gauge
nats_core_account_jetstream_consumer_count{account="$G",account_name="$G",raft_group="S-R1F-4xqNIVlf",stream="ORDERS_AGG"} 0
nats_core_account_jetstream_consumer_count{account="$G",account_name="$G",raft_group="S-R1F-Cp5pI54v",stream="ORDERS_MIRROR"} 0
nats_core_account_jetstream_consumer_count{account="$G",account_name="$G",raft_group="S-R3F-zHrMNfYE",stream="ORDERS"} 1
# HELP nats_core_account_jetstream_enabled Whether JetStream is enabled or not for this account
# TYPE nats_core_account_jetstream_enabled gauge
nats_core_account_jetstream_enabled{account="$G",account_name="$G"} 1
nats_core_account_jetstream_enabled{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_memory_reserved The number of bytes reserved by JetStream memory
# TYPE nats_core_account_jetstream_memory_reserved gauge
nats_core_account_jetstream_memory_reserved{account="$G",account_name="$G"} 1.8446744073709552e+19
nats_core_account_jetstream_memory_reserved{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_memory_used The number of bytes used by JetStream memory
# TYPE nats_core_account_jetstream_memory_used gauge
nats_core_account_jetstream_memory_used{account="$G",account_name="$G"} 0
nats_core_account_jetstream_memory_used{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_replica_count The number of replicas per stream for this account
# TYPE nats_core_account_jetstream_replica_count gauge
nats_core_account_jetstream_replica_count{account="$G",account_name="$G",raft_group="S-R1F-4xqNIVlf",stream="ORDERS_AGG"} 1
nats_core_account_jetstream_replica_count{account="$G",account_name="$G",raft_group="S-R1F-Cp5pI54v",stream="ORDERS_MIRROR"} 1
nats_core_account_jetstream_replica_count{account="$G",account_name="$G",raft_group="S-R3F-zHrMNfYE",stream="ORDERS"} 3
# HELP nats_core_account_jetstream_storage_reserved The number of bytes reserved by JetStream storage
# TYPE nats_core_account_jetstream_storage_reserved gauge
nats_core_account_jetstream_storage_reserved{account="$G",account_name="$G"} 1.8446744073709552e+19
nats_core_account_jetstream_storage_reserved{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_storage_used The number of bytes used by JetStream storage
# TYPE nats_core_account_jetstream_storage_used gauge
nats_core_account_jetstream_storage_used{account="$G",account_name="$G"} 9006
nats_core_account_jetstream_storage_used{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_stream_count The number of streams in this account
# TYPE nats_core_account_jetstream_stream_count gauge
nats_core_account_jetstream_stream_count{account="$G",account_name="$G"} 3
nats_core_account_jetstream_stream_count{account="$SYS",account_name="$SYS"} 0
# HELP nats_core_account_jetstream_tiered_storage_reserved The number of bytes reserved by JetStream storage tier
# TYPE nats_core_account_jetstream_tiered_storage_reserved gauge
nats_core_account_jetstream_tiered_storage_reserved{account="$G",account_name="$G",tier="R1"} 0
nats_core_account_jetstream_tiered_storage_reserved{account="$G",account_name="$G",tier="R3"} 0
# HELP nats_core_account_jetstream_tiered_storage_used The number of bytes used by JetStream storage tier
# TYPE nats_core_account_jetstream_tiered_storage_used gauge
nats_core_account_jetstream_tiered_storage_used{account="$G",account_name="$G",tier="R1"} 4713
nats_core_account_jetstream_tiered_storage_used{account="$G",account_name="$G",tier="R3"} 1431
# HELP nats_core_account_leaf_count The number of leafnode connections to this account
# TYPE nats_core_account_leaf_count gauge
nats_core_account_leaf_count{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_leaf_count{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_leaf_count{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
nats_core_account_leaf_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_leaf_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_leaf_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_account_msgs_recv The number of messages received on this account across all connections
# TYPE nats_core_account_msgs_recv counter
nats_core_account_msgs_recv{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 50
nats_core_account_msgs_recv{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_msgs_recv{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 83
nats_core_account_msgs_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1258
nats_core_account_msgs_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 896
nats_core_account_msgs_recv{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1215
# HELP nats_core_account_msgs_sent The number of messages sent on this account across all connections
# TYPE nats_core_account_msgs_sent counter
nats_core_account_msgs_sent{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 80
nats_core_account_msgs_sent{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_msgs_sent{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 83
nats_core_account_msgs_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 634
nats_core_account_msgs_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 419
nats_core_account_msgs_sent{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 681
# HELP nats_core_account_slow_consumer_count The number of slow consumers detected in this account
# TYPE nats_core_account_slow_consumer_count gauge
nats_core_account_slow_consumer_count{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_slow_consumer_count{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_slow_consumer_count{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
nats_core_account_slow_consumer_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_slow_consumer_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_slow_consumer_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_account_sub_count The number of subscriptions on this account
# TYPE nats_core_account_sub_count gauge
nats_core_account_sub_count{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 32
nats_core_account_sub_count{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 30
nats_core_account_sub_count{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 30
nats_core_account_sub_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 230
nats_core_account_sub_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 230
nats_core_account_sub_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 230
# HELP nats_core_account_total_conn_count The combined current number of client and leafnode connections to this account
# TYPE nats_core_account_total_conn_count gauge
nats_core_account_total_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_total_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_total_conn_count{account="$G",account_name="$G",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
nats_core_account_total_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_account_total_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_account_total_conn_count{account="$SYS",account_name="$SYS",server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_active_account_count Number of active accounts gauge
# TYPE nats_core_active_account_count gauge
nats_core_active_account_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 2
nats_core_active_account_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 2
nats_core_active_account_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2
# HELP nats_core_connection_count Current number of client connections gauge
# TYPE nats_core_connection_count gauge
nats_core_connection_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_connection_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_connection_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_core_count Machine cores gauge
# TYPE nats_core_core_count gauge
nats_core_core_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 10
nats_core_core_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 10
nats_core_core_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 10
# HELP nats_core_cpu_percentage Server cpu utilization gauge
# TYPE nats_core_cpu_percentage gauge
nats_core_cpu_percentage{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0.3
nats_core_cpu_percentage{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0.3
nats_core_cpu_percentage{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0.3
# HELP nats_core_gateway_count Number of active gateways gauge
# TYPE nats_core_gateway_count gauge
nats_core_gateway_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_gateway_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_gateway_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_go_memlimit_bytes Server GOMEMLIMIT gauge (0 if not set)
# TYPE nats_core_go_memlimit_bytes gauge
nats_core_go_memlimit_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_go_memlimit_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_go_memlimit_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_gomaxprocs Server GOMAXPROCS gauge (maximum number of threads to use for running goroutines at once)
# TYPE nats_core_gomaxprocs gauge
nats_core_gomaxprocs{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 10
nats_core_gomaxprocs{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 10
nats_core_gomaxprocs{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 10
# HELP nats_core_info General Server information Summary gauge
# TYPE nats_core_info gauge
nats_core_info{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_version="2.14.6"} 1
nats_core_info{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_version="2.14.6"} 1
nats_core_info{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_version="2.14.6"} 1
# HELP nats_core_jetstream_accounts Number of NATS Accounts present on a Jetstream server
# TYPE nats_core_jetstream_accounts gauge
nats_core_jetstream_accounts{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1
nats_core_jetstream_accounts{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1
nats_core_jetstream_accounts{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_api_errors Number of Jetstream API Errors. Value is 0 when server starts
# TYPE nats_core_jetstream_api_errors counter
nats_core_jetstream_api_errors{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_api_errors{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_api_errors{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_api_pending Number of Jetstream API in the queue waiting to be processed
# TYPE nats_core_jetstream_api_pending gauge
nats_core_jetstream_api_pending{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_api_pending{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_api_pending{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_api_requests Number of Jetstream API Requests processed. Value is 0 when server starts
# TYPE nats_core_jetstream_api_requests counter
nats_core_jetstream_api_requests{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 11
nats_core_jetstream_api_requests{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_api_requests{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 4
# HELP nats_core_jetstream_cluster_raft_group_info Provides metadata about a RAFT Group
# TYPE nats_core_jetstream_cluster_raft_group_info gauge
nats_core_jetstream_cluster_raft_group_info{cluster_name="_meta_",jetstream_domain="Default",leader="n1",raft_group="_meta_",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1
nats_core_jetstream_cluster_raft_group_info{cluster_name="_meta_",jetstream_domain="Default",leader="n1",raft_group="_meta_",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1
nats_core_jetstream_cluster_raft_group_info{cluster_name="east",jetstream_domain="Default",leader="n1",raft_group="_meta_",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_cluster_raft_group_leader 1 if this server is leader of raft group, 0 otherwise
# TYPE nats_core_jetstream_cluster_raft_group_leader gauge
nats_core_jetstream_cluster_raft_group_leader{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_cluster_raft_group_leader{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_cluster_raft_group_leader{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_cluster_raft_group_replica_peer_active Jetstream RAFT Group Peer last Active time. Very large values may imply raft is stalled
# TYPE nats_core_jetstream_cluster_raft_group_replica_peer_active gauge
nats_core_jetstream_cluster_raft_group_replica_peer_active{cluster_name="east",peer="n2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 5.45156791e+08
nats_core_jetstream_cluster_raft_group_replica_peer_active{cluster_name="east",peer="n3",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 5.45158958e+08
# HELP nats_core_jetstream_cluster_raft_group_replica_peer_current Jetstream RAFT Group Peer is current: 1 or not: 0
# TYPE nats_core_jetstream_cluster_raft_group_replica_peer_current gauge
nats_core_jetstream_cluster_raft_group_replica_peer_current{cluster_name="east",peer="n2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
nats_core_jetstream_cluster_raft_group_replica_peer_current{cluster_name="east",peer="n3",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_cluster_raft_group_replica_peer_offline Jetstream RAFT Group Peer is offline: 1 or online: 0
# TYPE nats_core_jetstream_cluster_raft_group_replica_peer_offline gauge
nats_core_jetstream_cluster_raft_group_replica_peer_offline{cluster_name="east",peer="n2",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
nats_core_jetstream_cluster_raft_group_replica_peer_offline{cluster_name="east",peer="n3",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_cluster_raft_group_replicas Info about replicas from leaders perspective
# TYPE nats_core_jetstream_cluster_raft_group_replicas gauge
nats_core_jetstream_cluster_raft_group_replicas{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_cluster_raft_group_replicas{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_cluster_raft_group_replicas{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2
# HELP nats_core_jetstream_cluster_raft_group_size Number of peers in a RAFT group
# TYPE nats_core_jetstream_cluster_raft_group_size gauge
nats_core_jetstream_cluster_raft_group_size{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 3
nats_core_jetstream_cluster_raft_group_size{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 3
nats_core_jetstream_cluster_raft_group_size{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 3
# HELP nats_core_jetstream_enabled 1 if Jetstream is enabled, 0 otherwise.  A gauge.
# TYPE nats_core_jetstream_enabled gauge
nats_core_jetstream_enabled{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1
nats_core_jetstream_enabled{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1
nats_core_jetstream_enabled{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_filestore_reserved_bytes Account Reservations of jetstream filesystem storage in bytes
# TYPE nats_core_jetstream_filestore_reserved_bytes gauge
nats_core_jetstream_filestore_reserved_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_filestore_reserved_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_filestore_reserved_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_filestore_size_bytes Capacity of jetstream filesystem storage in bytes
# TYPE nats_core_jetstream_filestore_size_bytes gauge
nats_core_jetstream_filestore_size_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 7.4242679808e+10
nats_core_jetstream_filestore_size_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 7.42426368e+10
nats_core_jetstream_filestore_size_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 7.424265216e+10
# HELP nats_core_jetstream_filestore_used_bytes Consumption of jetstream filesystem storage in bytes
# TYPE nats_core_jetstream_filestore_used_bytes gauge
nats_core_jetstream_filestore_used_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 6144
nats_core_jetstream_filestore_used_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1431
nats_core_jetstream_filestore_used_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1431
# HELP nats_core_jetstream_ha_assets Number of HA (R>1) assets used by NATS
# TYPE nats_core_jetstream_ha_assets gauge
nats_core_jetstream_ha_assets{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 3
nats_core_jetstream_ha_assets{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 3
nats_core_jetstream_ha_assets{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 3
# HELP nats_core_jetstream_info  Always 1. Contains metadata for cross-reference from other time-series
# TYPE nats_core_jetstream_info gauge
nats_core_jetstream_info{server_cluster="east",server_domain="Default",server_host="127.0.0.1",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_jetstream="true",server_name="n2",server_version="2.14.6"} 1
nats_core_jetstream_info{server_cluster="east",server_domain="Default",server_host="127.0.0.1",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_jetstream="true",server_name="n3",server_version="2.14.6"} 1
nats_core_jetstream_info{server_cluster="east",server_domain="Default",server_host="127.0.0.1",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_jetstream="true",server_name="n1",server_version="2.14.6"} 1
# HELP nats_core_jetstream_memstore_reserved_bytes Account Reservations of  jetstream in-memory store in bytes
# TYPE nats_core_jetstream_memstore_reserved_bytes gauge
nats_core_jetstream_memstore_reserved_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_memstore_reserved_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_memstore_reserved_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_memstore_size_bytes Capacity of jetstream in-memory store in bytes
# TYPE nats_core_jetstream_memstore_size_bytes gauge
nats_core_jetstream_memstore_size_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 2.5769803776e+10
nats_core_jetstream_memstore_size_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 2.5769803776e+10
nats_core_jetstream_memstore_size_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2.5769803776e+10
# HELP nats_core_jetstream_memstore_used_bytes Consumption of jetstream in-memory store in bytes
# TYPE nats_core_jetstream_memstore_used_bytes gauge
nats_core_jetstream_memstore_used_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_memstore_used_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_memstore_used_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_meta_snapshot_last_duration_seconds Duration of the last meta snapshot in seconds
# TYPE nats_core_jetstream_meta_snapshot_last_duration_seconds gauge
nats_core_jetstream_meta_snapshot_last_duration_seconds{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0.000305333
nats_core_jetstream_meta_snapshot_last_duration_seconds{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0.000137292
nats_core_jetstream_meta_snapshot_last_duration_seconds{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0.000233875
# HELP nats_core_jetstream_meta_snapshot_last_timestamp_seconds Timestamp of the last meta snapshot as Unix epoch in seconds
# TYPE nats_core_jetstream_meta_snapshot_last_timestamp_seconds gauge
nats_core_jetstream_meta_snapshot_last_timestamp_seconds{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1.788403322e+09
nats_core_jetstream_meta_snapshot_last_timestamp_seconds{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1.788403322e+09
nats_core_jetstream_meta_snapshot_last_timestamp_seconds{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1.788403322e+09
# HELP nats_core_jetstream_meta_snapshot_pending_bytes Size in bytes of pending entries awaiting meta snapshot
# TYPE nats_core_jetstream_meta_snapshot_pending_bytes gauge
nats_core_jetstream_meta_snapshot_pending_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_meta_snapshot_pending_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_meta_snapshot_pending_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_meta_snapshot_pending_entries Number of pending entries awaiting meta snapshot
# TYPE nats_core_jetstream_meta_snapshot_pending_entries gauge
nats_core_jetstream_meta_snapshot_pending_entries{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_meta_snapshot_pending_entries{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_meta_snapshot_pending_entries{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_server_jetstream_disabled JetStream disabled or not
# TYPE nats_core_jetstream_server_jetstream_disabled gauge
nats_core_jetstream_server_jetstream_disabled{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_jetstream_server_jetstream_disabled{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_server_jetstream_disabled{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_server_max_memory JetStream Max Memory
# TYPE nats_core_jetstream_server_max_memory gauge
nats_core_jetstream_server_max_memory{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 2.5769803776e+10
nats_core_jetstream_server_max_memory{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 2.5769803776e+10
nats_core_jetstream_server_max_memory{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 2.5769803776e+10
# HELP nats_core_jetstream_server_max_storage JetStream Max Storage
# TYPE nats_core_jetstream_server_max_storage gauge
nats_core_jetstream_server_max_storage{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 7.4242679808e+10
nats_core_jetstream_server_max_storage{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 7.42426368e+10
nats_core_jetstream_server_max_storage{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 7.424265216e+10
# HELP nats_core_jetstream_server_total_consumer_leaders Number of consumer leaders on this server (sum across servers gives total consumer count)
# TYPE nats_core_jetstream_server_total_consumer_leaders gauge
nats_core_jetstream_server_total_consumer_leaders{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1
nats_core_jetstream_server_total_consumer_leaders{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_server_total_consumer_leaders{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_server_total_consumers Number of consumer replicas on this server (includes R1 consumers)
# TYPE nats_core_jetstream_server_total_consumers gauge
nats_core_jetstream_server_total_consumers{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1
nats_core_jetstream_server_total_consumers{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1
nats_core_jetstream_server_total_consumers{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_jetstream_server_total_message_bytes Total number of bytes stored in JetStream
# TYPE nats_core_jetstream_server_total_message_bytes gauge
nats_core_jetstream_server_total_message_bytes{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 6144
nats_core_jetstream_server_total_message_bytes{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1431
nats_core_jetstream_server_total_message_bytes{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1431
# HELP nats_core_jetstream_server_total_messages Total number of stored messages in JetStream
# TYPE nats_core_jetstream_server_total_messages gauge
nats_core_jetstream_server_total_messages{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 90
nats_core_jetstream_server_total_messages{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 30
nats_core_jetstream_server_total_messages{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 30
# HELP nats_core_jetstream_server_total_stream_leaders Number of stream leaders on this server (sum across servers gives total stream count)
# TYPE nats_core_jetstream_server_total_stream_leaders gauge
nats_core_jetstream_server_total_stream_leaders{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 3
nats_core_jetstream_server_total_stream_leaders{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_jetstream_server_total_stream_leaders{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_jetstream_server_total_streams Number of stream replicas on this server (includes R1 streams)
# TYPE nats_core_jetstream_server_total_streams gauge
nats_core_jetstream_server_total_streams{cluster_name="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 3
nats_core_jetstream_server_total_streams{cluster_name="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1
nats_core_jetstream_server_total_streams{cluster_name="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1
# HELP nats_core_mem_bytes Server memory gauge
# TYPE nats_core_mem_bytes gauge
nats_core_mem_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 2.8934144e+07
nats_core_mem_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 2.8196864e+07
nats_core_mem_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 3.0031872e+07
# HELP nats_core_recv_bytes Number of bytes received by the server from all connections including clients, routes, gateways and leafnodes counter
# TYPE nats_core_recv_bytes counter
nats_core_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 101889
nats_core_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 104448
nats_core_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 162380
# HELP nats_core_recv_from_client_bytes_total Number of bytes received by the server from client connections (excludes routes, gateways, leafnodes) counter
# TYPE nats_core_recv_from_client_bytes_total counter
nats_core_recv_from_client_bytes_total{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_recv_from_client_bytes_total{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_recv_from_client_bytes_total{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 3821
# HELP nats_core_recv_from_client_msgs_total Number of messages received by the server from client connections (excludes routes, gateways, leafnodes) counter
# TYPE nats_core_recv_from_client_msgs_total counter
nats_core_recv_from_client_msgs_total{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_recv_from_client_msgs_total{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_recv_from_client_msgs_total{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 83
# HELP nats_core_recv_msgs_count Number of messages received by the server from all connections including clients, routes, gateways and leafnodes counter
# TYPE nats_core_recv_msgs_count counter
nats_core_recv_msgs_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 678
nats_core_recv_msgs_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 447
nats_core_recv_msgs_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 698
# HELP nats_core_route_count Number of active routes gauge
# TYPE nats_core_route_count gauge
nats_core_route_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 8
nats_core_route_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 8
nats_core_route_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 8
# HELP nats_core_route_pending_bytes Number of bytes pending in the route gauge
# TYPE nats_core_route_pending_bytes gauge
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="11"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="8"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="9"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="15"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="12"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="14"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="9"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="11"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="13"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="15"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="10"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="11"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="9"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_pending_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="15"} 0
# HELP nats_core_route_recv_bytes Number of bytes received over the route counter
# TYPE nats_core_route_recv_bytes counter
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="11"} 871
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="8"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="9"} 61650
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="12"} 39368
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="15"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="12"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="14"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="9"} 55438
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="11"} 49010
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="13"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="15"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="10"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="11"} 142
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="8"} 93723
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="9"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="13"} 64694
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_recv_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="15"} 0
# HELP nats_core_route_recv_msg_count Number of messages received over the route counter
# TYPE nats_core_route_recv_msg_count counter
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="11"} 50
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="8"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="9"} 404
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="12"} 224
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="15"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="12"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="14"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="9"} 215
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="11"} 232
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="13"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="15"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="10"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="11"} 20
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="8"} 401
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="9"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="13"} 194
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_recv_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="15"} 0
# HELP nats_core_route_sent_bytes Number of bytes sent over the route counter
# TYPE nats_core_route_sent_bytes counter
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="11"} 142
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="8"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="9"} 93723
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="12"} 49010
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="15"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="12"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="14"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="9"} 64694
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="11"} 39368
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="13"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="15"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="10"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="11"} 871
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="8"} 61650
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="9"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="13"} 55438
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="15"} 0
# HELP nats_core_route_sent_msg_count Number of messages sent over the route counter
# TYPE nats_core_route_sent_msg_count counter
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="11"} 20
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="8"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n1",server_route_name_id="9"} 401
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="12"} 232
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="13"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",server_route_name="n3",server_route_name_id="15"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="10"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="12"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="14"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n1",server_route_name_id="9"} 194
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="11"} 224
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="13"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="15"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",server_route_name="n2",server_route_name_id="8"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="10"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="11"} 50
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="8"} 404
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n2",server_route_name_id="9"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="12"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="13"} 215
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="14"} 0
nats_core_route_sent_msg_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",server_route_name="n3",server_route_name_id="15"} 0
# HELP nats_core_rtt_nanoseconds RTT in nanoseconds gauge
# TYPE nats_core_rtt_nanoseconds gauge
nats_core_rtt_nanoseconds{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 392292
nats_core_rtt_nanoseconds{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 370750
nats_core_rtt_nanoseconds{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 343875
# HELP nats_core_sent_bytes Number of bytes sent by the server to all connections including clients, routes, gateways and leafnodes counter
# TYPE nats_core_sent_bytes counter
nats_core_sent_bytes{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 142875
nats_core_sent_bytes{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 104062
nats_core_sent_bytes{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 211891
# HELP nats_core_sent_msgs_count Number of messages sent by the server to all connections including clients, routes, gateways and leafnodes counter
# TYPE nats_core_sent_msgs_count counter
nats_core_sent_msgs_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 653
nats_core_sent_msgs_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 418
nats_core_sent_msgs_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 759
# HELP nats_core_sent_to_client_bytes_total Number of bytes sent by the server to client connections (excludes routes, gateways, leafnodes) counter
# TYPE nats_core_sent_to_client_bytes_total counter
nats_core_sent_to_client_bytes_total{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_sent_to_client_bytes_total{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_sent_to_client_bytes_total{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 93932
# HELP nats_core_sent_to_client_msgs_total Number of messages sent by the server to client connections (excludes routes, gateways, leafnodes) counter
# TYPE nats_core_sent_to_client_msgs_total counter
nats_core_sent_to_client_msgs_total{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_sent_to_client_msgs_total{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_sent_to_client_msgs_total{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 90
# HELP nats_core_slow_consumer_count Number of slow consumers gauge
# TYPE nats_core_slow_consumer_count gauge
nats_core_slow_consumer_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_slow_consumer_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_slow_consumer_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 0
# HELP nats_core_start_time Server start time gauge
# TYPE nats_core_start_time gauge
nats_core_start_time{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 1.788403202356733e+18
nats_core_start_time{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 1.788403202526818e+18
nats_core_start_time{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 1.788403202188888e+18
# HELP nats_core_subs_count Current number of subscriptions gauge
# TYPE nats_core_subs_count gauge
nats_core_subs_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 261
nats_core_subs_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 259
nats_core_subs_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 259
# HELP nats_core_total_connection_count Total number of client connections serviced counter
# TYPE nats_core_total_connection_count counter
nats_core_total_connection_count{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 0
nats_core_total_connection_count{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 0
nats_core_total_connection_count{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 12
# HELP nats_core_uptime Server uptime gauge
# TYPE nats_core_uptime gauge
nats_core_uptime{server_cluster="east",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2"} 129.675453
nats_core_uptime{server_cluster="east",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3"} 129.505295
nats_core_uptime{server_cluster="east",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1"} 129.843119
# HELP nats_jetstream_advisory_count Number of JetStream Advisory listeners that are running
# TYPE nats_jetstream_advisory_count gauge
nats_jetstream_advisory_count 0
# HELP nats_latency_observations_count Number of Service Latency listeners that are running
# TYPE nats_latency_observations_count gauge
nats_latency_observations_count 0
# HELP nats_stream_consumer_count Total number of consumers from a stream
# TYPE nats_stream_consumer_count gauge
nats_stream_consumer_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 0
nats_stream_consumer_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 0
nats_stream_consumer_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 0
nats_stream_consumer_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 0
nats_stream_consumer_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 0
# HELP nats_stream_first_seq First sequence from a stream
# TYPE nats_stream_first_seq gauge
nats_stream_first_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 1
nats_stream_first_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 1
nats_stream_first_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 1
nats_stream_first_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 1
nats_stream_first_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 1
# HELP nats_stream_last_seq Last sequence from a stream
# TYPE nats_stream_last_seq gauge
nats_stream_last_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 30
nats_stream_last_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 30
nats_stream_last_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 30
nats_stream_last_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 30
nats_stream_last_seq{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 30
# HELP nats_stream_subject_count Total number of subjects in a stream
# TYPE nats_stream_subject_count gauge
nats_stream_subject_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 1
nats_stream_subject_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 1
nats_stream_subject_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 1
nats_stream_subject_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 1
nats_stream_subject_count{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 1
# HELP nats_stream_total_bytes Total stored bytes from a stream
# TYPE nats_stream_total_bytes gauge
nats_stream_total_bytes{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 3282
nats_stream_total_bytes{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 1431
nats_stream_total_bytes{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 1431
nats_stream_total_bytes{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 1431
nats_stream_total_bytes{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 1431
# HELP nats_stream_total_messages Total number of messages from a stream
# TYPE nats_stream_total_messages gauge
nats_stream_total_messages{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-4xqNIVlf",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_AGG",stream_leader="n2"} 30
nats_stream_total_messages{account="$G",account_name="$G",cluster_name="east",raft_group="S-R1F-Cp5pI54v",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS_MIRROR",stream_leader="n2"} 30
nats_stream_total_messages{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO",server_name="n2",stream="ORDERS",stream_leader="n2"} 30
nats_stream_total_messages{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI",server_name="n3",stream="ORDERS",stream_leader="n2"} 30
nats_stream_total_messages{account="$G",account_name="$G",cluster_name="east",raft_group="S-R3F-zHrMNfYE",server_id="NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S",server_name="n1",stream="ORDERS",stream_leader="n2"} 30
# HELP nats_survey_duration_seconds Time it took to gather the surveyed data histogram
# TYPE nats_survey_duration_seconds summary
nats_survey_duration_seconds_sum 0.008843957999999999
nats_survey_duration_seconds_count 2
# HELP nats_survey_expected_count Number of remote hosts expected to responded gauge
# TYPE nats_survey_expected_count gauge
nats_survey_expected_count 3
# HELP nats_survey_surveyed_count Number of remote hosts successfully surveyed gauge
# TYPE nats_survey_surveyed_count gauge
nats_survey_surveyed_count 3
# HELP nats_up 1 if connected to NATS, 0 otherwise.  A gauge.
# TYPE nats_up gauge
nats_up 1

[http 200]
```


## Appendix · the v0.9.11 source behind the names and the `--prefix` flag

Verbatim from the Go module cache at v0.9.11 (`github.com/nats-io/nats-surveyor@v0.9.11`), real line numbers.

`--prefix` is parsed and stored, and the stored value is used nowhere — the field is marked `TODO`:

### `cmd/root.go` lines 236–240

```go
  236	
  237		// prefix
  238		rootCmd.Flags().String("prefix", "", "Replace the default prefix for all the metrics.")
  239		_ = viper.BindPFlag("prefix", rootCmd.Flags().Lookup("prefix"))
  240	
```


### `cmd/root.go` lines 330–335

```go
  330		opts.HTTPCaFile = viper.GetString("http-tlscacert")
  331		opts.HTTPUser = viper.GetString("http-user")
  332		opts.HTTPPassword = viper.GetString("http-pass")
  333		opts.Prefix = viper.GetString("prefix")
  334		opts.ObservationConfigDir = viper.GetString("observe")
  335		opts.JetStreamConfigDir = viper.GetString("jetstream")
```


### `surveyor/surveyor.go` lines 76–90

```go
   76		TLSFirst             bool
   77		HTTPCertFile         string
   78		HTTPKeyFile          string
   79		HTTPCaFile           string
   80		HTTPUser             string // User in metrics scrape by Prometheus.
   81		HTTPPassword         string
   82		Prefix               string // TODO
   83		ObservationConfigDir string
   84		JetStreamConfigDir   string
   85		Accounts             bool
   86		AccountsDetailed     bool
   87		Gatewayz             bool
   88		Raftz                bool
   89		Jsz                  CollectJsz
   90		JszLimit             int
```


Every name is built with the literal namespace `nats`: `nats_core_<name>` for the server, route, gateway and account series, `nats_stream_*` / `nats_consumer_*` for the JetStream ones, `nats_survey_*` and `nats_up` for the surveyor itself:

### `surveyor/collector_statz.go` lines 388–397

```go
  388	// Up/Down on servers - look at discovery mechanisms in Prometheus - aging out, how does it work?
  389	func (sc *StatzCollector) buildDescs() {
  390		newName := func(name string) string {
  391			return prometheus.BuildFQName("nats", "core", name)
  392		}
  393	
  394		// A unlabelled description for the up/down
  395		sc.natsUp = newGauge("nats_up", "1 if connected to NATS, 0 otherwise.  A gauge.", sc.constLabels)
  396	
  397		sc.descs.Info = newGaugeVec(newName("info"), "General Server information Summary gauge", sc.constLabels, sc.serverInfoLabels)
```


### `surveyor/collector_statz.go` lines 440–460

```go
  440			sc.descs.InboundGateways = sc.newGatewayzDescs("gatewayz_inbound_gateway", newName)
  441		}
  442	
  443		// Raftz
  444		if sc.collectRaftz {
  445			sc.descs.RaftzMetaCommitted = newGaugeVec(newName("raftz_meta_committed"),
  446				"Highest committed log entry index of the meta Raft group",
  447				sc.constLabels,
  448				sc.jsServerLabels,
  449			)
  450			sc.descs.RaftzMetaApplied = newGaugeVec(newName("raftz_meta_applied"),
  451				"Highest applied log entry index of the meta Raft group",
  452				sc.constLabels,
  453				sc.jsServerLabels,
  454			)
  455			sc.descs.RaftzMetaPindex = newGaugeVec(newName("raftz_meta_pindex"),
  456				"Log entry index at last snapshot of the meta Raft group",
  457				sc.constLabels,
  458				sc.jsServerLabels,
  459			)
  460		}
```


### `surveyor/collector_statz.go` lines 560–660

```go
  560			sc.descs.accJetstreamTieredStorageUsed = newGaugeVec(newName("account_jetstream_tiered_storage_used"), "The number of bytes used by JetStream storage tier", sc.constLabels, append(accLabel, "tier"))
  561			sc.descs.accJetstreamTieredMemoryReserved = newGaugeVec(newName("account_jetstream_tiered_memory_reserved"), "The number of bytes reserved by JetStream memory tier", sc.constLabels, append(accLabel, "tier"))
  562			sc.descs.accJetstreamTieredStorageReserved = newGaugeVec(newName("account_jetstream_tiered_storage_reserved"), "The number of bytes reserved by JetStream storage tier", sc.constLabels, append(accLabel, "tier"))
  563			sc.descs.accJetstreamStreamCount = newGaugeVec(newName("account_jetstream_stream_count"), "The number of streams in this account", sc.constLabels, accLabel)
  564			sc.descs.accJetstreamConsumerCount = newGaugeVec(newName("account_jetstream_consumer_count"), "The number of consumers per stream for this account", sc.constLabels, append(accLabel, "stream", "raft_group"))
  565			sc.descs.accJetstreamReplicaCount = newGaugeVec(newName("account_jetstream_replica_count"), "The number of replicas per stream for this account", sc.constLabels, append(accLabel, "stream", "raft_group"))
  566	
  567			jszLabels := append(accLabel, []string{"cluster_name", "raft_group", "server_id", "server_name", "stream", "stream_leader"}...)
  568			var consumerLabels []string
  569			consumerLabels = append(consumerLabels, jszLabels...)
  570			consumerLabels = append(consumerLabels, "consumer_name")
  571			consumerLabels = append(consumerLabels, "consumer_leader")
  572	
  573			sc.descs.accJszStreamMsgs = newGaugeVec(
  574				prometheus.BuildFQName("nats", "stream", "total_messages"),
  575				"Total number of messages from a stream",
  576				sc.constLabels,
  577				jszLabels,
  578			)
  579			sc.descs.accJszStreamBytes = newGaugeVec(
  580				prometheus.BuildFQName("nats", "stream", "total_bytes"),
  581				"Total stored bytes from a stream",
  582				sc.constLabels,
  583				jszLabels,
  584			)
  585			sc.descs.accJszStreamFirstSeq = newGaugeVec(
  586				prometheus.BuildFQName("nats", "stream", "first_seq"),
  587				"First sequence from a stream",
  588				sc.constLabels,
  589				jszLabels,
  590			)
  591			sc.descs.accJszStreamLastSeq = newGaugeVec(
  592				prometheus.BuildFQName("nats", "stream", "last_seq"),
  593				"Last sequence from a stream",
  594				sc.constLabels,
  595				jszLabels,
  596			)
  597			sc.descs.accJszStreamConsumerCount = newGaugeVec(
  598				prometheus.BuildFQName("nats", "stream", "consumer_count"),
  599				"Total number of consumers from a stream",
  600				sc.constLabels,
  601				jszLabels,
  602			)
  603			sc.descs.accJszStreamSubjectCount = newGaugeVec(
  604				prometheus.BuildFQName("nats", "stream", "subject_count"),
  605				"Total number of subjects in a stream",
  606				sc.constLabels,
  607				jszLabels,
  608			)
  609			sc.descs.accJszConsumerDeliveredConsumerSeq = newGaugeVec(
  610				prometheus.BuildFQName("nats", "consumer", "delivered_consumer_seq"),
  611				"Latest consumer sequence number of a stream consumer",
  612				sc.constLabels,
  613				consumerLabels,
  614			)
  615			sc.descs.accJszConsumerDeliveredStreamSeq = newGaugeVec(
  616				prometheus.BuildFQName("nats", "consumer", "delivered_stream_seq"),
  617				"Latest stream sequence number of a stream",
  618				sc.constLabels,
  619				consumerLabels,
  620			)
  621			sc.descs.accJszConsumerNumAckPending = newGaugeVec(
  622				prometheus.BuildFQName("nats", "consumer", "num_ack_pending"),
  623				"Number of pending acks from a consumer",
  624				sc.constLabels,
  625				consumerLabels,
  626			)
  627			sc.descs.accJszConsumerNumRedelivered = newGaugeVec(
  628				prometheus.BuildFQName("nats", "consumer", "num_redelivered"),
  629				"Number of redelivered messages from a consumer",
  630				sc.constLabels,
  631				consumerLabels,
  632			)
  633			sc.descs.accJszConsumerNumWaiting = newGaugeVec(
  634				prometheus.BuildFQName("nats", "consumer", "num_waiting"),
  635				"Number of inflight fetch requests from a pull consumer",
  636				sc.constLabels,
  637				consumerLabels,
  638			)
  639			sc.descs.accJszConsumerNumPending = newGaugeVec(
  640				prometheus.BuildFQName("nats", "consumer", "num_pending"),
  641				"Number of pending messages from a consumer",
  642				sc.constLabels,
  643				consumerLabels,
  644			)
  645			sc.descs.accJszConsumerAckFloorStreamSeq = newGaugeVec(
  646				prometheus.BuildFQName("nats", "consumer", "ack_floor_stream_seq"),
  647				"Number of ack floor stream seq from a consumer",
  648				sc.constLabels,
  649				consumerLabels,
  650			)
  651			sc.descs.accJszConsumerAckFloorConsumerSeq = newGaugeVec(
  652				prometheus.BuildFQName("nats", "consumer", "ack_floor_consumer_seq"),
  653				"Number of ack floor consumer seq from a consumer",
  654				sc.constLabels,
  655				consumerLabels,
  656			)
  657		}
  658	
  659		// Surveyor
  660		sc.surveyedCnt = newGaugeVec(
```


### `surveyor/collector_statz.go` lines 660–700

```go
  660		sc.surveyedCnt = newGaugeVec(
  661			prometheus.BuildFQName("nats", "survey", "surveyed_count"),
  662			"Number of remote hosts successfully surveyed gauge",
  663			sc.constLabels,
  664			[]string{},
  665		)
  666	
  667		sc.expectedCnt = newGaugeVec(
  668			prometheus.BuildFQName("nats", "survey", "expected_count"),
  669			"Number of remote hosts expected to responded gauge",
  670			sc.constLabels,
  671			[]string{},
  672		)
  673	
  674		sc.pollTime = newSummaryVec(
  675			prometheus.BuildFQName("nats", "survey", "duration_seconds"),
  676			"Time it took to gather the surveyed data histogram",
  677			sc.constLabels,
  678			[]string{},
  679		)
  680	
  681		sc.pollErrCnt = newCounterVec(
  682			prometheus.BuildFQName("nats", "survey", "poll_error_count"),
  683			"The number of times the poller encountered errors counter",
  684			sc.constLabels,
  685			[]string{},
  686		)
  687	
  688		sc.lateReplies = newCounterVec(
  689			prometheus.BuildFQName("nats", "survey", "late_replies_count"),
  690			"Number of times a reply was received too late counter",
  691			sc.constLabels,
  692			[]string{"timeout"},
  693		)
  694	
  695		sc.noReplies = newCounterVec(
  696			prometheus.BuildFQName("nats", "survey", "no_replies_count"),
  697			"Number of nodes that did not reply in poll cycle",
  698			sc.constLabels,
  699			[]string{"expected"},
  700		)
```


The `--jsz-leaders-only`, `--jsz-limit` and `--jsz-filter` options, and the meta group filter used for `--raftz`:

### `surveyor/collector_statz.go` lines 768–790

```go
  768		}
  769	}
  770	
  771	func WithCollectJsz(jsz CollectJsz, jszLeadersOnly bool, jszFilters []JszFilter) StatzCollectorOpt {
  772		return func(sc *StatzCollector) error {
  773			sc.collectJsz = jsz
  774			sc.jszLeadersOnly = jszLeadersOnly
  775			for i := range jszFilters {
  776				sc.jszFilterSet[jszFilters[i]] = true
  777			}
  778			return nil
  779		}
  780	}
  781	
  782	func WithJszLimit(jszLimit int) StatzCollectorOpt {
  783		return func(sc *StatzCollector) error {
  784			sc.jszLimit = jszLimit
  785			return nil
  786		}
  787	}
  788	
  789	func WithConstantLabels(constLabels prometheus.Labels) StatzCollectorOpt {
  790		return func(sc *StatzCollector) error {
```


### `surveyor/collector_statz.go` lines 1258–1276

```go
 1258			opts = server.JSzOptions{
 1259				Accounts:   true,
 1260				Streams:    true,
 1261				Consumer:   true,
 1262				Config:     true,
 1263				Limit:      sc.jszLimit,
 1264				RaftGroups: true,
 1265			}
 1266		} else if collectJsz {
 1267			opts = server.JSzOptions{
 1268				Accounts:   true,
 1269				Streams:    true,
 1270				Consumer:   getConsumers,
 1271				Config:     true,
 1272				Limit:      sc.jszLimit,
 1273				RaftGroups: true,
 1274			}
 1275		}
 1276	
```


### `surveyor/collector_statz.go` lines 1458–1466

```go
 1458	
 1459	func (sc *StatzCollector) getRaftz(ctx context.Context, nc *nats.Conn) ([]*raftStat, error) {
 1460		req := &server.RaftzOptions{
 1461			AccountFilter: "",
 1462			GroupFilter:   "_meta_",
 1463		}
 1464		reqJSON, err := json.Marshal(req)
 1465		if err != nil {
 1466			return nil, err
```

