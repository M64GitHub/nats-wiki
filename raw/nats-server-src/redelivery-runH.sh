#!/bin/bash
# redelivery-runH.sh — the Stack Overflow #78603662 shape on the lab's standalone v2.14.6:
# a consumer created through the raw JetStream API with `backoff: [10000]` and `max_deliver: 2`,
# exactly the numbers the .NET code sent, then the same without max_deliver.
S=${S:-nats://127.0.0.1:4291}
n() { echo; echo "\$ nats $*"; nats --server "$S" "$@"; }
n stream add sample-new --subjects 'test.new.*' --storage file --defaults >/dev/null && echo "Stream sample-new was created"
for i in 0 1 2 3 4 5 6 7 8 9; do nats --server "$S" pub test.new.first "message $i" >/dev/null; done; echo "published 10 messages to test.new.first"
echo; echo "\$ nats req '\$JS.API.CONSUMER.CREATE.sample-new.first-new-consumer' '{...\"max_deliver\":2,\"backoff\":[10000]}' | jq .config"
nats --server "$S" req '$JS.API.CONSUMER.CREATE.sample-new.first-new-consumer' \
 '{"stream_name":"sample-new","config":{"name":"first-new-consumer","durable_name":"first-new-consumer","deliver_policy":"all","ack_policy":"explicit","max_deliver":2,"backoff":[10000]}}' --raw \
 | jq -c '.config | {ack_wait, max_deliver, backoff, ack_policy, deliver_policy}'
n consumer info sample-new first-new-consumer | sed -n '/Configuration/,/Max Waiting/p'
echo; echo "### the same config with max_deliver omitted"
echo "\$ nats req '\$JS.API.CONSUMER.CREATE.sample-new.nomax' '{...\"backoff\":[10000]}' | jq"
nats --server "$S" req '$JS.API.CONSUMER.CREATE.sample-new.nomax' \
 '{"stream_name":"sample-new","config":{"name":"nomax","durable_name":"nomax","deliver_policy":"all","ack_policy":"explicit","backoff":[10000]}}' --raw \
 | jq -c 'if .error then .error else (.config | {ack_wait, max_deliver, backoff}) end'
echo; echo "### and with max_deliver: 1 (the backoff list is as long as the limit)"
nats --server "$S" req '$JS.API.CONSUMER.CREATE.sample-new.one' \
 '{"stream_name":"sample-new","config":{"name":"one","durable_name":"one","deliver_policy":"all","ack_policy":"explicit","max_deliver":1,"backoff":[10000]}}' --raw \
 | jq -c 'if .error then .error else (.config | {ack_wait, max_deliver, backoff}) end'
