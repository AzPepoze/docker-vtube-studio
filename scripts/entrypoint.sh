#!/usr/bin/env bash
set -euo pipefail

PIDS=""

cleanup() {
  # shellcheck disable=SC2086
  for p in $PIDS; do kill "$p" 2>/dev/null || true; done
}
trap cleanup EXIT TERM INT

mkdir -p /tmp/.X11-unix "$HOME"
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
mkdir -p "$HOME/.config/openbox"
[ -f "$HOME/.config/openbox/menu.xml" ] || printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' '<openbox_menu xmlns="http://openbox.org/3.4/menu">' '</openbox_menu>' > "$HOME/.config/openbox/menu.xml"

echo "[boot] starting virtual display ${DISPLAY:-:99}..."
SCREEN_GEOM="${SCREEN_GEOM:-640x360x24}"
SCREEN_SIZE="${SCREEN_GEOM%x*}"
SOCK="/tmp/.X11-unix/X${DISPLAY#:}"
Xvfb "${DISPLAY:-:99}" -screen 0 "$SCREEN_GEOM" </dev/null >/dev/null 2>&1 &
PIDS="$PIDS $!"
openbox </dev/null >/dev/null 2>&1 &
PIDS="$PIDS $!"
for _ in $(seq 1 20); do [ -S "$SOCK" ] && break; sleep 0.5; done
[ -S "$SOCK" ] || { echo "[boot] virtual display failed to start"; exit 1; }
echo "[boot] display ready (${SCREEN_GEOM})."

if /usr/local/bin/install-vts.sh; then

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
    STREAM_DIR="${STREAM_DIR:-/srv/stream}" STREAM_PORT="${STREAM_PORT:-8080}" /usr/local/bin/serve.py </dev/null &
    PIDS="$PIDS $!"
    mkdir -p "${STREAM_DIR:-/srv/stream}"
    echo "[boot] stream on (${STREAM_FPS:-60} fps)."
    ffmpeg -hide_banner -loglevel error \
      -f x11grab -video_size "${SCREEN_SIZE:-640x360}" -framerate "${STREAM_FPS:-60}" -i "${DISPLAY:-:99}" \
      -c:v libx264 -preset veryfast -tune zerolatency -pix_fmt yuv420p -g 30 \
      -hls_time 2 -hls_list_size 6 -hls_flags delete_segments \
      -hls_segment_filename "${STREAM_DIR:-/srv/stream}/seg%03d.ts" \
      "${STREAM_DIR:-/srv/stream}/stream.m3u8" </dev/null &
    PIDS="$PIDS $!"
  else
    echo "[boot] stream disabled (ENABLE_STREAM=0)"
  fi

  VTS_EXE="$(cat "${EXE_CACHE:-$(dirname "${VTS_DIR:-/data/vts}")/.vts-exe}")"
  echo "[boot] launching VTube Studio."
  echo "--------------------------------------------------"
  echo "[vts] ready:"
  echo "[vts]   API:   ws://${PUBLIC_HOST:-localhost}:${HOST_VTS_PORT:-8001}"
  echo "[vts]   Watch: http://${PUBLIC_HOST:-localhost}:${HOST_STREAM_PORT:-8090}"
  echo "[vts]   VNC:   http://${PUBLIC_HOST:-localhost}:6080/vnc.html (needs: docker compose --profile vnc up -d)"
  echo "--------------------------------------------------"
  export STEAM_COMPAT_DATA_PATH="${WINEPREFIX:-/data/prefix}"
  export STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-/opt/steamcmd}"
  mkdir -p "$STEAM_COMPAT_DATA_PATH"

  NOISE="ALSA lib|ProtonFixes.*Skipping fix execution|not enough frames to estimate rate|Failed to open /etc/machine-id|Openbox-Message|setlocale.*failed|UpdateUI: skip show logo"
  "${PROTONPATH:?PROTONPATH not set}/proton" run "$VTS_EXE" -nosteam 2> >(grep -v -E "$NOISE" >&2) &
  PROTON_PID=$!
  PIDS="$PIDS $PROTON_PID"
  wait "$PROTON_PID"
else
  echo "[boot] install needs your Steam login first. Run this in another terminal:"
  echo "[boot]   docker exec -it vtube-studio install-vts.sh"
  echo "[boot] then restart this container: docker compose restart"
  exec tail -f /dev/null
fi
