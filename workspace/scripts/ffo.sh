#!/bin/bash

extension=""
open_file=false

# Check if -o flag is passed
if [[ "$1" == "-o" ]]; then
    open_file=true
    shift  # Remove the -o flag from arguments
fi

# If an argument is given, treat it as an extension filter
if [[ -n "$1" ]]; then
    extension="$1"
fi

# Use fd to find files with or without an extension filter
if [[ -n "$extension" ]]; then
    selected_file=$(fd --type f --extension "$extension" . | fzf)
else
    selected_file=$(fd --type f . | fzf)
fi

# Check if a file was selected
if [[ -n "$selected_file" ]]; then
    if [[ "$open_file" == true ]]; then
        vim "$selected_file"
    else
        full_path="$(realpath "$selected_file")"
        
        # Copy to clipboard (macOS: pbcopy, Linux: xclip)
        if command -v pbcopy &> /dev/null; then
            echo -n "$full_path" | pbcopy
        elif command -v xclip &> /dev/null; then
            echo -n "$full_path" | xclip -selection clipboard
        else
            echo "Clipboard copy not supported. Full path: $full_path"
            exit 1
        fi
        
        echo "Copied to clipboard: $full_path"
    fi
else
    echo "No file selected."
fi

