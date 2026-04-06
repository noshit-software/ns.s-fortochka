# Fortochka — Quick Reference

## SSH

```bash
ssh -i ~/.ssh/fortochka.key ubuntu@163.192.34.235
```

## 3x-ui Panel

- URL: `http://163.192.34.235:2053/mHdFe3WjFxXacirHi0/`
- Login: `admin` / `admin` (CHANGE THIS)

## Subscription URLs

Worker subscription (preferred — auto-updates after SNI rotation):
```
https://fortochka-radio-api.robertgardunia.workers.dev/api/sub
```

3x-ui panel subscription (fallback — direct from server):
```
http://163.192.34.235:2096/sub/55litne3iods7ein
```

To use in Alice VPN: Settings → Add server → Subscription URL → paste Worker URL above.

## VLESS Link (current)

Get the latest from the panel: Inbounds > expand > info icon (i) on "family" client

## Fortochka Radio

- Frontend: `https://fortochka-radio.pages.dev`
- Worker API: `https://fortochka-radio-api.robertgardunia.workers.dev/api/status`

## Oracle Cloud Console

- Login: `https://cloud.oracle.com`
- VCN Security List path: Hamburger menu > Networking > Virtual Cloud Networks > vcn-20260331-1954 > Subnets > subnet > Security Lists > Default Security List > Add Ingress Rules
- Open ports: 22, 443, 2053, 2096

## Fix: websites fail, WhatsApp works

Cause: sniffing disabled on the VLESS inbound. XRay can't resolve domain names for clients.

Fix:
1. Open the panel
2. Inbounds > edit (pencil) > scroll to **Sniffing** > toggle ON
3. Check HTTP, TLS, QUIC
4. Save > restart XRay

## Server Management

```bash
# Restart 3x-ui + XRay
sudo x-ui restart

# Check if XRay is listening
sudo ss -tlnp | grep 443

# Check iptables (should be all ACCEPT)
sudo iptables -L -n

# Flush iptables if Oracle defaults come back
sudo iptables -F && sudo iptables -P INPUT ACCEPT && sudo iptables -P FORWARD ACCEPT && sudo iptables -P OUTPUT ACCEPT
sudo iptables-save | sudo tee /etc/iptables/rules.v4

# View XRay access log
sudo cat /usr/local/x-ui/access.log | grep -v api | tail -20

# Watch live traffic
sudo tail -f /usr/local/x-ui/access.log | grep -v api
```

## Deploy Radio Updates

```bash
# Worker (API)
cd d:/ns.s/ns.s-fortochka/radio/worker
npx wrangler deploy

# Frontend
cd d:/ns.s/ns.s-fortochka/radio/site
npx wrangler pages deploy . --project-name fortochka-radio --commit-dirty=true
```

## SNI Whitelist (working from Russia)

Russian domains (mobile whitelist):
- `ya.ru` — Yandex
- `cloud.mail.ru` — Mail.ru
- `rbc.ru` — Russian business news
- `dzen.ru` — Yandex Zen
- `vkvideo.ru` — VK Video

Source: github.com/igareck/vpn-configs-for-russia
