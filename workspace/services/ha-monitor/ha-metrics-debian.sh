#!/usr/bin/env bash
# Debian/Ubuntu/Mint/PopOS specific metrics

# Inherit generic logic
source "$(dirname "${BASH_SOURCE[0]}")/ha-metrics-generic.sh"

# Example: We could add a function to check for pending APT updates
get_updates_available() {
    if command -v apt-get &>/dev/null; then
        # This is slow, so maybe only run every few hours in a real scenario
        # For now, just a placeholder of how to extend
        apt-get -s upgrade | grep -P '^\d+ upgraded' | cut -d' ' -f1 || echo "0"
    else
        echo "0"
    fi
}
