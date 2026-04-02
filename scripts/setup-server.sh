#!/usr/bin/env bash
# Fortochka — Server Setup Script
# Run this on a fresh Ubuntu 22.04/24.04 VPS to install 3x-ui and prepare
# the server for VLESS+Reality configuration via the web panel.
#
# Usage:
#   sudo bash setup-server.sh
#
# What this script does:
#   1. Installs system dependencies
#   2. Flushes Oracle Cloud default iptables rules (safe on non-Oracle too)
#   3. Installs 3x-ui (XRay management panel)
#   4. Prints the panel URL and login credentials
#
# What you do next:
#   1. Log into the 3x-ui panel in your browser
#   2. Add a VLESS+Reality inbound on port 443 via the panel UI
#   3. Generate a QR code / VLESS link from the panel
#   4. Send the link to the family
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

# ─── System Preparation ─────────────────────────────────────────────────────

log_step "Preparing system"

apt-get update -qq
apt-get upgrade -y -qq

install_if_missing curl curl
install_if_missing wget wget
install_if_missing jq jq
install_if_missing qrencode qrencode
install_if_missing openssl openssl

# Install netfilter-persistent to save iptables rules across reboots
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent netfilter-persistent >/dev/null 2>&1

log_info "System packages ready"

# ─── Fix iptables (Oracle Cloud) ────────────────────────────────────────────

log_step "Configuring firewall"

# Oracle Cloud Ubuntu images ship with restrictive iptables rules that block
# most traffic except SSH. Flush them and set permissive defaults.
# The VCN Security List handles external firewalling on Oracle Cloud.
# On non-Oracle providers this is harmless — it just clears default rules.

iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

ip6tables -F
ip6tables -X
ip6tables -P INPUT ACCEPT
ip6tables -P FORWARD ACCEPT
ip6tables -P OUTPUT ACCEPT

# Persist so rules survive reboots
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

log_info "iptables flushed and persisted"

# Enable IP forwarding (needed for VPN traffic routing)
sysctl -w net.ipv4.ip_forward=1 >/dev/null
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi

log_info "IP forwarding enabled"

# ─── Install 3x-ui ──────────────────────────────────────────────────────────

log_step "Installing 3x-ui (XRay management panel)"

if command -v x-ui &>/dev/null || systemctl is-active --quiet x-ui 2>/dev/null; then
    log_warn "3x-ui is already installed. Skipping installation."
    log_info "If you want to reinstall, run: x-ui uninstall"
else
    curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh -o /tmp/3x-ui-install.sh
    bash /tmp/3x-ui-install.sh

    # Wait for service to start
    sleep 3

    if ! systemctl is-active --quiet x-ui; then
        log_error "3x-ui failed to start. Check: systemctl status x-ui"
        exit 1
    fi
    log_info "3x-ui installed and running"
fi

# ─── Get panel info ─────────────────────────────────────────────────────────

log_step "Detecting panel settings"

SERVER_IP=$(get_public_ip)

# Get panel port from x-ui settings
PANEL_INFO=$(x-ui settings show 2>&1 || true)
PANEL_PORT=$(echo "$PANEL_INFO" | grep -oP 'port:\s*\K\d+' || echo "2053")
WEB_BASE_PATH=$(echo "$PANEL_INFO" | grep -oP 'webBasePath:\s*\K\S+' || echo "/")

PANEL_URL="http://${SERVER_IP}:${PANEL_PORT}${WEB_BASE_PATH}"

# ─── Summary ────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_step "Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  ${BOLD}3x-ui Panel:${NC}  $PANEL_URL"
echo -e "  ${BOLD}Server IP:${NC}    $SERVER_IP"
echo -e "  ${BOLD}SSH:${NC}          ssh ubuntu@$SERVER_IP"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo "  1. Open the panel URL in your browser and log in"
echo "  2. Go to Inbounds > Add Inbound"
echo "  3. Set Protocol: vless, Port: 443"
echo "  4. Expand Client, set Flow: xtls-rprx-vision"
echo "  5. Set Security: Reality"
echo "  6. Set Target and SNI to a major site (e.g. yahoo.com:443 / yahoo.com)"
echo "  7. Click Get New Cert, then Create"
echo "  8. Click the QR code icon to get the share link"
echo "  9. Send the VLESS link to the family"
echo ""

# Oracle Cloud reminder
echo -e "  ${YELLOW}${BOLD}ORACLE CLOUD USERS:${NC}"
echo -e "  ${YELLOW}Open ports 443 and ${PANEL_PORT} in your VCN Security List!${NC}"
echo -e "  ${YELLOW}Hamburger menu > Networking > Virtual Cloud Networks > your VCN${NC}"
echo -e "  ${YELLOW}  > Subnets > your subnet > Security Lists > Add Ingress Rules${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
