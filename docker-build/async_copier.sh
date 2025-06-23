#!/usr/bin/env bash
# filepath: async_copier.sh
set -Eeuo pipefail
shopt -s nullglob extglob

source /app/wifi_scripts/config.sh

TAG_SCRIPT="/app/tags_viofo.sh"

_log() {
  local level="${1:-INFO}"
  shift
  local msg="[$(date +'%F %T')] [$level] $*"
  echo "$msg"
  echo "$msg" >>"$LOG_FILE"
}

main() {
  mkdir -p "$TEMP_DIR" "$DEST_DIR" "$(dirname "$LOG_FILE")"
  touch "$INDEX_FILE"

  if ! mountpoint -q "$DEST_DIR"; then
    _log ERROR "SMB share ($DEST_DIR) is not mounted. Exiting."
    exit 1
  fi

  local found_files=false

  for src in "$TEMP_DIR"/!(*.txt|*.lock|*.filepart); do
    [[ -f "$src" ]] || continue
    found_files=true
    local fname="${src##*/}"
    local dst="$DEST_DIR/$fname"

    _log INFO "Processing $fname..."

    # Calculate checksum before tagging
    local checksum
    checksum=$(sha256sum "$src" | cut -d' ' -f1)
    _log INFO "SHA256 for $fname: $checksum"

    if "$TAG_SCRIPT" "$src" "$checksum"; then
      _log INFO "Metadata added to $fname"
    else
      _log ERROR "Failed to add metadata to $fname"
      continue
    fi

    if cp -a "$src" "$dst"; then
      _log INFO "Copied $fname to $DEST_DIR"
      (
        flock 200
        echo "$fname $checksum" >>"$INDEX_FILE"
      ) 200>"$INDEX_FILE.lock"
      rm -f "$src"
      _log INFO "Deleted $fname from $TEMP_DIR"
    else
      _log ERROR "Failed to copy $fname to $DEST_DIR"
      continue
    fi
  done

  if cp -a "$INDEX_FILE" "$DEST_DIR/"; then
    _log INFO "Copied $INDEX_FILE to $DEST_DIR"
  else
    _log ERROR "Failed to copy $INDEX_FILE to $DEST_DIR"
  fi

  if ! $found_files; then
    _log INFO "No valid files found in $TEMP_DIR"
  fi
}

main "$@"
