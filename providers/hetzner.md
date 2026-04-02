# Hetzner

Closest to Russia but IPs are actively targeted.

## Quick deploy

1. Sign up at [console.hetzner.cloud](https://console.hetzner.cloud)
2. New Project > Add Server
3. Location: **Helsinki** (closest to Moscow) or **Falkenstein**
4. Image: Ubuntu 24.04
5. Type: CX22 (€3.29/mo, 2 vCPU, 4GB RAM)
6. SSH key: add yours
7. Create

## Post-creation

```bash
# SSH in
ssh root@NEW_IP

# Clone and setup
cd /opt
git clone https://github.com/noshit-software/ns.s-fortochka.git
cd ns.s-fortochka
bash scripts/setup-server.sh
```

Then configure VLESS+Reality via the 3x-ui panel.

## WARNING

Hetzner IP ranges (especially Helsinki and Falkenstein) are **actively throttled** by Russian DPI. TSPU equipment specifically targets known Hetzner ASNs. Use as a last resort or test first before relying on it.

If a Hetzner server works from Russia, it could stop working at any time without notice.
