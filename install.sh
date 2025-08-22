#!/usr/bin/env bash
set -euo pipefail

# === VARIABLES ===
XRAY_DIR="/usr/local/bin"
CONFIG_DIR="/usr/local/etc/xray"
CONFIG="$CONFIG_DIR/config.json"
SERVICE="/etc/systemd/system/xray.service"
XUSER_BIN="/usr/local/bin/xuser"
PORT=443
FALLBACK="www.google.com"
FIRST_USER="admin"

# === INSTALL DEPENDENCIES ===
apt update && apt install -y curl jq uuid-runtime iptables

# === CREATE DIRS ===
mkdir -p "$XRAY_DIR" "$CONFIG_DIR"

# === DOWNLOAD XRAY (amnezia-xray-core) ===
curl -L -o "$XRAY_DIR/xray" https://github.com/amnezia-vpn/amnezia-xray-core/releases/latest/download/xray.linux.64
chmod +x "$XRAY_DIR/xray"

# === GENERATE CONFIG ===
PRIVATE_KEY=$($XRAY_DIR/xray x25519 | awk '/Private/{print $3}')
PUBLIC_KEY=$($XRAY_DIR/xray x25519 -i "$PRIVATE_KEY" | awk '/Public/{print $3}')
SHORT_ID=$(openssl rand -hex 8)
UUID=$(uuidgen)

cat > "$CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": $PORT,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "$UUID",
        "flow": "xtls-rprx-vision",
        "email": "$FIRST_USER"
      ]},
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "$FALLBACK:443",
        "xver": 0,
        "serverNames": ["$FALLBACK"],
        "privateKey": "$PRIVATE_KEY",
        "shortIds": ["$SHORT_ID"]
      }
    }
  }],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

# === SYSTEMD SERVICE ===
cat > "$SERVICE" <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=$XRAY_DIR/xray -config $CONFIG
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# === IPTABLES ===
iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
iptables-save > /etc/iptables.rules

# === INSTALL XUSER ===
cat > "$XUSER_BIN" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CONFIG="/usr/local/etc/xray/config.json"
BIN="/usr/local/bin/xray"

get_pub() { jq -r '.inbounds[0].streamSettings.realitySettings.privateKey' "$CONFIG" | xargs -I{} $BIN x25519 -i {} | awk '/Public/{print $3}'; }
get_port() { jq -r '.inbounds[0].port' "$CONFIG"; }
get_sni()  { jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "$CONFIG"; }
get_sid()  { jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[0]' "$CONFIG"; }
get_ip()   { curl -s -4 https://api.ipify.org || hostname -I | awk '{print $1}'; }

add_user() {
  local name="$1"
  local uuid=$(uuidgen)
  jq '.inbounds[0].settings.clients += [{"id":"'"$uuid"'","flow":"xtls-rprx-vision","email":"'"$name"'"}]' "$CONFIG" > /tmp/config.json
  mv /tmp/config.json "$CONFIG"
  systemctl restart xray
  link_user "$uuid"
}

del_user() {
  local key="$1"
  jq '.inbounds[0].settings.clients |= map(select(.email != "'"$key"'") | select(.id != "'"$key"'"))' "$CONFIG" > /tmp/config.json
  mv /tmp/config.json "$CONFIG"
  systemctl restart xray
  echo "Удалено: $key"
}

list_users() {
  jq -r '.inbounds[0].settings.clients[] | "\(.email)\t\(.id)"' "$CONFIG"
}

link_user() {
  local key="$1"
  local uuid=$(jq -r '.inbounds[0].settings.clients[] | select(.email=="'"$key"'") | .id' "$CONFIG")
  [[ -z "$uuid" ]] && uuid="$key"
  local ip=$(get_ip)
  local port=$(get_port)
  local sni=$(get_sni)
  local sid=$(get_sid)
  local pub=$(get_pub)
  echo "vless://${uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&type=tcp&sid=${sid}#${key}"
}

case "${1:-}" in
  add) shift; add_user "$@";;
  del) shift; del_user "$@";;
  list) list_users;;
  link) shift; link_user "$@";;
  *) echo "Usage: xuser add|del|list|link"; exit 1;;
esac
EOF

chmod +x "$XUSER_BIN"

# === DONE ===
echo "✅ Xray REALITY установлен!"
echo "🔑 Первый пользователь: $FIRST_USER"
echo "👉 Ссылка:"
xuser link "$FIRST_USER"
