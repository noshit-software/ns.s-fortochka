# Oracle Cloud Free Tier

## Quick deploy

Already running. See CLAUDE.md for connection details.

## New instance (if current one gets blocked)

1. Log into [cloud.oracle.com](https://cloud.oracle.com)
2. Compute > Instances > Create Instance
3. Image: Ubuntu 24.04
4. Shape: VM.Standard.E2.1.Micro (AMD, 1GB RAM, Always Free)
5. Networking: Create new VCN, ensure public IPv4 is assigned
6. SSH key: generate and download both keys
7. Create

## Post-creation

```bash
# Open ports in VCN Security List:
# Hamburger menu > Networking > Virtual Cloud Networks > your VCN
# > Subnets > your subnet > Security Lists > Add Ingress Rules
# Ports: 443 (TCP), 2053 (TCP), 2096 (TCP)

# SSH in
ssh -i ~/.ssh/your-key.key ubuntu@NEW_IP

# Clone and setup
cd /opt
sudo git clone https://github.com/noshit-software/ns.s-fortochka.git
cd ns.s-fortochka
sudo bash scripts/setup-server.sh
```

Then configure VLESS+Reality via the 3x-ui panel.

## Limitations

- Free tier locked to home region (can't change after signup)
- ARM instances frequently out of capacity
- Two-layer firewall (iptables + VCN Security List)
