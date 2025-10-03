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

# Define a unique name for the zip file to avoid conflicts
ZIP_FILE="$(basename "$FILE")_$(date +%s).zip"

# 2. Zip the file
# The 'zip' command includes checksums to ensure integrity.
echo "Zipping '$FILE' to '$ZIP_FILE'..."
zip -j "$ZIP_FILE" "$FILE"

# Verify that the zip command was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to zip file '$FILE'. Aborting."
    exit 1
fi

# 3. Send the zipped file to Telegram
echo "Sending '$ZIP_FILE' to Telegram..."
CAPTION="Archived file: $(basename "$FILE")"

# Use curl to send the file. The -s flag silences progress output.
# We capture the API response to check for success.
RESPONSE=$(curl -s -F "chat_id=${CHAT_ID}" -F "document=@${ZIP_FILE}" -F "caption=${CAPTION}" "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument")

# 4. Verify the upload was successful
# A successful Telegram API response contains '"ok":true'.
if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "File sent successfully to Telegram."
else
    echo "Error: Failed to send file via Telegram API."
    echo "API Response: $RESPONSE"
    # Keep the zip file for inspection if sending failed
    echo "The zip file '$ZIP_FILE' has been kept for inspection."
    exit 1
fi

# 5. Clean up the temporary zip file
echo "Cleaning up temporary file..."
rm "$ZIP_FILE"

echo "Process complete."
