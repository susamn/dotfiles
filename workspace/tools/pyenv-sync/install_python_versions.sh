#!/usr/bin/env bash
set -e

VERSIONS_FILE="$HOME/dotfiles/pyenv/python_versions.txt"

while read -r version; do
  if [ -n "$version" ]; then
    pyenv install -s "$version"
  fi
done < "$VERSIONS_FILE"

