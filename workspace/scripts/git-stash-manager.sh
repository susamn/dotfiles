#!/usr/bin/env bash

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not a git repository"
    exit 1
fi

# Check bash version (need 4.0+ for associative arrays, but we're not using them heavily)
if [[ -z "$BASH_VERSION" ]]; then
    echo "❌ This script requires bash"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
LIGHT_GRAY='\033[1;37m'
LIGHT_GREEN='\033[1;32m'
LIGHT_YELLOW='\033[1;33m'
NC='\033[0m'

# Get current branch
current_branch=$(git branch --show-current)
if [[ -z "$current_branch" ]]; then
    # Detached HEAD state
    current_branch="(detached HEAD)"
fi
echo -e "${MAGENTA}🌿 Current Branch:${NC} ${current_branch}"
echo

# Get all stashes
stash_count=$(git stash list | wc -l)

if [[ $stash_count -eq 0 ]]; then
    echo -e "  ${GREEN}✓ No stashes found${NC}"
    exit 0
fi

echo -e "${CYAN}\033[4mStashed Changes\033[0m${NC} ${GRAY}(${stash_count} total)${NC}"
echo

# Parse and display each stash
git stash list --format="%gd|%gs|%cr" | while IFS='|' read -r stash_ref message time_ago; do
    # Extract branch name from message (format: "WIP on branch: commit_hash commit_msg" or "On branch: commit_msg")
    if [[ $message =~ (WIP on|On) ]]; then
        # Try sed -E first (macOS, modern GNU sed), fall back to sed -r (older GNU sed)
        branch=$(echo "$message" | sed -E 's/(WIP on|On) ([^:]+):.*/\2/' 2>/dev/null || echo "$message" | sed -r 's/(WIP on|On) ([^:]+):.*/\2/' 2>/dev/null)
        description=$(echo "$message" | sed -E 's/(WIP on|On) [^:]+: (.+)/\2/' 2>/dev/null || echo "$message" | sed -r 's/(WIP on|On) [^:]+: (.+)/\2/' 2>/dev/null)

        # Fallback if sed failed
        if [[ -z "$branch" ]]; then
            branch="unknown"
        fi
        if [[ -z "$description" ]]; then
            description="$message"
        fi
    else
        branch="unknown"
        description="$message"
    fi

    # Color code based on whether stash is from current branch
    if [[ "$branch" == "$current_branch" ]]; then
        branch_color="${LIGHT_GREEN}"
        stash_emoji="📦"
    else
        branch_color="${LIGHT_YELLOW}"
        stash_emoji="📦"
    fi

    # Display stash entry
    echo -e "  ${stash_emoji} ${LIGHT_GRAY}${stash_ref}${NC}"
    echo -e "     ${GREEN}├─${NC} Branch: ${branch_color}${branch}${NC}"
    echo -e "     ${GREEN}├─${NC} Time: ${GRAY}${time_ago}${NC}"
    echo -e "     ${GREEN}└─${NC} ${description}"

    # Show file count in stash
    file_count=$(git stash show "$stash_ref" --name-only 2>/dev/null | wc -l)
    if [[ $file_count -gt 0 ]]; then
        echo -e "        ${CYAN}↳${NC} ${GRAY}${file_count} file(s) changed${NC}"
    fi

    echo
done

echo
echo -e "${CYAN}\033[4mUsage\033[0m${NC}"
echo -e "  ${GREEN}•${NC} Apply stash:         ${YELLOW}git stash apply stash@{N}${NC}"
echo -e "  ${GREEN}•${NC} Apply & remove:      ${YELLOW}git stash pop stash@{N}${NC}"
echo -e "  ${GREEN}•${NC} Show stash diff:     ${YELLOW}git stash show -p stash@{N}${NC}"
echo -e "  ${GREEN}•${NC} Drop stash:          ${YELLOW}git stash drop stash@{N}${NC}"
echo -e "  ${GREEN}•${NC} Create branch:       ${YELLOW}git stash branch <name> stash@{N}${NC}"
echo
