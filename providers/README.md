# Provider Deploy Guides

Quick-deploy instructions for each provider. All follow the same pattern:

1. Create a VPS instance (provider-specific)
2. SSH in
3. Run `sudo bash scripts/setup-server.sh`
4. Configure VLESS+Reality via the 3x-ui panel
5. Add the new server's subscription URL to the family's app

## Active providers

| Provider | Region | Cost | Status |
|----------|--------|------|--------|
| Oracle Cloud | San Jose | Free | Running |
| Scaleway | Paris | ~$2/mo | Scaffolded |
| Scaleway | Warsaw | ~$2/mo | Scaffolded |

## Reserve providers (deploy if needed)

| Provider | Region | Cost | Notes |
|----------|--------|------|-------|
| BuyVM | Luxembourg | $2/mo | 512MB, less-targeted IPs |
| Vultr | Frankfurt | $5/mo | Closest to Moscow after Warsaw |
| Vultr | Stockholm | $5/mo | Nordic routing to Russia |
| RackNerd | Los Angeles | $1.50/mo | Budget option, far from Russia |
| Hetzner | Helsinki | €3.29/mo | Closest to Russia but IPs are targeted |
