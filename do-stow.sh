#!/usr/bin/env bash
# do-stow.sh — Stow dotfiles, deploy skill symlinks, and create agent instruction symlinks
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$DOTFILES_DIR/skills"
AGENTS_FILE="$SKILLS_DIR/.agents"

# ── stow packages ─────────────────────────────────────────────────────────────
# Exclusions are handled by .stow-local-ignore — no --ignore flags needed.
stow_packages() {
  cd "$DOTFILES_DIR"

  echo "[stow] Checking for conflicts..."
  if stow -nvt ~ . 2>&1 | grep -q "existing target"; then
    echo ""
    echo "Conflicts detected! Aborting."
    echo "Resolve manually, or re-run with --adopt:"
    echo "  stow -vt ~ . --adopt"
    exit 1
  fi

  echo "[stow] Stowing dotfiles..."
  stow -vt ~ .
}

# ── parse .agents line ────────────────────────────────────────────────────────
# Sets globals: AGENT_NAME, AGENT_SKILLS_PATH, AGENT_INSTRUCTION_LINK
parse_agent_line() {
  local line="$1"
  AGENT_NAME="$(awk '{print $1}' <<< "$line")"
  AGENT_SKILLS_PATH="$(awk '{print $2}' <<< "$line")"
  AGENT_SKILLS_PATH="${AGENT_SKILLS_PATH/#\~/$HOME}"
  AGENT_INSTRUCTION_LINK="$(awk '{print $3}' <<< "$line")"
  AGENT_INSTRUCTION_LINK="${AGENT_INSTRUCTION_LINK/#\~/$HOME}"
}

# ── deploy skill symlinks ─────────────────────────────────────────────────────
deploy_skills() {
  if [[ ! -f "$AGENTS_FILE" ]]; then
    echo "[skills] No skills/.agents file found, skipping."
    return
  fi

  shopt -s nullglob

  # Collect active and disabled skill names once
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

  local skills_joined
  skills_joined="$(IFS=$','; echo "${skill_names[*]}" | sed 's/,/, /g')"

  # Deploy symlinks and collect agent names
  local agent_names=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    parse_agent_line "$line"
    mkdir -p "$AGENT_SKILLS_PATH"

    # Remove symlinks for disabled skills
    for disabled_name in "${disabled_names[@]}"; do
      local link="$AGENT_SKILLS_PATH/$disabled_name"
      if [[ -L "$link" ]]; then
        rm "$link"
      fi
    done

    # Create symlinks for active skills
    for skill_name in "${skill_names[@]}"; do
      ln -sfn "$SKILLS_DIR/$skill_name/" "$AGENT_SKILLS_PATH/$skill_name"
    done

    agent_names+=("$AGENT_NAME")
  done < "$AGENTS_FILE"

  local agents_joined
  agents_joined="$(IFS=$','; echo "${agent_names[*]}" | sed 's/,/, /g')"

  echo "[skills] installing: $skills_joined"
  [[ ${#disabled_names[@]} -gt 0 ]] && echo "[skills] disabled: $(IFS=$','; echo "${disabled_names[*]}" | sed 's/,/, /g')"
  echo "[skills] agents: $agents_joined"
}

# ── generate instruction files ────────────────────────────────────────────────
# Generates agent-specific instruction files from templates/AGENTS.md.template.
# These live outside the dotfiles repo (e.g. ~/.claude/CLAUDE.md) and contain
# agent-specific paths, allowing agents to identify their own context.
deploy_instructions() {
  local template="$DOTFILES_DIR/templates/AGENTS.md.template"
  if [[ ! -f "$AGENTS_FILE" || ! -f "$template" ]]; then
    echo "[instructions] Skipping: template or .agents file missing."
    return
  fi

  local entries=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    parse_agent_line "$line"

    [[ -z "$AGENT_INSTRUCTION_LINK" || "$AGENT_INSTRUCTION_LINK" == "-" ]] && continue

    local link_dir
    link_dir="$(dirname "$AGENT_INSTRUCTION_LINK")"
    mkdir -p "$link_dir"

    # Generate the file from template, replacing placeholders
    # Use ~/ instead of absolute path for the instruction file content
    local display_path="${AGENT_INSTRUCTION_LINK/$HOME/\~}"
    local skills_display_path="${AGENT_SKILLS_PATH/$HOME/\~}"
    rm -f "$AGENT_INSTRUCTION_LINK"
    sed -e "s|{{INSTRUCTION_PATH}}|$display_path|g" -e "s|{{AGENT_SKILLS_PATH}}|$skills_display_path|g" "$template" > "$AGENT_INSTRUCTION_LINK"

    entries+=("$AGENT_NAME")
  done < "$AGENTS_FILE"

  local joined
  joined="$(IFS=$','; echo "${entries[*]}" | sed 's/,/, /g')"
  echo "[instructions] generated: $joined"
}

stow_packages
deploy_skills
deploy_instructions
