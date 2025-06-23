#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/config.sh"

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <SSID> <PSK>" >&2
  exit 1
fi

ssid="$1"
psk="$2"

mkdir -p "$WPA_BACKUP_DIR"
timestamp=$(date +%Y%m%d_%H%M%S)
cp "$WPA_CONF" "$WPA_BACKUP_DIR/wpa_supplicant.$timestamp.conf"

cat > "$WPA_CONF" <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=$COUNTRY

network={
    ssid="$ssid"
    psk="$psk"
}
EOF

echo "🔁 Switching to SSID: $ssid"

if wpa_cli -i "$IFACE" reconfigure; then
  echo "✅ wpa_cli reconfigured successfully"
else
  echo "⚠️ wpa_cli failed, attempting DHCP fallback"

  if command -v dhclient &>/dev/null; then
    dhclient -r "$IFACE" || true
    dhclient "$IFACE" && echo "🔄 DHCP lease acquired via dhclient"
  elif pidof dhcpcd &>/dev/null; then
    pkill -HUP dhcpcd
    echo "🔄 dhcpcd signaled for renewal"
  else
    echo "❌ No DHCP client fallback available"
    exit 1
  fi
fi
