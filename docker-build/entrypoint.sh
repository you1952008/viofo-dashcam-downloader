VERSION="1.0.3"
#!/usr/bin/env bash
set -e
shopt -s nullglob extglob

# Load configuration and environment variables
source /app/wifi_scripts/config.sh

# Hardcoded paths
TEMP_DIR="/app/downloads"
DEST_DIR="/app/dashcam/videos"
LOG_FILE="/app/logs/viofo_copy.log"
INDEX_FILE="/app/downloads/processed_files.txt"
INDEX_LOCK="/app/downloads/processed_files.txt.lock"

# Logging function for consistent log output
_log() {
  local level="${1:-INFO}"
  shift
  local msg="[$(date +'%F %T')] [$level] $*"
  echo "$msg"
  echo "$msg" >>"$LOG_FILE"
}

# Ensure required directories and files exist before starting main logic
mkdir -p "$TEMP_DIR" "$DEST_DIR" "$WPA_BACKUP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$INDEX_FILE" "$INDEX_LOCK"
bash /app/init_index.sh

# Ensure WPA config file exists
if [ ! -f "$WPA_CONF" ]; then
  mkdir -p "$(dirname "$WPA_CONF")"
  touch "$WPA_CONF"
fi

# Function to ensure SMB mount point exists and is mounted
ensure_smb_mount() {
  mkdir -p /app/dashcam
  mkdir -p /app/dashcam/videos
  if ! mountpoint -q "$DEST_DIR"; then
    _log INFO "Attempting to mount $DEST_DIR..."
    if mount -t cifs "//$SMB_SERVER/$SMB_SHARE" "$DEST_DIR" \
      -o username="$SMB_USER",password="$SMB_PASS",vers=3.0,uid=1000,gid=1000; then
      _log INFO "SMB share mounted."
      return 0
    else
      _log ERROR "Failed to mount $DEST_DIR."
      return 1
    fi
  else
    _log INFO "SMB share already mounted."
    return 0
  fi
}

# Helper function to check if a given SSID is available in the Wi-Fi scan
ssid_available() {
  local ssid="$1"
  iwlist "$IFACE" scan 2>/dev/null | grep -q "ESSID:\"$ssid\""
}

current_ssid() {
  iwgetid -r 2>/dev/null
}

has_files_to_copy() {
  shopt -s nullglob
  local files=("$TEMP_DIR"/!(*.txt|*.lock|*.filepart))
  (( ${#files[@]} > 0 ))
}

# Initial connection to CAR_SSID or BASE_SSID and attempt to mount SMB share
if ssid_available "$CAR_SSID"; then
  _log INFO "Connecting to CAR_SSID ($CAR_SSID)..."
  bash /app/wifi_scripts/switch_wifi.sh "$CAR_SSID" "$CAR_PSK"
  _log INFO "Checking SMB mount at $DEST_DIR..."
  ensure_smb_mount
elif ssid_available "$BASE_SSID"; then
  _log INFO "Connecting to BASE_SSID ($BASE_SSID)..."
  bash /app/wifi_scripts/switch_wifi.sh "$BASE_SSID" "$BASE_PSK"
  _log INFO "Checking SMB mount at $DEST_DIR..."
  ensure_smb_mount
else
  _log INFO "No CAR or BASE SSID found at startup. Skipping initial SMB mount."
fi

# Bootstrap the index file from existing files on the SMB share
_log INFO "Bootstrapping index from existing files..."
bash /app/bootstrap_index.sh
_log INFO "Bootstrap complete."

IDLE_SLEEP="${IDLE_SLEEP:-300}"  # Default to 5 minutes, override with env if needed

# Main loop: handles Wi-Fi switching, downloading, and copying files
while true; do
  # Check if there is enough free disk space before proceeding
  used_pct=$(df --output=pcent "$DEST_DIR" | tail -1 | tr -dc '0-9')
  free_pct=$((100 - used_pct))

  if (( free_pct < THRESHOLD )); then
    _log ERROR "Low disk space (<${THRESHOLD}%). Attempting to offload files..."

    wifi_connected=""
    # Only scan for CAR or BASE if needed
    if ssid_available "$CAR_SSID"; then
      _log INFO "CAR_SSID ($CAR_SSID) detected. Switching Wi-Fi..."
      bash /app/wifi_scripts/switch_wifi.sh "$CAR_SSID" "$CAR_PSK"
      wifi_connected="CAR"
    elif ssid_available "$BASE_SSID"; then
      _log INFO "BASE_SSID ($BASE_SSID) detected. Switching Wi-Fi..."
      bash /app/wifi_scripts/switch_wifi.sh "$BASE_SSID" "$BASE_PSK"
      wifi_connected="BASE"
    else
      _log INFO "No CAR or BASE SSID found. Sleeping for $IDLE_SLEEP seconds..."
      sleep "$IDLE_SLEEP"
      continue
    fi

    # Ensure SMB share is mounted
    if ensure_smb_mount && { [[ "$wifi_connected" == "CAR" ]] || [[ "$wifi_connected" == "BASE" ]]; }; then
      _log INFO "Launching async_copier..."
      bash /app/async_copier.sh
    fi

    sleep "$IDLE_SLEEP"
    continue
  fi

  wifi_connected=""
  # Scan and connect in priority order: CAMERA, CAR, BASE
  if ssid_available "$CAMERA_SSID"; then
    if [[ "$(current_ssid)" != "$CAMERA_SSID" ]]; then
      _log INFO "CAMERA_SSID ($CAMERA_SSID) detected. Switching Wi-Fi..."
      bash /app/wifi_scripts/auto_wifi.sh "$CAMERA_SSID" "$CAMERA_PSK"
    else
      _log INFO "Already connected to CAMERA_SSID ($CAMERA_SSID)."
    fi
    _log INFO "Launching video downloader..."
    bash /app/video_downloader.sh
    wifi_connected="CAMERA"
  elif ssid_available "$CAR_SSID"; then
    if [[ "$(current_ssid)" != "$CAR_SSID" ]]; then
      _log INFO "CAR_SSID ($CAR_SSID) detected. Switching Wi-Fi..."
      bash /app/wifi_scripts/switch_wifi.sh "$CAR_SSID" "$CAR_PSK"
    else
      _log INFO "Already connected to CAR_SSID ($CAR_SSID)."
    fi
    wifi_connected="CAR"
  elif ssid_available "$BASE_SSID"; then
    if [[ "$(current_ssid)" != "$BASE_SSID" ]]; then
      _log INFO "BASE_SSID ($BASE_SSID) detected. Switching Wi-Fi..."
      bash /app/wifi_scripts/switch_wifi.sh "$BASE_SSID" "$BASE_PSK"
    else
      _log INFO "Already connected to BASE_SSID ($BASE_SSID)."
    fi
    wifi_connected="BASE"
  else
    # Fallback: check if already connected to CAR or BASE
    current=$(current_ssid)
    if [[ "$current" == "$CAR_SSID" ]]; then
      _log INFO "Already connected to CAR_SSID ($CAR_SSID)."
      wifi_connected="CAR"
    elif [[ "$current" == "$BASE_SSID" ]]; then
      _log INFO "Already connected to BASE_SSID ($BASE_SSID)."
      wifi_connected="BASE"
    else
      _log INFO "No known SSID found. Sleeping for $IDLE_SLEEP seconds..."
      sleep "$IDLE_SLEEP"
      continue
    fi
  fi

  # Only run async_copier if on CAR or BASE and SMB is mounted
  if ensure_smb_mount && { [[ "$wifi_connected" == "CAR" ]] || [[ "$wifi_connected" == "BASE" ]]; }; then
    if has_files_to_copy; then
      _log INFO "Files found in $TEMP_DIR. Launching async_copier..."
      bash /app/async_copier.sh
    else
      _log INFO "No files to process in $TEMP_DIR. Waiting for new files or Wi-Fi change."
    fi
  fi

  _log INFO "Sleeping for $IDLE_SLEEP seconds before next check."
  sleep "$IDLE_SLEEP"
done
