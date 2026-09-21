#!/usr/bin/env bash
# One-time setup bridge: attach VNC + browser to the main container's screen
# (shared via /tmp/.X11-unix) so you can log into Steam and click "Allow"
# for MapleAI. Runs in the `setup` container, used once, then removed.
# Usage: docker compose -f compose.yml -f compose.setup.yml --profile setup up setup
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

echo "[setup] browser access on :6080 — close this container when done."
wait
