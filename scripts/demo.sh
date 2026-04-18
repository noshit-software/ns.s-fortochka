#!/usr/bin/env bash
# demo.sh — Live SNI rotation demo.
#
# Shows the full pipeline:
#   1. VLESS connection working through Oracle SJC (exit IP visible from Moscow)
#   2. Forced SNI rotation: Oracle XRay restarts with new disguise
#   3. Client reconnects with new SNI — connection recovers
#
# Run from the operator's machine (needs SSH keys for both Oracle and RUVDS):
#   bash scripts/demo.sh [new_sni]
#
# Default rotation target: vk.com (always passes Russian DPI)

set -euo pipefail

ORACLE_HOST="163.192.34.235"
ORACLE_USER="ubuntu"
ORACLE_KEY="$HOME/.ssh/fortochka.key"
MSK_HOST="fortochka-msk"

NEW_SNI="${1:-vk.com}"

oracle() { ssh -i "$ORACLE_KEY" -o StrictHostKeyChecking=no "${ORACLE_USER}@${ORACLE_HOST}" "$@"; }
msk()    { ssh "$MSK_HOST" "$@"; }

log() { echo ""; echo "  >>> $1"; echo ""; }

# ── 1. Ensure xray is running on RUVDS ──────────────────────────────────────
log "Checking xray client on Moscow box..."
msk "pgrep -x xray > /dev/null && echo 'xray already running (PID: '$(pgrep -x xray)')' || { nohup xray run -c /root/xray-client.json >> /root/xray-client.log 2>&1 & sleep 2; pgrep -x xray > /dev/null && echo 'xray started' || echo 'ERROR: xray failed'; }"

# ── 2. Verify current SNI on Oracle ─────────────────────────────────────────
CURRENT_SNI=$(oracle "sudo sqlite3 /etc/x-ui/x-ui.db 'SELECT json_extract(stream_settings, \"$.realitySettings.serverNames[0]\") FROM inbounds WHERE id=1;'")
log "Oracle SNI: $CURRENT_SNI → rotating to: $NEW_SNI"

if [[ "$CURRENT_SNI" == "$NEW_SNI" ]]; then
  echo "  [warn] New SNI is same as current. Pick a different target."
  echo "  Candidates:"
  msk "head -10 /root/working-snis.txt"
  exit 1
fi

# ── 3. Start monitor on RUVDS in background (streams to this terminal) ───────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  LIVE MONITOR (Moscow → Oracle SJC via VLESS+Reality)"
echo "  SNI: $CURRENT_SNI"
echo "  Forcing rotation to [$NEW_SNI] in 15 seconds..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Run monitor in background, pipe to local terminal
msk "bash /root/monitor.sh" &
MONITOR_PID=$!

# ── 4. Wait, then rotate ─────────────────────────────────────────────────────
sleep 15

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ROTATING: $CURRENT_SNI → $NEW_SNI"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Update Oracle panel via SQLite, restart XRay there
oracle "sudo bash /root/rotate-sni.sh $NEW_SNI"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Oracle XRay restarted with SNI: $NEW_SNI"
echo "  Updating Moscow client config..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Update RUVDS xray client config + restart
msk "bash /root/update-client-sni.sh $NEW_SNI"

# Also tell the Worker KV
SCAN_SECRET=$(cat /d/ns.s/ns.s-fortochka/.scan_secret 2>/dev/null || echo "")
if [[ -n "$SCAN_SECRET" ]]; then
  HTTP=$(curl -s -w "%{http_code}" -o /dev/null -X POST \
    "https://fortochka-radio-api.robertgardunia.workers.dev/api/set-sni" \
    -H "Content-Type: application/json" \
    -H "X-Scan-Secret: $SCAN_SECRET" \
    -d "{\"server_id\":\"oracle-sanjose\",\"sni\":\"$NEW_SNI\"}" \
    --max-time 10)
  echo "  Worker KV updated: HTTP $HTTP"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  WATCHING RECOVERY (next 30 seconds)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sleep 30

kill $MONITOR_PID 2>/dev/null || true
wait $MONITOR_PID 2>/dev/null || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DONE. Rotation: $CURRENT_SNI → $NEW_SNI"
echo "  Check /root/check.log on Moscow for the health checker view."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
