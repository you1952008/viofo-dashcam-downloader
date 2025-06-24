#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/config.sh"

echo "[DEBUG] Called as: $0 $*"
echo "[DEBUG] target argument: ${1:-<none>}"

# Usage: auto_wifi.sh [car|base|camera]
target="${1:-base}"

case "$target" in
  car)
    ssid="$CAR_SSID"
    psk="$CAR_PSK"
    ;;
  base)
    ssid="$BASE_SSID"
    psk="$BASE_PSK"
    ;;
  camera)
    ssid="$CAMERA_SSID"
    psk="$CAMERA_PSK"
    ;;
  *)
    echo "[ERROR] Usage: $0 [car|base|camera]"
    exit 1
    ;;
esac

echo "[DEBUG] Switching to SSID: $ssid"

current_ssid=$(iwgetid -r || echo "")
echo "[DEBUG] Currently connected SSID: $current_ssid"
if [[ "$current_ssid" == "$ssid" ]]; then
  echo "✔️ Already connected to $ssid"
  exit 0
fi

"$SCRIPT_DIR/switch_wifi.sh" "$ssid" "$psk"
sleep 2  # Give Wi-Fi a moment to associate
