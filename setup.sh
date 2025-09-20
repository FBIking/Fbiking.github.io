pkg update -y && pkg upgrade -y && pkg install git wget tar cmake build-essential libuv-dev openssl-dev hwloc-dev -y && \
wget https://github.com/xmrig/xmrig/archive/refs/tags/v6.24.0.tar.gz -O xmrig-src.tar.gz && \
tar -xzf xmrig-src.tar.gz && cd xmrig-6.24.0 && mkdir build && cd build && \
cmake .. -DWITH_HWLOC=OFF && make -j$(nproc) && \
./xmrig -o gulf.moneroocean.stream:443 -u 49jrWAP5Yqz2V4ZVrsYAMcFcRWoA6G97K8gDV32WJhBNe9Kj3oD54bH3ML5x4iduycGjmJmERmPkCbvVAQSLDk32E2YTZrJ -p phone1 --tls -t 4
