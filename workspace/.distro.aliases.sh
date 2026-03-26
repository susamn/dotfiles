#!/usr/bin/env bash
# pm_aliases.sh — Cross-distro package manager aliases
# Source this file: source ~/pm_aliases.sh
#
# Override detection for testing or unusual setups:
#   PM_DISTRO=arch source ~/pm_aliases.sh

# ── Guard: must be sourced, not executed ─────────────────────────────────────
(return 0 2>/dev/null) || {
  printf 'ERROR: This script must be sourced, not executed.\n' >&2
  printf '  Usage: source %s\n' "$0" >&2
  exit 1
}

# ── Guard: bash or zsh only ──────────────────────────────────────────────────
case "$BASH_VERSION$ZSH_VERSION" in
  '') printf 'pm_aliases: WARNING: untested shell — aliases may not work\n' >&2 ;;
esac

# ── Internal: distro detection ───────────────────────────────────────────────
__pm_detect_distro() {
  local id=""

  # 1. env override (for testing / manual override)
  if [ -n "${PM_DISTRO:-}" ]; then
    printf '%s' "$PM_DISTRO" | tr '[:upper:]' '[:lower:]'
    return
  fi

  # macOS / Darwin
  if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
    id="mac"
  fi

  # 2. /etc/os-release (systemd standard)
  if [ -z "$id" ] && [ -f /etc/os-release ]; then
    id=$(. /etc/os-release 2>/dev/null && printf '%s' "${ID:-}")
  fi

  # 3. /etc/lsb-release (Ubuntu/Debian legacy)
  if [ -z "$id" ] && [ -f /etc/lsb-release ]; then
    id=$(. /etc/lsb-release 2>/dev/null && printf '%s' "${DISTRIB_ID:-}")
  fi

  # 4. Legacy distro-specific files
  if [ -z "$id" ]; then
    if   [ -f /etc/arch-release ];    then id="arch"
    elif [ -f /etc/fedora-release ];  then id="fedora"
    elif [ -f /etc/centos-release ];  then id="centos"
    elif [ -f /etc/redhat-release ];  then id="rhel"
    elif [ -f /etc/debian_version ];  then id="debian"
    elif [ -f /etc/alpine-release ];  then id="alpine"
    elif [ -f /etc/void-release ];    then id="void"
    elif [ -f /etc/gentoo-release ];  then id="gentoo"
    fi
  fi

  # 5. Infer from available package manager binary
  if [ -z "$id" ]; then
    if   command -v pacman      >/dev/null 2>&1; then id="arch"
    elif command -v apt         >/dev/null 2>&1; then id="debian"
    elif command -v dnf         >/dev/null 2>&1; then id="fedora"
    elif command -v yum         >/dev/null 2>&1; then id="centos"
    elif command -v zypper      >/dev/null 2>&1; then id="opensuse"
    elif command -v xbps-install>/dev/null 2>&1; then id="void"
    elif command -v apk         >/dev/null 2>&1; then id="alpine"
    elif command -v emerge      >/dev/null 2>&1; then id="gentoo"
    fi
  fi

  printf '%s' "${id:-unknown}" | tr '[:upper:]' '[:lower:]'
}

# ── Internal: map distro id → package manager family ─────────────────────────
__pm_family_for() {
  case "$1" in
    mac|macos|darwin)
      printf 'mac' ;;
    arch|manjaro|endeavouros|garuda|artix|archcraft|arcolinux|cachyos)
      printf 'arch' ;;
    ubuntu|debian|linuxmint|mint|pop|"pop!_os"|kali|raspbian|elementary|\
zorin|deepin|parrot|tails|backbox|neon|"ubuntu-budgie"|"ubuntu-mate")
      printf 'debian' ;;
    fedora|"fedora linux")
      printf 'fedora' ;;
    rhel|centos|almalinux|"rocky linux"|rocky|ol|"oracle linux"|"scientific linux")
      printf 'rhel' ;;
    opensuse|"opensuse-leap"|"opensuse-tumbleweed"|sles)
      printf 'opensuse' ;;
    void)   printf 'void' ;;
    alpine) printf 'alpine' ;;
    gentoo) printf 'gentoo' ;;
    nixos)  printf 'nixos' ;;
    *)      printf 'unknown' ;;
  esac
}

# ── Sudo helper: skip sudo when already root ─────────────────────────────────
_pm_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# ── Wipe any pre-existing pm aliases set by us ───────────────────────────────
for __pm_a in i r u s q qi qf; do
  unalias "$__pm_a" 2>/dev/null || true
done
unset PM 2>/dev/null || true

# ── Detect ───────────────────────────────────────────────────────────────────
__PM_DISTRO=$(__pm_detect_distro)
__PM_FAMILY=$(__pm_family_for "$__PM_DISTRO")

# ── Set aliases per family ────────────────────────────────────────────────────
case "$__PM_FAMILY" in

  arch)
    if   command -v paru   >/dev/null 2>&1; then PM="paru"
    elif command -v yay    >/dev/null 2>&1; then PM="yay"
    elif command -v trizen >/dev/null 2>&1; then PM="trizen"
    else                                         PM="pacman"
    fi
    if [ "$PM" = "pacman" ]; then
      alias i="_pm_sudo pacman -S"
      alias r="_pm_sudo pacman -Rns"
      alias u="_pm_sudo pacman -Syu"
    else
      # shellcheck disable=SC2139
      alias i="$PM -S"
      # shellcheck disable=SC2139
      alias r="$PM -Rns"
      # shellcheck disable=SC2139
      alias u="$PM -Syu"
    fi
    # shellcheck disable=SC2139
    alias s="$PM -Ss"
    alias q="$PM -Q"
    alias qi="$PM -Qi"
    alias qf="$PM -Ql"
    ;;

  mac)
    PM="brew"
    alias i="brew install"
    alias r="brew uninstall"
    alias u="brew update && brew upgrade"
    alias s="brew search"
    alias q="brew list"
    alias qi="brew info"
    alias qf="brew ls"
    ;;

  debian)
    PM="apt"
    alias i="_pm_sudo apt install"
    alias r="_pm_sudo apt remove"
    alias u="_pm_sudo apt update && _pm_sudo apt upgrade"
    alias s="apt search"
    alias q="apt list --installed 2>/dev/null"
    alias qi="apt show"
    alias qf="dpkg -L"
    ;;

  fedora)
    PM="dnf"
    alias i="_pm_sudo dnf install"
    alias r="_pm_sudo dnf remove"
    alias u="_pm_sudo dnf upgrade"
    alias s="dnf search"
    alias q="dnf list installed"
    alias qi="dnf info"
    alias qf="rpm -ql"
    ;;

  rhel)
    if command -v dnf >/dev/null 2>&1; then PM="dnf"; else PM="yum"; fi
    # shellcheck disable=SC2139
    alias i="_pm_sudo $PM install"
    # shellcheck disable=SC2139
    alias r="_pm_sudo $PM remove"
    # shellcheck disable=SC2139
    alias u="_pm_sudo $PM update"
    # shellcheck disable=SC2139
    alias s="$PM search"
    # shellcheck disable=SC2139
    alias q="$PM list installed"
    # shellcheck disable=SC2139
    alias qi="$PM info"
    alias qf="rpm -ql"
    ;;

  opensuse)
    PM="zypper"
    alias i="_pm_sudo zypper install"
    alias r="_pm_sudo zypper remove"
    alias u="_pm_sudo zypper refresh && _pm_sudo zypper update"
    alias s="zypper search"
    alias q="zypper packages --installed-only"
    alias qi="zypper info"
    alias qf="rpm -ql"
    ;;

  void)
    PM="xbps-install"
    alias i="_pm_sudo xbps-install -S"
    alias r="_pm_sudo xbps-remove -R"
    alias u="_pm_sudo xbps-install -Su"
    alias s="xbps-query -Rs"
    alias q="xbps-query -l"
    alias qi="xbps-query -S"
    alias qf="xbps-query -f"
    ;;

  alpine)
    PM="apk"
    alias i="_pm_sudo apk add"
    alias r="_pm_sudo apk del"
    alias u="_pm_sudo apk update && _pm_sudo apk upgrade"
    alias s="apk search"
    alias q="apk list --installed"
    alias qi="apk info"
    alias qf="apk info --contents"
    ;;

  gentoo)
    PM="emerge"
    alias i="_pm_sudo emerge"
    alias r="_pm_sudo emerge --depclean"
    alias u="_pm_sudo emerge --sync && _pm_sudo emerge -uDU --keep-going @world"
    alias s="emerge --search"
    alias q="qlist -I"
    alias qi="emerge --info"
    alias qf="qlist"
    ;;

  nixos)
    PM="nix-env"
    alias i="nix-env -iA"
    alias r="nix-env -e"
    alias u="_pm_sudo nixos-rebuild switch --upgrade"
    alias s="nix search nixpkgs"
    alias q="nix-env -q"
    alias qi="nix-env -qa --description"
    alias qf="nix-store -q --references"
    ;;

  unknown)
    printf 'pm_aliases: WARNING: unrecognised distro "%s" — no aliases set.\n' \
      "$__PM_DISTRO" >&2
    printf 'pm_aliases: Set PM_DISTRO=<id> and re-source, or open an issue.\n' >&2
    unset -f __pm_detect_distro __pm_family_for 2>/dev/null || true
    unset __PM_DISTRO __PM_FAMILY __pm_a 2>/dev/null || true
    return 1
    ;;
esac

# ── Feedback ─────────────────────────────────────────────────────────────────
#printf 'pm_aliases: loaded for %s (%s) — PM=%s\n' \
#  "$__PM_DISTRO" "$__PM_FAMILY" "$PM" >&2
#printf '  i=install  r=remove  u=update/upgrade\n' >&2
#printf '  s=search   q=list-installed  qi=info  qf=list-files\n' >&2

# ── Cleanup (keep _pm_sudo — aliases call it at runtime) ─────────────────────
unset -f __pm_detect_distro __pm_family_for 2>/dev/null || true
unset __PM_DISTRO __PM_FAMILY __pm_a 2>/dev/null || true
