#!/usr/bin/env bash
# runE.sh — row 9, the cardinality pair: CARD (1.2 M subjects) against FLAT (6 subjects), same message count.
# nats-server v2.14.6 through tools/lab/cluster.sh up 1. Output is the transcript; log lines come from n1.log.
set -u
cd /Users/m64/space/64/nats-wiki
LAB="bash tools/lab/cluster.sh"
S=nats://127.0.0.1:4291
LABDIR="${TMPDIR:-/tmp}"; LABDIR="${LABDIR%/}/nats-lab"
STORE="$LABDIR/n1/store/jetstream/\$G/streams"
LOG="$LABDIR/n1/n1.log"
say(){ echo; echo "### [$(date '+%H:%M:%S')] $*"; }
mem(){ curl -s 127.0.0.1:8291/varz | python3 -c 'import json,sys;d=json.load(sys.stdin);print("varz mem:",d["mem"],"bytes =",round(d["mem"]/1048576,1),"MiB")'; }
rss(){ ps -o rss= -p "$(cat "$LABDIR/n1/n1.pid")" | awk '{print "ps rss:",$1,"KB =",$1/1024,"MiB"}'; }
sinfo(){ nats -s $S stream info "$1" --json | python3 -c 'import json,sys;d=json.load(sys.stdin);s=d["state"];print("stream",d["config"]["name"],"subjects",d["config"]["subjects"],"messages",s["messages"],"bytes",s["bytes"],"first",s["first_seq"],"last",s["last_seq"],"num_subjects",s.get("num_subjects"),"num_deleted",s.get("num_deleted",0))'; }
files(){ echo "$1: $(ls "$STORE/$1/msgs" | wc -l | tr -d ' ') files in msgs/, $(du -sh "$STORE/$1/msgs" | cut -f1), index.db: $(ls -l "$STORE/$1/msgs/index.db" 2>/dev/null | awk '{print $5" bytes"}' || echo none)"; }
logs(){ grep -E 'Starting restore|Restored|Took .* to start JetStream|Filestore|Stream state|JetStream Shutdown|Initiating JetStream|Server Exiting|Trapped|Starting nats-server|Starting JetStream' "$LOG" | tail -n "${1:-20}"; }

say "versions"; nats-server --version; nats --version
say "fresh lab: up 1"; $LAB down >/dev/null 2>&1; $LAB down --purge >/dev/null 2>&1; $LAB up 1
say "baseline"; mem; rss

say "fill CARD: 3,000,000 × 100 B over 1,200,000 subjects"
nats -s $S bench js pub async --create --storage file --maxbytes 4GB --stream CARD --msgs 3000000 --size 100 --batch 500 --multisubject --multisubjectmax 1200000 --no-progress card 2>&1 | grep -v '^$'
sleep 2; sinfo CARD; mem; rss; files CARD

say "fill FLAT: 3,000,000 × 100 B over 6 subjects"
nats -s $S bench js pub async --create --storage file --maxbytes 4GB --stream FLAT --msgs 3000000 --size 100 --batch 500 --multisubject --multisubjectmax 6 --no-progress flat 2>&1 | grep -v '^$'
sleep 2; sinfo FLAT; mem; rss; files FLAT

say "predicted index.db subject term for CARD: sum(len(subject)+4)"
python3 -c 'print(sum(len(f"card.{i}")+4 for i in range(1200000)),"bytes for 1,200,000 subjects; FLAT:",sum(len(f"flat.{i}")+4 for i in range(6)))'

say "watch for the periodic index.db (flushStreamStateLoop) for up to 5 min"
for i in $(seq 1 30); do sleep 10; echo "[$(date '+%H:%M:%S')] +$((i*10))s  CARD index.db: $(ls -l "$STORE/CARD/msgs/index.db" 2>/dev/null | awk '{print $5" bytes"}' || echo none)   FLAT index.db: $(ls -l "$STORE/FLAT/msgs/index.db" 2>/dev/null | awk '{print $5" bytes"}' || echo none)"; done
files CARD; files FLAT; mem; rss

say "E1 · clean stop (SIGTERM) → up 1"
$LAB down; sleep 1; files CARD; files FLAT
$LAB up 1 >/dev/null; sleep 1; logs 12; mem; rss

say "E2 · 200,000 more messages into each, then SIGKILL within the flush window → start 1"
nats -s $S bench js pub async --stream CARD --msgs 200000 --size 100 --batch 500 --multisubject --multisubjectmax 1200000 --no-progress card 2>&1 | grep -v '^$' | tail -1
nats -s $S bench js pub async --stream FLAT --msgs 200000 --size 100 --batch 500 --multisubject --multisubjectmax 6 --no-progress flat 2>&1 | grep -v '^$' | tail -1
sleep 1; sinfo CARD; sinfo FLAT; files CARD; files FLAT
$LAB stop 1 -9; sleep 1; files CARD; files FLAT
$LAB start 1 >/dev/null; sleep 1; logs 12; mem; rss
sleep 3; sinfo CARD; sinfo FLAT

say "E3 · a filtered pull consumer on each (card.1* / flat.1), read once, timed"
for st in CARD FLAT; do
  f="card.1*"; [ "$st" = FLAT ] && f="flat.1"
  nats -s $S consumer add "$st" F1 --filter "$f" --pull --ack none --deliver all --defaults >/dev/null
  N=$(nats -s $S consumer info "$st" F1 --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["num_pending"])')
  echo "$st F1 filter=$f num_pending=$N"
  nats -s $S bench js consume --stream "$st" --consumer F1 --msgs "$N" --batch 500 --acks none --no-progress 2>&1 | grep -v '^$' | tail -1
done

say "E4 · delete index.db on a cleanly stopped store → up 1 (the no-file path)"
$LAB down; sleep 1; rm -v "$STORE/CARD/msgs/index.db" "$STORE/FLAT/msgs/index.db" 2>&1; files CARD; files FLAT
$LAB up 1 >/dev/null; sleep 1; logs 12
say "done; leaving the server up"; $LAB status
