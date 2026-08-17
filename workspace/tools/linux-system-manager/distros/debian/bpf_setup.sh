#!/bin/bash

set -euo pipefail

# Debian/Ubuntu BPF/BCC Installation
# Installs bpftrace, BCC and matching kernel headers from official repos
# only. Run "Check BPF Readiness" afterwards to verify.

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}ℹ${NC}  $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn()    { echo -e "${YELLOW}⚠${NC}  $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_info "This script requires root privileges. Re-running with sudo..."
        exec sudo -- "$0"
    fi
}

install_bpf_tools() {
    log_info "Updating package index..."
    apt-get update -qq

    log_info "Installing bpftrace and bpfcc-tools via apt..."
    if apt-get install -y bpftrace bpfcc-tools; then
        log_success "bpftrace and bpfcc-tools installed"
    else
        log_error "apt install failed"
        exit 1
    fi

    local headers_pkg="linux-headers-$(uname -r)"
    if apt-cache show "$headers_pkg" &>/dev/null; then
        log_info "Installing matching kernel headers ($headers_pkg)..."
        if apt-get install -y "$headers_pkg"; then
            log_success "$headers_pkg installed"
        else
            log_warn "$headers_pkg failed to install; legacy (non-CO-RE) BCC tools may not work"
        fi
    else
        log_warn "$headers_pkg not found in repos; legacy (non-CO-RE) BCC tools may not work"
    fi
}

main() {
    echo "╔════════════════════════════════════════════════╗"
    echo "║   Debian/Ubuntu BPF/BCC Installation           ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""

    check_root
    install_bpf_tools

    echo ""
    log_success "Done. Run 'Check BPF Readiness' to verify the machine is ready."
}

main "$@"
