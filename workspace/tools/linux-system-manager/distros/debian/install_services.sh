#!/bin/bash
# Menu entry point for the installer. The menu runner resolves exec paths inside
# distros/<id>/, so this thin wrapper is what lets Section 5 reach the
# distro-agnostic installer two levels up. It deliberately does not escalate:
# install.py self-escalates only once something is actually going to be written,
# so browsing what is installed never prompts for a password.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$(cd "$SCRIPT_DIR/../.." && pwd)/install.py"

if [[ ! -x "$INSTALLER" ]]; then
    echo "Installer not found or not executable: $INSTALLER" >&2
    exit 1
fi

exec "$INSTALLER" "${1:---interactive}"
