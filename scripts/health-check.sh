#!/usr/bin/env bash
# Fortochka — Health check for active servers
#
# Checks each server in configs/servers.txt for:
#   1. TCP connectivity on port 443
#   2. TLS handshake with the SNI domain (verifies Reality is responding)
#
# Usage:
#   bash health-check.sh           # Interactive output
#   bash health-check.sh --quiet   # Exit code only (for cron)
#
# Exit codes:
#   0 — all servers healthy
#   1 — one or more servers unreachable

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PROJECT_ROOT=$(get_project_root)
SERVERS_FILE="$PROJECT_ROOT/configs/servers.txt"
QUIET=false

if [[ "${1:-}" == "--quiet" ]]; then
    QUIET=true
fi

if [[ ! -f "$SERVERS_FILE" ]]; then
    log_error "No servers file found at $SERVERS_FILE"
    exit 1
fi

TOTAL=0
HEALTHY=0
FAILED=0
FAILED_SERVERS=""

while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ || -z "${line// }" ]] && continue

    read -r ip port uuid pubkey sni shortid name <<< "$line"
    [[ -z "$ip" || -z "$port" ]] && continue

    name="${name:-$ip}"
    TOTAL=$((TOTAL + 1))

    # Test 1: TCP connection
    if timeout 5 bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null; then
        tcp_status="OK"
    else
        tcp_status="FAIL"
    fi

    # Test 2: TLS handshake with SNI
    tls_status="SKIP"
    if [[ "$tcp_status" == "OK" ]] && command -v openssl &>/dev/null; then
        if echo | timeout 5 openssl s_client -connect "$ip:$port" -servername "$sni" 2>/dev/null | grep -q "CONNECTED"; then
            tls_status="OK"
        else
            tls_status="FAIL"
        fi
    fi

    # Determine overall status
    if [[ "$tcp_status" == "OK" && ("$tls_status" == "OK" || "$tls_status" == "SKIP") ]]; then
        status="HEALTHY"
        HEALTHY=$((HEALTHY + 1))
        if [[ "$QUIET" != true ]]; then
            echo -e "  ${GREEN}[OK]${NC}   $name ($ip:$port) — TCP: $tcp_status, TLS: $tls_status"
        fi
    else
        status="DOWN"
        FAILED=$((FAILED + 1))
        FAILED_SERVERS="${FAILED_SERVERS}${name} ($ip) "
        if [[ "$QUIET" != true ]]; then
            echo -e "  ${RED}[FAIL]${NC} $name ($ip:$port) — TCP: $tcp_status, TLS: $tls_status"
        fi
    fi
done < "$SERVERS_FILE"

if [[ "$QUIET" != true ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Total: $TOTAL  Healthy: $HEALTHY  Failed: $FAILED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ $FAILED -gt 0 ]]; then
        echo ""
        log_warn "Failed servers: $FAILED_SERVERS"
        log_info "Consider rotating failed servers:"
        log_info "  bash scripts/rotate-server.sh"
    fi
fi

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
