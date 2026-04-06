#!/usr/bin/env bash
# scan-sni.sh — Test which SNI targets pass Russian DPI
#
# Run this from a RUSSIAN VPS to find working disguise domains for VLESS+Reality.
# From a non-Russian IP the test is meaningless — DPI only runs on Russian traffic.
#
# Usage:
#   bash scripts/scan-sni.sh <server-ip> [candidates-file]
#
# Example:
#   bash scripts/scan-sni.sh 163.192.34.235
#   bash scripts/scan-sni.sh 163.192.34.235 configs/sni-whitelist.txt

set -euo pipefail

SERVER_IP="${1:?Usage: scan-sni.sh <server-ip> [candidates-file]}"
CANDIDATES_FILE="${2:-configs/sni-whitelist.txt}"
SERVER_PORT=443
TIMEOUT=10

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

if [[ ! -f "$CANDIDATES_FILE" ]]; then
  echo "Candidates file not found: $CANDIDATES_FILE"
  exit 1
fi

echo -e "${BOLD}=== Fortochka SNI Scanner ===${NC}"
echo "Server:     $SERVER_IP:$SERVER_PORT"
echo "Candidates: $CANDIDATES_FILE"
echo "Timeout:    ${TIMEOUT}s per domain"
echo ""
echo "Testing TLS handshakes through Russian DPI..."
echo "-------------------------------------------"

declare -a pass_fast=()
declare -a pass_slow=()
declare -a fail_list=()

while IFS= read -r line; do
  # Skip comments and blank lines
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line// }" ]] && continue

  sni="$line"
  printf "%-40s " "$sni"

  # curl --connect-to forces the TCP connection to our server IP,
  # but presents the SNI domain in the TLS ClientHello.
  # If DPI blocks it: curl exits with code 35 (TLS error) or 28 (timeout).
  # If DPI passes it: we get any HTTP response — even a 4xx from the target site.
  output=$(curl \
    --connect-to "${sni}:${SERVER_PORT}:${SERVER_IP}:${SERVER_PORT}" \
    "https://${sni}/" \
    --max-time "$TIMEOUT" \
    --silent \
    --write-out "%{http_code} %{time_total}" \
    --output /dev/null \
    2>/dev/null || echo "000 0")

  http_code=$(echo "$output" | awk '{print $1}')
  time_s=$(echo "$output" | awk '{print $2}')
  time_ms=$(echo "$time_s" | awk '{printf "%d", $1 * 1000}')

  if [[ "$http_code" == "000" ]]; then
    echo -e "${RED}FAIL${NC}   (no connection)"
    fail_list+=("$sni")
  elif [[ $time_ms -lt 4000 ]]; then
    echo -e "${GREEN}PASS${NC}   HTTP $http_code  ${time_ms}ms"
    pass_fast+=("$sni|$http_code|$time_ms")
  else
    echo -e "${YELLOW}SLOW${NC}   HTTP $http_code  ${time_ms}ms"
    pass_slow+=("$sni|$http_code|$time_ms")
  fi

done < "$CANDIDATES_FILE"

echo ""
echo -e "${BOLD}=== Summary ===${NC}"
echo ""

if [[ ${#pass_fast[@]} -gt 0 ]]; then
  echo -e "${GREEN}Fast (recommended):${NC}"
  for entry in "${pass_fast[@]}"; do
    sni="${entry%%|*}"; rest="${entry#*|}"; code="${rest%%|*}"; ms="${rest##*|}"
    printf "  ✓  %-38s HTTP %-4s %sms\n" "$sni" "$code" "$ms"
  done
  echo ""
fi

if [[ ${#pass_slow[@]} -gt 0 ]]; then
  echo -e "${YELLOW}Slow (usable fallback):${NC}"
  for entry in "${pass_slow[@]}"; do
    sni="${entry%%|*}"; rest="${entry#*|}"; code="${rest%%|*}"; ms="${rest##*|}"
    printf "  ~  %-38s HTTP %-4s %sms\n" "$sni" "$code" "$ms"
  done
  echo ""
fi

if [[ ${#fail_list[@]} -gt 0 ]]; then
  echo -e "${RED}Blocked by DPI:${NC}"
  for sni in "${fail_list[@]}"; do
    printf "  ✗  %s\n" "$sni"
  done
  echo ""
fi

echo "-------------------------------------------"
total=$(( ${#pass_fast[@]} + ${#pass_slow[@]} + ${#fail_list[@]} ))
passed=$(( ${#pass_fast[@]} + ${#pass_slow[@]} ))
echo "Tested: $total  |  Passed: $passed  |  Blocked: ${#fail_list[@]}"

if [[ ${#pass_fast[@]} -gt 0 ]]; then
  best="${pass_fast[0]%%|*}"
  echo ""
  echo -e "${BOLD}Best candidate: $best${NC}"
  echo "  → In 3x-ui panel: Inbounds > edit > Target: ${best}:443, SNI: ${best}"
  echo "  → In radio/worker/src/config.js: update sni field for this server"
fi
