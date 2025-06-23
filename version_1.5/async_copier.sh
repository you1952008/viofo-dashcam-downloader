#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob extglob

: "${TEMP_DIR:=/app/downloads}"
: "${DEST_DIR:=/app/dashcam}"
: "${LOG_FILE:=/app/viofo_copy.log}"
: "${INDEX_FILE:=/app/processed_files.txt}"
: "${TAG_SCRIPT:=/app/tags_viofo.sh}"

mkdir -p "$TEMP_DIR" "$DEST_DIR" "$(dirname "$LOG_FILE")"
touch "$INDEX_FILE"

_log() {
  local msg="[$(date +'%F %T')] $*"
  echo "$msg"
  echo "$msg" >>"$LOG_FILE"
}

# Check if SMB share is mounted
if ! mountpoint -q "$DEST_DIR"; then
  _log "❌ SMB share ($DEST_DIR) is not mounted. Exiting."
  exit 1
fi

found_files=false

for SRC in "$TEMP_DIR"/!(*.txt|*.lock|*.filepart); do
  [[ -f "$SRC" ]] || continue
  found_files=true
  fname="${SRC##*/}"
  DST="$DEST_DIR/$fname"

  _log "🔍 Processing $fname..."

  # Calculate SHA256 before modifying the file
  checksum=$(sha256sum "$SRC" | cut -d' ' -f1)
  _log "🔑 SHA256 for $fname: $checksum"

  # Add metadata (including checksum) to the file
  if "$TAG_SCRIPT" "$SRC" "$checksum"; then
    _log "🏷️  Metadata added to $fname"
  else
    _log "❌ Failed to add metadata to $fname"
    continue
  fi

  # Copy file to destination
  if cp -a "$SRC" "$DST"; then
    _log "✅ Copied $fname to $DEST_DIR"
    echo "$fname $checksum" >>"$INDEX_FILE"
    rm -f "$SRC"
    _log "🗑️  Deleted $fname from $TEMP_DIR"
  else
    _log "❌ Failed to copy $fname to $DEST_DIR"
    continue
  fi
done

# After all files, copy the index file to DEST_DIR
if cp -a "$INDEX_FILE" "$DEST_DIR/"; then
  _log "📄 Copied $INDEX_FILE to $DEST_DIR"
else
  _log "❌ Failed to copy $INDEX_FILE to $DEST_DIR"
fi

if ! $found_files; then
  _log "💤 No valid files found in $TEMP_DIR"
fi

exit 0
