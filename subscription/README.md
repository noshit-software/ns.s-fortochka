# Subscription Hosting

The subscription URL is how family members' phones automatically get updated server configs.

## Built-in subscription (recommended)

3x-ui has a built-in subscription server. No external hosting needed.

1. In the 3x-ui panel, go to **Panel Settings > Subscription** — it should already be enabled on port 2096.
2. Expand any inbound, click the info icon on a client, and copy the **Subscription URL**.
3. Send that URL to the family. They paste it into v2RayTun's subscription settings once.
4. When you add or change servers in the panel, the subscription updates automatically.

Make sure port 2096 is open in both iptables and the Oracle Cloud VCN Security List.

## GitHub Gist subscription (alternative)

If you want to host the subscription externally (e.g., in case the server itself goes down), `publish-gist.sh` uploads the subscription to a secret GitHub Gist. This requires the `gh` CLI and `configs/servers.txt`.

## When a server gets blocked

1. Add a new server (new VPS, run `setup-server.sh`, configure via panel)
2. The new server's subscription URL is independent
3. If using the built-in subscription, clients auto-update
4. If using Gist, update `configs/servers.txt` and run `generate-subscription.sh` + `publish-gist.sh`

## Privacy

- The subscription URL contains server IPs and public keys — treat it as sensitive
- Do not share it on public channels
- Anyone with the URL can use your servers
