#!/usr/bin/env bash
# config-mutability-run.sh — the commands behind raw/nats-server-src/config-mutability-observed-v2.14.6.md
# (2026-09-03, nats-server v2.14.6, nats CLI 0.4.0). Against the wiki's lab cluster: bash tools/lab/cluster.sh up 3
# Every update is sent as a raw $JS.API request so the refusal string is the server's, not the CLI's.
set -u
S="--server nats://127.0.0.1:4291 --timeout 4s"
req() { nats $S req "$1" "$2" 2>&1 | grep -vE '^$|Sending|Received' ; }
python3 - <<'PY' > base-stream.json
import json
print(json.dumps({"name":"CFG","subjects":["cfg.>"],"retention":"limits","max_consumers":-1,"max_msgs":-1,"max_bytes":-1,
 "max_age":0,"max_msgs_per_subject":-1,"max_msg_size":-1,"discard":"old","storage":"file","num_replicas":1,
 "duplicate_window":120000000000,"compression":"none","allow_direct":False,"mirror_direct":False,"sealed":False,
 "deny_delete":False,"deny_purge":False,"allow_rollup_hdrs":False,"consumer_limits":{},"allow_msg_ttl":True}))
PY
echo "### create CFG"; req '$JS.API.STREAM.CREATE.CFG' "$(cat base-stream.json)" | head -c 400; echo
upd() { # $1 label, $2 python expression modifying cfg
  python3 - "$2" <<'PY' > upd.json
import json,sys; cfg=json.load(open('base-stream.json')); exec(sys.argv[1]); print(json.dumps(cfg))
PY
  printf '### update: %s\n' "$1"; req '$JS.API.STREAM.UPDATE.CFG' "$(cat upd.json)" | python3 -c 'import json,sys
for l in sys.stdin:
    l=l.strip()
    if not l.startswith("{"): print(l); continue
    d=json.loads(l); e=d.get("error"); print("  refused:", e["err_code"], e["description"]) if e else print("  accepted; config.%s" % ", ".join("%s=%s"%(k,d["config"].get(k)) for k in ("storage","retention","discard","num_replicas","max_consumers","allow_msg_ttl","allow_msg_counter","persist_mode","compression","sealed","deny_delete","deny_purge","allow_msg_schedules","allow_rollup_hdrs","subjects")))'
}
upd "name changed"                       'cfg["name"]="CFG2"'
upd "storage file -> memory"             'cfg["storage"]="memory"'
upd "retention limits -> interest"       'cfg["retention"]="interest"'
upd "retention interest -> workqueue"    'cfg["retention"]="workqueue"'
upd "discard old -> new"                 'cfg["discard"]="new"'
upd "num_replicas 1 -> 3"                'cfg["num_replicas"]=3'
upd "num_replicas back to 1"             'cfg["num_replicas"]=1'
upd "max_consumers -1 -> 5"              'cfg["max_consumers"]=5'
upd "compression none -> s2"             'cfg["compression"]="s2"'
upd "subjects changed"                   'cfg["subjects"]=["cfg.>","other.>"]'
upd "allow_msg_counter on"               'cfg["allow_msg_counter"]=True'
upd "persist_mode -> async"              'cfg["persist_mode"]="async"'
upd "allow_msg_ttl off"                  'cfg["allow_msg_ttl"]=False'
upd "allow_msg_schedules on (needs rollup)" 'cfg["allow_msg_schedules"]=True'
upd "allow_rollup_hdrs + allow_msg_schedules on" 'cfg["allow_rollup_hdrs"]=True; cfg["allow_msg_schedules"]=True'
cp upd.json base-stream.json   # schedules now on
upd "allow_msg_schedules off again"      'cfg["allow_msg_schedules"]=False'
upd "deny_delete on"                     'cfg["deny_delete"]=True'
cp upd.json base-stream.json
upd "deny_delete off again"              'cfg["deny_delete"]=False'
upd "deny_purge on"                      'cfg["deny_purge"]=True'
cp upd.json base-stream.json
upd "deny_purge off again"               'cfg["deny_purge"]=False'
upd "sealed on"                          'cfg["sealed"]=True'
cp upd.json base-stream.json
upd "sealed off again"                   'cfg["sealed"]=False'
upd "mirror added to a stream with subjects" 'cfg["mirror"]={"name":"OTHER"}'
upd "max_age 50ms"                       'cfg["max_age"]=50000000'
upd "duplicate_window > max_age"         'cfg["max_age"]=60000000000; cfg["duplicate_window"]=120000000000'
upd "discard_new_per_subject without discard new" 'cfg["discard_new_per_subject"]=True'
upd "allow_msg_counter on a sealed stream" 'cfg["allow_msg_counter"]=True'

echo; echo "### consumer c1 (pull, explicit, filter cfg.a)"
CC='{"stream_name":"CFG","config":{"durable_name":"c1","ack_policy":"explicit","deliver_policy":"all","filter_subject":"cfg.a","replay_policy":"instant","max_deliver":-1,"ack_wait":30000000000,"max_ack_pending":1000},"action":"create"}'
req '$JS.API.CONSUMER.CREATE.CFG.c1' "$CC" | head -c 300; echo
cupd() { # $1 label, $2 python expr on cfg (the consumer config)
  python3 - "$2" <<'PY' > cupd.json
import json,sys
cfg={"durable_name":"c1","ack_policy":"explicit","deliver_policy":"all","filter_subject":"cfg.a","replay_policy":"instant","max_deliver":-1,"ack_wait":30000000000,"max_ack_pending":1000}
exec(sys.argv[1]); print(json.dumps({"stream_name":"CFG","config":cfg,"action":"update"}))
PY
  printf '### consumer update: %s\n' "$1"; req '$JS.API.CONSUMER.CREATE.CFG.c1' "$(cat cupd.json)" | python3 -c 'import json,sys
for l in sys.stdin:
    l=l.strip()
    if not l.startswith("{"): print(l); continue
    d=json.loads(l); e=d.get("error"); print("  refused:", e["err_code"], e["description"]) if e else print("  accepted; config.%s" % ", ".join("%s=%s"%(k,d["config"].get(k)) for k in ("deliver_policy","ack_policy","replay_policy","filter_subject","ack_wait","max_deliver","max_ack_pending","max_waiting","deliver_subject","mem_storage","inactive_threshold","num_replicas","backoff","description")))'
}
cupd "description"                    'cfg["description"]="hello"'
cupd "ack_wait 30s -> 10s"            'cfg["ack_wait"]=10000000000'
cupd "max_deliver -1 -> 5"            'cfg["max_deliver"]=5'
cupd "max_ack_pending 1000 -> 10"     'cfg["max_ack_pending"]=10'
cupd "filter_subject cfg.a -> cfg.b"  'cfg["filter_subject"]="cfg.b"'
cupd "filter_subjects [cfg.a, cfg.c]" 'cfg.pop("filter_subject"); cfg["filter_subjects"]=["cfg.a","cfg.c"]'
cupd "backoff [1s,2s] with max_deliver 5" 'cfg["max_deliver"]=5; cfg["backoff"]=[1000000000,2000000000]; cfg["ack_wait"]=1000000000'
cupd "backoff [1s,2s,3s] with max_deliver 2" 'cfg["max_deliver"]=2; cfg["backoff"]=[1000000000,2000000000,3000000000]; cfg["ack_wait"]=1000000000'
cupd "inactive_threshold 1m"          'cfg["inactive_threshold"]=60000000000'
cupd "num_replicas 1"                 'cfg["num_replicas"]=1'
cupd "deliver_policy all -> new"      'cfg["deliver_policy"]="new"'
cupd "ack_policy explicit -> all"     'cfg["ack_policy"]="all"'
cupd "replay_policy -> original"      'cfg["replay_policy"]="original"'
cupd "opt_start_seq 5 (with by_start_sequence)" 'cfg["deliver_policy"]="by_start_sequence"; cfg["opt_start_seq"]=5'
cupd "pull -> push (deliver_subject)" 'cfg["deliver_subject"]="push.c1"'
cupd "max_waiting 512 -> 10"          'cfg["max_waiting"]=10'
cupd "mem_storage on"                 'cfg["mem_storage"]=True'
cupd "idle_heartbeat on a pull consumer" 'cfg["idle_heartbeat"]=5000000000'
cupd "flow_control on a pull consumer" 'cfg["flow_control"]=True'
cupd "priority_groups + policy on a pull consumer" 'cfg["priority_groups"]=["a"]; cfg["priority_policy"]="overflow"'
cupd "durable_name changed"           'cfg["durable_name"]="c9"'
cupd "max_batch 5"                    'cfg["max_batch"]=5'

echo; echo "### STREAM.INFO with subjects_filter, after 3 publishes"
for s in cfg.a cfg.b cfg.a; do nats $S pub $s "x" >/dev/null 2>&1; done
req '$JS.API.STREAM.INFO.CFG' '{"subjects_filter":">"}' | python3 -c 'import json,sys; d=json.loads([l for l in sys.stdin if l.startswith("{")][0]); print("  state.num_subjects:", d["state"].get("num_subjects"), " subjects:", d["state"].get("subjects"), " paging total/offset/limit:", d.get("total"), d.get("offset"), d.get("limit"))'
echo; echo "### MSG.NEXT batch 300 (no_wait) on c1 (filter cfg.a: 2 messages)"
nats $S req '$JS.API.CONSUMER.MSG.NEXT.CFG.c1' '{"batch":300,"no_wait":true}' --replies 3 2>&1 | grep -vE '^$|Sending' | cut -c1-160
echo; echo "### MSG.NEXT batch 300 on c1 after max_batch 5"
nats $S req '$JS.API.CONSUMER.MSG.NEXT.CFG.c1' '{"batch":300,"no_wait":true}' --replies 1 2>&1 | grep -vE '^$|Sending' | cut -c1-200
echo; echo "### cleanup"; req '$JS.API.STREAM.DELETE.CFG' '' | head -c 120; echo
