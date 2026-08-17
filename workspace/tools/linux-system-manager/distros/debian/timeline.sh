#!/bin/bash
set -euo pipefail

# Debian / Ubuntu Package Timeline Logger
# Logs all package installations and upgrades to a timeline file
# Called by APT DPkg::Post-Invoke hook after package operations

# --- Configuration ---
# Determine the actual user's home (not root's home when run via sudo).
# All fallbacks are guarded: APT hooks run with a minimal environment where USER
# is frequently unset, and a bare ${USER} aborts under `set -u`.
if [[ -n "${SUDO_USER:-}" ]]; then
    ACTUAL_USER="${SUDO_USER}"
elif [[ -n "${USER:-}" ]]; then
    ACTUAL_USER="${USER}"
elif [[ -n "${LOGNAME:-}" ]]; then
    ACTUAL_USER="${LOGNAME}"
else
    ACTUAL_USER="$(id -un 2>/dev/null || echo root)"
fi

# Resolve the home directory from passwd rather than assuming /home/<user>:
# root lives in /root, and system/LDAP accounts are routinely elsewhere.
ACTUAL_HOME="$(getent passwd "$ACTUAL_USER" 2>/dev/null | cut -d: -f6)"
if [[ -z "$ACTUAL_HOME" || ! -d "$ACTUAL_HOME" ]]; then
    ACTUAL_HOME="${HOME:-/root}"
fi

TIMELINE_DIR="${ACTUAL_HOME}/.local/state/debian-package-state"
TIMELINE_FILE="${TIMELINE_DIR}/timeline.log"
STATE_FILE="${TIMELINE_DIR}/last_processed_line"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# --- Parse arguments ---
ACTION="log"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --view)
      ACTION="view"
      shift
      ;;
    --recent)
      ACTION="recent"
      shift
      ;;
    --search)
      ACTION="search"
      shift
      ;;
    --help|-h)
      echo "Debian / Ubuntu Package Timeline Logger"
      echo ""
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  (no args)  Log package operations from /var/log/dpkg.log (called by hook)"
      echo "  --view     View timeline in formatted output"
      echo "  --recent   View last 50 package operations"
      echo "  --search   Search package operations history"
      echo "  --help, -h Show this help message"
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# --- Logging Function ---
log_package_operation() {
    mkdir -p "$TIMELINE_DIR"
    touch "$TIMELINE_FILE"
    touch "$STATE_FILE"

    # Make sure the files are owned by the actual user
    chown "${ACTUAL_USER}:${ACTUAL_USER}" "$TIMELINE_FILE" "$STATE_FILE" 2>/dev/null || true

    local last_line=0
    if [[ -f "$STATE_FILE" && -s "$STATE_FILE" ]]; then
        last_line=$(cat "$STATE_FILE")
    fi

    # Handle missing /var/log/dpkg.log gracefully
    if [[ ! -f /var/log/dpkg.log ]]; then
        return 0
    fi

    local current_lines=$(wc -l < /var/log/dpkg.log || echo "0")

    # If log rotated or was truncated, reset last_line
    if [[ $current_lines -lt $last_line ]]; then
        last_line=0
    fi

    local boot_changed=false

    if [[ $current_lines -gt $last_line ]]; then
        # Process substitution, not a pipe: `tail | while` runs the loop body in a
        # subshell, so boot_changed set below would be discarded and the post-upgrade
        # boot safety check would never fire after a kernel or grub change.
        while read -r line; do
            # Format in dpkg.log: YYYY-MM-DD HH:MM:SS ACTION PKGNAME:ARCH OLDVER NEWVER
            # Examples:
            # 2026-07-10 17:07:05 install python3-software-properties:all <none> 0.99.22.9
            # 2026-07-10 17:07:06 upgrade python3-software-properties:all 0.99.22.8 0.99.22.9
            # 2026-07-10 17:07:07 remove python3-software-properties:all 0.99.22.9 <none>
            
            # Extract fields
            local date_val="" time_val="" action="" pkg="" old_ver="" new_ver=""
            read -r date_val time_val action pkg old_ver new_ver <<< "$line" || true
            
            # Skip if any key fields are empty or invalid date/time
            [[ -z "$date_val" || -z "$time_val" || -z "$action" || -z "$pkg" ]] && continue
            [[ ! "$date_val" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && continue
            
            # Filter actions we care about
            case "$action" in
                install|upgrade|remove|purge)
                    # Strip architecture suffix from package name (e.g. pkgname:amd64 -> pkgname)
                    local pkg_clean="${pkg%%:*}"
                    local log_timestamp="${date_val} ${time_val}"
                    local operation=""
                    local version=""
                    local old_version=""
                    
                    # Check if boot-critical
                    if [[ "$pkg_clean" =~ ^linux-image-[0-9] || "$pkg_clean" =~ ^grub || "$pkg_clean" == "systemd" || "$pkg_clean" == "initramfs-tools" ]]; then
                        boot_changed=true
                    fi
                    
                    case "$action" in
                        install)
                            operation="INSTALLED"
                            version="$new_ver"
                            old_version="N/A"
                            ;;
                        upgrade)
                            operation="UPGRADED"
                            version="$new_ver"
                            old_version="$old_ver"
                            ;;
                        remove|purge)
                            operation="REMOVED"
                            version="N/A"
                            old_version="$old_ver"
                            ;;
                    esac
                    
                    echo "${log_timestamp}|${operation}|${pkg_clean}|${version}|${old_version}" >> "$TIMELINE_FILE"
                    ;;
            esac
        done < <(tail -n +$((last_line + 1)) /var/log/dpkg.log)

        # Save new state
        echo "$current_lines" > "$STATE_FILE"
        chown "${ACTUAL_USER}:${ACTUAL_USER}" "$STATE_FILE" 2>/dev/null || true
    fi

    # Cleanup: keep only last 10000 lines in timeline
    if [[ -f "$TIMELINE_FILE" ]]; then
        local line_count=$(wc -l < "$TIMELINE_FILE")
        if [[ $line_count -gt 10000 ]]; then
            tail -10000 "$TIMELINE_FILE" > "${TIMELINE_FILE}.tmp"
            mv "${TIMELINE_FILE}.tmp" "$TIMELINE_FILE"
            chown "${ACTUAL_USER}:${ACTUAL_USER}" "$TIMELINE_FILE" 2>/dev/null || true
        fi
    fi

    # Check if we need to trigger boot check
    if $boot_changed; then
        echo ""
        echo -e "${YELLOW}⚠ Boot-critical packages were modified. Running boot safety check...${NC}"
        if [[ -x /usr/local/bin/debian-boot-check.sh ]]; then
            /usr/local/bin/debian-boot-check.sh --quick-banner || true
        fi
    fi
}

# --- View Function ---
view_timeline() {
    if [[ ! -f "$TIMELINE_FILE" ]]; then
        echo -e "${YELLOW}⚠${NC}  No timeline data found"
        echo "Timeline will be created after your next package operation"
        exit 0
    fi

    # Generate formatted output and pipe to less
    {
        echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${MAGENTA}║                                                                              ║${NC}"
        echo -e "${MAGENTA}║               Debian / Ubuntu Package Installation Timeline                 ║${NC}"
        echo -e "${MAGENTA}║                                                                              ║${NC}"
        echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        local current_date=""
        local operation_count=0

        # Read timeline file in reverse (newest first)
        while IFS='|' read -r timestamp operation package new_version old_version; do
            date_part=$(echo "$timestamp" | cut -d' ' -f1)
            time_part=$(echo "$timestamp" | cut -d' ' -f2)

            # Print date header if date changed
            if [[ "$date_part" != "$current_date" ]]; then
                if [[ -n "$current_date" ]]; then
                    echo ""
                fi
                current_date="$date_part"

                # Format date nicely
                formatted_date=$(date -d "$date_part" '+%A, %B %d, %Y' 2>/dev/null || echo "$date_part")

                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${YELLOW}📅  ${formatted_date}${NC}"
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo ""
            fi

            # Format operation with icons and colors
            case "$operation" in
                INSTALLED)
                    echo -e "  ${GREEN}⏰ ${time_part}${NC}  ${GREEN}📦 INSTALLED   ${NC}  ${BLUE}${package}${NC}  ${MAGENTA}(${new_version})${NC}"
                    ;;
                REINSTALLED)
                    echo -e "  ${CYAN}⏰ ${time_part}${NC}  ${CYAN}🔄 REINSTALLED ${NC}  ${BLUE}${package}${NC}  ${MAGENTA}(${new_version})${NC}"
                    ;;
                UPGRADED)
                    echo -e "  ${YELLOW}⏰ ${time_part}${NC}  ${YELLOW}⬆️  UPGRADED    ${NC}  ${BLUE}${package}${NC}"
                    echo -e "     ${GREEN}└─${NC} ${old_version} ${CYAN}→${NC} ${MAGENTA}${new_version}${NC}"
                    ;;
                REMOVED)
                    echo -e "  ${RED}⏰ ${time_part}${NC}  ${RED}🗑️  REMOVED     ${NC}  ${BLUE}${package}${NC}"
                    ;;
                *)
                    echo -e "  ${time_part}  ${operation}  ${package}"
                    ;;
            esac

            operation_count=$((operation_count + 1))
        done < <(tac "$TIMELINE_FILE")

        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${GREEN}Total operations logged: ${operation_count}${NC}"
        echo -e "${BLUE}Timeline file: ${TIMELINE_FILE}${NC}"
        echo ""
        echo -e "${YELLOW}💡 Tip: Use arrow keys or j/k to navigate, '/' to search, 'q' to quit${NC}"
        echo ""

    } | less -R
}

view_recent_timeline() {
    if [[ ! -f "$TIMELINE_FILE" ]]; then
        echo -e "${YELLOW}⚠ No timeline data found${NC}"
        return 1
    fi

    echo -e "${CYAN}Last 50 package operations:${NC}"
    echo ""

    tail -50 "$TIMELINE_FILE" | while IFS='|' read -r timestamp operation package version old_ver; do
        case "$operation" in
            INSTALLED) echo -e "  ${GREEN}📦 INSTALLED${NC}   $timestamp  $package ($version)" ;;
            UPGRADED)  echo -e "  ${YELLOW}⬆️  UPGRADED${NC}    $timestamp  $package ($old_ver → $version)" ;;
            REMOVED)   echo -e "  ${RED}🗑️  REMOVED${NC}     $timestamp  $package" ;;
            *)         echo -e "  $operation  $timestamp  $package" ;;
        esac
    done
}

search_timeline() {
    if [[ ! -f "$TIMELINE_FILE" ]]; then
        echo -e "${YELLOW}⚠ No timeline data found${NC}"
        return 1
    fi

    read -p "Enter package name to search: " search_term

    if [[ -z "$search_term" ]]; then
        return 0
    fi

    echo ""
    echo -e "${CYAN}Results for: $search_term${NC}"
    echo ""

    # grep exits 1 on no match, which aborts the script under `set -e`. Capture the
    # result first so "no matches" is a normal outcome rather than a silent failure.
    # -F treats the term literally, so a package name containing regex metacharacters
    # (e.g. "g++") searches for what the user actually typed.
    local matches
    matches="$(grep -iF -- "$search_term" "$TIMELINE_FILE" || true)"

    if [[ -z "$matches" ]]; then
        echo -e "  ${YELLOW}No matches found for '${search_term}'.${NC}"
        return 0
    fi

    local match_count=0
    while IFS='|' read -r timestamp operation package version old_ver; do
        [[ -z "$timestamp" ]] && continue
        echo -e "  $timestamp  ${YELLOW}$operation${NC}  $package  ($version)"
        match_count=$((match_count + 1))
    done <<< "$matches"

    echo ""
    echo -e "${GREEN}${match_count} match(es).${NC}"
}

# --- Main Execution ---
case "$ACTION" in
    log)
        log_package_operation
        ;;
    view)
        view_timeline
        ;;
    recent)
        view_recent_timeline
        ;;
    search)
        search_timeline
        ;;
esac
