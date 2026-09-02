#!/bin/bash
# redelivery-runH-repeat.sh — run H's pull half repeated: the consumer is deleted and recreated
# through the raw API before every pull, three pulls per shape, batch 100 then batch 10.
S=${S:-nats://127.0.0.1:4291}; P=raw/nats-server-src/nats-probe-client.py; B=local/scratch/runs/redelivery/runH-batch.py
mk() { nats --server "$S" consumer rm sample-new "$1" -f >/dev/null 2>&1; nats --server "$S" req "\$JS.API.CONSUMER.CREATE.sample-new.$1" "{\"stream_name\":\"sample-new\",\"config\":{\"name\":\"$1\",\"durable_name\":\"$1\",\"deliver_policy\":\"all\",\"ack_policy\":\"explicit\",\"backoff\":[10000]$2}}" --raw | jq -c '.config|{ack_wait,max_deliver}'; }
for batch in 100 10; do for c in "first-new-consumer|,\"max_deliver\":2" "nomax|"; do name=${c%%|*}; extra=${c#*|}
  for i in 1 2 3; do echo -n "batch=$batch $name #$i  cfg="; mk "$name" "$extra"; BATCH=$batch python3 "$B" "$P" "sample-new/$name" | grep -E '=>|status'; done; done; done
