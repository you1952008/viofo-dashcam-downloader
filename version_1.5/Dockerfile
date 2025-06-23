# 1. Use armv6-compatible base image
FROM debian:bookworm-slim@sha256:7e1d1e7e6e1e6e2e6e1e6e1e6e1e6e1e6e1e6e1e6e6e1e6e1e6e1e6e1e6e1e

# Upgrade all packages to ensure vulnerabilities are patched
RUN apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

LABEL maintainer="Ryan <you@example.com>" \
      org.opencontainers.image.source="https://github.com/your/repo"

ARG DEBIAN_FRONTEND=noninteractive
ENV TEMP_DIR=/app/downloads \
    DEST_DIR=/app/dashcam \
    LOG_LEVEL=INFO

# 2. Install packages
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    bash \
    curl \
    exiftool \
    coreutils \
    util-linux \
    grep \
    sed \
    gawk \
    procps \
    parallel \
    wpasupplicant \
    iw \
    wireless-tools \
    iproute2 \
    isc-dhcp-client \
    bzip2 \
 && rm -rf /var/lib/apt/lists/*

# 3. Set working directory
WORKDIR /app

# 4. Copy scripts
COPY entrypoint.sh \
     video_downloader.sh \
     async_copier.sh \
     tags_viofo.sh \
     bootstrap_index.sh \
     ./
COPY wifi_scripts/ ./wifi_scripts/

RUN chmod +x \
      entrypoint.sh \
      video_downloader.sh \
      async_copier.sh \
      tags_viofo.sh \
      bootstrap_index.sh \
      wifi_scripts/*.sh

VOLUME ["/app/downloads", "/app/dashcam"]

ENTRYPOINT ["bash", "./entrypoint.sh"]

HEALTHCHECK --interval=1m --timeout=10s \
  CMD pgrep -f async_copier\.sh >/dev/null || exit 1
