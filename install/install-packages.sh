#!/bin/bash

# Require sudo for the script
if [[ "$EUID" -ne 0 ]]; then
  echo "[ERROR] This script must be run as root (use sudo)."
  exit 1
fi

# --- LOGGING FUNCTIONS ----------------------------------
log() {
  echo "[INFO] $1"
}

warn() {
  echo "[WARNING] $1"
}

# --- CHECK PACKAGE INSTALLATION --------------------------
is_package_installed() {
  local pkg_manager="$1"
  local package="$2"

  case "$pkg_manager" in
    brew)
      brew list --formula | grep -q "^${package}$"
      ;;
    apt)
      dpkg -s "$package" &> /dev/null
      ;;
    yum|dnf)
      rpm -q "$package" &> /dev/null
      ;;
    pacman)
      pacman -Qi "$package" &> /dev/null
      ;;
    *)
      return 1
      ;;
  esac
}

# --- INSTALL PACKAGES ------------------------------------
install_packages() {
  local pkg_manager="$1"
  local packages=("${@:2}")
  local to_install=()
  local already_installed=()

  # Check each package before installation
  for package in "${packages[@]}"; do
    if is_package_installed "$pkg_manager" "$package"; then
      already_installed+=("$package")
    else
      to_install+=("$package")
    fi
  done

  # Log already installed packages
  if [[ ${#already_installed[@]} -gt 0 ]]; then
    log "Already installed: ${already_installed[*]}"
  fi

  # Install only missing packages
  if [[ ${#to_install[@]} -gt 0 ]]; then
    log "Installing (${pkg_manager}): ${to_install[*]}"
    case "$pkg_manager" in
      brew)
        brew install "${to_install[@]}" &> /dev/null
        ;;
      apt)
        apt update &> /dev/null
        apt install -y "${to_install[@]}" &> /dev/null
        ;;
      yum)
        yum install -y "${to_install[@]}" &> /dev/null
        ;;
      dnf)
        dnf install -y "${to_install[@]}" &> /dev/null
        ;;
      pacman)
        pacman -S --noconfirm "${to_install[@]}" &> /dev/null
        ;;
      *)
        warn "Unsupported package manager: $pkg_manager"
        ;;
    esac

    if [[ $? -ne 0 ]]; then
      warn "Some packages failed to install: ${to_install[*]}"
      failed_packages+=("${to_install[@]}")
    fi
  fi

  # Return only installed packages
  echo "${already_installed[@]}"
}

# --- DETECT PACKAGE MANAGER -----------------------------
detect_package_manager() {
  if command -v apt &> /dev/null; then
    echo "apt"
  elif command -v yum &> /dev/null; then
    echo "yum"
  elif command -v dnf &> /dev/null; then
    echo "dnf"
  elif command -v pacman &> /dev/null; then
    echo "pacman"
  else
    warn "Unsupported package manager. Cannot install platform packages."
    echo "unknown"
  fi
}

# --- READ PACKAGES FROM A FILE --------------------------
read_packages() {
  local pkg_file="$1"
  if [[ -f "$pkg_file" ]]; then
    mapfile -t packages < <(grep -v '^$' "$pkg_file")  # Read file ignoring empty lines
    echo "${packages[@]}"
  else
    warn "Package file $pkg_file not found."
    echo ""
  fi
}

# --- MAIN SCRIPT -----------------------------------------
main() {
  local installed_packages=()
  local already_installed_packages=()
  failed_packages=()

  # 1) Install Brew packages (if brew.pkg exists and Brew is installed)
  brew_packages=($(read_packages "brew.pkg"))
  if [[ ${#brew_packages[@]} -gt 0 ]]; then
    if command -v brew &> /dev/null; then
      already_installed_packages+=($(install_packages brew "${brew_packages[@]}"))
      installed_packages+=("${brew_packages[@]}")
    else
      warn "Homebrew is not installed or not on PATH. Skipping brew packages."
    fi
  fi

  # 2) Detect platform package manager
  pkg_manager=$(detect_package_manager)
  if [[ "$pkg_manager" != "unknown" ]]; then
    platform_packages=($(read_packages "platform.pkg"))
    if [[ ${#platform_packages[@]} -gt 0 ]]; then
      already_installed_packages+=($(install_packages "$pkg_manager" "${platform_packages[@]}"))
      installed_packages+=("${platform_packages[@]}")
    fi
  fi

  # --- FORMATTED REPORT ----------------------------------
  echo -e "\n------------------------------------"
  echo "         Installation Report"
  echo "------------------------------------"
  
  printf "%-25s %s\n" "Installed Packages:" "${installed_packages[*]:-None}"
  printf "%-25s %s\n" "Already Installed:" "${already_installed_packages[*]:-None}"
  printf "%-25s %s\n" "Failed Packages:" "${failed_packages[*]:-None}"
}

# Execute main
main

