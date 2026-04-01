# Fortochka (Форточка)

A small window you crack open for fresh air when everything else is sealed shut.

Anti-censorship VPN toolkit. Shell scripts to deploy and manage VLESS+Reality proxy servers for people in Russia who need uncensored internet access.

## Quick Start

### 1. Get a VPS

Sign up for [Oracle Cloud Free Tier](https://cloud.oracle.com/free) and create an Ubuntu 24.04 ARM instance (Always Free — $0/month). See [docs/server-providers.md](docs/server-providers.md) for details.

### 2. Set up the server

```bash
ssh ubuntu@YOUR_VPS_IP
git clone https://github.com/YOUR_USERNAME/ns.s-fortochka.git
cd ns.s-fortochka
sudo bash scripts/setup-server.sh
```

The script installs XRay (via 3x-ui), configures VLESS+Reality on port 443, sets up the firewall, and outputs a QR code.

### 3. Connect a phone

- **iOS**: Install [v2RayTun](https://apps.apple.com/app/v2raytun/id6476628951) from the App Store
- **Android**: Install [v2rayNG](https://play.google.com/store/apps/details?id=com.v2ray.ang) from Google Play (or [sideload the APK](https://github.com/2dust/v2rayNG/releases))

Scan the QR code. Connect. Done.

### 4. Set up auto-updating configs (optional)

```bash
# Generate a subscription URL your family's apps can poll for config updates
bash scripts/generate-subscription.sh
bash subscription/publish-gist.sh
```

When a server gets blocked, add a new one and update the subscription — client apps pull the new config automatically.

## What's in the box

```
scripts/
  setup-server.sh            # Install and configure a VPN server
  generate-client-config.sh  # Generate QR code + share link for a phone
  generate-subscription.sh   # Build subscription file from all active servers
  health-check.sh            # Check if servers are up and responding
  rotate-server.sh           # Replace a blocked server and update subscription
  lib/common.sh              # Shared functions used by all scripts

configs/
  xray-server-template.json  # XRay server config template
  xray-client-template.json  # XRay client config template
  sni-whitelist.txt          # SNI domains that work from Russia
  .env.example               # Server configuration template

docs/
  client-setup-ios.md        # Step-by-step phone setup (iOS)
  client-setup-android.md    # Step-by-step phone setup (Android)
  server-providers.md        # VPS provider guide (Oracle Cloud, etc.)
  architecture.md            # How VLESS+Reality works

subscription/
  publish-gist.sh            # Push subscription to GitHub Gist
```

## How it works

VLESS+Reality makes your VPN traffic look like a normal HTTPS connection to a major website (like microsoft.com). Russia's deep packet inspection (DPI) system sees what appears to be legitimate traffic and lets it through. Your actual data travels encrypted inside this disguise.

The subscription URL model means family members install the app and scan one QR code. After that, when servers change, their app updates automatically — they never need to reconfigure.

## Protocol status (March 2026)

| Protocol | Status |
|----------|--------|
| OpenVPN | Dead |
| WireGuard | Dead |
| Shadowsocks | Dead |
| VMess | Dead |
| Trojan | Dead |
| **VLESS+Reality** | **Alive** |
| VLESS+WebSocket | Alive (CDN fallback) |
| Hysteria2 | Alive (UDP) |

## noshit.software

Part of the [noshit.software](https://noshit.software) portfolio. Real infrastructure for real people.
