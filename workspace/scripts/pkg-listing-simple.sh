#!/bin/bash

# Define file paths
BREW_FILE="brew_packages_descriptions"
PLATFORM_FILE="platform_packages_descriptions"

# Combine and format the package lists with tabs as delimiters
{
    awk -F'=' '{printf "brew\t%s\t%s\n", $1, $2}' "$BREW_FILE"
    awk -F'=' '{printf "platform\t%s\t%s\n", $1, $2}' "$PLATFORM_FILE"
} | fzf \
    --header "Source|Package|Description" \
    --delimiter $'\t' \
    --with-nth 1,2,3 \
    --preview 'echo -e "Description: {3}"' \
    --border \
    --height=50% \
    --layout=reverse \
    --info=inline
