#!/bin/bash

# Check if the current directory is a Git repository
if [ ! -d .git ]; then
  echo "Error: Not a Git repository!"
  exit 1
fi

# Define the source (template) and destination (repository) directories
TEMPLATE_DIR="$HOME/.git-templates/hooks"
REPO_DIR=".git/hooks"

# Ensure the template directory exists
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "Error: Template directory ($TEMPLATE_DIR) does not exist!"
  exit 1
fi

# Copy hooks from the template to the repo's .git/hooks directory
for hook in "$TEMPLATE_DIR"/*; do
  hook_name=$(basename "$hook")
  destination="$REPO_DIR/$hook_name"

  # Only copy the hook if it doesn't already exist
  if [ ! -f "$destination" ]; then
    cp "$hook" "$destination"
    chmod +x "$destination"
    echo "Copied hook: $hook_name"
  else
    echo "Hook '$hook_name' already exists, skipping."
  fi
done

