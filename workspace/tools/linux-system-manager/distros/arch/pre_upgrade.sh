#!/bin/bash

set -euo pipefail

# Arch Linux Pre-Upgrade Preview Script
# Shows what will be upgraded BEFORE you run pacman -Syu
# Helps you understand if kernel/boot-critical packages will be updated

# --- Colors ---
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      echo "Arch Linux Pre-Upgrade Preview"
      echo ""
      echo "Usage: $0"
      echo ""
      echo "Shows pending upgrades with focus on boot-critical packages."
      echo "Run this BEFORE 'pacman -Syu' to understand upgrade risks."
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

echo "╔════════════════════════════════════════════════╗"
echo "║   Arch Linux Pre-Upgrade Preview              ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# Check if checkupdates is available
if ! command -v checkupdates &> /dev/null; then
    echo -e "${RED}✗${NC} checkupdates not found (install pacman-contrib)"
    echo "  sudo pacman -S pacman-contrib"
    exit 1
fi

echo -e "${BLUE}ℹ${NC}  Checking for available updates (this may take a moment)..."
echo ""

# Get all pending updates
all_updates=$(checkupdates 2>/dev/null || true)

# Handle checkupdates failure vs no updates
if [[ $? -ne 0 ]] && [[ -z "$all_updates" ]]; then
    echo -e "${YELLOW}⚠${NC}  Could not check for updates. Ensure pacman database is synced."
    echo "  Run: sudo pacman -Sy"
    exit 1
fi

if [[ -z "$all_updates" ]]; then
    echo -e "${GREEN}✓${NC} System is fully up-to-date!"
    echo "  No packages need upgrading."
    exit 0
fi

# Count total updates
total_count=$(echo "$all_updates" | wc -l)

echo -e "${CYAN}═══ Total Pending Updates: $total_count packages ═══${NC}"
echo ""

# Extract critical boot-related packages
critical_updates=$(echo "$all_updates" | grep -E '^(linux\b|linux-lts|linux-zen|linux-hardened|linux-headers|mkinitcpio|grub|systemd|nvidia|dkms)' || true)

if [[ -n "$critical_updates" ]]; then
    echo -e "${RED}⚠ CRITICAL: Boot-Related Packages${NC}"
    echo -e "${YELLOW}These require extra caution - validate before reboot!${NC}"
    echo ""
    echo "$critical_updates" | while read -r line; do
        echo "  🔴 $line"
    done
    echo ""

    # Specific warnings
    if echo "$critical_updates" | grep -q "^linux "; then
        echo -e "${YELLOW}➜${NC} Kernel update detected - after upgrade:"
        echo "  1. Run: sudo arch-boot-check.sh"
        echo "  2. Verify initramfs was regenerated"
        echo "  3. Check GRUB config updated"
        echo ""
    fi

    if echo "$critical_updates" | grep -q "nvidia"; then
        echo -e "${YELLOW}➜${NC} NVIDIA driver update - ensure you have:"
        echo "  • linux-headers installed"
        echo "  • dkms working properly"
        echo ""
    fi

    if echo "$critical_updates" | grep -q "grub"; then
        echo -e "${YELLOW}➜${NC} GRUB update - after upgrade run:"
        echo "  sudo grub-mkconfig -o /boot/grub/grub.cfg"
        echo ""
    fi
else
    echo -e "${GREEN}✓${NC} No critical boot packages in this update"
    echo ""
fi

# Other important packages
important_updates=$(echo "$all_updates" | grep -E '^(mesa|xorg|wayland|pipewire|pulseaudio|networkmanager|sudo|openssh)' || true)

if [[ -n "$important_updates" ]]; then
    echo -e "${BLUE}ℹ  Important System Packages${NC}"
    echo ""
    echo "$important_updates" | while read -r line; do
        echo "  🔵 $line"
    done
    echo ""
fi

# Show first 10 remaining packages
other_updates=$(echo "$all_updates" | grep -vE '^(linux|mkinitcpio|grub|systemd|nvidia|dkms|mesa|xorg|wayland|pipewire|pulseaudio|networkmanager|sudo|openssh)' || true)
other_count=$(echo "$other_updates" | wc -l)

if [[ $other_count -gt 0 ]]; then
    echo -e "${BLUE}ℹ  Other Packages ($other_count total)${NC}"
    echo ""
    echo "$other_updates" | head -10 | while read -r line; do
        echo "  • $line"
    done

    if [[ $other_count -gt 10 ]]; then
        echo "  ... and $((other_count - 10)) more"
    fi
    echo ""
fi

# Pre-upgrade recommendations
echo -e "${CYAN}═══ Recommended Actions ═══${NC}"
echo ""

if [[ -n "$critical_updates" ]]; then
    echo -e "${YELLOW}Before upgrading:${NC}"
    echo "  1. Create backup: ./arch-boot-backup.sh"
    if command -v timeshift &> /dev/null; then
        echo "  2. Create Timeshift snapshot: sudo timeshift --create"
    fi
    echo "  3. Ensure /boot is mounted: mount | grep /boot"
    echo "  4. Check disk space: df -h /boot"
    echo ""

    echo -e "${YELLOW}To upgrade:${NC}"
    echo "  sudo pacman -Syu"
    echo ""

    echo -e "${YELLOW}After upgrading (BEFORE reboot):${NC}"
    echo "  1. Check pacman logs: tail -50 /var/log/pacman.log"
    echo "  2. Run safety check: sudo arch-boot-check.sh"
    echo "  3. If safe, reboot"
    echo ""
else
    echo -e "${GREEN}This appears to be a routine upgrade.${NC}"
    echo ""
    echo "To upgrade:"
    echo "  sudo pacman -Syu"
    echo ""
fi

# Check current running kernel vs installed
current_kernel=$(uname -r)
installed_kernel=$(pacman -Q linux 2>/dev/null | awk '{print $2}' || echo "")

if [[ -n "$installed_kernel" ]]; then
    echo -e "${CYAN}═══ Kernel Status ═══${NC}"
    echo "  Running: $current_kernel"
    echo "  Installed: $installed_kernel"

    if [[ -n "$critical_updates" ]] && echo "$critical_updates" | grep -q "^linux "; then
        # More robust kernel version extraction
        new_kernel=$(echo "$critical_updates" | awk '/^linux / {for(i=1; i<=NF; i++) if ($i == "->") { print $(i+1); break } }' | head -1 || echo "unknown")
        if [[ -n "$new_kernel" ]] && [[ "$new_kernel" != "unknown" ]]; then
            echo "  Will upgrade to: $new_kernel"
            echo ""
            echo -e "${YELLOW}Note: Reboot required to use new kernel${NC}"
        fi
    fi
    echo ""
else
    # Check for other kernel variants (linux-lts, linux-zen, etc.)
    # Not `local`: this is top-level code, and `local` outside a function is a
    # runtime error that aborts the script under `set -e`.
    any_kernel=$(pacman -Q 2>/dev/null | grep '^linux ' | head -1 | awk '{print $1":"$2}' || echo "")
    if [[ -n "$any_kernel" ]]; then
        echo -e "${CYAN}═══ Kernel Status ═══${NC}"
        echo "  Running: $current_kernel"
        echo "  Installed: $any_kernel"
        echo ""
    fi
fi

# Final summary
if [[ -n "$critical_updates" ]]; then
    echo -e "${RED}⚠ HIGH RISK UPGRADE${NC}"
    echo "Boot-critical packages will be updated. Follow precautions above."
else
    echo -e "${GREEN}✓ LOW RISK UPGRADE${NC}"
    echo "No boot-critical packages detected. Safe to proceed."
fi

exit 0
