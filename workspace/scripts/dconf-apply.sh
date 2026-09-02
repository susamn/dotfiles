#!/usr/bin/env bash
# dconf-apply.sh — Apply version-controlled GSettings/dconf keys.
#
# gsettings writes to ~/.config/dconf/user, a binary database that is neither
# stowed nor tracked by this repo. Any desktop setting changed by hand is
# therefore invisible to do-stow.sh and lost on a rebuild. This script is the
# version-controlled record of the keys that matter, so onboard.sh can restore
# them on a fresh machine.
#
# Only deliberate, explained settings belong here. Transient state -- window
# sizes, recent colour picks, view zoom -- stays out: a full `dconf dump` would
# capture that noise and produce an unreadable diff on every GNOME interaction.
#
# Note that this file does NOT capture every non-default key currently on the
# machine. Run `dconf dump /` to see the rest (theme, icon theme, text scaling);
# add any you want reproducible to the table below.
#
# Usage:
#   dconf-apply.sh            # apply every setting (idempotent)
#   dconf-apply.sh check      # report drift, change nothing; exit 1 if any
#   dconf-apply.sh list       # print the table
#
# Exit: 0 ok / 1 drift found (check mode) / 2 usage or missing dependency

set -euo pipefail

# --- SETTINGS TABLE -------------------------------------
# Format: <schema>|<key>|<value>|<why>
# <value> is passed verbatim to `gsettings set`, so quote it as gsettings expects.
SETTINGS=(
  "org.gnome.desktop.privacy|remember-recent-files|false|Recent-files tracking makes gvfsd-recent stat every remembered path. Entries on the rclone Google Drive mounts turn that into a network round-trip, and an unreachable remote wedged gvfsd-recent in uninterruptible D state for over an hour on 2026-09-02."

  "org.freedesktop.Tracker3.Miner.Files|ignored-directories|['po', 'CVS', 'core-dumps', 'lost+found', '/home/susamn/Documents/Docs', '/home/susamn/Obsidian']|The indexer recursively walks \$HOME, and both rclone mounts live under it, so it continuously crawled Google Drive. The first four entries are the upstream defaults and must be kept -- gsettings replaces the whole list rather than merging."
)

# --- OUTPUT ---------------------------------------------
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BLUE=$'\033[0;34m'; NC=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; NC=""
fi

# Diagnostics go to stderr so stdout stays parseable.
info() { printf '%s\n' "$*" >&2; }
fail() { printf '%s%s%s\n' "$RED" "$*" "$NC" >&2; }

# --- PREFLIGHT ------------------------------------------
if ! command -v gsettings >/dev/null 2>&1; then
  fail "gsettings not found. Install glib2 (Arch) or libglib2.0-bin (Debian)."
  exit 2
fi

# A schema absent from this machine is not an error: the desktop component that
# owns it may simply not be installed. Skip it and say so rather than aborting
# the whole run and leaving the remaining settings unapplied.
schema_present() {
  gsettings list-schemas 2>/dev/null | grep -qx "$1"
}

# --- MODES ----------------------------------------------
mode="${1:-apply}"
drift=0
skipped=0

case "$mode" in
  list)
    for entry in "${SETTINGS[@]}"; do
      IFS='|' read -r schema key value why <<<"$entry"
      printf '%s %s = %s\n' "$schema" "$key" "$value"
      printf '    %s\n\n' "$why"
    done
    ;;

  check|apply)
    for entry in "${SETTINGS[@]}"; do
      IFS='|' read -r schema key value why <<<"$entry"

      if ! schema_present "$schema"; then
        info "${YELLOW}skip${NC}  $schema — schema not installed on this machine"
        skipped=$((skipped + 1))
        continue
      fi

      current="$(gsettings get "$schema" "$key" 2>/dev/null || echo "<unreadable>")"
      # Compared as strings against `gsettings get` output, so every value in
      # the table above must already be written in that normalised form --
      # bare `false`, and arrays as ['a', 'b'] with a space after each comma.
      # A cosmetically different but semantically equal value reads as
      # permanent drift, which check mode will report on every run.
      desired="$value"

      if [[ "$current" == "$desired" ]]; then
        info "${GREEN}ok${NC}    $schema $key"
        continue
      fi

      if [[ "$mode" == "check" ]]; then
        info "${YELLOW}drift${NC} $schema $key"
        info "        want: $desired"
        info "        have: $current"
        drift=$((drift + 1))
      else
        if gsettings set "$schema" "$key" "$value" 2>/dev/null; then
          info "${BLUE}set${NC}   $schema $key"
          info "        was:  $current"
        else
          fail "fail  $schema $key — gsettings rejected the value"
          drift=$((drift + 1))
        fi
      fi
    done

    # Written as explicit blocks, not `[[ cond ]] && action` one-liners: such a
    # list returns 1 when the condition is false, and under `set -e` that exits
    # the script with a failure status even though every setting was fine.
    if [[ $skipped -gt 0 ]]; then
      info ""
      info "$skipped setting(s) skipped: schema not present."
    fi

    if [[ $drift -gt 0 ]]; then
      if [[ "$mode" == "check" ]]; then
        info ""
        info "$drift setting(s) differ. Run '$(basename "$0")' to apply."
      fi
      exit 1
    fi
    exit 0
    ;;

  -h|--help|help)
    sed -n '2,22p' "$0" | sed 's/^# \?//'
    ;;

  *)
    fail "Unknown mode: $mode"
    fail "Usage: $(basename "$0") [apply|check|list]"
    exit 2
    ;;
esac
