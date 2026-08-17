#!/bin/bash

set -euo pipefail

# Debian / Ubuntu Boot Safety Check Script
# Validates system state before reboot to prevent boot failures

# --- Configuration ---
BOOT_MOUNT="/boot"
LOG_FILE="/var/log/dpkg.log"
WARN_COUNT=0
ERROR_COUNT=0
AUTO_FIX=false
QUICK_BANNER=false

# --- Colors ---
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Parse arguments ---
# Captured before the parse loop consumes them, so the sudo re-exec in check_root
# can replay the original invocation. Without this, --auto-fix and --quick-banner
# are silently dropped whenever the script escalates privileges.
ORIGINAL_ARGS=("$@")

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto-fix)
      AUTO_FIX=true
      shift
      ;;
    --quick-banner)
      QUICK_BANNER=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--auto-fix] [--quick-banner]"
      echo ""
      echo "Options:"
      echo "  --auto-fix      Attempt to automatically fix detected issues"
      echo "  --quick-banner  Display YES/NO boxed banners on summary"
      echo "  --help, -h      Show this help message"
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# --- Helper Functions ---
log_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC}  $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

log_error() {
    echo -e "${RED}✗${NC} $1"
    ERROR_COUNT=$((ERROR_COUNT + 1))
}

section_header() {
    echo ""
    echo -e "${BLUE}━━━ $1 ━━━${NC}"
}

# --- Checks ---

check_root() {
    section_header "Permission Check"
    if [[ $EUID -ne 0 ]]; then
        log_info "This script requires root privileges. Re-running with sudo..."
        exec sudo -- "$0" ${ORIGINAL_ARGS[@]+"${ORIGINAL_ARGS[@]}"}
    fi
    log_success "Running as root"
    return 0
}

check_boot_partition() {
    section_header "Boot Partition Status"

    # Check if /boot is mounted
    if ! mountpoint -q "$BOOT_MOUNT"; then
        log_error "/boot is NOT mounted"
        if $AUTO_FIX; then
            log_info "Attempting to mount /boot..."
            if mount "$BOOT_MOUNT" 2>/dev/null; then
                log_success "Successfully mounted /boot"
            else
                log_error "Failed to mount /boot - check /etc/fstab"
                return 1
            fi
        else
            return 1
        fi
    else
        log_success "/boot is mounted"
    fi

    # Check if writable
    if [[ ! -w "$BOOT_MOUNT" ]]; then
        log_error "/boot is mounted but NOT writable"
        return 1
    fi
    log_success "/boot is writable"

    # Check available space
    local available_space=$(df -BM --output=avail "$BOOT_MOUNT" | tail -n 1 | sed 's/M$//' | tr -d ' ')
    if [[ "$available_space" =~ ^[0-9]+$ ]]; then
        if [[ $available_space -lt 50 ]]; then
            log_warn "/boot has only ${available_space}MB free (recommend at least 50MB)"
        else
            log_success "/boot has ${available_space}MB free"
        fi
    else
        log_warn "Could not determine /boot free space"
    fi

    return 0
}

check_installed_kernels() {
    section_header "Installed Kernels"

    local kernels=$(dpkg-query -W -f='${Status} ${Package}\n' 2>/dev/null | grep '^install ok installed' | awk '{print $4}' | grep -E '^linux-image-[0-9]' || true)

    if [[ -z "$kernels" ]]; then
        log_error "No kernel packages found!"
        return 1
    fi

    log_info "Found kernel packages:"
    while IFS= read -r kernel; do
        [[ -n "$kernel" ]] && echo "  - $kernel"
    done <<< "$kernels"

    local kernel_count=$(echo "$kernels" | grep -c '^' || true)
    if [[ "$kernel_count" =~ ^[0-9]+$ ]] && [[ $kernel_count -lt 2 ]]; then
        log_warn "Only 1 kernel installed. Consider installing linux-image-generic as fallback"
    elif [[ "$kernel_count" =~ ^[0-9]+$ ]] && [[ $kernel_count -ge 2 ]]; then
        log_success "Multiple kernels installed (good for fallback)"
    fi

    return 0
}

check_kernel_images() {
    section_header "Kernel Images & Initramfs"

    local kernels=$(dpkg-query -W -f='${Status} ${Package}\n' 2>/dev/null | grep '^install ok installed' | awk '{print $4}' | grep -E '^linux-image-[0-9]' || true)

    if [[ -z "$kernels" ]]; then
        log_error "No kernel packages found to check images for"
        return 1
    fi

    local all_ok=true
    local errors_found=0

    while IFS= read -r kernel; do
        [[ -z "$kernel" ]] && continue

        local version_suffix="${kernel#linux-image-}"
        local vmlinuz="/boot/vmlinuz-${version_suffix}"
        local initrd="/boot/initrd.img-${version_suffix}"

        log_info "Checking $kernel:"

        # Check vmlinuz
        if [[ -f "$vmlinuz" ]]; then
            local vmlinuz_size=$(stat -c%s "$vmlinuz" 2>/dev/null || echo "0")
            if [[ "$vmlinuz_size" =~ ^[0-9]+$ ]] && [[ $vmlinuz_size -gt 1000000 ]]; then
                echo "  ✓ vmlinuz exists ($(numfmt --to=iec $vmlinuz_size))"
            else
                echo "  ✗ vmlinuz exists but suspiciously small ($vmlinuz_size bytes)"
                all_ok=false
                errors_found=$((errors_found + 1))
            fi
        else
            echo "  ✗ vmlinuz NOT found at $vmlinuz"
            all_ok=false
            errors_found=$((errors_found + 1))
        fi

        # Check initrd
        if [[ -f "$initrd" ]]; then
            local initrd_size=$(stat -c%s "$initrd" 2>/dev/null || echo "0")
            if [[ "$initrd_size" =~ ^[0-9]+$ ]] && [[ $initrd_size -gt 0 ]]; then
                local age_minutes=$(( ($(date +%s) - $(stat -c%Y "$initrd")) / 60 ))
                echo "  ✓ initrd exists ($(numfmt --to=iec $initrd_size), ${age_minutes}min old)"
            else
                echo "  ✗ initrd exists but has invalid size"
                all_ok=false
                errors_found=$((errors_found + 1))
            fi
        else
            echo "  ✗ initrd NOT found at $initrd"
            all_ok=false
            errors_found=$((errors_found + 1))
        fi
    done < <(echo "$kernels")

    if $all_ok; then
        log_success "All kernel images present"
        return 0
    else
        log_error "Missing or invalid kernel images (found $errors_found issue(s))"
        if $AUTO_FIX; then
            log_info "Attempting to regenerate initramfs..."
            if update-initramfs -u -k all 2>&1; then
                log_success "Successfully regenerated initramfs"
                return 0
            else
                log_error "Failed to regenerate initramfs"
                return 1
            fi
        fi
        return 1
    fi
}

check_recent_kernel_update() {
    section_header "Recent Kernel Updates"

    if [[ ! -f "$LOG_FILE" ]]; then
        log_warn "Cannot find dpkg log at $LOG_FILE"
        return 0
    fi

    # Check last 24 hours for kernel updates
    local recent_kernel_updates=$(grep -E "$(date -d '24 hours ago' '+%Y-%m-%d')|$(date '+%Y-%m-%d')" "$LOG_FILE" | grep -E "install linux-image-[0-9]|upgrade linux-image-[0-9]" || true)

    if [[ -n "$recent_kernel_updates" ]]; then
        log_warn "Kernel was updated in the last 24 hours:"
        echo "$recent_kernel_updates" | tail -5 | sed 's/^/  /'
        log_info "Extra caution recommended - kernel updates can cause boot issues"
    else
        log_success "No recent kernel updates detected"
    fi

    return 0
}

check_grub_config() {
    section_header "GRUB Configuration"

    local grub_cfg="/boot/grub/grub.cfg"

    if [[ ! -f "$grub_cfg" ]]; then
        log_error "GRUB config not found at $grub_cfg"
        return 1
    fi

    local cfg_age_hours=$(( ($(date +%s) - $(stat -c%Y "$grub_cfg")) / 3600 ))
    log_info "grub.cfg is ${cfg_age_hours} hours old"

    if grep -q "menuentry" "$grub_cfg"; then
        log_success "grub.cfg contains menu entries"
    else
        log_error "grub.cfg appears invalid (no menu entries found)"
        return 1
    fi

    # Count available kernels in GRUB (search for vmlinuz-)
    local grub_kernel_count=$(grep -c "vmlinuz-" "$grub_cfg" || true)
    if [[ $grub_kernel_count -eq 0 ]]; then
        log_error "No kernel entries found in GRUB config"
        if $AUTO_FIX; then
            log_info "Attempting to regenerate GRUB config..."
            if update-grub; then
                log_success "Successfully regenerated GRUB config"
                return 0
            else
                log_error "Failed to regenerate GRUB config"
                return 1
            fi
        fi
        return 1
    else
        log_success "Found $grub_kernel_count kernel entries in GRUB"
    fi

    return 0
}

check_vfat_module() {
    section_header "VFAT Module in Initramfs"

    local kernels=$(dpkg-query -W -f='${Status} ${Package}\n' 2>/dev/null | grep '^install ok installed' | awk '{print $4}' | grep -E '^linux-image-[0-9]' || true)
    local first_kernel=$(echo "$kernels" | head -1)
    
    if [[ -z "$first_kernel" ]]; then
        log_warn "No kernels installed, skipping VFAT check"
        return 0
    fi
    
    local version_suffix="${first_kernel#linux-image-}"
    local initrd="/boot/initrd.img-${version_suffix}"

    if [[ ! -f "$initrd" ]]; then
        log_warn "Cannot check initramfs (file not found)"
        return 0
    fi

    # Extract and check for vfat module using lsinitramfs
    if lsinitramfs "$initrd" 2>/dev/null | grep -q "vfat\|fat"; then
        log_success "VFAT/FAT module present in initramfs"
    else
        log_warn "VFAT module not found in initramfs (may cause boot issues if /boot/efi is vfat)"
        log_info "Check /etc/initramfs-tools/modules"
    fi

    return 0
}

check_dpkg_hooks() {
    section_header "DPkg Status Checks"

    if [[ ! -f "$LOG_FILE" ]]; then
        log_warn "Cannot check dpkg logs (log not found)"
        return 0
    fi

    local hook_failures=$(tail -100 "$LOG_FILE" | grep -i "error:\|fail" || true)

    if [[ -n "$hook_failures" ]]; then
        log_error "Recent dpkg failures or errors detected:"
        echo "$hook_failures" | sed 's/^/  /'
        return 1
    else
        log_success "No recent dpkg failures detected"
    fi

    return 0
}

check_held_packages() {
    section_header "Held & Broken Packages"

    local held=$(dpkg --get-selections | grep hold || true)
    local broken=$(dpkg -l | grep -E '^i[^i]|^[^i]i' || true)

    if [[ -n "$held" ]]; then
        log_warn "Some packages are held back:"
        echo "$held" | sed 's/^/  /'
    fi

    if [[ -n "$broken" ]]; then
        log_error "Broken packages detected on the system!"
        echo "$broken" | sed 's/^/  /'
        return 1
    else
        log_success "No broken packages detected"
    fi

    return 0
}

check_efi_boot_entries() {
    section_header "EFI Boot Entries"

    if [[ ! -d "/sys/firmware/efi" ]]; then
        log_info "System is not using EFI (likely BIOS/Legacy boot)"
        return 0
    fi

    if ! command -v efibootmgr &> /dev/null; then
        log_warn "efibootmgr not installed, cannot check EFI entries"
        return 0
    fi

    local boot_entries=$(efibootmgr | grep "Boot[0-9]" || true)

    if [[ -z "$boot_entries" ]]; then
        log_error "No EFI boot entries found!"
        return 1
    fi

    log_success "EFI boot entries present:"
    echo "$boot_entries" | head -5 | sed 's/^/  /'

    return 0
}

check_dkms_modules() {
    section_header "DKMS Module Status"

    if ! command -v dkms &> /dev/null; then
        log_info "DKMS not installed (skip if you don't use proprietary drivers)"
        return 0
    fi

    local dkms_output=$(dkms status 2>/dev/null || true)

    if [[ -z "$dkms_output" ]]; then
        log_info "No DKMS modules installed"
        return 0
    fi

    log_info "DKMS modules found:"
    echo "$dkms_output" | sed 's/^/  /'

    if echo "$dkms_output" | grep -qi "error\|failed"; then
        log_error "DKMS module build failures detected!"
        log_info "Rebuild with: dkms autoinstall"
        return 1
    fi

    local kernels=$(dpkg-query -W -f='${Status} ${Package}\n' 2>/dev/null | grep '^install ok installed' | awk '{print $4}' | grep -E '^linux-image-[0-9]' || true)
    local missing_headers_count=0

    while IFS= read -r kernel; do
        [[ -z "$kernel" ]] && continue
        local version_suffix="${kernel#linux-image-}"
        local headers="linux-headers-${version_suffix}"
        if ! dpkg-query -W -f='${Status}' "$headers" 2>/dev/null | grep -q "ok installed"; then
            log_warn "Missing $headers (needed for DKMS)"
            missing_headers_count=$((missing_headers_count + 1))
        fi
    done < <(echo "$kernels")

    if [[ $missing_headers_count -gt 0 ]]; then
        log_info "Install headers with: sudo apt install linux-headers-generic"
    else
        log_success "DKMS modules built successfully"
    fi

    return 0
}

check_filesystem_integrity() {
    section_header "Filesystem Integrity (Advisory)"

    log_info "Filesystem checks should be run on unmounted partitions"
    log_info "This check only provides recommendations"
    echo ""

    local boot_device=$(df "$BOOT_MOUNT" | awk 'NR==2 {print $1}')
    local boot_fstype=$(df -T "$BOOT_MOUNT" | awk 'NR==2 {print $2}')

    log_info "Boot partition: $boot_device (filesystem: $boot_fstype)"

    if [[ "$boot_fstype" == "vfat" ]] || [[ "$boot_fstype" == "fat32" ]]; then
        log_info "To check vfat filesystem (requires unmount):"
        echo "  sudo umount $BOOT_MOUNT"
        echo "  sudo fsck.vfat -a $boot_device"
        echo "  sudo mount $BOOT_MOUNT"
    elif [[ "$boot_fstype" == "ext4" ]] || [[ "$boot_fstype" == "ext3" ]] || [[ "$boot_fstype" == "ext2" ]]; then
        log_info "To check ext filesystem (requires unmount or live USB):"
        echo "  sudo fsck -f $boot_device"
    fi

    local fs_errors=$(dmesg | grep -i "error\|corrupt" | grep -iF "$boot_device" | tail -5 || true)
    if [[ -n "$fs_errors" ]]; then
        log_warn "Filesystem errors detected in kernel log:"
        echo "$fs_errors" | sed 's/^/  /'
        log_info "Run fsck from a live USB to repair"
        return 1
    else
        log_success "No filesystem errors in kernel log"
    fi

    return 0
}

check_disk_health() {
    section_header "Disk Health (SMART)"

    if ! command -v smartctl &> /dev/null; then
        log_info "smartctl not installed (install smartmontools for disk health checks)"
        return 0
    fi

    if ! command -v jq &> /dev/null; then
        log_info "jq not installed (install jq for reliable SMART checks)"
        return 0
    fi

    local boot_partition=$(df "$BOOT_MOUNT" | awk 'NR==2 {print $1}')
    local disk_device=$(lsblk -no PKNAME "$boot_partition" 2>/dev/null | head -1)

    if [[ -z "$disk_device" ]]; then
        log_warn "Could not determine disk device for SMART check"
        return 0
    fi

    if [[ ! "$disk_device" =~ ^/dev/ ]]; then
        disk_device="/dev/$disk_device"
    fi

    log_info "Checking SMART status for $disk_device..."

    local smart_output
    smart_output=$(smartctl -j -H "$disk_device" 2>/dev/null)
    if [[ -z "$smart_output" ]]; then
        log_warn "SMART not available/supported for $disk_device"
        return 0
    fi

    if echo "$smart_output" | jq -e '.smart_status.passed' >/dev/null; then
        log_success "Disk health: PASSED"
    else
        log_error "Disk health: FAILED or DEGRADED"
        log_info "Run for details: sudo smartctl -a $disk_device"
        return 1
    fi

    local reallocated=$(echo "$smart_output" | jq -r '.ata_smart_attributes.table[] | select(.name == "Reallocated_Sector_Ct") | .raw.value' 2>/dev/null || echo "0")
    if [[ "$reallocated" != "0" ]] && [[ -n "$reallocated" ]]; then
        log_warn "Disk has $reallocated reallocated sectors (potential hardware issues)"
    fi

    return 0
}

check_apt_cache() {
    section_header "APT Cache Status"

    local cache_dir="/var/cache/apt/archives"

    if [[ ! -d "$cache_dir" ]]; then
        log_error "APT cache directory not found at $cache_dir"
        return 1
    fi

    local cache_count=$(find "$cache_dir" -maxdepth 1 -type f -name '*.deb' 2>/dev/null | wc -l || echo "0")
    local cache_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1 || echo "unknown")

    if [[ "$cache_count" =~ ^[0-9]+$ ]] && [[ $cache_count -eq 0 ]]; then
        log_warn "APT cache is empty - cannot downgrade easily if needed"
    elif [[ "$cache_count" =~ ^[0-9]+$ ]]; then
        log_success "APT cache has $cache_count packages ($cache_size)"
        log_info "Cache available for package updates/reinstalls"
    else
        log_warn "Could not determine APT cache status"
    fi

    return 0
}

check_timeshift_snapshot() {
    section_header "Timeshift/Snapshot Status"

    if ! command -v timeshift &> /dev/null; then
        log_info "Timeshift not installed"
        return 0
    fi

    local snapshot_count=$(timeshift --list 2>/dev/null | grep -c "^>" || true)

    if [[ $snapshot_count -eq 0 ]]; then
        log_warn "No Timeshift snapshots found"
        log_info "Create snapshot before risky upgrades: timeshift --create"
    else
        log_success "Found $snapshot_count Timeshift snapshot(s)"

        local recent_snapshot=$(timeshift --list 2>/dev/null | grep "^>" | head -1 || true)
        if [[ -n "$recent_snapshot" ]]; then
            log_info "Most recent: $recent_snapshot"
        fi
    fi

    if [[ -d "/sys/firmware/efi" ]]; then
        log_info "REMINDER: Ensure your EFI partition is backed up separately"
        log_info "Timeshift may not include /boot or ESP in snapshots"
    fi

    return 0
}

# --- Main Execution ---

main() {
    echo "╔════════════════════════════════════════════════╗"
    echo "║   Debian / Ubuntu Boot Safety Check            ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""

    if ! check_root; then
        exit 1
    fi

    # Run all checks
    check_boot_partition
    check_installed_kernels
    check_kernel_images
    check_recent_kernel_update
    check_grub_config
    check_vfat_module
    check_dpkg_hooks
    check_held_packages
    check_efi_boot_entries
    check_dkms_modules
    check_filesystem_integrity
    check_disk_health
    check_apt_cache
    check_timeshift_snapshot

    # Final summary
    section_header "Summary"

    if [[ $ERROR_COUNT -eq 0 && $WARN_COUNT -eq 0 ]]; then
        if $QUICK_BANNER; then
            echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║                                                              ║${NC}"
            echo -e "${GREEN}║                  ✓✓✓ YES - SAFE TO REBOOT ✓✓✓                ║${NC}"
            echo -e "${GREEN}║                                                              ║${NC}"
            echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
        else
            echo -e "${GREEN}✓✓✓ SAFE TO REBOOT ✓✓✓${NC}"
            echo "All checks passed successfully."
        fi
        exit 0
    elif [[ $ERROR_COUNT -eq 0 ]]; then
        if $QUICK_BANNER; then
            echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║                                                              ║${NC}"
            echo -e "${GREEN}║                  ✓✓✓ YES - SAFE TO REBOOT ✓✓✓                ║${NC}"
            echo -e "${GREEN}║                                                              ║${NC}"
            echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${YELLOW}Note:${NC} Warnings were found, check output details above."
        else
            echo -e "${YELLOW}⚠ REBOOT WITH CAUTION ⚠${NC}"
            echo "Found $WARN_COUNT warning(s) but no critical errors."
            echo "Review warnings above before rebooting."
        fi
        exit 0
    else
        if $QUICK_BANNER; then
            echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║                                                              ║${NC}"
            echo -e "${RED}║                  ✗✗✗ NO - DO NOT REBOOT ✗✗✗                  ║${NC}"
            echo -e "${RED}║                                                              ║${NC}"
            echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo "Recommendation: Try Auto-Fix option from Boot menu"
        else
            echo -e "${RED}✗✗✗ DO NOT REBOOT ✗✗✗${NC}"
            echo "Found $ERROR_COUNT critical error(s) and $WARN_COUNT warning(s)."
            echo "Fix the errors above before rebooting!"
            if ! $AUTO_FIX; then
                echo ""
                echo "Tip: Try running with --auto-fix to attempt automatic repairs"
            fi
        fi
        exit 1
    fi
}

main "$@"
