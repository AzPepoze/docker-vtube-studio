# docker-vtuber-studio

VTube Studio (Steam version) in Docker on a headless server, with a watch page you can paste into any browser to see the avatar. No VNC needed.

Maple (the AI VTuber project next door) talks to this container to drive the avatar's expressions and hotkeys.

## You need

- Docker + Docker Compose
- A Steam account that owns VTube Studio (it's free on Steam)
- About 10 GB free for the data volume on first run

## Quick start

1. Start it (no typing needed):

   ```bash
   docker compose up -d --build
   ```

2. Log into Steam once, inside the container:

   ```bash
   docker exec -it vtube-studio install-vts.sh
   ```

   It asks for your Steam username + password **in the terminal** — typed,
   never written to any file. If Steam wants a Guard code, it asks for that
   too. Steam then remembers the login inside the container's private volume.

3. Restart so it boots fully, then watch it:

   ```bash
   docker compose restart
   ```

   Open `http://your-server:8090` in any browser. That's the URL you share.
   (Host port `8090` — `8080` belongs to llamacpp on this box. Change it
   with `STREAM_PORT` if you like.)
   All later runs need no input — just `docker compose up -d`.

   (If you'd rather use a file: `cp .env.example .env`, `chmod 600 .env`,
   fill in the blanks, then `docker compose up --build` attached. Never commit `.env`.)

## Remote control (clicks)

The watch page is view-only. The same container also serves a remote
desktop in your browser — open the `VNC:` link from the logs
(`http://your-server:6080/vnc.html`), click what you need, done.
Set `VNC_PASSWORD` to lock it, `ENABLE_VNC=0` to turn it off.

## Knobs (all optional, via `.env` or inline `KEY=value`)

- `STREAM_FPS=60` — watch page frames per second. Lower = less CPU.
- `SCREEN_GEOM=640x360x24` — virtual screen size. Smaller = much less CPU.
- `LP_NUM_THREADS=8` — cap software-rendering threads.
- `PUBLIC_HOST=localhost` — host name used in the clickable log links.
  Set your LAN IP or domain if your browser is on another machine.

## Everyday use

```bash
docker compose up -d      # start
docker compose down       # stop
docker compose logs -f    # watch logs
```

Restarts reuse the installed game as-is (no Steam login, no waiting).
The Docker image itself rarely needs rebuilding.

To update VTube Studio itself later:

```bash
docker exec -it vtube-studio env VTS_UPDATE_ON_START=1 install-vts.sh
docker compose restart
```

## What's inside

- `Dockerfile` — small Debian + SteamCMD + Proton + virtual screen + video stream.
- `compose.yml` — ports (`8001` API, `8090` watch page, `6080` remote control) and the data volume.
- `scripts/` — start script, installer, and the VNC bridge.
- `stream/` — the watch page and its tiny web server.
- All heavy stuff (Steam login, game files, models, Proton) lives in a Docker
  volume, not in the image — so the image stays small and pulls stay fast.

## Troubleshooting

- **Container logs say "install needs your Steam login", health shows unhealthy?**
  Normal before the first login — the container is parked, waiting. Do Quick
  start step 2 (`docker exec -it ...`), then `docker compose restart`.
- **Steam Guard code asked, then fails?** Codes expire in ~30 seconds. Run step 2
  again and be quick — or put a fresh code in `STEAM_GUARD` in `.env` and restart.
- **First start is slow?** Normal. Proton warms up for a few minutes, then it's fine.
- **Watch page says "open stream.m3u8 in VLC"?** Your browser needs internet for the player library, or just open `http://your-server:8090/stream.m3u8` directly in VLC.
- **Forgot what's running?** `docker compose ps` and `docker compose logs -f`.

## Known limits

- API + viewing only: no face tracking, no video output to OBS.
- No GPU: software rendering. Fine once the model is loaded, since the stream is just for watching.
- The stream has a few seconds of delay. Normal for this kind of video.
