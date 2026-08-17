#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

read -p "Enter package name to analyze: " package_name

if [[ -z "$package_name" ]]; then
    exit 0
fi

if ! pacman -Si "$package_name" &>/dev/null; then
    echo -e "${RED}✗ Package not found: $package_name${NC}"
    exit 1
fi

version=$(pacman -Si "$package_name" | grep "^Version" | cut -d':' -f2- | xargs)
size=$(pacman -Si "$package_name" | grep "^Installed Size" | cut -d':' -f2- | xargs)

echo ""
echo -e "${CYAN}Package:${NC} $package_name"
echo -e "${CYAN}Version:${NC} $version"
echo -e "${CYAN}Size:${NC} $size"
