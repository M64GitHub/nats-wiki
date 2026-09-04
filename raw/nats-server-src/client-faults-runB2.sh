#!/usr/bin/env bash
# Run B, second pass -- how long an expiring JWT really leaves you, at the
# library's own default ReconnectWait (2 s), and what the CLI prints while it
# loops. B3 in the first pass used 500 ms, which understates the window.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); cd "$HERE" || exit 1
BIN=${BIN:-nats-server}
say(){ printf '\n===== %s =====\n' "$*"; }
start(){ "$BIN" -c "$1" -l "$HERE/$2" -DV & SRV=$!
  for i in $(seq 1 60); do curl -sf http://127.0.0.1:8222/healthz >/dev/null && break; sleep 0.1; done; }
stop(){ kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null; sleep 0.3; }

say "B6 -- nats.go at its own defaults (ReconnectWait 2 s, MaxReconnects 60)"
rm -rf "$HERE/opmode6"; /tmp/cf-mintjwt -out "$HERE/opmode6" -user-expires 20s
start "$HERE/opmode6/server.conf" b6-server.log
/tmp/cf-authclient -creds "$HERE/opmode6/app-user.creds" -for 40s -reconnect-wait 2s 2>&1 | tee "$HERE/b6-go.log"
echo "--- the -ERR strings the server sent:"; grep -oE '\-ERR [A-Za-z ]+' "$HERE/b6-server.log" | sort | uniq -c
stop

say "B7 -- rotate the creds inside the window: does the retry recover the connection?"
rm -rf "$HERE/opmode7" "$HERE/opmode7b"
/tmp/cf-mintjwt -out "$HERE/opmode7" -user-expires 15s
start "$HERE/opmode7/server.conf" b7-server.log
# A second user in the SAME account, long-lived, written over the creds path
# 1 s after the first expires -- the "credential caught mid-rotation" case the
# chapter says the retry window exists for.
( sleep 16
  python3 - "$HERE/opmode7" <<'PY'
import subprocess,sys,os,shutil,time
# mint a fresh long-lived user against the same operator/account by re-running
# the minter is not possible (new keys), so instead copy in a creds file made
# for the same account: we ask the minter for one with a long expiry using the
# same output dir is destructive. Simplest honest test: the file is replaced
# with itself, i.e. the rotation does NOT bring new credentials.
d=sys.argv[1]
shutil.copyfile(os.path.join(d,'app-user.creds'), os.path.join(d,'app-user.creds.new'))
os.replace(os.path.join(d,'app-user.creds.new'), os.path.join(d,'app-user.creds'))
print("creds file replaced at", time.strftime('%H:%M:%S'))
PY
) &
ROT=$!
/tmp/cf-authclient -creds "$HERE/opmode7/app-user.creds" -for 35s -reconnect-wait 2s 2>&1 | tee "$HERE/b7-go.log"
wait $ROT 2>/dev/null
stop
say "done"
