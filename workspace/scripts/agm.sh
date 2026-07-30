#!/usr/bin/env bash
# agm.sh — Agent & MCP Manager wrapper script for dotfiles
set -euo pipefail

# Resolve physical symlink target of this script
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
REAL_SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

export DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$REAL_SCRIPT_DIR/../.." && pwd)}"

python3 "$REAL_SCRIPT_DIR/agent-manager.py" "$@"
