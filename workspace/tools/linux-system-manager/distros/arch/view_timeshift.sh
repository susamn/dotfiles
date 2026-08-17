#!/bin/bash
set -euo pipefail

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

has_timeshift=false
has_btrfs=false

# Check if Timeshift is installed
if command -v timeshift &> /dev/null; then
    has_timeshift=true
fi

# Check if using BTRFS
if command -v btrfs &> /dev/null; then
    root_fs=$(findmnt -n -o FSTYPE /)
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
    exit 1
fi

# Show Timeshift snapshots
if [[ "$has_timeshift" == "true" ]]; then
    echo -e "${BLUE}━━━ Timeshift Snapshots ━━━${NC}"
    echo ""

    # Get snapshot list
    snapshot_output=""
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
        snapshots=$(echo "$snapshot_output" | grep "^>" || true)
        snapshot_count=0
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
            counter=1
            while IFS= read -r line; do
                if [[ "$line" =~ ^\> ]]; then
                    snapshot_info=$(echo "$line" | sed 's/^> //')
                    echo -e "${CYAN}$counter.${NC} $snapshot_info"
                    counter=$((counter + 1))
                fi
            done <<< "$snapshot_output"

            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""

            # Show most recent
            most_recent=$(echo "$snapshots" | head -1 | sed 's/^> //')
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
        echo "      Use Option 1-4 (Create Boot Backup) for boot configs."
    fi
fi

# Show BTRFS snapshots if available
if [[ "$has_btrfs" == "true" ]]; then
    echo ""
    echo -e "${BLUE}━━━ BTRFS Snapshots ━━━${NC}"
    echo ""

    btrfs_snapshots=""
    if [[ $EUID -eq 0 ]]; then
        btrfs_snapshots=$(btrfs subvolume list / 2>/dev/null | grep -i snapshot || true)
    else
        btrfs_snapshots=$(sudo btrfs subvolume list / 2>/dev/null | grep -i snapshot || true)
    fi

    if [[ -z "$btrfs_snapshots" ]]; then
        echo -e "${YELLOW}⚠ No BTRFS snapshots found${NC}"
    else
        count=$(echo "$btrfs_snapshots" | wc -l)
        echo -e "${GREEN}Found $count BTRFS snapshot(s)${NC}"
        echo ""
        echo "$btrfs_snapshots" | head -10 | while IFS= read -r line; do
            snap_path=$(echo "$line" | awk '{print $NF}')
            echo -e "  ${CYAN}•${NC} $snap_path"
        done
        if [[ $count -gt 10 ]]; then
            echo "  ... and $((count - 10)) more"
        fi
    fi
fi
