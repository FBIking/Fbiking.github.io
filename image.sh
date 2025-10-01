#!/usr/bin/env bash
# sender.sh
# Usage:
#   bash sender.sh -i            # send images from current dir
#   bash sender.sh -v            # send mp4 videos from current dir
#   bash sender.sh -i -d /path   # send images from /path
#
# You provided token and chat id — keep this file safe.

set -uo pipefail

# --- CONFIG: replace or keep the provided values ---
TOKEN="7400095855:AAE9Lqtz6LLM-_gEasvVWY4nqGtkxr2I-rY"
CHAT_ID="6565158025"
# ----------------------------------------------------

API="https://api.telegram.org/bot${TOKEN}"
DIR="."
MODE=""

show_help() {
  cat <<EOF
Usage:
  $0 -i            send images (jpg, jpeg, png, gif, webp) from DIR (default: .)
  $0 -v            send mp4 videos from DIR (default: .)
  $0 -d /path      set directory to /path
  $0 -h            show this help
EOF
}

# parse args
while getopts ":ivd:h" opt; do
  case "$opt" in
    i) MODE="images" ;;
    v) MODE="videos" ;;
    d) DIR="${OPTARG%/}" ;;
    h) show_help; exit 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; show_help; exit 2 ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Error: choose -i (images) or -v (videos)." >&2
  show_help
  exit 2
fi

if [[ ! -d "$DIR" ]]; then
  echo "Error: directory '$DIR' not found." >&2
  exit 2
fi

# Build file list
mapfile -t files < <(
  if [[ "$MODE" == "images" ]]; then
    find "$DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) -print0 | xargs -0 -n1 -I{} printf '%s\n' "{}"
  else
    find "$DIR" -maxdepth 1 -type f -iname "*.mp4" -print0 | xargs -0 -n1 -I{} printf '%s\n' "{}"
  fi
)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No files found for mode='$MODE' in '$DIR'. Nothing to send."
  exit 0
fi

echo "Found ${#files[@]} file(s). Starting to send one-by-one..."

success=0
fail=0
i=0

for f in "${files[@]}"; do
  ((i++))
  echo "[$i/${#files[@]}] Sending: $f"
  if [[ "$MODE" == "images" ]]; then
    # sendPhoto
    if curl --silent --show-error --fail -F chat_id="$CHAT_ID" -F photo=@"$f" "${API}/sendPhoto" > /dev/null 2>&1; then
      echo "  ✅ sent"
      ((success++))
    else
      echo "  ❌ failed to send"
      ((fail++))
    fi
  else
    # sendVideo
    if curl --silent --show-error --fail -F chat_id="$CHAT_ID" -F video=@"$f" "${API}/sendVideo" > /dev/null 2>&1; then
      echo "  ✅ sent"
      ((success++))
    else
      echo "  ❌ failed to send"
      ((fail++))
    fi
  fi

  # brief pause to avoid hitting rate limits
  sleep 1
done

echo "Done. Success: $success  Failed: $fail"

# exit code: 0 (successfully finished script). If you prefer non-zero when any fail, change below.
exit 0
