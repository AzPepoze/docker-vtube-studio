#!/usr/bin/env bash
# Install / update VTube Studio (Steam AppID 1325860) into $VTS_DIR via steamcmd.
# Idempotent: skips when the game exe already exists and VTS_UPDATE_ON_START=0.
set -euo pipefail

VTS_DIR="${VTS_DIR:-/data/vts}"
APP_ID="${VTS_APP_ID:-1325860}"
EXE_CACHE="${EXE_CACHE:-$(dirname "$VTS_DIR")/.vts-exe}"

mkdir -p "$VTS_DIR" "$HOME"

# Session cache: after the first login, steamcmd remembers the session in
# /data/home, so credentials are never needed again — and never stored in a file.
has_session() {
  ls "$HOME"/.steam/steam/config/loginusers.vdf >/dev/null 2>&1
}

ask() {
  # $1 = var name, $2 = prompt, $3 = silent (1 = password)
  local var="$1" prompt="$2" silent="${3:-0}" val=""
  if [ -t 0 ]; then
    if [ "$silent" = "1" ]; then
      read -rsp "$prompt" val && echo >&2
    else
      read -rp "$prompt" val
    fi
    printf -v "$var" '%s' "$val"
  else
    echo "[install] ERROR: $var is not set and there is no terminal to ask." >&2
    echo "[install] Run once attached (docker compose up, without -d) or set $var in .env." >&2
    exit 1
  fi
}

find_exe() {
  find "$VTS_DIR" -maxdepth 4 -iname 'vtube studio.exe' -o -iname 'vtubestudio.exe' 2>/dev/null | head -n 1
}

if [ -n "$(find_exe)" ]; then
  if [ "${VTS_UPDATE_ON_START:-0}" = "0" ]; then
    # Steady state: VTS is installed, skip Steam entirely — no login needed.
    FOUND="$(find_exe)"
    echo "[install] VTS already present, skipping update: $FOUND"
    echo "$FOUND" > "$EXE_CACHE"
    exit 0
  fi
  echo "[install] VTS present, updating (VTS_UPDATE_ON_START=1)..."
fi

echo "[install] fetching VTube Studio via steamcmd (app $APP_ID)..."
if [ -z "${STEAM_USER:-}" ] && has_session; then
  # Reuse the account name Steam cached last time — no typing needed.
  STEAM_USER="$(grep -o '"AccountName"[[:space:]]*"[^"]*"' "$HOME"/.steam/steam/config/loginusers.vdf 2>/dev/null | head -n 1 | cut -d'"' -f4)"
fi
if [ -z "${STEAM_USER:-}" ]; then
  ask STEAM_USER "[install] Steam username: "
fi
LOGIN_ARGS=("+login" "${STEAM_USER:-anonymous}")
if [ -n "${STEAM_PASS:-}" ]; then
  LOGIN_ARGS+=("$STEAM_PASS")
elif ! has_session && [ "${STEAM_USER:-}" != "anonymous" ]; then
  ask STEAM_PASS "[install] Steam password (typed, never stored): " 1
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
