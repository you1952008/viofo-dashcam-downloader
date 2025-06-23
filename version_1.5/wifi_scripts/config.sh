#!/usr/bin/env bash
# Configuration for Wi-Fi switching and threshold logic

# Configurable values (sourced from environment or .env)
THRESHOLD="${THRESHOLD:-10}"

HOME_SSID="${HOME_SSID:?Missing HOME_SSID}"
HOME_PSK="${HOME_PSK:?Missing HOME_PSK}"

CAR_SSID="${CAR_SSID:?Missing CAR_SSID}"
CAR_PSK="${CAR_PSK:?Missing CAR_PSK}"

# Hardcoded system-level constants
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"
WPA_BACKUP_DIR="/etc/wpa_supplicant/backups"
COUNTRY="US"
IFACE="wlan0"
