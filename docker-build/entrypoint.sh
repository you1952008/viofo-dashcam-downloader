#!/usr/bin/env bash
set -e

# Load configuration and environment variables
source /app/wifi_scripts/config.sh

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

# Initial connection to CAR_SSID and attempt to mount SMB share
_log INFO "Connecting to CAR_SSID ($CAR_SSID)..."
bash /app/wifi_scripts/switch_wifi.sh "$CAR_SSID" "$CAR_PSK"

_log INFO "Checking SMB mount at $DEST_DIR..."
if ! mountpoint -q "$DEST_DIR"; then
  _log INFO "Attempting to mount $DEST_DIR..."
  mount "$DEST_DIR" && _log INFO "SMB share mounted." || _log ERROR "Failed to mount $DEST_DIR."
else
  _log INFO "SMB share already mounted."
fi

# Bootstrap the index file from existing files on the SMB share
_log INFO "Bootstrapping index from existing files..."
bash /app/bootstrap_index.sh
_log INFO "Bootstrap complete."

# Helper function to check if a given SSID is available in the Wi-Fi scan
ssid_available() {
  local ssid="$1"
  iwlist "$IFACE" scan 2>/dev/null | grep -q "ESSID:\"$ssid\""
}

# Main loop: handles Wi-Fi switching, downloading, and copying files
while true; do
  # Check if there is enough free disk space before proceeding
  used_pct=$(df --output=pcent "$DEST_DIR" | tail -1 | tr -dc '0-9')
  free_pct=$((100 - used_pct))

  if (( free_pct < THRESHOLD )); then
    _log ERROR "Low disk space (<${THRESHOLD}%). Attempting to offload files..."

    wifi_connected=""
    # Try to connect to CAR or BASE Wi-Fi for offloading
    if ssid_available "$CAR_SSID"; then
      _log INFO "CAR_SSID ($CAR_SSID) detected. Switching Wi-Fi..."
      bash /app/wifi_scripts/switch_wifi.sh "$CAR_SSID" "$CAR_PSK"
      wifi_connected="CAR"
    elif ssid_available "$BASE_SSID"; then
      _log INFO "BASE_SSID ($BASE_SSID) detected. Switching Wi-Fi..."
      bash /app/wifi_scripts/switch_wifi.sh "$BASE_SSID" "$BASE_PSK"
      wifi_connected="BASE"
    else
      _log ERROR "No CAR or BASE SSID found. Waiting..."
      sleep 60
      continue
    fi

    # Check if the SMB share is mounted; attempt to mount if not
    _log INFO "Checking SMB mount at $DEST_DIR..."
    smb_mounted=false
    if ! mountpoint -q "$DEST_DIR"; then
      _log INFO "Attempting to mount $DEST_DIR..."
      if mount "$DEST_DIR"; then
        _log INFO "SMB share mounted."
        smb_mounted=true
      else
        _log ERROR "Failed to mount $DEST_DIR."
      fi
    else
      _log INFO "SMB share already mounted."
      smb_mounted=true
    fi

    # Only run async_copier if connected to CAR or BASE and SMB is mounted
    if { [[ "$wifi_connected" == "CAR" ]] || [[ "$wifi_connected" == "BASE" ]]; } && $smb_mounted; then
      _log INFO "Launching async_copier..."
      bash /app/async_copier.sh
    fi

    sleep 60
    continue
  fi

  wifi_connected=""
  # Scan and connect in priority order: CAMERA, CAR, BASE
  if ssid_available "$CAMERA_SSID"; then
    _log INFO "CAMERA_SSID ($CAMERA_SSID) detected. Switching Wi-Fi..."
    bash /app/wifi_scripts/auto_wifi.sh "$CAMERA_SSID" "$CAMERA_PSK"
    _log INFO "Launching video downloader..."
    bash /app/video_downloader.sh
    _log INFO "Reconnecting to CAR_SSID ($CAR_SSID)..."
    bash /app/wifi_scripts/switch_wifi.sh "$CAR_SSID" "$CAR_PSK"
    wifi_connected="CAMERA"
  elif ssid_available "$CAR_SSID"; then
    _log INFO "CAR_SSID ($CAR_SSID) detected. Switching Wi-Fi..."
    bash /app/wifi_scripts/switch_wifi.sh "$CAR_SSID" "$CAR_PSK"
    wifi_connected="CAR"
  elif ssid_available "$BASE_SSID"; then
    _log INFO "BASE_SSID ($BASE_SSID) detected. Switching Wi-Fi..."
    bash /app/wifi_scripts/switch_wifi.sh "$BASE_SSID" "$BASE_PSK"
    wifi_connected="BASE"
  else
    _log INFO "No known SSID found. Waiting..."
    sleep 60
    continue
  fi

  # Check if the SMB share is mounted; attempt to mount if not
  _log INFO "Checking SMB mount at $DEST_DIR..."
  smb_mounted=false
  if ! mountpoint -q "$DEST_DIR"; then
    _log INFO "Attempting to mount $DEST_DIR..."
    if mount "$DEST_DIR"; then
      _log INFO "SMB share mounted."
      smb_mounted=true
    else
      _log ERROR "Failed to mount $DEST_DIR."
    fi
  else
    _log INFO "SMB share already mounted."
    smb_mounted=true
  fi

  # Only run async_copier if connected to CAR or BASE and SMB is mounted
  if { [[ "$wifi_connected" == "CAR" ]] || [[ "$wifi_connected" == "BASE" ]]; } && $smb_mounted; then
    _log INFO "Launching async_copier..."
    bash /app/async_copier.sh
  fi

done
