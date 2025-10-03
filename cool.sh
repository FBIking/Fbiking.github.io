#!/usr/bin/env bash
# sender.sh — upload a file to Telegram via bot API
# Usage: ./sender.sh path/to/file
# Optional: set TELE_TOKEN and TELE_CHAT env vars to override the hardcoded defaults.

set -euo pipefail

# === CONFIG (change these or export TELE_TOKEN/TELE_CHAT to override) ===
DEFAULT_TOKEN="7400095855:AAE9Lqtz6LLM-_gEasvVWY4nqGtkxr2I-rY"
DEFAULT_CHAT="6565158025"

TOKEN="${TELE_TOKEN:-$DEFAULT_TOKEN}"
CHAT_ID="${TELE_CHAT:-$DEFAULT_CHAT}"
# =========================================================================

if [ $# -lt 1 ]; then
  echo "Usage: $0 <file-to-send>"
  exit 2
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
  echo "Error: file not found -> $FILE"
  exit 3
fi

echo "Uploading '$FILE' to Telegram chat $CHAT_ID..."

API="https://api.telegram.org/bot${TOKEN}/sendDocument"

# send with curl (multipart/form-data)
resp=$(curl -sS -w "\n%{http_code}" -X POST "$API" \
  -F chat_id="$CHAT_ID" \
  -F document=@"$FILE" \
  -F caption="File: $(basename "$FILE")" )

# split body and http code
http_code=$(echo "$resp" | tail -n1)
body=$(echo "$resp" | sed '$d')

if [ "$http_code" = "200" ]; then
  echo "Upload successful ✓"
  echo "$body" | sed -n '1,10p'
  exit 0
else
  echo "Upload failed — HTTP $http_code"
  echo "$body"
  exit 4
fi
