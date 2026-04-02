# BuyVM

Budget option with good IP reputation.

## Quick deploy

1. Go to [buyvm.net](https://buyvm.net)
2. Choose **KVM Slice** — $2/month (512MB RAM, 1 CPU, 10GB SSD)
3. Location: **Luxembourg** (closest to Russia)
4. OS: Ubuntu 24.04
5. Order and wait for provisioning email

## Post-creation

```bash
# SSH in (credentials in provisioning email)
ssh root@NEW_IP

# Clone and setup
cd /opt
git clone https://github.com/noshit-software/ns.s-fortochka.git
cd ns.s-fortochka
bash scripts/setup-server.sh
```

Then configure VLESS+Reality via the 3x-ui panel.

## Notes

- 512MB RAM is enough for XRay (uses ~50-100MB)
- BuyVM IPs are less commonly targeted by DPI
- Luxembourg has decent routing to Russia (~40-50ms)
- May need to open firewall ports manually if BuyVM has default rules
