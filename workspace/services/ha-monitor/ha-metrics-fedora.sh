#!/usr/bin/env bash
# Fedora specific metrics

# Inherit generic logic
source "$(dirname "${BASH_SOURCE[0]}")/ha-metrics-generic.sh"

# Example: Check for dnf updates
get_updates_available() {
    if command -v dnf &>/dev/null; then
        dnf check-update -q | grep -c '^\S' || echo "0"
    else
        echo "0"
    fi
}
