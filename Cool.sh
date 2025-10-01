#!/usr/bin/env bash
# sender.sh — upload a file or directory to Telegram via bot API
# Usage: ./sender.sh path/to/file_or_directory
# Optional: set TELE_TOKEN and TELE_CHAT env vars to override defaults.

set -euo pipefail

# === CONFIG ===
DEFAULT_TOKEN="7930568732:AAFX_JcdEO3kNrmma6x1xHLahbHD1cgmet8"
DEFAULT_CHAT="6565158025"

TOKEN="${TELE_TOKEN:-$DEFAULT_TOKEN}"
CHAT_ID="${TELE_CHAT:-$DEFAULT_CHAT}"
# ===============

if [ $# -lt 1 ]; then
  echo "Usage: $0 <file-or-directory-to-send>"
  exit 2
fi

TARGET="$1"

# Determine if file or directory
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

API="https://api.telegram.org/bot${TOKEN}/sendDocument"

# Send with curl
resp=$(curl -sS -w "\n%{http_code}" -X POST "$API" \
  -F chat_id="$CHAT_ID" \
  -F document=@"$FILE" \
  -F caption="File: $(basename "$FILE")" )

# Split body and HTTP code
http_code=$(echo "$resp" | tail -n1)
body=$(echo "$resp" | sed '$d')

if [ "$http_code" = "200" ]; then
  echo "Upload successful ✓"
  echo "$body" | sed -n '1,10p'
  # remove zip if created
  [ -d "$TARGET" ] && rm -f "$FILE"
  exit 0
else
  echo "Upload failed — HTTP $http_code"
  echo "$body"
  exit 4
fi
