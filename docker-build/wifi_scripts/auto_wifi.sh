#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/config.sh"

if "$SCRIPT_DIR/check_space.sh"; then
  ssid="$HOME_SSID"
  psk="$HOME_PSK"
else
  ssid="$CAR_SSID"
  psk="$CAR_PSK"
fi

current_ssid=$(iwgetid -r || echo "")
if [[ "$current_ssid" == "$ssid" ]]; then
  echo "✔️ Already connected to $ssid"
  exit 0
fi

"$SCRIPT_DIR/switch_wifi.sh" "$ssid" "$psk"
