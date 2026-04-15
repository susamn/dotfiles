#!/usr/bin/env bash
# do-unstow.sh — Remove instruction symlinks, skill symlinks, then unstow dotfiles
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$DOTFILES_DIR/skills"
AGENTS_FILE="$SKILLS_DIR/.agents"

# ── parse .agents line ────────────────────────────────────────────────────────
parse_agent_line() {
  local line="$1"
  AGENT_NAME="$(awk '{print $1}' <<< "$line")"
  AGENT_SKILLS_PATH="$(awk '{print $2}' <<< "$line")"
  AGENT_SKILLS_PATH="${AGENT_SKILLS_PATH/#\~/$HOME}"
  AGENT_INSTRUCTION_LINK="$(awk '{print $3}' <<< "$line")"
  AGENT_INSTRUCTION_LINK="${AGENT_INSTRUCTION_LINK/#\~/$HOME}"
}

# ── remove instruction symlinks ───────────────────────────────────────────────
remove_instruction_links() {
  if [[ ! -f "$AGENTS_FILE" ]]; then
    return
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    parse_agent_line "$line"

    [[ -z "$AGENT_INSTRUCTION_LINK" || "$AGENT_INSTRUCTION_LINK" == "-" ]] && continue

    if [[ -L "$AGENT_INSTRUCTION_LINK" ]]; then
      rm "$AGENT_INSTRUCTION_LINK"
      echo "  [$AGENT_NAME] removed instruction: $AGENT_INSTRUCTION_LINK"
    fi
  done < "$AGENTS_FILE"
}

# ── remove skill symlinks ─────────────────────────────────────────────────────
remove_skills() {
  if [[ ! -f "$AGENTS_FILE" ]]; then
    echo "[skills] No skills/.agents file found, skipping."
    return
  fi

  local removed=0
  shopt -s nullglob

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    parse_agent_line "$line"

    for skill_dir in "$SKILLS_DIR"/*/; do
      [[ -d "$skill_dir" ]] || continue
      local skill_name link
      skill_name="$(basename "$skill_dir")"
      link="$AGENT_SKILLS_PATH/$skill_name"

      if [[ -L "$link" ]]; then
        rm "$link"
        echo "  [$AGENT_NAME] removed skill: $skill_name"
        (( removed++ )) || true
      fi
    done
  done < "$AGENTS_FILE"

  echo "[skills] $removed skill symlink(s) removed."
}

# ── unstow packages ───────────────────────────────────────────────────────────
unstow_packages() {
  cd "$DOTFILES_DIR"
  echo "[stow] Unstowing dotfiles..."
  stow -Dvt ~ .
}

remove_instruction_links
remove_skills
unstow_packages
