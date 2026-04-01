#!/usr/bin/env bash
# Fortochka — shared functions for all scripts
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}${BOLD}==>${NC} ${BOLD}$*${NC}"; }

require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

require_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS. This script requires Ubuntu 22.04 or 24.04."
        exit 1
    fi
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        log_error "This script requires Ubuntu. Detected: $ID"
        exit 1
    fi
    local major_version
    major_version=$(echo "$VERSION_ID" | cut -d. -f1)
    if [[ "$major_version" -lt 22 ]]; then
        log_error "Ubuntu 22.04+ required. Detected: $VERSION_ID"
        exit 1
    fi
    log_info "Detected Ubuntu $VERSION_ID"
}

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required command not found: $cmd"
        echo "Install it with: apt install $cmd"
        exit 1
    fi
}

install_if_missing() {
    local cmd="$1"
    local pkg="${2:-$1}"
    if ! command -v "$cmd" &>/dev/null; then
        log_info "Installing $pkg..."
        apt-get install -y "$pkg" >/dev/null 2>&1
    fi
}

confirm_action() {
    local prompt="${1:-Continue?}"
    read -r -p "$prompt [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

generate_uuid() {
    if command -v uuidgen &>/dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif [[ -f /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        # Fallback: use openssl to generate a UUID v4
        local hex
        hex=$(openssl rand -hex 16)
        echo "${hex:0:8}-${hex:8:4}-4${hex:13:3}-$(printf '%x' $((0x8 | 0x$(echo "${hex:16:1}" | tr 'a-f' '0-5') & 0x3)))${hex:17:3}-${hex:20:12}"
    fi
}

generate_short_id() {
    openssl rand -hex 8
}

generate_reality_keypair() {
    # Requires xray to be installed
    local xray_bin=""
    local output=""

    if command -v xray &>/dev/null; then
        xray_bin="xray"
    else
        # Try common install locations
        for path in /usr/local/x-ui/bin/xray-linux-* /usr/local/bin/xray /usr/bin/xray; do
            if [[ -x "$path" ]]; then
                xray_bin="$path"
                break
            fi
        done
    fi

    if [[ -z "$xray_bin" ]]; then
        log_error "XRay binary not found. Install 3x-ui first."
        return 1
    fi

    output=$("$xray_bin" x25519)
    REALITY_PRIVATE_KEY=$(echo "$output" | grep -i "private" | awk '{print $NF}')
    REALITY_PUBLIC_KEY=$(echo "$output" | grep -i "password\|public" | awk '{print $NF}')
    if [[ -z "$REALITY_PRIVATE_KEY" || -z "$REALITY_PUBLIC_KEY" ]]; then
        log_error "Failed to parse Reality keypair. Raw output:"
        echo "$output" >&2
        return 1
    fi
    export REALITY_PRIVATE_KEY REALITY_PUBLIC_KEY
}

get_public_ip() {
    local ip=""
    # Try multiple services in case one is blocked
    for service in "ifconfig.me" "api.ipify.org" "icanhazip.com" "ipecho.net/plain"; do
        ip=$(curl -s --max-time 5 "$service" 2>/dev/null || true)
        if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    done
    log_error "Could not detect public IP"
    return 1
}

get_script_dir() {
    cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}

get_project_root() {
    local script_dir
    script_dir=$(get_script_dir)
    # Walk up until we find CLAUDE.md or .git
    local dir="$script_dir"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/CLAUDE.md" ]] || [[ -d "$dir/.git" ]]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    log_error "Could not find project root"
    return 1
}

load_env() {
    local env_file="${1:-.env}"
    local project_root
    project_root=$(get_project_root)
    local env_path="$project_root/configs/$env_file"
    if [[ -f "$env_path" ]]; then
        log_info "Loading config from $env_path"
        set -a
        source "$env_path"
        set +a
    fi
}

random_port() {
    # Generate a random port between 10000 and 65000
    echo $(( RANDOM % 55000 + 10000 ))
}
