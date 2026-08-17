#!/bin/bash

set -euo pipefail

# Debian/Ubuntu BPF Trace Actions
# Self-contained numbered picker over the BCC toolkit installed by
# bpf_setup.sh. Debian's bpfcc-tools package puts tools on PATH suffixed
# with -bpfcc.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
CLR='\033[H\033[2J'

log_info()  { echo -e "${BLUE}ℹ${NC}  $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

TOOL_NAMES=(opensnoop-bpfcc statsnoop-bpfcc execsnoop-bpfcc exitsnoop-bpfcc tcpconnect-bpfcc tcpaccept-bpfcc tcplife-bpfcc)
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

    if ! command -v "$tool" &>/dev/null; then
        log_error "$tool not found on PATH"
        log_info "Run 'Install BCC & bpftrace' from the BPF Tools menu first."
        echo ""
        read -rp "Press ENTER to continue..." _
        return
    fi

    echo ""
    log_info "Tracing with $tool. Press Ctrl+C to stop."
    echo ""
    "$tool" || true
    echo ""
    read -rp "Press ENTER to continue..." _
}

main() {
    check_root

    while true; do
        echo -e "$CLR"
        echo "╔════════════════════════════════════════════════╗"
        echo "║   Debian/Ubuntu BPF Trace Actions              ║"
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
