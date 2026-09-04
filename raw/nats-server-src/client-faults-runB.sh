#!/usr/bin/env bash
# Run B -- a user JWT expiring on a live connection.
#
#   B1  the exact bytes on the wire at expiry (a raw client that signs the nonce)
#   B2  the `nats` CLI, which sets IgnoreAuthErrorAbort and never gives up
#   B3  nats.go v1.53.1 with the default rules: which errors, how many
#       reconnects, and what closes it
#   B4  nats.go with IgnoreAuthErrorAbort, for the contrast
#   B5  an ACCOUNT JWT expiring under a live connection
#
# nats-server v2.14.6, nats CLI 0.4.0, nats.go v1.53.1, jwt/v2 v2.8.2,
# nkeys v0.4.16.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BIN=${BIN:-nats-server}
S=nats://127.0.0.1:4222
say(){ printf '\n===== %s =====\n' "$*"; }
start(){ "$BIN" -c "$1" -l "$HERE/$2" -DV & SRV=$!
  for i in $(seq 1 60); do curl -sf http://127.0.0.1:8222/healthz >/dev/null && break; sleep 0.1; done; }
stop(){ kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null; }
build(){ ( cd "$HERE/go" && go build -o /tmp/cf-mintjwt ./mintjwt && go build -o /tmp/cf-rawcreds ./rawcreds && go build -o /tmp/cf-authclient ./authclient ); }

build || exit 1

say "B1 -- the wire, at expiry (user JWT valid 20 s)"
rm -rf "$HERE/opmode"; /tmp/cf-mintjwt -out "$HERE/opmode" -user-expires 20s
start "$HERE/opmode/server.conf" b-server.log
/tmp/cf-rawcreds -creds "$HERE/opmode/app-user.creds" -for 45s -ping 5s 2>&1 | tee "$HERE/b1-raw.log"
echo "--- server log:"; grep -iE 'expired|authoriz|authentic' "$HERE/b-server.log" | head -10
stop

say "B2 -- the nats CLI (IgnoreAuthErrorAbort, unlimited reconnects)"
rm -rf "$HERE/opmode2"; /tmp/cf-mintjwt -out "$HERE/opmode2" -user-expires 20s
start "$HERE/opmode2/server.conf" b2-server.log
( nats sub 'orders.>' -s "$S" --creds "$HERE/opmode2/app-user.creds" --connection-name cli-order-svc > "$HERE/b2-cli.log" 2>&1 ) &
CLIPID=$!
sleep 45; kill $CLIPID 2>/dev/null; wait $CLIPID 2>/dev/null
echo "--- what the CLI printed (first 25 lines):"; head -25 "$HERE/b2-cli.log"
echo "--- how many times it was rejected:"; grep -ci 'authoriz\|expired' "$HERE/b2-cli.log"
echo "--- server log:"; grep -icE 'authorization error|expired' "$HERE/b2-server.log"
stop

say "B3 -- nats.go v1.53.1, default rules"
rm -rf "$HERE/opmode3"; /tmp/cf-mintjwt -out "$HERE/opmode3" -user-expires 20s
start "$HERE/opmode3/server.conf" b3-server.log
/tmp/cf-authclient -creds "$HERE/opmode3/app-user.creds" -for 60s 2>&1 | tee "$HERE/b3-go.log"
echo "--- server log (auth):"; grep -iE 'expired|authorization' "$HERE/b3-server.log" | head -12
echo "--- /connz closed:"; curl -s 'http://127.0.0.1:8222/connz?state=closed' | python3 -c 'import json,sys;d=json.load(sys.stdin);print([(c.get("name"),c.get("reason")) for c in d["connections"]])'
stop

say "B4 -- nats.go with IgnoreAuthErrorAbort, same creds"
rm -rf "$HERE/opmode4"; /tmp/cf-mintjwt -out "$HERE/opmode4" -user-expires 20s
start "$HERE/opmode4/server.conf" b4-server.log
/tmp/cf-authclient -creds "$HERE/opmode4/app-user.creds" -for 45s -ignore-abort 2>&1 | tee "$HERE/b4-go.log"
stop

say "B5 -- an ACCOUNT JWT expiring under a live connection"
rm -rf "$HERE/opmode5"; /tmp/cf-mintjwt -out "$HERE/opmode5" -user-expires 0 -account-expires 25s
start "$HERE/opmode5/server.conf" b5-server.log
/tmp/cf-rawcreds -creds "$HERE/opmode5/app-user.creds" -for 50s -ping 5s 2>&1 | tee "$HERE/b5-raw.log"
echo "--- server log:"; grep -iE 'expired|authoriz' "$HERE/b5-server.log" | head -8
stop
say "done"
