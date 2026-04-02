# Server Health Monitor

Checks all Fortochka servers and sends Telegram alerts when one goes down or comes back up. Only alerts on state changes — no spam.

## Setup

1. Copy config files:
   ```bash
   cp monitor/servers.conf.example monitor/servers.conf
   cp monitor/.env.example monitor/.env
   ```

2. Fill in `servers.conf` with your server IPs

3. Create a Telegram bot (for alerts):
   - Message **@BotFather** on Telegram
   - Send `/newbot`, follow the prompts
   - Copy the bot token into `monitor/.env`
   - Message your new bot, then visit `https://api.telegram.org/bot<TOKEN>/getUpdates` to get your chat_id
   - Add the chat_id to `monitor/.env`

4. Test it:
   ```bash
   bash monitor/check-servers.sh
   ```

5. Add to cron (check every 5 minutes):
   ```bash
   crontab -e
   # Add this line:
   */5 * * * * /opt/ns.s-fortochka/monitor/check-servers.sh >> /var/log/fortochka-monitor.log 2>&1
   ```

## How it works

- Checks TCP connectivity on port 443
- Checks TLS handshake with the configured SNI domain
- Compares current state with previous state
- Only sends Telegram alert when something **changes** (goes down or comes back up)
- Exits with code 1 if any server is down

## Where to run it

Run this from a machine that is NOT one of the monitored servers — your home machine, a separate VPS, or any always-on computer. If you run it on one of the Fortochka servers and that server goes down, the monitor goes down with it.
