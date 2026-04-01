#!/usr/bin/env bash
# Fortochka — Rotate a blocked server
#
# Marks a server as inactive in servers.txt and optionally updates the subscription.
#
# Usage:
#   bash rotate-server.sh <server-name>    # Comment out the named server
#   bash rotate-server.sh                  # Interactive — shows servers and asks which to remove

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PROJECT_ROOT=$(get_project_root)
SERVERS_FILE="$PROJECT_ROOT/configs/servers.txt"

if [[ ! -f "$SERVERS_FILE" ]]; then
    log_error "No servers file found at $SERVERS_FILE"
    exit 1
fi

# List active servers
log_step "Active servers"
echo ""

SERVERS=()
INDEX=0
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue
    read -r ip port uuid pubkey sni shortid name <<< "$line"
    name="${name:-$ip}"
    SERVERS+=("$name")
    INDEX=$((INDEX + 1))
    echo "  $INDEX. $name ($ip:$port)"
done < "$SERVERS_FILE"

if [[ ${#SERVERS[@]} -eq 0 ]]; then
    log_warn "No active servers found."
    exit 0
fi

echo ""

# Determine which server to deactivate
TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
    read -r -p "Which server to deactivate? (number or name): " input
    if [[ "$input" =~ ^[0-9]+$ ]] && [[ "$input" -ge 1 ]] && [[ "$input" -le ${#SERVERS[@]} ]]; then
        TARGET="${SERVERS[$((input - 1))]}"
    else
        TARGET="$input"
    fi
fi

# Comment out the server line
if grep -q "$TARGET" "$SERVERS_FILE"; then
    sed -i "/$TARGET/s/^/# BLOCKED $(date +%Y-%m-%d): /" "$SERVERS_FILE"
    log_info "Deactivated: $TARGET"
else
    log_error "Server '$TARGET' not found in servers.txt"
    exit 1
fi

# Regenerate subscription
echo ""
if confirm_action "Regenerate subscription file?"; then
    bash "$SCRIPT_DIR/generate-subscription.sh"

    echo ""
    if confirm_action "Publish updated subscription to Gist?"; then
        bash "$PROJECT_ROOT/subscription/publish-gist.sh"
    fi
fi

echo ""
log_step "Next steps"
echo "  1. Set up a replacement server on a new VPS:"
echo "     sudo bash scripts/setup-server.sh"
echo ""
echo "  2. Add the new server's details to configs/servers.txt"
echo "     (the setup script prints the servers.txt entry at the end)"
echo ""
echo "  3. Regenerate and publish the subscription:"
echo "     bash scripts/generate-subscription.sh"
echo "     bash subscription/publish-gist.sh"
echo ""
echo "  Client apps will auto-pull the updated config on their next refresh."
