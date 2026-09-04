#!/bin/bash
# runC2.sh — the timed -ERRs: authorization timeout, TLS handshake timeout, stale connection,
# and the two that looked recoverable in runC. nats-server v2.14.6.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
UP() { nats-server -c "$1" >"c2-$2-server.log" 2>&1 & SRV=$!; sleep 0.7; }
DOWN() { kill $SRV 2>/dev/null; wait $SRV 2>/dev/null; }

UP authto.conf a
echo "### C15 · authorization { timeout: 1 } and a client that sends nothing at all"
python3 wire-raw.py --port 14222 --wait 4.0 --label ""
echo; DOWN; echo "--- server log ---"; grep -v "Starting\|Version\|Git\|Name\|ID:\|Listening\|ready\|configuration" c2-a-server.log | tail -4

UP tlsreq.conf b
echo; echo "### C16 · tls { timeout: 2 } and a client that never starts a handshake"
python3 wire-raw.py --port 14222 --wait 5.0 --label ""
echo; DOWN; echo "--- server log ---"; grep -v "Starting\|Version\|Git\|Name\|ID:\|Listening\|ready\|configuration" c2-b-server.log | tail -4

UP ping.conf c
echo; echo "### C17 · ping_interval 2s, ping_max 2, a client that never answers PING"
python3 wire-raw.py --port 14222 --wait 14.0 --send 'CONNECT {"verbose":false}' --label ""
echo; DOWN; echo "--- server log ---"; grep -v "Starting\|Version\|Git\|Name\|ID:\|Listening\|ready\|configuration" c2-c-server.log | tail -4

UP mcl.conf d
echo; echo "### C18 · max_control_line 1024, a 2000-byte SUB — is the connection closed?"
python3 wire-raw.py --port 14222 --wait 4.0 --send 'CONNECT {"verbose":false}' --send 'BIGLINE SUB 2000' --send 'PING' --label ""
DOWN

UP maxsubs.conf e
echo; echo "### C19 · max_subscriptions 2 — is the connection still usable afterwards?"
python3 wire-raw.py --port 14222 --wait 2.0 --send 'CONNECT {"verbose":false}' --send 'SUB a 1' --send 'SUB b 2' --send 'SUB c 3' --send 'PUBLINE a hello' --send 'PING' --label ""
DOWN
