#!/usr/bin/env bash
# Arch Linux specific metrics

# Inherit generic logic
source "$(dirname "${BASH_SOURCE[0]}")/ha-metrics-generic.sh"

# Example: Check for pacman updates
get_updates_available() {
    if command -v checkupdates &>/dev/null; then
        checkupdates | wc -l
    else
        echo "0"
    fi
}
