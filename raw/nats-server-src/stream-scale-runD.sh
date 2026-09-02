#!/usr/bin/env bash
# runD.sh — row 13, the thread's shape: a 50 M-message file stream, four restarts, and a sourcing stream
# with an idle source. Then run F (rows 4/5): --max-msgs past a billion. nats-server v2.14.6 through
# tools/lab/cluster.sh up 1. The transcript is the record; restart timings come from n1.log.
set -u
cd /Users/m64/space/64/nats-wiki
export NATS_LAB_WAIT=1200
LAB="bash tools/lab/cluster.sh"
S=nats://127.0.0.1:4291
D=local/scratch/runs/stream-scale
LABDIR="${TMPDIR:-/tmp}"; LABDIR="${LABDIR%/}/nats-lab"
STORE="$LABDIR/n1/store/jetstream/\$G/streams"
LOG="$LABDIR/n1/n1.log"
say(){ echo; echo "### [$(date '+%H:%M:%S')] $*"; }
mem(){ curl -s 127.0.0.1:8291/varz | python3 -c 'import json,sys;d=json.load(sys.stdin);print("varz mem:",d["mem"],"bytes =",round(d["mem"]/1048576,1),"MiB")'; }
sinfo(){ nats -s $S stream info "$1" --json | python3 -c 'import json,sys;d=json.load(sys.stdin);s=d["state"];print("stream",d["config"]["name"],"subjects",d["config"]["subjects"],"sources",[x["name"]+("/"+x["filter_subject"] if x.get("filter_subject") else "") for x in d["config"].get("sources") or []],"messages",s["messages"],"bytes",s["bytes"],"first",s["first_seq"],"last",s["last_seq"],"num_subjects",s.get("num_subjects"),"num_deleted",s.get("num_deleted",0),"src-state",[(x["name"],x.get("lag")) for x in d.get("sources") or []])'; }
files(){ echo "$1: $(ls "$STORE/$1/msgs" | wc -l | tr -d ' ') files in msgs/, $(du -sh "$STORE/$1/msgs" | cut -f1), index.db: $(ls -l "$STORE/$1/msgs/index.db" 2>/dev/null | awk '{print $5" bytes"}' || echo none)"; }
logs(){ grep -E 'Starting restore|Restored|Took .* to start JetStream|Filestore|Stream state|JetStream Shutdown|Initiating JetStream|Server Exiting|Trapped|Starting nats-server|Starting JetStream|Healthcheck' "$LOG" | tail -n "${1:-20}"; }
hc(){ echo "Healthcheck failed lines in the log so far: $(grep -c 'Healthcheck failed' "$LOG")"; }
restart_timed(){ # restart_timed <label> <cmd...>: iostat alongside, wall time, then the log lines
  local label="$1"; shift
  iostat -d -w 1 > "$D/iostat-$label.txt" 2>&1 & local IP=$!
  local t0=$(date +%s); "$@" >/dev/null; local t1=$(date +%s)
  kill $IP 2>/dev/null; wait $IP 2>/dev/null
  echo "wall time for '$*': $((t1-t0)) s (until /healthz answered)"
  echo "iostat (disk0 MB/s column), peak and mean while it ran:"; python3 - "$D/iostat-$label.txt" <<'PY'
import sys,re
rows=[]
for l in open(sys.argv[1]):
    p=l.split()
    if len(p)>=3 and re.match(r'^[0-9.]+$',p[0]): rows.append(float(p[2]))
rows=rows[1:] if len(rows)>1 else rows
print("  samples",len(rows),"peak MB/s",max(rows) if rows else 0,"mean MB/s",round(sum(rows)/len(rows),1) if rows else 0)
PY
  logs 14; hc
}

say "versions"; nats-server --version; nats --version; df -h "$LABDIR" | tail -1
say "fresh lab: down --purge, up 1"; $LAB down >/dev/null 2>&1; $LAB down --purge >/dev/null 2>&1; $LAB up 1; mem

say "D1 · fill EVENTS: 50,000,000 × 100 B over 6 subjects (watchdog 15 min)"
t0=$(date +%s)
nats -s $S bench js pub async --create --storage file --maxbytes 20GB --stream EVENTS --msgs 50000000 --size 100 --batch 500 --multisubject --multisubjectmax 6 --no-progress ev 2>&1 | grep -v '^$' & BP=$!
( sleep 900 && kill $BP 2>/dev/null && echo "WATCHDOG: fill stopped at 15 min" ) & WD=$!
wait $BP; kill $WD 2>/dev/null; wait $WD 2>/dev/null
echo "fill wall time: $(( $(date +%s) - t0 )) s"
sleep 2; sinfo EVENTS; mem; files EVENTS; du -sh "$STORE/EVENTS"; ls -l "$STORE/EVENTS/msgs" | head -4; ls -l "$STORE/EVENTS/msgs" | tail -3

say "D2 · clean stop (SIGTERM, cluster.sh down) → up 1"
$LAB down; sleep 1; files EVENTS
restart_timed d2 $LAB up 1; mem

say "D3 · 200,000 more messages, then SIGKILL → start 1 (index.db older than the last block)"
nats -s $S bench js pub async --stream EVENTS --msgs 200000 --size 100 --batch 500 --multisubject --multisubjectmax 6 --no-progress ev 2>&1 | grep -v '^$' | tail -1
sleep 1; sinfo EVENTS; files EVENTS
$LAB stop 1 -9; sleep 1; files EVENTS
restart_timed d3 $LAB start 1; mem; sleep 2; sinfo EVENTS

say "D4 · clean stop, delete index.db → up 1 (the no-file path)"
$LAB down; sleep 1; rm -v "$STORE/EVENTS/msgs/index.db"; files EVENTS
restart_timed d4 $LAB up 1; mem

say "D5 · the sources variant: IDLE (empty) and AGG sourcing EVENTS/ev.1 + IDLE"
nats -s $S stream add IDLE --subjects 'idle.>' --storage file --defaults >/dev/null && echo "IDLE created"
nats -s $S stream add --config $D/agg.json 2>&1 | grep -E 'created|error' ; sleep 1
echo "waiting for AGG to catch up (messages stable and lag 0), up to 15 min"
prev=-1; for i in $(seq 1 90); do sleep 10; cur=$(nats -s $S stream info AGG --json | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["state"]["messages"],max([x.get("lag",0) for x in d.get("sources") or []] or [0]))'); echo "[$(date '+%H:%M:%S')] AGG msgs,lag = $cur"; m=${cur%% *}; l=${cur##* }; if [ "$m" = "$prev" ] && [ "$l" = "0" ] && [ "$m" != "0" ]; then break; fi; prev=$m; done
sinfo AGG; files AGG; du -sh "$STORE/AGG"; mem
say "D5a · clean stop → up 1: AGG (two sources, one empty) against EVENTS"
$LAB down; sleep 1; files AGG; files EVENTS
restart_timed d5a $LAB up 1; mem
say "D5b · drop the IDLE source from AGG, clean stop → up 1"
nats -s $S stream edit AGG --config $D/agg-no-idle.json --force 2>&1 | grep -E 'updated|error'; sleep 1; sinfo AGG
$LAB down; sleep 1
restart_timed d5b $LAB up 1
say "D5c · IDLE back as a source, but with one message in it; clean stop → up 1"
nats -s $S stream edit AGG --config $D/agg.json --force 2>&1 | grep -E 'updated|error'; sleep 1
nats -s $S pub idle.one 'one message' >/dev/null; sleep 3; sinfo AGG
$LAB down; sleep 1
restart_timed d5c $LAB up 1
say "D5d · a second restart of the same shape (nothing new sourced since D5c)"
$LAB down; sleep 1
restart_timed d5d $LAB up 1

say "F · --max-msgs past a billion, and the arithmetic"
nats -s $S stream edit EVENTS --max-msgs 1000000000 --force 2>&1 | grep -E 'updated|error'; nats -s $S stream info EVENTS --json | python3 -c 'import json,sys;print("config.max_msgs =",json.load(sys.stdin)["config"]["max_msgs"])'
nats -s $S stream edit EVENTS --max-msgs 10000000000 --force 2>&1 | grep -E 'updated|error'; nats -s $S stream info EVENTS --json | python3 -c 'import json,sys;print("config.max_msgs =",json.load(sys.stdin)["config"]["max_msgs"])'
nats -s $S stream edit EVENTS --max-msgs -1 --force >/dev/null 2>&1
python3 - "$STORE/EVENTS" <<'PY'
import sys,os,json,subprocess
st=sys.argv[1]; tot=0; n=0
for f in os.listdir(st+"/msgs"):
    if f.endswith(".blk"): tot+=os.path.getsize(st+"/msgs/"+f); n+=1
info=json.loads(subprocess.check_output(["nats","-s","nats://127.0.0.1:4291","stream","info","EVENTS","--json"]))
m=info["state"]["messages"]; b=info["state"]["bytes"]
print(f"EVENTS: {m:,} messages, reported bytes {b:,} ({b/m:.2f} B/msg), {n} .blk files totalling {tot:,} B ({tot/m:.2f} B/msg on disk)")
print(f"extrapolated, as arithmetic only: 1,000,000,000 messages of this shape = {tot/m*1e9/2**30:,.1f} GiB on disk, {b/m*1e9/2**30:,.1f} GiB reported")
PY
say "done"; $LAB status; df -h "$LABDIR" | tail -1
