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

  local entries=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    parse_agent_line "$line"

    [[ -z "$AGENT_INSTRUCTION_LINK" || "$AGENT_INSTRUCTION_LINK" == "-" ]] && continue

    if [[ -L "$AGENT_INSTRUCTION_LINK" ]]; then
      rm "$AGENT_INSTRUCTION_LINK"
      entries+=("$AGENT_NAME")
    fi
  done < "$AGENTS_FILE"

  local joined
  joined="$(IFS=$','; echo "${entries[*]}" | sed 's/,/, /g')"
  echo "[instructions] unlinked: $joined"
}

# ── remove skill symlinks ─────────────────────────────────────────────────────
remove_skills() {
  if [[ ! -f "$AGENTS_FILE" ]]; then
    echo "[skills] No skills/.agents file found, skipping."
    return
  fi

  shopt -s nullglob

  # Collect active and disabled skill names (matching deploy_skills logic)
  local skill_names=()
  local disabled_names=()
  for skill_dir in "$SKILLS_DIR"/*/; do
    [[ -d "$skill_dir" ]] || continue
    local name
    name="$(basename "$skill_dir")"
    if [[ "$name" == *.disabled ]]; then
      disabled_names+=("${name%.disabled}")
    else
      skill_names+=("$name")
    fi
  done

  local agent_names=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    parse_agent_line "$line"

    for skill_name in "${skill_names[@]}"; do
      local link="$AGENT_SKILLS_PATH/$skill_name"
      if [[ -L "$link" ]]; then
        rm "$link"
      fi
    done

    agent_names+=("$AGENT_NAME")
  done < "$AGENTS_FILE"

  local skills_joined agents_joined
  skills_joined="$(IFS=$','; echo "${skill_names[*]}" | sed 's/,/, /g')"
  agents_joined="$(IFS=$','; echo "${agent_names[*]}" | sed 's/,/, /g')"

  echo "[skills] removing: $skills_joined"
  [[ ${#disabled_names[@]} -gt 0 ]] && echo "[skills] disabled: $(IFS=$','; echo "${disabled_names[*]}" | sed 's/,/, /g')"
  echo "[skills] agents: $agents_joined"
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
