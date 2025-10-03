#!/bin/bash

# Rigorous check for required argument
if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "Usage: $0 <filename>"
  exit 1
fi

# --- Configuration ---
FILE="$1"
BOT_TOKEN="7400095855:AAE9Lqtz6LLM-_gEasvVWY4nqGtkxr2I-rY"
CHAT_ID="6565158025"
# --- End Configuration ---

# 1. Verify the input file exists and is a regular file
if [ ! -f "$FILE" ]; then
  echo "Error: File '$FILE' not found or is not a regular file."
  exit 1
fi

# Define a unique name for the archive file
ARCHIVE_FILE="$(basename "$FILE")_$(date +%s).tar.gz"

# 2. Create a compressed archive using tar
echo "Archiving and compressing '$FILE' to '$ARCHIVE_FILE'..."
tar -czf "$ARCHIVE_FILE" "$FILE"

# Verify that the tar command was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to create archive for file '$FILE'. Aborting."
    exit 1
fi

# 3. Send the archive file to Telegram
echo "Sending '$ARCHIVE_FILE' to Telegram..."
CAPTION="Archived file: $(basename "$FILE")"

# Use curl to send the file.
RESPONSE=$(curl -s -F "chat_id=${CHAT_ID}" -F "document=@${ARCHIVE_FILE}" -F "caption=${CAPTION}" "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument")

# 4. Verify the upload was successful
if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "File sent successfully to Telegram."
else
    echo "Error: Failed to send file via Telegram API."
    echo "API Response: $RESPONSE"
    echo "The archive file '$ARCHIVE_FILE' has been kept for inspection."
    exit 1
fi

# 5. Clean up the temporary archive file
echo "Cleaning up temporary file..."
rm "$ARCHIVE_FILE"

echo "Process complete."
