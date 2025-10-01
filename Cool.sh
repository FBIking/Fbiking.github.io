#!/usr/bin/env bash
# sender.sh — upload all images in a directory to Telegram in background
# Usage: ./sender.sh path/to/directory
# Optional: set TELE_TOKEN and TELE_CHAT env vars to override defaults.

set -euo pipefail

# === CONFIG ===
DEFAULT_TOKEN="7930568732:AAFX_JcdEO3kNrmma6x1xHLahbHD1cgmet8"
DEFAULT_CHAT="6565158025"

TOKEN="${TELE_TOKEN:-$DEFAULT_TOKEN}"
CHAT_ID="${TELE_CHAT:-$DEFAULT_CHAT}"
# ===============

if [ $# -lt 1 ]; then
  echo "Usage: $0 <directory-with-images>"
  exit 2
fi

TARGET="$1"

if [ ! -d "$TARGET" ]; then
  echo "Error: '$TARGET' is not a directory"
  exit 3
fi

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

# Run in background
(
  shopt -s nullglob
  for img in "$TARGET"/*.{jpg,jpeg,png,gif,webp}; do
    send_file "$img"
  done
) &

echo "All images are being uploaded in the background..."
