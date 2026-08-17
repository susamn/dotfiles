#!/bin/bash
set -euo pipefail

# Arch-specific hook installer
# This script is called by the global install.py with root privileges.

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}⚙ Running Arch-specific hook installation...${NC}"

# 1. Install executables to /usr/local/bin/ (referenced by hooks)
echo "  Installing scripts to /usr/local/bin/..."
cp "${SCRIPT_DIR}/check_boot.sh" /usr/local/bin/arch-boot-check.sh
chmod +x /usr/local/bin/arch-boot-check.sh
echo -e "  ${GREEN}✓ Installed /usr/local/bin/arch-boot-check.sh${NC}"

cp "${SCRIPT_DIR}/timeline.sh" /usr/local/bin/arch-package-timeline.sh
chmod +x /usr/local/bin/arch-package-timeline.sh
echo -e "  ${GREEN}✓ Installed /usr/local/bin/arch-package-timeline.sh${NC}"

# 2. Install pacman hooks
echo "  Installing Pacman hooks to /etc/pacman.d/hooks/..."
mkdir -p /etc/pacman.d/hooks

if [[ -d "${SCRIPT_DIR}/hooks" ]]; then
    for hook in "${SCRIPT_DIR}/hooks"/*.hook; do
        if [[ -f "$hook" ]]; then
            cp "$hook" /etc/pacman.d/hooks/
            echo -e "    ${GREEN}✓ Copied $(basename "$hook")${NC}"
        fi
    done
fi

echo -e "  ${GREEN}✓ Arch hooks and tools installation completed successfully.${NC}"
