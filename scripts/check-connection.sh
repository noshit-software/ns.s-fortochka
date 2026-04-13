#!/usr/bin/env bash
# check-connection.sh — Test if current SNI still passes Russian DPI
#
# Run every 3 minutes from the RUVDS Moscow box via cron.
# If the current SNI is blocked, triggers the Worker to rotate immediately.
# The Worker picks a new SNI from the KV candidate list and applies it to
# the 3x-ui panel. The client app picks it up on its next subscription refresh.
#
# Cron setup:
#   */3 * * * * bash /root/check-connection.sh >> /root/check.log 2>&1
#
# Dependencies: curl, python3

set -euo pipefail

SERVER_IP="163.192.34.235"
SERVER_PORT=443
WORKER_URL="https://fortochka-radio-api.robertgardunia.workers.dev"
SCAN_SECRET_FILE="/root/.scan_secret"
TIMEOUT=8

if [[ ! -f "$SCAN_SECRET_FILE" ]]; then
  echo "$(date -u +%H:%M:%S): ERROR — no secret at $SCAN_SECRET_FILE"
  exit 1
fi
SCAN_SECRET=$(cat "$SCAN_SECRET_FILE")

# Get current SNI from Worker
current_sni=$(curl -s "${WORKER_URL}/api/status" --max-time 10 2>/dev/null \
  | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for s in data.get('servers', []):
        if s.get('id') == 'oracle-sanjose':
            print(s.get('sni', ''))
            break
except: pass
" 2>/dev/null || echo "")

if [[ -z "$current_sni" ]]; then
  echo "$(date -u +%H:%M:%S): WARN — could not get current SNI from Worker, skipping"
  exit 0
fi

# Test: connect to Oracle IP but present current SNI.
# --insecure: skip cert check — we only care whether DPI passes the connection.
# Timeout = DPI silently dropped it. Any response = DPI let it through.
http_code=$(curl \
  --connect-to "${current_sni}:${SERVER_PORT}:${SERVER_IP}:${SERVER_PORT}" \
  "https://${current_sni}/" \
  --insecure \
  --max-time "$TIMEOUT" \
  --silent \
  --write-out "%{http_code}" \
  --output /dev/null \
  2>/dev/null || echo "000")

if [[ "$http_code" != "000" ]]; then
  echo "$(date -u +%H:%M:%S): OK — $current_sni (HTTP $http_code)"
  exit 0
fi

# Blocked — trigger rotation
echo "$(date -u +%H:%M:%S): BLOCKED — $current_sni — triggering rotation"

response=$(curl -s -w "\n%{http_code}" \
  -X POST "${WORKER_URL}/api/rotate-now" \
  -H "Content-Type: application/json" \
  -H "X-Scan-Secret: ${SCAN_SECRET}" \
  -d "{\"server_id\":\"oracle-sanjose\"}" \
  --max-time 15 \
  2>/dev/null || echo -e "\nfailed")

http_status=$(echo "$response" | tail -1)
body=$(echo "$response" | head -1)

if [[ "$http_status" == "200" ]]; then
  new_sni=$(python3 -c "import sys,json; d=json.loads('${body}'); print(d.get('newSni','?'))" 2>/dev/null || echo "?")
  echo "$(date -u +%H:%M:%S): ROTATED — $current_sni → $new_sni"
else
  echo "$(date -u +%H:%M:%S): ROTATION FAILED — HTTP $http_status — $body"
fi
