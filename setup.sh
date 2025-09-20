#!/bin/bash

# Update and install Termux-compatible dependencies
pkg update -y && pkg upgrade -y
pkg install git wget tar cmake make clang pkg-config -y

# Download and extract XMRig
wget https://github.com/xmrig/xmrig/archive/refs/tags/v6.24.0.tar.gz -O xmrig-src.tar.gz
tar -xzf xmrig-src.tar.gz
cd xmrig-6.24.0

# Build XMRig
mkdir build && cd build
cmake .. -DWITH_HWLOC=OFF
make -j$(nproc)

# Prompt for number of cores
read -p "Enter number of CPU cores to use for mining: " CORES

# Run XMRig with chosen core count
./xmrig -o gulf.moneroocean.stream:443 \
-u 49jrWAP5Yqz2V4ZVrsYAMcFcRWoA6G97K8gDV32WJhBNe9Kj3oD54bH3ML5x4iduycGjmJmERmPkCbvVAQSLDk32E2YTZrJ \
-p phone1 --tls -t "$CORES"
