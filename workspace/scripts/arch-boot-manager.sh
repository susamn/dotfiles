#!/bin/bash

set -euo pipefail

# Arch Linux Boot Safety Manager
# Interactive menu to run all boot safety tools

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRE_UPGRADE_SCRIPT="${SCRIPT_DIR}/arch-pre-upgrade.sh"
BOOT_CHECK_SCRIPT="${SCRIPT_DIR}/arch-boot-check.sh"
BACKUP_SCRIPT="${SCRIPT_DIR}/arch-boot-backup.sh"
TIMELINE_SCRIPT="${SCRIPT_DIR}/arch-package-timeline.sh"

# --- Colors ---
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# --- Helper Functions ---
print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                              ║${NC}"
    echo -e "${CYAN}║        ${MAGENTA}Arch Linux Boot Safety Manager${CYAN}                    ║${NC}"
    echo -e "${CYAN}║                                                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

pause() {
    echo ""
    read -p "Press ENTER to continue..." -r
}

run_command() {
    local desc="$1"
    shift
    local cmd=("$@")

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Running: $desc${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    "${cmd[@]}"
    local exit_code=$?

    echo ""
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ Completed successfully${NC}"
    else
        echo -e "${RED}✗ Command exited with code: $exit_code${NC}"
    fi

    return $exit_code
}

# --- Main Menu ---
show_main_menu() {
    print_header
    echo -e "${CYAN}═══ Main Menu ═══${NC}"
    echo ""
    echo -e "  ${MAGENTA}Q${NC}) ${YELLOW}⚡ Quick Check - Is it safe to reboot?${NC}"
    echo -e "  ${MAGENTA}G${NC}) ${YELLOW}📋 View GRUB Config & Menu Entries${NC}"
    echo -e "  ${MAGENTA}T${NC}) ${YELLOW}📸 List Timeshift Snapshots${NC}"
    echo -e "  ${MAGENTA}P${NC}) ${YELLOW}📦 View Package Timeline - Installation history${NC}"
    echo -e "  ${MAGENTA}H${NC}) ${YELLOW}📖 Boot Process Help - Understand how boot works${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}) ${BLUE}Pre-Upgrade Preview${NC} - See what will be updated"
    echo -e "  ${GREEN}2${NC}) ${BLUE}Boot Safety Check (Auto-Fix)${NC} - Validate and fix issues ${RED}[modifies system]${NC}"
    echo -e "  ${GREEN}3${NC}) ${BLUE}Create Boot Backup${NC} - Backup boot configuration"
    echo -e "  ${GREEN}4${NC}) ${BLUE}List Backups${NC} - Show all available backups"
    echo -e "  ${GREEN}5${NC}) ${BLUE}Restore from Backup${NC} - Restore boot configuration ${RED}[modifies system]${NC}"
    echo ""
    echo -e "  ${YELLOW}6${NC}) ${MAGENTA}Complete Upgrade Workflow${NC} - Guided upgrade process"
    echo ""
    echo -e "  ${GREEN}7${NC}) ${BLUE}Install Tools${NC} - Install scripts system-wide ${RED}[modifies system]${NC}"
    echo -e "  ${GREEN}8${NC}) ${BLUE}View Documentation${NC} - Browse help files"
    echo ""
    echo -e "  ${RED}0${NC}) Exit"
    echo ""
    echo -ne "${CYAN}Select option:${NC} "
}

# --- Menu Actions ---

action_boot_help() {
    # Generate the help content and pipe to less with color support
    {
        echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${MAGENTA}║                                                              ║${NC}"
        echo -e "${MAGENTA}║        Understanding the Boot Process                       ║${NC}"
        echo -e "${MAGENTA}║                                                              ║${NC}"
        echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # ━━━ Boot Process Flow ━━━
        echo -e "${YELLOW}━━━ What Happens When You Boot Your Computer? ━━━${NC}"
        echo ""

        echo -e "${CYAN}1. FIRMWARE (BIOS/UEFI)${NC}"
        echo -e "   ${BLUE}•${NC} Your motherboard's firmware starts first"
        echo -e "   ${BLUE}•${NC} Looks for a bootloader on your disk"
        echo ""

        echo -e "${CYAN}2. BOOTLOADER (GRUB)${NC}"
        echo -e "   ${BLUE}•${NC} GRUB shows you the menu with kernel choices"
        echo -e "   ${BLUE}•${NC} Loads the kernel you select"
        echo ""

        echo -e "${CYAN}3. KERNEL (vmlinuz-*)${NC}"
        echo -e "   ${BLUE}•${NC} The Linux kernel itself - the core of the OS"
        echo -e "   ${BLUE}•${NC} Needs help from initramfs to start"
        echo ""

        echo -e "${CYAN}4. INITRAMFS (initramfs-*.img)${NC}"
        echo -e "   ${BLUE}•${NC} Temporary filesystem loaded into RAM"
        echo -e "   ${BLUE}•${NC} Contains drivers needed to mount your real root filesystem"
        echo -e "   ${BLUE}•${NC} Hands control to your actual system"
        echo ""

        echo -e "${CYAN}5. YOUR SYSTEM${NC}"
        echo -e "   ${BLUE}•${NC} Root filesystem mounted"
        echo -e "   ${BLUE}•${NC} systemd/init starts services"
        echo -e "   ${BLUE}•${NC} You get a login screen"
        echo ""

        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # ━━━ Important Files ━━━
        echo -e "${YELLOW}━━━ Important Files Explained ━━━${NC}"
        echo ""

        echo -e "${GREEN}📁 /boot/vmlinuz-linux${NC}"
        echo -e "   ${CYAN}What it is:${NC}"
        echo -e "   ${BLUE}•${NC} The Linux kernel (compressed)"
        echo -e "   ${BLUE}•${NC} vmlinuz = ${MAGENTA}V${NC}irtual ${MAGENTA}M${NC}emory ${MAGENTA}LINU${NC}x g${MAGENTA}Z${NC}ipped"
        echo -e "   ${BLUE}•${NC} This is the actual operating system kernel"
        echo -e "   ${BLUE}•${NC} Created when you install a kernel package"
        echo ""
        echo -e "   ${CYAN}Examples:${NC} ${YELLOW}vmlinuz-linux${NC}, ${YELLOW}vmlinuz-linux-lts${NC}"
        echo -e "   ${CYAN}Why multiple?${NC} Different kernel versions as fallbacks!"
        echo ""

        echo -e "${GREEN}📁 /boot/initramfs-linux.img${NC}"
        echo -e "   ${CYAN}What it is:${NC}"
        echo -e "   ${BLUE}•${NC} ${MAGENTA}Init${NC}ial ${MAGENTA}RAM${NC} ${MAGENTA}F${NC}ile${MAGENTA}S${NC}ystem"
        echo -e "   ${BLUE}•${NC} Contains drivers needed at boot time"
        echo -e "   ${BLUE}•${NC} Helps kernel mount your root partition"
        echo -e "   ${BLUE}•${NC} Generated by ${YELLOW}mkinitcpio${NC}"
        echo ""
        echo -e "   ${CYAN}Why needed?${NC}"
        echo -e "   Your kernel needs drivers to read your disk, but those"
        echo -e "   drivers are ON that disk - chicken & egg problem!"
        echo -e "   ${GREEN}initramfs solves this!${NC}"
        echo ""

        echo -e "${GREEN}📁 /boot/initramfs-linux-fallback.img${NC}"
        echo -e "   ${BLUE}•${NC} Fallback version with ${YELLOW}MORE${NC} drivers"
        echo -e "   ${BLUE}•${NC} Slower to boot but more compatible"
        echo -e "   ${BLUE}•${NC} Used if normal initramfs fails"
        echo ""

        echo -e "${GREEN}📁 /boot/grub/grub.cfg${NC}"
        echo -e "   ${BLUE}•${NC} GRUB's configuration file"
        echo -e "   ${BLUE}•${NC} Lists all available kernels"
        echo -e "   ${BLUE}•${NC} Tells GRUB how to boot each one"
        echo -e "   ${BLUE}•${NC} Generated by ${YELLOW}grub-mkconfig${NC}"
        echo ""

        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # ━━━ Commands Explained ━━━
        echo -e "${YELLOW}━━━ What Do These Commands Do? ━━━${NC}"
        echo ""

        echo -e "${GREEN}🔧 mkinitcpio -P${NC}"
        echo ""
        echo -e "   ${CYAN}What it does:${NC}"
        echo -e "   ${BLUE}•${NC} Generates initramfs files for ${YELLOW}ALL${NC} installed kernels"
        echo -e "   ${BLUE}•${NC} Reads ${MAGENTA}/etc/mkinitcpio.conf${NC} for configuration"
        echo -e "   ${BLUE}•${NC} Includes necessary drivers/modules"
        echo ""
        echo -e "   ${CYAN}When to run:${NC}"
        echo -e "   ${BLUE}•${NC} After kernel upgrade (usually automatic via hook)"
        echo -e "   ${BLUE}•${NC} After changing ${MAGENTA}/etc/mkinitcpio.conf${NC}"
        echo -e "   ${BLUE}•${NC} When initramfs is missing or corrupted"
        echo ""
        echo -e "   ${CYAN}Example output:${NC}"
        echo -e "   ${BLUE}==>${NC} Building image from preset: /etc/mkinitcpio.d/linux.preset"
        echo -e "   ${BLUE}==>${NC} Building image: /boot/initramfs-linux.img"
        echo -e "   ${GREEN}✓${NC} Creates /boot/initramfs-linux.img"
        echo -e "   ${GREEN}✓${NC} Creates /boot/initramfs-linux-fallback.img"
        echo ""

        echo -e "${GREEN}🔧 grub-mkconfig -o /boot/grub/grub.cfg${NC}"
        echo ""
        echo -e "   ${CYAN}What it does:${NC}"
        echo -e "   ${BLUE}•${NC} Scans ${YELLOW}/boot${NC} for kernels"
        echo -e "   ${BLUE}•${NC} Reads ${MAGENTA}/etc/default/grub${NC} for settings"
        echo -e "   ${BLUE}•${NC} Generates menu entries for each kernel"
        echo -e "   ${BLUE}•${NC} Writes to ${MAGENTA}/boot/grub/grub.cfg${NC}"
        echo ""
        echo -e "   ${CYAN}When to run:${NC}"
        echo -e "   ${BLUE}•${NC} After kernel installation/removal"
        echo -e "   ${BLUE}•${NC} After changing GRUB settings in ${MAGENTA}/etc/default/grub${NC}"
        echo -e "   ${BLUE}•${NC} When GRUB menu doesn't show new kernels"
        echo ""
        echo -e "   ${CYAN}Example output:${NC}"
        echo -e "   Generating grub configuration file ..."
        echo -e "   ${GREEN}Found${NC} linux image: ${YELLOW}/boot/vmlinuz-linux${NC}"
        echo -e "   ${GREEN}Found${NC} initrd image: ${YELLOW}/boot/initramfs-linux.img${NC}"
        echo -e "   ${GREEN}Found${NC} fallback initrd: ${YELLOW}/boot/initramfs-linux-fallback.img${NC}"
        echo ""

        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # ━━━ Common Problems ━━━
        echo -e "${YELLOW}━━━ Common Boot Problems & Solutions ━━━${NC}"
        echo ""

        echo -e "${RED}❌ Problem:${NC} ${YELLOW}\"Error: file '/boot/vmlinuz-linux' not found\"${NC}"
        echo -e "   ${CYAN}Cause:${NC} Kernel file missing or /boot not mounted"
        echo -e "   ${GREEN}Fix:${NC}"
        echo -e "   ${BLUE}1.${NC} Mount /boot: ${YELLOW}sudo mount /boot${NC}"
        echo -e "   ${BLUE}2.${NC} Reinstall kernel: ${YELLOW}sudo pacman -S linux${NC}"
        echo -e "   ${BLUE}3.${NC} Regenerate GRUB: ${YELLOW}sudo grub-mkconfig -o /boot/grub/grub.cfg${NC}"
        echo ""

        echo -e "${RED}❌ Problem:${NC} ${YELLOW}\"ERROR: device 'UUID=...' not found\"${NC}"
        echo -e "   ${CYAN}Cause:${NC} initramfs doesn't have drivers for your filesystem"
        echo -e "   ${GREEN}Fix:${NC}"
        echo -e "   ${BLUE}1.${NC} Edit ${MAGENTA}/etc/mkinitcpio.conf${NC}"
        echo -e "   ${BLUE}2.${NC} Add needed modules: ${YELLOW}MODULES=(vfat btrfs)${NC}"
        echo -e "   ${BLUE}3.${NC} Regenerate: ${YELLOW}sudo mkinitcpio -P${NC}"
        echo ""

        echo -e "${RED}❌ Problem:${NC} ${YELLOW}\"unknown filesystem vfat\"${NC} ${RED}(YOUR ISSUE!)${NC}"
        echo -e "   ${CYAN}Cause:${NC} vfat module missing from initramfs"
        echo -e "   ${GREEN}Fix:${NC}"
        echo -e "   ${BLUE}1.${NC} Edit ${MAGENTA}/etc/mkinitcpio.conf${NC}"
        echo -e "   ${BLUE}2.${NC} Add: ${YELLOW}MODULES=(vfat)${NC}"
        echo -e "   ${BLUE}3.${NC} Regenerate: ${YELLOW}sudo mkinitcpio -P${NC}"
        echo -e "   ${BLUE}4.${NC} Verify: ${YELLOW}lsinitcpio /boot/initramfs-linux.img | grep vfat${NC}"
        echo ""

        echo -e "${RED}❌ Problem:${NC} ${YELLOW}GRUB menu doesn't show new kernel${NC}"
        echo -e "   ${CYAN}Cause:${NC} GRUB config not updated"
        echo -e "   ${GREEN}Fix:${NC} ${YELLOW}sudo grub-mkconfig -o /boot/grub/grub.cfg${NC}"
        echo ""

        echo -e "${RED}❌ Problem:${NC} ${YELLOW}System boots to emergency shell${NC}"
        echo -e "   ${CYAN}Cause:${NC} Root filesystem can't be mounted"
        echo -e "   ${GREEN}Fix:${NC}"
        echo -e "   ${BLUE}1.${NC} Check ${MAGENTA}/etc/fstab${NC} for correct UUIDs"
        echo -e "   ${BLUE}2.${NC} Ensure filesystem drivers in initramfs"
        echo -e "   ${BLUE}3.${NC} Regenerate: ${YELLOW}sudo mkinitcpio -P${NC}"
        echo ""

        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # ━━━ Config Files ━━━
        echo -e "${YELLOW}━━━ Configuration Files ━━━${NC}"
        echo ""

        echo -e "${GREEN}📄 /etc/mkinitcpio.conf${NC}"
        echo -e "   ${CYAN}Purpose:${NC} Controls what goes ${YELLOW}INTO${NC} your initramfs"
        echo ""
        echo -e "   ${CYAN}Key settings:${NC}"
        echo -e "   ${BLUE}•${NC} ${YELLOW}MODULES=(vfat btrfs)${NC}  ${BLUE}←${NC} Drivers to include"
        echo -e "   ${BLUE}•${NC} ${YELLOW}HOOKS=(base udev...)${NC}  ${BLUE}←${NC} Features to enable"
        echo -e "   ${BLUE}•${NC} ${YELLOW}FILES=()${NC}              ${BLUE}←${NC} Extra files to include"
        echo ""
        echo -e "   ${CYAN}Edit this if:${NC} You need specific drivers at boot time"
        echo ""

        echo -e "${GREEN}📄 /etc/default/grub${NC}"
        echo -e "   ${CYAN}Purpose:${NC} Controls GRUB behavior"
        echo ""
        echo -e "   ${CYAN}Key settings:${NC}"
        echo -e "   ${BLUE}•${NC} ${YELLOW}GRUB_TIMEOUT=5${NC}        ${BLUE}←${NC} Menu timeout (seconds)"
        echo -e "   ${BLUE}•${NC} ${YELLOW}GRUB_DEFAULT=0${NC}        ${BLUE}←${NC} Which entry boots by default"
        echo -e "   ${BLUE}•${NC} ${YELLOW}GRUB_CMDLINE_LINUX=\"\"${NC} ${BLUE}←${NC} Kernel boot parameters"
        echo ""
        echo -e "   ${CYAN}After editing:${NC} Run ${YELLOW}grub-mkconfig -o /boot/grub/grub.cfg${NC}"
        echo ""

        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # ━━━ Quick Reference ━━━
        echo -e "${YELLOW}━━━ Quick Reference Commands ━━━${NC}"
        echo ""

        echo -e "${CYAN}Check what you have:${NC}"
        echo -e "   ${BLUE}•${NC} ${YELLOW}ls -lh /boot/vmlinuz-*${NC}      ${BLUE}←${NC} See installed kernels"
        echo -e "   ${BLUE}•${NC} ${YELLOW}ls -lh /boot/initramfs-*${NC}    ${BLUE}←${NC} See initramfs files"
        echo -e "   ${BLUE}•${NC} ${YELLOW}grep menuentry /boot/grub/grub.cfg${NC}  ${BLUE}←${NC} See GRUB menu entries"
        echo ""

        echo -e "${CYAN}Regenerate everything:${NC}"
        echo -e "   ${BLUE}•${NC} ${YELLOW}sudo mkinitcpio -P${NC}                          ${BLUE}←${NC} Rebuild initramfs"
        echo -e "   ${BLUE}•${NC} ${YELLOW}sudo grub-mkconfig -o /boot/grub/grub.cfg${NC}  ${BLUE}←${NC} Rebuild GRUB menu"
        echo ""

        echo -e "${CYAN}Inspect initramfs contents:${NC}"
        echo -e "   ${BLUE}•${NC} ${YELLOW}lsinitcpio /boot/initramfs-linux.img${NC}       ${BLUE}←${NC} See what's inside"
        echo -e "   ${BLUE}•${NC} ${YELLOW}lsinitcpio /boot/initramfs-linux.img | grep vfat${NC}  ${BLUE}←${NC} Find vfat module"
        echo ""

        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        echo -e "${GREEN}💡 Tip:${NC} These tools would have caught the 'unknown filesystem vfat'"
        echo -e "       error ${YELLOW}BEFORE${NC} you rebooted!"
        echo ""
        echo -e "${CYAN}Controls: Arrow keys or j/k to scroll, q to exit, / to search${NC}"
        echo ""

    } | less -R
}

action_quick_check() {
    if [[ ! -x "$BOOT_CHECK_SCRIPT" ]]; then
        echo -e "${RED}✗ Script not found or not executable: $BOOT_CHECK_SCRIPT${NC}"
        pause
        return 1
    fi

    print_header
    echo -e "${YELLOW}⚡ Quick Check - Is it safe to reboot?${NC}"
    echo ""
    echo -e "${CYAN}Running boot safety validation...${NC}"
    echo ""

    if [[ $EUID -ne 0 ]]; then
        sudo "$BOOT_CHECK_SCRIPT"
    else
        "$BOOT_CHECK_SCRIPT"
    fi

    local check_result=$?
    echo ""

    # Simple yes/no verdict
    if [[ $check_result -eq 0 ]]; then
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                                                              ║${NC}"
        echo -e "${GREEN}║                  ✓✓✓ YES - SAFE TO REBOOT ✓✓✓                ║${NC}"
        echo -e "${GREEN}║                                                              ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                                                              ║${NC}"
        echo -e "${RED}║                  ✗✗✗ NO - DO NOT REBOOT ✗✗✗                  ║${NC}"
        echo -e "${RED}║                                                              ║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Recommendation:${NC} Run option 2 (Auto-Fix) to attempt repairs,"
        echo -e "               or review the errors above and fix manually."
    fi

    pause
}

action_list_timeshift() {
    print_header
    echo -e "${CYAN}═══ System Snapshots (Timeshift & BTRFS) ═══${NC}"
    echo ""

    local has_timeshift=false
    local has_btrfs=false

    # Check if Timeshift is installed
    if command -v timeshift &> /dev/null; then
        has_timeshift=true
    fi

    # Check if using BTRFS with snapshots
    if command -v btrfs &> /dev/null; then
        # Check if root is btrfs
        local root_fs=$(findmnt -n -o FSTYPE /)
        if [[ "$root_fs" == "btrfs" ]]; then
            has_btrfs=true
        fi
    fi

    # If neither available
    if [[ "$has_timeshift" == "false" ]] && [[ "$has_btrfs" == "false" ]]; then
        echo -e "${YELLOW}⚠ No snapshot tools detected${NC}"
        echo ""
        echo -e "${CYAN}Install Timeshift:${NC}"
        echo "  sudo pacman -S timeshift"
        echo ""
        echo -e "${CYAN}Or use BTRFS snapshots:${NC}"
        echo "  Requires BTRFS filesystem and snapper/timeshift-autosnap"
        echo ""
        pause
        return 1
    fi

    # Show Timeshift snapshots
    if [[ "$has_timeshift" == "true" ]]; then
        echo -e "${BLUE}━━━ Timeshift Snapshots ━━━${NC}"
        echo ""
        echo -e "${CYAN}Fetching Timeshift snapshots...${NC}"
        echo ""

        # Get snapshot list (requires sudo)
        local snapshot_output
        if [[ $EUID -eq 0 ]]; then
            snapshot_output=$(timeshift --list 2>/dev/null)
        else
            snapshot_output=$(sudo timeshift --list 2>/dev/null)
        fi

    if [[ -z "$snapshot_output" ]]; then
        echo -e "${YELLOW}⚠ No snapshots found or unable to read Timeshift data${NC}"
        echo ""
        echo -e "${CYAN}Create your first snapshot with:${NC}"
        echo "  sudo timeshift --create --comments 'Before upgrade'"
        echo ""
        pause
        return 0
    fi

    # Parse and display snapshots
    local snapshots=$(echo "$snapshot_output" | grep "^>" || true)
    local snapshot_count=0
    if [[ -n "$snapshots" ]]; then
        snapshot_count=$(echo "$snapshots" | wc -l)
    fi

    if [[ $snapshot_count -eq 0 ]]; then
        echo -e "${YELLOW}⚠ No snapshots available${NC}"
        echo ""
        echo -e "${CYAN}Create a snapshot before risky upgrades:${NC}"
        echo "  sudo timeshift --create --comments 'Description here'"
        echo ""
    else
        echo -e "${GREEN}Found $snapshot_count snapshot(s):${NC}"
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # Display each snapshot with formatting
        local counter=1
        while IFS= read -r line; do
            if [[ "$line" =~ ^\> ]]; then
                # Extract snapshot details
                local snapshot_info=$(echo "$line" | sed 's/^> //')

                echo -e "${CYAN}Snapshot $counter:${NC}"
                echo "  $snapshot_info"
                echo ""
                ((counter++))
            fi
        done <<< "$snapshot_output"

        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi

    echo ""

    # Show most recent snapshot
    local most_recent=$(echo "$snapshots" | head -1 | sed 's/^> //')
    if [[ -n "$most_recent" ]]; then
        echo -e "${GREEN}Most recent snapshot:${NC}"
        echo "  $most_recent"
        echo ""
    fi

    # Disk usage info
    echo -e "${BLUE}━━━ Disk Usage ━━━${NC}"
    echo ""

    local snapshot_location="/run/timeshift/backup"
    if [[ -d "$snapshot_location" ]]; then
        local usage=$(du -sh "$snapshot_location" 2>/dev/null | cut -f1)
        if [[ -n "$usage" ]]; then
            echo -e "${CYAN}Snapshot storage:${NC} $usage"
        fi
    fi

    # Check available space on timeshift device
    local timeshift_device=$(echo "$snapshot_output" | grep "Device :" | head -1 | awk '{print $3}' || true)
    if [[ -n "$timeshift_device" ]]; then
        local avail_space=$(df -h "$timeshift_device" 2>/dev/null | awk 'NR==2 {print $4}')
        if [[ -n "$avail_space" ]]; then
            echo -e "${CYAN}Available space:${NC} $avail_space"
        fi
    fi

    echo ""

    # Quick actions
    echo -e "${BLUE}━━━ Quick Actions ━━━${NC}"
    echo ""
    echo -e "${CYAN}Create a new snapshot:${NC}"
    echo "  sudo timeshift --create --comments 'Before kernel update'"
    echo ""
    echo -e "${CYAN}Restore from a snapshot:${NC}"
    echo "  sudo timeshift --restore"
    echo ""
        echo -e "${YELLOW}Note:${NC} Timeshift may not backup /boot or EFI partition!"
        echo "      Use option 4 (Create Boot Backup) for boot configs."
        echo ""
    fi

    # Show BTRFS snapshots
    if [[ "$has_btrfs" == "true" ]]; then
        echo -e "${BLUE}━━━ BTRFS Snapshots ━━━${NC}"
        echo ""

        # Try to list BTRFS snapshots
        local btrfs_snapshots
        if [[ $EUID -eq 0 ]]; then
            btrfs_snapshots=$(btrfs subvolume list / 2>/dev/null | grep -i snapshot || true)
        else
            btrfs_snapshots=$(sudo btrfs subvolume list / 2>/dev/null | grep -i snapshot || true)
        fi

        if [[ -z "$btrfs_snapshots" ]]; then
            echo -e "${YELLOW}⚠ No BTRFS snapshots found${NC}"
            echo ""
            echo -e "${CYAN}Using BTRFS? Consider:${NC}"
            echo "  • Snapper - automatic snapshot management"
            echo "  • Timeshift (BTRFS mode) - user-friendly GUI"
            echo "  • Manual: sudo btrfs subvolume snapshot / /.snapshots/backup"
            echo ""
        else
            local snapshot_count=$(echo "$btrfs_snapshots" | wc -l)
            echo -e "${GREEN}Found $snapshot_count BTRFS snapshot(s):${NC}"
            echo ""

            # Display snapshots
            echo "$btrfs_snapshots" | head -20 | while IFS= read -r line; do
                # Extract snapshot name/path
                local snap_path=$(echo "$line" | awk '{print $NF}')
                echo -e "  ${CYAN}•${NC} $snap_path"
            done

            if [[ $snapshot_count -gt 20 ]]; then
                echo "  ... and $((snapshot_count - 20)) more"
            fi

            echo ""

            # Show snapshot disk usage
            echo -e "${CYAN}Disk usage:${NC}"
            local root_device=$(findmnt -n -o SOURCE /)
            if [[ -n "$root_device" ]]; then
                local btrfs_usage
                if [[ $EUID -eq 0 ]]; then
                    btrfs_usage=$(btrfs filesystem usage / 2>/dev/null | grep "Used:" | head -1)
                else
                    btrfs_usage=$(sudo btrfs filesystem usage / 2>/dev/null | grep "Used:" | head -1)
                fi
                if [[ -n "$btrfs_usage" ]]; then
                    echo "  $btrfs_usage"
                fi
            fi

            echo ""
            echo -e "${CYAN}Manage BTRFS snapshots:${NC}"
            echo "  List all: sudo btrfs subvolume list /"
            echo "  Create: sudo btrfs subvolume snapshot / /.snapshots/\$(date +%Y%m%d)"
            echo "  Delete: sudo btrfs subvolume delete /.snapshots/NAME"
            echo ""
        fi
    fi

    # Summary
    echo -e "${BLUE}━━━ Snapshot Summary ━━━${NC}"
    echo ""
    if [[ "$has_timeshift" == "true" ]]; then
        echo -e "${GREEN}✓${NC} Timeshift available"
    fi
    if [[ "$has_btrfs" == "true" ]]; then
        echo -e "${GREEN}✓${NC} BTRFS snapshots available"
    fi
    echo ""
    echo -e "${YELLOW}Important:${NC} Both Timeshift and BTRFS snapshots may not include"
    echo "          /boot or EFI partitions. Use option 3 for boot backups!"

    pause
}

action_view_package_timeline() {
    if [[ ! -x "$TIMELINE_SCRIPT" ]]; then
        echo -e "${RED}✗ Script not found or not executable: $TIMELINE_SCRIPT${NC}"
        pause
        return 1
    fi

    "$TIMELINE_SCRIPT" --view
}

action_view_grub() {
    print_header
    echo -e "${CYAN}═══ GRUB Configuration & Menu Entries ═══${NC}"
    echo ""

    local grub_cfg="/boot/grub/grub.cfg"
    local grub_default="/etc/default/grub"

    # Check if GRUB config exists
    if [[ ! -f "$grub_cfg" ]]; then
        echo -e "${RED}✗ GRUB config not found at $grub_cfg${NC}"
        echo -e "${YELLOW}Note: You may be using a different bootloader (systemd-boot, rEFInd, etc.)${NC}"
        pause
        return 1
    fi

    # Config file info
    echo -e "${BLUE}━━━ Config File Information ━━━${NC}"
    echo -e "${CYAN}Location:${NC} $grub_cfg"

    local cfg_size=$(stat -c%s "$grub_cfg" 2>/dev/null)
    if [[ -n "$cfg_size" ]]; then
        echo -e "${CYAN}Size:${NC} $(numfmt --to=iec $cfg_size)"
    fi

    local cfg_modified=$(stat -c%y "$grub_cfg" 2>/dev/null | cut -d'.' -f1)
    if [[ -n "$cfg_modified" ]]; then
        echo -e "${CYAN}Last modified:${NC} $cfg_modified"
    fi

    # Check age
    local cfg_age_hours=$(( ($(date +%s) - $(stat -c%Y "$grub_cfg")) / 3600 ))
    if [[ $cfg_age_hours -lt 24 ]]; then
        echo -e "${GREEN}✓ Recently updated (${cfg_age_hours} hours ago)${NC}"
    elif [[ $cfg_age_hours -lt 168 ]]; then
        echo -e "${YELLOW}⚠ Updated $(($cfg_age_hours / 24)) days ago${NC}"
    else
        echo -e "${YELLOW}⚠ Updated $(($cfg_age_hours / 24)) days ago (consider regenerating)${NC}"
    fi

    echo ""

    # Extract and display menu entries
    echo -e "${BLUE}━━━ Available Menu Entries ━━━${NC}"
    echo ""

    local menu_entries=$(grep "^menuentry" "$grub_cfg" | sed "s/menuentry '\([^']*\)'.*/\1/")

    if [[ -z "$menu_entries" ]]; then
        echo -e "${RED}✗ No menu entries found!${NC}"
        echo -e "${YELLOW}This is a serious issue - GRUB won't be able to boot.${NC}"
        echo ""
        echo -e "${CYAN}Fix with:${NC}"
        echo "  sudo grub-mkconfig -o /boot/grub/grub.cfg"
    else
        local entry_count=$(echo "$menu_entries" | wc -l)
        echo -e "${GREEN}Found $entry_count menu entry/entries:${NC}"
        echo ""

        local counter=1
        while IFS= read -r entry; do
            # Highlight kernel entries
            if echo "$entry" | grep -q "linux"; then
                echo -e "  ${GREEN}$counter.${NC} ${CYAN}$entry${NC}"
            else
                echo -e "  ${GREEN}$counter.${NC} $entry"
            fi
            ((counter++))
        done <<< "$menu_entries"
    fi

    echo ""

    # Kernel detection in GRUB
    echo -e "${BLUE}━━━ Kernel Detection ━━━${NC}"
    echo ""

    local kernel_entries=$(grep -c "vmlinuz-linux" "$grub_cfg" || echo "0")

    if [[ $kernel_entries -eq 0 ]]; then
        echo -e "${RED}✗ No kernel entries found in GRUB config!${NC}"
    else
        echo -e "${GREEN}✓ Found $kernel_entries kernel reference(s) in GRUB config${NC}"
    fi

    # List detected kernels
    local detected_kernels=$(grep "vmlinuz-linux" "$grub_cfg" | grep -oP "vmlinuz-linux[^\s]*" | sort -u)
    if [[ -n "$detected_kernels" ]]; then
        echo -e "${CYAN}Detected kernels:${NC}"
        while IFS= read -r kernel; do
            echo "  • $kernel"
        done <<< "$detected_kernels"
    fi

    echo ""

    # Compare with installed kernels
    echo -e "${BLUE}━━━ Installed vs GRUB Comparison ━━━${NC}"
    echo ""

    local installed_kernels=$(pacman -Qq | grep '^linux' | grep -v 'linux-api-headers\|linux-firmware' || true)

    if [[ -n "$installed_kernels" ]]; then
        echo -e "${CYAN}Installed kernel packages:${NC}"
        while IFS= read -r pkg; do
            # Skip header packages (they don't have vmlinuz - they're for development/DKMS)
            if [[ "$pkg" =~ -headers$ ]]; then
                continue
            fi

            local vmlinuz="/boot/vmlinuz-${pkg}"
            if [[ -f "$vmlinuz" ]]; then
                if grep -q "vmlinuz-${pkg}" "$grub_cfg"; then
                    echo -e "  ${GREEN}✓${NC} $pkg (in GRUB config)"
                else
                    echo -e "  ${YELLOW}⚠${NC} $pkg (NOT in GRUB config - regenerate!)"
                fi
            else
                echo -e "  ${RED}✗${NC} $pkg (vmlinuz missing!)"
            fi
        done <<< "$installed_kernels"
    fi

    echo ""

    # Default GRUB settings
    if [[ -f "$grub_default" ]]; then
        echo -e "${BLUE}━━━ GRUB Default Settings ━━━${NC}"
        echo ""

        local timeout=$(grep "^GRUB_TIMEOUT=" "$grub_default" 2>/dev/null | cut -d'=' -f2)
        local default_entry=$(grep "^GRUB_DEFAULT=" "$grub_default" 2>/dev/null | cut -d'=' -f2)

        if [[ -n "$timeout" ]]; then
            echo -e "${CYAN}Timeout:${NC} $timeout seconds"
        fi

        if [[ -n "$default_entry" ]]; then
            echo -e "${CYAN}Default entry:${NC} $default_entry"
        fi
    fi

    echo ""

    # Validation summary
    echo -e "${BLUE}━━━ Validation Summary ━━━${NC}"
    echo ""

    local issues=0

    if [[ ! -f "$grub_cfg" ]]; then
        echo -e "${RED}✗ GRUB config missing${NC}"
        ((issues++))
    fi

    if [[ -z "$menu_entries" ]]; then
        echo -e "${RED}✗ No menu entries found${NC}"
        ((issues++))
    fi

    if [[ $kernel_entries -eq 0 ]]; then
        echo -e "${RED}✗ No kernels in GRUB config${NC}"
        ((issues++))
    fi

    if [[ $cfg_age_hours -gt 168 ]]; then
        echo -e "${YELLOW}⚠ GRUB config is old (consider regenerating)${NC}"
    fi

    if [[ $issues -eq 0 ]]; then
        echo -e "${GREEN}✓ GRUB configuration looks good!${NC}"
    else
        echo ""
        echo -e "${YELLOW}Found $issues issue(s). Regenerate GRUB config with:${NC}"
        echo "  sudo grub-mkconfig -o /boot/grub/grub.cfg"
    fi

    pause
}

action_pre_upgrade() {
    if [[ ! -x "$PRE_UPGRADE_SCRIPT" ]]; then
        echo -e "${RED}✗ Script not found or not executable: $PRE_UPGRADE_SCRIPT${NC}"
        pause
        return 1
    fi

    run_command "Pre-Upgrade Preview" "$PRE_UPGRADE_SCRIPT"
    pause
}

action_boot_check_autofix() {
    if [[ ! -x "$BOOT_CHECK_SCRIPT" ]]; then
        echo -e "${RED}✗ Script not found or not executable: $BOOT_CHECK_SCRIPT${NC}"
        pause
        return 1
    fi

    # Information box
    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                  SYSTEM MODIFICATION WARNING                 ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}What will be modified:${NC}"
    echo -e "  ${BLUE}•${NC} Mounts /boot if unmounted"
    echo -e "  ${BLUE}•${NC} Regenerates initramfs (mkinitcpio -P)"
    echo -e "  ${BLUE}•${NC} Regenerates GRUB config (grub-mkconfig)"
    echo ""
    echo -e "${CYAN}Flag used:${NC} ${GREEN}--auto-fix${NC}"
    echo ""
    echo -e "${CYAN}Why this is useful:${NC}"
    echo -e "  Automatically repairs common boot issues like:"
    echo -e "  - Missing initramfs files"
    echo -e "  - Outdated GRUB configuration"
    echo -e "  - Boot partition mount problems"
    echo ""
    echo -e "${CYAN}Alternative:${NC}"
    echo -e "  Run option Q (Quick Check) first, then manually fix"
    echo -e "  issues if you prefer full control."
    echo ""
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Continue with auto-fix? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        pause
        return 0
    fi

    if [[ $EUID -ne 0 ]]; then
        run_command "Boot Safety Check with Auto-Fix (requires sudo)" sudo "$BOOT_CHECK_SCRIPT" --auto-fix
    else
        run_command "Boot Safety Check with Auto-Fix" "$BOOT_CHECK_SCRIPT" --auto-fix
    fi
    pause
}

action_create_backup() {
    if [[ ! -x "$BACKUP_SCRIPT" ]]; then
        echo -e "${RED}✗ Script not found or not executable: $BACKUP_SCRIPT${NC}"
        pause
        return 1
    fi

    run_command "Create Boot Backup" "$BACKUP_SCRIPT"
    pause
}

action_list_backups() {
    if [[ ! -x "$BACKUP_SCRIPT" ]]; then
        echo -e "${RED}✗ Script not found or not executable: $BACKUP_SCRIPT${NC}"
        pause
        return 1
    fi

    run_command "List Backups" "$BACKUP_SCRIPT" --list
    pause
}

action_restore_backup() {
    if [[ ! -x "$BACKUP_SCRIPT" ]]; then
        echo -e "${RED}✗ Script not found or not executable: $BACKUP_SCRIPT${NC}"
        pause
        return 1
    fi

    # Information box
    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                  SYSTEM MODIFICATION WARNING                 ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}What will be modified:${NC}"
    echo -e "  ${BLUE}•${NC} Overwrites /etc/fstab"
    echo -e "  ${BLUE}•${NC} Overwrites /etc/mkinitcpio.conf"
    echo -e "  ${BLUE}•${NC} Overwrites /etc/default/grub"
    echo ""
    echo -e "${CYAN}Flag used:${NC} ${GREEN}--restore${NC}"
    echo ""
    echo -e "${CYAN}Why this is useful:${NC}"
    echo -e "  Restores boot configuration from a working backup when:"
    echo -e "  - System won't boot after changes"
    echo -e "  - Configuration files got corrupted"
    echo -e "  - You want to revert to a known-good state"
    echo ""
    echo -e "${CYAN}After restore:${NC}"
    echo -e "  You'll need to regenerate initramfs and GRUB config:"
    echo -e "  ${BLUE}sudo mkinitcpio -P${NC}"
    echo -e "  ${BLUE}sudo grub-mkconfig -o /boot/grub/grub.cfg${NC}"
    echo ""
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    run_command "Restore from Backup" "$BACKUP_SCRIPT" --restore
    pause
}

action_complete_workflow() {
    print_header
    echo -e "${MAGENTA}═══ Complete Upgrade Workflow ═══${NC}"
    echo ""
    echo "This will guide you through a safe upgrade process:"
    echo "  1. Preview pending updates"
    echo "  2. Create backup (if high risk)"
    echo "  3. Run upgrade (manual)"
    echo "  4. Validate system"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        pause
        return 0
    fi

    # Step 1: Preview
    echo ""
    echo -e "${CYAN}Step 1/4: Preview Pending Updates${NC}"
    if [[ -x "$PRE_UPGRADE_SCRIPT" ]]; then
        "$PRE_UPGRADE_SCRIPT"
    else
        echo -e "${RED}✗ Pre-upgrade script not found${NC}"
        pause
        return 1
    fi

    echo ""
    read -p "Do you want to proceed with this upgrade? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Upgrade cancelled."
        pause
        return 0
    fi

    # Step 2: Backup decision
    echo ""
    echo -e "${CYAN}Step 2/4: Backup Recommendation${NC}"
    echo ""
    read -p "Create a backup before upgrading? (Y/n): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        if [[ -x "$BACKUP_SCRIPT" ]]; then
            "$BACKUP_SCRIPT"
        else
            echo -e "${RED}✗ Backup script not found${NC}"
        fi
    else
        echo "Skipping backup (not recommended for kernel updates!)"
    fi

    # Step 3: Manual upgrade
    echo ""
    echo -e "${CYAN}Step 3/4: System Upgrade${NC}"
    echo ""
    echo "Ready to upgrade. Run the following command:"
    echo ""
    echo -e "${GREEN}  sudo pacman -Syu${NC}"
    echo ""
    echo "After the upgrade completes, return here and press ENTER."
    echo ""
    read -p "Press ENTER when upgrade is complete (or Ctrl+C to abort)..." -r

    # Step 4: Validation
    echo ""
    echo -e "${CYAN}Step 4/4: Post-Upgrade Validation${NC}"
    echo ""

    if [[ -x "$BOOT_CHECK_SCRIPT" ]]; then
        if [[ $EUID -ne 0 ]]; then
            sudo "$BOOT_CHECK_SCRIPT"
        else
            "$BOOT_CHECK_SCRIPT"
        fi

        local check_result=$?

        echo ""
        if [[ $check_result -eq 0 ]]; then
            echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
            echo -e "${GREEN}✓ Upgrade workflow completed successfully!${NC}"
            echo -e "${GREEN}✓ System is safe to reboot${NC}"
            echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
        else
            echo -e "${RED}═══════════════════════════════════════════════${NC}"
            echo -e "${RED}✗ Issues detected during validation${NC}"
            echo -e "${RED}✗ Review errors above before rebooting${NC}"
            echo -e "${RED}═══════════════════════════════════════════════${NC}"
            echo ""
            echo "You can try running the auto-fix from the main menu (option 2)."
        fi
    else
        echo -e "${RED}✗ Boot check script not found${NC}"
    fi

    pause
}

action_install_tools() {
    print_header

    # Information box
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                  SYSTEM MODIFICATION WARNING                 ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}What will be modified:${NC}"
    echo -e "  ${BLUE}•${NC} Copies arch-boot-check.sh → /usr/local/bin/"
    echo -e "  ${BLUE}•${NC} Copies arch-package-timeline.sh → /usr/local/bin/"
    echo -e "  ${BLUE}•${NC} Copies 99-boot-safety-check.hook → /etc/pacman.d/hooks/"
    echo -e "  ${BLUE}•${NC} Copies 99-package-timeline.hook → /etc/pacman.d/hooks/"
    echo -e "  ${BLUE}•${NC} Installs dependencies (pacman-contrib, smartmontools)"
    echo -e "  ${BLUE}•${NC} Optionally installs linux-lts kernel"
    echo ""
    echo -e "${CYAN}Flag used:${NC} ${GREEN}N/A (installation process)${NC}"
    echo ""
    echo -e "${CYAN}Why this is useful:${NC}"
    echo -e "  Enables automatic boot validation after upgrades:"
    echo -e "  - Hook runs after kernel/GRUB updates"
    echo -e "  - Alerts you to boot issues before you reboot"
    echo -e "  - Prevents unexpected boot failures"
    echo ""
    echo -e "${CYAN}What gets installed:${NC}"
    echo -e "  ${BLUE}1.${NC} Boot check script (for hook to use)"
    echo -e "  ${BLUE}2.${NC} Package timeline script (tracks all installations)"
    echo -e "  ${BLUE}3.${NC} Pacman hooks (auto-trigger on updates)"
    echo -e "  ${BLUE}4.${NC} Dependencies (for full functionality)"
    echo -e "  ${BLUE}5.${NC} Fallback kernel (recommended safety measure)"
    echo ""
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        pause
        return 0
    fi

    # Check for dependencies
    echo ""
    echo -e "${BLUE}Checking dependencies...${NC}"

    local missing_deps=()

    if ! pacman -Qq pacman-contrib &>/dev/null; then
        missing_deps+=("pacman-contrib")
    fi

    if ! pacman -Qq smartmontools &>/dev/null; then
        missing_deps+=("smartmontools")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠ Missing dependencies: ${missing_deps[*]}${NC}"
        echo ""
        read -p "Install missing dependencies? (y/N): " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo pacman -S "${missing_deps[@]}"
        fi
    else
        echo -e "${GREEN}✓ All dependencies installed${NC}"
    fi

    # Install boot check script
    echo ""
    echo -e "${BLUE}Installing arch-boot-check.sh...${NC}"

    if [[ -f "$BOOT_CHECK_SCRIPT" ]]; then
        sudo cp "$BOOT_CHECK_SCRIPT" /usr/local/bin/
        sudo chmod +x /usr/local/bin/arch-boot-check.sh
        echo -e "${GREEN}✓ Installed to /usr/local/bin/arch-boot-check.sh${NC}"
    else
        echo -e "${RED}✗ Script not found: $BOOT_CHECK_SCRIPT${NC}"
    fi

    # Install package timeline script
    echo ""
    echo -e "${BLUE}Installing arch-package-timeline.sh...${NC}"

    if [[ -f "$TIMELINE_SCRIPT" ]]; then
        sudo cp "$TIMELINE_SCRIPT" /usr/local/bin/
        sudo chmod +x /usr/local/bin/arch-package-timeline.sh
        echo -e "${GREEN}✓ Installed to /usr/local/bin/arch-package-timeline.sh${NC}"
    else
        echo -e "${RED}✗ Script not found: $TIMELINE_SCRIPT${NC}"
    fi

    # Install pacman hooks
    echo ""
    echo -e "${BLUE}Installing pacman hooks...${NC}"

    local boot_hook_file="${SCRIPT_DIR}/99-boot-safety-check.hook"
    local timeline_hook_file="${SCRIPT_DIR}/99-package-timeline.hook"

    sudo mkdir -p /etc/pacman.d/hooks

    if [[ -f "$boot_hook_file" ]]; then
        sudo cp "$boot_hook_file" /etc/pacman.d/hooks/
        echo -e "${GREEN}✓ Installed to /etc/pacman.d/hooks/99-boot-safety-check.hook${NC}"
    else
        echo -e "${RED}✗ Hook file not found: $boot_hook_file${NC}"
    fi

    if [[ -f "$timeline_hook_file" ]]; then
        sudo cp "$timeline_hook_file" /etc/pacman.d/hooks/
        echo -e "${GREEN}✓ Installed to /etc/pacman.d/hooks/99-package-timeline.hook${NC}"
    else
        echo -e "${RED}✗ Hook file not found: $timeline_hook_file${NC}"
    fi

    # Install fallback kernel
    echo ""
    read -p "Install linux-lts fallback kernel? (recommended) (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo pacman -S linux-lts linux-lts-headers
    fi

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Installation complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo ""
    echo "The boot check will now run automatically after kernel/GRUB upgrades."
    echo "Package timeline tracking is now active for all package operations."
    echo ""
    echo "View timeline anytime with option P from the main menu."

    pause
}

action_view_docs() {
    local doc_file="${SCRIPT_DIR}/README.md"

    if [[ -f "$doc_file" ]]; then
        if command -v less &> /dev/null; then
            less "$doc_file"
        elif command -v more &> /dev/null; then
            more "$doc_file"
        else
            cat "$doc_file"
            pause
        fi
    else
        echo -e "${RED}✗ Documentation not found: $doc_file${NC}"
        pause
    fi
}

# --- Main Loop ---
main() {
    while true; do
        show_main_menu
        read -r choice

        case $choice in
            q|Q) action_quick_check ;;
            g|G) action_view_grub ;;
            t|T) action_list_timeshift ;;
            p|P) action_view_package_timeline ;;
            h|H) action_boot_help ;;
            1) action_pre_upgrade ;;
            2) action_boot_check_autofix ;;
            3) action_create_backup ;;
            4) action_list_backups ;;
            5) action_restore_backup ;;
            6) action_complete_workflow ;;
            7) action_install_tools ;;
            8) action_view_docs ;;
            0)
                echo ""
                echo -e "${GREEN}Goodbye!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# --- Entry Point ---
main "$@"
