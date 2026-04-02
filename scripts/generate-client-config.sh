#!/usr/bin/env bash
# Fortochka — Generate client config, VLESS share link, and QR code
#
# Usage:
#   bash generate-client-config.sh <IP> <PORT> <UUID> <PUBLIC_KEY> <SNI> <SHORT_ID> <NAME>
#
# Or with environment variables:
#   SERVER_IP=x.x.x.x CLIENT_UUID=... bash generate-client-config.sh
#
# Outputs:
#   - VLESS share link (printed to terminal)
#   - QR code (printed to terminal + saved as PNG)
#   - Client config JSON (saved to output/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Parse args or use env vars
SERVER_IP="${1:-${SERVER_IP:-}}"
SERVER_PORT="${2:-${SERVER_PORT:-443}}"
CLIENT_UUID="${3:-${CLIENT_UUID:-}}"
REALITY_PUBLIC_KEY="${4:-${REALITY_PUBLIC_KEY:-}}"
SNI_DOMAIN="${5:-${SNI_DOMAIN:-microsoft.com}}"
SHORT_ID="${6:-${SHORT_ID:-}}"
SERVER_NAME="${7:-${SERVER_NAME:-fortochka}}"

# Validate required fields
if [[ -z "$SERVER_IP" || -z "$CLIENT_UUID" || -z "$REALITY_PUBLIC_KEY" || -z "$SHORT_ID" ]]; then
    log_error "Missing required parameters."
    echo ""
    echo "Usage: $0 <IP> <PORT> <UUID> <PUBLIC_KEY> <SNI> <SHORT_ID> <NAME>"
    echo ""
    echo "Example:"
    echo "  $0 140.238.1.100 443 550e8400-... abc123key== microsoft.com deadbeef01 oracle-fra"
    exit 1
fi

# Build VLESS share link
VLESS_LINK="vless://${CLIENT_UUID}@${SERVER_IP}:${SERVER_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI_DOMAIN}&fp=chrome&pbk=${REALITY_PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#Fortochka-${SERVER_NAME}"

# Build client config JSON from template
PROJECT_ROOT=$(get_project_root)
CLIENT_TEMPLATE="$PROJECT_ROOT/configs/xray-client-template.json"

if [[ -f "$CLIENT_TEMPLATE" ]]; then
    CLIENT_CONFIG=$(cat "$CLIENT_TEMPLATE" \
        | sed "s|__SERVER_IP__|$SERVER_IP|g" \
        | sed "s|__CLIENT_UUID__|$CLIENT_UUID|g" \
        | sed "s|__SNI_DOMAIN__|$SNI_DOMAIN|g" \
        | sed "s|__REALITY_PUBLIC_KEY__|$REALITY_PUBLIC_KEY|g" \
        | sed "s|__SHORT_ID__|$SHORT_ID|g")
fi

# Output
mkdir -p "$PROJECT_ROOT/output"

# Save VLESS link
echo "$VLESS_LINK" > "$PROJECT_ROOT/output/${SERVER_NAME}-vless.txt"

# Save client config JSON
if [[ -n "${CLIENT_CONFIG:-}" ]]; then
    echo "$CLIENT_CONFIG" > "$PROJECT_ROOT/output/${SERVER_NAME}-client.json"
    log_info "Client config saved to output/${SERVER_NAME}-client.json"
fi

# Generate QR code
if command -v qrencode &>/dev/null; then
    echo "$VLESS_LINK" | qrencode -t PNG -o "$PROJECT_ROOT/output/${SERVER_NAME}-qr.png"
    log_info "QR code saved to output/${SERVER_NAME}-qr.png"

    echo ""
    log_step "QR Code for $SERVER_NAME"
    echo ""
    echo "$VLESS_LINK" | qrencode -t UTF8
    echo ""
else
    log_warn "qrencode not installed — skipping QR code generation"
    log_warn "Install with: apt install qrencode (Linux) or brew install qrencode (Mac)"
fi

echo ""
log_step "VLESS Share Link"
echo "$VLESS_LINK"
echo ""
log_info "Send this link or QR code to the phone. In v2RayTun:"
log_info "  Tap + > Import config from clipboard (or scan QR)"
