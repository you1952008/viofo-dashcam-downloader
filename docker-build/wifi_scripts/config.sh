#!/usr/bin/env bash
# Configuration for Wi-Fi switching and threshold logic

# Configurable values (sourced from environment or .env)
THRESHOLD="${THRESHOLD:-10}"

CAMERA_SSID="${CAMERA_SSID:?Missing CAMERA_SSID}"
CAMERA_PSK="${CAMERA_PSK:?Missing CAMERA_PSK}"
CAR_SSID="${CAR_SSID:?Missing CAR_SSID}"
CAR_PSK="${CAR_PSK:?Missing CAR_PSK}"
BASE_SSID="${BASE_SSID:?Missing BASE_SSID}"
BASE_PSK="${BASE_PSK:?Missing BASE_PSK}"

# Hardcoded system-level constants
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"
WPA_BACKUP_DIR="/etc/wpa_supplicant/backups"
COUNTRY="US"
IFACE="wlan0"
