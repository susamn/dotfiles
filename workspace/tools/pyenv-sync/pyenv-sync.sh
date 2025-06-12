#!/usr/bin/env bash

set -euo pipefail

# Configuration
PYENV_SYNC_DIR="$TOOLS_PATH/pyenv-sync"
PYTHON_VERSIONS_FILE="$PYENV_SYNC_DIR/python_versions.txt"
PLUGINS_FILE="$PYENV_SYNC_DIR/plugins.txt"
VENV_CONFIG="$PYENV_SYNC_DIR/virtualenvs.yaml"
REQS_DIR="$PYENV_SYNC_DIR/requirements"
PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
PATH="$PYENV_ROOT/bin:$PATH"

# Load pyenv
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# Check tools
check_requirements() {
  for cmd in git pyenv yq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "❌ $cmd is required but not installed."
      exit 1
    fi
  done
}

install_plugins() {
  echo "📦 Installing pyenv plugins..."
  mkdir -p "$PYENV_ROOT/plugins"
  while read -r plugin; do
    [ -z "$plugin" ] && continue
    [ -d "$PYENV_ROOT/plugins/$plugin" ] || \
      git clone "https://github.com/pyenv/$plugin.git" "$PYENV_ROOT/plugins/$plugin"
  done < "$PLUGINS_FILE"
}

install_python_versions() {
  echo "🐍 Installing Python versions from dotfiles..."
  while read -r version; do
    [ -z "$version" ] && continue
    if ! pyenv versions --bare | grep -Fxq "$version"; then
      pyenv install -s "$version"
    else
      echo "✅ Python $version already installed"
    fi
  done < "$PYTHON_VERSIONS_FILE"
}

create_or_sync_envs() {
  echo "🔁 Syncing only dotfiles-managed virtualenvs..."
  local envs
  envs=$(yq e 'keys | .[]' "$VENV_CONFIG")

  for env in $envs; do
    local py req_file env_exists
    py=$(yq e ".\"$env\".python" "$VENV_CONFIG")
    req_file=$(yq e ".\"$env\".requirements" "$VENV_CONFIG")
    env_exists=$(pyenv virtualenvs --bare | grep -Fx "$env" || true)

    if [ -z "$env_exists" ]; then
      echo "➕ Creating virtualenv '$env' (Python $py)"
      pyenv virtualenv "$py" "$env"
    else
      echo "✅ Virtualenv '$env' already exists"
    fi

    echo "📂 Syncing dependencies for $env"
    pyenv activate "$env"

    # Get currently installed packages (names only, lowercase)
    local installed_packages=()
    while IFS= read -r line; do
      pkg=$(echo "$line" | cut -d= -f1 | tr '[:upper:]' '[:lower:]')
      installed_packages+=("$pkg")
    done < <(pip freeze)

    # Prepare to rebuild filtered requirements list
    local deps_to_keep=()

    while IFS= read -r pkg_line; do
      [ -z "$pkg_line" ] && continue
      current_pkg=$(echo "$pkg_line" | cut -d= -f1 | tr '[:upper:]' '[:lower:]')
      if printf '%s\n' "${installed_packages[@]}" | grep -qx "$current_pkg"; then
        deps_to_keep+=("$pkg_line")
      else
        echo "❓ I see '$current_pkg' is missing in env '$env'. Remove from $req_file? [y/N]"
        read -r answer < /dev/tty
        if [[ "$answer" =~ ^[Yy]$ ]]; then
          echo "🗑️ Removing $current_pkg from $req_file"
          continue
        fi
        echo "✅ Keeping $current_pkg in $req_file"
        deps_to_keep+=("$pkg_line")
      fi
    done < "$REQS_DIR/$req_file"

    # Write updated list to requirements file
    printf "%s\n" "${deps_to_keep[@]}" > "$REQS_DIR/$req_file"

    # Install missing ones
    for line in "${deps_to_keep[@]}"; do
      pkg=$(echo "$line" | cut -d= -f1 | tr '[:upper:]' '[:lower:]')
      if ! printf '%s\n' "${installed_packages[@]}" | grep -qx "$pkg"; then
        echo "📥 Installing $line"
        pip install "$line"
      fi
    done

    # 🔍 Check for extra manually installed packages
    echo "🔍 Checking for manually installed packages not in $req_file..."
    local req_names=()
    while IFS= read -r req_line; do
      [ -z "$req_line" ] && continue
      req_pkg=$(echo "$req_line" | cut -d= -f1 | tr '[:upper:]' '[:lower:]')
      req_names+=("$req_pkg")
    done < "$REQS_DIR/$req_file"

    final_installed=()
    while IFS= read -r line; do
      final_installed+=("$(echo "$line" | cut -d= -f1 | tr '[:upper:]' '[:lower:]')")
    done < <(pip freeze)

    for installed_pkg in "${final_installed[@]}"; do
      if ! printf '%s\n' "${req_names[@]}" | grep -qx "$installed_pkg"; then
        version_line=$(pip freeze | grep -i "^$installed_pkg==")
        echo "❓ You manually installed '$installed_pkg'. Add to $req_file? [y/N]"
        read -r answer < /dev/tty
        if [[ "$answer" =~ ^[Yy]$ ]]; then
          echo "$version_line" >> "$REQS_DIR/$req_file"
          echo "📝 Added $version_line to $req_file"
        else
          echo "⚠️  Skipping $installed_pkg"
        fi
      fi
    done

    pyenv deactivate
  done
}


show_info() {
  echo "ℹ️ PYENV SYSTEM INFO"
  echo

  echo "🔧 Installed Python versions:"
  pyenv versions --bare | grep -E '^[0-9]' || echo "(none)"
  echo

  echo "🧪 Virtualenvs on this system:"
  local envs_raw
  envs_raw=$(pyenv virtualenvs --bare 2>/dev/null || echo "")
  if [ -z "$envs_raw" ]; then
    echo "(none)"
  else
    local envs_clean=()
    while IFS= read -r env; do
      name="${env##*/}"  # strip any prefix (e.g., 3.12.2/envs/foo → foo)
      envs_clean+=("$name")
    done <<< "$envs_raw"

    # Deduplicate and sort
    printf '%s\n' "${envs_clean[@]}" | sort -u
  fi
  echo

  echo "📄 Dotfiles-configured Python versions:"
  cat "$PYTHON_VERSIONS_FILE" || echo "(none)"
  echo

  echo "📄 Dotfiles-configured virtualenvs:"
  yq e 'keys | .[]' "$VENV_CONFIG" || echo "(none)"
}

add_new_envs() {
  check_requirements

  echo "🔎 Finding unmanaged pyenv virtualenvs on this system..."

  # Collect all envs
  all_envs=()
  while IFS= read -r line; do
    all_envs+=("$line")
  done < <(pyenv virtualenvs --bare | sort -u)

  # Managed envs from yaml
  managed_envs=()
  if [[ -f "$VENV_CONFIG" ]]; then
    while IFS= read -r line; do
      managed_envs+=("$line")
    done < <(yq e 'keys | .[]' "$VENV_CONFIG" 2>/dev/null || echo "")
  fi

  # Find unmanaged
  unmanaged_envs=()
  for env in "${all_envs[@]}"; do
    found=0
    for managed in "${managed_envs[@]}"; do
      if [[ "$env" == "$managed" ]]; then
        found=1
        break
      fi
    done
    if [[ $found -eq 0 ]]; then
      unmanaged_envs+=("$env")
    fi
  done

  if [[ ${#unmanaged_envs[@]} -eq 0 ]]; then
    echo "✅ No unmanaged virtualenvs found."
    return
  fi

  echo "Unmanaged virtualenvs:"
  for i in "${!unmanaged_envs[@]}"; do
    echo "  [$((i+1))] ${unmanaged_envs[i]}"
  done

  echo
  echo "Enter the numbers of virtualenvs to add (e.g. '1 2'):"
  read -r -a choices < /dev/tty

  if [[ ${#choices[@]} -eq 0 ]]; then
    echo "No selection made."
    return
  fi

  # Fallback for python version
  get_latest_python_version() {
    latest=""
    while IFS= read -r line; do
      latest="$line"
    done < <(pyenv versions --bare | grep -E '^[0-9]' | sort -V)
    echo "$latest"
  }

  mkdir -p "$REQS_DIR"

  for idx in "${choices[@]}"; do
    if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 || idx > ${#unmanaged_envs[@]} )); then
      echo "⚠️ Invalid selection: $idx"
      continue
    fi

    env_name="${unmanaged_envs[$((idx-1))]}"
    echo "➕ Adding '$env_name'..."

    detected_py=""
    while IFS= read -r line; do
      if pyenv virtualenvs --bare | grep -qx "$line/envs/$env_name"; then
        detected_py="$line"
        break
      fi
    done < <(pyenv versions --bare | grep -E '^[0-9]')

    if [[ -z "$detected_py" ]]; then
      detected_py=$(get_latest_python_version)
      echo "⚠️ Could not detect Python version. Using latest: $detected_py"
    fi

    req_file="$env_name"

    [[ ! -f "$VENV_CONFIG" ]] && echo "{}" > "$VENV_CONFIG"
    yq e -i ".\"$env_name\" = {python: \"$detected_py\", requirements: \"$req_file\"}" "$VENV_CONFIG"

    if [[ ! -f "$REQS_DIR/$req_file" ]]; then
      echo "# Requirements for $env_name" > "$REQS_DIR/$req_file"
      echo "📝 Created $REQS_DIR/$req_file"
    fi

    echo "✅ Done adding '$env_name'"
  done
}



# Extend main to support add:
main() {
  case "${1:-}" in
    init)
      echo "🚀 Initializing pyenv from dotfiles..."
      check_requirements
      install_plugins
      install_python_versions
      create_or_sync_envs
      ;;
    sync)
      echo "🔄 Syncing dotfiles-tracked dependencies into virtualenvs..."
      check_requirements
      create_or_sync_envs
      ;;
    add)
      add_new_envs
      ;;
    info)
      check_requirements
      show_info
      ;;
    *)
      echo "Usage: $0 [init|sync|add|info]"
      exit 1
      ;;
  esac
}

main "$@"
