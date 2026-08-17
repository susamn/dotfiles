#!/bin/bash

set -euo pipefail

# Arch Linux BPF/BCC Installation
# Installs bpftrace and BCC from official repos only -- no AUR, no
# source builds. Run "Check BPF Readiness" afterwards to verify.

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}ℹ${NC}  $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_info "This script requires root privileges. Re-running with sudo..."
        exec sudo -- "$0"
    fi
}

install_bpf_tools() {
    log_info "Installing bpftrace, bcc and bcc-tools via pacman..."
    if pacman -Sy --needed --noconfirm bpftrace bcc bcc-tools; then
        log_success "bpftrace, bcc and bcc-tools installed"
    else
        log_error "pacman install failed"
        exit 1
    fi
}

main() {
    echo "╔════════════════════════════════════════════════╗"
    echo "║   Arch Linux BPF/BCC Installation              ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""

    check_root
    install_bpf_tools

    echo ""
    log_success "Done. Run 'Check BPF Readiness' to verify the machine is ready."
}

main "$@"
