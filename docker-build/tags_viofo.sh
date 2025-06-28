#!/usr/bin/env bash
set -euo pipefail

command -v exiftool >/dev/null 2>&1 || { echo "exiftool not found"; exit 1; }

FILE="$1"

echo "🔧 Tagging: $(basename "$FILE")"

# Extract metadata from filename
BASENAME=$(basename "$FILE" .MP4)
YEAR=${BASENAME:0:4}
MONTH=${BASENAME:5:2}
DAY=${BASENAME:7:2}
HOUR=${BASENAME:10:2}
MINUTE=${BASENAME:12:2}
SECOND=${BASENAME:14:2}
FLAGS=${BASENAME:21:2}

PROTECTED_FLAG=${FLAGS:0:1}
CAMERA_POSITION=${FLAGS:1:1}

PROTECTED_STATUS=$([ "$PROTECTED_FLAG" == "P" ] && echo "Yes" || echo "No")
CAMERA_DESC=$([ "$CAMERA_POSITION" == "F" ] && echo "Front" || echo "Rear")
DATETIME="${YEAR}:${MONTH}:${DAY} ${HOUR}:${MINUTE}:${SECOND}"

# Compute SHA-256
CHECKSUM=$(sha256sum "$FILE" | cut -d' ' -f1)

# Apply metadata (only one exiftool call needed)
exiftool -m -overwrite_original -q -q -ExtractEmbedded \
  -DateTimeOriginal="$DATETIME" \
  -CreateDate="$DATETIME" \
  -ModifyDate="$DATETIME" \
  -Title="VIOFO Dashcam - $CAMERA_DESC" \
  -Comment="Protected: $PROTECTED_STATUS | Checksum: $CHECKSUM" \
  "$FILE"

# Update file modification timestamp to match dashcam datetime
TOUCH_TIMESTAMP="${YEAR}${MONTH}${DAY}${HOUR}${MINUTE}.${SECOND}"
touch -t "$TOUCH_TIMESTAMP" "$FILE"

echo "📅 File mtime set to: $DATETIME"
