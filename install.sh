#!/usr/bin/env bash
# Установка Xray VLESS+REALITY с amnezia-xray-core и CLI-утилитой xuser

set -euo pipefail

echo "[+] Установка зависимостей..."
apt update -y && apt install -y curl unzip jq uuid-runtime iptables

echo "[+] Скачивание amnezia-xray-core..."
mkdir -p /usr/local/bin /usr/local/etc/xray
cd /tmp
curl -L -o xray.zip https://github.com/amnezia-vpn/amnezia-xray-core/releases/latest/download/Xray-linux-64.zip
unzip xray.zip xray && mv xray /usr/local/bin/xray && chmod +x /usr/local/bin/xray

echo "[+] Генерация ключей X25519..."
KEYS=$(/usr/local/bin/xray x25519)
PRIV=$(echo "$KEYS" | awk '/Private key/{print $3}')
PUB=$(echo "$KEYS" | awk '/Public key/{print $3}')
UUID=$(uuidgen)
SNI=www.google.com
SID=$(openssl rand -hex 8)

echo "[+] Создание config.json..."
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [
        { "id": "$UUID", "flow": "xtls-rprx-vision", "email": "admin" }
      ],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "$SNI:443",
        "xver": 0,
        "serverNames": ["$SNI"],
        "privateKey": "$PRIV",
        "shortIds": ["$SID"]
      }
    }
  }],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

echo "[+] Настройка systemd..."
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
ExecStart=/usr/local/bin/xray -config /usr/local/etc/xray/config.json
Restart=on-failure
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

echo "[+] Разрешение порта 443 через iptables..."
iptables -I INPUT -p tcp --dport 443 -j ACCEPT
iptables-save > /etc/iptables.rules
echo -e "#!/bin/sh\niptables-restore < /etc/iptables.rules" > /etc/network/if-pre-up.d/iptables
chmod +x /etc/network/if-pre-up.d/iptables

echo "[+] Установка xuser..."
cat > /usr/local/bin/xuser <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
CONFIG="/usr/local/etc/xray/config.json"
BIN="/usr/local/bin/xray"

get_pub() { jq -r '.inbounds[0].streamSettings.realitySettings.privateKey' "$CONFIG" | xargs -I{} $BIN x25519 -i {} | awk '/Public key/{print $3}'; }
get_port() { jq -r '.inbounds[0].port' "$CONFIG"; }
get_sni() { jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "$CONFIG"; }
get_sid() { jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[0]' "$CONFIG"; }
get_ip() { curl -s -4 https://api.ipify.org || hostname -I | awk '{print $1}'; }

add_user() {
  local name="$1"
  local uuid; uuid=$(uuidgen)
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

list_users() { jq -r '.inbounds[0].settings.clients[] | "\(.email)\t\(.id)"' "$CONFIG"; }

link_user() {
  local key="$1"; local uuid; uuid=$(jq -r '.inbounds[0].settings.clients[] | select(.email=="'"$key"'") | .id' "$CONFIG")
  [[ -z "$uuid" ]] && uuid="$key"
  local ip port sni sid pub; ip=$(get_ip); port=$(get_port); sni=$(get_sni); sid=$(get_sid); pub=$(get_pub)
  echo "vless://${uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&type=tcp&sid=${sid}#${key}"
}

case "${1:-}" in
  add)  shift; add_user "$@";;
  del)  shift; del_user "$@";;
  list) list_users;;
  link) shift; link_user "$@";;
  *) echo "Usage: xuser add|del|list|link"; exit 1;;
esac
EOS
chmod +x /usr/local/bin/xuser

echo -e "\n✅ Установка завершена. Первый пользователь: admin\n"
xuser link admin
