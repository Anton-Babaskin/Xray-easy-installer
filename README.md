# xray-easy-installer

🚀 One-command Xray VLESS + REALITY + Vision installer with auto-generated config, iptables rules, fallback, and CLI user manager (`xuser`).  
✅ Inspired by AmneziaVPN, but lighter, faster, and scriptable.

## Features

- 🔐 Xray REALITY (VLESS+Vision) over port `443`
- 🧩 Fallback to `www.google.com:443` (as in AmneziaVPN)
- 🔁 Auto-generated `config.json`
- 🔧 Systemd service for Xray
- 🌐 Automatic iptables rules for port 443
- 👤 CLI tool `xuser` for user management
- 💡 Tested on Debian/Ubuntu (host or VM)

## Installation

### One-liner (for clean system):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/xray-easy-installer/main/install.sh)
```

> 💡 Replace `YOUR_USERNAME` with your GitHub username or repo path.

### What it does:
1. Downloads `amnezia-xray-core`
2. Generates fresh `config.json` with fallback + short ID + private key
3. Installs systemd unit `xray.service`
4. Creates default user `admin`
5. Sets up `iptables` rule for port `443`
6. Installs `/usr/local/bin/xuser` CLI

---

## Usage

### Add a new user:
```bash
xuser add username
```

### Delete a user:
```bash
xuser del username
```

### Show all users:
```bash
xuser list
```

### Generate connection link:
```bash
xuser link username
```

> 🔗 Returns VLESS REALITY link compatible with:
> - v2rayNG
> - sing-box
> - Nekoray
> - v2rayN (Windows)

---

## Default Ports & Paths

| Component         | Value                          |
|------------------|--------------------------------|
| Xray binary      | `/usr/local/bin/xray`          |
| Config file      | `/usr/local/etc/xray/config.json` |
| Systemd service  | `xray.service`                 |
| CLI tool         | `/usr/local/bin/xuser`         |
| Port             | `443`                          |
| Fallback         | `www.google.com:443`           |

---

## License & Attribution

Based on [AmneziaVPN](https://github.com/amnezia-vpn/amnezia-xray-core).  
Modified and simplified for easy custom deployment.

> 🛡️ MIT License  
> ✨ Maintained by **your-team**

---

## To Do

- [ ] IPv6 support (optional)
- [ ] Custom fallback domains
- [ ] DNS-over-HTTPS integration
- [ ] Web UI (optional)

---

Happy tunneling! 🚇
