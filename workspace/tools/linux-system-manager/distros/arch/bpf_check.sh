#!/bin/bash

set -euo pipefail

# Arch Linux BPF/BCC Readiness Check
# Verifies bpftrace/BCC are installed AND the running kernel actually
# supports BPF tracing (BTF + tracefs) -- package presence alone can't
# tell you a trace action will actually work.

ERROR_COUNT=0
WARN_COUNT=0

# --- Colors ---
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}ℹ${NC}  $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn()    { echo -e "${YELLOW}⚠${NC}  $1"; WARN_COUNT=$((WARN_COUNT + 1)); }
log_error()   { echo -e "${RED}✗${NC} $1"; ERROR_COUNT=$((ERROR_COUNT + 1)); }

section_header() {
    echo ""
    echo -e "${BLUE}━━━ $1 ━━━${NC}"
}

check_bpftrace_binary() {
    section_header "bpftrace"
    if command -v bpftrace &>/dev/null; then
        log_success "bpftrace found: $(command -v bpftrace)"
    else
        log_error "bpftrace not found on PATH"
        log_info "Install with: pacman -S bpftrace"
    fi
}

check_bcc_tools() {
    section_header "BCC Tools"
    if pacman -Qq bcc-tools &>/dev/null || pacman -Qq bcc &>/dev/null; then
        log_success "bcc / bcc-tools package installed"
    else
        log_error "bcc-tools not installed"
        log_info "Install with: pacman -S bcc bcc-tools"
    fi
}

check_kernel_btf() {
    section_header "Kernel BTF Support"
    if [[ -f /sys/kernel/btf/vmlinux ]]; then
        log_success "BTF available at /sys/kernel/btf/vmlinux (CO-RE tracing supported)"
    else
        log_warn "No BTF at /sys/kernel/btf/vmlinux"
        log_info "Legacy BCC tools can still work without BTF; CO-RE-based tools will fail"
    fi
}

check_tracefs() {
    section_header "Tracefs Mount"
    if mountpoint -q /sys/kernel/tracing 2>/dev/null || mountpoint -q /sys/kernel/debug/tracing 2>/dev/null; then
        log_success "tracefs is mounted"
    else
        log_error "tracefs not mounted (checked /sys/kernel/tracing and /sys/kernel/debug/tracing)"
        log_info "Mount with: mount -t tracefs nodev /sys/kernel/tracing"
    fi
}

check_kernel_version() {
    section_header "Kernel Version"
    local kver major minor
    kver=$(uname -r | grep -oE '^[0-9]+\.[0-9]+' || echo "0.0")
    major=${kver%%.*}
    minor=${kver##*.}
    if [[ $major -gt 4 ]] || { [[ $major -eq 4 ]] && [[ $minor -ge 9 ]]; }; then
        log_success "Kernel $(uname -r) meets the 4.9+ floor for BPF tracing"
    else
        log_warn "Kernel $(uname -r) is older than the recommended 4.9 floor"
    fi
}

main() {
    echo "╔════════════════════════════════════════════════╗"
    echo "║   Arch Linux BPF/BCC Readiness Check           ║"
    echo "╚════════════════════════════════════════════════╝"

    check_bpftrace_binary
    check_bcc_tools
    check_kernel_btf
    check_tracefs
    check_kernel_version

    section_header "Summary"
    if [[ $ERROR_COUNT -eq 0 ]]; then
        log_success "System is ready for BPF tracing ($WARN_COUNT warning(s))"
        exit 0
    else
        log_error "System is NOT ready for BPF tracing ($ERROR_COUNT error(s), $WARN_COUNT warning(s))"
        echo ""
        echo "Run 'Install BCC & bpftrace' from the BPF Tools menu, then re-check."
        exit 1
    fi
}

main "$@"
