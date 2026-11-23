#!/bin/bash
# OpenMausBot on Railway: prepare the volume, run the app and the edge as
# separate unprivileged users, and exit the container when either one stops.
set -euo pipefail
set -m

APP_USER="maus"
EDGE_USER="caddy"
DATA_DIR="/data"
STOP_TIMEOUT=25

log() { printf '[entrypoint] %s\n' "$*"; }
fail() { printf '[entrypoint] ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "must start as root to prepare $DATA_DIR"
[ -n "${PORT:-}" ] || fail "PORT is not set"
case "$PORT" in
  ''|*[!0-9]*) fail "PORT must be a number, got '$PORT'" ;;
esac
[ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ] || fail "PORT out of range: $PORT"

umask 077
mkdir -p "$DATA_DIR"
if [ "$(stat -c %d "$DATA_DIR")" = "$(stat -c %d /)" ]; then
  log "WARNING: $DATA_DIR is not a mounted volume; state will be lost on redeploy"
fi

APP_UID="$(id -u "$APP_USER")"
APP_GID="$(id -g "$APP_USER")"
EDGE_UID="$(id -u "$EDGE_USER")"
EDGE_GID="$(id -g "$EDGE_USER")"

DATA_UID="$(stat -c %u "$DATA_DIR")"
DATA_GID="$(stat -c %g "$DATA_DIR")"
if [ "$DATA_UID" != "$APP_UID" ] || [ "$DATA_GID" != "$APP_GID" ]; then
  log "handing $DATA_DIR to $APP_USER (was $DATA_UID:$DATA_GID)"
  chown -R "$APP_UID:$APP_GID" "$DATA_DIR"
fi
chmod 700 "$DATA_DIR"

ROOT_OWNED="$(find "$DATA_DIR" -xdev -user 0 -print -quit 2>/dev/null || true)"
if [ -n "$ROOT_OWNED" ]; then
  log "returning root-owned files to $APP_USER (first: $ROOT_OWNED)"
  find "$DATA_DIR" -xdev -user 0 -exec chown -h "$APP_UID:$APP_GID" {} +
fi

log "starting OpenMausBot as $APP_USER"
setpriv --reuid="$APP_UID" --regid="$APP_GID" --init-groups /usr/local/bin/run-omb.sh &
OMB_PID=$!

log "starting Caddy as $EDGE_USER on :$PORT"
setpriv --reuid="$EDGE_UID" --regid="$EDGE_GID" --init-groups \
  env HOME=/tmp/caddy XDG_DATA_HOME=/tmp/caddy/data XDG_CONFIG_HOME=/tmp/caddy/config \
  /usr/local/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
CADDY_PID=$!

shutdown() {
  local code="${1:-0}"
  trap - TERM INT
  log "stopping OpenMausBot and Caddy"
  kill -TERM -- "-$OMB_PID" "-$CADDY_PID" 2>/dev/null || true
  local i
  for i in $(seq 1 "$STOP_TIMEOUT"); do
    if ! kill -0 "$OMB_PID" 2>/dev/null && ! kill -0 "$CADDY_PID" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  kill -KILL -- "-$OMB_PID" "-$CADDY_PID" 2>/dev/null || true
  wait 2>/dev/null || true
  exit "$code"
}
trap 'shutdown 0' TERM INT

log "OpenMausBot pid $OMB_PID, Caddy pid $CADDY_PID"
set +e
wait -n
STATUS=$?
set -e
log "a child exited with status $STATUS; stopping the container"
shutdown "$STATUS"
