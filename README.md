# docker-vtuber-studio

VTube Studio (Steam) in Docker: API on `:8001`, watch page on `:8090`, remote control on `:6080`.

Maple talks to it to drive the avatar's expressions and hotkeys.

## You need

Docker + Compose, a Steam account owning VTube Studio (free), ~10 GB free once.

## Quick start

1. Start it:
   ```bash
   docker compose up -d --build
   ```

2. Log into Steam (typed, never saved — be quick with Guard codes):
   ```bash
   docker exec -it vtube-studio install-vts.sh
   ```

3. Reboot and watch (`:8090`). First boot takes minutes, later runs just work:
   ```bash
   docker compose restart
   ```

Prefer a file over typing? `cp .env.example .env`, `chmod 600 .env`, fill it in. Never commit `.env`.

## Clicking things

The watch page is view-only. Open the `VNC:` link from the logs
(`:6080/vnc.html`), click what you need, done.
`VNC_PASSWORD` locks it, `ENABLE_VNC=0` turns it off.

## Knobs (optional, `.env` or inline `KEY=value`)

- `STREAM_FPS=60` — stream frames per second. Lower = less CPU.
- `SCREEN_GEOM=640x360x24` — virtual screen. Smaller = much less CPU.
- `LP_NUM_THREADS=8` — software-rendering threads.
- `PUBLIC_HOST=localhost` — host shown in the log links. Set your LAN IP or domain if your browser is elsewhere.

## Updating VTube Studio later

```bash
docker exec -it vtube-studio env VTS_UPDATE_ON_START=1 install-vts.sh
docker compose restart
```

## If something looks wrong

- "install needs your Steam login" before step 2: normal, it's parked waiting.
- Guard codes expire in ~30 seconds. Be quick or retry.
- First boot takes minutes (Proton warmup). No GPU here, so expect ~13 fps and a few seconds of stream delay. No face tracking — Maple drives the face.
