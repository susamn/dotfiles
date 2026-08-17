#!/bin/bash
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

# Resolve the repo's services/ directory from this script's own location rather
# than from the caller's working directory. The menu runner happens to set cwd to
# distros/<id>, so a relative ../../services path works from the menu and silently
# finds nothing when the script is run directly.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Units live in $SERVICES_PATH, not inside this tool -- the tool manages them,
# the definitions are configuration. Falls back to the workspace-relative path so
# this still resolves when the environment variable is not exported.
SERVICES_DIR="${SERVICES_PATH:-$(cd "$SCRIPT_DIR/../../../.." && pwd)/services}"
USER_SERVICES_DIR="$SERVICES_DIR/user"

# Personal units live in two systemd managers, not one. Units under services/
# are installed system-wide (/etc/systemd/system) and grouped by the system
# manager's personal-services.target; units under services/user/ are installed
# per-user (~/.config/systemd/user) and grouped by the user manager's target of
# the same name. The two managers share no namespace, so every unit must carry
# its scope with it -- querying or toggling a user unit through the system
# manager reports "not-found" and silently does nothing.
#
# Scope is one of: system | user
lsm_systemctl() {
    local scope="$1"; shift
    if [[ "$scope" == "user" ]]; then
        systemctl --user "$@"
    else
        systemctl "$@"
    fi
}

# Same dispatch, for state-changing calls. System units need root; user units
# must NOT be touched through sudo -- that would talk to root's user manager
# instead of the caller's, enabling the unit for the wrong account.
lsm_systemctl_admin() {
    local scope="$1"; shift
    if [[ "$scope" == "user" ]]; then
        systemctl --user "$@"
    else
        sudo systemctl "$@"
    fi
}

lsm_scope_label() {
    if [[ "$1" == "user" ]]; then
        printf '%buser%b' "$BLUE" "$NC"
    else
        printf '%bsystem%b' "$YELLOW" "$NC"
    fi
}

# Extract unit names from `systemctl list-units` output.
#
# systemctl prefixes lines with a status marker (U+25CF) for units needing
# attention, so a bare `awk '{print $1}'` returns the bullet instead of the unit
# name -- producing phantom entries like "● (inactive/stopped)" in the listing.
# --plain suppresses the marker; this filter additionally skips any leading token
# that is not a unit name, so the parse cannot silently yield garbage.
lsm_unit_names() {
    awk '{
        for (i = 1; i <= NF; i++) {
            if ($i ~ /\.(service|timer|socket|mount|target|path)$/) {
                print $i
                break
            }
        }
    }'
}

# A oneshot service driven by a timer is represented by that timer: it sits
# inactive between runs by design, so listing it alongside its timer reports a
# healthy sync as "stopped". Returns 0 when the unit is triggered by a timer
# that is itself in the listing.
lsm_is_timer_triggered() {
    local scope="$1" unit="$2"
    [[ "$unit" == *.service ]] || return 1
    local trig
    trig=$(lsm_systemctl "$scope" show "$unit" -p TriggeredBy --value 2>/dev/null)
    [[ -n "$trig" ]]
}

# Hidden units are not discarded, they are cross-referenced: the timer's row gets
# a marker and the unit it activates is detailed in a section below. Without this
# a timer-driven sync had no representation at all beyond its timer, and "where is
# the service?" is a fair question to ask of a status view.
LSM_DEFERRED=()
LSM_MARKER_IDX=0

# A..Z, then A2..Z2 and so on. Reusing a marker in a long listing would point two
# timers at one detail line, which is worse than an ugly marker.
#
# Sets LSM_MARKER rather than echoing it: read through $( ), the counter would be
# incremented inside a subshell and every marker would come back as (A).
LSM_MARKER=""
lsm_next_marker() {
    local i="$LSM_MARKER_IDX" letter round
    letter=$(printf "\\$(printf '%03o' $(( 65 + i % 26 )))")
    round=$(( i / 26 ))
    LSM_MARKER_IDX=$(( i + 1 ))
    if (( round == 0 )); then
        LSM_MARKER="$letter"
    else
        LSM_MARKER="${letter}$(( round + 1 ))"
    fi
}

# One row of the main listing. A timer whose activated unit is hidden by
# lsm_is_timer_triggered picks up a marker and queues that unit for the detail
# section; everything else prints exactly as before.
lsm_print_unit_row() {
    local scope="$1" unit="$2" tag="$3"
    local state ref="" activated marker

    if [[ "$unit" == *.timer ]]; then
        activated=$(lsm_systemctl "$scope" show "$unit" -p Unit --value 2>/dev/null || true)
        if [[ -n "$activated" ]] && lsm_is_timer_triggered "$scope" "$activated"; then
            lsm_next_marker
            marker="$LSM_MARKER"
            LSM_DEFERRED+=("$marker	$scope	$activated	$unit")
            ref=" ${BLUE}──activates──▶${NC} ${YELLOW}($marker)${NC}"
        fi
    fi

    state=$(lsm_systemctl "$scope" is-active "$unit" 2>/dev/null || echo "inactive")
    if [[ "$state" == "active" ]]; then
        echo -e "  ${GREEN}●${NC} [$tag] $unit (${GREEN}active/running${NC})$ref"
    else
        echo -e "  ${RED}○${NC} [$tag] $unit (${RED}inactive/stopped${NC})$ref"
    fi
}

# The cross-referenced section. Nothing is printed when no timer-driven unit was
# hidden, so a listing without timers looks exactly as it did before.
#
# Each property is queried on its own: `show -p A -p B --value` returns values in
# systemd's own order, not the order of the arguments, so batching them silently
# transposes the fields.
lsm_print_triggered_section() {
    (( ${#LSM_DEFERRED[@]} > 0 )) || return 0

    echo ""
    echo -e "${CYAN}Timer-activated units:${NC}"
    echo -e "  ${BLUE}Type=oneshot — inactive between runs by design. The timer above is what${NC}"
    echo -e "  ${BLUE}runs on a schedule; these are what it runs.${NC}"
    echo ""

    local rec marker scope unit timer tag active result last next detail
    for rec in "${LSM_DEFERRED[@]}"; do
        marker="${rec%%	*}"; rec="${rec#*	}"
        scope="${rec%%	*}";  rec="${rec#*	}"
        unit="${rec%%	*}"
        timer="${rec#*	}"
        tag="$(lsm_scope_label "$scope")"

        active=$(lsm_systemctl "$scope" show "$unit" -p ActiveState --value 2>/dev/null || true)
        result=$(lsm_systemctl "$scope" show "$unit" -p Result --value 2>/dev/null || true)
        last=$(lsm_systemctl "$scope" show "$unit" -p ExecMainStartTimestamp --value 2>/dev/null || true)
        next=$(lsm_systemctl "$scope" show "$timer" -p NextElapseUSecRealtime --value 2>/dev/null || true)

        case "$active" in
            active|activating|reloading)
                detail="${GREEN}● running now${NC}" ;;
            failed)
                detail="${RED}✗ last run FAILED (${result:-unknown})${NC}${last:+ at $last}" ;;
            *)
                if [[ -z "$last" ]]; then
                    detail="${YELLOW}○ never run${NC}"
                else
                    detail="${GREEN}✓ last run ok${NC} at $last"
                fi ;;
        esac

        echo -e "  ${YELLOW}($marker)${NC} [$tag] $unit"
        echo -e "      $detail${next:+ ${BLUE}·${NC} next $next}"
    done
}

# Emits one NUL-terminated "<scope><TAB><unit-name>" record per personal unit,
# gathered from both managers' personal-services.target plus the repo's own
# services/ (system) and services/user/ (user) source directories. The source
# directories are the fallback that keeps units visible before they have been
# installed or enabled, so a fresh checkout still lists what it ships.
collect_personal_units() {
    local seen=()
    local scope dir u name

    if command -v systemctl &>/dev/null; then
        for scope in system user; do
            while read -r u; do
                if [[ -n "$u" && "$u" != "personal-services.target" ]]; then
                    printf '%s\t%s\0' "$scope" "$u"
                    seen+=("$scope	$u")
                fi
            done < <(lsm_systemctl "$scope" list-dependencies personal-services.target \
                         --plain --no-legend 2>/dev/null | lsm_unit_names || true)
        done
    fi

    for scope in system user; do
        if [[ "$scope" == "user" ]]; then
            dir="$USER_SERVICES_DIR"
        else
            dir="$SERVICES_DIR"
        fi
        # -d follows symlinks, so a stow-linked $SERVICES_PATH passes.
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' file; do
            name=$(basename "$file")
            [[ " ${seen[*]:-} " == *" ${scope}	${name} "* ]] && continue
            # A template from the directory scan is redundant once the target has
            # already contributed its live instances: the display layer expands
            # templates, so emitting both lists every instance twice.
            if [[ "$name" == *@.service || "$name" == *@.timer ]]; then
                base="${name%@*}"; suffix="${name##*.}"
                dup=false
                for s in "${seen[@]:-}"; do
                    [[ "$s" == "${scope}	${base}@"*".${suffix}" ]] && { dup=true; break; }
                done
                [[ "$dup" == true ]] && continue
            fi
            printf '%s\t%s\0' "$scope" "$name"
            seen+=("$scope	$name")
        done < <(find -L "$dir" -maxdepth 1 -type f \( -name '*.service' -o -name '*.timer' \) -print0 2>/dev/null)
    done
}


case "$action" in
    --active)
        echo -e "${CYAN}Currently running services:${NC}"
        echo ""
        systemctl list-units --type=service --state=running --no-pager | head -30
        echo ""
        echo -e "${BLUE}Showing first 30 services. Use 'systemctl list-units --type=service' for complete list.${NC}"
        ;;
    --failed)
        failed=$(systemctl list-units --type=service --state=failed --no-pager)
        if echo "$failed" | grep -q "0 loaded units listed"; then
            echo -e "${GREEN}✓ No failed services!${NC}"
        else
            echo -e "${RED}Failed service units:${NC}"
            echo ""
            echo "$failed"
        fi
        ;;
    --timers)
        echo -e "${CYAN}Active systemd timers:${NC}"
        echo ""
        systemctl list-timers --all --no-pager
        ;;
    --cron)
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
                count=$(ls -1 "$dir" 2>/dev/null | wc -l)
                echo -e "  ${BLUE}$dir${NC}: $count scripts"
            fi
        done
        ;;
    --user-scripts)
        echo -e "${CYAN}Custom scripts in /usr/local/bin:${NC}"
        echo ""
        # Derive the prefix from the containing distro directory: this file is shared
        # verbatim between distros, and a hardcoded "arch-" found nothing on Debian,
        # whose installer writes debian-*.sh.
        script_prefix="$(basename "$SCRIPT_DIR")"
        if [[ -d /usr/local/bin ]]; then
            found_any=false
            while IFS= read -r -d '' installed; do
                printf '  %s  %6s  %s\n' \
                    "$(stat -c '%A' "$installed")" \
                    "$(du -h "$installed" | cut -f1)" \
                    "$(basename "$installed")"
                found_any=true
            done < <(find /usr/local/bin -maxdepth 1 -type f \
                          -name "${script_prefix}-*.sh" -print0 2>/dev/null | sort -z)
            if [[ "$found_any" == false ]]; then
                echo "  No ${script_prefix}-*.sh scripts found"
            fi
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
        ;;
    --enabled)
        echo -e "${CYAN}Services enabled at boot:${NC}"
        echo ""
        systemctl list-unit-files --type=service --state=enabled --no-pager | head -30
        echo ""
        echo -e "${BLUE}Showing first 30 enabled services.${NC}"
        ;;
    --recent-changes)
        echo -e "${CYAN}Recently modified systemd units:${NC}"
        echo ""
        find /etc/systemd/system /usr/lib/systemd/system -type f -name "*.service" -mtime -30 2>/dev/null | while read -r file; do
            mtime=$(stat -c %y "$file" | cut -d'.' -f1)
            echo -e "  ${YELLOW}$mtime${NC}  $(basename "$file")"
        done | head -20
        ;;
    --active-personal)
        echo -e "${CYAN}Personal Services & Timers Status:${NC}"
        echo ""
        while IFS= read -r -d '' record; do
            scope="${record%%	*}"
            name="${record#*	}"
            tag="$(lsm_scope_label "$scope")"
            if [[ "$name" == *@.service || "$name" == *@.timer ]]; then
                template_base="${name%.*}"
                template_suffix="${name##*.}"
                instances=()
                while read -r inst; do
                    if [[ -n "$inst" && "$inst" != "$name" ]]; then
                        instances+=("$inst")
                    fi
                done < <(lsm_systemctl "$scope" list-units --all --no-legend --plain --no-pager "${template_base}*.${template_suffix}" 2>/dev/null | lsm_unit_names || true)

                if [[ ${#instances[@]} -gt 0 ]]; then
                    for inst in "${instances[@]}"; do
                        lsm_is_timer_triggered "$scope" "$inst" && continue
                        lsm_print_unit_row "$scope" "$inst" "$tag"
                    done
                else
                    echo -e "  ${BLUE}ℹ${NC} [$tag] $name (No active instances)"
                fi
            else
                lsm_is_timer_triggered "$scope" "$name" && continue
                lsm_print_unit_row "$scope" "$name" "$tag"
            fi
        done < <(collect_personal_units)
        lsm_print_triggered_section
        ;;
    --failed-personal)
        echo -e "${CYAN}Failed Personal Services & Timers Check:${NC}"
        echo ""
        failed_count=0
        while IFS= read -r -d '' record; do
            scope="${record%%	*}"
            name="${record#*	}"
            tag="$(lsm_scope_label "$scope")"
            if [[ "$name" == *@.service || "$name" == *@.timer ]]; then
                template_base="${name%.*}"
                template_suffix="${name##*.}"
                while read -r inst; do
                    if [[ -n "$inst" && "$inst" != "$name" ]]; then
                        state=$(lsm_systemctl "$scope" show -p ActiveState --value "$inst" 2>/dev/null || echo "")
                        substate=$(lsm_systemctl "$scope" show -p SubState --value "$inst" 2>/dev/null || echo "")
                        if [[ "$state" == "failed" ]] || [[ "$substate" == "failed" ]]; then
                            echo -e "  ${RED}✗ [$tag] $inst is failed${NC}"
                            lsm_systemctl "$scope" status "$inst" --no-pager | sed 's/^/    /'
                            echo ""
                            failed_count=$((failed_count + 1))
                        fi
                    fi
                done < <(lsm_systemctl "$scope" list-units --all --no-legend --plain --no-pager "${template_base}*.${template_suffix}" 2>/dev/null | lsm_unit_names || true)
            else
                state=$(lsm_systemctl "$scope" show -p ActiveState --value "$name" 2>/dev/null || echo "")
                substate=$(lsm_systemctl "$scope" show -p SubState --value "$name" 2>/dev/null || echo "")
                if [[ "$state" == "failed" ]] || [[ "$substate" == "failed" ]]; then
                    echo -e "  ${RED}✗ [$tag] $name is failed${NC}"
                    lsm_systemctl "$scope" status "$name" --no-pager | sed 's/^/    /'
                    echo ""
                    failed_count=$((failed_count + 1))
                fi
            fi
        done < <(collect_personal_units)
        if [[ $failed_count -eq 0 ]]; then
            echo -e "${GREEN}✓ No failed personal services/timers!${NC}"
        fi
        ;;
    --manage-personal)
        echo -e "${CYAN}Manage Personal Services & Timers:${NC}"
        echo ""
        units=()
        scopes=()
        while IFS= read -r -d '' record; do
            scopes+=("${record%%	*}")
            units+=("${record#*	}")
        done < <(collect_personal_units)

        if [[ ${#units[@]} -eq 0 ]]; then
            echo "No personal services/timers found."
            exit 0
        fi

        echo "Select a personal unit to manage:"
        echo ""
        i=1
        for idx in "${!units[@]}"; do
            echo -e "  ${GREEN}$i${NC}) [$(lsm_scope_label "${scopes[$idx]}")] ${units[$idx]}"
            i=$((i + 1))
        done
        echo -e "  ${RED}0${NC}) Cancel"
        echo ""
        read -p "Select unit (1-$((i-1))): " choice
        
        if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -ge "$i" ]]; then
            echo "Cancelled or invalid selection."
            exit 0
        fi
        
        selected_unit="${units[$((choice-1))]}"
        selected_scope="${scopes[$((choice-1))]}"
        echo ""

        # If template, resolve instance
        if [[ "$selected_unit" == *@.service || "$selected_unit" == *@.timer ]]; then
            template_base="${selected_unit%.*}"
            template_suffix="${selected_unit##*.}"
            echo "Scanning for instantiated units of $selected_unit..."
            
            # Find active or configured instances
            instances=()
            while read -r line; do
                if [[ -n "$line" ]]; then
                    instances+=("$line")
                fi
            done < <(lsm_systemctl "$selected_scope" list-units --all --no-legend --plain --no-pager "${template_base}*.${template_suffix}" 2>/dev/null | lsm_unit_names || true)

            # Check enabled/disabled ones too
            while read -r line; do
                if [[ -n "$line" && "$line" == *.* ]]; then
                    exists=false
                    for inst in "${instances[@]:-}"; do
                        if [[ "$inst" == "$line" ]]; then
                            exists=true
                            break
                        fi
                    done
                    if [[ "$exists" = false ]]; then
                        instances+=("$line")
                    fi
                fi
            done < <(lsm_systemctl "$selected_scope" list-unit-files --no-legend --plain --no-pager "${template_base}*.${template_suffix}" 2>/dev/null | lsm_unit_names || true)

            # Filter base template
            filtered_instances=()
            for inst in "${instances[@]:-}"; do
                if [[ "$inst" != "$selected_unit" && "$inst" != "${template_base}.service" && "$inst" != "${template_base}.timer" ]]; then
                    filtered_instances+=("$inst")
                fi
            done
            
            if [[ ${#filtered_instances[@]} -eq 0 ]]; then
                echo -e "${YELLOW}No instances of $selected_unit are currently configured or running on the system.${NC}"
                echo -e "You can configure them from Section 6 (Cloud Sync Management)."
                exit 0
            fi
            
            echo "Select an instance to manage:"
            inst_idx=1
            for inst in "${filtered_instances[@]}"; do
                echo -e "  ${GREEN}$inst_idx${NC}) $inst"
                inst_idx=$((inst_idx + 1))
            done
            echo -e "  ${RED}0${NC}) Cancel"
            echo ""
            read -p "Select instance (1-$((inst_idx-1))): " inst_choice
            if [[ ! "$inst_choice" =~ ^[0-9]+$ ]] || [[ "$inst_choice" -lt 1 ]] || [[ "$inst_choice" -ge "$inst_idx" ]]; then
                echo "Cancelled."
                exit 0
            fi
            selected_unit="${filtered_instances[$((inst_choice-1))]}"
            echo ""
        fi

        echo -e "Selected unit: ${CYAN}$selected_unit${NC} [$(lsm_scope_label "$selected_scope")]"
        echo "1) Start & Enable"
        echo "2) Stop & Disable"
        echo "3) View status logs"
        read -p "Select action: " act

        case "$act" in
            1)
                echo "Enabling and starting $selected_unit ($selected_scope scope)..."
                lsm_systemctl_admin "$selected_scope" enable --now "$selected_unit"
                ;;
            2)
                echo "Stopping and disabling $selected_unit ($selected_scope scope)..."
                lsm_systemctl_admin "$selected_scope" disable --now "$selected_unit"
                ;;
            3)
                echo ""
                lsm_systemctl "$selected_scope" status "$selected_unit" --no-pager
                ;;
            *)
                echo "Invalid action."
                ;;
        esac
        ;;
    *)
        echo -e "${RED}Unknown action: $action${NC}"
        exit 1
        ;;
esac
