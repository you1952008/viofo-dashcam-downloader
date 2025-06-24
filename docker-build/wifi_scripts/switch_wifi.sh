#!/usr/bin/env bash
set -euo pipefail

IFACE="${IFACE:-wlan0}"
SSID="$1"
PSK="$2"

echo "[DEBUG] switch_wifi.sh called with IFACE=$IFACE SSID=$SSID"

# Update wpa_supplicant.conf (your logic here)

# Reconfigure wpa_supplicant
echo "[DEBUG] Running: wpa_cli -i $IFACE reconfigure"
if ! timeout 10 wpa_cli -i "$IFACE" reconfigure; then
  echo "[ERROR] wpa_cli reconfigure failed or timed out"
  exit 1
fi

# Optionally, check connection status
sleep 2
status=$(wpa_cli -i "$IFACE" status)
echo "[DEBUG] wpa_cli status output:"
echo "$status"
