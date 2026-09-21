# docker-vtuber-studio

VTube Studio (Steam version) in Docker on a headless server, with a watch page you can paste into any browser to see the avatar. No VNC needed.

Maple (the AI VTuber project next door) talks to this container to drive the avatar's expressions and hotkeys.

## You need

- Docker + Docker Compose
- A Steam account that owns VTube Studio (it's free on Steam)
- About 10 GB free for the data volume on first run

## Quick start

1. Start it attached (so it can ask you things on the first run):

   ```bash
   docker compose up --build
   ```

   On the first run it asks for your Steam username + password **in the
   terminal** — typed, never written to any file. If Steam wants a Guard
   code, it asks for that too. Steam then remembers the login inside the
   container's private volume, so all later runs need no input — just
   `docker compose up -d`.

   (If you'd rather use a file: `cp .env.example .env`, `chmod 600 .env`,
   fill in the blanks. Never commit `.env`.)

2. Watch it: open `http://your-server:8080` in any browser. That's the URL you share.

## One-time setup (first run only)

Steam login and one click need a browser inside the container. Run this once:

```bash
docker compose -f compose.yml -f compose.setup.yml --profile setup up setup
```

Open `http://your-server:6080` and: log into Steam (put a Guard code in `.env`
as `STEAM_GUARD` if asked, then restart), start VTube Studio, load your model,
turn tracking OFF. When Maple first connects and VTube Studio asks to allow
"MapleAI", click Allow. Then stop the setup container with Ctrl-C — you never
run it again. The watch page on `:8080` is how you look at it from now on.

## Everyday use

```bash
docker compose up -d      # start
docker compose down       # stop
docker compose logs -f    # watch logs
```

VTube Studio updates itself on each start. The Docker image itself rarely needs rebuilding.

## What's inside

- `Dockerfile` — small Debian + SteamCMD + Proton + virtual screen + video stream.
- `compose.yml` — ports (`8001` API, `8080` watch page) and the data volume.
- `compose.setup.yml` — the one-time setup browser. Not used day to day.
- `scripts/` — start script and installer.
- `stream/` — the watch page and its tiny web server.
- All heavy stuff (Steam login, game files, models, Proton) lives in a Docker
  volume, not in the image — so the image stays small and pulls stay fast.

## Troubleshooting

- **Steam Guard code asked, then fails?** Put the code in `STEAM_GUARD` in `.env` and run `docker compose up -d` again. Codes expire fast, be quick.
- **First start is slow?** Normal. Proton warms up for a few minutes, then it's fine.
- **Watch page says "open stream.m3u8 in VLC"?** Your browser needs internet for the player library, or just open `http://your-server:8080/stream.m3u8` directly in VLC.
- **Forgot what's running?** `docker compose ps` and `docker compose logs -f`.

## Known limits

- API + viewing only: no face tracking, no video output to OBS.
- No GPU: software rendering. Fine once the model is loaded, since the stream is just for watching.
- The stream has a few seconds of delay. Normal for this kind of video.
