# Android Setup — v2rayNG

## 1. Install v2rayNG

**Option A — Google Play Store:**
Search for **v2rayNG** and install it.

**Option B — Direct download (if Play Store is blocked):**
Download the APK from the v2rayNG GitHub releases page. You'll need to allow "Install from unknown sources" in your phone settings when prompted.

**Do this NOW** even if the VPN server isn't ready yet.

## 2. Add the server (QR code method)

1. Open **v2rayNG**
2. Tap the **+** button (bottom right)
3. Choose **Import config from QRcode**
4. Scan the QR code you received

## 3. Add the server (link method)

If you received a text link instead of a QR code:

1. **Copy the link** (it starts with `vless://`)
2. Open **v2rayNG**
3. Tap the **+** button (bottom right)
4. Choose **Import config from clipboard**

## 4. Add subscription URL (recommended)

A subscription URL means the app automatically updates when servers change. You only do this once.

1. Open **v2rayNG**
2. Tap the **three dots** menu (top right)
3. Choose **Subscription group settings**
4. Tap **+** to add
5. Give it a name (anything you want)
6. Paste the subscription URL
7. Save, then go back and tap **Update subscription**

## 5. Connect

1. In v2rayNG, tap the server name to select it (it should have a checkmark)
2. Tap the **V** button at the bottom to connect
3. Allow the VPN permission when Android asks
4. A key icon appears in the status bar when connected

## 6. Verify it works

Visit any website that shows your IP address. It should show the VPN server's IP, not your home IP. If you can access sites that were blocked before, it's working.

## Troubleshooting

- **Can't connect?** Try a different server if you have multiple in the subscription.
- **"Connection timed out"?** The server may be blocked. Update your subscription (menu > Update subscription) to get the latest servers.
- **App was removed from Play Store?** Download the APK directly from GitHub. Search for "v2rayNG releases github" in your browser.
