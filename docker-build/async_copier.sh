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
  _log INFO "=== async_copier started ==="
  mkdir -p "$TEMP_DIR" "$DEST_DIR" "$(dirname "$LOG_FILE")"
  touch "$INDEX_FILE"

  _log INFO "DEST_DIR is set to: $DEST_DIR"
  ls -ld "$DEST_DIR"
  mount | grep "$DEST_DIR"

  found_files=false
  _log INFO "Scanning $TEMP_DIR for files to copy..."

  FILES=("$TEMP_DIR"/*)
  if [ ${#FILES[@]} -eq 0 ]; then
    _log INFO "No files to process in $TEMP_DIR. Exiting async_copier."
    exit 0
  fi

  for src in "$TEMP_DIR"/!(*.txt|*.lock|*.filepart); do
    [[ -f "$src" ]] || continue
    found_files=true
    fname="${src##*/}"
    dst="$DEST_DIR/$fname"

    _log INFO "Processing $fname..."

    # Calculate checksum before tagging
    checksum=$(sha256sum "$src" | cut -d' ' -f1)
    _log INFO "SHA256 for $fname: $checksum"

    _log INFO "Tagging $fname with metadata..."
    if "$TAG_SCRIPT" "$src"; then
      _log INFO "Metadata added to $fname"
    else
      _log ERROR "Failed to add metadata to $fname"
      continue
    fi

    _log INFO "Copying $fname to $DEST_DIR..."
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

  _log INFO "Copying $INDEX_FILE to $DEST_DIR..."
  if cp -a "$INDEX_FILE" "$DEST_DIR/"; then
    _log INFO "Copied $INDEX_FILE to $DEST_DIR"
  else
    _log ERROR "Failed to copy $INDEX_FILE to $DEST_DIR"
  fi

  if [ "$found_files" = false ]; then
    _log INFO "No valid files found in $TEMP_DIR"
  fi

  _log INFO "=== async_copier finished ==="
}

main "$@"
