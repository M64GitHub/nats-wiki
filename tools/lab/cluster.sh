#!/usr/bin/env bash
# tools/lab/cluster.sh — the wiki's scratch nats-server cluster, in one command.
#
# Starts n nats-server processes (1 = standalone, 3 or 4 = cluster `east`) on the pinned release,
# with the exact shape every raw/nats-server-src/*-observed-v2.14.6.md run was made with, so those
# runs can be repeated by whoever clones the repo. Node k listens on 127.0.0.1:429k (clients),
# 629k (routes) and 829k (monitoring); the system-account user is sys / sys. Stores, logs and pid
# files live under a scratch directory, never in the repo. See tools/lab/README.md.
#
#   bash tools/lab/cluster.sh up [n]          start n nodes (default 3), wait until healthy
#   bash tools/lab/cluster.sh down [--purge]  SIGTERM every node; --purge also deletes the stores
#   bash tools/lab/cluster.sh status          one line per node: pid, health, meta leader
#   bash tools/lab/cluster.sh logs k [tail…]  the log of node k (extra args go to tail)
#   bash tools/lab/cluster.sh conf k          print the rendered config of node k
#   bash tools/lab/cluster.sh stop k [-9]     SIGTERM (or SIGKILL with -9) one node, keep its store
#   bash tools/lab/cluster.sh start k         restart one node on its rendered config and store
#   bash tools/lab/cluster.sh url [k]         print nats://sys:sys@127.0.0.1:429k for the CLI
#
# Environment:
#   NATS_LAB_DIR      scratch directory      (default: ${TMPDIR:-/tmp}/nats-lab)
#   NATS_LAB_VERSION  the release required   (default: v2.14.6 — the wiki's verified-against)
#   NATS_SERVER       the binary             (default: nats-server on PATH)
#   NATS_LAB_FLAGS    extra flags per node   (default: none; e.g. "-DV" for debug and trace logs)
#   NATS_LAB_WAIT     seconds to wait for health after `up` (default: 30)
#
# Needs bash 3.2+ (macOS ships 3.2), curl and python3. Nothing else.

set -euo pipefail

TMP_BASE="${TMPDIR:-/tmp}"; TMP_BASE="${TMP_BASE%/}"
LAB_DIR="${NATS_LAB_DIR:-$TMP_BASE/nats-lab}"
LAB_DIR="${LAB_DIR%/}"
WANT_VERSION="${NATS_LAB_VERSION:-v2.14.6}"
BIN="${NATS_SERVER:-nats-server}"
EXTRA_FLAGS="${NATS_LAB_FLAGS:-}"
WAIT_SECS="${NATS_LAB_WAIT:-30}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME=east
MAX_NODES=9

usage() { sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
die()   { echo "cluster.sh: $*" >&2; exit 1; }

client_port() { echo $((4290 + $1)); }
route_port()  { echo $((6290 + $1)); }
http_port()   { echo $((8290 + $1)); }
node_dir()    { echo "$LAB_DIR/n$1"; }
pid_file()    { echo "$(node_dir "$1")/n$1.pid"; }
log_file()    { echo "$(node_dir "$1")/n$1.log"; }
conf_file()   { echo "$(node_dir "$1")/n$1.conf"; }
store_dir()   { echo "$(node_dir "$1")/store"; }

check_k() {
  case "${1:-}" in
    [1-9]) ;;
    *) die "node number must be 1..$MAX_NODES, got '${1:-}'" ;;
  esac
}

# The count the cluster was started with, remembered so `status` and `start` know the shape.
count_file() { echo "$LAB_DIR/count"; }
node_count() { [ -f "$(count_file)" ] && cat "$(count_file)" || echo 0; }

alive() {           # alive k → 0 if node k's recorded pid is running
  local pf; pf="$(pid_file "$1")"
  [ -f "$pf" ] || return 1
  kill -0 "$(cat "$pf")" 2>/dev/null
}

port_free() {       # port_free 4291 → 0 when nothing is bound to it on 127.0.0.1
  python3 - "$1" <<'PY'
import socket, sys
s = socket.socket(); s.settimeout(0.2)
try:
    s.connect(("127.0.0.1", int(sys.argv[1]))); sys.exit(1)
except OSError:
    sys.exit(0)
PY
}

http_code() {       # http_code URL → the status code, or 000 when nothing answers
  local c
  c="$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$1" 2>/dev/null || true)"
  echo "${c:-000}"
}

jsz_meta() {        # jsz_meta k → "leader cluster_size" from /jsz (empty when JetStream is off)
  curl -s --max-time 2 "http://127.0.0.1:$(http_port "$1")/jsz" 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
m = d.get("meta_cluster") or {}
print(m.get("leader", "-"), m.get("cluster_size", "-"))
' 2>/dev/null || true
}

check_version() {
  command -v "$BIN" >/dev/null 2>&1 || die "$BIN not found on PATH (set NATS_SERVER=/path/to/nats-server)"
  local out have
  out="$("$BIN" --version 2>&1 | head -n 1)"
  have="${out##* }"
  echo "binary: $out ($(command -v "$BIN"))"
  if [ "${have#v}" != "${WANT_VERSION#v}" ]; then
    die "refusing to start: binary is $have, this lab wants $WANT_VERSION (NATS_LAB_VERSION). Every verified-against in the wiki names one release; keep the binary on it, or set NATS_LAB_VERSION deliberately and say so in the run."
  fi
}

render() {          # render k n → writes node k's config for an n-node lab
  local k="$1" n="$2" tmpl routes="" j
  local d; d="$(node_dir "$k")"
  mkdir -p "$d" "$(store_dir "$k")"
  if [ "$n" -eq 1 ]; then
    tmpl="$HERE/conf/standalone.conf.tmpl"
  else
    tmpl="$HERE/conf/node.conf.tmpl"
    j=1
    while [ "$j" -le "$n" ]; do
      if [ "$j" -ne "$k" ]; then
        routes="${routes:+$routes, }nats://127.0.0.1:$(route_port "$j")"
      fi
      j=$((j + 1))
    done
  fi
  sed -e "s|@NAME@|n$k|g" \
      -e "s|@CLIENT_PORT@|$(client_port "$k")|g" \
      -e "s|@CLUSTER_PORT@|$(route_port "$k")|g" \
      -e "s|@HTTP_PORT@|$(http_port "$k")|g" \
      -e "s|@STORE_DIR@|$(store_dir "$k")|g" \
      -e "s|@ROUTES@|$routes|g" \
      "$tmpl" > "$(conf_file "$k")"
}

launch() {          # launch k → start node k on its rendered config, record the pid
  local k="$1" cf lf pf
  cf="$(conf_file "$k")"; lf="$(log_file "$k")"; pf="$(pid_file "$k")"
  [ -f "$cf" ] || die "no rendered config for n$k — run 'up' first"
  if alive "$k"; then echo "n$k: already running (pid $(cat "$pf"))"; return 0; fi
  for p in "$(client_port "$k")" "$(http_port "$k")" "$(route_port "$k")"; do
    port_free "$p" || die "port $p is in use by something that is not this lab's n$k — stop it first"
  done
  # shellcheck disable=SC2086
  ( nohup "$BIN" -c "$cf" -l "$lf" -P "$pf" $EXTRA_FLAGS </dev/null >/dev/null 2>&1 & )
  local i=0
  while [ ! -s "$pf" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
  [ -s "$pf" ] || die "n$k did not write its pid file — read $lf"
  echo "n$k: pid $(cat "$pf")  client 127.0.0.1:$(client_port "$k")  http 127.0.0.1:$(http_port "$k")  log $lf"
}

wait_healthy() {    # wait_healthy n → block until /healthz (and the meta group, if clustered) is ok
  local n="$1" k deadline now code query
  query=""; [ "$n" -gt 1 ] && query="?js-meta-only=true"
  deadline=$(( $(date +%s) + WAIT_SECS ))
  k=1
  while [ "$k" -le "$n" ]; do
    while :; do
      code="$(http_code "http://127.0.0.1:$(http_port "$k")/healthz$query")"
      [ "$code" = "200" ] && break
      now=$(date +%s)
      if [ "$now" -ge "$deadline" ]; then
        echo "n$k: /healthz$query is $code after ${WAIT_SECS}s — see $(log_file "$k")" >&2
        return 1
      fi
      sleep 0.25
    done
    k=$((k + 1))
  done
  return 0
}

cmd_up() {
  local n="${1:-3}" k
  case "$n" in [1-9]) ;; *) die "up takes a node count 1..$MAX_NODES (the wiki's runs used 1, 3 and 4)";; esac
  check_version
  mkdir -p "$LAB_DIR"
  echo "lab dir: $LAB_DIR"
  local reused=0
  k=1
  while [ "$k" -le "$n" ]; do
    if [ -d "$(store_dir "$k")/jetstream" ]; then reused=1; fi
    render "$k" "$n"
    k=$((k + 1))
  done
  [ "$reused" -eq 1 ] && echo "note: reusing existing store directories (this is a restart with data; 'down --purge' clears them)"
  echo "$n" > "$(count_file)"
  k=1
  while [ "$k" -le "$n" ]; do launch "$k"; k=$((k + 1)); done
  if wait_healthy "$n"; then
    if [ "$n" -gt 1 ]; then
      echo "healthy: $n nodes, /healthz?js-meta-only=true ok on every node; meta leader $(jsz_meta 1 | cut -d' ' -f1), cluster_size $(jsz_meta 1 | cut -d' ' -f2)"
    else
      echo "healthy: standalone n1, /healthz ok"
    fi
    echo "nats CLI: nats --server $(cmd_url 1) …"
  else
    echo "started, but not healthy within ${WAIT_SECS}s — 'status' and 'logs k' show why" >&2
    exit 1
  fi
}

stop_one() {        # stop_one k [-9]
  local k="$1" sig="${2:-}" pf pid i
  pf="$(pid_file "$k")"
  if ! alive "$k"; then echo "n$k: not running"; rm -f "$pf"; return 0; fi
  pid="$(cat "$pf")"
  if [ "$sig" = "-9" ]; then
    kill -KILL "$pid" 2>/dev/null || true
    echo "n$k: SIGKILL sent to pid $pid"
  else
    kill -TERM "$pid" 2>/dev/null || true
    i=0
    while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
      echo "n$k: pid $pid did not exit on SIGTERM within 10s, killed"
    else
      echo "n$k: stopped (SIGTERM, pid $pid)"
    fi
  fi
  rm -f "$pf"
}

cmd_down() {
  local purge=0 k
  [ "${1:-}" = "--purge" ] && purge=1
  k=1
  while [ "$k" -le "$MAX_NODES" ]; do
    [ -d "$(node_dir "$k")" ] && stop_one "$k"
    k=$((k + 1))
  done
  if [ "$purge" -eq 1 ]; then
    rm -rf "$LAB_DIR"
    echo "purged $LAB_DIR"
  else
    echo "stores kept under $LAB_DIR ('down --purge' deletes them)"
  fi
}

cmd_status() {
  local n k pf pid a code meta leader size
  n="$(node_count)"
  [ "$n" -gt 0 ] || { echo "no lab under $LAB_DIR (run 'up')"; return 0; }
  printf '%-4s %-7s %-5s %-6s %-5s %-8s %-8s %-11s %s\n' node pid alive client http healthz js-meta meta_leader cluster_size
  k=1
  while [ "$k" -le "$n" ]; do
    pf="$(pid_file "$k")"; pid="-"; a=no
    if alive "$k"; then pid="$(cat "$pf")"; a=yes; fi
    code="$(http_code "http://127.0.0.1:$(http_port "$k")/healthz")"
    meta="$(http_code "http://127.0.0.1:$(http_port "$k")/healthz?js-meta-only=true")"
    leader=-; size=-
    if [ "$a" = yes ]; then
      set -- $(jsz_meta "$k"); leader="${1:--}"; size="${2:--}"
    fi
    printf '%-4s %-7s %-5s %-6s %-5s %-8s %-8s %-11s %s\n' "n$k" "$pid" "$a" "$(client_port "$k")" "$(http_port "$k")" "$code" "$meta" "$leader" "$size"
    k=$((k + 1))
  done
  echo "lab dir: $LAB_DIR   version gate: $WANT_VERSION"
}

cmd_logs()  { check_k "${1:-}"; local k="$1"; shift; [ -f "$(log_file "$k")" ] || die "no log for n$k"; [ $# -eq 0 ] && set -- -n 50; tail "$@" "$(log_file "$k")"; }
cmd_conf()  { check_k "${1:-}"; [ -f "$(conf_file "$1")" ] || die "no rendered config for n$1 — run 'up' first"; echo "# $(conf_file "$1")"; cat "$(conf_file "$1")"; }
cmd_stop()  { check_k "${1:-}"; stop_one "$1" "${2:-}"; }
cmd_start() { check_k "${1:-}"; check_version; launch "$1"; }
cmd_url()   { local k="${1:-1}"; check_k "$k"; echo "nats://sys:sys@127.0.0.1:$(client_port "$k")"; }

case "${1:-}" in
  up)     shift; cmd_up "$@" ;;
  down)   shift; cmd_down "$@" ;;
  status) cmd_status ;;
  logs)   shift; cmd_logs "$@" ;;
  conf)   shift; cmd_conf "$@" ;;
  stop)   shift; cmd_stop "$@" ;;
  start)  shift; cmd_start "$@" ;;
  url)    shift; cmd_url "$@" ;;
  -h|--help|help|"") usage 0 ;;
  *) echo "cluster.sh: unknown command '$1'" >&2; usage 1 ;;
esac
