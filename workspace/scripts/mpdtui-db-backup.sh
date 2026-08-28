#!/usr/bin/env bash
#
# mpdtui-db-backup.sh -- on-demand backup / restore of the mpdtui SQLite DB
# to any rclone remote. Only the DB file is ever backed up or replaced;
# no other file is touched.
#
# Layout on the remote:  <remote>:Backup/mpdtui/mpdtui-<host>-<timestamp>.db
#                         <remote>:Backup/mpdtui/mpdtui-<host>-<timestamp>.sql
#                         <remote>:Backup/mpdtui/mpdtui-<host>-latest.db  (+ .sql)
#
# Usage:
#   mdbk               # or: mdbk backup
#   mdbk restore
#   mdbk list
#
# Both backup and restore prompt for the rclone remote (default: gdrive).
# The base path "Backup/mpdtui" is created on the remote if missing.
# Restore prompts for the target DB path; if a file is already there it
# asks before replacing it.
#
# Env overrides:  MPDTUI_DB (source/default target), MPDTUI_DB_REMOTE (skip
#                 the prompt), MPDTUI_DB_KEEP (snapshots kept per host, 0 = all)
#
set -euo pipefail

DB="${MPDTUI_DB:-$HOME/.config/mpdtui/mpdtui.db}"
BASE_PATH="Backup/mpdtui"
DEFAULT_REMOTE="gdrive"
KEEP="${MPDTUI_DB_KEEP:-30}"
HOST="$(hostname -s 2>/dev/null || hostname)"

log()  { echo -e "\033[1;36m::\033[0m $*"; }
ok()   { echo -e "\033[1;32mok\033[0m $*"; }
err()  { echo -e "\033[1;31merror\033[0m $*" >&2; exit 1; }

command -v rclone  >/dev/null || err "rclone not found"
command -v sqlite3 >/dev/null || err "sqlite3 not found"

# Pick + validate the rclone remote; echo the base "<remote>:Backup/mpdtui"
# and make sure it exists.
pick_remote() {
  local remote
  if [[ -n "${MPDTUI_DB_REMOTE:-}" ]]; then
    remote="${MPDTUI_DB_REMOTE%%:*}"
  elif [[ -t 0 ]]; then
    read -rp "rclone remote [$DEFAULT_REMOTE]: " remote
    remote="${remote:-$DEFAULT_REMOTE}"
  else
    remote="$DEFAULT_REMOTE"
  fi

  rclone listremotes | grep -qx "${remote}:" \
    || err "rclone remote '${remote}' is not configured (see: rclone config)"

  local base="${remote}:${BASE_PATH}"
  rclone mkdir "$base" 2>/dev/null || true
  echo "$base"
}

# --- backup ---------------------------------------------------------------
do_backup() {
  [[ -f "$DB" ]] || err "DB not found: $DB"

  local base; base="$(pick_remote)"
  local tmp ts snap dump
  tmp="$(mktemp -d)"
  ts="$(date +%Y%m%d-%H%M%S)"
  snap="$tmp/mpdtui-${HOST}-${ts}.db"
  dump="$tmp/mpdtui-${HOST}-${ts}.sql"

  # consistent snapshot even while mpdtui runs (read lock, folds in the WAL);
  # plain .sql dump as a tool-independent fallback
  sqlite3 "$DB" ".backup '$snap'"
  sqlite3 "$snap" .dump > "$dump"

  local check
  check="$(sqlite3 "$snap" 'PRAGMA integrity_check;' 2>&1 || true)"
  [[ "$check" == "ok" ]] || { rm -rf "$tmp"; err "integrity_check failed: $check"; }

  log "uploading to $base"
  rclone copy "$snap" "$base/" --no-traverse -q
  rclone copy "$dump" "$base/" --no-traverse -q
  rclone copyto "$snap" "$base/mpdtui-${HOST}-latest.db"  --no-traverse -q
  rclone copyto "$dump" "$base/mpdtui-${HOST}-latest.sql" --no-traverse -q

  local size; size="$(du -h "$snap" | cut -f1)"
  rm -rf "$tmp"
  ok "backed up $size as mpdtui-${HOST}-${ts}.db  (+ .sql, + latest)"

  prune "$base"
}

# keep only the newest $KEEP timestamped snapshots for THIS host
prune() {
  local base="$1"
  [[ "$KEEP" -gt 0 ]] || return 0
  local ext old f n=0
  for ext in db sql; do
    mapfile -t old < <(
      rclone lsf "$base" --files-only --include "mpdtui-${HOST}-*.${ext}" 2>/dev/null \
        | grep -vE -- "-latest\.${ext}\$" \
        | sort | head -n -"$KEEP"
    )
    for f in "${old[@]}"; do
      [[ -n "$f" ]] || continue
      rclone deletefile "$base/$f" 2>/dev/null && n=$((n+1))
    done
  done
  [[ "$n" -eq 0 ]] || log "pruned $n old file(s), keeping newest $KEEP per type"
}

# --- list ---------------------------------------------------------------
do_list() {
  local base; base="$(pick_remote)"
  log "$base"
  rclone lsl "$base" 2>/dev/null | grep -E '\.db$' | sort -k4 \
    || err "cannot list $base"
}

# --- restore -----------------------------------------------------------
do_restore() {
  local base; base="$(pick_remote)"

  mapfile -t snaps < <(
    rclone lsf "$base" --files-only --include 'mpdtui-*.db' 2>/dev/null | sort
  )
  [[ ${#snaps[@]} -gt 0 ]] || err "no backups found at $base"

  echo "Available backups:"
  printf '  %s\n' "${snaps[@]}"
  local default_snap="mpdtui-${HOST}-latest.db"
  printf '%s\n' "${snaps[@]}" | grep -qx "$default_snap" || default_snap="${snaps[-1]}"

  local snap target
  if [[ -t 0 ]]; then
    read -rp "restore which [$default_snap]: " snap
    snap="${snap:-$default_snap}"
  else
    snap="$default_snap"
  fi
  printf '%s\n' "${snaps[@]}" | grep -qx "$snap" || err "no such backup: $snap"

  if [[ -t 0 ]]; then
    read -rp "restore to DB path [$DB]: " target
    target="${target:-$DB}"
  else
    target="$DB"
  fi
  target="${target/#\~/$HOME}"
  # if a directory was given, drop the file inside it
  [[ -d "$target" ]] && target="${target%/}/mpdtui.db"

  local tdir; tdir="$(dirname "$target")"
  [[ -d "$tdir" ]] || { log "creating $tdir"; mkdir -p "$tdir"; }

  if [[ -e "$target" ]]; then
    [[ -f "$target" ]] || err "target exists and is not a regular file: $target"
    local reply=""
    [[ -t 0 ]] && read -rp "replace existing $target ? [y/N]: " reply
    [[ "$reply" =~ ^[Yy]$ ]] || err "aborted -- existing DB left untouched"
  fi

  # download to a temp file, verify, then move into place -- nothing else touched
  local tmp; tmp="$(mktemp)"
  log "downloading $snap"
  rclone copyto "$base/$snap" "$tmp" --no-traverse -q || { rm -f "$tmp"; err "download failed: $snap"; }
  sqlite3 "$tmp" 'PRAGMA integrity_check;' | grep -qx ok \
    || { rm -f "$tmp"; err "downloaded DB failed integrity_check"; }
  mv -f "$tmp" "$target"
  ok "restored $snap -> $target"
}

case "${1:-backup}" in
  backup|"")  do_backup ;;
  restore)    do_restore ;;
  list|ls)    do_list ;;
  *)          err "unknown command: $1 (use: backup | restore | list)" ;;
esac
