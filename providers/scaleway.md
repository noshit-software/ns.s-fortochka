# Scaleway

Best balance of price, proximity to Russia, and IP reputation.

## Quick deploy

1. Sign up at [console.scaleway.com](https://console.scaleway.com)
2. Go to **Instances > Create Instance**
3. Choose region:
   - **Paris** (PAR1) — Western Europe
   - **Warsaw** (WAW2) — closest to Moscow, best latency
   - **Amsterdam** (AMS1) — good alternative
4. Choose type: **STARDUST1-S** (~€1.99/mo) or **DEV1-S** (~€3/mo)
   - Stardust: 1 vCPU, 1GB RAM — sufficient for XRay
5. Image: Ubuntu 24.04
6. Add your SSH key (or generate one)
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

## Notes

- No extra firewall layers — standard iptables only
- Scaleway IPs are French enterprise hosting — less targeted by Russian DPI
- Warsaw is ~1200km from Moscow — expect 20-30ms latency
- Root access by default (no `sudo` needed)
