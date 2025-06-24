#!/usr/bin/env bash
set -euo pipefail

IFACE="${IFACE:-wlan0}"
SSID="$1"
PSK="$2"

# Pre-flight: Check that NetworkManager is running and managing the interface
if ! nmcli -t -f RUNNING general | grep -q '^running$'; then
  echo "[ERROR] NetworkManager is not running or not accessible via D-Bus."
  exit 10
fi

if ! nmcli device status | grep -E "^$IFACE\s" | grep -q -E 'wifi.*(connected|disconnected)'; then
  echo "[ERROR] NetworkManager is not managing interface $IFACE. Check your NetworkManager configuration."
  exit 11
fi

echo "[DEBUG] nmcli switch_wifi.sh called with IFACE=$IFACE SSID=$SSID"

# Check if already connected
current_ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2 || true)
if [[ "$current_ssid" == "$SSID" ]]; then
  echo "[INFO] Already connected to $SSID"
  exit 0
fi

# Check if SSID is visible
if ! nmcli -t -f ssid dev wifi list ifname "$IFACE" | grep -Fxq "$SSID"; then
  echo "[WARN] SSID '$SSID' not found in scan results. Skipping switch."
  exit 2  # Soft error: SSID not found
fi

# Try to connect
nmcli dev wifi connect "$SSID" password "$PSK" ifname "$IFACE"

# Wait for connection (max 15s)
for i in {1..15}; do
    new_ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2 || true)
    echo "[DEBUG] nmcli current ssid: $new_ssid"
    if [[ "$new_ssid" == "$SSID" ]]; then
        echo "[INFO] Connected to $SSID"
        exit 0
    fi
    sleep 1
done

echo "[ERROR] Failed to connect to $SSID. Check credentials or signal."
exit 1
