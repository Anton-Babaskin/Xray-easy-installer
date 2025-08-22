#!/usr/bin/env bash
# install.sh — xray-easy-installer (VLESS + REALITY + Vision) with fallback, iptables, and xuser

set -euo pipefail

CONFIG="/usr/local/etc/xray/config.json"
XRAY_BIN="/usr/local/bin/xray"
XUSER_BIN="/usr/local/bin/xuser"
SERVICE="/etc/systemd/system/xray.service"

install_xray() {
  echo "🔧 Установка Xray..."

  mkdir -p /usr/local/etc/xray

  echo "📦 Скачиваем Xray-core (Amnezia Edition)..."
  curl -Lo "$XRAY_BIN" https://github.com/amnezia/xray-core/releases/latest/download/xray-linux-64
  chmod +x "$XRAY_BIN"

  echo "📁 Скачиваем geo-файлы..."
  curl -Lo /usr/local/etc/xray/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
  curl -Lo /usr/local/etc/xray/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat

  echo "🛡️ Генерация ключей..."
  keys=$($XRAY_BIN x25519)
  priv=$(echo "$keys" | awk '/Private/{print $3}')
  pub=$(echo "$keys" | awk '/Public/{print $3}')
  sid=$(openssl rand -hex 8)
  uuid=$(uuidgen)

  ip=$(curl -s -4 https://api.ipify.org || hostname -I | awk '{print $1}')
  sni="www.google.com"

  echo "⚙️ Создаём config.json..."
  cat > "$CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [
        {
          "id": "$uuid",
          "flow": "xtls-rprx-vision",
          "email": "admin"
        }
      ],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "www.google.com:443",
        "xver": 0,
        "serverNames": ["$sni"],
        "privateKey": "$priv",
        "shortIds": ["$sid"]
      }
    }
  }],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

  echo "🧩 Создаём systemd unit..."
  cat > "$SERVICE" <<EOF
[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
ExecStart=$XRAY_BIN run -config $CONFIG
Restart=on-failure
User=nobody
AmbientCapabilities=CAP_NET_BIND_SERVICE
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable xray
  systemctl restart xray

  echo "📦 Устанавливаем xuser CLI..."
  curl -Lo "$XUSER_BIN" https://raw.githubusercontent.com/Anton-Babaskin/xray-easy-installer/main/xuser
  chmod +x "$XUSER_BIN"

  echo "🧱 Добавляем iptables правило на порт 443..."
  iptables -I INPUT -p tcp --dport 443 -j ACCEPT

  echo "✅ Установка завершена."
  echo ""
  echo "🔗 VLESS ссылка:"
  $XUSER_BIN link admin
}

uninstall_xray() {
  echo "🧹 Удаление Xray..."

  systemctl stop xray
  systemctl disable xray
  rm -f "$SERVICE"
  systemctl daemon-reload

  rm -f "$XRAY_BIN"
  rm -f "$XUSER_BIN"
  rm -rf /usr/local/etc/xray

  iptables -D INPUT -p tcp --dport 443 -j ACCEPT || true

  echo "✅ Xray удалён полностью."
}

main_menu() {
  echo "Welcome to Xray-easy-installer!"
  echo ""
  echo "1) Install Xray (VLESS + REALITY + Vision)"
  echo "2) Add new user"
  echo "3) List users"
  echo "4) Remove user"
  echo "5) Uninstall Xray"
  echo "6) Exit"
  echo ""

  read -rp "Select an option [1-6]: " option
  case "$option" in
    1) install_xray ;;
    2) $XUSER_BIN add ;;
    3) $XUSER_BIN list ;;
    4) $XUSER_BIN del ;;
    5) uninstall_xray ;;
    6) exit 0 ;;
    *) echo "❌ Invalid option." ;;
  esac
}

main_menu
