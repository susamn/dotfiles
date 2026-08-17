#!/bin/bash
set -euo pipefail

# Debian / Ubuntu Pre-Upgrade Preview Script
# Shows what will be upgraded BEFORE you run apt upgrade / apt dist-upgrade
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
      echo "Debian / Ubuntu Pre-Upgrade Preview"
      echo ""
      echo "Usage: $0"
      echo ""
      echo "Shows pending upgrades with focus on boot-critical packages."
      echo "Run this BEFORE 'apt dist-upgrade' to understand upgrade risks."
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
echo "║   Debian / Ubuntu Pre-Upgrade Preview          ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

echo -e "${BLUE}ℹ${NC}  Checking for available updates (this may take a moment)..."
echo ""

# Get all pending updates using apt-get -s upgrade
all_updates_raw=$(apt-get -s upgrade 2>/dev/null | grep "^Inst " || true)

if [[ -z "$all_updates_raw" ]]; then
    # Double check dist-upgrade just in case
    all_updates_raw=$(apt-get -s dist-upgrade 2>/dev/null | grep "^Inst " || true)
fi

if [[ -z "$all_updates_raw" ]]; then
    echo -e "${GREEN}✓${NC} System is fully up-to-date!"
    echo "  No packages need upgrading."
    exit 0
fi

# Parse the updates list into standard format: pkg_name (old_version -> new_version)
all_updates=""
total_count=0
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    
    # regex matches: Inst package [old] (new ...) or Inst package (new ...)
    if [[ "$line" =~ ^Inst\ ([^ ]+)\ \[([^]]+)\]\ \(([^ ]+) ]]; then
        pkg="${BASH_REMATCH[1]}"
        old_ver="${BASH_REMATCH[2]}"
        new_ver="${BASH_REMATCH[3]}"
    elif [[ "$line" =~ ^Inst\ ([^ ]+)\ \(([^ ]+) ]]; then
        pkg="${BASH_REMATCH[1]}"
        old_ver="N/A"
        new_ver="${BASH_REMATCH[2]}"
    else
        pkg=$(echo "$line" | awk '{print $2}')
        old_ver="N/A"
        new_ver="unknown"
    fi
    
    formatted="${pkg} ${old_ver} -> ${new_ver}"
    if [[ -z "$all_updates" ]]; then
        all_updates="$formatted"
    else
        all_updates="${all_updates}
${formatted}"
    fi
    total_count=$((total_count + 1))
done <<< "$all_updates_raw"

echo -e "${CYAN}═══ Total Pending Updates: $total_count packages ═══${NC}"
echo ""

# Extract critical boot-related packages
critical_updates=$(echo "$all_updates" | grep -E 'linux-image|linux-headers|linux-modules|grub|systemd|udev|initramfs-tools|nvidia|dkms' || true)

if [[ -n "$critical_updates" ]]; then
    echo -e "${RED}⚠ CRITICAL: Boot-Related Packages${NC}"
    echo -e "${YELLOW}These require extra caution - validate before reboot!${NC}"
    echo ""
    echo "$critical_updates" | while read -r line; do
        echo "  🔴 $line"
    done
    echo ""

    # Specific warnings
    if echo "$critical_updates" | grep -q "linux-image"; then
        echo -e "${YELLOW}➜${NC} Kernel update detected - after upgrade:"
        echo "  1. Run: sudo debian-boot-check.sh"
        echo "  2. Verify initramfs/initrd was regenerated"
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
        echo "  sudo update-grub"
        echo ""
    fi
else
    echo -e "${GREEN}✓${NC} No critical boot packages in this update"
    echo ""
fi

# Other important packages
important_updates=$(echo "$all_updates" | grep -E '(mesa|xorg|wayland|pipewire|pulseaudio|networkmanager|sudo|openssh|apt|dpkg)' | grep -vE 'linux-image|linux-headers|linux-modules|grub|systemd|udev|initramfs-tools|nvidia|dkms' || true)

if [[ -n "$important_updates" ]]; then
    echo -e "${BLUE}ℹ  Important System Packages${NC}"
    echo ""
    echo "$important_updates" | while read -r line; do
        echo "  🔵 $line"
    done
    echo ""
fi

# Show first 10 remaining packages
other_updates=$(echo "$all_updates" | grep -vE 'linux-image|linux-headers|linux-modules|grub|systemd|udev|initramfs-tools|nvidia|dkms|mesa|xorg|wayland|pipewire|pulseaudio|networkmanager|sudo|openssh|apt|dpkg' || true)
other_count=0
if [[ -n "$other_updates" ]]; then
    other_count=$(echo "$other_updates" | wc -l)
fi

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
    echo "  1. Create backup: ./debian-boot-backup.sh"
    if command -v timeshift &> /dev/null; then
        echo "  2. Create Timeshift snapshot: sudo timeshift --create"
    fi
    echo "  3. Ensure /boot is mounted: mount | grep /boot"
    echo "  4. Check disk space: df -h /boot"
    echo ""

    echo -e "${YELLOW}To upgrade:${NC}"
    echo "  sudo apt update && sudo apt dist-upgrade"
    echo ""

    echo -e "${YELLOW}After upgrading (BEFORE reboot):${NC}"
    echo "  1. Check dpkg logs: tail -50 /var/log/dpkg.log"
    echo "  2. Run safety check: sudo debian-boot-check.sh"
    echo "  3. If safe, reboot"
    echo ""
else
    echo -e "${GREEN}This appears to be a routine upgrade.${NC}"
    echo ""
    echo "To upgrade:"
    echo "  sudo apt update && sudo apt upgrade"
    echo ""
fi

# Check current running kernel vs installed
current_kernel=$(uname -r)
# Find the highest version kernel package installed
installed_kernel=$(dpkg-query -W -f='${Status} ${Package} ${Version}\n' | grep '^install ok installed' | awk '{print $4" ("$5")"}' | grep -E "^linux-image-[0-9]" | sort -V | tail -1 || echo "")

if [[ -n "$installed_kernel" ]]; then
    echo -e "${CYAN}═══ Kernel Status ═══${NC}"
    echo "  Running: $current_kernel"
    echo "  Installed: $installed_kernel"
    echo ""
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
