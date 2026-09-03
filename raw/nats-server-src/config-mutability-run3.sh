#!/usr/bin/env bash
# config-mutability-run3.sh — pass 3 (2026-09-03): MSG.NEXT batch 300 on an unsealed stream holding 3 messages
# (pass 2 published into a stream it had just sealed, so the publishes were refused and the pull saw nothing).
set -u
S="--server nats://127.0.0.1:4291 --timeout 4s"
req() { nats $S req "$1" "$2" 2>&1 | grep -vE '^$|Sending|Received' ; }
echo "### create CFG3, publish 3, consumer c3 (no max_batch)"
req '$JS.API.STREAM.CREATE.CFG3' '{"name":"CFG3","subjects":["cfg3.>"],"retention":"limits","storage":"file","num_replicas":1}' | head -c 80; echo
for i in 1 2 3; do nats $S pub cfg3.a "m$i" >/dev/null 2>&1; done
req '$JS.API.CONSUMER.CREATE.CFG3.c3' '{"stream_name":"CFG3","config":{"durable_name":"c3","ack_policy":"explicit"},"action":"create"}' | python3 -c 'import json,sys; d=json.loads([l for l in sys.stdin if l.startswith("{")][0]); print("  created; num_pending=%s max_batch=%s" % (d.get("num_pending"), d.get("config",{}).get("max_batch")))'
echo "### MSG.NEXT {batch:300, no_wait:true}"; nats $S req '$JS.API.CONSUMER.MSG.NEXT.CFG3.c3' '{"batch":300,"no_wait":true}' --replies 4 2>&1 | grep -vE '^$|Sending' | cut -c1-100
echo "### MSG.NEXT {batch:100000, no_wait:true} (nothing left)"; nats $S req '$JS.API.CONSUMER.MSG.NEXT.CFG3.c3' '{"batch":100000,"no_wait":true}' --replies 1 2>&1 | grep -vE '^$|Sending' | cut -c1-100
echo "### cleanup"; req '$JS.API.STREAM.DELETE.CFG3' '' | head -c 80; echo
