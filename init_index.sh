#!/usr/bin/env bash
set -euo pipefail

: "${INDEX_FILE:?INDEX_FILE env var required}"
: "${INDEX_LOCK:?INDEX_LOCK env var required}"

INDEX_DIR=$(dirname "$INDEX_FILE")
mkdir -p "$INDEX_DIR"

touch "$INDEX_FILE" "$INDEX_LOCK"
chmod 664 "$INDEX_FILE" "$INDEX_LOCK"
echo "📁 Index initialized at $INDEX_FILE"
