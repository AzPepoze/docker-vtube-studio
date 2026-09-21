#!/usr/bin/env bash
set -euo pipefail

PIDS=""
cleanup() {
  # shellcheck disable=SC2086
  for p in $PIDS; do kill "$p" 2>/dev/null || true; done
}
trap cleanup EXIT TERM INT

if [ -n "${VNC_PASSWORD:-}" ]; then
  x11vnc -display "${DISPLAY:-:99}" -forever -shared -rfbport 5900 -passwd "$VNC_PASSWORD" </dev/null &
else
  x11vnc -display "${DISPLAY:-:99}" -forever -shared -rfbport 5900 </dev/null &
fi
PIDS="$PIDS $!"
websockify --web /opt/novnc 6080 localhost:5900 </dev/null &
PIDS="$PIDS $!"

echo "[vnc] remote control: http://${PUBLIC_HOST:-localhost}:6080/vnc.html"
wait
