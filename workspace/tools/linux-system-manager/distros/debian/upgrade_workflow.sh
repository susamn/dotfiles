#!/bin/bash
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "This will guide you through a safe upgrade process"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Step 1: Preview
if [[ -x "${SCRIPT_DIR}/pre_upgrade.sh" ]]; then
    "${SCRIPT_DIR}/pre_upgrade.sh"
fi

# Step 2: Backup
echo ""
read -p "Create backup before upgrade? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]] && [[ -x "${SCRIPT_DIR}/backup_boot.sh" ]]; then
    "${SCRIPT_DIR}/backup_boot.sh"
fi

# Step 3: Manual upgrade instruction
echo ""
echo -e "${CYAN}Run: ${GREEN}sudo apt update && sudo apt dist-upgrade${NC}"
echo ""
read -p "Press ENTER when upgrade is complete..." -r

# Step 4: Validation
if [[ -x "${SCRIPT_DIR}/check_boot.sh" ]]; then
    "${SCRIPT_DIR}/check_boot.sh"
fi
