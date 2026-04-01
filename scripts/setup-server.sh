#!/usr/bin/env bash
# Fortochka — Server Setup Script
# Run this on a fresh Ubuntu 22.04/24.04 VPS to set up a VLESS+Reality VPN server.
#
# Usage:
#   sudo bash setup-server.sh              # Interactive (prompts for config)
#   sudo bash setup-server.sh --defaults   # Use all defaults / .env values
#
# Prerequisites:
#   - Fresh Ubuntu 22.04 or 24.04 VPS
#   - Root access
#   - Port 443 open (if Oracle Cloud: also open in VCN security list!)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ─── Preflight ───────────────────────────────────────────────────────────────

log_step "Fortochka Server Setup"
echo ""

require_root
require_ubuntu

USE_DEFAULTS=false
if [[ "${1:-}" == "--defaults" ]]; then
    USE_DEFAULTS=true
fi

# Load .env if it exists
load_env ".env" 2>/dev/null || true

# ─── Configuration ───────────────────────────────────────────────────────────

log_step "Configuration"

# SNI Domain
if [[ -z "${SNI_DOMAIN:-}" ]]; then
    SNI_DOMAIN="microsoft.com"
fi
if [[ "$USE_DEFAULTS" != true ]]; then
    echo ""
    echo "SNI domain — the website your VPN traffic will impersonate."
    echo "Must be a major site Russia can't afford to block."
    echo "See configs/sni-whitelist.txt for options."
    echo ""
    read -r -p "SNI domain [$SNI_DOMAIN]: " input
    SNI_DOMAIN="${input:-$SNI_DOMAIN}"
fi
log_info "SNI domain: $SNI_DOMAIN"

# Panel port
if [[ -z "${PANEL_PORT:-}" ]]; then
    PANEL_PORT=$(random_port)
fi
log_info "3x-ui panel port: $PANEL_PORT"

# Panel credentials
if [[ -z "${PANEL_USERNAME:-}" ]]; then
    PANEL_USERNAME="admin"
fi
if [[ -z "${PANEL_PASSWORD:-}" ]]; then
    PANEL_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)
fi

# Client UUID
if [[ -z "${CLIENT_UUID:-}" ]]; then
    CLIENT_UUID=$(generate_uuid)
fi
log_info "Client UUID: $CLIENT_UUID"

# WebSocket fallback port
if [[ -z "${WS_PORT:-}" ]]; then
    WS_PORT=$(random_port)
fi
log_info "WebSocket fallback port: $WS_PORT"

# Server name
if [[ -z "${SERVER_NAME:-}" ]]; then
    SERVER_NAME="fortochka-1"
fi

# Short ID
SHORT_ID=$(generate_short_id)

# ─── System Preparation ─────────────────────────────────────────────────────

log_step "Preparing system"

apt-get update -qq
apt-get upgrade -y -qq

install_if_missing curl curl
install_if_missing wget wget
install_if_missing jq jq
install_if_missing qrencode qrencode
install_if_missing openssl openssl
install_if_missing ufw ufw

log_info "System packages ready"

# ─── Install 3x-ui ──────────────────────────────────────────────────────────

log_step "Installing 3x-ui (XRay management panel)"

if command -v x-ui &>/dev/null || systemctl is-active --quiet x-ui 2>/dev/null; then
    log_warn "3x-ui is already installed. Skipping installation."
    log_info "If you want to reinstall, run: x-ui uninstall"
else
    # Download and run the official installer in non-interactive mode
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) <<< "y"

    # Wait for service to start
    sleep 3

    if ! systemctl is-active --quiet x-ui; then
        log_error "3x-ui failed to start. Check: systemctl status x-ui"
        exit 1
    fi
    log_info "3x-ui installed and running"
fi

# Configure panel settings
x-ui setting -username "$PANEL_USERNAME" -password "$PANEL_PASSWORD" 2>/dev/null || true
x-ui setting -port "$PANEL_PORT" 2>/dev/null || true

# Restart to apply settings
systemctl restart x-ui
sleep 2

log_info "3x-ui panel configured"

# ─── Generate Reality Keypair ────────────────────────────────────────────────

log_step "Generating Reality keypair"

if [[ -n "${REALITY_PRIVATE_KEY:-}" && -n "${REALITY_PUBLIC_KEY:-}" ]]; then
    log_info "Using Reality keypair from config"
else
    generate_reality_keypair
    log_info "Generated new Reality keypair"
fi

log_info "Public key: $REALITY_PUBLIC_KEY"

# ─── Configure XRay ─────────────────────────────────────────────────────────

log_step "Configuring VLESS+Reality"

SERVER_IP=$(get_public_ip)
log_info "Server IP: $SERVER_IP"

# Generate WebSocket path
WS_PATH=$(openssl rand -hex 8)

# Build the XRay config from template
PROJECT_ROOT=$(get_project_root)
CONFIG_TEMPLATE="$PROJECT_ROOT/configs/xray-server-template.json"

if [[ -f "$CONFIG_TEMPLATE" ]]; then
    XRAY_CONFIG=$(cat "$CONFIG_TEMPLATE")
else
    log_warn "Template not found at $CONFIG_TEMPLATE, using inline config"
    XRAY_CONFIG='{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {
      "tag": "vless-reality-tcp",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "__CLIENT_UUID__", "flow": "xtls-rprx-vision"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "__SNI_DOMAIN__:443",
          "xver": 0,
          "serverNames": ["__SNI_DOMAIN__"],
          "privateKey": "__REALITY_PRIVATE_KEY__",
          "shortIds": ["__SHORT_ID__"]
        }
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
    }
  ],
  "outbounds": [
    {"tag": "direct", "protocol": "freedom"},
    {"tag": "blocked", "protocol": "blackhole"}
  ]
}'
fi

# Substitute placeholders
XRAY_CONFIG=$(echo "$XRAY_CONFIG" \
    | sed "s|__CLIENT_UUID__|$CLIENT_UUID|g" \
    | sed "s|__SNI_DOMAIN__|$SNI_DOMAIN|g" \
    | sed "s|__REALITY_PRIVATE_KEY__|$REALITY_PRIVATE_KEY|g" \
    | sed "s|__SHORT_ID__|$SHORT_ID|g" \
    | sed "s|__WS_PORT__|$WS_PORT|g" \
    | sed "s|__WS_PATH__|$WS_PATH|g")

# Find the XRay config location (3x-ui stores it here)
XRAY_CONFIG_PATH="/usr/local/x-ui/bin/config.json"
if [[ ! -d "$(dirname "$XRAY_CONFIG_PATH")" ]]; then
    XRAY_CONFIG_PATH="/etc/x-ui/config.json"
fi

echo "$XRAY_CONFIG" > "$XRAY_CONFIG_PATH"
log_info "XRay config written to $XRAY_CONFIG_PATH"

# Restart XRay to apply
systemctl restart x-ui
sleep 2

if systemctl is-active --quiet x-ui; then
    log_info "XRay is running with new config"
else
    log_error "XRay failed to start. Check config: $XRAY_CONFIG_PATH"
    log_error "Logs: journalctl -u x-ui -n 50"
    exit 1
fi

# ─── Firewall ────────────────────────────────────────────────────────────────

log_step "Configuring firewall"

ufw --force reset >/dev/null 2>&1
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow 22/tcp comment "SSH" >/dev/null
ufw allow 443/tcp comment "VLESS+Reality" >/dev/null
ufw allow "$WS_PORT/tcp" comment "VLESS WebSocket fallback" >/dev/null
ufw allow "$PANEL_PORT/tcp" comment "3x-ui panel" >/dev/null
ufw --force enable >/dev/null

log_info "Firewall configured (SSH, 443, $WS_PORT, $PANEL_PORT)"

# ─── Generate Client Config ─────────────────────────────────────────────────

log_step "Generating client configuration"

# Build VLESS share link
VLESS_LINK="vless://${CLIENT_UUID}@${SERVER_IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI_DOMAIN}&fp=chrome&pbk=${REALITY_PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#Fortochka-${SERVER_NAME}"

# Generate QR code
mkdir -p "$PROJECT_ROOT/output"
echo "$VLESS_LINK" | qrencode -t PNG -o "$PROJECT_ROOT/output/${SERVER_NAME}-qr.png" 2>/dev/null || true

# Save config details
cat > "$PROJECT_ROOT/output/${SERVER_NAME}-config.txt" << EOF
# Fortochka Server: $SERVER_NAME
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Server IP:        $SERVER_IP
Protocol:         VLESS + Reality
Port:             443
UUID:             $CLIENT_UUID
SNI Domain:       $SNI_DOMAIN
Public Key:       $REALITY_PUBLIC_KEY
Short ID:         $SHORT_ID
Fingerprint:      chrome
Flow:             xtls-rprx-vision

3x-ui Panel:      http://$SERVER_IP:$PANEL_PORT
Panel Username:   $PANEL_USERNAME
Panel Password:   $PANEL_PASSWORD

WebSocket Fallback:
  Port:           $WS_PORT
  Path:           /$WS_PATH

VLESS Share Link:
$VLESS_LINK

servers.txt entry:
$SERVER_IP 443 $CLIENT_UUID $REALITY_PUBLIC_KEY $SNI_DOMAIN $SHORT_ID $SERVER_NAME
EOF

log_info "Config saved to output/${SERVER_NAME}-config.txt"

# ─── Summary ────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_step "Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  ${BOLD}3x-ui Panel:${NC}      http://$SERVER_IP:$PANEL_PORT"
echo -e "  ${BOLD}Panel Login:${NC}      $PANEL_USERNAME / $PANEL_PASSWORD"
echo ""
echo -e "  ${BOLD}Server IP:${NC}        $SERVER_IP"
echo -e "  ${BOLD}Client UUID:${NC}      $CLIENT_UUID"
echo -e "  ${BOLD}SNI Domain:${NC}       $SNI_DOMAIN"
echo -e "  ${BOLD}Public Key:${NC}       $REALITY_PUBLIC_KEY"
echo ""

# Show QR code in terminal
echo -e "  ${BOLD}Scan this QR code with v2RayTun (iOS) or v2rayNG (Android):${NC}"
echo ""
echo "$VLESS_LINK" | qrencode -t UTF8 2>/dev/null || echo "  (install qrencode to display QR in terminal)"
echo ""
echo -e "  ${BOLD}VLESS link (copy to phone if QR doesn't work):${NC}"
echo "  $VLESS_LINK"
echo ""

# Oracle Cloud reminder
echo -e "  ${YELLOW}${BOLD}ORACLE CLOUD USERS:${NC}"
echo -e "  ${YELLOW}You must ALSO open ports 443 and $WS_PORT in your VCN Security List!${NC}"
echo -e "  ${YELLOW}The firewall (ufw) alone is not enough on Oracle Cloud.${NC}"
echo -e "  ${YELLOW}Go to: Networking > Virtual Cloud Networks > your VCN > Security Lists${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
