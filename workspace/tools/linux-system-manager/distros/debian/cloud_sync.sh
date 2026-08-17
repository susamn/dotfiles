#!/bin/bash
# Distro-agnostic cloud sync and mount manager for linux-system-manager.
# Manages systemd timer configurations, mount services, and rclone configurations for individual users.

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

action=""
if [[ $# -gt 0 ]]; then
    action="$1"
fi

# Detect actual user if running via sudo
REAL_USER="${SUDO_USER:-${USER:-$(id -un)}}"

# Resolve a user's home from passwd. $HOME must NOT be used for this: under sudo
# it is /root while REAL_USER is the invoking user, so every profile lookup silently
# searched root's config directory and reported "no profiles configured".
user_home() {
    local target="$1"
    local resolved
    resolved="$(getent passwd "$target" 2>/dev/null | cut -d: -f6)"
    if [[ -n "$resolved" ]]; then
        echo "$resolved"
    elif [[ "$target" == "${USER:-}" && -n "${HOME:-}" ]]; then
        # Not in passwd (container, NSS gap): only $HOME can speak for the current
        # user. Guessing /home/<user> would be wrong on exactly the systems where
        # passwd lookup already failed.
        echo "$HOME"
    fi
}

PROFILE_SUBDIR=".config/rclone-sync-profiles"

# Search order: the invoking user's home first, then root's. Deduplicated so that
# running as root does not list every profile twice.
PROFILE_DIRS=()
_seen_home=""
for _h in "$(user_home "$REAL_USER")" "$(user_home root)"; do
    [[ -n "$_h" && "$_h" != "$_seen_home" ]] && PROFILE_DIRS+=("$_h/$PROFILE_SUBDIR")
    _seen_home="$_h"
done
unset _h _seen_home

# Helper function to find profile config file and its user
find_profile_conf() {
    local profile="$1"
    local dir
    for dir in "${PROFILE_DIRS[@]}"; do
        if [[ -f "$dir/${profile}.conf" ]]; then
            echo "$dir/${profile}.conf"
            return 0
        fi
    done
    return 1
}

# Emit every profile config path, NUL-terminated so paths containing spaces survive.
# The previous version echoed a space-joined string, which split any such path.
scan_all_profiles() {
    local dir f
    for dir in "${PROFILE_DIRS[@]}"; do
        [[ -d "$dir" ]] || continue
        for f in "$dir"/*.conf; do
            [[ -f "$f" ]] && printf '%s\0' "$f"
        done
    done
}

# Ensure systemd templates and runner scripts are deployed and up-to-date
ensure_templates_installed() {
    echo -e "${BLUE}⚙ Validating and updating systemd templates and runner scripts...${NC}"
    
    # Determine repository path
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local repo_dir
    repo_dir="$(dirname "$(dirname "$script_dir")")"
    
    # Copy sync runner script
    if [[ -f "$repo_dir/services/rclone-sync.sh" ]]; then
        sudo cp "$repo_dir/services/rclone-sync.sh" /usr/local/bin/rclone-sync.sh
        sudo chmod 755 /usr/local/bin/rclone-sync.sh
    else
        echo -e "${RED}Error: Source runner script not found at $repo_dir/services/rclone-sync.sh${NC}" >&2
        return 1
    fi
    
    # Copy mount runner script
    if [[ -f "$repo_dir/services/rclone-mount.sh" ]]; then
        sudo cp "$repo_dir/services/rclone-mount.sh" /usr/local/bin/rclone-mount.sh
        sudo chmod 755 /usr/local/bin/rclone-mount.sh
    else
        echo -e "${RED}Error: Source mount script not found at $repo_dir/services/rclone-mount.sh${NC}" >&2
        return 1
    fi
    
    # Copy timer template
    if [[ -f "$repo_dir/services/rclone-sync@.timer" ]]; then
        sudo cp "$repo_dir/services/rclone-sync@.timer" /etc/systemd/system/rclone-sync@.timer
        sudo chmod 644 /etc/systemd/system/rclone-sync@.timer
    fi
    
    # Copy sync service template and replace placeholder
    if [[ -f "$repo_dir/services/rclone-sync@.service" ]]; then
        sed "s/@USER@/$REAL_USER/g" "$repo_dir/services/rclone-sync@.service" | sudo tee /etc/systemd/system/rclone-sync@.service > /dev/null
        sudo chmod 644 /etc/systemd/system/rclone-sync@.service
    fi
    
    # Copy mount service template and replace placeholder
    if [[ -f "$repo_dir/services/rclone-mount@.service" ]]; then
        sed "s/@USER@/$REAL_USER/g" "$repo_dir/services/rclone-mount@.service" | sudo tee /etc/systemd/system/rclone-mount@.service > /dev/null
        sudo chmod 644 /etc/systemd/system/rclone-mount@.service
    fi
    
    sudo systemctl daemon-reload
    echo -e "  ${GREEN}✓ Templates and runner scripts are up to date.${NC}"
}

# Pin a single instance to the user that owns its profile.
#
# The @USER@ placeholder in the shared template is substituted once, at install
# time, with whoever ran the installer. Every profile would otherwise run as that
# user regardless of its own USER= field -- reading the wrong ~/.config/rclone and
# writing files with the wrong ownership. A per-instance drop-in overrides it.
write_service_user_override() {
    local unit="$1"      # e.g. rclone-sync@gdrive.service
    local run_user="$2"

    if [[ -z "$run_user" ]]; then
        return 0
    fi
    if ! id "$run_user" &>/dev/null; then
        echo -e "  ${RED}✗ Cannot pin $unit: user '$run_user' does not exist.${NC}" >&2
        return 1
    fi

    local override_dir="/etc/systemd/system/${unit}.d"
    sudo mkdir -p "$override_dir"
    sudo tee "$override_dir/user.conf" > /dev/null <<EOF
[Service]
User=$run_user
EOF
    echo -e "  ${GREEN}✓ Pinned $unit to user '$run_user'.${NC}"
}

case "$action" in
    --list)
        # Find all profile configuration files
        files=()
        while IFS= read -r -d '' _f; do files+=("$_f"); done < <(scan_all_profiles)
        
        if [[ ${#files[@]} -eq 0 || -z "${files[0]:-}" ]]; then
            echo -e "${YELLOW}No cloud sync/mount profiles configured yet in ~/.config/rclone-sync-profiles/ or /root/.config/rclone-sync-profiles/${NC}"
            echo -e "Use the 'Create New Sync Profile' option to create one."
            exit 0
        fi

        echo -e "${CYAN}=========================================================================================================${NC}"
        echo -e "${CYAN}                                Active Cloud Sync & Mount Profiles                                       ${NC}"
        echo -e "${CYAN}=========================================================================================================${NC}"
        printf "%-18s %-14s %-10s %-8s %-12s %-10s %-10s %-12s\n" "Profile Name" "Type" "User" "Timer" "Enabled" "Status" "Schedule" "Backend"
        echo -e "${BLUE}---------------------------------------------------------------------------------------------------------${NC}"

        declare -A user_remotes_cached

        for file in "${files[@]}"; do
            [[ -f "$file" ]] || continue
            profile=$(basename "$file" .conf)
            
            # Defaults
            REMOTE=""
            REMOTE_PATH=""
            LOCAL_PATH=""
            SYNC_TYPE="one"
            USER=""
            SCHEDULE=""
            DIRECTION="local-to-remote"
            RCLONE_CONFIG=""
            
            # Load config variables
            # shellcheck disable=SC1090
            source "$file"
            
            # Use directory owner if USER not specified
            if [[ -z "$USER" ]]; then
                USER=$(stat -c '%U' "$file")
            fi
            
            if [[ "$SYNC_TYPE" == "mount" ]]; then
                # Mounts use a continuous service, not a timer
                timer_state="N/A"
                timer_enabled="N/A"
                service_state=$(systemctl is-active "rclone-mount@${profile}.service" 2>/dev/null || echo "inactive")
                service_enabled=$(systemctl is-enabled "rclone-mount@${profile}.service" 2>/dev/null || echo "disabled")
                
                t_color="$CYAN"
                t_state_text="N/A"
                t_enabled_text="(Mount)"
                
                if [[ "$service_state" == "active" ]]; then
                    s_color="$GREEN"
                    s_text="running"
                else
                    s_color="$YELLOW"
                    s_text="stopped"
                fi
                sched_text="Continuous"
                timer_enabled="$service_enabled"
            else
                timer_state=$(systemctl is-active "rclone-sync@${profile}.timer" 2>/dev/null || echo "inactive")
                service_state=$(systemctl is-active "rclone-sync@${profile}.service" 2>/dev/null || echo "inactive")
                timer_enabled=$(systemctl is-enabled "rclone-sync@${profile}.timer" 2>/dev/null || echo "disabled")
                
                # Format timer status colors
                if [[ "$timer_state" == "active" ]]; then
                    t_color="$GREEN"
                else
                    t_color="$RED"
                fi
                t_state_text="$timer_state"
                t_enabled_text="($timer_enabled)"
                
                # Format service status colors
                if [[ "$service_state" == "active" ]]; then
                    s_color="$GREEN"
                    s_text="syncing"
                else
                    s_color="$YELLOW"
                    s_text="idle"
                fi
                sched_text="$SCHEDULE"
            fi
            
            # Fetch remotes for this user (cached)
            if [[ -z "${user_remotes_cached[$USER]:-}" ]]; then
                remotes_list=$(sudo -u "$USER" -H rclone listremotes 2>/dev/null || true)
                user_remotes_cached[$USER]=$(echo "$remotes_list" | tr '\n' ' ')
            fi
            
            # Check backend availability
            backend_available=false
            for r in ${user_remotes_cached[$USER]}; do
                if [[ "$r" == "$REMOTE:" || "$r" == "$REMOTE" ]]; then
                    backend_available=true
                    break
                fi
            done
            
            if [[ "$backend_available" = true ]]; then
                b_color="$GREEN"
                b_text="Available"
            else
                b_color="$RED"
                b_text="Unavailable"
            fi
            
            # Check local path availability
            if [[ -d "$LOCAL_PATH" ]]; then
                local_status="${GREEN}Available${NC}"
            else
                local_status="${RED}Missing${NC}"
            fi
            
            # Check remote path availability
            remote_status="${RED}Inaccessible${NC}"
            if [[ "$backend_available" = true ]]; then
                if [[ -z "${RCLONE_CONFIG}" ]]; then
                    USER_HOME=$(eval echo "~$USER")
                    RCLONE_CONFIG="$USER_HOME/.config/rclone/rclone.conf"
                fi
                if sudo -u "$USER" -H rclone lsf --max-depth 1 "$REMOTE:$REMOTE_PATH" --config "$RCLONE_CONFIG" &>/dev/null; then
                    remote_status="${GREEN}Available${NC}"
                fi
            else
                remote_status="${RED}Backend Unavailable${NC}"
            fi
            
            # Print row with color escape sequences in the format string to prevent alignment breakages
            printf "%-18s %-14s %-10s ${t_color}%-8s${NC} %-12s ${s_color}%-10s${NC} %-10s ${b_color}%-12s${NC}\n" \
                "$profile" "$SYNC_TYPE" "$USER" "$t_state_text" "$t_enabled_text" "$s_text" "$sched_text" "$b_text"
            echo -e "   ${BLUE}↳${NC} Local:  ${YELLOW}$LOCAL_PATH${NC} ($local_status)"
            if [[ -n "$REMOTE_PATH" ]]; then
                echo -e "   ${BLUE}↳${NC} Remote: ${YELLOW}$REMOTE:$REMOTE_PATH${NC} ($remote_status)"
            else
                echo -e "   ${BLUE}↳${NC} Remote: ${YELLOW}$REMOTE:${NC} ($remote_status)"
            fi
            if [[ "$SYNC_TYPE" == "one" ]]; then
                echo -e "   ${BLUE}↳${NC} Dir:    ${YELLOW}$DIRECTION${NC}"
            fi
            echo ""
        done
        ;;

    --create)
        # Ensure systemd templates are present and up to date
        ensure_templates_installed

        echo -e "${CYAN}Create New Cloud Sync/Mount Profile${NC}"
        echo ""
        
        # 1. Profile Name
        read -p "Enter profile name (e.g. gdrive-backup): " PROFILE
        PROFILE=$(echo "$PROFILE" | tr -d '[:space:]')
        if [[ -z "$PROFILE" ]]; then
            echo -e "${RED}Error: Profile name cannot be empty.${NC}"
            exit 1
        fi
        
        # Check if profile already exists
        if find_profile_conf "$PROFILE" &>/dev/null; then
            echo -e "${RED}Error: Profile '$PROFILE' already exists.${NC}"
            exit 1
        fi

        # 2. Select User
        echo -e "Select user to run sync under (default: $REAL_USER):"
        read -p "Username: " USER
        USER="${USER:-$REAL_USER}"
        if ! id "$USER" &>/dev/null; then
            echo -e "${RED}Error: User '$USER' does not exist on this system.${NC}"
            exit 1
        fi

        USER_HOME=$(eval echo "~$USER")
        profiles_dir="$USER_HOME/.config/rclone-sync-profiles"
        conf_file="$profiles_dir/${PROFILE}.conf"

        # 3. Detect rclone remotes
        echo -e "${BLUE}Scanning for configured rclone remotes for user '$USER'...${NC}"
        remotes=()
        while read -r line; do
            if [[ -n "$line" ]]; then
                remotes+=("${line%:}")
            fi
        done < <(sudo -u "$USER" -H rclone listremotes 2>/dev/null || true)

        REMOTE=""
        if [[ ${#remotes[@]} -eq 0 ]]; then
            echo -e "${YELLOW}No configured rclone remotes found for '$USER'. Make sure rclone is configured.${NC}"
            read -p "Enter remote name manually (e.g. gdrive): " REMOTE
        else
            echo "Select an rclone remote:"
            for i in "${!remotes[@]}"; do
                echo -e "  $((i+1))) ${remotes[$i]}"
            done
            echo -e "  0) Enter manually"
            read -p "Select option (0-${#remotes[@]}): " remote_choice
            if [[ "$remote_choice" -gt 0 && "$remote_choice" -le "${#remotes[@]}" ]]; then
                REMOTE="${remotes[$((remote_choice-1))]}"
            else
                read -p "Enter remote name manually: " REMOTE
            fi
        fi
        
        if [[ -z "$REMOTE" ]]; then
            echo -e "${RED}Error: Remote cannot be empty.${NC}"
            exit 1
        fi

        # 4. Remote Path
        read -p "Enter remote path (folder inside remote, e.g. backups, leave blank for root): " REMOTE_PATH
        
        # 5. Profile Type
        echo "Select Profile Type:"
        echo "  1) One-way Sync (copies changes in one direction)"
        echo "  2) Bidirectional Sync (bisync - keeps both paths in sync)"
        echo "  3) Mount Directory (Continuous Sync using FUSE)"
        read -p "Select option (1-3): " type_choice
        
        SYNC_TYPE="one"
        DIRECTION="local-to-remote"
        SCHEDULE=""
        if [[ "$type_choice" == "3" ]]; then
            SYNC_TYPE="mount"
        elif [[ "$type_choice" == "2" ]]; then
            SYNC_TYPE="bidirectional"
        else
            echo "Select Direction:"
            echo "  1) Local-to-Remote (Backup local files to cloud - Recommended)"
            echo "  2) Remote-to-Local (Download cloud files to local)"
            read -p "Select option (1-2): " dir_choice
            if [[ "$dir_choice" == "2" ]]; then
                DIRECTION="remote-to-local"
            fi
        fi

        # 6. Local Path
        local_path_ok=false
        RCLONE_OPTS=""
        while [[ "$local_path_ok" = false ]]; do
            read -p "Enter local directory path (absolute path): " LOCAL_PATH
            if [[ "$LOCAL_PATH" == "~"* ]]; then
                LOCAL_PATH="${LOCAL_PATH/\~/$USER_HOME}"
            fi
            
            if [[ ! -d "$LOCAL_PATH" ]]; then
                echo -e "${YELLOW}Local directory '$LOCAL_PATH' does not exist. Create it? (y/n)${NC}"
                read -p "Choice: " create_dir
                if [[ "$create_dir" =~ ^[Yy]$ ]]; then
                    sudo -u "$USER" -H mkdir -p "$LOCAL_PATH"
                    echo -e "${GREEN}Created directory $LOCAL_PATH${NC}"
                    local_path_ok=true
                else
                    echo "Please specify a different directory."
                fi
            else
                # Directory exists, check if empty
                if [[ -n "$(ls -A "$LOCAL_PATH" 2>/dev/null)" ]]; then
                    echo -e "\n${YELLOW}⚠️ Warning: Local directory '$LOCAL_PATH' is not empty.${NC}"
                    echo "Please choose how to proceed:"
                    echo "  1) Proceed anyway"
                    echo "  2) Choose a different folder"
                    echo "  3) Cancel"
                    read -p "Select option (1-3): " non_empty_choice
                    
                    if [[ "$non_empty_choice" == "1" ]]; then
                        local_path_ok=true
                        # If mount, add --allow-non-empty flag
                        if [[ "$SYNC_TYPE" == "mount" ]]; then
                            RCLONE_OPTS="--allow-non-empty"
                            echo -e "${GREEN}✓ Will use --allow-non-empty flag for this mount.${NC}"
                        else
                            echo -e "${GREEN}✓ Proceeding with non-empty directory.${NC}"
                        fi
                    elif [[ "$non_empty_choice" == "2" ]]; then
                        echo ""
                        # Loop again to get a new path
                    else
                        echo "Cancelled."
                        exit 0
                    fi
                else
                    # Directory is empty
                    local_path_ok=true
                fi
            fi
        done

        # 7. Schedule (only for sync, mounts are continuous)
        if [[ "$SYNC_TYPE" != "mount" ]]; then
            echo "Select Schedule (Systemd Timer schedule):"
            echo "  1) Hourly"
            echo "  2) Daily"
            echo "  3) Weekly"
            echo "  4) Custom Calendar expression"
            read -p "Select option (1-4): " sched_choice
            case "$sched_choice" in
                1) SCHEDULE="hourly" ;;
                2) SCHEDULE="daily" ;;
                3) SCHEDULE="weekly" ;;
                *)
                    read -p "Enter custom calendar expression (e.g. '*-*-* 02:00:00'): " SCHEDULE
                    ;;
            esac
            
            if [[ -z "$SCHEDULE" ]]; then
                SCHEDULE="daily"
            fi
        fi

        # Ensure directory exists in user home
        if [[ ! -d "$profiles_dir" ]]; then
            sudo -u "$USER" -H mkdir -p "$profiles_dir"
        fi

        # Write Config File
        echo "Creating configuration file..."
        sudo -u "$USER" -H tee "$conf_file" > /dev/null <<EOF
REMOTE="$REMOTE"
REMOTE_PATH="$REMOTE_PATH"
LOCAL_PATH="$LOCAL_PATH"
SYNC_TYPE="$SYNC_TYPE"
USER="$USER"
DIRECTION="$DIRECTION"
SCHEDULE="$SCHEDULE"
RCLONE_OPTS="$RCLONE_OPTS"
EOF
        sudo -u "$USER" -H chmod 600 "$conf_file"
        echo -e "  ${GREEN}✓ Created config: $conf_file (tracked by dotfiles)${NC}"

        if [[ "$SYNC_TYPE" != "mount" ]]; then
            # Write Systemd Override
            override_dir="/etc/systemd/system/rclone-sync@${PROFILE}.timer.d"
            sudo mkdir -p "$override_dir"
            sudo tee "$override_dir/override.conf" > /dev/null <<EOF
[Timer]
OnCalendar=
OnCalendar=$SCHEDULE
EOF
            echo -e "  ${GREEN}✓ Configured systemd schedule override.${NC}"

            write_service_user_override "rclone-sync@${PROFILE}.service" "$USER"

            # Reload & Enable
            echo "Enabling timer in systemd..."
            sudo systemctl daemon-reload
            sudo systemctl enable --now "rclone-sync@${PROFILE}.timer"
            echo -e "  ${GREEN}✓ Enabled rclone-sync@${PROFILE}.timer${NC}"

            # Initial Resync if bidirectional
            if [[ "$SYNC_TYPE" == "bidirectional" ]]; then
                # Create flag file
                sudo -u "$USER" -H touch "$profiles_dir/${PROFILE}.resync"
                echo ""
                echo -e "${YELLOW}Bidirectional sync (bisync) requires an initial resync to build file metadata caches.${NC}"
                read -p "Do you want to run the initial resync in the background now? (y/n): " init_resync
                if [[ "$init_resync" =~ ^[Yy]$ ]]; then
                    echo "Starting initial resync in the background..."
                    sudo systemctl start "rclone-sync@${PROFILE}.service"
                    echo -e "  ${GREEN}✓ Initial resync triggered via systemd in the background.${NC}"
                    echo -e "  You can monitor progress in real-time by selecting 'View Sync Logs' (option 64)."
                else
                    echo -e "${YELLOW}Note: The resync will run automatically in the background on the first scheduled timer trigger.${NC}"
                fi
            fi
        else
            # Reload & Enable Mount Service
            echo "Enabling mount service in systemd..."
            write_service_user_override "rclone-mount@${PROFILE}.service" "$USER"
            sudo systemctl daemon-reload
            sudo systemctl enable --now "rclone-mount@${PROFILE}.service"
            echo -e "  ${GREEN}✓ Enabled and started rclone-mount@${PROFILE}.service (Mounts will start on boot)${NC}"
        fi
        ;;

    --manage)
        # Ensure systemd templates are present and up to date
        ensure_templates_installed

        files=()
        while IFS= read -r -d '' _f; do files+=("$_f"); done < <(scan_all_profiles)
        if [[ ${#files[@]} -eq 0 || -z "${files[0]:-}" ]]; then
            echo -e "${YELLOW}No cloud sync/mount profiles configured yet.${NC}"
            exit 0
        fi

        echo "Select a profile to manage:"
        profiles=()
        for file in "${files[@]}"; do
            [[ -f "$file" ]] || continue
            p=$(basename "$file" .conf)
            profiles+=("$p")
            echo -e "  $((${#profiles[@]})) $p"
        done
        echo -e "  0) Cancel"
        read -p "Select option (0-${#profiles[@]}): " p_choice
        
        if [[ ! "$p_choice" =~ ^[0-9]+$ ]] || [[ "$p_choice" -le 0 ]] || [[ "$p_choice" -gt "${#profiles[@]}" ]]; then
            echo "Cancelled."
            exit 0
        fi

        PROFILE="${profiles[$((p_choice-1))]}"
        echo ""
        echo -e "Managing Profile: ${CYAN}$PROFILE${NC}"
        
        # Load profile config
        conf_file=$(find_profile_conf "$PROFILE")
        # shellcheck disable=SC1090
        source "$conf_file"
        
        # Use directory owner if USER not specified
        if [[ -z "$USER" ]]; then
            USER=$(stat -c '%U' "$conf_file")
        fi

        # Check backend availability
        user_remotes=$(sudo -u "$USER" -H rclone listremotes 2>/dev/null || true)
        backend_available=false
        for r in $user_remotes; do
            if [[ "$r" == "$REMOTE:" || "$r" == "$REMOTE" ]]; then
                backend_available=true
                break
            fi
        done

        # Check local path availability
        local_path_available=false
        if [[ -d "$LOCAL_PATH" ]]; then
            local_path_available=true
        fi

        # Check remote path availability
        remote_path_available=false
        if [[ -z "${RCLONE_CONFIG:-}" ]]; then
            USER_HOME=$(eval echo "~$USER")
            RCLONE_CONFIG="$USER_HOME/.config/rclone/rclone.conf"
        fi
        if [[ "$backend_available" = true ]] && sudo -u "$USER" -H rclone lsf --max-depth 1 "$REMOTE:$REMOTE_PATH" --config "$RCLONE_CONFIG" &>/dev/null; then
            remote_path_available=true
        fi

        # Display status report
        if [[ "$backend_available" = true ]]; then
            echo -e "Backend Connection: ${GREEN}Available (${REMOTE})${NC}"
        else
            echo -e "Backend Connection: ${RED}⚠️ Unavailable (${REMOTE} not configured)${NC}"
        fi

        if [[ "$local_path_available" = true ]]; then
            echo -e "Local Path Check:   ${GREEN}Available ($LOCAL_PATH)${NC}"
        else
            echo -e "Local Path Check:   ${RED}⚠️ Missing ($LOCAL_PATH)${NC}"
        fi

        if [[ "$remote_path_available" = true ]]; then
            echo -e "Remote Path Check:  ${GREEN}Available ($REMOTE:$REMOTE_PATH)${NC}"
        else
            echo -e "Remote Path Check:  ${RED}⚠️ Inaccessible ($REMOTE:$REMOTE_PATH)${NC}"
        fi

        echo ""
        if [[ "$SYNC_TYPE" == "mount" ]]; then
            echo "1) Start Mount Service Now"
            echo "2) Enable & Start Mount at Boot (Persistent)"
            echo "3) Disable & Stop Mount"
            echo "4) Force Bidirectional Resync (N/A for Mounts)"
            echo "5) Delete Mount Profile"
        else
            echo "1) Start Sync Service Now (One-time Run)"
            echo "2) Enable & Start Scheduled Timer"
            echo "3) Disable & Stop Scheduled Timer"
            echo "4) Force Bidirectional Resync (Run bisync with --resync)"
            echo "5) Delete Sync Profile"
        fi
        read -p "Select action (1-5): " m_choice

        case "$m_choice" in
            1)
                # Validation checks
                if [[ "$backend_available" = false || "$local_path_available" = false || "$remote_path_available" = false ]]; then
                    echo -e "${RED}Error: Cannot start service. All components (Backend, Local Path, Remote Path) must be Available.${NC}"
                    exit 1
                fi
                if [[ "$SYNC_TYPE" == "mount" ]]; then
                    echo "Starting rclone-mount@${PROFILE}.service..."
                    sudo systemctl start "rclone-mount@${PROFILE}.service"
                    echo -e "${GREEN}✓ Mount service started. Check logs (option 64) for progress.${NC}"
                else
                    echo "Starting rclone-sync@${PROFILE}.service..."
                    sudo systemctl start "rclone-sync@${PROFILE}.service"
                    echo -e "${GREEN}✓ Service start triggered. You can monitor it using the logs option.${NC}"
                fi
                ;;
            2)
                # Validation checks
                if [[ "$backend_available" = false || "$local_path_available" = false || "$remote_path_available" = false ]]; then
                    echo -e "${RED}Error: Cannot enable at boot. All components (Backend, Local Path, Remote Path) must be Available.${NC}"
                    exit 1
                fi
                if [[ "$SYNC_TYPE" == "mount" ]]; then
                    echo "Enabling and starting rclone-mount@${PROFILE}.service..."
                    sudo systemctl enable --now "rclone-mount@${PROFILE}.service"
                    echo -e "${GREEN}✓ Mount enabled and started at boot.${NC}"
                else
                    echo "Enabling and starting rclone-sync@${PROFILE}.timer..."
                    sudo systemctl enable --now "rclone-sync@${PROFILE}.timer"
                    echo -e "${GREEN}✓ Timer enabled and started.${NC}"
                fi
                ;;
            3)
                if [[ "$SYNC_TYPE" == "mount" ]]; then
                    echo "Stopping and disabling rclone-mount@${PROFILE}.service..."
                    sudo systemctl disable --now "rclone-mount@${PROFILE}.service"
                    echo -e "${GREEN}✓ Mount disabled and stopped.${NC}"
                else
                    echo "Stopping and disabling rclone-sync@${PROFILE}.timer..."
                    sudo systemctl disable --now "rclone-sync@${PROFILE}.timer"
                    echo -e "${GREEN}✓ Timer disabled and stopped.${NC}"
                fi
                ;;
            4)
                if [[ "$SYNC_TYPE" == "mount" ]]; then
                    echo -e "${RED}Error: Bidirectional resync is only valid for sync profiles, not mounts.${NC}"
                    exit 1
                fi
                if [[ "$SYNC_TYPE" != "bidirectional" ]]; then
                    echo -e "${RED}Error: Resync is only valid for bidirectional profiles.${NC}"
                    exit 1
                fi
                if [[ "$backend_available" = false || "$local_path_available" = false || "$remote_path_available" = false ]]; then
                    echo -e "${RED}Error: Cannot perform resync. All components (Backend, Local Path, Remote Path) must be Available.${NC}"
                    exit 1
                fi
                
                USER_HOME=$(eval echo "~$USER")
                profiles_dir="$USER_HOME/.config/rclone-sync-profiles"
                
                echo "Triggering bidirectional resync in the background..."
                sudo -u "$USER" -H touch "$profiles_dir/${PROFILE}.resync"
                sudo systemctl start "rclone-sync@${PROFILE}.service"
                echo -e "${GREEN}✓ Bidirectional resync triggered in the background via systemd.${NC}"
                echo -e "You can monitor progress in real-time by selecting 'View Sync Logs' (option 64)."
                ;;
            5)
                read -p "Are you sure you want to delete profile $PROFILE? This will remove all its scheduler timers and configuration. (y/n): " confirm_delete
                if [[ "$confirm_delete" =~ ^[Yy]$ ]]; then
                    echo "Stopping and disabling systemd units..."
                    if [[ "$SYNC_TYPE" == "mount" ]]; then
                        sudo systemctl disable --now "rclone-mount@${PROFILE}.service" 2>/dev/null || true
                        sudo rm -rf "/etc/systemd/system/rclone-mount@${PROFILE}.service.d"
                    else
                        sudo systemctl disable --now "rclone-sync@${PROFILE}.timer" 2>/dev/null || true
                        sudo systemctl stop "rclone-sync@${PROFILE}.service" 2>/dev/null || true
                        sudo rm -rf "/etc/systemd/system/rclone-sync@${PROFILE}.timer.d"
                        sudo rm -rf "/etc/systemd/system/rclone-sync@${PROFILE}.service.d"
                    fi
                    
                    echo "Deleting files..."
                    sudo rm -f "$conf_file"
                    
                    sudo systemctl daemon-reload
                    echo -e "${GREEN}✓ Profile $PROFILE deleted successfully from $conf_file.${NC}"
                else
                    echo "Delete cancelled."
                fi
                ;;
            *)
                echo "Invalid selection."
                ;;
        esac
        ;;

    --logs)
        files=()
        while IFS= read -r -d '' _f; do files+=("$_f"); done < <(scan_all_profiles)
        if [[ ${#files[@]} -eq 0 || -z "${files[0]:-}" ]]; then
            echo -e "${YELLOW}No cloud sync/mount profiles configured yet.${NC}"
            exit 0
        fi

        echo "Select a profile to view logs:"
        profiles=()
        for file in "${files[@]}"; do
            [[ -f "$file" ]] || continue
            p=$(basename "$file" .conf)
            profiles+=("$p")
            echo -e "  $((${#profiles[@]})) $p"
        done
        echo -e "  0) Cancel"
        read -p "Select option (0-${#profiles[@]}): " p_choice
        
        if [[ ! "$p_choice" =~ ^[0-9]+$ ]] || [[ "$p_choice" -le 0 ]] || [[ "$p_choice" -gt "${#profiles[@]}" ]]; then
            echo "Cancelled."
            exit 0
        fi

        PROFILE="${profiles[$((p_choice-1))]}"
        
        # Load config
        conf_file=$(find_profile_conf "$PROFILE")
        # shellcheck disable=SC1090
        source "$conf_file"

        echo ""
        if [[ "$SYNC_TYPE" == "mount" ]]; then
            echo -e "Viewing logs for ${CYAN}rclone-mount@${PROFILE}.service${NC}:"
            echo -e "${BLUE}------------------------------------------------------------${NC}"
            journalctl -u "rclone-mount@${PROFILE}.service" -n 50 --no-pager
            echo -e "${BLUE}------------------------------------------------------------${NC}"
        else
            echo -e "Viewing logs for ${CYAN}rclone-sync@${PROFILE}.service${NC}:"
            echo -e "${BLUE}------------------------------------------------------------${NC}"
            journalctl -u "rclone-sync@${PROFILE}.service" -n 50 --no-pager
            echo -e "${BLUE}------------------------------------------------------------${NC}"
        fi
        ;;

    *)
        echo -e "${RED}Unknown action: $action${NC}"
        exit 1
        ;;
esac
