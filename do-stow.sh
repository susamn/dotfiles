#!/usr/bin/env bash
# do-stow.sh — Stow dotfiles, deploy skill symlinks, and create agent instruction symlinks
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AISTUFF_DIR="$DOTFILES_DIR/workspace/aistuff"
SKILLS_DIR="$AISTUFF_DIR/skills"
AGENTS_FILE="$SKILLS_DIR/.agents"
IGNORE_PROFILES_DIR="$DOTFILES_DIR/stow-ignores"

# ── pick an ignore profile ────────────────────────────────────────────────────
SELECTED_IGNORE_FILE=""
select_ignore_profile() {
  command -v fzf >/dev/null 2>&1 || {
    echo "[stow] fzf is required to pick a stow-ignore profile. Install it and re-run." >&2
    exit 1
  }

  local profiles=()
  while IFS= read -r f; do profiles+=("$(basename "$f")"); done \
    < <(find "$IGNORE_PROFILES_DIR" -maxdepth 1 -type f | sort)

  if [[ ${#profiles[@]} -eq 0 ]]; then
    echo "[stow] No ignore profiles found in $IGNORE_PROFILES_DIR" >&2
    exit 1
  fi

  local choice confirm
  while true; do
    choice="$(printf '%s\n' "${profiles[@]}" | fzf --prompt="stow-ignore profile> " --height=~40% --border --header="Which machine is this? (Esc to abort)")"
    [[ -n "$choice" ]] || { echo "[stow] No profile selected, aborting."; exit 1; }

    confirm="$(printf '%s\n' "Yes" "No" | fzf --prompt="Use '$choice'? > " --height=~40% --border --header="Confirm profile selection")"
    if [[ "$confirm" == "Yes" ]]; then
      SELECTED_IGNORE_FILE="$IGNORE_PROFILES_DIR/$choice"
      echo "[stow] Using ignore profile: $choice"
      return
    fi
    # "No" or Esc on confirm: loop back to profile selection
  done
}

# ── stow ignore configurations ───────────────────────────────────────────────
STOW_IGNORE_FLAGS=()
get_stow_ignore_flags() {
  local flags=()
  if [[ -f "$SELECTED_IGNORE_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      # Skip empty lines and comments
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      line=$(echo "$line" | xargs)

      # Convert glob pattern to regex pattern
      local escaped
      escaped="${line//./\.}"
      escaped="${escaped//\*/.*}"

      if [[ "$escaped" == */ ]]; then
        flags+=("--ignore=^${escaped%/}($|/)")
      else
        flags+=("--ignore=^${escaped}$")
      fi
    done < "$SELECTED_IGNORE_FILE"
  fi
  STOW_IGNORE_FLAGS=("${flags[@]}")
}

# ── stow packages ─────────────────────────────────────────────────────────────
stow_packages() {
  cd "$DOTFILES_DIR"
  get_stow_ignore_flags

  echo "[stow] Checking for conflicts..."
  if stow "${STOW_IGNORE_FLAGS[@]}" -nvt ~ . 2>&1 | grep -q "existing target"; then
    echo ""
    echo "Conflicts detected! Aborting."
    echo "Resolve manually, or re-run with --adopt:"
    echo "  stow ${STOW_IGNORE_FLAGS[@]} -vt ~ . --adopt"
    exit 1
  fi

  echo "[stow] Stowing dotfiles..."
  stow "${STOW_IGNORE_FLAGS[@]}" -vt ~ .
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
# Generates agent-specific instruction files from skills/AGENTS-TEMPLATE.md.
# These live outside the dotfiles repo (e.g. ~/.claude/CLAUDE.md) and contain
# agent-specific paths, allowing agents to identify their own context.
deploy_instructions() {
  local template="$SKILLS_DIR/AGENTS-TEMPLATE.md"
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

# ── deploy mcp configs ────────────────────────────────────────────────────────
deploy_mcp() {
  if [[ -x "$DOTFILES_DIR/workspace/scripts/agm.sh" ]]; then
    echo "[mcp] Syncing MCP configurations..."
    "$DOTFILES_DIR/workspace/scripts/agm.sh" sync
  fi
}

select_ignore_profile
stow_packages
deploy_skills
deploy_instructions
deploy_mcp

