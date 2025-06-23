# syntax=docker/dockerfile:1.4
# 1. Use armv6-compatible base image
FROM debian:bookworm-slim

LABEL maintainer="Ryan <i-used-that-thing@getincontact.net>"

ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    bash curl cifs-utils exiftool coreutils util-linux grep sed gawk procps parallel \
    wpasupplicant iw wireless-tools iproute2 isc-dhcp-client bzip2 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy scripts
COPY entrypoint.sh video_downloader.sh async_copier.sh tags_viofo.sh bootstrap_index.sh init_index.sh ./
COPY wifi_scripts/ ./wifi_scripts/

ENTRYPOINT ["bash", "./entrypoint.sh"]
