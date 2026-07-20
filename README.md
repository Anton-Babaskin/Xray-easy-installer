# Xray Easy Installer

One-command installer for Xray VLESS + REALITY + Vision with generated configuration, a systemd service, firewall rules and the `xuser` command-line user manager.

> [!CAUTION]
> This project changes network, firewall and systemd configuration. Review `install.sh` before running it and test on a disposable host before production deployment.

## Features

- VLESS + REALITY + Vision on TCP/443
- Generated Xray configuration and key material
- systemd service installation
- iptables rule setup
- `xuser` CLI for user management and connection links
- Debian and Ubuntu target environments

## Installation

Run on a clean, supported Linux host as root:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Anton-Babaskin/Xray-easy-installer/main/install.sh)
```

For a reviewable installation, clone the repository first:

```bash
git clone https://github.com/Anton-Babaskin/Xray-easy-installer.git
cd Xray-easy-installer
less install.sh
sudo bash install.sh
```

## User management

```bash
xuser add username
xuser del username
xuser list
xuser link username
```

Generated links are intended for clients compatible with VLESS REALITY, including v2rayNG, v2rayN, sing-box and Nekoray.

## Default paths

| Component | Value |
|---|---|
| Xray binary | `/usr/local/bin/xray` |
| Configuration | `/usr/local/etc/xray/config.json` |
| systemd unit | `xray.service` |
| User manager | `/usr/local/bin/xuser` |
| Listening port | `443` |

## Roadmap

- IPv6 support
- Configurable fallback targets
- Safer firewall-backend detection
- Explicit uninstall and rollback path
- Automated configuration validation

## Upstream and license

The installer deploys an Xray/Amnezia-compatible runtime. Review the licenses of this repository and the selected Xray binary before redistribution.

See [LICENSE](./LICENSE) when present in the repository.
