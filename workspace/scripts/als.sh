#!/bin/bash

# Path to lookup file (adjust if needed)
LOOKUP_FILE="${WORKSPACE_PATH:-$HOME}/.alias_descriptions"
SHOW_DESCRIPTIONS=false

# Color definitions
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'

# Check for the -m flag
while [[ "$1" ]]; do
    case "$1" in
        -m) SHOW_DESCRIPTIONS=true ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Ensure input is provided (prevent empty pipe)
if [[ -t 0 ]]; then
    echo -e "${BOLD}Error:${RESET} No input provided. Pipe alias list into this script."
    echo -e "${DIM}Example: alias | ./script.sh [-m]${RESET}"
    exit 1
fi

# Process input aliases (passed to the script)
while read -r line; do
    # Ensure the alias format is valid (key=value)
    [[ "$line" =~ ^[^=]+=[^=]+$ ]] || continue

    name=$(echo "$line" | awk -F '=' '{print $1}')

    # Ignore aliases that start with "_"
    if [[ ! $name =~ ^_ ]]; then
        command=$(echo "$line" | awk -F '=' '{print $2}' | sed "s/'//g")  # Remove surrounding quotes

        description=""
        if [[ "$SHOW_DESCRIPTIONS" == true && -f "$LOOKUP_FILE" ]]; then
            description=$(grep "^$name=" "$LOOKUP_FILE" | cut -d= -f2-)
        fi

        if [[ -n "$description" ]]; then
            # Format: name in cyan, command in green, description in dim
            printf "${CYAN}%-14s${RESET} ${GREEN}%-45s${RESET} ${DIM}%s${RESET}\n" "$name" "$command" "$description"
        else
            printf "${CYAN}%-14s${RESET} ${GREEN}%-45s${RESET}\n" "$name" "$command"
        fi
    fi
done | fzf \
    --ansi \
    --layout=reverse \
    --border=rounded \
    --border-label="│ Shell Aliases │" \
    --border-label-pos=3 \
    --prompt="🔍 " \
    --pointer="▶" \
    --marker="✓" \
    --header="NAME            COMMAND                                       DESCRIPTION" \
    --header-first \
    --color="border:#5f87af,label:#87afff:bold,header:#87afff:bold,prompt:#87d787:bold,pointer:#ff5f87:bold,marker:#87d787:bold" \
    --preview-window=hidden \
    --info=inline \
    --height=100%

