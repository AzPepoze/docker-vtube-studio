#!/usr/bin/env bash
# Install / update VTube Studio (Steam AppID 1325860) into $VTS_DIR via steamcmd.
# Idempotent: skips when the game exe already exists and VTS_UPDATE_ON_START=0.
set -euo pipefail

: "${STEAM_USER:?Set STEAM_USER in .env (first run only needs STEAM_PASS too)}"

VTS_DIR="${VTS_DIR:-/data/vts}"
APP_ID="${VTS_APP_ID:-1325860}"
EXE_CACHE="/data/.vts-exe"

mkdir -p "$VTS_DIR" "$HOME"

# Session cache: after the first login with a password, steamcmd remembers
# the session in /data/home, so STEAM_PASS can be deleted from .env.
has_session() {
  ls "$HOME"/.steam/steam/config/loginusers.vdf >/dev/null 2>&1
}

find_exe() {
  find "$VTS_DIR" -maxdepth 4 -iname 'vtube studio.exe' -o -iname 'vtubestudio.exe' 2>/dev/null | head -n 1
}

if [ "${VTS_UPDATE_ON_START:-1}" = "0" ]; then
  FOUND="$(find_exe)"
  if [ -n "$FOUND" ]; then
    echo "[install] VTS already present, skipping update: $FOUND"
    echo "$FOUND" > "$EXE_CACHE"
    exit 0
  fi
fi

echo "[install] fetching VTube Studio via steamcmd (app $APP_ID)..."
LOGIN_ARGS=("+login" "$STEAM_USER")
if [ -n "${STEAM_PASS:-}" ]; then
  LOGIN_ARGS+=("$STEAM_PASS")
elif ! has_session; then
  echo "[install] ERROR: no STEAM_PASS and no cached Steam session." >&2
  echo "[install] Put STEAM_PASS in .env for this run only — it can be deleted afterwards." >&2
  exit 1
fi
if [ -n "${STEAM_GUARD:-}" ]; then
  LOGIN_ARGS+=("$STEAM_GUARD")
fi

steamcmd \
  +@sSteamCmdForcePlatformType windows \
  +force_install_dir "$VTS_DIR" \
  "${LOGIN_ARGS[@]}" \
  +app_update "$APP_ID" validate \
  +quit

FOUND="$(find_exe)"
if [ -z "$FOUND" ]; then
  echo "[install] ERROR: VTube Studio exe not found under $VTS_DIR after install." >&2
  exit 1
fi

echo "[install] ready: $FOUND"
echo "$FOUND" > "$EXE_CACHE"
