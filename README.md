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

## Host Setup Requirements

To use this project with robust Wi-Fi switching from inside the container, your host system must meet the following requirements:

### 1. NetworkManager Must Be Installed and Managing Wi-Fi

- **Install NetworkManager** (if not already installed):
  ```sh
  sudo apt-get update
  sudo apt-get install network-manager
  ```

- **Ensure NetworkManager is running:**
  ```sh
  sudo systemctl enable --now NetworkManager
  ```

- **Make sure your Wi-Fi interface (e.g., `wlan0`) is managed by NetworkManager:**
  - Check status:
    ```sh
    nmcli device status
    ```
    `wlan0` should show as `wifi` and `connected` or `disconnected` (not `unmanaged`).
  - If it shows as `unmanaged`, edit `/etc/NetworkManager/NetworkManager.conf` and set:
    ```
    [ifupdown]
    managed=true
    ```
    Then restart NetworkManager:
    ```sh
    sudo systemctl restart NetworkManager
    ```

- **Disable any other Wi-Fi managers** (like standalone `wpa_supplicant` or `dhcpcd`) for `wlan0`.

### 2. D-Bus Socket Must Be Accessible to the Container

- Your `docker-compose.yml` or `compose.yml` must include:
  ```yaml
  volumes:
    - /var/run/dbus:/var/run/dbus
  environment:
    - DBUS_SYSTEM_BUS_ADDRESS=unix:path=/var/run/dbus/system_bus_socket
  ```

### 3. (Optional) Add User to netdev Group

- If you run the container as a non-root user, ensure that user is in the `netdev` group on the host:
  ```sh
  sudo usermod -aG netdev $USER
  ```

### 4. Example: Checking Everything

```sh
nmcli device status
# Should show wlan0 as managed

sudo systemctl status NetworkManager
# Should show active (running)
```

---

**Once these requirements are met, the container will be able to control Wi-Fi using `nmcli` and switch networks as needed.**

## License

This project is licensed under the MIT License.
