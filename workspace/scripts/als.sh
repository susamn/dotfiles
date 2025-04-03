#!/bin/bash

# Path to lookup file (adjust if needed)
LOOKUP_FILE="${WORKSPACE_PATH:-$HOME}/.alias_descriptions"
MAX_COMMAND_LENGTH=30
SHOW_DESCRIPTIONS=false

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
    echo "Error: No input provided. Pipe alias list into this script."
    echo "Example: alias | ./script.sh [-m]"
    exit 1
fi

echo -e "NAME                  COMMAND                                   DESCRIPTION"

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
            printf "%-10s %-35s %s\n" "$name" "$command" "$description"
        else
            printf "%-10s %-35s\n" "$name" "$command"
        fi
    fi
done | fzf --layout=reverse --border --preview-window=wrap

