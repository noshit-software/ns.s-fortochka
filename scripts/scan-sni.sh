#!/usr/bin/env bash
# scan-sni.sh — Test which SNI targets pass Russian DPI and work with VLESS+Reality
#
# Run this from a RUSSIAN VPS to find working disguise domains.
# From a non-Russian IP the DPI test is meaningless.
#
# For each domain, checks:
#   1. DPI pass    — direct TLS connection from Russia goes through
#   2. TLS 1.3     — domain supports TLS 1.3 (required for Reality)
#   3. Not CDN     — IP is not Cloudflare/Fastly/Akamai/etc (CDN breaks Reality)
#
# Only domains passing all three are valid Reality SNI candidates.
#
# Usage:
#   bash scan-sni.sh [candidates-file] [worker-url] [scan-secret]
#
# Examples:
#   bash scan-sni.sh
#   bash scan-sni.sh sni-whitelist.txt https://fortochka-radio-api.robertgardunia.workers.dev mysecret
#
# Cron (every 4 hours):
#   0 */4 * * * bash /root/scan-sni.sh /root/sni-whitelist.txt https://... secret >> /root/scan.log 2>&1

set -euo pipefail

CANDIDATES_FILE="${1:-sni-whitelist.txt}"
WORKER_URL="${2:-}"
SCAN_SECRET="${3:-}"
TIMEOUT=10
DELAY_MIN=3
DELAY_MAX=27

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Known CDN IP ranges (Cloudflare, Fastly, Akamai, AWS CloudFront, Google CDN)
# Reality breaks with these because TLS terminates at the CDN edge, not the origin.
CDN_RANGES=(
  # Cloudflare
  "103.21.244." "103.22.200." "103.31.4." "104.16." "104.17." "104.18." "104.19."
  "104.20." "104.21." "104.22." "104.24." "104.25." "104.26." "104.27."
  "108.162.192." "108.162.193." "108.162.194." "108.162.195."
  "131.0.72." "141.101.64." "141.101.65." "141.101.66." "141.101.67."
  "162.158." "172.64." "172.65." "172.66." "172.67." "172.68." "172.69."
  "172.70." "172.71." "188.114.96." "188.114.97." "188.114.98." "188.114.99."
  "190.93.240." "190.93.241." "190.93.242." "190.93.243."
  "197.234.240." "197.234.241." "197.234.242." "197.234.243."
  "198.41.128." "198.41.129." "198.41.130." "198.41.131." "198.41.132."
  "198.41.200." "198.41.201." "198.41.202." "198.41.203." "198.41.204."
  # Fastly
  "23.235.32." "23.235.33." "23.235.34." "23.235.35." "23.235.36." "23.235.37."
  "23.235.38." "23.235.39." "151.101." "199.27.72." "199.27.73." "199.27.74."
  # Akamai
  "23.32." "23.33." "23.34." "23.35." "23.36." "23.37." "23.38." "23.39."
  "23.40." "23.41." "23.42." "23.43." "23.44." "23.45." "23.46." "23.47."
  "23.48." "23.49." "23.50." "23.51." "23.52." "23.53." "23.54." "23.55."
  "23.56." "23.57." "23.58." "23.59." "23.60." "23.61." "23.62." "23.63."
  "23.192." "23.193." "23.194." "23.195." "23.196." "23.197." "23.198." "23.199."
  "23.200." "23.201." "23.202." "23.203." "23.204." "23.205." "23.206." "23.207."
  "23.208." "23.209." "23.210." "23.211." "23.212." "23.213." "23.214." "23.215."
  # AWS CloudFront
  "13.32." "13.33." "13.34." "13.35." "52.84." "52.85." "54.182." "54.230."
  "54.239.128." "64.252." "70.132." "99.84." "205.251.192." "205.251.193."
  "205.251.194." "205.251.195." "205.251.196." "205.251.197." "205.251.198."
  "205.251.199." "205.251.200." "205.251.201." "205.251.202." "205.251.203."
  "205.251.204." "205.251.205." "205.251.206." "205.251.207." "205.251.208."
  "205.251.209." "205.251.210." "205.251.211." "205.251.212." "205.251.213."
  "205.251.214." "205.251.215." "205.251.216." "205.251.217." "205.251.218."
  "205.251.219." "205.251.220." "205.251.221." "205.251.222." "205.251.223."
  "205.251.224." "205.251.225." "205.251.226." "205.251.227." "205.251.228."
  "205.251.229." "205.251.230." "205.251.231." "205.251.232." "205.251.233."
  "205.251.234." "205.251.235." "205.251.236." "205.251.237." "205.251.238."
  "205.251.239." "205.251.240." "205.251.241." "205.251.242." "205.251.243."
  "205.251.244." "205.251.245." "205.251.246." "205.251.247." "205.251.248."
  "205.251.249." "205.251.250." "205.251.251." "205.251.252." "205.251.253."
  "205.251.254." "205.251.255."
)

is_cdn_ip() {
  local ip="$1"
  for range in "${CDN_RANGES[@]}"; do
    if [[ "$ip" == ${range}* ]]; then
      return 0
    fi
  done
  return 1
}

if [[ ! -f "$CANDIDATES_FILE" ]]; then
  echo "Candidates file not found: $CANDIDATES_FILE"
  exit 1
fi

echo -e "${BOLD}=== Fortochka SNI Scanner ===${NC}"
echo "Candidates: $CANDIDATES_FILE"
echo "Checks:     DPI pass + TLS 1.3 + not CDN"
echo "Timeout:    ${TIMEOUT}s per domain"
echo "Delay:      ${DELAY_MIN}-${DELAY_MAX}s between probes (randomized)"
echo "Worker:     ${WORKER_URL:-not configured (results printed only)}"
echo ""
echo "-------------------------------------------"

declare -a pass_fast=()
declare -a pass_slow=()
declare -a fail_list=()

while IFS= read -r line; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line// }" ]] && continue

  sni="$line"
  printf "%-40s " "$sni"

  # --- CHECK 1: DPI pass (direct connection from Russia) ---
  output=$(curl \
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
    echo -e "${RED}FAIL${NC}   (blocked by DPI)"
    fail_list+=("$sni")
    sleep $(( DELAY_MIN + RANDOM % (DELAY_MAX - DELAY_MIN + 1) ))
    continue
  fi

  # --- CHECK 2: TLS 1.3 support ---
  tls13_ok=$(curl \
    "https://${sni}/" \
    --tlsv1.3 \
    --max-time "$TIMEOUT" \
    --silent \
    --write-out "%{http_code}" \
    --output /dev/null \
    2>/dev/null || echo "000")

  if [[ "$tls13_ok" == "000" ]]; then
    echo -e "${YELLOW}SKIP${NC}   (no TLS 1.3)"
    fail_list+=("$sni")
    sleep $(( DELAY_MIN + RANDOM % (DELAY_MAX - DELAY_MIN + 1) ))
    continue
  fi

  # --- CHECK 3: CDN detection ---
  resolved_ip=$(dig +short "$sni" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || echo "")

  if [[ -z "$resolved_ip" ]]; then
    echo -e "${YELLOW}SKIP${NC}   (cannot resolve IP)"
    fail_list+=("$sni")
    sleep $(( DELAY_MIN + RANDOM % (DELAY_MAX - DELAY_MIN + 1) ))
    continue
  fi

  if is_cdn_ip "$resolved_ip"; then
    echo -e "${CYAN}CDN ${NC}   ($resolved_ip — not suitable for Reality)"
    fail_list+=("$sni")
    sleep $(( DELAY_MIN + RANDOM % (DELAY_MAX - DELAY_MIN + 1) ))
    continue
  fi

  # --- All checks passed ---
  if [[ $time_ms -lt 4000 ]]; then
    echo -e "${GREEN}PASS${NC}   HTTP $http_code  ${time_ms}ms  ($resolved_ip)"
    pass_fast+=("$sni|$http_code|$time_ms")
  else
    echo -e "${YELLOW}SLOW${NC}   HTTP $http_code  ${time_ms}ms  ($resolved_ip)"
    pass_slow+=("$sni|$http_code|$time_ms")
  fi

  sleep $(( DELAY_MIN + RANDOM % (DELAY_MAX - DELAY_MIN + 1) ))

done < "$CANDIDATES_FILE"

echo ""
echo -e "${BOLD}=== Summary ===${NC}"
echo ""

if [[ ${#pass_fast[@]} -gt 0 ]]; then
  echo -e "${GREEN}Fast — valid Reality SNI candidates:${NC}"
  for entry in "${pass_fast[@]}"; do
    sni="${entry%%|*}"; rest="${entry#*|}"; code="${rest%%|*}"; ms="${rest##*|}"
    printf "  ✓  %-38s HTTP %-4s %sms\n" "$sni" "$code" "$ms"
  done
  echo ""
fi

if [[ ${#pass_slow[@]} -gt 0 ]]; then
  echo -e "${YELLOW}Slow — usable fallback:${NC}"
  for entry in "${pass_slow[@]}"; do
    sni="${entry%%|*}"; rest="${entry#*|}"; code="${rest%%|*}"; ms="${rest##*|}"
    printf "  ~  %-38s HTTP %-4s %sms\n" "$sni" "$code" "$ms"
  done
  echo ""
fi

if [[ ${#fail_list[@]} -gt 0 ]]; then
  echo -e "${RED}Failed (blocked, no TLS 1.3, or CDN):${NC}"
  for sni in "${fail_list[@]}"; do
    printf "  ✗  %s\n" "$sni"
  done
  echo ""
fi

echo "-------------------------------------------"
total=$(( ${#pass_fast[@]} + ${#pass_slow[@]} + ${#fail_list[@]} ))
passed=$(( ${#pass_fast[@]} + ${#pass_slow[@]} ))
echo "Tested: $total  |  Passed: $passed  |  Failed: ${#fail_list[@]}"

# POST results to Worker KV if configured
if [[ -n "$WORKER_URL" && -n "$SCAN_SECRET" ]]; then
  echo ""
  echo "Posting results to Worker..."

  json_candidates="["
  first=1
  for entry in "${pass_fast[@]}" "${pass_slow[@]}"; do
    sni="${entry%%|*}"; rest="${entry#*|}"; code="${rest%%|*}"; ms="${rest##*|}"
    [[ $first -eq 0 ]] && json_candidates+=","
    json_candidates+="{\"sni\":\"${sni}\",\"ms\":${ms},\"status\":\"pass\"}"
    first=0
  done
  json_candidates+="]"

  payload="{\"candidates\":${json_candidates},\"scanned_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"total\":${total},\"passed\":${passed}}"

  response=$(curl -s -w "\n%{http_code}" \
    -X POST "${WORKER_URL}/api/scan-results" \
    -H "Content-Type: application/json" \
    -H "X-Scan-Secret: ${SCAN_SECRET}" \
    -d "$payload" \
    --max-time 15 \
    2>/dev/null || echo -e "\nfailed")

  http_status=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -1)

  if [[ "$http_status" == "200" ]]; then
    echo -e "${GREEN}✓ Results posted to Worker KV${NC}"
  else
    echo -e "${YELLOW}⚠ Worker POST failed (HTTP $http_status) — results not saved remotely${NC}"
    echo "  $body"
  fi
else
  echo ""
  echo "No Worker URL configured — results not posted remotely."
  echo "To enable: bash scan-sni.sh <file> <worker-url> <secret>"
fi

if [[ ${#pass_fast[@]} -gt 0 ]]; then
  best="${pass_fast[0]%%|*}"
  echo ""
  echo -e "${BOLD}Best candidate: $best${NC}"
fi
