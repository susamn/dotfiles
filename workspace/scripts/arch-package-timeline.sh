#!/bin/bash

set -euo pipefail

# Arch Linux Package Timeline Logger
# Logs all package installations and upgrades to a timeline file
# Called by pacman hook after package operations

# --- Configuration ---
# Determine the actual user's home (not root's home when run via sudo)
if [[ -n "${SUDO_USER:-}" ]]; then
    ACTUAL_USER="${SUDO_USER}"
else
    ACTUAL_USER="${USER}"
fi

TIMELINE_DIR="/home/${ACTUAL_USER}/.local/state/arch-package-state"
TIMELINE_FILE="${TIMELINE_DIR}/timeline.log"

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
    --help|-h)
      echo "Arch Linux Package Timeline Logger"
      echo ""
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  (no args)  Log package operations from stdin (called by hook)"
      echo "  --view     View timeline in formatted output"
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
    # Create timeline directory if it doesn't exist
    mkdir -p "$TIMELINE_DIR"

    # Make sure the file is writable by the actual user, not root
    touch "$TIMELINE_FILE"
    chown "${ACTUAL_USER}:${ACTUAL_USER}" "$TIMELINE_FILE" 2>/dev/null || true

    # Get timestamp
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Read package names from stdin (passed by NeedsTargets in hook)
    while IFS= read -r package; do
        [[ -z "$package" ]] && continue

        # Get package info from pacman
        local pkg_info=$(pacman -Q "$package" 2>/dev/null || echo "")

        if [[ -n "$pkg_info" ]]; then
            # Package is installed, get version
            local version=$(echo "$pkg_info" | awk '{print $2}')

            # Check what operation was performed by looking at recent pacman log
            local operation="UNKNOWN"
            local last_log=$(grep "\[ALPM\].*${package}" /var/log/pacman.log 2>/dev/null | tail -1 || echo "")

            # Check in order: reinstalled BEFORE installed (since reinstalled contains "installed")
            if echo "$last_log" | grep -q "reinstalled ${package}"; then
                operation="REINSTALLED"
            elif echo "$last_log" | grep -q "installed ${package}"; then
                operation="INSTALLED"
            elif echo "$last_log" | grep -q "upgraded ${package}"; then
                operation="UPGRADED"
                # Extract old and new versions for upgrades
                local old_ver=$(echo "$last_log" | sed 's/.*(\(.*\) -> .*/\1/')
                local new_ver=$(echo "$last_log" | sed 's/.* -> \(.*\))/\1/')
                echo "${timestamp}|${operation}|${package}|${new_ver}|${old_ver}" >> "$TIMELINE_FILE"
                continue
            fi

            echo "${timestamp}|${operation}|${package}|${version}|N/A" >> "$TIMELINE_FILE"
        else
            # Package was removed
            echo "${timestamp}|REMOVED|${package}|N/A|N/A" >> "$TIMELINE_FILE"
        fi
    done

    # Cleanup: keep only last 10000 lines to prevent file from growing too large
    if [[ -f "$TIMELINE_FILE" ]]; then
        local line_count=$(wc -l < "$TIMELINE_FILE")
        if [[ $line_count -gt 10000 ]]; then
            tail -10000 "$TIMELINE_FILE" > "${TIMELINE_FILE}.tmp"
            mv "${TIMELINE_FILE}.tmp" "$TIMELINE_FILE"
            chown "${ACTUAL_USER}:${ACTUAL_USER}" "$TIMELINE_FILE" 2>/dev/null || true
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
        echo -e "${MAGENTA}║                   Arch Linux Package Installation Timeline                  ║${NC}"
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

            # Format operation with icons and colors (aligned for readability)
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

# --- Main Execution ---
case "$ACTION" in
    log)
        log_package_operation
        ;;
    view)
        view_timeline
        ;;
esac
