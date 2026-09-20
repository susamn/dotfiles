#!/usr/bin/env bash
# yazi-pkg.sh — `ya pkg` wrapper that re-applies the local plugin patches.
#
# Why this exists: some yazi plugins are stale and still call ya.mgr_emit(),
# which yazi 26 removed in favour of ya.emit(). Calling it makes the plugin's
# task fail silently -- the only symptom is the task counter in the status bar
# ("1 left"). Fixes live in .config/yazi/patches/<plugin>.patch, tracked in the
# dotfiles repo; plugins/ itself is gitignored and every `ya pkg` run
# overwrites it, so the patches must be re-applied afterwards.
#
# Usage:
#   yazi-pkg.sh install   # ya pkg install, then patch
#   yazi-pkg.sh upgrade   # ya pkg upgrade, then patch
#   yazi-pkg.sh patch     # re-apply patches only
#   yazi-pkg.sh status    # report which patches are applied

set -euo pipefail

YAZI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/yazi"
PATCH_DIR="$YAZI_DIR/patches"

log()  { echo -e "\033[1;32m[yazi-pkg]\033[0m $1"; }
warn() { echo -e "\033[1;33m[yazi-pkg]\033[0m $1" >&2; }
die()  { echo -e "\033[1;31m[yazi-pkg]\033[0m $1" >&2; exit 1; }

command -v ya >/dev/null 2>&1 || die "ya (yazi CLI) not found in PATH."

# Patches are -p1 against the plugins/ directory:
#   --- a/<plugin>.yazi/main.lua
#   +++ b/<plugin>.yazi/main.lua
apply_patches() {
  local rc=0 p name
  [ -d "$PATCH_DIR" ] || { warn "No patch directory at $PATCH_DIR — nothing to apply."; return 0; }

  shopt -s nullglob
  for p in "$PATCH_DIR"/*.patch; do
    name="$(basename "$p" .patch)"
    if [ ! -d "$YAZI_DIR/plugins/$name" ]; then
      warn "$name is not installed — skipping its patch."
      continue
    fi
    if patch -p1 -d "$YAZI_DIR/plugins" --dry-run --reverse --force --silent < "$p" >/dev/null 2>&1; then
      log "$name: already patched."
      continue
    fi
    # `ya pkg` deploys plugin files read-only (444); make them writable first,
    # otherwise patch warns on every run.
    chmod -R u+w "$YAZI_DIR/plugins/$name"
    if patch -p1 -d "$YAZI_DIR/plugins" --forward --silent < "$p"; then
      log "$name: patched."
    else
      warn "$name: PATCH FAILED — upstream changed. Rebuild $p by hand, or drop it if upstream fixed the bug."
      rc=1
    fi
  done
  shopt -u nullglob
  return $rc
}

status_patches() {
  local p name
  shopt -s nullglob
  for p in "$PATCH_DIR"/*.patch; do
    name="$(basename "$p" .patch)"
    if [ ! -d "$YAZI_DIR/plugins/$name" ]; then
      echo "  $name: not installed"
    elif patch -p1 -d "$YAZI_DIR/plugins" --dry-run --reverse --force --silent < "$p" >/dev/null 2>&1; then
      echo "  $name: applied"
    else
      echo "  $name: NOT applied"
    fi
  done
  shopt -u nullglob
}

case "${1:-install}" in
  install) ya pkg install; apply_patches ;;
  upgrade) ya pkg upgrade; apply_patches ;;
  patch)   apply_patches ;;
  status)  status_patches ;;
  *)       die "Usage: $(basename "$0") {install|upgrade|patch|status}" ;;
esac
