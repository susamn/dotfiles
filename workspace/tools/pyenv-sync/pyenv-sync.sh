#!/usr/bin/env bash

set -euo pipefail

# Modern Palette
RED='\033[38;5;196m'
GREEN='\033[38;5;46m'
YELLOW='\033[38;5;226m'
BLUE='\033[38;5;33m'
CYAN='\033[38;5;51m'
MAGENTA='\033[38;5;201m'
GRAY='\033[38;5;244m'
WHITE='\033[38;5;255m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

PYENV_SYNC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQS_DIR="$PYENV_SYNC_DIR/requirements"
PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"

# UI Helpers
print_banner() {
  echo ""
  echo -e "${CYAN}╭────────────────────────────────────────────────────────────╮${NC}"
  echo -e "${CYAN}│${NC}  ${BOLD}${MAGENTA}🚀 pyenv-sync${NC} ${DIM}v2.0${NC}                                        ${CYAN}│${NC}"
  echo -e "${CYAN}╰────────────────────────────────────────────────────────────╯${NC}"
  echo ""
}

print_header() {
  echo -e "${CYAN}╭─ ${BOLD}$1${NC}"
}

print_step() {
  echo -e "${CYAN}│${NC}  $1"
}

print_success() {
  echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} $1"
}

print_warn() {
  echo -e "${CYAN}│${NC}  ${YELLOW}⚠${NC} $1"
}

print_error() {
  echo -e "${CYAN}│${NC}  ${RED}✗${NC} $1"
}

print_footer() {
  echo -e "${CYAN}╰────────────────────────────────────────────────────────────╯${NC}\n"
}

install_pyenv() {
  print_step "Checking pyenv installation..."
  if command -v pyenv &>/dev/null || [ -d "$HOME/.pyenv" ]; then
    print_success "pyenv is already installed."
  else
    print_warn "pyenv is not installed. Installing via curl..."
    if curl -s https://pyenv.run | bash > /dev/null 2>&1; then
      print_success "pyenv installed successfully via pyenv.run."
    else
      print_warn "pyenv.run failed. Trying via brew..."
      if command -v brew &>/dev/null; then
        brew install pyenv > /dev/null 2>&1
        print_success "pyenv installed successfully via brew."
      else
        print_error "brew not found. Please install pyenv manually."
        exit 1
      fi
    fi
  fi
  
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)" || true
}

install_pyenv_virtualenv() {
  print_step "Checking pyenv-virtualenv..."
  if [ -d "$HOME/.pyenv/plugins/pyenv-virtualenv" ] || (command -v brew &>/dev/null && brew list pyenv-virtualenv &>/dev/null); then
    print_success "pyenv-virtualenv is already installed."
  else
    print_warn "pyenv-virtualenv not installed. Installing..."
    if command -v brew &>/dev/null && brew list pyenv &>/dev/null; then
       brew install pyenv-virtualenv > /dev/null 2>&1
    else
       git clone https://github.com/pyenv/pyenv-virtualenv.git "$HOME/.pyenv/plugins/pyenv-virtualenv" -q
    fi
    print_success "pyenv-virtualenv installed."
  fi
  eval "$(pyenv virtualenv-init -)" || true
}

install_python() {
  print_step "Checking for base Python version..."
  if ! command -v python3 &>/dev/null && ! pyenv versions --bare | grep -q '^[0-9]'; then
    print_warn "No python versions found."
    echo -e "${CYAN}│${NC}  Available pyenv versions (latest 10):"
    pyenv install --list | grep -E '^\s*[0-9]' | tail -n 10 | sed "s/^/│    /"
    echo -n -e "${CYAN}│${NC}  ${MAGENTA}Enter python version to install (e.g., 3.12.2):${NC} "
    read -r py_version < /dev/tty
    if [ -n "$py_version" ]; then
      print_step "Installing Python $py_version..."
      pyenv install "$py_version"
      pyenv global "$py_version"
      print_success "Python $py_version installed and set as global default."
    else
      print_error "No version selected. Skipping."
    fi
  else
    print_success "Python is available."
  fi
}

install_uv() {
  print_step "Checking uv installation..."
  if command -v uv &>/dev/null; then
    print_success "uv is already installed."
  else
    print_warn "uv is not installed. Installing via curl..."
    if curl -LsSf https://astral.sh/uv/install.sh | sh > /dev/null 2>&1; then
      print_success "uv installed successfully."
      # Temporary path update for this session so we can use it immediately
      export PATH="$HOME/.local/bin:$PATH"
    else
      print_warn "uv installation failed. Falling back to standard pip."
    fi
  fi
}

cmd_init() {
  print_banner
  print_header "Initialization"
  install_pyenv
  install_pyenv_virtualenv
  install_python
  install_uv
  print_footer

  echo -e "${YELLOW}╭────────────────────────────────────────────────────────────╮${NC}"
  echo -e "${YELLOW}│${NC}               ${BOLD}⚠️  SHELL CONFIGURATION NEEDED${NC}               ${YELLOW}│${NC}"
  echo -e "${YELLOW}╰────────────────────────────────────────────────────────────╯${NC}"
  echo -e "  Please add the following to your ${BOLD}~/.bashrc${NC} or ${BOLD}~/.zshrc${NC}:"
  echo ""
  echo -e "  ${GRAY}# pyenv-sync initialization${NC}"
  echo -e "  ${WHITE}export PYENV_ROOT=\"\$HOME/.pyenv\"${NC}"
  echo -e "  ${WHITE}export PATH=\"\$PYENV_ROOT/bin:\$HOME/.local/bin:\$PATH\"${NC}"
  echo -e "  ${WHITE}eval \"\$(pyenv init -)\"${NC}"
  echo -e "  ${WHITE}eval \"\$(pyenv virtualenv-init -)\"${NC}"
  echo ""
  echo -e "  ${WHITE}pnv() {${NC}"
  echo -e "  ${WHITE}  if [ \"\$1\" = \"activate\" ] || [ \"\$1\" = \"-a\" ]; then${NC}"
  echo -e "  ${WHITE}    if [ -z \"\$2\" ]; then${NC}"
  echo -e "  ${WHITE}      if command -v fzf &>/dev/null; then${NC}"
  echo -e "  ${WHITE}        local selected_env=\$(pyenv virtualenvs --bare | fzf --prompt=\"Select env> \" --height=10 --reverse)${NC}"
  echo -e "  ${WHITE}        if [ -n \"\$selected_env\" ]; then${NC}"
  echo -e "  ${WHITE}          pyenv activate \"\$selected_env\"${NC}"
  echo -e "  ${WHITE}        fi${NC}"
  echo -e "  ${WHITE}      else${NC}"
  echo -e "  ${WHITE}        echo \"Usage: pnv activate <env_name> (install fzf for interactive selection)\"${NC}"
  echo -e "  ${WHITE}        return 1${NC}"
  echo -e "  ${WHITE}      fi${NC}"
  echo -e "  ${WHITE}    else${NC}"
  echo -e "  ${WHITE}      pyenv activate \"\$2\"${NC}"
  echo -e "  ${WHITE}    fi${NC}"
  echo -e "  ${WHITE}  elif [ \"\$1\" = \"deactivate\" ] || [ \"\$1\" = \"-d\" ]; then${NC}"
  echo -e "  ${WHITE}    pyenv deactivate${NC}"
  echo -e "  ${WHITE}  else${NC}"
  echo -e "  ${WHITE}    bash \"$PYENV_SYNC_DIR/pyenv-sync.sh\" \"\$@\"${NC}"
  echo -e "  ${WHITE}  fi${NC}"
  echo -e "  ${WHITE}}${NC}"
  echo ""
  echo -e "  ${DIM}After adding this, restart your shell or run: source ~/.bashrc${NC}\n"
}

cmd_sync_env_to_repo() {
  print_header "Syncing TO Repository"
  print_step "Current active environment: ${MAGENTA}$PYENV_VERSION${NC}"
  local req_file="$REQS_DIR/$PYENV_VERSION.txt"
  local py_version
  py_version=$(pyenv version-name | sed -e "s/:.*//")
  
  local header="# python=$py_version"
  echo "$header" > "$req_file"

  # Use uv if available, otherwise pip
  if command -v uv &>/dev/null; then
    print_step "Using ${CYAN}uv${NC} for freezing dependencies..."
    # uv pip requires the python executable or activating the env. 
    # To be safe globally, we'll explicitly pass the pyenv python executable.
    local py_exec
    py_exec="$(pyenv prefix "$PYENV_VERSION")/bin/python"
    uv pip freeze --python "$py_exec" >> "$req_file"
  else
    print_step "uv not found, using standard ${CYAN}pip${NC}..."
    pip freeze >> "$req_file"
  fi
  
  print_success "Dependencies successfully written to ${WHITE}$(basename "$req_file")${NC}"
  print_footer
}

cmd_sync_repo_to_envs() {
  print_header "Syncing FROM Repository"
  if [ ! -d "$REQS_DIR" ] || [ -z "$(ls -A "$REQS_DIR" 2>/dev/null)" ]; then
    print_warn "No requirements files found in $REQS_DIR."
    print_footer
    return 0
  fi
  
  local global_py
  global_py=$(pyenv global 2>/dev/null || echo "system")
  
  for req_file in "$REQS_DIR"/*.txt; do
    [ -e "$req_file" ] || continue
    local env_name="$(basename "$req_file" .txt)"
    
    echo -e "${CYAN}│${NC}"
    print_step "${BOLD}Processing Env: ${MAGENTA}$env_name${NC}"
    
    local py_version="$global_py"
    local header
    header=$(grep -m 1 "^# python=" "$req_file" || true)
    if [ -n "$header" ]; then
      py_version="${header#*python=}"
    fi
    py_version=$(echo "$py_version" | tr -d '\r')
    
    # Check if env exists by checking the directory inside $PYENV_ROOT/versions
    if [ ! -d "$PYENV_ROOT/versions/$env_name" ]; then
      print_warn "Virtualenv missing. Creating with Python ${YELLOW}$py_version${NC}..."
      if [ "$py_version" != "system" ] && ! pyenv versions --bare | grep -Fxq "$py_version"; then
        print_step "Python $py_version not found locally. Installing..."
        pyenv install "$py_version" || {
          print_error "Failed to install Python $py_version. Skipping $env_name."
          continue
        }
      fi
      pyenv virtualenv "$py_version" "$env_name" > /dev/null 2>&1 || {
        print_error "Failed to create virtualenv $env_name. Skipping."
        continue
      }
      print_success "Virtualenv created."
    else
      print_step "Virtualenv ${GREEN}$env_name${NC} exists."
    fi
    
    # Determine if uv is available for installation
    local use_uv=false
    local py_exec=""
    if command -v uv &>/dev/null; then
      use_uv=true
      print_step "Using ${CYAN}uv${NC} for package syncing..."
      py_exec="$(pyenv prefix "$env_name")/bin/python"
    else
      print_step "uv not found, using standard ${CYAN}pip${NC}..."
    fi

    print_step "Synchronizing packages..."
    local installed_count=0
    # Read requirements line by line
    while IFS= read -r pkg || [ -n "$pkg" ]; do
      [[ -z "$pkg" || "$pkg" == \#* ]] && continue
      pkg=$(echo "$pkg" | tr -d '\r')
      
      # Install only if not installed
      local is_installed=false
      if [ "$use_uv" = true ]; then
         if uv pip freeze --python "$py_exec" | grep -i "^${pkg%%==*}===" &>/dev/null || \
            uv pip freeze --python "$py_exec" | grep -i "^${pkg%%==*}=" &>/dev/null; then
            is_installed=true
         fi
      else
         if PYENV_VERSION="$env_name" pyenv exec pip freeze | grep -i "^${pkg%%==*}===" &>/dev/null || \
            PYENV_VERSION="$env_name" pyenv exec pip freeze | grep -i "^${pkg%%==*}=" &>/dev/null; then
            is_installed=true
         fi
      fi

      if [ "$is_installed" = false ]; then
         echo -e "${CYAN}│${NC}    ${DIM}Installing $pkg...${NC}"
         if [ "$use_uv" = true ]; then
            if uv pip install --python "$py_exec" "$pkg" > /dev/null 2>&1; then
              ((installed_count++))
            else
              echo -e "${CYAN}│${NC}    ${RED}Failed to install $pkg (omitted)${NC}"
            fi
         else
            if PYENV_VERSION="$env_name" pyenv exec pip install "$pkg" > /dev/null 2>&1; then
              ((installed_count++))
            else
              echo -e "${CYAN}│${NC}    ${RED}Failed to install $pkg (omitted)${NC}"
            fi
         fi
      fi
    done < "$req_file"
    
    if [ "$installed_count" -gt 0 ]; then
      print_success "Installed $installed_count new packages."
    else
      print_success "All packages up to date."
    fi
  done
  print_footer
}

cmd_sync() {
  print_banner
  mkdir -p "$REQS_DIR"
  if [ -n "${PYENV_VERSION:-}" ]; then
    cmd_sync_env_to_repo
  fi
  cmd_sync_repo_to_envs
}

cmd_list() {
  print_banner
  print_header "Python Versions"
  local py_versions
  py_versions=$(pyenv versions --bare | grep -E '^[0-9]' || echo "")
  if [ -n "$py_versions" ]; then
    while IFS= read -r version; do
      print_step "🐍 ${WHITE}$version${NC}"
    done <<< "$py_versions"
  else
    print_step "${DIM}(none installed)${NC}"
  fi
  
  echo -e "${CYAN}│${NC}"
  print_header "Virtual Environments"
  if [ -d "$REQS_DIR" ] && [ "$(ls -A "$REQS_DIR" 2>/dev/null)" ]; then
    # Header format
    printf "${CYAN}│${NC}  %-2s %-15s │ %-10s │ %-20s\n" "" "NAME" "PYTHON" "LAST SYNCED"
    printf "${CYAN}│${NC}  %s\n" "────────────────────┼────────────┼──────────────────────"
    
    for req_file in "$REQS_DIR"/*.txt; do
      [ -e "$req_file" ] || continue
      local env_name="$(basename "$req_file" .txt)"
      local header
      header=$(grep -m 1 "^# python=" "$req_file" || true)
      local py_version="unknown"
      if [ -n "$header" ]; then
        py_version="${header#*python=}"
      fi
      py_version=$(echo "$py_version" | tr -d '\r')
      
      local last_mod
      if echo "$OSTYPE" | grep -q 'darwin'; then
         last_mod=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$req_file" 2>/dev/null || echo "unknown")
      else
         last_mod=$(stat -c "%y" "$req_file" 2>/dev/null | cut -d'.' -f1 || echo "unknown")
      fi
      
      if [ -d "$PYENV_ROOT/versions/$env_name" ]; then
        printf "${CYAN}│${NC}  ${GREEN}%-2s${NC} ${WHITE}%-15s${NC} │ %-10s │ %-20s\n" "✓" "$env_name" "$py_version" "$last_mod"
      else
        printf "${CYAN}│${NC}  ${RED}%-2s${NC} ${GRAY}%-15s${NC} │ ${GRAY}%-10s${NC} │ ${GRAY}%-20s${NC}\n" "✗" "$env_name" "$py_version" "Not Created locally"
      fi
    done
  else
    print_step "${DIM}(no managed environments found)${NC}"
  fi
  print_footer
}

cmd_status() {
  print_banner
  print_header "System Information"
  print_step "Repository Path : ${WHITE}$PYENV_SYNC_DIR${NC}"
  print_step "Requirements Dir: ${WHITE}$REQS_DIR${NC}"
  echo -e "${CYAN}│${NC}"
  if [ -n "${PYENV_VERSION:-}" ]; then
    print_step "Active Env      : ${GREEN}$PYENV_VERSION${NC}"
    if command -v pyenv &>/dev/null; then
      print_step "Python Path     : ${WHITE}$(pyenv which python)${NC}"
    fi
  else
    print_step "Active Env      : ${YELLOW}None${NC}"
    if command -v pyenv &>/dev/null; then
      print_step "Global Python   : ${WHITE}$(pyenv global 2>/dev/null || echo 'system')${NC}"
    fi
  fi
  print_footer
}

case "${1:-}" in
  init|-i) cmd_init ;;
  sync|-s) cmd_sync ;;
  list|-l) cmd_list ;;
  status|-st) cmd_status ;;
  *)
    print_banner
    print_header "Usage"
    print_step "pnv [command]"
    echo -e "${CYAN}│${NC}"
    print_step "${WHITE}init | -i${NC}         - Initialize pyenv, plugins, and setup shell"
    print_step "${WHITE}activate | -a [env]${NC}- Activate virtualenv. Uses fzf if env is omitted"
    print_step "${WHITE}deactivate | -d${NC}   - Deactivate virtualenv"
    print_step "${WHITE}sync | -s${NC}         - Sync packages to/from tracked requirements"
    print_step "${WHITE}list | -l${NC}         - List available Python versions and tracked envs"
    print_step "${WHITE}status | -st${NC}      - Show current environment status"
    print_footer
    exit 1
    ;;
esac
