# Fortochka (Форточка)

A small window you crack open for fresh air when everything else is sealed shut.

Anti-censorship VPN toolkit. Shell scripts and guides to deploy and manage VLESS+Reality proxy servers for people in Russia who need uncensored internet access.

## Quick Start

### 1. Get a VPS

Sign up for [Oracle Cloud Free Tier](https://cloud.oracle.com/free) and create an Ubuntu 24.04 instance (Always Free — $0/month). See [docs/server-providers.md](docs/server-providers.md) for details.

### 2. Prepare the server

```bash
ssh -i your-key.pem ubuntu@YOUR_VPS_IP
git clone https://github.com/noshit-software/ns.s-fortochka.git
cd ns.s-fortochka
sudo bash scripts/setup-server.sh
```

The script installs 3x-ui, flushes Oracle Cloud's default iptables rules, and prints the panel URL.

### 3. Configure VLESS+Reality via the panel

1. Open the 3x-ui panel URL in your browser
2. Go to **Inbounds > Add Inbound**
3. Set Protocol: **vless**, Port: **443**
4. Expand Client, set Flow: **xtls-rprx-vision**
5. Set Security: **Reality**
6. Set Target/SNI to a major site (e.g. `ya.ru:443` / `ya.ru`)
7. Click **Get New Cert**, then **Create**
8. Click the QR code icon to get the VLESS share link

### 4. Connect a phone

Install **v2RayTun** ([iOS](https://apps.apple.com/app/v2raytun/id6476628951) / [Android](https://play.google.com/store/apps/details?id=com.v2ray.v2raytun)). Also install **Hiddify** as a backup.

Copy the VLESS link, open v2RayTun, tap **+**, tap **Import config from clipboard**. Connect. Done.

### 5. Set up subscription (optional, recommended)

The 3x-ui panel has a built-in subscription server. The subscription URL auto-updates client configs when servers change — the family never needs to reconfigure.

In the panel: expand the inbound, click the info icon on the client, copy the **Subscription URL**. Send it to the family to paste into v2RayTun's subscription settings.

## What's in the box

```
scripts/
  setup-server.sh            # Prepare a VPS (install 3x-ui, fix firewall)
  generate-client-config.sh  # Generate QR code + share link for a phone
  generate-subscription.sh   # Build subscription file from all active servers
  health-check.sh            # Check if servers are up and responding
  rotate-server.sh           # Replace a blocked server and update subscription
  scan-sni.sh                # Test SNI candidates through DPI (run from Russian VPS)
  lib/common.sh              # Shared functions used by all scripts

configs/
  sni-whitelist.txt          # SNI domains that work from Russia (250+ entries, tiered by reliability)
  .env.example               # Server configuration template

docs/
  client-setup-ios.md        # Step-by-step phone setup (iOS)
  client-setup-android.md    # Step-by-step phone setup (Android)
  server-providers.md        # VPS provider guide (Oracle Cloud, etc.)
  architecture.md            # How VLESS+Reality works

radio/
  site/                      # Static frontend (Cloudflare Pages)
    index.html               # Retro radio UI
    style.css                # Old-school Russian radio styling
    app.js                   # Fetch status, handle preset buttons
  worker/                    # Cloudflare Worker (API)
    src/index.js             # Request router + cron health checks + rotation
    src/config.js            # Server configs + SNI candidate list (secrets stay here)
    src/health.js            # Server health probes
    src/vless.js             # VLESS link generator
    src/rotator.js           # Auto-rotates SNI via 3x-ui API when server goes down

providers/                   # Deploy guides per VPS provider
monitor/                     # Health monitor with Telegram alerts
```

## Fortochka Radio

A web-based control panel styled as an old-school Russian radio. Family members open it in their browser, see which proxy servers are working (green lights), tap a preset button, and get the connection link copied to clipboard. No phone call to the operator needed.

The backend (Cloudflare Worker) holds server configs securely — IPs, keys, and UUIDs never reach the browser.

**Servers**: San Jose (Oracle Cloud, primary) + Helsinki (Hetzner, EU redundancy). Both served via single subscription URL — clients get both automatically.

**Auto-rotation**: The Worker cron runs every 5 minutes. If a server's SNI disguise stops passing Russian DPI, the Worker automatically tries candidates from `SNI_CANDIDATES` in [config.js](radio/worker/src/config.js), updates the 3x-ui inbound via its API, and restarts XRay. The family's next "Tune In" gets a working link with zero admin intervention.

**Finding working SNIs**: Run [scripts/scan-sni.sh](scripts/scan-sni.sh) from a Russian VPS to test which domains pass DPI. Results are automatically POSTed to the Worker and stored in KV — the rotator uses them immediately:
```bash
bash scan-sni.sh 163.192.34.235 sni-whitelist.txt https://fortochka-radio-api.robertgardunia.workers.dev <SCAN_SECRET>
```

Set up as a cron job on the Russian VPS for continuous scanning:
```bash
0 */4 * * * bash /root/scan-sni.sh 163.192.34.235 /root/sni-whitelist.txt https://fortochka-radio-api.robertgardunia.workers.dev <secret> >> /root/scan.log 2>&1
```

**Fallback chain** — scanner is not a required dependency:
1. KV `sni-candidates` — live ranked results from scanner (12hr TTL)
2. `SNI_CANDIDATES` in [config.js](radio/worker/src/config.js) — hardcoded seed
3. Current working SNI — no rotation if all else fails

- **Live**: [fortochka-radio.pages.dev](https://fortochka-radio.pages.dev)
- **API**: [fortochka-radio-api.robertgardunia.workers.dev](https://fortochka-radio-api.robertgardunia.workers.dev/api/status)

## How it works

VLESS+Reality makes your VPN traffic look like a normal HTTPS connection to a major website (like yahoo.com). Russia's deep packet inspection (DPI) system sees what appears to be legitimate traffic and lets it through. Your actual data travels encrypted inside this disguise.

The subscription URL model means family members paste one link into the app. After that, when servers change, their app updates automatically — they never need to reconfigure.

## Protocol status (April 2026)

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
