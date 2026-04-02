#!/usr/bin/env bash
# Fortochka — Publish subscription file to a GitHub Gist
#
# Creates or updates a secret Gist containing the subscription data.
# The Gist's raw URL becomes the subscription URL for client apps.
#
# Prerequisites:
#   - GitHub CLI (gh) installed and authenticated: gh auth login
#   - subscription/active.txt exists (run generate-subscription.sh first)
#
# Usage:
#   bash subscription/publish-gist.sh
#
# First run creates a new Gist. Subsequent runs update the same Gist.
# The Gist ID is saved to subscription/.gist-id for future updates.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib/common.sh"

PROJECT_ROOT=$(get_project_root)
SUB_FILE="$PROJECT_ROOT/subscription/active.txt"
GIST_ID_FILE="$PROJECT_ROOT/subscription/.gist-id"

# Preflight
if ! command -v gh &>/dev/null; then
    log_error "GitHub CLI (gh) not found."
    echo "Install it: https://cli.github.com/"
    echo "Then authenticate: gh auth login"
    exit 1
fi

if ! gh auth status &>/dev/null 2>&1; then
    log_error "GitHub CLI not authenticated. Run: gh auth login"
    exit 1
fi

if [[ ! -f "$SUB_FILE" ]]; then
    log_error "Subscription file not found. Run generate-subscription.sh first."
    exit 1
fi

log_step "Publishing subscription to GitHub Gist"

if [[ -f "$GIST_ID_FILE" ]]; then
    # Update existing Gist
    GIST_ID=$(cat "$GIST_ID_FILE")
    log_info "Updating existing Gist: $GIST_ID"

    if gh gist edit "$GIST_ID" "$SUB_FILE" 2>/dev/null; then
        log_info "Gist updated successfully"
    else
        log_warn "Failed to update Gist. Creating a new one..."
        rm -f "$GIST_ID_FILE"
    fi
fi

if [[ ! -f "$GIST_ID_FILE" ]]; then
    # Create new secret Gist
    log_info "Creating new secret Gist..."

    GIST_URL=$(gh gist create "$SUB_FILE" --desc "fortochka" 2>&1 | tail -1)
    GIST_ID=$(echo "$GIST_URL" | grep -oP '[a-f0-9]{20,}' || true)

    if [[ -z "$GIST_ID" ]]; then
        log_error "Failed to create Gist. Output: $GIST_URL"
        exit 1
    fi

    echo "$GIST_ID" > "$GIST_ID_FILE"
    log_info "Created Gist: $GIST_URL"
fi

# Get the raw URL for the subscription file
GIST_ID=$(cat "$GIST_ID_FILE")
RAW_URL="https://gist.githubusercontent.com/$(gh api user --jq .login 2>/dev/null || echo 'USER')/${GIST_ID}/raw/active.txt"

echo ""
log_step "Subscription URL"
echo ""
echo "  $RAW_URL"
echo ""
log_info "Add this URL to v2RayTun/v2rayNG subscription settings."
log_info "Client apps will auto-fetch updated server configs from this URL."
echo ""
log_warn "Keep this URL private — anyone with it can use your servers."
