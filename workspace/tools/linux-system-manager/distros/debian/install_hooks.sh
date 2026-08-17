#!/bin/bash
set -euo pipefail

# Debian/Ubuntu-specific hook installer
# This script is called by the global install.py with root privileges.

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}⚙ Running Debian-specific hook installation...${NC}"

# 1. Install executables to /usr/local/bin/
echo "  Installing scripts to /usr/local/bin/..."
cp "${SCRIPT_DIR}/check_boot.sh" /usr/local/bin/debian-boot-check.sh
chmod +x /usr/local/bin/debian-boot-check.sh
echo -e "  ${GREEN}✓ Installed /usr/local/bin/debian-boot-check.sh${NC}"

cp "${SCRIPT_DIR}/timeline.sh" /usr/local/bin/debian-package-timeline.sh
chmod +x /usr/local/bin/debian-package-timeline.sh
echo -e "  ${GREEN}✓ Installed /usr/local/bin/debian-package-timeline.sh${NC}"

cp "${SCRIPT_DIR}/backup_boot.sh" /usr/local/bin/debian-boot-backup.sh
chmod +x /usr/local/bin/debian-boot-backup.sh
echo -e "  ${GREEN}✓ Installed /usr/local/bin/debian-boot-backup.sh${NC}"

# 2. Install APT hooks
echo "  Installing APT hooks to /etc/apt/apt.conf.d/..."
mkdir -p /etc/apt/apt.conf.d

if [[ -f "${SCRIPT_DIR}/hooks/99sysmanager" ]]; then
    cp "${SCRIPT_DIR}/hooks/99sysmanager" /etc/apt/apt.conf.d/
    echo -e "    ${GREEN}✓ Copied 99sysmanager to /etc/apt/apt.conf.d/${NC}"
fi

echo -e "  ${GREEN}✓ Debian hooks and tools installation completed successfully.${NC}"
