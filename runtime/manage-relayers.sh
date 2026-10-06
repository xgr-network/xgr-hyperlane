#!/usr/bin/env bash

RUNTIME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$RUNTIME_DIR/runtime-state"

mkdir -p "$STATE_DIR"

env_file() {
  case "$1" in
    forward)
      if [ -f "$RUNTIME_DIR/.env.relayer" ]; then
        printf '%s\n' "$RUNTIME_DIR/.env.relayer"
      else
        printf '%s\n' "$RUNTIME_DIR/relayer-forward-mainnet.env"
      fi
      ;;
    reverse) printf '%s\n' "$RUNTIME_DIR/.env.relayer.reverse" ;;
    iln-base-to-xgr) printf '%s\n' "$RUNTIME_DIR/.env.relayer.iln.base-to-xgr" ;;
    iln-xgr-to-base) printf '%s\n' "$RUNTIME_DIR/.env.relayer.iln.xgr-to-base" ;;
    *) return 1 ;;
  esac
}

script_file() {
  case "$1" in
    forward|reverse) printf '%s\n' "$RUNTIME_DIR/native-relayer/index.mjs" ;;
    iln-base-to-xgr|iln-xgr-to-base) printf '%s\n' "$RUNTIME_DIR/native-relayer/iln.mjs" ;;
    *) return 1 ;;
  esac
}

pid_file() {
  case "$1" in
    forward) printf '%s\n' "$STATE_DIR/native-relayer.pid" ;;
    reverse) printf '%s\n' "$STATE_DIR/native-relayer-reverse.pid" ;;
    iln-base-to-xgr) printf '%s\n' "$STATE_DIR/native-iln-base-to-xgr.pid" ;;
    iln-xgr-to-base) printf '%s\n' "$STATE_DIR/native-iln-xgr-to-base.pid" ;;
    *) return 1 ;;
  esac
}

log_file() {
  case "$1" in
    forward) printf '%s\n' "$STATE_DIR/native-relayer.log" ;;
    reverse) printf '%s\n' "$STATE_DIR/native-relayer-reverse.log" ;;
    iln-base-to-xgr) printf '%s\n' "$STATE_DIR/native-iln-base-to-xgr.log" ;;
    iln-xgr-to-base) printf '%s\n' "$STATE_DIR/native-iln-xgr-to-base.log" ;;
    *) return 1 ;;
  esac
}

is_running() {
  local route="$1"
  local pf pid
  pf="$(pid_file "$route")" || return 1
  [ -f "$pf" ] || return 1
  pid="$(cat "$pf" 2>/dev/null)"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null
}

start_one() {
  local route="$1"
  local ef sf pf lf pid

  ef="$(env_file "$route")" || return 1
  sf="$(script_file "$route")" || return 1
  pf="$(pid_file "$route")" || return 1
  lf="$(log_file "$route")" || return 1

  if is_running "$route"; then
    echo "$route relayer already running: PID $(cat "$pf")"
    return 0
  fi

  if [ ! -f "$ef" ]; then
    echo "missing env file: $ef" >&2
    return 1
  fi
  if [ ! -f "$sf" ]; then
    echo "missing relayer script: $sf" >&2
    return 1
  fi

  (
    cd "$RUNTIME_DIR" || exit 1
    set -a
    . "$ef"
    set +a

    if [ -z "${RELAYER_PRIVATE_KEY:-}" ]; then
      if [ -z "${RELAYER_KEY_ACCOUNT:-}" ]; then
        echo "missing RELAYER_PRIVATE_KEY or RELAYER_KEY_ACCOUNT in $ef" >&2
        exit 1
      fi
      RELAYER_PRIVATE_KEY="$(cast wallet private-key --account "$RELAYER_KEY_ACCOUNT")" || exit 1
      export RELAYER_PRIVATE_KEY
    fi

    nohup node "$sf" >> "$lf" 2>&1 &
    echo $! > "$pf"
  )

  sleep 1
  if ! is_running "$route"; then
    echo "$route relayer failed to start; recent log:" >&2
    tail -n 50 "$lf" >&2
    rm -f "$pf"
    return 1
  fi

  pid="$(cat "$pf")"
  echo "$route relayer started: PID $pid"
  echo "log: $lf"
}

stop_one() {
  local route="$1"
  local pf pid i

  pf="$(pid_file "$route")" || return 1
  if ! is_running "$route"; then
    echo "$route relayer not running"
    rm -f "$pf"
    return 0
  fi

  pid="$(cat "$pf")"
  kill "$pid" 2>/dev/null

  i=0
  while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 20 ]; do
    sleep 1
    i=$((i + 1))
  done

  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null
  fi

  rm -f "$pf"
  echo "$route relayer stopped"
}

status_one() {
  local route="$1"
  local pf
  pf="$(pid_file "$route")" || return 1

  if is_running "$route"; then
    echo "$route: RUNNING pid=$(cat "$pf")"
  else
    echo "$route: STOPPED"
  fi
}

logs_one() {
  local route="$1"
  local lf
  lf="$(log_file "$route")" || return 1
  touch "$lf"
  tail -n 100 -f "$lf"
}

for_each_target() {
  local action="$1"
  local target="$2"

  case "$target" in
    forward|reverse|iln-base-to-xgr|iln-xgr-to-base)
      "${action}_one" "$target"
      ;;
    all)
      # "all" intentionally means the established production relayers only.
      # The ILN relayer must always be started explicitly until ILN is activated.
      "${action}_one" forward || return 1
      "${action}_one" reverse
      ;;
    *)
      echo "target must be forward, reverse, iln-base-to-xgr, iln-xgr-to-base or all" >&2
      return 1
      ;;
  esac
}

ACTION="${1:-status}"
TARGET="${2:-all}"

case "$ACTION" in
  start)
    for_each_target start "$TARGET"
    ;;
  stop)
    for_each_target stop "$TARGET"
    ;;
  restart)
    for_each_target stop "$TARGET"
    for_each_target start "$TARGET"
    ;;
  status)
    for_each_target status "$TARGET"
    ;;
  logs)
    if [ "$TARGET" = "all" ]; then
      echo "logs requires forward, reverse, iln-base-to-xgr or iln-xgr-to-base" >&2
      exit 1
    fi
    logs_one "$TARGET"
    ;;
  *)
    echo "usage: $0 {start|stop|restart|status|logs} [forward|reverse|iln-base-to-xgr|iln-xgr-to-base|all]" >&2
    exit 1
    ;;
esac
