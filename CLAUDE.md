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
- **Primary hosting**: Oracle Cloud Free Tier (ARM Ampere A1)
- **Client apps**: v2RayTun (iOS), v2rayNG (Android), Hiddify (backup)

## Key constraints

- End users (family) are non-technical — everything on their side must be dead simple
- No Terraform, no Ansible, no Docker — just shell scripts a developer can read and run
- Never commit real keys, UUIDs, server IPs, or .env files
- Config templates use `__PLACEHOLDER__` syntax for substitution
- All scripts source `scripts/lib/common.sh` for shared functions

## Protocol requirements (Russia-specific)

- SNI domain MUST be from the Russian whitelist (see `configs/sni-whitelist.txt`)
- Flow MUST be `xtls-rprx-vision` (avoids TLS-in-TLS detection)
- Fingerprint should be `chrome` or `firefox`
- Hetzner IPs are being throttled from Russia — prefer Oracle Cloud, BuyVM, Scaleway
- Port 443 is mandatory (blends with HTTPS traffic)

## Repo conventions

- Scripts go in `scripts/`, shared functions in `scripts/lib/`
- Config templates go in `configs/`
- Generated output (QR codes, client configs) goes in `output/` (gitignored)
- Live server data goes in `configs/servers.txt` (gitignored)
- Subscription files go in `subscription/` (active.txt is gitignored)
