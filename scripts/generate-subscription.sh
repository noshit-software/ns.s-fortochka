#!/usr/bin/env bash
# Fortochka — Generate subscription file from servers.txt
#
# Reads configs/servers.txt and produces a base64-encoded subscription file
# that v2rayNG and v2RayTun can import and auto-update from.
#
# Usage:
#   bash generate-subscription.sh
#
# Output:
#   subscription/active.txt — the subscription file (base64 encoded)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PROJECT_ROOT=$(get_project_root)
SERVERS_FILE="$PROJECT_ROOT/configs/servers.txt"
OUTPUT_FILE="$PROJECT_ROOT/subscription/active.txt"

if [[ ! -f "$SERVERS_FILE" ]]; then
    log_error "No servers file found at $SERVERS_FILE"
    echo ""
    echo "Create it from the example:"
    echo "  cp configs/servers.txt.example configs/servers.txt"
    echo "  # Then add your server details"
    exit 1
fi

log_step "Generating subscription from servers.txt"

# Read servers and build VLESS links
LINKS=""
SERVER_COUNT=0

while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue

    # Parse fields
    read -r ip port uuid pubkey sni shortid name <<< "$line"

    if [[ -z "$ip" || -z "$port" || -z "$uuid" || -z "$pubkey" || -z "$sni" || -z "$shortid" ]]; then
        log_warn "Skipping malformed line: $line"
        continue
    fi

    name="${name:-fortochka-$SERVER_COUNT}"

    # Build VLESS link
    vless_link="vless://${uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pubkey}&sid=${shortid}&type=tcp#Fortochka-${name}"

    if [[ -n "$LINKS" ]]; then
        LINKS="${LINKS}\n${vless_link}"
    else
        LINKS="$vless_link"
    fi

    SERVER_COUNT=$((SERVER_COUNT + 1))
    log_info "Added: $name ($ip)"
done < "$SERVERS_FILE"

if [[ $SERVER_COUNT -eq 0 ]]; then
    log_error "No valid servers found in $SERVERS_FILE"
    exit 1
fi

# Encode as base64 (the standard subscription format)
echo -e "$LINKS" | base64 -w 0 > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

log_info "Subscription file written to subscription/active.txt"
log_info "Contains $SERVER_COUNT server(s)"
echo ""
log_step "Next steps"
echo "  1. Host this file somewhere accessible:"
echo "     bash subscription/publish-gist.sh"
echo ""
echo "  2. On the phone, add the subscription URL:"
echo "     v2rayNG: Subscription group settings > + > paste URL > Update"
echo "     v2RayTun: Settings > Subscription > + > paste URL > Update"
