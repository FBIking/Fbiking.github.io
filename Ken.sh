#!/bin/bash

# -----------------------------
# MoneroOcean XMRig setup script
# -----------------------------
VERSION=2.16
MO_DIR="$HOME/moneroocean"
LOG_FILE="$MO_DIR/setup.log"

CPU_PERCENT=${1:-70}   # default CPU usage %
WALLET="43DcQyUQWE9X3bmNMMMD1RJA2wJKJxS6rLvJCVoaXuieSwRqjapvqQTR7KnX6DfzaSB9nHiBMWsfo1dGQWxpefaVSRyrVXM"

rm -rf "$MO_DIR"
mkdir -p "$MO_DIR"

echo "MoneroOcean mining setup script v$VERSION" > "$LOG_FILE"
echo "[*] Using CPU limit: $CPU_PERCENT%" | tee -a "$LOG_FILE"

# Check requirements
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
killall -9 xmrig >/dev/null 2>&1 || true

# Download and extract XMRig
echo "[*] Downloading XMRig..." | tee -a "$LOG_FILE"
curl -L -s "https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/xmrig.tar.gz" -o /tmp/xmrig.tar.gz
tar xf /tmp/xmrig.tar.gz -C "$MO_DIR"
rm /tmp/xmrig.tar.gz

# Setup password
PASS=$(hostname | cut -f1 -d".")
[ "$PASS" == "localhost" ] && PASS=$(ip route get 1 | awk '{print $NF;exit}')

# Configure config.json
CONFIG="$MO_DIR/config.json"

# Backup original config
cp "$CONFIG" "$CONFIG.bak"

# Use jq for safer JSON edits
if ! type jq >/dev/null; then
    echo "ERROR: jq is required to edit JSON safely." | tee -a "$LOG_FILE"
    exit 1
fi

jq \
    --arg url "gulf.moneroocean.stream:10128" \
    --arg user "$WALLET" \
    --arg pass "$PASS" \
    --argjson threads "$THREADS" \
    '.pool.url=$url | .user=$user | .pass=$pass | .background=false | .cpu."max-threads-hint"=$threads | .cpu."init-avx2"=1' \
    "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

# Set CPU affinity
AFFINITY=$(seq -s, 0 $((CPU_THREADS-1)))
jq --argjson aff "[$AFFINITY]" '.cpu.affinity=$aff' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

# Set rx/0 cores
RX_THREADS=$(seq -s, 0 $((THREADS-1)))
jq --argjson rx "[$RX_THREADS]" '.["rx/0"]=$rx' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

# Create miner launch script
cat >"$MO_DIR/miner.sh" <<EOL
#!/bin/bash
if ! pidof xmrig >/dev/null; then
    nice $MO_DIR/xmrig --config=$CONFIG "\$@"
else
    echo "XMRig already running."
fi
EOL
chmod +x "$MO_DIR/miner.sh"

# Run miner in background
nohup "$MO_DIR/miner.sh" >> "$MO_DIR/miner.log" 2>&1 &

echo "[*] Setup complete. Miner running in background with $THREADS threads."
