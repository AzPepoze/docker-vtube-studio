
ARG DEBIAN_CODENAME=trixie
ARG GE_PROTON_VERSION=GE-Proton11-7

FROM debian:${DEBIAN_CODENAME}-slim AS novnc
ARG NOVNC_VERSION=1.6.0
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL "https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.tar.gz" \
  | tar -xz -C /opt \
 && mv "/opt/noVNC-${NOVNC_VERSION}" /opt/novnc

FROM debian:${DEBIAN_CODENAME}-slim AS vts
ARG STEAMCMD_URL=https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
ARG GE_PROTON_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    HOME=/data/home \
    DISPLAY=:99 \
    PROTONPATH=/opt/protons/${GE_PROTON_VERSION} \
    WINEPREFIX=/data/prefix \
    VTS_DIR=/data/vts \
    ENABLE_STREAM=1 \
    STREAM_PORT=8080 \
    STREAM_DIR=/srv/stream \
    ENABLE_VNC=1

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates curl procps \
    lib32gcc-s1 lib32stdc++6 \
    xvfb openbox \
    python3 \
    ffmpeg \
    x11vnc websockify \
    mesa-vulkan-drivers libgl1 libegl1 \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /opt/steamcmd \
 && curl -fsSL "${STEAMCMD_URL}" | tar -xz -C /opt/steamcmd \
 && printf '#!/bin/sh\nexec /opt/steamcmd/steamcmd.sh "$@"\n' > /usr/local/bin/steamcmd \
 && chmod +x /usr/local/bin/steamcmd \
 && mkdir -p /opt/protons \
 && curl -fsSL "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${GE_PROTON_VERSION}/${GE_PROTON_VERSION}-x86_64.tar.gz" \
  | tar -xz -C /opt/protons \
 && mv "/opt/protons/${GE_PROTON_VERSION}-x86_64" "/opt/protons/${GE_PROTON_VERSION}" \
 && test -x "/opt/protons/${GE_PROTON_VERSION}/proton" \
 && mkdir -p /data "$HOME" /srv/stream /tmp/.X11-unix

COPY --from=novnc /opt/novnc /opt/novnc
COPY scripts/entrypoint.sh scripts/install-vts.sh /usr/local/bin/
COPY stream/serve.py /usr/local/bin/serve.py
COPY stream/www/ /srv/stream/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/install-vts.sh /usr/local/bin/serve.py

EXPOSE 8001 8080 6080 5900
VOLUME /data

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=120s \
  CMD timeout 5 bash -c 'cat < /dev/null > /dev/tcp/127.0.0.1/8001' || exit 1

ENTRYPOINT ["entrypoint.sh"]
