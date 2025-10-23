#!/usr/bin/env bash

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not a git repository"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
LIGHT_GRAY='\033[1;37m'
NC='\033[0m'

# Get current branch
current_branch=$(git branch --show-current)
if [[ -z "$current_branch" ]]; then
    current_branch="(detached HEAD)"
fi

# Parse arguments
ACTION="apply"
if [[ "$1" == "-p" ]] || [[ "$1" == "--pop" ]]; then
    ACTION="pop"
elif [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo -e "${CYAN}Git Stash Apply Current${NC}"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo -e "  ${GREEN}-p, --pop${NC}     Pop (apply & remove) instead of just applying"
    echo -e "  ${GREEN}-h, --help${NC}    Show this help message"
    echo
    exit 0
fi

echo -e "${MAGENTA}🌿 Current Branch:${NC} ${current_branch}"
echo

# Find latest stash from current branch
stash_info=$(git stash list --format="%gd|%gs" | grep -m1 "WIP on ${current_branch}:")

if [[ -z "$stash_info" ]]; then
    echo -e "${YELLOW}⚠ No stash found from branch '${current_branch}'${NC}"
    echo
    echo -e "${GRAY}Available stashes:${NC}"
    git stash list | head -5
    exit 1
fi

# Extract stash details
stash_ref=$(echo "$stash_info" | cut -d'|' -f1)
stash_msg=$(echo "$stash_info" | cut -d'|' -f2)

# Get file count
file_count=$(git stash show "$stash_ref" --name-only 2>/dev/null | wc -l)

# Display what we're about to do
if [[ "$ACTION" == "pop" ]]; then
    echo -e "${CYAN}🔄 Popping stash from current branch:${NC}"
else
    echo -e "${CYAN}🔄 Applying stash from current branch:${NC}"
fi

echo -e "  ${LIGHT_GRAY}${stash_ref}${NC}"
echo -e "     ${GREEN}├─${NC} ${stash_msg}"
echo -e "     ${GREEN}└─${NC} ${GRAY}${file_count} file(s) will be changed${NC}"
echo

# Apply or pop the stash
if [[ "$ACTION" == "pop" ]]; then
    if git stash pop "$stash_ref"; then
        echo
        echo -e "${GREEN}✓ Stash popped successfully!${NC}"
    else
        echo
        echo -e "${RED}❌ Failed to pop stash${NC}"
        exit 1
    fi
else
    if git stash apply "$stash_ref"; then
        echo
        echo -e "${GREEN}✓ Stash applied successfully!${NC}"
        echo -e "${GRAY}(Stash kept in list. Use -p or --pop to remove)${NC}"
    else
        echo
        echo -e "${RED}❌ Failed to apply stash${NC}"
        exit 1
    fi
fi
