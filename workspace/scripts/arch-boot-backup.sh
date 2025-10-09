#!/bin/bash

set -euo pipefail

# Arch Linux Boot Configuration Backup Script
# Creates a comprehensive backup of boot-related configurations
# for emergency recovery purposes

# --- Configuration ---
BACKUP_DIR="${HOME}/.boot-backups"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/boot-backup-${BACKUP_DATE}"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Parse arguments ---
ACTION="backup"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --restore)
      ACTION="restore"
      shift
      ;;
    --list)
      ACTION="list"
      shift
      ;;
    --help|-h)
      echo "Arch Linux Boot Configuration Backup & Restore"
      echo ""
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  (no args)     Create a new backup (default)"
      echo "  --restore     Restore from a previous backup interactively"
      echo "  --list        List all available backups"
      echo "  --help, -h    Show this help message"
      echo ""
      echo "Backup location: $BACKUP_DIR"
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
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# --- Backup Functions ---

create_backup() {
    echo "╔════════════════════════════════════════════════╗"
    echo "║   Creating Boot Configuration Backup          ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""

    # Create backup directory
    mkdir -p "$BACKUP_PATH"
    log_info "Backup location: $BACKUP_PATH"
    echo ""

    # System information
    log_info "Collecting system information..."
    {
        echo "# Arch Linux Boot Backup"
        echo "# Created: $(date)"
        echo "# Hostname: $(hostname)"
        echo "# Kernel: $(uname -r)"
        echo ""
    } > "$BACKUP_PATH/backup-info.txt"

    # Installed kernels
    log_info "Backing up kernel package list..."
    pacman -Qq | grep '^linux' > "$BACKUP_PATH/installed-kernels.txt" || true
    log_success "Saved to installed-kernels.txt"

    # /etc/fstab
    if [[ -f /etc/fstab ]]; then
        log_info "Backing up /etc/fstab..."
        cp /etc/fstab "$BACKUP_PATH/fstab.backup"
        log_success "Saved fstab"
    fi

    # /etc/mkinitcpio.conf
    if [[ -f /etc/mkinitcpio.conf ]]; then
        log_info "Backing up /etc/mkinitcpio.conf..."
        cp /etc/mkinitcpio.conf "$BACKUP_PATH/mkinitcpio.conf.backup"
        log_success "Saved mkinitcpio.conf"
    fi

    # /etc/default/grub
    if [[ -f /etc/default/grub ]]; then
        log_info "Backing up /etc/default/grub..."
        cp /etc/default/grub "$BACKUP_PATH/grub.default.backup"
        log_success "Saved grub defaults"
    fi

    # GRUB config (requires sudo)
    if [[ -f /boot/grub/grub.cfg ]]; then
        log_info "Backing up GRUB config..."
        if [[ $EUID -eq 0 ]]; then
            cp /boot/grub/grub.cfg "$BACKUP_PATH/grub.cfg.backup"
            log_success "Saved grub.cfg"
        else
            sudo cp /boot/grub/grub.cfg "$BACKUP_PATH/grub.cfg.backup" 2>/dev/null || \
                log_warn "Could not backup grub.cfg (requires sudo)"
        fi
    fi

    # Partition layout
    log_info "Recording partition layout..."
    if [[ $EUID -eq 0 ]]; then
        lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,UUID > "$BACKUP_PATH/partition-layout.txt"
        blkid > "$BACKUP_PATH/blkid-output.txt" 2>/dev/null || true
    else
        lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT > "$BACKUP_PATH/partition-layout.txt"
        sudo blkid > "$BACKUP_PATH/blkid-output.txt" 2>/dev/null || \
            log_warn "Could not get full partition info (requires sudo)"
    fi
    log_success "Saved partition layout"

    # EFI boot entries
    if [[ -d /sys/firmware/efi ]] && command -v efibootmgr &> /dev/null; then
        log_info "Recording EFI boot entries..."
        if [[ $EUID -eq 0 ]]; then
            efibootmgr -v > "$BACKUP_PATH/efi-boot-entries.txt" 2>/dev/null || true
        else
            sudo efibootmgr -v > "$BACKUP_PATH/efi-boot-entries.txt" 2>/dev/null || \
                log_warn "Could not read EFI entries (requires sudo)"
        fi
        log_success "Saved EFI boot entries"
    fi

    # Boot directory listing
    log_info "Recording /boot contents..."
    ls -lh /boot > "$BACKUP_PATH/boot-directory-listing.txt" 2>/dev/null || true
    log_success "Saved boot directory listing"

    # Full /boot tar backup
    log_info "Creating full /boot tar backup (this may take a moment)..."
    local boot_tar="${BACKUP_PATH}/boot-full-backup.tar.gz"
    local tar_error="${BACKUP_PATH}/tar-error.log"

    local tar_success=false
    if [[ $EUID -eq 0 ]]; then
        if tar -czf "$boot_tar" -C / boot 2>"$tar_error"; then
            tar_success=true
        fi
    else
        if sudo tar -czf "$boot_tar" -C / boot 2>"$tar_error"; then
            tar_success=true
        fi
    fi

    if $tar_success; then
        local tar_size=$(du -sh "$boot_tar" 2>/dev/null | cut -f1 || echo "unknown")
        log_success "Full /boot backup created ($tar_size)"
        log_info "Contains: kernels, initramfs, GRUB config, etc."
        rm -f "$tar_error"  # Remove error log if successful
    else
        log_warn "Could not create full /boot tar backup"
        if [[ -f "$tar_error" ]] && [[ -s "$tar_error" ]]; then
            log_info "Error details saved to: $tar_error"
        fi
    fi

    # Pacman package list (all)
    log_info "Backing up all installed packages..."
    pacman -Qq > "$BACKUP_PATH/all-packages.txt"
    log_success "Saved package list"

    # Recent pacman log entries
    if [[ -f /var/log/pacman.log ]]; then
        log_info "Extracting recent pacman logs..."
        tail -500 /var/log/pacman.log > "$BACKUP_PATH/recent-pacman.log" 2>/dev/null || true
        log_success "Saved recent pacman logs"
    fi

    # Generate recovery instructions
    log_info "Generating recovery instructions..."
    cat > "$BACKUP_PATH/RECOVERY-INSTRUCTIONS.txt" << 'EOF'
# EMERGENCY BOOT RECOVERY INSTRUCTIONS

## If System Won't Boot

### 1. Boot from Arch Linux Live USB

### 2. Mount Your System
```bash
# Find your root partition (check partition-layout.txt in this backup)
lsblk

# Mount root partition (replace /dev/sdXY with your root partition)
mount /dev/sdXY /mnt

# Mount EFI/boot partition (replace /dev/sdXZ with your EFI partition)
mount /dev/sdXZ /mnt/boot

# Mount other partitions if needed (e.g., /home)
# mount /dev/sdXW /mnt/home
```

### 3. Chroot into Your System
```bash
arch-chroot /mnt
```

### 4. Fix Common Issues

#### Problem: "unknown filesystem 'vfat'"
```bash
# Edit mkinitcpio configuration
nano /etc/mkinitcpio.conf

# Add 'vfat' to MODULES array:
MODULES=(vfat)

# Regenerate initramfs
mkinitcpio -P
```

#### Problem: Missing initramfs
```bash
# Regenerate all initramfs images
mkinitcpio -P
```

#### Problem: GRUB not detecting kernel
```bash
# Reinstall GRUB (EFI)
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# Regenerate GRUB config
grub-mkconfig -o /boot/grub/grub.cfg
```

#### Problem: Corrupted kernel
```bash
# Check installed kernels (see installed-kernels.txt)
pacman -Q | grep linux

# Reinstall main kernel
pacman -S linux

# Or install fallback kernel
pacman -S linux-lts

# Regenerate initramfs
mkinitcpio -P

# Update GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

### 5. Restore Configuration Files from Backup

If needed, restore backed-up configuration files:

```bash
# From the live USB, copy backup files to your mounted system
cp /path/to/backup/fstab.backup /mnt/etc/fstab
cp /path/to/backup/mkinitcpio.conf.backup /mnt/etc/mkinitcpio.conf
cp /path/to/backup/grub.default.backup /mnt/etc/default/grub

# OR restore entire /boot from tar backup (if /boot is corrupted)
cd /mnt
tar -xzf /path/to/backup/boot-full-backup.tar.gz
```

### 6. Exit and Reboot
```bash
exit          # Exit chroot
umount -R /mnt
reboot
```

## Prevention Tips

1. Always keep multiple kernels installed (linux + linux-lts)
2. Run arch-boot-check.sh before rebooting after upgrades
3. Create regular backups with this script
4. Never do partial upgrades (always use: pacman -Syu)
5. Check /var/log/pacman.log for hook failures after upgrades

## Important Files in This Backup

- boot-full-backup.tar.gz: Complete /boot directory backup (kernels, initramfs, GRUB)
- fstab.backup: Filesystem mount table
- mkinitcpio.conf.backup: Initramfs configuration
- grub.cfg.backup: GRUB bootloader configuration
- grub.default.backup: GRUB default settings
- partition-layout.txt: Your disk partition structure
- efi-boot-entries.txt: EFI boot manager entries
- installed-kernels.txt: List of kernel packages
- all-packages.txt: Complete package list for system restoration
EOF

    log_success "Generated recovery instructions"

    # Cleanup old backups (keep last 10)
    log_info "Cleaning up old backups (keeping last 10)..."
    local backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name 'boot-backup-*' 2>/dev/null | wc -l || echo "0")
    if [[ "$backup_count" =~ ^[0-9]+$ ]] && [[ $backup_count -gt 10 ]]; then
        # Use find with null-terminated output for safety with special characters
        find "$BACKUP_DIR" -maxdepth 1 -type d -name 'boot-backup-*' -printf '%T@ %p\0' 2>/dev/null | \
            sort -zn | \
            head -z -n -10 | \
            cut -z -d' ' -f2- | \
            while IFS= read -r -d '' old_backup; do
                if [[ -d "$old_backup" ]]; then
                    rm -rf "$old_backup"
                    log_info "Removed old backup: $(basename "$old_backup")"
                fi
            done
    fi

    echo ""
    log_success "Backup completed successfully!"
    echo ""
    echo "Backup saved to: $BACKUP_PATH"
    echo ""
    echo "To view recovery instructions:"
    echo "  cat $BACKUP_PATH/RECOVERY-INSTRUCTIONS.txt"
}

list_backups() {
    echo "╔════════════════════════════════════════════════╗"
    echo "║   Available Boot Configuration Backups        ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""

    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        log_warn "No backups found in $BACKUP_DIR"
        exit 0
    fi

    local count=1
    for backup in $(ls -1t "$BACKUP_DIR"); do
        local backup_path="${BACKUP_DIR}/${backup}"
        local size=$(du -sh "$backup_path" | cut -f1)
        local date_created=$(stat -c %y "$backup_path" | cut -d' ' -f1,2 | cut -d'.' -f1)

        echo "${count}. $backup"
        echo "   Created: $date_created"
        echo "   Size: $size"
        echo "   Path: $backup_path"
        echo ""

        ((count++))
    done

    echo "Total backups: $((count - 1))"
}

restore_backup() {
    echo "╔════════════════════════════════════════════════╗"
    echo "║   Restore Boot Configuration from Backup      ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""

    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        log_error "No backups found in $BACKUP_DIR"
        exit 1
    fi

    log_info "Available backups:"
    echo ""

    local backups=($(ls -1t "$BACKUP_DIR"))
    local count=1

    for backup in "${backups[@]}"; do
        local date_created=$(stat -c %y "${BACKUP_DIR}/${backup}" | cut -d' ' -f1,2 | cut -d'.' -f1)
        echo "  ${count}. $backup (${date_created})"
        ((count++))
    done

    echo ""
    read -p "Select backup number to restore (or 'q' to quit): " selection

    if [[ "$selection" == "q" ]]; then
        echo "Cancelled."
        exit 0
    fi

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ $selection -lt 1 ]] || [[ $selection -gt ${#backups[@]} ]]; then
        log_error "Invalid selection"
        exit 1
    fi

    local selected_backup="${backups[$((selection - 1))]}"
    local selected_path="${BACKUP_DIR}/${selected_backup}"

    echo ""
    log_warn "You are about to restore configuration from: $selected_backup"
    log_warn "This will overwrite current configuration files!"
    echo ""
    read -p "Are you sure? Type 'yes' to continue: " confirmation

    if [[ "$confirmation" != "yes" ]]; then
        echo "Cancelled."
        exit 0
    fi

    echo ""
    log_info "Restoring configuration files..."

    # Restore files with sudo if needed
    local need_sudo=false
    if [[ $EUID -ne 0 ]]; then
        need_sudo=true
        log_info "Some files require sudo privileges"
    fi

    # Restore fstab
    if [[ -f "${selected_path}/fstab.backup" ]]; then
        if $need_sudo; then
            sudo cp "${selected_path}/fstab.backup" /etc/fstab
        else
            cp "${selected_path}/fstab.backup" /etc/fstab
        fi
        log_success "Restored /etc/fstab"
    fi

    # Restore mkinitcpio.conf
    if [[ -f "${selected_path}/mkinitcpio.conf.backup" ]]; then
        if $need_sudo; then
            sudo cp "${selected_path}/mkinitcpio.conf.backup" /etc/mkinitcpio.conf
        else
            cp "${selected_path}/mkinitcpio.conf.backup" /etc/mkinitcpio.conf
        fi
        log_success "Restored /etc/mkinitcpio.conf"
    fi

    # Restore grub defaults
    if [[ -f "${selected_path}/grub.default.backup" ]]; then
        if $need_sudo; then
            sudo cp "${selected_path}/grub.default.backup" /etc/default/grub
        else
            cp "${selected_path}/grub.default.backup" /etc/default/grub
        fi
        log_success "Restored /etc/default/grub"
    fi

    echo ""
    log_success "Configuration files restored!"
    echo ""
    log_warn "IMPORTANT: You may need to:"
    echo "  1. Regenerate initramfs: sudo mkinitcpio -P"
    echo "  2. Update GRUB config: sudo grub-mkconfig -o /boot/grub/grub.cfg"
    echo ""
    echo "For full recovery instructions, see:"
    echo "  cat ${selected_path}/RECOVERY-INSTRUCTIONS.txt"
}

# --- Main Execution ---

case "$ACTION" in
    backup)
        create_backup
        ;;
    list)
        list_backups
        ;;
    restore)
        restore_backup
        ;;
esac
