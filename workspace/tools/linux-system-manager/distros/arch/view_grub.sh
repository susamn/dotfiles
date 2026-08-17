#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Allow override so the parser can be exercised against a fixture in tests.
grub_cfg="${GRUB_CFG:-/boot/grub/grub.cfg}"

if [[ ! -f "$grub_cfg" ]]; then
    echo -e "${RED}✗ GRUB config not found at $grub_cfg${NC}"
    exit 1
fi

echo -e "${BLUE}━━━ GRUB Menu Entries ━━━${NC}"
echo ""

# Anchoring on '^menuentry' misses every entry nested inside a submenu block,
# which is where GRUB puts fallback and older-kernel entries by default. Allow
# leading whitespace, and guard grep so "no entries" is reported rather than
# aborting the script under `set -e`.
menu_entries="$(grep -E '^[[:space:]]*menuentry' "$grub_cfg" \
                | sed -E "s/^[[:space:]]*menuentry[[:space:]]+['\"]([^'\"]*)['\"].*/\1/" \
                || true)"

if [[ -z "$menu_entries" ]]; then
    echo -e "${YELLOW}⚠ No menu entries found in $grub_cfg${NC}"
    echo -e "  This usually means the config is truncated or was not generated."
    echo -e "  Regenerate with: ${CYAN}sudo grub-mkconfig -o $grub_cfg${NC}"
    exit 1
fi

# `echo "$x" | wc -l` reports 1 for empty input; count only non-empty lines.
entry_count="$(grep -c . <<< "$menu_entries" || true)"

echo -e "${GREEN}Found $entry_count menu entries:${NC}"
echo ""

counter=1
while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    if [[ "$entry" == *linux* ]]; then
        echo -e "  ${GREEN}$counter.${NC} ${CYAN}$entry${NC}"
    else
        echo -e "  ${GREEN}$counter.${NC} $entry"
    fi
    counter=$((counter + 1))
done <<< "$menu_entries"
