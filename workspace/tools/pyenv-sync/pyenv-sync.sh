#!/usr/bin/env bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
LIGHT_GREEN='\033[1;32m'
LIGHT_YELLOW='\033[1;33m'
LIGHT_RED='\033[1;31m'
LIGHT_GRAY='\033[1;37m'
NC='\033[0m'

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

# Ensure pyenv-virtualenv is installed
PYENV_VIRTUALENV_INSTALLED=false
if [ ! -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]; then
  echo "📦 Installing pyenv-virtualenv plugin..."
  git clone https://github.com/pyenv/pyenv-virtualenv.git "$PYENV_ROOT/plugins/pyenv-virtualenv"
  PYENV_VIRTUALENV_INSTALLED=true
fi

eval "$(pyenv virtualenv-init -)"

# Show shell configuration reminder if we just installed pyenv-virtualenv
if [ "$PYENV_VIRTUALENV_INSTALLED" = true ]; then
  echo ""
  echo "╔════════════════════════════════════════════════════════════════════════════╗"
  echo "║                        ⚠️  SHELL CONFIGURATION NEEDED                       ║"
  echo "╚════════════════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "  pyenv-virtualenv was just installed. You need to add pyenv initialization"
  echo "  to your shell configuration:"
  echo ""
  echo "  For bash (~/.bashrc):"
  echo "  ────────────────────────────────────────────────────────────────────────"
  echo "    export PYENV_ROOT=\"\$HOME/.pyenv\""
  echo "    export PATH=\"\$PYENV_ROOT/bin:\$PATH\""
  echo "    eval \"\$(pyenv init -)\""
  echo "    eval \"\$(pyenv virtualenv-init -)\""
  echo ""
  echo "  For zsh (~/.zshrc):"
  echo "  ────────────────────────────────────────────────────────────────────────"
  echo "    export PYENV_ROOT=\"\$HOME/.pyenv\""
  echo "    export PATH=\"\$PYENV_ROOT/bin:\$PATH\""
  echo "    eval \"\$(pyenv init -)\""
  echo "    eval \"\$(pyenv virtualenv-init -)\""
  echo ""
  echo "  After adding these lines:"
  echo "  ────────────────────────────────────────────────────────────────────────"
  echo "    • Restart your shell, or"
  echo "    • Run: source ~/.bashrc (or source ~/.zshrc)"
  echo ""
  echo "╚════════════════════════════════════════════════════════════════════════════╝"
  echo ""
fi

# Check tools
check_requirements() {
  for cmd in git pyenv yq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo -e "${RED}❌ $cmd${NC} is required but not installed."
      exit 1
    fi
  done
}

install_plugins() {
  echo -e "${CYAN}\033[4m📦 Pyenv Plugins\033[0m${NC}"
  mkdir -p "$PYENV_ROOT/plugins"
  while read -r plugin; do
    [ -z "$plugin" ] && continue
    if [ -d "$PYENV_ROOT/plugins/$plugin" ]; then
      echo -e "  ${GRAY}• ${plugin}${NC} ${GRAY}(already installed)${NC}"
    else
      echo -e "  ${LIGHT_GREEN}• Installing ${plugin}${NC}"
      git clone "https://github.com/pyenv/$plugin.git" "$PYENV_ROOT/plugins/$plugin" 2>/dev/null
    fi
  done < "$PLUGINS_FILE"
  echo
}

install_python_versions() {
  echo -e "${CYAN}\033[4m🐍 Python Versions\033[0m${NC}"
  while read -r version; do
    [ -z "$version" ] && continue
    if ! pyenv versions --bare | grep -Fxq "$version"; then
      echo -e "  ${LIGHT_GREEN}• Installing Python ${version}${NC}"
      pyenv install -s "$version"
    else
      echo -e "  ${GRAY}• Python ${version}${NC} ${GRAY}(already installed)${NC}"
    fi
  done < "$PYTHON_VERSIONS_FILE"
  echo
}

create_or_sync_envs() {
  echo -e "${CYAN}\033[4m🔁 Virtualenvs\033[0m${NC}"
  local envs
  envs=$(yq e 'keys | .[]' "$VENV_CONFIG")

  for env in $envs; do
    local py req_file env_exists
    py=$(yq e ".\"$env\".python" "$VENV_CONFIG")
    req_file=$(yq e ".\"$env\".requirements" "$VENV_CONFIG")
    env_exists=$(pyenv virtualenvs --bare | grep -Fx "$env" || true)

    echo
    echo -e "${MAGENTA}  • ${env}${NC} ${GRAY}(Python ${py})${NC}"

    if [ -z "$env_exists" ]; then
      echo -e "     ${GREEN}└─${NC} Creating virtualenv"
      pyenv virtualenv "$py" "$env"
    else
      echo -e "     ${GREEN}└─${NC} ${GRAY}Already exists${NC}"
    fi

    echo -e "     ${GREEN}└─${NC} Syncing dependencies"
    export PYENV_VERSION="$env"

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
        echo -e "         ${YELLOW}❓${NC} Package '${current_pkg}' missing. Remove from ${req_file}? [y/N]"
        read -r answer < /dev/tty
        if [[ "$answer" =~ ^[Yy]$ ]]; then
          echo -e "         ${RED}🗑️${NC}  Removing ${current_pkg}"
          continue
        fi
        echo -e "         ${GREEN}✓${NC} Keeping ${current_pkg}"
        deps_to_keep+=("$pkg_line")
      fi
    done < "$REQS_DIR/$req_file"

    # Write updated list to requirements file
    printf "%s\n" "${deps_to_keep[@]}" > "$REQS_DIR/$req_file"

    # Install missing ones
    for line in "${deps_to_keep[@]}"; do
      pkg=$(echo "$line" | cut -d= -f1 | tr '[:upper:]' '[:lower:]')
      if ! printf '%s\n' "${installed_packages[@]}" | grep -qx "$pkg"; then
        echo -e "         ${LIGHT_GREEN}📥${NC} Installing ${line}"
        pip install "$line"
      fi
    done

    # 🔍 Check for extra manually installed packages
    echo -e "     ${GREEN}└─${NC} Checking for manually installed packages"
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
        echo -e "         ${YELLOW}❓${NC} Found manually installed '${installed_pkg}'. Add to ${req_file}? [y/N]"
        read -r answer < /dev/tty
        if [[ "$answer" =~ ^[Yy]$ ]]; then
          echo "$version_line" >> "$REQS_DIR/$req_file"
          echo -e "         ${GREEN}📝${NC} Added ${version_line}"
        else
          echo -e "         ${GRAY}⚠️${NC}  Skipping ${installed_pkg}"
        fi
      fi
    done

    unset PYENV_VERSION
  done
  echo
}


show_info() {
  echo -e "${MAGENTA}ℹ️  PYENV SYSTEM INFO${NC}"
  echo

  echo -e "${CYAN}\033[4m🔧 Installed Python Versions\033[0m${NC}"
  if pyenv versions --bare | grep -E '^[0-9]' >/dev/null 2>&1; then
    while IFS= read -r version; do
      echo -e "  ${LIGHT_GREEN}• ${version}${NC}"
    done < <(pyenv versions --bare | grep -E '^[0-9]')
  else
    echo -e "  ${GRAY}(none)${NC}"
  fi
  echo

  echo -e "${CYAN}\033[4m🧪 Virtualenvs on This System\033[0m${NC}"
  local envs_raw
  envs_raw=$(pyenv virtualenvs --bare 2>/dev/null || echo "")
  if [ -z "$envs_raw" ]; then
    echo -e "  ${GRAY}(none)${NC}"
  else
    local envs_clean=()
    while IFS= read -r env; do
      name="${env##*/}"  # strip any prefix (e.g., 3.12.2/envs/foo → foo)
      envs_clean+=("$name")
    done <<< "$envs_raw"

    # Deduplicate and sort
    while IFS= read -r env; do
      echo -e "  ${LIGHT_YELLOW}• ${env}${NC}"
    done < <(printf '%s\n' "${envs_clean[@]}" | sort -u)
  fi
  echo

  echo -e "${CYAN}\033[4m📄 Dotfiles-Configured Python Versions\033[0m${NC}"
  if [ -s "$PYTHON_VERSIONS_FILE" ]; then
    while IFS= read -r version; do
      [ -z "$version" ] && continue
      echo -e "  ${LIGHT_GREEN}• ${version}${NC}"
    done < "$PYTHON_VERSIONS_FILE"
  else
    echo -e "  ${GRAY}(none)${NC}"
  fi
  echo

  echo -e "${CYAN}\033[4m📄 Dotfiles-Configured Virtualenvs\033[0m${NC}"
  if [ -f "$VENV_CONFIG" ]; then
    local configured_envs
    configured_envs=$(yq e 'keys | .[]' "$VENV_CONFIG" 2>/dev/null || echo "")
    if [ -z "$configured_envs" ]; then
      echo -e "  ${GRAY}(none)${NC}"
    else
      while IFS= read -r env; do
        echo -e "  ${MAGENTA}• ${env}${NC}"
      done <<< "$configured_envs"
    fi
  else
    echo -e "  ${GRAY}(none)${NC}"
  fi
}

add_new_envs() {
  check_requirements

  echo -e "${CYAN}\033[4m🔎 Finding Unmanaged Virtualenvs\033[0m${NC}"
  echo

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
    echo -e "  ${GREEN}✓ No unmanaged virtualenvs found${NC}"
    echo
    return
  fi

  echo -e "${YELLOW}Unmanaged virtualenvs:${NC}"
  for i in "${!unmanaged_envs[@]}"; do
    echo -e "  ${LIGHT_YELLOW}[$((i+1))]${NC} ${unmanaged_envs[i]}"
  done

  echo
  echo -e "${CYAN}Enter the numbers of virtualenvs to add (e.g. '1 2'):${NC}"
  read -r -a choices < /dev/tty

  if [[ ${#choices[@]} -eq 0 ]]; then
    echo -e "${GRAY}No selection made.${NC}"
    echo
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
  echo

  for idx in "${choices[@]}"; do
    if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 || idx > ${#unmanaged_envs[@]} )); then
      echo -e "${RED}⚠️  Invalid selection: ${idx}${NC}"
      continue
    fi

    env_name="${unmanaged_envs[$((idx-1))]}"
    echo -e "${MAGENTA}➕ Adding '${env_name}'${NC}"

    detected_py=""
    while IFS= read -r line; do
      if pyenv virtualenvs --bare | grep -qx "$line/envs/$env_name"; then
        detected_py="$line"
        break
      fi
    done < <(pyenv versions --bare | grep -E '^[0-9]')

    if [[ -z "$detected_py" ]]; then
      detected_py=$(get_latest_python_version)
      echo -e "   ${YELLOW}└─${NC} Could not detect Python version. Using latest: ${detected_py}"
    else
      echo -e "   ${GREEN}└─${NC} Detected Python ${detected_py}"
    fi

    req_file="$env_name"

    [[ ! -f "$VENV_CONFIG" ]] && echo "{}" > "$VENV_CONFIG"
    yq e -i ".\"$env_name\" = {python: \"$detected_py\", requirements: \"$req_file\"}" "$VENV_CONFIG"

    if [[ ! -f "$REQS_DIR/$req_file" ]]; then
      echo "# Requirements for $env_name" > "$REQS_DIR/$req_file"
      echo -e "   ${GREEN}└─${NC} Created requirements file"
    fi

    echo -e "   ${GREEN}✓${NC} Done"
    echo
  done
}



# Extend main to support add:
main() {
  case "${1:-}" in
    init)
      echo -e "${MAGENTA}🚀 Initializing pyenv from dotfiles${NC}"
      echo
      check_requirements
      install_plugins
      install_python_versions
      create_or_sync_envs
      echo -e "${GREEN}✓ Initialization complete${NC}"
      echo
      ;;
    sync)
      echo -e "${MAGENTA}🔄 Syncing virtualenv dependencies${NC}"
      echo
      check_requirements
      create_or_sync_envs
      echo -e "${GREEN}✓ Sync complete${NC}"
      echo
      ;;
    add)
      add_new_envs
      ;;
    info)
      check_requirements
      show_info
      ;;
    *)
      echo -e "${RED}Usage:${NC} $0 ${CYAN}[init|sync|add|info]${NC}"
      echo
      echo -e "  ${CYAN}init${NC}  - Initial setup: install plugins, Python versions, and virtualenvs"
      echo -e "  ${CYAN}sync${NC}  - Sync dependencies from requirements files into virtualenvs"
      echo -e "  ${CYAN}add${NC}   - Add unmanaged pyenv virtualenvs to dotfiles tracking"
      echo -e "  ${CYAN}info${NC}  - Show system info (Python versions, virtualenvs, config)"
      echo
      exit 1
      ;;
  esac
}

main "$@"
