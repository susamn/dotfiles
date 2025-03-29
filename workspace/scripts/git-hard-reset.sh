#!/bin/bash

# Prompt for confirmation to reset
read -p "Proceed with git reset --hard? (Y/n): " ans
if [[ "$ans" == "Y" ]]; then
    git reset --hard
    echo "Reset successful."
else
    echo "Aborted."
    exit 1
fi

# Ask if user wants to clean untracked files
read -p "Do you want to clean untracked files with git clean -fd? (Y/n): " clean_ans
if [[ "$clean_ans" == "Y" ]]; then
    git clean -fd
    echo "Cleaned untracked files and directories."
else
    echo "Skipped cleaning."
fi

