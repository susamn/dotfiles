#!/bin/bash

# Define file paths
BREW_FILE="$INSTALL_PATH/brew_packages_descriptions"
PLATFORM_FILE="$INSTALL_PATH/platform_packages_descriptions"

# Function to check if package is installed
is_installed() {
    local source=$1
    local pkg=$2
    
    if [[ "$source" == "brew" ]]; then
        brew list --formula -1 | grep -qxF "$pkg"
    elif [[ "$source" == "platform" ]]; then
        command -v "$pkg" >/dev/null 2>&1 || \
        { [ -n "$(command -v apt)" ] && dpkg -l "$pkg" >/dev/null 2>&1; } || \
        { [ -n "$(command -v dnf)" ] && dnf list installed "$pkg" >/dev/null 2>&1; }
    fi
    return $?
}

# Combine and format package information
{
    # Process Brew packages
    while IFS='=' read -r pkg description; do
        if is_installed "brew" "$pkg"; then
            status="Yes"
        else
            status="No"
        fi
        printf "%s\t%s\tbrew\t%s\n" "$status" "$pkg" "$description"
    done < "$BREW_FILE"

    # Process Platform packages
    while IFS='=' read -r pkg description; do
        if is_installed "platform" "$pkg"; then
            status="Yes"
        else
            status="No"
        fi
        printf "%s\t%s\tplatform\t%s\n" "$status" "$pkg" "$description"
    done < "$PLATFORM_FILE"
} | fzf \
    --header "Installed|Package|Source|Description" \
    --delimiter $'\t' \
    --with-nth 1,2,3,4 \
    --preview 'echo -e "Description: {4}"' \
    --border \
    --height=50% \
    --layout=reverse \
    --info=inline \
    --ansi
