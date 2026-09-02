#!/usr/bin/env bash
# do-unstow.sh — Remove instruction symlinks, skill symlinks, then unstow dotfiles
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AISTUFF_DIR="$DOTFILES_DIR/workspace/aistuff"
SKILLS_DIR="$AISTUFF_DIR/skills"
AGENTS_FILE="$SKILLS_DIR/.agents"
IGNORE_PROFILES_DIR="$DOTFILES_DIR/stow-ignores"

# ── pick an ignore profile ────────────────────────────────────────────────────
# Must match the profile used when stowing, or -D won't compute the same
# symlink set and can miscount what to remove.
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
    choice="$(printf '%s\n' "${profiles[@]}" | fzf --prompt="stow-ignore profile> " --height=~40% --border --header="Which profile did you stow with? (Esc to abort)")"
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

# ── parse .agents line ────────────────────────────────────────────────────────
parse_agent_line() {
  local line="$1"
  AGENT_NAME="$(awk '{print $1}' <<< "$line")"
  AGENT_SKILLS_PATH="$(awk '{print $2}' <<< "$line")"
  AGENT_SKILLS_PATH="${AGENT_SKILLS_PATH/#\~/$HOME}"
  AGENT_INSTRUCTION_LINK="$(awk '{print $3}' <<< "$line")"
  AGENT_INSTRUCTION_LINK="${AGENT_INSTRUCTION_LINK/#\~/$HOME}"
}

# ── remove instruction files ──────────────────────────────────────────────────
remove_instructions() {
  if [[ ! -f "$AGENTS_FILE" ]]; then
    return
  fi

  local entries=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    parse_agent_line "$line"

    [[ -z "$AGENT_INSTRUCTION_LINK" || "$AGENT_INSTRUCTION_LINK" == "-" ]] && continue

    if [[ -f "$AGENT_INSTRUCTION_LINK" ]]; then
      rm "$AGENT_INSTRUCTION_LINK"
      entries+=("$AGENT_NAME")
    fi
  done < "$AGENTS_FILE"

  local joined
  joined="$(IFS=$','; echo "${entries[*]}" | sed 's/,/, /g')"
  echo "[instructions] removed: $joined"
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

# ── unstow packages ───────────────────────────────────────────────────────────
unstow_packages() {
  cd "$DOTFILES_DIR"
  get_stow_ignore_flags
  echo "[stow] Unstowing dotfiles..."
  stow "${STOW_IGNORE_FLAGS[@]}" -Dvt ~ .
}

select_ignore_profile
remove_instructions
remove_skills
unstow_packages
