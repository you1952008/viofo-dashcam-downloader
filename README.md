# Viofo Dashcam Downloader Pipeline

Automated pipeline for downloading, tagging, and archiving dashcam videos from a Viofo camera over Wi-Fi, with multi-network support and SMB/CIFS storage.

## Features

- Connects to CAMERA, CAR, or BASE Wi-Fi in priority order
- Downloads new videos when on CAMERA Wi-Fi
- Tags videos with metadata and SHA256 checksum
- Copies processed videos to an SMB share (when on CAR or BASE Wi-Fi)
- Maintains an index of processed files
- Runs in Docker, supports multi-arch (x86_64, arm64, armv6)

```text
viofo-dashcam-downloader/
│
├── docker/                  # All Docker-related files/scripts
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── video_downloader.sh
│   ├── async_copier.sh
│   ├── tags_viofo.sh
│   ├── bootstrap_index.sh
│   ├── init_index.sh
│   └── wifi_scripts/
│       ├── auto_wifi.sh
│       ├── check_space.sh
│       ├── config.sh
│       └── switch_wifi.sh
│
├── downloads/               # Local download cache (gitignored)
├── logs/                    # Log files (gitignored)
├── .env                     # User's environment config
├── .env.template            # Template for .env
├── .gitignore
├── compose.yml              # Docker Compose for local use
├── README.md
└── version_1.5/             # (Optional: legacy or alternate version)
```

## Quick Start

1. **Clone the repo if you want to build your own Docker image:**

   ```sh
   git clone https://github.com/yourusername/viofo-dashcam-downloader.git
   cd viofo-dashcam-downloader
   ```

2. **Copy the .env:**

   ```sh
   cp .env.template .env
   # Edit .env with your Wi-Fi and SMB credentials
   ```

3. **Pull the prebuilt image or run with Docker Compose:**

   ```sh
   docker pull ryanwayne/viofo-pipeline:0.2
   ```

   **or**
  
   ```sh
   docker compose up
   ```
