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
# `restart` reuses the container filesystem, so drop our own stale X lock.
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
# Give openbox the empty menu file it keeps asking for (kills a startup warning).
mkdir -p "$HOME/.config/openbox"
[ -f "$HOME/.config/openbox/menu.xml" ] || printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' '<openbox_menu xmlns="http://openbox.org/3.4/menu">' '</openbox_menu>' > "$HOME/.config/openbox/menu.xml"

echo "[boot] starting virtual display ${DISPLAY:-:99}..."
# Small screen on purpose: llvmpipe renders on CPU, cost scales with pixels.
# 640x360 is plenty for the watch page; raise via SCREEN_GEOM if you have cores to burn.
SCREEN_GEOM="${SCREEN_GEOM:-640x360x24}"
SCREEN_SIZE="${SCREEN_GEOM%x*}"
Xvfb "${DISPLAY:-:99}" -screen 0 "$SCREEN_GEOM" </dev/null &
PIDS="$PIDS $!"
openbox </dev/null 2>/dev/null &
PIDS="$PIDS $!"

if /usr/local/bin/install-vts.sh; then

# Guarantee the VTS API server is on: fresh installs ship Config_StartAPI=false,
# which means nothing answers on port 8001. Enforce every boot (idempotent).
# Also cap llvmpipe render threads: without a GPU, VTS will happily eat every
# core via software rendering. Override with LP_NUM_THREADS if you want more.
export LP_NUM_THREADS="${LP_NUM_THREADS:-4}"
python3 - "$VTS_DIR" <<'EOF'
import json, sys
p = sys.argv[1] + "/VTube Studio_Data/StreamingAssets/Config/vts_config.json"
try:
    d = json.load(open(p))
    for it in d.get("BoolData", []):
        if it.get("Key") == "Config_StartAPI":
            it["Value"] = True
    json.dump(d, open(p, "w"), indent=4)
    print("[boot] VTS API server enabled (Config_StartAPI=true).")
except Exception as e:
    print(f"[boot] WARNING: could not enable VTS API in config: {e}")
EOF
  if [ "${ENABLE_STREAM:-1}" = "1" ]; then
    echo "[boot] watch page on :${STREAM_PORT:-8080}"
    STREAM_DIR="${STREAM_DIR:-/srv/stream}" STREAM_PORT="${STREAM_PORT:-8080}" /usr/local/bin/serve.py </dev/null &
    PIDS="$PIDS $!"
    mkdir -p "${STREAM_DIR:-/srv/stream}"
    ffmpeg -hide_banner -loglevel warning \
      -f x11grab -video_size "${SCREEN_SIZE:-640x360}" -framerate "${STREAM_FPS:-15}" -i "${DISPLAY:-:99}" \
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
  echo "[vts] ready:"
  echo "[vts]   API:   ws://${PUBLIC_HOST:-localhost}:${HOST_VTS_PORT:-8001}"
  echo "[vts]   Watch: http://${PUBLIC_HOST:-localhost}:${HOST_STREAM_PORT:-8090}"
  echo "[vts]   VNC:   http://${PUBLIC_HOST:-localhost}:6080/vnc.html (needs: docker compose --profile vnc up -d)"
  export STEAM_COMPAT_DATA_PATH="${WINEPREFIX:-/data/prefix}"
  export STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-/opt/steamcmd}"
  mkdir -p "$STEAM_COMPAT_DATA_PATH"

  # Foreground: trap on EXIT/TERM cleans up Xvfb, ffmpeg and the web server.
  # VTS ships start_without_steam.bat (= exe -nosteam): without a running
  # Steam client the Steamworks check fails and VTS quits after ~4s.
  # -nosteam is the official way to run it standalone (API unaffected).
  "${PROTONPATH:?PROTONPATH not set}/proton" run "$VTS_EXE" -nosteam &
  PROTON_PID=$!
  PIDS="$PIDS $PROTON_PID"
  wait "$PROTON_PID"
else
  echo "[boot] install needs your Steam login first. Run this in another terminal:"
  echo "[boot]   docker exec -it vtube-studio install-vts.sh"
  echo "[boot] then restart this container: docker compose restart"
  exec tail -f /dev/null
fi
