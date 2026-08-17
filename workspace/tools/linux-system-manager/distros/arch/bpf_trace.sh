#!/bin/bash

set -euo pipefail

# Arch Linux BPF Trace Actions
# Self-contained numbered picker over the BCC toolkit installed by
# bpf_setup.sh. Arch's bcc-tools package drops tools unsuffixed under
# /usr/share/bcc/tools and does not put them on PATH.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
CLR='\033[H\033[2J'

log_info()  { echo -e "${BLUE}ℹ${NC}  $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

TOOLS_DIR="/usr/share/bcc/tools"

TOOL_NAMES=(opensnoop statsnoop execsnoop exitsnoop tcpconnect tcpaccept tcplife)
TOOL_LABELS=(
    "Trace File Opens (opensnoop)"
    "Trace File Stat Calls (statsnoop)"
    "Trace Process Exec (execsnoop)"
    "Trace Process Exit (exitsnoop)"
    "Trace Outbound TCP Connections (tcpconnect)"
    "Trace Inbound TCP Connections (tcpaccept)"
    "Trace TCP Connection Lifetimes (tcplife)"
)

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_info "BPF tracing requires root privileges. Re-running with sudo..."
        exec sudo -- "$0"
    fi
}

run_tool() {
    local tool="$1"
    local tool_path="${TOOLS_DIR}/${tool}"

    if [[ ! -x "$tool_path" ]]; then
        log_error "$tool not found at $tool_path"
        log_info "Run 'Install BCC & bpftrace' from the BPF Tools menu first."
        echo ""
        read -rp "Press ENTER to continue..." _
        return
    fi

    echo ""
    log_info "Tracing with $tool. Press Ctrl+C to stop."
    echo ""
    "$tool_path" || true
    echo ""
    read -rp "Press ENTER to continue..." _
}

main() {
    check_root

    while true; do
        echo -e "$CLR"
        echo "╔════════════════════════════════════════════════╗"
        echo "║   Arch Linux BPF Trace Actions                 ║"
        echo "╚════════════════════════════════════════════════╝"
        echo ""
        for i in "${!TOOL_NAMES[@]}"; do
            echo -e "  ${GREEN}$((i + 1))${NC})  ${YELLOW}${TOOL_LABELS[$i]}${NC}"
        done
        echo ""
        echo -e "  ${RED}0${NC})  Back"
        echo ""
        read -rp "Select a tool (1-${#TOOL_NAMES[@]}, 0 to go back): " choice

        if [[ "$choice" == "0" ]]; then
            break
        fi

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "${#TOOL_NAMES[@]}" ]]; then
            log_error "Invalid option: $choice"
            sleep 1
            continue
        fi

        run_tool "${TOOL_NAMES[$((choice - 1))]}"
    done
}

main
