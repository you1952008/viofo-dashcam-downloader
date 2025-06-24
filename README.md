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
   git clone https://github.com/you1952008/viofo-dashcam-downloader.git
   cd viofo-dashcam-downloader
   ```

2. ***Use Prebuilt Image***

    ```sh
    git clone --filter=blob:none --no-checkout https://github.com/you1952008/viofo-dashcam-downloader.git
    cd viofo-dashcam-downloader
    git sparse-checkout init --cone
    git sparse-checkout set .env.template compose.yml README.md
    git checkout
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

> **Tip:**  
> If you only want to use the prebuilt image and don't need the Docker build scripts, you can just download `.env.template` and `compose.yml` from the repo, or clone the repo and remove the `docker/` folder.

## Running with Container-Managed Wi-Fi

To allow the container to control Wi-Fi, you must disable any `wpa_supplicant` or network manager on the host that manages your Wi-Fi interface.

### 1. Disable wpa_supplicant on the Host

```sh
sudo systemctl stop wpa_supplicant
sudo systemctl disable wpa_supplicant
sudo pkill wpa_supplicant
```

If you use NetworkManager, mark your Wi-Fi interface as unmanaged by adding to `/etc/NetworkManager/NetworkManager.conf`:

```text
[keyfile]
unmanaged-devices=interface-name:wlan0
```

Then reload NetworkManager:

```sh
sudo systemctl reload NetworkManager
```

### 2. Run the Container

Make sure your container is started with:

- `--net=host`
- `--privileged`

The container will now manage Wi-Fi connections using its own `wpa_supplicant` and scripts.

## License

This project is licensed under the MIT License.
