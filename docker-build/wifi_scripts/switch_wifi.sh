#!/usr/bin/env bash
set -euo pipefail

IFACE="${IFACE:-wlan0}"
SSID="$1"
PSK="$2"

echo "[DEBUG] nmcli switch_wifi.sh called with IFACE=$IFACE SSID=$SSID"

# Check if already connected
current_ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
if [[ "$current_ssid" == "$SSID" ]]; then
  echo "[INFO] Already connected to $SSID"
  exit 0
fi

# Try to connect
nmcli dev wifi connect "$SSID" password "$PSK" ifname "$IFACE"

# Wait for connection (max 15s)
for i in {1..15}; do
    new_ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
    echo "[DEBUG] nmcli current ssid: $new_ssid"
    if [[ "$new_ssid" == "$SSID" ]]; then
        echo "[INFO] Connected to $SSID"
        exit 0
    fi
    sleep 1
done

echo "[ERROR] Failed to connect to $SSID. Check credentials or signal."
exit 1
