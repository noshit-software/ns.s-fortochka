# Fortochka (Форточка)

Anti-censorship VPN toolkit for family in Russia. Shell scripts that set up and manage VLESS+Reality proxy servers.

## What this is

A collection of bash scripts to:
1. Provision a VLESS+Reality VPN server on a fresh Ubuntu VPS
2. Generate client configs (QR codes / share links) for family members' phones
3. Manage subscription URLs so clients auto-update when servers change
4. Monitor server health
5. Rotate servers when they get blocked

## Tech stack

- **Scripts**: Bash (all scripts use `set -euo pipefail`)
- **Server software**: XRay-core via 3x-ui panel (github.com/MHSanaei/3x-ui)
- **Protocol**: VLESS + REALITY + XTLS-Vision over TCP (primary), WebSocket and XHTTP fallbacks
- **Target server OS**: Ubuntu 22.04 or 24.04 (ARM or x86)
- **Primary hosting**: Oracle Cloud Free Tier (E2.1.Micro AMD, San Jose)
- **Client apps**: v2RayTun (iOS + Android), Hiddify (backup)

## Key constraints

- End users (family) are non-technical — everything on their side must be dead simple
- No Terraform, no Ansible, no Docker — just shell scripts a developer can read and run
- Never commit real keys, UUIDs, server IPs, or .env files
- All scripts source `scripts/lib/common.sh` for shared functions
- Do NOT edit XRay config files directly — 3x-ui manages config via its database and overwrites manual changes
- Configure VLESS inbounds through the 3x-ui web panel, not scripts

## Active servers

- **fortochka** (Oracle Cloud Free Tier, E2.1.Micro AMD, San Jose)
  - SSH: `ssh -i ~/.ssh/fortochka.key ubuntu@163.192.34.235`
  - 3x-ui panel: `http://163.192.34.235:2053/mHdFe3WjFxXacirHi0/` (admin/admin)
  - Subscription URL: `http://163.192.34.235:2096/sub/55litne3iods7ein`
  - Reality target/SNI: yahoo.com
  - Fingerprint: chrome
  - Flow: xtls-rprx-vision
  - VCN Security List open ports: 22, 443, 2053, 2096

## How to change the disguise target

If the current SNI target (yahoo.com) gets blocked:

1. SSH into the server
2. Open the 3x-ui panel in your browser
3. Go to **Inbounds** > click the **edit** (pencil) icon on the inbound
4. Change **Target** to `newsite.com:443` and **SNI** to `newsite.com`
5. Save and restart XRay
6. The family's app auto-updates via subscription — no action needed on their end

Good target sites: major sites Russia can't afford to block (see `configs/sni-whitelist.txt`). The target must support TLS 1.3 and NOT be behind a CDN.

## How to add a new user

1. Open the 3x-ui panel
2. Go to **Inbounds** > expand the inbound > click **+** (add client)
3. Set **Flow** to `xtls-rprx-vision`
4. Save
5. Click the QR/info icon to get their VLESS link or subscription URL

## How to rotate a blocked server

If the server IP gets blocked:

1. Spin up a new Oracle Cloud instance (or other provider)
2. Run `sudo bash scripts/setup-server.sh` on it
3. Configure VLESS+Reality via the 3x-ui panel (same steps as initial setup)
4. Send the new VLESS link or subscription URL to the family
5. Terminate the old instance

## Protocol requirements (Russia-specific)

- SNI domain MUST be a major site Russia can't block (see `configs/sni-whitelist.txt`)
- Flow MUST be `xtls-rprx-vision` (avoids TLS-in-TLS detection)
- Fingerprint should be `chrome` or `firefox`
- Target site must support TLS 1.3, must NOT be behind a CDN
- Hetzner IPs are being throttled from Russia — prefer Oracle Cloud, BuyVM, Scaleway
- Port 443 is mandatory (blends with HTTPS traffic)

## Oracle Cloud notes

- Free tier accounts are locked to their home region
- TWO firewalls: iptables on the instance AND VCN Security List in the console — both must allow traffic
- The setup script flushes Oracle's default restrictive iptables and persists the rules
- To open ports in VCN: Hamburger menu > Networking > Virtual Cloud Networks > your VCN > Subnets > your subnet > Security Lists > Default Security List > Add Ingress Rules
- ARM instances (A1.Flex) are often out of capacity — AMD E2.1.Micro (1GB RAM) works fine for XRay

## Client setup (for the family)

1. Install **v2RayTun** and **Hiddify** from the App Store / Play Store (both platforms)
2. Send them the VLESS link via email (mail.ru/yandex — whitelisted in Russia)
3. They copy the link, open v2RayTun, tap **+**, tap **Import config from clipboard**
4. Connect — all traffic now goes through the VPN

## Repo conventions

- Scripts go in `scripts/`, shared functions in `scripts/lib/`
- Generated output (QR codes, client configs) goes in `output/` (gitignored)
- Live server data goes in `configs/servers.txt` (gitignored)
- Subscription files go in `subscription/` (active.txt is gitignored)
