# Vultr

Multi-region from one account. Good for rapid deployment.

## Quick deploy

1. Sign up at [vultr.com](https://vultr.com)
2. Deploy New Server
3. Choose region:
   - **Frankfurt** — closest major city to Moscow via Vultr
   - **Stockholm** — Nordic routing to Russia
   - **Amsterdam** — good alternative
4. Server type: Cloud Compute (Regular Performance)
5. Plan: $5/month (1 CPU, 1GB RAM, 25GB SSD)
6. OS: Ubuntu 24.04
7. Add SSH key
8. Deploy

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

## Notes

- 20+ regions available from one account
- API available for automated provisioning
- Standard iptables, no extra firewall layers
- $5/month minimum (no cheaper tier)
