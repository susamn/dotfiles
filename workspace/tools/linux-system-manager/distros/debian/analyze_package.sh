#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

read -p "Enter package name to analyze: " package_name

if [[ -z "$package_name" ]]; then
    exit 0
fi

if ! apt-cache show "$package_name" &>/dev/null; then
    echo -e "${RED}✗ Package not found: $package_name${NC}"
    exit 1
fi

version=$(apt-cache show "$package_name" | grep "^Version:" | head -1 | cut -d':' -f2- | xargs)
size=$(apt-cache show "$package_name" | grep "^Installed-Size:" | head -1 | cut -d':' -f2- | xargs)

echo ""
echo -e "${CYAN}Package:${NC} $package_name"
echo -e "${CYAN}Version:${NC} $version"
echo -e "${CYAN}Size:${NC} ${size} KB"
