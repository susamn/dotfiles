#!/usr/bin/env bash
# onboard.sh — Complete setup script to bootstrap a new environment with these dotfiles.
# Supports Pop!_OS/Ubuntu/Debian, Arch Linux, Fedora/RHEL, and macOS.
#
# Usage:
#   ./onboard.sh
#

set -euo pipefail

# --- LOGGING UTILITIES ----------------------------------
log() {
  echo -e "\033[1;32m[INFO]\033[0m $1"
}

warn() {
  echo -e "\033[1;33m[WARN]\033[0m $1"
}

error() {
  echo -e "\033[1;31m[ERROR]\033[0m $1"
  exit 1
}

# --- PORTABLE SED FUNCTION ------------------------------
safe_sed() {
  local pattern="$1"
  local file="$2"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i "" "$pattern" "$file"
  else
    sed -i "$pattern" "$file"
  fi
}

# --- 1) OS DETECTION & DEPENDENCIES ---------------------
detect_and_install_dependencies() {
  log "Detecting OS and installing base dependencies..."
  
  if command -v apt-get &>/dev/null; then
    log "Detected Debian/Ubuntu/Pop!_OS (APT)"
    sudo apt-get update
    sudo apt-get install -y zsh curl git stow make build-essential libssl-dev zlib1g-dev \
      libbz2-dev libreadline-dev libsqlite3-dev wget llvm libncursesw5-dev xz-utils \
      tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev python3 python3-pip python3-venv
  elif command -v pacman &>/dev/null; then
    log "Detected Arch Linux (Pacman)"
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm zsh curl git stow base-devel openssl zlib xz tk python python-pip
  elif command -v dnf &>/dev/null; then
    log "Detected Fedora/RHEL (DNF)"
    sudo dnf groupinstall -y "Development Tools"
    sudo dnf install -y zsh curl git stow make gcc zlib-devel bzip2-devel readline-devel \
      sqlite-devel openssl-devel tk-devel libffi-devel xz-devel python3 python3-pip python3-virtualenv
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    log "Detected macOS (Homebrew)"
    if ! xcode-select -p &>/dev/null; then
      log "Installing macOS Command Line Tools..."
      xcode-select --install
      echo "Please complete the Command Line Tools installation dialog, then press Enter to continue..."
      read -r
    fi
  else
    warn "Unsupported or unknown OS. Please ensure zsh, python3, git, stow, and pyenv build dependencies are installed manually."
  fi
}

# --- 2) HOMEBREW INSTALLATION ---------------------------
install_brew() {
  if ! command -v brew &>/dev/null; then
    log "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Load brew env into current session
    if [ -d "/home/linuxbrew/.linuxbrew" ]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [ -d "/opt/homebrew" ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -d "/usr/local/bin" ] && [ -f "/usr/local/bin/brew" ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    log "Homebrew is already installed."
    # Ensure active in current session
    if [ -d "/home/linuxbrew/.linuxbrew" ]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [ -d "/opt/homebrew" ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  fi
}

# --- 3) NVM & STABLE NODE INSTALLATION ------------------
install_nvm_and_node() {
  export NVM_DIR="$HOME/.nvm"
  
  if [ ! -d "$NVM_DIR" ]; then
    log "Installing NVM (Node Version Manager)..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  else
    log "NVM is already installed."
  fi
  
  # Load NVM
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  
  if command -v nvm &>/dev/null; then
    echo ""
    echo "=================================================="
    echo "Node.js Installation Selection"
    echo "=================================================="
    echo "Stable Versions:"
    echo "  1) Node.js Stable/Current (Latest release)"
    echo "  2) Node.js LTS (Long Term Support)"
    echo "Beta / Unstable Versions:"
    echo "  3) Node.js RC (Release Candidate)"
    echo "  4) Node.js Nightly"
    echo "Other Options:"
    echo "  5) Enter specific version manually"
    echo "  6) Skip Node.js installation"
    echo "=================================================="
    read -p "Select options (comma-separated, e.g. 1,2): " node_choices </dev/tty
    node_choices=${node_choices:-1}
    
    local ifs_backup=$IFS
    IFS=','
    local first_installed=""
    local node_install_run=false
    for choice in $node_choices; do
      choice=$(echo "$choice" | xargs)
      local node_ver=""
      case "$choice" in
        1) node_ver="node" ;;
        2) node_ver="--lts" ;;
        3) 
          log "Querying latest Node RC version..."
          node_ver=$(nvm ls-remote --unstable 2>/dev/null | grep -oE "v[0-9\.]+-rc\.[0-9]+" | tail -n 1 || true)
          if [ -z "$node_ver" ]; then
            warn "Could not resolve latest RC version. Skipping."
            continue
          fi
          ;;
        4) 
          node_ver="nightly"
          ;;
        5) 
          read -p "Enter Node version (e.g. 20.11.0): " custom_ver </dev/tty
          node_ver="$custom_ver"
          ;;
        6) 
          log "Skipping Node.js installation."
          IFS=$ifs_backup
          return 0
          ;;
        *)
          warn "Invalid option '$choice'. Skipping."
          continue
          ;;
      esac

      if [ -n "$node_ver" ]; then
        log "Installing Node.js ($node_ver) via NVM..."
        if nvm install "$node_ver"; then
          node_install_run=true
          if [ -z "$first_installed" ]; then
            first_installed="$node_ver"
          fi
        else
          warn "Failed to install Node.js ($node_ver)."
        fi
      fi
    done
    IFS=$ifs_backup

    if [ "$node_install_run" = true ] && [ -n "$first_installed" ]; then
      nvm use "$first_installed"
      nvm alias default "$first_installed"
    fi
  else
    warn "NVM could not be initialized in this session. Skipping Node.js installation."
  fi
}

# --- 4) SDKMAN, JAVA, & MAVEN INSTALLATION --------------
install_sdkman_and_java() {
  export SDKMAN_DIR="$HOME/.sdkman"
  
  if [ ! -d "$SDKMAN_DIR" ]; then
    log "Installing SDKMAN..."
    # Disable auto-modification of rc files since we handle it in our stowed zshrc
    export sdkman_auto_selfupdate=false
    curl -s "https://get.sdkman.io?rcupdate=false" | bash
  else
    log "SDKMAN is already installed."
  fi
  
  # Load SDKMAN
  if [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
  else
    error "SDKMAN initialization file not found at $SDKMAN_DIR/bin/sdkman-init.sh"
  fi
  
  echo ""
  echo "=================================================="
  echo "Java Installation Selection (Amazon Corretto / OpenJDK)"
  echo "=================================================="
  echo "Stable Versions (Amazon Corretto):"
  echo "  1) Java 11 (LTS)"
  echo "  2) Java 17 (LTS)"
  echo "  3) Java 21 (LTS)"
  echo "Beta / Early Access Versions (OpenJDK EA):"
  echo "  4) Java 25 (Early Access)"
  echo "  5) Java 26 (Early Access)"
  echo "  6) Java 27 (Early Access)"
  echo "Other Options:"
  echo "  7) Skip Java installation entirely"
  echo "=================================================="
  read -p "Select options (comma-separated, e.g. 1,3,4): " java_choices </dev/tty
  java_choices=${java_choices:-1,2,3}
  
  local ifs_backup=$IFS
  IFS=','
  local jvers=()
  for choice in $java_choices; do
    choice=$(echo "$choice" | xargs)
    case "$choice" in
      1) jvers+=("11-amzn") ;;
      2) jvers+=("17-amzn") ;;
      3) jvers+=("21-amzn") ;;
      4) jvers+=("25-open") ;;
      5) jvers+=("26-open") ;;
      6) jvers+=("27-open") ;;
      7)
        log "Skipping Java installation."
        IFS=$ifs_backup
        return 0
        ;;
      *)
        warn "Invalid option '$choice'. Skipping."
        ;;
    esac
  done
  IFS=$ifs_backup
  
  for item in "${jvers[@]}"; do
    local jver="${item%-*}"
    local vendor="${item#*-}"
    
    log "Querying latest Java version for Java ${jver} (${vendor})..."
    local full_ver
    full_ver=$(sdk list java 2>/dev/null | grep -oE "[0-9\.]+(\.ea\.[0-9]+)?-${vendor}" | grep "^${jver}\." | sort -V | tail -n 1 || true)
    
    # Fallback to hardcoded defaults if query fails
    if [ -z "$full_ver" ]; then
      case "$item" in
        "11-amzn") full_ver="11.0.22-amzn" ;;
        "17-amzn") full_ver="17.0.10-amzn" ;;
        "21-amzn") full_ver="21.0.2-amzn" ;;
        "25-open") full_ver="25.ea.2-open" ;;
        "26-open") full_ver="26.ea.1-open" ;;
        "27-open") full_ver="27.ea.1-open" ;;
      esac
    fi
    
    if [ -n "$full_ver" ]; then
      if [ ! -d "$SDKMAN_DIR/candidates/java/$full_ver" ]; then
        log "Installing Java $full_ver via SDKMAN..."
        sdk install java "$full_ver"
      else
        log "Java $full_ver is already installed."
      fi
    else
      warn "Could not resolve version for Java ${jver} (${vendor}) in SDKMAN."
    fi
  done
  
  # Install Maven if Java was installed
  if [ ${#jvers[@]} -gt 0 ]; then
    if [ ! -d "$SDKMAN_DIR/candidates/maven/current" ]; then
      log "Installing Maven via SDKMAN..."
      sdk install maven
    else
      log "Maven is already installed."
    fi
  fi
}

# --- 5) PYENV & PYENV-VIRTUALENV INSTALLATION ----------
install_pyenv() {
  export PYENV_ROOT="$HOME/.pyenv"
  
  if [ ! -d "$PYENV_ROOT" ]; then
    log "Installing pyenv..."
    git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
  else
    log "pyenv is already installed."
  fi
  
  if [ ! -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]; then
    log "Installing pyenv-virtualenv..."
    git clone https://github.com/pyenv/pyenv-virtualenv.git "$PYENV_ROOT/plugins/pyenv-virtualenv"
  else
    log "pyenv-virtualenv is already installed."
  fi
  
  # Load pyenv env for compilation
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
  
  # Install requested Python versions (3.11, 3.12, 3.13)
  for pyver in "3.11" "3.12" "3.13"; do
    if ! pyenv versions --bare | grep -q "^${pyver}\."; then
      log "Installing Python ${pyver} (this may take a few minutes)..."
      # Retrieve latest patch version to make installation robust
      local patch_ver
      patch_ver=$(pyenv install --list | grep -E "^\s*${pyver}\.[0-9]+$" | tail -n 1 | tr -d ' ')
      if [ -n "$patch_ver" ]; then
        pyenv install "$patch_ver"
      else
        pyenv install "$pyver"
      fi
    else
      log "Python ${pyver} is already installed."
    fi
  done
}

# --- 6) PATH FILES DYNAMIC CONFIGURATION ----------------
update_paths_configs() {
  log "Updating local paths in workspace/.paths-*.sh files..."
  
  # 1. Java path configurations
  local paths_java="workspace/.paths-java.sh"
  if [ -f "$paths_java" ]; then
    # Scan all installed Java subdirectories under SDKMAN
    if [ -d "$HOME/.sdkman/candidates/java" ]; then
      for jdir in "$HOME/.sdkman/candidates/java"/*; do
        if [ -d "$jdir" ] && [ ! -L "$jdir" ]; then
          local folder_name=$(basename "$jdir")
          local major_ver=$(echo "$folder_name" | grep -oE '^[0-9]+' || true)
          if [ -n "$major_ver" ]; then
            local var_name="JAVA${major_ver}_HOME"
            # Ensure export variable exists in paths-java.sh file
            if ! grep -q "^export ${var_name}=" "$paths_java"; then
              log "Prepend missing ${var_name} export to ${paths_java}..."
              echo "export ${var_name}=" | cat - "$paths_java" > temp && mv temp "$paths_java"
            fi
            # Set path
            safe_sed "s|^export ${var_name}=.*|export ${var_name}=\"\$HOME/.sdkman/candidates/java/$folder_name\"|g" "$paths_java"
          fi
        fi
      done
    fi
    
    # Clear any declared Java variables in the file if they are no longer installed on the system
    local declared_vers=$(grep -oE '^export JAVA[0-9]+_HOME=' "$paths_java" | grep -oE '[0-9]+' || true)
    for v in $declared_vers; do
      local found_folder=$(find "$HOME/.sdkman/candidates/java" -maxdepth 1 -name "${v}.*" -exec basename {} \; 2>/dev/null | head -n 1 || true)
      if [ -z "$found_folder" ]; then
        safe_sed "s|^export JAVA${v}_HOME=.*|export JAVA${v}_HOME=|g" "$paths_java"
      fi
    done
    
    safe_sed "s|^export MAVEN_HOME=.*|export MAVEN_HOME=\"\$HOME/.sdkman/candidates/maven/current\"|g" "$paths_java"
    log "Updated paths in $paths_java"
  else
    warn "$paths_java not found."
  fi
  
  # 2. Python path configurations
  local paths_python="workspace/.paths-python.sh"
  if [ -f "$paths_python" ]; then
    # Sourced pyenv variables must be active
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    
    local py11_ver=$(pyenv versions --bare | grep -E '^3\.11\.' | tail -n 1 || true)
    local py12_ver=$(pyenv versions --bare | grep -E '^3\.12\.' | tail -n 1 || true)
    local py13_ver=$(pyenv versions --bare | grep -E '^3\.13\.' | tail -n 1 || true)
    
    if [ -n "$py11_ver" ]; then
      safe_sed "s|^export PYTHON311_HOME=.*|export PYTHON311_HOME=\"\$HOME/.pyenv/versions/$py11_ver\"|g" "$paths_python"
    fi
    if [ -n "$py12_ver" ]; then
      safe_sed "s|^export PYTHON312_HOME=.*|export PYTHON312_HOME=\"\$HOME/.pyenv/versions/$py12_ver\"|g" "$paths_python"
    fi
    if [ -n "$py13_ver" ]; then
      safe_sed "s|^export PYTHON313_HOME=.*|export PYTHON313_HOME=\"\$HOME/.pyenv/versions/$py13_ver\"|g" "$paths_python"
    fi
    
    log "Updated paths in $paths_python"
  else
    warn "$paths_python not found."
  fi
}

# --- 7) INSTALL PACKAGE MANIFESTS -----------------------
install_manifest_packages() {
  log "Installing packages from workspace manifests..."
  
  # Execute system platform packages installer
  if [ -f "workspace/install/install-packages.sh" ]; then
    log "Running system packages installer (requires sudo authentication)..."
    sudo chmod +x workspace/install/install-packages.sh
    sudo ./workspace/install/install-packages.sh
  else
    warn "workspace/install/install-packages.sh not found."
  fi

  # Execute Brew package installation
  if [ -f "workspace/install/brew.pkg" ] && command -v brew &>/dev/null; then
    log "Installing brew packages from brew.pkg..."
    # Read packages, filter empty lines, and run brew install
    local brew_pkgs=$(grep -v '^$' workspace/install/brew.pkg | xargs)
    if [ -n "$brew_pkgs" ]; then
      brew install $brew_pkgs
    else
      log "No packages found in brew.pkg."
    fi
  fi
}

# --- 8) ZSHRC CONFIGURATION -----------------------------
setup_zshrc() {
  log "Setting up shell configuration in ~/.zshrc..."
  touch "$HOME/.zshrc"
  
  # 1. Pyenv configuration block
  local pyenv_block='
# PYENV-VIRTUALENV
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &>/dev/null; then
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
fi'

  if ! grep -q "PYENV_ROOT" "$HOME/.zshrc"; then
    echo -e "$pyenv_block" >> "$HOME/.zshrc"
    log "Added Pyenv block to ~/.zshrc."
  fi

  # 2. SDKMAN configuration block
  local sdkman_block='
#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"'

  if ! grep -q "SDKMAN_DIR" "$HOME/.zshrc"; then
    echo -e "$sdkman_block" >> "$HOME/.zshrc"
    log "Added SDKMAN block to ~/.zshrc."
  fi

  # 3. Bootstrap configuration block
  local bootstrap_block='
if [ -f ~/.bootstrap.sh ]; then
  source ~/.bootstrap.sh
fi'

  if ! grep -q "bootstrap.sh" "$HOME/.zshrc"; then
    echo -e "$bootstrap_block" >> "$HOME/.zshrc"
    log "Added bootstrap.sh source block to ~/.zshrc."
  fi
}

# --- 9) STOW ENVIRONMENT --------------------------------
run_stow() {
  log "Running stow configuration..."
  if [ -f "do-stow.sh" ]; then
    chmod +x do-stow.sh
    ./do-stow.sh
  else
    error "do-stow.sh not found in the root directory!"
  fi
}

# --- 10) DEFAULT SHELL CONFIGURATION ---------------------
configure_default_shell() {
  if [ "$SHELL" != "$(command -v zsh)" ] && command -v zsh &>/dev/null; then
    log "Changing default login shell to Zsh..."
    chsh -s "$(command -v zsh)"
  fi
}

# --- MAIN EXECUTION -------------------------------------
main() {
  log "=================================================="
  log "Starting Dotfiles Machine Bootstrap Script"
  log "=================================================="
  
  detect_and_install_dependencies
  install_brew
  install_nvm_and_node
  install_sdkman_and_java
  install_pyenv
  update_paths_configs
  install_manifest_packages
  setup_zshrc
  run_stow
  configure_default_shell
  
  log "=================================================="
  log "Bootstrap successfully completed!"
  log "Please restart your terminal session to apply Zsh configuration."
  log "=================================================="
}

main
