#!/bin/bash

set -euo pipefail

# Arch Linux System Manager
# Interactive menu to manage boot safety, updates, services, and system timeline

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
    echo -e "${CYAN}║          ${MAGENTA}Arch Linux System Manager${CYAN}                       ║${NC}"
    echo -e "${CYAN}║                                                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section_header() {
    local title="$1"
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                              ║${NC}"
    printf "${CYAN}║${MAGENTA}%*s${CYAN}║${NC}\n" $((31 + ${#title}/2)) "$title" | sed "s/$/$(printf '%*s' $((31 - ${#title}/2)) '')/; s/^//"
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

# ═══════════════════════════════════════════════════════════════
# MAIN MENU - Single Page with Submenus
# ═══════════════════════════════════════════════════════════════

show_main_menu() {
    print_header
    echo -e "${CYAN}═══ System Management Menu ═══${NC}"
    echo ""

    # Boot Management Section
    echo -e "${GREEN}1${NC})   ${BLUE}⚙️  Boot Management${NC}"
    echo -e "      ${MAGENTA}a${NC})  ${YELLOW}⚡ Quick Safety Check${NC} - Is it safe to reboot?"
    echo -e "      ${MAGENTA}b${NC})  ${YELLOW}📖 Boot Process Help${NC} - Understand how boot works"
    echo -e "      ${GREEN}1${NC})  View GRUB Configuration"
    echo -e "      ${GREEN}2${NC})  Run Boot Safety Check"
    echo -e "      ${GREEN}3${NC})  Auto-Fix Boot Issues ${RED}[modifies system]${NC}"
    echo -e "      ${GREEN}4${NC})  Create Boot Backup"
    echo -e "      ${GREEN}5${NC})  List Backups"
    echo -e "      ${GREEN}6${NC})  Restore from Backup ${RED}[modifies system]${NC}"
    echo -e "      ${GREEN}7${NC})  View Timeshift Snapshots"
    echo ""

    # Update Management Section
    echo -e "${GREEN}2${NC})   ${BLUE}📦  Update Management${NC}"
    echo -e "      ${GREEN}1${NC})  Preview Pending Updates"
    echo -e "      ${GREEN}2${NC})  Analyze Package"
    echo -e "      ${GREEN}3${NC})  Complete Upgrade Workflow"
    echo ""

    # Package Timeline Section
    echo -e "${GREEN}3${NC})   ${BLUE}📊  Package Timeline${NC}"
    echo -e "      ${GREEN}1${NC})  View Complete Timeline"
    echo -e "      ${GREEN}2${NC})  View Recent Activity (Last 50)"
    echo -e "      ${GREEN}3${NC})  Search Timeline"
    echo ""

    # Services & Scripts Section
    echo -e "${GREEN}4${NC})   ${BLUE}🔧  Services & Scripts${NC}"
    echo -e "      ${GREEN}1${NC})  Active Systemd Services"
    echo -e "      ${GREEN}2${NC})  Failed Services"
    echo -e "      ${GREEN}3${NC})  Systemd Timers"
    echo -e "      ${GREEN}4${NC})  Cron Jobs"
    echo -e "      ${GREEN}5${NC})  User Scripts & Tools"
    echo -e "      ${GREEN}6${NC})  Enabled Services"
    echo -e "      ${GREEN}7${NC})  Recent Service Changes"
    echo ""

    # Installation & Docs
    echo -e "${YELLOW}5${NC})   ${MAGENTA}🛠️  Install System Tools${NC} - Install scripts & hooks system-wide"
    echo -e "${YELLOW}6${NC})   ${MAGENTA}📖  Documentation${NC} - View help files"
    echo ""
    echo -e "${RED}0${NC})   Exit"
    echo ""
    echo -ne "${CYAN}Select option (e.g., 11, 23, 1a):${NC} "
}

# ═══════════════════════════════════════════════════════════════
# ACTION FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════
# BOOT MANAGEMENT ACTIONS
# ═══════════════════════════════════════════════════════════════

action_quick_check() {
    if [[ ! -x "$BOOT_CHECK_SCRIPT" ]]; then
        echo -e "${RED}✗ Script not found or not executable: $BOOT_CHECK_SCRIPT${NC}"
        pause
        return 1
    fi

    print_section_header "Quick Safety Check"
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
        echo -e "${YELLOW}Recommendation:${NC} Try Auto-Fix option from Boot menu"
    fi

    pause
}

action_boot_help() {
    # Generate the help content and pipe to less with color support
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
}

action_view_grub() {
    print_section_header "GRUB Configuration"

    local grub_cfg="/boot/grub/grub.cfg"

    if [[ ! -f "$grub_cfg" ]]; then
        echo -e "${RED}✗ GRUB config not found at $grub_cfg${NC}"
        pause
        return 1
    fi

    echo -e "${BLUE}━━━ GRUB Menu Entries ━━━${NC}"
    echo ""

    local menu_entries=$(grep "^menuentry" "$grub_cfg" | sed "s/menuentry '\([^']*\)'.*/\1/")
    local entry_count=$(echo "$menu_entries" | wc -l)

    echo -e "${GREEN}Found $entry_count menu entries:${NC}"
    echo ""

    local counter=1
    while IFS= read -r entry; do
        if echo "$entry" | grep -q "linux"; then
            echo -e "  ${GREEN}$counter.${NC} ${CYAN}$entry${NC}"
        else
            echo -e "  ${GREEN}$counter.${NC} $entry"
        fi
        ((counter++))
    done <<< "$menu_entries"

    pause
}

action_boot_check() {
    if [[ ! -x "$BOOT_CHECK_SCRIPT" ]]; then
        echo -e "${RED}✗ Script not found: $BOOT_CHECK_SCRIPT${NC}"
        pause
        return 1
    fi

    print_section_header "Boot Safety Check"
    if [[ $EUID -ne 0 ]]; then
        sudo "$BOOT_CHECK_SCRIPT"
    else
        "$BOOT_CHECK_SCRIPT"
    fi
    pause
}

action_boot_autofix() {
    if [[ ! -x "$BOOT_CHECK_SCRIPT" ]]; then
        echo -e "${RED}✗ Script not found: $BOOT_CHECK_SCRIPT${NC}"
        pause
        return 1
    fi

    print_section_header "Auto-Fix Boot Issues"
    echo -e "${YELLOW}This will automatically fix common boot issues${NC}"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 0
    fi

    if [[ $EUID -ne 0 ]]; then
        sudo "$BOOT_CHECK_SCRIPT" --auto-fix
    else
        "$BOOT_CHECK_SCRIPT" --auto-fix
    fi
    pause
}

action_create_backup() {
    if [[ ! -x "$BACKUP_SCRIPT" ]]; then
        echo -e "${RED}✗ Script not found: $BACKUP_SCRIPT${NC}"
        pause
        return 1
    fi

    print_section_header "Create Boot Backup"
    "$BACKUP_SCRIPT"
    pause
}

action_list_backups() {
    if [[ ! -x "$BACKUP_SCRIPT" ]]; then
        echo -e "${RED}✗ Script not found: $BACKUP_SCRIPT${NC}"
        pause
        return 1
    fi

    print_section_header "Available Backups"
    "$BACKUP_SCRIPT" --list
    pause
}

action_restore_backup() {
    if [[ ! -x "$BACKUP_SCRIPT" ]]; then
        echo -e "${RED}✗ Script not found: $BACKUP_SCRIPT${NC}"
        pause
        return 1
    fi

    print_section_header "Restore from Backup"
    "$BACKUP_SCRIPT" --restore
    pause
}

action_view_timeshift() {
    print_section_header "Timeshift Snapshots"

    local has_timeshift=false
    local has_btrfs=false

    # Check if Timeshift is installed
    if command -v timeshift &> /dev/null; then
        has_timeshift=true
    fi

    # Check if using BTRFS
    if command -v btrfs &> /dev/null; then
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
        pause
        return 1
    fi

    # Show Timeshift snapshots
    if [[ "$has_timeshift" == "true" ]]; then
        echo -e "${BLUE}━━━ Timeshift Snapshots ━━━${NC}"
        echo ""

        # Get snapshot list
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
        else
            # Parse snapshots
            local snapshots=$(echo "$snapshot_output" | grep "^>" || true)
            local snapshot_count=0
            if [[ -n "$snapshots" ]]; then
                snapshot_count=$(echo "$snapshots" | wc -l)
            fi

            if [[ $snapshot_count -eq 0 ]]; then
                echo -e "${YELLOW}⚠ No snapshots available${NC}"
                echo ""
            else
                echo -e "${GREEN}Found $snapshot_count snapshot(s):${NC}"
                echo ""
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

                # Display each snapshot
                local counter=1
                while IFS= read -r line; do
                    if [[ "$line" =~ ^\> ]]; then
                        local snapshot_info=$(echo "$line" | sed 's/^> //')
                        echo -e "${CYAN}$counter.${NC} $snapshot_info"
                        ((counter++))
                    fi
                done <<< "$snapshot_output"

                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo ""

                # Show most recent
                local most_recent=$(echo "$snapshots" | head -1 | sed 's/^> //')
                if [[ -n "$most_recent" ]]; then
                    echo -e "${GREEN}Most recent:${NC} $most_recent"
                    echo ""
                fi
            fi

            # Disk usage
            echo -e "${BLUE}━━━ Quick Actions ━━━${NC}"
            echo ""
            echo -e "${CYAN}Create snapshot:${NC}"
            echo "  sudo timeshift --create --comments 'Before kernel update'"
            echo ""
            echo -e "${CYAN}Restore:${NC}"
            echo "  sudo timeshift --restore"
            echo ""
            echo -e "${YELLOW}Note:${NC} Timeshift may not backup /boot or EFI partition!"
            echo "      Use option 4 (Create Boot Backup) for boot configs."
        fi
    fi

    # Show BTRFS snapshots if available
    if [[ "$has_btrfs" == "true" ]]; then
        echo ""
        echo -e "${BLUE}━━━ BTRFS Snapshots ━━━${NC}"
        echo ""

        local btrfs_snapshots
        if [[ $EUID -eq 0 ]]; then
            btrfs_snapshots=$(btrfs subvolume list / 2>/dev/null | grep -i snapshot || true)
        else
            btrfs_snapshots=$(sudo btrfs subvolume list / 2>/dev/null | grep -i snapshot || true)
        fi

        if [[ -z "$btrfs_snapshots" ]]; then
            echo -e "${YELLOW}⚠ No BTRFS snapshots found${NC}"
        else
            local count=$(echo "$btrfs_snapshots" | wc -l)
            echo -e "${GREEN}Found $count BTRFS snapshot(s)${NC}"
            echo ""
            echo "$btrfs_snapshots" | head -10 | while IFS= read -r line; do
                local snap_path=$(echo "$line" | awk '{print $NF}')
                echo -e "  ${CYAN}•${NC} $snap_path"
            done
            if [[ $count -gt 10 ]]; then
                echo "  ... and $((count - 10)) more"
            fi
        fi
    fi

    pause
}

# ═══════════════════════════════════════════════════════════════
# UPDATE MANAGEMENT ACTIONS
# ═══════════════════════════════════════════════════════════════

action_pre_upgrade() {
    if [[ ! -x "$PRE_UPGRADE_SCRIPT" ]]; then
        echo -e "${RED}✗ Script not found: $PRE_UPGRADE_SCRIPT${NC}"
        pause
        return 1
    fi

    print_section_header "Preview Pending Updates"
    "$PRE_UPGRADE_SCRIPT"
    pause
}

action_analyze_package() {
    print_section_header "Package Analysis"

    read -p "Enter package name to analyze: " package_name

    if [[ -z "$package_name" ]]; then
        return 0
    fi

    if ! pacman -Si "$package_name" &>/dev/null; then
        echo -e "${RED}✗ Package not found: $package_name${NC}"
        pause
        return 1
    fi

    local version=$(pacman -Si "$package_name" | grep "^Version" | cut -d':' -f2- | xargs)
    local size=$(pacman -Si "$package_name" | grep "^Installed Size" | cut -d':' -f2- | xargs)

    echo ""
    echo -e "${CYAN}Package:${NC} $package_name"
    echo -e "${CYAN}Version:${NC} $version"
    echo -e "${CYAN}Size:${NC} $size"

    pause
}

action_upgrade_workflow() {
    print_section_header "Complete Upgrade Workflow"

    echo "This will guide you through a safe upgrade process"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 0
    fi

    # Step 1: Preview
    if [[ -x "$PRE_UPGRADE_SCRIPT" ]]; then
        "$PRE_UPGRADE_SCRIPT"
    fi

    # Step 2: Backup
    echo ""
    read -p "Create backup before upgrade? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]] && [[ -x "$BACKUP_SCRIPT" ]]; then
        "$BACKUP_SCRIPT"
    fi

    # Step 3: Manual upgrade instruction
    echo ""
    echo -e "${CYAN}Run: ${GREEN}sudo pacman -Syu${NC}"
    echo ""
    read -p "Press ENTER when upgrade is complete..." -r

    # Step 4: Validation
    if [[ -x "$BOOT_CHECK_SCRIPT" ]]; then
        sudo "$BOOT_CHECK_SCRIPT"
    fi

    pause
}

# ═══════════════════════════════════════════════════════════════
# TIMELINE ACTIONS
# ═══════════════════════════════════════════════════════════════

action_view_timeline() {
    if [[ ! -x "$TIMELINE_SCRIPT" ]]; then
        echo -e "${RED}✗ Script not found: $TIMELINE_SCRIPT${NC}"
        pause
        return 1
    fi

    "$TIMELINE_SCRIPT" --view
}

action_view_recent_timeline() {
    local timeline_file="/home/${SUDO_USER:-$USER}/.local/state/arch-package-state/timeline.log"

    if [[ ! -f "$timeline_file" ]]; then
        echo -e "${YELLOW}⚠ No timeline data found${NC}"
        pause
        return 1
    fi

    print_section_header "Recent Package Activity"
    echo -e "${CYAN}Last 50 package operations:${NC}"
    echo ""

    tail -50 "$timeline_file" | while IFS='|' read -r timestamp operation package version old_ver; do
        case "$operation" in
            INSTALLED) echo -e "  ${GREEN}📦 INSTALLED${NC}   $timestamp  $package ($version)" ;;
            UPGRADED)  echo -e "  ${YELLOW}⬆️  UPGRADED${NC}    $timestamp  $package ($old_ver → $version)" ;;
            REMOVED)   echo -e "  ${RED}🗑️  REMOVED${NC}     $timestamp  $package" ;;
            *)         echo -e "  $operation  $timestamp  $package" ;;
        esac
    done

    pause
}

action_search_timeline() {
    local timeline_file="/home/${SUDO_USER:-$USER}/.local/state/arch-package-state/timeline.log"

    if [[ ! -f "$timeline_file" ]]; then
        echo -e "${YELLOW}⚠ No timeline data found${NC}"
        pause
        return 1
    fi

    print_section_header "Search Timeline"
    read -p "Enter package name to search: " search_term

    if [[ -z "$search_term" ]]; then
        return 0
    fi

    echo ""
    echo -e "${CYAN}Results for: $search_term${NC}"
    echo ""

    grep -i "$search_term" "$timeline_file" | while IFS='|' read -r timestamp operation package version old_ver; do
        echo -e "  $timestamp  ${YELLOW}$operation${NC}  $package  ($version)"
    done

    pause
}

# ═══════════════════════════════════════════════════════════════
# SERVICES & SCRIPTS ACTIONS
# ═══════════════════════════════════════════════════════════════

action_active_services() {
    print_section_header "Active Systemd Services"

    echo -e "${CYAN}Currently running services:${NC}"
    echo ""

    systemctl list-units --type=service --state=running --no-pager | head -30

    echo ""
    echo -e "${BLUE}Showing first 30 services. Use 'systemctl list-units --type=service' for complete list.${NC}"

    pause
}

action_failed_services() {
    print_section_header "Failed Services"

    local failed=$(systemctl list-units --type=service --state=failed --no-pager)

    if echo "$failed" | grep -q "0 loaded units listed"; then
        echo -e "${GREEN}✓ No failed services!${NC}"
    else
        echo -e "${RED}Failed service units:${NC}"
        echo ""
        echo "$failed"
    fi

    pause
}

action_systemd_timers() {
    print_section_header "Systemd Timers"

    echo -e "${CYAN}Active systemd timers:${NC}"
    echo ""

    systemctl list-timers --all --no-pager

    pause
}

action_cron_jobs() {
    print_section_header "Cron Jobs"

    echo -e "${CYAN}System crontab (/etc/crontab):${NC}"
    echo ""
    if [[ -f /etc/crontab ]]; then
        cat /etc/crontab | grep -v "^#" | grep -v "^$" || echo "  No entries"
    else
        echo "  Not found"
    fi

    echo ""
    echo -e "${CYAN}User crontab ($USER):${NC}"
    echo ""
    crontab -l 2>/dev/null || echo "  No crontab for $USER"

    echo ""
    echo -e "${CYAN}System cron directories:${NC}"
    echo ""
    for dir in /etc/cron.{hourly,daily,weekly,monthly}; do
        if [[ -d "$dir" ]]; then
            local count=$(ls -1 "$dir" 2>/dev/null | wc -l)
            echo -e "  ${BLUE}$dir${NC}: $count scripts"
        fi
    done

    pause
}

action_user_scripts() {
    print_section_header "User Scripts & Tools"

    echo -e "${CYAN}Custom scripts in /usr/local/bin:${NC}"
    echo ""
    if [[ -d /usr/local/bin ]]; then
        ls -lh /usr/local/bin | grep -E "arch-.*\.sh$" || echo "  No arch-*.sh scripts found"
    fi

    echo ""
    echo -e "${CYAN}Scripts in ~/bin or ~/.local/bin:${NC}"
    echo ""
    for dir in ~/bin ~/.local/bin; do
        if [[ -d "$dir" ]]; then
            echo -e "${BLUE}$dir:${NC}"
            ls -1 "$dir" | head -10
            echo ""
        fi
    done

    pause
}

action_enabled_services() {
    print_section_header "Enabled Services"

    echo -e "${CYAN}Services enabled at boot:${NC}"
    echo ""

    systemctl list-unit-files --type=service --state=enabled --no-pager | head -30

    echo ""
    echo -e "${BLUE}Showing first 30 enabled services.${NC}"

    pause
}

action_recent_service_changes() {
    print_section_header "Recent Service Changes"

    echo -e "${CYAN}Recently modified systemd units:${NC}"
    echo ""

    find /etc/systemd/system /usr/lib/systemd/system -type f -name "*.service" -mtime -30 2>/dev/null | while read -r file; do
        local mtime=$(stat -c %y "$file" | cut -d'.' -f1)
        echo -e "  ${YELLOW}$mtime${NC}  $(basename "$file")"
    done | head -20

    pause
}

# ═══════════════════════════════════════════════════════════════
# INSTALLATION ACTIONS
# ═══════════════════════════════════════════════════════════════

action_install_tools() {
    print_section_header "Install System Tools"

    echo -e "${YELLOW}This will install scripts and hooks system-wide${NC}"
    echo ""
    echo -e "  • arch-boot-check.sh → /usr/local/bin/"
    echo -e "  • arch-package-timeline.sh → /usr/local/bin/"
    echo -e "  • Pacman hooks → /etc/pacman.d/hooks/"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 0
    fi

    # Install scripts
    for script in "$BOOT_CHECK_SCRIPT" "$TIMELINE_SCRIPT"; do
        if [[ -f "$script" ]]; then
            sudo cp "$script" /usr/local/bin/
            sudo chmod +x "/usr/local/bin/$(basename "$script")"
            echo -e "${GREEN}✓ Installed $(basename "$script")${NC}"
        fi
    done

    # Install hooks
    sudo mkdir -p /etc/pacman.d/hooks
    for hook in "${SCRIPT_DIR}"/99-*.hook; do
        if [[ -f "$hook" ]]; then
            sudo cp "$hook" /etc/pacman.d/hooks/
            echo -e "${GREEN}✓ Installed $(basename "$hook")${NC}"
        fi
    done

    echo ""
    echo -e "${GREEN}✓ Installation complete!${NC}"

    pause
}

action_view_docs() {
    local doc_file="${SCRIPT_DIR}/README.md"

    if [[ -f "$doc_file" ]]; then
        less "$doc_file" 2>/dev/null || cat "$doc_file"
    else
        echo -e "${YELLOW}⚠ Documentation not found${NC}"
    fi

    pause
}


# ═══════════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════════

main() {
    while true; do
        show_main_menu
        read -r choice

        # Convert to lowercase for case-insensitive matching
        choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

        case $choice_lower in
            # Boot Management
            1a) action_quick_check ;;
            1b) action_boot_help ;;
            11) action_view_grub ;;
            12) action_boot_check ;;
            13) action_boot_autofix ;;
            14) action_create_backup ;;
            15) action_list_backups ;;
            16) action_restore_backup ;;
            17) action_view_timeshift ;;

            # Update Management
            21) action_pre_upgrade ;;
            22) action_analyze_package ;;
            23) action_upgrade_workflow ;;

            # Package Timeline
            31) action_view_timeline ;;
            32) action_view_recent_timeline ;;
            33) action_search_timeline ;;

            # Services & Scripts
            41) action_active_services ;;
            42) action_failed_services ;;
            43) action_systemd_timers ;;
            44) action_cron_jobs ;;
            45) action_user_scripts ;;
            46) action_enabled_services ;;
            47) action_recent_service_changes ;;

            # Installation & Documentation
            5) action_install_tools ;;
            6) action_view_docs ;;

            # Exit
            0)
                echo ""
                echo -e "${GREEN}Goodbye!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# --- Entry Point ---
main "$@"
