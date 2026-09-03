#!/usr/bin/env bash
# system-subjects-run.sh — the commands behind raw/nats-server-src/system-subjects-observed-v2.14.6.md
# (2026-09-03, nats-server v2.14.6, nats CLI 0.4.0, macOS). Two scenes:
#   (1) the wiki's lab cluster:  bash tools/lab/cluster.sh up 3   (n1–n3, $SYS user sys/sys, ports 429k/829k)
#   (2) a standalone server x1 with two ordinary accounts, a service export with latency sampling and a
#       leafnode listener, plus a leaf x2 that dials it — the lab has no ordinary account, and CONNS is
#       never published for $G, so the account events need this.
# Run it from a scratch directory; it writes its logs next to itself. Not idempotent: read it, then run it.
set -u
LAB=nats://sys:sys@127.0.0.1:4291
N1_ID=$(curl -s http://127.0.0.1:8291/varz | python3 -c 'import json,sys;print(json.load(sys.stdin)["server_id"])')
N2_PID=$(cat "${NATS_LAB_DIR:-${TMPDIR:-/tmp}/nats-lab}/n2/n2.pid")

# --- A · which paths the HTTP mux serves (server.go:3134–3162) ------------------------------------
for p in varz statsz idz profilez stacksz debug/vars subscriptionsz expvarz; do
  printf '%-16s %s\n' "/$p" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1:8291/$p)"
done | tee runA-http.log

# --- B · the request-only forms over the system account (events.go:1268–1315) --------------------
req() { nats --server $LAB --timeout 4s req "$@"; }
{ for z in IDZ STATSZ VARZ; do echo "### \$SYS.REQ.SERVER.PING.$z"; req "\$SYS.REQ.SERVER.PING.$z" '{}' --replies 3; done
  echo "### PING.PROFILEZ"; req '$SYS.REQ.SERVER.PING.PROFILEZ' '{"name":"goroutine"}' --replies 3
  echo "### <id>.IDZ";      req "\$SYS.REQ.SERVER.$N1_ID.IDZ" '{}'
  echo "### PING.EXPVARZ";  req '$SYS.REQ.SERVER.PING.EXPVARZ' '{}' --replies 1
} > runB-ping.log 2>&1
nats --server $LAB --timeout 2s req '$SYS.REQ.SERVER.PING.STACKSZ' '{}' >> runB-ping.log 2>&1   # no such request

# --- C · x1: account events, auth error, service latency, a leaf --------------------------------
cat > x1.conf <<'CONF'
server_name: x1
listen: 127.0.0.1:4299
http: 127.0.0.1:8299
leafnodes { listen: 127.0.0.1:7499 }
accounts {
  $SYS { users: [ { user: sys, password: sys } ] }
  SVC {
    users: [ { user: svc, password: svc } ]
    exports: [ { service: "svc.echo", latency: { sampling: 100%, subject: "svc.latency" } } ]
  }
  APP {
    users: [ { user: app, password: app } ]
    imports: [ { service: { account: SVC, subject: "svc.echo" } } ]
  }
}
CONF
cat > x2.conf <<'CONF'
server_name: x2
listen: 127.0.0.1:4298
leafnodes { remotes: [ { url: "nats://app:app@127.0.0.1:7499" } ] }
CONF
nohup nats-server -c x1.conf -l x1.log -P x1.pid </dev/null >/dev/null 2>&1 &
sleep 1
nohup nats --server nats://sys:sys@127.0.0.1:4299 sub '$SYS.>'     > x1-sys.log     2>&1 </dev/null &
nohup nats --server nats://svc:svc@127.0.0.1:4299 sub 'svc.latency' > x1-latency.log 2>&1 </dev/null &
nohup nats --server nats://svc:svc@127.0.0.1:4299 reply 'svc.echo' 'pong' > x1-reply.log 2>&1 </dev/null &
nohup nats --server $LAB sub '$SYS.>' > lab-sys.log 2>&1 </dev/null &
sleep 2
nohup nats --server nats://app:app@127.0.0.1:4299 --connection-name holder sub 'hold.me' > x1-holder.log 2>&1 </dev/null &
sleep 2
nats --server nats://app:app@127.0.0.1:4299 --connection-name requester req svc.echo 'ping' --timeout 3s
sleep 1
nats --server nats://app:WRONG@127.0.0.1:4299 --timeout 2s pub x y          # Authorization Violation
sleep 1
nohup nats-server -c x2.conf -l x2.log -P x2.pid </dev/null >/dev/null 2>&1 &   # the leaf
sleep 100                                                                     # three CONNS heartbeats

# --- D · the lab: account requests, reload by message, lame duck, shutdown ------------------------
{ echo "### ACCOUNT.PING.STATZ"; req '$SYS.REQ.ACCOUNT.PING.STATZ' '{}' --replies 3
  echo "### ACCOUNT.\$G.CONNZ";  req '$SYS.REQ.ACCOUNT.$G.CONNZ' '{}' --replies 3
  echo "### USER.INFO";          req '$SYS.REQ.USER.INFO' ''
  echo "### RELOAD";             req "\$SYS.REQ.SERVER.$N1_ID.RELOAD" ''
  echo "### legacy PING";        req '$SYS.REQ.SERVER.PING' '{}' --replies 3
} > runD-lab.log 2>&1
grep -E 'Reloaded' "${NATS_LAB_DIR:-${TMPDIR:-/tmp}/nats-lab}/n1/n1.log" | tail -2 >> runD-lab.log
nats-server --signal ldm=$N2_PID; sleep 3                 # LAMEDUCK; with no clients n2 exits at once
bash tools/lab/cluster.sh start 2; sleep 3
bash tools/lab/cluster.sh stop 2; sleep 3                 # SIGTERM → SHUTDOWN
bash tools/lab/cluster.sh start 2
grep -A1 -E 'LAMEDUCK|SHUTDOWN' lab-sys.log

# --- E · per-account request forms, as sys and as an ordinary user -------------------------------
for z in CONNS STATZ INFO SUBSZ LEAFZ JSZ CONNZ; do
  echo "### as sys: \$SYS.REQ.ACCOUNT.APP.$z"; nats --server nats://sys:sys@127.0.0.1:4299 req "\$SYS.REQ.ACCOUNT.APP.$z" '{}' --timeout 2s
done > runE-misc.log 2>&1
for s in '$SYS.REQ.USER.INFO' '$SYS.REQ.ACCOUNT.PING.CONNZ' '$SYS.REQ.ACCOUNT.PING.STATZ' '$SYS.REQ.SERVER.PING.VARZ' '$SYS.REQ.ACCOUNT.APP.CONNZ'; do
  echo "### as app: $s"; nats --server nats://app:app@127.0.0.1:4299 req "$s" '{}' --timeout 2s
done >> runE-misc.log 2>&1

# --- teardown ---------------------------------------------------------------------------------------
kill $(cat x2.pid) $(cat x1.pid) 2>/dev/null; pkill -f "nats --server nats://(sys|svc|app):" 2>/dev/null
