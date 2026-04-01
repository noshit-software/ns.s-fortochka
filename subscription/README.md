# Subscription Hosting

The subscription URL is how family members' phones automatically get updated server configs.

## How it works

1. `generate-subscription.sh` reads `configs/servers.txt` and produces `subscription/active.txt` — a base64-encoded file containing VLESS share links for all active servers.

2. `publish-gist.sh` uploads `active.txt` to a secret GitHub Gist. The Gist's raw URL is the subscription URL.

3. On the phone, v2RayTun/v2rayNG is configured with this subscription URL. It periodically checks for updates and pulls new server configs automatically.

## When a server gets blocked

1. Run `scripts/rotate-server.sh` to deactivate the blocked server
2. Set up a new server with `scripts/setup-server.sh`
3. Add the new server to `configs/servers.txt`
4. Run `scripts/generate-subscription.sh` to rebuild the subscription
5. Run `subscription/publish-gist.sh` to publish the update

The family's phones will pick up the new config on their next refresh — no action needed on their end.

## Privacy

- The Gist is **secret** (not listed publicly), but anyone with the URL can access it
- The subscription file contains server IPs and public keys — treat the URL as sensitive
- Do not share the URL on public channels
