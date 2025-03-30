#!/bin/bash

# Path to lookup file (adjust if needed)
LOOKUP_FILE="$WORKSPACE_PATH/.alias_descriptions"
MAX_COMMAND_LENGTH=30

# Ensure the lookup file exists
if [[ ! -f "$LOOKUP_FILE" ]]; then
    echo "Error: Lookup file not found at $LOOKUP_FILE"
    exit 1
fi
echo -e "NAME                  COMMAND                                   DESCRIPTION"
# Process input aliases (passed to the script)
while read -r line; do
    name=$(echo "$line" | awk -F '=' '{print $1}')
    command=$(echo "$line" | awk -F '=' '{print $2}' | sed "s/'//g")  # Remove quotes around command

    # Lookup description for the alias
    desc=$(grep "^$name=" "$LOOKUP_FILE" | cut -d= -f2)
    #truncated_command=$(echo "$command" | cut -c1-$MAX_COMMAND_LENGTH)


    if [ -n "$desc" ]; then
        #printf "%-10s %-35s %s\n" "$name" "$truncated_command" "$desc"
        printf "%-10s %-35s %s\n" "$name" "$command" "$desc"
    else
        #printf "%-10s %-35s\n" "$name" "$truncated_command"
        printf "%-10s %-35s\n" "$name" "$command"

    fi
done | fzf --layout=reverse --border --preview-window=wrap

