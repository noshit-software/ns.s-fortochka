#!/usr/bin/env bash
# Fortochka — Server health monitor with Telegram alerts
#
# Checks all servers listed in monitor/servers.conf for:
#   1. TCP connectivity on port 443
#   2. TLS handshake (verifies XRay/Reality is responding)
#
# Sends a Telegram message if any server goes down.
#
# Usage:
#   bash monitor/check-servers.sh                # Run once
#   crontab: */5 * * * * /path/to/check-servers.sh   # Every 5 minutes
#
# Setup:
#   1. Copy monitor/servers.conf.example to monitor/servers.conf
#   2. Copy monitor/.env.example to monitor/.env
#   3. Fill in your Telegram bot token and chat ID

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVERS_FILE="$SCRIPT_DIR/servers.conf"
ENV_FILE="$SCRIPT_DIR/.env"
STATE_FILE="$SCRIPT_DIR/.last-state"

# ─── Load config ─────────────────────────────────────────────────────────────

if [[ ! -f "$SERVERS_FILE" ]]; then
    echo "ERROR: No servers.conf found. Copy servers.conf.example and fill in."
    exit 1
fi

TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
fi

# ─── Check each server ──────────────────────────────────────────────────────

RESULTS=""
ANY_DOWN=false
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M UTC")

while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue

    read -r name ip port sni <<< "$line"
    [[ -z "$ip" || -z "$port" ]] && continue

    name="${name:-$ip}"
    sni="${sni:-yahoo.com}"
    status="OK"

    # TCP check
    if ! timeout 10 bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null; then
        status="DOWN"
        ANY_DOWN=true
    else
        # TLS check
        if command -v openssl &>/dev/null; then
            if ! echo | timeout 10 openssl s_client -connect "$ip:$port" -servername "$sni" 2>/dev/null | grep -q "CONNECTED"; then
                status="TLS_FAIL"
                ANY_DOWN=true
            fi
        fi
    fi

    RESULTS="${RESULTS}${name} (${ip}): ${status}\n"
done < "$SERVERS_FILE"

# ─── Compare with last state ────────────────────────────────────────────────

CURRENT_STATE=$(echo -e "$RESULTS" | sort)
PREVIOUS_STATE=""
if [[ -f "$STATE_FILE" ]]; then
    PREVIOUS_STATE=$(cat "$STATE_FILE")
fi

echo "$CURRENT_STATE" > "$STATE_FILE"

# Only alert if state changed (avoid spam)
STATE_CHANGED=false
if [[ "$CURRENT_STATE" != "$PREVIOUS_STATE" ]]; then
    STATE_CHANGED=true
fi

# ─── Output ──────────────────────────────────────────────────────────────────

echo "$TIMESTAMP"
echo -e "$RESULTS"

# ─── Telegram alert ──────────────────────────────────────────────────────────

if [[ "$ANY_DOWN" == true && "$STATE_CHANGED" == true ]]; then
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        MESSAGE="⚠️ Fortochka server alert — $TIMESTAMP

$(echo -e "$RESULTS")"

        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$MESSAGE" \
            -d parse_mode="HTML" >/dev/null 2>&1 || true
    fi
fi

# Also alert when a server comes back up
if [[ "$ANY_DOWN" == false && "$STATE_CHANGED" == true && -n "$PREVIOUS_STATE" ]]; then
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        MESSAGE="✅ Fortochka — all servers OK — $TIMESTAMP

$(echo -e "$RESULTS")"

        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$MESSAGE" \
            -d parse_mode="HTML" >/dev/null 2>&1 || true
    fi
fi

if [[ "$ANY_DOWN" == true ]]; then
    exit 1
fi
exit 0
