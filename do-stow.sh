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

  local skill_count=0
  shopt -s nullglob

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    parse_agent_line "$line"

    mkdir -p "$AGENT_SKILLS_PATH"

    for skill_dir in "$SKILLS_DIR"/*/; do
      [[ -d "$skill_dir" ]] || continue
      local skill_name
      skill_name="$(basename "$skill_dir")"
      ln -sfn "$skill_dir" "$AGENT_SKILLS_PATH/$skill_name"
      echo "  [$AGENT_NAME] skill: $skill_name"
      (( skill_count++ )) || true
    done
  done < "$AGENTS_FILE"

  echo "[skills] $skill_count skill symlink(s) deployed."
}

# ── create instruction symlinks ───────────────────────────────────────────────
# Creates a symlink at the agent's global instruction file path → AGENTS.md.
# These live outside the dotfiles repo (e.g. ~/.claude/CLAUDE.md) so agents
# pick them up from any working directory, not just when inside this repo.
deploy_instruction_links() {
  if [[ ! -f "$AGENTS_FILE" ]]; then
    return
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    parse_agent_line "$line"

    [[ -z "$AGENT_INSTRUCTION_LINK" || "$AGENT_INSTRUCTION_LINK" == "-" ]] && continue

    local link_dir
    link_dir="$(dirname "$AGENT_INSTRUCTION_LINK")"
    mkdir -p "$link_dir"

    local rel_target
    rel_target="$(realpath --relative-to="$link_dir" "$DOTFILES_DIR/AGENTS.md")"

    ln -sfn "$rel_target" "$AGENT_INSTRUCTION_LINK"
    echo "  [$AGENT_NAME] instruction: $AGENT_INSTRUCTION_LINK → $rel_target"
  done < "$AGENTS_FILE"
}

stow_packages
deploy_skills
deploy_instruction_links
