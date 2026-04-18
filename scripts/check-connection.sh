#!/usr/bin/env bash
# check-connection.sh — Detect SNI block and rotate directly from Russia
#
# Runs every 3 minutes on the RUVDS Moscow box via cron.
# When it detects the current SNI is blocked by Russian DPI:
#   1. Picks a random new SNI from the local candidates list
#   2. Updates the 3x-ui panel directly (port 2053 is reachable from here)
#   3. Notifies the Worker via /api/set-sni so subscription URLs update immediately
#
# The Worker cannot touch the panel (Cloudflare blocks outbound to port 2053).
# This box is the only thing that can do it.
#
# Cron:
#   */3 * * * * bash /root/check-connection.sh >> /root/check.log 2>&1

set -euo pipefail

SERVER_IP="163.192.34.235"
SERVER_PORT=443
SERVER_ID="oracle-sanjose"
PANEL_URL="http://163.192.34.235:2053/mHdFe3WjFxXacirHi0"
PANEL_USER="admin"
PANEL_PASS="admin"
WORKER_URL="https://fortochka-radio-api.robertgardunia.workers.dev"
SCAN_SECRET=$(cat /root/.scan_secret)
CANDIDATES_FILE="/root/working-snis.txt"
TIMEOUT=8

log() { echo "$(date -u +%H:%M:%S) $1"; }

# Get current SNI from Worker KV
get_current_sni() {
  curl -s "${WORKER_URL}/api/status" --max-time 10 2>/dev/null \
    | python3 -c "
import sys, json
try:
  for s in json.load(sys.stdin).get('servers', []):
    if s.get('id') == '${SERVER_ID}':
      print(s.get('sni', ''))
      break
except: pass
" 2>/dev/null || echo ""
}

# Pick a random SNI from candidates, excluding current
pick_new_sni() {
  local current="$1"
  if [[ ! -f "$CANDIDATES_FILE" ]]; then
    echo ""
    return
  fi
  # Filter out current, pick random line
  python3 -c "
import random, sys
lines = [l.strip() for l in open('${CANDIDATES_FILE}') if l.strip() and l.strip() != '${current}']
if lines: print(random.choice(lines))
" 2>/dev/null || echo ""
}

# Update 3x-ui panel with new SNI
update_panel() {
  local new_sni="$1"

  # Login
  cookie=$(curl -s -c - -X POST "${PANEL_URL}/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${PANEL_USER}\",\"password\":\"${PANEL_PASS}\"}" \
    --max-time 10 2>/dev/null \
    | python3 -c "
import sys, json
try:
  lines = sys.stdin.read().strip().split('\n')
  for line in lines:
    if '3x-ui' in line:
      parts = line.split()
      if len(parts) >= 2: print('3x-ui=' + parts[-1]); break
except: pass
" 2>/dev/null || echo "")

  if [[ -z "$cookie" ]]; then
    log "ERROR: Panel login failed"
    return 1
  fi

  # Get inbounds
  inbound_json=$(curl -s "${PANEL_URL}/xui/inbound/list" \
    -H "Cookie: ${cookie}" --max-time 10 2>/dev/null || echo "")

  if [[ -z "$inbound_json" ]]; then
    log "ERROR: Could not get inbounds"
    return 1
  fi

  # Update SNI via python
  python3 << PYEOF
import json, urllib.request, urllib.error

panel = "${PANEL_URL}"
cookie = "${cookie}"
new_sni = "${new_sni}"

data = json.loads('''${inbound_json}''')
inbounds = data.get("obj", [])
vless = next((ib for ib in inbounds if ib.get("protocol") == "vless" and ib.get("port") == 443), None)
if not vless:
    print("ERROR: No VLESS inbound on port 443")
    exit(1)

settings = json.loads(vless["streamSettings"])
settings["realitySettings"]["serverNames"] = [new_sni]
settings["realitySettings"]["dest"] = f"{new_sni}:443"
vless["streamSettings"] = json.dumps(settings)

req = urllib.request.Request(
    f"{panel}/xui/inbound/update/{vless['id']}",
    data=json.dumps(vless).encode(),
    headers={"Content-Type": "application/json", "Cookie": cookie},
    method="POST"
)
with urllib.request.urlopen(req, timeout=10) as r:
    result = json.loads(r.read())
    if result.get("success"):
        print("OK")
    else:
        print(f"ERROR: {result.get('msg')}")
        exit(1)

# Restart XRay
try:
    req2 = urllib.request.Request(f"{panel}/xui/inbound/restart", method="POST",
        headers={"Cookie": cookie})
    urllib.request.urlopen(req2, timeout=10)
except: pass
PYEOF
}

# Notify Worker KV of new SNI
notify_worker() {
  local new_sni="$1"
  result=$(curl -s -w "\n%{http_code}" -X POST "${WORKER_URL}/api/set-sni" \
    -H "Content-Type: application/json" \
    -H "X-Scan-Secret: ${SCAN_SECRET}" \
    -d "{\"server_id\":\"${SERVER_ID}\",\"sni\":\"${new_sni}\"}" \
    --max-time 15 2>/dev/null || echo -e "\nfailed")
  echo "$result" | tail -1
}

# ── Main ─────────────────────────────────────────────────────────────────────

current_sni=$(get_current_sni)
if [[ -z "$current_sni" ]]; then
  log "WARN: Could not get current SNI from Worker — skipping"
  exit 0
fi

# Test connection: route through Oracle IP using current SNI
# --insecure: skip cert check — only testing if DPI passes the connection
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
  log "OK — ${current_sni} (HTTP ${http_code})"
  exit 0
fi

# Blocked — pick new SNI and rotate
log "BLOCKED — ${current_sni} — rotating"

new_sni=$(pick_new_sni "$current_sni")
if [[ -z "$new_sni" ]]; then
  log "ERROR: No candidates available in ${CANDIDATES_FILE}"
  exit 1
fi

# Update panel
panel_result=$(update_panel "$new_sni")
if [[ "$panel_result" != "OK" ]]; then
  log "ERROR: Panel update failed — ${panel_result}"
  exit 1
fi
log "PANEL: ${current_sni} → ${new_sni}"

# Notify Worker
worker_status=$(notify_worker "$new_sni")
if [[ "$worker_status" == "200" ]]; then
  log "WORKER: KV updated — ${new_sni}"
else
  log "WARN: Worker KV update failed (HTTP ${worker_status}) — panel was updated"
fi

log "ROTATED: ${current_sni} → ${new_sni}"
