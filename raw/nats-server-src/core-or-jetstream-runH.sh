#!/bin/bash
set -m
# Run H — the docs' own Acme example, both chapters at once: the core chapter's inventory
# responder on orders.inventory.check, and the JetStream chapter's first command,
# `nats stream add ORDERS --subjects "orders.>"`. nats-server v2.14.6, nats CLI 0.4.0.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
N="nats --server nats://127.0.0.1:14222 --timeout=3s"
pkill -f 'nats-server -c' 2>/dev/null; pkill -f 'orders.inventory' 2>/dev/null; sleep 0.5; rm -rf store; mkdir -p store
nats-server -c server.conf -l "$D/h-server.log" >/dev/null 2>&1 & SRV=$!
sleep 0.8

echo "=== H1 · learn/core-nats/request-reply.md: the inventory service ==="
$N reply orders.inventory.check 'in stock: 42' >/dev/null 2>&1 & R=$!
sleep 0.8
$N request orders.inventory.check '{"sku":"ord_8w2k"}' 2>&1 | tail -3

echo
echo "=== H2 · learn/jetstream/your-first-stream.md, verbatim ==="
$N stream add ORDERS --subjects "orders.>" --defaults 2>&1 | tail -2
sleep 0.3

echo
echo "=== H3 · the same inventory request, with both chapters' state in place ==="
$N request orders.inventory.check '{"sku":"ord_8w2k"}' 2>&1 | tail -3
echo "--- gathering every reply instead of the first ---"
$N request orders.inventory.check '{"sku":"ord_8w2k"}' --replies=0 2>&1 | tail -7

echo
echo "=== H4 · and what the ORDERS stream is now holding ==="
$N stream subjects ORDERS 2>&1 | head -12
kill $R $SRV 2>/dev/null; wait $SRV 2>/dev/null
echo "=== done ==="
