#!/usr/bin/env bash
# Boot a virtual screen, make sure VTube Studio is installed, run it,
# and publish the screen as an HLS watch page (paste-able URL, no VNC).
set -euo pipefail

PIDS=""

cleanup() {
  # shellcheck disable=SC2086
  for p in $PIDS; do kill "$p" 2>/dev/null || true; done
}
trap cleanup EXIT TERM INT

mkdir -p /tmp/.X11-unix "$HOME"

echo "[boot] starting virtual display ${DISPLAY:-:99}..."
# NOTE: background daemons get </dev/null so they can never steal keystrokes
# from the interactive Steam login prompt below.
Xvfb "${DISPLAY:-:99}" -screen 0 1280x720x24 </dev/null &
PIDS="$PIDS $!"
openbox </dev/null 2>/dev/null &
PIDS="$PIDS $!"

if /usr/local/bin/install-vts.sh; then
  if [ "${ENABLE_STREAM:-1}" = "1" ]; then
    echo "[boot] watch page on :${STREAM_PORT:-8080}"
    STREAM_DIR="${STREAM_DIR:-/srv/stream}" STREAM_PORT="${STREAM_PORT:-8080}" /usr/local/bin/serve.py </dev/null &
    PIDS="$PIDS $!"
    mkdir -p "${STREAM_DIR:-/srv/stream}"
    ffmpeg -hide_banner -loglevel warning \
      -f x11grab -video_size 1280x720 -framerate 15 -i "${DISPLAY:-:99}" \
      -c:v libx264 -preset veryfast -tune zerolatency -pix_fmt yuv420p -g 30 \
      -hls_time 2 -hls_list_size 6 -hls_flags delete_segments \
      -hls_segment_filename "${STREAM_DIR:-/srv/stream}/seg%03d.ts" \
      "${STREAM_DIR:-/srv/stream}/stream.m3u8" </dev/null &
    PIDS="$PIDS $!"
  else
    echo "[boot] stream disabled (ENABLE_STREAM=0)"
  fi

  VTS_EXE="$(cat "${EXE_CACHE:-$(dirname "${VTS_DIR:-/data/vts}")/.vts-exe}")"
  echo "[boot] launching VTube Studio: $VTS_EXE"
  export STEAM_COMPAT_DATA_PATH="${WINEPREFIX:-/data/prefix}"
  export STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-/opt/steamcmd}"

  # Foreground: trap on EXIT/TERM cleans up Xvfb, ffmpeg and the web server.
  "${PROTONPATH:?PROTONPATH not set}/proton" run "$VTS_EXE" &
  PROTON_PID=$!
  PIDS="$PIDS $PROTON_PID"
  wait "$PROTON_PID"
else
  echo "[boot] install needs your Steam login first. Run this in another terminal:"
  echo "[boot]   docker exec -it vtube-studio install-vts.sh"
  echo "[boot] then restart this container: docker compose restart"
  exec tail -f /dev/null
fi
