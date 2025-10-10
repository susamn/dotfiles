#!/bin/bash

# Get top 5 processes by swap usage
# Output format: PID SWAP_KB COMMAND

# Use awk to parse /proc/*/status files and extract swap usage
for pid in /proc/[0-9]*; do
    if [ -f "$pid/status" ]; then
        pid_num=$(basename "$pid")

        # Get VmSwap value (in kB)
        swap=$(grep "^VmSwap:" "$pid/status" 2>/dev/null | awk '{print $2}')

        # Get process name
        name=$(grep "^Name:" "$pid/status" 2>/dev/null | awk '{print $2}')

        # Only print if swap > 0
        if [ -n "$swap" ] && [ "$swap" -gt 0 ] 2>/dev/null; then
            echo "$swap $name"
        fi
    fi
done | sort -rn | head -5 | awk '{
    swap_kb = $1
    name = $2

    # Convert KB to MB for better readability
    if (swap_kb >= 1024) {
        swap_mb = swap_kb / 1024
        printf "%-15s %6.1f MB\n", name, swap_mb
    } else {
        printf "%-15s %6d KB\n", name, swap_kb
    }
}'
