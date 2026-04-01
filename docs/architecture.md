# How Fortochka Works

## The problem

Russia runs deep packet inspection (DPI) equipment called TSPU on every ISP. This equipment analyzes internet traffic in real time and blocks connections that look like VPN traffic. As of 2026, it successfully blocks OpenVPN, WireGuard, Shadowsocks, Trojan, and VMess protocols.

## The solution: VLESS + Reality

VLESS+Reality is a proxy protocol that makes your traffic **indistinguishable from a normal HTTPS connection** to a legitimate website.

### How it works, step by step

1. **Your phone** connects to the Fortochka server on port 443 (the normal HTTPS port)

2. **The DPI system** inspects the connection and sees what looks like a standard TLS 1.3 handshake to `microsoft.com` (or whatever SNI domain is configured). It allows the connection.

3. **The Fortochka server** uses the Reality protocol to perform a special handshake that looks identical to a real TLS connection from the outside. Only clients with the correct private key can complete the handshake — to everyone else (including the DPI), it looks like a normal website visit.

4. **Once connected**, your internet traffic travels through the encrypted tunnel. You can browse freely, use messaging apps, and access any website.

### Key components

| Component | What it does |
|-----------|-------------|
| **VLESS** | Lightweight proxy protocol — carries your traffic |
| **Reality** | Makes the connection look like real HTTPS to a real website |
| **XTLS-Vision** | Prevents "TLS inside TLS" detection — a telltale sign of proxied traffic |
| **SNI domain** | The "cover story" website (e.g., microsoft.com) — what the DPI thinks you're visiting |
| **XRay** | The server software that implements all of the above |
| **3x-ui** | Web-based management panel for XRay |

### Why port 443?

Port 443 is the standard HTTPS port. Every website uses it. Blocking port 443 would break the entire internet, so the DPI must allow traffic on this port and rely on content inspection instead. VLESS+Reality passes that inspection.

### Why the SNI domain matters

When your browser connects to a website over HTTPS, the first message includes the website's name in plain text (the Server Name Indication, or SNI). The DPI reads this. Reality sets the SNI to a major website like `microsoft.com` — a site Russia cannot afford to block. The DPI sees a connection to microsoft.com and lets it through.

## The subscription model

Instead of manually configuring each phone with server details, Fortochka uses a **subscription URL**:

1. The server operator maintains a list of active servers
2. A script generates a subscription file and hosts it on GitHub
3. The phone app is configured with the subscription URL
4. When servers change (blocked, rotated, added), the operator updates the subscription
5. The phone app automatically pulls the new config — no action needed from the user

This means the family never needs to reconfigure their phones. If a server gets blocked, the operator adds a new one and updates the subscription. The phones just work.

## Layered defense

Fortochka is designed with multiple independent layers:

- **Layer 1: VLESS+Reality VPN** — full internet access (primary)
- **Layer 2: Communication channels** — landline calls, SMS, Russian email (works without internet)
- **Layer 3: News access** — shortwave radio for international broadcasts (works without any infrastructure)

Each layer works independently. If the VPN is blocked, voice calls still work. If the internet is completely shut down, shortwave radio still works. No single point of failure.
