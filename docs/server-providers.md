# Server Providers

## Oracle Cloud Free Tier (Recommended)

Oracle Cloud offers an "Always Free" tier that includes ARM-based VPS instances at $0/month. This is not a trial — it's permanently free.

### Sign up

1. Go to [cloud.oracle.com](https://cloud.oracle.com)
2. Click **Sign Up**
3. You'll need a credit card for verification (you won't be charged for Always Free resources)
4. Set your **home region** to wherever you are (this is for your account — doesn't matter for the VPN server)

### Create a VPS instance

1. After signing in, go to **Compute > Instances > Create Instance**
2. Name: anything (e.g., `fortochka-fra`)
3. **Placement**: Change to **Frankfurt** (eu-frankfurt-1) or **Amsterdam** — these are closest to Russia
4. **Image**: Ubuntu 24.04
5. **Shape**: Change to **Ampere** (ARM) — select **VM.Standard.A1.Flex**
   - 1 OCPU and 6 GB RAM is plenty (stays within free tier)
6. **Networking**: Use default VCN or create a new one
7. **SSH Key**: Upload your public SSH key (or let Oracle generate one — download the private key!)
8. Click **Create**

### Open ports (critical!)

Oracle Cloud has TWO firewalls. You must open ports in BOTH:

**1. VCN Security List:**
1. Go to **Networking > Virtual Cloud Networks**
2. Click your VCN
3. Click **Security Lists** > **Default Security List**
4. **Add Ingress Rules**:
   - Source: `0.0.0.0/0`, Protocol: TCP, Destination Port: `443`
   - Source: `0.0.0.0/0`, Protocol: TCP, Destination Port: `YOUR_WS_PORT`
   - Source: `0.0.0.0/0`, Protocol: TCP, Destination Port: `YOUR_PANEL_PORT`

**2. Instance firewall (iptables/ufw):**
The setup script handles this automatically.

### SSH into your instance

```bash
ssh -i your-private-key.pem ubuntu@YOUR_INSTANCE_IP
```

Then follow the Quick Start in the main README.

## Why not Hetzner?

Hetzner is cheap and reliable, but their IP ranges (especially Helsinki and Falkenstein) are actively throttled from Russia. TSPU (DPI equipment) targets known datacenter IP ranges, and Hetzner is one of the most blocked.

If you already have a Hetzner VPS, it's worth testing — it may still work depending on the specific IP. But for new servers, Oracle Cloud is a better bet because:
- Oracle IPs are associated with enterprise workloads, not VPN hosting
- Less targeted by Russian DPI
- Free

## Alternatives

If Oracle Cloud doesn't work or you want additional servers on different providers:

- **BuyVM** — cheap, less-targeted IPs, Luxembourg location available
- **Scaleway** — French provider, Paris/Amsterdam locations
- **Linode/Akamai** — Frankfurt location available
- **Vultr** — multiple European locations

The key is: **different providers = different IP ranges = harder to block all at once.**
