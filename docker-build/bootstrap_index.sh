#!/usr/bin/env bash
set -euo pipefail

TYPE="${1:-videos}"

: "${DEST_DIR:=/app/dashcam}"
: "${TEMP_DIR:=/app/downloads}"

# Append subdirectory based on type
TEMP_DIR="${TEMP_DIR%/}/$TYPE"
DEST_DIR="${DEST_DIR%/}/$TYPE"
INDEX_FILE="$TEMP_DIR/processed_files.txt"
INDEX_LOCK="$TEMP_DIR/processed_files.txt.lock"

mkdir -p "$TEMP_DIR"
mkdir -p "$DEST_DIR"   
touch "$INDEX_FILE" "$INDEX_LOCK"

(
  flock 200

  INDEX_SRC="$DEST_DIR/processed_files.txt"

  if [[ -f "$INDEX_SRC" ]]; then
    echo "📄 [BOOTSTRAP] Reusing existing index from $INDEX_SRC"
    cp "$INDEX_SRC" "$INDEX_FILE"
    echo "📁 [BOOTSTRAP] Copied to $INDEX_FILE"
    exit 0
  fi

  echo "📥 [BOOTSTRAP] No index found — generating fresh copy..."
  TMP_OUT=$(mktemp)
  trap 'rm -f "$TMP_OUT"' EXIT

  # Set file extensions based on type
  if [[ "$TYPE" == "photos" ]]; then
    find "$DEST_DIR" -type f -iname '*.jpg' | while read -r f; do
      fname=$(basename "$f")
      comment=$(exiftool -s3 -Comment "$f" 2>/dev/null | tr -d '\r\n')
      checksum=$(printf "%s" "$comment" | grep -a -oE '[A-Fa-f0-9]{64}' | head -n1 || :)
      if [[ -z "$checksum" ]]; then
        checksum=$(sha256sum "$f" | cut -d' ' -f1)
      fi
      printf "%s %s\n" "$fname" "$checksum"
    done > "$TMP_OUT"
  else
    find "$DEST_DIR" -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.ts' \) | while read -r f; do
      fname=$(basename "$f")
      comment=$(exiftool -s3 -Comment "$f" 2>/dev/null | tr -d '\r\n')
      checksum=$(printf "%s" "$comment" | grep -a -oE '[A-Fa-f0-9]{64}' | head -n1 || :)
      if [[ -z "$checksum" ]]; then
        checksum=$(sha256sum "$f" | cut -d' ' -f1)
      fi
      printf "%s %s\n" "$fname" "$checksum"
    done > "$TMP_OUT"
  fi

  sort -u "$TMP_OUT" > "$INDEX_FILE"
  echo "✅ [BOOTSTRAP] Indexed $(wc -l < "$INDEX_FILE") files."

  cp "$INDEX_FILE" "$DEST_DIR/processed_files.txt"
  echo "📁 [BOOTSTRAP] Copied index to $DEST_DIR/processed_files.txt"

) 200>"$INDEX_LOCK"
