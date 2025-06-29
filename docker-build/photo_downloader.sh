#!/usr/bin/env bash
set -xeuo pipefail
shopt -s nullglob
PS4='+ [${BASH_SOURCE}:${LINENO}] '

: "${THRESHOLD:?Need THRESHOLD in env}"
: "${BASE_URL:=http://192.168.1.254/DCIM/Photo}"
: "${TEMP_DIR:=/app/downloads/photos}"
: "${DEST_DIR:=/app/dashcam/photos}"
: "${TAG_SCRIPT:=/app/tags_viofo.sh}"
: "${INDEX_FILE:=/app/downloads/photos/processed_files.txt}"

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

echo "$(date) │ Curling file list from $BASE_URL"
{
  curl --fail --connect-timeout 5 --max-time 15 -s "${BASE_URL%/}/" \
    | grep -oiE 'href="[^"]+\.JPG"' \
    | sed -E 's/^href="(.+)"/\1/' \
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
max_consecutive_skipped=10

while IFS= read -r FILE; do
  echo "$(date) │ → Next: $FILE"

  if ! check_space; then
    echo "❌ Low disk space before downloading $FILE. Exiting."
    exit 2
  fi

  REMOTE_URL="${BASE_URL%/}/$FILE"
  LOCAL_PATH="${TEMP_DIR%/}/$FILE"
  REFERENCE_FILE="${DEST_DIR%/}/$FILE"

  if grep -Fxq "$FILE" "$INDEX_FILE" 2>/dev/null; then
    echo "$(date) │ ✅ Already processed. Skipping."
    consecutive_skipped=$((consecutive_skipped + 1))
    if (( consecutive_skipped >= max_consecutive_skipped )); then
      echo "$(date) │ 🚪 $max_consecutive_skipped consecutive files already processed. Exiting downloader."
      exit 0
    fi
    continue
  fi

  if [[ -f "$REFERENCE_FILE" ]]; then
    embedded=$(exiftool -s3 -Comment "$REFERENCE_FILE" | grep -oE '[a-f0-9]{64}' || true)
    if [[ -n "$embedded" ]]; then
      echo "$(date) │ ✅ Existing file has checksum. Skipping."
      echo "$FILE" >> "$INDEX_FILE"
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
      echo "$FILE" >> "$INDEX_FILE"
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
exit