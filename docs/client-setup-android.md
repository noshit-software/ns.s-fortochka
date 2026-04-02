# Android Setup — v2RayTun

## 1. Install v2RayTun and Hiddify

Open the Play Store and search for **v2RayTun**. Install it. Then search for **Hiddify** and install that too as a backup.

If the Play Store doesn't have them, you can sideload APKs on Android — download directly from the developer's GitHub releases page. You'll need to allow "Install from unknown sources" in your phone settings when prompted.

**Do this NOW** even if the VPN server isn't ready yet.

## 2. Add the server (QR code method)

1. Open **v2RayTun**
2. Tap the **+** button
3. Choose **Import config from QRcode**
4. Scan the QR code you received

## 3. Add the server (link method)

If you received a text link instead of a QR code:

1. **Copy the link** (it starts with `vless://`)
2. Open **v2RayTun**
3. Tap the **+** button
4. Choose **Import config from clipboard**

## 4. Add subscription URL (recommended)

A subscription URL means the app automatically updates when servers change. You only do this once.

1. Open **v2RayTun**
2. Go to settings, find **Subscription**
3. Add the subscription URL you received
4. Save and update

## 5. Connect

1. In v2RayTun, tap the server name to select it
2. Tap the connect button
3. Allow the VPN permission when Android asks
4. A key icon appears in the status bar when connected

## 6. Verify it works

Visit any website that shows your IP address. It should show the VPN server's IP, not your home IP. If you can access sites that were blocked before, it's working.

## Troubleshooting

- **Can't connect?** Try a different server if you have multiple in the subscription.
- **"Connection timed out"?** The server may be blocked. Update your subscription (menu > Update subscription) to get the latest servers.
- **App was removed from Play Store?** Download the APK directly from GitHub. Android allows sideloading — search for the app's GitHub releases page in your browser.
