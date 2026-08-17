#!/bin/bash
set -euo pipefail

MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

{
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                                                              ║${NC}"
    echo -e "${MAGENTA}║        Understanding the Boot Process                       ║${NC}"
    echo -e "${MAGENTA}║                                                              ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${YELLOW}━━━ What Happens When You Boot Your Computer? ━━━${NC}"
    echo ""
    echo -e "${CYAN}1. FIRMWARE (BIOS/UEFI)${NC} → ${CYAN}2. BOOTLOADER (GRUB)${NC} → ${CYAN}3. KERNEL${NC} → ${CYAN}4. INITRAMFS${NC} → ${CYAN}5. YOUR SYSTEM${NC}"
    echo ""
    echo -e "${GREEN}💡 Tip:${NC} These tools catch boot errors ${YELLOW}BEFORE${NC} you reboot!"
    echo ""
    echo -e "${CYAN}Controls: Arrow keys or j/k to scroll, q to exit, / to search${NC}"
    echo ""
    echo "Press 'q' to return..."
} | less -R
