#!/usr/bin/env bash
set -xuo pipefail
shopt -s nullglob

# ─── 0. Load & validate ENV ───────────────────────────────────────────────────
: "${THRESHOLD:?Need THRESHOLD in env}"
: "${TEMP_DIR:?Need TEMP_DIR in env}"
: "${DEST_DIR:?Need DEST_DIR in env}"
: "${HOME_SSID:?Need HOME_SSID in env}"
: "${HOME_PSK:?Need HOME_PSK in env}"
: "${CAR_SSID:?Need CAR_SSID in env}"
: "${CAR_PSK:?Need CAR_PSK in env}"
: "${WPA_CONF:?Need WPA_CONF in env}"
: "${WPA_BACKUP_DIR:?Need WPA_BACKUP_DIR in env}"
: "${COUNTRY:?Need COUNTRY in env}"
: "${IFACE:?Need IFACE in env}"
: "${INDEX_FILE:?Need INDEX_FILE in env}"
: "${INDEX_LOCK:?Need INDEX_LOCK in env}"

# ─── 1. Pre-flight deps ───────────────────────────────────────────────────────
MISSING=()
for cmd in bash curl exiftool sha256sum mktemp flock grep sed gawk wpa_cli iwgetid df mountpoint mount; do
  command -v "$cmd" >/dev/null || MISSING+=("$cmd")
done
[[ ${#MISSING[@]} -eq 0 ]] || {
  echo "❌ Missing required commands: ${MISSING[*]}"
  exit 1
}

# ─── 2. Ensure required paths ─────────────────────────────────────────────────
mkdir -p "$TEMP_DIR" "$DEST_DIR" "$WPA_BACKUP_DIR"
touch "$INDEX_FILE" "$INDEX_LOCK"
echo "📄 [INIT] Ensuring index file exists..."
bash /app/init_index.sh

# ─── 3. Connect to CAR_SSID and mount SMB share ───────────────────────────────
echo "📶 [NET] Connecting to CAR_SSID ($CAR_SSID)..."
bash /app/wifi_scripts/switch_wifi.sh "$CAR_SSID" "$CAR_PSK"

echo "📂 [MOUNT] Checking SMB mount at $DEST_DIR..."
if ! mountpoint -q "$DEST_DIR"; then
  echo "🔄 Attempting to mount $DEST_DIR..."
  if mount "$DEST_DIR"; then
    echo "✅ SMB share mounted successfully."
  else
    echo "❌ Failed to mount $DEST_DIR. async_copier may fail."
  fi
else
  echo "✅ SMB share already mounted."
fi

# ─── 4. Bootstrap index ───────────────────────────────────────────────────────
echo "🧮 [INDEX] Bootstrapping index from existing files..."
bash /app/bootstrap_index.sh
echo "✅ [INDEX] Bootstrap complete."

# ─── 5. Main loop ─────────────────────────────────────────────────────────────
while true; do
  # Check disk space
  used_pct=$(df --output=pcent "$DEST_DIR" | tail -1 | tr -dc '0-9')
  free_pct=$((100 - used_pct))
  if (( free_pct < THRESHOLD )); then
    echo "❌ Low disk space (<${THRESHOLD}%). Waiting..."
    sleep 60
    continue
  fi

  # Scan for HOME_SSID
  echo "🔍 [NET] Scanning for HOME_SSID ($HOME_SSID)..."
  if iwlist "$IFACE" scan 2>/dev/null | grep -q "ESSID:\"$HOME_SSID\""; then
    echo "✅ [NET] HOME_SSID detected. Switching Wi-Fi..."
    bash /app/wifi_scripts/auto_wifi.sh "$HOME_SSID" "$HOME_PSK"

    echo "⬇️  [DL] Launching video downloader..."
    if bash /app/video_downloader.sh; then
      echo "✅ [DL] Download pass complete."
    else
      echo "❌ [DL] Downloader exited with error."
    fi

    echo "📶 [NET] Reconnecting to CAR_SSID ($CAR_SSID)..."
    bash /app/wifi_scripts/switch_wifi.sh "$CAR_SSID" "$CAR_PSK"

    echo "📂 [MOUNT] Checking SMB mount at $DEST_DIR..."
    if ! mountpoint -q "$DEST_DIR"; then
      echo "🔄 Attempting to mount $DEST_DIR..."
      if mount "$DEST_DIR"; then
        echo "✅ SMB share mounted successfully."
      else
        echo "❌ Failed to mount $DEST_DIR. async_copier may fail."
      fi
    else
      echo "✅ SMB share already mounted."
    fi

    echo "🚚 [COPY] Launching async_copier..."
    if bash /app/async_copier.sh; then
      echo "✅ [COPY] async_copier pass complete."
    else
      echo "❌ [COPY] async_copier exited with error."
    fi

    # After async_copier, immediately check for HOME_SSID again (loop restarts)
  else
    echo "❌ [NET] HOME_SSID not found. Staying on CAR_SSID."
    sleep 60
  fi
done
