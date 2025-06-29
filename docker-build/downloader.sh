#!/usr/bin/env bash
set -xeuo pipefail
shopt -s nullglob extglob
PS4='+ [${BASH_SOURCE}:${LINENO}] '

: "${THRESHOLD:?Need THRESHOLD in env}"
: "${BASE_URL:?BASE_URL must be set by entrypoint}"
: "${TEMP_DIR:?TEMP_DIR must be set by entrypoint}"
: "${DEST_DIR:?DEST_DIR must be set by entrypoint}"
: "${TAG_SCRIPT:?TAG_SCRIPT must be set by entrypoint}"

TYPE="${1:-videos}"

# Append subdirectory based on type
TEMP_DIR="${TEMP_DIR%/}/$TYPE"
DEST_DIR="${DEST_DIR%/}/$TYPE"
INDEX_FILE="${TEMP_DIR}/processed_files.txt"

check_space() {
  local used_pct free_pct
  used_pct=$(df --output=pcent / | tail -1 | tr -dc '0-9')
  free_pct=$((100 - used_pct))
  (( free_pct >= THRESHOLD ))
}

echo "$(date) │ Preparing $TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Ensure processed_files.txt exists and is a file
touch "$INDEX_FILE"
[[ -f "$INDEX_FILE" ]] || { echo "❌ '$INDEX_FILE' is not a file."; exit 1; }

if ! check_space; then
  echo "❌ Low disk space (<${THRESHOLD}%). Exiting to trigger Wi-Fi switch."
  exit 2
fi

TMP_LIST=$(mktemp)
trap 'rm -f "$TMP_LIST"' EXIT

# Set file extension pattern based on type
declare -A EXT_PATTERNS=( [videos]='MP4|MOV|TS' [photos]='JPG' )
ext_pattern="${EXT_PATTERNS[$TYPE]:-MP4|MOV|TS}"

# Use BASE_URL from entrypoint, but allow override for photos if needed
if [[ "$TYPE" == "photos" ]]; then
  BASE_URL="${BASE_URL%/}/../Photo"
fi

echo "$(date) │ Curling file list from $BASE_URL"
{
  curl --fail --connect-timeout 5 --max-time 15 -s "${BASE_URL%/}/" \
    | grep -oiE "href=\"[^\"]+\.($ext_pattern)\"" \
    | sed -E 's/^href=\"(.+)\"/\1/' \
    | sed 's|^.*/||' \
    | sort -ru \
    > "$TMP_LIST"
} || true

echo "$(date) │ Found $(wc -l <"$TMP_LIST") files."

# Clean exit if no files to download
if [[ ! -s "$TMP_LIST" ]]; then
  echo "$(date) │ ✔️ No files to download. Exiting cleanly."
  exit 0
fi

consecutive_skipped=0
max_consecutive_skipped=3

while IFS= read -r FILE; do
  echo "$(date) │ → Next: $FILE"

  if ! check_space; then
    echo "❌ Low disk space before downloading $FILE. Exiting."
    exit 2
  fi

  REMOTE_URL="${BASE_URL%/}/$FILE"
  LOCAL_PATH="${TEMP_DIR%/}/$FILE"
  REFERENCE_FILE="${DEST_DIR%/}/$FILE"

  if grep -Fq "$FILE" "$INDEX_FILE" 2>/dev/null; then
    echo "$(date) │ ✅ Already processed. Skipping."
    consecutive_skipped=$((consecutive_skipped + 1))
    if (( consecutive_skipped >= max_consecutive_skipped )); then
      echo "$(date) │ 🚪 $max_consecutive_skipped consecutive files already processed. Exiting downloader."
      exit 0
    fi
    continue
  fi

  checksum=""
  if [[ -f "$REFERENCE_FILE" ]]; then
    comment=$(exiftool -s3 -Comment "$REFERENCE_FILE" 2>/dev/null | tr -d '\r\n')
    checksum=$(printf "%s" "$comment" | grep -a -oE '[A-Fa-f0-9]{64}' | head -n1 || :)
    if [[ -n "$checksum" ]]; then
      echo "$(date) │ ✅ Existing file has checksum. Skipping."
      printf "%s %s\n" "$FILE" "$checksum" >> "$INDEX_FILE"
      consecutive_skipped=$((consecutive_skipped + 1))
      if (( consecutive_skipped >= max_consecutive_skipped )); then
        echo "$(date) │ 🚪 $max_consecutive_skipped consecutive files already processed. Exiting downloader."
        exit 0
      fi
      continue
    fi
    echo "$(date) │ ⚠️ Exists but no checksum. Redownloading."
  fi

  echo "$(date) │ ℹ️ New file. Downloading."
  if curl --fail --connect-timeout 15 --max-time 300 -# -o "$LOCAL_PATH" "$REMOTE_URL"; then
    echo "$(date) │ 🏷️ Tagging $LOCAL_PATH"
    if bash "$TAG_SCRIPT" "$LOCAL_PATH"; then
      echo "$(date) │ ✅ Tagged."
      # Extract checksum from tag or compute it ONCE
      comment=$(exiftool -s3 -Comment "$LOCAL_PATH" 2>/dev/null | tr -d '\r\n')
      checksum=$(printf "%s" "$comment" | grep -a -oE '[A-Fa-f0-9]{64}' | head -n1 || :)
      if [[ -z "$checksum" ]]; then
        checksum=$(sha256sum "$LOCAL_PATH" | cut -d' ' -f1)
        # Optionally, you could re-tag here with the checksum if needed
      fi
      printf "%s %s\n" "$FILE" "$checksum" >> "$INDEX_FILE"
      consecutive_skipped=0
    else
      echo "$(date) │ ❌ Tagging failed. Not marking as processed."
      rm -f "$LOCAL_PATH"
      consecutive_skipped=$((consecutive_skipped + 1))
      if (( consecutive_skipped >= max_consecutive_skipped )); then
        echo "$(date) │ 🚪 $max_consecutive_skipped consecutive failures. Exiting downloader."
        exit 2
      fi
    fi
  else
    echo "$(date) │ ❌ Download failed. Cleaning up."
    rm -f "$LOCAL_PATH"
    consecutive_skipped=$((consecutive_skipped + 1))
    if (( consecutive_skipped >= max_consecutive_skipped )); then
      echo "$(date) │ 🚪 $max_consecutive_skipped consecutive download failures. Exiting downloader."
      exit 2
    fi
  fi
done < "$TMP_LIST"

echo "$(date) │ ✔️ All done."
exit 0
