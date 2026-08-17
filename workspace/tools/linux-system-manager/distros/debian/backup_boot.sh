#!/bin/bash

set -euo pipefail

# Debian / Ubuntu Boot Configuration Backup Script
# Creates a comprehensive backup of boot-related configurations
# for emergency recovery purposes

# --- Configuration ---
# Resolve the invoking user's home from passwd, not $HOME. Under sudo $HOME is
# /root, so backups created via an escalated path landed in /root/.boot-backups
# while "List Backups" run normally looked in the user's home and saw nothing.
_backup_user="${SUDO_USER:-${USER:-$(id -un 2>/dev/null || echo root)}}"
_backup_home="$(getent passwd "$_backup_user" 2>/dev/null | cut -d: -f6)"
if [[ -z "$_backup_home" || ! -d "$_backup_home" ]]; then
    _backup_home="${HOME:-/root}"
fi

BACKUP_DIR="${BOOT_BACKUP_DIR:-${_backup_home}/.boot-backups}"
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
      echo "Debian / Ubuntu Boot Configuration Backup & Restore"
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
        echo "# Debian / Ubuntu Boot Backup"
        echo "# Created: $(date)"
        echo "# Hostname: $(hostname)"
        echo "# Kernel: $(uname -r)"
        echo ""
    } > "$BACKUP_PATH/backup-info.txt"

    # Installed kernels
    log_info "Backing up kernel package list..."
    if dpkg-query -W -f='${Status} ${Package}\n' 2>/dev/null | grep '^install ok installed' | awk '{print $4}' | grep -E '^linux-image-[0-9]' > "$BACKUP_PATH/installed-kernels.txt" 2>/dev/null; then
        log_success "Saved to installed-kernels.txt"
    else
        log_warn "No Linux kernel packages found (creating empty file)"
        echo "# No Linux kernel packages found at backup time" > "$BACKUP_PATH/installed-kernels.txt"
    fi

    # /etc/fstab
    if [[ -f /etc/fstab ]]; then
        log_info "Backing up /etc/fstab..."
        cp /etc/fstab "$BACKUP_PATH/fstab.backup"
        log_success "Saved fstab"
    fi

    # /etc/initramfs-tools/
    if [[ -d /etc/initramfs-tools ]]; then
        log_info "Backing up /etc/initramfs-tools..."
        mkdir -p "$BACKUP_PATH/initramfs-tools"
        cp -r /etc/initramfs-tools/* "$BACKUP_PATH/initramfs-tools/" 2>/dev/null || true
        log_success "Saved initramfs-tools config"
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
        # shellcheck disable=SC2024  # sudo elevates the *read*; the redirect is
        # intentionally performed as the invoking user so the backup file stays
        # user-owned. `| sudo tee` would make it root-owned inside their home.
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
            # shellcheck disable=SC2024  # sudo elevates the *read*; the redirect is
            # intentionally performed as the invoking user so the backup file stays
            # user-owned. `| sudo tee` would make it root-owned inside their home.
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
        log_info "Contains: kernels, initrd, GRUB config, etc."
        rm -f "$tar_error"
    else
        log_warn "Could not create full /boot tar backup"
        if [[ -f "$tar_error" ]] && [[ -s "$tar_error" ]]; then
            log_info "Error details saved to: $tar_error"
        fi
    fi

    # dpkg package list (all)
    log_info "Backing up all installed packages..."
    dpkg --get-selections > "$BACKUP_PATH/all-packages.txt"
    log_success "Saved package list"

    # Recent dpkg log entries
    if [[ -f /var/log/dpkg.log ]]; then
        log_info "Extracting recent dpkg logs..."
        tail -500 /var/log/dpkg.log > "$BACKUP_PATH/recent-dpkg.log" 2>/dev/null || true
        log_success "Saved recent dpkg logs"
    fi

    # Generate recovery instructions
    log_info "Generating recovery instructions..."
    cat > "$BACKUP_PATH/RECOVERY-INSTRUCTIONS.txt" << 'EOF'
# EMERGENCY BOOT RECOVERY INSTRUCTIONS (DEBIAN / UBUNTU)

## If System Won't Boot

### 1. Boot from a Live USB (Ubuntu or Debian installer)

### 2. Mount Your System
```bash
# Find your root partition (check partition-layout.txt in this backup)
lsblk

# Mount root partition (replace /dev/sdXY with your root partition)
mount /dev/sdXY /mnt

# Mount EFI/boot partition (replace /dev/sdXZ with your EFI partition)
mount /dev/sdXZ /mnt/boot

# Mount necessary virtual filesystems for chroot
for i in /dev /dev/pts /proc /sys /run; do mount -B $i /mnt$i; done
```

### 3. Chroot into Your System
```bash
chroot /mnt
```

### 4. Fix Common Issues

#### Problem: Missing initramfs/initrd
```bash
# Regenerate all initrd images
update-initramfs -u -k all
```

#### Problem: GRUB not detecting kernel
```bash
# Reinstall GRUB (EFI)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu

# Regenerate GRUB config
update-grub
```

#### Problem: Corrupted kernel
```bash
# Reinstall kernel package (see installed-kernels.txt in backup)
apt-get install --reinstall linux-image-generic
```

### 5. Restore Configuration Files from Backup

If needed, restore backed-up configuration files from the live USB (outside chroot or copying to /mnt):

```bash
cp /path/to/backup/fstab.backup /mnt/etc/fstab
cp -r /path/to/backup/initramfs-tools/* /mnt/etc/initramfs-tools/
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
EOF

    log_success "Generated recovery instructions"

    # Cleanup old backups (keep last 10)
    log_info "Cleaning up old backups (keeping last 10)..."
    local backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name 'boot-backup-*' 2>/dev/null | wc -l || echo "0")
    if [[ "$backup_count" =~ ^[0-9]+$ ]] && [[ $backup_count -gt 10 ]]; then
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

    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_warn "No backups found in $BACKUP_DIR"
        exit 0
    fi

    local backups=()
    while IFS= read -r -d '' backup_path; do
        [[ -n "$backup_path" ]] && backups+=("$backup_path")
    done < <(find "$BACKUP_DIR" -maxdepth 1 -mindepth 1 -type d -name 'boot-backup-*' -printf '%T@ %p\0' 2>/dev/null | sort -znr | cut -zd' ' -f2-)

    if [[ ${#backups[@]} -eq 0 ]]; then
        log_warn "No backups found in $BACKUP_DIR"
        exit 0
    fi

    local count=1
    for backup_path in "${backups[@]}"; do
        local backup_name=$(basename "$backup_path")
        local size=$(du -sh "$backup_path" | cut -f1)
        local date_created=$(stat -c %y "$backup_path" | cut -d' ' -f1,2 | cut -d'.' -f1)

        echo "${count}. $backup_name"
        echo "   Created: $date_created"
        echo "   Size: $size"
        echo "   Path: $backup_path"
        echo ""

        count=$((count + 1))
    done

    echo "Total backups: $((count - 1))"
}

restore_backup() {
    echo "╔════════════════════════════════════════════════╗"
    echo "║   Restore Boot Configuration from Backup      ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""

    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_error "No backups found in $BACKUP_DIR"
        exit 1
    fi

    local backups=()
    while IFS= read -r -d '' backup_path; do
        [[ -n "$backup_path" ]] && backups+=("$backup_path")
    done < <(find "$BACKUP_DIR" -maxdepth 1 -mindepth 1 -type d -name 'boot-backup-*' -printf '%T@ %p\0' 2>/dev/null | sort -znr | cut -zd' ' -f2-)

    if [[ ${#backups[@]} -eq 0 ]]; then
        log_warn "No backups found in $BACKUP_DIR"
        exit 0
    fi

    log_info "Available backups:"
    echo ""

    local count=1
    for backup_path in "${backups[@]}"; do
        local backup_name=$(basename "$backup_path")
        local date_created=$(stat -c %y "$backup_path" | cut -d' ' -f1,2 | cut -d'.' -f1)
        echo "  ${count}. $backup_name (${date_created})"
        count=$((count + 1))
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

    local selected_path="${backups[$((selection - 1))]}"
    local selected_backup=$(basename "$selected_path")

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

    # Restore initramfs-tools
    if [[ -d "${selected_path}/initramfs-tools" ]]; then
        if $need_sudo; then
            sudo cp -r "${selected_path}/initramfs-tools"/* /etc/initramfs-tools/
        else
            cp -r "${selected_path}/initramfs-tools"/* /etc/initramfs-tools/
        fi
        log_success "Restored /etc/initramfs-tools"
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
    echo "  1. Regenerate initramfs: sudo update-initramfs -u -k all"
    echo "  2. Update GRUB config: sudo update-grub"
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
