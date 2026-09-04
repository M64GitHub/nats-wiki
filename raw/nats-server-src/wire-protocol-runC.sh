#!/bin/bash
# runC.sh — every -ERR a client can be sent, provoked, with the exact bytes. nats-server v2.14.6.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
R() { python3 wire-raw.py --port 14222 --wait "$1" --label "$2" "${@:3}"; echo; }
UP() { nats-server -c "$1" >"c-$2-server.log" 2>&1 & SRV=$!; sleep 0.7; }
DOWN() { kill $SRV 2>/dev/null; wait $SRV 2>/dev/null; }

UP base.conf c1
R 0.6 "C1 · an unknown verb"                       --send 'CONNECT {"verbose":false}' --send 'FOO bar' --send 'PING'
R 0.6 "C2 · SUB with a malformed subject (Recoverable?)" --send 'CONNECT {"verbose":false}' --send 'SUB foo. 1' --send 'SUB ok 2' --send 'PUBLINE ok x' --send 'PING'
R 0.6 "C3 · PUB with a malformed subject"          --send 'CONNECT {"verbose":false}' --send 'PUBLINE foo..bar x' --send 'PING'
R 0.6 "C4 · PUB with a wildcard subject"           --send 'CONNECT {"verbose":false}' --send 'PUBLINE foo.* x' --send 'PING'
R 0.6 "C5 · UNSUB for a subscription that does not exist" --send 'CONNECT {"verbose":false}' --send 'UNSUB 99' --send 'PING'
DOWN

UP maxconn.conf c6
echo "--- C6 · max_connections: 1 — hold one connection open, then dial a second ---"
python3 wire-raw.py --port 14222 --wait 2.5 --pong --send 'CONNECT {"verbose":false}' --label "C6a the first connection" >c6a.log 2>&1 &
H=$!; sleep 0.5
R 0.8 "C6b · the second connection"                --send 'CONNECT {"verbose":false}' --send 'PING'
wait $H; sed -n '1,4p' c6a.log
DOWN

UP authto.conf c7
R 3.0 "C7 · authorization timeout 1s, a client that never sends CONNECT" --send ''
R 0.8 "C7b · the same server, a wrong password"    --send 'CONNECT {"verbose":false,"user":"u","pass":"WRONG"}' --send 'PING'
DOWN

UP mcl.conf c8
R 0.8 "C8 · max_control_line 1024, a 2000-byte SUB argument" --send 'CONNECT {"verbose":false}' --send 'BIGLINE SUB 2000' --send 'PING'
DOWN

UP mpay.conf c9
R 0.8 "C9 · max_payload 128, a 200-byte PUB"       --send 'CONNECT {"verbose":false}' --send 'PUBBIG foo 200' --send 'PING'
DOWN

UP maxsubs.conf c10
R 0.8 "C10 · max_subscriptions 2, a third SUB"     --send 'CONNECT {"verbose":false}' --send 'SUB a 1' --send 'SUB b 2' --send 'SUB c 3' --send 'PING'
DOWN

UP perms.conf c11
R 0.8 "C11 · a subscription outside the allow list" --send 'CONNECT {"verbose":false,"user":"p","pass":"p"}' --send 'SUB nope 1' --send 'SUB can.sub 2' --send 'PING'
R 0.8 "C12 · a publish outside the allow list"      --send 'CONNECT {"verbose":false,"user":"p","pass":"p"}' --send 'PUBLINE nope x' --send 'PING'
R 0.8 "C13 · a queue subscription outside the allow list" --send 'CONNECT {"verbose":false,"user":"p","pass":"p"}' --send 'SUB nope Q 1' --send 'PING'
DOWN

UP tlsreq.conf c14
R 0.8 "C14 · tls required, a plain client"          --send 'CONNECT {"verbose":false}' --send 'PING'
DOWN
